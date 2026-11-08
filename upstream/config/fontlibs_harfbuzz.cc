// The HarfBuzz sources this repository builds, as one translation unit: harfbuzz.cc without the platform shapers (CoreText, DirectWrite,
// GDI, Uniscribe, FreeType, GLib, Graphite, WASM), plus the raster library. Written from harfbuzz.cc of the pinned release.
//
// Features this build leaves out, set here so that every platform and both library kinds are built the same: what only shaping
// for subsetting, debugging, environment variables, files, vertical text, the math table, glyph names and the deprecated API
// need. Kept: OpenType and AAT layout, variations, styles, colour (COLR, bitmaps, paint), drawing, and the legacy kern table.
// HB_OPTIMIZE_SIZE picks the smaller code where HarfBuzz has two. The macros are those of HB_LEAN that these libraries can do
// without; HB_LEAN itself also removes variations, styles and colour.
#ifndef NDEBUG
#define NDEBUG
#endif
#define HB_OPTIMIZE_SIZE
#define HB_DISABLE_DEPRECATED
#define HB_NO_ATEXIT
#define HB_NO_BUFFER_MESSAGE
#define HB_NO_BUFFER_SERIALIZE
#define HB_NO_BUFFER_VERIFY
#define HB_NO_ERRNO
#define HB_NO_GETENV
#define HB_NO_SETLOCALE
#define HB_NO_MMAP
#define HB_NO_OPEN
#define HB_NO_FACE_COLLECT_UNICODES
#define HB_NO_LAYOUT_COLLECT_GLYPHS
#define HB_NO_LAYOUT_RARELY_USED
#define HB_NO_LAYOUT_UNUSED
#define HB_NO_MATH
#define HB_NO_META
#define HB_NO_VERTICAL
#define HB_NO_OT_FONT_GLYPH_NAMES
#define HB_NO_SUBSET_DEPEND

#include "OT/Var/VARC/VARC.cc"
#include "hb-aat-layout.cc"
#include "hb-aat-map.cc"
#include "hb-blob.cc"
#include "hb-buffer-serialize.cc"
#include "hb-buffer-verify.cc"
#include "hb-buffer.cc"
#include "hb-common.cc"
#include "hb-draw.cc"
#include "hb-face-builder.cc"
#include "hb-face.cc"
#include "hb-fallback-shape.cc"
#include "hb-font.cc"
#include "hb-map.cc"
#include "hb-number.cc"
#include "hb-ot-cff1-table.cc"
#include "hb-ot-cff2-table.cc"
#include "hb-ot-color.cc"
#include "hb-ot-face.cc"
#include "hb-ot-fetch.cc"
#include "hb-ot-font.cc"
#include "hb-ot-layout.cc"
#include "hb-ot-map.cc"
#include "hb-ot-math.cc"
#include "hb-ot-meta.cc"
#include "hb-ot-metrics.cc"
#include "hb-ot-name.cc"
#include "hb-ot-shape-fallback.cc"
#include "hb-ot-shape-normalize.cc"
#include "hb-ot-shape.cc"
#include "hb-ot-shaper-arabic.cc"
#include "hb-ot-shaper-default.cc"
#include "hb-ot-shaper-hangul.cc"
#include "hb-ot-shaper-hebrew.cc"
#include "hb-ot-shaper-indic-table.cc"
#include "hb-ot-shaper-indic.cc"
#include "hb-ot-shaper-khmer.cc"
#include "hb-ot-shaper-myanmar.cc"
#include "hb-ot-shaper-syllabic.cc"
#include "hb-ot-shaper-thai.cc"
#include "hb-ot-shaper-use.cc"
#include "hb-ot-shaper-vowel-constraints.cc"
#include "hb-ot-tag.cc"
#include "hb-ot-var.cc"
#include "hb-outline.cc"
#include "hb-paint-bounded.cc"
#include "hb-paint-extents.cc"
#include "hb-paint.cc"
#include "hb-set.cc"
#include "hb-shape-plan.cc"
#include "hb-shape.cc"
#include "hb-shaper.cc"
#include "hb-static.cc"
#include "hb-style.cc"
#include "hb-ucd.cc"
#include "hb-unicode.cc"
#include "hb-raster-image.cc"
#include "hb-raster-draw.cc"
#include "hb-raster-paint.cc"
