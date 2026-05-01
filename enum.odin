package main

Ast_Enum_Decl :: struct {
	name:      string,
	type_expr: ^Type_Expr,
	symbol:    ^Symbol,
	variants:  [dynamic]Ast_Enum_Variant,
}

Ast_Enum_Variant :: struct {
	name:  string,
	value: i64,
}

enum_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := node.data.(Ast_Enum_Decl)
	existing, ok := resolve_symbol(scope, data.name)
	if !ok {
		type := new(Type)
		type.kind = .Enum
		type.fields = {}
		sym := make_symbol(.Type)
		sym.name = data.name
		sym.type = type
		scope.symbols[data.name] = sym
		data.symbol = sym
		for &field, idx in data.variants {
			append(&sym.type.enum_variants, Enum_Variant{name = field.name, value = i64(idx)})
		}
	} else {
		error_span(node.span, "Re-declaration of enum '%s'", data.name)
		data.symbol = existing
	}
}

enum_resolve :: proc(node: ^Ast_Node) {
	// This shouldn't be needed
	// The type of the symbol created by this node is already set during scope binding
}

enum_decl_check :: proc(c: ^Checker, s: ^Ast_Enum_Decl, scope: ^Scope, span: Span) {
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

enum_member_resolve :: proc(expr: ^Expr, type: ^Type, scope: ^Scope, span: Span) -> ^Type {
	e := expr.data.(Expr_Member)


	for &f in type.enum_variants {
		if f.name == e.member {
			expr.type = type
			return type
		}
	}

	name, _ := get_type_name(scope, type)
	error_span(span, "Enum '%s' has no variant '%s'", name, e.member)

	expr.type = &error_type
	return &error_type
}

enum_member_emit_value :: proc(gen: ^Generator, expr: ^Expr) -> ValueRef {
	e := expr.data.(Expr_Member)
	for f in e.base.type.enum_variants {
		if f.name == e.member {
			return ConstInt(Int64TypeInContext(gen.ctx), u64(f.value), 0)
		}
	}
	unreachable()
}
