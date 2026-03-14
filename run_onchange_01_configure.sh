#!/usr/bin/env bash
# chezmoi: run_onchange_install-packages.sh
set -euo pipefail

current_default_browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
if [[ "$current_default_browser" != "firefox.desktop" ]]; then
  xdg-settings set default-web-browser firefox.desktop
fi

# Configure the snapper config file as follows:
# sudoedit /etc/snapper/configs/root
# TIMELINE_LIMIT_HOURLY="6"
# TIMELINE_LIMIT_DAILY="7"
# TIMELINE_LIMIT_WEEKLY="4"
# TIMELINE_LIMIT_MONTHLY="3"
# TIMELINE_LIMIT_YEARLY="0"

# Ensure snapper root config exists
if [[ ! -f /etc/snapper/configs/root ]]; then
  echo "Creating snapper root config..."
  sudo snapper -c root create-config /
fi

# Ensure /.snapshots ownership and permissions
snapshots_state="$(stat -c '%a:%U:%G' /.snapshots 2>/dev/null || true)"
if [[ ! -d /.snapshots ]] || [[ "$snapshots_state" != "750:root:wheel" ]]; then
  echo "Ensuring /.snapshots exists with the expected ownership and permissions..."
  sudo install -d -m 750 -o root -g wheel /.snapshots
fi

# Fix fonts for XWayland
sudo install -d /etc/fonts/conf.d

if [[ ! -e /etc/fonts/conf.d/70-no-bitmaps.conf ]]; then
  sudo ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/70-no-bitmaps.conf
fi

sudo rm -f /etc/fonts/conf.d/10-scale-bitmap-fonts.conf
fc-cache -f

# Make docker config file
sudo mkdir -p /etc/docker

tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
{
  "storage-driver": "btrfs"
}
EOF

if ! sudo cmp -s "$tmp" /etc/docker/daemon.json 2>/dev/null; then
  sudo install -Dm644 "$tmp" /etc/docker/daemon.json
fi

rm -f "$tmp"

configure_windows_vm() {
  local project_dir="${HOME}/.local/share/windows-docker"
  local storage_dir="${project_dir}/windows"
  local compose_file="${project_dir}/compose.yml"
  local tmp_file

  install -d -m 0755 "${project_dir}"
  install -d -m 0755 "${storage_dir}"

  tmp_file="$(mktemp)"
  cat >"${tmp_file}" <<'EOF'
services:
  windows:
    image: dockurr/windows
    container_name: windows
    restart: unless-stopped
    stop_grace_period: 2m
    environment:
      VERSION: "11"
      RAM_SIZE: "8G"
      CPU_CORES: "4"
      DISK_SIZE: "64G"
      ARGUMENTS: "-device usb-host,vendorid=0x0483,productid=0xa0cb"
    devices:
      - /dev/kvm
      - /dev/net/tun
      - /dev/bus/usb
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"
      - "3389:3389/tcp"
      - "3389:3389/udp"
    volumes:
      - ./windows:/storage
EOF

  if [[ ! -f "${compose_file}" ]] || ! cmp -s "${tmp_file}" "${compose_file}"; then
    mv "${tmp_file}" "${compose_file}"
    echo "Updated ${compose_file}"
  else
    rm -f "${tmp_file}"
    echo "Unchanged ${compose_file}"
  fi
}

configure_windows_vm

# Add user to groups
sudo usermod -aG wireshark $USER
sudo usermod -aG docker $USER
