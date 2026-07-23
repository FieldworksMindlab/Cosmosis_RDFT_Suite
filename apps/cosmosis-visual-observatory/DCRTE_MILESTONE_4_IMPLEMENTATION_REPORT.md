# DCRTE-ET Milestone 4 Implementation Report

## Result

Milestone 4 is implemented as an additive deterministic scheduler layer in
Surface Foundry. The established M0-M3 field, domain, preflight,
intrinsic-coordinate, materializer, mesh, call-sheet, relief, and STL paths are
unchanged. `IMMEDIATE` is the default scheduler and remains the compatibility
bridge to the static workflow.

The new layer answers one additional question: given a frozen candidate-solid
volume, which permitted voxels are active at scheduler batch N? It does not
change field identity, geometry, or fabrication settings.

## Repository Audit And Name Mapping

| Work-order concept | Current implementation |
| --- | --- |
| Field engine / legacy adapter | `FieldEngine`, `LegacyTopologyScalarAdapter` in `DCRTE_Field.pde` |
| Candidate scalar volume | `DCRTEVolume.scalar` in `DCRTE_Volume.pde` |
| Observation admission mask | `DCRTEVolume.admitted` in `DCRTE_Volume.pde` |
| Candidate-solid mask | `DCRTEVolume.candidateSolid` in `DCRTE_Volume.pde` |
| Final-solid mask | `DCRTEVolume.finalSolid` in `DCRTE_Volume.pde` |
| Volume specification | `VolumeSpec` in `DCRTE_Observer.pde` |
| Flat index convention | `x + nx * (y + ny * z)` in `VolumeSpec.index(...)` |
| Signed distance | `SignedDistanceVolume.signedDistance` in `DCRTE_SignedDistanceVolume.pde` |
| Cartesian coordinates | `CartesianCoordinateSystem` in `DCRTE_CoordinateSystem.pde` |
| Intrinsic coordinates | `IntrinsicAxialCoordinateSystem` and `IntrinsicCoordinateVolume` |
| Intrinsic confidence | `IntrinsicCoordinateVolume.confidence` |
| Materializer | `LegacyVoxelMaterializerAdapter` in `DCRTE_MaterializerAdapter.pde` |
| Imported preflight | `DomainPreflightReport` and imported-domain preflight tabs |
| JSON, STL, call sheets | Existing Surface Foundry export and call-sheet paths |
| Surface Foundry controls | Main sketch input handling plus `DCRTE_UI.pde` |
| Invalidation | Existing DCRTE source invalidation plus scheduler snapshot checks |
| Raised veins | Existing foundry policy; suppressed for partial scheduled masks |
| Components | Existing preflight utilities plus M4 flat-array component traversal |
| Immediate baseline | `ImmediateScheduler` in `DCRTE_Scheduler.pde` |
| M4 controller | `SchedulerController` in `DCRTE_SchedulerController.pde` |

The audit found an existing M4 scaffold in the live project. It was completed
and hardened in place rather than duplicated or replaced.

## Implemented Modules

- `DCRTE_SchedulerCore.pde`: immutable snapshots, configuration, contracts, and
  upstream provenance.
- `DCRTE_PropagationState.pde`: flat activation, frontier, arrival, and hash
  storage.
- `DCRTE_SeedStrategies.pde`: center, intrinsic endpoint, and component seed
  selection.
- `DCRTE_FrontierPolicies.pde`: deterministic 6-, 18-, and 26-neighbor
  propagation.
- `DCRTE_SchedulerMetrics.pde`: diagnostics and compact batch history.
- `DCRTE_SchedulerController.pde`: lifecycle, comparison, materialization,
  invalidation, and export.
- `DCRTE_SchedulerUI.pde`: controls, M3/M4 comparison, diagnostics, and
  orthogonal slices.
- `DCRTE_M4_Tests.pde`: deterministic fixtures, acceptance matrix, and opt-in
  performance benchmarks.

## Immutable Snapshot Boundary

`CandidateVolumeSnapshot` freezes:

- volume dimensions and world bounds;
- admitted and candidate-solid masks;
- field scalar values;
- optional signed distance;
- intrinsic S, rho, theta, and confidence;
- field, domain, coordinate, and material configuration identities.

The content hash includes all scheduler-relevant arrays and configuration
identities. The creation timestamp is diagnostic only and cannot influence
ordering. Scheduler arrays are separate from all upstream arrays.

Changes to domain, transform, SDF, coordinate mapping, field parameters,
material profile, iso rule, or resolution invalidate the schedule and disable
export. Camera, panel, slice, color, and display-speed changes do not.

## Scheduling Semantics

`IMMEDIATE` activates every admitted candidate at batch zero. It must reproduce
the M3 static candidate mask with zero mismatched voxels.

`FRONT_PROPAGATION` supports:

- center-nearest, intrinsic-start, intrinsic-end, and per-component seeds;
- 6-, 18-, and 26-connected neighborhoods;
- reachable-only, seed-each-component, and block-disconnected policies;
- breadth-first or field-priority deterministic frontier ordering;
- bounded batch size and render-independent execution.

Arrival convention:

```text
-1 = not activated
 0 = seed
 1..N = committed scheduler batch
```

The materialization rule is exactly:

```text
finalSolid[i] = admitted[i] && candidateSolid[i] && active[i]
```

Pause, resume, animation display budget, and render cadence do not alter arrival
order or final state hashes. Equal frontier scores resolve by flat voxel index.

## Milestone Comparison

The scheduler panel shows the frozen M3 candidate count and the M4 active,
pending, illegal, and mismatch state. Scheduler JSON includes a
`baseline_comparison` object with:

- M3 baseline identity;
- M4 layer identity;
- candidate, active, and pending counts;
- illegal activation count;
- mask mismatch count;
- completed-equivalence flag.

This makes the exploratory difference explicit: M3 defines what may become
material; M4 exposes deterministic activation order over that unchanged set.

## Materialization And Export

The current partial state or completed schedule can be materialized through the
existing legacy adapter. Any subsequent scheduler advance marks that mesh stale.
STL and call-sheet export remain locked until mesh state and scheduler hash
match.

Raised transport veins remain suppressed for partial schedules because the
legacy vein system does not yet define scheduler-aware clipping. This is a
deliberate compatibility guard rather than a geometry change.

Scheduler artifacts include:

- `exports/scheduler/<timestamp>_<mode>_<state>/scheduler_metrics.csv`
- `exports/scheduler/<timestamp>_<mode>_<state>/scheduler_run.json`
- `exports/scheduler/<timestamp>_<mode>_<state>/arrival_order.bin`
- `exports/scheduler/<timestamp>_<mode>_<state>/arrival_order.json`
- `exports/scheduler/<timestamp>_<mode>_<state>/manifest.json`

Binary arrival data is little-endian signed 32-bit integer data in the same flat
volume order.

## Verification

Processing compilation and all deterministic startup suites pass:

| Suite | Result |
| --- | ---: |
| M1 | 37 passed |
| M2 | 37 passed |
| M2.5 | 13 passed |
| M3 | 21 passed |
| M4 | 22 passed |
| Geodesic Salon core | 56 of 56 passed |

The M4 application acceptance matrix passes 10 of 10 cases. It covers Immediate
and Front modes, Cartesian and intrinsic egg domains, a bent capsule,
disconnected-component policies, invalid-domain blocking, pause/resume,
render-budget independence, reconstruction, and materialization.

The fixture suite additionally verifies:

- complete snapshot provenance, including theta and material identity;
- Immediate zero-mask mismatch;
- arrival batch and rank reconstruction;
- 18- and 26-neighbor completion;
- reset reproducibility;
- compact history monotonicity;
- no outside-domain or noncandidate activation.

Run acceptance:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_m4 \
  --force --run --dcrte-m4-acceptance
```

## Performance Record

The opt-in benchmark propagates a deterministic fully admitted cube. It measures
scheduler mechanics, not field evaluation or mesh extraction.

| Resolution | Candidates | Batches | Snapshot | Scheduler | Reconstruct | Total | Snapshot bytes | State bytes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 cubed | 262,144 | 96 | 68.10 ms | 1,033.15 ms | 2.33 ms | 1,120.79 ms | 2,621,440 | 4,980,736 |
| 128 cubed | 2,097,152 | 192 | 239.30 ms | 15,385.02 ms | 6.22 ms | 15,656.70 ms | 20,971,520 | 39,845,888 |

Both benchmark cases complete with zero mask mismatch. Component and frontier
traversal use reusable flat storage and avoid per-voxel neighbor allocations.

Run the benchmark:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_m4_benchmark \
  --force --run --dcrte-m4-benchmark
```

The latest machine-readable result is
`logs/dcrte_m4_benchmark_latest.json`.

## Stop Reasons And Compatibility Names

The implementation preserves established enum names where they differ from the
work order:

- `USER_STOPPED` corresponds to `USER_STOP`;
- `CONFIGURATION_STALE` corresponds to `CONFIGURATION_INVALIDATED`;
- `INVALID_DOMAIN` covers invalid domain and invalid candidate volume gates.

Pauses are nonterminal and remain distinct from the final stop reason.

## Explicit Deferrals

Milestone 4 does not implement:

- entropy or stochastic acceptance;
- physical time, stress, density, or thermal solvers;
- arbitrary branching growth;
- mesh repair or new extraction;
- scheduler-aware partial-state veins.

The live 2D entropy diagnostic is not used as local 3D scheduler entropy.

## Milestone 5 Insertion Points

The future Emergent Entropic Scheduler can be added through the existing
`FieldScheduler` contract, scheduler configuration, seed interface, frontier
scoring policy, diagnostics/history, controller, and UI. It can consume the same
immutable candidate snapshot without changing M0-M4 behavior.
