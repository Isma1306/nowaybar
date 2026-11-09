#include <wayland-client.h>
#include "xdg-shell.h"
#include "wlr-layer-shell-unstable-v1.h"

struct wl_registry *shim_wl_display_get_registry(struct wl_display *wl_display)
{
  return wl_display_get_registry(wl_display);
}

int shim_wl_registry_add_listener(struct wl_registry *wl_registry, const struct wl_registry_listener *listener, void *data)
{
  return wl_registry_add_listener(wl_registry, listener, data);
}

struct wl_compositor *shim_bind_compositor(struct wl_registry *registry, uint32_t name, uint32_t version)
{
  return wl_registry_bind(registry, name, &wl_compositor_interface, version);
}

struct wl_shm *shim_bind_shm(struct wl_registry *registry, uint32_t name, uint32_t version)
{
  return wl_registry_bind(registry, name, &wl_shm_interface, version);
}

struct zwlr_layer_shell_v1 *shim_bind_layer_shell(struct wl_registry *registry, uint32_t name, uint32_t version)
{
  return wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, version);
}

struct wl_surface *shim_wl_compositor_create_surface(struct wl_compositor *compositor)
{
  return wl_compositor_create_surface(compositor);
}

struct zwlr_layer_surface_v1 *shim_zwlr_layer_shell_v1_get_layer_surface(struct zwlr_layer_shell_v1 *zwlr_layer_shell_v1, struct wl_surface *surface, struct wl_output *output, uint32_t layer, const char *namespace)
{
  return zwlr_layer_shell_v1_get_layer_surface(zwlr_layer_shell_v1, surface, output, layer, namespace);
}

void shim_zwlr_layer_surface_v1_set_size(struct zwlr_layer_surface_v1 *layer_surface, uint32_t width, uint32_t height)
{
  zwlr_layer_surface_v1_set_size(layer_surface, width, height);
}

void shim_zwlr_layer_surface_v1_set_anchor(struct zwlr_layer_surface_v1 *layer_surface, uint32_t anchor)
{
  zwlr_layer_surface_v1_set_anchor(layer_surface, anchor);
}

void shim_zwlr_layer_surface_v1_set_exclusive_zone(struct zwlr_layer_surface_v1 *layer_surface, int32_t zone)
{
  zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, zone);
}

void shim_wl_surface_commit(struct wl_surface *surface)
{
  wl_surface_commit(surface);
}

int shim_zwlr_layer_surface_v1_add_listener(struct zwlr_layer_surface_v1 *zwlr_layer_surface_v1,
                                            const struct zwlr_layer_surface_v1_listener *listener, void *data)
{
  return zwlr_layer_surface_v1_add_listener(zwlr_layer_surface_v1, listener, data);
}

void shim_zwlr_layer_surface_v1_ack_configure(struct zwlr_layer_surface_v1 *zwlr_layer_surface_v1, uint32_t serial)
{
  zwlr_layer_surface_v1_ack_configure(zwlr_layer_surface_v1, serial);
}
