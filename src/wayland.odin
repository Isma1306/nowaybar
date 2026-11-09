package main

foreign import shim "../build/shim/libshim.a"
foreign import wl "system:wayland-client"
import "core:c"

wl_display :: distinct rawptr
wl_registry :: distinct rawptr
wl_compositor :: distinct rawptr
wl_shm :: distinct rawptr
zwlr_layer_shell_v1 :: distinct rawptr

wl_registry_listener :: struct {
	global:        proc "c" (
		data: rawptr,
		registry: wl_registry,
		name: u32,
		interface: cstring,
		version: u32,
	),
	global_remove: proc "c" (data: rawptr, registry: wl_registry, name: u32),
}

foreign wl {
	wl_display_connect :: proc(name: cstring) -> wl_display ---
	wl_display_disconnect :: proc(display: wl_display) ---
	wl_display_roundtrip :: proc(display: wl_display) -> c.int ---
}

foreign shim {
	shim_wl_display_get_registry :: proc(display: wl_display) -> wl_registry ---
	shim_wl_registry_add_listener :: proc(registry: wl_registry, listener: ^wl_registry_listener, data: rawptr) -> c.int ---
	shim_bind_compositor :: proc(registry: wl_registry, name: u32, version: u32) -> wl_compositor ---
	shim_bind_shm :: proc(registry: wl_registry, name: u32, version: u32) -> wl_shm ---
	shim_bind_layer_shell :: proc(registry: wl_registry, name: u32, version: u32) -> zwlr_layer_shell_v1 ---
}
