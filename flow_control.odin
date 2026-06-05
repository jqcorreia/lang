package main

import "core:container/queue"

flow_continue_parse :: proc(p: ^Parser) -> ^Ast_Continue {
	stmt := new(Ast_Continue)

	expect(p, .NewLine)
	return stmt
}

flow_continue_emit :: proc(gen: ^Generator, s: ^Ast_Continue, scope: ^Scope, span: Span) {
	loop := queue.front(&compiler.loops)
	BuildBr(gen.builder, loop.continue_block)
}
