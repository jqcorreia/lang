package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/posix"

Options :: struct {
	command:      string `args:"pos=0,required"`,
	file:         string `args:"pos=1"`,
	target:       string `args:"name=target"`,
	out:          string `args:"name=out"`,
	print_tokens: bool `args:"name=print-tokens"`,
	backend:      string `args:"name=backend"`,
	overflow:     [dynamic]string,
}

supported_commands :: []string{"lsp", "check", "build", "run"}

validate_opt :: proc(opt: Options) {
	valid_cmd := false
	for cmd in supported_commands {
		if cmd == opt.command {
			valid_cmd = true
		}
	}
	if !valid_cmd {
		fmt.println("Invalid command")
		os.exit(1)
	}

	if opt.file == "" {
		fmt.println("No file provided")
		os.exit(1)
	}
}

main :: proc() {
	opt: Options
	flags.parse_or_exit(&opt, os.args, .Unix)

	if opt.command == "lsp" {
		lsp_run()
		return
	}

	validate_opt(opt)


	compiler_init(
		CompilerConfig {
			path = opt.file,
			target = opt.target,
			output_file = opt.out,
			print_tokens = opt.print_tokens,
			backend = opt.backend == "" || opt.backend == "llvm" ? .LLVM : .Custom,
		},
	)

	switch opt.command {
	case "check":
		compile()
	case "build":
		if !build() do os.exit(1)
	case "run":
		if !build() do os.exit(1)
		sb := strings.builder_make()
		fmt.sbprintf(&sb, "./%s ", compiler.out_file)
		for extra_arg in opt.overflow {
			fmt.sbprintf(&sb, "%s ", extra_arg)
		}
		posix.system(strings.to_cstring(&sb))
	}

	os.exit(0)
}
