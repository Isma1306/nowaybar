package main

import "core:log"
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
		for r in state.workspace_list[i].name {
			draw_char(rune(r), state, origin + rec.pos + item.pos)
		}
	}
}

get_font :: proc(state: ^State) {
	font_bytes, err := os.read_entire_file_from_path(
		"/usr/share/fonts/noto/NotoSansMono-Bold.ttf",
		context.allocator,
	)
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
	state.fontinfo = info
}

get_char :: proc(state: ^State, char: rune) -> (bytes: []u8, w: i32, h: i32) {
	scale := stbtt.ScaleForPixelHeight(&state.fontinfo, 14)
	xoff := i32(0)
	yoff := i32(0)
	pointer := stbtt.GetCodepointBitmap(&state.fontinfo, scale, scale, char, &w, &h, &xoff, &yoff)
	return ([^]u8)(pointer)[:w * h], w, h
}

draw_char :: proc(char: rune, state: ^State, origin: [Axis]int) {
	color: u32 = 0xFFFFFFFF
	char_map, width, height := get_char(state, char)
	w := int(width)
	h := int(height)
	box := Rectangle {
		width  = w,
		height = h,
	}

	center(&box, 20, .X)
	center(&box, 20, .Y)

	for gy := 0; gy < h; gy += 1 {
		for gx := 0; gx < w; gx += 1 {
			a := char_map[gy * w + gx]
			if (a == 0) {
				continue
			}
			index :=
				u32(origin[.Y] + gy + box.pos[.Y]) * state.canvas.width +
				u32(origin[.X] + gx + box.pos[.X])
			state.canvas.pixels[index] = blend(state.canvas.pixels[index], color, a)
		}

	}

	stbtt.FreeBitmap(raw_data(char_map), nil)
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
