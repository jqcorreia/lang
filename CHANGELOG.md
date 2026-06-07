<a name="v0.0.6"></a>
### v0.0.6 (2026-06-07)


#### Features

*   Basic switch/match ([7e3adeda](7e3adeda))
*   Implement 'continue' keyword. ([c6254e5c](c6254e5c))
*   validate CLI options. ([ba12c02c](ba12c02c))

#### Bug Fixes

*   allow type aliases to be based on custom types. ([5bbcbc92](5bbcbc92))
*   return nil if there are more fields than positional arguments. ([5e3dc1ca](5e3dc1ca))
*   Do a memset for aggregate types. ([889c5f27](889c5f27))



# v0.0.5
## Changes
- Function pointers
- Manual memory allocation, new() and free()

# v0.0.4
## Changes
- Codebase reorganize into "features" (struct, function, enum, etc....)
- Early implementation of Unified Function Call Syntax (not sure if good idea yet)
- Better ergonomics around numeric type coercions. e.g Integer literals to float
- Exponentiation operator
- More libc and libm bindings and some integration code.
- Proper and correct SysV ABI argument parsing (specially around struct lowering)
- Add support for custom value in enums. Also support coercion to a numeric type for ergonomics.
- Support for other numeric bases (fancy way to say that 0x literals are supported)
- Add support for implicit enum variants (Odin like `.variant` syntax when the enum can be infered)
- Support for basic array-array numeric operations
- Support primtive type casting e.g: `a: i32 = i32(123.666)`
- Constants. This was way more complex than we antecipated, since we do eager const eval and that implies a mini interpreter

