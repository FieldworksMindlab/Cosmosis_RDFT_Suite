# Geodesic Salon Architecture

## Purpose

Geodesic Salon is an additive workspace for deterministic geodesic dome design,
intrinsic face inspection, and modular fabrication. It does not replace or
modify the existing Surface Foundry, imported-mesh preflight, intrinsic axial
coordinates, or Milestone 4 scheduler.

Framed panel dimensions use a face-relative printable-cap policy. Operator
values define maximum frame depth, rail width, skin thickness, and portal size;
the fabrication face resolves effective values from its shortest edge and
apothem. Large panels retain the requested caps, while subdivided panels become
proportionally lighter. The requested caps remain in the manifest and the
resolved dimensions are written into the reusable-part and placement records.

## Geometry Contract

The engine supports tetrahedral, octahedral, icosahedral, dodecahedral, and
rhombic-triacontahedral seed families. Dodecahedral pentagons and rhombic
triacontahedral faces receive deterministic triangular decompositions before
entering the established barycentric subdivision path. Triangular seed families
also support an opt-in radial face-stellation modifier. Each seed triangle is
subdivided with a barycentric frequency grid, projected to the requested
radius, and deduplicated across seed-face boundaries. Faces are oriented
outward and adjacency is reconstructed from canonical vertex pairs.

A dome is produced as a panel-aligned cap. Whole geodesic faces above the
requested cut are retained, the single exposed boundary ring is identified from
edge incidence, and only that ring is planed to `cut_z`. This avoids cut-created
half-panels and preserves reusable triangle adjacency. The result must satisfy:

- no edge belongs to more than two faces;
- a full sphere has no boundary and Euler characteristic 2;
- a dome has one boundary cycle and Euler characteristic 1;
- every dome boundary vertex lies on the clipping plane.

## Intrinsic Coordinates

Every face exposes:

- stable `face_id` and `parent_seed_face`;
- barycentric coordinates `(b0, b1, b2)`;
- `s = clamp(1 - 3 min(b0,b1,b2), 0, 1)`, where the face center is 0 and an
  edge is 1;
- a local angular coordinate `theta` about the face centroid;
- a projection confidence value.

These coordinates are face-local and complement the established DCRTE axial
coordinate implementation. They do not alter Milestone 3 output contracts.

## Plateau Diagnostic

The optional Plateau overlay displays four rays in tetrahedral directions. The
pairwise target angle is `acos(-1/3)`, approximately `109.471` degrees. It is
treated as a local junction or dispersion diagnostic. It is not imposed on all
geodesic mesh edges and it is not presented as a universal face-intersection
angle.

## Fabrication Kit

Combined shells are thickened radially. Dome boundary edges are joined between
the outer and inner skins, producing a closed shell that is audited before
writing STL.

Modular panels are deduplicated by a canonical cyclic signature containing the
ordered edge geometry and mate-code pattern, resolved fabrication dimensions,
edge break, relief side, relief height, and growth mode. A representative panel
is transformed into face-local coordinates and written once per reusable type.
`INNER REINFORCEMENT` remains the default frame-and-skin construction: its
membrane occupies the inner skin band and its center relief remains below the
outer rail. `EXTERIOR CROWN` places the same closed membrane against the outer
rail face and raises its tri-meeting center outward in either growth view. Both
constructions reuse the same rail, portal, chamfer, and adjacency geometry.
Frame-and-skin panels raise their mate codes from the inward-facing membrane;
open frames raise them from the inward rail. No label geometry appears on the
exterior shell. Reciprocal shared edges receive identical raised codes and
matched portal schedules. Boundary edges are marked `RIM`. The lettering
remains clear of the mating seam. Labels use a complete rounded engineering-
stroke alphabet covering `A-Z` and `0-9`, generated directly as mesh geometry
rather than sampled raster text. Their stations are shared with the frame
triangulation so the label and panel remain a single watertight surface. KICAS
preserves the selected panel style: `FRAME + SKIN` carries its `P###` mark on
the inward membrane, while `OPEN FRAME` carries it on one inward rail and does
not add a center membrane.
The outer rail receives a capped subtle edge break.

Framed panels default to `HALF_DIHEDRAL_MITER`. For each shared edge, the
face-normal angle is divided symmetrically between the two panels. The outer
rail transitions from the face boundary to the calculated lateral inset over
the resolved frame depth; corner vertices are intersections of the adjacent
edge-offset lines rather than independent endpoint approximations. Portal
tunnels sample this same sloped profile, so their floors, ceilings, and end
walls remain closed inside the mitered rail.

The resolver retains a small printable inner-rail reserve. If a requested depth
would make the half-miter wider than the rail, depth is reduced before portal
and skin dimensions are finalized. Requested depth, resolved depth, limiting
depth, auto-cap state, half-miter angle, inset, and feasibility are all written
to kit metadata. A combination that cannot fit at the minimum fabrication
depth is rejected by atomic preflight with a face-and-edge diagnostic. The
`SQUARE_UNMITERED` strategy remains an explicit compatibility mode and is never
described as a rigid seamless joint.

An assembled-seam audit maps reciprocal local profiles back into shell space.
It gates on cross-seam separation and portal correspondence. Tangential trim
offset near a multi-face vertex is tracked separately because independently
closed convex panel corners can terminate at different stations on the same
correct shared miter line. This distinction prevents a longitudinal corner
trim from being misreported as an inverted or open dihedral.

## Paint Planning

Paint Mode is metadata and visualization layered after geometric
qualification. It never modifies the canonical uncolored part mesh. Nine
deterministic strategies assign stable `C##` identifiers to shell faces:
propagation, growth rings, spiral, adjacency weave, recursive fractal,
parent-macro geometry, RDFT field response, curvature, and harmonic bands.
Propagation uses the original three Geodesic Salon colors exactly; variable
schemes accept three through twelve IDs and a phase offset.

Legacy exports group the same reusable type by color and quantity, yielding
filenames such as `P014_C03_qty008.stl`. KICAS retains one ordered placement
per file, such as `P014_C03_qty001.stl`. The `paint_plan.json`,
`paint_schedule.csv`, and `print_batches.csv` files map face, placement, base
type, color, adjacency, and output filename. `GS-004_paint_map` is always PNG
when Paint Mode is enabled and follows the existing SVG opt-in policy.
The export folder includes:

- one audited combined STL;
- one audited STL per reusable panel type in legacy mode, or one audited,
  ordered placement STL per face in KICAS mode;
- a quantity-based bill of materials;
- a face-to-type assembly map with neighbor and placement data;
- a concise human-readable assembly guide;
- two illustrated PNG assembly guides, plus a third ordered KICAS guide when
  that mode is active, and an assembly-guide validation report;
- optional grouped SVG counterparts when the SVG control is enabled;
- optional deterministic paint plan, schedule, print batches, color-grouped
  STL aliases, and illustrated paint map;
- optional per-color generic 3MF build plates with deterministic transforms,
  quantity reconciliation, overlap checks, and package validation;
- a manifest containing geometry, field state, and audit provenance.

Legacy mode never emits an individual STL for every face; repeated panels
reference the same part type and required quantity. KICAS intentionally emits
one unique placement STL per face because each part has a placement-specific
lock role and raised interior `P###` installation mark.

## Generic 3MF Plate Kit

The `PLATE KIT` path is an additive post-export stage. It first completes the
same atomic kit preflight, canonical STL export, guide export, and paint
assignment used by `EXPORT KIT`. It then instances those already-qualified
panel meshes into printer-neutral 3MF Core packages. No alternate panel
geometry is generated for plating.

Paint-enabled kits receive one color directory per used `C##` identifier.
Paint-disabled kits receive one neutral `C00` directory. Each directory
contains one or more numbered 3MF files; a second file is created only when the
required instances for that color exceed a `256 x 256 mm` build area with
`5 mm` margins and `5 mm` part spacing. Reusable legacy panel types are stored
once as 3MF mesh resources and referenced by multiple build items. KICAS
placement-specific parts remain unique resources.

The packer is deterministic, axis-aligned, and conservative. It does not
perform slicer-dependent orientation, support generation, or nesting. It
rejects a Plate Kit success state when an expected face is missing or
duplicated, a color quantity differs from the paint plan, a resource is
invalid, a part exceeds the bed, placements overlap or leave the safe bounds,
or a 3MF package lacks required ZIP entries. `plate_manifest.json`,
`plate_schedule.csv`, and `plate_validation.json` preserve the complete
face-to-color-to-plate mapping and SHA-256 hashes.

The generated 3MF files deliberately contain no printer, filament, process,
support, or G-code configuration. Operators must select and inspect those
settings in their slicer before printing. Canonical and color-batched STLs
remain available for one-off and replacement parts.

## KICAS Assembly Contract

KICAS is additive and does not replace the legacy portal-and-mate-code path. A
deterministic breadth-first planner assigns `P001` to the seed and gives every
later placement a parent face, insertion vector, and reciprocal lock role.
Tree edges receive integral male/female slide captures. Non-tree shared edges
remain alignment relationships, and the final designated key closes the
ordered sequence.

Every triangle edge retains exactly one enlarged portal at edge station `0.5`.
The operator first seats the integral capture, then aligns the matching center
portals and may add a user-supplied zip tie for strength. Portal reinforcement
does not replace lock engagement. KICAS preserves either `FRAME + SKIN` or
`OPEN FRAME`; the latter remains rail-only with no center membrane. It enforces
inward physical placement labels, one center portal per edge, and
half-dihedral miters so the ordered parts share the same closed-manifold
fabrication rules as the rest of the Salon.

The base-geometry catalog remains available for quantities and analysis, but
its type IDs are not installation IDs. KICAS guide sheets label catalog entries
as `TYPE P###`; bare `P###` always means ordered physical placement. The third
guide, `GS-003_KICAS_sequence`, shows cumulative installation ranges,
parent/female and new/male roles, center portal reinforcement, and final key
verification.

## Illustrated Guide Contract

The assembly overview and detailed digital map consume the in-memory
`GeodesicModel` and `GeodesicPanelCatalog` used by STL, BOM, and assembly-plan
export. Quantities, type IDs, signatures, placement counts, geometry, face IDs,
and adjacency are therefore live kit data; the 44-panel design references are
not hard-coded into production output.

Six illustrative stages are generated by a deterministic breadth-first
traversal from the uppermost face. Every stage is validated as a connected
subset of the model graph, and the final stage must contain every placement.
In legacy mode this is a geometric visualization sequence, not a mechanically
qualified build order. KICAS uses the same deterministic graph foundation to
produce its explicit ordered-placement guide and records the complete parent
and insertion sequence in `assembly_plan.json`.

PNG is the baseline output. SVG is opt-in and uses named groups for page frame,
headers, panel types, stages, face map, adjacency, full assembly, notes, and
title block. The SVG carries editable vector geometry and text; the existing
Fieldworks MindLAB bitmap logo is embedded so the file remains self-contained.

The guide validation gate rejects missing catalog assignments, BOM mismatch,
invalid normals, broken or non-reciprocal adjacency, disconnected model graphs,
or disconnected stages. Separate joining hardware has a strict zero-component
contract: the generated panels may include integral portals and raised mate
codes, but clips, ties, fasteners, and connector parts remain user-supplied.
Guide annotations sit above external leader lines so neither element obscures
the illustrated panel.

## Determinism And Validation

The core acceptance suite checks seed-family counts, dodecahedral and
rhombic-triacontahedral topology, stellated topology, the frequency-2
icosahedral `V/E/F = 42/120/80` identity, the twelve five-valent icosahedral
vertices, dome clipping, shell and reusable-panel manifold audits, assembly
guide coverage, intrinsic center and edge coordinates, deterministic
fingerprints, the Plateau angle, reciprocal mate-code equality, reciprocal
portal schedules, applied and compatibility seam provenance, physical
half-dihedral slope, automatic depth limiting, ordered catalog codes, and the
maximum printable edge-break cap. KICAS coverage additionally checks
deterministic plan completeness, `faces - 1` locking pairs, exactly one portal
at the center of every edge, unique interior placement labels, reciprocal lock
roles, guide output, and manifold audits for every ordered part.
