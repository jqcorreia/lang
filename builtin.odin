package main

// Note(quadrado): we need a way to abstract and simplify the declaration of builtins that can't be
// declared in the language runtime.
add_builtins :: proc(scope: ^Scope) {
	heap_create_new_func(scope)
}

heap_create_new_func :: proc(scope: ^Scope) {
	new_fn := make_symbol(.Function)
	new_fn.name = "new"
	scope.symbols["new"] = new_fn
}

heap_new_resolve :: proc(sym: ^Symbol, expr: ^Expr, scope: ^Scope) -> ^Type {
	call := expr.data.(Expr_Call)
	name := call.args[0].data.(Expr_Variable).value

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

heap_new_emit :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	name := e.args[0].data.(Expr_Variable).value

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
