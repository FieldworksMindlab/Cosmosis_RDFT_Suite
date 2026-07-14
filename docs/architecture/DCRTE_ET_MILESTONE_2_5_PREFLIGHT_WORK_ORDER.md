# Work Order: DCRTE-ET Milestone 2.5

## Imported Mesh Preflight Diagnostics and Safe Domain Qualification

**Version:** 1.0  
**Status:** Ready for Codex implementation  
**Project:** Surface Foundry / Cosmosis RDFT Suite  
**Architecture:** DCRTE-ET Architecture Specification v0.3  
**Prerequisites:** Milestones 0, 1, and 2 have passed  
**Primary application:** `apps/cosmosis-visual-observatory/`

---

# 1. Purpose

Milestone 2 proved that Surface Foundry can:

- load an external STL;
- draw it in the imported-domain preview;
- validate it as a potential volumetric domain;
- construct a signed distance field for trusted closed meshes;
- block materialization when the imported mesh cannot safely define an inside and outside.

Milestone 2.5 must make that rejection process explicit, inspectable, spatially locatable, and actionable.

The system must not merely report:

```text
MESH INVALID
```

It must identify:

```text
what failed
where it failed
how severe the failure is
whether the failure is safe to sanitize
whether the mesh is usable for preview only
whether it may become usable after external repair
which corrective action is recommended
```

This milestone is a diagnostic and qualification layer.

It is not a general automatic mesh-repair system.

---

# 2. Core Principle

> A mesh that can be rendered is not automatically a trustworthy volumetric observation domain.

Rendering requires triangles.

A signed observation domain requires a reliable interior, exterior, boundary, orientation, scale, and resolvable feature structure.

Surface Foundry must distinguish these states:

```text
VISIBLE MESH
      |
      v
PARSEABLE MESH
      |
      v
TOPOLOGICALLY INSPECTABLE MESH
      |
      v
CLOSED DOMAIN CANDIDATE
      |
      v
SDF-QUALIFIED DOMAIN
      |
      v
MATERIALIZATION-QUALIFIED DOMAIN
```

Every imported mesh must receive an explicit qualification level.

---

# 3. Required Qualification Levels

Implement:

```java
enum DomainQualification {
  NOT_LOADED,
  PARSE_FAILED,
  PREVIEW_ONLY,
  TOPOLOGY_INVALID,
  TOPOLOGY_VALID_SDF_UNRESOLVED,
  SDF_VALID_MATERIALIZATION_BLOCKED,
  MATERIALIZATION_READY
}
```

Equivalent established naming is acceptable.

## 3.1 Meaning

### `NOT_LOADED`

No imported mesh is present.

### `PARSE_FAILED`

The file could not be interpreted as supported mesh data.

### `PREVIEW_ONLY`

Triangle geometry can be displayed, but topology or sign is unreliable.

### `TOPOLOGY_INVALID`

The mesh contains blocking topological defects such as open boundaries or non-manifold incidence.

### `TOPOLOGY_VALID_SDF_UNRESOLVED`

The mesh is closed and manifold, but voxelization, inside/outside classification, or signed-distance construction is unreliable at the selected resolution.

### `SDF_VALID_MATERIALIZATION_BLOCKED`

The SDF is usable, but downstream validation blocks fabrication, for example because resolved walls disappear, the final field is empty, or outside-domain material is detected.

### `MATERIALIZATION_READY`

The imported domain passed all required gates.

---

# 4. Diagnostic Severity

Implement:

```java
enum DiagnosticSeverity {
  INFO,
  WARNING,
  BLOCKER
}
```

Every diagnostic should use a structured record:

```java
class DomainDiagnostic {
  String code;
  DiagnosticSeverity severity;
  String stage;
  String title;
  String message;
  String recommendedAction;

  int count;
  float value;
  float threshold;

  int triangleIndex;
  int edgeVertexA;
  int edgeVertexB;
  int voxelIndex;

  float worldX;
  float worldY;
  float worldZ;

  boolean hasLocation;
  boolean isAutoSanitizable;
  boolean requiresTopologyChange;

  JSONObject toJSON();
}
```

Not every field must be populated for every diagnostic.

---

# 5. Preflight Stages

The report must preserve stage boundaries:

```text
1. FILE
2. PARSE
3. GEOMETRY
4. TOPOLOGY
5. COMPONENTS
6. ORIENTATION
7. SELF_INTERSECTION
8. TRANSFORM
9. RESOLUTION
10. BOUNDARY_VOXELIZATION
11. INSIDE_OUTSIDE
12. SIGNED_DISTANCE
13. MATERIALIZATION
14. EXPORT
```

The final report must identify:

- the first blocking stage;
- all known blockers measured safely before that point;
- warnings;
- skipped stages;
- the reason each stage was skipped.

Do not continue into an expensive or semantically invalid stage when an earlier blocker makes the result meaningless.

---

# 6. Required Diagnostic Identifier Set

Implement the identifiers below or a clearly documented equivalent.

---

## 6.1 File and parse diagnostics

```text
PF_FILE_NOT_FOUND
PF_FILE_UNREADABLE
PF_FILE_EMPTY
PF_FORMAT_UNSUPPORTED
PF_STL_FORMAT_AMBIGUOUS
PF_BINARY_LENGTH_MISMATCH
PF_ASCII_PARSE_INCOMPLETE
PF_TRIANGLE_LIMIT_EXCEEDED
PF_SOURCE_COORDINATE_NONFINITE
PF_SOURCE_UNITS_UNSPECIFIED
PF_SOURCE_SCALE_EXTREME
PF_SOURCE_HASH_FAILURE
```

Required behavior:

- `PF_SOURCE_UNITS_UNSPECIFIED` is informational unless preserve-scale behavior is later added.
- `PF_SOURCE_SCALE_EXTREME` warns when source dimensions risk numeric instability before normalization.
- Full local paths remain private by default.

---

## 6.2 Geometry sanitation diagnostics

```text
PF_ZERO_AREA_TRIANGLES
PF_NEAR_ZERO_AREA_TRIANGLES
PF_INVALID_TRIANGLE_INDICES
PF_DUPLICATE_TRIANGLES
PF_COPLANAR_DUPLICATE_FACES
PF_DUPLICATE_VERTICES
PF_NEAR_DUPLICATE_VERTICES
PF_ISOLATED_VERTICES
PF_INVALID_BOUNDS
PF_ZERO_VOLUME_BOUNDS
PF_EXTREME_ASPECT_RATIO
```

Safe automatic sanitation may include:

- invalid triangles that reference unusable geometry;
- zero-area triangles;
- exact duplicate triangles;
- exact duplicate vertices;
- near-duplicate vertices within the established conservative tolerance;
- isolated unused vertices.

Automatic sanitation must not be described as topological repair.

`PF_COPLANAR_DUPLICATE_FACES` may indicate duplicated shells or internal surfaces. Do not delete uncertain coplanar faces unless they are exact orientation-independent duplicates.

---

## 6.3 Topology diagnostics

```text
PF_BOUNDARY_EDGES
PF_BOUNDARY_LOOPS
PF_BOUNDARY_LOOP_LARGE
PF_BOUNDARY_LOOP_SMALL
PF_NONMANIFOLD_EDGES
PF_NONMANIFOLD_VERTICES
PF_BOWTIE_VERTICES
PF_T_JUNCTION_CANDIDATES
PF_DISCONNECTED_COMPONENTS
PF_TINY_DISCONNECTED_COMPONENTS
PF_OPEN_COMPONENTS
PF_CLOSED_COMPONENTS_MULTIPLE
PF_NESTED_SHELLS
PF_INTERNAL_SHELL_CANDIDATE
PF_COMPONENT_CONTACT_OR_OVERLAP
```

For every boundary loop, report:

- loop index;
- edge count;
- approximate perimeter;
- world-space bounding box;
- centroid;
- largest and smallest loop;
- representative location.

For every disconnected component, report:

- component index;
- triangle count;
- vertex count;
- surface area estimate;
- signed or absolute volume where valid;
- bounding box;
- closed or open status;
- fraction of total surface area and volume.

Strict mode must block:

- any boundary edge;
- any non-manifold edge;
- any non-manifold vertex;
- open components;
- unresolved component contact or overlap;
- nested shells whose inside/outside semantics remain ambiguous.

Multiple disconnected closed shells should be blocked by default unless an explicit, tested multi-shell policy already exists.

---

## 6.4 Orientation diagnostics

```text
PF_INCONSISTENT_EDGE_WINDING
PF_COMPONENT_WINDING_INCONSISTENT
PF_GLOBAL_WINDING_INVERTED
PF_COMPONENT_WINDING_INVERTED
PF_SIGNED_VOLUME_NEAR_ZERO
PF_SIGNED_VOLUME_CONFLICT
PF_NORMAL_FIELD_UNRELIABLE
```

Safe automatic action:

- A single closed consistently oriented component with negative signed volume may be globally flipped.

Multiple components may be normalized separately only when:

- every component is independently closed;
- no components intersect;
- containment semantics are known;
- all actions are reported.

Otherwise block.

---

## 6.5 Self-intersection and overlap diagnostics

```text
PF_SELF_INTERSECTION
PF_SELF_INTERSECTION_SUSPECTED
PF_TRIANGLE_OVERLAP
PF_COPLANAR_OVERLAP
PF_COMPONENT_INTERSECTION
PF_INTERNAL_FACE_CANDIDATE
```

Required first implementation:

1. Build a broad-phase spatial index using triangle AABBs and a uniform grid or spatial hash.
2. Generate deterministic candidate triangle pairs.
3. Skip ordinary adjacent triangles sharing an edge where appropriate.
4. Run triangle-triangle intersection on candidates.
5. Distinguish expected adjacency from crossing.
6. Record representative triangle pairs and intersection locations.

Requirements:

- report whether the result is confirmed or suspected;
- report tested pair count;
- block strict SDF when confirmed intersections exist;
- warn when candidate density exceeds tested capability;
- never silently accept self-intersecting surfaces as reliable boundaries.

---

## 6.6 Transform and fit diagnostics

```text
PF_TRANSFORM_INVALID
PF_TRANSFORM_NONINVERTIBLE
PF_TRANSFORM_OUTSIDE_OBSERVER
PF_TRANSFORM_MARGIN_TOO_SMALL
PF_TRANSFORM_CLIPPING
PF_TRANSFORM_ASPECT_PRESERVATION_FAILURE
PF_ROTATION_STATE_INVALID
PF_SOURCE_TO_WORLD_PRECISION_LOSS
```

Required checks:

- the transformed mesh fits inside SDF bounds with margin;
- no triangle is clipped by the build volume;
- uniform fitting preserves aspect ratio;
- repeated rotations derive from immutable source data;
- inverse transform error remains within tolerance.

---

## 6.7 Resolution and feature diagnostics

```text
PF_VOXEL_RESOLUTION_TOO_LOW
PF_FEATURE_BELOW_ONE_VOXEL
PF_FEATURE_BELOW_TWO_VOXELS
PF_THIN_WALL_UNRESOLVED
PF_NARROW_CHANNEL_UNRESOLVED
PF_COMPONENT_DISAPPEARS_AT_RESOLUTION
PF_BOUNDARY_ALIASING_HIGH
PF_RESOLUTION_CONVERGENCE_POOR
PF_GRID_MEMORY_LIMIT
PF_GRID_TIME_LIMIT
```

Estimate feature-size risk from:

1. source-mesh edge and triangle-altitude statistics;
2. post-voxelization boundary occupancy and component persistence.

Report:

```text
voxel spacing
minimum source edge
5th percentile source edge
median source edge
minimum triangle altitude
5th percentile triangle altitude
estimated minimum resolved wall
estimated minimum resolved channel
```

Do not equate source triangle size with physical wall thickness. Label mesh-derived values as risk indicators.

Implement:

```java
class ResolutionSuitability {
  float voxelSpacing;
  float meshDiagonal;
  float edgeP05;
  float triangleAltitudeP05;
  float boundaryCoverageRatio;
  float estimatedConfidence;
  int recommendedMinimumResolution;
  ArrayList<String> reasons;

  JSONObject toJSON();
}
```

Recommended display:

```text
64^3   LOW CONFIDENCE
128^3  ACCEPTABLE
256^3  RECOMMENDED, NOT CURRENTLY SUPPORTED
```

Never silently alter resolution.

---

## 6.8 Boundary voxelization diagnostics

```text
PF_BOUNDARY_VOXELIZATION_EMPTY
PF_TRIANGLE_MARKED_NO_VOXELS
PF_BOUNDARY_COVERAGE_GAPS
PF_BOUNDARY_THICKNESS_EXCESSIVE
PF_BOUNDARY_FRAGMENTED
PF_BOUNDARY_COMPONENT_MISMATCH
PF_BOUNDARY_TOUCHES_GRID_EDGE
PF_BOUNDARY_VOXEL_COUNT_IMPLAUSIBLE
```

Required checks:

- each triangle maps to candidate voxels or is explicitly marked below resolution;
- boundary does not touch build bounds after correct fitting;
- boundary components are compared with source-mesh components;
- obvious boundary gaps are reported;
- boundary band does not consume an implausibly high fraction of the grid.

---

## 6.9 Inside/outside diagnostics

```text
PF_PARITY_ODD_INTERSECTION_COUNT
PF_PARITY_RETRY_REQUIRED
PF_PARITY_RETRY_FAILED
PF_PARITY_INCONSISTENT_AXIS
PF_INSIDE_MASK_EMPTY
PF_INSIDE_MASK_FULL
PF_INSIDE_COMPONENT_MISMATCH
PF_INTERIOR_LEAK
PF_EXTERIOR_POCKET
PF_SIGN_ISLAND
PF_AMBIGUOUS_VOXELS
```

### Cross-axis verification

Use:

- primary X-axis parity classification;
- Y-axis or Z-axis verification on a configurable subset or full grid;
- full secondary-axis verification at `64^3` when practical.

Report disagreement count and locations.

Confirmed disagreement above tolerance is a blocker.

### Flood-fill verification

From the grid exterior, flood-fill through non-boundary voxels.

Expected:

- reached cells are exterior;
- unreached non-boundary cells are interior.

Compare:

```text
parity inside count
flood-fill inside count
disagreement voxel count
largest disagreement component
representative disagreement locations
```

Nonzero disagreement above tolerance blocks strict materialization.

---

## 6.10 Signed-distance diagnostics

```text
PF_SDF_NONFINITE
PF_SDF_SIGN_CONFLICT
PF_SDF_ZERO_BAND_EMPTY
PF_SDF_ZERO_BAND_EXCESSIVE
PF_SDF_GRADIENT_INVALID
PF_SDF_GRADIENT_DIRECTION_CONFLICT
PF_SDF_DISTANCE_NONMONOTONIC
PF_SDF_VOLUME_ERROR_HIGH
PF_SDF_RESOLUTION_INSTABILITY
PF_SDF_GRID_MISMATCH
```

Required checks:

- all distances finite;
- zero band nonempty;
- interior sign negative;
- exterior sign positive;
- sampled volume plausible;
- gradient generally points outward near the boundary;
- observer and SDF grids match explicitly or interpolate intentionally;
- fixture results are compared at `64^3` and `128^3`.

---

## 6.11 Materialization diagnostics

```text
PF_FIELD_NONFINITE
PF_FINAL_VOLUME_EMPTY
PF_FINAL_VOLUME_FULL
PF_OUTSIDE_DOMAIN_MATERIAL
PF_FINAL_COMPONENTS_EXCESSIVE
PF_FINAL_COMPONENT_TOO_SMALL
PF_MINIMUM_FEATURE_UNPRINTABLE
PF_RAISED_VEIN_DOMAIN_ESCAPE
PF_MATERIALIZER_FAILURE
PF_EXPORT_DISABLED
```

Preflight must explain whether the failure belongs to:

- source mesh;
- topology;
- resolution;
- SDF;
- field configuration;
- material rule;
- fabrication validation.

---

# 7. Recommended Action Identifiers

Map warnings and blockers to standardized action codes:

```text
ACTION_REEXPORT_WATERTIGHT
ACTION_CLOSE_BOUNDARY_LOOPS
ACTION_REMOVE_NONMANIFOLD_GEOMETRY
ACTION_UNIFY_NORMALS
ACTION_REMOVE_INTERNAL_FACES
ACTION_SEPARATE_INTERSECTING_SHELLS
ACTION_BOOLEAN_UNION_COMPONENTS
ACTION_DELETE_TINY_COMPONENTS
ACTION_INCREASE_SDF_RESOLUTION
ACTION_INCREASE_SOURCE_MESH_QUALITY
ACTION_REDUCE_DOMAIN_SCALE_MARGIN
ACTION_REORIENT_DOMAIN
ACTION_SIMPLIFY_SOURCE_MESH
ACTION_INSPECT_SELF_INTERSECTIONS
ACTION_USE_UNSIGNED_PREVIEW
ACTION_ADJUST_FIELD_THRESHOLD
ACTION_ADJUST_SHELL_THICKNESS
ACTION_DISABLE_RAISED_VEINS
ACTION_RETRY_WITH_CANONICAL_FIXTURE
```

Do not automatically execute topology-changing actions.

---

# 8. Preflight Report Structure

Implement:

```java
class DomainPreflightReport {
  String reportVersion;
  DomainQualification qualification;
  ValidationStatus status;

  String sourceName;
  String sourceHashSha256;

  ArrayList<DomainDiagnostic> diagnostics;
  ArrayList<String> blockers;
  ArrayList<String> warnings;
  ArrayList<String> information;

  MeshDomainReport meshReport;
  ResolutionSuitability resolutionSuitability;
  SDFQualityReport sdfReport;
  DCRTEValidationReport materializationReport;

  String firstBlockingStage;
  String recommendedNextAction;

  boolean previewEnabled;
  boolean sdfBuildEnabled;
  boolean materializationEnabled;
  boolean exportEnabled;

  JSONObject toJSON();
}
```

The report must remain valid even when downstream stages were not run.

Example:

```json
{
  "qualification": "topology_invalid",
  "first_blocking_stage": "topology",
  "sdf_report": null,
  "sdf_stage": "not_run_due_to_topology_blocker",
  "preview_enabled": true,
  "sdf_build_enabled": false,
  "materialization_enabled": false,
  "export_enabled": false
}
```

---

# 9. Diagnostic Geometry

Add selectable overlays:

- boundary edges;
- boundary loops;
- non-manifold edges;
- disconnected components;
- self-intersection points or candidate regions;
- transformed bounds;
- boundary voxels;
- parity disagreement voxels;
- flood-fill disagreement voxels;
- SDF sign islands;
- unresolved thin regions.

Every overlay must include a numerical legend.

Do not rely only on color.

## 9.1 Issue navigation

Provide next/previous issue controls.

Example:

```text
ISSUE 3 OF 184
PF_BOUNDARY_LOOP_SMALL
EDGES 6
PERIMETER 0.018
CENTER (0.21, -0.48, 0.07)
ACTION CLOSE BOUNDARY LOOP AND REEXPORT
```

---

# 10. Preflight UI

Add a dedicated preflight panel or collapsible block.

Required summary:

```text
DOMAIN QUALIFICATION  TOPOLOGY INVALID
FIRST BLOCKER         PF_BOUNDARY_EDGES
BOUNDARY EDGES        184
BOUNDARY LOOPS        3
NONMANIFOLD EDGES     0
COMPONENTS            2
SELF INTERSECTIONS    0 CONFIRMED
SDF RESOLUTION        64^3 LOW CONFIDENCE
SDF BUILD             DISABLED
MATERIALIZATION       DISABLED
EXPORT                DISABLED
RECOMMENDED ACTION    CLOSE BOUNDARY LOOPS AND REEXPORT
```

Required controls:

```text
RUN PREFLIGHT
SHOW BLOCKERS
SHOW WARNINGS
NEXT ISSUE
PREVIOUS ISSUE
EXPORT REPORT JSON
COPY SUMMARY
USE UNSIGNED PREVIEW
```

A warning acknowledgement must never override a blocker.

---

# 11. Safe Sanitation Policy

Implement:

```java
enum SanitationPolicy {
  NONE,
  SAFE_AUTOMATIC,
  SAFE_WITH_CONFIRMATION
}
```

## 11.1 Safe automatic actions

Allowed when thresholds are conservative:

- remove zero-area triangles;
- remove invalid-index triangles;
- remove exact duplicate triangles;
- merge exact duplicate vertices;
- merge near-duplicate vertices within the established tolerance;
- remove isolated unused vertices;
- globally flip one valid closed component with inverted winding.

## 11.2 Confirmation-required actions

May be offered but not run silently:

- merge vertices at an expanded tolerance;
- remove tiny closed disconnected components;
- normalize winding per disconnected component;
- remove exact coplanar duplicate faces when confidence is high.

## 11.3 Deferred topology-changing repair

Do not implement:

- hole filling;
- boundary-loop triangulation;
- Boolean union;
- self-intersection resolution;
- remeshing;
- shell thickening;
- non-manifold surgery;
- component bridging;
- Poisson reconstruction.

The report may recommend external repair or future repair modules.

---

# 12. External Invalid STL Reference Case

Preserve the real external STL that currently:

- imports;
- previews;
- fails materialization.

Register it locally as a user-managed reference case:

```text
DCRTE-M2-INVALID-EXT-001
```

Do not commit it if ownership or licensing is unclear.

Record:

- source hash;
- source filename;
- parser result;
- sanitation result;
- first blocker;
- blocker counts;
- representative locations;
- selected resolution;
- failed stage;
- recommended action.

Milestone 2.5 passes only when this case produces a materially more useful report than the current generic failure.

---

# 13. Deterministic Fixtures

Use the existing Milestone 2 fixtures and add:

## 13.1 Small triangular hole

Closed cube with one triangle removed.

Expected:

- one boundary loop;
- boundary-edge count greater than zero;
- strict rejection;
- hole location visible.

## 13.2 Large boundary opening

Cube with one full face removed.

Expected:

- one large boundary loop;
- larger perimeter than small-hole fixture;
- `PF_BOUNDARY_LOOP_LARGE`.

## 13.3 Bowtie vertex

Two surface fans touching at one vertex without a manifold neighborhood.

Expected:

- `PF_NONMANIFOLD_VERTICES` or `PF_BOWTIE_VERTICES`.

## 13.4 Intersecting shells

Two closed cubes overlapping.

Expected:

- component overlap;
- confirmed triangle intersections;
- strict rejection.

## 13.5 Nested shells

One closed cube inside another.

Expected:

- nested-shell diagnostic;
- preview available;
- strict blocking unless tested cavity semantics are explicitly implemented.

## 13.6 Thin wall

A wall below one voxel at `64^3`.

Expected:

- low-resolution warning;
- improved result at `128^3`;
- no claim that the wall is resolved at `64^3`.

## 13.7 Tiny disconnected shell

Large cube plus a very small closed tetrahedron.

Expected:

- two components;
- tiny-component warning;
- no automatic deletion without confirmation.

---

# 14. Acceptance Criteria

Milestone 2.5 passes when:

## 14.1 Classification

- every imported mesh receives a qualification level;
- first blocking stage is explicit;
- skipped stages explain why;
- preview, SDF, materialization, and export permissions are explicit.

## 14.2 Diagnostics

- boundary edges and loops are counted;
- non-manifold edges are counted;
- non-manifold vertices are detected;
- disconnected components are characterized;
- winding failures are characterized;
- confirmed self-intersections block strict SDF;
- transform clipping is detected;
- low resolution is reported;
- parity and flood-fill results are compared;
- SDF sign failures are distinguished from source-topology failures;
- materialization failures are distinguished from domain failures.

## 14.3 Safety

- no topology-changing repair runs automatically;
- safe sanitation is logged;
- invalid meshes cannot bypass export gates;
- warnings cannot override blockers;
- no final material appears outside a trusted domain.

## 14.4 Regression

- canonical egg remains valid;
- imported cube remains valid;
- imported sphere remains valid;
- open and non-manifold fixtures remain blocked;
- primitive domains still work;
- adapter test still passes;
- legacy direct mode still works;
- call sheets and exports remain available.

---

# 15. Recommended Commit Sequence

```text
1. feat: add domain qualification and staged diagnostic model
2. feat: add standardized preflight identifier catalog
3. feat: add boundary-loop extraction and metrics
4. feat: add connected-component and component-volume reporting
5. feat: add nonmanifold-vertex and bowtie detection
6. feat: add broad-phase self-intersection diagnostics
7. feat: add resolution-suitability report
8. feat: add parity versus flood-fill verification
9. feat: add diagnostic overlays and issue navigation
10. feat: add preflight panel and report export
11. test: add hole, bowtie, overlap, nested, thin-wall, and tiny-shell fixtures
12. test: run external invalid STL reference case
13. test: run milestone 0-2 regression suite
14. docs: document sanitation, blockers, and corrective actions
```

---

# 16. Compact Codex Prompt

```text
Implement DCRTE-ET Milestone 2.5 as an imported-mesh preflight and domain-qualification layer.

Milestone 2 already imports and previews external STL files, builds SDFs for valid meshes, and safely blocks invalid meshes. Extend that behavior so failures are staged, inspectable, spatially locatable, and actionable.

Add DomainQualification, DiagnosticSeverity, DomainDiagnostic, DomainPreflightReport, standardized PF_* identifiers, standardized ACTION_* recommendations, boundary-loop extraction, nonmanifold-vertex detection, component analysis, orientation diagnostics, broad-phase self-intersection diagnostics, resolution-suitability scoring, boundary-voxel diagnostics, parity-versus-flood-fill verification, SDF diagnostics, materialization-stage diagnostics, diagnostic overlays, issue navigation, and JSON report export.

Keep strict export gates. Separate safe sanitation from topology-changing repair. Allow only conservative sanitation such as degenerate-face removal, exact duplicate removal, near-duplicate welding within the established tolerance, isolated-vertex removal, and a global winding flip for one valid closed component. Do not implement hole filling, Boolean union, remeshing, self-intersection repair, or nonmanifold surgery.

Use the external STL that currently previews but fails as a local negative reference case and produce a precise first blocker, counts, locations, failed stage, and recommended action. Preserve all Milestone 0-2, legacy, primitive-domain, egg, call-sheet, and export behavior.

Treat the attached work order as the architecture contract.
```

---

# 17. Handoff to Milestone 3

Milestone 3 must consume only domains that reach:

```text
MATERIALIZATION_READY
```

or a specifically permitted research state with stable SDF and interior classification.

The preflight report must expose:

```text
single dominant closed component
elongation ratio
principal-axis confidence
inside-mask connectivity
SDF resolution confidence
thin-feature risk
nested-shell status
self-intersection status
component count
```

Milestone 3 must not attempt intrinsic coordinates when sign, connectivity, or dominant-component structure is unreliable.

---

**End of Work Order**
