# DCRTE-ET M6-HX Implementation Report

## Scope

M6-HX adds the disabled-by-default Holographic Bridge Explorer (HBE) beside the
existing Observatory workflows. It is a classical field, voxel-graph, and
scheduler testbed inspired by Biswas et al. (2026, arXiv:2607.12047). It does
not implement a quantum code, tensor network, gravitational model, geodesic,
or physical wormhole.

## Existing-System Mapping

| HBE requirement | Observatory implementation used |
|---|---|
| Imported domain | `DCRTEImportedMeshDomain` |
| Signed distance | existing imported SDF pipeline |
| Intrinsic chart | `IntrinsicCoordinateVolume` and the M3 builder |
| Candidate state | `CandidateVolumeSnapshot` |
| Propagation | existing Immediate, Front, and EES scheduler controller |
| Entropic score | optional HBE extension on the existing score context |
| Material output | existing Surface Foundry and M6 paths |
| Evidence | existing JSON/CSV export conventions |

No second scheduler or relaxed intrinsic suitability rule was introduced.

## Implemented Modules

- `DCRTE_HBE_Config.pde`: immutable configuration, hashes, feedback sources,
  influence channels, and nonclaim metadata.
- `DCRTE_HBE_DualLobeFixture.pde`: deterministic connected dual-lobe STL
  fixture passed through the normal importer and qualification path.
- `DCRTE_HBE_IntrinsicObservables.pde`: left/right coordinate, neck support,
  anchors, radius, and confidence semantics.
- `DCRTE_HBE_MirrorMap.pde`: deterministic mirrored partner lookup and
  confidence reporting.
- `DCRTE_HBE_FieldModifier.pde`: identity-safe neck relief plus an opt-in
  mirrored hierarchical lobe morphology proxy.
- `DCRTE_HBE_SeedStrategies.pde` and `DCRTE_HBE_ScoreExtension.pde`: optional
  seed and score terms layered onto the existing scheduler.
- `DCRTE_HBE_Connectivity.pde` and `DCRTE_HBE_PathProxies.pde`: six-connected
  candidate/active paths, components, shortest path, bottleneck, bilateral and
  mirror metrics, and connected/disconnected graph-pairing proxies.
- `DCRTE_HBE_Sweep.pde`: immutable fixed-envelope `11 x 6` response sweep.
- `DCRTE_HBE_Visualization.pde` and `DCRTE_HBE_UI.pde`: dedicated HBE lens,
  explicit feedback capture, analysis controls, views, and status reporting.
- `DCRTE_HBE_Export.pde`: manifest and CSV evidence with citation and false
  literal-claim flags.
- `DCRTE_HBE_Tests.pde`: deterministic identity, fixture, intrinsic, mirror,
  field, scheduler-isolation, connectivity, graph, and sweep tests.

## Data And Formula Notes

- Candidate membership remains `abs(scalar) < isoBand`.
- The field channel uses frozen feedback and coupling only.
- The default lobe proxy is `OFF`; therefore field identity outside the neck is
  exact unless the operator explicitly selects the morphology probe.
- A bridge means a six-connected voxel path between declared intrinsic anchor
  sets. Reported length is a voxel-graph proxy, not a geometric geodesic.
- Every snapshot binds configuration, frozen metrics, intrinsic, candidate,
  mirror, and analysis hashes.

Fixture hashes, intrinsic validity, mirror confidence, feedback values,
candidate changes, seed choices, connection events, tau, entropy, graph costs,
and path metrics are state-dependent and are written into each experiment's
runtime evidence rather than hard-coded into this report.

## Crash Remediation

The reported `Index 262144 out of bounds for length 262144` was a stale-grid
composition error: a candidate volume could be iterated while indexing an SDF
from a different `VolumeSpec`. M6 composition now verifies exact dimensions,
bounds, spacing, voxel count, and backing-array length before flat-array access.
Mismatch produces `M6_COMPOSITION_GRID_MISMATCH`, invalidates the composition,
and returns safely.

## Verification

Processing 4.5.2 build and deterministic runtime verification:

| Suite | Result |
|---|---:|
| M1 | PASS 37 |
| M2 | PASS 37 |
| M2.5 | PASS 13 |
| M3 | PASS 22 |
| M4 | PASS 22 |
| M5 | PASS 28 |
| M6 | PASS 36 |
| M6-HX HBE | PASS 21 |
| Geodesic Salon | PASS 72/72 |

The standalone application and monorepo copies compile and the touched source
files are byte-identical.

## Deliberate Limits And HBE-2 Insertion Points

- The interactive sweep is fixed-envelope and immutable. The full 66-cell
  geometry-rebuild sweep, pause/resume checkpoint engine, and selected-specimen
  exporter remain a separate research-mode operation because each cell must
  rebuild and qualify an imported domain without corrupting interactive state.
- The lobe proxy is a deterministic ordered morphology term, not a Petaminx
  tensor network or a claim of hyperbolic geometry.
- HBE reports absent valid paths as experimental outcomes; it does not force a
  disconnected candidate or stable-partial scheduler state to complete.
- Future HBE-2 work can add an isolated worker/checkpoint runner, selected-cell
  specimen materialization, hysteresis sweeps, and a learned sweep surrogate
  without changing the disabled identity path.
