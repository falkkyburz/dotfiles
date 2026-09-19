#!/bin/bash
set -u
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

set_mode() {
  local mode="$1"
  if ! command -v gsettings >/dev/null 2>&1; then
    echo "gsettings not found; cannot set color-scheme" >&2
    return 1
  fi
  gsettings set org.gnome.desktop.interface color-scheme "$mode"
  echo "color-scheme -> $mode"
}

case "${1:-toggle}" in
  dark)  set_mode prefer-dark ;;
  light) set_mode prefer-light ;;
  toggle)
    current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'" || true)
    if [ "${current:-}" = "prefer-dark" ]; then
      set_mode prefer-light
    else
      set_mode prefer-dark
    fi
    ;;
  *) echo "usage: $0 [toggle|dark|light]" >&2; exit 1 ;;
esac
