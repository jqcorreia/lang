The pattern you're hitting has a name. What you have is essentially **synthesize-then-patch**: walk the tree bottom-up to compute each expression's type (`unify`/`coerce`), then when context arrives later (a call arg, a typed var-decl) you walk back down through `set_expr_type` patching subtrees. The cracks are structural: every new expression kind that can hold untyped operands is a new case in `set_expr_type`, and any one you forget produces silent wrong codegen — exactly what just happened with `Expr_Binary`. You'll hit it again with index expressions, ternaries (when you add them), nested calls, members of struct literals you didn't think of, etc.

The standard upgrade is **bidirectional type checking**: split the resolver into two functions instead of one.

- `infer(expr) -> Type` — use when there's no expected type (top-level, RHS of `var x = ...`, the argument to a variadic, etc.).
- `check(expr, expected_type)` — use when you *do* know what type the context wants (call arg with declared param type, RHS of `var x: T = ...`, struct-literal field with known field type, return expression with known return type).

Each expression kind implements both. For `Expr_Binary` in `check(e, T)`: just call `check(e.left, T)` and `check(e.right, T)`. The "push-down" stops being a separate retroactive pass and becomes the natural recursive structure of checking — you literally cannot forget a case because every expr kind has to define both modes. Untyped literals collapse to whatever the checking context demands, and at the top level (no context) they default. `unify` only survives for genuinely symmetric situations like range endpoints with no surrounding type.

This is how Odin, Go, Zig, Rust (within function bodies) and most modern statically-typed languages handle it. It isn't a big rewrite — your existing `coerce` becomes the leaf-rule of `check` (does this synthesized type work where T is expected?), and `infer` is mostly your current resolver minus the post-hoc patching. The big win: the class of bug you just fixed (`set_expr_type` missing a case) becomes structurally impossible.

Worth doing, but not urgent. The current shape is fine while the language is small; the right time to make the move is when adding the next expression kind starts to feel like "where do I need to remember to add a `set_expr_type` case this time?"
