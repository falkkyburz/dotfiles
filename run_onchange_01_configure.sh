#!/usr/bin/env bash
# chezmoi: run_onchange_install-packages.sh
set -euo pipefail

current_default_browser="$(xdg-settings get default-web-browser 2>/dev/null || true)"
if [[ "$current_default_browser" != "firefox.desktop" ]]; then
  xdg-settings set default-web-browser firefox.desktop
fi

# Ensure standard user directories exist (initialize once)
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
  xdg_user_dirs_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
  if [[ ! -f "$xdg_user_dirs_file" ]]; then
    xdg-user-dirs-update
  fi
fi

# Make Work directory
install -d -m 0755 "${HOME}/Work"

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

# Provision systemd-boot UKI paths and mkinitcpio preset
sudo install -d -m 0755 /boot/EFI/Linux
sudo install -d -m 0755 /etc/kernel
sudo install -d -m 0755 /etc/mkinitcpio.d

if [[ ! -s /etc/kernel/cmdline ]]; then
  kernel_cmdline=""

  for token in $(< /proc/cmdline); do
    case "$token" in
      BOOT_IMAGE=*|initrd=*)
        continue
        ;;
    esac

    kernel_cmdline+="${kernel_cmdline:+ }${token}"
  done

  if [[ -z "$kernel_cmdline" ]]; then
    kernel_cmdline="rw"
  fi

  tmp="$(mktemp)"
  printf '%s\n' "$kernel_cmdline" >"$tmp"

  if ! sudo cmp -s "$tmp" /etc/kernel/cmdline 2>/dev/null; then
    sudo install -Dm644 "$tmp" /etc/kernel/cmdline
  fi

  rm -f "$tmp"
fi

tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux.img"
default_uki="/boot/EFI/Linux/arch-linux.efi"

fallback_image="/boot/initramfs-linux-fallback.img"
fallback_uki="/boot/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
EOF

if ! sudo cmp -s "$tmp" /etc/mkinitcpio.d/linux.preset 2>/dev/null; then
  sudo install -Dm644 "$tmp" /etc/mkinitcpio.d/linux.preset
fi

rm -f "$tmp"

# Configure Windows VM
install -d -m 0755 "${HOME}/.local/share/windows-docker"
install -d -m 0755 "${HOME}/.local/share/windows-docker/windows"
install -d -m 0755 "${HOME}/.local/share/windows-vm-shared"

# Add user to groups
sudo usermod -aG wireshark $USER
sudo usermod -aG docker $USER

# Switch login shell to zsh when available
if command -v zsh >/dev/null 2>&1; then
  zsh_path="$(command -v zsh)"
  if [[ "${SHELL:-}" != "$zsh_path" ]]; then
    chsh -s "$zsh_path" "$USER"
  fi
fi

# Install Oh My Zsh once
if command -v zsh >/dev/null 2>&1; then
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
  fi
fi

# Install kickstart.nvim once
nvim_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
if [[ ! -e "$nvim_config_dir" ]]; then
  git clone https://github.com/nvim-lua/kickstart.nvim.git "$nvim_config_dir"
elif [[ -d "$nvim_config_dir/.git" ]]; then
  current_remote="$(git -C "$nvim_config_dir" remote get-url origin 2>/dev/null || true)"
  if [[ "$current_remote" != "https://github.com/nvim-lua/kickstart.nvim.git" ]]; then
    printf 'Skipping kickstart install: %s already tracks %s\n' "$nvim_config_dir" "$current_remote"
  fi
else
  printf 'Skipping kickstart install: %s already exists and is not a git repo\n' "$nvim_config_dir"
fi
