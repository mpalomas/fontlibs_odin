package tests

// Smoke tests: the libraries are the versions the bindings are for, and FreeType and HarfBuzz work through them on a font with
// simple shapes (testdata/test.ttf, a 780 byte TrueType font built by hand: 1000 units per em; glyph 2, the character A,
// is a square 100 to 700 units right of the pen and 0 to 700 up, advance 800; glyph 3, B, advance 800; a kern table moves B 100
// units closer to a preceding A). At 10 pixels per em, A covers exactly 6 by 7 pixels.
//
//   odin test tests

import "core:c"
import "core:testing"
import ft "../freetype"
import hb "../harfbuzz"

test_font := #load("testdata/test.ttf")

@(test)
freetype_is_the_pinned_version :: proc(t: ^testing.T) {
	library: ft.Library
	testing.expect_value(t, ft.Init_FreeType(&library), ft.OK)
	defer ft.Done_FreeType(library)
	major, minor, patch: i32
	ft.Library_Version(library, &major, &minor, &patch)
	testing.expect_value(t, [3]i32{major, minor, patch}, [3]i32{2, 15, 0})
}

@(test)
harfbuzz_is_the_pinned_version :: proc(t: ^testing.T) {
	testing.expect_value(t, string(hb.version_string()), "15.1.0")
}

@(test)
freetype_loads_the_face_and_rasterizes_a_glyph :: proc(t: ^testing.T) {
	library: ft.Library
	testing.expect_value(t, ft.Init_FreeType(&library), ft.OK)
	defer ft.Done_FreeType(library)
	face: ft.Face
	testing.expect_value(t, ft.New_Memory_Face(library, raw_data(test_font), ft.Long(len(test_font)), 0, &face), ft.OK)
	defer ft.Done_Face(face)
	testing.expect_value(t, face.units_per_em, 1000)
	testing.expect_value(t, face.num_glyphs, 5)
	testing.expect_value(t, face.ascender, 800)
	testing.expect_value(t, string(face.family_name), "Unit Test")

	testing.expect_value(t, ft.Set_Pixel_Sizes(face, 0, 10), ft.OK)
	index := ft.Get_Char_Index(face, 'A')
	testing.expect_value(t, index, 2)
	testing.expect_value(t, ft.Load_Glyph(face, index, {.No_Hinting, .Render, .No_Bitmap}), ft.OK)
	slot := face.glyph
	testing.expect_value(t, slot.format, ft.Glyph_Format.Bitmap)
	testing.expect_value(t, slot.bitmap.width, 6)
	testing.expect_value(t, slot.bitmap.rows, 7)
	testing.expect_value(t, slot.bitmap.pixel_mode, ft.Pixel_Mode.Gray)
	testing.expect_value(t, slot.bitmap_left, 1)
	testing.expect_value(t, slot.bitmap_top, 7)
	testing.expect_value(t, slot.advance.x, 8 * 64) // 26.6 fixed point, unhinted
	for y in 0 ..< int(slot.bitmap.rows) {
		for x in 0 ..< int(slot.bitmap.width) {
			testing.expect_value(t, slot.bitmap.buffer[y * int(slot.bitmap.pitch) + x], 255)
		}
	}
}

@(test)
harfbuzz_shapes_with_the_kern_table :: proc(t: ^testing.T) {
	blob := hb.blob_create(raw_data(test_font), u32(len(test_font)), .Readonly, nil, nil)
	defer hb.blob_destroy(blob)
	face := hb.face_create(blob, 0)
	defer hb.face_destroy(face)
	font := hb.font_create(face)
	defer hb.font_destroy(font)
	hb.font_set_scale(font, 1000, 1000)
	testing.expect_value(t, hb.face_get_glyph_count(face), 5)

	buffer := hb.buffer_create()
	defer hb.buffer_destroy(buffer)
	text := "AB"
	hb.buffer_add_utf8(buffer, raw_data(text), i32(len(text)), 0, i32(len(text)))
	hb.buffer_guess_segment_properties(buffer)
	hb.shape(font, buffer, nil, 0)
	length: u32
	infos := hb.buffer_get_glyph_infos(buffer, &length)
	positions := hb.buffer_get_glyph_positions(buffer, &length)
	testing.expect_value(t, length, 2)
	testing.expect_value(t, [2]u32{infos[0].codepoint, infos[1].codepoint}, [2]u32{2, 3})
	testing.expect_value(t, [2]u32{infos[0].cluster, infos[1].cluster}, [2]u32{0, 1})
	// The pair's 100 units come off the two glyphs together: the advances and the second glyph's offset.
	testing.expect_value(t, positions[0].x_advance + positions[1].x_advance, 1500)
	testing.expect_value(t, positions[0].x_advance + positions[1].x_offset, 700)
}

@(test)
harfbuzz_rasterizes_an_outline_like_freetype :: proc(t: ^testing.T) {
	blob := hb.blob_create(raw_data(test_font), u32(len(test_font)), .Readonly, nil, nil)
	defer hb.blob_destroy(blob)
	face := hb.face_create(blob, 0)
	defer hb.face_destroy(face)
	font := hb.font_create(face)
	defer hb.font_destroy(font)
	hb.font_set_scale(font, 1000, 1000)

	draw := hb.raster_draw_create_or_fail()
	testing.expect(t, draw != nil)
	defer hb.raster_draw_destroy(draw)
	scale := f32(10) / 1000 // 10 pixels per em; y points down in an image
	hb.raster_draw_set_transform(draw, scale, 0, 0, -scale, 0, 0)
	extents: hb.Glyph_Extents
	testing.expect(t, bool(hb.font_get_glyph_extents(font, 2, &extents)))
	testing.expect(t, bool(hb.raster_draw_set_glyph_extents(draw, &extents)))
	testing.expect(t, bool(hb.raster_draw_glyph_or_fail(draw, font, 2)))
	image := hb.raster_draw_render(draw)
	testing.expect(t, image != nil)
	defer hb.raster_image_destroy(image)

	image_extents: hb.Raster_Extents
	hb.raster_image_get_extents(image, &image_extents)
	testing.expect_value(t, hb.raster_image_get_format(image), hb.Raster_Format.A8)
	testing.expect_value(t, image_extents.width, 6)
	testing.expect_value(t, image_extents.height, 7)
	testing.expect_value(t, image_extents.x_origin, 1)
	testing.expect_value(t, image_extents.y_origin, -7) // the top edge is 7 up from the baseline: y down
	pixels := hb.raster_image_get_buffer(image)
	for y in 0 ..< int(image_extents.height) {
		for x in 0 ..< int(image_extents.width) {
			value := pixels[y * int(image_extents.stride) + x]
			testing.expectf(t, value >= 253, "pixel %d, %d is %d, a fully covered pixel", x, y, value)
		}
	}
}

@(test)
freetype_emboldens_and_shears_an_outline :: proc(t: ^testing.T) {
	library: ft.Library
	testing.expect_value(t, ft.Init_FreeType(&library), ft.OK)
	defer ft.Done_FreeType(library)
	face: ft.Face
	testing.expect_value(t, ft.New_Memory_Face(library, raw_data(test_font), ft.Long(len(test_font)), 0, &face), ft.OK)
	defer ft.Done_Face(face)
	testing.expect_value(t, ft.Set_Pixel_Sizes(face, 0, 10), ft.OK)

	bitmap_size :: proc(face: ft.Face, embolden: ft.Pos, shear: ft.Fixed) -> (width, rows: c.uint) {
		assert(ft.Load_Glyph(face, 2, {.No_Hinting, .No_Bitmap}) == ft.OK)
		slot := face.glyph
		if embolden != 0 {
			assert(ft.Outline_EmboldenXY(&slot.outline, embolden, embolden) == ft.OK)
		}
		if shear != 0 {
			shear_matrix := ft.Matrix{xx = 0x10000, xy = shear, yx = 0, yy = 0x10000}
			ft.Outline_Transform(&slot.outline, &shear_matrix)
		}
		assert(ft.Render_Glyph(slot, .Normal) == ft.OK)
		return slot.bitmap.width, slot.bitmap.rows
	}
	plain_width, plain_rows := bitmap_size(face, 0, 0)
	bold_width, bold_rows := bitmap_size(face, 64, 0) // a pixel stronger
	italic_width, italic_rows := bitmap_size(face, 0, 0x4000) // a quarter: 7 pixels up lean 1.75 right
	testing.expect_value(t, [2]u32{plain_width, plain_rows}, [2]u32{6, 7})
	testing.expect(t, bold_width > plain_width && bold_rows > plain_rows, "emboldening grows the glyph both ways")
	testing.expect(t, italic_width > plain_width && italic_rows == plain_rows, "shearing widens it, and doesn't make it taller")
}

@(test)
harfbuzz_reports_the_direction_of_a_shaped_buffer_and_the_style_of_a_face :: proc(t: ^testing.T) {
	blob := hb.blob_create(raw_data(test_font), u32(len(test_font)), .Readonly, nil, nil)
	defer hb.blob_destroy(blob)
	face := hb.face_create(blob, 0)
	defer hb.face_destroy(face)
	font := hb.font_create(face)
	defer hb.font_destroy(font)
	hb.font_set_scale(font, 1000, 1000)

	direction_of :: proc(font: hb.Font, text: string) -> hb.Direction {
		buffer := hb.buffer_create()
		defer hb.buffer_destroy(buffer)
		hb.buffer_add_utf8(buffer, raw_data(text), i32(len(text)), 0, i32(len(text)))
		hb.buffer_guess_segment_properties(buffer)
		hb.shape(font, buffer, nil, 0)
		return hb.buffer_get_direction(buffer)
	}
	testing.expect_value(t, direction_of(font, "AB"), hb.Direction.LTR)
	testing.expect_value(t, direction_of(font, "אבג"), hb.Direction.RTL)

	// The face has no OS/2 table: no italic, and a default weight.
	testing.expect_value(t, hb.style_get_value(font, .Italic), 0)
	testing.expect(t, hb.style_get_value(font, .Weight) > 0, "a weight, even when the font doesn't say")
}
