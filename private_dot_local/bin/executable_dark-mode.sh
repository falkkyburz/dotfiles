#!/bin/bash

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

if command -v gsettings >/dev/null 2>&1; then
  mode=$(gsettings get org.gnome.desktop.interface color-scheme)
  mode=${mode//\'/}
  echo "Current mode $mode"
fi

case "$mode" in
  prefer-dark)
    gsettings set org.gnome.desktop.interface color-scheme prefer-light
    notify-send "Light Mode"
    ;;
  prefer-light|default)
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    notify-send "Dark Mode"
    ;;
esac
