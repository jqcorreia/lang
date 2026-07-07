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

Expr_Function :: struct {
	params:        []Param,
	ret_type_expr: ^Expr,
	body:          ^Ast_Block,
}

Expr_Call :: struct {
	callee: ^Expr,
	args:   []^Expr,
	method: bool, // true if desugared from receiver.method(args), enables auto-ref/deref on arg 0
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
	for !done && current(p).kind != .EOF && !p.error_occured {
		#partial switch current(p).kind {
		case .Identifier:
			param_name := current(p).lexeme
			advance(p)
			expect(p, .Colon)
			if current(p).kind == .Ellipsis {
				advance(p)
				type_expr := parse_type_expr(p)
				append(
					&params,
					Param{name = param_name, type_expr = type_expr, variadic_marker = true},
				)
			} else {
				type_expr := parse_type_expr(p)
				append(&params, Param{name = param_name, type_expr = type_expr})
			}
		case .Comma:
			if peek(p).kind == .RParen {
				unexpected_token(p, peek(p))
			}
			advance(p)
		case .RParen:
			advance(p)
			done = true
		case:
			unexpected_token(p, current(p))
		}
	}

	return params[:]
}

function_ret_type_parse :: proc(p: ^Parser) -> Type_Expr {
	if current(p).kind == .RightArrow {
		advance(p)

		type_expr := parse_type_expr(p)

		return type_expr
	}

	return Type_Expr{data = ""}
}

function_external_block_parse :: proc(p: ^Parser, lib_name: string) -> ^Ast_Block {
	// Deduplicate linker libs
	found := false
	for lib in compiler.external_linker_libs {
		if lib == lib_name {
			found = true
			break
		}
	}
	if !found {append(&compiler.external_linker_libs, lib_name)}

	res: [dynamic]^Ast_Node

	expect(p, .LBrace)

	for keep_parsing_block(p) {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		// Get token here so we can create a proper span here
		fn_tok := current(p)
		expect(p, .Func_Keyword)
		data := function_decl_parse(p, external = true)
		stmt := new(Ast_Node)
		stmt.data = data^
		stmt.span = Span {
			start    = fn_tok.span.start,
			end      = current(p).span.end,
			filename = p.filename,
		}
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

	existing, ok := resolve_symbol(cur_scope, data.name)

	if !ok {
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
	} else {
		error_span(node.span, "Re-declaration of function '%s'", data.name)
		data.symbol = existing
	}
}

function_signature_resolve :: proc(node: ^Ast_Function, scope: ^Scope, span: Span) -> ^Type {
	type := new(Type)
	type.kind = .Function
	for &param in node.params {
		param_type := resolve_type_expr(&param.type_expr, scope, span)
		if param.variadic_marker {
			// Note: should err if declaring multiple variadic args
			variadic_type := new(Type)
			variadic_type.kind = .Slice
			variadic_type.variadic = true
			variadic_type.elem_type = param_type

			// Flag this function as having C-type variadic args
			type.c_variadic = node.external
			append(&type.params, variadic_type)
			continue
		}
		append(&type.params, param_type)
	}

	ret_type := resolve_type_expr(&node.ret_type_expr, scope, span)
	if ret_type == &error_type {
		return &error_type
	}

	type.return_type = ret_type

	return type
}

function_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Function)
	sig := function_signature_resolve(&data, node.scope, node.span)
	data.symbol.type = sig

	for &param, i in data.params {
		param.symbol.type = sig.params[i]
	}

	if !data.external {
		resolve_block_types(data.body)
	}
}

function_call_resolve :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	e := &expr.data.(Expr_Call)

	fn_type: ^Type
	args := e.args

	#partial switch data in e.callee.data {
	case Expr_Member:
		base_type := resolve_expr_type(data.base, scope, span)

		if base_type.kind == .Error {
			expr.type = &error_type
			e.callee.type = &error_type
			return expr.type
		}

		base_type = deref_type(base_type)

		if base_type.kind == .Struct {
			field_type := struct_field_type_by_name(base_type, data.member)

			if field_type == nil {
				sym, ok := resolve_symbol(scope, data.member)
				if !ok {
					error_span(
						expr.span,
						"Undefined function '%s' (no such field or method)",
						data.member,
					)
					expr.type = &error_type
					e.callee.type = &error_type
					return &error_type
				}
				fn_type = sym.type

				// This change allows the codegen to see this as a regular function, which it should be
				e.callee.data = Expr_Identifier {
					value = data.member,
				}
			} else {
				if field_type.kind == .Function {
					fn_type = field_type
					args = e.args[1:]
					e.method = false
				} else {
					error_span(expr.span, "Field '%s' is not a function", data.member)
					expr.type = &error_type
					e.callee.type = &error_type
					return expr.type
				}
			}
		}

	case Expr_Identifier:
		sym, ok := resolve_symbol(scope, data.value)
		if !ok {
			error_span(expr.span, "Undefined function '%s''", data.value)
			expr.type = &error_type
			return &error_type
		}
		if builtin, builtin_ok := builtins_map[sym.name]; builtin_ok {
			return builtin.resolve(sym, expr, scope, span)
		}

		// If the symbol exists, but is of kind .Type then this a cast
		if sym.kind == .Type {
			return cast_resolve(expr, sym, scope, span)
		}
		fn_type = sym.type
	}

	e.callee.type = fn_type
	e.args = args

	variadic_found := false
	variadic_args: [dynamic]^Expr
	variadic_type: ^Type

	for i in 0 ..< len(e.args) {
		arg := e.args[i]
		arg.type = resolve_expr_type(arg, scope, span)

		//Note: this is crappy, we should be iterating over params and not args TODO
		// This way we avoid all this
		if variadic_found || i >= len(fn_type.params) {
			arg.type = coerce(arg.type, variadic_type, scope)
			append(&variadic_args, arg)
			continue
		}

		param := fn_type.params[i]
		if param.variadic {
			variadic_found = true
			variadic_type = param.elem_type
			arg.type = coerce(arg.type, variadic_type, scope)
			append(&variadic_args, arg)
			continue
		}

		// Auto-ref / auto-deref the receiver of a method-style call
		// Note: This is a mess and should be refactored
		if e.method && i == 0 && param != nil && arg.type != nil {
			if param.kind == .Pointer &&
			   arg.type.kind != .Pointer &&
			   param.pointee_type == arg.type {
				wrapped := new(Expr)
				wrapped.data = Expr_Unary {
					op   = .Ampersand,
					expr = arg,
				}
				wrapped.type = param
				e.args[i] = wrapped
				arg = wrapped
			} else if arg.type.kind == .Pointer &&
			   param.kind != .Pointer &&
			   arg.type.pointee_type == param {
				wrapped := new(Expr)
				wrapped.data = Expr_Unary {
					op   = .Star,
					expr = arg,
				}
				wrapped.type = param
				e.args[i] = wrapped
				arg = wrapped
			}
		}

		if param != nil {
			coerced_type := coerce_expr(arg, param, scope)
			if coerced_type == nil {
				error_span(arg.span, "Invalid parameter type")
			}
		}
	}

	expr.type = e.callee.type.return_type
	return e.callee.type.return_type
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
	func_name: string
	#partial switch data in e.callee.data {
	case Expr_Identifier:
		func_name = data.value
	case Expr_Member:
		func_name = data.member
	}

	type := e.callee.type

	if type == nil || type.kind == .Error {
		return
	}

	variadic_found := false
	required_params := 0
	for param in type.params {
		if !param.variadic {
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
		if i >= len(type.params) {
			error_span(span, "Too many arguments for '%s'", func_name)
			continue
		}
		param := type.params[i]
		if param.variadic {
			variadic_found = true
			continue
		}
		param_type := param
		if param_type == nil || param_type.kind == .Error {
			continue
		}
		if coerce(arg.type, param_type, scope) == nil {
			error_span(
				span,
				"Argument %d of '%s': expected '%s', got '%s'",
				i + 1,
				func_name,
				param_type.kind,
				arg.type.kind,
			)
		}
	}
}

build_llvm_fn_type_sysv :: proc(
	gen: ^Generator,
	sig: ^Type,
) -> (
	TypeRef,
	[dynamic]u32,
	[dynamic]TypeRef,
) {
	param_types: [dynamic]TypeRef
	byval_param_idxs: [dynamic]u32
	byval_param_tys: [dynamic]TypeRef
	variadic := false

	ret_type_ref := get_llvm_type(gen, sig.return_type)
	for param in sig.params {
		// Only build a variadic LLVM function if it's an effective c-style variadic function
		// The loop continues because variadic param are not SysV classified yet TODO
		if param.variadic && sig.c_variadic {
			variadic = true
			continue
		}
		switch l in abi_classify_param(gen, param) {
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

	param_types_ptr := len(param_types) == 0 ? nil : &param_types[0]
	fn_type := FunctionType(ret_type_ref, param_types_ptr, u32(len(param_types)), i32(variadic))

	return fn_type, byval_param_idxs, byval_param_tys
}

function_decl_emit_sysv :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	fn_type, byval_param_idxs, byval_param_tys := build_llvm_fn_type_sysv(gen, s.symbol.type)

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

// Helper to build an slice struct backed by values. This is used on converting variadic variables
// to a usable slice.
build_variadic_slice :: proc(gen: ^Generator, slice_type: ^Type, vals: []ValueRef) -> ValueRef {
	slice_struct_ty := get_llvm_type(gen, slice_type)
	n := len(vals)
	slot := build_entry_alloca(gen, slice_struct_ty, "varargs_slice")

	ptr_val: ValueRef
	if n > 0 {
		elem_ty := get_llvm_type(gen, slice_type.elem_type)
		arr_ty := ArrayType(elem_ty, u32(n))
		backing := build_entry_alloca(gen, arr_ty, "varargs_backing")
		for v, k in vals {
			indices: []ValueRef = {
				ConstInt(Int64TypeInContext(gen.ctx), 0, 0),
				ConstInt(Int64TypeInContext(gen.ctx), u64(k), 0),
			}
			ep := BuildGEP2(gen.builder, arr_ty, backing, raw_data(indices), 2, "")
			BuildStore(gen.builder, v, ep)
		}
		ptr_val = backing
	} else {
		ptr_val = ConstNull(PointerTypeInContext(gen.ctx, 0))
	}

	p0 := BuildStructGEP2(gen.builder, slice_struct_ty, slot, 0, "")
	BuildStore(gen.builder, ptr_val, p0)
	p1 := BuildStructGEP2(gen.builder, slice_struct_ty, slot, 1, "")
	BuildStore(gen.builder, ConstInt(Int64TypeInContext(gen.ctx), u64(n), 0), p1)

	return BuildLoad2(gen.builder, slice_struct_ty, slot, "")
}

function_call_emit_sysv :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	indirect := false
	direct_sym: ^Symbol
	fn_type: ^Type
	e := expr.data.(Expr_Call)

	#partial switch data in e.callee.data {
	case Expr_Identifier:
		fn_name := data.value
		sym, _ := resolve_symbol(scope, fn_name)

		assert(sym != nil)

		if builtin, builtin_ok := builtins_map[sym.name]; builtin_ok {
			return builtin.emit(gen, expr, scope, span)
		}
		if sym.kind == .Function {
			indirect = false
			direct_sym = sym
			fn_type = sym.type
		}
		if sym.kind == .Variable {
			indirect = true
			fn_type = sym.type
		}
	case Expr_Member:
		indirect = true
		fn_type = e.callee.type
	}

	args: [dynamic]ValueRef
	byval_arg_idxs: [dynamic]u32
	byval_arg_tys: [dynamic]TypeRef

	// Find the native variadic param if it exists
	native_variadic: ^Type
	if !fn_type.c_variadic {
		for p in fn_type.params {
			if p.variadic {
				native_variadic = p
				break
			}
		}
	}

	variadic_found := false
	variadic_vals: [dynamic]ValueRef
	for a, i in e.args {
		is_variadic := variadic_found || i >= len(fn_type.params)
		if !is_variadic && fn_type.params[i].variadic {
			variadic_found = true
			is_variadic = true
		}

		if is_variadic {
			val := emit_value(gen, a, scope, span)
			if native_variadic != nil {
				// Native: collect and pack into a slice after the loop.
				append(&variadic_vals, val)
				continue
			}
			// C variadic ABI
			// Floats are promoted to double (f64)
			// Integers (or bools) are promoted to i32
			if a.type.numeric_float && a.type.kind != .Float64 {
				val = BuildFPExt(gen.builder, val, DoubleTypeInContext(gen.ctx), "fpext")
			}
			if (a.type.numeric_integer || a.type.kind == .Bool) && get_type_byte_size(a.type) < 4 {
				i32_t := Int32TypeInContext(gen.ctx)
				val =
					a.type.signed ? BuildSExt(gen.builder, val, i32_t, "") : BuildZExt(gen.builder, val, i32_t, "")
			}
			append(&args, val)
			continue
		}

		// Classify by the declared param type, not arg.type, so caller and
		// callee agree even when numeric coercion has rewritten the arg type.
		param_type := fn_type.params[i]
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
			// Use the real (padded) LLVM struct size: get_type_byte_size is
			// padding-free and would truncate the copy, corrupting later fields.
			size := ConstInt(
				Int64TypeInContext(gen.ctx),
				u64(ABISizeOfType(gen.data_layout, l.struct_type)),
				0,
			)
			BuildMemCpy(gen.builder, copy, 8, src, 8, size)
			append(&byval_arg_idxs, u32(len(args)))
			append(&byval_arg_tys, l.struct_type)
			append(&args, copy)
		}
	}

	// Native variadic always passes a trailing slice (empty -> {null, 0}).
	if native_variadic != nil {
		append(&args, build_variadic_slice(gen, native_variadic, variadic_vals[:]))
	}

	sym_type: TypeRef
	sym_value: ValueRef
	if !indirect {
		// Direct call: lazily emit the function declaration on first use
		// (covers external functions and forward refs).
		if direct_sym not_in gen.values {
			decl := direct_sym.decl.data.(Ast_Function)
			function_decl_emit_sysv(gen, &decl, scope, span)
		}
		sym_type = gen.types[direct_sym]
		sym_value = gen.values[direct_sym]
	} else {
		// Indirect call through a function-pointer value. Build the LLVM
		// FunctionType from the signature and load the callee at the call site.
		sym_value = emit_value(gen, e.callee, scope, span)
		sym_type, _, _ = build_llvm_fn_type_sysv(gen, fn_type)
	}

	call: ValueRef
	args_ptr := len(args) == 0 ? nil : &args[0]
	call = BuildCall2(gen.builder, sym_type, sym_value, args_ptr, u32(len(args)), "")

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
		// if ast_param.variadic_marker do continue
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
			// layout, true today since get_type_byte_size has no padding.
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


	// If function return type is Void and not terminated yet (a explicit return,
	// which is a valid expression), terminate with a RetVoid
	// NOTE(quadrado): Using the "terminated" field in the Ast is not good but GetBasicBlockTerminator
	// always returns a value and not nil as expected of a non-terminated block.

	if s.symbol.type.return_type.kind == .Void && !s.body.terminated {
		BuildRetVoid(gen.builder)
	}

	PositionBuilderAtEnd(gen.builder, old_pos)
}
