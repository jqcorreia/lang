package main

import "core:strings"

Ast_Struct_Decl :: struct {
	name:   string,
	fields: [dynamic]Ast_Struct_Field,
	symbol: ^Symbol,
}

Ast_Struct_Field :: struct {
	name:      string,
	type_expr: Type_Expr,
	symbol:    ^Symbol,
}

struct_bind :: proc(node: ^Ast_Node, data: ^Ast_Struct_Decl, cur_scope: ^Scope) {
	existing, ok := resolve_symbol(cur_scope, data.name)
	if !ok {
		type := new(Type)
		type.kind = .Struct
		type.fields = {}
		sym := make_symbol(.Type)
		sym.name = data.name
		sym.type = type
		cur_scope.symbols[data.name] = sym
		data.symbol = sym
		for &field, idx in data.fields {
			append(&sym.type.fields, Struct_Field{name = field.name, index = idx})
		}
	} else {
		error_span(node.span, "Re-declaration of struct '%s'", data.name)
		data.symbol = existing
	}
}

struct_decl_resolve :: proc(node: ^Ast_Node) {
	data := node.data.(Ast_Struct_Decl)
	type_sym, ok := resolve_symbol(node.scope, data.name)
	if !ok {
		return
	}

	data.symbol.type = type_sym.type
	for &field, idx in data.fields {
		type_sym.type.fields[idx].type = resolve_type_expr(&field.type_expr, node.scope, node.span)
	}
}

struct_literal_resolve :: proc(expr: ^Expr, scope: ^Scope, span: Span) -> ^Type {
	e := expr.data.(Expr_Struct_Literal)
	type := resolve_type_expr(&e.type_expr, scope, span)
	if type == &error_type {
		expr.type = &error_type
		return &error_type
	}

	expr.type = type
	for arg_name, arg in e.args {
		for field in type.fields {
			if field.name == arg_name {
				arg_type := resolve_expr_type(arg, scope, span)
				coerced_type := type_coercion(arg_type, field.type, scope)
				if coerced_type != nil {
					set_expr_type(arg, coerced_type, scope)
				} else {
					arg.type = arg_type
				}
			}
		}
	}
	return type
}

struct_member_resolve :: proc(
	expr: ^Expr,
	struct_type: ^Type,
	scope: ^Scope,
	span: Span,
) -> ^Type {
	e := expr.data.(Expr_Member)

	for &field in struct_type.fields {
		if e.member == field.name {
			expr.type = field.type
			return expr.type
		}
	}

	error_span(span, "Struct '%s' has no field '%s'", struct_type_name(struct_type), e.member)
	expr.type = &error_type
	return &error_type
}

struct_type_name :: proc(t: ^Type) -> string {
	for name, type in compiler.types {
		if type == t do return name
	}
	return "<anonymous>"
}

struct_decl_check :: proc(c: ^Checker, s: ^Ast_Struct_Decl, scope: ^Scope, span: Span) {
	for field in s.symbol.type.fields {
		if field.type == nil || field.type.kind == .Error {
			error_span(span, "Unresolved type for field '%s' in '%s'", field.name, s.name)
		}
	}
}

struct_emit_decl :: proc(gen: ^Generator, s: ^Ast_Struct_Decl, scope: ^Scope, span: Span) {
	llvm_type := StructCreateNamed(gen.ctx, strings.clone_to_cstring(s.name))
	sym := s.symbol
	gen.primitive_types[sym.type] = llvm_type
}

struct_emit_body :: proc(gen: ^Generator, s: ^Ast_Struct_Decl, scope: ^Scope, span: Span) {
	sym := s.symbol
	llvm_type := gen.primitive_types[sym.type]

	field_types: [dynamic]TypeRef

	for field in sym.type.fields {
		append(&field_types, get_llvm_type(gen, field.type))
	}

	StructSetBody(llvm_type, raw_data(field_types), u32(len(field_types)), 0)
	AddGlobal(gen.module, llvm_type, "dummy_struct_use")
}

struct_emit_into :: proc(
	gen: ^Generator,
	expr: ^Expr,
	dest: ValueRef,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	e := expr.data.(Expr_Struct_Literal)
	type := expr.type
	struct_llvm_type := get_llvm_type(gen, type)

	ptr := dest == nil ? build_entry_alloca(gen, struct_llvm_type, "") : dest

	for field in type.fields {
		field_ptr := BuildStructGEP2(gen.builder, struct_llvm_type, ptr, u32(field.index), "")
		arg := e.args[field.name]
		if arg == nil {
			// In case of non defined field, zero initialize the literal
			BuildStore(gen.builder, make_zero_value(gen, field.type), field_ptr)
		} else if field.type.kind == .Struct || field.type.kind == .Array {
			emit_into(gen, arg, field_ptr, scope, span)
		} else {
			BuildStore(gen.builder, emit_value(gen, arg, scope, span), field_ptr)
		}
	}

	return ptr
}

struct_emit_address :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	return struct_emit_into(gen, expr, nil, scope, span)
}

struct_emit_value :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope, span: Span) -> ValueRef {
	e := expr.data.(Expr_Struct_Literal)
	addr := struct_emit_address(gen, expr, scope, span)
	type := resolve_type_expr(&e.type_expr, scope, span)
	return BuildLoad2(gen.builder, get_llvm_type(gen, type), addr, "")
}

// Returns the integer type used for ABI-passing small structs on x86-64 System V.
// A struct whose fields are all integer/float primitives totalling <= 8 bytes is passed
// as a single i32 (<= 4 bytes) or i64 (<= 8 bytes) instead of being expanded field-by-field.
// Returns the byte size of any type, or 0 if it can't be computed
get_type_byte_size :: proc(type: ^Type) -> u32 {
	if type == nil {return 0}
	#partial switch type.kind {
	case .Int8, .Uint8, .Bool:
		return 1
	case .Int16, .Uint16:
		return 2
	case .Int32, .Uint32:
		return 4
	case .Int64, .Uint64:
		return 8
	case .Float32:
		return 4
	case .Float64:
		return 8
	case .Pointer, .CString:
		return 8
	case .Enum:
		return 8
	case .Struct:
		total: u32 = 0
		for field in type.fields {
			field_size := get_type_byte_size(field.type)
			if field_size == 0 {return 0}
			total += field_size
		}
		return total
	case .Array:
		if type.elem_type == nil {return 0}
		elem_size := get_type_byte_size(type.elem_type)
		if elem_size == 0 {return 0}
		return elem_size * u32(type.size)
	}
	return 0
}

// Small structs (<= 8 bytes) are coerced to integers for register passing (C ABI)
get_abi_int_type_for_struct :: proc(gen: ^Generator, type: ^Type) -> (TypeRef, bool) {
	if type == nil || type.kind != .Struct {return nil, false}
	total_bytes := get_type_byte_size(type)
	if total_bytes == 0 {return nil, false}
	if total_bytes <= 4 {
		return Int32TypeInContext(gen.ctx), true
	} else if total_bytes <= 8 {
		return Int64TypeInContext(gen.ctx), true
	}
	return nil, false
}

// Large structs (> 16 bytes) are passed by pointer with caller-side copy
is_large_struct :: proc(type: ^Type) -> bool {
	if type == nil || type.kind != .Struct {return false}
	return get_type_byte_size(type) > 16
}
