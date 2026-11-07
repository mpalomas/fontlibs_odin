# fontlibs_odin

FreeType and HarfBuzz for Odin, built for Owin's font rendering (`font/` and `xgpu/text/` in the Owin repository). Only a subset of each library is bound and built:

- **FreeType 2.15.0:** TrueType and CFF fonts, the auto-hinter, the smooth rasterizer. No zlib, PNG or other formats. About 0.6 MB.
- **HarfBuzz 15.1.0:** the shaper (OpenType and AAT), and the raster library (outlines to A8, COLRv0 and COLRv1 colour glyphs to BGRA32). No libpng, no platform shapers. About 2 MB.

Used as a collection: `-collection:fontlibs=deps/fontlibs_odin`, then `import "fontlibs:freetype"` and `import "fontlibs:harfbuzz"`.

## Building

```sh
tools/import_sources.sh FREETYPE_TARBALL HARFBUZZ_TARBALL   # only to update the pinned sources in upstream/
tools/build_fontlibs.sh                                     # lib/<os>-<arch>/libfreetype.a and libharfbuzz.a
odin run tools/spike -- <output directory>                  # the Phase 0 checks below
```

Built on macOS arm64 only so far. The Linux path of the script is untested, and `build_fontlibs.ps1` (Windows) doesn't exist yet. The FreeType tarball's PGP signature was not checked (no `gpg` here): the pinned SHA-256 values in `tools/import_sources.sh` come from the downloads.

## Phase 0 results (macOS 26, Apple clang, arm64)

| Check | Result |
|---|---|
| Build | Both libraries compile in a few seconds. HarfBuzz needs no C++ runtime (the script checks the undefined symbols). |
| Hinting | FreeType light hinting rounds advances (Arial 16 px 'A': 11.00 against 10.67 unhinted) and changes ink by about 3%. **Advances must come from HarfBuzz, never from hinted glyphs.** |
| Kerning | Works through GPOS in Roboto and Arial. |
| Apple Color Emoji sequences | HarfBuzz shapes family ZWJ, flag, keycap, skin tone, England tag flag and VS16 heart to **one glyph each** through `morx`. No CoreText needed. |
| sbix bitmaps | `hb_raster_paint` does **not** draw them (no libpng): it returns false. `hb_ot_color_glyph_reference_png` returns the PNG (160x160 for the largest strike) and `core:image/png` decodes it. |
| COLRv0 (Twemoji) | `hb_raster_paint` composites correctly at 16 and 64 px, with a subpixel offset in the transform. |
| COLRv1 (Noto Color Emoji from google/fonts) | Smile, France flag (gradients) and a skin-tone thumbs-up paint correctly. The family glyph paints as a pale tile with black silhouettes: probably Noto's design, **not yet compared against a reference render**. GSUB sequences shape to one glyph each. |
| Outline rasterizer | `hb_raster_draw` matches FreeType unhinted: same 12x12 bitmap and origin for Arial 'A' at 16 px, ink within 0.5%. FreeType is kept for hinting, embolden and stroking. |
| Format detection | `hb_ot_color_has_layers / paint / png` tell COLRv0, COLRv1 and sbix/CBDT apart. Noto's current font also has a 20 MB `SVG ` table, which we don't render. |

## Not checked yet

- CBDT: no CBDT font was available (Noto's current build is COLRv1).
- Apple's `flip` glyphs (sbix graphic type `flip`, which HarfBuzz doesn't handle).
- Light hinting at 11 to 16 px next to native text on Windows and Linux.
- Linux and Windows builds, and ABI layout checks of the hand-written structs against the C headers.
- Glyph upload timing on Dawn and wgpu-native.

## Licences

FreeType is under the FreeType License (`upstream/freetype/docs/FTL.TXT`), which asks programs that use it to credit it in their documentation. HarfBuzz is under the "Old MIT" licence (`upstream/harfbuzz/COPYING`). The bindings and scripts here are MIT.
