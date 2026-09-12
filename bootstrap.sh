#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if ((EUID == 0)); then
  echo 'Run as the intended desktop user with sudo access, not as root.' >&2
  exit 1
fi
if [[ ! -f /etc/arch-release || $(uname -m) != x86_64 ]] || ! command -v pacman >/dev/null; then
  echo 'This bootstrap requires an installed x86_64 Arch Linux system.' >&2
  exit 1
fi

# A preview never installs or upgrades anything. Install a supported mise first.
for argument in "$@"; do
  if [[ "$argument" == --dry-run || "$argument" == -n ]]; then
    exec /usr/bin/mise bootstrap "$@"
  fi
done

bash scripts/prerequisites.sh
minimum=2026.9.2
repository_version=$(LC_ALL=C pacman -Si mise | awk '/^Version[[:space:]]*:/ {print $3; exit}')
if [[ -z "$repository_version" ]]; then
  echo 'Cannot determine the official mise package version.' >&2
  exit 1
fi
if [[ $(vercmp "$repository_version" "$minimum") -ge 0 ]]; then
  sudo pacman -S --needed mise
else
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed mise-bin
  else
    paru -S --needed mise-bin
  fi
fi

# Both packages own /usr/bin/mise; never depend on a separate upstream binary.
/usr/bin/mise trust "$PWD/mise.toml"
exec /usr/bin/mise bootstrap "$@"
