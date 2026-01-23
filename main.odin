package main

import "core:fmt"
import "core:os"

gen :: proc(e: ^Expr, ctx: ContextRef, builder: BuilderRef) -> ValueRef {
	int32 := Int32TypeInContext(ctx)
	switch e.kind {
	case .Int_Lit:
		return ConstInt(int32, u64(e.data.(Expr_Int_Lit).value), false)
	case .Binary:
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
	i8 := Int8TypeInContext(ctx)
	i32 := Int32TypeInContext(ctx)
	i8p := PointerType(i8, 0)

	printf_ty = FunctionType(
		i32, // return type
		&i8p, // first arg: char *
		1,
		true, // variadic
	)

	printf_fn = AddFunction(module, "printf", printf_ty)
	fmt_ptr = BuildGlobalStringPtr(builder, "%d\n", "fmt")

	args := []ValueRef {
		fmt_ptr,
		ret, // i32
	}

	BuildCall2(
		builder,
		printf_ty, // <-- REQUIRED
		printf_fn,
		&args[0],
		u32(len(args)),
		"",
	)
	BuildRet(builder, ConstInt(int32, 0, true))
}

printf_fn: ValueRef
fmt_ptr: ValueRef
printf_ty: TypeRef

setup_runtime :: proc(ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
}

tokens_print :: proc(tokens: []Token) {
	for token in tokens {
		fmt.println(token)
	}
}
expr_print :: proc(expr: ^Expr, lvl: u32 = 0) {
	if expr == nil {
		return
	}
	for _ in 0 ..< lvl {
		fmt.print(" ")
	}
	switch expr.kind {
	case .Int_Lit:
		fmt.println("Int ", expr.data.(Expr_Int_Lit).value)
	case .Binary:
		data, _ := expr.data.(Expr_Binary)
		fmt.println("Binary ", data.op)
		expr_print(data.left, lvl + 1)
		expr_print(data.right, lvl + 1)
	}
}

main :: proc() {
	file := os.args[1]
	expr := os.read_entire_file(file) or_else panic("No file found")
	tokens := lex(string(expr))
	tokens_print(tokens)

	parser := Parser {
		tokens = tokens,
	}
	// fmt.println(Binary{left = &Number{value = 100}, right = &Number{value = 200}})
	stmts := parse_program(&parser)
	for stmt in stmts {
		fmt.println(stmt)
	}

	// ctx := ContextCreate()
	// module := ModuleCreateWithNameInContext("calc", ctx)
	// builder := CreateBuilderInContext(ctx)
	// setup_runtime(ctx, module, builder)

	// generate(pexpr, ctx, module, builder)

	// InitializeX86Target()
	// InitializeX86TargetInfo()
	// InitializeX86TargetMC()
	// InitializeX86AsmPrinter()

	// triple := GetDefaultTargetTriple()

	// target: TargetRef

	// error: cstring
	// if GetTargetFromTriple(triple, &target, &error) > 0 {
	// 	fmt.println(triple, string(error))
	// 	return
	// }
	// SetTarget(module, triple)

	// fmt.println(target, triple)
	// tm := CreateTargetMachine(
	// 	target,
	// 	triple,
	// 	"generic",
	// 	"",
	// 	.CodeGenLevelDefault,
	// 	.RelocPIC,
	// 	.CodeModelDefault,
	// )

	// SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	// if VerifyModule(module, .AbortProcessAction, &error) > 0 {
	// 	fmt.println(error)
	// }
	// if TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error) > 0 {
	// 	fmt.println(error)
	// }
}
