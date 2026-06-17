#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

opencode_has_credentials() {
  local output

  output="$(opencode auth list 2>/dev/null || true)"
  grep -Eq '(^|[^0-9])[1-9][0-9]* credentials?\b' <<<"$output"
}

needs=()

if have gh && ! gh auth status >/dev/null 2>&1; then
  needs+=("GitHub CLI: gh auth login")
fi

if have nordvpn && ! nordvpn account >/dev/null 2>&1; then
  needs+=("NordVPN: nordvpn login")
fi

if have opencode && ! opencode_has_credentials; then
  needs+=("opencode: opencode auth login")
fi

if ((${#needs[@]} == 0)); then
  exit 0
fi

printf '\nPost-install login reminders:\n'
printf '  - %s\n' "${needs[@]}"
printf '\n'
