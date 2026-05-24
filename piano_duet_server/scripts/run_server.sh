#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PYTHON="${PYTHON:-}"
if [ -z "$PYTHON" ]; then
  if command -v python3.10 >/dev/null 2>&1; then
    PYTHON="python3.10"
  elif command -v python3.12 >/dev/null 2>&1; then
    PYTHON="python3.12"
  else
    PYTHON="python3"
  fi
fi

if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "Error: $PYTHON not found. Install Python 3.10+ or run with: PYTHON=python3 ./scripts/run_server.sh" >&2
  exit 1
fi

if [ "${DUET_ENGINE:-placeholder}" = "magenta" ]; then
  py_ver="$("$PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  if [ "$py_ver" != "3.10" ] && [ "$py_ver" != "3.9" ]; then
    echo "Error: DUET_ENGINE=magenta requires Python 3.9/3.10 (got ${py_ver})." >&2
    echo "Install python3.10 and run: PYTHON=python3.10 DUET_ENGINE=magenta ./scripts/run_server.sh" >&2
    exit 1
  fi
fi

if [ ! -d ".venv" ]; then
  "$PYTHON" -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

PIP_PROGRESS_BAR=off python -m pip install -q -U pip
PIP_PROGRESS_BAR=off pip install -q -r requirements.txt

if [ "${DUET_ENGINE:-auto}" = "magenta" ]; then
  if [ -f "requirements-magenta.txt" ]; then
    echo "Installing Magenta requirements..."
    PIP_PROGRESS_BAR=off pip install -q -r requirements-magenta.txt
  fi
fi

PORT="${PORT:-8766}"
exec python -m uvicorn server.api.main:app --host 0.0.0.0 --port "$PORT"
