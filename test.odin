package main

import "core:fmt"
import "core:os"
import "core:testing"

TEST_FOLDER :: "tests"
SKIP_TESTS := [?]string{"var_shadow.zero", "bench_large.zero"}

@(test)
run_tests :: proc(t: ^testing.T) {
	handle, _ := os.open(TEST_FOLDER)
	fis, _ := os.read_dir(handle, -1, context.temp_allocator)
	os.close(handle)

	// Cleanup primitive types and generic compiler info that does not
	// end up in an arena.
	defer {
		delete(compiler.filepath)
		delete(compiler.filepath_dir)
		delete(compiler.exe_dir)

		delete(compiler.types)
	}

	for fi in fis {

		compiler_init({path = fi.fullpath, verify_only = true})
		skip := false
		for name in SKIP_TESTS {
			if fi.name == name {
				skip = true
				break
			}
		}
		if skip {
			fmt.printf("[%s] skipped\n", fi.name)
			continue
		}

		source := os.read_entire_file(fi.fullpath, context.temp_allocator) or_else nil
		if source == nil {
			fmt.printf("[%s] could not read file\n", fi.name)
			testing.fail(t)
			continue
		}

		fmt.println(fi.name)
		build_ok := build()
		if !build_ok {
			for err in compiler.errors {
				fmt.printf("[%s] %s\n", fi.name, err.message)
			}
		}
		testing.expectf(t, build_ok, "[%s] compilation failed", fi.name)
	}
	free_all(context.temp_allocator)
}
