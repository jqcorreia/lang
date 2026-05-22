package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sys/posix"
import "core:time"

Options :: struct {
	command: string `args:"pos=0,required"`,
	file:    string `args:"pos=1"`,
}

main :: proc() {
	opt: Options

	flags.parse_or_exit(&opt, os.args, .Unix)

	if opt.command == "lsp" {
		lsp_run()
		return
	}

	compiler_init()
	compiler.current_filepath = filepath.dir(opt.file)

	start_time := time.now()

	source := os.read_entire_file(opt.file, context.allocator) or_else panic("No file found")

	ok: bool
	if opt.command == "check" {
		_, ok = compile(string(source), opt.file)
	} else {
		ok = build(string(source), opt.file)
	}

	if !ok {
		fmt.printf("Compilation failed with %d errors:\n", len(compiler.errors))
		for error in compiler.errors {
			print_error_pretty(error)
		}
		os.exit(1)
	}
	if opt.command == "check" {
		os.exit(0)
	}

	if ODIN_DEBUG {
	}

	fmt.println("--- Compilation done in", time.diff(start_time, time.now()), "---")
	linker_libs := strings.builder_make()

	for lib in compiler.external_linker_libs {
		fmt.sbprintf(&linker_libs, "-l%s ", lib)
	}
	build_command := fmt.tprintf(
		"ld -o out /usr/lib/crt1.o /usr/lib/crti.o calc.o %s-lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 /usr/lib/crtn.o",
		strings.to_string(linker_libs),
	)
	// Link and run
	when ODIN_OS == .Linux {
		if opt.command == "build" {
			fmt.println("Using final build command:", build_command)
			posix.system(strings.clone_to_cstring(build_command))
			os.exit(0)
		}
		if opt.command == "run" {
			fmt.println("Using final build command:", build_command)
			posix.system(strings.clone_to_cstring(build_command))
			posix.system("./out")
			os.exit(0)
		}
	} else {
		unimplemented("Only linux is supported for now. :-\\")
	}

	os.exit(0)
}
