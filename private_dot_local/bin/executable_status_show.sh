#!/usr/bin/env bash

set -u
set -o pipefail

PANEL_WIDTH=44
LABEL_WIDTH=11
ETHERNET_IFACE_WIDTH=12

if ! [[ "$PANEL_WIDTH" =~ ^[0-9]+$ ]]; then
  printf 'Invalid panel width: %s\n' "$PANEL_WIDTH" >&2
  exit 1
fi

truncate_text() {
  local text="$1"
  local max_width="$2"

  if ((${#text} <= max_width)); then
    printf '%s' "$text"
    return
  fi

  if ((max_width <= 3)); then
    printf '%.*s' "$max_width" "$text"
    return
  fi

  printf '%s...' "${text:0:max_width-3}"
}

render_row() {
  local label="$1"
  local value="$2"
  local value_width=$((PANEL_WIDTH - LABEL_WIDTH - 1))

  value="$(truncate_text "$value" "$value_width")"
  printf '%-*s %s\n' "$LABEL_WIDTH" "$label" "$value"
}

value_width() {
  printf '%s' "$((PANEL_WIDTH - 4 - LABEL_WIDTH - 2))"
}

read_battery_dir() {
  local dir

  for dir in /sys/class/power_supply/BAT*; do
    if [[ -d "$dir" ]]; then
      printf '%s' "$dir"
      return 0
    fi
  done

  return 1
}

get_date_row() {
  DATE_VALUE="$(date '+%F W%V %A')"
}

get_time_row() {
  TIME_VALUE="$(date '+%T')"
}

get_battery_row() {
  local battery_dir capacity status

  BATTERY_VISIBLE=0
  if ! battery_dir="$(read_battery_dir)"; then
    return
  fi

  capacity="$(<"$battery_dir/capacity")"
  status="$(<"$battery_dir/status")"

  BATTERY_VISIBLE=1
  BATTERY_VALUE="${capacity}%  ${status}"
}

get_wifi_signal() {
  local device="$1"
  local signal

  signal="$(
    nmcli -f AP device show "$device" 2>/dev/null | awk -F': *' '
      /^AP\[[0-9]+\]\.IN-USE:/ { active = ($2 == "*"); next }
      active && /^AP\[[0-9]+\]\.SIGNAL:/ { print $2; exit }
    '
  )"

  if [[ "$signal" =~ ^[0-9]+$ ]]; then
    printf '%s' "$signal"
  fi
}

get_active_interface() {
  ip route show default 2>/dev/null | awk 'NR==1 {print $5}'
}

get_ipv4_address() {
  local device="$1"
  ip -4 -o addr show dev "$device" 2>/dev/null | awk 'NR==1 {print $4}' | cut -d/ -f1
}

trim_ssid() {
  local ssid="$1"
  local suffix="$2"
  local available

  available=$(($(value_width) - ${#suffix}))
  if ((available < 1)); then
    printf '%s' "$suffix"
    return
  fi

  printf '%s%s' "$(truncate_text "$ssid" "$available")" "$suffix"
}

trim_interface_name() {
  local iface="$1"
  printf '%s' "$(truncate_text "$iface" "$ETHERNET_IFACE_WIDTH")"
}

get_wifi_row() {
  local name signal suffix

  WIFI_VALUE="N/A"

  if [[ -z "$ACTIVE_INTERFACE" || ! -d "/sys/class/net/$ACTIVE_INTERFACE/wireless" ]]; then
    return
  fi

  if ! command -v nmcli >/dev/null 2>&1; then
    WIFI_VALUE="Unavailable"
    return
  fi

  name="$(nmcli -g GENERAL.CONNECTION device show "$ACTIVE_INTERFACE" 2>/dev/null | head -n1)"
  signal="$(get_wifi_signal "$ACTIVE_INTERFACE")"

  if [[ -z "$name" ]]; then
    WIFI_VALUE="Connected"
    return
  fi

  if [[ -n "$signal" ]]; then
    suffix=" (${signal}%)"
    WIFI_VALUE="$(trim_ssid "$name" "$suffix")"
  else
    WIFI_VALUE="$name"
  fi
}

get_network_row() {
  local address iface_display

  NETWORK_VALUE="N/A"

  if [[ -z "$ACTIVE_INTERFACE" ]]; then
    return
  fi

  iface_display="$(trim_interface_name "$ACTIVE_INTERFACE")"
  address="$(get_ipv4_address "$ACTIVE_INTERFACE")"

  NETWORK_VALUE="$iface_display"
  if [[ -n "$address" ]]; then
    NETWORK_VALUE+=" $address"
  fi
}

get_volume_row() {
  local output volume

  VOLUME_VALUE="Unavailable"

  if ! command -v wpctl >/dev/null 2>&1; then
    return
  fi

  output="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    return
  fi

  if [[ "$output" == *"[MUTED]"* ]]; then
    VOLUME_VALUE="Muted"
    return
  fi

  volume="$(awk '/Volume:/ {printf "%d", $2 * 100}' <<<"$output")"
  if [[ -n "$volume" ]]; then
    VOLUME_VALUE="${volume}%"
  fi
}

get_brightness_row() {
  local output brightness

  BRIGHTNESS_VALUE="Unavailable"

  if ! command -v brightnessctl >/dev/null 2>&1; then
    return
  fi

  output="$(brightnessctl -m 2>/dev/null || true)"
  brightness="$(awk -F, '{print $4}' <<<"$output")"
  brightness="${brightness%%%}"

  if [[ "$brightness" =~ ^[0-9]+$ ]]; then
    BRIGHTNESS_VALUE="${brightness}%"
  fi
}

draw_panel() {
  render_row "Date" "$DATE_VALUE"
  render_row "Time" "$TIME_VALUE"
  if ((BATTERY_VISIBLE)); then
    render_row "Battery" "$BATTERY_VALUE"
  fi
  render_row "WiFi" "$WIFI_VALUE"
  render_row "Network" "$NETWORK_VALUE"
  render_row "Volume" "$VOLUME_VALUE"
  render_row "Brightness" "$BRIGHTNESS_VALUE"
}

collect_rows() {
  ACTIVE_INTERFACE="$(get_active_interface)"
  get_date_row
  get_time_row
  get_battery_row
  get_wifi_row
  get_network_row
  get_volume_row
  get_brightness_row
}

main() {
  if ((PANEL_WIDTH < 36)); then
    printf 'Invalid panel width: %s\n' "$PANEL_WIDTH" >&2
    exit 1
  fi

  collect_rows
  draw_panel
}

main

while IFS= read -rsn1 key; do
  break
done
