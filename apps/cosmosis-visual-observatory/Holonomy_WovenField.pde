/*
  Holonomy Loom Field Atlas

  The Loom owns one canonical, inspectable field artifact. Surface Foundry
  never rebuilds that field: it captures the same artifact, transports its
  (u,v) coordinates through the selected carrier/domain mapping, and samples
  the stored adaptive atlas. The final fabrication observer may remain a
  uniform voxel grid, but the transported field now contains literal stepped
  atlas cells, phase accumulation, and explicit scale-transition gradients.
*/

enum HolonomyWovenMode {
  OFF,
  SURFACE_SKIN,
  VOLUME_WEAVE,
  GRADIENT_RELIEF;

  String id() { return name().toLowerCase(); }
  String label() {
    if (this == SURFACE_SKIN) return "SKIN";
    if (this == VOLUME_WEAVE) return "VOLUME";
    if (this == GRADIENT_RELIEF) return "RELIEF";
    return "OFF";
  }
}

final int HOLONOMY_FIELD_COLS = 72;
final int HOLONOMY_FIELD_ROWS = 48;
final int HOLONOMY_FIELD_MAX_LEVEL = 5;
final String HOLONOMY_FIELD_SCHEMA = "holonomy_loom_field_atlas_v2";

HolonomyWovenMode holonomyWovenMode = HolonomyWovenMode.OFF;
float holonomyWovenDepthSpan = 4.0f;
float holonomyWovenAlphaSpan = 1.25f;
float holonomyWovenBoundaryCoupling = 0.72f;
float holonomyWovenAmplitude = 0.52f;

HolonomyFieldArtifact holonomyWovenLiveField = null;
HolonomyFieldArtifact holonomyWovenCapturedField = null;
HolonomyFieldArtifact holonomyWovenFoundryField = null;
boolean holonomyWovenFieldLocked = false;
String holonomyWovenLiveSignature = "";
int holonomyWovenLastLiveBuildFrame = -9999;
float holonomyWovenMappedU = 0;
float holonomyWovenMappedV = 0;
DCRTEM1TestReport holonomyWovenTests = new DCRTEM1TestReport();

class HolonomyFieldArtifact {
  int cols;
  int rows;
  float[][] value;
  float[][] phase;
  float[][] continuousDepth;
  float[][] localAlpha;
  float[][] gradient;
  int[][] recursionLevel;
  int[][] cellSpan;
  String artifactId = "unbuilt";
  String schema = HOLONOMY_FIELD_SCHEMA;
  HolonomyWovenMode mode = HolonomyWovenMode.OFF;
  boolean reversed;
  float phaseStart;
  float phaseEnd;
  float accumulatedPhase;
  float closureError;
  float loopArea;
  float gammaSnapshot;
  float minimumDepth = Float.MAX_VALUE;
  float maximumDepth = -Float.MAX_VALUE;
  int minimumCellSpan = Integer.MAX_VALUE;
  int maximumCellSpan = Integer.MIN_VALUE;
  PImage previewImage = null;

  HolonomyFieldArtifact(int cols, int rows) {
    this.cols = cols;
    this.rows = rows;
    value = new float[rows][cols];
    phase = new float[rows][cols];
    continuousDepth = new float[rows][cols];
    localAlpha = new float[rows][cols];
    gradient = new float[rows][cols];
    recursionLevel = new int[rows][cols];
    cellSpan = new int[rows][cols];
  }

  int column(float u) {
    return constrain(floor(holonomyWovenFract(u) * cols), 0, cols - 1);
  }

  int row(float v) {
    return constrain(floor(constrain(v, 0, 0.999999f) * rows), 0, rows - 1);
  }

  float sampleValue(float u, float v) { return value[row(v)][column(u)]; }
  float samplePhase(float u, float v) { return phase[row(v)][column(u)]; }
  float sampleDepth(float u, float v) { return continuousDepth[row(v)][column(u)]; }
  float sampleAlpha(float u, float v) { return localAlpha[row(v)][column(u)]; }
  float sampleGradient(float u, float v) { return gradient[row(v)][column(u)]; }
  int sampleLevel(float u, float v) { return recursionLevel[row(v)][column(u)]; }
  int sampleCellSpan(float u, float v) { return cellSpan[row(v)][column(u)]; }
}

void initializeHolonomyWovenField() {
  rebuildHolonomyWovenLiveField(true);
  holonomyWovenTests = runHolonomyWovenFieldTests();
  println("HOLONOMY LOOM FIELD TESTS " + holonomyWovenTests.status());
}

void cycleHolonomyWovenMode() {
  if (holonomyWovenMode == HolonomyWovenMode.OFF)
    holonomyWovenMode = HolonomyWovenMode.SURFACE_SKIN;
  else if (holonomyWovenMode == HolonomyWovenMode.SURFACE_SKIN)
    holonomyWovenMode = HolonomyWovenMode.VOLUME_WEAVE;
  else if (holonomyWovenMode == HolonomyWovenMode.VOLUME_WEAVE)
    holonomyWovenMode = HolonomyWovenMode.GRADIENT_RELIEF;
  else holonomyWovenMode = HolonomyWovenMode.OFF;
  releaseHolonomyWovenFieldCapture("mode changed");
  rebuildHolonomyWovenLiveField(true);
  markCurrentFoundryStale("Holonomy Loom field mode changed; regenerate");
}

void toggleHolonomyWovenFieldCapture() {
  if (holonomyWovenFieldLocked) {
    releaseHolonomyWovenFieldCapture("operator released capture");
    markCurrentFoundryStale("Holonomy Loom field released; recapture and regenerate");
  } else {
    captureHolonomyWovenFieldForFoundry();
    markCurrentFoundryStale("Holonomy Loom field captured; regenerate");
  }
}

void releaseHolonomyWovenFieldCapture(String reason) {
  holonomyWovenFieldLocked = false;
  holonomyWovenCapturedField = null;
  holonomyWovenFoundryField = null;
  holonomyWovenLiveSignature = "";
}

HolonomyFieldArtifact captureHolonomyWovenFieldForFoundry() {
  if (holonomyWovenFieldLocked && holonomyWovenCapturedField != null) {
    holonomyWovenFoundryField = holonomyWovenCapturedField;
    return holonomyWovenFoundryField;
  }
  rebuildHolonomyWovenLiveField(true);
  holonomyWovenCapturedField = holonomyWovenLiveField;
  holonomyWovenFoundryField = holonomyWovenCapturedField;
  holonomyWovenFieldLocked = true;
  return holonomyWovenFoundryField;
}

HolonomyFieldArtifact holonomyWovenDisplayField() {
  if (holonomyWovenFieldLocked && holonomyWovenCapturedField != null)
    return holonomyWovenCapturedField;
  rebuildHolonomyWovenLiveField(false);
  return holonomyWovenLiveField;
}

HolonomyFieldArtifact holonomyWovenFieldForFoundry() {
  if (holonomyWovenFoundryField != null) return holonomyWovenFoundryField;
  if (holonomyWovenLiveField == null) rebuildHolonomyWovenLiveField(true);
  return holonomyWovenLiveField;
}

boolean holonomyWovenRequested() {
  return holonomyWovenMode != HolonomyWovenMode.OFF;
}

boolean holonomyWovenApplied() {
  HolonomyFieldArtifact artifact = holonomyWovenFoundryField;
  HolonomyWovenMode mode = artifact == null ? holonomyWovenMode : artifact.mode;
  return mode != HolonomyWovenMode.OFF && !dcrteMonotileModeActive();
}

String holonomyWovenStatusLabel() {
  HolonomyFieldArtifact artifact = holonomyWovenFieldLocked
    ? holonomyWovenCapturedField : holonomyWovenLiveField;
  HolonomyWovenMode mode = artifact == null ? holonomyWovenMode : artifact.mode;
  String capture = holonomyWovenFieldLocked ? " / CAPTURED" : " / LIVE";
  if (mode == HolonomyWovenMode.OFF) return "OFF" + capture;
  if (dcrteMonotileModeActive()) return mode.label() + " / SUPPRESSED" + capture;
  return mode.label() + capture;
}

String holonomyWovenShortArtifactId() {
  HolonomyFieldArtifact artifact = holonomyWovenFieldLocked
    ? holonomyWovenCapturedField : holonomyWovenLiveField;
  if (artifact == null || artifact.artifactId == null) return "unbuilt";
  return artifact.artifactId.substring(0, min(12, artifact.artifactId.length()));
}

float holonomyWovenFract(float value) {
  return value - floor(value);
}

float holonomyWovenSmoothstep(float edge0, float edge1, float value) {
  if (abs(edge1 - edge0) < 0.000001f) return value < edge0 ? 0 : 1;
  float t = constrain((value - edge0) / (edge1 - edge0), 0, 1);
  return t * t * (3.0f - 2.0f * t);
}

float holonomyWovenOrientedCoordinate(float raw, boolean reversed) {
  float u = holonomyWovenFract(raw);
  return reversed ? holonomyWovenFract(1.0f - u) : u;
}

float holonomyWovenAngularCoordinate(float primary, float secondary) {
  float angle = atan2(secondary, primary) / TWO_PI;
  return holonomyWovenFract(angle + 1.0f);
}

float holonomyWovenLoopAlpha(float u) {
  u = holonomyWovenFract(u);
  float a0 = constrain(alpha - holonomyWovenAlphaSpan, 1.0f, ALPHA_MAX);
  float a1 = constrain(alpha + holonomyWovenAlphaSpan, 1.0f, ALPHA_MAX);
  if (u < 0.25f) return lerp(a0, a1, u * 4.0f);
  if (u < 0.50f) return a1;
  if (u < 0.75f) return lerp(a1, a0, (u - 0.50f) * 4.0f);
  return a0;
}

float holonomyWovenLoopDepth(float u) {
  u = holonomyWovenFract(u);
  float d0 = constrain(depth - holonomyWovenDepthSpan, 0, DEPTH_MAX);
  float d1 = constrain(depth + holonomyWovenDepthSpan, 0, DEPTH_MAX);
  if (u < 0.25f) return d0;
  if (u < 0.50f) return lerp(d0, d1, (u - 0.25f) * 4.0f);
  if (u < 0.75f) return d1;
  return lerp(d1, d0, (u - 0.75f) * 4.0f);
}

float holonomyWovenAtlasDepth(float u, float v) {
  float transverse = sin(TWO_PI * v + braneTwist * PI)
    * (0.24f + 0.42f * holonomyWovenBoundaryCoupling);
  float crossing = sin(TWO_PI * (u * 2.0f - v * 0.5f) + quasiEnergy * PI) * 0.18f;
  return constrain(holonomyWovenLoopDepth(u) + transverse + crossing, 0, DEPTH_MAX);
}

int holonomyWovenCellLevel(float continuousDepth) {
  return constrain(round(map(continuousDepth, 0, DEPTH_MAX, 0, HOLONOMY_FIELD_MAX_LEVEL)),
    0, HOLONOMY_FIELD_MAX_LEVEL);
}

int holonomyWovenCellSpanForLevel(int level) {
  return 1 << constrain(HOLONOMY_FIELD_MAX_LEVEL - level, 0, HOLONOMY_FIELD_MAX_LEVEL);
}

float holonomyWovenAccumulatedPhase(float u, float v, float gammaValue, boolean reversed) {
  float orientedGamma = reversed ? -gammaValue : gammaValue;
  float connection = sin(TWO_PI * u) * (0.32f + 0.18f * cos(TWO_PI * v + braneTwist * PI));
  connection += sin(TWO_PI * u * 2.0f) * (0.08f + floquetCoupling * 0.11f) * sin(TWO_PI * v);
  return orientedGamma * u + connection;
}

float holonomyWovenAtlasScalar(float u, float v, int localDepth, float localAlpha,
  float phaseValue) {
  float sum = 0;
  float weightSum = 0;
  for (int level = 0; level <= localDepth; level++) {
    float scale = pow(2.0f, min(6.0f, level * 0.74f));
    float weight = localAlpha <= 1.001f ? 1.0f
      : pow(localAlpha, -level * recursionFalloff());
    float phase = phaseValue * (1.0f + level * 0.07f) + floquetCoupling * level * 0.68f;
    float lattice = sin(TWO_PI * u * scale + phase)
                  * cos(TWO_PI * v * scale * 0.82f - phase * 0.61f);
    float braid = cos(TWO_PI * (u + v) * (1.0f + scale * 0.23f) + phase * 0.43f)
                * sin(TWO_PI * (v - u) * (1.0f + scale * 0.17f) - phase * 0.29f);
    float node = cos(TWO_PI * u * (2.0f + level) + braneTwist * PI)
               * sin(TWO_PI * v * (1.0f + level * 0.5f) - quasiEnergy * PI);
    sum += weight * (lattice * 0.50f + braid * 0.32f + node * 0.18f);
    weightSum += weight;
  }
  return weightSum <= 0.000001f ? 0 : constrain(sum / weightSum, -1, 1);
}

String holonomyWovenArtifactSignature(float gammaValue, boolean reversed,
  HolonomyWovenMode modeValue) {
  StringBuilder out = new StringBuilder();
  dcrteCanonical(out, "schema", HOLONOMY_FIELD_SCHEMA);
  dcrteCanonical(out, "cols", HOLONOMY_FIELD_COLS);
  dcrteCanonical(out, "rows", HOLONOMY_FIELD_ROWS);
  dcrteCanonical(out, "mode", modeValue.id());
  dcrteCanonical(out, "reverse", reversed);
  dcrteCanonical(out, "gamma", gammaValue);
  dcrteCanonical(out, "alpha", alpha);
  dcrteCanonical(out, "depth", depth);
  dcrteCanonical(out, "alpha_span", holonomyWovenAlphaSpan);
  dcrteCanonical(out, "depth_span", holonomyWovenDepthSpan);
  dcrteCanonical(out, "boundary_coupling", holonomyWovenBoundaryCoupling);
  dcrteCanonical(out, "amplitude", holonomyWovenAmplitude);
  dcrteCanonical(out, "floquet", floquetCoupling);
  dcrteCanonical(out, "quasi_energy", quasiEnergy);
  dcrteCanonical(out, "brane_twist", braneTwist);
  dcrteCanonical(out, "deep_detail", deepDetail);
  dcrteCanonical(out, "falloff", recursionFalloff());
  return out.toString();
}

HolonomyFieldArtifact buildHolonomyWovenFieldArtifact(float gammaValue,
  boolean reversed, HolonomyWovenMode modeValue) {
  HolonomyFieldArtifact artifact = new HolonomyFieldArtifact(HOLONOMY_FIELD_COLS, HOLONOMY_FIELD_ROWS);
  artifact.mode = modeValue;
  artifact.reversed = reversed;
  artifact.gammaSnapshot = gammaValue;
  float a0 = constrain(alpha - holonomyWovenAlphaSpan, 1.0f, ALPHA_MAX);
  float a1 = constrain(alpha + holonomyWovenAlphaSpan, 1.0f, ALPHA_MAX);
  float d0 = constrain(depth - holonomyWovenDepthSpan, 0, DEPTH_MAX);
  float d1 = constrain(depth + holonomyWovenDepthSpan, 0, DEPTH_MAX);
  artifact.loopArea = (a1 - a0) * (d1 - d0) * (reversed ? -1.0f : 1.0f);
  artifact.phaseStart = holonomyWovenAccumulatedPhase(0, 0.5f, gammaValue, reversed);
  artifact.phaseEnd = holonomyWovenAccumulatedPhase(1, 0.5f, gammaValue, reversed);
  artifact.accumulatedPhase = artifact.phaseEnd - artifact.phaseStart;
  artifact.closureError = abs(artifact.accumulatedPhase - (reversed ? -gammaValue : gammaValue));

  for (int r = 0; r < artifact.rows; r++) {
    float v = (r + 0.5f) / artifact.rows;
    for (int c = 0; c < artifact.cols; c++) {
      float u = (c + 0.5f) / artifact.cols;
      float continuousDepth = holonomyWovenAtlasDepth(u, v);
      int recursionLevel = constrain(round(continuousDepth), 0, DEPTH_MAX);
      int cellLevel = holonomyWovenCellLevel(continuousDepth);
      int span = holonomyWovenCellSpanForLevel(cellLevel);
      int originC = (c / span) * span;
      int originR = (r / span) * span;
      float cellU = holonomyWovenFract((originC + span * 0.5f) / artifact.cols);
      float cellV = constrain((originR + span * 0.5f) / artifact.rows, 0, 0.999999f);
      float cellDepth = holonomyWovenAtlasDepth(cellU, cellV);
      int cellRecursion = constrain(round(cellDepth), 0, DEPTH_MAX);
      float cellAlpha = holonomyWovenLoopAlpha(cellU);
      float cellPhase = holonomyWovenAccumulatedPhase(cellU, cellV, gammaValue, reversed);
      artifact.value[r][c] = holonomyWovenAtlasScalar(cellU, cellV, cellRecursion, cellAlpha, cellPhase);
      artifact.phase[r][c] = cellPhase;
      artifact.continuousDepth[r][c] = cellDepth;
      artifact.localAlpha[r][c] = cellAlpha;
      artifact.recursionLevel[r][c] = cellRecursion;
      artifact.cellSpan[r][c] = span;
      artifact.minimumDepth = min(artifact.minimumDepth, cellDepth);
      artifact.maximumDepth = max(artifact.maximumDepth, cellDepth);
      artifact.minimumCellSpan = min(artifact.minimumCellSpan, span);
      artifact.maximumCellSpan = max(artifact.maximumCellSpan, span);
    }
  }

  for (int r = 0; r < artifact.rows; r++) {
    for (int c = 0; c < artifact.cols; c++) {
      int left = (c - 1 + artifact.cols) % artifact.cols;
      int right = (c + 1) % artifact.cols;
      int up = max(0, r - 1);
      int down = min(artifact.rows - 1, r + 1);
      float valueDx = artifact.value[r][right] - artifact.value[r][left];
      float valueDy = artifact.value[down][c] - artifact.value[up][c];
      float depthDx = artifact.continuousDepth[r][right] - artifact.continuousDepth[r][left];
      float depthDy = artifact.continuousDepth[down][c] - artifact.continuousDepth[up][c];
      boolean scaleBoundary = artifact.cellSpan[r][c] != artifact.cellSpan[r][left]
        || artifact.cellSpan[r][c] != artifact.cellSpan[r][right]
        || artifact.cellSpan[r][c] != artifact.cellSpan[up][c]
        || artifact.cellSpan[r][c] != artifact.cellSpan[down][c];
      float differential = sqrt(valueDx * valueDx + valueDy * valueDy) * 0.42f
        + sqrt(depthDx * depthDx + depthDy * depthDy) * 0.18f;
      artifact.gradient[r][c] = constrain(differential + (scaleBoundary ? 0.68f : 0), 0, 1);
    }
  }

  StringBuilder canonical = new StringBuilder(holonomyWovenArtifactSignature(gammaValue, reversed, modeValue));
  for (int r = 0; r < artifact.rows; r++) {
    for (int c = 0; c < artifact.cols; c++) {
      canonical.append(Float.floatToIntBits(artifact.value[r][c])).append(',');
      canonical.append(Float.floatToIntBits(artifact.phase[r][c])).append(',');
      canonical.append(artifact.recursionLevel[r][c]).append(',');
      canonical.append(artifact.cellSpan[r][c]).append(';');
    }
  }
  artifact.artifactId = dcrteSha256(canonical.toString());
  holonomyWovenBuildPreviewImage(artifact);
  return artifact;
}

void rebuildHolonomyWovenLiveField(boolean force) {
  if (holonomyWovenFieldLocked && !force) return;
  String signature = holonomyWovenArtifactSignature(holoGamma, reverseHolonomy, holonomyWovenMode);
  boolean changed = holonomyWovenLiveField == null || !signature.equals(holonomyWovenLiveSignature);
  if (!force && (!changed || frameCount - holonomyWovenLastLiveBuildFrame < 8)) return;
  holonomyWovenLiveField = buildHolonomyWovenFieldArtifact(holoGamma, reverseHolonomy, holonomyWovenMode);
  holonomyWovenLiveSignature = signature;
  holonomyWovenLastLiveBuildFrame = frameCount;
}

void holonomyWovenMapDomainCoordinates(float x, float y, float z, boolean reversed) {
  float angular;
  float axial;
  float radial;

  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
      && dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL) {
    angular = holonomyWovenAngularCoordinate(y, z);
    axial = constrain(0.5f + 0.5f * x / max(0.0001f, dcrteIntrinsicLongitudinalScale), 0, 1);
    radial = constrain(sqrt(y*y + z*z) / max(0.0001f, dcrteIntrinsicRadialScale), 0, 1);
  } else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE
      && dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.CYLINDER) {
    angular = holonomyWovenAngularCoordinate(x - dcrteDomainCenterX, z - dcrteDomainCenterZ);
    axial = constrain(0.5f + 0.5f * (y - dcrteDomainCenterY) / max(0.0001f, dcrteCylinderHalfHeight), 0, 1);
    radial = constrain(sqrt(sq(x - dcrteDomainCenterX) + sq(z - dcrteDomainCenterZ))
      / max(0.0001f, dcrteCylinderRadius), 0, 1);
  } else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE
      && dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.PANEL) {
    float nx;
    float ny;
    float nz;
    if (dcrtePanelLayoutMode == DCRTEPanelLayoutMode.SPHEROID_CELLS) {
      // Cell-array field samples arrive in cell-local spheroid coordinates.
      nx = x;
      ny = y;
      nz = z;
    } else {
      float scaleMM = dcrtePanelMaxDimensionMM();
      nx = x / max(0.0001f, dcrtePanelWidthMM / scaleMM);
      ny = y / max(0.0001f, dcrtePanelHeightMM / scaleMM);
      nz = z / max(0.0001f, dcrtePanelDepthMM / scaleMM);
    }
    float ax = abs(nx), ay = abs(ny), az = abs(nz);
    if (dcrtePanelLayoutMode == DCRTEPanelLayoutMode.SPHEROID_CELLS) {
      angular = holonomyWovenAngularCoordinate(nx, nz);
      float radius = max(0.000001f, sqrt(nx*nx + ny*ny + nz*nz));
      axial = constrain(0.5f + 0.5f * ny / radius, 0, 1);
      radial = constrain(radius, 0, 1);
    } else {
      if (ax >= ay && ax >= az) angular = holonomyWovenAngularCoordinate(ny, nz);
      else if (ay >= az) angular = holonomyWovenAngularCoordinate(nx, nz);
      else angular = holonomyWovenAngularCoordinate(nx, ny);
      axial = constrain(0.5f + 0.1666667f * (nx + ny + nz), 0, 1);
      radial = constrain(max(ax, max(ay, az)), 0, 1);
    }
  } else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE
      && dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.BOX) {
    float nx = (x - dcrteDomainCenterX) / max(0.0001f, dcrteBoxHalfX);
    float ny = (y - dcrteDomainCenterY) / max(0.0001f, dcrteBoxHalfY);
    float nz = (z - dcrteDomainCenterZ) / max(0.0001f, dcrteBoxHalfZ);
    float ax = abs(nx), ay = abs(ny), az = abs(nz);
    if (ax >= ay && ax >= az) angular = holonomyWovenAngularCoordinate(ny, nz);
    else if (ay >= az) angular = holonomyWovenAngularCoordinate(nx, nz);
    else angular = holonomyWovenAngularCoordinate(nx, ny);
    axial = constrain(0.5f + 0.1666667f * (nx + ny + nz), 0, 1);
    radial = constrain(max(ax, max(ay, az)), 0, 1);
  } else {
    angular = holonomyWovenAngularCoordinate(x, z);
    float radius = max(0.000001f, sqrt(x*x + y*y + z*z));
    axial = constrain(0.5f + 0.5f * y / radius, 0, 1);
    radial = constrain(radius / 1.23f, 0, 1);
  }

  float fold = holonomyWovenBoundaryCoupling
    * (0.035f * sin((x * 5.7f + y * 3.9f - z * 4.6f) * PI)
      + 0.022f * sin((x * 2.3f - y * 6.1f + z * 3.4f) * PI));
  holonomyWovenMappedU = holonomyWovenOrientedCoordinate(angular + fold, reversed);
  holonomyWovenMappedV = constrain(axial * 0.72f + radial * 0.28f
    + 0.04f * sin(TWO_PI * angular + braneTwist * PI), 0, 0.999999f);
}

float holonomyWovenDomainDepth(float x, float y, float z) {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
      && dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL)
    return constrain(sqrt(y*y + z*z) / max(0.0001f, dcrteIntrinsicRadialScale), 0, 1.25f);
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) {
    if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.SPHERE) {
      float radius = sqrt(sq(x - dcrteDomainCenterX) + sq(y - dcrteDomainCenterY) + sq(z - dcrteDomainCenterZ));
      return constrain(radius / max(0.0001f, dcrteSphereRadius), 0, 1.25f);
    }
    if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.CYLINDER) {
      float side = sqrt(sq(x - dcrteDomainCenterX) + sq(z - dcrteDomainCenterZ)) / max(0.0001f, dcrteCylinderRadius);
      float cap = abs(y - dcrteDomainCenterY) / max(0.0001f, dcrteCylinderHalfHeight);
      return constrain(max(side, cap), 0, 1.25f);
    }
    if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.PANEL) {
      if (dcrtePanelLayoutMode == DCRTEPanelLayoutMode.SPHEROID_CELLS) {
        return constrain(sqrt(x*x + y*y + z*z), 0, 1.25f);
      }
      float scaleMM = dcrtePanelMaxDimensionMM();
      float px = abs(x) / max(0.0001f, dcrtePanelWidthMM / scaleMM);
      float py = abs(y) / max(0.0001f, dcrtePanelHeightMM / scaleMM);
      float pz = abs(z) / max(0.0001f, dcrtePanelDepthMM / scaleMM);
      return constrain(max(px, max(py, pz)), 0, 1.25f);
    }
    float bx = abs(x - dcrteDomainCenterX) / max(0.0001f, dcrteBoxHalfX);
    float by = abs(y - dcrteDomainCenterY) / max(0.0001f, dcrteBoxHalfY);
    float bz = abs(z - dcrteDomainCenterZ) / max(0.0001f, dcrteBoxHalfZ);
    return constrain(max(bx, max(by, bz)), 0, 1.25f);
  }
  return constrain(sqrt(x*x + y*y + z*z) / 1.23f, 0, 1.25f);
}

float holonomyWovenModifier(float x, float y, float z) {
  if (holonomyWovenFoundryField == null && holonomyWovenMode == HolonomyWovenMode.OFF) return 0;
  HolonomyFieldArtifact artifact = holonomyWovenFieldForFoundry();
  if (artifact == null || artifact.mode == HolonomyWovenMode.OFF || dcrteMonotileModeActive()) return 0;
  holonomyWovenMapDomainCoordinates(x, y, z, artifact.reversed);
  float local = artifact.sampleValue(holonomyWovenMappedU, holonomyWovenMappedV);
  float boundary = artifact.sampleGradient(holonomyWovenMappedU, holonomyWovenMappedV);
  float domainDepth = holonomyWovenDomainDepth(x, y, z);
  float skin = holonomyWovenSmoothstep(0.42f, 0.92f, domainDepth);

  if (artifact.mode == HolonomyWovenMode.SURFACE_SKIN)
    return holonomyWovenAmplitude * (local * (0.12f + 0.88f * skin) + boundary * 0.18f * skin);
  if (artifact.mode == HolonomyWovenMode.VOLUME_WEAVE)
    return holonomyWovenAmplitude * (local * 0.86f + (boundary - 0.28f) * 0.34f);
  if (artifact.mode == HolonomyWovenMode.GRADIENT_RELIEF)
    return holonomyWovenAmplitude * (local * 0.22f + (boundary - 0.20f) * (0.42f + 0.88f * skin));
  return 0;
}

color holonomyWovenPhaseColor(float phaseValue, float magnitude, float gradientValue) {
  float hue = holonomyWovenFract(phaseValue / TWO_PI + 0.5f);
  color[] palette = {
    color(48, 92, 190), color(52, 205, 220), color(92, 225, 142),
    color(250, 205, 76), color(244, 112, 88), color(178, 82, 225), color(48, 92, 190)
  };
  float scaled = hue * 6.0f;
  int index = constrain(floor(scaled), 0, 5);
  color phaseColor = lerpColor(palette[index], palette[index + 1], scaled - index);
  float energy = 0.34f + 0.66f * constrain(abs(magnitude), 0, 1);
  color shaded = lerpColor(color(7, 13, 22), phaseColor, energy);
  return lerpColor(shaded, color(255, 238, 150), constrain(gradientValue * 0.72f, 0, 0.72f));
}

color holonomyWovenCarrierColor(float x, float y, float z) {
  HolonomyFieldArtifact artifact = holonomyWovenFoundryField != null
    ? holonomyWovenFoundryField : holonomyWovenDisplayField();
  if (artifact == null) return color(95, 225, 210);
  holonomyWovenMapDomainCoordinates(x, y, z, artifact.reversed);
  return holonomyWovenPhaseColor(
    artifact.samplePhase(holonomyWovenMappedU, holonomyWovenMappedV),
    artifact.sampleValue(holonomyWovenMappedU, holonomyWovenMappedV),
    artifact.sampleGradient(holonomyWovenMappedU, holonomyWovenMappedV));
}

void holonomyWovenBuildPreviewImage(HolonomyFieldArtifact artifact) {
  if (artifact == null) return;
  int pixelScale = 3;
  PImage preview = createImage(artifact.cols * pixelScale, artifact.rows * pixelScale, RGB);
  preview.loadPixels();
  for (int pr = 0; pr < preview.height; pr++) {
    int r = constrain(pr / pixelScale, 0, artifact.rows - 1);
    for (int pc = 0; pc < preview.width; pc++) {
      int c = constrain(pc / pixelScale, 0, artifact.cols - 1);
      int span = artifact.cellSpan[r][c];
      boolean leftEdge = c == 0 || (c / span) != ((c - 1) / span)
        || span != artifact.cellSpan[r][max(0, c - 1)];
      boolean topEdge = r == 0 || (r / span) != ((r - 1) / span)
        || span != artifact.cellSpan[max(0, r - 1)][c];
      color sampleColor = holonomyWovenPhaseColor(
        artifact.phase[r][c], artifact.value[r][c], artifact.gradient[r][c]);
      if ((leftEdge && pc % pixelScale == 0) || (topEdge && pr % pixelScale == 0))
        sampleColor = lerpColor(sampleColor, color(3, 7, 12), span >= 8 ? 0.76f : 0.48f);
      if (artifact.gradient[r][c] > 0.72f
          && pc % pixelScale == pixelScale / 2 && pr % pixelScale == pixelScale / 2)
        sampleColor = lerpColor(sampleColor, color(255, 238, 150), 0.70f);
      preview.pixels[pr * preview.width + pc] = sampleColor;
    }
  }
  preview.updatePixels();
  artifact.previewImage = preview;
}

void drawHolonomyWovenAtlas(float x, float y, float w, float h,
  HolonomyFieldArtifact artifact, boolean labels) {
  if (artifact == null || w < 4 || h < 4) return;
  if (artifact.previewImage == null) holonomyWovenBuildPreviewImage(artifact);
  noStroke();
  image(artifact.previewImage, x, y, w, h);
  noFill();
  stroke(92, 160, 170);
  strokeWeight(1);
  rect(x, y, w, h);

  if (labels) drawHolonomyWovenLandmarks(x, y, w, h);
}

void drawHolonomyWovenLandmarks(float x, float y, float w, float h) {
  float[] us = {0.12f, 0.38f, 0.63f, 0.87f};
  float[] vs = {0.22f, 0.72f, 0.34f, 0.79f};
  String[] names = {"A", "B", "C", "D"};
  for (int i = 0; i < us.length; i++) {
    float px = x + us[i] * w;
    float py = y + vs[i] * h;
    stroke(255);
    strokeWeight(1.2f);
    fill(5, 10, 16, 210);
    ellipse(px, py, 14, 14);
    fill(255, 244, 176);
    textSize(8);
    textAlign(CENTER, CENTER);
    text(names[i], px, py - 0.5f);
  }
}

void appendHolonomyWovenMetadata(JSONObject target) {
  if (target == null) return;
  HolonomyFieldArtifact artifact = holonomyWovenFoundryField;
  if (artifact == null) artifact = holonomyWovenDisplayField();
  JSONObject woven = new JSONObject();
  woven.setString("source_lens", "HOLONOMY LOOM");
  woven.setString("artifact_schema", HOLONOMY_FIELD_SCHEMA);
  woven.setString("artifact_id", artifact == null ? "unbuilt" : artifact.artifactId);
  woven.setString("mode", artifact == null ? holonomyWovenMode.id() : artifact.mode.id());
  woven.setBoolean("requested", artifact != null && artifact.mode != HolonomyWovenMode.OFF);
  woven.setBoolean("applied", artifact != null && artifact.mode != HolonomyWovenMode.OFF && !dcrteMonotileModeActive());
  woven.setBoolean("captured_for_foundry", artifact != null && artifact == holonomyWovenFoundryField);
  woven.setString("observer", "adaptive_parameter_atlas_to_uniform_fabrication_grid");
  woven.setString("adaptive_cell_claim", "literal stepped cells exist in the Loom atlas; the final mesh observer samples that same piecewise field on its audited uniform grid");
  woven.setInt("atlas_columns", artifact == null ? 0 : artifact.cols);
  woven.setInt("atlas_rows", artifact == null ? 0 : artifact.rows);
  woven.setInt("minimum_cell_span", artifact == null ? 0 : artifact.minimumCellSpan);
  woven.setInt("maximum_cell_span", artifact == null ? 0 : artifact.maximumCellSpan);
  woven.setFloat("minimum_recursion_depth", artifact == null ? 0 : artifact.minimumDepth);
  woven.setFloat("maximum_recursion_depth", artifact == null ? 0 : artifact.maximumDepth);
  woven.setFloat("alpha_span", holonomyWovenAlphaSpan);
  woven.setFloat("depth_span", holonomyWovenDepthSpan);
  woven.setFloat("boundary_coupling", holonomyWovenBoundaryCoupling);
  woven.setFloat("amplitude", holonomyWovenAmplitude);
  woven.setString("orientation", artifact != null && artifact.reversed ? "reverse" : "forward");
  woven.setFloat("phase_start_rad", artifact == null ? 0 : artifact.phaseStart);
  woven.setFloat("phase_end_rad", artifact == null ? 0 : artifact.phaseEnd);
  woven.setFloat("accumulated_phase_rad", artifact == null ? 0 : artifact.accumulatedPhase);
  woven.setFloat("phase_closure_error", artifact == null ? 0 : artifact.closureError);
  woven.setFloat("loop_area", artifact == null ? 0 : artifact.loopArea);
  woven.setString("phase_source", "discrete_adiabatic_connection_integral_v2");
  woven.setString("domain_mapping", holonomyWovenDomainMappingLabel());
  JSONArray landmarks = new JSONArray();
  float[] us = {0.12f, 0.38f, 0.63f, 0.87f};
  float[] vs = {0.22f, 0.72f, 0.34f, 0.79f};
  for (int i = 0; i < us.length; i++) {
    JSONObject landmark = new JSONObject();
    landmark.setString("label", str((char)('A' + i)));
    landmark.setFloat("u", us[i]);
    landmark.setFloat("v", vs[i]);
    if (artifact != null) {
      landmark.setInt("recursion_depth", artifact.sampleLevel(us[i], vs[i]));
      landmark.setInt("cell_span", artifact.sampleCellSpan(us[i], vs[i]));
      landmark.setFloat("phase_rad", artifact.samplePhase(us[i], vs[i]));
      landmark.setFloat("gradient", artifact.sampleGradient(us[i], vs[i]));
    }
    landmarks.setJSONObject(i, landmark);
  }
  woven.setJSONArray("landmarks", landmarks);
  target.setJSONObject("holonomy_woven_field", woven);
}

String holonomyWovenDomainMappingLabel() {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
      && dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL)
    return "intrinsic_axial_parallel_transport_uv";
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE)
    return dcrtePrimitiveDomainType.id() + "_periodic_domain_uv";
  return "periodic_spherical_cartesian_uv";
}

DCRTEM1TestReport runHolonomyWovenFieldTests() {
  DCRTEM1TestReport tests = new DCRTEM1TestReport();
  try {
    float a0 = holonomyWovenLoopAlpha(0);
    float a1 = holonomyWovenLoopAlpha(1);
    float d0 = holonomyWovenLoopDepth(0);
    float d1 = holonomyWovenLoopDepth(1);
    tests.check(abs(a0 - a1) <= 0.000001f && abs(d0 - d1) <= 0.000001f,
      "adiabatic parameter loop closes exactly");

    HolonomyFieldArtifact forward = buildHolonomyWovenFieldArtifact(0.73f, false,
      HolonomyWovenMode.VOLUME_WEAVE);
    HolonomyFieldArtifact repeated = buildHolonomyWovenFieldArtifact(0.73f, false,
      HolonomyWovenMode.VOLUME_WEAVE);
    HolonomyFieldArtifact reverse = buildHolonomyWovenFieldArtifact(0.73f, true,
      HolonomyWovenMode.VOLUME_WEAVE);
    tests.check(forward.artifactId.equals(repeated.artifactId),
      "identical Loom state produces identical field artifact identity");
    tests.check(!forward.artifactId.equals(reverse.artifactId),
      "orientation is part of field artifact identity");
    tests.check(forward.closureError < 0.00001f && reverse.closureError < 0.00001f,
      "phase accumulation closes to the measured holonomy");
    tests.check(abs(forward.accumulatedPhase + reverse.accumulatedPhase) < 0.00001f,
      "reverse traversal flips accumulated phase");
    tests.check(abs(forward.loopArea + reverse.loopArea) < 0.00001f,
      "reverse traversal flips loop area");
    tests.check(forward.maximumDepth - forward.minimumDepth > holonomyWovenDepthSpan * 1.6f,
      "atlas spans distinct low and high recursion");
    tests.check(forward.minimumCellSpan < forward.maximumCellSpan,
      "atlas contains visibly different adaptive cell scales");

    boolean finite = true;
    float peakGradient = 0;
    for (int r = 0; r < forward.rows; r++) {
      for (int c = 0; c < forward.cols; c++) {
        finite = finite && dcrteFinite(forward.value[r][c])
          && dcrteFinite(forward.phase[r][c]) && dcrteFinite(forward.gradient[r][c]);
        peakGradient = max(peakGradient, forward.gradient[r][c]);
      }
    }
    tests.check(finite, "field artifact samples are finite");
    tests.check(peakGradient > 0.70f,
      "differential-gradient channel marks adaptive scale boundaries");

    HolonomyFieldArtifact savedFoundryField = holonomyWovenFoundryField;
    int savedGeometryIndex = foundryGeometryIndex;
    holonomyWovenFoundryField = forward;
    foundryGeometryIndex = 0;
    float transported = holonomyWovenModifier(0.61f, -0.27f, 0.43f);
    holonomyWovenMapDomainCoordinates(0.61f, -0.27f, 0.43f, forward.reversed);
    float expected = holonomyWovenAmplitude * (
      forward.sampleValue(holonomyWovenMappedU, holonomyWovenMappedV) * 0.86f
      + (forward.sampleGradient(holonomyWovenMappedU, holonomyWovenMappedV) - 0.28f) * 0.34f);
    tests.check(abs(transported - expected) < 0.000001f,
      "Foundry transport samples the captured Loom artifact without resynthesis");
    HolonomyFieldArtifact offArtifact = buildHolonomyWovenFieldArtifact(0.73f, false,
      HolonomyWovenMode.OFF);
    float[] transportScores = currentTopologyScores();
    foundryGeometryIndex = 13;
    holonomyWovenFoundryField = offArtifact;
    float carriedOff = foundryScalar(0.61f, -0.27f, 0.43f, transportScores);
    holonomyWovenFoundryField = forward;
    float carriedOn = foundryScalar(0.61f, -0.27f, 0.43f, transportScores);
    tests.check(abs((carriedOn - carriedOff) - transported) < 0.00001f,
      "carrier wrapping preserves the captured Loom field contribution");
    holonomyWovenFoundryField = savedFoundryField;
    foundryGeometryIndex = savedGeometryIndex;

    float seamA = holonomyWovenOrientedCoordinate(0.000001f, false);
    float seamB = holonomyWovenOrientedCoordinate(0.999999f, false);
    tests.check(min(abs(seamA - seamB), 1.0f - abs(seamA - seamB)) < 0.00001f,
      "transport coordinate is periodic across the atlas seam");
  }
  catch (Exception error) {
    tests.check(false, "Loom field test exception: " + error.getClass().getSimpleName()
      + " " + error.getMessage());
  }
  return tests;
}
