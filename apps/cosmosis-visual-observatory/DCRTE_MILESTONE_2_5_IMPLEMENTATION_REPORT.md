# DCRTE-ET Milestone 2.5 Implementation Report

## Result

Milestone 2.5 adds an imported-mesh preflight and domain-qualification layer
without replacing the Milestone 2 importer, signed-distance builder,
Observation Layer, scheduler, materializer, call-sheet path, or export path.
The final deterministic preflight run passed 13/13 checks. The retained
Milestone 1 and 2 deterministic suites also pass at application startup.

Milestone 3 intrinsic coordinates are not implemented by this milestone.

## Staged Qualification

`DomainPreflightReport` records fourteen ordered stages: file, parse, geometry,
topology, components, orientation, self-intersection, transform, resolution,
boundary voxelization, inside/outside classification, signed distance,
materialization, and export. Each stage is pass, warning, blocked, skipped, or
not run, with a reason and elapsed time.

Qualification and permission are separate. A report records one of the
defined domain states while independently gating preview, strict SDF,
materialization, and export. The first blocker is selected by stage order;
warnings cannot override blockers. A failed new load receives its own parse
report while the previously active domain remains intact.

## Diagnostics

The implementation adds standardized `PF_*` identifiers and `ACTION_*`
recommendations for:

- parse and source metadata failures;
- degenerate, duplicate, and empty geometry;
- boundary edges and measured boundary loops;
- non-manifold edges, non-manifold vertices, and bowtie neighborhoods;
- disconnected, tiny, open, overlapping, and nested components;
- inconsistent orientation and invalid component volume;
- broad-phase self-intersection candidates with exact triangle tests;
- transform clipping and observer-volume fit risk;
- low resolution and sub-voxel feature risk;
- boundary voxelization coverage and scanline coverage;
- X/Y parity disagreement, flood-fill disagreement, and inside connectivity;
- signed-distance quality, non-finite samples, and sign reliability;
- materialization and export-stage failures.

Representative loops, vertices, triangle pairs, components, and voxel indices
are retained for overlay and JSON inspection. Report output also exposes the
Milestone 3 handoff metrics, but no intrinsic-coordinate calculation consumes
them yet.

## UI and Reports

The existing imported-domain panel now opens a dedicated preflight panel. It
provides run, unsigned-preview, severity filters, issue navigation, JSON export,
summary copy, and issue/loop/component/intersection/sign-voxel overlay controls.
The panel shows qualification, permissions, ordered stages, first blocker,
diagnostic detail, and the recommended next action.

Reports are written beneath `logs/dcrte_preflight_reports/`. Generated logs are
ignored by Git; compact acceptance evidence is curated in
`docs/verification/`.

## Sanitation and Repair Boundary

Automatic sanitation remains conservative and is now itemized by exact vertex
merges, near-duplicate merges, exact duplicate faces, zero-area faces,
near-zero-area faces, isolated vertices, and global winding correction. The
source mesh remains immutable.

No hole filling, loop triangulation, Boolean union, self-intersection repair,
remeshing, shell thickening, non-manifold surgery, component bridging, or
reconstruction is performed. Invalid topology remains available for diagnostic
preview only.

## Deterministic Fixtures

The Milestone 2.5 suite covers:

| Case | Expected result |
|---|---|
| Closed cube | topology valid; SDF permitted |
| Small triangular hole | `PF_BOUNDARY_LOOP_SMALL`; strict SDF blocked |
| Large face opening | `PF_BOUNDARY_LOOP_LARGE`; strict SDF blocked |
| Bowtie vertex | non-manifold/bowtie vertex blocker |
| Intersecting shells | component or self-intersection blocker |
| Nested shells | cavity-semantics blocker |
| Thin wall | sub-voxel feature warning |
| Tiny disconnected shell | disconnected-component blocker and tiny-shell warning |

The suite also verifies safe-sanitation counts, parity/flood/SDF qualification,
materialization gating, and separate parse-attempt reporting.

## External Invalid Reference

The local case `DCRTE-M2-INVALID-EXT-001` used the generated source filename
`surface_foundry_call_sheet_20260713_230856_source.stl` without committing the
15 MB STL or its private path. Its SHA-256 is
`1b4f67943b5e1244d37948754314bed0d55c31c1889a6d1c6b47e24210c2d6b8`.

The importer passed and sanitation completed with warnings. Preflight found 53
non-manifold/bowtie vertices in one surface component, selected
`PF_NONMANIFOLD_VERTICES` as the first topology-stage blocker, supplied a
representative world location, disabled strict SDF/materialization/export, and
recommended `ACTION_REMOVE_NONMANIFOLD_GEOMETRY`. This is materially more
specific than the previous generic materialization failure.

## Files

Added:

- `DCRTE_PreflightModel.pde`
- `DCRTE_PreflightMesh.pde`
- `DCRTE_PreflightVolume.pde`
- `DCRTE_Preflight.pde`
- `DCRTE_Preflight_Tests.pde`

Extended:

- `Cosmosis_Visual_Observatory.pde`
- `DCRTE_MeshValidation.pde`
- `DCRTE_BoundaryVoxelizer.pde`
- `DCRTE_ImportedMeshDomain.pde`
- `DCRTE_MaterializerAdapter.pde`
- `DCRTE_UI.pde`

## Milestone Boundary

Milestone 2.5 ends with qualification and handoff data. A later Milestone 3 may
consume only `MATERIALIZATION_READY` domains, or an explicitly permitted
research state with stable sign and connectivity. This implementation does not
start that work.
