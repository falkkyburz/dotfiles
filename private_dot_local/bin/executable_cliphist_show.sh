#!/usr/bin/env bash
set -euo pipefail

selection="$(
  cliphist list |
    hyprlauncher --dmenu
)"

[ -n "${selection:-}" ] || exit 0

printf '%s\n' "$selection" |
  cliphist decode |
  wl-copy
