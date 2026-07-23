/*
  Deterministic Geodesic Salon panel-color planning.

  Paint data is additive fabrication metadata. Canonical uncolored panel STLs
  remain unchanged; optional color batches duplicate only the reusable meshes
  required for a selected color assignment.
*/

enum GeodesicPaintScheme {
  PROPAGATION,
  GROWTH_RINGS,
  SPIRAL,
  ADJACENCY_WEAVE,
  RECURSIVE_FRACTAL,
  MACRO_GEOMETRY,
  RDFT_FIELD,
  CURVATURE,
  HARMONIC;

  String label() {
    if (this == PROPAGATION) return "PROPAGATION";
    if (this == GROWTH_RINGS) return "GROWTH RINGS";
    if (this == SPIRAL) return "SPIRAL";
    if (this == ADJACENCY_WEAVE) return "ADJACENCY WEAVE";
    if (this == RECURSIVE_FRACTAL) return "RECURSIVE FRACTAL";
    if (this == MACRO_GEOMETRY) return "MACRO GEOMETRY";
    if (this == RDFT_FIELD) return "RDFT FIELD";
    if (this == CURVATURE) return "CURVATURE";
    return "HARMONIC";
  }

  String key() {
    return label().toLowerCase().replace(" ", "_");
  }
}

boolean geodesicPaintEnabled = false;
GeodesicPaintScheme geodesicPaintScheme =
  GeodesicPaintScheme.PROPAGATION;
int geodesicPaintColorCount = 6;
float geodesicPaintPhase = 0;
GeodesicPaintPlan geodesicPaintPlan = null;

class GeodesicPaintAssignment {
  int faceId;
  String placementId = "";
  String typeId = "UNASSIGNED";
  int colorIndex;
  String colorId;
  int rgb;
  float scalar;
  float arrival;
  String batchFile = "";

  GeodesicPaintAssignment(int faceId, int colorIndex, float scalar,
    float arrival) {
    this.faceId = faceId;
    this.colorIndex = colorIndex;
    this.colorId = geodesicPaintColorId(colorIndex);
    this.rgb = geodesicPaintPaletteColor(colorIndex);
    this.scalar = scalar;
    this.arrival = arrival;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("face_id", faceId);
    json.setString("placement_id", placementId);
    json.setString("reusable_type_id", typeId);
    json.setInt("color_index", colorIndex);
    json.setString("color_id", colorId);
    json.setString("color_hex", geodesicPaintHex(rgb));
    json.setFloat("assignment_scalar", scalar);
    json.setFloat("growth_arrival", arrival);
    json.setString("batch_file", batchFile);
    return json;
  }
}

class GeodesicPaintPlan {
  GeodesicPaintScheme scheme;
  int requestedColorCount;
  int effectiveColorCount;
  float phase;
  int sourceSeed;
  String modelFingerprint;
  ArrayList<GeodesicPaintAssignment> assignments =
    new ArrayList<GeodesicPaintAssignment>();
  HashMap<Integer, GeodesicPaintAssignment> byFace =
    new HashMap<Integer, GeodesicPaintAssignment>();

  GeodesicPaintPlan(GeodesicPaintScheme scheme, int requestedColorCount,
    float phase, int sourceSeed, String modelFingerprint) {
    this.scheme = scheme;
    this.requestedColorCount = requestedColorCount;
    this.effectiveColorCount = scheme == GeodesicPaintScheme.PROPAGATION ?
      3 : constrain(requestedColorCount, 3, 12);
    if (scheme == GeodesicPaintScheme.ADJACENCY_WEAVE)
      this.effectiveColorCount = max(4, this.effectiveColorCount);
    this.phase = phase;
    this.sourceSeed = sourceSeed;
    this.modelFingerprint = modelFingerprint;
  }

  void add(GeodesicPaintAssignment assignment) {
    assignments.add(assignment);
    byFace.put(assignment.faceId, assignment);
  }

  GeodesicPaintAssignment forFace(int faceId) {
    return byFace.get(faceId);
  }

  HashMap<Integer, Integer> colorQuantities() {
    HashMap<Integer, Integer> quantities =
      new HashMap<Integer, Integer>();
    for (GeodesicPaintAssignment assignment : assignments) {
      int index = assignment.colorIndex;
      quantities.put(index, quantities.containsKey(index) ?
        quantities.get(index) + 1 : 1);
    }
    return quantities;
  }

  ArrayList<Integer> usedColorIndices() {
    ArrayList<Integer> indices = new ArrayList<Integer>(
      colorQuantities().keySet());
    java.util.Collections.sort(indices);
    return indices;
  }

  int usedColorCount() {
    return colorQuantities().size();
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.geodesic_salon.paint_plan.v1");
    json.setString("scheme", scheme.label());
    json.setString("scheme_key", scheme.key());
    json.setInt("requested_color_count", requestedColorCount);
    json.setInt("effective_color_count", effectiveColorCount);
    json.setInt("used_color_count", usedColorCount());
    json.setInt("unused_color_count",
      max(0, effectiveColorCount - usedColorCount()));
    json.setFloat("phase", phase);
    json.setInt("source_seed", sourceSeed);
    json.setString("model_fingerprint", modelFingerprint);
    HashMap<Integer, Integer> quantities = colorQuantities();
    JSONArray palette = new JSONArray();
    JSONArray usedPalette = new JSONArray();
    int usedPaletteIndex = 0;
    for (int i = 0; i < effectiveColorCount; i++) {
      JSONObject swatch = new JSONObject();
      swatch.setString("color_id", geodesicPaintColorId(i));
      swatch.setString("color_hex",
        geodesicPaintHex(geodesicPaintPaletteColor(i)));
      int panelCount = quantities.containsKey(i) ? quantities.get(i) : 0;
      swatch.setInt("panel_count", panelCount);
      swatch.setBoolean("used", panelCount > 0);
      palette.setJSONObject(i, swatch);
      if (panelCount > 0)
        usedPalette.setJSONObject(usedPaletteIndex++, swatch);
    }
    json.setJSONArray("palette", palette);
    json.setJSONArray("used_palette", usedPalette);
    JSONArray values = new JSONArray();
    for (int i = 0; i < assignments.size(); i++)
      values.setJSONObject(i, assignments.get(i).toJSON());
    json.setJSONArray("face_assignments", values);
    return json;
  }
}

class GeodesicPaintExportResult {
  boolean enabled = false;
  boolean success = true;
  String status = "PAINT OFF";
  String planJson = "";
  String scheduleCsv = "";
  String batchesCsv = "";
  String guidePng = "";
  String guideSvg = "";
  String validationJson = "";
  int batchFiles = 0;
  int availableColorCount = 0;
  int usedColorCount = 0;
  int expectedFaces = 0;
  int assignedFaces = 0;
  int batchQuantity = 0;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("enabled", enabled);
    json.setBoolean("success", success);
    json.setString("status", status);
    json.setString("paint_plan_json", planJson);
    json.setString("paint_schedule_csv", scheduleCsv);
    json.setString("print_batches_csv", batchesCsv);
    json.setString("paint_map_png", guidePng);
    json.setString("paint_map_svg", guideSvg);
    json.setString("validation_json", validationJson);
    json.setInt("color_batch_stl_files", batchFiles);
    json.setInt("available_color_count", availableColorCount);
    json.setInt("used_color_count", usedColorCount);
    json.setInt("expected_faces", expectedFaces);
    json.setInt("assigned_faces", assignedFaces);
    json.setInt("batch_quantity", batchQuantity);
    return json;
  }
}

class GeodesicPaintValidation {
  boolean valid = false;
  String status = "NOT CHECKED";
  int expectedFaces = 0;
  int assignmentRows = 0;
  int uniqueFaceIds = 0;
  int missingFaceIds = 0;
  int duplicateFaceIds = 0;
  int invalidFaceIds = 0;
  int invalidColorAssignments = 0;
  int reusableTypeMismatches = 0;
  int availableColorCount = 0;
  int usedColorCount = 0;
  int batchFiles = 0;
  int batchQuantity = 0;
  int missingBatchFiles = 0;

  boolean assignmentsValid() {
    return assignmentRows == expectedFaces &&
      uniqueFaceIds == expectedFaces && missingFaceIds == 0 &&
      duplicateFaceIds == 0 && invalidFaceIds == 0 &&
      invalidColorAssignments == 0 && reusableTypeMismatches == 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema",
      "fieldworks.geodesic_salon.paint_validation.v1");
    json.setBoolean("valid", valid);
    json.setString("status", status);
    json.setInt("expected_faces", expectedFaces);
    json.setInt("assignment_rows", assignmentRows);
    json.setInt("unique_face_ids", uniqueFaceIds);
    json.setInt("missing_face_ids", missingFaceIds);
    json.setInt("duplicate_face_ids", duplicateFaceIds);
    json.setInt("invalid_face_ids", invalidFaceIds);
    json.setInt("invalid_color_assignments", invalidColorAssignments);
    json.setInt("reusable_type_mismatches", reusableTypeMismatches);
    json.setInt("available_color_count", availableColorCount);
    json.setInt("used_color_count", usedColorCount);
    json.setInt("batch_files", batchFiles);
    json.setInt("batch_quantity", batchQuantity);
    json.setInt("missing_batch_files", missingBatchFiles);
    return json;
  }
}

void refreshGeodesicPaintPlan() {
  if (geodesicModel == null) {
    geodesicPaintPlan = null;
    return;
  }
  GeodesicPanelCatalog catalog = geodesicLastPreflight == null ?
    null : geodesicLastPreflight.catalog;
  geodesicPaintPlan = buildGeodesicPaintPlan(geodesicModel, catalog,
    geodesicPaintScheme, geodesicPaintColorCount, geodesicPaintPhase);
}

GeodesicPaintPlan currentGeodesicPaintPlan() {
  if (geodesicPaintPlan == null ||
      geodesicPaintPlan.scheme != geodesicPaintScheme ||
      geodesicPaintPlan.requestedColorCount != geodesicPaintColorCount ||
      abs(geodesicPaintPlan.phase - geodesicPaintPhase) > 0.0001f ||
      geodesicModel == null ||
      !geodesicPaintPlan.modelFingerprint.equals(geodesicModel.fingerprint))
    refreshGeodesicPaintPlan();
  return geodesicPaintPlan;
}

GeodesicPaintPlan buildGeodesicPaintPlan(GeodesicModel model,
  GeodesicPanelCatalog catalog, GeodesicPaintScheme scheme,
  int colorCount, float phase) {
  GeodesicPaintPlan plan = new GeodesicPaintPlan(scheme, colorCount,
    phase, seed, model == null ? "invalid" : model.fingerprint);
  if (model == null) return plan;
  HashMap<Integer, Integer> weave = scheme ==
    GeodesicPaintScheme.ADJACENCY_WEAVE ?
    geodesicAdjacencyPaintColors(model, plan.effectiveColorCount) :
    new HashMap<Integer, Integer>();
  float[] curvature = scheme == GeodesicPaintScheme.CURVATURE ?
    geodesicPaintCurvatureScalars(model) : null;

  for (GeodesicFace face : model.faces) {
    float arrival = geodesicFaceArrival(face);
    float scalar = geodesicPaintScalar(model, face, scheme, arrival,
      phase, curvature);
    int colorIndex;
    if (scheme == GeodesicPaintScheme.PROPAGATION) {
      float propagationPhase =
        geodesicPositiveFraction(face.parentFace * 0.173f +
        arrival * 0.77f);
      colorIndex = propagationPhase < 0.34f ? 0 :
        (propagationPhase < 0.68f ? 1 : 2);
      scalar = propagationPhase;
    } else if (scheme == GeodesicPaintScheme.ADJACENCY_WEAVE) {
      colorIndex = weave.containsKey(face.id) ?
        weave.get(face.id) : 0;
      scalar = colorIndex /
        (float)max(1, plan.effectiveColorCount - 1);
    } else {
      colorIndex = constrain(floor(scalar * plan.effectiveColorCount),
        0, plan.effectiveColorCount - 1);
    }
    GeodesicPaintAssignment assignment = new GeodesicPaintAssignment(
      face.id, colorIndex, scalar, arrival);
    if (catalog != null && catalog.faceToType.containsKey(face.id))
      assignment.typeId = catalog.faceToType.get(face.id);
    if (geodesicAssemblyMode == GeodesicAssemblyMode.KICAS &&
        geodesicLastPreflight != null &&
        geodesicLastPreflight.fabrication != null &&
        geodesicLastPreflight.fabrication.kicasPlan != null)
      assignment.placementId =
        geodesicLastPreflight.fabrication.kicasPlan.labelForFace(face.id);
    plan.add(assignment);
  }
  return plan;
}

float geodesicPaintScalar(GeodesicModel model, GeodesicFace face,
  GeodesicPaintScheme scheme, float arrival, float phase,
  float[] curvature) {
  float azimuth = geodesicPositiveFraction(
    (atan2(face.centroid.y, face.centroid.x) + PI) / TWO_PI);
  float polar = constrain((face.centroid.z / max(0.001f, model.radius) +
    1.0f) * 0.5f, 0, 1);
  if (scheme == GeodesicPaintScheme.GROWTH_RINGS)
    return geodesicPositiveFraction(arrival + phase);
  if (scheme == GeodesicPaintScheme.SPIRAL)
    return geodesicPositiveFraction(azimuth * 2.0f +
      (1.0f - polar) * 1.35f + phase);
  if (scheme == GeodesicPaintScheme.RECURSIVE_FRACTAL) {
    float recursive = sin((face.parentFace + 1) * 12.9898f +
      (face.id + 1) * 78.233f + seed * 0.013f + phase * TWO_PI);
    return geodesicPositiveFraction(abs(recursive) * 43758.5453f);
  }
  if (scheme == GeodesicPaintScheme.MACRO_GEOMETRY)
    return geodesicPositiveFraction(
      (face.parentFace + phase * max(1, geodesicFrequency)) /
      (float)max(1, geodesicPaintColorCount));
  if (scheme == GeodesicPaintScheme.RDFT_FIELD) {
    PVector n = face.normal;
    float value = sin(n.x * (alpha + 1.0f) * 2.3f +
      n.y * (sourcePressure + 0.5f) * 3.7f +
      n.z * (braneTwist + 0.5f) * 4.1f +
      azimuth * TWO_PI * max(1, geodesicFrequency) +
      coherenceBias * 2.0f + phase * TWO_PI);
    value += 0.42f * cos(polar * PI * (deepDetail * 5.0f + 1.0f) +
      floquetCoupling * TWO_PI);
    return constrain(0.5f + value / 2.84f, 0, 0.999999f);
  }
  if (scheme == GeodesicPaintScheme.CURVATURE)
    return curvature == null || face.id < 0 ||
      face.id >= curvature.length ? 0 : curvature[face.id];
  if (scheme == GeodesicPaintScheme.HARMONIC) {
    int m = max(1, geodesicFrequency);
    int l = max(1, min(8, depth + 1));
    float harmonic = sin(azimuth * TWO_PI * m + phase * TWO_PI) *
      cos((polar - 0.5f) * PI * l);
    return constrain(0.5f + 0.5f * harmonic, 0, 0.999999f);
  }
  return arrival;
}

HashMap<Integer, Integer> geodesicAdjacencyPaintColors(
  GeodesicModel model, int colorCount) {
  HashMap<Integer, Integer> result = new HashMap<Integer, Integer>();
  ArrayList<GeodesicFace> order =
    new ArrayList<GeodesicFace>(model.faces);
  java.util.Collections.sort(order,
    new java.util.Comparator<GeodesicFace>() {
      public int compare(GeodesicFace a, GeodesicFace b) {
        int degreeA = geodesicFaceDegree(a);
        int degreeB = geodesicFaceDegree(b);
        if (degreeA != degreeB) return degreeB - degreeA;
        return a.id - b.id;
      }
    });
  for (GeodesicFace face : order) {
    boolean[] used = new boolean[max(4, colorCount)];
    for (int neighbor : face.neighbors)
      if (result.containsKey(neighbor)) {
        int neighborColor = result.get(neighbor);
        if (neighborColor >= 0 && neighborColor < used.length)
          used[neighborColor] = true;
      }
    int selected = 0;
    while (selected < used.length && used[selected]) selected++;
    if (selected >= colorCount) selected =
      abs(face.id + face.parentFace) % max(1, colorCount);
    result.put(face.id, selected);
  }
  return result;
}

int geodesicFaceDegree(GeodesicFace face) {
  int degree = 0;
  for (int neighbor : face.neighbors) if (neighbor >= 0) degree++;
  return degree;
}

float[] geodesicPaintCurvatureScalars(GeodesicModel model) {
  float[] values = new float[model.faces.size()];
  float minimum = Float.MAX_VALUE;
  float maximum = -Float.MAX_VALUE;
  for (GeodesicFace face : model.faces) {
    float sum = 0;
    int count = 0;
    for (int neighbor : face.neighbors) if (neighbor >= 0) {
      float angle = acos(constrain(face.normal.dot(
        model.faces.get(neighbor).normal), -1, 1));
      sum += angle;
      count++;
    }
    values[face.id] = count == 0 ? 0 : sum / count;
    minimum = min(minimum, values[face.id]);
    maximum = max(maximum, values[face.id]);
  }
  float range = max(0.000001f, maximum - minimum);
  for (int i = 0; i < values.length; i++)
    values[i] = constrain((values[i] - minimum) / range,
      0, 0.999999f);
  return values;
}

float geodesicPositiveFraction(float value) {
  value %= 1.0f;
  return value < 0 ? value + 1.0f : value;
}

String geodesicPaintColorId(int index) {
  return "C" + nf(index + 1, 2);
}

int geodesicPaintPaletteColor(int index) {
  int[][] palette = {
    { 27, 214, 190 },
    { 74, 154, 238 },
    { 232, 84, 166 },
    { 255, 190, 50 },
    { 116, 224, 94 },
    { 238, 94, 73 },
    { 152, 104, 230 },
    { 242, 228, 90 },
    { 43, 202, 232 },
    { 245, 132, 50 },
    { 215, 228, 240 },
    { 82, 92, 112 }
  };
  int[] rgb = palette[(index % palette.length + palette.length) %
    palette.length];
  return color(rgb[0], rgb[1], rgb[2]);
}

String geodesicPaintHex(int value) {
  return "#" + hex((value >> 16) & 0xff, 2) +
    hex((value >> 8) & 0xff, 2) + hex(value & 0xff, 2);
}

int geodesicPaintDisplayColor(int faceId) {
  GeodesicPaintPlan plan = currentGeodesicPaintPlan();
  GeodesicPaintAssignment assignment = plan == null ?
    null : plan.forFace(faceId);
  return assignment == null ? color(60, 78, 88) : assignment.rgb;
}

String geodesicSelectedPaintLabel() {
  GeodesicPaintPlan plan = currentGeodesicPaintPlan();
  if (plan == null) return "-";
  GeodesicPaintAssignment assignment =
    plan.forFace(geodesicSelectedFace);
  return assignment == null ? "-" :
    assignment.colorId + " / " + assignment.typeId;
}

void cycleGeodesicPaintScheme(int direction) {
  GeodesicPaintScheme[] values = GeodesicPaintScheme.values();
  int index = (geodesicPaintScheme.ordinal() + direction +
    values.length) % values.length;
  geodesicPaintScheme = values[index];
  refreshGeodesicPaintPlan();
  geodesicStatus = "PAINT / " + geodesicPaintScheme.label();
}

void adjustGeodesicPaintColors(int direction) {
  geodesicPaintColorCount = constrain(geodesicPaintColorCount +
    direction, 3, 12);
  refreshGeodesicPaintPlan();
  geodesicStatus = "PAINT COLORS / " +
    currentGeodesicPaintPlan().effectiveColorCount;
}

void adjustGeodesicPaintPhase(int direction) {
  geodesicPaintPhase = geodesicPositiveFraction(
    geodesicPaintPhase + direction * 0.05f);
  refreshGeodesicPaintPlan();
  geodesicStatus = "PAINT PHASE / " +
    nf(geodesicPaintPhase, 1, 2);
}

GeodesicPaintValidation validateGeodesicPaintAssignments(
  GeodesicPaintPlan plan, GeodesicModel model,
  GeodesicPanelCatalog catalog) {
  GeodesicPaintValidation validation = new GeodesicPaintValidation();
  validation.expectedFaces = model == null ? 0 : model.faces.size();
  validation.assignmentRows = plan == null ? 0 : plan.assignments.size();
  validation.availableColorCount = plan == null ?
    0 : plan.effectiveColorCount;
  validation.usedColorCount = plan == null ? 0 : plan.usedColorCount();
  if (plan == null || model == null) {
    validation.status = "PAINT PLAN OR MODEL MISSING";
    return validation;
  }

  boolean[] seen = new boolean[validation.expectedFaces];
  for (GeodesicPaintAssignment assignment : plan.assignments) {
    if (assignment.faceId < 0 ||
        assignment.faceId >= validation.expectedFaces) {
      validation.invalidFaceIds++;
      continue;
    }
    if (seen[assignment.faceId]) validation.duplicateFaceIds++;
    else {
      seen[assignment.faceId] = true;
      validation.uniqueFaceIds++;
    }
    if (assignment.colorIndex < 0 ||
        assignment.colorIndex >= plan.effectiveColorCount ||
        !assignment.colorId.equals(
        geodesicPaintColorId(assignment.colorIndex)) ||
        assignment.rgb != geodesicPaintPaletteColor(
        assignment.colorIndex))
      validation.invalidColorAssignments++;
    if (catalog != null &&
        catalog.faceToType.containsKey(assignment.faceId) &&
        !catalog.faceToType.get(assignment.faceId).equals(
        assignment.typeId))
      validation.reusableTypeMismatches++;
  }
  for (boolean value : seen) if (!value) validation.missingFaceIds++;
  validation.valid = validation.assignmentsValid();
  validation.status = validation.valid ?
    "FACE ASSIGNMENTS PASS" : "FACE ASSIGNMENTS INVALID";
  return validation;
}

void validateGeodesicPaintBatches(GeodesicPaintValidation validation,
  File runFolder, GeodesicPaintPlan plan) {
  if (validation == null || plan == null) return;
  HashMap<String, Integer> quantities = new HashMap<String, Integer>();
  for (GeodesicPaintAssignment assignment : plan.assignments) {
    String path = assignment.batchFile == null ?
      "" : assignment.batchFile;
    if (path.length() == 0) {
      validation.missingBatchFiles++;
      continue;
    }
    quantities.put(path, quantities.containsKey(path) ?
      quantities.get(path) + 1 : 1);
  }
  validation.batchFiles = quantities.size();
  validation.batchQuantity = 0;
  for (String path : quantities.keySet()) {
    validation.batchQuantity += quantities.get(path);
    File batch = new File(runFolder, path);
    if (!batch.exists() || batch.length() <= 84)
      validation.missingBatchFiles++;
  }
  validation.valid = validation.assignmentsValid() &&
    validation.batchQuantity == validation.expectedFaces &&
    validation.batchFiles > 0 && validation.missingBatchFiles == 0;
  validation.status = validation.valid ?
    "PAINT PACKAGE PASS" : "PAINT PACKAGE INVALID";
}

GeodesicPaintExportResult exportGeodesicPaintPackage(File runFolder,
  GeodesicPanelCatalog catalog, GeodesicFabricationSettings fabrication,
  String stamp) {
  GeodesicPaintExportResult result = new GeodesicPaintExportResult();
  result.enabled = geodesicPaintEnabled;
  if (!result.enabled) return result;
  GeodesicPaintPlan plan = buildGeodesicPaintPlan(geodesicModel,
    catalog, geodesicPaintScheme, geodesicPaintColorCount,
    geodesicPaintPhase);
  geodesicPaintPlan = plan;
  result.availableColorCount = plan.effectiveColorCount;
  result.usedColorCount = plan.usedColorCount();
  result.expectedFaces = geodesicModel == null ?
    0 : geodesicModel.faces.size();
  result.assignedFaces = plan.assignments.size();
  File paintFolder = new File(runFolder, "paint");
  File batchRoot = new File(paintFolder, "parts_by_color");
  if ((!paintFolder.exists() && !paintFolder.mkdirs()) ||
      (!batchRoot.exists() && !batchRoot.mkdirs())) {
    result.success = false;
    result.status = "PAINT FOLDER FAILED";
    return result;
  }
  result.validationJson = "paint/paint_validation.json";
  GeodesicPaintValidation validation =
    validateGeodesicPaintAssignments(plan, geodesicModel, catalog);
  if (!validation.valid) {
    saveJSONObject(validation.toJSON(),
      new File(runFolder, result.validationJson).getAbsolutePath());
    result.success = false;
    result.status = validation.status;
    return result;
  }

  HashMap<String, ArrayList<GeodesicPaintAssignment>> groups =
    new HashMap<String, ArrayList<GeodesicPaintAssignment>>();
  for (GeodesicPaintAssignment assignment : plan.assignments) {
    String partKey = fabrication.assemblyMode ==
      GeodesicAssemblyMode.KICAS ?
      geodesicKicasPlacementForFace(fabrication, assignment.faceId) :
      assignment.typeId;
    assignment.placementId = fabrication.assemblyMode ==
      GeodesicAssemblyMode.KICAS ? partKey : "";
    String key = partKey + "|" + assignment.colorId;
    if (!groups.containsKey(key))
      groups.put(key, new ArrayList<GeodesicPaintAssignment>());
    groups.get(key).add(assignment);
  }

  ArrayList<String> keys = new ArrayList<String>(groups.keySet());
  java.util.Collections.sort(keys);
  for (String key : keys) {
    ArrayList<GeodesicPaintAssignment> batch = groups.get(key);
    if (batch == null || batch.size() == 0) continue;
    GeodesicPaintAssignment first = batch.get(0);
    String partId = fabrication.assemblyMode ==
      GeodesicAssemblyMode.KICAS ? first.placementId : first.typeId;
    String filename = partId + "_" + first.colorId + "_qty" +
      nf(batch.size(), 3) + ".stl";
    File colorFolder = new File(batchRoot, first.colorId);
    if (!colorFolder.exists() && !colorFolder.mkdirs()) {
      result.success = false;
      result.status = "COLOR BATCH FOLDER FAILED";
      return result;
    }
    SurfaceMesh mesh;
    if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
      mesh = buildGeodesicFabricatedPart(geodesicModel,
        geodesicModel.faces.get(first.faceId), fabrication,
        geodesicGrowth, geodesicReliefMM).mesh;
    } else {
      GeodesicPartType type = catalog.typeById(first.typeId);
      mesh = type == null ? null : type.mesh;
    }
    if (mesh == null || mesh.tris.size() == 0) {
      result.success = false;
      result.status = "COLOR BATCH MESH MISSING / " + partId;
      return result;
    }
    String relative = "paint/parts_by_color/" + first.colorId +
      "/" + filename;
    mesh.writeSTL(new File(runFolder, relative).getAbsolutePath());
    for (GeodesicPaintAssignment assignment : batch)
      assignment.batchFile = relative;
    result.batchFiles++;
  }
  validateGeodesicPaintBatches(validation, runFolder, plan);
  result.batchQuantity = validation.batchQuantity;
  saveJSONObject(validation.toJSON(),
    new File(runFolder, result.validationJson).getAbsolutePath());

  result.planJson = "paint/paint_plan.json";
  result.scheduleCsv = "paint/paint_schedule.csv";
  result.batchesCsv = "paint/print_batches.csv";
  saveJSONObject(plan.toJSON(),
    new File(runFolder, result.planJson).getAbsolutePath());
  writeGeodesicPaintSchedule(new File(runFolder, result.scheduleCsv),
    plan, catalog);
  writeGeodesicPaintBatches(new File(runFolder, result.batchesCsv),
    plan);
  result.guidePng = "guides/GS-004_paint_map.png";
  renderGeodesicPaintGuideRaster(
    new File(runFolder, result.guidePng), plan, stamp);
  if (geodesicGuideSvgEnabled) {
    result.guideSvg = "guides/GS-004_paint_map.svg";
    renderGeodesicPaintGuideSvg(
      new File(runFolder, result.guideSvg), plan, stamp);
  }
  result.success = result.success &&
    validation.valid &&
    new File(runFolder, result.planJson).exists() &&
    new File(runFolder, result.scheduleCsv).exists() &&
    new File(runFolder, result.guidePng).exists() &&
    new File(runFolder, result.validationJson).exists();
  result.status = result.success ?
    plan.scheme.label() + " / " + plan.usedColorCount() +
    " USED COLORS / " + result.batchFiles +
    " BATCH FILES" : "PAINT EXPORT INCOMPLETE";
  return result;
}

String geodesicKicasPlacementForFace(
  GeodesicFabricationSettings fabrication, int faceId) {
  if (fabrication == null || fabrication.kicasPlan == null)
    return "P" + nf(faceId + 1, 3);
  String label = fabrication.kicasPlan.labelForFace(faceId);
  return label == null || label.length() == 0 ?
    "P" + nf(faceId + 1, 3) : label;
}

void writeGeodesicPaintSchedule(File file, GeodesicPaintPlan plan,
  GeodesicPanelCatalog catalog) {
  PrintWriter writer = createWriter(file.getAbsolutePath());
  writer.println("face_id,placement_id,reusable_type_id,color_id,color_hex,assignment_scalar,growth_arrival,neighbor_faces,batch_file");
  for (GeodesicPaintAssignment assignment : plan.assignments) {
    GeodesicFace face = geodesicModel.faces.get(assignment.faceId);
    String neighbors = face.neighbors[0] + "|" + face.neighbors[1] +
      "|" + face.neighbors[2];
    writer.println(assignment.faceId + "," +
      geodesicCsv(assignment.placementId) + "," +
      geodesicCsv(assignment.typeId) + "," + assignment.colorId + "," +
      geodesicPaintHex(assignment.rgb) + "," +
      nf(assignment.scalar, 1, 6) + "," +
      nf(assignment.arrival, 1, 6) + "," +
      geodesicCsv(neighbors) + "," +
      geodesicCsv(assignment.batchFile));
  }
  writer.flush();
  writer.close();
}

void writeGeodesicPaintBatches(File file, GeodesicPaintPlan plan) {
  HashMap<String, Integer> quantities = new HashMap<String, Integer>();
  HashMap<String, String> files = new HashMap<String, String>();
  HashMap<String, String> colors = new HashMap<String, String>();
  for (GeodesicPaintAssignment assignment : plan.assignments) {
    String key = assignment.batchFile;
    quantities.put(key, quantities.containsKey(key) ?
      quantities.get(key) + 1 : 1);
    files.put(key, assignment.batchFile);
    colors.put(key, assignment.colorId);
  }
  ArrayList<String> keys = new ArrayList<String>(quantities.keySet());
  java.util.Collections.sort(keys);
  PrintWriter writer = createWriter(file.getAbsolutePath());
  writer.println("color_id,color_hex,quantity,batch_file");
  for (String key : keys) {
    String colorId = colors.get(key);
    int index = max(0, int(colorId.substring(1)) - 1);
    writer.println(colorId + "," +
      geodesicPaintHex(geodesicPaintPaletteColor(index)) + "," +
      quantities.get(key) + "," + geodesicCsv(files.get(key)));
  }
  writer.flush();
  writer.close();
}

String geodesicCsv(String value) {
  if (value == null) return "";
  return "\"" + value.replace("\"", "\"\"") + "\"";
}

class GeodesicPaintProjectedFace {
  GeodesicFace face;
  PVector[] points = new PVector[3];
  float depth;
  boolean frontFacing;
  float labelClearance;
}

ArrayList<GeodesicPaintProjectedFace> geodesicPaintProjection(
  GeodesicModel model, float centerX, float centerY, float scale) {
  return geodesicPaintProjection(model, centerX, centerY, scale,
    0.62f, -0.58f);
}

ArrayList<GeodesicPaintProjectedFace> geodesicPaintProjection(
  GeodesicModel model, float centerX, float centerY, float scale,
  float rz, float rx) {
  ArrayList<GeodesicPaintProjectedFace> result =
    new ArrayList<GeodesicPaintProjectedFace>();
  for (GeodesicFace face : model.faces) {
    GeodesicPaintProjectedFace projected =
      new GeodesicPaintProjectedFace();
    projected.face = face;
    projected.depth = 0;
    float normalY = sin(rz) * face.normal.x +
      cos(rz) * face.normal.y;
    float normalZ = sin(rx) * normalY +
      cos(rx) * face.normal.z;
    projected.frontFacing = normalZ > 0.0001f;
    for (int i = 0; i < 3; i++) {
      PVector p = model.vertices.get(face.vertex(i)).position;
      float x1 = cos(rz) * p.x - sin(rz) * p.y;
      float y1 = sin(rz) * p.x + cos(rz) * p.y;
      float y2 = cos(rx) * y1 - sin(rx) * p.z;
      float z2 = sin(rx) * y1 + cos(rx) * p.z;
      projected.points[i] =
        new PVector(centerX + x1 * scale, centerY + y2 * scale, z2);
      projected.depth += z2;
    }
    projected.depth /= 3.0f;
    float edgeAB = PVector.dist(projected.points[0], projected.points[1]);
    float edgeBC = PVector.dist(projected.points[1], projected.points[2]);
    float edgeCA = PVector.dist(projected.points[2], projected.points[0]);
    float longestEdge = max(edgeAB, max(edgeBC, edgeCA));
    float twiceArea = abs(
      (projected.points[1].x - projected.points[0].x) *
      (projected.points[2].y - projected.points[0].y) -
      (projected.points[1].y - projected.points[0].y) *
      (projected.points[2].x - projected.points[0].x));
    projected.labelClearance = longestEdge > 0.0001f ?
      twiceArea / longestEdge : 0;
    result.add(projected);
  }
  java.util.Collections.sort(result,
    new java.util.Comparator<GeodesicPaintProjectedFace>() {
      public int compare(GeodesicPaintProjectedFace a,
        GeodesicPaintProjectedFace b) {
        return a.depth < b.depth ? -1 : (a.depth > b.depth ? 1 : 0);
      }
    });
  return result;
}

ArrayList<GeodesicPaintProjectedFace> geodesicPaintProjectionInPanel(
    GeodesicModel model, float x, float y, float w, float h,
    float rz, float rx, float padding) {
  ArrayList<GeodesicPaintProjectedFace> projected =
    geodesicPaintProjection(model, 0, 0, 1, rz, rx);
  if (projected.size() == 0) return projected;
  float minX = Float.POSITIVE_INFINITY;
  float minY = Float.POSITIVE_INFINITY;
  float maxX = Float.NEGATIVE_INFINITY;
  float maxY = Float.NEGATIVE_INFINITY;
  for (GeodesicPaintProjectedFace item : projected) {
    for (PVector point : item.points) {
      minX = min(minX, point.x);
      minY = min(minY, point.y);
      maxX = max(maxX, point.x);
      maxY = max(maxY, point.y);
    }
  }
  float spanX = max(0.0001f, maxX - minX);
  float spanY = max(0.0001f, maxY - minY);
  float fit = min(max(1, w - padding * 2) / spanX,
    max(1, h - padding * 2) / spanY);
  float midX = (minX + maxX) * 0.5f;
  float midY = (minY + maxY) * 0.5f;
  float centerX = x + w * 0.5f;
  float centerY = y + h * 0.5f;
  for (GeodesicPaintProjectedFace item : projected) {
    for (PVector point : item.points) {
      point.x = centerX + (point.x - midX) * fit;
      point.y = centerY - (point.y - midY) * fit;
    }
    item.labelClearance = geodesicPaintLabelClearance(item.points);
  }
  return projected;
}

float geodesicPaintLabelClearance(PVector[] points) {
  if (points == null || points.length < 3) return 0;
  float edgeAB = PVector.dist(points[0], points[1]);
  float edgeBC = PVector.dist(points[1], points[2]);
  float edgeCA = PVector.dist(points[2], points[0]);
  float longestEdge = max(edgeAB, max(edgeBC, edgeCA));
  float twiceArea = abs(
    (points[1].x - points[0].x) *
    (points[2].y - points[0].y) -
    (points[1].y - points[0].y) *
    (points[2].x - points[0].x));
  return longestEdge > 0.0001f ? twiceArea / longestEdge : 0;
}

void drawGeodesicPaintRasterView(PGraphics pg,
    GeodesicPaintPlan plan, float x, float y, float w, float h,
    String label, float rz, float rx, boolean showColorIds) {
  pg.noFill();
  pg.stroke(35);
  pg.strokeWeight(1.5f);
  pg.rect(x, y, w, h);
  pg.fill(10);
  pg.noStroke();
  pg.textAlign(LEFT, TOP);
  pg.textFont(createFont("Helvetica Bold",
    showColorIds ? 24 : 19, true));
  pg.text(label, x + 18, y + 14);
  ArrayList<GeodesicPaintProjectedFace> projected =
    geodesicPaintProjectionInPanel(geodesicModel,
      x + 8, y + 48, w - 16, h - 56, rz, rx,
      showColorIds ? 54 : 20);
  for (GeodesicPaintProjectedFace item : projected) {
    GeodesicPaintAssignment assignment =
      plan.forFace(item.face.id);
    int rgb = assignment == null ? color(180) : assignment.rgb;
    pg.fill(red(rgb), green(rgb), blue(rgb));
    pg.stroke(12);
    pg.strokeWeight(showColorIds ? 2.2f : 1.35f);
    pg.beginShape();
    for (PVector point : item.points) pg.vertex(point.x, point.y);
    pg.endShape(CLOSE);
  }
  if (showColorIds && geodesicModel.faces.size() <= 180) {
    for (GeodesicPaintProjectedFace item : projected) {
      GeodesicPaintAssignment assignment =
        plan.forFace(item.face.id);
      if (!item.frontFacing || item.labelClearance < 24.0f ||
          assignment == null) continue;
      float cx = (item.points[0].x + item.points[1].x +
        item.points[2].x) / 3.0f;
      float cy = (item.points[0].y + item.points[1].y +
        item.points[2].y) / 3.0f;
      pg.fill(0);
      pg.noStroke();
      pg.textFont(createFont("Helvetica Bold",
        max(11, 21 - geodesicModel.faces.size() / 18.0f), true));
      pg.textAlign(CENTER, CENTER);
      pg.text(assignment.colorId, cx, cy);
    }
  }
}

void renderGeodesicPaintGuideRaster(File file, GeodesicPaintPlan plan,
  String stamp) {
  int width = 3200;
  int height = 2200;
  PGraphics pg = createGraphics(width, height, JAVA2D);
  pg.beginDraw();
  pg.background(248);
  pg.smooth(4);
  pg.strokeJoin(MITER);
  pg.fill(10);
  pg.textFont(createFont("Helvetica Bold", 46, true));
  pg.textAlign(LEFT, TOP);
  pg.text("GEODESIC SALON - PANEL PAINT MAP", 80, 60);
  pg.textFont(createFont("Helvetica", 24, true));
  pg.text(plan.scheme.label() + "  |  " +
    plan.usedColorCount() + " USED / " +
    plan.effectiveColorCount + " AVAILABLE COLOR IDs  |  6 VIEWS  |  " +
    stamp, 84, 122);
  pg.noFill();
  pg.stroke(20);
  pg.strokeWeight(4);
  pg.rect(42, 42, width - 84, height - 84);
  pg.rect(80, 180, 2460, 1840);
  pg.rect(2580, 180, 540, 1840);

  drawGeodesicPaintRasterView(pg, plan,
    100, 200, 1440, 1800, "PRIMARY ISOMETRIC",
    0.62f, -0.58f, true);
  drawGeodesicPaintRasterView(pg, plan,
    1560, 200, 470, 570, "FRONT (-Y)",
    0, -HALF_PI, false);
  drawGeodesicPaintRasterView(pg, plan,
    2050, 200, 470, 570, "RIGHT (+X)",
    -HALF_PI, -HALF_PI, false);
  drawGeodesicPaintRasterView(pg, plan,
    1560, 790, 470, 570, "REAR (+Y)",
    PI, -HALF_PI, false);
  drawGeodesicPaintRasterView(pg, plan,
    2050, 790, 470, 570, "LEFT (-X)",
    HALF_PI, -HALF_PI, false);
  drawGeodesicPaintRasterView(pg, plan,
    1560, 1380, 960, 620, "TOP (+Z)",
    0, 0, false);

  pg.textAlign(LEFT, TOP);
  pg.textFont(createFont("Helvetica Bold", 30, true));
  pg.fill(10);
  pg.text("PRINT COLOR IDs / REQUIRED", 2620, 220);
  pg.textFont(createFont("Helvetica", 22, true));
  int y = 290;
  HashMap<Integer, Integer> quantities = plan.colorQuantities();
  ArrayList<Integer> usedIndices = plan.usedColorIndices();
  for (int i : usedIndices) {
    int rgb = geodesicPaintPaletteColor(i);
    pg.fill(red(rgb), green(rgb), blue(rgb));
    pg.stroke(0);
    pg.strokeWeight(2);
    pg.rect(2620, y, 90, 52);
    pg.fill(0);
    pg.noStroke();
    pg.text(geodesicPaintColorId(i) + "  " +
      geodesicPaintHex(rgb) + "  x" + quantities.get(i),
      2740, y + 11);
    y += 78;
  }
  pg.textFont(createFont("Helvetica Bold", 26, true));
  pg.text("FABRICATION", 2620, y + 20);
  pg.textFont(createFont("Helvetica", 20, true));
  pg.text("Use paint_schedule.csv for face-to-color identity.\n" +
    "Print batch STLs are grouped by C##.\n" +
    "Only the used color IDs are listed above.\n" +
    "Canonical uncolored parts remain in parts/.\n" +
    "Apply one material color per batch file.",
    2620, y + 72, 440, 360);
  PImage logo = fieldworksLogoImage();
  float logoX = 2630;
  float logoY = 1440;
  float logoW = 420;
  float logoH = 190;
  if (logo != null) {
    float logoScale = min(logoW / logo.width,
      logoH / logo.height);
    float drawW = logo.width * logoScale;
    float drawH = logo.height * logoScale;
    pg.image(logo, logoX + (logoW - drawW) * 0.5f,
      logoY + (logoH - drawH) * 0.5f, drawW, drawH);
  } else {
    pg.textFont(createFont("Helvetica Bold", 28, true));
    pg.textAlign(CENTER, CENTER);
    pg.text("FIELDWORKS MINDLAB", logoX + logoW * 0.5f,
      logoY + logoH * 0.5f);
    pg.textAlign(LEFT, TOP);
  }
  pg.textFont(createFont("Helvetica", 18, true));
  pg.text("Scheme " + plan.scheme.key() + "\nPhase " +
    nf(plan.phase, 1, 3) + "\nSeed " + plan.sourceSeed +
    "\nPanels " + plan.assignments.size() + "\nUsed colors " +
    plan.usedColorCount() + " / " + plan.effectiveColorCount +
    "\nModel " + plan.modelFingerprint, 2620, 1710);
  pg.endDraw();
  pg.save(file.getAbsolutePath());
}

void writeGeodesicPaintSvgView(PrintWriter out,
    GeodesicPaintPlan plan, String groupId,
    float x, float y, float w, float h, String label,
    float rz, float rx, boolean showColorIds) {
  out.println("<g id=\"" + groupId + "\">");
  out.println("<rect x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) +
    "\" width=\"" + svgNum(w) + "\" height=\"" + svgNum(h) +
    "\" fill=\"none\" stroke=\"#222\" stroke-width=\"0.25\"/>");
  out.println("<text x=\"" + svgNum(x + 3) + "\" y=\"" +
    svgNum(y + 5) + "\" font-family=\"Helvetica,Arial,sans-serif\" " +
    "font-size=\"3.4\" font-weight=\"700\">" +
    safeXml(label) + "</text>");
  ArrayList<GeodesicPaintProjectedFace> projected =
    geodesicPaintProjectionInPanel(geodesicModel,
      x + 1.5f, y + 7, w - 3, h - 8.5f, rz, rx,
      showColorIds ? 8 : 3);
  out.println("<g id=\"" + groupId + "-panels\">");
  for (GeodesicPaintProjectedFace item : projected) {
    GeodesicPaintAssignment assignment =
      plan.forFace(item.face.id);
    String points = "";
    for (int i = 0; i < item.points.length; i++)
      points += (i == 0 ? "" : " ") + svgNum(item.points[i].x) +
        "," + svgNum(item.points[i].y);
    out.println("<polygon data-face=\"" + item.face.id +
      "\" data-color-id=\"" +
      (assignment == null ? "" : assignment.colorId) +
      "\" points=\"" + points + "\" fill=\"" +
      (assignment == null ? "#b4b4b4" :
      geodesicPaintHex(assignment.rgb)) +
      "\" stroke=\"#111\" stroke-width=\"" +
      (showColorIds ? "0.28" : "0.18") + "\"/>");
  }
  out.println("</g>");
  if (showColorIds && geodesicModel.faces.size() <= 180) {
    out.println("<g id=\"" + groupId +
      "-color-id-labels\" fill=\"#000\" " +
      "font-family=\"Helvetica,Arial,sans-serif\" font-size=\"2.5\" " +
      "font-weight=\"700\" text-anchor=\"middle\" " +
      "dominant-baseline=\"central\">");
    for (GeodesicPaintProjectedFace item : projected) {
      GeodesicPaintAssignment assignment =
        plan.forFace(item.face.id);
      if (!item.frontFacing || item.labelClearance < 4.5f ||
          assignment == null) continue;
      float cx = (item.points[0].x + item.points[1].x +
        item.points[2].x) / 3.0f;
      float cy = (item.points[0].y + item.points[1].y +
        item.points[2].y) / 3.0f;
      out.println("<text x=\"" + svgNum(cx) + "\" y=\"" +
        svgNum(cy) + "\">" + assignment.colorId + "</text>");
    }
    out.println("</g>");
  }
  out.println("</g>");
}

void writeGeodesicPaintSvgLogo(PrintWriter out,
    float x, float y, float w, float h) {
  File logo = new File(sketchPath("data/" +
    FIELDWORKS_LOGO_FILE));
  if (!logo.exists()) {
    out.println("<text x=\"" + svgNum(x + w * 0.5f) +
      "\" y=\"" + svgNum(y + h * 0.5f) +
      "\" font-family=\"Helvetica,Arial,sans-serif\" " +
      "font-size=\"5\" font-weight=\"700\" " +
      "text-anchor=\"middle\" dominant-baseline=\"central\">" +
      "FIELDWORKS MINDLAB</text>");
    return;
  }
  try {
    byte[] bytes = java.nio.file.Files.readAllBytes(
      logo.toPath());
    String encoded = java.util.Base64.getEncoder()
      .encodeToString(bytes);
    String href = "data:image/png;base64," + encoded;
    out.println("<image href=\"" + href +
      "\" xlink:href=\"" + href + "\" x=\"" +
      svgNum(x) + "\" y=\"" + svgNum(y) +
      "\" width=\"" + svgNum(w) + "\" height=\"" +
      svgNum(h) +
      "\" preserveAspectRatio=\"xMidYMid meet\"/>");
  } catch (Exception error) {
    out.println("<text x=\"" + svgNum(x + w * 0.5f) +
      "\" y=\"" + svgNum(y + h * 0.5f) +
      "\" font-family=\"Helvetica,Arial,sans-serif\" " +
      "font-size=\"5\" font-weight=\"700\" " +
      "text-anchor=\"middle\" dominant-baseline=\"central\">" +
      "FIELDWORKS MINDLAB</text>");
  }
}

void renderGeodesicPaintGuideSvg(File file, GeodesicPaintPlan plan,
  String stamp) {
  PrintWriter out = createWriter(file.getAbsolutePath());
  out.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
  out.println("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 594 420\" width=\"594mm\" height=\"420mm\" role=\"img\" aria-label=\"Geodesic Salon panel paint map\">");
  out.println("<rect width=\"594\" height=\"420\" fill=\"#f8f8f8\"/>");
  out.println("<rect x=\"6\" y=\"6\" width=\"582\" height=\"408\" fill=\"none\" stroke=\"#000\" stroke-width=\"0.7\"/>");
  out.println("<text x=\"14\" y=\"14\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"8\" font-weight=\"700\">GEODESIC SALON - PANEL PAINT MAP</text>");
  out.println("<text x=\"14\" y=\"25\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"4.2\">" +
    safeXml(plan.scheme.label() + " | " +
    plan.usedColorCount() + " USED / " +
    plan.effectiveColorCount + " AVAILABLE COLOR IDs | 6 VIEWS | " +
    stamp) + "</text>");
  out.println("<rect x=\"14\" y=\"34\" width=\"450\" height=\"354\" fill=\"none\" stroke=\"#000\" stroke-width=\"0.35\"/>");
  out.println("<rect x=\"472\" y=\"34\" width=\"108\" height=\"354\" fill=\"none\" stroke=\"#000\" stroke-width=\"0.35\"/>");
  writeGeodesicPaintSvgView(out, plan, "primary-isometric",
    16, 36, 270, 350, "PRIMARY ISOMETRIC",
    0.62f, -0.58f, true);
  writeGeodesicPaintSvgView(out, plan, "front-view",
    290, 36, 83, 110, "FRONT (-Y)", 0, -HALF_PI, false);
  writeGeodesicPaintSvgView(out, plan, "right-view",
    377, 36, 83, 110, "RIGHT (+X)", -HALF_PI, -HALF_PI, false);
  writeGeodesicPaintSvgView(out, plan, "rear-view",
    290, 150, 83, 110, "REAR (+Y)", PI, -HALF_PI, false);
  writeGeodesicPaintSvgView(out, plan, "left-view",
    377, 150, 83, 110, "LEFT (-X)", HALF_PI, -HALF_PI, false);
  writeGeodesicPaintSvgView(out, plan, "top-view",
    290, 264, 170, 122, "TOP (+Z)", 0, 0, false);
  out.println("<g id=\"legend\" font-family=\"Helvetica,Arial,sans-serif\">");
  out.println("<text x=\"480\" y=\"44\" font-size=\"5\" font-weight=\"700\">PRINT COLOR IDs / REQUIRED</text>");
  float y = 54;
  HashMap<Integer, Integer> quantities = plan.colorQuantities();
  ArrayList<Integer> usedIndices = plan.usedColorIndices();
  for (int i : usedIndices) {
    int rgb = geodesicPaintPaletteColor(i);
    out.println("<rect x=\"480\" y=\"" + svgNum(y) +
      "\" width=\"18\" height=\"9\" fill=\"" +
      geodesicPaintHex(rgb) + "\" stroke=\"#000\" stroke-width=\"0.25\"/>");
    out.println("<text x=\"502\" y=\"" + svgNum(y + 1.3f) +
      "\" font-size=\"3.6\">" + geodesicPaintColorId(i) + " " +
      geodesicPaintHex(rgb) + " x" + quantities.get(i) + "</text>");
    y += 14;
  }
  out.println("<text x=\"480\" y=\"" + svgNum(y + 8) +
    "\" font-size=\"4.2\" font-weight=\"700\">FABRICATION</text>");
  out.println("<text x=\"480\" y=\"" + svgNum(y + 16) +
    "\" font-size=\"3.4\">Use paint_schedule.csv.</text>");
  out.println("<text x=\"480\" y=\"" + svgNum(y + 22) +
    "\" font-size=\"3.4\">Batch STLs are grouped by C##.</text>");
  out.println("<text x=\"480\" y=\"" + svgNum(y + 28) +
    "\" font-size=\"3.4\">Only used color IDs are listed.</text>");
  writeGeodesicPaintSvgLogo(out, 480, 286, 92, 46);
  out.println("</g>");
  out.println("</svg>");
  out.flush();
  out.close();
}
