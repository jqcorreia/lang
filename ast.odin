package main

import "core:fmt"

Ast_Module :: []^Ast_Node

Ast_Node :: struct {
	data:  Ast_Data,
	span:  Span,
	scope: ^Scope,
}

Ast_Data :: union {
	Ast_Expr,
	Ast_Const_Decl,
	Ast_Var_Decl,
	Ast_Var_Assign,
	Ast_Function,
	Ast_Return,
	Ast_Block,
	Ast_If,
	Ast_For,
	Ast_Break,
	Ast_Continue,
	Ast_Struct_Decl,
	Ast_Enum_Decl,
	Ast_Import,
}

Type_Expr :: union {
	Type_Expr_Name,
	Type_Expr_Array,
	Type_Expr_Pointer,
	Type_Expr_Function,
}

Type_Expr_Name :: string

Type_Expr_Array :: struct {
	size: ^Expr,
	elem: ^Type_Expr,
}

Type_Expr_Pointer :: struct {
	pointee: ^Type_Expr,
}

Type_Expr_Function :: struct {
	params:      []^Type_Expr,
	return_type: ^Type_Expr,
}

Ast_Expr :: struct {
	expr: ^Expr,
}

Ast_Var_Assign :: struct {
	lhs:    ^Expr,
	expr:   ^Expr,
	symbol: ^Symbol,
	create: bool,
}

Ast_Var_Decl :: struct {
	name:      string, // var name
	expr:      ^Expr, // nil if default value, whatever that is
	symbol:    ^Symbol, // symbol to be bound
	type_expr: Type_Expr, // Type expression to be resolved
}


Param :: struct {
	name:            string,
	type_expr:       Type_Expr,
	symbol:          ^Symbol,
	variadic_marker: bool,
}

Ast_Block :: struct {
	statements:            []^Ast_Node,
	terminated:            bool,
	is_external_functions: bool,
}

Ast_Return :: struct {
	expr: ^Expr,
}

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

Ast_Break :: struct {}
Ast_Continue :: struct {}

Ast_Import :: struct {
	path:       string,
	identifier: string,
}


Expr :: struct {
	data: Expr_Data,
	type: ^Type,
}

Expr_Data :: union {
	Expr_Null,
	Expr_Int_Literal,
	Expr_Float_Literal,
	Expr_Bool_Literal,
	Expr_String_Literal,
	Expr_Struct_Literal,
	Expr_Array_Literal,
	Expr_Unary,
	Expr_Binary,
	Expr_Variable,
	Expr_Call,
	Expr_Member,
	Expr_Implicit_Variant,
	Expr_Index,
	Expr_Range,
	Expr_Cast,
}

Expr_Null :: struct {}

Expr_String_Literal :: struct {
	value: string,
}

Expr_Int_Literal :: struct {
	value: i64,
}

Expr_Float_Literal :: struct {
	value: f64,
}

Expr_Bool_Literal :: struct {
	value: bool,
}

Expr_Unary :: struct {
	op:   Token_Kind,
	expr: ^Expr,
}

Expr_Binary :: struct {
	op:    Token_Kind,
	left:  ^Expr,
	right: ^Expr,
}

Expr_Variable :: struct {
	value: string,
}


Expr_Struct_Literal :: struct {
	type_expr: Type_Expr,
	args:      map[string]^Expr,
}

Expr_Range :: struct {
	start:     ^Expr,
	end:       ^Expr,
	inclusive: bool,
}

Expr_Member :: struct {
	base:   ^Expr,
	member: string,
	kind:   Member_Kind,
	// type field from base would refer to the `member` field type
}

Member_Kind :: enum {
	Field,
	Method,
	Swizzle,
	Variant,
}

// Generic AST traverse function
traverse_ast :: proc(
	ast: ^Ast_Node,
	func: proc(node: ^Ast_Node, userdata: rawptr = nil),
	userdata: rawptr = nil,
) {
	#partial switch &node in ast.data {
	case Ast_Expr:
		func(ast, userdata)
	case Ast_Var_Assign:
		func(ast, userdata)
	case Ast_Var_Decl:
		func(ast, userdata)
	case Ast_Function:
		func(ast, userdata)
		if !node.external {
			for child in node.body.statements {
				traverse_ast(child, func, userdata)
			}
		}
	case Ast_Struct_Decl:
		func(ast, userdata)
	case Ast_Return:
		func(ast, userdata)
	case Ast_If:
		func(ast, userdata)
		for child in node.then_block.statements {
			traverse_ast(child, func, userdata)
		}
		if node.else_block != nil {
			for child in node.else_block.statements {
				traverse_ast(child, func, userdata)
			}
		}
	case Ast_For:
		func(ast, userdata)
		for child in node.body.statements {
			traverse_ast(child, func, userdata)
		}
	case Ast_Break:
		func(ast, userdata)
	case Ast_Block:
		for child in node.statements {
			traverse_ast(child, func, userdata)
		}
	case Ast_Import:
		func(ast, userdata)
	case Ast_Enum_Decl:
		func(ast, userdata)
	case Ast_Const_Decl:
		func(ast, userdata)
	case:
		unimplemented(fmt.tprint("Unimplement traverse statement", ast))
	}
}
traverse_block :: proc(
	nodes: []^Ast_Node,
	func: proc(node: ^Ast_Node, userdata: rawptr = nil),
	userdata: rawptr = nil,
) {
	for node in nodes {
		traverse_ast(node, func, userdata)
	}
}
