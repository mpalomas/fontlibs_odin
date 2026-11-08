#!/usr/bin/env bash
# Builds FreeType and HarfBuzz from upstream/ into lib/<os>-<arch>/: libfreetype.a and libharfbuzz.a (static), and libfontlibs.dylib
# (macOS) or libfontlibs.so (Linux), one shared library with the API of both (shared).
#
# Usage: tools/build_fontlibs.sh [static|shared|all]   (default: all)
#
# FreeType is built with upstream/config/fontlibs_ftoption.h and fontlibs_ftmodule.h (TrueType and CFF fonts, the auto-hinter, the smooth
# rasterizer; no zlib, PNG, or other formats). HarfBuzz is built from upstream/config/fontlibs_harfbuzz.cc: the shaper and the raster
# library, without the platform shapers, and with no libpng (PNG bitmap emoji are for the caller to decode). The sources are built
# for size (-Os, NDEBUG), and both configurations leave out what these libraries don't use. The objects are compiled once,
# position-independent, and serve both kinds of library, with -ffunction-sections and -fdata-sections so the programs' linker drops
# what they don't use. Only the C APIs of FreeType and HarfBuzz are exported from the shared library.
# HarfBuzz needs no C++ runtime (no exceptions, RTTI or thread-safe statics): the script checks it, so the shared library is
# linked with the C compiler and needs the C library only.
# Environment:
#   CC, CXX                  (default: cc, c++; CC also links the shared library)
#   CFLAGS, CXXFLAGS         Extra compiler flags
#   MACOSX_DEPLOYMENT_TARGET The oldest macOS to support (default: the compiler's)
#   JOBS                     Parallel compiles (default: the number of CPUs)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CC="${CC:-cc}"
CXX="${CXX:-c++}"
LINKAGE="${1:-all}"

die() {
    echo "error: $*" >&2
    exit 1
}

case "$LINKAGE" in
    static | shared | all) ;;
    *) die "usage: tools/build_fontlibs.sh [static|shared|all]" ;;
esac
case "$(uname -s)" in
    Linux) OS=linux SHARED_EXT=so ;;
    Darwin) OS=macos SHARED_EXT=dylib ;;
    *) die "unsupported OS $(uname -s), on Windows use tools/build_fontlibs.ps1" ;;
esac
case "$(uname -m)" in
    x86_64 | amd64) ARCH=x86_64 ;;
    arm64 | aarch64) ARCH=arm64 ;;
    *) die "unsupported architecture $(uname -m)" ;;
esac
PLATFORM="$OS-$ARCH"
LIB_DIR="$REPO/lib/$PLATFORM"
OBJ_DIR="$REPO/build/$PLATFORM"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)}"
UP="$REPO/upstream"
FT="$UP/freetype"
HB="$UP/harfbuzz/src"
[[ -f "$FT/src/base/ftbase.c" && -f "$HB/hb-ot-shape.cc" ]] || die "no sources in upstream/: run tools/import_sources.sh"

COMMON=(-Os -DNDEBUG -fPIC -ffunction-sections -fdata-sections -fvisibility=hidden)
FT_FLAGS=(
    "${COMMON[@]}" -DFT2_BUILD_LIBRARY
    '-DFT_CONFIG_OPTIONS_H=<fontlibs_ftoption.h>' '-DFT_CONFIG_MODULES_H=<fontlibs_ftmodule.h>'
    -I"$UP/config" -I"$FT/include" -I"$FT/src"
)
HB_FLAGS=(
    "${COMMON[@]}" -std=c++17 -fno-exceptions -fno-rtti -fno-threadsafe-statics -fvisibility-inlines-hidden
    -I"$HB" -I"$UP/config"
    # HarfBuzz's mutex is a pthread one with this; without it, outside of macOS, it's a std::mutex, which needs the C++ runtime.
    -DHAVE_PTHREAD
    '-DHB_EXTERN=__attribute__((visibility("default")))'
)
# CFLAGS and CXXFLAGS hold several flags.
# shellcheck disable=SC2206
FT_FLAGS+=(${CFLAGS:-})
# shellcheck disable=SC2206
HB_FLAGS+=(${CXXFLAGS:-})

FT_SOURCES=(
    # Base: the files FreeType's own CMake lists
    "$FT/src/base/ftsystem.c" "$FT/src/base/ftinit.c" "$FT/src/base/ftdebug.c" "$FT/src/base/ftbase.c" "$FT/src/base/ftbbox.c"
    "$FT/src/base/ftglyph.c" "$FT/src/base/ftbitmap.c" "$FT/src/base/ftmm.c" "$FT/src/base/ftstroke.c" "$FT/src/base/ftsynth.c"
    "$FT/src/base/ftfstype.c" "$FT/src/base/ftgasp.c"
    # Modules
    "$FT/src/truetype/truetype.c" "$FT/src/cff/cff.c" "$FT/src/sfnt/sfnt.c" "$FT/src/psaux/psaux.c" "$FT/src/psnames/psnames.c"
    "$FT/src/pshinter/pshinter.c" "$FT/src/smooth/smooth.c" "$FT/src/autofit/autofit.c"
)
HB_SOURCES=("$UP/config/fontlibs_harfbuzz.cc")

rm -rf "$OBJ_DIR"
mkdir -p "$OBJ_DIR/ft" "$OBJ_DIR/hb" "$LIB_DIR"
echo "Compiling ${#FT_SOURCES[@]} FreeType files with $("$CC" --version | head -n 1)"
echo "Compiling ${#HB_SOURCES[@]} HarfBuzz file with $("$CXX" --version | head -n 1)"

FT_OBJECTS=()
HB_OBJECTS=()
pids=()
wait_for_slot() {
    while [[ $(jobs -rp | wc -l) -ge $JOBS ]]; do
        sleep 0.1
    done
}
for src in "${FT_SOURCES[@]}"; do
    obj="$OBJ_DIR/ft/$(basename "${src%.c}").o"
    FT_OBJECTS+=("$obj")
    wait_for_slot
    "$CC" "${FT_FLAGS[@]}" -c "$src" -o "$obj" &
    pids+=($!)
done
for src in "${HB_SOURCES[@]}"; do
    obj="$OBJ_DIR/hb/$(basename "${src%.cc}").o"
    HB_OBJECTS+=("$obj")
    wait_for_slot
    "$CXX" "${HB_FLAGS[@]}" -c "$src" -o "$obj" &
    pids+=($!)
done
for pid in "${pids[@]}"; do
    wait "$pid" || die "compilation failed"
done

# Undefined symbols from the C++ runtime (libc++ or libstdc++): operator new/delete, __cxa_*, __gxx_*, std::.
# __cxa_atexit and __cxa_finalize, which register static destructors, are in the C library.
cxx_runtime_symbols() {
    nm -u "$@" 2>/dev/null | awk '{ print $NF }' |
        grep -E '^_{1,2}(Znw|Zna|Zdl|Zda|cxa_|gxx_|ZNSt|ZSt)' | grep -vE '^_{1,2}cxa_(atexit|finalize)$' | sort -u || true
}
runtime="$(cxx_runtime_symbols "${HB_OBJECTS[@]}")"
[[ -z "$runtime" ]] || die "HarfBuzz needs the C++ runtime, which the bindings do not link:
$runtime"

if [[ "$LINKAGE" != shared ]]; then
    rm -f "$LIB_DIR/libfreetype.a" "$LIB_DIR/libharfbuzz.a"
    ar rcs "$LIB_DIR/libfreetype.a" "${FT_OBJECTS[@]}"
    ar rcs "$LIB_DIR/libharfbuzz.a" "${HB_OBJECTS[@]}"
fi
# Linked with the C compiler driver, which adds no C++ runtime (unlike c++ without -nostdlib++, which GCC only has since version 13).
# HarfBuzz uses the C math and thread libraries on Linux, which the library names so that a program doesn't have to.
if [[ "$LINKAGE" != static ]]; then
    out="$LIB_DIR/libfontlibs.$SHARED_EXT"
    rm -f "$out"
    if [[ "$OS" == macos ]]; then
        "$CC" -dynamiclib -install_name @rpath/libfontlibs.dylib -Wl,-dead_strip "${FT_OBJECTS[@]}" "${HB_OBJECTS[@]}" -o "$out"
    else
        "$CC" -shared -Wl,-soname,libfontlibs.so -Wl,--gc-sections -Wl,--no-undefined "${FT_OBJECTS[@]}" "${HB_OBJECTS[@]}" \
            -lm -lpthread -o "$out"
    fi
fi
echo "Built in lib/$PLATFORM/:"
ls -lh "$LIB_DIR"/libfreetype.a "$LIB_DIR"/libharfbuzz.a "$LIB_DIR"/libfontlibs.* 2>/dev/null
