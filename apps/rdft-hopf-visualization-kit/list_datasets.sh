#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Viewer datasets in:"
echo "  $(pwd)/data"
echo
find data -maxdepth 1 -name 'osc_state_*.csv' -type f -print | sort
