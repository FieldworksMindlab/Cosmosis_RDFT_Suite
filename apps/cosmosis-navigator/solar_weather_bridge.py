#!/usr/bin/env python3
"""
RDFT Solar Weather Bridge
-------------------------
Fetches slow-changing public space-weather data and sends a compact local UDP
packet to Processing. Processing listens on UDP port 5060 and forwards the
normalized state to SuperCollider only when SOLAR→SYNTH is enabled.

Default packet:
SOLAR:xray=<W/m^2>,wind=<km/s>,bz=<nT>,kp=<0-9>,flare=<0-1>

Sources used when internet is available:
- NOAA SWPC RTSW solar wind/magnetic data
- NOAA SWPC GOES X-ray flux data
- NOAA SWPC planetary K-index data

The script has a simulation fallback so the GUI can be tested offline.
"""
from __future__ import annotations

import argparse
import json
import math
import socket
import time
import urllib.request
from typing import Any, Iterable

NOAA_XRAY_6H = "https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json"
NOAA_RTSW_WIND_1M = "https://services.swpc.noaa.gov/json/rtsw/rtsw_wind_1m.json"
NOAA_RTSW_MAG_1M = "https://services.swpc.noaa.gov/json/rtsw/rtsw_mag_1m.json"
NOAA_KP = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"


def fetch_json(url: str, timeout: float = 8.0) -> Any:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except Exception:
        return default


def newest_record(data: Any) -> dict[str, Any]:
    """Return the newest dict-like record from SWPC's mixed JSON formats."""
    if isinstance(data, dict):
        # Newer endpoints often return dictionaries or lists under a data key.
        for key in ("data", "records", "items"):
            if isinstance(data.get(key), list) and data[key]:
                return newest_record(data[key])
        return data

    if not isinstance(data, list) or not data:
        return {}

    # Old SWPC product format: first row is column names, following rows are values.
    if isinstance(data[0], list) and data and all(isinstance(k, str) for k in data[0]):
        header = data[0]
        for row in reversed(data[1:]):
            if isinstance(row, list) and len(row) == len(header):
                return dict(zip(header, row))
        return {}

    for item in reversed(data):
        if isinstance(item, dict):
            return item
    return {}


def latest_xray_flux() -> float:
    data = fetch_json(NOAA_XRAY_6H)
    # Prefer 1-8 Angstrom channel because it is the standard flare classification band.
    if isinstance(data, list):
        for item in reversed(data):
            if not isinstance(item, dict):
                continue
            energy = str(item.get("energy") or item.get("channel") or "")
            if "0.1-0.8" in energy or "long" in energy.lower() or "1-8" in energy:
                return as_float(item.get("flux"), 1e-8)
        for item in reversed(data):
            if isinstance(item, dict) and "flux" in item:
                return as_float(item.get("flux"), 1e-8)
    return 1e-8


def latest_solar_wind_speed() -> float:
    rec = newest_record(fetch_json(NOAA_RTSW_WIND_1M))
    for key in ("speed", "bulk_speed", "proton_speed"):
        if key in rec:
            return as_float(rec[key], 400.0)
    return 400.0


def latest_bz() -> float:
    rec = newest_record(fetch_json(NOAA_RTSW_MAG_1M))
    for key in ("bz_gsm", "bz", "bz_gse"):
        if key in rec:
            return as_float(rec[key], 0.0)
    return 0.0


def latest_kp() -> float:
    rec = newest_record(fetch_json(NOAA_KP))
    for key in ("kp_index", "Kp", "kp"):
        if key in rec:
            return as_float(rec[key], 0.0)
    return 0.0


def flare_norm_from_xray(xray_flux: float) -> float:
    # Approximate normalized flare drive. C-class ~1e-6, M-class ~1e-5, X-class >=1e-4.
    if xray_flux <= 0:
        return 0.0
    return max(0.0, min(1.0, (math.log10(xray_flux) + 8.0) / 4.0))


def fetch_space_weather() -> tuple[float, float, float, float, float]:
    xray = latest_xray_flux()
    wind = latest_solar_wind_speed()
    bz = latest_bz()
    kp = latest_kp()
    flare = flare_norm_from_xray(xray)
    return xray, wind, bz, kp, flare


def simulated_space_weather(t: float) -> tuple[float, float, float, float, float]:
    xray = 1e-8 * (1.0 + 18.0 * max(0.0, math.sin(t * 0.017)) ** 6)
    wind = 390.0 + 95.0 * math.sin(t * 0.011) + 45.0 * math.sin(t * 0.037)
    bz = 8.0 * math.sin(t * 0.023)
    kp = max(0.0, min(6.0, 2.0 + 1.5 * math.sin(t * 0.009) + 0.8 * math.sin(t * 0.041)))
    flare = flare_norm_from_xray(xray)
    return xray, wind, bz, kp, flare


def format_packet(values: tuple[float, float, float, float, float]) -> str:
    xray, wind, bz, kp, flare = values
    return f"SOLAR:xray={xray:.9g},wind={wind:.3f},bz={bz:.3f},kp={kp:.3f},flare={flare:.4f}"


def main() -> None:
    parser = argparse.ArgumentParser(description="Send solar weather data to RDFT Processing over UDP.")
    parser.add_argument("--host", default="127.0.0.1", help="Processing host")
    parser.add_argument("--port", type=int, default=5060, help="Processing UDP port")
    parser.add_argument("--interval", type=float, default=120.0, help="Fetch/send interval in seconds")
    parser.add_argument("--simulate", action="store_true", help="Use generated solar-like data instead of internet APIs")
    args = parser.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"RDFT solar bridge sending to {args.host}:{args.port} every {args.interval}s")

    while True:
        try:
            values = simulated_space_weather(time.time()) if args.simulate else fetch_space_weather()
        except Exception as exc:
            print(f"Solar API fetch failed; using simulation fallback: {exc}")
            values = simulated_space_weather(time.time())

        packet = format_packet(values)
        sock.sendto(packet.encode("utf-8"), (args.host, args.port))
        print(packet)
        time.sleep(max(5.0, args.interval))


if __name__ == "__main__":
    main()
