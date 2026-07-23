# DCRTE-ET Boundary-Anchored Composition

## Purpose

Milestone 6 adds a fabrication composition layer after the scheduler and before
the existing materializer. It combines an authoritative source-derived shell
with the scheduled recursive scaffold while preserving the established M0-M5
field, coordinate, candidacy, scheduling, and export contracts.

M6 is composition, not deformation. It does not move the imported surface,
rewrite recursive field equations, or mutate scheduler activation and arrival
arrays.

```text
qualified imported domain and signed distance
  -> immutable candidate snapshot
  -> M4 or M5 scheduler state
  -> M6 source shell and role composition
  -> existing voxel materializer
  -> existing manifold and export gates
```

## Canonical Torus Fixture

The imported-domain toolbar provides equal `LOAD STL`, `LOAD EGG`, and
`LOAD TORUS` fixture controls in both compact and full preflight layouts.

The torus is generated with:

- major radius `0.62`;
- minor radius `0.22`;
- 96 major segments;
- 48 minor segments;
- outward triangle winding.

The generated mesh is written to deterministic binary STL, released, and then
reloaded through the normal STL importer, sanitizer, transform, preflight,
voxelization, and SDF path. There is no torus-specific evaluator bypass.

Cartesian sampling and M6 shell composition are supported. The existing
intrinsic axial coordinate system remains intentionally blocked with
`IC_CLOSED_LOOP_SUSPECTED`; M6 does not pretend that a single axial coordinate
is valid around a closed loop.

The strict SDF preflight can reject a coarse torus grid with
`PF_SDF_VOLUME_ERROR_HIGH`. Increase imported resolution rather than weakening
the gate.

## Authoritative Source Shell

M6 requires a current preflight report with:

- one qualified closed manifold component by default;
- no open or non-manifold incidence;
- no unresolved self-intersection;
- a valid signed-distance field;
- no blocker through the signed-distance stage.

The SDF is the authoritative envelope. A current valid SDF can enter M6 before
the final composed material has earned export readiness. `MATERIALIZATION_READY`
is therefore not required to build the source shell; it is earned later after
composition and materialization pass.

Nested shells and ambiguous multiple bodies are blocked. The production role
is `SINGLE_QUALIFIED_COMPONENT`; dominant and explicit roles are available only
when preflight exposes an unambiguous component choice.

The inward shell is:

```text
domainInside = sdf <= boundaryEpsilon

sourceShell =
    sdf <= boundaryEpsilon
    && sdf >= -(fabricationShellThickness + boundaryEpsilon)
```

The default thickness is three voxels. The range is 1-32 voxels, with a warning
below two. Shell construction is independent from the observation mode, so an
operator can use `HARD_INTERIOR` observation with `SHELL_PLUS_SCAFFOLD`
fabrication.

Locked source-shell voxels must survive regularization. Any attempted or actual
locked-shell loss is reported and blocks authoritative export.

## Composition Modes

`SCAFFOLD_ONLY`

Uses the exact M5 scheduled active mask and exact legacy materializer route.
This is the regression baseline.

`SHELL_ONLY`

Materializes only the inward source-derived fabrication shell.

`SHELL_PLUS_SCAFFOLD`

Unions the source shell and scheduled scaffold without automatic attachment
correction. Attachment analysis remains visible.

`BOUNDARY_ANCHORED_SCAFFOLD`

Combines the source shell and scheduler state under the selected attachment
policy. Boundary-derived seeds can be resolved through the existing
`SeedStrategy` interface before Front or Entropic scheduling.

`INSET_SCAFFOLD`

Removes scheduled scaffold from a declared clearance band inward from the
source shell before composition. The removed voxel count is exported.

The composition volume keeps separate flat role arrays for domain, shell,
scheduled scaffold, inset scaffold, anchor bridges, support material, composed
material, locked material, and regularized material. Roles are not collapsed
until final materialization.

## Boundary Seeds

Boundary seed modes reuse the existing deterministic scheduler machinery:

- source-shell voxel nearest the domain center;
- source-shell intrinsic start or end when valid;
- selected shell patch;
- deterministic distributed farthest-point seeds.

Boundary seeding never changes the candidate mask. It only selects legal
candidate voxels within the inward source-shell seed band.

## Attachment Analysis

Scaffold components are classified as:

- boundary attached;
- near-boundary unattached;
- floating interior;
- below the minimum component size.

The report includes component counts, attached fraction, contact faces, contact
area, and a local attachment-thickness proxy.

Attachment policies are:

- `VALIDATE_ONLY`;
- `REQUIRE_EXISTING_CONTACT`;
- `SEED_FROM_BOUNDARY`;
- `BRIDGE_FIELD_CONSTRAINED`;
- `BRIDGE_DOMAIN_CONSTRAINED`.

Field-constrained bridges use deterministic shortest paths through candidate
voxels. Domain-constrained bridges may add explicit support material inside the
source envelope. Support voxels remain a separate role and are never described
as recursive field material. The default maximum bridge length is six voxels
and the default dilation radius is 1.5 voxels.

If no legal path exists, the failure is explicit and no invalid material is
added.

## Operator Workflow

1. Open `Surface Foundry` and select the imported DCRTE pipeline.
2. Load an STL, egg fixture, or torus fixture.
3. Run preflight and build a strict SDF.
4. Build the recursive field and initialize or run the desired scheduler.
5. Open the preflight inspector and choose `COMPOSITION`.
6. On `ENVELOPE`, select the mode, shell thickness, source role, clearance,
   and shell lock.
7. Click `BUILD SOURCE SHELL`, then `COMPOSE ROLES`.
8. On `ATTACH`, select the attachment and boundary-seed policies, analyze
   components, and compose bridges when requested.
9. Cycle the role overlay to inspect shell, scaffold, attachment, bridges,
   support, composed, or all roles.
10. On `REPORT`, review blockers, fidelity, locked-shell loss, outside-domain
    count, role counts, and hashes.
11. Click `MATERIALIZE`; export remains locked until the composed material and
    printable mesh pass the existing gates.

Changing the source mesh, transform, SDF resolution, scheduler state, or any M6
configuration marks the composition stale and requires recomposition.

## Validation And Provenance

M6 reports:

- source name, hash, component role, and SDF identity;
- configuration and composition hashes;
- shell thickness in voxels, world units, and millimeters;
- observation, coordinate, scheduler, and composition modes;
- scheduler batch, state, and hash;
- counts for every material role;
- clearance removal and locked-shell removal attempts;
- component attachment classes and bridge outcomes;
- source-boundary coverage and exterior-envelope distance metrics;
- materializer manifold status and stale state.

The JSON report is exported from the `REPORT` page. Authoritative M6 settings
also appear on Surface Foundry call sheets. `SCAFFOLD_ONLY` preserves the
existing M5 output behavior and does not add authoritative shell claims.

## Deterministic Verification

The standard startup suite includes 32 M6 checks. The full application matrix
adds cases M6-A through M6-P.

```bash
/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/Cosmosis_Visual_Observatory" \
  --output="/tmp/cosmosis-m6-tests" --force --run \
  --args --dcrte-m6-tests-only

/Applications/Processing.app/Contents/MacOS/Processing cli \
  --sketch="/path/to/Cosmosis_Visual_Observatory" \
  --output="/tmp/cosmosis-m6-acceptance" --force --run \
  --args --dcrte-m6-acceptance
```

The acceptance report is written to:

```text
logs/dcrte_m6_acceptance_latest.json
```

## Scope Limits

M6 does not implement topology optimization, finite-element analysis, stress
simulation, shell offsetting from exact triangle normals, multi-material slicer
semantics, automatic nested-shell role inference, branching intrinsic
coordinates, or closed-loop intrinsic coordinates. It makes no physical-time
claim. Those limits are reported rather than silently approximated.

Milestone 7 behavior is not implemented by this layer.
