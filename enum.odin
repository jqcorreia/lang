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
