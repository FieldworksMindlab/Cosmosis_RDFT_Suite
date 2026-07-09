#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_DIR="$ROOT/.shaper_pids"
LOG_DIR="$ROOT/logs"
PID_FILE="$PID_DIR/shaper_sender.pid"
PYTHON_BIN="${PYTHON_BIN:-python3}"
INTERVAL="${SHAPER_INTERVAL:-180}"
STATION="${SHAPER_OCEAN_STATION:-9414290}"
MIX="${SHAPER_MIX:-0.62}"

mkdir -p "$PID_DIR" "$LOG_DIR"
cd "$ROOT"

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "shaper_sender.py is already running with PID $(cat "$PID_FILE")"
  exit 0
fi

args=(senders/shaper_sender.py --interval "$INTERVAL" --station "$STATION" --mix "$MIX")
if [[ "${SHAPER_SIMULATE:-0}" == "1" ]]; then
  args+=(--simulate)
fi

nohup "$PYTHON_BIN" "${args[@]}" > "$LOG_DIR/shaper_sender.log" 2>&1 &
echo $! > "$PID_FILE"
echo "Started Shaper Sender PID $(cat "$PID_FILE") -> $LOG_DIR/shaper_sender.log"

