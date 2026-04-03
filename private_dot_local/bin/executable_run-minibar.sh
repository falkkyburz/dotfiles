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

nmcli_net_state() {
  nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.ROUTE device show 2>/dev/null |
    awk -F: '
      function trim(s) {
        gsub(/^[[:space:]]+/, "", s)
        gsub(/[[:space:]]+$/, "", s)
        return s
      }
      function first_ipv4(s,    a) {
        split(s, a, "/")
        return a[1]
      }
      function finish_device(    m) {
        if (dev == "") return

        if (dtype == "wireguard") {
          if (wg_default_zero) vpn = 1
        }

        if ((dtype == "wifi" || dtype == "ethernet") && state ~ /^100 / && has_main_default) {
          m = metric
          if (!have_best || m < best_metric) {
            have_best = 1
            best_metric = m
            best_dev = dev
            best_type = dtype
            best_conn = conn
            best_ip = ip
          }
        }
      }

      BEGIN {
        have_best = 0
        vpn = 0
        best_metric = 0
      }

      /^GENERAL\.DEVICE:/ {
        finish_device()
        dev = $2
        dtype = ""
        state = ""
        conn = ""
        ip = ""
        has_main_default = 0
        metric = 1000000
        wg_default_zero = 0
        next
      }

      /^GENERAL\.TYPE:/ {
        dtype = $2
        next
      }

      /^GENERAL\.STATE:/ {
        state = $2
        next
      }

      /^GENERAL\.CONNECTION:/ {
        conn = $2
        next
      }

      /^IP4\.ADDRESS\[[0-9]+\]:/ {
        if (ip == "") ip = first_ipv4($2)
        next
      }

      /^IP4\.ROUTE\[[0-9]+\]:/ {
        if ($2 !~ /dst = 0\.0\.0\.0\/0/) next
        if (dtype == "wireguard" && $2 ~ /mt = 0([, ]|$)/) wg_default_zero = 1

        if ($2 ~ /table=/) next

        has_main_default = 1
        if (match($2, /mt = [0-9]+/)) {
          metric = substr($2, RSTART + 5, RLENGTH - 5) + 0
        } else {
          metric = 0
        }
        next
      }

      END {
        finish_device()
        printf "%s|%s|%s|%s|%d\n", best_type, best_conn, best_ip, best_dev, vpn
      }
    '
}

wifi() {
  local net_type ssid ip dev vpn sig icon='󰤮' vpn_suffix=''
  IFS='|' read -r net_type ssid ip dev vpn < <(nmcli_net_state)
  if [[ -z "${net_type:-}" ]]; then
    printf '%s' "$i_net_off"
    return
  fi

  [[ "${vpn:-0}" == "1" ]] && vpn_suffix='(vpn)'

  if [[ "$net_type" == "wifi" ]]; then
    sig="$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$dev" --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')"
    if [[ "$sig" =~ ^[0-9]+$ ]]; then
      ((sig < 20)) && icon='󰤯'
      ((sig >= 20 && sig < 40)) && icon='󰤟'
      ((sig >= 40 && sig < 60)) && icon='󰤢'
      ((sig >= 60 && sig < 80)) && icon='󰤥'
      ((sig >= 80)) && icon='󰤨'
    fi
    [[ -n "${ssid:-}" ]] && printf '%s %s %s' "$icon" "$vpn_suffix" "$ssid" || printf '%s %s' "$icon" "$vpn_suffix"
    return
  fi

  if [[ "$net_type" == "ethernet" ]]; then
    [[ -n "${ip:-}" ]] && printf '󰈀 %s %s' "$vpn_suffix" "$ip" || printf '󰈀 %s %s' "$vpn_suffix" "$dev"
    return
  fi

  printf '%s' "$i_net_off"
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
  s="${s//$'\n'/ }"
  s="${s//|//}"
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
printf '%s %s %s|%s|%s %s  %s %s  %s  %s %s  %s %s\n' "$ws_s" "$(short "$title_s" 40)" "$(short "$med_s" 40)" "$tim" "$i_cpu" "${cpu_s#cpu }" "$i_mem" "${mem_s#ram }" "$(short "$wifi_s" 24)" "$i_bt" "$(short "$bt_s" 40)" "${bat_s#bat }"
    redraw=0
  fi
  sleep 0.15
done | minibar
