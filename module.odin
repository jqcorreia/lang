package main

Ast_Module :: struct {
	statements: []^Ast_Node,
}

module_bind :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	data := node.data.(Ast_Module)
	new_scope := new(Scope)
	new_scope.parent = cur_scope
	new_scope.kind = .Module

	for s in data.statements {
		bind_scopes(s, new_scope)
	}
}
