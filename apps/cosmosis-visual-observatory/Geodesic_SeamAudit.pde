/* Pairwise fabrication audit for assembled half-dihedral panel seams. */

class GeodesicSeamAudit {
  boolean evaluated = false;
  boolean valid = true;
  String status = "NOT EVALUATED";
  int sharedEdges = 0;
  int samples = 0;
  float toleranceMM = 0.05f;
  float maximumGapMM = 0;
  float maximumTangentialGapMM = 0;
  float maximumCrossSeamGapMM = 0;
  float maximumPortalOffsetMM = 0;
  int maximumGapEdgeId = -1;
  int maximumGapFaceA = -1;
  int maximumGapFaceB = -1;
  float maximumGapDepthFraction = 0;
  float maximumGapEdgeFraction = 0;
  int failedEdgeId = -1;
  int failedFaceA = -1;
  int failedFaceB = -1;
  String failedMateCode = "";
  float failedGapMM = 0;
  float failedDepthFraction = 0;
  float failedEdgeFraction = 0;
  float failedRequestedDepthMM = -1;
  float failedResolvedDepthAMM = -1;
  float failedResolvedDepthBMM = -1;
  float failedResolvedWidthAMM = -1;
  float failedResolvedWidthBMM = -1;
  float failedNormalAngleDeg = -1;
  float failedProfileLineAngleDeg = -1;
  float failedNeighborSideA = 0;
  float failedNeighborSideB = 0;

  void recordGap(float gap, float tangentialGap, float crossSeamGap,
    GeodesicEdge edge, String mateCode, float depthFraction,
    float edgeFraction) {
    samples++;
    if (gap > maximumGapMM) {
      maximumGapMM = gap;
      maximumGapEdgeId = edge == null ? -1 : edge.id;
      maximumGapFaceA = edge == null ? -1 : edge.faceA;
      maximumGapFaceB = edge == null ? -1 : edge.faceB;
      maximumGapDepthFraction = depthFraction;
      maximumGapEdgeFraction = edgeFraction;
    }
    maximumTangentialGapMM = max(maximumTangentialGapMM, tangentialGap);
    maximumCrossSeamGapMM = max(maximumCrossSeamGapMM, crossSeamGap);
    if (crossSeamGap <= toleranceMM || failedEdgeId >= 0) return;
    valid = false;
    failedEdgeId = edge == null ? -1 : edge.id;
    failedFaceA = edge == null ? -1 : edge.faceA;
    failedFaceB = edge == null ? -1 : edge.faceB;
    failedMateCode = mateCode == null ? "" : mateCode;
    failedGapMM = crossSeamGap;
    failedDepthFraction = depthFraction;
    failedEdgeFraction = edgeFraction;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("evaluated", evaluated);
    json.setBoolean("valid", valid);
    json.setString("status", status);
    json.setInt("shared_edges", sharedEdges);
    json.setInt("profile_samples", samples);
    json.setFloat("tolerance_mm", toleranceMM);
    json.setFloat("maximum_profile_gap_mm", maximumGapMM);
    json.setFloat("maximum_tangential_gap_mm", maximumTangentialGapMM);
    json.setFloat("maximum_cross_seam_gap_mm", maximumCrossSeamGapMM);
    json.setInt("maximum_gap_edge_id", maximumGapEdgeId);
    json.setInt("maximum_gap_face_a", maximumGapFaceA);
    json.setInt("maximum_gap_face_b", maximumGapFaceB);
    json.setFloat("maximum_gap_depth_fraction", maximumGapDepthFraction);
    json.setFloat("maximum_gap_edge_fraction", maximumGapEdgeFraction);
    json.setFloat("maximum_portal_offset_mm", maximumPortalOffsetMM);
    json.setInt("failed_edge_id", failedEdgeId);
    json.setInt("failed_face_a", failedFaceA);
    json.setInt("failed_face_b", failedFaceB);
    json.setString("failed_mate_code", failedMateCode);
    json.setFloat("failed_gap_mm", failedGapMM);
    json.setFloat("failed_depth_fraction", failedDepthFraction);
    json.setFloat("failed_edge_fraction", failedEdgeFraction);
    json.setFloat("failed_requested_depth_mm", failedRequestedDepthMM);
    json.setFloat("failed_resolved_depth_a_mm", failedResolvedDepthAMM);
    json.setFloat("failed_resolved_depth_b_mm", failedResolvedDepthBMM);
    json.setFloat("failed_resolved_width_a_mm", failedResolvedWidthAMM);
    json.setFloat("failed_resolved_width_b_mm", failedResolvedWidthBMM);
    json.setFloat("failed_normal_angle_deg", failedNormalAngleDeg);
    json.setFloat("failed_profile_line_angle_deg",
      failedProfileLineAngleDeg);
    json.setFloat("failed_neighbor_side_a", failedNeighborSideA);
    json.setFloat("failed_neighbor_side_b", failedNeighborSideB);
    json.setString("failed_joint_class",
      failedNeighborSideA > 0.0001f || failedNeighborSideB > 0.0001f ?
      "CONCAVE" : "CONVEX");
    return json;
  }
}

GeodesicSeamAudit geodesicAuditAssembledSeams(GeodesicModel model,
  GeodesicFabricationSettings settings) {
  GeodesicSeamAudit audit = new GeodesicSeamAudit();
  if (model == null || settings == null) {
    audit.valid = false;
    audit.status = "MODEL OR FABRICATION MISSING";
    return audit;
  }
  if (settings.style == GeodesicPanelStyle.SOLID ||
      settings.seamProfile != GeodesicSeamProfile.HALF_DIHEDRAL_MITER) {
    audit.status = "NOT REQUIRED";
    return audit;
  }

  audit.evaluated = true;
  HashMap<Integer, GeodesicFabricationFace> faces =
    new HashMap<Integer, GeodesicFabricationFace>();
  for (GeodesicFace face : model.faces)
    faces.put(face.id, geodesicFabricationFace(model, face, settings));

  float[] edgeFractions = { 0.18f, 0.50f, 0.82f };
  float[] depthFractions = { 0.18f, 0.50f, 0.82f };
  for (GeodesicEdge edge : model.edges) {
    if (edge.faceA < 0 || edge.faceB < 0) continue;
    GeodesicFabricationFace faceA = faces.get(edge.faceA);
    GeodesicFabricationFace faceB = faces.get(edge.faceB);
    int edgeA = geodesicFabricationEdgeToward(faceA, edge.faceB);
    int edgeB = geodesicFabricationEdgeToward(faceB, edge.faceA);
    if (faceA == null || faceB == null || edgeA < 0 || edgeB < 0) {
      audit.valid = false;
      audit.failedEdgeId = edge.id;
      audit.failedFaceA = edge.faceA;
      audit.failedFaceB = edge.faceB;
      audit.status = "RECIPROCAL EDGE MISSING";
      return audit;
    }

    GeodesicMiterOuterProfile profileA = geodesicBuildMiterOuterProfile(
      faceA, geodesicCopyPolygon(faceA.boundary),
      faceA.resolvedFabrication.frameDepthMM,
      faceA.resolvedFabrication.edgeBreakMM);
    GeodesicMiterOuterProfile profileB = geodesicBuildMiterOuterProfile(
      faceB, geodesicCopyPolygon(faceB.boundary),
      faceB.resolvedFabrication.frameDepthMM,
      faceB.resolvedFabrication.edgeBreakMM);
    if (profileA == null || profileB == null) {
      audit.valid = false;
      audit.failedEdgeId = edge.id;
      audit.failedFaceA = edge.faceA;
      audit.failedFaceB = edge.faceB;
      audit.status = "MITER PROFILE MISSING";
      return audit;
    }

    audit.sharedEdges++;
    boolean reverse = geodesicFabricationEdgesRunOpposite(faceA, edgeA,
      faceB, edgeB);
    GeodesicJointEdgeProfile jointA = faceA.joints.get(edgeA);
    PVector sharedAxis = PVector.sub(
      model.vertices.get(edge.b).position,
      model.vertices.get(edge.a).position);
    if (sharedAxis.magSq() < 0.000001f) sharedAxis.set(1, 0, 0);
    else sharedAxis.normalize();
    for (float depthFraction : depthFractions) {
      float depthA = faceA.resolvedFabrication.frameDepthMM;
      float depthB = faceB.resolvedFabrication.frameDepthMM;
      float inwardA = depthA * depthFraction;
      float inwardB = depthB * depthFraction;
      float zA = geodesicAssemblyExteriorAtTop(faceA.resolvedFabrication) ?
        depthA - inwardA : inwardA;
      float zB = geodesicAssemblyExteriorAtTop(faceB.resolvedFabrication) ?
        depthB - inwardB : inwardB;

      // Adjacent polygons can trim the two ends of a shared miter by
      // different amounts. Compare the physical seam lines themselves so
      // harmless along-edge station drift cannot masquerade as an opening.
      PVector worldA0 = geodesicFabricationPointToAssembly(faceA,
        geodesicMiterOuterPoint(profileA, edgeA, 0, zA));
      PVector worldA1 = geodesicFabricationPointToAssembly(faceA,
        geodesicMiterOuterPoint(profileA, edgeA, 1, zA));
      PVector worldB0 = geodesicFabricationPointToAssembly(faceB,
        geodesicMiterOuterPoint(profileB, edgeB, 0, zB));
      PVector worldB1 = geodesicFabricationPointToAssembly(faceB,
        geodesicMiterOuterPoint(profileB, edgeB, 1, zB));
      if (PVector.dist(worldA0, worldA1) < 0.000001f ||
          PVector.dist(worldB0, worldB1) < 0.000001f) {
        audit.valid = false;
        audit.failedEdgeId = edge.id;
        audit.failedFaceA = edge.faceA;
        audit.failedFaceB = edge.faceB;
        audit.status = "MITER SEAM DEGENERATE";
        return audit;
      }

      for (float tA : edgeFractions) {
        boolean hadFailure = audit.failedEdgeId >= 0;
        float tB = reverse ? 1.0f - tA : tA;
        PVector localA = geodesicMiterOuterPoint(profileA, edgeA, tA, zA);
        PVector localB = geodesicMiterOuterPoint(profileB, edgeB, tB, zB);
        PVector worldA = geodesicFabricationPointToAssembly(faceA, localA);
        PVector worldB = geodesicFabricationPointToAssembly(faceB, localB);
        PVector delta = PVector.sub(worldA, worldB);
        float tangentialGap = abs(delta.dot(sharedAxis));
        float gap = delta.mag();
        float crossSeamGap = max(
          geodesicDistanceToSupportingLine(worldA, worldB0, worldB1),
          geodesicDistanceToSupportingLine(worldB, worldA0, worldA1));
        audit.recordGap(gap, tangentialGap, crossSeamGap, edge,
          jointA.mateCode, depthFraction, tA);
        if (!hadFailure && audit.failedEdgeId == edge.id) {
          GeodesicFace modelFaceA = model.faces.get(edge.faceA);
          GeodesicFace modelFaceB = model.faces.get(edge.faceB);
          PVector modelEdgeMid = PVector.add(
            model.vertices.get(edge.a).position,
            model.vertices.get(edge.b).position).mult(0.5f);
          PVector lineA = PVector.sub(worldA1, worldA0).normalize();
          PVector lineB = PVector.sub(worldB1, worldB0).normalize();
          audit.failedRequestedDepthMM =
            faceA.resolvedFabrication.requestedFrameDepthMM;
          audit.failedResolvedDepthAMM = depthA;
          audit.failedResolvedDepthBMM = depthB;
          audit.failedResolvedWidthAMM =
            faceA.resolvedFabrication.frameWidthMM;
          audit.failedResolvedWidthBMM =
            faceB.resolvedFabrication.frameWidthMM;
          audit.failedNormalAngleDeg = jointA.normalAngleDeg;
          audit.failedProfileLineAngleDeg = degrees(acos(constrain(
            abs(lineA.dot(lineB)), -1, 1)));
          audit.failedNeighborSideA = PVector.sub(
            modelFaceB.centroid, modelEdgeMid).dot(modelFaceA.normal);
          audit.failedNeighborSideB = PVector.sub(
            modelFaceA.centroid, modelEdgeMid).dot(modelFaceB.normal);
        }
      }
    }

    if (jointA.portalCenters.size() > 0) {
      GeodesicJointEdgeProfile jointB = faceB.joints.get(edgeB);
      if (jointA.portalCenters.size() != jointB.portalCenters.size()) {
        audit.valid = false;
        audit.failedEdgeId = edge.id;
        audit.failedFaceA = edge.faceA;
        audit.failedFaceB = edge.faceB;
        audit.status = "PORTAL COUNT MISMATCH";
        return audit;
      }
      for (int i = 0; i < jointA.portalCenters.size(); i++) {
        float a = jointA.portalCenters.get(i);
        float b = jointB.portalCenters.get(
          reverse ? jointB.portalCenters.size() - 1 - i : i);
        if (reverse) b = 1.0f - b;
        float offset = abs(a - b) * jointA.edgeLengthMM;
        audit.maximumPortalOffsetMM = max(audit.maximumPortalOffsetMM, offset);
        if (offset > audit.toleranceMM && audit.failedEdgeId < 0) {
          audit.valid = false;
          audit.failedEdgeId = edge.id;
          audit.failedFaceA = edge.faceA;
          audit.failedFaceB = edge.faceB;
          audit.failedMateCode = jointA.mateCode;
        }
      }
    }
  }

  audit.status = audit.valid ? "ASSEMBLED SEAMS PASS" :
    "ASSEMBLED SEAM GAP";
  return audit;
}

float geodesicDistanceToSupportingLine(PVector point, PVector lineA,
  PVector lineB) {
  if (point == null || lineA == null || lineB == null)
    return Float.MAX_VALUE;
  PVector direction = PVector.sub(lineB, lineA);
  float magnitudeSq = direction.magSq();
  if (magnitudeSq < 0.000000001f) return Float.MAX_VALUE;
  PVector relative = PVector.sub(point, lineA);
  float station = relative.dot(direction) / magnitudeSq;
  PVector closest = PVector.add(lineA, PVector.mult(direction, station));
  return PVector.dist(point, closest);
}

boolean geodesicAssemblyExteriorAtTop(GeodesicFabricationSettings settings) {
  return settings != null &&
    settings.style == GeodesicPanelStyle.FRAME_SKIN &&
    settings.reliefSide == GeodesicReliefSide.EXTERIOR_CROWN;
}

int geodesicFabricationEdgeToward(GeodesicFabricationFace face,
  int neighborFaceId) {
  if (face == null) return -1;
  for (int i = 0; i < face.neighborFaceIds.size(); i++)
    if (face.neighborFaceIds.get(i) == neighborFaceId) return i;
  return -1;
}

boolean geodesicFabricationEdgesRunOpposite(GeodesicFabricationFace faceA,
  int edgeA, GeodesicFabricationFace faceB, int edgeB) {
  int aStart = faceA.vertexIds.get(edgeA);
  int aEnd = faceA.vertexIds.get((edgeA + 1) % faceA.vertexCount());
  int bStart = faceB.vertexIds.get(edgeB);
  int bEnd = faceB.vertexIds.get((edgeB + 1) % faceB.vertexCount());
  if (aStart == bEnd && aEnd == bStart) return true;
  if (aStart == bStart && aEnd == bEnd) return false;
  return PVector.dist(faceA.boundary.get(edgeA), faceB.boundary.get(edgeB)) >
    PVector.dist(faceA.boundary.get(edgeA),
      faceB.boundary.get((edgeB + 1) % faceB.vertexCount()));
}

PVector geodesicFabricationPointToAssembly(GeodesicFabricationFace face,
  PVector local) {
  float scale = face == null || face.resolvedFabrication == null ? 1.0f :
    max(1.0f, face.resolvedFabrication.fabricationScale);
  PVector world = face.origin.copy().mult(scale);
  world.add(PVector.mult(face.axisX, local.x));
  world.add(PVector.mult(face.axisY, local.y));
  float depth = face.resolvedFabrication == null ? 0 :
    face.resolvedFabrication.frameDepthMM;
  float inward = geodesicAssemblyExteriorAtTop(face.resolvedFabrication) ?
    depth - local.z : local.z;
  world.add(PVector.mult(face.axisZ, -inward));
  return world;
}
