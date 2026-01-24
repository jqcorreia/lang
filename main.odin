package main

import "core:fmt"
import "core:os"

printf_fn: ValueRef
fmt_ptr: ValueRef
printf_ty: TypeRef


Function :: struct {
	ty: TypeRef,
	fn: ValueRef,
}

State :: struct {
	funcs:     map[string]Function,
	ret_value: ValueRef,
}

state := State{}

setup_runtime :: proc(ctx: ContextRef, module: ModuleRef, builder: BuilderRef) {
	// Printf
	i32 := Int32TypeInContext(ctx)
	i8 := Int8TypeInContext(ctx)
	i8p := PointerType(i8, 0)

	printf_ty = FunctionType(
		i32, // return type
		&i8p, // first arg: char *
		1,
		true, // variadic
	)

	printf_fn = AddFunction(module, "printf", printf_ty)

	state.funcs["print"] = Function {
		ty = printf_ty,
		fn = printf_fn,
	}
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
	#partial switch expr.kind {
	case .Int_Lit:
		fmt.println("Int ", expr.data.(Expr_Int_Lit).value)
	case .Ident:
		fmt.println("Identifier ", expr.data.(Expr_Ident).value)
	case .Binary:
		data, _ := expr.data.(Expr_Binary)
		fmt.println("Binary ", data.op)
		expr_print(data.left, lvl + 1)
		expr_print(data.right, lvl + 1)
	}
}

main :: proc() {
	// file := os.args[1]
	expr := os.read_entire_file("test2.z") or_else panic("No file found")
	tokens := lex(string(expr))
	tokens_print(tokens)

	parser := Parser {
		tokens = tokens,
	}

	stmts := parse_program(&parser)

	// for stmt in stmts {
	// 	fmt.println(stmt)
	// 	data := stmt.data.(Stmt_Let)
	// 	expr_print(data.value)
	// }

	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)
	setup_runtime(ctx, module, builder)

	generate(stmts, ctx, module, builder)
	// generate(pexpr, ctx, module, builder)

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
		.RelocPIC,
		.CodeModelDefault,
	)

	SetModuleDataLayout(module, CreateTargetDataLayout(tm))
	if VerifyModule(module, .AbortProcessAction, &error) > 0 {
		fmt.println(error)
	}
	if TargetMachineEmitToFile(tm, module, "calc.o", .ObjectFile, &error) > 0 {
		fmt.println(error)
	}
}
