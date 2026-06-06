package main

Ast_Const_Decl :: struct {
	name:   string,
	expr:   ^Expr,
	symbol: ^Symbol,
}

const_parse :: proc(p: ^Parser) -> Ast_Const_Decl {
	name := current(p).value.(string)
	advance(p)
	expect(p, .ColonColon)

	expr := parse_expression(p, 0)

	return Ast_Const_Decl{name = name, expr = expr}
}

const_bind :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	data := &node.data.(Ast_Const_Decl)
	if existing, ok := resolve_symbol(cur_scope, data.name); ok {
		error_span(node.span, "Re-declaration of constant '%s'", data.name)
		data.symbol = existing
		return
	}

	sym := make_symbol(.Constant)
	cur_scope.symbols[data.name] = sym
	data.symbol = sym
}

const_decl_is_alias :: proc(expr: ^Expr, scope: ^Scope) -> bool {
	// Is this expression a type expression?
	_, ok := expr_to_type_expr(expr)
	if !ok {
		return false
	}

	// In case of being a type expression check if it's an identifier and
	// resolve to a symbol
	// By now all the symbols should be in place from the binding pass
	if v, is_var := expr.data.(Expr_Variable); is_var {
		sym, found := resolve_symbol(scope, v.value)
		return found && (sym.kind == .Type || sym.kind == .Type_Alias)
	}
	return true
}

const_eval :: proc(node: ^Ast_Node, scope: ^Scope) {
	data, is_const := node.data.(Ast_Const_Decl)
	if !is_const do return
	if data.symbol.kind == .Type_Alias do return
	value, ok := const_eval_expr(data.expr, scope, node.span)
	if !ok do return
	data.symbol.const_value = value
	switch v in value {
	case i64:
		sym, _ := resolve_symbol(scope, "untyped_int")
		data.symbol.type = sym.type
	case f64:
		sym, _ := resolve_symbol(scope, "untyped_float")
		data.symbol.type = sym.type
	}
}

const_eval_expr :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> (Const_Value, bool) {
	#partial switch e in expr.data {
	case Expr_Int_Literal:
		return e.value, true

	case Expr_Float_Literal:
		return e.value, true

	case Expr_Variable:
		sym, ok := resolve_symbol(scope, e.value)
		if !ok || sym.kind != .Constant {
			error_span(span, "'%s' is not a constant", e.value)
			return nil, false
		}
		if sym.const_value == nil {
			// Forward reference within the same const-eval pass. Order-of-decl matters today.
			error_span(span, "Constant '%s' used before its value is known", e.value)
			return nil, false
		}
		return sym.const_value, true

	case Expr_Unary:
		operand, ok := const_eval_expr(e.expr, scope, span)
		if !ok do return nil, false
		#partial switch e.op {
		case .Minus:
			switch v in operand {
			case i64:
				return -v, true
			case f64:
				return -v, true
			}
		}
		error_span(span, "Unsupported unary operator in constant expression")
		return nil, false

	case Expr_Binary:
		left, l_ok := const_eval_expr(e.left, scope, span)
		if !l_ok do return nil, false
		right, r_ok := const_eval_expr(e.right, scope, span)
		if !r_ok do return nil, false
		return const_eval_binary(e.op, left, right, span)
	}
	error_span(span, "Unsupported expression in constant")
	return nil, false
}

const_eval_binary :: proc(op: Token_Kind, a, b: Const_Value, span: Span) -> (Const_Value, bool) {
	_, a_is_f := a.(f64)
	_, b_is_f := b.(f64)

	if a_is_f || b_is_f {
		af := const_to_f64(a)
		bf := const_to_f64(b)
		#partial switch op {
		case .Plus:
			return af + bf, true
		case .Minus:
			return af - bf, true
		case .Star:
			return af * bf, true
		case .Slash:
			if bf == 0 {
				error_span(span, "Division by zero in constant expression")
				return nil, false
			}
			return af / bf, true
		}
		error_span(span, "Unsupported operator on float constants")
		return nil, false
	}

	ai := a.(i64)
	bi := b.(i64)
	#partial switch op {
	case .Plus:
		return ai + bi, true
	case .Minus:
		return ai - bi, true
	case .Star:
		return ai * bi, true
	case .Slash:
		if bi == 0 {
			error_span(span, "Division by zero in constant expression")
			return nil, false
		}
		return ai / bi, true
	case .Percent:
		if bi == 0 {
			error_span(span, "Modulo by zero in constant expression")
			return nil, false
		}
		return ai % bi, true
	}
	error_span(span, "Unsupported operator in constant expression")
	return nil, false
}

const_to_f64 :: proc(v: Const_Value) -> f64 {
	switch x in v {
	case i64:
		return f64(x)
	case f64:
		return x
	}
	return 0
}
