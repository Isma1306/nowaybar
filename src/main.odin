package main
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:os"

global :: proc "c" (
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

global_remove :: proc "c" (data: rawptr, registry: wl_registry, name: u32) {
	context = runtime.default_context()
}

State :: struct {
	compositor:  wl_compositor,
	layer_shell: zwlr_layer_shell_v1,
	shm:         wl_shm,
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
	listener := wl_registry_listener {
		global        = global,
		global_remove = global_remove,
	}
	shim_wl_registry_add_listener(registry, &listener, &state)
	wl_display_roundtrip(display)
	if (state.compositor == nil || state.layer_shell == nil || state.shm == nil) {
		log.error("State is missing pointers")
		os.exit(1)
	}
	wl_display_disconnect(display)

}
