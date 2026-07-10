#!/usr/bin/env python3
"""
Surface Foundry Relief Generator

Builds silhouette-cutout bas-relief STLs from a source STL. Optional call-sheet
SVG input is used only for companion STL discovery and view metadata.
"""

from __future__ import annotations

import argparse
import collections
import copy
import json
import math
import os
import re
import struct
import sys
import time
import zlib
from pathlib import Path


DEFAULT_CONFIG = {
    "project_name": "surface_foundry_relief",
    "input": {
        "source_stl": "source/surface_foundry_source.stl",
        "call_sheet_svg": "",
        "use_svg_for_metadata_only": True,
    },
    "output": {
        "directory": "output",
        "basename": "surface_foundry_relief",
        "write_defined_variant": True,
        "write_dramatic_variant": True,
        "write_preview_png": True,
        "write_heightfield_png": True,
        "write_metadata_json": True,
    },
    "view": {
        "azimuth_deg": 45.0,
        "elevation_deg": 35.26438968,
        "rotation_order": "Rx(-elevation) @ Rz(azimuth)",
        "auto_parse_svg_view_label": False,
    },
    "projection": {
        "model_voxel_pitch": 1.0,
        "fill_voxel_volume": True,
        "front_depth_weight": 0.72,
        "thickness_weight": 0.28,
        "smoothing_sigma": 0.7,
        "unsharp_sigma": 1.4,
        "unsharp_amount": 0.55,
    },
    "relief": {
        "xy_span_mm": 118.0,
        "flat_back": True,
        "silhouette_cutout": True,
        "z_voxel_step_mm": 1.0,
        "variants": [
            {
                "name": "defined",
                "base_thickness_mm": 2.0,
                "relief_height_mm": 9.0,
                "gamma": 0.58,
            },
            {
                "name": "dramatic",
                "base_thickness_mm": 2.6,
                "relief_height_mm": 18.0,
                "gamma": 0.72,
                "broad_smoothing_sigma": 3.2,
                "volume_blend": 0.35,
                "broad_blend": 0.47,
                "detail_blend": 0.18,
            },
        ],
    },
    "mesh": {
        "make_watertight": True,
        "center_xy": True,
        "set_bottom_to_z_zero": True,
        "export_units": "millimeters",
    },
}


def require_deps():
    missing = []
    try:
        import numpy as np  # noqa: F401
    except ImportError:
        missing.append("numpy")
    try:
        import trimesh  # noqa: F401
    except ImportError:
        missing.append("trimesh")
    if missing:
        msg = [
            "Missing required Python packages: " + ", ".join(missing),
            "",
            "Install them from this folder with:",
            "  python3 -m pip install -r requirements.txt",
            "",
            "The tool does not convert SVG brightness to STL. It requires the",
            "source STL, or an SVG with a matching *_source.stl beside it.",
        ]
        raise SystemExit("\n".join(msg))
    import numpy as np
    import trimesh

    return np, trimesh


def deep_update(base, patch):
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_update(base[key], value)
        else:
            base[key] = value
    return base


def load_config(path: Path | None):
    cfg = copy.deepcopy(DEFAULT_CONFIG)
    if path and path.exists():
        with path.open("r", encoding="utf-8") as f:
            deep_update(cfg, json.load(f))
    return cfg


def resolve_path(value: str, root: Path) -> Path | None:
    if not value:
        return None
    p = Path(value).expanduser()
    if not p.is_absolute():
        p = root / p
    return p


def companion_stl_from_svg(svg_path: Path) -> Path | None:
    stem = svg_path.stem
    for suffix in ("_surface_silhouette", "_voxel_lattice"):
        if stem.endswith(suffix):
            candidate = svg_path.with_name(stem[: -len(suffix)] + "_source.stl")
            if candidate.exists():
                return candidate
    candidate = svg_path.with_name(stem + "_source.stl")
    if candidate.exists():
        return candidate
    source_candidates = sorted(svg_path.parent.glob("*_source.stl"))
    if len(source_candidates) == 1:
        return source_candidates[0]
    return None


def parse_svg_view(svg_path: Path):
    if not svg_path or not svg_path.exists():
        return None
    try:
        text = svg_path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    matches = re.findall(r"AZ\s+([0-9.]+)\s*/\s*EL\s+([0-9.]+)", text, flags=re.I)
    if not matches:
        return None
    az, el = matches[-1]
    return float(az), float(el)


def rotation_matrix(np, azimuth_deg: float, elevation_deg: float):
    az = math.radians(azimuth_deg)
    el = math.radians(-elevation_deg)
    rz = np.array(
        [
            [math.cos(az), -math.sin(az), 0.0],
            [math.sin(az), math.cos(az), 0.0],
            [0.0, 0.0, 1.0],
        ],
        dtype=float,
    )
    rx = np.array(
        [
            [1.0, 0.0, 0.0],
            [0.0, math.cos(el), -math.sin(el)],
            [0.0, math.sin(el), math.cos(el)],
        ],
        dtype=float,
    )
    return rx @ rz


def load_oriented_mesh(np, trimesh, stl_path: Path, azimuth: float, elevation: float):
    mesh = trimesh.load(str(stl_path), force="mesh")
    if isinstance(mesh, trimesh.Scene):
        mesh = trimesh.util.concatenate(tuple(mesh.geometry.values()))
    if mesh.is_empty:
        raise SystemExit(f"Source STL contains no mesh geometry: {stl_path}")
    mesh.apply_translation(-mesh.bounds.mean(axis=0))
    transform = np.eye(4)
    transform[:3, :3] = rotation_matrix(np, azimuth, elevation)
    mesh.apply_transform(transform)
    mesh.apply_translation(-mesh.bounds.mean(axis=0))
    return mesh


def voxelize_mesh(mesh, pitch: float, fill_volume: bool):
    vox = mesh.voxelized(pitch=pitch)
    if fill_volume:
        filled = vox.fill()
        if filled is not None:
            vox = filled
    mat = vox.matrix.astype(bool)
    if mat.size == 0 or not mat.any():
        raise SystemExit("Voxelization produced an empty volume. Try a smaller voxel pitch.")
    return mat


def crop_projection(np, mat):
    any_xy = mat.any(axis=2)
    rev = mat[:, :, ::-1]
    back = np.argmax(rev, axis=2)
    nz = mat.shape[2]
    front = np.where(any_xy, nz - 1 - back, -1)
    thickness = mat.sum(axis=2)

    ix = np.where(any_xy.any(axis=1))[0]
    iy = np.where(any_xy.any(axis=0))[0]
    if len(ix) == 0 or len(iy) == 0:
        raise SystemExit("Projected volume has no occupied silhouette.")
    xs = slice(ix.min(), ix.max() + 1)
    ys = slice(iy.min(), iy.max() + 1)
    front = front[xs, ys].T
    thickness = thickness[xs, ys].T
    mask = front >= 0
    return front, thickness, mask


def normalize_inside(np, arr, mask):
    values = arr[mask].astype(float)
    if values.size == 0:
        return np.zeros(arr.shape, dtype=float)
    lo = float(values.min())
    hi = float(values.max())
    out = np.zeros(arr.shape, dtype=float)
    if hi <= lo:
        out[mask] = 1.0
    else:
        out[mask] = (arr[mask].astype(float) - lo) / (hi - lo)
    return out


def gaussian_filter_fallback(np, arr, sigma: float):
    if sigma <= 0:
        return arr.copy()
    radius = max(1, int(math.ceil(sigma * 3.0)))
    xs = np.arange(-radius, radius + 1, dtype=float)
    kernel = np.exp(-(xs * xs) / (2.0 * sigma * sigma))
    kernel /= kernel.sum()
    padded = np.pad(arr, ((radius, radius), (0, 0)), mode="edge")
    tmp = np.apply_along_axis(lambda m: np.convolve(m, kernel, mode="valid"), 0, padded)
    padded = np.pad(tmp, ((0, 0), (radius, radius)), mode="edge")
    return np.apply_along_axis(lambda m: np.convolve(m, kernel, mode="valid"), 1, padded)


def gaussian_filter(np, arr, sigma: float):
    try:
        from scipy.ndimage import gaussian_filter as scipy_gaussian_filter

        return scipy_gaussian_filter(arr, sigma=sigma)
    except ImportError:
        return gaussian_filter_fallback(np, arr, sigma)


def build_relief_field(np, front, thickness, mask, projection_cfg):
    front_norm = normalize_inside(np, front, mask)
    thickness_norm = normalize_inside(np, thickness, mask)
    raw = (
        float(projection_cfg["front_depth_weight"]) * front_norm
        + float(projection_cfg["thickness_weight"]) * thickness_norm
    )
    raw[~mask] = 0.0

    sigma = float(projection_cfg["smoothing_sigma"])
    num = gaussian_filter(np, raw * mask.astype(float), sigma)
    den = gaussian_filter(np, mask.astype(float), sigma)
    smoothed = np.divide(num, den, out=np.zeros_like(num), where=den > 1.0e-6)
    smoothed[~mask] = 0.0

    blur = gaussian_filter(np, smoothed, float(projection_cfg["unsharp_sigma"]))
    sharp = smoothed + float(projection_cfg["unsharp_amount"]) * (smoothed - blur)
    sharp = np.clip(sharp, 0.0, None)
    sharp[~mask] = 0.0
    maxv = sharp[mask].max() if mask.any() else 0.0
    if maxv > 0:
        sharp /= maxv
    return sharp


def grid_vertex_heights(np, height, mask):
    rows, cols = height.shape
    verts = np.zeros((rows + 1, cols + 1), dtype=float)
    counts = np.zeros((rows + 1, cols + 1), dtype=float)
    for dy, dx in ((0, 0), (1, 0), (0, 1), (1, 1)):
        verts[dy : dy + rows, dx : dx + cols] += height * mask
        counts[dy : dy + rows, dx : dx + cols] += mask.astype(float)
    return np.divide(verts, counts, out=np.zeros_like(verts), where=counts > 0)


def add_tri(tris, a, b, c):
    tris.append((a, b, c))


def cell_point(row, col, z, rows, cols, xy_scale):
    x = (col - cols * 0.5) * xy_scale
    y = ((rows - row) - rows * 0.5) * xy_scale
    return (x, y, z)


def build_heightfield_triangles(np, height, mask, xy_span_mm: float):
    rows, cols = height.shape
    xy_scale = xy_span_mm / max(rows, cols)
    vh = grid_vertex_heights(np, height, mask)
    tris = []
    for r in range(rows):
        for c in range(cols):
            if not mask[r, c]:
                continue
            p00 = cell_point(r, c, vh[r, c], rows, cols, xy_scale)
            p10 = cell_point(r, c + 1, vh[r, c + 1], rows, cols, xy_scale)
            p11 = cell_point(r + 1, c + 1, vh[r + 1, c + 1], rows, cols, xy_scale)
            p01 = cell_point(r + 1, c, vh[r + 1, c], rows, cols, xy_scale)
            b00 = cell_point(r, c, 0.0, rows, cols, xy_scale)
            b10 = cell_point(r, c + 1, 0.0, rows, cols, xy_scale)
            b11 = cell_point(r + 1, c + 1, 0.0, rows, cols, xy_scale)
            b01 = cell_point(r + 1, c, 0.0, rows, cols, xy_scale)

            add_tri(tris, p00, p10, p11)
            add_tri(tris, p00, p11, p01)
            add_tri(tris, b11, b10, b00)
            add_tri(tris, b01, b11, b00)

            neighbors = [
                (-1, 0, p10, p00, b00, b10),
                (1, 0, p01, p11, b11, b01),
                (0, -1, p00, p01, b01, b00),
                (0, 1, p11, p10, b10, b11),
            ]
            for dr, dc, ta, tb, bb, ba in neighbors:
                rr = r + dr
                cc = c + dc
                if rr < 0 or rr >= rows or cc < 0 or cc >= cols or not mask[rr, cc]:
                    add_tri(tris, ta, tb, bb)
                    add_tri(tris, ta, bb, ba)
    return tris, xy_scale


def normal(a, b, c):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx = uy * vz - uz * vy
    ny = uz * vx - ux * vz
    nz = ux * vy - uy * vx
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length <= 1.0e-12:
        return (0.0, 0.0, 0.0)
    return (nx / length, ny / length, nz / length)


def mesh_audit(tris):
    edge_counts = collections.Counter()
    edge_balance = collections.Counter()
    degenerate = 0

    def key(point):
        return tuple(round(float(value), 6) for value in point)

    for a, b, c in tris:
        if normal(a, b, c) == (0.0, 0.0, 0.0):
            degenerate += 1
            continue
        vertices = (key(a), key(b), key(c))
        for first, second in zip(vertices, vertices[1:] + vertices[:1]):
            edge = tuple(sorted((first, second)))
            edge_counts[edge] += 1
            edge_balance[edge] += 1 if first <= second else -1

    boundary = sum(count == 1 for count in edge_counts.values())
    non_manifold = sum(
        count > 2 or (count == 2 and abs(edge_balance[edge]) == 2)
        for edge, count in edge_counts.items()
    )
    return {
        "watertight": boundary == 0 and non_manifold == 0 and degenerate == 0,
        "boundary_edges": int(boundary),
        "non_manifold_edges": int(non_manifold),
        "degenerate_faces": int(degenerate),
    }


def write_ascii_stl(path: Path, name: str, tris):
    with path.open("w", encoding="utf-8") as f:
        f.write(f"solid {name}\n")
        for a, b, c in tris:
            n = normal(a, b, c)
            f.write(f"  facet normal {n[0]:.7g} {n[1]:.7g} {n[2]:.7g}\n")
            f.write("    outer loop\n")
            for p in (a, b, c):
                f.write(f"      vertex {p[0]:.7g} {p[1]:.7g} {p[2]:.7g}\n")
            f.write("    endloop\n")
            f.write("  endfacet\n")
        f.write(f"endsolid {name}\n")


def png_chunk(kind: bytes, data: bytes):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_rgb_png(path: Path, rgb):
    height, width, _ = rgb.shape
    raw_rows = []
    for y in range(height):
        raw_rows.append(b"\x00" + rgb[y].astype("uint8").tobytes())
    raw = b"".join(raw_rows)
    data = b"\x89PNG\r\n\x1a\n"
    data += png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    data += png_chunk(b"IDAT", zlib.compress(raw, 9))
    data += png_chunk(b"IEND", b"")
    path.write_bytes(data)


def write_heightfield_png(np, path: Path, field, mask):
    img = np.full(field.shape, 255, dtype=np.uint8)
    if mask.any():
        img[mask] = np.clip(field[mask] * 255.0, 0, 255).astype(np.uint8)
    rgb = np.dstack([img, img, img])
    write_rgb_png(path, rgb)


def write_preview_png(np, path: Path, field, mask):
    gy, gx = np.gradient(field)
    shade = np.clip(0.72 - gx * 0.55 - gy * 0.35 + field * 0.30, 0, 1)
    base = np.full(field.shape, 255, dtype=np.uint8)
    tone = np.clip(245 - shade * 205, 0, 255).astype(np.uint8)
    base[mask] = tone[mask]
    rgb = np.dstack([base, base, base])
    edge = mask ^ erode_mask(np, mask)
    rgb[edge] = [0, 0, 0]
    write_rgb_png(path, rgb)


def erode_mask(np, mask):
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    out = mask.copy()
    for dy, dx in ((0, 1), (1, 0), (1, 2), (2, 1)):
        out &= padded[dy : dy + mask.shape[0], dx : dx + mask.shape[1]]
    return out


def interior_depth_field(np, mask, max_layers=64):
    layer = mask.copy()
    depth = np.zeros(mask.shape, dtype=float)
    deepest = 0.0
    for level in range(1, max_layers + 1):
        if not layer.any():
            break
        depth[layer] = float(level)
        deepest = float(level)
        layer = erode_mask(np, layer)
    if deepest > 0:
        depth[mask] /= deepest
    return depth


def masked_gaussian(np, field, mask, sigma):
    weights = mask.astype(float)
    numerator = gaussian_filter(np, field * weights, sigma)
    denominator = gaussian_filter(np, weights, sigma)
    out = np.divide(numerator, denominator, out=np.zeros_like(numerator), where=denominator > 1.0e-6)
    out[~mask] = 0.0
    return out


def variant_field(np, field, mask, variant):
    if variant.get("name") != "dramatic":
        return field
    broad = masked_gaussian(np, field, mask, float(variant.get("broad_smoothing_sigma", 3.2)))
    dome = interior_depth_field(np, mask)
    detail_blend = float(variant.get("detail_blend", 0.18))
    broad_blend = float(variant.get("broad_blend", 0.47))
    volume_blend = float(variant.get("volume_blend", 0.35))
    total = max(1.0e-6, detail_blend + broad_blend + volume_blend)
    shaped = (detail_blend * field + broad_blend * broad + volume_blend * dome) / total
    shaped[~mask] = 0.0
    max_value = float(shaped[mask].max()) if mask.any() else 0.0
    min_value = float(shaped[mask].min()) if mask.any() else 0.0
    if max_value > min_value:
        shaped[mask] = (shaped[mask] - min_value) / (max_value - min_value)
    return shaped


def variant_height(np, field, mask, variant):
    base = float(variant["base_thickness_mm"])
    relief = float(variant["relief_height_mm"])
    gamma = float(variant["gamma"])
    shaped = variant_field(np, field, mask, variant)
    height = np.zeros(field.shape, dtype=float)
    height[mask] = base + relief * np.power(np.clip(shaped[mask], 0, 1), gamma)
    return height


def write_metadata(path: Path, metadata):
    path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")


def build_arg_parser():
    parser = argparse.ArgumentParser(description="Generate silhouette-cutout bas-relief STL variants from a source STL.")
    parser.add_argument("--stl", help="Source STL. If omitted, --svg can auto-discover a matching *_source.stl.")
    parser.add_argument("--svg", help="Optional call-sheet SVG, used only for metadata/view discovery.")
    parser.add_argument("--config", default="relief_config.json", help="JSON config path.")
    parser.add_argument("--out", help="Output directory override.")
    parser.add_argument("--azimuth", type=float, help="View azimuth degrees.")
    parser.add_argument("--elevation", type=float, help="View elevation degrees.")
    parser.add_argument("--span-mm", type=float, help="Output XY span in millimeters.")
    parser.add_argument("--voxel-pitch", type=float, help="Source voxel pitch.")
    parser.add_argument("--variant", choices=["defined", "dramatic", "all"], default="all")
    return parser


def main():
    args = build_arg_parser().parse_args()
    np, trimesh = require_deps()
    config_path = Path(args.config).expanduser()
    config_root = config_path.parent if config_path.exists() else Path.cwd()
    cfg = load_config(config_path if config_path.exists() else None)

    svg_path = Path(args.svg).expanduser() if args.svg else resolve_path(cfg["input"].get("call_sheet_svg", ""), config_root)
    stl_path = Path(args.stl).expanduser() if args.stl else resolve_path(cfg["input"].get("source_stl", ""), config_root)
    if (not stl_path or not stl_path.exists()) and svg_path:
        stl_path = companion_stl_from_svg(svg_path)
    if not stl_path or not stl_path.exists():
        raise SystemExit("No source STL found. Pass --stl, or pass --svg beside a matching *_source.stl.")

    out_dir = Path(args.out).expanduser() if args.out else resolve_path(cfg["output"]["directory"], config_root)
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.azimuth is not None:
        cfg["view"]["azimuth_deg"] = args.azimuth
    if args.elevation is not None:
        cfg["view"]["elevation_deg"] = args.elevation
    if args.span_mm is not None:
        cfg["relief"]["xy_span_mm"] = args.span_mm
    if args.voxel_pitch is not None:
        cfg["projection"]["model_voxel_pitch"] = args.voxel_pitch
    if cfg["view"].get("auto_parse_svg_view_label") and svg_path:
        parsed = parse_svg_view(svg_path)
        if parsed:
            cfg["view"]["azimuth_deg"], cfg["view"]["elevation_deg"] = parsed

    az = float(cfg["view"]["azimuth_deg"])
    el = float(cfg["view"]["elevation_deg"])
    pitch = float(cfg["projection"]["model_voxel_pitch"])
    mesh = load_oriented_mesh(np, trimesh, stl_path, az, el)
    mat = voxelize_mesh(mesh, pitch, bool(cfg["projection"].get("fill_voxel_volume", True)))
    front, thickness, mask = crop_projection(np, mat)
    field = build_relief_field(np, front, thickness, mask, cfg["projection"])

    basename = cfg["output"]["basename"]
    variants = cfg["relief"]["variants"]
    if args.variant != "all":
        variants = [v for v in variants if v["name"] == args.variant]
    written = []
    variant_summaries = []
    for variant in variants:
        name = variant["name"]
        enabled = cfg["output"].get(f"write_{name}_variant", True)
        if not enabled:
            continue
        height = variant_height(np, field, mask, variant)
        tris, xy_scale = build_heightfield_triangles(np, height, mask, float(cfg["relief"]["xy_span_mm"]))
        audit = mesh_audit(tris)
        if cfg["mesh"].get("make_watertight", True) and not audit["watertight"]:
            raise SystemExit(
                f"Refusing to write non-watertight {name} relief: "
                f"boundary={audit['boundary_edges']} non_manifold={audit['non_manifold_edges']} "
                f"degenerate={audit['degenerate_faces']}"
            )
        stl_out = out_dir / f"{basename}_cutout_{name}.stl"
        write_ascii_stl(stl_out, f"{basename}_{name}", tris)
        written.append(str(stl_out))
        variant_summaries.append(
            {
                "name": name,
                "path": str(stl_out),
                "triangles": len(tris),
                "xy_cell_mm": xy_scale,
                "profile": "detail-preserving" if name == "defined" else "volumetric-contour",
                "min_height_mm": float(height[mask].min()) if mask.any() else 0.0,
                "mean_height_mm": float(height[mask].mean()) if mask.any() else 0.0,
                "max_height_mm": float(height.max()) if height.size else 0.0,
                "mesh_audit": audit,
            }
        )

    if cfg["output"].get("write_heightfield_png", True):
        write_heightfield_png(np, out_dir / f"{basename}_heightfield.png", field, mask)
    if cfg["output"].get("write_preview_png", True):
        write_preview_png(np, out_dir / f"{basename}_preview.png", field, mask)

    metadata = {
        "program": "Surface Foundry Relief Generator",
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "source_stl": str(stl_path),
        "call_sheet_svg": str(svg_path) if svg_path else "",
        "svg_used_as_geometry": False,
        "view": cfg["view"],
        "projection": cfg["projection"],
        "relief": cfg["relief"],
        "source_voxel_shape": list(map(int, mat.shape)),
        "relief_field_shape": list(map(int, field.shape)),
        "occupied_pixels": int(mask.sum()),
        "source_mesh_watertight": bool(mesh.is_watertight),
        "source_mesh_winding_consistent": bool(mesh.is_winding_consistent),
        "variants": variant_summaries,
    }
    if cfg["output"].get("write_metadata_json", True):
        write_metadata(out_dir / f"{basename}_metadata.json", metadata)

    print("Surface Foundry relief complete")
    print(f"  source STL: {stl_path}")
    if svg_path:
        print(f"  SVG metadata/reference: {svg_path}")
    for path in written:
        print(f"  wrote: {path}")


if __name__ == "__main__":
    main()
