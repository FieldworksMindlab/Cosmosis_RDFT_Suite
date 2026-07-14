/* DCRTE-ET Milestone 2.5 staged imported-domain qualification data model. */

enum DomainQualification {
  NOT_LOADED,
  PARSE_FAILED,
  PREVIEW_ONLY,
  TOPOLOGY_INVALID,
  TOPOLOGY_VALID_SDF_UNRESOLVED,
  SDF_VALID_MATERIALIZATION_BLOCKED,
  MATERIALIZATION_READY;

  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum DiagnosticSeverity {
  INFO,
  WARNING,
  BLOCKER;

  String id() { return name().toLowerCase(); }
}

enum SanitationPolicy {
  NONE,
  SAFE_AUTOMATIC,
  SAFE_WITH_CONFIRMATION;

  String id() { return name().toLowerCase(); }
}

enum DCRTEPreflightStageState {
  NOT_RUN,
  PASS,
  WARNING,
  BLOCKED,
  SKIPPED;

  String id() { return name().toLowerCase(); }
}

class DCRTEPreflightCodes {
  static final String PF_FILE_NOT_FOUND = "PF_FILE_NOT_FOUND";
  static final String PF_FILE_UNREADABLE = "PF_FILE_UNREADABLE";
  static final String PF_FILE_EMPTY = "PF_FILE_EMPTY";
  static final String PF_FORMAT_UNSUPPORTED = "PF_FORMAT_UNSUPPORTED";
  static final String PF_STL_FORMAT_AMBIGUOUS = "PF_STL_FORMAT_AMBIGUOUS";
  static final String PF_BINARY_LENGTH_MISMATCH = "PF_BINARY_LENGTH_MISMATCH";
  static final String PF_ASCII_PARSE_INCOMPLETE = "PF_ASCII_PARSE_INCOMPLETE";
  static final String PF_TRIANGLE_LIMIT_EXCEEDED = "PF_TRIANGLE_LIMIT_EXCEEDED";
  static final String PF_SOURCE_COORDINATE_NONFINITE = "PF_SOURCE_COORDINATE_NONFINITE";
  static final String PF_SOURCE_UNITS_UNSPECIFIED = "PF_SOURCE_UNITS_UNSPECIFIED";
  static final String PF_SOURCE_SCALE_EXTREME = "PF_SOURCE_SCALE_EXTREME";
  static final String PF_SOURCE_HASH_FAILURE = "PF_SOURCE_HASH_FAILURE";

  static final String PF_ZERO_AREA_TRIANGLES = "PF_ZERO_AREA_TRIANGLES";
  static final String PF_NEAR_ZERO_AREA_TRIANGLES = "PF_NEAR_ZERO_AREA_TRIANGLES";
  static final String PF_INVALID_TRIANGLE_INDICES = "PF_INVALID_TRIANGLE_INDICES";
  static final String PF_DUPLICATE_TRIANGLES = "PF_DUPLICATE_TRIANGLES";
  static final String PF_COPLANAR_DUPLICATE_FACES = "PF_COPLANAR_DUPLICATE_FACES";
  static final String PF_DUPLICATE_VERTICES = "PF_DUPLICATE_VERTICES";
  static final String PF_NEAR_DUPLICATE_VERTICES = "PF_NEAR_DUPLICATE_VERTICES";
  static final String PF_ISOLATED_VERTICES = "PF_ISOLATED_VERTICES";
  static final String PF_INVALID_BOUNDS = "PF_INVALID_BOUNDS";
  static final String PF_ZERO_VOLUME_BOUNDS = "PF_ZERO_VOLUME_BOUNDS";
  static final String PF_EXTREME_ASPECT_RATIO = "PF_EXTREME_ASPECT_RATIO";

  static final String PF_BOUNDARY_EDGES = "PF_BOUNDARY_EDGES";
  static final String PF_BOUNDARY_LOOPS = "PF_BOUNDARY_LOOPS";
  static final String PF_BOUNDARY_LOOP_LARGE = "PF_BOUNDARY_LOOP_LARGE";
  static final String PF_BOUNDARY_LOOP_SMALL = "PF_BOUNDARY_LOOP_SMALL";
  static final String PF_NONMANIFOLD_EDGES = "PF_NONMANIFOLD_EDGES";
  static final String PF_NONMANIFOLD_VERTICES = "PF_NONMANIFOLD_VERTICES";
  static final String PF_BOWTIE_VERTICES = "PF_BOWTIE_VERTICES";
  static final String PF_T_JUNCTION_CANDIDATES = "PF_T_JUNCTION_CANDIDATES";
  static final String PF_DISCONNECTED_COMPONENTS = "PF_DISCONNECTED_COMPONENTS";
  static final String PF_TINY_DISCONNECTED_COMPONENTS = "PF_TINY_DISCONNECTED_COMPONENTS";
  static final String PF_OPEN_COMPONENTS = "PF_OPEN_COMPONENTS";
  static final String PF_CLOSED_COMPONENTS_MULTIPLE = "PF_CLOSED_COMPONENTS_MULTIPLE";
  static final String PF_NESTED_SHELLS = "PF_NESTED_SHELLS";
  static final String PF_INTERNAL_SHELL_CANDIDATE = "PF_INTERNAL_SHELL_CANDIDATE";
  static final String PF_COMPONENT_CONTACT_OR_OVERLAP = "PF_COMPONENT_CONTACT_OR_OVERLAP";

  static final String PF_INCONSISTENT_EDGE_WINDING = "PF_INCONSISTENT_EDGE_WINDING";
  static final String PF_COMPONENT_WINDING_INCONSISTENT = "PF_COMPONENT_WINDING_INCONSISTENT";
  static final String PF_GLOBAL_WINDING_INVERTED = "PF_GLOBAL_WINDING_INVERTED";
  static final String PF_COMPONENT_WINDING_INVERTED = "PF_COMPONENT_WINDING_INVERTED";
  static final String PF_SIGNED_VOLUME_NEAR_ZERO = "PF_SIGNED_VOLUME_NEAR_ZERO";
  static final String PF_SIGNED_VOLUME_CONFLICT = "PF_SIGNED_VOLUME_CONFLICT";
  static final String PF_NORMAL_FIELD_UNRELIABLE = "PF_NORMAL_FIELD_UNRELIABLE";

  static final String PF_SELF_INTERSECTION = "PF_SELF_INTERSECTION";
  static final String PF_SELF_INTERSECTION_SUSPECTED = "PF_SELF_INTERSECTION_SUSPECTED";
  static final String PF_TRIANGLE_OVERLAP = "PF_TRIANGLE_OVERLAP";
  static final String PF_COPLANAR_OVERLAP = "PF_COPLANAR_OVERLAP";
  static final String PF_COMPONENT_INTERSECTION = "PF_COMPONENT_INTERSECTION";
  static final String PF_INTERNAL_FACE_CANDIDATE = "PF_INTERNAL_FACE_CANDIDATE";

  static final String PF_TRANSFORM_INVALID = "PF_TRANSFORM_INVALID";
  static final String PF_TRANSFORM_NONINVERTIBLE = "PF_TRANSFORM_NONINVERTIBLE";
  static final String PF_TRANSFORM_OUTSIDE_OBSERVER = "PF_TRANSFORM_OUTSIDE_OBSERVER";
  static final String PF_TRANSFORM_MARGIN_TOO_SMALL = "PF_TRANSFORM_MARGIN_TOO_SMALL";
  static final String PF_TRANSFORM_CLIPPING = "PF_TRANSFORM_CLIPPING";
  static final String PF_TRANSFORM_ASPECT_PRESERVATION_FAILURE = "PF_TRANSFORM_ASPECT_PRESERVATION_FAILURE";
  static final String PF_ROTATION_STATE_INVALID = "PF_ROTATION_STATE_INVALID";
  static final String PF_SOURCE_TO_WORLD_PRECISION_LOSS = "PF_SOURCE_TO_WORLD_PRECISION_LOSS";

  static final String PF_VOXEL_RESOLUTION_TOO_LOW = "PF_VOXEL_RESOLUTION_TOO_LOW";
  static final String PF_FEATURE_BELOW_ONE_VOXEL = "PF_FEATURE_BELOW_ONE_VOXEL";
  static final String PF_FEATURE_BELOW_TWO_VOXELS = "PF_FEATURE_BELOW_TWO_VOXELS";
  static final String PF_THIN_WALL_UNRESOLVED = "PF_THIN_WALL_UNRESOLVED";
  static final String PF_NARROW_CHANNEL_UNRESOLVED = "PF_NARROW_CHANNEL_UNRESOLVED";
  static final String PF_COMPONENT_DISAPPEARS_AT_RESOLUTION = "PF_COMPONENT_DISAPPEARS_AT_RESOLUTION";
  static final String PF_BOUNDARY_ALIASING_HIGH = "PF_BOUNDARY_ALIASING_HIGH";
  static final String PF_RESOLUTION_CONVERGENCE_POOR = "PF_RESOLUTION_CONVERGENCE_POOR";
  static final String PF_GRID_MEMORY_LIMIT = "PF_GRID_MEMORY_LIMIT";
  static final String PF_GRID_TIME_LIMIT = "PF_GRID_TIME_LIMIT";

  static final String PF_BOUNDARY_VOXELIZATION_EMPTY = "PF_BOUNDARY_VOXELIZATION_EMPTY";
  static final String PF_TRIANGLE_MARKED_NO_VOXELS = "PF_TRIANGLE_MARKED_NO_VOXELS";
  static final String PF_BOUNDARY_COVERAGE_GAPS = "PF_BOUNDARY_COVERAGE_GAPS";
  static final String PF_BOUNDARY_THICKNESS_EXCESSIVE = "PF_BOUNDARY_THICKNESS_EXCESSIVE";
  static final String PF_BOUNDARY_FRAGMENTED = "PF_BOUNDARY_FRAGMENTED";
  static final String PF_BOUNDARY_COMPONENT_MISMATCH = "PF_BOUNDARY_COMPONENT_MISMATCH";
  static final String PF_BOUNDARY_TOUCHES_GRID_EDGE = "PF_BOUNDARY_TOUCHES_GRID_EDGE";
  static final String PF_BOUNDARY_VOXEL_COUNT_IMPLAUSIBLE = "PF_BOUNDARY_VOXEL_COUNT_IMPLAUSIBLE";

  static final String PF_PARITY_ODD_INTERSECTION_COUNT = "PF_PARITY_ODD_INTERSECTION_COUNT";
  static final String PF_PARITY_RETRY_REQUIRED = "PF_PARITY_RETRY_REQUIRED";
  static final String PF_PARITY_RETRY_FAILED = "PF_PARITY_RETRY_FAILED";
  static final String PF_PARITY_INCONSISTENT_AXIS = "PF_PARITY_INCONSISTENT_AXIS";
  static final String PF_INSIDE_MASK_EMPTY = "PF_INSIDE_MASK_EMPTY";
  static final String PF_INSIDE_MASK_FULL = "PF_INSIDE_MASK_FULL";
  static final String PF_INSIDE_COMPONENT_MISMATCH = "PF_INSIDE_COMPONENT_MISMATCH";
  static final String PF_INTERIOR_LEAK = "PF_INTERIOR_LEAK";
  static final String PF_EXTERIOR_POCKET = "PF_EXTERIOR_POCKET";
  static final String PF_SIGN_ISLAND = "PF_SIGN_ISLAND";
  static final String PF_AMBIGUOUS_VOXELS = "PF_AMBIGUOUS_VOXELS";

  static final String PF_SDF_NONFINITE = "PF_SDF_NONFINITE";
  static final String PF_SDF_SIGN_CONFLICT = "PF_SDF_SIGN_CONFLICT";
  static final String PF_SDF_ZERO_BAND_EMPTY = "PF_SDF_ZERO_BAND_EMPTY";
  static final String PF_SDF_ZERO_BAND_EXCESSIVE = "PF_SDF_ZERO_BAND_EXCESSIVE";
  static final String PF_SDF_GRADIENT_INVALID = "PF_SDF_GRADIENT_INVALID";
  static final String PF_SDF_GRADIENT_DIRECTION_CONFLICT = "PF_SDF_GRADIENT_DIRECTION_CONFLICT";
  static final String PF_SDF_DISTANCE_NONMONOTONIC = "PF_SDF_DISTANCE_NONMONOTONIC";
  static final String PF_SDF_VOLUME_ERROR_HIGH = "PF_SDF_VOLUME_ERROR_HIGH";
  static final String PF_SDF_RESOLUTION_INSTABILITY = "PF_SDF_RESOLUTION_INSTABILITY";
  static final String PF_SDF_GRID_MISMATCH = "PF_SDF_GRID_MISMATCH";

  static final String PF_FIELD_NONFINITE = "PF_FIELD_NONFINITE";
  static final String PF_FINAL_VOLUME_EMPTY = "PF_FINAL_VOLUME_EMPTY";
  static final String PF_FINAL_VOLUME_FULL = "PF_FINAL_VOLUME_FULL";
  static final String PF_OUTSIDE_DOMAIN_MATERIAL = "PF_OUTSIDE_DOMAIN_MATERIAL";
  static final String PF_FINAL_COMPONENTS_EXCESSIVE = "PF_FINAL_COMPONENTS_EXCESSIVE";
  static final String PF_FINAL_COMPONENT_TOO_SMALL = "PF_FINAL_COMPONENT_TOO_SMALL";
  static final String PF_MINIMUM_FEATURE_UNPRINTABLE = "PF_MINIMUM_FEATURE_UNPRINTABLE";
  static final String PF_RAISED_VEIN_DOMAIN_ESCAPE = "PF_RAISED_VEIN_DOMAIN_ESCAPE";
  static final String PF_MATERIALIZER_FAILURE = "PF_MATERIALIZER_FAILURE";
  static final String PF_EXPORT_DISABLED = "PF_EXPORT_DISABLED";
}

class DCRTEPreflightActions {
  static final String ACTION_REEXPORT_WATERTIGHT = "ACTION_REEXPORT_WATERTIGHT";
  static final String ACTION_CLOSE_BOUNDARY_LOOPS = "ACTION_CLOSE_BOUNDARY_LOOPS";
  static final String ACTION_REMOVE_NONMANIFOLD_GEOMETRY = "ACTION_REMOVE_NONMANIFOLD_GEOMETRY";
  static final String ACTION_UNIFY_NORMALS = "ACTION_UNIFY_NORMALS";
  static final String ACTION_REMOVE_INTERNAL_FACES = "ACTION_REMOVE_INTERNAL_FACES";
  static final String ACTION_SEPARATE_INTERSECTING_SHELLS = "ACTION_SEPARATE_INTERSECTING_SHELLS";
  static final String ACTION_BOOLEAN_UNION_COMPONENTS = "ACTION_BOOLEAN_UNION_COMPONENTS";
  static final String ACTION_DELETE_TINY_COMPONENTS = "ACTION_DELETE_TINY_COMPONENTS";
  static final String ACTION_INCREASE_SDF_RESOLUTION = "ACTION_INCREASE_SDF_RESOLUTION";
  static final String ACTION_INCREASE_SOURCE_MESH_QUALITY = "ACTION_INCREASE_SOURCE_MESH_QUALITY";
  static final String ACTION_REDUCE_DOMAIN_SCALE_MARGIN = "ACTION_REDUCE_DOMAIN_SCALE_MARGIN";
  static final String ACTION_REORIENT_DOMAIN = "ACTION_REORIENT_DOMAIN";
  static final String ACTION_SIMPLIFY_SOURCE_MESH = "ACTION_SIMPLIFY_SOURCE_MESH";
  static final String ACTION_INSPECT_SELF_INTERSECTIONS = "ACTION_INSPECT_SELF_INTERSECTIONS";
  static final String ACTION_USE_UNSIGNED_PREVIEW = "ACTION_USE_UNSIGNED_PREVIEW";
  static final String ACTION_ADJUST_FIELD_THRESHOLD = "ACTION_ADJUST_FIELD_THRESHOLD";
  static final String ACTION_ADJUST_SHELL_THICKNESS = "ACTION_ADJUST_SHELL_THICKNESS";
  static final String ACTION_DISABLE_RAISED_VEINS = "ACTION_DISABLE_RAISED_VEINS";
  static final String ACTION_RETRY_WITH_CANONICAL_FIXTURE = "ACTION_RETRY_WITH_CANONICAL_FIXTURE";
}

class DomainDiagnostic {
  String code;
  DiagnosticSeverity severity;
  String stage;
  String title;
  String message;
  String recommendedAction;
  int count = -1;
  float value = Float.NaN;
  float threshold = Float.NaN;
  int triangleIndex = -1;
  int secondaryTriangleIndex = -1;
  int edgeVertexA = -1;
  int edgeVertexB = -1;
  int voxelIndex = -1;
  float worldX;
  float worldY;
  float worldZ;
  boolean hasLocation;
  boolean isAutoSanitizable;
  boolean requiresTopologyChange;

  DomainDiagnostic(String code, DiagnosticSeverity severity, String stage,
      String title, String message, String recommendedAction) {
    this.code = code;
    this.severity = severity;
    this.stage = stage;
    this.title = title;
    this.message = message;
    this.recommendedAction = recommendedAction;
  }

  DomainDiagnostic withCount(int count) { this.count = count; return this; }
  DomainDiagnostic withValue(float value, float threshold) { this.value = value; this.threshold = threshold; return this; }
  DomainDiagnostic withTriangle(int triangleIndex) { this.triangleIndex = triangleIndex; return this; }
  DomainDiagnostic withTrianglePair(int a, int b) { this.triangleIndex = a; this.secondaryTriangleIndex = b; return this; }
  DomainDiagnostic withEdge(int a, int b) { this.edgeVertexA = a; this.edgeVertexB = b; return this; }
  DomainDiagnostic withVoxel(int voxelIndex) { this.voxelIndex = voxelIndex; return this; }
  DomainDiagnostic at(float x, float y, float z) {
    worldX = x; worldY = y; worldZ = z; hasLocation = true; return this;
  }
  DomainDiagnostic sanitizable(boolean value) { isAutoSanitizable = value; return this; }
  DomainDiagnostic topologyChange(boolean value) { requiresTopologyChange = value; return this; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("code", code == null ? "" : code);
    json.setString("severity", severity == null ? "info" : severity.id());
    json.setString("stage", stage == null ? "" : stage.toLowerCase());
    json.setString("title", title == null ? "" : title);
    json.setString("message", message == null ? "" : message);
    json.setString("recommended_action", recommendedAction == null ? "" : recommendedAction);
    if (count >= 0) json.setInt("count", count);
    if (dcrteFinite(value)) json.setFloat("value", value);
    if (dcrteFinite(threshold)) json.setFloat("threshold", threshold);
    if (triangleIndex >= 0) json.setInt("triangle_index", triangleIndex);
    if (secondaryTriangleIndex >= 0) json.setInt("secondary_triangle_index", secondaryTriangleIndex);
    if (edgeVertexA >= 0) json.setInt("edge_vertex_a", edgeVertexA);
    if (edgeVertexB >= 0) json.setInt("edge_vertex_b", edgeVertexB);
    if (voxelIndex >= 0) json.setInt("voxel_index", voxelIndex);
    json.setBoolean("has_location", hasLocation);
    if (hasLocation) {
      JSONArray location = new JSONArray();
      location.setFloat(0, worldX); location.setFloat(1, worldY); location.setFloat(2, worldZ);
      json.setJSONArray("world_location", location);
    }
    json.setBoolean("auto_sanitizable", isAutoSanitizable);
    json.setBoolean("requires_topology_change", requiresTopologyChange);
    return json;
  }
}

class DCRTEPreflightStageRecord {
  String stage;
  DCRTEPreflightStageState state = DCRTEPreflightStageState.NOT_RUN;
  String reason = "";
  long elapsedMillis;

  DCRTEPreflightStageRecord(String stage) { this.stage = stage; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("stage", stage.toLowerCase());
    json.setString("state", state.id());
    json.setString("reason", reason == null ? "" : reason);
    json.setLong("elapsed_millis", elapsedMillis);
    return json;
  }
}

class MeshBoundaryLoopReport {
  int loopIndex;
  int[] vertexIndices = new int[0];
  int edgeCount;
  float perimeter;
  Bounds3D worldBounds;
  float centerX;
  float centerY;
  float centerZ;
  boolean closed;
  boolean largest;
  boolean smallest;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("loop_index", loopIndex);
    json.setInt("edge_count", edgeCount);
    json.setFloat("perimeter", perimeter);
    json.setBoolean("closed", closed);
    json.setBoolean("largest", largest);
    json.setBoolean("smallest", smallest);
    JSONArray center = new JSONArray();
    center.setFloat(0, centerX); center.setFloat(1, centerY); center.setFloat(2, centerZ);
    json.setJSONArray("centroid_world", center);
    if (worldBounds != null) json.setJSONObject("bounds_world", worldBounds.toJSON());
    return json;
  }
}

class MeshComponentReport {
  int componentIndex;
  int[] triangleIndices = new int[0];
  int triangleCount;
  int vertexCount;
  int boundaryEdgeCount;
  int nonManifoldEdgeCount;
  float surfaceArea;
  double signedVolume;
  double absoluteVolume;
  float surfaceAreaFraction;
  float volumeFraction;
  Bounds3D worldBounds;
  boolean closed;
  boolean isOpen;
  boolean consistentlyOriented;
  boolean tiny;
  boolean nested;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("component_index", componentIndex);
    json.setInt("triangle_count", triangleCount);
    json.setInt("vertex_count", vertexCount);
    json.setInt("boundary_edge_count", boundaryEdgeCount);
    json.setInt("nonmanifold_edge_count", nonManifoldEdgeCount);
    json.setFloat("surface_area", surfaceArea);
    json.setDouble("signed_volume", signedVolume);
    json.setDouble("absolute_volume", absoluteVolume);
    json.setFloat("surface_area_fraction", surfaceAreaFraction);
    json.setFloat("volume_fraction", volumeFraction);
    json.setBoolean("closed", closed);
    json.setBoolean("open", isOpen);
    json.setBoolean("consistently_oriented", consistentlyOriented);
    json.setBoolean("tiny", tiny);
    json.setBoolean("nested", nested);
    if (worldBounds != null) json.setJSONObject("bounds_world", worldBounds.toJSON());
    return json;
  }
}

class SelfIntersectionReport {
  int candidatePairCount;
  int testedPairCount;
  int confirmedIntersectionCount;
  int coplanarOverlapCount;
  int skippedAdjacentPairCount;
  boolean candidateLimitReached;
  int[] triangleA = new int[0];
  int[] triangleB = new int[0];
  float[] worldLocations = new float[0];
  long elapsedMillis;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("candidate_pair_count", candidatePairCount);
    json.setInt("tested_pair_count", testedPairCount);
    json.setInt("confirmed_intersection_count", confirmedIntersectionCount);
    json.setInt("coplanar_overlap_count", coplanarOverlapCount);
    json.setInt("skipped_adjacent_pair_count", skippedAdjacentPairCount);
    json.setBoolean("candidate_limit_reached", candidateLimitReached);
    json.setLong("elapsed_millis", elapsedMillis);
    JSONArray examples = new JSONArray();
    int count = min(triangleA.length, triangleB.length);
    for (int i = 0; i < count; i++) {
      JSONObject example = new JSONObject();
      example.setInt("triangle_a", triangleA[i]);
      example.setInt("triangle_b", triangleB[i]);
      if (i * 3 + 2 < worldLocations.length) {
        JSONArray location = new JSONArray();
        location.setFloat(0, worldLocations[i * 3]);
        location.setFloat(1, worldLocations[i * 3 + 1]);
        location.setFloat(2, worldLocations[i * 3 + 2]);
        example.setJSONArray("world_location", location);
      }
      examples.setJSONObject(i, example);
    }
    json.setJSONArray("representative_intersections", examples);
    return json;
  }
}

class ResolutionSuitability {
  float voxelSpacing;
  float meshDiagonal;
  float minimumEdge;
  float edgeP05;
  float medianEdge;
  float minimumTriangleAltitude;
  float triangleAltitudeP05;
  float boundaryCoverageRatio = -1;
  float estimatedMinimumResolvedWall;
  float estimatedMinimumResolvedChannel;
  float estimatedConfidence;
  int recommendedMinimumResolution;
  ArrayList<String> reasons = new ArrayList<String>();

  String label() {
    if (estimatedConfidence < 0.38f) return "LOW CONFIDENCE";
    if (estimatedConfidence < 0.70f) return "ACCEPTABLE";
    return "RECOMMENDED";
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("voxel_spacing", voxelSpacing);
    json.setFloat("mesh_diagonal", meshDiagonal);
    json.setFloat("minimum_source_edge_risk_indicator", minimumEdge);
    json.setFloat("edge_p05_risk_indicator", edgeP05);
    json.setFloat("median_source_edge_risk_indicator", medianEdge);
    json.setFloat("minimum_triangle_altitude_risk_indicator", minimumTriangleAltitude);
    json.setFloat("triangle_altitude_p05_risk_indicator", triangleAltitudeP05);
    json.setFloat("boundary_coverage_ratio", boundaryCoverageRatio);
    json.setFloat("estimated_minimum_resolved_wall", estimatedMinimumResolvedWall);
    json.setFloat("estimated_minimum_resolved_channel", estimatedMinimumResolvedChannel);
    json.setFloat("estimated_confidence", estimatedConfidence);
    json.setString("confidence_label", label().toLowerCase().replace(' ', '_'));
    json.setInt("recommended_minimum_resolution", recommendedMinimumResolution);
    json.setJSONArray("reasons", dcrteStringListJSON(reasons));
    return json;
  }
}

class InsideOutsideVerification {
  int parityInsideCount;
  int floodFillInsideCount;
  int floodFillExteriorCount;
  int disagreementVoxelCount;
  int largestDisagreementComponent;
  int crossAxisCheckedVoxelCount;
  int crossAxisDisagreementCount;
  int insideComponentCount;
  int largestInsideComponent;
  float largestInsideComponentFraction;
  int boundaryComponentCount;
  int[] disagreementVoxelIndices = new int[0];
  int[] crossAxisDisagreementVoxelIndices = new int[0];
  long elapsedMillis;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("parity_inside_count", parityInsideCount);
    json.setInt("flood_fill_inside_count", floodFillInsideCount);
    json.setInt("flood_fill_exterior_count", floodFillExteriorCount);
    json.setInt("disagreement_voxel_count", disagreementVoxelCount);
    json.setInt("largest_disagreement_component", largestDisagreementComponent);
    json.setInt("cross_axis_checked_voxel_count", crossAxisCheckedVoxelCount);
    json.setInt("cross_axis_disagreement_count", crossAxisDisagreementCount);
    json.setInt("inside_component_count", insideComponentCount);
    json.setInt("largest_inside_component", largestInsideComponent);
    json.setFloat("largest_inside_component_fraction", largestInsideComponentFraction);
    json.setInt("boundary_component_count", boundaryComponentCount);
    json.setLong("elapsed_millis", elapsedMillis);
    return json;
  }
}

class DomainPreflightReport {
  String reportVersion = "1.0-m2.5";
  DomainQualification qualification = DomainQualification.NOT_LOADED;
  ValidationStatus status = ValidationStatus.PASS;
  String sourceName = "";
  String sourceHashSha256 = "";
  String referenceCaseId = "";
  int selectedResolution;
  SanitationPolicy sanitationPolicy = SanitationPolicy.SAFE_AUTOMATIC;
  ArrayList<DomainDiagnostic> diagnostics = new ArrayList<DomainDiagnostic>();
  ArrayList<String> blockers = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();
  ArrayList<String> information = new ArrayList<String>();
  ArrayList<DCRTEPreflightStageRecord> stages = new ArrayList<DCRTEPreflightStageRecord>();
  ArrayList<MeshBoundaryLoopReport> boundaryLoops = new ArrayList<MeshBoundaryLoopReport>();
  ArrayList<MeshComponentReport> components = new ArrayList<MeshComponentReport>();
  MeshDomainReport meshReport;
  ResolutionSuitability resolutionSuitability;
  SDFQualityReport sdfReport;
  DCRTEValidationReport materializationReport;
  SelfIntersectionReport selfIntersectionReport;
  InsideOutsideVerification insideOutsideVerification;
  String firstBlockingStage = "";
  String firstBlockingCode = "";
  String recommendedNextAction = "";
  boolean previewEnabled;
  boolean sdfBuildEnabled;
  boolean materializationEnabled;
  boolean exportEnabled;
  boolean reportStale;
  int nonManifoldVertexCount;
  int bowtieVertexCount;
  int[] nonManifoldVertexIndices = new int[0];
  int[] bowtieVertexIndices = new int[0];
  int componentCount;
  int nestedShellCount;
  int openComponentCount;
  int closedComponentCount;
  boolean singleDominantClosedComponent;
  float dominantComponentFraction;
  float elongationRatio;
  float principalAxisConfidence;
  int insideMaskComponentCount;
  float insideMaskDominantFraction;
  float sdfResolutionConfidence;
  boolean thinFeatureRisk;
  String nestedShellStatus = "not_evaluated";
  String selfIntersectionStatus = "not_evaluated";
  long totalMillis;

  DomainPreflightReport() {
    String[] names = dcrtePreflightStageNames();
    for (int i = 0; i < names.length; i++) stages.add(new DCRTEPreflightStageRecord(names[i]));
  }

  void setStage(String stage, DCRTEPreflightStageState state, String reason, long elapsedMillis) {
    DCRTEPreflightStageRecord entry = stageRecord(stage);
    if (entry == null) return;
    entry.state = state;
    entry.reason = reason == null ? "" : reason;
    entry.elapsedMillis = elapsedMillis;
  }

  DCRTEPreflightStageRecord stageRecord(String stage) {
    for (int i = 0; i < stages.size(); i++) if (stages.get(i).stage.equals(stage)) return stages.get(i);
    return null;
  }

  void addDiagnostic(DomainDiagnostic diagnostic) {
    if (diagnostic == null) return;
    diagnostics.add(diagnostic);
    if (diagnostic.severity == DiagnosticSeverity.BLOCKER) {
      if (!blockers.contains(diagnostic.code)) blockers.add(diagnostic.code);
      status = ValidationStatus.FAIL;
    } else if (diagnostic.severity == DiagnosticSeverity.WARNING) {
      if (!warnings.contains(diagnostic.code)) warnings.add(diagnostic.code);
      if (status != ValidationStatus.FAIL) status = ValidationStatus.PASS_WITH_WARNINGS;
    } else if (!information.contains(diagnostic.code)) information.add(diagnostic.code);
  }

  boolean hasDiagnostic(String code) {
    for (int i = 0; i < diagnostics.size(); i++) if (code.equals(diagnostics.get(i).code)) return true;
    return false;
  }

  boolean hasBlockerAtOrBefore(String stage) {
    int limit = dcrtePreflightStageIndex(stage);
    for (int i = 0; i < diagnostics.size(); i++) {
      DomainDiagnostic diagnostic = diagnostics.get(i);
      if (diagnostic.severity == DiagnosticSeverity.BLOCKER
          && dcrtePreflightStageIndex(diagnostic.stage) <= limit) return true;
    }
    return false;
  }

  void refreshSummary() {
    firstBlockingStage = "";
    firstBlockingCode = "";
    recommendedNextAction = "";
    int bestStage = Integer.MAX_VALUE;
    for (int i = 0; i < diagnostics.size(); i++) {
      DomainDiagnostic diagnostic = diagnostics.get(i);
      if (diagnostic.severity != DiagnosticSeverity.BLOCKER) continue;
      int stageIndex = dcrtePreflightStageIndex(diagnostic.stage);
      if (stageIndex < bestStage) {
        bestStage = stageIndex;
        firstBlockingStage = diagnostic.stage;
        firstBlockingCode = diagnostic.code;
        recommendedNextAction = diagnostic.recommendedAction;
      }
    }
    if (recommendedNextAction == null) recommendedNextAction = "";
  }

  String conciseSummary() {
    StringBuilder summary = new StringBuilder();
    summary.append("DOMAIN QUALIFICATION  ").append(qualification.label()).append('\n');
    summary.append("FIRST BLOCKER         ").append(firstBlockingCode.length() == 0 ? "NONE" : firstBlockingCode).append('\n');
    summary.append("BOUNDARY EDGES        ").append(meshReport == null ? 0 : meshReport.boundaryEdgeCount).append('\n');
    summary.append("BOUNDARY LOOPS        ").append(boundaryLoops.size()).append('\n');
    summary.append("NONMANIFOLD EDGES     ").append(meshReport == null ? 0 : meshReport.nonManifoldEdgeCount).append('\n');
    summary.append("NONMANIFOLD VERTICES  ").append(nonManifoldVertexCount).append('\n');
    summary.append("COMPONENTS            ").append(componentCount).append('\n');
    summary.append("SELF INTERSECTIONS    ").append(selfIntersectionReport == null ? 0 : selfIntersectionReport.confirmedIntersectionCount).append(" CONFIRMED\n");
    summary.append("SDF RESOLUTION        ").append(selectedResolution).append("^3 ")
      .append(resolutionSuitability == null ? "NOT EVALUATED" : resolutionSuitability.label()).append('\n');
    summary.append("SDF BUILD             ").append(sdfBuildEnabled ? "ENABLED" : "DISABLED").append('\n');
    summary.append("MATERIALIZATION       ").append(materializationEnabled ? "ENABLED" : "DISABLED").append('\n');
    summary.append("EXPORT                ").append(exportEnabled ? "ENABLED" : "DISABLED").append('\n');
    summary.append("RECOMMENDED ACTION    ").append(recommendedNextAction.length() == 0 ? "NONE" : recommendedNextAction);
    return summary.toString();
  }

  JSONObject toJSON() {
    refreshSummary();
    JSONObject json = new JSONObject();
    json.setString("report_version", reportVersion);
    json.setString("qualification", qualification.id());
    json.setString("status", status.id());
    json.setString("source_name", sourceName == null ? "" : sourceName);
    json.setString("source_sha256", sourceHashSha256 == null ? "" : sourceHashSha256);
    json.setString("reference_case_id", referenceCaseId == null ? "" : referenceCaseId);
    json.setInt("selected_resolution", selectedResolution);
    json.setString("sanitation_policy", sanitationPolicy.id());
    json.setString("first_blocking_stage", firstBlockingStage.toLowerCase());
    json.setString("first_blocking_code", firstBlockingCode);
    json.setString("recommended_next_action", recommendedNextAction);
    json.setBoolean("preview_enabled", previewEnabled);
    json.setBoolean("sdf_build_enabled", sdfBuildEnabled);
    json.setBoolean("materialization_enabled", materializationEnabled);
    json.setBoolean("export_enabled", exportEnabled);
    json.setBoolean("report_stale", reportStale);
    json.setLong("total_millis", totalMillis);
    json.setJSONArray("blockers", dcrteStringListJSON(blockers));
    json.setJSONArray("warnings", dcrteStringListJSON(warnings));
    json.setJSONArray("information", dcrteStringListJSON(information));
    JSONArray diagnosticJson = new JSONArray();
    for (int i = 0; i < diagnostics.size(); i++) diagnosticJson.setJSONObject(i, diagnostics.get(i).toJSON());
    json.setJSONArray("diagnostics", diagnosticJson);
    JSONArray stageJson = new JSONArray();
    for (int i = 0; i < stages.size(); i++) stageJson.setJSONObject(i, stages.get(i).toJSON());
    json.setJSONArray("stages", stageJson);
    JSONArray loopJson = new JSONArray();
    for (int i = 0; i < boundaryLoops.size(); i++) loopJson.setJSONObject(i, boundaryLoops.get(i).toJSON());
    json.setJSONArray("boundary_loops", loopJson);
    JSONArray componentJson = new JSONArray();
    for (int i = 0; i < components.size(); i++) componentJson.setJSONObject(i, components.get(i).toJSON());
    json.setJSONArray("components", componentJson);
    if (meshReport != null) json.setJSONObject("mesh_report", meshReport.toJSON());
    if (resolutionSuitability != null) json.setJSONObject("resolution_suitability", resolutionSuitability.toJSON());
    if (sdfReport != null) json.setJSONObject("sdf_report", sdfReport.toJSON());
    if (materializationReport != null) json.setJSONObject("materialization_report", materializationReport.toJSON());
    if (selfIntersectionReport != null) json.setJSONObject("self_intersection_report", selfIntersectionReport.toJSON());
    if (insideOutsideVerification != null) json.setJSONObject("inside_outside_verification", insideOutsideVerification.toJSON());
    JSONObject handoff = new JSONObject();
    handoff.setBoolean("single_dominant_closed_component", singleDominantClosedComponent);
    handoff.setFloat("dominant_component_fraction", dominantComponentFraction);
    handoff.setFloat("elongation_ratio", elongationRatio);
    handoff.setFloat("principal_axis_confidence", principalAxisConfidence);
    handoff.setInt("inside_mask_component_count", insideMaskComponentCount);
    handoff.setFloat("inside_mask_dominant_fraction", insideMaskDominantFraction);
    handoff.setFloat("sdf_resolution_confidence", sdfResolutionConfidence);
    handoff.setBoolean("thin_feature_risk", thinFeatureRisk);
    handoff.setString("nested_shell_status", nestedShellStatus);
    handoff.setString("self_intersection_status", selfIntersectionStatus);
    handoff.setInt("component_count", componentCount);
    json.setJSONObject("milestone_3_handoff", handoff);
    return json;
  }
}

String[] dcrtePreflightStageNames() {
  return new String[] {"FILE", "PARSE", "GEOMETRY", "TOPOLOGY", "COMPONENTS", "ORIENTATION",
    "SELF_INTERSECTION", "TRANSFORM", "RESOLUTION", "BOUNDARY_VOXELIZATION", "INSIDE_OUTSIDE",
    "SIGNED_DISTANCE", "MATERIALIZATION", "EXPORT"};
}

int dcrtePreflightStageIndex(String stage) {
  String[] names = dcrtePreflightStageNames();
  for (int i = 0; i < names.length; i++) if (names[i].equals(stage)) return i;
  return names.length;
}
