#!/usr/bin/env bash
set -euo pipefail

if ! command -v minibar >/dev/null 2>&1; then
  printf 'minibar command not found in PATH\n' >&2
  exit 1
fi

c_red='#ff5f56'
field_sep=$'\x1e'

sanitize() {
  local s=$1
  [[ $s == *['&<'$'\n'$'\r'$'\x1e'$'\x1f']* ]] || { printf '%s' "$s"; return; }
  s=${s//&/\&amp;}
  s=${s//</\&lt;}
  s=${s//$'\n'/ }
  s=${s//$'\r'/ }
  s=${s//$'\x1f'/ }
  s=${s//$'\x1e'/ }
  while [[ $s == *"  "* ]]; do s=${s//  / }; done
  printf '%s' "$s"
}

short() {
  local s="$1" n="${2:-18}"
  s="${s//$'\n'/ }"
  s="${s//$'\x1f'/ }"
  s="${s//$'\x1e'/ }"
  ((${#s} > n)) && printf '%s…' "${s:0:n-1}" || printf '%s' "$s"
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

battery_icon() {
  local status="${1:-Unknown}"
  local c="${2:-0}"

  [[ "$c" =~ ^[0-9]+$ ]] || c=0
  ((c < 0)) && c=0
  ((c > 100)) && c=100

  if [[ "$status" == 'Charging' ]]; then
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

ws() {
  local line id
  IFS= read -r line < <(hyprctl activeworkspace 2>/dev/null || true)
  id="${line#workspace ID }"
  id="${id%% *}"
  [[ "$id" =~ ^[0-9]+$ ]] || id='?'
  printf '[%s]' "$(sanitize "$id")"
}

mem() {
  local k v total=0 avail=0 used pct raw
  while read -r k v _; do
    [[ "$k" == 'MemTotal:' ]] && total=$v
    [[ "$k" == 'MemAvailable:' ]] && avail=$v
  done < /proc/meminfo

  if ((total <= 0)); then
    printf '󰘚 %s%%' "$(sanitize '?')"
    return
  fi

  used=$((total - avail))
  pct=$((used * 100 / total))
  raw="$pct"

  if ((pct > 95)); then
    printf '%s %s%%' "$(markup "$c_red" '󰘚')" "$(sanitize "$raw")"
    return
  fi

  printf '󰘚 %s%%' "$(sanitize "$raw")"
}

bat() {
  local b cap status icon
  for b in /sys/class/power_supply/BAT*; do
    [[ -d "$b" ]] || continue
    read -r cap < "$b/capacity" || continue
    read -r status < "$b/status" || status='Unknown'
    icon="$(battery_icon "$status" "$cap")"
    if [[ "$cap" =~ ^[0-9]+$ ]] && ((cap < 10)); then
      printf '%s %s%%' "$(markup "$c_red" "$icon")" "$(sanitize "$cap")"
      return
    fi
    printf '%s %s%%' "$icon" "$(sanitize "$cap")"
    return
  done

  printf '󰁹 %s' "$(sanitize 'n/a')"
}

bt() {
  local _ mac name out=''
  while read -r _ mac name; do
    [[ -z "$name" ]] && continue
    out+="${out:+, }$name"
  done < <(bluetoothctl devices Connected 2>/dev/null || true)
  [[ -n "$out" ]] || return 0
  printf '󰂱 %s' "$(sanitize "$(short "$out" 40)")"
}

net() {
  local net_type conn ip dev vpn sig='' icon text
  IFS='|' read -r net_type conn ip dev vpn < <(nmcli_net_state)
  net_iface="$dev"

  if [[ -z "${net_type:-}" ]]; then
    net_s="$(printf '%s %s' "$(markup "$c_red" '󰤭')" 'offline')"
    return
  fi

  if [[ "$net_type" == 'wifi' ]]; then
    sig="$(nmcli -t -f IN-USE,SIGNAL dev wifi list ifname "$dev" --rescan no 2>/dev/null | awk -F: '$1=="*"{print $2; exit}')"
    icon='󰤮'
    if [[ "$sig" =~ ^[0-9]+$ ]]; then
      ((sig < 20)) && icon='󰤯'
      ((sig >= 20 && sig < 40)) && icon='󰤟'
      ((sig >= 40 && sig < 60)) && icon='󰤢'
      ((sig >= 60 && sig < 80)) && icon='󰤥'
      ((sig >= 80)) && icon='󰤨'
    fi
    text="${conn:-$dev}"
  else
    icon='󰈀'
    text="${ip:-$dev}"
  fi

  text="$(sanitize "$(short "$text" 24)")"
  if [[ "${vpn:-0}" == '1' ]]; then
    net_s="$(printf '%s 󰦝 %s' "$icon" "$text")"
    return
  fi

  net_s="$(printf '%s %s' "$icon" "$text")"
}

pt=0
pi=0
cpu() {
  local _ u n s i w irq sirq st g gn total dt di pct raw display
  read -r _ u n s i w irq sirq st g gn < /proc/stat
  total=$((u + n + s + i + w + irq + sirq + st + g + gn))
  if ((pt == 0)); then
    pt=$total
    pi=$i
    cpu_s='󰍛  0%'
    return 0
  fi

  dt=$((total - pt))
  di=$((i - pi))
  pt=$total
  pi=$i

  if ((dt > 0)); then
    pct=$(((dt - di) * 100 / dt))
    raw="$pct"
  else
    raw='?'
  fi

  display="$raw"
  if [[ "$raw" =~ ^[0-9]$ ]]; then
    display=" $raw"
  fi

  if [[ "$raw" =~ ^[0-9]+$ ]] && ((raw > 95)); then
    cpu_s="$(printf '%s %s%%' "$(markup "$c_red" '󰍛')" "$(sanitize "$display")")"
    return 0
  fi

  cpu_s="$(printf '󰍛 %s%%' "$(sanitize "$display")")"
  return 0
}

rxb=0
txb=0
brt=0
iface=''
net_iface=''
br_s='⬇0 ⬆0'

br() {
  local rxb_now txb_now rxkbit txkbit dt_ms tnow rxsym txsym

  if [[ "$net_iface" != "$iface" ]]; then
    iface="$net_iface"
    brt=0
  fi

  [[ -n $iface ]] || return 0
  [[ -r /sys/class/net/$iface/statistics/rx_bytes ]] || return 0
  [[ -r /sys/class/net/$iface/statistics/tx_bytes ]] || return 0

  if ((brt == 0)); then
    rxb=$(< /sys/class/net/$iface/statistics/rx_bytes)
    txb=$(< /sys/class/net/$iface/statistics/tx_bytes)
    brt=$(date +%s%3N)
    br_s='⬇0 ⬆0'
    return 0
  fi

  rxb_now=$(< /sys/class/net/$iface/statistics/rx_bytes)
  txb_now=$(< /sys/class/net/$iface/statistics/tx_bytes)
  tnow=$(date +%s%3N)
  dt_ms=$((tnow-brt))
  dt_ms=$((dt_ms > 0 ? dt_ms : 1))
  brt=$tnow
  rxkbit=$((((rxb_now-rxb) * 8) / dt_ms))
  txkbit=$((((txb_now-txb) * 8) / dt_ms))
  rxb=$rxb_now
  txb=$txb_now
  if (( $rxkbit < 1000 )); then rxsym=k 
  elif (( $rxkbit < 1000000 )); then rxsym=M rxkbit=$(($rxkbit/1000))
  elif (( $rxkbit < 1000000000 )); then rxsym=G rxkbit=$(($rxkbit/1000000))
  fi
  if (( $txkbit < 1000 )); then txsym=k
  elif (( $txkbit < 1000000 )); then txsym=M txkbit=$(($txkbit/1000))
  elif (( $txkbit < 1000000000 )); then txsym=G txkbit=$(($txkbit/1000000))
  fi

  br_s="$(printf '⬇%3s%s ⬆%3s%s' "$rxkbit" "$rxsym" "$txkbit" "$txsym")"

  return 0
}

title() {
  local info
  info="$(hyprctl activewindow -j | jq -r '.title' 2>/dev/null)"
  if [[ -n "$info" && "$info" != 'null' ]]; then
    printf '%s' "$(sanitize "$(short "$info" 40)")"
    return 0
  fi

  return 0
}

media() {
  local info status
  info="$(playerctl metadata --format '{{ artist }} - {{ title }}' 2>/dev/null)"
  status="$(playerctl status 2>/dev/null)"
  if [[ -n "$info" && "$status" == 'Playing' ]]; then
    printf '󰝚 %s' "$(sanitize "$(short "$info" 40)")"
    return 0
  fi

  return 0
}

clock() {
  printf '%s' "$(sanitize "$(date '+%a %Y-%m-%d %H:%M')")"
}

ws_s="$(ws)"
mem_s="$(mem)"
net
bt_s="$(bt)"
bat_s="$(bat)"
tim_s="$(clock)"
title_s="$(title)"
med_s="$(media)"
cpu
br

net_every=15
bat_every=5
bt_every=5
next_net=0
next_bat=0
next_bt=0

while true; do
  now="$(date +%s)"
  ntim="$(clock)"
  nw="$(ws)"

  if [[ "$nw" != "$ws_s" ]]; then
    ws_s="$nw"
    redraw=1
  fi

  if [[ "${last:-}" != "$now" ]]; then
    last="$now"
    ws_s="$(ws)"
    cpu
    br
    mem_s="$(mem)"
    med_s="$(media)"
    title_s="$(title)"
    redraw=1
  fi

  if [[ "$ntim" != "$tim_s" ]]; then
    tim_s="$ntim"
    redraw=1
  fi

  if (( now >= next_net )); then
    prev_net_s="$net_s"
    net
    [[ "$net_s" != "$prev_net_s" ]] && redraw=1
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
      "$(join_nonempty "$ws_s" "$title_s" "$med_s")" \
      "$tim_s" \
      "$(join_nonempty "$cpu_s" "$mem_s" "$br_s" "$net_s" "$bt_s" "$bat_s")"
    redraw=0
  fi

  sleep 0.15
done | minibar
