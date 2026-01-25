package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

Stmt :: struct {
	kind: Stmt_Kind,
	data: Stmt_Data,
}

Stmt_Kind :: enum {
	Expr,
	Let,
	Block,
}

Stmt_Data :: union {
	Stmt_Expr,
	Stmt_Let,
	Stmt_Block,
}

Stmt_Expr :: struct {
	expr: ^Expr,
}

Stmt_Let :: struct {
	name:  string,
	value: ^Expr,
}

Stmt_Block :: struct {
	stmts: []^Stmt,
}

Expr :: struct {
	kind: Expr_Kind,
	data: Expr_Data,
}

Expr_Kind :: enum {
	Int_Lit,
	Binary,
	Ident,
	Call,
}

Expr_Data :: union {
	Expr_Int_Lit,
	Expr_Binary,
	Expr_Ident,
	Expr_Call,
}

Expr_Int_Lit :: struct {
	value: i64,
}

Expr_Ident :: struct {
	value: string,
}

Expr_Binary :: struct {
	op:          Token_Kind,
	left, right: ^Expr,
}

Expr_Call :: struct {
	callee: string,
	args:   []^Expr,
}

current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

peek :: proc(p: ^Parser, n: u32 = 1) -> Token {
	if p.pos + 1 > len(p.tokens) - 1 {
		panic("peek failed")
	}
	return p.tokens[p.pos + 1]
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
	case .LParen:
		return 200
	case .Plus, .Minus:
		return 10
	case .Star, .Slash:
		return 20
	}
	return -1
}

parse_assign_stmt :: proc(p: ^Parser) -> ^Stmt {
	name_tok := current(p)
	advance(p)

	expect(p, .Equal)

	value := parse_expression(p, 0)
	expect(p, .NewLine)

	return make_stmt_let(name_tok.value.(string), value)
}

parse_expr_stmt :: proc(p: ^Parser) -> ^Stmt {
	expr := parse_expression(p)
	return make_stmt_expr(expr)
}

parse_call_args :: proc(p: ^Parser) -> []^Expr {
	res: [dynamic]^Expr

	t := current(p)
	for t.kind != .RParen {
		t = advance(p)
	}

	append(&res, make_expr_int_lit(67))

	return res[:]
}

parse_expression :: proc(p: ^Parser, min_lbp: int = 0) -> ^Expr {
	t := advance(p)

	left: ^Expr

	#partial switch t.kind {
	case .Number:
		left = make_expr_int_lit(i64(t.value.(int)))
	case .Identifier:
		left = make_expr_ident(t.value.(string))
	case .LParen:
		left = parse_expression(p, 0)
		expect(p, .RParen)
	case:
		panic("Invalid expression")
	}

	for {
		op := current(p)
		lbp := precedence(op.kind)

		if lbp < min_lbp do break
		advance(p)

		#partial switch op.kind {
		case .LParen:
			args := parse_call_args(p)
			left = make_expr_call(left.data.(Expr_Ident).value, args)
		case:
			rbp := lbp + 1

			right := parse_expression(p, rbp)
			left = make_expr_binary(left = left, right = right, op = op.kind)
		}
	}
	return left
}
parse_statement :: proc(p: ^Parser) -> ^Stmt {
	#partial switch current(p).kind {
	case .Identifier:
		if peek(p).kind == .LParen {
			return parse_expr_stmt(p)
		}
		return parse_assign_stmt(p)
	case:
		error := fmt.tprintf("Error on token %s", current(p).kind)
		panic(error)
	}
	return nil
}

parse_program :: proc(p: ^Parser) -> []^Stmt {
	stmts: [dynamic]^Stmt

	for current(p).kind != .EOF {
		append(&stmts, parse_statement(p))
	}

	return stmts[:]
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

make_expr_ident :: proc(value: string) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Ident
	expr.data = Expr_Ident {
		value = value,
	}
	return expr
}

make_expr_call :: proc(callee: string, args: []^Expr) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Call
	expr.data = Expr_Call {
		callee = callee,
		args   = args,
	}
	return expr
}


make_stmt_expr :: proc(expr: ^Expr) -> ^Stmt {
	s := new(Stmt)
	s.kind = .Expr
	s.data = Stmt_Expr {
		expr = expr,
	}
	return s
}

make_stmt_let :: proc(name: string, value: ^Expr) -> ^Stmt {
	s := new(Stmt)
	s.kind = .Let
	s.data = Stmt_Let {
		name  = name,
		value = value,
	}
	return s
}

make_stmt_block :: proc(stmts: []^Stmt) -> ^Stmt {
	s := new(Stmt)
	s.kind = .Block
	s.data = Stmt_Block {
		stmts = stmts,
	}
	return s
}
