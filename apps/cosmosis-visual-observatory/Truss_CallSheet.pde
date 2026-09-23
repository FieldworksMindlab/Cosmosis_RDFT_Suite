/*
  Truss Yard illustrated assembly call sheets.

  Drawn with the same canvas primitives as the Geodesic Salon guides, so both
  sheet families share a visual language. Portrait rather than landscape: a mast
  or tunnel is long on one axis and wastes most of a landscape page.

    TY-001  assembly overview   elevation, build data, panel type plates
    TY-002  wall development    tube unrolled flat, joint map and schedule

  The drawing describes geometry and placement only. Zip ties are user supplied.
*/

final float TRUSS_SHEET_W = 420;
final float TRUSS_SHEET_H = 594;

// One scale applied at every text call, so type can be retuned in one place.
final float TRUSS_TYPE_SCALE = 1.5f;
final float TRUSS_BODY = 3.4f;
final float TRUSS_ANNOTATION = 2.75f;
final float TRUSS_MICRO = 2.35f;
final float TRUSS_TITLE = 5.4f;
final float TRUSS_ROW = 5.4f * TRUSS_TYPE_SCALE;
final float TRUSS_HEAD = 9.5f * TRUSS_TYPE_SCALE;

boolean trussCallSheetSvgEnabled = true;

class TrussCallSheetResult {
  boolean success = false;
  String status = "not generated";
  String overviewPng = "";
  String developmentPng = "";
  String overviewSvg = "";
  String developmentSvg = "";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("success", success);
    json.setString("status", status);
    json.setString("assembly_overview_png", overviewPng);
    json.setString("wall_development_png", developmentPng);
    json.setString("assembly_overview_svg", overviewSvg);
    json.setString("wall_development_svg", developmentSvg);
    return json;
  }
}

/* Places drawing coordinates into a page box, optionally turning the drawing a
   quarter turn when that fills the box better. */
class TrussSheetFit {
  boolean turned = false;
  float scale = 1;
  float cx, cy, bx, by;

  PVector place(PVector p) {
    float qx = turned ? -p.y : p.x;
    float qy = turned ? p.x : p.y;
    return new PVector(cx + (qx - bx) * scale, cy + (qy - by) * scale);
  }
}

TrussSheetFit trussFit(ArrayList<PVector> points, float x, float y,
  float w, float h, float pad, boolean allowTurn) {
  TrussSheetFit fit = new TrussSheetFit();
  fit.cx = x + w * 0.5f;
  fit.cy = y + h * 0.5f;
  if (points == null || points.size() == 0) return fit;
  int turns = allowTurn ? 2 : 1;
  for (int turn = 0; turn < turns; turn++) {
    float minX = Float.MAX_VALUE, maxX = -Float.MAX_VALUE;
    float minY = Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
    for (PVector p : points) {
      float qx = turn == 1 ? -p.y : p.x;
      float qy = turn == 1 ? p.x : p.y;
      minX = min(minX, qx); maxX = max(maxX, qx);
      minY = min(minY, qy); maxY = max(maxY, qy);
    }
    float bw = max(0.001f, maxX - minX);
    float bh = max(0.001f, maxY - minY);
    float scale = min((w - pad * 2) / bw, (h - pad * 2) / bh);
    // Take the turn only when it is a clear improvement, so an almost-square
    // drawing keeps its natural orientation.
    if (turn == 0 || scale > fit.scale * 1.02f) {
      fit.turned = turn == 1;
      fit.scale = scale;
      fit.bx = (minX + maxX) * 0.5f;
      fit.by = (minY + maxY) * 0.5f;
    }
  }
  return fit;
}

void trussText(GeodesicGuideCanvas canvas, String value, float x, float y,
  float size, boolean bold, int align) {
  canvas.textLine(value, x, y, size * TRUSS_TYPE_SCALE, bold, align);
}

void trussSheetSection(GeodesicGuideCanvas canvas, float x, float y,
  float w, float h, String title) {
  canvas.rect(x, y, w, h, 0.35f, false);
  trussText(canvas, title, x + 3.2f, y + 3.0f, TRUSS_ANNOTATION, true, LEFT);
  canvas.line(x, y + TRUSS_HEAD, x + w, y + TRUSS_HEAD, 0.2f);
}

void trussSheetRow(GeodesicGuideCanvas canvas, float x, float w, float y,
  String key, String value, boolean bold) {
  trussText(canvas, key, x + 3.2f, y, TRUSS_MICRO, bold, LEFT);
  trussText(canvas, value, x + w - 3.2f, y, TRUSS_MICRO, true, RIGHT);
}

void trussSheetFrame(GeodesicGuideCanvas canvas) {
  canvas.beginGroup("page-frame");
  canvas.rect(5, 5, TRUSS_SHEET_W - 10, TRUSS_SHEET_H - 10, 0.7f, false);
  canvas.rect(7.2f, 7.2f, TRUSS_SHEET_W - 14.4f, TRUSS_SHEET_H - 14.4f, 0.22f, false);
  canvas.endGroup();
}

void trussSheetHeader(GeodesicGuideCanvas canvas, TrussMastModel model,
  String heading) {
  canvas.beginGroup("header");
  trussText(canvas, "TRUSS YARD - " + heading, 11, 10, TRUSS_TITLE, true, LEFT);
  String label = (model.tunnel ? "TUNNEL" : "TOWER") + "  /  " +
    model.section.label() + " SIDED  /  " + model.bays + " BAYS  /  TWIST " +
    nf(degrees(model.twistRadians), 1, 1) + " DEG";
  trussText(canvas, label, 11, 18.5f, TRUSS_ANNOTATION, false, LEFT);
  canvas.line(10, 24, TRUSS_SHEET_W - 10, 24, 0.4f);
  canvas.endGroup();
}

void trussSheetFooter(GeodesicGuideCanvas canvas, TrussMastModel model,
  String sheet, String drawing, String generatedAt, String[] notes) {
  canvas.beginGroup("footer-title-block");
  float y = TRUSS_SHEET_H - 52;
  canvas.rect(10, y, TRUSS_SHEET_W - 20, 42, 0.4f, false);
  float[] cuts = { 128, 196, 268, 318 };
  for (float cut : cuts) canvas.line(10 + cut, y, 10 + cut, y + 42, 0.28f);
  trussText(canvas, "DRAWING", 14, y + 3.5f, 2.5f, true, LEFT);
  trussText(canvas, drawing, 14, y + 13, 2.5f, false, LEFT);
  trussText(canvas, "Generated " + generatedAt, 14, y + 26, 2.3f, false, LEFT);
  trussText(canvas, "DRAWN FOR", 142, y + 3.5f, 2.5f, true, LEFT);
  trussText(canvas, "[Brian Fahey]", 142, y + 16, 2.8f, true, LEFT);
  canvas.logo(208, y + 5, 56, 30);
  trussText(canvas, "SHEET", 282, y + 3.5f, 2.5f, true, LEFT);
  trussText(canvas, sheet, 282, y + 16, 2.8f, false, LEFT);
  trussText(canvas, "NOTES", 332, y + 3.5f, 2.5f, true, LEFT);
  for (int i = 0; i < notes.length && i < 4; i++)
    trussText(canvas, notes[i], 332, y + 12 + i * 7.0f, 2.1f, i == 0, LEFT);
  canvas.endGroup();
}

// --------------------------------------------------------------------------
// Geometry helpers
// --------------------------------------------------------------------------

/* Two unit vectors spanning the plane perpendicular to the structure axis. */
PVector[] trussAxisPlane(TrussMastModel model) {
  PVector direction = trussAxisOf(model).direction.copy();
  direction.normalize();
  PVector seed = abs(direction.x) < 0.8f ? new PVector(1, 0, 0) : new PVector(0, 1, 0);
  PVector u = seed.cross(direction);
  if (u.magSq() < 0.000001f) u = new PVector(0, 1, 0);
  u.normalize();
  PVector v = direction.cross(u);
  v.normalize();
  return new PVector[] { u, v, direction };
}

/* Lays a triangle flat from its three edge lengths so a panel plate is drawn
   true to the printed part rather than as a projection of its placement.
   Negative height so the plate reads point-up once page y-down is applied. */
PVector[] trussFlatPlate(float a, float b, float c) {
  if (a < 0.000001f)
    return new PVector[] { new PVector(0, 0), new PVector(1, 0), new PVector(0, -1) };
  float x = (a * a + c * c - b * b) / (2 * a);
  float y = sqrt(max(0, c * c - x * x));
  return new PVector[] { new PVector(0, 0), new PVector(a, 0), new PVector(x, -y) };
}

String trussCompressJointIds(ArrayList<String> ids) {
  if (ids == null || ids.size() == 0) return "";
  IntList numbers = new IntList();
  String prefix = "J";
  for (String id : ids) {
    if (id == null || id.length() < 2) continue;
    prefix = id.substring(0, 1);
    try { numbers.append(Integer.parseInt(id.substring(1))); }
    catch (Exception ignored) { }
  }
  if (numbers.size() == 0) return "";
  numbers.sort();
  String text = "";
  int start = numbers.get(0);
  int previous = start;
  for (int i = 1; i <= numbers.size(); i++) {
    int value = i < numbers.size() ? numbers.get(i) : -999;
    if (value == previous + 1) { previous = value; continue; }
    if (text.length() > 0) text += ", ";
    text += start == previous ? prefix + nf(start, 3) :
      prefix + nf(start, 3) + "-" + prefix + nf(previous, 3);
    start = value;
    previous = value;
  }
  return text.length() <= 60 ? text : text.substring(0, 57) + "...";
}

// --------------------------------------------------------------------------
// TY-001 assembly overview
// --------------------------------------------------------------------------

void drawTrussOverviewSheet(GeodesicGuideCanvas canvas, TrussMastModel model,
  String generatedAt) {
  trussSheetFrame(canvas);
  trussSheetHeader(canvas, model, "ASSEMBLY OVERVIEW");

  float viewX = 11, viewY = 30, viewW = 246, viewH = 400;
  trussSheetSection(canvas, viewX, viewY, viewW, viewH, "ELEVATION / ISOMETRIC");

  CallSheetBasis basis = callSheetBasis(38, 22);
  PVector centre = new PVector();
  int vertexCount = 0;
  for (TrussFrameFace face : model.frameFaces)
    for (int i = 0; i < 3; i++) { centre.add(face.world[i]); vertexCount++; }
  if (vertexCount > 0) centre.mult(1.0f / vertexCount);

  ArrayList<PVector> flat = new ArrayList<PVector>();
  for (TrussFrameFace face : model.frameFaces)
    for (int i = 0; i < 3; i++) {
      PVector p = callSheetProject(face.world[i], centre, basis);
      flat.add(new PVector(p.x, p.y));
    }
  if (flat.size() > 0) {
    TrussSheetFit fit = trussFit(flat, viewX, viewY + 11, viewW, viewH - 16, 9, true);
    // Painter order so the near wall reads over the far one.
    IntList order = new IntList();
    FloatList depth = new FloatList();
    for (int i = 0; i < model.frameFaces.size(); i++) {
      TrussFrameFace face = model.frameFaces.get(i);
      float d = 0;
      for (int k = 0; k < 3; k++)
        d += callSheetProject(face.world[k], centre, basis).z;
      order.append(i);
      depth.append(d / 3.0f);
    }
    for (int i = 1; i < order.size(); i++)
      for (int j = i; j > 0 && depth.get(j) < depth.get(j - 1); j--) {
        float dv = depth.get(j); depth.set(j, depth.get(j - 1)); depth.set(j - 1, dv);
        int ov = order.get(j); order.set(j, order.get(j - 1)); order.set(j - 1, ov);
      }
    canvas.beginGroup("elevation");
    for (int index = 0; index < order.size(); index++) {
      TrussFrameFace face = model.frameFaces.get(order.get(index));
      PVector normal = PVector.sub(face.world[1], face.world[0])
        .cross(PVector.sub(face.world[2], face.world[0]));
      if (normal.magSq() > 0.000001f) normal.normalize();
      boolean facing = normal.dot(basis.view) >= -0.015f;
      PVector[] screen = new PVector[3];
      for (int k = 0; k < 3; k++) {
        PVector p = callSheetProject(face.world[k], centre, basis);
        screen[k] = fit.place(new PVector(p.x, p.y));
      }
      canvas.polygon(screen, facing ? 0.32f : 0.12f, false);
    }
    canvas.endGroup();
    if (fit.turned)
      trussText(canvas, "AXIS RUNS DOWN THE PAGE", viewX + 3.2f,
        viewY + viewH - 6, TRUSS_MICRO, false, LEFT);
  }

  float dataX = 262, dataW = TRUSS_SHEET_W - 262 - 11;
  float y = viewY;

  String[][] build = {
    { "Section", model.section.label() },
    { "Corner dihedral", nf(model.section.cornerDihedralDeg(), 1, 1) + " deg" },
    { "Bays", str(model.bays) },
    { "Bay span", nf(model.baySpanMM, 1, 2) + " mm" },
    { "Bay height", nf(model.bayHeightMM, 1, 2) + " mm" },
    { "Twist per bay", nf(degrees(model.twistRadians), 1, 2) + " deg" },
    { "Rail section", nf(model.frameWidthMM, 1, 2) + " x " +
      nf(model.frameDepthMM, 1, 2) + " mm" },
    { "Panel mode", model.framePanelMode == TrussFramePanelMode.OPEN_FRAME ?
      "OPEN FRAME" : "EXTERIOR MEMBRANE" },
    { "Panels", str(model.frameFaces.size()) },
    { "Reusable types", str(model.frameTypes.size()) },
    { "Shared joints", str(trussSharedFrameJointCount(model)) },
    { "Open rim edges", str(trussBoundaryFrameJointCount(model)) }
  };
  float buildH = TRUSS_HEAD + 6 + build.length * TRUSS_ROW;
  trussSheetSection(canvas, dataX, y, dataW, buildH, "BUILD DATA");
  for (int i = 0; i < build.length; i++)
    trussSheetRow(canvas, dataX, dataW, y + TRUSS_HEAD + 3 + i * TRUSS_ROW,
      build[i][0], build[i][1], false);
  y += buildH + 6;

  int shared = trussSharedFrameJointCount(model);
  String[][] fastening = {
    { "Ties required", shared + " (one per shared joint)" },
    { "Thread from", model.accessSide.label() + " face" },
    { "Portal per edge", "1 joint-owned aperture" },
    { "Tie stock", nf(trussZipTieWidthMM, 1, 2) + " x " +
      nf(trussZipTieThicknessMM, 1, 2) + " mm" },
    { "Minimum print scale", model.fastenerFit == null ||
      !model.fastenerFit.evaluated ? "not evaluated" :
      nf(model.fastenerFit.minimumPrintScalePercent, 1, 0) +
      "% for that tie" },
    { "Tightest portal", model.fastenerFit == null ||
      !model.fastenerFit.evaluated ? "-" :
      nf(model.fastenerFit.minimumApertureWidthMM, 1, 2) + " x " +
      nf(model.fastenerFit.minimumApertureHeightMM, 1, 2) + " mm at " +
      model.fastenerFit.limitingJoint },
  };
  float fastH = TRUSS_HEAD + 6 + fastening.length * TRUSS_ROW;
  trussSheetSection(canvas, dataX, y, dataW, fastH, "FASTENING SCHEDULE");
  for (int i = 0; i < fastening.length; i++)
    trussSheetRow(canvas, dataX, dataW, y + TRUSS_HEAD + 3 + i * TRUSS_ROW,
      fastening[i][0], fastening[i][1], false);
  y += fastH + 6;

  ArrayList<String> typeIds = new ArrayList<String>(model.frameQuantities.keySet());
  java.util.Collections.sort(typeIds);
  float catalogH = TRUSS_HEAD + 6 + max(1, typeIds.size()) * TRUSS_ROW;
  trussSheetSection(canvas, dataX, y, dataW, catalogH, "PART CATALOG");
  for (int i = 0; i < typeIds.size(); i++)
    trussSheetRow(canvas, dataX, dataW, y + TRUSS_HEAD + 3 + i * TRUSS_ROW,
      typeIds.get(i), "x" + model.frameQuantities.get(typeIds.get(i)), true);
  y += catalogH + 6;

  String[][] folds = {
    { "Concave creases", str(model.concaveSharedJointCount) },
    { "Forced by twist", str(model.forcedConcaveJointCount()) },
    { "Avoidable", str(model.avoidableConcaveJointCount()) },
    { "Crease-free twist", "multiples of " +
      nf(360.0f / model.sectionSides, 1, 1) + " deg" }
  };
  float foldH = TRUSS_HEAD + 6 + folds.length * TRUSS_ROW;
  trussSheetSection(canvas, dataX, y, dataW, foldH, "WALL FOLDS");
  for (int i = 0; i < folds.length; i++)
    trussSheetRow(canvas, dataX, dataW, y + TRUSS_HEAD + 3 + i * TRUSS_ROW,
      folds[i][0], folds[i][1], false);
  y += foldH + 6;

  float stationH = TRUSS_HEAD + 6 + (model.bays + 1) * TRUSS_ROW;
  if (y + stationH < TRUSS_SHEET_H - 58) {
    trussSheetSection(canvas, dataX, y, dataW, stationH,
      "STATION KEY / RING POSITION");
    for (int i = 0; i <= model.bays; i++)
      trussSheetRow(canvas, dataX, dataW, y + TRUSS_HEAD + 3 + i * TRUSS_ROW,
        "Station " + i,
        nf(i * model.bayHeightMM, 1, 1) + " mm  /  " +
        nf(i * degrees(model.twistRadians), 1, 1) + " deg",
        i == 0 || i == model.bays);
  }

  drawTrussPanelPlates(canvas, model, viewY + viewH + 6);

  trussSheetFooter(canvas, model, "TY-001", "Truss assembly overview",
    generatedAt, new String[] {
      "MATCH JOINT IDS PANEL TO PANEL",
      "THREAD TIES FROM " + model.accessSide.label(),
      "SEE TY-002 FOR PANEL MAP",
      "PRINT PARTS FROM parts/" });
}

/* Every distinct printed part laid out flat and dimensioned, so a panel in the
   hand can be matched to a part number without measuring the model. */
void drawTrussPanelPlates(GeodesicGuideCanvas canvas, TrussMastModel model,
  float plateY) {
  float plateH = TRUSS_SHEET_H - 58 - plateY - 4;
  if (plateH <= 40) return;
  trussSheetSection(canvas, 11, plateY, TRUSS_SHEET_W - 22, plateH,
    "PANEL TYPES / FLAT PLATES, EDGE LENGTHS IN MM");

  ArrayList<String> seen = new ArrayList<String>();
  ArrayList<TrussFrameFace> examples = new ArrayList<TrussFrameFace>();
  for (TrussFrameFace face : model.frameFaces)
    if (!seen.contains(face.typeId)) { seen.add(face.typeId); examples.add(face); }

  int columns = max(1, min(examples.size(), 4));
  float cellW = (TRUSS_SHEET_W - 22) / columns;
  float cellH = plateH - TRUSS_HEAD - 6;
  for (int index = 0; index < columns; index++) {
    TrussFrameFace face = examples.get(index);
    float cellX = 11 + index * cellW;
    float cellY = plateY + TRUSS_HEAD + 3;
    float[] lengths = new float[3];
    for (int i = 0; i < 3; i++)
      lengths[i] = PVector.dist(face.world[i], face.world[(i + 1) % 3]);
    int quantity = model.frameQuantities.containsKey(face.typeId) ?
      model.frameQuantities.get(face.typeId) : 0;
    trussText(canvas, face.typeId + "   x" + quantity, cellX + cellW * 0.5f,
      cellY, TRUSS_ANNOTATION, true, CENTER);

    PVector[] plate = trussFlatPlate(lengths[0], lengths[1], lengths[2]);
    ArrayList<PVector> points = new ArrayList<PVector>();
    for (PVector p : plate) points.add(p);
    float plateTop = cellY + TRUSS_ROW * 1.3f;
    TrussSheetFit fit = trussFit(points, cellX, plateTop, cellW,
      cellH - (plateTop - cellY) - TRUSS_ROW, 6, false);
    PVector[] screen = new PVector[3];
    for (int i = 0; i < 3; i++) screen[i] = fit.place(plate[i]);
    canvas.polygon(screen, 0.45f, false);

    PVector g = PVector.add(PVector.add(screen[0], screen[1]), screen[2])
      .mult(1.0f / 3.0f);
    for (int i = 0; i < 3; i++) {
      PVector a = screen[i], b = screen[(i + 1) % 3];
      float mx = (a.x + b.x) * 0.5f, my = (a.y + b.y) * 0.5f;
      // Push the dimension outward from the centroid so it clears the plate
      // whatever the triangle's shape.
      float ox = mx - g.x, oy = my - g.y;
      float span = max(0.001f, sqrt(ox * ox + oy * oy));
      String mark = "";
      if (face.fabricationFace != null && i < face.fabricationFace.joints.size()) {
        GeodesicJointEdgeProfile joint = face.fabricationFace.joints.get(i);
        mark = joint.neighborFaceId < 0 ? " RIM" : (joint.concaveJoint ? " C" : "");
      }
      trussText(canvas, nf(lengths[i], 1, 1) + mark,
        mx + ox / span * 5.6f,
        my + oy / span * 5.6f - TRUSS_MICRO * TRUSS_TYPE_SCALE * 0.5f,
        TRUSS_MICRO, false, CENTER);
    }
  }
  float legendY = plateY + plateH - TRUSS_ROW * 1.1f;
  trussText(canvas, "C = concave crease edge    /    RIM = open end, no mate",
    14, legendY, TRUSS_MICRO, false, LEFT);
  if (examples.size() > columns)
    trussText(canvas, "+" + (examples.size() - columns) +
      " further types in bill_of_materials.json",
      TRUSS_SHEET_W - 14, legendY, TRUSS_MICRO, false, RIGHT);
}

// --------------------------------------------------------------------------
// TY-002 wall development
// --------------------------------------------------------------------------

void drawTrussDevelopmentSheet(GeodesicGuideCanvas canvas, TrussMastModel model,
  String generatedAt) {
  trussSheetFrame(canvas);
  trussSheetHeader(canvas, model, "WALL DEVELOPMENT + JOINT MAP");

  // The schedule takes only the rows it has and the map gets the rest. With
  // many bays the map is what runs out of room, not the table.
  ArrayList<String> scheduleKeys = new ArrayList<String>();
  for (TrussFrameJoint joint : model.frameJoints) {
    if (!joint.shared()) continue;
    String key = (joint.concave ? "CONCAVE" : "CONVEX") + "_" +
      round(joint.edgeLengthMM * 100) + "_" +
      round(joint.interiorDihedralDeg * 10) + "_" +
      round(joint.halfMiterDeg * 100);
    if (!scheduleKeys.contains(key)) scheduleKeys.add(key);
  }
  float devX = 11, devY = 30, devW = TRUSS_SHEET_W - 22;
  float schedH = TRUSS_HEAD + 8 + (min(scheduleKeys.size(), 8) + 1) * TRUSS_ROW;
  float devH = (TRUSS_SHEET_H - 52) - devY - 6 - schedH - 6;
  trussSheetSection(canvas, devX, devY, devW, devH,
    "WALL DEVELOPMENT / TUBE UNROLLED ABOUT ITS AXIS");

  PVector[] frame = trussAxisPlane(model);
  PVector u = frame[0], v = frame[1], direction = frame[2];

  float radius = 1;
  for (TrussFrameFace face : model.frameFaces)
    for (int i = 0; i < 3; i++) {
      PVector p = face.world[i];
      radius = max(radius, sqrt(sq(p.dot(u)) + sq(p.dot(v))));
    }

  ArrayList<PVector[]> cells = new ArrayList<PVector[]>();
  ArrayList<PVector> allPoints = new ArrayList<PVector>();
  for (TrussFrameFace face : model.frameFaces) {
    float sinSum = 0, cosSum = 0;
    float[] angles = new float[3];
    float[] axials = new float[3];
    for (int i = 0; i < 3; i++) {
      PVector p = face.world[i];
      angles[i] = atan2(p.dot(v), p.dot(u));
      axials[i] = p.dot(direction);
      sinSum += sin(angles[i]);
      cosSum += cos(angles[i]);
    }
    float mean = atan2(sinSum, cosSum);
    PVector[] cell = new PVector[3];
    for (int i = 0; i < 3; i++) {
      // Unwrap each corner to the branch nearest the panel's own centre so a
      // panel spanning the seam stays contiguous.
      float delta = angles[i] - mean;
      while (delta > PI) delta -= TWO_PI;
      while (delta < -PI) delta += TWO_PI;
      cell[i] = new PVector((mean + delta) * radius, axials[i]);
      allPoints.add(cell[i]);
    }
    cells.add(cell);
  }

  if (cells.size() > 0) {
    TrussSheetFit fit = trussFit(allPoints, devX, devY + 11, devW, devH - 20, 10, true);

    // Label size follows the drawn panel size, so a dense map stays readable
    // instead of overprinting itself.
    FloatList edgeLengths = new FloatList();
    for (PVector[] cell : cells) {
      PVector[] screen = new PVector[3];
      for (int i = 0; i < 3; i++) screen[i] = fit.place(cell[i]);
      for (int i = 0; i < 3; i++)
        edgeLengths.append(PVector.dist(screen[i], screen[(i + 1) % 3]));
    }
    edgeLengths.sort();
    float typical = edgeLengths.size() > 0 ?
      edgeLengths.get(edgeLengths.size() / 2) : 10;
    float label = constrain(typical * 0.13f, 0.9f, 3.0f) / TRUSS_TYPE_SCALE;
    boolean showFace = typical > 14.0f;

    canvas.beginGroup("development");
    for (int index = 0; index < cells.size(); index++) {
      TrussFrameFace face = model.frameFaces.get(index);
      PVector[] cell = cells.get(index);
      PVector[] screen = new PVector[3];
      for (int i = 0; i < 3; i++) screen[i] = fit.place(cell[i]);
      canvas.polygon(screen, 0.3f, false);
      float cx = (screen[0].x + screen[1].x + screen[2].x) / 3.0f;
      float cy = (screen[0].y + screen[1].y + screen[2].y) / 3.0f;
      // The FRAME_ prefix is on every panel and only costs width.
      String part = face.typeId.replace("FRAME_", "");
      if (showFace) {
        trussText(canvas, part, cx, cy - label * TRUSS_TYPE_SCALE * 1.3f,
          label, true, CENTER);
        trussText(canvas, "F" + face.id, cx,
          cy + label * TRUSS_TYPE_SCALE * 0.15f, label * 0.82f, false, CENTER);
      } else {
        trussText(canvas, part, cx, cy - label * TRUSS_TYPE_SCALE * 0.5f,
          label, true, CENTER);
      }
      for (int i = 0; i < 3; i++) {
        if (face.neighborFaceIds[i] < 0) continue;
        // A joint belongs to two panels. Drawing it from both stamped every
        // marker and label twice at the same spot, which is most of what made
        // a dense map unreadable.
        if (face.id > face.neighborFaceIds[i]) continue;
        PVector a = screen[i], b = screen[(i + 1) % 3];
        float t = face.portalStations[i];
        float px = a.x + (b.x - a.x) * t;
        float py = a.y + (b.y - a.y) * t;
        boolean concave = face.fabricationFace != null &&
          i < face.fabricationFace.joints.size() &&
          face.fabricationFace.joints.get(i).concaveJoint;
        float marker = constrain(typical * 0.05f, 0.45f, 1.15f);
        canvas.circle(px, py, marker, 0.25f, concave);
        if (showFace)
          trussText(canvas, face.jointIds[i], px + marker * 1.7f,
            py - label * TRUSS_TYPE_SCALE * 0.55f, label * 0.72f, false, LEFT);
      }
    }
    canvas.endGroup();
  }

  float legendY = devY + devH - 13;
  canvas.circle(devX + 6, legendY + 1.6f, 1.15f, 0.25f, false);
  trussText(canvas, "convex joint / tie point", devX + 9.5f, legendY, 2.5f, false, LEFT);
  canvas.circle(devX + 72, legendY + 1.6f, 1.15f, 0.25f, true);
  trussText(canvas, "concave crease / tie point", devX + 75.5f, legendY, 2.5f, false, LEFT);
  trussText(canvas, "each tie point is shared by the two panels meeting there",
    devX + devW - 3.2f, legendY, 2.5f, false, RIGHT);

  // --- joint schedule --------------------------------------------------
  float schedY = devY + devH + 6;
  trussSheetSection(canvas, devX, schedY, devW, schedH, "SHARED JOINT SCHEDULE");

  // Distinct joint geometries, not every joint: a hundred rows of the same
  // three numbers is not a schedule.
  ArrayList<String> keys = new ArrayList<String>();
  HashMap<String, ArrayList<String>> groups = new HashMap<String, ArrayList<String>>();
  HashMap<String, TrussFrameJoint> examples = new HashMap<String, TrussFrameJoint>();
  for (TrussFrameJoint joint : model.frameJoints) {
    if (!joint.shared()) continue;
    String key = (joint.concave ? "CONCAVE" : "CONVEX") + "_" +
      round(joint.edgeLengthMM * 100) + "_" +
      round(joint.interiorDihedralDeg * 10) + "_" +
      round(joint.halfMiterDeg * 100);
    if (!groups.containsKey(key)) {
      groups.put(key, new ArrayList<String>());
      examples.put(key, joint);
      keys.add(key);
    }
    groups.get(key).add(joint.label());
  }
  // Largest families first.
  for (int i = 1; i < keys.size(); i++)
    for (int j = i; j > 0 &&
      groups.get(keys.get(j)).size() > groups.get(keys.get(j - 1)).size(); j--) {
      String swap = keys.get(j); keys.set(j, keys.get(j - 1)); keys.set(j - 1, swap);
    }

  float[] columns = { 0, 30, 48, 82, 118, 158 };
  String[] headings = { "CLASS", "QTY", "EDGE mm", "DIHEDRAL", "HALF MITER", "JOINT IDS" };
  for (int i = 0; i < headings.length; i++)
    trussText(canvas, headings[i], devX + 3.2f + columns[i],
      schedY + TRUSS_HEAD + 3, 2.5f, true, LEFT);
  canvas.line(devX, schedY + TRUSS_HEAD + 3 + TRUSS_ROW * 0.85f,
    devX + devW, schedY + TRUSS_HEAD + 3 + TRUSS_ROW * 0.85f, 0.2f);
  for (int i = 0; i < keys.size(); i++) {
    float rowY = schedY + TRUSS_HEAD + 6 + TRUSS_ROW * 0.9f + i * TRUSS_ROW;
    if (rowY > schedY + schedH - TRUSS_ROW) {
      trussText(canvas, "... " + (keys.size() - i) +
        " further geometries in assembly_plan.json", devX + 3.2f, rowY,
        2.5f, true, LEFT);
      break;
    }
    TrussFrameJoint joint = examples.get(keys.get(i));
    ArrayList<String> ids = groups.get(keys.get(i));
    String[] values = {
      joint.concave ? "CONCAVE" : "CONVEX",
      "x" + ids.size(),
      nf(joint.edgeLengthMM, 1, 2),
      nf(joint.interiorDihedralDeg, 1, 1) + " deg",
      nf(joint.halfMiterDeg, 1, 2) + " deg",
      trussCompressJointIds(ids)
    };
    for (int k = 0; k < values.length; k++)
      trussText(canvas, values[k], devX + 3.2f + columns[k], rowY, 2.5f,
        k == 0, LEFT);
  }

  trussSheetFooter(canvas, model, "TY-002", "Wall development and joint map",
    generatedAt, new String[] {
      "FILLED TIE POINT = CONCAVE CREASE",
      "PANEL LABELS ARE PART / FACE",
      "MAP READS BASE AT BOTTOM",
      "FULL DATA IN assembly_plan.json" });
}

// --------------------------------------------------------------------------
// Export
// --------------------------------------------------------------------------

TrussCallSheetResult exportTrussCallSheets(File runFolder, TrussMastModel model,
  String stamp) {
  TrussCallSheetResult result = new TrussCallSheetResult();
  if (model == null || model.frameFaces.size() == 0) {
    result.status = "no triangle frame model";
    return result;
  }
  File folder = new File(runFolder, "call_sheets");
  if (!folder.exists() && !folder.mkdirs()) {
    result.status = "call sheet folder unavailable";
    return result;
  }
  String overviewTitle = "Truss Yard assembly overview";
  String developmentTitle = "Truss Yard wall development";
  String description = "Panel placement and joint reference for a modular mast " +
    "or tunnel. Zip ties are user supplied; the drawing describes geometry only.";
  try {
    result.overviewPng = "call_sheets/TY-001_assembly_overview.png";
    result.developmentPng = "call_sheets/TY-002_wall_development.png";
    GeodesicGuideCanvas overview = new GeodesicGuideRasterCanvas(
      new File(runFolder, result.overviewPng).getAbsolutePath(),
      TRUSS_SHEET_W, TRUSS_SHEET_H);
    overview.begin();
    drawTrussOverviewSheet(overview, model, stamp);
    overview.end();

    GeodesicGuideCanvas development = new GeodesicGuideRasterCanvas(
      new File(runFolder, result.developmentPng).getAbsolutePath(),
      TRUSS_SHEET_W, TRUSS_SHEET_H);
    development.begin();
    drawTrussDevelopmentSheet(development, model, stamp);
    development.end();

    if (trussCallSheetSvgEnabled) {
      result.overviewSvg = "call_sheets/TY-001_assembly_overview.svg";
      result.developmentSvg = "call_sheets/TY-002_wall_development.svg";
      GeodesicGuideCanvas overviewSvg = new GeodesicGuideSvgCanvas(
        new File(runFolder, result.overviewSvg).getAbsolutePath(),
        TRUSS_SHEET_W, TRUSS_SHEET_H, overviewTitle, description);
      overviewSvg.begin();
      drawTrussOverviewSheet(overviewSvg, model, stamp);
      overviewSvg.end();

      GeodesicGuideCanvas developmentSvg = new GeodesicGuideSvgCanvas(
        new File(runFolder, result.developmentSvg).getAbsolutePath(),
        TRUSS_SHEET_W, TRUSS_SHEET_H, developmentTitle, description);
      developmentSvg.begin();
      drawTrussDevelopmentSheet(developmentSvg, model, stamp);
      developmentSvg.end();
    }
    result.success = new File(runFolder, result.overviewPng).exists() &&
      new File(runFolder, result.developmentPng).exists();
    result.status = result.success ?
      "2 PNG" + (trussCallSheetSvgEnabled ? " + 2 SVG" : " / SVG OFF") :
      "call sheet files missing";
  } catch (Exception error) {
    result.success = false;
    result.status = "call sheet render failed: " + error.getClass().getSimpleName();
  }
  return result;
}
