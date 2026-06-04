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

# Configure PAM login for KWallet auto-unlock on TTY login
tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
#%PAM-1.0

auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_kwallet5.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_kwallet5.so auto_start force_run kwalletd=/usr/bin/ksecretd
password   include      system-local-login
EOF

if ! sudo cmp -s "$tmp" /etc/pam.d/login 2>/dev/null; then
  sudo install -Dm644 "$tmp" /etc/pam.d/login
fi

rm -f "$tmp"

# Configure firewall -> Make nftables config file. 
# Uncomment the sshd line to allow incoming ssh sessions.
tmp="$(mktemp)"
cat >"$tmp" <<'EOF'
#!/usr/bin/nft -f
# vim:set ts=2 sw=2 et:

# IPv4/IPv6 Simple & Safe firewall ruleset.
# More examples in /usr/share/nftables/ and /usr/share/doc/nftables/examples/.

flush ruleset
table inet filter {
  chain input {
    type filter hook input priority filter
    policy drop

    ct state invalid drop comment "early drop of invalid connections"
    ct state {established, related} accept comment "allow tracked connections"
    iif lo accept comment "allow from loopback"
    meta l4proto { icmp, icmpv6 } accept comment "allow icmp"
    tcp dport ssh accept comment "allow sshd"
    pkttype host limit rate 5/second counter reject with icmpx type admin-prohibited
    counter
  }
  chain forward {
    type filter hook forward priority filter
    policy drop

    # Allow Docker bridge networks to forward through the host firewall.
    iifname "docker0" accept
    oifname "docker0" ct state {established, related} accept
    iifname "br-*" accept
    oifname "br-*" ct state {established, related} accept
  }
  chain output {
    type filter hook output priority filter
    policy accept
  }
}
EOF

if ! sudo cmp -s "$tmp" /etc/nftables.conf 2>/dev/null; then
  sudo install -Dm644 "$tmp" /etc/nftables.conf
fi

rm -f "$tmp"

sudo nft -c -f /etc/nftables.conf
sudo nft -f /etc/nftables.conf
sudo nft list ruleset >/dev/null

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

# Install Doom Emacs once
doom_emacs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/emacs"

if [[ ! -d "$doom_emacs_dir" ]]; then
  git clone --depth=1 https://github.com/doomemacs/doomemacs.git "$doom_emacs_dir"
elif [[ ! -d "$doom_emacs_dir/.git" ]]; then
  printf '%s exists but is not a git repository\n' "$doom_emacs_dir" >&2
  exit 1
fi

if [[ ! -d "$doom_emacs_dir/.local" ]]; then
  "$doom_emacs_dir/bin/doom" install --force
fi

# Build and install dotfiles utilities
dotfiles_utils_dir="${HOME}/Work/dotfiles-utils"

if [[ ! -d "$dotfiles_utils_dir" ]]; then
  git clone https://github.com/falkkyburz/dotfiles-utils.git "$dotfiles_utils_dir"
elif [[ ! -d "$dotfiles_utils_dir/.git" ]]; then
  printf '%s exists but is not a git repository\n' "$dotfiles_utils_dir" >&2
  exit 1
fi

cmake --preset release -S "$dotfiles_utils_dir"
cmake --build "$dotfiles_utils_dir/build/release" --parallel
cmake --install "$dotfiles_utils_dir/build/release"

# Build and install Hyprland screen picker
hyprscreenpicker_dir="${HOME}/Work/hyprscreenpicker"

if [[ ! -d "$hyprscreenpicker_dir" ]]; then
  git clone https://github.com/falkkyburz/hyprscreenpicker.git "$hyprscreenpicker_dir"
elif [[ ! -d "$hyprscreenpicker_dir/.git" ]]; then
  printf '%s exists but is not a git repository\n' "$hyprscreenpicker_dir" >&2
  exit 1
fi

cmake -S "$hyprscreenpicker_dir" -B "$hyprscreenpicker_dir/build/release" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${HOME}/.local"
cmake --build "$hyprscreenpicker_dir/build/release" --parallel
cmake --install "$hyprscreenpicker_dir/build/release"

# Fix thunar default terminal
mkdir -p "$HOME/.config/xfce4"
grep -qxF 'TerminalEmulator=kitty' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null || \
  printf 'TerminalEmulator=kitty\n' > "$HOME/.config/xfce4/helpers.rc"
