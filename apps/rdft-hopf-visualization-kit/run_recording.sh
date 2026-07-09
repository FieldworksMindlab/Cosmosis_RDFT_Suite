#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

CSV_PATH="${CSV_PATH:-}"
if [ "$#" -gt 0 ] && [[ "$1" != --* ]]; then
  CSV_PATH="$1"
  shift
fi
CSV_PATH="${CSV_PATH:-data/osc_state_2026-06-23_18-23-44.csv}"

if [ ! -d ".venv" ]; then
  echo "No .venv found. Running setup first..."
  ./setup_mac.sh
fi

source .venv/bin/activate
export MPLCONFIGDIR="$PWD/.matplotlib"
mkdir -p "$MPLCONFIGDIR"
python rdft_hopf_recorder.py "$CSV_PATH" "$@"
