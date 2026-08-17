package main

Ast_Module :: struct {
	statements: []^Ast_Node,
}

Module :: struct {
	id:           string,
	path:         string,
	statements:   []^Ast_Node,
	compiled_obj: string,
}

module_bind :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	data := node.data.(Ast_Module)
	// new_scope := new(Scope)
	// new_scope.parent = cur_scope
	// new_scope.kind = .Module

	for s in data.statements {
		bind_scopes(s, cur_scope)
	}
}

module_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Module)

	for st in data.statements {
		resolve_types(st)
	}
}

module_check :: proc(c: ^Checker, node: ^Ast_Module, scope: ^Scope, span: Span) {
}
