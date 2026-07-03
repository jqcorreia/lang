package main


Checker :: struct {
	current_function: ^Symbol,
}

global_scope: ^Scope

check :: proc(c: ^Checker, nodes: []^Ast_Node) {
	global_scope = create_global_scope()
	for node in nodes {
		bind_scopes(node, global_scope)
	}

	// Note: this should be avoided or better structured. Symbol redeclaration occur
	// in the bind phase and they need to stop compilation ASAP.
	// This simple check will do it for now. TODO
	if len(compiler.errors) > 0 {
		return
	}
	// Resolve type aliases, this needs to happen after bind in order to be able
	// to alias already ocurring symbols
	for node in nodes {
		if const, ok := node.data.(Ast_Const_Decl); ok {
			if const_decl_is_alias(const.expr, node.scope) {
				const.symbol.kind = .Type_Alias
			}
		}
	}
	for node in nodes {
		if fn, ok := node.data.(Ast_Function); ok {
			fn.symbol.type = function_signature_resolve(&fn, node.scope, node.span)
		}
	}
	for node in nodes {
		const_eval(node, global_scope)
	}
	for node in nodes {
		resolve_types(node)
	}
	if len(compiler.errors) > 0 {
		return
	}
	for node in nodes {
		check_stmt(c, node)
	}
}

check_stmt :: proc(c: ^Checker, node: ^Ast_Node) {
	#partial switch &data in node.data {
	case Ast_Const_Decl:
	case Ast_Block:
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
	case Ast_Union_Decl:
		union_decl_check(c, &data, node.scope, node.span)
	case Ast_Return:
		flow_return_check(c, &data, node.scope, node.span)
	case Ast_If:
		flow_if_check(c, node)
	case Ast_Match:
		match_check(c, node)
	case Ast_For:
		flow_for_check(c, node, node.span)
	case Ast_Break:
		flow_break_check(c, &data, node.scope, node.span)
	case Ast_Continue:
		flow_continue_check(c, &data, node.scope, node.span)
	case Ast_Import:
		check_import(c, &data, node.scope, node.span)
	case:
		compiler_bug(node.span, "Unimplemented check")
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


check_block :: proc(c: ^Checker, block: ^Ast_Block, span: Span) {
	for node in block.statements {
		check_stmt(c, node)
	}
}


check_import :: proc(c: ^Checker, node: ^Ast_Import, scope: ^Scope, span: Span) {
	if scope.kind != .Global {
		error_span(span, "Import statements must be at top-level")
	}
}
