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
printable voxel-band shell, and optionally unions raised transport veins into
that same volume following the phase paths used in the topology preview.
Diagonal voxel contacts are bridged before triangle extraction so the resulting
cubical surface does not contain edges shared by more than two faces.

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

`relief_defined` keeps the established detailed heightfield unchanged. Its
2.0 mm base plus 9.0 mm relief range produces an 11.0 mm maximum height.
`relief_dramatic` now uses a separate volumetric contour field: 18% source
detail, 47% broad contour, and 35% silhouette interior depth. Its 2.6 mm base
plus 18.0 mm relief range produces a 20.6 mm maximum height, making the two
physical outputs measurably and visibly different.

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
triangle count. It also records source-mesh boundary, non-manifold, degenerate,
and bridge-voxel counts. STL and call-sheet export are blocked unless the source
mesh passes this manifold audit. The current extractor remains dependency-free
and draft-friendly; marching cubes or surface nets can still be added later for
smoother production surfaces.

## DCRTE-ET Milestone 0

Surface Foundry includes an opt-in compatibility layer for the
Domain-Constrained Recursive Topology Engine with Emergent Entropic Scheduling
(DCRTE-ET). Milestone 0 introduces architecture and parity diagnostics only. It
does not import domains, build signed distance fields, add intrinsic
coordinates, or run an entropic scheduler.

Milestone 0 established two pipeline selections:

- `PIPE LEGACY`: the default. Surface Foundry operates through the unchanged
  direct `topologyScalar(...)` and `foundryScalar(...)` path.
- `PIPE ADAPTER`: enables a diagnostic comparison between direct scalar calls
  and `LegacyTopologyScalarAdapter`. Mesh generation still uses the legacy
  direct path in this milestone.

Adapter mode compares both paths over the same deterministic 256-point
low-discrepancy sample set every 30 frames. The preview reports sample count,
maximum absolute error, and mean absolute error. The comparison uses no random
calls and passes at a maximum error of `1e-7` or less. Returning to
`PIPE LEGACY` disables comparison work and restores the prior runtime path.

`DCRTE_Config.pde` captures current field, topology, Surface Foundry, shaper,
and material-selection state without replacing the existing globals. It builds
a canonical, explicitly ordered representation and assigns a SHA-256
configuration ID. Surface Foundry metadata and call-sheet manifests now add:

- `dcrte_pipeline_mode`
- `dcrte_field_engine_id`
- `dcrte_field_engine_version`
- `dcrte_configuration_id`
- `dcrte_generation_path`
- `dcrte_adapter_role`
- nested `dcrte_configuration`

The metadata states `generation_path: legacy_direct` and
`adapter_role: diagnostic_only` so adapter-test provenance cannot be mistaken
for a new materialization pipeline. The canonical architecture is documented in
`docs/architecture/DCRTE_ET_ARCHITECTURE_SPEC.md`; implementation boundaries and
the Milestone 1 refactor inventory are in
`DCRTE_MILESTONE_0_IMPLEMENTATION_NOTES.md`.

## DCRTE-ET Milestone 1: Primitive Observation Domains

Milestone 1 adds a third, opt-in Surface Foundry pipeline: `PIPE DCRTE
PRIMITIVE`. In this mode, the recursive field remains unchanged. Sphere, box,
and cylinder domains act as finite observation constraints. Material is produced
only where the selected domain admits a field sample and the existing Surface
Foundry material rule classifies that sample as solid.

The field carrier and observation domain are deliberately separate:

- **Field carrier** is the selected TPMS, manifold, lattice, or fractal used by
  `foundryScalar(...)` to wrap and combine the RDFT field.
- **Observation domain** is an analytic sphere, axis-aligned box, or finite
  Y-axis cylinder that decides where samples may become material.

Changing the observation domain does not deform a finished mesh and does not
change the field equations. It creates a new finite observation of the same
field configuration.

### Primitive controls

Cycle the Surface Build pipeline button until the preview reads `DCRTE-ET
PRIMITIVE DOMAIN`. Its overlay provides clickable controls for:

- `DOMAIN`: sphere, box, or cylinder;
- `HARD INTERIOR` / `SHELL BAND` observation;
- `RES`: `32^3`, `64^3`, or `128^3` voxel-center sampling;
- domain wireframe visibility;
- inward shell thickness in voxel units;
- center-slice visibility;
- explicit `BUILD` and `VALIDATE` actions.

The normal `GENERATE MESH`, `G`, call-sheet, and STL controls dispatch through
the selected pipeline. No primitive volume is rebuilt continuously in
`draw()`. Parameter changes mark the current primitive build stale and require
an explicit rebuild.

The center slice uses separate colors for rejected samples, admitted samples,
and final solid samples. The wireframe and slice are diagnostics only; neither
is included in the STL.

### Observation behavior

The observer samples Cartesian voxel centers over `[-1, 1]^3`. Hard-interior
mode admits samples whose signed distance is at most one quarter of the minimum
voxel spacing. Shell-band mode uses the same boundary epsilon and admits only
an inward band, four voxels thick by default.

Primitive builds use flat scalar and boolean arrays as the authoritative
volume. A single adapter converts the final mask to the legacy
`boolean[][][]` representation required by the established regularizer,
call-sheet tools, and voxel-face mesher. Domain-aware cleanup resolves edge
contacts without placing material outside the admission mask.

Raised transport veins remain unchanged in `LEGACY_DIRECT`. They are suppressed
in `DCRTE_PRIMITIVE` until segment-level domain clipping is implemented. The UI,
validation warnings, call sheets, and JSON metadata distinguish requested veins
from applied veins.

### Validation and provenance

Primitive export is blocked for invalid configuration, empty output,
non-finite field values, outside-domain material, or a failed legacy
materializer audit. The panel displays admitted and final counts, domain fill,
outside-solid count, validation status, build time, and deterministic test
status.

Primitive metadata uses schema `0.4-m1` and records:

- field engine and canonical configuration ID;
- independent field carrier and observation-domain parameters;
- observer bounds, resolution, voxel-center policy, and sample volume;
- hard-interior or inward shell-band parameters;
- immediate, frame-independent scheduler;
- legacy materializer adapter and raised-vein policy;
- validation counts, analytic-volume comparison, timings, and test result.

The six standard `64^3` sphere/box/cylinder by hard/shell configurations pass
with zero outside-domain material on the development machine. The measured
matrix and implementation boundaries are recorded in
`DCRTE_MILESTONE_1_IMPLEMENTATION_REPORT.md`.

For a non-interactive regression run:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis-dcrte-m1 \
  --force --run --dcrte-m1-acceptance
```

This writes the compact report `logs/dcrte_m1_acceptance_latest.json` and exits.
Imported meshes and mesh-derived SDFs are added by Milestone 2 below. Intrinsic
coordinates, propagation, entropic scheduling, adaptive sampling, and
mechanical analysis remain outside the current implementation.

## DCRTE-ET Milestone 2: Imported Mesh Domains

Milestone 2 adds `PIPE DCRTE IMPORTED`. In this mode Surface Foundry does not
deform a recursive object to match the source STL. The source mesh is validated
and converted into a signed-distance observation domain. The recursive field is
then independently sampled, admitted by that domain, and materialized through
the existing Observation Layer, immediate scheduler, validation, voxel
materializer, preview, call-sheet, and STL export paths.

### Import workflow

1. Select `PIPE DCRTE IMPORTED` in Surface Foundry.
2. Click `LOAD STL`, or `LOAD EGG FIXTURE` for the deterministic reference ovoid.
3. Inspect watertight, manifold, orientation, boundary-edge, and non-manifold
   counts before building.
4. Use fit, quarter-turn rotation, uniform scale, and `32^3` / `64^3` / `128^3`
   resolution controls as needed.
5. Click `REBUILD SDF`. A `128^3` research build requires a second confirming
   click within ten seconds.
6. Select hard-interior or inward shell-band observation, then generate the
   material through the normal Surface Foundry controls.

Binary and common ASCII STL are supported. Source coordinates remain unitless;
the recorded transform maps them into normalized `[-1,1]^3` observation space,
while Surface Foundry output scale independently maps the result to millimeters.
The source filename, format, byte count, SHA-256, sanitation counts and
tolerances, transform, SDF algorithm and timings, observation settings, field
configuration, validation, and output scale are recorded in JSON provenance.
Full local source paths are not exported.

### Strict and preview policies

`STRICT` is required for signed SDF construction, field materialization, call
sheets, and STL export. Open, non-manifold, inconsistently oriented, or otherwise
unreliable meshes remain visible with exact diagnostics but cannot produce
material. `UNSIGNED PREVIEW` permits mesh, boundary-voxel, and unsigned-distance
inspection only. It never makes inside/outside claims and never enables export.

Sanitation is deliberately narrow: near-duplicate vertices can be merged,
degenerate or duplicate faces removed, and a valid closed mesh can receive one
global winding flip. No holes are filled, no gaps are bridged, and no source
topology is reconstructed.

### SDF and fixture

The full accepted mesh is conservatively boundary-voxelized, classified by
deterministic X-scanline parity, and converted with an exact Euclidean distance
transform over boundary voxel centers. SDF slices are available on XY, XZ, and
YZ axes with interior, boundary band, exterior, and optional final-material
overlays. Preview stride never reduces the authoritative validation or SDF mesh.

The canonical egg is a deterministic imported-domain fixture used to test an
asymmetric ovoid boundary. It is generated as a closed 12,096-triangle mesh,
written to binary STL, released, and processed through the same importer,
validator, transform, SDF, materialization, and export path as user files.

For an offline acceptance run:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis-dcrte-m2 \
  --force --run --dcrte-m2-acceptance
```

The run writes `logs/dcrte_m2_acceptance_latest.json` and exits. Measured fixture
results and architecture insertion points are documented in
`DCRTE_MILESTONE_2_IMPLEMENTATION_REPORT.md`.

## DCRTE-ET Milestone 2.5: Imported Domain Preflight

Milestone 2.5 adds a staged qualification layer around the Milestone 2 imported
mesh pipeline. It does not repair topology and does not relax any existing
export gate. Instead, it identifies the first failed stage, records all
blockers and warnings, locates representative geometry, and states which
operations remain permitted: preview, strict SDF, materialization, and export.

The fourteen stages are file, parse, geometry, topology, components,
orientation, self-intersection, transform, resolution, boundary voxelization,
inside/outside verification, signed distance, materialization, and export.
Qualification advances from `NOT_LOADED` or `PARSE_FAILED` through
`TOPOLOGY_INVALID`, `TOPOLOGY_VALID_SDF_UNRESOLVED`, `SDF_VALID`, and
`MATERIALIZATION_READY`. A warning never overrides a blocker.

### Operator workflow

1. Load an STL in `PIPE DCRTE IMPORTED`.
2. Open `PREFLIGHT`. The docked workspace replaces the normal preview while it
   is active, keeping the diagnostic model separate from the inspector. Use
   `CLOSE PREFLIGHT` to return to the standard imported-domain controls.
3. Click `RUN PREFLIGHT` after changing the source, transform, resolution, or
   invalid-domain policy.
4. Use the `SUMMARY`, `STAGES`, `ISSUES`, and `VOLUME` tabs to inspect the
   qualification handoff, all fourteen stages, filtered diagnostics, and SDF
   slices without stacking readouts over the model.
5. Cycle `OVERLAY` through selected issue, boundary loops, components,
   intersections, and sign-disagreement voxels. The Issues tab provides
   blocker, warning, and information filters plus previous/next navigation.
6. Use `EXPORT REPORT JSON` for the complete machine-readable record or
   `COPY SUMMARY` from the Issues tab for the compact operator report.
7. Use `UNSIGNED PREVIEW` only for research inspection. It never enables
   materialization or export for an untrusted domain.

The interactive sketch opens at `1600x1000` and the main Processing surface is
resizable. Command-line acceptance runs retain their noninteractive lifecycle.

Safe sanitation is reported separately and is limited to exact and
near-duplicate vertex merging at the established tolerance, degenerate and
duplicate face removal, isolated-vertex removal, and one global winding flip
for an otherwise valid closed component. Hole filling, Boolean union,
remeshing, shell thickening, component bridging, and non-manifold surgery are
not performed.

Run the deterministic preflight matrix with:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis-dcrte-m25 \
  --force --run --dcrte-m25-acceptance
```

Register a local, user-managed invalid STL as the required real-world reference
case without copying the STL into the repository:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis-dcrte-m25-reference \
  --force --run \
  "--dcrte-m25-reference=/absolute/path/to/reference.stl"
```

The commands write `logs/dcrte_m25_acceptance_latest.json` and
`logs/dcrte_reference_cases/DCRTE-M2-INVALID-EXT-001.json`. The implementation
and measured results are recorded in
`DCRTE_MILESTONE_2_5_IMPLEMENTATION_REPORT.md`.

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
