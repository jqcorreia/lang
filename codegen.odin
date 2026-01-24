package main

import "core:fmt"

emit_stmt :: proc(s: ^Stmt, ctx: ContextRef, builder: BuilderRef) {
	switch s.kind {
	case .Expr:
		unimplemented()
	case .Block:
		unimplemented()
	case .Let:
		data := s.data.(Stmt_Let)
		ptr := BuildAlloca(builder, Int32Type(), "")
		BuildStore(builder, emit_expr(data.value, ctx, builder), ptr)
		state.ret_value = ptr
	}
}

emit_expr :: proc(e: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	switch e.kind {
	case .Int_Lit:
		return ConstInt(int32, u64(e.data.(Expr_Int_Lit).value), false)
	case .Ident:
		unimplemented()
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
	case .Call:
		unimplemented()
	}
	return ConstInt(int32, 42, true)
}

generate :: proc(stmts: []^Stmt, ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
	int32 := Int32TypeInContext(ctx)
	fn_type := FunctionType(int32, nil, 0, 0)

	main_f := AddFunction(module, "main", fn_type)

	entry := AppendBasicBlockInContext(ctx, main_f, "")
	PositionBuilderAtEnd(builder, entry)

	for stmt in stmts {
		fmt.println(stmt)
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

	BuildRet(builder, BuildLoad2(builder, int32, state.ret_value, ""))
}
