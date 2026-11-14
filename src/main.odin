package main
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"
import "core:sys/linux"

registry_global :: proc "c" (
	data: rawptr,
	registry: wl_registry,
	name: u32,
	interface: cstring,
	version: u32,
) {
	context = runtime.default_context()
	state := cast(^State)data
	if (interface == "wl_shm") {
		state.shm = shim_bind_shm(registry, name, 1)
	}
	if (interface == "wl_compositor") {
		state.compositor = shim_bind_compositor(registry, name, min(version, 4))
	}
	if (interface == "zwlr_layer_shell_v1") {
		state.layer_shell = shim_bind_layer_shell(registry, name, min(version, 4))
	}
}

registry_global_remove :: proc "c" (data: rawptr, registry: wl_registry, name: u32) {
	context = runtime.default_context()
}

layer_surface_configure :: proc "c" (
	data: rawptr,
	surface: zwlr_layer_surface_v1,
	serial: u32,
	width: u32,
	height: u32,
) {
	context = runtime.default_context()
	state := cast(^State)data
	state.canvas.width = width
	state.canvas.height = height
	shim_zwlr_layer_surface_v1_ack_configure(surface, serial)
}

layer_surface_closed :: proc "c" (data: rawptr, surface: zwlr_layer_surface_v1) {
	context = runtime.default_context()
}

State :: struct {
	compositor:    wl_compositor,
	layer_shell:   zwlr_layer_shell_v1,
	shm:           wl_shm,
	surface:       wl_surface,
	layer_surface: zwlr_layer_surface_v1,
	canvas:        Canvas,
	bar_width:     u32,
}
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

Workspace_info :: struct {
	id:              int,
	name:            string,
	monitor:         string,
	monitorID:       int,
	windows:         int,
	hasfullscreen:   bool,
	lastwindow:      string,
	lastwindowtitle: string,
	ispersistent:    bool,
	tiledLayout:     string,
}

main :: proc() {
	fmt.println("Start!")
	context.logger = log.create_console_logger()
	display := wl_display_connect(nil)
	if display == nil {
		log.error("no display!")
		return
	}
	state := State{}
	state.bar_width = 30
	registry := shim_wl_display_get_registry(display)
	register_listener := wl_registry_listener {
		global        = registry_global,
		global_remove = registry_global_remove,
	}
	layer_surface_listener := zwlr_layer_surface_v1_listener {
		configure = layer_surface_configure,
		closed    = layer_surface_closed,
	}
	shim_wl_registry_add_listener(registry, &register_listener, &state)
	wl_display_roundtrip(display)
	if (state.compositor == nil || state.layer_shell == nil || state.shm == nil) {
		log.error("State is missing pointers")
		os.exit(1)
	}
	state.surface = shim_wl_compositor_create_surface(state.compositor)
	state.layer_surface = shim_zwlr_layer_shell_v1_get_layer_surface(
		state.layer_shell,
		state.surface,
		nil,
		LAYER_TOP,
		"bar",
	)
	shim_zwlr_layer_surface_v1_add_listener(state.layer_surface, &layer_surface_listener, &state)
	shim_zwlr_layer_surface_v1_set_size(state.layer_surface, state.bar_width, 0)
	shim_zwlr_layer_surface_v1_set_anchor(
		state.layer_surface,
		ANCHOR_TOP | ANCHOR_LEFT | ANCHOR_BOTTOM,
	)
	shim_zwlr_layer_surface_v1_set_exclusive_zone(state.layer_surface, i32(state.bar_width))
	shim_wl_surface_commit(state.surface)
	wl_display_roundtrip(display)
	fd, error := linux.memfd_create("bar", {})
	if error != .NONE {
		log.error("memfd_create: ", error)
		os.exit(1)
	}
	size := state.canvas.height * state.canvas.width * 4
	error = linux.ftruncate(fd, i64(size))
	if error != .NONE {
		log.error("ftruncate: ", error)
		os.exit(1)
	}
	mem_pointer, err := linux.mmap(0, uint(size), {.READ, .WRITE}, {.SHARED}, fd, 0)
	if err != .NONE {
		log.error("nmap: ", err)
		os.exit(1)
	}
	state.canvas.pixels = ([^]u32)(mem_pointer)[:state.canvas.width * state.canvas.height]

	draw(&state.canvas)
	width := i32(state.canvas.width)
	height := i32(state.canvas.height)
	pool := shim_wl_shm_create_pool(state.shm, i32(fd), i32(size))
	buffer := shim_wl_shm_pool_create_buffer(
		pool,
		0,
		width,
		height,
		width * 4,
		WL_SHM_FORMAT_ARGB8888,
	)

	shim_wl_surface_attach(state.surface, buffer, 0, 0)
	shim_wl_surface_damage_buffer(state.surface, 0, 0, width, height)
	shim_wl_surface_commit(state.surface)

	for wl_display_dispatch(display) != -1 {}

	wl_display_disconnect(display)

}

draw :: proc(canvas: ^Canvas) {

	background := Rectangle {
		color = 0xFF89B4FA,
		pos = {.X = 0, .Y = 0},
		height = int(canvas.height),
		width = int(canvas.width),
	}

	draw_rectangle(background, [Axis]int{}, canvas)

	workspaces_box := Rectangle {
		color = 0xFF890000,
		pos = {.X = 0, .Y = 20},
		width = int(canvas.width),
	}
	workspaces_list := []Workspace_info{{id = 1}, {id = 2}, {id = 3}}
	active_workspace := 2
	draw_workspaces(workspaces_list, active_workspace, 5, workspaces_box, background.pos, canvas)
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
