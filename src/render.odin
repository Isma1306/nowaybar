package main

import "core:log"
import "core:math"
import "core:os"
import stbtt "vendor:stb/truetype"
Canvas :: struct {
	width:  u32,
	height: u32,
	pixels: []u32,
}
Axis :: enum {
	X,
	Y,
}
Rectangle :: struct {
	pos:    [Axis]int,
	width:  int,
	height: int,
	color:  u32,
}

draw :: proc(state: ^State) {

	background := Rectangle {
		color = 0xFF89B4FA,
		pos = {.X = 0, .Y = 0},
		height = int(state.canvas.height),
		width = int(state.canvas.width),
	}

	draw_rectangle(background, [Axis]int{}, &state.canvas)
	workspaces_box := Rectangle {
		color = 0xFF890000,
		pos = {.X = 0, .Y = 20},
		width = int(state.canvas.width),
	}

	draw_workspaces(state, 5, workspaces_box, background.pos, &state.canvas)


}

draw_rectangle :: proc(rec: Rectangle, origin: [Axis]int, canvas: ^Canvas) {
	width := rec.width
	height := rec.height
	abs_pos := rec.pos + origin
	column := abs_pos[.X]
	if (column + width > int(canvas.width)) {
		log.warnf("rect ends at x=%v but canvas is only %v wide", column + width, canvas.width)
		width = int(canvas.width) - column
	}
	if (abs_pos[.Y] + rec.height > int(canvas.height)) {
		log.warnf(
			"rect ends at y=%v but canvas is only %v tall",
			abs_pos[.Y] + rec.height,
			canvas.height,
		)
		height = int(canvas.height) - abs_pos[.Y]
	}
	row := abs_pos[.Y] * int(canvas.width)
	endrow := row + (int(canvas.width) * height)
	for row_start := row + column; row_start < endrow; row_start += int(canvas.width) {
		for x := row_start; x < row_start + width; x += 1 {
			canvas.pixels[x] = rec.color
		}

	}
}


center :: proc(rec: ^Rectangle, container_size: int, axis: Axis) {
	space := 0
	if (axis == .X) {
		space = container_size - rec.width
	} else {
		space = container_size - rec.height
	}
	if (space >= 0) {
		rec.pos[axis] = space / 2
	}
}

draw_workspaces :: proc(
	state: ^State,
	padding: int,
	rec: Rectangle,
	origin: [Axis]int,
	canvas: ^Canvas,
) {
	rec := rec
	item_size := rec.width - (padding * 2)
	rec.height = len(state.workspace_list) * (padding + item_size) + padding
	draw_rectangle(rec, origin, canvas)
	workspace := Rectangle {
		color  = 0xFF00B4FA,
		height = item_size,
		width  = item_size,
	}
	center(&workspace, rec.width, .X)
	for i := 0; i < len(state.workspace_list); i += 1 {
		item := workspace
		item.pos[.Y] = (i * (item_size + padding)) + padding
		if (state.workspace_list[i].id == state.active_workspace) {
			item.color = 0xFF0000FA
		}
		draw_rectangle(item, origin + rec.pos, canvas)
		if (state.workspace_list[i].type == "special") {
			draw_char(
				'\U000f0ddc',
				&state.fontinfo_icon,
				item_size,
				state,
				origin + rec.pos + item.pos,
			)
		} else {

			for r in state.workspace_list[i].name {
				draw_char(rune(r), &state.fontinfo, item_size, state, origin + rec.pos + item.pos)
			}
		}
	}
}

get_font :: proc(path: string, is_icon: bool, state: ^State) {
	font_bytes, err := os.read_entire_file_from_path(path, context.allocator)
	if (err != nil) {

		log.error("read_entire_file: ", err)
		os.exit(1)

	}
	info := stbtt.fontinfo{}
	ok := stbtt.InitFont(&info, raw_data(font_bytes), 0)
	if (!ok) {

		log.error("stbtt.InitFont failed")
		os.exit(1)

	}
	if (is_icon) {
		state.fontinfo_icon = info
	} else {
		state.fontinfo = info
	}
}

get_char :: proc(
	font: ^stbtt.fontinfo,
	char: rune,
	scale, shift_x, shift_y: f32,
) -> (
	bytes: []u8,
	w, h, xoff, yoff: i32,
) {
	pointer := stbtt.GetCodepointBitmapSubpixel(
		font,
		scale,
		scale,
		shift_x,
		shift_y,
		char,
		&w,
		&h,
		&xoff,
		&yoff,
	)
	return ([^]u8)(pointer)[:w * h], w, h, xoff, yoff
}

draw_char :: proc(
	char: rune,
	font: ^stbtt.fontinfo,
	container_size: int,
	state: ^State,
	origin: [Axis]int,
) {
	color: u32 = 0xFFFFFFFF
	scale := stbtt.ScaleForPixelHeight(font, 16)

	// The glyph's outline box, in font units (y grows UP in fonts).
	// These are exact numbers, not rounded to pixels.
	x0, y0, x1, y1: i32
	stbtt.GetCodepointBox(font, char, &x0, &y0, &x1, &y1)
	glyph_w := f32(x1 - x0) * scale
	glyph_h := f32(y1 - y0) * scale

	// Where the outline's left/top edge should be to sit in the exact
	// middle. Usually a fraction, e.g. 4.6 px.
	left := (f32(container_size) - glyph_w) / 2
	top := (f32(container_size) - glyph_h) / 2

	// Split that into whole pixels + a leftover fraction. stb draws the
	// glyph already shifted by the fraction ("subpixel"), and we place
	// the bitmap at the whole-pixel part.
	anchor_x := left - f32(x0) * scale
	anchor_y := top + f32(y1) * scale
	shift_x := anchor_x - math.floor(anchor_x)
	shift_y := anchor_y - math.floor(anchor_y)

	char_map, width, height, xoff, yoff := get_char(font, char, scale, shift_x, shift_y)
	defer stbtt.FreeBitmap(raw_data(char_map), nil)
	w := int(width)
	h := int(height)
	pos_x := int(math.floor(anchor_x)) + int(xoff)
	pos_y := int(math.floor(anchor_y)) + int(yoff)

	for gy := 0; gy < h; gy += 1 {
		for gx := 0; gx < w; gx += 1 {
			a := char_map[gy * w + gx]
			if (a == 0) {
				continue
			}
			index :=
				u32(origin[.Y] + gy + pos_y) * state.canvas.width + u32(origin[.X] + gx + pos_x)
			state.canvas.pixels[index] = blend(state.canvas.pixels[index], color, a)
		}

	}
}

blend :: proc(bg: u32, fg: u32, a: u8) -> u32 {
	alpha := u32(a)
	// 1. unpack: shift the channel down to the bottom 8 bits, then mask off the rest
	bg_r, bg_g, bg_b := (bg >> 16) & 0xFF, (bg >> 8) & 0xFF, bg & 0xFF
	fg_r, fg_g, fg_b := (fg >> 16) & 0xFF, (fg >> 8) & 0xFF, fg & 0xFF

	// 2. mix: (text * a + background * (255 - a)) / 255, per channel
	r := (fg_r * alpha + bg_r * (255 - alpha)) / 255
	g := (fg_g * alpha + bg_g * (255 - alpha)) / 255
	b := (fg_b * alpha + bg_b * (255 - alpha)) / 255

	// 3. pack: fully opaque alpha, channels back in their slots
	return 0xFF000000 | (r << 16) | (g << 8) | b
}
