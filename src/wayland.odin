package main

foreign import shim "../build/shim/libshim.a"
foreign import wl "system:wayland-client"
import "core:c"

LAYER_TOP :: 2
ANCHOR_TOP :: 1
ANCHOR_BOTTOM :: 2
ANCHOR_LEFT :: 4
ANCHOR_RIGHT :: 8

// -------------- //
wl_display :: distinct rawptr
wl_registry :: distinct rawptr
wl_compositor :: distinct rawptr
wl_shm :: distinct rawptr
wl_surface :: distinct rawptr
wl_output :: distinct rawptr
zwlr_layer_shell_v1 :: distinct rawptr
zwlr_layer_surface_v1 :: distinct rawptr
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

zwlr_layer_surface_v1_listener :: struct {
	configure: proc "c" (
		data: rawptr,
		surface: zwlr_layer_surface_v1,
		serial: u32,
		width: u32,
		height: u32,
	),
	closed:    proc "c" (data: rawptr, surface: zwlr_layer_surface_v1),
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
	shim_wl_compositor_create_surface :: proc(compositor: wl_compositor) -> wl_surface ---
	shim_zwlr_layer_shell_v1_get_layer_surface :: proc(zwlr_layer_shell_v1: zwlr_layer_shell_v1, surface: wl_surface, output: wl_output, layer: u32, namespace: cstring) -> zwlr_layer_surface_v1 ---
	shim_zwlr_layer_surface_v1_set_size :: proc(layer_surface: zwlr_layer_surface_v1, width: u32, height: u32) ---
	shim_zwlr_layer_surface_v1_set_anchor :: proc(layer_surface: zwlr_layer_surface_v1, anchor: u32) ---
	shim_zwlr_layer_surface_v1_set_exclusive_zone :: proc(layer_surface: zwlr_layer_surface_v1, zone: i32) ---
	shim_wl_surface_commit :: proc(surface: wl_surface) ---
	shim_zwlr_layer_surface_v1_add_listener :: proc(layer_surface: zwlr_layer_surface_v1, listener: ^zwlr_layer_surface_v1_listener, data: rawptr) -> c.int ---
	shim_zwlr_layer_surface_v1_ack_configure :: proc(layer_surface: zwlr_layer_surface_v1, serial: u32) ---
}
