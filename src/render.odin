package main

import "core:log"

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

	draw_workspaces(
		state.workspace_list,
		state.active_workspace,
		5,
		workspaces_box,
		background.pos,
		&state.canvas,
	)
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
	list: []Workspace_info,
	active_workspace: int,
	padding: int,
	rec: Rectangle,
	origin: [Axis]int,
	canvas: ^Canvas,
) {
	rec := rec
	item_size := rec.width - (padding * 2)
	rec.height = len(list) * (padding + item_size) + padding
	draw_rectangle(rec, origin, canvas)
	workspace := Rectangle {
		color  = 0xFF00B4FA,
		height = item_size,
		width  = item_size,
	}
	center(&workspace, rec.width, .X)
	for i := 0; i < len(list); i += 1 {
		item := workspace
		item.pos[.Y] = (i * (item_size + padding)) + padding
		if (list[i].id == active_workspace) {
			item.color = 0xFF0000FA
		}
		draw_rectangle(item, origin + rec.pos, canvas)
	}
}
