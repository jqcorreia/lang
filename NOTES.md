Pointers.

Here's the full breakdown:

  1. Lexer
  Add & as an Ampersand token. * already exists as Star.

  2. Type_Expr
  Add Type_Expr_Pointer :: struct { pointee: ^Type_Expr } to the union. Then parse_type_expr handles & prefix → recurses for the pointee type, same pattern as arrays.

  3. Types
  Add .Pointer to Type_Kind and a pointee_type: ^Type field to Type (already has elem_type for arrays, could reuse it or add a dedicated field for clarity).

  4. resolve_type_expr
  Handle Type_Expr_Pointer → resolve the pointee, create a new Type with .Pointer kind.

  5. Codegen, get_llvm_type
  .Pointer maps to PointerTypeInContext(gen.ctx, 0), LLVM opaque pointer, same as strings already use.

  6. Parser, expressions
  - Unary & in prefix position → address-of. No conflict since & has no infix meaning.
  - Unary * in prefix position → dereference. * in infix position stays as multiplication. The Pratt parser already handles this distinction (prefix vs infix).

  7. Resolver, Expr_Unary
  - &expr → type is pointer to expr.type
  - *expr → check expr.type is .Pointer, type is expr.type.pointee_type

  8. Codegen, Expr_Unary
  - &expr → call emit_address(expr) instead of emit_value, returns the pointer directly without loading
  - *expr → emit_value(expr) gets the pointer value, then BuildLoad2 with the pointee type

  9. Checker
  - *expr: verify expr.type is .Pointer, error otherwise
  - &expr: verify expr is addressable (variable, member, index, not a literal or call result)

  The tricky part is & vs * in the resolver's Expr_Unary: you need to distinguish address-of from dereference when both use Expr_Unary. Either add .Ampersand as a separate Token_Kind, or check op == .Ampersand vs op == .Star (with Star
  already meaning multiply in binary context, that's fine since they're separate AST nodes).

