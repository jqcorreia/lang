package main

Builtin_Funcs :: struct {
	create:  proc(scope: ^Scope),
	resolve: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type,
	emit:    proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef,
}

builtins_map: map[string]Builtin_Funcs

@(init)
builtins_init :: proc "contextless" () {
	builtins_map["new"] = {builtin_create_new_func, builtin_new_resolve, builtin_new_emit}
	builtins_map["len"] = {builtin_len_create, builtin_len_resolve, builtin_len_emit}
	builtins_map["cast"] = {builtin_cast_create, builtin_cast_resolve, builtin_cast_emit}
	builtins_map["slice"] = {builtin_slice_create, builtin_slice_resolve, builtin_slice_emit}
}

add_builtins :: proc(scope: ^Scope) {
	for _, v in builtins_map {
		v.create(scope)
	}
}

builtin_create_new_func :: proc(scope: ^Scope) {
	new_fn := make_symbol(.Function)
	new_fn.name = "new"
	scope.symbols["new"] = new_fn
}

builtin_new_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	call := expr.data.(Expr_Call)
	name := call.args[0].data.(Expr_Identifier).value

	type_sym, ok := resolve_symbol(scope, name)

	if !ok || type_sym.kind != .Type {
		error_span(expr.span, "new() takes a type as the argument")
		expr.type = &error_type
		return expr.type
	}

	ptr_type := new(Type)
	ptr_type.kind = .Pointer
	ptr_type.pointee_type = type_sym.type

	expr.type = ptr_type
	return ptr_type
}

builtin_new_emit :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Call)
	name := e.args[0].data.(Expr_Identifier).value

	sym, ok := resolve_symbol(scope, name)

	if !ok || sym.kind != .Type {
		error_span(span, "new() takes a type as the argument")
	}

	malloc_sym, _ := resolve_symbol(scope, "malloc")
	if malloc_sym not_in gen.values {
		decl := malloc_sym.decl.data.(Ast_Function)
		function_decl_emit_sysv(gen, &decl, scope, span)
	}

	size := get_type_byte_size(sym.type)
	fn := gen.values[malloc_sym]
	fn_type := gen.types[malloc_sym]

	arg := ConstInt(Int64TypeInContext(gen.ctx), u64(size), 0)
	call := BuildCall2(gen.builder, fn_type, fn, &arg, 1, "")

	return call
}

// cast(T, bytes) reinterprets a slice/array/value as a value of type T.
//
// Semantics: a *copy*. The source bytes are memcpy'd into a freshly alloca'd,
// correctly aligned T and the loaded T is returned. 
builtin_cast_create :: proc(scope: ^Scope) {
	sym := make_symbol(.Function)
	sym.name = "cast"
	scope.symbols["cast"] = sym
}

builtin_cast_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	call := expr.data.(Expr_Call)

	if len(call.args) != 2 {
		error_span(span, "cast() takes a type and a value: cast(T, bytes)")
		expr.type = &error_type
		return expr.type
	}

	ident, is_ident := call.args[0].data.(Expr_Identifier)
	if !is_ident {
		error_span(span, "cast() expects a type as the first argument")
		expr.type = &error_type
		return expr.type
	}

	type_sym, ok := resolve_symbol(scope, ident.value)
	if !ok || type_sym.kind != .Type {
		error_span(span, "cast() expects a type as the first argument")
		expr.type = &error_type
		return expr.type
	}

	// Resolve the source value so its type is known at emit time.
	resolve_expr_type(call.args[1], scope, span)

	expr.type = type_sym.type
	return expr.type
}

builtin_cast_emit :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Call)

	i64_t := Int64TypeInContext(gen.ctx)
	ptr_t := PointerTypeInContext(gen.ctx, 0)

	name := e.args[0].data.(Expr_Identifier).value
	sym, _ := resolve_symbol(scope, name)

	dst_ty := get_llvm_type(gen, sym.type)
	dst_size := StoreSizeOfType(gen.data_layout, dst_ty)
	dst_align := ABIAlignmentOfType(gen.data_layout, dst_ty)

	// Obtain the source data pointer and its byte length.
	src := e.args[1]
	src_ptr: ValueRef
	src_bytes: ValueRef

	#partial switch src.type.kind {
	case .Slice:
		struct_ty := get_llvm_type(gen, src.type)
		slice := emit_address(gen, src, scope, span)

		p0 := BuildStructGEP2(gen.builder, struct_ty, slice, 0, "")
		src_ptr = BuildLoad2(gen.builder, ptr_t, p0, "")

		p1 := BuildStructGEP2(gen.builder, struct_ty, slice, 1, "")
		count := BuildLoad2(gen.builder, i64_t, p1, "")

		elem_sz := ConstInt(i64_t, u64(get_type_byte_size(src.type.elem_type)), 0)
		src_bytes = BuildMul(gen.builder, count, elem_sz, "")
	case:
		// Any other addressable value (including arrays): reinterpret its in-memory bytes.
		src_ptr = emit_address(gen, src, scope, span)
		src_bytes = ConstInt(i64_t, u64(get_type_byte_size(src.type)), 0)
	}

	last := ConstInt(i64_t, dst_size - 1, 0) // Bounds are checked based on 0-index hence the dst_size - 1
	array_bound_check_emit(gen, last, src_bytes, scope, span)

	// Copy into an aligned T and load it back by value.
	slot := build_entry_alloca(gen, dst_ty, "cast")
	BuildMemCpy(gen.builder, slot, dst_align, src_ptr, 1, ConstInt(i64_t, dst_size, 0))
	return BuildLoad2(gen.builder, dst_ty, slot, "")
}

builtin_len_create :: proc(scope: ^Scope) {
	sym := make_symbol(.Function)
	sym.name = "len"
	scope.symbols["len"] = sym
}

builtin_len_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	i64_t, _ := resolve_symbol(scope, "i64")

	// This is a function so it needs to be used on a call
	data := expr.data.(Expr_Call)

	for arg in data.args {
		resolve_expr_type(arg, scope, span)
	}

	expr.type = i64_t.type
	return expr.type
}

builtin_len_emit :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Call)
	arg0 := e.args[0]
	#partial switch arg0.type.kind {
	case .Slice:
		struct_ty := get_llvm_type(gen, arg0.type)

		// alloc := build_entry_alloca(gen, struct_ty, "")
		slice := emit_address(gen, arg0, scope, span)

		p1 := BuildStructGEP2(gen.builder, struct_ty, slice, 1, "")
		return BuildLoad2(gen.builder, Int64TypeInContext(gen.ctx), p1, "")

	case .Array:
		return ConstInt(Int64TypeInContext(gen.ctx), arg0.type.size, 0)
	}

	return nil
}

builtin_slice_create :: proc(scope: ^Scope) {
	sym := make_symbol(.Function)
	sym.name = "slice"
	scope.symbols["slice"] = sym
}

builtin_slice_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	// This is a function so it needs to be used on a call
	data := expr.data.(Expr_Call)

	for arg in data.args {
		resolve_expr_type(arg, scope, span)
	}

	if data.args[0].type.kind != .Pointer {
		error_span(span, "First argument of slice must be a pointer")
		expr.type = &error_type
		return expr.type
	}

	if len(data.args) != 2 {
		error_span(span, "slice() takes 2 arguments")
		expr.type = &error_type
		return expr.type
	}

	slice_type := new(Type)
	slice_type.kind = .Slice
	slice_type.elem_type = data.args[0].type.pointee_type // Infer slice element type from the pointee type
	expr.type = slice_type
	return expr.type
}

builtin_slice_emit :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Call)
	slice_type := expr.type

	ptr := emit_value(gen, e.args[0], scope, span)
	size := emit_value(gen, e.args[1], scope, span)

	slice_ty := get_llvm_type(gen, slice_type)
	slot := build_entry_alloca(gen, slice_ty, "")

	p0 := BuildStructGEP2(gen.builder, slice_ty, slot, 0, "")
	BuildStore(gen.builder, ptr, p0)
	p1 := BuildStructGEP2(gen.builder, slice_ty, slot, 1, "")
	BuildStore(gen.builder, size, p1)

	return BuildLoad2(gen.builder, slice_ty, slot, "")
}
