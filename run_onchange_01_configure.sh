#!/usr/bin/env bash
# chezmoi: run_onchange_configure.sh
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
    iifname { "wlan0", "enp0s31f6" } ip saddr 192.168.1.0/24 tcp dport { 47984, 47989, 48010 } accept comment "allow Sunshine from LAN"
    iifname { "wlan0", "enp0s31f6" } ip saddr 192.168.1.0/24 udp dport { 47998, 47999, 48000, 48002, 48010 } accept comment "allow Sunshine from LAN"
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
if ! getent group nordvpn >/dev/null 2>&1; then
  sudo groupadd nordvpn
fi

add_user_to_group nordvpn "$target_user"
add_user_to_group wireshark "$target_user"
add_user_to_group docker "$target_user"

# Switch login shell to zsh when available
if command -v zsh >/dev/null 2>&1 && [[ -n "$target_user" ]]; then
  zsh_path="$(command -v zsh)"
  current_shell="$(getent passwd "$target_user" | cut -d: -f7 || true)"
  if [[ "$current_shell" != "$zsh_path" ]]; then
    if [[ -t 0 && -t 1 ]]; then
      chsh -s "$zsh_path" "$target_user"
    else
      printf 'Skipping shell change for %s: chsh needs an interactive terminal\n' "$target_user" >&2
    fi
  fi
fi

# Install Oh My Zsh once
if command -v zsh >/dev/null 2>&1; then
  if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh"
  fi
fi

# Build and install dotfiles utilities
dotfiles_utils_dir="${HOME}/dev/dotfiles-utils"

if [[ ! -d "$dotfiles_utils_dir" ]]; then
  git clone https://github.com/falkkyburz/dotfiles-utils.git "$dotfiles_utils_dir"
elif [[ ! -d "$dotfiles_utils_dir/.git" ]]; then
  printf '%s exists but is not a git repository\n' "$dotfiles_utils_dir" >&2
  exit 1
fi

git -C "$dotfiles_utils_dir" submodule update --init --recursive
cmake -S "$dotfiles_utils_dir" -B "$dotfiles_utils_dir/build/release" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${HOME}/.local"
cmake --build "$dotfiles_utils_dir/build/release" --parallel
cmake --install "$dotfiles_utils_dir/build/release"

# Build and install Hyprland screen picker
hyprscreenpicker_dir="${HOME}/dev/hyprscreenpicker"

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
helpers_file="$HOME/.config/xfce4/helpers.rc"
touch "$helpers_file"
if grep -q '^TerminalEmulator=' "$helpers_file"; then
  sed -i 's/^TerminalEmulator=.*/TerminalEmulator=kitty/' "$helpers_file"
else
  # Start a new line even if the existing file has no trailing newline.
  printf '\nTerminalEmulator=kitty\n' >> "$helpers_file"
fi
