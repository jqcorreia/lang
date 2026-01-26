package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

Statement :: struct {
	kind: Statement_Kind,
	data: Statement_Data,
}

Statement_Kind :: enum {
	Expr,
	Assignment,
	Function,
}

Statement_Data :: union {
	Statement_Expr,
	Statement_Assignment,
	Statement_Function,
}

Statement_Expr :: struct {
	expr: ^Expr,
}

Statement_Assignment :: struct {
	name: string,
	expr: ^Expr,
}

Statement_Function :: struct {
	name:   string,
	params: []string,
	body:   []^Statement,
}

Expr :: struct {
	kind: Expr_Kind,
	data: Expr_Data,
}

Expr_Kind :: enum {
	Int_Literal,
	Binary,
	Variable,
	Call,
}

Expr_Data :: union {
	Expr_Int_Literal,
	Expr_Binary,
	Expr_Variable,
	Expr_Call,
}

Expr_Int_Literal :: struct {
	value: i64,
}

Expr_Binary :: struct {
	op:    Token_Kind,
	left:  ^Expr,
	right: ^Expr,
}

Expr_Variable :: struct {
	value: string,
}

Expr_Call :: struct {
	callee: ^Expr,
	args:   []^Expr,
}

current :: proc(p: ^Parser) -> Token {
	return p.tokens[p.pos]
}

peek :: proc(p: ^Parser, n: int = 1) -> Token {
	return p.tokens[p.pos + n]
}

advance :: proc(p: ^Parser) -> Token {
	t := p.tokens[p.pos]
	p.pos += 1
	return t
}

expect :: proc(p: ^Parser, kind: Token_Kind) -> Token {
	if current(p).kind != kind {
		panic(fmt.tprintf("Expected %v, got %v", kind, current(p).kind))
	}
	return advance(p)
}

parse_program :: proc(p: ^Parser) -> []^Statement {
	stmts: [dynamic]^Statement
	done := false
	for !done {
		t := current(p)
		// fmt.println(t)
		switch {
		case t.kind == .EOF:
			done = true
		case t.kind == .Identifier:
			switch {
			// ASSIGNMENT
			case peek(p).kind == .Equal:
				// Get variable name
				name_tok := current(p)

				// Advance and expect an '='
				advance(p)
				expect(p, .Equal)

				// Construct statement
				s := new(Statement)
				s.kind = .Assignment
				s.data = Statement_Assignment {
					name = name_tok.lexeme,
					expr = parse_expression(p, 0),
				}

				append(&stmts, s)
				expect(p, .NewLine) // This should end with newline
			// FUNCTION CALL
			case peek(p).kind == .LParen:
				expr := parse_expression(p)

				s := new(Statement)
				s.kind = .Expr
				s.data = Statement_Expr {
					expr = expr,
				}
				append(&stmts, s)
				expect(p, .NewLine)
			case:
				unimplemented()
			}
		case t.kind == .Func_Keyword:
			advance(p)
			parse_function_decl(p)
		case:
			unimplemented(fmt.tprintf("Unexpected token: %s", t.lexeme))
		}
	}

	return stmts[:]
}

expr_int_literal :: proc(value: i64) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Int_Literal
	expr.data = Expr_Int_Literal {
		value = value,
	}

	return expr
}
expr_binary :: proc(op: Token_Kind, left: ^Expr, right: ^Expr) -> ^Expr {
	expr := new(Expr)

	expr.kind = .Binary
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}
expr_ident :: proc(value: string) -> ^Expr {
	expr := new(Expr)

	expr.kind = .Variable

	expr.data = Expr_Variable {
		value = value,
	}
	return expr

}

expr_call :: proc(callee: ^Expr, args: []^Expr) -> ^Expr {
	expr := new(Expr)
	expr.kind = .Call
	expr.data = Expr_Call {
		callee = callee,
		args   = args,
	}
	return expr
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

parse_expression :: proc(p: ^Parser, min_lbp: int = 0) -> ^Expr {
	t := advance(p)

	left: ^Expr

	#partial switch t.kind {
	case .Number:
		left = expr_int_literal(i64(t.value.(int)))
	case .Identifier:
		left = expr_ident(t.value.(string))
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
			left = expr_call(left, args)
		case:
			rbp := lbp + 1

			right := parse_expression(p, rbp)
			left = expr_binary(left = left, right = right, op = op.kind)
		}
	}
	return left
}

parse_call_args :: proc(p: ^Parser) -> []^Expr {
	args: [dynamic]^Expr

	// '(' already consumed
	if current(p).kind == .RParen {
		advance(p)
		return args[:]
	}

	for {
		arg := parse_expression(p, 0)
		append(&args, arg)

		if current(p).kind == .Comma {
			advance(p)
			continue
		}

		break
	}

	expect(p, .RParen)
	return args[:]
}

parse_function_decl :: proc(p: ^Parser) -> ^Statement {
	func_name := expect(p, .Identifier).value.(string)
	fmt.println(func_name)
	args := parse_function_decl_params(p)

	func := new(Statement)
	func.kind = .Function

	func.data = Statement_Function {
		name   = func_name,
		params = args,
		body   = parse_function_body(p),
	}
	return func
}

parse_function_decl_params :: proc(p: ^Parser) -> []string {
	params: [dynamic]string
	done := false
	expect(p, .LParen)
	for !done {
		arg_name := expect(p, .Identifier).lexeme
		append(&params, arg_name)

		#partial switch current(p).kind {
		case .Comma:
			advance(p)
		case .RParen:
			advance(p)
			done = true
		case:
			unexpected_token(current(p))
		}
	}

	return params[:]
}

parse_function_body :: proc(p: ^Parser) -> []^Statement {
	expect(p, .LBrace)

	for advance(p).kind != .RBrace {}
	advance(p)

	return {}
}
