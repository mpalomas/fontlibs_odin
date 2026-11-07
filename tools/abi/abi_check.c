/* Prints the size and the field offsets of the C structs the bindings declare, one "name value" per line, in the order of
 * odin/main.odin, which prints the same names from the Odin structs. tools/abi/check.sh builds both and compares them: a
 * mismatch means a binding doesn't match the library's headers (e.g. FreeType's long is 32 bits on 64-bit Windows). */
#include <stddef.h>
#include <stdio.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H

#include "hb.h"
#include "hb-raster.h"

#define SIZE(T) printf(#T " size %zu\n", sizeof(T))
#define OFFSET(T, field) printf(#T "." #field " %zu\n", offsetof(T, field))

int main(void) {
    SIZE(FT_Vector);
    OFFSET(FT_Vector, x);
    OFFSET(FT_Vector, y);

    SIZE(FT_BBox);
    OFFSET(FT_BBox, xMin);
    OFFSET(FT_BBox, yMin);
    OFFSET(FT_BBox, xMax);
    OFFSET(FT_BBox, yMax);

    SIZE(FT_Matrix);
    OFFSET(FT_Matrix, xx);
    OFFSET(FT_Matrix, xy);
    OFFSET(FT_Matrix, yx);
    OFFSET(FT_Matrix, yy);

    SIZE(FT_Generic);
    OFFSET(FT_Generic, data);
    OFFSET(FT_Generic, finalizer);

    SIZE(FT_ListRec);
    OFFSET(FT_ListRec, head);
    OFFSET(FT_ListRec, tail);

    SIZE(FT_Glyph_Metrics);
    OFFSET(FT_Glyph_Metrics, width);
    OFFSET(FT_Glyph_Metrics, height);
    OFFSET(FT_Glyph_Metrics, horiBearingX);
    OFFSET(FT_Glyph_Metrics, horiBearingY);
    OFFSET(FT_Glyph_Metrics, horiAdvance);
    OFFSET(FT_Glyph_Metrics, vertBearingX);
    OFFSET(FT_Glyph_Metrics, vertBearingY);
    OFFSET(FT_Glyph_Metrics, vertAdvance);

    SIZE(FT_Size_Metrics);
    OFFSET(FT_Size_Metrics, x_ppem);
    OFFSET(FT_Size_Metrics, y_ppem);
    OFFSET(FT_Size_Metrics, x_scale);
    OFFSET(FT_Size_Metrics, y_scale);
    OFFSET(FT_Size_Metrics, ascender);
    OFFSET(FT_Size_Metrics, descender);
    OFFSET(FT_Size_Metrics, height);
    OFFSET(FT_Size_Metrics, max_advance);

    SIZE(FT_SizeRec);
    OFFSET(FT_SizeRec, face);
    OFFSET(FT_SizeRec, generic);
    OFFSET(FT_SizeRec, metrics);
    OFFSET(FT_SizeRec, internal);

    SIZE(FT_Bitmap);
    OFFSET(FT_Bitmap, rows);
    OFFSET(FT_Bitmap, width);
    OFFSET(FT_Bitmap, pitch);
    OFFSET(FT_Bitmap, buffer);
    OFFSET(FT_Bitmap, num_grays);
    OFFSET(FT_Bitmap, pixel_mode);
    OFFSET(FT_Bitmap, palette_mode);
    OFFSET(FT_Bitmap, palette);

    SIZE(FT_Outline);
    OFFSET(FT_Outline, n_contours);
    OFFSET(FT_Outline, n_points);
    OFFSET(FT_Outline, points);
    OFFSET(FT_Outline, tags);
    OFFSET(FT_Outline, contours);
    OFFSET(FT_Outline, flags);

    SIZE(FT_GlyphSlotRec);
    OFFSET(FT_GlyphSlotRec, library);
    OFFSET(FT_GlyphSlotRec, face);
    OFFSET(FT_GlyphSlotRec, next);
    OFFSET(FT_GlyphSlotRec, glyph_index);
    OFFSET(FT_GlyphSlotRec, generic);
    OFFSET(FT_GlyphSlotRec, metrics);
    OFFSET(FT_GlyphSlotRec, linearHoriAdvance);
    OFFSET(FT_GlyphSlotRec, linearVertAdvance);
    OFFSET(FT_GlyphSlotRec, advance);
    OFFSET(FT_GlyphSlotRec, format);
    OFFSET(FT_GlyphSlotRec, bitmap);
    OFFSET(FT_GlyphSlotRec, bitmap_left);
    OFFSET(FT_GlyphSlotRec, bitmap_top);
    OFFSET(FT_GlyphSlotRec, outline);
    OFFSET(FT_GlyphSlotRec, num_subglyphs);
    OFFSET(FT_GlyphSlotRec, subglyphs);
    OFFSET(FT_GlyphSlotRec, control_data);
    OFFSET(FT_GlyphSlotRec, control_len);
    OFFSET(FT_GlyphSlotRec, lsb_delta);
    OFFSET(FT_GlyphSlotRec, rsb_delta);
    OFFSET(FT_GlyphSlotRec, other);
    OFFSET(FT_GlyphSlotRec, internal);

    SIZE(FT_FaceRec);
    OFFSET(FT_FaceRec, num_faces);
    OFFSET(FT_FaceRec, face_index);
    OFFSET(FT_FaceRec, face_flags);
    OFFSET(FT_FaceRec, style_flags);
    OFFSET(FT_FaceRec, num_glyphs);
    OFFSET(FT_FaceRec, family_name);
    OFFSET(FT_FaceRec, style_name);
    OFFSET(FT_FaceRec, num_fixed_sizes);
    OFFSET(FT_FaceRec, available_sizes);
    OFFSET(FT_FaceRec, num_charmaps);
    OFFSET(FT_FaceRec, charmaps);
    OFFSET(FT_FaceRec, generic);
    OFFSET(FT_FaceRec, bbox);
    OFFSET(FT_FaceRec, units_per_EM);
    OFFSET(FT_FaceRec, ascender);
    OFFSET(FT_FaceRec, descender);
    OFFSET(FT_FaceRec, height);
    OFFSET(FT_FaceRec, max_advance_width);
    OFFSET(FT_FaceRec, max_advance_height);
    OFFSET(FT_FaceRec, underline_position);
    OFFSET(FT_FaceRec, underline_thickness);
    OFFSET(FT_FaceRec, glyph);
    OFFSET(FT_FaceRec, size);
    OFFSET(FT_FaceRec, charmap);
    OFFSET(FT_FaceRec, driver);
    OFFSET(FT_FaceRec, memory);
    OFFSET(FT_FaceRec, stream);
    OFFSET(FT_FaceRec, sizes_list);
    OFFSET(FT_FaceRec, autohint);
    OFFSET(FT_FaceRec, extensions);
    OFFSET(FT_FaceRec, internal);

    /* The enums the bindings use as fields or parameters of the same size. */
    SIZE(FT_Error);
    SIZE(FT_Glyph_Format);
    SIZE(FT_Render_Mode);
    SIZE(FT_Int32);

    SIZE(hb_glyph_info_t);
    OFFSET(hb_glyph_info_t, codepoint);
    OFFSET(hb_glyph_info_t, mask);
    OFFSET(hb_glyph_info_t, cluster);
    OFFSET(hb_glyph_info_t, var1);
    OFFSET(hb_glyph_info_t, var2);

    SIZE(hb_glyph_position_t);
    OFFSET(hb_glyph_position_t, x_advance);
    OFFSET(hb_glyph_position_t, y_advance);
    OFFSET(hb_glyph_position_t, x_offset);
    OFFSET(hb_glyph_position_t, y_offset);
    OFFSET(hb_glyph_position_t, var);

    SIZE(hb_glyph_extents_t);
    OFFSET(hb_glyph_extents_t, x_bearing);
    OFFSET(hb_glyph_extents_t, y_bearing);
    OFFSET(hb_glyph_extents_t, width);
    OFFSET(hb_glyph_extents_t, height);

    SIZE(hb_feature_t);
    OFFSET(hb_feature_t, tag);
    OFFSET(hb_feature_t, value);
    OFFSET(hb_feature_t, start);
    OFFSET(hb_feature_t, end);

    SIZE(hb_variation_t);
    OFFSET(hb_variation_t, tag);
    OFFSET(hb_variation_t, value);

    SIZE(hb_raster_extents_t);
    OFFSET(hb_raster_extents_t, x_origin);
    OFFSET(hb_raster_extents_t, y_origin);
    OFFSET(hb_raster_extents_t, width);
    OFFSET(hb_raster_extents_t, height);
    OFFSET(hb_raster_extents_t, stride);

    SIZE(hb_bool_t);
    SIZE(hb_codepoint_t);
    SIZE(hb_position_t);
    SIZE(hb_tag_t);
    SIZE(hb_color_t);
    SIZE(hb_direction_t);
    SIZE(hb_memory_mode_t);
    SIZE(hb_raster_format_t);
    return 0;
}
