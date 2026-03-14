#!/usr/bin/env bash
set -euo pipefail

selection="$(
  cliphist list |
    fuzzel --dmenu --prompt='Clipboard: '
)"

[ -n "${selection:-}" ] || exit 0

printf '%s\n' "$selection" |
  cut -f1 |
  cliphist decode |
  wl-copy
