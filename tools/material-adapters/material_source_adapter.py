#!/usr/bin/env python3
"""
Material Source Adapter for Cosmosis Visual Observatory.

Writes Processing-readable material profiles from:
- Materials Project via optional mp-api client and MP_API_KEY
- OPTIMADE provider endpoints
- JARVIS via optional jarvis-tools
- Cosmosis/RDFT run CSV files

The sketch reads the generated JSON caches; it never needs network access.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import os
import statistics
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATABASE_OUT = ROOT / "data" / "material_database_profiles.json"
COSMOSIS_OUT = ROOT / "data" / "cosmosis_run_profiles.json"


def clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


def lerp(lo: float, hi: float, t: float) -> float:
    return lo + (hi - lo) * clamp(t)


def as_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or value == "":
            return default
        return float(value)
    except Exception:
        return default


def mean(values: list[float], default: float = 0.0) -> float:
    return statistics.fmean(values) if values else default


def std(values: list[float], default: float = 0.0) -> float:
    return statistics.pstdev(values) if len(values) > 1 else default


def read_json_array(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except Exception:
        return []


def write_json_array(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(rows, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def fetch_json_url(url: str, timeout: float = 20.0) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Cosmosis-Visual-Observatory/0.1 material-source-adapter",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def upsert_profile(path: Path, profile: dict[str, Any]) -> None:
    rows = read_json_array(path)
    key = (profile.get("source_mode"), profile.get("provider"), profile.get("source_id"), profile.get("name"))
    kept = []
    for row in rows:
      other = (row.get("source_mode"), row.get("provider"), row.get("source_id"), row.get("name"))
      if other != key:
          kept.append(row)
    kept.append(profile)
    write_json_array(path, kept)


def profile_template(name: str, family: str, source_mode: str, provider: str, source_id: str) -> dict[str, Any]:
    return {
        "name": name,
        "family": family,
        "source_mode": source_mode,
        "source": provider or source_mode,
        "provider": provider,
        "source_id": source_id,
        "formula": "",
        "confidence": "partial",
        "missing_fields": "",
        "density": 1.0,
        "youngs_gpa": 1.0,
        "bulk_gpa": 1.0,
        "shear_gpa": 1.0,
        "poisson": 0.30,
        "thermal_w_mk": 1.0,
        "heat_capacity_j_kgk": 800.0,
        "band_gap_ev": 0.0,
        "dielectric": 1.0,
        "anisotropy": 0.0,
        "porosity": 0.0,
        "crystal_order": 0.5,
        "magnetic": 0.0,
        "notes": "",
    }


def missing_fields(profile: dict[str, Any], inferred: set[str]) -> str:
    physical = [
        "density", "youngs_gpa", "bulk_gpa", "shear_gpa", "poisson",
        "thermal_w_mk", "heat_capacity_j_kgk", "band_gap_ev",
        "dielectric", "anisotropy", "porosity", "crystal_order", "magnetic",
    ]
    return ",".join([k for k in physical if k in inferred])


def fetch_materials_project(formula: str, out: Path) -> None:
    try:
        from mp_api.client import MPRester  # type: ignore
    except Exception as exc:
        raise SystemExit("Materials Project mode requires `pip install mp-api`: " + str(exc))

    api_key = os.environ.get("MP_API_KEY", "")
    if not api_key:
        raise SystemExit("Materials Project mode requires MP_API_KEY in the environment.")

    fields = [
        "material_id", "formula_pretty", "density", "band_gap",
        "is_metal", "energy_above_hull", "symmetry", "volume", "nsites",
    ]
    with MPRester(api_key) as mpr:
        docs = mpr.materials.summary.search(formula=formula, fields=fields, num_chunks=1, chunk_size=1)
    if not docs:
        raise SystemExit("No Materials Project summary result for " + formula)

    doc = docs[0]
    mat_id = str(getattr(doc, "material_id", formula))
    pretty = str(getattr(doc, "formula_pretty", formula))
    density = as_float(getattr(doc, "density", 1.0), 1.0)
    band_gap = as_float(getattr(doc, "band_gap", 0.0), 0.0)
    is_metal = bool(getattr(doc, "is_metal", False))
    symmetry = getattr(doc, "symmetry", None)
    crystal_system = str(getattr(symmetry, "crystal_system", "")) if symmetry else ""

    inferred = {"youngs_gpa", "bulk_gpa", "shear_gpa", "thermal_w_mk", "heat_capacity_j_kgk", "dielectric", "anisotropy", "porosity", "magnetic"}
    profile = profile_template(pretty + " (" + mat_id + ")", "Materials Project computed material", "database", "materials_project", mat_id)
    profile.update({
        "formula": pretty,
        "density": density,
        "band_gap_ev": band_gap,
        "crystal_order": 0.92 if crystal_system else 0.78,
        "dielectric": 1.0 if is_metal else lerp(3.0, 16.0, clamp(band_gap / 6.0)),
        "youngs_gpa": lerp(35.0, 420.0, clamp(density / 9.0)),
        "bulk_gpa": lerp(25.0, 260.0, clamp(density / 10.0)),
        "shear_gpa": lerp(15.0, 180.0, clamp(density / 10.0)),
        "thermal_w_mk": 80.0 if is_metal else lerp(1.0, 150.0, clamp(density / 8.0)),
        "confidence": "partial+inferred",
        "missing_fields": ",".join(sorted(inferred)),
        "notes": "Fetched from Materials Project summary endpoint; unavailable mechanical/transport fields are inferred for visualization only.",
    })
    upsert_profile(out, profile)
    print("Wrote", profile["name"], "to", out)


def fetch_optimade(formula: str, base_url: str, out: Path) -> None:
    base_url = resolve_optimade_base(base_url)
    query = urllib.parse.urlencode({
        "filter": 'chemical_formula_reduced="' + formula + '"',
        "page_limit": "1",
    })
    url = base_url.rstrip("/") + "/v1/structures?" + query
    payload = fetch_json_url(url, timeout=20)
    data = payload.get("data", [])
    if not data:
        raise SystemExit("No OPTIMADE structure result for " + formula)
    item = data[0]
    attrs = item.get("attributes", {})
    source_id = str(item.get("id", formula))
    reduced = str(attrs.get("chemical_formula_reduced") or formula)
    elements = attrs.get("elements") or []
    nelements = as_float(attrs.get("nelements"), len(elements) or 1)
    nsites = as_float(attrs.get("nsites"), 1.0)
    inferred = {"density", "youngs_gpa", "bulk_gpa", "shear_gpa", "poisson", "thermal_w_mk", "heat_capacity_j_kgk", "band_gap_ev", "dielectric", "magnetic"}
    profile = profile_template(reduced + " (" + source_id + ")", "OPTIMADE structure profile", "database", "optimade", source_id)
    profile.update({
        "formula": reduced,
        "density": lerp(1.2, 8.0, clamp(nsites / 60.0)),
        "youngs_gpa": lerp(35.0, 260.0, clamp(nelements / 5.0)),
        "bulk_gpa": lerp(25.0, 180.0, clamp(nelements / 5.0)),
        "shear_gpa": lerp(15.0, 120.0, clamp(nelements / 5.0)),
        "anisotropy": clamp((nelements - 1.0) / 5.0),
        "crystal_order": 0.82,
        "confidence": "structure-only+inferred",
        "missing_fields": ",".join(sorted(inferred)),
        "notes": "Fetched from OPTIMADE structure endpoint; most physical properties are inferred from structure descriptors for visualization only. Base URL: " + base_url,
    })
    upsert_profile(out, profile)
    print("Wrote", profile["name"], "to", out)


def resolve_optimade_base(base_url: str) -> str:
    """Accept either a direct OPTIMADE database URL or an index/meta-db URL."""
    direct = base_url.rstrip("/")
    try:
        payload = fetch_json_url(direct + "/v1/links", timeout=12)
        for item in payload.get("data", []):
            attrs = item.get("attributes", {})
            child = attrs.get("base_url")
            if child and attrs.get("link_type") in ("child", "root"):
                return str(child).rstrip("/")
    except Exception:
        pass
    try:
        payload = fetch_json_url(direct + "/v1/info", timeout=12)
        formats = payload.get("data", {}).get("attributes", {}).get("formats", [])
        if isinstance(formats, list):
            return direct
    except Exception:
        pass
    return direct


def fetch_jarvis(formula: str, out: Path) -> None:
    try:
        from jarvis.db.figshare import data  # type: ignore
    except Exception as exc:
        raise SystemExit("JARVIS mode requires `pip install jarvis-tools`: " + str(exc))

    rows = data("dft_3d")
    match = None
    for row in rows:
        if str(row.get("formula", "")).lower() == formula.lower() or str(row.get("jid", "")).lower() == formula.lower():
            match = row
            break
    if not match:
        raise SystemExit("No JARVIS dft_3d match for " + formula)

    jid = str(match.get("jid", formula))
    pretty = str(match.get("formula", formula))
    density = as_float(match.get("density"), 1.0)
    band_gap = as_float(match.get("optb88vdw_bandgap", match.get("mbj_bandgap", 0.0)), 0.0)
    bulk = as_float(match.get("bulk_modulus_kv"), 80.0)
    shear = as_float(match.get("shear_modulus_gv"), 40.0)
    inferred = {"youngs_gpa", "poisson", "thermal_w_mk", "heat_capacity_j_kgk", "dielectric", "porosity"}
    profile = profile_template(pretty + " (" + jid + ")", "JARVIS computed material", "database", "jarvis", jid)
    profile.update({
        "formula": pretty,
        "density": density,
        "band_gap_ev": band_gap,
        "bulk_gpa": bulk,
        "shear_gpa": shear,
        "youngs_gpa": max(1.0, 9.0 * bulk * shear / max(0.001, 3.0 * bulk + shear)),
        "crystal_order": 0.92,
        "dielectric": lerp(2.0, 18.0, clamp(band_gap / 6.0)),
        "confidence": "partial",
        "missing_fields": ",".join(sorted(inferred)),
        "notes": "Fetched from JARVIS dft_3d through jarvis-tools; absent fields are inferred for visualization only.",
    })
    upsert_profile(out, profile)
    print("Wrote", profile["name"], "to", out)


def csv_column(rows: list[dict[str, str]], names: list[str]) -> list[float]:
    found = None
    lower_names = {n.lower(): n for n in rows[0].keys()} if rows else {}
    for name in names:
        if name.lower() in lower_names:
            found = lower_names[name.lower()]
            break
    if not found:
        return []
    return [as_float(row.get(found), 0.0) for row in rows if row.get(found, "") != ""]


def import_cosmosis_csv(paths: list[Path], out: Path, window: int) -> None:
    generated: list[dict[str, Any]] = []
    for path in paths:
        with path.open(newline="", encoding="utf-8", errors="replace") as handle:
            rows = list(csv.DictReader(handle))
        if not rows:
            continue
        chunks = [rows] if window <= 0 else [rows[i:i + window] for i in range(0, len(rows), window)]
        for idx, chunk in enumerate(chunks):
            alpha = mean(csv_column(chunk, ["alpha", "actual_alpha"]), 2.4)
            depth = mean(csv_column(chunk, ["depth", "actual_depth", "surface_depth"]), 5.0)
            entropy = mean(csv_column(chunk, ["entropy", "metric_entropy"]), 0.5)
            fractal = mean(csv_column(chunk, ["fractal_dim", "Df", "fractal D"]), 1.6)
            coherence = mean(csv_column(chunk, ["coherence", "found_coherence", "landauer_coherence"]), 0.5)
            floquet = mean(csv_column(chunk, ["floquet_coupling", "floquet_g_eff", "floquet_g_eff_live"]), 0.4)
            quasi = mean(csv_column(chunk, ["floquet_quasienergy", "quasi_energy", "quasiEnergy"]), 0.4)
            curvature = mean(csv_column(chunk, ["surface_curv", "berry_curvature_density", "found_rot_activity"]), 0.4)
            helicity = mean(csv_column(chunk, ["beltrami_helicity", "hopf_activity_proxy", "hopf_link_proxy"]), 0.2)
            variability = clamp(std(csv_column(chunk, ["alpha", "actual_alpha"]), 0.0) * 0.30 + std(csv_column(chunk, ["floquet_coupling"]), 0.0))

            profile = profile_template(
                path.stem + (" window " + str(idx + 1) if len(chunks) > 1 else ""),
                "Cosmosis run imprint",
                "cosmosis_csv",
                "cosmosis_csv",
                path.name + (":window-" + str(idx + 1) if len(chunks) > 1 else ""),
            )
            profile.update({
                "density": lerp(0.4, 9.0, clamp((alpha - 1.0) / 5.0)),
                "youngs_gpa": lerp(0.01, 650.0, clamp(coherence * 0.46 + floquet * 0.24 + (fractal - 1.0) / 1.55 * 0.30)),
                "bulk_gpa": lerp(0.01, 320.0, clamp(coherence * 0.42 + curvature * 0.30 + floquet * 0.28)),
                "shear_gpa": lerp(0.002, 260.0, clamp(abs(helicity) * 0.38 + curvature * 0.32 + variability * 0.30)),
                "poisson": lerp(0.08, 0.38, clamp(1.0 - variability)),
                "thermal_w_mk": lerp(0.02, 900.0, clamp(floquet * 0.55 + quasi * 0.25 + coherence * 0.20)),
                "heat_capacity_j_kgk": lerp(350.0, 1500.0, entropy),
                "band_gap_ev": lerp(0.0, 8.0, quasi),
                "dielectric": lerp(1.0, 220.0, clamp(curvature * 0.45 + quasi * 0.35 + floquet * 0.20)),
                "anisotropy": clamp(abs(helicity) * 0.50 + variability * 0.34 + curvature * 0.16),
                "porosity": clamp(entropy * 0.45 + (1.0 - coherence) * 0.35 + depth / 12.0 * 0.20),
                "crystal_order": clamp(coherence * 0.55 + (1.0 - entropy) * 0.25 + floquet * 0.20),
                "magnetic": clamp(abs(helicity) * 0.55 + curvature * 0.25 + variability * 0.20),
                "confidence": "run-imprint",
                "missing_fields": "physical_properties_are_effective_run_proxies",
                "notes": "Generated from Cosmosis/RDFT CSV dynamics. Values are effective topology-imprint properties, not direct physical material measurements.",
            })
            generated.append(profile)
    write_json_array(out, generated)
    print("Wrote", len(generated), "Cosmosis CSV profile(s) to", out)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate material profile caches for Cosmosis Visual Observatory.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    mp = sub.add_parser("materials-project")
    mp.add_argument("formula")
    mp.add_argument("--out", type=Path, default=DATABASE_OUT)

    opt = sub.add_parser("optimade")
    opt.add_argument("formula")
    opt.add_argument("--base-url", required=True)
    opt.add_argument("--out", type=Path, default=DATABASE_OUT)

    jarvis = sub.add_parser("jarvis")
    jarvis.add_argument("formula_or_jid")
    jarvis.add_argument("--out", type=Path, default=DATABASE_OUT)

    csvp = sub.add_parser("cosmosis-csv")
    csvp.add_argument("paths", nargs="+", type=Path)
    csvp.add_argument("--window", type=int, default=0, help="Rows per generated profile; 0 means one profile per file")
    csvp.add_argument("--out", type=Path, default=COSMOSIS_OUT)

    args = parser.parse_args()
    if args.cmd == "materials-project":
        fetch_materials_project(args.formula, args.out)
    elif args.cmd == "optimade":
        fetch_optimade(args.formula, args.base_url, args.out)
    elif args.cmd == "jarvis":
        fetch_jarvis(args.formula_or_jid, args.out)
    elif args.cmd == "cosmosis-csv":
        import_cosmosis_csv(args.paths, args.out, args.window)


if __name__ == "__main__":
    main()
