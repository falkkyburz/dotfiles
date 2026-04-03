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
i_music='󰝚'
i_play='󰐊'
i_pause='󰏤'
i_prev='󰒮'
i_next='󰒭'
i_net_off='󰤭'

battery_icon() {
  local c="${1:-0}"
  [[ "$c" =~ ^[0-9]+$ ]] || c=0
  ((c < 0)) && c=0
  ((c > 100)) && c=100
  ((c <= 5)) && { printf '󰂎'; return; }
  ((c <= 15)) && { printf '󰁺'; return; }
  ((c <= 25)) && { printf '󰁻'; return; }
  ((c <= 35)) && { printf '󰁼'; return; }
  ((c <= 45)) && { printf '󰁽'; return; }
  ((c <= 55)) && { printf '󰁾'; return; }
  ((c <= 65)) && { printf '󰁿'; return; }
  ((c <= 75)) && { printf '󰂀'; return; }
  ((c <= 85)) && { printf '󰂁'; return; }
  ((c <= 95)) && { printf '󰂂'; return; }
  printf '󰁹'
}

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
  local b c s icon src
  for b in /sys/class/power_supply/BAT*; do
    [[ -d "$b" ]] || continue
    read -r c < "$b/capacity" || continue
    read -r s < "$b/status" || s="?"
    icon="$(battery_icon "$c")"
    if [[ "$s" == Charging ]]; then
      printf 'bat ↯%s %s%% %s' "$icon" "$c"
    else
      printf 'bat %s %s%% %s' "$icon" "$c"
    fi
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

is_vpn_iface() {
  local iface="${1:-}"
  [[ "$iface" =~ ^(tun[0-9]*|tap[0-9]*|wg[0-9]*|ppp[0-9]*|nordlynx|tailscale0|zt[a-zA-Z0-9]+)$ ]]
}

non_vpn_default_dev() {
  local dev metric
  while IFS='|' read -r metric dev; do
    [[ -z "${dev:-}" ]] && continue
    if ! is_vpn_iface "$dev"; then
      printf '%s' "$dev"
      return
    fi
  done < <(
    ip -4 route show table main default 2>/dev/null |
      awk '{
        d=""; m=0; has_m=0;
        for(i=1;i<=NF;i++) {
          if($i=="dev") d=$(i+1);
          else if($i=="metric") { m=$(i+1); has_m=1; }
        }
        if(d!="") {
          if(!has_m) m=0;
          print m"|"d;
        }
      }' |
      sort -t'|' -n -k1,1
  )
}

wifi() {
  local route_dev src ssid sig ip icon='󰤮' vpn_suffix='' display_dev
  IFS='|' read -r route_dev src < <(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev")d=$(i+1); else if($i=="src")s=$(i+1)} if(d!="") print d"|"s; exit}')
  if [[ -z "${route_dev:-}" ]]; then
    printf '%s' "$i_net_off"
    return
  fi

  display_dev="$route_dev"
  if is_vpn_iface "$route_dev"; then
    vpn_suffix=' (vpn)'
    display_dev="$(non_vpn_default_dev)"
    [[ -z "${display_dev:-}" ]] && display_dev="$route_dev"
  fi

  if [[ -d "/sys/class/net/$display_dev/wireless" ]]; then
    if ! command -v nmcli >/dev/null 2>&1; then printf '%s%s' "$icon" "$vpn_suffix"; return; fi
    ssid="$(nmcli -g GENERAL.CONNECTION device show "$display_dev" 2>/dev/null | awk 'NR==1{print; exit}')"
    sig="$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$display_dev" --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')"
    if [[ -n "${ssid:-}" && "$sig" =~ ^[0-9]+$ ]]; then
      ((sig < 20)) && icon='󰤯'
      ((sig >= 20 && sig < 40)) && icon='󰤟'
      ((sig >= 40 && sig < 60)) && icon='󰤢'
      ((sig >= 60 && sig < 80)) && icon='󰤥'
      ((sig >= 80)) && icon='󰤨'
      printf '%s %s%s' "$icon" "$ssid" "$vpn_suffix"
    else
      printf '%s%s' "$icon" "$vpn_suffix"
    fi
    return
  fi
  ip="${src:-$(ip -4 -o addr show dev "$route_dev" scope global 2>/dev/null | awk 'NR==1{split($4,a,"/"); print a[1]}')}"
  [[ -n "${ip:-}" ]] && printf '󰈀 %s%s' "$ip" "$vpn_suffix" || printf '󰈀 %s%s' "$display_dev" "$vpn_suffix"
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

title() {
  local info="$(hyprctl activewindow -j | jq -r '.title' 2>/dev/null)"
  if [[ -n "$info" && "$info" != "null" ]]; then
    printf '%s' "$info"
  fi
}

media() {
  local info="$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null)"
  local status="$(playerctl status 2>/dev/null)"
  if [[ -n "$info" && "$status" == "Playing" ]]; then
    clean="$(printf '%s' "$info" | tr -cd '[:alpha:][:space:]-:')"
    printf '%s %s' "$i_music" "$status: $clean"
  fi
}

short() {
  local s="$1" n="${2:-18}"
  ((${#s} > n)) && printf '%s…' "${s:0:n-1}" || printf '%s' "$s"
}

  ws_s="$(ws)"; mem_s="$(mem)"; wifi_s="$(wifi)"; bt_s="$(bt)"; bat_s="$(bat)"; tim="$(date '+%a %Y-%m-%d %H:%M')"; title_s="$(title)"; med_s="$(media)"
cpu; cpu_s="$REPLY"
wifi_every=15
bat_every=5
bt_every=5
next_wifi=0
next_bat=0
next_bt=0

while true; do
  now="$(date +%s)"
  ntim="$(date '+%a %Y-%m-%d %H:%M')"
  nw="$(ws)"

  if [[ "$nw" != "$ws_s" ]]; then
    ws_s="$nw"; redraw=1
  fi
  # update workspace, cpu, memory
  if [[ "${last:-}" != "$now" ]]; then
    last="$now"; ws_s="$(ws)"; cpu; cpu_s="$REPLY"; mem_s="$(mem)"; med_s="$(media)"; title_s="$(title)"; redraw=1
  fi
  # update time
  if [[ "$ntim" != "$tim" ]]; then
    tim="$ntim"; redraw=1
  fi
  # update network
  if (( now >= next_wifi )); then
    nwifi="$(wifi)"; [[ "$nwifi" != "$wifi_s" ]] && redraw=1; wifi_s="$nwifi"; next_wifi=$((now + wifi_every))
  fi
  # update bluetooth
  if (( now >= next_bt )); then
    nbt="$(bt)"; [[ "$nbt" != "$bt_s" ]] && redraw=1; bt_s="$nbt"; next_bt=$((now + bt_every))
  fi
  # update battery
  if (( now >= next_bat )); then
    nbat="$(bat)"; [[ "$nbat" != "$bat_s" ]] && redraw=1; bat_s="$nbat"; next_bat=$((now + bat_every))
  fi
  # draw
  if (( ${redraw:-1} )); then
printf '%s %s %s|%s|%s %s  %s %s  %s  %s %s  %s %s\n' "$ws_s" "$(short "$title_s" 40)" "$(short "$med_s" 40)" "$tim" "$i_cpu" "${cpu_s#cpu }" "$i_mem" "${mem_s#ram }" "$(short "$wifi_s" 18)" "$i_bt" "$(short "$bt_s" 40)" "${bat_s#bat }"
    redraw=0
  fi
  sleep 0.15
done | minibar
