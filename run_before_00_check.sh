#!/usr/bin/bash

hyprland_config="$HOME/.config/hypr/hyprland.lua"

if [[ -f "$hyprland_config" ]] &&
   [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] &&
   command -v hyprctl >/dev/null 2>&1 &&
   [[ -n $(hyprctl configerrors 2>/dev/null || true) ]]; then
    pending_diff=$(chezmoi diff --no-pager -- "$hyprland_config" 2>/dev/null || true)
    if [[ -n "$pending_diff" ]]; then
        echo "Warning: Hyprland has config errors; applying the pending config update anyway."
        exit 0
    fi

    echo "Error: Hyprland config errors and no config update is pending."
    exit 1;
fi
