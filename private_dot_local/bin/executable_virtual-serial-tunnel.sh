#!/usr/bin/env bash
set -euo pipefail

PORT_A="/tmp/ttyV0"
PORT_B="/tmp/ttyV1"
BAUD="115200"

usage() {
  cat <<'USAGE'
Create a virtual serial tunnel using socat.

Data written to one virtual serial port is readable from the other.

Usage:
  virtual-serial-tunnel.sh [options]

Options:
  -a, --port-a PATH   First virtual serial link  (default: /tmp/ttyV0)
  -b, --port-b PATH   Second virtual serial link (default: /tmp/ttyV1)
  -r, --baud RATE     Baud rate to set on both PTYs (default: 115200)
  -h, --help          Show this help text

Examples:
  ./virtual-serial-tunnel.sh
  ./virtual-serial-tunnel.sh -a /tmp/gps0 -b /tmp/gps1 -r 9600

Test in two terminals:
  cat /tmp/ttyV1
  printf 'hello\n' > /tmp/ttyV0
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$1" >&2
    printf 'Install it with your package manager, for example: sudo apt install socat\n' >&2
    exit 127
  fi
}

cleanup() {
  rm -f -- "$PORT_A" "$PORT_B"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--port-a)
      [[ $# -ge 2 ]] || { printf 'Error: %s requires a path\n' "$1" >&2; exit 2; }
      PORT_A="$2"
      shift 2
      ;;
    -b|--port-b)
      [[ $# -ge 2 ]] || { printf 'Error: %s requires a path\n' "$1" >&2; exit 2; }
      PORT_B="$2"
      shift 2
      ;;
    -r|--baud)
      [[ $# -ge 2 ]] || { printf 'Error: %s requires a baud rate\n' "$1" >&2; exit 2; }
      BAUD="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$PORT_A" == "$PORT_B" ]]; then
  printf 'Error: port paths must be different\n' >&2
  exit 2
fi

if [[ ! "$BAUD" =~ ^[0-9]+$ ]]; then
  printf 'Error: baud rate must be numeric: %s\n' "$BAUD" >&2
  exit 2
fi

require_command socat

cleanup
trap cleanup EXIT INT TERM

printf 'Creating virtual serial tunnel:\n'
printf '  %s <-> %s\n' "$PORT_A" "$PORT_B"
printf '  baud: %s\n\n' "$BAUD"
printf 'Keep this process running while using the ports. Press Ctrl-C to stop.\n\n'

exec socat -d -d \
  "PTY,link=${PORT_A},raw,echo=0,b${BAUD}" \
  "PTY,link=${PORT_B},raw,echo=0,b${BAUD}"
