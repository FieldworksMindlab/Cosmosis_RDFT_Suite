/* Printer-aware assembled-size presets for Geodesic Salon. */

final float GEODESIC_STANDARD_DIAMETER_MM = 304.8f;
final float GEODESIC_PRESET_MIN_RADIUS_MM = 24.0f;
final float GEODESIC_P1S_SAFE_PART_MM = 246.0f;

enum GeodesicSizePreset {
  MICRO("MICRO"),
  STANDARD("12 IN"),
  P1S_MAX("P1S MAX"),
  CUSTOM("CUSTOM");

  final String label;
  GeodesicSizePreset(String label) { this.label = label; }
}

class GeodesicSizeSolution {
  GeodesicSizePreset preset = GeodesicSizePreset.CUSTOM;
  boolean available = false;
  boolean bedFit = false;
  float requestedRadiusMM = 0;
  float effectiveRadiusMM = 0;
  float assembledDiameterMM = 0;
  float largestPartWidthMM = 0;
  float largestPartHeightMM = 0;
  float largestPartDepthMM = 0;
  String limitingPartId = "-";
  String status = "NOT CHECKED";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("preset", preset.label);
    json.setBoolean("available", available);
    json.setBoolean("bed_fit", bedFit);
    json.setFloat("requested_radius_mm", requestedRadiusMM);
    json.setFloat("effective_radius_mm", effectiveRadiusMM);
    json.setFloat("assembled_diameter_mm", assembledDiameterMM);
    json.setFloat("largest_part_width_mm", largestPartWidthMM);
    json.setFloat("largest_part_height_mm", largestPartHeightMM);
    json.setFloat("largest_part_depth_mm", largestPartDepthMM);
    json.setString("limiting_part_id", limitingPartId);
    json.setString("status", status);
    json.setFloat("printer_safe_envelope_mm", GEODESIC_P1S_SAFE_PART_MM);
    return json;
  }
}

GeodesicSizePreset geodesicSizePreset = GeodesicSizePreset.CUSTOM;
GeodesicSizeSolution geodesicSizeSolution = null;
String geodesicSizePresetNotice = "CUSTOM RADIUS";
boolean geodesicResolvingSizePreset = false;

GeodesicModel geodesicSizeCandidateModel(float radiusMM) {
  if (geodesicTopologyMode == GeodesicTopologyMode.APERIODIC)
    return buildGeodesicAperiodicModel(geodesicAperiodicFamily,
      geodesicExtent, geodesicAperiodicRecursion, radiusMM,
      geodesicCutRatio, geodesicAperiodicPhase);
  return buildGeodesicModel(geodesicFamily, geodesicExtent,
    geodesicFrequency, radiusMM, geodesicCutRatio,
    geodesicModifier, geodesicStellationRatio);
}

float geodesicAssembledDiameter(GeodesicModel model,
  GeodesicFabricationSettings fabrication) {
  if (model == null || model.vertices.size() == 0) return 0;
  float minX = Float.MAX_VALUE;
  float minY = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE;
  float maxY = -Float.MAX_VALUE;
  float scale = fabrication == null ? 1.0f :
    max(1.0f, fabrication.fabricationScale);
  for (GeodesicVertex vertex : model.vertices) {
    minX = min(minX, vertex.position.x * scale);
    maxX = max(maxX, vertex.position.x * scale);
    minY = min(minY, vertex.position.y * scale);
    maxY = max(maxY, vertex.position.y * scale);
  }
  return max(maxX - minX, maxY - minY);
}

void geodesicMeasurePresetPart(GeodesicSizeSolution solution,
  String partId, SurfaceMesh mesh) {
  GeodesicPlateMeshResource resource =
    new GeodesicPlateMeshResource(partId, partId, mesh);
  if (!resource.valid()) {
    solution.available = false;
    solution.status = "INVALID PART " + partId;
    return;
  }
  float largest = max(resource.widthMM(),
    max(resource.heightMM(), resource.depthMM()));
  float current = max(solution.largestPartWidthMM,
    max(solution.largestPartHeightMM, solution.largestPartDepthMM));
  if (largest > current) {
    solution.limitingPartId = partId;
    solution.largestPartWidthMM = resource.widthMM();
    solution.largestPartHeightMM = resource.heightMM();
    solution.largestPartDepthMM = resource.depthMM();
  }
  if (resource.widthMM() > GEODESIC_P1S_SAFE_PART_MM + 0.001f ||
      resource.heightMM() > GEODESIC_P1S_SAFE_PART_MM + 0.001f ||
      resource.depthMM() > GEODESIC_P1S_SAFE_PART_MM + 0.001f)
    solution.bedFit = false;
}

GeodesicSizeSolution geodesicProbeSize(float requestedRadiusMM,
  GeodesicSizePreset preset) {
  GeodesicSizeSolution solution = new GeodesicSizeSolution();
  solution.preset = preset;
  solution.requestedRadiusMM = max(1.0f, requestedRadiusMM);
  GeodesicModel model = geodesicSizeCandidateModel(solution.requestedRadiusMM);
  if (model == null || !model.valid || model.faces.size() == 0) {
    solution.status = model == null ? "NO MODEL" : model.validation;
    return solution;
  }
  if (geodesicTopologyMode == GeodesicTopologyMode.APERIODIC &&
      geodesicExtent == GeodesicExtentMode.SPHERE) {
    solution.status = "APERIODIC SPHERE IS PREVIEW ONLY";
    return solution;
  }
  GeodesicFabricationSettings requested =
    geodesicFabricationSettingsForModel(model);
  GeodesicFabricationSettings fabrication =
    geodesicResolveKitFabricationSettings(model, requested);
  solution.effectiveRadiusMM = fabrication.effectiveAssemblyRadiusMM;
  solution.assembledDiameterMM =
    geodesicAssembledDiameter(model, fabrication);
  solution.available = true;
  solution.bedFit = true;
  GeodesicPanelCatalog catalog = buildGeodesicPanelCatalog(model,
    fabrication, geodesicGrowth, geodesicReliefMM);
  if (catalog == null || catalog.types.size() == 0) {
    solution.available = false;
    solution.bedFit = false;
    solution.status = "EMPTY PART CATALOG";
    return solution;
  }
  for (GeodesicPartType type : catalog.types) {
    if (type.audit == null || type.audit[0] != 0 ||
        type.audit[1] != 0 || type.audit[2] != 0) {
      solution.available = false;
      solution.bedFit = false;
      solution.status = "PART AUDIT " + type.typeId;
      return solution;
    }
    geodesicMeasurePresetPart(solution, type.typeId, type.mesh);
    if (!solution.available) return solution;
  }
  solution.status = solution.bedFit ? "PRINTABLE" :
    "PART EXCEEDS P1S SAFE ENVELOPE";
  return solution;
}

GeodesicSizeSolution geodesicSolveStandardPreset() {
  float request = GEODESIC_STANDARD_DIAMETER_MM * 0.5f;
  GeodesicSizeSolution solution = null;
  for (int i = 0; i < 6; i++) {
    solution = geodesicProbeSize(request, GeodesicSizePreset.STANDARD);
    if (!solution.available || solution.assembledDiameterMM <= 0) return solution;
    float error = GEODESIC_STANDARD_DIAMETER_MM -
      solution.assembledDiameterMM;
    if (abs(error) <= 0.5f) break;
    float next = request * GEODESIC_STANDARD_DIAMETER_MM /
      solution.assembledDiameterMM;
    // An auto-raised fabrication floor can make the requested diameter
    // impossible without weakening portals or rails.
    if (next < GEODESIC_PRESET_MIN_RADIUS_MM && error < 0) break;
    request = max(1.0f, next);
  }
  if (solution != null &&
      abs(solution.assembledDiameterMM - GEODESIC_STANDARD_DIAMETER_MM) > 1.0f) {
    solution.available = false;
    solution.status = "12 IN DIAMETER CONFLICTS WITH MINIMUM FEATURES";
  }
  if (solution != null && !solution.bedFit) solution.available = false;
  return solution;
}

GeodesicSizeSolution geodesicSolveP1SMaxPreset() {
  GeodesicSizeSolution minimum = geodesicProbeSize(
    GEODESIC_PRESET_MIN_RADIUS_MM, GeodesicSizePreset.P1S_MAX);
  if (!minimum.available || !minimum.bedFit) {
    minimum.available = false;
    minimum.status = "MINIMUM FEATURE KIT EXCEEDS P1S ENVELOPE";
    return minimum;
  }
  float low = GEODESIC_PRESET_MIN_RADIUS_MM;
  float high = max(240.0f, low * 2.0f);
  GeodesicSizeSolution best = minimum;
  for (int i = 0; i < 10; i++) {
    GeodesicSizeSolution probe = geodesicProbeSize(high,
      GeodesicSizePreset.P1S_MAX);
    if (!probe.available || !probe.bedFit) break;
    best = probe;
    low = high;
    high *= 2.0f;
  }
  for (int i = 0; i < 12; i++) {
    float mid = (low + high) * 0.5f;
    GeodesicSizeSolution probe = geodesicProbeSize(mid,
      GeodesicSizePreset.P1S_MAX);
    if (probe.available && probe.bedFit) {
      best = probe;
      low = mid;
    } else high = mid;
  }
  best.preset = GeodesicSizePreset.P1S_MAX;
  best.status = "P1S MAX / 246 MM SAFE PART ENVELOPE";
  return best;
}

GeodesicSizeSolution geodesicSolveSizePreset(GeodesicSizePreset preset) {
  if (preset == GeodesicSizePreset.MICRO) {
    GeodesicSizeSolution solution = geodesicProbeSize(
      GEODESIC_PRESET_MIN_RADIUS_MM, preset);
    if (!solution.bedFit) solution.available = false;
    if (solution.available)
      solution.status = "MICRO / MINIMUM PROTECTED FEATURES";
    return solution;
  }
  if (preset == GeodesicSizePreset.STANDARD)
    return geodesicSolveStandardPreset();
  if (preset == GeodesicSizePreset.P1S_MAX)
    return geodesicSolveP1SMaxPreset();
  return geodesicProbeSize(geodesicRadiusMM, preset);
}

void applyGeodesicSizePreset(GeodesicSizePreset preset) {
  geodesicSizePreset = preset;
  rebuildGeodesicSalonModel("size preset " + preset.label);
}

void geodesicResolveActiveSizePreset() {
  if (geodesicSizePreset == GeodesicSizePreset.CUSTOM ||
      geodesicResolvingSizePreset) return;
  geodesicResolvingSizePreset = true;
  GeodesicSizeSolution solved = geodesicSolveSizePreset(geodesicSizePreset);
  geodesicResolvingSizePreset = false;
  geodesicSizeSolution = solved;
  if (solved != null && solved.available && solved.bedFit) {
    geodesicRadiusMM = solved.requestedRadiusMM;
    geodesicSizePresetNotice = solved.status;
  } else {
    String failure = solved == null ? "NO SIZE SOLUTION" : solved.status;
    geodesicSizePreset = GeodesicSizePreset.CUSTOM;
    geodesicSizePresetNotice = "PRESET UNAVAILABLE / " + failure;
  }
}

void geodesicRefreshCustomSizeSolution() {
  if (geodesicSizePreset != GeodesicSizePreset.CUSTOM) return;
  GeodesicSizeSolution solution = new GeodesicSizeSolution();
  solution.preset = GeodesicSizePreset.CUSTOM;
  solution.requestedRadiusMM = geodesicRadiusMM;
  GeodesicFabricationSettings fabrication = geodesicLastPreflight == null ?
    null : geodesicLastPreflight.fabrication;
  GeodesicPanelCatalog catalog = geodesicLastPreflight == null ?
    null : geodesicLastPreflight.catalog;
  solution.effectiveRadiusMM = fabrication == null ? geodesicRadiusMM :
    fabrication.effectiveAssemblyRadiusMM;
  solution.assembledDiameterMM =
    geodesicAssembledDiameter(geodesicModel, fabrication);
  solution.available = geodesicModel != null && geodesicModel.valid &&
    catalog != null && catalog.types.size() > 0;
  solution.bedFit = solution.available;
  if (catalog != null) {
    for (GeodesicPartType type : catalog.types) {
      geodesicMeasurePresetPart(solution, type.typeId, type.mesh);
      if (!solution.available) break;
    }
  }
  solution.status = !solution.available ? "CUSTOM / KIT PREFLIGHT BLOCKED" :
    solution.bedFit ? "CUSTOM / P1S PART FIT" :
    "CUSTOM / PART EXCEEDS P1S";
  geodesicSizeSolution = solution;
  geodesicSizePresetNotice = solution.status;
}

boolean geodesicPresetExportReady() {
  return geodesicSizePreset == GeodesicSizePreset.CUSTOM ||
    (geodesicSizeSolution != null && geodesicSizeSolution.available &&
    geodesicSizeSolution.bedFit);
}

String geodesicSizePresetReadout() {
  if (geodesicSizeSolution == null) return geodesicSizePreset.label;
  return geodesicSizePreset.label + " / " +
    nf(geodesicSizeSolution.assembledDiameterMM, 1, 1) + " mm DIA";
}

String geodesicLargestPartReadout() {
  if (geodesicSizeSolution == null) return "NOT CHECKED";
  return geodesicSizeSolution.limitingPartId + " " +
    nf(geodesicSizeSolution.largestPartWidthMM, 1, 1) + "x" +
    nf(geodesicSizeSolution.largestPartHeightMM, 1, 1) + "x" +
    nf(geodesicSizeSolution.largestPartDepthMM, 1, 1) + " mm / " +
    (geodesicSizeSolution.bedFit ? "FIT" : "BLOCKED");
}
