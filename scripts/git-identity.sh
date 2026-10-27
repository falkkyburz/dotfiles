#!/usr/bin/env bash
set -euo pipefail

name=$(git config --global --get user.name || true)
email=$(git config --global --get user.email || true)

if [[ -n "$name" && -n "$email" ]]; then
  exit 0
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  gh auth login --hostname github.com --git-protocol https --web
fi

profile=$(gh api --hostname github.com user)

if [[ -z "$name" ]]; then
  name=$(jq -r '.name | select(. != null and . != "")' <<<"$profile")
  if [[ -z "$name" ]]; then
    name=$(jq -r '.login' <<<"$profile")
  fi
  git config --global user.name "$name"
fi

if [[ -z "$email" ]]; then
  email=$(jq -r '"\(.id)+\(.login)@users.noreply.github.com"' <<<"$profile")
  git config --global user.email "$email"
fi
