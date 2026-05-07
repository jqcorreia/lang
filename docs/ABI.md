Lots of good questions packed together — let me unpack the layers because they're actually distinct concepts that get conflated.

## SysV is a platform contract, not a language contract

"SysV AMD64 ABI" is a binary calling convention specified for the x86-64 architecture on Unix-like systems. It says "function arguments go in these registers in this order, structs are classified this way, returns work like this, the stack is aligned to 16 bytes at call boundaries." It has nothing to do with C specifically — it's about *machine code*.

Any code running on the platform follows it (or breaks). C compilers emit code following SysV. Rust's `extern "C"` emits code following SysV. Fortran's `bind(C)`, Go's cgo, Zig's `callconv(.C)`, hand-written assembly — all SysV when targeting Linux/macOS/BSD x86-64.

So if you make Zero SysV-compliant, you can interop with **any code on the same platform that exposes a SysV-compliant interface**, regardless of source language. That's not a special property of C; C is just the *lingua franca* because it has historically been the language that exposes the platform ABI most directly.

## It's a (CPU × OS) thing

ABI is tied to architecture *and* operating system, because the OS dictates conventions on top of the CPU's register file:

| Platform | ABI |
|---|---|
| x86-64 Linux/macOS/BSD | **SysV AMD64** (what we've been talking about) |
| x86-64 Windows | **Microsoft x64** — different register allocation (`rcx`, `rdx`, ... not `rdi`, `rsi`), shadow space, struct rules |
| ARM64 (most platforms) | **AAPCS64** |
| ARM64 Apple | AAPCS64 with Apple variations |
| WebAssembly | its own thing |
| RISC-V | yet another |

So "I'm SysV-compliant" really means "I'm correct on x86-64 Linux/macOS/BSD." If you ever wanted Zero to run on Windows, you'd add a parallel implementation for Microsoft x64. (LLVM helps here — most of the lowering work is reusable per-target, but the classifier and which-attribute-where details differ.)

## What Rust devs mean by "stable ABI"

This is where the conversation shifts. Rust *does* comply with the platform ABI for interop — `extern "C"` plus `#[repr(C)]` makes Rust functions and structs follow SysV/Microsoft x64/whatever. That's solved.

What Rust **doesn't** have is a stable **Rust-to-Rust** ABI. The default calling convention `extern "Rust"` and the default struct layout `#[repr(Rust)]` are deliberately unspecified — the compiler can rearrange struct fields, change calling conventions, change v-table layouts, etc. between versions, releases, even compilations. This is intentional: it reserves room for optimization (better field ordering for cache, niche-filling enum tricks like `Option<&T>` being one pointer, etc.).

The cost is significant:

- You can't distribute precompiled Rust libraries as `.so`/`.dll` and link them into other Rust programs reliably across `rustc` versions.
- Two crates compiled with slightly different toolchains can produce binaries that disagree on what a `Vec<T>` looks like.
- The ecosystem works around this by distributing **source code** (`cargo` + crates.io) and recompiling everything together. Works fine in practice; doesn't help shipping binary plugins.

So when Rust people say "stable ABI" they usually mean one of:

- **"Use `extern "C"`"** — the workaround. Manually mark every interface as C-ABI. Works, but you lose Rust types like `Vec`, `String`, generics, traits at the boundary.
- **A future stable Rust-native ABI** ("crABI" is the longest-running proposal). Would let `Vec<T>` cross a boundary. Has been discussed for years. Not stabilized.
- **Community workarounds** like the `abi_stable` crate, which encodes its own stable layout on top of `repr(C)`.

So no — Rust hasn't finalized their own native calling convention, and probably won't for a long time. The position is roughly: "We get optimization headroom by keeping it unstable; if you need stable, use C ABI."

## C++ has exactly the same problem, mostly solved by inertia

C++ also has unstable ABI in the strict sense. It's why GCC vs. Clang vs. MSVC C++ libraries don't link freely; why GCC libstdc++ has had quiet breaks (the `std::string` SSO change in GCC 5 was a famous one). What saved C++ is decades of practice + the Itanium C++ ABI, which most non-Microsoft compilers settled on. But it's a de facto standard, not a specified one.

## Practical takeaway for Zero

If you make Zero SysV-compliant on x86-64 Linux:

- ✅ You can call any C library.
- ✅ You can call any Rust function exposed as `extern "C"`.
- ✅ You can call any C++ function declared `extern "C"`.
- ✅ A C program could load Zero-compiled `.so`s (after you implement function visibility) and call into them.
- ❌ You can't directly receive a Rust `Vec<T>` across the boundary — that's `repr(Rust)`, opaque.
- ❌ You're not portable to Windows or ARM until you target those ABIs separately.

Zero having a private calling convention internally (which it does today, accidentally) is fine — Rust does that on purpose. But the moment you want to interop with the world, you need a SysV path. The split is exactly Rust's: "internal calls go fast and weird, external calls go through SysV." That's actually a respectable design point, not a hack.

The interesting choice you'd face later: do you make `extern "C"` an explicit declaration in Zero (forcing users to opt in), or do you make all functions ABI-stable by default and add an opt-in for the faster internal convention? Rust chose the former. Go chose the latter (everything is "Go ABI" unless you cgo). Either is defensible. Worth knowing what you're picking before the codebase has too many assumptions baked in.

---

Yes — and there used to be *several* of them. The Win32 story is a fun bit of history because it shows what happens when an OS predates a unified ABI.

## 32-bit Windows had a zoo

On x86-32, you'd see all of these in Microsoft headers:

| Convention | Cleanup | Used for | Macro |
|---|---|---|---|
| `__cdecl` | caller | C functions, variadics | (default for C) |
| `__stdcall` | callee | **Win32 API** | `WINAPI`, `CALLBACK`, `APIENTRY` |
| `__fastcall` | callee | perf-sensitive code, first 1–2 args in `ecx`/`edx` | `__fastcall` |
| `__thiscall` | callee | C++ member functions, `this` in `ecx` | implicit |
| `__pascal` | callee, args reversed | Win16, old Mac Toolbox | (legacy) |

The Win32 API specifically used `__stdcall`. The reasoning: with thousands of API calls in a typical app, having the callee clean the stack (one `ret N` instruction) saves a few bytes per call site versus `__cdecl`'s "caller emits `add esp, N` after every call." Multiplied across an exe, real binary-size savings on 1990s machines. The downside is `stdcall` can't be variadic (callee can't know how much to pop), which is why `printf` and friends stay `cdecl` even on Win32.

## 64-bit Windows mostly collapsed all of this

On x86-64 Windows, Microsoft simplified hard: there's basically **one** calling convention, called "Microsoft x64" (sometimes "x64 fastcall"). It's used by everything — the Win32 API, your C code, your C++ code, system libraries. The legacy keywords `__cdecl`, `__stdcall`, `__fastcall`, `__thiscall` are all still accepted by the compiler on x64, but they're silently ignored — they all produce identical code.

The exceptions:

- `__vectorcall` — Microsoft added this later for SIMD-heavy code; uses more `XMM`/`YMM` registers for arguments. Opt-in only.
- Variadic functions still have a slightly tweaked variant (different rules for floats — they get duplicated into both the GP and XMM register, the called variadic prologue picks whichever it needs).

So if you ever target Windows x64, "Microsoft x64" is the whole story for Win32 API calls.

## How Microsoft x64 differs from SysV

Worth knowing because if Zero ever ships on Windows you'll be writing a parallel lowering:

| | SysV AMD64 | Microsoft x64 |
|---|---|---|
| First 4 GP args | `rdi, rsi, rdx, rcx` (then `r8, r9`, then stack) | `rcx, rdx, r8, r9` (only 4!) then stack |
| First 4 FP args | `xmm0`–`xmm7` (8 SSE regs) | `xmm0`–`xmm3` (only 4) |
| Shadow space | none | **32 bytes** of stack the caller must reserve even when args fit in registers |
| Struct passing | eightbyte classification (the mess we just discussed) | size ≤ 8B in register; otherwise pointer-with-callee-copy (much simpler!) |
| Red zone | 128 bytes below `rsp` usable by leaf fns | none |
| Callee-saved regs | different set | different set |

The struct rule on Microsoft x64 is genuinely simpler: > 8 bytes → pass by pointer, callee makes its own copy. No SSE/INTEGER classification, no eightbyte split. So Rectangle on Windows would Just Work via your existing pointer mechanism (with the appropriate attribute — Windows uses different parameter attributes than `byval`, but the spirit is the same).

## Why Microsoft went their own way

The simplest answer is: timing. The SysV AMD64 ABI was finalized around 2000–2001 by AMD with input from the GCC/Linux community. Microsoft started 64-bit Windows development in parallel and made different choices. By the time both ABIs existed, deviating was free for them and standardizing was expensive — they had different design priorities (debuggability, exception handling integration with SEH, the shadow space for spilling args during debug builds). So we now have two AMD64 ABIs because two large vendors built x64 toolchains independently.

## Mental model

The takeaway: "Win32 API calling convention" historically meant `__stdcall` on 32-bit and is meaningless on 64-bit (same as everything else on the platform). When porting an ABI-aware compiler to Windows, the work is real but localized: replace the SysV register table with the Microsoft x64 register table, replace the eightbyte classifier with the simpler "≤ 8B in register, else pointer," and add shadow space at every call site. Most of your codegen stays put.
