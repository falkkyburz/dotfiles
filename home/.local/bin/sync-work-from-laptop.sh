#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: sync-work-from-laptop.sh [--delete] [host] [user] [remote-dir] [local-dir]

Copy a dev directory from another laptop to this computer.

Defaults:
  host        192.168.1.119
  user        current local user
  remote-dir  /home/<user>/dev
  local-dir   $HOME/dev

Local-only files are preserved unless --delete is explicitly supplied.

Examples:
  sync-work-from-laptop.sh
  sync-work-from-laptop.sh 192.168.1.42
  sync-work-from-laptop.sh 192.168.1.42 falk
  sync-work-from-laptop.sh --delete 192.168.1.42
EOF
}

delete=false
case "${1:-}" in
  --delete)
    delete=true
    shift
    ;;
  -h|--help)
    usage
    exit 0
    ;;
esac

host="${1:-192.168.1.119}"
remote_user="${2:-$(id -un)}"
remote_dir="${3:-/home/${remote_user}/dev}"
local_dir="${4:-${HOME}/dev}"

for command_name in rsync ssh; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
done

mkdir -p -- "$local_dir"

rsync_options=(-a --human-readable --info=progress2)
if "$delete"; then
  printf 'WARNING: deleting local files absent from the source is enabled.\n'
  rsync_options+=(--delete)
fi

# Bypass a broken system-wide SSH configuration while retaining normal keys and
# known-host checking. Remove this option if your setup relies on ~/.ssh/config.
export RSYNC_RSH='ssh -F /dev/null'

printf 'Copying %s@%s:%s/ to %s/\n' \
  "$remote_user" "$host" "$remote_dir" "$local_dir"

rsync "${rsync_options[@]}" \
  "${remote_user}@${host}:${remote_dir%/}/" \
  "${local_dir%/}/"

printf '\ndev directory sync completed.\n'
