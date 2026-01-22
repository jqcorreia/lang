package main

import "core:fmt"
import "core:os"

gen :: proc(e: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	switch e.kind {
	case .Int_Lit:
		return ConstInt(int32, u64(e.data.(Expr_Int_Lit).value), false)
	case .Binary:
		fmt.println(e)
		#partial switch e.data.(Expr_Binary).op {
		case .Plus:
			return BuildAdd(
				builder,
				gen(e.data.(Expr_Binary).left, ctx, builder),
				gen(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Minus:
			return BuildSub(
				builder,
				gen(e.data.(Expr_Binary).left, ctx, builder),
				gen(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Star:
			return BuildMul(
				builder,
				gen(e.data.(Expr_Binary).left, ctx, builder),
				gen(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		case .Slash:
			return BuildUDiv(
				builder,
				gen(e.data.(Expr_Binary).left, ctx, builder),
				gen(e.data.(Expr_Binary).right, ctx, builder),
				"foo",
			)
		}
	}
	return ConstInt(int32, 42, true)
}

generate :: proc(e: ^Expr, ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
	int32 := Int32TypeInContext(ctx)
	fn_type := FunctionType(int32, nil, 0, 0)

	main_f := AddFunction(module, "main", fn_type)

	entry := AppendBasicBlockInContext(ctx, main_f, "entry")
	PositionBuilderAtEnd(builder, entry)

	ret := gen(e, ctx, builder)

	BuildRet(builder, ret)
}

main :: proc() {
	expr := os.read_entire_file("test.z") or_else panic("No file found")
	tokens := lex(string(expr))

	fmt.println(tokens)
	parser := Parser {
		tokens = tokens,
	}
	// fmt.println(Binary{left = &Number{value = 100}, right = &Number{value = 200}})
	pexpr := parse_expression(&parser)
	fmt.println(pexpr)
	// print_expr(&pexpr)

	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	generate(pexpr, ctx, module, builder)

	InitializeX86Target()
	InitializeX86TargetInfo()
	InitializeX86TargetMC()
	InitializeX86AsmPrinter()

	triple := GetDefaultTargetTriple()

	target: TargetRef

	error: cstring
	if GetTargetFromTriple(triple, &target, &error) > 0 {
		fmt.println(triple, string(error))
		return
	}
	SetTarget(module, triple)

	fmt.println(target, triple)
	tm := CreateTargetMachine(
		target,
		triple,
		"generic",
		"",
		.CodeGenLevelDefault,
		.RelocDefault,
		.CodeModelDefault,
	)

	SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error)
}
