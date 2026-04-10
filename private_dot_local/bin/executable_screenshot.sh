#!/usr/bin/env bash
set -euo pipefail

menu() {
  hyprlauncher --dmenu
}

wait_for_launcher_to_disappear() {
  # Give hyprlauncher a moment to unmap before capture.
  # Increase slightly if it still shows up in screenshots.
  sleep 0.18
}

take_region() {
  wait_for_launcher_to_disappear
  local geom
  geom="$(slurp)" || return 1
  grim -g "$geom" - | satty --filename -
}

take_current_monitor() {
  wait_for_launcher_to_disappear
  local mon
  mon="$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' | head -n1)"
  [[ -n "${mon:-}" && "$mon" != "null" ]] || return 1
  grim -o "$mon" - | satty --filename -
}

take_window() {
  local addr="$1"
  local geom

  wait_for_launcher_to_disappear

  geom="$(
    hyprctl clients -j |
      jq -r --arg addr "$addr" '
        .[]
        | select(.address == $addr)
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
      '
  )"

  [[ -n "${geom:-}" && "$geom" != "null" ]] || return 1
  grim -g "$geom" - | satty --filename -
}

build_menu() {
  local ws
  ws="$(hyprctl activeworkspace -j | jq -r '.id')"

  printf '%s\n' "Region"
  printf '%s\n' "Window: focused"
  printf '%s\n' "Full screen"

  hyprctl clients -j |
    jq -r --argjson ws "$ws" '
      map(
        select(
          .workspace.id == $ws and
          (.mapped // true) and
          (.hidden // false | not) and
          (.at[0] != null) and
          (.size[0] != null) and
          (.size[0] > 1) and
          (.size[1] > 1)
        )
      )
      | sort_by(.focusHistoryID // 999999)
      | .[]
      | "Window: " + ((.class // "unknown") + " — " + (.title // "untitled") | gsub("[\r\n\t]+"; " "))
    '
}

resolve_window_address() {
  local label="$1"
  local ws
  ws="$(hyprctl activeworkspace -j | jq -r '.id')"

  if [[ "$label" == "Window: focused" ]]; then
    hyprctl activewindow -j | jq -r '.address'
    return
  fi

  hyprctl clients -j |
    jq -r --argjson ws "$ws" --arg label "${label#Window: }" '
      map(
        select(
          .workspace.id == $ws and
          (.mapped // true) and
          (.hidden // false | not) and
          (.at[0] != null) and
          (.size[0] != null) and
          (.size[0] > 1) and
          (.size[1] > 1)
        )
      )
      | sort_by(.focusHistoryID // 999999)
      | map(
          select(
            (((.class // "unknown") + " — " + (.title // "untitled")) | gsub("[\r\n\t]+"; " ")) == $label
          )
        )
      | .[0].address // empty
    '
}

main() {
  local choice addr

  choice="$(build_menu | menu)" || exit 0
  [[ -n "${choice:-}" ]] || exit 0

  case "$choice" in
    "Region")
      take_region
      ;;
    "Full screen")
      take_current_monitor
      ;;
    Window:*)
      addr="$(resolve_window_address "$choice")"
      [[ -n "${addr:-}" && "$addr" != "null" ]] || exit 1
      take_window "$addr"
      ;;
    *)
      exit 0
      ;;
  esac
}

main "$@"
