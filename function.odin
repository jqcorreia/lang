package main

import "core:strings"

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
	method: bool, // true if desugared from receiver.method(args) — enables auto-ref/deref on arg 0
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
	for i in 0 ..< len(e.args) {
		arg := e.args[i]
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

		// Auto-ref / auto-deref the receiver of a method-style call
		if e.method && i == 0 && decl_type != nil && arg.type != nil {
			if decl_type.kind == .Pointer &&
			   arg.type.kind != .Pointer &&
			   decl_type.pointee_type == arg.type {
				wrapped := new(Expr)
				wrapped.data = Expr_Unary {
					op   = .Ampersand,
					expr = arg,
				}
				wrapped.type = decl_type
				e.args[i] = wrapped
				arg = wrapped
			} else if arg.type.kind == .Pointer &&
			   decl_type.kind != .Pointer &&
			   arg.type.pointee_type == decl_type {
				wrapped := new(Expr)
				wrapped.data = Expr_Unary {
					op   = .Star,
					expr = arg,
				}
				wrapped.type = decl_type
				e.args[i] = wrapped
				arg = wrapped
			}
		}

		if decl_type != nil {
			coerced_type := coerce(arg.type, decl_type, scope)
			if coerced_type != nil {
				set_expr_type(arg, coerced_type, scope)
			}
		}
	}
	expr.type = e.callee.type
	return e.callee.type
}

function_check :: proc(c: ^Checker, s: ^Ast_Function, scope: ^Scope, span: Span) {
	for param in s.params {
		if !param.variadic_marker &&
		   (param.symbol.type == nil || param.symbol.type.kind == .Error) {
			error_span(
				span,
				"Unresolved type '%s' for parameter '%s'",
				param.type_expr,
				param.name,
			)
		}
	}
	if s.symbol.type == nil || s.symbol.type.kind == .Error {
		error_span(span, "Unresolved return type '%s' for '%s'", s.ret_type_expr, s.name)
	}
	if !s.external {
		old_function := c.current_function
		c.current_function = s.symbol
		check_block(c, s.body, span)
		c.current_function = old_function
	}
}

function_call_check :: proc(
	c: ^Checker,
	e: Expr_Call,
	call_expr: ^Expr,
	scope: ^Scope,
	span: Span,
) {
	func_name := e.callee.data.(Expr_Variable).value
	sym, ok := resolve_symbol(scope, func_name)
	if !ok {
		error_span(span, "Undefined function '%s'", func_name)
		return
	}
	decl := sym.decl.data.(Ast_Function)
	variadic_found := false
	required_params := 0
	for param in decl.params {
		if !param.variadic_marker {
			required_params += 1
		}
	}
	if len(e.args) < required_params {
		error_span(span, "Too few arguments for '%s'", func_name)
	}
	for arg, i in e.args {
		check_expr(c, arg, scope, span)
		if variadic_found || arg.type.kind == .Error {
			continue
		}
		if i >= len(decl.params) {
			error_span(span, "Too many arguments for '%s'", func_name)
			continue
		}
		param := decl.params[i]
		if param.variadic_marker {
			variadic_found = true
			continue
		}
		decl_type := param.symbol.type
		if decl_type == nil || decl_type.kind == .Error {
			continue
		}
		if coerce(arg.type, decl_type, scope) == nil {
			error_span(
				span,
				"Argument %d of '%s': expected '%s', got '%s'",
				i + 1,
				func_name,
				decl_type.kind,
				arg.type.kind,
			)
		}
	}
}

function_call_emit :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	fn_name := e.callee.data.(Expr_Variable).value

	sym, ok := resolve_symbol(scope, fn_name)
	if !ok {
		fatal_span(span, "Unresolved function %s in function call", fn_name)
	}

	decl := sym.decl.data.(Ast_Function)
	args: [dynamic]ValueRef
	variadic_found := false
	for a, i in e.args {
		is_variadic := variadic_found || i >= len(decl.params)
		if !is_variadic && decl.params[i].variadic_marker {
			variadic_found = true
			is_variadic = true
		}
		// ABI coercion for external functions: small structs passed as integers
		if decl.external && !is_variadic && a.type != nil {
			if int_type, t_ok := get_abi_int_type_for_struct(gen, a.type); t_ok {
				addr := emit_address(gen, a, scope, span)
				append(&args, BuildLoad2(gen.builder, int_type, addr, "abi_coerce"))
				continue
			}
		}
		// Large structs: memcpy to stack and pass pointer (preserves by-value semantics)
		if is_large_struct(a.type) {
			src := emit_address(gen, a, scope, span)
			llvm_type := get_llvm_type(gen, a.type)
			copy := build_entry_alloca(gen, llvm_type, "byval_copy")
			size := ConstInt(Int64TypeInContext(gen.ctx), u64(get_type_byte_size(a.type)), 0)
			BuildMemCpy(gen.builder, copy, 8, src, 8, size)
			append(&args, copy)
			continue
		}
		val := emit_value(gen, a, scope, span)
		// C variadic ABI: float args must be promoted to double
		if is_variadic && a.type != nil && a.type.numeric_float && a.type.kind != .Float64 {
			val = BuildFPExt(gen.builder, val, DoubleTypeInContext(gen.ctx), "fpext")
		}
		append(&args, val)
	}

	// Lazily emit external function declarations on first use
	if sym not_in gen.values {
		function_decl_emit(gen, &decl, scope, span)
	}
	sym_type := gen.types[sym]
	sym_value := gen.values[sym]

	if len(args) == 0 {
		return BuildCall2(gen.builder, sym_type, sym_value, nil, 0, "")
	} else {
		return BuildCall2(gen.builder, sym_type, sym_value, &args[0], u32(len(args)), "")
	}
}

function_decl_emit :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	param_types: [dynamic]TypeRef

	fn_type: TypeRef

	//NOTE(quadrado): This must change so a function can return more than primitive types
	ret_type_ref := get_llvm_type(gen, s.symbol.type)

	if len(s.params) > 0 {
		variadic := false
		for param in s.params {
			if param.variadic_marker {
				variadic = true
			} else {
				param_type := get_llvm_type(gen, param.symbol.type)
				// ABI lowering: small structs -> integer, large structs -> pointer
				if s.external {
					if int_type, ok := get_abi_int_type_for_struct(gen, param.symbol.type); ok {
						param_type = int_type
					}
				}
				if is_large_struct(param.symbol.type) {
					param_type = PointerTypeInContext(gen.ctx, 0)
				}
				append(&param_types, param_type)
			}
		}
		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), i32(variadic))
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, 0)
	}

	sym := s.symbol
	// The runtime defines _zero_main() which becomes "main" in LLVM IR — the
	// entry point that libc's crt calls. The user's main() is renamed to
	// _user_main so _zero_main can call it.
	fn_name := s.name
	if s.name == "main" && !s.external {
		fn_name = "_user_main"
	} else if s.name == "_zero_main" {
		fn_name = "main"
	}
	fn := AddFunction(gen.module, strings.clone_to_cstring(fn_name), fn_type)

	gen.values[sym] = fn
	gen.types[sym] = fn_type
}


function_body_emit :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	sym := s.symbol
	fn := gen.values[sym]

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(gen.ctx, fn, "")

	old_pos := GetInsertBlock(gen.builder)
	PositionBuilderAtEnd(gen.builder, entry)

	for ast_param, i in s.params {
		param_sym := ast_param.symbol
		param := GetParam(fn, u32(i))

		// Large structs are passed by pointer — the param IS the pointer to the caller's copy
		if is_large_struct(param_sym.type) {
			gen.values[param_sym] = param
		} else {
			param_type := get_llvm_type(gen, param_sym.type)
			alloca := BuildAlloca(
				gen.builder,
				param_type,
				strings.clone_to_cstring(ast_param.name),
			)
			BuildStore(gen.builder, param, alloca)
			gen.values[param_sym] = alloca
		}
	}

	emit_block(gen, s.body)

	/*
	If function return type is Void and not terminated yet (a explicit return, 
    which is a valid expression), terminate with a RetVoid
    NOTE(quadrado): Using the "terminated" field in the Ast is not good but GetBasicBlockTerminator 
    always returns a value and not nil as expected of a non-terminated block.
    */
	if s.symbol.type.kind == .Void && !s.body.terminated {
		BuildRetVoid(gen.builder)
	}

	PositionBuilderAtEnd(gen.builder, old_pos)
}
