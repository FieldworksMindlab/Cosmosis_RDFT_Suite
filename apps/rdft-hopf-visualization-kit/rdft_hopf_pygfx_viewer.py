#!/usr/bin/env python3
"""
RDFT Hopf / Hyperobject Manifold Viewer
=======================================

Interactive PyGFX renderer for RDFT_FIELD SYNTH oscillator-state CSV logs.

It builds four views from one osc_state_*.csv file:

1. Hopf base trajectory
   Uses: hopf_base_x, hopf_base_y, hopf_base_z

2. Phase-derived Hopf projection
   Uses: hopf_fiber_phase, hopf_thread_phase, found_coherence,
   floquet_lock_gated, hopf_link_proxy

3. PCA manifold embedding
   Uses a broad set of RDFT state variables and projects them into 3D.

4. Winding-space transit
   Uses: hopf_fiber_winding, hopf_thread_winding, hopf_activity_proxy

This is a visualization of a projected higher-dimensional state manifold.
It does not claim the system is literally a 4D object. The tesseract overlay
is a reference scaffold only.

Install
-------
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pygfx wgpu rendercanvas pandas numpy pylinalg

Run
---
python rdft_hopf_pygfx_viewer.py osc_state_2026-06-15_08-20-12.csv
python rdft_hopf_pygfx_viewer.py osc_state_2026-06-15_08-20-12.csv --view pca

Controls
--------
Mouse drag / trackpad drag : orbit camera
Mouse wheel / trackpad     : zoom
Drop CSV file onto window : load dataset
O                         : open CSV file picker
P                         : generate/open Berry portrait dashboard
D                         : generate/open dimensional portrait dashboard
E                         : export/record GIFs and portrait graphs
M                         : cycle path metric color
V                         : color path by velocity
B                         : color path by holonomy / Berry phase
C                         : color path by curvature density
1                         : Hopf base trajectory
2                         : Phase-derived Hopf projection
3                         : PCA manifold embedding
4                         : Winding-space transit
A                         : toggle auto-rotation
Space                     : pause/resume moving transit marker
T                         : toggle dissipative transit trail
G                         : cycle trail glow strength
Y                         : toggle tesseract/hypercube reference scaffold
R                         : reset camera to current view
H                         : print help
Esc / Q                   : quit terminal process
"""

from __future__ import annotations

import argparse
import math
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional

import numpy as np
import pandas as pd

try:
    from rendercanvas.auto import RenderCanvas, loop
except Exception:
    # Fallback for older PyGFX/WGPU installs.
    from wgpu.gui.auto import WgpuCanvas as RenderCanvas, run as _run

    class _LoopShim:
        def run(self):
            _run()

    loop = _LoopShim()

import pygfx as gfx


VIEW_BUILDERS = ()
METRIC_MODES = ["solid", "time", "velocity", "holonomy", "curvature"]
METRIC_LABELS = {
    "solid": "view color",
    "time": "time",
    "velocity": "velocity",
    "holonomy": "holonomy",
    "curvature": "curvature",
}


@dataclass
class ViewData:
    key: str
    name: str
    positions: np.ndarray
    metrics: Dict[str, np.ndarray]
    color: str
    thickness: float
    description: str


def require_columns(df: pd.DataFrame, cols: Iterable[str], view_name: str) -> None:
    missing = [c for c in cols if c not in df.columns]
    if missing:
        raise KeyError(f"Cannot build {view_name}; missing columns: {', '.join(missing)}")


def first_present_column(df: pd.DataFrame, candidates: List[str], view_name: str) -> str:
    for col in candidates:
        if col in df.columns:
            return col
    raise KeyError(f"Cannot build {view_name}; missing one of: {', '.join(candidates)}")


def clean_numeric_frame(df: pd.DataFrame, cols: List[str]) -> pd.DataFrame:
    numeric = df[cols].apply(pd.to_numeric, errors="coerce")
    numeric = numeric.replace([np.inf, -np.inf], np.nan)
    return numeric.fillna(numeric.median(numeric_only=True))


def normalize_positions(points: np.ndarray, scale: float = 8.0) -> np.ndarray:
    pts = np.asarray(points, dtype=np.float32)
    pts = np.nan_to_num(pts, nan=0.0, posinf=0.0, neginf=0.0)
    center = pts.mean(axis=0, keepdims=True)
    pts = pts - center
    span = float(np.max(np.ptp(pts, axis=0)))
    if span < 1e-9:
        span = 1.0
    return (pts / span * scale).astype(np.float32)


def downsample(points: np.ndarray, max_points: int) -> np.ndarray:
    return points[sample_indices(len(points), max_points)].astype(np.float32)


def sample_indices(length: int, max_points: int) -> np.ndarray:
    if length <= max_points:
        return np.arange(length, dtype=int)
    idx = np.linspace(0, length - 1, max_points).astype(int)
    return idx


def clean_numeric_series(df: pd.DataFrame, col: str) -> np.ndarray:
    values = pd.to_numeric(df[col], errors="coerce").replace([np.inf, -np.inf], np.nan)
    if values.isna().all():
        return np.zeros(len(df), dtype=np.float32)
    return values.fillna(values.median()).to_numpy(dtype=np.float32)


def first_numeric_series(df: pd.DataFrame, candidates: List[str]) -> Optional[np.ndarray]:
    for col in candidates:
        if col in df.columns:
            return clean_numeric_series(df, col)
    return None


def build_metric_values(df: pd.DataFrame, sample_idx: np.ndarray, positions: np.ndarray) -> Dict[str, np.ndarray]:
    count = len(sample_idx)
    metrics: Dict[str, np.ndarray] = {
        "time": np.linspace(0.0, 1.0, count, dtype=np.float32),
    }

    velocity = first_numeric_series(df, ["orbital_speed", "cart_velocity", "ocean_velocity", "root_freq_slew_rate"])
    if velocity is None:
        deltas = np.linalg.norm(np.diff(positions, axis=0, prepend=positions[:1]), axis=1)
        velocity = deltas.astype(np.float32)
        metrics["velocity"] = velocity
    else:
        metrics["velocity"] = velocity[sample_idx].astype(np.float32)

    holonomy = first_numeric_series(df, ["berry_phase_principal", "berry_phase", "berry_winding_turns"])
    if holonomy is None:
        holonomy = np.zeros(len(df), dtype=np.float32)
    metrics["holonomy"] = holonomy[sample_idx].astype(np.float32)

    curvature = first_numeric_series(df, ["berry_curvature_density", "orient_area", "hopf_fiber_delta"])
    if curvature is None:
        curvature = np.zeros(len(df), dtype=np.float32)
    metrics["curvature"] = curvature[sample_idx].astype(np.float32)

    return metrics


def hex_to_rgb_array(color: str) -> np.ndarray:
    color = color.lstrip("#")
    return np.array([int(color[i : i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


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
    return np.clip((vals - lo) / (hi - lo), 0.0, 1.0).astype(np.float32)


def color_ramp(values: np.ndarray, stops: List[str]) -> np.ndarray:
    t = robust_normalize(values)
    stop_rgb = np.array([hex_to_rgb_array(c) for c in stops], dtype=np.float32)
    scaled = t * (len(stops) - 1)
    low = np.floor(scaled).astype(int)
    high = np.clip(low + 1, 0, len(stops) - 1)
    frac = (scaled - low)[:, None]
    rgb = stop_rgb[low] * (1.0 - frac) + stop_rgb[high] * frac
    return np.column_stack([rgb, np.ones(len(t), dtype=np.float32)]).astype(np.float32)


def metric_colors(view: ViewData, mode: str) -> np.ndarray:
    if mode == "solid" or mode not in view.metrics:
        rgb = np.tile(hex_to_rgb_array(view.color), (len(view.positions), 1))
        return np.column_stack([rgb, np.ones(len(view.positions), dtype=np.float32)]).astype(np.float32)
    if mode == "time":
        return color_ramp(view.metrics[mode], ["#243b6b", "#22c7ff", "#fff4b8", "#ff5cb8"])
    if mode == "velocity":
        return color_ramp(view.metrics[mode], ["#20315f", "#20d6b5", "#fff176", "#ff4d4d"])
    if mode == "curvature":
        vals = np.asarray(view.metrics[mode], dtype=np.float32)
        span = float(np.percentile(np.abs(vals), 98))
        if span < 1e-9:
            norm = np.full(len(vals), 0.5, dtype=np.float32)
        else:
            norm = np.clip((vals / span + 1.0) * 0.5, 0.0, 1.0)
        return color_ramp(norm, ["#2a62ff", "#f7fbff", "#ff8a33"])

    phase = np.asarray(view.metrics["holonomy"], dtype=np.float32)
    turns = np.mod(phase, 2.0 * np.pi) / (2.0 * np.pi)
    r = 0.55 + 0.45 * np.cos(2.0 * np.pi * turns)
    g = 0.55 + 0.45 * np.cos(2.0 * np.pi * (turns - 0.34))
    b = 0.55 + 0.45 * np.cos(2.0 * np.pi * (turns - 0.67))
    rgb = np.column_stack([r, g, b]).astype(np.float32)
    return np.column_stack([rgb, np.ones(len(turns), dtype=np.float32)]).astype(np.float32)


def metric_summary(view: ViewData, mode: str, index: int) -> str:
    if mode == "solid" or mode not in view.metrics:
        return "metric: view color"
    values = view.metrics[mode]
    if len(values) == 0:
        return f"metric: {METRIC_LABELS.get(mode, mode)}"
    idx = min(max(index, 0), len(values) - 1)
    value = float(values[idx])
    label = METRIC_LABELS.get(mode, mode)
    if mode == "holonomy":
        return f"metric: {label} {value:.3f} rad ({value / (2.0 * np.pi):.3f} turns)"
    return f"metric: {label} {value:.4g}"
    return points[idx].astype(np.float32)


def build_hopf_base(df: pd.DataFrame, max_points: int) -> ViewData:
    cols = ["hopf_base_x", "hopf_base_y", "hopf_base_z"]
    require_columns(df, cols, "Hopf base trajectory")
    sample_idx = sample_indices(len(df), max_points)
    pts_all = normalize_positions(clean_numeric_frame(df, cols).to_numpy(dtype=np.float32))
    pts = pts_all[sample_idx]
    return ViewData(
        key="base",
        name="Hopf base trajectory",
        positions=pts,
        metrics=build_metric_values(df, sample_idx, pts),
        color="#5ec8ff",
        thickness=3.0,
        description="Direct projection of logged hopf_base_x/y/z.",
    )


def build_phase_hopf(df: pd.DataFrame, max_points: int) -> ViewData:
    view_name = "phase-derived Hopf projection"
    require_columns(df, ["hopf_fiber_phase", "hopf_thread_phase"], view_name)
    coherence_col = first_present_column(df, ["found_coherence", "landauer_coherence"], view_name)
    lock_col = first_present_column(df, ["floquet_lock_gated", "floquet_lock_raw", "floquet_g_eff"], view_name)
    link_col = first_present_column(
        df,
        ["hopf_link_proxy", "hopf_fieldorient_proxy", "fourth_sphere_gamma", "fourth_sphere_area"],
        view_name,
    )

    phase1 = clean_numeric_series(df, "hopf_fiber_phase").astype(np.float64)
    phase2 = clean_numeric_series(df, "hopf_thread_phase").astype(np.float64)

    mix_src = (
        0.45 * clean_numeric_series(df, coherence_col).astype(np.float64)
        + 0.35 * clean_numeric_series(df, lock_col).astype(np.float64)
        + 0.20 * clean_numeric_series(df, link_col).astype(np.float64)
    )
    mix_norm = (mix_src - np.min(mix_src)) / (np.max(mix_src) - np.min(mix_src) + 1e-12)
    eta = (np.pi / 2.0) * mix_norm

    # Build two complex coordinates on S3 and map to S2 using the Hopf map:
    # X = 2 Re(z1 * conj(z2)), Y = 2 Im(z1 * conj(z2)), Z = |z1|^2 - |z2|^2.
    z1 = np.cos(eta) * np.exp(1j * phase1)
    z2 = np.sin(eta) * np.exp(1j * phase2)

    X = 2.0 * np.real(z1 * np.conj(z2))
    Y = 2.0 * np.imag(z1 * np.conj(z2))
    Z = np.abs(z1) ** 2 - np.abs(z2) ** 2

    sample_idx = sample_indices(len(df), max_points)
    pts_all = normalize_positions(np.column_stack([X, Y, Z]).astype(np.float32))
    pts = pts_all[sample_idx]
    return ViewData(
        key="phase",
        name="Phase-derived Hopf projection",
        positions=pts,
        metrics=build_metric_values(df, sample_idx, pts),
        color="#b07cff",
        thickness=2.6,
        description="Hopf-style S3->S2 projection from fiber/thread phases.",
    )


def build_pca_embedding(df: pd.DataFrame, max_points: int) -> ViewData:
    candidate_features = [
        "alpha", "depth", "orbital_phi", "orbital_speed", "orbital_radius",
        "entropy", "fractal_dim", "lyapunov",
        "berry_phase_principal", "berry_curvature_density",
        "floquet_phase", "floquet_quasienergy", "floquet_coupling_env", "floquet_lock_gated",
        "found_coherence", "found_coupling",
        "cart_x", "cart_y", "cart_z", "cart_stability",
        "orbit_resonance", "beltrami_lambda", "beltrami_alignment",
        "landauer_coherence", "harmonic_pressure_smoothed",
        "hopf_fiber_phase", "hopf_thread_phase", "hopf_link_proxy", "hopf_fieldorient_proxy", "hopf_activity_proxy",
        "fourth_sphere_gamma", "fourth_sphere_gamma_pi", "fourth_sphere_area",
        "fourth_sphere_seals", "fourth_sphere_mean_pi", "fourth_sphere_std_pi",
    ]

    features = [c for c in candidate_features if c in df.columns]
    if len(features) < 4:
        raise KeyError("Not enough numeric features to build PCA manifold embedding.")

    data = clean_numeric_frame(df, features).to_numpy(dtype=np.float64)
    data = (data - data.mean(axis=0)) / (data.std(axis=0) + 1e-12)

    U, S, VT = np.linalg.svd(data, full_matrices=False)
    scores = U[:, :3] * S[:3]
    explained = (S ** 2) / np.sum(S ** 2)

    sample_idx = sample_indices(len(df), max_points)
    pts_all = normalize_positions(scores.astype(np.float32))
    pts = pts_all[sample_idx]

    return ViewData(
        key="pca",
        name=(
            f"PCA manifold embedding "
            f"(PC1={explained[0]:.1%}, PC2={explained[1]:.1%}, PC3={explained[2]:.1%})"
        ),
        positions=pts,
        metrics=build_metric_values(df, sample_idx, pts),
        color="#77ff9f",
        thickness=2.4,
        description=f"3D PCA projection from {len(features)} logged RDFT state dimensions.",
    )


def build_winding_space(df: pd.DataFrame, max_points: int) -> ViewData:
    cols = ["hopf_fiber_winding", "hopf_thread_winding", "hopf_activity_proxy"]
    require_columns(df, cols, "winding-space transit")
    sample_idx = sample_indices(len(df), max_points)
    pts_all = normalize_positions(clean_numeric_frame(df, cols).to_numpy(dtype=np.float32))
    pts = pts_all[sample_idx]
    return ViewData(
        key="winding",
        name="Winding-space transit",
        positions=pts,
        metrics=build_metric_values(df, sample_idx, pts),
        color="#ffd166",
        thickness=2.7,
        description="Fiber winding vs thread winding vs Hopf activity.",
    )


VIEW_BUILDERS = (build_hopf_base, build_phase_hopf, build_pca_embedding, build_winding_space)


def make_line_object(
    positions: np.ndarray,
    color: str,
    thickness: float,
    colors: Optional[np.ndarray] = None,
) -> gfx.Line:
    if colors is None:
        geom = gfx.Geometry(positions=positions.astype(np.float32))
        mat = gfx.LineMaterial(color=color, thickness=thickness, aa=True)
    else:
        geom = gfx.Geometry(positions=positions.astype(np.float32), colors=colors.astype(np.float32))
        mat = gfx.LineMaterial(thickness=thickness, color_mode="vertex", aa=True)
    return gfx.Line(geom, mat)


def make_points_object(positions: np.ndarray, color: str, size: float = 12.0) -> gfx.Points:
    geom = gfx.Geometry(positions=positions.astype(np.float32))
    mat = gfx.PointsMaterial(color=color, size=size)
    return gfx.Points(geom, mat)


def make_view_group(view: ViewData, metric_mode: str = "solid") -> gfx.Group:
    group = gfx.Group()

    line = make_line_object(view.positions, view.color, view.thickness, colors=metric_colors(view, metric_mode))
    group.add(line)

    # Subtle point cloud along the trajectory.
    dots = make_points_object(view.positions[:: max(1, len(view.positions) // 500)], view.color, size=3.0)
    group.add(dots)

    # Start/end markers.
    start = make_points_object(view.positions[:1], "#00ffaa", size=14.0)
    end = make_points_object(view.positions[-1:], "#ff6b6b", size=14.0)
    group.add(start, end)

    return group


def build_tesseract_reference(scale: float = 5.0, distance: float = 3.2) -> gfx.Line:
    """Build a projected 4D hypercube / tesseract scaffold as a 3D reference cage."""
    verts4 = []
    for x in [-1, 1]:
        for y in [-1, 1]:
            for z in [-1, 1]:
                for w in [-1, 1]:
                    verts4.append((x, y, z, w))
    verts4 = np.array(verts4, dtype=np.float32)

    # Perspective project 4D -> 3D. This is only a dimensional reference frame.
    w = verts4[:, 3]
    factor = distance / (distance - 0.85 * w)
    verts3 = verts4[:, :3] * factor[:, None] * scale

    segments = []
    for i, a in enumerate(verts4):
        for j in range(i + 1, len(verts4)):
            b = verts4[j]
            if np.sum(a != b) == 1:
                segments.append(verts3[i])
                segments.append(verts3[j])
                segments.append(np.array([np.nan, np.nan, np.nan], dtype=np.float32))

    positions = np.array(segments, dtype=np.float32)
    mat = gfx.LineMaterial(color="#3b4a66", thickness=1.2, aa=True, opacity=0.45)
    return gfx.Line(gfx.Geometry(positions=positions), mat)


def print_help() -> None:
    print(__doc__)


class Viewer:
    def __init__(
        self,
        csv_path: Path,
        start_view: str,
        max_points: int,
        auto_rotate: bool,
        trail_length: int,
        trails_enabled: bool,
        metric_mode: str,
    ):
        self.max_points = max_points
        self.csv_path = Path(csv_path)
        self.df = pd.DataFrame()
        self.views: Dict[str, ViewData] = {}
        self.status_message = ""
        self.status_until = 0.0
        self.active_key = start_view
        self.paused = False
        self.auto_rotate = auto_rotate
        self.marker_index = 0
        self.marker_steps = 0
        self.last_step_time = time.time()
        self.trail_length = max(2, int(trail_length))
        self.trails_enabled = trails_enabled
        self.glow_level = 2
        self.metric_mode = metric_mode if metric_mode in METRIC_MODES else "solid"

        self.canvas = RenderCanvas(size=(1280, 820), title="RDFT Hopf / Hyperobject Manifold Viewer")
        try:
            self.renderer = gfx.renderers.WgpuRenderer(self.canvas, show_fps=True)
        except TypeError:
            self.renderer = gfx.WgpuRenderer(self.canvas)
        self.install_drop_callback()

        self.scene = gfx.Scene()
        self.scene.add(gfx.Background.from_color("#05060c", "#101323"))
        self.ui_scene, self.ui_camera, self.ui_bar, self.ui_text = self.make_ui_overlay()
        self.renderer.add_event_handler(self.update_ui_layout, "resize")
        self.update_ui_layout()

        self.camera = gfx.PerspectiveCamera(65, 1280 / 820, depth_range=(0.01, 5000))
        self.camera.local.position = (9, -12, 9)
        self.camera.show_pos((0, 0, 0))

        self.controller = gfx.OrbitController(self.camera, register_events=self.renderer)

        self.scene.add(gfx.AxesHelper(size=4.0, thickness=2.0))
        self.scene.add(gfx.GridHelper(size=12.0, thickness=1.0))

        self.groups: Dict[str, gfx.Group] = {}

        self.tesseract = build_tesseract_reference()
        self.tesseract.visible = True
        self.scene.add(self.tesseract)

        self.marker = make_points_object(np.array([[0, 0, 0]], dtype=np.float32), "#ffffff", size=20.0)
        self.scene.add(self.marker)
        self.trail_group, self.trail_layers = self.make_trail_group(self.trail_length)
        self.scene.add(self.trail_group)

        self.renderer.add_event_handler(self.on_key_down, "key_down")
        self.load_csv(csv_path, start_view=start_view, initial=True)

    @property
    def active_view(self) -> ViewData:
        return self.views[self.active_key]

    def make_ui_overlay(self):
        scene = gfx.Scene()
        camera = gfx.ScreenCoordsCamera()

        bar_geometry = gfx.plane_geometry()
        bar_geometry.positions.data[..., :2] += [0.5, -0.5]
        bar = gfx.Mesh(
            bar_geometry,
            gfx.MeshBasicMaterial(color="#061018", side="both", opacity=0.84),
        )
        text = gfx.Text(
            material=gfx.TextMaterial(color="#c7f6ff", outline_color="#000000", outline_thickness=0.12),
            text="",
            screen_space=True,
            font_size=15,
            anchor="topleft",
        )
        scene.add(bar, text)
        return scene, camera, bar, text

    def update_ui_layout(self, event=None) -> None:
        width, height = self.renderer.logical_size
        bar_h = 34
        self.ui_bar.local.position = (0, height, 0.1)
        self.ui_bar.local.scale = (width, bar_h, 1)
        self.ui_text.local.position = (12, height - 9, 0)

    def set_status(self, message: str, seconds: float = 5.0) -> None:
        self.status_message = message
        self.status_until = time.time() + seconds
        self.update_ui_text()
        self.canvas.request_draw()

    def update_ui_text(self) -> None:
        name = self.csv_path.name if self.csv_path else "no CSV"
        view = self.active_view.name if self.views else "no view"
        metric = metric_summary(self.active_view, self.metric_mode, self.marker_index) if self.views else "metric: none"
        help_text = (
            f"Drop CSV | O open | P Berry | D dimensional | E record | M metric | V velocity | B holonomy | T trails | "
            f"dataset: {name} | view: {view} | {metric}"
        )
        if self.status_message and time.time() < self.status_until:
            help_text = f"{self.status_message} | {help_text}"
        self.ui_text.set_text(help_text)

    def build_views(self, df: pd.DataFrame) -> Dict[str, ViewData]:
        views: Dict[str, ViewData] = {}
        for builder in VIEW_BUILDERS:
            view = builder(df, max_points=self.max_points)
            views[view.key] = view
        return views

    def load_csv(self, csv_path: Path, start_view: Optional[str] = None, initial: bool = False) -> bool:
        csv_path = Path(csv_path).expanduser()
        if not csv_path.exists():
            self.set_status(f"CSV not found: {csv_path}", seconds=8.0)
            return False
        if csv_path.suffix.lower() != ".csv":
            self.set_status(f"Not a CSV: {csv_path.name}", seconds=8.0)
            return False

        try:
            df = pd.read_csv(csv_path)
            if df.empty:
                raise ValueError("CSV is empty")
            views = self.build_views(df)
        except Exception as exc:
            if initial:
                raise
            self.set_status(f"Could not load {csv_path.name}: {exc}", seconds=10.0)
            print(f"\nCSV load error: {exc}", file=sys.stderr)
            return False

        for group in self.groups.values():
            self.scene.remove(group)

        self.csv_path = csv_path
        self.df = df
        self.views = views
        self.groups = {}
        self.active_key = start_view if start_view in views else self.active_key
        if self.active_key not in views:
            self.active_key = "base"
        for key, view in self.views.items():
            group = make_view_group(view, self.metric_mode)
            group.visible = key == self.active_key
            self.scene.add(group)
            self.groups[key] = group

        self.marker_index = 0
        self.marker_steps = 0
        self.update_marker(force=True)
        self.update_trail()
        self.camera.show_object(self.groups[self.active_key], view_dir=(-1.6, -1.3, 1.0), up=(0, 0, 1))
        self.set_status(f"Loaded {csv_path.name} ({len(df)} rows)", seconds=7.0)
        print(f"\nLoaded dataset: {csv_path}")
        print(f"Rows: {len(df)}")
        return True

    def install_drop_callback(self) -> None:
        try:
            import glfw

            window = getattr(self.canvas, "_window", None)
            if window is None:
                return

            def on_drop(_window, paths):
                for raw_path in paths:
                    path = Path(raw_path)
                    if path.suffix.lower() == ".csv":
                        self.load_csv(path)
                        return
                self.set_status("Drop an osc_state CSV file", seconds=6.0)

            self._drop_callback = on_drop
            glfw.set_drop_callback(window, self._drop_callback)
        except Exception as exc:
            print(f"File drop unavailable: {exc}", file=sys.stderr)

    def open_csv_dialog(self) -> None:
        script = (
            'POSIX path of (choose file with prompt "Choose an RDFT osc_state CSV" '
            'of type {"public.comma-separated-values-text", "public.text"})'
        )
        try:
            result = subprocess.run(
                ["osascript", "-e", script],
                check=False,
                capture_output=True,
                text=True,
                timeout=120,
            )
        except Exception as exc:
            self.set_status(f"File picker failed: {exc}", seconds=8.0)
            return

        if result.returncode == 0 and result.stdout.strip():
            self.load_csv(Path(result.stdout.strip()))
        else:
            self.set_status("File picker canceled", seconds=3.0)

    def open_dashboard(self, page: str = "berry") -> None:
        script = Path(__file__).with_name("rdft_hopf_dashboard.py")
        out_dir = Path(__file__).with_name("dashboards")
        try:
            subprocess.Popen(
                [
                    sys.executable,
                    str(script),
                    str(self.csv_path),
                    "--page",
                    page,
                    "--out-dir",
                    str(out_dir),
                    "--open",
                ]
            )
            self.set_status(f"Generating {page} portrait page...", seconds=6.0)
        except Exception as exc:
            self.set_status(f"Dashboard failed: {exc}", seconds=8.0)

    def record_data_package(self) -> None:
        script = Path(__file__).with_name("rdft_hopf_recorder.py")
        out_root = Path(__file__).with_name("recordings")
        try:
            subprocess.Popen(
                [
                    sys.executable,
                    str(script),
                    str(self.csv_path),
                    "--out-root",
                    str(out_root),
                    "--open-folder",
                ]
            )
            self.set_status("Recording GIFs and graph package...", seconds=8.0)
        except Exception as exc:
            self.set_status(f"Recording failed: {exc}", seconds=8.0)

    def set_view(self, key: str) -> None:
        if key not in self.views:
            return
        self.active_key = key
        for k, g in self.groups.items():
            g.visible = k == key
        self.marker_index = min(self.marker_index, len(self.active_view.positions) - 1)
        self.marker_steps = 0
        self.update_marker(force=True)
        self.update_trail()
        self.camera.show_object(self.groups[key], view_dir=(-1.6, -1.3, 1.0), up=(0, 0, 1))
        self.update_ui_text()
        print(f"\nView: {self.active_view.name}")
        print(f"  {self.active_view.description}")

    def set_metric_mode(self, mode: str) -> None:
        if mode not in METRIC_MODES:
            return
        self.metric_mode = mode
        for key, group in self.groups.items():
            view = self.views[key]
            line = group.children[0]
            colors = metric_colors(view, self.metric_mode)
            line.geometry.colors.data[:] = colors
            line.geometry.colors.update_full()
        self.update_trail()
        self.update_ui_text()
        print(f"Path metric: {METRIC_LABELS.get(self.metric_mode, self.metric_mode)}")

    def cycle_metric_mode(self) -> None:
        index = METRIC_MODES.index(self.metric_mode) if self.metric_mode in METRIC_MODES else 0
        self.set_metric_mode(METRIC_MODES[(index + 1) % len(METRIC_MODES)])

    def update_marker(self, force: bool = False) -> None:
        now = time.time()
        if not force and (now - self.last_step_time) < 0.025:
            return
        self.last_step_time = now

        pts = self.active_view.positions
        if len(pts) == 0:
            return

        if not self.paused or force:
            if not force:
                self.marker_index = (self.marker_index + 1) % len(pts)
                self.marker_steps += 1
            self.marker.local.position = tuple(float(v) for v in pts[self.marker_index])
            self.update_trail()

    @staticmethod
    def hex_to_rgb(color: str) -> np.ndarray:
        color = color.lstrip("#")
        return np.array([int(color[i : i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)

    def make_trail_group(self, trail_length: int):
        group = gfx.Group()
        blank_positions = np.full((trail_length, 3), np.nan, dtype=np.float32)
        blank_colors = np.zeros((trail_length, 4), dtype=np.float32)

        layer_specs = [
            ("outer aura", 22.0, 0.08),
            ("middle glow", 12.0, 0.18),
            ("hot core", 4.0, 0.95),
        ]
        layers = []
        for _, thickness, opacity in layer_specs:
            geom = gfx.Geometry(positions=blank_positions.copy(), colors=blank_colors.copy())
            mat = gfx.LineMaterial(thickness=thickness, color_mode="vertex", aa=True, opacity=opacity)
            line = gfx.Line(geom, mat)
            group.add(line)
            layers.append((line, opacity))
        return group, layers

    def update_trail(self) -> None:
        self.trail_group.visible = self.trails_enabled
        if not self.trails_enabled:
            return

        pts = self.active_view.positions
        if len(pts) == 0:
            return

        count = min(self.trail_length, self.marker_steps + 1, len(pts))
        positions = np.full((self.trail_length, 3), np.nan, dtype=np.float32)
        colors = np.zeros((self.trail_length, 4), dtype=np.float32)

        idx = (self.marker_index - np.arange(count - 1, -1, -1)) % len(pts)
        positions[-count:] = pts[idx]

        active_line = self.groups[self.active_key].children[0] if self.groups else None
        if active_line is not None and hasattr(active_line.geometry, "colors"):
            head = active_line.geometry.colors.data[min(self.marker_index, len(pts) - 1), :3].astype(np.float32)
        else:
            head = self.hex_to_rgb(self.active_view.color)
        ember = np.array([0.04, 0.12, 0.18], dtype=np.float32)
        white = np.array([1.0, 0.96, 0.86], dtype=np.float32)
        t = np.linspace(0.0, 1.0, count, dtype=np.float32)
        heat = t[:, None] ** 2.2
        rgb = (1.0 - t[:, None]) * ember + t[:, None] * head
        rgb = (1.0 - heat) * rgb + heat * white
        alpha = np.clip(t**1.7, 0.0, 1.0)

        colors[-count:, :3] = rgb
        colors[-count:, 3] = alpha

        glow_scale = [0.0, 0.45, 0.75, 1.0][self.glow_level]
        for layer_index, (line, base_opacity) in enumerate(self.trail_layers):
            layer_colors = colors.copy()
            if layer_index < 2:
                layer_colors[:, 3] *= glow_scale
            line.geometry.positions.data[:] = positions
            line.geometry.colors.data[:] = layer_colors
            line.geometry.positions.update_full()
            line.geometry.colors.update_full()
            line.material.opacity = base_opacity

    def on_key_down(self, event) -> None:
        key = str(getattr(event, "key", "")).lower()

        if key == "1":
            self.set_view("base")
        elif key == "2":
            self.set_view("phase")
        elif key == "3":
            self.set_view("pca")
        elif key == "4":
            self.set_view("winding")
        elif key == "o":
            self.open_csv_dialog()
        elif key == "p":
            self.open_dashboard("berry")
        elif key == "d":
            self.open_dashboard("dimensional")
        elif key == "e":
            self.record_data_package()
        elif key == "m":
            self.cycle_metric_mode()
        elif key == "v":
            self.set_metric_mode("velocity")
        elif key == "b":
            self.set_metric_mode("holonomy")
        elif key == "c":
            self.set_metric_mode("curvature")
        elif key == "a":
            self.auto_rotate = not self.auto_rotate
            print(f"Auto-rotation: {self.auto_rotate}")
        elif key == " ":
            self.paused = not self.paused
            print(f"Transit marker paused: {self.paused}")
        elif key == "t":
            self.trails_enabled = not self.trails_enabled
            self.update_trail()
            print(f"Dissipative trail visible: {self.trails_enabled}")
        elif key == "g":
            self.glow_level = (self.glow_level + 1) % 4
            self.update_trail()
            print(f"Trail glow level: {self.glow_level}/3")
        elif key == "y":
            self.tesseract.visible = not self.tesseract.visible
            print(f"Tesseract scaffold visible: {self.tesseract.visible}")
        elif key == "r":
            self.camera.show_object(self.groups[self.active_key], view_dir=(-1.6, -1.3, 1.0), up=(0, 0, 1))
        elif key == "h":
            print_help()
        elif key in ("escape", "q"):
            print("Close the viewer window or Ctrl+C in terminal to exit.")

    def animate(self):
        if self.auto_rotate:
            # Rotate the active group very slightly; this makes the manifold object feel volumetric.
            # This block is intentionally optional; if pylinalg is unavailable, the viewer still works.
            try:
                import pylinalg as la
                g = self.groups[self.active_key]
                rot = la.quat_from_euler((0.0, 0.003, 0.004), order="XYZ")
                g.local.rotation = la.quat_mul(rot, g.local.rotation)
            except Exception:
                pass

        self.update_marker()
        self.update_trail()
        self.update_ui_text()
        self.renderer.render(self.scene, self.camera, flush=False)
        self.renderer.render(self.ui_scene, self.ui_camera, clear_color=False)
        self.canvas.request_draw()

    def run(self) -> None:
        print("\nRDFT Hopf / Hyperobject Manifold Viewer")
        print(f"Loaded: {self.csv_path}")
        print(f"Rows: {len(self.df)}")
        print("Press H for help.")
        self.set_view(self.active_key)
        self.canvas.request_draw(self.animate)
        loop.run()


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Interactive PyGFX viewer for RDFT Hopf manifold CSV data.")
    parser.add_argument("csv", type=Path, help="Path to osc_state_*.csv")
    parser.add_argument(
        "--view",
        choices=["base", "phase", "pca", "winding"],
        default="base",
        help="Starting view.",
    )
    parser.add_argument(
        "--max-points",
        type=int,
        default=2500,
        help="Maximum points used for each trajectory. Increase if your GPU handles it.",
    )
    parser.add_argument(
        "--no-auto-rotate",
        action="store_true",
        help="Start without auto-rotation.",
    )
    parser.add_argument(
        "--trail-length",
        type=int,
        default=180,
        help="Number of recent transit samples used for the dissipative trail.",
    )
    parser.add_argument(
        "--no-trails",
        action="store_true",
        help="Start with dissipative trails hidden.",
    )
    parser.add_argument(
        "--metric",
        choices=METRIC_MODES,
        default="solid",
        help="Path color encoding.",
    )
    return parser.parse_args(argv)


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    if not args.csv.exists():
        print(f"CSV not found: {args.csv}", file=sys.stderr)
        return 2

    try:
        viewer = Viewer(
            csv_path=args.csv,
            start_view=args.view,
            max_points=args.max_points,
            auto_rotate=not args.no_auto_rotate,
            trail_length=args.trail_length,
            trails_enabled=not args.no_trails,
            metric_mode=args.metric,
        )
        viewer.run()
    except KeyboardInterrupt:
        return 0
    except Exception as exc:
        print(f"\nError: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
