#!/bin/sh
# The Line's login screen: what greetd's session command runs inside cage (see /etc/greetd/start-greeter.sh).
# Its state (cache, logs) goes under /run/greetd; it reads the last user's accent from their config.json.
dir="$(dirname "$(readlink -f "$0")")"

export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QSG_RENDER_LOOP=basic
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/greetd}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/run/greetd/cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-/run/greetd/state}"
export XCURSOR_THEME=TheLine
mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

exec qs -p "$dir"
