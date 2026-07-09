#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find "$ROOT" -type d \( \
  -name ".cache" -o \
  -name ".config" -o \
  -name ".holo_pids" -o \
  -name ".shaper_pids" -o \
  -name "__pycache__" -o \
  -name ".pycache" -o \
  -name "logs" -o \
  -name "recordings" -o \
  -name "exports" \
\) -prune -print

echo
echo "Dry-run only. Review the paths above before deleting anything."
