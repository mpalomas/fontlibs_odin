// Bindings for part of FreeType 2.15: loading faces from memory, sizes, glyph loading with hinting, outline
// editing and rendering to bitmaps. Written by hand; tools/abi/check.sh checks the struct layouts against the C headers.
package freetype

import "core:c"

@(private) OS :: "macos" when ODIN_OS == .Darwin else "linux" when ODIN_OS == .Linux else "windows" when ODIN_OS == .Windows else #panic("fontlibs: unsupported OS")
@(private) ARCH :: "x86_64" when ODIN_ARCH == .amd64 else "arm64" when ODIN_ARCH == .arm64 else #panic("fontlibs: unsupported architecture")
@(private) FILE :: "freetype.lib" when ODIN_OS == .Windows else "libfreetype.a"

// Path of the library, relative to this directory. Override with -define:FREETYPE_LIB=<path>.
FREETYPE_LIB :: #config(FREETYPE_LIB, "../lib/" + OS + "-" + ARCH + "/" + FILE)

when !#exists(FREETYPE_LIB) {
	#panic("Could not find the FreeType library at '" + FREETYPE_LIB + "'. Run tools/build_fontlibs.sh (.ps1 on Windows), or pass -define:FREETYPE_LIB=<path>.")
}

foreign import lib {
	FREETYPE_LIB,
}

// FT_Long, FT_Pos and FT_Fixed are C long: 32 bits on 64-bit Windows, 64 bits elsewhere.
Long :: c.long
Pos :: c.long // in 26.6 fixed point for sizes in pixels, in font units for unscaled outlines
Fixed :: c.long // 16.16

Library :: distinct rawptr
Face :: ^Face_Rec
Glyph_Slot :: ^Glyph_Slot_Rec
Size :: ^Size_Rec

Error :: distinct c.int // 0 is success
OK :: Error(0)

Generic :: struct {
	data:      rawptr,
	finalizer: rawptr,
}

Vector :: struct {
	x, y: Pos,
}

BBox :: struct {
	x_min, y_min, x_max, y_max: Pos,
}

Matrix :: struct {
	xx, xy, yx, yy: Fixed,
}

Glyph_Metrics :: struct {
	width, height:                Pos,
	hori_bearing_x:               Pos,
	hori_bearing_y:               Pos,
	hori_advance:                 Pos,
	vert_bearing_x:               Pos,
	vert_bearing_y:               Pos,
	vert_advance:                 Pos,
}

Size_Metrics :: struct {
	x_ppem, y_ppem:   c.ushort,
	x_scale, y_scale: Fixed, // font units to 26.6 pixels, 16.16
	ascender:         Pos, // 26.6
	descender:        Pos,
	height:           Pos,
	max_advance:      Pos,
}

Size_Rec :: struct {
	face:     Face,
	generic:  Generic,
	metrics:  Size_Metrics,
	internal: rawptr,
}

Pixel_Mode :: enum c.uchar {
	None,
	Mono,
	Gray,
	Gray2,
	Gray4,
	LCD,
	LCD_V,
	BGRA,
}

Bitmap :: struct {
	rows:         c.uint,
	width:        c.uint,
	pitch:        c.int, // bytes per row, negative when the bitmap is upside down
	buffer:       [^]u8,
	num_grays:    c.ushort,
	pixel_mode:   Pixel_Mode,
	palette_mode: c.uchar,
	palette:      rawptr,
}

Outline :: struct {
	n_contours: c.ushort,
	n_points:   c.ushort,
	points:     [^]Vector,
	tags:       [^]u8,
	contours:   [^]c.ushort,
	flags:      c.int,
}

// The glyph format, a four-character tag: 'outl', 'bits', ...
Glyph_Format :: enum c.int {
	None      = 0,
	Composite = 'c' << 24 | 'o' << 16 | 'm' << 8 | 'p',
	Bitmap    = 'b' << 24 | 'i' << 16 | 't' << 8 | 's',
	Outline   = 'o' << 24 | 'u' << 16 | 't' << 8 | 'l',
	Plotter   = 'p' << 24 | 'l' << 16 | 'o' << 8 | 't',
	SVG       = 'S' << 24 | 'V' << 16 | 'G' << 8 | ' ',
}

Glyph_Slot_Rec :: struct {
	library:             Library,
	face:                Face,
	next:                Glyph_Slot,
	glyph_index:         c.uint,
	generic:             Generic,
	metrics:             Glyph_Metrics,
	linear_hori_advance: Fixed,
	linear_vert_advance: Fixed,
	advance:             Vector,
	format:              Glyph_Format,
	bitmap:              Bitmap,
	bitmap_left:         c.int,
	bitmap_top:          c.int,
	outline:             Outline,
	num_subglyphs:       c.uint,
	subglyphs:           rawptr,
	control_data:        rawptr,
	control_len:         c.long,
	lsb_delta:           Pos,
	rsb_delta:           Pos,
	other:               rawptr,
	internal:            rawptr,
}

List_Rec :: struct {
	head, tail: rawptr,
}

Face_Rec :: struct {
	num_faces:           Long,
	face_index:          Long,
	face_flags:          Long,
	style_flags:         Long,
	num_glyphs:          Long,
	family_name:         cstring,
	style_name:          cstring,
	num_fixed_sizes:     c.int,
	available_sizes:     rawptr,
	num_charmaps:        c.int,
	charmaps:            rawptr,
	generic:             Generic,
	bbox:                BBox,
	units_per_em:        c.ushort,
	ascender:            c.short,
	descender:           c.short,
	height:              c.short,
	max_advance_width:   c.short,
	max_advance_height:  c.short,
	underline_position:  c.short,
	underline_thickness: c.short,
	glyph:               Glyph_Slot,
	size:                Size,
	charmap:             rawptr,
	driver:              rawptr,
	memory:              rawptr,
	stream:              rawptr,
	sizes_list:          List_Rec,
	autohint:            Generic,
	extensions:          rawptr,
	internal:            rawptr,
}

// Load_Flags are the FT_LOAD_ flags of load_glyph. The target (how the glyph will be rendered, which picks the hinter) is a
// number in bits 16 to 19 of the flags: use target.
Load_Flag :: enum c.int {
	No_Scale          = 0,
	No_Hinting        = 1,
	Render            = 2,
	No_Bitmap         = 3,
	Vertical_Layout   = 4,
	Force_Autohint    = 5,
	Crop_Bitmap       = 6,
	Pedantic          = 7,
	Ignore_Global_Advance_Width = 9,
	No_Recurse        = 10,
	Ignore_Transform  = 11,
	Monochrome        = 12,
	Linear_Design     = 13,
	No_Autohint       = 15,
	Color             = 20,
	Compute_Metrics   = 21,
	Bitmap_Metrics_Only = 22,
	No_Svg            = 24,
}
Load_Flags :: bit_set[Load_Flag; c.int]

Render_Mode :: enum c.int {
	Normal,
	Light,
	Mono,
	LCD,
	LCD_V,
	SDF,
}

// load_target is the FT_LOAD_TARGET_ part of the load flags for a render mode: Light hints vertically only, with the auto-hinter.
load_target :: #force_inline proc "contextless" (mode: Render_Mode) -> Load_Flags {
	return transmute(Load_Flags)((c.int(mode) & 15) << 16)
}

@(default_calling_convention = "c", link_prefix = "FT_")
foreign lib {
	Init_FreeType :: proc(library: ^Library) -> Error ---
	Done_FreeType :: proc(library: Library) -> Error ---
	Library_Version :: proc(library: Library, major, minor, patch: ^c.int) ---

	// New_Memory_Face does not copy the data: it must stay alive as long as the face.
	New_Memory_Face :: proc(library: Library, file_base: [^]u8, file_size: Long, face_index: Long, face: ^Face) -> Error ---
	Done_Face :: proc(face: Face) -> Error ---

	Set_Char_Size :: proc(face: Face, char_width, char_height: Pos, horz_resolution, vert_resolution: c.uint) -> Error ---
	Set_Pixel_Sizes :: proc(face: Face, pixel_width, pixel_height: c.uint) -> Error ---
	Set_Transform :: proc(face: Face, transform: ^Matrix, delta: ^Vector) ---

	Get_Char_Index :: proc(face: Face, charcode: c.ulong) -> c.uint ---
	Load_Glyph :: proc(face: Face, glyph_index: c.uint, load_flags: Load_Flags) -> Error ---
	Render_Glyph :: proc(slot: Glyph_Slot, render_mode: Render_Mode) -> Error ---

	// Outline_Translate moves an outline, in the units of its points (26.6 pixels for a scaled glyph).
	Outline_Translate :: proc(outline: ^Outline, x_offset, y_offset: Pos) ---
	// Outline_Transform applies a 2x2 matrix (16.16): a shear makes a synthetic italic.
	Outline_Transform :: proc(outline: ^Outline, transform: ^Matrix) ---
	// Outline_EmboldenXY grows an outline by the strengths (26.6 pixels for a scaled glyph) in x and y, keeping its bottom left
	// where it was: a synthetic bold.
	Outline_EmboldenXY :: proc(outline: ^Outline, x_strength, y_strength: Pos) -> Error ---
}
