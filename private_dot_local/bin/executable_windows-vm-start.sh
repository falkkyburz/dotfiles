#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/.local/share/windows-docker"
NOVNC_URL="http://localhost:8006"

cd "${PROJECT_DIR}"

if ! docker ps --format '{{.Names}}' | grep -qx windows; then
  docker compose up -d
fi

echo
echo "Windows VM browser UI:"
echo "${NOVNC_URL}"
echo
echo "Opening browser..."
echo "Showing container logs below. Press Ctrl+C to exit."
echo

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "${NOVNC_URL}" >/dev/null 2>&1 || true
fi

exec docker logs -f windows
