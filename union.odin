package main

import "core:fmt"

Ast_Union_Decl :: struct {
	name:     string,
	variants: [dynamic]Ast_Union_Variant,
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

	fmt.println(decl)
	return decl
}

union_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
}
