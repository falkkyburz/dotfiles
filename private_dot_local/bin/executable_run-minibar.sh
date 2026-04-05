#!/usr/bin/env bash
set -euo pipefail

if ! command -v minibar >/dev/null 2>&1; then
  printf 'minibar command not found in PATH\n' >&2
  exit 1
fi

i_cpu='󰍛'
i_mem='󰘚'
i_bt='󰂱'
i_music='󰝚'
i_net_off='󰤭'
i_net_wifi_0='󰤯'
i_net_wifi_1='󰤟'
i_net_wifi_2='󰤢'
i_net_wifi_3='󰤥'
i_net_wifi_4='󰤨'
i_net_wifi='󰤮'
i_net_eth='󰈀'
i_vpn='󰦝'

c_red='#ff5f56'

field_sep=$'\x1e'

battery_icon() {
  local status="${1:-Unknown}"
  local c="${2:-0}"

  [[ "$c" =~ ^[0-9]+$ ]] || c=0
  ((c < 0)) && c=0
  ((c > 100)) && c=100

  if [[ "$status" == "Charging" ]]; then
    ((c <= 10)) && { printf '󰢜'; return; }
    ((c <= 20)) && { printf '󰂆'; return; }
    ((c <= 30)) && { printf '󰂇'; return; }
    ((c <= 40)) && { printf '󰂈'; return; }
    ((c <= 50)) && { printf '󰢝'; return; }
    ((c <= 60)) && { printf '󰂉'; return; }
    ((c <= 70)) && { printf '󰂊'; return; }
    ((c <= 80)) && { printf '󰂋'; return; }
    ((c <= 90)) && { printf '󰂌'; return; }
    printf '󰂅'
    return
  fi

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
  id="${l#workspace ID }"
  id="${id%% *}"
  [[ "$id" =~ ^[0-9]+$ ]] && printf '%s' "$id" || printf '?'
}

mem() {
  local k v total=0 avail=0 used=0 pct=0
  while read -r k v _; do
    [[ "$k" == "MemTotal:" ]] && total=$v
    [[ "$k" == "MemAvailable:" ]] && avail=$v
  done < /proc/meminfo

  if ((total > 0)); then
    used=$((total - avail))
    pct=$((used * 100 / total))
    printf '%s' "$pct"
    return
  fi

  printf '?'
}

bat() {
  local b c s
  for b in /sys/class/power_supply/BAT*; do
    [[ -d "$b" ]] || continue
    read -r c < "$b/capacity" || continue
    read -r s < "$b/status" || s='Unknown'
    printf '%s%s%s' "$s" "$field_sep" "$c"
    return
  done

  printf 'n/a%s?' "$field_sep"
}

bt() {
  local _ mac name out=''
  while read -r _ mac name; do
    [[ -z "$name" ]] && continue
    out+="${out:+, }$name"
  done < <(bluetoothctl devices Connected 2>/dev/null || true)
  printf '%s' "$out"
}

nmcli_net_state() {
  nmcli -t -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS,IP4.ROUTE device show 2>/dev/null |
    awk -F: '
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

net() {
  local net_type conn ip dev vpn sig=''
  IFS='|' read -r net_type conn ip dev vpn < <(nmcli_net_state)

  if [[ -z "${net_type:-}" ]]; then
    printf 'offline%s%s%s%s%s%s' "$field_sep" "$field_sep" "$field_sep" "$field_sep" "$field_sep" "$field_sep"
    return
  fi

  if [[ "$net_type" == 'wifi' ]]; then
    sig="$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$dev" --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')"
  fi

  printf '%s%s%s%s%s%s%s%s%s%s%s' \
    "$net_type" "$field_sep" "${conn:-}" "$field_sep" "${ip:-}" "$field_sep" \
    "${dev:-}" "$field_sep" "${vpn:-0}" "$field_sep" "${sig:-}"
}

pt=0
pi=0
cpu() {
  local _ u n s i w irq sirq st g gn total dt di
  read -r _ u n s i w irq sirq st g gn < /proc/stat
  total=$((u + n + s + i + w + irq + sirq + st + g + gn))
  if ((pt == 0)); then
    pt=$total
    pi=$i
    REPLY='0'
    return
  fi
  dt=$((total - pt))
  di=$((i - pi))
  pt=$total
  pi=$i
  if ((dt > 0)); then
    REPLY="$(((dt - di) * 100 / dt))"
  else
    REPLY='?'
  fi
}

title() {
  local info
  info="$(hyprctl activewindow -j | jq -r '.title' 2>/dev/null)"
  if [[ -n "$info" && "$info" != 'null' ]]; then
    printf '%s' "$info"
  fi
}

media() {
  local info status
  info="$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null)"
  status="$(playerctl status 2>/dev/null)"
  if [[ -n "$info" && "$status" == 'Playing' ]]; then
    printf '%s' "$info"
  fi
}

short() {
  local s="$1" n="${2:-18}"
  s="${s//$'\n'/ }"
  s="${s//$'\x1f'/ }"
  s="${s//$'\x1e'/ }"
  ((${#s} > n)) && printf '%s…' "${s:0:n-1}" || printf '%s' "$s"
}

sanitize() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  s=${s//\'/&apos;}
  s=${s//$'\x1f'/ }
  s=${s//$'\x1e'/ }
  printf '%s' "$s"
}

markup() {
  local color=$1
  local text=$2
  printf '<span foreground="%s">%s</span>' "$color" "$(sanitize "$text")"
}

join_nonempty() {
  local part out=''
  for part in "$@"; do
    [[ -n "$part" ]] || continue
    out+="${out:+ }$part"
  done
  printf '%s' "$out"
}

seg_ws() {
  printf '[%s]' "$(sanitize "${1:-?}")"
}

seg_title() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return
  printf '%s' "$(sanitize "$(short "$raw" 40)")"
}

seg_media() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return
  printf '%s %s' "$i_music" "$(sanitize "$(short "$raw" 40)")"
}

seg_net() {
  local raw="${1:-}"
  local net_type conn ip dev vpn sig icon text body

  IFS="$field_sep" read -r net_type conn ip dev vpn sig <<< "$raw"

  if [[ "$net_type" == 'offline' || -z "$net_type" ]]; then
    printf '%s %s' "$(markup "$c_red" "$i_net_off")" 'offline'
    return
  fi

  if [[ "$net_type" == 'wifi' ]]; then
    icon="$i_net_wifi"
    if [[ "$sig" =~ ^[0-9]+$ ]]; then
      ((sig < 20)) && icon="$i_net_wifi_0"
      ((sig >= 20 && sig < 40)) && icon="$i_net_wifi_1"
      ((sig >= 40 && sig < 60)) && icon="$i_net_wifi_2"
      ((sig >= 60 && sig < 80)) && icon="$i_net_wifi_3"
      ((sig >= 80)) && icon="$i_net_wifi_4"
    fi
    text="${conn:-$dev}"
  else
    icon="$i_net_eth"
    text="${ip:-$dev}"
  fi

  text="$(short "$text" 24)"
  body="$icon"
  [[ "${vpn:-0}" == '1' ]] && body+=" $i_vpn"
  if [[ -n "$text" ]]; then
    body+=" $(sanitize "$text")"
  fi
  printf '%s' "$body"
}

seg_bt() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return
  printf '%s %s' "$i_bt" "$(sanitize "$(short "$raw" 40)")"
}

seg_cpu() {
  local raw="${1:-?}"

  if [[ "$raw" =~ ^[0-9]+$ ]] && ((raw > 95)); then
    printf '%s %s%%' "$(markup "$c_red" "$i_cpu")" "$(sanitize "$raw")"
    return
  fi

  printf '%s %s%%' "$i_cpu" "$(sanitize "$raw")"
}

seg_mem() {
  local raw="${1:-?}"

  if [[ "$raw" =~ ^[0-9]+$ ]] && ((raw > 95)); then
    printf '%s %s%%' "$(markup "$c_red" "$i_mem")" "$(sanitize "$raw")"
    return
  fi

  printf '%s %s%%' "$i_mem" "$(sanitize "$raw")"
}

seg_bat() {
  local raw="${1:-}"
  local status cap icon

  IFS="$field_sep" read -r status cap <<< "$raw"
  if [[ "$status" == 'n/a' || -z "$cap" ]]; then
    printf '%s %s' '󰁹' "$(sanitize 'n/a')"
    return
  fi

  icon="$(battery_icon "$status" "$cap")"

  if [[ "$cap" =~ ^[0-9]+$ ]] && ((cap < 10)); then
    printf '%s %s%%' "$(markup "$c_red" "$icon")" "$(sanitize "$cap")"
    return
  fi

  printf '%s %s%%' "$icon" "$(sanitize "$cap")"
}

seg_time() {
  printf '%s' "$(sanitize "${1:-}")"
}

ws_s="$(ws)"
mem_s="$(mem)"
net_s="$(net)"
bt_s="$(bt)"
bat_s="$(bat)"
tim="$(date '+%a %Y-%m-%d %H:%M')"
title_s="$(title)"
med_s="$(media)"
cpu
cpu_s="$REPLY"

net_every=15
bat_every=5
bt_every=5
next_net=0
next_bat=0
next_bt=0

while true; do
  now="$(date +%s)"
  ntim="$(date '+%a %Y-%m-%d %H:%M')"
  nw="$(ws)"

  if [[ "$nw" != "$ws_s" ]]; then
    ws_s="$nw"
    redraw=1
  fi

  if [[ "${last:-}" != "$now" ]]; then
    last="$now"
    ws_s="$(ws)"
    cpu
    cpu_s="$REPLY"
    mem_s="$(mem)"
    med_s="$(media)"
    title_s="$(title)"
    redraw=1
  fi

  if [[ "$ntim" != "$tim" ]]; then
    tim="$ntim"
    redraw=1
  fi

  if (( now >= next_net )); then
    nnet="$(net)"
    [[ "$nnet" != "$net_s" ]] && redraw=1
    net_s="$nnet"
    next_net=$((now + net_every))
  fi

  if (( now >= next_bt )); then
    nbt="$(bt)"
    [[ "$nbt" != "$bt_s" ]] && redraw=1
    bt_s="$nbt"
    next_bt=$((now + bt_every))
  fi

  if (( now >= next_bat )); then
    nbat="$(bat)"
    [[ "$nbat" != "$bat_s" ]] && redraw=1
    bat_s="$nbat"
    next_bat=$((now + bat_every))
  fi

  if (( ${redraw:-1} )); then
    printf '%s\x1f%s\x1f%s\n' \
      "$(join_nonempty "$(seg_ws "$ws_s")" "$(seg_title "$title_s")" "$(seg_media "$med_s")")" \
      "$(seg_time "$tim")" \
      "$(join_nonempty "$(seg_cpu "$cpu_s")" "$(seg_mem "$mem_s")" "$(seg_net "$net_s")" "$(seg_bt "$bt_s")" "$(seg_bat "$bat_s")")"
    redraw=0
  fi

  sleep 0.15
done | minibar
