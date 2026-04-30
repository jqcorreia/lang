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
