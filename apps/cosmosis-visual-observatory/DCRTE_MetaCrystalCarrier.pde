/*
 * Isolated Meta-Crystal carrier inspired by arXiv:2410.07833.
 *
 * The paper-derived layer supplies explicit BCC/BCCT strut graphs and the
 * reported grain recipes. Mechanical readouts in this file are geometric
 * proxies only; they are not substitutes for simulation or physical tests.
 */

final int DCRTE_META_CRYSTAL_GEOMETRY_INDEX = 19;
final int DCRTE_META_CRYSTAL_GRID = 20;
final String DCRTE_META_CRYSTAL_SOURCE = "arXiv:2410.07833";

String[] dcrteMetaCrystalFamilies = {
  "BCC CONTROL", "BCCT", "META-GRAIN", "META-HARMONIC"
};
String[][] dcrteMetaCrystalPresets = {
  {"G8"},
  {"G8"},
  {"G44", "G2222", "G1x8"},
  {"G242", "G11411", "G112211"}
};

int dcrteMetaCrystalFamily = 0;
int dcrteMetaCrystalPreset = 0;
float dcrteMetaCrystalThetaDeg = 0.0f;
float dcrteMetaCrystalStrutRadius = 0.026f;
int dcrteMetaCrystalLoadAxis = 1;
int dcrteMetaCrystalView = 0;
boolean dcrteMetaCrystalRdftCoupled = false;
String dcrteMetaCrystalStatus = "select META-CRYSTAL to inspect";
DCRTEMetaCrystalGraph dcrteMetaCrystalGraph = null;
String dcrteMetaCrystalSignature = "";

class DCRTEMetaCrystalEdge {
  int a;
  int b;
  int grain;
  boolean grainBoundary;
  float axialProxy;

  DCRTEMetaCrystalEdge(int aValue, int bValue, int grainValue) {
    a = aValue;
    b = bValue;
    grain = grainValue;
  }
}

class DCRTEMetaCrystalGraph {
  ArrayList<PVector> nodes = new ArrayList<PVector>();
  ArrayList<DCRTEMetaCrystalEdge> edges = new ArrayList<DCRTEMetaCrystalEdge>();
  HashMap<String, Integer> nodeLookup = new HashMap<String, Integer>();
  HashSet<String> edgeLookup = new HashSet<String>();
  IntList[] cells = new IntList[DCRTE_META_CRYSTAL_GRID * DCRTE_META_CRYSTAL_GRID * DCRTE_META_CRYSTAL_GRID];
  int[] grainWidths;
  int boundaryCount;
  float axialMean;
  float equivalentGrainSize;

  DCRTEMetaCrystalGraph() {
    for (int i = 0; i < cells.length; i++) cells[i] = new IntList();
  }
}

boolean dcrteMetaCrystalModeActive() {
  return foundryGeometryIndex == DCRTE_META_CRYSTAL_GEOMETRY_INDEX;
}

String dcrteMetaCrystalFamilyLabel() {
  return dcrteMetaCrystalFamilies[constrain(dcrteMetaCrystalFamily, 0, dcrteMetaCrystalFamilies.length - 1)];
}

String dcrteMetaCrystalPresetLabel() {
  String[] presets = dcrteMetaCrystalPresets[constrain(dcrteMetaCrystalFamily, 0, dcrteMetaCrystalPresets.length - 1)];
  dcrteMetaCrystalPreset = constrain(dcrteMetaCrystalPreset, 0, presets.length - 1);
  return presets[dcrteMetaCrystalPreset];
}

String dcrteMetaCrystalViewLabel() {
  String[] labels = {"GEOMETRY", "GRAINS", "LOAD PATH", "RISK"};
  return labels[constrain(dcrteMetaCrystalView, 0, labels.length - 1)];
}

String dcrteMetaCrystalLoadAxisLabel() {
  return dcrteMetaCrystalLoadAxis == 0 ? "X" : dcrteMetaCrystalLoadAxis == 1 ? "Y" : "Z";
}

float dcrteMetaCrystalEffectiveThetaDeg() {
  return dcrteMetaCrystalFamily == 0 ? 0 : dcrteMetaCrystalThetaDeg;
}

void cycleDcrteMetaCrystalFamily(int delta) {
  dcrteMetaCrystalFamily = (dcrteMetaCrystalFamily + delta + dcrteMetaCrystalFamilies.length) % dcrteMetaCrystalFamilies.length;
  dcrteMetaCrystalPreset = 0;
  if (dcrteMetaCrystalFamily == 0) dcrteMetaCrystalThetaDeg = 0;
  else if (dcrteMetaCrystalThetaDeg < 0.5f) dcrteMetaCrystalThetaDeg = 27;
  invalidateDcrteMetaCrystal("family changed");
}

void cycleDcrteMetaCrystalPreset(int delta) {
  String[] presets = dcrteMetaCrystalPresets[dcrteMetaCrystalFamily];
  dcrteMetaCrystalPreset = (dcrteMetaCrystalPreset + delta + presets.length) % presets.length;
  invalidateDcrteMetaCrystal("grain recipe changed");
}

void adjustDcrteMetaCrystalTheta(float delta) {
  if (dcrteMetaCrystalFamily == 0) return;
  dcrteMetaCrystalThetaDeg = constrain(dcrteMetaCrystalThetaDeg + delta, 0, 45);
  invalidateDcrteMetaCrystal("twinning angle changed");
}

void cycleDcrteMetaCrystalView() {
  dcrteMetaCrystalView = (dcrteMetaCrystalView + 1) % 4;
}

void cycleDcrteMetaCrystalLoadAxis() {
  dcrteMetaCrystalLoadAxis = (dcrteMetaCrystalLoadAxis + 1) % 3;
  invalidateDcrteMetaCrystal("load axis changed");
}

void toggleDcrteMetaCrystalCoupling() {
  dcrteMetaCrystalRdftCoupled = !dcrteMetaCrystalRdftCoupled;
  markCurrentFoundryStale("meta-crystal coupling changed; regenerate");
}

void invalidateDcrteMetaCrystal(String reason) {
  dcrteMetaCrystalGraph = null;
  dcrteMetaCrystalSignature = "";
  ensureDcrteMetaCrystalGraph();
  markCurrentFoundryStale(reason + "; regenerate");
}

int[] dcrteMetaCrystalWidths(String preset) {
  if (preset.equals("G44")) return new int[]{4, 4};
  if (preset.equals("G2222")) return new int[]{2, 2, 2, 2};
  if (preset.equals("G1x8")) return new int[]{1, 1, 1, 1, 1, 1, 1, 1};
  if (preset.equals("G242")) return new int[]{2, 4, 2};
  if (preset.equals("G11411")) return new int[]{1, 1, 4, 1, 1};
  if (preset.equals("G112211")) return new int[]{1, 1, 2, 2, 1, 1};
  return new int[]{8};
}

boolean ensureDcrteMetaCrystalGraph() {
  String signature = dcrteMetaCrystalFamily + "|" + dcrteMetaCrystalPresetLabel() + "|" + nf(dcrteMetaCrystalEffectiveThetaDeg(), 1, 3) + "|" + dcrteMetaCrystalLoadAxis;
  if (dcrteMetaCrystalGraph != null && signature.equals(dcrteMetaCrystalSignature)) return true;
  try {
    DCRTEMetaCrystalGraph graph = buildDcrteMetaCrystalGraph();
    dcrteMetaCrystalGraph = graph;
    dcrteMetaCrystalSignature = signature;
    dcrteMetaCrystalStatus = graph.nodes.size() + " nodes / " + graph.edges.size() + " struts / " + graph.grainWidths.length + " grains";
    return true;
  } catch (Exception error) {
    dcrteMetaCrystalGraph = null;
    dcrteMetaCrystalStatus = "graph failed: " + (error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage());
    println("DCRTE Meta-Crystal: " + dcrteMetaCrystalStatus);
    return false;
  }
}

DCRTEMetaCrystalGraph buildDcrteMetaCrystalGraph() {
  DCRTEMetaCrystalGraph graph = new DCRTEMetaCrystalGraph();
  graph.grainWidths = dcrteMetaCrystalWidths(dcrteMetaCrystalPresetLabel());
  float theta = radians(dcrteMetaCrystalEffectiveThetaDeg());
  float shear = tan(theta);
  int ny = 8;
  int nz = 8;
  int startX = 0;
  for (int grain = 0; grain < graph.grainWidths.length; grain++) {
    int width = graph.grainWidths[grain];
    float midX = startX + width * 0.5f;
    float sign = (grain & 1) == 0 ? 1.0f : -1.0f;
    for (int ix = startX; ix < startX + width; ix++) {
      for (int iy = 0; iy < ny; iy++) {
        for (int iz = 0; iz < nz; iz++) {
          PVector center = dcrteMetaCrystalTransform(ix + 0.5f, iy + 0.5f, iz + 0.5f, midX, sign, shear);
          int centerIndex = dcrteMetaCrystalNode(graph, center);
          for (int dx = 0; dx <= 1; dx++) {
            for (int dy = 0; dy <= 1; dy++) {
              for (int dz = 0; dz <= 1; dz++) {
                PVector corner = dcrteMetaCrystalTransform(ix + dx, iy + dy, iz + dz, midX, sign, shear);
                int cornerIndex = dcrteMetaCrystalNode(graph, corner);
                dcrteMetaCrystalEdge(graph, centerIndex, cornerIndex, grain);
              }
            }
          }
        }
      }
    }
    startX += width;
  }
  normalizeDcrteMetaCrystalGraph(graph);
  classifyDcrteMetaCrystalGraph(graph);
  indexDcrteMetaCrystalGraph(graph);
  return graph;
}

PVector dcrteMetaCrystalTransform(float x, float y, float z, float grainMidX, float reflection, float shear) {
  // BCCT equation from the paper, reflected on alternating grain bands.
  float localX = x - grainMidX;
  float localZ = z - 4.0f;
  return new PVector(x, y + reflection * shear * (localX + localZ), z);
}

String dcrteMetaCrystalPointKey(PVector p) {
  return round(p.x * 10000) + ":" + round(p.y * 10000) + ":" + round(p.z * 10000);
}

int dcrteMetaCrystalNode(DCRTEMetaCrystalGraph graph, PVector point) {
  String key = dcrteMetaCrystalPointKey(point);
  Integer existing = graph.nodeLookup.get(key);
  if (existing != null) return existing.intValue();
  int index = graph.nodes.size();
  graph.nodes.add(point.copy());
  graph.nodeLookup.put(key, index);
  return index;
}

void dcrteMetaCrystalEdge(DCRTEMetaCrystalGraph graph, int a, int b, int grain) {
  int lo = min(a, b);
  int hi = max(a, b);
  String key = lo + ":" + hi;
  if (graph.edgeLookup.contains(key)) return;
  graph.edgeLookup.add(key);
  graph.edges.add(new DCRTEMetaCrystalEdge(lo, hi, grain));
}

void normalizeDcrteMetaCrystalGraph(DCRTEMetaCrystalGraph graph) {
  PVector low = new PVector(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY);
  PVector high = new PVector(Float.NEGATIVE_INFINITY, Float.NEGATIVE_INFINITY, Float.NEGATIVE_INFINITY);
  for (PVector p : graph.nodes) {
    low.x = min(low.x, p.x); low.y = min(low.y, p.y); low.z = min(low.z, p.z);
    high.x = max(high.x, p.x); high.y = max(high.y, p.y); high.z = max(high.z, p.z);
  }
  PVector center = PVector.add(low, high).mult(0.5f);
  float extent = max(high.x - low.x, max(high.y - low.y, high.z - low.z));
  float scale = 1.76f / max(0.0001f, extent);
  for (PVector p : graph.nodes) p.sub(center).mult(scale);
}

void classifyDcrteMetaCrystalGraph(DCRTEMetaCrystalGraph graph) {
  float axialSum = 0;
  float grainSizeSum = 0;
  for (int width : graph.grainWidths) {
    grainSizeSum += pow(max(0.0001f, 6.0f * width * width * 8.0f / PI), 1.0f / 3.0f);
  }
  graph.equivalentGrainSize = grainSizeSum / max(1, graph.grainWidths.length);
  for (DCRTEMetaCrystalEdge edge : graph.edges) {
    PVector a = graph.nodes.get(edge.a);
    PVector b = graph.nodes.get(edge.b);
    PVector direction = PVector.sub(b, a).normalize();
    float component = dcrteMetaCrystalLoadAxis == 0 ? direction.x : dcrteMetaCrystalLoadAxis == 1 ? direction.y : direction.z;
    edge.axialProxy = component * component;
    axialSum += edge.axialProxy;
    float midpointX = (a.x + b.x) * 0.5f;
    edge.grainBoundary = dcrteMetaCrystalNearBoundary(graph, midpointX);
    if (edge.grainBoundary) graph.boundaryCount++;
  }
  graph.axialMean = axialSum / max(1, graph.edges.size());
}

boolean dcrteMetaCrystalNearBoundary(DCRTEMetaCrystalGraph graph, float normalizedX) {
  if (graph.grainWidths.length <= 1) return false;
  int sum = 0;
  for (int i = 0; i < graph.grainWidths.length - 1; i++) {
    sum += graph.grainWidths[i];
    float boundary = map(sum, 0, 8, -0.88f, 0.88f);
    if (abs(normalizedX - boundary) < 0.055f) return true;
  }
  return false;
}

void indexDcrteMetaCrystalGraph(DCRTEMetaCrystalGraph graph) {
  float margin = 0.075f;
  for (int edgeIndex = 0; edgeIndex < graph.edges.size(); edgeIndex++) {
    DCRTEMetaCrystalEdge edge = graph.edges.get(edgeIndex);
    PVector a = graph.nodes.get(edge.a);
    PVector b = graph.nodes.get(edge.b);
    int x0 = dcrteMetaCrystalGrid(min(a.x, b.x) - margin);
    int x1 = dcrteMetaCrystalGrid(max(a.x, b.x) + margin);
    int y0 = dcrteMetaCrystalGrid(min(a.y, b.y) - margin);
    int y1 = dcrteMetaCrystalGrid(max(a.y, b.y) + margin);
    int z0 = dcrteMetaCrystalGrid(min(a.z, b.z) - margin);
    int z1 = dcrteMetaCrystalGrid(max(a.z, b.z) + margin);
    for (int gz = z0; gz <= z1; gz++)
      for (int gy = y0; gy <= y1; gy++)
        for (int gx = x0; gx <= x1; gx++)
          graph.cells[dcrteMetaCrystalCell(gx, gy, gz)].append(edgeIndex);
  }
}

int dcrteMetaCrystalGrid(float value) {
  return constrain(floor(map(value, -1, 1, 0, DCRTE_META_CRYSTAL_GRID)), 0, DCRTE_META_CRYSTAL_GRID - 1);
}

int dcrteMetaCrystalCell(int x, int y, int z) {
  return x + y * DCRTE_META_CRYSTAL_GRID + z * DCRTE_META_CRYSTAL_GRID * DCRTE_META_CRYSTAL_GRID;
}

float dcrteMetaCrystalDistance(float x, float y, float z) {
  if (!ensureDcrteMetaCrystalGraph()) return 2.0f;
  int gx = dcrteMetaCrystalGrid(x);
  int gy = dcrteMetaCrystalGrid(y);
  int gz = dcrteMetaCrystalGrid(z);
  IntList candidates = dcrteMetaCrystalGraph.cells[dcrteMetaCrystalCell(gx, gy, gz)];
  float best = Float.POSITIVE_INFINITY;
  PVector point = new PVector(x, y, z);
  for (int i = 0; i < candidates.size(); i++) {
    DCRTEMetaCrystalEdge edge = dcrteMetaCrystalGraph.edges.get(candidates.get(i));
    best = min(best, dcrteMetaCrystalSegmentDistance(point, dcrteMetaCrystalGraph.nodes.get(edge.a), dcrteMetaCrystalGraph.nodes.get(edge.b)));
  }
  return best;
}

float dcrteMetaCrystalSegmentDistance(PVector point, PVector a, PVector b) {
  PVector ab = PVector.sub(b, a);
  float denom = max(0.0000001f, ab.magSq());
  float t = constrain(PVector.sub(point, a).dot(ab) / denom, 0, 1);
  return PVector.dist(point, PVector.add(a, PVector.mult(ab, t)));
}

float dcrteMetaCrystalRadiusAt(float x, float y, float z) {
  if (!dcrteMetaCrystalRdftCoupled) return dcrteMetaCrystalStrutRadius;
  float modulation = 0.92f + 0.16f * constrain(topologyScalar(x, y, z, currentTopologyScores()) * 0.5f + 0.5f, 0, 1);
  return dcrteMetaCrystalStrutRadius * modulation;
}

boolean dcrteMetaCrystalOccupied(float x, float y, float z) {
  if (max(abs(x), max(abs(y), abs(z))) > 0.96f) return false;
  return dcrteMetaCrystalDistance(x, y, z) <= dcrteMetaCrystalRadiusAt(x, y, z);
}

float evaluateDcrteMetaCrystalCarrier(float x, float y, float z) {
  float signed = dcrteMetaCrystalDistance(x, y, z) - dcrteMetaCrystalRadiusAt(x, y, z);
  if (!dcrteMetaCrystalRdftCoupled) return signed;
  return signed + topologyScalar(x, y, z, currentTopologyScores()) * 0.025f;
}

float dcrteMetaCrystalPaperAxialFraction() {
  float[] angles = {0, 21, 27, 32, 37, 45};
  float[] fractions = {0.026f, 0.411f, 0.688f, 0.79f, 0.89f, 0.954f};
  float theta = dcrteMetaCrystalEffectiveThetaDeg();
  if (theta <= angles[0]) return fractions[0];
  for (int i = 1; i < angles.length; i++) {
    if (theta <= angles[i]) return lerp(fractions[i - 1], fractions[i], map(theta, angles[i - 1], angles[i], 0, 1));
  }
  return fractions[fractions.length - 1];
}

void drawDcrteMetaCrystalGraphPreview(float scale) {
  if (!ensureDcrteMetaCrystalGraph()) return;
  strokeWeight(1.15f);
  for (DCRTEMetaCrystalEdge edge : dcrteMetaCrystalGraph.edges) {
    if (dcrteMetaCrystalView == 1) {
      color[] palette = {color(32, 205, 190), color(232, 89, 142), color(255, 190, 62), color(110, 215, 96), color(145, 104, 224), color(70, 154, 225), color(238, 103, 75), color(200, 215, 225)};
      stroke(palette[edge.grain % palette.length], 205);
    } else if (dcrteMetaCrystalView == 2) {
      stroke(lerpColor(color(42, 72, 92), color(255, 205, 76), edge.axialProxy), 210);
    } else if (dcrteMetaCrystalView == 3) {
      stroke(edge.grainBoundary ? color(255, 78, 110, 235) : lerpColor(color(48, 210, 185), color(255, 166, 64), 1.0f - edge.axialProxy), 185);
    } else {
      stroke(65, 220, 205, 160);
    }
    PVector a = dcrteMetaCrystalGraph.nodes.get(edge.a);
    PVector b = dcrteMetaCrystalGraph.nodes.get(edge.b);
    line(a.x * scale, a.y * scale, a.z * scale, b.x * scale, b.y * scale, b.z * scale);
  }
}

void drawDcrteMetaCrystalOverlay(int x, int y, int w, int h) {
  if (!dcrteMetaCrystalModeActive() || !ensureDcrteMetaCrystalGraph()) return;
  int boxW = min(286, max(248, w / 3));
  int boxH = 118;
  int bx = x + 12;
  int by = y + 12;
  fill(3, 9, 13, 234);
  stroke(42, 118, 118);
  rect(bx, by, boxW, boxH, 5);
  fill(112, 235, 215);
  textSize(9);
  textAlign(LEFT, TOP);
  text("META-CRYSTAL / " + dcrteMetaCrystalFamilyLabel(), bx + 10, by + 9);
  fill(145, 176, 183);
  textSize(8);
  text("recipe     " + dcrteMetaCrystalPresetLabel() + "   theta " + nf(dcrteMetaCrystalEffectiveThetaDeg(), 1, 1) + " deg", bx + 10, by + 27);
  text("graph      " + dcrteMetaCrystalGraph.nodes.size() + " nodes / " + dcrteMetaCrystalGraph.edges.size() + " struts", bx + 10, by + 41);
  text("view       " + dcrteMetaCrystalViewLabel() + " / load " + dcrteMetaCrystalLoadAxisLabel(), bx + 10, by + 55);
  text("geom axial " + nf(dcrteMetaCrystalGraph.axialMean, 1, 3) + "   paper eta " + nf(dcrteMetaCrystalPaperAxialFraction(), 1, 3), bx + 10, by + 69);
  text("coupling   " + (dcrteMetaCrystalRdftCoupled ? "RDFT EXPERIMENTAL" : "PAPER REPLICA"), bx + 10, by + 83);
  fill(255, 190, 72);
  text("PROXY ONLY / " + (foundryActiveVolumeResolution() < 72 ? "72^3+ RES RECOMMENDED" : "validate before structural use"), bx + 10, by + 99);
}

void appendDcrteMetaCrystalMetadata(JSONObject root) {
  if (!dcrteMetaCrystalModeActive() || !ensureDcrteMetaCrystalGraph()) return;
  JSONObject meta = new JSONObject();
  meta.setString("schema", "dcrte.meta_crystal.v1");
  meta.setString("source", DCRTE_META_CRYSTAL_SOURCE);
  meta.setString("family", dcrteMetaCrystalFamilyLabel());
  meta.setString("grain_recipe", dcrteMetaCrystalPresetLabel());
  meta.setFloat("twinning_angle_deg", dcrteMetaCrystalEffectiveThetaDeg());
  meta.setString("load_axis", dcrteMetaCrystalLoadAxisLabel());
  meta.setString("coupling", dcrteMetaCrystalRdftCoupled ? "RDFT_EXPLORATORY" : "PAPER_REPLICA");
  meta.setFloat("normalized_strut_radius", dcrteMetaCrystalStrutRadius);
  meta.setInt("node_count", dcrteMetaCrystalGraph.nodes.size());
  meta.setInt("edge_count", dcrteMetaCrystalGraph.edges.size());
  meta.setInt("grain_count", dcrteMetaCrystalGraph.grainWidths.length);
  meta.setFloat("geometric_axial_proxy", dcrteMetaCrystalGraph.axialMean);
  meta.setFloat("paper_axial_energy_fraction_reference", dcrteMetaCrystalPaperAxialFraction());
  meta.setFloat("equivalent_grain_size_proxy", dcrteMetaCrystalGraph.equivalentGrainSize);
  meta.setBoolean("mechanical_result_validated", false);
  meta.setString("validation_note", "Geometry/proxy output only; simulate and physically test before structural use.");
  root.setJSONObject("meta_crystal", meta);
}

void exportDcrteMetaCrystalGraph() {
  if (!ensureDcrteMetaCrystalGraph()) return;
  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  String slug = dcrteMetaCrystalFamilyLabel().toLowerCase().replace(" ", "_") + "_" + dcrteMetaCrystalPresetLabel().toLowerCase();
  String base = "exports/meta_crystal/" + stamp + "_" + slug;
  File directory = new File(sketchPath(base));
  directory.mkdirs();
  PrintWriter nodes = createWriter(base + "/nodes.csv");
  nodes.println("node_id,x,y,z");
  for (int i = 0; i < dcrteMetaCrystalGraph.nodes.size(); i++) {
    PVector p = dcrteMetaCrystalGraph.nodes.get(i);
    nodes.println(i + "," + p.x + "," + p.y + "," + p.z);
  }
  nodes.flush(); nodes.close();
  PrintWriter edges = createWriter(base + "/edges.csv");
  edges.println("edge_id,node_a,node_b,grain_id,boundary,axial_proxy");
  for (int i = 0; i < dcrteMetaCrystalGraph.edges.size(); i++) {
    DCRTEMetaCrystalEdge edge = dcrteMetaCrystalGraph.edges.get(i);
    edges.println(i + "," + edge.a + "," + edge.b + "," + edge.grain + "," + edge.grainBoundary + "," + edge.axialProxy);
  }
  edges.flush(); edges.close();
  JSONObject manifest = new JSONObject();
  manifest.setString("program", "Cosmosis Visual Observatory Meta-Crystal Carrier");
  manifest.setString("generated_at", stamp);
  appendDcrteMetaCrystalMetadata(manifest);
  manifest.setString("nodes_csv", "nodes.csv");
  manifest.setString("edges_csv", "edges.csv");
  saveJSONObject(manifest, base + "/manifest.json");
  dcrteMetaCrystalStatus = "graph exported: " + base;
}

void runDcrteMetaCrystalTests() {
  int familyBefore = dcrteMetaCrystalFamily;
  int presetBefore = dcrteMetaCrystalPreset;
  float thetaBefore = dcrteMetaCrystalThetaDeg;
  int axisBefore = dcrteMetaCrystalLoadAxis;
  boolean coupledBefore = dcrteMetaCrystalRdftCoupled;
  int passed = 0;
  int total = 8;
  try {
    int[][] recipes = {
      dcrteMetaCrystalWidths("G44"), dcrteMetaCrystalWidths("G2222"), dcrteMetaCrystalWidths("G1x8"),
      dcrteMetaCrystalWidths("G242"), dcrteMetaCrystalWidths("G11411"), dcrteMetaCrystalWidths("G112211")
    };
    boolean sums = true;
    for (int[] recipe : recipes) {
      int sum = 0; for (int value : recipe) sum += value;
      sums &= sum == 8;
    }
    if (sums) passed++;

    dcrteMetaCrystalFamily = 0; dcrteMetaCrystalPreset = 0; dcrteMetaCrystalThetaDeg = 0; dcrteMetaCrystalGraph = null;
    DCRTEMetaCrystalGraph bcc = buildDcrteMetaCrystalGraph();
    if (bcc.nodes.size() > 0 && bcc.edges.size() > 0) passed++;
    int bccEdges = bcc.edges.size();

    dcrteMetaCrystalFamily = 1; dcrteMetaCrystalThetaDeg = 27; dcrteMetaCrystalGraph = null;
    DCRTEMetaCrystalGraph bcct = buildDcrteMetaCrystalGraph();
    if (bcct.edges.size() == bccEdges) passed++;
    boolean finite = true;
    for (PVector p : bcct.nodes) finite &= Float.isFinite(p.x) && Float.isFinite(p.y) && Float.isFinite(p.z);
    if (finite) passed++;

    dcrteMetaCrystalGraph = bcct;
    dcrteMetaCrystalSignature = dcrteMetaCrystalFamily + "|" + dcrteMetaCrystalPresetLabel() + "|" + nf(dcrteMetaCrystalThetaDeg, 1, 3) + "|" + dcrteMetaCrystalLoadAxis;
    float distance = dcrteMetaCrystalDistance(0, 0, 0);
    if (Float.isFinite(distance) && distance >= 0) passed++;
    if (dcrteMetaCrystalPaperAxialFraction() > 0.60f) passed++;

    dcrteMetaCrystalFamily = 3; dcrteMetaCrystalPreset = 1; dcrteMetaCrystalThetaDeg = 27; dcrteMetaCrystalGraph = null;
    DCRTEMetaCrystalGraph harmonic = buildDcrteMetaCrystalGraph();
    if (harmonic.grainWidths.length == 5 && harmonic.boundaryCount > 0) passed++;
    String firstSignature = harmonic.nodes.size() + ":" + harmonic.edges.size() + ":" + nf(harmonic.axialMean, 1, 6);
    DCRTEMetaCrystalGraph harmonicAgain = buildDcrteMetaCrystalGraph();
    String secondSignature = harmonicAgain.nodes.size() + ":" + harmonicAgain.edges.size() + ":" + nf(harmonicAgain.axialMean, 1, 6);
    if (firstSignature.equals(secondSignature)) passed++;
  } finally {
    dcrteMetaCrystalFamily = familyBefore;
    dcrteMetaCrystalPreset = presetBefore;
    dcrteMetaCrystalThetaDeg = thetaBefore;
    dcrteMetaCrystalLoadAxis = axisBefore;
    dcrteMetaCrystalRdftCoupled = coupledBefore;
    dcrteMetaCrystalGraph = null;
    dcrteMetaCrystalSignature = "";
  }
  println("META-CRYSTAL CARRIER TESTS " + (passed == total ? "PASS" : "FAIL") + " " + passed + "/" + total);
  if (passed != total) throw new RuntimeException("Meta-Crystal tests failed " + passed + "/" + total);
}
