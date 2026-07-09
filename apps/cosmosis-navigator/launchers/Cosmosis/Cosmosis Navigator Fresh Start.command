#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================"
echo " Cosmosis Navigator Fresh Start"
echo "========================================"
echo
echo "This will stop stale project processes, rebuild the Launchpad bridge,"
echo "then open SuperCollider and Processing."
echo

/bin/bash "$PROJECT_DIR/fresh_start_cosmosis.sh"

echo
echo "Fresh start command finished."
echo "You can close this Terminal window after Processing and SuperCollider are open."
