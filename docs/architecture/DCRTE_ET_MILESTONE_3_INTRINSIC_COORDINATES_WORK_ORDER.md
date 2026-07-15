# Work Order: DCRTE-ET Milestone 3

## Basic Intrinsic Coordinate System for Imported Observation Domains

**Version:** 1.0
**Status:** Ready for Codex implementation after Milestone 2.5
**Project:** Surface Foundry / Cosmosis RDFT Suite
**Architecture:** DCRTE-ET Architecture Specification v0.3
**Prerequisites:** Milestones 0, 1, 2, and 2.5 have passed
**Primary application:** `apps/cosmosis-visual-observatory/`

---

# 1. Codex Directive

Implement the first intrinsic-coordinate system for DCRTE-ET.

Milestone 3 must allow the existing recursive field to be sampled in coordinates derived from the imported observation domain rather than only in global Cartesian coordinates.

The first implementation is intended for:

- one dominant connected closed domain;
- elongated or approximately axial forms;
- the canonical egg;
- cylinders and capsules;
- simple limb-like or bone-like shells;
- non-branching organic enclosures.

It is not intended for:

- branching trees;
- hands or antlers;
- vascular networks;
- toroidal domains;
- multiple disconnected bodies;
- highly concave domains with ambiguous centerlines;
- domains that fail Milestone 2.5 preflight.

The recursive field equations must remain unchanged.

The coordinate system changes only the coordinates supplied to the field engine.

It does not deform a finished field object or mesh.

Required modes:

```text
CARTESIAN
INTRINSIC_AXIAL
```

The application must support controlled comparison between the two modes using the same:

- imported domain;
- SDF;
- observer;
- field parameters;
- seed;
- material rule;
- scheduler;
- materializer;
- output scale.

---

# 2. Core Principle

> Fields are primary. Geometry is emergent. Coordinates determine how the field is observed, not what object the engine believes it is building.

In Cartesian mode:

```text
fieldSample = F(x, y, z)
```

In intrinsic axial mode:

```text
fieldSample = F(s', u', v')
```

where:

```text
s     = normalized arc length along a domain-derived centerline
r     = radial distance from that centerline
theta = angular coordinate in a transported local frame
rho   = normalized radial distance
u'    = rho * cos(theta)
v'    = rho * sin(theta)
s'    = mapped longitudinal coordinate
```

The field remains the same mathematical function.

Only its input coordinate frame changes.

---

# 3. Milestone Goal

Prove this pipeline:

```text
Preflight-qualified imported domain
      |
      v
Inside mask and signed distance volume
      |
      v
Principal-axis analysis
      |
      v
Cross-sectional centroid samples
      |
      v
Smoothed centerline
      |
      v
Arc-length parameterization
      |
      v
Parallel-transport local frames
      |
      v
Per-voxel intrinsic coordinates
      |
      v
Coordinate-system mapper
      |
      v
Existing FieldEngine
      |
      v
Existing Observation Layer
      |
      v
Existing material rule and materializer
```

Milestone 3 passes when the canonical egg and imported cylinder can be generated in both Cartesian and intrinsic modes, with deterministic coordinates, no material outside the domain, and clear diagnostics identifying where the intrinsic map is reliable or uncertain.

---

# 4. Architectural Boundary

Introduce a coordinate-mapping layer between the observer and the field engine.

Current conceptual flow:

```text
observer world coordinate
      |
      v
FieldEngine.sample(x, y, z)
```

Milestone 3 flow:

```text
observer world coordinate
      |
      v
FieldCoordinateSystem.map(...)
      |
      v
field coordinate
      |
      v
FieldEngine.sample(fx, fy, fz)
```

The `FieldEngine` must not import or depend on:

- triangle meshes;
- SDF classes;
- centerlines;
- PCA;
- coordinate confidence;
- domain semantics.

The coordinate system owns the translation from observed domain position to field-input coordinates.

---

# 5. Required Interfaces

Implement or adapt:

```java
interface FieldCoordinateSystem {
  FieldCoordinateSample mapAtIndex(
    int x,
    int y,
    int z,
    float worldX,
    float worldY,
    float worldZ
  );

  String getId();
  String getVersion();

  boolean isValid();
  String validationMessage();

  JSONObject toJSON();
}
```

## 5.1 FieldCoordinateSample

```java
class FieldCoordinateSample {
  float fieldX;
  float fieldY;
  float fieldZ;

  float s;
  float radialDistance;
  float normalizedRadius;
  float theta;
  float signedBoundaryDistance;
  float confidence;

  int centerlineIndex;

  boolean valid;
  boolean fallbackUsed;
}
```

Not every coordinate mode must populate every intrinsic quantity.

## 5.2 CartesianCoordinateSystem

Implement:

```java
class CartesianCoordinateSystem
  implements FieldCoordinateSystem
```

This must formally reproduce the existing world-to-field coordinate mapping.

It is the regression baseline.

## 5.3 IntrinsicAxialCoordinateSystem

Implement:

```java
class IntrinsicAxialCoordinateSystem
  implements FieldCoordinateSystem
```

It consumes:

- preflight-qualified `SignedDistanceVolume`;
- dominant inside component;
- observer bounds;
- `CenterlineModel`;
- `TransportFrameField`;
- radial normalization model;
- coordinate-scaling configuration;
- confidence model.

---

# 6. Suitability Gate

Milestone 3 must not attempt intrinsic coordinates for every valid mesh.

Implement:

```java
class IntrinsicSuitabilityReport {
  ValidationStatus status;

  int insideComponentCount;
  float dominantComponentFraction;

  float principalEigenvalue1;
  float principalEigenvalue2;
  float principalEigenvalue3;

  float elongationRatio12;
  float elongationRatio13;

  float centerlineCoverage;
  float validSliceFraction;
  float maximumSliceGapFraction;

  float centerlineSelfApproachRisk;
  float nearestPointAmbiguityFraction;
  float frameContinuityScore;
  float radialNormalizationConfidence;

  boolean singleDominantComponent;
  boolean closedLoopSuspected;
  boolean branchingSuspected;
  boolean suitable;

  ArrayList<String> blockers;
  ArrayList<String> warnings;

  JSONObject toJSON();
}
```

## 6.1 Blocker identifiers

```text
IC_DOMAIN_NOT_PREFLIGHT_QUALIFIED
IC_INSIDE_MASK_EMPTY
IC_MULTIPLE_DOMINANT_COMPONENTS
IC_AXIS_UNDEFINED
IC_CENTERLINE_COVERAGE_LOW
IC_CENTERLINE_DISCONTINUOUS
IC_BRANCHING_SUSPECTED
IC_CLOSED_LOOP_SUSPECTED
IC_FRAME_BUILD_FAILED
IC_MAPPING_AMBIGUITY_HIGH
IC_NONFINITE_COORDINATES
```

## 6.2 Warning identifiers

```text
IC_LOW_ELONGATION
IC_CROSS_SECTION_VARIATION_HIGH
IC_CONCAVITY_HIGH
IC_NEAREST_CENTERLINE_AMBIGUOUS
IC_RADIAL_NORMALIZATION_APPROXIMATE
IC_ENDPOINT_CONFIDENCE_LOW
IC_FRAME_TWIST_ELEVATED
IC_THIN_FEATURE_RISK
```

## 6.3 Initial suitability policy

Recommended initial values:

```text
dominant component fraction >= 0.98
valid slice fraction         >= 0.85
centerline coverage          >= 0.90
maximum slice gap fraction   <= 0.08
mapping ambiguity fraction   <= 0.05
```

Elongation should begin as a warning rather than an automatic blocker.

Expected:

- egg passes;
- cylinder passes;
- curved capsule passes;
- sphere warns;
- torus blocks;
- Y-branch blocks;
- disconnected paired bodies block.

---

# 7. New PDE Tabs

Create unless equivalent files already exist:

```text
DCRTE_CoordinateSystem.pde
DCRTE_IntrinsicSuitability.pde
DCRTE_PCA.pde
DCRTE_Centerline.pde
DCRTE_TransportFrames.pde
DCRTE_RadialModel.pde
DCRTE_IntrinsicVolume.pde
DCRTE_IntrinsicVisualization.pde
DCRTE_M3_Tests.pde
```

Optional:

```text
DCRTE_IntrinsicBuildJob.pde
```

Do not move the entire Processing application into Java packages.

---

# 8. Dominant Interior Component

Intrinsic coordinates must be built from one dominant inside component.

Use the Milestone 2.5 component analysis.

Required behavior:

1. identify connected components in the inside voxel mask;
2. rank by voxel count;
3. compute dominant fraction;
4. reject multiple similarly dominant components;
5. ignore tiny secondary components only for diagnostic analysis, not silently;
6. build intrinsic coordinates only over the accepted dominant component.

If tiny components are excluded from intrinsic mapping:

- count them;
- preserve them in the preflight report;
- do not materialize them in intrinsic mode unless an explicit policy is selected;
- export the policy.

Recommended default:

```text
BLOCK when any secondary component exceeds 2% of inside volume.
```

---

# 9. Principal-Axis Analysis

Use the interior voxels of the accepted dominant component.

## 9.1 Weighting modes

Support:

```text
UNIFORM_INSIDE
DISTANCE_WEIGHTED
```

Default:

```text
DISTANCE_WEIGHTED
```

Recommended weight:

```text
weight = max(-sdf, minimumPositiveWeight)
```

This gives more influence to voxels farther from the boundary and reduces sensitivity to surface voxel aliasing.

## 9.2 PCA output

```java
class PCAFrame {
  float centerX;
  float centerY;
  float centerZ;

  float axis1X;
  float axis1Y;
  float axis1Z;

  float axis2X;
  float axis2Y;
  float axis2Z;

  float axis3X;
  float axis3Y;
  float axis3Z;

  float eigenvalue1;
  float eigenvalue2;
  float eigenvalue3;

  boolean valid;

  JSONObject toJSON();
}
```

Sort eigenvalues in descending order.

`axis1` is the initial longitudinal axis.

## 9.3 Deterministic sign policy

PCA axes have sign ambiguity.

Choose the longitudinal sign deterministically:

1. estimate equivalent cross-sectional radius near both ends;
2. direct `s = 0` toward the end with the smaller equivalent radius;
3. this makes the canonical egg's narrower end the origin;
4. if end radii are nearly equal, choose the sign whose dominant world-axis component is positive;
5. export the chosen policy and measured end radii.

Do not use random sign selection.

## 9.4 PCA implementation

Implement a stable symmetric 3x3 eigensolver or use an already approved repository dependency.

Required tests:

- X-aligned cylinder;
- Y-aligned cylinder;
- arbitrarily rotated cylinder;
- egg;
- nearly spherical domain;
- degenerate flat or invalid volume.

---

# 10. Axial Slice Construction

For each dominant-component voxel:

```text
q = p - PCA center
axialCoordinate = dot(q, axis1)
```

Determine:

```text
axialMin
axialMax
```

from accepted inside voxels.

## 10.1 Slice count

Default:

```text
sliceCount = max(32, observer resolution)
```

Examples:

```text
64^3  -> 64 slices
128^3 -> 128 slices
```

Make this configurable.

## 10.2 Slice data

Implement:

```java
class AxialSliceSample {
  int sliceIndex;
  float axialPosition;

  int insideVoxelCount;
  float weightSum;

  float centroidX;
  float centroidY;
  float centroidZ;

  float equivalentRadius;
  float maxRadialExtent;

  float covariance00;
  float covariance01;
  float covariance11;

  float majorRadius;
  float minorRadius;
  float crossSectionAngle;

  boolean valid;
  float confidence;
}
```

Compute centroids from inside voxels in the slice.

Preferred weight:

```text
max(-sdf, smallPositiveValue)
```

## 10.3 Equivalent radius

Estimate cross-sectional area:

```text
area = insideVoxelCount * approximateProjectedVoxelArea
equivalentRadius = sqrt(area / PI)
```

The first implementation may use isotropic voxel-face area.

Document that oblique slice area is approximate.

## 10.4 Sparse slices

Mark a slice invalid when:

```text
insideVoxelCount < minimumSliceVoxelCount
```

Recommended:

```text
minimumSliceVoxelCount = 4
```

Do not construct a centerline from isolated one-voxel slices.

---

# 11. Centerline Construction

## 11.1 Raw centerline

Use valid axial-slice centroids ordered by axial position.

## 11.2 Short-gap interpolation

Interpolate only short gaps.

Recommended:

```text
maximumInterpolatedGap =
  max(2 slices, 0.04 * sliceCount)
```

Longer gaps block intrinsic construction.

Every interpolated slice must be counted and exported.

## 11.3 Smoothing

Use a deterministic Processing-compatible method.

Preferred first implementation:

- weighted moving average;
- two or three passes;
- endpoint-preserving weights;
- optional Catmull-Rom resampling afterward.

Do not smooth so aggressively that the centerline leaves the domain.

After smoothing, verify every centerline point against the SDF.

If a sample leaves the domain:

- attempt a conservative correction toward the raw centroid;
- reduce confidence;
- block if it cannot be restored safely.

## 11.4 Arc-length resampling

Resample to near-uniform arc-length spacing.

Default:

```text
centerlineSampleCount = sliceCount
```

Implement:

```java
class CenterlinePoint {
  float x;
  float y;
  float z;

  float arcLength;
  float normalizedS;

  float equivalentRadius;
  float majorRadius;
  float minorRadius;

  float tangentX;
  float tangentY;
  float tangentZ;

  float confidence;
}
```

## 11.5 Endpoint inset

The geometric poles are poorly resolved and radial normalization approaches zero.

Inset endpoints:

```text
endpointInset = 1.5 * voxelSpacing
```

Move inward along the centerline until SDF confidence is stable.

Record:

- original endpoint estimate;
- inset endpoint;
- inset distance;
- endpoint confidence.

## 11.6 Validation

Check:

- finite points;
- positive total length;
- monotonic arc length;
- no large step discontinuity;
- every point inside;
- adequate longitudinal coverage;
- no near self-crossings between non-neighbor segments;
- no suspected branching.

---

# 12. Parallel-Transport Frames

Do not use Frenet frames as the primary method.

Frenet frames become unstable when curvature approaches zero.

## 12.1 Frame structure

```java
class TransportFrame {
  float tx;
  float ty;
  float tz;

  float nx;
  float ny;
  float nz;

  float bx;
  float by;
  float bz;

  float twistFromPrevious;
  float confidence;
}
```

## 12.2 Initial frame

At the first centerline point:

1. compute tangent from a forward difference;
2. use PCA axis 2 as the initial normal when sufficiently nonparallel;
3. otherwise use the world axis least aligned with the tangent;
4. orthogonalize the normal;
5. compute the binormal;
6. normalize all three axes.

Record the selected initial-normal policy.

## 12.3 Transport step

For consecutive tangents `t0` and `t1`:

1. compute `cross(t0, t1)`;
2. compute minimal rotation angle with `atan2`;
3. rotate previous normal and binormal through the minimal rotation;
4. re-orthonormalize;
5. preserve handedness and sign continuity.

When tangents are nearly parallel:

- carry the previous normal forward;
- re-orthonormalize.

When tangents are nearly opposite:

- report a frame-build blocker or severe confidence loss.

## 12.4 Twist diagnostics

Report:

- mean frame rotation per segment;
- maximum rotation;
- cumulative rotation;
- samples above warning threshold;
- sign flips;
- discontinuity count.

Accepted fixtures should have no unexplained frame sign flips.

---

# 13. Nearest Centerline Mapping

For each admitted voxel, find the nearest centerline segment.

## 13.1 Initial index estimate

Use PCA axial projection to estimate centerline position:

```text
estimatedIndex =
  round(normalizedAxialPosition * (sampleCount - 1))
```

Search a local window around that index.

Recommended:

```text
searchRadius = 6 samples
```

If the optimum lies on the window edge, expand once.

## 13.2 Segment projection

Use nearest point on line segments rather than only nearest centerline sample.

For every candidate segment:

- project voxel position onto the segment;
- clamp the segment parameter;
- compute squared distance;
- retain the minimum;
- interpolate normalized arc length;
- interpolate and re-orthonormalize the transported frame.

## 13.3 Ambiguity detection

Track the best and second-best nonadjacent segment distance.

A mapping is ambiguous when:

```text
secondBestDistance - bestDistance
  < ambiguityTolerance
```

and the two candidate segments are separated beyond a local-neighbor threshold.

This identifies concave regions where one point is similarly close to remote centerline sections.

Count and visualize ambiguity.

## 13.4 Intrinsic values

For nearest point `c` and transported frame `(t,n,b)`:

```text
delta = p - c

s = interpolated normalized arc length

radialN = dot(delta, n)
radialB = dot(delta, b)

r = sqrt(radialN^2 + radialB^2)
theta = atan2(radialB, radialN)

d = imported SDF value
```

Normalize:

```text
theta in [-PI, PI)
```

---

# 14. Radial Normalization

Raw radius changes across eggs and other domains.

Milestone 3 requires approximate normalized radius.

## 14.1 Equivalent-circular model

Interpolate slice equivalent radius:

```text
R_eq(s)
```

Then:

```text
rho = r / max(R_eq(s), epsilon)
```

This is the required first implementation.

## 14.2 Optional elliptical model

If slice covariance is stable, support:

```text
EQUIVALENT_CIRCULAR
ELLIPTICAL
```

For elliptical mode:

```text
rho =
  sqrt(
    (u / majorRadius)^2
    +
    (v / minorRadius)^2
  )
```

where `u` and `v` are expressed in the local cross-sectional principal frame.

Default:

```text
EQUIVALENT_CIRCULAR
```

until elliptical mode passes its fixtures.

## 14.3 Interpretation

Because an imported domain may be irregular:

```text
rho = 1
```

will not equal the boundary in every direction.

Always export:

```text
IC_RADIAL_NORMALIZATION_APPROXIMATE
```

when using the equivalent-radius model.

Do not describe rho as exact geodesic or harmonic radius.

---

# 15. Intrinsic Coordinate Volume

Implement flat storage:

```java
class IntrinsicCoordinateVolume {
  VolumeSpec spec;

  float[] s;
  float[] radialDistance;
  float[] normalizedRadius;
  float[] theta;
  float[] confidence;

  int[] centerlineIndex;

  boolean[] valid;
  boolean[] ambiguous;
  boolean[] fallbackUsed;

  int validCount;
  int ambiguousCount;
  int fallbackCount;
  int nonFiniteCount;

  JSONObject toJSON();
}
```

## 15.1 Storage policy

At `64^3`, precompute all intrinsic arrays.

At `128^3`, full precomputation is preferred.

A reduced-memory mode is allowed only if:

- reproducibility remains intact;
- confidence and ambiguity are still available;
- the mode is explicit in metadata.

Do not allocate one object per voxel.

## 15.2 Outside voxels

Intrinsic coordinates are required only for accepted inside or admitted voxels.

Outside voxels may remain invalid.

## 15.3 Cache invalidation

Rebuild intrinsic coordinates when:

- source domain changes;
- transform changes;
- SDF changes;
- observer resolution changes;
- inside component changes;
- centerline settings change;
- radial model changes;
- coordinate-system version changes.

Do not rebuild when only:

- seed changes;
- field alpha changes;
- field phase changes;
- material threshold changes;
- observation switches between hard interior and shell band;
- visualization slice changes.

---

# 16. Mapping Intrinsic Values to Field Inputs

The existing field engine expects three scalar coordinates.

Use the seam-free cylindrical embedding:

```text
fieldX = longitudinalScale * (2*s - 1)

fieldY =
  radialScale
  * rho
  * cos(theta)

fieldZ =
  radialScale
  * rho
  * sin(theta)
```

Defaults:

```text
longitudinalScale = 1.0
radialScale = 1.0
```

The field equations remain unchanged.

## 16.1 Required mapping ID

```text
INTRINSIC_CYLINDRICAL_EMBEDDING
```

Raw `(s,r,theta)` field input may be experimental later, but it should not be the default because theta contains a seam.

## 16.2 Centerline behavior

Near the centerline:

```text
r < radialEpsilon
```

theta is undefined.

Set:

```text
theta = 0
```

and reduce angular confidence.

The cylindrical embedding remains continuous because both radial coordinates approach zero.

## 16.3 Pole behavior

Near narrow domain endpoints:

- clamp `R_eq(s)` to a positive epsilon;
- reduce confidence;
- use endpoint inset;
- never produce non-finite rho;
- report clamped voxel count.

---

# 17. Confidence Model

Every intrinsic voxel receives confidence in `[0,1]`.

Suggested factors:

```text
preflight resolution confidence
slice confidence
centerline confidence
frame confidence
nearest-segment uniqueness
radial-model confidence
endpoint confidence
```

A conservative minimum model is acceptable:

```text
confidence =
  min(
    resolutionConfidence,
    sliceConfidence,
    centerlineConfidence,
    frameConfidence,
    ambiguityConfidence,
    radialConfidence,
    endpointConfidence
  )
```

A weighted product is also acceptable if documented.

## 17.1 Fallback policy

Implement:

```java
enum IntrinsicFallbackPolicy {
  BLOCK,
  CARTESIAN_LOCAL_FALLBACK,
  CLAMP_TO_VALID_INTRINSIC
}
```

Default:

```text
BLOCK
```

Optional research preview:

```text
CARTESIAN_LOCAL_FALLBACK
```

If fallback is used:

- mark every fallback voxel;
- count it;
- visualize it;
- export the policy;
- do not call the result fully intrinsic.

Recommended strict export threshold:

```text
fallback fraction <= 0.01
```

---

# 18. Field Pipeline Integration

Required loop:

```java
for each voxel:
  domainSample = domain.sample(...)
  observationSample = observation.observe(domainSample)

  if not observationSample.admitted:
    finalSolid = false
    continue

  coordinateSample =
    selectedCoordinateSystem.mapAtIndex(...)

  if not coordinateSample.valid:
    apply configured fallback
    or block generation

  fieldSample =
    fieldEngine.sample(
      coordinateSample.fieldX,
      coordinateSample.fieldY,
      coordinateSample.fieldZ,
      existing field context
    )

  candidateSolid =
    existing material rule(fieldSample)

  active =
    immediate scheduler(
      observationSample.admitted,
      candidateSolid
    )

  finalSolid = active
```

Do not change:

- field equations;
- material rule;
- scheduler semantics;
- domain admission;
- materializer behavior.

The coordinate system must never classify material directly.

---

# 19. Comparison Mode

Implement:

```java
enum CoordinateComparisonMode {
  SINGLE,
  CARTESIAN_AND_INTRINSIC
}
```

When paired comparison is enabled:

- freeze one immutable field configuration;
- use one seed;
- use one domain and SDF;
- generate Cartesian output;
- generate intrinsic output;
- retain both reports;
- compare metrics;
- display side-by-side or toggle views;
- export paired metadata.

## 19.1 Required comparison metrics

```text
admitted voxel count
candidate solid count
final solid count
solid fraction of domain
connected component count
largest component fraction
outside solid count
field generation time
intrinsic build time
mapping time
ambiguity fraction
fallback fraction
mean confidence
```

Optional:

- Euler characteristic;
- surface area;
- mean local orientation relative to centerline;
- radial continuity;
- longitudinal continuity.

Do not declare one mode superior from appearance alone.

---

# 20. Visualization

Required modes:

```text
CENTERLINE
CENTERLINE_FRAMES
AXIAL_SLICES
INTRINSIC_S
INTRINSIC_R
INTRINSIC_RHO
INTRINSIC_THETA
INTRINSIC_CONFIDENCE
AMBIGUITY
FALLBACK
CARTESIAN_RESULT
INTRINSIC_RESULT
```

## 20.1 Centerline view

Display:

- domain wireframe;
- raw slice centroids;
- smoothed centerline;
- endpoints;
- interpolated gap points;
- low-confidence segments.

## 20.2 Frame view

Display transported frames at a selectable stride.

Draw short vectors for:

- tangent;
- normal;
- binormal.

Also display numerical frame-continuity metrics.

## 20.3 Scalar slice views

Allow selected slices of:

- `s`;
- radial distance;
- rho;
- theta;
- confidence;
- ambiguity;
- fallback.

Theta visualization must account for periodic wrap.

## 20.4 Optional unwrapped map

An optional diagnostic map may show:

```text
horizontal = theta
vertical   = s
```

sampled at a selected rho band.

This is diagnostic only and not used for materialization in Milestone 3.

---

# 21. User Interface

Add an Intrinsic Coordinates panel.

Required summary:

```text
COORDINATE MODE       CARTESIAN / INTRINSIC AXIAL
SUITABILITY           PASS / WARNING / BLOCKED
PCA ELONGATION        1.84
CENTERLINE SAMPLES    64
CENTERLINE LENGTH     1.72
VALID SLICES          61 / 64
FRAME CONTINUITY      0.97
AMBIGUOUS VOXELS      0.8%
FALLBACK VOXELS       0.0%
MEAN CONFIDENCE       0.94
RADIAL MODEL          EQUIVALENT CIRCULAR
LONGITUDINAL SCALE    1.00
RADIAL SCALE          1.00
BUILD STATUS          READY
```

Required controls:

```text
BUILD INTRINSIC
RESET INTRINSIC
COORDINATE MODE
RADIAL MODEL
LONGITUDINAL SCALE
RADIAL SCALE
FALLBACK POLICY
SHOW CENTERLINE
SHOW FRAMES
SHOW CONFIDENCE
COMPARE CARTESIAN
EXPORT INTRINSIC REPORT
```

Changing field parameters must not rebuild intrinsic coordinates.

Changing domain, transform, SDF, resolution, or centerline settings must invalidate them.

---

# 22. Validation Report

Implement:

```java
class IntrinsicValidationReport {
  ValidationStatus status;

  IntrinsicSuitabilityReport suitability;

  int totalInsideVoxels;
  int validIntrinsicVoxels;
  int ambiguousVoxels;
  int fallbackVoxels;
  int nonFiniteVoxels;

  float validFraction;
  float ambiguityFraction;
  float fallbackFraction;

  float centerlineLength;
  float centerlineCoverage;
  float maxCenterlineStep;
  float minimumCenterlineSDFMargin;

  float meanFrameRotation;
  float maxFrameRotation;
  int frameDiscontinuityCount;

  float meanConfidence;
  float p05Confidence;
  float minimumConfidence;

  long pcaMillis;
  long sliceMillis;
  long centerlineMillis;
  long frameMillis;
  long mappingMillis;
  long totalMillis;

  ArrayList<String> errors;
  ArrayList<String> warnings;

  JSONObject toJSON();
}
```

## 22.1 Hard failures

- non-finite PCA;
- undefined primary axis;
- empty dominant component;
- zero centerline length;
- centerline outside domain;
- unresolved long slice gap;
- frame construction failure;
- excessive nonlocal mapping ambiguity;
- non-finite intrinsic values;
- fallback above selected threshold;
- intrinsic generation creates outside-domain material.

## 22.2 Warnings

- low elongation;
- low endpoint confidence;
- approximate radial normalization;
- rapidly changing cross section;
- elevated frame twist;
- curvature high relative to sample spacing;
- SDF resolution low;
- high pole-clamp count.

---

# 23. Deterministic Fixtures

## 23.1 Straight cylinder

Expected:

- PCA axis matches cylinder axis;
- centerline is approximately straight;
- centerline remains near geometric center;
- equivalent radius approximately constant;
- frame twist near zero;
- `s` monotonic;
- rho approximately 1 near side wall;
- ambiguity near zero.

## 23.2 Rotated cylinder

Rotate by fixed non-axis-aligned angles.

Expected:

- PCA recovers longitudinal axis;
- intrinsic distributions remain comparable;
- field metrics remain comparable;
- no dependency on world orientation beyond voxel discretization.

## 23.3 Canonical egg

Expected:

- centerline follows long axis;
- narrow end becomes `s = 0`;
- equivalent radius grows toward broad region;
- valid-slice fraction high;
- frame continuity high;
- intrinsic materialization succeeds;
- no outside material.

## 23.4 Rotated egg

Expected:

- deterministic sign policy remains stable;
- centerline and radius profile remain comparable;
- intrinsic output metrics remain comparable;
- Cartesian output may change relative to world-fixed coordinates.

## 23.5 Sphere

Expected:

- low-elongation warning;
- deterministic but geometrically nonunique PCA axis;
- no false claim of unique intrinsic orientation;
- intrinsic mode may pass with warning or block according to configured suitability policy.

## 23.6 Bent capsule

Create a smooth, non-branching curved capsule.

Expected:

- centerline follows the bend;
- parallel-transport frames remain continuous;
- no Frenet-style frame flips;
- mapping ambiguity remains below threshold.

## 23.7 Torus

Expected:

- closed-loop suspicion;
- block `INTRINSIC_AXIAL`;
- Cartesian mode remains available.

## 23.8 Y-branch

Expected:

- branching suspicion;
- block `INTRINSIC_AXIAL`;
- no forced single centerline.

## 23.9 Two disconnected eggs

Expected:

- multiple dominant components;
- intrinsic mode blocked.

---

# 24. Materialization Acceptance Matrix

Use one approved field configuration and seed.

| Test | Domain | Coordinate mode | Expected |
|---|---|---|---|
| M3-A | Imported cylinder | Cartesian | Baseline passes |
| M3-B | Imported cylinder | Intrinsic axial | Passes |
| M3-C | Canonical egg | Cartesian | Baseline passes |
| M3-D | Canonical egg | Intrinsic axial | Passes |
| M3-E | Rotated egg | Intrinsic axial | Comparable intrinsic metrics |
| M3-F | Bent capsule | Intrinsic axial | Passes with continuous frames |
| M3-G | Sphere | Intrinsic axial | Warning or policy block |
| M3-H | Torus | Intrinsic axial | Blocked |
| M3-I | Y-branch | Intrinsic axial | Blocked |
| M3-J | Two eggs | Intrinsic axial | Blocked |

For every passing materialization:

- outside material count is zero;
- final volume is nonempty;
- field values are finite;
- coordinate values are finite;
- metadata is complete;
- result reproduces from seed and configuration;
- legacy materializer succeeds.

---

# 25. Rigid-Rotation Comparison

The purpose is to test coordinate behavior, not prove topological invariance.

For the same egg:

1. generate or load source mesh;
2. apply fixed rigid rotation;
3. rebuild SDF;
4. rebuild intrinsic coordinates;
5. use the same field seed and settings;
6. compare coordinate distributions and output metrics.

Expected intrinsic behavior:

- comparable centerline length;
- comparable equivalent-radius profile;
- comparable confidence;
- comparable solid fraction;
- comparable component counts;
- no world-axis dependence beyond discretization.

Expected Cartesian behavior:

- the world-fixed field may intersect the rotated domain differently.

Document:

> Cartesian mode observes a world-fixed recursive field. Intrinsic mode observes the unchanged recursive field through a domain-relative coordinate frame.

---

# 26. Metadata

Extend existing DCRTE metadata.

Example:

```json
{
  "coordinate_system": {
    "type": "intrinsic_axial",
    "version": "1.0",
    "mapping": "cylindrical_embedding",
    "longitudinal_scale": 1.0,
    "radial_scale": 1.0,
    "radial_model": "equivalent_circular",
    "fallback_policy": "block"
  },
  "intrinsic_suitability": {
    "status": "pass",
    "dominant_component_fraction": 1.0,
    "elongation_ratio_12": 1.84,
    "valid_slice_fraction": 0.953,
    "centerline_coverage": 0.968,
    "ambiguity_fraction": 0.008,
    "branching_suspected": false,
    "closed_loop_suspected": false
  },
  "centerline": {
    "sample_count": 64,
    "length": 1.72,
    "endpoint_inset": 0.046875,
    "smoothing_method": "weighted_moving_average",
    "smoothing_passes": 3,
    "sign_policy": "smaller_end_radius_is_s_zero"
  },
  "frames": {
    "method": "parallel_transport",
    "initial_normal_policy": "pca_second_axis",
    "mean_rotation": 0.014,
    "max_rotation": 0.083,
    "discontinuities": 0
  },
  "intrinsic_volume": {
    "valid_voxels": 91284,
    "ambiguous_voxels": 702,
    "fallback_voxels": 0,
    "mean_confidence": 0.94,
    "p05_confidence": 0.81
  }
}
```

Every intrinsic result must retain all existing:

- source mesh;
- preflight;
- transform;
- SDF;
- observer;
- observation;
- field;
- scheduler;
- materializer;
- validation;
- output-scale metadata.

---

# 27. Performance

Record phase timings.

## 27.1 Target at 64³

For an egg or cylinder:

```text
PCA and slices       <= 3 seconds
centerline and frame <= 3 seconds
voxel mapping        <= 15 seconds
```

These are development targets, not universal hardware guarantees.

## 27.2 Target at 128³

Supported research build:

```text
intrinsic build <= 120 seconds
```

If exceeded:

- report the bottleneck;
- preserve resolution;
- do not silently downsample;
- keep architecture correct.

## 27.3 Memory

At `128³`, multiple float arrays and one integer array may be significant.

Report measured memory where practical.

Do not allocate per-voxel coordinate objects.

---

# 28. Stop Conditions

Codex must stop and report if:

1. intrinsic coordinates require changing recursive field equations;
2. preflight qualification is bypassed;
3. a branching or toroidal domain is forced into one axial centerline;
4. centerline points leave the domain;
5. transported frames flip nondeterministically;
6. rotated copies use inconsistent longitudinal sign;
7. confidence is suppressed to make a fixture pass;
8. fallback is used without being counted;
9. intrinsic material appears outside the domain;
10. legacy, primitive, or imported Cartesian modes regress.

Report:

- exact class and function;
- expected contract;
- observed failure;
- smallest proposed architectural adjustment.

---

# 29. Explicit Non-Goals

Do not implement in Milestone 3:

- full medial-axis transform;
- arbitrary branching curve skeletons;
- graph-valued coordinates;
- toroidal coordinates;
- multiple centerline branches;
- directional boundary-radius ray casting;
- exact geodesic surface coordinates;
- harmonic coordinates;
- conformal maps;
- entropic propagation;
- Emergent Entropic Scheduler;
- stress fields;
- FEA;
- topology optimization;
- automatic mesh repair;
- hyperuniformity analysis;
- claims of topological invariance.

Milestone 3 is intentionally limited to a basic non-branching intrinsic axial coordinate system.

---

# 30. Recommended Commit Sequence

```text
1. feat: add FieldCoordinateSystem and Cartesian baseline
2. feat: add intrinsic suitability report and gates
3. feat: add dominant-component distance-weighted PCA
4. test: add PCA axis and sign determinism fixtures
5. feat: add axial slice statistics and equivalent radii
6. feat: add smoothed arc-length centerline
7. test: add cylinder and egg centerline fixtures
8. feat: add parallel-transport frames
9. test: add straight and bent frame-continuity fixtures
10. feat: add nearest-centerline segment mapping
11. feat: add radial normalization and intrinsic coordinate volume
12. feat: add intrinsic field-coordinate mapping
13. feat: add visualization, ambiguity, and confidence diagnostics
14. feat: add Cartesian-versus-intrinsic comparison mode
15. feat: extend metadata and validation
16. test: run milestone 3 acceptance and milestone 0-2.5 regressions
17. docs: document coordinate meaning, limits, and comparison behavior
```

---

# 31. Documentation Update

Document:

- coordinate-system abstraction;
- Cartesian versus intrinsic observation;
- suitability limits;
- PCA axis;
- slice-centroid centerline;
- smoothing and endpoint inset;
- parallel-transport frames;
- definitions of `s`, `r`, `rho`, `theta`, and signed boundary distance;
- cylindrical field embedding;
- confidence and fallback;
- egg, cylinder, and bent-capsule examples;
- rigid-rotation comparison;
- blocked torus and branch examples;
- explicit statement that intrinsic coordinates do not prove topological invariance;
- Milestone 4 scheduler insertion point.

Use:

> Intrinsic axial mode does not deform a generated object into the imported domain. It derives a longitudinal centerline and transported local frames from the qualified domain, maps each observed point into domain-relative coordinates, and evaluates the unchanged recursive field in that coordinate system.

Also state:

> The first intrinsic system is intentionally limited to one dominant non-branching closed domain. Domains with loops, branches, multiple dominant components, or unreliable centerlines remain available in Cartesian mode but are blocked from intrinsic axial mode.

---

# 32. Deliverables

Codex must provide:

1. `FieldCoordinateSystem`.
2. `CartesianCoordinateSystem`.
3. `IntrinsicAxialCoordinateSystem`.
4. `FieldCoordinateSample`.
5. dominant-component selection.
6. distance-weighted PCA.
7. deterministic axis-sign policy.
8. axial slice statistics.
9. centerline construction.
10. gap interpolation.
11. smoothing and arc-length resampling.
12. endpoint inset.
13. parallel-transport frames.
14. nearest-segment voxel mapping.
15. equivalent-radius normalization.
16. intrinsic coordinate volume.
17. confidence model.
18. ambiguity diagnostics.
19. fallback policy.
20. suitability report.
21. validation report.
22. UI panel.
23. centerline and frame visualization.
24. intrinsic scalar visualization.
25. Cartesian-versus-intrinsic comparison mode.
26. metadata extension.
27. cylinder, egg, sphere, bent capsule, torus, branch, and disconnected fixtures.
28. regression report.
29. implementation report containing:
    - files changed;
    - interfaces added;
    - PCA method;
    - sign policy;
    - slice settings;
    - smoothing settings;
    - centerline metrics;
    - frame metrics;
    - mapping ambiguity;
    - confidence distribution;
    - fallback count;
    - Cartesian and intrinsic material counts;
    - outside material count;
    - rigid-rotation comparison;
    - performance;
    - known limitations;
    - recommended Milestone 4 insertion points.

---

# 33. Milestone 3 Acceptance Criteria

Milestone 3 passes when:

## Architecture

- field equations remain unchanged;
- coordinate system is modular;
- Cartesian baseline remains equivalent;
- intrinsic mapping depends on qualified domain data, not mesh semantics;
- materializer remains coordinate-agnostic.

## Suitability

- egg passes;
- straight cylinder passes;
- rotated cylinder passes;
- bent capsule passes;
- torus is blocked;
- Y-branch is blocked;
- multiple dominant components are blocked;
- sphere receives low-elongation warning.

## Coordinates

- `s` is finite and monotonic along centerline;
- theta is stable under parallel transport;
- rho is finite;
- centerline remains inside;
- accepted fixtures have zero unexplained frame discontinuities;
- ambiguity is reported;
- fallback is reported;
- rotated copies use deterministic sign conventions.

## Materialization

- Cartesian egg works;
- intrinsic egg works;
- Cartesian cylinder works;
- intrinsic cylinder works;
- intrinsic bent capsule works;
- no outside-domain material;
- no non-finite field values;
- results reproduce from metadata and seed.

## Regression

- Milestone 2.5 preflight works;
- imported Cartesian mode works;
- primitive domains work;
- adapter test passes;
- legacy direct mode works;
- call sheets and exports remain available.

---

# 34. Expected Result

At the end of Milestone 3, the same qualified egg can be observed in two distinct ways:

```text
Cartesian:
  the domain intersects a world-fixed recursive field

Intrinsic:
  the unchanged recursive field is evaluated relative to the
  domain's own longitudinal and radial coordinate structure
```

This gives Surface Foundry an instrument for asking:

> Which statistical and topological characteristics remain stable when the observation domain changes, and which become more stable when the field is evaluated in domain-relative coordinates?

Milestone 3 does not answer that question by assumption.

It constructs the system needed to test it.

---

# 35. Compact Codex Prompt

```text
Implement DCRTE-ET Milestone 3 after Milestone 2.5 passes.

Add a modular FieldCoordinateSystem layer between the UniformGridObserver and the unchanged FieldEngine. Preserve a CartesianCoordinateSystem that reproduces current imported-domain results, and add an IntrinsicAxialCoordinateSystem for one dominant non-branching closed domain.

Build intrinsic coordinates from the qualified inside mask and SDF using dominant-component distance-weighted PCA, axial slice centroids, short-gap interpolation, deterministic smoothing, arc-length centerline resampling, endpoint inset, parallel-transport frames, nearest-centerline segment mapping, equivalent-radius normalization, and cylindrical field embedding:

fieldX = longitudinalScale * (2*s - 1)
fieldY = radialScale * rho * cos(theta)
fieldZ = radialScale * rho * sin(theta)

Do not change field equations or material rules.

Add suitability gates, confidence, ambiguity detection, fallback policy, centerline and frame visualization, intrinsic scalar views, Cartesian-versus-intrinsic comparison mode, deterministic sign selection, metadata, validation, and performance measurements.

The canonical egg and imported cylinder must pass. Rotated cylinder and rotated egg fixtures must produce stable domain-relative mappings. A bent capsule must pass with continuous frames. A torus, Y-branch, and multiple dominant components must be blocked from intrinsic axial mode.

Use flat arrays, deterministic algorithms, no per-voxel objects, no hidden fallback, and no material outside the domain. Preserve every Milestone 0-2.5, legacy, primitive, imported Cartesian, call-sheet, and export path.

Treat the attached Milestone 3 work order as the architecture contract.
```

---

# 36. Handoff to Milestone 4

Do not implement Milestone 4 yet.

Milestone 4 will introduce the pluggable scheduler framework and the first Emergent Entropic Scheduler.

The clean insertion point will be:

```text
qualified domain
      |
      v
selected coordinate system
      |
      v
field candidate state
      |
      v
Scheduler interface
      |
      v
activation and growth state
      |
      v
materialization
```

Milestone 3 must export stable coordinate and confidence fields that a future scheduler can use without coupling the scheduler to mesh parsing or centerline construction.

Potential scheduler observables:

```text
field scalar
SDF distance
intrinsic s
intrinsic rho
intrinsic theta
coordinate confidence
local occupancy entropy
local field variance
growth-front state
```

---

**End of Work Order**
