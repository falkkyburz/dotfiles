#!/usr/bin/env bash
set -euo pipefail

if ! command -v minibar >/dev/null 2>&1; then
  printf 'minibar command not found in PATH\n' >&2
  exit 1
fi

c_red='#ff5f56'
field_sep=$'\x1f'

sanitize() {
  printf '%s' "$1" | perl -Mutf8 -CSDA -pe '
    s/&/&amp;/g;
    s/</&lt;/g;
    s/\n/ /g;
    s/\r/ /g;
    s/\x{1F}/ /g;
    s/\x{1E}/ /g;

    s/[\x{FE0E}\x{FE0F}\x{200D}]//g;   # selectors, ZWJ
    s/[\x{1F000}-\x{1FAFF}]//g;        # emoji / pictographs

    s/[^\p{L}\p{N}\p{P}\p{Zs}\x{E000}-\x{F8FF}✓✗↓↑←→↔↕▲▼△▽⚠]/ /g;

    s/ {2,}/ /g;
    s/^ //;
    s/ $//;
  '
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
    ((c <= 10)) && { printf '󰢟'; return; }
    ((c <= 20)) && { printf '󰢜'; return; }
    ((c <= 30)) && { printf '󰂆'; return; }
    ((c <= 40)) && { printf '󰂇'; return; }
    ((c <= 50)) && { printf '󰂈'; return; }
    ((c <= 60)) && { printf '󰢝'; return; }
    ((c <= 70)) && { printf '󰂉'; return; }
    ((c <= 80)) && { printf '󰂊'; return; }
    ((c <= 90)) && { printf '󰂋'; return; }
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

monitor_workspace_title_rows() {
  local monitors clients

  monitors="$(hyprctl monitors -j 2>/dev/null || printf '[]')"
  clients="$(hyprctl clients -j 2>/dev/null || printf '[]')"

  jq -r --argjson clients "$clients" '
    .[] as $mon |
    (
      $clients
      | map(select(
          .monitor == $mon.id and
          .workspace.id == $mon.activeWorkspace.id and
          .visible == true and
          .hidden == false
        ))
      | sort_by(.focusHistoryID // 999999)
      | first
    ) as $client |
    (
      $clients
      | any(.[];
          .monitor == $mon.id and
          .workspace.id == $mon.activeWorkspace.id and
          .visible == true and
          .hidden == false and
          (((.fullscreen // 0) != 0) or ((.fullscreenClient // 0) != 0))
        )
    ) as $fullscreen |
    [
      $mon.name,
      (if $fullscreen then "0" else "1" end),
      (($mon.activeWorkspace.id // "?") | tostring),
      ($client.title // "")
    ] | @tsv
  ' <<< "$monitors" 2>/dev/null || true
}

monitor_bar_state() {
  monitor_workspace_title_rows | sort
}

hypr_event_name() {
  printf '%s' "${1%%>>*}"
}

is_hypr_bar_event() {
  case "$(hypr_event_name "$1")" in
    workspace*|focusedmon*|activewindow*|windowtitle*|openwindow|closewindow|movewindow*|changefloatingmode|fullscreen|monitoradded|monitorremoved|renamemonitor)
      return 0
      ;;
  esac

  return 1
}

start_hypr_events() {
  local socket sig runtime_dir

  command -v socat >/dev/null 2>&1 || return 1
  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  [[ -n "$sig" ]] || return 1

  socket="$runtime_dir/hypr/$sig/.socket2.sock"
  [[ -S "$socket" ]] || return 1

  hypr_event_fifo="$(mktemp -u "${TMPDIR:-/tmp}/run-minibar-hypr.XXXXXX")"
  mkfifo "$hypr_event_fifo"
  exec {hypr_event_fd}<>"$hypr_event_fifo"
  rm -f "$hypr_event_fifo"

  socat -u "UNIX-CONNECT:$socket" - >&$hypr_event_fd &
  hypr_event_pid=$!
  return 0
}

cleanup() {
  if [[ -n "${hypr_event_pid:-}" ]]; then
    kill "$hypr_event_pid" 2>/dev/null || true
  fi

  if [[ -n "${hypr_event_fd:-}" ]]; then
    exec {hypr_event_fd}>&- 2>/dev/null || true
  fi
}

ws_label() {
  local id="${1:-?}"
  [[ "$id" =~ ^-?[0-9]+$ ]] || id='?'
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

  if ((pct > 75)); then
    printf '󰘚 %s%%' "$(markup "$c_red" "$raw")"
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

pow() {
  local uwatt dwatt watt
  if [[ -d "/sys/class/power_supply/BAT0" ]]; then
    read -r uwatt < "/sys/class/power_supply/BAT0/power_now"
    watt="$(($uwatt/1000000))"
    dwatt="$((($uwatt-($watt*1000000))/100000))"
    printf ' %2u.%uW' "$watt" "$dwatt"
    return 0
  fi

  return 0
}

idle_inhibit() {
  local pid pidfile="${XDG_RUNTIME_DIR:-/tmp}/qt-idle-inhibit.pid"

  [[ -r "$pidfile" ]] || return 0
  read -r pid < "$pidfile" || return 0
  [[ "$pid" =~ ^[0-9]+$ ]] || return 0
  kill -0 "$pid" 2>/dev/null || return 0

  printf '󰒳 '
}

vol() {
  local vol_raw mic_raw vol_icon mic_icon
  if command -v wpctl >/dev/null 2>&1; then
    vol_raw="$(wpctl get-volume @DEFAULT_AUDIO_SINK@)"
    mic_raw="$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@)"
    if [[ "$vol_raw" == *"[MUTED]"* ]]; then
      vol_icon=''
    else 
      vol_icon=''
    fi
    if [[ "$mic_raw" == *"[MUTED]"* ]]; then
      mic_icon='󰍭'
    else 
      mic_icon='󰍬'
    fi
    printf '%s %s %s\n' "$mic_icon" "$vol_icon" "$(awk '{printf "%.0f%%\n", $2 * 100}' <<< "$vol_raw")"
    return 0
  fi

  return 0
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
    cpu_s="$(printf '󰍛 %s%%' "$(markup "$c_red" "$display")")"
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
br_s='▼0 ▲0'

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
    br_s='󰜮0 󰜷0'
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

  br_s="$(printf '󰜮%3s%s 󰜷%3s%s' "$rxkbit" "$rxsym" "$txkbit" "$txsym")"

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
  printf ' %s  %s' "$(sanitize "$(date '+%a %Y-%m-%d')")" "$(sanitize "$(date '+%H:%M')")"

}

emit_for_monitors() {
  local rows mon visible ws_id title_s left right error_flag=''
  rows="${1:-}"
  right="$(join_nonempty "$idle_s" "$cpu_s" "$mem_s" "$br_s" "$net_s" "$bt_s" "$vol_s" "$pow_s" "$bat_s")"
  (( ${hypr_error:-0} )) && error_flag="$(markup "$c_red" '✗')"

  if [[ -z "$rows" ]]; then
    printf '%s%s%s%s%s\n' \
      "$(join_nonempty "$error_flag" "$(ws_label '?')" "$med_s")" \
      "$field_sep" \
      "$tim_s" \
      "$field_sep" \
      "$right"
    return
  fi

  while IFS=$'\t' read -r mon visible ws_id title_s; do
    [[ -n "$mon" ]] || continue
    title_s="$(sanitize "$(short "$title_s" 40)")"
    left="$(join_nonempty "$error_flag" "$(ws_label "$ws_id")" "$title_s" "$med_s")"
    printf '%s%s%s%s%s%s%s\n' \
      "output=$(sanitize "$mon") visible=$visible" \
      "$field_sep" \
      "$left" \
      "$field_sep" \
      "$tim_s" \
      "$field_sep" \
      "$right"
  done <<< "$rows"
}

trap cleanup EXIT INT TERM

bar_state=''
mem_s="$(mem)"
net
bt_s="$(bt)"
bat_s="$(bat)"
pow_s="$(pow)"
vol_s="$(vol)"
idle_s="$(idle_inhibit)"
tim_s="$(clock)"
med_s="$(media)"
cpu
br

net_every=15
bat_every=5
pow_every=1
vol_every=1
idle_every=1
bt_every=5
hypr_poll_every=5
next_net=0
next_bat=0
next_pow=0
next_vol=0
next_idle=0
next_bt=0
next_hypr_poll=0
hypr_dirty=1
hypr_socket_events=0
hypr_error=0
first_redraw=1

if start_hypr_events; then
  hypr_socket_events=1
else
  hypr_error=1
  hypr_poll_every=1
fi

while true; do
  redraw=$first_redraw
  first_redraw=0
  now="$(date +%s)"
  ntim="$(clock)"

  if (( hypr_socket_events )); then
    if ! kill -0 "$hypr_event_pid" 2>/dev/null; then
      hypr_socket_events=0
      hypr_error=1
      hypr_poll_every=1
      hypr_dirty=1
      redraw=1
    fi

    for _ in {1..20}; do
      hypr_event=''
      IFS= read -r -t 0.001 -u "$hypr_event_fd" hypr_event || break
      [[ -n "$hypr_event" ]] || break

      if is_hypr_bar_event "$hypr_event"; then
        hypr_dirty=1
      fi
    done
  fi

  if (( ! hypr_socket_events && now >= next_hypr_poll )); then
    hypr_dirty=1
    next_hypr_poll=$((now + hypr_poll_every))
  fi

  if (( hypr_dirty )); then
    new_bar_state="$(monitor_bar_state)"
    if [[ "$new_bar_state" != "$bar_state" ]]; then
      bar_state="$new_bar_state"
      redraw=1
    fi
    hypr_dirty=0
  fi

  if [[ "${last:-}" != "$now" ]]; then
    last="$now"
    cpu
    br
    mem_s="$(mem)"
    med_s="$(media)"
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

  if (( now >= next_pow )); then
    npow="$(pow)"
    [[ "$npow" != "$pow_s" ]] && redraw=1
    pow_s="$npow"
    next_pow=$((now + pow_every))
  fi

  if (( now >= next_vol )); then
    nvol="$(vol)"
    [[ "$nvol" != "$vol_s" ]] && redraw=1
    vol_s="$nvol"
    next_vol=$((now + vol_every))
  fi

  if (( now >= next_idle )); then
    nidle="$(idle_inhibit)"
    [[ "$nidle" != "$idle_s" ]] && redraw=1
    idle_s="$nidle"
    next_idle=$((now + idle_every))
  fi

  if (( ${redraw:-1} )); then
    emit_for_monitors "$bar_state"
    redraw=0
  fi

  sleep 0.15
done | minibar "$@"
