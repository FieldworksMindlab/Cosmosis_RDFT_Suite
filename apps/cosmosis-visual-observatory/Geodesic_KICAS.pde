/*
  KICAS: Kinematic Integral Capture Assembly System.

  This is an additive Geodesic Salon fabrication policy. The legacy reusable
  portal kit remains unchanged. KICAS assigns a deterministic construction
  order, uses reciprocal slide-capture edge stations on the spanning tree, and
  retains one enlarged center portal on every edge for optional tie reinforcement.
*/

enum GeodesicKicasEdgeRole {
  OFF,
  RIM,
  ALIGN,
  FEMALE,
  MALE,
  KEY_FEMALE,
  KEY_MALE;

  String label() {
    if (this == RIM) return "RIM";
    if (this == ALIGN) return "ALIGN";
    if (this == FEMALE) return "FEMALE";
    if (this == MALE) return "MALE";
    if (this == KEY_FEMALE) return "KEY FEMALE";
    if (this == KEY_MALE) return "KEY MALE";
    return "OFF";
  }

  boolean locking() {
    return this == FEMALE || this == MALE ||
      this == KEY_FEMALE || this == KEY_MALE;
  }

  boolean male() {
    return this == MALE || this == KEY_MALE;
  }
}

class GeodesicKicasStep {
  int order;
  int faceId;
  int parentFaceId = -1;
  int parentEdgeIndex = -1;
  String placementLabel = "";
  String reusableTypeId = "";
  PVector insertionDirection = new PVector(0, 0, 1);

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("order", order);
    json.setString("placement_id", placementLabel);
    json.setInt("face_id", faceId);
    json.setInt("parent_face_id", parentFaceId);
    json.setInt("parent_edge_index", parentEdgeIndex);
    json.setString("reusable_geometry_type", reusableTypeId);
    JSONArray direction = new JSONArray();
    direction.setFloat(0, insertionDirection.x);
    direction.setFloat(1, insertionDirection.y);
    direction.setFloat(2, insertionDirection.z);
    json.setJSONArray("insertion_direction_model", direction);
    json.setString("operation", order == 1 ? "SEED" :
      (parentFaceId < 0 ? "PLACE" : "SLIDE_LOCK_THEN_OPTIONAL_TIE"));
    return json;
  }
}

class GeodesicKicasPlan {
  int seedFaceId = -1;
  ArrayList<GeodesicKicasStep> steps = new ArrayList<GeodesicKicasStep>();
  HashMap<Integer, GeodesicKicasStep> stepByFace =
    new HashMap<Integer, GeodesicKicasStep>();
  HashMap<String, GeodesicKicasEdgeRole> roleByFaceEdge =
    new HashMap<String, GeodesicKicasEdgeRole>();
  boolean valid = false;
  String validation = "NOT BUILT";
  int lockingEdgePairs = 0;
  int alignmentEdgePairs = 0;

  String edgeKey(int faceId, int edgeIndex) {
    return faceId + ":" + edgeIndex;
  }

  String labelForFace(int faceId) {
    GeodesicKicasStep step = stepByFace.get(faceId);
    return step == null ? "" : step.placementLabel;
  }

  int orderForFace(int faceId) {
    GeodesicKicasStep step = stepByFace.get(faceId);
    return step == null ? -1 : step.order;
  }

  GeodesicKicasEdgeRole roleForEdge(int faceId, int edgeIndex) {
    GeodesicKicasEdgeRole role = roleByFaceEdge.get(edgeKey(faceId, edgeIndex));
    return role == null ? GeodesicKicasEdgeRole.OFF : role;
  }

  void setRole(int faceId, int edgeIndex, GeodesicKicasEdgeRole role) {
    roleByFaceEdge.put(edgeKey(faceId, edgeIndex), role);
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.geodesic_salon.kicas_plan.v1");
    json.setBoolean("valid", valid);
    json.setString("validation", validation);
    json.setInt("seed_face_id", seedFaceId);
    json.setInt("placement_count", steps.size());
    json.setInt("locking_edge_pairs", lockingEdgePairs);
    json.setInt("alignment_edge_pairs", alignmentEdgePairs);
    json.setString("closure_policy",
      "spanning_tree_slide_capture_with_alignment_edges_and_center_tie_portals");
    json.setString("label_policy",
      "ordered_per_placement_P###_three_x_target_raised_interior_rail_or_membrane");
    json.setString("reinforcement_policy",
      "one_enlarged_center_portal_per_panel_edge");
    JSONArray values = new JSONArray();
    for (int i = 0; i < steps.size(); i++) values.setJSONObject(i,
      steps.get(i).toJSON());
    json.setJSONArray("ordered_steps", values);
    JSONArray roles = new JSONArray();
    int roleIndex = 0;
    for (GeodesicKicasStep step : steps) {
      for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
        JSONObject edge = new JSONObject();
        edge.setInt("face_id", step.faceId);
        edge.setInt("edge_index", edgeIndex);
        edge.setString("role", roleForEdge(step.faceId, edgeIndex).label());
        roles.setJSONObject(roleIndex++, edge);
      }
    }
    json.setJSONArray("face_edge_roles", roles);
    return json;
  }
}

GeodesicKicasPlan buildGeodesicKicasPlan(GeodesicModel model) {
  GeodesicKicasPlan plan = new GeodesicKicasPlan();
  if (model == null || !model.valid || model.faces.size() == 0) {
    plan.validation = "DOMAIN INVALID";
    return plan;
  }

  int seedFace = 0;
  float bestZ = -Float.MAX_VALUE;
  for (GeodesicFace face : model.faces) {
    if (face.centroid.z > bestZ + 0.0001f ||
        (abs(face.centroid.z - bestZ) <= 0.0001f && face.id < seedFace)) {
      seedFace = face.id;
      bestZ = face.centroid.z;
    }
  }
  plan.seedFaceId = seedFace;
  boolean[] seen = new boolean[model.faces.size()];
  int[] parent = new int[model.faces.size()];
  java.util.Arrays.fill(parent, -1);
  java.util.ArrayDeque<Integer> queue = new java.util.ArrayDeque<Integer>();
  queue.add(seedFace);
  seen[seedFace] = true;
  while (!queue.isEmpty()) {
    int faceId = queue.removeFirst();
    GeodesicKicasStep step = new GeodesicKicasStep();
    step.order = plan.steps.size() + 1;
    step.faceId = faceId;
    step.parentFaceId = parent[faceId];
    step.placementLabel = "P" + nf(step.order, 3);
    if (step.parentFaceId >= 0) {
      GeodesicFace parentFace = model.faces.get(step.parentFaceId);
      for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++)
        if (model.faces.get(faceId).neighbors[edgeIndex] == step.parentFaceId)
          step.parentEdgeIndex = edgeIndex;
      step.insertionDirection = PVector.sub(model.faces.get(faceId).centroid,
        parentFace.centroid);
      if (step.insertionDirection.magSq() < 0.000001f)
        step.insertionDirection.set(model.faces.get(faceId).normal);
      step.insertionDirection.normalize();
    } else step.insertionDirection.set(model.faces.get(faceId).normal);
    plan.steps.add(step);
    plan.stepByFace.put(faceId, step);

    ArrayList<Integer> neighbors = new ArrayList<Integer>();
    for (int neighbor : model.faces.get(faceId).neighbors)
      if (neighbor >= 0) neighbors.add(neighbor);
    java.util.Collections.sort(neighbors);
    for (int neighbor : neighbors) if (!seen[neighbor]) {
      seen[neighbor] = true;
      parent[neighbor] = faceId;
      queue.addLast(neighbor);
    }
  }

  if (plan.steps.size() != model.faces.size()) {
    plan.validation = "FACE GRAPH DISCONNECTED " + plan.steps.size() +
      "/" + model.faces.size();
    return plan;
  }

  for (GeodesicFace face : model.faces) {
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      int neighbor = face.neighbors[edgeIndex];
      if (neighbor < 0) {
        plan.setRole(face.id, edgeIndex, GeodesicKicasEdgeRole.RIM);
        continue;
      }
      boolean childToParent = parent[face.id] == neighbor;
      boolean parentToChild = parent[neighbor] == face.id;
      boolean keyPair = childToParent &&
        plan.orderForFace(face.id) == model.faces.size();
      if (childToParent)
        plan.setRole(face.id, edgeIndex, keyPair ?
          GeodesicKicasEdgeRole.KEY_MALE : GeodesicKicasEdgeRole.MALE);
      else if (parentToChild) {
        boolean keyFemale = plan.orderForFace(neighbor) == model.faces.size();
        plan.setRole(face.id, edgeIndex, keyFemale ?
          GeodesicKicasEdgeRole.KEY_FEMALE : GeodesicKicasEdgeRole.FEMALE);
      } else plan.setRole(face.id, edgeIndex, GeodesicKicasEdgeRole.ALIGN);
    }
  }

  String error = geodesicValidateKicasPlan(model, plan);
  plan.valid = error.length() == 0;
  plan.validation = plan.valid ? "VALID" : error;
  return plan;
}

String geodesicValidateKicasPlan(GeodesicModel model, GeodesicKicasPlan plan) {
  if (model == null || plan == null) return "PLAN MISSING";
  if (plan.steps.size() != model.faces.size()) return "PLACEMENT COUNT MISMATCH";
  HashSet<String> labels = new HashSet<String>();
  int lockingDirected = 0;
  int alignmentDirected = 0;
  for (GeodesicKicasStep step : plan.steps) {
    if (step.placementLabel.length() == 0 || labels.contains(step.placementLabel))
      return "PLACEMENT LABEL INVALID face " + step.faceId;
    labels.add(step.placementLabel);
    GeodesicFace face = model.faces.get(step.faceId);
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      int neighbor = face.neighbors[edgeIndex];
      GeodesicKicasEdgeRole role = plan.roleForEdge(face.id, edgeIndex);
      if (neighbor < 0) {
        if (role != GeodesicKicasEdgeRole.RIM)
          return "RIM ROLE MISMATCH face " + face.id + " edge " + edgeIndex;
        continue;
      }
      int reverse = -1;
      GeodesicFace neighborFace = model.faces.get(neighbor);
      for (int candidate = 0; candidate < 3; candidate++)
        if (neighborFace.neighbors[candidate] == face.id) reverse = candidate;
      if (reverse < 0) return "RECIPROCAL EDGE MISSING";
      GeodesicKicasEdgeRole mate = plan.roleForEdge(neighbor, reverse);
      boolean reciprocalLock =
        (role == GeodesicKicasEdgeRole.MALE && mate == GeodesicKicasEdgeRole.FEMALE) ||
        (role == GeodesicKicasEdgeRole.FEMALE && mate == GeodesicKicasEdgeRole.MALE) ||
        (role == GeodesicKicasEdgeRole.KEY_MALE && mate == GeodesicKicasEdgeRole.KEY_FEMALE) ||
        (role == GeodesicKicasEdgeRole.KEY_FEMALE && mate == GeodesicKicasEdgeRole.KEY_MALE);
      if (role.locking() && !reciprocalLock)
        return "LOCK ROLE MISMATCH face " + face.id + " edge " + edgeIndex;
      if (role == GeodesicKicasEdgeRole.ALIGN &&
          mate != GeodesicKicasEdgeRole.ALIGN)
        return "ALIGN ROLE MISMATCH face " + face.id + " edge " + edgeIndex;
      if (role.locking()) lockingDirected++;
      if (role == GeodesicKicasEdgeRole.ALIGN) alignmentDirected++;
    }
  }
  plan.lockingEdgePairs = lockingDirected / 2;
  plan.alignmentEdgePairs = alignmentDirected / 2;
  if (plan.lockingEdgePairs != max(0, model.faces.size() - 1))
    return "LOCK TREE COUNT " + plan.lockingEdgePairs + "/" +
      max(0, model.faces.size() - 1);
  return "";
}

void geodesicConfigureKicasJoint(GeodesicFabricationFace face,
  GeodesicJointEdgeProfile profile, GeodesicFabricationSettings settings) {
  if (face == null || profile == null || settings == null ||
      settings.assemblyMode != GeodesicAssemblyMode.KICAS ||
      settings.kicasPlan == null) return;
  GeodesicKicasEdgeRole role = settings.kicasPlan.roleForEdge(
    face.faceId, profile.edgeIndex);
  profile.kicasRole = role.label();
  if (face.vertexIds == null ||
      face.vertexIds.size() != face.vertexCount()) {
    profile.kicasStation = profile.edgeIndex % 2 == 0 ? 0.74f : 0.26f;
    profile.kicasLengthMM = min(settings.kicasLockLengthMM,
      profile.edgeLengthMM * 0.20f);
    profile.kicasDepthMM = min(settings.kicasLockDepthMM,
      settings.frameWidthMM * 0.26f);
    return;
  }
  int startVertex = face.vertexIds.get(profile.edgeIndex);
  int endVertex = face.vertexIds.get(
    (profile.edgeIndex + 1) % face.vertexIds.size());
  profile.kicasStation = startVertex < endVertex ? 0.74f : 0.26f;
  profile.kicasLengthMM = min(settings.kicasLockLengthMM,
    profile.edgeLengthMM * 0.20f);
  profile.kicasDepthMM = min(settings.kicasLockDepthMM,
    settings.frameWidthMM * 0.26f);
}

GeodesicKicasEdgeRole geodesicKicasRole(GeodesicJointEdgeProfile joint) {
  if (joint == null || joint.kicasRole == null) return GeodesicKicasEdgeRole.OFF;
  String role = joint.kicasRole;
  if (role.equals("RIM")) return GeodesicKicasEdgeRole.RIM;
  if (role.equals("ALIGN")) return GeodesicKicasEdgeRole.ALIGN;
  if (role.equals("FEMALE")) return GeodesicKicasEdgeRole.FEMALE;
  if (role.equals("MALE")) return GeodesicKicasEdgeRole.MALE;
  if (role.equals("KEY FEMALE")) return GeodesicKicasEdgeRole.KEY_FEMALE;
  if (role.equals("KEY MALE")) return GeodesicKicasEdgeRole.KEY_MALE;
  return GeodesicKicasEdgeRole.OFF;
}

String[] geodesicKicasRoleLabels(GeodesicFabricationFace face) {
  if (face == null) return new String[0];
  String[] labels = new String[face.joints.size()];
  for (int i = 0; i < labels.length; i++)
    labels[i] = geodesicKicasRole(face.joints.get(i)).label();
  return labels;
}

ArrayList<Float> geodesicKicasEdgeBreaks(GeodesicJointEdgeProfile joint) {
  ArrayList<Float> result = new ArrayList<Float>();
  GeodesicKicasEdgeRole role = geodesicKicasRole(joint);
  if (!role.locking() || joint.edgeLengthMM < 0.001f) return result;
  float half = min(0.10f, joint.kicasLengthMM /
    max(0.001f, joint.edgeLengthMM) * 0.5f);
  float start = constrain(joint.kicasStation - half, 0.05f, 0.95f);
  float end = constrain(joint.kicasStation + half, 0.05f, 0.95f);
  float ramp = (end - start) * 0.24f;
  result.add(start);
  result.add(start + ramp);
  result.add(end - ramp);
  result.add(end);
  return result;
}

float geodesicKicasEnvelope(GeodesicJointEdgeProfile joint, float t) {
  ArrayList<Float> breaks = geodesicKicasEdgeBreaks(joint);
  if (breaks.size() != 4 || t <= breaks.get(0) || t >= breaks.get(3)) return 0;
  if (t < breaks.get(1))
    return constrain((t - breaks.get(0)) /
      max(0.0001f, breaks.get(1) - breaks.get(0)), 0, 1);
  if (t > breaks.get(2))
    return constrain((breaks.get(3) - t) /
      max(0.0001f, breaks.get(3) - breaks.get(2)), 0, 1);
  return 1;
}

PVector geodesicKicasInwardNormal(GeodesicFabricationFace face,
  int edgeIndex) {
  PVector a = face.boundary.get(edgeIndex);
  PVector b = face.boundary.get((edgeIndex + 1) % face.vertexCount());
  PVector tangent = PVector.sub(b, a);
  if (tangent.magSq() < 0.000001f) return new PVector();
  tangent.normalize();
  PVector inward = new PVector(-tangent.y, tangent.x, 0);
  PVector midpoint = PVector.add(a, b).mult(0.5f);
  PVector toCenter = PVector.sub(geodesicPolygonCentroid(face.boundary), midpoint);
  if (inward.dot(toCenter) < 0) inward.mult(-1);
  return inward;
}

PVector geodesicKicasOuterPoint(GeodesicFabricationFace face,
  GeodesicMiterOuterProfile profile, GeodesicJointEdgeProfile joint,
  GeodesicFabricationSettings settings, int edgeIndex, float t, float z) {
  PVector result = geodesicMiterOuterPoint(profile, edgeIndex, t, z);
  GeodesicKicasEdgeRole role = geodesicKicasRole(joint);
  float envelope = geodesicKicasEnvelope(joint, t);
  if (!role.locking() || envelope <= 0.0001f) return result;
  float depthFraction = constrain(z / max(0.001f, profile.depth), 0, 1);
  float dovetail = 0.72f + 0.28f * sin(PI * depthFraction);
  float magnitude = joint.kicasDepthMM * dovetail;
  if (!role.male()) magnitude += max(0, settings.kicasLockClearanceMM);
  PVector inward = geodesicKicasInwardNormal(face, edgeIndex);
  inward.mult((role.male() ? -1 : 1) * magnitude * envelope);
  result.add(inward);
  result.z = z;
  return result;
}

ArrayList<Float> geodesicKicasVerticalLevels(float bottom, float top,
  GeodesicMiterOuterProfile profile) {
  ArrayList<Float> levels = geodesicMiterLevels(bottom, top, profile);
  float[] captures = {
    profile.depth * 0.25f, profile.depth * 0.50f, profile.depth * 0.75f
  };
  for (float value : captures)
    if (value > bottom + 0.0001f && value < top - 0.0001f)
      geodesicAddUniqueZLevel(levels, value);
  java.util.Collections.sort(levels);
  return levels;
}

void geodesicAddUniqueZLevel(ArrayList<Float> values, float value) {
  for (float existing : values) if (abs(existing - value) < 0.0001f) return;
  values.add(value);
}

void geodesicAddKicasRailFaceInterval(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, PVector innerA, PVector innerB,
  float start, float end, float z, boolean top) {
  if (end - start < 0.0001f) return;
  PVector oa = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, start, z);
  PVector ob = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, end, z);
  PVector ia = geodesicEdgePoint(innerA, innerB, start, z);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, z);
  if (top) mesh.addQuad(oa, ob, ib, ia);
  else mesh.addQuad(oa, ia, ib, ob);
}

void geodesicAddKicasCodedTopRail(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, PVector innerA, PVector innerB,
  ArrayList<Float> tBreaks, String mark, float depth, float relief) {
  if (tBreaks == null || tBreaks.size() < 2) return;
  PVector outerStart = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, 0, depth);
  PVector outerEnd = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, 1, depth);
  float edgeLength = max(0.001f,
    (PVector.dist(outerStart, outerEnd) + PVector.dist(innerA, innerB)) * 0.5f);
  PVector outerMid = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, 0.5f, depth);
  PVector innerMid = geodesicEdgePoint(innerA, innerB, 0.5f, depth);
  float railWidth = max(0.001f, PVector.dist(outerMid, innerMid));
  int columns = mark == null || mark.length() == 0 ? 0 :
    mark.length() * 4 - 1;
  float cellMM = geodesicRailLabelCellMM(edgeLength, railWidth, columns,
    GEODESIC_KICAS_PLACEMENT_CELL_CAP_MM,
    GEODESIC_KICAS_PLACEMENT_FIT_FRACTION,
    GEODESIC_KICAS_PLACEMENT_RAIL_FRACTION);
  float cellT = cellMM / edgeLength;
  float cellU = cellMM / railWidth;
  float startT = 0.5f - columns * cellT * 0.5f;
  float startU = 0.5f - 5.0f * cellU * 0.5f;
  ArrayList<Float> uBreaks = new ArrayList<Float>();
  geodesicAddUniqueBreak(uBreaks, 0);
  geodesicAddUniqueBreak(uBreaks, 1);
  for (int sample = 1; sample < 24; sample++)
    geodesicAddUniqueBreak(uBreaks, sample / 24.0f);
  java.util.Collections.sort(uBreaks);

  for (int ti = 0; ti < tBreaks.size() - 1; ti++) {
    float t0 = tBreaks.get(ti);
    float t1 = tBreaks.get(ti + 1);
    if (t1 - t0 < 0.00001f) continue;
    for (int ui = 0; ui < uBreaks.size() - 1; ui++) {
      float u0 = uBreaks.get(ui);
      float u1 = uBreaks.get(ui + 1);
      if (u1 - u0 < 0.00001f) continue;
      PVector p00 = geodesicKicasCodedRailPoint(face, profile, joint, settings,
          edgeIndex, innerA, innerB, t0, u0, depth,
          geodesicEdgeCodeHeight(mark, geodesicKicasPlacementReadT(t0), u0,
            startT, startU,
            cellT, cellU, relief));
      PVector p10 = geodesicKicasCodedRailPoint(face, profile, joint, settings,
          edgeIndex, innerA, innerB, t1, u0, depth,
          geodesicEdgeCodeHeight(mark, geodesicKicasPlacementReadT(t1), u0,
            startT, startU,
            cellT, cellU, relief));
      PVector p11 = geodesicKicasCodedRailPoint(face, profile, joint, settings,
          edgeIndex, innerA, innerB, t1, u1, depth,
          geodesicEdgeCodeHeight(mark, geodesicKicasPlacementReadT(t1), u1,
            startT, startU,
            cellT, cellU, relief));
      PVector p01 = geodesicKicasCodedRailPoint(face, profile, joint, settings,
          edgeIndex, innerA, innerB, t0, u1, depth,
          geodesicEdgeCodeHeight(mark, geodesicKicasPlacementReadT(t0), u1,
            startT, startU,
            cellT, cellU, relief));
      geodesicAddKicasStableQuad(mesh, p00, p10, p11, p01);
    }
  }
}

// Panel boundaries wind around the outward face. From the raised
// assembly-interior rail that makes the unadjusted glyph field read backward,
// so reverse only the sampling coordinate and leave all seam geometry intact.
float geodesicKicasPlacementReadT(float panelT) {
  return 1.0f - constrain(panelT, 0, 1);
}

void geodesicAddKicasStableQuad(SurfaceMesh mesh,
  PVector a, PVector b, PVector c, PVector d) {
  float acMinimum = min(
    PVector.sub(b, a).cross(PVector.sub(c, a)).magSq(),
    PVector.sub(c, a).cross(PVector.sub(d, a)).magSq());
  float bdMinimum = min(
    PVector.sub(b, a).cross(PVector.sub(d, a)).magSq(),
    PVector.sub(c, b).cross(PVector.sub(d, b)).magSq());
  if (bdMinimum > acMinimum) {
    mesh.addTri(a, b, d);
    mesh.addTri(b, c, d);
  } else mesh.addQuad(a, b, c, d);
}

PVector geodesicKicasCodedRailPoint(GeodesicFabricationFace face,
  GeodesicMiterOuterProfile profile, GeodesicJointEdgeProfile joint,
  GeodesicFabricationSettings settings, int edgeIndex,
  PVector innerA, PVector innerB, float t, float u, float depth,
  float labelHeight) {
  PVector outer = geodesicKicasOuterPoint(face, profile, joint, settings,
    edgeIndex, t, depth);
  PVector inner = geodesicEdgePoint(innerA, innerB, t, depth);
  float across = constrain(u, 0, 1);
  PVector result;
  if (across <= 0.000001f) result = outer.copy();
  else if (across >= 0.999999f) result = inner.copy();
  else result = PVector.lerp(outer, inner, across);
  result.z = depth + max(0, labelHeight);
  return result;
}

void geodesicAddKicasOuterWallBand(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, float start, float end, float bottom, float top) {
  if (top - bottom < 0.0001f) return;
  ArrayList<Float> levels = geodesicKicasVerticalLevels(bottom, top, profile);
  for (int i = 0; i < levels.size() - 1; i++) {
    float z0 = levels.get(i);
    float z1 = levels.get(i + 1);
    PVector a0 = geodesicKicasOuterPoint(face, profile, joint, settings,
      edgeIndex, start, z0);
    PVector b0 = geodesicKicasOuterPoint(face, profile, joint, settings,
      edgeIndex, end, z0);
    PVector a1 = geodesicKicasOuterPoint(face, profile, joint, settings,
      edgeIndex, start, z1);
    PVector b1 = geodesicKicasOuterPoint(face, profile, joint, settings,
      edgeIndex, end, z1);
    mesh.addQuad(a0, b0, b1, a1);
  }
}

void geodesicAddKicasFrameWallInterval(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, PVector innerA, PVector innerB,
  PVector innerTopA, PVector innerTopB, float start, float end,
  float innerWallBottom, float innerWallTop, float depth,
  float slotBottom, float slotTop, float edgeBreak) {
  if (end - start < 0.0001f) return;
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);
  geodesicAddKicasOuterWallBand(mesh, face, profile, joint, settings,
    edgeIndex, start, end, 0, slotBottom);
  geodesicAddKicasOuterWallBand(mesh, face, profile, joint, settings,
    edgeIndex, start, end, slotBottom, slotTop);
  geodesicAddKicasOuterWallBand(mesh, face, profile, joint, settings,
    edgeIndex, start, end, slotTop, depth);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
    min(slotBottom, innerWallTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotBottom), min(innerWallTop, slotTop), depth, edgeBreak);
  geodesicAddInnerWallBand(mesh, ia, ib, ita, itb,
    max(innerWallBottom, slotTop), innerWallTop, depth, edgeBreak);
}

void geodesicAddKicasFramePortalInterval(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, PVector innerA, PVector innerB,
  PVector innerTopA, PVector innerTopB, float start, float end,
  float innerWallBottom, float innerWallTop, float depth,
  float slotBottom, float slotTop, float edgeBreak,
  boolean closeStart, boolean closeEnd) {
  PVector ia = geodesicEdgePoint(innerA, innerB, start, 0);
  PVector ib = geodesicEdgePoint(innerA, innerB, end, 0);
  PVector ita = geodesicEdgePoint(innerTopA, innerTopB, start, 0);
  PVector itb = geodesicEdgePoint(innerTopA, innerTopB, end, 0);
  if (slotBottom > 0.0001f)
    geodesicAddKicasOuterWallBand(mesh, face, profile, joint, settings,
      edgeIndex, start, end, 0, slotBottom);
  if (slotTop < depth - 0.0001f)
    geodesicAddKicasOuterWallBand(mesh, face, profile, joint, settings,
      edgeIndex, start, end, slotTop, depth);
  if (slotBottom > innerWallBottom + 0.0001f)
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, innerWallBottom,
      slotBottom, depth, edgeBreak);
  if (slotTop < innerWallTop - 0.0001f)
    geodesicAddInnerWallBand(mesh, ia, ib, ita, itb, slotTop,
      innerWallTop, depth, edgeBreak);

  PVector outerStartBottom = geodesicKicasOuterPoint(face, profile, joint,
    settings, edgeIndex, start, slotBottom);
  PVector outerEndBottom = geodesicKicasOuterPoint(face, profile, joint,
    settings, edgeIndex, end, slotBottom);
  PVector outerStartTop = geodesicKicasOuterPoint(face, profile, joint,
    settings, edgeIndex, start, slotTop);
  PVector outerEndTop = geodesicKicasOuterPoint(face, profile, joint,
    settings, edgeIndex, end, slotTop);
  PVector innerStartBottom = geodesicInnerChamferPoint(
    ia, ita, slotBottom, depth, edgeBreak);
  PVector innerEndBottom = geodesicInnerChamferPoint(
    ib, itb, slotBottom, depth, edgeBreak);
  PVector innerStartTop = geodesicInnerChamferPoint(
    ia, ita, slotTop, depth, edgeBreak);
  PVector innerEndTop = geodesicInnerChamferPoint(
    ib, itb, slotTop, depth, edgeBreak);
  mesh.addQuad(outerStartBottom, outerEndBottom,
    innerEndBottom, innerStartBottom);
  mesh.addQuad(outerStartTop, innerStartTop,
    innerEndTop, outerEndTop);
  if (closeStart)
    geodesicAddKicasPortalEndCap(mesh, face, profile, joint, settings,
      edgeIndex, ia, ita, start, slotBottom, slotTop, depth, edgeBreak, true);
  if (closeEnd)
    geodesicAddKicasPortalEndCap(mesh, face, profile, joint, settings,
      edgeIndex, ib, itb, end, slotBottom, slotTop, depth, edgeBreak, false);
}

void geodesicAddKicasPortalEndCap(SurfaceMesh mesh,
  GeodesicFabricationFace face, GeodesicMiterOuterProfile profile,
  GeodesicJointEdgeProfile joint, GeodesicFabricationSettings settings,
  int edgeIndex, PVector innerBase, PVector innerTop, float station,
  float bottom, float top, float depth, float edgeBreak,
  boolean startCap) {
  ArrayList<Float> outerLevels = geodesicKicasVerticalLevels(
    bottom, top, profile);
  ArrayList<Float> innerLevels = geodesicChamferLevels(
    bottom, top, depth, edgeBreak, false);
  int outerIndex = 0;
  int innerIndex = 0;
  while (outerIndex < outerLevels.size() - 1 ||
      innerIndex < innerLevels.size() - 1) {
    float outerZ = outerLevels.get(outerIndex);
    float innerZ = innerLevels.get(innerIndex);
    PVector outer0 = geodesicKicasOuterPoint(face, profile, joint,
      settings, edgeIndex, station, outerZ);
    PVector inner0 = geodesicInnerChamferPoint(
      innerBase, innerTop, innerZ, depth, edgeBreak);
    float nextOuter = outerIndex < outerLevels.size() - 1 ?
      outerLevels.get(outerIndex + 1) : Float.MAX_VALUE;
    float nextInner = innerIndex < innerLevels.size() - 1 ?
      innerLevels.get(innerIndex + 1) : Float.MAX_VALUE;
    if (abs(nextOuter - nextInner) < 0.0001f) {
      PVector outer1 = geodesicKicasOuterPoint(face, profile, joint,
        settings, edgeIndex, station, nextOuter);
      PVector inner1 = geodesicInnerChamferPoint(
        innerBase, innerTop, nextInner, depth, edgeBreak);
      if (startCap) mesh.addQuad(outer0, inner0, inner1, outer1);
      else mesh.addQuad(outer0, outer1, inner1, inner0);
      outerIndex++;
      innerIndex++;
    } else if (nextOuter < nextInner) {
      PVector outer1 = geodesicKicasOuterPoint(face, profile, joint,
        settings, edgeIndex, station, nextOuter);
      if (startCap) mesh.addTri(outer0, inner0, outer1);
      else mesh.addTri(outer0, outer1, inner0);
      outerIndex++;
    } else {
      PVector inner1 = geodesicInnerChamferPoint(
        innerBase, innerTop, nextInner, depth, edgeBreak);
      if (startCap) mesh.addTri(outer0, inner0, inner1);
      else mesh.addTri(outer0, inner1, inner0);
      innerIndex++;
    }
  }
}

void drawGeodesicGuideKicasSequence(GeodesicGuideCanvas canvas,
  GeodesicGuideData data) {
  GeodesicKicasPlan plan = data.fabrication.kicasPlan;
  canvas.beginGroup("kicas-header");
  canvas.textLine("GEODESIC SALON - KICAS ORDERED ASSEMBLY", 11, 10,
    8.2f, true, LEFT);
  canvas.textLine("KINEMATIC INTEGRAL CAPTURE + CENTER TIE REINFORCEMENT",
    11, 21, 4.1f, true, LEFT);
  canvas.rect(11, 29, 410, 19, 0.3f, false);
  canvas.textLine("INSTALL PANELS IN P### ORDER. SLIDE THE PARENT LOCK HOME.",
    15, 32, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  canvas.textLine("Then pass one zip tie through each centered edge portal for final integrity.",
    15, 39, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.logo(440, 8, 136, 40);
  canvas.endGroup();

  float bodyY = 53;
  float bodyH = 318;
  guideSection(canvas, 10, bodyY, 424, bodyH,
    "1. ORDERED INSTALLATION - CUMULATIVE PLACEMENT");
  guideSection(canvas, 437, bodyY, 147, bodyH,
    "2. LOCK / TIE REFERENCE");

  canvas.beginGroup("kicas-stages");
  String[] titles = {
    "SEED", "ESTABLISH RING", "BUILD PRIMARY REGION",
    "CLOSE LOWER BAND", "FILL NETWORK", "INSTALL KEY / VERIFY"
  };
  float stageW = 138;
  float stageH = 141;
  for (int i = 0; i < 6; i++) {
    int col = i % 3;
    int row = i / 3;
    float sx = 14 + col * 139.0f;
    float sy = bodyY + 17 + row * 147.0f;
    canvas.rect(sx, sy, stageW, stageH, 0.24f, false);
    canvas.rect(sx + 3, sy + 4, 8, 8, 0.22f, true);
    canvas.textLine(str(i + 1), sx + 7, sy + 4.5f, 3.2f,
      true, CENTER);
    canvas.textLine(titles[i], sx + 14, sy + 4.5f, 3.45f,
      true, LEFT);
    guideDrawKicasStage(canvas, data, data.stages.get(i),
      sx + 3, sy + 16, stageW - 6, 91, 38, 24, 4);
    canvas.textLine(guideKicasStageRange(data, data.stages.get(i)),
      sx + 5, sy + 110, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
    guideTextBlock(canvas, guideKicasStageCaption(data,
      data.stages.get(i), i), sx + 5, sy + 118, stageW - 10,
      GEODESIC_GUIDE_BODY_MM, 5.6f, false, 4);
  }
  canvas.endGroup();

  canvas.beginGroup("kicas-reference");
  float rx = 443;
  canvas.textLine("ASSEMBLY RULE", rx, bodyY + 18, 4.3f, true, LEFT);
  guideTextBlock(canvas,
    "Each P### file is one physical placement. Its raised P### mark faces inward. Do not substitute reusable type IDs for installation order.",
    rx, bodyY + 27, 133, GEODESIC_GUIDE_BODY_MM, 5.7f, false, 7);

  canvas.textLine("SLIDE + CAPTURE", rx, bodyY + 72, 4.3f, true, LEFT);
  guideDrawKicasLockDiagram(canvas, rx, bodyY + 82, 133, 56);
  guideTextBlock(canvas,
    "Bring the new panel to its listed parent, align the off-center male/female capture, then slide along the printed insertion vector until seated.",
    rx, bodyY + 143, 133, GEODESIC_GUIDE_BODY_MM, 5.7f, false, 8);

  canvas.textLine("CENTER REINFORCEMENT", rx, bodyY + 195,
    4.3f, true, LEFT);
  guideDrawKicasPortalDiagram(canvas, rx, bodyY + 205, 133, 35);
  guideTextBlock(canvas,
    "Every triangle edge retains one enlarged portal at its geometric center. After locks are seated, pair the matching center portals and add zip ties as required.",
    rx, bodyY + 245, 133, GEODESIC_GUIDE_BODY_MM, 5.7f, false, 8);

  int lockPairs = plan == null ? 0 : plan.lockingEdgePairs;
  int alignPairs = plan == null ? 0 : plan.alignmentEdgePairs;
  canvas.textLine("PLAN AUDIT", rx, bodyY + 292, 4.3f, true, LEFT);
  canvas.textLine(data.model.faces.size() + " ordered panels / " +
    lockPairs + " lock pairs", rx, bodyY + 301,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.textLine(alignPairs + " alignment pairs / 3 center portals per panel",
    rx, bodyY + 308, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.endGroup();
  drawGeodesicGuideFooter(canvas, data, "GS-003",
    "KICAS ORDERED LOCK + TIE SEQUENCE");
}

void guideDrawKicasStage(GeodesicGuideCanvas canvas,
  GeodesicGuideData data, GeodesicGuideStage stage,
  float x, float y, float w, float h, float azimuth, float elevation,
  int maxLabels) {
  GeodesicGuideProjection projection = new GeodesicGuideProjection(
    data.model, azimuth, elevation);
  HashSet<Integer> added = new HashSet<Integer>(stage.newFaceIds);
  float labelBandH = min(23.0f, max(17.0f, h * 0.22f));
  float modelY = y + labelBandH;
  float modelH = max(18.0f, h - labelBandH);
  float modelCenterX = x + w * 0.5f;
  float modelCenterY = modelY + modelH * 0.5f;
  PVector stageFit = guideStageFit(data, stage, projection, x, modelY,
    w, modelH, added);
  int labels = 0;
  for (int faceId : stage.faceIds) {
    GeodesicFace face = data.model.faces.get(faceId);
    if (!projection.visible(face)) continue;
    PVector offset = added.contains(faceId) ?
      PVector.mult(face.normal, min(6.0f, data.model.radius * 0.08f)) :
      null;
    PVector[] tri = guideFaceScreen(data.model, face, projection,
      x, modelY, w, modelH, 2, offset);
    guideFitScreenTriangle(tri, stageFit.x, stageFit.y,
      modelCenterX, modelCenterY, stageFit.z);
    if (added.contains(faceId)) {
      guideHatchTriangle(canvas, tri, 2, 0.11f);
      canvas.polygon(tri, 0.42f, false);
      PVector original = projection.screen(face.centroid, x, modelY,
        w, modelH, 2);
      PVector moved = offset == null ? original :
        projection.screen(PVector.add(face.centroid, offset), x, modelY,
          w, modelH, 2);
      original = guideFitScreenPoint(original, stageFit.x, stageFit.y,
        modelCenterX, modelCenterY, stageFit.z);
      moved = guideFitScreenPoint(moved, stageFit.x, stageFit.y,
        modelCenterX, modelCenterY, stageFit.z);
      canvas.dashedLine(original.x, original.y, moved.x, moved.y,
        0.16f, 1.0f, 0.8f);
      if (labels < maxLabels) {
        float labelX = x + (labels + 0.5f) * w /
          max(1, maxLabels);
        float labelY = y + 1.0f;
        float leaderY = labelY + GEODESIC_GUIDE_ANNOTATION_MM + 1.4f;
        canvas.line(moved.x, moved.y, labelX, leaderY, 0.18f);
        canvas.textLine(guideKicasPlacementLabel(data, faceId),
          labelX, labelY, GEODESIC_GUIDE_ANNOTATION_MM, true, CENTER);
        labels++;
      }
    } else canvas.polygon(tri, 0.18f, false);
  }
}

String guideKicasPlacementLabel(GeodesicGuideData data, int faceId) {
  if (data == null || data.fabrication == null ||
      data.fabrication.kicasPlan == null) return "P???";
  String label = data.fabrication.kicasPlan.labelForFace(faceId);
  return label.length() == 0 ? "P???" : label;
}

String guideKicasStageRange(GeodesicGuideData data,
  GeodesicGuideStage stage) {
  if (stage == null || stage.newFaceIds.size() == 0) return "NO NEW PANELS";
  String first = guideKicasPlacementLabel(data,
    stage.newFaceIds.get(0));
  String last = guideKicasPlacementLabel(data,
    stage.newFaceIds.get(stage.newFaceIds.size() - 1));
  return first.equals(last) ? "INSTALL " + first :
    "INSTALL " + first + " - " + last;
}

String guideKicasStageCaption(GeodesicGuideData data,
  GeodesicGuideStage stage, int index) {
  if (index == 0)
    return "Place the seed panel and its first neighbors; keep all P### marks inward.";
  if (index == 5)
    return "Install the designated key panel last, seat every lock, then reinforce center portals.";
  return "For each new P###: find its parent in assembly_plan.json, align, slide to capture, and hold.";
}

void guideDrawKicasLockDiagram(GeodesicGuideCanvas canvas,
  float x, float y, float w, float h) {
  float midY = y + h * 0.53f;
  PVector[] parent = {
    new PVector(x + 4, midY + 15),
    new PVector(x + 49, midY + 15),
    new PVector(x + 27, midY - 19)
  };
  PVector[] child = {
    new PVector(x + 84, midY + 15),
    new PVector(x + 129, midY + 15),
    new PVector(x + 106, midY - 19)
  };
  canvas.polygon(parent, 0.35f, false);
  canvas.polygon(child, 0.35f, false);
  canvas.textLine("PARENT / FEMALE", x + 27, y,
    GEODESIC_GUIDE_MICRO_MM, true, CENTER);
  canvas.textLine("NEW P### / MALE", x + 106, y,
    GEODESIC_GUIDE_MICRO_MM, true, CENTER);
  canvas.line(x + 55, midY, x + 77, midY, 0.45f);
  canvas.line(x + 77, midY, x + 72, midY - 3, 0.45f);
  canvas.line(x + 77, midY, x + 72, midY + 3, 0.45f);
  canvas.rect(x + 42, midY - 4, 9, 8, 0.3f, false);
  canvas.rect(x + 82, midY - 5, 10, 10, 0.3f, true);
}

void guideDrawKicasPortalDiagram(GeodesicGuideCanvas canvas,
  float x, float y, float w, float h) {
  float edgeY = y + h * 0.55f;
  canvas.line(x + 5, edgeY, x + w - 5, edgeY, 0.65f);
  canvas.circle(x + w * 0.5f, edgeY, 5.0f, 0.45f, false);
  canvas.line(x + w * 0.5f, y + 1, x + w * 0.5f, edgeY - 6,
    0.2f);
  canvas.textLine("ONE PORTAL AT 50% EDGE STATION",
    x + w * 0.5f, y, GEODESIC_GUIDE_MICRO_MM, true, CENTER);
}
