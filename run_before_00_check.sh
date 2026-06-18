#!/usr/bin/bash

if [[ -f "$HOME/.config/hypr/hyprland.lua" ]] &&
   [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] &&
   command -v hyprctl >/dev/null 2>&1 &&
   [[ -n $(hyprctl configerrors 2>/dev/null || true) ]]; then
    echo "Error: Hyprland config errors.";
    exit 1;
fi
