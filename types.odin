#+feature dynamic-literals

package main

Type :: struct {
	kind:            Type_Kind,
	compiled:        Compiled_Type,
	signed:          bool, // not sure if this is the best place or I should have a kind union a be done with it
	numeric_integer: bool,
	numeric_float:   bool,
	fields:          [dynamic]Struct_Field,
	enum_variants:   [dynamic]Enum_Variant,
	size:            u64,
	elem_type:       ^Type,
	pointee_type:    ^Type, // Maybe not needed, could use elem_type, for now use a different field for clarity
}

Struct_Field :: struct {
	name:  string,
	type:  ^Type,
	index: int,
}

Enum_Variant :: struct {
	name:  string,
	value: i64,
}

Compiled_Type :: union {
	TypeRef,
}

Type_Kind :: enum {
	Nil,
	Undefined,
	Error,
	Void,
	Bool,
	Untyped_Int,
	Untyped_Float,
	Untyped_Enum_Variant,
	Uint8,
	Uint16,
	Uint64,
	Uint32,
	Int8,
	Int16,
	Int32,
	Int64,
	Float16,
	Float32,
	Float64,
	CString,
	Struct,
	Enum,
	Array,
	Pointer,
}

create_type :: proc(
	kind: Type_Kind,
	type_name: string,
	scope: ^Scope,
	signed := false,
	numeric_integer := false,
	numeric_float := false,
) {
	t := new(Type)
	t.kind = kind
	t.numeric_integer = numeric_integer
	t.numeric_float = numeric_float
	t.signed = signed
	scope.symbols[type_name] = make_symbol(.Type, t)
}

create_primitive_types :: proc(scope: ^Scope) {
	// NOTE: I don't know if void to be equivalent to empty type_expr is a good idea
	create_type(.Void, "", scope)
	create_type(.Bool, "bool", scope)

	create_type(.Untyped_Int, "untyped_int", scope, numeric_integer = true)
	create_type(.Untyped_Float, "untyped_float", scope, numeric_float = true)
	create_type(.Untyped_Enum_Variant, "untyped_enum_variant", scope)
	create_type(.Uint8, "u8", scope, numeric_integer = true)
	create_type(.Uint16, "u16", scope, numeric_integer = true)
	create_type(.Uint32, "u32", scope, numeric_integer = true)
	create_type(.Uint64, "u64", scope, numeric_integer = true)
	create_type(.Int8, "i8", scope, signed = true, numeric_integer = true)
	create_type(.Int16, "i16", scope, signed = true, numeric_integer = true)
	create_type(.Int32, "i32", scope, signed = true, numeric_integer = true)
	create_type(.Int64, "i64", scope, signed = true, numeric_integer = true)
	create_type(.Float16, "f16", scope, signed = true, numeric_float = true)
	create_type(.Float32, "f32", scope, signed = true, numeric_float = true)
	create_type(.Float64, "f64", scope, signed = true, numeric_float = true)

	create_type(.CString, "cstr", scope)
}

// coerce: directional. Can a `from` value be used where a `to` is expected?
// Asymmetric — e.g. Untyped_Int → f64 is fine, f64 → Untyped_Int is not.
// For symmetric "what type do these meet at" queries, use `unify` instead.
coerce :: proc(from: ^Type, to: ^Type, scope: ^Scope) -> ^Type {
	if from.kind == .Array && to.kind == .Array {
		if from.size == to.size && coerce(from.elem_type, to.elem_type, scope) != nil {
			return to
		}
	}

	if from.kind == .Untyped_Int && to.numeric_integer {
		return to
	}

	// Allow untyped int to be converted to a float
	if from.kind == .Untyped_Int && to.numeric_float {
		return to
	}

	if from.kind == .Untyped_Float && to.numeric_float {
		return to
	}

	if from.kind == .Nil && to.kind == .Pointer {
		return to
	}

	if to.kind == .Nil && from.kind == .Pointer {
		return from
	}

	// Any pointer is compatible with cstr (matches C char* semantics)
	if from.kind == .Pointer && to.kind == .CString {
		return to
	}

	if from.kind == .CString && to.kind == .Pointer {
		return to
	}

	// Check for exact enum type since 2 different enums and not coersable
	if from.kind == .Enum && to.kind == .Enum {
		if from == to {
			return from
		}
		return nil
	}

	if from.kind == .Enum && to.numeric_integer {
		return to
	}

	if from.kind == .Untyped_Enum_Variant && to.kind == .Enum {
		return to
	}

	if from.kind == to.kind {
		return from
	}

	return nil
}

// unify: symmetric. Find the common type two operands meet at - for binary
// operators, range endpoints, etc. where neither side is the "destination".
unify :: proc(a: ^Type, b: ^Type, scope: ^Scope) -> ^Type {
	// // Two untyped literals: collapse to the default concrete type
	// if a.kind == .Untyped_Int && b.kind == .Untyped_Int {
	// 	sym, _ := resolve_symbol(scope, "i64")
	// 	return sym.type
	// }
	// if a.kind == .Untyped_Float && b.kind == .Untyped_Float {
	// 	sym, _ := resolve_symbol(scope, "f64")
	// 	return sym.type
	// }
	if r := coerce(a, b, scope); r != nil {
		return r
	}
	return coerce(b, a, scope)
}

// Set the type on an expression and propagate it inward to untyped sub-expressions.
// This happens because some expressions can be typed but the components be still untyped
set_expr_type :: proc(expr: ^Expr, type: ^Type, scope: ^Scope) {
	expr.type = type
	#partial switch &e in expr.data {
	case Expr_Unary:
		coerced := coerce(e.expr.type, type, scope)
		if coerced != nil {
			set_expr_type(e.expr, coerced, scope)
		}
	case Expr_Binary:
		if l := coerce(e.left.type, type, scope); l != nil {
			set_expr_type(e.left, l, scope)
		}
		if r := coerce(e.left.type, type, scope); r != nil {
			set_expr_type(e.right, r, scope)
		}
	case Expr_Array_Literal:
		if type.elem_type == nil {return}
		for elem in e.elements {
			if elem.type.kind == .Array {
				set_expr_type(elem, type.elem_type, scope)
			} else {
				coerced := coerce(elem.type, type.elem_type, scope)
				if coerced != nil {elem.type = coerced}
			}
		}
	}
}

resolve_type_expr :: proc(type_expr: ^Type_Expr, scope: ^Scope, span: Span) -> ^Type {
	switch te in type_expr {
	case Type_Expr_Name:
		sym, ok := resolve_symbol(scope, te)
		if !ok {
			error_span(span, "Undefined type '%s'", te)
			return &error_type
		}
		return sym.type

	case Type_Expr_Array:
		elem_type := resolve_type_expr(te.elem, scope, span)
		if elem_type == &error_type {
			return &error_type
		}
		type := new(Type)
		type.kind = .Array
		type.size = te.size
		type.elem_type = elem_type

		return type

	case Type_Expr_Pointer:
		pointee_type := resolve_type_expr(te.pointee, scope, span)
		if pointee_type == &error_type {
			return &error_type
		}
		type := new(Type)
		type.kind = .Pointer
		type.pointee_type = pointee_type

		return type
	}
	return nil
}

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
