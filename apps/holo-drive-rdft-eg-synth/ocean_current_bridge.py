#!/usr/bin/env python3
"""
RDFT Ocean Current Bridge
-------------------------
Fetches NOAA CO-OPS tide/water-temperature data and sends a compact local UDP
packet to Processing. Processing listens on UDP port 5062 and forwards the
normalized field to SuperCollider as /rdf/ocean.

Default packet:
OCEAN:tide=<m>,temp_c=<C>,current=<0-1>,phase=<0-1>,range=<m>,velocity=<0-1>,accel=<0-1>,energy=<0-1>,memory=<0-1>,live=<0-1>

The current value is a tidal-current proxy derived from recent water-level
slope. This is robust for tide stations; exact current-bin stations can be
added later for a chosen harbor/channel.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import socket
import time
import urllib.parse
import urllib.request
from typing import Any

COOPS = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
ocean_memory = 0.0


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def fetch_json(params: dict[str, str], timeout: float = 10.0) -> Any:
    url = COOPS + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except Exception:
        return default


def coops_data(station: str, product: str, hours: int = 6) -> list[dict[str, Any]]:
    now = utc_now()
    begin = now - dt.timedelta(hours=hours)
    params = {
        "product": product,
        "application": "RDFT_HOLO_SYNTH",
        "begin_date": begin.strftime("%Y%m%d %H:%M"),
        "end_date": now.strftime("%Y%m%d %H:%M"),
        "datum": "MLLW",
        "station": station,
        "time_zone": "gmt",
        "units": "metric",
        "format": "json",
    }
    if product == "water_temperature":
        params.pop("datum", None)
    data = fetch_json(params)
    rows = data.get("data") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def normalize(values: list[float], value: float) -> float:
    if not values:
        return 0.5
    lo = min(values)
    hi = max(values)
    span = max(0.001, hi - lo)
    return max(0.0, min(1.0, (value - lo) / span))


def derive_dynamics(levels: list[float], current: float) -> tuple[float, float, float]:
    idx_now = len(levels) - 1
    idx_mid = max(0, len(levels) - 3)
    idx_old = max(0, len(levels) - 6)
    tide_now = levels[idx_now]
    tide_mid = levels[idx_mid]
    tide_old = levels[idx_old]
    tide_range = max(0.001, max(levels) - min(levels))

    velocity_raw = abs(tide_now - tide_mid)
    accel_raw = abs(tide_now - (2.0 * tide_mid) + tide_old)
    velocity = max(0.0, min(1.0, velocity_raw / max(0.02, tide_range * 0.20)))
    accel = max(0.0, min(1.0, accel_raw / max(0.01, tide_range * 0.08)))

    energy = max(
        0.0,
        min(
            1.0,
            current * 0.35
            + velocity * 0.40
            + accel * 0.25,
        ),
    )
    return velocity, accel, energy


def fetch_ocean(station: str) -> tuple[float, float, float, float, float, float, float, float, float, float]:
    water = coops_data(station, "water_level", hours=6)
    if len(water) < 2:
        raise RuntimeError("not enough water_level data")

    levels = [as_float(row.get("v"), 0.0) for row in water if "v" in row]
    tide = levels[-1]
    tide_range = max(0.001, max(levels) - min(levels))
    phase = normalize(levels, tide)

    # Tidal current proxy: recent water-level slope relative to observed range.
    prev = levels[max(0, len(levels) - 6)]
    slope = abs(tide - prev)
    current = max(0.0, min(1.0, slope / max(0.04, tide_range * 0.30)))

    temp_rows = coops_data(station, "water_temperature", hours=6)
    temp_c = 12.0
    vals: list[float] = []
    if temp_rows:
        vals = [as_float(row.get("v"), temp_c) for row in temp_rows if "v" in row]
        if vals:
            temp_c = vals[-1]
    velocity, accel, energy = derive_dynamics(levels, current)
    live = 1.0
    return tide, temp_c, current, phase, tide_range, velocity, accel, energy, 0.0, live


def simulated_ocean(t: float) -> tuple[float, float, float, float, float, float, float, float, float, float]:
    phase_wave = 0.5 + 0.5 * math.sin(t * 0.0014)
    tide = 0.8 * math.sin(t * 0.0014)
    current = abs(math.cos(t * 0.0014))
    temp_c = 13.0 + 4.0 * math.sin(t * 0.00018)
    tide_range = 1.6
    velocity = abs(math.cos(t * 0.0014))
    accel = abs(math.sin(t * 0.0028)) * 0.55
    energy = max(0.0, min(1.0, current * 0.35 + velocity * 0.40 + accel * 0.25))
    return tide, temp_c, current, phase_wave, tide_range, velocity, accel, energy, 0.0, 1.0


def with_memory(values: tuple[float, float, float, float, float, float, float, float, float, float]) -> tuple[float, float, float, float, float, float, float, float, float, float]:
    global ocean_memory
    tide, temp_c, current, phase, tide_range, velocity, accel, energy, _memory, live = values
    ocean_memory = (0.96 * ocean_memory) + (0.04 * energy)
    return tide, temp_c, current, phase, tide_range, velocity, accel, energy, ocean_memory, live


def format_packet(values: tuple[float, float, float, float, float, float, float, float, float, float]) -> str:
    tide, temp_c, current, phase, tide_range, velocity, accel, energy, memory, live = values
    return (
        f"OCEAN:tide={tide:.4f},temp_c={temp_c:.3f},current={current:.4f},"
        f"phase={phase:.4f},range={tide_range:.4f},"
        f"velocity={velocity:.4f},accel={accel:.4f},energy={energy:.4f},"
        f"memory={memory:.4f},live={live:.1f}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Send NOAA ocean/tide field data to RDFT Processing over UDP.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=5062)
    parser.add_argument("--interval", type=float, default=180.0)
    parser.add_argument("--station", default="9414290", help="NOAA CO-OPS station, default San Francisco")
    parser.add_argument("--simulate", action="store_true")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"RDFT ocean bridge sending to {args.host}:{args.port} station={args.station} every {args.interval}s")
    while True:
        try:
            values = simulated_ocean(time.time()) if args.simulate else fetch_ocean(args.station)
            packet = format_packet(with_memory(values))
        except Exception as exc:
            print(f"Ocean API fetch failed; sending live=0.0 fallback: {exc}")
            packet = "OCEAN:live=0.0"
        sock.sendto(packet.encode("utf-8"), (args.host, args.port))
        print(packet)
        time.sleep(max(20.0, args.interval))


if __name__ == "__main__":
    main()
