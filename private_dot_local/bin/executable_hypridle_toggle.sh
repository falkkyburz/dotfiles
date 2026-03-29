#!/usr/bin/env bash
set -euo pipefail

if pgrep -u "$UID" -x hypridle >/dev/null; then
    pkill -u "$UID" -x hypridle
    notify-send "hypridle" "disabled"
else
    hypridle >/dev/null 2>&1 &
    sleep 0.1
    if pgrep -u "$UID" -x hypridle >/dev/null; then
        notify-send "hypridle" "enabled"
    else
        notify-send "hypridle" "failed to start"
        exit 1
    fi
fi
