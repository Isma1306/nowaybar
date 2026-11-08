#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

#   -Wall    warn about suspicious code
#   -O2      optimize
#   -I shim  also look in shim/ for #include "..."
CFLAGS="-Wall -O2 -I shim"

mkdir -p build/shim

echo "==> compiling C shim"
cc $CFLAGS -c shim/shim.c                         -o build/shim/shim.o
cc $CFLAGS -c shim/xdg-shell.c                    -o build/shim/xdg-shell.o
cc $CFLAGS -c shim/wlr-layer-shell-unstable-v1.c  -o build/shim/wlr-layer-shell-unstable-v1.o

echo "==> bundling libshim.a"
rm -f build/shim/libshim.a
ar rcs build/shim/libshim.a build/shim/shim.o build/shim/xdg-shell.o build/shim/wlr-layer-shell-unstable-v1.o

#   -out:build/bar  output executable
#   -debug          include debug info
# echo "==> building odin"
# odin build src -out:build/bar -debug

echo "==> done"
