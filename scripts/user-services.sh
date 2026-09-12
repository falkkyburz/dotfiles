#!/usr/bin/env bash
set -euo pipefail

user_unit_known() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q .
}

user_systemd_available() {
  systemctl --user show-environment >/dev/null 2>&1
}

start_or_enable_user() {
  local unit="$1"

  if ! user_unit_known "$unit"; then
    printf 'Skipping missing user unit: %s\n' "$unit"
    return
  fi

  local state
  state="$(systemctl --user is-enabled "$unit" 2>/dev/null || true)"

  case "$state" in
  enabled | enabled-runtime | linked | linked-runtime | alias)
    systemctl --user start "$unit" >/dev/null 2>&1 || true
    ;;
  static | indirect | generated | transient)
    systemctl --user start "$unit"
    ;;
  disabled)
    systemctl --user enable --now "$unit"
    ;;
  *)
    systemctl --user start "$unit" >/dev/null 2>&1 || true
    ;;
  esac
}

main() {
  if ! user_systemd_available; then
    printf 'Skipping user systemd units: no user systemd session is available\n'
    return
  fi

  systemctl --user daemon-reload

  USER_UNITS=(
    pipewire.service
    pipewire-pulse.service
    wireplumber.service
    voxtype.service
    app-dev.lizardbyte.app.Sunshine.service
  )

  for unit in "${USER_UNITS[@]}"; do
    start_or_enable_user "$unit"
  done

  if systemctl --user is-active --quiet graphical-session.target; then
    start_or_enable_user xdg-desktop-portal.service
  else
    printf 'Skipping xdg-desktop-portal.service: graphical-session.target is inactive\n'
  fi
}

main "$@"
