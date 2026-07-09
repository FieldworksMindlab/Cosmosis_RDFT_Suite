#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CSV_PATH="${CSV_PATH:-}"

if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  CSV_PATH="$1"
  shift
fi

CSV_PATH="${CSV_PATH:-data/osc_state_2026-06-23_18-23-44.csv}"

VIEW_WAS_SET=0
for arg in "$@"; do
  case "$arg" in
    --view|--view=*)
      VIEW_WAS_SET=1
      ;;
  esac
done

if [ ! -d ".venv" ]; then
  echo "No .venv found. Running setup first..."
  ./setup_mac.sh
fi

source .venv/bin/activate

if [ "$VIEW_WAS_SET" -eq 1 ]; then
  python rdft_hopf_pygfx_viewer.py "$CSV_PATH" "$@"
else
  python rdft_hopf_pygfx_viewer.py "$CSV_PATH" --view phase "$@"
fi
