/* Joint-owned zip-tie passages. Only LEGACY PORTAL opts into this geometry.
 * The four tunnel walls are planes parallel to one shared assembly axis.
 * A short, faceted round-over widens the cavity entrances, never the throat.
 */
class GeodesicStraightPortal {
  PVector seam = new PVector();
  PVector heightAxis = new PVector();
  PVector axis = new PVector();
  PVector along = new PVector();
  float centerHeight;
  float width;
  float height;
  float entryRelief = 0.35f;
  boolean fits = true;
}

boolean geodesicUsesStraightPortals(GeodesicFabricationSettings settings) {
  return settings != null && settings.fastenerPortals &&
    settings.style != GeodesicPanelStyle.SOLID &&
    settings.assemblyMode == GeodesicAssemblyMode.LEGACY_PORTAL &&
    settings.seamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER &&
    settings.portalAxisMode == GeodesicPortalAxisMode.ASSEMBLED_STRAIGHT;
}

void geodesicResolveStraightPortals(GeodesicModel model, GeodesicFace source,
  GeodesicFabricationFace face, GeodesicFabricationSettings settings) {
  for (int edge = 0; edge < face.joints.size(); edge++) {
    GeodesicJointEdgeProfile joint = face.joints.get(edge);
    if (joint.portalCenters.size() == 0 || joint.neighborFaceId < 0) continue;
    // Neighbor labels cannot affect a passage. Avoid rebuilding the entire
    // topology's mate-code registry for each of these dimension-only probes.
    GeodesicFabricationSettings neighborSettings = settings.copy();
    neighborSettings.edgeCodesEnabled = false;
    GeodesicFabricationFace neighbor = geodesicFabricationFaceRaw(model,
      model.faces.get(joint.neighborFaceId), neighborSettings);
    int mate = geodesicFabricationEdgeToward(neighbor, source.id);
    if (mate < 0 || neighbor.joints.get(mate).portalCenters.size() == 0) continue;
    GeodesicPortalChannelGeometry a = geodesicPortalChannelGeometry(face, edge);
    GeodesicPortalChannelGeometry b = geodesicPortalChannelGeometry(neighbor, mate);
    if (!a.valid || !b.valid) continue;
    GeodesicStraightPortal portal = new GeodesicStraightPortal();
    PVector va = model.vertices.get(face.vertexIds.get(edge)).position;
    PVector vb = model.vertices.get(face.vertexIds.get((edge + 1) % face.vertexCount())).position;
    portal.seam = PVector.add(va, vb).mult(0.5f * settings.fabricationScale);
    portal.heightAxis = PVector.add(face.axisZ, neighbor.axisZ).normalize();
    PVector along = PVector.sub(vb, va).normalize();
    portal.along.set(along);
    portal.axis = along.cross(portal.heightAxis).normalize();
    portal.centerHeight = 0.5f * (PVector.sub(a.innerCenterWorld, portal.seam).dot(portal.heightAxis) +
      PVector.sub(b.innerCenterWorld, portal.seam).dot(portal.heightAxis));
    portal.width = min(joint.portalWidthMM, neighbor.joints.get(mate).portalWidthMM);
    portal.height = min(a.slotTop - a.slotBottom, b.slotTop - b.slotBottom);
    portal.entryRelief = min(0.35f, portal.height * 0.15f);
    // Intersect the safe height ranges at both ends of both rails. A seam
    // cannot acquire a usable bore merely by pushing its roof through a cap.
    float low = -Float.MAX_VALUE, high = Float.MAX_VALUE;
    GeodesicFabricationFace[] pair = { face, neighbor };
    GeodesicPortalChannelGeometry[] geometry = { a, b };
    int[] edges = { edge, mate };
    for (int side = 0; side < 2; side++) {
      GeodesicFabricationFace f = pair[side];
      GeodesicPortalChannelGeometry g = geometry[side];
      GeodesicFabricationSettings fs = f.resolvedFabrication;
      boolean crown = geodesicAssemblyExteriorAtTop(fs);
      float skin = fs.style == GeodesicPanelStyle.FRAME_SKIN ? fs.skinThicknessMM : 0;
      for (int end = 0; end < 2; end++) {
        float zlo = 0.35f + (end == 1 && !crown ? skin : 0);
        float zhi = g.depth - 0.35f - (end == 1 && crown ? skin : 0);
        PVector pl = end == 0 ? geodesicMiterOuterPoint(g.miterProfile, edges[side], 0.5f, zlo) :
          new PVector(g.innerCenterLocal.x, g.innerCenterLocal.y, zlo);
        PVector ph = end == 0 ? geodesicMiterOuterPoint(g.miterProfile, edges[side], 0.5f, zhi) :
          new PVector(g.innerCenterLocal.x, g.innerCenterLocal.y, zhi);
        float hl = PVector.sub(geodesicFabricationPointToAssembly(f, pl), portal.seam).dot(portal.heightAxis);
        float hh = PVector.sub(geodesicFabricationPointToAssembly(f, ph), portal.seam).dot(portal.heightAxis);
        float reserve = portal.height * 0.5f + (end == 1 ? portal.entryRelief : 0);
        low = max(low, min(hl, hh) + reserve);
        high = min(high, max(hl, hh) - reserve);
      }
    }
    portal.fits = low <= high;
    if (portal.fits) portal.centerHeight = constrain(portal.centerHeight, low, high);
    joint.straightPortal = portal;
    joint.portalWidthMM = portal.width;
    float halfSpan = joint.edgeLengthMM * 0.5f;
    // The contracted cavity edge, not merely the outside edge length, limits
    // usable stations. Use BOTH parts and both miter levels symmetrically.
    for (int side = 0; side < 2; side++) {
      GeodesicFabricationFace f = pair[side];
      GeodesicPortalChannelGeometry g = geometry[side];
      int e = edges[side];
      PVector inner0 = geodesicPortalChannelGeometry(f, e, 0).innerCenterWorld;
      PVector inner1 = geodesicPortalChannelGeometry(f, e, 1).innerCenterWorld;
      float x0 = PVector.sub(inner0, portal.seam).dot(along);
      float x1 = PVector.sub(inner1, portal.seam).dot(along);
      halfSpan = min(halfSpan, min(-min(x0, x1), max(x0, x1)));
      for (float z : new float[] { g.slotBottom, g.slotTop }) {
        PVector outer0 = geodesicFabricationPointToAssembly(f,
          geodesicMiterOuterPoint(g.miterProfile, e, 0, z));
        PVector outer1 = geodesicFabricationPointToAssembly(f,
          geodesicMiterOuterPoint(g.miterProfile, e, 1, z));
        x0 = PVector.sub(outer0, portal.seam).dot(along);
        x1 = PVector.sub(outer1, portal.seam).dot(along);
        halfSpan = min(halfSpan, min(-min(x0, x1), max(x0, x1)));
      }
    }
    halfSpan -= max(joint.cornerClearanceMM, neighbor.joints.get(mate).cornerClearanceMM);
    geodesicScheduleBalancedPortals(joint, halfSpan,
      min(3, settings.desiredPortalsPerEdge), portal.entryRelief);
    if (joint.portalCenters.isEmpty()) portal.fits = false;
    joint.reciprocalPortalResolved = portal.fits;
    // The legacy scalar aperture fields describe one REAL hole. For a
    // two-hole fallback choose the same physical hole from either panel.
    joint.reciprocalPortalStation = joint.portalCenters.isEmpty() ? 0.5f :
      joint.portalCenters.get(joint.portalCenters.size() == 3 ? 1 :
        (face.vertexIds.get(edge) < face.vertexIds.get((edge + 1) % face.vertexCount()) ?
          0 : joint.portalCenters.size() - 1));
    joint.reciprocalPortalAxisWorld.set(portal.axis);
    joint.reciprocalPortalResidualMM = 0;
    PVector center = geodesicStraightPortalCenterWorld(joint, joint.reciprocalPortalStation);
    float localZ = geodesicAssemblyPointToFabrication(face, center).z;
    joint.reciprocalPortalThroatInwardMM = geodesicAssemblyExteriorAtTop(face.resolvedFabrication) ?
      face.resolvedFabrication.frameDepthMM - localZ : localZ;
    joint.reciprocalApertureResolved = portal.fits;
    int[] xs = { -1, 1, 1, -1 }, ys = { -1, -1, 1, 1 };
    for (int corner = 0; corner < 4; corner++) {
      joint.reciprocalApertureCornersWorld[corner] = PVector.add(center,
        PVector.mult(along, xs[corner] * portal.width * 0.5f));
      joint.reciprocalApertureCornersWorld[corner].add(
        PVector.mult(portal.heightAxis, ys[corner] * portal.height * 0.5f));
    }
  }
}

String geodesicStraightPortalSignature(GeodesicFabricationFace face,
  GeodesicJointEdgeProfile joint) {
  GeodesicStraightPortal p = joint.straightPortal;
  return "b" + round(joint.normalAngleDeg * 1000) +
    (joint.concaveJoint ? "C" : "V") + "h" + round(p.centerHeight * 1000) +
    "a" + round(p.height * 1000) + "e" + round(p.entryRelief * 1000) +
    "s" + geodesicPortalStationSignature(joint);
}

// All subdivisions are shared by floor, roof and end walls. This replaces
// the old seam lip, which could obstruct an otherwise aligned centerline.
void geodesicAddStraightTunnelShell(SurfaceMesh mesh,
  PVector ob0, PVector ob1, PVector ot0, PVector ot1,
  PVector ib0, PVector ib1, PVector it0, PVector it1,
  boolean closeStart, boolean closeEnd) {
  float[] stations = { 0, 0.80f, 0.85f, 0.90f, 0.95f, 1 };
  for (int i = 0; i < stations.length - 1; i++) {
    float s = stations[i], t = stations[i + 1];
    PVector a = PVector.lerp(ob0, ib0, s), b = PVector.lerp(ob1, ib1, s);
    PVector c = PVector.lerp(ot0, it0, s), d = PVector.lerp(ot1, it1, s);
    PVector aa = PVector.lerp(ob0, ib0, t), bb = PVector.lerp(ob1, ib1, t);
    PVector cc = PVector.lerp(ot0, it0, t), dd = PVector.lerp(ot1, it1, t);
    mesh.addQuad(a, b, bb, aa);
    mesh.addQuad(c, cc, dd, d);
    if (closeStart) mesh.addQuad(a, aa, cc, c);
    if (closeEnd) mesh.addQuad(b, d, dd, bb);
  }
}

class GeodesicStraightRailMap {
  GeodesicFabricationFace face;
  GeodesicStraightPortal portal;
  GeodesicMiterOuterProfile profile;
  int edge;
  PVector ia, ib, ita, itb, along, inward, base;
  float bottom, top, slotBottom, slotTop, depth, edgeBreak, length;

  PVector point(float t, float s, float z) {
    PVector outer = geodesicMiterOuterPoint(profile, edge, t, z);
    PVector inner = geodesicInnerChamferPoint(PVector.lerp(ia, ib, t),
      PVector.lerp(ita, itb, t), z, depth, edgeBreak);
    return PVector.lerp(outer, inner, s);
  }

  float height(PVector local) {
    return PVector.sub(geodesicFabricationPointToAssembly(face, local),
      portal.seam).dot(portal.heightAxis);
  }

  PVector transform(PVector p) {
    // Keep caps, membrane, corner joins and their lettering exactly fixed.
    if (p.z <= bottom + 0.0001f || p.z >= top - 0.0001f) return p.copy();
    PVector o0 = point(0, 0, p.z), o1 = point(1, 0, p.z);
    PVector i0 = point(0, 1, p.z), i1 = point(1, 1, p.z);
    float span = PVector.sub(i0, o0).dot(inward);
    if (abs(span) < 0.00001f) return p.copy();
    float s = constrain(PVector.sub(p, o0).dot(inward) / span, 0, 1);
    if (s < 0.00001f) s = 0;
    if (s > 0.99999f) s = 1;
    PVector left = PVector.lerp(o0, i0, s), right = PVector.lerp(o1, i1, s);
    float t = PVector.sub(p, left).dot(along) / PVector.sub(right, left).dot(along);
    ArrayList<Float> centers = face.joints.get(edge).portalCenters;
    int nearest = 0;
    for (int i = 1; i < centers.size(); i++)
      if (abs(t - centers.get(i)) < abs(t - centers.get(nearest))) nearest = i;
    float station = centers.get(nearest);
    float cellStart = nearest == 0 ? 0 : (station + centers.get(nearest - 1)) * 0.5f;
    float cellEnd = nearest == centers.size() - 1 ? 1 : (station + centers.get(nearest + 1)) * 0.5f;
    float half = portal.width / (2 * length);
    float flareInfluence = t < station ?
      constrain((t - cellStart) / max(0.0001f, station - half - cellStart), 0, 1) :
      constrain((cellEnd - t) / max(0.0001f, cellEnd - station - half), 0, 1);
    if (abs(t - station) <= half + 0.00001f) flareInfluence = 1;
    // Straighten the whole run between portals. Fading this correction in
    // every web reverses the inner wall's station order on contracted rails.
    float first = centers.get(0), last = centers.get(centers.size() - 1);
    float influence = t < first ? constrain(t / max(0.0001f, first - half), 0, 1) :
      (t > last ? constrain((1 - t) / max(0.0001f, 1 - last - half), 0, 1) : 1);
    if (t >= first - half - 0.00001f && t <= last + half + 0.00001f) influence = 1;
    if (influence < 0.00001f) return p.copy();
    float band = p.z < slotBottom ? (p.z - bottom) / (slotBottom - bottom) :
      (p.z > slotTop ? (top - p.z) / (top - slotTop) : 1);
    float u = constrain((p.z - slotBottom) / (slotTop - slotBottom), 0, 1);
    // Quarter-ellipse relief approximated by five rings at the inner mouth.
    float entry = constrain((s - 0.8f) / 0.2f, 0, 1);
    float flare = portal.entryRelief * (1 - sqrt(max(0, 1 - entry * entry)));
    float z0 = depth * 0.5f;
    float h0 = height(point(0.5f, s, z0));
    float slope = (height(point(0.5f, s, z0 + 0.1f)) - h0) / 0.1f;
    if (abs(slope) < 0.00001f) return p.copy();
    float sign = slope < 0 ? -1 : 1;
    float targetH = portal.centerHeight + sign * (u - 0.5f) * (portal.height + 2 * flare);
    float targetZ = z0 + (targetH - h0) / slope;
    float referenceZ = lerp(slotBottom, slotTop, u);
    float z = p.z + (targetZ - referenceZ) * band * influence;
    PVector l = point(0, s, z), r = point(1, s, z);
    float targetX = t * length + constrain((t - station) * 2 * length / portal.width, -1, 1) *
      flare * flareInfluence;
    float correctedT = (targetX - PVector.sub(l, base).dot(along)) /
      PVector.sub(r, l).dot(along);
    return point(lerp(t, correctedT, band * influence), s, z);
  }
}

void geodesicTransformStraightRail(SurfaceMesh mesh, int first,
  GeodesicFabricationFace face, int edge, GeodesicMiterOuterProfile profile,
  PVector ia, PVector ib, PVector ita, PVector itb,
  float bottom, float top, float slotBottom, float slotTop, float depth, float edgeBreak) {
  GeodesicStraightRailMap map = new GeodesicStraightRailMap();
  map.face = face; map.portal = face.joints.get(edge).straightPortal;
  map.profile = profile; map.edge = edge;
  map.ia = ia; map.ib = ib; map.ita = ita; map.itb = itb;
  map.bottom = bottom; map.top = top;
  map.slotBottom = slotBottom; map.slotTop = slotTop;
  map.depth = depth; map.edgeBreak = edgeBreak;
  map.base = face.boundary.get(edge);
  map.along = PVector.sub(face.boundary.get((edge + 1) % face.vertexCount()), map.base).normalize();
  map.inward = new PVector(-map.along.y, map.along.x, 0);
  map.length = face.joints.get(edge).edgeLengthMM;
  HashMap<String, PVector> cache = new HashMap<String, PVector>();
  for (int index = first; index < mesh.tris.size(); index++) {
    MeshTri tri = mesh.tris.get(index);
    PVector[] vertices = { tri.a, tri.b, tri.c };
    for (PVector p : vertices) {
      String key = mesh.auditVertexKey(p);
      PVector transformed = cache.get(key);
      if (transformed == null) {
        transformed = map.transform(p);
        cache.put(key, transformed);
      }
      p.set(transformed);
      mesh.includePreviewBounds(p);
    }
  }
}

class GeodesicPassageAudit {
  boolean valid = true;
  int checked = 0;
  int passagesChecked = 0;
  float failedStation = -1;
  int[] edgesByPortalCount = new int[4];
  int failedFace = -1;
  int failedNeighbor = -1;
  String status = "NOT REQUIRED";
  float minimumWidth = Float.MAX_VALUE;
  float minimumHeight = Float.MAX_VALUE;
  JSONObject toJSON() {
    JSONObject j = new JSONObject();
    j.setBoolean("valid", valid); j.setString("status", status);
    j.setInt("shared_edges_checked", checked);
    j.setInt("shared_passages_checked", passagesChecked);
    j.setFloat("failed_station_edge_fraction", failedStation);
    j.setInt("edges_with_one_passage", edgesByPortalCount[1]);
    j.setInt("edges_with_two_passages", edgesByPortalCount[2]);
    j.setInt("edges_with_three_passages", edgesByPortalCount[3]);
    j.setInt("failed_face", failedFace); j.setInt("failed_neighbor", failedNeighbor);
    j.setString("method", "CONTINUOUS_TRIANGLE_VS_SWEPT_RECTANGULAR_VOLUME");
    j.setFloat("geometric_tolerance_mm", 0.05f);
    j.setFloat("reference_strap_width_mm", 2.5f);
    j.setFloat("reference_strap_thickness_mm", 1.1f);
    j.setFloat("reference_total_clearance_mm", 0.4f);
    if (checked > 0) {
      j.setFloat("minimum_clear_width_mm", minimumWidth);
      j.setFloat("minimum_clear_height_mm", minimumHeight);
    }
    return j;
  }
}

GeodesicPassageAudit geodesicAuditStraightPassages(GeodesicModel model,
  GeodesicFabricationSettings settings, GeodesicGrowthMode growth, float relief) {
  GeodesicPassageAudit audit = new GeodesicPassageAudit();
  if (!geodesicUsesStraightPortals(settings)) return audit;
  HashMap<Integer, GeodesicPart> parts = new HashMap<Integer, GeodesicPart>();
  for (GeodesicEdge edge : model.edges) {
    if (edge.faceA < 0 || edge.faceB < 0) continue;
    for (int id : new int[] { edge.faceA, edge.faceB }) if (!parts.containsKey(id)) {
      GeodesicPart part = buildGeodesicFabricatedPart(model, model.faces.get(id), settings, growth, relief);
      // Match the catalog's existing code-label fallback exactly.
      if (!geodesicAuditClean(part.audit) && settings.edgeCodesEnabled) {
        GeodesicFabricationSettings plain = settings.copy(); plain.edgeCodesEnabled = false;
        part = buildGeodesicFabricatedPart(model, model.faces.get(id), plain, growth, relief);
      }
      parts.put(id, part);
    }
    GeodesicPart a = parts.get(edge.faceA), b = parts.get(edge.faceB);
    int ea = geodesicFabricationEdgeToward(a.fabricationFace, edge.faceB);
    int eb = geodesicFabricationEdgeToward(b.fabricationFace, edge.faceA);
    GeodesicJointEdgeProfile ja = a.fabricationFace.joints.get(ea);
    GeodesicJointEdgeProfile jb = b.fabricationFace.joints.get(eb);
    GeodesicStraightPortal p = ja.straightPortal;
    GeodesicStraightPortal q = b.fabricationFace.joints.get(eb).straightPortal;
    String failure = "";
    if (p == null || q == null) failure = "SHARED PASSAGE MISSING";
    else if (!p.fits || !q.fits) failure = "STRAIGHT PASSAGE DOES NOT FIT RAIL / EDGE; INCREASE PART SIZE OR ADJUST RAIL / SKIN";
    else if (!geodesicAuditClean(a.audit) || !geodesicAuditClean(b.audit)) failure = "PASSAGE MESH NOT MANIFOLD";
    else if (abs(p.centerHeight - q.centerHeight) > 0.01f || abs(p.width - q.width) > 0.01f || abs(p.height - q.height) > 0.01f)
      failure = "SHARED PASSAGE DIMENSIONS DISAGREE";
    else if (p.width - 0.10f < 2.9f || p.height - 0.10f < 1.5f)
      failure = "PASSAGE TOO SMALL FOR 2.5 x 1.1 mm STRAP + 0.4 mm CLEARANCE";
    else if (!geodesicPortalSchedulesMatch(ja, jb)) failure = "SHARED PASSAGE STATIONS DISAGREE";
    else {
      PVector along = PVector.sub(model.vertices.get(a.fabricationFace.vertexIds.get((ea + 1) % a.fabricationFace.vertexCount())).position,
        model.vertices.get(a.fabricationFace.vertexIds.get(ea)).position).normalize();
      for (float station : ja.portalCenters) {
        PVector axis = along.cross(p.heightAxis).normalize();
        PVector center = PVector.add(p.seam, PVector.mult(p.heightAxis, p.centerHeight));
        center.add(PVector.mult(along, (station - 0.5f) * ja.edgeLengthMM));
        float lo = Float.MAX_VALUE, hi = -Float.MAX_VALUE;
        for (GeodesicPart part : new GeodesicPart[] { a, b }) {
          int e = part == a ? ea : eb;
          GeodesicPortalChannelGeometry geometry = geodesicPortalChannelGeometry(part.fabricationFace, e);
          PVector wallNormal = part.fabricationFace.axisZ.cross(along).normalize();
          float divisor = axis.dot(wallNormal);
          if (abs(divisor) < 0.001f) { failure = "PASSAGE PARALLEL TO ENTRANCE"; break; }
          for (int x : new int[] { -1, 1 }) for (int y : new int[] { -1, 1 }) {
            PVector corner = PVector.add(center, PVector.mult(along, x * p.width * 0.5f));
            corner.add(PVector.mult(p.heightAxis, y * p.height * 0.5f));
            float t = PVector.sub(geometry.innerCenterWorld, corner).dot(wallNormal) / divisor;
            lo = min(lo, t); hi = max(hi, t);
          }
        }
        if (failure.length() == 0) {
          // Extend beyond both inner wall planes: checks the entrances as well
          // as every position through both rails and across the mating seam.
          for (GeodesicPart part : new GeodesicPart[] { a, b }) {
            if (geodesicMeshBlocksPassage(part, center, along, p.heightAxis, axis,
                p.width * 0.5f - 0.05f, p.height * 0.5f - 0.05f, lo - 0.20f, hi + 0.20f)) {
              failure = "SOLID INTERSECTS STRAIGHT PASSAGE"; break;
            }
          }
        }
        if (failure.length() > 0) { audit.failedStation = station; break; }
        audit.passagesChecked++;
      }
      audit.minimumWidth = min(audit.minimumWidth, p.width - 0.10f);
      audit.minimumHeight = min(audit.minimumHeight, p.height - 0.10f);
    }
    if (failure.length() > 0) {
      audit.valid = false; audit.failedFace = edge.faceA; audit.failedNeighbor = edge.faceB;
      audit.status = failure; return audit;
    }
    audit.checked++;
    audit.edgesByPortalCount[ja.portalCenters.size()]++;
  }
  audit.status = "STRAIGHT PASSAGES PASS";
  return audit;
}

boolean geodesicMeshBlocksPassage(GeodesicPart part, PVector center,
  PVector x, PVector y, PVector z, float halfWidth, float halfHeight, float lo, float hi) {
  float[] lower = { -halfWidth, -halfHeight, lo };
  float[] upper = { halfWidth, halfHeight, hi };
  for (MeshTri tri : part.mesh.tris) {
    ArrayList<PVector> polygon = new ArrayList<PVector>();
    for (PVector local : new PVector[] { tri.a, tri.b, tri.c }) {
      PVector delta = PVector.sub(geodesicFabricationPointToAssembly(part.fabricationFace, local), center);
      polygon.add(new PVector(delta.dot(x), delta.dot(y), delta.dot(z)));
    }
    // Exact convex clipping of the triangle against the entire swept volume.
    // Unlike centerline rays or station samples this catches side-wall snags.
    for (int dim = 0; dim < 3 && polygon.size() > 0; dim++) {
      polygon = geodesicClipPassagePolygon(polygon, dim, lower[dim], true);
      polygon = geodesicClipPassagePolygon(polygon, dim, upper[dim], false);
    }
    if (polygon.size() >= 3) return true;
  }
  return false;
}

float geodesicPassageComponent(PVector p, int dim) { return dim == 0 ? p.x : (dim == 1 ? p.y : p.z); }

ArrayList<PVector> geodesicClipPassagePolygon(ArrayList<PVector> input, int dim, float limit, boolean above) {
  ArrayList<PVector> output = new ArrayList<PVector>();
  if (input.size() == 0) return output;
  PVector previous = input.get(input.size() - 1);
  float pv = geodesicPassageComponent(previous, dim) - limit;
  for (PVector current : input) {
    float cv = geodesicPassageComponent(current, dim) - limit;
    boolean pi = above ? pv >= 0 : pv <= 0;
    boolean ci = above ? cv >= 0 : cv <= 0;
    if (pi != ci) output.add(PVector.lerp(previous, current, pv / (pv - cv)));
    if (ci) output.add(current);
    previous = current; pv = cv;
  }
  return output;
}

// Keep apertures sized for the strap. Only station spacing scales with the
// edge; fall back to two or one when three would consume the reserved web.
void geodesicScheduleBalancedPortals(GeodesicJointEdgeProfile joint,
  float usableHalfSpan, int desired, float entryRelief) {
  joint.portalCenters.clear();
  float mouth = joint.portalWidthMM + 2 * entryRelief;
  float web = max(1.2f, joint.portalWidthMM * 0.4f);
  float room = usableHalfSpan - mouth * 0.5f;
  if (desired < 1 || room < 0) return;
  float spread = min(joint.edgeLengthMM * 0.25f, room);
  int count = desired >= 3 && spread >= mouth + web ? 3 :
    (desired >= 2 && spread * 2 >= mouth + web ? 2 : 1);
  if (count >= 2) joint.portalCenters.add(0.5f - spread / joint.edgeLengthMM);
  if (count != 2) joint.portalCenters.add(0.5f);
  if (count >= 2) joint.portalCenters.add(0.5f + spread / joint.edgeLengthMM);
}

String geodesicPortalStationSignature(GeodesicJointEdgeProfile joint) {
  String result = "";
  for (float station : joint.portalCenters) result += "_" + round(station * 100000);
  return result;
}

boolean geodesicPortalSchedulesMatch(GeodesicJointEdgeProfile a, GeodesicJointEdgeProfile b) {
  if (a.portalCenters.size() != b.portalCenters.size() || a.portalCenters.isEmpty()) return false;
  for (int i = 0; i < a.portalCenters.size(); i++)
    if (abs(a.portalCenters.get(i) - (1 - b.portalCenters.get(b.portalCenters.size() - 1 - i))) * a.edgeLengthMM > 0.01f)
      return false;
  return true;
}

PVector geodesicStraightPortalCenterWorld(GeodesicJointEdgeProfile joint, float station) {
  GeodesicStraightPortal p = joint.straightPortal;
  return PVector.add(p.seam, PVector.mult(p.heightAxis, p.centerHeight)).add(
    PVector.mult(p.along, (station - 0.5f) * joint.edgeLengthMM));
}
