package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

printf_fn: ValueRef
fmt_ptr: ValueRef
printf_ty: TypeRef


Function :: struct {
	name:   string,
	params: []string,
	ty:     TypeRef,
	fn:     ValueRef,
}

State :: struct {
	funcs:       map[string]Function,
	vars:        map[string]ValueRef,
	ret_value:   ValueRef,
	line_starts: [dynamic]int,
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

	fmt.println("What?!")
	state.funcs["print"] = Function {
		name   = "print",
		ty     = printf_ty,
		fn     = printf_fn,
		params = {"val"},
	}
}

token_serialize :: proc(token: Token) -> string {
	sb := strings.builder_make()
	line, col := span_to_location(token.span)
	lexeme := token.lexeme
	if lexeme == "\n" {
		lexeme = "\\n"
	}
	fmt.sbprintf(&sb, "%s \"%s\", line: %d, col: %d", token.kind, lexeme, line, col)

	return strings.to_string(sb)
}

tokens_print :: proc(tokens: []Token) {
	for token in tokens {
		fmt.println(token_serialize(token))
	}
}

main :: proc() {
	ctx := ContextCreate()
	module := ModuleCreateWithNameInContext("calc", ctx)
	builder := CreateBuilderInContext(ctx)

	setup_runtime(ctx, module, builder)

	fmt.println(state)
	start_time := time.now()
	filename := "test3.z"

	if len(os.args) > 1 {
		filename = os.args[1]
	}

	expr := os.read_entire_file(filename) or_else panic("No file found")
	tokens := lex(string(expr))

	// fmt.println(tokens)
	tokens_print(tokens)

	parser := Parser {
		tokens = tokens,
	}

	stmts := parse_program(&parser)
	for stmt in stmts {
		statement_print(stmt)
		// fmt.println(stmt)
		// e := stmt.data.(Statement_Assignment).expr
		// expr_print(e)
	}

	generate(stmts, ctx, module, builder)

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
	// DumpModule(module)
	fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")
}
