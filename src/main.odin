package main
import "base:runtime"
import "core:fmt"
import "core:log"

global :: proc "c" (
	data: rawptr,
	registry: wl_registry,
	name: u32,
	interface: cstring,
	version: u32,
) {
	context = runtime.default_context()
	fmt.println("connect")
	fmt.println(name)
	fmt.println(interface)
	fmt.println(version)
}

global_remove :: proc "c" (data: rawptr, registry: wl_registry, name: u32) {
	context = runtime.default_context()
}

main :: proc() {
	fmt.println("Start!")
	context.logger = log.create_console_logger()
	display := wl_display_connect(nil)
	if display == nil {
		log.error("no display!")
		return
	}
	registry := shim_wl_display_get_registry(display)
	listener := wl_registry_listener{global, global_remove}
	shim_wl_registry_add_listener(registry, &listener, nil)
	wl_display_roundtrip(display)
	wl_display_disconnect(display)

}
