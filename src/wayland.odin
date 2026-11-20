package main

foreign import shim "../build/shim/libshim.a"
foreign import wl "system:wayland-client"
import "core:c"

LAYER_TOP :: 2
ANCHOR_TOP :: 1
ANCHOR_BOTTOM :: 2
ANCHOR_LEFT :: 4
ANCHOR_RIGHT :: 8
WL_SHM_FORMAT_ARGB8888 :: 0
WL_SEAT_CAPABILITY_POINTER :: 1

// -------------- //
wl_display :: distinct rawptr
wl_registry :: distinct rawptr
wl_compositor :: distinct rawptr
wl_shm :: distinct rawptr
wl_surface :: distinct rawptr
wl_output :: distinct rawptr
zwlr_layer_shell_v1 :: distinct rawptr
zwlr_layer_surface_v1 :: distinct rawptr
wl_shm_pool :: distinct rawptr
wl_buffer :: distinct rawptr
wl_seat :: distinct rawptr
wl_pointer :: distinct rawptr
wl_fixed_t :: distinct i32
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

wl_seat_listener :: struct {
	capabilities: proc "c" (data: rawptr, seat: wl_seat, capabilities: u32),
	name:         proc "c" (data: rawptr, seat: wl_seat, name: cstring),
}

Button_states :: enum u32 {
	released,
	pressed,
}

Pointer_axis :: enum u32 {
	vertical_scroll,
	horizontal_scroll,
}
wl_pointer_listener :: struct {
	enter:  proc "c" (
		data: rawptr,
		pointer: wl_pointer,
		serial: u32,
		surface: wl_surface,
		surface_x: wl_fixed_t,
		surface_y: wl_fixed_t,
	),
	leave:  proc "c" (data: rawptr, pointer: wl_pointer, serial: u32, surface: wl_surface),
	motion: proc "c" (
		data: rawptr,
		pointer: wl_pointer,
		time: u32,
		surface_x: wl_fixed_t,
		surface_y: wl_fixed_t,
	),
	button: proc "c" (
		data: rawptr,
		pointer: wl_pointer,
		serial: u32,
		time: u32,
		button: u32,
		state: Button_states,
	),
	axis:   proc "c" (
		data: rawptr,
		pointer: wl_pointer,
		time: u32,
		axis: Pointer_axis,
		value: wl_fixed_t,
	),
}


foreign wl {
	wl_display_connect :: proc(name: cstring) -> wl_display ---
	wl_display_disconnect :: proc(display: wl_display) ---
	wl_display_roundtrip :: proc(display: wl_display) -> c.int ---
	wl_display_dispatch :: proc(display: wl_display) -> c.int ---
	wl_display_get_fd :: proc(display: wl_display) -> c.int ---
	wl_display_flush :: proc(display: wl_display) -> c.int ---
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
	shim_wl_shm_create_pool :: proc(shm: wl_shm, fd: i32, size: i32) -> wl_shm_pool ---
	shim_wl_shm_pool_create_buffer :: proc(pool: wl_shm_pool, offset: i32, width: i32, height: i32, stride: i32, format: u32) -> wl_buffer ---
	shim_wl_surface_attach :: proc(surface: wl_surface, buffer: wl_buffer, x: i32, y: i32) ---
	shim_wl_surface_damage_buffer :: proc(surface: wl_surface, x: i32, y: i32, width: i32, height: i32) ---
	shim_bind_seat :: proc(registry: wl_registry, name: u32, version: u32) -> wl_seat ---
	shim_wl_seat_add_listener :: proc(seat: wl_seat, listener: ^wl_seat_listener, data: rawptr) -> c.int ---
	shim_wl_seat_get_pointer :: proc(seat: wl_seat) -> wl_pointer ---
	shim_wl_pointer_add_listener :: proc(pointer: wl_pointer, listener: ^wl_pointer_listener, data: rawptr) -> c.int ---
}
