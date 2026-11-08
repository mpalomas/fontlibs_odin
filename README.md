# fontlibs_odin

[FreeType](https://freetype.org) and [HarfBuzz](https://harfbuzz.github.io) for Odin: pinned sources, static libraries built by the scripts here, and hand-written bindings for the part of each library that text rendering needs. Only a subset of each is bound and built:

- **FreeType 2.15.0:** TrueType and CFF fonts (also in OpenType and collection files), the auto-hinter, the smooth rasterizer. No zlib, PNG or other formats. About 0.6 MB.
- **HarfBuzz 15.1.0:** the shaper (OpenType and AAT), and the raster library (outlines to A8, COLRv0 and COLRv1 color glyphs to BGRA32). No libpng, no platform shapers (CoreText, DirectWrite, ...). About 2 MB.

Used as a collection: `-collection:fontlibs=<path to this directory>`, then

```odin
import ft "fontlibs:freetype"
import hb "fontlibs:harfbuzz"
```

The C prefixes are stripped (`ft.Load_Glyph`, `hb.shape`). Link directives find the libraries in `lib/<os>-<arch>/`.

## What is bound

| | |
|---|---|
| `freetype` | `Init_FreeType`, `Done_FreeType`, `Library_Version`, `New_Memory_Face`, `Done_Face`, `Set_Char_Size`, `Set_Pixel_Sizes`, `Set_Transform`, `Get_Char_Index`, `Load_Glyph`, `Render_Glyph`, `Outline_Translate`, `Outline_Transform`, `Outline_EmboldenXY`, with the face, glyph slot, bitmap and outline structs and the load flags. |
| `harfbuzz` | Blobs, faces, fonts (scale, variations, nominal glyphs, glyph extents and advances, style values); buffers (UTF-8 text, direction, segment properties) and `shape` with features; color glyph queries (`ot_color_has_layers / paint / png / svg`, `ot_color_glyph_reference_png`); the raster library: `raster_draw_*` for outlines and `raster_paint_*` for COLRv0 and COLRv1 glyphs, and `raster_image_*` for the results. |

More can be added: the files are plain `foreign` blocks. The struct layouts are checked against the C headers (see below).

## Building

```sh
tools/build_fontlibs.sh      # Linux, macOS: lib/<os>-<arch>/libfreetype.a and libharfbuzz.a (needs a C and a C++ compiler)
tools/build_fontlibs.ps1     # Windows (PowerShell 7.4, CMake, Visual Studio): lib/windows-<arch>/freetype.lib and harfbuzz.lib
tools/abi/check.sh           # the bindings' structs and constants against the C headers
odin test tests              # smoke tests: the pinned versions, loading, shaping, rasterizing
tools/import_sources.sh FREETYPE_TARBALL HARFBUZZ_TARBALL   # only to update the pinned sources in upstream/
```

FreeType is built with `upstream/config/fontlibs_ftoption.h` and `fontlibs_ftmodule.h`, HarfBuzz from `upstream/config/fontlibs_harfbuzz.cc`, a single translation unit. Both are compiled position-independent with `-ffunction-sections` and `-fdata-sections`, so a program's linker drops what it doesn't use. HarfBuzz needs no C++ runtime (no exceptions, RTTI or thread-safe statics; the Unix script checks the undefined symbols, and the pthread mutex is selected with `-DHAVE_PTHREAD`). The Windows build is `CMakeLists.txt`: MSVC, the static C runtime (`/MT`), no default library directives.

## What works

Built and tested in `.github/workflows/ci.yml` on **Linux x86_64, macOS arm64 and Windows x86_64**: the libraries build, the ABI check passes (156 values: struct sizes, field offsets and enum constants), and the seven smoke tests pass (the library versions, loading a face and rasterizing a glyph with FreeType, shaping with a kern table, HarfBuzz's rasterizer against FreeType's, embolden and shear, text direction and a face's style). The built libraries are kept as artifacts of each run.

Tried by hand on macOS arm64 with real fonts:

| | |
|---|---|
| Shaping | Kerning through GPOS (Roboto, Arial). HarfBuzz shapes Apple Color Emoji's family (ZWJ), flag, keycap, skin tone, tag flag and variation selector sequences to **one glyph each** through the AAT `morx` table: no CoreText needed. |
| Outlines | `hb_raster_draw` matches FreeType unhinted: the same 12x12 bitmap and origin for Arial 'A' at 16 px, ink within 0.5%. |
| Hinting | FreeType light hinting rounds advances (Arial 16 px 'A': 11.00 against 10.67 unhinted) and changes ink by about 3%: take advances from HarfBuzz, not from hinted glyphs. |
| COLRv0 | `hb_raster_paint` composites Twemoji correctly, at several sizes and with a subpixel offset in the transform. |
| COLRv1 | Noto Color Emoji paints correctly: faces, flags with gradients, skin tones, sequences shaped to one glyph. |
| sbix bitmaps | `hb_raster_paint` does **not** draw them (it returns false: there is no libpng). `ot_color_glyph_reference_png` returns the PNG (160x160 for Apple Color Emoji's largest strike), which you decode yourself, for example with `core:image/png`. |
| Format detection | `ot_color_has_layers / paint / png` tell COLRv0, COLRv1 and sbix/CBDT apart. Noto's current font also has a 20 MB `SVG ` table, which is not rendered. |

## What has not been tested

- **CBDT** bitmap fonts: no CBDT font was at hand. They go through the same `ot_color_glyph_reference_png` path as sbix, which works.
- **Apple's `flip` glyphs** (an sbix graphic type): HarfBuzz doesn't handle them, so such a glyph has no PNG.
- **Real fonts on Linux and Windows:** the CI there runs only the smoke tests, on a font of simple shapes. Light hinting at 11 to 16 px next to native text has not been looked at on either.
- **Other targets:** Linux arm64, macOS x86_64 and Windows arm64 are not built by CI. The scripts name the output directory after the machine's architecture and should work, but have not been run.
- **Variable fonts:** `font_set_variations` is bound, but nothing here exercises it.
- The FreeType tarball's PGP signature was not checked when the sources were imported; the pinned SHA-256 values in `upstream/release.env` and `tools/import_sources.sh` come from the downloads.
- The COLRv1 family glyph of Noto Color Emoji paints as a pale tile with dark silhouettes. That is probably the font's design, but it has not been compared with a reference render.

## Licenses

FreeType is under the FreeType License (`upstream/freetype/docs/FTL.TXT`), which asks programs that use it to credit it in their documentation: "Portions of this software are copyright © The FreeType Project (www.freetype.org). All rights reserved." HarfBuzz is under the "Old MIT" license (`upstream/harfbuzz/COPYING`). The bindings and scripts here are MIT.
