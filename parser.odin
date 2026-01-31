package main

import "core:fmt"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

Ast_Node :: union {
	Ast_Expr,
	Ast_Assignment,
	Ast_Function,
	Ast_Return,
	Ast_Block,
	Ast_If,
	Ast_For,
	Ast_Break,
	Ast_Continue,
}


Ast_Expr :: struct {
	expr: ^Expr,
}

Ast_Assignment :: struct {
	name: string,
	expr: ^Expr,
}

Ast_Function :: struct {
	name:     string,
	params:   []string,
	body:     ^Ast_Block,
	ret_type: string,
}

Ast_Block :: struct {
	statements: []^Ast_Node,
	terminated: bool,
}

Ast_Return :: struct {
	expr: ^Expr,
}

Ast_If :: struct {
	cond:       ^Expr,
	then_block: ^Ast_Block,
	else_block: ^Ast_Block, // nil if no else
}

Ast_For :: struct {
	body: ^Ast_Block,
}

Ast_Break :: struct {}
Ast_Continue :: struct {}


Expr :: union {
	Expr_Int_Literal,
	Expr_Binary,
	Expr_Variable,
	Expr_Call,
}

Expr_Data :: union {}

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

parse_program :: proc(p: ^Parser) -> []^Ast_Node {
	stmts: [dynamic]^Ast_Node
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

parse_statement :: proc(p: ^Parser) -> ^Ast_Node {
	t := current(p)
	stmt := new(Ast_Node)

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

			stmt^ = Ast_Assignment {
				name = name_tok.lexeme,
				expr = parse_expression(p, 0),
			}
			expect(p, .NewLine) // This should end with newline

		case peek(p).kind == .LParen:
			// --- Function Call ---
			expr := parse_expression(p)
			stmt^ = Ast_Expr {
				expr = expr,
			}
			expect(p, .NewLine)
		case:
			unimplemented()
		}
	case t.kind == .Func_Keyword:
		advance(p)
		stmt^ = parse_function_decl(p)^
	case t.kind == .For_Keyword:
		advance(p)
		stmt^ = parse_for_loop(p)^
	case t.kind == .Break_Keyword:
		advance(p)
		stmt^ = parse_break(p)^
	case t.kind == .Continue_Keyword:
		advance(p)
		stmt^ = parse_continue(p)^
	case t.kind == .Return_Keyword:
		// --- Return statment ---
		advance(p)
		expr := parse_expression(p, 0)
		expect(p, .NewLine)

		stmt^ = Ast_Return {
			expr = expr,
		}
	case t.kind == .If_Keyword:
		advance(p)
		stmt^ = parse_if(p)^
	case:
		unimplemented(fmt.tprintf("Unexpected token: %s", token_serialize(t)))
	}
	return stmt
}

expr_int_literal :: proc(value: i64) -> ^Expr {
	expr := new(Expr_Int_Literal)
	expr.value = value

	ret := new(Expr)
	ret^ = expr^
	return ret
}

expr_binary :: proc(op: Token_Kind, left: ^Expr, right: ^Expr) -> ^Expr {
	expr := new(Expr_Binary)
	expr.op = op
	expr.left = left
	expr.right = right

	ret := new(Expr)
	ret^ = expr^
	return ret
}
expr_ident :: proc(value: string) -> ^Expr {
	expr := new(Expr_Variable)

	expr.value = value

	ret := new(Expr)
	ret^ = expr^
	return ret
}

expr_call :: proc(callee: ^Expr, args: []^Expr) -> ^Expr {
	func, ok := state.funcs[callee.(Expr_Variable).value]
	if !ok {
		panic("function not found")
	}

	if len(args) < len(func.params) {
		panic(fmt.tprintf("Missing arguments in call to function '%s'", func.name))
	}
	if len(args) > len(func.params) {
		panic(fmt.tprintf("Extra arguments in call to function '%s'", func.name))
	}

	expr := new(Expr_Call)
	expr.callee = callee
	expr.args = args

	ret := new(Expr)
	ret^ = expr^
	return ret
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

parse_function_decl :: proc(p: ^Parser) -> ^Ast_Function {
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

	func := new(Ast_Function)

	func.name = func_name
	func.params = args
	func.body = body
	func.ret_type = ret_type

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

parse_block :: proc(p: ^Parser) -> ^Ast_Block {
	res: [dynamic]^Ast_Node

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

	sb := new(Ast_Block)
	sb.statements = res[:]

	return sb
}

parse_if :: proc(p: ^Parser) -> ^Ast_If {
	cond := parse_expression(p)
	then_block := parse_block(p)
	else_block: ^Ast_Block = nil

	if current(p).kind == .Else_Keyword {
		advance(p)
		else_block = parse_block(p)
	}

	stmt_if := new(Ast_If)
	stmt_if.cond = cond
	stmt_if.then_block = then_block
	stmt_if.else_block = else_block

	return stmt_if
}

parse_for_loop :: proc(p: ^Parser) -> ^Ast_For {
	// No condition parsing for now

	stmt := new(Ast_For)
	stmt.body = parse_block(p)

	return stmt
}

parse_break :: proc(p: ^Parser) -> ^Ast_Break {
	stmt := new(Ast_Break)

	expect(p, .NewLine)
	return stmt
}

parse_continue :: proc(p: ^Parser) -> ^Ast_Continue {
	stmt := new(Ast_Continue)

	expect(p, .NewLine)
	return stmt
}
