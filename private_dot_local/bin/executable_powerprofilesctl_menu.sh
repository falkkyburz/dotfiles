#!/usr/bin/env bash
set -euo pipefail

current="$(powerprofilesctl get)"

profiles=()
while IFS= read -r line; do
  [[ -n "$line" ]] && profiles+=("$line")
done < <(printf '%s\n' performance balanced power-saver)

menu_input="$(
  for p in "${profiles[@]}"; do
    if [[ "$p" == "$current" ]]; then
      printf '* %s\n' "$p"
    else
      printf '  %s\n' "$p"
    fi
  done
)"

choice="$(printf '%s\n' "$menu_input" | hyprlauncher --dmenu)"
[[ -z "${choice:-}" ]] && exit 0

profile="${choice#* }"
profile="${profile#  }"

case "$profile" in
performance | balanced | power-saver)
  powerprofilesctl set "$profile"
  ;;
esac
