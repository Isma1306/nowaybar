# nowaybar
a tiny non customizable bar for wayland written in Odin

## Requirements

- [Odin](https://odin-lang.org)
- libwayland-client and `wayland-scanner` (the `wayland` package on most distros)
- A C compiler (`cc`) and `ar`
- A Wayland compositor that supports `wlr-layer-shell` (Hyprland, Sway, ...)

## Build

```sh
./build.sh
./build/bar
```
