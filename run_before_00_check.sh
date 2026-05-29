#!/usr/bin/bash

if [[ -f "$HOME/.config/hypr/hyprland.lua" ]] &&
   command -v hyprctl >/dev/null &&
   [[ -n $(hyprctl configerrors) ]]; then
    echo "Error: Hyprland config errors.";
    exit 1;
fi


