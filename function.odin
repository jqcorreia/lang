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
	// If the symbol exists, but is of kind .Type then this a cast
	if sym.kind == .Type {
		return cast_resolve(expr, sym, scope, span)
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


// SysV variants of function declaration, body and call site
//
// These three procs drive parameter passing entirely from abi_classify_param,
// applying SysV AMD64 uniformly to internal and external calls. They exist in
// parallel with function_{decl,call,body}_emit so the old path keeps working
// while the new one can be wired in piecewise.

function_decl_emit_sysv :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	param_types: [dynamic]TypeRef
	byval_param_idxs: [dynamic]u32
	byval_param_tys: [dynamic]TypeRef

	//NOTE(quadrado): This must change so a function can return more than primitive types
	ret_type_ref := get_llvm_type(gen, s.symbol.type)

	variadic := false
	for param in s.params {
		if param.variadic_marker {
			variadic = true
			continue
		}
		switch l in abi_classify_param(gen, param.symbol.type) {
		case ABI_Direct:
			append(&param_types, l.llvm_type)
		case ABI_Coerce:
			append(&param_types, l.scalar_type)
		case ABI_Split:
			append(&param_types, l.eb0_type)
			append(&param_types, l.eb1_type)
		case ABI_Byval:
			append(&byval_param_idxs, u32(len(param_types)))
			append(&byval_param_tys, l.struct_type)
			append(&param_types, PointerTypeInContext(gen.ctx, 0))
		}
	}

	fn_type: TypeRef
	if len(param_types) > 0 {
		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), i32(variadic))
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, i32(variadic))
	}

	// Rename main functions because of runtime entrypoint
	sym := s.symbol
	fn_name := s.name
	if s.name == "main" && !s.external {
		fn_name = "_user_main"
	} else if s.name == "_zero_main" {
		fn_name = "main"
	}
	fn := AddFunction(gen.module, strings.clone_to_cstring(fn_name), fn_type)

	// Applies Param attribute. The LLVM attribute name 'byval' signals the intent of passing param by-value.
	// Warning: param index is 1-based. index 0 is the return value
	if len(byval_param_idxs) > 0 {
		byval_kind := GetEnumAttributeKindForName("byval", 5)
		for param_idx, k in byval_param_idxs {
			attr := CreateTypeAttribute(gen.ctx, byval_kind, byval_param_tys[k])
			AddAttributeAtIndex(fn, param_idx + 1, attr)
		}
	}

	gen.values[sym] = fn
	gen.types[sym] = fn_type
}


function_call_emit_sysv :: proc(
	gen: ^Generator,
	e: Expr_Call,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	fn_name := e.callee.data.(Expr_Variable).value

	sym, ok := resolve_symbol(scope, fn_name)
	if !ok {
		fatal_span(span, "Unresolved function %s in function call", fn_name)
	}

	decl := sym.decl.data.(Ast_Function)
	args: [dynamic]ValueRef
	byval_arg_idxs: [dynamic]u32
	byval_arg_tys: [dynamic]TypeRef

	variadic_found := false
	for a, i in e.args {
		is_variadic := variadic_found || i >= len(decl.params)
		if !is_variadic && decl.params[i].variadic_marker {
			variadic_found = true
			is_variadic = true
		}

		if is_variadic {
			val := emit_value(gen, a, scope, span)
			// C variadic ABI: float args must be promoted to double.
			if a.type != nil && a.type.numeric_float && a.type.kind != .Float64 {
				val = BuildFPExt(gen.builder, val, DoubleTypeInContext(gen.ctx), "fpext")
			}
			append(&args, val)
			continue
		}

		// Classify by the declared param type, not arg.type, so caller and
		// callee agree even when numeric coercion has rewritten the arg type.
		param_type := decl.params[i].symbol.type
		switch l in abi_classify_param(gen, param_type) {
		case ABI_Direct:
			append(&args, emit_value(gen, a, scope, span))
		case ABI_Coerce:
			addr := emit_address(gen, a, scope, span)
			append(&args, BuildLoad2(gen.builder, l.scalar_type, addr, "abi_coerce"))
		case ABI_Split:
			addr := emit_address(gen, a, scope, span)
			eb0 := BuildLoad2(gen.builder, l.eb0_type, addr, "abi_split0")
			i8_ty := Int8TypeInContext(gen.ctx)
			offset8 := ConstInt(Int64TypeInContext(gen.ctx), 8, 0)
			eb1_addr := BuildGEP2(gen.builder, i8_ty, addr, &offset8, 1, "")
			eb1 := BuildLoad2(gen.builder, l.eb1_type, eb1_addr, "abi_split1")
			append(&args, eb0)
			append(&args, eb1)
		case ABI_Byval:
			src := emit_address(gen, a, scope, span)
			copy := build_entry_alloca(gen, l.struct_type, "byval_copy")
			size := ConstInt(Int64TypeInContext(gen.ctx), u64(get_type_byte_size(param_type)), 0)
			BuildMemCpy(gen.builder, copy, 8, src, 8, size)
			append(&byval_arg_idxs, u32(len(args)))
			append(&byval_arg_tys, l.struct_type)
			append(&args, copy)
		}
	}

	// Lazily emit external function declarations on first use.
	if sym not_in gen.values {
		function_decl_emit_sysv(gen, &decl, scope, span)
	}
	sym_type := gen.types[sym]
	sym_value := gen.values[sym]

	call: ValueRef
	if len(args) == 0 {
		call = BuildCall2(gen.builder, sym_type, sym_value, nil, 0, "")
	} else {
		call = BuildCall2(gen.builder, sym_type, sym_value, &args[0], u32(len(args)), "")
	}

	if len(byval_arg_idxs) > 0 {
		byval_kind := GetEnumAttributeKindForName("byval", 5)
		for arg_idx, k in byval_arg_idxs {
			attr := CreateTypeAttribute(gen.ctx, byval_kind, byval_arg_tys[k])
			AddCallSiteAttribute(call, arg_idx + 1, attr)
		}
	}

	return call
}


function_body_emit_sysv :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	sym := s.symbol
	fn := gen.values[sym]

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(gen.ctx, fn, "")

	old_pos := GetInsertBlock(gen.builder)
	PositionBuilderAtEnd(gen.builder, entry)

	llvm_idx: u32 = 0
	for ast_param in s.params {
		if ast_param.variadic_marker do continue
		param_sym := ast_param.symbol
		name := strings.clone_to_cstring(ast_param.name)

		switch l in abi_classify_param(gen, param_sym.type) {
		case ABI_Direct:
			p := GetParam(fn, llvm_idx)
			alloca := BuildAlloca(gen.builder, l.llvm_type, name)
			BuildStore(gen.builder, p, alloca)
			gen.values[param_sym] = alloca
			llvm_idx += 1
		case ABI_Coerce:
			// Materialize back into a struct alloca. Storing the scalar at the
			// struct's base address relies on opaque pointers + the eightbyte
			// layout produced by abi_classify_param matching the struct field
			// layout — true today since get_type_byte_size has no padding.
			p := GetParam(fn, llvm_idx)
			alloca := BuildAlloca(gen.builder, l.struct_type, name)
			BuildStore(gen.builder, p, alloca)
			gen.values[param_sym] = alloca
			llvm_idx += 1
		case ABI_Split:
			// Get both eightbytes and reconstruct the struct alloca
			p0 := GetParam(fn, llvm_idx)
			p1 := GetParam(fn, llvm_idx + 1)
			alloca := BuildAlloca(gen.builder, l.struct_type, name)

			// Store the first one
			BuildStore(gen.builder, p0, alloca)

			// Create an offset
			i8_ty := Int8TypeInContext(gen.ctx)
			offset8 := ConstInt(Int64TypeInContext(gen.ctx), 8, 0)

			// Store the second one
			eb1_addr := BuildGEP2(gen.builder, i8_ty, alloca, &offset8, 1, "")
			BuildStore(gen.builder, p1, eb1_addr)

			// The alloca reprents the struct itself, reconstructed
			gen.values[param_sym] = alloca

			// Move 2 in the 'llvm' index
			llvm_idx += 2
		case ABI_Byval:
			// The param value IS the pointer to the caller's stack copy.
			gen.values[param_sym] = GetParam(fn, llvm_idx)
			llvm_idx += 1
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
