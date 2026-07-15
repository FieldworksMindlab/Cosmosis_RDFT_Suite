# DCRTE-ET Milestone 3 Implementation Report

## Result

Milestone 3 adds a basic intrinsic axial coordinate system for one qualified,
dominant, non-branching imported domain. It is inserted between the existing
observer and the unchanged recursive field engine. Cartesian imported-domain
sampling remains the default and retains the Milestone 2 behavior.

The final deterministic run passed 20/20 Milestone 3 checks and the canonical
acceptance matrix passed 12/12 cases. The retained Milestone 1, 2, and 2.5
deterministic suites also pass at application startup.

## Architecture Boundary

`FieldCoordinateSystem` is the only new boundary in the generation path:

```text
qualified observer voxel
  -> Cartesian or intrinsic coordinate mapping
  -> existing FieldEngine sample
  -> existing observation admission
  -> existing scheduler and materializer
```

No recursive field equation, topology blend, material rule, scheduler rule,
legacy regularizer, call-sheet renderer, or STL exporter was replaced.

The two coordinate implementations are:

- `CartesianCoordinateSystem`: exact identity mapping from observer world
  coordinates to field coordinates.
- `IntrinsicAxialCoordinateSystem`: maps normalized centerline position `s`,
  normalized radius `rho`, and transported polar angle `theta` into the same
  three field inputs.

```text
fieldX = longitudinalScale * (2*s - 1)
fieldY = radialScale * rho * cos(theta)
fieldZ = radialScale * rho * sin(theta)
```

## Intrinsic Construction

The builder consumes only a current Milestone 2.5-qualified SDF and inside
mask. It performs these deterministic stages:

1. Select the largest six-connected inside component and require a dominant
   fraction of at least `0.98`.
2. Compute distance-weighted PCA with weights `max(-sdf, smallPositiveValue)`.
3. Resolve PCA sign toward the smaller end radius, or toward the positive
   dominant world axis when both ends are equivalent.
4. Build `max(32, observer resolution)` axial bins with a four-voxel minimum.
5. Interpolate only gaps no larger than `max(2, 0.04 * sliceCount)` and retain
   both raw and effective valid-slice fractions.
6. Smooth centroids with three deterministic weighted-moving-average passes.
7. Correct smoothed points conservatively toward raw centroids when needed,
   then resample by arc length and inset endpoints by `1.5 * voxel spacing`.
8. Build a parallel-transport frame field; Frenet frames are not used.
9. Map admitted voxels to the nearest centerline segment using an axial initial
   estimate, a six-sample search window, one expansion, and a second pass for
   genuinely nonlocal ambiguity.
10. Compute `s`, radial distance, `rho`, `theta`, signed boundary distance,
    confidence, ambiguity, and fallback markers in flat primitive arrays.

The required equivalent-circular radial model is the default. The optional
elliptical model is exposed only as an explicit operator choice and has a
passing finite-cylinder fixture.

## Suitability And Safety

The initial policy uses the work-order thresholds:

| Metric | Gate |
|---|---:|
| Dominant component fraction | `>= 0.98` |
| Effective valid slice fraction | `>= 0.85` |
| Centerline coverage | `>= 0.90` |
| Maximum slice gap fraction | `<= 0.08` |
| Nonlocal mapping ambiguity | `<= 0.05` |
| Fallback fraction for export | `<= 0.01` |

Low elongation begins as a warning. Closed loops, suspected branches, multiple
dominant components, unresolved centerlines, frame failures, non-finite
coordinates, excessive ambiguity, and excessive fallback remain blockers.

Fallback defaults to `BLOCK`. Cartesian-local and clamped-local fallback modes
are explicit, counted separately at mapping and application time, visualized,
and exported in metadata. No accepted result may hide fallback use.

## UI And Visualization

The docked preflight workspace now includes an `INTRINSIC` inspector tab. It
contains build/reset controls, coordinate and radial modes, longitudinal and
radial scale controls, fallback policy, comparison mode, report export, and
toggles for centerline, frames, confidence, and scalar views.

The inspector reports coordinate mode, build and suitability state, component
fraction, PCA elongation, valid slices, centerline sample count and length,
frame continuity, ambiguity, mapping and applied fallback, confidence, radial
model, scales, build time, and paired solid fractions.

M3.1 adds a persistent operator gate band between the preflight toolbar and
the model workspace. It states whether export is ready, stale, awaiting
materialization, preflight-blocked, or intrinsic-blocked; selecting the band
routes to the relevant Issues or Intrinsic inspector. Every existing button
also receives a visible held state without adding audio to the visual-only app.
The Intrinsic inspector can export and reveal its current JSON report directly.

Available overlays include centerline, transported frames, axial slice rings,
`s`, radial distance, `rho`, periodic `theta`, confidence, ambiguity, fallback,
and retained Cartesian/intrinsic comparison masks.

## Cartesian Versus Intrinsic Comparison

`CARTESIAN_AND_INTRINSIC` samples both coordinate systems with one frozen field
configuration and seed. It retains separate masks and reports:

- admitted voxel count;
- candidate and final solid counts;
- solid fractions;
- component counts and largest-component fractions;
- outside-domain solid counts;
- Cartesian field time;
- intrinsic field time;
- coordinate mapping time;
- intrinsic build time;
- ambiguity, fallback, and confidence.

The operator can toggle the retained Cartesian and intrinsic result overlays.
The selected coordinate mode still controls the actual generated mesh.

## Metadata

Imported-domain configuration schema `0.6-m3` records coordinate mode and
version, mapping, radial model, fallback policy, comparison mode, scales, build
status, valid/ambiguity/fallback fractions, and confidence. Full export metadata
also includes the suitability report, PCA frame and sign policy, slices,
centerline, transported frames, flat intrinsic volume summary, phase timings,
paired comparison report, and Milestone 1-3 deterministic test status.

All existing source-mesh, sanitation, transform, SDF, observer, observation,
field, scheduler, materializer, validation, output-scale, call-sheet, and STL
provenance remains present.

## Acceptance Evidence

The measured `36^3` acceptance run produced:

| ID | Case | Result | Key evidence |
|---|---|---|---|
| M3-A | Cylinder / Cartesian | Pass | Exact identity mapping |
| M3-B | Cylinder / intrinsic | Pass with warning | frame `1.000`, ambiguity `0`, fallback `0` |
| M3-C | Egg / Cartesian | Pass | Exact identity mapping |
| M3-D | Egg / intrinsic | Pass with warning | frame `1.000`, ambiguity `0`, fallback `0` |
| M3-E | Rotated egg / intrinsic | Pass with warning | frame `0.997`, ambiguity `0` |
| M3-F | Bent capsule / intrinsic | Pass with warning | frame `0.959`, no discontinuity |
| M3-G | Sphere / intrinsic | Policy block | low elongation and ambiguity reported |
| M3-H | Torus / intrinsic | Block | `IC_CLOSED_LOOP_SUSPECTED` |
| M3-I | Y-branch / intrinsic | Block | `IC_BRANCHING_SUSPECTED` |
| M3-J | Two bodies / intrinsic | Block | `IC_MULTIPLE_DOMINANT_COMPONENTS` |
| M3-K | Production M2 egg / intrinsic / `64^3` | Pass with warning | imported-mesh SDF path; no false self-approach |
| M3-L | Production M2 egg / intrinsic / `128^3` | Pass with warning | high-resolution imported-mesh SDF path |

At this fixture size, complete intrinsic builds measured approximately `3-6
ms` on the development machine. Timing is reported rather than treated as a
portable benchmark.

Run the acceptance matrix with:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="$PWD" \
  --output=/tmp/cosmosis_m3_acceptance \
  --force --run --dcrte-m3-acceptance
```

The run writes `logs/dcrte_m3_acceptance_latest.json`. A curated copy is kept in
`docs/verification/dcrte_m3_acceptance.json`.

## Files

Added:

- `DCRTE_CoordinateSystem.pde`
- `DCRTE_IntrinsicSuitability.pde`
- `DCRTE_PCA.pde`
- `DCRTE_Centerline.pde`
- `DCRTE_TransportFrames.pde`
- `DCRTE_RadialModel.pde`
- `DCRTE_IntrinsicVolume.pde`
- `DCRTE_IntrinsicVisualization.pde`
- `DCRTE_M3_Tests.pde`

Extended:

- `Cosmosis_Visual_Observatory.pde`
- `DCRTE_Config.pde`
- `DCRTE_ImportedMeshDomain.pde`
- `DCRTE_MaterializerAdapter.pde`
- `DCRTE_UI.pde`
- `README.md`

## Known Limits

Milestone 3 is deliberately limited to a single dominant, non-branching,
non-looping closed domain with a reliable SDF. Equivalent radius and oblique
slice area are approximations. Intrinsic coordinates are a field-sampling
coordinate system; they do not prove topological invariance, mechanical
performance, manufacturability, or material constitutive behavior.

Automatic mesh repair is not part of Milestone 3. An STL with the reported nine
non-manifold vertices remains diagnostic-preview-only and correctly blocked by
Milestone 2.5. A future repair tool should create a new derived mesh candidate,
retain the immutable source, record the operation and before/after topology,
then rerun full preflight. It must never silently relax admission criteria.

## Recommended Next Insertions

- Add an explicit `DERIVE REPAIRED CANDIDATE` stage before preflight for
  conservative duplicate/degenerate cleanup first, followed later by optional
  voxel/SDF remeshing when topology-changing repair is intentionally selected.
- Keep repair provenance separate from intrinsic-coordinate metadata.
- Add branch-aware or closed-loop coordinate systems as new implementations of
  `FieldCoordinateSystem`; do not overload `INTRINSIC_AXIAL`.
- Add background intrinsic-build jobs only if measured `128^3` domains make the
  current synchronous operator workflow unresponsive.
- Keep future entropic scheduling, FEA, stress fields, and topology optimization
  downstream of the coordinate boundary.
