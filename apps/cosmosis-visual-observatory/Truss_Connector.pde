/*
  Truss Yard dome connector.

  Geodesic Salon commits an opening; this builds the piece that lets a tunnel
  meet it. The dome is never modified: the connector adapts to the opening's
  perimeter, so a dome can be printed whole and a tunnel added without
  compromising it.

  The geometry is deliberately boring, and that is the point. The connector's
  first ring IS the opening perimeter -- the same world points, not a copy
  offset by a plate -- so incident members meet on the dome's own nodes and the
  designed eccentricity is exactly zero. Alpermann, Gengnagel and Quinn (IASS
  2010) measured that offset member centrelines tripled connector stress against
  an idealised joint while deflection barely moved, so eccentricity is the thing
  worth engineering away rather than detailing around.

  From that ring the collar blends to a regular polygon over a short run, which
  is the tunnel's standard section. Every panel then flows through the ordinary
  Truss Yard fabrication path: same miters, same portals, same audits, same
  catalog. The only special class is the gate ring against the dome, which
  carries the loads the opening interrupted and gets wider rails at identical
  depth -- depth has to match or the shared miter stops mating.
*/

/* One bay by default, and that is a measured choice rather than a timid one.
   A single-bay collar goes straight from the opening perimeter to the regular
   section, so consecutive rings never both change shape and the wall comes out
   fully convex. Every extra bay adds an intermediate ring, and any two rings
   that differ in shape crease at their interface -- proven for twisted tubes
   and the same here. The reciprocal portal solver does not resolve an aperture
   at a sharp concave crease, so multi-bay collars currently lose portals there:
   measured 8 unresolved of 12 creases at 3 bays, 12 of 18 at 4. */
int trussConnectorCollarBays = 1;
float trussGateRailScale = 1.6f;

class TrussConnectorResult {
  boolean evaluated = false;
  boolean built = false;
  int nodes = 0;
  String section = "";
  float maximumNodeOffsetMM = Float.MAX_VALUE;   // connector ring vs dome ring
  float openingPlanarityMM = 0;
  float collarLengthMM = 0;
  float ringRadiusMM = 0;
  int gatePanels = 0;
  int collarPanels = 0;
  // Resolved rail section of the built connector. A tunnel bound to this piece
  // must carry the same rail, or the two do not mate at the terminal ring.
  float railWidthMM = 0;
  float railDepthMM = 0;
  float terminalRadiusMM = 0;
  String status = "no opening committed";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.truss_yard.dome_connector.v1");
    json.setBoolean("evaluated", evaluated);
    json.setBoolean("built", built);
    json.setString("status", status);
    json.setInt("perimeter_nodes", nodes);
    json.setString("tunnel_section", section);
    json.setFloat("maximum_node_offset_mm", maximumNodeOffsetMM);
    json.setFloat("opening_planarity_mm", openingPlanarityMM);
    json.setFloat("collar_length_mm", collarLengthMM);
    json.setFloat("ring_radius_mm", ringRadiusMM);
    json.setInt("gate_panels", gatePanels);
    json.setInt("collar_panels", collarPanels);
    json.setFloat("rail_width_mm", railWidthMM);
    json.setFloat("rail_depth_mm", railDepthMM);
    json.setFloat("terminal_ring_radius_mm", terminalRadiusMM);
    json.setString("bind_contract",
      "a tunnel bound to this connector inherits the terminal ring radius and " +
      "the rail section; bay count, bay height and twist stay free");
    json.setFloat("gate_rail_scale", trussGateRailScale);
    json.setString("eccentricity_contract",
      "the connector's dome-side ring is the opening perimeter itself, so " +
      "members meet on the dome's own nodes and designed eccentricity is zero; " +
      "maximum_node_offset_mm is the measured residual");
    json.setString("dome_contract",
      "the dome is not modified; it exports whole and the opening drives only " +
      "this connector");
    return json;
  }
}

TrussConnectorResult trussConnectorResult = new TrussConnectorResult();
boolean trussConnectionMode = false;

boolean trussConnectorAvailable() {
  return geodesicOpeningSelection != null &&
    geodesicOpeningSelection.active &&
    geodesicOpeningSelection.candidate != null &&
    geodesicOpeningSelection.candidate.matchesTrussSection() &&
    geodesicOpeningSelection.candidate.ringWorld.size() >= 3;
}

/* Regular polygon matching the opening, placed a collar's length along the
   opening normal and rotated so vertex i lines up with perimeter vertex i.
   Aligning the rings removes the twist that would otherwise show up as a
   node-to-node offset at the far end of the collar. */
ArrayList<PVector> trussConnectorTargetRing(GeodesicOpeningCandidate opening,
  float collarLength) {
  ArrayList<PVector> target = new ArrayList<PVector>();
  int n = opening.ringWorld.size();
  PVector normal = opening.normal.copy();
  if (normal.magSq() < 0.000001f) return target;
  normal.normalize();

  float radius = 0;
  for (PVector p : opening.ringWorld)
    radius += PVector.dist(p, opening.centroid);
  radius /= n;

  // In-plane frame anchored on the first perimeter node, so the regular ring
  // starts aligned with the opening instead of at an arbitrary phase.
  PVector u = PVector.sub(opening.ringWorld.get(0), opening.centroid);
  u.sub(PVector.mult(normal, u.dot(normal)));
  if (u.magSq() < 0.000001f) return target;
  u.normalize();
  PVector v = normal.cross(u);
  v.normalize();

  PVector centre = PVector.add(opening.centroid,
    PVector.mult(normal, collarLength));
  for (int i = 0; i < n; i++) {
    float angle = TWO_PI * i / n;
    PVector p = centre.copy();
    p.add(PVector.mult(u, cos(angle) * radius));
    p.add(PVector.mult(v, sin(angle) * radius));
    target.add(p);
  }
  return target;
}

/* Builds the connector as an ordinary triangulated frame model so it inherits
   the whole fabrication path rather than growing a parallel one. */
TrussMastModel trussBuildConnectorModel(GeodesicOpeningCandidate opening,
  TrussConnectorResult result) {
  TrussMastModel model = new TrussMastModel();
  result.evaluated = true;
  int n = opening.ringWorld.size();
  result.nodes = n;
  result.section = opening.matchingSection();
  result.openingPlanarityMM = opening.planarityMM;

  model.sectionSides = n;
  model.section = TrussSectionFamily.HEXAGON;      // overridden by sectionSides
  for (TrussSectionFamily family : TrussSectionFamily.values())
    if (family.sides() == n) model.section = family;
  model.bays = max(1, trussConnectorCollarBays);
  model.tunnel = true;
  // A connector is entered through the tunnel bore, so its ties are threaded
  // from inside like any tunnel.
  model.accessSide = TrussAccessSide.INTERIOR;
  model.axis = new TrussAxisFrame(true);
  model.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  // Rings change shape along the collar, not just orientation, so the crease
  // ring at each bay interface is forced rather than a triangulation fault.
  model.ringShapeVaries = true;
  model.framePanelMode = trussFramePanelMode;
  // The connector exists because of an opening, so it always builds to that
  // dome's dimensions. It is the middle of the lineage, never its own island.
  model.lineageFabrication = geodesicOpeningSelection == null ? null :
    geodesicOpeningSelection.domeFabrication;
  model.combined = new SurfaceMesh("dome_connector");
  model.adapter = new SurfaceMesh("dome_connector_adapter_unused");

  float radius = 0;
  for (PVector p : opening.ringWorld) radius += PVector.dist(p, opening.centroid);
  radius /= n;
  result.ringRadiusMM = radius;
  // Long enough to blend the irregular perimeter into a regular section without
  // forcing sharp panel folds, short enough to stay a collar.
  float collar = max(radius * 0.9f, opening.perimeterMM / n * 1.1f);
  result.collarLengthMM = collar;
  model.baySpanMM = radius * 2;
  model.bayHeightMM = collar / model.bays;
  model.strutRadiusMM = trussStrutRadiusMM;
  model.twistRadians = 0;

  ArrayList<PVector> target = trussConnectorTargetRing(opening, collar);
  if (target.size() != n) {
    result.status = "opening normal is degenerate";
    return model;
  }

  // The axis frame is built around the world origin, but the connector sits out
  // at the opening. Work in a local frame whose origin is the opening centre
  // and whose axis is the opening normal, then the ordinary radial reasoning in
  // Truss Yard applies unchanged.
  PVector normal = opening.normal.copy();
  normal.normalize();
  model.axis.origin.set(opening.centroid);
  model.axis.direction.set(normal);

  PVector[][] rings = new PVector[model.bays + 1][n];
  for (int station = 0; station <= model.bays; station++) {
    float blend = station / (float)model.bays;
    for (int i = 0; i < n; i++)
      rings[station][i] = PVector.lerp(opening.ringWorld.get(i),
        target.get(i), blend);
  }
  // Station 0 is the opening perimeter itself, not an approximation of it.
  for (int i = 0; i < n; i++) rings[0][i] = opening.ringWorld.get(i).copy();

  int faceId = 0;
  for (int station = 0; station < model.bays; station++)
    for (int side = 0; side < n; side++) {
      int next = (side + 1) % n;
      PVector a = rings[station][side];
      PVector b = rings[station][next];
      PVector c = rings[station + 1][next];
      PVector d = rings[station + 1][side];
      int before = model.frameFaces.size();
      if (trussDiagonalFoldsOutward(model, a, b, c, d)) {
        trussAddFrameFace(model, faceId++, a, b, c);
        trussAddFrameFace(model, faceId++, a, c, d);
      } else {
        trussAddFrameFace(model, faceId++, b, c, d);
        trussAddFrameFace(model, faceId++, b, d, a);
      }
      // The ring against the dome is the gate truss: it carries what the
      // opening interrupted.
      if (station == 0)
        for (int f = before; f < model.frameFaces.size(); f++)
          model.frameFaces.get(f).gateTruss = true;
    }

  trussResolveFrameJoints(model);
  trussFabricateFrameFaces(model);
  for (SurfaceMesh typeMesh : model.frameTypes.values())
    model.sealedComponents.add(typeMesh);

  for (TrussFrameFace face : model.frameFaces) {
    if (face.gateTruss) result.gatePanels++;
    else result.collarPanels++;
  }

  // Measured, not asserted: how far the built dome-side ring sits from the
  // opening perimeter it is supposed to land on.
  result.maximumNodeOffsetMM = 0;
  for (int i = 0; i < n; i++) {
    PVector wanted = opening.ringWorld.get(i);
    float nearest = Float.MAX_VALUE;
    for (TrussFrameFace face : model.frameFaces)
      for (int k = 0; k < 3; k++)
        nearest = min(nearest, PVector.dist(face.world[k], wanted));
    result.maximumNodeOffsetMM = max(result.maximumNodeOffsetMM, nearest);
  }

  result.railWidthMM = model.frameWidthMM;
  result.railDepthMM = model.frameDepthMM;
  result.terminalRadiusMM = radius;
  result.built = model.frameFaces.size() > 0 && model.frameTypes.size() > 0;
  result.status = result.built ?
    "CONNECTOR / " + result.section + " " + n + "-node / offset " +
      nf(result.maximumNodeOffsetMM, 1, 4) + " mm" :
    "connector produced no panels";
  return model;
}

/* Fabrication settings for the reinforced gate ring: wider rails, identical
   depth so the shared miter with the next ring still mates. */
GeodesicFabricationSettings trussGateFabricationSettings(
  GeodesicFabricationSettings base, float apothemLimit) {
  GeodesicFabricationSettings gate = base.copy();
  gate.frameWidthMM = min(base.frameWidthMM * max(1.0f, trussGateRailScale),
    max(base.frameWidthMM, apothemLimit));
  gate.frameDepthMM = base.frameDepthMM;
  gate.requestedFrameDepthMM = base.requestedFrameDepthMM;
  gate.miterDepthLimitMM = base.miterDepthLimitMM;
  return gate;
}
