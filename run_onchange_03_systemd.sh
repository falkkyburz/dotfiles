#!/usr/bin/env bash
set -euo pipefail

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

systemd_units_changed=0

write_root_file() {
  local target="$1"
  local mode="$2"
  local owner="$3"
  local group="$4"
  local desired_meta="${mode#0}:$owner:$group"
  local current_meta=""
  local tmp

  tmp="$(mktemp)"
  cat >"$tmp"

  run_as_root install -d -m 0755 "$(dirname "$target")"

  if run_as_root test -e "$target"; then
    current_meta="$(run_as_root stat -c '%a:%U:%G' "$target")"
    if run_as_root cmp -s "$tmp" "$target" && [[ "$current_meta" == "$desired_meta" ]]; then
      rm -f "$tmp"
      return 0
    fi
  fi

  run_as_root install -m "$mode" -o "$owner" -g "$group" "$tmp" "$target"
  case "$target" in
  /etc/systemd/system/*) systemd_units_changed=1 ;;
  esac

  rm -f "$tmp"
}


system_unit_known() {
  systemctl list-unit-files "$1" --no-legend 2>/dev/null | grep -q .
}

user_unit_known() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q .
}

unit_is_enabled_user() {
  systemctl --user is-enabled "$1" >/dev/null 2>&1
}

unit_is_enabled_system() {
  sudo systemctl is-enabled "$1" >/dev/null 2>&1
}

enable_now_system() {
  local unit="$1"
  if system_unit_known "$unit"; then
    if ! unit_is_enabled_system "$unit"; then
      sudo systemctl enable --now "$unit"
    else
      sudo systemctl start "$unit" >/dev/null 2>&1 || true
    fi
  else
    printf 'Skipping missing system unit: %s\n' "$unit"
  fi
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
  if ((systemd_units_changed)); then
    run_as_root systemctl daemon-reload
  fi

  SYSTEM_UNITS=(
    bluetooth.service
    docker.service
  )

  if pacman -Q networkmanager >/dev/null 2>&1; then
    SYSTEM_UNITS+=(NetworkManager.service)
  fi

  for unit in "${SYSTEM_UNITS[@]}"; do
    enable_now_system "$unit"
  done

  USER_UNITS=(
    pipewire.service
    pipewire-pulse.service
    wireplumber.service
    xdg-desktop-portal.service
  )

  for unit in "${USER_UNITS[@]}"; do
    start_or_enable_user "$unit"
  done
}

main "$@"
