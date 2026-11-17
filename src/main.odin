package main
import "base:runtime"
import "core:log"
import "core:mem/virtual"
import "core:os"
import "core:sys/linux"
import stbtt "vendor:stb/truetype"

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
	compositor:       wl_compositor,
	layer_shell:      zwlr_layer_shell_v1,
	shm:              wl_shm,
	surface:          wl_surface,
	layer_surface:    zwlr_layer_surface_v1,
	canvas:           Canvas,
	bar_width:        u32,
	active_workspace: int,
	workspace_list:   []Workspace_info,
	fontinfo:         stbtt.fontinfo,
	fontinfo_icon:    stbtt.fontinfo,
	workspace_arena:  virtual.Arena,
	cutted_info:      [dynamic]u8,
}


main :: proc() {
	context.logger = log.create_console_logger()
	log.info("Start!")
	display := wl_display_connect(nil)
	if display == nil {
		log.error("no display!")
		return
	}
	wayland_fd := wl_display_get_fd(display)
	state := State{}
	state.bar_width = 30
	arena_err := virtual.arena_init_growing(&state.workspace_arena)
	if (arena_err != nil) {
		log.error("arena_err :", arena_err)
		os.exit(1)
	}
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
	get_font("./fonts/NotoSansMono-Bold.ttf", false, &state)
	get_font("./fonts/SymbolsNerdFontMono-Regular.ttf", true, &state)
	set_active_workspace(&state)
	set_workspaces(&state)

	draw(&state)
	shim_wl_surface_attach(state.surface, buffer, 0, 0)
	shim_wl_surface_damage_buffer(state.surface, 0, 0, width, height)
	shim_wl_surface_commit(state.surface)
	free_all(context.temp_allocator)


	hypr_fd := connect_hypr("/.socket2.sock")
	poll_list := [2]linux.Poll_Fd {
		{fd = hypr_fd, events = {.IN}},
		{fd = linux.Fd(wayland_fd), events = {.IN}},
	}
	for {
		wl_display_flush(display)
		linux.poll(poll_list[:], -1)
		if (.IN in poll_list[0].revents) {
			ok := handle_hyprland(poll_list[0].fd, &state)
			if ok {
				draw(&state)
				shim_wl_surface_attach(state.surface, buffer, 0, 0)
				shim_wl_surface_damage_buffer(state.surface, 0, 0, width, height)
				shim_wl_surface_commit(state.surface)
			}
		}


		if (.IN in poll_list[1].revents) {
			res := wl_display_dispatch(display)
			if (res == -1) {
				break
			}

		}


	}

	wl_display_disconnect(display)

}
