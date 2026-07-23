# DCRTE-ET Milestone 5 Implementation Report

## Result

Milestone 5 is implemented as a third, optional scheduler mode:
`EMERGENT_ENTROPIC`. M0-M4, legacy generation, imported-domain preflight,
intrinsic coordinates, materialization, call sheets, reliefs, STL export, and
Geodesic Salon remain available through their existing paths.

M5 uses the frozen M4 candidate snapshot, seed strategies, component rules,
frontier construction, scheduler controller, arrival storage, materializer, and
export-currentness gate. It adds state-dependent entropy evaluation and
acceptance without changing the upstream field or candidate volume.

## M4 Implemented-Name Mapping

| Work-order concept | Implemented name and file |
| --- | --- |
| Candidate snapshot | `CandidateVolumeSnapshot`, `DCRTE_SchedulerCore.pde` |
| Propagation state | `PropagationState`, `DCRTE_PropagationState.pde` |
| Active mask | `PropagationState.active` |
| Frontier mask / indices | `frontier`, `frontierIndices`, `frontierCount` |
| Arrival storage | `arrivalBatch`, `arrivalRank`, `activationScore` |
| Scheduler interface | `FieldScheduler` |
| Scheduler context | `SchedulerContext` |
| Configuration | `SchedulerConfiguration` |
| Batch | `SchedulerBatch` |
| Controller | `SchedulerController` |
| Immediate baseline | `ImmediateScheduler` |
| Breadth-first baseline | `FrontPropagationScheduler` |
| Seed strategies | `DCRTE_SeedStrategies.pde` |
| Neighborhood and frontier | `DCRTE_FrontierPolicies.pde` |
| Component policies | `SchedulerComponentPolicy` |
| History | `SchedulerHistoryEntry` |
| Hashing | scheduler-specific stable SHA-256 state hashes |
| JSON / CSV | `SchedulerController.toJSON()` and scheduler metrics exporters |
| UI | `DCRTE_SchedulerUI.pde` |
| Partial materialization | `SchedulerController.materializeCurrent()` |
| Raised-vein guard | existing scheduler-aware suppression policy |
| Invalidation | `SchedulerController.invalidate(...)` |

The frozen context already exposes field scalar, signed distance, intrinsic S,
rho, theta, coordinate confidence, and candidate component labels. No duplicate
controller or propagation framework was created.

## New Modules

- `DCRTE_EntropyCore.pde`
- `DCRTE_EntropyModels.pde`
- `DCRTE_EntropyCache.pde`
- `DCRTE_EntropyPolicies.pde`
- `DCRTE_EntropicScoring.pde`
- `DCRTE_EntropicAcceptance.pde`
- `DCRTE_EmergentEntropicScheduler.pde`
- `DCRTE_RelationalProgress.pde`
- `DCRTE_EntropicStability.pde`
- `DCRTE_EntropicVisualization.pde`
- `DCRTE_EntropicHistory.pde`
- `DCRTE_M5_Tests.pde`

The existing scheduler core, controller, UI, and primary sketch received narrow
integration changes.

## Formulas And Versions

Dynamic occupancy entropy:

```text
H_occ = -(p ln p + (1-p) ln(1-p)) / ln 2
```

Static field histogram entropy:

```text
H_field = -sum(p_b ln p_b) / ln(binCount)
```

Hypothetical activation delta is the exact mean `H_after - H_before` across
every affected valid candidate center.

The combined score is the normalized weighted sum of available terms. Default
policy weights before normalization are:

| Policy | Principal weights |
| --- | --- |
| Relaxation | field .20, relaxation .45, coherence .20, depth .05, confidence .10 |
| Exploration | field .20, exploration .35, coherence .15, field complexity .15, noise .10, confidence .05 |
| Balanced | field .25, balance .30, coherence .20, depth .10, field complexity .05, confidence .10 |
| Adaptive | relaxation and exploration presets blended by exported policy state |

Formula versions:

- score: `m5-score-1`;
- relational progress: `m5-tau-1`;
- stateless random: `m5-mix64-1`;
- entropy model versions: `1.0`.

## Neighborhood And Support

Entropy neighborhoods support propagation neighbors, cube radius 1, and cube
radius 2. The default is cube radius 1 with the center included. The support
policy is candidate-only; outside coordinates and admitted noncandidate voxels
are excluded. The default minimum support is four.

The field model defaults to eight bins over the frozen global candidate range.

## Cache Strategy

M5 builds flat primitive arrays for occupancy entropy, field entropy, support,
validity, and affected-center marks. Only centers touched by a committed
activation batch are updated. Full recomputation is performed at the configured
verification interval and before completion, frontier exhaustion, stable
partial termination, and deterministic threshold stall.

Tolerance: `1e-6`.

Observed maximum cache error in deterministic tests and the 12-case matrix:
zero. Cache divergence is a hard failure, never an approximate fallback.

## Policies And Acceptance

Policies:

- relaxation;
- exploration;
- balanced;
- adaptive relax/explore.

Only adaptive mode changes policy state after stagnation. Boost, hold, decay,
and return transitions are recorded. Other modes report no adaptive transition.

Acceptance modes:

- deterministic threshold;
- deterministic top-K;
- stateless seeded stochastic sigmoid acceptance.

Stochastic values derive from scheduler seed, batch, voxel, and a versioned
salt. There is no sequential random stream.

## Relational Progress And Stability

```text
delta_tau =
    activationWeight * activationFractionChange
  + entropyWeight * meanAbsoluteEntropyChange
  + frontierWeight * frontierFractionChange
```

Default weights are `1.0`, `1.0`, and `0.25`. Tau is dimensionless,
computational, and nondecreasing under the default formula. It is not a
physical-time claim.

Default stability settings:

- minimum batches: 20;
- observation window: 8;
- activation, entropy, frontier, and score epsilons: `0.0001`;
- required stable windows: 3.

Stable partial, threshold stall, complete reachable, frontier exhausted,
maximum batches, and validation failure remain distinct terminal states.

## State Hash And Provenance

The M5 hash includes:

- candidate snapshot hash;
- scheduler, entropy model, score, and random versions;
- full scheduler and entropy configuration;
- policy mode and state;
- normalized score weights;
- entropy-cache hash;
- raw tau representation;
- arrival array and batch index;
- terminal state.

Wall-clock runtime, render frame count, camera, and UI state are excluded.

Exports record model definitions, support and boundary policy, bins, weights,
threshold, temperature, scheduler seed, acceptance mode, policy transitions,
tau, stability criteria, cache status, terminal state, and partial/complete
labeling.

## Interface

The scheduler panel now distinguishes M4 and M5 modes. M5 offers basic and
advanced configuration, ten visualization modes, frontier-candidate
inspection, a tau/entropy history plot, cache status, and explicit terminal
state. M4 controls and slices retain their prior behavior.

## Verification

All startup regression suites pass:

| Suite | Result |
| --- | ---: |
| M1 | 37 passed |
| M2 | 37 passed |
| M2.5 | 13 passed |
| M3 | 21 passed |
| M4 | 22 passed |
| M5 | 28 passed |
| Geodesic Salon core | 56 of 56 passed |

The M5 application acceptance matrix passes 12 of 12 cases. It covers a
cylinder, intrinsic egg, bent capsule, disconnected components, invalid domain,
all four policies, all three acceptance families, deterministic repeatability,
adaptive transitions, complete reachable states, and explicitly labeled
partial/stalled states.

Representative reproducibility hashes from the current acceptance run:

- M5-A relaxation cylinder:
  `bb31e468ddc1e6a51b4b9c69e861084f8d81a40b34859531e0139f522d2f766a`;
- M5-D stochastic egg:
  `97b0b6a004f3c9681b88df318b8515bbd1372c369559b5eab430a36d7420aaf8`;
- M5-J threshold-stalled egg:
  `2b5663b19db2b21999113cb1a5f036c23b2e17116345e4994e6145faa34e1370`.

These hashes are configuration-specific and will change when declared policy
semantics or configuration change.

Run deterministic tests:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_m5_tests \
  --force --run --dcrte-m5-tests-only
```

Run the acceptance matrix with `--dcrte-m5-acceptance`.

## Performance Record

The opt-in diagnostic benchmark uses an exact candidate shell with no hidden
downsampling. It records snapshot capture, cache plus initialization, one exact
frontier batch, and full cache verification. It is not mislabeled as a full
terminal scheduler run.

| Resolution | Candidates | Cache + initialize | Exact batch | Full verify | Total | Correct |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 64 cubed | 23,816 | 161.23 ms | 52.44 ms | 21.79 ms | 321.77 ms | yes |
| 128 cubed | 96,776 | 251.74 ms | 181.61 ms | 57.06 ms | 763.59 ms | yes |

Both exact single-batch cases are inside the work-order development targets.
Full terminal runtime remains domain-, frontier-, acceptance-, and
threshold-dependent and must be measured for the intended research fixture.

Run with `--dcrte-m5-benchmark`. The result is written to
`logs/dcrte_m5_benchmark_latest.json`.

## Memory

The entropy cache estimate includes two float fields, two support arrays, two
validity masks, and one affected-center mark array. Score records are allocated
for the current frontier and sampled exports are bounded by configuration.
`128^3` remains a research mode.

## Stop Reasons

M5 adds explicit reasons for entropy model/configuration failure, nonfinite
entropy or scores, cache divergence, invalid weights or acceptance settings,
stateless-random failure, nonfinite tau, invalid stability, stable partial,
threshold stall, and adaptive exhaustion. Existing M4 invalid-domain,
component, seed, unreachable, maximum-batch, invalidation, user-stop, and
internal-error reasons remain in force.

## Baseline Comparison

Immediate still reproduces the frozen candidate mask at batch zero. Front
Propagation still orders the same mask by graph distance or frozen field
priority. Entropic policies produce policy-dependent arrival order and tau on
the same snapshot. The current cylinder fixture completed under relaxation and
exploration in 25 batches with different hashes and tau values, while both
ended with active fraction one.

This is a descriptive comparison. M5 is not declared superior without a
separate application criterion.

## Known Limitations

- Exact full-frontier entropy evaluation is intentionally more expensive than
  M4 connectivity propagation, especially at `128^3`.
- Binary occupancy entropy describes the declared local active/inactive state;
  it is not thermodynamic entropy or free energy.
- Field histogram entropy is static because the M5 candidate field is frozen.
- Threshold policies can reach an explicit stall or maximum-batch state before
  all reachable candidates activate. Such results remain partial.
- The initial adaptive policy uses declared engineering thresholds and bounded
  preset transitions; it is not learned or physically calibrated.
- M5 does not deactivate material, repair imported meshes, alter intrinsic
  coordinates, mutate field parameters, or perform stress, flow, chemistry,
  or multi-material simulation.

## Milestone 6 Insertion Points

Milestone 6 characterization can consume the frozen candidate snapshot,
arrival-order volume, active masks reconstructed at selected event batches,
entropic history, and paired scheduler exports. Suitable additions include
spectral density, directional anisotropy, connected-component persistence,
Euler characteristic, genus, interface-area evolution, and persistent
homology. These analyses should remain downstream observers: they must not
alter M5 scoring or force a desired scheduler result.

## Known Limits

- Exact hypothetical evaluation is more expensive than M4 propagation.
- Threshold fixtures can legitimately terminate at stable partial, explicit
  stall, or maximum batch depending on declared thresholds.
- The static histogram uses fixed frozen field values and does not model
  chemistry or thermodynamics.
- Intrinsic direction is omitted when intrinsic data is unavailable.
- M5 does not deactivate material or mutate the recursive field.
- Full-run `128^3` performance is not yet characterized for every domain.

## Milestone 6 Insertion Points

Future work can add a new named policy, observable, or downstream analytical
comparison through the existing M5 interfaces. It should not alter M5 formulas
or reinterpret tau as physical time. Deactivation, annealing, stress, flow,
multi-material competition, learned policies, and inverse design remain
separate future research modules.
