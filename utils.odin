package main

import "core:fmt"
import "core:os"
import "core:strings"

fatal_token :: proc(token: Token, format: string, args: ..any) {
	fatal_span(token.span, format, ..args)
}

fatal_span :: proc(span: Span, format: string, args: ..any) {
	error := error_string(span, format, ..args)
	fmt.println(error)
	os.exit(1)
}

error_token :: proc(token: Token, format: string, args: ..any) {
	error_span(token.span, format, ..args)
}

error_span :: proc(span: Span, format: string, args: ..any) {
	append(
		&compiler.errors,
		Compiler_Error{span = span, message = error_string(span, format, ..args)},
	)
}

error_string :: proc(span: Span, format: string, args: ..any) -> string {
	row, col := span_to_location(span)
	loc := fmt.tprintf("%s:%d:%d", span.filename, row, col)
	msg := fmt.tprintf(format, ..args)
	error := fmt.tprintf("%s: %s", loc, msg)

	return error
}

token_serialize :: proc(token: Token) -> string {
	sb := strings.builder_make()
	line, col := span_to_location(token.span)
	lexeme := token.lexeme
	if lexeme == "\n" {
		lexeme = "\\n"
	}
	fmt.sbprintf(&sb, "%s \"%s\", line: %d, col: %d", token.kind, lexeme, line, col)

	return strings.to_string(sb)
}

tokens_print :: proc(tokens: []Token) {
	for token in tokens {
		fmt.println(token_serialize(token))
	}
}

expr_print_sb :: proc(expr: ^Expr, lvl: u32 = 0) -> string {
	sb := strings.builder_make()
	if expr == nil {
		return fmt.sbprint(&sb, "")
	}
	for _ in 0 ..< lvl {
		fmt.sbprint(&sb, " ")
	}
	#partial switch e in expr.data {
	case Expr_Int_Literal:
		fmt.sbprint(&sb, "Int ", e.value)
	case Expr_Variable:
		fmt.sbprint(&sb, "Identifier ", expr.data.(Expr_Variable).value)
	case Expr_Binary:
		fmt.sbprintln(&sb, "Binary ", e.op)
		fmt.sbprintln(&sb, expr_print_sb(e.left, lvl + 1))
		fmt.sbprintln(&sb, expr_print_sb(e.right, lvl + 1))
	}

	return strings.to_string(sb)
}

statement_print :: proc(node: ^Ast_Node, lvl: u32 = 0) {
	if node == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch data in node.data {
	case Ast_Var_Assign:
		fmt.println("Assignment ", data.lhs)
		fmt.println(scope_string(node.scope))
		expr_print(data.expr, node.scope, lvl + 1)
	case Ast_Return:
		fmt.println("Return ")
		expr_print(data.expr, node.scope, lvl + 1)
	case Ast_Break:
		fmt.println("Break")
	case Ast_Expr:
		expr_print(data.expr, node.scope, lvl + 1)
	case Ast_Function:
		fmt.print("Function", data.name, " ")
		for p in data.params {
			fmt.printf("%s: %s ", p.name, p.type_expr)
		}
		fmt.println()
		if !data.external {
			for st in data.body.statements {
				statement_print(st, lvl + 1)
			}
		}
	case:
		fmt.println(node)
	}
}

expr_print :: proc(expr: ^Expr, scope: ^Scope, lvl: u32 = 0) {
	if expr == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch e in expr.data {
	case Expr_Int_Literal:
		fmt.println("Int ", e.value)
	case Expr_Variable:
		fmt.println("Identifier ", e.value)
	case Expr_Binary:
		fmt.println("Binary ", e.op)
		expr_print(e.left, scope, lvl + 1)
		expr_print(e.right, scope, lvl + 1)
	case Expr_Call:
		fmt.println("Call ", e.callee.data.(Expr_Variable).value)
		for arg in e.args {
			expr_print(arg, scope, lvl + 1)
		}
	case:
		fmt.println(e)
	}
}

scope_print :: proc(current_scope: ^Scope) {
	scope := current_scope
	for {
		fmt.println(scope_string(scope))
		if scope.parent == nil {
			break
		}
		scope = scope.parent
	}
}
scope_string :: proc(scope: ^Scope) -> string {
	if scope == nil {
		return "No scope"
	}
	sb := strings.builder_make()

	_addr := scope
	fmt.sbprintln(&sb, "Scope ", scope.kind, &_addr)
	for name, sym in scope.symbols {
		fmt.sbprintln(&sb, name, sym.type, sym.kind, sym.decl)
	}

	return strings.to_string(sb)
}


unexpected_token :: proc(token: Token, loc := #caller_location) {
	fmt.println(loc)
	unimplemented(fmt.tprintf("Unexpected token: '%s'", token.lexeme))
}

one_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos, filename = lexer.filename}

}

two_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos + 1, filename = lexer.filename}

}

n_char_span :: proc(lexer: Lexer, n: int) -> Span {
	return Span{start = lexer.pos, end = lexer.pos + n - 1, filename = lexer.filename}
}

span_to_location :: proc(span: Span) -> (line: int, col: int) {
	starts := compiler.line_starts[span.filename]
	if len(starts) == 0 {
		// Span without a known file — usually an Ast_Node whose `.span` was
		// never populated. Return a sentinel so error reporting doesn't crash;
		// grep error output for `:1:1` to find the offending construction site.
		return 1, 1
	}
	pos := span.start
	// Find the last line_start that is <= pos
	result_line := 0
	for i in 0 ..< len(starts) {
		if starts[i] <= pos {
			result_line = i
		} else {
			break
		}
	}
	return result_line + 1, pos - starts[result_line] + 1
}
