# Work Order: DCRTE-ET Milestone 2

## Imported Mesh Observation Domains and Signed Distance Fields

**Version:** 1.0  
**Status:** Ready for Codex implementation  
**Project:** Surface Foundry / Cosmosis RDFT Suite  
**Architecture:** DCRTE-ET Architecture Specification v0.3  
**Prerequisites:** Milestones 0 and 1 have passed all acceptance tests  
**Primary application:** `apps/cosmosis-visual-observatory/`  
**Primary sketch:** `Cosmosis_Visual_Observatory.pde`

---

# 1. Codex Directive

Implement Milestone 2 of the Domain-Constrained Recursive Topology Engine with Emergent Entropic Scheduling.

Milestone 2 must allow Surface Foundry to load a closed, watertight STL mesh and use that mesh as an observation domain for the existing recursive field.

The imported mesh is not a deformation target.

The imported mesh must be:

1. parsed into a reusable triangle-mesh representation;
2. inspected and validated;
3. transformed into the DCRTE observation coordinate system;
4. voxelized into a boundary representation;
5. classified as inside or outside;
6. converted into a signed distance volume;
7. exposed through the existing `ObservationDomain` interface;
8. passed through the existing Observation Layer, field engine, immediate scheduler, validation, legacy materializer, preview, and export paths.

The milestone must include a deterministic, procedurally generated egg-shaped STL fixture. The egg is a canonical validation target and demonstration object, not a special production-only domain class. It must pass through the same STL writer, importer, validator, SDF builder, and materialization path as any other imported STL.

Required support:

- binary STL import;
- ASCII STL import where feasible;
- source-file hashing and provenance;
- triangle-mesh sanitation;
- watertight and manifold inspection;
- strict rejection of unreliable open domains;
- normalized fit transform;
- voxelized surface boundary;
- inside/outside classification;
- signed distance volume at `64^3`;
- signed distance volume at `128^3` as a supported research mode;
- hard-interior observation;
- inside-only shell-band observation;
- mesh preview;
- SDF slice preview;
- field materialization inside the imported domain;
- invalid-domain preview with export disabled;
- deterministic egg, cube, sphere, and open-mesh fixtures;
- complete JSON metadata and validation reports.

Do not implement OBJ import, automatic hole filling, general mesh surgery, intrinsic coordinates, medial axes, entropic scheduling, mechanical simulation, adaptive sampling, hyperuniformity analysis, or new production meshing algorithms in this milestone.

---

# 2. Core Principle

> **Fields are primary. Geometry is emergent.**

Milestone 1 demonstrated:

```text
same recursive field
    + primitive observation domain
    = a new material realization
```

Milestone 2 extends the Observation Layer from analytic primitives to imported closed meshes:

```text
same recursive field
    + imported watertight STL
    = a material realization inside that STL domain
```

The imported target must never be used to warp or deform a finished recursive object.

The imported target supplies only:

- a boundary;
- an inside/outside relation;
- a signed distance field;
- a transform between source and observation coordinates;
- optional boundary-relative measurements.

The core material rule remains:

```text
finalSolid(x) =
    importedDomainAdmits(x)
    AND
    existingMaterialRule(field(x))
```

For shell-band observation:

```text
finalSolid(x) =
    insideImportedDomain(x)
    AND
    absInteriorDistance(x) <= shellThickness
    AND
    existingMaterialRule(field(x))
```

---

# 3. Milestone Goal

Prove this complete pipeline:

```text
Watertight STL
      |
      v
TriangleMeshData
      |
      v
Mesh sanitation and validity report
      |
      v
Source-to-observation transform
      |
      v
Boundary voxelization
      |
      v
Inside/outside classification
      |
      v
SignedDistanceVolume
      |
      v
ImportedMeshDomain
      |
      v
Existing Observation Layer
      |
      v
Existing FieldEngine
      |
      v
Existing material rule
      |
      v
Immediate scheduler
      |
      v
Legacy materializer adapter
      |
      v
Validation, preview, STL, and JSON export
```

Milestone 2 passes when a valid egg-shaped STL can be generated, imported, inspected, voxelized, viewed as SDF slices, populated by the existing recursive field, exported, and printed without any field-derived material appearing outside the egg domain.

---

# 4. Scope Decision: Egg Target

The egg target should be incorporated now, but it must not become a special-case shortcut.

Do not add:

```text
if domain == EGG:
    use custom egg mask
```

Instead, add a procedural fixture generator that creates a valid triangle mesh, writes it to STL, then re-imports it through the standard Milestone 2 path.

This gives the project an early ovoid target while simultaneously testing the general imported-mesh architecture.

The egg fixture serves four purposes:

1. a visually meaningful target;
2. an asymmetric closed shape that is more demanding than a sphere;
3. an elongated shape that prepares the codebase for Milestone 3 intrinsic coordinates;
4. a repeatable round-trip test for STL writing, import, validation, transform, SDF construction, and materialization.

The egg is a reference observation domain, not a claim of biological or structural equivalence to any specific natural egg.

---

# 5. Pre-Implementation Inspection

Before editing code, inspect the actual Milestone 0 and Milestone 1 implementation.

Codex must identify and report the implemented names and file locations for:

- `FieldEngine`;
- `LegacyTopologyScalarAdapter`;
- `ObservationDomain`;
- `SphereDomain`;
- `BoxDomain`;
- `CylinderDomain`;
- `UniformGridObserver`;
- `ObservationLayer`;
- `HardInteriorObservation`;
- `ShellBandObservation`;
- `DCRTEVolume`;
- immediate scheduler;
- DCRTE validation report;
- legacy materializer adapter;
- pipeline selector;
- metadata exporter;
- primitive-domain preview;
- Surface Foundry file export;
- any existing worker-thread or job system;
- all keyboard and mouse controls.

Also identify:

- how the current observer bounds are represented;
- whether `64^3` and `128^3` volume specifications are already supported;
- how world coordinates are converted to output millimeters;
- whether raised transport veins are disabled or clipped in DCRTE primitive mode;
- which code owns the current selected domain;
- which code owns the current final solid volume;
- whether the current domain interface assumes analytic SDF sampling.

Do not duplicate established interfaces. Extend them in the smallest compatible way.

If Milestone 1 used different names than this work order, preserve the implemented names and document the mapping.

---

# 6. Pipeline Modes

Extend the existing pipeline selector.

Target modes:

```java
enum FoundryPipelineMode {
  LEGACY_DIRECT,
  DCRTE_ADAPTER_TEST,
  DCRTE_PRIMITIVE,
  DCRTE_IMPORTED_MESH
}
```

Equivalent established names are acceptable.

## 6.1 `LEGACY_DIRECT`

Must remain unchanged.

## 6.2 `DCRTE_ADAPTER_TEST`

Must retain Milestone 0 field-equivalence diagnostics.

## 6.3 `DCRTE_PRIMITIVE`

Must retain all Milestone 1 sphere, box, and cylinder behavior.

## 6.4 `DCRTE_IMPORTED_MESH`

Must:

- require a loaded mesh source;
- require a valid or explicitly preview-only import state;
- build or reuse a `SignedDistanceVolume`;
- expose that volume as an `ImportedMeshDomain`;
- use the existing observer and Observation Layer;
- use the existing `FieldEngine`;
- use the immediate scheduler;
- use the existing DCRTE volume and materializer adapter;
- use the existing raised-vein safety policy;
- emit import, SDF, and transform metadata;
- disable final mesh export when domain validity is unreliable.

The startup default should remain the current established mode.

---

# 7. New PDE Tabs

Create the following tabs unless equivalent tabs already exist:

```text
DCRTE_MeshData.pde
DCRTE_STLImporter.pde
DCRTE_MeshValidation.pde
DCRTE_MeshTransform.pde
DCRTE_BoundaryVoxelizer.pde
DCRTE_InsideOutside.pde
DCRTE_DistanceTransform.pde
DCRTE_SignedDistanceVolume.pde
DCRTE_ImportedMeshDomain.pde
DCRTE_EggFixture.pde
DCRTE_M2_Tests.pde
```

Optional, if the sketch already uses asynchronous build jobs:

```text
DCRTE_SDFBuildJob.pde
```

Do not move the whole application into packages.

## 7.1 Responsibility boundaries

### `DCRTE_MeshData.pde`

Contains:

- `TriangleMeshData`;
- compact vertex and triangle storage;
- source and transformed bounds;
- triangle access helpers;
- mesh statistics;
- source-mesh immutability rules.

### `DCRTE_STLImporter.pde`

Contains:

- generic `TriangleMeshImporter` interface;
- `STLMeshImporter`;
- binary STL parser;
- ASCII STL parser;
- format detection;
- file-size and triangle-count safety limits;
- source SHA-256 hash.

The generic importer interface is required so a later `OBJMeshImporter` can be added without changing downstream systems.

### `DCRTE_MeshValidation.pde`

Contains:

- sanitation pass;
- degenerate-triangle removal;
- near-duplicate vertex merge;
- boundary-edge detection;
- non-manifold-edge detection;
- orientation inspection;
- signed volume calculation;
- `MeshDomainReport`;
- strict invalid-domain policy.

### `DCRTE_MeshTransform.pde`

Contains:

- source-to-observation transform;
- normalized fit;
- center and uniform scale;
- optional 90-degree axis rotations;
- inverse transform;
- transform metadata.

### `DCRTE_BoundaryVoxelizer.pde`

Contains:

- conservative triangle-to-grid boundary rasterization;
- boundary mask;
- triangle candidate range calculation;
- point-to-triangle distance helper;
- voxelization report.

### `DCRTE_InsideOutside.pde`

Contains:

- deterministic parity scanline classifier;
- intersection deduplication;
- ambiguous-row retries;
- inside mask;
- classification report.

### `DCRTE_DistanceTransform.pde`

Contains:

- Euclidean or documented approximate grid distance transform;
- no domain-specific logic;
- no UI drawing.

### `DCRTE_SignedDistanceVolume.pde`

Contains:

- SDF storage;
- direct grid sampling;
- trilinear world-coordinate sampling;
- normal sampling from central differences;
- SDF quality report;
- serialization metadata.

### `DCRTE_ImportedMeshDomain.pde`

Contains:

- `ImportedMeshDomain`;
- adapter from `SignedDistanceVolume` to `ObservationDomain`;
- direct-index fast path when observer and SDF grids match;
- preview-only state enforcement.

### `DCRTE_EggFixture.pde`

Contains:

- parametric egg mesh generator;
- valid outward-wound triangulation;
- deterministic binary STL writer for the fixture;
- optional UI command to create and load the canonical egg.

This file must not contain production egg-specific masking.

### `DCRTE_M2_Tests.pde`

Contains:

- deterministic mesh fixtures;
- importer tests;
- topology tests;
- SDF tests;
- volume tests;
- round-trip tests;
- regression runner.

---

# 8. Core Mesh Data Structures

Use flat primitive arrays.

## 8.1 TriangleMeshData

Target structure:

```java
class TriangleMeshData {
  float[] vertices;   // xyzxyzxyz...
  int[] triangles;    // abcabcabc...

  int vertexCount;
  int triangleCount;

  Bounds3D sourceBounds;
  Bounds3D worldBounds;

  String sourceName;
  String sourceFormat;
  String sourceHashSha256;

  boolean sourceNormalsPresent;
  boolean transformed;

  float vx(int vertexIndex);
  float vy(int vertexIndex);
  float vz(int vertexIndex);

  int ia(int triangleIndex);
  int ib(int triangleIndex);
  int ic(int triangleIndex);

  TriangleMeshData copyTransformed(MeshTransform transform);
  boolean isStructurallyValid();
}
```

Do not store one object per vertex or one object per triangle.

Normals from STL may be imported for diagnostics, but geometric normals computed from triangle vertices are authoritative.

## 8.2 MeshDomainReport

```java
class MeshDomainReport {
  ValidationStatus status;

  String sourceName;
  String sourceFormat;
  String sourceHashSha256;

  long sourceBytes;
  int declaredTriangleCount;
  int parsedTriangleCount;

  int inputVertexCount;
  int outputVertexCount;
  int duplicateVerticesMerged;

  int inputTriangleCount;
  int outputTriangleCount;
  int zeroAreaTrianglesRemoved;
  int invalidIndexTrianglesRemoved;
  int duplicateTrianglesRemoved;

  int uniqueEdgeCount;
  int boundaryEdgeCount;
  int nonManifoldEdgeCount;
  int inconsistentOrientationEdgeCount;

  boolean watertight;
  boolean manifold;
  boolean consistentlyOriented;
  boolean globalWindingFlipped;

  double signedVolumeSource;
  double absoluteVolumeSource;
  double signedVolumeWorld;
  double absoluteVolumeWorld;

  Bounds3D sourceBounds;
  Bounds3D worldBounds;

  ArrayList<String> errors;
  ArrayList<String> warnings;

  JSONObject toJSON();
}
```

## 8.3 MeshTransform

```java
class MeshTransform {
  float sourceCenterX;
  float sourceCenterY;
  float sourceCenterZ;

  float worldCenterX;
  float worldCenterY;
  float worldCenterZ;

  float uniformScale;

  int rotateXQuarterTurns;
  int rotateYQuarterTurns;
  int rotateZQuarterTurns;

  float fitMargin;
  String mode;

  void apply(float x, float y, float z, float[] out);
  void applyInverse(float x, float y, float z, float[] out);

  JSONObject toJSON();
}
```

The transform must be deterministic and reversible within floating-point tolerance.

## 8.4 VoxelBoundaryVolume

```java
class VoxelBoundaryVolume {
  VolumeSpec spec;
  boolean[] boundary;
  int boundaryCount;

  int sourceTriangleCount;
  int candidateVoxelTests;
  int markedBoundaryVoxels;

  JSONObject toJSON();
}
```

## 8.5 InsideOutsideVolume

```java
class InsideOutsideVolume {
  VolumeSpec spec;
  boolean[] inside;

  int insideCount;
  int outsideCount;
  int ambiguousScanlineCount;
  int retriedScanlineCount;
  int failedScanlineCount;
  int deduplicatedIntersectionCount;

  JSONObject toJSON();
}
```

## 8.6 SignedDistanceVolume

```java
class SignedDistanceVolume {
  VolumeSpec spec;

  float[] signedDistance;
  boolean[] inside;
  boolean[] boundary;

  float minDistance;
  float maxDistance;

  int finiteCount;
  int nonFiniteCount;
  int zeroBandCount;

  float sampleAtIndex(int x, int y, int z);
  float sampleWorld(float x, float y, float z);

  void normalAtIndex(int x, int y, int z, float[] outNormal);
  void normalWorld(float x, float y, float z, float[] outNormal);

  JSONObject toJSON();
}
```

Do not store three full normal arrays unless profiling proves this is necessary.

Compute normals on demand from SDF differences.

---

# 9. Import Policy

## 9.1 Required format

Milestone 2 requires STL.

Support:

- binary STL;
- ASCII STL where feasible.

Do not add OBJ yet.

Create the generic interface now:

```java
interface TriangleMeshImporter {
  TriangleMeshData load(File file);
  String getFormatId();
  boolean supports(File file);
}
```

A future OBJ importer must be able to return the same `TriangleMeshData`.

## 9.2 File selection

Use Processing's file-selection mechanism, such as:

```java
selectInput("Select a watertight STL observation domain", "meshSelected");
```

Requirements:

- do not build the SDF inside the file callback before the import report is shown;
- retain the last successfully loaded source;
- canceling selection must not destroy the current domain;
- full local paths should not be exported by default;
- export source filename and SHA-256 hash;
- source units must be recorded as unspecified unless the user explicitly supplies them.

## 9.3 Safety limits

Add configurable safety limits.

Recommended defaults:

```text
warning triangle count: 100,000
soft maximum:           500,000
hard refusal:         2,000,000
```

Also reject:

- files too short to contain a valid STL;
- declared binary triangle counts inconsistent with impossible file size;
- non-finite vertex coordinates;
- meshes with no valid triangles;
- meshes with a zero-size bounding box.

Do not allocate based solely on an untrusted triangle count without checking file length and integer overflow.

## 9.4 STL format detection

Do not assume a file beginning with `solid` is ASCII.

Preferred detection:

1. read file length;
2. inspect binary triangle count at byte 80;
3. compute expected binary length:

```text
84 + 50 * triangleCount
```

4. if expected length matches or is safely plausible, parse as binary;
5. otherwise attempt ASCII parsing;
6. if both fail, return a structured import error.

Use little-endian decoding for binary STL.

## 9.5 Binary STL parsing

For every triangle:

- read and ignore or store the source normal;
- read three vertices;
- read attribute byte count;
- reject non-finite values;
- append raw vertices and triangle indices;
- do not trust source normals for winding.

## 9.6 ASCII STL parsing

Accept common case-insensitive tokens:

```text
solid
facet normal
outer loop
vertex
endloop
endfacet
endsolid
```

Requirements:

- tolerate ordinary whitespace;
- tolerate scientific notation;
- reject incomplete facets;
- do not execute or interpret arbitrary text;
- report line number for parse errors where practical.

---

# 10. Mesh Sanitation

Milestone 2 may perform safe, transparent sanitation.

It must not perform speculative geometry reconstruction.

## 10.1 Required sanitation operations

- remove triangles with invalid indices;
- remove triangles containing non-finite vertices;
- remove zero-area or near-zero-area triangles;
- merge near-duplicate vertices;
- optionally remove exact duplicate triangles;
- compute geometric triangle normals;
- inspect edge incidence;
- inspect orientation consistency;
- compute signed volume;
- flip all triangle windings if the mesh is closed, consistently oriented, and globally inward.

## 10.2 Near-duplicate vertex merge

Use quantized spatial hashing.

Recommended quantization tolerance:

```text
mergeTolerance =
  max(sourceBoundsDiagonal * 1e-6, 1e-7)
```

Make the tolerance configurable and export it.

Quantized key example:

```text
qx = round(x / tolerance)
qy = round(y / tolerance)
qz = round(z / tolerance)
```

Handle key overflow safely.

Do not merge vertices across a tolerance large enough to alter visible geometry.

## 10.3 Zero-area triangles

Compute:

```text
area2 = length(cross(b - a, c - a))
```

Reject triangles when:

```text
area2 <= areaTolerance
```

Tie tolerance to source scale.

## 10.4 Edge map

Represent each undirected edge by sorted vertex indices:

```text
edge(min(a,b), max(a,b))
```

Track:

- total incidence count;
- directed orientation contributed by each triangle.

Classification:

```text
count == 1  -> boundary edge
count == 2  -> manifold candidate
count > 2   -> non-manifold edge
```

For `count == 2`, the two triangles must traverse the shared edge in opposite directions for local orientation consistency.

## 10.5 Watertight status

A mesh is watertight for Milestone 2 only when:

```text
boundaryEdgeCount == 0
AND
nonManifoldEdgeCount == 0
AND
triangleCount > 0
```

## 10.6 Orientation

A mesh is consistently oriented when all manifold shared edges have opposite directed traversal.

For a watertight, consistently oriented mesh:

```text
signedVolume =
  sum(dot(a, cross(b, c))) / 6
```

If signed volume is negative and magnitude is meaningful:

- flip every triangle winding;
- recompute signed volume;
- record `globalWindingFlipped = true`.

Do not flip disconnected or unreliable open meshes and then call them valid.

---

# 11. Invalid Domain Policy

Implement these policies:

```java
enum InvalidDomainPolicy {
  STRICT,
  UNSIGNED_PREVIEW
}
```

Do not implement automatic hole filling in Milestone 2.

## 11.1 `STRICT`

Required for field materialization and export.

Reject SDF sign generation when:

- mesh is not watertight;
- mesh is non-manifold;
- orientation is inconsistent and cannot be resolved by one global flip;
- source bounds are invalid;
- transformed bounds are invalid;
- classification fails above the allowed ambiguity threshold.

The mesh may remain visible as a wireframe preview, but:

```text
SDF BUILD DISABLED
MATERIALIZATION DISABLED
STL EXPORT DISABLED
```

## 11.2 `UNSIGNED_PREVIEW`

Allow:

- mesh preview;
- boundary voxel preview;
- unsigned distance preview where available;
- import-report inspection.

Disallow:

- inside/outside claims;
- signed SDF export;
- field materialization;
- final STL export.

Display a persistent warning:

```text
PREVIEW ONLY - DOMAIN SIGN IS UNRELIABLE
```

## 11.3 Safe sanitation is not repair

Removing degenerate faces, merging duplicate vertices, and globally reversing winding are sanitation.

Filling holes, bridging gaps, remeshing, or altering topology are repair and are deferred.

Never label sanitation as a successful repair of an open mesh.

---

# 12. Source-to-Observation Transform

STL coordinates are unitless.

Do not infer millimeters, inches, anatomy, or real-world scale.

## 12.1 Default mode

Use:

```text
FIT_CENTERED_UNIFORM
```

Procedure:

1. compute source bounds;
2. compute source center;
3. subtract source center;
4. apply selected quarter-turn rotations;
5. recompute rotated bounds;
6. apply one uniform scale so the largest dimension fits inside the observer bounds with margin;
7. translate to observer center.

Recommended default fit margin:

```text
0.08 of the smallest observer dimension
```

For normalized `[-1, 1]^3` bounds, the transformed mesh should fit approximately inside `[-0.92, 0.92]`.

## 12.2 Required transform controls

- reset transform;
- center and fit;
- rotate X by 90 degrees;
- rotate Y by 90 degrees;
- rotate Z by 90 degrees;
- increase or decrease uniform scale within bounds;
- optional translation nudges if UI space permits.

Every transform change invalidates the current SDF and requires a rebuild.

## 12.3 Transform preservation

Store:

- original source vertices;
- transformed world vertices;
- source bounds;
- transformed bounds;
- uniform scale;
- quarter-turn rotations;
- translation;
- inverse transform;
- fit margin.

Never repeatedly transform already-transformed vertices. Always derive world vertices from immutable source data.

## 12.4 Output scale

The imported source transform and final fabrication scale are separate.

Record:

```text
source coordinates
    -> normalized observation coordinates
    -> Surface Foundry output millimeters
```

Do not claim that the exported object preserves the source STL's real-world dimensions unless an explicit preserve-scale mode is added later.

---

# 13. Mesh Preview

Display the transformed imported mesh before SDF construction.

Required preview modes:

- wireframe;
- translucent surface;
- face-normal diagnostic optional;
- invalid-edge overlay;
- transformed bounding box.

Color is a UI aid only.

## 13.1 Invalid-edge overlay

When practical:

- boundary edges should be visually distinguishable;
- non-manifold edges should be visually distinguishable;
- orientation errors may be indicated separately.

The UI must also provide numerical counts so the preview is not color-dependent.

## 13.2 Large mesh preview

For very large meshes:

- permit preview stride or face limit;
- clearly label preview decimation;
- always validate and voxelize from the full accepted mesh unless the user explicitly chooses otherwise.

Do not silently voxelize only the preview subset.

---

# 14. SDF Construction Overview

The first implementation should prioritize transparent correctness over maximal speed.

Required stages:

```text
transformed watertight mesh
      |
      v
conservative boundary voxelization
      |
      v
deterministic inside/outside classification
      |
      v
distance transform from boundary
      |
      v
apply negative sign inside
      |
      v
SDF quality checks
```

A completed SDF build must be immutable for downstream use.

## 14.1 Supported resolutions

Required:

- `64^3`.

Supported research mode:

- `128^3`.

Optional debug:

- `32^3`.

Do not implement `256^3` or `512^3` dense imported-mesh SDFs in Milestone 2.

## 14.2 Isotropic grid requirement

For the first implementation, use cubic resolution and cubic observer bounds so voxel spacing is isotropic.

If existing observer bounds are not cubic:

- embed the mesh in a cubic SDF build volume;
- record the build bounds separately;
- do not distort the imported mesh.

This simplifies distance-transform accuracy and error interpretation.

---

# 15. Conservative Boundary Voxelization

The boundary voxelizer must mark grid cells intersecting or lying close to mesh triangles.

## 15.1 Required method

For each transformed triangle:

1. compute the triangle world-space AABB;
2. expand the AABB by the voxel half diagonal plus epsilon;
3. convert expanded bounds to clamped voxel index ranges;
4. iterate candidate voxel centers;
5. compute point-to-triangle distance;
6. mark a voxel as boundary when the distance is less than or equal to a conservative threshold.

Recommended threshold:

```text
boundaryThreshold =
  0.5 * voxelDiagonal + boundaryEpsilon
```

where:

```text
voxelDiagonal = sqrt(dx^2 + dy^2 + dz^2)
```

## 15.2 Point-to-triangle distance

Implement a standard closest-point-on-triangle calculation using vertex, edge, and face regions.

Requirements:

- no per-call object allocation in the hot loop;
- handle degenerate triangles defensively even though sanitation should remove them;
- return squared distance when possible to avoid unnecessary square roots;
- include deterministic tests for face, edge, and vertex nearest points.

## 15.3 Boundary report

Record:

- triangle count;
- total candidate voxel tests;
- marked boundary voxels;
- boundary fraction;
- build time;
- threshold;
- voxel spacing;
- triangles that mapped to zero candidate voxels;
- any out-of-bounds triangles.

A valid fitted mesh should not contain transformed triangles outside the SDF build bounds.

---

# 16. Inside/Outside Classification

Use deterministic parity classification.

## 16.1 Preferred first-pass method: X-axis scanlines

For each `(y, z)` voxel-center row:

1. cast an infinite line parallel to world X;
2. compute all intersections with mesh triangles;
3. sort intersection X coordinates;
4. deduplicate intersections closer than a tolerance;
5. classify intervals by odd-even parity;
6. mark voxel centers inside when they lie between an odd and even crossing.

This is more efficient than casting a separate full triangle ray for every voxel.

## 16.2 Triangle intersection in YZ projection

For an X-axis line at fixed `(y, z)`:

- project the triangle into the YZ plane;
- test whether `(y, z)` lies within the projected triangle;
- skip triangles whose projected area is below tolerance;
- use barycentric interpolation to determine intersection X.

Use a consistent half-open or deduplication policy to avoid counting shared edges twice.

## 16.3 Intersection deduplication

Sort intersections and merge values when:

```text
abs(x[i] - x[i - 1]) <= intersectionTolerance
```

Recommended initial tolerance:

```text
0.20 * voxelSpacing
```

Export the actual value.

## 16.4 Deterministic jitter retry

If a scanline produces an odd number of unique intersections:

1. retry with a tiny deterministic Y offset;
2. retry with a tiny deterministic Z offset;
3. optionally retry with both;
4. never use unseeded randomness.

Recommended jitter magnitude:

```text
1e-4 * voxelSpacing
```

The jitter must be small enough not to cross a voxel cell.

## 16.5 Failed scanlines

If parity remains ambiguous:

- increment `failedScanlineCount`;
- mark the row classification as invalid;
- fail strict SDF construction if failures exceed tolerance.

Recommended strict tolerance:

```text
failedScanlineCount == 0
```

A temporary allowance of a tiny number may be used only if every affected voxel is conservatively treated as outside and the build is labeled `PASS_WITH_WARNINGS`. Final material must never enter an ambiguously classified region.

## 16.6 Boundary voxels

Boundary voxels may be assigned:

```text
signedDistance = 0
```

For the inside mask, choose one documented policy and use it consistently.

Recommended:

```text
boundary voxels are admitted as inside for hard-interior observation
```

This matches Milestone 1 boundary-epsilon behavior and reduces accidental open surfaces.

---

# 17. Distance Transform

The signed distance does not need exact triangle distance everywhere in Milestone 2, but it must be stable, monotonic, finite, and tied to voxel scale.

## 17.1 Required algorithm

Preferred implementation:

> Three-dimensional squared Euclidean distance transform applied as successive one-dimensional transforms along X, Y, and Z.

Initialize:

```text
f[i] = 0       for boundary voxels
f[i] = INF     elsewhere
```

Run a one-dimensional squared-distance transform over every line in:

1. X;
2. Y;
3. Z.

Then:

```text
unsignedDistance = sqrt(squaredDistance) * voxelSpacing
```

This produces exact Euclidean distance to the nearest marked boundary voxel center on an isotropic grid.

It is not exact distance to the original triangle surface. Report this explicitly.

## 17.2 Alternative fallback

A documented 26-neighbor chamfer transform may be used only if the exact grid EDT cannot be completed within Processing constraints.

If chamfer distance is used:

- identify it in metadata;
- include neighbor weights;
- compare it against analytic fixtures;
- do not call it exact Euclidean distance.

## 17.3 Signed distance

Apply sign:

```text
if boundary:
    sdf = 0
else if inside:
    sdf = -unsignedDistance
else:
    sdf = +unsignedDistance
```

## 17.4 Optional half-voxel correction

An optional correction may shift non-boundary magnitudes by half a voxel to better approximate the original surface:

```text
correctedDistance =
  max(0, unsignedDistance - 0.5 * voxelSpacing)
```

This must be:

- configurable;
- disabled or enabled consistently;
- recorded in metadata;
- validated against primitive mesh fixtures.

Do not tune the correction separately for the egg.

---

# 18. SDF Sampling and Normals

## 18.1 Direct-index fast path

When the DCRTE observer has the same `VolumeSpec` as the SDF:

```java
float sampleAtIndex(int x, int y, int z)
```

must be used.

Do not trilinearly interpolate values already aligned to the same grid.

## 18.2 World-coordinate sampling

For generic `ObservationDomain.sample(x, y, z)`:

- convert world coordinate to continuous grid coordinate;
- reject or return positive outside distance beyond the SDF bounds;
- trilinearly interpolate the eight neighboring SDF values;
- return sign and distance.

## 18.3 Normal sampling

Compute:

```text
gradX = D(x + 1, y, z) - D(x - 1, y, z)
gradY = D(x, y + 1, z) - D(x, y - 1, z)
gradZ = D(x, y, z + 1) - D(x, y, z - 1)
```

Use one-sided differences at grid edges.

Normalize the gradient.

The SDF convention requires the normal to point toward increasing distance, which is outward from a valid closed domain.

If gradient magnitude is too small:

- return a fallback normal;
- set normal validity false;
- report low-gradient sample count only if normals are precomputed for diagnostics.

---

# 19. ImportedMeshDomain

Implement:

```java
class ImportedMeshDomain implements ObservationDomain {
  TriangleMeshData sourceMesh;
  TriangleMeshData worldMesh;
  MeshDomainReport meshReport;
  MeshTransform transform;
  SignedDistanceVolume sdf;
  InvalidDomainPolicy invalidPolicy;

  DomainSample sample(float x, float y, float z);
  DomainSample sampleAtIndex(int x, int y, int z);

  Bounds3D bounds();
  float analyticVolume();
  String getId();
  String getVersion();
  JSONObject toJSON();

  boolean isValid();
  boolean isPreviewOnly();
  String validationMessage();
}
```

## 19.1 Volume terminology

For imported meshes, `analyticVolume()` should return the absolute signed triangle-mesh volume in world coordinates when validity permits.

This is a geometric mesh-volume estimate, not an analytic formula.

Use metadata naming that distinguishes it:

```json
"reference_volume_type": "signed_triangle_mesh_volume"
```

## 19.2 Grid compatibility

If SDF and observer specifications differ:

- do not silently index one grid with the other;
- use world-coordinate interpolation;
- display a warning;
- record the two specifications.

Preferred Milestone 2 behavior is to build the SDF on the same grid used for field observation.

---

# 20. Observation Layer Integration

Reuse Milestone 1 observation modes.

Required:

- hard interior;
- inside-only shell band.

## 20.1 Hard interior

```text
admitted = sdf <= boundaryEpsilon
```

## 20.2 Inside-only shell band

```text
admitted =
    sdf <= boundaryEpsilon
    AND
    sdf >= -(shellThickness + boundaryEpsilon)
```

## 20.3 Invalid domains

If imported domain is preview-only:

- Observation Layer may display the boundary;
- it must return `admitted = false` for materialization;
- final mesh export must remain disabled.

## 20.4 No field changes

Do not change field equations to make them fit an egg or any imported shell.

Do not modify field frequency automatically based on mesh dimensions.

Any future scale-adaptive field behavior must be an explicit coordinate or constraint feature in a later milestone.

---

# 21. Materialization and Export

Reuse the Milestone 1 materializer adapter.

## 21.1 Final solid rule

```text
finalSolid =
    importedMeshDomainAdmitted
    AND
    existingFieldCandidateSolid
    AND
    immediateSchedulerActive
```

## 21.2 Outside-domain gate

For every final solid voxel:

```text
sdf <= boundaryEpsilon
```

Any violation is a hard failure.

## 21.3 Raised veins

Retain the established Milestone 1 policy.

If primitive-mode veins were disabled until clipping, imported-mesh mode must also disable them.

If clipping was implemented, every vein point and segment must be checked against the imported SDF.

Record:

```json
"raised_veins": {
  "requested": true,
  "applied": false,
  "reason": "disabled_until_imported_sdf_clipping"
}
```

Do not allow vein geometry outside the imported shell.

## 21.4 Export gate

Final STL export is enabled only when:

- mesh report is valid under `STRICT`;
- SDF build is valid;
- field volume is non-empty;
- outside-domain material count is zero;
- scalar values are finite;
- legacy materializer succeeds.

JSON diagnostics and preview images may still be exported for failed research runs if clearly labeled.

---

# 22. User Interface

Add an Imported Domain block inside Surface Foundry.

Do not redesign the full application.

## 22.1 Required controls

```text
LOAD STL
LOAD EGG FIXTURE
REBUILD SDF
CANCEL BUILD
FIT / CENTER
ROTATE X 90
ROTATE Y 90
ROTATE Z 90
RESET TRANSFORM
RESOLUTION 32 / 64 / 128
POLICY STRICT / UNSIGNED PREVIEW
SLICE AXIS XY / XZ / YZ
SLICE INDEX
SHOW MESH
SHOW BOUNDARY VOXELS
SHOW SDF SLICE
SHOW MATERIAL
```

`CANCEL BUILD` is required only if a background build job is implemented. Otherwise show a warning before starting `128^3`.

## 22.2 Required status display

```text
PIPELINE          DCRTE IMPORTED
SOURCE            dcrte_egg_fixture.stl
FORMAT            BINARY STL
SOURCE SHA         8f4a...2c91
TRIANGLES          12,096
WATERTIGHT         YES
MANIFOLD           YES
ORIENTED           YES
BOUNDARY EDGES      0
NONMANIFOLD EDGES   0
SDF RESOLUTION      64^3
INSIDE VOXELS       91,284
BOUNDARY VOXELS     14,602
SDF STATUS          PASS
OBSERVATION         HARD INTERIOR
FINAL SOLID         22,041
OUTSIDE SOLID       0
BUILD TIME          7.42 s
EXPORT              ENABLED
```

Values are examples only.

## 22.3 Failure display

Example:

```text
DOMAIN INVALID
BOUNDARY EDGES: 184
STRICT SDF DISABLED
PREVIEW ONLY
```

The user must not have to inspect logs to discover invalid-domain status.

## 22.4 Carrier versus domain

Continue to label these separately:

```text
FIELD CARRIER       GYROID
OBSERVATION DOMAIN  IMPORTED STL
SOURCE MESH         DCRTE EGG FIXTURE
```

---

# 23. SDF Slice Preview

Add a clear SDF diagnostic view.

Required axes:

- XY;
- XZ;
- YZ.

Required overlays:

- negative interior;
- zero or near-zero boundary band;
- positive exterior;
- optional final solid voxels;
- optional original triangle intersections.

The UI may use color, but also display:

- slice axis;
- slice index;
- world coordinate;
- min and max SDF on slice;
- inside count;
- boundary count;
- outside count.

## 23.1 Boundary band

For visualization:

```text
abs(sdf) <= 0.75 * voxelSpacing
```

may be treated as the zero band.

This is a display threshold, not the formal Observation Layer epsilon.

## 23.2 Slice navigation

Slice index must be clamped to the selected resolution.

Changing slice index must not rebuild the SDF.

---

# 24. Canonical Egg Fixture

## 24.1 Purpose

The canonical egg is the first non-primitive imported observation-domain target.

It must be:

- smooth;
- closed;
- asymmetric along one axis;
- deterministic;
- manifold;
- outward wound;
- free of duplicate poles;
- suitable for `64^3` and `128^3` SDF tests.

## 24.2 Parametric profile

Use Y as the long axis.

For:

```text
u in [0, PI]
v in [0, 2PI)
```

define:

```text
y = halfHeight * cos(u)

radial =
  baseRadius
  * sin(u)
  * (1 - asymmetry * cos(u))

x = radial * cos(v)
z = radial * sin(v)
```

Recommended defaults:

```text
halfHeight = 1.20
baseRadius = 0.78
asymmetry  = 0.18
```

Interpretation:

- `u = 0` is the narrower upper pole;
- `u = PI` is the broader lower pole;
- the shape remains closed because `sin(u) = 0` at both poles.

This is an averaged computational ovoid, not a taxonomic model.

## 24.3 Mesh construction

Recommended fixture resolution:

```text
latitude segments  = 64
longitude segments = 96
```

Requirements:

- create one top-pole vertex;
- create one bottom-pole vertex;
- create intermediate latitude rings;
- wrap longitude seam;
- create triangle fans at poles;
- create two triangles per quad between rings;
- verify outward winding;
- do not create 96 duplicate coincident vertices at each pole.

## 24.4 Round-trip path

The acceptance test must perform:

```text
generate egg TriangleMeshData
    -> write deterministic binary STL
    -> release generated in-memory mesh
    -> import STL through STLMeshImporter
    -> sanitize and validate
    -> fit and transform
    -> build SDF
    -> materialize field
```

Do not pass the generated mesh directly to `ImportedMeshDomain` in the primary round-trip acceptance test.

## 24.5 Egg metadata

Record fixture parameters:

```json
"fixture": {
  "type": "canonical_egg",
  "version": "1.0",
  "half_height": 1.20,
  "base_radius": 0.78,
  "asymmetry": 0.18,
  "latitude_segments": 64,
  "longitude_segments": 96
}
```

## 24.6 Future relevance

The egg is expected to reveal limitations of Cartesian sampling near:

- the pointed pole;
- the broad base;
- regions of changing cross-sectional radius.

Do not solve those limitations in Milestone 2. Record them for Milestone 3 intrinsic-coordinate comparison.

---

# 25. Additional Deterministic Mesh Fixtures

## 25.1 Closed cube mesh

Create a triangulated cube with:

- eight vertices;
- twelve triangles;
- outward winding;
- exact watertight topology.

Use it to test:

- edge incidence;
- signed volume;
- parity classification;
- SDF sign;
- normalized transform.

## 25.2 Closed UV sphere mesh

Create a moderate-resolution sphere mesh.

Use it to compare:

- imported-mesh SDF against `SphereDomain`;
- inside-voxel counts;
- volume error;
- sign at known points;
- normal direction.

## 25.3 Open cube mesh

Remove two triangles from the closed cube.

Expected:

- boundary edges greater than zero;
- `watertight = false`;
- strict SDF disabled;
- preview allowed;
- final export disabled.

## 25.4 Non-manifold edge fixture

Construct three triangles sharing one edge.

Expected:

- non-manifold edge count greater than zero;
- strict rejection.

## 25.5 Inverted sphere fixture

Reverse every triangle winding.

Expected:

- closed;
- consistently oriented;
- negative signed volume;
- one global flip;
- final positive signed volume;
- valid strict domain.

## 25.6 Degenerate fixture

Include:

- repeated-vertex triangle;
- collinear triangle;
- valid triangles.

Expected:

- degenerate triangles removed;
- report count correct;
- validity based only on remaining mesh.

---

# 26. Test Requirements

Add a manual or automated test runner.

Tests must not require network access.

## 26.1 STL parser tests

- binary cube STL parses exact triangle count;
- ASCII cube STL parses exact triangle count;
- binary STL with `solid` in header still parses as binary;
- malformed binary length is rejected;
- malformed ASCII facet is rejected;
- non-finite vertex is rejected;
- source hash remains stable for identical bytes.

## 26.2 Mesh validation tests

- closed cube is watertight and manifold;
- open cube is rejected in strict mode;
- non-manifold fixture is rejected;
- inverted sphere is globally corrected;
- duplicate vertices are merged;
- degenerate faces are removed;
- signed volume is positive after accepted correction.

## 26.3 Transform tests

- transformed mesh is centered;
- transformed max extent fits within margin;
- aspect ratio is preserved;
- four quarter-turns return to original orientation;
- transform followed by inverse returns original coordinate within tolerance;
- source vertices remain unchanged after repeated transforms.

## 26.4 Boundary voxelization tests

For cube and sphere fixtures:

- boundary count is nonzero;
- no transformed triangle lies outside build bounds;
- increasing resolution increases or preserves boundary detail;
- point-to-triangle distance tests pass at face, edge, and vertex cases.

## 26.5 Inside/outside tests

Known cube points:

```text
center              inside
near interior face  inside
outside corner      outside
far exterior        outside
```

Known sphere points:

```text
origin              inside
surface-near point  boundary or near zero
outside radius      outside
```

Parity scanline tests:

- intersections are even for valid rows;
- shared-edge duplicates are merged;
- deterministic retries reproduce the same result;
- no unseeded randomness is used.

## 26.6 SDF tests

For imported sphere fixture:

- center SDF is negative;
- exterior SDF is positive;
- boundary band is near zero;
- gradient normal points outward;
- no NaN or infinite values;
- radial error is reported in voxel units.

For imported cube fixture:

- center SDF is negative;
- outside face distance is positive;
- edge and corner magnitudes are approximately Euclidean at grid resolution.

## 26.7 Egg round-trip test

The canonical egg must:

- write deterministic STL;
- re-import successfully;
- report zero boundary edges;
- report zero non-manifold edges;
- report valid orientation;
- build a strict SDF;
- produce nonzero inside volume;
- produce no outside material;
- materialize a non-empty recursive field with an approved test configuration;
- export JSON provenance;
- export STL through the existing materializer path.

## 26.8 Observation tests

For imported egg and cube:

- hard interior admits the full sampled interior;
- shell band admits fewer voxels than hard interior;
- shell band remains inside;
- shell thickness change does not require reimport, only rematerialization;
- transform change invalidates SDF;
- slice change does not invalidate SDF.

## 26.9 Regression tests

After Milestone 2:

- `LEGACY_DIRECT` passes;
- `DCRTE_ADAPTER_TEST` passes;
- `DCRTE_PRIMITIVE` sphere passes;
- `DCRTE_PRIMITIVE` box passes;
- `DCRTE_PRIMITIVE` cylinder passes;
- the Milestone 1 printed-cylinder configuration can still be regenerated from its saved configuration;
- current STL and JSON exports remain valid;
- call-sheet generation remains available;
- no existing key bindings are overwritten.

---

# 27. SDF Quality Report

Implement:

```java
class SDFQualityReport {
  ValidationStatus status;

  String algorithm;
  int resolutionX;
  int resolutionY;
  int resolutionZ;

  float voxelSpacing;
  float boundaryThreshold;
  float intersectionTolerance;
  float jitterMagnitude;

  int boundaryVoxelCount;
  int insideVoxelCount;
  int outsideVoxelCount;

  int ambiguousScanlineCount;
  int retriedScanlineCount;
  int failedScanlineCount;
  int deduplicatedIntersectionCount;

  int finiteDistanceCount;
  int nonFiniteDistanceCount;
  int zeroBandCount;

  double referenceMeshVolume;
  double sampledInsideVolume;
  double volumeRelativeError;

  float minSignedDistance;
  float maxSignedDistance;

  long boundaryBuildMillis;
  long insideOutsideMillis;
  long distanceTransformMillis;
  long qualityCheckMillis;
  long totalMillis;

  ArrayList<String> errors;
  ArrayList<String> warnings;

  JSONObject toJSON();
}
```

## 27.1 Reference volume comparison

For a valid watertight mesh:

```text
sampledInsideVolume =
  insideVoxelCount * voxelVolume
```

Compare with transformed absolute signed mesh volume:

```text
volumeRelativeError =
  abs(sampledInsideVolume - meshVolume) / meshVolume
```

Suggested warning thresholds:

```text
64^3  > 0.12
128^3 > 0.07
```

These are initial engineering thresholds and may be revised from measured fixture results.

Do not fail solely because a coarse grid has moderate volume error unless it indicates a gross classification problem.

Suggested hard failure:

```text
volumeRelativeError > 0.35
```

## 27.2 Resolution comparison

For cube, sphere, and egg fixtures, record `64^3` and `128^3` results.

Expected:

- `128^3` generally improves boundary representation;
- volume error should generally decrease;
- no strict requirement for perfect monotonicity due to voxel-center aliasing;
- topology of the imported source mesh remains unchanged.

---

# 28. Imported-Domain Validation Codes

Extend the existing validation framework.

Required codes:

```text
IMPORT_FILE_NOT_FOUND
IMPORT_UNSUPPORTED_FORMAT
IMPORT_FILE_TOO_LARGE
IMPORT_TRIANGLE_LIMIT
IMPORT_PARSE_FAILURE
IMPORT_NONFINITE_VERTEX
IMPORT_EMPTY_MESH
IMPORT_INVALID_BOUNDS

MESH_DEGENERATE_TRIANGLES_REMOVED
MESH_DUPLICATE_VERTICES_MERGED
MESH_BOUNDARY_EDGES
MESH_NONMANIFOLD_EDGES
MESH_ORIENTATION_INCONSISTENT
MESH_GLOBAL_WINDING_FLIPPED
MESH_NOT_WATERTIGHT
MESH_SIGNED_VOLUME_INVALID

TRANSFORM_INVALID
TRANSFORM_OUTSIDE_BUILD_BOUNDS

BOUNDARY_VOXELIZATION_EMPTY
BOUNDARY_VOXELIZATION_FAILURE

INSIDE_OUTSIDE_AMBIGUOUS
INSIDE_OUTSIDE_FAILED
INSIDE_VOLUME_EMPTY
INSIDE_VOLUME_FULL

SDF_NONFINITE
SDF_SIGN_INCONSISTENT
SDF_VOLUME_ERROR_HIGH
SDF_GRID_MISMATCH

DOMAIN_PREVIEW_ONLY
DOMAIN_EXPORT_DISABLED

OUTSIDE_DOMAIN_MATERIAL
EMPTY_FINAL_VOLUME
FULL_FINAL_VOLUME
LEGACY_MATERIALIZER_FAILURE
RAISED_VEINS_SUPPRESSED
```

Every code must have:

- severity;
- human-readable message;
- relevant counts or values;
- JSON representation.

---

# 29. Configuration and Metadata

Extend the existing DCRTE configuration snapshot.

Do not create a separate unrelated metadata system.

## 29.1 Example schema

```json
{
  "schema_version": "0.5-m2",
  "dcrte_milestone": 2,
  "pipeline": {
    "mode": "dcrte_imported_mesh"
  },
  "field": {
    "engine_id": "legacy_topology_scalar_adapter",
    "engine_version": "0.1",
    "configuration_id": "existing-field-config-id",
    "carrier": "gyroid"
  },
  "source_mesh": {
    "filename": "dcrte_egg_fixture.stl",
    "format": "binary_stl",
    "sha256": "example",
    "source_units": "unspecified",
    "source_bytes": 604884,
    "parsed_triangles": 12096
  },
  "mesh_report": {
    "watertight": true,
    "manifold": true,
    "consistently_oriented": true,
    "global_winding_flipped": false,
    "boundary_edges": 0,
    "nonmanifold_edges": 0,
    "zero_area_triangles_removed": 0,
    "duplicate_vertices_merged": 0,
    "absolute_volume_world": 2.41
  },
  "transform": {
    "mode": "fit_centered_uniform",
    "uniform_scale": 0.731,
    "world_center": [0.0, 0.0, 0.0],
    "quarter_turns": [0, 0, 0],
    "fit_margin": 0.08
  },
  "observer": {
    "type": "uniform_grid",
    "resolution": [64, 64, 64],
    "bounds": {
      "min": [-1.0, -1.0, -1.0],
      "max": [1.0, 1.0, 1.0]
    },
    "sample_policy": "voxel_center",
    "coordinate_mode": "cartesian"
  },
  "sdf": {
    "algorithm": "grid_euclidean_distance_transform",
    "boundary_method": "conservative_point_triangle_distance",
    "inside_outside_method": "x_scanline_parity",
    "voxel_spacing": 0.03125,
    "boundary_threshold": 0.0271,
    "inside_voxels": 91284,
    "boundary_voxels": 14602,
    "failed_scanlines": 0,
    "volume_relative_error": 0.061
  },
  "observation": {
    "mode": "hard_interior",
    "boundary_epsilon": 0.0078125
  },
  "scheduler": {
    "type": "immediate",
    "stateful": false
  },
  "materializer": {
    "type": "legacy_voxel_materializer_adapter",
    "raised_veins_policy": "disabled_until_imported_sdf_clipping"
  },
  "validation": {
    "status": "pass",
    "final_solid_voxels": 22041,
    "outside_solid_voxels": 0,
    "export_enabled": true
  }
}
```

Values are examples only.

## 29.2 Required provenance

Every imported-domain result must record:

- source filename;
- source format;
- source SHA-256;
- source byte size;
- triangle and vertex counts before and after sanitation;
- sanitation tolerances;
- boundary and non-manifold counts;
- orientation result;
- signed mesh volume;
- source and world bounds;
- transform;
- observer specification;
- SDF algorithm;
- SDF thresholds and tolerances;
- SDF counts and timing;
- observation mode;
- shell thickness;
- field configuration;
- scheduler;
- materializer;
- raised-vein policy;
- validation;
- output scale;
- deterministic seed;
- application version;
- architecture version.

Do not export the user's full local file path unless explicitly enabled.

---

# 30. Build Job and Responsiveness

Imported-mesh SDF construction may be substantially slower than primitive-domain evaluation.

## 30.1 Preferred architecture

If the application already has a safe worker-job pattern, implement:

```java
class SDFBuildJob implements Runnable {
  volatile boolean cancelRequested;
  volatile float progress;
  volatile String phase;

  immutable input snapshot;
  completed result or structured failure;
}
```

Rules:

- no Processing drawing calls on the worker;
- no mutation of active UI state until a complete result is ready;
- cancel between major loops;
- publish results on the main thread;
- keep the previous valid SDF active until the new build succeeds.

## 30.2 Acceptable fallback

A synchronous `64^3` build is acceptable if measured runtime remains practical.

For `128^3`:

- show a confirmation warning;
- show phase and elapsed time;
- do not trigger automatically from slider movement;
- permit cancellation if practical.

## 30.3 State machine

Recommended:

```text
NO_MESH
IMPORTING
MESH_READY
MESH_INVALID
SDF_DIRTY
BUILDING_BOUNDARY
CLASSIFYING_INTERIOR
COMPUTING_DISTANCE
VALIDATING_SDF
SDF_READY
SDF_FAILED
MATERIALIZING
READY
```

Do not rebuild the SDF every frame.

---

# 31. Performance Targets

Performance depends on triangle count and machine.

Record actual measurements.

## 31.1 Reference mesh class

Use:

```text
triangle count <= 25,000
```

for acceptance timing.

## 31.2 Targets

At `64^3`:

```text
import + sanitation       <= 5 seconds
SDF construction          <= 30 seconds
field materialization     <= Milestone 1 target or documented regression
```

At `128^3`:

```text
supported research build
target <= 180 seconds
```

These are development targets, not universal hardware guarantees.

If the implementation exceeds them:

- report measured phase timings;
- identify the bottleneck;
- do not silently reduce mesh or grid resolution;
- keep the architecture correct;
- propose a later acceleration path.

## 31.3 Memory

Use flat arrays.

Approximate dense storage at `128^3`:

```text
2,097,152 samples

float SDF              about 8 MB
boolean inside         implementation dependent
boolean boundary       implementation dependent
field scalar           about 8 MB
additional masks       implementation dependent
```

Avoid per-voxel objects.

Reuse temporary arrays in the 1D distance transform.

---

# 32. Acceptance Test Matrix

Run all required tests.

## 32.1 Core imported-domain tests

| Test | Source | Resolution | Observation | Expected |
|---|---|---:|---|---|
| M2-A | Closed cube STL | 64 | Hard interior | Valid, no outside material |
| M2-B | Closed sphere STL | 64 | Hard interior | Valid, comparable to analytic sphere |
| M2-C | Canonical egg STL | 64 | Hard interior | Valid asymmetric ovoid realization |
| M2-D | Canonical egg STL | 64 | Shell band | Inside-only ovoid shell |
| M2-E | Canonical egg STL | 128 | Hard interior | Higher-resolution research build |
| M2-F | Open cube STL | 64 | Strict | Rejected, preview only |
| M2-G | Non-manifold fixture | 64 | Strict | Rejected |
| M2-H | Inverted sphere STL | 64 | Hard interior | Global winding corrected and accepted |

## 32.2 Required checks for valid tests

- source hash created;
- mesh report created;
- zero boundary edges;
- zero non-manifold edges;
- orientation valid;
- transformed bounds fit observer;
- boundary voxels nonzero;
- failed scanlines zero;
- SDF finite;
- inside voxels nonzero;
- sampled volume plausible;
- final material non-empty for the selected field configuration;
- outside material count zero;
- JSON export complete;
- STL export successful;
- preview and exported domain agree.

## 32.3 Required checks for invalid tests

- invalid reason visible;
- mesh preview remains available;
- strict SDF build blocked or failed safely;
- materialization blocked;
- final STL export blocked;
- JSON report identifies exact counts;
- no silent repair.

## 32.4 Regression matrix

Re-run:

- Milestone 0 adapter test;
- Milestone 1 sphere hard interior;
- Milestone 1 cylinder hard interior;
- Milestone 1 cylinder shell band;
- legacy direct generation;
- call-sheet generation;
- current STL and JSON export;
- reference printed-cylinder configuration.

---

# 33. Stop Conditions

Codex must stop and report rather than silently broadening scope when:

1. STL parsing requires replacing unrelated repository infrastructure.
2. The existing `ObservationDomain` cannot support a grid-backed SDF without a breaking rewrite.
3. The materializer starts producing geometry outside the imported domain.
4. Strict validity cannot distinguish an open mesh from a closed mesh.
5. SDF sign changes nondeterministically between identical runs.
6. The egg fixture passes only through a special-case path.
7. Source mesh scale or orientation is being guessed without metadata.
8. `128^3` forces hidden downsampling.
9. a proposed change begins adding OBJ, hole filling, medial axes, intrinsic coordinates, entropic scheduling, or FEA.
10. legacy or primitive modes regress.

When blocked, report:

- exact class and function;
- expected contract;
- actual data shape;
- smallest proposed adapter or interface change;
- effect on Milestones 0 and 1.

---

# 34. Explicit Non-Goals

Do not implement in Milestone 2:

- OBJ import;
- PLY or 3MF import;
- medical CT or voxel volume import;
- automatic hole filling;
- Poisson reconstruction;
- remeshing;
- decimation as part of the authoritative pipeline;
- arbitrary mesh boolean operations;
- multiple imported domains;
- dynamic domains;
- intrinsic coordinates;
- PCA centerlines;
- medial axes;
- parallel-transport frames;
- propagation schedulers;
- Emergent Entropic Scheduler;
- entropy models;
- graded density fields;
- orientation fields;
- stress-driven growth;
- FEA;
- marching cubes;
- dual contouring;
- GPU acceleration;
- hyperuniformity analysis;
- persistent homology;
- claims of prosthetic, implant, skeletal, or biological validity.

The egg fixture is a computational ovoid target only.

---

# 35. Recommended Commit Sequence

Keep every commit buildable.

```text
1. feat: add flat triangle-mesh data and generic importer interface
2. feat: add binary and ASCII STL import with source hashing
3. test: add deterministic cube, sphere, open, and nonmanifold STL fixtures
4. feat: add mesh sanitation and MeshDomainReport
5. feat: add normalized source-to-observation mesh transform
6. feat: add imported mesh preview and invalid-edge diagnostics
7. feat: add conservative boundary voxelization
8. test: add point-to-triangle and boundary voxelization fixtures
9. feat: add deterministic scanline inside-outside classification
10. test: add cube and sphere parity fixtures
11. feat: add 3D grid distance transform and SignedDistanceVolume
12. feat: add ImportedMeshDomain and DCRTE_IMPORTED_MESH pipeline
13. feat: add SDF slice preview and build status UI
14. feat: add canonical egg generator and deterministic STL round trip
15. feat: extend JSON provenance and export gating
16. test: run milestone 2 acceptance and milestone 0-1 regression matrix
17. docs: add imported-domain usage, limitations, and measured timings
```

Do not combine the entire milestone into one commit.

---

# 36. Documentation Update

Update the project documentation.

Required sections:

- imported observation-domain concept;
- supported STL formats;
- requirement for closed watertight meshes;
- strict versus unsigned-preview policy;
- sanitation versus repair;
- source-to-observation normalization;
- SDF construction method;
- hard-interior and shell-band behavior;
- SDF slice controls;
- canonical egg fixture;
- resolution and performance guidance;
- export gates;
- known limitations;
- OBJ deferral;
- Milestone 3 handoff.

Use this statement or an equivalent:

> In DCRTE imported-mesh mode, Surface Foundry does not deform a recursive object to match the source STL. The source mesh is validated and converted into a signed distance observation domain. The recursive field is then independently sampled, admitted by that domain, and materialized through the existing Surface Foundry pipeline.

Also state:

> The canonical egg is a deterministic imported-domain fixture used to test an asymmetric ovoid boundary. It is processed through the same STL and SDF pipeline as user-supplied meshes.

---

# 37. Deliverables

Codex must provide:

1. Modified Processing sketch.
2. Generic triangle-mesh importer interface.
3. Binary STL importer.
4. ASCII STL importer where feasible.
5. Source hashing.
6. Flat triangle-mesh representation.
7. Mesh sanitation.
8. `MeshDomainReport`.
9. Strict and unsigned-preview policies.
10. Normalized fit transform.
11. Imported mesh preview.
12. Boundary voxelizer.
13. Inside/outside classifier.
14. Distance transform.
15. `SignedDistanceVolume`.
16. `ImportedMeshDomain`.
17. `DCRTE_IMPORTED_MESH` pipeline.
18. SDF slice preview.
19. Canonical egg fixture generator.
20. Deterministic binary STL writer for fixtures.
21. Egg round-trip test.
22. Validation and export gates.
23. Extended JSON metadata.
24. Updated documentation.
25. Concise implementation report containing:
    - files changed;
    - existing interfaces extended;
    - parser behavior;
    - sanitation tolerances;
    - mesh report results;
    - SDF algorithm;
    - scanline ambiguity results;
    - `64^3` and `128^3` timings;
    - cube, sphere, egg, open, non-manifold, and inverted fixture results;
    - final solid counts;
    - outside solid counts;
    - raised-vein policy;
    - regressions run;
    - known limitations;
    - proposed Milestone 2.1 OBJ insertion point;
    - proposed Milestone 3 intrinsic-coordinate insertion point.

Do not commit large generated STL outputs.

The canonical egg STL may be generated on demand. A small deterministic fixture may be committed only if repository policy permits it and its generation parameters are documented.

---

# 38. Milestone 2 Acceptance Criteria

Milestone 2 passes only when all conditions below are satisfied.

## 38.1 Architecture

- `FieldEngine` remains independent of STL parsing.
- `TriangleMeshImporter` remains independent of field logic.
- `SignedDistanceVolume` remains independent of materialization.
- `ImportedMeshDomain` exposes the same conceptual contract as primitive domains.
- Observation Layer remains responsible for admission.
- materializer remains downstream of final solid classification.
- egg fixture uses the standard import and SDF path.
- no imported mesh semantic identity enters the recursive engine.

## 38.2 Import

- binary STL loads;
- ASCII STL loads where feasible;
- source hash exports;
- malformed files fail safely;
- triangle limits are enforced;
- non-finite coordinates fail safely.

## 38.3 Mesh validity

- closed cube is accepted;
- closed sphere is accepted;
- canonical egg is accepted;
- open cube is rejected in strict mode;
- non-manifold fixture is rejected;
- inverted closed sphere is corrected by one global winding flip;
- no hole filling occurs;
- all sanitation actions are reported.

## 38.4 SDF

- boundary voxelization is non-empty;
- inside/outside classification is deterministic;
- failed scanlines are zero for accepted fixtures;
- distances are finite;
- sign is correct at known points;
- normals point outward on sphere tests;
- `64^3` works;
- `128^3` works as a supported research build;
- SDF slices are viewable;
- mesh and sampled volume comparison is recorded.

## 38.5 Materialization

- field materializes inside closed cube;
- field materializes inside imported sphere;
- field materializes inside canonical egg;
- egg shell-band mode works;
- no final material exists outside the domain;
- empty and full field cases are detected;
- invalid domains cannot produce final STL;
- JSON and STL export remain paired.

## 38.6 Regression

- legacy direct path still works;
- adapter test still passes;
- primitive sphere, box, and cylinder still work;
- printed-cylinder reference configuration remains reproducible;
- call sheets remain available;
- existing controls are not overwritten;
- no field equation changes are introduced.

## 38.7 Provenance

Every imported-domain result records:

- source identity and hash;
- mesh validity;
- sanitation;
- transform;
- SDF algorithm;
- grid resolution;
- SDF quality;
- observation mode;
- field configuration;
- scheduler;
- materializer;
- validation;
- output scale;
- timing.

---

# 39. Expected Result

At the end of Milestone 2, Surface Foundry should be able to produce:

```text
same recursive field + imported cube STL
same recursive field + imported sphere STL
same recursive field + imported egg STL
same recursive field + another valid watertight STL
```

Each result is a separate material realization of the same field under a different observation constraint.

The egg should make the architectural shift physically obvious:

- the broad base;
- changing cross section;
- narrower pole;
- curved asymmetric boundary;

all constrain where geometry may emerge, while the internal recursive field remains independent of the target's semantic identity.

Milestone 2 establishes:

> **An arbitrary valid closed mesh can become an observation domain without becoming a deformation target.**

---

# 40. Compact Codex Prompt

Use the full work order above as the canonical architecture contract.

Place this prompt before it when starting the Codex task:

```text
Implement DCRTE-ET Milestone 2 in the Cosmosis Visual Observatory.

Milestones 0 and 1 have passed. Begin by inspecting the actual FieldEngine, ObservationDomain, UniformGridObserver, Observation Layer, DCRTE volume, validation, materializer adapter, preview, export, and pipeline-selector implementations.

Add a DCRTE_IMPORTED_MESH pipeline that loads closed watertight STL meshes, sanitizes and validates them, applies a reversible normalized fit transform, conservatively voxelizes the boundary, classifies inside/outside deterministically, builds a signed distance volume at 64^3 and supported 128^3 resolution, exposes it through ImportedMeshDomain, and reuses the existing hard-interior, shell-band, field, immediate scheduler, materializer, validation, and export systems.

Implement binary STL, ASCII STL where feasible, SHA-256 provenance, MeshDomainReport, strict invalid-domain rejection, unsigned preview mode, mesh preview, SDF slices, export gates, deterministic fixtures, and full JSON metadata.

Include a canonical parametric egg fixture, but do not special-case the egg in the production domain logic. Generate it as a valid outward-wound triangle mesh, write it to deterministic binary STL, release the source mesh, then re-import it through the same STL, validation, transform, SDF, and materialization path as any user mesh.

Do not implement OBJ, hole filling, remeshing, intrinsic coordinates, medial axes, propagation, Emergent Entropic Scheduling, new production materializers, or advanced analysis.

Use flat arrays, deterministic algorithms, no per-voxel objects, no hidden downsampling, and no material outside the imported domain. Preserve all Milestone 0, Milestone 1, legacy, call-sheet, and export behavior.

Return a concise implementation report with files changed, parser and sanitation details, fixture results, SDF errors, ambiguity counts, 64^3 and 128^3 timings, final material counts, outside-domain counts, regressions, limitations, and clean insertion points for OBJ and Milestone 3 intrinsic coordinates.

Treat the attached Milestone 2 work order as the architecture contract.
```

---

# 41. Handoff After Milestone 2

Do not implement these items until Milestone 2 passes.

## 41.1 Milestone 2.1: OBJ importer

The future OBJ importer should:

- implement `TriangleMeshImporter`;
- parse positions and polygon faces;
- support positive and negative indices;
- triangulate polygons deterministically;
- ignore unsupported materials safely;
- return `TriangleMeshData`;
- use the same sanitation, report, transform, SDF, observation, and export path.

No downstream class should need to know whether the source was STL or OBJ.

## 41.2 Milestone 3: Basic intrinsic coordinates

The egg becomes a useful first Milestone 3 target.

Milestone 3 will compare:

```text
Cartesian field sampling
versus
domain-derived intrinsic sampling
```

inside the same imported egg SDF.

Expected Milestone 3 insertion points:

```text
ImportedMeshDomain
      |
      v
inside mask and SDF
      |
      v
PCA principal axis
      |
      v
slice-centroid centerline
      |
      v
smoothed centerline
      |
      v
parallel-transport frame
      |
      v
s, r, theta, confidence
      |
      v
CoordinateSystem passed to FieldEngine
```

Milestone 2 must preserve enough source and SDF data to support this without rebuilding the import architecture.

## 41.3 Recommended reference artifacts

Preserve:

```text
DCRTE-M1-CYL-001
DCRTE-M2-EGG-001
```

For `DCRTE-M2-EGG-001`, retain:

- source egg parameters;
- deterministic STL hash;
- field configuration;
- SDF resolution;
- observation mode;
- final STL;
- JSON metadata;
- slicer profile;
- print settings;
- photographs;
- validation report.

This creates a physical reference sequence showing the Observation Layer evolving from analytic primitive domains to imported asymmetric domains.

---

**End of Work Order**
