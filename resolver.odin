package main

resolve_types :: proc(node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Const_Decl:
		if data.symbol.kind == .Type_Alias {
			te, _ := expr_to_type_expr(data.expr)
			data.symbol.type = resolve_type_expr(&te, node.scope, node.span)
		}
	case Ast_Break, Ast_Continue:
	case Ast_Import:
	case Ast_Block:
		for n in data.statements {
			resolve_types(n)
		}
	case Ast_Var_Assign:
		resolve_expr_type(data.lhs, node.scope, node.span)
		resolve_expr_type(data.expr, node.scope, node.span)
		coerced_type := coerce_expr(data.expr, data.lhs.type, node.scope)
		if coerced_type != nil {
			set_expr_type(data.expr, coerced_type, node.scope)
		}
	case Ast_Var_Decl:
		target_type: ^Type
		initializer_expr_type: ^Type
		type_expr_type: ^Type

		// Get the initializer expression type
		if data.expr != nil {
			initializer_expr_type = resolve_expr_type(data.expr, node.scope, node.span)
		}

		// Resolve type expression effective type
		if data.type_expr.data != nil {
			type_expr_type = resolve_type_expr(&data.type_expr, node.scope, node.span)
		}

		if data.expr == nil && data.type_expr.data == nil {
			error_span(node.span, "Could not infer type")
			return
		}

		if type_expr_type != nil && initializer_expr_type == nil {
			// No initializer just set the symbol type and return
			data.symbol.type = type_expr_type
			return
		}

		// Inherit initializer type if type expression not present
		target_type = data.type_expr.data == nil ? initializer_expr_type : type_expr_type
		coerced_type := coerce_expr(data.expr, target_type, node.scope)

		if coerced_type == nil {
			error_span(
				node.span,
				"Type mismatch, expected %s, got %s",
				serialize_type(type_expr_type),
				serialize_type(initializer_expr_type),
			)
			// Keep natural types so the checker can report a meaningful mismatch
			data.symbol.type = target_type
			data.expr.type = initializer_expr_type
			return
		}

		// Set the symbol final type
		data.symbol.type = coerced_type

	case Ast_Struct_Decl:
		struct_decl_resolve(node)
	case Ast_Enum_Decl:
		enum_resolve(node)
	case Ast_Union_Decl:
		union_decl_resolve(node)
	case Ast_Function:
		function_resolve(node)
	case Ast_Expr:
		data.expr.type = resolve_expr_type(data.expr, node.scope, node.span)
	case Ast_If:
		flow_if_resolve(node)
	case Ast_Match:
		match_resolve(node)
	case Ast_For:
		flow_for_resolve(node)
	case Ast_Return:
		flow_return_resolve(node)
	case:
		compiler_bug(node.span, "Unimplemented resolve for node %v")
	}
}

resolve_expr_type :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	switch &e in expr.data {
	case Expr_Null:
		null := new(Type)
		null.kind = .Nil
		expr.type = null

		return expr.type

	case Expr_Int_Literal:
		sym, _ := resolve_symbol(scope, "untyped_int")
		expr.type = sym.type
		return sym.type

	case Expr_Float_Literal:
		sym, _ := resolve_symbol(scope, "untyped_float")
		expr.type = sym.type
		return sym.type

	case Expr_Bool_Literal:
		sym, _ := resolve_symbol(scope, "bool")
		expr.type = sym.type
		return sym.type

	case Expr_String_Literal:
		sym, _ := resolve_symbol(scope, "cstr")
		expr.type = sym.type
		return sym.type

	case Expr_Struct_Literal:
		return struct_literal_resolve(expr, scope, span)

	case Expr_Array_Literal:
		return array_literal_resolve(expr, scope, span)

	case Expr_Array_Type, Expr_Function:
		// A type appearing in value position. Lower to a type expression and resolve it
		te, ok := expr_to_type_expr(expr)
		if !ok {
			error_span(span, "Invalid type expression")
			expr.type = &error_type
			return &error_type
		}
		t := resolve_type_expr(&te, scope, span)
		expr.type = t
		return t

	case Expr_Implicit_Variant:
		return enum_implicit_variant_resolve(expr, scope, span)

	case Expr_Identifier:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok {
			error_span(expr.span, "Undefined variable '%s'", e.value)
			expr.type = &error_type
			return &error_type
		}
		if sym.type == nil {
			expr.type = &error_type
			return &error_type
		}
		expr.type = sym.type
		return sym.type

	case Expr_Call:
		return function_call_resolve(expr, scope, span)

	case Expr_Array_To_Slice:
	case Expr_To_Union:
	case Expr_Cast:
	// Nothing is needed here since everything is done via the resolve branch of Expr_Call
	case Expr_Member:
		base_type := resolve_expr_type(e.base, scope, span)
		if base_type.kind == .Error {
			// Already reported by the inner resolution; don't cascade.
			expr.type = &error_type
			return &error_type
		}

		type := base_type
		if type.kind == .Pointer && type.pointee_type != nil {
			type = type.pointee_type
		}

		if type.kind == .Struct {
			return struct_member_resolve(expr, type, scope, span)
		}

		if type.kind == .Enum {
			return enum_member_resolve(expr, type, scope, span)
		}

		error_span(span, "Cannot access member '%s' on non-aggregate type", e.member)
		expr.type = &error_type
		return &error_type

	case Expr_Index:
		return array_expr_index_resolve(expr, scope, span)

	case Expr_Unary:
		operand := resolve_expr_type(e.expr, scope, span)
		#partial switch e.op {
		case .Ampersand:
			pointer_type := new(Type)
			pointer_type.kind = .Pointer
			pointer_type.pointee_type = operand
			expr.type = pointer_type
			return pointer_type
		case .Star:
			if operand.kind == .Pointer {
				expr.type = operand.pointee_type
				return operand.pointee_type
			} else {
				expr.type = &error_type
				return &error_type
			}
		case:
			expr.type = operand
			return operand
		}

	case Expr_Range:
		start_type := resolve_expr_type(e.start, scope, span)
		end_type := resolve_expr_type(e.end, scope, span)
		if start_type.kind == .Untyped_Int && end_type.kind == .Untyped_Int {
			expr.type = start_type
			return expr.type
		}

		coerced := unify(start_type, end_type, scope)
		if coerced == nil {
			expr.type = &error_type
			return &error_type
		}
		if coerced.kind == .Untyped_Int {
			i64_sym, _ := resolve_symbol(scope, "i64")
			coerced = i64_sym.type
		}
		e.start.type = coerced
		e.end.type = coerced
		expr.type = coerced
		return coerced

	case Expr_Binary:
		left := resolve_expr_type(e.left, scope, span)
		right := resolve_expr_type(e.right, scope, span)

		// In case of arrays and scalar we can't follow the unification path
		if (is_array(left) && is_scalar(right)) || (is_array(right) && is_scalar(left)) {
			// Decide which is the scalar which is the array
			scalar := is_scalar(left) ? left : right
			array := is_array(left) ? left : right
			scalar_expr := is_scalar(left) ? e.left : e.right
			array_expr := is_array(left) ? e.left : e.right

			// Broadcast: coerce the scalar to the array's element type (or fail)
			scalar_coerced_type := coerce(scalar, array.elem_type, scope)

			// Set the specific types
			set_expr_type(scalar_expr, scalar_coerced_type, scope)
			set_expr_type(array_expr, array, scope)

			expr.type = array
			return array
		}

		coerced_type := unify(left, right, scope)
		if coerced_type == nil {
			error_span(
				span,
				"Type mismatch: '%s' %s '%s'",
				e.left.type.kind,
				e.op,
				e.right.type.kind,
			)
			expr.type = &error_type
			return &error_type
		}
		set_expr_type(e.left, coerced_type, scope)
		set_expr_type(e.right, coerced_type, scope)

		is_logical := e.op == .DoublePipe || e.op == .DoubleAmpersand
		if is_logical {
			if e.left.type.kind != .Bool || e.right.type.kind != .Bool {
				error_span(
					span,
					"Both operands of '%s' must be bool, got '%s' and '%s'",
					e.op,
					e.left.type.kind,
					e.right.type.kind,
				)
				expr.type = &error_type
				return &error_type
			}
			expr.type = coerced_type
			return coerced_type
		}

		is_comparison :=
			e.op == .DoubleEqual ||
			e.op == .NotEqual ||
			e.op == .Greater ||
			e.op == .Lesser ||
			e.op == .GreaterOrEqual ||
			e.op == .LesserOrEqual

		if is_comparison {
			if coerced_type.kind == .Struct || coerced_type.kind == .Array {
				error_span(span, "Unsupported comparison: '%s' %s '%s'", left, e.op, right)
				expr.type = &error_type
				return &error_type
			}
			bool_sym, _ := resolve_symbol(scope, "bool")
			expr.type = bool_sym.type
			return bool_sym.type
		}

		expr.type = coerced_type
		return coerced_type
	}
	compiler_bug(expr.span, "You should not be here at all")

	return nil
}

resolve_block_types :: proc(block: ^Ast_Block) {
	for node in block.statements {
		resolve_types(node)
	}
}
