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
10. Geodesic Salon
11. Truss Yard

## Controls

- Drag sliders in the left rail to reshape the shared field state.
- `DEPTH` spans `0-12`, which gives `13` recursive layers when counting the base layer.
- `DEEP DETAIL` controls how strongly deeper recursive layers survive alpha falloff.
- Use `[` and `]` to cycle the selected material target.
- Press `M` or click `MODE` to switch material source mode.
- Press `O` to open a Cosmosis/RDFT CSV run and create a run-imprint profile.
- Press `U` to reload generated database/Cosmosis material cache files.
- Press `V` or click `APPLY` to map the selected material profile into the RDFT controls.
- `1` through `9` selects an established workspace; `0` opens Geodesic Salon; `T` opens Truss Yard; `B` opens HBE.
- Press `G` in Surface Foundry to generate a printable mesh.
- Press `C` or click `CALL SHEET` in Surface Foundry to generate PNG drafting sheets, source STL, relief STLs, and metadata.
- Click `PULL SVG` or press `X` after a call sheet when you explicitly want plotter/vector SVG files for the current render strategy.
- Press `E` in Surface Foundry to export STL plus metadata JSON.
- Press `N` in Surface Foundry to cycle the geometry carrier used for field wrapping.
- Press `W`, or use the field control in Holonomy Loom, to cycle the Loom-owned
  field through `OFF`, `SKIN`, `VOLUME`, and `RELIEF`. `CAPTURE FOR FOUNDRY`
  freezes the exact visible field artifact used by mesh generation.
- Use the Geodesic Salon controls to rebuild domes, inspect face-local growth,
  toggle the Plateau junction diagnostic, choose `ASSEMBLY GUIDE SVG ON/OFF`,
  preview deterministic panel-color assignments, and export a deduplicated
  fabrication kit with illustrated assembly sheets.
- Click `SCHEDULER` in a DCRTE Surface Foundry pipeline to open the deterministic M4 activation lab.
- `Space` pauses/resumes.
- `R` resets orbit/trails.
- `H` toggles help.
- `S` saves a frame to `exports/`.

## Holonomy Loom Field Atlas

Holonomy Loom owns a canonical adaptive field atlas produced by its closed
adiabatic alpha/depth sweep. The atlas is visible inside the parameter loop and
again in an enlarged inspector. Phase is encoded by hue, field magnitude by
brightness, stepped cell outlines by local recursion scale, and bright seams by
the differential gradient where cell scales meet. Landmarks `A` through `D`
provide stable reference points.

`CAPTURE FOR FOUNDRY` freezes that exact atlas, including its artifact ID,
orientation, accumulated phase, recursion depths, cell spans, gradients, and
landmarks. Surface Foundry does not synthesize a second approximation. It maps
domain coordinates into the captured atlas and samples the same stored values
through the selected carrier. Generating a mesh automatically captures the live
atlas if the operator has not already done so.

- `SKIN` concentrates the woven field toward the domain boundary.
- `VOLUME` carries mixed recursion through the admitted interior.
- `RELIEF` converts half-integer recursion transitions into an explicit ridge
  channel while retaining a lower-amplitude woven field.

Sphere, box, and cylinder primitives use periodic domain-aware coordinates.
Imported meshes use intrinsic axial coordinates and parallel-transported frames
when `INTRINSIC AXIAL` is selected; Cartesian imported mode uses the periodic
spherical fallback. The exact aperiodic monotile substrate suppresses this
layer to preserve its separate recursion and audit contract.

Exports record the Loom artifact schema and SHA-256 identity, requested/applied
mode, atlas dimensions, cell-span range, recursion range, phase accumulation and
closure error, domain mapping, and landmark samples. The adaptive steps are
literal cells in the canonical parameter atlas. The fabrication mesh continues
to use its established audited uniform observer, sampling that same piecewise
field so existing regularization, manifold audits, and STL export gates remain
authoritative.

## Geodesic Salon

Geodesic Salon is a dome-first design workspace layered beside Surface Foundry.
It creates deterministic tetrahedral, octahedral, icosahedral,
dodecahedron-derived, and rhombic-triacontahedron-derived geodesic shells at
frequencies `1-12`, with either a clipped dome or complete sphere extent. The
dodecahedral and rhombic families use stable triangular decompositions of their
polygon seed faces so they can reuse the established panel and assembly
pipeline. Tetrahedral, octahedral, and icosahedral families also support an
opt-in face-stellation modifier with adjustable radial height. `STELLATION ON`
rebuilds each triangular face as three faces meeting at a new radial apex; it
changes the qualified topology, reusable part catalog, combined shell, guides,
and exported STLs rather than merely changing the preview. Dodecahedral and
rhombic seed faces remain `STELLATION N/A` because their current triangular
decompositions include support diagonals that are not original polygon edges.
Every generated face receives a stable ID, edge neighbors, a parent seed face,
barycentric coordinates, and a normalized center-to-edge coordinate.

### Fabrication Size Presets

Geodesic Salon exposes four assembled-size modes without changing the selected
family, frequency, cap, panel style, assembly method, or paint plan:

- `MICRO` resolves the smallest audited kit that still preserves the current
  minimum rail, wall, portal, skin, miter, and label requirements.
- `12 IN` resolves an assembled dome or shell that measures `304.8 mm` across
  its widest horizontal span. It is the desktop-model reference size, not a
  12-inch circumference.
- `P1S MAX` enlarges the assembled model until its limiting unique part reaches
  a conservative `246 x 246 x 246 mm` Bambu P1S-safe envelope. This preserves
  the existing 5 mm margins inside the printer's 256 mm build volume.
- `CUSTOM` preserves direct radius adjustment and reports whether the largest
  generated part fits that same P1S envelope.

The readout reports assembled diameter, limiting part ID, part dimensions, and
fit state. A preset becomes unavailable instead of weakening fabrication
features when its requested size conflicts with the current topology or panel
contract. Kit manifold, seam, portal, and 3MF package audits still run normally;
printer presets establish geometry and bed fit, not material or slicer settings.

### Aperiodic Atlas Mode

The `TOPOLOGY` control adds an isolated `APERIODIC` provider beside the
preserved `POLYHEDRAL` generator. Choose either an exact local Hat substitution
manifest or a deterministic Penrose P3 de Bruijn five-grid field. Each source
is projected through six cube-map charts onto the same qualified triangular
carrier used by the established dome fabrication pipeline. The aperiodic field
therefore controls logical tile identity, visual grouping, assembly order, and
provenance; it does not replace audited panel geometry with fragile arbitrary
polygons.

Aperiodic mode is dome-first and requires KICAS ordering. `TILE`, `CHART`,
`DISTORTION`, and `DEFECT` overlays expose the mapped structure before export.
The atlas writes `aperiodic_atlas.json`, per-placement atlas identity in
`assembly_plan.json`, and `GS-005_aperiodic_atlas.png`; SVG follows the existing
guide SVG opt-in. Complete aperiodic spheres may be visualized, but kit export
remains locked until chart-seam closure is explicitly qualified. Existing
polyhedral families and their fabrication behavior are unchanged.

The fabrication contract treats every currently visualized shell as a
fabrication problem with an explicit resolution method:

1. The complete shell must satisfy its Euler characteristic and discrete
   Gauss-Bonnet residual.
2. A sphere must have no boundary. A dome must have exactly one closed, simple
   polygonal boundary chain after exact plane clipping.
3. Shell thickness follows each vertex radially so standard and stellated
   surfaces remain closed without collapsing local crowns.
4. Shared panel rails use reciprocal half-dihedral miters computed from the
   actual adjacent face normals.
5. A kit-wide dimension resolver raises physical scale or limits rail depth
   when a requested frame cannot contain its miter, skin, portals, or minimum
   printable wall.
6. Each reusable STL receives its own manifold audit. Integral portals and
   edge chamfers remain when valid. A raised mate-code emboss that alone makes
   a panel nonmanifold is omitted only for that reusable type; its logical code
   remains mandatory in the BOM, JSON, and illustrated guides.

This separation keeps structural validity non-negotiable while allowing the
marking method to adapt to panel scale. A kit is blocked only when the shell,
seam, panel body, or clean fallback cannot be fabricated.

The two growth views are intentionally distinct:

- `OVERWRAP` advances a connected shell front over the dome.
- `CENTER > EDGE` exposes the face-local radial coordinate and adds a printable
  center relief to modular panel types.

`PLATEAU` is an optional diagnostic overlay for the tetrahedral junction angle
of approximately `109.471` degrees. It is a local junction/dispersion target,
not a claim that all geodesic edges or soap-film faces meet at that angle and
not a replacement for the intrinsic face coordinates. When bubble joining is
enabled, each shared edge also records its dihedral angle, Plateau deviation,
junction bisector, corner clearance, and symmetric portal schedule. The angle
therefore informs fabrication clearance without forcing every joint to become
a tetrahedral soap-film junction.

Panel fabrication has three selectable strategies:

- `FRAME + SKIN` creates a deep perimeter rail with a thinner center membrane.
- `OPEN FRAME` creates the rail without the center membrane.
- `SOLID` preserves the original full panel behavior.

`FRAME + SKIN` also has two relief-side treatments. `INNER REINFORCEMENT` is
the preserved default: its center-to-edge membrane rises from the panel base
but remains recessed below the outer rail. `EXTERIOR CROWN` moves the membrane
to the rail's exterior face and always raises its tri-meeting center beyond that
face, producing visible topography in both growth views while leaving rail
seams, portals, mate codes, and edge breaks unchanged. All framed kits raise
shallow mate codes from the inward-facing membrane or rail so the exterior
remains clean and the assembly labels stay inside the panel cavity. Labels use
a complete `A-Z` and `0-9` rounded engineering-stroke alphabet with printable
open counters. The strokes are generated as panel mesh geometry, not rasterized
text or a sampled image, and remain part of one watertight shell. In KICAS,
`P###` is raised on the inward membrane for `FRAME + SKIN` and on an inward rail
for `OPEN FRAME`; the latter retains a completely open center.
The setting is not applicable to `OPEN FRAME` or `SOLID`.

For framed strategies, the displayed frame, skin, and portal dimensions are
printable upper limits rather than dimensions forced onto every subdivision.
Each face resolves lighter dimensions from its shortest edge and apothem. This
keeps small high-frequency panels from becoming disproportionately deep or
thick-walled while preserving the entered dimensions on reference-scale parts.
The resolved values are recorded per reusable part and per placement in the kit
JSON files.

`PORTALS ON` cuts matched fastener tunnels into each reusable rail. Portal
positions are derived from edge length, adjacent-face dihedral, vertex
clearance, and the bubble-join policy. Each mating edge receives the same
logical compatibility code on both panels; boundary edges are marked `RIM`.
Raised interior marks are applied when the resulting reusable type remains
watertight. Types that cannot safely carry the emboss export unmarked and
declare `omitted_after_manifold_fallback_use_bom_json_guide` in their
provenance. Codes sit clear of the seam, while a capped sub-millimeter edge
break removes the printable knife edge without visibly rounding the panel. The
fabrication core accepts an ordered convex polygon boundary, so the same rail,
code, and portal construction supports triangles, pentagons, and future
mixed-face polyhedra. The current seed-family outputs remain triangulated
networks. A toroidal polyhedron is deliberately deferred because it requires a
genus-1 validation contract rather than the current sphere/disk assumptions.

`SEAM MITERED` is the default framed-panel strategy. Every shared rail receives
one reciprocal half of the adjacent-face dihedral cut, and portal floors,
ceilings, and end walls follow the same sloped profile. The two panels
therefore meet on the shared bisector plane instead of presenting parallel
square walls. `SEAM SQUARE` remains available as an explicit compatibility
mode.

Every shared edge records its face-normal angle, interior dihedral, applied
half-miter angle, required lateral inset, and dimensional-fit result. When the
requested depth would consume the available frame width, the face-relative
resolver lowers the fabrication depth while preserving the requested value in
JSON provenance. At the Plateau-like `109.471` degree interior junction, for
example, a full `13 mm` depth would require approximately `9.19 mm` of lateral
inset. The resolver retains a printable inner rail instead of emitting an
impossible bevel. If even the minimum fabrication depth cannot fit, the atomic
kit preflight blocks export and identifies the face and edge that failed.
Integral portals remain valid for ties and user-selected joining systems in
both seam modes.

The assembled-seam preflight transforms reciprocal panel profiles back into
the shell coordinate system and measures separation across each mating plane.
Cross-seam distance is the fabrication gate. Longitudinal station drift near
multi-face vertices is retained separately in the manifest as a corner-trim
diagnostic, so it cannot be mistaken for an open or inverted miter.

### Paint Mode

`PAINT ON` adds deterministic face-color planning without changing shell,
panel, miter, portal, label, or canonical STL geometry. `SCHEME <` and
`SCHEME >` cycle:

- propagation order, preserving the established teal/blue/magenta display;
- growth rings;
- spiral;
- adjacency weave;
- recursive fractal;
- parent macro geometry;
- the current RDFT field state;
- local curvature;
- harmonic bands.

`COLORS -/+` selects `3-12` print color IDs for schemes that support a variable
palette. `PHASE -/+` shifts the selected pattern. Propagation intentionally
keeps its original three colors. The viewport displays the exact assignments
that will be written; selecting a face reports both its color ID and part ID.
The same model, settings, seed, scheme, count, and phase reproduce the same
assignment plan.

### KICAS Assembly

`KICAS` means **Kinematic Integral Capture Assembly System**. It is an
optional assembly mode layered beside the preserved `LEGACY PORTAL` workflow.
The name describes the intent: panel motion is ordered and kinematic, locking
features are printed directly into the panel geometry, and each new part
captures against an already seated parent before optional tie reinforcement is
added. It creates a deterministic breadth-first installation
plan with one physical STL per shell placement. Every part carries a unique
raised interior `P###` mark; `P001` is the seed, each subsequent part names its
parent and insertion vector in `assembly_plan.json`, and the designated key part
closes the sequence.

Parent/child edges receive reciprocal integral male/female slide captures.
Alignment-only edges remain part of the same audited shell contract. Every
triangle edge also retains exactly one enlarged fastener portal at its geometric
center. The intended operation is:

1. Orient the raised `P###` mark inward.
2. Install parts in ascending `P###` order.
3. Slide the listed integral lock fully home.
4. Align the centered portals on the shared edge.
5. Add a user-supplied zip tie where reinforcement is required.

The center portal is secondary reinforcement, not a substitute for seating the
lock. KICAS preserves the selected framed construction: `FRAME + SKIN` uses
inner reinforcement, while `OPEN FRAME` remains a rail-only window. Both use
inward physical placement labels, one center portal per edge, and audited
half-dihedral miters. It does not alter legacy kit geometry or exports.

KICAS placement numbers use a three-times-size target at 100% kit scale. With
`INNER REINFORCEMENT` or `OPEN FRAME`, the raised `P###` number is placed on the
upward assembly-interior rail so it remains visible when the outward face is on
the print bed. With `EXTERIOR CROWN`, it remains on the inward membrane. The
generator fit-caps unusually small or acute panels to keep every mark inside
printable material and preserve the manifold seam contract. The existing code
height control continues to set the physical relief height of these marks.

`EXPORT KIT` writes one timestamped folder under `exports/geodesic_salon/`:

```text
YYYYMMDD_HHMMSS_icosa_f3/
  manifest.json
  bill_of_materials.json
  assembly_plan.json
  ASSEMBLY.txt
  guides/
    GS-001_assembly_overview.png
    GS-002_digital_assembly_map.png
    GS-003_KICAS_sequence.png      # KICAS only
    GS-004_paint_map.png           # PAINT ON
    guide_validation.json
    GS-001_assembly_overview.svg  # only when SVG is ON
    GS-002_digital_assembly_map.svg
    GS-003_KICAS_sequence.svg     # KICAS + SVG ON
    GS-004_paint_map.svg          # PAINT ON + SVG ON
  combined/
    geodesic_dome_combined.stl
  parts/
    P001_qtyNNN.stl
    P002_qtyNNN.stl
    ...
  paint/                          # PAINT ON
    paint_plan.json
    paint_schedule.csv
    print_batches.csv
    parts_by_color/
      C01/
        P001_C01_qtyNNN.stl
      C02/
        P001_C02_qtyNNN.stl
  print_ready/                    # PLATE KIT only
    plate_manifest.json
    plate_validation.json
    plate_schedule.csv
    C01/
      C01_plate_01.3mf
      C01_plate_02.3mf            # only when C01 exceeds one plate
    C02/
      C02_plate_01.3mf
```

Congruent panels are grouped by a canonical cyclic edge profile that preserves
the ordered mate-code pattern, portal geometry, fabrication dimensions, relief
side, and growth mode. Only one local-coordinate STL is written per reusable
panel type in legacy mode. KICAS instead writes one `P###_face_####.stl` per
ordered physical placement because its lock role and installation label are
placement-specific. The base-geometry catalog is retained for analysis and BOM
grouping but is not substituted for the ordered KICAS files.
Paint Mode leaves these canonical files unchanged. Its color folders contain
geometry-identical print batches grouped by reusable type and color in legacy
mode. KICAS writes one color-identified ordered placement per file, for example
`P014_C01_qty001.stl`. The JSON and CSV records remain the authority for
face, placement, reusable type, color ID, hex reference, neighbors, and batch
filename. `GS-004_paint_map` keeps one large isometric reference and adds
front, right, rear, left, and top model-space projections of the identical
face-color assignment, providing a visual assembly fallback when physical part
labels are unavailable or difficult to read. Each orthographic title includes
its viewing-axis sign so right and left remain unambiguous.
`PLATE KIT` performs the same qualified kit export and then adds generic,
printer-neutral 3MF build plates. Every physical panel instance is placed once,
grouped into its specified `C##` color folder, with additional numbered plates
only when that color cannot fit on one `256 x 256 mm` bed. Paint Mode OFF uses
one neutral `C00` group. Packing is deterministic and conservative: parts
remain axis-aligned with a `5 mm` bed margin and `5 mm` spacing. The package
does not embed a printer profile, filament, process, support, or G-code
settings; those remain operator decisions in the slicer. Individual reusable
and replacement-part STLs remain unchanged.

`plate_manifest.json`, `plate_schedule.csv`, and `plate_validation.json`
record every face, part ID, color ID, plate file, transform, quantity, file
hash, boundary check, and overlap check. A Plate Kit is reported successful
only when every expected panel appears exactly once, color quantities agree,
all placements are in bounds without overlap, and every 3MF ZIP contains its
required Core model entries.

The bill of materials records required quantities; the assembly plan maps every
face to its type, ordered edge codes, edge neighbors, model-space vertices,
centroid, outward normal, and bubble-aware edge-joint profiles. Its codebook
records the geometry represented by every letter. Each part and placement also
records whether its physical code was applied or replaced by the documented
logical-code fallback. The combined shell and every exported reusable part
type must pass the same boundary/nonmanifold/degenerate audit before export
proceeds.

Run the complete fabrication qualification matrix with:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_geodesic_matrix \
  --force --run --geodesic-fabrication-matrix
```

The matrix covers every current seed family in dome and sphere form at
frequencies `1`, `2`, `3`, `4`, and `6`, including standard and supported
stellated variants. Diagnostic flags can independently disable portals,
physical codes, or chamfers to isolate a failed detail strategy.

The illustrated guides are derived from that same live catalog and adjacency
graph. The overview is a concise kit reference; the digital assembly map adds
the reusable panel catalog, six connected geometric stages, face map,
orientation key, and adjacency reference. PNG guides are always written.
KICAS adds `GS-003`, a mechanically ordered sequence that distinguishes
`P###` placement IDs from base-geometry type IDs and diagrams the
lock-first/center-tie-second rule.
`ASSEMBLY GUIDE SVG ON` additionally writes editable, grouped SVG versions;
the default `OFF` state avoids unnecessary large vector files.

The guide renderer does not invent separate connectors, hubs, clips, fasteners,
or a mechanically validated construction sequence. It describes panel
placement, integral portal alignment, shared-edge topology, and outward-normal
orientation. Part labels are placed above external leader lines so neither the
text nor line obscures the panels. The builder must choose and validate hardware
appropriate to the material and use case. `guide_validation.json`
records BOM agreement, graph connectivity, reciprocal adjacency,
connected-stage checks, and a zero separate-connector component count.

For automated export verification, launch with `--geodesic-export-kit`; add
`--geodesic-guide-svg` to exercise the SVG-enabled branch. Add
`--geodesic-kicas` to exercise ordered KICAS planning, integral locks, one
center portal per edge, unique placement STLs, and the third guide. Add
`--geodesic-paint` to exercise color planning, the paint map, manifests,
schedules, and color-batched STL naming. Use
`--geodesic-export-plate-kit` instead of `--geodesic-export-kit` to add the
per-color generic 3MF plates and their validation package.

Add `--geodesic-aperiodic-hat` or `--geodesic-aperiodic-penrose` to exercise
the corresponding dome atlas, forced KICAS contract, and GS-005 export.

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

The SVG pull uses the current `TONAL` or `GRAPHIC BW` render strategy and
updates the matching manifest with `svg_available: true`.

The drawing layout follows the Surface Foundry call-sheet spec: a 3 by 3
matrix of rotated orthographic isometric views, plus one large standard
isometric view on the right. `surface_silhouette` emphasizes shadowed surface
regions and bold contour-like linework; `voxel_lattice` now draws exposed voxel
cube edges plus a sampled internal lattice. `TONAL` uses seven deterministic
depth bands from light gray to near-black, thins distant interior edges as voxel
resolution rises, and preserves the darkest/heaviest strokes for near exposed
structure. The grayscale is written as actual SVG stroke colors rather than
stacked transparency, so the bands can be mapped to plotter pens, pressure, or
media-depletion studies. `GRAPHIC BW` switches to strict black and white
drafting with white occlusion masks, visible-shell extraction, binary
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
cylinder, and physical panel domains act as finite observation constraints. Material is produced
only where the selected domain admits a field sample and the existing Surface
Foundry material rule classifies that sample as solid.

The field carrier and observation domain are deliberately separate:

- **Field carrier** is the selected TPMS, manifold, lattice, or fractal used by
  `foundryScalar(...)` to wrap and combine the RDFT field.
- **Observation domain** is an analytic sphere, axis-aligned box, finite
  Y-axis cylinder, continuous panel, or smoothly fused spheroid-cell panel that
  decides where samples may become material.

Changing the observation domain does not deform a finished mesh and does not
change the field equations. It creates a new finite observation of the same
field configuration.

### Primitive controls

Cycle the Surface Build pipeline button until the preview reads `DCRTE-ET
PRIMITIVE DOMAIN`. Its overlay provides clickable controls for:

- `DOMAIN`: sphere, box, cylinder, or panel;
- `HARD INTERIOR` / `SHELL BAND` observation;
- `RES`: `32^3`, `64^3`, or `128^3` voxel-center sampling;
- domain wireframe visibility;
- inward shell thickness in voxel units;
- center-slice visibility;
- explicit `BUILD` and `VALIDATE` actions.

### Physical panel domains

Select `DOMAIN PANEL` to open the physical panel controls. Panel width, height,
and depth are specified in millimeters. The longest dimension becomes the
Surface Foundry scale and the other axes retain their physical proportions
inside the established cubic observer, preserving isotropic voxels and carrier
geometry rather than stretching the field.

Two layouts are available:

- `CONTINUOUS` evaluates one global field/carrier observation throughout a
  rectangular panel envelope.
- `CELLS` creates a rows-by-columns array of spheroids. Each cell evaluates the
  same field in cell-local coordinates. Adjacent values blend across the two
  nearest cells, while the observation domains use a polynomial smooth union
  controlled by `OVL`. The result is one fused body with a naturally scalloped
  perimeter rather than a rectangular clipping frame.

Panel controls provide independent width, height, depth, rows, columns, and
overlap adjustments. The status line reports the nominal cubic observer and the
effective occupied voxel count along the physical panel axes. `BAND` remains
the Surface Foundry material/TPMS iso-band control; panel depth is an independent
outer-envelope dimension. `HARD INTERIOR` fills the admitted panel with field
geometry, while `SHELL BAND` restricts material generation to an inward band of
the panel or fused-cell boundary.

Panel export metadata uses schema `0.8-panel` and records the physical
dimensions, layout, grid, cell count, overlap, smooth-union blend, natural
scalloped-boundary policy, field mapping, observer, exact captured field state,
carrier, iso band, and validation results.

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

## DCRTE-ET Milestone 3: Intrinsic Axial Coordinates

Milestone 3 adds an optional coordinate layer between a qualified imported
domain and the unchanged recursive field engine. `CARTESIAN` remains the
default and preserves the Milestone 2 world-coordinate path. `INTRINSIC AXIAL`
uses a domain-derived centerline and transported frame so the same field can be
sampled by longitudinal position, normalized radius, and local polar angle.

Intrinsic construction is available only after Milestone 2.5 preflight permits
materialization. Open the full-size `PREFLIGHT` workspace and select the
`INTRINSIC` inspector tab to:

- build or reset the intrinsic coordinate volume;
- select Cartesian or intrinsic field coordinates;
- select equivalent-circular or elliptical radial normalization;
- adjust longitudinal and radial field scales;
- select the explicit fallback policy;
- display centerline, parallel-transport frames, axial slices, scalar fields,
  confidence, ambiguity, fallback, and paired result masks;
- run a Cartesian/intrinsic comparison from one frozen field configuration;
- export the intrinsic qualification report as JSON.
- reveal the current intrinsic report directly; reports are stored under
  `logs/dcrte_intrinsic_reports/`.

The initial intrinsic system is intentionally limited to one dominant,
non-branching, non-looping closed domain. Cylinder, egg, rotated egg, and bent
capsule fixtures pass. Sphere receives low-elongation diagnostics and may be
policy-blocked for mapping ambiguity. Torus, Y-branch, and disconnected paired
bodies are blocked from intrinsic axial mode while remaining available in
Cartesian mode.

Run the deterministic matrix with:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis_m3_acceptance \
  --force --run --dcrte-m3-acceptance
```

The run writes `logs/dcrte_m3_acceptance_latest.json`. Architecture, thresholds,
measured results, metadata, known limits, and future insertion points are in
`DCRTE_MILESTONE_3_IMPLEMENTATION_REPORT.md`.

The M3.1 stabilization matrix also runs the production canonical M2 egg through
the imported-mesh SDF path at `64^3` and `128^3`. Self-approach is evaluated by
comparing spatial distance with centerline arc distance, so adjacent samples on
one thick axis are not mistaken for a closed loop.

Milestone 3 does not repair invalid source meshes. Non-manifold, open,
self-intersecting, or otherwise unqualified STLs remain blocked by preflight.
Any future repair path will derive a separately identified candidate and rerun
the full qualification report rather than weakening the current gate.

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

## DCRTE Scheduler Framework

Milestone 4 adds an optional deterministic scheduler between the frozen
candidate-solid volume and the existing materializer. `IMMEDIATE` remains the
default and reproduces the static M1-M3 result. `FRONT PROPAGATION` exposes
seeded activation order, component policy, neighborhood, batch size, and field
priority without changing field candidacy.

Open Surface Foundry, select a DCRTE primitive or imported pipeline, generate a
candidate mesh, and click `SCHEDULER`. The full-preview panel provides
initialize, step, run, pause, complete, stop, materialize, metrics export, and
arrival/frontier slice controls. Advancing a schedule after materialization
marks the mesh stale until the selected state is materialized again.

The scheduler readout and run JSON compare the frozen M3 static candidate mask
with the M4 active state. Immediate completion requires zero mismatched voxels;
deterministic front completion reaches the same mask when every candidate
component is reachable. This makes milestone differences inspectable without
changing the established generation path.

See [the M4 scheduler architecture](docs/architecture/dcrte_scheduler_framework.md)
and [the implementation report](DCRTE_MILESTONE_4_IMPLEMENTATION_REPORT.md).

M4 is deterministic and makes no physical-time claim.

## DCRTE-ET Milestone 5: Emergent Entropic Scheduler

Milestone 5 adds `EMERGENT ENTROPIC` as a third scheduler mode while preserving
Immediate and Front Propagation. It evaluates exact hypothetical frontier
activations with versioned binary occupancy and field-histogram entropy models,
then applies relaxation, exploration, balanced, or adaptive score policies.
Acceptance can be deterministic threshold, deterministic top-K, or stateless
seeded stochastic.

The M5 scheduler reuses the frozen candidate snapshot, M4 seed and component
rules, frontier construction, batch commit, controller, materializer, and
export gates. It cannot mutate the recursive field or candidate mask.

The scheduler panel exposes entropy and score slices, frontier-candidate
inspection, a relational-progress and entropy history plot, cache verification,
and explicit complete, partial, stalled, and failed terminal labels. Tau is a
dimensionless cumulative measure of internal computational change, not a
physical clock.

See [the M5 entropic scheduler architecture](docs/architecture/dcrte_emergent_entropic_scheduler.md)
and [the M5 implementation report](DCRTE_MILESTONE_5_IMPLEMENTATION_REPORT.md).

## DCRTE-ET Milestone 6: Boundary-Anchored Composition

Milestone 6 adds an optional material-role layer after the scheduler and before
the existing materializer. It can preserve the qualified imported surface as an
inward fabrication shell, combine that shell with the scheduled recursive
scaffold, inset scaffold from the boundary, analyze attachment, and add
deterministic field- or domain-constrained anchor bridges.

Open the imported-domain preflight inspector and select `COMPOSITION`.
`ENVELOPE` controls composition mode, shell thickness, shell lock, source role,
clearance, role composition, materialization, and overlays. `ATTACH` controls
attachment policy, boundary seeding, bridge limits, and component analysis.
`REPORT` exposes validation, role counts, envelope fidelity, hashes, stale
state, and JSON export.

The toolbar now includes `LOAD TORUS` beside the existing STL and egg controls.
The canonical torus is written to deterministic binary STL and reimported
through the normal M2 path. Cartesian mode is supported. Intrinsic axial mode
remains blocked with `IC_CLOSED_LOOP_SUSPECTED`.

`SCAFFOLD_ONLY` is the exact M5 regression path. The shell modes require a
current qualified signed boundary, preserve locked shell voxels, and retain the
existing manifold and export gates. M6 composes material roles; it does not
deform the source mesh or mutate scheduler state.

See [the M6 boundary-anchored composition architecture](docs/architecture/dcrte_boundary_anchored_composition.md).

### M6-HX Holographic Bridge Explorer

The optional `HBE` lens adds a disabled-by-default classical experiment for
comparing candidate connectivity, scheduler-realized paths, neck bottlenecks,
mirror agreement, and frozen field/scheduler influence. It is an analogy
testbed inspired by Biswas et al. (2026), not a quantum-code, gravity, geodesic,
or physical-wormhole simulation. Existing generation paths remain exact when
the layer is disabled.

See [the M6-HX Holographic Bridge Explorer architecture](docs/architecture/dcrte_holographic_bridge_explorer.md)
and [implementation report](DCRTE_M6_HX_IMPLEMENTATION_REPORT.md).

### Aperiodic Monotile Substrate

Surface Foundry includes an optional `APERIODIC MONOTILE` carrier alongside
the existing TPMS, Hopf, and fractal geometries. Levels 1–3 expose exact hat
substitution patches containing 25, 169, and 1,156 tiles. The fixed carrier can
be blended through the normal RDFT field pipeline, while an independent
`EXPORT CONNECTED SWATCH` action creates a manifold 90 mm relief plate. One
interior tile can be left plain, raised as a visible `BUMP`, or removed as a
large `HOLE`. This geometry-only mode makes no optical, photonic, quantum,
material-response, or CRE beam-behavior claim.

See [the Aperiodic Monotile Substrate architecture and operating instructions](docs/architecture/dcrte_aperiodic_monotile.md).

## Truss Yard

Truss Yard is an additive fabrication workspace for modular masts and tunnels.
It now has two deliberately separate build modes: `TRIANGLE FRAMES` generates
reusable open triangular structural panels with one centerline-facing shared
zip-tie aperture on every edge; `SKELETON STUDY` retains the earlier octahedral
node-and-strut model as a visual structural study. Neither mode modifies a
Geodesic Salon kit. With `MATCH DOME` on, the workspace reads the live salon
scale only as a reference for a separate adapter study.

Triangle-frame portals follow a reciprocal shared-edge contract. Each mating
edge pair owns one world-space four-corner aperture. Its broad plane contains
the radial direction and the seam line, so the closed zip-tie loop lies in a
plane through the structural axis rather than producing mirrored local slots.
Both panels taper to that same opening, and export is blocked if their aperture
corners, approach orientation, or throat position do not agree.

### Section, twist, and wall folds

The cross-section is selectable: `TRIANGLE`, `SQUARE`, `PENTAGON`, `HEXAGON`,
`OCTAGON`, and `DODECAGON`. Wider sections are strongly preferred for printing.
A square section corner folds to a 90-degree interior dihedral before twist is
applied and sharper after, which drives the half-miter close to the rail-width
budget; a hexagon or octagon corner sits at 120 or 135 degrees and miters
comfortably.

Wall folds obey a geometric constraint worth stating plainly: **a twisted
segmented tube cannot be convex everywhere.** The panels above and below a bay
ring are coplanar only when consecutive rings are aligned, so any twist that is
not a whole section step leaves exactly one concave crease ring at every bay
interface — `sides x (bays - 1)` concave joints. No choice of split diagonal,
twist direction, or bay-to-bay alternation removes them. What the generator
*must* avoid is concavity beyond that floor, which the previous fixed-diagonal
split produced by always cutting each non-planar bay quad the same way.

The workspace therefore reports concave joints as *forced* versus *avoidable*,
blocks export on any avoidable concavity, and shows the nearest fully convex
twist next to the twist control. Set twist to a multiple of `360 / sides` for a
wall with no concave creases at all.

Zip-tie access side is recorded per orientation — a tunnel is entered so its
ties are threaded from the bore, while a mast is a sealed shaft that can only be
reached from outside. Only interior access is realised in geometry today: panels
are extruded along the negative face normal by the shared Geodesic Salon
fabrication mapping, and that normal also classifies joints as convex or
concave, so it cannot simply be reversed. The manifest and assembly guide mark
an unrealised access side explicitly.

### What blocks export, and what is only measured

Export is blocked on geometry that is wrong at any scale:

- **Sealed part audit** — every reusable frame STL is closed and orientable.
- **Avoidable concavity** — concave folds beyond the forced crease rings.
- **Portal pair audit** — paired apertures agree on corners, throat, and
  approach direction.
- **Cross-seam gap** — mating rail ends lie on one line within `0.05 mm`.

Everything else is measured and reported, not gated. Thresholds get set from
real builds; a gate invented ahead of the data blocked every kit once already:

- **Seam overlap** — length of shared edge over which both panels actually carry
  rail. This is the coverage measure.
- **Seam trim asymmetry** — reported because it is easy to mistake for a gap.
  It compares the two panels at the same *parameter* along their miter lines,
  and adjacent triangles legitimately trim their rail ends by different amounts,
  so equal-parameter points sit apart by exactly that difference. Values of
  several millimetres are normal and mean nothing has opened.
- **Portal depth excursion** — how far an aperture strays outside its panel's
  own depth range.
- **Fastener fit** — see below.

The portal approach direction is audited against the panel depth axis
**measured through the assembly transform that places the exported mesh**, not
against the function that built the aperture. The earlier check called that
function for both jobs, so it reported exactly zero error on every kit and could
never fail.

### Fasteners and print scale

An aperture is in model millimetres and a zip tie is a real object, so the two
only meet at a print scale. A 50 mm model mast cannot pass a 2.5 mm tie at
100% — a fact about scale, not a defect in the geometry, and scale is a slicer
decision. So the workspace reports the **minimum print scale at which the
declared stock passes** and never blocks on it.

Declared stock defaults to a `2.5 x 1.0 mm` tie with `0.35 mm` clearance; set
`trussZipTieWidthMM`, `trussZipTieThicknessMM`, and `trussZipTieClearanceMM` to
match what you have. The readout and TY-001's fastening schedule both print the
required scale, the tightest portal, and the joint that sets it.

### Auditing an exported kit

`tools/truss_audit.py` re-derives every gate from the exported STLs and assembly
plan rather than trusting the manifest the sketch writes about itself:

```bash
python3 tools/truss_audit.py exports/truss_yard/<stamp>_octa_<label>_b<n>
```

It reports per-part manifoldness, true congruence classes at print tolerance
(so duplicate part numbers for one physical shape are caught), the forced versus
avoidable concavity split, cross-seam gap, seam overlap against rail width, and
which side each portal actually presents to. It exits non-zero on failure.

### Assembly call sheets

Every `TRIANGLE FRAMES` export writes its own call sheets into
`<folder>/call_sheets/`, as PNG and SVG, exactly as the dome guides do. They are
drawn with the same canvas primitives as the Geodesic Salon guides, which now
take a page size so a portrait sheet can share them; the landscape defaults
leave dome output unchanged.

`tools/truss_call_sheet.py` renders the same two sheets offline from the
`assembly_plan.json`, `manifest.json`, and `bill_of_materials.json` of any
existing export, which is useful for kits exported before the sheets existed:

```bash
python3 tools/truss_call_sheet.py exports/truss_yard/<folder>
```

Two A2 sheets, in the same technical-drawing
language as the Geodesic Salon guides — black on white, double page frame, ruled
section headers, Fieldworks MindLAB title block. They are **portrait** where the
dome sheets are landscape, because a mast or tunnel is long on one axis and
wastes most of a landscape page.

- `TY-001_assembly_overview.svg` — isometric elevation (turned so the structure's
  axis runs down the page), build data, fastening schedule, part catalog, wall
  fold accounting, station key, and dimensioned flat plates of every panel type
  so a printed part can be identified in the hand.
- `TY-002_wall_development.svg` — the tube wall unrolled flat about its axis,
  with every panel's part and face number, every shared joint marked at its
  actual tie point (filled for a concave crease, open for a convex joint), and a
  joint schedule grouped by distinct geometry rather than listing every joint.

Output is SVG with the logo embedded, so the sheets are self-contained and print
at any size.

### Printing a mast or tunnel as one solid

The assembly preview is a correct but self-intersecting pile of individually
closed panels, which is fine to look at and wrong to print: a slicer filling
that pile by the even-odd rule treats double-covered overlap as *outside* and
can hollow out the seams.

`PULL UNION + KIT` exports the full kit **and**
`triangulated_frame_<label>_watertight_union.stl` — one watertight solid unioned
from the placed panels, produced by `Truss_Union.pde`. `EXPORT TRUSS` skips it,
because the union is a large file and most exports do not want one.

The union samples the preview's **non-zero winding number** on a regular grid,
which is the part that makes overlapping panels count as solid instead of
cancelling, then extracts the boundary with surface nets.

**Watertight here means no holes _and_ no non-manifold edges.** Surface nets
places one vertex per group of solid corners in a cell, but the surface crossing
that cell has one sheet per (solid group, empty group) pair. Where there are
more sheets than vertices, one vertex serves two sheets and the mesh pinches
into an edge with four incident faces — which slicers reject even though there
is no hole. Those cells are filled solid before extraction, which costs at most
one voxel of material at a handful of pinch points. Splitting them into separate
vertices instead was measured tearing roughly 2500 holes, which is far worse.

`tools/truss_union.py` runs the identical algorithm offline on any export:

```bash
python3 tools/truss_union.py exports/truss_yard/<folder> --voxel 0.5
```

The two implementations are kept byte-for-byte equivalent in behaviour — same
grid, same triangle count, same volume — so the tool is a faithful preview of
what the sketch writes. Any change to one belongs in both.

**Authority.** The parts in `parts/` remain the fabrication authority; print
those to *assemble* a truss. The union is the render authority: print it when
you want the mast or tunnel as a single body. It is deliberately never added to
the sealed component list, so it cannot influence the audit that gates export.

Sampling defaults to `0.55 mm` (`trussUnionVoxelMM`), coarsened automatically if
a long mast would exceed the cell budget, so an export cannot run away on
memory.

Two notes on what "watertight" means here. The output is **closed**: no holes,
no flipped faces, positive volume. It is not always strictly 2-manifold; a cell
carrying two sheets of surface can leave an edge with four incident faces. The
tool reports that pinch count separately. Splitting those cells fully does
produce a 2-manifold mesh but tears thousands of holes in the process, and a
slicer tolerates pinch edges while holes defeat it, so closure is the gate.

Resolution is a straight trade: `--voxel 0.6` is a good default, smaller values
capture the portal slots more crisply at roughly cubic cost in time and
triangles. `--smooth` sets Laplacian relaxation passes, each clamped inside its
own cell so the surface cannot migrate across a rail and pinch it off.

Triangle-frame rail ends now use reciprocal half-dihedral miters. The two
panels sharing an edge derive complementary signed miter faces from the same
assembled dihedral, rather than receiving isolated square cuts. A world-space
cross-seam audit measures the resulting fit and blocks export above `0.05 mm`.
This is the printable seam authority used by both panel modes:

- `PANEL: OPEN FRAME` exports rail-only triangular frames for open-air tunnel,
  mast, and scaffold structures.
- `PANEL: EXTERIOR MEMBRANE` adds a continuous outward skin for enclosed
  corridors while preserving the same frame, miter, and centered-portal
  geometry. It is airtight-ready, not automatically pressure-tight: printed
  seams and portal penetrations must still be sealed for the intended service.

`EXPORT TRUSS` creates a timestamped folder under `exports/truss_yard/`:

- In `TRIANGLE FRAMES`, `parts/` contains individually audited reusable
  `FRAME_P###` STLs and `assembly_plan.json` maps each face placement to its
  printable frame type. The plan includes reciprocal joint IDs, neighbor face
  IDs, edge indices, portal stations, world-space portal centers, signed miter
  classes, half-dihedral angles, and seam-audit results. Assemble matching
  shared joints panel-to-panel through their centered portals with zip ties.
- In `SKELETON STUDY`, `parts/` contains individually audited reusable
  `TRUSS_DIAGONAL`, `TRUSS_RING`, and `TRUSS_NODE` STLs, with optional adapter
  arm/root parts.
- `bill_of_materials.json` and `ASSEMBLY.txt` record reusable quantities and
  the current build dimensions.
- `manifest.json` records the field state, match reference, and audit state.
- The `*_assembly_preview.stl` is an intentionally intersecting visual
  aggregate for orientation only; printable authority always remains with the
  individually audited reusable parts.

The current first-pass adapter establishes scale and attachment intent between
the two systems. Dedicated dome-interface standards, boolean-unioned
assemblies, and specialty truss families can be added later without changing
the qualified Geodesic Salon panel pipeline.

## Meta-Crystal carrier

Surface Foundry includes an isolated `META-CRYSTAL` carrier based on the
explicit BCC/BCCT geometry and grain recipes reported in
[Tuning the mechanical behaviour of additively manufactured metamaterials](https://arxiv.org/abs/2410.07833).
It does not replace or alter any earlier carrier. Select it with the existing
`GEOM` controls to expose its own compact instrument block.

Available families are `BCC CONTROL`, `BCCT`, `META-GRAIN`, and
`META-HARMONIC`. The paper-derived recipes are `G44`, `G2222`, `G1x8`,
`G242`, `G11411`, and `G112211`. `THETA` changes the BCCT twinning angle;
`STRUT` changes normalized member radius; `LOAD AXIS` changes the geometric
alignment readout. The four views separate raw geometry, grain identity,
load-path alignment, and localization-risk cues.

`PAPER REPLICA` is the default and materializes the explicit graph without a
field deformation. `RDFT COUPLED` is an opt-in exploratory thickness
modulation. It is intentionally labeled experimental so it cannot be confused
with a result reported by the paper. The on-screen axial and risk values are
geometry proxies, not finite-element predictions or measured properties.

`EXPORT GRAPH` writes `nodes.csv`, `edges.csv`, and `manifest.json` beneath
`exports/meta_crystal/`. Surface Foundry STL and call-sheet exports also embed
the family, recipe, angle, load axis, coupling mode, source reference, and an
explicit unvalidated-mechanics notice. For useful voxelized struts, use at
least `72^3` resolution; higher resolution improves thin-member fidelity.

Developer verification:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" --output=/tmp/cosmosis_meta --force --run \
  --dcrte-meta-crystal-tests-only
```
