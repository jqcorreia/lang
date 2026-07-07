package main

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
	if p.error_occured {
		return decl
	}

	union_name := name_token.value.(string)
	decl.name = union_name

	expect(p, .LBrace)
	if p.error_occured {
		return decl
	}

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
		type.name = data.name

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

union_expr_emit_into :: proc(
	gen: ^Generator,
	expr: Expr_To_Union,
	dst: ValueRef,
	union_type: ^Type,
	scope: ^Scope,
	span: Span,
) {
	inner_value := emit_value(gen, expr.original, scope, span)
	union_type := get_llvm_type(gen, union_type)
	u64_t := Int64TypeInContext(gen.ctx)

	tag_ptr := BuildStructGEP2(gen.builder, union_type, dst, 0, "")
	BuildStore(gen.builder, ConstInt(u64_t, expr.tag, 0), tag_ptr)

	payload_ptr := BuildStructGEP2(gen.builder, union_type, dst, 1, "")
	BuildStore(gen.builder, inner_value, payload_ptr)
}
