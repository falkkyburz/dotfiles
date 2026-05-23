#!/bin/bash

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

if command -v gsettings 2>/dev/null; then
  mode=$(gsettings get org.gnome.desktop.interface color-scheme)
  mode=${mode//\'/}
  echo "Current mode $mode"
fi

if [[ $mode == "prefer-dark" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme prefer-light
  notify-send "Light Mode"
elif [[ $mode == "prefer-light" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme prefer-dark
  notify-send "Dark Mode"
fi
