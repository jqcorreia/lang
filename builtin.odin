package main

Builtin_Funcs :: struct {
	create:  proc(scope: ^Scope),
	resolve: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope) -> ^Type,
	emit:    proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef,
}

builtins_map: map[string]Builtin_Funcs

@(init)
builtins_init :: proc "contextless" () {
	builtins_map["new"] = {builtin_create_new_func, builtin_new_resolve, builtin_new_emit}
	builtins_map["len"] = {builtin_len_create, builtin_len_resolve, builtin_len_emit}
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

builtin_new_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope) -> ^Type {
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

builtin_new_emit :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
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

builtin_len_create :: proc(scope: ^Scope) {
	sym := make_symbol(.Function)
	sym.name = "len"
	scope.symbols["len"] = sym
}

builtin_len_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope) -> ^Type {
	i64_t, _ := resolve_symbol(scope, "i64")

	expr.type = i64_t.type
	return expr.type
}

builtin_len_emit :: proc(gen: ^Generator, expr: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	arg0 := expr.args[0]
	#partial switch arg0.type.kind {
	case .Slice:

	case .Array:
		return ConstInt(Int64TypeInContext(gen.ctx), arg0.type.size, 0)
	}


	return nil
}
