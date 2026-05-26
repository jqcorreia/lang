package main

import "core:fmt"
import "core:os"
import "core:testing"

TEST_FOLDER :: "tests"
SKIP_TESTS := [?]string{"var_shadow.zero", "bench_large.zero"}

@(test)
run_tests :: proc(t: ^testing.T) {
	compiler_init()

	handle, _ := os.open(TEST_FOLDER)
	fis, _ := os.read_dir(handle, -1, context.temp_allocator)
	os.close(handle)

	// Cleanup primitive types and generic compiler info that does not
	// end up in an arena.
	defer {
		delete(compiler.current_filepath)
		delete(compiler.exe_dir)

		for _, t in compiler.types do free(t)
		delete(compiler.types)
	}

	for fi in fis {
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
		build_ok := build(string(source), fi.fullpath)
		if !build_ok {
			for err in compiler.errors {
				fmt.printf("[%s] %s\n", fi.name, err.message)
			}
		}
		testing.expectf(t, build_ok, "[%s] compilation failed", fi.name)
	}
	free_all(context.temp_allocator)
}
