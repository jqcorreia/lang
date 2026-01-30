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
	Return,
	Block,
	If,
	For,
	Break,
	Continue,
}

Statement_Data :: union {
	Statement_Expr,
	Statement_Assignment,
	Statement_Function,
	Statement_Return,
	Statement_Block,
	Statement_If,
	Statement_For,
	Statement_Break,
	Statement_Continue,
}


Statement_Expr :: struct {
	expr: ^Expr,
}

Statement_Assignment :: struct {
	name: string,
	expr: ^Expr,
}

Statement_Function :: struct {
	name:     string,
	params:   []string,
	body:     ^Statement_Block,
	ret_type: string,
}

Statement_Block :: struct {
	statements: []^Statement,
	terminated: bool,
}

Statement_Return :: struct {
	expr: ^Expr,
}

Statement_If :: struct {
	cond:       ^Expr,
	then_block: ^Statement_Block,
	else_block: ^Statement_Block, // nil if no else
}

Statement_For :: struct {
	body: ^Statement_Block,
}

Statement_Break :: struct {}
Statement_Continue :: struct {}

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
	for {
		t := current(p)
		if t.kind == .EOF do break

		// Deal with rogue newlines, like at the beginning of a line
		if t.kind == .NewLine {
			advance(p)
			continue
		}

		stmt := parse_statement(p)
		append(&stmts, stmt)
	}

	return stmts[:]
}

parse_statement :: proc(p: ^Parser) -> ^Statement {
	t := current(p)
	stmt: ^Statement
	switch {
	case t.kind == .Identifier:
		switch {
		case peek(p).kind == .Equal:
			// --- Assignment ---
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

			stmt = s
			expect(p, .NewLine) // This should end with newline
		case peek(p).kind == .LParen:
			// --- Function Call ---
			expr := parse_expression(p)

			s := new(Statement)
			s.kind = .Expr
			s.data = Statement_Expr {
				expr = expr,
			}
			stmt = s
			expect(p, .NewLine)
		case:
			unimplemented()
		}
	case t.kind == .Func_Keyword:
		advance(p)
		stmt = parse_function_decl(p)
	case t.kind == .For_Keyword:
		advance(p)
		stmt = parse_for_loop(p)
	case t.kind == .Break_Keyword:
		advance(p)
		stmt = parse_break(p)
	case t.kind == .Continue_Keyword:
		advance(p)
		stmt = parse_continue(p)
	case t.kind == .Return_Keyword:
		// --- Return statment ---
		advance(p)
		expr := parse_expression(p, 0)
		expect(p, .NewLine)

		s := new(Statement)
		s.kind = .Return
		s.data = Statement_Return {
			expr = expr,
		}
		stmt = s
	case t.kind == .If_Keyword:
		advance(p)
		stmt = parse_if(p)
	case:
		unimplemented(fmt.tprintf("Unexpected token: %s", token_serialize(t)))
	}
	return stmt
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
	func, ok := state.funcs[callee.data.(Expr_Variable).value]
	if !ok {
		panic("function not found")
	}

	if len(args) < len(func.params) {
		panic(fmt.tprintf("Missing arguments in call to function '%s'", func.name))
	}
	if len(args) > len(func.params) {
		panic(fmt.tprintf("Extra arguments in call to function '%s'", func.name))
	}

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
	case .Star, .Slash:
		return 20
	case .Plus, .Minus:
		return 10
	case .Lesser, .Greater, .GreaterOrEqual, .LesserOrEqual, .DoubleEqual:
		return 5
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
	args := parse_function_decl_params(p)
	ret_type := parse_function_ret_type(p)

	// Initial declaration of a function
	state.funcs[func_name] = {
		name        = func_name,
		params      = args,
		return_type = ret_type,
	}

	body := parse_block(p)

	func := new(Statement)
	func.kind = .Function

	func.data = Statement_Function {
		name     = func_name,
		params   = args,
		body     = body,
		ret_type = ret_type,
	}
	return func
}

parse_function_decl_params :: proc(p: ^Parser) -> []string {
	params: [dynamic]string
	done := false
	expect(p, .LParen)
	for !done {
		// if current(p).kind == .RParen {
		// 	advance(p)
		// 	return params[:]
		// }
		// arg_name := expect(p, .Identifier).lexeme
		// append(&params, arg_name)

		#partial switch current(p).kind {
		case .Identifier:
			arg_name := current(p).lexeme
			append(&params, arg_name)
			advance(p)
		case .Comma:
			if peek(p).kind == .RParen {
				unexpected_token(peek(p))
			}
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

parse_function_ret_type :: proc(p: ^Parser) -> string {
	if current(p).kind == .RightArrow {
		advance(p)
		type := expect(p, .Identifier)

		return type.value.(string)
	}

	return ""
}

parse_block :: proc(p: ^Parser) -> ^Statement_Block {
	res: [dynamic]^Statement

	expect(p, .LBrace)

	if current(p).kind == .NewLine do advance(p)

	for current(p).kind != .RBrace {
		stmt := parse_statement(p)
		statement_print(stmt)
		append(&res, stmt)
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	sb := new(Statement_Block)
	sb.statements = res[:]

	return sb
}

parse_if :: proc(p: ^Parser) -> ^Statement {
	cond := parse_expression(p)
	then_block := parse_block(p)
	else_block: ^Statement_Block = nil

	if current(p).kind == .Else_Keyword {
		advance(p)
		else_block = parse_block(p)
	}

	stmt_if: Statement_If = {
		cond       = cond,
		then_block = then_block,
		else_block = else_block,
	}

	stmt := new(Statement)
	stmt.kind = .If
	stmt.data = stmt_if

	return stmt
}

parse_for_loop :: proc(p: ^Parser) -> ^Statement {
	// No condition parsing for now

	stmt := new(Statement)
	stmt.kind = .For
	stmt.data = Statement_For {
		body = parse_block(p),
	}

	return stmt
}

parse_break :: proc(p: ^Parser) -> ^Statement {
	stmt := new(Statement)
	stmt.kind = .Break
	stmt.data = Statement_Break{}

	expect(p, .NewLine)
	return stmt
}

parse_continue :: proc(p: ^Parser) -> ^Statement {
	stmt := new(Statement)
	stmt.kind = .Continue
	stmt.data = Statement_Continue{}

	expect(p, .NewLine)
	return stmt
}
