package main

import "core:fmt"

emit_stmt :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef) {
	#partial switch s.kind {
	case .Expr:
		data := s.data.(Statement_Expr)
		emit_expr(data.expr, ctx, builder)
	case .Assignment:
		data := s.data.(Statement_Assignment)
		ptr := BuildAlloca(builder, Int32Type(), "")
		BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
		state.vars[data.name] = ptr
	// state.ret_value = ptr
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	func := state.funcs[e.callee.data.(Expr_Variable).value]
	args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")

	return call
}

emit_expr :: proc(e: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	#partial switch e.kind {
	case .Int_Literal:
		return ConstInt(int32, u64(e.data.(Expr_Int_Literal).value), false)
	case .Call:
		return emit_call(e.data.(Expr_Call), ctx, builder)
	case .Variable:
		return BuildLoad2(builder, int32, state.vars[e.data.(Expr_Variable).value], "")
	case .Binary:
		#partial switch e.data.(Expr_Binary).op {
		case .Plus:
			return BuildAdd(
				builder,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Minus:
			return BuildSub(
				builder,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Star:
			return BuildMul(
				builder,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Slash:
			return BuildSDiv(
				builder,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		}
	}
	return ConstInt(int32, 42, true)
}

generate :: proc(stmts: []^Statement, ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
	int32 := Int32TypeInContext(ctx)
	fn_type := FunctionType(int32, nil, 0, 0)

	main_f := AddFunction(module, "main", fn_type)

	entry := AppendBasicBlockInContext(ctx, main_f, "")
	PositionBuilderAtEnd(builder, entry)

	for stmt in stmts {
		emit_stmt(stmt, ctx, builder)
	}

	// ret := gen_expr(e, ctx, builder)
	// i8 := Int8TypeInContext(ctx)
	// i32 := Int32TypeInContext(ctx)
	// i8p := PointerType(i8, 0)

	// printf_ty = FunctionType(
	// 	i32, // return type
	// 	&i8p, // first arg: char *
	// 	1,
	// 	true, // variadic
	// )

	// printf_fn = AddFunction(module, "printf", printf_ty)
	// fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "fmt")

	// args := []ValueRef {
	// 	fmt_ptr,
	// 	ret, // i32
	// }

	// BuildCall2(
	// 	builder,
	// 	printf_ty, // <-- REQUIRED
	// 	printf_fn,
	// 	&args[0],
	// 	u32(len(args)),
	// 	"",
	// )

	BuildRet(builder, ConstInt(int32, 0, false))
}
