// Phase 0 spike: checks what FreeType and HarfBuzz do on real system fonts before the font package is built on them.
//
//   odin run tools/spike -- <output directory>
package main

import "core:fmt"
import "core:image"
import "core:image/png"
import "core:mem/virtual"
import "core:os"
import ft "../../freetype"
import hb "../../harfbuzz"

ARIAL :: "/System/Library/Fonts/Supplemental/Arial.ttf"
APPLE_EMOJI :: "/System/Library/Fonts/Apple Color Emoji.ttc"
TWEMOJI :: "/Users/mpalomas/dev/c++/sokol-samples/sapp/data/twemoji.ttf"
ROBOTO :: "/Users/mpalomas/dev/c++/bgfx/examples/runtime/font/roboto-regular.ttf"
NOTO_EMOJI :: "/private/tmp/claude-501/-Users-mpalomas-dev-odin-owin/7f95e612-c819-4985-8bba-dd730518ade0/scratchpad/dl-notoemoji/NotoColorEmoji-Regular.ttf"

out_dir: string

map_font :: proc(path: string) -> (data: []u8, ok: bool) {
	mapped, err := virtual.map_file_from_path(path, {.Read})
	if err != nil || raw_data(mapped) == nil {
		fmt.printfln("  cannot map %s: %v", path, err)
		return nil, false
	}
	return mapped, true
}

// save_bgra writes premultiplied BGRA pixels over a gray background, so the alpha shows.
save_bgra :: proc(name: string, buffer: [^]u8, width, height, stride: int, a8 := false) {
	if width == 0 || height == 0 {
		fmt.printfln("  %s: empty image, not saved", name)
		return
	}
	img := new(image.Image, context.temp_allocator)
	img.width, img.height, img.channels, img.depth = width, height, 3, 8
	resize(&img.pixels, width * height * 3)
	defer delete(img.pixels)
	for y in 0 ..< height {
		for x in 0 ..< width {
			o := y * stride + x * (1 if a8 else 4)
			r, g, b, a: int
			if a8 {
				r, g, b, a = int(buffer[o]), int(buffer[o]), int(buffer[o]), int(buffer[o])
			} else {
				b, g, r, a = int(buffer[o]), int(buffer[o + 1]), int(buffer[o + 2]), int(buffer[o + 3])
			}
			bg := 64
			d := (y * width + x) * 3
			img.pixels[d] = u8(min(255, r + bg * (255 - a) / 255))
			img.pixels[d + 1] = u8(min(255, g + bg * (255 - a) / 255))
			img.pixels[d + 2] = u8(min(255, b + bg * (255 - a) / 255))
		}
	}
	path := fmt.tprintf("%s/%s.png", out_dir, name)
	if err := png.save_to_file(path, img); err != nil {
		fmt.printfln("  cannot save %s: %v", path, err)
	} else {
		fmt.printfln("  saved %s (%dx%d)", path, width, height)
	}
}

ink :: proc(bitmap: ft.Bitmap) -> (sum: int) {
	for y in 0 ..< int(bitmap.rows) {
		for x in 0 ..< int(bitmap.width) {
			sum += int(bitmap.buffer[y * int(bitmap.pitch) + x])
		}
	}
	return
}

freetype_check :: proc() {
	fmt.println("FREETYPE: Arial 'A' at 16 px")
	data, ok := map_font(ARIAL)
	if !ok {
		return
	}
	library: ft.Library
	assert(ft.Init_FreeType(&library) == ft.OK)
	major, minor, patch: i32
	ft.Library_Version(library, &major, &minor, &patch)
	fmt.printfln("  FreeType %d.%d.%d", major, minor, patch)
	face: ft.Face
	if err := ft.New_Memory_Face(library, raw_data(data), ft.Long(len(data)), 0, &face); err != ft.OK {
		fmt.printfln("  New_Memory_Face failed: %d", err)
		return
	}
	fmt.printfln("  %s %s, %d glyphs, upem %d", face.family_name, face.style_name, face.num_glyphs, face.units_per_em)
	ft.Set_Pixel_Sizes(face, 0, 16)
	index := ft.Get_Char_Index(face, 'A')
	for variant in ([]struct {
		name:  string,
		flags: ft.Load_Flags,
	}{{"none", {.No_Hinting, .Render}}, {"light", {.Render} | ft.load_target(.Light)}, {"normal", {.Render}}}) {
		assert(ft.Load_Glyph(face, index, variant.flags) == ft.OK)
		slot := face.glyph
		b := slot.bitmap
		fmt.printfln(
			"  hinting %-6s bitmap %dx%d left %d top %d advance %.2f ink %d",
			variant.name, b.width, b.rows, slot.bitmap_left, slot.bitmap_top, f32(slot.advance.x) / 64, ink(b),
		)
		if variant.name == "light" {
			save_bgra("freetype_light_A", b.buffer, int(b.width), int(b.rows), int(b.pitch), true)
		}
	}
	ft.Done_Face(face)
	ft.Done_FreeType(library)
}

shape :: proc(font: hb.Font, text: string) -> (infos: []hb.Glyph_Info, positions: []hb.Glyph_Position) {
	buffer := hb.buffer_create()
	hb.buffer_add_utf8(buffer, raw_data(text), i32(len(text)), 0, i32(len(text)))
	hb.buffer_guess_segment_properties(buffer)
	hb.shape(font, buffer, nil, 0)
	n: u32
	i := hb.buffer_get_glyph_infos(buffer, &n)
	p := hb.buffer_get_glyph_positions(buffer, &n)
	infos = make([]hb.Glyph_Info, n, context.temp_allocator)
	positions = make([]hb.Glyph_Position, n, context.temp_allocator)
	copy(infos, i[:n])
	copy(positions, p[:n])
	hb.buffer_destroy(buffer)
	return
}

make_font :: proc(data: []u8, index: u32) -> (font: hb.Font, upem: u32) {
	blob := hb.blob_create(raw_data(data), u32(len(data)), .Readonly, nil, nil)
	face := hb.face_create(blob, index)
	upem = hb.face_get_upem(face)
	font = hb.font_create(face)
	hb.font_set_scale(font, i32(upem), i32(upem))
	return
}

shaping_check :: proc() {
	fmt.println("HARFBUZZ: kerning (pair advance sum vs the glyphs alone)")
	for path in ([]string{ROBOTO, ARIAL}) {
		data, ok := map_font(path)
		if !ok {
			continue
		}
		font, upem := make_font(data, 0)
		fmt.printfln("  %s (HarfBuzz %s, upem %d)", path, hb.version_string(), upem)
		for pair in ([]string{"AV", "To", "Te", "r.", "LT", "fi"}) {
			infos, positions := shape(font, pair)
			total, alone := 0, 0
			for p in positions {
				total += int(p.x_advance)
			}
			for r in pair {
				single, single_positions := shape(font, fmt.tprintf("%c", r))
				_ = single
				alone += int(single_positions[0].x_advance)
			}
			fmt.printfln("    %q: %d glyphs, advance %d, alone %d, difference %d", pair, len(infos), total, alone, total - alone)
		}
	}
}

emoji_check :: proc() {
	fmt.println("HARFBUZZ + APPLE COLOR EMOJI: sequences (the font has no GSUB, only morx)")
	data, ok := map_font(APPLE_EMOJI)
	if !ok {
		return
	}
	font, upem := make_font(data, 0)
	face_has := proc(font: hb.Font) {}
	_ = face_has
	for sequence in ([]struct {
		name: string,
		text: string,
	}{
		{"smile", "😀"},
		{"family ZWJ", "👨‍👩‍👧‍👦"},
		{"flag FR", "🇫🇷"},
		{"keycap 1", "1️⃣"},
		{"thumbs skin tone", "👍🏽"},
		{"flag England (tags)", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"},
		{"heart VS16", "❤️"},
	}) {
		infos, positions := shape(font, sequence.text)
		fmt.printf("  %-20s %2d bytes -> %d glyph(s):", sequence.name, len(sequence.text), len(infos))
		for info, i in infos {
			fmt.printf(" #%d(cluster %d, advance %d)", info.codepoint, info.cluster, positions[i].x_advance)
		}
		fmt.println()
	}

	fmt.println("  bitmap glyphs through HarfBuzz:")
	infos, _ := shape(font, "😀")
	glyph := infos[0].codepoint
	fmt.printfln("    upem %d", upem)
	blob := hb.ot_color_glyph_reference_png(font, glyph)
	length: u32
	png_data := hb.blob_get_data(blob, &length)
	if length > 8 {
		fmt.printfln("    PNG blob: %d bytes, magic %x %x %x %x", length, png_data[0], png_data[1], png_data[2], png_data[3])
		if img, err := png.load_from_bytes(png_data[:length]); err == nil {
			fmt.printfln("    decoded by core:image/png: %dx%d, %d channels", img.width, img.height, img.channels)
			save_bgra("apple_smile_png", raw_data(img.pixels), img.width, img.height, img.width * img.channels) // channels is 4: RGBA, shown swapped
			image.destroy(img)
		} else {
			fmt.printfln("    core:image/png failed: %v", err)
		}
	} else {
		fmt.println("    no PNG for glyph")
	}
	hb.blob_destroy(blob)

	// hb_raster_paint without libpng: does it draw sbix?
	paint := hb.raster_paint_create_or_fail()
	hb.raster_paint_set_transform(paint, 1, 0, 0, -1, 0, 0)
	extents: hb.Glyph_Extents
	got_extents := hb.font_get_glyph_extents(font, glyph, &extents)
	fmt.printfln("    glyph extents: %v %v", got_extents, extents)
	set := hb.raster_paint_set_glyph_extents(paint, &extents)
	painted := hb.raster_paint_glyph_or_fail(paint, font, glyph)
	image_out := hb.raster_paint_render(paint)
	e: hb.Raster_Extents
	if image_out != nil {
		hb.raster_image_get_extents(image_out, &e)
	}
	fmt.printfln("    hb_raster_paint on sbix: extents set %v, painted %v, image %v %v", set, painted, image_out != nil, e)
}

colr_check :: proc() {
	fmt.println("HARFBUZZ RASTER PAINT: Twemoji (COLRv0)")
	data, ok := map_font(TWEMOJI)
	if !ok {
		return
	}
	font, upem := make_font(data, 0)
	face_glyph: hb.Codepoint
	assert(bool(hb.font_get_nominal_glyph(font, 0x1F600, &face_glyph)))
	fmt.printfln("  upem %d, U+1F600 is glyph %d", upem, face_glyph)
	for size in ([]f32{16, 64}) {
		scale := size / f32(upem)
		paint := hb.raster_paint_create_or_fail()
		// A subpixel offset, as the atlas will use: a quarter pixel right.
		hb.raster_paint_set_transform(paint, scale, 0, 0, -scale, 0.25, 0)
		extents: hb.Glyph_Extents
		hb.font_get_glyph_extents(font, face_glyph, &extents)
		hb.raster_paint_set_glyph_extents(paint, &extents)
		hb.raster_paint_set_foreground(paint, hb.color(255, 255, 255, 255))
		painted := hb.raster_paint_glyph_or_fail(paint, font, face_glyph)
		img := hb.raster_paint_render(paint)
		e: hb.Raster_Extents
		hb.raster_image_get_extents(img, &e)
		pixels := hb.raster_image_get_buffer(img)
		nonzero := 0
		for y in 0 ..< int(e.height) {
			for x in 0 ..< int(e.width) {
				if pixels[y * int(e.stride) + x * 4 + 3] != 0 {
					nonzero += 1
				}
			}
		}
		fmt.printfln("  size %.0f: painted %v, image %dx%d origin (%d,%d), %d non-transparent pixels", size, painted, e.width, e.height, e.x_origin, e.y_origin, nonzero)
		save_bgra(fmt.tprintf("twemoji_smile_%.0f", size), pixels, int(e.width), int(e.height), int(e.stride))
		hb.raster_image_destroy(img)
		hb.raster_paint_destroy(paint)
	}

	fmt.println("HARFBUZZ RASTER DRAW vs FREETYPE: Arial 'A' at 16 px, A8 coverage")
	arial, arial_ok := map_font(ARIAL)
	if !arial_ok {
		return
	}
	font2, upem2 := make_font(arial, 0)
	glyph: hb.Codepoint
	_ = hb.font_get_nominal_glyph(font2, 'A', &glyph)
	draw := hb.raster_draw_create_or_fail()
	scale := f32(16) / f32(upem2)
	hb.raster_draw_set_transform(draw, scale, 0, 0, -scale, 0, 0)
	extents: hb.Glyph_Extents
	hb.font_get_glyph_extents(font2, glyph, &extents)
	hb.raster_draw_set_glyph_extents(draw, &extents)
	fmt.printfln("  drawn %v", hb.raster_draw_glyph_or_fail(draw, font2, glyph))
	img := hb.raster_draw_render(draw)
	e: hb.Raster_Extents
	hb.raster_image_get_extents(img, &e)
	pixels := hb.raster_image_get_buffer(img)
	sum := 0
	for y in 0 ..< int(e.height) {
		for x in 0 ..< int(e.width) {
			sum += int(pixels[y * int(e.stride) + x])
		}
	}
	fmt.printfln("  hb_raster_draw: %dx%d origin (%d,%d) ink %d", e.width, e.height, e.x_origin, e.y_origin, sum)
	save_bgra("hb_raster_draw_A", pixels, int(e.width), int(e.height), int(e.stride), true)
}

// paint_glyph paints a colour glyph at size pixels and reports what came out.
paint_glyph :: proc(font: hb.Font, upem: u32, glyph: hb.Codepoint, size: f32, name: string) {
	scale := size / f32(upem)
	paint := hb.raster_paint_create_or_fail()
	defer hb.raster_paint_destroy(paint)
	hb.raster_paint_set_transform(paint, scale, 0, 0, -scale, 0, 0)
	extents: hb.Glyph_Extents
	hb.font_get_glyph_extents(font, glyph, &extents)
	hb.raster_paint_set_glyph_extents(paint, &extents)
	hb.raster_paint_set_foreground(paint, hb.color(255, 255, 255, 255))
	painted := hb.raster_paint_glyph_or_fail(paint, font, glyph)
	img := hb.raster_paint_render(paint)
	e: hb.Raster_Extents
	hb.raster_image_get_extents(img, &e)
	pixels := hb.raster_image_get_buffer(img)
	nonzero := 0
	for y in 0 ..< int(e.height) {
		for x in 0 ..< int(e.width) {
			if pixels[y * int(e.stride) + x * 4 + 3] != 0 {
				nonzero += 1
			}
		}
	}
	fmt.printfln("    %-18s glyph %d: painted %v, %dx%d origin (%d,%d), %d non-transparent", name, glyph, painted, e.width, e.height, e.x_origin, e.y_origin, nonzero)
	save_bgra(name, pixels, int(e.width), int(e.height), int(e.stride))
	hb.raster_image_destroy(img)
}

noto_check :: proc() {
	fmt.println("COLOUR FORMATS BY FONT (hb_ot_color_has_*)")
	for path in ([]string{TWEMOJI, APPLE_EMOJI, NOTO_EMOJI}) {
		data, ok := map_font(path)
		if !ok {
			continue
		}
		blob := hb.blob_create(raw_data(data), u32(len(data)), .Readonly, nil, nil)
		face := hb.face_create(blob, 0)
		fmt.printfln("  layers(COLRv0) %v  paint(COLRv1) %v  png(sbix/CBDT) %v  svg %v   %s", bool(hb.ot_color_has_layers(face)), bool(hb.ot_color_has_paint(face)), bool(hb.ot_color_has_png(face)), bool(hb.ot_color_has_svg(face)), path)
	}
	fmt.println("HARFBUZZ + NOTO COLOR EMOJI (COLRv1, sequences by GSUB)")
	data, ok := map_font(NOTO_EMOJI)
	if !ok {
		return
	}
	font, upem := make_font(data, 0)
	fmt.printfln("  upem %d", upem)
	for sequence in ([]struct {
		name: string,
		text: string,
	}{{"noto_smile", "😀"}, {"noto_family", "👨‍👩‍👧‍👦"}, {"noto_flag_fr", "🇫🇷"}, {"noto_thumbs_skin", "👍🏽"}, {"noto_england", "🏴󠁧󠁢󠁥󠁮󠁧󠁿"}}) {
		infos, _ := shape(font, sequence.text)
		fmt.printfln("  %-18s %d glyph(s)", sequence.name, len(infos))
		paint_glyph(font, upem, infos[0].codepoint, 96, sequence.name)
	}
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: spike <output directory>")
		os.exit(2)
	}
	out_dir = os.args[1]
	freetype_check()
	shaping_check()
	emoji_check()
	colr_check()
	noto_check()
}
