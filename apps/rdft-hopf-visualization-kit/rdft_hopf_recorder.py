#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import time
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).with_name(".matplotlib")))
Path(os.environ["MPLCONFIGDIR"]).mkdir(parents=True, exist_ok=True)

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, PillowWriter
import numpy as np
import pandas as pd

from rdft_hopf_dashboard import berry_page, dimensional_page


VIEW_KEYS = ["base", "phase", "pca", "winding"]
METRIC_MODES = ["time", "velocity", "holonomy", "curvature"]


def clean_numeric_series(df: pd.DataFrame, col: str) -> np.ndarray:
    values = pd.to_numeric(df[col], errors="coerce").replace([np.inf, -np.inf], np.nan)
    if values.isna().all():
        return np.zeros(len(df), dtype=np.float32)
    return values.fillna(values.median()).to_numpy(dtype=np.float32)


def first_present(df: pd.DataFrame, candidates: Iterable[str]) -> Optional[str]:
    for col in candidates:
        if col in df.columns:
            return col
    return None


def first_numeric(df: pd.DataFrame, candidates: Iterable[str]) -> Optional[np.ndarray]:
    col = first_present(df, candidates)
    if col is None:
        return None
    return clean_numeric_series(df, col)


def sample_indices(length: int, max_points: int) -> np.ndarray:
    if length <= max_points:
        return np.arange(length, dtype=int)
    return np.linspace(0, length - 1, max_points).astype(int)


def normalize_positions(points: np.ndarray, scale: float = 8.0) -> np.ndarray:
    pts = np.asarray(points, dtype=np.float32)
    pts = np.nan_to_num(pts, nan=0.0, posinf=0.0, neginf=0.0)
    pts = pts - pts.mean(axis=0, keepdims=True)
    span = float(np.max(np.ptp(pts, axis=0)))
    if span < 1e-9:
        span = 1.0
    return (pts / span * scale).astype(np.float32)


def clean_numeric_frame(df: pd.DataFrame, cols: List[str]) -> pd.DataFrame:
    numeric = df[cols].apply(pd.to_numeric, errors="coerce")
    numeric = numeric.replace([np.inf, -np.inf], np.nan)
    return numeric.fillna(numeric.median(numeric_only=True))


def robust_normalize(values: np.ndarray) -> np.ndarray:
    vals = np.asarray(values, dtype=np.float32)
    vals = np.nan_to_num(vals, nan=0.0, posinf=0.0, neginf=0.0)
    if len(vals) == 0:
        return vals
    lo, hi = np.percentile(vals, [2, 98])
    if abs(float(hi - lo)) < 1e-9:
        lo, hi = float(vals.min()), float(vals.max())
    if abs(float(hi - lo)) < 1e-9:
        return np.zeros_like(vals)
    return np.clip((vals - lo) / (hi - lo), 0.0, 1.0)


def metric_values(df: pd.DataFrame, sample_idx: np.ndarray, positions: np.ndarray) -> Dict[str, np.ndarray]:
    metrics: Dict[str, np.ndarray] = {"time": np.linspace(0.0, 1.0, len(sample_idx), dtype=np.float32)}

    velocity = first_numeric(df, ["orbital_speed", "cart_velocity", "ocean_velocity", "root_freq_slew_rate"])
    if velocity is None:
        velocity = np.linalg.norm(np.diff(positions, axis=0, prepend=positions[:1]), axis=1)
        metrics["velocity"] = velocity.astype(np.float32)
    else:
        metrics["velocity"] = velocity[sample_idx].astype(np.float32)

    holonomy = first_numeric(df, ["berry_phase_principal", "berry_phase", "berry_winding_turns"])
    metrics["holonomy"] = (holonomy[sample_idx] if holonomy is not None else np.zeros(len(sample_idx))).astype(np.float32)

    curvature = first_numeric(df, ["berry_curvature_density", "orient_area", "hopf_fiber_delta"])
    metrics["curvature"] = (curvature[sample_idx] if curvature is not None else np.zeros(len(sample_idx))).astype(np.float32)
    return metrics


def metric_colors(metrics: Dict[str, np.ndarray], mode: str) -> np.ndarray:
    if mode == "holonomy":
        phase = np.mod(metrics["holonomy"], 2.0 * np.pi) / (2.0 * np.pi)
        return np.column_stack(
            [
                0.55 + 0.45 * np.cos(2.0 * np.pi * phase),
                0.55 + 0.45 * np.cos(2.0 * np.pi * (phase - 0.34)),
                0.55 + 0.45 * np.cos(2.0 * np.pi * (phase - 0.67)),
            ]
        )
    if mode == "curvature":
        vals = metrics["curvature"]
        span = float(np.percentile(np.abs(vals), 98))
        norm = np.full(len(vals), 0.5, dtype=np.float32) if span < 1e-9 else np.clip((vals / span + 1.0) * 0.5, 0, 1)
        return plt.get_cmap("coolwarm")(norm)[:, :3]
    cmap = "viridis" if mode == "time" else "plasma"
    return plt.get_cmap(cmap)(robust_normalize(metrics[mode]))[:, :3]


def build_base(df: pd.DataFrame, max_points: int) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    cols = ["hopf_base_x", "hopf_base_y", "hopf_base_z"]
    if not all(c in df.columns for c in cols):
        cols = ["cart_x", "cart_y", "cart_z"]
    pts_all = normalize_positions(clean_numeric_frame(df, cols).to_numpy(dtype=np.float32))
    idx = sample_indices(len(df), max_points)
    pts = pts_all[idx]
    return pts, metric_values(df, idx, pts)


def build_phase(df: pd.DataFrame, max_points: int) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    phase1 = clean_numeric_series(df, first_present(df, ["hopf_fiber_phase", "berry_phase_principal", "berry_phase"]) or "berry_phase")
    phase2 = clean_numeric_series(df, first_present(df, ["hopf_thread_phase", "floquet_phase"]) or "floquet_phase")
    coherence = clean_numeric_series(df, first_present(df, ["found_coherence", "landauer_coherence"]) or "found_coherence")
    lock = clean_numeric_series(df, first_present(df, ["floquet_lock_gated", "floquet_lock_raw", "floquet_g_eff"]) or "floquet_g_eff")
    link = clean_numeric_series(
        df,
        first_present(df, ["hopf_link_proxy", "hopf_fieldorient_proxy", "fourth_sphere_gamma", "fourth_sphere_area"])
        or "berry_curvature_density",
    )

    mix = 0.45 * coherence + 0.35 * lock + 0.20 * link
    mix_norm = (mix - mix.min()) / (mix.max() - mix.min() + 1e-12)
    eta = (np.pi / 2.0) * mix_norm
    z1 = np.cos(eta) * np.exp(1j * phase1)
    z2 = np.sin(eta) * np.exp(1j * phase2)
    pts_all = normalize_positions(np.column_stack([2.0 * np.real(z1 * np.conj(z2)), 2.0 * np.imag(z1 * np.conj(z2)), np.abs(z1) ** 2 - np.abs(z2) ** 2]))
    idx = sample_indices(len(df), max_points)
    pts = pts_all[idx]
    return pts, metric_values(df, idx, pts)


def build_pca(df: pd.DataFrame, max_points: int) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    features = [
        "alpha", "depth", "orbital_phi", "orbital_speed", "orbital_radius", "entropy",
        "fractal_dim", "lyapunov", "berry_phase_principal", "berry_curvature_density",
        "floquet_phase", "floquet_quasienergy", "floquet_coupling_env", "floquet_lock_gated",
        "found_coherence", "found_coupling", "cart_x", "cart_y", "cart_z", "cart_stability",
        "orbit_resonance", "beltrami_lambda", "beltrami_alignment", "landauer_coherence",
        "harmonic_pressure_smoothed", "hopf_fiber_phase", "hopf_thread_phase",
        "hopf_link_proxy", "hopf_fieldorient_proxy", "hopf_activity_proxy",
        "fourth_sphere_gamma", "fourth_sphere_gamma_pi", "fourth_sphere_area",
        "fourth_sphere_seals", "fourth_sphere_mean_pi", "fourth_sphere_std_pi",
    ]
    available = [c for c in features if c in df.columns]
    data = clean_numeric_frame(df, available).to_numpy(dtype=np.float64)
    data = (data - data.mean(axis=0)) / (data.std(axis=0) + 1e-12)
    u, s, _ = np.linalg.svd(data, full_matrices=False)
    pts_all = normalize_positions((u[:, :3] * s[:3]).astype(np.float32))
    idx = sample_indices(len(df), max_points)
    pts = pts_all[idx]
    return pts, metric_values(df, idx, pts)


def build_winding(df: pd.DataFrame, max_points: int) -> Tuple[np.ndarray, Dict[str, np.ndarray]]:
    cols = ["hopf_fiber_winding", "hopf_thread_winding", "hopf_activity_proxy"]
    if not all(c in df.columns for c in cols):
        cols = ["berry_winding_turns", "hopf_fiber_delta", "found_coherence"]
    pts_all = normalize_positions(clean_numeric_frame(df, cols).to_numpy(dtype=np.float32))
    idx = sample_indices(len(df), max_points)
    pts = pts_all[idx]
    return pts, metric_values(df, idx, pts)


BUILDERS = {
    "base": build_base,
    "phase": build_phase,
    "pca": build_pca,
    "winding": build_winding,
}


def set_equal_axes(ax, pts: np.ndarray) -> None:
    mins = pts.min(axis=0)
    maxs = pts.max(axis=0)
    center = (mins + maxs) / 2.0
    radius = max(float(np.max(maxs - mins)) / 2.0, 1.0)
    ax.set_xlim(center[0] - radius, center[0] + radius)
    ax.set_ylim(center[1] - radius, center[1] + radius)
    ax.set_zlim(center[2] - radius, center[2] + radius)


def render_gif(view_key: str, pts: np.ndarray, metrics: Dict[str, np.ndarray], out: Path, frames: int, fps: int) -> None:
    frame_indices = np.linspace(0, len(pts) - 1, frames).astype(int)
    fig = plt.figure(figsize=(5.2, 5.2), facecolor="#05060c")
    ax = fig.add_subplot(111, projection="3d", facecolor="#05060c")
    fig.subplots_adjust(left=0, right=1, top=0.94, bottom=0.02)

    initial_colors = metric_colors(metrics, METRIC_MODES[0])
    ax.plot(pts[:, 0], pts[:, 1], pts[:, 2], color="#6f7892", alpha=0.28, linewidth=0.7)
    scatter = ax.scatter(pts[:, 0], pts[:, 1], pts[:, 2], c=initial_colors, s=7, alpha=0.78, depthshade=False)
    marker = ax.scatter([pts[0, 0]], [pts[0, 1]], [pts[0, 2]], c="#ffffff", s=56, edgecolors="#00e5ff", depthshade=False)
    trail, = ax.plot([], [], [], color="#ffffff", linewidth=2.5, alpha=0.9)

    set_equal_axes(ax, pts)
    ax.grid(True, alpha=0.18)
    ax.tick_params(colors="#9fb3c8", labelsize=6)
    for axis in (ax.xaxis, ax.yaxis, ax.zaxis):
        axis.label.set_color("#d6e7ff")
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_zlabel("z")

    def update(frame: int):
        metric = METRIC_MODES[(frame * len(METRIC_MODES)) // max(frames, 1)]
        i = int(frame_indices[frame])
        colors = metric_colors(metrics, metric)
        scatter.set_color(colors)
        marker._offsets3d = ([pts[i, 0]], [pts[i, 1]], [pts[i, 2]])
        start = max(0, i - 40)
        segment = pts[start : i + 1]
        trail.set_data(segment[:, 0], segment[:, 1])
        trail.set_3d_properties(segment[:, 2])
        ax.view_init(elev=24 + 8 * np.sin(frame / max(frames - 1, 1) * 2 * np.pi), azim=frame / max(frames - 1, 1) * 360.0)
        ax.set_title(f"{view_key.upper()} | {metric}", color="#f7fbff", fontsize=12)
        return scatter, marker, trail

    animation = FuncAnimation(fig, update, frames=frames, interval=1000 / fps, blit=False)
    animation.save(out, writer=PillowWriter(fps=fps), dpi=82)
    plt.close(fig)


def recording_folder(csv_path: Path, out_root: Path) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    return out_root / f"{csv_path.stem}_recording_{stamp}"


def main() -> int:
    parser = argparse.ArgumentParser(description="Record low-data RDFT Hopf GIFs and portrait graph exports.")
    parser.add_argument("csv", type=Path)
    parser.add_argument("--out-root", type=Path, default=Path("recordings"))
    parser.add_argument("--max-points", type=int, default=700)
    parser.add_argument("--frames", type=int, default=48)
    parser.add_argument("--fps", type=int, default=10)
    parser.add_argument("--open-folder", action="store_true")
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"CSV not found: {args.csv}")
        return 2

    df = pd.read_csv(args.csv)
    out_dir = recording_folder(args.csv, args.out_root)
    anim_dir = out_dir / "animations"
    graph_dir = out_dir / "graphs"
    anim_dir.mkdir(parents=True, exist_ok=True)
    graph_dir.mkdir(parents=True, exist_ok=True)

    berry_page(df, graph_dir / f"{args.csv.stem}_berry_portrait.png", max(args.max_points, 900))
    dimensional_page(df, graph_dir / f"{args.csv.stem}_dimensional_portrait.png", max(args.max_points, 900))

    for key in VIEW_KEYS:
        pts, metrics = BUILDERS[key](df, args.max_points)
        render_gif(key, pts, metrics, anim_dir / f"{args.csv.stem}_{key}_spinning_metrics.gif", args.frames, args.fps)
        print(anim_dir / f"{args.csv.stem}_{key}_spinning_metrics.gif")

    print(out_dir)
    if args.open_folder:
        subprocess.run(["open", str(out_dir)], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
