#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

opencode_has_credentials() {
  local output

  output="$(opencode auth list 2>/dev/null || true)"
  grep -Eq '(^|[^0-9])[1-9][0-9]* credentials?\b' <<<"$output"
}

docker_has_credentials() {
  local config="${DOCKER_CONFIG:-$HOME/.docker}/config.json"

  [[ -f "$config" ]] || return 1

  if have jq; then
    jq -e '((.auths // {}) | length > 0) or ((.credsStore // "") | length > 0) or ((.credHelpers // {}) | length > 0)' "$config" >/dev/null 2>&1
  else
    grep -Eq '"auths"[[:space:]]*:[[:space:]]*\{[^}]|"credsStore"[[:space:]]*:|"credHelpers"[[:space:]]*:' "$config"
  fi
}

needs=()
optional=()

if have gh && ! gh auth status >/dev/null 2>&1; then
  needs+=("GitHub CLI: gh auth login")
fi

if have nordvpn && ! nordvpn account >/dev/null 2>&1; then
  needs+=("NordVPN: nordvpn login")
fi

if have opencode && ! opencode_has_credentials; then
  needs+=("opencode: opencode auth login")
fi

if have docker && ! docker_has_credentials; then
  optional+=("Docker Hub/private registries: docker login")
fi

if have npm && ! npm whoami >/dev/null 2>&1; then
  optional+=("npm registry: npm login")
fi

if ((${#needs[@]} == 0 && ${#optional[@]} == 0)); then
  exit 0
fi

if ((${#needs[@]})); then
  printf '\nPost-install login reminders:\n'
  printf '  - %s\n' "${needs[@]}"
fi

if ((${#optional[@]})); then
  printf '\nOptional account reminders:\n'
  printf '  - %s\n' "${optional[@]}"
fi

printf '\n'
