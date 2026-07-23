# DCRTE-ET Milestone 4 Scheduler Framework

Milestone 4 inserts a deterministic activation scheduler between the frozen
field-candidate volume and the existing Surface Foundry materializer. It does
not alter the recursive field, domain qualification, coordinate mapping,
candidate decision, mesh extraction, call-sheet rendering, or STL audit path.

## Pipeline Boundary

```text
domain + observation + coordinates
                |
                v
recursive field sampling
                |
                v
immutable admitted candidate snapshot
                |
                v
Immediate or Front Propagation scheduler
                |
                v
active material mask at batch N
                |
                v
existing legacy materializer and validation
```

`CandidateVolumeSnapshot` copies admission, candidacy, field scalar, optional
signed distance, intrinsic S/rho/theta/confidence arrays, and the field, domain,
coordinate, and material configuration identities. Its SHA-256 identity is
stable for a fixed upstream configuration. The diagnostic creation timestamp is
exported but is deliberately excluded from scheduler decisions and hashes.
Scheduler state is stored separately in flat arrays for active, frontier,
queued, arrival batch, arrival rank, and activation score.

## Modes

- **Immediate** activates every admitted candidate at batch zero. It is the
  default and preserves the static M1-M3 generation result.
- **Front Propagation** activates deterministic six-, eighteen-, or
  twenty-six-connected frontiers. Six-connected breadth-first propagation is
  the reference policy and gives Manhattan-distance arrival layers.

Front propagation supports center-nearest, intrinsic-start, intrinsic-end, and
component seed strategies. Disconnected candidate components can be treated as
single-inlet reachable-only, seeded independently, or blocked explicitly.

## Determinism

Scheduler ordering depends only on the frozen snapshot and scheduler
configuration. Rendering cadence controls how many committed batches are shown
per frame; it does not affect arrival order. Equal field-priority scores are
resolved by flat voxel index. Each state has a SHA-256 hash over the candidate
identity, scheduler configuration, seeds, batch index, and complete arrival
array.

The scheduler makes no physical-time claim. A batch is a discrete relational
activation step, not seconds, thermal time, or mechanical time.

## Milestone Comparison

The scheduler panel presents the frozen M3 static candidate count beside the M4
active and pending counts. JSON exports include a `baseline_comparison` object
with candidate, active, pending, illegal-activation, and mask-mismatch counts.

In Immediate mode, a completed M4 schedule must have zero mismatches against the
M3 static candidate mask. A completed Front Propagation run must reach that same
mask when the candidate graph is connected or every component is seeded.
Intermediate front states intentionally expose ordering while preserving field
identity.

## Materialization And Export

The operator may materialize the current partial state or complete the schedule
and materialize the final state. Advancing or invalidating a scheduler after
materialization marks the mesh stale. STL and call-sheet exports remain locked
until the materialized mesh matches the current scheduler state hash.

Raised transport veins remain disabled for partial scheduled states because the
current vein path does not yet have a scheduler-aware clipping contract.

## Diagnostics And Artifacts

The Scheduler panel reports candidate, active, frontier, unreachable, component,
batch, progress, timing, stop-reason, and state-hash values. XY, XZ, and YZ
slices visualize candidate, active, frontier, seed, and arrival layers.

`EXPORT METRICS` writes:

- `exports/scheduler/<timestamp>_<mode>_<state>/scheduler_metrics.csv`
- `exports/scheduler/<timestamp>_<mode>_<state>/scheduler_run.json`
- `exports/scheduler/<timestamp>_<mode>_<state>/arrival_order.bin`
- `exports/scheduler/<timestamp>_<mode>_<state>/arrival_order.json`
- `exports/scheduler/<timestamp>_<mode>_<state>/manifest.json`

Each export action creates one self-contained run directory. Existing flat
`logs/scheduler_*` files from earlier versions remain valid historical records.
Repeated `ARCHIVE RUN` actions during the same initialized scheduler run update
that run directory; initializing a new run starts a new archive directory.

The binary arrival volume uses little-endian signed 32-bit integers, flat
`x + nx * (y + ny * z)` ordering, `0` for seed activation, and `-1` for voxels
not activated in the exported state.

## Acceptance And Performance

Run the deterministic application matrix:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_m4 \
  --force --run --dcrte-m4-acceptance
```

Run the opt-in 64-cubed and 128-cubed scheduler benchmark:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/cosmosis-visual-observatory" \
  --output=/tmp/cosmosis_m4_benchmark \
  --force --run --dcrte-m4-benchmark
```

The benchmark uses a deterministic, fully admitted candidate cube so it measures
scheduler mechanics rather than field or mesh extraction cost. It writes
`logs/dcrte_m4_benchmark_latest.json`.

## Compatibility Contract

The Milestone 4 scheduler framework does not alter the recursive field, domain,
coordinate system, candidate-solid rule, mesh extraction rule, STL scale, or
call-sheet style. Immediate remains the default and is the compatibility bridge
to the established M0-M3 workflow.

A completed deterministic front-propagation run should reproduce the Immediate
final mask when all candidate components are deliberately reachable and no
early-stop rule is active.

## Explicit Deferrals

Milestone 4 does not implement entropy, stochastic activation, density or stress
fields, physical solvers, mesh repair, or new surface extraction. The existing
two-dimensional live entropy metric is not used by this three-dimensional
scheduler. Local entropy observables and the Emergent Entropic Scheduler remain
Milestone 5 work.
