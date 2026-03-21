#!/usr/bin/env bash
set -euo pipefail

win_pid="$(hyprctl activewindow -j | jq -r '.pid // empty')"
[[ -n "${win_pid:-}" ]] || exec printf '%s\n' "$HOME"

shell_pid="$(pgrep -P "$win_pid" | tail -n1 || true)"
[[ -n "${shell_pid:-}" ]] || exec printf '%s\n' "$HOME"

cwd="$(readlink -f "/proc/$shell_pid/cwd" 2>/dev/null || true)"
[[ -d "${cwd:-}" ]] && printf '%s\n' "$cwd" || printf '%s\n' "$HOME"
