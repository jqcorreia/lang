package main

import "core:container/queue"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"

Compiler :: struct {
	current_filepath:     string, // Directory of the source file being compiled
	exe_dir:              string, // Directory of the compiler executable
	line_starts:          map[string][dynamic]int,
	sources:              map[string]string,
	scopes:               queue.Queue(Scope),
	global_scope:         Scope,
	loops:                queue.Queue(Loop),
	types:                map[string]^Type,
	errors:               [dynamic]Compiler_Error,
	external_linker_libs: [dynamic]string,
	arena:                virtual.Arena,
}

Compiler_Error :: struct {
	file:    string,
	span:    Span,
	message: string,
}

Loop :: struct {
	break_block: BasicBlockRef,
}

compiler := Compiler{}

compiler_init :: proc() {
	compiler.exe_dir = filepath.dir(string(os.args[0]))
	err := virtual.arena_init_growing(&compiler.arena)
	assert(err == .None)
	setup_native_types(&compiler) // Initialize the native type pointers
}

compiler_reset :: proc() {
	compiler.errors = {}
	compiler.line_starts = make(map[string][dynamic]int)
	compiler.sources = make(map[string]string)
	compiler.loops = {}
	compiler.external_linker_libs = {}
}

compile :: proc(source: string, filename: string) -> (stmts: []^Ast_Node, ok: bool) {
	compiler_reset()

	// Auto-include the runtime, resolved relative to the executable
	runtime_path, _ := filepath.join(
		{compiler.exe_dir, "runtime", "start.zero"},
		context.allocator,
	)
	runtime_source :=
		os.read_entire_file(runtime_path, context.allocator) or_else panic(
			fmt.tprintf("Runtime not found at %s", runtime_path),
		)
	runtime_tokens := lex(string(runtime_source), runtime_path)
	runtime_parser := Parser {
		tokens   = runtime_tokens,
		filename = runtime_path,
	}
	runtime_stmts := parse_program(&runtime_parser)

	// Reset line_starts so they reflect user source only (for error reporting)
	compiler.line_starts = {}
	tokens := lex(source, filename)
	when ODIN_DEBUG {
		tokens_print(tokens)
	}

	parser := Parser {
		tokens   = tokens,
		filename = filename,
	}
	user_stmts := parse_program(&parser)

	// Runtime first, then user code
	all_stmts: [dynamic]^Ast_Node
	for s in runtime_stmts do append(&all_stmts, s)
	for s in user_stmts do append(&all_stmts, s)
	stmts = order_statements(all_stmts[:])

	when ODIN_DEBUG {
		for stmt in stmts {
			statement_print(stmt)
		}
	}

	checker := Checker{}
	check(&checker, stmts)

	ok = len(compiler.errors) == 0
	return
}

build :: proc(source: string, filename: string) -> (ok: bool) {
	// Reset the compiler arena
	free_all(virtual.arena_allocator(&compiler.arena))
	context.allocator = virtual.arena_allocator(&compiler.arena)

	stmts: []^Ast_Node
	stmts, ok = compile(source, filename)
	if !ok {
		return
	}
	ok = generate(stmts)
	return
}

// Order top-level statements by processing priority:
// 1. Imports and external blocks (types + external function signatures)
// 2. Struct declarations
// 3. Global variable declarations
// 4. Functions
stmt_priority :: proc(node: ^Ast_Node) -> int {
	#partial switch &data in node.data {
	case Ast_Import, Ast_Const_Decl:
		return 0
	case Ast_Block:
		return 1
	case Ast_Struct_Decl:
		return 2
	case Ast_Var_Decl:
		return 3
	case Ast_Function:
		return 4
	}
	return 5
}

order_statements :: proc(stmts: []^Ast_Node) -> []^Ast_Node {
	ordered: [dynamic]^Ast_Node
	for priority in 0 ..= 5 {
		for s in stmts {
			if stmt_priority(s) == priority {
				append(&ordered, s)
			}
		}
	}
	return ordered[:]
}

setup_native_types :: proc(compiler: ^Compiler) {
	u8_t := new(Type)
	u8_t.kind = .Uint8
	compiler.types["u8"] = u8_t

	i8_t := new(Type)
	i8_t.kind = .Int8
	compiler.types["i8"] = i8_t

	i16_t := new(Type)
	i16_t.kind = .Int16
	compiler.types["i16"] = i16_t

	i32_t := new(Type)
	i32_t.kind = .Int32
	compiler.types["i32"] = i32_t

	i64_t := new(Type)
	i64_t.kind = .Int64
	compiler.types["i64"] = i64_t

	u32_t := new(Type)
	u32_t.kind = .Uint32
	compiler.types["u32"] = u32_t

	u64_t := new(Type)
	u64_t.kind = .Uint64
	compiler.types["u64"] = u64_t

	bool_t := new(Type)
	bool_t.kind = .Bool
	compiler.types["bool"] = bool_t
}
