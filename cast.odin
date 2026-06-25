package main

Expr_Cast :: struct {
	cast_type: ^Type,
	arg:       ^Expr,
}

cast_resolve :: proc(expr: ^Expr, sym: ^Symbol, scope: ^Scope, span: Span) -> ^Type {
	orig_call := expr.data.(Expr_Call)

	args := orig_call.args

	if len(args) != 1 {
		error_span(span, "Casts take exactly one argument")
		expr.type = &error_type
		return &error_type
	}

	resolve_expr_type(args[0], scope, span)

	// Mutate expression to a cast to the type of the symbol
	expr.data = Expr_Cast {
		cast_type = sym.type,
		arg       = args[0],
	}

	expr.type = sym.type
	return sym.type
}

cast_emit_value :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Cast)
	to_llvm := get_llvm_type(gen, e.cast_type)
	val := emit_value(gen, e.arg, scope, span)

	from := e.arg.type
	to := e.cast_type

	switch {
	case from.numeric_integer && to.numeric_integer:
		return BuildIntCast2(gen.builder, val, to_llvm, i32(from.signed), "")
	case from.kind == .Enum && to.numeric_integer:
		// Enums are backed by an integer, so an enum->int cast is an integer cast
		return BuildIntCast2(gen.builder, val, to_llvm, i32(to.signed), "")
	case from.numeric_float && to.numeric_integer:
		if to.signed {
			return BuildFPToSI(gen.builder, val, to_llvm, "")
		}
		return BuildFPToUI(gen.builder, val, to_llvm, "")
	case from.numeric_integer && to.numeric_float:
		if from.signed {
			return BuildSIToFP(gen.builder, val, to_llvm, "")
		}
		return BuildUIToFP(gen.builder, val, to_llvm, "")
	case from.numeric_float && to.numeric_float:
		return BuildFPCast(gen.builder, val, to_llvm, "")
	case from.kind == .Pointer && to.kind == .Pointer:
		return BuildPointerCast(gen.builder, val, to_llvm, "")
	case from.kind == .Pointer && to.numeric_integer:
		return BuildPtrToInt(gen.builder, val, to_llvm, "")
	case from.numeric_integer && to.kind == .Pointer:
		return BuildIntToPtr(gen.builder, val, to_llvm, "")
	}

	fatal_span(span, "Unsupported cast from '%s' to '%s'", from.kind, to.kind)
	return nil
}
