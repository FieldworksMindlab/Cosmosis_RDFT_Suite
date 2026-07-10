# Cosmosis Visual Observatory

Visual-only RDFT theory workspace inspired by the Cosmosis Navigator theory
vocabulary. This is a new project, not a migration of Cosmosis Navigator.

## Scope

- No SuperCollider.
- No BasinNET runtime.
- No Launchpad or audio routing.
- No dependency on the Cosmosis Navigator sketch folder.

## Open

Open this folder directly in Processing 4:

```bash
Cosmosis_Visual_Observatory/Cosmosis_Visual_Observatory.pde
```

The sketch uses Processing's built-in Java mode and hand-rolled UI controls.

## Workspaces

1. Field Atlas
2. Holonomy Loom
3. Phi Threshold Chamber
4. Floquet Harmonic Forge
5. CTC Window Observatory
6. Wigner Studio
7. Branes / Fibers
8. Topology Lab / Phase Atlas
9. Surface Foundry

## Controls

- Drag sliders in the left rail to reshape the shared field state.
- `DEPTH` spans `0-12`, which gives `13` recursive layers when counting the base layer.
- `DEEP DETAIL` controls how strongly deeper recursive layers survive alpha falloff.
- Use `[` and `]` to cycle the selected material target.
- Press `M` or click `MODE` to switch material source mode.
- Press `O` to open a Cosmosis/RDFT CSV run and create a run-imprint profile.
- Press `U` to reload generated database/Cosmosis material cache files.
- Press `V` or click `APPLY` to map the selected material profile into the RDFT controls.
- `1` through `9` selects a workspace.
- Press `G` in Surface Foundry to generate a printable mesh.
- Press `C` or click `CALL SHEET` in Surface Foundry to generate PNG drafting sheets, source STL, relief STLs, and metadata.
- Click `PULL SVG` or press `X` after a call sheet when you explicitly want plotter/vector SVG files for the current render strategy.
- Press `E` in Surface Foundry to export STL plus metadata JSON.
- Press `N` in Surface Foundry to cycle the geometry carrier used for field wrapping.
- `Space` pauses/resumes.
- `R` resets orbit/trails.
- `H` toggles help.
- `S` saves a frame to `exports/`.

## Material Targets

The left rail includes a material target selector with three source modes:

- `HEURISTIC`: the original local catalog in `data/material_profiles.json`.
- `DATABASE`: concrete external records cached in `data/material_database_profiles.json`.
- `COSMOSIS`: run-imprint profiles cached in `data/cosmosis_run_profiles.json`.

Press `M` or click `MODE` in the material panel to cycle these sources. Press
`O` in Cosmosis mode to open a CSV run directly from the sketch and immediately
create/apply a run-imprint profile. Press `U` to reload the generated cache
files after running an adapter.

All modes emit the same profile schema: density, stiffness, porosity,
anisotropy, dielectric response, band gap, thermal transport, crystalline order,
and magnetic character are mapped into the shared RDFT control surface.
Profiles also carry provenance fields: `source_mode`, `provider`, `source_id`,
`confidence`, and `missing_fields`. Functional targets may additionally carry
`functional_tags`, `phase_transform`, `topological_response`,
`superconducting_coherence`, and `transition_temperature_k`. These are clearly
labeled RDFT response modifiers layered on top of sourced material properties;
they are not constitutive or multiphysics simulations.

The curated database cache includes phase-distinct NiTi austenite and
martensite proxies, trigonal bismuth (`mp-23152` / `JVASP-837`), A15 Nb3Sn,
Bi2Se3, Bi2Te3, and rutile VO2. Their structure, density, electronic, dielectric,
and available elastic fields are anchored to Materials Project or NIST JARVIS
records. Missing transport fields remain listed as visualization inferences.

The heuristic mode is intentionally unchanged: fast, expressive, and approximate.
Database mode can use Materials Project, OPTIMADE providers, or JARVIS/NIST.
Cosmosis mode treats a CSV run as an observed dynamical manifold and converts
the run statistics into effective topology-imprint properties rather than direct
physical material measurements.

Generate or refresh cache files with:

```bash
# JARVIS through the OPTIMADE provider index, no API key required
./adapters/material_source_adapter.py optimade Si \
  --base-url https://providers.optimade.org/index-metadbs/jarvis

# Materials Project, requires mp-api and MP_API_KEY
MP_API_KEY=your_key ./adapters/material_source_adapter.py materials-project Si

# Exact Materials Project record
MP_API_KEY=your_key ./adapters/material_source_adapter.py materials-project --material-id mp-23152

# Exact JARVIS OPTIMADE record, no API key required
./adapters/material_source_adapter.py optimade --source-id dft_3d_JVASP-19668 \
  --base-url https://jarvis.nist.gov/optimade/jarvisdft

# JARVIS through jarvis-tools, requires jarvis-tools installed
./adapters/material_source_adapter.py jarvis Si

# Cosmosis/RDFT run imprint from one or more CSV files
./adapters/material_source_adapter.py cosmosis-csv ../RDFT_CHLADNI_SPHERE_SYNTH/osc_state_2026-06-15_08-20-12.csv

# Windowed CSV imprint, one generated profile per 500 rows
./adapters/material_source_adapter.py cosmosis-csv path/to/run.csv --window 500
```

After running an adapter, press `U` in the sketch to reload the material source
caches.

For quick interactive comparison, use `M` until the panel reads `COSMOSIS`, then
press `O` and choose any compatible Cosmosis/RDFT CSV. The sketch will parse the
selected run, append it to the in-memory Cosmosis profiles, select it, and apply
it immediately. This in-app open path is session-local; use the adapter when you
want profiles written back to `data/cosmosis_run_profiles.json`.

## Surface Foundry

Surface Foundry turns the live Topology Lab field into fabrication geometry.
The first pass samples `topologyScalar(...)` into a 3D volume, extracts a
printable voxel-band shell, and optionally adds raised transport-vein tubes
following the same phase paths used in the topology preview.

The Foundry can also wrap the RDFT field over a selected geometry carrier:

- `TPMS BLEND`
- `GYROID`
- `SCHWARZ P`
- `BELTRAMI SADDLE`
- `HOPF TORUS`
- `PETAMINX LATTICE`
- `MANDELBROT`
- `JULIA`
- `FRACTAL RIDGE`
- `SCHWARZ D`
- `NEOVIUS`
- `I-WP`
- `LIDINOID`
- `FISCHER-KOCH S`
- `SCHOEN FRD`
- `SPLIT P`
- `MENGER SPONGE`
- `MANDELBULB`

The seven added TPMS carriers are harmonic implicit surfaces evaluated by the
same RDFT field-wrapping path as the original Gyroid and Schwarz P carriers.
Menger Sponge and Mandelbulb add recursive solid/fractal alternatives. They all
feed the existing voxel sampling, preview, call-sheet, relief, and STL pipeline.

This is the visual-only counterpart to the synth's surface/topology wrapping:
the exported STL records both the active topology blend and the chosen geometry
carrier in its metadata.

Exports are written to `exports/` as:

- `surface_foundry_*.stl`
- `surface_foundry_*.json`

Call sheets are generated from the same in-memory triangle mesh used by STL
export, so they do not need to import an STL first. Press `C` or click
`CALL SHEET` directly above `EXPORT STL` to write the lightweight/default
outputs:

- `call_sheet/output/*_surface_silhouette.png`
- `call_sheet/output/*_voxel_lattice.png`
- `call_sheet/output/*_source.stl`
- `call_sheet/output/*_relief_defined.stl`
- `call_sheet/output/*_relief_dramatic.stl`
- `call_sheet/configs/*.json`

SVGs can become extremely large at high resolution. They are now generated only
when requested. After `CALL SHEET`, click `PULL SVG` or press `X` to write:

- `call_sheet/output/*_surface_silhouette.svg`
- `call_sheet/output/*_voxel_lattice.svg`

The SVG pull uses the current `TONAL LINES` or `GRAPHIC BW` render strategy and
updates the matching manifest with `svg_available: true`.

The drawing layout follows the Surface Foundry call-sheet spec: a 3 by 3
matrix of rotated orthographic isometric views, plus one large standard
isometric view on the right. `surface_silhouette` emphasizes shadowed surface
regions and bold contour-like linework; `voxel_lattice` now draws exposed voxel
cube edges plus a sampled internal lattice. `TONAL LINES` keeps the descriptive
black-line accumulation pass, while `GRAPHIC BW` switches to strict black and
white drafting with white occlusion masks, visible-shell extraction, binary
hatch regions, sparse internal structure, and a final outline pass. In voxel
mode, graphic drafting avoids solid mass fills and uses exposed voxel edges plus
controlled crosshatching so the form stays legible instead of collapsing into a
black silhouette. The large isometric view also adds orientation-based depth
bands on side-facing shell faces, which gives plotters explicit connective
tissue and layered surface cues without relying on gray values. Graphic BW uses
an adaptive illustration pass: lower mesh resolutions receive tighter hatching
and more connector cues, while higher resolutions use a lighter base lattice
with heavier side/depth contours for a sharper plotter hierarchy. The surface
silhouette path also includes a sparse spectral stipple pass: small solid black
circle clusters are placed by recursive Fourier-like bands in shadow and neck
regions, giving the drawing a controlled crackle/pointillist mass without
grayscale or opacity. SVG is the optional plotter/vector source; PNG is the
default quick preview and archive-friendly output. PDF can be layered on later
through Processing's PDF renderer if needed.

The Stochastic CAD panel lets you tune the voxel call-sheet style before
committing to file generation. `STRIDE` controls the sampled internal lattice,
`CULL` and `RAND` thin excess edges using a deterministic seed, and `SHADE`
controls how many exposed voxel faces become shadow or hatch masses. The active
CAD overlay now fills the green topology preview footprint as a yellow
holographic projection, so the preview reads at the same scale as the generated
surface.

The JSON records the material target, topology blend, RDFT controls, resolution,
iso band, model scale, raised-vein settings, stochastic CAD settings, and
triangle count. The current mesh extractor is intentionally dependency-free and
draft-friendly; a later pass can replace it with marching cubes or surface nets
for smoother production STL surfaces.

## Floquet Shaper Influence

Floquet Forge includes an optional Shaper layer. When off, the sketch behaves as
before. When on, external stream channels act as additional Floquet drive terms
that influence the recursive field, topology scalar, and Surface Foundry output.

The built-in `SIM` source procedurally animates five normalized streams:

- `solar_wind`
- `xray_flux`
- `ocean_current`
- `tide`
- `galactic_torsion`

The `SENDER` source polls `data/shaper_streams.json`, so an external Sender
bridge can overwrite that file with live API or sensor data while the sketch is
running. Values should be normalized to `0..1`; optional `mix` controls the
overall influence amount.

Run the live NOAA-backed sender from the project folder:

```bash
./senders/start_shaper_sender.sh
```

Then open Floquet Forge, switch to `SOURCE SENDER`, and turn `SHAPER ON`.

The sender writes:

- NOAA SWPC solar wind speed
- NOAA SWPC GOES X-ray flux
- NOAA CO-OPS tide/water-level dynamics
- NOAA CO-OPS water temperature
- a geomagnetic "galactic torsion" proxy derived from Bz, Kp, and sidereal phase

The torsion channel is deliberately labeled as a proxy, not a direct measured
galactic torsion stream.

Optional sender settings:

```bash
SHAPER_INTERVAL=120 ./senders/start_shaper_sender.sh
SHAPER_OCEAN_STATION=9414290 ./senders/start_shaper_sender.sh
SHAPER_SIMULATE=1 ./senders/start_shaper_sender.sh
./senders/stop_shaper_sender.sh
```

The current mapping is conceptual and instrument-like: plasma streams modulate
Floquet phase/source pressure, ocean/tide streams bend waveform continuity, and
galactic torsion perturbs the topology scalar as a slow cosmic phase/torsion
term.

## First-Pass Model

The program keeps one shared visual state: recursive field, dominant layer,
phi residual, orbit probe, holonomy loop, Floquet coefficients, particles,
and derived metrics. Each workspace renders that same state through a different
theory lens.

The recursive stack is procedural: `depth = 12` means the system is rendering
thirteen nested field layers, `0` through `12`. This is useful for finer
topological detail and fabrication experiments without claiming that each layer
is a directly proven physical dimension.

The Topology Lab is a phase atlas: it classifies the current alpha/depth field
state against topology archetypes, renders a live blended level-set cell, shows
orthogonal slices, and tracks structural proxies such as tunnel density,
surface-to-volume, curvature variance, connectedness, and genus proxy.

The CTC and Wigner views are analogical diagnostics for visual exploration,
not physical claims.
