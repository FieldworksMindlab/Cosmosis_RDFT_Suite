#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

if [[ -z "${PYTHON_BIN:-}" && -x "$PROJECT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
else
  PYTHON_BIN="${PYTHON_BIN:-python3}"
fi
HOLO_HOST="${HOLO_HOST:-127.0.0.1}"
SOLAR_PORT="${SOLAR_PORT:-5060}"
SOLAR_INTERVAL="${SOLAR_INTERVAL:-120}"
SOLAR_SIMULATE="${SOLAR_SIMULATE:-0}"
OCEAN_PORT="${OCEAN_PORT:-5062}"
OCEAN_INTERVAL="${OCEAN_INTERVAL:-180}"
OCEAN_STATION="${OCEAN_STATION:-9414290}"
OCEAN_SIMULATE="${OCEAN_SIMULATE:-0}"
GALAXY_REFRESH="${GALAXY_REFRESH:-0}"
GALAXY_TIMEOUT_SECONDS="${GALAXY_TIMEOUT_SECONDS:-20}"
SURFACE_MODE="${SURFACE_MODE:-gyroid}"
SURFACE_GRID="${SURFACE_GRID:-32}"
SURFACE_FPS="${SURFACE_FPS:-12}"
SURFACE_TERRAIN_SOURCE="${SURFACE_TERRAIN_SOURCE:-opentopodata}"
SURFACE_TERRAIN_PRESET="${SURFACE_TERRAIN_PRESET:-grand_canyon}"
SURFACE_TERRAIN_DEMTYPE="${SURFACE_TERRAIN_DEMTYPE:-srtm30m}"
SURFACE_TERRAIN_BATCH_DELAY="${SURFACE_TERRAIN_BATCH_DELAY:-1.1}"
LAUNCHPAD_BRIDGE="${LAUNCHPAD_BRIDGE:-1}"
LAUNCHPAD_PAINT="${LAUNCHPAD_PAINT:-1}"
SWIFT_BIN="${SWIFT_BIN:-swift}"
HOLO_OPEN_PROCESSING="${HOLO_OPEN_PROCESSING:-1}"
HOLO_OPEN_SUPERCOLLIDER="${HOLO_OPEN_SUPERCOLLIDER:-1}"
PROCESSING_APP="${PROCESSING_APP:-Processing}"
SUPERCOLLIDER_APP="${SUPERCOLLIDER_APP:-SuperCollider}"

LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$PROJECT_DIR/.holo_pids"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$PROJECT_DIR/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$PROJECT_DIR/.cache}"
export ASTROPY_CONFIG_DIR="${ASTROPY_CONFIG_DIR:-$XDG_CONFIG_HOME/astropy}"
export ASTROPY_CACHE_DIR="${ASTROPY_CACHE_DIR:-$XDG_CACHE_HOME/astropy}"
mkdir -p "$LOG_DIR" "$PID_DIR" "$PROJECT_DIR/maps" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$ASTROPY_CONFIG_DIR" "$ASTROPY_CACHE_DIR"

echo "HOLO Mac package starting from: $PROJECT_DIR"

if [[ -f "$PID_DIR/solar.pid" ]] && kill -0 "$(cat "$PID_DIR/solar.pid")" 2>/dev/null; then
  echo "solar_weather_bridge.py is already running with PID $(cat "$PID_DIR/solar.pid")"
else
  solar_args=(solar_weather_bridge.py --host "$HOLO_HOST" --port "$SOLAR_PORT" --interval "$SOLAR_INTERVAL")
  if [[ "$SOLAR_SIMULATE" == "1" ]]; then
    solar_args+=(--simulate)
  fi
  nohup "$PYTHON_BIN" "${solar_args[@]}" > "$LOG_DIR/solar_weather_bridge.log" 2>&1 &
  echo "$!" > "$PID_DIR/solar.pid"
  echo "Started solar sender PID $(cat "$PID_DIR/solar.pid") -> $LOG_DIR/solar_weather_bridge.log"
fi

if [[ -f "ocean_current_bridge.py" ]]; then
  if [[ -f "$PID_DIR/ocean.pid" ]] && kill -0 "$(cat "$PID_DIR/ocean.pid")" 2>/dev/null; then
    echo "ocean_current_bridge.py is already running with PID $(cat "$PID_DIR/ocean.pid")"
  else
    ocean_args=(ocean_current_bridge.py --host "$HOLO_HOST" --port "$OCEAN_PORT" --interval "$OCEAN_INTERVAL" --station "$OCEAN_STATION")
    if [[ "$OCEAN_SIMULATE" == "1" ]]; then
      ocean_args+=(--simulate)
    fi
    nohup "$PYTHON_BIN" "${ocean_args[@]}" > "$LOG_DIR/ocean_current_bridge.log" 2>&1 &
    echo "$!" > "$PID_DIR/ocean.pid"
    echo "Started ocean sender PID $(cat "$PID_DIR/ocean.pid") -> $LOG_DIR/ocean_current_bridge.log"
  fi
else
  echo "No ocean_current_bridge.py found; ocean sensing layer remains optional."
fi

if [[ "$GALAXY_REFRESH" == "1" ]]; then
  echo "Refreshing galaxy maps once -> $LOG_DIR/galaxy_bridge.log"
  if command -v timeout >/dev/null 2>&1; then
    galaxy_cmd=(timeout "$GALAXY_TIMEOUT_SECONDS" "$PYTHON_BIN" galaxy_bridge.py)
  else
    galaxy_cmd=("$PYTHON_BIN" galaxy_bridge.py)
  fi
  if "${galaxy_cmd[@]}" > "$LOG_DIR/galaxy_bridge.log" 2>&1; then
    echo "Galaxy maps refreshed in $PROJECT_DIR/maps"
  else
    echo "Galaxy refresh failed, timed out, or dependencies are missing. Existing maps remain usable."
    echo "See $LOG_DIR/galaxy_bridge.log"
  fi
else
  echo "Skipping galaxy refresh; using cached maps in $PROJECT_DIR/maps"
fi

if [[ -f "surface_sender.py" ]]; then
  if [[ -f "$PID_DIR/surface.pid" ]] && kill -0 "$(cat "$PID_DIR/surface.pid")" 2>/dev/null; then
    echo "surface_sender.py is already running with PID $(cat "$PID_DIR/surface.pid")"
  else
    nohup "$PYTHON_BIN" surface_sender.py \
      --host "$HOLO_HOST" \
      --mode "$SURFACE_MODE" \
      --grid "$SURFACE_GRID" \
      --fps "$SURFACE_FPS" \
      --terrain-source "$SURFACE_TERRAIN_SOURCE" \
      --terrain-preset "$SURFACE_TERRAIN_PRESET" \
      --terrain-demtype "$SURFACE_TERRAIN_DEMTYPE" \
      --terrain-batch-delay "$SURFACE_TERRAIN_BATCH_DELAY" \
      > "$LOG_DIR/surface_sender.log" 2>&1 &
    echo "$!" > "$PID_DIR/surface.pid"
    echo "Started surface sender PID $(cat "$PID_DIR/surface.pid") -> $LOG_DIR/surface_sender.log"
  fi
else
  echo "No surface_sender.py found; surface layer remains optional."
fi

if [[ "$LAUNCHPAD_BRIDGE" == "1" && -f "launchpad_bridge.swift" ]]; then
  if [[ -f "$PID_DIR/launchpad.pid" ]] && kill -0 "$(cat "$PID_DIR/launchpad.pid")" 2>/dev/null; then
    old_launchpad_pid="$(cat "$PID_DIR/launchpad.pid")"
    kill "$old_launchpad_pid" 2>/dev/null || true
    rm -f "$PID_DIR/launchpad.pid"
    echo "Restarted Launchpad bridge; stopped old PID $old_launchpad_pid so RDFT pad colors/mode can be reclaimed."
  fi
  if command -v "$SWIFT_BIN" >/dev/null 2>&1; then
    mkdir -p "$XDG_CACHE_HOME/swift-module-cache" "$XDG_CACHE_HOME/clang-module-cache"
    nohup env CLANG_MODULE_CACHE_PATH="$XDG_CACHE_HOME/clang-module-cache" \
      RDFT_LPX_PAINT="$LAUNCHPAD_PAINT" \
      "$SWIFT_BIN" -module-cache-path "$XDG_CACHE_HOME/swift-module-cache" launchpad_bridge.swift \
      > "$LOG_DIR/launchpad_bridge.log" 2>&1 &
    echo "$!" > "$PID_DIR/launchpad.pid"
    echo "Started Launchpad bridge PID $(cat "$PID_DIR/launchpad.pid") -> $LOG_DIR/launchpad_bridge.log"
  else
    echo "Swift not found; Launchpad bridge disabled. macOS sees the Launchpad, but Processing Java cannot read it directly."
  fi
fi

if [[ "$HOLO_OPEN_SUPERCOLLIDER" == "1" ]]; then
  open -a "$SUPERCOLLIDER_APP" "$PROJECT_DIR/ColdSun_Shimmer.scd" 2>/dev/null || \
    echo "Could not open SuperCollider app '$SUPERCOLLIDER_APP'. Open ColdSun_Shimmer.scd manually."
fi

if [[ "$HOLO_OPEN_PROCESSING" == "1" ]]; then
  open -a "$PROCESSING_APP" "$PROJECT_DIR" 2>/dev/null || \
    echo "Could not open Processing app '$PROCESSING_APP'. Open this sketch folder manually."
fi

echo "Package started. Use ./stop_chladni_mac.sh to stop background senders."
