#!/usr/bin/env bash
# chezmoi: run_onchange_install-packages.sh
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

PACMAN_PKGS=(
  # base tooling
  git base-devel

  # core apps / tools
  kitty bat btop zsh less jq github-cli chezmoi age man tree lynx
  nnn nodejs npm fd lazygit fzf wget uv cpio usbutils zsh-autosuggestions
  unzip tree-sitter-cli

  # keyring
  kwallet kwallet-pam kwalletmanager

  # bluetooth
  blueman bluez bluez-utils

  # desktop / hyprland stack + services
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs brightnessctl
  swaync libnotify swayosd power-profiles-daemon playerctl qt5-wayland
  qt6-wayland librsvg papirus-icon-theme wlr-protocols

  # screenshot
  slurp grim

  # files / disks / btrfs
  thunar udiskie btrfs-assistant samba gvfs-smb systemd-ukify

  # clipboard
  wl-clipboard cliphist

  # fonts
  ttf-noto-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
  cantarell-fonts
  nwg-look font-manager

  # browsers
  firefox chromium libfido2 speech-dispatcher

  # audio / video
  alsa-utils pipewire wireplumber pipewire-alsa pipewire-pulse sof-firmware vlc vlc-plugins-all audacity playerctl

  # extras
  libreoffice octave inkscape gimp fastfetch obs-studio zathura zathura-pdf-poppler okular reflector freecad kicad
  lolcat figlet duf dust ripgrep exiftool rsync bandwhich pkgstats

  # GUI Tools
  gnome-clocks impression gnome-disk-utility systemdgenie gwenview kdenlive ark

  # development
  gdb code stlink pulseview libsigrok sigrok-firmware-fx2lafw sigrok-cli wireshark-qt hugo sqlite postgresql
  qalculate-gtk libqalculate gnuplot

  # development zephyr
  cmake ninja gperf ccache dfu-util dtc python-virtualenv tk xz file gcc-multilib sdl2-compat

  # nm gui tools (installed per your earlier list)
  network-manager-applet nm-connection-editor wpa_supplicant

  # Docker / VM
  docker docker-compose docker-buildx lazydocker
  qemu-desktop libvirt dnsmasq virt-viewer

  # security
  nftables
)

AUR_PKGS=(
  hyprland-meta-git
  localsend
  satty
  can-utils-git
  xdg-terminal-exec
  opencode
  unixcw
  neovim-git
  nordvpn-bin
  qutebrowser-git
  ttf-noto-emoji-monochrome
)

install_pacman() {
  # install only missing packages
  local missing=()
  for p in "${PACMAN_PKGS[@]}"; do
    pacman -Qi "$p" >/dev/null 2>&1 || missing+=("$p")
  done

  ((${#missing[@]} == 0)) && return 0

  sudo pacman -S --needed --noconfirm "${missing[@]}"
}

bootstrap_yay() {
  have yay && return 0

  local tmpdir
  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd "$tmpdir/yay"
    makepkg -si --needed --noconfirm
  )
  rm -rf "$tmpdir"
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
  bootstrap_yay
  install_aur
}

main "$@"
