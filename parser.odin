package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

Parser :: struct {
	tokens: []Token,
	pos:    int,
}

Ast_Module :: []^Ast_Node


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

skip_newlines :: proc(p: ^Parser) {
	for {
		if current(p).kind == .NewLine do advance(p)
		else do break
	}
}

expect :: proc(p: ^Parser, kind: Token_Kind, loc := #caller_location) -> Token {
	if current(p).kind != kind {
		fmt.println(loc)
		fatal_token(
			current(p),
			"Expected %v, got %v with lexeme '%s'",
			kind,
			current(p).kind,
			current(p).lexeme,
		)
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
		// Doing this here so I can directly expand the imports and do so recursively
		// This is the basic implementation of it, this must go somewhere else
		if t.kind == .Import_Keyword {
			// Add the parse_statement to the AST preparing for further work on this
			import_stmt := parse_statement(p)
			append(&stmts, import_stmt)

			import_node := import_stmt.data.(Ast_Import)
			raw_path := import_node.path

			// Resolve import path:
			//   "std:c"         -> <exe_dir>/std/c.z  (compiler-relative, ":" as collection separator)
			//   "vendor/raylib" -> <source_dir>/vendor/raylib.z (source-relative)
			resolved_path: string
			if colon_idx := strings.index(raw_path, ":"); colon_idx >= 0 {
				collection := raw_path[:colon_idx]
				rest := raw_path[colon_idx + 1:]
				resolved_path, _ = filepath.join(
					{compiler.exe_dir, collection, rest},
					context.allocator,
				)
			} else {
				resolved_path, _ = filepath.join(
					{compiler.current_filepath, raw_path},
					context.allocator,
				)
			}
			if !strings.ends_with(resolved_path, ".z") {
				resolved_path = fmt.tprintf("%s.z", resolved_path)
			}
			contents :=
				os.read_entire_file(resolved_path, context.allocator) or_else panic(
					fmt.tprintf("Import not found: %s", resolved_path),
				)
			import_tokens := lex(string(contents))
			import_parser := Parser {
				tokens = import_tokens,
			}

			import_stmts := parse_program(&import_parser)
			for s in import_stmts do append(&stmts, s)
			continue
		}

		stmt := parse_statement(p)
		append(&stmts, stmt)
	}

	return stmts[:]
}

parse_statement :: proc(p: ^Parser) -> ^Ast_Node {
	t := current(p)
	span := Span {
		start = t.span.start,
	}
	ast_node := new(Ast_Node)
	data := &ast_node.data

	switch {
	case t.kind == .Import_Keyword:
		advance(p)
		data^ = parse_import(p)^
	case t.kind == .External_Keyword:
		advance(p)
		lib_name := expect(p, .QuotedString)
		data^ = function_external_block_parse(p, lib_name.value.(string))^
	case t.kind == .Identifier:
		data^ = parse_identifier(p)
	case t.kind == .Star:
		data^ = parse_deref(p)
	case t.kind == .Func_Keyword:
		advance(p)
		data^ = function_decl_parse(p, external = false)^
	case t.kind == .Struct_Keyword:
		advance(p)
		data^ = struct_decl_parse(p)^
	case t.kind == .Enum_Keyword:
		advance(p)
		data^ = enum_decl_parse(p)^
	case t.kind == .For_Keyword:
		advance(p)
		data^ = parse_for_loop(p)^
	case t.kind == .Break_Keyword:
		advance(p)
		data^ = parse_break(p)^
	case t.kind == .Continue_Keyword:
		advance(p)
		data^ = parse_continue(p)^
	case t.kind == .Return_Keyword:
		advance(p)
		expr: ^Expr
		if current(p).kind != .NewLine {
			expr = parse_expression(p, 0)
		}
		expect(p, .NewLine)

		data^ = Ast_Return {
			expr = expr,
		}
	case t.kind == .If_Keyword:
		advance(p)
		data^ = parse_if(p)^
	case:
		unimplemented(fmt.tprintf("Unexpected token: %s", token_serialize(t)))
	}
	span.end = current(p).span.end
	ast_node.span = span
	return ast_node
}


parse_identifier :: proc(p: ^Parser) -> Ast_Data {
	switch {
	case peek(p).kind == .Equal:
		// --- Assignment ---
		// Get variable name
		lhs := parse_expression(p, 0)

		// Advance and expect an '='
		// advance(p)
		expect(p, .Equal)

		data := Ast_Var_Assign {
			lhs  = lhs,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine) // This should end with newline

		return data

	case peek(p).kind == .Period:
		// --- Member assignment: foo.bar = expr ---
		lhs := parse_expression(p, 0)
		expect(p, .Equal)

		data := Ast_Var_Assign {
			lhs  = lhs,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine)

		return data

	case peek(p).kind == .LParen:
		// --- Function Call ---
		expr := parse_expression(p)
		expect(p, .NewLine)
		return Ast_Expr{expr = expr}

	case peek(p).kind == .ColonEqual:
		// --- Assignment and initialization---
		// Get variable name
		name_tok := current(p)

		// Advance and expect an '='
		advance(p)
		expect(p, .ColonEqual)

		data := Ast_Var_Decl {
			name = name_tok.lexeme,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine) // This should end with newline
		return data

	case peek(p).kind == .Colon:
		// Get variable name
		name_tok := current(p)

		advance(p)
		expect(p, .Colon)

		// type_expr := expect(p, .Identifier).lexeme
		type_expr := parse_type_expr(p)
		default_value_expr: ^Expr
		if current(p).kind == .Equal {
			advance(p)
			default_value_expr = parse_expression(p, 0)
		}

		return Ast_Var_Decl {
			name = name_tok.lexeme,
			type_expr = type_expr,
			expr = default_value_expr,
		}
	case peek(p).kind == .LBracket:
		// --- Member assignment: foo.bar = expr ---
		lhs := parse_expression(p, 0)
		expect(p, .Equal)

		data := Ast_Var_Assign {
			lhs  = lhs,
			expr = parse_expression(p, 0),
		}

		expect(p, .NewLine)

		return data

	case:
		next_token := peek(p)
		fatal_token(next_token, "Unexpected token %s", next_token.kind)
	}
	panic("Should be unreachable")
}

parse_deref :: proc(p: ^Parser) -> Ast_Data {
	lhs := parse_expression(p, 0)
	expect(p, .Equal)
	data := Ast_Var_Assign {
		lhs  = lhs,
		expr = parse_expression(p, 0),
	}
	expect(p, .NewLine)
	return data
}

parse_type_expr :: proc(p: ^Parser) -> Type_Expr {
	#partial switch current(p).kind {
	case .Ampersand:
		advance(p)
		elem_expr := new(Type_Expr)
		elem_expr^ = parse_type_expr(p)

		expr := Type_Expr_Pointer {
			pointee = elem_expr,
		}
		return expr
	case .Identifier:
		return advance(p).value.(string)
	case .LBracket:
		advance(p)
		size_token := expect(p, .Number)
		expect(p, .RBracket)
		elem_expr := new(Type_Expr)
		elem_expr^ = parse_type_expr(p)
		expr := Type_Expr_Array {
			size = u64(size_token.value.(int)),
			elem = elem_expr,
		}
		return expr
	case:
		fatal_token(current(p), "Unexpected token in type expression")
	}
	return Type_Expr{}
}

expr_int_literal :: proc(value: i64) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Int_Literal {
		value = value,
	}
	return ret
}
expr_float_literal :: proc(value: f64) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Float_Literal {
		value = value,
	}
	return ret
}

expr_string_literal :: proc(value: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_String_Literal {
		value = value,
	}
	return ret
}

expr_null_literal :: proc() -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Null{}

	return ret
}

expr_unary :: proc(op: Token_Kind, e: ^Expr) -> ^Expr {
	expr := new(Expr)
	expr.data = Expr_Unary {
		op   = op,
		expr = e,
	}
	return expr
}

expr_binary :: proc(op: Token_Kind, left: ^Expr, right: ^Expr) -> ^Expr {
	expr := new(Expr)
	expr.data = Expr_Binary {
		op    = op,
		left  = left,
		right = right,
	}
	return expr
}

expr_ident :: proc(value: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Variable {
		value = value,
	}

	return ret
}

expr_call :: proc(callee: ^Expr, args: []^Expr, method: bool = false) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Call {
		callee = callee,
		args   = args,
		method = method,
	}
	return ret
}

expr_member :: proc(left: ^Expr, field_name: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Member {
		base   = left,
		member = field_name,
		kind   = .Field,
	}

	return ret
}

expr_implicit_variant :: proc(name: string) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Implicit_Variant {
		name = name,
	}
	return ret
}

expr_index :: proc(left: ^Expr, index: ^Expr) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Index {
		array = left,
		index = index,
	}

	return ret
}

expr_bool_literal :: proc(kind: Token_Kind) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Bool_Literal {
		value = kind == .True_Keyword ? true : false,
	}

	return ret
}
precedence :: proc(op: Token_Kind) -> int {
	#partial switch op {
	case .LParen:
		return 200
	case .LBracket:
		return 200
	case .Period:
		return 200
	case .Caret:
		return 100
	case .Star, .Slash, .Percent:
		return 20
	case .Plus, .Minus:
		return 10
	case .Lesser, .Greater, .GreaterOrEqual, .LesserOrEqual, .DoubleEqual, .NotEqual:
		return 5
	case .DoublePipe, .DoubleAmpersand:
		return 4
	case .DotDot, .DotDotEq:
		return 3
	}
	return -1
}

prefix_precedence :: proc(op: Token_Kind) -> int {
	#partial switch op {
	case .Ampersand:
		return 50
	case .Star:
		return 50
	case .Minus:
		return 50
	case .Bang:
		return 50
	}
	return -1
}

parse_expression :: proc(
	p: ^Parser,
	min_lbp: int = 0,
	allow_struct_literal: bool = true,
) -> ^Expr {
	t := advance(p)

	left: ^Expr

	#partial switch t.kind {
	case .Number:
		#partial switch v in t.value {
		case int:
			left = expr_int_literal(i64(v))
		case f64:
			left = expr_float_literal(v)
		case:
			panic("Number token can't have other types than int or f64")
		}
	case .True_Keyword, .False_Keyword:
		left = expr_bool_literal(t.kind)
	case .Nil_Keyword:
		left = expr_null_literal()
	case .QuotedString:
		left = expr_string_literal(t.value.(string))
	case .Identifier:
		if allow_struct_literal && current(p).kind == .LBrace {
			left = parse_struct_literal(p, t.value.(string))
		} else {
			left = expr_ident(t.value.(string))
		}
	case .LParen:
		left = parse_expression(p, 0, true) // parentheses reset the context
		expect(p, .RParen)
	case .Minus, .Bang, .Ampersand, .Star:
		// Negative values, negation, address_of, dereference
		rbp := prefix_precedence(t.kind)
		right := parse_expression(p, rbp, allow_struct_literal)
		left = expr_unary(t.kind, right)
	case .LBracket:
		elements: [dynamic]^Expr
		for current(p).kind != .RBracket {
			skip_newlines(p)
			if current(p).kind == .RBracket do break // Skip newlines can land on rbracket
			append(&elements, parse_expression(p, 0))
			if current(p).kind == .Comma do advance(p)
		}
		expect(p, .RBracket)
		left = new(Expr)
		left.data = Expr_Array_Literal {
			elements = elements[:],
		}
	case .Period:
		// Implicit enum variant selector: `.VariantName`. The expected enum
		// type is supplied later from context (var decl LHS, call arg, etc.).
		name := expect(p, .Identifier).value.(string)
		left = expr_implicit_variant(name)
	case:
		fatal_token(current(p), "Invalid token in expression")
	}

	for {
		op := current(p)
		lbp := precedence(op.kind)

		if lbp < min_lbp do break
		advance(p)

		#partial switch op.kind {
		case .LBracket:
			index := parse_expression(p, 0)
			expect(p, .RBracket)
			left = expr_index(left, index)
		case .LParen:
			args := parse_call_args(p)
			left = expr_call(left, args)
		case .Period:
			field_name := expect(p, .Identifier).value.(string)
			if current(p).kind == .LParen {
				advance(p) // consume '(' — parse_call_args expects it already eaten
				rest := parse_call_args(p)
				all := make([]^Expr, len(rest) + 1)
				all[0] = left
				for a, i in rest do all[i + 1] = a
				left = expr_call(expr_ident(field_name), all, method = true)
			} else {
				left = expr_member(left, field_name)
			}
		case .DotDot, .DotDotEq:
			right := parse_expression(p, lbp + 1, allow_struct_literal)
			range := new(Expr)
			range.data = Expr_Range {
				start     = left,
				end       = right,
				inclusive = op.kind == .DotDotEq,
			}
			left = range
		case:
			rbp := lbp + 1

			right := parse_expression(p, rbp, allow_struct_literal)
			left = expr_binary(op.kind, left, right)
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


parse_struct_literal :: proc(p: ^Parser, struct_name: string) -> ^Expr {
	result := new(Expr)

	lit := Expr_Struct_Literal{}
	lit.type_expr = struct_name

	parse_struct_literal_fields(p, &lit)
	result.data = lit

	return result
}

parse_struct_literal_fields :: proc(p: ^Parser, struct_expr: ^Expr_Struct_Literal) {
	done := false
	expect(p, .LBrace)
	for !done {
		#partial switch current(p).kind {
		case .Identifier:
			field_name := current(p).lexeme
			advance(p)
			expect(p, .Equal)
			struct_expr.args[field_name] = parse_expression(p, 0)
		case .Comma:
			if peek(p).kind == .RBrace {
				unexpected_token(peek(p))
			}
			advance(p)
		case .RBrace:
			advance(p)
			done = true
		case .NewLine:
			advance(p)
		case:
			unexpected_token(current(p))
		}
	}
}

parse_block :: proc(p: ^Parser) -> ^Ast_Block {
	res: [dynamic]^Ast_Node

	expect(p, .LBrace)

	for current(p).kind != .RBrace {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		stmt := parse_statement(p)
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
	cond := parse_expression(p, 0, false)
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
	stmt := new(Ast_For)

	if current(p).kind == .Identifier && peek(p).kind == .In_Keyword {
		stmt.iterator = advance(p).value.(string) // consume iterator name
		advance(p) // consume 'in'
		stmt.range = parse_expression(p, 0, false)
	}

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

parse_import :: proc(p: ^Parser) -> ^Ast_Import {
	stmt := new(Ast_Import)

	filepath := expect(p, .QuotedString).value.(string)
	stmt.path = filepath

	if current(p).kind == .Identifier {
		stmt.identifier = current(p).value.(string)
		advance(p)
	}

	return stmt
}
