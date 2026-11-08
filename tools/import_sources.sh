#!/usr/bin/env bash
# Imports the FreeType and HarfBuzz sources this repository builds into upstream/, from the release tarballs, and writes the pin
# (upstream/release.env). Only what the build needs is kept, so the repository stays small.
#
# Usage: tools/import_sources.sh FREETYPE_TARBALL HARFBUZZ_TARBALL
#
# The tarballs are checked against the SHA256 values below: update them together with the versions.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FT_VERSION=2.15.0
FT_SHA256=93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5
HB_VERSION=15.1.0
HB_SHA256=0fc7c565443a5f4be7da65ac5ee5bd737d9b158dc908708b7689a0a5796b0c8d

die() {
    echo "error: $*" >&2
    exit 1
}

sha256() {
    if command -v sha256sum >/dev/null; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}

[[ $# -eq 2 ]] || die "usage: tools/import_sources.sh FREETYPE_TARBALL HARFBUZZ_TARBALL"
FT_TAR="$1"
HB_TAR="$2"
[[ "$(sha256 "$FT_TAR")" == "$FT_SHA256" ]] || die "$FT_TAR is not FreeType $FT_VERSION (checksum mismatch)"
[[ "$(sha256 "$HB_TAR")" == "$HB_SHA256" ]] || die "$HB_TAR is not HarfBuzz $HB_VERSION (checksum mismatch)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/ft" "$TMP/hb"
tar -xJf "$FT_TAR" -C "$TMP/ft"
tar -xJf "$HB_TAR" -C "$TMP/hb"
FT="$TMP/ft/freetype-$FT_VERSION"
HB="$TMP/hb/harfbuzz-$HB_VERSION"

rm -rf "$REPO/upstream/freetype" "$REPO/upstream/harfbuzz"
mkdir -p "$REPO/upstream/freetype/src" "$REPO/upstream/freetype/docs" "$REPO/upstream/harfbuzz/src"

# FREETYPE: the headers and the modules in config/ftmodule.h: TrueType and CFF fonts, the auto-hinter, the smooth rasterizer.
cp -R "$FT/include" "$REPO/upstream/freetype/include"
for module in base truetype cff sfnt psaux psnames pshinter smooth autofit; do
    cp -R "$FT/src/$module" "$REPO/upstream/freetype/src/$module"
done
cp "$FT/LICENSE.TXT" "$REPO/upstream/freetype/LICENSE.TXT"
cp "$FT/docs/FTL.TXT" "$REPO/upstream/freetype/docs/FTL.TXT"

# HARFBUZZ: every header (the shaper includes more of them than it uses), and the sources config/fontlibs_harfbuzz.cc includes: the
# shaper and the raster library. Not the subsetter, the GPU library, or the platform shapers.
cp "$HB/COPYING" "$REPO/upstream/harfbuzz/COPYING"
cp -R "$HB/src/OT" "$REPO/upstream/harfbuzz/src/OT"
cp "$HB"/src/*.hh "$HB"/src/*.h "$REPO/upstream/harfbuzz/src/"
while IFS= read -r f; do
    case "$f" in
    OT/*) ;; # copied with the directory
    *) cp "$HB/src/$f" "$REPO/upstream/harfbuzz/src/$f" ;;
    esac
done < <(sed -n 's/^#include "\(.*\.cc\)"$/\1/p' "$REPO/upstream/config/fontlibs_harfbuzz.cc")

cat >"$REPO/upstream/release.env" <<EOF
# The sources in upstream/, written by tools/import_sources.sh.
FREETYPE_VERSION=$FT_VERSION
FREETYPE_SHA256=$FT_SHA256
HARFBUZZ_VERSION=$HB_VERSION
HARFBUZZ_SHA256=$HB_SHA256
EOF
echo "Imported FreeType $FT_VERSION and HarfBuzz $HB_VERSION into upstream/"
du -sh "$REPO/upstream/freetype" "$REPO/upstream/harfbuzz"
