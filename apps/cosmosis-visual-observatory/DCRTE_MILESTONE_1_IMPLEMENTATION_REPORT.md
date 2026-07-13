# DCRTE-ET Milestone 1 Implementation Report

## Result

Milestone 1 adds analytic primitive observation domains to Surface Foundry as
an opt-in layer. The legacy direct path and Milestone 0 adapter-test path remain
available. Processing 4.5.2 compiled the completed sketch, all 37 deterministic
fixtures passed, and all six required `64^3` acceptance configurations produced
printable meshes with zero outside-domain material.

## Milestone 0 Mapping

The implemented Milestone 0 names are retained:

| Architecture role | Implemented symbol | Location |
| --- | --- | --- |
| Field interface | `FieldEngine` | `DCRTE_Field.pde` |
| Legacy field adapter | `LegacyTopologyScalarAdapter` | `DCRTE_Field.pde` |
| Configuration snapshot | `DCRTEConfig` / `captureDcrteConfig()` | `DCRTE_Config.pde` |
| Pipeline selector | `DCRTEPipelineMode` | `DCRTE_Field.pde` |
| Adapter diagnostics | `DCRTEAdapterDiagnostics` | `DCRTE_Field.pde` |
| Metadata hook | `appendDcrteMetadata()` | `DCRTE_Config.pde` |

## Existing Boundaries Reused

- Legacy volume generation remains `generateSurfaceFoundryMesh()`.
- The existing candidate rule remains `abs(foundryScalar(...)) < foundryIsoBand`.
- The legacy spherical crop remains only in `LEGACY_DIRECT`.
- Existing recursive field functions remain `foundryScalar(...)` and
  `topologyScalar(...)`.
- Existing connectivity repair remains `regularizeFoundrySolid(...)`.
- Existing voxel extraction remains `addVoxelBoundaryFaces(...)`.
- Existing mesh audit remains `SurfaceMesh.manifoldAudit()`.
- Existing STL export remains `SurfaceMesh.writeSTL(...)` through
  `exportSurfaceFoundryMesh()` and the call-sheet workflow.
- Existing metadata entry points remain `writeFoundryMetadata(...)` and
  `writeFoundryCallSheetManifest(...)`.
- Existing preview and input entry points remain `drawFoundryPreview(...)`,
  `mousePressed()`, and `keyPressed()`.

The legacy materializer representation is `boolean[][][]`. DCRTE uses flat
`float[]` and `boolean[]` arrays and converts only at the adapter boundary.

## Added Interfaces and Components

- `ObservationDomain`, `DomainSample`, and `Bounds3D`
- `SphereDomain`, `BoxDomain`, and Y-axis `CylinderDomain`
- `VolumeSpec` and `UniformGridObserver`
- `ObservationLayer` and `ObservationSample`
- `HardInteriorObservation` and inside-only `ShellBandObservation`
- `DCRTEVolume`
- frame-independent `ImmediateScheduler`
- `LegacyVoxelMaterializerAdapter`
- `DCRTEValidationReport`
- `DCRTEM1TestReport`

The observer samples Cartesian voxel centers over `[-1, 1]^3`, the same
normalized coordinate range previously passed to Surface Foundry field
sampling. No intrinsic coordinates are introduced.

## Materialization Policy

Primitive mode evaluates `foundryScalar(...)` everywhere through the Milestone
0 field adapter, classifies candidates with the existing iso band, applies the
domain observation mask, and activates the intersection through the immediate
scheduler.

The adapter converts the flat final mask to `boolean[][][]`, runs the existing
connectivity regularizer, clips all additions to admitted voxels, and performs
an admission-aware diagonal cleanup. When a legacy bridge choice falls outside
the domain, the cleanup chooses an admitted bridge instead. This resolved
curved-boundary and shell edge contacts while keeping outside-solid count zero.

Raised transport veins are not applied in primitive mode. Their metadata policy
is `disabled_until_domain_clipping`. Legacy behavior is unchanged.

## Verification

Deterministic fixtures: `37 passed, 0 failed`.

Primary acceptance matrix, Processing 4.5.2 on the development Mac:

| ID | Domain | Observation | Admitted | Final | Outside | Triangles | Time |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| M1-A | sphere | hard interior | 96,200 | 29,889 | 0 | 55,684 | 288 ms |
| M1-B | sphere | shell band | 39,040 | 12,330 | 0 | 33,440 | 186 ms |
| M1-C | box | hard interior | 125,000 | 39,497 | 0 | 69,668 | 201 ms |
| M1-D | box | shell band | 50,912 | 16,546 | 0 | 39,692 | 141 ms |
| M1-E | cylinder | hard interior | 85,568 | 27,224 | 0 | 49,504 | 272 ms |
| M1-F | cylinder | shell band | 39,488 | 13,004 | 0 | 31,420 | 125 ms |

Supplemental builds:

- Sphere hard interior at `32^3`: printable, 14,008 triangles, 25 ms.
- Sphere hard interior at `128^3`: printable, 222,228 triangles, 973 ms.
- Legacy direct regression: printable, 38,236 triangles, zero boundary,
  non-manifold, or degenerate audit findings.
- Adapter regression: `PASS`, 256 samples, maximum and mean absolute error `0`.

Exact timings vary by field state and machine. The authoritative latest run is
written to `logs/dcrte_m1_acceptance_latest.json` by the opt-in acceptance flag.

## Configuration and Provenance

Milestone 1 extends the Milestone 0 snapshot to schema `0.4-m1`. Primitive
metadata distinguishes field carrier from observation domain and includes:

- domain type, version, center, dimensions, analytic volume, and bounds;
- uniform observer resolution, spacing, sample volume, and Cartesian policy;
- observation epsilon and shell thickness;
- immediate scheduler identity;
- legacy materializer adapter and raised-vein policy;
- validation counts, relative domain-volume error, timings, and test status;
- original field, material, shaper, carrier, seed, and configuration identity.

## Files Added

- `DCRTE_Domain.pde`
- `DCRTE_Observer.pde`
- `DCRTE_Observation.pde`
- `DCRTE_Volume.pde`
- `DCRTE_Validation.pde`
- `DCRTE_Scheduler.pde`
- `DCRTE_MaterializerAdapter.pde`
- `DCRTE_M1_Tests.pde`
- `DCRTE_UI.pde`

## Known Limits and Milestone 2 Boundary

Milestone 1 supports analytic primitives only. It does not import or repair
meshes, voxelize triangle boundaries, build mesh-derived SDFs, compute intrinsic
coordinates, propagate fronts, schedule by entropy, adapt sample density, or
perform mechanical analysis.

The intended Milestone 2 insertion points are:

- `ImportedMeshDomain` implementing `ObservationDomain`;
- `MeshDomainReport` alongside configuration validation;
- `VoxelizedBoundary` and `SignedDistanceVolume` behind the domain interface;
- `StrictInvalidDomainPolicy` before volume allocation;
- SDF slice diagnostics beside the existing center-slice preview.

Those additions should not require changes to `FieldEngine`, observation-layer
interfaces, `ImmediateScheduler`, the legacy candidate rule, `DCRTEVolume`, or
the materializer adapter boundary.
