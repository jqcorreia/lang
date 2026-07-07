#!/usr/bin/env bash
# Build a statically-LLVM-linked `zero` compiler.
#
# The source (llvm.odin) always declares `foreign import LLVM_C "system:LLVM-21"`,
# so a plain `odin build .` / `make` links the system libLLVM-21.so dynamically.
# This script does NOT touch the source. Instead it:
#   1. drops an EMPTY stub libLLVM-21.a into a shadow dir placed first on the
#      linker search path, so Odin's emitted `-lLLVM-21` resolves to the stub
#      (contributing no symbols) instead of the system shared object; then
#   2. resolves the real LLVM C-API symbols from the static component archives.
#
# LLVM 21 static libs are expected under $LLVM_DIR (override via env).
set -euo pipefail

LLVM_DIR="${LLVM_DIR:-$HOME/llvm/LLVM-21.1.8-Linux-X64}"
LLVM_CONFIG="$LLVM_DIR/bin/llvm-config"

if [[ ! -x "$LLVM_CONFIG" ]]; then
    echo "llvm-config not found at $LLVM_CONFIG" >&2
    echo "Set LLVM_DIR to your extracted LLVM 21 directory." >&2
    exit 1
fi

LIBDIR="$($LLVM_CONFIG --libdir)"
LLVM_LIBS="$($LLVM_CONFIG --link-static --libs)"

# System libs. llvm-config may emit distro-specific absolute paths (e.g. a
# Debian zstd path); use plain -l flags that resolve against the system.
SYS_LIBS="-lrt -lstdc++ -lz -lzstd"

# 1) Stub archive to shadow the system libLLVM-21.so that Odin's -lLLVM-21 would
#    otherwise pull in. An explicit -L is searched before the system dirs, so a
#    (empty) libLLVM-21.a here wins over /usr/lib/libLLVM-21.so.
SHADOW_DIR="$(mktemp -d)"
trap 'rm -rf "$SHADOW_DIR"' EXIT
: > "$SHADOW_DIR/_stub.c"
cc -c "$SHADOW_DIR/_stub.c" -o "$SHADOW_DIR/_stub.o"
ar rcs "$SHADOW_DIR/libLLVM-21.a" "$SHADOW_DIR/_stub.o"

# 2) All LLVM component archives have circular dependencies, so wrap them in a
#    link group. The stub -L comes first; the real symbols come from the group.
LINK_FLAGS="-L$SHADOW_DIR -L$LIBDIR -Wl,--start-group $LLVM_LIBS -Wl,--end-group $SYS_LIBS"

echo "Linking against static LLVM in $LIBDIR"
# The LLVM.org release archives contain LLVM IR bitcode (LTO build), which the
# default GNU ld cannot consume. lld links bitcode directly (built-in LTO), so
# force it. System lld must be >= the LLVM version that produced the bitcode.
odin build . -out:zero -linker:lld -extra-linker-flags:"$LINK_FLAGS" "$@"
echo "Built ./zero"
