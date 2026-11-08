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