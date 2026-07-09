#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/.shaper_pids/shaper_sender.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No Shaper Sender PID file found."
  exit 0
fi

PID="$(cat "$PID_FILE")"
if kill -0 "$PID" 2>/dev/null; then
  kill "$PID"
  echo "Stopped Shaper Sender PID $PID"
else
  echo "Shaper Sender PID $PID was not running."
fi
rm -f "$PID_FILE"
