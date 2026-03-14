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

# Configure Windows VM
install -d -m 0755 "${HOME}/.local/share/windows-docker"
install -d -m 0755 "${HOME}/.local/share/windows-docker/windows"
install -d -m 0755 "${HOME}/.local/share/windows-vm-shared"

# Add user to groups
sudo usermod -aG wireshark $USER
sudo usermod -aG docker $USER
