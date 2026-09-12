#!/usr/bin/env bash
set -euo pipefail

target_user="${SUDO_USER:-${USER:-}}"

add_user_to_group() {
  local group="$1"
  local user="$2"

  if [[ -z "$user" ]]; then
    printf 'Skipping group %s: could not determine target user\n' "$group" >&2
    return 0
  fi

  if ! getent passwd "$user" >/dev/null 2>&1; then
    printf 'Skipping group %s: user %s does not exist\n' "$group" "$user" >&2
    return 0
  fi

  if ! getent group "$group" >/dev/null 2>&1; then
    printf 'Skipping group %s: group does not exist\n' "$group" >&2
    return 0
  fi

  sudo usermod -aG "$group" "$user"
}

if command -v xdg-settings >/dev/null 2>&1; then
  current_default_browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  if [[ "$current_default_browser" != "helium.desktop" ]]; then
    xdg-settings set default-web-browser helium.desktop || \
      printf 'Warning: failed to set default browser with xdg-settings\n' >&2
  fi
fi

# Ensure standard user directories exist (initialize once)
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  xdg_user_dirs_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
  if [[ ! -f "$xdg_user_dirs_file" ]]; then
    xdg-user-dirs-update
  fi
fi

# Make development directory
install -d -m 0755 "${HOME}/dev"

# Configure Voxtype and download the configured model if it is missing
if command -v voxtype >/dev/null 2>&1; then
  voxtype setup --download
fi

fc-cache -f

# Configure Windows VM
install -d -m 0755 "${HOME}/.local/share/windows-docker"
install -d -m 0755 "${HOME}/.local/share/windows-docker/windows"
install -d -m 0755 "${HOME}/.local/share/windows-vm-shared"

# Account names differ across machines; mise's account table keys are literal.
for group in nordvpn wireshark docker libvirt uucp; do
  add_user_to_group "$group" "$target_user"
done

# Apply the declarative hardware rules to devices already connected.
sudo udevadm control --reload-rules
sudo udevadm trigger

# Build and install dotfiles utilities
dotfiles_utils_dir="${HOME}/dev/dotfiles-utils"

git -C "$dotfiles_utils_dir" submodule update --init --recursive
cmake -S "$dotfiles_utils_dir" -B "$dotfiles_utils_dir/build/release" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${HOME}/.local"
cmake --build "$dotfiles_utils_dir/build/release" --parallel
cmake --install "$dotfiles_utils_dir/build/release"

# Build and install Hyprland screen picker
hyprscreenpicker_dir="${HOME}/dev/hyprscreenpicker"

cmake -S "$hyprscreenpicker_dir" -B "$hyprscreenpicker_dir/build/release" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${HOME}/.local"
cmake --build "$hyprscreenpicker_dir/build/release" --parallel
cmake --install "$hyprscreenpicker_dir/build/release"
