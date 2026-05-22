package main

import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"

// LSP message reading/writing over stdin/stdout
// NOTE: all this code is claude generated for the sake of a POC.
// When properly understood, annotated and modified to the correct standards
// remove this comment

lsp_read_message :: proc() -> (content: string, ok: bool) {
	reader := io.to_reader(os.to_stream(os.stdin))
	content_length := -1

	// Read headers
	for {
		line_buf: [4096]u8
		line_sb := strings.builder_make()
		for {
			n, err := io.read(reader, line_buf[:1])
			if n == 0 || err != nil {
				return "", false
			}
			ch := line_buf[0]
			if ch == '\n' {
				break
			}
			if ch != '\r' {
				strings.write_byte(&line_sb, ch)
			}
		}
		line := strings.to_string(line_sb)

		if len(line) == 0 {
			// Empty line = end of headers
			break
		}

		if strings.has_prefix(line, "Content-Length: ") {
			length_str := line[len("Content-Length: "):]
			content_length, _ = strconv.parse_int(length_str)
		}
	}

	if content_length < 0 {
		return "", false
	}

	// Read body
	body := make([]u8, content_length)
	total_read := 0
	for total_read < content_length {
		n, err := io.read(reader, body[total_read:])
		if n == 0 || err != nil {
			return "", false
		}
		total_read += n
	}

	return string(body), true
}

lsp_write_message :: proc(content: string) {
	header := fmt.tprintf("Content-Length: %d\r\n\r\n", len(content))
	os.write(os.stdout, transmute([]u8)header)
	os.write(os.stdout, transmute([]u8)content)
}

// JSON-RPC helpers

lsp_send_response :: proc(id: json.Value, result: string) {
	msg := fmt.tprintf(`{{"jsonrpc":"2.0","id":%s,"result":%s}}`, json_value_to_string(id), result)
	lsp_write_message(msg)
}

lsp_send_notification :: proc(method: string, params: string) {
	msg := fmt.tprintf(`{{"jsonrpc":"2.0","method":"%s","params":%s}}`, method, params)
	lsp_write_message(msg)
}

json_value_to_string :: proc(v: json.Value) -> string {
	#partial switch val in v {
	case json.Integer:
		return fmt.tprintf("%d", val)
	case json.Float:
		return fmt.tprintf("%f", val)
	case json.String:
		return fmt.tprintf(`"%s"`, val)
	case json.Null:
		return "null"
	}
	return "null"
}

// Diagnostics

lsp_publish_diagnostics :: proc(uri: string, source: string) {
	compiler_init()
	// Extract file path from file:// URI and set source directory for import resolution
	file_path := strings.has_prefix(uri, "file://") ? uri[len("file://"):] : uri
	compiler.current_filepath = filepath.dir(file_path)
	_, _ = compile(source, file_path)

	diagnostics_sb := strings.builder_make()
	strings.write_string(&diagnostics_sb, "[")

	for error, i in compiler.errors {
		if i > 0 {
			strings.write_string(&diagnostics_sb, ",")
		}

		line, col := span_to_location(error.span)
		// LSP uses 0-based line/col
		lsp_line := line - 1
		lsp_col := col - 1
		if lsp_line < 0 {lsp_line = 0}
		if lsp_col < 0 {lsp_col = 0}

		// Escape the message for JSON
		escaped_msg := json_escape_string(error.message)

		diag := fmt.tprintf(
			`{{"range":{{"start":{{"line":%d,"character":%d}},"end":{{"line":%d,"character":%d}}}},"severity":1,"source":"zero","message":"%s"}}`,
			lsp_line,
			lsp_col,
			lsp_line,
			lsp_col + 1,
			escaped_msg,
		)
		strings.write_string(&diagnostics_sb, diag)
	}

	strings.write_string(&diagnostics_sb, "]")

	params := fmt.tprintf(
		`{{"uri":"%s","diagnostics":%s}}`,
		uri,
		strings.to_string(diagnostics_sb),
	)
	lsp_send_notification("textDocument/publishDiagnostics", params)
}

json_escape_string :: proc(s: string) -> string {
	sb := strings.builder_make()
	for ch in s {
		switch ch {
		case '"':
			strings.write_string(&sb, `\"`)
		case '\\':
			strings.write_string(&sb, `\\`)
		case '\n':
			strings.write_string(&sb, `\n`)
		case '\r':
			strings.write_string(&sb, `\r`)
		case '\t':
			strings.write_string(&sb, `\t`)
		case:
			strings.write_rune(&sb, ch)
		}
	}
	return strings.to_string(sb)
}

// Initialize response with minimal capabilities

LSP_INITIALIZE_RESULT :: `{
	"capabilities": {
		"textDocumentSync": {
			"openClose": true,
			"change": 1
		}
	},
	"serverInfo": {
		"name": "zero-lsp",
		"version": "0.1.0"
	}
}`


// Main LSP loop

lsp_run :: proc() {
	for {
		content, ok := lsp_read_message()
		if !ok {
			break
		}

		parsed, parse_err := json.parse(transmute([]u8)content)
		if parse_err != nil {
			continue
		}

		root := parsed.(json.Object) or_continue

		method_val := root["method"] or_continue
		method := method_val.(json.String) or_continue

		switch method {
		case "initialize":
			id := root["id"]
			lsp_send_response(id, LSP_INITIALIZE_RESULT)

		case "initialized":
		// Nothing to do

		case "shutdown":
			id := root["id"]
			lsp_send_response(id, "null")

		case "exit":
			os.exit(0)

		case "textDocument/didOpen":
			params := root["params"].(json.Object) or_continue
			text_doc := params["textDocument"].(json.Object) or_continue
			uri := text_doc["uri"].(json.String) or_continue
			text := text_doc["text"].(json.String) or_continue
			lsp_publish_diagnostics(uri, text)

		case "textDocument/didChange":
			params := root["params"].(json.Object) or_continue
			text_doc := params["textDocument"].(json.Object) or_continue
			uri := text_doc["uri"].(json.String) or_continue
			// With textDocumentSync.change = 1 (Full), the entire content is sent
			changes := params["contentChanges"].(json.Array) or_continue
			if len(changes) > 0 {
				change := changes[0].(json.Object) or_continue
				text := change["text"].(json.String) or_continue
				lsp_publish_diagnostics(uri, text)
			}

		case "textDocument/didClose":
			// Clear diagnostics
			params := root["params"].(json.Object) or_continue
			text_doc := params["textDocument"].(json.Object) or_continue
			uri := text_doc["uri"].(json.String) or_continue
			lsp_send_notification(
				"textDocument/publishDiagnostics",
				fmt.tprintf(`{"uri":"%s","diagnostics":[]}`, uri),
			)
		}
	}
}
