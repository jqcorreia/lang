package main

import "core:fmt"

error_type := Type {
	kind = .Error,
}

resolve_types :: proc(node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Block:
		for n in data.statements {
			resolve_types(n)
		}
	case Ast_Var_Assign:
		resolve_expr_type(data.lhs, node.scope, node.span)
		resolve_expr_type(data.expr, node.scope, node.span)
		coerced_type := type_coercion(data.expr.type, data.lhs.type, node.scope)
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
			coerced_type := type_coercion(initializer_expr_type, resolved_type, node.scope)
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
		type_sym, ok := resolve_symbol(node.scope, data.name)
		if !ok {
			return
		}

		data.symbol.type = type_sym.type
		for &field, idx in data.fields {
			type_sym.type.fields[idx].type = resolve_type_expr(
				&field.type_expr,
				node.scope,
				node.span,
			)
		}

	case Ast_Enum_Decl:
	// This shouldn't be needed
	// The type of the symbol created by this node is already set during scope binding
	// type_sym, ok := resolve_symbol(node.scope, data.name)
	// if !ok {
	// 	return
	// }

	// data.symbol.type = type_sym.type

	case Ast_Function:
		for &param in data.params {
			param.symbol.type = resolve_type_expr(&param.type_expr, node.scope, node.span)
		}
		data.symbol.type = resolve_type_expr(&data.ret_type_expr, node.scope, node.span)

		if !data.external {
			resolve_block_types(data.body)
		}

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
				coerced_type := type_coercion(expr_type, sym.type, node.scope)
				if coerced_type != nil {
					set_expr_type(data.expr, coerced_type, node.scope)
				}
				// On coercion failure, leave data.expr.type as the natural type
				// so the checker can report expected vs got
			}
		}

	case Ast_Break:
	case Ast_Import:
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
		type := resolve_type_expr(&e.type_expr, scope, span)
		if type == &error_type {
			expr.type = &error_type
			return &error_type
		}

		expr.type = type
		for arg_name, arg in e.args {
			for field in type.fields {
				if field.name == arg_name {
					arg_type := resolve_expr_type(arg, scope, span)
					coerced_type := type_coercion(arg_type, field.type, scope)
					if coerced_type != nil {
						set_expr_type(arg, coerced_type, scope)
					} else {
						arg.type = arg_type
					}
				}
			}
		}
		return type

	case Expr_Array_Literal:
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

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok || sym.type == nil {
			expr.type = &error_type
			return &error_type
		}
		expr.type = sym.type
		return sym.type

	case Expr_Member:
		type := resolve_expr_type(e.base, scope, span)

		// Support pointer to struct
		if type.kind == .Pointer && type.pointee_type != nil && type.pointee_type.kind == .Struct {
			type = type.pointee_type
		}

		if type == nil || (type.kind != .Struct && type.kind != .Enum) {
			expr.type = &error_type
			return &error_type
		}

		if type.kind == .Struct {
			for &f in type.fields {
				if f.name == e.member {
					// e.base.type = type
					expr.type = f.type
					return f.type
				}
			}
		}
		// In this case just set and return the base type
		// The enum_variants loop is there to check if the variant exists
		// and only then set the type and return it, otherwise it ends on error branch
		if type.kind == .Enum {
			for &f in type.enum_variants {
				if f.name == e.member {
					expr.type = type
					return expr.type
				}
			}
		}

		expr.type = &error_type
		return &error_type

	case Expr_Index:
		type := resolve_expr_type(e.array, scope, span)
		resolve_expr_type(e.index, scope, span)

		// Support pointer to array
		if type.kind == .Pointer && type.pointee_type != nil && type.pointee_type.kind == .Array {
			type = type.pointee_type
		}
		if type.kind != .Array {
			expr.type = &error_type
			return &error_type
		}
		expr.type = type.elem_type
		return type.elem_type

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

		coerced := type_coercion(start_type, end_type, scope)
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
		coerced_type := type_coercion(left, right, scope)
		if coerced_type == nil {
			expr.type = &error_type
			return &error_type
		}
		set_expr_type(e.left, coerced_type, scope)
		set_expr_type(e.right, coerced_type, scope)

		is_logical := e.op == .DoublePipe || e.op == .DoubleAmpersand
		if is_logical {
			if coerced_type.kind != .Bool {
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
				expr.type = &error_type
				return &error_type
			}
			bool_sym, _ := resolve_symbol(scope, "bool")
			expr.type = bool_sym.type
			return bool_sym.type
		}

		expr.type = coerced_type
		return coerced_type

	case Expr_Call:
		func_name := e.callee.data.(Expr_Variable).value
		sym, ok := resolve_symbol(scope, func_name)
		if !ok {
			expr.type = &error_type
			return &error_type
		}
		decl := sym.decl.data.(Ast_Function)
		if sym.type == nil {
			// Not resolved yet, do it here
			type := resolve_type_expr(&decl.ret_type_expr, scope, span)
			e.callee.type = type
			sym.type = type
		} else {
			e.callee.type = sym.type
		}
		variadic_found := false
		for arg, i in e.args {
			if variadic_found {
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			if i >= len(decl.params) {
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			param := &decl.params[i]
			if param.variadic_marker {
				variadic_found = true
				arg.type = resolve_expr_type(arg, scope, span)
				continue
			}
			arg_type := resolve_expr_type(arg, scope, span)
			decl_type := param.symbol.type
			if decl_type == nil {
				// Not resolved yet, do it here
				param_type := resolve_type_expr(&param.type_expr, scope, span)
				param.symbol.type = param_type
				decl_type = param_type
			}
			if decl_type != nil {
				coerced_type := type_coercion(arg_type, decl_type, scope)
				if coerced_type != nil {
					set_expr_type(arg, coerced_type, scope)
				} else {
					arg.type = arg_type // keep actual type, checker will report
				}
			} else {
				arg.type = arg_type
			}
		}
		expr.type = e.callee.type
		return e.callee.type
	}
	unimplemented("You should not be here at all")
}

resolve_block_types :: proc(block: ^Ast_Block) {
	for node in block.statements {
		resolve_types(node)
	}
}
