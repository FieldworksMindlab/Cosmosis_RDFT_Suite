#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$PROJECT_DIR/.holo_pids"

stop_pid_file() {
  local name="$1"
  local file="$PID_DIR/$name.pid"
  if [[ ! -f "$file" ]]; then
    echo "$name: no pid file"
    return
  fi

  local pid
  pid="$(cat "$file")"
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo "$name: stopped PID $pid"
  else
    echo "$name: PID $pid was not running"
  fi
  rm -f "$file"
}

stop_pid_file solar
stop_pid_file ocean
stop_pid_file surface
