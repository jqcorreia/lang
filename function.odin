package main

Ast_Function :: struct {
	name:          string,
	params:        []Param,
	body:          ^Ast_Block,
	ret_type_expr: Type_Expr,
	symbol:        ^Symbol,
	external:      bool,
}

Expr_Call :: struct {
	callee: ^Expr,
	args:   []^Expr,
}

function_decl_parse :: proc(p: ^Parser, external: bool = false) -> ^Ast_Function {
	func_name := expect(p, .Identifier).value.(string)
	params := function_decl_params_parse(p)
	ret_type := function_ret_type_parse(p)

	body: ^Ast_Block
	if !external {
		body = parse_block(p)
	}

	func := new(Ast_Function)

	func.name = func_name
	func.params = params
	func.body = body
	func.ret_type_expr = ret_type
	func.external = external

	return func
}

function_decl_params_parse :: proc(p: ^Parser) -> []Param {
	params: [dynamic]Param
	done := false
	expect(p, .LParen)
	for !done {
		#partial switch current(p).kind {
		case .Identifier:
			param_name := current(p).lexeme
			advance(p)
			expect(p, .Colon)
			type_expr := parse_type_expr(p)
			append(&params, Param{name = param_name, type_expr = type_expr})

		case .Ellipsis:
			append(&params, Param{variadic_marker = true})
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

function_ret_type_parse :: proc(p: ^Parser) -> Type_Expr {
	if current(p).kind == .RightArrow {
		advance(p)

		type_token := parse_type_expr(p)

		return type_token
	}

	return ""
}

function_external_block_parse :: proc(p: ^Parser, lib_name: string) -> ^Ast_Block {
	// Deduplicate linker libs
	found := false
	for lib in compiler.external_linker_libs {
		if lib == lib_name {found = true
			break
		}
	}
	if !found {append(&compiler.external_linker_libs, lib_name)}

	res: [dynamic]^Ast_Node

	expect(p, .LBrace)

	for current(p).kind != .RBrace {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		expect(p, .Func_Keyword)
		data := function_decl_parse(p, external = true)
		stmt := new(Ast_Node)
		stmt.data = data^
		append(&res, stmt)
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	sb := new(Ast_Block)
	sb.statements = res[:]
	sb.is_external_functions = true

	return sb
}

function_bind :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	data := &node.data.(Ast_Function)

	new_scope := make_scope(.Function, parent = cur_scope)
	symbol := new(Symbol)
	symbol.name = data.name
	symbol.kind = .Function
	symbol.decl = node
	symbol.scope = cur_scope
	new_scope.function = symbol
	cur_scope.symbols[data.name] = symbol
	for &param in data.params {
		sym := make_symbol(.Param)
		sym.decl = node
		sym.name = param.name
		new_scope.symbols[param.name] = sym
		param.symbol = sym
	}
	data.symbol = symbol
	if !data.external {
		get_block_symbols(data.body, new_scope)
	}
}

function_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Function)
	for &param in data.params {
		param.symbol.type = resolve_type_expr(&param.type_expr, node.scope, node.span)
	}
	data.symbol.type = resolve_type_expr(&data.ret_type_expr, node.scope, node.span)

	if !data.external {
		resolve_block_types(data.body)
	}
}

function_call_resolve :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	e := expr.data.(Expr_Call)
	func_name := e.callee.data.(Expr_Variable).value
	sym, ok := resolve_symbol(scope, func_name)
	if !ok {
		expr.type = &error_type
		return &error_type
	}
	decl := sym.decl.data.(Ast_Function)
	if sym.type == nil {
		// Not resolved yet, do it here
		type := resolve_type_expr(&decl.ret_type_expr, scope, span)
		e.callee.type = type
		sym.type = type
	} else {
		e.callee.type = sym.type
	}
	variadic_found := false
	for arg, i in e.args {
		arg.type = resolve_expr_type(arg, scope, span)

		if variadic_found || i >= len(decl.params) {
			continue
		}

		param := &decl.params[i]
		if param.variadic_marker {
			variadic_found = true
			continue
		}

		decl_type := param.symbol.type
		if decl_type == nil {
			// Not resolved yet, do it here
			param_type := resolve_type_expr(&param.type_expr, scope, span)
			param.symbol.type = param_type
			decl_type = param_type
		}
		if decl_type != nil {
			coerced_type := type_coercion(arg.type, decl_type, scope)
			if coerced_type != nil {
				set_expr_type(arg, coerced_type, scope)
			}
		}
	}
	expr.type = e.callee.type
	return e.callee.type
}
