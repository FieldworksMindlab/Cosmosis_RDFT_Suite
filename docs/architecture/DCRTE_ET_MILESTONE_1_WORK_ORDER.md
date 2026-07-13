# Work Order: DCRTE-ET Milestone 1

## Primitive Observation Domains

**Version:** 1.0  
**Status:** Ready for Codex implementation  
**Project:** Surface Foundry / Cosmosis RDFT Suite  
**Architecture:** DCRTE-ET Architecture Specification v0.3  
**Prerequisite:** Milestone 0 has passed all acceptance tests  
**Primary application:** `apps/cosmosis-visual-observatory/`  
**Primary sketch:** `Cosmosis_Visual_Observatory.pde`

---

## 1. Codex Directive

Implement Milestone 1 of the Domain-Constrained Recursive Topology Engine with Entropic Time Integration.

Milestone 1 must prove that the existing Surface Foundry recursive field can be sampled through several primitive observation domains without changing the recursive field equations or deforming a finished mesh.

The new path must support:

- sphere observation domain;
- axis-aligned box observation domain;
- finite cylinder observation domain;
- uniform 3D grid observation;
- hard-interior observation;
- interior shell-band observation;
- immediate static activation;
- intersection with the existing Surface Foundry material rule;
- adaptation into the existing voxel mesh and export path;
- domain and volume validation;
- reproducible metadata export.

The legacy generation path must remain available and unchanged.

Do not implement arbitrary STL import, mesh repair, signed distance fields from imported meshes, intrinsic coordinates, front propagation, entropy scheduling, adaptive sampling, mechanical analysis, or hyperuniformity analysis in this milestone.

---

## 2. Core Principle

> **Fields are primary. Geometry is emergent.**

The recursive field must remain independent of the observation domain.

A sphere, box, or cylinder does not deform the field. Each domain only determines where field samples are admitted for materialization.

The central Milestone 1 equation is:

```text
finalSolid(x) =
    domainAdmits(x)
    AND
    legacyMaterialRule(field(x))
```

The field is evaluated using the Milestone 0 `FieldEngine` path. The domain is evaluated separately. The two systems meet only at the Observation Layer.

---

## 3. Milestone Goal

Prove this pipeline:

```text
Existing RDFT / Surface Foundry field
                |
                v
        UniformGridObserver
                |
                v
      PrimitiveObservationDomain
                |
                v
         ObservationLayer
                |
                v
     Existing field-to-solid rule
                |
                v
       Immediate static activation
                |
                v
 Legacy materializer and STL exporter
                |
                v
       Validation and metadata
```

Success means the same field configuration can be observed through a sphere, box, or cylinder while:

- preserving the existing field engine;
- preventing material outside the selected domain;
- retaining legacy Surface Foundry as a separate path;
- exporting enough provenance to reproduce the result.

---

## 4. Prerequisite Verification

Before changing code, inspect the completed Milestone 0 implementation.

Codex must identify and report:

1. The actual names and locations of:
   - `FieldEngine`;
   - `LegacyTopologyScalarAdapter`;
   - the DCRTE configuration snapshot;
   - the pipeline selector;
   - adapter comparison diagnostics;
   - metadata export hooks.

2. The exact existing functions responsible for:
   - Surface Foundry volume sampling;
   - field-to-solid or iso-band classification;
   - conversion of solid voxels into mesh geometry;
   - optional raised-vein generation;
   - STL export;
   - JSON metadata export;
   - Surface Foundry preview drawing;
   - input handling.

3. The coordinate range currently passed to the legacy topology scalar.

4. The data structure currently used by the legacy materializer:
   - flat array;
   - `boolean[][][]`;
   - `float[][][]`;
   - or another representation.

5. The current keyboard mappings, so no key collision is introduced.

Do not create duplicate versions of Milestone 0 interfaces. Extend or adapt the classes that already exist.

If Milestone 0 names differ from the architecture document, use the implemented names consistently and note the mapping in the implementation report.

---

## 5. Required Pipeline Modes

Extend the Milestone 0 pipeline selector with one new mode.

```java
enum FoundryPipelineMode {
  LEGACY_DIRECT,
  DCRTE_ADAPTER_TEST,
  DCRTE_PRIMITIVE
}
```

Equivalent names are acceptable if Milestone 0 already established a naming convention.

### Behavior

#### `LEGACY_DIRECT`

- Preserve the original generation path.
- Preserve original field sampling.
- Preserve original raised veins.
- Preserve original mesh and export behavior.
- Do not apply any DCRTE domain mask.

#### `DCRTE_ADAPTER_TEST`

- Preserve the Milestone 0 comparison behavior.
- Do not apply a primitive domain unless Milestone 0 already explicitly does so.
- Continue reporting direct-versus-adapter numerical error.

#### `DCRTE_PRIMITIVE`

- Sample the field through the Milestone 0 `FieldEngine`.
- Use a `UniformGridObserver`.
- Evaluate one primitive domain.
- Apply one Observation Layer mode.
- Apply immediate activation.
- Intersect the admitted volume with the existing field-to-solid rule.
- Send the result through a legacy materializer adapter.
- Validate the volume before export.
- Add full domain metadata.

`LEGACY_DIRECT` should remain the startup default unless the user has deliberately stored a different preference.

---

## 6. New PDE Tabs

Create the following tabs unless equivalent Milestone 0 tabs already exist.

```text
DCRTE_Domain.pde
DCRTE_Observer.pde
DCRTE_Observation.pde
DCRTE_Volume.pde
DCRTE_Validation.pde
DCRTE_MaterializerAdapter.pde
DCRTE_M1_Tests.pde
```

A minimal scheduler tab may also be added:

```text
DCRTE_Scheduler.pde
```

Do not move the entire sketch into Java packages. Keep Processing 4 compatibility.

### Responsibility boundaries

#### `DCRTE_Domain.pde`

Contains:

- `ObservationDomain` interface;
- `DomainSample`;
- `Bounds3D`;
- `SphereDomain`;
- `BoxDomain`;
- `CylinderDomain`;
- primitive domain configuration enums and parameter objects.

#### `DCRTE_Observer.pde`

Contains:

- `VolumeSpec`;
- `UniformGridObserver`;
- index conversion;
- grid-to-world mapping;
- voxel spacing and sample-volume calculations.

#### `DCRTE_Observation.pde`

Contains:

- `ObservationLayer` interface;
- `ObservationSample`;
- `HardInteriorObservation`;
- `ShellBandObservation`;
- observation mode enum and configuration.

#### `DCRTE_Volume.pde`

Contains:

- flat scalar and boolean volume containers;
- safe indexing;
- resolution and bounds metadata;
- conversion boundary for legacy arrays when required.

#### `DCRTE_Validation.pde`

Contains:

- configuration validation;
- domain volume comparison;
- empty and full volume detection;
- outside-domain material detection;
- validation status and report serialization.

#### `DCRTE_MaterializerAdapter.pde`

Contains:

- adaptation of DCRTE volume output to the existing Surface Foundry mesh path;
- no new production meshing algorithm;
- explicit raised-vein handling in primitive mode.

#### `DCRTE_M1_Tests.pde`

Contains deterministic fixtures and test runners that can be called manually or through a debug flag.

---

## 7. Core Data Structures

Use these structures as the target design. Simplify only where required by Processing.

### 7.1 Bounds3D

```java
class Bounds3D {
  float minX;
  float minY;
  float minZ;
  float maxX;
  float maxY;
  float maxZ;

  float sizeX();
  float sizeY();
  float sizeZ();

  float centerX();
  float centerY();
  float centerZ();

  float volume();
  boolean isValid();
}
```

Requirements:

- all dimensions must be positive;
- no NaN or infinite values;
- bounds must serialize to JSON;
- bounds must be independent of screen coordinates and STL millimeter scale.

### 7.2 DomainSample

```java
class DomainSample {
  boolean inside;
  float signedDistance;
  float normalX;
  float normalY;
  float normalZ;
  int regionId;
  boolean valid;
}
```

Milestone 1 primitives must provide analytic or stable approximate signed distance.

Sign convention:

```text
signedDistance < 0 : inside
signedDistance = 0 : boundary
signedDistance > 0 : outside
```

Normals should point outward when valid.

### 7.3 ObservationDomain

```java
interface ObservationDomain {
  DomainSample sample(float x, float y, float z);
  Bounds3D bounds();
  float analyticVolume();
  String getId();
  String getVersion();
  JSONObject toJSON();
  boolean isValid();
  String validationMessage();
}
```

Avoid creating a new `PVector` for every voxel sample. The hot loop should use primitive `float` coordinates or a reused mutable sample object.

### 7.4 VolumeSpec

```java
class VolumeSpec {
  int nx;
  int ny;
  int nz;
  Bounds3D bounds;

  int voxelCount();
  float spacingX();
  float spacingY();
  float spacingZ();
  float sampleVolume();
  boolean isValid();
}
```

Milestone 1 must support cubic resolutions at minimum:

- `32^3` debug;
- `64^3` standard interactive target;
- `128^3` optional preview, not required for acceptance.

### 7.5 DCRTEVolume

```java
class DCRTEVolume {
  VolumeSpec spec;
  float[] scalar;
  boolean[] admitted;
  boolean[] candidateSolid;
  boolean[] active;
  boolean[] finalSolid;

  int admittedCount;
  int candidateSolidCount;
  int activeCount;
  int finalSolidCount;
  int outsideSolidCount;
}
```

Use one-dimensional primitive arrays.

The index formula must be documented and used consistently:

```java
int index(int x, int y, int z) {
  return x + nx * (y + ny * z);
}
```

Do not allocate a `PVector`, `DomainSample`, or `FieldSample` object inside the innermost voxel loop if reusable objects or scalar methods can avoid it.

---

## 8. Primitive Domains

All initial primitive domains should be expressed in the observer's world coordinate system.

Use a default normalized observation box of:

```text
x in [-1, 1]
y in [-1, 1]
z in [-1, 1]
```

unless the existing Surface Foundry field already uses a different normalized range. If the legacy field uses another range, preserve that range and document it.

The observer bounds and domain dimensions must be configurable rather than hidden constants.

---

## 9. Sphere Domain

### 9.1 Default configuration

```text
center = (0, 0, 0)
radius = 0.88
```

The radius should leave a visible margin inside the default observation bounds.

### 9.2 Signed distance

```text
q = p - center
distance = length(q)
sdf = distance - radius
```

### 9.3 Normal

For `distance > epsilon`:

```text
normal = q / distance
```

At the exact center:

```text
normal = (0, 1, 0)
valid normal = false or fallback
```

### 9.4 Analytic volume

```text
V = 4/3 * PI * radius^3
```

### 9.5 Validation

Reject:

- radius less than or equal to zero;
- non-finite center or radius;
- sphere that has no overlap with the observer bounds.

Warn when:

- the sphere intersects or exceeds observer bounds;
- volume comparison error is unusually high for the selected resolution.

---

## 10. Box Domain

Milestone 1 uses an axis-aligned box.

### 10.1 Default configuration

```text
center = (0, 0, 0)
halfExtents = (0.78, 0.78, 0.78)
```

### 10.2 Exact signed distance

Use the standard axis-aligned box SDF:

```text
q = abs(p - center) - halfExtents

outside = length(max(q, 0))
inside = min(max(q.x, max(q.y, q.z)), 0)

sdf = outside + inside
```

### 10.3 Normal

An approximate analytic normal is sufficient for Milestone 1.

Preferred methods:

1. direct face normal for clearly interior-nearest or exterior-nearest face;
2. central difference of the SDF with a small epsilon;
3. documented fallback when a corner or edge is ambiguous.

### 10.4 Analytic volume

```text
V = 8 * hx * hy * hz
```

### 10.5 Validation

Reject:

- any half extent less than or equal to zero;
- non-finite center or half extents.

Warn when:

- box extends beyond observer bounds.

---

## 11. Cylinder Domain

Milestone 1 uses a finite cylinder aligned with the world Y axis.

Future axis selection is allowed but not required.

### 11.1 Default configuration

```text
center = (0, 0, 0)
radius = 0.68
halfHeight = 0.88
axis = Y
```

### 11.2 Exact signed distance

For Y-axis alignment:

```text
radial = sqrt((x - cx)^2 + (z - cz)^2)
q0 = radial - radius
q1 = abs(y - cy) - halfHeight

outside = length(max(vec2(q0, q1), 0))
inside = min(max(q0, q1), 0)

sdf = outside + inside
```

### 11.3 Analytic volume

```text
V = PI * radius^2 * (2 * halfHeight)
```

### 11.4 Validation

Reject:

- radius less than or equal to zero;
- half height less than or equal to zero;
- non-finite parameters.

Warn when:

- cylinder extends beyond observer bounds.

---

## 12. Uniform Grid Observer

### 12.1 Responsibility

`UniformGridObserver` defines where the field and domain are sampled. It must not decide whether a point becomes material.

### 12.2 Sample position policy

Use voxel-center sampling.

For X:

```text
tx = (x + 0.5) / nx
worldX = lerp(minX, maxX, tx)
```

Use the same policy for Y and Z.

Do not sample exactly on the bounds unless a test explicitly requires it.

### 12.3 Required methods

```java
class UniformGridObserver {
  VolumeSpec spec;

  void initialize(VolumeSpec spec);

  int index(int x, int y, int z);

  float worldX(int x);
  float worldY(int y);
  float worldZ(int z);

  float normalizedX(int x);
  float normalizedY(int y);
  float normalizedZ(int z);

  boolean isValid();
  JSONObject toJSON();
}
```

### 12.4 Coordinate handoff

For Milestone 1, the field engine should receive either:

- the same Cartesian coordinates previously used by Surface Foundry; or
- normalized bounding-box coordinates mapped back into that exact legacy range.

Do not introduce intrinsic coordinates yet.

Export:

```json
"coordinates": {
  "type": "cartesian",
  "source": "uniform_grid_observer"
}
```

---

## 13. Observation Layer

The Observation Layer decides whether a domain sample is admitted.

### 13.1 Interface

```java
interface ObservationLayer {
  ObservationSample observe(DomainSample domainSample);
  String getId();
  JSONObject toJSON();
  boolean isValid();
  String validationMessage();
}
```

### 13.2 ObservationSample

```java
class ObservationSample {
  boolean admitted;
  float maskWeight;
  float boundaryWeight;
  float domainDistance;
  int regionId;
}
```

Milestone 1 uses binary mask weights:

```text
maskWeight = 1 when admitted
maskWeight = 0 when rejected
```

Soft boundary weighting is deferred.

---

## 14. Hard Interior Observation

### Rule

```text
admitted = signedDistance <= boundaryEpsilon
```

Use a small configurable boundary epsilon tied to voxel spacing, for example:

```text
boundaryEpsilon = 0.25 * minVoxelSpacing
```

The exact default must be documented.

Do not use a large epsilon that materially dilates the domain.

### Metadata

```json
"observation": {
  "mode": "hard_interior",
  "boundary_epsilon": 0.0078125
}
```

---

## 15. Interior Shell-Band Observation

Milestone 1 shell bands must remain inside the primitive domain.

### Rule

For shell thickness `t > 0`:

```text
admitted =
    signedDistance <= boundaryEpsilon
    AND
    signedDistance >= -(t + boundaryEpsilon)
```

This creates an inward shell.

Do not admit points outside the domain in Milestone 1.

### Default thickness

Use a thickness that spans several voxels at `64^3`, for example:

```text
shellThickness = 4 * minVoxelSpacing
```

The user may change it through the DCRTE panel.

### Validation

Reject:

- thickness less than or equal to zero;
- non-finite thickness.

Warn when:

- thickness is less than 1.5 voxel spacings;
- thickness is greater than the domain's smallest meaningful radius or half extent;
- the shell admits zero voxels.

### Metadata

```json
"observation": {
  "mode": "shell_band",
  "side": "inside_only",
  "thickness": 0.125,
  "thickness_voxels": 4.0
}
```

---

## 16. Immediate Static Scheduler

Milestone 1 includes only a baseline immediate activation mechanism.

Do not build the full scheduler framework from Milestone 4.

A minimal implementation is sufficient:

```java
class ImmediateScheduler {
  String getId() {
    return "immediate";
  }

  boolean activate(boolean admitted, boolean candidateSolid) {
    return admitted && candidateSolid;
  }
}
```

The purpose is to establish the pipeline location where future schedulers will operate.

Export:

```json
"scheduler": {
  "type": "immediate",
  "stateful": false,
  "relational_progress": null
}
```

The scheduler must not depend on `frameCount`, elapsed milliseconds, or render cadence.

---

## 17. Field Sampling and Material Rule

### 17.1 Preserve the field

Use the completed Milestone 0 `FieldEngine`.

Do not edit the field equations.

Do not change:

- alpha behavior;
- recursion depth behavior;
- deep-detail behavior;
- phase behavior;
- carrier behavior;
- topology blend behavior;
- material-profile mapping.

### 17.2 Preserve the field-to-solid rule

Identify the existing Surface Foundry rule that determines solid voxels from field samples.

Examples may include:

- absolute iso-band threshold;
- scalar threshold;
- carrier-adjusted threshold;
- local shell classification.

Move or wrap that rule only as much as required to call it from the DCRTE path.

Recommended abstraction:

```java
boolean legacyCandidateSolid(float scalarValue, LegacyFoundryContext context);
```

The result before domain masking is:

```text
candidateSolid
```

The final result is:

```text
finalSolid = admitted AND candidateSolid
```

### 17.3 Required loop order

Use this order:

```java
for z
  for y
    for x
      idx = observer.index(x, y, z)

      wx = observer.worldX(x)
      wy = observer.worldY(y)
      wz = observer.worldZ(z)

      domainSample = domain.sample(wx, wy, wz)
      observationSample = observation.observe(domainSample)

      volume.admitted[idx] = observationSample.admitted

      fieldSample = fieldEngine.sample(...)
      volume.scalar[idx] = fieldSample.value

      candidate = legacyCandidateSolid(fieldSample.value, context)
      volume.candidateSolid[idx] = candidate

      active = immediateScheduler.activate(
        observationSample.admitted,
        candidate
      )

      volume.active[idx] = active
      volume.finalSolid[idx] = active
```

The implementation may skip expensive field evaluation outside the admitted domain only if:

- outside scalar values are never needed by the legacy materializer;
- the skipped value is recorded as invalid or NaN rather than falsely treated as a real field value;
- adapter-test behavior is unaffected;
- preview and metadata remain correct.

The safer first implementation is to evaluate the field everywhere and mask only during material admission.

---

## 18. Legacy Materializer Adapter

### 18.1 Goal

Reuse the existing voxel mesh creation path.

Do not implement marching cubes, dual contouring, or surface nets.

### 18.2 Adapter behavior

The adapter must:

1. accept `DCRTEVolume.finalSolid`;
2. convert it to the data structure expected by the existing materializer;
3. call the existing mesh builder;
4. preserve existing millimeter scaling;
5. preserve triangle winding and STL output;
6. attach domain metadata to JSON export.

### 18.3 Temporary conversion

If the existing mesh builder requires `boolean[][][]`, one explicit conversion is allowed at the adapter boundary:

```java
boolean[][][] toLegacyBooleanVolume(DCRTEVolume volume)
```

Do not use nested arrays as the authoritative DCRTE storage.

### 18.4 Raised transport veins

Raised veins can violate the primitive boundary if they are generated independently of the admitted volume.

In `DCRTE_PRIMITIVE` mode, use one of these safe policies:

#### Preferred

Clip every vein sample and every generated vein segment against the active observation domain.

#### Acceptable for Milestone 1

Disable raised veins in `DCRTE_PRIMITIVE` mode and report:

```text
Raised veins disabled in primitive-domain mode until domain clipping is implemented.
```

The legacy pipeline must retain its existing raised-vein behavior.

Do not allow unbounded vein geometry in a DCRTE primitive export.

Record the policy:

```json
"raised_veins": {
  "requested": true,
  "applied": false,
  "reason": "disabled_until_domain_clipping"
}
```

---

## 19. User Interface

Add a compact DCRTE block inside the Surface Foundry workspace.

Do not redesign the whole application.

### 19.1 Required displayed fields

```text
PIPELINE       DCRTE PRIMITIVE
DOMAIN         SPHERE
OBSERVATION    HARD INTERIOR
RESOLUTION     64^3
ADMITTED       098,214
FINAL SOLID    021,552
DOMAIN FILL    21.94%
OUTSIDE SOLID  0
VALIDATION     PASS
BUILD TIME     1.84 s
```

### 19.2 Required controls

The panel must support:

- cycle pipeline mode;
- cycle primitive domain;
- cycle observation mode;
- select `32`, `64`, or optional `128` resolution;
- increase or decrease shell thickness;
- regenerate;
- run validation;
- show or hide domain preview.

Prefer clickable controls because existing keyboard controls are already dense.

Optional keyboard shortcuts may be added only after scanning the full `keyPressed()` map.

Preferred shortcuts, only if free:

```text
P : cycle pipeline
J : cycle primitive domain
K : cycle observation mode
, : decrease shell thickness
. : increase shell thickness
```

If any preferred key is occupied, do not override it. Use buttons and report the decision.

### 19.3 Naming clarity

The existing geometry carrier and the new observation domain are different concepts.

The UI must label them distinctly:

```text
FIELD CARRIER       GYROID
OBSERVATION DOMAIN  CYLINDER
```

Do not call both of them "geometry."

---

## 20. Visualization

Milestone 1 must make the observation domain visible.

### 20.1 Primitive wireframe preview

Draw a transparent wireframe or low-opacity guide for the selected primitive:

- sphere;
- box;
- cylinder.

The preview must:

- use the same world transform as the generated field;
- not become part of the STL;
- be toggleable;
- not obscure the materialized form.

### 20.2 Center-slice diagnostic

Add an optional simple center-slice diagnostic showing:

- rejected voxels;
- admitted voxels;
- final solid voxels.

A three-color display is acceptable in the UI, but export classification must remain numerical and color-independent.

This diagnostic may be small and need not become a full slice browser.

### 20.3 Status

During generation, show:

```text
BUILDING DOMAIN
SAMPLING FIELD
APPLYING OBSERVATION
MATERIALIZING
VALIDATING
READY
```

Do not regenerate continuously in `draw()`.

Generation should occur only when requested or when a relevant parameter is deliberately changed and the user confirms regeneration.

---

## 21. Validation Framework

Milestone 1 validation is limited to primitive-domain and volume sanity checks.

### 21.1 Status enum

```java
enum ValidationStatus {
  PASS,
  PASS_WITH_WARNINGS,
  FAIL
}
```

### 21.2 Required validation codes

```text
INVALID_BOUNDS
INVALID_RESOLUTION
INVALID_DOMAIN_PARAMETERS
NO_DOMAIN_OVERLAP
EMPTY_ADMITTED_DOMAIN
EMPTY_FINAL_VOLUME
FULL_FINAL_VOLUME
OUTSIDE_DOMAIN_MATERIAL
SHELL_TOO_THIN
SHELL_TOO_THICK
DOMAIN_VOLUME_ERROR_HIGH
NONFINITE_SCALAR
LEGACY_ADAPTER_FAILURE
RAISED_VEINS_SUPPRESSED
```

### 21.3 Required report fields

```java
class DCRTEValidationReport {
  ValidationStatus status;
  ArrayList<String> errors;
  ArrayList<String> warnings;

  int totalSamples;
  int admittedSamples;
  int candidateSolidSamples;
  int finalSolidSamples;
  int outsideSolidSamples;
  int nonFiniteScalarSamples;

  float admittedFraction;
  float finalFractionOfGrid;
  float finalFractionOfDomain;

  float analyticDomainVolume;
  float sampledDomainVolume;
  float domainVolumeRelativeError;

  long domainBuildMillis;
  long fieldSampleMillis;
  long materializeMillis;
  long validationMillis;
  long totalMillis;

  JSONObject toJSON();
}
```

### 21.4 Empty volume

Fail export when:

```text
finalSolidSamples == 0
```

The mesh may still be previewed as an empty diagnostic state, but STL export must not claim success.

### 21.5 Full volume

Warn or fail when every admitted voxel becomes solid.

Recommended rule:

```text
fullRatio = finalSolidSamples / admittedSamples
```

If:

```text
fullRatio >= 0.999
```

emit `FULL_FINAL_VOLUME`.

This catches accidental threshold inversion and constant-field errors.

### 21.6 Outside-domain material

This is a hard failure.

For every final solid voxel:

```text
admitted must be true
```

If any violation exists:

```text
status = FAIL
export disabled
```

The count must be displayed and exported.

### 21.7 Analytic volume comparison

Estimate sampled domain volume:

```text
sampledVolume = admittedSamples * observer.sampleVolume()
```

Compare with the primitive's analytic volume.

```text
relativeError =
  abs(sampledVolume - analyticVolume) / analyticVolume
```

This is a domain and observer diagnostic, not a field-quality metric.

Suggested warning thresholds at `64^3`:

```text
box      > 0.04
sphere   > 0.08
cylinder > 0.08
```

Do not hard fail solely because of volume discretization unless the error is extreme, such as greater than `0.25`.

Store the selected threshold in metadata.

### 21.8 Non-finite values

Any NaN or infinite field scalar is a validation failure for the DCRTE primitive run.

Report the first affected index and world coordinate when practical.

---

## 22. Configuration Extension

Extend the Milestone 0 DCRTE configuration snapshot.

Do not create a second unrelated configuration format.

### 22.1 Required schema

```json
{
  "schema_version": "0.4-m1",
  "dcrte_milestone": 1,
  "pipeline": {
    "mode": "dcrte_primitive"
  },
  "field": {
    "engine_id": "legacy_topology_scalar_adapter",
    "engine_version": "0.1",
    "configuration_id": "existing-m0-config-id"
  },
  "domain": {
    "type": "sphere",
    "version": "1.0",
    "center": [0.0, 0.0, 0.0],
    "radius": 0.88,
    "analytic_volume": 2.854,
    "bounds": {
      "min": [-1.0, -1.0, -1.0],
      "max": [1.0, 1.0, 1.0]
    }
  },
  "observer": {
    "type": "uniform_grid",
    "resolution": [64, 64, 64],
    "sample_policy": "voxel_center",
    "coordinate_mode": "cartesian",
    "sample_volume": 0.000030517578125
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
    "raised_veins_policy": "disabled_until_domain_clipping"
  },
  "validation": {
    "status": "pass",
    "admitted_samples": 92742,
    "final_solid_samples": 21881,
    "outside_solid_samples": 0,
    "analytic_domain_volume": 2.854,
    "sampled_domain_volume": 2.830,
    "domain_volume_relative_error": 0.0084
  }
}
```

Values above are examples only.

### 22.2 Provenance

Export:

- random seed;
- field configuration ID;
- domain type and parameters;
- observer bounds and resolution;
- observation mode;
- shell thickness;
- immediate scheduler ID;
- carrier name;
- legacy iso-band or material rule parameters;
- raised-vein policy;
- validation status;
- timing measurements;
- application and architecture version.

---

## 23. Deterministic Test Fixtures

Add a manual test runner or debug test mode.

Tests must not require external files.

### 23.1 Sphere SDF tests

For radius `1` centered at origin:

```text
sample (0,0,0)       sdf = -1
sample (1,0,0)       sdf = 0
sample (2,0,0)       sdf = 1
sample (0,0.5,0)     sdf = -0.5
```

Tolerance:

```text
1e-5
```

### 23.2 Box SDF tests

For half extents `(1,1,1)`:

```text
sample (0,0,0)       sdf = -1
sample (1,0,0)       sdf = 0
sample (2,0,0)       sdf = 1
sample (1,1,1)       sdf = 0
```

Corner exterior values should match the exact SDF within tolerance.

### 23.3 Cylinder SDF tests

For radius `1`, half height `1`, Y axis:

```text
sample (0,0,0)       sdf = -1
sample (1,0,0)       sdf = 0
sample (0,1,0)       sdf = 0
sample (2,0,0)       sdf = 1
sample (0,2,0)       sdf = 1
```

### 23.4 Observer mapping tests

For a small `4^3` observer over `[-1,1]^3`:

- first voxel center must be `-0.75`;
- last voxel center must be `0.75`;
- index mapping must be unique;
- index range must be `[0, 63]`;
- sample volume times sample count must equal bounds volume.

### 23.5 Observation tests

Hard interior:

- inside admitted;
- boundary admitted within epsilon;
- outside rejected.

Shell band:

- near-inside boundary admitted;
- deep interior rejected;
- outside rejected;
- shell admitted count less than hard-interior count for the same domain.

### 23.6 Synthetic volume tests

Provide a minimal synthetic field rule for tests only:

#### Constant empty

```text
candidateSolid = false
```

Expected:

- `EMPTY_FINAL_VOLUME`;
- export disabled.

#### Constant full

```text
candidateSolid = true
```

Expected:

- all admitted voxels final solid;
- `FULL_FINAL_VOLUME`;
- outside solid count zero.

#### Checker field

```text
candidateSolid = ((x + y + z) % 2 == 0)
```

Expected:

- non-empty;
- non-full;
- no material outside domain.

### 23.7 Primitive volume convergence

At `32^3` and `64^3`, compute sampled-versus-analytic volume error.

Expected:

- error should generally decrease or remain comparable as resolution increases;
- no domain should report an obviously impossible volume;
- box should show the lowest error when aligned to the grid.

Do not require strictly monotonic error for every resolution due to voxel-center aliasing.

### 23.8 Legacy regression

After adding Milestone 1:

- run `LEGACY_DIRECT`;
- confirm current Surface Foundry generation still works;
- run `DCRTE_ADAPTER_TEST`;
- confirm Milestone 0 numerical comparison remains negligible;
- confirm legacy export metadata remains valid;
- confirm DCRTE fields are added only when DCRTE modes are active, unless the established schema intentionally includes null values.

---

## 24. Acceptance Test Matrix

Run these six primary configurations at `64^3`.

| Test | Domain | Observation | Expected |
|---|---|---|---|
| M1-A | Sphere | Hard interior | Non-empty, no outside material |
| M1-B | Sphere | Shell band | Shell visible, less admitted volume |
| M1-C | Box | Hard interior | Non-empty, axis-aligned clipping |
| M1-D | Box | Shell band | Six-sided inner shell |
| M1-E | Cylinder | Hard interior | Non-empty, finite caps |
| M1-F | Cylinder | Shell band | Side and cap shell, no exterior |

For every configuration:

- generation completes;
- validation report is produced;
- outside solid count equals zero;
- STL generation succeeds unless the field configuration legitimately produces an empty or full invalid volume;
- JSON includes domain, observer, observation, scheduler, materializer, and validation metadata;
- preview matches exported domain;
- the selected field carrier remains recorded independently.

Also run:

- one `32^3` debug build;
- one `128^3` build if practical;
- legacy regression;
- adapter regression.

---

## 25. Performance Requirements

### 25.1 Primary target

`64^3` equals 262,144 samples.

This must complete as an interactive user-requested operation on the development machine.

Target:

```text
total primitive build <= 5 seconds
```

This is a target, not an absolute cross-hardware failure threshold. Record the actual measured times.

### 25.2 Memory

Use flat primitive arrays.

Approximate storage for `64^3`:

```text
float scalar       about 1.0 MB
five boolean sets  implementation dependent
domain metadata    small
```

Processing's Java boolean arrays may use more than one bit per sample. Report observed memory if practical.

Do not allocate hundreds of thousands of temporary objects.

### 25.3 Generation cadence

- no full volume rebuild in `draw()`;
- no hidden automatic rebuild every frame;
- no unseeded randomness;
- preserve deterministic output for the same field, domain, observer, and seed.

### 25.4 Optional progress display

For long runs, update a progress counter between major phases. Do not mutate Processing UI from an unsafe worker thread unless thread handling is already established.

A synchronous implementation is acceptable for Milestone 1 if `64^3` remains practical.

---

## 26. Failure and Stop Conditions

Codex must stop and report rather than silently changing architecture when:

1. The Milestone 0 field adapter cannot be called without changing field equations.
2. The legacy materializer cannot consume a masked volume without a major rewrite.
3. Primitive mode produces geometry outside the admitted domain.
4. Legacy mode output changes unexpectedly.
5. Existing key controls would be overwritten.
6. Export metadata cannot distinguish carrier from observation domain.
7. NaN or infinite scalar values appear.
8. A proposed refactor begins to include STL import, SDF voxelization, intrinsic coordinates, or entropic scheduling.

When a blocker occurs, make the smallest diagnostic change needed and report the exact function and data boundary involved.

---

## 27. Explicit Non-Goals

Do not implement in Milestone 1:

- external STL, OBJ, PLY, or 3MF domain loading;
- mesh watertightness checks;
- mesh repair;
- triangle ray casting;
- voxelized imported-mesh SDF;
- arbitrary domain curvature;
- medial axis extraction;
- PCA centerlines;
- intrinsic `s`, `r`, or `theta`;
- front propagation;
- Emergent Entropic Scheduler;
- Shannon, Renyi, Tsallis, or spectral entropy models;
- adaptive density fields;
- orientation fields;
- stress maps;
- FEA;
- marching cubes;
- dual contouring;
- GPU compute;
- hyperuniformity classification;
- persistent homology;
- medical or prosthetic claims.

Milestone 1 is a controlled architectural proof, not the final domain engine.

---

## 28. Recommended Commit Sequence

Keep every commit buildable.

```text
1. feat: add primitive observation-domain data structures
2. feat: add uniform-grid observer and flat DCRTE volume
3. test: add analytic primitive and observer fixtures
4. feat: add hard-interior and shell-band observation layers
5. feat: add immediate activation and primitive pipeline mode
6. feat: adapt masked DCRTE volume to legacy materializer
7. feat: add primitive preview and DCRTE diagnostics panel
8. feat: add domain and volume validation report
9. feat: extend Surface Foundry JSON provenance for milestone 1
10. test: run primitive acceptance matrix and legacy regression
11. docs: add milestone 1 usage, limits, and measured performance
```

Do not combine all work into one opaque commit.

---

## 29. Required Documentation Update

Update the Visual Observatory README or a dedicated DCRTE implementation note.

Required content:

- explanation of primitive observation domains;
- statement that domains constrain observation and do not deform the field;
- pipeline mode descriptions;
- distinction between field carrier and observation domain;
- controls;
- hard-interior behavior;
- interior shell-band behavior;
- resolution guidance;
- validation meanings;
- raised-vein policy;
- export metadata example;
- limitations and Milestone 2 boundary.

Use this language or an equivalent statement:

> In DCRTE primitive mode, the recursive field remains unchanged. Sphere, box, and cylinder domains act as finite observation constraints. Material is produced only where the selected domain admits a field sample and the existing Surface Foundry material rule classifies that sample as solid.

---

## 30. Deliverables

Codex must provide:

1. Modified Processing sketch.
2. New or extended PDE tabs.
3. Updated pipeline selector.
4. Sphere, box, and cylinder domains.
5. Uniform grid observer.
6. Hard-interior and shell-band observation layers.
7. Immediate static scheduler.
8. Legacy materializer adapter.
9. Domain preview.
10. Validation report.
11. Extended JSON metadata.
12. Deterministic test fixtures.
13. Updated documentation.
14. A concise implementation report containing:
    - files changed;
    - interfaces added;
    - existing functions wrapped;
    - coordinate range used;
    - test results;
    - build timings;
    - validation counts for all six acceptance runs;
    - raised-vein policy;
    - known limitations;
    - recommended Milestone 2 refactor boundaries.

Do not commit large generated STL files. Small JSON fixtures or compact metric snapshots are acceptable.

---

## 31. Milestone 1 Acceptance Criteria

Milestone 1 passes only when all of the following are true.

### Architecture

- `FieldEngine` remains independent of domain classes.
- Primitive domains do not call field equations.
- Observation layers do not create mesh triangles.
- Materializer adapter does not own recursive field logic.
- Immediate activation does not depend on rendering frame rate.

### Functional

- sphere domain renders correctly;
- box domain renders correctly;
- cylinder domain renders correctly;
- hard-interior mode works;
- interior shell-band mode works;
- no final material exists outside the admitted domain;
- `64^3` completes as an interactive operation;
- materialization exports through the existing STL path;
- domain metadata accompanies export;
- empty volume is detected;
- full volume is detected;
- non-finite field values are detected;
- outside-domain material is a hard failure.

### Regression

- `LEGACY_DIRECT` still works;
- `DCRTE_ADAPTER_TEST` still passes;
- current controls remain available;
- current call-sheet workflow is not broken;
- current STL and JSON export still works;
- legacy field equations are unchanged.

### Provenance

Every DCRTE primitive export records:

- pipeline mode;
- field engine ID and version;
- configuration ID;
- field carrier;
- domain type and parameters;
- observer bounds and resolution;
- observation mode;
- shell thickness when relevant;
- scheduler type;
- materializer adapter;
- raised-vein policy;
- validation report;
- deterministic seed;
- timing measurements.

---

## 32. Expected Result

At the end of Milestone 1, Surface Foundry should be able to show the same recursive field as several different emergent material bodies:

```text
same field + sphere domain   -> spherical realization
same field + box domain      -> box-constrained realization
same field + cylinder domain -> cylindrical realization
```

These are not deformed versions of a source mesh.

They are separate observations and materializations of the same recursive field.

This milestone establishes the core DCRTE claim at the software level:

> **The field is primary. The observation domain determines where geometry may emerge.**

---

## 33. Copy-Paste Codex Prompt

Use the full work order above as the canonical instruction. The following compact prompt may be placed before it when starting the Codex task:

```text
Implement DCRTE-ET Milestone 1 in the Cosmosis Visual Observatory.

Milestone 0 has passed. Begin by inspecting the actual Milestone 0 classes and the existing Surface Foundry generation, materialization, export, UI, and key-handling paths.

Add a new DCRTE_PRIMITIVE pipeline that evaluates the existing FieldEngine through a UniformGridObserver and constrains materialization with analytic sphere, axis-aligned box, and finite Y-axis cylinder observation domains. Implement hard-interior and inside-only shell-band observation layers, immediate static activation, a legacy materializer adapter, primitive preview, deterministic tests, domain/volume validation, timing diagnostics, and reproducible JSON metadata.

Preserve LEGACY_DIRECT and DCRTE_ADAPTER_TEST. Do not change field equations. Do not implement imported meshes, mesh SDFs, intrinsic coordinates, propagation, entropic scheduling, new meshing algorithms, or advanced analysis.

Use flat primitive arrays, avoid per-voxel object allocation, prevent all material outside the admitted domain, and disable primitive-mode raised veins unless they are explicitly clipped. Run the six-domain acceptance matrix, legacy regression, and adapter regression. Return a concise implementation report with files changed, tests, counts, timings, limitations, and Milestone 2 boundaries.

Treat the attached Milestone 1 work order as the architecture contract.
```

---

## 34. Handoff to Milestone 2

Do not implement Milestone 2 yet.

The Milestone 1 implementation report should identify the clean insertion points for:

```text
ImportedMeshDomain
MeshDomainReport
VoxelizedBoundary
SignedDistanceVolume
StrictInvalidDomainPolicy
SDF slice preview
```

The primitive `ObservationDomain` interface and `UniformGridObserver` should be designed so that an imported-mesh SDF domain can replace a primitive without changing:

- `FieldEngine`;
- Observation Layer;
- immediate scheduler;
- material rule;
- DCRTE volume;
- legacy materializer adapter;
- validation report structure.

That replaceability is the final architectural test of Milestone 1.

---

**End of Work Order**
