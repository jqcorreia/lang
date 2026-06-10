package main

import "core:fmt"

Expr_Array_Literal :: struct {
	elements: []^Expr,
}

Expr_Array_Type :: struct {
	size: ^Expr,
	elem: ^Expr,
}

Expr_Index :: struct {
	array: ^Expr,
	index: ^Expr,
}


expr_index_parse :: proc(left: ^Expr, index: ^Expr) -> ^Expr {
	ret := new(Expr)
	ret.data = Expr_Index {
		array = left,
		index = index,
	}

	return ret
}

array_literal_resolve :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	e := expr.data.(Expr_Array_Literal)
	elem_type: ^Type
	for &elem in e.elements {
		elem.type = resolve_expr_type(elem, scope, span)
		elem_type = elem.type
	}
	array_type := new(Type)
	array_type.kind = .Array
	array_type.size = u64(len(e.elements))
	array_type.elem_type = elem_type
	expr.type = array_type

	return array_type == nil ? &error_type : array_type
}

array_expr_index_resolve :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	e := expr.data.(Expr_Index)
	type := resolve_expr_type(e.array, scope, span)
	resolve_expr_type(e.index, scope, span)

	// fmt.println(type)
	// Support pointer to array
	if type.kind == .Pointer && type.pointee_type != nil && type.pointee_type.kind == .Array {
		type = type.pointee_type
	}
	if type.kind != .Array && type.kind != .Slice {
		name, _ := get_type_name(scope, type)
		error_span(span, "Cannot index non-array type '%s'", name)
		expr.type = &error_type
		return &error_type
	}
	expr.type = type.elem_type
	return type.elem_type
}

array_expr_index_check :: proc(c: ^Checker, expr: ^Expr, scope: ^Scope, span: Span) {
	e := expr.data.(Expr_Index)
	check_expr(c, e.array, scope, span)
	check_expr(c, e.index, scope, span)
	if e.array.type.kind == .Error || e.index.type.kind == .Error {
		return
	}
	array_type := e.array.type
	if array_type.kind == .Pointer && array_type.pointee_type.kind == .Array {
		array_type = array_type.pointee_type
	}
	if array_type.kind != .Array && array_type.kind != .Slice {
		error_span(span, "'%s' is not indexable", e.array.type.kind)
	} else if !e.index.type.numeric_integer && e.index.type.kind != .Untyped_Int {
		error_span(span, "Index must be an integer, got '%s'", e.index.type.kind)
	} else if lit, ok := e.index.data.(Expr_Int_Literal); ok {
		if u64(lit.value) >= array_type.size && array_type.kind == .Array {
			error_span(
				span,
				"Index %d out of bounds for array of size %d",
				lit.value,
				array_type.size,
			)
		}
	}
}

array_literal_emit_value :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	addr := array_literal_emit_address(gen, expr, scope, span)
	return BuildLoad2(gen.builder, get_llvm_type(gen, expr.type), addr, "")
}

array_literal_emit_address :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	array_llvm_type := get_llvm_type(gen, expr.type)
	ptr := build_entry_alloca(gen, array_llvm_type, "")
	array_literal_emit_into(gen, expr, ptr, scope, span)

	return ptr
}

array_literal_emit_into :: proc(
	gen: ^Generator,
	expr: ^Expr,
	dest: ValueRef,
	scope: ^Scope,
	span: Span,
) {
	e := expr.data.(Expr_Array_Literal)
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

}

array_expr_index_emit_address :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	e := expr.data.(Expr_Index)
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
}

array_expr_index_emit_value :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	ptr := array_expr_index_emit_address(gen, expr, scope, span)
	llvm_type := get_llvm_type(gen, expr.type)
	return BuildLoad2(gen.builder, llvm_type, ptr, "")
}

array_binary_emit_vector :: proc(
	gen: ^Generator,
	e: ^Expr_Binary,
	result_type: ^Type,
	scope: ^Scope,
	span: Span,
) -> ValueRef {

	gen_vec :: proc(
		gen: ^Generator,
		expr: ^Expr,
		array_type: ^Type,
		scope: ^Scope,
		span: Span,
	) -> ValueRef {
		// Build <N x T> matching the [N x T] storage.
		elem_llvm := get_llvm_type(gen, array_type.elem_type)
		vec_type := VectorType(elem_llvm, u32(array_type.size))
		vec: ValueRef

		if expr.type.kind == .Array {
			addr := emit_address(gen, expr, scope, span)
			vec = BuildLoad2(gen.builder, vec_type, addr, "lvec")
		} else {
			// It can only be a scalar
			// Broadcast into a vector and return that vector

			// Insert the scalar value into first element
			init := BuildInsertElement(
				gen.builder,
				GetUndef(vec_type),
				emit_value(gen, expr, scope, span),
				ConstInt(Int32Type(), 0, 0),
				"",
			)
			// Shuffle vector uses a mask (ConstNull == vector of all zeros)
			// This means that the element at index 0 of first vector will end in all the positions
			vec = BuildShuffleVector(
				gen.builder,
				init,
				GetUndef(vec_type),
				ConstNull(vec_type),
				"",
			)
		}

		// @Note: this uses alignment of 1 in order to not care right now for array alignments
		// Need to revisit this later.
		SetAlignment(vec, 1)
		return vec
	}

	// Load both arrays *as vectors*. Opaque pointers make this a
	// pure reinterpretation. No bitcast instruction needed.
	lvec := gen_vec(gen, e.left, result_type, scope, span)
	rvec := gen_vec(gen, e.right, result_type, scope, span)

	// Use same ops as scalar, they dispatch on Type so they
	// will operate on vectors, no problem
	is_float := result_type.elem_type.numeric_float
	#partial switch e.op {
	case .Plus:
		return(
			is_float ? BuildFAdd(gen.builder, lvec, rvec, "vadd") : BuildAdd(gen.builder, lvec, rvec, "vadd") \
		)
	case .Star:
		return(
			is_float ? BuildFMul(gen.builder, lvec, rvec, "vadd") : BuildMul(gen.builder, lvec, rvec, "vadd") \
		)
	case .Minus:
		return(
			is_float ? BuildFSub(gen.builder, lvec, rvec, "vadd") : BuildSub(gen.builder, lvec, rvec, "vadd") \
		)
	case .Slash:
		return(
			is_float ? BuildFDiv(gen.builder, lvec, rvec, "vadd") : BuildSDiv(gen.builder, lvec, rvec, "vadd") \
		)
	case:
		fatal_span(span, "Unsupported array operator '%v'", e.op)
	}
	return nil
}

coerce_to_array :: proc(from: ^Type, to: ^Type, scope: ^Scope) -> ^Type {
	if from.kind == .Array && to.kind == .Array {
		if from.size == to.size && coerce(from.elem_type, to.elem_type, scope) != nil do return to
		else do return nil
	}

	// Decide which is the scalar and the array
	scalar := is_scalar(from) ? from : to
	array := is_array(from) ? from : to

	// Coerce from scalar to the array elem_type
	coerced_scalar_type := coerce(scalar, array.elem_type, scope)
	if coerced_scalar_type != nil do return coerced_scalar_type

	// Different element size/type, return nil to flag error
	return nil

}

array_to_slice_emit_into :: proc(
	gen: ^Generator,
	expr: Expr_Array_To_Slice,
	dst: ValueRef,
	slice_type: ^Type,
	scope: ^Scope,
	span: Span,
) {
	// Create the backing array
	arr := expr.original
	n := arr.type.size
	backing_ty := get_llvm_type(gen, expr.original.type)
	backing := build_entry_alloca(gen, backing_ty, "")
	emit_into(gen, arr, backing, scope, span)

	struct_ty := get_llvm_type(gen, slice_type)

	p0 := BuildStructGEP2(gen.builder, struct_ty, dst, 0, "")
	BuildStore(gen.builder, backing, p0)
	p1 := BuildStructGEP2(gen.builder, struct_ty, dst, 1, "")
	BuildStore(gen.builder, ConstInt(Int64TypeInContext(gen.ctx), n, 0), p1)
}
