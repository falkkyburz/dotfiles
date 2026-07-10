#!/usr/bin/env bash
set -euo pipefail

win_pid="$(hyprctl activewindow -j | jq -r '.pid // empty')"
[[ -n "${win_pid:-}" ]] || exec printf '%s\n' "$HOME"

# Kitty also has helper children such as __atexit__ and __watch_conf__.  The
# shell is the direct child attached to a pseudo-terminal, so select by TTY
# instead of relying on the arbitrary order returned by pgrep.
shell_pid="$(
    ps --ppid "$win_pid" -o pid=,tty= 2>/dev/null |
        awk '$2 ~ /^pts\// { print $1; exit }'
)"
[[ -n "${shell_pid:-}" ]] || exec printf '%s\n' "$HOME"

cwd="$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null || true)"
[[ -d "${cwd:-}" ]] && printf '%s\n' "$cwd" || printf '%s\n' "$HOME"
