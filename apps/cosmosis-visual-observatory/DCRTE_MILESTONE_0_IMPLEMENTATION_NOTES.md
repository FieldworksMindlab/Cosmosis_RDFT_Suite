# DCRTE-ET Milestone 0 Implementation Notes

## Scope

Milestone 0 introduces a compatibility architecture around the existing Surface
Foundry field evaluator. It does not implement observation domains, imported
STL domains, signed distance fields, intrinsic coordinates, propagation,
materializers, analysis modules, or the Emergent Entropic Scheduler.

`LEGACY_DIRECT` remains the default. `DCRTE_ADAPTER_TEST` runs parity diagnostics
only. Both modes continue to generate geometry through the same legacy direct
path.

## Existing Path Preserved

The current generation chain remains:

```text
generateSurfaceFoundryMesh()
  -> currentTopologyScores()
  -> foundryScalar(x, y, z, scores)
  -> topologyScalar(x, y, z, scores)
  -> optional geometryCarrierScalar(...)
  -> boolean voxel occupancy
  -> regularizeFoundrySolid(...)
  -> addVoxelBoundaryFaces(...)
  -> SurfaceMesh manifoldAudit()
```

Downstream STL, call-sheet, relief, and SVG generation still consume the same
`foundryMesh` and `foundryCallSheetSolid` objects.

No existing field equation was moved or edited for Milestone 0. No generation
call was replaced with `FieldEngine.sample(...)`.

## Added Components

`DCRTE_Field.pde` provides:

- `FieldEngine` minimal interface;
- `LegacyTopologyScalarAdapter`;
- `LEGACY_DIRECT` and `DCRTE_ADAPTER_TEST` modes;
- deterministic 256-point direct/adapter comparison;
- maximum and mean absolute error diagnostics;
- no random sampling and no geometry mutation.

`DCRTE_Config.pde` provides:

- copied configuration snapshots of current field and Foundry state;
- explicit canonical key ordering;
- SHA-256 configuration identity;
- nested JSON serialization;
- additive Surface Foundry metadata fields.

The Surface Foundry UI adds one pipeline selector in previously unused control
space and a small overlay diagnostic. Existing keyboard commands are unchanged.

## Regression Contract

The adapter must call the existing `topologyScalar(...)` with the same point and
topology blend as the direct comparison. Expected maximum and mean absolute
error are zero; the displayed pass tolerance is `1e-7` to allow future
floating-point implementation changes to be measured rather than hidden.

The regression fixture is stored at
`data/dcrte_presets/milestone_0_legacy_regression.json`.

## Milestone 1 Refactor Inventory

These functions and globals are candidates for later isolation. They are not
refactored in Milestone 0:

- `topologyScalar(...)`: currently reads shared globals including `depth`,
  `simT`, `braneTwist`, source/quasi controls, and shaper state.
- `foundryScalar(...)`: combines the topology scalar with carrier geometry,
  field wrapping, phase lift, and global Foundry blend state.
- `geometryCarrierScalar(...)`: reads time, depth, twist, and holonomy globals.
- `sampleFieldWrap(...)`: reads the global 2D field array.
- `currentTopologyScores()` and `topologyScores(...)`: derive the active blend
  from shared live metrics.
- `generateSurfaceFoundryMesh()`: owns sampling, crop constraints, occupancy,
  vein union, regularization, mesh extraction, and audit in one synchronous
  function.
- `addRaisedVeinsToSolid(...)`: is a materialization-stage union operation and
  should remain separate from future field evaluation.
- `foundryCallSheetSolid`: uses nested arrays; future domain volumes should use
  flat primitive storage without changing this legacy buffer prematurely.
- `writeFoundryMetadata(...)` and `writeFoundryCallSheetManifest(...)`: contain
  overlapping provenance fields that can later share a versioned exporter.
- Surface Foundry mouse geometry: should move into a dedicated UI tab only after
  the compatibility selector has proven stable.

Milestone 1 should add primitive observation domains and a uniform observer
beside this path, not by replacing it.
