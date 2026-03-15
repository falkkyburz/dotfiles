#!/usr/bin/env bash
set -euo pipefail

choice="$(
  printf "lock\nreboot\nshutdown\nlogout\nsuspend\n" |
    hyprlauncher --dmenu
)"

case "${choice:-}" in
lock)
  loginctl lock-session
  ;;
reboot)
  systemctl reboot
  ;;
shutdown)
  systemctl poweroff
  ;;
logout)
  hyprctl dispatch exit
  ;;
suspend)
  systemctl suspend
  ;;
*)
  exit 0
  ;;
esac
