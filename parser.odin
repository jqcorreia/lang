package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

advance :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

match :: proc(p: ^Parser, kind: Token_Kind) -> bool {
	if current(p).kind == kind {
		p.pos += 1
		return true
	}
	return false
}
expect :: proc(p: ^Parser, kind: Token_Kind) {
	if current(p).kind != kind {
		panic(fmt.tprintf("Expected %v, got %v", kind, current(p).kind))
	}
	advance(p)
}

precedence :: proc(op: Token_Kind) -> int {
	#partial switch op {
	case .Plus, .Minus:
		return 10
	case .Star, .Slash:
		return 20
	}
	return -1
}

parse_expression :: proc(p: ^Parser, min_lbp: int = 0) -> ^Expr {
	t := advance(p)

	left: ^Expr

	#partial switch t.kind {
	case .Number:
		left = make_expr_int_lit(i64(t.value))
	case .LParen:
		left = parse_expression(p, 0)
		expect(p, .RParen)
	case:
		panic("Invalid expression")
	}

	for {
		op := current(p)
		fmt.println(op)
		lbp := precedence(op.kind)

		if lbp < min_lbp do break
		advance(p)

		rbp := lbp + 1

		right := parse_expression(p, rbp)
		left = make_expr_binary(left = left, right = right, op = op.kind)
	}
	return left
}

Expr :: struct {
	kind: Expr_Kind,
	data: Expr_Data,
}

Expr_Kind :: enum {
	Int_Lit,
	Binary,
}

Expr_Data :: union {
	Expr_Int_Lit,
	Expr_Binary,
}

Expr_Int_Lit :: struct {
	value: i64,
}

Expr_Binary :: struct {
	op:          Token_Kind,
	left, right: ^Expr,
}

make_expr_int_lit :: proc(value: i64) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Int_Lit
	expr.data = Expr_Int_Lit {
		value = value,
	}
	return expr
}

make_expr_binary :: proc(left, right: ^Expr, op: Token_Kind) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Binary
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}
