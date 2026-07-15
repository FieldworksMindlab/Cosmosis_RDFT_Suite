/* DCRTE-ET Milestone 3 coordinate boundary between observer and field engine. */

enum DCRTECoordinateMode {
  CARTESIAN,
  INTRINSIC_AXIAL;

  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum IntrinsicFallbackPolicy {
  BLOCK,
  CARTESIAN_LOCAL_FALLBACK,
  CLAMP_TO_VALID_INTRINSIC;

  String id() { return name().toLowerCase(); }
}

enum CoordinateComparisonMode {
  SINGLE,
  CARTESIAN_AND_INTRINSIC;

  String id() { return name().toLowerCase(); }
}

enum IntrinsicVisualizationMode {
  CENTERLINE,
  CENTERLINE_FRAMES,
  AXIAL_SLICES,
  INTRINSIC_S,
  INTRINSIC_R,
  INTRINSIC_RHO,
  INTRINSIC_THETA,
  INTRINSIC_CONFIDENCE,
  AMBIGUITY,
  FALLBACK,
  CARTESIAN_RESULT,
  INTRINSIC_RESULT;

  String label() { return name().replace('_', ' '); }
}

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
  int centerlineIndex = -1;
  boolean valid;
  boolean fallbackUsed;

  FieldCoordinateSample setCartesian(float x, float y, float z) {
    fieldX = x; fieldY = y; fieldZ = z;
    s = Float.NaN; radialDistance = Float.NaN; normalizedRadius = Float.NaN;
    theta = Float.NaN; signedBoundaryDistance = Float.NaN;
    confidence = 1; centerlineIndex = -1; valid = true; fallbackUsed = false;
    return this;
  }

  FieldCoordinateSample invalidate() {
    fieldX = fieldY = fieldZ = Float.NaN;
    s = radialDistance = normalizedRadius = theta = signedBoundaryDistance = Float.NaN;
    confidence = 0; centerlineIndex = -1; valid = false; fallbackUsed = false;
    return this;
  }
}

interface FieldCoordinateSystem {
  FieldCoordinateSample mapAtIndex(int x, int y, int z, float worldX, float worldY, float worldZ);
  String getId();
  String getVersion();
  boolean isValid();
  String validationMessage();
  JSONObject toJSON();
}

class CartesianCoordinateSystem implements FieldCoordinateSystem {
  final FieldCoordinateSample sample = new FieldCoordinateSample();

  public FieldCoordinateSample mapAtIndex(int x, int y, int z, float worldX, float worldY, float worldZ) {
    return sample.setCartesian(worldX, worldY, worldZ);
  }
  public String getId() { return "cartesian"; }
  public String getVersion() { return "1.0-m3"; }
  public boolean isValid() { return true; }
  public String validationMessage() { return "identity world-to-field mapping"; }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setString("mapping", "observer_world_identity");
    json.setBoolean("valid", true);
    return json;
  }
}

class IntrinsicAxialCoordinateSystem implements FieldCoordinateSystem {
  IntrinsicCoordinateVolume volume;
  IntrinsicValidationReport validation;
  float longitudinalScale;
  float radialScale;
  IntrinsicFallbackPolicy fallbackPolicy;
  final FieldCoordinateSample sample = new FieldCoordinateSample();

  IntrinsicAxialCoordinateSystem(IntrinsicCoordinateVolume volume,
      IntrinsicValidationReport validation, float longitudinalScale, float radialScale,
      IntrinsicFallbackPolicy fallbackPolicy) {
    this.volume = volume;
    this.validation = validation;
    this.longitudinalScale = longitudinalScale;
    this.radialScale = radialScale;
    this.fallbackPolicy = fallbackPolicy == null ? IntrinsicFallbackPolicy.BLOCK : fallbackPolicy;
  }

  public FieldCoordinateSample mapAtIndex(int x, int y, int z, float worldX, float worldY, float worldZ) {
    sample.invalidate();
    if (volume == null || volume.spec == null || x < 0 || y < 0 || z < 0
        || x >= volume.spec.nx || y >= volume.spec.ny || z >= volume.spec.nz) return sample;
    int idx = volume.index(x, y, z);
    if (!volume.valid[idx]) {
      if (fallbackPolicy == IntrinsicFallbackPolicy.CARTESIAN_LOCAL_FALLBACK) {
        sample.setCartesian(worldX, worldY, worldZ);
        sample.confidence = 0;
        sample.fallbackUsed = true;
      } else if (fallbackPolicy == IntrinsicFallbackPolicy.CLAMP_TO_VALID_INTRINSIC) {
        int clamped = nearestValidIndex(x, y, z, 4);
        if (clamped >= 0) setIntrinsicSample(clamped, true, 0.25f);
      }
      return sample;
    }
    setIntrinsicSample(idx, volume.fallbackUsed[idx], volume.confidence[idx]);
    return sample;
  }

  void setIntrinsicSample(int idx, boolean fallbackUsed, float confidence) {
    float s = volume.s[idx];
    float rho = volume.normalizedRadius[idx];
    float theta = volume.theta[idx];
    float fx = longitudinalScale * (2.0f * s - 1.0f);
    float fy = radialScale * rho * cos(theta);
    float fz = radialScale * rho * sin(theta);
    if (!dcrteFinite(fx) || !dcrteFinite(fy) || !dcrteFinite(fz)) return;
    sample.fieldX = fx; sample.fieldY = fy; sample.fieldZ = fz;
    sample.s = s;
    sample.radialDistance = volume.radialDistance[idx];
    sample.normalizedRadius = rho;
    sample.theta = theta;
    sample.signedBoundaryDistance = volume.signedBoundaryDistance[idx];
    sample.confidence = confidence;
    sample.centerlineIndex = volume.centerlineIndex[idx];
    sample.valid = true;
    sample.fallbackUsed = fallbackUsed;
  }

  int nearestValidIndex(int x, int y, int z, int maximumRadius) {
    for (int radius = 1; radius <= maximumRadius; radius++) {
      int x0 = max(0, x - radius), x1 = min(volume.spec.nx - 1, x + radius);
      int y0 = max(0, y - radius), y1 = min(volume.spec.ny - 1, y + radius);
      int z0 = max(0, z - radius), z1 = min(volume.spec.nz - 1, z + radius);
      for (int zz = z0; zz <= z1; zz++) for (int yy = y0; yy <= y1; yy++) for (int xx = x0; xx <= x1; xx++) {
        if (xx != x0 && xx != x1 && yy != y0 && yy != y1 && zz != z0 && zz != z1) continue;
        int candidate = volume.index(xx, yy, zz);
        if (volume.valid[candidate]) return candidate;
      }
    }
    return -1;
  }

  public String getId() { return "intrinsic_axial"; }
  public String getVersion() { return "1.0-m3"; }
  public boolean isValid() {
    return volume != null && volume.isValid() && validation != null && validation.exportAllowed();
  }
  public String validationMessage() {
    if (validation == null) return "intrinsic coordinates not built";
    if (validation.errors.size() > 0) return validation.errors.get(0);
    return validation.status.id();
  }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setString("mapping", "INTRINSIC_CYLINDRICAL_EMBEDDING");
    json.setFloat("longitudinal_scale", longitudinalScale);
    json.setFloat("radial_scale", radialScale);
    json.setString("fallback_policy", fallbackPolicy.id());
    json.setBoolean("valid", isValid());
    if (validation != null) json.setJSONObject("validation", validation.toJSON());
    return json;
  }
}

DCRTECoordinateMode dcrteCoordinateMode = DCRTECoordinateMode.CARTESIAN;
IntrinsicFallbackPolicy dcrteIntrinsicFallbackPolicy = IntrinsicFallbackPolicy.BLOCK;
CoordinateComparisonMode dcrteCoordinateComparisonMode = CoordinateComparisonMode.SINGLE;
IntrinsicVisualizationMode dcrteIntrinsicVisualizationMode = IntrinsicVisualizationMode.CENTERLINE;
float dcrteIntrinsicLongitudinalScale = 1.0f;
float dcrteIntrinsicRadialScale = 1.0f;
boolean dcrteIntrinsicShowCenterline = true;
boolean dcrteIntrinsicShowFrames = false;
boolean dcrteIntrinsicShowConfidence = false;
int dcrteIntrinsicFrameStride = 6;
String dcrteIntrinsicBuildStatus = "NOT BUILT";
long dcrteIntrinsicLastBuildMillis = 0;
CartesianCoordinateSystem dcrteCartesianCoordinateSystem = new CartesianCoordinateSystem();
IntrinsicAxialCoordinateSystem dcrteIntrinsicCoordinateSystem = null;
IntrinsicBuildResult dcrteIntrinsicBuildResult = null;
DCRTECoordinateComparisonReport dcrteCoordinateComparisonReport = null;

void initializeDcrteMilestone3() {
  dcrteCartesianCoordinateSystem = new CartesianCoordinateSystem();
  dcrteIntrinsicBuildStatus = "NOT BUILT";
  dcrteM3Tests = runDcrteMilestone3Tests();
  println("DCRTE-ET Milestone 3 deterministic tests: " + dcrteM3Tests.status());
  for (int i = 0; i < dcrteM3Tests.failures.size(); i++) println("  FAIL " + dcrteM3Tests.failures.get(i));
}

FieldCoordinateSystem dcrteSelectedCoordinateSystem() {
  if (dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL) return dcrteIntrinsicCoordinateSystem;
  return dcrteCartesianCoordinateSystem;
}

void cycleDcrteCoordinateMode() {
  dcrteCoordinateMode = dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN
    ? DCRTECoordinateMode.INTRINSIC_AXIAL : DCRTECoordinateMode.CARTESIAN;
  markDcrteImportedMaterialStale("coordinate mode changed; regenerate material");
}

void cycleDcrteIntrinsicFallbackPolicy() {
  if (dcrteIntrinsicFallbackPolicy == IntrinsicFallbackPolicy.BLOCK) {
    dcrteIntrinsicFallbackPolicy = IntrinsicFallbackPolicy.CARTESIAN_LOCAL_FALLBACK;
  } else if (dcrteIntrinsicFallbackPolicy == IntrinsicFallbackPolicy.CARTESIAN_LOCAL_FALLBACK) {
    dcrteIntrinsicFallbackPolicy = IntrinsicFallbackPolicy.CLAMP_TO_VALID_INTRINSIC;
  } else dcrteIntrinsicFallbackPolicy = IntrinsicFallbackPolicy.BLOCK;
  refreshDcrteIntrinsicCoordinateSystem();
  markDcrteImportedMaterialStale("intrinsic fallback policy changed; regenerate material");
}

void cycleDcrteCoordinateComparisonMode() {
  dcrteCoordinateComparisonMode = dcrteCoordinateComparisonMode == CoordinateComparisonMode.SINGLE
    ? CoordinateComparisonMode.CARTESIAN_AND_INTRINSIC : CoordinateComparisonMode.SINGLE;
  markDcrteImportedMaterialStale("coordinate comparison mode changed; regenerate material");
}

void cycleDcrteIntrinsicVisualizationMode() {
  IntrinsicVisualizationMode[] values = IntrinsicVisualizationMode.values();
  dcrteIntrinsicVisualizationMode = values[(dcrteIntrinsicVisualizationMode.ordinal() + 1) % values.length];
}

void adjustDcrteIntrinsicLongitudinalScale(float delta) {
  dcrteIntrinsicLongitudinalScale = constrain(dcrteIntrinsicLongitudinalScale + delta, 0.25f, 3.0f);
  refreshDcrteIntrinsicCoordinateSystem();
  markDcrteImportedMaterialStale("intrinsic longitudinal scale changed; regenerate material");
}

void adjustDcrteIntrinsicRadialScale(float delta) {
  dcrteIntrinsicRadialScale = constrain(dcrteIntrinsicRadialScale + delta, 0.25f, 3.0f);
  refreshDcrteIntrinsicCoordinateSystem();
  markDcrteImportedMaterialStale("intrinsic radial scale changed; regenerate material");
}

void refreshDcrteIntrinsicCoordinateSystem() {
  if (dcrteIntrinsicBuildResult == null) {
    dcrteIntrinsicCoordinateSystem = null;
    return;
  }
  dcrteIntrinsicCoordinateSystem = new IntrinsicAxialCoordinateSystem(
    dcrteIntrinsicBuildResult.volume, dcrteIntrinsicBuildResult.validation,
    dcrteIntrinsicLongitudinalScale, dcrteIntrinsicRadialScale,
    dcrteIntrinsicFallbackPolicy);
}

void invalidateDcrteIntrinsic(String reason) {
  dcrteIntrinsicBuildResult = null;
  dcrteIntrinsicCoordinateSystem = null;
  dcrteCoordinateComparisonReport = null;
  dcrteIntrinsicBuildStatus = reason == null ? "STALE" : "STALE - " + reason;
}

void resetDcrteIntrinsic() {
  invalidateDcrteIntrinsic("reset");
  dcrteCoordinateMode = DCRTECoordinateMode.CARTESIAN;
  dcrteIntrinsicFallbackPolicy = IntrinsicFallbackPolicy.BLOCK;
  dcrteCoordinateComparisonMode = CoordinateComparisonMode.SINGLE;
  dcrteIntrinsicLongitudinalScale = 1.0f;
  dcrteIntrinsicRadialScale = 1.0f;
  markDcrteImportedMaterialStale("intrinsic coordinates reset; Cartesian active");
}

boolean buildDcrteImportedIntrinsicCoordinates() {
  if (dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) {
    dcrteIntrinsicBuildStatus = "BLOCKED - BUILD A VALID SDF";
    return false;
  }
  if (dcrteImportedPreflightReport == null || dcrteImportedPreflightReport.reportStale) {
    runDcrteImportedPreflightWithDerived(true, false);
  }
  if (dcrteImportedPreflightReport == null || !dcrteImportedPreflightReport.materializationEnabled) {
    dcrteIntrinsicBuildStatus = "BLOCKED - PREFLIGHT NOT QUALIFIED";
    return false;
  }
  dcrteIntrinsicBuildStatus = "BUILDING";
  long buildStart = millis();
  IntrinsicBuildResult result = new DCRTEIntrinsicCoordinateBuilder().build(
    dcrteImportedSdf, dcrteImportedPreflightReport, false);
  dcrteIntrinsicLastBuildMillis = millis() - buildStart;
  dcrteIntrinsicBuildResult = result;
  refreshDcrteIntrinsicCoordinateSystem();
  if (result == null || result.validation == null || !result.validation.exportAllowed()) {
    dcrteIntrinsicBuildStatus = "BLOCKED - " + (result == null || result.validation == null
      ? "BUILD FAILED" : result.validation.primaryIssue());
    return false;
  }
  dcrteIntrinsicBuildStatus = result.validation.status == ValidationStatus.PASS_WITH_WARNINGS
    ? "READY WITH WARNINGS" : "READY";
  dcrteImportedStale = true;
  dcrteImportedLastBuildConfiguration = null;
  markFoundryStale();
  foundryStatus = "intrinsic coordinates built; regenerate material";
  return true;
}

void exportDcrteIntrinsicReportJSON() {
  if (dcrteIntrinsicBuildResult == null || dcrteIntrinsicBuildResult.validation == null) return;
  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_"
    + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  String path = "logs/dcrte_intrinsic_reports/dcrte_intrinsic_" + stamp + ".json";
  saveJSONObject(dcrteIntrinsicBuildResult.toJSON(), path);
  dcrteImportedStatus = "intrinsic report exported: " + path;
}

JSONObject dcrteCoordinateMetadataJSON() {
  FieldCoordinateSystem system = dcrteSelectedCoordinateSystem();
  JSONObject json = system == null ? new JSONObject() : system.toJSON();
  json.setString("selected_mode", dcrteCoordinateMode.id());
  json.setString("comparison_mode", dcrteCoordinateComparisonMode.id());
  json.setString("radial_model", dcrteIntrinsicRadialModel.id());
  json.setString("build_status", dcrteIntrinsicBuildStatus);
  json.setLong("intrinsic_build_millis", dcrteIntrinsicLastBuildMillis);
  if (dcrteIntrinsicBuildResult != null) json.setJSONObject("intrinsic_build", dcrteIntrinsicBuildResult.toJSON());
  if (dcrteCoordinateComparisonReport != null) json.setJSONObject("comparison", dcrteCoordinateComparisonReport.toJSON());
  return json;
}
