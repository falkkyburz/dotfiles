#!/usr/bin/env bash
set -euo pipefail

if ((EUID == 0)) || [[ ! -f /etc/arch-release || $(uname -m) != x86_64 ]]; then
  echo 'Bootstrap requires a regular user on installed Arch Linux with sudo access.' >&2
  exit 1
fi
# A full upgrade avoids partial upgrades when adding packages on a fresh machine.
sudo pacman -Syu --needed --noconfirm git base-devel curl

if ! command -v yay >/dev/null 2>&1 && ! command -v paru >/dev/null 2>&1; then
  build_dir=$(mktemp -d)
  trap 'rm -rf -- "$build_dir"' EXIT
  git clone https://aur.archlinux.org/yay.git "$build_dir/yay"
  (cd "$build_dir/yay" && makepkg -si --needed --noconfirm)
fi
