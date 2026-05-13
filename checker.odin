package main

import "core:fmt"

Checker :: struct {
	current_function: ^Symbol,
}

global_scope: ^Scope

check :: proc(c: ^Checker, nodes: []^Ast_Node) {
	global_scope = create_global_scope()
	for node in nodes {
		bind_scopes(node, global_scope)
	}
	for node in nodes {
		resolve_types(node)
	}
	for node in nodes {
		check_stmt(c, node)
	}
}

check_stmt :: proc(c: ^Checker, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Expr:
		check_expr(c, data.expr, node.scope, node.span)
	case Ast_Var_Decl:
		check_var_decl(c, &data, node.scope, node.span)
	case Ast_Var_Assign:
		check_assignment(c, &data, node.scope, node.span)
	case Ast_Function:
		function_check(c, &data, node.scope, node.span)
	case Ast_Struct_Decl:
		struct_decl_check(c, &data, node.scope, node.span)
	case Ast_Enum_Decl:
		enum_decl_check(c, &data, node.scope, node.span)
	case Ast_Return:
		check_return(c, &data, node.scope, node.span)
	case Ast_If:
		check_expr(c, data.cond, node.scope, node.span)
		check_if(c, &data, node.span)
	case Ast_For:
		if data.range != nil {
			check_expr(c, data.range, node.scope, node.span)
		}
		check_for_loop(c, &data, node.span)
	case Ast_Break:
		check_break(c, &data, node.scope, node.span)
	case Ast_Continue:
		check_continue(c, &data, node.scope, node.span)
	case Ast_Block:
	case Ast_Import:
		check_import(c, &data, node.scope, node.span)
	case:
		unimplemented(fmt.tprint("Unimplemented check", node))
	}
}

check_expr :: proc(c: ^Checker, expr: ^Expr, scope: ^Scope, span: Span) {
	#partial switch e in expr.data {
	case Expr_Int_Literal, Expr_Float_Literal, Expr_String_Literal, Expr_Member:
	// Nothing to check

	case Expr_Array_Literal:
		for elem in e.elements {
			check_expr(c, elem, scope, span)
		}

	case Expr_Implicit_Variant:
		enum_implicit_variant_check(expr, scope, span)

	case Expr_Index:
		array_expr_index_check(c, expr, scope, span)

	case Expr_Unary:
		check_expr(c, e.expr, scope, span)
		if e.expr.type.kind == .Error {
			return
		}
		#partial switch e.op {
		case .Bang:
			if e.expr.type.kind != .Bool {
				error_span(span, "Operator '!' requires bool operand, got '%s'", e.expr.type.kind)
			}
		case .Minus:
			if !e.expr.type.numeric_integer && !e.expr.type.numeric_float {
				error_span(
					span,
					"Operator '-' requires numeric operand, got '%s'",
					e.expr.type.kind,
				)
			}
		case .Star:
			if e.expr.type.kind != .Pointer {
				error_span(span, "Cannot dereference non-pointer type '%s'", e.expr.type.kind)
			}
		}

	case Expr_Binary:
		check_expr(c, e.left, scope, span)
		check_expr(c, e.right, scope, span)

	case Expr_Call:
		function_call_check(c, e, expr, scope, span)

	case Expr_Struct_Literal:
		if expr.type.kind == .Error {
			error_span(span, "Undefined struct type '%s'", e.type_expr)
		}
	}
}


check_var_decl :: proc(c: ^Checker, s: ^Ast_Var_Decl, scope: ^Scope, span: Span) {
	if s.symbol.type == nil || s.symbol.type.kind == .Error {
		if s.type_expr != nil {
			error_span(span, "Unresolved type '%s' for '%s'", s.type_expr, s.name)
		} else {
			error_span(span, "Cannot infer type for '%s'", s.name)
		}
		return
	}
	if s.expr != nil {
		check_expr(c, s.expr, scope, span)
		if s.expr.type != nil &&
		   s.expr.type.kind != .Error &&
		   coerce(s.expr.type, s.symbol.type, scope) == nil {
			error_span(
				span,
				"Type mismatch in '%s': expected '%s', got '%s'",
				s.name,
				s.symbol.type.kind,
				s.expr.type.kind,
			)
		}
	}
}

check_assignment :: proc(c: ^Checker, s: ^Ast_Var_Assign, scope: ^Scope, span: Span) {
	check_expr(c, s.lhs, scope, span)
	check_expr(c, s.expr, scope, span)
	if s.lhs.type.kind == .Error || s.expr.type.kind == .Error {
		return
	}
	if coerce(s.expr.type, s.lhs.type, scope) == nil {
		error_span(span, "Cannot assign '%s' to '%s'", s.expr.type.kind, s.lhs.type.kind)
	}
}


check_return :: proc(c: ^Checker, s: ^Ast_Return, scope: ^Scope, span: Span) {
	if c.current_function == nil {
		error_span(span, "Return statement outside of function")
		return
	}
	if s.expr == nil {
		return
	}
	check_expr(c, s.expr, scope, span)
	if s.expr.type.kind == .Error {
		return
	}
	fn_type := c.current_function.type
	if fn_type == nil || fn_type.kind == .Error {
		return
	}
	if coerce(s.expr.type, fn_type, scope) == nil {
		error_span(
			span,
			"Return type mismatch in '%s': expected '%s', got '%s'",
			c.current_function.name,
			fn_type.kind,
			s.expr.type.kind,
		)
	}
}

check_block :: proc(c: ^Checker, block: ^Ast_Block, span: Span) {
	for node in block.statements {
		check_stmt(c, node)
	}
}

check_if :: proc(c: ^Checker, s: ^Ast_If, span: Span) {
	check_block(c, s.then_block, span)
	if s.else_block != nil {
		check_block(c, s.else_block, span)
	}
}

check_for_loop :: proc(c: ^Checker, s: ^Ast_For, span: Span) {
	check_block(c, s.body, span)
}

check_break :: proc(c: ^Checker, s: ^Ast_Break, scope: ^Scope, span: Span) {
	sc := scope
	for {
		if sc.kind == .Loop {
			return
		}
		if sc.parent == nil do break
		sc = sc.parent
	}
	error_span(span, "Break statement outside of loop")
}

check_continue :: proc(c: ^Checker, s: ^Ast_Continue, scope: ^Scope, span: Span) {
	sc := scope
	for {
		if sc.kind == .Loop {
			return
		}
		if sc.parent == nil do break
		sc = sc.parent
	}
	error_span(span, "Continue statement outside of loop")
}

check_import :: proc(c: ^Checker, node: ^Ast_Import, scope: ^Scope, span: Span) {
	if scope.kind != .Global {
		error_span(span, "Import statements must be at top-level")
	}
}
