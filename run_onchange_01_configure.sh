#!/usr/bin/env bash
# chezmoi: run_onchange_install-packages.sh
set -euo pipefail

xdg-settings set default-web-browser firefox.desktop

# Configure the snapper config file as follows:
# sudoedit /etc/snapper/configs/root
# TIMELINE_LIMIT_HOURLY="6"
# TIMELINE_LIMIT_DAILY="7"
# TIMELINE_LIMIT_WEEKLY="4"
# TIMELINE_LIMIT_MONTHLY="3"
# TIMELINE_LIMIT_YEARLY="0"

# Ensure snapper root config exists
if ! sudo snapper -c root list >/dev/null 2>&1; then
  echo "Creating snapper root config..."
  sudo snapper -c root create-config /
else
  echo "Snapper root config already exists."
fi

# Ensure /.snapshots ownership and permissions
current_mode="$(stat -c '%a' /.snapshots)"
current_group="$(stat -c '%G' /.snapshots)"

if [[ "$current_mode" != "750" ]]; then
  echo "Setting /.snapshots mode to 750..."
  sudo chmod 750 /.snapshots
else
  echo "Mode on /.snapshots already 750."
fi

if [[ "$current_group" != "wheel" ]]; then
  echo "Setting /.snapshots group to wheel..."
  sudo chown :wheel /.snapshots
else
  echo "Group on /.snapshots already wheel."
fi
