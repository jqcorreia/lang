package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

Options :: struct {
	command: string `args:"pos=0,required"`,
	file:    string `args:"pos=1"`,
	target:  string `args:"name=target"`,
}

main :: proc() {
	opt: Options

	flags.parse_or_exit(&opt, os.args, .Unix)

	if opt.command == "lsp" {
		lsp_run()
		return
	}

	compiler_init(opt.file)

	switch opt.command {
	case "lsp":
		lsp_run()
		return
	case "check":
		compile()
	case "build":
		build()
	case "run":
		build()
		posix.system(strings.clone_to_cstring(fmt.tprintf("./%s", compiler.out_file)))
	}

	os.exit(0)
}
