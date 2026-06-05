package main

import "core:container/queue"
import "core:fmt"

Ast_If :: struct {
	cond:       ^Expr,
	then_block: ^Ast_Block,
	else_block: ^Ast_Block, // nil if no else
}

Ast_For :: struct {
	body:     ^Ast_Block,
	iterator: string, // empty if unconditional loop
	symbol:   ^Symbol, // nil if unconditional loop, bound in scope phase
	range:    ^Expr, // nil if unconditional loop
}

Ast_Match :: struct {
	expr:    ^Expr,
	clauses: [dynamic]Ast_Match_Clause,
}

Ast_Break :: struct {}
Ast_Continue :: struct {}

Ast_Return :: struct {
	expr: ^Expr,
}

Ast_Match_Clause :: struct {
	expr:  ^Expr,
	block: ^Ast_Block,
}

flow_match_parse :: proc(p: ^Parser) -> ^Ast_Match {
	st := new(Ast_Match)

	st.expr = parse_expression(p, 0, false)
	expect(p, .LBrace)

	for keep_parsing_block(p) {
		// // Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}

		clause_expr := parse_expression(p, 0)
		expect(p, .FatRightArrow)

		fmt.println(clause_expr)
		block := parse_block(p)
		append(&st.clauses, Ast_Match_Clause{expr = clause_expr, block = block})
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}
	return st
}

flow_match_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := node.data.(Ast_Match)
	for &clause in data.clauses {
		new_scope_else := make_scope(.Block, parent = scope)
		get_block_symbols(clause.block, new_scope_else)
	}
}

flow_for_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := &node.data.(Ast_For)
	new_scope := make_scope(.Loop, parent = scope)
	if data.iterator != "" {
		sym := make_symbol(.Variable)
		sym.name = data.iterator
		new_scope.symbols[data.iterator] = sym
		data.symbol = sym
	}
	get_block_symbols(data.body, new_scope)
}

flow_if_bind :: proc(node: ^Ast_Node, scope: ^Scope) {
	data := node.data.(Ast_If)
	new_scope_then := make_scope(.Block, parent = scope)
	get_block_symbols(data.then_block, new_scope_then)
	if data.else_block != nil {
		new_scope_else := make_scope(.Block, parent = scope)
		get_block_symbols(data.else_block, new_scope_else)
	}
}

flow_match_resolve :: proc(node: ^Ast_Node) {
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
			return
		}
		clause.expr.type = coerced_type

		resolve_block_types(clause.block)
	}
}

flow_match_check :: proc(c: ^Checker, node: ^Ast_Node) {
	data := node.data.(Ast_Match)
	check_expr(c, data.expr, node.scope, node.span)
	for &clause in data.clauses {
		check_expr(c, clause.expr, node.scope, node.span)
		check_block(c, clause.block, node.span)
	}
}

flow_match_emit :: proc(gen: ^Generator, s: ^Ast_Match, scope: ^Scope, span: Span) {
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

flow_if_parse :: proc(p: ^Parser) -> ^Ast_If {
	cond := parse_expression(p, 0, false)
	then_block := parse_block(p)
	else_block: ^Ast_Block = nil

	if current(p).kind == .Else_Keyword {
		advance(p)
		else_block = parse_block(p)
	}

	stmt_if := new(Ast_If)
	stmt_if.cond = cond
	stmt_if.then_block = then_block
	stmt_if.else_block = else_block

	return stmt_if
}

flow_if_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_If)
	resolve_expr_type(data.cond, node.scope, node.span)
	resolve_block_types(data.then_block)
	if data.else_block != nil {
		resolve_block_types(data.else_block)
	}
}

flow_if_check :: proc(c: ^Checker, node: ^Ast_Node) {
	data := node.data.(Ast_If)
	check_expr(c, data.cond, node.scope, node.span)

	check_block(c, data.then_block, node.span)
	if data.else_block != nil {
		check_block(c, data.else_block, node.span)
	}
}

flow_if_emit :: proc(gen: ^Generator, s: ^Ast_If, scope: ^Scope, span: Span) {
	if_stmt := s
	cond_val := emit_value(gen, if_stmt.cond, scope, span)

	cond_bool: ValueRef
	cond_val_type := TypeOf(cond_val)

	// If the expression eval result is a i1 (one bit integer) then use it directly
	// Otherwise emit a comparison to zero and the cond_bool
	if GetTypeKind(cond_val_type) == .IntegerTypeKind && GetIntTypeWidth(cond_val_type) == 1 {
		cond_bool = cond_val
	} else {
		zero := ConstInt(Int32Type(), 0, 0)
		cond_bool = BuildICmp(gen.builder, .IntNE, cond_val, zero, "ifcond")
	}

	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	then_bb := AppendBasicBlock(function, "then")
	merge_bb := AppendBasicBlock(function, "ifcont")

	else_bb: BasicBlockRef
	if if_stmt.else_block != nil {
		else_bb = AppendBasicBlock(function, "else")
		BuildCondBr(gen.builder, cond_bool, then_bb, else_bb)
	} else {
		BuildCondBr(gen.builder, cond_bool, then_bb, merge_bb)
	}

	PositionBuilderAtEnd(gen.builder, then_bb)
	emit_block(gen, if_stmt.then_block)

	bb := GetInsertBlock(gen.builder)
	if GetBasicBlockTerminator(bb) == nil {
		BuildBr(gen.builder, merge_bb)
	}

	if if_stmt.else_block != nil {
		PositionBuilderAtEnd(gen.builder, else_bb)
		emit_block(gen, if_stmt.else_block)

		bb = GetInsertBlock(gen.builder)
		if GetBasicBlockTerminator(bb) == nil {
			BuildBr(gen.builder, merge_bb)
		}
	}
	PositionBuilderAtEnd(gen.builder, merge_bb)
}

flow_for_parse :: proc(p: ^Parser) -> ^Ast_For {
	stmt := new(Ast_For)

	if current(p).kind == .Identifier && peek(p).kind == .In_Keyword {
		stmt.iterator = advance(p).value.(string) // consume iterator name
		advance(p) // consume 'in'
		stmt.range = parse_expression(p, 0, false)
	}

	stmt.body = parse_block(p)
	return stmt
}

emit_for_loop_unconditional :: proc(gen: ^Generator, s: ^Ast_For, scope: ^Scope, span: Span) {
	function := GetBasicBlockParent(GetInsertBlock(gen.builder))

	loop_bb := AppendBasicBlock(function, "loop")
	after_bb := AppendBasicBlock(function, "after")

	BuildBr(gen.builder, loop_bb)
	queue.push_front(&compiler.loops, Loop{break_block = after_bb, continue_block = loop_bb})
	PositionBuilderAtEnd(gen.builder, loop_bb)
	emit_block(gen, s.body)

	if GetBasicBlockTerminator(GetInsertBlock(gen.builder)) == nil {
		BuildBr(gen.builder, loop_bb)
	}

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(gen.builder, after_bb)
}

flow_for_emit :: proc(gen: ^Generator, s: ^Ast_For, scope: ^Scope, span: Span) {
	if s.range == nil {
		emit_for_loop_unconditional(gen, s, scope, span)
		return
	}

	function := GetBasicBlockParent(GetInsertBlock(gen.builder))
	range := s.range.data.(Expr_Range)
	iter_type := get_llvm_type(gen, s.symbol.type)

	// Emit start and end once in the entry block so they are available across all BBs
	// Determine loop direction at runtime: is start <= end?
	start_val := emit_value(gen, range.start, scope, span)
	end_val := emit_value(gen, range.end, scope, span)
	is_forward := BuildICmp(gen.builder, .IntSLE, start_val, end_val, "is_fwd")

	// Store the initial value of the range
	iter_ptr := build_entry_alloca(gen, iter_type, "iter")
	BuildStore(gen.builder, start_val, iter_ptr)
	gen.values[s.symbol] = iter_ptr

	// Create the basic blocks
	cond_bb := AppendBasicBlock(function, "for_cond")
	loop_bb := AppendBasicBlock(function, "for_body")
	inc_bb := AppendBasicBlock(function, "for_inc")
	after_bb := AppendBasicBlock(function, "for_after")

	// Push the loop with break and continue blocks
	queue.push_front(&compiler.loops, Loop{break_block = after_bb, continue_block = inc_bb})

	BuildBr(gen.builder, cond_bb)

	// Conditional part of the loop
	// Check for current iterator value and check for end case (either inclusive or exclusive)
	// Set the conditional branching at the end to either the loop body or exit the loop
	PositionBuilderAtEnd(gen.builder, cond_bb)
	iter_val := BuildLoad2(gen.builder, iter_type, iter_ptr, "iter")
	cmp: ValueRef
	if range.inclusive {
		fwd_cmp := BuildICmp(gen.builder, .IntSLE, iter_val, end_val, "fwd_cond")
		bwd_cmp := BuildICmp(gen.builder, .IntSGE, iter_val, end_val, "bwd_cond")
		cmp = BuildSelect(gen.builder, is_forward, fwd_cmp, bwd_cmp, "cond")
	} else {
		fwd_cmp := BuildICmp(gen.builder, .IntSLT, iter_val, end_val, "fwd_cond")
		bwd_cmp := BuildICmp(gen.builder, .IntSGT, iter_val, end_val, "bwd_cond")
		cmp = BuildSelect(gen.builder, is_forward, fwd_cmp, bwd_cmp, "cond")
	}

	BuildCondBr(gen.builder, cmp, loop_bb, after_bb)

	// Position builder and emit the body of the loop
	PositionBuilderAtEnd(gen.builder, loop_bb)
	emit_block(gen, s.body)

	// Check for termination
	// If not terminated yet, advance iterator and branch to condition block again
	if GetBasicBlockTerminator(GetInsertBlock(gen.builder)) == nil {
		BuildBr(gen.builder, inc_bb)
	}

	PositionBuilderAtEnd(gen.builder, inc_bb)
	cur := BuildLoad2(gen.builder, iter_type, iter_ptr, "iter")
	inc := BuildAdd(gen.builder, cur, ConstInt(iter_type, 1, 0), "inc")
	dec := BuildSub(gen.builder, cur, ConstInt(iter_type, 1, 0), "dec")
	next := BuildSelect(gen.builder, is_forward, inc, dec, "next")
	BuildStore(gen.builder, next, iter_ptr)
	BuildBr(gen.builder, cond_bb)

	queue.pop_front(&compiler.loops)
	PositionBuilderAtEnd(gen.builder, after_bb)
}

flow_for_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_For)
	if data.range != nil {
		resolve_expr_type(data.range, node.scope, node.span)
		range := data.range.data.(Expr_Range)
		data.symbol.type = range.start.type
	}
	resolve_block_types(data.body)
}

flow_for_check :: proc(c: ^Checker, node: ^Ast_Node, span: Span) {
	data := node.data.(Ast_For)
	if data.range != nil {
		check_expr(c, data.range, node.scope, node.span)
	}
	check_block(c, data.body, span)
}

flow_break_parse :: proc(p: ^Parser) -> ^Ast_Break {
	stmt := new(Ast_Break)

	expect(p, .NewLine)
	return stmt
}

flow_break_emit :: proc(gen: ^Generator, s: ^Ast_Break, scope: ^Scope, span: Span) {
	loop := queue.front(&compiler.loops)

	BuildBr(gen.builder, loop.break_block)

	// Move gen.builder away from terminated block
	fn := GetBasicBlockParent(GetInsertBlock(gen.builder))
	dead := AppendBasicBlock(fn, "after_break")
	PositionBuilderAtEnd(gen.builder, dead)
}

flow_break_check :: proc(c: ^Checker, s: ^Ast_Break, scope: ^Scope, span: Span) {
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

flow_continue_parse :: proc(p: ^Parser) -> ^Ast_Continue {
	stmt := new(Ast_Continue)

	expect(p, .NewLine)
	return stmt
}

flow_continue_emit :: proc(gen: ^Generator, s: ^Ast_Continue, scope: ^Scope, span: Span) {
	loop := queue.front(&compiler.loops)
	BuildBr(gen.builder, loop.continue_block)
}

flow_continue_check :: proc(c: ^Checker, s: ^Ast_Continue, scope: ^Scope, span: Span) {
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

flow_return_parse :: proc(p: ^Parser) -> ^Ast_Return {
	advance(p)
	expr: ^Expr
	if current(p).kind != .NewLine {
		expr = parse_expression(p, 0)
	}
	expect(p, .NewLine)

	stmt := new(Ast_Return)
	stmt.expr = expr

	return stmt
}

flow_return_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Return)
	if data.expr != nil {
		expr_type := resolve_expr_type(data.expr, node.scope, node.span)
		sym := get_scope_function(node.scope)
		if sym != nil && sym.type != nil && sym.type.kind != .Error {
			coerced_type := coerce(expr_type, sym.type.return_type, node.scope)
			if coerced_type != nil {
				set_expr_type(data.expr, coerced_type, node.scope)
			}
			// On coercion failure, leave data.expr.type as the natural type
			// so the checker can report expected vs got
		}
	}
}

flow_return_check :: proc(c: ^Checker, s: ^Ast_Return, scope: ^Scope, span: Span) {
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
	if coerce(s.expr.type, fn_type.return_type, scope) == nil {
		error_span(
			span,
			"Return type mismatch in '%s': expected '%s', got '%s'",
			c.current_function.name,
			fn_type.return_type.kind,
			s.expr.type.kind,
		)
	}
}

flow_return_emit :: proc(gen: ^Generator, s: ^Ast_Return, scope: ^Scope, span: Span) {
	data := s
	if data.expr != nil {
		BuildRet(gen.builder, emit_value(gen, data.expr, scope, span))
	} else {
		BuildRetVoid(gen.builder)
	}
}
