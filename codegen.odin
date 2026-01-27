package main

import "core:fmt"
import "core:strings"

emit_stmt :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	fmt.println(s)
	#partial switch s.kind {
	case .Expr:
		data := s.data.(Statement_Expr)
		emit_expr(data.expr, ctx, builder)
	case .Assignment:
		data := s.data.(Statement_Assignment)
		ptr := BuildAlloca(builder, Int32Type(), "")
		BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
		state.vars[data.name] = ptr
	// state.ret_value = fmt_ptr
	case .Function:
		old_pos := GetInsertBlock(builder)
		data := s.data.(Statement_Function)
		fn_type := FunctionType(VoidTypeInContext(ctx), nil, 0, false)
		fn := AddFunction(module, strings.clone_to_cstring(data.name), fn_type)


		state.funcs[data.name] = Function {
			ty = fn_type,
			fn = fn,
		}

		SetLinkage(fn, .InternalLinkage)
		entry := AppendBasicBlockInContext(ctx, fn, "")

		PositionBuilderAtEnd(builder, entry)
		for bst in data.body {
			emit_stmt(bst, ctx, builder, module)
		}
		BuildRetVoid(builder)
		PositionBuilderAtEnd(builder, old_pos)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_print_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	func := state.funcs[e.callee.data.(Expr_Variable).value]
	args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")
	// call := BuildCall2(builder, func.ty, func.fn, nil, 0, "")

	return call
}

emit_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	fn_name := e.callee.data.(Expr_Variable).value
	func, ok := state.funcs[e.callee.data.(Expr_Variable).value]
	if !ok {
		panic(fmt.tprintln("Function", fn_name, "not found"))
	}
	// args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	// call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")
	call := BuildCall2(builder, func.ty, func.fn, nil, 0, "")

	return call
}

emit_expr :: proc(e: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	#partial switch e.kind {
	case .Int_Literal:
		return ConstInt(int32, u64(e.data.(Expr_Int_Literal).value), false)
	case .Call:
		data := e.data.(Expr_Call)
		if data.callee.data.(Expr_Variable).value == "print" {
			return emit_print_call(e.data.(Expr_Call), ctx, builder)
		} else {
			return emit_call(e.data.(Expr_Call), ctx, builder)
		}
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
		emit_stmt(stmt, ctx, builder, module)
	}


	BuildRet(builder, ConstInt(int32, 0, false))
}
