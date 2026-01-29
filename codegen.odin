package main

import "core:fmt"
import "core:strings"

resolve_var :: proc(name: string) -> ValueRef {
	local_var, local_var_ok := scope_current().vars[name]
	if local_var_ok {
		return local_var
	} else {
		global_var, global_var_ok := state.global_scope.vars[name]
		if global_var_ok {
			return global_var
		}
	}
	return nil
}

emit_stmt :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	#partial switch s.kind {
	case .Expr:
		data := s.data.(Statement_Expr)
		emit_expr(data.expr, ctx, builder)
	case .Assignment:
		emit_assigment(s, ctx, builder, module)
	case .Function:
		emit_function(s, ctx, builder, module)
	case .Return:
		data := s.data.(Statement_Return)
		BuildRet(builder, emit_expr(data.expr, ctx, builder))
	case .If:
		emit_if(s, ctx, builder, module)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_assigment :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	data := s.data.(Statement_Assignment)
	if !scope_top_level() {
		ptr := BuildAlloca(builder, Int32Type(), "")
		BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
		scope_current().vars[data.name] = ptr
	} else {
		if data.expr.kind == .Int_Literal {
			ptr := AddGlobal(module, Int32Type(), strings.clone_to_cstring(data.name))
			SetInitializer(
				ptr,
				ConstInt(Int32Type(), u64(data.expr.data.(Expr_Int_Literal).value), false),
			)
			state.global_scope.vars[data.name] = ptr
		} else {
			panic("Global variables need to be constants")
		}
	}
}

emit_function :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	old_pos := GetInsertBlock(builder)


	data := s.data.(Statement_Function)
	func := &state.funcs[data.name]

	int32 := Int32TypeInContext(ctx)
	param_types: [dynamic]TypeRef

	fn_type: TypeRef
	ret_type_ref := func.return_type == "" ? VoidTypeInContext(ctx) : Int32TypeInContext(ctx)

	if len(func.params) > 0 {
		for _ in data.params {
			append(&param_types, int32)
		}

		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), false)
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, false)

	}

	fn := AddFunction(module, strings.clone_to_cstring(data.name), fn_type)
	// By now the function must exist in state
	// Complete the information with TypeRef and ValueRef
	func.ty = fn_type
	func.fn = fn

	SetLinkage(fn, .InternalLinkage)
	entry := AppendBasicBlockInContext(ctx, fn, "")
	PositionBuilderAtEnd(builder, entry)

	// Allocate vars
	scope := Scope{}
	scope_push(scope)
	for param_name, i in data.params {
		param := GetParam(fn, u32(i))

		alloca := BuildAlloca(builder, int32, strings.clone_to_cstring(param_name))
		BuildStore(builder, param, alloca)

		scope_current().vars[param_name] = alloca
	}

	for bst in data.body.statements {
		emit_stmt(bst, ctx, builder, module)
	}
	if func.return_type == "" {
		BuildRetVoid(builder)
	}
	PositionBuilderAtEnd(builder, old_pos)
	DumpValue(fn)

	scope_pop()
}

// This a hacked printf-type emission until we have proper external functions
emit_print_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	func := state.funcs[e.callee.data.(Expr_Variable).value]
	args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")

	return call
}

emit_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	fn_name := e.callee.data.(Expr_Variable).value
	func, ok := state.funcs[e.callee.data.(Expr_Variable).value]

	if !ok {
		panic(fmt.tprintln("Function", fn_name, "not found"))
	}

	args: [dynamic]ValueRef
	for a in e.args {
		append(&args, emit_expr(a, ctx, builder))
	}

	if len(args) == 0 {
		return BuildCall2(builder, func.ty, func.fn, nil, 0, "")
	} else {
		return BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")
	}
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
		return BuildLoad2(builder, int32, resolve_var(e.data.(Expr_Variable).value), "")
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
		case .Greater:
			return BuildICmp(
				builder,
				.IntUGT,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Lesser:
			return BuildICmp(
				builder,
				.IntULT,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .GreaterOrEqual:
			return BuildICmp(
				builder,
				.IntUGE,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .LesserOrEqual:
			return BuildICmp(
				builder,
				.IntULE,
				emit_expr(e.data.(Expr_Binary).left, ctx, builder),
				emit_expr(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		}
	}
	return ConstInt(int32, 42, true)
}

emit_block :: proc(
	block: ^Statement_Block,
	ctx: ContextRef,
	builder: BuilderRef,
	module: ModuleRef,
) {
	for bst in block.statements {
		emit_stmt(bst, ctx, builder, module)
		if bst.kind == .Return {
			block.terminated = true
		}
	}
}

emit_if :: proc(s: ^Statement, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	if_stmt := s.data.(Statement_If)
	cond_val := emit_expr(if_stmt.cond, ctx, builder)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, false)
		cond_bool = BuildICmp(builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(builder))

	then_bb := AppendBasicBlock(function, "then")
	else_bb := AppendBasicBlock(function, "else")
	merge_bb := AppendBasicBlock(function, "ifcont")

	if s.data.(Statement_If).else_block != nil {
		BuildCondBr(builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(builder, cond_bool, then_bb, merge_bb)
	}
	PositionBuilderAtEnd(builder, then_bb)
	emit_block(if_stmt.then_block, ctx, builder, module)
	// If block didn’t already return:
	if !if_stmt.then_block.terminated {
		BuildBr(builder, merge_bb)
	}
	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(builder, else_bb)
		emit_block(if_stmt.else_block, ctx, builder, module)
		if !if_stmt.else_block.terminated {
			BuildBr(builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(builder, merge_bb)
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

	DumpValue(main_f)

	BuildRet(builder, ConstInt(int32, 0, false))
}
