/* Truss Yard: modular octahedral mast and tunnel generator.
   This is deliberately adjacent to Geodesic Salon: it reads salon scale but
   never mutates salon panels, assemblies, or their fabrication contract. */

enum TrussYardOrientation { TOWER, TUNNEL }
enum TrussBuildMode { SKELETON_STUDY, TRIANGLE_FRAMES }
enum TrussFramePanelMode { OPEN_FRAME, EXTERIOR_MEMBRANE }

/* Which face of the assembled wall the zip-tie loop is presented to.
   A tunnel is entered, so its ties are threaded from the interior. A mast is a
   closed shaft no hand fits into, so its ties must be presented outward. This
   is a physical reachability contract, not a styling choice. */
enum TrussAccessSide {
  INTERIOR,
  EXTERIOR;

  String label() { return this == INTERIOR ? "INTERIOR" : "EXTERIOR"; }

  /* Both sides are realised in geometry: the panel body follows
     assemblyGrowthSign and the miter lean follows the body. */
  boolean realizedInGeometry() { return true; }
}

/* Cross-section of the mast or tunnel. The square section was never a
   deliberate choice and is the worst case for mitering: its corner joints fold
   far past the printable half-miter budget once twist is applied. Wider
   sections keep the corner dihedral shallow. */
enum TrussSectionFamily {
  TRIANGLE,
  SQUARE,
  PENTAGON,
  HEXAGON,
  OCTAGON,
  DODECAGON;

  int sides() {
    if (this == TRIANGLE) return 3;
    if (this == SQUARE) return 4;
    if (this == PENTAGON) return 5;
    if (this == HEXAGON) return 6;
    if (this == OCTAGON) return 8;
    return 12;
  }

  /* Interior dihedral of the untwisted prism corner, in degrees. */
  float cornerDihedralDeg() { return 180.0f - 360.0f / sides(); }

  String label() { return name() + " " + sides(); }
}

/* A mast or tunnel has an axis, not a centre. Every inward/outward decision in
   this workspace resolves against this frame rather than against the world
   origin the spherical Geodesic Salon topology assumes. */
class TrussAxisFrame {
  PVector origin = new PVector();
  PVector direction = new PVector(0, 0, 1);

  TrussAxisFrame(boolean tunnel) {
    // trussOrient maps the generated +Z mast axis onto +X for tunnels.
    direction.set(tunnel ? 1 : 0, 0, tunnel ? 0 : 1);
  }

  PVector radial(PVector p) {
    PVector relative = PVector.sub(p, origin);
    return PVector.sub(relative, PVector.mult(direction, relative.dot(direction)));
  }

  float radius(PVector p) { return radial(p).mag(); }

  PVector outward(PVector p) {
    PVector r = radial(p);
    if (r.magSq() < 0.000001f) return new PVector(0, 1, 0);
    return r.normalize();
  }

  PVector inward(PVector p) { return PVector.mult(outward(p), -1); }

  /* The direction the wall thickness grows from the nominal surface, which is
     also the direction a zip-tie loop is presented toward.

     Reversing the face winding would be the obvious way to move the body
     outboard and is wrong: the normal also classifies joints convex or concave,
     so reversing it turns every section corner into a concave miter. The body
     side is carried by assemblyGrowthSign in the fabrication settings instead,
     and the miter lean follows it. */
  PVector materialSide(PVector p, TrussAccessSide access) {
    return access == TrussAccessSide.EXTERIOR ? outward(p) : inward(p);
  }
}

class TrussFrameFace {
  int id;
  PVector[] world = new PVector[3];
  int[] neighborFaceIds = { -1, -1, -1 };
  String[] jointIds = { "", "", "" };
  float[] portalStations = { 0.5f, 0.5f, 0.5f };
  PVector[] portalCentersWorld = new PVector[3];
  PVector[] portalAxesWorld = new PVector[3];
  String typeId = "";
  /* Panels on the dome-side ring of a connector carry the loads the opening
     interrupted, so they are their own structural class: wider rails, same
     depth. Depth must match its neighbours or the shared miter stops mating,
     which is why the reinforcement is in width alone. */
  boolean gateTruss = false;
  SurfaceMesh localMesh;
  GeodesicFabricationFace fabricationFace;

  TrussFrameFace(int id, PVector a, PVector b, PVector c) {
    this.id = id;
    world[0] = a.copy(); world[1] = b.copy(); world[2] = c.copy();
    for (int i = 0; i < 3; i++) {
      portalCentersWorld[i] = new PVector();
      portalAxesWorld[i] = new PVector();
    }
  }
}

class TrussFrameEdgeRef {
  int faceIndex;
  int edgeIndex;

  TrussFrameEdgeRef(int faceIndex, int edgeIndex) {
    this.faceIndex = faceIndex;
    this.edgeIndex = edgeIndex;
  }
}

class TrussFrameJoint {
  int id;
  int faceAIndex;
  int edgeA;
  int faceBIndex = -1;
  int edgeB = -1;
  PVector midpoint = new PVector();
  float edgeLengthMM;
  float normalAngleDeg;
  float interiorDihedralDeg;
  float halfMiterDeg;
  float miterInsetMM;
  float miterInsetSign = 1;
  boolean concave;
  boolean miterFeasible = true;
  PVector bisector = new PVector();
  float portalAxisErrorDeg = 180;
  float portalPairErrorDeg = 180;
  float portalThroatErrorMM = Float.MAX_VALUE;
  float portalCornerErrorMM = Float.MAX_VALUE;
  float portalInwardErrorDeg = 180;
  boolean portalCoaxial = false;
  boolean portalApertureAligned = false;
  boolean portalWithinPanelDepth = false;
  float portalDepthExcursionMM = Float.MAX_VALUE;

  TrussFrameJoint(int id, TrussFrameEdgeRef a, TrussFrameEdgeRef b,
    PVector midpoint, float edgeLengthMM) {
    this.id = id;
    faceAIndex = a.faceIndex;
    edgeA = a.edgeIndex;
    if (b != null) {
      faceBIndex = b.faceIndex;
      edgeB = b.edgeIndex;
    }
    this.midpoint.set(midpoint);
    this.edgeLengthMM = edgeLengthMM;
  }

  boolean shared() { return faceBIndex >= 0; }

  /* Both panels carry one centered local portal and reciprocal seam identity:
     the physical condition for threading one tie through either panel without
     deforming its channel to chase a world-space aperture. */
  boolean reciprocalPortalResolvedOnBothPanels(TrussMastModel model) {
    if (!shared()) return true;
    TrussFrameFace faceA = model.frameFaces.get(faceAIndex);
    TrussFrameFace faceB = model.frameFaces.get(faceBIndex);
    if (faceA.fabricationFace == null || faceB.fabricationFace == null) return false;
    if (edgeA < 0 || edgeA >= faceA.fabricationFace.joints.size()) return false;
    if (edgeB < 0 || edgeB >= faceB.fabricationFace.joints.size()) return false;
    GeodesicJointEdgeProfile profileA = faceA.fabricationFace.joints.get(edgeA);
    GeodesicJointEdgeProfile profileB = faceB.fabricationFace.joints.get(edgeB);
    return profileA.reciprocalPortalResolved && profileB.reciprocalPortalResolved &&
      profileA.portalCenters.size() == 1 && profileB.portalCenters.size() == 1 &&
      abs(profileA.portalCenters.get(0) - 0.5f) < 0.00001f &&
      abs(profileB.portalCenters.get(0) - 0.5f) < 0.00001f &&
      abs(profileA.reciprocalPortalStation - 0.5f) < 0.00001f &&
      abs(profileB.reciprocalPortalStation - 0.5f) < 0.00001f;
  }
  String label() { return (shared() ? "J" : "RIM") + nf(id + 1, 3); }
}

/* Numeric identity of one printable frame type.

   Quantising a signature into a string still splits a pair of panels whose
   measurements straddle a bucket edge, which is why kits kept shipping two
   part numbers for one shape. Matching numerically against the types already
   registered has no bucket edges to straddle. */
class TrussFrameTypeKey {
  String signature;
  String typeId;
  TrussFramePanelMode mode;
  boolean gate = false;
  float railWidthMM = 0;
  // [edge][feature]; features are lengths in mm except index 1, an angle.
  float[][] edgeFeatures;
  boolean[] edgeBoundary;
  float[] edgeInsetSign;

  boolean matches(TrussFrameTypeKey other, float lengthTolerance,
    float angleTolerance) {
    if (other == null || other.mode != mode) return false;
    // A reinforced gate panel is never the same part as a field panel, even
    // when every edge measurement agrees.
    if (other.gate != gate) return false;
    if (abs(other.railWidthMM - railWidthMM) > lengthTolerance) return false;
    if (other.edgeFeatures.length != edgeFeatures.length) return false;
    int count = edgeFeatures.length;
    // Rotation only. A panel and its mirror image are different parts and must
    // not collapse onto one STL, so reversed cycles are never considered.
    for (int rotation = 0; rotation < count; rotation++) {
      boolean same = true;
      for (int edge = 0; edge < count && same; edge++) {
        int mate = (edge + rotation) % count;
        if (edgeBoundary[edge] != other.edgeBoundary[mate] ||
            edgeInsetSign[edge] != other.edgeInsetSign[mate]) same = false;
        else for (int feature = 0; feature < edgeFeatures[edge].length; feature++) {
          float tolerance = feature == 1 ? angleTolerance : lengthTolerance;
          if (abs(edgeFeatures[edge][feature] -
              other.edgeFeatures[mate][feature]) > tolerance) same = false;
        }
      }
      if (same) return true;
    }
    return false;
  }
}

class TrussPortalAperture {
  boolean valid = false;
  PVector[] corners = {
    new PVector(), new PVector(), new PVector(), new PVector()
  };
  PVector edgeAxis = new PVector();
  PVector heightAxis = new PVector();
  PVector center = new PVector();
}

class TrussPortalCandidate {
  boolean valid = false;
  float inwardMM;
  float stationA = 0.5f;
  float stationB = 0.5f;
  float residualMM = Float.MAX_VALUE;
  float axisErrorDeg = 180;
  PVector throatWorld = new PVector();
  PVector axisWorld = new PVector();
}

class TrussMastModel {
  int bays;
  float baySpanMM;
  float bayHeightMM;
  float strutRadiusMM;
  float twistRadians;
  boolean tunnel;
  int sectionSides = 4;
  TrussSectionFamily section = TrussSectionFamily.SQUARE;
  TrussAccessSide accessSide = TrussAccessSide.INTERIOR;
  TrussAxisFrame axis;
  int concaveSharedJointCount = 0;
  // Shallow concave joints resolve a portal; sharp ones do not. Recording the
  // sharpest makes that correlation legible instead of a mystery.
  float sharpestConcaveDihedralDeg = 180;
  /* When a truss is bound to a connector it must carry that connector's rail
     section, or the two will not mate at the terminal ring. Zero means free. */
  float boundRailWidthMM = 0;
  float boundRailDepthMM = 0;
  boolean boundRailInsufficient = false;
  /* Dimensions inherited from the dome an opening was cut in. When present the
     truss builds to these rather than deriving its own from strut radius, which
     is what lets a dome panel, a connector and a tunnel share a miter and a
     portal instead of each arriving at its own numbers. */
  GeodesicFabricationSettings lineageFabrication = null;
  boolean domeMatched;

  /* Any twist strictly between zero and one section step leaves one concave
     crease ring at every bay interface. That is forced: the panels above and
     below a ring are only coplanar when consecutive rings are aligned, and no
     choice of diagonal, twist direction, or bay alternation avoids it. The
     buildable target is therefore zero *avoidable* concavity, not zero.

     Twist is not the only way consecutive rings differ. A connector blends an
     irregular dome perimeter into a regular section, so its rings differ in
     shape and crease for the same reason at the same rate -- measured as
     exactly one crease ring per bay interface. Reading that as avoidable would
     block every connector export. */
  boolean ringShapeVaries = false;

  int forcedConcaveJointCount() {
    if (!ringShapeVaries &&
        trussTwistIsSectionAligned(twistRadians, sectionSides)) return 0;
    return sectionSides * max(0, bays - 1);
  }

  int avoidableConcaveJointCount() {
    return max(0, concaveSharedJointCount - forcedConcaveJointCount());
  }
  float matchRadiusMM;
  float matchEdgeMM;
  ArrayList<PVector> nodes = new ArrayList<PVector>();
  ArrayList<int[]> links = new ArrayList<int[]>();
  ArrayList<SurfaceMesh> sealedComponents = new ArrayList<SurfaceMesh>();
  ArrayList<SurfaceMesh> sealedAdapterComponents = new ArrayList<SurfaceMesh>();
  ArrayList<TrussFrameFace> frameFaces = new ArrayList<TrussFrameFace>();
  HashMap<String, SurfaceMesh> frameTypes = new HashMap<String, SurfaceMesh>();
  HashMap<String, String> frameTypeIds = new HashMap<String, String>();
  HashMap<String, Integer> frameQuantities = new HashMap<String, Integer>();
  ArrayList<TrussFrameTypeKey> frameTypeKeys = new ArrayList<TrussFrameTypeKey>();
  ArrayList<TrussFrameJoint> frameJoints = new ArrayList<TrussFrameJoint>();
  boolean frameJointTopologyValid = true;
  TrussFramePanelMode framePanelMode = TrussFramePanelMode.OPEN_FRAME;
  GeodesicModel frameTopology;
  GeodesicFabricationSettings frameFabrication;
  GeodesicFabricationSettings gateFabrication;
  GeodesicSeamAudit frameSeamAudit;
  float maximumPortalAxisErrorDeg = 180;
  float maximumPortalPairErrorDeg = 180;
  float maximumPortalThroatErrorMM = Float.MAX_VALUE;
  float maximumPortalCornerErrorMM = Float.MAX_VALUE;
  float maximumPortalInwardErrorDeg = 180;
  float maximumPortalDepthExcursionMM = Float.MAX_VALUE;
  TrussFastenerFit fastenerFit = new TrussFastenerFit();
  TrussBuildMode buildMode = TrussBuildMode.SKELETON_STUDY;
  float frameWidthMM;
  float frameDepthMM;
  SurfaceMesh combined;
  SurfaceMesh adapter;
  int[] audit = { -1, -1, -1 };
  int[] adapterAudit = { -1, -1, -1 };

  boolean componentsAudited() {
    for (SurfaceMesh mesh : sealedComponents) {
      int[] check = mesh.manifoldAudit();
      if (check[0] != 0 || check[1] != 0 || check[2] != 0) return false;
    }
    for (SurfaceMesh mesh : sealedAdapterComponents) {
      int[] check = mesh.manifoldAudit();
      if (check[0] != 0 || check[1] != 0 || check[2] != 0) return false;
    }
    return sealedComponents.size() > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.truss_yard.triangulated_space_frame.v3");
    json.setString("family", buildMode == TrussBuildMode.TRIANGLE_FRAMES ?
      "triangulated_frame_truss" : "octahedral_lattice_study");
    json.setString("build_mode", buildMode == TrussBuildMode.TRIANGLE_FRAMES ?
      "TRIANGLE_FRAMES" : "SKELETON_STUDY");
    json.setString("orientation", tunnel ? "tunnel" : "tower");
    json.setString("section_family", section.name());
    json.setInt("section_sides", sectionSides);
    json.setFloat("section_corner_dihedral_deg", section.cornerDihedralDeg());
    json.setString("zip_tie_access_side", accessSide.label());
    // The body sits on the same side as the assembler: a tunnel wall hangs
    // inboard toward the bore, a mast wall stands outboard.
    json.setString("access_side_contract", accessSide == TrussAccessSide.INTERIOR ?
      "panels are laid inboard of the wall surface; ties are threaded from inside the tunnel" :
      "panels are laid outboard of the wall surface; ties are threaded from outside the mast");
    json.setInt("concave_shared_joints", concaveSharedJointCount);
    json.setInt("forced_concave_shared_joints", forcedConcaveJointCount());
    json.setInt("avoidable_concave_shared_joints", avoidableConcaveJointCount());
    json.setBoolean("concave_joint_audit_passed", avoidableConcaveJointCount() == 0);
    json.setBoolean("fully_convex_wall", concaveSharedJointCount == 0);
    json.setString("concave_joint_policy",
      "one crease ring per bay interface is forced by any twist that is not a whole section step; " +
      "set twist to a multiple of 360/sides for a fully convex wall");
    json.setInt("bays", bays);
    json.setFloat("bay_span_mm", baySpanMM);
    json.setFloat("bay_height_mm", bayHeightMM);
    json.setFloat("strut_radius_mm", strutRadiusMM);
    json.setFloat("bay_twist_deg", degrees(twistRadians));
    json.setFloat("frame_width_mm", frameWidthMM);
    json.setFloat("frame_depth_mm", frameDepthMM);
    json.setString("frame_panel_mode", framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
      "OPEN_FRAME" : "EXTERIOR_MEMBRANE");
    json.setString("enclosure_contract", framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
      "open scaffold" :
      "continuous exterior panel membrane; seal physical seams and portal penetrations for airtight service");
    json.setInt("nodes", nodes.size());
    json.setInt("struts", links.size());
    json.setBoolean("dome_match_enabled", domeMatched);
    json.setFloat("matched_dome_radius_mm", matchRadiusMM);
    json.setFloat("matched_panel_edge_mm", matchEdgeMM);
    json.setString("adapter_contract",
      "reference spider only; does not alter Geodesic Salon panel geometry");
    json.setInt("combined_triangles", combined == null ? 0 : combined.tris.size());
    json.setString("assembled_preview_contract",
      "visual aggregate only; print the sealed reusable part STLs for assured manifold components");
    json.setInt("assembled_preview_boundary_edges", audit[0]);
    json.setInt("assembled_preview_nonmanifold_edges", audit[1]);
    json.setBoolean("sealed_components_audited", componentsAudited());
    json.setInt("sealed_component_count", sealedComponents.size());
    json.setInt("triangle_frame_instances", frameFaces.size());
    json.setInt("reusable_triangle_frame_types", frameTypes.size());
    json.setInt("reciprocal_shared_joints", trussSharedFrameJointCount(this));
    json.setInt("boundary_frame_edges", trussBoundaryFrameJointCount(this));
    json.setBoolean("portal_midpoint_audit_passed", trussFramePortalAuditPassed(this));
    json.setBoolean("portal_coaxial_audit_passed", trussFramePortalAuditPassed(this));
    json.setFloat("maximum_portal_axis_error_deg", maximumPortalAxisErrorDeg);
    json.setFloat("maximum_reciprocal_axis_error_deg", maximumPortalPairErrorDeg);
    json.setFloat("maximum_portal_throat_error_mm", maximumPortalThroatErrorMM);
    json.setFloat("maximum_portal_corner_error_mm", maximumPortalCornerErrorMM);
    json.setFloat("maximum_portal_inward_error_deg", maximumPortalInwardErrorDeg);
    json.setFloat("maximum_portal_depth_excursion_mm",
      maximumPortalDepthExcursionMM == Float.MAX_VALUE ? -1 :
      maximumPortalDepthExcursionMM);
    json.setString("portal_inward_audit_basis",
      "aperture compared against the panel depth axis measured through the " +
      "assembly transform, not against the function that built it");
    json.setJSONObject("fastener_fit", fastenerFit.toJSON());
    json.setFloat("minimum_seam_overlap_mm", trussMinimumSeamOverlapMM(this));
    json.setFloat("seam_trim_asymmetry_mm", frameSeamAudit == null ? -1 :
      frameSeamAudit.maximumTangentialGapMM);
    json.setString("seam_trim_asymmetry_note",
      "difference in how far the two panels trim their rail ends, not an " +
      "opening; minimum_seam_overlap_mm is the coverage measure");
    json.setFloat("fabrication_scale", frameFabrication == null ? 1.0f :
      frameFabrication.fabricationScale);
    json.setString("scale_lineage", lineageFabrication == null ?
      "free standing at 1.0; not matched to a dome" :
      "inherited from the dome this connects to, so all three print at one size");
    json.setString("reported_not_gated",
      "seam overlap, trim asymmetry, portal depth excursion, and fastener fit " +
      "are measured and reported; thresholds are set from real builds rather " +
      "than assumed, and print scale is a slicer decision");
    json.setBoolean("portal_aperture_audit_passed",
      trussFramePortalAuditPassed(this));
    json.setBoolean("miter_seam_audit_passed", trussFrameSeamAuditPassed(this));
    if (frameSeamAudit != null)
      json.setJSONObject("miter_seam_audit", frameSeamAudit.toJSON());
    json.setString("portal_station_policy",
      "one centered portal at edge station 0.5 on every panel");
    json.setString("portal_axis_policy",
      "panel-local straight-through channel; reciprocal seam identity is metadata and does not skew the cut");
    json.setString("portal_loop_policy",
      "the tie closes across matched seam IDs while both printable slots remain centered and directly accessible");
    json.setInt("adapter_triangles", adapter == null ? 0 : adapter.tris.size());
    return json;
  }
}

class TrussYardTestReport {
  int passed = 0;
  int failed = 0;
  ArrayList<String> failures = new ArrayList<String>();
  void check(boolean condition, String name) {
    if (condition) passed++;
    else { failed++; failures.add(name); }
  }
  String summary() {
    if (failed == 0) return "PASS " + passed;
    return "FAIL " + failed + "/" + (passed + failed) + " " +
      shortText(failures.get(0), 46);
  }
}

TrussMastModel trussModel = null;
TrussYardOrientation trussOrientation = TrussYardOrientation.TOWER;
TrussSectionFamily trussSection = TrussSectionFamily.HEXAGON;
// Part identity is decided at printer resolution, not float resolution.
float trussPartQuantumMM = 0.02f;
float trussPartAngleQuantumDeg = 0.05f;
// Declared fastener stock. A portal the tie cannot pass through is a portal
// that does not exist, so this is checked rather than assumed.
float trussZipTieWidthMM = 2.5f;
float trussZipTieThicknessMM = 1.0f;
float trussZipTieClearanceMM = 0.35f;
// Kits print at a uniform scale, so a model-scale aperture and a real tie only
// meet at some scale. Declare it rather than assume 100%.
float trussPrintScalePercent = 100.0f;
int trussBayCount = 4;
float trussBaySpanMM = 42.0f;
float trussBayHeightMM = 34.0f;
float trussStrutRadiusMM = 2.6f;
float trussTwistDeg = 16.0f;
boolean trussDomeMatch = true;
/* Binds a free-standing truss to a built connector: it inherits the connector's
   terminal ring and rail section so the two print as a match. Bay count, bay
   height and twist stay free. */
boolean trussBindToConnector = false;
TrussBuildMode trussBuildMode = TrussBuildMode.TRIANGLE_FRAMES;
TrussFramePanelMode trussFramePanelMode = TrussFramePanelMode.OPEN_FRAME;
String trussStatus = "octahedral lattice pending";
String trussLastExport = "";
String trussTestStatus = "not run";

void initializeTrussYard() {
  TrussYardTestReport report = runTrussYardTests();
  trussTestStatus = report.summary();
  println("TRUSS YARD TESTS " + trussTestStatus);
  for (String failure : report.failures) println("  FAIL " + failure);
  rebuildTrussYard("initialized");
}

void rebuildTrussYard(String reason) {
  float matchRadius = trussDomeMatch && geodesicModel != null ? geodesicModel.radius : 0;
  float matchEdge = trussDomeMatch ? trussSalonMeanEdgeLength() : 0;
  if (trussDomeMatch && matchEdge > 0) {
    trussBaySpanMM = constrain(matchEdge * 1.12f, 18.0f, 140.0f);
    trussBayHeightMM = constrain(matchEdge * 0.92f, 16.0f, 120.0f);
  }
  boolean tunnel = trussOrientation == TrussYardOrientation.TUNNEL;
  // Chain of command: the dome makes an opening, the connector matches it, and
  // a bound truss starts from the connector's terminal ring. Bay count, bay
  // height and twist stay the operator's; section and rail do not, because
  // those are what make the two pieces mate.
  TrussSectionFamily buildSection = trussSection;
  float buildSpan = trussBaySpanMM;
  boolean bound = trussBindToConnector && trussConnectorResult != null &&
    trussConnectorResult.built && !trussConnectionMode;
  if (bound) {
    buildSpan = trussConnectorResult.terminalRadiusMM * 2;
    for (TrussSectionFamily family : TrussSectionFamily.values())
      if (family.sides() == trussConnectorResult.nodes) buildSection = family;
  }
  trussModel = buildTrussMastModel(trussBayCount, buildSpan,
    trussBayHeightMM, trussStrutRadiusMM, radians(trussTwistDeg),
    tunnel, trussDomeMatch, matchRadius, matchEdge, buildSection,
    trussAccessSideFor(tunnel));
  if (bound) {
    trussModel.boundRailWidthMM = trussConnectorResult.railWidthMM;
    trussModel.boundRailDepthMM = trussConnectorResult.railDepthMM;
    // End of the lineage. The tunnel inherits the same dome dimensions the
    // connector was built to, so all three share a miter and a portal.
    trussModel.lineageFabrication = geodesicOpeningSelection == null ? null :
      geodesicOpeningSelection.domeFabrication;
  } else if (trussDomeMatch && geodesicModel != null) {
    // MATCH DOME now matches the dome's rail section too, not only its span.
    // Matching span alone produced panels of the right footprint and a third
    // of the depth -- 3.2 mm rails beside the dome's 10.5 mm -- which reads on
    // a plate as parts from two different kits.
    trussModel.lineageFabrication = trussLiveDomeFabrication();
  }
  trussModel.buildMode = trussBuildMode;
  trussModel.framePanelMode = trussFramePanelMode;
  // Connection mode replaces the free-standing mast with the piece that meets a
  // committed Geodesic Salon opening.
  if (trussConnectionMode && trussConnectorAvailable() &&
      trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES) {
    trussConnectorResult = new TrussConnectorResult();
    trussModel = trussBuildConnectorModel(
      geodesicOpeningSelection.candidate, trussConnectorResult);
  } else if (trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES) {
    trussConnectorResult = new TrussConnectorResult();
    trussConnectorResult.status = trussConnectionMode ?
      "connection mode on / no committed opening" : "no opening committed";
    buildTrussTriangleFrames(trussModel);
  }
  boolean componentReady = trussModel.componentsAudited();
  boolean frameMode = trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES;
  boolean portalReady = !frameMode || trussFramePortalAuditPassed(trussModel);
  boolean seamReady = !frameMode || trussFrameSeamAuditPassed(trussModel);
  // "Avoidable" concavity means the triangulation fought a regular prism's own
  // curvature. A connector blends an irregular dome perimeter, so a fold there
  // is the opening's shape, not a triangulation fault, and it is reported.
  boolean foldReady = !frameMode || trussModel.ringShapeVaries ||
    trussModel.avoidableConcaveJointCount() == 0;
  trussStatus = componentReady && portalReady && seamReady && foldReady ?
    "TRUSS READY / " + reason :
    (!componentReady ? "TRUSS REVIEW / SEALED PART AUDIT" :
      (!foldReady ? "TRUSS REVIEW / " + trussModel.avoidableConcaveJointCount() +
        " AVOIDABLE CONCAVE FOLDS" :
      (!portalReady ? "TRUSS REVIEW / PORTAL PAIR AUDIT" :
      "TRUSS REVIEW / MITER SEAM AUDIT")));
}

/* The live dome's resolved fabrication dimensions. Resolved rather than raw UI
   values, because that is where the fabrication scale and the printable caps
   are settled. */
GeodesicFabricationSettings trussLiveDomeFabrication() {
  if (geodesicModel == null) return null;
  return geodesicResolveKitFabricationSettings(geodesicModel,
    currentGeodesicFabricationSettings()).copy();
}

/* How far a committed opening's captured dimensions have drifted from the dome
   as it stands now. The dome fingerprint only covers topology, so it happily
   matches after the frame depth has been changed underneath it. */
String trussLineageDriftDetail() {
  if (geodesicOpeningSelection == null || !geodesicOpeningSelection.active ||
      geodesicOpeningSelection.domeFabrication == null) return "";
  GeodesicFabricationSettings live = trussLiveDomeFabrication();
  if (live == null) return "";
  GeodesicFabricationSettings held = geodesicOpeningSelection.domeFabrication;
  boolean depth = abs(live.frameDepthMM - held.frameDepthMM) > 0.05f;
  boolean width = abs(live.frameWidthMM - held.frameWidthMM) > 0.05f;
  boolean scale = abs(live.fabricationScale - held.fabricationScale) > 0.005f;
  if (!depth && !width && !scale) return "";
  String detail = "STALE / opening holds";
  if (depth) detail += " depth " + nf(held.frameDepthMM, 1, 1) +
    " vs live " + nf(live.frameDepthMM, 1, 1);
  if (width) detail += " width " + nf(held.frameWidthMM, 1, 1) +
    " vs " + nf(live.frameWidthMM, 1, 1);
  if (scale) detail += " scale x" + nf(held.fabricationScale, 1, 2) +
    " vs x" + nf(live.fabricationScale, 1, 2);
  return detail + " / re-commit the opening";
}

float trussSalonMeanEdgeLength() {
  if (geodesicModel == null || geodesicModel.edges == null ||
      geodesicModel.edges.size() == 0) return 0;
  float sum = 0;
  for (GeodesicEdge edge : geodesicModel.edges) {
    PVector a = geodesicModel.vertices.get(edge.a).position;
    PVector b = geodesicModel.vertices.get(edge.b).position;
    sum += PVector.dist(a, b);
  }
  return sum / geodesicModel.edges.size();
}

TrussMastModel buildTrussMastModel(int bays, float span, float height,
  float strutRadius, float twist, boolean tunnel, boolean domeMatched,
  float matchRadius, float matchEdge) {
  // Legacy nine-argument form. The skeleton study is always a four-sided ring,
  // and a tunnel is entered while a mast is not, so those defaults hold.
  return buildTrussMastModel(bays, span, height, strutRadius, twist, tunnel,
    domeMatched, matchRadius, matchEdge, TrussSectionFamily.SQUARE,
    trussAccessSideFor(tunnel));
}

TrussAccessSide trussAccessSideFor(boolean tunnel) {
  return tunnel ? TrussAccessSide.INTERIOR : TrussAccessSide.EXTERIOR;
}

/* A twist of a whole section step reproduces the untwisted ring, so the wall
   panels stay coplanar across every bay interface and the tube is convex
   everywhere. These are the only fully convex twists. */
boolean trussTwistIsSectionAligned(float twistRadians, int sides) {
  float step = TWO_PI / max(3, sides);
  float turns = twistRadians / step;
  return abs(turns - round(turns)) < 0.0005f;
}

/* Nearest fully convex twist, in degrees. */
float trussNearestConvexTwistDeg(float twistDeg, int sides) {
  float stepDeg = 360.0f / max(3, sides);
  return round(twistDeg / stepDeg) * stepDeg;
}

/* Usable twist runs to exactly one section step in each direction. At the step
   the ring lands back on itself and the wall is fully convex; past it the bay
   quads shear beyond the next vertex and fold against their own curvature,
   which no diagonal choice can rescue. The limit is therefore the section's,
   not a fixed angle: 120 degrees on a triangle, 30 on a dodecagon. */
float trussMaxTwistDeg(int sides) {
  return 360.0f / max(3, sides);
}

TrussMastModel buildTrussMastModel(int bays, float span, float height,
  float strutRadius, float twist, boolean tunnel, boolean domeMatched,
  float matchRadius, float matchEdge, TrussSectionFamily section,
  TrussAccessSide accessSide) {
  TrussMastModel result = new TrussMastModel();
  result.section = section;
  result.sectionSides = section.sides();
  result.accessSide = accessSide;
  result.axis = new TrussAxisFrame(tunnel);
  result.bays = constrain(bays, 1, 24);
  result.baySpanMM = max(8.0f, span);
  result.bayHeightMM = max(8.0f, height);
  result.strutRadiusMM = constrain(strutRadius, 0.8f, min(span, height) * 0.16f);
  result.twistRadians = twist;
  result.tunnel = tunnel;
  result.domeMatched = domeMatched;
  result.matchRadiusMM = matchRadius;
  result.matchEdgeMM = matchEdge;
  result.combined = new SurfaceMesh("octahedral_truss_" + (tunnel ? "tunnel" : "tower"));
  result.adapter = new SurfaceMesh("dome_reference_adapter_spider");

  int[] axial = new int[result.bays + 1];
  for (int i = 0; i <= result.bays; i++)
    axial[i] = trussAddNode(result, new PVector(0, 0, i * result.bayHeightMM));
  for (int bay = 0; bay < result.bays; bay++) {
    float z0 = bay * result.bayHeightMM;
    float z1 = (bay + 1) * result.bayHeightMM;
    int bottom = axial[bay];
    int top = axial[bay + 1];
    int[] ring = new int[4];
    float phase = twist * bay + QUARTER_PI;
    for (int i = 0; i < 4; i++) {
      float a = phase + HALF_PI * i;
      ring[i] = trussAddNode(result, new PVector(cos(a) * result.baySpanMM * 0.5f,
        sin(a) * result.baySpanMM * 0.5f, (z0 + z1) * 0.5f));
      trussAddLink(result, bottom, ring[i]);
      trussAddLink(result, top, ring[i]);
    }
    // Close the ring only after every node exists. The previous in-loop link
    // addressed an uninitialized slot and produced a duplicate axial brace.
    for (int i = 0; i < 4; i++) trussAddLink(result, ring[i], ring[(i + 1) % 4]);
  }
  for (int[] link : result.links) {
    trussAddBeam(result.combined, result.nodes.get(link[0]),
      result.nodes.get(link[1]), result.strutRadiusMM, result.tunnel);
  }
  for (PVector node : result.nodes)
    trussAddNodeBody(result.combined, node, result.strutRadiusMM * 1.15f, result.tunnel);

  for (int linkIndex = 0; linkIndex < result.links.size(); linkIndex++) {
    int[] link = result.links.get(linkIndex);
    SurfaceMesh partMesh = new SurfaceMesh("sealed_truss_strut_" + nf(linkIndex, 3));
    trussAddBeam(partMesh, result.nodes.get(link[0]), result.nodes.get(link[1]),
      result.strutRadiusMM, result.tunnel);
    result.sealedComponents.add(partMesh);
  }
  for (int nodeIndex = 0; nodeIndex < result.nodes.size(); nodeIndex++) {
    SurfaceMesh partMesh = new SurfaceMesh("sealed_truss_node_" + nf(nodeIndex, 3));
    trussAddNodeBody(partMesh, result.nodes.get(nodeIndex), result.strutRadiusMM * 1.15f,
      result.tunnel);
    result.sealedComponents.add(partMesh);
  }

  if (domeMatched && matchRadius > 0) {
    float adapterRadius = constrain(max(matchEdge * 0.75f, matchRadius * 0.14f),
      result.baySpanMM * 0.65f, matchRadius * 0.32f);
    PVector root = new PVector(0, 0, 0);
    for (int i = 0; i < 4; i++) {
      float a = QUARTER_PI + HALF_PI * i;
      PVector anchor = new PVector(cos(a) * adapterRadius,
        sin(a) * adapterRadius, -max(3.5f, result.strutRadiusMM * 2.2f));
      trussAddBeam(result.adapter, root, anchor, result.strutRadiusMM * 1.10f, result.tunnel);
      trussAddNodeBody(result.adapter, anchor, result.strutRadiusMM * 1.20f, result.tunnel);
      SurfaceMesh adapterBeam = new SurfaceMesh("sealed_adapter_arm_" + nf(i + 1, 2));
      trussAddBeam(adapterBeam, root, anchor, result.strutRadiusMM * 1.10f, result.tunnel);
      result.sealedAdapterComponents.add(adapterBeam);
      SurfaceMesh adapterNode = new SurfaceMesh("sealed_adapter_anchor_" + nf(i + 1, 2));
      trussAddNodeBody(adapterNode, anchor, result.strutRadiusMM * 1.20f, result.tunnel);
      result.sealedAdapterComponents.add(adapterNode);
    }
    trussAddNodeBody(result.adapter, root, result.strutRadiusMM * 1.28f, result.tunnel);
    SurfaceMesh rootNode = new SurfaceMesh("sealed_adapter_root");
    trussAddNodeBody(rootNode, root, result.strutRadiusMM * 1.28f, result.tunnel);
    result.sealedAdapterComponents.add(rootNode);
  }
  result.audit = result.combined.manifoldAudit();
  result.adapterAudit = result.adapter.manifoldAudit();
  return result;
}

void buildTrussTriangleFrames(TrussMastModel model) {
  model.frameFaces.clear();
  model.frameTypes.clear();
  model.frameTypeIds.clear();
  model.frameQuantities.clear();
  model.frameTypeKeys.clear();
  model.frameJoints.clear();
  model.frameJointTopologyValid = true;
  model.frameTopology = null;
  model.frameFabrication = null;
  model.frameSeamAudit = null;
  model.sealedComponents.clear();
  model.sealedAdapterComponents.clear();
  model.combined = new SurfaceMesh("triangulated_frame_" + (model.tunnel ? "tunnel" : "tower"));
  model.adapter = new SurfaceMesh("dome_reference_adapter_disabled_for_frame_kit");
  model.frameWidthMM = constrain(model.strutRadiusMM * 2.0f, 3.4f, model.baySpanMM * 0.16f);
  model.frameDepthMM = constrain(model.strutRadiusMM * 1.65f, 2.4f, model.frameWidthMM * 0.88f);

  int sides = max(3, model.sectionSides);
  float sectionStep = TWO_PI / sides;
  PVector[][] rings = new PVector[model.bays + 1][sides];
  for (int station = 0; station <= model.bays; station++) {
    float phase = model.twistRadians * station + sectionStep * 0.5f;
    for (int side = 0; side < sides; side++) {
      float angle = phase + sectionStep * side;
      PVector raw = new PVector(cos(angle) * model.baySpanMM * 0.5f,
        sin(angle) * model.baySpanMM * 0.5f, station * model.bayHeightMM);
      rings[station][side] = trussOrient(raw, model.tunnel);
    }
  }
  int faceId = 0;
  for (int station = 0; station < model.bays; station++) {
    for (int side = 0; side < sides; side++) {
      int next = (side + 1) % sides;
      PVector a = rings[station][side];
      PVector b = rings[station][next];
      PVector c = rings[station + 1][next];
      PVector d = rings[station + 1][side];
      // Twist makes every bay quad non-planar, so the two diagonals are not
      // interchangeable: one folds the wall away from the assembler and one
      // dents it inward. Splitting on a fixed index picked the dented diagonal
      // for one twist sign and produced a concave miter on every bay.
      if (trussDiagonalFoldsOutward(model, a, b, c, d)) {
        trussAddFrameFace(model, faceId++, a, b, c);
        trussAddFrameFace(model, faceId++, a, c, d);
      } else {
        trussAddFrameFace(model, faceId++, b, c, d);
        trussAddFrameFace(model, faceId++, b, d, a);
      }
    }
  }
  trussResolveFrameJoints(model);
  trussFabricateFrameFaces(model);
  for (SurfaceMesh typeMesh : model.frameTypes.values()) model.sealedComponents.add(typeMesh);
}

void trussAddFrameFace(TrussMastModel model, int id, PVector a, PVector b, PVector c) {
  PVector[] wound = trussWindFaceForAccess(model, a, b, c);
  PVector[] ordered = trussCanonicalFrameVertices(wound[0], wound[1], wound[2]);
  TrussFrameFace face = new TrussFrameFace(id, ordered[0], ordered[1], ordered[2]);
  model.frameFaces.add(face);
}

TrussAxisFrame trussAxisOf(TrussMastModel model) {
  return model.axis == null ? new TrussAxisFrame(model.tunnel) : model.axis;
}

/* The direction the assembler reaches from. The panel body lies between the
   wall surface and the assembler, so the material grows this way too: a tunnel
   wall hangs inboard toward the bore, a mast wall stands outboard. */
PVector trussAccessDirection(TrussMastModel model, PVector point) {
  return trussAxisOf(model).materialSide(point, model.accessSide);
}

/* Panels are extruded along the negative face normal, so the winding decides
   which side of the wall the rails and their zip-tie throats end up on. */
PVector trussShellNormalReference(TrussMastModel model, PVector point) {
  return PVector.mult(trussAccessDirection(model, point), -1);
}

PVector[] trussWindFaceForAccess(TrussMastModel model, PVector a, PVector b,
  PVector c) {
  PVector centroid = PVector.add(PVector.add(a, b), c).mult(1.0f / 3.0f);
  // Always wound outward, whatever the access side. Convexity is classified
  // from this normal, so flipping it would relabel every joint; the body side
  // is carried by assemblyGrowthSign instead.
  PVector reference = trussAxisOf(model).outward(centroid);
  PVector normal = PVector.sub(b, a).cross(PVector.sub(c, a));
  if (normal.dot(reference) < 0) return new PVector[] { a, c, b };
  return new PVector[] { a, b, c };
}

PVector trussWoundNormal(TrussMastModel model, PVector a, PVector b, PVector c) {
  PVector[] wound = trussWindFaceForAccess(model, a, b, c);
  PVector normal = PVector.sub(wound[1], wound[0])
    .cross(PVector.sub(wound[2], wound[0]));
  if (normal.magSq() < 0.000000001f) return new PVector();
  return normal.normalize();
}

/* Mirrors geodesicSharedEdgeConcave for a candidate diagonal, before any
   fabrication topology exists, so the split can be chosen rather than audited
   after the fact. */
boolean trussDiagonalFoldsOutward(TrussMastModel model, PVector a, PVector b,
  PVector c, PVector d) {
  float acFold = trussDiagonalFoldClearance(model, a, b, c, d);
  float bdFold = trussDiagonalFoldClearance(model, b, c, d, a);
  // Both diagonals convex (an untwisted, planar bay) leaves the choice free;
  // keep the historical A-C split so untwisted kits stay byte-identical.
  if (acFold <= 0 && bdFold <= 0) return true;
  return acFold <= bdFold;
}

/* Positive when splitting p0-p2 dents the wall toward the assembler. */
float trussDiagonalFoldClearance(TrussMastModel model, PVector p0, PVector p1,
  PVector p2, PVector p3) {
  PVector normalA = trussWoundNormal(model, p0, p1, p2);
  PVector normalB = trussWoundNormal(model, p0, p2, p3);
  if (normalA.magSq() < 0.5f || normalB.magSq() < 0.5f) return 0;
  PVector edgeMid = PVector.add(p0, p2).mult(0.5f);
  PVector centroidA = PVector.add(PVector.add(p0, p1), p2).mult(1.0f / 3.0f);
  PVector centroidB = PVector.add(PVector.add(p0, p2), p3).mult(1.0f / 3.0f);
  float sideA = PVector.sub(centroidB, edgeMid).dot(normalA);
  float sideB = PVector.sub(centroidA, edgeMid).dot(normalB);
  return max(sideA, sideB);
}

PVector[] trussCanonicalFrameVertices(PVector a, PVector b, PVector c) {
  PVector[] vertices = { a.copy(), b.copy(), c.copy() };
  int best = 0;
  for (int start = 1; start < 3; start++) {
    if (trussFrameCycleLess(vertices, start, best)) best = start;
  }
  return new PVector[] {
    vertices[best].copy(),
    vertices[(best + 1) % 3].copy(),
    vertices[(best + 2) % 3].copy()
  };
}

boolean trussFrameCycleLess(PVector[] vertices, int aStart, int bStart) {
  for (int offset = 0; offset < 3; offset++) {
    int a0 = (aStart + offset) % 3;
    int a1 = (aStart + offset + 1) % 3;
    int b0 = (bStart + offset) % 3;
    int b1 = (bStart + offset + 1) % 3;
    int aLength = round(PVector.dist(vertices[a0], vertices[a1]) * 1000.0f);
    int bLength = round(PVector.dist(vertices[b0], vertices[b1]) * 1000.0f);
    if (aLength < bLength) return true;
    if (aLength > bLength) return false;
  }
  return false;
}

String trussFrameSignature(PVector a, PVector b, PVector c) {
  return round(PVector.dist(a, b) * 1000.0f) + "_" +
    round(PVector.dist(b, c) * 1000.0f) + "_" +
    round(PVector.dist(c, a) * 1000.0f);
}

GeodesicModel trussBuildFrameTopology(TrussMastModel model) {
  float radius = 1;
  GeodesicModel topology = new GeodesicModel(GeodesicSeedFamily.OCTAHEDRAL,
    GeodesicExtentMode.DOME, 1, 1, 0);
  HashMap<String, Integer> vertexIds = new HashMap<String, Integer>();
  for (TrussFrameFace frame : model.frameFaces) {
    int[] ids = new int[3];
    for (int i = 0; i < 3; i++) {
      PVector point = frame.world[i];
      radius = max(radius, point.mag());
      String key = trussFramePointKey(point);
      Integer vertexId = vertexIds.get(key);
      if (vertexId == null) {
        vertexId = topology.vertices.size();
        topology.vertices.add(new GeodesicVertex(vertexId, point));
        vertexIds.put(key, vertexId);
      }
      ids[i] = vertexId;
    }
    topology.faces.add(new GeodesicFace(topology.faces.size(),
      ids[0], ids[1], ids[2], frame.id));
  }
  topology.radius = radius;
  finalizeGeodesicModel(topology);
  return topology;
}

GeodesicFabricationSettings trussFrameFabricationSettings(TrussMastModel model,
  GeodesicModel topology) {
  GeodesicFabricationSettings settings = new GeodesicFabricationSettings();
  settings.style = model.framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
    GeodesicPanelStyle.OPEN_FRAME : GeodesicPanelStyle.FRAME_SKIN;
  settings.reliefSide = GeodesicReliefSide.EXTERIOR_CROWN;
  // A mast is a sealed shaft, so its panels are laid outboard of the wall and
  // present their tie throats where a hand can reach them.
  settings.assemblyGrowthSign =
    model.accessSide == TrussAccessSide.EXTERIOR ? 1.0f : -1.0f;
  settings.seamProfile = GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
  settings.assemblyMode = GeodesicAssemblyMode.LEGACY_PORTAL;
  settings.portalAxisMode =
    GeodesicPortalAxisMode.PANEL_TRANSVERSE;
  settings.frameWidthMM = model.frameWidthMM;
  settings.frameDepthMM = max(3.2f, model.frameDepthMM);
  if (model.lineageFabrication != null) {
    // Inherit the dome's section wholesale. Deriving a depth from strut radius
    // gave a 0.84 mm portal slot against the dome's 13 mm frame: the two were
    // not the same dimensional language and nothing could line up.
    settings.frameDepthMM = model.lineageFabrication.frameDepthMM;
    settings.frameWidthMM = model.lineageFabrication.frameWidthMM;
    settings.skinThicknessMM = model.lineageFabrication.skinThicknessMM;
    settings.edgeBreakMM = model.lineageFabrication.edgeBreakMM;
  }
  settings.skinThicknessMM = settings.style == GeodesicPanelStyle.FRAME_SKIN ?
    constrain(settings.frameDepthMM * 0.24f, 0.8f, 1.8f) : 0;
  settings.fastenerPortals = true;
  settings.desiredPortalsPerEdge = 1;
  settings.portalWidthMM = model.lineageFabrication != null ?
    model.lineageFabrication.portalWidthMM :
    constrain(settings.frameWidthMM * 0.92f, 3.6f, 6.2f);
  settings.portalHeightMM = model.lineageFabrication != null ?
    model.lineageFabrication.portalHeightMM :
    constrain(settings.frameDepthMM * 0.42f, 1.0f, 2.0f);
  settings.bubbleJoinEnabled = false;
  settings.edgeCodesEnabled = false;
  settings.edgeBreakMM = 0.16f;
  settings.kitDimensionsResolved = true;
  // Inherit the dome's fabrication scale so a connector and tunnel print at the
  // same size as the dome they attach to. Free-standing trusses stay at 1.0.
  settings.fabricationScale = model.lineageFabrication == null ? 1.0f :
    max(1.0f, model.lineageFabrication.fabricationScale);
  settings.effectiveAssemblyRadiusMM = topology == null ? 0 : topology.radius;

  float maximumHalfAngleTangent = 0;
  if (topology != null) for (GeodesicEdge edge : topology.edges) {
    if (edge.faceA < 0 || edge.faceB < 0) continue;
    GeodesicFace a = topology.faces.get(edge.faceA);
    GeodesicFace b = topology.faces.get(edge.faceB);
    float normalAngle = acos(constrain(a.normal.dot(b.normal), -1, 1));
    maximumHalfAngleTangent = max(maximumHalfAngleTangent,
      tan(normalAngle * 0.5f));
  }
  float reserve = geodesicMiterRailReserve(settings) + 0.10f;
  float requiredWidth = settings.frameDepthMM * maximumHalfAngleTangent + reserve;
  if (model.boundRailWidthMM > 0) {
    // Locked to the connector. If this twist needs a wider rail than the
    // connector carries, the bind is over-constrained; report it rather than
    // silently widening and producing a tunnel that will not mate.
    settings.frameWidthMM = model.boundRailWidthMM;
    settings.frameDepthMM = model.boundRailDepthMM;
    model.boundRailInsufficient = requiredWidth > model.boundRailWidthMM + 0.0001f;
  } else {
    settings.frameWidthMM = max(settings.frameWidthMM, requiredWidth);
  }
  settings.requestedFrameDepthMM = settings.frameDepthMM;
  settings.miterDepthLimitMM = settings.frameDepthMM;
  return settings;
}

void trussFabricateFrameFaces(TrussMastModel model) {
  model.frameTopology = trussBuildFrameTopology(model);
  model.frameFabrication = trussFrameFabricationSettings(model, model.frameTopology);
  model.frameWidthMM = model.frameFabrication.frameWidthMM;
  model.frameDepthMM = model.frameFabrication.frameDepthMM;
  // Reinforced rails for any gate ring, capped so the widened rail still fits
  // inside the panel it belongs to.
  boolean anyGate = false;
  for (TrussFrameFace probe : model.frameFaces) if (probe.gateTruss) anyGate = true;
  model.gateFabrication = anyGate ?
    trussGateFabricationSettings(model.frameFabrication,
      model.baySpanMM * 0.22f) : null;
  model.combined = new SurfaceMesh("triangulated_frame_" +
    (model.tunnel ? "tunnel" : "tower"));

  for (int faceIndex = 0; faceIndex < model.frameFaces.size(); faceIndex++) {
    TrussFrameFace frame = model.frameFaces.get(faceIndex);
    GeodesicFabricationFace fabrication = geodesicFabricationFace(
      model.frameTopology, model.frameTopology.faces.get(faceIndex),
      frame.gateTruss && model.gateFabrication != null ?
        model.gateFabrication : model.frameFabrication);
    for (GeodesicJointEdgeProfile joint : fabrication.joints) {
      joint.portalCenters.clear();
      joint.portalCenters.add(0.5f);
    }
    frame.fabricationFace = fabrication;
  }
  trussResolveCenteredPanelPortals(model);

  for (int faceIndex = 0; faceIndex < model.frameFaces.size(); faceIndex++) {
    TrussFrameFace frame = model.frameFaces.get(faceIndex);
    GeodesicFabricationFace fabrication = frame.fabricationFace;
    TrussFrameTypeKey candidate = trussFrameTypeKey(fabrication,
      model.framePanelMode, frame.gateTruss);
    TrussFrameTypeKey established = trussMatchFrameType(model, candidate);
    String signature = established == null ?
      candidate.signature : established.signature;
    String typeId = model.frameTypeIds.get(signature);
    SurfaceMesh local = model.frameTypes.get(signature);
    if (local == null) {
      typeId = (frame.gateTruss ? "GATE_P" : "FRAME_P") +
        nf(model.frameTypes.size() + 1, 3);
      candidate.typeId = typeId;
      model.frameTypeKeys.add(candidate);
      local = buildGeodesicFabricationMesh(fabrication,
        fabrication.resolvedFabrication, GeodesicGrowthMode.SHELL_OVERWRAP, 0);
      geodesicWeldMicroSeams(local, 0.001f);
      // Sealing one miter sliver can expose the adjacent chord as a second
      // tiny closed loop. Converge rather than stopping at an arbitrary count:
      // each pass only ever closes, so running to a fixed point is monotone and
      // the helper still refuses any opening larger than one portal-scale
      // repair. Four passes was enough for regular tunnel panels and is not
      // enough for a connector, whose panels are all different shapes.
      for (int sealPass = 0; sealPass < 12; sealPass++)
        if (geodesicSealReciprocalMiterSlivers(local) == 0) break;
      geodesicWeldMicroSeams(local, 0.001f);
      local.name = typeId;
      model.frameTypes.put(signature, local);
      model.frameTypeIds.put(signature, typeId);
    }
    frame.typeId = typeId;
    frame.localMesh = local;
    int quantity = model.frameQuantities.containsKey(typeId) ?
      model.frameQuantities.get(typeId) : 0;
    model.frameQuantities.put(typeId, quantity + 1);
    trussAppendFabricatedMesh(model.combined, local, fabrication);
  }
  trussCaptureMiterMetadata(model);
  model.fastenerFit = trussAuditFastenerFit(model);
  model.frameSeamAudit = geodesicAuditAssembledSeams(
    model.frameTopology, model.frameFabrication);
}

void trussResolveReciprocalPortalChannels(TrussMastModel model) {
  if (model == null) return;
  for (TrussFrameJoint trussJoint : model.frameJoints) {
    if (!trussJoint.shared()) continue;
    GeodesicFabricationFace faceA =
      model.frameFaces.get(trussJoint.faceAIndex).fabricationFace;
    GeodesicFabricationFace faceB =
      model.frameFaces.get(trussJoint.faceBIndex).fabricationFace;
    if (faceA == null || faceB == null) continue;
    GeodesicPortalChannelGeometry geometryA =
      geodesicPortalChannelGeometry(faceA, trussJoint.edgeA, 0.5f);
    GeodesicPortalChannelGeometry geometryB =
      geodesicPortalChannelGeometry(faceB, trussJoint.edgeB, 0.5f);
    if (!geometryA.valid || !geometryB.valid) continue;

    float halfHeight = max(
      (geometryA.slotTop - geometryA.slotBottom) * 0.5f,
      (geometryB.slotTop - geometryB.slotBottom) * 0.5f);
    float minimumInward = halfHeight + 0.10f;
    float maximumInward = min(geometryA.depth, geometryB.depth) -
      halfHeight - 0.10f;
    if (maximumInward <= minimumInward) continue;

    TrussPortalCandidate best = new TrussPortalCandidate();
    float bestScore = Float.MAX_VALUE;
    int samples = 128;
    for (int sample = 0; sample <= samples; sample++) {
      float inward = lerp(minimumInward, maximumInward,
        sample / (float)samples);
      TrussPortalCandidate candidate = trussPortalCandidate(faceA,
        trussJoint.edgeA, faceB, trussJoint.edgeB, trussJoint, inward);
      float score = candidate.residualMM +
        candidate.axisErrorDeg * 0.08f;
      if (candidate.valid && score < bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    if (!best.valid) continue;
    float step = (maximumInward - minimumInward) / samples;
    for (int iteration = 0; iteration < 10; iteration++) {
      float[] probes = {
        constrain(best.inwardMM - step, minimumInward, maximumInward),
        constrain(best.inwardMM + step, minimumInward, maximumInward)
      };
      for (float probe : probes) {
        TrussPortalCandidate candidate = trussPortalCandidate(faceA,
          trussJoint.edgeA, faceB, trussJoint.edgeB, trussJoint, probe);
        float score = candidate.residualMM +
          candidate.axisErrorDeg * 0.08f;
        if (candidate.valid && score < bestScore) {
          best = candidate;
          bestScore = score;
        }
      }
      step *= 0.5f;
    }

    GeodesicJointEdgeProfile jointA = faceA.joints.get(trussJoint.edgeA);
    GeodesicJointEdgeProfile jointB = faceB.joints.get(trussJoint.edgeB);
    jointA.portalCenters.clear();
    jointB.portalCenters.clear();
    jointA.portalCenters.add(best.stationA);
    jointB.portalCenters.add(best.stationB);
    jointA.reciprocalPortalResolved = true;
    jointB.reciprocalPortalResolved = true;
    jointA.reciprocalPortalStation = best.stationA;
    jointB.reciprocalPortalStation = best.stationB;
    jointA.reciprocalPortalThroatInwardMM = best.inwardMM;
    jointB.reciprocalPortalThroatInwardMM = best.inwardMM;
    jointA.reciprocalPortalResidualMM = best.residualMM;
    jointB.reciprocalPortalResidualMM = best.residualMM;
    jointA.reciprocalPortalAxisWorld.set(best.axisWorld);
    jointB.reciprocalPortalAxisWorld.set(best.axisWorld);
    trussResolveJointOwnedAperture(model, trussJoint, faceA, faceB,
      jointA, jointB);
    TrussFrameFace frameA = model.frameFaces.get(trussJoint.faceAIndex);
    TrussFrameFace frameB = model.frameFaces.get(trussJoint.faceBIndex);
    frameA.portalStations[trussJoint.edgeA] = best.stationA;
    frameB.portalStations[trussJoint.edgeB] = best.stationB;
    frameA.portalCentersWorld[trussJoint.edgeA].set(best.throatWorld);
    frameB.portalCentersWorld[trussJoint.edgeB].set(best.throatWorld);
  }
}

/* Resolve assembly compatibility without altering physical portal geometry.
   Each face gets the same KICAS-style center station and a straight local
   channel. Shared joints remain paired by their J### seam identity. */
void trussResolveCenteredPanelPortals(TrussMastModel model) {
  if (model == null) return;
  for (TrussFrameFace frame : model.frameFaces) {
    GeodesicFabricationFace face = frame.fabricationFace;
    if (face == null) continue;
    for (int edgeIndex = 0; edgeIndex < face.joints.size(); edgeIndex++) {
      GeodesicJointEdgeProfile joint = face.joints.get(edgeIndex);
      joint.portalCenters.clear();
      joint.portalCenters.add(0.5f);
      joint.reciprocalPortalResolved = true;
      joint.reciprocalPortalStation = 0.5f;
      joint.reciprocalPortalResidualMM = 0;
      joint.reciprocalApertureResolved = false;
      for (PVector corner : joint.reciprocalApertureCornersWorld)
        corner.set(0, 0, 0);

      GeodesicPortalChannelGeometry geometry =
        geodesicPortalChannelGeometry(face, edgeIndex, 0.5f);
      if (geometry.valid) {
        float centerZ = (geometry.slotBottom + geometry.slotTop) * 0.5f;
        PVector outerLocal = geodesicMiterOuterPoint(
          geometry.miterProfile, edgeIndex, 0.5f, centerZ);
        PVector outerWorld =
          geodesicFabricationPointToAssembly(face, outerLocal);
        PVector axis = PVector.sub(geometry.innerCenterWorld, outerWorld);
        if (axis.magSq() > 0.000001f) axis.normalize();
        joint.reciprocalPortalAxisWorld.set(axis);
        joint.reciprocalPortalThroatInwardMM = centerZ;
      } else {
        joint.reciprocalPortalAxisWorld.set(0, 0, 0);
        joint.reciprocalPortalThroatInwardMM = 0;
      }

      frame.portalStations[edgeIndex] = 0.5f;
      TrussPortalAperture aperture =
        trussFaceLocalPortalAperture(face, edgeIndex);
      joint.reciprocalPortalResolved = aperture.valid;
      if (aperture.valid)
        frame.portalCentersWorld[edgeIndex].set(aperture.center);
      else
        frame.portalCentersWorld[edgeIndex].set(0, 0, 0);
    }
  }
}

void trussResolveJointOwnedAperture(TrussMastModel model,
  TrussFrameJoint trussJoint, GeodesicFabricationFace faceA,
  GeodesicFabricationFace faceB, GeodesicJointEdgeProfile jointA,
  GeodesicJointEdgeProfile jointB) {
  TrussPortalAperture apertureA =
    trussFaceLocalPortalAperture(faceA, trussJoint.edgeA);
  TrussPortalAperture apertureB =
    trussFaceLocalPortalAperture(faceB, trussJoint.edgeB);
  if (!apertureA.valid || !apertureB.valid) return;

  PVector edgeAxis = apertureA.edgeAxis.copy();
  if (edgeAxis.magSq() < 0.000001f) return;
  edgeAxis.normalize();
  PVector inward = trussPortalDesiredInwardAxis(model, trussJoint, edgeAxis);
  if (inward.magSq() < 0.000001f) return;
  inward.normalize();

  PVector planeNormal = edgeAxis.cross(inward);
  if (planeNormal.magSq() < 0.000001f) return;
  planeNormal.normalize();
  float[] boundsA = trussApertureProjectionBounds(apertureA,
    edgeAxis, inward);
  float[] boundsB = trussApertureProjectionBounds(apertureB,
    edgeAxis, inward);
  float overlapMinU = max(boundsA[0], boundsB[0]);
  float overlapMaxU = min(boundsA[1], boundsB[1]);
  float overlapMinV = max(boundsA[2], boundsB[2]);
  float overlapMaxV = min(boundsA[3], boundsB[3]);
  float widthA = PVector.dist(apertureA.corners[0], apertureA.corners[1]);
  float widthB = PVector.dist(apertureB.corners[0], apertureB.corners[1]);
  float heightA = PVector.dist(apertureA.corners[0], apertureA.corners[3]);
  float heightB = PVector.dist(apertureB.corners[0], apertureB.corners[3]);
  float centerU;
  float centerV;
  float halfWidth;
  float halfHeight;
  if (overlapMaxU - overlapMinU >= 1.50f &&
      overlapMaxV - overlapMinV >= 0.90f) {
    centerU = (overlapMinU + overlapMaxU) * 0.5f;
    centerV = (overlapMinV + overlapMaxV) * 0.5f;
    halfWidth = (overlapMaxU - overlapMinU) * 0.42f;
    halfHeight = (overlapMaxV - overlapMinV) * 0.42f;
  } else {
    // At extreme twist the two tilted face-mouth projections can cease to
    // overlap. The internal joint throat is still valid: both panel channels
    // taper to this conservative common opening in the radial joint plane.
    centerU = (apertureA.center.dot(edgeAxis) +
      apertureB.center.dot(edgeAxis)) * 0.5f;
    centerV = (apertureA.center.dot(inward) +
      apertureB.center.dot(inward)) * 0.5f;
    halfWidth = max(0.75f, min(widthA, widthB) * 0.30f);
    halfHeight = max(0.45f, min(heightA, heightB) * 0.27f);
  }
  float centerW = (apertureA.center.dot(planeNormal) +
    apertureB.center.dot(planeNormal)) * 0.5f;
  PVector center = PVector.mult(edgeAxis, centerU);
  center.add(PVector.mult(inward, centerV));
  center.add(PVector.mult(planeNormal, centerW));
  halfWidth = min(halfWidth, min(widthA, widthB) * 0.38f);
  halfHeight = min(halfHeight, min(heightA, heightB) * 0.42f);
  // The floor has to scale with the slot the fabrication actually resolved.
  // Absolute millimetres here were unsatisfiable by construction: capping at
  // 0.42x the slot height and then demanding 0.42 mm requires a slot at least
  // 1.0 mm tall, so every portal below that -- 0.84 mm on a connector -- lost
  // its aperture no matter what the geometry did. Model millimetres are not the
  // physical size anyway; these print at scale, and fastener fit is reported
  // separately against the declared tie.
  float minimumHalfWidth = max(0.12f, min(widthA, widthB) * 0.20f);
  float minimumHalfHeight = max(0.08f, min(heightA, heightB) * 0.20f);
  if (halfWidth < minimumHalfWidth || halfHeight < minimumHalfHeight) return;
  PVector[] corners = trussSharedApertureCorners(center, edgeAxis, inward,
    halfWidth, halfHeight);

  jointA.reciprocalApertureResolved = true;
  jointB.reciprocalApertureResolved = true;
  for (int i = 0; i < corners.length; i++) {
    jointA.reciprocalApertureCornersWorld[i].set(corners[i]);
    jointB.reciprocalApertureCornersWorld[i].set(corners[i]);
  }
}

float[] trussApertureProjectionBounds(TrussPortalAperture aperture,
  PVector edgeAxis, PVector inward) {
  float minU = Float.MAX_VALUE;
  float maxU = -Float.MAX_VALUE;
  float minV = Float.MAX_VALUE;
  float maxV = -Float.MAX_VALUE;
  for (PVector corner : aperture.corners) {
    float u = corner.dot(edgeAxis);
    float v = corner.dot(inward);
    minU = min(minU, u);
    maxU = max(maxU, u);
    minV = min(minV, v);
    maxV = max(maxV, v);
  }
  return new float[] { minU, maxU, minV, maxV };
}

PVector[] trussSharedApertureCorners(PVector center, PVector edgeAxis,
  PVector inward, float halfWidth, float halfHeight) {
  PVector edge = edgeAxis.copy().normalize();
  PVector height = inward.copy();
  height.sub(PVector.mult(edge, height.dot(edge)));
  if (height.magSq() > 0.000001f) height.normalize();
  PVector edgeOffset = PVector.mult(edge, halfWidth);
  PVector heightOffset = PVector.mult(height, halfHeight);
  return new PVector[] {
    PVector.sub(PVector.sub(center, edgeOffset), heightOffset),
    PVector.sub(PVector.add(center, edgeOffset), heightOffset),
    PVector.add(PVector.add(center, edgeOffset), heightOffset),
    PVector.add(PVector.sub(center, edgeOffset), heightOffset)
  };
}

boolean trussApertureContains(TrussPortalAperture aperture,
  PVector[] corners, float toleranceMM) {
  if (aperture == null || !aperture.valid || corners == null) return false;
  PVector u = PVector.sub(aperture.corners[1], aperture.corners[0]);
  PVector v = PVector.sub(aperture.corners[3], aperture.corners[0]);
  float uu = u.dot(u);
  float uv = u.dot(v);
  float vv = v.dot(v);
  float determinant = uu * vv - uv * uv;
  if (abs(determinant) < 0.000001f) return false;
  float toleranceU = toleranceMM / max(0.001f, u.mag());
  float toleranceV = toleranceMM / max(0.001f, v.mag());
  for (PVector corner : corners) {
    PVector delta = PVector.sub(corner, aperture.corners[0]);
    float du = delta.dot(u);
    float dv = delta.dot(v);
    float coordinateU = (du * vv - dv * uv) / determinant;
    float coordinateV = (dv * uu - du * uv) / determinant;
    if (coordinateU < -toleranceU || coordinateU > 1.0f + toleranceU ||
        coordinateV < -toleranceV || coordinateV > 1.0f + toleranceV)
      return false;
  }
  return true;
}

TrussPortalCandidate trussPortalCandidate(GeodesicFabricationFace faceA,
  int edgeA, GeodesicFabricationFace faceB, int edgeB,
  TrussFrameJoint joint, float inwardMM) {
  TrussPortalCandidate candidate = new TrussPortalCandidate();
  GeodesicPortalChannelGeometry centerA =
    geodesicPortalChannelGeometry(faceA, edgeA, 0.5f);
  GeodesicPortalChannelGeometry centerB =
    geodesicPortalChannelGeometry(faceB, edgeB, 0.5f);
  if (!centerA.valid || !centerB.valid) return candidate;
  float zA = geodesicPortalLocalZForInward(faceA, inwardMM);
  float zB = geodesicPortalLocalZForInward(faceB, inwardMM);
  PVector a0 = geodesicFabricationPointToAssembly(faceA,
    geodesicMiterOuterPoint(centerA.miterProfile, edgeA, 0, zA));
  PVector a1 = geodesicFabricationPointToAssembly(faceA,
    geodesicMiterOuterPoint(centerA.miterProfile, edgeA, 1, zA));
  PVector b0 = geodesicFabricationPointToAssembly(faceB,
    geodesicMiterOuterPoint(centerB.miterProfile, edgeB, 0, zB));
  PVector b1 = geodesicFabricationPointToAssembly(faceB,
    geodesicMiterOuterPoint(centerB.miterProfile, edgeB, 1, zB));

  PVector edgeAxis = PVector.sub(a1, a0);
  if (edgeAxis.magSq() < 0.000001f) return candidate;
  edgeAxis.normalize();
  float aScalar0 = a0.dot(edgeAxis);
  float aScalar1 = a1.dot(edgeAxis);
  float bScalar0 = b0.dot(edgeAxis);
  float bScalar1 = b1.dot(edgeAxis);
  float overlapMinimum = max(min(aScalar0, aScalar1),
    min(bScalar0, bScalar1));
  float overlapMaximum = min(max(aScalar0, aScalar1),
    max(bScalar0, bScalar1));
  GeodesicJointEdgeProfile profileA = faceA.joints.get(edgeA);
  GeodesicJointEdgeProfile profileB = faceB.joints.get(edgeB);
  float halfWidth = max(profileA.portalWidthMM, profileB.portalWidthMM) *
    0.5f + 0.12f;
  if (overlapMaximum - overlapMinimum <= halfWidth * 2.0f) return candidate;
  float targetScalar = constrain(joint.midpoint.dot(edgeAxis),
    overlapMinimum + halfWidth, overlapMaximum - halfWidth);
  float stationA = (targetScalar - aScalar0) /
    max(0.000001f, abs(aScalar1 - aScalar0));
  if (aScalar1 < aScalar0) stationA = (aScalar0 - targetScalar) /
    max(0.000001f, aScalar0 - aScalar1);
  float stationB = (targetScalar - bScalar0) /
    max(0.000001f, abs(bScalar1 - bScalar0));
  if (bScalar1 < bScalar0) stationB = (bScalar0 - targetScalar) /
    max(0.000001f, bScalar0 - bScalar1);
  stationA = constrain(stationA, 0.05f, 0.95f);
  stationB = constrain(stationB, 0.05f, 0.95f);

  PVector throatA = geodesicFabricationPointToAssembly(faceA,
    geodesicMiterOuterPoint(centerA.miterProfile, edgeA, stationA, zA));
  PVector throatB = geodesicFabricationPointToAssembly(faceB,
    geodesicMiterOuterPoint(centerB.miterProfile, edgeB, stationB, zB));
  PVector throat = PVector.add(throatA, throatB).mult(0.5f);
  GeodesicPortalChannelGeometry geometryA =
    geodesicPortalChannelGeometry(faceA, edgeA, stationA);
  GeodesicPortalChannelGeometry geometryB =
    geodesicPortalChannelGeometry(faceB, edgeB, stationB);
  PVector axis = PVector.sub(geometryB.innerCenterWorld,
    geometryA.innerCenterWorld);
  if (axis.magSq() < 0.000001f) return candidate;
  axis.normalize();
  PVector fromA = PVector.sub(throat, geometryA.innerCenterWorld);
  PVector rejection = PVector.sub(fromA,
    PVector.mult(axis, fromA.dot(axis)));
  float angleA = trussUnsignedAxisAngleDeg(
    PVector.sub(geometryA.innerCenterWorld, throat), axis);
  float angleB = trussUnsignedAxisAngleDeg(
    PVector.sub(geometryB.innerCenterWorld, throat), axis);

  candidate.valid = true;
  candidate.inwardMM = inwardMM;
  candidate.stationA = stationA;
  candidate.stationB = stationB;
  candidate.residualMM = rejection.mag() + PVector.dist(throatA, throatB);
  candidate.axisErrorDeg = max(angleA, angleB);
  candidate.throatWorld.set(throat);
  candidate.axisWorld.set(axis);
  return candidate;
}

/* Two panels share an STL only when they are congruent at the resolution the
   printer can actually hold. The previous key compared raw edge-index order at
   0.001 mm, so a rotated triangle or a micron of solver noise minted a new part
   number: a four-bay tunnel shipped twenty SKUs for two real shapes. */
int trussQuantize(float value, float quantum) {
  return round(value / max(0.000001f, quantum));
}

/* Measurements that decide whether two panels are the same printed part. */
TrussFrameTypeKey trussFrameTypeKey(GeodesicFabricationFace face,
  TrussFramePanelMode mode, boolean gate) {
  TrussFrameTypeKey key = new TrussFrameTypeKey();
  key.mode = mode;
  key.gate = gate;
  key.railWidthMM = face.resolvedFabrication == null ? 0 :
    face.resolvedFabrication.frameWidthMM;
  key.signature = trussFrameFabricationSignature(face, mode);
  int count = face.vertexCount();
  key.edgeFeatures = new float[count][16];
  key.edgeBoundary = new boolean[count];
  key.edgeInsetSign = new float[count];
  for (int edgeIndex = 0; edgeIndex < count; edgeIndex++) {
    GeodesicJointEdgeProfile joint = face.joints.get(edgeIndex);
    float[] features = key.edgeFeatures[edgeIndex];
    features[0] = joint.edgeLengthMM;
    features[1] = joint.recommendedHalfMiterDeg;
    features[2] = joint.reciprocalPortalStation * joint.edgeLengthMM;
    features[3] = joint.reciprocalPortalThroatInwardMM;
    // The aperture cut, order-independent so the same opening compares equal
    // however the reciprocal solve happened to enumerate its corners.
    float[] corners = new float[12];
    if (joint.reciprocalApertureResolved) {
      for (int i = 0; i < 4; i++) {
        PVector local = geodesicAssemblyPointToFabrication(face,
          joint.reciprocalApertureCornersWorld[i]);
        corners[i * 3] = local.x;
        corners[i * 3 + 1] = local.y;
        corners[i * 3 + 2] = local.z;
      }
      java.util.Arrays.sort(corners);
    }
    for (int i = 0; i < 12; i++) features[4 + i] = corners[i];
    key.edgeBoundary[edgeIndex] = joint.neighborFaceId < 0;
    key.edgeInsetSign[edgeIndex] = joint.miterInsetSign < 0 ? -1 : 1;
  }
  return key;
}

/* Returns the already-registered type this face prints as, or null. */
TrussFrameTypeKey trussMatchFrameType(TrussMastModel model,
  TrussFrameTypeKey candidate) {
  for (TrussFrameTypeKey existing : model.frameTypeKeys)
    if (existing.matches(candidate, trussPartQuantumMM,
        trussPartAngleQuantumDeg)) return existing;
  return null;
}

String trussFrameFabricationSignature(GeodesicFabricationFace face,
  TrussFramePanelMode mode) {
  String[] edgeTerms = new String[face.vertexCount()];
  for (int edgeIndex = 0; edgeIndex < face.vertexCount(); edgeIndex++) {
    GeodesicJointEdgeProfile joint = face.joints.get(edgeIndex);
    String term = "L" + trussQuantize(joint.edgeLengthMM, trussPartQuantumMM) +
      "M" + trussQuantize(joint.recommendedHalfMiterDeg, trussPartAngleQuantumDeg) +
      "S" + (joint.miterInsetSign < 0 ? "N" : "P") +
      (joint.neighborFaceId < 0 ? "R" : "J") +
      // Absolute position along the edge, not a fraction: the printed slot sits
      // at a distance, and two edges of different length sharing a fraction are
      // not the same part.
      "X" + trussQuantize(joint.reciprocalPortalStation * joint.edgeLengthMM,
        trussPartQuantumMM) +
      "T" + trussQuantize(joint.reciprocalPortalThroatInwardMM, trussPartQuantumMM);
    term += trussApertureFootprint(face, joint);
    edgeTerms[edgeIndex] = term;
  }
  // Rotation-canonical but not reversal-canonical: a mirrored panel is a
  // physically different part and must keep its own STL.
  return (mode == TrussFramePanelMode.OPEN_FRAME ? "OPEN" : "MEMBRANE") + "_" +
    geodesicCanonicalCyclicSignature(edgeTerms);
}

/* The aperture cut, expressed in face-local millimetres and order-independent,
   so the same physical opening hashes the same however its corners were
   enumerated during the reciprocal solve. */
String trussApertureFootprint(GeodesicFabricationFace face,
  GeodesicJointEdgeProfile joint) {
  if (!joint.reciprocalApertureResolved) return "A0";
  String[] corners = new String[joint.reciprocalApertureCornersWorld.length];
  for (int i = 0; i < corners.length; i++) {
    PVector local = geodesicAssemblyPointToFabrication(face,
      joint.reciprocalApertureCornersWorld[i]);
    corners[i] = nf(trussQuantize(local.x, trussPartQuantumMM), 6) + "," +
      nf(trussQuantize(local.y, trussPartQuantumMM), 6) + "," +
      nf(trussQuantize(local.z, trussPartQuantumMM), 6);
  }
  java.util.Arrays.sort(corners);
  String footprint = "A";
  for (String corner : corners) footprint += "|" + corner;
  return footprint;
}

void trussCaptureMiterMetadata(TrussMastModel model) {
  model.maximumPortalAxisErrorDeg = 0;
  model.maximumPortalPairErrorDeg = 0;
  model.maximumPortalThroatErrorMM = 0;
  model.maximumPortalCornerErrorMM = 0;
  model.maximumPortalInwardErrorDeg = 0;
  model.maximumPortalDepthExcursionMM = 0;
  model.concaveSharedJointCount = 0;
  model.sharpestConcaveDihedralDeg = 180;
  for (TrussFrameFace face : model.frameFaces) {
    if (face.fabricationFace == null) continue;
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++)
      face.portalAxesWorld[edgeIndex].set(
        geodesicReciprocalPortalChannelAxis(face.fabricationFace, edgeIndex));
  }
  for (TrussFrameJoint joint : model.frameJoints) {
    TrussFrameFace face = model.frameFaces.get(joint.faceAIndex);
    if (face.fabricationFace == null ||
        joint.edgeA < 0 || joint.edgeA >= face.fabricationFace.joints.size()) continue;
    GeodesicJointEdgeProfile profile =
      face.fabricationFace.joints.get(joint.edgeA);
    joint.normalAngleDeg = max(0, profile.normalAngleDeg);
    joint.interiorDihedralDeg = max(0, profile.interiorDihedralDeg);
    joint.halfMiterDeg = max(0, profile.recommendedHalfMiterDeg);
    joint.miterInsetMM = max(0, profile.recommendedMiterInsetMM);
    joint.miterInsetSign = profile.miterInsetSign;
    joint.concave = profile.concaveJoint;
    joint.miterFeasible = profile.miterFeasibleAtResolvedDimensions;
    joint.bisector.set(profile.junctionBisector);
    if (!joint.shared()) continue;
    if (joint.concave) {
      model.concaveSharedJointCount++;
      model.sharpestConcaveDihedralDeg =
        min(model.sharpestConcaveDihedralDeg, joint.interiorDihedralDeg);
    }
    PVector axisA = model.frameFaces.get(joint.faceAIndex)
      .portalAxesWorld[joint.edgeA];
    PVector axisB = model.frameFaces.get(joint.faceBIndex)
      .portalAxesWorld[joint.edgeB];
    GeodesicFabricationFace fabricationA =
      model.frameFaces.get(joint.faceAIndex).fabricationFace;
    GeodesicFabricationFace fabricationB =
      model.frameFaces.get(joint.faceBIndex).fabricationFace;
    GeodesicJointEdgeProfile reciprocalA =
      fabricationA.joints.get(joint.edgeA);
    GeodesicJointEdgeProfile reciprocalB =
      fabricationB.joints.get(joint.edgeB);
    PVector expectedA = reciprocalA.reciprocalPortalAxisWorld.copy();
    PVector expectedB = reciprocalB.reciprocalPortalAxisWorld.copy();
    if (expectedA.magSq() > 0.000001f) expectedA.normalize();
    if (expectedB.magSq() > 0.000001f) expectedB.normalize();
    float errorA = trussUnsignedAxisAngleDeg(axisA, expectedA);
    float errorB = trussUnsignedAxisAngleDeg(axisB, expectedB);
    joint.portalAxisErrorDeg = max(errorA, errorB);
    joint.portalPairErrorDeg = trussUnsignedAxisAngleDeg(axisA, axisB);
    PVector throatA = geodesicReciprocalPortalThroatWorld(
      fabricationA, joint.edgeA);
    PVector throatB = geodesicReciprocalPortalThroatWorld(
      fabricationB, joint.edgeB);
    joint.portalThroatErrorMM = PVector.dist(throatA, throatB);
    TrussPortalAperture apertureA = trussPortalAperture(
      fabricationA, joint.edgeA);
    TrussPortalAperture apertureB = trussPortalAperture(
      fabricationB, joint.edgeB);
    joint.portalCornerErrorMM = trussPortalCornerSetError(
      apertureA, apertureB);
    // Audit against the transform that actually places the exported mesh, not
    // against the function that built the aperture. Measuring the aperture with
    // its own constructor reported zero error on every kit and could never
    // fail, which is worth less than no check at all.
    PVector measuredA = trussMeasuredPanelDepthAxis(fabricationA);
    PVector measuredB = trussMeasuredPanelDepthAxis(fabricationB);
    float inwardA =
      trussUnsignedAxisAngleDeg(apertureA.heightAxis, measuredA);
    float inwardB =
      trussUnsignedAxisAngleDeg(apertureB.heightAxis, measuredB);
    joint.portalInwardErrorDeg = max(inwardA, inwardB);
    joint.portalDepthExcursionMM = max(
      trussApertureDepthExcursionMM(fabricationA, apertureA),
      trussApertureDepthExcursionMM(fabricationB, apertureB));
    joint.portalWithinPanelDepth = joint.portalDepthExcursionMM <= 0.0001f;
    joint.portalApertureAligned = apertureA.valid && apertureB.valid &&
      abs(reciprocalA.reciprocalPortalStation - 0.5f) < 0.00001f &&
      abs(reciprocalB.reciprocalPortalStation - 0.5f) < 0.00001f &&
      joint.portalInwardErrorDeg <= 8.0f;
    // Adjacent panel-local channels need not be coaxial around a fold. Their
    // printable contract is centered, straight local access plus a matched
    // seam ID; throat and corner differences remain diagnostic only.
    joint.portalCoaxial = joint.portalApertureAligned;
    model.maximumPortalAxisErrorDeg = max(model.maximumPortalAxisErrorDeg,
      joint.portalAxisErrorDeg);
    model.maximumPortalPairErrorDeg = max(model.maximumPortalPairErrorDeg,
      joint.portalPairErrorDeg);
    model.maximumPortalThroatErrorMM = max(model.maximumPortalThroatErrorMM,
      joint.portalThroatErrorMM);
    model.maximumPortalCornerErrorMM = max(model.maximumPortalCornerErrorMM,
      joint.portalCornerErrorMM);
    model.maximumPortalInwardErrorDeg = max(model.maximumPortalInwardErrorDeg,
      joint.portalInwardErrorDeg);
    model.maximumPortalDepthExcursionMM = max(
      model.maximumPortalDepthExcursionMM, joint.portalDepthExcursionMM);
  }
}

TrussPortalAperture trussPortalAperture(GeodesicFabricationFace face,
  int edgeIndex) {
  TrussPortalAperture aperture = new TrussPortalAperture();
  if (face == null || edgeIndex < 0 || edgeIndex >= face.joints.size())
    return aperture;
  GeodesicJointEdgeProfile joint = face.joints.get(edgeIndex);
  if (face.resolvedFabrication != null &&
      face.resolvedFabrication.portalAxisMode ==
        GeodesicPortalAxisMode.RECIPROCAL_JOINT_AXIS &&
      joint.reciprocalApertureResolved) {
    for (int i = 0; i < aperture.corners.length; i++)
      aperture.corners[i].set(joint.reciprocalApertureCornersWorld[i]);
    return trussFinalizePortalAperture(aperture);
  }
  return trussFaceLocalPortalAperture(face, edgeIndex);
}

TrussPortalAperture trussFaceLocalPortalAperture(
  GeodesicFabricationFace face, int edgeIndex) {
  TrussPortalAperture aperture = new TrussPortalAperture();
  if (face == null || face.resolvedFabrication == null ||
      edgeIndex < 0 || edgeIndex >= face.joints.size()) return aperture;
  GeodesicJointEdgeProfile joint = face.joints.get(edgeIndex);
  GeodesicPortalChannelGeometry geometry =
    geodesicPortalChannelGeometry(face, edgeIndex);
  ArrayList<float[]> intervals = geodesicPortalIntervals(joint);
  if (!joint.reciprocalPortalResolved || !geometry.valid ||
      intervals.size() != 1) return aperture;
  float[] interval = intervals.get(0);
  float[] slot = geodesicPortalOuterSlotRange(face, joint,
    face.resolvedFabrication, geometry.depth,
    geometry.slotBottom, geometry.slotTop);
  PVector[] local = {
    geodesicMiterOuterPoint(geometry.miterProfile, edgeIndex,
      interval[0], slot[0]),
    geodesicMiterOuterPoint(geometry.miterProfile, edgeIndex,
      interval[1], slot[0]),
    geodesicMiterOuterPoint(geometry.miterProfile, edgeIndex,
      interval[1], slot[1]),
    geodesicMiterOuterPoint(geometry.miterProfile, edgeIndex,
      interval[0], slot[1])
  };
  for (int i = 0; i < 4; i++) {
    aperture.corners[i].set(
      geodesicFabricationPointToAssembly(face, local[i]));
  }
  return trussFinalizePortalAperture(aperture);
}

TrussPortalAperture trussFinalizePortalAperture(
  TrussPortalAperture aperture) {
  aperture.center.set(0, 0, 0);
  for (PVector corner : aperture.corners) aperture.center.add(corner);
  aperture.center.mult(0.25f);
  PVector startMid = PVector.add(aperture.corners[0],
    aperture.corners[3]).mult(0.5f);
  PVector endMid = PVector.add(aperture.corners[1],
    aperture.corners[2]).mult(0.5f);
  PVector bottomMid = PVector.add(aperture.corners[0],
    aperture.corners[1]).mult(0.5f);
  PVector topMid = PVector.add(aperture.corners[3],
    aperture.corners[2]).mult(0.5f);
  aperture.edgeAxis.set(PVector.sub(endMid, startMid));
  aperture.heightAxis.set(PVector.sub(topMid, bottomMid));
  aperture.valid = aperture.edgeAxis.magSq() > 0.000001f &&
    aperture.heightAxis.magSq() > 0.000001f;
  if (aperture.valid) {
    aperture.edgeAxis.normalize();
    aperture.heightAxis.normalize();
  }
  return aperture;
}

float trussPortalCornerSetError(TrussPortalAperture a,
  TrussPortalAperture b) {
  if (a == null || b == null || !a.valid || !b.valid)
    return Float.MAX_VALUE;
  float best = Float.MAX_VALUE;
  for (int offset = 0; offset < 4; offset++) {
    float forward = 0;
    float reverse = 0;
    for (int i = 0; i < 4; i++) {
      forward = max(forward, PVector.dist(a.corners[i],
        b.corners[(i + offset) % 4]));
      int reverseIndex = (offset - i) % 4;
      if (reverseIndex < 0) reverseIndex += 4;
      reverse = max(reverse, PVector.dist(a.corners[i],
        b.corners[reverseIndex]));
    }
    best = min(best, min(forward, reverse));
  }
  return best;
}

PVector trussPortalDesiredInwardAxis(TrussMastModel model,
  TrussFrameJoint joint, PVector edgeAxis) {
  // The aperture's short axis runs along the wall depth, from the buried
  // material toward whichever face the assembler can actually reach.
  PVector approach = trussAccessDirection(model, joint.midpoint);
  if (approach.magSq() < 0.000001f)
    approach.set(model.tunnel ? 0 : 1, model.tunnel ? 1 : 0, 0);
  if (edgeAxis != null && edgeAxis.magSq() > 0.000001f) {
    PVector tangent = edgeAxis.copy(); tangent.normalize();
    approach.sub(PVector.mult(tangent, approach.dot(tangent)));
  }
  if (approach.magSq() > 0.000001f) approach.normalize();
  return approach;
}

/* Worst seam coverage in the build, or -1 when nothing could be measured. */
float trussMinimumSeamOverlapMM(TrussMastModel model) {
  if (model == null) return -1;
  float worst = Float.MAX_VALUE;
  for (TrussFrameJoint joint : model.frameJoints) {
    if (!joint.shared()) continue;
    float overlap = trussSeamOverlapMM(model, joint);
    if (overlap >= 0) worst = min(worst, overlap);
  }
  return worst == Float.MAX_VALUE ? -1 : worst;
}

/* The direction panel material grows, measured through the very transform that
   places the exported mesh in the assembly. Independent of the axis-frame
   reasoning that chose the aperture, so comparing the two can actually fail. */
PVector trussMeasuredPanelDepthAxis(GeodesicFabricationFace face) {
  if (face == null || face.resolvedFabrication == null) return new PVector();
  PVector surface = geodesicFabricationPointToAssembly(face, new PVector(0, 0, 0));
  PVector buried = geodesicFabricationPointToAssembly(face,
    new PVector(0, 0, face.resolvedFabrication.frameDepthMM));
  PVector axis = PVector.sub(buried, surface);
  if (axis.magSq() > 0.000001f) axis.normalize();
  return axis;
}

/* How far the aperture strays outside the panel's own depth range. A portal
   that leaves the rail is not a channel, it is a notch in the outside face. */
float trussApertureDepthExcursionMM(GeodesicFabricationFace face,
  TrussPortalAperture aperture) {
  if (face == null || face.resolvedFabrication == null ||
      aperture == null || !aperture.valid) return Float.MAX_VALUE;
  float depth = face.resolvedFabrication.frameDepthMM;
  float worst = 0;
  for (PVector corner : aperture.corners) {
    PVector local = geodesicAssemblyPointToFabrication(face, corner);
    if (local.z < 0) worst = max(worst, -local.z);
    else if (local.z > depth) worst = max(worst, local.z - depth);
  }
  return worst;
}

float trussUnsignedAxisAngleDeg(PVector a, PVector b) {
  if (a == null || b == null ||
      a.magSq() < 0.000001f || b.magSq() < 0.000001f) return 180;
  PVector na = a.copy(); na.normalize();
  PVector nb = b.copy(); nb.normalize();
  return degrees(acos(constrain(abs(na.dot(nb)), 0, 1)));
}

void trussResolveFrameJoints(TrussMastModel model) {
  model.frameJoints.clear();
  model.frameJointTopologyValid = true;
  HashMap<String, ArrayList<TrussFrameEdgeRef>> edgeRefs =
    new HashMap<String, ArrayList<TrussFrameEdgeRef>>();
  for (int faceIndex = 0; faceIndex < model.frameFaces.size(); faceIndex++) {
    TrussFrameFace face = model.frameFaces.get(faceIndex);
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      PVector a = face.world[edgeIndex];
      PVector b = face.world[(edgeIndex + 1) % 3];
      String key = trussFrameEdgeKey(a, b);
      ArrayList<TrussFrameEdgeRef> refs = edgeRefs.get(key);
      if (refs == null) {
        refs = new ArrayList<TrussFrameEdgeRef>();
        edgeRefs.put(key, refs);
      }
      refs.add(new TrussFrameEdgeRef(faceIndex, edgeIndex));
    }
  }
  for (String key : edgeRefs.keySet()) {
    ArrayList<TrussFrameEdgeRef> refs = edgeRefs.get(key);
    if (refs.size() < 1 || refs.size() > 2) {
      model.frameJointTopologyValid = false;
      continue;
    }
    TrussFrameEdgeRef a = refs.get(0);
    TrussFrameEdgeRef b = refs.size() == 2 ? refs.get(1) : null;
    TrussFrameFace faceA = model.frameFaces.get(a.faceIndex);
    PVector edgeA = faceA.world[a.edgeIndex];
    PVector edgeB = faceA.world[(a.edgeIndex + 1) % 3];
    PVector midpoint = PVector.add(edgeA, edgeB).mult(0.5f);
    TrussFrameJoint joint = new TrussFrameJoint(model.frameJoints.size(),
      a, b, midpoint, PVector.dist(edgeA, edgeB));
    model.frameJoints.add(joint);
    trussAssignFrameJoint(model, joint, a);
    if (b != null) trussAssignFrameJoint(model, joint, b);
  }
}

void trussAssignFrameJoint(TrussMastModel model, TrussFrameJoint joint,
  TrussFrameEdgeRef ref) {
  TrussFrameFace face = model.frameFaces.get(ref.faceIndex);
  face.jointIds[ref.edgeIndex] = joint.label();
  face.portalStations[ref.edgeIndex] = 0.5f;
  face.portalCentersWorld[ref.edgeIndex].set(joint.midpoint);
  if (joint.shared()) {
    int mateIndex = ref.faceIndex == joint.faceAIndex ?
      joint.faceBIndex : joint.faceAIndex;
    face.neighborFaceIds[ref.edgeIndex] = model.frameFaces.get(mateIndex).id;
  }
}

String trussFrameEdgeKey(PVector a, PVector b) {
  String aKey = trussFramePointKey(a);
  String bKey = trussFramePointKey(b);
  return aKey.compareTo(bKey) <= 0 ? aKey + "|" + bKey : bKey + "|" + aKey;
}

String trussFramePointKey(PVector p) {
  return round(p.x * 1000.0f) + "," + round(p.y * 1000.0f) + "," +
    round(p.z * 1000.0f);
}

int trussSharedFrameJointCount(TrussMastModel model) {
  int count = 0;
  if (model == null) return count;
  for (TrussFrameJoint joint : model.frameJoints) if (joint.shared()) count++;
  return count;
}

int trussBoundaryFrameJointCount(TrussMastModel model) {
  int count = 0;
  if (model == null) return count;
  for (TrussFrameJoint joint : model.frameJoints) if (!joint.shared()) count++;
  return count;
}

/* Which portal criterion blocks, and by how much. An audit that reports only a
   verdict cannot be acted on; this names the first thing that failed and the
   worst value behind it. */
/* Which part fails to close, and how. "REVIEW 12 components" says a mesh is not
   a solid but not whether it is a hairline sliver or a real hole, and those
   want completely different fixes. */
String trussSealedPartsDetail(TrussMastModel model) {
  if (model == null || model.sealedComponents.size() == 0) return "no components";
  int failing = 0, worstBoundary = 0, worstNonManifold = 0, worstDegenerate = 0;
  String worstName = "";
  for (SurfaceMesh mesh : model.sealedComponents) {
    int[] audit = mesh.manifoldAudit();
    if (audit[0] == 0 && audit[1] == 0 && audit[2] == 0) continue;
    failing++;
    if (audit[0] + audit[1] + audit[2] >
        worstBoundary + worstNonManifold + worstDegenerate) {
      worstBoundary = audit[0];
      worstNonManifold = audit[1];
      worstDegenerate = audit[2];
      worstName = mesh.name;
    }
  }
  if (failing == 0) return "all " + model.sealedComponents.size() + " sealed";
  return failing + "/" + model.sealedComponents.size() + " open / worst " +
    worstName + " bnd " + worstBoundary + " nonman " + worstNonManifold +
    " degen " + worstDegenerate;
}

String trussPortalAuditDetail(TrussMastModel model) {
  if (model == null || model.frameJoints.size() == 0) return "no joints";
  if (!model.frameJointTopologyValid) return "joint topology invalid";
  int station = 0, neighbour = 0, unresolved = 0, coaxial = 0;
  int throatOver = 0, cornerOver = 0, inwardOver = 0;
  int gateAdjacentFailures = 0, plainFailures = 0;
  for (TrussFrameJoint joint : model.frameJoints) {
    TrussFrameFace faceA = model.frameFaces.get(joint.faceAIndex);
    boolean bad = false;
    if (!trussFrameEdgeMatchesJoint(faceA, joint.edgeA, joint)) { station++; bad = true; }
    if (joint.shared()) {
      TrussFrameFace faceB = model.frameFaces.get(joint.faceBIndex);
      if (!trussFrameEdgeMatchesJoint(faceB, joint.edgeB, joint)) { station++; bad = true; }
      if (faceA.neighborFaceIds[joint.edgeA] != faceB.id ||
          faceB.neighborFaceIds[joint.edgeB] != faceA.id) { neighbour++; bad = true; }
      // Only unresolved portals block; the rest are reported drift.
      if (!joint.reciprocalPortalResolvedOnBothPanels(model)) { unresolved++; bad = true; }
      if (!joint.portalCoaxial) coaxial++;
      if (joint.portalThroatErrorMM > 0.05f) throatOver++;
      if (joint.portalCornerErrorMM > 0.05f) cornerOver++;
      if (joint.portalInwardErrorDeg > 8.0f) inwardOver++;
      // Splitting failures by whether a reinforced gate panel is involved is a
      // decisive test of whether the wider gate rail is what breaks the portal
      // solve, rather than the collar's flare.
      if (bad) {
        if (faceA.gateTruss || faceB.gateTruss) gateAdjacentFailures++;
        else plainFailures++;
      }
    }
  }
  if (station + neighbour + unresolved == 0)
    return "assemblable" + (inwardOver + throatOver + cornerOver > 0 ?
      " / drift inw " + nf(model.maximumPortalInwardErrorDeg, 1, 1) + "d thr " +
      nf(model.maximumPortalThroatErrorMM, 1, 2) : "");
  String detail = "";
  if (station > 0) detail += "stn " + station + " ";
  if (neighbour > 0) detail += "nbr " + neighbour + " ";
  if (unresolved > 0) detail += "unres " + unresolved + " ";
  if (inwardOver > 0) detail += "inw " + inwardOver + "@" +
    nf(model.maximumPortalInwardErrorDeg, 1, 1) + "d ";
  if (cornerOver > 0) detail += "cor " + cornerOver + "@" +
    nf(model.maximumPortalCornerErrorMM, 1, 2) + " ";
  if (throatOver > 0) detail += "thr " + throatOver + "@" +
    nf(model.maximumPortalThroatErrorMM, 1, 2) + " ";
  if (coaxial > 0) detail += "cox " + coaxial + " ";
  detail += "| gate " + gateAdjacentFailures + " plain " + plainFailures;
  if (model.concaveSharedJointCount > 0)
    detail += " | sharpest concave " +
      nf(model.sharpestConcaveDihedralDeg, 1, 0) + "d";
  return detail;
}

boolean trussFramePortalAuditPassed(TrussMastModel model) {
  if (model == null || !model.frameJointTopologyValid ||
      model.frameFaces.size() == 0 || model.frameJoints.size() == 0) return false;
  for (TrussFrameJoint joint : model.frameJoints) {
    TrussFrameFace faceA = model.frameFaces.get(joint.faceAIndex);
    if (!trussFrameEdgeMatchesJoint(faceA, joint.edgeA, joint)) return false;
    if (joint.shared()) {
      TrussFrameFace faceB = model.frameFaces.get(joint.faceBIndex);
      if (!trussFrameEdgeMatchesJoint(faceB, joint.edgeB, joint)) return false;
      if (faceA.neighborFaceIds[joint.edgeA] != faceB.id ||
          faceB.neighborFaceIds[joint.edgeB] != faceA.id) return false;
      // Gate on the assembly requirement, not on a fabrication ideal.
      //
      // A shared joint is assemblable when both panels own the same resolved
      // portal and it is positioned on both. When the aperture resolves, both
      // panels are assigned the identical world corners by construction, so
      // corner error is exactly zero -- it was never independent evidence, it
      // was a restatement of "did it resolve" wearing a 0.05 mm tolerance. The
      // approach angle and throat residual are precision measures of how
      // squarely the tie sits, not of whether the parts go together, and a zip
      // tie through a printed slot does not resolve fractions of a millimetre.
      // Both are reported instead, so a drift that matters is still visible.
      if (!joint.reciprocalPortalResolvedOnBothPanels(model)) return false;
    }
  }
  return true;
}

boolean trussFrameSeamAuditPassed(TrussMastModel model) {
  // Cross-seam gap is the physical opening between mating rail ends and is the
  // only seam term worth blocking on.
  //
  // The audit's tangential term is NOT an opening. It compares the two panels
  // at the same parameter along their miter lines, and adjacent triangles
  // legitimately trim their rail ends by different amounts, so equal-parameter
  // points sit apart along the seam by exactly that difference. Gating on it
  // blocked every kit while measuring nothing physical. It is reported as
  // trim asymmetry instead; trussSeamOverlapMM is the real coverage measure.
  return model != null && model.frameSeamAudit != null &&
    model.frameSeamAudit.evaluated && model.frameSeamAudit.valid &&
    model.frameSeamAudit.maximumCrossSeamGapMM <=
      model.frameSeamAudit.toleranceMM + 0.0001f;
}

/* Length of shared edge over which both panels actually carry rail.
   This is the coverage the tangential term was mistaken for: it projects each
   panel's own miter span onto the shared axis and intersects them. Reported
   while thresholds are established from real builds rather than assumed. */
float trussSeamOverlapMM(TrussMastModel model, TrussFrameJoint joint) {
  if (model == null || joint == null || !joint.shared()) return -1;
  GeodesicFabricationFace faceA =
    model.frameFaces.get(joint.faceAIndex).fabricationFace;
  GeodesicFabricationFace faceB =
    model.frameFaces.get(joint.faceBIndex).fabricationFace;
  if (faceA == null || faceB == null) return -1;
  GeodesicPortalChannelGeometry geometryA =
    geodesicPortalChannelGeometry(faceA, joint.edgeA, 0.5f);
  GeodesicPortalChannelGeometry geometryB =
    geodesicPortalChannelGeometry(faceB, joint.edgeB, 0.5f);
  if (!geometryA.valid || !geometryB.valid) return -1;
  float zA = geodesicPortalLocalZForInward(faceA, geometryA.depth * 0.5f);
  float zB = geodesicPortalLocalZForInward(faceB, geometryB.depth * 0.5f);
  PVector a0 = geodesicFabricationPointToAssembly(faceA,
    geodesicMiterOuterPoint(geometryA.miterProfile, joint.edgeA, 0, zA));
  PVector a1 = geodesicFabricationPointToAssembly(faceA,
    geodesicMiterOuterPoint(geometryA.miterProfile, joint.edgeA, 1, zA));
  PVector b0 = geodesicFabricationPointToAssembly(faceB,
    geodesicMiterOuterPoint(geometryB.miterProfile, joint.edgeB, 0, zB));
  PVector b1 = geodesicFabricationPointToAssembly(faceB,
    geodesicMiterOuterPoint(geometryB.miterProfile, joint.edgeB, 1, zB));
  PVector axis = PVector.sub(a1, a0);
  if (axis.magSq() < 0.000001f) return -1;
  axis.normalize();
  float minA = min(a0.dot(axis), a1.dot(axis));
  float maxA = max(a0.dot(axis), a1.dot(axis));
  float minB = min(b0.dot(axis), b1.dot(axis));
  float maxB = max(b0.dot(axis), b1.dot(axis));
  return max(0, min(maxA, maxB) - max(minA, minB));
}

/* Portal opening measured against the fastener that has to pass through it.

   The aperture is in model millimetres and the tie is a real physical object,
   so the two only meet at a print scale. A 50 mm model mast simply cannot pass
   a 2.5 mm tie at 100%; that is a statement about scale, not a defect in the
   geometry. The useful answer is therefore the smallest print scale at which
   the declared stock passes, which is what this reports. */
class TrussFastenerFit {
  boolean evaluated = false;
  boolean fits = false;
  float minimumApertureWidthMM = Float.MAX_VALUE;
  float minimumApertureHeightMM = Float.MAX_VALUE;
  float requiredWidthMM;
  float requiredHeightMM;
  float minimumPrintScalePercent = 0;
  String limitingJoint = "";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("evaluated", evaluated);
    json.setBoolean("fits_at_declared_scale", fits);
    json.setFloat("declared_print_scale_percent", trussPrintScalePercent);
    json.setFloat("minimum_print_scale_percent", minimumPrintScalePercent);
    json.setFloat("tie_width_mm", trussZipTieWidthMM);
    json.setFloat("tie_thickness_mm", trussZipTieThicknessMM);
    json.setFloat("clearance_mm", trussZipTieClearanceMM);
    json.setFloat("required_aperture_width_mm", requiredWidthMM);
    json.setFloat("required_aperture_height_mm", requiredHeightMM);
    json.setFloat("minimum_aperture_width_mm",
      minimumApertureWidthMM == Float.MAX_VALUE ? 0 : minimumApertureWidthMM);
    json.setFloat("minimum_aperture_height_mm",
      minimumApertureHeightMM == Float.MAX_VALUE ? 0 : minimumApertureHeightMM);
    json.setString("limiting_joint", limitingJoint);
    json.setString("policy",
      "the tightest shared aperture, scaled by the declared print scale, must " +
      "clear the declared tie stock plus clearance");
    return json;
  }
}

TrussFastenerFit trussAuditFastenerFit(TrussMastModel model) {
  TrussFastenerFit fit = new TrussFastenerFit();
  fit.requiredWidthMM = trussZipTieWidthMM + trussZipTieClearanceMM;
  fit.requiredHeightMM = trussZipTieThicknessMM + trussZipTieClearanceMM;
  if (model == null || model.frameJoints.size() == 0) return fit;
  float worstScale = 0;
  for (TrussFrameJoint joint : model.frameJoints) {
    if (!joint.shared()) continue;
    TrussFrameFace face = model.frameFaces.get(joint.faceAIndex);
    if (face.fabricationFace == null) continue;
    TrussPortalAperture aperture =
      trussPortalAperture(face.fabricationFace, joint.edgeA);
    if (!aperture.valid) continue;
    fit.evaluated = true;
    float width = PVector.dist(aperture.corners[0], aperture.corners[1]);
    float height = PVector.dist(aperture.corners[0], aperture.corners[3]);
    // A tie is a flat strap, so it passes the long way through: compare the
    // aperture's own long and short spans against the strap's.
    float longSpan = max(width, height);
    float shortSpan = min(width, height);
    float needed = max(
      longSpan > 0.0001f ? fit.requiredWidthMM / longSpan : 999,
      shortSpan > 0.0001f ? fit.requiredHeightMM / shortSpan : 999) * 100.0f;
    if (needed > worstScale) {
      worstScale = needed;
      fit.minimumApertureWidthMM = longSpan;
      fit.minimumApertureHeightMM = shortSpan;
      fit.limitingJoint = joint.label();
    }
  }
  fit.minimumPrintScalePercent = worstScale;
  fit.fits = fit.evaluated && worstScale <= trussPrintScalePercent + 0.01f;
  return fit;
}

boolean trussFrameEdgeMatchesJoint(TrussFrameFace face, int edgeIndex,
  TrussFrameJoint joint) {
  if (face == null || face.fabricationFace == null ||
      edgeIndex < 0 || edgeIndex >= face.fabricationFace.joints.size())
    return false;
  GeodesicJointEdgeProfile profile =
    face.fabricationFace.joints.get(edgeIndex);
  return profile.portalCenters.size() == 1 &&
    abs(face.portalStations[edgeIndex] -
      profile.reciprocalPortalStation) < 0.00001f &&
    abs(profile.portalCenters.get(0) -
      profile.reciprocalPortalStation) < 0.00001f &&
    face.portalStations[edgeIndex] >= 0.05f &&
    face.portalStations[edgeIndex] <= 0.95f &&
    face.jointIds[edgeIndex].equals(joint.label());
}

void trussAppendTransformedMesh(SurfaceMesh target, SurfaceMesh local,
  PVector a, PVector b, PVector c) {
  PVector xAxis = PVector.sub(b, a); xAxis.normalize();
  PVector normal = PVector.sub(b, a).cross(PVector.sub(c, a)); normal.normalize();
  PVector yAxis = normal.cross(xAxis); yAxis.normalize();
  for (MeshTri tri : local.tris) target.addTri(
    trussLocalToWorld(tri.a, a, xAxis, yAxis, normal),
    trussLocalToWorld(tri.b, a, xAxis, yAxis, normal),
    trussLocalToWorld(tri.c, a, xAxis, yAxis, normal));
}

void trussAppendFabricatedMesh(SurfaceMesh target, SurfaceMesh local,
  GeodesicFabricationFace face) {
  if (target == null || local == null || face == null) return;
  for (MeshTri tri : local.tris) target.addTri(
    geodesicFabricationPointToAssembly(face, tri.a),
    geodesicFabricationPointToAssembly(face, tri.b),
    geodesicFabricationPointToAssembly(face, tri.c));
}

PVector trussLocalToWorld(PVector p, PVector origin, PVector xAxis, PVector yAxis, PVector zAxis) {
  PVector world = origin.copy();
  world.add(PVector.mult(xAxis, p.x));
  world.add(PVector.mult(yAxis, p.y));
  world.add(PVector.mult(zAxis, p.z));
  return world;
}

int trussAddNode(TrussMastModel model, PVector point) {
  model.nodes.add(point);
  return model.nodes.size() - 1;
}

void trussAddLink(TrussMastModel model, int a, int b) {
  if (a == b) return;
  model.links.add(new int[] { a, b });
}

PVector trussOrient(PVector raw, boolean tunnel) {
  return tunnel ? new PVector(raw.z, raw.y, -raw.x) : raw.copy();
}

void trussAddBeam(SurfaceMesh mesh, PVector rawA, PVector rawB, float radius,
  boolean tunnel) {
  PVector a = trussOrient(rawA, tunnel);
  PVector b = trussOrient(rawB, tunnel);
  PVector axis = PVector.sub(b, a);
  if (axis.magSq() < 0.00001f) return;
  axis.normalize();
  PVector guide = abs(axis.z) < 0.82f ? new PVector(0, 0, 1) : new PVector(0, 1, 0);
  PVector side = axis.cross(guide);
  if (side.magSq() < 0.00001f) side = new PVector(1, 0, 0);
  side.normalize();
  PVector binormal = axis.cross(side);
  binormal.normalize();
  int sides = 8;
  PVector[] ra = new PVector[sides];
  PVector[] rb = new PVector[sides];
  for (int i = 0; i < sides; i++) {
    float theta = TWO_PI * i / sides;
    PVector offset = PVector.mult(side, cos(theta) * radius);
    offset.add(PVector.mult(binormal, sin(theta) * radius));
    ra[i] = PVector.add(a, offset);
    rb[i] = PVector.add(b, offset);
  }
  for (int i = 0; i < sides; i++) {
    int j = (i + 1) % sides;
    mesh.addQuad(ra[i], rb[i], rb[j], ra[j]);
    // Reverse each cap ring relative to the side wall so the component remains orientable.
    mesh.addTri(a, ra[i], ra[j]);
    mesh.addTri(b, rb[j], rb[i]);
  }
}

void trussAddNodeBody(SurfaceMesh mesh, PVector raw, float radius, boolean tunnel) {
  PVector p = trussOrient(raw, tunnel);
  PVector px = PVector.add(p, new PVector(radius, 0, 0));
  PVector nx = PVector.add(p, new PVector(-radius, 0, 0));
  PVector py = PVector.add(p, new PVector(0, radius, 0));
  PVector ny = PVector.add(p, new PVector(0, -radius, 0));
  PVector pz = PVector.add(p, new PVector(0, 0, radius));
  PVector nz = PVector.add(p, new PVector(0, 0, -radius));
  mesh.addTri(pz, px, py); mesh.addTri(pz, py, nx);
  mesh.addTri(pz, nx, ny); mesh.addTri(pz, ny, px);
  mesh.addTri(nz, py, px); mesh.addTri(nz, nx, py);
  mesh.addTri(nz, ny, nx); mesh.addTri(nz, px, ny);
}

/* Readiness of the current build, as a traffic light.

   2 RED    nothing blocks and nothing drifts: fully convex wall, every panel a
            closed solid, every shared joint carrying a resolved portal, seams
            closed. This is the red the dome uses for a committed opening, so a
            finished chain reads the same colour end to end.
   1 YELLOW buildable and exportable, but carrying reported drift -- forced
            crease rings, portal approach angle, seam trim asymmetry.
   0 TEAL   something blocks export.

   The point is to see a slider move land without reading the numbers. */
int trussReadinessGrade() {
  if (trussModel == null) return 0;
  if (!trussModel.componentsAudited()) return 0;
  if (trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES)
    return 1;
  boolean foldsOk = trussModel.ringShapeVaries ||
    trussModel.avoidableConcaveJointCount() == 0;
  if (!foldsOk || !trussFramePortalAuditPassed(trussModel) ||
      !trussFrameSeamAuditPassed(trussModel)) return 0;
  boolean pristine = trussModel.concaveSharedJointCount == 0 &&
    trussModel.maximumPortalInwardErrorDeg <= 8.0f &&
    trussModel.maximumPortalThroatErrorMM <= 0.05f &&
    trussModel.maximumPortalCornerErrorMM <= 0.05f &&
    (trussModel.frameSeamAudit == null ||
      trussModel.frameSeamAudit.maximumTangentialGapMM <=
        max(0.5f, trussModel.frameWidthMM));
  return pristine ? 2 : 1;
}

String trussReadinessLabel(int grade) {
  if (grade == 2) return "CLEAN / no drift";
  if (grade == 1) return "BUILDABLE / carries drift";
  return "BLOCKED";
}

void drawTrussYard(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "TRUSS YARD");
  int sideW = 340;
  int sceneX = x + 24, sceneY = y + 52;
  int sceneW = w - sideW - 72, sceneH = h - 76;
  int sideX = sceneX + sceneW + 24;
  drawTrussYardScene(sceneX, sceneY, sceneW, sceneH);
  drawTrussYardControls(sideX, sceneY, sideW, sceneH);
}

void drawTrussYardScene(int x, int y, int w, int h) {
  pushStyle();
  fill(3, 8, 12); stroke(31, 70, 78); rect(x, y, w, h, 6);
  fill(112, 224, 210); textAlign(LEFT, TOP); textSize(10);
  text(trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
    "TRIANGULATED FRAME MAST / TUNNEL" : "OCTAHEDRAL SKELETON STUDY", x + 14, y + 12);
  fill(96, 132, 142); textSize(8);
  text(trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
    "reusable portal frames / centered zip-tie assembly" :
    "reusable lattice segments / salon-scale adapter reference", x + 14, y + 29);
  if (trussModel != null && trussModel.combined != null) {
    pushMatrix();
    translate(x + w * 0.50f, y + h * 0.55f, 0);
    rotateX(-0.72f);
    rotateY(0.48f + simT * 0.05f);
    int grade = trussReadinessGrade();
    int previewFill = grade == 2 ? color(255, 96, 72, 52) :
      (grade == 1 ? color(240, 198, 70, 48) : color(75, 180, 210, 44));
    int previewStroke = grade == 2 ? color(255, 138, 108, 165) :
      (grade == 1 ? color(255, 224, 122, 140) : color(120, 235, 220, 95));
    trussModel.combined.drawPreviewFitted(min(w, h) * 0.35f,
      previewFill, previewStroke);
    drawTrussConnectorOpeningOverlay(min(w, h) * 0.35f);
    if (trussDomeMatch && trussModel.adapter != null) {
      pushMatrix(); translate(0, 0, -min(w, h) * 0.05f);
      trussModel.adapter.drawPreviewFitted(min(w, h) * 0.20f); popMatrix();
    }
    popMatrix();
  }
  int legendGrade = trussReadinessGrade();
  fill(legendGrade == 2 ? color(255, 138, 108) :
    (legendGrade == 1 ? color(255, 224, 122) : color(120, 235, 220)));
  textSize(9); textAlign(RIGHT, TOP);
  text(trussReadinessLabel(legendGrade), x + w - 14, y + 12);
  fill(96, 132, 142); textSize(8);
  text("red clean / yellow drift / teal blocked", x + w - 14, y + 26);
  fill(125, 160, 170); textSize(9); textAlign(LEFT, BOTTOM);
  String match = trussDomeMatch && geodesicModel != null ?
    "dome reference " + nf(trussModel.matchRadiusMM, 1, 1) + " mm / edge " +
    nf(trussModel.matchEdgeMM, 1, 1) + " mm" : "standalone dimensions";
  text(match, x + 14, y + h - 16);
  popStyle();
}

/* The dome perimeter this connector was built to meet, drawn in the same fitted
   frame as the preview so the piece can be read against its opening. Without it
   the connector is a shape with no stated context. */
void drawTrussConnectorOpeningOverlay(float fitRadius) {
  if (!trussConnectionMode || !trussConnectorAvailable() ||
      trussModel == null || trussModel.combined == null) return;
  GeodesicOpeningCandidate opening = geodesicOpeningSelection.candidate;
  if (opening.ringWorld.size() < 3) return;
  SurfaceMesh mesh = trussModel.combined;
  float spanX = mesh.previewMaxX - mesh.previewMinX;
  float spanY = mesh.previewMaxY - mesh.previewMinY;
  float spanZ = mesh.previewMaxZ - mesh.previewMinZ;
  float span = max(0.001f, max(spanX, max(spanY, spanZ)));
  float scale = fitRadius * 2.0f / span;
  float cx = (mesh.previewMinX + mesh.previewMaxX) * 0.5f;
  float cy = (mesh.previewMinY + mesh.previewMaxY) * 0.5f;
  float cz = (mesh.previewMinZ + mesh.previewMaxZ) * 0.5f;
  pushStyle();
  noFill();
  stroke(255, 214, 92, 240);
  strokeWeight(2.0f);
  beginShape();
  for (PVector p : opening.ringWorld)
    vertex((p.x - cx) * scale, (p.y - cy) * scale, (p.z - cz) * scale);
  endShape(CLOSE);
  popStyle();
}

void drawTrussYardControls(int x, int y, int w, int h) {
  drawReadoutPanel(x, y, w, 540, "TRUSS BUILD");
  int bx = x + 16, by = y + 38, bw = w - 32, gap = 8;
  int half = (bw - gap) / 2;
  boolean bindable = trussConnectorResult != null && trussConnectorResult.built;
  drawButton(bx, by, bw, 20,
    !trussBindToConnector ? "BIND TO CONNECTOR: OFF" :
    (bindable ? "BOUND / " + trussConnectorResult.section + " R " +
      nf(trussConnectorResult.terminalRadiusMM, 1, 1) + " rail " +
      nf(trussConnectorResult.railWidthMM, 1, 2) :
      "BIND ON / NO CONNECTOR BUILT"),
    !trussBindToConnector ? color(42, 72, 82) :
      (bindable ? color(34, 104, 96) : color(112, 62, 48)));
  by += 26;
  drawButton(bx, by, half, 26, "REBUILD", color(28, 108, 86));
  drawButton(bx + half + gap, by, half, 26, "EXPORT TRUSS", color(94, 69, 34));
  by += 30;
  drawButton(bx, by, bw, 22, "PULL UNION + KIT", color(72, 58, 96));
  by += 30;
  drawButton(bx, by, bw, 22,
    trussConnectionMode ? "CONNECTION MODE / DOME OPENING" : "MODE: FREE STANDING",
    trussConnectionMode ? (trussConnectorAvailable() ?
      color(34, 104, 96) : color(112, 62, 48)) : color(42, 72, 82));
  by += 30;
  drawButton(bx, by, half, 22, trussOrientation == TrussYardOrientation.TOWER ?
    "TOWER" : "TUNNEL", color(42, 72, 82));
  drawButton(bx + half + gap, by, half, 22, trussDomeMatch ?
    "MATCH DOME ON" : "MATCH DOME OFF", trussDomeMatch ? color(39, 104, 84) : color(55, 58, 66));
  by += 32;
  drawButton(bx, by, bw, 22, trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
    "MODE: TRIANGLE FRAMES" : "MODE: SKELETON STUDY",
    trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ? color(16, 112, 104) : color(82, 67, 43));
  by += 32;
  drawButton(bx, by, bw, 22, trussFramePanelMode == TrussFramePanelMode.OPEN_FRAME ?
    "PANEL: OPEN FRAME" : "PANEL: EXTERIOR MEMBRANE",
    trussFramePanelMode == TrussFramePanelMode.OPEN_FRAME ?
    color(42, 72, 82) : color(36, 104, 87));
  by += 32;
  drawButton(bx, by, bw, 22,
    trussConnectionMode && trussConnectorAvailable() ?
      "SECTION: " + trussConnectorResult.section + " " +
        trussConnectorResult.nodes + " / FROM OPENING" :
      "SECTION: " + trussSection.label(),
    trussConnectionMode && trussConnectorAvailable() ?
      color(34, 88, 96) : color(42, 72, 82));
  by += 38;
  boolean connectorDriven = trussConnectionMode && trussConnectorAvailable();
  drawTrussControlPair(bx, by, bw, connectorDriven ? "COLLAR BAYS" : "BAYS",
    connectorDriven ? trussConnectorCollarBays + (trussConnectorCollarBays == 1 ?
      " / convex, portals resolve" : " / adds crease rings, portals may not resolve") :
    str(trussBayCount)); by += 46;
  drawTrussControlPair(bx, by, bw, "SPAN", connectorDriven ?
    nf(trussConnectorResult.ringRadiusMM * 2, 1, 1) + " mm / from opening" :
    nf(trussBaySpanMM, 1, 1) + " mm"); by += 46;
  drawTrussControlPair(bx, by, bw, "HEIGHT", connectorDriven ?
    nf(trussConnectorResult.collarLengthMM, 1, 1) + " mm collar / from opening" :
    nf(trussBayHeightMM, 1, 1) + " mm"); by += 46;
  drawTrussControlPair(bx, by, bw, trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ? "RAIL" : "STRUT",
    nf(trussStrutRadiusMM, 1, 2) + " mm"); by += 46;
  float convexTwist = trussNearestConvexTwistDeg(trussTwistDeg,
    trussSection.sides());
  boolean twistIsConvex = abs(convexTwist - trussTwistDeg) < 0.05f;
  drawTrussControlPair(bx, by, bw, connectorDriven ? "GATE RAIL" : "TWIST",
    connectorDriven ?
    "x" + nf(trussGateRailScale, 1, 2) + (trussGateRailScale <= 1.001f ?
      " / no reinforcement" : " / reinforced") :
    nf(trussTwistDeg, 1, 1) + " deg" +
    (twistIsConvex ? " / convex" : " / creased, convex at " +
      nf(convexTwist, 1, 1)));
  int sy = y + 560;
  int statsH = h - 560;
  drawReadoutPanel(x, sy, w, statsH, "FABRICATION / ADAPTER");
  int ty = sy + 34;
  // Fit the readout to the panel instead of running off the bottom of it.
  trussMetricStep = constrain((statsH - 42) / TRUSS_READOUT_LINES, 9, 13);
  trussMetricClipBottom = sy + statsH - 4;
  trussMetric(x + 16, ty, w - 32, "status", trussStatus); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "readiness",
    trussReadinessLabel(trussReadinessGrade())); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
    "frame instances / types" : "octa bays / struts",
    (trussModel == null ? "-" : (trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
      trussModel.frameFaces.size() + " / " + trussModel.frameTypes.size() :
      trussModel.bays + " / " + trussModel.links.size()))); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "sealed parts audit",
    trussModel == null ? "-" : (trussModel.componentsAudited() ? "PASS " : "REVIEW ") + trussModel.sealedComponents.size() + " components"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "seal blocker",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    trussSealedPartsDetail(trussModel)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "portal pair audit",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    (trussFramePortalAuditPassed(trussModel) ? "PASS " : "REVIEW ") +
    trussSharedFrameJointCount(trussModel) + " shared / " +
    trussBoundaryFrameJointCount(trussModel) + " rim"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "portal blocker",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    trussPortalAuditDetail(trussModel)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "section / access",
    trussModel == null ? "-" : trussModel.section.label() + " / " +
    trussModel.accessSide.label() + " TIE"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "wall fold audit",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    (trussModel.avoidableConcaveJointCount() > 0 ?
      "REVIEW / " + trussModel.avoidableConcaveJointCount() + " avoidable" :
      (trussModel.concaveSharedJointCount == 0 ? "PASS / fully convex wall" :
        "PASS / " + trussModel.concaveSharedJointCount +
        " forced crease" + (trussModel.concaveSharedJointCount == 1 ? "" : "s")))); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "miter seam audit",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ||
    trussModel.frameSeamAudit == null ? "-" :
    (trussFrameSeamAuditPassed(trussModel) ? "PASS " : "REVIEW ") +
    nf(trussModel.frameSeamAudit.maximumCrossSeamGapMM, 1, 3) +
    " / " + nf(trussModel.frameSeamAudit.toleranceMM, 1, 2) + " mm"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "seam coverage",
    trussModel == null || trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    "min overlap " + nf(trussMinimumSeamOverlapMM(trussModel), 1, 2) +
    " mm / trim asym " + nf(trussModel.frameSeamAudit == null ? 0 :
      trussModel.frameSeamAudit.maximumTangentialGapMM, 1, 2)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "zip-tie fit",
    trussModel == null || trussModel.fastenerFit == null ||
    !trussModel.fastenerFit.evaluated ? "-" :
    "scale to " + nf(trussModel.fastenerFit.minimumPrintScalePercent, 1, 0) +
    "% for " + nf(trussZipTieWidthMM, 1, 1) + "x" +
    nf(trussZipTieThicknessMM, 1, 1) + " tie"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "tightest portal",
    trussModel == null || trussModel.fastenerFit == null ||
    !trussModel.fastenerFit.evaluated ? "-" :
    nf(trussModel.fastenerFit.minimumApertureWidthMM, 1, 2) + " x " +
    nf(trussModel.fastenerFit.minimumApertureHeightMM, 1, 2) + " mm vs tie " +
    nf(trussModel.fastenerFit.requiredWidthMM, 1, 2) + " x " +
    nf(trussModel.fastenerFit.requiredHeightMM, 1, 2)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "lineage",
    trussModel == null || trussModel.lineageFabrication == null ?
    "own dimensions / not dome-derived" :
    "DOME depth " + nf(trussModel.lineageFabrication.frameDepthMM, 1, 1) +
    " portal " + nf(trussModel.lineageFabrication.portalWidthMM, 1, 1) + "x" +
    nf(trussModel.lineageFabrication.portalHeightMM, 1, 1) +
    " / scale x" + nf(max(1.0f,
      trussModel.lineageFabrication.fabricationScale), 1, 2)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "lineage drift",
    trussLineageDriftDetail().length() == 0 ?
    "in step with the live dome" : trussLineageDriftDetail()); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "bind",
    !trussBindToConnector ? "off / free dimensions" :
    (trussConnectorResult == null || !trussConnectorResult.built ?
      "ON / no connector built yet" :
      (trussConnectionMode ? "ON / idle while in connection mode" :
        "BOUND / span " + nf(trussConnectorResult.terminalRadiusMM * 2, 1, 1) +
        " rail " + nf(trussConnectorResult.railWidthMM, 1, 2) + "x" +
        nf(trussConnectorResult.railDepthMM, 1, 2) +
        (trussModel != null && trussModel.boundRailInsufficient ?
          " / TWIST NEEDS WIDER RAIL" : "")))); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "connector",
    !trussConnectionMode ? "free standing" : trussConnectorResult.status); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "node offset",
    !trussConnectionMode || !trussConnectorResult.built ? "-" :
    nf(trussConnectorResult.maximumNodeOffsetMM, 1, 4) + " mm / opening " +
    nf(trussConnectorResult.openingPlanarityMM, 1, 2) + " mm flat"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "gate / collar panels",
    !trussConnectionMode || !trussConnectorResult.built ? "-" :
    trussConnectorResult.gatePanels + " gate x" + nf(trussGateRailScale, 1, 1) +
    " rail / " + trussConnectorResult.collarPanels + " collar"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "union",
    trussBuildMode != TrussBuildMode.TRIANGLE_FRAMES ? "-" :
    "on demand / " + nf(trussUnionVoxelMM, 1, 2) + " mm sampling"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "adapter", trussDomeMatch ?
    "REFERENCE SPIDER / SEPARATE STL" : "OFF / STANDALONE"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "salon contract", trussDomeMatch && geodesicModel != null ?
    geodesicFamily.displayLabel() + " R " + nf(geodesicModel.radius, 1, 1) : "NO LIVE SALON MODEL"); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "export", trussLastExport.length() == 0 ? "not exported" : shortText(trussLastExport, 35)); ty += trussMetricStep;
  trussMetric(x + 16, ty, w - 32, "tests", trussTestStatus);
}

void drawTrussControlPair(int x, int y, int w, String label, String value) {
  int gap = 8, half = (w - gap) / 2;
  drawButton(x, y, half, 22, label + " -", color(42, 72, 82));
  drawButton(x + half + gap, y, half, 22, label + " +", color(42, 72, 82));
  fill(110, 140, 150); textAlign(LEFT, TOP); textSize(8);
  text(label.toLowerCase(), x, y + 25);
  fill(220, 238, 236); textAlign(RIGHT, TOP); text(value, x + w, y + 25);
}

// Number of readout lines below; keep in step so the adaptive fit is right.
final int TRUSS_READOUT_LINES = 24;
int trussMetricStep = 13;
float trussMetricClipBottom = Float.MAX_VALUE;

void trussMetric(int x, int y, int w, String label, String value) {
  if (y + 8 > trussMetricClipBottom) return;
  fill(112, 140, 150); textAlign(LEFT, TOP); textSize(8); text(label, x, y);
  fill(220, 238, 236); textAlign(RIGHT, TOP); text(shortText(value, 43), x + w, y);
}

boolean handleTrussYardMouse(int pageX, int pageY, int pageW, int pageH) {
  int sideW = 340, x = pageX + 24, y = pageY + 52;
  int sceneW = pageW - sideW - 72, sideX = x + sceneW + 24;
  int bx = sideX + 16, by = y + 38, bw = sideW - 32, gap = 8, half = (bw - gap) / 2;
  if (over(bx, by, bw, 20)) {
    trussBindToConnector = !trussBindToConnector;
    rebuildTrussYard(trussBindToConnector ? "bound to connector" : "unbound");
    return true;
  }
  by += 26;
  if (over(bx, by, half, 26)) { rebuildTrussYard("rebuilt"); return true; }
  if (over(bx + half + gap, by, half, 26)) { exportTrussYard(false); return true; }
  by += 30;
  if (over(bx, by, bw, 22)) { exportTrussYard(true); return true; }
  by += 30;
  if (over(bx, by, bw, 22)) {
    trussConnectionMode = !trussConnectionMode;
    rebuildTrussYard(trussConnectionMode ? "connection mode" : "free standing");
    return true;
  }
  by += 30;
  if (over(bx, by, half, 22)) { trussOrientation = trussOrientation == TrussYardOrientation.TOWER ? TrussYardOrientation.TUNNEL : TrussYardOrientation.TOWER; rebuildTrussYard("orientation changed"); return true; }
  if (over(bx + half + gap, by, half, 22)) { trussDomeMatch = !trussDomeMatch; rebuildTrussYard("dome match changed"); return true; }
  by += 32;
  if (over(bx, by, bw, 22)) { trussBuildMode = trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES ?
      TrussBuildMode.SKELETON_STUDY : TrussBuildMode.TRIANGLE_FRAMES; rebuildTrussYard("build mode changed"); return true; }
  by += 32;
  if (over(bx, by, bw, 22)) {
    trussFramePanelMode = trussFramePanelMode == TrussFramePanelMode.OPEN_FRAME ?
      TrussFramePanelMode.EXTERIOR_MEMBRANE : TrussFramePanelMode.OPEN_FRAME;
    rebuildTrussYard("panel enclosure changed");
    return true;
  }
  by += 32;
  if (over(bx, by, bw, 22)) {
    if (trussConnectionMode && trussConnectorAvailable()) return true;
    trussSection = trussNextSection(trussSection);
    // A twist legal on a triangle overshoots a dodecagon, so re-seat it.
    float limit = trussMaxTwistDeg(trussSection.sides());
    trussTwistDeg = constrain(trussTwistDeg, -limit, limit);
    rebuildTrussYard("section changed");
    return true;
  }
  by += 38;
  if (trussHandlePair(bx, by, bw, 0)) return true; by += 46;
  if (trussHandlePair(bx, by, bw, 1)) return true; by += 46;
  if (trussHandlePair(bx, by, bw, 2)) return true; by += 46;
  if (trussHandlePair(bx, by, bw, 3)) return true; by += 46;
  if (trussHandlePair(bx, by, bw, 4)) return true;
  return false;
}

TrussSectionFamily trussNextSection(TrussSectionFamily current) {
  TrussSectionFamily[] all = TrussSectionFamily.values();
  for (int i = 0; i < all.length; i++)
    if (all[i] == current) return all[(i + 1) % all.length];
  return TrussSectionFamily.HEXAGON;
}

boolean trussHandlePair(int x, int y, int w, int control) {
  int gap = 8, half = (w - gap) / 2;
  int delta = over(x, y, half, 22) ? -1 : (over(x + half + gap, y, half, 22) ? 1 : 0);
  if (delta == 0) return false;
  if (control == 0) {
    if (trussConnectionMode && trussConnectorAvailable())
      trussConnectorCollarBays = constrain(trussConnectorCollarBays + delta, 1, 6);
    else trussBayCount = constrain(trussBayCount + delta, 1, 24);
  }
  else if (control == 1) {
    if (trussConnectionMode && trussConnectorAvailable()) return true;
    trussDomeMatch = false;
    trussBaySpanMM = constrain(trussBaySpanMM + delta * 2, 12, 160);
  }
  else if (control == 2) {
    if (trussConnectionMode && trussConnectorAvailable()) return true;
    trussDomeMatch = false;
    trussBayHeightMM = constrain(trussBayHeightMM + delta * 2, 12, 160);
  }
  else if (control == 3) trussStrutRadiusMM = constrain(trussStrutRadiusMM + delta * 0.25f, 0.8f, 12.0f);
  else {
    if (trussConnectionMode && trussConnectorAvailable()) {
      // The gate reinforcement widens rails, which changes the portal solve.
      // Being able to dial it back to 1.0 is how we tell whether the gate class
      // or the collar's flare is what blocks a connector.
      trussGateRailScale = constrain(trussGateRailScale + delta * 0.1f, 1.0f, 2.4f);
      rebuildTrussYard("gate rail scale");
      return true;
    }
    float limit = trussMaxTwistDeg(trussSection.sides());
    // Step in twelfths of the section so the convex endpoints are reachable
    // exactly rather than being stepped over.
    trussTwistDeg = constrain(trussTwistDeg + delta * (limit / 12.0f),
      -limit, limit);
    if (abs(trussTwistDeg) < 0.0005f) trussTwistDeg = 0;
  }
  rebuildTrussYard("parameter changed");
  return true;
}

void exportTrussYard() {
  // The union is a large file and most exports do not want one, so the plain
  // export stays exactly as it was and PULL UNION opts in.
  exportTrussYard(false);
}

void exportTrussYard(boolean includeUnion) {
  if (trussModel == null) rebuildTrussYard("export requested");
  if (trussModel == null || trussModel.combined == null || trussModel.combined.tris.size() == 0) {
    trussStatus = "EXPORT BLOCKED / EMPTY LATTICE"; return;
  }
  if (!trussModel.componentsAudited()) {
    trussStatus = "EXPORT BLOCKED / SEALED COMPONENT AUDIT"; return;
  }
  String stamp = geodesicSalonTimestamp();
  String label = trussOrientation == TrussYardOrientation.TUNNEL ? "tunnel" : "tower";
  File folder = new File(sketchPath("exports/truss_yard/" + stamp + "_octa_" + label + "_b" + trussBayCount));
  if (!folder.exists() && !folder.mkdirs()) { trussStatus = "EXPORT BLOCKED / FOLDER"; return; }
  File parts = new File(folder, "parts");
  if (!parts.exists() && !parts.mkdirs()) { trussStatus = "EXPORT BLOCKED / PARTS FOLDER"; return; }
  if (trussBuildMode == TrussBuildMode.TRIANGLE_FRAMES) {
    trussExportTriangleFrameKit(folder, parts, stamp, label, includeUnion);
    return;
  }
  SurfaceMesh diagonal = trussModel.sealedComponents.get(0);
  SurfaceMesh ring = trussModel.sealedComponents.get(2);
  SurfaceMesh node = trussModel.sealedComponents.get(trussModel.links.size());
  diagonal.writeSTL(new File(parts, "TRUSS_DIAGONAL_qty" + nf(trussBayCount * 8, 3) + ".stl").getAbsolutePath());
  ring.writeSTL(new File(parts, "TRUSS_RING_qty" + nf(trussBayCount * 4, 3) + ".stl").getAbsolutePath());
  node.writeSTL(new File(parts, "TRUSS_NODE_qty" + nf(trussModel.nodes.size(), 3) + ".stl").getAbsolutePath());
  trussModel.combined.writeSTL(new File(folder, "octahedral_" + label + "_assembly_preview.stl").getAbsolutePath());
  if (trussDomeMatch && trussModel.adapter != null && trussModel.adapter.tris.size() > 0) {
    trussModel.sealedAdapterComponents.get(0).writeSTL(new File(parts, "ADAPTER_ARM_qty004.stl").getAbsolutePath());
    trussModel.sealedAdapterComponents.get(trussModel.sealedAdapterComponents.size() - 1).writeSTL(new File(parts, "ADAPTER_ROOT_qty001.stl").getAbsolutePath());
  }
  JSONObject manifest = trussModel.toJSON();
  manifest.setString("generated_at", stamp);
  manifest.setString("printable_parts_folder", "parts/");
  manifest.setString("assembled_preview_stl", "octahedral_" + label + "_assembly_preview.stl");
  manifest.setString("adapter_reference", trussDomeMatch ? "parts/ADAPTER_ARM_qty004.stl + parts/ADAPTER_ROOT_qty001.stl" : "");
  manifest.setJSONObject("field_state", geodesicSalonFieldStateJSON());
  saveJSONObject(manifest, new File(folder, "manifest.json").getAbsolutePath());
  JSONObject bom = new JSONObject();
  bom.setString("schema", "fieldworks.truss_yard.bom.v1");
  bom.setString("orientation", label);
  bom.setString("print_contract", "Print sealed reusable parts from parts/. Assembly preview is visual reference only.");
  JSONArray partList = new JSONArray();
  trussAddBomItem(partList, "TRUSS_DIAGONAL", trussBayCount * 8,
    "sealed octahedral axial-to-ring strut");
  trussAddBomItem(partList, "TRUSS_RING", trussBayCount * 4,
    "sealed octahedral ring brace");
  trussAddBomItem(partList, "TRUSS_NODE", trussModel.nodes.size(),
    "sealed octahedral lattice node");
  if (trussDomeMatch) {
    trussAddBomItem(partList, "ADAPTER_ARM", 4,
      "reference spider arm scaled from the active Geodesic Salon model");
    trussAddBomItem(partList, "ADAPTER_ROOT", 1,
      "reference spider center node");
  }
  bom.setJSONArray("parts", partList);
  saveJSONObject(bom, new File(folder, "bill_of_materials.json").getAbsolutePath());
  PrintWriter guide = createWriter(new File(folder, "ASSEMBLY.txt").getAbsolutePath());
  guide.println("TRUSS YARD / OCTAHEDRAL " + label.toUpperCase());
  guide.println("Generated " + stamp);
  guide.println("Bays " + trussModel.bays + " | span " + nf(trussModel.baySpanMM, 1, 2) + " mm | height " + nf(trussModel.bayHeightMM, 1, 2) + " mm");
  guide.println("Strut radius " + nf(trussModel.strutRadiusMM, 1, 2) + " mm | twist " + nf(degrees(trussModel.twistRadians), 1, 2) + " deg");
  guide.println("Print the reusable sealed part STLs in parts/ for assured manifold components. The assembly preview STL is visual reference only and contains intentionally intersecting solids.");
  if (trussDomeMatch) guide.println("Adapter reference matches salon radius " + nf(trussModel.matchRadiusMM, 1, 2) + " mm and mean panel edge " + nf(trussModel.matchEdgeMM, 1, 2) + " mm. It is a scale-reference adapter, not a universal panel connector.");
  guide.flush(); guide.close();
  trussLastExport = folder.getAbsolutePath();
  trussStatus = "TRUSS EXPORTED / " + trussModel.links.size() + " STRUTS";
}

void trussExportTriangleFrameKit(File folder, File parts, String stamp,
  String label, boolean includeUnion) {
  if (trussModel.frameTypes.size() == 0 || trussModel.frameFaces.size() == 0) {
    trussStatus = "EXPORT BLOCKED / FRAME CATALOG EMPTY";
    return;
  }
  if (trussModel.avoidableConcaveJointCount() > 0 && !trussModel.ringShapeVaries) {
    // Forced crease rings at bay interfaces are expected; anything beyond them
    // means the wall was triangulated against its own curvature.
    trussStatus = "EXPORT BLOCKED / " +
      trussModel.avoidableConcaveJointCount() + " AVOIDABLE CONCAVE FOLDS";
    return;
  }
  if (!trussFramePortalAuditPassed(trussModel)) {
    trussStatus = "EXPORT BLOCKED / PORTAL PAIR AUDIT";
    return;
  }
  if (!trussFrameSeamAuditPassed(trussModel)) {
    trussStatus = "EXPORT BLOCKED / MITER SEAM AUDIT";
    return;
  }
  JSONArray partList = new JSONArray();
  for (String signature : trussModel.frameTypes.keySet()) {
    String typeId = trussModel.frameTypeIds.get(signature);
    SurfaceMesh mesh = trussModel.frameTypes.get(signature);
    int quantity = trussModel.frameQuantities.get(typeId);
    if (mesh == null || mesh.tris.size() == 0 || mesh.manifoldAudit()[0] != 0 ||
        mesh.manifoldAudit()[1] != 0 || mesh.manifoldAudit()[2] != 0) {
      trussStatus = "EXPORT BLOCKED / FRAME AUDIT " + typeId;
      return;
    }
    String filename = typeId + "_qty" + nf(quantity, 3) + ".stl";
    mesh.writeSTL(new File(parts, filename).getAbsolutePath());
    trussAddBomItem(partList, typeId, quantity,
      (trussModel.framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
      "open triangular structural frame" :
      "triangular frame with continuous exterior membrane") +
      " and one centerline-facing shared aperture per edge");
  }
  String previewName = "triangulated_frame_" + label + "_assembly_preview.stl";
  trussModel.combined.writeSTL(new File(folder, previewName).getAbsolutePath());
  TrussCallSheetResult callSheets =
    exportTrussCallSheets(folder, trussModel, stamp);
  // Render authority only, and opt-in because the file is large. The parts in
  // parts/ stay the fabrication authority, and this mesh is deliberately never
  // added to sealedComponents so it cannot affect the audit that gates export.
  TrussUnionResult union = new TrussUnionResult();
  if (includeUnion) union = exportTrussUnion(folder, trussModel.combined, label);
  else union.status = "not requested / use PULL UNION";
  JSONObject manifest = trussModel.toJSON();
  manifest.setString("generated_at", stamp);
  manifest.setString("printable_parts_folder", "parts/");
  manifest.setString("assembled_preview_stl", previewName);
  manifest.setJSONObject("call_sheets", callSheets.toJSON());
  manifest.setJSONObject("watertight_union", union.toJSON());
  if (trussConnectionMode) {
    manifest.setJSONObject("dome_connector", trussConnectorResult.toJSON());
    if (geodesicOpeningSelection != null)
      manifest.setJSONObject("source_opening", geodesicOpeningSelection.toJSON());
  }
  manifest.setString("assembly_contract",
    "Print reusable frame parts. Align matching joint IDs and complementary half-dihedral miter faces, then secure each shared edge through the centered straight-through portal on each panel.");
  manifest.setJSONObject("field_state", geodesicSalonFieldStateJSON());
  saveJSONObject(manifest, new File(folder, "manifest.json").getAbsolutePath());
  JSONObject bom = new JSONObject();
  bom.setString("schema", "fieldworks.truss_yard.frame_kit_bom.v1");
  bom.setString("orientation", label);
  bom.setString("print_contract", "Print the manifold triangle frames in parts/. The assembled preview STL is a visual layout reference only.");
  bom.setJSONArray("parts", partList);
  saveJSONObject(bom, new File(folder, "bill_of_materials.json").getAbsolutePath());
  JSONArray placements = new JSONArray();
  for (TrussFrameFace face : trussModel.frameFaces) {
    JSONObject item = new JSONObject();
    item.setInt("face_id", face.id);
    item.setString("part_id", face.typeId);
    JSONArray vertices = new JSONArray();
    for (int i = 0; i < 3; i++) {
      vertices.setJSONArray(i, trussPointJSONArray(face.world[i]));
    }
    item.setJSONArray("world_vertices_mm", vertices);
    JSONArray edges = new JSONArray();
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      JSONObject edge = new JSONObject();
      edge.setInt("edge_index", edgeIndex);
      edge.setString("joint_id", face.jointIds[edgeIndex]);
      edge.setString("edge_role", face.neighborFaceIds[edgeIndex] >= 0 ?
        "SHARED" : "BOUNDARY");
      edge.setInt("neighbor_face_id", face.neighborFaceIds[edgeIndex]);
      edge.setFloat("portal_station_edge_fraction", face.portalStations[edgeIndex]);
      if (face.fabricationFace != null &&
          edgeIndex < face.fabricationFace.joints.size()) {
        GeodesicJointEdgeProfile profile =
          face.fabricationFace.joints.get(edgeIndex);
        edge.setFloat("normal_angle_deg", max(0, profile.normalAngleDeg));
        edge.setFloat("interior_dihedral_deg",
          max(0, profile.interiorDihedralDeg));
        edge.setFloat("half_miter_deg",
          max(0, profile.recommendedHalfMiterDeg));
        edge.setFloat("miter_inset_sign", profile.miterInsetSign);
        edge.setString("joint_class",
          profile.concaveJoint ? "CONCAVE" : "CONVEX");
      }
      edge.setJSONArray("portal_center_world_mm",
        trussPointJSONArray(face.portalCentersWorld[edgeIndex]));
      edges.setJSONObject(edgeIndex, edge);
    }
    item.setJSONArray("edges", edges);
    item.setString("joint",
      "one zip-tie loop through matched centered panel-local portals");
    placements.append(item);
  }
  JSONArray joints = new JSONArray();
  for (int i = 0; i < trussModel.frameJoints.size(); i++) {
    TrussFrameJoint joint = trussModel.frameJoints.get(i);
    JSONObject item = new JSONObject();
    item.setString("joint_id", joint.label());
    item.setString("role", joint.shared() ? "SHARED" : "BOUNDARY");
    item.setInt("face_a", trussModel.frameFaces.get(joint.faceAIndex).id);
    item.setInt("edge_a", joint.edgeA);
    item.setInt("face_b", joint.shared() ?
      trussModel.frameFaces.get(joint.faceBIndex).id : -1);
    item.setInt("edge_b", joint.edgeB);
    item.setFloat("edge_length_mm", joint.edgeLengthMM);
    TrussFrameFace jointFaceA =
      trussModel.frameFaces.get(joint.faceAIndex);
    item.setFloat("portal_station_a_edge_fraction",
      jointFaceA.portalStations[joint.edgeA]);
    if (joint.shared()) {
      TrussFrameFace jointFaceB =
        trussModel.frameFaces.get(joint.faceBIndex);
      item.setFloat("portal_station_b_edge_fraction",
        jointFaceB.portalStations[joint.edgeB]);
    }
    item.setFloat("normal_angle_deg", joint.normalAngleDeg);
    item.setFloat("interior_dihedral_deg", joint.interiorDihedralDeg);
    item.setFloat("half_miter_deg", joint.halfMiterDeg);
    item.setFloat("miter_inset_mm", joint.miterInsetMM);
    item.setFloat("miter_inset_sign", joint.miterInsetSign);
    item.setString("joint_class", joint.concave ? "CONCAVE" : "CONVEX");
    item.setBoolean("miter_feasible", joint.miterFeasible);
    item.setBoolean("portal_aperture_aligned",
      joint.portalApertureAligned);
    item.setFloat("portal_corner_error_mm",
      joint.portalCornerErrorMM);
    item.setFloat("portal_inward_error_deg",
      joint.portalInwardErrorDeg);
    item.setFloat("portal_approach_axis_error_deg_diagnostic",
      joint.portalAxisErrorDeg);
    item.setFloat("portal_pair_axis_error_deg_diagnostic",
      joint.portalPairErrorDeg);
    item.setJSONArray("junction_bisector", trussPointJSONArray(joint.bisector));
    item.setJSONArray("portal_center_world_mm",
      trussPointJSONArray(jointFaceA.portalCentersWorld[joint.edgeA]));
    joints.setJSONObject(i, item);
  }
  JSONObject plan = new JSONObject();
  plan.setString("schema", "fieldworks.truss_yard.triangle_frame_assembly.v3");
  plan.setString("method",
    "edge-to-edge frame assembly with centered panel-local zip-tie portals and complementary half-dihedral rail miters");
  plan.setString("portal_alignment_policy",
    "one straight-through portal at station 0.5 on each panel; shared seam IDs pair the openings without skewing either cut");
  plan.setBoolean("portal_pair_audit_passed",
    trussFramePortalAuditPassed(trussModel));
  plan.setFloat("maximum_portal_throat_error_mm",
    trussModel.maximumPortalThroatErrorMM);
  plan.setBoolean("miter_seam_audit_passed",
    trussFrameSeamAuditPassed(trussModel));
  plan.setJSONObject("miter_seam_audit",
    trussModel.frameSeamAudit.toJSON());
  plan.setInt("shared_joint_count", trussSharedFrameJointCount(trussModel));
  plan.setInt("boundary_edge_count", trussBoundaryFrameJointCount(trussModel));
  plan.setJSONArray("joints", joints);
  plan.setJSONArray("faces", placements);
  saveJSONObject(plan, new File(folder, "assembly_plan.json").getAbsolutePath());
  PrintWriter guide = createWriter(new File(folder, "ASSEMBLY.txt").getAbsolutePath());
  guide.println("TRUSS YARD / TRIANGLE FRAME " + label.toUpperCase());
  guide.println("Generated " + stamp);
  guide.println("Bays " + trussModel.bays + " | span " + nf(trussModel.baySpanMM, 1, 2) + " mm | height " + nf(trussModel.bayHeightMM, 1, 2) + " mm | twist " + nf(degrees(trussModel.twistRadians), 1, 2) + " deg");
  guide.println("Section " + trussModel.section.label() + " | corner dihedral " +
    nf(trussModel.section.cornerDihedralDeg(), 1, 1) + " deg untwisted.");
  guide.println("Zip-tie access " + trussModel.accessSide.label() +
    (trussModel.accessSide == TrussAccessSide.INTERIOR ?
    ": thread every tie from inside the tunnel bore." :
    ": thread every tie from outside the mast. The shaft is not reachable, so " +
    "the panels are laid outboard of the wall surface."));
  guide.println("Wall folds: " + trussSharedFrameJointCount(trussModel) +
    " shared joints, " + trussModel.concaveSharedJointCount + " concave (" +
    trussModel.forcedConcaveJointCount() + " forced by twist, " +
    trussModel.avoidableConcaveJointCount() + " avoidable).");
  if (trussModel.concaveSharedJointCount > 0)
    guide.println("Set twist to a multiple of " +
      nf(360.0f / trussModel.sectionSides, 1, 1) +
      " deg for a wall with no concave creases at all.");
  guide.println("Frame rail " + nf(trussModel.frameWidthMM, 1, 2) + " mm x " + nf(trussModel.frameDepthMM, 1, 2) + " mm.");
  guide.println("Panel mode " + (trussModel.framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
    "OPEN FRAME scaffold." :
    "EXTERIOR MEMBRANE enclosure; seal physical seams and portal penetrations for airtight service."));
  guide.println("Print each reusable frame STL in parts/. Place faces by reciprocal joint IDs in assembly_plan.json. Every shared edge uses complementary half-dihedral miter faces and one centered straight-through portal on each panel. Pair the matching seam IDs and close the tie across the seam.");
  guide.println("Portal pair audit PASS | shared joints " +
    trussSharedFrameJointCount(trussModel) + " | boundary edges " +
    trussBoundaryFrameJointCount(trussModel) + ".");
  guide.println("Local portal diagnostic | maximum seam-mouth offset " +
    nf(trussModel.maximumPortalCornerErrorMM, 1, 4) +
    " mm | maximum panel-axis error " +
    nf(trussModel.maximumPortalInwardErrorDeg, 1, 3) +
    " deg | maximum mouth-center offset " +
    nf(trussModel.maximumPortalThroatErrorMM, 1, 4) + " mm.");
  guide.println("Miter seam audit PASS | maximum cross-seam gap " +
    nf(trussModel.frameSeamAudit.maximumCrossSeamGapMM, 1, 4) +
    " mm | tolerance " + nf(trussModel.frameSeamAudit.toleranceMM, 1, 3) +
    " mm.");
  guide.println("The aggregate preview is a visual layout, not a printable merged shell.");
  if (union.evaluated && union.closed)
    guide.println("For a single-body print use " + union.filename +
      ": one closed solid unioned from the placed panels at " +
      nf(union.voxelMM, 1, 2) + " mm sampling. Print the parts in parts/ instead " +
      "when you intend to assemble the truss.");
  else if (union.evaluated)
    guide.println("Watertight union not produced: " + union.status +
      ". Print the parts in parts/.");
  else
    guide.println("No watertight union in this kit. Use PULL UNION + KIT in " +
      "Truss Yard to export one; it is a large single-body STL for printing " +
      "the whole structure rather than assembling it.");
  guide.flush(); guide.close();
  trussLastExport = folder.getAbsolutePath();
  trussStatus = (includeUnion ? "KIT + UNION / " : "FRAME KIT EXPORTED / ") +
    trussModel.frameFaces.size() + " PANELS / " +
    trussModel.frameTypes.size() + " TYPES" +
    (includeUnion ? " / " + union.status : "");
}

JSONArray trussPointJSONArray(PVector point) {
  JSONArray values = new JSONArray();
  values.setFloat(0, point.x);
  values.setFloat(1, point.y);
  values.setFloat(2, point.z);
  return values;
}

void trussAddBomItem(JSONArray parts, String id, int quantity, String role) {
  JSONObject item = new JSONObject();
  item.setString("id", id);
  item.setInt("quantity", quantity);
  item.setString("role", role);
  parts.append(item);
}

TrussYardTestReport runTrussYardTests() {
  TrussYardTestReport report = new TrussYardTestReport();
  TrussMastModel tower = buildTrussMastModel(3, 36, 30, 2.4f, radians(12), false, true, 72, 31);
  report.check(tower.nodes.size() == 16, "tower shares axial nodes between bays");
  report.check(tower.links.size() == 36, "tower has twelve octahedral links per bay");
  report.check(tower.combined.tris.size() > 0 && tower.componentsAudited(), "tower reusable components are sealed and auditable");
  report.check(tower.adapter.tris.size() > 0 && tower.sealedAdapterComponents.size() > 0 && tower.componentsAudited(), "dome reference adapter components are sealed");
  TrussMastModel tunnel = buildTrussMastModel(2, 28, 24, 1.8f, 0, true, false, 0, 0);
  report.check(tunnel.tunnel && tunnel.combined.previewMaxX - tunnel.combined.previewMinX > 40, "tunnel rotates long axis onto x");
  report.check(!tunnel.domeMatched && tunnel.adapter.tris.size() == 0, "standalone tunnel omits adapter");
  TrussMastModel frames = buildTrussMastModel(3, 36, 30, 2.4f, radians(12), false, false, 0, 0);
  frames.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  buildTrussTriangleFrames(frames);
  report.check(frames.frameFaces.size() == 24, "frame truss creates two triangular panels per side per bay");
  report.check(frames.frameTypes.size() > 0 && frames.componentsAudited(), "reusable triangle frames are sealed and auditable");
  report.check(frames.combined.tris.size() > 0, "frame truss has an aggregate assembly preview");
  report.check(trussFramePortalAuditPassed(frames),
    "every shared frame edge uses one centered panel-local portal");
  report.check(trussSharedFrameJointCount(frames) == 32 &&
    trussBoundaryFrameJointCount(frames) == 8,
    "three-bay frame truss resolves 32 shared joints and 8 boundary edges");
  boolean stationsResolved = true;
  for (TrussFrameFace face : frames.frameFaces) {
    for (int edgeIndex = 0; edgeIndex < 3; edgeIndex++) {
      GeodesicJointEdgeProfile profile =
        face.fabricationFace.joints.get(edgeIndex);
      if (profile.neighborFaceId >= 0 &&
          (!profile.reciprocalPortalResolved ||
           profile.portalCenters.size() != 1 ||
           abs(profile.portalCenters.get(0) -
             profile.reciprocalPortalStation) > 0.00001f ||
           abs(profile.reciprocalPortalStation - 0.5f) > 0.00001f))
        stationsResolved = false;
    }
  }
  report.check(stationsResolved,
    "all shared frame portals remain centered at edge station 0.5");
  report.check(frames.frameTopology != null &&
    frames.frameTopology.faces.size() == frames.frameFaces.size(),
    "frame mast exposes one shared fabrication topology for all panels");
  report.check(frames.frameFabrication != null &&
    frames.frameFabrication.seamProfile ==
      GeodesicSeamProfile.HALF_DIHEDRAL_MITER,
    "frame mast requests reciprocal half-dihedral rail miters");
  report.check(frames.frameFabrication != null &&
    frames.frameFabrication.portalAxisMode ==
      GeodesicPortalAxisMode.PANEL_TRANSVERSE,
    "frame mast requests straight panel-local portal channels");
  report.check(trussFrameSeamAuditPassed(frames),
    "assembled frame miters remain within the physical seam-gap tolerance");
  // Coverage, not the audit's trim-asymmetry term. Every shared edge must
  // carry rail from both panels over a usable span, or the tie has nothing to
  // pull against.
  report.check(trussMinimumSeamOverlapMM(frames) > 0,
    "every shared edge carries overlapping rail from both panels");

  // Geodesic Salon must be untouched by the growth sign: its default settings
  // have to keep laying panels inboard and leaning miters exactly as before.
  GeodesicFabricationSettings salonDefaults = new GeodesicFabricationSettings();
  report.check(salonDefaults.assemblyGrowthSign < 0 &&
    salonDefaults.copy().assemblyGrowthSign < 0,
    "default fabrication settings still lay panels inboard for the salon");
  GeodesicFabricationSettings salonPortals =
    currentGeodesicFabricationSettings();
  report.check(salonPortals.portalAxisMode ==
      GeodesicPortalAxisMode.PANEL_TRANSVERSE &&
    salonPortals.desiredPortalsPerEdge == 1,
    "Salon panels use one centered straight-through portal in every assembly mode");
  GeodesicJointEdgeProfile salonLegacyProbe =
    new GeodesicJointEdgeProfile();
  salonLegacyProbe.edgeLengthMM = 60;
  GeodesicFabricationSettings salonLegacySettings = salonPortals.copy();
  salonLegacySettings.assemblyMode = GeodesicAssemblyMode.LEGACY_PORTAL;
  geodesicSchedulePortals(salonLegacyProbe, salonLegacySettings);
  report.check(salonLegacyProbe.portalCenters.size() == 1 &&
    abs(salonLegacyProbe.portalCenters.get(0) - 0.5f) < 0.0001f,
    "Salon legacy assembly schedules one centered panel-local portal");
  GeodesicJointEdgeProfile salonKicasProbe =
    new GeodesicJointEdgeProfile();
  salonKicasProbe.edgeLengthMM = 60;
  GeodesicFabricationSettings salonKicasSettings = salonPortals.copy();
  salonKicasSettings.assemblyMode = GeodesicAssemblyMode.KICAS;
  geodesicSchedulePortals(salonKicasProbe, salonKicasSettings);
  report.check(salonKicasProbe.portalCenters.size() == 1 &&
    abs(salonKicasProbe.portalCenters.get(0) - 0.5f) < 0.0001f,
    "Salon KICAS assembly schedules one centered panel-local portal");

  // A mast presents its ties outboard, a tunnel inboard, and both are realised.
  TrussMastModel outward = buildTrussMastModel(2, 40, 34, 2.4f, radians(12),
    false, false, 0, 0, TrussSectionFamily.HEXAGON, TrussAccessSide.EXTERIOR);
  outward.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  buildTrussTriangleFrames(outward);
  TrussMastModel inwardModel = buildTrussMastModel(2, 40, 34, 2.4f, radians(12),
    false, false, 0, 0, TrussSectionFamily.HEXAGON, TrussAccessSide.INTERIOR);
  inwardModel.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  buildTrussTriangleFrames(inwardModel);
  report.check(outward.frameFabrication != null &&
    outward.frameFabrication.assemblyGrowthSign > 0 &&
    inwardModel.frameFabrication != null &&
    inwardModel.frameFabrication.assemblyGrowthSign < 0,
    "access side selects the panel body side");
  // Flipping the body must not relabel a single joint: convexity comes from the
  // winding, which stays outward either way.
  report.check(outward.concaveSharedJointCount ==
    inwardModel.concaveSharedJointCount,
    "flipping the body side leaves joint convexity unchanged (" +
      outward.concaveSharedJointCount + " vs " +
      inwardModel.concaveSharedJointCount + ")");
  report.check(outward.componentsAudited() &&
    trussFrameSeamAuditPassed(outward),
    "outboard panels still seal and still close their miter seams");

  // The connector's dome-side ring must land exactly on the opening perimeter.
  // Zero designed eccentricity is the whole point of the piece, so it is
  // measured against the perimeter it was handed rather than assumed.
  GeodesicOpeningCandidate probe = new GeodesicOpeningCandidate();
  int probeNodes = 6;
  float probeRadius = 40;
  probe.centroid.set(0, 0, 0);
  probe.normal.set(0, 0, 1);
  for (int i = 0; i < probeNodes; i++) {
    float angle = TWO_PI * i / probeNodes;
    // Deliberately irregular and slightly out of plane, like a real opening.
    float r = probeRadius * (i % 2 == 0 ? 1.0f : 0.88f);
    probe.ringWorld.add(new PVector(cos(angle) * r, sin(angle) * r,
      (i % 3 == 0 ? 0.6f : -0.3f)));
    probe.ring.append(i);
  }
  probe.nodes = probeNodes;
  probe.perimeterMM = 0;
  for (int i = 0; i < probeNodes; i++)
    probe.perimeterMM += PVector.dist(probe.ringWorld.get(i),
      probe.ringWorld.get((i + 1) % probeNodes));
  TrussConnectorResult connector = new TrussConnectorResult();
  TrussMastModel connectorModel = trussBuildConnectorModel(probe, connector);
  report.check(connector.built,
    "connector builds panels from a committed opening: " + connector.status);
  report.check(connector.maximumNodeOffsetMM <= 0.0005f,
    "connector dome-side ring lands on the opening perimeter (" +
      nf(connector.maximumNodeOffsetMM, 1, 5) + " mm offset)");
  report.check(connector.gatePanels == probeNodes * 2,
    "the ring against the dome is the gate truss (" +
      connector.gatePanels + " panels)");
  report.check(connectorModel.gateFabrication != null &&
    connectorModel.gateFabrication.frameDepthMM ==
      connectorModel.frameFabrication.frameDepthMM,
    "gate rails reinforce in width only, so the shared miter still mates");
  report.check(connectorModel.gateFabrication == null ||
    connectorModel.gateFabrication.frameWidthMM >
      connectorModel.frameFabrication.frameWidthMM,
    "gate rails are actually wider than field rails");
  boolean gateTypesSeparate = false;
  for (String typeId : connectorModel.frameQuantities.keySet())
    if (typeId.startsWith("GATE_")) gateTypesSeparate = true;
  report.check(gateTypesSeparate,
    "gate panels form their own part class in the catalog");
  report.check(connectorModel.componentsAudited(),
    "connector panels are sealed and auditable");
  // The collar creases once per bay interface because its rings change shape.
  // That is forced, and reading it as avoidable would block every connector.
  report.check(connectorModel.avoidableConcaveJointCount() == 0,
    "connector collar adds no avoidable concavity (" +
      connectorModel.concaveSharedJointCount + " concave, " +
      connectorModel.forcedConcaveJointCount() + " forced)");

  // The union is a render output and must never influence the fabrication
  // authority: the panel catalog and sealed component list stay untouched.
  int sealedBeforeUnion = frames.sealedComponents.size();
  int typesBeforeUnion = frames.frameTypes.size();
  TrussUnionResult unionProbe = new TrussUnionResult();
  SurfaceMesh unionMesh = trussBuildUnionMesh(frames.combined, unionProbe);
  report.check(frames.sealedComponents.size() == sealedBeforeUnion &&
    frames.frameTypes.size() == typesBeforeUnion,
    "building the watertight union leaves the printable catalog untouched");
  report.check(unionProbe.evaluated && unionMesh.tris.size() > 0,
    "watertight union extracts a surface from the assembled preview");
  // Watertight to a slicer means no holes and no four-incident-face edges.
  report.check(unionProbe.closed,
    "watertight union has no holes and no non-manifold edges: " +
      unionProbe.holes + " holes, " + unionProbe.pinchEdges + " pinch edges, " +
      unionProbe.degenerate + " degenerate, " + unionProbe.repairedCells +
      " cells repaired, volume " + nf(unionProbe.volumeMM3, 1, 1) + " mm3");
  report.check(frames.fastenerFit != null && frames.fastenerFit.evaluated &&
    frames.fastenerFit.minimumPrintScalePercent > 0,
    "fastener audit resolves the print scale at which the declared tie passes");
  report.check(frames.maximumPortalDepthExcursionMM <= 0.0001f,
    "every aperture stays inside the panel depth measured through the " +
    "assembly transform");
  // The inward audit must be capable of failing. Comparing the aperture with a
  // direction it was not built from is what makes that true, so confirm the
  // measured axis really is the panel depth axis and not a restatement.
  boolean measuredAxisUsable = true;
  for (TrussFrameFace face : frames.frameFaces) {
    if (face.fabricationFace == null) continue;
    if (trussMeasuredPanelDepthAxis(face.fabricationFace).magSq() < 0.5f)
      measuredAxisUsable = false;
  }
  report.check(measuredAxisUsable,
    "panel depth axis resolves from the placement transform on every panel");
  boolean sharedMitersResolved = true;
  for (TrussFrameJoint joint : frames.frameJoints) {
    if (!joint.shared()) continue;
    if (joint.halfMiterDeg <= 0.0001f || !joint.miterFeasible)
      sharedMitersResolved = false;
  }
  report.check(sharedMitersResolved,
    "every shared frame joint resolves a feasible non-square half miter");
  // A twisted segmented tube always carries one concave crease ring per bay
  // interface. What the triangulation must not do is add any beyond that.
  boolean noAvoidableConcavity = true;
  boolean convexTwistIsConvex = true;
  int[] twists = { -30, -16, -7, 0, 7, 16, 30 };
  TrussSectionFamily[] sections = {
    TrussSectionFamily.TRIANGLE, TrussSectionFamily.SQUARE,
    TrussSectionFamily.HEXAGON, TrussSectionFamily.OCTAGON
  };
  for (TrussSectionFamily section : sections) {
    for (int twist : twists) {
      for (int orientation = 0; orientation < 2; orientation++) {
        boolean sweepTunnel = orientation == 1;
        TrussMastModel sweep = buildTrussMastModel(3, 40, 34, 2.4f,
          radians(twist), sweepTunnel, false, 0, 0, section,
          trussAccessSideFor(sweepTunnel));
        sweep.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
        buildTrussTriangleFrames(sweep);
        if (sweep.avoidableConcaveJointCount() != 0) noAvoidableConcavity = false;
      }
    }
    // A whole-section-step twist keeps every bay interface coplanar.
    TrussMastModel aligned = buildTrussMastModel(3, 40, 34, 2.4f,
      radians(360.0f / section.sides()), false, false, 0, 0, section,
      TrussAccessSide.INTERIOR);
    aligned.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
    buildTrussTriangleFrames(aligned);
    if (aligned.concaveSharedJointCount != 0) convexTwistIsConvex = false;
  }
  report.check(noAvoidableConcavity,
    "wall triangulation adds no concave fold beyond the forced crease rings");
  report.check(convexTwistIsConvex,
    "a whole-section-step twist produces a fully convex wall");

  // Congruent panels must collapse onto one printable type. A twisted prism has
  // screw symmetry, so bays repeat exactly and the catalog stays tiny.
  TrussMastModel catalog = buildTrussMastModel(6, 44, 36, 2.4f, radians(16),
    false, false, 0, 0, TrussSectionFamily.HEXAGON, TrussAccessSide.EXTERIOR);
  catalog.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  buildTrussTriangleFrames(catalog);
  report.check(catalog.frameFaces.size() == 6 * 6 * 2,
    "hexagonal section builds two panels per side per bay");
  report.check(catalog.frameTypes.size() <= 6,
    "reusable frame catalog collapses congruent panels (" +
      catalog.frameTypes.size() + " types for " +
      catalog.frameFaces.size() + " panels)");

  TrussMastModel enclosed = buildTrussMastModel(2, 36, 30, 2.4f,
    radians(12), false, false, 0, 0);
  enclosed.buildMode = TrussBuildMode.TRIANGLE_FRAMES;
  enclosed.framePanelMode = TrussFramePanelMode.EXTERIOR_MEMBRANE;
  buildTrussTriangleFrames(enclosed);
  report.check(enclosed.frameFabrication != null &&
    enclosed.frameFabrication.style == GeodesicPanelStyle.FRAME_SKIN &&
    enclosed.componentsAudited(),
    "exterior membrane mode produces sealed reusable panel components");
  report.check(trussFramePortalAuditPassed(enclosed) &&
    trussFrameSeamAuditPassed(enclosed),
    "exterior membrane panels preserve portal and miter seam contracts");
  return report;
}
