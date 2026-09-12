#!/usr/bin/bash

hyprland_config="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$hyprland_config" ]] &&
   [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] &&
   command -v hyprctl >/dev/null 2>&1; then
    # configerrors also contains failures from runtime `hyprctl eval` commands.
    # Existing errors must not block unrelated updates or config repairs.
    if errors=$(hyprctl configerrors 2>/dev/null) && [[ "$errors" =~ [^[:space:]] ]]; then
        printf 'Warning: Hyprland reports existing errors; continuing dotfiles apply:\n%s\n' "$errors" >&2
    fi
fi

exit 0
