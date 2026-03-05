#!/usr/bin/env bash
set -euo pipefail

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

write_root_file() {
  local target="$1"
  local mode="$2"
  local owner="$3"
  local group="$4"
  local tmp

  tmp="$(mktemp)"
  cat >"$tmp"

  run_as_root install -d -m 0755 "$(dirname "$target")"
  run_as_root install -m "$mode" -o "$owner" -g "$group" "$tmp" "$target"

  rm -f "$tmp"
}

serial_group="uucp"
if ! getent group "$serial_group" >/dev/null 2>&1; then
  serial_group="dialout"
fi

target_user="${SUDO_USER:-${USER:-}}"
target_home=""
if [[ -n "$target_user" ]]; then
  target_home="$(getent passwd "$target_user" | cut -d: -f6)"
fi
if [[ -z "$target_home" ]]; then
  echo "error: could not determine target home directory for usb sound rule" >&2
  exit 1
fi

write_root_file /etc/udev/rules.d/99-serial.rules 0644 root root <<RULES
KERNEL=="ttyUSB[0-9]*", MODE="0666", GROUP="$serial_group", ENV{ID_MM_DEVICE_IGNORE}="1"
KERNEL=="ttyACM[0-9]*", MODE="0666", GROUP="$serial_group", ENV{ID_MM_DEVICE_IGNORE}="1"
RULES

# Keep module list deterministic and duplicate-free on repeated runs.
write_root_file /etc/modules-load.d/can.conf 0644 root root <<'MODULES'
gs_usb
vcan
MODULES

write_root_file /etc/udev/rules.d/99-candlelight.rules 0644 root root <<'RULES'
ACTION=="add", SUBSYSTEM=="net", ATTRS{idVendor}=="1d50", ATTRS{idProduct}=="606f", RUN+="/usr/bin/ip link set dev %k type can bitrate 500000", RUN+="/usr/bin/ip link set dev %k up"
RULES

write_root_file /etc/udev/rules.d/99-usb-sound.rules 0644 root root <<RULES
SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="$target_home/.local/bin/play_sound.sh $target_home/.local/share/sound/ding.wav"
RULES

write_root_file /etc/udev/rules.d/99-ross-tech-hexv2.rules 0644 root root <<'RULES'
SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="a0cb", MODE="0666", GROUP="plugdev"
RULES

# Keep current user in serial group when possible.
if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  run_as_root usermod -aG "$serial_group" "$SUDO_USER" || true
elif [[ -n "${USER:-}" ]]; then
  run_as_root usermod -aG "$serial_group" "$USER" || true
fi

run_as_root udevadm control --reload-rules
run_as_root udevadm trigger

echo "udev rules installed and reloaded successfully"
