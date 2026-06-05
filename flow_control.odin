package main

import "core:container/queue"

Ast_For :: struct {
	body:     ^Ast_Block,
	iterator: string, // empty if unconditional loop
	symbol:   ^Symbol, // nil if unconditional loop, bound in scope phase
	range:    ^Expr, // nil if unconditional loop
}

Ast_Break :: struct {}
Ast_Continue :: struct {}

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
