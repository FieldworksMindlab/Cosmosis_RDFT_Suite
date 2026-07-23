# DCRTE-ET M6-HX Holographic Bridge Explorer

## Purpose And Scope

The Holographic Bridge Explorer (HBE) is an optional observation layer beside
the established Surface Foundry, scheduler, composition, and Geodesic Salon
workflows. It asks a narrow classical question: can a frozen information-like
control and a frozen nonlinear-feedback analog produce reproducible changes in
candidate connectivity, scheduler arrival order, and neck bottlenecks inside a
qualified voxel domain?

The experiment is directly inspired by the organization and qualitative
relations studied in:

> Biswas, D., Cheng, G., Karthikeyan, K., et al. (2026). Observation of
> gravity-like signatures in holographic codes on a quantum computer.
> arXiv:2607.12047v1. https://doi.org/10.48550/arXiv.2607.12047

HBE does not implement that paper's quantum code, quantum observables, tensor
network, gravity model, RT/QES surface, geodesic calculation, or wormhole. Its
outputs are explicitly labeled classical field, graph, and scheduler proxies.

> The Holographic Bridge Explorer is directly inspired by the experimental
> organization and qualitative relations studied by Biswas et al. It does not
> implement their quantum code, quantum observables, or gravitational
> interpretation. It converts selected relations into explicit classical field,
> graph, and scheduler proxies so that state-dependent connectivity can be
> tested reproducibly inside Cosmosis.

> "Magic analog" means a frozen nonlinear-feedback control derived from
> declared Cosmosis metrics. It is not quantum non-stabilizerness and is not a
> stabilizer Renyi entropy measurement.

## Isolation Contract

HBE is disabled by default. When disabled:

- the legacy scalar field is returned bit-for-bit;
- candidate classification is unchanged;
- seed and score resolution follow the existing M4/M5 paths;
- scheduler state hashes contain no HBE contribution;
- Surface Foundry, M6 composition, and Geodesic Salon behavior is unchanged.

Enabling HBE creates a frozen experiment snapshot. Any relevant upstream domain,
intrinsic-coordinate, candidate, or HBE configuration change invalidates that
snapshot. The operator must rebuild it before analysis or export.

## Data Path

```text
qualified imported domain
  -> strict SDF and M3 intrinsic coordinates
  -> immutable candidate snapshot
  -> frozen HBE metrics and intrinsic observables
  -> optional field channel before candidate classification
  -> optional seed and score channel inside the existing scheduler
  -> six-connected candidate and active graph analysis
  -> HBE evidence export
```

There is one scheduler. HBE adds declared seed and score terms to the existing
scheduler context; it does not run a hidden secondary scheduler.

## Canonical Fixture

`LOAD FIXTURE` generates a deterministic dual-lobe domain joined by a neck. The
mesh is written as STL and then passes through the normal importer, sanitizer,
preflight, SDF, and intrinsic-coordinate pipelines. The fixture is not trusted
through a special evaluator bypass.

The domain response can remain fixed or use a monotonic neck-shortening proxy.
This is a classical geometry control, not a gravitational deformation claim.

## Frozen Controls

`COUPLING` is a dimensionless classical control. `FEEDBACK` may be manual or
captured from a declared Observatory metric. Captured values are immutable for
the life of the snapshot; live panel motion cannot silently alter a running
experiment.

`CAPTURE FEEDBACK` makes that freeze explicit. It records the currently selected
feedback source without yet binding a domain or candidate mask. `BUILD SNAPSHOT`
then binds the frozen feedback to the current qualified domain, intrinsic
coordinates, and candidate state. Changing a relevant control invalidates both
and requires a deliberate recapture/rebuild.

Influence modes are:

- `ANALYSIS_ONLY`: observes the current candidate and active masks;
- `FIELD_ONLY`: applies a neck-local field modifier before candidate
  classification;
- `SCHEDULER_ONLY`: leaves candidate geometry unchanged and adds HBE seed/score
  terms to M4/M5;
- `FIELD_AND_SCHEDULER`: enables both declared channels.

The field modifier is exact identity outside an enabled field channel and exact
identity outside the declared neck support when `LOBE PROXY` is off. The optional
`MIRRORED_HIERARCHICAL_BRANCHING` lobe proxy adds a deterministic, bilaterally
mirrored ordered-field term away from the neck. It is disabled by default and
is only a classical morphology probe, not a tensor network or physical channel.
The existing material rule remains `abs(scalar) < isoBand`.

## What A Bridge Means

A candidate bridge is a six-connected path of candidate voxels from the left
anchor set to the right anchor set. An active bridge is the same path criterion
applied to scheduler-active voxels. Candidate disconnection or active
disconnection is a valid experimental result, not automatically a software
failure.

Reported observables include:

- candidate versus active connectivity;
- connected-component and largest-component counts;
- shortest voxel-path steps and world-length proxy;
- path tortuosity;
- minimum neck cross section and bottleneck location;
- left/right occupancy and bilateral balance;
- mirror occupancy and arrival agreement;
- first scheduler connection batch, tau, entropy, and meeting voxel;
- deterministic graph-pairing costs.

Path lengths are voxel-graph proxies. They are not geometric geodesics.

## Operator Workflow

1. Open the `HBE` lens.
2. Leave `HBE OFF` to confirm baseline identity, or click it to opt in.
3. Click `LOAD FIXTURE`, or prepare a qualified imported domain.
4. Select influence, feedback, domain, mirror, seed, and score policies.
5. Click `CAPTURE FEEDBACK` to freeze the selected live or manual control.
6. Click `BUILD SNAPSHOT`. If candidacy is not current, click
   `GENERATE CANDIDATE` and build again.
7. Use `INITIALIZE EES`, `STEP ONCE`, `RUN EES`, or `COMPLETE EES`.
8. Click `ANALYZE` to compare candidate and active connectivity.
9. Cycle `VIEW` to inspect masks, sides, neck support, mirror pairs, paths,
   field sensitivity, arrival state, and sweep results.
10. Run the fixed-envelope `11 x 6` sweep when desired.
11. Click `EXPORT HBE EVIDENCE` to write the manifest and CSV evidence.

The status readout distinguishes an absent valid path from invalid input,
snapshot staleness, and a software failure.

The interactive sweep is intentionally fixed-envelope: each of its 66 cells
starts from the same immutable candidate snapshot. The work order's full
geometry-rebuild/checkpoint sweep is not attached to this button because it
would repeatedly replace the imported domain, SDF, intrinsic chart, and
candidate state. That long-running operation remains a separate research-mode
insertion point rather than a hidden mutation of the working Observatory.

## Evidence

Exports are written beneath:

```text
exports/hbe/<timestamp>_<snapshot-hash>/
```

The package contains a JSON manifest, candidate/active metrics CSV, connection
path CSV, and optional sweep manifest/results/failures. Every artifact carries
the paper citation and the nonclaim metadata.

## Safety Fix: Composition Grid Identity

M6 composition now requires exact `VolumeSpec` identity between the candidate
volume and imported SDF before any flat-array access. A stale `64^3` SDF can no
longer be indexed by a later candidate grid. The condition reports
`M6_COMPOSITION_GRID_MISMATCH`, marks composition stale, and returns safely
instead of throwing `ArrayIndexOutOfBoundsException`.

## Verification

The startup HBE suite covers disabled defaults, deterministic configuration,
monotonic neck response, frozen feedback, fixture manifold validity, intrinsic
side observables, mirror mapping, candidate/active connectivity, exact field
identity, neck localization, opt-in lobe-proxy determinism, candidate accounting,
dual seeds, bilateral balance, graph-pairing determinism, channel isolation, and
sweep-cell reproducibility.

Build the sketch with Processing 4:

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/Cosmosis_Visual_Observatory" \
  --output="/tmp/cosmosis-hbe-build" --force --build
```

Run only HBE startup tests with `--dcrte-hbe-tests-only`. Running Processing
from a restricted shell may require permission for its debugger socket; a
successful build does not exercise those runtime tests.
