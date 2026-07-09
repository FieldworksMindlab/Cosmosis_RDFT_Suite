#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
from pathlib import Path


REQUIRED_BY_VIEW = {
    "base": [["hopf_base_x"], ["hopf_base_y"], ["hopf_base_z"]],
    "phase": [
        ["hopf_fiber_phase"],
        ["hopf_thread_phase"],
        ["found_coherence", "landauer_coherence"],
        ["floquet_lock_gated", "floquet_lock_raw", "floquet_g_eff"],
        ["hopf_link_proxy", "hopf_fieldorient_proxy", "fourth_sphere_gamma", "fourth_sphere_area"],
    ],
    "pca": [["alpha"], ["depth"], ["entropy"], ["fractal_dim"]],
    "winding": [["hopf_fiber_winding"], ["hopf_thread_winding"], ["hopf_activity_proxy"]],
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an RDFT osc_state CSV for the Hopf viewer.")
    parser.add_argument("csv", type=Path)
    args = parser.parse_args()

    if not args.csv.exists():
        print(f"CSV not found: {args.csv}")
        return 2

    with args.csv.open("r", newline="") as handle:
        reader = csv.reader(handle)
        try:
            header = next(reader)
        except StopIteration:
            print(f"CSV is empty: {args.csv}")
            return 1
        row_count = sum(1 for _ in reader)

    columns = set(header)
    missing = {
        view: ["/".join(options) for options in required if not any(column in columns for column in options)]
        for view, required in REQUIRED_BY_VIEW.items()
    }
    missing = {view: cols for view, cols in missing.items() if cols}

    print(f"CSV: {args.csv}")
    print(f"Rows: {row_count}")
    print(f"Columns: {len(header)}")

    if missing:
        for view, cols in missing.items():
            print(f"Missing for {view}: {', '.join(cols)}")
        return 1

    print("Viewer columns: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
