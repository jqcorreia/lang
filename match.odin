package main

Ast_Match :: struct {
	expr:               ^Expr,
	clauses:            [dynamic]Ast_Match_Clause,
	variant_identifier: string,
	else_clause:        Ast_Match_Clause,
}

Ast_Match_Clause :: struct {
	expr:   ^Expr,
	block:  ^Ast_Block,
	binder: ^Symbol,
	tag:    u64,
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
		if current(p).kind == .FatRightArrow {
			advance(p)
			// else clause
			block := parse_block(p)

			// Check on the block field if the else clause was 
			// already parsed and err on duplication
			if st.else_clause.block != nil {
				continue // Fow now just ignore

			}
			st.else_clause = Ast_Match_Clause {
				block = block,
			}
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
		if data.variant_identifier != "" {
			variant_sym := make_symbol(.Variable)
			new_scope.symbols[data.variant_identifier] = variant_sym
			clause.binder = variant_sym
		}
		get_block_symbols(clause.block, new_scope)
	}
	if data.else_clause.block != nil {
		new_scope := make_scope(.Block, parent = scope)
		get_block_symbols(data.else_clause.block, new_scope)
	}
}

match_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Match)
	expr_type := resolve_expr_type(data.expr, node.scope, node.span)

	if expr_type == nil {
		data.expr.type = &error_type
		return
	}

	if expr_type.kind == .Union {
		for &clause in data.clauses {
			type_expr, _ := expr_to_type_expr(clause.expr)
			type := resolve_type_expr(&type_expr, node.scope, node.span)

			clause.expr.type = type
			clause.binder.type = type

			// The tag is the variant's index *within the union declaration*,
			// which must match what construction stores (see coerce_expr).
			found := false
			for variant, v_idx in expr_type.union_variants {
				if variant.type == type {
					clause.tag = u64(v_idx)
					found = true
					break
				}
			}
			if !found {
				error_span(clause.expr.span, "type is not a variant of the union")
			}

			resolve_block_types(clause.block)
		}
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

	if data.else_clause.block != nil {
		resolve_block_types(data.else_clause.block)
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
	is_union :: proc(e: ^Expr) -> bool {
		return e.type.kind == .Union
	}

	entry := GetBasicBlockParent(GetInsertBlock(gen.builder))
	match_val: ValueRef
	payload_ptr: ValueRef

	if is_union(s.expr) {
		union_ptr := emit_address(gen, s.expr, scope, span)
		union_ty := get_llvm_type(gen, s.expr.type)

		tag_ptr := BuildStructGEP2(gen.builder, union_ty, union_ptr, 0, "")
		match_val = BuildLoad2(gen.builder, Int64TypeInContext(gen.ctx), tag_ptr, "")
		payload_ptr = BuildStructGEP2(gen.builder, union_ty, union_ptr, 1, "")
	} else {
		match_val = emit_value(gen, s.expr, scope, span)
	}

	else_bb := AppendBasicBlock(entry, "else")
	merge_bb := AppendBasicBlock(entry, "merge")

	sw := BuildSwitch(gen.builder, match_val, else_bb, u32(len(s.clauses)))
	for clause in s.clauses {
		bb := AppendBasicBlock(entry, "")
		PositionBuilderAtEnd(gen.builder, bb)

		if is_union(s.expr) {
			gen.values[clause.binder] = payload_ptr
			AddCase(sw, ConstInt(Int64TypeInContext(gen.ctx), clause.tag, 0), bb)
		} else {
			AddCase(sw, emit_value(gen, clause.expr, scope, span), bb)
		}

		emit_block(gen, clause.block)
		BuildBr(gen.builder, merge_bb)
	}

	{
		//TODO: right now the else clause goes straight to merge, we should implement the catch-all here
		PositionBuilderAtEnd(gen.builder, else_bb)
		if s.else_clause.block != nil {
			emit_block(gen, s.else_clause.block)
		}
		BuildBr(gen.builder, merge_bb)
	}

	PositionBuilderAtEnd(gen.builder, merge_bb)
}
