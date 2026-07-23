/*
  Geodesic Salon core.

  This module is intentionally isolated from the established Foundry and DCRTE
  pipelines. It supplies deterministic geodesic observation geometry, local
  face coordinates, fabrication meshes, and validation without changing the
  behavior of the existing milestone implementations.
*/

enum GeodesicSeedFamily {
  TETRAHEDRAL,
  OCTAHEDRAL,
  ICOSAHEDRAL,
  DODECAHEDRAL,
  RHOMBIC_TRIACONTAHEDRAL;

  String label() {
    if (this == TETRAHEDRAL) return "TETRA";
    if (this == OCTAHEDRAL) return "OCTA";
    if (this == DODECAHEDRAL) return "DODECA";
    if (this == RHOMBIC_TRIACONTAHEDRAL) return "RHOMBIC 30";
    return "ICOSA";
  }
}

enum GeodesicFormModifier {
  NONE,
  FACE_STELLATION;

  String label() { return this == FACE_STELLATION ? "STELLATED" : "STANDARD"; }
}

enum GeodesicExtentMode {
  DOME,
  SPHERE;

  String label() { return this == DOME ? "DOME" : "SPHERE"; }
}

enum GeodesicGrowthMode {
  SHELL_OVERWRAP,
  CENTER_TO_EDGE;

  String label() { return this == SHELL_OVERWRAP ? "OVERWRAP" : "CENTER > EDGE"; }
}

enum GeodesicPanelStyle {
  SOLID,
  FRAME_SKIN,
  OPEN_FRAME;

  String label() {
    if (this == SOLID) return "SOLID";
    if (this == OPEN_FRAME) return "OPEN FRAME";
    return "FRAME + SKIN";
  }
}

enum GeodesicSeamProfile {
  SQUARE,
  HALF_DIHEDRAL_MITER;

  String label() {
    return this == HALF_DIHEDRAL_MITER ? "MITERED" : "SQUARE";
  }
}

enum GeodesicReliefSide {
  INNER_REINFORCEMENT,
  EXTERIOR_CROWN;

  String label() {
    return this == EXTERIOR_CROWN ? "EXTERIOR CROWN" : "INNER REINFORCEMENT";
  }
}

enum GeodesicAssemblyMode {
  LEGACY_PORTAL,
  KICAS;

  String label() {
    return this == KICAS ? "KICAS LOCK + TIE" : "LEGACY PORTAL";
  }
}

class GeodesicFabricationSettings {
  GeodesicAssemblyMode assemblyMode = GeodesicAssemblyMode.LEGACY_PORTAL;
  GeodesicKicasPlan kicasPlan = null;
  GeodesicPanelStyle style = GeodesicPanelStyle.FRAME_SKIN;
  GeodesicReliefSide reliefSide = GeodesicReliefSide.INNER_REINFORCEMENT;
  float frameDepthMM = 13.0f;
  float frameWidthMM = 7.0f;
  float skinThicknessMM = 3.0f;
  boolean fastenerPortals = true;
  int desiredPortalsPerEdge = 2;
  float portalWidthMM = 5.2f;
  float portalHeightMM = 2.6f;
  boolean bubbleJoinEnabled = true;
  float bubbleClearanceStrength = 0.35f;
  boolean edgeCodesEnabled = true;
  float edgeBreakMM = 0.22f;
  float edgeCodeReliefMM = 0.45f;
  float kicasLockLengthMM = 7.2f;
  float kicasLockDepthMM = 1.35f;
  float kicasLockClearanceMM = 0.32f;
  float kicasPortalScale = 1.30f;
  GeodesicSeamProfile seamProfile = GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
  float requestedFrameDepthMM = 13.0f;
  float miterDepthLimitMM = 13.0f;
  boolean miterDepthAutoCapped = false;
  float fabricationScale = 1.0f;
  float effectiveAssemblyRadiusMM = 0;
  boolean fabricationScaleAutoRaised = false;
  boolean kitDimensionsResolved = false;

  GeodesicFabricationSettings copy() {
    GeodesicFabricationSettings value = new GeodesicFabricationSettings();
    value.assemblyMode = assemblyMode;
    value.kicasPlan = kicasPlan;
    value.style = style;
    value.reliefSide = reliefSide;
    value.frameDepthMM = frameDepthMM;
    value.frameWidthMM = frameWidthMM;
    value.skinThicknessMM = skinThicknessMM;
    value.fastenerPortals = fastenerPortals;
    value.desiredPortalsPerEdge = desiredPortalsPerEdge;
    value.portalWidthMM = portalWidthMM;
    value.portalHeightMM = portalHeightMM;
    value.bubbleJoinEnabled = bubbleJoinEnabled;
    value.bubbleClearanceStrength = bubbleClearanceStrength;
    value.edgeCodesEnabled = edgeCodesEnabled;
    value.edgeBreakMM = edgeBreakMM;
    value.edgeCodeReliefMM = edgeCodeReliefMM;
    value.kicasLockLengthMM = kicasLockLengthMM;
    value.kicasLockDepthMM = kicasLockDepthMM;
    value.kicasLockClearanceMM = kicasLockClearanceMM;
    value.kicasPortalScale = kicasPortalScale;
    value.seamProfile = seamProfile;
    value.requestedFrameDepthMM = requestedFrameDepthMM;
    value.miterDepthLimitMM = miterDepthLimitMM;
    value.miterDepthAutoCapped = miterDepthAutoCapped;
    value.fabricationScale = fabricationScale;
    value.effectiveAssemblyRadiusMM = effectiveAssemblyRadiusMM;
    value.fabricationScaleAutoRaised = fabricationScaleAutoRaised;
    value.kitDimensionsResolved = kitDimensionsResolved;
    return value;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("assembly_mode", assemblyMode.label());
    json.setString("panel_style", style.label());
    json.setString("relief_side", reliefSide.label());
    json.setString("dimension_policy", "face_relative_printable_caps");
    json.setBoolean("face_relative_scaling", style != GeodesicPanelStyle.SOLID);
    json.setFloat("frame_depth_mm", frameDepthMM);
    json.setFloat("frame_width_mm", frameWidthMM);
    json.setFloat("skin_thickness_mm", style == GeodesicPanelStyle.OPEN_FRAME ? 0 : skinThicknessMM);
    json.setBoolean("integral_fastener_portals", fastenerPortals && style != GeodesicPanelStyle.SOLID);
    json.setInt("desired_portals_per_edge", desiredPortalsPerEdge);
    json.setFloat("portal_width_mm", portalWidthMM);
    json.setFloat("portal_height_mm", portalHeightMM);
    json.setBoolean("bubble_join_rule", bubbleJoinEnabled);
    json.setFloat("bubble_clearance_strength", bubbleClearanceStrength);
    json.setBoolean("embossed_edge_codes", edgeCodesEnabled && style != GeodesicPanelStyle.SOLID);
    json.setBoolean("ordered_placement_labels", assemblyMode == GeodesicAssemblyMode.KICAS);
    json.setString("placement_label_treatment",
      assemblyMode != GeodesicAssemblyMode.KICAS ? "OFF" :
      (style == GeodesicPanelStyle.OPEN_FRAME ||
       (style == GeodesicPanelStyle.FRAME_SKIN &&
        reliefSide == GeodesicReliefSide.INNER_REINFORCEMENT) ?
      "RAISED_INTERIOR_RAIL" : "RAISED_INTERIOR_MEMBRANE"));
    json.setString("placement_label_glyph_style",
      assemblyMode == GeodesicAssemblyMode.KICAS ?
      "RAISED_ROUNDED_STROKE" : "OFF");
    json.setFloat("placement_label_scale_target",
      assemblyMode == GeodesicAssemblyMode.KICAS ?
      GEODESIC_KICAS_PLACEMENT_LABEL_SCALE : 0);
    json.setString("placement_label_fit_policy",
      assemblyMode == GeodesicAssemblyMode.KICAS ?
      "THREE_X_TARGET_FIT_CAPPED_TO_PRINTABLE_FACE" : "OFF");
    json.setBoolean("recessed_edge_codes", false);
    json.setString("edge_code_treatment", edgeCodesEnabled && style != GeodesicPanelStyle.SOLID ?
      "RAISED_INTERIOR" : "OFF");
    json.setString("edge_code_face", style == GeodesicPanelStyle.SOLID ?
      "NOT_APPLICABLE" : "INTERIOR");
    json.setString("edge_code_glyph_style", edgeCodesEnabled &&
      style != GeodesicPanelStyle.SOLID ? "RAISED_ROUNDED_STROKE" : "OFF");
    json.setFloat("edge_break_mm", edgeBreakMM);
    json.setFloat("edge_code_relief_mm", edgeCodeReliefMM);
    json.setFloat("edge_code_depth_mm", 0);
    json.setFloat("edge_code_height_mm", edgeCodeReliefMM);
    json.setFloat("kicas_lock_length_mm", kicasLockLengthMM);
    json.setFloat("kicas_lock_depth_mm", kicasLockDepthMM);
    json.setFloat("kicas_lock_clearance_mm", kicasLockClearanceMM);
    json.setFloat("kicas_center_portal_scale", kicasPortalScale);
    json.setString("kicas_joint_policy", assemblyMode == GeodesicAssemblyMode.KICAS ?
      "DIRECTED_SLIDE_CAPTURE_WITH_INDEPENDENT_CENTER_TIE_PORTAL" : "OFF");
    json.setString("shared_edge_profile", style == GeodesicPanelStyle.SOLID ?
      "SQUARE_SOLID" : (seamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER ?
      "HALF_DIHEDRAL_MITER" : "SQUARE_UNMITERED"));
    json.setBoolean("dihedral_miter_applied", style != GeodesicPanelStyle.SOLID &&
      seamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER);
    json.setFloat("requested_frame_depth_mm", requestedFrameDepthMM);
    json.setFloat("miter_depth_limit_mm", miterDepthLimitMM);
    json.setBoolean("miter_depth_auto_capped", miterDepthAutoCapped);
    json.setFloat("fabrication_scale", fabricationScale);
    json.setFloat("effective_assembly_radius_mm", effectiveAssemblyRadiusMM);
    json.setBoolean("fabrication_scale_auto_raised", fabricationScaleAutoRaised);
    json.setBoolean("kit_dimensions_resolved", kitDimensionsResolved);
    json.setFloat("plateau_target_deg", geodesicPlateauAngleDegrees());
    return json;
  }
}

class GeodesicJointEdgeProfile {
  int edgeIndex;
  int neighborFaceId = -1;
  float edgeLengthMM;
  float normalAngleDeg = -1;
  float interiorDihedralDeg = -1;
  float plateauDeviationDeg = -1;
  float cornerClearanceMM;
  float portalWidthMM;
  float recommendedHalfMiterDeg = 0;
  float recommendedMiterInsetMM = 0;
  float miterInsetSign = 1;
  boolean concaveJoint = false;
  boolean miterFeasibleAtResolvedDimensions = true;
  String compatibilityKey = "";
  String mateCode = "";
  String kicasRole = "OFF";
  float kicasStation = 0.72f;
  float kicasLengthMM = 0;
  float kicasDepthMM = 0;
  ArrayList<Float> portalCenters = new ArrayList<Float>();
  PVector junctionBisector = new PVector();

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("edge_index", edgeIndex);
    json.setInt("neighbor_face_id", neighborFaceId);
    json.setFloat("edge_length_mm", edgeLengthMM);
    json.setFloat("normal_angle_deg", normalAngleDeg);
    json.setFloat("interior_dihedral_deg", interiorDihedralDeg);
    json.setFloat("plateau_deviation_deg", plateauDeviationDeg);
    json.setFloat("corner_clearance_mm", cornerClearanceMM);
    json.setFloat("portal_width_mm", portalWidthMM);
    json.setFloat("recommended_half_miter_deg", recommendedHalfMiterDeg);
    json.setFloat("recommended_miter_inset_mm", recommendedMiterInsetMM);
    json.setFloat("miter_inset_sign", miterInsetSign);
    json.setBoolean("concave_joint", concaveJoint);
    json.setString("joint_class", concaveJoint ? "CONCAVE" : "CONVEX");
    json.setBoolean("miter_feasible_at_resolved_dimensions",
      miterFeasibleAtResolvedDimensions);
    json.setString("compatibility_key", compatibilityKey);
    json.setString("mate_code", mateCode);
    json.setString("kicas_role", kicasRole);
    json.setFloat("kicas_station_edge_fraction", kicasStation);
    json.setFloat("kicas_length_mm", kicasLengthMM);
    json.setFloat("kicas_depth_mm", kicasDepthMM);
    JSONArray positions = new JSONArray();
    for (int i = 0; i < portalCenters.size(); i++) positions.setFloat(i, portalCenters.get(i));
    json.setJSONArray("portal_centers_edge_fraction", positions);
    JSONArray bisector = new JSONArray();
    bisector.setFloat(0, junctionBisector.x);
    bisector.setFloat(1, junctionBisector.y);
    bisector.setFloat(2, junctionBisector.z);
    json.setJSONArray("junction_bisector", bisector);
    return json;
  }
}

class GeodesicMiterOuterProfile {
  ArrayList<PVector> bottomCap = new ArrayList<PVector>();
  ArrayList<PVector> lowerMiter = new ArrayList<PVector>();
  ArrayList<PVector> upperMiter = new ArrayList<PVector>();
  ArrayList<PVector> topCap = new ArrayList<PVector>();
  float depth;
  float edgeBreak;
  boolean exteriorAtTop;

  boolean valid(int vertexCount) {
    return vertexCount >= 3 &&
      bottomCap.size() == vertexCount &&
      lowerMiter.size() == vertexCount &&
      upperMiter.size() == vertexCount &&
      topCap.size() == vertexCount;
  }
}

class GeodesicFabricationFace {
  int faceId = -1;
  int parentFace = -1;
  String placementLabel = "";
  ArrayList<PVector> boundary = new ArrayList<PVector>();
  ArrayList<Integer> vertexIds = new ArrayList<Integer>();
  ArrayList<Integer> neighborFaceIds = new ArrayList<Integer>();
  ArrayList<GeodesicJointEdgeProfile> joints = new ArrayList<GeodesicJointEdgeProfile>();
  PVector origin = new PVector();
  PVector axisX = new PVector(1, 0, 0);
  PVector axisY = new PVector(0, 1, 0);
  PVector axisZ = new PVector(0, 0, 1);
  GeodesicFabricationSettings resolvedFabrication = null;
  float shortestEdgeMM = 0;
  float apothemMM = 0;

  int vertexCount() { return boundary.size(); }

  int portalCount() {
    int count = 0;
    for (GeodesicJointEdgeProfile joint : joints) count += joint.portalCenters.size();
    return count;
  }

  JSONObject resolvedDimensionsJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("shortest_edge_mm", shortestEdgeMM);
    json.setFloat("apothem_mm", apothemMM);
    if (resolvedFabrication != null)
      json.setJSONObject("fabrication", resolvedFabrication.toJSON());
    return json;
  }
}

class GeodesicVertex {
  int id;
  PVector position;
  int valence;

  GeodesicVertex(int id, PVector position) {
    this.id = id;
    this.position = position.copy();
  }
}

class GeodesicFace {
  int id;
  int a;
  int b;
  int c;
  int parentFace;
  int[] neighbors = { -1, -1, -1 };
  PVector centroid = new PVector();
  PVector normal = new PVector(0, 0, 1);

  GeodesicFace(int id, int a, int b, int c, int parentFace) {
    this.id = id;
    this.a = a;
    this.b = b;
    this.c = c;
    this.parentFace = parentFace;
  }

  int vertex(int index) {
    if (index == 0) return a;
    if (index == 1) return b;
    return c;
  }
}

class GeodesicEdge {
  int id;
  int a;
  int b;
  int faceA = -1;
  int faceB = -1;

  GeodesicEdge(int id, int a, int b) {
    this.id = id;
    this.a = a;
    this.b = b;
  }

  boolean boundary() { return faceA >= 0 && faceB < 0; }
  int faceCount() { return (faceA >= 0 ? 1 : 0) + (faceB >= 0 ? 1 : 0); }
}

class GeodesicIntrinsicSample {
  boolean valid;
  int faceId = -1;
  float b0;
  float b1;
  float b2;
  float s;
  float theta;
  float confidence;
  PVector projected = new PVector();

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("valid", valid);
    json.setInt("face_id", faceId);
    JSONArray bary = new JSONArray();
    bary.setFloat(0, b0); bary.setFloat(1, b1); bary.setFloat(2, b2);
    json.setJSONArray("barycentric", bary);
    json.setFloat("center_to_edge", s);
    json.setFloat("theta", theta);
    json.setFloat("confidence", confidence);
    return json;
  }
}

class GeodesicModel {
  GeodesicSeedFamily family;
  GeodesicExtentMode extent;
  GeodesicFormModifier modifier = GeodesicFormModifier.NONE;
  int frequency;
  float radius;
  float cutRatio;
  float cutZ;
  float stellationRatio = 0;
  ArrayList<GeodesicVertex> vertices = new ArrayList<GeodesicVertex>();
  ArrayList<GeodesicFace> faces = new ArrayList<GeodesicFace>();
  ArrayList<GeodesicEdge> edges = new ArrayList<GeodesicEdge>();
  boolean valid;
  String validation = "not built";
  int boundaryEdges;
  int boundaryLoopCount;
  boolean boundaryChainClosed;
  boolean boundaryChainSimple;
  float boundaryPerimeterMM;
  int nonManifoldEdges;
  int fiveValentVertices;
  int eulerCharacteristic;
  float gaussBonnetTotal;
  float gaussBonnetExpected;
  float gaussBonnetResidual;
  String fingerprint = "";

  GeodesicModel(GeodesicSeedFamily family, GeodesicExtentMode extent, int frequency, float radius, float cutRatio) {
    this(family, extent, frequency, radius, cutRatio, GeodesicFormModifier.NONE, 0);
  }

  GeodesicModel(GeodesicSeedFamily family, GeodesicExtentMode extent, int frequency,
    float radius, float cutRatio, GeodesicFormModifier modifier, float stellationRatio) {
    this.family = family;
    this.extent = extent;
    this.modifier = modifier;
    this.frequency = frequency;
    this.radius = radius;
    this.cutRatio = cutRatio;
    this.cutZ = radius * cutRatio;
    this.stellationRatio = stellationRatio;
  }

  int expectedFullFaces() {
    int baseFaces = family == GeodesicSeedFamily.TETRAHEDRAL ? 4 :
      (family == GeodesicSeedFamily.OCTAHEDRAL ? 8 :
      (family == GeodesicSeedFamily.DODECAHEDRAL ? 36 :
      (family == GeodesicSeedFamily.RHOMBIC_TRIACONTAHEDRAL ? 60 : 20)));
    int modifierFactor = modifier == GeodesicFormModifier.FACE_STELLATION ? 3 : 1;
    return baseFaces * frequency * frequency * modifierFactor;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("family", family.label());
    json.setString("extent", extent.label());
    json.setString("modifier", modifier.label());
    json.setFloat("stellation_ratio", stellationRatio);
    json.setInt("frequency", frequency);
    json.setFloat("radius_mm", radius);
    json.setFloat("cut_ratio", cutRatio);
    json.setFloat("cut_z_mm", cutZ);
    json.setInt("vertices", vertices.size());
    json.setInt("edges", edges.size());
    json.setInt("faces", faces.size());
    json.setInt("boundary_edges", boundaryEdges);
    json.setInt("boundary_loop_count", boundaryLoopCount);
    json.setBoolean("boundary_chain_closed", boundaryChainClosed);
    json.setBoolean("boundary_chain_simple", boundaryChainSimple);
    json.setFloat("boundary_perimeter_mm", boundaryPerimeterMM);
    json.setInt("nonmanifold_edges", nonManifoldEdges);
    json.setInt("five_valent_vertices", fiveValentVertices);
    json.setInt("euler_characteristic", eulerCharacteristic);
    json.setFloat("gauss_bonnet_total_rad", gaussBonnetTotal);
    json.setFloat("gauss_bonnet_expected_rad", gaussBonnetExpected);
    json.setFloat("gauss_bonnet_residual_rad", gaussBonnetResidual);
    json.setBoolean("valid", valid);
    json.setString("validation", validation);
    json.setString("fingerprint", fingerprint);
    return json;
  }
}

class GeodesicIntrinsicCoordinateSystem {
  GeodesicModel model;

  GeodesicIntrinsicCoordinateSystem(GeodesicModel model) {
    this.model = model;
  }

  GeodesicIntrinsicSample locate(PVector point) {
    GeodesicIntrinsicSample result = new GeodesicIntrinsicSample();
    if (model == null || model.faces.size() == 0 || point == null) return result;
    float bestScore = Float.MAX_VALUE;
    GeodesicFace bestFace = null;
    float[] bestBary = null;
    PVector bestProjection = null;
    for (GeodesicFace face : model.faces) {
      PVector a = model.vertices.get(face.a).position;
      float planeDistance = PVector.sub(point, a).dot(face.normal);
      PVector projection = PVector.sub(point, PVector.mult(face.normal, planeDistance));
      float[] bary = geodesicBarycentric(projection,
        a,
        model.vertices.get(face.b).position,
        model.vertices.get(face.c).position);
      float outside = max(0, -bary[0]) + max(0, -bary[1]) + max(0, -bary[2]);
      float score = abs(planeDistance) + outside * model.radius * 2.0f;
      if (score < bestScore) {
        bestScore = score;
        bestFace = face;
        bestBary = bary;
        bestProjection = projection;
      }
    }
    if (bestFace == null || bestBary == null) return result;
    float b0 = constrain(bestBary[0], 0, 1);
    float b1 = constrain(bestBary[1], 0, 1);
    float b2 = constrain(bestBary[2], 0, 1);
    float sum = b0 + b1 + b2;
    if (sum <= 0.000001f) return result;
    b0 /= sum; b1 /= sum; b2 /= sum;
    PVector a = model.vertices.get(bestFace.a).position;
    PVector b = model.vertices.get(bestFace.b).position;
    PVector center = bestFace.centroid;
    PVector axisU = PVector.sub(b, a);
    if (axisU.magSq() < 0.000001f) axisU.set(1, 0, 0);
    axisU.normalize();
    PVector axisV = bestFace.normal.cross(axisU);
    if (axisV.magSq() < 0.000001f) axisV.set(0, 1, 0);
    axisV.normalize();
    PVector radial = PVector.sub(bestProjection, center);
    result.valid = true;
    result.faceId = bestFace.id;
    result.b0 = b0; result.b1 = b1; result.b2 = b2;
    result.s = constrain(1.0f - 3.0f * min(b0, min(b1, b2)), 0, 1);
    result.theta = atan2(radial.dot(axisV), radial.dot(axisU));
    result.confidence = constrain(1.0f - bestScore / max(0.001f, model.radius * 0.12f), 0, 1);
    result.projected = bestProjection.copy();
    return result;
  }
}

class GeodesicDomain implements ObservationDomain {
  GeodesicModel model;

  GeodesicDomain(GeodesicModel model) { this.model = model; }

  public float signedDistance(float x, float y, float z) {
    if (!isValid()) return Float.NaN;
    PVector point = new PVector(x, y, z);
    float distance = -Float.MAX_VALUE;
    for (GeodesicFace face : model.faces) {
      PVector a = model.vertices.get(face.a).position;
      distance = max(distance, PVector.sub(point, a).dot(face.normal));
    }
    if (model.extent == GeodesicExtentMode.DOME) distance = max(distance, model.cutZ - z);
    return distance;
  }

  public void sample(float x, float y, float z, DomainSample target) {
    if (target == null) return;
    if (!isValid()) {
      target.set(false, Float.NaN, 0, 0, 1, 0, false);
      return;
    }
    PVector point = new PVector(x, y, z);
    float distance = -Float.MAX_VALUE;
    PVector normal = new PVector(0, 0, 1);
    int region = 0;
    for (GeodesicFace face : model.faces) {
      PVector a = model.vertices.get(face.a).position;
      float candidate = PVector.sub(point, a).dot(face.normal);
      if (candidate > distance) {
        distance = candidate;
        normal.set(face.normal);
        region = face.id + 1;
      }
    }
    if (model.extent == GeodesicExtentMode.DOME && model.cutZ - z > distance) {
      distance = model.cutZ - z;
      normal.set(0, 0, -1);
      region = model.faces.size() + 1;
    }
    target.set(distance <= 0, distance, normal.x, normal.y, normal.z, distance <= 0 ? region : 0, true);
  }

  public Bounds3D bounds() {
    if (!isValid()) return new Bounds3D(0, 0, 0, 0, 0, 0);
    float minZ = model.extent == GeodesicExtentMode.DOME ? model.cutZ : -model.radius;
    return new Bounds3D(-model.radius, -model.radius, minZ, model.radius, model.radius, model.radius);
  }

  public float analyticVolume() {
    if (!isValid()) return 0;
    if (model.extent == GeodesicExtentMode.SPHERE) return 4.0f * PI * pow(model.radius, 3) / 3.0f;
    float h = model.radius - model.cutZ;
    return PI * h * h * (model.radius - h / 3.0f);
  }

  public String getId() { return "geodesic_" + (model == null ? "invalid" : model.family.label().toLowerCase()); }
  public String getVersion() { return "salon-1.0"; }
  public boolean isValid() { return model != null && model.valid; }
  public String validationMessage() { return isValid() ? model.validation : "geodesic model is invalid"; }

  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", getId());
    json.setString("version", getVersion());
    json.setBoolean("valid", isValid());
    if (model != null) json.setJSONObject("geometry", model.toJSON());
    json.setFloat("analytic_envelope_volume_mm3", analyticVolume());
    return json;
  }
}

class GeodesicPart {
  int faceId;
  int parentFace;
  int[] neighbors;
  String filename;
  SurfaceMesh mesh;
  int[] audit;
  GeodesicFabricationSettings fabrication;
  GeodesicFabricationFace fabricationFace;

  JSONObject toJSON(GeodesicModel model) {
    JSONObject json = new JSONObject();
    json.setInt("face_id", faceId);
    json.setInt("parent_face", parentFace);
    JSONArray neighborValues = new JSONArray();
    for (int i = 0; i < neighbors.length; i++) neighborValues.setInt(i, neighbors[i]);
    json.setJSONArray("neighbors", neighborValues);
    json.setString("filename", filename == null ? "" : filename);
    json.setInt("triangles", mesh == null ? 0 : mesh.tris.size());
    if (fabrication != null) json.setJSONObject("fabrication", fabrication.toJSON());
    if (fabricationFace != null) {
      json.setInt("boundary_vertex_count", fabricationFace.vertexCount());
      json.setInt("integral_portal_count", fabricationFace.portalCount());
      json.setJSONObject("resolved_dimensions", fabricationFace.resolvedDimensionsJSON());
      JSONArray joints = new JSONArray();
      for (int i = 0; i < fabricationFace.joints.size(); i++)
        joints.setJSONObject(i, fabricationFace.joints.get(i).toJSON());
      json.setJSONArray("edge_joints", joints);
    }
    if (audit != null) {
      json.setInt("boundary_edges", audit[0]);
      json.setInt("nonmanifold_edges", audit[1]);
      json.setInt("degenerate_faces", audit[2]);
    }
    if (model != null && faceId >= 0 && faceId < model.faces.size()) {
      GeodesicFace face = model.faces.get(faceId);
      JSONArray center = new JSONArray();
      center.setFloat(0, face.centroid.x); center.setFloat(1, face.centroid.y); center.setFloat(2, face.centroid.z);
      JSONArray normal = new JSONArray();
      normal.setFloat(0, face.normal.x); normal.setFloat(1, face.normal.y); normal.setFloat(2, face.normal.z);
      json.setJSONArray("center_mm", center);
      json.setJSONArray("normal", normal);
    }
    return json;
  }
}

class GeodesicPartType {
  String typeId;
  String signature;
  int representativeFaceId;
  int quantity;
  String filename;
  SurfaceMesh mesh;
  int[] audit;
  GeodesicFabricationSettings fabrication;
  int portalCount;
  boolean physicalEdgeCodesRequested;
  boolean physicalEdgeCodesApplied;
  String physicalEdgeCodeStatus = "not_requested";
  int[] codedAudit;
  ArrayList<String> edgeCodes = new ArrayList<String>();
  ArrayList<Integer> faceIds = new ArrayList<Integer>();

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type_id", typeId);
    json.setString("signature", signature);
    json.setInt("representative_face_id", representativeFaceId);
    json.setInt("quantity", quantity);
    json.setString("filename", filename == null ? "" : filename);
    json.setInt("triangles", mesh == null ? 0 : mesh.tris.size());
    json.setInt("integral_portal_count", portalCount);
    json.setBoolean("physical_edge_codes_requested", physicalEdgeCodesRequested);
    json.setBoolean("physical_edge_codes_applied", physicalEdgeCodesApplied);
    json.setString("physical_edge_code_status", physicalEdgeCodeStatus);
    JSONArray codes = new JSONArray();
    for (int i = 0; i < edgeCodes.size(); i++) codes.setString(i, edgeCodes.get(i));
    json.setJSONArray("edge_mate_codes", codes);
    if (fabrication != null) json.setJSONObject("fabrication", fabrication.toJSON());
    JSONArray faces = new JSONArray();
    for (int i = 0; i < faceIds.size(); i++) faces.setInt(i, faceIds.get(i));
    json.setJSONArray("face_ids", faces);
    if (audit != null) {
      json.setInt("boundary_edges", audit[0]);
      json.setInt("nonmanifold_edges", audit[1]);
      json.setInt("degenerate_faces", audit[2]);
    }
    if (codedAudit != null) {
      json.setInt("coded_attempt_boundary_edges", codedAudit[0]);
      json.setInt("coded_attempt_nonmanifold_edges", codedAudit[1]);
      json.setInt("coded_attempt_degenerate_faces", codedAudit[2]);
    }
    return json;
  }
}

class GeodesicPanelCatalog {
  ArrayList<GeodesicPartType> types = new ArrayList<GeodesicPartType>();
  HashMap<Integer, String> faceToType = new HashMap<Integer, String>();
  GeodesicFabricationSettings fabrication;

  int physicalEdgeCodeFallbackCount() {
    int result = 0;
    for (GeodesicPartType type : types)
      if (type.physicalEdgeCodesRequested && !type.physicalEdgeCodesApplied) result++;
    return result;
  }

  GeodesicPartType typeById(String typeId) {
    if (typeId == null) return null;
    for (GeodesicPartType type : types)
      if (typeId.equals(type.typeId)) return type;
    return null;
  }

  JSONObject billOfMaterialsJSON() {
    JSONObject json = new JSONObject();
    json.setInt("unique_part_types", types.size());
    json.setInt("physical_edge_code_fallback_types", physicalEdgeCodeFallbackCount());
    if (fabrication != null)
      json.setJSONObject("requested_kit_fabrication", fabrication.toJSON());
    int total = 0;
    JSONArray values = new JSONArray();
    for (int i = 0; i < types.size(); i++) {
      GeodesicPartType type = types.get(i);
      total += type.quantity;
      values.setJSONObject(i, type.toJSON());
    }
    json.setInt("total_panel_instances", total);
    json.setJSONArray("part_types", values);
    return json;
  }
}

class GeodesicPartsList {
  ArrayList<GeodesicPart> parts = new ArrayList<GeodesicPart>();

  JSONObject toJSON(GeodesicModel model) {
    JSONObject json = new JSONObject();
    json.setInt("part_count", parts.size());
    JSONArray values = new JSONArray();
    for (int i = 0; i < parts.size(); i++) values.setJSONObject(i, parts.get(i).toJSON(model));
    json.setJSONArray("parts", values);
    return json;
  }
}

GeodesicModel buildGeodesicModel(GeodesicSeedFamily family, GeodesicExtentMode extent,
  int frequency, float radius, float cutRatio) {
  return buildGeodesicModel(family, extent, frequency, radius, cutRatio,
    GeodesicFormModifier.NONE, 0);
}

GeodesicModel buildGeodesicModel(GeodesicSeedFamily family, GeodesicExtentMode extent,
  int frequency, float radius, float cutRatio, GeodesicFormModifier modifier,
  float stellationRatio) {
  frequency = constrain(frequency, 1, 12);
  radius = max(1, radius);
  cutRatio = constrain(cutRatio, -0.30f, 0.82f);
  GeodesicModel full = buildFullGeodesicModel(family, frequency, radius);
  if (modifier == GeodesicFormModifier.FACE_STELLATION &&
    geodesicFamilySupportsStellation(family)) {
    full = stellateGeodesicModel(full, constrain(stellationRatio, 0.04f, 0.45f));
  }
  if (extent == GeodesicExtentMode.SPHERE) return full;
  return clipGeodesicDome(full, cutRatio);
}

GeodesicModel buildFullGeodesicModel(GeodesicSeedFamily family, int frequency, float radius) {
  GeodesicModel model = new GeodesicModel(family, GeodesicExtentMode.SPHERE, frequency, radius, -1.0f);
  GeodesicSeedData seed = geodesicSeedData(family);
  ArrayList<PVector> seedVertices = seed.vertices;
  int[][] seedFaces = seed.faces;
  HashMap<String, Integer> vertexMap = new HashMap<String, Integer>();
  for (int parent = 0; parent < seedFaces.length; parent++) {
    PVector a = seedVertices.get(seedFaces[parent][0]);
    PVector b = seedVertices.get(seedFaces[parent][1]);
    PVector c = seedVertices.get(seedFaces[parent][2]);
    int[][] local = new int[frequency + 1][frequency + 1];
    for (int i = 0; i <= frequency; i++) {
      for (int j = 0; j <= frequency - i; j++) {
        float wa = (frequency - i - j) / (float)frequency;
        float wb = i / (float)frequency;
        float wc = j / (float)frequency;
        PVector point = PVector.mult(a, wa);
        point.add(PVector.mult(b, wb));
        point.add(PVector.mult(c, wc));
        point.normalize();
        point.mult(radius);
        local[i][j] = geodesicAddVertex(model, vertexMap, point);
      }
    }
    for (int i = 0; i < frequency; i++) {
      for (int j = 0; j < frequency - i; j++) {
        geodesicAddOrientedFace(model, local[i][j], local[i + 1][j], local[i][j + 1], parent);
        if (j < frequency - i - 1) {
          geodesicAddOrientedFace(model, local[i + 1][j], local[i + 1][j + 1], local[i][j + 1], parent);
        }
      }
    }
  }
  finalizeGeodesicModel(model);
  return model;
}

GeodesicModel clipGeodesicDome(GeodesicModel source, float cutRatio) {
  GeodesicModel dome = new GeodesicModel(source.family, GeodesicExtentMode.DOME,
    source.frequency, source.radius, cutRatio, source.modifier, source.stellationRatio);
  HashMap<String, Integer> vertexMap = new HashMap<String, Integer>();
  float cutZ = dome.cutZ;
  for (GeodesicFace sourceFace : source.faces) {
    ArrayList<PVector> triangle = new ArrayList<PVector>();
    triangle.add(source.vertices.get(sourceFace.a).position);
    triangle.add(source.vertices.get(sourceFace.b).position);
    triangle.add(source.vertices.get(sourceFace.c).position);
    ArrayList<PVector> clipped = clipGeodesicPolygonAbove(triangle, cutZ);
    if (clipped.size() < 3) continue;
    int first = geodesicAddVertex(dome, vertexMap, clipped.get(0));
    for (int i = 1; i < clipped.size() - 1; i++) {
      int b = geodesicAddVertex(dome, vertexMap, clipped.get(i));
      int c = geodesicAddVertex(dome, vertexMap, clipped.get(i + 1));
      PVector ab = PVector.sub(dome.vertices.get(b).position,
        dome.vertices.get(first).position);
      PVector ac = PVector.sub(dome.vertices.get(c).position,
        dome.vertices.get(first).position);
      if (ab.cross(ac).magSq() < 0.00000001f) continue;
      geodesicAddOrientedFace(dome, first, b, c, sourceFace.parentFace);
    }
  }
  finalizeGeodesicModel(dome);
  return dome;
}

boolean geodesicFamilySupportsStellation(GeodesicSeedFamily family) {
  return family == GeodesicSeedFamily.TETRAHEDRAL ||
    family == GeodesicSeedFamily.OCTAHEDRAL ||
    family == GeodesicSeedFamily.ICOSAHEDRAL;
}

GeodesicModel stellateGeodesicModel(GeodesicModel source, float ratio) {
  GeodesicModel result = new GeodesicModel(source.family, source.extent,
    source.frequency, source.radius, source.cutRatio,
    GeodesicFormModifier.FACE_STELLATION, ratio);
  for (GeodesicVertex vertex : source.vertices)
    result.vertices.add(new GeodesicVertex(result.vertices.size(), vertex.position));
  for (GeodesicFace face : source.faces) {
    PVector apex = face.centroid.copy();
    if (apex.magSq() < 0.000001f) apex.set(face.normal);
    apex.normalize().mult(source.radius * (1.0f + ratio));
    int apexId = result.vertices.size();
    result.vertices.add(new GeodesicVertex(apexId, apex));
    geodesicAddOrientedFace(result, face.a, face.b, apexId, face.parentFace);
    geodesicAddOrientedFace(result, face.b, face.c, apexId, face.parentFace);
    geodesicAddOrientedFace(result, face.c, face.a, apexId, face.parentFace);
  }
  finalizeGeodesicModel(result);
  return result;
}

void geodesicCountRawEdge(HashMap<String, Integer> counts, int a, int b) {
  String key = geodesicEdgeKey(a, b);
  counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
}

void geodesicCollectRawBoundary(HashMap<String, Integer> counts, HashSet<Integer> vertices, int a, int b) {
  if (counts.get(geodesicEdgeKey(a, b)) == 1) {
    vertices.add(a);
    vertices.add(b);
  }
}

ArrayList<PVector> clipGeodesicPolygonAbove(ArrayList<PVector> input, float cutZ) {
  ArrayList<PVector> output = new ArrayList<PVector>();
  if (input.size() == 0) return output;
  PVector previous = input.get(input.size() - 1);
  boolean previousInside = previous.z >= cutZ - 0.00001f;
  for (PVector current : input) {
    boolean currentInside = current.z >= cutZ - 0.00001f;
    if (currentInside != previousInside) {
      float denominator = current.z - previous.z;
      float t = abs(denominator) < 0.000001f ? 0 : (cutZ - previous.z) / denominator;
      PVector intersection = PVector.lerp(previous, current, constrain(t, 0, 1));
      intersection.z = cutZ;
      output.add(intersection);
    }
    if (currentInside) output.add(current.copy());
    previous = current;
    previousInside = currentInside;
  }
  ArrayList<PVector> cleaned = new ArrayList<PVector>();
  for (PVector point : output) {
    if (cleaned.size() == 0 || PVector.dist(point, cleaned.get(cleaned.size() - 1)) > 0.00001f) cleaned.add(point);
  }
  if (cleaned.size() > 1 && PVector.dist(cleaned.get(0), cleaned.get(cleaned.size() - 1)) <= 0.00001f) {
    cleaned.remove(cleaned.size() - 1);
  }
  return cleaned;
}

int geodesicAddVertex(GeodesicModel model, HashMap<String, Integer> map, PVector point) {
  String key = geodesicVertexKey(point);
  if (map.containsKey(key)) return map.get(key);
  int id = model.vertices.size();
  model.vertices.add(new GeodesicVertex(id, point));
  map.put(key, id);
  return id;
}

void geodesicAddOrientedFace(GeodesicModel model, int a, int b, int c, int parentFace) {
  if (a == b || b == c || c == a) return;
  PVector pa = model.vertices.get(a).position;
  PVector pb = model.vertices.get(b).position;
  PVector pc = model.vertices.get(c).position;
  PVector normal = PVector.sub(pb, pa).cross(PVector.sub(pc, pa));
  if (normal.magSq() < 0.00000001f) return;
  PVector center = PVector.add(PVector.add(pa, pb), pc).div(3.0f);
  if (normal.dot(center) < 0) {
    int swap = b; b = c; c = swap;
  }
  model.faces.add(new GeodesicFace(model.faces.size(), a, b, c, parentFace));
}

void finalizeGeodesicModel(GeodesicModel model) {
  HashMap<String, GeodesicEdge> edgeMap = new HashMap<String, GeodesicEdge>();
  for (GeodesicFace face : model.faces) {
    PVector a = model.vertices.get(face.a).position;
    PVector b = model.vertices.get(face.b).position;
    PVector c = model.vertices.get(face.c).position;
    face.centroid = PVector.add(PVector.add(a, b), c).div(3.0f);
    face.normal = PVector.sub(b, a).cross(PVector.sub(c, a));
    if (face.normal.magSq() > 0.0000001f) face.normal.normalize();
    geodesicRegisterEdge(model, edgeMap, face, 0, face.a, face.b);
    geodesicRegisterEdge(model, edgeMap, face, 1, face.b, face.c);
    geodesicRegisterEdge(model, edgeMap, face, 2, face.c, face.a);
  }
  model.edges.addAll(edgeMap.values());
  for (int i = 0; i < model.edges.size(); i++) {
    GeodesicEdge edge = model.edges.get(i);
    edge.id = i;
    model.vertices.get(edge.a).valence++;
    model.vertices.get(edge.b).valence++;
    if (edge.boundary()) model.boundaryEdges++;
    if (edge.faceCount() > 2 || edge.faceCount() == 0) model.nonManifoldEdges++;
    if (edge.faceA >= 0 && edge.faceB >= 0) {
      geodesicAssignNeighbor(model.faces.get(edge.faceA), edge.a, edge.b, edge.faceB);
      geodesicAssignNeighbor(model.faces.get(edge.faceB), edge.a, edge.b, edge.faceA);
    }
  }
  for (GeodesicVertex vertex : model.vertices) if (vertex.valence == 5) model.fiveValentVertices++;
  model.eulerCharacteristic = model.vertices.size() - model.edges.size() + model.faces.size();
  GeodesicBoundaryAnalysis boundary = geodesicAnalyzeBoundary(model);
  model.boundaryLoopCount = boundary.loopCount;
  model.boundaryChainClosed = boundary.closed;
  model.boundaryChainSimple = boundary.simple;
  model.boundaryPerimeterMM = boundary.perimeterMM;
  geodesicComputeGaussBonnet(model);
  boolean topologyOk = model.nonManifoldEdges == 0;
  topologyOk &= model.gaussBonnetResidual < 0.01f;
  if (model.extent == GeodesicExtentMode.SPHERE)
    topologyOk &= model.boundaryEdges == 0 && model.boundaryLoopCount == 0 &&
      model.boundaryChainClosed && model.boundaryChainSimple &&
      model.eulerCharacteristic == 2;
  else
    topologyOk &= model.boundaryEdges > 2 && model.boundaryLoopCount == 1 &&
      model.boundaryChainClosed && model.boundaryChainSimple &&
      model.eulerCharacteristic == 1;
  model.valid = model.faces.size() > 0 && topologyOk;
  if (model.valid) model.validation = "TOPOLOGY VALID";
  else if (model.nonManifoldEdges > 0)
    model.validation = "TOPOLOGY INVALID / NONMANIFOLD EDGE";
  else if (!model.boundaryChainClosed)
    model.validation = "TOPOLOGY INVALID / OPEN BOUNDARY CHAIN";
  else if (!model.boundaryChainSimple)
    model.validation = "TOPOLOGY INVALID / SELF-INTERSECTING BOUNDARY";
  else if (model.gaussBonnetResidual >= 0.01f)
    model.validation = "TOPOLOGY INVALID / CURVATURE BUDGET";
  else model.validation = "TOPOLOGY INVALID / EULER OR BOUNDARY CLASS";
  model.fingerprint = geodesicFingerprint(model);
}

class GeodesicBoundaryAnalysis {
  int loopCount = 0;
  boolean closed = true;
  boolean simple = true;
  float perimeterMM = 0;
  ArrayList<ArrayList<Integer>> loops = new ArrayList<ArrayList<Integer>>();
}

GeodesicBoundaryAnalysis geodesicAnalyzeBoundary(GeodesicModel model) {
  GeodesicBoundaryAnalysis result = new GeodesicBoundaryAnalysis();
  if (model == null) {
    result.closed = false;
    result.simple = false;
    return result;
  }
  HashMap<Integer, ArrayList<Integer>> adjacency =
    new HashMap<Integer, ArrayList<Integer>>();
  HashSet<String> unusedEdges = new HashSet<String>();
  for (GeodesicEdge edge : model.edges) {
    if (!edge.boundary()) continue;
    geodesicBoundaryNeighbor(adjacency, edge.a, edge.b);
    geodesicBoundaryNeighbor(adjacency, edge.b, edge.a);
    unusedEdges.add(geodesicEdgeKey(edge.a, edge.b));
    result.perimeterMM += PVector.dist(
      model.vertices.get(edge.a).position,
      model.vertices.get(edge.b).position);
  }
  if (unusedEdges.size() == 0) return result;
  for (Integer vertexId : adjacency.keySet())
    if (adjacency.get(vertexId).size() != 2) result.closed = false;

  int guardLimit = max(8, unusedEdges.size() * 2 + 4);
  while (unusedEdges.size() > 0) {
    String firstKey = unusedEdges.iterator().next();
    String[] endpointText = firstKey.split(":");
    int start = Integer.parseInt(endpointText[0]);
    int current = start;
    int previous = -1;
    ArrayList<Integer> loop = new ArrayList<Integer>();
    boolean loopClosed = false;
    for (int guard = 0; guard < guardLimit; guard++) {
      loop.add(current);
      ArrayList<Integer> neighbors = adjacency.get(current);
      if (neighbors == null || neighbors.size() == 0) break;
      int next = neighbors.get(0) == previous && neighbors.size() > 1 ?
        neighbors.get(1) : neighbors.get(0);
      unusedEdges.remove(geodesicEdgeKey(current, next));
      previous = current;
      current = next;
      if (current == start) {
        loopClosed = true;
        break;
      }
    }
    if (!loopClosed || loop.size() < 3) result.closed = false;
    result.loops.add(loop);
  }
  result.loopCount = result.loops.size();
  for (ArrayList<Integer> loop : result.loops)
    if (!geodesicBoundaryLoopSimple(model, loop)) result.simple = false;
  return result;
}

void geodesicBoundaryNeighbor(HashMap<Integer, ArrayList<Integer>> adjacency,
  int vertex, int neighbor) {
  if (!adjacency.containsKey(vertex))
    adjacency.put(vertex, new ArrayList<Integer>());
  adjacency.get(vertex).add(neighbor);
}

boolean geodesicBoundaryLoopSimple(GeodesicModel model,
  ArrayList<Integer> loop) {
  if (model == null || loop == null || loop.size() < 3) return false;
  int count = loop.size();
  for (int i = 0; i < count; i++) {
    PVector a = model.vertices.get(loop.get(i)).position;
    PVector b = model.vertices.get(loop.get((i + 1) % count)).position;
    for (int j = i + 1; j < count; j++) {
      if (j == i || j == (i + 1) % count ||
          (i == 0 && j == count - 1)) continue;
      PVector c = model.vertices.get(loop.get(j)).position;
      PVector d = model.vertices.get(loop.get((j + 1) % count)).position;
      if (geodesicSegmentsIntersectXY(a, b, c, d)) return false;
    }
  }
  return true;
}

boolean geodesicSegmentsIntersectXY(PVector a, PVector b,
  PVector c, PVector d) {
  float o1 = geodesicOrientationXY(a, b, c);
  float o2 = geodesicOrientationXY(a, b, d);
  float o3 = geodesicOrientationXY(c, d, a);
  float o4 = geodesicOrientationXY(c, d, b);
  float epsilon = 0.00001f;
  return ((o1 > epsilon && o2 < -epsilon) ||
      (o1 < -epsilon && o2 > epsilon)) &&
    ((o3 > epsilon && o4 < -epsilon) ||
      (o3 < -epsilon && o4 > epsilon));
}

float geodesicOrientationXY(PVector a, PVector b, PVector c) {
  return (b.x - a.x) * (c.y - a.y) -
    (b.y - a.y) * (c.x - a.x);
}

void geodesicComputeGaussBonnet(GeodesicModel model) {
  if (model == null || model.vertices.size() == 0) return;
  float[] angleSums = new float[model.vertices.size()];
  for (GeodesicFace face : model.faces) {
    int[] ids = { face.a, face.b, face.c };
    for (int corner = 0; corner < 3; corner++) {
      PVector center = model.vertices.get(ids[corner]).position;
      PVector left = PVector.sub(
        model.vertices.get(ids[(corner + 1) % 3]).position, center);
      PVector right = PVector.sub(
        model.vertices.get(ids[(corner + 2) % 3]).position, center);
      float denominator = left.mag() * right.mag();
      if (denominator > 0.000001f)
        angleSums[ids[corner]] += acos(constrain(
          left.dot(right) / denominator, -1, 1));
    }
  }
  HashSet<Integer> boundaryVertices = new HashSet<Integer>();
  for (GeodesicEdge edge : model.edges) {
    if (!edge.boundary()) continue;
    boundaryVertices.add(edge.a);
    boundaryVertices.add(edge.b);
  }
  float total = 0;
  for (int vertex = 0; vertex < angleSums.length; vertex++)
    total += (boundaryVertices.contains(vertex) ? PI : TWO_PI) -
      angleSums[vertex];
  model.gaussBonnetTotal = total;
  model.gaussBonnetExpected = TWO_PI * model.eulerCharacteristic;
  model.gaussBonnetResidual = abs(
    model.gaussBonnetTotal - model.gaussBonnetExpected);
}

void geodesicRegisterEdge(GeodesicModel model, HashMap<String, GeodesicEdge> edgeMap,
  GeodesicFace face, int localEdge, int a, int b) {
  String key = geodesicEdgeKey(a, b);
  GeodesicEdge edge = edgeMap.get(key);
  if (edge == null) {
    edge = new GeodesicEdge(edgeMap.size(), min(a, b), max(a, b));
    edge.faceA = face.id;
    edgeMap.put(key, edge);
  } else if (edge.faceB < 0) edge.faceB = face.id;
  else model.nonManifoldEdges++;
}

void geodesicAssignNeighbor(GeodesicFace face, int a, int b, int neighbor) {
  if (geodesicSameEdge(face.a, face.b, a, b)) face.neighbors[0] = neighbor;
  else if (geodesicSameEdge(face.b, face.c, a, b)) face.neighbors[1] = neighbor;
  else if (geodesicSameEdge(face.c, face.a, a, b)) face.neighbors[2] = neighbor;
}

boolean geodesicSameEdge(int a0, int b0, int a1, int b1) {
  return (a0 == a1 && b0 == b1) || (a0 == b1 && b0 == a1);
}

String geodesicEdgeKey(int a, int b) { return min(a, b) + ":" + max(a, b); }

String geodesicVertexKey(PVector point) {
  // Reversed edge interpolation can differ by a few float ULPs. A 0.0001 mm
  // weld tolerance keeps shared clip vertices identical without affecting
  // fabrication-scale geometry.
  return round(point.x * 10000.0f) + "," + round(point.y * 10000.0f) + "," + round(point.z * 10000.0f);
}

String geodesicFingerprint(GeodesicModel model) {
  String canonical = model.family.label() + "|" + model.extent.label() + "|" + model.frequency + "|" +
    model.vertices.size() + "|" + model.edges.size() + "|" + model.faces.size() + "|";
  int sampleStride = max(1, model.vertices.size() / 24);
  for (int i = 0; i < model.vertices.size(); i += sampleStride) canonical += geodesicVertexKey(model.vertices.get(i).position) + ";";
  return hex(canonical.hashCode(), 8);
}

float[] geodesicBarycentric(PVector point, PVector a, PVector b, PVector c) {
  PVector v0 = PVector.sub(b, a);
  PVector v1 = PVector.sub(c, a);
  PVector v2 = PVector.sub(point, a);
  float d00 = v0.dot(v0);
  float d01 = v0.dot(v1);
  float d11 = v1.dot(v1);
  float d20 = v2.dot(v0);
  float d21 = v2.dot(v1);
  float denominator = d00 * d11 - d01 * d01;
  if (abs(denominator) < 0.0000001f) return new float[] { 1, 0, 0 };
  float v = (d11 * d20 - d01 * d21) / denominator;
  float w = (d00 * d21 - d01 * d20) / denominator;
  return new float[] { 1.0f - v - w, v, w };
}

class GeodesicSeedData {
  ArrayList<PVector> vertices = new ArrayList<PVector>();
  int[][] faces = new int[0][0];
}

GeodesicSeedData geodesicSeedData(GeodesicSeedFamily family) {
  if (family == GeodesicSeedFamily.DODECAHEDRAL) return geodesicDodecaSeedData();
  if (family == GeodesicSeedFamily.RHOMBIC_TRIACONTAHEDRAL)
    return geodesicRhombicTriacontaSeedData();
  GeodesicSeedData data = new GeodesicSeedData();
  ArrayList<PVector> values = data.vertices;
  if (family == GeodesicSeedFamily.TETRAHEDRAL) {
    float baseX = 2.0f * sqrt(2.0f) / 3.0f;
    float backX = -sqrt(2.0f) / 3.0f;
    float baseY = sqrt(2.0f / 3.0f);
    values.add(new PVector(0, 0, 1));
    values.add(new PVector(baseX, 0, -1.0f / 3.0f));
    values.add(new PVector(backX, baseY, -1.0f / 3.0f));
    values.add(new PVector(backX, -baseY, -1.0f / 3.0f));
  } else if (family == GeodesicSeedFamily.OCTAHEDRAL) {
    values.add(new PVector(1, 0, 0)); values.add(new PVector(-1, 0, 0));
    values.add(new PVector(0, 1, 0)); values.add(new PVector(0, -1, 0));
    values.add(new PVector(0, 0, 1)); values.add(new PVector(0, 0, -1));
  } else if (family == GeodesicSeedFamily.ICOSAHEDRAL) {
    float phi = (1.0f + sqrt(5.0f)) * 0.5f;
    values.add(new PVector(-1, phi, 0)); values.add(new PVector(1, phi, 0));
    values.add(new PVector(-1, -phi, 0)); values.add(new PVector(1, -phi, 0));
    values.add(new PVector(0, -1, phi)); values.add(new PVector(0, 1, phi));
    values.add(new PVector(0, -1, -phi)); values.add(new PVector(0, 1, -phi));
    values.add(new PVector(phi, 0, -1)); values.add(new PVector(phi, 0, 1));
    values.add(new PVector(-phi, 0, -1)); values.add(new PVector(-phi, 0, 1));
  }
  for (PVector value : values) value.normalize();
  if (family == GeodesicSeedFamily.TETRAHEDRAL) {
    data.faces = new int[][] {
      { 0, 1, 2 }, { 0, 3, 1 }, { 0, 2, 3 }, { 1, 3, 2 }
    };
  } else if (family == GeodesicSeedFamily.OCTAHEDRAL) {
    data.faces = new int[][] {
      { 4, 0, 2 }, { 4, 2, 1 }, { 4, 1, 3 }, { 4, 3, 0 },
      { 5, 2, 0 }, { 5, 1, 2 }, { 5, 3, 1 }, { 5, 0, 3 }
    };
  } else {
    data.faces = new int[][] {
      { 0, 11, 5 }, { 0, 5, 1 }, { 0, 1, 7 }, { 0, 7, 10 }, { 0, 10, 11 },
      { 1, 5, 9 }, { 5, 11, 4 }, { 11, 10, 2 }, { 10, 7, 6 }, { 7, 1, 8 },
      { 3, 9, 4 }, { 3, 4, 2 }, { 3, 2, 6 }, { 3, 6, 8 }, { 3, 8, 9 },
      { 4, 9, 5 }, { 2, 4, 11 }, { 6, 2, 10 }, { 8, 6, 7 }, { 9, 8, 1 }
    };
  }
  return data;
}

ArrayList<PVector> geodesicSeedVertices(GeodesicSeedFamily family) {
  return geodesicSeedData(family).vertices;
}

int[][] geodesicSeedFaces(GeodesicSeedFamily family) {
  return geodesicSeedData(family).faces;
}

GeodesicSeedData geodesicDodecaSeedData() {
  GeodesicSeedData ico = geodesicSeedData(GeodesicSeedFamily.ICOSAHEDRAL);
  GeodesicSeedData result = new GeodesicSeedData();
  for (int[] face : ico.faces) {
    PVector center = PVector.add(PVector.add(ico.vertices.get(face[0]),
      ico.vertices.get(face[1])), ico.vertices.get(face[2])).div(3.0f);
    center.normalize();
    result.vertices.add(center);
  }
  ArrayList<int[]> triangles = new ArrayList<int[]>();
  for (int vertexId = 0; vertexId < ico.vertices.size(); vertexId++) {
    ArrayList<Integer> incident = new ArrayList<Integer>();
    for (int faceId = 0; faceId < ico.faces.length; faceId++)
      if (geodesicFaceContainsVertex(ico.faces[faceId], vertexId)) incident.add(faceId);
    ArrayList<Integer> ordered = geodesicSortAroundAxis(result.vertices,
      incident, ico.vertices.get(vertexId));
    geodesicTriangulatePolygonFan(ordered, triangles);
  }
  result.faces = geodesicTriangleArray(triangles);
  return result;
}

GeodesicSeedData geodesicRhombicTriacontaSeedData() {
  GeodesicSeedData ico = geodesicSeedData(GeodesicSeedFamily.ICOSAHEDRAL);
  HashMap<String, Integer> edgeMidpointIds = new HashMap<String, Integer>();
  ArrayList<PVector> rectifiedVertices = new ArrayList<PVector>();
  for (int[] face : ico.faces) {
    geodesicRectifiedVertex(ico.vertices, rectifiedVertices, edgeMidpointIds, face[0], face[1]);
    geodesicRectifiedVertex(ico.vertices, rectifiedVertices, edgeMidpointIds, face[1], face[2]);
    geodesicRectifiedVertex(ico.vertices, rectifiedVertices, edgeMidpointIds, face[2], face[0]);
  }

  ArrayList<ArrayList<Integer>> rectifiedFaces = new ArrayList<ArrayList<Integer>>();
  for (int[] face : ico.faces) {
    ArrayList<Integer> triangle = new ArrayList<Integer>();
    triangle.add(edgeMidpointIds.get(geodesicEdgeKey(face[0], face[1])));
    triangle.add(edgeMidpointIds.get(geodesicEdgeKey(face[1], face[2])));
    triangle.add(edgeMidpointIds.get(geodesicEdgeKey(face[2], face[0])));
    rectifiedFaces.add(triangle);
  }
  for (int vertexId = 0; vertexId < ico.vertices.size(); vertexId++) {
    ArrayList<Integer> incidentEdges = new ArrayList<Integer>();
    for (String key : edgeMidpointIds.keySet()) {
      String[] ids = split(key, ':');
      if (parseInt(ids[0]) == vertexId || parseInt(ids[1]) == vertexId)
        incidentEdges.add(edgeMidpointIds.get(key));
    }
    rectifiedFaces.add(geodesicSortAroundAxis(rectifiedVertices,
      incidentEdges, ico.vertices.get(vertexId)));
  }

  GeodesicSeedData result = new GeodesicSeedData();
  for (ArrayList<Integer> polygon : rectifiedFaces) {
    PVector center = new PVector();
    for (int id : polygon) center.add(rectifiedVertices.get(id));
    center.div(max(1, polygon.size()));
    center.normalize();
    result.vertices.add(center);
  }

  ArrayList<int[]> triangles = new ArrayList<int[]>();
  for (int rectifiedId = 0; rectifiedId < rectifiedVertices.size(); rectifiedId++) {
    ArrayList<Integer> incidentFaces = new ArrayList<Integer>();
    for (int faceId = 0; faceId < rectifiedFaces.size(); faceId++)
      if (rectifiedFaces.get(faceId).contains(rectifiedId)) incidentFaces.add(faceId);
    ArrayList<Integer> rhombus = geodesicSortAroundAxis(result.vertices,
      incidentFaces, rectifiedVertices.get(rectifiedId));
    geodesicTriangulatePolygonFan(rhombus, triangles);
  }
  result.faces = geodesicTriangleArray(triangles);
  return result;
}

int geodesicRectifiedVertex(ArrayList<PVector> source, ArrayList<PVector> target,
  HashMap<String, Integer> ids, int a, int b) {
  String key = geodesicEdgeKey(a, b);
  if (ids.containsKey(key)) return ids.get(key);
  PVector midpoint = PVector.add(source.get(a), source.get(b)).mult(0.5f);
  midpoint.normalize();
  int id = target.size();
  target.add(midpoint);
  ids.put(key, id);
  return id;
}

boolean geodesicFaceContainsVertex(int[] face, int vertexId) {
  for (int id : face) if (id == vertexId) return true;
  return false;
}

ArrayList<Integer> geodesicSortAroundAxis(ArrayList<PVector> points,
  ArrayList<Integer> ids, PVector axisValue) {
  ArrayList<Integer> result = new ArrayList<Integer>(ids);
  PVector axis = axisValue.copy();
  if (axis.magSq() < 0.000001f) axis.set(0, 0, 1);
  axis.normalize();
  PVector reference = abs(axis.z) < 0.85f ? new PVector(0, 0, 1) : new PVector(0, 1, 0);
  PVector basisX = reference.cross(axis);
  if (basisX.magSq() < 0.000001f) basisX.set(1, 0, 0);
  basisX.normalize();
  PVector basisY = axis.cross(basisX).normalize();
  for (int i = 1; i < result.size(); i++) {
    int value = result.get(i);
    float angle = geodesicAngleAroundAxis(points.get(value), axis, basisX, basisY);
    int j = i - 1;
    while (j >= 0 && geodesicAngleAroundAxis(points.get(result.get(j)),
      axis, basisX, basisY) > angle) {
      result.set(j + 1, result.get(j));
      j--;
    }
    result.set(j + 1, value);
  }
  return result;
}

float geodesicAngleAroundAxis(PVector point, PVector axis, PVector basisX, PVector basisY) {
  PVector tangent = PVector.sub(point, PVector.mult(axis, point.dot(axis)));
  return atan2(tangent.dot(basisY), tangent.dot(basisX));
}

void geodesicTriangulatePolygonFan(ArrayList<Integer> polygon, ArrayList<int[]> triangles) {
  if (polygon.size() < 3) return;
  for (int i = 1; i < polygon.size() - 1; i++)
    triangles.add(new int[] { polygon.get(0), polygon.get(i), polygon.get(i + 1) });
}

int[][] geodesicTriangleArray(ArrayList<int[]> triangles) {
  int[][] result = new int[triangles.size()][3];
  for (int i = 0; i < triangles.size(); i++) result[i] = triangles.get(i);
  return result;
}

SurfaceMesh buildGeodesicCombinedShell(GeodesicModel model, float thickness) {
  SurfaceMesh mesh = new SurfaceMesh("geodesic_salon_combined");
  if (model == null || !model.valid) return mesh;
  float shellThickness = constrain(thickness, 0.2f, model.radius * 0.35f);
  ArrayList<PVector> inner = new ArrayList<PVector>();
  for (GeodesicVertex vertex : model.vertices) {
    PVector point = vertex.position.copy();
    float localRadius = point.mag();
    if (localRadius > 0.000001f)
      point.normalize().mult(max(0.1f, localRadius - shellThickness));
    inner.add(point);
  }
  for (GeodesicFace face : model.faces) {
    PVector a = model.vertices.get(face.a).position;
    PVector b = model.vertices.get(face.b).position;
    PVector c = model.vertices.get(face.c).position;
    mesh.addTri(a, b, c);
    mesh.addTri(inner.get(face.c), inner.get(face.b), inner.get(face.a));
  }
  for (GeodesicEdge edge : model.edges) {
    if (!edge.boundary()) continue;
    GeodesicFace face = model.faces.get(edge.faceA);
    int u = edge.a;
    int v = edge.b;
    if (!geodesicFaceUsesDirectedEdge(face, u, v)) {
      int swap = u; u = v; v = swap;
    }
    mesh.addQuad(model.vertices.get(v).position, model.vertices.get(u).position,
      inner.get(u), inner.get(v));
  }
  return mesh;
}

boolean geodesicFaceUsesDirectedEdge(GeodesicFace face, int a, int b) {
  return (face.a == a && face.b == b) || (face.b == a && face.c == b) || (face.c == a && face.a == b);
}

GeodesicPart buildGeodesicFacePart(GeodesicModel model, GeodesicFace face,
  float thickness, GeodesicGrowthMode growthMode, float relief) {
  GeodesicPart part = new GeodesicPart();
  part.faceId = face.id;
  part.parentFace = face.parentFace;
  part.neighbors = face.neighbors.clone();
  part.mesh = new SurfaceMesh("geodesic_face_" + nf(face.id, 4));
  PVector a = model.vertices.get(face.a).position;
  PVector b = model.vertices.get(face.b).position;
  PVector c = model.vertices.get(face.c).position;
  float shellThickness = constrain(thickness, 0.2f, model.radius * 0.35f);
  PVector ai = geodesicRadialInset(a, shellThickness);
  PVector bi = geodesicRadialInset(b, shellThickness);
  PVector ci = geodesicRadialInset(c, shellThickness);
  if (growthMode == GeodesicGrowthMode.CENTER_TO_EDGE) {
    PVector center = PVector.add(PVector.add(a, b), c).div(3.0f);
    center.normalize().mult(model.radius + max(0, relief));
    part.mesh.addTri(a, b, center);
    part.mesh.addTri(b, c, center);
    part.mesh.addTri(c, a, center);
  } else part.mesh.addTri(a, b, c);
  part.mesh.addTri(ci, bi, ai);
  part.mesh.addQuad(b, a, ai, bi);
  part.mesh.addQuad(c, b, bi, ci);
  part.mesh.addQuad(a, c, ci, ai);
  part.audit = part.mesh.manifoldAudit();
  return part;
}

PVector geodesicRadialInset(PVector point, float distance) {
  PVector result = point == null ? new PVector() : point.copy();
  float localRadius = result.mag();
  if (localRadius > 0.000001f)
    result.normalize().mult(max(0.1f, localRadius - max(0, distance)));
  return result;
}

GeodesicFabricationFace geodesicFabricationFace(GeodesicModel model, GeodesicFace face,
  GeodesicFabricationSettings settings) {
  GeodesicFabricationFace result = new GeodesicFabricationFace();
  result.faceId = face.id;
  result.parentFace = face.parentFace;
  if (settings != null && settings.assemblyMode == GeodesicAssemblyMode.KICAS &&
      settings.kicasPlan != null)
    result.placementLabel = settings.kicasPlan.labelForFace(face.id);
  result.origin = face.centroid.copy();
  result.axisZ = face.normal.copy();
  if (result.axisZ.magSq() < 0.000001f) result.axisZ.set(0, 0, 1);
  result.axisZ.normalize();
  PVector worldA = model.vertices.get(face.a).position;
  PVector worldB = model.vertices.get(face.b).position;
  result.axisX = PVector.sub(worldB, worldA);
  if (result.axisX.magSq() < 0.000001f) result.axisX.set(1, 0, 0);
  result.axisX.normalize();
  result.axisY = result.axisZ.cross(result.axisX);
  if (result.axisY.magSq() < 0.000001f) result.axisY.set(0, 1, 0);
  result.axisY.normalize();

  for (int i = 0; i < 3; i++) {
    int vertexId = face.vertex(i);
    PVector point = geodesicToLocal(model.vertices.get(vertexId).position,
      result.origin, result.axisX, result.axisY, result.axisZ);
    point.z = 0;
    float fabricationScale = settings == null ? 1.0f :
      max(1.0f, settings.fabricationScale);
    point.x *= fabricationScale;
    point.y *= fabricationScale;
    result.boundary.add(point);
    result.vertexIds.add(vertexId);
    result.neighborFaceIds.add(face.neighbors[i]);
  }
  geodesicNormalizeFabricationWinding(result);
  GeodesicFabricationSettings resolved = geodesicResolveFabricationDimensions(result, settings);
  geodesicResolveMiterDepth(model, face, resolved);
  result.resolvedFabrication = resolved;
  for (int i = 0; i < result.vertexCount(); i++)
    result.joints.add(geodesicJointProfile(model, face, result, i, resolved));
  return result;
}

GeodesicFabricationSettings geodesicResolveFabricationDimensions(
  GeodesicFabricationFace face, GeodesicFabricationSettings requested) {
  GeodesicFabricationSettings resolved = requested == null ?
    new GeodesicFabricationSettings() : requested.copy();
  resolved.requestedFrameDepthMM = requested == null ?
    resolved.frameDepthMM : requested.frameDepthMM;
  resolved.miterDepthLimitMM = resolved.frameDepthMM;
  resolved.miterDepthAutoCapped = false;
  if (face == null || face.vertexCount() < 3) return resolved;

  float shortest = Float.MAX_VALUE;
  for (int i = 0; i < face.vertexCount(); i++)
    shortest = min(shortest, PVector.dist(face.boundary.get(i),
      face.boundary.get((i + 1) % face.vertexCount())));
  if (shortest == Float.MAX_VALUE) shortest = 0;
  float apothem = geodesicMinimumCentroidEdgeDistance(face.boundary);
  face.shortestEdgeMM = shortest;
  face.apothemMM = apothem;

  if (resolved.style != GeodesicPanelStyle.SOLID &&
      resolved.kitDimensionsResolved) {
    resolved.frameDepthMM = max(1.2f, resolved.frameDepthMM);
    resolved.frameWidthMM = max(0.8f, resolved.frameWidthMM);
    if (resolved.style == GeodesicPanelStyle.FRAME_SKIN)
      resolved.skinThicknessMM = constrain(resolved.skinThicknessMM, 0.6f,
        max(0.6f, resolved.frameDepthMM - 1.2f));
    else resolved.skinThicknessMM = 0;
    float verticalClearance = resolved.frameDepthMM -
      resolved.skinThicknessMM - 1.2f;
    resolved.portalHeightMM = min(max(1.0f, resolved.portalHeightMM),
      max(1.0f, min(verticalClearance, verticalClearance * 0.42f)));
    resolved.edgeBreakMM = min(max(0, resolved.edgeBreakMM),
      min(0.26f, min(resolved.frameWidthMM * 0.12f,
      resolved.frameDepthMM * 0.08f)));
    resolved.edgeCodeReliefMM = min(max(0.32f, resolved.edgeCodeReliefMM),
      min(0.50f, max(0.38f, resolved.frameWidthMM * 0.22f)));
  } else if (resolved.style != GeodesicPanelStyle.SOLID) {
    // UI values are dimensional ceilings. Small or highly subdivided faces
    // resolve to lighter members while reference-scale panels retain the caps.
    resolved.frameDepthMM = min(max(1.2f, resolved.frameDepthMM),
      max(3.2f, shortest * 0.20f));
    float printableRail = min(1.6f, apothem * 0.42f);
    resolved.frameWidthMM = min(max(0.8f, resolved.frameWidthMM),
      min(apothem * 0.46f, max(printableRail, apothem * 0.30f)));
    if (resolved.style == GeodesicPanelStyle.FRAME_SKIN)
      resolved.skinThicknessMM = min(max(0.6f, resolved.skinThicknessMM),
        max(0.8f, resolved.frameDepthMM * 0.23f));
    else resolved.skinThicknessMM = 0;
    float verticalClearance = resolved.frameDepthMM - resolved.skinThicknessMM - 1.2f;
    resolved.portalHeightMM = min(max(1.0f, resolved.portalHeightMM),
      max(1.0f, min(verticalClearance, verticalClearance * 0.42f)));
    resolved.edgeBreakMM = min(max(0, resolved.edgeBreakMM),
      min(0.26f, min(resolved.frameWidthMM * 0.12f, resolved.frameDepthMM * 0.08f)));
    resolved.edgeCodeReliefMM = min(max(0.32f, resolved.edgeCodeReliefMM),
      min(0.50f, max(0.38f, resolved.frameWidthMM * 0.22f)));
  }
  face.resolvedFabrication = resolved;
  return resolved;
}

GeodesicFabricationSettings geodesicResolveKitFabricationSettings(
  GeodesicModel model, GeodesicFabricationSettings requested) {
  GeodesicFabricationSettings resolved = requested == null ?
    new GeodesicFabricationSettings() : requested.copy();
  if (resolved.assemblyMode == GeodesicAssemblyMode.KICAS) {
    // KICAS changes the joint contract, not the selected panel construction.
    // In particular, OPEN_FRAME must remain a windowed rail-only panel.
    if (resolved.style == GeodesicPanelStyle.FRAME_SKIN)
      resolved.reliefSide = GeodesicReliefSide.INNER_REINFORCEMENT;
    resolved.fastenerPortals = true;
    resolved.desiredPortalsPerEdge = 1;
    resolved.edgeCodesEnabled = false;
    resolved.seamProfile = GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
    if (resolved.kicasPlan == null && model != null)
      resolved.kicasPlan = buildGeodesicKicasPlan(model);
  }
  resolved.kitDimensionsResolved = true;
  resolved.fabricationScale = 1.0f;
  resolved.fabricationScaleAutoRaised = false;
  resolved.effectiveAssemblyRadiusMM = model == null ? 0 : model.radius;
  if (model == null || model.faces.size() == 0 ||
      resolved.style == GeodesicPanelStyle.SOLID) return resolved;

  float minimumApothem = Float.MAX_VALUE;
  float minimumEdge = Float.MAX_VALUE;
  float maximumHalfAngleTangent = 0;
  for (GeodesicFace face : model.faces) {
    PVector center = face.centroid;
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      PVector a = model.vertices.get(face.vertex(edgeIndex)).position;
      PVector b = model.vertices.get(face.vertex((edgeIndex + 1) % 3)).position;
      PVector edge = PVector.sub(b, a);
      float edgeLength = edge.mag();
      minimumEdge = min(minimumEdge, edgeLength);
      if (edgeLength > 0.000001f) {
        float distance = PVector.sub(center, a).cross(edge).mag() / edgeLength;
        minimumApothem = min(minimumApothem, distance);
      }
      int neighborId = face.neighbors[edgeIndex];
      if (neighborId < 0 || neighborId >= model.faces.size()) continue;
      float normalAngle = acos(constrain(
        face.normal.dot(model.faces.get(neighborId).normal), -1, 1));
      maximumHalfAngleTangent = max(maximumHalfAngleTangent,
        tan(normalAngle * 0.5f));
    }
  }
  if (minimumApothem == Float.MAX_VALUE || minimumEdge == Float.MAX_VALUE)
    return resolved;

  float minimumDepth = max(3.2f,
    resolved.style == GeodesicPanelStyle.FRAME_SKIN ?
    resolved.skinThicknessMM + 1.2f : 3.2f);
  float reserve = geodesicMiterRailReserve(resolved) + 0.10f;
  float requiredMiterWidth = maximumHalfAngleTangent < 0.000001f ?
    resolved.frameWidthMM : minimumDepth * maximumHalfAngleTangent + reserve;
  float sharedWidth = max(resolved.frameWidthMM, requiredMiterWidth);
  float sharedDepth = resolved.frameDepthMM;
  if (maximumHalfAngleTangent > 0.000001f)
    sharedDepth = min(sharedDepth,
      max(minimumDepth, (sharedWidth - reserve) / maximumHalfAngleTangent));
  sharedDepth = max(minimumDepth, sharedDepth);

  float requiredApothem = sharedWidth / 0.62f;
  float requiredEdge = max(8.0f, sharedWidth * 2.40f);
  if (resolved.assemblyMode == GeodesicAssemblyMode.KICAS) {
    float centerPortal = max(resolved.portalWidthMM * resolved.kicasPortalScale,
      sharedWidth * 0.82f);
    requiredEdge = max(requiredEdge, centerPortal + resolved.kicasLockLengthMM +
      max(4.0f, sharedWidth * 0.72f));
  }
  float scaleForApothem = requiredApothem / max(0.0001f, minimumApothem);
  float scaleForEdge = requiredEdge / max(0.0001f, minimumEdge);
  float fabricationScale = max(1.0f, max(scaleForApothem, scaleForEdge));
  fabricationScale = ceil(fabricationScale * 20.0f) / 20.0f;

  resolved.frameDepthMM = sharedDepth;
  resolved.requestedFrameDepthMM = requested == null ?
    sharedDepth : requested.frameDepthMM;
  resolved.frameWidthMM = sharedWidth;
  resolved.fabricationScale = fabricationScale;
  resolved.fabricationScaleAutoRaised = fabricationScale > 1.0001f;
  resolved.effectiveAssemblyRadiusMM = model.radius * fabricationScale;
  resolved.miterDepthLimitMM = sharedDepth;
  resolved.miterDepthAutoCapped =
    sharedDepth < resolved.requestedFrameDepthMM - 0.0001f;
  return resolved;
}

float geodesicMiterRailReserve(GeodesicFabricationSettings settings) {
  if (settings == null) return 0.45f;
  return max(0.45f, settings.edgeBreakMM * 2.0f + 0.15f);
}

void geodesicResolveMiterDepth(GeodesicModel model, GeodesicFace sourceFace,
  GeodesicFabricationSettings resolved) {
  if (model == null || sourceFace == null || resolved == null ||
      resolved.style == GeodesicPanelStyle.SOLID ||
      resolved.seamProfile != GeodesicSeamProfile.HALF_DIHEDRAL_MITER) return;
  float maximumHalfAngleTangent = 0;
  for (int i = 0; i < 3; i++) {
    int neighborId = sourceFace.neighbors[i];
    if (neighborId < 0 || neighborId >= model.faces.size()) continue;
    GeodesicFace neighbor = model.faces.get(neighborId);
    float normalAngle = acos(constrain(sourceFace.normal.dot(neighbor.normal), -1, 1));
    maximumHalfAngleTangent = max(maximumHalfAngleTangent, tan(normalAngle * 0.5f));
  }
  if (maximumHalfAngleTangent < 0.000001f) return;

  float availableWidth = max(0, resolved.frameWidthMM - geodesicMiterRailReserve(resolved));
  float limit = availableWidth / maximumHalfAngleTangent;
  resolved.miterDepthLimitMM = max(0, limit);
  float minimumFabricationDepth = 3.2f;
  float cappedDepth = max(minimumFabricationDepth,
    min(resolved.frameDepthMM, resolved.miterDepthLimitMM));
  resolved.miterDepthAutoCapped =
    cappedDepth < resolved.frameDepthMM - 0.0001f;
  resolved.frameDepthMM = cappedDepth;

  if (resolved.style == GeodesicPanelStyle.FRAME_SKIN) {
    float maximumSkin = max(0.6f, resolved.frameDepthMM - 2.2f);
    resolved.skinThicknessMM = constrain(resolved.skinThicknessMM, 0.6f, maximumSkin);
  } else resolved.skinThicknessMM = 0;
  float verticalClearance = resolved.frameDepthMM -
    resolved.skinThicknessMM - 1.2f;
  resolved.portalHeightMM = min(max(1.0f, resolved.portalHeightMM),
    max(1.0f, min(verticalClearance, verticalClearance * 0.42f)));
}

void geodesicNormalizeFabricationWinding(GeodesicFabricationFace face) {
  if (geodesicPolygonArea(face.boundary) >= 0) return;
  int n = face.boundary.size();
  ArrayList<PVector> reversedBoundary = new ArrayList<PVector>();
  ArrayList<Integer> reversedVertices = new ArrayList<Integer>();
  ArrayList<Integer> reversedNeighbors = new ArrayList<Integer>();
  for (int i = 0; i < n; i++) {
    reversedBoundary.add(face.boundary.get(n - 1 - i));
    reversedVertices.add(face.vertexIds.get(n - 1 - i));
    int oldEdge = (n - 2 - i + n) % n;
    reversedNeighbors.add(face.neighborFaceIds.get(oldEdge));
  }
  face.boundary = reversedBoundary;
  face.vertexIds = reversedVertices;
  face.neighborFaceIds = reversedNeighbors;
}

GeodesicJointEdgeProfile geodesicJointProfile(GeodesicModel model, GeodesicFace sourceFace,
  GeodesicFabricationFace face, int edgeIndex, GeodesicFabricationSettings settings) {
  GeodesicJointEdgeProfile profile = new GeodesicJointEdgeProfile();
  profile.edgeIndex = edgeIndex;
  profile.neighborFaceId = face.neighborFaceIds.get(edgeIndex);
  PVector a = face.boundary.get(edgeIndex);
  PVector b = face.boundary.get((edgeIndex + 1) % face.vertexCount());
  profile.edgeLengthMM = PVector.dist(a, b);
  profile.junctionBisector = sourceFace.normal.copy();
  if (profile.neighborFaceId >= 0 && profile.neighborFaceId < model.faces.size()) {
    GeodesicFace neighbor = model.faces.get(profile.neighborFaceId);
    float dotNormals = constrain(sourceFace.normal.dot(neighbor.normal), -1, 1);
    profile.normalAngleDeg = degrees(acos(dotNormals));
    profile.interiorDihedralDeg = 180.0f - profile.normalAngleDeg;
    profile.plateauDeviationDeg = abs(profile.interiorDihedralDeg - geodesicPlateauAngleDegrees());
    profile.junctionBisector.add(neighbor.normal);
  }
  if (profile.junctionBisector.magSq() < 0.000001f) profile.junctionBisector.set(sourceFace.normal);
  profile.junctionBisector.normalize();
  if (profile.neighborFaceId >= 0 &&
      profile.neighborFaceId < model.faces.size()) {
    int vertexA = face.vertexIds.get(edgeIndex);
    int vertexB = face.vertexIds.get((edgeIndex + 1) % face.vertexCount());
    profile.concaveJoint = geodesicSharedEdgeConcave(model, sourceFace,
      model.faces.get(profile.neighborFaceId), vertexA, vertexB);
    profile.miterInsetSign = profile.concaveJoint ? -1.0f : 1.0f;
  }
  if (profile.normalAngleDeg > 0) {
    profile.recommendedHalfMiterDeg = profile.normalAngleDeg * 0.5f;
    profile.recommendedMiterInsetMM = settings.frameDepthMM *
      tan(radians(profile.recommendedHalfMiterDeg));
    profile.miterFeasibleAtResolvedDimensions =
      profile.recommendedMiterInsetMM <= max(0,
        settings.frameWidthMM - geodesicMiterRailReserve(settings)) + 0.0001f;
  }
  // Mate codes describe the source shell topology, not the fabrication scale.
  // Keep portal and joint dimensions in scaled millimeters while classifying
  // reciprocal edges against the unscaled model used by the code registry.
  float logicalEdgeLengthMM = profile.edgeLengthMM /
    max(1.0f, settings.fabricationScale);
  profile.compatibilityKey = geodesicEdgeCompatibilityKey(logicalEdgeLengthMM,
    profile.interiorDihedralDeg, profile.neighborFaceId < 0,
    profile.concaveJoint);
  profile.mateCode = settings.edgeCodesEnabled ?
    geodesicEdgeCompatibilityCode(model, profile.compatibilityKey) : "";
  geodesicSchedulePortals(profile, settings);
  geodesicConfigureKicasJoint(face, profile, settings);
  return profile;
}

String geodesicEdgeCompatibilityKey(float edgeLengthMM, float interiorDihedralDeg,
  boolean boundary) {
  return geodesicEdgeCompatibilityKey(edgeLengthMM, interiorDihedralDeg,
    boundary, false);
}

String geodesicEdgeCompatibilityKey(float edgeLengthMM, float interiorDihedralDeg,
  boolean boundary, boolean concave) {
  if (boundary) return "RIM";
  int lengthClass = round(edgeLengthMM * 20.0f);
  int dihedralClass = round(max(0, interiorDihedralDeg) * 10.0f);
  return "L" + lengthClass + "_D" + dihedralClass +
    (concave ? "_C" : "");
}

String geodesicModelEdgeCompatibilityKey(GeodesicModel model, GeodesicEdge edge) {
  if (model == null || edge == null || edge.faceA < 0 || edge.faceB < 0) return "RIM";
  float length = PVector.dist(model.vertices.get(edge.a).position,
    model.vertices.get(edge.b).position);
  GeodesicFace a = model.faces.get(edge.faceA);
  GeodesicFace b = model.faces.get(edge.faceB);
  float normalAngle = degrees(acos(constrain(a.normal.dot(b.normal), -1, 1)));
  return geodesicEdgeCompatibilityKey(length, 180.0f - normalAngle, false,
    geodesicSharedEdgeConcave(model, a, b, edge.a, edge.b));
}

boolean geodesicSharedEdgeConcave(GeodesicModel model, GeodesicFace faceA,
  GeodesicFace faceB, int vertexA, int vertexB) {
  if (model == null || faceA == null || faceB == null ||
      vertexA < 0 || vertexA >= model.vertices.size() ||
      vertexB < 0 || vertexB >= model.vertices.size()) return false;
  PVector edgeMid = PVector.add(model.vertices.get(vertexA).position,
    model.vertices.get(vertexB).position).mult(0.5f);
  float sideA = PVector.sub(faceB.centroid, edgeMid).dot(faceA.normal);
  float sideB = PVector.sub(faceA.centroid, edgeMid).dot(faceB.normal);
  float epsilon = max(0.0001f, model.radius * 0.000001f);
  return sideA > epsilon || sideB > epsilon;
}

String geodesicEdgeCompatibilityCode(GeodesicModel model, String key) {
  if (key == null || key.length() == 0) return "";
  if (key.equals("RIM")) return "RIM";
  HashSet<String> unique = new HashSet<String>();
  if (model != null) for (GeodesicEdge edge : model.edges) {
    String candidate = geodesicModelEdgeCompatibilityKey(model, edge);
    if (!candidate.equals("RIM")) unique.add(candidate);
  }
  ArrayList<String> sorted = new ArrayList<String>(unique);
  java.util.Collections.sort(sorted);
  int index = sorted.indexOf(key);
  return index < 0 ? "?" : geodesicAlphabeticCode(index);
}

String geodesicAlphabeticCode(int zeroBasedIndex) {
  int value = max(0, zeroBasedIndex) + 1;
  String result = "";
  while (value > 0) {
    value--;
    result = str((char)('A' + value % 26)) + result;
    value /= 26;
  }
  return result;
}

void geodesicSchedulePortals(GeodesicJointEdgeProfile profile, GeodesicFabricationSettings settings) {
  profile.portalCenters.clear();
  float edgeRelativeWidth = max(2.4f, profile.edgeLengthMM * 0.18f);
  float requestedPortalWidth = settings.assemblyMode == GeodesicAssemblyMode.KICAS ?
    settings.portalWidthMM * max(1.0f, settings.kicasPortalScale) :
    settings.portalWidthMM;
  profile.portalWidthMM = min(requestedPortalWidth,
    min(edgeRelativeWidth, max(0, profile.edgeLengthMM - 2.0f)));
  // Shared-edge placement must be independent of either panel's rail width so
  // reciprocal faces receive exactly the same portal schedule.
  float baseClearance = max(profile.portalWidthMM * 0.65f,
    min(2.2f, profile.edgeLengthMM * 0.08f));
  float bubbleFactor = 1.0f;
  if (settings.bubbleJoinEnabled && profile.plateauDeviationDeg >= 0)
    bubbleFactor += settings.bubbleClearanceStrength *
      constrain(profile.plateauDeviationDeg / geodesicPlateauAngleDegrees(), 0, 1);
  profile.cornerClearanceMM = baseClearance * bubbleFactor;
  boolean verticalFit = settings.frameDepthMM >= settings.portalHeightMM +
    (settings.style == GeodesicPanelStyle.FRAME_SKIN ? settings.skinThicknessMM + 1.2f : 1.2f);
  if (!settings.fastenerPortals || settings.style == GeodesicPanelStyle.SOLID ||
      settings.desiredPortalsPerEdge <= 0 || profile.portalWidthMM < 2.0f || !verticalFit) return;

  if (settings.assemblyMode == GeodesicAssemblyMode.KICAS) {
    profile.portalCenters.add(0.5f);
    return;
  }

  float maxClearance = max(0.8f, (profile.edgeLengthMM - profile.portalWidthMM) * 0.5f);
  float clearance = min(profile.cornerClearanceMM, maxClearance);
  float available = profile.edgeLengthMM - 2.0f * clearance;
  float gap = max(1.2f, profile.portalWidthMM * 0.65f);
  if (settings.desiredPortalsPerEdge >= 2 &&
      available >= 2.0f * profile.portalWidthMM + gap) {
    float center = (clearance + profile.portalWidthMM * 0.5f) / profile.edgeLengthMM;
    profile.portalCenters.add(constrain(center, 0.08f, 0.42f));
    profile.portalCenters.add(constrain(1.0f - center, 0.58f, 0.92f));
  } else if (available >= profile.portalWidthMM ||
             profile.edgeLengthMM >= profile.portalWidthMM + 1.6f) {
    profile.portalCenters.add(0.5f);
  }
}

GeodesicPart buildGeodesicFabricatedPart(GeodesicModel model, GeodesicFace face,
  GeodesicFabricationSettings settings, GeodesicGrowthMode growthMode, float relief) {
  GeodesicPart part = new GeodesicPart();
  part.faceId = face.id;
  part.parentFace = face.parentFace;
  part.neighbors = face.neighbors.clone();
  part.fabricationFace = geodesicFabricationFace(model, face, settings);
  part.fabrication = part.fabricationFace.resolvedFabrication == null ?
    settings.copy() : part.fabricationFace.resolvedFabrication.copy();
  part.mesh = buildGeodesicFabricationMesh(part.fabricationFace, part.fabrication,
    growthMode, relief);
  part.audit = part.mesh.manifoldAudit();
  return part;
}

SurfaceMesh buildGeodesicFabricationMesh(GeodesicFabricationFace face,
  GeodesicFabricationSettings settings, GeodesicGrowthMode growthMode, float relief) {
  SurfaceMesh mesh = new SurfaceMesh("geodesic_fabricated_panel");
  if (face == null || face.vertexCount() < 3) return mesh;
  GeodesicFabricationSettings resolved = face.resolvedFabrication == null ?
    geodesicResolveFabricationDimensions(face, settings) : face.resolvedFabrication;
  ArrayList<PVector> outer = geodesicCopyPolygon(face.boundary);
  geodesicEnsureJointProfiles(face, resolved);
  if (resolved.style == GeodesicPanelStyle.SOLID) {
    geodesicAddSolidPolygon(mesh, outer, max(0.8f, resolved.skinThicknessMM),
      growthMode == GeodesicGrowthMode.CENTER_TO_EDGE ? max(0, relief) : 0);
    return mesh;
  }

  float apothem = geodesicMinimumCentroidEdgeDistance(outer);
  float frameWidth = constrain(resolved.frameWidthMM, 0.8f, max(0.9f, apothem * 0.72f));
  ArrayList<PVector> inner = geodesicInsetConvexPolygon(outer, frameWidth);
  if (inner == null || inner.size() != outer.size() ||
      abs(geodesicPolygonArea(inner)) < 0.01f) {
    inner = geodesicScalePolygonFromCentroid(outer,
      constrain(1.0f - frameWidth / max(0.001f, apothem), 0.18f, 0.82f));
  }
  float depth = max(1.2f, resolved.frameDepthMM);
  float skin = resolved.style == GeodesicPanelStyle.FRAME_SKIN ?
    constrain(resolved.skinThicknessMM, 0.6f, depth - 0.8f) : 0;
  boolean exteriorCrown = resolved.style == GeodesicPanelStyle.FRAME_SKIN &&
    resolved.reliefSide == GeodesicReliefSide.EXTERIOR_CROWN;
  float membraneBottom = exteriorCrown ? depth - skin : 0;
  float membraneTop = exteriorCrown ? depth : skin;
  float innerWallBottom = exteriorCrown ? 0 : skin;
  float innerWallTop = exteriorCrown ? depth - skin : depth;
  float innerWallSpan = max(1.2f, innerWallTop - innerWallBottom);
  float slotHeight = constrain(resolved.portalHeightMM, 1.0f,
    max(1.0f, innerWallSpan - 1.2f));
  float slotBottom = innerWallBottom + max(0.6f,
    (innerWallSpan - slotHeight) * 0.5f);
  float slotTop = min(innerWallTop - 0.6f, slotBottom + slotHeight);
  float edgeBreak = constrain(resolved.edgeBreakMM, 0,
    min(0.26f, min(frameWidth * 0.12f, depth * 0.08f)));
  ArrayList<PVector> outerChamfer = edgeBreak > 0.001f ?
    geodesicInsetConvexPolygon(outer, edgeBreak) : geodesicCopyPolygon(outer);
  ArrayList<PVector> innerTopChamfer = edgeBreak > 0.001f ?
    geodesicInsetConvexPolygon(outer, max(0.01f, frameWidth - edgeBreak)) :
    geodesicCopyPolygon(inner);
  if (outerChamfer == null || outerChamfer.size() != outer.size())
    outerChamfer = geodesicCopyPolygon(outer);
  if (innerTopChamfer == null || innerTopChamfer.size() != inner.size())
    innerTopChamfer = geodesicCopyPolygon(inner);
  boolean mitered = resolved.seamProfile ==
    GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
  boolean kicas = resolved.assemblyMode == GeodesicAssemblyMode.KICAS;
  GeodesicMiterOuterProfile miterProfile = mitered ?
    geodesicBuildMiterOuterProfile(face, outer, depth, edgeBreak) : null;
  if (mitered && (miterProfile == null || !miterProfile.valid(outer.size())))
    return mesh;
  ArrayList<PVector> bottomOuter = mitered ?
    miterProfile.bottomCap : outerChamfer;
  ArrayList<PVector> topOuter = mitered ?
    miterProfile.topCap : outerChamfer;

  int n = outer.size();
  ArrayList<PVector> subdividedInnerBase = new ArrayList<PVector>();
  ArrayList<PVector> subdividedInnerTop = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector outerA = outer.get(i);
    PVector outerB = outer.get((i + 1) % n);
    PVector innerA = inner.get(i);
    PVector innerB = inner.get((i + 1) % n);
    PVector outerChamferA = outerChamfer.get(i);
    PVector outerChamferB = outerChamfer.get((i + 1) % n);
    PVector bottomOuterA = bottomOuter.get(i);
    PVector bottomOuterB = bottomOuter.get((i + 1) % n);
    PVector topOuterA = topOuter.get(i);
    PVector topOuterB = topOuter.get((i + 1) % n);
    PVector innerTopA = innerTopChamfer.get(i);
    PVector innerTopB = innerTopChamfer.get((i + 1) % n);
    GeodesicJointEdgeProfile joint = face.joints.get(i);
    ArrayList<float[]> slots = geodesicPortalIntervals(joint);
    ArrayList<Float> structuralBreaks = geodesicEdgeBreaks(slots);
    if (kicas) {
      for (float station : geodesicKicasEdgeBreaks(joint))
        geodesicAddUniqueBreak(structuralBreaks, station);
      java.util.Collections.sort(structuralBreaks);
    }
    float railCodeRelief = resolved.style == GeodesicPanelStyle.OPEN_FRAME &&
      resolved.edgeCodesEnabled ? resolved.edgeCodeReliefMM : 0;
    boolean railPlacementSurface = kicas &&
      (resolved.style == GeodesicPanelStyle.OPEN_FRAME ||
       (resolved.style == GeodesicPanelStyle.FRAME_SKIN && !exteriorCrown));
    boolean railPlacementCode = railPlacementSurface && i == 0 &&
      face.placementLabel.length() > 0;
    ArrayList<Float> breaks = railPlacementCode ?
      geodesicCodedRailTBreaksMark(topOuterA, topOuterB,
        innerTopA, innerTopB, structuralBreaks, face.placementLabel,
        resolved.edgeCodeReliefMM, GEODESIC_KICAS_PLACEMENT_CELL_CAP_MM,
        GEODESIC_KICAS_PLACEMENT_FIT_FRACTION,
        GEODESIC_KICAS_PLACEMENT_RAIL_FRACTION) :
      geodesicCodedRailTBreaks(topOuterA, topOuterB,
        innerTopA, innerTopB, structuralBreaks, joint.mateCode,
        railCodeRelief);
    if (!kicas && resolved.style == GeodesicPanelStyle.FRAME_SKIN &&
        resolved.edgeCodesEnabled) {
      geodesicAddInteriorCodeEdgeBreaks(breaks, inner, i, joint.mateCode);
      java.util.Collections.sort(breaks);
    } else if (kicas && exteriorCrown && i == 0 &&
        face.placementLabel.length() > 0) {
      // Crown labels modify the membrane boundary. Rail labels already add
      // their exact stations through geodesicCodedRailTBreaksMark().
      geodesicAddInteriorPlacementEdgeBreaks(breaks, inner, i,
        face.placementLabel);
      java.util.Collections.sort(breaks);
    }
    for (int j = 0; j < breaks.size() - 1; j++) {
      float start = breaks.get(j);
      float end = breaks.get(j + 1);
      boolean portal = geodesicIntervalIsPortal(start, end, slots);
      boolean codedOpenFrameBottom = resolved.style == GeodesicPanelStyle.OPEN_FRAME &&
        resolved.edgeCodesEnabled;
      if (!exteriorCrown && !codedOpenFrameBottom) {
        if (kicas)
          geodesicAddKicasRailFaceInterval(mesh, face, miterProfile, joint,
            resolved, i, innerA, innerB, start, end, 0, false);
        else
          geodesicAddFrameRailFaceInterval(mesh, bottomOuterA, bottomOuterB,
            innerA, innerB, start, end, 0, false);
      }
      if (portal) {
        if (kicas)
          geodesicAddKicasFramePortalInterval(mesh, face, miterProfile,
            joint, resolved, i, innerA, innerB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak,
            geodesicIntervalStartsPortal(start, slots),
            geodesicIntervalEndsPortal(end, slots));
        else if (mitered)
          geodesicAddMiterFramePortalInterval(mesh, miterProfile, i,
            innerA, innerB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak,
            geodesicIntervalStartsPortal(start, slots),
            geodesicIntervalEndsPortal(end, slots));
        else
          geodesicAddFramePortalInterval(mesh, outerA, outerB, innerA, innerB,
            outerChamferA, outerChamferB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak,
            geodesicIntervalStartsPortal(start, slots),
            geodesicIntervalEndsPortal(end, slots));
      } else {
        if (kicas)
          geodesicAddKicasFrameWallInterval(mesh, face, miterProfile,
            joint, resolved, i, innerA, innerB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak);
        else if (mitered)
          geodesicAddMiterFrameWallInterval(mesh, miterProfile, i,
            innerA, innerB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak);
        else
          geodesicAddFrameWallInterval(mesh, outerA, outerB, innerA, innerB,
            outerChamferA, outerChamferB, innerTopA, innerTopB,
            start, end, innerWallBottom, innerWallTop, depth,
            slotBottom, slotTop, edgeBreak);
      }
      subdividedInnerBase.add(geodesicEdgePoint(innerA, innerB, start, 0));
      subdividedInnerTop.add(geodesicEdgePoint(innerTopA, innerTopB, start, 0));
    }
    float codeRelief = resolved.edgeCodesEnabled ? resolved.edgeCodeReliefMM : 0;
    if (kicas) {
      if (railPlacementSurface)
        geodesicAddKicasCodedTopRail(mesh, face, miterProfile, joint,
          resolved, i, innerTopA, innerTopB, breaks,
          railPlacementCode ? face.placementLabel : "", depth,
          railPlacementCode ? resolved.edgeCodeReliefMM : 0);
      else for (int j = 0; j < breaks.size() - 1; j++) {
        float start = breaks.get(j);
        float end = breaks.get(j + 1);
        geodesicAddKicasRailFaceInterval(mesh, face, miterProfile, joint,
          resolved, i, innerTopA, innerTopB, start, end, depth, true);
        // Exterior-crown panels keep their membrane at the top of the frame.
        // Close the matching lower rail explicitly; without it, the KICAS
        // branch leaves the inner perimeter open at z=0.
        if (exteriorCrown)
          geodesicAddKicasRailFaceInterval(mesh, face, miterProfile, joint,
            resolved, i, innerA, innerB, start, end, 0, false);
      }
    } else if (resolved.style == GeodesicPanelStyle.OPEN_FRAME && resolved.edgeCodesEnabled) {
      geodesicAddCodedBottomRail(mesh, bottomOuterA, bottomOuterB,
        innerA, innerB, breaks, joint.mateCode, 0);
      geodesicAddCodedTopRail(mesh, topOuterA, topOuterB,
        innerTopA, innerTopB, breaks, joint.mateCode, depth, codeRelief);
    } else {
      geodesicAddCodedTopRail(mesh, topOuterA, topOuterB,
        innerTopA, innerTopB, breaks, joint.mateCode, depth, 0);
      if (exteriorCrown)
        geodesicAddCodedBottomRail(mesh, bottomOuterA, bottomOuterB,
          innerA, innerB, breaks, joint.mateCode, 0);
    }
  }
  if (skin > 0) {
    // Exterior crown is a fabrication treatment, so its apex remains present
    // in either growth visualization. The preserved inner treatment continues
    // to receive relief only from CENTER > EDGE, as before.
    float centerRelief = exteriorCrown ||
      growthMode == GeodesicGrowthMode.CENTER_TO_EDGE ? max(0, relief) : 0;
    ArrayList<PVector> topBoundary = exteriorCrown ?
      subdividedInnerTop : subdividedInnerBase;
    // The assembly interior is the cavity/reinforcement face. It is the upper
    // membrane face for INNER REINFORCEMENT and the lower face opposite an
    // EXTERIOR CROWN. Keep the other face mathematically clean.
    boolean codeOnTop = !exteriorCrown;
    boolean placementCode = kicas && exteriorCrown &&
      face.placementLabel.length() > 0;
    boolean membraneEdgeCodes = !kicas && resolved.edgeCodesEnabled;
    if ((membraneEdgeCodes || placementCode) && codeOnTop) {
      geodesicAddPolygonFan(mesh, subdividedInnerBase, membraneBottom, false, 0);
      geodesicAddCodedInteriorMembrane(mesh, topBoundary, inner,
        face.joints, membraneTop, resolved.edgeCodeReliefMM, true, centerRelief,
        placementCode ? face.placementLabel : "");
    } else if (membraneEdgeCodes || placementCode) {
      geodesicAddCodedInteriorMembrane(mesh, subdividedInnerBase, inner,
        face.joints, membraneBottom, resolved.edgeCodeReliefMM, false, 0,
        placementCode ? face.placementLabel : "");
      geodesicAddPolygonFan(mesh, topBoundary, membraneTop, true, centerRelief);
    } else {
      geodesicAddPolygonFan(mesh, subdividedInnerBase, membraneBottom, false, 0);
      geodesicAddPolygonFan(mesh, topBoundary, membraneTop, true, centerRelief);
    }
  }
  return mesh;
}

ArrayList<Float> geodesicEdgeBreaks(ArrayList<float[]> slots) {
  ArrayList<Float> result = new ArrayList<Float>();
  result.add(0.0f);
  for (float[] slot : slots) {
    if (slot[0] > result.get(result.size() - 1) + 0.0001f) result.add(slot[0]);
    if (slot[1] > result.get(result.size() - 1) + 0.0001f) result.add(slot[1]);
  }
  if (result.get(result.size() - 1) < 0.9999f) result.add(1.0f);
  return result;
}

boolean geodesicIntervalIsPortal(float start, float end, ArrayList<float[]> slots) {
  float midpoint = (start + end) * 0.5f;
  for (float[] slot : slots)
    if (midpoint > slot[0] - 0.0001f && midpoint < slot[1] + 0.0001f) return true;
  return false;
}

boolean geodesicIntervalStartsPortal(float value, ArrayList<float[]> slots) {
  for (float[] slot : slots) if (abs(value - slot[0]) < 0.0001f) return true;
  return false;
}

boolean geodesicIntervalEndsPortal(float value, ArrayList<float[]> slots) {
  for (float[] slot : slots) if (abs(value - slot[1]) < 0.0001f) return true;
  return false;
}

void geodesicAddFrameRailFaceInterval(SurfaceMesh mesh, PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, float start, float end, float z, boolean top) {
  if (end - start < 0.0001f) return;
  PVector oa = geodesicEdgePoint(outerA, outerB, start, z);
  PVector ob = geodesicEdgePoint(outerA, outerB, end, z);
  PVector ia = geodesicEdgePoint(innerA, innerB, start, z);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, z);
  if (top) mesh.addQuad(oa, ob, ib, ia);
  else mesh.addQuad(oa, ia, ib, ob);
}

GeodesicMiterOuterProfile geodesicBuildMiterOuterProfile(
  GeodesicFabricationFace face, ArrayList<PVector> outer,
  float depth, float edgeBreak) {
  if (face == null || outer == null || outer.size() < 3 ||
      face.joints.size() != outer.size()) return null;
  GeodesicMiterOuterProfile profile = new GeodesicMiterOuterProfile();
  profile.depth = depth;
  profile.edgeBreak = constrain(edgeBreak, 0, depth * 0.20f);
  profile.exteriorAtTop = face.resolvedFabrication != null &&
    face.resolvedFabrication.style == GeodesicPanelStyle.FRAME_SKIN &&
    face.resolvedFabrication.reliefSide == GeodesicReliefSide.EXTERIOR_CROWN;
  int n = outer.size();
  float lowerZ = profile.edgeBreak;
  float upperZ = depth - profile.edgeBreak;
  float[] bottomOffsets = new float[n];
  float[] lowerOffsets = new float[n];
  float[] upperOffsets = new float[n];
  float[] topOffsets = new float[n];
  for (int i = 0; i < n; i++) {
    GeodesicJointEdgeProfile joint = face.joints.get(i);
    float slope = joint.neighborFaceId < 0 ? 0 :
      joint.miterInsetSign *
      tan(radians(max(0, joint.recommendedHalfMiterDeg)));
    if (profile.exteriorAtTop) {
      bottomOffsets[i] = depth * slope + profile.edgeBreak;
      lowerOffsets[i] = (depth - lowerZ) * slope;
      upperOffsets[i] = (depth - upperZ) * slope;
      topOffsets[i] = profile.edgeBreak;
    } else {
      bottomOffsets[i] = profile.edgeBreak;
      lowerOffsets[i] = lowerZ * slope;
      upperOffsets[i] = upperZ * slope;
      topOffsets[i] = depth * slope + profile.edgeBreak;
    }
  }
  profile.bottomCap = geodesicInsetConvexPolygonVariable(outer, bottomOffsets);
  profile.lowerMiter = geodesicInsetConvexPolygonVariable(outer, lowerOffsets);
  profile.upperMiter = geodesicInsetConvexPolygonVariable(outer, upperOffsets);
  profile.topCap = geodesicInsetConvexPolygonVariable(outer, topOffsets);
  if (!profile.valid(n) ||
      abs(geodesicPolygonArea(profile.bottomCap)) < 0.01f ||
      abs(geodesicPolygonArea(profile.topCap)) < 0.01f) return null;
  return profile;
}

PVector geodesicMiterOuterPoint(GeodesicMiterOuterProfile profile,
  int edgeIndex, float t, float z) {
  int n = profile.bottomCap.size();
  int next = (edgeIndex + 1) % n;
  float depth = max(0.0001f, profile.depth);
  if (z <= 0.000001f)
    return geodesicEdgePoint(profile.bottomCap.get(edgeIndex),
      profile.bottomCap.get(next), t, 0);
  if (z >= depth - 0.000001f)
    return geodesicEdgePoint(profile.topCap.get(edgeIndex),
      profile.topCap.get(next), t, depth);
  float edgeBreak = constrain(profile.edgeBreak, 0, depth * 0.20f);
  PVector a;
  PVector b;
  float blend;
  if (edgeBreak > 0.0001f && z < edgeBreak) {
    a = PVector.lerp(profile.bottomCap.get(edgeIndex),
      profile.lowerMiter.get(edgeIndex), constrain(z / edgeBreak, 0, 1));
    b = PVector.lerp(profile.bottomCap.get(next),
      profile.lowerMiter.get(next), constrain(z / edgeBreak, 0, 1));
  } else if (edgeBreak > 0.0001f && z > depth - edgeBreak) {
    blend = constrain((z - (depth - edgeBreak)) / edgeBreak, 0, 1);
    a = PVector.lerp(profile.upperMiter.get(edgeIndex),
      profile.topCap.get(edgeIndex), blend);
    b = PVector.lerp(profile.upperMiter.get(next),
      profile.topCap.get(next), blend);
  } else {
    float span = max(0.0001f, depth - edgeBreak * 2.0f);
    blend = constrain((z - edgeBreak) / span, 0, 1);
    a = PVector.lerp(profile.lowerMiter.get(edgeIndex),
      profile.upperMiter.get(edgeIndex), blend);
    b = PVector.lerp(profile.lowerMiter.get(next),
      profile.upperMiter.get(next), blend);
  }
  float edgeT = constrain(t, 0, 1);
  PVector result;
  if (edgeT <= 0.000001f) result = a.copy();
  else if (edgeT >= 0.999999f) result = b.copy();
  else result = PVector.lerp(a, b, edgeT);
  result.z = z;
  return result;
}

ArrayList<Float> geodesicMiterLevels(float bottom, float top,
  GeodesicMiterOuterProfile profile) {
  ArrayList<Float> levels = new ArrayList<Float>();
  levels.add(bottom);
  float lower = profile.edgeBreak;
  float upper = profile.depth - profile.edgeBreak;
  if (lower > bottom + 0.0001f && lower < top - 0.0001f) levels.add(lower);
  if (upper > bottom + 0.0001f && upper < top - 0.0001f) levels.add(upper);
  levels.add(top);
  java.util.Collections.sort(levels);
  return levels;
}

void geodesicAddMiterOuterWallBand(SurfaceMesh mesh,
  GeodesicMiterOuterProfile profile, int edgeIndex, float start, float end,
  float bottom, float top) {
  if (top - bottom < 0.0001f) return;
  ArrayList<Float> levels = geodesicMiterLevels(bottom, top, profile);
  for (int i = 0; i < levels.size() - 1; i++) {
    float z0 = levels.get(i);
    float z1 = levels.get(i + 1);
    PVector a0 = geodesicMiterOuterPoint(profile, edgeIndex, start, z0);
    PVector b0 = geodesicMiterOuterPoint(profile, edgeIndex, end, z0);
    PVector a1 = geodesicMiterOuterPoint(profile, edgeIndex, start, z1);
    PVector b1 = geodesicMiterOuterPoint(profile, edgeIndex, end, z1);
    mesh.addQuad(a0, b0, b1, a1);
  }
}

void geodesicAddMiterFrameWallInterval(SurfaceMesh mesh,
  GeodesicMiterOuterProfile profile, int edgeIndex,
  PVector innerA, PVector innerB, PVector innerTopA, PVector innerTopB,
  float start, float end, float innerWallBottom, float innerWallTop,
  float depth, float slotBottom, float slotTop, float edgeBreak) {
  if (end - start < 0.0001f) return;
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);
  geodesicAddMiterOuterWallBand(mesh, profile, edgeIndex, start, end,
    0, slotBottom);
  geodesicAddMiterOuterWallBand(mesh, profile, edgeIndex, start, end,
    slotBottom, slotTop);
  geodesicAddMiterOuterWallBand(mesh, profile, edgeIndex, start, end,
    slotTop, depth);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
    min(slotBottom, innerWallTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotBottom), min(innerWallTop, slotTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotTop), innerWallTop, depth, edgeBreak);
}

/*
 * The rail faces, outer/inner walls, and portal tunnel all share the same
 * interval endpoints. This avoids T-junctions at portal boundaries and keeps
 * each generated panel a closed 2-manifold.
 */
void geodesicAddFrameWallInterval(SurfaceMesh mesh, PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, PVector outerChamferA, PVector outerChamferB,
  PVector innerTopA, PVector innerTopB, float start, float end,
  float innerWallBottom, float innerWallTop, float depth,
  float slotBottom, float slotTop, float edgeBreak) {
  if (end - start < 0.0001f) return;
  PVector oa = geodesicEdgePoint(outerA, outerB, start, 0);
  PVector ob = geodesicEdgePoint(outerA, outerB, end, 0);
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector oca = geodesicEdgePoint(outerChamferA, outerChamferB, start, 0);
  PVector ocb = geodesicEdgePoint(outerChamferA, outerChamferB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);
  geodesicAddOuterWallBand(mesh, oa, ob, oca, ocb, 0, slotBottom, depth, edgeBreak);
  geodesicAddOuterWallBand(mesh, oa, ob, oca, ocb, slotBottom, slotTop, depth, edgeBreak);
  geodesicAddOuterWallBand(mesh, oa, ob, oca, ocb, slotTop, depth, depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
    min(slotBottom, innerWallTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotBottom), min(innerWallTop, slotTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotTop), innerWallTop, depth, edgeBreak);
}

void geodesicAddOuterWallBand(SurfaceMesh mesh, PVector a, PVector b,
  PVector chamferA, PVector chamferB, float bottom, float top,
  float depth, float edgeBreak) {
  if (top - bottom < 0.0001f) return;
  ArrayList<Float> levels = geodesicChamferLevels(bottom, top, depth, edgeBreak, true);
  for (int i = 0; i < levels.size() - 1; i++) {
    float z0 = levels.get(i);
    float z1 = levels.get(i + 1);
    PVector a0 = geodesicOuterChamferPoint(a, chamferA, z0, depth, edgeBreak);
    PVector b0 = geodesicOuterChamferPoint(b, chamferB, z0, depth, edgeBreak);
    PVector a1 = geodesicOuterChamferPoint(a, chamferA, z1, depth, edgeBreak);
    PVector b1 = geodesicOuterChamferPoint(b, chamferB, z1, depth, edgeBreak);
    mesh.addQuad(a0, b0, b1, a1);
  }
}

void geodesicAddInnerWallBand(SurfaceMesh mesh, PVector a, PVector b,
  PVector topA, PVector topB, float bottom, float top,
  float depth, float edgeBreak) {
  if (top - bottom < 0.0001f) return;
  ArrayList<Float> levels = geodesicChamferLevels(bottom, top, depth, edgeBreak, false);
  for (int i = 0; i < levels.size() - 1; i++) {
    float z0 = levels.get(i);
    float z1 = levels.get(i + 1);
    PVector a0 = geodesicInnerChamferPoint(a, topA, z0, depth, edgeBreak);
    PVector b0 = geodesicInnerChamferPoint(b, topB, z0, depth, edgeBreak);
    PVector a1 = geodesicInnerChamferPoint(a, topA, z1, depth, edgeBreak);
    PVector b1 = geodesicInnerChamferPoint(b, topB, z1, depth, edgeBreak);
    mesh.addQuad(a0, a1, b1, b0);
  }
}

ArrayList<Float> geodesicChamferLevels(float bottom, float top, float depth,
  float edgeBreak, boolean bothEnds) {
  ArrayList<Float> levels = new ArrayList<Float>();
  levels.add(bottom);
  if (edgeBreak > 0.0001f) {
    if (bothEnds && edgeBreak > bottom + 0.0001f && edgeBreak < top - 0.0001f)
      levels.add(edgeBreak);
    float upper = depth - edgeBreak;
    if (upper > bottom + 0.0001f && upper < top - 0.0001f) levels.add(upper);
  }
  levels.add(top);
  java.util.Collections.sort(levels);
  return levels;
}

PVector geodesicOuterChamferPoint(PVector base, PVector inset, float z,
  float depth, float edgeBreak) {
  PVector result;
  if (edgeBreak > 0.0001f && z <= 0.000001f)
    result = inset.copy();
  else if (edgeBreak > 0.0001f && z >= depth - 0.000001f)
    result = inset.copy();
  else if (edgeBreak > 0.0001f && z < edgeBreak)
    result = PVector.lerp(inset, base, constrain(z / edgeBreak, 0, 1));
  else if (edgeBreak > 0.0001f && z > depth - edgeBreak)
    result = PVector.lerp(base, inset,
      constrain((z - (depth - edgeBreak)) / edgeBreak, 0, 1));
  else result = base.copy();
  result.z = z;
  return result;
}

PVector geodesicInnerChamferPoint(PVector base, PVector inset, float z,
  float depth, float edgeBreak) {
  PVector result;
  if (edgeBreak > 0.0001f && z >= depth - 0.000001f)
    result = inset.copy();
  else if (edgeBreak > 0.0001f && z > depth - edgeBreak)
    result = PVector.lerp(base, inset,
      constrain((z - (depth - edgeBreak)) / edgeBreak, 0, 1));
  else result = base.copy();
  result.z = z;
  return result;
}

void geodesicEnsureJointProfiles(GeodesicFabricationFace face, GeodesicFabricationSettings settings) {
  if (face.joints.size() == face.vertexCount()) return;
  face.joints.clear();
  for (int i = 0; i < face.vertexCount(); i++) {
    GeodesicJointEdgeProfile profile = new GeodesicJointEdgeProfile();
    profile.edgeIndex = i;
    profile.neighborFaceId = i < face.neighborFaceIds.size() ? face.neighborFaceIds.get(i) : -1;
    profile.edgeLengthMM = PVector.dist(face.boundary.get(i),
      face.boundary.get((i + 1) % face.vertexCount()));
    profile.junctionBisector.set(face.axisZ);
    geodesicSchedulePortals(profile, settings);
    geodesicConfigureKicasJoint(face, profile, settings);
    face.joints.add(profile);
  }
}

void geodesicAddSolidPolygon(SurfaceMesh mesh, ArrayList<PVector> polygon,
  float depth, float centerRelief) {
  geodesicAddPolygonFan(mesh, polygon, 0, false, 0);
  geodesicAddPolygonFan(mesh, polygon, depth, true, centerRelief);
  for (int i = 0; i < polygon.size(); i++) {
    PVector a = geodesicAtZ(polygon.get(i), 0);
    PVector b = geodesicAtZ(polygon.get((i + 1) % polygon.size()), 0);
    PVector bt = geodesicAtZ(polygon.get((i + 1) % polygon.size()), depth);
    PVector at = geodesicAtZ(polygon.get(i), depth);
    mesh.addQuad(a, b, bt, at);
  }
}

void geodesicAddPolygonFan(SurfaceMesh mesh, ArrayList<PVector> polygon,
  float z, boolean top, float centerRelief) {
  // Edge-code and portal breaks add collinear boundary vertices unevenly.
  // An arithmetic mean would move the apex toward the most subdivided edge;
  // the area centroid keeps the fan invariant under those subdivisions.
  PVector center = geodesicPolygonAreaCentroid(polygon);
  center.z = z + (top ? centerRelief : 0);
  for (int i = 0; i < polygon.size(); i++) {
    PVector a = geodesicAtZ(polygon.get(i), z);
    PVector b = geodesicAtZ(polygon.get((i + 1) % polygon.size()), z);
    if (top) mesh.addTri(center, a, b);
    else mesh.addTri(center, b, a);
  }
}

class GeodesicInteriorCodeLayout {
  PVector edgeA;
  PVector edgeB;
  PVector center;
  String mark = "";
  float edgeLength;
  float apothem;
  float cellSize;
  float startAlong;
  float startAcross;
  int columns;
  boolean valid;
  ArrayList<Float> boundaryStations = new ArrayList<Float>();
  ArrayList<PVector> boundaryPoints = new ArrayList<PVector>();
}

final int GEODESIC_CODE_SAMPLES_PER_UNIT = 3;
final float GEODESIC_CODE_STROKE_RADIUS = 0.27f;
final float GEODESIC_CODE_STROKE_FEATHER = 0.07f;
final float GEODESIC_INTERIOR_BREAK_EPSILON = 0.0001f;
final float GEODESIC_KICAS_PLACEMENT_LABEL_SCALE = 3.0f;
final float GEODESIC_KICAS_PLACEMENT_CELL_CAP_MM =
  0.72f * GEODESIC_KICAS_PLACEMENT_LABEL_SCALE;
final float GEODESIC_KICAS_PLACEMENT_FIT_FRACTION = 0.90f;
// Five glyph rows occupy at most 85% of the rail width. The remaining margin
// keeps rounded strokes at z=0 on both rail boundaries, so the raised mark
// stitches exactly to the adjacent miter and inner-wall faces.
final float GEODESIC_KICAS_PLACEMENT_RAIL_FRACTION = 0.17f;

GeodesicInteriorCodeLayout geodesicInteriorCodeLayout(
  ArrayList<PVector> boundary, int edgeIndex, String mateCode) {
  return geodesicInteriorCodeLayoutRaw(boundary, edgeIndex,
    geodesicPhysicalEdgeMark(mateCode), false);
}

GeodesicInteriorCodeLayout geodesicInteriorPlacementLayout(
  ArrayList<PVector> boundary, int edgeIndex, String placementLabel) {
  return geodesicInteriorCodeLayoutRaw(boundary, edgeIndex,
    placementLabel == null ? "" : placementLabel.toUpperCase(), true);
}

GeodesicInteriorCodeLayout geodesicInteriorCodeLayoutRaw(
  ArrayList<PVector> boundary, int edgeIndex, String mark,
  boolean placementCode) {
  GeodesicInteriorCodeLayout layout = new GeodesicInteriorCodeLayout();
  if (boundary == null || boundary.size() < 3 ||
      edgeIndex < 0 || edgeIndex >= boundary.size()) return layout;
  layout.edgeA = boundary.get(edgeIndex);
  layout.edgeB = boundary.get((edgeIndex + 1) % boundary.size());
  layout.center = geodesicPolygonCentroid(boundary);
  layout.mark = mark == null ? "" : mark;
  layout.columns = layout.mark.length() == 0 ? 0 : layout.mark.length() * 4 - 1;
  layout.edgeLength = PVector.dist(layout.edgeA, layout.edgeB);
  PVector midpoint = PVector.add(layout.edgeA, layout.edgeB).mult(0.5f);
  layout.apothem = PVector.dist(midpoint, layout.center);
  if (layout.columns <= 0 || layout.edgeLength < 0.001f ||
      layout.apothem < 0.001f) return layout;

  if (placementCode) {
    // Request three times the former placement-label scale. Acute and small
    // faces remain fit-capped so the mark cannot cross a seam or create a
    // non-manifold sliver near the panel center.
    layout.cellSize = min(1.15f * GEODESIC_KICAS_PLACEMENT_LABEL_SCALE,
      min(layout.apothem * 0.095f * GEODESIC_KICAS_PLACEMENT_LABEL_SCALE,
      layout.edgeLength * 0.86f / layout.columns));
    layout.startAcross = layout.apothem * 0.06f;
    layout.cellSize = min(layout.cellSize,
      max(0.001f, (layout.apothem * 0.82f - layout.startAcross) / 5.0f));
  } else {
    // Two-character codes remain inside the edge wedge, while one-character
    // codes approach a 3 mm cap height at the reference export scale.
    layout.cellSize = min(0.90f, min(layout.apothem * 0.125f,
      layout.edgeLength * 0.42f / layout.columns));
    layout.startAcross = layout.apothem * 0.070f;
    layout.cellSize = min(layout.cellSize,
      max(0.001f, (layout.apothem * 0.70f - layout.startAcross) / 5.0f));
  }
  float codeWidth = layout.columns * layout.cellSize;
  layout.startAlong = (layout.edgeLength - codeWidth) * 0.5f;
  layout.valid = layout.cellSize >= (placementCode ? 0.24f : 0.18f) &&
    layout.startAlong > 0.01f &&
    layout.startAcross + 5.0f * layout.cellSize <
      layout.apothem * (placementCode ? 0.84f : 0.72f);
  return layout;
}

void geodesicAddInteriorCodeEdgeBreaks(ArrayList<Float> breaks,
  ArrayList<PVector> boundary, int edgeIndex, String mateCode) {
  GeodesicInteriorCodeLayout layout =
    geodesicInteriorCodeLayout(boundary, edgeIndex, mateCode);
  if (!layout.valid) return;
  geodesicAddInteriorStrokeBreaks(breaks, layout);
}

void geodesicAddInteriorPlacementEdgeBreaks(ArrayList<Float> breaks,
  ArrayList<PVector> boundary, int edgeIndex, String placementLabel) {
  GeodesicInteriorCodeLayout layout =
    geodesicInteriorPlacementLayout(boundary, edgeIndex, placementLabel);
  if (!layout.valid) return;
  geodesicAddInteriorStrokeBreaks(breaks, layout);
}

void geodesicAddInteriorStrokeBreaks(ArrayList<Float> breaks,
  GeodesicInteriorCodeLayout layout) {
  int samplesPerUnit = geodesicInteriorCodeSamplesPerUnit(layout);
  int samples = layout.columns * samplesPerUnit;
  for (int sample = 0; sample <= samples; sample++) {
    float x = layout.startAlong + layout.cellSize * sample /
      samplesPerUnit;
    geodesicAddUniqueBreak(breaks, x / layout.edgeLength);
  }
}

int geodesicInteriorCodeSamplesPerUnit(GeodesicInteriorCodeLayout layout) {
  if (layout == null || layout.edgeLength < 0.001f) return 2;
  // Deeply acute stellated panels converge rapidly toward their center. A
  // two-sample stroke grid avoids sub-nozzle needle triangles there, while
  // ordinary triangles and polygons retain the fuller rounded stroke grid.
  float aspect = layout.apothem / layout.edgeLength;
  return aspect < 0.20f ? 2 : GEODESIC_CODE_SAMPLES_PER_UNIT;
}

/*
 * Build labels as a binary stepped membrane from a rounded engineering-stroke
 * alphabet. Every occupied stroke cell has a flat cap and explicit vertical
 * walls. The labels remain part of one watertight panel rather than becoming
 * intersecting text shells.
 */
void geodesicAddCodedInteriorMembrane(SurfaceMesh mesh,
  ArrayList<PVector> subdividedBoundary, ArrayList<PVector> originalBoundary,
  ArrayList<GeodesicJointEdgeProfile> joints, float z, float relief,
  boolean top, float centerRelief, String placementLabel) {
  if (subdividedBoundary == null || subdividedBoundary.size() < 3 ||
      originalBoundary == null || originalBoundary.size() < 3 ||
      joints == null || joints.size() < originalBoundary.size() ||
      relief <= 0.001f) {
    geodesicAddPolygonFan(mesh, subdividedBoundary, z, top, centerRelief);
    return;
  }

  ArrayList<GeodesicInteriorCodeLayout> layouts =
    new ArrayList<GeodesicInteriorCodeLayout>();
  ArrayList<Float> uBreaks = new ArrayList<Float>();
  geodesicAddUniqueInteriorBreak(uBreaks, 0);
  float patchEnd = 0.16f;
  for (int edge = 0; edge < originalBoundary.size(); edge++) {
    GeodesicInteriorCodeLayout layout =
      placementLabel != null && placementLabel.length() > 0 ?
      (edge == 0 ? geodesicInteriorPlacementLayout(originalBoundary,
        edge, placementLabel) : geodesicInteriorCodeLayoutRaw(
        originalBoundary, edge, "", false)) :
      geodesicInteriorCodeLayout(originalBoundary, edge,
        joints.get(edge).mateCode);
    layouts.add(layout);
    if (!layout.valid) continue;
    int samplesPerUnit = geodesicInteriorCodeSamplesPerUnit(layout);
    for (int sample = 0; sample <= 5 * samplesPerUnit;
        sample++) {
      float y = layout.startAcross + layout.cellSize * sample /
        samplesPerUnit;
      geodesicAddUniqueInteriorBreak(uBreaks, y / layout.apothem);
      patchEnd = max(patchEnd,
        (y + layout.cellSize * 0.18f) / layout.apothem);
    }
  }
  patchEnd = constrain(patchEnd, 0.16f,
    placementLabel != null && placementLabel.length() > 0 ? 0.86f : 0.76f);
  geodesicAddUniqueInteriorBreak(uBreaks, patchEnd);
  java.util.Collections.sort(uBreaks);

  for (int edge = 0; edge < originalBoundary.size(); edge++) {
    GeodesicInteriorCodeLayout layout = layouts.get(edge);
    ArrayList<Float> tBreaks = geodesicInteriorCodeTBreaks(
      subdividedBoundary, layout);
    if (tBreaks.size() < 2) continue;
    int rows = uBreaks.size() - 1;
    int columns = tBreaks.size() - 1;
    boolean[][] active = new boolean[rows][columns];

    for (int row = 0; row < rows; row++) {
      float u0 = uBreaks.get(row);
      float u1 = uBreaks.get(row + 1);
      float uMid = (u0 + u1) * 0.5f;
      for (int column = 0; column < columns; column++) {
        float t0 = tBreaks.get(column);
        float t1 = tBreaks.get(column + 1);
        float tMid = (t0 + t1) * 0.5f;
        active[row][column] =
          geodesicInteriorCodeCellActive(layout, tMid, uMid);
        PVector p00 = geodesicInteriorCodeGridPoint(layout, t0, u0,
          z, relief, active[row][column], top, centerRelief);
        PVector p10 = geodesicInteriorCodeGridPoint(layout, t1, u0,
          z, relief, active[row][column], top, centerRelief);
        PVector p11 = geodesicInteriorCodeGridPoint(layout, t1, u1,
          z, relief, active[row][column], top, centerRelief);
        PVector p01 = geodesicInteriorCodeGridPoint(layout, t0, u1,
          z, relief, active[row][column], top, centerRelief);
        if (top) mesh.addQuad(p00, p10, p11, p01);
        else mesh.addQuad(p00, p01, p11, p10);
      }
    }

    geodesicAddInteriorCodeStepWalls(mesh, layout, tBreaks, uBreaks,
      active, z, relief, top, centerRelief);

    float finalU = uBreaks.get(uBreaks.size() - 1);
    PVector centerPoint = layout.center.copy();
    centerPoint.z = z + (top ? centerRelief : 0);
    for (int column = 0; column < columns; column++) {
      PVector left = geodesicInteriorCodeGridPoint(layout,
        tBreaks.get(column), finalU, z, relief, false, top, centerRelief);
      PVector right = geodesicInteriorCodeGridPoint(layout,
        tBreaks.get(column + 1), finalU, z, relief, false, top, centerRelief);
      if (top) mesh.addTri(centerPoint, left, right);
      else mesh.addTri(centerPoint, right, left);
    }
  }
}

ArrayList<Float> geodesicInteriorCodeTBreaks(
  ArrayList<PVector> subdividedBoundary, GeodesicInteriorCodeLayout layout) {
  ArrayList<Float> result = new ArrayList<Float>();
  geodesicAddUniqueInteriorBreak(result, 0);
  geodesicAddUniqueInteriorBreak(result, 1);
  if (layout == null || layout.edgeA == null || layout.edgeB == null ||
      layout.edgeLength < 0.001f) return result;
  PVector tangent = PVector.sub(layout.edgeB, layout.edgeA);
  tangent.normalize();
  if (subdividedBoundary != null) for (PVector point : subdividedBoundary) {
    if (geodesicPointSegmentDistance2D(point,
        layout.edgeA, layout.edgeB) > 0.00001f) continue;
    float along = PVector.sub(point, layout.edgeA).dot(tangent);
    if (along > -0.001f && along < layout.edgeLength + 0.001f) {
      float station = constrain(along / layout.edgeLength, 0, 1);
      geodesicAddUniqueInteriorBreak(result, station);
      geodesicRememberInteriorBoundaryPoint(layout, station, point);
    }
  }
  if (layout.valid) geodesicAddInteriorStrokeBreaks(result, layout);
  java.util.Collections.sort(result);
  return result;
}

boolean geodesicInteriorCodeCellActive(GeodesicInteriorCodeLayout layout,
  float t, float u) {
  if (layout == null || !layout.valid) return false;
  float x = (t * layout.edgeLength - layout.startAlong) / layout.cellSize;
  float y = (u * layout.apothem - layout.startAcross) / layout.cellSize;
  return geodesicGlyphCellActive(layout.mark, x, y);
}

boolean geodesicGlyphCellActive(String mark, float x, float y) {
  return geodesicGlyphStrokeDistance(mark, x, y) <=
    GEODESIC_CODE_STROKE_RADIUS;
}

PVector geodesicInteriorCodeGridPoint(GeodesicInteriorCodeLayout layout,
  float t, float u, float z, float relief, boolean active,
  boolean top, float centerRelief) {
  PVector edgePoint = geodesicInteriorBoundaryPoint(layout, t);
  PVector result = PVector.lerp(edgePoint, layout.center, u);
  float baseZ = z + (top ? centerRelief * u : 0);
  result.z = baseZ + (active ? (top ? relief : -relief) : 0);
  return result;
}

void geodesicRememberInteriorBoundaryPoint(GeodesicInteriorCodeLayout layout,
  float station, PVector point) {
  for (int i = 0; i < layout.boundaryStations.size(); i++) {
    if (abs(layout.boundaryStations.get(i) - station) <
        GEODESIC_INTERIOR_BREAK_EPSILON) return;
  }
  layout.boundaryStations.add(station);
  layout.boundaryPoints.add(point.copy());
}

PVector geodesicInteriorBoundaryPoint(GeodesicInteriorCodeLayout layout,
  float station) {
  if (station <= GEODESIC_INTERIOR_BREAK_EPSILON)
    return layout.edgeA.copy();
  if (station >= 1.0f - GEODESIC_INTERIOR_BREAK_EPSILON)
    return layout.edgeB.copy();
  for (int i = 0; i < layout.boundaryStations.size(); i++) {
    if (abs(layout.boundaryStations.get(i) - station) <
        GEODESIC_INTERIOR_BREAK_EPSILON)
      return layout.boundaryPoints.get(i).copy();
  }
  return PVector.lerp(layout.edgeA, layout.edgeB, station);
}

void geodesicAddUniqueInteriorBreak(ArrayList<Float> values, float value) {
  float clamped = constrain(value, 0, 1);
  for (float existing : values)
    if (abs(existing - clamped) < GEODESIC_INTERIOR_BREAK_EPSILON) return;
  values.add(clamped);
}

void geodesicAddInteriorCodeStepWalls(SurfaceMesh mesh,
  GeodesicInteriorCodeLayout layout, ArrayList<Float> tBreaks,
  ArrayList<Float> uBreaks, boolean[][] active, float z, float relief,
  boolean top, float centerRelief) {
  int rows = active.length;
  int columns = rows == 0 ? 0 : active[0].length;

  for (int row = 0; row < rows; row++) {
    float u0 = uBreaks.get(row);
    float u1 = uBreaks.get(row + 1);
    for (int column = 0; column < columns - 1; column++) {
      boolean left = active[row][column];
      boolean right = active[row][column + 1];
      if (left == right) continue;
      float t = tBreaks.get(column + 1);
      boolean highIsLeft = left;
      PVector highStart;
      PVector highEnd;
      PVector lowStart;
      PVector lowEnd;
      if (top == highIsLeft) {
        highStart = geodesicInteriorCodeGridPoint(layout, t, u0,
          z, relief, true, top, centerRelief);
        highEnd = geodesicInteriorCodeGridPoint(layout, t, u1,
          z, relief, true, top, centerRelief);
        lowStart = geodesicInteriorCodeGridPoint(layout, t, u1,
          z, relief, false, top, centerRelief);
        lowEnd = geodesicInteriorCodeGridPoint(layout, t, u0,
          z, relief, false, top, centerRelief);
      } else {
        highStart = geodesicInteriorCodeGridPoint(layout, t, u1,
          z, relief, true, top, centerRelief);
        highEnd = geodesicInteriorCodeGridPoint(layout, t, u0,
          z, relief, true, top, centerRelief);
        lowStart = geodesicInteriorCodeGridPoint(layout, t, u0,
          z, relief, false, top, centerRelief);
        lowEnd = geodesicInteriorCodeGridPoint(layout, t, u1,
          z, relief, false, top, centerRelief);
      }
      geodesicAddInteriorCodeStepWall(mesh,
        highStart, highEnd, lowStart, lowEnd);
    }
  }

  for (int row = 0; row < rows - 1; row++) {
    float u = uBreaks.get(row + 1);
    for (int column = 0; column < columns; column++) {
      boolean lower = active[row][column];
      boolean upper = active[row + 1][column];
      if (lower == upper) continue;
      float t0 = tBreaks.get(column);
      float t1 = tBreaks.get(column + 1);
      boolean highIsLower = lower;
      PVector highStart;
      PVector highEnd;
      PVector lowStart;
      PVector lowEnd;
      if (top == highIsLower) {
        highStart = geodesicInteriorCodeGridPoint(layout, t1, u,
          z, relief, true, top, centerRelief);
        highEnd = geodesicInteriorCodeGridPoint(layout, t0, u,
          z, relief, true, top, centerRelief);
        lowStart = geodesicInteriorCodeGridPoint(layout, t0, u,
          z, relief, false, top, centerRelief);
        lowEnd = geodesicInteriorCodeGridPoint(layout, t1, u,
          z, relief, false, top, centerRelief);
      } else {
        highStart = geodesicInteriorCodeGridPoint(layout, t0, u,
          z, relief, true, top, centerRelief);
        highEnd = geodesicInteriorCodeGridPoint(layout, t1, u,
          z, relief, true, top, centerRelief);
        lowStart = geodesicInteriorCodeGridPoint(layout, t1, u,
          z, relief, false, top, centerRelief);
        lowEnd = geodesicInteriorCodeGridPoint(layout, t0, u,
          z, relief, false, top, centerRelief);
      }
      geodesicAddInteriorCodeStepWall(mesh,
        highStart, highEnd, lowStart, lowEnd);
    }
  }
}

void geodesicAddInteriorCodeStepWall(SurfaceMesh mesh,
  PVector highStart, PVector highEnd, PVector lowStart, PVector lowEnd) {
  mesh.addQuad(highEnd, highStart, lowEnd, lowStart);
}

PVector geodesicInteriorCodePoint(PVector point,
  ArrayList<PVector> boundary, ArrayList<GeodesicJointEdgeProfile> joints,
  float z, float relief, boolean top) {
  PVector result = point.copy();
  float height = geodesicInteriorCodeHeight(point, boundary, joints, relief);
  // Raise toward the assembly cavity from whichever membrane face is inward.
  result.z = z + (top ? height : -height);
  return result;
}

float geodesicInteriorCodeHeight(PVector point, ArrayList<PVector> boundary,
  ArrayList<GeodesicJointEdgeProfile> joints, float relief) {
  if (point == null || boundary == null || joints == null || relief <= 0) return 0;
  PVector center = geodesicPolygonCentroid(boundary);
  float panelApothem = geodesicMinimumCentroidEdgeDistance(boundary);
  float boundaryClearance = max(0.12f, panelApothem * 0.055f);
  for (int edge = 0; edge < boundary.size(); edge++) {
    PVector a = boundary.get(edge);
    PVector b = boundary.get((edge + 1) % boundary.size());
    if (geodesicPointSegmentDistance2D(point, a, b) < boundaryClearance) return 0;
  }
  float strength = 0;
  for (int edge = 0; edge < boundary.size() && edge < joints.size(); edge++) {
    String mark = geodesicPhysicalEdgeMark(joints.get(edge).mateCode);
    if (mark.length() == 0) continue;
    PVector a = boundary.get(edge);
    PVector b = boundary.get((edge + 1) % boundary.size());
    PVector tangent = PVector.sub(b, a);
    float edgeLength = tangent.mag();
    if (edgeLength < 0.001f) continue;
    tangent.div(edgeLength);
    PVector midpoint = PVector.add(a, b).mult(0.5f);
    PVector inward = PVector.sub(center, midpoint);
    float apothem = inward.mag();
    if (apothem < 0.001f) continue;
    inward.div(apothem);
    float along = PVector.sub(point, a).dot(tangent);
    float across = PVector.sub(point, midpoint).dot(inward);
    int columns = mark.length() * 4 - 1;
    // Compact square cells reproduce the original raised edge-local marks with
    // a restrained size increase. The cap prevents codes from reaching the
    // panel center on narrow or highly subdivided faces.
    float cellSize = min(apothem * 0.070f,
      edgeLength * 0.34f / max(5.0f, columns));
    float cellAlong = cellSize;
    float cellAcross = cellSize;
    if (cellAlong < 0.001f || cellAcross < 0.001f) continue;
    float startAlong = (edgeLength - columns * cellAlong) * 0.5f;
    float startAcross = apothem * 0.100f;
    float x = (along - startAlong) / cellAlong;
    float y = (across - startAcross) / cellAcross;
    strength = max(strength, geodesicGlyphStrength(mark, x, y));
  }
  return relief * strength;
}

float geodesicPointSegmentDistance2D(PVector point, PVector a, PVector b) {
  PVector edge = PVector.sub(b, a);
  float lengthSq = edge.x * edge.x + edge.y * edge.y;
  if (lengthSq < 0.000001f) return dist(point.x, point.y, a.x, a.y);
  float t = constrain(((point.x - a.x) * edge.x +
    (point.y - a.y) * edge.y) / lengthSq, 0, 1);
  float nearestX = a.x + edge.x * t;
  float nearestY = a.y + edge.y * t;
  return dist(point.x, point.y, nearestX, nearestY);
}

void geodesicAddPolygonRing(SurfaceMesh mesh, ArrayList<PVector> outer,
  ArrayList<PVector> inner, float z, boolean top) {
  for (int i = 0; i < outer.size(); i++) {
    int j = (i + 1) % outer.size();
    PVector oa = geodesicAtZ(outer.get(i), z);
    PVector ob = geodesicAtZ(outer.get(j), z);
    PVector ib = geodesicAtZ(inner.get(j), z);
    PVector ia = geodesicAtZ(inner.get(i), z);
    if (top) mesh.addQuad(oa, ob, ib, ia);
    else mesh.addQuad(oa, ia, ib, ob);
  }
}

void geodesicAddFramePortalInterval(SurfaceMesh mesh, PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, PVector outerChamferA, PVector outerChamferB,
  PVector innerTopA, PVector innerTopB, float start, float end,
  float innerWallBottom, float innerWallTop, float depth,
  float slotBottom, float slotTop, float edgeBreak,
  boolean closeStart, boolean closeEnd) {
  PVector oa = geodesicEdgePoint(outerA, outerB, start, 0);
  PVector ob = geodesicEdgePoint(outerA, outerB, end, 0);
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector oca = geodesicEdgePoint(outerChamferA, outerChamferB, start, 0);
  PVector ocb = geodesicEdgePoint(outerChamferA, outerChamferB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);

  if (slotBottom > 0.0001f) {
    geodesicAddOuterWallBand(mesh, oa, ob, oca, ocb, 0, slotBottom,
      depth, edgeBreak);
  }
  if (slotTop < depth - 0.0001f) {
    geodesicAddOuterWallBand(mesh, oa, ob, oca, ocb, slotTop, depth,
      depth, edgeBreak);
  }
  if (slotBottom > innerWallBottom + 0.0001f) {
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
      slotBottom, depth, edgeBreak);
  }
  if (slotTop < innerWallTop - 0.0001f) {
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, slotTop, innerWallTop,
      depth, edgeBreak);
  }

  mesh.addQuad(geodesicAtZ(oa, slotBottom), geodesicAtZ(ob, slotBottom),
    geodesicAtZ(ib, slotBottom), geodesicAtZ(ia, slotBottom));
  mesh.addQuad(geodesicAtZ(oa, slotTop), geodesicAtZ(ia, slotTop),
    geodesicAtZ(ib, slotTop), geodesicAtZ(ob, slotTop));
  if (closeStart) mesh.addQuad(geodesicAtZ(oa, slotBottom),
    geodesicAtZ(ia, slotBottom), geodesicAtZ(ia, slotTop),
    geodesicAtZ(oa, slotTop));
  if (closeEnd) mesh.addQuad(geodesicAtZ(ob, slotBottom),
    geodesicAtZ(ob, slotTop), geodesicAtZ(ib, slotTop),
    geodesicAtZ(ib, slotBottom));
}

void geodesicAddMiterFramePortalInterval(SurfaceMesh mesh,
  GeodesicMiterOuterProfile profile, int edgeIndex,
  PVector innerA, PVector innerB, PVector innerTopA, PVector innerTopB,
  float start, float end, float innerWallBottom, float innerWallTop,
  float depth, float slotBottom, float slotTop, float edgeBreak,
  boolean closeStart, boolean closeEnd) {
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);
  if (slotBottom > 0.0001f)
    geodesicAddMiterOuterWallBand(mesh, profile, edgeIndex, start, end,
      0, slotBottom);
  if (slotTop < depth - 0.0001f)
    geodesicAddMiterOuterWallBand(mesh, profile, edgeIndex, start, end,
      slotTop, depth);
  if (slotBottom > innerWallBottom + 0.0001f)
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
      slotBottom, depth, edgeBreak);
  if (slotTop < innerWallTop - 0.0001f)
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, slotTop,
      innerWallTop, depth, edgeBreak);

  PVector outerStartBottom = geodesicMiterOuterPoint(profile, edgeIndex,
    start, slotBottom);
  PVector outerEndBottom = geodesicMiterOuterPoint(profile, edgeIndex,
    end, slotBottom);
  PVector outerStartTop = geodesicMiterOuterPoint(profile, edgeIndex,
    start, slotTop);
  PVector outerEndTop = geodesicMiterOuterPoint(profile, edgeIndex,
    end, slotTop);
  PVector innerStartBottom = geodesicAtZ(ia, slotBottom);
  PVector innerEndBottom = geodesicAtZ(ib, slotBottom);
  PVector innerStartTop = geodesicAtZ(ia, slotTop);
  PVector innerEndTop = geodesicAtZ(ib, slotTop);
  mesh.addQuad(outerStartBottom, outerEndBottom,
    innerEndBottom, innerStartBottom);
  mesh.addQuad(outerStartTop, innerStartTop,
    innerEndTop, outerEndTop);
  if (closeStart) mesh.addQuad(outerStartBottom, innerStartBottom,
    innerStartTop, outerStartTop);
  if (closeEnd) mesh.addQuad(outerEndBottom, outerEndTop,
    innerEndTop, innerEndBottom);
}

void geodesicAddCodedTopRail(SurfaceMesh mesh, PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, ArrayList<Float> structuralBreaks,
  String mateCode, float depth, float relief) {
  String mark = geodesicPhysicalEdgeMark(mateCode);
  float edgeLength = max(0.001f, PVector.dist(outerA, outerB));
  float railWidth = max(0.001f,
    (PVector.dist(outerA, innerA) + PVector.dist(outerB, innerB)) * 0.5f);
  float cellMM = min(railWidth * 0.16f, 0.46f);
  int columns = mark.length() == 0 ? 0 : mark.length() * 4 - 1;
  if (columns > 0) cellMM = min(cellMM, edgeLength * 0.68f / columns);
  float cellT = cellMM / edgeLength;
  float cellU = cellMM / railWidth;
  float startT = 0.5f - columns * cellT * 0.5f;
  float startU = 0.5f - 5.0f * cellU * 0.5f;

  ArrayList<Float> tBreaks = new ArrayList<Float>();
  if (structuralBreaks != null) for (float value : structuralBreaks)
    geodesicAddUniqueBreak(tBreaks, value);
  geodesicAddUniqueBreak(tBreaks, 0);
  geodesicAddUniqueBreak(tBreaks, 1);
  ArrayList<Float> uBreaks = new ArrayList<Float>();
  geodesicAddUniqueBreak(uBreaks, 0);
  geodesicAddUniqueBreak(uBreaks, 1);
  if (columns > 0 && relief > 0.001f && cellMM >= 0.16f) {
    // All edge patches use the same normalized cross-rail grid. This keeps
    // their radial corner boundaries identical even when adjacent labels or
    // edge lengths differ.
    for (int r = 1; r < 32; r++) geodesicAddUniqueBreak(uBreaks, r / 32.0f);
  }
  java.util.Collections.sort(tBreaks);
  java.util.Collections.sort(uBreaks);
  for (int ti = 0; ti < tBreaks.size() - 1; ti++) {
    float t0 = tBreaks.get(ti);
    float t1 = tBreaks.get(ti + 1);
    if (t1 - t0 < 0.00001f) continue;
    for (int ui = 0; ui < uBreaks.size() - 1; ui++) {
      float u0 = uBreaks.get(ui);
      float u1 = uBreaks.get(ui + 1);
      if (u1 - u0 < 0.00001f) continue;
      float h00 = geodesicEdgeCodeHeight(mark, t0, u0, startT, startU,
        cellT, cellU, relief);
      float h10 = geodesicEdgeCodeHeight(mark, t1, u0, startT, startU,
        cellT, cellU, relief);
      float h11 = geodesicEdgeCodeHeight(mark, t1, u1, startT, startU,
        cellT, cellU, relief);
      float h01 = geodesicEdgeCodeHeight(mark, t0, u1, startT, startU,
        cellT, cellU, relief);
      mesh.addQuad(
        geodesicRailPoint(outerA, outerB, innerA, innerB, t0, u0, depth + h00),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t1, u0, depth + h10),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t1, u1, depth + h11),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t0, u1, depth + h01));
    }
  }
}

void geodesicAddCodedBottomRail(SurfaceMesh mesh, PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, ArrayList<Float> structuralBreaks,
  String mateCode, float relief) {
  String mark = geodesicPhysicalEdgeMark(mateCode);
  float edgeLength = max(0.001f, PVector.dist(outerA, outerB));
  float railWidth = max(0.001f,
    (PVector.dist(outerA, innerA) + PVector.dist(outerB, innerB)) * 0.5f);
  float cellMM = min(railWidth * 0.16f, 0.46f);
  int columns = mark.length() == 0 ? 0 : mark.length() * 4 - 1;
  if (columns > 0) cellMM = min(cellMM, edgeLength * 0.68f / columns);
  float cellT = cellMM / edgeLength;
  float cellU = cellMM / railWidth;
  float startT = 0.5f - columns * cellT * 0.5f;
  float startU = 0.5f - 5.0f * cellU * 0.5f;

  ArrayList<Float> tBreaks = new ArrayList<Float>();
  if (structuralBreaks != null) for (float value : structuralBreaks)
    geodesicAddUniqueBreak(tBreaks, value);
  geodesicAddUniqueBreak(tBreaks, 0);
  geodesicAddUniqueBreak(tBreaks, 1);
  ArrayList<Float> uBreaks = new ArrayList<Float>();
  geodesicAddUniqueBreak(uBreaks, 0);
  geodesicAddUniqueBreak(uBreaks, 1);
  if (columns > 0 && relief > 0.001f && cellMM >= 0.16f)
    for (int r = 1; r < 32; r++) geodesicAddUniqueBreak(uBreaks, r / 32.0f);
  java.util.Collections.sort(tBreaks);
  java.util.Collections.sort(uBreaks);
  for (int ti = 0; ti < tBreaks.size() - 1; ti++) {
    float t0 = tBreaks.get(ti);
    float t1 = tBreaks.get(ti + 1);
    if (t1 - t0 < 0.00001f) continue;
    for (int ui = 0; ui < uBreaks.size() - 1; ui++) {
      float u0 = uBreaks.get(ui);
      float u1 = uBreaks.get(ui + 1);
      if (u1 - u0 < 0.00001f) continue;
      float h00 = geodesicEdgeCodeHeight(mark, t0, u0, startT, startU,
        cellT, cellU, relief);
      float h10 = geodesicEdgeCodeHeight(mark, t1, u0, startT, startU,
        cellT, cellU, relief);
      float h11 = geodesicEdgeCodeHeight(mark, t1, u1, startT, startU,
        cellT, cellU, relief);
      float h01 = geodesicEdgeCodeHeight(mark, t0, u1, startT, startU,
        cellT, cellU, relief);
      mesh.addQuad(
        geodesicRailPoint(outerA, outerB, innerA, innerB, t0, u0, h00),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t0, u1, h01),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t1, u1, h11),
        geodesicRailPoint(outerA, outerB, innerA, innerB, t1, u0, h10));
    }
  }
}

ArrayList<Float> geodesicCodedRailTBreaks(PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, ArrayList<Float> structuralBreaks,
  String mateCode, float relief) {
  return geodesicCodedRailTBreaksMark(outerA, outerB, innerA, innerB,
    structuralBreaks, geodesicPhysicalEdgeMark(mateCode), relief,
    0.46f, 0.68f);
}

ArrayList<Float> geodesicCodedRailTBreaksMark(PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, ArrayList<Float> structuralBreaks,
  String mark, float relief, float cellCapMM, float fitFraction) {
  return geodesicCodedRailTBreaksMark(outerA, outerB, innerA, innerB,
    structuralBreaks, mark, relief, cellCapMM, fitFraction, 0.16f);
}

ArrayList<Float> geodesicCodedRailTBreaksMark(PVector outerA, PVector outerB,
  PVector innerA, PVector innerB, ArrayList<Float> structuralBreaks,
  String mark, float relief, float cellCapMM, float fitFraction,
  float railFraction) {
  ArrayList<Float> result = new ArrayList<Float>();
  String resolvedMark = mark == null ? "" : mark.toUpperCase();
  if (structuralBreaks != null) for (float value : structuralBreaks)
    geodesicAddUniqueBreak(result, value);
  geodesicAddUniqueBreak(result, 0);
  geodesicAddUniqueBreak(result, 1);
  int columns = resolvedMark.length() == 0 ? 0 :
    resolvedMark.length() * 4 - 1;
  if (columns <= 0 || relief <= 0.001f) {
    java.util.Collections.sort(result);
    return result;
  }
  float edgeLength = max(0.001f, PVector.dist(outerA, outerB));
  float railWidth = max(0.001f,
    (PVector.dist(outerA, innerA) + PVector.dist(outerB, innerB)) * 0.5f);
  float cellMM = geodesicRailLabelCellMM(edgeLength, railWidth, columns,
    cellCapMM, fitFraction, railFraction);
  if (cellMM < 0.16f) {
    java.util.Collections.sort(result);
    return result;
  }
  float cellT = cellMM / edgeLength;
  float startT = 0.5f - columns * cellT * 0.5f;
  int samples = columns * GEODESIC_CODE_SAMPLES_PER_UNIT;
  for (int sample = 0; sample <= samples; sample++)
    geodesicAddUniqueBreak(result, constrain(startT +
      cellT * sample / GEODESIC_CODE_SAMPLES_PER_UNIT, 0, 1));
  java.util.Collections.sort(result);
  return result;
}

float geodesicRailLabelCellMM(float edgeLength, float railWidth, int columns,
  float cellCapMM, float fitFraction, float railFraction) {
  if (columns <= 0 || edgeLength < 0.001f || railWidth < 0.001f) return 0;
  return min(max(0, cellCapMM), min(
    railWidth * constrain(railFraction, 0.05f, 0.19f),
    edgeLength * constrain(fitFraction, 0.10f, 0.94f) / columns));
}

void geodesicAddUniqueBreak(ArrayList<Float> values, float value) {
  float clamped = constrain(value, 0, 1);
  // Every downstream panel builder rejects intervals below 0.0001. Use that
  // same feature threshold here so a skipped microscopic face cannot leave a
  // corresponding membrane or rail vertex behind as an open seam.
  for (float existing : values) if (abs(existing - clamped) < 0.0001f) return;
  values.add(clamped);
}

PVector geodesicRailPoint(PVector outerA, PVector outerB, PVector innerA,
  PVector innerB, float t, float u, float z) {
  PVector outer = geodesicEdgePoint(outerA, outerB, t, 0);
  PVector inner = geodesicEdgePoint(innerA, innerB, t, 0);
  float across = constrain(u, 0, 1);
  PVector result;
  if (across <= 0.000001f) result = outer.copy();
  else if (across >= 0.999999f) result = inner.copy();
  else result = PVector.lerp(outer, inner, across);
  result.z = z;
  return result;
}

String geodesicPhysicalEdgeMark(String mateCode) {
  if (mateCode == null || mateCode.length() == 0) return "";
  if (mateCode.equals("RIM")) return "R";
  return mateCode.substring(0, min(2, mateCode.length())).toUpperCase();
}

float geodesicEdgeCodeHeight(String mark, float t, float u, float startT,
  float startU, float cellT, float cellU, float relief) {
  if (mark == null || mark.length() == 0 || relief <= 0 ||
      cellT <= 0.000001f || cellU <= 0.000001f) return 0;
  float x = (t - startT) / cellT;
  float y = (u - startU) / cellU;
  return relief * geodesicGlyphStrength(mark, x, y);
}

float geodesicGlyphStrength(String mark, float x, float y) {
  float distance = geodesicGlyphStrokeDistance(mark, x, y);
  if (distance == Float.MAX_VALUE) return 0;
  return constrain((GEODESIC_CODE_STROKE_RADIUS +
    GEODESIC_CODE_STROKE_FEATHER - distance) /
    GEODESIC_CODE_STROKE_FEATHER, 0, 1);
}

float geodesicGlyphStrokeDistance(String mark, float x, float y) {
  if (mark == null || mark.length() == 0 || y < -0.5f || y > 5.5f)
    return Float.MAX_VALUE;
  float best = Float.MAX_VALUE;
  for (int character = 0; character < mark.length(); character++) {
    float localX = x - character * 4.0f;
    if (localX < -0.5f || localX > 3.5f) continue;
    int[] segments = geodesicGlyphStrokeSegments(mark.charAt(character));
    for (int segment : segments) {
      float[] line = geodesicGlyphStrokeSegment(segment);
      best = min(best, geodesicPointSegmentDistance(localX, y,
        line[0], line[1], line[2], line[3]));
    }
  }
  return best;
}

float geodesicPointSegmentDistance(float px, float py,
  float ax, float ay, float bx, float by) {
  float dx = bx - ax;
  float dy = by - ay;
  float lengthSquared = dx * dx + dy * dy;
  if (lengthSquared < 0.000001f) return dist(px, py, ax, ay);
  float t = constrain(((px - ax) * dx + (py - ay) * dy) /
    lengthSquared, 0, 1);
  return dist(px, py, ax + t * dx, ay + t * dy);
}

float[] geodesicGlyphStrokeSegment(int segment) {
  switch (segment) {
  case 0: return new float[] { 0.45f, 0.35f, 2.55f, 0.35f }; // top
  case 1: return new float[] { 0.35f, 0.45f, 0.35f, 2.35f }; // upper left
  case 2: return new float[] { 2.65f, 0.45f, 2.65f, 2.35f }; // upper right
  case 3: return new float[] { 0.45f, 2.50f, 2.55f, 2.50f }; // middle
  case 4: return new float[] { 0.35f, 2.65f, 0.35f, 4.55f }; // lower left
  case 5: return new float[] { 2.65f, 2.65f, 2.65f, 4.55f }; // lower right
  case 6: return new float[] { 0.45f, 4.65f, 2.55f, 4.65f }; // bottom
  case 7: return new float[] { 0.45f, 0.45f, 1.50f, 2.35f }; // upper \ diagonal
  case 8: return new float[] { 2.55f, 0.45f, 1.50f, 2.35f }; // upper / diagonal
  case 9: return new float[] { 0.45f, 4.55f, 1.50f, 2.65f }; // lower / diagonal
  case 10: return new float[] { 2.55f, 4.55f, 1.50f, 2.65f }; // lower \ diagonal
  case 11: return new float[] { 1.50f, 0.40f, 1.50f, 2.35f }; // center upper
  case 12: return new float[] { 1.50f, 2.65f, 1.50f, 4.60f }; // center lower
  case 13: return new float[] { 0.45f, 0.45f, 2.55f, 4.55f }; // full \
  case 14: return new float[] { 2.55f, 0.45f, 0.45f, 4.55f }; // full /
  default: return new float[] { 0, 0, 0, 0 };
  }
}

int[] geodesicGlyphStrokeSegments(char value) {
  switch (Character.toUpperCase(value)) {
  case 'A': return new int[] { 0, 1, 2, 3, 4, 5 };
  case 'B': return new int[] { 0, 1, 2, 3, 4, 5, 6 };
  case 'C': return new int[] { 0, 1, 4, 6 };
  case 'D': return new int[] { 0, 1, 2, 4, 5, 6 };
  case 'E': return new int[] { 0, 1, 3, 4, 6 };
  case 'F': return new int[] { 0, 1, 3, 4 };
  case 'G': return new int[] { 0, 1, 3, 4, 5, 6 };
  case 'H': return new int[] { 1, 2, 3, 4, 5 };
  case 'I': return new int[] { 0, 6, 11, 12 };
  case 'J': return new int[] { 2, 4, 5, 6 };
  case 'K': return new int[] { 1, 4, 8, 10 };
  case 'L': return new int[] { 1, 4, 6 };
  case 'M': return new int[] { 1, 2, 4, 5, 7, 8 };
  case 'N': return new int[] { 1, 2, 4, 5, 13 };
  case 'O': return new int[] { 0, 1, 2, 4, 5, 6 };
  case 'P': return new int[] { 0, 1, 2, 3, 4 };
  case 'Q': return new int[] { 0, 1, 2, 4, 5, 6, 10 };
  case 'R': return new int[] { 0, 1, 2, 3, 4, 10 };
  case 'S': return new int[] { 0, 1, 3, 5, 6 };
  case 'T': return new int[] { 0, 11, 12 };
  case 'U': return new int[] { 1, 2, 4, 5, 6 };
  case 'V': return new int[] { 1, 2, 9, 10 };
  case 'W': return new int[] { 1, 2, 4, 5, 9, 10 };
  case 'X': return new int[] { 13, 14 };
  case 'Y': return new int[] { 7, 8, 12 };
  case 'Z': return new int[] { 0, 6, 14 };
  case '0': return new int[] { 0, 1, 2, 4, 5, 6 };
  case '1': return new int[] { 2, 5 };
  case '2': return new int[] { 0, 2, 3, 4, 6 };
  case '3': return new int[] { 0, 2, 3, 5, 6 };
  case '4': return new int[] { 1, 2, 3, 5 };
  case '5': return new int[] { 0, 1, 3, 5, 6 };
  case '6': return new int[] { 0, 1, 3, 4, 5, 6 };
  case '7': return new int[] { 0, 2, 5 };
  case '8': return new int[] { 0, 1, 2, 3, 4, 5, 6 };
  case '9': return new int[] { 0, 1, 2, 3, 5, 6 };
  default: return new int[0];
  }
}

ArrayList<float[]> geodesicPortalIntervals(GeodesicJointEdgeProfile joint) {
  ArrayList<float[]> intervals = new ArrayList<float[]>();
  if (joint == null || joint.edgeLengthMM <= 0) return intervals;
  float halfWidth = 0.5f * joint.portalWidthMM / joint.edgeLengthMM;
  for (float center : joint.portalCenters) {
    float start = constrain(center - halfWidth, 0.01f, 0.99f);
    float end = constrain(center + halfWidth, 0.01f, 0.99f);
    if (end - start > 0.001f) intervals.add(new float[] { start, end });
  }
  return intervals;
}

PVector geodesicEdgePoint(PVector a, PVector b, float t, float z) {
  float clamped = constrain(t, 0, 1);
  PVector point;
  if (clamped <= 0.000001f) point = a.copy();
  else if (clamped >= 0.999999f) point = b.copy();
  else point = PVector.lerp(a, b, clamped);
  point.z = z;
  return point;
}

PVector geodesicAtZ(PVector point, float z) {
  return new PVector(point.x, point.y, z);
}

ArrayList<String> geodesicBoundaryEdgeReport(SurfaceMesh mesh, int limit) {
  HashMap<String, Integer> counts = new HashMap<String, Integer>();
  for (MeshTri tri : mesh.tris) {
    geodesicCountAuditEdge(mesh, counts, tri.a, tri.b);
    geodesicCountAuditEdge(mesh, counts, tri.b, tri.c);
    geodesicCountAuditEdge(mesh, counts, tri.c, tri.a);
  }
  ArrayList<String> result = new ArrayList<String>();
  for (String key : counts.keySet()) {
    if (counts.get(key) == 1) result.add(key);
  }
  java.util.Collections.sort(result);
  if (result.size() > limit) return new ArrayList<String>(result.subList(0, limit));
  return result;
}

ArrayList<String> geodesicNonmanifoldEdgeReport(SurfaceMesh mesh, int limit) {
  ArrayList<String> result = new ArrayList<String>();
  if (mesh == null) return result;
  HashMap<String, Integer> counts = new HashMap<String, Integer>();
  HashMap<String, Integer> balances = new HashMap<String, Integer>();
  for (MeshTri tri : mesh.tris) {
    PVector[] points = { tri.a, tri.b, tri.c };
    for (int edge = 0; edge < 3; edge++) {
      String a = mesh.auditVertexKey(points[edge]);
      String b = mesh.auditVertexKey(points[(edge + 1) % 3]);
      boolean forward = a.compareTo(b) <= 0;
      String key = forward ? a + "|" + b : b + "|" + a;
      counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
      int direction = forward ? 1 : -1;
      balances.put(key, balances.containsKey(key) ?
        balances.get(key) + direction : direction);
    }
  }
  for (String key : counts.keySet()) {
    int count = counts.get(key);
    int balance = balances.get(key);
    if (count > 2 || (count == 2 && abs(balance) == 2)) {
      result.add(key + " count=" + count + " balance=" + balance);
      if (result.size() >= max(1, limit)) break;
    }
  }
  return result;
}

void geodesicCountAuditEdge(SurfaceMesh mesh, HashMap<String, Integer> counts,
  PVector a, PVector b) {
  String ka = mesh.auditVertexKey(a);
  String kb = mesh.auditVertexKey(b);
  String key = ka.compareTo(kb) <= 0 ? ka + "|" + kb : kb + "|" + ka;
  counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
}

ArrayList<PVector> geodesicCopyPolygon(ArrayList<PVector> source) {
  ArrayList<PVector> result = new ArrayList<PVector>();
  for (PVector point : source) result.add(new PVector(point.x, point.y, 0));
  return result;
}

float geodesicPolygonArea(ArrayList<PVector> polygon) {
  float area = 0;
  for (int i = 0; i < polygon.size(); i++) {
    PVector a = polygon.get(i);
    PVector b = polygon.get((i + 1) % polygon.size());
    area += a.x * b.y - b.x * a.y;
  }
  return area * 0.5f;
}

PVector geodesicPolygonCentroid(ArrayList<PVector> polygon) {
  PVector center = new PVector();
  for (PVector point : polygon) center.add(point);
  if (polygon.size() > 0) center.div(polygon.size());
  center.z = 0;
  return center;
}

PVector geodesicPolygonAreaCentroid(ArrayList<PVector> polygon) {
  if (polygon == null || polygon.size() < 3)
    return polygon == null ? new PVector() : geodesicPolygonCentroid(polygon);
  float twiceArea = 0;
  float weightedX = 0;
  float weightedY = 0;
  for (int i = 0; i < polygon.size(); i++) {
    PVector a = polygon.get(i);
    PVector b = polygon.get((i + 1) % polygon.size());
    float cross = a.x * b.y - b.x * a.y;
    twiceArea += cross;
    weightedX += (a.x + b.x) * cross;
    weightedY += (a.y + b.y) * cross;
  }
  if (abs(twiceArea) < 0.000001f) return geodesicPolygonCentroid(polygon);
  return new PVector(weightedX / (3.0f * twiceArea),
    weightedY / (3.0f * twiceArea), 0);
}

float geodesicMinimumCentroidEdgeDistance(ArrayList<PVector> polygon) {
  PVector center = geodesicPolygonCentroid(polygon);
  float minimum = Float.MAX_VALUE;
  for (int i = 0; i < polygon.size(); i++) {
    PVector a = polygon.get(i);
    PVector b = polygon.get((i + 1) % polygon.size());
    PVector edge = PVector.sub(b, a);
    float length = edge.mag();
    if (length < 0.0001f) continue;
    float distance = abs(edge.x * (a.y - center.y) - (a.x - center.x) * edge.y) / length;
    minimum = min(minimum, distance);
  }
  return minimum == Float.MAX_VALUE ? 0 : minimum;
}

ArrayList<PVector> geodesicInsetConvexPolygon(ArrayList<PVector> polygon, float distance) {
  int n = polygon.size();
  if (n < 3) return null;
  ArrayList<PVector> result = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector previous = polygon.get((i - 1 + n) % n);
    PVector current = polygon.get(i);
    PVector next = polygon.get((i + 1) % n);
    PVector prevDir = PVector.sub(current, previous);
    PVector nextDir = PVector.sub(next, current);
    if (prevDir.magSq() < 0.000001f || nextDir.magSq() < 0.000001f) return null;
    prevDir.normalize();
    nextDir.normalize();
    PVector prevPoint = new PVector(current.x - prevDir.y * distance,
      current.y + prevDir.x * distance, 0);
    PVector nextPoint = new PVector(current.x - nextDir.y * distance,
      current.y + nextDir.x * distance, 0);
    PVector intersection = geodesicLineIntersection(prevPoint, prevDir, nextPoint, nextDir);
    if (intersection == null) return null;
    result.add(intersection);
  }
  return result;
}

ArrayList<PVector> geodesicInsetConvexPolygonVariable(
  ArrayList<PVector> polygon, float[] distances) {
  int n = polygon == null ? 0 : polygon.size();
  if (n < 3 || distances == null || distances.length != n) return null;
  ArrayList<PVector> result = new ArrayList<PVector>();
  for (int i = 0; i < n; i++) {
    PVector previous = polygon.get((i - 1 + n) % n);
    PVector current = polygon.get(i);
    PVector next = polygon.get((i + 1) % n);
    PVector prevDir = PVector.sub(current, previous);
    PVector nextDir = PVector.sub(next, current);
    if (prevDir.magSq() < 0.000001f || nextDir.magSq() < 0.000001f) return null;
    prevDir.normalize();
    nextDir.normalize();
    float previousDistance = distances[(i - 1 + n) % n];
    float nextDistance = distances[i];
    PVector prevPoint = new PVector(
      current.x - prevDir.y * previousDistance,
      current.y + prevDir.x * previousDistance, 0);
    PVector nextPoint = new PVector(
      current.x - nextDir.y * nextDistance,
      current.y + nextDir.x * nextDistance, 0);
    PVector intersection = geodesicLineIntersection(
      prevPoint, prevDir, nextPoint, nextDir);
    if (intersection == null) return null;
    result.add(intersection);
  }
  return result;
}

PVector geodesicLineIntersection(PVector a, PVector directionA,
  PVector b, PVector directionB) {
  float cross = directionA.x * directionB.y - directionA.y * directionB.x;
  if (abs(cross) < 0.00001f) return null;
  float dx = b.x - a.x;
  float dy = b.y - a.y;
  float t = (dx * directionB.y - dy * directionB.x) / cross;
  return new PVector(a.x + directionA.x * t, a.y + directionA.y * t, 0);
}

ArrayList<PVector> geodesicScalePolygonFromCentroid(ArrayList<PVector> polygon, float scale) {
  ArrayList<PVector> result = new ArrayList<PVector>();
  PVector center = geodesicPolygonCentroid(polygon);
  for (PVector point : polygon) {
    PVector value = PVector.sub(point, center).mult(scale).add(center);
    value.z = 0;
    result.add(value);
  }
  return result;
}

String geodesicPanelSignature(GeodesicModel model, GeodesicFace face,
  float thickness, GeodesicGrowthMode growthMode, float relief) {
  PVector a = model.vertices.get(face.a).position;
  PVector b = model.vertices.get(face.b).position;
  PVector c = model.vertices.get(face.c).position;
  float[] edges = { PVector.dist(a, b), PVector.dist(b, c), PVector.dist(c, a) };
  java.util.Arrays.sort(edges);
  return round(edges[0] * 100.0f) + "_" + round(edges[1] * 100.0f) + "_" +
    round(edges[2] * 100.0f) + "_t" + round(thickness * 100.0f) + "_r" +
    round(relief * 100.0f) + "_" + growthMode.name();
}

GeodesicPanelCatalog buildGeodesicPanelCatalog(GeodesicModel model, float thickness,
  GeodesicGrowthMode growthMode, float relief) {
  GeodesicPanelCatalog catalog = new GeodesicPanelCatalog();
  HashMap<String, GeodesicPartType> bySignature = new HashMap<String, GeodesicPartType>();
  for (GeodesicFace face : model.faces) {
    String signature = geodesicPanelSignature(model, face, thickness, growthMode, relief);
    GeodesicPartType type = bySignature.get(signature);
    if (type == null) {
      type = new GeodesicPartType();
      type.typeId = "P" + nf(bySignature.size() + 1, 3);
      type.signature = signature;
      type.representativeFaceId = face.id;
      GeodesicPart representative = buildGeodesicFacePart(model, face, thickness, growthMode, relief);
      type.mesh = geodesicMeshToFaceLocal(representative.mesh, model, face);
      type.audit = type.mesh.manifoldAudit();
      bySignature.put(signature, type);
      catalog.types.add(type);
    }
    type.quantity++;
    type.faceIds.add(face.id);
    catalog.faceToType.put(face.id, type.typeId);
  }
  return catalog;
}

String geodesicFabricatedPanelSignature(GeodesicFabricationFace face,
  GeodesicFabricationSettings settings, GeodesicGrowthMode growthMode, float relief) {
  GeodesicFabricationSettings resolved = face.resolvedFabrication == null ?
    geodesicResolveFabricationDimensions(face, settings) : face.resolvedFabrication;
  String[] edgeTerms = new String[face.vertexCount()];
  for (int i = 0; i < face.vertexCount(); i++) {
    GeodesicJointEdgeProfile joint = face.joints.get(i);
    edgeTerms[i] = round(joint.edgeLengthMM * 100.0f) + "p" +
      joint.portalCenters.size() + "w" + round(joint.portalWidthMM * 100.0f) +
      "c" + round(joint.cornerClearanceMM * 100.0f) + "m" + joint.mateCode +
      "k" + joint.kicasRole;
  }
  String edgeSignature = geodesicCanonicalCyclicSignature(edgeTerms);
  return "n" + face.vertexCount() + "_" + edgeSignature + "_" + resolved.style.name() +
    "_rs" + resolved.reliefSide.name() +
    "_sp" + resolved.seamProfile.name() +
    "_fd" + round(resolved.frameDepthMM * 100.0f) +
    "_fw" + round(resolved.frameWidthMM * 100.0f) +
    "_sk" + round(resolved.skinThicknessMM * 100.0f) +
    "_pw" + round(resolved.portalWidthMM * 100.0f) +
    "_ph" + round(resolved.portalHeightMM * 100.0f) +
    "_eb" + round(resolved.edgeBreakMM * 100.0f) +
    "_r" + round(relief * 100.0f) + "_" + growthMode.name();
}

String geodesicCanonicalCyclicSignature(String[] terms) {
  if (terms == null || terms.length == 0) return "";
  String best = null;
  for (int offset = 0; offset < terms.length; offset++) {
    String candidate = "";
    for (int i = 0; i < terms.length; i++)
      candidate += (i == 0 ? "" : "-") + terms[(i + offset) % terms.length];
    if (best == null || candidate.compareTo(best) < 0) best = candidate;
  }
  return best == null ? "" : best;
}

GeodesicPanelCatalog buildGeodesicPanelCatalog(GeodesicModel model,
  GeodesicFabricationSettings settings, GeodesicGrowthMode growthMode, float relief) {
  GeodesicPanelCatalog catalog = new GeodesicPanelCatalog();
  catalog.fabrication = settings == null ? null : settings.copy();
  HashMap<String, GeodesicPartType> bySignature = new HashMap<String, GeodesicPartType>();
  for (GeodesicFace face : model.faces) {
    GeodesicFabricationFace fabricationFace = geodesicFabricationFace(model, face, settings);
    String signature = geodesicFabricatedPanelSignature(fabricationFace, settings, growthMode, relief);
    GeodesicPartType type = bySignature.get(signature);
    if (type == null) {
      type = new GeodesicPartType();
      type.typeId = "P" + nf(bySignature.size() + 1, 3);
      type.signature = signature;
      type.representativeFaceId = face.id;
      GeodesicPart representative = buildGeodesicFabricatedPart(model, face, settings,
        growthMode, relief);
      ArrayList<String> logicalMateCodes = new ArrayList<String>();
      for (GeodesicJointEdgeProfile joint : representative.fabricationFace.joints)
        logicalMateCodes.add(joint.mateCode);
      type.physicalEdgeCodesRequested = settings.edgeCodesEnabled &&
        settings.style != GeodesicPanelStyle.SOLID;
      type.physicalEdgeCodesApplied = type.physicalEdgeCodesRequested;
      type.physicalEdgeCodeStatus = type.physicalEdgeCodesRequested ?
        "raised_interior" : "not_requested";
      if (type.physicalEdgeCodesRequested &&
          !geodesicAuditClean(representative.audit)) {
        type.codedAudit = representative.audit == null ? null :
          java.util.Arrays.copyOf(representative.audit, representative.audit.length);
        GeodesicFabricationSettings fallback = settings.copy();
        fallback.edgeCodesEnabled = false;
        GeodesicPart uncoded = buildGeodesicFabricatedPart(model, face, fallback,
          growthMode, relief);
        if (geodesicAuditClean(uncoded.audit)) {
          representative = uncoded;
          type.physicalEdgeCodesApplied = false;
          type.physicalEdgeCodeStatus =
            "omitted_after_manifold_fallback_use_bom_json_guide";
        } else {
          type.physicalEdgeCodeStatus = "manifold_fallback_failed";
        }
      }
      type.mesh = representative.mesh;
      type.audit = representative.audit;
      type.fabrication = representative.fabrication.copy();
      type.portalCount = representative.fabricationFace.portalCount();
      type.edgeCodes.addAll(logicalMateCodes);
      bySignature.put(signature, type);
      catalog.types.add(type);
    }
    type.quantity++;
    type.faceIds.add(face.id);
    catalog.faceToType.put(face.id, type.typeId);
  }
  return catalog;
}

boolean geodesicAuditClean(int[] audit) {
  return audit != null && audit.length >= 3 &&
    audit[0] == 0 && audit[1] == 0 && audit[2] == 0;
}

SurfaceMesh geodesicMeshToFaceLocal(SurfaceMesh source, GeodesicModel model, GeodesicFace face) {
  SurfaceMesh local = new SurfaceMesh("geodesic_panel_type");
  PVector a = model.vertices.get(face.a).position;
  PVector b = model.vertices.get(face.b).position;
  PVector origin = face.centroid.copy();
  PVector axisX = PVector.sub(b, a);
  if (axisX.magSq() < 0.000001f) axisX.set(1, 0, 0);
  axisX.normalize();
  PVector axisZ = face.normal.copy();
  if (axisZ.magSq() < 0.000001f) axisZ.set(0, 0, 1);
  axisZ.normalize();
  PVector axisY = axisZ.cross(axisX);
  if (axisY.magSq() < 0.000001f) axisY.set(0, 1, 0);
  axisY.normalize();
  for (MeshTri tri : source.tris) {
    local.addTri(
      geodesicToLocal(tri.a, origin, axisX, axisY, axisZ),
      geodesicToLocal(tri.b, origin, axisX, axisY, axisZ),
      geodesicToLocal(tri.c, origin, axisX, axisY, axisZ));
  }
  return local;
}

PVector geodesicToLocal(PVector point, PVector origin, PVector axisX, PVector axisY, PVector axisZ) {
  PVector delta = PVector.sub(point, origin);
  return new PVector(delta.dot(axisX), delta.dot(axisY), delta.dot(axisZ));
}

JSONObject geodesicAssemblyPlanJSON(GeodesicModel model, GeodesicPanelCatalog catalog) {
  GeodesicFabricationSettings legacy = new GeodesicFabricationSettings();
  legacy.style = GeodesicPanelStyle.SOLID;
  legacy.fastenerPortals = false;
  return geodesicAssemblyPlanJSON(model, catalog, legacy);
}

JSONObject geodesicAssemblyPlanJSON(GeodesicModel model, GeodesicPanelCatalog catalog,
  GeodesicFabricationSettings settings) {
  JSONObject json = new JSONObject();
  json.setString("coordinate_system", "model_mm_right_handed");
  json.setString("assembly_rule", settings.assemblyMode ==
    GeodesicAssemblyMode.KICAS ?
    "follow ordered P### placements; slide each male capture into its parent female station, verify ALIGN edges, then optionally zip tie every enlarged center portal" :
    "match identical logical edge_mate_codes, verify listed neighbors, and align integral portal schedules; use physical raised marks where present and BOM/JSON/guide codes for fallback parts; repeated type_id values reuse one STL");
  json.setJSONObject("fabrication", settings.toJSON());
  json.setJSONObject("slicer_scale_reference",
    geodesicSlicerScaleReferenceJSON(model, settings.fabricationScale));
  JSONObject codebook = new JSONObject();
  codebook.setString("RIM", "boundary edge; no mating panel");
  for (GeodesicEdge edge : model.edges) {
    String key = geodesicModelEdgeCompatibilityKey(model, edge);
    String code = key.equals("RIM") ? "RIM" : geodesicEdgeCompatibilityCode(model, key);
    if (!codebook.hasKey(code)) codebook.setString(code, key);
  }
  json.setJSONObject("edge_mate_codebook", codebook);
  JSONArray placements = new JSONArray();
  for (int i = 0; i < model.faces.size(); i++) {
    GeodesicFace face = model.faces.get(i);
    JSONObject placement = new JSONObject();
    placement.setInt("face_id", face.id);
    if (settings.assemblyMode == GeodesicAssemblyMode.KICAS &&
        settings.kicasPlan != null) {
      placement.setString("placement_id",
        settings.kicasPlan.labelForFace(face.id));
      placement.setInt("assembly_order",
        settings.kicasPlan.orderForFace(face.id));
    }
    String typeId = catalog.faceToType.get(face.id);
    placement.setString("type_id", typeId);
    GeodesicPartType placementType = catalog.typeById(typeId);
    placement.setBoolean("physical_edge_codes_applied",
      placementType != null && placementType.physicalEdgeCodesApplied);
    placement.setString("physical_edge_code_status",
      placementType == null ? "unknown" : placementType.physicalEdgeCodeStatus);
    placement.setInt("parent_seed_face", face.parentFace);
    JSONArray neighbors = new JSONArray();
    for (int n = 0; n < face.neighbors.length; n++) neighbors.setInt(n, face.neighbors[n]);
    placement.setJSONArray("neighbors_by_edge_ab_bc_ca", neighbors);
    JSONArray vertexIds = new JSONArray();
    vertexIds.setInt(0, face.a); vertexIds.setInt(1, face.b); vertexIds.setInt(2, face.c);
    placement.setJSONArray("vertex_ids_abc", vertexIds);
    JSONArray vertices = new JSONArray();
    int[] ids = { face.a, face.b, face.c };
    for (int v = 0; v < 3; v++) {
      PVector point = model.vertices.get(ids[v]).position;
      JSONArray xyz = new JSONArray();
      xyz.setFloat(0, point.x); xyz.setFloat(1, point.y); xyz.setFloat(2, point.z);
      vertices.setJSONArray(v, xyz);
    }
    placement.setJSONArray("vertices_mm_abc", vertices);
    JSONArray center = new JSONArray();
    center.setFloat(0, face.centroid.x); center.setFloat(1, face.centroid.y); center.setFloat(2, face.centroid.z);
    placement.setJSONArray("center_mm", center);
    JSONArray normal = new JSONArray();
    normal.setFloat(0, face.normal.x); normal.setFloat(1, face.normal.y); normal.setFloat(2, face.normal.z);
    placement.setJSONArray("outward_normal", normal);
    GeodesicFabricationFace fabricationFace = geodesicFabricationFace(model, face, settings);
    placement.setJSONObject("resolved_dimensions", fabricationFace.resolvedDimensionsJSON());
    JSONArray joints = new JSONArray();
    JSONArray mateCodes = new JSONArray();
    for (int edge = 0; edge < fabricationFace.joints.size(); edge++) {
      joints.setJSONObject(edge, fabricationFace.joints.get(edge).toJSON());
      mateCodes.setString(edge, fabricationFace.joints.get(edge).mateCode);
    }
    placement.setJSONArray("edge_mate_codes_ab_bc_ca", mateCodes);
    placement.setJSONArray("edge_joint_profiles", joints);
    placements.setJSONObject(i, placement);
  }
  json.setJSONArray("placements", placements);
  return json;
}

PVector geodesicNominalAssemblyDimensionsMM(GeodesicModel model) {
  if (model == null || model.vertices.size() == 0) return new PVector();
  float minX = Float.MAX_VALUE;
  float minY = Float.MAX_VALUE;
  float minZ = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE;
  float maxY = -Float.MAX_VALUE;
  float maxZ = -Float.MAX_VALUE;
  for (GeodesicVertex vertex : model.vertices) {
    minX = min(minX, vertex.position.x);
    minY = min(minY, vertex.position.y);
    minZ = min(minZ, vertex.position.z);
    maxX = max(maxX, vertex.position.x);
    maxY = max(maxY, vertex.position.y);
    maxZ = max(maxZ, vertex.position.z);
  }
  return new PVector(maxX - minX, maxY - minY, maxZ - minZ);
}

String geodesicSlicerScaleDimensions(GeodesicModel model, int percent) {
  return geodesicSlicerScaleDimensions(model, 1.0f, percent);
}

String geodesicSlicerScaleDimensions(GeodesicModel model,
  float fabricationScale, int percent) {
  PVector dimensions = geodesicNominalAssemblyDimensionsMM(model);
  float factor = max(1, percent) / 100.0f * max(1.0f, fabricationScale);
  return round(dimensions.x * factor) + " x " +
    round(dimensions.y * factor) + " x " +
    round(dimensions.z * factor) + " mm";
}

JSONObject geodesicSlicerScaleReferenceJSON(GeodesicModel model) {
  return geodesicSlicerScaleReferenceJSON(model, 1.0f);
}

JSONObject geodesicSlicerScaleReferenceJSON(GeodesicModel model,
  float fabricationScale) {
  JSONObject json = new JSONObject();
  json.setString("schema", "fieldworks.geodesic_salon.slicer_scale_reference.v1");
  json.setString("units", "mm");
  json.setString("axis_order", "width_x_depth_x_height");
  float resolvedScale = max(1.0f, fabricationScale);
  json.setString("measurement_basis",
    "assembled model vertex bounds after resolved fabrication scale");
  json.setFloat("resolved_fabrication_scale", resolvedScale);
  json.setString("instruction", "apply the same percentage to X, Y, and Z for every reusable part STL");
  JSONArray values = new JSONArray();
  int[] percents = { 100, 200, 300 };
  PVector dimensions = geodesicNominalAssemblyDimensionsMM(model);
  for (int i = 0; i < percents.length; i++) {
    float factor = percents[i] / 100.0f * resolvedScale;
    JSONObject scale = new JSONObject();
    scale.setInt("uniform_scale_percent", percents[i]);
    scale.setFloat("width_mm", dimensions.x * factor);
    scale.setFloat("depth_mm", dimensions.y * factor);
    scale.setFloat("height_mm", dimensions.z * factor);
    values.setJSONObject(i, scale);
  }
  json.setJSONArray("reference_scales", values);
  return json;
}

float geodesicPlateauAngleDegrees() {
  return degrees(acos(-1.0f / 3.0f));
}

int geodesicNeighborEdgeIndex(GeodesicFace face, int neighborFaceId) {
  if (face == null) return -1;
  for (int edge = 0; edge < face.neighbors.length; edge++)
    if (face.neighbors[edge] == neighborFaceId) return edge;
  return -1;
}

GeodesicFabricationFace geodesicRegularFabricationFace(int sides, float radius,
  GeodesicFabricationSettings settings) {
  GeodesicFabricationFace face = new GeodesicFabricationFace();
  face.faceId = 0;
  face.axisZ.set(0, 0, 1);
  sides = max(3, sides);
  for (int i = 0; i < sides; i++) {
    float angle = -HALF_PI + TWO_PI * i / sides;
    face.boundary.add(new PVector(cos(angle) * radius, sin(angle) * radius, 0));
    face.vertexIds.add(i);
    face.neighborFaceIds.add(-1);
  }
  geodesicNormalizeFabricationWinding(face);
  GeodesicFabricationSettings resolved = geodesicResolveFabricationDimensions(face, settings);
  geodesicEnsureJointProfiles(face, resolved);
  return face;
}

class GeodesicTestReport {
  int passed;
  int failed;
  ArrayList<String> failures = new ArrayList<String>();

  void check(boolean condition, String label) {
    if (condition) passed++;
    else { failed++; failures.add(label); }
  }

  String summary() { return passed + "/" + (passed + failed) + (failed == 0 ? " PASS" : " FAIL"); }
}

float geodesicMaximumVertexRadius(GeodesicModel model) {
  float result = 0;
  if (model == null) return result;
  for (GeodesicVertex vertex : model.vertices)
    result = max(result, vertex.position.mag());
  return result;
}

float geodesicPanelCenterPeakZ(GeodesicPart part) {
  if (part == null || part.mesh == null || part.fabricationFace == null) return -Float.MAX_VALUE;
  ArrayList<PVector> outer = geodesicCopyPolygon(part.fabricationFace.boundary);
  float apothem = geodesicMinimumCentroidEdgeDistance(outer);
  float frameWidth = constrain(part.fabrication.frameWidthMM, 0.8f,
    max(0.9f, apothem * 0.72f));
  ArrayList<PVector> inner = geodesicInsetConvexPolygon(outer, frameWidth);
  if (inner == null || inner.size() != outer.size() ||
      abs(geodesicPolygonArea(inner)) < 0.01f)
    inner = geodesicScalePolygonFromCentroid(outer,
      constrain(1.0f - frameWidth / max(0.001f, apothem), 0.18f, 0.82f));
  if (part.fabrication.reliefSide == GeodesicReliefSide.EXTERIOR_CROWN &&
      part.fabrication.edgeBreakMM > 0.001f) {
    ArrayList<PVector> crownBoundary = geodesicInsetConvexPolygon(outer,
      max(0.01f, frameWidth - part.fabrication.edgeBreakMM));
    if (crownBoundary != null && crownBoundary.size() == inner.size()) inner = crownBoundary;
  }
  PVector center = geodesicPolygonCentroid(inner);
  float peak = -Float.MAX_VALUE;
  for (MeshTri tri : part.mesh.tris) {
    PVector[] points = { tri.a, tri.b, tri.c };
    for (PVector point : points) {
      float dx = point.x - center.x;
      float dy = point.y - center.y;
      if (dx * dx + dy * dy < 0.0001f) peak = max(peak, point.z);
    }
  }
  return peak;
}

float geodesicMeshMinimumZ(SurfaceMesh mesh) {
  if (mesh == null || mesh.tris.size() == 0) return Float.NaN;
  float minimum = Float.MAX_VALUE;
  for (MeshTri tri : mesh.tris) {
    minimum = min(minimum, tri.a.z);
    minimum = min(minimum, tri.b.z);
    minimum = min(minimum, tri.c.z);
  }
  return minimum;
}

float geodesicMeshMaximumZ(SurfaceMesh mesh) {
  if (mesh == null || mesh.tris.size() == 0) return Float.NaN;
  float maximum = -Float.MAX_VALUE;
  for (MeshTri tri : mesh.tris) {
    maximum = max(maximum, tri.a.z);
    maximum = max(maximum, tri.b.z);
    maximum = max(maximum, tri.c.z);
  }
  return maximum;
}

String geodesicDegenerateTriangleSummary(SurfaceMesh mesh, int limit) {
  if (mesh == null) return "mesh null";
  ArrayList<String> values = new ArrayList<String>();
  for (int i = 0; i < mesh.tris.size() && values.size() < max(1, limit); i++) {
    MeshTri tri = mesh.tris.get(i);
    float areaSq = PVector.sub(tri.b, tri.a).cross(PVector.sub(tri.c, tri.a)).magSq();
    if (areaSq < 0.00000001f)
      values.add(i + ":" + nf(areaSq, 1, 10) +
        " z" + nf(tri.a.z, 1, 3) + "/" + nf(tri.b.z, 1, 3) +
        "/" + nf(tri.c.z, 1, 3) +
        " ab" + nf(PVector.dist(tri.a, tri.b), 1, 5) +
        " ac" + nf(PVector.dist(tri.a, tri.c), 1, 5));
  }
  return values.size() == 0 ? "none" : join(values.toArray(new String[values.size()]), ",");
}

GeodesicTestReport runGeodesicCoreTests() {
  GeodesicTestReport report = new GeodesicTestReport();
  GeodesicModel tetra = buildGeodesicModel(GeodesicSeedFamily.TETRAHEDRAL, GeodesicExtentMode.SPHERE, 2, 40, 0);
  GeodesicModel octa = buildGeodesicModel(GeodesicSeedFamily.OCTAHEDRAL, GeodesicExtentMode.SPHERE, 2, 40, 0);
  GeodesicModel icosa = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL, GeodesicExtentMode.SPHERE, 2, 40, 0);
  GeodesicModel dodeca = buildGeodesicModel(GeodesicSeedFamily.DODECAHEDRAL,
    GeodesicExtentMode.SPHERE, 1, 40, 0);
  GeodesicModel rhombic30 = buildGeodesicModel(GeodesicSeedFamily.RHOMBIC_TRIACONTAHEDRAL,
    GeodesicExtentMode.SPHERE, 1, 40, 0);
  GeodesicModel stellatedIcosa = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL,
    GeodesicExtentMode.SPHERE, 1, 40, 0, GeodesicFormModifier.FACE_STELLATION, 0.18f);
  report.check(tetra.faces.size() == 16 && tetra.eulerCharacteristic == 2, "tetra f2 counts");
  report.check(octa.faces.size() == 32 && octa.eulerCharacteristic == 2, "octa f2 counts");
  report.check(icosa.faces.size() == 80 && icosa.vertices.size() == 42 && icosa.edges.size() == 120, "icosa f2 VEF");
  report.check(dodeca.valid && dodeca.vertices.size() == 20 &&
    dodeca.edges.size() == 54 && dodeca.faces.size() == 36 &&
    dodeca.eulerCharacteristic == 2, "dodeca triangulated seed VEF");
  report.check(rhombic30.valid && rhombic30.vertices.size() == 32 &&
    rhombic30.edges.size() == 90 && rhombic30.faces.size() == 60 &&
    rhombic30.eulerCharacteristic == 2, "rhombic triaconta triangulated seed VEF");
  report.check(stellatedIcosa.valid && stellatedIcosa.modifier ==
    GeodesicFormModifier.FACE_STELLATION && stellatedIcosa.vertices.size() == 32 &&
    stellatedIcosa.edges.size() == 90 && stellatedIcosa.faces.size() == 60,
    "icosa face stellation VEF");
  GeodesicModel tallerStellation = buildGeodesicModel(
    GeodesicSeedFamily.ICOSAHEDRAL, GeodesicExtentMode.SPHERE, 1, 40, 0,
    GeodesicFormModifier.FACE_STELLATION, 0.32f);
  report.check(!stellatedIcosa.fingerprint.equals(tallerStellation.fingerprint) &&
    geodesicMaximumVertexRadius(tallerStellation) >
    geodesicMaximumVertexRadius(stellatedIcosa) + 4.0f,
    "stellation height changes generated shell");
  int[] dodecaShellAudit = buildGeodesicCombinedShell(dodeca, 2.4f).manifoldAudit();
  int[] rhombicShellAudit = buildGeodesicCombinedShell(rhombic30, 2.4f).manifoldAudit();
  int[] stellatedShellAudit = buildGeodesicCombinedShell(stellatedIcosa, 2.4f).manifoldAudit();
  report.check(dodecaShellAudit[0] == 0 && dodecaShellAudit[1] == 0 &&
    dodecaShellAudit[2] == 0, "dodeca combined shell watertight");
  report.check(rhombicShellAudit[0] == 0 && rhombicShellAudit[1] == 0 &&
    rhombicShellAudit[2] == 0, "rhombic triaconta combined shell watertight");
  report.check(stellatedShellAudit[0] == 0 && stellatedShellAudit[1] == 0 &&
    stellatedShellAudit[2] == 0, "stellated icosa combined shell watertight");
  report.check(icosa.fiveValentVertices == 12, "icosa twelve five-valent vertices");
  report.check(icosa.valid && icosa.boundaryEdges == 0 &&
    icosa.boundaryLoopCount == 0 && icosa.boundaryChainClosed &&
    icosa.boundaryChainSimple && icosa.nonManifoldEdges == 0,
    "closed geodesic manifold");
  report.check(icosa.gaussBonnetResidual < 0.001f,
    "sphere Gauss-Bonnet curvature budget");
  GeodesicModel dome = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL, GeodesicExtentMode.DOME, 3, 60, 0);
  report.check(dome.valid && dome.boundaryEdges > 2 &&
    dome.boundaryLoopCount == 1 && dome.boundaryChainClosed &&
    dome.boundaryChainSimple && dome.eulerCharacteristic == 1,
    "dome topology disk with one simple polygonal rim");
  report.check(dome.gaussBonnetResidual < 0.001f,
    "dome Gauss-Bonnet curvature budget");
  boolean boundaryPlane = true;
  for (GeodesicEdge edge : dome.edges) if (edge.boundary()) {
    boundaryPlane &= abs(dome.vertices.get(edge.a).position.z - dome.cutZ) < 0.001f;
    boundaryPlane &= abs(dome.vertices.get(edge.b).position.z - dome.cutZ) < 0.001f;
  }
  report.check(boundaryPlane, "dome boundary lies on cut plane");
  SurfaceMesh shell = buildGeodesicCombinedShell(dome, 2.4f);
  int[] shellAudit = shell.manifoldAudit();
  report.check(shellAudit[0] == 0 && shellAudit[1] == 0 && shellAudit[2] == 0, "combined shell watertight");
  GeodesicPart part = buildGeodesicFacePart(dome, dome.faces.get(0), 2.4f, GeodesicGrowthMode.CENTER_TO_EDGE, 1.2f);
  report.check(part.audit[0] == 0 && part.audit[1] == 0 && part.audit[2] == 0, "face part watertight");
  GeodesicFabricationSettings framed = new GeodesicFabricationSettings();
  framed.style = GeodesicPanelStyle.FRAME_SKIN;
  GeodesicPart framedPart = buildGeodesicFabricatedPart(dome, dome.faces.get(0), framed,
    GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  report.check(framedPart.audit[0] == 0 && framedPart.audit[1] == 0 &&
    framedPart.audit[2] == 0 && framedPart.fabricationFace.portalCount() > 0,
    "framed face with portals watertight audit " + framedPart.audit[0] + "/" +
      framedPart.audit[1] + "/" + framedPart.audit[2] + " portals " +
      framedPart.fabricationFace.portalCount());
  boolean seamMetadata = false;
  boolean seamFormula = true;
  boolean seamFeasible = true;
  for (GeodesicJointEdgeProfile joint : framedPart.fabricationFace.joints) {
    if (joint.neighborFaceId < 0) continue;
    seamMetadata = true;
    seamFormula &= abs(joint.recommendedHalfMiterDeg * 2.0f -
      joint.normalAngleDeg) < 0.001f;
    seamFormula &= abs(joint.recommendedMiterInsetMM -
      framedPart.fabrication.frameDepthMM *
      tan(radians(joint.recommendedHalfMiterDeg))) < 0.001f;
    seamFeasible &= joint.miterFeasibleAtResolvedDimensions;
  }
  report.check(seamMetadata && seamFormula && seamFeasible,
    "shared edges record feasible reciprocal half-dihedral miters");
  GeodesicModel tetraF1 = buildGeodesicModel(GeodesicSeedFamily.TETRAHEDRAL,
    GeodesicExtentMode.SPHERE, 1, 72, 0);
  GeodesicFabricationFace tetraMiterFace = geodesicFabricationFace(tetraF1,
    tetraF1.faces.get(0), framed);
  GeodesicFabricationSettings tetraMiterSettings =
    tetraMiterFace.resolvedFabrication;
  GeodesicMiterOuterProfile tetraMiterProfile =
    geodesicBuildMiterOuterProfile(tetraMiterFace,
      geodesicCopyPolygon(tetraMiterFace.boundary),
      tetraMiterSettings.frameDepthMM, tetraMiterSettings.edgeBreakMM);
  GeodesicJointEdgeProfile tetraMiterJoint = tetraMiterFace.joints.get(0);
  float sampleMiterZ = tetraMiterSettings.frameDepthMM * 0.5f;
  PVector sampleMiterPoint = geodesicMiterOuterPoint(
    tetraMiterProfile, 0, 0.5f, sampleMiterZ);
  PVector tetraEdgeDirection = PVector.sub(tetraMiterFace.boundary.get(1),
    tetraMiterFace.boundary.get(0)).normalize();
  PVector tetraEdgeInward = new PVector(-tetraEdgeDirection.y,
    tetraEdgeDirection.x, 0);
  float measuredMiterInset = PVector.sub(sampleMiterPoint,
    tetraMiterFace.boundary.get(0)).dot(tetraEdgeInward);
  float expectedMiterInset = sampleMiterZ *
    tan(radians(tetraMiterJoint.recommendedHalfMiterDeg));
  report.check(tetraMiterSettings.miterDepthAutoCapped &&
    tetraMiterSettings.frameDepthMM < framed.frameDepthMM &&
    abs(measuredMiterInset - expectedMiterInset) < 0.001f,
    "tetra seam auto-limits depth and applies the physical half-dihedral slope");
  GeodesicModel[] signedMiterModels = {
    buildGeodesicModel(GeodesicSeedFamily.TETRAHEDRAL,
      GeodesicExtentMode.SPHERE, 4, 72, 0),
    buildGeodesicModel(GeodesicSeedFamily.DODECAHEDRAL,
      GeodesicExtentMode.SPHERE, 2, 72, 0),
    buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL,
      GeodesicExtentMode.SPHERE, 2, 72, 0,
      GeodesicFormModifier.FACE_STELLATION, 0.18f)
  };
  float[] signedMiterDepths = { 4.0f, 13.0f, 24.0f };
  float[] signedMiterWidths = { 1.2f, 7.0f, 14.0f };
  boolean signedMiterRegression = true;
  boolean signedMiterFoundConcave = false;
  float signedMiterMaximumGap = 0;
  for (int caseIndex = 0; caseIndex < signedMiterModels.length; caseIndex++) {
    GeodesicFabricationSettings signedSettings = framed.copy();
    signedSettings.reliefSide = GeodesicReliefSide.EXTERIOR_CROWN;
    signedSettings.frameDepthMM = signedMiterDepths[caseIndex];
    signedSettings.requestedFrameDepthMM = signedMiterDepths[caseIndex];
    signedSettings.frameWidthMM = signedMiterWidths[caseIndex];
    signedSettings = geodesicResolveKitFabricationSettings(
      signedMiterModels[caseIndex], signedSettings);
    GeodesicSeamAudit signedAudit = geodesicAuditAssembledSeams(
      signedMiterModels[caseIndex], signedSettings);
    signedMiterRegression &= signedAudit != null && signedAudit.valid &&
      signedAudit.maximumCrossSeamGapMM <= signedAudit.toleranceMM;
    if (signedAudit != null)
      signedMiterMaximumGap = max(signedMiterMaximumGap,
        signedAudit.maximumCrossSeamGapMM);
    for (GeodesicFace signedFace : signedMiterModels[caseIndex].faces) {
      GeodesicFabricationFace signedFabricationFace =
        geodesicFabricationFace(signedMiterModels[caseIndex], signedFace,
        signedSettings);
      signedMiterRegression &=
        abs(signedFabricationFace.resolvedFabrication.frameDepthMM -
          signedSettings.frameDepthMM) < 0.001f &&
        abs(signedFabricationFace.resolvedFabrication.frameWidthMM -
          signedSettings.frameWidthMM) < 0.001f;
      for (GeodesicJointEdgeProfile signedJoint :
          signedFabricationFace.joints) {
        if (!signedJoint.concaveJoint) continue;
        signedMiterFoundConcave = true;
        signedMiterRegression &= signedJoint.miterInsetSign < 0;
      }
    }
  }
  report.check(signedMiterRegression && signedMiterFoundConcave,
    "signed concave miters close across low, nominal, and deep panel settings " +
      nf(signedMiterMaximumGap, 1, 4) + "mm");
  float framedMinimumZ = geodesicMeshMinimumZ(framedPart.mesh);
  JSONObject framedFabricationJSON = framedPart.fabrication.toJSON();
  report.check(!Float.isNaN(framedMinimumZ) && framedMinimumZ >= -0.00001f,
    "raised interior mate codes preserve the exterior base plane minZ " +
      nf(framedMinimumZ, 1, 4));
  report.check(!framedFabricationJSON.getBoolean("recessed_edge_codes") &&
    framedFabricationJSON.getBoolean("embossed_edge_codes") &&
    framedFabricationJSON.getString("edge_code_treatment").equals("RAISED_INTERIOR") &&
    framedFabricationJSON.getString("edge_code_glyph_style").equals("RAISED_ROUNDED_STROKE") &&
    framedFabricationJSON.getFloat("edge_code_height_mm") > 0,
    "fabrication provenance records raised interior mate codes");
  report.check(framedFabricationJSON.getString("shared_edge_profile").equals(
    "HALF_DIHEDRAL_MITER") &&
    framedFabricationJSON.getBoolean("dihedral_miter_applied"),
    "fabrication provenance records applied half-dihedral miters");
  GeodesicFabricationSettings squareFramed = framed.copy();
  squareFramed.seamProfile = GeodesicSeamProfile.SQUARE;
  GeodesicPart squarePart = buildGeodesicFabricatedPart(dome, dome.faces.get(0),
    squareFramed, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  JSONObject squareFabricationJSON = squarePart.fabrication.toJSON();
  report.check(squarePart.audit[0] == 0 && squarePart.audit[1] == 0 &&
    squarePart.audit[2] == 0 &&
    squareFabricationJSON.getString("shared_edge_profile").equals(
      "SQUARE_UNMITERED") &&
    !squareFabricationJSON.getBoolean("dihedral_miter_applied"),
    "square compatibility seam remains watertight and explicit");
  float glyphPeak = 0;
  for (int gx = 0; gx <= 30; gx++) for (int gy = 0; gy <= 50; gy++)
    glyphPeak = max(glyphPeak,
      geodesicGlyphStrength("A", gx / 10.0f, gy / 10.0f));
  report.check(glyphPeak > 0.95f &&
    geodesicGlyphStrength("A", -1.0f, -1.0f) < 0.001f,
    "rounded stroke glyph field is bounded and deterministic");
  report.check(geodesicGlyphCellActive("A", 1.5f, 0.35f) &&
    geodesicGlyphCellActive("A", 0.35f, 1.5f) &&
    !geodesicGlyphCellActive("A", 1.5f, 1.45f) &&
    !geodesicGlyphCellActive("A", 3.5f, 1.5f),
    "rounded stroke glyphs retain open counters and character gaps");
  boolean numericGlyphsComplete = true;
  for (char digit = '0'; digit <= '9'; digit++)
    numericGlyphsComplete &= geodesicGlyphStrokeSegments(digit).length > 0;
  float placementGlyphPeak = 0;
  for (int gx = 0; gx <= 150; gx++) for (int gy = 0; gy <= 50; gy++)
    placementGlyphPeak = max(placementGlyphPeak,
      geodesicGlyphStrength("P014", gx / 10.0f, gy / 10.0f));
  report.check(numericGlyphsComplete && placementGlyphPeak > 0.95f &&
    geodesicGlyphStrength("P014", 4.45f, 0.35f) > 0.95f &&
    geodesicGlyphStrength("P014", 10.65f, 1.5f) > 0.95f &&
    geodesicGlyphStrength("P014", 12.35f, 1.5f) > 0.95f,
    "P### placement alphabet includes complete legible numeric strokes");
  report.check(abs(geodesicKicasPlacementReadT(0.0f) - 1.0f) < 0.0001f &&
    abs(geodesicKicasPlacementReadT(0.25f) - 0.75f) < 0.0001f &&
    abs(geodesicKicasPlacementReadT(1.0f)) < 0.0001f,
    "KICAS rail placement labels read forward from the assembly interior");
  GeodesicPart innerReliefPart = buildGeodesicFabricatedPart(dome, dome.faces.get(0),
    framed, GeodesicGrowthMode.CENTER_TO_EDGE, 1.2f);
  float innerPeak = geodesicPanelCenterPeakZ(innerReliefPart);
  report.check(innerReliefPart.audit[0] == 0 && innerReliefPart.audit[1] == 0 &&
    innerReliefPart.audit[2] == 0 &&
    innerPeak < innerReliefPart.fabrication.frameDepthMM - 0.01f,
    "default inner reinforcement remains recessed and watertight");
  GeodesicFabricationSettings crowned = framed.copy();
  crowned.reliefSide = GeodesicReliefSide.EXTERIOR_CROWN;
  GeodesicPart crownedPart = buildGeodesicFabricatedPart(dome, dome.faces.get(0),
    crowned, GeodesicGrowthMode.CENTER_TO_EDGE, 1.2f);
  float crownedPeak = geodesicPanelCenterPeakZ(crownedPart);
  report.check(crownedPart.audit[0] == 0 && crownedPart.audit[1] == 0 &&
    crownedPart.audit[2] == 0 &&
    crownedPeak > crownedPart.fabrication.frameDepthMM + 1.19f,
    "exterior crown projects beyond rail and remains watertight audit " +
      crownedPart.audit[0] + "/" + crownedPart.audit[1] + "/" +
      crownedPart.audit[2] + " peak " + nf(crownedPeak, 1, 3) +
      " depth " + nf(crownedPart.fabrication.frameDepthMM, 1, 3));
  GeodesicFabricationSettings tetraInnerKit =
    geodesicResolveKitFabricationSettings(tetraF1, framed);
  GeodesicSeamAudit tetraInnerSeams =
    geodesicAuditAssembledSeams(tetraF1, tetraInnerKit);
  report.check(tetraInnerSeams.valid &&
    tetraInnerSeams.maximumCrossSeamGapMM <= tetraInnerSeams.toleranceMM,
    "inner-reinforcement assembled miter seams close within " +
      nf(tetraInnerSeams.maximumCrossSeamGapMM, 1, 4) + " mm");
  GeodesicFabricationSettings tetraCrownRequested = framed.copy();
  tetraCrownRequested.reliefSide = GeodesicReliefSide.EXTERIOR_CROWN;
  GeodesicFabricationSettings tetraCrownKit =
    geodesicResolveKitFabricationSettings(tetraF1, tetraCrownRequested);
  GeodesicSeamAudit tetraCrownSeams =
    geodesicAuditAssembledSeams(tetraF1, tetraCrownKit);
  report.check(tetraCrownSeams.valid &&
    tetraCrownSeams.maximumCrossSeamGapMM <= tetraCrownSeams.toleranceMM,
    "exterior-crown assembled miter seams close within " +
      nf(tetraCrownSeams.maximumCrossSeamGapMM, 1, 4) + " mm");
  GeodesicFabricationSettings domeCrownKit =
    geodesicResolveKitFabricationSettings(dome, tetraCrownRequested);
  GeodesicSeamAudit domeCrownSeams =
    geodesicAuditAssembledSeams(dome, domeCrownKit);
  report.check(domeCrownSeams.valid &&
    domeCrownSeams.maximumCrossSeamGapMM <= domeCrownSeams.toleranceMM &&
    domeCrownSeams.maximumTangentialGapMM >
      domeCrownSeams.maximumCrossSeamGapMM,
    "subdivided exterior crown distinguishes seam closure from vertex trim " +
      nf(domeCrownSeams.maximumCrossSeamGapMM, 1, 4) + "/" +
      nf(domeCrownSeams.maximumTangentialGapMM, 1, 4) + " mm");
  GeodesicFabricationFace pentagon = geodesicRegularFabricationFace(5, 34, framed);
  SurfaceMesh pentagonMesh = buildGeodesicFabricationMesh(pentagon, framed,
    GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  int[] pentagonAudit = pentagonMesh.manifoldAudit();
  report.check(pentagonAudit[0] == 0 && pentagonAudit[1] == 0 && pentagonAudit[2] == 0 &&
    pentagon.portalCount() == 10, "generic pentagon frame and portal topology audit " +
      pentagonAudit[0] + "/" + pentagonAudit[1] + "/" + pentagonAudit[2] +
      " portals " + pentagon.portalCount());
  GeodesicPart dodecaPart = buildGeodesicFabricatedPart(dodeca, dodeca.faces.get(0),
    framed, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  GeodesicPart rhombicPart = buildGeodesicFabricatedPart(rhombic30,
    rhombic30.faces.get(0), framed, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  GeodesicPart stellatedPart = buildGeodesicFabricatedPart(stellatedIcosa,
    stellatedIcosa.faces.get(0), framed, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  report.check(dodecaPart.audit[0] == 0 && dodecaPart.audit[1] == 0 &&
    dodecaPart.audit[2] == 0, "dodeca reusable panel fabrication watertight");
  report.check(rhombicPart.audit[0] == 0 && rhombicPart.audit[1] == 0 &&
    rhombicPart.audit[2] == 0,
    "rhombic triaconta reusable panel fabrication watertight audit " +
      rhombicPart.audit[0] + "/" + rhombicPart.audit[1] + "/" +
      rhombicPart.audit[2] + " tris " + rhombicPart.mesh.tris.size() +
      " boundary " + geodesicBoundaryEdgeReport(rhombicPart.mesh, 8));
  report.check(stellatedPart.audit[0] == 0 && stellatedPart.audit[1] == 0 &&
    stellatedPart.audit[2] == 0,
    "stellated reusable panel fabrication watertight audit " +
      stellatedPart.audit[0] + "/" + stellatedPart.audit[1] + "/" +
      stellatedPart.audit[2] + " boundary " +
      geodesicBoundaryEdgeReport(stellatedPart.mesh, 12) + " degenerate " +
      geodesicDegenerateTriangleSummary(stellatedPart.mesh, 12));
  GeodesicModel scaledModel = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL,
    GeodesicExtentMode.DOME, 3, 72, 0);
  GeodesicFabricationFace scaledFace = geodesicFabricationFace(scaledModel,
    scaledModel.faces.get(0), framed);
  float scaledSpan = 0;
  for (PVector point : scaledFace.boundary)
    for (PVector other : scaledFace.boundary) scaledSpan = max(scaledSpan, PVector.dist(point, other));
  report.check(scaledFace.resolvedFabrication.frameDepthMM / max(0.001f, scaledSpan) < 0.28f &&
    scaledFace.resolvedFabrication.frameWidthMM / max(0.001f, scaledFace.apothemMM) < 0.38f,
    "small panels use face-relative fabrication dimensions");
  GeodesicFabricationFace referenceScale = geodesicRegularFabricationFace(3, 70, framed);
  report.check(abs(referenceScale.resolvedFabrication.frameDepthMM - framed.frameDepthMM) < 0.01f &&
    abs(referenceScale.resolvedFabrication.frameWidthMM - framed.frameWidthMM) < 0.01f,
    "reference-scale panels retain dimensional caps");
  GeodesicIntrinsicCoordinateSystem coordinates = new GeodesicIntrinsicCoordinateSystem(dome);
  GeodesicFace sampleFace = dome.faces.get(0);
  GeodesicIntrinsicSample center = coordinates.locate(sampleFace.centroid);
  report.check(center.valid && center.faceId == sampleFace.id && center.s < 0.01f, "face center intrinsic coordinate");
  PVector edgeMid = PVector.add(dome.vertices.get(sampleFace.a).position, dome.vertices.get(sampleFace.b).position).mult(0.5f);
  GeodesicIntrinsicSample edgeSample = coordinates.locate(edgeMid);
  report.check(edgeSample.valid && edgeSample.s > 0.98f, "face edge intrinsic coordinate");
  GeodesicModel repeat = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL, GeodesicExtentMode.DOME, 3, 60, 0);
  report.check(dome.fingerprint.equals(repeat.fingerprint), "deterministic fingerprint");
  report.check(abs(geodesicPlateauAngleDegrees() - 109.47122f) < 0.001f, "Plateau tetrahedral angle");
  GeodesicPanelCatalog guideCatalog = buildGeodesicPanelCatalog(dome, framed,
    GeodesicGrowthMode.SHELL_OVERWRAP, 1.2f);
  GeodesicGuideData guideData = buildGeodesicGuideData(dome, guideCatalog, "TEST");
  report.check(guideData.validation.valid() && guideData.stages.size() == 6 &&
    guideData.stages.get(5).faceIds.size() == dome.faces.size(),
    "assembly guide connected stage coverage");
  GeodesicPaintPlan propagationPaintA = buildGeodesicPaintPlan(dome,
    guideCatalog, GeodesicPaintScheme.PROPAGATION, 9, 0);
  GeodesicPaintPlan propagationPaintB = buildGeodesicPaintPlan(dome,
    guideCatalog, GeodesicPaintScheme.PROPAGATION, 9, 0);
  boolean propagationExact = propagationPaintA.effectiveColorCount == 3 &&
    propagationPaintA.assignments.size() == dome.faces.size();
  boolean propagationStable =
    propagationPaintA.assignments.size() ==
    propagationPaintB.assignments.size();
  for (int i = 0; i < propagationPaintA.assignments.size(); i++) {
    GeodesicPaintAssignment a = propagationPaintA.assignments.get(i);
    GeodesicPaintAssignment b = propagationPaintB.assignments.get(i);
    propagationExact &= a.colorIndex >= 0 && a.colorIndex < 3 &&
      a.colorId.equals(geodesicPaintColorId(a.colorIndex)) &&
      a.rgb == geodesicPaintPaletteColor(a.colorIndex);
    propagationStable &= a.faceId == b.faceId &&
      a.colorIndex == b.colorIndex &&
      abs(a.scalar - b.scalar) < 0.000001f;
  }
  report.check(propagationExact,
    "paint propagation preserves the established three-color growth display");
  report.check(propagationStable,
    "paint assignments repeat deterministically for an unchanged model");
  GeodesicPaintPlan weavePaint = buildGeodesicPaintPlan(dome,
    guideCatalog, GeodesicPaintScheme.ADJACENCY_WEAVE, 4, 0);
  boolean weaveSeparatesNeighbors = weavePaint.effectiveColorCount >= 4;
  for (GeodesicEdge edge : dome.edges)
    if (edge.faceA >= 0 && edge.faceB >= 0)
      weaveSeparatesNeighbors &=
        weavePaint.forFace(edge.faceA).colorIndex !=
        weavePaint.forFace(edge.faceB).colorIndex;
  report.check(weaveSeparatesNeighbors,
    "adjacency paint assigns different color IDs across every shared edge");
  GeodesicPaintPlan curvaturePaint = buildGeodesicPaintPlan(dome,
    guideCatalog, GeodesicPaintScheme.CURVATURE, 12, 0.65f);
  GeodesicPaintValidation curvatureValidation =
    validateGeodesicPaintAssignments(curvaturePaint, dome, guideCatalog);
  int curvatureQuantity = 0;
  for (int quantity : curvaturePaint.colorQuantities().values())
    curvatureQuantity += quantity;
  JSONObject curvatureJson = curvaturePaint.toJSON();
  report.check(curvatureValidation.valid &&
    curvaturePaint.usedColorCount() > 0 &&
    curvaturePaint.usedColorCount() <=
      curvaturePaint.effectiveColorCount &&
    curvatureQuantity == dome.faces.size() &&
    curvatureJson.getJSONArray("used_palette").size() ==
      curvaturePaint.usedColorCount(),
    "paint package reports only used colors while preserving every face");
  SurfaceMesh plateProbeMesh = new SurfaceMesh("plate_probe");
  plateProbeMesh.addTri(new PVector(0, 0, 0),
    new PVector(120, 0, 0), new PVector(0, 120, 0));
  GeodesicPlateMeshResource plateProbeResource =
    new GeodesicPlateMeshResource("PTEST", "PTEST", plateProbeMesh);
  ArrayList<GeodesicPlateInstance> plateProbeA =
    new ArrayList<GeodesicPlateInstance>();
  ArrayList<GeodesicPlateInstance> plateProbeB =
    new ArrayList<GeodesicPlateInstance>();
  for (int i = 0; i < 5; i++) {
    plateProbeA.add(new GeodesicPlateInstance(i, "C01",
      color(27, 214, 190), "PTEST", plateProbeResource));
    plateProbeB.add(new GeodesicPlateInstance(i, "C01",
      color(27, 214, 190), "PTEST", plateProbeResource));
  }
  GeodesicPlateKitValidation plateProbeValidationA =
    new GeodesicPlateKitValidation();
  GeodesicPlateKitValidation plateProbeValidationB =
    new GeodesicPlateKitValidation();
  ArrayList<GeodesicPackedPlate> plateProbePlatesA =
    packGeodesicColorPlates("C01", color(27, 214, 190),
      plateProbeA, plateProbeValidationA);
  ArrayList<GeodesicPackedPlate> plateProbePlatesB =
    packGeodesicColorPlates("C01", color(27, 214, 190),
      plateProbeB, plateProbeValidationB);
  int packedProbeCount = 0;
  boolean plateProbeDeterministic =
    plateProbePlatesA.size() == plateProbePlatesB.size();
  for (int i = 0; i < plateProbePlatesA.size(); i++) {
    GeodesicPackedPlate plateA = plateProbePlatesA.get(i);
    GeodesicPackedPlate plateB = plateProbePlatesB.get(i);
    packedProbeCount += plateA.instances.size();
    plateProbeDeterministic &=
      plateA.instances.size() == plateB.instances.size();
    for (int j = 0; j < min(plateA.instances.size(),
        plateB.instances.size()); j++) {
      GeodesicPlateInstance instanceA = plateA.instances.get(j);
      GeodesicPlateInstance instanceB = plateB.instances.get(j);
      plateProbeDeterministic &= instanceA.faceId == instanceB.faceId &&
        abs(instanceA.x - instanceB.x) < 0.0001f &&
        abs(instanceA.y - instanceB.y) < 0.0001f;
    }
  }
  report.check(plateProbePlatesA.size() == 2 &&
    packedProbeCount == 5 &&
    plateProbeValidationA.oversizedInstances == 0 &&
    plateProbeValidationA.outOfBoundsInstances == 0 &&
    plateProbeValidationA.overlapPairs == 0,
    "generic 3MF plate packing splits overflow without overlap");
  report.check(plateProbeDeterministic &&
    plateProbeValidationB.outOfBoundsInstances == 0 &&
    plateProbeValidationB.overlapPairs == 0,
    "generic 3MF plate placement is deterministic");
  int guideBomTotal = 0;
  for (GeodesicPartType type : guideCatalog.types) guideBomTotal += type.quantity;
  report.check(guideBomTotal == dome.faces.size() &&
    guideData.validation.toJSON().getInt("connector_components") == 0,
    "assembly guide BOM and no-hardware contract");
  GeodesicPanelCatalog dodecaCatalog = buildGeodesicPanelCatalog(dodeca, framed,
    GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  GeodesicPanelCatalog rhombicCatalog = buildGeodesicPanelCatalog(rhombic30, framed,
    GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  GeodesicGuideData dodecaGuide = buildGeodesicGuideData(dodeca, dodecaCatalog, "TEST");
  GeodesicGuideData rhombicGuide = buildGeodesicGuideData(rhombic30,
    rhombicCatalog, "TEST");
  report.check(dodecaGuide.validation.valid() &&
    dodecaGuide.stages.get(dodecaGuide.stages.size() - 1).faceIds.size() ==
    dodeca.faces.size(), "dodeca assembly guide covers every placement");
  report.check(rhombicGuide.validation.valid() &&
    rhombicGuide.stages.get(rhombicGuide.stages.size() - 1).faceIds.size() ==
    rhombic30.faces.size(), "rhombic triaconta assembly guide covers every placement");
  boolean reciprocalCodes = true;
  boolean reciprocalPortals = true;
  boolean reciprocalMiters = true;
  for (GeodesicEdge edge : dome.edges) if (!edge.boundary()) {
    GeodesicFace faceA = dome.faces.get(edge.faceA);
    GeodesicFace faceB = dome.faces.get(edge.faceB);
    int indexA = geodesicNeighborEdgeIndex(faceA, edge.faceB);
    int indexB = geodesicNeighborEdgeIndex(faceB, edge.faceA);
    GeodesicFabricationFace fabricationA = geodesicFabricationFace(dome, faceA, framed);
    GeodesicFabricationFace fabricationB = geodesicFabricationFace(dome, faceB, framed);
    reciprocalCodes &= indexA >= 0 && indexB >= 0;
    if (indexA < 0 || indexB < 0) continue;
    GeodesicJointEdgeProfile jointA = fabricationA.joints.get(indexA);
    GeodesicJointEdgeProfile jointB = fabricationB.joints.get(indexB);
    reciprocalCodes &= jointA.mateCode.length() > 0 && jointA.mateCode.equals(jointB.mateCode);
    reciprocalPortals &= jointA.portalCenters.size() == jointB.portalCenters.size();
    reciprocalMiters &= abs(jointA.recommendedHalfMiterDeg -
      jointB.recommendedHalfMiterDeg) < 0.0001f;
    int portalCount = min(jointA.portalCenters.size(), jointB.portalCenters.size());
    for (int p = 0; p < portalCount; p++)
      reciprocalPortals &= abs(jointA.portalCenters.get(p) - jointB.portalCenters.get(p)) < 0.00001f;
  }
  report.check(reciprocalCodes, "reciprocal shared edges carry identical mate codes");
  report.check(reciprocalPortals, "reciprocal shared edges carry identical portal schedules");
  report.check(reciprocalMiters,
    "reciprocal shared edges carry identical half-dihedral miter profiles");
  boolean codedCatalog = true;
  boolean subtleBreak = true;
  for (GeodesicPartType type : guideCatalog.types) {
    codedCatalog &= type.edgeCodes.size() >= 3;
    for (String code : type.edgeCodes) codedCatalog &= code != null && code.length() > 0;
    subtleBreak &= type.fabrication != null && type.fabrication.edgeBreakMM > 0 &&
      type.fabrication.edgeBreakMM <= 0.2601f;
  }
  report.check(codedCatalog, "reusable panel catalog records ordered mate codes");
  report.check(subtleBreak, "resolved edge break remains positive and no greater than 0.26 mm");
  GeodesicFabricationSettings scaledLegacy = framed.copy();
  scaledLegacy.assemblyMode = GeodesicAssemblyMode.LEGACY_PORTAL;
  scaledLegacy.fabricationScale = 3.25f;
  scaledLegacy.fabricationScaleAutoRaised = true;
  scaledLegacy.kitDimensionsResolved = true;
  GeodesicPanelCatalog scaledLegacyCatalog = buildGeodesicPanelCatalog(dome,
    scaledLegacy, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  boolean scaledLegacyCodes = scaledLegacyCatalog.types.size() > 0;
  for (GeodesicPartType type : scaledLegacyCatalog.types) {
    scaledLegacyCodes &= type.edgeCodes.size() >= 3;
    for (String code : type.edgeCodes)
      scaledLegacyCodes &= code != null && code.length() > 0 &&
        !code.equals("?");
  }
  report.check(scaledLegacyCodes,
    "auto-scaled legacy kits retain resolved logical mate codes");
  GeodesicModel fallbackModel = buildGeodesicModel(
    GeodesicSeedFamily.TETRAHEDRAL, GeodesicExtentMode.DOME, 2, 72, 0);
  GeodesicFabricationSettings fallbackSettings =
    geodesicResolveKitFabricationSettings(fallbackModel, framed);
  GeodesicPanelCatalog fallbackCatalog = buildGeodesicPanelCatalog(fallbackModel,
    fallbackSettings, GeodesicGrowthMode.SHELL_OVERWRAP, 1.4f);
  boolean fallbackCatalogClean = fallbackCatalog.types.size() > 0;
  boolean fallbackCodesRetained = true;
  for (GeodesicPartType type : fallbackCatalog.types) {
    fallbackCatalogClean &= geodesicAuditClean(type.audit);
    fallbackCodesRetained &= type.edgeCodes.size() >= 3;
    for (String code : type.edgeCodes)
      fallbackCodesRetained &= code != null && code.length() > 0;
  }
  report.check(fallbackCatalogClean &&
    fallbackCatalog.physicalEdgeCodeFallbackCount() > 0 &&
    fallbackCodesRetained,
    "part-local mate-code fallback preserves a clean kit and logical code map");
  GeodesicModel tetraF4 = buildGeodesicModel(GeodesicSeedFamily.TETRAHEDRAL,
    GeodesicExtentMode.DOME, 4, 72, 0.20f);
  GeodesicFabricationSettings tetraF4Fabrication = new GeodesicFabricationSettings();
  tetraF4Fabrication.style = GeodesicPanelStyle.FRAME_SKIN;
  tetraF4Fabrication.frameDepthMM = 6.0f;
  tetraF4Fabrication.frameWidthMM = 7.0f;
  tetraF4Fabrication.skinThicknessMM = 2.8f;
  GeodesicPart tetraF4Part = buildGeodesicFabricatedPart(tetraF4,
    tetraF4.faces.get(0), tetraF4Fabrication,
    GeodesicGrowthMode.CENTER_TO_EDGE, 1.4f);
  report.check(tetraF4Part.audit[0] == 0 && tetraF4Part.audit[1] == 0 &&
    tetraF4Part.audit[2] == 0,
    "tetra f4 framed panel regression audit " + tetraF4Part.audit[0] + "/" +
      tetraF4Part.audit[1] + "/" + tetraF4Part.audit[2] +
      " degenerate " + geodesicDegenerateTriangleSummary(tetraF4Part.mesh, 12));
  GeodesicModel kicasModel = buildGeodesicModel(
    GeodesicSeedFamily.TETRAHEDRAL, GeodesicExtentMode.DOME, 2, 72, 0.10f);
  GeodesicKicasPlan kicasPlan = buildGeodesicKicasPlan(kicasModel);
  report.check(kicasPlan.valid &&
    kicasPlan.steps.size() == kicasModel.faces.size() &&
    kicasPlan.lockingEdgePairs == kicasModel.faces.size() - 1,
    "KICAS deterministic ordered spanning-tree plan");
  GeodesicFabricationSettings kicasSettings = framed.copy();
  kicasSettings.assemblyMode = GeodesicAssemblyMode.KICAS;
  kicasSettings.kicasPlan = kicasPlan;
  kicasSettings = geodesicResolveKitFabricationSettings(kicasModel,
    kicasSettings);
  boolean kicasPortalSchedule = true;
  boolean kicasPartsClean = true;
  boolean kicasLabels = true;
  boolean kicasLockRoles = false;
  String kicasFirstAuditFailure = "none";
  for (GeodesicKicasStep step : kicasPlan.steps) {
    GeodesicPart kicasPart = buildGeodesicFabricatedPart(kicasModel,
      kicasModel.faces.get(step.faceId), kicasSettings,
      GeodesicGrowthMode.SHELL_OVERWRAP, 0);
    boolean kicasPartClean = geodesicAuditClean(kicasPart.audit);
    if (!kicasPartClean && kicasFirstAuditFailure.equals("none"))
      kicasFirstAuditFailure = step.placementLabel + " face " + step.faceId +
        " audit " + kicasPart.audit[0] + "/" + kicasPart.audit[1] + "/" +
        kicasPart.audit[2] + " role " +
        join(geodesicKicasRoleLabels(kicasPart.fabricationFace), ",") +
        " boundary " +
        geodesicBoundaryEdgeReport(kicasPart.mesh, 24) + " degenerate " +
        geodesicDegenerateTriangleSummary(kicasPart.mesh, 8);
    kicasPartsClean &= kicasPartClean;
    kicasLabels &= kicasPart.fabricationFace.placementLabel.equals(
      step.placementLabel);
    for (GeodesicJointEdgeProfile joint :
        kicasPart.fabricationFace.joints) {
      kicasPortalSchedule &= joint.portalCenters.size() == 1 &&
        abs(joint.portalCenters.get(0) - 0.5f) < 0.00001f;
      kicasLockRoles |= geodesicKicasRole(joint).locking();
    }
  }
  report.check(kicasPortalSchedule,
    "KICAS retains exactly one centered reinforcement portal per edge");
  report.check(kicasPartsClean,
    "KICAS ordered placement parts pass watertight manifold audit " +
    kicasFirstAuditFailure);
  report.check(kicasLabels && kicasLockRoles,
    "KICAS parts carry P### placement labels and reciprocal lock roles");
  GeodesicPart kicasInnerPart = buildGeodesicFabricatedPart(kicasModel,
    kicasModel.faces.get(kicasPlan.steps.get(0).faceId), kicasSettings,
    GeodesicGrowthMode.CENTER_TO_EDGE, 1.2f);
  JSONObject kicasInnerJSON = kicasInnerPart.fabrication.toJSON();
  float kicasInnerMaximumZ = geodesicMeshMaximumZ(kicasInnerPart.mesh);
  report.check(geodesicAuditClean(kicasInnerPart.audit) &&
    kicasInnerJSON.getString("placement_label_treatment").equals(
      "RAISED_INTERIOR_RAIL") &&
    abs(kicasInnerJSON.getFloat("placement_label_scale_target") -
      GEODESIC_KICAS_PLACEMENT_LABEL_SCALE) < 0.0001f &&
    kicasInnerMaximumZ > kicasInnerPart.fabrication.frameDepthMM +
      kicasInnerPart.fabrication.edgeCodeReliefMM * 0.50f,
    "inner-reinforcement KICAS places its enlarged P### mark on the upward " +
      "interior rail audit " + kicasInnerPart.audit[0] + "/" +
      kicasInnerPart.audit[1] + "/" + kicasInnerPart.audit[2] +
      " maxZ " + nf(kicasInnerMaximumZ, 1, 3));
  GeodesicFabricationSettings kicasCrownSettings = kicasSettings.copy();
  kicasCrownSettings.reliefSide = GeodesicReliefSide.EXTERIOR_CROWN;
  GeodesicPart kicasCrownPart = buildGeodesicFabricatedPart(kicasModel,
    kicasModel.faces.get(kicasPlan.steps.get(0).faceId), kicasCrownSettings,
    GeodesicGrowthMode.CENTER_TO_EDGE, 1.2f);
  JSONObject kicasCrownJSON = kicasCrownPart.fabrication.toJSON();
  report.check(geodesicAuditClean(kicasCrownPart.audit) &&
    kicasCrownJSON.getString("placement_label_treatment").equals(
      "RAISED_INTERIOR_MEMBRANE"),
    "exterior-crown KICAS preserves its inward membrane P### treatment audit " +
      kicasCrownPart.audit[0] + "/" + kicasCrownPart.audit[1] + "/" +
      kicasCrownPart.audit[2] + " boundary " +
      geodesicBoundaryEdgeReport(kicasCrownPart.mesh, 16) + " degenerate " +
      geodesicDegenerateTriangleSummary(kicasCrownPart.mesh, 8));
  GeodesicFabricationSettings kicasOpenRequested = framed.copy();
  kicasOpenRequested.style = GeodesicPanelStyle.OPEN_FRAME;
  kicasOpenRequested.assemblyMode = GeodesicAssemblyMode.KICAS;
  kicasOpenRequested.kicasPlan = kicasPlan;
  GeodesicFabricationSettings kicasOpenSettings =
    geodesicResolveKitFabricationSettings(kicasModel, kicasOpenRequested);
  GeodesicPart kicasOpenPart = buildGeodesicFabricatedPart(kicasModel,
    kicasModel.faces.get(kicasPlan.steps.get(0).faceId), kicasOpenSettings,
    GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  JSONObject kicasOpenJSON = kicasOpenPart.fabrication.toJSON();
  float kicasOpenCenterPeak = geodesicPanelCenterPeakZ(kicasOpenPart);
  float kicasOpenMaximumZ = geodesicMeshMaximumZ(kicasOpenPart.mesh);
  report.check(kicasOpenSettings.style == GeodesicPanelStyle.OPEN_FRAME &&
    kicasOpenPart.fabrication.style == GeodesicPanelStyle.OPEN_FRAME &&
    kicasOpenPart.fabrication.skinThicknessMM == 0 &&
    kicasOpenCenterPeak < -Float.MAX_VALUE * 0.5f,
    "KICAS preserves the selected open-frame window without a hidden membrane");
  report.check(geodesicAuditClean(kicasOpenPart.audit) &&
    kicasOpenPart.fabricationFace.portalCount() == 3 &&
    kicasOpenPart.fabricationFace.placementLabel.startsWith("P") &&
    kicasOpenMaximumZ > kicasOpenPart.fabrication.frameDepthMM +
      kicasOpenPart.fabrication.edgeCodeReliefMM * 0.5f &&
    kicasOpenJSON.getString("placement_label_treatment").equals(
      "RAISED_INTERIOR_RAIL") &&
    kicasOpenJSON.getString("placement_label_glyph_style").equals(
      "RAISED_ROUNDED_STROKE") &&
    abs(kicasOpenJSON.getFloat("placement_label_scale_target") -
      GEODESIC_KICAS_PLACEMENT_LABEL_SCALE) < 0.0001f,
    "open-frame KICAS part keeps portals and a raised inward-rail P### mark " +
      "audit " + kicasOpenPart.audit[0] + "/" + kicasOpenPart.audit[1] +
      "/" + kicasOpenPart.audit[2] + " portals " +
      kicasOpenPart.fabricationFace.portalCount() + " maxZ " +
      nf(kicasOpenMaximumZ, 1, 3) + " depth " +
      nf(kicasOpenPart.fabrication.frameDepthMM, 1, 3) + " label " +
      kicasOpenPart.fabricationFace.placementLabel + " boundary " +
      geodesicBoundaryEdgeReport(kicasOpenPart.mesh, 12) + " degenerate " +
      geodesicDegenerateTriangleSummary(kicasOpenPart.mesh, 8));
  GeodesicPanelCatalog kicasCatalog = buildGeodesicPanelCatalog(kicasModel,
    kicasSettings, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
  GeodesicGuideData kicasGuide = buildGeodesicGuideData(kicasModel,
    kicasCatalog, "TEST");
  report.check(kicasGuide.validation.valid() &&
    kicasGuide.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS &&
    kicasGuide.validation.physicalJointStatus.startsWith("KICAS_"),
    "KICAS third-guide data and joint contract validate");
  return report;
}
