#!/usr/bin/bash

hyprland_config="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$hyprland_config" ]] &&
   [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] &&
   command -v hyprctl >/dev/null 2>&1 &&
   [[ -n $(hyprctl configerrors 2>/dev/null || true) ]]; then
    for config in "$hyprland_config" "$HOME/.config/hypr/hyprland-util.lua"; do
        # Render first so a missing local module can also be repaired, without
        # mistaking a chezmoi rendering failure for a pending update.
        desired=$(chezmoi cat -- "$config" 2>/dev/null) || continue
        if [[ ! -f "$config" ]] || [[ "$desired" != "$(cat -- "$config")" ]]; then
            echo "Warning: Hyprland has config errors; applying the pending config update anyway."
            exit 0
        fi
    done

    echo "Error: Hyprland config errors and no config update is pending."
    exit 1
fi
