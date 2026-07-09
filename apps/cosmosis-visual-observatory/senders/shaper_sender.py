#!/usr/bin/env python3
"""
Cosmosis Visual Observatory Shaper Sender
-----------------------------------------
Fetches public NOAA space-weather and tide/ocean streams, normalizes them into
the Observatory's shaper schema, and atomically writes data/shaper_streams.json.

No UDP, no SuperCollider, no external dependencies.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

NOAA_XRAY_6H = "https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json"
NOAA_RTSW_WIND_1M = "https://services.swpc.noaa.gov/json/rtsw/rtsw_wind_1m.json"
NOAA_RTSW_MAG_1M = "https://services.swpc.noaa.gov/json/rtsw/rtsw_mag_1m.json"
NOAA_KP = "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json"
NOAA_COOPS = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
DEFAULT_OUT = Path(__file__).resolve().parents[1] / "data" / "shaper_streams.json"

ocean_memory = 0.0


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def fetch_json_url(url: str, timeout: float = 10.0) -> Any:
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_json_params(url: str, params: dict[str, str], timeout: float = 10.0) -> Any:
    return fetch_json_url(url + "?" + urllib.parse.urlencode(params), timeout)


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except Exception:
        return default


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def norm_linear(value: float, lo: float, hi: float) -> float:
    return clamp((value - lo) / max(0.0001, hi - lo))


def newest_record(data: Any) -> dict[str, Any]:
    if isinstance(data, dict):
        for key in ("data", "records", "items"):
            if isinstance(data.get(key), list) and data[key]:
                return newest_record(data[key])
        return data
    if not isinstance(data, list) or not data:
        return {}
    if isinstance(data[0], list) and all(isinstance(k, str) for k in data[0]):
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
    data = fetch_json_url(NOAA_XRAY_6H)
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
    rec = newest_record(fetch_json_url(NOAA_RTSW_WIND_1M))
    for key in ("speed", "bulk_speed", "proton_speed"):
        if key in rec:
            return as_float(rec[key], 400.0)
    return 400.0


def latest_bz() -> float:
    rec = newest_record(fetch_json_url(NOAA_RTSW_MAG_1M))
    for key in ("bz_gsm", "bz", "bz_gse"):
        if key in rec:
            return as_float(rec[key], 0.0)
    return 0.0


def latest_kp() -> float:
    rec = newest_record(fetch_json_url(NOAA_KP))
    for key in ("kp_index", "Kp", "kp"):
        if key in rec:
            return as_float(rec[key], 0.0)
    return 0.0


def flare_norm_from_xray(xray_flux: float) -> float:
    if xray_flux <= 0:
        return 0.0
    return clamp((math.log10(xray_flux) + 8.0) / 4.0)


def coops_data(station: str, product: str, hours: int = 6) -> list[dict[str, Any]]:
    now = utc_now()
    begin = now - dt.timedelta(hours=hours)
    params = {
        "product": product,
        "application": "COSMOSIS_VISUAL_OBSERVATORY",
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
    data = fetch_json_params(NOAA_COOPS, params)
    rows = data.get("data") if isinstance(data, dict) else None
    return rows if isinstance(rows, list) else []


def normalize_in_series(values: list[float], value: float) -> float:
    if not values:
        return 0.5
    lo = min(values)
    hi = max(values)
    return clamp((value - lo) / max(0.001, hi - lo))


def fetch_ocean(station: str) -> dict[str, float]:
    water = coops_data(station, "water_level", hours=6)
    if len(water) < 2:
        raise RuntimeError("not enough NOAA CO-OPS water_level data")
    levels = [as_float(row.get("v"), 0.0) for row in water if "v" in row]
    if len(levels) < 2:
        raise RuntimeError("water_level rows did not contain numeric values")
    tide = levels[-1]
    tide_range = max(0.001, max(levels) - min(levels))
    phase = normalize_in_series(levels, tide)
    prev = levels[max(0, len(levels) - 6)]
    mid = levels[max(0, len(levels) - 3)]
    slope = abs(tide - prev)
    current = clamp(slope / max(0.04, tide_range * 0.30))
    velocity = clamp(abs(tide - mid) / max(0.02, tide_range * 0.20))
    accel = clamp(abs(tide - 2.0 * mid + prev) / max(0.01, tide_range * 0.08))
    energy = clamp(current * 0.35 + velocity * 0.40 + accel * 0.25)

    temp_c = 12.0
    temp_rows = coops_data(station, "water_temperature", hours=6)
    vals = [as_float(row.get("v"), temp_c) for row in temp_rows if "v" in row] if temp_rows else []
    if vals:
        temp_c = vals[-1]

    return {
        "tide_m": tide,
        "water_temp_c": temp_c,
        "tide_range_m": tide_range,
        "ocean_current": current,
        "tide_phase": phase,
        "ocean_velocity": velocity,
        "ocean_accel": accel,
        "ocean_energy": energy,
    }


def simulated_raw(t: float) -> dict[str, float]:
    phase = 0.5 + 0.5 * math.sin(t * 0.0014)
    current = abs(math.cos(t * 0.0014))
    xray = 1e-8 * (1.0 + 18.0 * max(0.0, math.sin(t * 0.017)) ** 6)
    wind = 390.0 + 95.0 * math.sin(t * 0.011) + 45.0 * math.sin(t * 0.037)
    bz = 8.0 * math.sin(t * 0.023)
    kp = clamp(2.0 + 1.5 * math.sin(t * 0.009) + 0.8 * math.sin(t * 0.041), 0.0, 9.0)
    return {
        "xray_w_m2": xray,
        "wind_km_s": wind,
        "bz_nt": bz,
        "kp": kp,
        "tide_m": 0.8 * math.sin(t * 0.0014),
        "water_temp_c": 13.0 + 4.0 * math.sin(t * 0.00018),
        "tide_range_m": 1.6,
        "ocean_current": current,
        "tide_phase": phase,
        "ocean_velocity": current,
        "ocean_accel": abs(math.sin(t * 0.0028)) * 0.55,
        "ocean_energy": clamp(current * 0.75 + abs(math.sin(t * 0.0028)) * 0.25),
    }


def live_raw(station: str) -> tuple[dict[str, float], dict[str, bool]]:
    status = {"solar_live": True, "ocean_live": True}
    raw: dict[str, float] = {}
    try:
        raw["xray_w_m2"] = latest_xray_flux()
        raw["wind_km_s"] = latest_solar_wind_speed()
        raw["bz_nt"] = latest_bz()
        raw["kp"] = latest_kp()
    except Exception:
        status["solar_live"] = False
        raw.update({k: v for k, v in simulated_raw(time.time()).items() if k in ("xray_w_m2", "wind_km_s", "bz_nt", "kp")})
    try:
        raw.update(fetch_ocean(station))
    except Exception:
        status["ocean_live"] = False
        raw.update({k: v for k, v in simulated_raw(time.time()).items() if k not in ("xray_w_m2", "wind_km_s", "bz_nt", "kp")})
    return raw, status


def build_frame(raw: dict[str, float], status: dict[str, bool], mix: float, source: str, station: str) -> dict[str, Any]:
    global ocean_memory
    ocean_memory = ocean_memory * 0.96 + raw["ocean_energy"] * 0.04
    sidereal = math.sin(time.time() / 86164.0905 * math.tau)
    torsion_proxy = clamp(
        0.50
        + 0.25 * math.tanh(-raw["bz_nt"] / 8.0)
        + 0.20 * norm_linear(raw["kp"], 0.0, 9.0)
        + 0.05 * sidereal
    )
    return {
        "schema": "cosmosis_visual_observatory.shaper.v1",
        "source": source,
        "updated_utc": utc_now().isoformat().replace("+00:00", "Z"),
        "station": station,
        "mix": clamp(mix),
        "solar_wind": norm_linear(raw["wind_km_s"], 250.0, 850.0),
        "xray_flux": flare_norm_from_xray(raw["xray_w_m2"]),
        "ocean_current": clamp(raw["ocean_current"]),
        "tide": clamp(raw["tide_phase"]),
        "galactic_torsion": torsion_proxy,
        "raw": {
            "xray_w_m2": raw["xray_w_m2"],
            "wind_km_s": raw["wind_km_s"],
            "bz_nt": raw["bz_nt"],
            "kp": raw["kp"],
            "tide_m": raw["tide_m"],
            "water_temp_c": raw["water_temp_c"],
            "tide_range_m": raw["tide_range_m"],
            "ocean_velocity": raw["ocean_velocity"],
            "ocean_accel": raw["ocean_accel"],
            "ocean_energy": raw["ocean_energy"],
            "ocean_memory": ocean_memory,
            "torsion_proxy_note": "derived from Bz, Kp, and sidereal phase; not a direct torsion measurement",
        },
        "status": status,
    }


def atomic_write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def read_frame(simulate: bool, station: str, mix: float) -> dict[str, Any]:
    if simulate:
        raw = simulated_raw(time.time())
        status = {"solar_live": False, "ocean_live": False}
        return build_frame(raw, status, mix, "simulation", station)
    raw, status = live_raw(station)
    source = "live_noaa_swpc_coops" if status["solar_live"] or status["ocean_live"] else "fallback_simulation"
    return build_frame(raw, status, mix, source, station)


def main() -> None:
    parser = argparse.ArgumentParser(description="Write live Shaper API data for Cosmosis Visual Observatory.")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT, help="Output JSON file")
    parser.add_argument("--station", default="9414290", help="NOAA CO-OPS station, default San Francisco")
    parser.add_argument("--interval", type=float, default=180.0, help="Fetch/write interval in seconds")
    parser.add_argument("--mix", type=float, default=0.62, help="Default shaper influence mix")
    parser.add_argument("--simulate", action="store_true", help="Use generated data instead of public APIs")
    parser.add_argument("--once", action="store_true", help="Write one frame and exit")
    args = parser.parse_args()

    print(f"Shaper sender writing {args.out} station={args.station} interval={args.interval}s")
    while True:
        frame = read_frame(args.simulate, args.station, args.mix)
        atomic_write_json(args.out, frame)
        print(
            f"{frame['updated_utc']} source={frame['source']} "
            f"solar={frame['solar_wind']:.3f} xray={frame['xray_flux']:.3f} "
            f"ocean={frame['ocean_current']:.3f} tide={frame['tide']:.3f} "
            f"torsion={frame['galactic_torsion']:.3f}"
        )
        if args.once:
            break
        time.sleep(max(30.0, args.interval))


if __name__ == "__main__":
    main()
