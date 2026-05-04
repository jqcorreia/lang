package main

import "core:container/queue"
import "core:fmt"
import "core:strings"

Generator :: struct {
	values:          map[^Symbol]ValueRef,
	types:           map[^Symbol]TypeRef,
	ctx:             ContextRef,
	builder:         BuilderRef,
	module:          ModuleRef,
	primitive_types: map[^Type]TypeRef,
	empty_str_ptr:   ValueRef,
}


get_llvm_type :: proc(gen: ^Generator, type: ^Type) -> TypeRef {
	if type.kind == .Array {
		elem_type := get_llvm_type(gen, type.elem_type)
		return ArrayType2(elem_type, type.size)
	}
	if type.kind == .Pointer {
		return PointerTypeInContext(gen.ctx, 0)
	}
	// Untyped integers default to i64 at codegen
	if type.kind == .Untyped_Int {
		return Int64TypeInContext(gen.ctx)
	}
	// Untyped floats default to double at codegen
	if type.kind == .Untyped_Float {
		return DoubleTypeInContext(gen.ctx)
	}
	// @Note: for now enums are i64
	if type.kind == .Enum {
		return Int64TypeInContext(gen.ctx)
	}
	return gen.primitive_types[type]
}

build_entry_alloca :: proc(gen: ^Generator, type: TypeRef, name: cstring) -> ValueRef {
	cur_bb := GetInsertBlock(gen.builder)
	function := GetBasicBlockParent(cur_bb)
	entry_bb := GetEntryBasicBlock(function)
	first_instr := GetFirstInstruction(entry_bb)
	if first_instr != nil {
		PositionBuilderBefore(gen.builder, first_instr)
	} else {
		PositionBuilderAtEnd(gen.builder, entry_bb)
	}
	ptr := BuildAlloca(gen.builder, type, name)
	PositionBuilderAtEnd(gen.builder, cur_bb)
	return ptr
}

emit_stmt :: proc(gen: ^Generator, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Block, Ast_Import, Ast_Enum_Decl:
	// Do nothing
	case Ast_Expr:
		emit_value(gen, data.expr, node.scope, node.span)
	case Ast_Var_Assign:
		emit_assigment(gen, &data, node.scope, node.span)
	case Ast_Var_Decl:
		emit_var_decl(gen, &data, node.scope, node.span)
	case Ast_Struct_Decl:
		struct_emit_body(gen, &data, node.scope, node.span)
	case Ast_Function:
		if !data.external {
			emit_function_body(gen, &data, node.scope, node.span)
		}
	case Ast_Return:
		emit_return(gen, &data, node.scope, node.span)
	case Ast_If:
		emit_if(gen, &data, node.scope, node.span)
	case Ast_For:
		emit_for_loop(gen, &data, node.scope, node.span)
	case Ast_Break:
		emit_break(gen, &data, node.scope, node.span)
	case:
		unimplemented(fmt.tprint("Unimplement emit statement", node))
	}
}


emit_into :: proc(gen: ^Generator, expr: ^Expr, dest: ValueRef, scope: ^Scope, span: Span) {
	#partial switch &e in expr.data {
	case Expr_Array_Literal:
		array_llvm_type := get_llvm_type(gen, expr.type)

		for elem, i in e.elements {
			indices: []ValueRef = {
				ConstInt(Int32TypeInContext(gen.ctx), 0, 0),
				ConstInt(Int32TypeInContext(gen.ctx), u64(i), 0),
			}
			elem_ptr := BuildGEP2(gen.builder, array_llvm_type, dest, raw_data(indices), 2, "")
			if elem.type.kind == .Array {
				emit_into(gen, elem, elem_ptr, scope, span)
			} else {
				elem_val := emit_value(gen, elem, scope, span)
				BuildStore(gen.builder, elem_val, elem_ptr)
			}
		}
	case Expr_Struct_Literal:
		struct_emit_into(gen, expr, dest, scope, span)
	case:
		// General fallback: emit value and store into dest
		val := emit_value(gen, expr, scope, span)
		BuildStore(gen.builder, val, dest)
	}
}

emit_address :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	#partial switch &e in expr.data {
	case Expr_Array_Literal:
		array_llvm_type := get_llvm_type(gen, expr.type)
		ptr := build_entry_alloca(gen, array_llvm_type, "")
		emit_into(gen, expr, ptr, scope, span)
		return ptr

	case Expr_Struct_Literal:
		return struct_emit_address(gen, expr, scope, span)

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok {
			fatal_span(span, "Symbol not found on expr emit: %s", e.value)
		}
		var := gen.values[sym]

		return var

	case Expr_Member:
		// Get the base type
		base_type: ^Type = e.base.type.kind == .Pointer ? e.base.type.pointee_type : e.base.type

		if base_type.kind == .Struct {
			return struct_member_emit_address(gen, &e, scope, span)
		}

	case Expr_Index:
		index_val := emit_value(gen, e.index, scope, span)
		indices: []ValueRef = {ConstInt(Int32TypeInContext(gen.ctx), 0, 0), index_val}

		array_ptr: ValueRef
		llvm_type: TypeRef

		if e.array.type.kind == .Pointer {
			array_ptr = emit_value(gen, e.array, scope, span)
			llvm_type = get_llvm_type(gen, e.array.type.pointee_type)
		} else {
			array_ptr = emit_address(gen, e.array, scope, span)
			llvm_type = get_llvm_type(gen, e.array.type)
		}

		ptr := BuildGEP2(gen.builder, llvm_type, array_ptr, raw_data(indices), 2, "")

		return ptr

	case Expr_Unary:
		if e.op == .Star {
			return emit_value(gen, e.expr, scope, span)
		}
	}

	fatal_span(span, "Not addressable expresion", expr)
	// unimplemented(fmt.tprintf("Not addressable expression %v", expr))
	return nil
}

emit_value :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	int64 := Int64TypeInContext(gen.ctx)
	float64 := DoubleTypeInContext(gen.ctx)
	#partial switch &e in expr.data {
	case Expr_Null:
		return ConstPointerNull(PointerTypeInContext(gen.ctx, 0))
	case Expr_Int_Literal:
		type := get_llvm_type(gen, expr.type)
		if type == nil {
			type = int64
		}
		// Deal with the case that is a untyped int literal coerced into a float
		// Check type_coercion() for the case of untyped_int -> numeric_float
		if type != nil && expr.type.numeric_float {
			return ConstReal(type, f64(e.value))
		} else {
			return ConstInt(type, u64(e.value), 0)
		}

	case Expr_Float_Literal:
		type := get_llvm_type(gen, expr.type)
		if type == nil {
			type = float64
		}
		return ConstReal(type, f64(e.value))
	case Expr_Bool_Literal:
		type := get_llvm_type(gen, expr.type)
		return ConstInt(type, e.value ? 1 : 0, 0)
	case Expr_String_Literal:
		return BuildGlobalStringPtr(gen.builder, strings.clone_to_cstring(e.value), "")
	case Expr_Array_Literal:
		addr := emit_address(gen, expr, scope, span)
		return BuildLoad2(gen.builder, get_llvm_type(gen, expr.type), addr, "")

	case Expr_Struct_Literal:
		return struct_emit_value(gen, expr, scope, span)
	case Expr_Member:
		base_type: ^Type
		if e.base.type.kind == .Pointer {
			base_type = e.base.type.pointee_type
		} else {
			base_type = e.base.type
		}

		if base_type.kind == .Struct {
			return struct_member_emit_value(gen, expr, scope, span)
		}
		if base_type.kind == .Enum {
			return enum_member_emit_value(gen, expr)
		}
	case Expr_Index:
		ptr := emit_address(gen, expr, scope, span)
		llvm_type := get_llvm_type(gen, expr.type)
		return BuildLoad2(gen.builder, llvm_type, ptr, "")
	case Expr_Call:
		return emit_call(gen, e, scope, span)
	case Expr_Variable:
		ptr := emit_address(gen, expr, scope, span)
		sym, _ := resolve_symbol(scope, e.value)
		val := BuildLoad2(gen.builder, get_llvm_type(gen, sym.type), ptr, "")
		// Insert integer cast if expression type differs from storage type (e.g. untyped range var coerced to i32)
		sym_is_int := sym.type.numeric_integer || sym.type.kind == .Untyped_Int
		if expr.type != sym.type && expr.type.numeric_integer && sym_is_int {
			return BuildIntCast2(gen.builder, val, get_llvm_type(gen, expr.type), 1, "icast")
		}
		return val
	case Expr_Unary:
		#partial switch e.op {
		case .Bang:
			operand := emit_value(gen, e.expr, scope, span)
			return BuildNot(gen.builder, operand, "not")
		case .Minus:
			operand := emit_value(gen, e.expr, scope, span)
			if e.expr.type.numeric_float {
				return BuildFNeg(gen.builder, operand, "fneg")
			}
			zero := ConstInt(get_llvm_type(gen, e.expr.type), 0, 0)
			return BuildSub(gen.builder, zero, operand, "subzero")
		case .Ampersand:
			ptr := emit_address(gen, e.expr, scope, span)
			return ptr
		case .Star:
			ptr := emit_value(gen, e.expr, scope, span)
			return BuildLoad2(gen.builder, get_llvm_type(gen, e.expr.type.pointee_type), ptr, "")
		}
	case Expr_Binary:
		left := emit_value(gen, e.left, scope, span)
		right := emit_value(gen, e.right, scope, span)
		#partial switch e.op {
		case .Plus:
			if expr.type.numeric_float {
				return BuildFAdd(gen.builder, left, right, "fadd")
			}
			return BuildAdd(gen.builder, left, right, "add")
		case .Minus:
			if expr.type.numeric_float {
				return BuildFSub(gen.builder, left, right, "fsub")
			}
			return BuildSub(gen.builder, left, right, "sub")
		case .Star:
			if expr.type.numeric_float {
				return BuildFMul(gen.builder, left, right, "fmul")
			}
			return BuildMul(gen.builder, left, right, "mul")
		case .Slash:
			if expr.type.numeric_float {
				return BuildFDiv(gen.builder, left, right, "fdiv")
			}
			return BuildSDiv(gen.builder, left, right, "div")
		case .Percent:
			if expr.type.numeric_float {
				return BuildFRem(gen.builder, left, right, "fmod")
			}
			if expr.type.signed {
				return BuildSRem(gen.builder, left, right, "imod")
			} else {
				return BuildURem(gen.builder, left, right, "umod")
			}
		case .DoubleEqual:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealOEQ, left, right, "feq")
			}
			return BuildICmp(gen.builder, .IntEQ, left, right, "eq")
		case .NotEqual:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealONE, left, right, "fne")
			}
			return BuildICmp(gen.builder, .IntNE, left, right, "ne")
		case .Greater:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealOGT, left, right, "fgt")
			}
			pred := e.left.type.signed || e.right.type.signed ? IntPredicate.IntSGT : .IntUGT
			return BuildICmp(gen.builder, pred, left, right, "gt")
		case .Lesser:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealOLT, left, right, "flt")
			}
			pred := e.left.type.signed || e.right.type.signed ? IntPredicate.IntSLT : .IntULT
			return BuildICmp(gen.builder, pred, left, right, "lt")
		case .GreaterOrEqual:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealOGE, left, right, "fge")
			}
			pred := e.left.type.signed || e.right.type.signed ? IntPredicate.IntSGE : .IntUGE
			return BuildICmp(gen.builder, pred, left, right, "gte")
		case .LesserOrEqual:
			if e.left.type.numeric_float {
				return BuildFCmp(gen.builder, .RealOLE, left, right, "fle")
			}
			pred := e.left.type.signed || e.right.type.signed ? IntPredicate.IntSLE : .IntULE
			return BuildICmp(gen.builder, pred, left, right, "lte")
		case .DoublePipe:
			return BuildOr(gen.builder, left, right, "or")
		case .DoubleAmpersand:
			return BuildAnd(gen.builder, left, right, "and")
		}
	}
	unimplemented(fmt.tprintf("Expression %v emit not implemented", expr))
}

emit_assigment :: proc(gen: ^Generator, s: ^Ast_Var_Assign, scope: ^Scope, span: Span) {
	ptr := emit_address(gen, s.lhs, scope, span)
	type := s.expr.type

	if type.kind == .Struct || type.kind == .Array {
		emit_into(gen, s.expr, ptr, scope, span)
	} else {
		BuildStore(gen.builder, emit_value(gen, s.expr, scope, span), ptr)
	}
}

make_global_string_ptr :: proc(gen: ^Generator, s: string) -> ValueRef {
	cstr := strings.clone_to_cstring(s)
	char_type := Int8TypeInContext(gen.ctx)
	str_data_type := ArrayType(char_type, u32(len(s) + 1))
	str_global := AddGlobal(gen.module, str_data_type, ".str")
	SetInitializer(str_global, ConstStringInContext(gen.ctx, cstr, u32(len(s)), 0))
	SetGlobalConstant(str_global, 1)
	SetLinkage(str_global, .PrivateLinkage)
	indices := []ValueRef {
		ConstInt(Int32TypeInContext(gen.ctx), 0, 0),
		ConstInt(Int32TypeInContext(gen.ctx), 0, 0),
	}
	return ConstInBoundsGEP2(str_data_type, str_global, raw_data(indices), 2)
}

make_const_value :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope) -> ValueRef {
	llvm_type := get_llvm_type(gen, expr.type)
	#partial switch e in expr.data {
	case Expr_Int_Literal:
		return ConstInt(llvm_type, u64(e.value), 0)
	case Expr_Float_Literal:
		return ConstReal(llvm_type, e.value)
	case Expr_String_Literal:
		return make_global_string_ptr(gen, e.value)
	case Expr_Struct_Literal:
		return struct_emit_const(gen, expr, scope)
	case Expr_Array_Literal:
		elem_type := get_llvm_type(gen, expr.type.elem_type)
		elem_vals: [dynamic]ValueRef
		for elem in e.elements {
			append(&elem_vals, make_const_value(gen, elem, scope))
		}
		return ConstArray2(elem_type, raw_data(elem_vals), u64(len(elem_vals)))
	case:
		panic(fmt.tprintf("Cannot use '%v' as global constant initializer", expr.data))
	}
}

emit_var_decl :: proc(gen: ^Generator, s: ^Ast_Var_Decl, scope: ^Scope, span: Span) {
	// Build local variables
	// If the variable exists, just emit a Store, otherwise emit Alloca + Store
	is_global := scope.kind == .Global
	sym := s.symbol
	if sym == nil {
		fatal_span(span, "Symbol %s is not bound!", s.name)
	}
	if !is_global {
		ptr, exists := gen.values[sym]

		if exists do fatal_span(span, "Variable aliasing detected. Fatal error for now")

		compiler_type := get_llvm_type(gen, sym.type)
		ptr = build_entry_alloca(gen, compiler_type, "")
		gen.values[sym] = ptr
		if s.expr != nil {
			if sym.type.kind == .Struct || sym.type.kind == .Array {
				emit_into(gen, s.expr, ptr, scope, span)
			} else {
				BuildStore(gen.builder, emit_value(gen, s.expr, scope, span), ptr)
			}
		} else {
			BuildStore(gen.builder, make_zero_value(gen, sym.type), ptr)
		}
	} else {
		llvm_type := get_llvm_type(gen, sym.type)
		ptr := AddGlobal(gen.module, llvm_type, strings.clone_to_cstring(s.name))
		if s.expr != nil {
			SetInitializer(ptr, make_const_value(gen, s.expr, scope))
		} else {
			SetInitializer(ptr, make_zero_value(gen, sym.type))
		}
		gen.values[sym] = ptr
	}
}

emit_memcpy :: proc(gen: ^Generator, s: ^Ast_Var_Decl, scope: ^Scope, span: Span) {
	// NOTE: THis is incomplete but saved for future reference!!

	// data_layout := GetModuleDataLayout(gen.module)

	// align := ABIAlignmentOfType(data_layout, compiler_type)
	// size := ABISizeOfType(data_layout, compiler_type)
	// i64_size := ConstInt(Int64Type(), size, 0)
	// addr := emit_address(gen, s.expr, scope, span)
	// BuildMemCpy(gen.builder, ptr, align, addr, align, i64_size)
}

emit_function_decl :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	param_types: [dynamic]TypeRef

	fn_type: TypeRef

	//NOTE(quadrado): This must change so a function can return more than primitive types
	ret_type_ref := get_llvm_type(gen, s.symbol.type)

	if len(s.params) > 0 {
		variadic := false
		for param in s.params {
			if param.variadic_marker {
				variadic = true
			} else {
				param_type := get_llvm_type(gen, param.symbol.type)
				// ABI lowering: small structs -> integer, large structs -> pointer
				if s.external {
					if int_type, ok := get_abi_int_type_for_struct(gen, param.symbol.type); ok {
						param_type = int_type
					}
				}
				if is_large_struct(param.symbol.type) {
					param_type = PointerTypeInContext(gen.ctx, 0)
				}
				append(&param_types, param_type)
			}
		}
		fn_type = FunctionType(ret_type_ref, &param_types[0], u32(len(param_types)), i32(variadic))
	} else {
		fn_type = FunctionType(ret_type_ref, nil, 0, 0)
	}

	sym := s.symbol
	// The runtime defines _zero_main() which becomes "main" in LLVM IR — the
	// entry point that libc's crt calls. The user's main() is renamed to
	// _user_main so _zero_main can call it.
	fn_name := s.name
	if s.name == "main" && !s.external {
		fn_name = "_user_main"
	} else if s.name == "_zero_main" {
		fn_name = "main"
	}
	fn := AddFunction(gen.module, strings.clone_to_cstring(fn_name), fn_type)

	gen.values[sym] = fn
	gen.types[sym] = fn_type
}


emit_function_body :: proc(gen: ^Generator, s: ^Ast_Function, scope: ^Scope, span: Span) {
	sym := s.symbol
	fn := gen.values[sym]

	SetLinkage(fn, .ExternalLinkage)
	entry := AppendBasicBlockInContext(gen.ctx, fn, "")

	old_pos := GetInsertBlock(gen.builder)
	PositionBuilderAtEnd(gen.builder, entry)

	for ast_param, i in s.params {
		param_sym := ast_param.symbol
		param := GetParam(fn, u32(i))

		// Large structs are passed by pointer — the param IS the pointer to the caller's copy
		if is_large_struct(param_sym.type) {
			gen.values[param_sym] = param
		} else {
			param_type := get_llvm_type(gen, param_sym.type)
			alloca := BuildAlloca(
				gen.builder,
				param_type,
				strings.clone_to_cstring(ast_param.name),
			)
			BuildStore(gen.builder, param, alloca)
			gen.values[param_sym] = alloca
		}
	}

	emit_block(gen, s.body)

	/*
	If function return type is Void and not terminated yet (a explicit return, 
    which is a valid expression), terminate with a RetVoid
    NOTE(quadrado): Using the "terminated" field in the Ast is not good but GetBasicBlockTerminator 
    always returns a value and not nil as expected of a non-terminated block.
    */
	if s.symbol.type.kind == .Void && !s.body.terminated {
		BuildRetVoid(gen.builder)
	}

	PositionBuilderAtEnd(gen.builder, old_pos)
	// DumpValue(fn)
}

emit_return :: proc(gen: ^Generator, s: ^Ast_Return, scope: ^Scope, span: Span) {
	data := s
	if data.expr != nil {
		BuildRet(gen.builder, emit_value(gen, data.expr, scope, span))
	} else {
		BuildRetVoid(gen.builder)
	}
}


emit_call :: proc(gen: ^Generator, e: Expr_Call, scope: ^Scope, span: Span) -> ValueRef {
	fn_name := e.callee.data.(Expr_Variable).value

	sym, ok := resolve_symbol(scope, fn_name)
	if !ok {
		fatal_span(span, "Unresolved function %s in function call", fn_name)
	}

	decl := sym.decl.data.(Ast_Function)
	args: [dynamic]ValueRef
	variadic_found := false
	for a, i in e.args {
		is_variadic := variadic_found || i >= len(decl.params)
		if !is_variadic && decl.params[i].variadic_marker {
			variadic_found = true
			is_variadic = true
		}
		// ABI coercion for external functions: small structs passed as integers
		if decl.external && !is_variadic && a.type != nil {
			if int_type, t_ok := get_abi_int_type_for_struct(gen, a.type); t_ok {
				addr := emit_address(gen, a, scope, span)
				append(&args, BuildLoad2(gen.builder, int_type, addr, "abi_coerce"))
				continue
			}
		}
		// Large structs: memcpy to stack and pass pointer (preserves by-value semantics)
		if is_large_struct(a.type) {
			src := emit_address(gen, a, scope, span)
			llvm_type := get_llvm_type(gen, a.type)
			copy := build_entry_alloca(gen, llvm_type, "byval_copy")
			size := ConstInt(Int64TypeInContext(gen.ctx), u64(get_type_byte_size(a.type)), 0)
			BuildMemCpy(gen.builder, copy, 8, src, 8, size)
			append(&args, copy)
			continue
		}
		val := emit_value(gen, a, scope, span)
		// C variadic ABI: float args must be promoted to double
		if is_variadic && a.type != nil && a.type.numeric_float && a.type.kind != .Float64 {
			val = BuildFPExt(gen.builder, val, DoubleTypeInContext(gen.ctx), "fpext")
		}
		append(&args, val)
	}

	// Lazily emit external function declarations on first use
	if sym not_in gen.values {
		emit_function_decl(gen, &decl, scope, span)
	}
	sym_type := gen.types[sym]
	sym_value := gen.values[sym]

	if len(args) == 0 {
		return BuildCall2(gen.builder, sym_type, sym_value, nil, 0, "")
	} else {
		return BuildCall2(gen.builder, sym_type, sym_value, &args[0], u32(len(args)), "")
	}
}


emit_block :: proc(gen: ^Generator, block: ^Ast_Block) {
	for bst in block.statements {
		emit_stmt(gen, bst)
		if _, ok := bst.data.(Ast_Return); ok {
			block.terminated = true
		}
	}
}

emit_if :: proc(gen: ^Generator, s: ^Ast_If, scope: ^Scope, span: Span) {
	if_stmt := s
	cond_val := emit_value(gen, if_stmt.cond, scope, span)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)

	// If the expression eval result is a i1 (one bit integer) then use it directly
	// Otherwise emit a comparison to zero and the cond_bool
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, 0)
		cond_bool = BuildICmp(gen.builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	then_bb := AppendBasicBlock(function, "then")
	merge_bb := AppendBasicBlock(function, "ifcont")

	else_bb: BasicBlockRef
	if if_stmt.else_block != nil {
		else_bb = AppendBasicBlock(function, "else")
		BuildCondBr(gen.builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(gen.builder, cond_bool, then_bb, merge_bb)
	}

	PositionBuilderAtEnd(gen.builder, then_bb)
	emit_block(gen, if_stmt.then_block)

	bb := GetInsertBlock(gen.builder)
	if GetBasicBlockTerminator(bb) == nil {
		BuildBr(gen.builder, merge_bb)
	}

	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(gen.builder, else_bb)
		emit_block(gen, if_stmt.else_block)

		bb = GetInsertBlock(gen.builder)
		if GetBasicBlockTerminator(bb) == nil {
			BuildBr(gen.builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(gen.builder, merge_bb)
}

emit_for_loop_unconditional :: proc(gen: ^Generator, s: ^Ast_For, scope: ^Scope, span: Span) {
	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	loop_bb := AppendBasicBlock(function, "loop")
	after_bb := AppendBasicBlock(function, "after")

	BuildBr(gen.builder, loop_bb)
	queue.push_front(&compiler.loops, Loop{break_block = after_bb})
	PositionBuilderAtEnd(gen.builder, loop_bb)
	emit_block(gen, s.body)

	if GetBasicBlockTerminator(GetInsertBlock(gen.builder)) == nil {
		BuildBr(gen.builder, loop_bb)
	}

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(gen.builder, after_bb)
}

emit_for_loop :: proc(gen: ^Generator, s: ^Ast_For, scope: ^Scope, span: Span) {
	if s.range == nil {
		emit_for_loop_unconditional(gen, s, scope, span)
		return
	}

	function := GetBasicBlockParent(GetInsertBlock(gen.builder))
	range := s.range.data.(Expr_Range)
	iter_type := get_llvm_type(gen, s.symbol.type)

	// Emit start and end once in the entry block so they are available across all BBs
	// Determine loop direction at runtime: is start <= end?
	start_val := emit_value(gen, range.start, scope, span)
	end_val := emit_value(gen, range.end, scope, span)
	is_forward := BuildICmp(gen.builder, .IntSLE, start_val, end_val, "is_fwd")

	// Store the initial value of the range
	iter_ptr := build_entry_alloca(gen, iter_type, strings.clone_to_cstring(s.iterator))
	BuildStore(gen.builder, start_val, iter_ptr)
	gen.values[s.symbol] = iter_ptr

	// Create the basic blocks
	cond_bb := AppendBasicBlock(function, "for_cond")
	loop_bb := AppendBasicBlock(function, "for_body")
	after_bb := AppendBasicBlock(function, "for_after")

	BuildBr(gen.builder, cond_bb)

	// Conditional part of the loop
	// Check for current iterator value and check for end case (either inclusive or exclusive)
	// Set the conditional branching at the end to either the loop body or exit the loop
	PositionBuilderAtEnd(gen.builder, cond_bb)
	iter_val := BuildLoad2(gen.builder, iter_type, iter_ptr, "iter")
	cmp: ValueRef
	if range.inclusive {
		fwd_cmp := BuildICmp(gen.builder, .IntSLE, iter_val, end_val, "fwd_cond")
		bwd_cmp := BuildICmp(gen.builder, .IntSGE, iter_val, end_val, "bwd_cond")
		cmp = BuildSelect(gen.builder, is_forward, fwd_cmp, bwd_cmp, "cond")
	} else {
		fwd_cmp := BuildICmp(gen.builder, .IntSLT, iter_val, end_val, "fwd_cond")
		bwd_cmp := BuildICmp(gen.builder, .IntSGT, iter_val, end_val, "bwd_cond")
		cmp = BuildSelect(gen.builder, is_forward, fwd_cmp, bwd_cmp, "cond")
	}

	BuildCondBr(gen.builder, cmp, loop_bb, after_bb)

	// Position builder and emit the body of the loop
	queue.push_front(&compiler.loops, Loop{break_block = after_bb})
	PositionBuilderAtEnd(gen.builder, loop_bb)
	emit_block(gen, s.body)

	// Check for termination
	// If not terminated yet, advance iterator and branch to condition block again
	if GetBasicBlockTerminator(GetInsertBlock(gen.builder)) == nil {
		cur := BuildLoad2(gen.builder, iter_type, iter_ptr, "iter")
		inc := BuildAdd(gen.builder, cur, ConstInt(iter_type, 1, 0), "inc")
		dec := BuildSub(gen.builder, cur, ConstInt(iter_type, 1, 0), "dec")
		next := BuildSelect(gen.builder, is_forward, inc, dec, "next")
		BuildStore(gen.builder, next, iter_ptr)
		BuildBr(gen.builder, cond_bb)
	}

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(gen.builder, after_bb)
}

emit_break :: proc(gen: ^Generator, s: ^Ast_Break, scope: ^Scope, span: Span) {
	loop := queue.front(&compiler.loops)

	BuildBr(gen.builder, loop.break_block)

	// Move gen.builder away from terminated block
	fn := GetBasicBlockParent(GetInsertBlock(gen.builder))
	dead := AppendBasicBlock(fn, "after_break")
	PositionBuilderAtEnd(gen.builder, dead)
}

setup_codegen :: proc(gen: ^Generator) {
	// Primitive types
	for _, sym in global_scope.symbols {
		if sym.kind == .Type {
			#partial switch sym.type.kind {
			case .Void:
				gen.primitive_types[sym.type] = VoidTypeInContext(gen.ctx)
			case .Bool:
				gen.primitive_types[sym.type] = Int1TypeInContext(gen.ctx)
			case .Uint8:
				gen.primitive_types[sym.type] = Int8TypeInContext(gen.ctx)
			case .Uint16:
				gen.primitive_types[sym.type] = Int16TypeInContext(gen.ctx)
			case .Uint32:
				gen.primitive_types[sym.type] = Int32TypeInContext(gen.ctx)
			case .Uint64:
				gen.primitive_types[sym.type] = Int64TypeInContext(gen.ctx)
			case .Int8:
				gen.primitive_types[sym.type] = Int8TypeInContext(gen.ctx)
			case .Int16:
				gen.primitive_types[sym.type] = Int16TypeInContext(gen.ctx)
			case .Int32:
				gen.primitive_types[sym.type] = Int32TypeInContext(gen.ctx)
			case .Int64:
				gen.primitive_types[sym.type] = Int64TypeInContext(gen.ctx)
			case .Float16:
				gen.primitive_types[sym.type] = HalfTypeInContext(gen.ctx)
			case .Float32:
				gen.primitive_types[sym.type] = FloatTypeInContext(gen.ctx)
			case .Float64:
				gen.primitive_types[sym.type] = DoubleTypeInContext(gen.ctx)
			case .CString:
				gen.primitive_types[sym.type] = PointerTypeInContext(gen.ctx, 0)
			}
		}
	}
	gen.empty_str_ptr = make_global_string_ptr(gen, "")
}

make_zero_value :: proc(gen: ^Generator, type: ^Type) -> ValueRef {
	if type.kind == .CString {
		return gen.empty_str_ptr
	}
	return ConstNull(get_llvm_type(gen, type))
}

generate :: proc(stmts: []^Ast_Node) -> bool {
	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	generator := Generator {
		ctx     = ctx,
		module  = module,
		builder = builder,
	}
	setup_codegen(&generator)

	emit_struct_decls := proc(node: ^Ast_Node, userdata: rawptr = nil) {
		if snode, ok := node.data.(Ast_Struct_Decl); ok {
			gen := cast(^Generator)userdata
			struct_emit_decl(gen, &snode, node.scope, node.span)
		}
	}
	emit_function_decls := proc(node: ^Ast_Node, userdata: rawptr = nil) {
		if fnode, ok := node.data.(Ast_Function); ok {
			// Skip external functions, they are emitted lazily on first call
			if fnode.external {return}
			gen := cast(^Generator)userdata
			emit_function_decl(gen, &fnode, node.scope, node.span)
		}
	}

	// Emit first things first
	// - Structs
	// - Functions
	traverse_block(stmts, emit_struct_decls, &generator)
	traverse_block(stmts, emit_function_decls, &generator)

	for stmt in stmts {
		emit_stmt(&generator, stmt)
	}

	when ODIN_DEBUG {
		DumpModule(module)
	}

	InitializeX86Target()
	InitializeX86TargetInfo()
	InitializeX86TargetMC()
	InitializeX86AsmPrinter()

	triple := GetDefaultTargetTriple()

	target: TargetRef

	error: cstring
	if GetTargetFromTriple(triple, &target, &error) > 0 {
		fmt.println(triple, string(error))
		return false
	}
	SetTarget(module, triple)

	tm := CreateTargetMachine(
		target,
		triple,
		"generic",
		"",
		.CodeGenLevelNone,
		.RelocPIC,
		.CodeModelDefault,
	)

	SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	if VerifyModule(module, .AbortProcessAction, &error) > 0 {
		fmt.println(error)
		return false
	}
	if TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error) > 0 {
		fmt.println(error)
		return false
	}
	return true
}
