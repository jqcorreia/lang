# Function Pointers — Remaining Work

State as of the in-progress refactor: lexer, parser, AST, and
`resolve_type_expr` for `Type_Expr_Function` are done. `function_signature_resolve`
builds a `.Function` `Type` (variadic encoded as a sentinel `Type{variadic=true}`
in `sig.params`). `function_call_resolve` and `function_call_check` drive off
the callee symbol's `type` (the signature). The remaining segfault on
`add(10, 32)` (where `add` is a variable of `fn(...) -> ...` type) lives in
codegen.

## Main Blocker — `function_call_emit_sysv`

`function.odin:431` still does:

```odin
decl := sym.decl.data.(Ast_Function)
```

For a Variable-of-`.Function`-type symbol, `sym.decl` is an `Ast_Var_Decl`. The
type assertion panics → exit 139. The whole proc still reads `decl.params[i]`
for variadic detection and per-param types, and pulls the LLVM function value
from `gen.values[sym]` / `gen.types[sym]`.

Mirror what `function_call_resolve` already does — drive off the signature on
the symbol's type:

```odin
sig := sym.type      // .Function signature

if !is_variadic && sig.params[i].variadic { ... }
param_type := sig.params[i]
```

### Two paths for the callable value

`BuildCall2` needs both the function pointer (`sym_value`) and the
**FunctionType** TypeRef (`sym_type`). Where they come from depends on whether
the call is direct or indirect:

- **Direct (`sym.kind == .Function`)**: keep the lazy-emit-then-cache path:

  ```odin
  if sym not_in gen.values {
      function_decl_emit_sysv(gen, &decl, scope, span)
  }
  sym_value := gen.values[sym]
  sym_type  := gen.types[sym]
  ```

- **Indirect (`sym.kind == .Variable`)**: emit the callee expression to get the
  loaded function pointer, and build the LLVM FunctionType from `sig`:

  ```odin
  sym_value := emit_value(gen, e.callee, scope, span)
  sym_type, byval_idxs, byval_tys := build_llvm_fn_type(gen, sig)
  ```

### Shared helper

Extract the param-classify + `FunctionType(...)` block currently inside
`function_decl_emit_sysv` (lines ~359-391) into:

```odin
build_llvm_fn_type :: proc(gen: ^Generator, sig: ^Type)
    -> (fn_type: TypeRef, byval_idxs: [dynamic]u32, byval_tys: [dynamic]TypeRef)
```

Iterate `sig.params`, classify each via `abi_classify_param`, and build the
LLVM FunctionType from `sig.return_type` and the classified params. Reuse from
both `function_decl_emit_sysv` and the indirect-call branch.

## `emit_value` / `emit_address` for Function symbols

`codegen.odin:116` and `codegen.odin:203` both route every `Expr_Variable`
through `gen.values[sym]` + `BuildLoad2`. For a Function symbol,
`gen.values[sym]` is the LLVM function value (already a pointer); loading from
it reads 8 bytes of code at runtime — segfault. The RHS of `add = add2`
triggers this path.

Short-circuit at the top of each `Expr_Variable` case:

```odin
case Expr_Variable:
    sym, _ := resolve_symbol(scope, e.value)
    if sym.kind == .Function {
        return gen.values[sym]   // function value/pointer, no load
    }
    ...
```

## Priority

1. Replace `sym.decl` access in `function_call_emit_sysv` with `sig := sym.type`.
2. Add the `build_llvm_fn_type` helper and the direct/indirect branch for
   `sym_value` / `sym_type`.
3. Short-circuit `emit_value` / `emit_address` for Function-symbol
   `Expr_Variable`.

After (1) and (3), `add = add2; add(10, 32)` compiles. (2) makes the indirect
`BuildCall2` use the correct LLVM signature.

## Smaller Cleanups (Same Pass)

- `function_call_resolve:196` and `function_call_check:302` still extract
  `func_name` via `e.callee.data.(Expr_Variable).value`. Works for bare
  identifiers; would crash on `obj.cb(...)` or `table[i](...)`. To generalize,
  replace name-lookup with `sig := resolve_expr_type(e.callee, scope, span)`
  and validate `sig.kind == .Function`.
- `function_call_resolve:268-269`: guard `e.callee.type` for `.Function` before
  dereferencing `.return_type` — otherwise calling a non-callable derefs nil.
- `function_decl_emit_sysv:366`: still iterates `s.params` (AST) for variadic
  detection. Could iterate `s.symbol.type.params` and check `.variadic` for
  consistency. Not required.
- `function_call_resolve:227-232`: dead commented block — delete.

## Pre-pass Idea (Future)

Once the unified call site reads only `e.callee.type`, the lazy
signature-resolution fallback is no longer needed if signatures are pre-resolved
in a header pass. In `compiler.odin:compile`, after `bind_scopes` and before
`resolve_types`:

```odin
for stmt in stmts {
    if fn, ok := stmt.data.(Ast_Function); ok {
        fn.symbol.type = function_signature_resolve(&fn, stmt.scope, stmt.span)
    }
}
```

Every Function symbol then has its signature before any call site is
visited — forward references resolve trivially, no `sym.type == nil` checks.
