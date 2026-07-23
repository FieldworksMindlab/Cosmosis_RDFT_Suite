/*
  Geodesic Salon illustrated assembly guides.

  Both guide styles consume the same live panel catalog and face graph used by
  STL export. The renderer describes geometric adjacency only. It never invents
  joining hardware, and it labels the staged traversal as illustrative.
*/

final int GEODESIC_GUIDE_PNG_W = 4960;
final int GEODESIC_GUIDE_PNG_H = 3508;
// The principal working copy is deliberately 50% larger than the first guide
// revision. Secondary annotations also move up one size tier for print use.
final float GEODESIC_GUIDE_BODY_MM = 5.10f;
final float GEODESIC_GUIDE_ANNOTATION_MM = 3.95f;
final float GEODESIC_GUIDE_MICRO_MM = 3.55f;
final float GEODESIC_GUIDE_BOTTOM_TITLE_MM = 4.20f;
final float GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM = 4.72f;
final float GEODESIC_GUIDE_BOTTOM_MICRO_MM = 4.28f;

enum GeodesicGuideStyle {
  OVERVIEW,
  ASSEMBLY_MAP,
  KICAS_SEQUENCE
}

class GeodesicGuideStage {
  int index;
  int targetCount;
  ArrayList<Integer> faceIds = new ArrayList<Integer>();
  ArrayList<Integer> newFaceIds = new ArrayList<Integer>();

  GeodesicGuideStage(int index, int targetCount) {
    this.index = index;
    this.targetCount = targetCount;
  }
}

class GeodesicGuideValidation {
  ArrayList<String> errors = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();
  int reciprocalAdjacencies = 0;
  int stageCount = 0;
  String physicalJointStatus =
    "integral_portals_only_hardware_user_supplied";

  boolean valid() { return errors.size() == 0; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema", "fieldworks.geodesic_salon.guide_validation.v1");
    json.setBoolean("valid", valid());
    json.setString("physical_joint_status", physicalJointStatus);
    json.setInt("connector_components", 0);
    json.setInt("reciprocal_adjacencies", reciprocalAdjacencies);
    json.setInt("connected_stages", stageCount);
    JSONArray errorValues = new JSONArray();
    for (int i = 0; i < errors.size(); i++) errorValues.setString(i, errors.get(i));
    json.setJSONArray("errors", errorValues);
    JSONArray warningValues = new JSONArray();
    for (int i = 0; i < warnings.size(); i++) warningValues.setString(i, warnings.get(i));
    json.setJSONArray("warnings", warningValues);
    return json;
  }
}

class GeodesicGuideData {
  GeodesicModel model;
  GeodesicPanelCatalog catalog;
  HashMap<String, GeodesicPartType> typesById = new HashMap<String, GeodesicPartType>();
  ArrayList<GeodesicGuideStage> stages = new ArrayList<GeodesicGuideStage>();
  GeodesicGuideValidation validation = new GeodesicGuideValidation();
  int seedFaceId = -1;
  String generatedAt;
  GeodesicFabricationSettings fabrication;

  GeodesicGuideData(GeodesicModel model, GeodesicPanelCatalog catalog, String generatedAt) {
    this.model = model;
    this.catalog = catalog;
    this.generatedAt = generatedAt;
    if (catalog != null) for (GeodesicPartType type : catalog.types) typesById.put(type.typeId, type);
    fabrication = catalog != null && catalog.fabrication != null ?
      catalog.fabrication.copy() :
      currentGeodesicFabricationSettings();
  }

  String typeForFace(int faceId) {
    if (catalog == null || !catalog.faceToType.containsKey(faceId)) return "UNASSIGNED";
    return catalog.faceToType.get(faceId);
  }
}

class GeodesicGuideExportResult {
  boolean success;
  boolean svgEnabled;
  String status = "not generated";
  String overviewPng = "";
  String mapPng = "";
  String overviewSvg = "";
  String mapSvg = "";
  String kicasPng = "";
  String kicasSvg = "";
  String validationFile = "guides/guide_validation.json";
  GeodesicGuideValidation validation;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("success", success);
    json.setBoolean("svg_enabled", svgEnabled);
    json.setString("status", status);
    json.setString("overview_png", overviewPng);
    json.setString("assembly_map_png", mapPng);
    json.setString("overview_svg", overviewSvg);
    json.setString("assembly_map_svg", mapSvg);
    json.setString("kicas_sequence_png", kicasPng);
    json.setString("kicas_sequence_svg", kicasSvg);
    json.setString("validation", validationFile);
    return json;
  }
}

abstract class GeodesicGuideCanvas {
  float pageW = 594;
  float pageH = 420;

  abstract void begin();
  abstract void end();
  abstract void beginGroup(String id);
  abstract void endGroup();
  abstract void line(float x1, float y1, float x2, float y2, float weight);
  abstract void dashedLine(float x1, float y1, float x2, float y2, float weight, float dash, float gap);
  abstract void rect(float x, float y, float w, float h, float weight, boolean blackFill);
  abstract void polygon(PVector[] points, float weight, boolean blackFill);
  abstract void circle(float x, float y, float radius, float weight, boolean blackFill);
  abstract void textLine(String value, float x, float y, float size, boolean bold, int align);
  abstract void logo(float x, float y, float w, float h);
}

class GeodesicGuideRasterCanvas extends GeodesicGuideCanvas {
  PGraphics pg;
  String filename;
  float sx;
  float sy;
  PFont regular;
  PFont bold;

  GeodesicGuideRasterCanvas(String filename) {
    this.filename = filename;
    sx = GEODESIC_GUIDE_PNG_W / pageW;
    sy = GEODESIC_GUIDE_PNG_H / pageH;
    pg = createGraphics(GEODESIC_GUIDE_PNG_W, GEODESIC_GUIDE_PNG_H, JAVA2D);
    pg.pixelDensity = 1;
    pg.setSize(GEODESIC_GUIDE_PNG_W, GEODESIC_GUIDE_PNG_H);
    pg.noSmooth();
    regular = createFont("Helvetica", 28, true);
    bold = createFont("Helvetica Bold", 28, true);
  }

  void begin() {
    pg.beginDraw();
    pg.background(255);
    pg.strokeCap(SQUARE);
    pg.strokeJoin(MITER);
  }

  void end() {
    pg.endDraw();
    pg.save(filename);
  }

  void beginGroup(String id) { }
  void endGroup() { }

  void line(float x1, float y1, float x2, float y2, float weight) {
    pg.stroke(0); pg.noFill(); pg.strokeWeight(max(1, weight * sx));
    pg.line(x1 * sx, y1 * sy, x2 * sx, y2 * sy);
  }

  void dashedLine(float x1, float y1, float x2, float y2, float weight, float dash, float gap) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    float length = sqrt(dx * dx + dy * dy);
    if (length <= 0.0001f) return;
    float ux = dx / length;
    float uy = dy / length;
    for (float d = 0; d < length; d += dash + gap) {
      float e = min(length, d + dash);
      line(x1 + ux * d, y1 + uy * d, x1 + ux * e, y1 + uy * e, weight);
    }
  }

  void rect(float x, float y, float w, float h, float weight, boolean blackFill) {
    pg.stroke(0); pg.strokeWeight(max(1, weight * sx));
    if (blackFill) pg.fill(0); else pg.noFill();
    pg.rect(x * sx, y * sy, w * sx, h * sy);
  }

  void polygon(PVector[] points, float weight, boolean blackFill) {
    pg.stroke(0); pg.strokeWeight(max(1, weight * sx));
    if (blackFill) pg.fill(0); else pg.noFill();
    pg.beginShape();
    for (PVector point : points) pg.vertex(point.x * sx, point.y * sy);
    pg.endShape(CLOSE);
  }

  void circle(float x, float y, float radius, float weight, boolean blackFill) {
    pg.stroke(0); pg.strokeWeight(max(1, weight * sx));
    if (blackFill) pg.fill(0); else pg.noFill();
    pg.ellipse(x * sx, y * sy, radius * 2 * sx, radius * 2 * sy);
  }

  void textLine(String value, float x, float y, float size, boolean isBold, int align) {
    pg.fill(0); pg.noStroke();
    pg.textFont(isBold ? bold : regular);
    pg.textSize(size * sy);
    pg.textAlign(align, TOP);
    pg.text(value, x * sx, y * sy);
  }

  void logo(float x, float y, float w, float h) {
    PImage image = fieldworksLogoImage();
    if (image == null) {
      textLine("FIELDWORKS MINDLAB", x + w * 0.5f, y + h * 0.34f, 5.0f, true, CENTER);
      return;
    }
    float scale = min((w * sx) / image.width, (h * sy) / image.height);
    float dw = image.width * scale;
    float dh = image.height * scale;
    pg.image(image, x * sx + (w * sx - dw) * 0.5f, y * sy + (h * sy - dh) * 0.5f, dw, dh);
  }
}

class GeodesicGuideSvgCanvas extends GeodesicGuideCanvas {
  PrintWriter out;
  String filename;

  GeodesicGuideSvgCanvas(String filename) { this.filename = filename; }

  void begin() {
    out = createWriter(filename);
    out.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
    out.println("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 594 420\" width=\"594mm\" height=\"420mm\" role=\"img\" aria-label=\"Geodesic Salon assembly guide\">");
    out.println("<title>Geodesic Salon illustrated assembly guide</title>");
    out.println("<desc>Geometric panel placement and adjacency reference. Physical joint hardware is not included.</desc>");
    out.println("<rect width=\"594\" height=\"420\" fill=\"#ffffff\"/>");
  }

  void end() {
    out.println("</svg>");
    out.flush();
    out.close();
  }

  void beginGroup(String id) { out.println("<g id=\"" + safeXml(id) + "\">"); }
  void endGroup() { out.println("</g>"); }

  void line(float x1, float y1, float x2, float y2, float weight) {
    out.println("<line x1=\"" + svgNum(x1) + "\" y1=\"" + svgNum(y1) + "\" x2=\"" + svgNum(x2) + "\" y2=\"" + svgNum(y2) + "\" stroke=\"#000000\" stroke-width=\"" + svgNum(weight) + "\" stroke-linecap=\"square\"/>");
  }

  void dashedLine(float x1, float y1, float x2, float y2, float weight, float dash, float gap) {
    out.println("<line x1=\"" + svgNum(x1) + "\" y1=\"" + svgNum(y1) + "\" x2=\"" + svgNum(x2) + "\" y2=\"" + svgNum(y2) + "\" stroke=\"#000000\" stroke-width=\"" + svgNum(weight) + "\" stroke-dasharray=\"" + svgNum(dash) + " " + svgNum(gap) + "\"/>");
  }

  void rect(float x, float y, float w, float h, float weight, boolean blackFill) {
    out.println("<rect x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" width=\"" + svgNum(w) + "\" height=\"" + svgNum(h) + "\" fill=\"" + (blackFill ? "#000000" : "none") + "\" stroke=\"#000000\" stroke-width=\"" + svgNum(weight) + "\"/>");
  }

  void polygon(PVector[] points, float weight, boolean blackFill) {
    String value = "";
    for (int i = 0; i < points.length; i++) {
      if (i > 0) value += " ";
      value += svgNum(points[i].x) + "," + svgNum(points[i].y);
    }
    out.println("<polygon points=\"" + value + "\" fill=\"" + (blackFill ? "#000000" : "none") + "\" stroke=\"#000000\" stroke-width=\"" + svgNum(weight) + "\" stroke-linejoin=\"miter\"/>");
  }

  void circle(float x, float y, float radius, float weight, boolean blackFill) {
    out.println("<circle cx=\"" + svgNum(x) + "\" cy=\"" + svgNum(y) + "\" r=\"" + svgNum(radius) + "\" fill=\"" + (blackFill ? "#000000" : "none") + "\" stroke=\"#000000\" stroke-width=\"" + svgNum(weight) + "\"/>");
  }

  void textLine(String value, float x, float y, float size, boolean bold, int align) {
    String anchor = align == CENTER ? "middle" : (align == RIGHT ? "end" : "start");
    out.println("<text x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" fill=\"#000000\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"" + svgNum(size) + "\" font-weight=\"" + (bold ? "700" : "400") + "\" text-anchor=\"" + anchor + "\" dominant-baseline=\"hanging\">" + safeXml(value) + "</text>");
  }

  void logo(float x, float y, float w, float h) {
    File file = new File(sketchPath("data/" + FIELDWORKS_LOGO_FILE));
    if (!file.exists()) {
      textLine("FIELDWORKS MINDLAB", x + w * 0.5f, y + h * 0.34f, 5.0f, true, CENTER);
      return;
    }
    try {
      byte[] bytes = java.nio.file.Files.readAllBytes(file.toPath());
      String encoded = java.util.Base64.getEncoder().encodeToString(bytes);
      out.println("<image href=\"data:image/png;base64," + encoded + "\" x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" width=\"" + svgNum(w) + "\" height=\"" + svgNum(h) + "\" preserveAspectRatio=\"xMidYMid meet\"/>");
    } catch (Exception error) {
      textLine("FIELDWORKS MINDLAB", x + w * 0.5f, y + h * 0.34f, 5.0f, true, CENTER);
    }
  }
}

class GeodesicGuideProjection {
  GeodesicModel model;
  CallSheetBasis basis;
  CallSheetBounds bounds = new CallSheetBounds();

  GeodesicGuideProjection(GeodesicModel model, float azimuth, float elevation) {
    this.model = model;
    basis = callSheetBasis(azimuth, elevation);
    for (GeodesicVertex vertex : model.vertices) bounds.include(callSheetProject(vertex.position, new PVector(), basis));
  }

  PVector screen(PVector point, float x, float y, float w, float h, float padding) {
    PVector projected = callSheetProject(point, new PVector(), basis);
    float bw = max(0.001f, bounds.maxX - bounds.minX);
    float bh = max(0.001f, bounds.maxY - bounds.minY);
    float scale = min((w - padding * 2) / bw, (h - padding * 2) / bh);
    float cx = x + w * 0.5f;
    float cy = y + h * 0.5f;
    float bx = (bounds.minX + bounds.maxX) * 0.5f;
    float by = (bounds.minY + bounds.maxY) * 0.5f;
    return new PVector(cx + (projected.x - bx) * scale, cy + (projected.y - by) * scale, projected.z);
  }

  boolean visible(GeodesicFace face) { return face.normal.dot(basis.view) >= -0.015f; }
}

GeodesicGuideData buildGeodesicGuideData(GeodesicModel model, GeodesicPanelCatalog catalog, String generatedAt) {
  GeodesicGuideData data = new GeodesicGuideData(model, catalog, generatedAt);
  GeodesicGuideValidation validation = data.validation;
  if (model == null || !model.valid || model.faces.size() == 0) {
    validation.errors.add("GUIDE_DOMAIN_INVALID");
    return data;
  }
  if (catalog == null || catalog.types.size() == 0) {
    validation.errors.add("GUIDE_PANEL_CATALOG_EMPTY");
    return data;
  }
  int quantity = 0;
  for (GeodesicPartType type : catalog.types) {
    quantity += type.quantity;
    if (type.typeId == null || type.typeId.length() == 0) validation.errors.add("GUIDE_PANEL_TYPE_ID_MISSING");
  }
  if (quantity != model.faces.size()) validation.errors.add("GUIDE_BOM_FACE_COUNT_MISMATCH " + quantity + " != " + model.faces.size());
  for (GeodesicFace face : model.faces) {
    if (!catalog.faceToType.containsKey(face.id)) validation.errors.add("GUIDE_FACE_TYPE_MISSING face " + face.id);
    if (!geodesicFinite(face.normal.x) || !geodesicFinite(face.normal.y) || !geodesicFinite(face.normal.z) || face.normal.magSq() < 0.000001f) {
      validation.errors.add("GUIDE_NORMAL_INVALID face " + face.id);
    }
    for (int neighbor : face.neighbors) {
      if (neighbor < 0) continue;
      if (neighbor >= model.faces.size()) {
        validation.errors.add("GUIDE_NEIGHBOR_INVALID face " + face.id + " -> " + neighbor);
        continue;
      }
      boolean reciprocal = false;
      for (int reverse : model.faces.get(neighbor).neighbors) if (reverse == face.id) reciprocal = true;
      if (!reciprocal) validation.errors.add("GUIDE_ADJACENCY_NOT_RECIPROCAL " + face.id + " <-> " + neighbor);
      else if (face.id < neighbor) validation.reciprocalAdjacencies++;
    }
  }
  data.seedFaceId = geodesicGuideSeedFace(model);
  ArrayList<Integer> order = geodesicGuideBreadthFirstOrder(model, data.seedFaceId);
  if (order.size() != model.faces.size()) validation.errors.add("GUIDE_FACE_GRAPH_DISCONNECTED " + order.size() + "/" + model.faces.size());
  data.stages = geodesicGuideStages(order);
  for (GeodesicGuideStage stage : data.stages) {
    if (!geodesicGuideStageConnected(model, stage.faceIds)) validation.errors.add("GUIDE_STAGE_DISCONNECTED " + stage.index);
    else validation.stageCount++;
  }
  if (data.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    validation.physicalJointStatus =
      "KICAS_integral_slide_capture_plus_center_tie_reinforcement";
    GeodesicKicasPlan plan = data.fabrication.kicasPlan;
    if (plan == null) validation.errors.add("GUIDE_KICAS_PLAN_MISSING");
    else if (!plan.valid)
      validation.errors.add("GUIDE_KICAS_PLAN_INVALID " + plan.validation);
    else if (plan.steps.size() != model.faces.size())
      validation.errors.add("GUIDE_KICAS_PLACEMENT_COUNT_MISMATCH");
  }
  if (catalog.types.size() > 12) validation.warnings.add("GUIDE_PANEL_CATALOG_COMPACTED " + catalog.types.size() + " types");
  return data;
}

boolean geodesicFinite(float value) { return !Float.isNaN(value) && !Float.isInfinite(value); }

int geodesicGuideSeedFace(GeodesicModel model) {
  int best = 0;
  float bestZ = -Float.MAX_VALUE;
  for (GeodesicFace face : model.faces) {
    if (face.centroid.z > bestZ + 0.0001f || (abs(face.centroid.z - bestZ) <= 0.0001f && face.id < best)) {
      best = face.id;
      bestZ = face.centroid.z;
    }
  }
  return best;
}

ArrayList<Integer> geodesicGuideBreadthFirstOrder(GeodesicModel model, int seedFaceId) {
  ArrayList<Integer> result = new ArrayList<Integer>();
  if (model == null || seedFaceId < 0 || seedFaceId >= model.faces.size()) return result;
  boolean[] seen = new boolean[model.faces.size()];
  java.util.ArrayDeque<Integer> queue = new java.util.ArrayDeque<Integer>();
  queue.add(seedFaceId);
  seen[seedFaceId] = true;
  while (!queue.isEmpty()) {
    int faceId = queue.removeFirst();
    result.add(faceId);
    ArrayList<Integer> neighbors = new ArrayList<Integer>();
    for (int neighbor : model.faces.get(faceId).neighbors) if (neighbor >= 0) neighbors.add(neighbor);
    java.util.Collections.sort(neighbors);
    for (int neighbor : neighbors) if (!seen[neighbor]) {
      seen[neighbor] = true;
      queue.addLast(neighbor);
    }
  }
  return result;
}

ArrayList<GeodesicGuideStage> geodesicGuideStages(ArrayList<Integer> order) {
  ArrayList<GeodesicGuideStage> stages = new ArrayList<GeodesicGuideStage>();
  int total = order.size();
  if (total == 0) return stages;
  float[] fractions = { 0.04f, 0.15f, 0.31f, 0.52f, 0.78f, 1.0f };
  int previous = 0;
  for (int i = 0; i < fractions.length; i++) {
    int target = i == fractions.length - 1 ? total : max(i == 0 ? min(3, total) : previous, round(total * fractions[i]));
    target = constrain(target, 1, total);
    if (target < total && i > 0) target = max(target, min(total, previous + 1));
    GeodesicGuideStage stage = new GeodesicGuideStage(i + 1, target);
    for (int j = 0; j < target; j++) stage.faceIds.add(order.get(j));
    for (int j = previous; j < target; j++) stage.newFaceIds.add(order.get(j));
    stages.add(stage);
    previous = target;
  }
  return stages;
}

boolean geodesicGuideStageConnected(GeodesicModel model, ArrayList<Integer> faceIds) {
  if (faceIds.size() == 0) return false;
  HashSet<Integer> allowed = new HashSet<Integer>(faceIds);
  HashSet<Integer> visited = new HashSet<Integer>();
  java.util.ArrayDeque<Integer> queue = new java.util.ArrayDeque<Integer>();
  queue.add(faceIds.get(0));
  visited.add(faceIds.get(0));
  while (!queue.isEmpty()) {
    int faceId = queue.removeFirst();
    for (int neighbor : model.faces.get(faceId).neighbors) if (allowed.contains(neighbor) && !visited.contains(neighbor)) {
      visited.add(neighbor);
      queue.addLast(neighbor);
    }
  }
  return visited.size() == allowed.size();
}

GeodesicGuideExportResult exportGeodesicAssemblyGuides(File runFolder, GeodesicPanelCatalog catalog, String stamp) {
  GeodesicGuideExportResult result = new GeodesicGuideExportResult();
  result.svgEnabled = geodesicGuideSvgEnabled;
  File guideFolder = new File(runFolder, "guides");
  if (!guideFolder.exists() && !guideFolder.mkdirs()) {
    result.status = "guide folder unavailable";
    result.validation = new GeodesicGuideValidation();
    result.validation.errors.add("GUIDE_FOLDER_CREATE_FAILED");
    return result;
  }
  GeodesicGuideData data = buildGeodesicGuideData(geodesicModel, catalog, stamp);
  result.validation = data.validation;
  saveJSONObject(data.validation.toJSON(), new File(guideFolder, "guide_validation.json").getAbsolutePath());
  if (!data.validation.valid()) {
    result.status = "guide validation blocked";
    return result;
  }
  result.overviewPng = "guides/GS-001_assembly_overview.png";
  result.mapPng = "guides/GS-002_digital_assembly_map.png";
  try {
    renderGeodesicGuide(new GeodesicGuideRasterCanvas(new File(runFolder, result.overviewPng).getAbsolutePath()), data, GeodesicGuideStyle.OVERVIEW);
    renderGeodesicGuide(new GeodesicGuideRasterCanvas(new File(runFolder, result.mapPng).getAbsolutePath()), data, GeodesicGuideStyle.ASSEMBLY_MAP);
    if (data.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
      result.kicasPng = "guides/GS-003_KICAS_sequence.png";
      renderGeodesicGuide(new GeodesicGuideRasterCanvas(
        new File(runFolder, result.kicasPng).getAbsolutePath()),
        data, GeodesicGuideStyle.KICAS_SEQUENCE);
    }
    if (geodesicGuideSvgEnabled) {
      result.overviewSvg = "guides/GS-001_assembly_overview.svg";
      result.mapSvg = "guides/GS-002_digital_assembly_map.svg";
      renderGeodesicGuide(new GeodesicGuideSvgCanvas(new File(runFolder, result.overviewSvg).getAbsolutePath()), data, GeodesicGuideStyle.OVERVIEW);
      renderGeodesicGuide(new GeodesicGuideSvgCanvas(new File(runFolder, result.mapSvg).getAbsolutePath()), data, GeodesicGuideStyle.ASSEMBLY_MAP);
      if (data.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
        result.kicasSvg = "guides/GS-003_KICAS_sequence.svg";
        renderGeodesicGuide(new GeodesicGuideSvgCanvas(
          new File(runFolder, result.kicasSvg).getAbsolutePath()),
          data, GeodesicGuideStyle.KICAS_SEQUENCE);
      }
    }
    result.success = new File(runFolder, result.overviewPng).exists() &&
      new File(runFolder, result.mapPng).exists() &&
      (data.fabrication.assemblyMode != GeodesicAssemblyMode.KICAS ||
      new File(runFolder, result.kicasPng).exists());
    int guideCount = data.fabrication.assemblyMode ==
      GeodesicAssemblyMode.KICAS ? 3 : 2;
    result.status = result.success ? guideCount + " PNG" +
      (geodesicGuideSvgEnabled ? " + " + guideCount + " SVG" :
      " / SVG OFF") : "guide files missing";
  } catch (Exception error) {
    result.success = false;
    result.status = "guide render failed: " + error.getClass().getSimpleName();
    data.validation.errors.add("GUIDE_RENDER_FAILED " + error.getMessage());
    saveJSONObject(data.validation.toJSON(), new File(guideFolder, "guide_validation.json").getAbsolutePath());
  }
  return result;
}

void renderGeodesicGuide(GeodesicGuideCanvas canvas, GeodesicGuideData data, GeodesicGuideStyle style) {
  canvas.begin();
  canvas.beginGroup("page-frame");
  canvas.rect(5, 5, 584, 410, 0.7f, false);
  canvas.rect(7.2f, 7.2f, 579.6f, 405.6f, 0.22f, false);
  canvas.endGroup();
  if (style == GeodesicGuideStyle.OVERVIEW)
    drawGeodesicGuideOverview(canvas, data);
  else if (style == GeodesicGuideStyle.ASSEMBLY_MAP)
    drawGeodesicGuideAssemblyMap(canvas, data);
  else drawGeodesicGuideKicasSequence(canvas, data);
  canvas.end();
}

boolean guideKicas(GeodesicGuideData data) {
  return data != null && data.fabrication != null &&
    data.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS;
}

int guideKicasLockPairs(GeodesicGuideData data) {
  return guideKicas(data) && data.fabrication.kicasPlan != null ?
    data.fabrication.kicasPlan.lockingEdgePairs : 0;
}

void drawGeodesicGuideOverview(GeodesicGuideCanvas canvas, GeodesicGuideData data) {
  boolean kicas = guideKicas(data);
  canvas.beginGroup("header");
  canvas.textLine("GEODESIC SALON - ASSEMBLY OVERVIEW", 11, 11, 9.0f, true, LEFT);
  canvas.textLine(data.model.extent.label() + " / " + data.model.family.label() +
    " / F" + data.model.frequency + "  |  " + data.model.faces.size() +
    (kicas ? " ORDERED PARTS  |  " : " PANEL PLACEMENTS  |  ") +
    data.catalog.types.size() + (kicas ? " BASE GEOMETRIES" :
    " REUSABLE GEOMETRIES"), 11, 23, GEODESIC_GUIDE_ANNOTATION_MM,
    false, LEFT);
  canvas.rect(11, 31, 420, 17, 0.32f, false);
  canvas.textLine(kicas ?
    "P### INTERIOR ORDER MARKS + INTEGRAL LOCKS + CENTER TIE PORTALS" :
    "RECESSED INTERIOR MATE CODES + INTEGRAL PORTALS / HARDWARE USER-SUPPLIED",
    15, 34, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  canvas.textLine(kicas ?
    "Follow P### order; slide each lock home, then reinforce aligned center portals with a zip tie." :
    "Match identical edge codes; assembly JSON records reciprocal portals, dihedral, and junction guidance.",
    15, 40, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.logo(454, 9, 122, 38);
  canvas.endGroup();

  float bodyY = 53;
  float bodyH = 319;
  guideSection(canvas, 10, bodyY, 194, bodyH, "FINAL ASSEMBLED VIEW");
  guideSection(canvas, 207, bodyY, 250, bodyH, "SIX-STAGE GEOMETRIC OVERVIEW");
  guideSection(canvas, 460, bodyY, 124, bodyH, "KIT REFERENCE");

  canvas.beginGroup("hero-view");
  guideDrawCompleteModel(canvas, data, 18, bodyY + 20, 178, 235, 38, 24, true);
  canvas.textLine("Completed " + data.model.extent.label().toLowerCase() + " shell", 18, bodyY + 267, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  canvas.textLine(data.model.faces.size() + (kicas ? " ordered STL placements" :
    " panel placements"), 18, bodyY + 276, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.textLine(data.catalog.types.size() + (kicas ? " base geometry classes" :
    " reusable STL geometries"), 18, bodyY + 284, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  guideTextBlock(canvas, kicas ?
    "Keep P### marks inward. Seat each lock first; align and zip-tie the center portals second." :
    "Match identical interior mate codes and keep marked normals outward.",
    18, bodyY + 294, 176, GEODESIC_GUIDE_BODY_MM, 5.85f, false, 3);
  canvas.endGroup();

  canvas.beginGroup("assembly-steps");
  String[] titles = { "SEED CLUSTER", "FIRST RING", "PRIMARY REGION", "EXTEND SHELL", "FILL NETWORK", "VERIFY COMPLETE" };
  for (int i = 0; i < 6; i++) {
    int col = i % 3;
    int row = i / 3;
    float cellX = 211 + col * 81.0f;
    float cellY = bodyY + 17 + row * 148.0f;
    canvas.rect(cellX, cellY, 78, 142, 0.25f, false);
    canvas.rect(cellX + 3, cellY + 4, 7, 7, 0.25f, true);
    canvas.textLine(str(i + 1), cellX + 6.5f, cellY + 4.7f, 3.0f, true, CENTER);
    canvas.textLine(titles[i], cellX + 13, cellY + 4.5f, 3.25f, true, LEFT);
    guideDrawStage(canvas, data, data.stages.get(i), cellX + 3, cellY + 14, 72, 96, 38, 24, 2);
    canvas.textLine(data.stages.get(i).targetCount + " faces connected", cellX + 4, cellY + 111, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
    guideTextBlock(canvas, guideStageCaption(i, data), cellX + 4, cellY + 119, 70, GEODESIC_GUIDE_BODY_MM, 5.65f, false, 4);
  }
  canvas.endGroup();

  canvas.beginGroup("kit-reference");
  float refX = 466;
  canvas.textLine("BILL OF MATERIALS", refX, bodyY + 19, 4.50f, true, LEFT);
  float listY = bodyY + 28;
  for (int i = 0; i < data.catalog.types.size() && i < 12; i++) {
    GeodesicPartType type = data.catalog.types.get(i);
    canvas.textLine(guideCatalogTypeLabel(data, type), refX, listY,
      3.82f, true, LEFT);
    canvas.textLine("x " + type.quantity, refX + 108, listY, 3.82f, true, RIGHT);
    listY += 6;
  }
  canvas.line(refX, listY + 1, refX + 108, listY + 1, 0.22f);
  canvas.textLine("TOTAL", refX, listY + 4, 3.82f, true, LEFT);
  canvas.textLine(str(data.model.faces.size()), refX + 108, listY + 4, 3.82f, true, RIGHT);
  float partTop = min(bodyY + 122, listY + 16);
  canvas.textLine("PANEL REFERENCE", refX, partTop, 4.50f, true, LEFT);
  float rowH = min(30, 126.0f / max(1, min(4, data.catalog.types.size())));
  for (int i = 0; i < data.catalog.types.size() && i < 4; i++) {
    float py = partTop + 8 + i * rowH;
    GeodesicPartType type = data.catalog.types.get(i);
    guideDrawPanelThumbnail(canvas, data, type, refX, py, 35, rowH - 2);
    canvas.textLine(guideCatalogTypeLabel(data, type) + "  x" +
      type.quantity, refX + 39, py + 1, 3.68f, true, LEFT);
    guideTextBlock(canvas, guideEdgeCodesSummary(data, type), refX + 39, py + 7, 68,
      GEODESIC_GUIDE_BOTTOM_MICRO_MM, 4.45f, false, 2);
  }
  float techY = bodyY + 255;
  canvas.textLine("CONFIGURATION", refX, techY, 3.0f, true, LEFT);
  String[] notes = {
    "RADIUS " + nf(data.model.radius, 1, 1) + " mm / F" + data.model.frequency,
    "PANEL " + data.fabrication.style.label() + " / " + data.fabrication.reliefSide.label(),
    "FRAME D" + nf(data.fabrication.frameDepthMM, 1, 1) + " W" + nf(data.fabrication.frameWidthMM, 1, 1) + " / SKIN " + nf(data.fabrication.skinThicknessMM, 1, 1),
    (kicas ? "CENTER PORTALS " : "PORTALS ") +
      (data.fabrication.fastenerPortals ?
      nf(data.fabrication.portalWidthMM * (kicas ?
      data.fabrication.kicasPortalScale : 1.0f), 1, 1) + " x " +
      nf(data.fabrication.portalHeightMM, 1, 1) + " mm" : "OFF"),
    kicas ? "KICAS " + guideKicasLockPairs(data) + " LOCK PAIRS" :
      "MATE CODES " + guidePhysicalMateCodeSummary(data),
    "EDGE BREAK " + nf(data.fabrication.edgeBreakMM, 1, 2) + " / RELIEF " + nf(geodesicReliefMM, 1, 1) + " mm",
    "GROWTH " + geodesicGrowth.label(),
    "100%  " + geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 100),
    "200%  " + geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 200),
    "300%  " + geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 300)
  };
  for (int i = 0; i < notes.length; i++) canvas.textLine(notes[i], refX,
    techY + 8 + i * 5.35f, GEODESIC_GUIDE_ANNOTATION_MM,
    i >= notes.length - 3, LEFT);
  canvas.endGroup();
  drawGeodesicGuideFooter(canvas, data, "GS-001", "ASSEMBLY OVERVIEW");
}

void drawGeodesicGuideAssemblyMap(GeodesicGuideCanvas canvas, GeodesicGuideData data) {
  boolean kicas = guideKicas(data);
  canvas.beginGroup("header-title");
  canvas.textLine("GEODESIC SALON - RECURSIVE SPHEROID KIT", 11, 10, 7.8f, true, LEFT);
  canvas.textLine("DIGITAL ASSEMBLY MAP - NO SEPARATE CONNECTORS", 11, 20, 4.0f, true, LEFT);
  canvas.rect(11, 28, 215, 20, 0.3f, false);
  canvas.textLine(kicas ? "P### PLACEMENT IDS / KICAS LOCKS / CENTER PORTALS" :
    "LOGICAL MATE CODES / INTEGRAL PORTALS", 16, 31,
    GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
  canvas.textLine(kicas ?
    "Use P### install order; JSON maps parent, insertion vector, and reciprocal lock role." :
    "Use raised marks where present; otherwise match BOM/JSON codes edge-to-edge.",
    16, 37, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.textLine(kicas ?
    "Keep P### marks inward. Zip ties are user-supplied reinforcement." :
    "Keep normals outward. Hardware remains user-supplied.",
    16, 42, GEODESIC_GUIDE_ANNOTATION_MM, false, LEFT);
  canvas.rect(229, 9, 86, 39, 0.2f, false);
  canvas.textLine("ABOUT THIS KIT", 235, 13, 2.7f, true, LEFT);
  canvas.textLine(data.model.faces.size() + (kicas ? " ordered parts" :
    " panels total"), 235, 21, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine(data.catalog.types.size() + (kicas ? " base geometries" :
    " reusable types"), 235, 27, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine(kicas ? guideKicasLockPairs(data) + " lock pairs" :
    "Adjacency-defined", 235, 33, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine(kicas ? "P### marks inward" : "Normals outward",
    235, 39, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.rect(318, 9, 91, 39, 0.2f, false);
  canvas.textLine("WHAT IS INCLUDED", 324, 13, 2.7f, true, LEFT);
  canvas.textLine(kicas ? "Ordered placement STLs" : "Reusable panel STLs",
    324, 21, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine("BOM + assembly JSON", 324, 27, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine(kicas ? "Three illustrated guides" : "Two illustrated guides",
    324, 33, GEODESIC_GUIDE_MICRO_MM, false, LEFT);
  canvas.textLine(kicas ? "No separate connectors" : "No separate hardware",
    324, 39, GEODESIC_GUIDE_MICRO_MM, true, LEFT);
  canvas.logo(425, 8, 151, 40);
  canvas.endGroup();

  float topY = 53;
  float topH = 214;
  guideSection(canvas, 10, topY, 122, topH, kicas ?
    "1. BASE GEOMETRY CLASSES" : "1. PANEL TYPES - REUSABLE GEOMETRIES");
  guideSection(canvas, 135, topY, 449, topH, "2. ASSEMBLY SEQUENCE - GEOMETRIC RELATIONSHIPS ONLY");
  canvas.beginGroup("panel-types");
  float usable = topH - 20;
  int shown = min(10, data.catalog.types.size());
  float rowH = usable / max(1, shown);
  for (int i = 0; i < shown; i++) {
    GeodesicPartType type = data.catalog.types.get(i);
    float rowY = topY + 15 + i * rowH;
    canvas.textLine(guideCatalogTypeLabel(data, type) + "  x" +
      type.quantity, 15, rowY, GEODESIC_GUIDE_BOTTOM_MICRO_MM, true, LEFT);
    guideDrawPanelThumbnail(canvas, data, type, 15, rowY + 4, 43, rowH - 5);
    guideTextBlock(canvas, guideEdgeCodesSummary(data, type), 62, rowY + 6, 64,
      GEODESIC_GUIDE_BOTTOM_MICRO_MM, 4.45f, false, 3);
  }
  if (data.catalog.types.size() > shown) canvas.textLine("+ " + (data.catalog.types.size() - shown) + " TYPES IN BOM", 15, topY + topH - 8, 2.0f, true, LEFT);
  canvas.endGroup();

  canvas.beginGroup("assembly-steps");
  float stageW = 449.0f / 6.0f;
  String[] titles = { "SEED", "EXPAND RING", "PRIMARY REGION", "LOWER BAND", "FILL NETWORK", "VERIFY" };
  for (int i = 0; i < 6; i++) {
    float sx = 135 + i * stageW;
    if (i > 0) canvas.line(sx, topY + 13, sx, topY + topH, 0.22f);
    canvas.rect(sx + 4, topY + 17, 7, 7, 0.2f, true);
    canvas.textLine(str(i + 1), sx + 7.5f, topY + 17.4f, 3.0f, true, CENTER);
    canvas.textLine(titles[i], sx + 14, topY + 17.5f, 3.25f, true, LEFT);
    guideDrawStage(canvas, data, data.stages.get(i), sx + 3, topY + 28, stageW - 6, 134, 38, 24, 3);
    canvas.textLine(data.stages.get(i).targetCount + " / " + data.model.faces.size() + " faces", sx + 5, topY + 166, GEODESIC_GUIDE_ANNOTATION_MM, true, LEFT);
    guideTextBlock(canvas, guideStageCaption(i, data), sx + 5, topY + 175,
      stageW - 10, GEODESIC_GUIDE_BODY_MM, 5.65f, false, 5);
  }
  canvas.endGroup();

  float bottomY = 270;
  float bottomH = 101;
  float[] widths = { 70, 70, 108, 103, 129, 94 };
  String[] headings = { "3. HOW TO READ", "4. ORIENTATION", "5. FACE MAP", "6. ADJACENCY", "7. FULL ASSEMBLY", "8. NOTES" };
  float cursor = 10;
  for (int i = 0; i < widths.length; i++) {
    guideSection(canvas, cursor, bottomY, widths[i], bottomH, headings[i]);
    cursor += widths[i];
  }
  canvas.beginGroup("reading-key");
  guideDrawLegend(canvas, data, 15, bottomY + 18, 60);
  canvas.endGroup();
  canvas.beginGroup("orientation-guide");
  guideDrawOrientation(canvas, data, 84, bottomY + 18, 62, 73);
  canvas.endGroup();
  canvas.beginGroup("face-map");
  guideDrawFaceMap(canvas, data, 154, bottomY + 17, 100, 76);
  canvas.endGroup();
  canvas.beginGroup("adjacency-principle");
  guideDrawAdjacency(canvas, data, 260, bottomY + 18, 93, 73);
  canvas.endGroup();
  canvas.beginGroup("full-isometric-view");
  guideDrawCompleteModel(canvas, data, 366, bottomY + 16, 116, 76, 38, 24, false);
  canvas.endGroup();
  canvas.beginGroup("notes");
  guideTextBlock(canvas, "SLICER SCALE W x D x H: 100% " +
    geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 100) + "; 200% " +
    geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 200) + "; 300% " +
    geodesicSlicerScaleDimensions(data.model,
      data.fabrication.fabricationScale, 300) +
    (kicas ?
    ". Apply one uniform XYZ percentage to all parts. Follow P### order. Seat each integral lock, then zip-tie the aligned center portals. Full insertion and adjacency data: assembly_plan.json." :
    ". Apply one uniform XYZ percentage to all parts. Match interior mate codes and portal schedules. Keep normals outward. Full adjacency and Plateau data: assembly_plan.json."),
    493, bottomY + 18, 84, GEODESIC_GUIDE_BOTTOM_MICRO_MM, 5.55f, false, 13);
  canvas.endGroup();
  drawGeodesicGuideFooter(canvas, data, "GS-002", "DIGITAL ASSEMBLY MAP");
}

void guideSection(GeodesicGuideCanvas canvas, float x, float y, float w, float h, String title) {
  canvas.rect(x, y, w, h, 0.35f, false);
  float titleSize = y >= 269 ? GEODESIC_GUIDE_BOTTOM_TITLE_MM : 2.8f;
  canvas.textLine(title, x + 4, y + 4, titleSize, true, LEFT);
  canvas.line(x, y + 13, x + w, y + 13, 0.2f);
}

void drawGeodesicGuideFooter(GeodesicGuideCanvas canvas, GeodesicGuideData data, String sheet, String drawing) {
  canvas.beginGroup("footer-title-block");
  float y = 376;
  canvas.rect(10, y, 574, 34, 0.4f, false);
  float[] cuts = { 145, 265, 365, 425, 480 };
  for (float cut : cuts) canvas.line(10 + cut, y, 10 + cut, y + 34, 0.28f);
  canvas.textLine("DRAWING", 14, y + 4, 2.75f, true, LEFT);
  canvas.textLine(drawing, 14, y + 12, 2.7f, false, LEFT);
  canvas.textLine("Generated " + data.generatedAt, 14, y + 22, 2.50f, false, LEFT);
  canvas.textLine("DRAWN FOR", 159, y + 4, 2.75f, true, LEFT);
  canvas.textLine("[Brian Fahey]", 159, y + 15, 3.0f, true, LEFT);
  canvas.logo(278, y + 3, 84, 28);
  canvas.textLine("UNIFORM SCALE", 379, y + 4, 2.75f, true, LEFT);
  canvas.textLine("100 / 200 / 300%", 379, y + 15, 2.65f, false, LEFT);
  canvas.textLine("SEE SIZE TABLE", 379, y + 23, 2.40f, true, LEFT);
  canvas.textLine("SHEET", 439, y + 4, 2.75f, true, LEFT);
  canvas.textLine(sheet, 439, y + 16, 3.0f, false, LEFT);
  canvas.textLine("NOTES", 494, y + 4, 2.75f, true, LEFT);
  canvas.textLine(data.model.fingerprint + " / " + data.model.faces.size() + " FACES", 494, y + 12, 2.45f, false, LEFT);
  if (data.fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
    canvas.textLine("FOLLOW P### INSTALL ORDER", 494, y + 19, 2.45f, true, LEFT);
    canvas.textLine("LOCK FIRST / CENTER TIE SECOND", 494, y + 26, 2.45f, false, LEFT);
  } else {
    canvas.textLine("MATCH IDENTICAL EDGE CODES", 494, y + 19, 2.45f, true, LEFT);
    canvas.textLine("PORTALS + BUBBLE DATA IN JSON", 494, y + 26, 2.45f, false, LEFT);
  }
  canvas.endGroup();
}

void guideDrawCompleteModel(GeodesicGuideCanvas canvas, GeodesicGuideData data,
  float x, float y, float w, float h, float azimuth, float elevation, boolean insetPanels) {
  GeodesicGuideProjection projection = new GeodesicGuideProjection(data.model, azimuth, elevation);
  for (GeodesicFace face : data.model.faces) {
    if (!projection.visible(face)) continue;
    PVector[] tri = guideFaceScreen(data.model, face, projection, x, y, w, h, 4, null);
    float light = constrain(face.normal.dot(new PVector(-0.35f, 0.25f, 0.90f).normalize()), -1, 1);
    if (light < -0.15f) guideHatchTriangle(canvas, tri, 2, 0.12f);
    else if (light < 0.38f) guideHatchTriangle(canvas, tri, 1, 0.12f);
    if (insetPanels) canvas.polygon(guideInsetTriangle(tri, 0.12f), 0.15f, false);
  }
  for (GeodesicEdge edge : data.model.edges) {
    boolean va = edge.faceA >= 0 && projection.visible(data.model.faces.get(edge.faceA));
    boolean vb = edge.faceB >= 0 && projection.visible(data.model.faces.get(edge.faceB));
    if (!va && !vb) continue;
    PVector a = projection.screen(data.model.vertices.get(edge.a).position, x, y, w, h, 4);
    PVector b = projection.screen(data.model.vertices.get(edge.b).position, x, y, w, h, 4);
    canvas.line(a.x, a.y, b.x, b.y, va != vb || edge.boundary() ? 0.42f : 0.22f);
  }
}

void guideDrawStage(GeodesicGuideCanvas canvas, GeodesicGuideData data, GeodesicGuideStage stage,
  float x, float y, float w, float h, float azimuth, float elevation, int maxLabels) {
  GeodesicGuideProjection projection = new GeodesicGuideProjection(data.model, azimuth, elevation);
  HashSet<Integer> added = new HashSet<Integer>(stage.newFaceIds);
  float labelBandH = maxLabels > 0 ? min(23.0f, max(16.0f, h * 0.20f)) : 0;
  float modelY = y + labelBandH;
  float modelH = max(18.0f, h - labelBandH);
  float modelCenterX = x + w * 0.5f;
  float modelCenterY = modelY + modelH * 0.5f;
  PVector stageFit = guideStageFit(data, stage, projection, x, modelY, w, modelH, added);
  int labels = 0;
  for (int faceId : stage.faceIds) {
    GeodesicFace face = data.model.faces.get(faceId);
    if (!projection.visible(face)) continue;
    PVector offset = added.contains(faceId) ? PVector.mult(face.normal, min(6.0f, data.model.radius * 0.08f)) : null;
    PVector[] tri = guideFaceScreen(data.model, face, projection, x, modelY, w, modelH, 2, offset);
    guideFitScreenTriangle(tri, stageFit.x, stageFit.y, modelCenterX, modelCenterY, stageFit.z);
    if (added.contains(faceId)) {
      guideHatchTriangle(canvas, tri, 2, 0.11f);
      canvas.polygon(tri, 0.42f, false);
      PVector original = projection.screen(face.centroid, x, modelY, w, modelH, 2);
      PVector moved = offset == null ? original : projection.screen(PVector.add(face.centroid, offset), x, modelY, w, modelH, 2);
      original = guideFitScreenPoint(original, stageFit.x, stageFit.y, modelCenterX, modelCenterY, stageFit.z);
      moved = guideFitScreenPoint(moved, stageFit.x, stageFit.y, modelCenterX, modelCenterY, stageFit.z);
      canvas.dashedLine(original.x, original.y, moved.x, moved.y, 0.16f, 1.0f, 0.8f);
      if (labels < maxLabels) {
        float labelX = x + (labels + 0.5f) * w / max(1, maxLabels);
        float labelY = y + 1.0f;
        float leaderY = labelY + GEODESIC_GUIDE_ANNOTATION_MM + 1.1f;
        canvas.line(moved.x, moved.y, labelX, leaderY, 0.18f);
        canvas.textLine("F" + face.id + " " + data.typeForFace(face.id),
          labelX, labelY, GEODESIC_GUIDE_ANNOTATION_MM, true, CENTER);
        labels++;
      }
    } else canvas.polygon(tri, 0.18f, false);
  }
}

PVector guideStageFit(GeodesicGuideData data, GeodesicGuideStage stage,
  GeodesicGuideProjection projection, float x, float y, float w, float h,
  HashSet<Integer> added) {
  float minX = Float.MAX_VALUE;
  float minY = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE;
  float maxY = -Float.MAX_VALUE;
  for (int faceId : stage.faceIds) {
    GeodesicFace face = data.model.faces.get(faceId);
    if (!projection.visible(face)) continue;
    PVector offset = added.contains(faceId) ? PVector.mult(face.normal, min(6.0f, data.model.radius * 0.08f)) : null;
    PVector[] tri = guideFaceScreen(data.model, face, projection, x, y, w, h, 2, offset);
    for (PVector point : tri) {
      minX = min(minX, point.x);
      minY = min(minY, point.y);
      maxX = max(maxX, point.x);
      maxY = max(maxY, point.y);
    }
  }
  if (minX == Float.MAX_VALUE)
    return new PVector(x + w * 0.5f, y + h * 0.5f, 1.0f);
  float sourceW = max(0.001f, maxX - minX);
  float sourceH = max(0.001f, maxY - minY);
  float maxDiameter = min(w * 0.88f, h * 0.82f);
  float fitScale = min(maxDiameter / sourceW, maxDiameter / sourceH);
  return new PVector((minX + maxX) * 0.5f, (minY + maxY) * 0.5f,
    min(fitScale, 2.15f));
}

PVector guideFitScreenPoint(PVector point, float sourceX, float sourceY,
  float targetX, float targetY, float scale) {
  return new PVector(targetX + (point.x - sourceX) * scale,
    targetY + (point.y - sourceY) * scale, point.z);
}

void guideFitScreenTriangle(PVector[] points, float sourceX, float sourceY,
  float targetX, float targetY, float scale) {
  if (points == null) return;
  for (int i = 0; i < points.length; i++)
    points[i] = guideFitScreenPoint(points[i], sourceX, sourceY, targetX, targetY, scale);
}

PVector[] guideFaceScreen(GeodesicModel model, GeodesicFace face, GeodesicGuideProjection projection,
  float x, float y, float w, float h, float padding, PVector offset) {
  PVector[] result = new PVector[3];
  for (int i = 0; i < 3; i++) {
    PVector point = model.vertices.get(face.vertex(i)).position.copy();
    if (offset != null) point.add(offset);
    result[i] = projection.screen(point, x, y, w, h, padding);
  }
  return result;
}

PVector[] guideInsetTriangle(PVector[] tri, float inset) {
  PVector center = new PVector();
  for (PVector p : tri) center.add(p);
  center.div(3);
  PVector[] result = new PVector[tri.length];
  for (int i = 0; i < tri.length; i++) result[i] = PVector.lerp(tri[i], center, inset);
  return result;
}

void guideHatchTriangle(GeodesicGuideCanvas canvas, PVector[] tri, int mode, float weight) {
  if (mode <= 0) return;
  float maxLength = max(PVector.dist(tri[0], tri[1]), max(PVector.dist(tri[1], tri[2]), PVector.dist(tri[2], tri[0])));
  int count = constrain(round(maxLength / 3.2f), 2, 24);
  for (int i = 1; i < count; i++) {
    float t = i / (float)count;
    PVector a = PVector.lerp(tri[0], tri[1], t);
    PVector b = PVector.lerp(tri[0], tri[2], t);
    canvas.line(a.x, a.y, b.x, b.y, weight);
  }
  if (mode > 1) for (int i = 1; i < count; i++) {
    float t = i / (float)count;
    PVector a = PVector.lerp(tri[1], tri[0], t);
    PVector b = PVector.lerp(tri[1], tri[2], t);
    canvas.line(a.x, a.y, b.x, b.y, weight);
  }
}

void guideDrawPanelThumbnail(GeodesicGuideCanvas canvas, GeodesicGuideData data, GeodesicPartType type,
  float x, float y, float w, float h) {
  if (type.representativeFaceId < 0 || type.representativeFaceId >= data.model.faces.size()) return;
  GeodesicFace face = data.model.faces.get(type.representativeFaceId);
  PVector a3 = data.model.vertices.get(face.a).position;
  PVector b3 = data.model.vertices.get(face.b).position;
  PVector c3 = data.model.vertices.get(face.c).position;
  float ab = PVector.dist(a3, b3);
  float ac = PVector.dist(a3, c3);
  float bc = PVector.dist(b3, c3);
  float cx = (ab * ab + ac * ac - bc * bc) / max(0.0001f, 2 * ab);
  float cy = sqrt(max(0, ac * ac - cx * cx));
  PVector[] raw = { new PVector(0, cy), new PVector(ab, cy), new PVector(cx, 0) };
  float scale = min((w - 3) / max(0.001f, ab), (h - 3) / max(0.001f, cy));
  PVector[] tri = new PVector[3];
  for (int i = 0; i < 3; i++) tri[i] = new PVector(x + w * 0.5f + (raw[i].x - ab * 0.5f) * scale, y + h * 0.5f + (raw[i].y - cy * 0.5f) * scale);
  canvas.polygon(tri, 0.32f, false);
  PVector[] inset = guideInsetTriangle(tri, 0.16f);
  canvas.polygon(inset, 0.16f, false);
  PVector center = PVector.add(PVector.add(inset[0], inset[1]), inset[2]).div(3);
  for (PVector p : inset) canvas.line(center.x, center.y, p.x, p.y, 0.12f);
  for (int edge = 0; edge < tri.length && edge < type.edgeCodes.size(); edge++) {
    PVector midpoint = PVector.add(tri[edge], tri[(edge + 1) % tri.length]).mult(0.5f);
    PVector label = PVector.lerp(midpoint, center, 0.23f);
    canvas.textLine(type.edgeCodes.get(edge), label.x,
      label.y - GEODESIC_GUIDE_MICRO_MM * 0.48f,
      GEODESIC_GUIDE_MICRO_MM, true, CENTER);
  }
}

void guideDrawLegend(GeodesicGuideCanvas canvas, GeodesicGuideData data,
  float x, float y, float w) {
  boolean kicas = guideKicas(data);
  PVector[] tri = { new PVector(x + 2, y + 4), new PVector(x + 10, y + 4), new PVector(x + 6, y - 2) };
  canvas.polygon(tri, 0.22f, false);
  canvas.textLine("PANEL / FACE", x + 14, y - 2, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, false, LEFT);
  canvas.dashedLine(x + 2, y + 14, x + 11, y + 14, 0.18f, 1, 1);
  canvas.textLine("ALIGN EDGES", x + 14, y + 10, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, false, LEFT);
  canvas.line(x + 2, y + 24, x + 11, y + 24, 0.28f);
  canvas.textLine("SHARED EDGE", x + 14, y + 20, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, false, LEFT);
  canvas.textLine("F## = FACE ID", x + 2, y + 31, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, LEFT);
  canvas.textLine(kicas ? "P### = INSTALL ID" : "P### = TYPE ID",
    x + 2, y + 39, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, LEFT);
  canvas.textLine(kicas ? "LOCK ROLE IN JSON" : "A... = MATE CODE",
    x + 2, y + 48, GEODESIC_GUIDE_BOTTOM_MICRO_MM, true, LEFT);
  canvas.textLine("NORMALS POINT OUT", x + 2, y + 57, GEODESIC_GUIDE_BOTTOM_MICRO_MM, false, LEFT);
  canvas.textLine(kicas ? "CENTER TIE PORTALS" : "PORTALS IN STL + JSON",
    x + 2, y + 66, GEODESIC_GUIDE_BOTTOM_MICRO_MM, true, LEFT);
}

void guideDrawOrientation(GeodesicGuideCanvas canvas, GeodesicGuideData data, float x, float y, float w, float h) {
  GeodesicPartType type = data.catalog.types.get(0);
  guideDrawPanelThumbnail(canvas, data, type, x + 5, y + 14, w - 10, 38);
  float cx = x + w * 0.5f;
  canvas.line(cx, y + 12, cx, y + 1, 0.28f);
  canvas.line(cx, y + 1, cx - 1.5f, y + 4, 0.28f);
  canvas.line(cx, y + 1, cx + 1.5f, y + 4, 0.28f);
  canvas.textLine("OUTWARD NORMAL", cx, y + 54, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, CENTER);
  canvas.textLine("Keep this side exterior", cx, y + 62, GEODESIC_GUIDE_BOTTOM_MICRO_MM, false, CENTER);
}

void guideDrawFaceMap(GeodesicGuideCanvas canvas, GeodesicGuideData data, float x, float y, float w, float h) {
  GeodesicGuideProjection projection = new GeodesicGuideProjection(data.model, 0, 89.5f);
  int labelStride = max(1, ceil(data.model.faces.size() / 90.0f));
  for (GeodesicFace face : data.model.faces) {
    if (!projection.visible(face)) continue;
    PVector[] tri = guideFaceScreen(data.model, face, projection, x, y, w, h, 3, null);
    canvas.polygon(tri, 0.15f, false);
    if (face.id % labelStride == 0) {
      PVector center = PVector.add(PVector.add(tri[0], tri[1]), tri[2]).div(3);
      canvas.textLine(str(face.id), center.x, center.y - 1.1f, 2.32f, false, CENTER);
    }
  }
  if (labelStride > 1) canvas.textLine("LABEL STRIDE " + labelStride + " / FULL MAP IN JSON", x + w * 0.5f, y + h - 2, 2.40f, true, CENTER);
}

void guideDrawAdjacency(GeodesicGuideCanvas canvas, GeodesicGuideData data, float x, float y, float w, float h) {
  boolean kicas = guideKicas(data);
  float centerY = y + 26;
  PVector[] left = { new PVector(x + 6, centerY + 17), new PVector(x + 37, centerY + 17), new PVector(x + 22, centerY - 9) };
  PVector[] right = { new PVector(x + 56, centerY + 17), new PVector(x + 87, centerY + 17), new PVector(x + 72, centerY - 9) };
  canvas.polygon(left, 0.3f, false);
  canvas.polygon(right, 0.3f, false);
  canvas.dashedLine(left[1].x, left[1].y, right[0].x, right[0].y, 0.18f, 1.2f, 1.0f);
  canvas.dashedLine(left[2].x, left[2].y, right[2].x, right[2].y, 0.18f, 1.2f, 1.0f);
  String code = guideExampleMateCode(data);
  canvas.textLine(kicas ? "F" : code, left[1].x - 2.5f, centerY + 8,
    GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, CENTER);
  canvas.textLine(kicas ? "M" : code, right[0].x + 2.5f, centerY + 8,
    GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, CENTER);
  canvas.textLine(kicas ? "PARENT / FEMALE" : "PANEL A",
    x + 22, y + 1, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, CENTER);
  canvas.textLine(kicas ? "NEW P### / MALE" : "PANEL B",
    x + 72, y + 1, GEODESIC_GUIDE_BOTTOM_ANNOTATION_MM, true, CENTER);
  canvas.textLine(kicas ? "SLIDE TO CAPTURE" : "DASHED LINES ALIGN",
    x + w * 0.5f, y + 50, GEODESIC_GUIDE_BOTTOM_MICRO_MM, true, CENTER);
  canvas.textLine(kicas ? "CENTER PORTALS ALIGN" : "MATCH " + code + " TO " + code,
    x + w * 0.5f, y + 58, GEODESIC_GUIDE_BOTTOM_MICRO_MM, false, CENTER);
  canvas.textLine(kicas ? "LOCK FIRST / TIE SECOND" : "NO SEPARATE CONNECTOR",
    x + w * 0.5f, y + 66, GEODESIC_GUIDE_BOTTOM_MICRO_MM, true, CENTER);
}

void guideTextBlock(GeodesicGuideCanvas canvas, String text, float x, float y, float w,
  float size, float lineHeight, boolean bold, int maxLines) {
  String[] lines = guideWrapText(text, max(8, floor(w / max(0.1f, size * 0.53f))));
  int count = min(maxLines, lines.length);
  for (int i = 0; i < count; i++) {
    String value = lines[i];
    if (i == count - 1 && lines.length > count) value = guideEllipsis(value);
    canvas.textLine(value, x, y + i * lineHeight, size, bold, LEFT);
  }
}

String[] guideWrapText(String text, int maxChars) {
  ArrayList<String> lines = new ArrayList<String>();
  String[] paragraphs = text.split("\\n");
  for (String paragraph : paragraphs) {
    String current = "";
    for (String word : paragraph.trim().split("\\s+")) {
      String candidate = current.length() == 0 ? word : current + " " + word;
      if (candidate.length() > maxChars && current.length() > 0) {
        lines.add(current);
        current = word;
      } else current = candidate;
    }
    if (current.length() > 0) lines.add(current);
  }
  return lines.toArray(new String[lines.size()]);
}

String guideEllipsis(String value) {
  if (value.length() <= 3) return value;
  return value.substring(0, value.length() - 3) + "...";
}

String guideStageCaption(int index, GeodesicGuideData data) {
  if (guideKicas(data)) {
    if (index == 0) return "Place the P001 seed with its marked face inward.";
    if (index == 1) return "Find each parent; slide its child lock fully home.";
    if (index == 2) return "Follow P### order and the recorded insertion vectors.";
    if (index == 3) return "Continue ordered placements around the shell.";
    if (index == 4) return "Seat remaining locks and alignment-only edges.";
    return "Install the key; verify locks, center portals, and ties.";
  }
  if (index == 0) return "Orient seed faces; mate codes match and normals point out.";
  if (index == 1) return "Add neighbors; identical logical mate codes meet edge-to-edge.";
  if (index == 2) return "Extend by mate code and neighbor ID.";
  if (index == 3) return "Continue across the shell; reuse repeated part types.";
  if (index == 4) return "Fill the network; preserve code and orientation.";
  return "Verify all " + data.model.faces.size() + " placements and code pairs.";
}

String guideCatalogTypeLabel(GeodesicGuideData data, GeodesicPartType type) {
  if (type == null) return "TYPE ?";
  return guideKicas(data) ? "TYPE " + type.typeId : type.typeId;
}

String guideEdgeCodesSummary(GeodesicGuideData data, GeodesicPartType type) {
  if (guideKicas(data))
    return "BASE GEOMETRY / P### FILES ARE UNIQUE";
  if (type == null || type.edgeCodes.size() == 0) return "MATE CODES UNAVAILABLE";
  String result = "EDGES ";
  for (int i = 0; i < type.edgeCodes.size(); i++)
    result += (i == 0 ? "" : " - ") + type.edgeCodes.get(i);
  return result;
}

String guidePhysicalMateCodeSummary(GeodesicGuideData data) {
  if (data == null || data.fabrication == null ||
      !data.fabrication.edgeCodesEnabled) return "OFF";
  int fallback = data.catalog == null ? 0 :
    data.catalog.physicalEdgeCodeFallbackCount();
  return fallback == 0 ? "RAISED / INTERIOR" :
    "RAISED WHERE VALID / " + fallback + " BOM FALLBACK";
}

String guideExampleMateCode(GeodesicGuideData data) {
  if (data != null && data.catalog != null) for (GeodesicPartType type : data.catalog.types)
    for (String code : type.edgeCodes)
      if (code != null && code.length() > 0 && !code.equals("RIM")) return code;
  return "A";
}

String guideSignatureShort(String signature) {
  if (signature == null) return "geometry signature unavailable";
  String value = signature.replace("SHELL_OVERWRAP", "OVERWRAP").replace("CENTER_TO_EDGE", "CENTER > EDGE");
  return value.length() > 42 ? value.substring(0, 39) + "..." : value;
}

String guideResolvedDimensionRange(GeodesicGuideData data) {
  float minDepth = Float.MAX_VALUE;
  float maxDepth = 0;
  float minWidth = Float.MAX_VALUE;
  float maxWidth = 0;
  for (GeodesicPartType type : data.catalog.types) if (type.fabrication != null) {
    minDepth = min(minDepth, type.fabrication.frameDepthMM);
    maxDepth = max(maxDepth, type.fabrication.frameDepthMM);
    minWidth = min(minWidth, type.fabrication.frameWidthMM);
    maxWidth = max(maxWidth, type.fabrication.frameWidthMM);
  }
  if (minDepth == Float.MAX_VALUE || minWidth == Float.MAX_VALUE)
    return "EFFECTIVE DIMENSIONS UNAVAILABLE";
  return "EFFECTIVE D " + nf(minDepth, 1, 1) + "-" + nf(maxDepth, 1, 1) +
    " / W " + nf(minWidth, 1, 1) + "-" + nf(maxWidth, 1, 1) + " mm";
}
