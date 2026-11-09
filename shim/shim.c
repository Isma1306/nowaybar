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