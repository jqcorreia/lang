package main

import "core:fmt"

Ast_Union_Decl :: struct {
	name:     string,
	variants: [dynamic]Ast_Union_Variant,
	symbol:   ^Symbol,
}

Ast_Union_Variant :: struct {
	type_expr: Type_Expr,
}

union_decl_parse :: proc(p: ^Parser) -> ^Ast_Union_Decl {
	decl := new(Ast_Union_Decl)
	name_token := expect(p, .Identifier)

	union_name := name_token.value.(string)
	decl.name = union_name

	expect(p, .LBrace)

	for keep_parsing_block(p) {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}
		type_expr := parse_type_expr(p)
		append(&decl.variants, Ast_Union_Variant{type_expr = type_expr})
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	return decl
}

union_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := &node.data.(Ast_Union_Decl)
	existing, ok := resolve_symbol(scope, data.name)
	if !ok {
		type := new(Type)
		type.kind = .Union

		sym := make_symbol(.Type)
		sym.name = data.name
		sym.type = type
		scope.symbols[data.name] = sym
		data.symbol = sym
		for _, idx in data.variants {
			append(&sym.type.union_variants, Union_Variant{index = idx})
		}
	} else {
		error_span(node.span, "Re-declaration of union '%s'", data.name)
		data.symbol = existing
	}
}

union_decl_resolve :: proc(node: ^Ast_Node) {
	data := &node.data.(Ast_Union_Decl)
	type_sym, ok := resolve_symbol(node.scope, data.name)
	if !ok {
		return
	}

	data.symbol.type = type_sym.type
	for &variant, idx in data.variants {
		type_sym.type.union_variants[idx].type = resolve_type_expr(
			&variant.type_expr,
			node.scope,
			node.span,
		)
	}
}

union_decl_check :: proc(c: ^Checker, s: ^Ast_Union_Decl, scope: ^Scope, span: Span) {
	// Note: need to check for repeated variants TODO
	for variant, idx in s.symbol.type.union_variants {
		if variant.type == nil || variant.type.kind == .Error {
			error_span(
				span,
				"Unresolved type for variant '%s' in '%s'",
				s.variants[idx].type_expr,
				s.name,
			)
		}
	}
}

union_emit_decl :: proc(gen: ^Generator, s: ^Ast_Union_Decl, scope: ^Scope, span: Span) {
}
