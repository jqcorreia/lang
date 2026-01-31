package main

import "core:container/queue"
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

emit_stmt :: proc(s: ^Ast_Node, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	#partial switch &node in s.node {
	case Ast_Expr:
		emit_expr(node.expr, ctx, builder)
	case Ast_Assignment:
		emit_assigment(&node, ctx, builder, module)
	case Ast_Function:
		emit_function(&node, ctx, builder, module)
	case Ast_Return:
		emit_return(&node, ctx, builder, module)
	case Ast_If:
		emit_if(&node, ctx, builder, module)
	case Ast_For:
		emit_for_loop(&node, ctx, builder, module)
	case Ast_Break:
		emit_break(&node, ctx, builder, module)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", s))
	}
}

emit_assigment :: proc(
	s: ^Ast_Assignment,
	ctx: ContextRef,
	builder: BuilderRef,
	module: ModuleRef,
) {
	data := s
	// Build local variables
	// If the variable exists, just emit a Store, otherwise emit Alloca + Store
	if !scope_top_level() {
		ptr, exists := scope_current().vars[data.name]
		if exists {
			BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
		} else {
			ptr = BuildAlloca(builder, Int32Type(), "")
			BuildStore(builder, emit_expr(data.expr, ctx, builder), ptr)
			scope_current().vars[data.name] = ptr
		}
	} else {
		// Create global variables, only constant for now
		if _, ok := data.expr.(Expr_Int_Literal); ok {
			ptr := AddGlobal(module, Int32Type(), strings.clone_to_cstring(data.name))
			SetInitializer(
				ptr,
				ConstInt(Int32Type(), u64(data.expr.(Expr_Int_Literal).value), false),
			)
			state.global_scope.vars[data.name] = ptr
		} else {
			panic("Global variables need to be constants")
		}
	}
}

emit_function :: proc(s: ^Ast_Function, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	old_pos := GetInsertBlock(builder)

	data := s
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

	emit_block(data.body, ctx, builder, module)

	if func.return_type == "" {
		BuildRetVoid(builder)
	}
	PositionBuilderAtEnd(builder, old_pos)
	DumpValue(fn)

	scope_pop()
}

emit_return :: proc(s: ^Ast_Return, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	data := s
	BuildRet(builder, emit_expr(data.expr, ctx, builder))
}

// This a hacked printf-type emission until we have proper external functions
emit_print_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	func := state.funcs[e.callee.(Expr_Variable).value]
	args := []ValueRef{fmt_ptr, emit_expr(e.args[0], ctx, builder)}

	call := BuildCall2(builder, func.ty, func.fn, &args[0], u32(len(args)), "")

	return call
}

emit_call :: proc(e: Expr_Call, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "")
	fn_name := e.callee.(Expr_Variable).value
	func, ok := state.funcs[e.callee.(Expr_Variable).value]

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

emit_expr :: proc(expr: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	#partial switch e in expr {
	case Expr_Int_Literal:
		return ConstInt(int32, u64(e.value), false)
	case Expr_Call:
		data := e
		if data.callee.(Expr_Variable).value == "print" {
			return emit_print_call(e, ctx, builder)
		} else {
			return emit_call(e, ctx, builder)
		}
	case Expr_Variable:
		return BuildLoad2(builder, int32, resolve_var(e.value), "")
	case Expr_Binary:
		#partial switch e.op {
		case .Plus:
			return BuildAdd(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"add",
			)
		case .Minus:
			return BuildSub(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"sub",
			)
		case .Star:
			return BuildMul(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"mul",
			)
		case .Slash:
			return BuildSDiv(
				builder,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"div",
			)
		case .DoubleEqual:
			return BuildICmp(
				builder,
				.IntEQ,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gt",
			)
		case .Greater:
			return BuildICmp(
				builder,
				.IntUGT,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gt",
			)
		case .Lesser:
			return BuildICmp(
				builder,
				.IntULT,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"lt",
			)
		case .GreaterOrEqual:
			return BuildICmp(
				builder,
				.IntUGE,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"gte",
			)
		case .LesserOrEqual:
			return BuildICmp(
				builder,
				.IntULE,
				emit_expr(e.left, ctx, builder),
				emit_expr(e.right, ctx, builder),
				"lte",
			)
		}
	}
	unreachable()
}

emit_block :: proc(block: ^Ast_Block, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	for bst in block.statements {
		emit_stmt(bst, ctx, builder, module)
		if _, ok := bst.node.(Ast_Return); ok {
			block.terminated = true
		}
	}
}

emit_if :: proc(s: ^Ast_If, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	if_stmt := s
	cond_val := emit_expr(if_stmt.cond, ctx, builder)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)

	// If the expression eval result is a i1 (one bit integer) then use it directly
	// Otherwise emit a comparison to zero and the cond_bool
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, false)
		cond_bool = BuildICmp(builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(builder))

	then_bb := AppendBasicBlock(function, "then")
	merge_bb := AppendBasicBlock(function, "ifcont")

	else_bb: BasicBlockRef
	if if_stmt.else_block != nil {
		else_bb = AppendBasicBlock(function, "else")
		BuildCondBr(builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(builder, cond_bool, then_bb, merge_bb)
	}

	PositionBuilderAtEnd(builder, then_bb)
	emit_block(if_stmt.then_block, ctx, builder, module)

	bb := GetInsertBlock(builder)
	if GetBasicBlockTerminator(bb) == nil {
		BuildBr(builder, merge_bb)
	}

	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(builder, else_bb)
		emit_block(if_stmt.else_block, ctx, builder, module)

		bb = GetInsertBlock(builder)
		if GetBasicBlockTerminator(bb) == nil {
			BuildBr(builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(builder, merge_bb)
}

emit_for_loop :: proc(s: ^Ast_For, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	for_stmt := s
	function := GetBasicBlockParent(GetInsertBlock(builder))

	loop_bb := AppendBasicBlock(function, "loop")
	after_bb := AppendBasicBlock(function, "after")

	BuildBr(builder, loop_bb)
	queue.push_front(&state.loops, Loop{break_block = after_bb})
	PositionBuilderAtEnd(builder, loop_bb)
	emit_block(for_stmt.body, ctx, builder, module)

	if GetBasicBlockTerminator(GetInsertBlock(builder)) == nil {
		BuildBr(builder, loop_bb)
	}

	queue.pop_front(&state.loops)
	PositionBuilderAtEnd(builder, after_bb)
}

emit_break :: proc(s: ^Ast_Break, ctx: ContextRef, builder: BuilderRef, module: ModuleRef) {
	if queue.len(state.loops) == 0 {
		panic("Breaking outside of a loop")
	}
	loop := queue.front(&state.loops)

	BuildBr(builder, loop.break_block)

	// Move builder away from terminated block
	fn := GetBasicBlockParent(GetInsertBlock(builder))
	dead := AppendBasicBlock(fn, "after_break")
	PositionBuilderAtEnd(builder, dead)
}

generate :: proc(stmts: []^Ast_Node, ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
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
