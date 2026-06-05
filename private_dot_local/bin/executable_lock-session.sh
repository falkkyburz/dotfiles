#!/usr/bin/env bash
set -u

lock_file="${XDG_RUNTIME_DIR:-/tmp}/lock-session.lock"
exec 9>"$lock_file"
flock -n 9 || exit 0

pgrep -x hyprlock >/dev/null 2>&1 && exit 0

hyprlock
status=$?

hyprctl dispatch dpms on >/dev/null 2>&1 || true
brightnessctl -r >/dev/null 2>&1 || true
brightnessctl -rd tpacpi:kbd_backlight >/dev/null 2>&1 || true

exit "$status"
