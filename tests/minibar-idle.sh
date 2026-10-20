#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
script=${MINIBAR_SCRIPT:-home/.local/bin/run-minibar.sh}
# shellcheck disable=SC1090
# Load the real tracker without launching the desktop bar.
source <(sed -n '/^declare -A idle_dbus_/,/^start_idle_dbus_monitor()/p' "$script" | head -n -1)

expect() {
  # Assigned by the sourced tracker.
  # shellcheck disable=SC2154
  if [[ "$idle_dbus_count" != "$1" ]]; then
    printf 'FAIL: %s: got %s, expected %s\n' "$2" "$idle_dbus_count" "$1" >&2
    exit 1
  fi
}
call() {
  handle_idle_dbus_event "method call time=1 sender=$1 -> destination=org.freedesktop.ScreenSaver serial=$2 path=/ScreenSaver; interface=org.freedesktop.ScreenSaver; member=$3"
}
reply() {
  handle_idle_dbus_event "method return time=1 sender=:1.25 -> destination=$1 serial=500 reply_serial=$2"
}
uint() { handle_idle_dbus_event "   uint32 $1"; }
name_changed() {
  handle_idle_dbus_event 'signal time=1 sender=org.freedesktop.DBus -> destination=(null destination) serial=600 path=/org/freedesktop/DBus; interface=org.freedesktop.DBus; member=NameOwnerChanged'
  handle_idle_dbus_event "   string \"$1\""
  handle_idle_dbus_event "   string \"$2\""
  handle_idle_dbus_event "   string \"$3\""
}

call :1.42 10 Inhibit
handle_idle_dbus_event 'error time=1 sender=org.freedesktop.DBus -> destination=:1.42 error_name=org.freedesktop.DBus.Error.ServiceUnknown reply_serial=10'
expect 0 'rejected request must not light icon'

call :1.42 11 Inhibit
expect 0 'request must wait for successful reply'
reply :1.42 11
uint 1337
expect 1 'accepted cookie lights icon'
call :1.42 12 Inhibit
reply :1.42 12
uint 1338
expect 2 'independent cookies'

call :1.99 20 UnInhibit
uint 1337
reply :1.99 20
expect 1 'release from another connection uses cookie'
call :1.99 21 UnInhibit
uint 1337
reply :1.99 21
expect 1 'duplicate release leaves other cookie intact'
call :1.42 22 UnInhibit
uint 1338
handle_idle_dbus_event 'error time=1 sender=:1.25 -> destination=:1.42 error_name=org.freedesktop.DBus.Error.Failed reply_serial=22'
expect 1 'failed release retains cookie'

name_changed org.mpris.MediaPlayer2.chromium :1.42 ''
expect 1 'losing unrelated well-known name retains cookie'
name_changed :1.42 :1.42 ''
expect 0 'client disconnect clears its cookies'

call :1.50 30 Inhibit
reply :1.50 30
uint 1400
name_changed org.freedesktop.ScreenSaver :1.25 :1.26
expect 0 'service replacement invalidates old cookies'

# Simulate the actual timed-read boundary with the header split across reads.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkfifo "$tmp/events"
exec {idle_dbus_fd}<>"$tmp/events"
printf '%s' 'method call time=1 sender=:1.60 -> destination=org.freedesktop.ScreenSaver serial=40 path=/ScreenSaver; interface=org.freedesktop.ScreenSaver; member=In' >&"$idle_dbus_fd"
read_idle_dbus_events
printf '%s\n' 'hibit' >&"$idle_dbus_fd"
read_idle_dbus_events
reply :1.60 40
uint 1500
expect 1 'partial call header survives timeout'
printf '%s' 'method call time=1 sender=:1.60 -> destination=org.freedesktop.ScreenSaver serial=41 path=/ScreenSaver; interface=org.freedesktop.ScreenSaver; member=UnIn' >&"$idle_dbus_fd"
read_idle_dbus_events
printf '%s\n' 'hibit' '   uint32 1500' >&"$idle_dbus_fd"
read_idle_dbus_events
reply :1.60 41
expect 0 'partial release header survives timeout'
exec {idle_dbus_fd}>&-
printf 'PASS: rejected requests, cookie releases, disconnects, service restarts, partial reads\n'
