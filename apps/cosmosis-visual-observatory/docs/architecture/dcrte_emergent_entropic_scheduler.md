# DCRTE-ET Emergent Entropic Scheduler

## Scientific Framing

The Emergent Entropic Scheduler is a computational ordering policy. It
evaluates how hypothetical frontier activations change declared local entropy
observables and uses those changes, together with field and connectivity terms,
to select activation events. Its relational progress variable measures
cumulative internal state change and is not a physical clock.

The implementation tests a narrow proposition: a frozen recursive material
field can be ordered by state-dependent internal observables instead of only by
a fixed breadth-first deposition schedule.

It does not claim that:

- entropy is physical, proper, quantum, or emergent time;
- the scheduler simulates thermodynamic free energy;
- generated structures are self-organizing physical matter;
- a terminal state is universally optimal;
- a stable partial state is a global physical equilibrium.

An entropically stable configuration is stable only with respect to the
selected entropy model, score policy, acceptance rule, and thresholds. It is an
experimental result, not a universal equilibrium claim.

## Pipeline Boundary

M5 is additive and begins only after M0-M3 have produced an immutable
`CandidateVolumeSnapshot`:

```text
qualified observation domain
  -> coordinate system
  -> recursive field
  -> material candidacy
  -> immutable CandidateVolumeSnapshot
  -> M4 seed and frontier machinery
  -> M5 entropy evaluation and acceptance
  -> existing SchedulerBatch commit
  -> existing materializer and export gates
```

M5 never mutates the field scalar, signed distance, intrinsic coordinates,
candidate mask, admission mask, or material threshold. The final material rule
remains:

```text
finalSolid[i] =
    admitted[i]
    && candidateSolid[i]
    && active[i]
```

## Entropy Models

Entropy is model-dependent. Every run identifies and versions the model,
neighborhood, support rule, normalization, histogram bins, range policy,
acceptance rule, and stability thresholds.

### Binary Occupancy Entropy

`BinaryOccupancyEntropy` is the dynamic M5 observable. For a candidate-only
neighborhood with active fraction `p`:

```text
H_occ(p) = -(p ln p + (1-p) ln(1-p)) / ln 2
```

The limiting values at `p = 0` and `p = 1` are zero. The maximum at `p = 0.5`
is one. Admitted noncandidate voxels and coordinates outside the volume do not
contribute to support.

Available neighborhood declarations:

- propagation neighbors using the selected 6-, 18-, or 26-neighbor rule;
- cube radius 1;
- cube radius 2.

The center voxel can be included or excluded. Samples below the configured
minimum support are explicitly invalid and contribute zero rather than a
fabricated estimate.

### Field Histogram Entropy

`FieldHistogramEntropy` is a static field-complexity observable. Candidate field
values are assigned to the configured number of bins and normalized by
`ln(binCount)`:

```text
H_field = -sum(p_b ln p_b) / ln(binCount)
```

The default is eight bins over the global frozen candidate range. A constant
field has entropy zero. This model is not recomputed as occupancy changes.

## Hypothetical Activation Delta

Before committing a frontier candidate, M5 evaluates every local entropy center
whose neighborhood would contain that activation:

```text
delta_H = mean(H_after - H_before)
```

It also records mean absolute local change and the exact affected-center count.
The real active mask is never modified during this calculation.

## Exact Cache

`EntropyCache` stores occupancy entropy, field entropy, support count, and
validity in flat primitive arrays. After a batch commits, only centers affected
by newly active voxels are recomputed. At the configured interval and before
important terminal states, the cache is compared with a complete recomputation
at tolerance `1e-6`.

A mismatch is a hard validation failure. M5 does not silently downsample or
substitute an approximate entropy mode.

## Transparent Score

Every frontier record exposes normalized terms in `[0,1]`:

- field compatibility;
- entropy relaxation;
- entropy exploration;
- entropy balance;
- frontier coherence;
- interior depth;
- intrinsic direction, when available;
- coordinate confidence, when available;
- static field complexity;
- deterministic seeded noise.

Unavailable intrinsic terms are declared unavailable and omitted from the
effective weight denominator. All weights must be finite, nonnegative, and
normalize to one.

Formula version: `m5-score-1`.

### Policies

`RELAXATION` emphasizes entropy-decreasing and coherent events.

`EXPLORATION` emphasizes entropy-increasing, field-complex, and seeded-diverse
events.

`BALANCED` emphasizes events near the configured target entropy delta.

`ADAPTIVE_RELAX_EXPLORE` begins relaxation-dominant and temporarily increases
exploration weight and stochastic temperature after declared stagnation. Its
boost, hold, decay, and return transitions are exported. It cannot alter the
domain, field, candidacy, or material threshold.

## Acceptance

`DETERMINISTIC_THRESHOLD` accepts candidates at or above the configured score
threshold, bounded by the batch cap.

`DETERMINISTIC_TOP_K` sorts by descending score and then ascending flat voxel
index. It accepts up to the batch cap above the configured minimum top-K score.

`SEEDED_STOCHASTIC` computes:

```text
probability = sigmoid((score - threshold) / temperature)
```

The random value is a stateless 64-bit hash of scheduler seed, batch index,
voxel index, and policy salt. It does not use a sequential shared random stream,
so frontier enumeration and render cadence do not alter the result.

Random formula version: `m5-mix64-1`.

## Relational Progress

The dimensionless progress increment is:

```text
delta_tau =
    w_activation * newlyActivated / candidateCount
  + w_entropy * meanAbsoluteAcceptedEntropyChange
  + w_frontier * abs(frontierAfter-frontierBefore) / candidateCount
```

All default terms are nonnegative, so `tauRaw` is nondecreasing. `tau` is an
internal computational change measure. It is not seconds or a physical clock.

Formula version: `m5-tau-1`.

## Conditional Stability

The stability detector observes a configured rolling window of:

- activation fraction;
- mean absolute entropy change;
- frontier-change fraction;
- maximum available score relative to the threshold.

A stable partial state requires every criterion to remain below its epsilon for
the configured number of consecutive windows. Stable partial and complete
states are separate terminal labels. Partial materialization remains explicit
and uses the existing M4 materializer and export-currentness gate.

## Operator Interface

Choose `EMERGENT ENTROPIC` in the scheduler mode control. Basic controls expose
entropy neighborhood, policy, acceptance, batch cap, score threshold, and
temperature. Advanced controls expose the M4 seed/component/propagation rules,
minimum support, histogram bins, and stability window.

The M5 panel provides:

- entropy, score, probability, accepted/rejected, tau, and stability slice
  modes;
- direct inspection of the latest frontier score by flat voxel index;
- a tau and occupancy-entropy history plot;
- cache-verification status;
- policy and terminal-state readouts.

Changing scheduler configuration invalidates the current scheduled result and
requires reinitialization. M4 Immediate and Front Propagation remain available
and unchanged.

## Exports

M5 extends the existing scheduler report and arrival-order artifacts with:

- `exports/scheduler/<run>/entropic_metrics.csv`;
- `exports/scheduler/<run>/entropic_score_samples.json`, when score samples are enabled;
- M5 scheduler, entropy, score, policy, tau, stability, and cache provenance in
  `exports/scheduler/<run>/scheduler_run.json`;
- the existing arrival binary and descriptor.

Runtime milliseconds are diagnostic only and excluded from the state hash.

## Comparison With M4 Breadth-First Propagation

Front Propagation orders candidates by graph distance and optional frozen field
priority. M5 evaluates the current active state at every batch and can therefore
produce a different arrival order on the same frozen candidate mask.

Neither method is declared better without a task-specific criterion. The
comparison exports descriptive active fraction, batch count, stop reason,
entropy summaries, relational progress, and stable state hashes.

## Limits

M5 does not implement deactivation, annealing, physical temperature,
free-energy minimization, stress, pressure, fluid flow, chemistry,
reaction-diffusion equations, multiple material phases, machine-learned
policies, or inverse design. Exact frontier evaluation is intentionally more
expensive than M4 propagation.
