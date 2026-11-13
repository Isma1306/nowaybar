#!/usr/bin/env bash
# Rebuild and restart the bar whenever a source file is saved.
cd "$(dirname "$0")"

pid=""

stop_bar() {
	if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
		kill "$pid"
		wait "$pid" 2>/dev/null
	fi
	pid=""
}

trap 'stop_bar; exit 0' INT TERM

while true; do
	stop_bar
	if ./build.sh; then
		echo "==> starting bar"
		./build/bar &
		pid=$!
	else
		echo "==> build failed, waiting for changes"
	fi

	inotifywait -qq -r -e close_write,moved_to,create src shim protocols
done
