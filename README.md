# dotfiles (chezmoi)

Personal Arch Linux workstation dotfiles managed with [chezmoi](https://www.chezmoi.io/).

This is not a generic portable profile. Some managed files intentionally assume this user's workstation layout, including `~/dev`.

## Target System

- Arch Linux
- Hyprland on Wayland
- kitty
- zsh with Oh My Zsh
- Neovim
- PipeWire, WirePlumber, NetworkManager, iwd, Docker, and libvirt

## Managed Areas

- Shell, terminal, editor, browser, MIME, font, and desktop configs under `~/.config`.
- Hyprland ecosystem config for Hyprland, hypridle, hyprlock, hyprpaper, hyprsunset, hyprlauncher, and xdg-desktop-portal-hyprland.
- Local helper scripts under `~/.local/bin` for diagnostics, screenshots, screen recording, Hyprland helpers, power menus, and Windows VM helpers.
- Local data under `~/.local/share`, including wallpapers, desktop entries, sound assets, CMake presets, and Windows Docker/VM files.
- Run scripts that install Pacman and AUR packages, configure system services, write udev rules, and prepare boot/kernel artifacts.

`README.md` is ignored by chezmoi and is documentation only.

## Apply

```bash
chezmoi apply
```

The run scripts assume an Arch system with `pacman` and bootstrap `yay` for AUR packages when needed.

## Fresh Machine Checks

Before applying on a new machine, these checks catch most rendering and script syntax issues without running the privileged setup scripts:

```bash
chezmoi doctor
chezmoi apply --exclude=scripts --dry-run --verbose
bash -n run_*.sh private_dot_local/bin/executable_*
```

If `shellcheck` is installed, also run:

```bash
shellcheck -S error run_*.sh private_dot_local/bin/executable_*
```

## Doctor Scripts

The following diagnostic helpers are installed in `~/.local/bin`:

- `audio-doctor` checks PipeWire and WirePlumber services, defaults, sinks, and card profiles.
- `can-doctor` creates and verifies the `vcan0` and `vcan1` virtual CAN interfaces; run it with `sudo`.
- `clangd-doctor [project-dir]` checks a C/C++ project's clangd and compilation database setup.
- `dns-doctor [host]` inspects resolver, NetworkManager, VPN, encrypted DNS, and browser DoH state.
- `keyring-doctor` checks KWallet binaries, PAM integration, processes, DBus services, and wallet files.
- `network-doctor.sh [host]` checks devices, routes, DNS, connectivity, NetworkManager, and nftables.
- `wifi-doctor [SSID]` diagnoses NetworkManager and iwd state and can interactively clear saved authentication data.
- `xdg-doctor` checks the XDG desktop portal executables, processes, DBus names, and user services.

## Boot And Kernel

The current setup provisions mkinitcpio UKI output paths for systemd-boot-style unified kernel images. It writes `/etc/mkinitcpio.d/linux.preset` with these targets:

- `/boot/EFI/Linux/arch-linux.efi`
- `/boot/EFI/Linux/arch-linux-fallback.efi`

It also seeds `/etc/kernel/cmdline` from the current kernel command line when that file does not exist.

Manual kernel artifact refresh:

```bash
sudo mkinitcpio -P
```
