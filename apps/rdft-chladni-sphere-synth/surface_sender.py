#!/usr/bin/env python3
"""
surface_sender.py
=================
Synthetic topology / manifold sender for the Processing orbital panel.

Processing listens on UDP :5056 for packets in this format:

  SURFACE:seq|name|grid|angle|zbytes|depths|curvbytes

and sends simple text controls to UDP :5057:

  SURFACE_TOGGLE
  SURFACE_MODE_NEXT

This Mac migration version recreates the missing Raspberry Pi sender with
portable math-only surfaces, fractal topology modes, and optional real DEM
terrain sampling. It uses no hardware and no non-stdlib packages.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import select
import socket
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import urlopen


SurfaceFn = Callable[[float, float, float], float]
MAX_UDP_PACKET_BYTES = 8192


@dataclass(frozen=True)
class SurfaceMode:
    name: str
    fn: SurfaceFn


@dataclass(frozen=True)
class TerrainPreset:
    name: str
    south: float
    north: float
    west: float
    east: float
    description: str
    vertical_gain: float = 1.0
    contrast_gamma: float = 1.0
    curvature_gain: float = 1.0
    depth_bias: float = 0.0


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def gyroid(x: float, y: float, t: float) -> float:
    z = math.sin(x + t) * math.cos(y - t * 0.33)
    z += math.sin(y + t * 0.71) * math.cos((x + y) * 0.5)
    z += math.sin((x - y) * 0.7 - t * 0.5)
    return z / 3.0


def schwarz_p(x: float, y: float, t: float) -> float:
    return (math.cos(x + t * 0.38) + math.cos(y - t * 0.29) + math.cos((x + y) * 0.55)) / 3.0


def beltrami_saddle(x: float, y: float, t: float) -> float:
    r = math.hypot(x, y)
    theta = math.atan2(y, x)
    return math.sin(2.0 * theta + t) * math.exp(-0.12 * r * r) + 0.25 * math.sin(2.6 * r - t)


def hopf_torus(x: float, y: float, t: float) -> float:
    r = math.hypot(x, y)
    theta = math.atan2(y, x)
    ring = math.cos((r - 2.1) * 3.2)
    braid = math.sin(3.0 * theta + t * 1.3)
    return 0.62 * ring + 0.38 * braid


def petaminx_lattice(x: float, y: float, t: float) -> float:
    a = math.sin(1.8 * x + t)
    b = math.sin(1.8 * (0.309 * x + 0.951 * y) - t * 0.7)
    c = math.sin(1.8 * (-0.809 * x + 0.588 * y) + t * 0.45)
    return (a + b + c) / 3.0


def mandelbrot_field(x: float, y: float, t: float) -> float:
    cx = x / 3.2 - 0.55 + 0.10 * math.sin(t * 0.25)
    cy = y / 3.2 + 0.10 * math.cos(t * 0.21)
    zx = 0.0
    zy = 0.0
    max_iter = 42
    count = max_iter
    for i in range(max_iter):
        zx, zy = zx * zx - zy * zy + cx, 2.0 * zx * zy + cy
        if zx * zx + zy * zy > 8.0:
            count = i
            break
    return count / max_iter


def julia_field(x: float, y: float, t: float) -> float:
    zx = x / 3.0
    zy = y / 3.0
    c_re = -0.72 + 0.08 * math.sin(t * 0.31)
    c_im = 0.22 + 0.08 * math.cos(t * 0.27)
    max_iter = 38
    count = max_iter
    for i in range(max_iter):
        zx, zy = zx * zx - zy * zy + c_re, 2.0 * zx * zy + c_im
        if zx * zx + zy * zy > 8.0:
            count = i
            break
    return count / max_iter


def fractal_ridge(x: float, y: float, t: float) -> float:
    value = 0.0
    amp = 0.55
    freq = 0.65
    for octave in range(5):
        phase = t * (0.18 + octave * 0.07)
        n = math.sin((x + phase) * freq) * math.cos((y - phase * 0.7) * freq)
        n += 0.55 * math.sin((x * 0.73 + y * 1.21 + phase) * freq)
        value += amp * (1.0 - abs(n / 1.55))
        amp *= 0.52
        freq *= 1.92
    return value


MODES = [
    SurfaceMode("gyroid", gyroid),
    SurfaceMode("schwarz_p", schwarz_p),
    SurfaceMode("beltrami_saddle", beltrami_saddle),
    SurfaceMode("hopf_torus", hopf_torus),
    SurfaceMode("petaminx_lattice", petaminx_lattice),
    SurfaceMode("mandelbrot", mandelbrot_field),
    SurfaceMode("julia", julia_field),
    SurfaceMode("fractal_ridge", fractal_ridge),
    SurfaceMode("real_topography", lambda x, y, t: 0.0),
]


TERRAIN_PRESETS = {
    "grand_canyon": TerrainPreset("grand_canyon", 36.04, 36.18, -112.18, -111.94, "Grand Canyon, Arizona", 1.15, 0.86, 1.25, 0.05),
    "mauna_loa": TerrainPreset("mauna_loa", 19.34, 19.62, -155.72, -155.42, "Mauna Loa, Hawaii", 1.05, 0.95, 1.10, 0.02),
    "iceland_rift": TerrainPreset("iceland_rift", 63.83, 64.12, -22.72, -22.18, "Reykjanes/Iceland rift terrain", 2.80, 0.58, 3.25, 0.24),
    "st_helens": TerrainPreset("st_helens", 46.12, 46.30, -122.32, -122.08, "Mount St. Helens, Washington", 1.35, 0.80, 1.65, 0.08),
    "yosemite": TerrainPreset("yosemite", 37.70, 37.86, -119.66, -119.42, "Yosemite Valley, California", 1.25, 0.84, 1.45, 0.06),
}


def cache_dir() -> Path:
    here = Path(__file__).resolve().parent
    path = here / "maps" / "surface_cache"
    path.mkdir(parents=True, exist_ok=True)
    return path


def build_surface(mode: SurfaceMode, grid: int, t: float) -> tuple[list[int], list[int], list[int]]:
    values: list[float] = []
    span = 6.0
    for gy in range(grid):
        y = (gy / max(1, grid - 1) - 0.5) * span
        for gx in range(grid):
            x = (gx / max(1, grid - 1) - 0.5) * span
            values.append(mode.fn(x, y, t))

    vmin = min(values)
    vmax = max(values)
    scale = max(1e-9, vmax - vmin)
    z = [int(round(clamp((v - vmin) / scale) * 255)) for v in values]

    curv: list[int] = []
    depth: list[int] = []
    for gy in range(grid):
        for gx in range(grid):
            i = gy * grid + gx
            left = z[gy * grid + max(0, gx - 1)]
            right = z[gy * grid + min(grid - 1, gx + 1)]
            up = z[max(0, gy - 1) * grid + gx]
            down = z[min(grid - 1, gy + 1) * grid + gx]
            lap = abs((left + right + up + down) - (4 * z[i]))
            slope = abs(right - left) + abs(down - up)
            c = clamp((lap * 1.8 + slope * 0.35) / 255.0)
            curv.append(int(round(c * 255)))
            depth.append(1 + int(clamp(c * 1.12, 0, 0.999) * 7))

    return z, depth, curv


def channels_from_values(values: list[float], grid: int, preset: TerrainPreset | None = None) -> tuple[list[int], list[int], list[int]]:
    preset = preset or TerrainPreset("default", 0, 0, 0, 0, "default")
    vmin = min(values)
    vmax = max(values)
    scale = max(1e-9, vmax - vmin)
    normalized: list[float] = []
    for v in values:
        n = clamp((v - vmin) / scale)
        n = clamp((n - 0.5) * preset.vertical_gain + 0.5)
        n = clamp(n ** max(0.05, preset.contrast_gamma))
        normalized.append(n)
    z = [int(round(n * 255)) for n in normalized]

    curv: list[int] = []
    depth: list[int] = []
    for gy in range(grid):
        for gx in range(grid):
            i = gy * grid + gx
            left = z[gy * grid + max(0, gx - 1)]
            right = z[gy * grid + min(grid - 1, gx + 1)]
            up = z[max(0, gy - 1) * grid + gx]
            down = z[min(grid - 1, gy + 1) * grid + gx]
            lap = abs((left + right + up + down) - (4 * z[i]))
            slope = abs(right - left) + abs(down - up)
            c = clamp(((lap * 1.7 + slope * 0.42) / 255.0) * preset.curvature_gain)
            curv.append(int(round(c * 255)))
            depth.append(1 + int(clamp((c * 0.8) + (z[i] / 255.0) * 0.35 + preset.depth_bias, 0, 0.999) * 7))
    return z, depth, curv


def fallback_terrain_values(grid: int, preset: TerrainPreset) -> list[float]:
    salt = sum(ord(ch) for ch in preset.name) * 0.001
    values: list[float] = []
    for gy in range(grid):
        y = gy / max(1, grid - 1)
        for gx in range(grid):
            x = gx / max(1, grid - 1)
            dx = x - 0.52
            dy = y - 0.48
            ridge = math.exp(-((dx * 2.2 + dy * 0.5) ** 2) * 9.0)
            basin = -0.55 * math.exp(-((dx + 0.2) ** 2 + (dy - 0.1) ** 2) * 18.0)
            folds = 0.32 * math.sin((x * 8.0 + salt) + math.sin(y * 5.0))
            folds += 0.24 * math.cos((y * 10.0 - salt) + x * 2.0)
            values.append(ridge + basin + folds)
    return values


def cache_key(source: str, preset: TerrainPreset, grid: int, demtype: str) -> Path:
    bounds = f"{preset.south:.3f}_{preset.north:.3f}_{preset.west:.3f}_{preset.east:.3f}".replace("-", "m").replace(".", "p")
    return cache_dir() / f"{source}_{demtype}_{preset.name}_{grid}_{bounds}.json"


def load_cached_terrain(source: str, preset: TerrainPreset, grid: int, demtype: str) -> list[float] | None:
    path = cache_key(source, preset, grid, demtype)
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text())
        values = [float(v) for v in data["values"]]
        if len(values) == grid * grid:
            print(f"Loaded cached terrain: {path}", flush=True)
            return values
    except Exception as exc:
        print(f"Terrain cache ignored: {exc}", flush=True)
    return None


def save_cached_terrain(source: str, preset: TerrainPreset, grid: int, demtype: str, values: list[float]) -> None:
    path = cache_key(source, preset, grid, demtype)
    payload = {
        "source": source,
        "demtype": demtype,
        "preset": preset.__dict__,
        "grid": grid,
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "values": values,
    }
    path.write_text(json.dumps(payload, indent=2))
    print(f"Cached terrain: {path}", flush=True)


def fetch_url_json(url: str, timeout: float = 20.0) -> dict:
    with urlopen(url, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_url_text(url: str, timeout: float = 30.0) -> str:
    with urlopen(url, timeout=timeout) as response:
        return response.read().decode("utf-8", errors="replace")


def fetch_opentopodata(preset: TerrainPreset, grid: int, dataset: str, batch_delay: float) -> list[float]:
    # Public endpoint supports point batches; keep batches modest for stability.
    base = f"https://api.opentopodata.org/v1/{dataset}"
    coords: list[tuple[float, float]] = []
    for gy in range(grid):
        lat = preset.north + (preset.south - preset.north) * (gy / max(1, grid - 1))
        for gx in range(grid):
            lon = preset.west + (preset.east - preset.west) * (gx / max(1, grid - 1))
            coords.append((lat, lon))

    values: list[float] = []
    batch_size = 90
    for start in range(0, len(coords), batch_size):
        batch = coords[start : start + batch_size]
        locations = "|".join(f"{lat:.6f},{lon:.6f}" for lat, lon in batch)
        url = base + "?" + urlencode({"locations": locations})
        data = fetch_url_json(url)
        results = data.get("results", [])
        if len(results) != len(batch):
            raise RuntimeError(f"OpenTopoData returned {len(results)} results for {len(batch)} locations")
        for item in results:
            elevation = item.get("elevation")
            values.append(float(elevation) if elevation is not None else 0.0)
        if start + batch_size < len(coords) and batch_delay > 0:
            time.sleep(batch_delay)
    return values


def parse_ascii_grid(text: str, grid: int) -> list[float]:
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    header: dict[str, float] = {}
    body_start = 0
    for idx, line in enumerate(lines[:12]):
        parts = line.split()
        if len(parts) >= 2 and parts[0].lower() in {"ncols", "nrows", "xllcorner", "yllcorner", "cellsize", "nodata_value"}:
            header[parts[0].lower()] = float(parts[1])
            body_start = idx + 1
    ncols = int(header.get("ncols", 0))
    nrows = int(header.get("nrows", 0))
    if ncols <= 0 or nrows <= 0:
        raise RuntimeError("OpenTopography response was not an ASCII grid")
    raw: list[float] = []
    nodata = header.get("nodata_value", -9999.0)
    for line in lines[body_start:]:
        for item in line.split():
            val = float(item)
            raw.append(0.0 if val == nodata else val)
    if len(raw) < ncols * nrows:
        raise RuntimeError("ASCII grid did not contain enough cells")

    values: list[float] = []
    for gy in range(grid):
        sy = int(round((gy / max(1, grid - 1)) * (nrows - 1)))
        for gx in range(grid):
            sx = int(round((gx / max(1, grid - 1)) * (ncols - 1)))
            values.append(raw[sy * ncols + sx])
    return values


def fetch_opentopography(preset: TerrainPreset, grid: int, demtype: str, api_key: str) -> list[float]:
    params = {
        "demtype": demtype,
        "south": f"{preset.south:.6f}",
        "north": f"{preset.north:.6f}",
        "west": f"{preset.west:.6f}",
        "east": f"{preset.east:.6f}",
        "outputFormat": "AAIGrid",
        "API_Key": api_key,
    }
    url = "https://portal.opentopography.org/API/globaldem?" + urlencode(params)
    return parse_ascii_grid(fetch_url_text(url), grid)


def load_terrain(source: str, preset_name: str, grid: int, demtype: str, refresh: bool = False, batch_delay: float = 1.1) -> tuple[list[int], list[int], list[int], str]:
    preset = TERRAIN_PRESETS.get(preset_name, TERRAIN_PRESETS["grand_canyon"])
    cache_source = source
    if not refresh:
        cached = load_cached_terrain(cache_source, preset, grid, demtype)
        if cached is not None:
            z, depth, curv = channels_from_values(cached, grid, preset)
            return z, depth, curv, f"topo_{preset.name}"

    try:
        if source == "opentopography":
            key = os.environ.get("OPENTOPO_API_KEY", "").strip()
            if not key:
                raise RuntimeError("OPENTOPO_API_KEY is not set")
            values = fetch_opentopography(preset, grid, demtype, key)
        elif source == "opentopodata":
            values = fetch_opentopodata(preset, grid, demtype, batch_delay)
        else:
            values = fallback_terrain_values(grid, preset)
            cache_source = "fallback"
        save_cached_terrain(cache_source, preset, grid, demtype, values)
    except (OSError, URLError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"Terrain API unavailable ({exc}); using synthetic fallback for {preset.description}", flush=True)
        values = fallback_terrain_values(grid, preset)
        cache_source = "fallback"
        save_cached_terrain(cache_source, preset, grid, demtype, values)

    z, depth, curv = channels_from_values(values, grid, preset)
    return z, depth, curv, f"topo_{preset.name}"


def format_packet(seq: int, name: str, grid: int, angle: float, z: list[int], depth: list[int], curv: list[int]) -> str:
    zbytes = ",".join(str(v) for v in z)
    depths = ",".join(str(v) for v in depth)
    curvbytes = ",".join(str(v) for v in curv)
    return f"SURFACE:{seq}|{name}|{grid}|{angle:.5f}|{zbytes}|{depths}|{curvbytes}"


def downsample_channel(values: list[int], src_grid: int, dst_grid: int) -> list[int]:
    if dst_grid >= src_grid:
        return values
    out: list[int] = []
    for gy in range(dst_grid):
        sy = int(round((gy / max(1, dst_grid - 1)) * (src_grid - 1)))
        for gx in range(dst_grid):
            sx = int(round((gx / max(1, dst_grid - 1)) * (src_grid - 1)))
            out.append(values[sy * src_grid + sx])
    return out


def format_packet_safe(seq: int, name: str, grid: int, angle: float, z: list[int], depth: list[int], curv: list[int]) -> tuple[str, int]:
    out_grid = grid
    out_z = z
    out_depth = depth
    out_curv = curv
    packet = format_packet(seq, name, out_grid, angle, out_z, out_depth, out_curv)

    while len(packet.encode("utf-8")) > MAX_UDP_PACKET_BYTES and out_grid > 8:
        next_grid = max(8, out_grid - 4)
        out_z = downsample_channel(out_z, out_grid, next_grid)
        out_depth = downsample_channel(out_depth, out_grid, next_grid)
        out_curv = downsample_channel(out_curv, out_grid, next_grid)
        out_grid = next_grid
        packet = format_packet(seq, name, out_grid, angle, out_z, out_depth, out_curv)

    return packet, out_grid


def handle_control(sock: socket.socket, enabled: bool, mode_idx: int, preset_idx: int) -> tuple[bool, int, int]:
    try:
        ready, _, _ = select.select([sock], [], [], 0)
    except Exception:
        return enabled, mode_idx, preset_idx

    for _ in ready:
        try:
            data, _addr = sock.recvfrom(1024)
        except BlockingIOError:
            continue
        command = data.decode("utf-8", errors="ignore").strip().upper()
        if command == "SURFACE_TOGGLE":
            enabled = not enabled
            print(f"SURFACE_TOGGLE -> {'ON' if enabled else 'OFF'}", flush=True)
        elif command == "SURFACE_MODE_NEXT":
            mode_idx = (mode_idx + 1) % len(MODES)
            print(f"SURFACE_MODE_NEXT -> {MODES[mode_idx].name}", flush=True)
        elif command in {"SURFACE_SOURCE_TERRAIN", "SURFACE_TOPO", "SURFACE_TOPOGRAPHY"}:
            mode_idx = [m.name for m in MODES].index("real_topography")
            print("SURFACE_SOURCE_TERRAIN -> real_topography", flush=True)
        elif command in {"SURFACE_NEXT_LOCATION", "SURFACE_LOC_NEXT", "SURFACE_LOCATION_NEXT"}:
            preset_idx = (preset_idx + 1) % len(TERRAIN_PRESETS)
            preset_name = list(TERRAIN_PRESETS)[preset_idx]
            print(f"SURFACE_NEXT_LOCATION -> {preset_name}", flush=True)
    return enabled, mode_idx, preset_idx


def main() -> None:
    sys.argv = [arg.strip().strip("\u2028\u2029") for arg in sys.argv]
    parser = argparse.ArgumentParser(description="Send topology, fractal, or real terrain surfaces to Processing.")
    parser.add_argument("--host", default="127.0.0.1", help="Processing host")
    parser.add_argument("--port", type=int, default=5056, help="Processing surface UDP port")
    parser.add_argument("--control-port", type=int, default=5057, help="Control UDP port")
    parser.add_argument("--grid", type=int, default=32, help="Surface grid resolution")
    parser.add_argument("--fps", type=float, default=12.0, help="Packets per second")
    parser.add_argument("--mode", default="gyroid", choices=[m.name for m in MODES], help="Initial topology mode")
    parser.add_argument("--terrain-source", default=os.environ.get("SURFACE_TERRAIN_SOURCE", "opentopodata"), choices=["opentopodata", "opentopography", "fallback"], help="Real topography provider")
    parser.add_argument("--terrain-preset", default=os.environ.get("SURFACE_TERRAIN_PRESET", "grand_canyon"), choices=list(TERRAIN_PRESETS), help="Initial terrain location")
    parser.add_argument("--terrain-demtype", default=os.environ.get("SURFACE_TERRAIN_DEMTYPE", "srtm30m"), help="OpenTopoData dataset or OpenTopography DEM type")
    parser.add_argument("--terrain-batch-delay", type=float, default=float(os.environ.get("SURFACE_TERRAIN_BATCH_DELAY", "1.1")), help="Delay between OpenTopoData point batches")
    parser.add_argument("--terrain-refresh", action="store_true", help="Refresh cached terrain data on startup")
    args = parser.parse_args()

    grid = max(8, min(96, args.grid))
    interval = 1.0 / max(1.0, args.fps)
    mode_idx = [m.name for m in MODES].index(args.mode)
    preset_names = list(TERRAIN_PRESETS)
    preset_idx = preset_names.index(args.terrain_preset)
    enabled = True
    seq = 0
    terrain_cache: dict[tuple[str, str, int, str], tuple[list[int], list[int], list[int], str]] = {}

    send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    control_sock.bind(("127.0.0.1", args.control_port))
    control_sock.setblocking(False)

    print(
        f"Surface sender -> {args.host}:{args.port}, control :{args.control_port}, "
        f"grid={grid}, fps={args.fps}, mode={MODES[mode_idx].name}, "
        f"terrain={args.terrain_source}/{args.terrain_preset}/{args.terrain_demtype}",
        flush=True,
    )

    while True:
        enabled, mode_idx, preset_idx = handle_control(control_sock, enabled, mode_idx, preset_idx)
        t = time.time()
        mode = MODES[mode_idx]
        if enabled:
            name = mode.name
            if mode.name == "real_topography":
                preset_name = preset_names[preset_idx]
                key = (args.terrain_source, preset_name, grid, args.terrain_demtype)
                if key not in terrain_cache or args.terrain_refresh:
                    terrain_cache[key] = load_terrain(
                        args.terrain_source,
                        preset_name,
                        grid,
                        args.terrain_demtype,
                        refresh=args.terrain_refresh,
                        batch_delay=args.terrain_batch_delay,
                    )
                    args.terrain_refresh = False
                z, depth, curv, name = terrain_cache[key]
            else:
                z, depth, curv = build_surface(mode, grid, t * 0.45)
            angle = (t * 0.25) % (math.pi * 2.0)
            packet, sent_grid = format_packet_safe(seq, name, grid, angle, z, depth, curv)
            send_sock.sendto(packet.encode("utf-8"), (args.host, args.port))
            if seq % int(max(1, args.fps * 4)) == 0:
                print(f"SURFACE seq={seq:06d} mode={name} grid={sent_grid} bytes={len(packet)}", flush=True)
            seq += 1
        time.sleep(interval)


if __name__ == "__main__":
    main()
