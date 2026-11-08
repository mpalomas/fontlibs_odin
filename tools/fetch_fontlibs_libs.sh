#!/usr/bin/env bash
# Downloads the prebuilt FreeType and HarfBuzz libraries that match the committed sources and configuration into
# lib/<os>-<arch>/, from the GitHub release named in upstream/release.env (written by .github/workflows/build-fontlibs.yml).
#
# Usage: tools/fetch_fontlibs_libs.sh [PLATFORM...]
#   PLATFORM  linux-x86_64 or macos-arm64 (default: this machine's)
#
# Checks the release's configuration (fontlibs_ftoption.h, fontlibs_ftmodule.h, fontlibs_harfbuzz.cc) and the versions of the
# sources against the committed ones, and the downloads against the release's SHA256SUMS. Uses gh when it is installed and
# logged in, else curl.
# Environment:
#   FONTLIBS_RELEASE_REPO  (default: mpalomas/fontlibs_odin)
#   FONTLIBS_RELEASE_URL   Base URL of the release downloads, for curl (default: the repository's releases)

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLUG="${FONTLIBS_RELEASE_REPO:-mpalomas/fontlibs_odin}"
BASE_URL="${FONTLIBS_RELEASE_URL:-https://github.com/$SLUG/releases/download}"
PIN="$REPO/upstream/release.env"
CONFIG=(fontlibs_ftoption.h fontlibs_ftmodule.h fontlibs_harfbuzz.cc)

die() {
    echo "error: $*" >&2
    exit 1
}

[[ -f "$PIN" ]] || die "no $PIN: the committed sources do not come from a release. Build the libraries with tools/build_fontlibs.sh"
TAG="$(sed -n 's/^RELEASE_TAG=//p' "$PIN")"
[[ -n "$TAG" ]] || die "no RELEASE_TAG in $PIN: no release matches the committed sources. Build the libraries with tools/build_fontlibs.sh"

if [[ $# -gt 0 ]]; then
    PLATFORMS=("$@")
else
    case "$(uname -s)" in
        Linux) os=linux ;;
        Darwin) os=macos ;;
        *) die "unsupported OS $(uname -s)" ;;
    esac
    case "$(uname -m)" in
        x86_64 | amd64) arch=x86_64 ;;
        arm64 | aarch64) arch=arm64 ;;
        *) die "unsupported architecture $(uname -m)" ;;
    esac
    PLATFORMS=("$os-$arch")
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FILES=("${CONFIG[@]}" sources.env SHA256SUMS)
for platform in "${PLATFORMS[@]}"; do
    FILES+=("fontlibs-$platform.tar.gz")
done

echo "Downloading ${FILES[*]} from release $TAG of $SLUG"
if [[ -z "${FONTLIBS_RELEASE_URL:-}" ]] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    patterns=()
    for f in "${FILES[@]}"; do
        patterns+=(--pattern "$f")
    done
    gh release download "$TAG" --repo "$SLUG" --dir "$TMP" "${patterns[@]}"
else
    for f in "${FILES[@]}"; do
        curl -fsSL --retry 3 -o "$TMP/$f" "$BASE_URL/$TAG/$f" || die "cannot download $f"
    done
fi
for f in "${FILES[@]}"; do
    [[ -f "$TMP/$f" ]] || die "release $TAG has no $f"
done

sha256() {
    if command -v sha256sum >/dev/null; then
        sha256sum "$1" | cut -d ' ' -f 1
    else
        shasum -a 256 "$1" | cut -d ' ' -f 1
    fi
}
for f in "${FILES[@]}"; do
    [[ "$f" != SHA256SUMS ]] || continue
    want="$(awk -v f="$f" '$2 == f || $2 == "*" f { print $1 }' "$TMP/SHA256SUMS")"
    [[ -n "$want" ]] || die "$f is not in the release's SHA256SUMS"
    [[ "$(sha256 "$TMP/$f")" == "$want" ]] || die "checksum mismatch for $f"
done

# The libraries must be built from the committed versions of FreeType and HarfBuzz, with the committed configuration.
for f in "${CONFIG[@]}"; do
    cmp -s "$TMP/$f" "$REPO/upstream/config/$f" ||
        die "upstream/config/$f differs from release $TAG's: the configuration changed since. Build the libraries with tools/build_fontlibs.sh"
done
grep -E '^(FREETYPE|HARFBUZZ)_' "$PIN" | cmp -s - "$TMP/sources.env" ||
    die "the versions in upstream/release.env differ from release $TAG's: the sources were updated since. Build the libraries with tools/build_fontlibs.sh"

for platform in "${PLATFORMS[@]}"; do
    # The archives hold lib/<platform>/<libraries>.
    tar -xzf "$TMP/fontlibs-$platform.tar.gz" -C "$REPO"
    echo "Extracted to lib/$platform/:"
    ls -lh "$REPO/lib/$platform/"
done
