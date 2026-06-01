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

	compiler_init(CompilerConfig{path = opt.file, target = opt.target})

	switch opt.command {
	case "lsp":
		lsp_run()
		return
	case "check":
		compile()
	case "build":
		if !build() do os.exit(1)
	case "run":
		if !build() do os.exit(1)
		posix.system(strings.clone_to_cstring(fmt.tprintf("./%s", compiler.out_file)))
	}

	os.exit(0)
}
