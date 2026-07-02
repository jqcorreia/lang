package main

Ast_Match :: struct {
	expr:               ^Expr,
	clauses:            [dynamic]Ast_Match_Clause,
	variant_identifier: string,
}

Ast_Match_Clause :: struct {
	expr:  ^Expr,
	block: ^Ast_Block,
}

match_parse :: proc(p: ^Parser) -> ^Ast_Match {
	st := new(Ast_Match)

	// Parse both match and match-in statements
	expr1 := parse_expression(p, 0, false)
	if current(p).kind == .In_Keyword {
		advance(p)
		expr2 := parse_expression(p, 0, false)
		st.expr = expr2
		st.variant_identifier = expr1.data.(Expr_Identifier).value
	} else {
		st.expr = expr1
	}

	expect(p, .LBrace)

	for keep_parsing_block(p) {
		// // Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		clause_expr := parse_expression(p, 0)
		expect(p, .FatRightArrow)

		block := parse_block(p)
		append(&st.clauses, Ast_Match_Clause{expr = clause_expr, block = block})
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}
	return st
}

match_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := node.data.(Ast_Match)
	for &clause in data.clauses {
		new_scope := make_scope(.Block, parent = scope)
		get_block_symbols(clause.block, new_scope)
	}
}

match_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Match)
	expr_type := resolve_expr_type(data.expr, node.scope, node.span)

	if expr_type == nil {
		data.expr.type = &error_type
		return
	}
	for &clause in data.clauses {
		clause_type := resolve_expr_type(clause.expr, node.scope, node.span)
		coerced_type := coerce(clause_type, expr_type, node.scope)

		if coerced_type == nil {
			error_span(clause.expr.span, "Invalid value type in clause")
			clause.expr.type = &error_type
		} else {
			clause.expr.type = coerced_type
		}

		// Resolve the block even on error so the checker sees fully-typed
		// statements instead of crashing on nil expr types.
		resolve_block_types(clause.block)
	}
}

match_check :: proc(c: ^Checker, node: ^Ast_Node) {
	data := node.data.(Ast_Match)
	check_expr(c, data.expr, node.scope, node.span)
	for &clause in data.clauses {
		check_expr(c, clause.expr, node.scope, node.span)
		check_block(c, clause.block, node.span)
	}
}

match_emit :: proc(gen: ^Generator, s: ^Ast_Match, scope: ^Scope, span: Span) {
	entry := GetBasicBlockParent(GetInsertBlock(gen.builder))

	match_val := emit_value(gen, s.expr, scope, span)

	else_bb := AppendBasicBlock(entry, "else")
	merge_bb := AppendBasicBlock(entry, "merge")

	sw := BuildSwitch(gen.builder, match_val, else_bb, u32(len(s.clauses)))
	for clause in s.clauses {
		bb := AppendBasicBlock(entry, "")
		PositionBuilderAtEnd(gen.builder, bb)
		emit_block(gen, clause.block)
		AddCase(sw, emit_value(gen, clause.expr, scope, span), bb)
		BuildBr(gen.builder, merge_bb)
	}

	{
		PositionBuilderAtEnd(gen.builder, else_bb)
		BuildBr(gen.builder, merge_bb)
	}

	PositionBuilderAtEnd(gen.builder, merge_bb)
}
