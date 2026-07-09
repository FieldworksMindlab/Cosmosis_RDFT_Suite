# RDFT Hopf / Hyperobject Script SOP callbacks for TouchDesigner
# ==============================================================
#
# Paste this into the callbacks DAT docked to a Script SOP.
#
# It creates an open polyline from your osc_state_*.csv file using one of:
#   VIEW = "base"     -> hopf_base_x/y/z
#   VIEW = "phase"    -> phase-derived Hopf S3->S2 projection
#   VIEW = "winding"  -> hopf_fiber_winding/thread_winding/activity
#
# This version intentionally avoids pandas/numpy so it can run inside
# TouchDesigner's built-in Python more easily.
#
# Setup:
# 1. Create Script SOP.
# 2. Open its callbacks DAT.
# 3. Paste this whole file.
# 4. Edit CSV_PATH below.
# 5. Set VIEW below.
# 6. Connect Script SOP -> Null SOP -> Geometry COMP.
# 7. Add Camera, Light, Render TOP.
#
# Optional:
# Use a Trail SOP after the Script SOP, or instance small spheres onto the
# points for brighter "particle transit" marks.

import csv
import math
import os

# >>> EDIT THESE <<<
CSV_PATH = os.environ.get("RDFT_HOPF_CSV", "data/osc_state_2026-06-15_08-20-12.csv")
VIEW = "phase"      # "base", "phase", or "winding"
MAX_POINTS = 1800   # keep this reasonable for realtime TD cooking
SCALE = 8.0
CLOSED = False      # open transit line is usually better than forced closure


def _float(row, name, default=0.0):
    try:
        return float(row.get(name, default))
    except Exception:
        return default


def _read_rows(path):
    if not os.path.exists(path):
        debug("CSV not found: " + path)
        return []
    with open(path, "r", newline="") as f:
        return list(csv.DictReader(f))


def _downsample(rows, max_points):
    if len(rows) <= max_points:
        return rows
    step = float(len(rows) - 1) / float(max_points - 1)
    return [rows[int(round(i * step))] for i in range(max_points)]


def _normalize(points, scale=8.0):
    if not points:
        return []
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    zs = [p[2] for p in points]
    cx = sum(xs) / len(xs)
    cy = sum(ys) / len(ys)
    cz = sum(zs) / len(zs)

    centered = [(x - cx, y - cy, z - cz) for x, y, z in points]
    span_x = max(xs) - min(xs) if xs else 1.0
    span_y = max(ys) - min(ys) if ys else 1.0
    span_z = max(zs) - min(zs) if zs else 1.0
    span = max(span_x, span_y, span_z, 1e-9)

    return [(x / span * scale, y / span * scale, z / span * scale) for x, y, z in centered]


def _build_base(rows):
    return [
        (
            _float(r, "hopf_base_x"),
            _float(r, "hopf_base_y"),
            _float(r, "hopf_base_z"),
        )
        for r in rows
    ]


def _build_winding(rows):
    return [
        (
            _float(r, "hopf_fiber_winding"),
            _float(r, "hopf_thread_winding"),
            _float(r, "hopf_activity_proxy"),
        )
        for r in rows
    ]


def _build_phase_hopf(rows):
    # Same conceptual projection as the PyGFX viewer:
    # z1 = cos(eta) * exp(i*fiber_phase)
    # z2 = sin(eta) * exp(i*thread_phase)
    # Hopf map:
    # X = 2 Re(z1*conj(z2))
    # Y = 2 Im(z1*conj(z2))
    # Z = |z1|^2 - |z2|^2

    mixes = []
    for r in rows:
        m = (
            0.45 * _float(r, "found_coherence")
            + 0.35 * _float(r, "floquet_lock_gated")
            + 0.20 * _float(r, "hopf_link_proxy")
        )
        mixes.append(m)

    mn = min(mixes) if mixes else 0.0
    mx = max(mixes) if mixes else 1.0
    denom = max(mx - mn, 1e-9)

    pts = []
    for r, m in zip(rows, mixes):
        phase1 = _float(r, "hopf_fiber_phase")
        phase2 = _float(r, "hopf_thread_phase")
        eta = (math.pi / 2.0) * ((m - mn) / denom)

        # Use trig-expanded Hopf map to avoid complex numbers.
        # z1*conj(z2) has magnitude cos(eta)*sin(eta)
        # and phase phase1 - phase2.
        mag = math.cos(eta) * math.sin(eta)
        delta = phase1 - phase2

        x = 2.0 * mag * math.cos(delta)
        y = 2.0 * mag * math.sin(delta)
        z = math.cos(eta) ** 2 - math.sin(eta) ** 2

        pts.append((x, y, z))

    return pts


def _build_points(rows, view):
    if view == "base":
        return _build_base(rows)
    elif view == "winding":
        return _build_winding(rows)
    else:
        return _build_phase_hopf(rows)


def setupParameters(scriptOp):
    # Keeping parameters minimal because this is a paste-ready version.
    # You can replace the constants above with custom parameters later.
    return


def onPulse(par):
    return


def cook(scriptOp):
    scriptOp.clear()

    rows = _read_rows(CSV_PATH)
    rows = _downsample(rows, MAX_POINTS)
    pts = _normalize(_build_points(rows, VIEW), SCALE)

    if len(pts) < 2:
        return

    poly = scriptOp.appendPoly(len(pts), closed=CLOSED, addPoints=True)
    for i, p in enumerate(pts):
        poly[i].point.P = p

    return
