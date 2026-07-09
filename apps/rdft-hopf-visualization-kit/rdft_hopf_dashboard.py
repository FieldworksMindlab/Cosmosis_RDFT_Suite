#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import time
from pathlib import Path
from typing import Iterable, List

os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).with_name(".matplotlib")))
Path(os.environ["MPLCONFIGDIR"]).mkdir(parents=True, exist_ok=True)

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd


def numeric(df: pd.DataFrame, name: str, default: float = 0.0) -> np.ndarray:
    if name not in df.columns:
        return np.full(len(df), default, dtype=np.float64)
    values = pd.to_numeric(df[name], errors="coerce").replace([np.inf, -np.inf], np.nan)
    if values.isna().all():
        return np.full(len(df), default, dtype=np.float64)
    return values.fillna(values.median()).to_numpy(dtype=np.float64)


def first_numeric(df: pd.DataFrame, names: Iterable[str], default: float = 0.0) -> np.ndarray:
    for name in names:
        if name in df.columns:
            return numeric(df, name, default)
    return np.full(len(df), default, dtype=np.float64)


def time_axis(df: pd.DataFrame) -> np.ndarray:
    return first_numeric(df, ["timestamp", "frameCount"], 0.0)


def sample(df: pd.DataFrame, max_points: int) -> np.ndarray:
    if len(df) <= max_points:
        return np.arange(len(df), dtype=int)
    return np.linspace(0, len(df) - 1, max_points).astype(int)


def standardize(data: np.ndarray) -> np.ndarray:
    data = np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0)
    return (data - data.mean(axis=0)) / (data.std(axis=0) + 1e-12)


def pca3(data: np.ndarray) -> np.ndarray:
    z = standardize(data)
    u, s, _ = np.linalg.svd(z, full_matrices=False)
    return u[:, :3] * s[:3]


def style_axis(ax) -> None:
    ax.grid(True, alpha=0.22)
    ax.tick_params(labelsize=8)


def add_failure_line(ax, x: np.ndarray, failure: np.ndarray) -> None:
    if np.any(failure > 0):
        first = x[np.argmax(failure > 0)]
        ax.axvline(first, color="#ff6b6b", linestyle="--", linewidth=1.2, alpha=0.8, label="event region")


def berry_page(df: pd.DataFrame, out: Path, max_points: int) -> None:
    idx = sample(df, max_points)
    t = time_axis(df)
    fiber_phase = first_numeric(df, ["hopf_fiber_phase", "berry_phase_principal", "berry_phase"], 0.0)
    thread_phase = first_numeric(df, ["hopf_thread_phase", "floquet_phase"], 0.0)
    berry = first_numeric(df, ["berry_phase_principal", "berry_phase"], 0.0)
    curvature = first_numeric(df, ["berry_curvature_density", "orient_area"], 0.0)
    failure = first_numeric(df, ["breakdown_count", "harmonic_escape_event", "return_error"], 0.0)

    fig = plt.figure(figsize=(19.2, 10.8), constrained_layout=True)
    fig.suptitle("RDFT Berry / Hopf Topological Portrait", fontsize=18, fontweight="bold")

    ax = fig.add_subplot(2, 3, 1, projection="3d")
    x = first_numeric(df, ["hopf_base_x", "cart_x"], 0.0)[idx]
    y = first_numeric(df, ["hopf_base_y", "cart_y"], 0.0)[idx]
    z = first_numeric(df, ["hopf_base_z", "cart_z"], 0.0)[idx]
    c = fiber_phase[idx]
    ax.plot(x, y, z, color="#b0b0b0", alpha=0.35, linewidth=0.8)
    sc = ax.scatter(x, y, z, c=c, cmap="plasma", s=14, alpha=0.9)
    ax.scatter([x[0]], [y[0]], [z[0]], c="#00ff66", s=70, marker="o", edgecolor="black", label="Start")
    ax.scatter([x[-1]], [y[-1]], [z[-1]], c="#00f0ff", s=70, marker="s", edgecolor="black", label="End")
    ax.set_title("Hopf Base Space Colored by Fiber Phase")
    ax.set_xlabel("base x")
    ax.set_ylabel("base y")
    ax.set_zlabel("base z")
    ax.legend(fontsize=8)
    fig.colorbar(sc, ax=ax, shrink=0.62, label="fiber phase")

    ax = fig.add_subplot(2, 3, 2)
    ax.plot(t, fiber_phase, color="#c0c0c0", linewidth=0.8, alpha=0.7)
    ax.scatter(t[idx], fiber_phase[idx], c=berry[idx], cmap="plasma", s=14, label="Berry phase")
    closure = first_numeric(df, ["loop_closed", "symbolic_holonomy_event"], 0.0)
    add_failure_line(ax, t, closure)
    ax.set_title("Fiber Phase Traversal and Holonomy States")
    ax.set_xlabel("time")
    ax.set_ylabel("phase / holonomy")
    ax.legend(fontsize=8)
    style_axis(ax)

    ax = fig.add_subplot(2, 3, 3)
    ret = first_numeric(df, ["return_error"], 0.0)
    ecc = first_numeric(df, ["orbit_eccentricity", "orbital_radius"], 0.0)
    ax.plot(t, ret, color="#aa1e1e", label="return error")
    ax.axhline(np.nanmin(ret), color="#ffb347", linestyle=":", label="min return error")
    ax2 = ax.twinx()
    ax2.plot(t, ecc, color="#4b8bc2", alpha=0.75, label="eccentricity/radius")
    ax.set_title("Loop Closure Diagnostics")
    ax.set_xlabel("time")
    ax.set_ylabel("return error", color="#aa1e1e")
    ax2.set_ylabel("eccentricity / radius", color="#4b8bc2")
    style_axis(ax)

    ax = fig.add_subplot(2, 3, 4)
    floquet = first_numeric(df, ["floquet_quasienergy", "floquet_coupling_env", "floquet_phase"], 0.0)
    ax.scatter(berry[idx], floquet[idx], c=curvature[idx], cmap="coolwarm", s=18, alpha=0.75)
    ax.set_title("Berry-Floquet Portrait")
    ax.set_xlabel("Berry phase / holonomy")
    ax.set_ylabel("Floquet response")
    style_axis(ax)

    ax = fig.add_subplot(2, 3, 5)
    linking = first_numeric(
        df,
        ["hopf_link_proxy", "hopf_fieldorient_proxy", "berry_winding_turns", "hopf_fiber_winding"],
        0.0,
    )
    ax.plot(t, linking, color="#bf49f2", linewidth=1.2)
    add_failure_line(ax, t, failure)
    ax.set_title("Hopf Linking / Winding Proxy")
    ax.set_xlabel("time")
    ax.set_ylabel("linking proxy")
    style_axis(ax)

    ax = fig.add_subplot(2, 3, 6)
    h = ax.hist2d(berry, thread_phase, weights=curvature, bins=42, cmap="RdBu_r")
    fig.colorbar(h[3], ax=ax, label="curvature-weighted density")
    ax.set_title("Topological Charge Density")
    ax.set_xlabel("Berry phase")
    ax.set_ylabel("thread phase")
    style_axis(ax)

    fig.savefig(out, dpi=150)
    plt.close(fig)


def dimensional_page(df: pd.DataFrame, out: Path, max_points: int) -> None:
    idx = sample(df, max_points)
    fig = plt.figure(figsize=(19.2, 10.8), constrained_layout=True)
    fig.suptitle("RDFT Dimensional / Field-Space Analysis", fontsize=18, fontweight="bold")

    ax = fig.add_subplot(2, 3, 1, projection="3d")
    x = first_numeric(df, ["orbital_speed", "cart_velocity"], 0.0)[idx]
    y = first_numeric(df, ["orbital_radius", "depth"], 0.0)[idx]
    z = first_numeric(df, ["emergent_eg", "effective_voltage"], 0.0)[idx]
    c = first_numeric(df, ["entropy", "found_coherence"], 0.0)[idx]
    ax.plot(x, y, z, color="#a8a8a8", alpha=0.25, linewidth=0.7)
    ax.scatter(x, y, z, c=c, cmap="plasma", s=14)
    ax.set_title("Phase Space: Speed x Radius x Energy")
    ax.set_xlabel("speed")
    ax.set_ylabel("radius/depth")
    ax.set_zlabel("energy")

    ax = fig.add_subplot(2, 3, 2, projection="3d")
    bx = numeric(df, "beltrami_Bx")[idx]
    by = numeric(df, "beltrami_By")[idx]
    bz = numeric(df, "beltrami_Bz")[idx]
    bmag = first_numeric(df, ["beltrami_Bmag", "beltrami_alignment"], 0.0)[idx]
    ax.plot(bx, by, bz, color="#9f9f9f", alpha=0.25, linewidth=0.7)
    ax.scatter(bx, by, bz, c=bmag, cmap="viridis", s=14)
    ax.set_title("Beltrami Field Vector Space")
    ax.set_xlabel("Bx")
    ax.set_ylabel("By")
    ax.set_zlabel("Bz")

    ax = fig.add_subplot(2, 3, 3, projection="3d")
    cx = numeric(df, "cart_x")[idx]
    cy = numeric(df, "cart_y")[idx]
    cz = numeric(df, "cart_z")[idx]
    stability = first_numeric(df, ["cart_stability", "found_coherence"], 0.0)[idx]
    ax.plot(cx, cy, cz, color="#a8a8a8", alpha=0.35, linewidth=0.7)
    ax.scatter(cx, cy, cz, c=stability, cmap="coolwarm_r", s=14)
    ax.set_title("Cartesian Stability Manifold")
    ax.set_xlabel("cart x")
    ax.set_ylabel("cart y")
    ax.set_zlabel("cart z")

    features = [
        "orbital_speed", "orbital_radius", "emergent_eg", "effective_voltage",
        "beltrami_Bmag", "beltrami_alignment", "cart_stability",
        "lyapunov", "entropy", "fractal_dim", "depth", "avg_brightness",
        "hopf_fieldorient_proxy", "fourth_sphere_gamma", "fourth_sphere_area",
        "fourth_sphere_mean_pi", "fourth_sphere_std_pi",
    ]
    available = [f for f in features if f in df.columns]
    data = np.column_stack([numeric(df, f) for f in available])
    scores = pca3(data)[idx]

    ax = fig.add_subplot(2, 3, 4, projection="3d")
    ax.scatter(scores[:, 0], scores[:, 1], scores[:, 2], c=np.linspace(0, 1, len(scores)), cmap="magma", s=14)
    ax.set_title("PCA: Physics Manifold")
    ax.set_xlabel("PC1")
    ax.set_ylabel("PC2")
    ax.set_zlabel("PC3")

    ax = fig.add_subplot(2, 3, 5, projection="3d")
    hopf = np.column_stack([
        first_numeric(df, ["hopf_fiber_phase", "berry_phase_principal"], 0.0),
        first_numeric(df, ["hopf_thread_phase", "floquet_phase"], 0.0),
        first_numeric(df, ["hopf_activity_proxy", "hopf_fieldorient_proxy", "found_coherence"], 0.0),
    ])
    hopf_scores = pca3(hopf)[idx]
    ax.scatter(hopf_scores[:, 0], hopf_scores[:, 1], hopf_scores[:, 2], c=hopf[idx, 2], cmap="turbo", s=14)
    ax.set_title("Hopf Phase / Activity Structure")
    ax.set_xlabel("fiber/thread PC1")
    ax.set_ylabel("fiber/thread PC2")
    ax.set_zlabel("activity PC3")

    ax = fig.add_subplot(2, 3, 6)
    corr = pd.DataFrame({f: numeric(df, f) for f in available}).corr().to_numpy()
    im = ax.imshow(corr, cmap="RdBu_r", vmin=-1, vmax=1)
    ax.set_title("Parameter Correlation Matrix")
    ax.set_xticks(range(len(available)))
    ax.set_yticks(range(len(available)))
    ax.set_xticklabels(available, rotation=45, ha="right", fontsize=8)
    ax.set_yticklabels(available, fontsize=8)
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    fig.savefig(out, dpi=150)
    plt.close(fig)


def output_path(csv_path: Path, page: str, out_dir: Path) -> Path:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    return out_dir / f"{csv_path.stem}_{page}_portrait_{stamp}.png"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate RDFT Hopf / Berry dashboard portrait pages.")
    parser.add_argument("csv", type=Path)
    parser.add_argument("--page", choices=["berry", "dimensional"], default="berry")
    parser.add_argument("--out-dir", type=Path, default=Path("dashboards"))
    parser.add_argument("--max-points", type=int, default=1800)
    parser.add_argument("--open", action="store_true", help="Open the generated PNG on macOS.")
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"CSV not found: {args.csv}")
        return 2

    df = pd.read_csv(args.csv)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out = output_path(args.csv, args.page, args.out_dir)

    if args.page == "berry":
        berry_page(df, out, args.max_points)
    else:
        dimensional_page(df, out, args.max_points)

    print(out)
    if args.open:
        subprocess.run(["open", str(out)], check=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
