package main

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
	data_layout:     TargetDataRef,
	const_zero:      ValueRef,
}

Loop :: struct {
	break_block:    BasicBlockRef,
	continue_block: BasicBlockRef,
}

get_llvm_type :: proc(gen: ^Generator, type: ^Type) -> TypeRef {
	if type.kind == .Array {
		elem_type := get_llvm_type(gen, type.elem_type)
		return ArrayType2(elem_type, type.size)
	}
	if type.kind == .Pointer || type.kind == .RawPointer {
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
	// Functions are pointers internally
	if type.kind == .Function {
		return PointerTypeInContext(gen.ctx, 0)
	}
	// Slices are structs {ptr, i64}
	// Field 0 is base pointer
	// Field 1 is size
	if type.kind == .Slice {
		elems: []TypeRef = {PointerTypeInContext(gen.ctx, 0), Int64TypeInContext(gen.ctx)}
		return StructTypeInContext(gen.ctx, raw_data(elems), 2, 0)
	}

	// Unions are structs {tag(u32), data }
	// Field 0 is tag
	// Field 1 is array of bytes
	if type.kind == .Union {
		i8_t := Int8TypeInContext(gen.ctx)
		elems: []TypeRef = {
			Int64TypeInContext(gen.ctx),
			ArrayType2(i8_t, u64(get_type_byte_size(type) - size_of(u64))),
		}
		return StructTypeInContext(gen.ctx, raw_data(elems), 2, 0)
	}

	return gen.primitive_types[type]
}

build_entry_alloca :: proc(gen: ^Generator, type: TypeRef, name: cstring) -> ValueRef {
	// Just keep track of current insertion point and make sure that the allocas
	// are created at the top of a block
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
	case Ast_Block, Ast_Import, Ast_Enum_Decl, Ast_Const_Decl, Ast_Union_Decl:
	// Do nothing
	case Ast_Module:
		for st in data.statements {
			emit_stmt(gen, st)
		}
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
			function_body_emit_sysv(gen, &data, node.scope, node.span)
		}
	case Ast_Return:
		flow_return_emit(gen, &data, node.scope, node.span)
	case Ast_If:
		flow_if_emit(gen, &data, node.scope, node.span)
	case Ast_Match:
		match_emit(gen, &data, node.scope, node.span)
	case Ast_For:
		flow_for_emit(gen, &data, node.scope, node.span)
	case Ast_Break:
		flow_break_emit(gen, &data, node.scope, node.span)
	case Ast_Continue:
		flow_continue_emit(gen, &data, node.scope, node.span)
	case:
		compiler_bug(node.span, "Unimplemented emit statement")
	}
}


emit_into :: proc(gen: ^Generator, expr: ^Expr, dest: ValueRef, scope: ^Scope, span: Span) {
	#partial switch &e in expr.data {
	case Expr_Array_Literal:
		array_literal_emit_into(gen, expr, dest, scope, span)
	case Expr_Struct_Literal:
		struct_emit_into(gen, expr, dest, scope, span)
	case Expr_Binary:
		if expr.type.kind == .Array {
			vec := array_binary_emit_vector(gen, &e, expr.type, scope, span)
			st := BuildStore(gen.builder, vec, dest)
			SetAlignment(st, 1)
			return
		}
		// Do the general case here also
		val := emit_value(gen, expr, scope, span)
		BuildStore(gen.builder, val, dest)
	case Expr_Array_To_Slice:
		array_to_slice_emit_into(gen, e, dest, expr.type, scope, span)
	case Expr_To_Union:
		union_expr_emit_into(gen, e, dest, expr.type, scope, span)
	case:
		// General fallback: emit value and store into dest
		val := emit_value(gen, expr, scope, span)
		BuildStore(gen.builder, val, dest)
	}
}

emit_address :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	#partial switch &e in expr.data {
	case Expr_Array_Literal:
		return array_literal_emit_address(gen, expr, scope, span)
	case Expr_Struct_Literal:
		return struct_emit_address(gen, expr, scope, span)

	case Expr_Identifier:
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
		#partial switch e.array.type.kind {
		case .Array:
			return array_expr_index_emit_address(gen, expr, scope, span)
		case .Slice:
			return slice_expr_index_emit_address(gen, expr, scope, span)
		}
		return array_expr_index_emit_address(gen, expr, scope, span)

	case Expr_Unary:
		if e.op == .Star {
			return emit_value(gen, e.expr, scope, span)
		}
	case Expr_Binary:
		ptr := build_entry_alloca(gen, get_llvm_type(gen, expr.type), "")
		emit_into(gen, expr, ptr, scope, span)

		return ptr
	}

	fatal_span(span, "Not addressable expresion", expr)

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
		// Check coerce() for the case of untyped_int -> numeric_float
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
		return array_literal_emit_value(gen, expr, scope, span)
	case Expr_Array_To_Slice:
		slice_type := get_llvm_type(gen, expr.type)
		slot := build_entry_alloca(gen, slice_type, "")
		array_to_slice_emit_into(gen, e, slot, expr.type, scope, span)
		return BuildLoad2(gen.builder, slice_type, slot, "")

	case Expr_To_Union:
		union_type := get_llvm_type(gen, expr.type)
		slot := build_entry_alloca(gen, union_type, "")
		union_expr_emit_into(gen, e, slot, expr.type, scope, span)
		return BuildLoad2(gen.builder, union_type, slot, "")


	case Expr_Struct_Literal:
		return struct_emit_value(gen, expr, scope, span)
	case Expr_Member:
		base_type := deref_type(e.base.type)

		if base_type.kind == .Struct {
			return struct_member_emit_value(gen, expr, scope, span)
		}
		if base_type.kind == .Enum {
			return enum_member_emit_value(gen, expr)
		}
	case Expr_Implicit_Variant:
		return enum_implicit_variant_emit_value(gen, expr)
	case Expr_Index:
		#partial switch e.array.type.kind {
		case .Array:
			return array_expr_index_emit_value(gen, expr, scope, span)
		case .Slice:
			ptr := emit_address(gen, expr, scope, span)
			return BuildLoad2(gen.builder, get_llvm_type(gen, expr.type), ptr, "")
		}
	case Expr_Call:
		return function_call_emit_sysv(gen, expr, scope, span)
	case Expr_Cast:
		return cast_emit_value(gen, expr, scope, span)
	case Expr_Identifier:
		sym, _ := resolve_symbol(scope, e.value)
		if sym.kind == .Constant {
			type := get_llvm_type(gen, expr.type)
			switch v in sym.const_value {
			case i64:
				return ConstInt(type, u64(v), 0)
			case f64:
				return ConstReal(type, v)
			}
		}
		if sym.kind == .Function {
			return gen.values[sym]
		}
		ptr := emit_address(gen, expr, scope, span)
		val := BuildLoad2(gen.builder, get_llvm_type(gen, sym.type), ptr, "")
		// Insert integer cast if expression type differs from storage type (e.g. untyped range var coerced to i32)
		sym_is_int :=
			sym.type.numeric_integer || sym.type.kind == .Untyped_Int || sym.type.kind == .Enum
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
		case .Tilde:
			// There is no bitwise NOT, the equivalent is a xor with all ones.
			operand := emit_value(gen, e.expr, scope, span)
			return BuildXor(
				gen.builder,
				operand,
				ConstAllOnes(get_llvm_type(gen, e.expr.type)),
				"bin_not",
			)
		}
	case Expr_Binary:
		if expr.type.kind == .Array {
			vec := array_binary_emit_vector(gen, &e, expr.type, scope, span)
			slot := build_entry_alloca(gen, get_llvm_type(gen, expr.type), "arrbin")
			BuildStore(gen.builder, vec, slot)
			return BuildLoad2(gen.builder, get_llvm_type(gen, expr.type), slot, "arrbinval")
		}
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
		case .Caret:
			return BuildBinOp(gen.builder, .Xor, left, right, "xor")
		case .DoubleStar:
			if e.left.type.numeric_integer && e.right.type.numeric_integer {
				// Call a prelude function
				sym, _ := resolve_symbol(scope, "__zero_pow")
				sym_type := gen.types[sym]
				sym_value := gen.values[sym]
				args := []ValueRef{left, right}
				return BuildCall2(gen.builder, sym_type, sym_value, &args[0], 2, "")
			}
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
		case .Ampersand:
			return BuildBinOp(gen.builder, .And, left, right, "bin_and")
		case .Pipe:
			return BuildBinOp(gen.builder, .Or, left, right, "bin_or")
		case .DoubleLesser:
			return BuildShl(gen.builder, left, right, "shit_left")
		case .DoubleGreater:
			if e.left.type.signed do return BuildAShr(gen.builder, left, right, "shift_rigt_arit")
			return BuildLShr(gen.builder, left, right, "shift_rigt_logic")
		case .DoublePipe:
			return BuildOr(gen.builder, left, right, "or")
		case .DoubleAmpersand:
			return BuildAnd(gen.builder, left, right, "and")
		}
	}

	//Note: Emit a compiler bug with immediate exit to avoid a segfault. TODO
	compiler_bug_exit(expr.span, "Expression %v emit not implemented", expr)
	return nil
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
		if llvm_type != nil && expr.type.numeric_float {
			return ConstReal(llvm_type, f64(e.value))
		} else {
			return ConstInt(llvm_type, u64(e.value), 0)
		}
	case Expr_Float_Literal:
		return ConstReal(llvm_type, e.value)
	case Expr_Bool_Literal:
		return ConstInt(llvm_type, e.value ? 1 : 0, 0)
	case Expr_String_Literal:
		return make_global_string_ptr(gen, e.value)
	case Expr_Struct_Literal:
		return struct_emit_const(gen, expr, scope)
	case Expr_Implicit_Variant:
		return enum_implicit_variant_emit_value(gen, expr)
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

	if is_global {
		make_global(gen, sym, s, scope)
		return
	}

	// Create pointer
	ptr, exists := gen.values[sym]
	if exists do fatal_span(span, "Variable aliasing detected. Fatal error for now")

	// Create alloca
	compiler_type := get_llvm_type(gen, sym.type)
	ptr = build_entry_alloca(gen, compiler_type, "")
	gen.values[sym] = ptr

	#partial switch sym.type.kind {
	case .Struct, .Array, .Slice:
		if s.expr != nil {
			emit_into(gen, s.expr, ptr, scope, span)
		} else {
			// If no expression do a memset op, potentially optimized by LLVM
			size := StoreSizeOfType(gen.data_layout, compiler_type)
			align := ABIAlignmentOfType(gen.data_layout, compiler_type)

			BuildMemSet(
				gen.builder,
				ptr,
				ConstInt(Int8TypeInContext(gen.ctx), 0, 0),
				ConstInt(Int64TypeInContext(gen.ctx), size, 0),
				align,
			)
		}
	case:
		val :=
			s.expr != nil ? emit_value(gen, s.expr, scope, span) : make_zero_value(gen, sym.type)
		BuildStore(gen.builder, val, ptr)
	}
}

make_global :: proc(gen: ^Generator, sym: ^Symbol, s: ^Ast_Var_Decl, scope: ^Scope) {
	llvm_type := get_llvm_type(gen, sym.type)
	ptr := AddGlobal(gen.module, llvm_type, strings.clone_to_cstring(s.name))
	if s.expr != nil {
		SetInitializer(ptr, make_const_value(gen, s.expr, scope))
	} else {
		SetInitializer(ptr, make_zero_value(gen, sym.type))
	}
	gen.values[sym] = ptr
}

emit_block :: proc(gen: ^Generator, block: ^Ast_Block) {
	for bst in block.statements {
		emit_stmt(gen, bst)
		if _, ok := bst.data.(Ast_Return); ok {
			block.terminated = true
		}
	}
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
	gen.const_zero = ConstInt(Int64TypeInContext(gen.ctx), 0, 0)
}

make_zero_value :: proc(gen: ^Generator, type: ^Type) -> ValueRef {
	if type.kind == .CString {
		return gen.empty_str_ptr
	}
	return ConstNull(get_llvm_type(gen, type))
}

generate :: proc(stmts: []^Ast_Node) -> bool {
	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("program", ctx)
	builder := CreateBuilderInContext(ctx)

	InitializeX86Target()
	InitializeX86TargetInfo()
	InitializeX86TargetMC()
	InitializeX86AsmPrinter()

	// Select the target triple. For cross-compilation we set it explicitly
	// rather than using the host default, so LLVM emits the right object
	// format (COFF) and calling convention (Microsoft x64) for the target.
	triple: cstring
	switch compiler.target {
	case "windows":
		triple = "x86_64-pc-windows-msvc"
	case:
		triple = GetDefaultTargetTriple()
	}

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

	data_layout := CreateTargetDataLayout(tm)
	SetModuleDataLayout(module, data_layout)
	generator := Generator {
		ctx         = ctx,
		module      = module,
		builder     = builder,
		data_layout = data_layout,
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
			function_decl_emit_sysv(gen, &fnode, node.scope, node.span)
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

	if len(compiler.errors) > 0 {
		return false
	}

	when ODIN_DEBUG {
		DumpModule(module)
	}

	if VerifyModule(module, .AbortProcessAction, &error) > 0 {
		fmt.println(error)
		return false
	}

	if !compiler.verify_only {
		if TargetMachineEmitToFile(
			   tm,
			   module,
			   strings.clone_to_cstring(compiler.object_filepath),
			   .ObjectFile,
			   &error,
		   ) >
		   0 {
			fmt.println(error)
			return false
		}
	}
	return true
}
