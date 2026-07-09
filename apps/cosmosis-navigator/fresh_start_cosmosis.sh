#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$PROJECT_DIR/.holo_pids"
LAUNCHPAD_BRIDGE_MARKER="Cosmosis Launchpad bridge led-static-v1"
mkdir -p "$LOG_DIR" "$PID_DIR"

echo "Cosmosis fresh start: stopping project background processes..."
/bin/bash "$PROJECT_DIR/stop_chladni_mac.sh" || true

echo "Cosmosis fresh start: stopping stale Launchpad bridge processes..."
pkill -f "$PROJECT_DIR/launchpad_bridge" 2>/dev/null || true
pkill -f "$PROJECT_DIR/launchpad_bridge.swift" 2>/dev/null || true
rm -f "$PID_DIR/launchpad.pid"

if [[ "${COSMOSIS_QUIT_APPS:-1}" == "1" ]]; then
  echo "Cosmosis fresh start: asking Processing and SuperCollider to quit..."
  osascript -e 'tell application "Processing" to quit' >/dev/null 2>&1 || true
  osascript -e 'tell application "SuperCollider" to quit' >/dev/null 2>&1 || true
  sleep 2
fi

echo "Cosmosis fresh start: forcing Launchpad bridge rebuild..."
rm -f "$PROJECT_DIR/launchpad_bridge"

export LAUNCHPAD_BRIDGE=1
export HOLO_OPEN_PROCESSING=1
export HOLO_OPEN_SUPERCOLLIDER=1

echo "Cosmosis fresh start: launching full stack..."
/bin/bash "$PROJECT_DIR/start_chladni_mac.sh"

if ! strings "$PROJECT_DIR/launchpad_bridge" | grep -Fq "$LAUNCHPAD_BRIDGE_MARKER"; then
  echo "ERROR: rebuilt Launchpad bridge is missing current static-LED marker."
  exit 1
fi
for stale in "RDFT Launchpad page CC" "/lpx" "GALAXY SHEAR" "RDFT_LPX_PAINT" "static-8 scale-page"; do
  if strings "$PROJECT_DIR/launchpad_bridge" | grep -Fq "$stale"; then
    echo "ERROR: rebuilt Launchpad bridge still contains stale marker '$stale'."
    exit 1
  fi
done

echo "Cosmosis fresh start complete."
