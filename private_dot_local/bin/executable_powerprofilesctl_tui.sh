#!/usr/bin/env bash
set -euo pipefail

command -v powerprofilesctl >/dev/null || {
  echo "missing: powerprofilesctl" >&2
  exit 1
}
command -v fzf >/dev/null || {
  echo "missing: fzf" >&2
  exit 1
}

ACTIVE="$(powerprofilesctl get 2>/dev/null | tr -d '\r\n')"

render() {
  local p
  for p in power-saver balanced performance; do
    if [[ "$p" == "$ACTIVE" ]]; then
      printf "●\t\033[1;32m%s\033[0m  \033[2m(active)\033[0m\n" "$p"
    else
      printf " \t%s\n" "$p"
    fi
  done
}

choice="$(
  render |
    fzf --ansi --no-sort --cycle --no-multi --no-input \
      --delimiter=$'\t' --with-nth=2.. \
      --pointer='▶' --marker='' \
      --height=~10 --border=rounded \
      --bind 'j:down,k:up,h:up,l:accept,enter:accept,q:abort,esc:abort'
)" || exit 0

PROFILE="$(
  printf "%s\n" "$choice" |
    sed -E $'s/^[^\t]*\t//; s/\x1B\\[[0-9;]*[mK]//g; s/[[:space:]]+\\(active\\)[[:space:]]*$//; s/[[:space:]]+$//'
)"

[[ -n "${PROFILE// /}" ]] || exit 0
[[ "$PROFILE" == "$ACTIVE" ]] || powerprofilesctl set "$PROFILE"
