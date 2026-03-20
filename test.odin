package main


import "core:fmt"
import "core:os"
import "core:testing"

TEST_FOLDER :: "tests"

@(test)
run_tests :: proc(t: ^testing.T) {
	compiler_init()

	handle, _ := os.open(TEST_FOLDER)
	fis, _ := os.read_dir(handle, -1, context.allocator)
	os.close(handle)

	for fi in fis {
		source := os.read_entire_file(fi.fullpath, context.allocator) or_else nil
		if source == nil {
			fmt.printf("[%s] could not read file\n", fi.name)
			testing.fail(t)
			continue
		}

		_, compile_ok := compile(string(source))
		if !compile_ok {
			for err in compiler.errors {
				fmt.printf("[%s] %s\n", fi.name, err.message)
			}
		}
		testing.expectf(t, compile_ok, "[%s] compilation failed", fi.name)
	}
}
