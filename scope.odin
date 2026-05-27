package main

Symbol :: struct {
	name:        string,
	kind:        Symbol_Kind,
	type:        ^Type,
	decl:        ^Ast_Node,
	scope:       ^Scope,
	const_value: Const_Value,
}

Symbol_Kind :: enum {
	Variable,
	Constant,
	Function,
	Type,
	Param,
	Field,
	Type_Alias,
}

Symbol_Table :: map[string]^Symbol

Scope :: struct {
	kind:     ScopeKind,
	symbols:  Symbol_Table,
	function: ^Symbol,
	parent:   ^Scope,
}

ScopeKind :: enum {
	Global,
	Function,
	Block,
	Loop,
}

Const_Value :: union {
	i64,
	f64,
}

create_global_scope :: proc() -> ^Scope {
	scope := new(Scope)
	scope.kind = .Global
	create_primitive_types(scope)
	return scope
}

bind_scopes :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	node.scope = cur_scope
	#partial switch &data in node.data {
	case Ast_Block:
		for s in data.statements {
			bind_scopes(s, cur_scope)
		}
	case Ast_Var_Decl:
		existing, ok := resolve_symbol(cur_scope, data.name)
		if !ok {
			sym := make_symbol(.Variable)
			sym.name = data.name
			sym.decl = node
			cur_scope.symbols[data.name] = sym
			data.symbol = sym
		} else {
			error_span(node.span, "Re-declaration of variable '%s'", data.name)
			data.symbol = existing
		}
	case Ast_Const_Decl:
		const_bind(node, cur_scope)
	case Ast_Struct_Decl:
		struct_bind(node, cur_scope)
	case Ast_Enum_Decl:
		enum_bind(node, cur_scope)
	case Ast_Function:
		function_bind(node, cur_scope)
	case Ast_If:
		new_scope_then := make_scope(.Block, parent = cur_scope)
		get_block_symbols(data.then_block, new_scope_then)
		if data.else_block != nil {
			new_scope_else := make_scope(.Block, parent = cur_scope)
			get_block_symbols(data.else_block, new_scope_else)
		}
	case Ast_For:
		new_scope := make_scope(.Loop, parent = cur_scope)
		if data.iterator != "" {
			sym := make_symbol(.Variable)
			sym.name = data.iterator
			new_scope.symbols[data.iterator] = sym
			data.symbol = sym
		}
		get_block_symbols(data.body, new_scope)
	}
}

get_block_symbols :: proc(s: ^Ast_Block, scope: ^Scope) {
	for node in s.statements {
		bind_scopes(node, scope)
	}
}

make_scope :: proc(kind: ScopeKind, parent: ^Scope) -> ^Scope {
	scope := new(Scope)
	scope.kind = kind
	scope.parent = parent
	return scope
}

make_symbol :: proc(kind: Symbol_Kind, type: ^Type = nil) -> ^Symbol {
	sym := new(Symbol)
	sym.kind = kind
	sym.type = type
	return sym
}

resolve_symbol :: proc(current_scope: ^Scope, name: string) -> (^Symbol, bool) {
	scope := current_scope
	for {
		if sym, ok := scope.symbols[name]; ok {
			return sym, true
		}
		if scope.parent == nil {
			break
		}
		scope = scope.parent
	}
	return nil, false
}

get_type_symbol :: proc(current_scope: ^Scope, type: ^Type) -> (^Symbol, bool) {
	s := current_scope
	for s != nil {
		for _, sym in s.symbols {
			if sym.kind == .Type && sym.type == type do return sym, true
		}
		s = s.parent
	}
	return nil, false
}

get_type_name :: proc(current_scope: ^Scope, type: ^Type) -> (string, bool) {
	sym, ok := get_type_symbol(current_scope, type)
	name := ok ? sym.name : "<anonymous>"
	return name, false
}

get_scope_function :: proc(scope: ^Scope) -> ^Symbol {
	for cur := scope; cur.parent != nil; cur = cur.parent {
		if cur.function != nil {
			return cur.function
		}
	}
	return nil
}
