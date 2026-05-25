package main

import "core:fmt"
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

Expr_Struct_Literal :: struct {
	type_expr:  Type_Expr,
	args:       map[string]^Expr,
	args_pos:   [dynamic]^Expr,
	positional: bool,
}

struct_decl_parse :: proc(p: ^Parser) -> ^Ast_Struct_Decl {
	decl := new(Ast_Struct_Decl)
	name_token := expect(p, .Identifier)

	struct_name := name_token.value.(string)
	decl.name = struct_name

	expect(p, .LBrace)

	for current(p).kind != .RBrace {
		// Ignore empty lines
		if current(p).kind == .NewLine {
			advance(p)
			continue
		}
		field_name := expect(p, .Identifier).value.(string)
		expect(p, .Colon)
		type_expr := parse_type_expr(p)
		append(&decl.fields, Ast_Struct_Field{name = field_name, type_expr = type_expr})
	}
	advance(p)

	if current(p).kind == .NewLine {
		advance(p)
	}

	return decl
}

struct_literal_parse :: proc(p: ^Parser, struct_name: string) -> ^Expr {
	result := new(Expr)

	lit := Expr_Struct_Literal{}
	lit.type_expr = struct_name

	struct_literal_fields_parse(p, &lit)
	result.data = lit

	return result
}

struct_literal_fields_parse :: proc(p: ^Parser, struct_expr: ^Expr_Struct_Literal) {
	done := false
	expect(p, .LBrace)

	for current(p).kind == .NewLine {
		fmt.println("skipping")
		advance(p)
	}

	is_positional := peek(p).kind != .Equal

	if !is_positional {
		for !done {
			#partial switch current(p).kind {
			case .Identifier:
				field_name := current(p).lexeme
				advance(p)
				expect(p, .Equal)
				struct_expr.args[field_name] = parse_expression(p, 0)
			case .Comma:
				if peek(p).kind == .RBrace {
					unexpected_token(peek(p))
				}
				advance(p)
			case .RBrace:
				advance(p)
				done = true
			case .NewLine:
				advance(p)
			case:
				unexpected_token(current(p))
			}
		}
	} else {
		for !done {
			fmt.println(current(p).kind)
			#partial switch current(p).kind {
			case .Comma:
				if peek(p).kind == .RBrace {
					unexpected_token(peek(p))
				}
				advance(p)
			case .RBrace:
				advance(p)
				done = true
			case .NewLine:
				advance(p)
			case:
				append(&struct_expr.args_pos, parse_expression(p, 0))
			// unexpected_token(current(p))
			}
		}
	}
	struct_expr.positional = is_positional
}

struct_bind :: proc(node: ^Ast_Node, cur_scope: ^Scope) {
	data := &node.data.(Ast_Struct_Decl)
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
	data := &node.data.(Ast_Struct_Decl)
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
	if !e.positional {
		for arg_name, arg in e.args {
			for field in type.fields {
				if field.name == arg_name {
					arg_type := resolve_expr_type(arg, scope, span)
					coerced_type := coerce(arg_type, field.type, scope)
					if coerced_type != nil {
						set_expr_type(arg, coerced_type, scope)
					} else {
						error_span(
							arg.span,
							"Invalid field type, expected %s, got %s",
							field.type.kind,
							arg_type.kind,
						)
						arg.type = &error_type
					}
				}
			}
		}
	} else {
		for arg, idx in e.args_pos {
			field := type.fields[idx]
			arg_type := resolve_expr_type(arg, scope, span)
			coerced_type := coerce(arg_type, field.type, scope)
			if coerced_type != nil {
				set_expr_type(arg, coerced_type, scope)
			} else {
				error_span(
					arg.span,
					"Invalid field type, expected %s, got %s",
					field.type.kind,
					arg_type.kind,
				)
				arg.type = arg_type
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

	name, _ := get_type_name(scope, struct_type)
	error_span(span, "Struct '%s' has no field '%s'", name, e.member)
	expr.type = &error_type

	return &error_type
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
		fmt.println(e.positional, span_to_location(span))

		// We need to guard against a struct literal with no args
		positional := len(e.args_pos) > 0 && e.positional

		arg := positional ? e.args_pos[field.index] : e.args[field.name]
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
	addr := struct_emit_address(gen, expr, scope, span)
	type := expr.type
	return BuildLoad2(gen.builder, get_llvm_type(gen, type), addr, "")
}

struct_emit_const :: proc(gen: ^Generator, expr: ^Expr, scope: ^Scope) -> ValueRef {
	llvm_type := get_llvm_type(gen, expr.type)
	e := expr.data.(Expr_Struct_Literal)
	field_vals: [dynamic]ValueRef
	for field in expr.type.fields {
		if arg, ok := e.args[field.name]; ok {
			append(&field_vals, make_const_value(gen, arg, scope))
		} else {
			append(&field_vals, ConstNull(get_llvm_type(gen, field.type)))
		}
	}
	return ConstNamedStruct(llvm_type, raw_data(field_vals), u32(len(field_vals)))
}

struct_member_emit_address :: proc(
	gen: ^Generator,
	expr: ^Expr_Member,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	base_type: ^Type
	base_ptr: ValueRef

	// Calculate base base_ptr
	if expr.base.type.kind == .Pointer {
		base_type = expr.base.type.pointee_type
		base_ptr = emit_value(gen, expr.base, scope, span)
	} else {
		base_type = expr.base.type
		base_ptr = emit_address(gen, expr.base, scope, span)
	}

	llvm_type := get_llvm_type(gen, base_type)

	// @Note: this is always traversing the field list searching for the correct index
	// Maybe have this memoized in some way
	field_index := 0
	for f in base_type.fields {
		if f.name == expr.member {
			field_index = f.index
			break
		}
	}
	return BuildStructGEP2(gen.builder, llvm_type, base_ptr, u32(field_index), "")
}

struct_member_emit_value :: proc(
	gen: ^Generator,
	expr: ^Expr,
	scope: ^Scope,
	span: Span,
) -> ValueRef {
	ptr := emit_address(gen, expr, scope, span)
	return BuildLoad2(gen.builder, get_llvm_type(gen, expr.type), ptr, "")
}

struct_field_type_by_name :: proc(struct_type: ^Type, name: string) -> ^Type {
	for field in struct_type.fields {
		if field.name != name do continue
		else {
			return field.type
		}
	}
	return nil
}
