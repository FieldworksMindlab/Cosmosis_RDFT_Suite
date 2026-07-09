#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

MODE="${1:-real_topography}"
PRESET="${2:-grand_canyon}"
SOURCE="${3:-opentopodata}"

exec "$PYTHON_BIN" surface_sender.py \
  --mode "$MODE" \
  --terrain-source "$SOURCE" \
  --terrain-preset "$PRESET"
