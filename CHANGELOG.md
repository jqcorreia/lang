<a name="v0.0.9"></a>
### v0.0.9 (2026-07-07)

#### Features

*   Statically link LLVM into the final binary


<a name="v0.0.8"></a>
### v0.0.8 (2026-07-02)


#### Bug Fixes

*   revert to using  as the compiler instead of using  directly ([9909b98f](9909b98f))

#### Features

*   Support match else clause ([83ed59cf](83ed59cf))
*   Add union support ([b770e0a0](b770e0a0))
*   Add proper support for command line arguments and slice() constructor ([c9dea970](c9dea970))



<a name="v0.0.7"></a>
### v0.0.7 (2026-06-29)


#### Bug Fixes

*   Stop compilation on function re-declaration. ([caaece0b](caaece0b))
*   allow positional arguments for global constant structs. ([a4d8dcfd](a4d8dcfd))
*   Fix enum cast to integers. ([b1c0b499](b1c0b499))
*   fix array index widening that was making invalid accesses via GEP ([58603214](58603214))
*   Change caret to bitwise XOR and add  as the exponentiation operator. ([70361e3a](70361e3a))
*   Wide indexes to 64 bits before bound checking. ([f153d079](f153d079))
*   properly pass single line statement blocks ([3e6b8679](3e6b8679))
*   allow type aliases to be based on custom types. ([5bbcbc92](5bbcbc92))
*   return nil if there are more fields than positional arguments. ([5e3dc1ca](5e3dc1ca))
*   Do a memset for aggregate types. ([889c5f27](889c5f27))

#### Features

*   Add support for conditional loops. ([88601302](88601302))
*   Implement assignment operators. ([069054d3](069054d3))
*   Add bitwise NOT ([888edbbd](888edbbd))
*   add bitwise operation - shift, and & or ([1e23c535](1e23c535))
*   change 'nil' keyword to 'null'. ([58477aa2](58477aa2))
*   Ranged indexes on arrays ([fcdc707d](fcdc707d))
*   Ranged indexes on slices ([466d0687](466d0687))
*   Primitive support for array and slice runtime bounds check. ([ee3afd9c](ee3afd9c))
*   Add support for variadic arguments as a slice inside the function ([4954c39f](4954c39f))
*   Implement len() builtin for arrays and slices. ([17540e63](17540e63))
*   Add primitive support for slices ([ec61e21c](ec61e21c))
*   Basic switch/match ([7e3adeda](7e3adeda))
*   Implement 'continue' keyword. ([c6254e5c](c6254e5c))
*   validate CLI options. ([ba12c02c](ba12c02c))



<a name="v0.0.6"></a>
### v0.0.6 (2026-06-07)


#### Features

*   Basic switch/match ([7e3adeda](7e3adeda))
*   Implement 'continue' keyword. ([c6254e5c](c6254e5c))
*   Validate CLI options. ([ba12c02c](ba12c02c))

#### Bug Fixes

*   Allow type aliases to be based on custom types. ([5bbcbc92](5bbcbc92))
*   Return nil if there are more fields than positional arguments. ([5e3dc1ca](5e3dc1ca))
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

