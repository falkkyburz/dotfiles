#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${HOME}/.local/share/windows-docker"

cd "${PROJECT_DIR}"
exec docker compose stop
