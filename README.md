# dotfiles (chezmoi)

Personal Arch Linux workstation dotfiles managed with [chezmoi](https://www.chezmoi.io/).

This is not a generic portable profile. Some managed files intentionally assume this user's paths and workstation layout, including `/home/falk` and `~/Work`.

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

## Boot And Kernel

The current setup provisions mkinitcpio UKI output paths for systemd-boot-style unified kernel images. It writes `/etc/mkinitcpio.d/linux.preset` with these targets:

- `/boot/EFI/Linux/arch-linux.efi`
- `/boot/EFI/Linux/arch-linux-fallback.efi`

It also seeds `/etc/kernel/cmdline` from the current kernel command line when that file does not exist.

Manual kernel artifact refresh:

```bash
sudo mkinitcpio -P
```

This repo no longer configures the old Limine staged-kernel workflow.
