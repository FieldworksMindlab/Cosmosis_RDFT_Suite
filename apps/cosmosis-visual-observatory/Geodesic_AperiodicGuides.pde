/*
  GS-005: fabrication-facing map of the logical aperiodic atlas carried by the
  audited triangular KICAS shell. The drawing is deliberately black and white
  so the PNG and SVG remain useful as workshop documents and plotter output.
*/

void drawGeodesicGuideAperiodicAtlas(GeodesicGuideCanvas canvas,
  GeodesicGuideData data) {
  GeodesicModel model = data.model;
  canvas.beginGroup("aperiodic-header");
  canvas.textLine("GEODESIC SALON - APERIODIC CURVED ATLAS", 11, 11,
    8.8f, true, LEFT);
  canvas.textLine(model.aperiodicFamily.label() + " / RECURSION " +
    model.aperiodicRecursion + " / " + model.aperiodicLogicalTiles +
    " LOGICAL TILES / " + model.faces.size() + " ORDERED CARRIER FACES",
    11, 22, GEODESIC_GUIDE_BODY_MM, false, LEFT);
  canvas.logo(471, 10, 107, 27);
  canvas.line(10, 41, 584, 41, 0.45f);
  canvas.endGroup();

  float modelX = 11;
  float modelY = 48;
  float modelW = 432;
  float modelH = 292;
  canvas.beginGroup("aperiodic-atlas-model");
  canvas.rect(modelX, modelY, modelW, modelH, 0.38f, false);
  canvas.textLine("LOGICAL TILE DOMAINS / CHART SEAMS / DISTORTION DEFECTS",
    modelX + 4, modelY + 4, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  guideDrawAperiodicModel(canvas, data, modelX + 6, modelY + 14,
    modelW - 12, modelH - 20, 35, 24);
  canvas.endGroup();

  float infoX = 449;
  float infoW = 134;
  canvas.beginGroup("aperiodic-legend");
  canvas.rect(infoX, modelY, infoW, modelH, 0.38f, false);
  canvas.textLine("ATLAS LEGEND", infoX + 5, modelY + 5,
    GEODESIC_GUIDE_BODY_MM, true, LEFT);
  float ly = modelY + 20;
  guideAperiodicLegendSwatch(canvas, infoX + 6, ly, 0);
  canvas.textLine("TILE DOMAIN A", infoX + 30, ly - 1,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  ly += 16;
  guideAperiodicLegendSwatch(canvas, infoX + 6, ly, 1);
  canvas.textLine("TILE DOMAIN B", infoX + 30, ly - 1,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  ly += 18;
  canvas.line(infoX + 6, ly + 4, infoX + 25, ly + 4, 0.55f);
  canvas.textLine("TILE BOUNDARY", infoX + 30, ly,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  ly += 15;
  canvas.dashedLine(infoX + 6, ly + 4, infoX + 25, ly + 4,
    0.85f, 2.0f, 1.1f);
  canvas.textLine("CUBE-CHART SEAM", infoX + 30, ly,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  ly += 15;
  canvas.circle(infoX + 15, ly + 4, 3.0f, 0.55f, false);
  canvas.circle(infoX + 15, ly + 4, 0.8f, 0.35f, true);
  canvas.textLine("SEAM / DEFECT FACE", infoX + 30, ly,
    GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);

  ly += 22;
  canvas.textLine("FABRICATION CONTRACT", infoX + 5, ly,
    GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  ly += 10;
  String[] contract = {
    "The aperiodic field assigns",
    "logical identity and order.",
    "Physical parts remain the",
    "audited triangular carrier.",
    "Follow P### KICAS order.",
    "Use source tile IDs to read",
    "the nonperiodic structure."
  };
  for (String line : contract) {
    canvas.textLine(line, infoX + 5, ly, GEODESIC_GUIDE_MICRO_MM,
      false, LEFT);
    ly += 7;
  }

  ly += 5;
  canvas.textLine("SOURCE", infoX + 5, ly,
    GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT); ly += 9;
  String[] sourceLines = model.aperiodicFamily == GeodesicAperiodicFamily.HAT
    ? new String[] { "exact Hat substitution manifest", "six-chart curved atlas" }
    : new String[] { "Penrose P3 de Bruijn pentagrid", "six-chart curved atlas" };
  for (String sourceLine : sourceLines) {
    canvas.textLine(sourceLine, infoX + 5, ly,
      GEODESIC_GUIDE_MICRO_MM, false, LEFT);
    ly += 7;
  }
  ly += 1;
  canvas.textLine("CHARTS " + model.aperiodicChartCount, infoX + 5, ly,
    GEODESIC_GUIDE_MICRO_MM, false, LEFT); ly += 7;
  canvas.textLine("DEFECT FACES " + model.aperiodicDefectFaces,
    infoX + 5, ly, GEODESIC_GUIDE_MICRO_MM, false, LEFT); ly += 7;
  canvas.textLine("MAX DISTORTION " +
    nf(model.aperiodicMaxDistortion, 1, 3), infoX + 5, ly,
    GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.endGroup();

  canvas.beginGroup("aperiodic-footer");
  float footerY = 347;
  canvas.rect(11, footerY, 572, 58, 0.38f, false);
  canvas.line(205, footerY, 205, footerY + 58, 0.25f);
  canvas.line(397, footerY, 397, footerY + 58, 0.25f);
  canvas.textLine("HOW TO READ", 16, footerY + 5,
    GEODESIC_GUIDE_BODY_MM, true, LEFT);
  canvas.textLine("Fine triangles are fabrication faces. Pattern fields group",
    16, footerY + 17, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("them into source tiles; heavy dashed lines cross chart seams.",
    16, footerY + 25, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("Circle marks identify faces requiring seam-aware inspection.",
    16, footerY + 33, GEODESIC_GUIDE_MICRO_MM, false, LEFT);

  canvas.textLine("ASSEMBLY", 211, footerY + 5,
    GEODESIC_GUIDE_BODY_MM, true, LEFT);
  canvas.textLine("Build strictly in P### order from GS-003 and assembly_plan.json.",
    211, footerY + 17, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("aperiodic_atlas.json binds every P### face to tile, chart, UV,",
    211, footerY + 25, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("distortion, and defect state. Dome export is qualified; sphere",
    211, footerY + 33, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("export remains locked until explicit atlas closure is qualified.",
    211, footerY + 41, GEODESIC_GUIDE_MICRO_MM, false, LEFT);

  canvas.textLine("DOCUMENT", 403, footerY + 5,
    GEODESIC_GUIDE_BODY_MM, true, LEFT);
  canvas.textLine("GS-005", 403, footerY + 17,
    GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  canvas.textLine("Generated " + data.generatedAt, 403, footerY + 26,
    GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("Model " + model.fingerprint, 403, footerY + 34,
    GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("Atlas data: aperiodic_atlas.json", 403, footerY + 42,
    GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.endGroup();
}

void guideDrawAperiodicModel(GeodesicGuideCanvas canvas,
  GeodesicGuideData data, float x, float y, float w, float h,
  float azimuth, float elevation) {
  GeodesicModel model = data.model;
  GeodesicGuideProjection projection = new GeodesicGuideProjection(model,
    azimuth, elevation);
  for (GeodesicFace face : model.faces) {
    if (!projection.visible(face)) continue;
    PVector[] tri = guideFaceScreen(model, face, projection,
      x, y, w, h, 6, null);
    int pattern = geodesicAperiodicGuidePattern(face.sourceTileId);
    if (pattern == 1) guideHatchTriangle(canvas, tri, 1, 0.10f);
    else if (pattern == 2) guideHatchTriangle(canvas, tri, 2, 0.10f);
    else if (pattern == 3) {
      PVector[] inset = guideInsetTriangle(tri, 0.28f);
      canvas.polygon(inset, 0.12f, true);
    }
    canvas.polygon(tri, 0.10f, false);
    if (face.sourceDefect) {
      PVector center = projection.screen(face.centroid, x, y, w, h, 6);
      canvas.circle(center.x, center.y, 1.4f, 0.30f, false);
      canvas.circle(center.x, center.y, 0.35f, 0.15f, true);
    }
  }
  for (GeodesicEdge edge : model.edges) {
    boolean visibleA = edge.faceA >= 0 &&
      projection.visible(model.faces.get(edge.faceA));
    boolean visibleB = edge.faceB >= 0 &&
      projection.visible(model.faces.get(edge.faceB));
    if (!visibleA && !visibleB) continue;
    PVector a = projection.screen(model.vertices.get(edge.a).position,
      x, y, w, h, 6);
    PVector b = projection.screen(model.vertices.get(edge.b).position,
      x, y, w, h, 6);
    boolean chartSeam = geodesicAperiodicChartBoundary(model, edge);
    boolean tileBoundary = geodesicAperiodicSourceBoundary(model, edge);
    if (chartSeam)
      canvas.dashedLine(a.x, a.y, b.x, b.y, 0.78f, 2.1f, 1.0f);
    else if (tileBoundary)
      canvas.line(a.x, a.y, b.x, b.y, 0.42f);
    else if (visibleA != visibleB || edge.boundary())
      canvas.line(a.x, a.y, b.x, b.y, 0.54f);
  }
}

int geodesicAperiodicGuidePattern(int tileId) {
  int value = geodesicAperiodicHash(tileId) & 0x7fffffff;
  return value % 4;
}

void guideAperiodicLegendSwatch(GeodesicGuideCanvas canvas,
  float x, float y, int pattern) {
  PVector[] tri = {
    new PVector(x, y + 11), new PVector(x + 20, y + 11),
    new PVector(x + 10, y)
  };
  if (pattern == 0) guideHatchTriangle(canvas, tri, 1, 0.12f);
  else guideHatchTriangle(canvas, tri, 2, 0.12f);
  canvas.polygon(tri, 0.35f, false);
}
