#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/.local/share/windows-docker"

cd "${PROJECT_DIR}"

if ! docker ps --format '{{.Names}}' | grep -qx windows; then
  docker compose up -d
fi

echo "Windows VM is starting."
echo "Open: http://localhost:8006"
echo
echo "Follow logs with:"
echo "  docker logs -f windows"

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "http://localhost:8006" >/dev/null 2>&1 || true
fi

exec docker logs -f windows
