package main

import "core:fmt"

error_type := Type {
	kind = .Error,
}

resolve_types :: proc(node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Const_Decl:
		if data.symbol.kind == .Type_Alias {
			te, _ := expr_to_type_expr(data.expr)
			data.symbol.type = resolve_type_expr(&te, node.scope, node.span)
		}
	case Ast_Break:
	case Ast_Import:
	case Ast_Block:
		for n in data.statements {
			resolve_types(n)
		}
	case Ast_Var_Assign:
		resolve_expr_type(data.lhs, node.scope, node.span)
		resolve_expr_type(data.expr, node.scope, node.span)
		coerced_type := coerce(data.expr.type, data.lhs.type, node.scope)
		if coerced_type != nil {
			set_expr_type(data.expr, coerced_type, node.scope)
		}
	case Ast_Var_Decl:
		resolved_type: ^Type
		initializer_expr_type: ^Type

		// Get the initializer expression type
		if data.expr != nil {
			initializer_expr_type = resolve_expr_type(data.expr, node.scope, node.span)
		}

		// Deal with both cases of having types defined or not
		if data.type_expr == nil {
			if initializer_expr_type == nil {
				data.symbol.type = &error_type
				return
			}
			resolved_type = initializer_expr_type
			if initializer_expr_type.kind == .Untyped_Int {
				i64_sym, _ := resolve_symbol(node.scope, "i64")
				resolved_type = i64_sym.type
			} else if initializer_expr_type.kind == .Untyped_Float {
				f64_sym, _ := resolve_symbol(node.scope, "f64")
				resolved_type = f64_sym.type
			}
		} else {
			var_type := resolve_type_expr(&data.type_expr, node.scope, node.span)
			resolved_type = var_type
		}

		// Deal with type coercion
		if data.expr != nil {
			coerced_type := coerce(initializer_expr_type, resolved_type, node.scope)
			if coerced_type != nil {
				data.symbol.type = coerced_type
				set_expr_type(data.expr, coerced_type, node.scope)
			} else {
				// Keep natural types so the checker can report a meaningful mismatch
				data.symbol.type = resolved_type
				data.expr.type = initializer_expr_type
			}
		} else {
			data.symbol.type = resolved_type
		}

	case Ast_Struct_Decl:
		struct_decl_resolve(node)

	case Ast_Enum_Decl:
		enum_resolve(node)

	case Ast_Function:
		function_resolve(node)

	case Ast_Expr:
		data.expr.type = resolve_expr_type(data.expr, node.scope, node.span)

	case Ast_If:
		resolve_expr_type(data.cond, node.scope, node.span)
		resolve_block_types(data.then_block)
		if data.else_block != nil {
			resolve_block_types(data.else_block)
		}
	case Ast_For:
		if data.range != nil {
			resolve_expr_type(data.range, node.scope, node.span)
			range := data.range.data.(Expr_Range)
			data.symbol.type = range.start.type
		}
		resolve_block_types(data.body)

	case Ast_Return:
		if data.expr != nil {
			expr_type := resolve_expr_type(data.expr, node.scope, node.span)
			sym := get_scope_function(node.scope)
			if sym != nil && sym.type != nil && sym.type.kind != .Error {
				coerced_type := coerce(expr_type, sym.type.return_type, node.scope)
				if coerced_type != nil {
					set_expr_type(data.expr, coerced_type, node.scope)
				}
				// On coercion failure, leave data.expr.type as the natural type
				// so the checker can report expected vs got
			}
		}

	case:
		unimplemented(fmt.tprintf("Unimplemented resolve for node %v", node))
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
		return array_expr_array_literal_resolve(expr, scope, span)

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

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok {
			error_span(span, "Undefined variable '%s'", e.value)
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
		fmt.println("before", left.kind, right.kind)
		coerced_type := unify(left, right, scope)
		fmt.println("after", left.kind, right.kind, coerced_type.kind)
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
		fmt.println("before set expr", e.left.type.kind, e.right.type.kind, coerced_type.kind)
		// set_expr_type(e.left, coerced_type, scope)
		// set_expr_type(e.right, coerced_type, scope)
		fmt.println("after set expr", e.left.type.kind, e.right.type.kind, coerced_type.kind)

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
	unimplemented("You should not be here at all")
}

resolve_block_types :: proc(block: ^Ast_Block) {
	for node in block.statements {
		resolve_types(node)
	}
}
