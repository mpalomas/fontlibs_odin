#!/usr/bin/env bash
# Checks that the bindings' structs have the sizes and field offsets of the C structs in the headers of upstream/: builds
# abi_check.c (CMake, with the compiler of the platform) and odin/main.odin, runs both and compares what they print. Run it on
# every platform: FreeType's long, for one, is 32 bits on 64-bit Windows and 64 bits elsewhere. Works in Git Bash on Windows.
#
#   tools/abi/check.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Odin wants the extension of an executable on Windows.
EXE=""
case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) EXE=".exe" ;; esac
OUT="$REPO/build/abi"
rm -rf "$OUT"
mkdir -p "$OUT"

cmake -S "$REPO/tools/abi" -B "$OUT/c" -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$OUT/c" --config Release >/dev/null
exe="$(find "$OUT/c" -type f \( -name abi_check -o -name abi_check.exe \) | head -n 1)"
[[ -n "$exe" ]] || { echo "error: the C program was not built" >&2; exit 1; }
"$exe" >"$OUT/c.txt"

# The Odin program imports the bindings, which need the libraries to exist but not to be linked: it calls nothing of them.
odin build "$REPO/tools/abi/odin" -out:"$OUT/abi_odin$EXE" >/dev/null
odin_exe="$(find "$OUT" -maxdepth 1 -type f \( -name abi_odin -o -name abi_odin.exe \) | head -n 1)"
[[ -n "$odin_exe" ]] || { echo "error: the Odin program was not built" >&2; exit 1; }
"$odin_exe" >"$OUT/odin.txt"

# Windows tools write CRLF.
tr -d '\r' <"$OUT/c.txt" >"$OUT/c.lf.txt"
tr -d '\r' <"$OUT/odin.txt" >"$OUT/odin.lf.txt"
if diff "$OUT/c.lf.txt" "$OUT/odin.lf.txt"; then
    echo "ABI check: the bindings match the headers ($(wc -l <"$OUT/c.lf.txt" | tr -d ' ') values)"
else
    echo "error: the bindings differ from the headers (C on the left, Odin on the right)" >&2
    exit 1
fi
