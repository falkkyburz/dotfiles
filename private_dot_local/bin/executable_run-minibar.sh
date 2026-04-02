#!/usr/bin/env bash
set -euo pipefail

if ! command -v minibar >/dev/null 2>&1; then
  printf 'minibar command not found in PATH\n' >&2
  exit 1
fi

i_cpu='󰍛'
i_mem='󰘚'
i_bt='󰂱'
i_bat='󰁹'

ws() {
  local l id
  IFS= read -r l < <(hyprctl activeworkspace 2>/dev/null || true)
  id="${l#workspace ID }"; id="${id%% *}"
  [[ "$id" =~ ^[0-9]+$ ]] && printf '[%s]' "$id" || printf '[?]'
}

mem() {
  local k v total=0 avail=0 used=0 pct=0
  while read -r k v _; do
    [[ "$k" == "MemTotal:" ]] && total=$v
    [[ "$k" == "MemAvailable:" ]] && avail=$v
  done < /proc/meminfo
  used=$((total - avail)); pct=$((used * 100 / total))
  printf 'ram %s%%' "$pct"
}

bat() {
  local b c s
  for b in /sys/class/power_supply/BAT*; do
    [[ -d "$b" ]] || continue
    read -r c < "$b/capacity" || continue
    read -r s < "$b/status" || s="?"
    [[ "$s" == Charging ]] && printf 'bat ↯ %s%%' "$c" || printf 'bat %s%%' "$c"
    return
  done
  printf 'bat n/a'
}

bt() {
  local _ mac name out=""
  while read -r _ mac name; do
    [[ -z "$name" ]] && continue
    out+="${out:+, }$name"
  done < <(bluetoothctl devices Connected 2>/dev/null || true)
  printf '%s' "${out:--}"
}

wifi() {
  local ssid sig icon='󰤮'
  if ! command -v nmcli >/dev/null 2>&1; then printf '-'; return; fi
  IFS='|' read -r ssid sig < <(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null |
    awk -F: '$1=="yes"{print $2"|"$3; exit}')
  if [[ -n "${ssid:-}" && "$sig" =~ ^[0-9]+$ ]]; then
    ((sig < 20)) && icon='󰤯'
    ((sig >= 20 && sig < 40)) && icon='󰤟'
    ((sig >= 40 && sig < 60)) && icon='󰤢'
    ((sig >= 60 && sig < 80)) && icon='󰤥'
    ((sig >= 80)) && icon='󰤨'
    printf '%s %s' "$icon" "$ssid"
  elif nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$2=="ethernet"&&$3=="connected"{f=1} END{exit !f}'; then
    printf '󰈀 Ethernet'
  else
    printf '%s' "$icon"
  fi
}

short() {
  local s="$1" n="${2:-18}"
  ((${#s} > n)) && printf '%s…' "${s:0:n-1}" || printf '%s' "$s"
}

pt=0
pi=0
cpu() {
  local _ u n s i w irq sirq st g gn total dt di
  read -r _ u n s i w irq sirq st g gn < /proc/stat
  total=$((u + n + s + i + w + irq + sirq + st + g + gn))
  if ((pt == 0)); then
    pt=$total; pi=$i; REPLY='cpu 0%'; return
  fi
  dt=$((total - pt)); di=$((i - pi)); pt=$total; pi=$i
  ((dt > 0)) && REPLY="cpu $(((dt - di) * 100 / dt))%" || REPLY='cpu ?'
}

ws_s="$(ws)"; mem_s="$(mem)"; wifi_s="$(wifi)"; bt_s="$(bt)"; bat_s="$(bat)"; clk="$(date '+%a %Y-%m-%d %H:%M')"
cpu; cpu_s="$REPLY"
wifi_every=15
bat_every=30
bt_every=5
next_wifi=0
next_bat=0
next_bt=0

while true; do
  now="$(date +%s)"
  nclk="$(date '+%a %Y-%m-%d %H:%M')"
  nw="$(ws)"
  if [[ "$nw" != "$ws_s" ]]; then
    ws_s="$nw"; redraw=1
  fi
  if [[ "${last:-}" != "$now" ]]; then
    last="$now"; ws_s="$(ws)"; cpu; cpu_s="$REPLY"; mem_s="$(mem)"; redraw=1
  fi
  if [[ "$nclk" != "$clk" ]]; then
    clk="$nclk"; redraw=1
  fi
  if (( now >= next_wifi )); then
    nwifi="$(wifi)"; [[ "$nwifi" != "$wifi_s" ]] && redraw=1; wifi_s="$nwifi"; next_wifi=$((now + wifi_every))
  fi
  if (( now >= next_bt )); then
    nbt="$(bt)"; [[ "$nbt" != "$bt_s" ]] && redraw=1; bt_s="$nbt"; next_bt=$((now + bt_every))
  fi
  if (( now >= next_bat )); then
    nbat="$(bat)"; [[ "$nbat" != "$bat_s" ]] && redraw=1; bat_s="$nbat"; next_bat=$((now + bat_every))
  fi
  if (( ${redraw:-1} )); then
    printf '%s|%s|%s %s  %s %s  %s  %s %s  %s %s\n' "$ws_s" "$clk" "$i_cpu" "${cpu_s#cpu }" "$i_mem" "${mem_s#ram }" "$(short "$wifi_s" 18)" "$i_bt" "$bt_s" "$i_bat" "${bat_s#bat }"
    redraw=0
  fi
  sleep 0.15
done | minibar
