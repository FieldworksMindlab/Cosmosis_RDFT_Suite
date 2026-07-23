/* Geodesic Salon: dome-first geodesic design and modular fabrication workspace. */

GeodesicModel geodesicModel = null;
GeodesicIntrinsicCoordinateSystem geodesicCoordinates = null;
GeodesicSeedFamily geodesicFamily = GeodesicSeedFamily.ICOSAHEDRAL;
GeodesicExtentMode geodesicExtent = GeodesicExtentMode.DOME;
GeodesicGrowthMode geodesicGrowth = GeodesicGrowthMode.SHELL_OVERWRAP;
GeodesicPanelStyle geodesicPanelStyle = GeodesicPanelStyle.FRAME_SKIN;
GeodesicReliefSide geodesicReliefSide = GeodesicReliefSide.INNER_REINFORCEMENT;
GeodesicSeamProfile geodesicSeamProfile =
  GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
GeodesicAssemblyMode geodesicAssemblyMode =
  GeodesicAssemblyMode.LEGACY_PORTAL;
GeodesicFormModifier geodesicModifier = GeodesicFormModifier.NONE;
int geodesicFrequency = 3;
float geodesicRadiusMM = 72.0f;
float geodesicCutRatio = 0.0f;
float geodesicStellationRatio = 0.18f;
float geodesicThicknessMM = 2.4f;
float geodesicReliefMM = 1.4f;
float geodesicFrameDepthMM = 13.0f;
float geodesicFrameWidthMM = 7.0f;
float geodesicSkinThicknessMM = 3.0f;
float geodesicPortalWidthMM = 5.2f;
float geodesicPortalHeightMM = 2.6f;
boolean geodesicFastenerPortals = true;
boolean geodesicEdgeCodesEnabled = true;
float geodesicEdgeBreakMM = 0.22f;
float geodesicEdgeCodeReliefMM = 0.45f;
float geodesicFront = 0.58f;
boolean geodesicFrontRunning = true;
boolean geodesicPlateauEnabled = true;
boolean geodesicGuideSvgEnabled = false;
int geodesicSelectedFace = 0;
String geodesicStatus = "geometry not built";
String geodesicLastExport = "";
String geodesicTestStatus = "not run";
int geodesicUniqueTypes = 0;
int[] geodesicLastAudit = { 0, 0, 0 };
GeodesicKitPreflight geodesicLastPreflight = null;
final int GEODESIC_SIDE_W = 392;
final int GEODESIC_CONTROLS_H = 680;
final int GEODESIC_VALUE_ROW_H = 43;

enum GeodesicFabricationControl {
  PANEL_DEPTH,
  FRAME_WIDTH,
  SKIN_THICKNESS,
  PORTAL_WIDTH,
  PORTAL_HEIGHT,
  CODE_HEIGHT,
  EDGE_CHAMFER,
  STELLATION_HEIGHT
}

GeodesicFabricationControl geodesicFabricationControl =
  GeodesicFabricationControl.PANEL_DEPTH;

class GeodesicKitPreflight {
  boolean ready = false;
  String status = "NOT CHECKED";
  String detail = "";
  SurfaceMesh combined = null;
  int[] shellAudit = { 0, 0, 0 };
  GeodesicPanelCatalog catalog = null;
  GeodesicFabricationSettings fabrication = null;
  GeodesicPartType failedType = null;
  int failedFaceId = -1;
  GeodesicGuideData guideData = null;
  GeodesicSeamAudit seamAudit = null;
}

GeodesicFabricationSettings currentGeodesicFabricationSettings() {
  GeodesicFabricationSettings settings = new GeodesicFabricationSettings();
  settings.assemblyMode = geodesicAssemblyMode;
  if (geodesicAssemblyMode == GeodesicAssemblyMode.KICAS &&
      geodesicModel != null)
    settings.kicasPlan = buildGeodesicKicasPlan(geodesicModel);
  settings.style = geodesicPanelStyle;
  settings.reliefSide = geodesicReliefSide;
  settings.frameDepthMM = geodesicFrameDepthMM;
  settings.requestedFrameDepthMM = geodesicFrameDepthMM;
  settings.frameWidthMM = geodesicFrameWidthMM;
  settings.skinThicknessMM = geodesicSkinThicknessMM;
  settings.fastenerPortals = geodesicFastenerPortals;
  settings.portalWidthMM = geodesicPortalWidthMM;
  settings.portalHeightMM = geodesicPortalHeightMM;
  settings.edgeCodesEnabled = geodesicEdgeCodesEnabled;
  settings.edgeBreakMM = geodesicEdgeBreakMM;
  settings.edgeCodeReliefMM = geodesicEdgeCodeReliefMM;
  settings.seamProfile = geodesicSeamProfile;
  settings.bubbleJoinEnabled = geodesicPlateauEnabled;
  return settings;
}

void initializeGeodesicSalon() {
  GeodesicTestReport report = runGeodesicCoreTests();
  geodesicTestStatus = report.summary();
  println("GEODESIC SALON CORE " + report.summary());
  for (String failure : report.failures) println("  FAIL " + failure);
  rebuildGeodesicSalonModel("initialized");
}

void runGeodesicFabricationMatrix(boolean minimalFeatures) {
  GeodesicSeedFamily savedFamily = geodesicFamily;
  GeodesicExtentMode savedExtent = geodesicExtent;
  GeodesicFormModifier savedModifier = geodesicModifier;
  int savedFrequency = geodesicFrequency;
  boolean savedPortals = geodesicFastenerPortals;
  boolean savedCodes = geodesicEdgeCodesEnabled;
  float savedEdgeBreak = geodesicEdgeBreakMM;
  boolean disablePortals = minimalFeatures ||
    dcrteCommandLineFlag("--geodesic-matrix-no-portals");
  boolean disableCodes = minimalFeatures ||
    dcrteCommandLineFlag("--geodesic-matrix-no-codes");
  boolean disableChamfer = minimalFeatures ||
    dcrteCommandLineFlag("--geodesic-matrix-no-chamfer");
  if (disablePortals) geodesicFastenerPortals = false;
  if (disableCodes) geodesicEdgeCodesEnabled = false;
  if (disableChamfer) geodesicEdgeBreakMM = 0;
  int ready = 0;
  int blocked = 0;
  int[] frequencies = { 1, 2, 3, 4, 6 };
  println("GEODESIC FABRICATION MATRIX BEGIN / " +
    (minimalFeatures ? "STRUCTURAL ONLY" :
      "FEATURES portals=" + !disablePortals +
      " codes=" + !disableCodes +
      " chamfer=" + !disableChamfer));
  for (GeodesicSeedFamily family : GeodesicSeedFamily.values()) {
    for (GeodesicExtentMode extent : GeodesicExtentMode.values()) {
      int modifierCount = geodesicFamilySupportsStellation(family) ? 2 : 1;
      for (int modifierIndex = 0; modifierIndex < modifierCount; modifierIndex++) {
        GeodesicFormModifier modifier = modifierIndex == 0 ?
          GeodesicFormModifier.NONE : GeodesicFormModifier.FACE_STELLATION;
        for (int frequency : frequencies) {
          geodesicFamily = family;
          geodesicExtent = extent;
          geodesicModifier = modifier;
          geodesicFrequency = frequency;
          rebuildGeodesicSalonModel("fabrication matrix");
          boolean passed = geodesicLastPreflight != null &&
            geodesicLastPreflight.ready;
          if (passed) ready++;
          else blocked++;
          println((passed ? "READY   " : "BLOCKED ") +
            family.label() + " " + extent.label() + " F" + frequency + " " +
            modifier.label() + " | " +
            (geodesicLastPreflight == null ? "NO PREFLIGHT" :
              geodesicLastPreflight.status + " | " +
              geodesicLastPreflight.detail));
          if (!passed && minimalFeatures && geodesicLastPreflight != null &&
              geodesicLastPreflight.failedType != null &&
              geodesicLastPreflight.failedType.mesh != null) {
            println("  OPEN " + geodesicBoundaryEdgeReport(
              geodesicLastPreflight.failedType.mesh, 8));
          }
          if (!passed && minimalFeatures && geodesicLastPreflight != null &&
              geodesicLastPreflight.combined != null &&
              geodesicLastPreflight.shellAudit[1] > 0) {
            println("  NONMANIFOLD " + geodesicNonmanifoldEdgeReport(
              geodesicLastPreflight.combined, 8));
          }
        }
      }
    }
  }
  geodesicFamily = savedFamily;
  geodesicExtent = savedExtent;
  geodesicModifier = savedModifier;
  geodesicFrequency = savedFrequency;
  geodesicFastenerPortals = savedPortals;
  geodesicEdgeCodesEnabled = savedCodes;
  geodesicEdgeBreakMM = savedEdgeBreak;
  rebuildGeodesicSalonModel("fabrication matrix restored");
  println("GEODESIC FABRICATION MATRIX " + ready + " READY / " +
    blocked + " BLOCKED");
}

void rebuildGeodesicSalonModel(String reason) {
  geodesicModel = buildGeodesicModel(geodesicFamily, geodesicExtent,
    geodesicFrequency, geodesicRadiusMM, geodesicCutRatio,
    geodesicModifier, geodesicStellationRatio);
  geodesicCoordinates = new GeodesicIntrinsicCoordinateSystem(geodesicModel);
  geodesicSelectedFace = geodesicModel.faces.size() == 0 ? 0 :
    constrain(geodesicSelectedFace, 0, geodesicModel.faces.size() - 1);
  geodesicLastPreflight = preflightGeodesicSalonKit("PREVIEW");
  geodesicUniqueTypes = geodesicLastPreflight.catalog == null ?
    0 : geodesicLastPreflight.catalog.types.size();
  geodesicLastAudit = geodesicLastPreflight.shellAudit;
  refreshGeodesicPaintPlan();
  if (geodesicLastPreflight.failedType != null) {
    geodesicSelectedFace = constrain(geodesicLastPreflight.failedType.representativeFaceId,
      0, max(0, geodesicModel.faces.size() - 1));
  } else if (geodesicLastPreflight.failedFaceId >= 0) {
    geodesicSelectedFace = constrain(geodesicLastPreflight.failedFaceId,
      0, max(0, geodesicModel.faces.size() - 1));
  }
  geodesicStatus = geodesicLastPreflight.ready ?
    "KIT READY / " + reason : geodesicLastPreflight.status;
}

GeodesicKitPreflight preflightGeodesicSalonKit(String stamp) {
  GeodesicKitPreflight result = new GeodesicKitPreflight();
  if (geodesicModel == null || !geodesicModel.valid) {
    result.status = "DOMAIN BLOCKED";
    result.detail = geodesicModel == null ? "NO MODEL" : geodesicModel.validation;
    return result;
  }

  GeodesicFabricationSettings fabrication = geodesicResolveKitFabricationSettings(
    geodesicModel, currentGeodesicFabricationSettings());
  result.fabrication = fabrication;
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS &&
      (fabrication.kicasPlan == null || !fabrication.kicasPlan.valid)) {
    result.status = "KIT BLOCKED / KICAS PLAN";
    result.detail = fabrication.kicasPlan == null ? "PLAN MISSING" :
      fabrication.kicasPlan.validation;
    return result;
  }
  result.combined = buildGeodesicCombinedShell(geodesicModel, geodesicThicknessMM);
  result.shellAudit = result.combined.manifoldAudit();
  if (result.shellAudit[0] != 0 || result.shellAudit[1] != 0 || result.shellAudit[2] != 0) {
    result.status = "KIT BLOCKED / COMBINED SHELL";
    result.detail = "BOUNDARY " + result.shellAudit[0] + "  NONMANIFOLD " +
      result.shellAudit[1] + "  DEGENERATE " + result.shellAudit[2];
    return result;
  }

  if (fabrication.style != GeodesicPanelStyle.SOLID &&
      fabrication.seamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER) {
    for (GeodesicFace modelFace : geodesicModel.faces) {
      GeodesicFabricationFace fabricatedFace =
        geodesicFabricationFace(geodesicModel, modelFace, fabrication);
      for (GeodesicJointEdgeProfile joint : fabricatedFace.joints) {
        if (joint.neighborFaceId < 0 ||
            joint.miterFeasibleAtResolvedDimensions) continue;
        result.failedFaceId = modelFace.id;
        result.status = "KIT BLOCKED / MITER DIMENSIONS";
        result.detail = "FACE " + modelFace.id + " EDGE " + joint.edgeIndex +
          " NEED " + nf(joint.recommendedHalfMiterDeg, 1, 1) + "deg / " +
          nf(joint.recommendedMiterInsetMM, 1, 2) + "mm / WIDTH " +
          nf(fabricatedFace.resolvedFabrication.frameWidthMM, 1, 2);
        return result;
      }
    }
    result.seamAudit = geodesicAuditAssembledSeams(geodesicModel, fabrication);
    if (result.seamAudit == null || !result.seamAudit.valid) {
      result.failedFaceId = result.seamAudit == null ? -1 :
        result.seamAudit.failedFaceA;
      result.status = "KIT BLOCKED / ASSEMBLED SEAM";
      result.detail = result.seamAudit == null ? "SEAM AUDIT MISSING" :
        "EDGE " + result.seamAudit.failedEdgeId + " FACES " +
        result.seamAudit.failedFaceA + "/" + result.seamAudit.failedFaceB +
        " GAP " + nf(result.seamAudit.failedGapMM, 1, 3) + "mm" +
        " @ DEPTH " + nf(result.seamAudit.failedDepthFraction, 1, 2) +
        " EDGE " + nf(result.seamAudit.failedEdgeFraction, 1, 2) +
        " / MAX CROSS " +
        nf(result.seamAudit.maximumCrossSeamGapMM, 1, 3) + "mm" +
        " EDGE " + result.seamAudit.maximumGapEdgeId +
        " @ " + nf(result.seamAudit.maximumGapDepthFraction, 1, 2) +
        "/" + nf(result.seamAudit.maximumGapEdgeFraction, 1, 2) +
        " / STATION " +
        nf(result.seamAudit.maximumTangentialGapMM, 1, 3) +
        " / DEPTH " +
        nf(result.seamAudit.failedRequestedDepthMM, 1, 2) + ">" +
        nf(result.seamAudit.failedResolvedDepthAMM, 1, 2) + "/" +
        nf(result.seamAudit.failedResolvedDepthBMM, 1, 2) +
        " WIDTH " +
        nf(result.seamAudit.failedResolvedWidthAMM, 1, 2) + "/" +
        nf(result.seamAudit.failedResolvedWidthBMM, 1, 2) +
        " NORMAL " +
        nf(result.seamAudit.failedNormalAngleDeg, 1, 2) +
        " LINE " +
        nf(result.seamAudit.failedProfileLineAngleDeg, 1, 3) +
        " CLASS " +
        (result.seamAudit.failedNeighborSideA > 0.0001f ||
          result.seamAudit.failedNeighborSideB > 0.0001f ?
          "CONCAVE" : "CONVEX");
      return result;
    }
  }
  result.catalog = buildGeodesicPanelCatalog(geodesicModel,
    fabrication, geodesicGrowth, geodesicReliefMM);
  if (result.catalog.types.size() == 0) {
    result.status = "KIT BLOCKED / EMPTY PART CATALOG";
    result.detail = "NO REUSABLE PANEL TYPES";
    return result;
  }
  for (GeodesicPartType type : result.catalog.types) {
    if (type.mesh == null || type.mesh.tris.size() == 0 || type.audit == null ||
        type.audit[0] != 0 || type.audit[1] != 0 || type.audit[2] != 0) {
      result.failedType = type;
      int boundary = type.audit == null ? -1 : type.audit[0];
      int nonmanifold = type.audit == null ? -1 : type.audit[1];
      int degenerate = type.audit == null ? -1 : type.audit[2];
      result.status = "KIT BLOCKED / " + type.typeId + " FACE " + type.representativeFaceId;
      result.detail = "BOUNDARY " + boundary + "  NONMANIFOLD " +
        nonmanifold + "  DEGENERATE " + degenerate;
      return result;
    }
  }

  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    for (GeodesicFace modelFace : geodesicModel.faces) {
      GeodesicPart placementPart = buildGeodesicFabricatedPart(
        geodesicModel, modelFace, fabrication, geodesicGrowth,
        geodesicReliefMM);
      if (placementPart.mesh == null || placementPart.mesh.tris.size() == 0 ||
          placementPart.audit == null || placementPart.audit[0] != 0 ||
          placementPart.audit[1] != 0 || placementPart.audit[2] != 0) {
        result.failedFaceId = modelFace.id;
        int boundary = placementPart.audit == null ? -1 :
          placementPart.audit[0];
        int nonmanifold = placementPart.audit == null ? -1 :
          placementPart.audit[1];
        int degenerate = placementPart.audit == null ? -1 :
          placementPart.audit[2];
        result.status = "KIT BLOCKED / KICAS " +
          fabrication.kicasPlan.labelForFace(modelFace.id);
        result.detail = "BOUNDARY " + boundary + "  NONMANIFOLD " +
          nonmanifold + "  DEGENERATE " + degenerate;
        return result;
      }
      for (GeodesicJointEdgeProfile joint :
          placementPart.fabricationFace.joints) {
        if (joint.portalCenters.size() != 1 ||
            abs(joint.portalCenters.get(0) - 0.5f) > 0.0001f) {
          result.failedFaceId = modelFace.id;
          result.status = "KIT BLOCKED / KICAS CENTER PORTAL";
          result.detail = "FACE " + modelFace.id + " EDGE " +
            joint.edgeIndex + " PORTALS " + joint.portalCenters;
          return result;
        }
      }
    }
  }

  result.guideData = buildGeodesicGuideData(geodesicModel, result.catalog, stamp);
  if (result.guideData == null || !result.guideData.validation.valid()) {
    result.status = "KIT BLOCKED / ASSEMBLY GUIDE";
    result.detail = result.guideData == null || result.guideData.validation.errors.size() == 0 ?
      "GUIDE PREFLIGHT FAILED" : result.guideData.validation.errors.get(0);
    return result;
  }
  result.ready = true;
  result.status = "KIT READY";
  int codeFallbacks = result.catalog.physicalEdgeCodeFallbackCount();
  result.detail = result.catalog.types.size() + " REUSABLE TYPES / SHELL 0/0/0" +
    (result.seamAudit != null && result.seamAudit.evaluated ?
      " / SEAM " +
      nf(result.seamAudit.maximumCrossSeamGapMM, 1, 3) + "mm" : "") +
    (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS ?
      " / " + fabrication.kicasPlan.steps.size() + " ORDERED PARTS" : "") +
    (codeFallbacks > 0 ? " / CODE FALLBACK " + codeFallbacks : "");
  return result;
}

void updateGeodesicSalon() {
  if (geodesicFrontRunning && !paused) geodesicFront = (simT * 0.105f) % 1.0f;
}

void drawGeodesicSalon(int x, int y, int w, int h) {
  updateGeodesicSalon();
  drawPanelShell(x, y, w, h, "GEODESIC SALON");
  int sideW = GEODESIC_SIDE_W;
  int sceneX = x + 24;
  int sceneY = y + 52;
  int sceneW = w - sideW - 72;
  int sceneH = h - 76;
  int sideX = sceneX + sceneW + 24;
  drawGeodesicSalonScene(sceneX, sceneY, sceneW, sceneH);
  drawGeodesicSalonControls(sideX, sceneY, sideW, sceneH);
}

void drawGeodesicSalonScene(int x, int y, int w, int h) {
  pushStyle();
  fill(3, 8, 12);
  stroke(31, 70, 78);
  rect(x, y, w, h, 6);
  fill(112, 224, 210);
  textAlign(LEFT, TOP);
  textSize(10);
  text("DOME ASSEMBLY FIELD", x + 14, y + 12);
  fill(96, 132, 142);
  textSize(8);
  text("deterministic geodesic subdivision / face-local intrinsic coordinates", x + 14, y + 29);

  if (geodesicModel == null || geodesicModel.faces.size() == 0) {
    fill(255, 100, 115);
    textSize(12);
    text("NO VALID GEODESIC MODEL", x + 24, y + 72);
    popStyle();
    return;
  }

  int drawTop = y + 42;
  int drawH = h - 106;
  float scaleFactor = min(w, drawH) * 0.40f / max(1, geodesicModel.radius);
  float centerZ = geodesicModel.extent == GeodesicExtentMode.DOME ?
    (geodesicModel.radius + geodesicModel.cutZ) * 0.40f : 0;
  pushMatrix();
  translate(x + w * 0.5f, drawTop + drawH * 0.53f, 0);
  rotateX(-0.68f);
  rotateZ(0.48f + simT * 0.018f);
  scale(scaleFactor);
  translate(0, 0, -centerZ);
  hint(ENABLE_DEPTH_TEST);

  noStroke();
  for (GeodesicFace face : geodesicModel.faces) {
    float arrival = geodesicFaceArrival(face);
    boolean active = arrival <= geodesicFront;
    boolean selected = face.id == geodesicSelectedFace;
    if (geodesicPaintEnabled) {
      int paint = geodesicPaintDisplayColor(face.id);
      fill(red(paint), green(paint), blue(paint), 214);
    } else if (selected) fill(255, 205, 66, 225);
    else if (active) {
      float phase = (face.parentFace * 0.173f + arrival * 0.77f) % 1.0f;
      if (phase < 0.34f) fill(27, 214, 190, 132);
      else if (phase < 0.68f) fill(74, 154, 238, 126);
      else fill(232, 84, 166, 116);
    } else fill(12, 34, 40, 94);
    PVector a = geodesicModel.vertices.get(face.a).position;
    PVector b = geodesicModel.vertices.get(face.b).position;
    PVector c = geodesicModel.vertices.get(face.c).position;
    beginShape(TRIANGLES);
    vertex(a.x, a.y, a.z); vertex(b.x, b.y, b.z); vertex(c.x, c.y, c.z);
    endShape();
  }

  stroke(70, 222, 211, 190);
  strokeWeight(0.48f / scaleFactor + 0.12f);
  beginShape(LINES);
  for (GeodesicEdge edge : geodesicModel.edges) {
    PVector a = geodesicModel.vertices.get(edge.a).position;
    PVector b = geodesicModel.vertices.get(edge.b).position;
    vertex(a.x, a.y, a.z); vertex(b.x, b.y, b.z);
  }
  endShape();
  stroke(255, 190, 50, 235);
  strokeWeight(1.25f / scaleFactor + 0.18f);
  beginShape(LINES);
  for (GeodesicEdge edge : geodesicModel.edges) if (edge.boundary()) {
    PVector a = geodesicModel.vertices.get(edge.a).position;
    PVector b = geodesicModel.vertices.get(edge.b).position;
    vertex(a.x, a.y, a.z); vertex(b.x, b.y, b.z);
  }
  endShape();

  drawGeodesicSelectedFaceField(scaleFactor);
  if (geodesicPlateauEnabled) drawGeodesicPlateauJunction(scaleFactor);
  popMatrix();
  hint(DISABLE_DEPTH_TEST);

  fill(125, 160, 170);
  textAlign(LEFT, TOP);
  textSize(9);
  text("front " + nf(geodesicFront, 1, 3) + "  |  selected face " +
    (geodesicModel.faces.size() == 0 ? "-" : geodesicSelectedFace) + "  |  " +
    geodesicGrowth.label() +
    (geodesicPaintEnabled ? "  |  PAINT " +
      geodesicSelectedPaintLabel() : ""), x + 14, y + h - 48);
  boolean preflightReady = geodesicLastPreflight != null && geodesicLastPreflight.ready;
  fill(!geodesicModel.valid ? color(255, 92, 110) :
    (preflightReady ? color(100, 235, 200) : color(255, 194, 72)));
  text(geodesicStatus, x + 14, y + h - 30);
  textAlign(RIGHT, TOP);
  fill(125, 160, 170);
  text("Plateau target " + (geodesicPlateauEnabled ? nf(geodesicPlateauAngleDegrees(), 3, 3) + " deg" : "off"),
    x + w - 14, y + h - 30);
  popStyle();
}

float geodesicFaceArrival(GeodesicFace face) {
  if (geodesicModel == null) return 0;
  if (geodesicGrowth == GeodesicGrowthMode.SHELL_OVERWRAP) {
    return constrain((geodesicModel.radius - face.centroid.z) / max(0.001f, 2.0f * geodesicModel.radius), 0, 1);
  }
  float azimuth = (atan2(face.centroid.y, face.centroid.x) + PI) / TWO_PI;
  float radialBand = 0.5f + 0.5f * sin(azimuth * TWO_PI * max(1, geodesicFrequency));
  return constrain(0.22f * geodesicFaceIndex01(face.id) + 0.78f * radialBand, 0, 1);
}

float geodesicFaceIndex01(int faceId) {
  return geodesicModel == null || geodesicModel.faces.size() <= 1 ? 0 :
    faceId / (float)(geodesicModel.faces.size() - 1);
}

void drawGeodesicSelectedFaceField(float displayScale) {
  if (geodesicModel == null || geodesicModel.faces.size() == 0) return;
  GeodesicFace face = geodesicModel.faces.get(constrain(geodesicSelectedFace, 0, geodesicModel.faces.size() - 1));
  PVector a = geodesicModel.vertices.get(face.a).position;
  PVector b = geodesicModel.vertices.get(face.b).position;
  PVector c = geodesicModel.vertices.get(face.c).position;
  PVector center = face.centroid;
  stroke(255, 226, 92, 240);
  strokeWeight(1.15f / displayScale + 0.15f);
  noFill();
  for (int ring = 1; ring <= 4; ring++) {
    float t = ring / 4.0f;
    PVector pa = PVector.lerp(center, a, t);
    PVector pb = PVector.lerp(center, b, t);
    PVector pc = PVector.lerp(center, c, t);
    beginShape();
    vertex(pa.x, pa.y, pa.z); vertex(pb.x, pb.y, pb.z); vertex(pc.x, pc.y, pc.z);
    endShape(CLOSE);
  }
}

void drawGeodesicPlateauJunction(float displayScale) {
  if (geodesicModel == null || geodesicModel.faces.size() == 0) return;
  GeodesicFace face = geodesicModel.faces.get(constrain(geodesicSelectedFace, 0, geodesicModel.faces.size() - 1));
  PVector center = face.centroid.copy();
  float length = geodesicModel.radius * 0.20f;
  PVector[] rays = {
    new PVector(1, 1, 1), new PVector(1, -1, -1),
    new PVector(-1, 1, -1), new PVector(-1, -1, 1)
  };
  stroke(255, 84, 144, 240);
  strokeWeight(1.25f / displayScale + 0.16f);
  beginShape(LINES);
  for (PVector ray : rays) {
    ray.normalize().mult(length);
    vertex(center.x, center.y, center.z);
    vertex(center.x + ray.x, center.y + ray.y, center.z + ray.z);
  }
  endShape();
  noStroke();
  fill(255, 220, 72);
  pushMatrix();
  translate(center.x, center.y, center.z);
  sphereDetail(6);
  sphere(max(0.35f, 1.8f / displayScale));
  popMatrix();
}

void drawGeodesicSalonControls(int x, int y, int w, int h) {
  int controlsH = GEODESIC_CONTROLS_H;
  drawReadoutPanel(x, y, w, controlsH, "GEODESIC BUILD");
  int bx = x + 16;
  int bw = w - 32;
  int gap = 8;
  int half = (bw - gap) / 2;
  int third = (bw - gap * 2) / 3;
  int yy = y + 42;
  drawButton(bx, yy, third, 26, "REBUILD", color(32, 105, 84));
  drawButton(bx + third + gap, yy, third, 26, "EXPORT KIT",
    color(98, 75, 36));
  drawButton(bx + (third + gap) * 2, yy, third, 26, "PLATE KIT",
    color(112, 75, 35));
  yy += 34;
  drawButton(bx, yy, bw, 22, geodesicGuideSvgEnabled ? "ASSEMBLY GUIDE SVG ON" : "ASSEMBLY GUIDE SVG OFF",
    geodesicGuideSvgEnabled ? color(35, 114, 94) : color(55, 58, 66));
  yy += 30;
  drawButton(bx, yy, bw, 22,
    geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      "ASSEMBLY KICAS LOCK + CENTER TIE" :
      "ASSEMBLY LEGACY PORTAL KIT",
    geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      color(112, 75, 35) : color(42, 72, 82));
  yy += 30;
  drawButton(bx, yy, third, 22, "FRAME",
    geodesicPanelStyle == GeodesicPanelStyle.OPEN_FRAME ? color(38, 105, 87) : color(55, 58, 66));
  drawButton(bx + third + gap, yy, third, 22, "FRAME + SKIN",
    geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN ? color(38, 105, 87) : color(55, 58, 66));
  drawButton(bx + (third + gap) * 2, yy, third, 22, "SOLID",
    geodesicPanelStyle == GeodesicPanelStyle.SOLID ? color(38, 105, 87) : color(55, 58, 66));
  yy += 30;
  drawButton(bx, yy, half, 22,
    geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      "CENTER TIE PORTALS REQUIRED" :
      (geodesicFastenerPortals ? "PORTALS ON" : "PORTALS OFF"),
    geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      color(112, 75, 35) :
      (geodesicFastenerPortals ? color(112, 75, 35) : color(55, 58, 66)));
  boolean reliefAvailable = geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN;
  String reliefLabel = reliefAvailable ? geodesicReliefSide.label() : "RELIEF N/A";
  int reliefColor = !reliefAvailable ? color(55, 58, 66) :
    (geodesicReliefSide == GeodesicReliefSide.EXTERIOR_CROWN ?
      color(112, 75, 35) : color(38, 105, 87));
  drawButton(bx + half + gap, yy, half, 22, reliefLabel, reliefColor);
  yy += 30;
  drawButton(bx, yy, half, 22, "FAMILY <", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "FAMILY >", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, "seed family", geodesicFamily.label());
  yy += GEODESIC_VALUE_ROW_H;
  boolean modifierAvailable = geodesicFamilySupportsStellation(geodesicFamily);
  drawButton(bx, yy, bw, 22,
    modifierAvailable ?
      (geodesicModifier == GeodesicFormModifier.FACE_STELLATION ?
        "STELLATION ON" : "STELLATION OFF") :
      "STELLATION N/A FOR FAMILY",
    !modifierAvailable ? color(55, 58, 66) :
    (geodesicModifier == GeodesicFormModifier.FACE_STELLATION ?
      color(112, 75, 35) : color(42, 72, 82)));
  geodesicControlValue(bx, yy + 24, bw,
    modifierAvailable ? "face stellation height" : "family basis",
    modifierAvailable ? nf(geodesicStellationRatio * 100.0f, 1, 0) + "% radius" :
      "triangulated polygon seed");
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, half, 22, "FREQ -", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "FREQ +", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, "frequency", str(geodesicFrequency));
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, half, 22, "FORM", geodesicExtent == GeodesicExtentMode.DOME ? color(38, 105, 87) : color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "GROWTH", geodesicGrowth == GeodesicGrowthMode.CENTER_TO_EDGE ? color(112, 75, 35) : color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, geodesicExtent.label(), geodesicGrowth.label());
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, half, 22, "CAP DEEPER", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "CAP SHALLOWER", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, "cut plane ratio", nf(geodesicCutRatio, 1, 2));
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, half, 22, "RADIUS -", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "RADIUS +", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, "radius", nf(geodesicRadiusMM, 1, 1) + " mm");
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, half, 22, "PARAM <", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, "PARAM >", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, "fabrication parameter",
    geodesicFabricationControlLabel());
  yy += GEODESIC_VALUE_ROW_H;
  String adjustLabel = geodesicFabricationControlShortLabel();
  drawButton(bx, yy, half, 22, adjustLabel + " -", color(42, 72, 82));
  drawButton(bx + half + gap, yy, half, 22, adjustLabel + " +", color(42, 72, 82));
  geodesicControlValue(bx, yy + 24, bw, geodesicFabricationControlLabel(),
    geodesicFabricationControlValue());
  yy += GEODESIC_VALUE_ROW_H;
  drawButton(bx, yy, third, 22, geodesicPlateauEnabled ? "PLATEAU ON" : "PLATEAU OFF",
    geodesicPlateauEnabled ? color(112, 50, 76) : color(55, 58, 66));
  drawButton(bx + third + gap, yy, third, 22,
    geodesicSeamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER ?
      "SEAM MITERED" : "SEAM SQUARE",
    geodesicSeamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER ?
      color(112, 75, 35) : color(55, 58, 66));
  drawButton(bx + (third + gap) * 2, yy, third, 22,
    geodesicFrontRunning ? "FRONT RUN" : "FRONT HOLD",
    geodesicFrontRunning ? color(38, 105, 87) : color(55, 58, 66));
  yy += 30;
  drawButton(bx, yy, third, 22, "FACE <", color(42, 72, 82));
  drawButton(bx + third + gap, yy, third, 22, "FRONT +", color(42, 72, 82));
  drawButton(bx + (third + gap) * 2, yy, third, 22, "FACE >", color(42, 72, 82));
  yy += 30;
  drawButton(bx, yy, third, 22,
    geodesicPaintEnabled ? "PAINT ON" : "PAINT OFF",
    geodesicPaintEnabled ? color(112, 50, 76) : color(55, 58, 66));
  drawButton(bx + third + gap, yy, third, 22, "SCHEME <",
    color(42, 72, 82));
  drawButton(bx + (third + gap) * 2, yy, third, 22, "SCHEME >",
    color(42, 72, 82));
  yy += 30;
  int quarter = (bw - gap * 3) / 4;
  drawButton(bx, yy, quarter, 22, "COLORS -", color(42, 72, 82));
  drawButton(bx + quarter + gap, yy, quarter, 22, "COLORS +",
    color(42, 72, 82));
  drawButton(bx + (quarter + gap) * 2, yy, quarter, 22, "PHASE -",
    color(42, 72, 82));
  drawButton(bx + (quarter + gap) * 3, yy, quarter, 22, "PHASE +",
    color(42, 72, 82));

  int statsY = y + controlsH + 14;
  int statsH = h - controlsH - 14;
  drawReadoutPanel(x, statsY, w, statsH, "DOMAIN / FABRICATION");
  int sy = statsY + 32;
  int metricStep = 10;
  geodesicMetricLine(x + 16, sy, w - 32, "domain qualification", geodesicModel != null && geodesicModel.valid ? "VALID" : "BLOCKED"); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "kit preflight",
    geodesicLastPreflight == null ? "NOT CHECKED" : geodesicLastPreflight.status); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "preflight detail",
    geodesicLastPreflight == null ? "-" : geodesicLastPreflight.detail); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "V / E / F", geodesicModel == null ? "-" : geodesicModel.vertices.size() + " / " + geodesicModel.edges.size() + " / " + geodesicModel.faces.size()); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "Euler / boundary", geodesicModel == null ? "-" : geodesicModel.eulerCharacteristic + " / " + geodesicModel.boundaryEdges); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "rim chain",
    geodesicModel == null ? "-" :
    geodesicModel.boundaryLoopCount + " loop / " +
    (geodesicModel.boundaryChainClosed &&
      geodesicModel.boundaryChainSimple ? "VALID" : "BLOCKED")); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "Gauss-Bonnet residual",
    geodesicModel == null ? "-" :
    nf(geodesicModel.gaussBonnetResidual, 1, 6) + " rad"); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "five-valent", geodesicModel == null ? "-" : str(geodesicModel.fiveValentVertices)); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "reusable types", str(geodesicUniqueTypes)); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "guide / paint",
    (geodesicGuideSvgEnabled ? "PNG + SVG" : "PNG ONLY") + " / " +
    (geodesicPaintEnabled ?
      geodesicPaintScheme.label() + " C" +
      currentGeodesicPaintPlan().effectiveColorCount : "OFF"));
  sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "plate kit",
    geodesicLastPlateKitResult == null ?
      "ON DEMAND / 256x256" : geodesicLastPlateKitResult.status);
  sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "assembly mode",
    geodesicAssemblyMode.label()); sy += metricStep;
  GeodesicFabricationSettings displayFabrication =
    geodesicLastPreflight != null && geodesicLastPreflight.fabrication != null ?
    geodesicLastPreflight.fabrication : currentGeodesicFabricationSettings();
  geodesicMetricLine(x + 16, sy, w - 32, "panel / relief",
    displayFabrication.style.label() + " / " +
    (displayFabrication.style == GeodesicPanelStyle.FRAME_SKIN ?
      displayFabrication.reliefSide.label() : "N/A")); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "portals / mate IDs",
    (geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      "1 CENTER/EDGE / P###" :
      (geodesicFastenerPortals ? "ON" : "OFF") + " / " +
      geodesicMateCodeFabricationStatus())); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "seam profile", geodesicSelectedSeamProfile()); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "assembled seam audit",
    geodesicLastPreflight == null || geodesicLastPreflight.seamAudit == null ?
      "N/A" :
      (geodesicLastPreflight.seamAudit.valid ? "PASS " : "BLOCKED ") +
      nf(geodesicLastPreflight.seamAudit.maximumCrossSeamGapMM, 1, 3) +
      " mm"); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "selected effective", geodesicSelectedEffectiveDimensions()); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "assembly 100%",
    geodesicModel == null ? "-" : geodesicSlicerScaleDimensions(geodesicModel,
      geodesicResolvedFabricationScale(), 100)); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "shell audit", geodesicLastAudit[0] + "/" + geodesicLastAudit[1] + "/" + geodesicLastAudit[2]); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "core tests", geodesicTestStatus); sy += metricStep;
  geodesicMetricLine(x + 16, sy, w - 32, "fingerprint", geodesicModel == null ? "-" : geodesicModel.fingerprint);
}

String geodesicFabricationControlLabel() {
  if (geodesicFabricationControl == GeodesicFabricationControl.PANEL_DEPTH)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "shell thickness" : "frame depth";
  if (geodesicFabricationControl == GeodesicFabricationControl.FRAME_WIDTH) return "frame width";
  if (geodesicFabricationControl == GeodesicFabricationControl.SKIN_THICKNESS) return "skin thickness";
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_WIDTH) return "portal width";
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_HEIGHT) return "portal height";
  if (geodesicFabricationControl == GeodesicFabricationControl.CODE_HEIGHT) return "mate-code raise";
  if (geodesicFabricationControl == GeodesicFabricationControl.EDGE_CHAMFER) return "edge chamfer";
  return "stellation height";
}

String geodesicMateCodeFabricationStatus() {
  if (!geodesicEdgeCodesEnabled) return "OFF";
  if (geodesicLastPreflight == null || geodesicLastPreflight.catalog == null)
    return "RAISED / AUDIT PENDING";
  int fallback = geodesicLastPreflight.catalog.physicalEdgeCodeFallbackCount();
  return fallback == 0 ? "RAISED INTERIOR" :
    "RAISED + " + fallback + " BOM FALLBACK";
}

String geodesicFabricationControlShortLabel() {
  if (geodesicFabricationControl == GeodesicFabricationControl.PANEL_DEPTH)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "SHELL" : "DEPTH";
  if (geodesicFabricationControl == GeodesicFabricationControl.FRAME_WIDTH) return "WIDTH";
  if (geodesicFabricationControl == GeodesicFabricationControl.SKIN_THICKNESS) return "SKIN";
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_WIDTH) return "PORTAL W";
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_HEIGHT) return "PORTAL H";
  if (geodesicFabricationControl == GeodesicFabricationControl.CODE_HEIGHT) return "CODE";
  if (geodesicFabricationControl == GeodesicFabricationControl.EDGE_CHAMFER) return "CHAMFER";
  return "STELLATE";
}

String geodesicFabricationControlValue() {
  if (geodesicFabricationControl == GeodesicFabricationControl.PANEL_DEPTH)
    return nf(geodesicPanelStyle == GeodesicPanelStyle.SOLID ?
      geodesicThicknessMM : geodesicFrameDepthMM, 1, 2) + " mm";
  if (geodesicFabricationControl == GeodesicFabricationControl.FRAME_WIDTH)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "N/A IN SOLID" :
      nf(geodesicFrameWidthMM, 1, 2) + " mm";
  if (geodesicFabricationControl == GeodesicFabricationControl.SKIN_THICKNESS)
    return geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN ?
      nf(geodesicSkinThicknessMM, 1, 2) + " mm" : "N/A IN " + geodesicPanelStyle.label();
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_WIDTH)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "N/A IN SOLID" :
      nf(geodesicPortalWidthMM, 1, 2) + " mm";
  if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_HEIGHT)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "N/A IN SOLID" :
      nf(geodesicPortalHeightMM, 1, 2) + " mm";
  if (geodesicFabricationControl == GeodesicFabricationControl.CODE_HEIGHT)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "N/A IN SOLID" :
      nf(geodesicEdgeCodeReliefMM, 1, 2) + " mm";
  if (geodesicFabricationControl == GeodesicFabricationControl.EDGE_CHAMFER)
    return geodesicPanelStyle == GeodesicPanelStyle.SOLID ? "N/A IN SOLID" :
      nf(geodesicEdgeBreakMM, 1, 2) + " mm";
  if (!geodesicFamilySupportsStellation(geodesicFamily)) return "N/A FOR FAMILY";
  return nf(geodesicStellationRatio * 100.0f, 1, 0) + "% radius";
}

String geodesicSelectedEffectiveDimensions() {
  if (geodesicModel == null || geodesicModel.faces.size() == 0) return "-";
  GeodesicFabricationSettings settings =
    geodesicLastPreflight != null && geodesicLastPreflight.fabrication != null ?
    geodesicLastPreflight.fabrication : currentGeodesicFabricationSettings();
  GeodesicFace selected = geodesicModel.faces.get(constrain(geodesicSelectedFace,
    0, geodesicModel.faces.size() - 1));
  GeodesicFabricationFace face = geodesicFabricationFace(geodesicModel, selected,
    settings);
  GeodesicFabricationSettings resolved = face.resolvedFabrication;
  if (resolved == null) return "-";
  if (resolved.style == GeodesicPanelStyle.SOLID)
    return "solid " + nf(resolved.skinThicknessMM, 1, 2) + " mm";
  return "D" + nf(resolved.frameDepthMM, 1, 2) +
    " W" + nf(resolved.frameWidthMM, 1, 2) +
    " S" + (resolved.style == GeodesicPanelStyle.OPEN_FRAME ? "OPEN" :
      nf(resolved.skinThicknessMM, 1, 2)) +
    " B" + nf(resolved.edgeBreakMM, 1, 2) +
    (resolved.fabricationScaleAutoRaised ?
      " X" + nf(resolved.fabricationScale, 1, 2) : "") +
    (resolved.miterDepthAutoCapped ? " CAPPED" : "");
}

float geodesicResolvedFabricationScale() {
  return geodesicLastPreflight != null &&
    geodesicLastPreflight.fabrication != null ?
    max(1.0f, geodesicLastPreflight.fabrication.fabricationScale) : 1.0f;
}

String geodesicSelectedSeamProfile() {
  if (geodesicModel == null || geodesicModel.faces.size() == 0) return "-";
  GeodesicFace selected = geodesicModel.faces.get(constrain(geodesicSelectedFace,
    0, geodesicModel.faces.size() - 1));
  GeodesicFabricationSettings settings =
    geodesicLastPreflight != null && geodesicLastPreflight.fabrication != null ?
    geodesicLastPreflight.fabrication : currentGeodesicFabricationSettings();
  GeodesicFabricationFace face = geodesicFabricationFace(geodesicModel, selected,
    settings);
  GeodesicFabricationSettings resolved = face.resolvedFabrication;
  if (resolved != null && resolved.style == GeodesicPanelStyle.SOLID)
    return "SOLID / N/A";
  float maximumHalfMiter = 0;
  float maximumInset = 0;
  boolean feasible = true;
  int sharedEdges = 0;
  for (GeodesicJointEdgeProfile joint : face.joints) {
    if (joint.neighborFaceId < 0) continue;
    sharedEdges++;
    maximumHalfMiter = max(maximumHalfMiter, joint.recommendedHalfMiterDeg);
    maximumInset = max(maximumInset, joint.recommendedMiterInsetMM);
    feasible &= joint.miterFeasibleAtResolvedDimensions;
  }
  GeodesicSeamProfile effectiveSeam = resolved == null ?
    settings.seamProfile : resolved.seamProfile;
  if (sharedEdges == 0) return effectiveSeam.label() + " / RIM ONLY";
  if (effectiveSeam == GeodesicSeamProfile.SQUARE)
    return "SQUARE | NEED " + nf(maximumHalfMiter, 1, 1) + "deg " +
      nf(maximumInset, 1, 1) + "mm";
  return "MITER " + nf(maximumHalfMiter, 1, 1) + "deg " +
    nf(maximumInset, 1, 1) + "mm | " + (feasible ? "FIT" : "BLOCKED");
}

void geodesicControlValue(int x, int y, int w, String label, String value) {
  fill(100, 135, 145);
  textAlign(LEFT, TOP);
  textSize(8);
  text(label, x, y);
  fill(200, 230, 226);
  textAlign(RIGHT, TOP);
  text(value, x + w, y);
}

void geodesicMetricLine(int x, int y, int w, String label, String value) {
  fill(105, 143, 153);
  textAlign(LEFT, TOP);
  textSize(9);
  text(label, x, y);
  fill(214, 235, 232);
  textAlign(RIGHT, TOP);
  text(value, x + w, y);
}

boolean handleGeodesicSalonMouse(int pageX, int pageY, int pageW, int pageH) {
  int sideW = GEODESIC_SIDE_W;
  int sceneX = pageX + 24;
  int sceneY = pageY + 52;
  int sceneW = pageW - sideW - 72;
  int sideX = sceneX + sceneW + 24;
  int bx = sideX + 16;
  int bw = sideW - 32;
  int gap = 8;
  int half = (bw - gap) / 2;
  int third = (bw - gap * 2) / 3;
  int yy = sceneY + 42;
  if (over(bx, yy, third, 26)) {
    rebuildGeodesicSalonModel("rebuilt"); return true;
  }
  if (over(bx + third + gap, yy, third, 26)) {
    exportGeodesicSalonKit(); return true;
  }
  if (over(bx + (third + gap) * 2, yy, third, 26)) {
    exportGeodesicSalonPlateKit(); return true;
  }
  yy += 34;
  if (over(bx, yy, bw, 22)) {
    geodesicGuideSvgEnabled = !geodesicGuideSvgEnabled;
    geodesicStatus = geodesicGuideSvgEnabled ? "ASSEMBLY GUIDE SVG ENABLED" : "ASSEMBLY GUIDE SVG DISABLED";
    return true;
  }
  yy += 30;
  if (over(bx, yy, bw, 22)) {
    geodesicAssemblyMode =
      geodesicAssemblyMode == GeodesicAssemblyMode.KICAS ?
      GeodesicAssemblyMode.LEGACY_PORTAL : GeodesicAssemblyMode.KICAS;
    rebuildGeodesicSalonModel(geodesicAssemblyMode ==
      GeodesicAssemblyMode.KICAS ?
      "KICAS lock and center tie selected" : "legacy portal kit selected");
    return true;
  }
  yy += 30;
  if (over(bx, yy, third, 22)) {
    geodesicPanelStyle = GeodesicPanelStyle.OPEN_FRAME;
    rebuildGeodesicSalonModel("open frame selected"); return true;
  }
  if (over(bx + third + gap, yy, third, 22)) {
    geodesicPanelStyle = GeodesicPanelStyle.FRAME_SKIN;
    rebuildGeodesicSalonModel("frame and skin selected"); return true;
  }
  if (over(bx + (third + gap) * 2, yy, third, 22)) {
    geodesicPanelStyle = GeodesicPanelStyle.SOLID;
    rebuildGeodesicSalonModel("solid panel selected"); return true;
  }
  yy += 30;
  if (over(bx, yy, half, 22)) {
    if (geodesicAssemblyMode == GeodesicAssemblyMode.KICAS) {
      geodesicStatus = "KICAS REQUIRES ONE CENTER TIE PORTAL PER EDGE";
      return true;
    }
    geodesicFastenerPortals = !geodesicFastenerPortals;
    rebuildGeodesicSalonModel("fastener portals changed");
    return true;
  }
  if (over(bx + half + gap, yy, half, 22)) {
    if (geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN) {
      geodesicReliefSide = geodesicReliefSide == GeodesicReliefSide.INNER_REINFORCEMENT ?
        GeodesicReliefSide.EXTERIOR_CROWN : GeodesicReliefSide.INNER_REINFORCEMENT;
      rebuildGeodesicSalonModel("relief side changed");
    } else geodesicStatus = "RELIEF SIDE APPLIES TO FRAME + SKIN";
    return true;
  }
  yy += 30;
  if (over(bx, yy, half, 22)) { cycleGeodesicFamily(-1); return true; }
  if (over(bx + half + gap, yy, half, 22)) { cycleGeodesicFamily(1); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, bw, 22)) {
    if (!geodesicFamilySupportsStellation(geodesicFamily)) {
      geodesicModifier = GeodesicFormModifier.NONE;
      geodesicStatus = "STELLATION REQUIRES TETRA / OCTA / ICOSA";
    } else {
      geodesicModifier = geodesicModifier == GeodesicFormModifier.NONE ?
        GeodesicFormModifier.FACE_STELLATION : GeodesicFormModifier.NONE;
      rebuildGeodesicSalonModel("form modifier changed");
    }
    return true;
  }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) { geodesicFrequency = max(1, geodesicFrequency - 1); rebuildGeodesicSalonModel("frequency changed"); return true; }
  if (over(bx + half + gap, yy, half, 22)) { geodesicFrequency = min(12, geodesicFrequency + 1); rebuildGeodesicSalonModel("frequency changed"); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) { geodesicExtent = geodesicExtent == GeodesicExtentMode.DOME ? GeodesicExtentMode.SPHERE : GeodesicExtentMode.DOME; rebuildGeodesicSalonModel("form changed"); return true; }
  if (over(bx + half + gap, yy, half, 22)) { geodesicGrowth = geodesicGrowth == GeodesicGrowthMode.SHELL_OVERWRAP ? GeodesicGrowthMode.CENTER_TO_EDGE : GeodesicGrowthMode.SHELL_OVERWRAP; rebuildGeodesicSalonModel("growth changed"); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) { geodesicCutRatio = max(-0.30f, geodesicCutRatio - 0.05f); rebuildGeodesicSalonModel("cap changed"); return true; }
  if (over(bx + half + gap, yy, half, 22)) { geodesicCutRatio = min(0.82f, geodesicCutRatio + 0.05f); rebuildGeodesicSalonModel("cap changed"); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) { geodesicRadiusMM = max(24, geodesicRadiusMM - 4); rebuildGeodesicSalonModel("radius changed"); return true; }
  if (over(bx + half + gap, yy, half, 22)) { geodesicRadiusMM = min(240, geodesicRadiusMM + 4); rebuildGeodesicSalonModel("radius changed"); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) { cycleGeodesicFabricationControl(-1); return true; }
  if (over(bx + half + gap, yy, half, 22)) { cycleGeodesicFabricationControl(1); return true; }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, half, 22)) {
    adjustGeodesicFabricationControl(-1); return true;
  }
  if (over(bx + half + gap, yy, half, 22)) {
    adjustGeodesicFabricationControl(1); return true;
  }
  yy += GEODESIC_VALUE_ROW_H;
  if (over(bx, yy, third, 22)) {
    geodesicPlateauEnabled = !geodesicPlateauEnabled;
    rebuildGeodesicSalonModel("Plateau target changed");
    return true;
  }
  if (over(bx + third + gap, yy, third, 22)) {
    if (geodesicAssemblyMode == GeodesicAssemblyMode.KICAS) {
      geodesicStatus = "KICAS REQUIRES HALF-DIHEDRAL MITER SEAMS";
      return true;
    }
    geodesicSeamProfile =
      geodesicSeamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER ?
      GeodesicSeamProfile.SQUARE :
      GeodesicSeamProfile.HALF_DIHEDRAL_MITER;
    rebuildGeodesicSalonModel("seam profile changed");
    return true;
  }
  if (over(bx + (third + gap) * 2, yy, third, 22)) {
    geodesicFrontRunning = !geodesicFrontRunning;
    return true;
  }
  yy += 30;
  if (over(bx, yy, third, 22)) { selectGeodesicFace(-1); return true; }
  if (over(bx + third + gap, yy, third, 22)) { geodesicFrontRunning = false; geodesicFront = (geodesicFront + 0.08f) % 1.0f; return true; }
  if (over(bx + (third + gap) * 2, yy, third, 22)) { selectGeodesicFace(1); return true; }
  yy += 30;
  if (over(bx, yy, third, 22)) {
    geodesicPaintEnabled = !geodesicPaintEnabled;
    refreshGeodesicPaintPlan();
    geodesicStatus = geodesicPaintEnabled ?
      "PAINT MODE / " + geodesicPaintScheme.label() :
      "PAINT MODE OFF";
    return true;
  }
  if (over(bx + third + gap, yy, third, 22)) {
    cycleGeodesicPaintScheme(-1); return true;
  }
  if (over(bx + (third + gap) * 2, yy, third, 22)) {
    cycleGeodesicPaintScheme(1); return true;
  }
  yy += 30;
  int quarter = (bw - gap * 3) / 4;
  if (over(bx, yy, quarter, 22)) {
    adjustGeodesicPaintColors(-1); return true;
  }
  if (over(bx + quarter + gap, yy, quarter, 22)) {
    adjustGeodesicPaintColors(1); return true;
  }
  if (over(bx + (quarter + gap) * 2, yy, quarter, 22)) {
    adjustGeodesicPaintPhase(-1); return true;
  }
  if (over(bx + (quarter + gap) * 3, yy, quarter, 22)) {
    adjustGeodesicPaintPhase(1); return true;
  }
  return false;
}

void cycleGeodesicFamily(int direction) {
  GeodesicSeedFamily[] values = GeodesicSeedFamily.values();
  int index = (geodesicFamily.ordinal() + direction + values.length) % values.length;
  geodesicFamily = values[index];
  if (!geodesicFamilySupportsStellation(geodesicFamily))
    geodesicModifier = GeodesicFormModifier.NONE;
  rebuildGeodesicSalonModel("family changed");
}

void cycleGeodesicFabricationControl(int direction) {
  GeodesicFabricationControl[] values = GeodesicFabricationControl.values();
  int index = (geodesicFabricationControl.ordinal() + direction + values.length) % values.length;
  geodesicFabricationControl = values[index];
  geodesicStatus = "PARAMETER SELECTED / " + geodesicFabricationControlLabel().toUpperCase();
}

void adjustGeodesicFabricationControl(int direction) {
  if (geodesicFabricationControl == GeodesicFabricationControl.PANEL_DEPTH) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicThicknessMM = constrain(geodesicThicknessMM + direction * 0.2f, 0.8f, 12);
    } else {
      geodesicFrameDepthMM = constrain(geodesicFrameDepthMM + direction * 0.5f, 4, 30);
      geodesicSkinThicknessMM = min(geodesicSkinThicknessMM,
        geodesicFrameDepthMM - 1.2f);
    }
  } else if (geodesicFabricationControl == GeodesicFabricationControl.FRAME_WIDTH) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicStatus = "FRAME WIDTH N/A IN SOLID"; return;
    }
    geodesicFrameWidthMM = constrain(geodesicFrameWidthMM + direction * 0.25f, 0.8f, 20);
  } else if (geodesicFabricationControl == GeodesicFabricationControl.SKIN_THICKNESS) {
    if (geodesicPanelStyle != GeodesicPanelStyle.FRAME_SKIN) {
      geodesicStatus = "SKIN THICKNESS REQUIRES FRAME + SKIN"; return;
    }
    geodesicSkinThicknessMM = constrain(geodesicSkinThicknessMM + direction * 0.2f,
      0.6f, max(0.6f, geodesicFrameDepthMM - 1.2f));
  } else if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_WIDTH) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicStatus = "PORTALS N/A IN SOLID"; return;
    }
    geodesicPortalWidthMM = constrain(geodesicPortalWidthMM + direction * 0.2f, 2, 20);
  } else if (geodesicFabricationControl == GeodesicFabricationControl.PORTAL_HEIGHT) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicStatus = "PORTALS N/A IN SOLID"; return;
    }
    geodesicPortalHeightMM = constrain(geodesicPortalHeightMM + direction * 0.2f, 1, 12);
  } else if (geodesicFabricationControl == GeodesicFabricationControl.CODE_HEIGHT) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicStatus = "MATE CODES N/A IN SOLID"; return;
    }
    geodesicEdgeCodeReliefMM = constrain(geodesicEdgeCodeReliefMM +
      direction * 0.05f, 0.32f, 1.2f);
  } else if (geodesicFabricationControl == GeodesicFabricationControl.EDGE_CHAMFER) {
    if (geodesicPanelStyle == GeodesicPanelStyle.SOLID) {
      geodesicStatus = "EDGE CHAMFER N/A IN SOLID"; return;
    }
    geodesicEdgeBreakMM = constrain(geodesicEdgeBreakMM + direction * 0.02f, 0, 0.26f);
  } else {
    if (!geodesicFamilySupportsStellation(geodesicFamily)) {
      geodesicStatus = "STELLATION REQUIRES TETRA / OCTA / ICOSA"; return;
    }
    geodesicModifier = GeodesicFormModifier.FACE_STELLATION;
    geodesicStellationRatio = constrain(geodesicStellationRatio +
      direction * 0.02f, 0.04f, 0.45f);
  }
  rebuildGeodesicSalonModel(geodesicFabricationControlLabel() + " changed");
}

void selectGeodesicFace(int direction) {
  if (geodesicModel == null || geodesicModel.faces.size() == 0) return;
  geodesicSelectedFace = (geodesicSelectedFace + direction + geodesicModel.faces.size()) % geodesicModel.faces.size();
}

void exportGeodesicSalonKit() {
  GeodesicKitPreflight preflight = preflightGeodesicSalonKit("EXPORT");
  geodesicLastPreflight = preflight;
  geodesicLastAudit = preflight.shellAudit;
  if (!preflight.ready) {
    geodesicStatus = preflight.status;
    println(preflight.status + " / " + preflight.detail);
    if (preflight.failedFaceId >= 0)
      geodesicSelectedFace = constrain(preflight.failedFaceId,
        0, max(0, geodesicModel.faces.size() - 1));
    if (preflight.failedType != null) {
      geodesicSelectedFace = constrain(preflight.failedType.representativeFaceId,
        0, max(0, geodesicModel.faces.size() - 1));
      GeodesicFabricationFace failedFace = geodesicFabricationFace(geodesicModel,
        geodesicModel.faces.get(preflight.failedType.representativeFaceId),
        preflight.fabrication == null ? currentGeodesicFabricationSettings() :
        preflight.fabrication);
      for (GeodesicJointEdgeProfile joint : failedFace.joints)
        println("  PANEL AUDIT EDGE " + joint.edgeIndex + " length " +
          nf(joint.edgeLengthMM, 1, 4) + " clearance " +
          nf(joint.cornerClearanceMM, 1, 4) + " portals " + joint.portalCenters);
      for (String edge : geodesicBoundaryEdgeReport(preflight.failedType.mesh, 24))
        println("  PANEL BOUNDARY " + edge);
    }
    return;
  }
  String stamp = geodesicSalonTimestamp();
  String modifierSuffix = geodesicModifier == GeodesicFormModifier.FACE_STELLATION ?
    "_stellated" : "";
  String folderName = stamp + "_" + geodesicFamily.label().toLowerCase().replace(" ", "_") +
    "_f" + geodesicFrequency + modifierSuffix;
  File runFolder = new File(sketchPath("exports/geodesic_salon/" + folderName));
  File combinedFolder = new File(runFolder, "combined");
  File partsFolder = new File(runFolder, "parts");
  if ((!combinedFolder.exists() && !combinedFolder.mkdirs()) || (!partsFolder.exists() && !partsFolder.mkdirs())) {
    geodesicStatus = "EXPORT FAILED / cannot create run folders";
    return;
  }
  SurfaceMesh combined = preflight.combined;
  int[] combinedAudit = preflight.shellAudit;
  String combinedName = "geodesic_" + geodesicExtent.label().toLowerCase() + "_combined.stl";
  combined.writeSTL(new File(combinedFolder, combinedName).getAbsolutePath());

  GeodesicFabricationSettings fabrication = preflight.fabrication == null ?
    currentGeodesicFabricationSettings() : preflight.fabrication;
  GeodesicPanelCatalog catalog = preflight.catalog;
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    for (GeodesicPartType type : catalog.types)
      type.filename = "ORDERED_PLACEMENT_FILES";
    for (GeodesicKicasStep step : fabrication.kicasPlan.steps) {
      String reusableType = catalog.faceToType.containsKey(step.faceId) ?
        catalog.faceToType.get(step.faceId) : "UNASSIGNED";
      step.reusableTypeId = reusableType;
      GeodesicPart part = buildGeodesicFabricatedPart(geodesicModel,
        geodesicModel.faces.get(step.faceId), fabrication,
        geodesicGrowth, geodesicReliefMM);
      String filename = "parts/" + step.placementLabel + "_face_" +
        nf(step.faceId, 4) + ".stl";
      part.mesh.writeSTL(new File(runFolder, filename).getAbsolutePath());
    }
  } else {
    for (GeodesicPartType type : catalog.types) {
      type.filename = "parts/" + type.typeId + "_qty" +
        nf(type.quantity, 3) + ".stl";
      type.mesh.writeSTL(new File(runFolder, type.filename).getAbsolutePath());
    }
  }

  JSONObject bom = catalog.billOfMaterialsJSON();
  saveJSONObject(bom, new File(runFolder, "bill_of_materials.json").getAbsolutePath());
  JSONObject assembly = geodesicAssemblyPlanJSON(geodesicModel, catalog, fabrication);
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS)
    assembly.setJSONObject("kicas_ordered_assembly",
      fabrication.kicasPlan.toJSON());
  saveJSONObject(assembly, new File(runFolder, "assembly_plan.json").getAbsolutePath());
  writeGeodesicAssemblyGuide(new File(runFolder, "ASSEMBLY.txt"), catalog,
    fabrication);
  GeodesicGuideExportResult guideResult = exportGeodesicAssemblyGuides(runFolder, catalog, stamp);
  GeodesicPaintExportResult paintResult = exportGeodesicPaintPackage(
    runFolder, catalog, fabrication, stamp);
  GeodesicPlateKitExportResult plateResult = null;
  if (geodesicPlateKitRequested) {
    GeodesicPaintPlan platePaintPlan = geodesicPaintEnabled ?
      geodesicPaintPlan : null;
    plateResult = exportGeodesicPlateKitPackage(runFolder, catalog,
      fabrication, platePaintPlan, stamp);
    geodesicLastPlateKitResult = plateResult;
  }

  JSONObject manifest = new JSONObject();
  manifest.setString("schema", "fieldworks.geodesic_salon.kit.v1");
  manifest.setString("generated_at", stamp);
  manifest.setJSONObject("model", geodesicModel.toJSON());
  manifest.setString("growth_mode", geodesicGrowth.label());
  manifest.setFloat("shell_thickness_mm", geodesicThicknessMM);
  manifest.setFloat("center_relief_mm", geodesicReliefMM);
  manifest.setJSONObject("panel_fabrication", fabrication.toJSON());
  manifest.setJSONObject("slicer_scale_reference",
    geodesicSlicerScaleReferenceJSON(geodesicModel, fabrication.fabricationScale));
  manifest.setBoolean("plateau_junction_target_enabled", geodesicPlateauEnabled);
  manifest.setFloat("plateau_tetrahedral_angle_deg", geodesicPlateauAngleDegrees());
  manifest.setString("combined_stl", "combined/" + combinedName);
  manifest.setInt("combined_triangles", combined.tris.size());
  manifest.setInt("combined_boundary_edges", combinedAudit[0]);
  manifest.setInt("combined_nonmanifold_edges", combinedAudit[1]);
  manifest.setInt("unique_part_types", catalog.types.size());
  manifest.setInt("physical_edge_code_fallback_types",
    catalog.physicalEdgeCodeFallbackCount());
  manifest.setInt("panel_instances", geodesicModel.faces.size());
  if (preflight.seamAudit != null)
    manifest.setJSONObject("assembled_seam_audit",
      preflight.seamAudit.toJSON());
  manifest.setString("assembly_mode", fabrication.assemblyMode.label());
  manifest.setBoolean("center_reinforcement_portal_each_edge",
    fabrication.assemblyMode == GeodesicAssemblyMode.KICAS);
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS)
    manifest.setJSONObject("kicas_plan", fabrication.kicasPlan.toJSON());
  manifest.setJSONObject("assembly_guides", guideResult.toJSON());
  manifest.setJSONObject("paint_mode", paintResult.toJSON());
  if (plateResult != null)
    manifest.setJSONObject("plate_kit", plateResult.toJSON());
  manifest.setJSONObject("field_state", geodesicSalonFieldStateJSON());
  saveJSONObject(manifest, new File(runFolder, "manifest.json").getAbsolutePath());

  geodesicUniqueTypes = catalog.types.size();
  geodesicLastExport = runFolder.getAbsolutePath();
  geodesicStatus = "KIT EXPORTED / " +
    (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS ?
      fabrication.kicasPlan.steps.size() + " ordered KICAS parts" :
      geodesicUniqueTypes + " reusable types") + " / " +
    guideResult.status +
    (geodesicPaintEnabled ? " / " + paintResult.status : "") +
    (plateResult == null ? "" : " / " + plateResult.status);
}

void writeGeodesicAssemblyGuide(File file, GeodesicPanelCatalog catalog,
  GeodesicFabricationSettings fabrication) {
  PrintWriter writer = createWriter(file.getAbsolutePath());
  writer.println("GEODESIC SALON ASSEMBLY PLAN");
  writer.println("Generated " + geodesicSalonTimestamp());
  writer.println();
  writer.println("FABRICATION");
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    writer.println("KICAS ORDERED ASSEMBLY MODE");
    writer.println("Print the ordered P### placement files in parts/.");
    writer.println("P### is raised on the assembly-interior face and matches the construction sequence.");
    writer.println("Each triangular edge retains one enlarged center portal. Engage the integral");
    writer.println("slide-capture lock first, then add an optional zip tie for structural integrity.");
  } else {
    writer.println("Print one reusable STL type in the quantity listed below.");
    writer.println("Do not print one unique file per face; repeated face placements share the same type.");
  }
  writer.println();
  writer.println("BILL OF MATERIALS");
  for (GeodesicPartType type : catalog.types) {
    writer.println(type.typeId + "  quantity " + type.quantity + "  edge cycle " +
      geodesicEdgeCodeCycle(type) + "  physical marking " +
      type.physicalEdgeCodeStatus + "  file " + type.filename);
  }
  writer.println();
  writer.println("ASSEMBLY");
  writer.println("Use assembly_plan.json. Each placement lists face_id, reusable type_id,");
  writer.println("neighbors and logical edge_mate_codes in AB/BC/CA order, model-space vertices, centroid, and outward normal.");
  if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    writer.println("Follow kicas_ordered_assembly exactly. Place P001 as the seed, then slide each");
    writer.println("successive panel into its recorded parent edge along insertion_direction_model.");
    writer.println("GS-003 is the compressed illustrated order; the JSON remains authoritative.");
  } else {
    writer.println("The illustrated six-stage sequence is a connected geometric traversal, not a validated");
    writer.println("mechanical construction order. Match identical mate codes and keep outward normals exterior.");
  }
  writer.println("Raised interior codes are retained when their panel mesh passes manifold audit. A part marked");
  writer.println("omitted_after_manifold_fallback is deliberately unmarked; use its BOM, JSON, and guide codes.");
  writer.println(fabrication.assemblyMode == GeodesicAssemblyMode.KICAS ?
    "One integral center tie portal is included on every edge. Ties remain user-supplied." :
    "Integral rail portals are included when enabled. No separate connectors or fasteners are generated.");
  writer.println("Relief side: " + (geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN ?
    geodesicReliefSide.label() : "N/A FOR " + geodesicPanelStyle.label()) + ".");
  writer.println("Mate-code face: " + (geodesicPanelStyle == GeodesicPanelStyle.SOLID ?
    "NOT APPLICABLE" : "INTERIOR") + ".");
  writer.println("Frame, skin, and portal inputs are dimensional caps; each reusable panel records its face-relative resolved dimensions.");
  writer.println("Use edge_mate_codebook to decode compatibility classes and each edge_joint_profile to align shared portals. Bubble metadata records the local");
  writer.println("dihedral, face-normal bisector, and deviation from the Plateau tetrahedral target.");
  if (fabrication.seamProfile == GeodesicSeamProfile.HALF_DIHEDRAL_MITER) {
    writer.println("Shared rail walls use reciprocal half-dihedral miter profiles. Each reusable part records the resolved depth, half-miter angle,");
    writer.println("required lateral inset, and whether automatic depth limiting was applied to retain a printable rail.");
  } else {
    writer.println("IMPORTANT: shared rail walls use square compatibility profiles. Each edge_joint_profile records the recommended symmetric");
    writer.println("half-miter angle and required inset. Do not assume a seamless rigid joint in SQUARE mode.");
  }
  writer.println("Choose and validate ties or fasteners appropriate to the material, scale, and use case.");
  writer.println();
  writer.println("BAMBU / SLICER UNIFORM SCALE REFERENCE (NOMINAL ASSEMBLED W x D x H)");
  writer.println("Apply the same scale percentage to X, Y, and Z for every reusable part STL.");
  writer.println("Resolved fabrication scale: " +
    nf(fabrication.fabricationScale * 100.0f, 1, 0) + "% of visual model.");
  writer.println("100%  " + geodesicSlicerScaleDimensions(geodesicModel,
    fabrication.fabricationScale, 100));
  writer.println("200%  " + geodesicSlicerScaleDimensions(geodesicModel,
    fabrication.fabricationScale, 200));
  writer.println("300%  " + geodesicSlicerScaleDimensions(geodesicModel,
    fabrication.fabricationScale, 300));
  writer.flush();
  writer.close();
}

String geodesicEdgeCodeCycle(GeodesicPartType type) {
  if (type == null || type.edgeCodes.size() == 0) return "-";
  String value = "";
  for (int i = 0; i < type.edgeCodes.size(); i++)
    value += (i == 0 ? "" : "-") + type.edgeCodes.get(i);
  return value;
}

JSONObject geodesicSalonFieldStateJSON() {
  JSONObject json = new JSONObject();
  json.setFloat("alpha", alpha);
  json.setInt("depth", depth);
  json.setFloat("source", sourcePressure);
  json.setFloat("floquet", floquetCoupling);
  json.setFloat("quasi_energy", quasiEnergy);
  json.setFloat("coherence", coherenceBias);
  json.setFloat("ctc_bias", ctcBias);
  json.setFloat("brane_twist", braneTwist);
  json.setFloat("deep_detail", deepDetail);
  json.setFloat("time_scale", timeScale);
  json.setInt("seed", seed);
  json.setString("geodesic_relief_side", geodesicPanelStyle == GeodesicPanelStyle.FRAME_SKIN ?
    geodesicReliefSide.label() : "N/A");
  MaterialProfile material = activeMaterial();
  json.setString("material_target", material == null ? "none" : material.name);
  return json;
}

String geodesicSalonTimestamp() {
  return nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" +
    nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}
