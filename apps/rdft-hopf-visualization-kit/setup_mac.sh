#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Using Python: $($PYTHON_BIN -c 'import sys; print(sys.executable)')"
echo "Python version: $($PYTHON_BIN -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"

$PYTHON_BIN -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt

python validate_csv.py data/osc_state_2026-06-15_08-20-12.csv

cat <<'MSG'

Setup complete.

Run the viewer with:
  ./run_viewer.sh

Or choose a different view:
  ./run_viewer.sh --view pca
  ./run_viewer.sh --view winding

MSG
