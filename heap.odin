package main

heap_create_new_func :: proc(scope: ^Scope) {
	new_fn := make_symbol(.Function)
	new_fn.name = "new"
}
