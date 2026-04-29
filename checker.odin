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
		check_function(c, &data, node.scope, node.span)
	case Ast_Struct_Decl:
		struct_decl_check(c, &data, node.scope, node.span)
	case Ast_Enum_Decl:
		check_enum_decl(c, &data, node.scope, node.span)
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
	case Expr_Int_Literal, Expr_Float_Literal, Expr_String_Literal:
	// Nothing to check

	case Expr_Array_Literal:
		for elem in e.elements {
			check_expr(c, elem, scope, span)
		}

	case Expr_Index:
		check_expr(c, e.array, scope, span)
		check_expr(c, e.index, scope, span)
		if e.array.type.kind == .Error || e.index.type.kind == .Error {
			return
		}
		array_type := e.array.type
		if array_type.kind == .Pointer && array_type.pointee_type.kind == .Array {
			array_type = array_type.pointee_type
		}
		if array_type.kind != .Array {
			error_span(span, "'%s' is not an array", e.array.type.kind)
		} else if !e.index.type.numeric_integer && e.index.type.kind != .Untyped_Int {
			error_span(span, "Array index must be an integer, got '%s'", e.index.type.kind)
		} else if lit, ok := e.index.data.(Expr_Int_Literal); ok {
			if u64(lit.value) >= array_type.size {
				error_span(
					span,
					"Index %d out of bounds for array of size %d",
					lit.value,
					array_type.size,
				)
			}
		}

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
		if e.left.type.kind == .Error || e.right.type.kind == .Error {
			return
		}
		is_logical := e.op == .DoublePipe || e.op == .DoubleAmpersand
		if is_logical {
			if e.left.type.kind != .Bool {
				error_span(
					span,
					"Left operand of '%s' must be bool, got '%s'",
					e.op,
					e.left.type.kind,
				)
			}
			if e.right.type.kind != .Bool {
				error_span(
					span,
					"Right operand of '%s' must be bool, got '%s'",
					e.op,
					e.right.type.kind,
				)
			}
		} else if expr.type.kind == .Error {
			error_span(
				span,
				"Type mismatch: '%s' %s '%s'",
				e.left.type.kind,
				e.op,
				e.right.type.kind,
			)
		}

	case Expr_Call:
		check_call(c, e, expr, scope, span)

	case Expr_Member:
		// Struct + "not an aggregate" + undefined-variable errors now report from
		// resolver (Expr_Member / Expr_Variable). Enum-side reporting stays here
		// until the enum.odin pilot moves it; the cast is guarded so nested
		// member access (e.base is itself an Expr_Member) does not crash.
		if expr.type.kind == .Error {
			if base, ok := e.base.data.(Expr_Variable); ok {
				sym, sym_ok := resolve_symbol(scope, base.value)
				if sym_ok && sym.type != nil && sym.type.kind == .Enum {
					error_span(span, "Enum '%s' has no variant '%s'", base.value, e.member)
				}
			}
		}

	case Expr_Struct_Literal:
		if expr.type.kind == .Error {
			error_span(span, "Undefined struct type '%s'", e.type_expr)
		}
	}
}

check_call :: proc(c: ^Checker, e: Expr_Call, call_expr: ^Expr, scope: ^Scope, span: Span) {
	func_name := e.callee.data.(Expr_Variable).value
	sym, ok := resolve_symbol(scope, func_name)
	if !ok {
		error_span(span, "Undefined function '%s'", func_name)
		return
	}
	decl := sym.decl.data.(Ast_Function)
	variadic_found := false
	required_params := 0
	for param in decl.params {
		if !param.variadic_marker {
			required_params += 1
		}
	}
	if len(e.args) < required_params {
		error_span(span, "Too few arguments for '%s'", func_name)
	}
	for arg, i in e.args {
		check_expr(c, arg, scope, span)
		if variadic_found || arg.type.kind == .Error {
			continue
		}
		if i >= len(decl.params) {
			error_span(span, "Too many arguments for '%s'", func_name)
			continue
		}
		param := decl.params[i]
		if param.variadic_marker {
			variadic_found = true
			continue
		}
		decl_type := param.symbol.type
		if decl_type == nil || decl_type.kind == .Error {
			continue
		}
		if type_coercion(arg.type, decl_type, scope) == nil {
			error_span(
				span,
				"Argument %d of '%s': expected '%s', got '%s'",
				i + 1,
				func_name,
				decl_type.kind,
				arg.type.kind,
			)
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
		   type_coercion(s.expr.type, s.symbol.type, scope) == nil {
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
	if type_coercion(s.expr.type, s.lhs.type, scope) == nil {
		error_span(span, "Cannot assign '%s' to '%s'", s.expr.type.kind, s.lhs.type.kind)
	}
}

check_function :: proc(c: ^Checker, s: ^Ast_Function, scope: ^Scope, span: Span) {
	for param in s.params {
		if !param.variadic_marker &&
		   (param.symbol.type == nil || param.symbol.type.kind == .Error) {
			error_span(
				span,
				"Unresolved type '%s' for parameter '%s'",
				param.type_expr,
				param.name,
			)
		}
	}
	if s.symbol.type == nil || s.symbol.type.kind == .Error {
		error_span(span, "Unresolved return type '%s' for '%s'", s.ret_type_expr, s.name)
	}
	if !s.external {
		old_function := c.current_function
		c.current_function = s.symbol
		check_block(c, s.body, span)
		c.current_function = old_function
	}
}

check_enum_decl :: proc(c: ^Checker, s: ^Ast_Enum_Decl, scope: ^Scope, span: Span) {
	if len(s.variants) == 0 {
		error_span(span, "Enum '%s' has no variants", s.name)
		return
	}
	for v, i in s.variants {
		for j in 0 ..< i {
			if s.variants[j].name == v.name {
				error_span(span, "Duplicate variant '%s' in enum '%s'", v.name, s.name)
				break
			}
		}
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
	if type_coercion(s.expr.type, fn_type, scope) == nil {
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
