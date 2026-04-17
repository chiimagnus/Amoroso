#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${SERVER_DIR}"

./.venv/bin/pyinstaller \
  --noconfirm \
  --clean \
  --name lp-omr-convert \
  --paths "${SERVER_DIR}" \
  --distpath "${SCRIPT_DIR}/dist" \
  --workpath "${SCRIPT_DIR}/build" \
  omr/cli.py
