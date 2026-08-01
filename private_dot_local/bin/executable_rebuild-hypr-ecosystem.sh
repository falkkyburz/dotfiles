#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "Error: pacman not found." >&2
  exit 1
fi

if ! command -v yay >/dev/null 2>&1; then
  echo "Error: yay not found." >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "Error: rg (ripgrep) not found." >&2
  exit 1
fi

mapfile -t pkgs < <(pacman -Qq | rg '^(aquamarine-git|hypr.*-git|xdg-desktop-portal-hyprland-git)$')

if [ "${#pkgs[@]}" -eq 0 ]; then
  echo "No matching Hypr ecosystem -git packages are installed."
else
  echo "Will rebuild these packages:"
  printf '  %s\n' "${pkgs[@]}"

  echo
  echo "Clearing yay cache for selected packages..."
  for p in "${pkgs[@]}"; do
    rm -rf "${HOME}/.cache/yay/$p"
  done

  echo
  echo "Rebuilding selected packages with yay..."
  yay -S --devel --rebuild --answerclean All --answerdiff None "${pkgs[@]}"
fi

echo
echo "Building hyprscreenpicker..."
hyprscreenpicker_dir="${HOME}/Work/hyprscreenpicker"

if [[ ! -e "$hyprscreenpicker_dir" ]]; then
  git clone https://github.com/falkkyburz/hyprscreenpicker.git "$hyprscreenpicker_dir"
elif [[ ! -d "$hyprscreenpicker_dir/.git" ]]; then
  printf 'Error: %s exists but is not a git repository.\n' "$hyprscreenpicker_dir" >&2
  exit 1
fi

cmake \
  -S "$hyprscreenpicker_dir" \
  -B "$hyprscreenpicker_dir/build/release" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${HOME}/.local"
cmake --build "$hyprscreenpicker_dir/build/release" --parallel
cmake --install "$hyprscreenpicker_dir/build/release"

echo
echo "Done. Recommended checks:"
echo "  ldd /usr/lib/libhyprwire.so.3 | rg hyprutils"
echo "  hyprctl version"
echo "  hyprctl clients"
