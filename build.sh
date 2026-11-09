#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

GEN=build/shim

#   -Wall      warn about suspicious code
#   -O2        optimize
#   -I $GEN    also look in build/shim/ for #include "..." (generated headers)
CFLAGS="-Wall -O2 -I $GEN"

mkdir -p $GEN

echo "==> generating protocol code"
for proto in xdg-shell wlr-layer-shell-unstable-v1; do
	wayland-scanner client-header protocols/$proto.xml $GEN/$proto.h
	wayland-scanner private-code  protocols/$proto.xml $GEN/$proto.c
done

echo "==> compiling C shim"
cc $CFLAGS -c shim/shim.c                        -o $GEN/shim.o
cc $CFLAGS -c $GEN/xdg-shell.c                   -o $GEN/xdg-shell.o
cc $CFLAGS -c $GEN/wlr-layer-shell-unstable-v1.c -o $GEN/wlr-layer-shell-unstable-v1.o

echo "==> bundling libshim.a"
rm -f $GEN/libshim.a
ar rcs $GEN/libshim.a $GEN/shim.o $GEN/xdg-shell.o $GEN/wlr-layer-shell-unstable-v1.o

#   -out:build/bar  output executable
#   -debug          include debug info
echo "==> building odin"
odin build src -out:build/bar -debug

echo "==> done"
