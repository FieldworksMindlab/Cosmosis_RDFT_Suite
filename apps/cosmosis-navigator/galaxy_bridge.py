#!/usr/bin/env python3
"""
galaxy_bridge.py
================
Fetches real astronomical data for four galaxy field maps, normalises
each source into the four RDFT-compatible parameters, and writes a
pre-baked JSON map file that Processing / SuperCollider load at startup.

Run once manually, or drop into a nightly cron job.

Output
------
  maps/milky_way.json
  maps/andromeda.json
  maps/hubble_deep_field.json
  maps/random_galaxy.json
  maps/manifest.json          <- timestamps + which galaxy is "random" today

Dependencies
------------
  pip install astroquery astropy numpy requests

RDFT field parameter space (all 0-1 floats)
--------------------------------------------
  field_curvature       <- stellar / mass density proxy
  floquet_coupling      <- velocity dispersion proxy (how "coupled" the orb feels)
  field_excitation    <- temperature / emission proxy
  boundary_persistence  <- dark-matter / halo stability proxy
                           (how long the shell holds without collapse)

Each map also carries a 32x32 spatial grid of field_curvature for the
Processing visualiser, plus scalar metadata for the SuperCollider OSC bridge.
"""

import json
import math
import os
import random
import sys
import time
import warnings
from datetime import datetime, timezone
from pathlib import Path

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HERE = Path(__file__).parent
MAPS_DIR = HERE / "maps"
MAPS_DIR.mkdir(exist_ok=True)
LOCAL_CONFIG_DIR = HERE / ".config"
LOCAL_CACHE_DIR = HERE / ".cache"
LOCAL_CONFIG_DIR.mkdir(exist_ok=True)
LOCAL_CACHE_DIR.mkdir(exist_ok=True)
os.environ.setdefault("XDG_CONFIG_HOME", str(LOCAL_CONFIG_DIR))
os.environ.setdefault("XDG_CACHE_HOME", str(LOCAL_CACHE_DIR))
os.environ.setdefault("ASTROPY_CONFIG_DIR", str(LOCAL_CONFIG_DIR / "astropy"))
os.environ.setdefault("ASTROPY_CACHE_DIR", str(LOCAL_CACHE_DIR / "astropy"))

import numpy as np
import requests

GRID = 32   # spatial resolution of the field curvature map

# ---------------------------------------------------------------------------
# Normalisation helpers
# ---------------------------------------------------------------------------

def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, float(v)))

def norm_log(v, v_min, v_max):
    """Log-normalise a positive physical quantity."""
    v     = max(v, 1e-12)
    v_min = max(v_min, 1e-12)
    v_max = max(v_max, v_min + 1e-12)
    return clamp((math.log10(v) - math.log10(v_min)) /
                 (math.log10(v_max) - math.log10(v_min)))

def norm_lin(v, v_min, v_max):
    if v_max <= v_min:
        return 0.0
    return clamp((v - v_min) / (v_max - v_min))

# ---------------------------------------------------------------------------
# Synthetic spatial grid builder
# Used for all sources - takes a list of (x, y, weight) point sources
# and rasterises them into a GRID x GRID density field via Gaussian blur.
# ---------------------------------------------------------------------------

def rasterise_points(points, sigma=2.5):
    """
    points: list of (norm_x, norm_y, weight)  all in [0,1]
    Returns GRID x GRID numpy array, normalised to [0,1].
    """
    grid = np.zeros((GRID, GRID), dtype=float)
    for (nx, ny, w) in points:
        cx = nx * (GRID - 1)
        cy = ny * (GRID - 1)
        for r in range(GRID):
            for c in range(GRID):
                d2 = (c - cx)**2 + (r - cy)**2
                grid[r, c] += w * math.exp(-d2 / (2 * sigma**2))
    mx = grid.max()
    if mx > 0:
        grid /= mx
    return grid

def enhance_grid(arr, gamma=0.72, floor=0.0):
    """Display-oriented contrast shaping; preserves spatial topology but avoids flat maps."""
    arr = np.asarray(arr, dtype=float)
    mn = float(arr.min())
    mx = float(arr.max())
    if mx > mn:
        arr = (arr - mn) / (mx - mn)
    arr = np.power(np.clip(arr, 0, 1), gamma)
    if floor > 0:
        arr = floor + (1.0 - floor) * arr
    return np.clip(arr, 0, 1)

def grid_to_list(arr):
    """Flatten to list-of-lists for JSON serialisation."""
    return arr.tolist()

# ---------------------------------------------------------------------------
# Canonical map schema
# ---------------------------------------------------------------------------

def make_map(name, display_name, description,
             field_curvature, floquet_coupling,
             field_excitation, boundary_persistence,
             spatial_grid,           # GRID x GRID list-of-lists
             metadata=None):
    return {
        "name": name,
        "display_name": display_name,
        "description": description,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "grid_size": GRID,
        # ── scalar RDFT parameters ──────────────────────────────────────────
        "field_curvature":      clamp(field_curvature),
        "floquet_coupling":     clamp(floquet_coupling),
        "field_excitation":   clamp(field_excitation),
        "boundary_persistence": clamp(boundary_persistence),
        # ── spatial field for the Processing visualiser ─────────────────────
        "spatial_grid": spatial_grid,
        # ── raw astronomical metadata (for display / logging) ───────────────
        "source_data": metadata or {}
    }

# ===========================================================================
# MILKY WAY
# Source: ESA Gaia DR3  via astroquery.gaia
# What we pull:  stellar density vs galactic longitude (l) in the disc plane
#                velocity dispersion proxy from radial_velocity std
#                G-band luminosity as excitation proxy
# ===========================================================================

def fetch_milky_way():
    print("  [Milky Way] Querying Gaia DR3 ...")
    try:
        from astroquery.gaia import Gaia
        import astropy.units as u

        Gaia.MAIN_GAIA_TABLE = "gaiadr3.gaia_source"
        Gaia.ROW_LIMIT = -1

        # Density grid: sample 8x8 galactic (l,b) bins across the disc
        # We count stars brighter than G<14 to approximate mass density
        density_points = []
        vel_dispersions = []

        l_bins = np.linspace(0, 350, 8)
        b_bins = np.linspace(-10, 10, 8)

        for i, l_c in enumerate(l_bins):
            for j, b_c in enumerate(b_bins):
                q = f"""
                    SELECT COUNT(*) as n,
                           AVG(phot_g_mean_mag) as mean_g,
                           STDDEV(radial_velocity) as vel_disp
                    FROM gaiadr3.gaia_source
                    WHERE l BETWEEN {l_c-20} AND {l_c+20}
                      AND b BETWEEN {b_c-2} AND {b_c+2}
                      AND phot_g_mean_mag < 14
                """
                job = Gaia.launch_job(q)
                row = job.get_results()[0]
                n = float(row["n"] or 0)
                mean_g = float(row["mean_g"] or 14)
                vd = float(row["vel_disp"] or 0)
                nx = i / 7.0
                ny = j / 7.0
                w = math.log10(max(n, 1)) / 6.0   # log-normalised count
                density_points.append((nx, ny, clamp(w)))
                vel_dispersions.append(vd)

        mean_density = np.mean([p[2] for p in density_points])
        mean_vd = float(np.nanmean(vel_dispersions))
        max_vd = 120.0   # km/s typical MW disc
        floquet = norm_lin(mean_vd, 0, max_vd)

        # MW has warm ISM ~8000K effective, old stellar pop ~5000K
        excitation = 0.42

        # NFW halo profile: MW virial mass ~1.15e12 Msun, very stable
        boundary = 0.81

        grid = rasterise_points(density_points, sigma=3.0)

        source_meta = {
            "survey": "Gaia DR3",
            "stars_sampled": "~1e9 total, density grid from G<14 sample",
            "velocity_dispersion_mean_kms": round(mean_vd, 2),
            "halo_mass_solar": 1.15e12,
            "morphology": "SB(rs)bc barred spiral",
            "diameter_kpc": 26.8,
        }

        print(f"    density={mean_density:.3f}  floquet={floquet:.3f}  "
              f"excitation={excitation:.3f}  boundary={boundary:.3f}")
        return make_map(
            "milky_way", "Milky Way",
            "Home galaxy — inside-out topology, barred spiral, Gaia DR3 stellar density",
            field_curvature=mean_density,
            floquet_coupling=floquet,
            field_excitation=excitation,
            boundary_persistence=boundary,
            spatial_grid=grid_to_list(grid),
            metadata=source_meta
        )

    except Exception as e:
        print(f"    WARNING: Gaia query failed ({e}), using parametric model")
        return _milky_way_parametric()


def _milky_way_parametric():
    """
    Fallback: analytically model the MW using published parameters.
    Exponential disc + bar + spiral arm density.
    All numbers from McMillan 2017 / Bland-Hawthorn & Gerhard 2016.
    """
    # Exponential disc: h_R = 2.6 kpc, h_z = 0.3 kpc
    # We project face-on onto a 32x32 grid centred at galactic centre
    h_R = 2.6       # kpc scale radius
    R_sun = 8.15    # kpc, Sun's galactocentric distance
    R_max = 15.0    # kpc, map edge

    # Spiral arm offsets (log-spiral, 4 arms, pitch ~13 deg)
    arm_phases = [0, math.pi/2, math.pi, 3*math.pi/2]

    density_points = []
    for r in range(GRID):
        for c in range(GRID):
            # Map grid coords to kpc
            x = (c / (GRID-1) - 0.5) * 2 * R_max
            y = (r / (GRID-1) - 0.5) * 2 * R_max
            R = math.sqrt(x**2 + y**2)
            phi = math.atan2(y, x)

            # Disc density (face-on projection)
            disc = math.exp(-R / h_R) if R < R_max else 0

            # Spiral arm boost
            arm_boost = 0
            for ap in arm_phases:
                # Log-spiral: phi_arm = (1/tan(pitch)) * ln(R/R0)
                pitch = math.radians(13)
                if R > 0.5:
                    phi_arm = ap + (1/math.tan(pitch)) * math.log(R / 3.0)
                    d_phi = abs((phi - phi_arm + math.pi) % (2*math.pi) - math.pi)
                    arm_boost += 0.6 * math.exp(-d_phi**2 / (2 * 0.15**2))

            # Central bar (±4 kpc long, ±1 kpc wide, 27 deg tilt)
            bar_angle = math.radians(27)
            x_bar = x * math.cos(bar_angle) + y * math.sin(bar_angle)
            y_bar = -x * math.sin(bar_angle) + y * math.cos(bar_angle)
            bar = 1.5 * math.exp(-(x_bar/4.0)**2 - (y_bar/1.0)**2)

            w = clamp(disc + arm_boost * disc + bar * disc)
            density_points.append((c/(GRID-1), r/(GRID-1), w))

    grid = rasterise_points(density_points, sigma=0.35)   # keep spiral/bar structure legible
    grid = enhance_grid(grid, gamma=0.68)

    return make_map(
        "milky_way", "Milky Way",
        "Home galaxy — inside-out topology, barred spiral (parametric model)",
        field_curvature=0.68,
        floquet_coupling=0.35,   # moderate MW disc velocity dispersion ~35 km/s
        field_excitation=0.42,
        boundary_persistence=0.81,
        spatial_grid=grid_to_list(grid),
        metadata={
            "survey": "Parametric (McMillan 2017 / Bland-Hawthorn 2016)",
            "h_R_kpc": h_R, "R_sun_kpc": R_sun,
            "halo_mass_solar": 1.15e12,
            "morphology": "SB(rs)bc barred spiral",
        }
    )


# ===========================================================================
# ANDROMEDA (M31)
# Source: Published structural parameters (PHAT/PHAST catalog too large for
#         a lightweight daily pull; we model from Tamm et al. 2012 + Sick 2014)
# Live query path: astroquery.ipac.ned for photometric data
# ===========================================================================

def fetch_andromeda():
    print("  [Andromeda] Querying NED for M31 photometry ...")
    try:
        from astroquery.ipac.ned import Ned

        # Get NED photometry table for M31 — gives multi-wavelength fluxes
        phot = Ned.get_table("M31", table="photometry")
        # Find IR (stellar mass proxy) and UV/X-ray (star formation / excitation)
        bands = phot["Observed Passband"].data.tolist()
        fluxes = phot["Flux Density"].data.tolist()

        ir_flux  = 0.0
        uv_flux  = 0.0
        for band, flux in zip(bands, fluxes):
            band = str(band).lower()
            if flux and not math.isnan(float(flux)):
                if "k" in band or "2.2" in band or "3.6" in band:
                    ir_flux = max(ir_flux, float(flux))
                elif "uv" in band or "galex" in band or "0.15" in band:
                    uv_flux = max(uv_flux, float(flux))

        # Normalise: M31 K-band ~10 Jy (very bright nearby galaxy)
        field_curv = norm_log(ir_flux, 0.01, 5000.0) if ir_flux > 0 else 0.72
        excitation    = norm_log(uv_flux, 1e-4, 50.0) if uv_flux > 0 else 0.38

        print(f"    ir_flux={ir_flux:.4f}  uv_flux={uv_flux:.6f}")

    except Exception as e:
        print(f"    WARNING: NED query failed ({e}), using parametric values")
        field_curv = 0.72
        excitation    = 0.38

    # M31 structural model: de Vaucouleurs bulge + exponential disc + halo
    # Tamm et al. 2012: R_eff_bulge~1 kpc, h_disc~5.8 kpc, inc=77 deg
    inc = math.radians(77)   # inclination
    pa  = math.radians(38)   # position angle
    h_disc = 5.8             # kpc
    R_bulge = 1.0            # kpc effective radius
    R_max = 40.0             # kpc

    density_points = []
    for r in range(GRID):
        for c in range(GRID):
            x = (c / (GRID-1) - 0.5) * 2 * R_max
            y = (r / (GRID-1) - 0.5) * 2 * R_max
            # Rotate by position angle
            xr =  x * math.cos(pa) + y * math.sin(pa)
            yr = -x * math.sin(pa) + y * math.cos(pa)
            # De-project inclination
            xd = xr
            yd = yr / math.cos(inc) if abs(math.cos(inc)) > 0.01 else yr
            R  = math.sqrt(xd**2 + yd**2)

            disc  = math.exp(-R / h_disc)
            bulge = math.exp(-7.67 * ((R/R_bulge)**0.25 - 1)) if R < 10 else 0

            # M31 has a prominent dust lane — slight absorption at centre
            dust = 0.6 * math.exp(-(xr**2 + (yr*4)**2) / (2 * 2.0**2))
            w = clamp(disc * 0.6 + bulge * 0.4 - dust * 0.1)
            density_points.append((c/(GRID-1), r/(GRID-1), w))

    grid = rasterise_points(density_points, sigma=0.5)

    # M31 velocity dispersion ~150 km/s (bulge), disc ~60 km/s
    floquet = norm_lin(110, 0, 200)   # weighted mean

    # M31 halo: ~1.5e12 Msun, slightly larger than MW, highly stable
    boundary = 0.84

    source_meta = {
        "survey": "NED photometry + Tamm et al. 2012 structural model",
        "distance_kpc": 765,
        "inclination_deg": 77,
        "halo_mass_solar": 1.5e12,
        "morphology": "SA(s)b grand design spiral",
        "approach_velocity_kms": -301,   # approaching! negative redshift
        "diameter_kpc": 46.56,
    }

    print(f"    field_curv={field_curv:.3f}  floquet={floquet:.3f}  "
          f"excitation={excitation:.3f}  boundary={boundary:.3f}")

    return make_map(
        "andromeda", "Andromeda (M31)",
        "Approaching neighbour — external perspective, grand design spiral, "
        "collision trajectory geometry",
        field_curvature=field_curv,
        floquet_coupling=floquet,
        field_excitation=excitation,
        boundary_persistence=boundary,
        spatial_grid=grid_to_list(grid),
        metadata=source_meta
    )


# ===========================================================================
# HUBBLE DEEP FIELD
# Source: HDF photometric catalog via Vizier/MAST
#         Modelled as a resolution gradient — near galaxies resolved,
#         far galaxies smeared into single pixels.
#         Redshift slice z=0–0.5 (resolved), z=0.5–2 (semi-resolved),
#         z=2+ (unresolved, point-like)
# ===========================================================================

def fetch_hubble_deep_field():
    print("  [Hubble Deep Field] Building redshift gradient model ...")

    # HDF-N covers ~5.3 arcmin^2.  ~3000 galaxies identified.
    # Published redshift distribution: Williams et al. 1996 + HFF
    # We synthesise realistic galaxy positions from known N(z) distribution.

    # Redshift shell parameters (z_center, count, angular_spread, brightness)
    shells = [
        # z_center  N    spread  weight (mass proxy from luminosity function)
        (0.15,     80,  0.35,   0.90),   # nearby, well resolved, massive
        (0.40,    120,  0.28,   0.75),
        (0.80,    200,  0.22,   0.60),
        (1.20,    280,  0.18,   0.45),
        (1.80,    350,  0.14,   0.32),
        (2.50,    450,  0.10,   0.22),   # Lyman-break galaxies
        (4.00,    380,  0.07,   0.14),   # high-z, point-like
        (6.00,    200,  0.05,   0.08),   # reionization era
        (9.00,     80,  0.03,   0.04),   # JWST additions
    ]

    rng = random.Random(42)    # fixed seed — same "HDF snapshot" every run
    density_points = []

    for z_c, n, spread, w_base in shells:
        for _ in range(n):
            # Cluster around random positions within the tiny HDF field
            cx = rng.gauss(0.5, 0.35)
            cy = rng.gauss(0.5, 0.35)
            x = rng.gauss(cx, spread * 0.3)
            y = rng.gauss(cy, spread * 0.3)
            # Weight falls with redshift (fainter, less mass contribution)
            w = w_base * rng.uniform(0.6, 1.0)
            density_points.append((clamp(x), clamp(y), clamp(w)))

    grid = rasterise_points(density_points, sigma=1.2)

    # Field curvature: HDF is a deep pencil beam — many structures overlapping
    field_curv = 0.58   # moderate — not a single concentrated mass

    # Velocity dispersion: mix of all redshifts, turbulent
    floquet = 0.62      # high due to cosmological peculiar velocities

    # Excitation: very hot — X-ray background, AGN, high-z star formation
    excitation = 0.74

    # Boundary persistence: NOT a single halo — many overlapping halos
    # The "boundary" here is the pencil beam geometry itself — stable as a
    # direction but not a self-sustaining shell. Different character entirely.
    boundary = 0.31

    source_meta = {
        "survey": "HDF-N (Williams et al. 1996) + HFF + JADES z-distribution",
        "field_size_arcmin2": 5.3,
        "galaxy_count_approx": 3000,
        "redshift_range": "0.05 - 12",
        "lookback_time_range_Gyr": "0.5 - 13.4",
        "note": "Resolution gradient layer — near galaxies resolved, far = point sources"
    }

    print(f"    field_curv={field_curv:.3f}  floquet={floquet:.3f}  "
          f"excitation={excitation:.3f}  boundary={boundary:.3f}")

    return make_map(
        "hubble_deep_field", "Hubble Deep Field",
        "Pencil-beam resolution gradient — 3000 galaxies across 13 Gyr of lookback time",
        field_curvature=field_curv,
        floquet_coupling=floquet,
        field_excitation=excitation,
        boundary_persistence=boundary,
        spatial_grid=grid_to_list(grid),
        metadata=source_meta
    )


# ===========================================================================
# RANDOM GALAXY
# Source: NED TAP via astroquery.ipac.ned — queries a random NGC galaxy
#         from a curated morphology pool; refreshed daily.
# Fallback pool covers structurally interesting archetypes.
# ===========================================================================

GALAXY_POOL = [
    # (name, display, morph_type, field_curv, floquet, excitation, boundary,
    #  halo_mass, description)
    ("NGC 1300",  "NGC 1300",  "SBb",  0.64, 0.41, 0.35, 0.77,
     5e11,  "Classic barred spiral — strong bar channels the orb into two lanes"),
    ("NGC 4038",  "Antennae",  "Irr",  0.82, 0.78, 0.71, 0.38,
     2e11,  "Merging pair — violently asymmetric topology, tidal tail boundaries"),
    ("NGC 1316",  "Fornax A",  "S0p",  0.71, 0.52, 0.44, 0.88,
     8e11,  "Radio galaxy — AGN jet defines a hard directional boundary"),
    ("NGC 4889",  "NGC 4889",  "E4",   0.88, 0.31, 0.29, 0.95,
     2e13,  "Massive elliptical — deep smooth potential well, near-perfect shell"),
    ("Hoag Object","Hoag Obj", "Ring", 0.45, 0.66, 0.48, 0.52,
     3e11,  "Ring galaxy — hollow core, boundary IS the ring, exotic topology"),
    ("NGC 4676",  "Mice",      "Irr",  0.77, 0.82, 0.65, 0.33,
     3e11,  "Interacting pair with long tidal tails — turbulent, asymmetric"),
    ("M87",       "M87",       "E0p",  0.91, 0.44, 0.68, 0.97,
     6e12,  "Giant elliptical with relativistic jet — boundary shaped by AGN"),
    ("NGC 6822",  "Barnard's", "IB",   0.22, 0.28, 0.31, 0.41,
     1e9,   "Dwarf irregular — weak field, sparse boundary, intimate scale"),
    ("NGC 1569",  "NGC 1569",  "IBm",  0.38, 0.55, 0.82, 0.36,
     5e8,   "Starburst dwarf — low mass but energetically intense, turbulent"),
    ("NGC 4594",  "Sombrero",  "Sa",   0.75, 0.36, 0.33, 0.89,
     8e11,  "Sombrero — dramatic dust lane splits the boundary in two"),
    ("Arp 220",   "Arp 220",   "Irr",  0.85, 0.88, 0.95, 0.55,
     3e11,  "ULIRG merger — extreme excitation excitation, chaotic topology"),
    ("NGC 5128",  "Cen A",     "S0p",  0.79, 0.58, 0.72, 0.91,
     1e12,  "Centaurus A — radio lobe boundaries extend far beyond stellar disc"),
]

def fetch_random_galaxy():
    # Pick deterministically from today's date so it changes daily
    day_index = datetime.now(timezone.utc).timetuple().tm_yday
    entry = GALAXY_POOL[day_index % len(GALAXY_POOL)]
    (name, display, morph, fc, flq, th, bp, mass, desc) = entry

    print(f"  [Random Galaxy] Today's galaxy: {display} ({morph})")

    # Try to enrich with live NED data
    try:
        from astroquery.ipac.ned import Ned
        Ned.TIMEOUT = 10
        obj = Ned.query_object(name)
        z = float(obj["Redshift"][0]) if obj["Redshift"][0] else 0
        # Adjust excitation from redshift (higher-z = less constrained energetically)
        th = clamp(th * (1 - z * 0.1))
        print(f"    NED redshift z={z:.4f}, adjusted excitation={th:.3f}")
    except Exception as e:
        print(f"    NED live query skipped ({e}), using pool values")

    # Build a morphology-appropriate spatial grid
    grid = _build_morphology_grid(morph, name)

    source_meta = {
        "survey": "NED + curated structural pool",
        "galaxy": name,
        "morphology": morph,
        "halo_mass_solar": mass,
        "day_of_year": day_index,
        "description": desc,
    }

    return make_map(
        "random_galaxy", f"Random — {display}",
        desc,
        field_curvature=fc,
        floquet_coupling=flq,
        field_excitation=th,
        boundary_persistence=bp,
        spatial_grid=grid_to_list(grid),
        metadata=source_meta
    )


def _build_morphology_grid(morph, name):
    """Generate a spatial grid appropriate for the galaxy's morphology type."""
    rng = random.Random(hash(name) % 2**32)
    pts = []

    if "Ring" in name or morph == "Ring":
        # Ring galaxy: hollow centre, density on a ring
        for i in range(400):
            theta = rng.uniform(0, 2*math.pi)
            r = rng.gauss(0.35, 0.04)   # ring at r=0.35 from centre
            x = 0.5 + r * math.cos(theta)
            y = 0.5 + r * math.sin(theta)
            pts.append((clamp(x), clamp(y), rng.uniform(0.6, 1.0)))

    elif morph.startswith("E"):   # Elliptical
        for i in range(500):
            r = abs(rng.gauss(0, 0.2))
            theta = rng.uniform(0, 2*math.pi)
            # Ellipticity from Hubble type number
        ell = int(morph[1]) if len(morph) > 1 and morph[1].isdigit() else 0
        for i in range(500):
            r = abs(rng.gauss(0, 0.18))
            theta = rng.uniform(0, 2*math.pi)
            q = 1.0 - ell * 0.1   # axis ratio
            x = 0.5 + r * math.cos(theta)
            y = 0.5 + r * math.sin(theta) * q
            w = math.exp(-r / 0.15)
            pts.append((clamp(x), clamp(y), clamp(w)))

    elif morph.startswith("SB") or "bar" in morph.lower():
        # Barred spiral
        for i in range(600):
            # Bar
            if rng.random() < 0.3:
                x = rng.gauss(0.5, 0.18)
                y = rng.gauss(0.5, 0.04)
                pts.append((clamp(x), clamp(y), 0.9))
            else:
                # Spiral arms from bar ends
                arm = rng.choice([-1, 1])
                t = rng.uniform(0, math.pi * 1.2)
                r = 0.18 + t * 0.08
                x = 0.5 + arm * (0.18 + r * math.cos(t))
                y = 0.5 + r * math.sin(t) * arm
                pts.append((clamp(x), clamp(y), clamp(0.8 - t*0.2)))

    elif morph.startswith("Irr") or "Irr" in morph:
        # Irregular — chaotic clumps
        n_clumps = rng.randint(4, 9)
        for _ in range(n_clumps):
            cx = rng.uniform(0.15, 0.85)
            cy = rng.uniform(0.15, 0.85)
            n = rng.randint(30, 80)
            for _ in range(n):
                x = rng.gauss(cx, 0.08)
                y = rng.gauss(cy, 0.08)
                pts.append((clamp(x), clamp(y), rng.uniform(0.4, 1.0)))

    else:
        # Generic spiral (S, Sa, Sb, Sc, S0)
        for i in range(600):
            if rng.random() < 0.15:   # bulge
                r = abs(rng.gauss(0, 0.06))
                theta = rng.uniform(0, 2*math.pi)
                x = 0.5 + r * math.cos(theta)
                y = 0.5 + r * math.sin(theta)
                pts.append((clamp(x), clamp(y), 0.95))
            else:                      # arms
                arm = rng.choice([0, math.pi])
                t = rng.uniform(0, math.pi * 1.5)
                r = 0.08 + t * 0.09
                x = 0.5 + r * math.cos(arm + t)
                y = 0.5 + r * math.sin(arm + t)
                pts.append((clamp(x), clamp(y), clamp(0.9 - t*0.15)))

    return enhance_grid(rasterise_points(pts, sigma=1.0), gamma=0.55)


# ===========================================================================
# MANIFEST
# ===========================================================================

def write_manifest(maps):
    manifest = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "maps": {}
    }
    for m in maps:
        manifest["maps"][m["name"]] = {
            "display_name": m["display_name"],
            "description": m["description"],
            "generated_utc": m["generated_utc"],
            "field_curvature": m["field_curvature"],
            "floquet_coupling": m["floquet_coupling"],
            "field_excitation": m["field_excitation"],
            "boundary_persistence": m["boundary_persistence"],
        }
    path = MAPS_DIR / "manifest.json"
    with open(path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"  Manifest written → {path}")


# ===========================================================================
# MAIN
# ===========================================================================

def run(targets=None):
    """
    targets: list of map names to refresh, or None for all.
    e.g.  run(["milky_way", "random_galaxy"])
    """
    all_targets = ["milky_way", "andromeda", "hubble_deep_field", "random_galaxy"]
    targets = targets or all_targets

    fetchers = {
        "milky_way":         fetch_milky_way,
        "andromeda":         fetch_andromeda,
        "hubble_deep_field": fetch_hubble_deep_field,
        "random_galaxy":     fetch_random_galaxy,
    }

    written = []
    for key in targets:
        print(f"\n── {key} ──────────────────────────────────────────")
        t0 = time.time()
        data = fetchers[key]()
        path = MAPS_DIR / f"{key}.json"
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
        elapsed = time.time() - t0
        print(f"  ✓  Written → {path}  ({elapsed:.1f}s)")
        written.append(data)

    write_manifest(written)
    print(f"\nDone. {len(written)} map(s) refreshed in {MAPS_DIR}/\n")


if __name__ == "__main__":
    # CLI: python galaxy_bridge.py [map1 map2 ...]
    # e.g: python galaxy_bridge.py milky_way random_galaxy
    targets = sys.argv[1:] if len(sys.argv) > 1 else None
    run(targets)
