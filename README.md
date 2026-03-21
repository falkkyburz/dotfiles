# dotfiles (chezmoi)

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/).

Target system:
- Arch Linux
- Hyprland (Wayland)
- kitty
- zsh
- Neovim

The repository is structured to be reproducible, idempotent, and machine-portable.


## Kernel updates with Limine

On this system, `limine-snapper-sync` alone is **not enough** after a kernel update.

### Why

The normal Arch kernel update recreates:

- `/boot/vmlinuz-linux`
- `/boot/initramfs-linux.img`

But Limine boots the **staged copies** referenced in `/boot/limine.conf`, for example:

- `/boot/<machine-id>/linux/vmlinuz-linux`
- `/boot/<machine-id>/linux/initramfs-linux.img`

These staged files must be refreshed after each kernel update.

### Safe update sequence

```bash
mount | grep ' /boot ' &&
sudo mkinitcpio -P &&
sudo limine-entry-tool --add linux /boot/initramfs-linux.img /boot/vmlinuz-linux &&
sudo limine-snapper-sync
