# DCRTE-ET Milestone 2 Implementation Report

## Result

Milestone 2 adds imported STL observation domains without changing the legacy
field equations or replacing the Milestone 1 Observation Layer, scheduler,
validation, materializer, call-sheet, or export paths. The final acceptance run
on 2026-07-13 passed all 34 Milestone 2 deterministic checks, all eight M2-A
through M2-H fixture runs, all 37 Milestone 1 deterministic checks, and all six
Milestone 1 acceptance configurations.

## Existing Interfaces Extended

- `DCRTEPipelineMode` adds `DCRTE_IMPORTED_MESH`; startup remains legacy.
- `ImportedMeshDomain` implements the existing `ObservationDomain` contract and
  provides a matching-grid direct-index path.
- Existing `HardInteriorObservation` and `ShellBandObservation` perform all
  admission decisions.
- `LegacyTopologyScalarAdapter`, `ImmediateScheduler`, `DCRTEVolume`,
  `LegacyVoxelMaterializerAdapter`, and DCRTE validation remain downstream.
- Raised veins are suppressed as
  `disabled_until_imported_sdf_clipping`; legacy vein behavior is unchanged.

## Import and Sanitation

`TriangleMeshImporter` is the format-independent insertion point.
`STLMeshImporter` supports binary STL and common ASCII STL, identifies binary
files from their declared count and exact `84 + 50*n` byte layout even when the
header begins with `solid`, enforces byte and triangle limits before allocation,
rejects non-finite data, and computes SHA-256 from source bytes.

`DCRTEMeshSanitizer` uses quantized near-duplicate merging with
`max(boundsDiagonal * 1e-6, 1e-7)`, scale-related area tolerance, invalid and
degenerate face removal, duplicate triangle removal, edge-incidence inspection,
orientation checks, signed volume, and one global winding correction for an
otherwise valid inward-wound closed mesh. It performs no hole filling,
remeshing, bridging, or topology repair.

## SDF Construction

The source mesh is kept immutable. A reversible `FIT_CENTERED_UNIFORM`
transform derives world vertices with an 0.08 normalized margin and optional
quarter-turn rotations and bounded uniform scaling. Accepted full-resolution
triangles are conservatively rasterized with a half-voxel-diagonal distance
threshold. Deterministic X-axis parity scanlines classify the interior with
fixed, tiny retry offsets. A separable three-pass squared Euclidean distance
transform produces exact grid distance to the nearest boundary voxel center;
sign comes only from the parity classification. Normals are finite differences
computed on demand. Half-voxel correction is disabled and recorded.

## Acceptance Measurements

The following elapsed values cover SDF build, field sampling, materialization,
and validation after fixture import. Generated acceptance STLs and logs remain
ignored; the compact report is checked in under `docs/verification/`.

| Run | Domain / mode | Grid | Result | SDF ms | Total ms | Final solid | Outside | Volume error |
|---|---|---:|---|---:|---:|---:|---:|---:|
| M2-A | cube hard | 64 | pass | 17 | 524 | 65,156 | 0 | 0.0582 |
| M2-B | sphere hard | 64 | pass | 39 | 318 | 36,034 | 0 | 0.0905 |
| M2-C | egg hard | 64 | pass with warning | 198 | 370 | 16,420 | 0 | 0.1265 |
| M2-D | egg shell | 64 | pass with warning | 185 | 401 | 9,578 | 0 | 0.1265 |
| M2-E | egg hard | 128 | pass | 758 | 1,716 | 122,645 | 0 | 0.0618 |
| M2-F | open cube strict | 64 | rejected | - | 0 | - | - | - |
| M2-G | non-manifold strict | 64 | rejected | - | 0 | - | - | - |
| M2-H | inverted sphere hard | 64 | corrected/pass | 40 | 226 | 36,034 | 0 | 0.0905 |

All accepted runs had zero failed or ambiguous scanlines and zero non-finite SDF
samples. The 64-cubed egg exceeds the initial 0.12 volume-error warning threshold
by 0.0065; it remains below the 0.35 hard failure limit. At 128 cubed the error
falls to 0.0618 and the warning clears. The canonical egg contains 12,096 source
triangles, zero boundary edges, zero non-manifold edges, and zero orientation
errors after sanitation. The open cube reports four boundary edges. The
non-manifold fixture reports one non-manifold edge and six boundary edges. The
inverted sphere records one successful global winding flip.

Measured parser/sanitation time for the 12,096-triangle egg was 17/16 ms on the
first 64-cubed run and 5/4 ms on the 128-cubed run. These values are recorded
per source in `MeshDomainReport`; no authoritative face decimation occurred.

## Regression Results

- Adapter comparison: pass, 256 samples, maximum and mean error `0`.
- Milestone 1: 37/37 deterministic checks and 6/6 primary configurations.
- Primitive sphere, box, and cylinder: printable, zero outside material.
- Printed-cylinder shell reference: printable.
- Legacy direct mesh: printable, 38,236 triangles, zero boundary,
  non-manifold, and degenerate audit counts.
- Existing call-sheet and paired STL/JSON paths remain available.
- No existing keyboard binding was reassigned.

## Files Added

- `DCRTE_MeshData.pde`
- `DCRTE_STLImporter.pde`
- `DCRTE_MeshValidation.pde`
- `DCRTE_MeshTransform.pde`
- `DCRTE_BoundaryVoxelizer.pde`
- `DCRTE_InsideOutside.pde`
- `DCRTE_DistanceTransform.pde`
- `DCRTE_SignedDistanceVolume.pde`
- `DCRTE_ImportedMeshDomain.pde`
- `DCRTE_EggFixture.pde`
- `DCRTE_M2_Tests.pde`

The primary sketch and established DCRTE field, volume, validation,
materializer, configuration, and UI tabs receive only the imported-domain
dispatch, controls, previews, provenance, lifecycle, and export gates.

## Known Limits and Handoff

- The SDF is exact to boundary voxel centers, not exact to source triangles.
- Dense Cartesian grids can alias thin features and pointed regions.
- Builds are synchronous; 128-cubed requires explicit confirmation.
- STL coordinates are unitless and normalized; source fabrication scale is not
  inferred or preserved.
- Invalid meshes are diagnostic previews only and are not repaired.
- Only one imported domain is active at a time.

Milestone 2.1 OBJ support can be inserted as a new `TriangleMeshImporter` that
returns `TriangleMeshData`; no SDF or field code needs format logic. Milestone 3
intrinsic coordinates can be inserted between validated/transformed mesh data
and the Observation Layer as an additional coordinate description while
leaving `FieldEngine`, imported SDF admission, scheduler, and materializer
contracts intact.
