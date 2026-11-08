// Bindings for part of HarfBuzz 15.1: shaping, colour glyph queries, and the CPU raster library (outlines to
// A8, colour glyphs to BGRA32). Written by hand; tools/abi/check.sh checks the struct layouts against the C headers.
package harfbuzz

import "core:c"

@(private) OS :: "macos" when ODIN_OS == .Darwin else "linux" when ODIN_OS == .Linux else "windows" when ODIN_OS == .Windows else #panic("fontlibs: unsupported OS")
@(private) ARCH :: "x86_64" when ODIN_ARCH == .amd64 else "arm64" when ODIN_ARCH == .arm64 else #panic("fontlibs: unsupported architecture")

// Link the shared library, which holds FreeType and HarfBuzz both (libfontlibs.dylib or .so, fontlibs.dll through fontlibs.dll.lib),
// instead of the static ones. Enable with -define:FONTLIBS_SHARED=true, for both packages.
FONTLIBS_SHARED :: #config(FONTLIBS_SHARED, false)

when FONTLIBS_SHARED {
	@(private) FILE :: "fontlibs.dll.lib" when ODIN_OS == .Windows else "libfontlibs.dylib" when ODIN_OS == .Darwin else "libfontlibs.so"
} else {
	@(private) FILE :: "harfbuzz.lib" when ODIN_OS == .Windows else "libharfbuzz.a"
}

// Path of the library, relative to this directory. Override with -define:HARFBUZZ_LIB=<path>.
HARFBUZZ_LIB :: #config(HARFBUZZ_LIB, "../lib/" + OS + "-" + ARCH + "/" + FILE)

when !#exists(HARFBUZZ_LIB) {
	#panic("Could not find the HarfBuzz library at '" + HARFBUZZ_LIB + "'. Run tools/build_fontlibs.sh (.ps1 on Windows), or pass -define:HARFBUZZ_LIB=<path>.")
}

// HarfBuzz is C++ built without the C++ runtime, but with threads: on Linux it uses the C math and thread libraries.
when ODIN_OS == .Linux {
	foreign import lib {
		HARFBUZZ_LIB,
		"system:m",
		"system:pthread",
	}
} else {
	foreign import lib {
		HARFBUZZ_LIB,
	}
}

Bool :: distinct c.int
Codepoint :: u32
Position :: i32
Tag :: u32
Color :: u32 // HB_COLOR(b, g, r, a): blue is the highest byte, alpha the lowest

Blob :: distinct rawptr
Face :: distinct rawptr
Font :: distinct rawptr
Buffer :: distinct rawptr
Language :: distinct rawptr

Memory_Mode :: enum c.int {
	Duplicate,
	Readonly,
	Writable,
	Readonly_May_Make_Writable,
}

Direction :: enum c.int {
	Invalid,
	LTR = 4,
	RTL,
	TTB,
	BTT,
}

Glyph_Info :: struct {
	codepoint: Codepoint, // after shaping: the glyph id
	mask:      u32,
	cluster:   u32, // the byte offset in the text of the first character of the cluster
	var1:      u32,
	var2:      u32,
}

Glyph_Position :: struct {
	x_advance, y_advance: Position, // in font scale units
	x_offset, y_offset:   Position,
	var:                  u32,
}

Glyph_Extents :: struct {
	x_bearing, y_bearing: Position,
	width, height:        Position, // height is negative: it goes down from y_bearing
}

Feature :: struct {
	tag:   Tag,
	value: u32,
	start: c.uint, // HB_FEATURE_GLOBAL_START (0) and HB_FEATURE_GLOBAL_END (max) for the whole buffer
	end:   c.uint,
}

// Style_Tag is what style_get_value reads of a face: from its variation axes if it has them, else from its OS/2 and post tables.
Style_Tag :: enum u32 {
	Italic       = 'i' << 24 | 't' << 16 | 'a' << 8 | 'l', // 0 or 1
	Optical_Size = 'o' << 24 | 'p' << 16 | 's' << 8 | 'z',
	Slant_Angle  = 's' << 24 | 'l' << 16 | 'n' << 8 | 't', // in degrees, negative leans right
	Slant_Ratio  = 'S' << 24 | 'l' << 16 | 'n' << 8 | 't',
	Width        = 'w' << 24 | 'd' << 16 | 't' << 8 | 'h', // a percentage of normal
	Weight       = 'w' << 24 | 'g' << 16 | 'h' << 8 | 't', // 400 regular, 700 bold
}

Raster_Format :: enum c.int {
	A8,
	BGRA32, // premultiplied
}

Raster_Extents :: struct {
	x_origin, y_origin: c.int, // pixel coordinates of the image's left and top edges
	width, height:      c.uint,
	stride:             c.uint, // bytes per row
}

Raster_Image :: distinct rawptr
Raster_Draw :: distinct rawptr
Raster_Paint :: distinct rawptr

// tag makes an OpenType tag from four characters: tag("liga").
tag :: #force_inline proc "contextless" (s: string) -> Tag {
	assert_contextless(len(s) == 4)
	return Tag(s[0]) << 24 | Tag(s[1]) << 16 | Tag(s[2]) << 8 | Tag(s[3])
}

// color makes a Color from straight (not premultiplied) 8-bit channels.
color :: #force_inline proc "contextless" (r, g, b, a: u8) -> Color {
	return Color(b) << 24 | Color(g) << 16 | Color(r) << 8 | Color(a)
}

@(default_calling_convention = "c", link_prefix = "hb_")
foreign lib {
	version_string :: proc() -> cstring ---

	// BLOBS
	blob_create :: proc(data: [^]u8, length: c.uint, mode: Memory_Mode, user_data: rawptr, destroy: proc "c" (data: rawptr)) -> Blob ---
	blob_get_data :: proc(blob: Blob, length: ^c.uint) -> [^]u8 ---
	blob_destroy :: proc(blob: Blob) ---

	// FACES AND FONTS
	face_create :: proc(blob: Blob, index: c.uint) -> Face ---
	face_destroy :: proc(face: Face) ---
	face_get_glyph_count :: proc(face: Face) -> c.uint ---
	face_get_upem :: proc(face: Face) -> c.uint ---
	font_create :: proc(face: Face) -> Font ---
	font_destroy :: proc(font: Font) ---
	font_set_scale :: proc(font: Font, x_scale, y_scale: c.int) ---
	font_set_variations :: proc(font: Font, variations: [^]Variation, variations_length: c.uint) ---
	font_get_nominal_glyph :: proc(font: Font, unicode: Codepoint, glyph: ^Codepoint) -> Bool ---
	font_get_glyph_extents :: proc(font: Font, glyph: Codepoint, extents: ^Glyph_Extents) -> Bool ---
	font_get_glyph_h_advance :: proc(font: Font, glyph: Codepoint) -> Position ---
	style_get_value :: proc(font: Font, style_tag: Style_Tag) -> f32 ---

	// SHAPING
	buffer_create :: proc() -> Buffer ---
	buffer_destroy :: proc(buffer: Buffer) ---
	buffer_clear_contents :: proc(buffer: Buffer) ---
	buffer_add_utf8 :: proc(buffer: Buffer, text: [^]u8, text_length: c.int, item_offset: c.uint, item_length: c.int) ---
	buffer_set_direction :: proc(buffer: Buffer, direction: Direction) ---
	buffer_guess_segment_properties :: proc(buffer: Buffer) ---
	buffer_get_direction :: proc(buffer: Buffer) -> Direction ---
	buffer_get_length :: proc(buffer: Buffer) -> c.uint ---
	buffer_get_glyph_infos :: proc(buffer: Buffer, length: ^c.uint) -> [^]Glyph_Info ---
	buffer_get_glyph_positions :: proc(buffer: Buffer, length: ^c.uint) -> [^]Glyph_Position ---
	shape :: proc(font: Font, buffer: Buffer, features: [^]Feature, num_features: c.uint) ---

	// COLOUR
	ot_color_has_layers :: proc(face: Face) -> Bool --- // COLRv0
	ot_color_has_paint :: proc(face: Face) -> Bool --- // COLRv1
	ot_color_has_png :: proc(face: Face) -> Bool --- // sbix or CBDT
	ot_color_has_svg :: proc(face: Face) -> Bool ---
	ot_color_glyph_reference_png :: proc(font: Font, glyph: Codepoint) -> Blob ---

	// RASTER
	raster_image_destroy :: proc(image: Raster_Image) ---
	raster_image_get_buffer :: proc(image: Raster_Image) -> [^]u8 ---
	raster_image_get_extents :: proc(image: Raster_Image, extents: ^Raster_Extents) ---
	raster_image_get_format :: proc(image: Raster_Image) -> Raster_Format ---

	raster_draw_create_or_fail :: proc() -> Raster_Draw ---
	raster_draw_destroy :: proc(draw: Raster_Draw) ---
	raster_draw_set_transform :: proc(draw: Raster_Draw, xx, yx, xy, yy, dx, dy: f32) ---
	raster_draw_set_glyph_extents :: proc(draw: Raster_Draw, glyph_extents: ^Glyph_Extents) -> Bool ---
	raster_draw_glyph_or_fail :: proc(draw: Raster_Draw, font: Font, glyph: Codepoint) -> Bool ---
	raster_draw_render :: proc(draw: Raster_Draw) -> Raster_Image ---

	raster_paint_create_or_fail :: proc() -> Raster_Paint ---
	raster_paint_destroy :: proc(paint: Raster_Paint) ---
	raster_paint_set_transform :: proc(paint: Raster_Paint, xx, yx, xy, yy, dx, dy: f32) ---
	raster_paint_set_glyph_extents :: proc(paint: Raster_Paint, glyph_extents: ^Glyph_Extents) -> Bool ---
	raster_paint_set_foreground :: proc(paint: Raster_Paint, foreground: Color) ---
	raster_paint_glyph_or_fail :: proc(paint: Raster_Paint, font: Font, glyph: Codepoint) -> Bool ---
	raster_paint_render :: proc(paint: Raster_Paint) -> Raster_Image ---
}

Variation :: struct {
	tag:   Tag,
	value: f32,
}
