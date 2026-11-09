package main
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"

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
	state.width = width
	state.height = height
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
	width:         u32,
	height:        u32,
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
	shim_zwlr_layer_surface_v1_set_size(state.layer_surface, 0, 30)
	shim_zwlr_layer_surface_v1_set_anchor(
		state.layer_surface,
		ANCHOR_TOP | ANCHOR_LEFT | ANCHOR_RIGHT,
	)
	shim_zwlr_layer_surface_v1_set_exclusive_zone(state.layer_surface, 30)
	shim_wl_surface_commit(state.surface)
	wl_display_roundtrip(display)
	log.info(state.width)
	log.info(state.height)
	wl_display_disconnect(display)

}
