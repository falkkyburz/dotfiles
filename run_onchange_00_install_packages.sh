#!/usr/bin/env bash
# chezmoi: run_onchange_install-packages.sh
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

PACMAN_PKGS=(
  # base tooling
  git base-devel

  # core apps / tools
  kitty bat btop neovim zsh less jq github-cli chezmoi age man
  nnn nodejs npm fd lazygit fzf wget uv cpio usbutils

  # bluetooth
  blueman bluez bluez-utils

  # desktop / hyprland stack + services
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs brightnessctl
  swaync libnotify swayosd power-profiles-daemon playerctl qt5-wayland qt6-wayland

  # screenshot
  slurp grim

  # files / disks / btrfs
  dolphin udiskie btrfs-assistant snapper snap-pac

  # clipboard
  wl-clipboard cliphist

  # fonts
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-liberation cantarell-fonts nwg-look

  # browsers
  firefox chromium libfido2 speech-dispatcher

  # audio / video
  alsa-utils pipewire wireplumber pipewire-alsa pipewire-pulse sof-firmware vlc vlc-plugins-all audacity

  # extras
  libreoffice octave inkscape gimp fastfetch obs-studio zathura zathura-pdf-poppler okular reflector freecad kicad

  # KDE Tools
  kclock isoimagewriter partitionmanager systemdgenie gwenview kdenlive ark

  # development
  code stlink pulseview

  # nm gui tools (installed per your earlier list)
  network-manager-applet nm-connection-editor wpa_supplicant
)

AUR_PKGS=(
  hyprland-meta-git
  localsend
  satty
  can-utils-git
  limine-snapper-sync
  limine-entry-tool
)

install_pacman() {
  # install only missing packages
  local missing=()
  for p in "${PACMAN_PKGS[@]}"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  ((${#missing[@]} == 0)) && return 0

  sudo pacman -Syu --needed --noconfirm "${missing[@]}"
}

install_aur() {
  ((${#AUR_PKGS[@]} == 0)) && return 0
  have yay || {
    echo "ERROR: yay not found for AUR installs." >&2
    exit 1
  }

  local missing=()
  for p in "${AUR_PKGS[@]}"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  ((${#missing[@]} == 0)) && return 0

  yay -S --noconfirm "${missing[@]}"
}

main() {
  have pacman || {
    echo "ERROR: pacman not found." >&2
    exit 1
  }
  install_pacman
  install_aur
}

main "$@"
