package main

import "core:fmt"
import "core:strings"

expr_print_sb :: proc(expr: ^Expr, lvl: u32 = 0) -> string {
	sb := strings.builder_make()
	if expr == nil {
		return fmt.sbprint(&sb, "")
	}
	for _ in 0 ..< lvl {
		fmt.sbprint(&sb, " ")
	}
	#partial switch e in expr {
	case Expr_Int_Literal:
		fmt.sbprint(&sb, "Int ", expr.(Expr_Int_Literal).value)
	case Expr_Variable:
		fmt.sbprint(&sb, "Identifier ", expr.(Expr_Variable).value)
	case Expr_Binary:
		fmt.sbprintln(&sb, "Binary ", e.op)
		fmt.sbprintln(&sb, expr_print_sb(e.left, lvl + 1))
		fmt.sbprintln(&sb, expr_print_sb(e.right, lvl + 1))
	}

	return strings.to_string(sb)
}

statement_print :: proc(s: ^Ast_Node, lvl: u32 = 0) {
	if s == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch node in s.node {
	case Ast_Assignment:
		fmt.println("Assignment ", node.name)
		expr_print(node.expr, lvl + 1)
	case Ast_Expr:
		expr_print(node.expr, lvl + 1)
	case Ast_Function:
		fmt.println("Function", node.name, node.params)
		for st in node.body.statements {
			statement_print(st, lvl + 1)
		}
	}
}

expr_print :: proc(expr: ^Expr, lvl: u32 = 0) {
	if expr == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch e in expr {
	case Expr_Int_Literal:
		fmt.println("Int ", e.value)
	case Expr_Variable:
		fmt.println("Identifier ", e.value)
	case Expr_Binary:
		fmt.println("Binary ", e.op)
		expr_print(e.left, lvl + 1)
		expr_print(e.right, lvl + 1)
	case Expr_Call:
		fmt.println(e)
		fmt.println("Call ", e.callee.(Expr_Variable).value)
		for arg in e.args {
			expr_print(arg, lvl + 1)
		}
	}
}
unexpected_token :: proc(token: Token) {
	unimplemented(fmt.tprintf("Unexpected token: %s", token.lexeme))
}

one_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos}

}

two_char_span :: proc(lexer: Lexer) -> Span {
	return Span{start = lexer.pos, end = lexer.pos + 1}

}

span_to_location :: proc(span: Span) -> (line: int, col: int) {
	if len(state.line_starts) == 1 {
		return 1, span.start
	}
	idx := 0
	start := span.start
	for {
		left := state.line_starts[idx]
		right := state.line_starts[idx + 1]

		switch {
		case left <= start && right <= start:
			idx += 1
		case left <= start && right >= start:
			return idx + 1, start - left + 1
		}
	}
}
