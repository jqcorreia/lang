package main

import "core:container/queue"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sys/posix"
import "core:time"

Compiler :: struct {
	filepath:             string,
	filepath_dir:         string,
	object_filepath:      string,
	out_file:             string,
	exe_dir:              string, // Directory of the compiler executable
	line_starts:          map[string][dynamic]int,
	sources:              map[string]string,
	scopes:               queue.Queue(Scope),
	global_scope:         Scope,
	loops:                queue.Queue(Loop),
	types:                map[string]^Type,
	errors:               [dynamic]Compiler_Error,
	external_linker_libs: [dynamic]string,
	arena:                virtual.Arena,
	target:               string,
	verify_only:          bool,
}

Compiler_Error :: struct {
	file:    string,
	span:    Span,
	message: string,
}

CompilerConfig :: struct {
	path:            string,
	target:          string,
	object_filepath: string,
	verify_only:     bool,
	output_file:     string,
}

Loop :: struct {
	break_block: BasicBlockRef,
}

compiler := Compiler{}

compiler_init :: proc(config: CompilerConfig) {
	target: string
	if config.target == "" {
		#partial switch ODIN_OS {
		case .Linux:
			target = "linux"
		case .Windows:
			target = "windows"
		}
	} else {
		target = config.target
	}

	compiler.filepath = config.path
	compiler.filepath_dir = filepath.dir(config.path)

	// Target-native artifact extensions: COFF .obj / .exe on Windows,
	// ELF .o / no-extension on Linux.
	stem := filepath.stem(compiler.filepath)
	obj_ext := target == "windows" ? "obj" : "o"

	compiler.object_filepath =
		config.object_filepath != "" ? config.object_filepath : fmt.tprintf("%s.%s", stem, obj_ext)

	compiler.out_file =
		config.output_file == "" ? (target == "windows" ? fmt.tprintf("%s.exe", stem) : stem) : config.output_file

	compiler.verify_only = config.verify_only

	compiler.target = target
	exe_dir, exe_dir_err := os.get_executable_directory(context.allocator)
	assert(exe_dir_err == nil, "Could not determine compiler executable directory")
	compiler.exe_dir = exe_dir
	err := virtual.arena_init_growing(&compiler.arena)
	assert(err == .None)
}

compiler_reset :: proc() {
	compiler.errors = {}
	compiler.line_starts = make(map[string][dynamic]int)
	compiler.sources = make(map[string]string)
	compiler.loops = {}
	compiler.external_linker_libs = {}
}

compile :: proc() -> (stmts: []^Ast_Node, ok: bool) {
	compiler_reset()

	source :=
		os.read_entire_file(compiler.filepath, context.allocator) or_else panic("No file found")

	// Auto-include the runtime, resolved relative to the executable
	runtime_path, _ := filepath.join(
		{compiler.exe_dir, "runtime", "start.zero"},
		context.allocator,
	)
	runtime_source :=
		os.read_entire_file(runtime_path, context.allocator) or_else panic(
			fmt.tprintf("Runtime not found at %s", runtime_path),
		)
	runtime_tokens := lex(string(runtime_source), runtime_path)
	runtime_parser := Parser {
		tokens   = runtime_tokens,
		filename = runtime_path,
	}
	runtime_stmts := parse_program(&runtime_parser)

	// Reset line_starts so they reflect user source only (for error reporting)
	compiler.line_starts = {}
	tokens := lex(string(source), compiler.filepath)
	when ODIN_DEBUG {
		tokens_print(tokens)
	}

	parser := Parser {
		tokens   = tokens,
		filename = compiler.filepath,
	}

	user_stmts := parse_program(&parser)

	if len(compiler.errors) > 0 {
		return user_stmts, false
	}

	// Runtime first, then user code
	all_stmts: [dynamic]^Ast_Node
	for s in runtime_stmts do append(&all_stmts, s)
	for s in user_stmts do append(&all_stmts, s)
	stmts = order_statements(all_stmts[:])

	when ODIN_DEBUG {
		for stmt in stmts {
			statement_print(stmt)
		}
	}

	checker := Checker{}
	check(&checker, stmts)

	ok = len(compiler.errors) == 0
	return
}

build :: proc() -> (ok: bool) {
	// Reset the compiler arena
	free_all(virtual.arena_allocator(&compiler.arena))
	context.allocator = virtual.arena_allocator(&compiler.arena)

	// Primitive, dumb timing
	start_time := time.now()

	stmts, compile_ok := compile()
	if !compile_ok {
		fmt.printf("Compilation failed with %d errors:\n", len(compiler.errors))
		for error in compiler.errors {
			print_error_pretty(error)
		}
		return false
	}
	generate_ok := generate(stmts)
	if !generate_ok {
		fmt.printf("Compilation failed with %d errors:\n", len(compiler.errors))
		for error in compiler.errors {
			print_error_pretty(error)
		}
		return false
	}

	if !compiler.verify_only {
		switch compiler.target {
		case "linux":
			linker_libs := strings.builder_make()

			for lib in compiler.external_linker_libs {
				fmt.sbprintf(&linker_libs, "-l%s ", lib)
			}
			build_command := fmt.tprintf(
				"ld -o %s /usr/lib/crt1.o /usr/lib/crti.o %s %s-lc -dynamic-linker /lib64/ld-linux-x86-64.so.2 /usr/lib/crtn.o",
				compiler.out_file,
				compiler.object_filepath,
				strings.to_string(linker_libs),
			)
			fmt.println("Using final build command:", build_command)
			posix.system(strings.clone_to_cstring(build_command))
		case "windows":
			// Cross-link a native Windows console exe with lld-link against the
			// MSVC CRT + Windows SDK import libs. ZERO_WINSDK points at an xwin
			// splat root (containing crt/ and sdk/).
			win_sdk := os.get_env("ZERO_WINSDK", context.allocator)
			if win_sdk == "" {
				fmt.println(
					"error: ZERO_WINSDK is not set; cannot locate Windows CRT/SDK import libs.",
				)
				return false
			}

			linker_libs := strings.builder_make()
			for lib in compiler.external_linker_libs {
				// "c" is the POSIX libc placeholder; on Windows the C runtime is
				// provided by the libcmt/libucrt CRT libs linked explicitly below.
				if lib == "c" {continue}
				fmt.sbprintf(&linker_libs, "%s.lib ", lib)
			}
			build_command := fmt.tprintf(
				"lld-link /nologo /subsystem:console /out:%s " +
				"/libpath:%s/crt/lib/x86_64 /libpath:%s/sdk/lib/ucrt/x86_64 /libpath:%s/sdk/lib/um/x86_64 " +
				"%s libcmt.lib libvcruntime.lib libucrt.lib legacy_stdio_definitions.lib kernel32.lib %s",
				compiler.out_file,
				win_sdk,
				win_sdk,
				win_sdk,
				compiler.object_filepath,
				strings.to_string(linker_libs),
			)
			fmt.println("Using final build command:", build_command)
			posix.system(strings.clone_to_cstring(build_command))
		}
		fmt.println("--- Built in", time.diff(start_time, time.now()), "---")
	}
	return true
}

// Order top-level statements by processing priority:
// 1. Imports and external blocks (types + external function signatures)
// 2. Struct declarations
// 3. Global variable declarations
// 4. Functions
stmt_priority :: proc(node: ^Ast_Node) -> int {
	#partial switch &data in node.data {
	case Ast_Import, Ast_Const_Decl:
		return 0
	case Ast_Block:
		return 1
	case Ast_Struct_Decl:
		return 2
	case Ast_Var_Decl:
		return 3
	case Ast_Function:
		return 4
	}
	return 5
}

order_statements :: proc(stmts: []^Ast_Node) -> []^Ast_Node {
	ordered: [dynamic]^Ast_Node
	for priority in 0 ..= 5 {
		for s in stmts {
			if stmt_priority(s) == priority {
				append(&ordered, s)
			}
		}
	}
	return ordered[:]
}
