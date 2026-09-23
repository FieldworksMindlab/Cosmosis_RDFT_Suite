/*
  Geodesic Salon connector openings.

  An opening is a connected set of triangular faces whose removal leaves a
  closed boundary cycle made entirely of existing dome edges, so the cut follows
  strut lines instead of crossing panels.

  The family that wins on every dome measured is the vertex fan: every face
  touching one node. Its boundary is that node's link cycle, so the perimeter is
  already a ring of existing struts, and its node count equals the vertex
  valence -- which maps straight onto a Truss Yard section. A valence-6 fan
  gives a hexagonal opening a HEXAGON tunnel can meet node to node.

  That matters because of what dominates connector stress. Alpermann, Gengnagel
  and Quinn (IASS 2010) measured on a 14 m dome with entrances that the largest
  deflections and stresses always appear in the struts surrounding an opening,
  that geometric irregularity cost about 18% in reference stress, and that
  connector eccentricity -- members not meeting on a common node -- tripled
  stress against an idealised joint while deflection barely moved. A near-planar
  perimeter whose node count equals the tunnel section designs that eccentricity
  out rather than detailing around it.

  This file only measures and selects. It removes no faces and writes no
  geometry, so the qualified Salon kit pipeline is untouched until a selection
  is deliberately acted on.
*/

final float GEODESIC_OPENING_LENGTH_QUANTUM = 0.05f;

class GeodesicOpeningCandidate {
  String label = "";
  IntList faces = new IntList();
  IntList ring = new IntList();          // perimeter vertex ids, in cycle order
  // World positions of the ring, captured at scan time so the handoff does not
  // depend on the live dome still being the one that was measured.
  ArrayList<PVector> ringWorld = new ArrayList<PVector>();
  int nodes = 0;
  float planarityMM = 0;                 // RMS departure of the ring from a plane
  float minCornerDeg = 0;
  int distinctEdgeLengths = 0;
  float perimeterMM = 0;
  float minSpanMM = 0;
  float maxSpanMM = 0;
  int minRemainingValence = 0;
  boolean touchesRim = false;
  float heightFraction = 0;
  int repeats = 1;
  float score = 0;
  PVector centroid = new PVector();
  PVector normal = new PVector(0, 0, 1);

  /* The Yard builds these sections, so a matching perimeter node count lets the
     tunnel meet the dome with nothing interposed. */
  String matchingSection() {
    if (nodes == 3) return "TRIANGLE";
    if (nodes == 4) return "SQUARE";
    if (nodes == 5) return "PENTAGON";
    if (nodes == 6) return "HEXAGON";
    if (nodes == 8) return "OCTAGON";
    if (nodes == 12) return "DODECAGON";
    return "";
  }

  boolean matchesTrussSection() { return matchingSection().length() > 0; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("label", label);
    json.setString("matching_truss_section", matchingSection());
    JSONArray faceIds = new JSONArray();
    for (int i = 0; i < faces.size(); i++) faceIds.setInt(i, faces.get(i));
    json.setJSONArray("removed_face_ids", faceIds);
    JSONArray ringIds = new JSONArray();
    for (int i = 0; i < ring.size(); i++) ringIds.setInt(i, ring.get(i));
    json.setJSONArray("perimeter_vertex_ids", ringIds);
    JSONArray ringPoints = new JSONArray();
    for (int i = 0; i < ringWorld.size(); i++) {
      JSONArray point = new JSONArray();
      point.setFloat(0, ringWorld.get(i).x);
      point.setFloat(1, ringWorld.get(i).y);
      point.setFloat(2, ringWorld.get(i).z);
      ringPoints.setJSONArray(i, point);
    }
    json.setJSONArray("perimeter_points_mm", ringPoints);
    json.setInt("perimeter_nodes", nodes);
    json.setFloat("planarity_mm", planarityMM);
    json.setFloat("minimum_corner_deg", minCornerDeg);
    json.setInt("distinct_edge_lengths", distinctEdgeLengths);
    json.setFloat("perimeter_mm", perimeterMM);
    json.setFloat("minimum_span_mm", minSpanMM);
    json.setFloat("maximum_span_mm", maxSpanMM);
    json.setInt("minimum_remaining_valence", minRemainingValence);
    json.setBoolean("touches_rim", touchesRim);
    json.setFloat("height_fraction", heightFraction);
    json.setInt("symmetry_repeats", repeats);
    json.setFloat("score", score);
    JSONArray centre = new JSONArray();
    centre.setFloat(0, centroid.x); centre.setFloat(1, centroid.y);
    centre.setFloat(2, centroid.z);
    json.setJSONArray("centroid_mm", centre);
    JSONArray axis = new JSONArray();
    axis.setFloat(0, normal.x); axis.setFloat(1, normal.y);
    axis.setFloat(2, normal.z);
    json.setJSONArray("outward_normal", axis);
    return json;
  }
}

/* What Salon hands to Truss Yard when an opening is committed. */
class GeodesicOpeningSelection {
  boolean active = false;
  String domeFingerprint = "";
  float domeRadiusMM = 0;
  GeodesicOpeningCandidate candidate = null;
  /* The dome's own fabrication dimensions, captured when the opening is
     committed. This is the head of the lineage: the connector and any tunnel
     bound to it build to these numbers instead of deriving their own, which is
     what makes miters and portals line up across the three workspaces. */
  GeodesicFabricationSettings domeFabrication = null;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.geodesic_salon.connector_opening.v1");
    json.setBoolean("active", active);
    json.setString("dome_fingerprint", domeFingerprint);
    json.setFloat("dome_radius_mm", domeRadiusMM);
    json.setString("contract",
      "the tunnel meets this perimeter node to node; no adapter plate is " +
      "interposed, because offset member centrelines are what drive " +
      "connector stress");
    if (domeFabrication != null) {
      JSONObject dims = new JSONObject();
      dims.setFloat("frame_depth_mm", domeFabrication.frameDepthMM);
      dims.setFloat("frame_width_mm", domeFabrication.frameWidthMM);
      dims.setFloat("portal_width_mm", domeFabrication.portalWidthMM);
      dims.setFloat("portal_height_mm", domeFabrication.portalHeightMM);
      dims.setFloat("skin_thickness_mm", domeFabrication.skinThicknessMM);
      dims.setFloat("edge_break_mm", domeFabrication.edgeBreakMM);
      dims.setFloat("fabrication_scale", domeFabrication.fabricationScale);
      dims.setFloat("effective_assembly_radius_mm",
        domeFabrication.effectiveAssemblyRadiusMM);
      dims.setString("lineage",
        "dome sets these; connector and bound tunnel inherit them so miters " +
        "and portals line up across workspaces");
      json.setJSONObject("dome_dimensions", dims);
    }
    if (candidate != null) json.setJSONObject("opening", candidate.toJSON());
    return json;
  }
}

GeodesicOpeningSelection geodesicOpeningSelection = new GeodesicOpeningSelection();
ArrayList<GeodesicOpeningCandidate> geodesicOpeningCandidates =
  new ArrayList<GeodesicOpeningCandidate>();
int geodesicOpeningIndex = 0;
String geodesicOpeningStatus = "not scanned";

// --------------------------------------------------------------------------
// graph helpers
// --------------------------------------------------------------------------

String geodesicOpeningEdgeKey(int a, int b) {
  return a < b ? a + "_" + b : b + "_" + a;
}

HashMap<String, IntList> geodesicOpeningFacesAtEdge(GeodesicModel model) {
  HashMap<String, IntList> map = new HashMap<String, IntList>();
  for (GeodesicFace face : model.faces)
    for (int i = 0; i < 3; i++) {
      String key = geodesicOpeningEdgeKey(face.vertex(i), face.vertex((i + 1) % 3));
      if (!map.containsKey(key)) map.put(key, new IntList());
      map.get(key).append(face.id);
    }
  return map;
}

HashMap<Integer, IntList> geodesicOpeningFacesAtVertex(GeodesicModel model) {
  HashMap<Integer, IntList> map = new HashMap<Integer, IntList>();
  for (GeodesicFace face : model.faces)
    for (int i = 0; i < 3; i++) {
      int vid = face.vertex(i);
      if (!map.containsKey(vid)) map.put(vid, new IntList());
      if (!map.get(vid).hasValue(face.id)) map.get(vid).append(face.id);
    }
  return map;
}

/* Ordered boundary cycle of a face patch, or an empty list when the boundary is
   not one simple closed loop -- a pinched patch cannot serve as an opening. */
IntList geodesicOpeningPerimeter(GeodesicModel model, IntList patch,
  HashMap<String, IntList> facesAtEdge) {
  IntList fromVertex = new IntList();
  IntList toVertex = new IntList();
  for (int p = 0; p < patch.size(); p++) {
    GeodesicFace face = model.faces.get(patch.get(p));
    for (int i = 0; i < 3; i++) {
      int a = face.vertex(i), b = face.vertex((i + 1) % 3);
      IntList shared = facesAtEdge.get(geodesicOpeningEdgeKey(a, b));
      int outside = 0;
      for (int s = 0; s < shared.size(); s++)
        if (!patch.hasValue(shared.get(s))) outside++;
      if (outside > 0 || shared.size() == 1) { fromVertex.append(a); toVertex.append(b); }
    }
  }
  IntList ring = new IntList();
  if (fromVertex.size() < 3) return ring;
  // Every boundary vertex must be left exactly once, or the loop is not simple.
  for (int i = 0; i < fromVertex.size(); i++) {
    int count = 0;
    for (int j = 0; j < fromVertex.size(); j++)
      if (fromVertex.get(j) == fromVertex.get(i)) count++;
    if (count != 1) return new IntList();
  }
  int start = fromVertex.get(0);
  int current = start;
  for (int guard = 0; guard < fromVertex.size() + 1; guard++) {
    ring.append(current);
    int next = -1;
    for (int j = 0; j < fromVertex.size(); j++)
      if (fromVertex.get(j) == current) { next = toVertex.get(j); break; }
    if (next < 0) return new IntList();
    if (next == start) break;
    if (ring.hasValue(next)) return new IntList();
    current = next;
  }
  return ring.size() == fromVertex.size() ? ring : new IntList();
}

GeodesicOpeningCandidate geodesicEvaluateOpening(GeodesicModel model,
  IntList patch, String label, HashMap<String, IntList> facesAtEdge,
  HashMap<Integer, IntList> facesAtVertex, float minZ, float maxZ) {
  IntList ring = geodesicOpeningPerimeter(model, patch, facesAtEdge);
  if (ring.size() < 3) return null;

  GeodesicOpeningCandidate candidate = new GeodesicOpeningCandidate();
  candidate.label = label;
  candidate.faces = patch;
  candidate.ring = ring;
  candidate.nodes = ring.size();
  for (int i = 0; i < ring.size(); i++)
    candidate.ringWorld.add(model.vertices.get(ring.get(i)).position.copy());

  PVector centre = new PVector();
  for (int i = 0; i < ring.size(); i++)
    centre.add(model.vertices.get(ring.get(i)).position);
  centre.mult(1.0f / ring.size());
  candidate.centroid.set(centre);

  // Newell normal of the ring, then how far the ring departs from that plane.
  PVector normal = new PVector();
  for (int i = 0; i < ring.size(); i++) {
    PVector a = model.vertices.get(ring.get(i)).position;
    PVector b = model.vertices.get(ring.get((i + 1) % ring.size())).position;
    normal.x += (a.y - b.y) * (a.z + b.z);
    normal.y += (a.z - b.z) * (a.x + b.x);
    normal.z += (a.x - b.x) * (a.y + b.y);
  }
  if (normal.magSq() < 0.000001f) return null;
  normal.normalize();
  candidate.normal.set(normal);

  float squared = 0;
  for (int i = 0; i < ring.size(); i++) {
    PVector p = model.vertices.get(ring.get(i)).position;
    float d = PVector.sub(p, centre).dot(normal);
    squared += d * d;
  }
  candidate.planarityMM = sqrt(squared / ring.size());

  candidate.minCornerDeg = 180;
  candidate.perimeterMM = 0;
  IntList quantized = new IntList();
  for (int i = 0; i < ring.size(); i++) {
    PVector prev = model.vertices.get(ring.get((i + ring.size() - 1) % ring.size())).position;
    PVector here = model.vertices.get(ring.get(i)).position;
    PVector next = model.vertices.get(ring.get((i + 1) % ring.size())).position;
    PVector u = PVector.sub(prev, here); u.normalize();
    PVector v = PVector.sub(next, here); v.normalize();
    candidate.minCornerDeg = min(candidate.minCornerDeg,
      degrees(acos(constrain(u.dot(v), -1, 1))));
    float length = PVector.dist(here, next);
    candidate.perimeterMM += length;
    int key = round(length / GEODESIC_OPENING_LENGTH_QUANTUM);
    if (!quantized.hasValue(key)) quantized.append(key);
  }
  candidate.distinctEdgeLengths = quantized.size();

  candidate.minSpanMM = Float.MAX_VALUE;
  candidate.maxSpanMM = 0;
  for (int i = 0; i < ring.size(); i++)
    for (int j = i + 1; j < ring.size(); j++) {
      float span = PVector.dist(model.vertices.get(ring.get(i)).position,
        model.vertices.get(ring.get(j)).position);
      candidate.minSpanMM = min(candidate.minSpanMM, span);
      candidate.maxSpanMM = max(candidate.maxSpanMM, span);
    }

  // A perimeter node left holding almost nothing is the under-supported case
  // the IASS paper found carrying the highest stresses.
  candidate.minRemainingValence = 99;
  for (int i = 0; i < ring.size(); i++) {
    IntList incident = facesAtVertex.get(ring.get(i));
    int remaining = 0;
    for (int f = 0; f < incident.size(); f++)
      if (!patch.hasValue(incident.get(f))) remaining++;
    candidate.minRemainingValence = min(candidate.minRemainingValence, remaining);
  }

  for (int i = 0; i < ring.size(); i++) {
    IntList shared = facesAtEdge.get(geodesicOpeningEdgeKey(
      ring.get(i), ring.get((i + 1) % ring.size())));
    if (shared != null && shared.size() == 1) candidate.touchesRim = true;
  }
  candidate.heightFraction = (centre.z - minZ) / max(0.000001f, maxZ - minZ);
  return candidate;
}

/* Ranked openings for the live dome. Lower score is better: planarity leads,
   because it is what predicts connector eccentricity. */
ArrayList<GeodesicOpeningCandidate> geodesicScoreOpenings(GeodesicModel model) {
  ArrayList<GeodesicOpeningCandidate> results =
    new ArrayList<GeodesicOpeningCandidate>();
  if (model == null || model.faces.size() == 0) return results;

  HashMap<String, IntList> facesAtEdge = geodesicOpeningFacesAtEdge(model);
  HashMap<Integer, IntList> facesAtVertex = geodesicOpeningFacesAtVertex(model);
  float minZ = Float.MAX_VALUE, maxZ = -Float.MAX_VALUE;
  for (GeodesicVertex vertex : model.vertices) {
    minZ = min(minZ, vertex.position.z);
    maxZ = max(maxZ, vertex.position.z);
  }

  // Vertex fans only. Edge pairs and single rim faces also form legal rings but
  // measured worse on every dome: they leave perimeter nodes holding two faces
  // and their node counts rarely match a section.
  for (Integer vid : facesAtVertex.keySet()) {
    IntList fan = facesAtVertex.get(vid);
    if (fan.size() < 3) continue;
    IntList patch = new IntList();
    for (int i = 0; i < fan.size(); i++) patch.append(fan.get(i));
    GeodesicOpeningCandidate candidate = geodesicEvaluateOpening(model, patch,
      "vertex fan v" + vid + " (valence " + fan.size() + ")",
      facesAtEdge, facesAtVertex, minZ, maxZ);
    if (candidate != null) results.add(candidate);
  }

  // Symmetry-equivalent openings share a perimeter signature, so one portal
  // part can serve every site it recurs at.
  for (GeodesicOpeningCandidate a : results) {
    int repeats = 0;
    for (GeodesicOpeningCandidate b : results)
      if (a.nodes == b.nodes &&
          abs(a.perimeterMM - b.perimeterMM) < 0.05f &&
          a.distinctEdgeLengths == b.distinctEdgeLengths) repeats++;
    a.repeats = max(1, repeats);
  }

  float radius = max(1, model.radius);
  for (GeodesicOpeningCandidate c : results) {
    c.score = c.planarityMM / radius * 40.0f
      + c.distinctEdgeLengths * 0.35f
      + max(0, 60.0f - c.minCornerDeg) / 60.0f
      + max(0, 3 - c.minRemainingValence) * 1.2f
      + (c.faces.size() / (float)model.faces.size()) * 2.0f
      - (c.touchesRim ? 0.6f : 0)
      - min(c.repeats, 12) * 0.05f
      - (c.matchesTrussSection() ? 1.5f : 0);
  }
  for (int i = 1; i < results.size(); i++)
    for (int j = i; j > 0 && results.get(j).score < results.get(j - 1).score; j--) {
      GeodesicOpeningCandidate swap = results.get(j);
      results.set(j, results.get(j - 1));
      results.set(j - 1, swap);
    }
  return results;
}

void geodesicScanOpenings() {
  geodesicOpeningCandidates = geodesicScoreOpenings(geodesicModel);
  geodesicOpeningIndex = 0;
  if (geodesicOpeningCandidates.size() == 0) {
    geodesicOpeningStatus = "no opening follows existing struts";
    return;
  }
  geodesicOpeningStatus = geodesicOpeningCandidates.size() + " candidates";
}

void geodesicCycleOpening(int direction) {
  if (geodesicOpeningCandidates.size() == 0) { geodesicScanOpenings(); return; }
  geodesicOpeningIndex = (geodesicOpeningIndex + direction +
    geodesicOpeningCandidates.size()) % geodesicOpeningCandidates.size();
}

GeodesicOpeningCandidate geodesicSelectedOpening() {
  if (geodesicOpeningCandidates.size() == 0) return null;
  return geodesicOpeningCandidates.get(
    constrain(geodesicOpeningIndex, 0, geodesicOpeningCandidates.size() - 1));
}

/* Commits the highlighted opening and hands it to Truss Yard. */
void geodesicCommitOpening() {
  GeodesicOpeningCandidate candidate = geodesicSelectedOpening();
  if (candidate == null) {
    geodesicScanOpenings();
    candidate = geodesicSelectedOpening();
  }
  if (candidate == null) {
    geodesicOpeningStatus = "nothing to commit";
    return;
  }
  geodesicOpeningSelection.active = true;
  geodesicOpeningSelection.candidate = candidate;
  geodesicOpeningSelection.domeFingerprint =
    geodesicModel == null ? "" : geodesicModel.fingerprint;
  geodesicOpeningSelection.domeRadiusMM =
    geodesicModel == null ? 0 : geodesicModel.radius;
  // Head of the lineage: whatever the dome is set to is what the rest inherit.
  //
  // Resolve first rather than copying the raw UI values. Geodesic Salon raises
  // a fabrication scale so its panels print at a usable size -- a 72 mm dome
  // exports at 205 mm effective radius, a factor of 2.85 -- and that scale has
  // to travel with the dimensions or the connector and tunnel come out to the
  // right proportions at the wrong size.
  geodesicOpeningSelection.domeFabrication = geodesicModel == null ?
    currentGeodesicFabricationSettings().copy() :
    geodesicResolveKitFabricationSettings(geodesicModel,
      currentGeodesicFabricationSettings()).copy();
  geodesicOpeningStatus = "COMMITTED / " + candidate.matchingSection() +
    " " + candidate.nodes + "-node";
}
