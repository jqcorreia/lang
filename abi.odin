package main

// SysV AMD64 ABI parameter classification.
//
// Single source of truth for "how does this parameter type get passed?". Both
// function_decl_emit (which builds the LLVM signature) and function_call_emit
// (which builds the call site) consume the result. function_body_emit also
// uses it to materialize the params back into struct allocas at function entry.
//
// Policy by struct size, per SysV:
//   non-aggregate         -> Direct       (scalar passes through unchanged)
//   struct  size <= 8     -> Coerce       (one scalar arg; INTEGER or SSE)
//   struct  9 <= size<=16 -> Split        (two scalar args; eightbyte classify each)
//   struct  size >  16    -> Byval        (ptr with byval(StructTy) attribute)
//
// Limitation: eightbyte classification walks fields with the current
// padding-free byte_size model. Once struct layout accounts for alignment/
// padding, the field-walk in abi_classify_range must use real offsets.

ABI_Lowering :: union {
	ABI_Direct,
	ABI_Coerce,
	ABI_Split,
	ABI_Byval,
}

ABI_Direct :: struct {
	llvm_type: TypeRef, // pass-through (scalars and non-struct aggregates today)
}

ABI_Coerce :: struct {
	scalar_type: TypeRef, // i32 / i64 / float / double — the LLVM param type
	struct_type: TypeRef, // original struct type, kept for body re-store
}

ABI_Split :: struct {
	eb0_type:    TypeRef, // first eightbyte's LLVM type
	eb1_type:    TypeRef, // second eightbyte's LLVM type
	struct_type: TypeRef,
}

ABI_Byval :: struct {
	struct_type: TypeRef, // attached to the byval attribute on decl & call site
}

Eightbyte_Class :: enum {
	No_Class,
	Integer,
	SSE,
	Memory,
}

// SysV merge rule: anything + Memory = Memory; Integer dominates SSE on conflict;
// NoClass is the identity element. (Real spec has more cases — X87, ComplexX87,
// unaligned — that we don't generate today.)
abi_merge_class :: proc(a, b: Eightbyte_Class) -> Eightbyte_Class {
	if a == b do return a
	if a == .No_Class do return b
	if b == .No_Class do return a
	if a == .Memory || b == .Memory do return .Memory
	if a == .Integer || b == .Integer do return .Integer
	return .SSE
}

// Walk fields in [lo_byte, hi_byte) and merge each field's class into cls.
// Recurses into nested structs/arrays. Pointers and integers are INTEGER class;
// f32/f64 are SSE; bool/u8/...etc are INTEGER.
abi_classify_range :: proc(t: ^Type, base_offset: u32, cls: ^Eightbyte_Class, lo, hi: u32) {
	if t == nil do return

	#partial switch t.kind {
	case .Struct:
		offset := base_offset
		for &field in t.fields {
			abi_classify_range(field.type, offset, cls, lo, hi)
			offset += get_type_byte_size(field.type)
		}
	case .Array:
		if t.elem_type == nil do return
		elem_size := get_type_byte_size(t.elem_type)
		for i in 0 ..< t.size {
			elem_off := base_offset + u32(i) * elem_size
			if elem_off >= hi do break
			abi_classify_range(t.elem_type, elem_off, cls, lo, hi)
		}
	case:
		end := base_offset + get_type_byte_size(t)
		if end <= lo || base_offset >= hi do return
		if t.numeric_float {
			cls^ = abi_merge_class(cls^, .SSE)
		} else {
			cls^ = abi_merge_class(cls^, .Integer)
		}
	}
}

abi_eightbyte_to_llvm :: proc(gen: ^Generator, cls: Eightbyte_Class, byte_size: u32) -> TypeRef {
	#partial switch cls {
	case .Integer:
		if byte_size <= 1 do return Int8TypeInContext(gen.ctx)
		if byte_size <= 2 do return Int16TypeInContext(gen.ctx)
		if byte_size <= 4 do return Int32TypeInContext(gen.ctx)
		return Int64TypeInContext(gen.ctx)
	case .SSE:
		if byte_size <= 4 do return FloatTypeInContext(gen.ctx)
		return DoubleTypeInContext(gen.ctx)
	}
	// No_Class / Memory shouldn't reach here for register-passed eightbytes.
	return Int64TypeInContext(gen.ctx)
}

// THE policy function. Given a parameter type, decide how it's lowered for
// SysV. Every ABI question about parameters routes through here.
abi_classify_param :: proc(gen: ^Generator, t: ^Type) -> ABI_Lowering {
	// Non-aggregates pass through; LLVM handles their register placement.
	if t.kind != .Struct {
		return ABI_Direct{llvm_type = get_llvm_type(gen, t)}
	}

	size := get_type_byte_size(t)
	struct_ty := get_llvm_type(gen, t)

	// > 16B  -> MEMORY class -> byval pointer.
	if size > 16 {
		return ABI_Byval{struct_type = struct_ty}
	}

	// First eightbyte (bytes 0..min(8,size)).
	eb0 := Eightbyte_Class.No_Class
	abi_classify_range(t, 0, &eb0, 0, 8)

	if size <= 8 {
		return ABI_Coerce {
			scalar_type = abi_eightbyte_to_llvm(gen, eb0, size),
			struct_type = struct_ty,
		}
	}

	// 9..16B -> second eightbyte (bytes 8..size).
	eb1 := Eightbyte_Class.No_Class
	abi_classify_range(t, 0, &eb1, 8, 16)
	return ABI_Split {
		eb0_type = abi_eightbyte_to_llvm(gen, eb0, 8),
		eb1_type = abi_eightbyte_to_llvm(gen, eb1, size - 8),
		struct_type = struct_ty,
	}
}
