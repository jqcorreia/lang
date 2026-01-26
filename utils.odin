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
	#partial switch expr.kind {
	case .Int_Literal:
		fmt.sbprint(&sb, "Int ", expr.data.(Expr_Int_Literal).value)
	case .Variable:
		fmt.sbprint(&sb, "Identifier ", expr.data.(Expr_Variable).value)
	case .Binary:
		data, _ := expr.data.(Expr_Binary)
		fmt.sbprintln(&sb, "Binary ", data.op)
		fmt.sbprintln(&sb, expr_print_sb(data.left, lvl + 1))
		fmt.sbprintln(&sb, expr_print_sb(data.right, lvl + 1))
	}

	return strings.to_string(sb)
}

statement_print :: proc(s: ^Statement, lvl: u32 = 0) {
	if s == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch s.kind {
	case .Assignment:
		a := s.data.(Statement_Assignment)
		fmt.println("Assignment ", a.name)
		expr_print(a.expr, lvl + 1)
	case .Expr:
		a := s.data.(Statement_Expr)
		expr_print(a.expr, lvl + 1)
	}
}

expr_print :: proc(expr: ^Expr, lvl: u32 = 0) {
	if expr == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	#partial switch expr.kind {
	case .Int_Literal:
		fmt.println("Int ", expr.data.(Expr_Int_Literal).value)
	case .Variable:
		fmt.println("Identifier ", expr.data.(Expr_Variable).value)
	case .Binary:
		data, _ := expr.data.(Expr_Binary)
		fmt.println("Binary ", data.op)
		expr_print(data.left, lvl + 1)
		expr_print(data.right, lvl + 1)
	case .Call:
		data, _ := expr.data.(Expr_Call)
		fmt.println("Call ", data.callee.data.(Expr_Variable).value)
		for arg in data.args {
			expr_print(arg, lvl + 1)
		}
	}
}
unexpected_token :: proc(token: Token) {
	unimplemented(fmt.tprintln("Unexpected token: %s", token.lexeme))
}
