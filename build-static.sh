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
# Works both with an extracted LLVM.org release (set LLVM_DIR, archives are LTO
# bitcode and need lld) and with a distro's llvm-21-dev packages (archives are
# native objects, no lld needed) — it auto-detects which.
set -euo pipefail

# Locate llvm-config: explicit env, an extracted release dir, or a PATH lookup.
if [[ -n "${LLVM_CONFIG:-}" ]]; then
    :
elif [[ -n "${LLVM_DIR:-}" && -x "$LLVM_DIR/bin/llvm-config" ]]; then
    LLVM_CONFIG="$LLVM_DIR/bin/llvm-config"
elif [[ -x "$HOME/llvm/LLVM-21.1.8-Linux-X64/bin/llvm-config" ]]; then
    LLVM_CONFIG="$HOME/llvm/LLVM-21.1.8-Linux-X64/bin/llvm-config"
elif command -v llvm-config-21 >/dev/null 2>&1; then
    LLVM_CONFIG="llvm-config-21"
elif command -v llvm-config >/dev/null 2>&1; then
    LLVM_CONFIG="llvm-config"
else
    echo "llvm-config not found. Set LLVM_CONFIG or LLVM_DIR." >&2
    exit 1
fi

LIBDIR="$("$LLVM_CONFIG" --libdir)"

# llvm-config lists every component it knows about, but some (e.g. Polly) may not
# be shipped as static archives by all distros' -dev packages. Keep only the -l
# flags whose libNAME.a actually exists; the LLVM C API zero uses doesn't depend
# on the optional ones. Non -l tokens are passed through untouched.
LLVM_LIBS=""
for tok in $("$LLVM_CONFIG" --link-static --libs); do
    case "$tok" in
        -l*) if [[ -f "$LIBDIR/lib${tok#-l}.a" ]]; then
                 LLVM_LIBS="$LLVM_LIBS $tok"
             else
                 echo "  skipping $tok (no static archive present)"
             fi ;;
        *)   LLVM_LIBS="$LLVM_LIBS $tok" ;;
    esac
done

# System libs. llvm-config emits distro-specific absolute paths for some static
# libs (e.g. a Debian zstd path) that may not exist on the build host. Convert
# every "/path/libNAME.a" to "-lNAME" so they resolve dynamically against the
# system; we only require LLVM itself to be static.
SYS_LIBS=""
for tok in $("$LLVM_CONFIG" --link-static --system-libs); do
    case "$tok" in
        /*.a) name="$(basename "$tok")"; name="${name#lib}"; SYS_LIBS="$SYS_LIBS -l${name%.a}" ;;
        *)    SYS_LIBS="$SYS_LIBS $tok" ;;
    esac
done
SYS_LIBS="$SYS_LIBS -lstdc++"

# 1) Stub archive to shadow the system libLLVM-21.so that Odin's -lLLVM-21 would
#    otherwise pull in. An explicit -L is searched before the system dirs, so an
#    (empty) libLLVM-21.a here wins over the shared object.
SHADOW_DIR="$(mktemp -d)"
trap 'rm -rf "$SHADOW_DIR"' EXIT
: > "$SHADOW_DIR/_stub.c"
cc -c "$SHADOW_DIR/_stub.c" -o "$SHADOW_DIR/_stub.o"
ar rcs "$SHADOW_DIR/libLLVM-21.a" "$SHADOW_DIR/_stub.o"

# 2) All LLVM component archives have circular dependencies, so wrap them in a
#    link group. The stub -L comes first; the real symbols come from the group.
LINK_FLAGS="-L$SHADOW_DIR -L$LIBDIR -Wl,--start-group $LLVM_LIBS -Wl,--end-group $SYS_LIBS"

# LLVM.org release archives contain LLVM IR bitcode (LTO build), which the
# default GNU ld cannot consume; lld links bitcode directly (built-in LTO).
# Distro llvm-dev archives are native objects and link with the default linker.
# Detect which by inspecting a member of a known component archive.
LINKER_FLAG=""
CORE_LIB="$LIBDIR/libLLVMCore.a"
if [[ -f "$CORE_LIB" ]]; then
    member="$(ar t "$CORE_LIB" 2>/dev/null | head -1 || true)"
    # Read only the first 4 bytes; tolerate the SIGPIPE this induces under pipefail.
    magic="$( { ar p "$CORE_LIB" "$member" 2>/dev/null || true; } | od -An -tx1 -N4 2>/dev/null || true)"
    if [[ "$magic" == *"42 43 c0 de"* ]]; then
        echo "Archives are LLVM bitcode (LTO) -> linking with lld"
        LINKER_FLAG="-linker:lld"
    fi
fi

echo "Linking against static LLVM in $LIBDIR"
odin build . -out:zero -o:speed $LINKER_FLAG -extra-linker-flags:"$LINK_FLAGS" "$@"
echo "Built ./zero"
