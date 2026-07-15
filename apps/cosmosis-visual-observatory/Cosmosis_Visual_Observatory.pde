import java.io.File;
import java.util.HashSet;

/*
  Cosmosis Visual Observatory
  Visual-only RDFT theory workspace.

  This is a fresh project inspired by Cosmosis Navigator's theory vocabulary,
  not a migration of its audio, Launchpad, BasinNET, or SuperCollider systems.
*/

final int GRID = 96;
final int UI_W = 282;
final int TOP_H = 58;
final int M = 18;
final int TRAIL_MAX = 520;
final int PARTICLE_COUNT = 900;
final int HOLO_MAX = 380;
final int TRACE_MAX = 240;
final int DEPTH_MAX = 12;
final int MATERIAL_PANEL_H = 148;
final float ALPHA_MAX = 6.0;
final String FIELDWORKS_LOGO_FILE = "fieldworks_mindlab_logo.png";

String[] lensNames = {
  "FIELD ATLAS",
  "HOLONOMY LOOM",
  "PHI THRESHOLD",
  "FLOQUET FORGE",
  "CTC OBSERVATORY",
  "WIGNER STUDIO",
  "BRANES / FIBERS",
  "TOPOLOGY LAB",
  "SURFACE FOUNDRY"
};

ArrayList<SliderKnob> sliders = new ArrayList<SliderKnob>();
ArrayList<Particle> particles = new ArrayList<Particle>();
ArrayList<PVector> orbitTrail = new ArrayList<PVector>();
ArrayList<PVector> holoTrail = new ArrayList<PVector>();
ArrayList<Float> holoGammaTrail = new ArrayList<Float>();
ArrayList<MaterialProfile> materials = new ArrayList<MaterialProfile>();
ArrayList<MaterialProfile> heuristicMaterials = new ArrayList<MaterialProfile>();
ArrayList<MaterialProfile> databaseMaterials = new ArrayList<MaterialProfile>();
ArrayList<MaterialProfile> cosmosisMaterials = new ArrayList<MaterialProfile>();
SurfaceMesh foundryMesh = null;
boolean[][][] foundryCallSheetSolid = null;

PFont mono;
PImage fieldworksLogo = null;
boolean fieldworksLogoAttempted = false;
float[][] field = new float[GRID][GRID];
float[][] dominant = new float[GRID][GRID];
float[][] residual = new float[GRID][GRID];
float[][] prevField = new float[GRID][GRID];
float[] cross = new float[GRID];
float[] entropyTrace = new float[TRACE_MAX];
float[] fractalTrace = new float[TRACE_MAX];
float[] lyapTrace = new float[TRACE_MAX];
float[] coherenceTrace = new float[TRACE_MAX];
int traceHead = 0;

int activeLens = 0;
boolean paused = false;
boolean reverseHolonomy = false;
boolean showHelp = false;
boolean dirtyField = true;
int lastMetricFrame = -999;
int seed = 1337;
int selectedMaterial = 0;
int materialSourceMode = 0;
int materialAppliedFrame = -9999;
String materialStatus = "material catalog pending";
String materialAppliedName = "";
String cosmosisCsvStatus = "";
String foundryStatus = "mesh not generated";
String foundryLastExport = "";
String foundryLastCallSheet = "";
String foundryLastCallSheetBase = "";
String foundryLastSurfacePng = "";
String foundryLastLatticePng = "";
String foundryLastSurfaceSvg = "";
String foundryLastLatticeSvg = "";
String foundryLastSourceStl = "";
String foundryLastReliefDefinedStl = "";
String foundryLastReliefDramaticStl = "";
String foundryLastReliefPreviewPng = "";
String foundryLastReliefHeightPng = "";
String foundryLastManifestJson = "";
String foundryCallSheetStatus = "drawings not generated";
String foundryCallSheetGeneratedAt = "";
int foundryResolution = 36;
float foundryIsoBand = 0.105;
float foundryScaleMM = 80.0;
float foundryVeinRadiusMM = 1.8;
float foundryVeinLiftMM = 1.2;
boolean foundryRaisedVeins = true;
boolean foundryMeshStale = false;
int foundryBridgeVoxels = 0;
int foundryBoundaryEdges = 0;
int foundryNonManifoldEdges = 0;
int foundryDegenerateFaces = 0;
boolean cadPreviewEnabled = true;
boolean cadInternalLattice = true;
boolean cadGraphicDrafting = false;
int cadInternalStride = 3;
float cadShadowThreshold = 0.23;
float cadEdgeCull = 0.58;
float cadStochastic = 0.42;
String[] foundryGeometryNames = {
  "TPMS BLEND",
  "GYROID",
  "SCHWARZ P",
  "BELTRAMI SADDLE",
  "HOPF TORUS",
  "PETAMINX LATTICE",
  "MANDELBROT",
  "JULIA",
  "FRACTAL RIDGE",
  "SCHWARZ D",
  "NEOVIUS",
  "I-WP",
  "LIDINOID",
  "FISCHER-KOCH S",
  "SCHOEN FRD",
  "SPLIT P",
  "MENGER SPONGE",
  "MANDELBULB"
};
int foundryGeometryIndex = 0;
float foundryWrapBlend = 0.72;

float alpha = 2.35;
int depth = 5;
float sourcePressure = 0.48;
float floquetCoupling = 0.42;
float quasiEnergy = 0.36;
float coherenceBias = 0.62;
float ctcBias = 0.35;
float braneTwist = 0.58;
float deepDetail = 0.58;
float timeScale = 0.78;

float simT = 0;
float orbitX = 0.58;
float orbitY = 0.06;
float orbitVX = 0;
float orbitVY = 0.72;
float orbitClosure = 0;
float orbitRadius = 0;
float orbitSpeed = 0;
float orbitPhase = 0;

float metricEntropy = 0;
float metricFractal = 1.2;
float metricLyap = 0;
float metricKL = 0;
float metricMI = 0;
float metricCoherence = 0.5;
float metricBeltrami = 0;
float metricHelicity = 0;
float phiResidualMean = 0;
float phiGain = 1;
float phiThreshold = 0;
float holoGamma = 0;
float holoArea = 0;
float holoWinding = 0;
float ctcScore = 0;
float wignerNegativity = 0;

float[] floquetNu = new float[8];
float[] floquetHistory = new float[220];
int floquetHead = 0;

boolean shaperEnabled = false;
boolean shaperUseSender = false;
boolean shaperSenderOnline = false;
float shaperMix = 0.62;
float solarWindStream = 0.5;
float xrayFluxStream = 0.5;
float oceanCurrentStream = 0.5;
float tideStream = 0.5;
float galacticTorsionStream = 0.5;
float shaperDrive = 0;
float shaperPlasma = 0;
float shaperWater = 0;
float shaperCosmic = 0;
int shaperLastPoll = -999;
String shaperSourceStatus = "SIM";

void settings() {
  size(1600, 1000, P3D);
  smooth(4);
}

void setup() {
  surface.setTitle("Cosmosis Visual Observatory");
  if (args == null || args.length == 0) surface.setResizable(true);
  colorMode(RGB, 255);
  mono = createFont("Monospaced", 12);
  textFont(mono);
  randomSeed(seed);
  noiseSeed(seed);
  initControls();
  initMaterials();
  initParticles();
  initFloquet();
  computeField();
  computeMetrics();
  initializeDcrteMilestone0();
  initializeDcrteMilestone1();
  initializeDcrteMilestone2();
  initializeDcrteMilestone25();
  initializeDcrteMilestone25Tests();
  String dcrteM25ReferencePath = dcrteCommandLineValue("--dcrte-m25-reference=");
  if (dcrteM25ReferencePath != null) {
    runDcrteMilestone25ExternalReferenceCase(dcrteM25ReferencePath);
    exit();
    return;
  }
  if (dcrteCommandLineFlag("--dcrte-m25-acceptance")) {
    runDcrteMilestone25AcceptanceMatrix();
    exit();
    return;
  }
  if (dcrteCommandLineFlag("--dcrte-m2-acceptance")) {
    runDcrteMilestone2AcceptanceMatrix();
    exit();
    return;
  }
  if (dcrteCommandLineFlag("--dcrte-m1-acceptance")) {
    runDcrteMilestone1AcceptanceMatrix();
    exit();
  }
}

void draw() {
  if (!paused) {
    simT += 0.012 * max(0.05, timeScale);
    updateShaperStreams();
    stepOrbit();
    updateHolonomyLoom();
    updateFloquetForge();
    updateParticles();
    if (frameCount % 2 == 0) dirtyField = true;
  }
  if (dirtyField) {
    computeField();
    dirtyField = false;
  }
  if (frameCount - lastMetricFrame >= 3) {
    computeMetrics();
    lastMetricFrame = frameCount;
  }
  updateDcrteMilestone0();

  background(7, 10, 15);
  drawTopBar();
  drawControls();
  drawLensTabs();
  drawActiveLens();
  drawStatusStrip();
  if (showHelp) drawHelpOverlay();
}

void initControls() {
  sliders.clear();
  int x = 22;
  int y = 104;
  int w = UI_W - 44;
  int gap = 40;
  sliders.add(new SliderKnob("ALPHA", 1.0, ALPHA_MAX, alpha, x, y, w)); y += gap;
  sliders.add(new SliderKnob("DEPTH", 0, DEPTH_MAX, depth, x, y, w)); y += gap;
  sliders.add(new SliderKnob("SOURCE", 0.05, 1.3, sourcePressure, x, y, w)); y += gap;
  sliders.add(new SliderKnob("FLOQUET", 0, 1, floquetCoupling, x, y, w)); y += gap;
  sliders.add(new SliderKnob("QUASI E", 0, 1, quasiEnergy, x, y, w)); y += gap;
  sliders.add(new SliderKnob("COHERENCE", 0, 1, coherenceBias, x, y, w)); y += gap;
  sliders.add(new SliderKnob("CTC BIAS", 0, 1, ctcBias, x, y, w)); y += gap;
  sliders.add(new SliderKnob("BRANE TWIST", 0, 1, braneTwist, x, y, w)); y += gap;
  sliders.add(new SliderKnob("DEEP DETAIL", 0, 1, deepDetail, x, y, w)); y += gap;
  sliders.add(new SliderKnob("TIME SCALE", 0.05, 1.5, timeScale, x, y, w));
}

void initMaterials() {
  heuristicMaterials.clear();
  databaseMaterials.clear();
  cosmosisMaterials.clear();
  loadMaterialCatalog("material_profiles.json", heuristicMaterials, "heuristic");
  loadMaterialCatalog("material_database_profiles.json", databaseMaterials, "database");
  loadMaterialCatalog("cosmosis_run_profiles.json", cosmosisMaterials, "cosmosis_csv");

  if (heuristicMaterials.size() == 0) {
    addFallbackMaterial("Graphene", "2D carbon lattice", 2.26, 1000.0, 35.0, 280.0, 0.17, 3000.0, 700.0, 0.0, 2.5, 0.98, 0.01, 1.0, 0.0);
    addFallbackMaterial("Fused Silica", "amorphous oxide glass", 2.20, 72.0, 36.0, 31.0, 0.17, 1.4, 703.0, 8.9, 3.8, 0.04, 0.0, 0.25, 0.0);
    addFallbackMaterial("Cortical Bone", "hierarchical biomaterial", 1.90, 18.0, 12.0, 7.0, 0.30, 0.40, 1300.0, 5.0, 15.0, 0.64, 0.12, 0.48, 0.0);
  }

  activateMaterialSource(materialSourceMode);
}

void loadMaterialCatalog(String filename, ArrayList<MaterialProfile> target, String mode) {
  try {
    JSONArray catalog = loadJSONArray(filename);
    for (int i = 0; i < catalog.size(); i++) {
      MaterialProfile m = new MaterialProfile(catalog.getJSONObject(i));
      if (m.sourceMode == null || m.sourceMode.length() == 0 || m.sourceMode.equals("local approximate profile")) m.sourceMode = mode;
      if (!mode.equals("heuristic") && m.sourceMode.equals("heuristic")) m.sourceMode = mode;
      target.add(m);
    }
  }
  catch (Exception e) {
  }
}

void refreshMaterialSources() {
  String currentName = activeMaterial() == null ? "" : activeMaterial().name;
  initMaterials();
  for (int i = 0; i < materials.size(); i++) {
    if (materials.get(i).name.equals(currentName)) {
      selectedMaterial = i;
      break;
    }
  }
}

void activateMaterialSource(int mode) {
  materialSourceMode = (mode + 3) % 3;
  if (materialSourceMode == 0) materials = heuristicMaterials;
  else if (materialSourceMode == 1) materials = databaseMaterials;
  else materials = cosmosisMaterials;
  selectedMaterial = constrain(selectedMaterial, 0, max(0, materials.size() - 1));
  materialStatus = materialSourceLabel() + " " + materials.size();
}

void cycleMaterialSource() {
  activateMaterialSource(materialSourceMode + 1);
}

String materialSourceLabel() {
  if (materialSourceMode == 0) return "HEURISTIC";
  if (materialSourceMode == 1) return "DATABASE";
  return "COSMOSIS";
}

void openCosmosisCsv() {
  activateMaterialSource(2);
  cosmosisCsvStatus = "selecting CSV...";
  selectInput("Open Cosmosis/RDFT CSV run", "cosmosisCsvSelected");
}

void cosmosisCsvSelected(File selection) {
  if (selection == null) {
    cosmosisCsvStatus = "CSV open cancelled";
    return;
  }
  MaterialProfile m = profileFromCosmosisCsv(selection.getAbsolutePath());
  if (m == null) {
    cosmosisCsvStatus = "CSV import failed";
    return;
  }
  cosmosisMaterials.add(m);
  activateMaterialSource(2);
  selectedMaterial = cosmosisMaterials.size() - 1;
  materialStatus = "COSMOSIS " + cosmosisMaterials.size();
  cosmosisCsvStatus = "loaded " + m.name;
  applySelectedMaterial();
}

MaterialProfile profileFromCosmosisCsv(String path) {
  try {
    Table table = loadTable(path, "header,csv");
    if (table == null || table.getRowCount() == 0) return null;
    String name = path;
    int slash = max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
    if (slash >= 0 && slash < path.length() - 1) name = path.substring(slash + 1);
    if (name.toLowerCase().endsWith(".csv")) name = name.substring(0, name.length() - 4);

    float alphaMean = csvMean(table, new String[] {"alpha", "actual_alpha"}, 2.4);
    float depthMean = csvMean(table, new String[] {"depth", "actual_depth", "surface_depth"}, 5.0);
    float entropy = csvMean(table, new String[] {"entropy", "metric_entropy"}, 0.5);
    float fractal = csvMean(table, new String[] {"fractal_dim", "Df", "fractal D"}, 1.6);
    float coherence = csvMean(table, new String[] {"coherence", "found_coherence", "landauer_coherence"}, 0.5);
    float floquet = csvMean(table, new String[] {"floquet_coupling", "floquet_g_eff", "floquet_g_eff_live"}, 0.4);
    float quasi = csvMean(table, new String[] {"floquet_quasienergy", "quasi_energy", "quasiEnergy"}, 0.4);
    float curvature = csvMean(table, new String[] {"surface_curv", "berry_curvature_density", "found_rot_activity"}, 0.4);
    float helicity = csvMean(table, new String[] {"beltrami_helicity", "hopf_activity_proxy", "hopf_link_proxy"}, 0.2);
    float variability = constrain(csvStd(table, new String[] {"alpha", "actual_alpha"}, 0.0) * 0.30 + csvStd(table, new String[] {"floquet_coupling"}, 0.0), 0, 1);

    MaterialProfile m = new MaterialProfile();
    m.name = name;
    m.family = "Cosmosis run imprint";
    m.source = "in-app CSV open";
    m.sourceMode = "cosmosis_csv";
    m.provider = "cosmosis_csv";
    m.sourceId = name + ".csv rows=" + table.getRowCount();
    m.confidence = "run-imprint";
    m.missingFields = "physical_properties_are_effective_run_proxies";
    m.notes = "Generated in-app from Cosmosis/RDFT CSV dynamics.";
    m.density = lerp(0.4, 9.0, constrain((alphaMean - 1.0) / 5.0, 0, 1));
    m.youngs = lerp(0.01, 650.0, constrain(coherence * 0.46 + floquet * 0.24 + (fractal - 1.0) / 1.55 * 0.30, 0, 1));
    m.bulk = lerp(0.01, 320.0, constrain(coherence * 0.42 + curvature * 0.30 + floquet * 0.28, 0, 1));
    m.shear = lerp(0.002, 260.0, constrain(abs(helicity) * 0.38 + curvature * 0.32 + variability * 0.30, 0, 1));
    m.poisson = lerp(0.08, 0.38, constrain(1.0 - variability, 0, 1));
    m.thermal = lerp(0.02, 900.0, constrain(floquet * 0.55 + quasi * 0.25 + coherence * 0.20, 0, 1));
    m.heatCapacity = lerp(350.0, 1500.0, constrain(entropy, 0, 1));
    m.bandGap = lerp(0.0, 8.0, constrain(quasi, 0, 1));
    m.dielectric = lerp(1.0, 220.0, constrain(curvature * 0.45 + quasi * 0.35 + floquet * 0.20, 0, 1));
    m.anisotropy = constrain(abs(helicity) * 0.50 + variability * 0.34 + curvature * 0.16, 0, 1);
    m.porosity = constrain(entropy * 0.45 + (1.0 - coherence) * 0.35 + depthMean / (float)DEPTH_MAX * 0.20, 0, 1);
    m.crystalOrder = constrain(coherence * 0.55 + (1.0 - entropy) * 0.25 + floquet * 0.20, 0, 1);
    m.magnetic = constrain(abs(helicity) * 0.55 + curvature * 0.25 + variability * 0.20, 0, 1);
    m.computeMappings();
    return m;
  }
  catch (Exception e) {
    println("Cosmosis CSV import failed: " + e);
    return null;
  }
}

String csvColumnName(Table table, String[] names) {
  String[] titles = table.getColumnTitles();
  for (String want : names) {
    for (String title : titles) {
      if (title != null && title.equalsIgnoreCase(want)) return title;
    }
  }
  return null;
}

float csvMean(Table table, String[] names, float fallback) {
  String col = csvColumnName(table, names);
  if (col == null) return fallback;
  float sum = 0;
  int count = 0;
  for (TableRow row : table.rows()) {
    float v = parseFloat(safeString(row.getString(col), ""));
    if (!Float.isNaN(v)) {
      sum += v;
      count++;
    }
  }
  return count == 0 ? fallback : sum / count;
}

float csvStd(Table table, String[] names, float fallback) {
  String col = csvColumnName(table, names);
  if (col == null) return fallback;
  float avg = csvMean(table, names, fallback);
  float sumSq = 0;
  int count = 0;
  for (TableRow row : table.rows()) {
    float v = parseFloat(safeString(row.getString(col), ""));
    if (!Float.isNaN(v)) {
      float d = v - avg;
      sumSq += d * d;
      count++;
    }
  }
  return count < 2 ? fallback : sqrt(sumSq / count);
}

void addFallbackMaterial(String name, String family, float density, float youngs, float bulk, float shear, float poisson, float thermal, float heatCapacity, float bandGap, float dielectric, float anisotropy, float porosity, float crystalOrder, float magnetic) {
  MaterialProfile m = new MaterialProfile();
  m.name = name;
  m.family = family;
  m.source = "built-in fallback";
  m.sourceMode = "heuristic";
  m.sourceId = "fallback:" + name;
  m.confidence = "fallback";
  m.notes = "Fallback material profile.";
  m.density = density;
  m.youngs = youngs;
  m.bulk = bulk;
  m.shear = shear;
  m.poisson = poisson;
  m.thermal = thermal;
  m.heatCapacity = heatCapacity;
  m.bandGap = bandGap;
  m.dielectric = dielectric;
  m.anisotropy = anisotropy;
  m.porosity = porosity;
  m.crystalOrder = crystalOrder;
  m.magnetic = magnetic;
  m.computeMappings();
  heuristicMaterials.add(m);
}

void initParticles() {
  particles.clear();
  for (int i = 0; i < PARTICLE_COUNT; i++) {
    particles.add(new Particle(random(1), random(1)));
  }
}

void initFloquet() {
  for (int i = 0; i < floquetNu.length; i++) {
    floquetNu[i] = random(-0.22, 0.22);
  }
  for (int i = 0; i < floquetHistory.length; i++) floquetHistory[i] = 0;
}

void updateShaperStreams() {
  boolean loadedSender = false;
  if (shaperUseSender && frameCount - shaperLastPoll > 30) {
    loadedSender = loadShaperSenderFrame();
    shaperLastPoll = frameCount;
  }
  if (!shaperUseSender || !shaperSenderOnline) {
    float t = simT;
    solarWindStream = constrain(0.5 + 0.28 * sin(t * 0.73 + 0.4) + 0.18 * noise(20.0, t * 0.12), 0, 1);
    xrayFluxStream = constrain(0.5 + 0.33 * sin(t * 1.17 + 1.8) + 0.14 * sin(t * 3.4), 0, 1);
    oceanCurrentStream = constrain(0.5 + 0.34 * sin(t * 0.31 + 2.2) + 0.16 * noise(44.0, t * 0.08), 0, 1);
    tideStream = constrain(0.5 + 0.46 * sin(t * 0.18 + 0.5) + 0.06 * sin(t * 0.72), 0, 1);
    galacticTorsionStream = constrain(0.5 + 0.24 * sin(t * 0.09 + braneTwist * TWO_PI) + 0.20 * sin(t * 0.21 + alpha), 0, 1);
    shaperSourceStatus = shaperUseSender ? "SENDER WAIT" : "SIM";
  } else if (loadedSender) {
    shaperSourceStatus = "SENDER";
  }
  shaperPlasma = constrain(solarWindStream * 0.58 + xrayFluxStream * 0.42, 0, 1);
  shaperWater = constrain(oceanCurrentStream * 0.54 + tideStream * 0.46, 0, 1);
  shaperCosmic = constrain(galacticTorsionStream * 0.74 + abs(holoGamma) / PI * 0.26, 0, 1);
  shaperDrive = constrain(shaperPlasma * 0.36 + shaperWater * 0.30 + shaperCosmic * 0.34, 0, 1);
}

boolean loadShaperSenderFrame() {
  try {
    JSONObject frame = loadJSONObject("shaper_streams.json");
    solarWindStream = constrain(jsonFloat(frame, "solar_wind", solarWindStream), 0, 1);
    xrayFluxStream = constrain(jsonFloat(frame, "xray_flux", xrayFluxStream), 0, 1);
    oceanCurrentStream = constrain(jsonFloat(frame, "ocean_current", oceanCurrentStream), 0, 1);
    tideStream = constrain(jsonFloat(frame, "tide", tideStream), 0, 1);
    galacticTorsionStream = constrain(jsonFloat(frame, "galactic_torsion", galacticTorsionStream), 0, 1);
    shaperMix = constrain(jsonFloat(frame, "mix", shaperMix), 0, 1);
    shaperSenderOnline = true;
    return true;
  }
  catch (Exception e) {
    shaperSenderOnline = false;
    return false;
  }
}

float shaperAmount() {
  return shaperEnabled ? shaperMix : 0;
}

float shaperBipolar(float v) {
  return (v - 0.5) * 2.0 * shaperAmount();
}

void syncControls() {
  alpha = sliders.get(0).value;
  depth = round(sliders.get(1).value);
  sliders.get(1).value = depth;
  sourcePressure = sliders.get(2).value;
  floquetCoupling = sliders.get(3).value;
  quasiEnergy = sliders.get(4).value;
  coherenceBias = sliders.get(5).value;
  ctcBias = sliders.get(6).value;
  braneTwist = sliders.get(7).value;
  deepDetail = sliders.get(8).value;
  timeScale = sliders.get(9).value;
}

void selectMaterial(int delta) {
  if (materials.size() == 0) return;
  selectedMaterial = (selectedMaterial + delta + materials.size()) % materials.size();
}

MaterialProfile activeMaterial() {
  if (materials.size() == 0) return null;
  selectedMaterial = constrain(selectedMaterial, 0, materials.size() - 1);
  return materials.get(selectedMaterial);
}

void applySelectedMaterial() {
  MaterialProfile m = activeMaterial();
  if (m == null) return;
  setSliderValue(0, m.alphaMap);
  setSliderValue(1, round(m.depthMap));
  setSliderValue(2, m.sourceMap);
  setSliderValue(3, m.floquetMap);
  setSliderValue(4, m.quasiMap);
  setSliderValue(5, m.coherenceMap);
  setSliderValue(6, m.ctcMap);
  setSliderValue(7, m.braneMap);
  setSliderValue(8, m.detailMap);
  setSliderValue(9, m.timeMap);
  syncControls();
  materialAppliedName = m.name;
  materialAppliedFrame = frameCount;
  resetState();
}

void setSliderValue(int idx, float v) {
  SliderKnob s = sliders.get(idx);
  s.value = constrain(v, s.minVal, s.maxVal);
}

float logNorm(float v, float lo, float hi) {
  v = max(v, lo);
  return constrain((log(v) - log(lo)) / max(0.0001, log(hi) - log(lo)), 0, 1);
}

float jsonFloat(JSONObject obj, String key, float fallback) {
  try {
    return obj.getFloat(key);
  }
  catch (Exception e) {
    return fallback;
  }
}

String jsonString(JSONObject obj, String key, String fallback) {
  try {
    String v = obj.getString(key);
    return v == null ? fallback : v;
  }
  catch (Exception e) {
    return fallback;
  }
}

String safeString(String v, String fallback) {
  return v == null ? fallback : v;
}

void computeField() {
  for (int r = 0; r < GRID; r++) {
    for (int c = 0; c < GRID; c++) {
      prevField[r][c] = field[r][c];
    }
  }

  float maxVal = 0.0001;
  float minVal = 999;
  for (int r = 0; r < GRID; r++) {
    float y = map(r, 0, GRID - 1, -1, 1);
    for (int c = 0; c < GRID; c++) {
      float x = map(c, 0, GRID - 1, -1, 1);
      float rad = sqrt(x*x + y*y);
      float theta = atan2(y, x);
      float combo = 0;
      float best = -999;
      int bestLayer = 0;
      for (int d = 0; d <= depth; d++) {
        float scale = pow(2, d);
        float wt = (alpha <= 1.001) ? 1.0 : pow(alpha, -d * recursionFalloff());
        float shaperPhase = shaperAmount() * ((shaperPlasma - 0.5) * 1.45 + (shaperWater - 0.5) * 0.82 + (shaperCosmic - 0.5) * 1.15) * (1.0 + d * 0.055);
        float phase = simT * (0.42 + d * 0.055) + floquetCoupling * d * 0.8 + shaperPhase;
        float rectPart = sin((x + 1.0) * PI * scale * 0.5 + phase)
                       * sin((y + 1.0) * PI * scale * 0.5 - phase * 0.72);
        float polarPart = cos((d + 2) * theta + phase * 0.8)
                        * sin((scale * 0.52 + 1.0) * PI * rad - phase * 0.35);
        float lattice = cos(scale * x * 1.7 + braneTwist * TWO_PI)
                      * sin(scale * y * 1.35 - quasiEnergy * TWO_PI);
        float val = (rectPart * 0.48 + polarPart * 0.34 + lattice * 0.18);
        val = 0.5 + 0.5 * val;
        val *= wt * (0.82 + 0.18 * sin(theta * (d + 1) + simT));
        combo += val;
        if (val > best) {
          best = val;
          bestLayer = d;
        }
      }
      float noiseFold = noise(c * 0.035, r * 0.035, seed * 0.001 + simT * 0.18 + shaperAmount() * shaperCosmic * 0.35);
      combo += noiseFold * 0.08 * (0.2 + sourcePressure + shaperAmount() * shaperPlasma * 0.22);
      field[r][c] = combo;
      dominant[r][c] = (float)bestLayer / max(1, depth);
      maxVal = max(maxVal, combo);
      minVal = min(minVal, combo);
    }
  }

  for (int r = 0; r < GRID; r++) {
    float crossVal = 0;
    for (int c = 0; c < GRID; c++) {
      field[r][c] = constrain((field[r][c] - minVal) / max(0.0001, maxVal - minVal), 0, 1);
      if (r == GRID / 2) cross[c] = field[r][c];
    }
  }
  computeResidualField();
}

float recursionFalloff() {
  return lerp(0.58, 0.11, constrain(deepDetail, 0, 1));
}

void computeResidualField() {
  float sumResidual = 0;
  float sumGain = 0;
  float sumThreshold = 0;
  for (int r = 1; r < GRID - 1; r++) {
    float y = map(r, 0, GRID - 1, -1, 1);
    for (int c = 1; c < GRID - 1; c++) {
      float x = map(c, 0, GRID - 1, -1, 1);
      float rad = sqrt(x*x + y*y);
      float phi = -0.58 * sourcePressure + 0.42 * (field[r][c] - 0.5) - 0.16 * rad;
      float gx = field[r][c + 1] - field[r][c - 1];
      float gy = field[r + 1][c] - field[r - 1][c];
      float grad2 = gx*gx + gy*gy;
      float expTerm = min(20.0, exp(-2.0 * phi));
      float source = sourcePressure + 0.22 * quasiEnergy + 0.16 * dominant[r][c];
      float A = 0.5;
      float F = phi + 0.5 * grad2 + A * expTerm * source;
      float gain = 1.0 - 2.0 * A * expTerm * source;
      float threshold = constrain(2.0 * A * expTerm * source, 0, 2);
      residual[r][c] = constrain(0.5 + F * 0.45, 0, 1);
      sumResidual += abs(F);
      sumGain += gain;
      sumThreshold += threshold;
    }
  }
  int n = max(1, (GRID - 2) * (GRID - 2));
  phiResidualMean = lerp(phiResidualMean, sumResidual / n, 0.18);
  phiGain = lerp(phiGain, sumGain / n, 0.18);
  phiThreshold = lerp(phiThreshold, constrain(sumThreshold / n, 0, 1.4), 0.18);
}

void computeMetrics() {
  int bins = max(4, depth + 2);
  int[] counts = new int[bins];
  float sum = 0;
  float sumSq = 0;
  float edge = 0;
  float kl = 0;
  float helicity = 0;
  float beltrami = 0;
  for (int r = 1; r < GRID - 1; r++) {
    for (int c = 1; c < GRID - 1; c++) {
      float v = field[r][c];
      int b = constrain(floor(v * bins), 0, bins - 1);
      counts[b]++;
      sum += v;
      sumSq += v*v;
      float gx = field[r][c + 1] - field[r][c - 1];
      float gy = field[r + 1][c] - field[r - 1][c];
      float curl = (field[r + 1][c] - field[r - 1][c]) - (field[r][c + 1] - field[r][c - 1]);
      edge += sqrt(gx*gx + gy*gy);
      helicity += (gx * sin(simT + dominant[r][c] * TWO_PI) + gy * cos(simT + v * TWO_PI)) * curl;
      beltrami += abs(curl) / max(0.0001, sqrt(gx*gx + gy*gy) + 0.01);
      float p = constrain(v, 0, 1) + 0.00001;
      float q = constrain(prevField[r][c], 0, 1) + 0.00001;
      kl += p * log(p / q);
    }
  }
  float n = max(1, (GRID - 2) * (GRID - 2));
  float entropy = 0;
  for (int i = 0; i < bins; i++) {
    float p = counts[i] / n;
    if (p > 0.00001) entropy -= p * log(p) / log(2);
  }
  metricEntropy = lerp(metricEntropy, entropy / max(0.001, log(bins) / log(2)), 0.16);
  metricFractal = lerp(metricFractal, constrain(1.0 + edge / n * 16.0 + depth * 0.025, 1.0, 2.55), 0.16);
  metricKL = lerp(metricKL, constrain(abs(kl) / n * 12.0, 0, 1.8), 0.16);
  metricMI = lerp(metricMI, constrain((coherenceBias * 0.4 + floquetCoupling * 0.26 + (1.0 - metricEntropy) * 0.34), 0, 1), 0.16);
  metricLyap = lerp(metricLyap, constrain(orbitSpeed * 0.28 + metricKL * 0.32 + (1.0 - phiGain) * 0.18, 0, 1.8), 0.12);
  metricCoherence = lerp(metricCoherence, constrain(coherenceBias * 0.36 + metricMI * 0.34 + (1.0 - metricEntropy) * 0.18 + floquetCoupling * 0.12 - metricKL * 0.08, 0, 1), 0.16);
  metricBeltrami = lerp(metricBeltrami, constrain(beltrami / n * 3.0, 0, 1), 0.15);
  metricHelicity = lerp(metricHelicity, constrain(0.5 + helicity / n * 12.0, 0, 1), 0.15);
  ctcScore = constrain(0.24 * ctcBias + 0.22 * phiThreshold + 0.20 * orbitClosure + 0.16 * (1.0 - metricLyap / 1.8) + 0.18 * floquetCoupling, 0, 1);
  wignerNegativity = constrain(metricKL * 0.26 + (1.0 - metricCoherence) * 0.24 + quasiEnergy * 0.24 + abs(holoGamma) * 0.16, 0, 1);

  entropyTrace[traceHead] = metricEntropy;
  fractalTrace[traceHead] = constrain((metricFractal - 1.0) / 1.55, 0, 1);
  lyapTrace[traceHead] = constrain(metricLyap / 1.8, 0, 1);
  coherenceTrace[traceHead] = metricCoherence;
  traceHead = (traceHead + 1) % TRACE_MAX;
}

void stepOrbit() {
  int cx = constrain(round(map(orbitX, -1.2, 1.2, 2, GRID - 3)), 2, GRID - 3);
  int cy = constrain(round(map(orbitY, -1.2, 1.2, 2, GRID - 3)), 2, GRID - 3);
  float gx = field[cy][cx + 1] - field[cy][cx - 1];
  float gy = field[cy + 1][cx] - field[cy - 1][cx];
  float centerPull = 0.018 + 0.020 * coherenceBias;
  float swirl = 0.012 + 0.038 * floquetCoupling;
  float ax = -orbitX * centerPull - gx * 0.42 + -orbitY * swirl;
  float ay = -orbitY * centerPull - gy * 0.42 + orbitX * swirl;
  orbitVX = orbitVX * 0.992 + ax * timeScale;
  orbitVY = orbitVY * 0.992 + ay * timeScale;
  orbitX += orbitVX * 0.012 * timeScale;
  orbitY += orbitVY * 0.012 * timeScale;
  float bound = 1.24;
  if (abs(orbitX) > bound) { orbitX = constrain(orbitX, -bound, bound); orbitVX *= -0.72; }
  if (abs(orbitY) > bound) { orbitY = constrain(orbitY, -bound, bound); orbitVY *= -0.72; }
  orbitRadius = sqrt(orbitX*orbitX + orbitY*orbitY);
  orbitSpeed = sqrt(orbitVX*orbitVX + orbitVY*orbitVY);
  orbitPhase = atan2(orbitY, orbitX);
  orbitTrail.add(new PVector(orbitX, orbitY, orbitPhase));
  while (orbitTrail.size() > TRAIL_MAX) orbitTrail.remove(0);
  if (orbitTrail.size() > 80) {
    PVector now = orbitTrail.get(orbitTrail.size() - 1);
    PVector old = orbitTrail.get(max(0, orbitTrail.size() - 72));
    float d = dist(now.x, now.y, old.x, old.y);
    orbitClosure = lerp(orbitClosure, constrain(1.0 - d / max(0.12, orbitRadius + 0.12), 0, 1), 0.08);
  }
}

void updateHolonomyLoom() {
  float spanA = 0.58 + 0.32 * braneTwist;
  float spanD = 1.1 + 1.8 * floquetCoupling;
  float a0 = constrain(alpha - spanA, 1.0, ALPHA_MAX);
  float a1 = constrain(alpha + spanA, 1.0, ALPHA_MAX);
  float d0 = constrain(depth - spanD, 0, DEPTH_MAX);
  float d1 = constrain(depth + spanD, 0, DEPTH_MAX);
  float u = (simT * 0.09 * (reverseHolonomy ? -1 : 1)) % 1.0;
  if (u < 0) u += 1.0;
  float pa = a0;
  float pd = d0;
  if (u < 0.25) {
    float t = u / 0.25;
    pa = lerp(a0, a1, t);
    pd = d0;
  } else if (u < 0.5) {
    float t = (u - 0.25) / 0.25;
    pa = a1;
    pd = lerp(d0, d1, t);
  } else if (u < 0.75) {
    float t = (u - 0.5) / 0.25;
    pa = lerp(a1, a0, t);
    pd = d1;
  } else {
    float t = (u - 0.75) / 0.25;
    pa = a0;
    pd = lerp(d1, d0, t);
  }
  holoArea = (a1 - a0) * (d1 - d0) * (reverseHolonomy ? -1 : 1);
  float localCurv = (metricBeltrami - 0.5) * 0.9 + (phiThreshold - 0.6) * 0.45 + (quasiEnergy - 0.5) * 0.35;
  holoGamma = lerp(holoGamma, constrain(holoArea * localCurv * 0.33, -PI * 1.2, PI * 1.2), 0.035);
  holoWinding = holoGamma / TWO_PI;
  holoTrail.add(new PVector(pa, pd, u));
  holoGammaTrail.add(holoGamma);
  while (holoTrail.size() > HOLO_MAX) {
    holoTrail.remove(0);
    holoGammaTrail.remove(0);
  }
}

void updateFloquetForge() {
  for (int i = 0; i < floquetNu.length; i++) {
    float target = sin(simT * (0.37 + i * 0.041) + i * 1.7 + metricCoherence) * 0.20;
    target += cos(holoGamma + i * 0.9) * 0.08 * floquetCoupling;
    if (shaperEnabled) {
      float channel = i % 3 == 0 ? shaperPlasma : i % 3 == 1 ? shaperWater : shaperCosmic;
      target += shaperBipolar(channel) * (0.10 + 0.018 * i);
    }
    floquetNu[i] = lerp(floquetNu[i], constrain(target, -0.45, 0.45), 0.016);
  }
  float g = evaluateFloquet(simT);
  floquetHistory[floquetHead] = g;
  floquetHead = (floquetHead + 1) % floquetHistory.length;
}

float evaluateFloquet(float t) {
  float g = 0;
  for (int n = 1; n <= 4; n++) {
    int ia = (n - 1) * 2;
    int ib = ia + 1;
    g += floquetNu[ia] * cos(n * TWO_PI * (0.18 + quasiEnergy * 0.38) * t)
       + floquetNu[ib] * sin(n * TWO_PI * (0.18 + quasiEnergy * 0.38) * t);
  }
  float topo = 1.0 + 0.28 * cos(holoGamma + metricHelicity * TWO_PI) * metricBeltrami;
  g += shaperAmount() * 0.22 * sin(t * TWO_PI * (0.09 + shaperCosmic * 0.12) + shaperPlasma * TWO_PI);
  return constrain(g * topo, -1.2, 1.2);
}

void updateParticles() {
  for (Particle p : particles) p.step();
}

void drawTopBar() {
  noStroke();
  fill(10, 15, 22);
  rect(0, 0, width, TOP_H);
  fill(225, 240, 242);
  textAlign(LEFT, TOP);
  textSize(16);
  text("COSMOSIS VISUAL OBSERVATORY", 20, 12);
  textSize(10);
  fill(125, 165, 178);
  text("visual-only RDFT theory workspace  |  no audio / no SuperCollider / no BasinNET runtime", 20, 34);
  drawButton(width - 312, 15, 72, 26, paused ? "RUN" : "PAUSE", paused ? color(45, 110, 70) : color(92, 66, 42));
  drawButton(width - 232, 15, 72, 26, "RESET", color(56, 75, 98));
  drawButton(width - 152, 15, 92, 26, "RANDOMIZE", color(70, 56, 100));
  drawButton(width - 50, 15, 30, 26, "?", color(52, 70, 78));
}

void drawControls() {
  noStroke();
  fill(8, 12, 18);
  rect(0, TOP_H, UI_W, height - TOP_H);
  fill(150, 220, 210);
  textSize(11);
  textAlign(LEFT, TOP);
  text("THEORY PARAMETERS", 22, 76);
  for (SliderKnob s : sliders) s.draw();

  drawMaterialTargetPanel(22, materialPanelY(), UI_W - 44, MATERIAL_PANEL_H);

  int y = height - 268;
  drawMetricBlock(22, y, UI_W - 44, "FIELD STATE");
  y += 34;
  drawGauge(22, y, UI_W - 44, "entropy", metricEntropy, color(255, 165, 86)); y += 23;
  drawGauge(22, y, UI_W - 44, "fractal D", constrain((metricFractal - 1.0) / 1.55, 0, 1), color(105, 226, 160)); y += 23;
  drawGauge(22, y, UI_W - 44, "coherence", metricCoherence, color(116, 184, 255)); y += 23;
  drawGauge(22, y, UI_W - 44, "phi threshold", constrain(phiThreshold, 0, 1), color(255, 100, 110)); y += 23;
  drawGauge(22, y, UI_W - 44, "ctc window", ctcScore, color(210, 142, 255)); y += 34;
  fill(100, 130, 145);
  textSize(9);
  text("Keys: 1-9 select lenses, [ ] target material, M source mode, O opens Cosmosis CSV, U reloads data, V applies target, G generates STL mesh, C call sheets, X pulls SVG, E exports STL, N cycles Foundry geometry, SPACE pauses, R resets, H help.", 22, y, UI_W - 44, 60);
}

int materialPanelY() {
  return height - 430;
}

void drawMaterialTargetPanel(int x, int y, int w, int h) {
  MaterialProfile m = activeMaterial();
  fill(5, 9, 14, 225);
  stroke(32, 58, 68);
  rect(x, y, w, h, 7);
  fill(145, 230, 215);
  textAlign(LEFT, TOP);
  textSize(10);
  text("MATERIAL TARGET", x + 10, y + 9);
  fill(95, 126, 136);
  textAlign(RIGHT, TOP);
  textSize(8);
  text(materialStatus, x + w - 10, y + 11);

  if (m == null) {
    fill(130, 160, 170);
    textAlign(LEFT, TOP);
    textSize(9);
    String hint = materialSourceMode == 1 ? "No database profiles loaded. Run adapters/material_source_adapter.py."
                : materialSourceMode == 2 ? "No Cosmosis CSV profiles loaded. Press O to open a run CSV."
                : "No material catalog loaded.";
    text(hint, x + 10, y + 34, w - 20, 56);
    int by0 = y + h - 24;
    drawButton(x + 10, by0, 54, 18, "MODE", color(42, 57, 68));
    drawButton(x + 70, by0, 58, 18, "RELOAD", color(42, 57, 68));
    if (materialSourceMode == 2) drawButton(x + 134, by0, 52, 18, "OPEN", color(47, 68, 90));
    return;
  }

  fill(225, 242, 238);
  textAlign(LEFT, TOP);
  textSize(10);
  text(shortText(m.name, 24), x + 10, y + 30);
  fill(125, 160, 170);
  textSize(8);
  text(shortText(m.family, 29), x + 10, y + 45);
  fill(92, 122, 134);
  text(shortText(m.provenanceLabel(), 34), x + 10, y + 57);
  textAlign(RIGHT, TOP);
  text((selectedMaterial + 1) + "/" + materials.size(), x + w - 10, y + 30);

  drawMiniGauge(x + 10, y + 72, w - 20, "stiff", m.stiffnessN, color(110, 210, 245));
  drawMiniGauge(x + 10, y + 88, w - 20, "order", m.orderN, color(112, 232, 170));
  float functional = max(m.phaseTransform, max(m.topologicalResponse, m.superconductingCoherence));
  if (functional > 0.05) drawMiniGauge(x + 10, y + 104, w - 20, "functional", functional, color(255, 174, 84));
  else drawMiniGauge(x + 10, y + 104, w - 20, "porous/anis", constrain((m.porosity + m.anisotropy) * 0.5, 0, 1), color(255, 174, 84));

  int by = y + h - 24;
  drawButton(x + 10, by, 28, 18, "<", color(42, 57, 68));
  drawButton(x + 44, by, 64, 18, "APPLY", materialAppliedFrame > 0 && frameCount - materialAppliedFrame < 90 ? color(45, 108, 78) : color(47, 68, 90));
  drawButton(x + 114, by, 28, 18, ">", color(42, 57, 68));
  drawButton(x + 148, by, 48, 18, "MODE", color(42, 57, 68));
  if (materialSourceMode == 2) drawButton(x + 202, by, 34, 18, "OPEN", color(47, 68, 90));
  fill(92, 118, 130);
  textSize(8);
  textAlign(RIGHT, CENTER);
  String conf = safeString(m.confidence, "");
  if (materialSourceMode != 2) text(conf.length() == 0 ? "V APPLY" : shortText(conf, 9), x + w - 10, by + 9);
}

void drawMiniGauge(int x, int y, int w, String label, float v, color c) {
  v = constrain(v, 0, 1);
  fill(110, 138, 148);
  textSize(8);
  textAlign(LEFT, CENTER);
  text(label, x, y + 5);
  noStroke();
  fill(24, 34, 42);
  rect(x + 68, y + 2, w - 68, 6, 3);
  fill(c);
  rect(x + 68, y + 2, (w - 68) * v, 6, 3);
}

String shortText(String s, int maxChars) {
  if (s == null) return "";
  if (s.length() <= maxChars) return s;
  return s.substring(0, max(0, maxChars - 3)) + "...";
}

void drawLensTabs() {
  int x0 = UI_W + 16;
  int y = 70;
  int usable = width - x0 - 18;
  int tabW = usable / lensNames.length;
  for (int i = 0; i < lensNames.length; i++) {
    int x = x0 + i * tabW;
    boolean active = i == activeLens;
    fill(active ? color(26, 58, 68) : color(12, 18, 25));
    stroke(active ? color(90, 235, 220) : color(35, 54, 62));
    rect(x, y, tabW - 5, 30, 5);
    fill(active ? color(220, 255, 248) : color(110, 140, 150));
    textAlign(CENTER, CENTER);
    textSize(9);
    text(lensNames[i], x + (tabW - 5) / 2, y + 15);
  }
}

void drawActiveLens() {
  int x = UI_W + 18;
  int y = 112;
  int w = width - x - 20;
  int h = height - y - 48;
  if (activeLens == 0) drawFieldAtlas(x, y, w, h);
  else if (activeLens == 1) drawHolonomyLoom(x, y, w, h);
  else if (activeLens == 2) drawPhiThreshold(x, y, w, h);
  else if (activeLens == 3) drawFloquetForge(x, y, w, h);
  else if (activeLens == 4) drawCTCObservatory(x, y, w, h);
  else if (activeLens == 5) drawWignerStudio(x, y, w, h);
  else if (activeLens == 6) drawBranesFibers(x, y, w, h);
  else if (activeLens == 7) drawTopologyLab(x, y, w, h);
  else drawSurfaceFoundry(x, y, w, h);
}

void drawFieldAtlas(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "FIELD ATLAS");
  int mapSize = min(h - 94, w - 360);
  int mx = x + 24;
  int my = y + 48;
  drawHeatmap(field, mx, my, mapSize, mapSize, 0);
  drawFieldThreads(mx, my, mapSize, mapSize);
  drawOrbitOverlay(mx, my, mapSize, mapSize);
  drawCrossSectionGraph(mx, my + mapSize + 18, mapSize, 52);

  int rx = mx + mapSize + 28;
  int rw = w - (rx - x) - 24;
  drawReadoutPanel(rx, my, rw, 156, "RECURSIVE DISTINCTION");
  drawGauge(rx + 16, my + 40, rw - 32, "alpha/depth density", constrain(depth / (float)DEPTH_MAX * 0.55 + (alpha - 1) / (ALPHA_MAX - 1) * 0.45, 0, 1), color(125, 225, 170));
  drawGauge(rx + 16, my + 66, rw - 32, "dominant layer variance", metricEntropy, color(255, 170, 85));
  drawGauge(rx + 16, my + 92, rw - 32, "field coherence", metricCoherence, color(100, 180, 255));
  drawGauge(rx + 16, my + 118, rw - 32, "Beltrami threading", metricBeltrami, color(120, 255, 220));

  drawReadoutPanel(rx, my + 174, rw, 190, "PARTICLE FLOW");
  drawParticleWindow(rx + 16, my + 214, rw - 32, 112);
  fill(126, 160, 170);
  textSize(9);
  textAlign(LEFT, TOP);
  text("Particles drift along the same gradient field used for metrics; color shifts toward threshold and holonomy activity.", rx + 16, my + 334, rw - 32, 40);

  drawTracePanel(rx, my + 382, rw, h - 430);
}

void drawHolonomyLoom(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "HOLONOMY LOOM");
  int planeW = min(w - 360, h - 80);
  int px = x + 34;
  int py = y + 54;
  fill(4, 8, 14);
  stroke(42, 70, 82);
  rect(px, py, planeW, planeW, 6);
  drawGridLines(px, py, planeW, planeW, 8, color(28, 48, 58));
  fill(132, 170, 180);
  textSize(9);
  textAlign(LEFT, TOP);
  text("alpha", px, py + planeW + 8);
  pushMatrix();
  translate(px - 24, py + planeW / 2);
  rotate(-HALF_PI);
  text("depth", 0, 0);
  popMatrix();

  float aSpan = 0.58 + 0.32 * braneTwist;
  float dSpan = 1.1 + 1.8 * floquetCoupling;
  float a0 = constrain(alpha - aSpan, 1.0, ALPHA_MAX);
  float a1 = constrain(alpha + aSpan, 1.0, ALPHA_MAX);
  float d0 = constrain(depth - dSpan, 0, DEPTH_MAX);
  float d1 = constrain(depth + dSpan, 0, DEPTH_MAX);
  float rx0 = map(a0, 1, ALPHA_MAX, px + 28, px + planeW - 28);
  float rx1 = map(a1, 1, ALPHA_MAX, px + 28, px + planeW - 28);
  float ry0 = map(d0, 0, DEPTH_MAX, py + planeW - 28, py + 28);
  float ry1 = map(d1, 0, DEPTH_MAX, py + planeW - 28, py + 28);
  drawHolonomyCurvatureOverlay(min(rx0, rx1), min(ry0, ry1), abs(rx1 - rx0), abs(ry1 - ry0));
  noFill();
  stroke(reverseHolonomy ? color(205, 140, 255) : color(95, 230, 205));
  strokeWeight(2);
  rect(min(rx0, rx1), min(ry0, ry1), abs(rx1 - rx0), abs(ry1 - ry0));
  drawHolonomyLoopFibers(min(rx0, rx1), min(ry0, ry1), abs(rx1 - rx0), abs(ry1 - ry0));

  noFill();
  beginShape();
  for (int i = 0; i < holoTrail.size(); i++) {
    PVector p = holoTrail.get(i);
    float g = holoGammaTrail.get(i);
    float hx = map(p.x, 1, ALPHA_MAX, px + 28, px + planeW - 28);
    float hy = map(p.y, 0, DEPTH_MAX, py + planeW - 28, py + 28);
    stroke(g >= 0 ? color(90, 230, 205, 60 + i * 165 / max(1, holoTrail.size()))
                  : color(220, 120, 255, 60 + i * 165 / max(1, holoTrail.size())));
    vertex(hx, hy);
  }
  endShape();
  if (holoTrail.size() > 0) {
    PVector p = holoTrail.get(holoTrail.size() - 1);
    float hx = map(p.x, 1, ALPHA_MAX, px + 28, px + planeW - 28);
    float hy = map(p.y, 0, DEPTH_MAX, py + planeW - 28, py + 28);
    noStroke();
    fill(255, 180, 80);
    ellipse(hx, hy, 12, 12);
  }

  int rx = px + planeW + 32;
  int rw = w - (rx - x) - 28;
  drawReadoutPanel(rx, py, rw, 190, "LOOP INVARIANTS");
  metricLine(rx + 16, py + 40, "gamma", nf(holoGamma, 1, 4) + " rad");
  metricLine(rx + 16, py + 62, "gamma/pi", nf(holoGamma / PI, 1, 4));
  metricLine(rx + 16, py + 84, "winding", nf(holoWinding, 1, 4));
  metricLine(rx + 16, py + 106, "loop area", nf(holoArea, 1, 4));
  metricLine(rx + 16, py + 128, "orientation", reverseHolonomy ? "reverse" : "forward");
  drawButton(rx + 16, py + 150, 132, 24, reverseHolonomy ? "RUN FORWARD" : "RUN REVERSED", color(70, 52, 96));

  drawReadoutPanel(rx, py + 210, rw, 236, "THREAD TRANSLATION");
  drawHoloBraid(rx + 16, py + 252, rw - 32, 142);
  fill(126, 160, 170);
  textSize(9);
  textAlign(LEFT, TOP);
  text("The rectangle is the parameter loop. Fibers now ride the enclosed area directly; the side braid is a phase readout of that same transport.", rx + 16, py + 404, rw - 32, 42);
}

void drawPhiThreshold(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "PHI THRESHOLD CHAMBER");
  int mapW = min(w - 360, h - 80);
  int mx = x + 26;
  int my = y + 52;
  drawHeatmap(residual, mx, my, mapW, mapW, 1);
  drawResidualContours(mx, my, mapW, mapW);
  drawOrbitOverlay(mx, my, mapW, mapW);

  int rx = mx + mapW + 30;
  int rw = w - (rx - x) - 26;
  drawReadoutPanel(rx, my, rw, 168, "RESIDUAL EQUATION");
  metricLine(rx + 16, my + 38, "F mean", nf(phiResidualMean, 1, 5));
  metricLine(rx + 16, my + 60, "G local", nf(phiGain, 1, 5));
  metricLine(rx + 16, my + 82, "threshold", nf(phiThreshold, 1, 4));
  metricLine(rx + 16, my + 104, "source S", nf(sourcePressure, 1, 4));
  drawGauge(rx + 16, my + 130, rw - 32, "instability proximity", constrain(phiThreshold, 0, 1), color(255, 95, 112));

  drawReadoutPanel(rx, my + 188, rw, 184, "THRESHOLD GEOMETRY");
  drawThresholdGlyph(rx + 16, my + 222, rw - 32, 104);
  fill(126, 160, 170);
  textSize(9);
  text("Bright filaments are where the residual approaches the instability boundary. The orbit samples that geometry as a visual probe.", rx + 16, my + 334, rw - 32, 38);

  drawTracePanel(rx, my + 390, rw, h - 438);
}

void drawFloquetForge(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "FLOQUET HARMONIC FORGE");
  int leftX = x + 24;
  int topY = y + 52;
  int leftW = 350;
  int mainX = leftX + leftW + 22;
  int mainW = w - leftW - 70;
  int panelH = h - 82;

  drawReadoutPanel(leftX, topY, leftW, 286, "FLOQUET CORE");
  int cx = leftX + leftW / 2;
  int cy = topY + 154;
  float rad = min(leftW - 80, 190) * 0.43;
  drawFloquetRadial(cx, cy, rad);
  drawFloquetWave(leftX + 18, topY + 230, leftW - 36, 42);

  drawReadoutPanel(leftX, topY + 304, leftW, panelH - 304, "DRIVE COEFFICIENTS");
  for (int i = 0; i < floquetNu.length; i++) {
    drawGauge(leftX + 16, topY + 340 + i * 19, leftW - 32, "nu" + (i + 1), map(floquetNu[i], -0.45, 0.45, 0, 1), color(90 + i * 16, 210, 205));
  }
  metricLine(leftX + 16, topY + 502, "phase", nf((simT * (0.18 + quasiEnergy * 0.38)) % TWO_PI, 1, 4));
  metricLine(leftX + 16, topY + 524, "topology imprint", nf(metricBeltrami * metricCoherence, 1, 4));
  drawGauge(leftX + 16, topY + 552, leftW - 32, "lock proxy", constrain(floquetCoupling * 0.6 + metricCoherence * 0.4, 0, 1), color(255, 184, 84));

  drawReadoutPanel(mainX, topY, mainW, panelH, "SHAPER INFLUENCE");
  drawShaperInfluencePanel(mainX + 18, topY + 38, mainW - 36, panelH - 54);
}

void drawCTCObservatory(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "CTC WINDOW OBSERVATORY");
  int cx = x + (w - 320) / 2;
  int cy = y + h / 2;
  float r = min(w - 420, h - 130) * 0.34;
  drawCTCRings(cx, cy, r);
  int rx = x + w - 330;
  int rw = 300;
  drawReadoutPanel(rx, y + 52, rw, 244, "WINDOW CONDITIONS");
  drawGauge(rx + 16, y + 92, rw - 32, "threshold proximity", constrain(phiThreshold, 0, 1), color(255, 100, 110));
  drawGauge(rx + 16, y + 122, rw - 32, "orbit closure", orbitClosure, color(115, 220, 205));
  drawGauge(rx + 16, y + 152, rw - 32, "Lyapunov calm", 1.0 - constrain(metricLyap / 1.8, 0, 1), color(110, 170, 255));
  drawGauge(rx + 16, y + 182, rw - 32, "Floquet lock", floquetCoupling, color(255, 185, 85));
  drawGauge(rx + 16, y + 212, rw - 32, "CTC window", ctcScore, color(210, 130, 255));
  metricLine(rx + 16, y + 250, "zone", ctcScore > 0.72 ? "WINDOW PEAK" : ctcScore > 0.55 ? "WINDOW OPEN" : ctcScore > 0.38 ? "APPROACH" : "CLOSED");

  drawReadoutPanel(rx, y + 316, rw, 160, "CAUTION");
  fill(126, 160, 170);
  textSize(9);
  textAlign(LEFT, TOP);
  text("This lens is an analogical diagnostic: it visualizes closure, threshold, and phase-lock conditions. It is not a claim of physical CTC formation.", rx + 16, y + 354, rw - 32, 72);
}

void drawWignerStudio(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "WIGNER STUDIO");
  int plot = min(w - 360, h - 90);
  int px = x + 32;
  int py = y + 54;
  drawWignerPlot(px, py, plot, plot);
  int rx = px + plot + 32;
  int rw = w - (rx - x) - 28;
  drawReadoutPanel(rx, py, rw, 180, "MEASUREMENT ANALOG");
  drawGauge(rx + 16, py + 42, rw - 32, "position certainty", 1.0 - metricEntropy, color(120, 220, 170));
  drawGauge(rx + 16, py + 72, rw - 32, "phase variance", constrain(metricKL + quasiEnergy * 0.35, 0, 1), color(255, 170, 80));
  drawGauge(rx + 16, py + 102, rw - 32, "chirality", metricHelicity, color(170, 140, 255));
  drawGauge(rx + 16, py + 132, rw - 32, "negativity", wignerNegativity, color(255, 105, 128));

  drawReadoutPanel(rx, py + 204, rw, 220, "BORN WEIGHTS");
  drawBornBars(rx + 22, py + 250, rw - 44, 120);
  fill(126, 160, 170);
  textSize(9);
  text("Quadrants are sampled from field amplitude, chirality, and phase variance. The plot gives a visual phase-space analog.", rx + 16, py + 382, rw - 32, 42);
}

void drawShaperInfluencePanel(int x, int y, int w, int h) {
  drawButton(x, y, 118, 26, shaperEnabled ? "SHAPER ON" : "SHAPER OFF", shaperEnabled ? color(42, 98, 78) : color(52, 58, 66));
  drawButton(x + 130, y, 132, 26, shaperUseSender ? "SOURCE SENDER" : "SOURCE SIM", shaperUseSender ? color(66, 76, 104) : color(52, 70, 78));
  drawButton(x + 274, y, 64, 26, "MIX -", color(42, 57, 68));
  drawButton(x + 348, y, 64, 26, "MIX +", color(42, 57, 68));
  fill(118, 150, 160);
  textSize(9);
  textAlign(RIGHT, CENTER);
  text("mix " + nf(shaperMix, 1, 2) + "  " + shaperSourceStatus, x + w, y + 13);

  int streamY = y + 50;
  int cardW = (w - 28) / 3;
  drawShaperStreamCard(x, streamY, cardW, h - 90, "PLASMA", "solar wind / x-ray", shaperPlasma, solarWindStream, xrayFluxStream, color(255, 118, 92), 0);
  drawShaperStreamCard(x + cardW + 14, streamY, cardW, h - 90, "WATER", "ocean current / tide", shaperWater, oceanCurrentStream, tideStream, color(90, 190, 255), 1);
  drawShaperStreamCard(x + (cardW + 14) * 2, streamY, cardW, h - 90, "COSMIC", "torsion / deep phase", shaperCosmic, galacticTorsionStream, shaperDrive, color(180, 140, 255), 2);

  int by = y + h - 28;
  drawGauge(x, by, w, "combined shaper drive", shaperEnabled ? shaperDrive * shaperMix : 0, color(255, 184, 84));
}

void drawShaperStreamCard(int x, int y, int w, int h, String title, String subtitle, float value, float a, float b, color c, int mode) {
  fill(3, 7, 11);
  stroke(34, 60, 70);
  rect(x, y, w, h, 6);
  fill(red(c), green(c), blue(c), 210);
  textAlign(LEFT, TOP);
  textSize(11);
  text(title, x + 12, y + 10);
  fill(120, 150, 160);
  textSize(8);
  text(subtitle, x + 12, y + 27);
  drawShaperGlyph(x + 12, y + 48, w - 24, max(70, h - 116), value, c, mode);
  drawGauge(x + 12, y + h - 58, w - 24, "stream a", a, c);
  drawGauge(x + 12, y + h - 34, w - 24, "stream b", b, color(red(c) * 0.65 + 60, green(c) * 0.65 + 60, blue(c) * 0.65 + 60));
}

void drawShaperGlyph(int x, int y, int w, int h, float v, color c, int mode) {
  fill(5, 10, 16);
  stroke(28, 50, 62);
  rect(x, y, w, h, 5);
  noFill();
  if (mode == 0) {
    for (int lane = 0; lane < 12; lane++) {
      stroke(red(c), green(c), blue(c), 55 + lane * 10);
      beginShape();
      for (int i = 0; i <= 90; i++) {
        float u = i / 90.0;
        float yy = y + h * (0.18 + lane * 0.06) + sin(u * TWO_PI * (2.0 + v * 3.0) + lane + simT) * h * 0.08;
        vertex(x + u * w, yy);
      }
      endShape();
    }
  } else if (mode == 1) {
    for (int band = 0; band < 8; band++) {
      stroke(red(c), green(c), blue(c), 70 + band * 12);
      beginShape();
      for (int i = 0; i <= 120; i++) {
        float u = i / 120.0;
        float yy = y + h * (0.25 + band * 0.07) + sin(u * TWO_PI * 1.2 + simT * 0.7 + band) * h * (0.05 + v * 0.05);
        vertex(x + u * w, yy);
      }
      endShape();
    }
  } else {
    translate(0, 0);
    for (int ring = 0; ring < 6; ring++) {
      stroke(red(c), green(c), blue(c), 62 + ring * 18);
      float r = min(w, h) * (0.16 + ring * 0.055 + v * 0.025);
      ellipse(x + w * 0.5, y + h * 0.5, r * 2.0, r * (1.2 + 0.2 * sin(simT + ring)));
    }
    stroke(255, 190, 92, 145);
    line(x + w * 0.5, y + h * 0.18, x + w * 0.5 + sin(simT + v * TWO_PI) * w * 0.22, y + h * 0.82);
  }
}

void drawBranesFibers(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "BRANES / FIBERS");
  int cx = x + w / 2;
  int cy = y + h / 2 + 22;
  pushMatrix();
  translate(cx, cy, -120);
  rotateX(0.68);
  rotateY(-0.34);
  rotateZ(simT * 0.055);
  drawInteractingBraneSystem(min(w, h) * 0.46);
  popMatrix();

  int rx = x + 24;
  drawReadoutPanel(rx, y + 52, 286, 176, "FIBER STATE");
  metricLine(rx + 16, y + 90, "Beltrami", nf(metricBeltrami, 1, 4));
  metricLine(rx + 16, y + 112, "helicity", nf(metricHelicity, 1, 4));
  metricLine(rx + 16, y + 134, "brane twist", nf(braneTwist, 1, 4));
  metricLine(rx + 16, y + 156, "holonomy", nf(holoGamma, 1, 4));
  drawGauge(rx + 16, y + 188, 254, "thread tension", constrain(metricBeltrami * 0.5 + abs(holoGamma) * 0.24 + braneTwist * 0.26, 0, 1), color(120, 230, 210));
}

void drawTopologyLab(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "TOPOLOGY LAB");
  int rightW = 320;
  int gap = 18;
  int leftX = x + 24;
  int topY = y + 52;
  int leftW = w - rightW - gap - 48;
  int mainH = max(300, h - 252);
  int rightX = leftX + leftW + gap;

  float[] scores = new float[5];
  topologyScores(scores);
  int active = activeTopologyIndex(scores);
  float confidence = topologyConfidence(scores);

  drawReadoutPanel(leftX, topY, leftW, mainH, "EMERGENT TOPOLOGY CELL");
  drawTopologyPhaseCell(leftX + 16, topY + 40, leftW - 32, mainH - 58, scores, active, confidence);

  int bottomY = topY + mainH + 14;
  int bottomH = h - (bottomY - y) - 24;
  drawTopologySlices(leftX, bottomY, leftW, bottomH, scores);

  drawReadoutPanel(rightX, topY, rightW, 238, "ALPHA / DEPTH PHASE ATLAS");
  drawTopologyPhaseMap(rightX + 16, topY + 38, rightW - 32, 164);
  fill(132, 168, 176);
  textSize(9);
  textAlign(LEFT, TOP);
  text("active: " + topologyName(active), rightX + 16, topY + 208);
  textAlign(RIGHT, TOP);
  text("confidence " + nf(confidence, 1, 3), rightX + rightW - 16, topY + 208);

  drawReadoutPanel(rightX, topY + 256, rightW, 228, "STRUCTURE PROXIES");
  drawTopologyMetrics(rightX + 16, topY + 296, rightW - 32, scores, confidence);

  drawReadoutPanel(rightX, topY + 502, rightW, h - 554, "REFERENCE ARCHETYPES");
  drawTopologyReferences(rightX + 14, topY + 536, rightW - 28, h - 596, scores, active);
}

void drawSurfaceFoundry(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "SURFACE FOUNDRY");
  int rightW = 330;
  int px = x + 24;
  int py = y + 52;
  int previewW = w - rightW - 72;
  int previewH = h - 82;
  int rightX = px + previewW + 24;

  drawReadoutPanel(px, py, previewW, previewH, "PRINTABLE TOPOLOGY PREVIEW");
  drawFoundryPreview(px + 16, py + 40, previewW - 32, previewH - 58);

  drawReadoutPanel(rightX, py, rightW, 294, "SURFACE BUILD");
  drawFoundryControls(rightX + 16, py + 42, rightW - 32);

  drawReadoutPanel(rightX, py + 312, rightW, 210, "MESH OUTPUT");
  drawFoundryStats(rightX + 16, py + 350, rightW - 32);

  drawReadoutPanel(rightX, py + 540, rightW, max(120, h - 592), "STOCHASTIC CAD");
  drawStochasticCadPanel(rightX + 16, py + 578, rightW - 32, max(70, h - 634));
  hint(ENABLE_DEPTH_TEST);
}

void drawFoundryPreview(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 6);
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH && dcrtePreflightPanelOpen) {
    drawDcrtePreflightPanel(x, y, w, h);
    return;
  }
  pushMatrix();
  translate(x + w * 0.50, y + h * 0.52, -120);
  rotateX(0.82);
  rotateY(-0.55 + simT * 0.08);
  rotateZ(0.18);
  float previewScale = min(w, h) * 0.34;
  if (foundryMesh != null && foundryMesh.tris.size() > 0
      && !(dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
        && (!dcrteImportedShowMaterial || dcrteImportedStale))) {
    foundryMesh.drawPreview(previewScale / max(1.0, foundryScaleMM * 0.5));
  } else if (foundryGeometryIndex > 0) {
    drawFoundryWrappedGeometryPreview(previewScale);
  } else {
    float[] scores = new float[5];
    topologyScores(scores);
    int active = activeTopologyIndex(scores);
    float confidence = topologyConfidence(scores);
    drawTopologyManifoldMesh(scores, active, previewScale, 0.070 + (1.0 - confidence) * 0.045);
    drawTopologySkeleton(scores, active, previewScale);
    drawAnchoredTopologyFibers(scores, active, previewScale);
  }
  drawDcrtePrimitiveWireframe(previewScale);
  drawDcrteImportedDomainPreview(previewScale);
  popMatrix();
  hint(DISABLE_DEPTH_TEST);

  if (cadPreviewEnabled) drawStochasticCadPreview(x, y, w, h);
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) {
    drawDcrtePrimitivePanel(x + w - 306, y + 12, 294, 248);
    drawDcrteCenterSlice(x, y, w, h);
  } else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    int importedPanelW = min(370, max(330, w - 24));
    drawDcrteImportedPanel(x + w - importedPanelW - 12, y + 12, importedPanelW, 410);
    drawDcrteImportedSdfSlice(x, y, w, h);
  } else {
    drawDcrteDiagnosticsOverlay(x + w - 238, y + 12, 226, 88);
  }

  fill(132, 168, 176);
  textSize(9);
  textAlign(LEFT, BOTTOM);
  text(foundryMesh == null ? "live wrap preview: " + foundryGeometryName() : "generated STL mesh preview", x + 12, y + h - 12);
}

void drawStochasticCadPanel(int x, int y, int w, int h) {
  int topGap = 6;
  int topW = (w - topGap * 2) / 3;
  drawButton(x, y, topW, 22, cadPreviewEnabled ? "PREVIEW ON" : "PREVIEW OFF", cadPreviewEnabled ? color(55, 86, 72) : color(55, 55, 62));
  drawButton(x + topW + topGap, y, topW, 22, cadInternalLattice ? "LATTICE ON" : "LATTICE OFF", cadInternalLattice ? color(55, 86, 72) : color(55, 55, 62));
  drawButton(x + (topW + topGap) * 2, y, topW, 22, cadGraphicDrafting ? "GRAPHIC BW" : "TONAL", cadGraphicDrafting ? color(90, 82, 36) : color(42, 57, 68));

  int cellGap = 10;
  int cellW = (w - cellGap) / 2;
  int row1 = y + 31;
  int row2 = y + 69;
  drawCadStepper(x, row1, cellW, "STRIDE", str(cadInternalStride));
  drawCadStepper(x + cellW + cellGap, row1, cellW, "CULL", nf(cadEdgeCull, 1, 2));
  drawCadStepper(x, row2, cellW, "SHADE", nf(cadShadowThreshold, 1, 2));
  drawCadStepper(x + cellW + cellGap, row2, cellW, "RAND", nf(cadStochastic, 1, 2));
}

void drawCadStepper(int x, int y, int w, String label, String value) {
  fill(126, 160, 170);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  textAlign(RIGHT, TOP);
  text(value, x + w, y);
  int buttonY = y + 12;
  int buttonGap = 4;
  int buttonW = (w - buttonGap) / 2;
  drawButton(x, buttonY, buttonW, 20, "-", color(42, 57, 68));
  drawButton(x + buttonW + buttonGap, buttonY, buttonW, 20, "+", color(42, 57, 68));
}

void drawStochasticCadPreview(int x, int y, int w, int h) {
  int margin = 6;
  int pw = w - margin * 2;
  int ph = h - margin * 2;
  int px = x + margin;
  int py = y + margin;

  noFill();
  stroke(90, 220, 255, 22);
  strokeWeight(10.0);
  rect(px - 12, py - 12, pw + 24, ph + 24, 14);
  stroke(255, 96, 190, 34);
  strokeWeight(6.0);
  rect(px - 9, py - 9, pw + 18, ph + 18, 12);
  stroke(255, 244, 110, 74);
  strokeWeight(2.4);
  rect(px - 6, py - 6, pw + 12, ph + 12, 10);
  stroke(255, 238, 78, 82);
  strokeWeight(0.75);
  line(px + pw * 0.18, py + ph + 4, x + w * 0.40, y + h * 0.62);
  line(px + pw * 0.82, py + ph + 4, x + w * 0.60, y + h * 0.62);

  fill(255, 246, 130, 210);
  textSize(8);
  textAlign(LEFT, TOP);
  text("CAD LAYER", px + 8, py + 7);
  if (foundryCallSheetSolid == null) {
    fill(255, 246, 130, 180);
    text("generate mesh for voxel preview", px + 8, py + 23);
    return;
  }
  CallSheetBasis basis = callSheetBasis(45, 35.26438968);
  PVector center = new PVector();
  CallSheetBounds bounds = callSheetVoxelBounds(basis);
  float scale = callSheetScale(bounds, pw - 22, ph - 34) * 1.14;
  int drawX = px + 8;
  int drawY = py + 14;
  int drawW = pw - 16;
  int drawH = ph - 22;
  int oldStride = cadInternalStride;
  cadInternalStride = graphicCadStride();
  stroke(90, 220, 255, 45);
  strokeWeight(2.8);
  drawRasterVoxelEdgesForPanel(g, center, basis, bounds, drawX, drawY, drawW, drawH, scale, new HashSet<String>(), false, true);
  stroke(205, 112, 255, 96);
  strokeWeight(1.1);
  drawRasterVoxelEdgesForPanel(g, center, basis, bounds, drawX, drawY, drawW, drawH, scale, new HashSet<String>(), false, true);
  stroke(255, 248, 128, 138);
  strokeWeight(0.72);
  drawRasterVoxelEdgesForPanel(g, center, basis, bounds, drawX, drawY, drawW, drawH, scale, new HashSet<String>(), false, true);
  cadInternalStride = oldStride;
  if (foundryMesh != null && foundryMesh.tris.size() > 0) {
    PVector meshCenter = foundryMeshCenter();
    stroke(120, 255, 190, 124);
    strokeWeight(0.38);
    drawCallSheetRasterEdges(g, meshCenter, basis, bounds, drawX, drawY, drawW, drawH, scale, max(1, foundryMesh.tris.size() / 9000), true);
  }
  stroke(255, 210, 84, 230);
  strokeWeight(1.05);
  drawRasterVoxelEdgesForPanel(g, center, basis, bounds, drawX, drawY, drawW, drawH, scale, new HashSet<String>(), true, false);
  stroke(245, 255, 210, 190);
  strokeWeight(0.35);
  drawRasterVoxelEdgesForPanel(g, center, basis, bounds, drawX, drawY, drawW, drawH, scale, new HashSet<String>(), true, false);
}

int graphicCadStride() {
  return constrain(cadInternalStride, 2, 4);
}

float graphicResolutionBoost() {
  return constrain((48.0 - foundryActiveVolumeResolution()) / 24.0, 0, 1);
}

float graphicAdaptiveSpacing(float base) {
  return base * (1.0 - 0.28 * graphicResolutionBoost());
}

float graphicAdaptiveKeep(float base) {
  return constrain(base - 0.24 * graphicResolutionBoost(), 0.06, 0.96);
}

void drawFoundryControls(int x, int y, int w) {
  drawButton(x, y, 132, 26, "GENERATE MESH", color(45, 86, 72));
  drawButton(x + 142, y, 102, 26, "CALL SHEET", foundryMesh == null ? color(47, 68, 90) : color(62, 82, 96));
  drawButton(x + 252, y, 78, 26, "PULL SVG", foundryLastCallSheetBase.length() == 0 ? color(50, 52, 62) : color(86, 72, 38));
  drawButton(x, y + 30, 132, 22, "PIPE " + dcrtePipelineLabel(), dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT ? color(42, 57, 68) : color(65, 82, 55));
  drawButton(x + 142, y + 30, 102, 22, "EXPORT STL", foundryMesh == null ? color(42, 50, 58) : color(86, 66, 42));

  int yy = y + 62;
  drawButton(x, yy, 78, 22, "RES -", color(42, 57, 68));
  drawButton(x + 88, yy, 78, 22, "RES +", color(42, 57, 68));
  metricLine(x, yy + 32, "resolution", str(foundryActiveVolumeResolution()) + "^3");

  yy += 50;
  drawButton(x, yy, 78, 22, "BAND -", color(42, 57, 68));
  drawButton(x + 88, yy, 78, 22, "BAND +", color(42, 57, 68));
  metricLine(x, yy + 32, "iso band", nf(foundryIsoBand, 1, 3));

  yy += 50;
  drawButton(x, yy, 78, 22, "GEOM <", color(42, 57, 68));
  drawButton(x + 88, yy, 78, 22, "GEOM >", color(42, 57, 68));
  metricLine(x, yy + 32, "wrap geometry", shortText(foundryGeometryName(), 24));

  yy += 50;
  drawButton(x, yy, 112, 22, foundryRaisedVeins ? "VEINS ON" : "VEINS OFF", foundryRaisedVeins ? color(55, 86, 72) : color(55, 55, 62));
  metricLine(x, yy + 32, "vein radius", nf(foundryVeinRadiusMM, 1, 1) + " mm");
  metricLine(x, yy + 54, "scale", nf(foundryScaleMM, 1, 0) + " mm");
}

void drawDcrteDiagnosticsOverlay(int x, int y, int w, int h) {
  boolean testing = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_ADAPTER_TEST;
  color accent = testing
    ? (dcrteAdapterDiagnostics.passed() ? color(122, 230, 165) : color(255, 188, 92))
    : color(106, 145, 158);
  fill(3, 9, 13, 226);
  stroke(red(accent), green(accent), blue(accent), 190);
  strokeWeight(1.0);
  rect(x, y, w, h, 5);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(9);
  text("DCRTE-ET MILESTONE 0", x + 10, y + 8);
  fill(150, 184, 190);
  textSize(8);
  text("pipeline  " + dcrtePipelineMode.id(), x + 10, y + 25);
  text("engine    " + dcrteGenerationFieldEngineId(), x + 10, y + 38);
  if (testing) {
    text("adapter   " + dcrteAdapterDiagnostics.status + "  n=" + dcrteAdapterDiagnostics.sampleCount, x + 10, y + 51);
    text("error max " + nf(dcrteAdapterDiagnostics.maxAbsoluteError, 1, 8) + "  mean " + nf(dcrteAdapterDiagnostics.meanAbsoluteError, 1, 8), x + 10, y + 64);
  } else {
    text("adapter   idle; generation remains direct", x + 10, y + 51);
    text("selector  optional parity diagnostics", x + 10, y + 64);
  }
}

void drawFoundryStats(int x, int y, int w) {
  metricLine(x, y, "status", foundryStatus);
  metricLine(x, y + 24, "triangles", foundryMesh == null ? "0" : str(foundryMesh.tris.size()));
  metricLine(x, y + 48, "material", activeMaterial() == null ? "none" : shortText(activeMaterial().name, 20));
  metricLine(x, y + 72, "topology", topologyName(activeTopologyIndex(currentTopologyScores())));
  metricLine(x, y + 96, "geometry", shortText(foundryGeometryName(), 20));
  metricLine(x, y + 120, "raised veins", foundryRaisedVeinsApplied() ? "included" : (foundryRaisedVeins ? "suppressed" : "off"));
  metricLine(x, y + 144, "drawings", foundryCallSheetStatus);
  fill(100, 130, 145);
  textSize(8);
  textAlign(LEFT, TOP);
  String out = foundryLastCallSheet.length() > 0 ? foundryLastCallSheet : foundryLastExport;
  text(out.length() == 0 ? "No export yet." : out, x, y + 170, w, 28);
}

float[] currentTopologyScores() {
  float[] scores = new float[5];
  topologyScores(scores);
  return scores;
}

String foundryGeometryName() {
  foundryGeometryIndex = constrain(foundryGeometryIndex, 0, foundryGeometryNames.length - 1);
  return foundryGeometryNames[foundryGeometryIndex];
}

void cycleFoundryGeometry(int delta) {
  foundryGeometryIndex = (foundryGeometryIndex + delta + foundryGeometryNames.length) % foundryGeometryNames.length;
  markCurrentFoundryStale("field carrier changed; regenerate");
}

void generateSurfaceFoundryMesh() {
  float[] scores = currentTopologyScores();
  foundryMesh = new SurfaceMesh("rdft_surface_foundry_" + foundryGeometryName());
  boolean[][][] solid = new boolean[foundryResolution][foundryResolution][foundryResolution];
  for (int ix = 0; ix < foundryResolution; ix++) {
    float x = map(ix + 0.5, 0, foundryResolution, -1, 1);
    for (int iy = 0; iy < foundryResolution; iy++) {
      float y = map(iy + 0.5, 0, foundryResolution, -1, 1);
      for (int iz = 0; iz < foundryResolution; iz++) {
        float z = map(iz + 0.5, 0, foundryResolution, -1, 1);
        float crop = sqrt(x*x + y*y + z*z);
        float val = foundryScalar(x, y, z, scores);
        solid[ix][iy][iz] = abs(val) < foundryIsoBand && crop < 1.23;
      }
    }
  }
  if (foundryRaisedVeins) addRaisedVeinsToSolid(solid, scores);
  foundryBridgeVoxels = regularizeFoundrySolid(solid, 6);
  foundryCallSheetSolid = solid;

  for (int ix = 0; ix < foundryResolution; ix++) {
    for (int iy = 0; iy < foundryResolution; iy++) {
      for (int iz = 0; iz < foundryResolution; iz++) {
        if (!solid[ix][iy][iz]) continue;
        addVoxelBoundaryFaces(foundryMesh, solid, ix, iy, iz, foundryResolution);
      }
    }
  }

  int[] audit = foundryMesh.manifoldAudit();
  foundryBoundaryEdges = audit[0];
  foundryNonManifoldEdges = audit[1];
  foundryDegenerateFaces = audit[2];
  if (foundryBoundaryEdges == 0 && foundryNonManifoldEdges == 0 && foundryDegenerateFaces == 0) {
    foundryStatus = "watertight " + foundryMesh.tris.size() + " tris";
  } else {
    foundryStatus = "mesh blocked: open " + foundryBoundaryEdges + " nonman " + foundryNonManifoldEdges;
  }
  foundryMeshStale = false;
  foundryLastExport = "";
}

void markFoundryStale() {
  foundryCallSheetSolid = null;
  if (foundryMesh != null) {
    foundryMeshStale = true;
    foundryStatus = "settings changed; regenerate";
  }
}

boolean foundryMeshIsPrintable() {
  return foundryMesh != null && foundryMesh.tris.size() > 0
      && foundryBoundaryEdges == 0
      && foundryNonManifoldEdges == 0
      && foundryDegenerateFaces == 0;
}

void addVoxelBoundaryFaces(SurfaceMesh mesh, boolean[][][] solid, int ix, int iy, int iz, int n) {
  float x0 = foundryCoord(ix, n);
  float x1 = foundryCoord(ix + 1, n);
  float y0 = foundryCoord(iy, n);
  float y1 = foundryCoord(iy + 1, n);
  float z0 = foundryCoord(iz, n);
  float z1 = foundryCoord(iz + 1, n);
  if (!isSolid(solid, ix + 1, iy, iz, n)) mesh.addQuad(new PVector(x1, y0, z0), new PVector(x1, y1, z0), new PVector(x1, y1, z1), new PVector(x1, y0, z1));
  if (!isSolid(solid, ix - 1, iy, iz, n)) mesh.addQuad(new PVector(x0, y0, z0), new PVector(x0, y0, z1), new PVector(x0, y1, z1), new PVector(x0, y1, z0));
  if (!isSolid(solid, ix, iy + 1, iz, n)) mesh.addQuad(new PVector(x0, y1, z0), new PVector(x0, y1, z1), new PVector(x1, y1, z1), new PVector(x1, y1, z0));
  if (!isSolid(solid, ix, iy - 1, iz, n)) mesh.addQuad(new PVector(x0, y0, z0), new PVector(x1, y0, z0), new PVector(x1, y0, z1), new PVector(x0, y0, z1));
  if (!isSolid(solid, ix, iy, iz + 1, n)) mesh.addQuad(new PVector(x0, y0, z1), new PVector(x1, y0, z1), new PVector(x1, y1, z1), new PVector(x0, y1, z1));
  if (!isSolid(solid, ix, iy, iz - 1, n)) mesh.addQuad(new PVector(x0, y0, z0), new PVector(x0, y1, z0), new PVector(x1, y1, z0), new PVector(x1, y0, z0));
}

boolean isSolid(boolean[][][] solid, int ix, int iy, int iz, int n) {
  if (ix < 0 || iy < 0 || iz < 0 || ix >= n || iy >= n || iz >= n) return false;
  return solid[ix][iy][iz];
}

float foundryCoord(int idx, int n) {
  return map(idx, 0, n, -foundryScaleMM * 0.5, foundryScaleMM * 0.5);
}

void addRaisedVeinsToSolid(boolean[][][] solid, float[] scores) {
  PVector[] nodes = topologyNodes(1.0);
  int[][] pairs = {
    {0, 2}, {2, 1}, {1, 3}, {3, 0},
    {4, 0}, {4, 2}, {5, 1}, {5, 3}
  };
  int n = solid.length;
  float cell = foundryScaleMM / max(1.0f, n);
  float radius = foundryVeinRadiusMM + cell * 0.62f;
  for (int i = 0; i < pairs.length; i++) {
    PVector previousRaised = null;
    for (int s = 0; s <= 42; s++) {
      float t = s / 42.0;
      PVector base = topologyFiberPoint(nodes[pairs[i][0]], nodes[pairs[i][1]], scores, 1.0, i, t, 0);
      base.mult(foundryScaleMM * 0.5 * 0.92);
      PVector lift = base.copy();
      if (lift.mag() < 0.0001) lift = new PVector(0, 0, 1);
      lift.normalize();
      lift.mult(foundryVeinLiftMM + foundryVeinRadiusMM * 0.55);
      PVector raised = PVector.add(base, lift);
      rasterizeFoundrySegment(solid, base, raised, radius, cell);
      if (previousRaised != null) rasterizeFoundrySegment(solid, previousRaised, raised, radius, cell);
      previousRaised = raised;
    }
  }
}

void rasterizeFoundrySegment(boolean[][][] solid, PVector a, PVector b, float radius, float cell) {
  float distance = PVector.dist(a, b);
  int steps = max(1, ceil(distance / max(0.15f, cell * 0.42f)));
  for (int i = 0; i <= steps; i++) {
    float t = i / (float)steps;
    PVector sample = new PVector(lerp(a.x, b.x, t), lerp(a.y, b.y, t), lerp(a.z, b.z, t));
    rasterizeFoundrySphere(solid, sample, radius);
  }
}

void rasterizeFoundrySphere(boolean[][][] solid, PVector center, float radius) {
  int n = solid.length;
  float cell = foundryScaleMM / max(1.0f, n);
  int cx = floor(map(center.x, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f, 0, n));
  int cy = floor(map(center.y, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f, 0, n));
  int cz = floor(map(center.z, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f, 0, n));
  int reach = ceil(radius / cell) + 1;
  float radiusSq = radius * radius;
  for (int ix = max(0, cx - reach); ix <= min(n - 1, cx + reach); ix++) {
    for (int iy = max(0, cy - reach); iy <= min(n - 1, cy + reach); iy++) {
      for (int iz = max(0, cz - reach); iz <= min(n - 1, cz + reach); iz++) {
        float vx = map(ix + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f);
        float vy = map(iy + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f);
        float vz = map(iz + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f);
        float dx = vx - center.x;
        float dy = vy - center.y;
        float dz = vz - center.z;
        if (dx*dx + dy*dy + dz*dz <= radiusSq) solid[ix][iy][iz] = true;
      }
    }
  }
}

int regularizeFoundrySolid(boolean[][][] solid, int maxPasses) {
  int n = solid.length;
  int totalAdded = 0;
  for (int pass = 0; pass < maxPasses; pass++) {
    int added = 0;
    for (int ix = 0; ix < n; ix++) {
      for (int iy = 1; iy < n; iy++) {
        for (int iz = 1; iz < n; iz++) {
          added += resolveFoundryDiagonal(solid,
            ix, iy - 1, iz - 1, ix, iy, iz - 1,
            ix, iy, iz, ix, iy - 1, iz);
        }
      }
    }
    for (int iy = 0; iy < n; iy++) {
      for (int ix = 1; ix < n; ix++) {
        for (int iz = 1; iz < n; iz++) {
          added += resolveFoundryDiagonal(solid,
            ix - 1, iy, iz - 1, ix, iy, iz - 1,
            ix, iy, iz, ix - 1, iy, iz);
        }
      }
    }
    for (int iz = 0; iz < n; iz++) {
      for (int ix = 1; ix < n; ix++) {
        for (int iy = 1; iy < n; iy++) {
          added += resolveFoundryDiagonal(solid,
            ix - 1, iy - 1, iz, ix, iy - 1, iz,
            ix, iy, iz, ix - 1, iy, iz);
        }
      }
    }
    totalAdded += added;
    if (added == 0) break;
  }
  return totalAdded;
}

int resolveFoundryDiagonal(boolean[][][] solid,
  int ax, int ay, int az, int bx, int by, int bz,
  int cx, int cy, int cz, int dx, int dy, int dz) {
  boolean a = solid[ax][ay][az];
  boolean b = solid[bx][by][bz];
  boolean c = solid[cx][cy][cz];
  boolean d = solid[dx][dy][dz];
  if (a && c && !b && !d) {
    fillFoundryBridge(solid, bx, by, bz, dx, dy, dz);
    return 1;
  }
  if (b && d && !a && !c) {
    fillFoundryBridge(solid, ax, ay, az, cx, cy, cz);
    return 1;
  }
  return 0;
}

void fillFoundryBridge(boolean[][][] solid, int ax, int ay, int az, int bx, int by, int bz) {
  int scoreA = foundryFaceNeighborCount(solid, ax, ay, az);
  int scoreB = foundryFaceNeighborCount(solid, bx, by, bz);
  boolean chooseA = scoreA > scoreB || (scoreA == scoreB && ((ax + ay + az) & 1) == 0);
  if (chooseA) solid[ax][ay][az] = true;
  else solid[bx][by][bz] = true;
}

int foundryFaceNeighborCount(boolean[][][] solid, int x, int y, int z) {
  int n = solid.length;
  int count = 0;
  if (isSolid(solid, x + 1, y, z, n)) count++;
  if (isSolid(solid, x - 1, y, z, n)) count++;
  if (isSolid(solid, x, y + 1, z, n)) count++;
  if (isSolid(solid, x, y - 1, z, n)) count++;
  if (isSolid(solid, x, y, z + 1, n)) count++;
  if (isSolid(solid, x, y, z - 1, n)) count++;
  return count;
}

void exportSurfaceFoundryMesh() {
  if (!dcrtePrimitiveExportAllowed()) {
    foundryStatus = dcrteFoundryExportBlockMessage();
    return;
  }
  if (foundryMesh == null || foundryMesh.tris.size() == 0) {
    foundryStatus = "generate mesh first";
    return;
  }
  if (foundryMeshStale) {
    foundryStatus = "regenerate before export";
    return;
  }
  if (!foundryMeshIsPrintable()) {
    foundryStatus = "export blocked: mesh is not manifold";
    return;
  }
  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  String base = "exports/surface_foundry_" + stamp;
  foundryMesh.writeSTL(base + ".stl");
  writeFoundryMetadata(base + ".json");
  foundryLastExport = base + ".stl";
  foundryStatus = "exported STL";
}

void writeFoundryMetadata(String filename) {
  JSONObject meta = new JSONObject();
  float[] scores = currentTopologyScores();
  meta.setString("program", "Cosmosis Visual Observatory Surface Foundry");
  meta.setString("topology", topologyName(activeTopologyIndex(scores)));
  meta.setString("wrap_geometry", foundryGeometryName());
  meta.setFloat("wrap_blend", foundryGeometryIndex == 0 ? 0.0 : foundryWrapBlend);
  MaterialProfile activeMetaMaterial = activeMaterial();
  meta.setString("material_target", activeMetaMaterial == null ? "none" : safeString(activeMetaMaterial.name, "Unknown"));
  meta.setString("material_source_mode", activeMetaMaterial == null ? materialSourceLabel() : safeString(activeMetaMaterial.sourceMode, materialSourceLabel()));
  meta.setString("material_source", activeMetaMaterial == null ? "" : safeString(activeMetaMaterial.source, ""));
  meta.setString("material_source_id", activeMetaMaterial == null ? "" : safeString(activeMetaMaterial.sourceId, ""));
  meta.setString("material_confidence", activeMetaMaterial == null ? "" : safeString(activeMetaMaterial.confidence, ""));
  meta.setString("material_functional_tags", activeMetaMaterial == null ? "" : safeString(activeMetaMaterial.functionalTags, ""));
  meta.setFloat("material_phase_transform", activeMetaMaterial == null ? 0 : activeMetaMaterial.phaseTransform);
  meta.setFloat("material_topological_response", activeMetaMaterial == null ? 0 : activeMetaMaterial.topologicalResponse);
  meta.setFloat("material_superconducting_coherence", activeMetaMaterial == null ? 0 : activeMetaMaterial.superconductingCoherence);
  meta.setFloat("material_transition_temperature_k", activeMetaMaterial == null ? 0 : activeMetaMaterial.transitionTemperatureK);
  meta.setBoolean("mesh_watertight", foundryMeshIsPrintable());
  meta.setInt("mesh_boundary_edges", foundryBoundaryEdges);
  meta.setInt("mesh_non_manifold_edges", foundryNonManifoldEdges);
  meta.setInt("mesh_degenerate_faces", foundryDegenerateFaces);
  meta.setInt("mesh_bridge_voxels", foundryBridgeVoxels);
  meta.setInt("resolution", foundryActiveVolumeResolution());
  meta.setFloat("iso_band", foundryIsoBand);
  meta.setFloat("scale_mm", foundryScaleMM);
  meta.setBoolean("raised_transport_veins", foundryRaisedVeinsApplied());
  meta.setBoolean("raised_transport_veins_requested", foundryRaisedVeins);
  meta.setString("raised_transport_veins_policy", dcrteRaisedVeinsPolicy());
  meta.setFloat("vein_radius_mm", foundryVeinRadiusMM);
  meta.setFloat("vein_lift_mm", foundryVeinLiftMM);
  meta.setInt("triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
  meta.setFloat("alpha", alpha);
  meta.setInt("depth", depth);
  meta.setFloat("source", sourcePressure);
  meta.setFloat("floquet", floquetCoupling);
  meta.setFloat("quasi_energy", quasiEnergy);
  meta.setFloat("coherence", coherenceBias);
  meta.setFloat("brane_twist", braneTwist);
  meta.setFloat("deep_detail", deepDetail);
  meta.setFloat("recursion_falloff", recursionFalloff());
  meta.setBoolean("shaper_enabled", shaperEnabled);
  meta.setString("shaper_source", shaperSourceStatus);
  meta.setFloat("shaper_mix", shaperMix);
  meta.setFloat("solar_wind", solarWindStream);
  meta.setFloat("xray_flux", xrayFluxStream);
  meta.setFloat("ocean_current", oceanCurrentStream);
  meta.setFloat("tide", tideStream);
  meta.setFloat("galactic_torsion", galacticTorsionStream);
  JSONArray blend = new JSONArray();
  for (int i = 0; i < scores.length; i++) blend.setFloat(i, scores[i]);
  meta.setJSONArray("topology_blend", blend);
  appendDcrteMetadata(meta);
  saveJSONObject(meta, filename);
}

void generateFoundryCallSheets() {
  if (foundryMesh == null || foundryMesh.tris.size() == 0 || foundryMeshStale || foundryCallSheetSolid == null) {
    generateSelectedSurfaceFoundryMesh();
  }
  if (foundryMesh == null || foundryMesh.tris.size() == 0) {
    foundryCallSheetStatus = "mesh unavailable";
    foundryStatus = "call sheet failed";
    return;
  }
  if (!dcrtePrimitiveExportAllowed()) {
    foundryCallSheetStatus = "blocked by DCRTE validation";
    foundryStatus = "call sheet blocked";
    return;
  }
  if (!foundryMeshIsPrintable()) {
    foundryCallSheetStatus = "source mesh is not manifold";
    foundryStatus = "call sheet blocked: mesh audit failed";
    return;
  }

  ensureDir(sketchPath("call_sheet"));
  ensureDir(sketchPath("call_sheet/output"));
  ensureDir(sketchPath("call_sheet/configs"));

  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  foundryCallSheetGeneratedAt = nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  String base = "surface_foundry_call_sheet_" + stamp;
  String surfaceSvg = "call_sheet/output/" + base + "_surface_silhouette.svg";
  String surfacePng = "call_sheet/output/" + base + "_surface_silhouette.png";
  String latticeSvg = "call_sheet/output/" + base + "_voxel_lattice.svg";
  String latticePng = "call_sheet/output/" + base + "_voxel_lattice.png";
  String sourceStl = "call_sheet/output/" + base + "_source.stl";
  String reliefDefinedStl = "call_sheet/output/" + base + "_relief_defined.stl";
  String reliefDramaticStl = "call_sheet/output/" + base + "_relief_dramatic.stl";
  String reliefPreviewPng = "call_sheet/output/" + base + "_relief_preview.png";
  String reliefHeightPng = "call_sheet/output/" + base + "_relief_heightfield.png";
  String manifestJson = "call_sheet/configs/" + base + ".json";

  writeFoundryCallSheetPng(surfacePng, "surface_silhouette");
  writeFoundryCallSheetPng(latticePng, "voxel_lattice");
  foundryMesh.writeSTL(sourceStl);
  if (!writeFoundryReliefSuite(reliefDefinedStl, reliefDramaticStl, reliefPreviewPng, reliefHeightPng)) {
    foundryCallSheetStatus = "relief mesh audit failed";
    return;
  }
  writeFoundryCallSheetManifest(manifestJson, "", surfacePng, "", latticePng, sourceStl, reliefDefinedStl, reliefDramaticStl, reliefPreviewPng, reliefHeightPng);

  foundryLastCallSheetBase = base;
  foundryLastSurfacePng = surfacePng;
  foundryLastLatticePng = latticePng;
  foundryLastSurfaceSvg = surfaceSvg;
  foundryLastLatticeSvg = latticeSvg;
  foundryLastSourceStl = sourceStl;
  foundryLastReliefDefinedStl = reliefDefinedStl;
  foundryLastReliefDramaticStl = reliefDramaticStl;
  foundryLastReliefPreviewPng = reliefPreviewPng;
  foundryLastReliefHeightPng = reliefHeightPng;
  foundryLastManifestJson = manifestJson;
  foundryLastCallSheet = surfacePng + " / " + latticePng;
  foundryCallSheetStatus = "PNGs + audited STLs; SVG optional";
  foundryStatus = "watertight call sheet STLs generated";
}

void pullFoundryCallSheetSvgs() {
  if (foundryLastCallSheetBase.length() == 0 || foundryLastSurfacePng.length() == 0 || foundryLastLatticePng.length() == 0) {
    foundryCallSheetStatus = "make call sheet before SVG";
    foundryStatus = "call sheet first";
    return;
  }
  if (foundryMesh == null || foundryMesh.tris.size() == 0 || foundryMeshStale || foundryCallSheetSolid == null) {
    foundryCallSheetStatus = "regenerate call sheet before SVG";
    foundryStatus = "call sheet stale";
    return;
  }

  ensureDir(sketchPath("call_sheet"));
  ensureDir(sketchPath("call_sheet/output"));
  ensureDir(sketchPath("call_sheet/configs"));

  writeFoundryCallSheetSvg(foundryLastSurfaceSvg, "surface_silhouette");
  writeFoundryCallSheetSvg(foundryLastLatticeSvg, "voxel_lattice");
  writeFoundryCallSheetManifest(foundryLastManifestJson, foundryLastSurfaceSvg, foundryLastSurfacePng, foundryLastLatticeSvg, foundryLastLatticePng, foundryLastSourceStl, foundryLastReliefDefinedStl, foundryLastReliefDramaticStl, foundryLastReliefPreviewPng, foundryLastReliefHeightPng);

  foundryLastCallSheet = foundryLastSurfaceSvg + " / " + foundryLastLatticeSvg;
  foundryCallSheetStatus = "SVG pulled for active render mode";
  foundryStatus = "SVG call sheets generated";
}

boolean writeFoundryReliefSuite(String definedStl, String dramaticStl, String previewPng, String heightPng) {
  ReliefField field = buildFoundryReliefField();
  if (field == null) return false;
  writeFoundryReliefImage(field, heightPng, false);
  writeFoundryReliefImage(field, previewPng, true);
  SurfaceMesh defined = buildFoundryReliefMesh(field, "defined", 2.0f, 9.0f, 0.58f);
  SurfaceMesh dramatic = buildFoundryReliefMesh(field, "dramatic", 2.6f, 18.0f, 0.72f);
  int[] definedAudit = defined.manifoldAudit();
  int[] dramaticAudit = dramatic.manifoldAudit();
  if (definedAudit[0] != 0 || definedAudit[1] != 0 || definedAudit[2] != 0
      || dramaticAudit[0] != 0 || dramaticAudit[1] != 0 || dramaticAudit[2] != 0) {
    foundryStatus = "relief export blocked: mesh audit failed";
    return false;
  }
  defined.writeSTL(definedStl);
  dramatic.writeSTL(dramaticStl);
  return true;
}

ReliefField buildFoundryReliefField() {
  ReliefField meshField = buildFoundryMeshReliefField();
  if (meshField != null) return meshField;
  if (foundryCallSheetSolid == null) return null;
  int n = foundryActiveVolumeResolution();
  CallSheetBasis basis = callSheetBasis(45, 35.26438968);
  float minU = Float.MAX_VALUE;
  float maxU = -Float.MAX_VALUE;
  float minV = Float.MAX_VALUE;
  float maxV = -Float.MAX_VALUE;
  boolean any = false;
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        float[] b = reliefVoxelProjectionBounds(ix, iy, iz, n, basis);
        minU = min(minU, b[0]);
        maxU = max(maxU, b[1]);
        minV = min(minV, b[2]);
        maxV = max(maxV, b[3]);
        any = true;
      }
    }
  }
  if (!any || maxU <= minU || maxV <= minV) return null;

  int grid = (int)constrain(n * 2, 48, 160);
  float[][] front = new float[grid][grid];
  float[][] thickness = new float[grid][grid];
  boolean[][] mask = new boolean[grid][grid];
  for (int r = 0; r < grid; r++) {
    for (int c = 0; c < grid; c++) {
      front[r][c] = -Float.MAX_VALUE;
      thickness[r][c] = 0;
    }
  }

  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        float[] b = reliefVoxelProjectionBounds(ix, iy, iz, n, basis);
        int c0 = (int)constrain(floor(map(b[0], minU, maxU, 0, grid - 1)) - 1, 0, grid - 1);
        int c1 = (int)constrain(ceil(map(b[1], minU, maxU, 0, grid - 1)) + 1, 0, grid - 1);
        int r0 = (int)constrain(floor(map(b[3], maxV, minV, 0, grid - 1)) - 1, 0, grid - 1);
        int r1 = (int)constrain(ceil(map(b[2], maxV, minV, 0, grid - 1)) + 1, 0, grid - 1);
        for (int r = min(r0, r1); r <= max(r0, r1); r++) {
          for (int c = min(c0, c1); c <= max(c0, c1); c++) {
            float uCell = map(c + 0.5f, 0, grid - 1, minU, maxU);
            float vCell = map(r + 0.5f, 0, grid - 1, maxV, minV);
            if (uCell < b[0] || uCell > b[1] || vCell < b[2] || vCell > b[3]) continue;
            front[r][c] = max(front[r][c], b[4]);
            thickness[r][c] += 1.0;
            mask[r][c] = true;
          }
        }
      }
    }
  }

  boolean[][] projectedMask = mask;
  mask = reliefKeepLargestMask(reliefCloseMask(mask, 1));
  inpaintReliefProjection(front, thickness, projectedMask, mask, 5);

  return reliefFieldFromProjection(front, thickness, mask, grid);
}

PVector foundryVoxelCenter(int ix, int iy, int iz, int n) {
  return new PVector(
    map(ix + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f),
    map(iy + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f),
    map(iz + 0.5f, 0, n, -foundryScaleMM * 0.5f, foundryScaleMM * 0.5f)
  );
}

ReliefField buildFoundryMeshReliefField() {
  if (foundryMesh == null || foundryMesh.tris == null || foundryMesh.tris.size() == 0) return null;
  CallSheetBasis basis = callSheetBasis(45, 35.26438968);
  float minU = Float.MAX_VALUE;
  float maxU = -Float.MAX_VALUE;
  float minV = Float.MAX_VALUE;
  float maxV = -Float.MAX_VALUE;
  for (MeshTri t : foundryMesh.tris) {
    float[] a = reliefProjectPoint(t.a, basis);
    float[] b = reliefProjectPoint(t.b, basis);
    float[] c = reliefProjectPoint(t.c, basis);
    minU = min(minU, min(a[0], min(b[0], c[0])));
    maxU = max(maxU, max(a[0], max(b[0], c[0])));
    minV = min(minV, min(a[1], min(b[1], c[1])));
    maxV = max(maxV, max(a[1], max(b[1], c[1])));
  }
  if (maxU <= minU || maxV <= minV) return null;

  int grid = (int)constrain(max(202, foundryActiveVolumeResolution() * 3), 128, 220);
  float[][] front = new float[grid][grid];
  float[][] thickness = new float[grid][grid];
  boolean[][] mask = new boolean[grid][grid];
  for (int r = 0; r < grid; r++) {
    for (int c = 0; c < grid; c++) front[r][c] = -Float.MAX_VALUE;
  }

  for (MeshTri t : foundryMesh.tris) {
    float[] a = reliefProjectPoint(t.a, basis);
    float[] b = reliefProjectPoint(t.b, basis);
    float[] c = reliefProjectPoint(t.c, basis);
    rasterReliefTriangle(front, thickness, mask, a, b, c, minU, maxU, minV, maxV);
  }

  boolean[][] projectedMask = mask;
  mask = reliefKeepLargestMask(reliefCloseMask(mask, 1));
  inpaintReliefProjection(front, thickness, projectedMask, mask, 8);
  if (!reliefMaskAny(mask)) return null;
  return reliefFieldFromProjection(front, thickness, mask, grid);
}

float[] reliefProjectPoint(PVector p, CallSheetBasis basis) {
  return new float[] { p.dot(basis.horizontal), p.dot(basis.vertical), p.dot(basis.view) };
}

void rasterReliefTriangle(float[][] front, float[][] thickness, boolean[][] mask, float[] a, float[] b, float[] c, float minU, float maxU, float minV, float maxV) {
  int grid = front.length;
  float triMinU = min(a[0], min(b[0], c[0]));
  float triMaxU = max(a[0], max(b[0], c[0]));
  float triMinV = min(a[1], min(b[1], c[1]));
  float triMaxV = max(a[1], max(b[1], c[1]));
  int c0 = (int)constrain(floor(map(triMinU, minU, maxU, 0, grid - 1)) - 1, 0, grid - 1);
  int c1 = (int)constrain(ceil(map(triMaxU, minU, maxU, 0, grid - 1)) + 1, 0, grid - 1);
  int r0 = (int)constrain(floor(map(triMaxV, maxV, minV, 0, grid - 1)) - 1, 0, grid - 1);
  int r1 = (int)constrain(ceil(map(triMinV, maxV, minV, 0, grid - 1)) + 1, 0, grid - 1);
  float den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]);
  if (abs(den) < 0.000001) return;
  for (int r = min(r0, r1); r <= max(r0, r1); r++) {
    for (int col = min(c0, c1); col <= max(c0, c1); col++) {
      float u = map(col + 0.5f, 0, grid - 1, minU, maxU);
      float v = map(r + 0.5f, 0, grid - 1, maxV, minV);
      float wa = ((b[1] - c[1]) * (u - c[0]) + (c[0] - b[0]) * (v - c[1])) / den;
      float wb = ((c[1] - a[1]) * (u - c[0]) + (a[0] - c[0]) * (v - c[1])) / den;
      float wc = 1.0f - wa - wb;
      if (wa < -0.03f || wb < -0.03f || wc < -0.03f) continue;
      float d = wa * a[2] + wb * b[2] + wc * c[2];
      front[r][col] = max(front[r][col], d);
      thickness[r][col] += 1.0f;
      mask[r][col] = true;
    }
  }
}

ReliefField reliefFieldFromProjection(float[][] front, float[][] thickness, boolean[][] mask, int grid) {
  float[][] frontNorm = normalizeReliefArray(front, mask);
  float[][] thickNorm = normalizeReliefArray(thickness, mask);
  float[][] raw = new float[grid][grid];
  for (int r = 0; r < grid; r++) {
    for (int c = 0; c < grid; c++) {
      raw[r][c] = mask[r][c] ? 0.72f * frontNorm[r][c] + 0.28f * thickNorm[r][c] : 0;
    }
  }
  float[][] smooth = maskedReliefBlur(raw, mask, 1, 2);
  float[][] blur = maskedReliefBlur(smooth, mask, 2, 2);
  float[][] sharp = new float[grid][grid];
  float maxSharp = 0;
  for (int r = 0; r < grid; r++) {
    for (int c = 0; c < grid; c++) {
      if (!mask[r][c]) continue;
      sharp[r][c] = max(0, smooth[r][c] + 0.55f * (smooth[r][c] - blur[r][c]));
      maxSharp = max(maxSharp, sharp[r][c]);
    }
  }
  if (maxSharp > 0.0001) {
    for (int r = 0; r < grid; r++) {
      for (int c = 0; c < grid; c++) sharp[r][c] = mask[r][c] ? sharp[r][c] / maxSharp : 0;
    }
  }
  return new ReliefField(grid, grid, sharp, mask, 118.0f);
}

float[] reliefVoxelProjectionBounds(int ix, int iy, int iz, int n, CallSheetBasis basis) {
  float minU = Float.MAX_VALUE;
  float maxU = -Float.MAX_VALUE;
  float minV = Float.MAX_VALUE;
  float maxV = -Float.MAX_VALUE;
  float maxD = -Float.MAX_VALUE;
  for (int dx = 0; dx <= 1; dx++) {
    for (int dy = 0; dy <= 1; dy++) {
      for (int dz = 0; dz <= 1; dz++) {
        PVector p = new PVector(foundryCoord(ix + dx, n), foundryCoord(iy + dy, n), foundryCoord(iz + dz, n));
        float u = p.dot(basis.horizontal);
        float v = p.dot(basis.vertical);
        float d = p.dot(basis.view);
        minU = min(minU, u);
        maxU = max(maxU, u);
        minV = min(minV, v);
        maxV = max(maxV, v);
        maxD = max(maxD, d);
      }
    }
  }
  return new float[] { minU, maxU, minV, maxV, maxD };
}

boolean[][] reliefCloseMask(boolean[][] src, int radius) {
  return reliefErodeMask(reliefDilateMask(src, radius), radius);
}

boolean[][] reliefDilateMask(boolean[][] src, int radius) {
  int rows = src.length;
  int cols = src[0].length;
  boolean[][] out = new boolean[rows][cols];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!src[r][c]) continue;
      for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          int rr = r + dy;
          int cc = c + dx;
          if (rr >= 0 && rr < rows && cc >= 0 && cc < cols) out[rr][cc] = true;
        }
      }
    }
  }
  return out;
}

boolean[][] reliefErodeMask(boolean[][] src, int radius) {
  int rows = src.length;
  int cols = src[0].length;
  boolean[][] out = new boolean[rows][cols];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      boolean keep = src[r][c];
      for (int dy = -radius; dy <= radius && keep; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
          int rr = r + dy;
          int cc = c + dx;
          if (rr < 0 || rr >= rows || cc < 0 || cc >= cols || !src[rr][cc]) {
            keep = false;
            break;
          }
        }
      }
      out[r][c] = keep;
    }
  }
  return out;
}

boolean[][] reliefKeepLargestMask(boolean[][] src) {
  int rows = src.length;
  int cols = src[0].length;
  boolean[][] seen = new boolean[rows][cols];
  boolean[][] best = new boolean[rows][cols];
  int[] qr = new int[rows * cols];
  int[] qc = new int[rows * cols];
  int[] dr = { -1, 1, 0, 0 };
  int[] dc = { 0, 0, -1, 1 };
  int bestCount = 0;
  for (int sr = 0; sr < rows; sr++) {
    for (int sc = 0; sc < cols; sc++) {
      if (!src[sr][sc] || seen[sr][sc]) continue;
      int head = 0;
      int tail = 0;
      qr[tail] = sr;
      qc[tail] = sc;
      tail++;
      seen[sr][sc] = true;
      while (head < tail) {
        int r = qr[head];
        int c = qc[head];
        head++;
        for (int i = 0; i < 4; i++) {
          int rr = r + dr[i];
          int cc = c + dc[i];
          if (rr < 0 || rr >= rows || cc < 0 || cc >= cols || seen[rr][cc] || !src[rr][cc]) continue;
          seen[rr][cc] = true;
          qr[tail] = rr;
          qc[tail] = cc;
          tail++;
        }
      }
      if (tail > bestCount) {
        bestCount = tail;
        best = new boolean[rows][cols];
        for (int i = 0; i < tail; i++) best[qr[i]][qc[i]] = true;
      }
    }
  }
  return bestCount > 0 ? best : src;
}

boolean reliefMaskAny(boolean[][] mask) {
  for (int r = 0; r < mask.length; r++) {
    for (int c = 0; c < mask[0].length; c++) if (mask[r][c]) return true;
  }
  return false;
}

void inpaintReliefProjection(float[][] front, float[][] thickness, boolean[][] sourceMask, boolean[][] targetMask, int passes) {
  int rows = targetMask.length;
  int cols = targetMask[0].length;
  boolean[][] known = new boolean[rows][cols];
  for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) known[r][c] = sourceMask[r][c] && targetMask[r][c];
  for (int pass = 0; pass < passes; pass++) {
    boolean changed = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!targetMask[r][c] || known[r][c]) continue;
        float frontSum = 0;
        float thickSum = 0;
        float count = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            int rr = r + dy;
            int cc = c + dx;
            if (rr < 0 || rr >= rows || cc < 0 || cc >= cols || !known[rr][cc]) continue;
            frontSum += front[rr][cc];
            thickSum += thickness[rr][cc];
            count += 1.0f;
          }
        }
        if (count > 0) {
          front[r][c] = frontSum / count;
          thickness[r][c] = thickSum / count;
          known[r][c] = true;
          changed = true;
        }
      }
    }
    if (!changed) break;
  }
  float frontMean = 0;
  float thickMean = 0;
  float knownCount = 0;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!known[r][c]) continue;
      frontMean += front[r][c];
      thickMean += thickness[r][c];
      knownCount += 1.0f;
    }
  }
  if (knownCount > 0) {
    frontMean /= knownCount;
    thickMean /= knownCount;
  }
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (targetMask[r][c] && !known[r][c]) {
        front[r][c] = frontMean;
        thickness[r][c] = thickMean;
      }
    }
  }
}

float[][] normalizeReliefArray(float[][] src, boolean[][] mask) {
  int rows = src.length;
  int cols = src[0].length;
  float lo = Float.MAX_VALUE;
  float hi = -Float.MAX_VALUE;
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!mask[r][c]) continue;
      lo = min(lo, src[r][c]);
      hi = max(hi, src[r][c]);
    }
  }
  float[][] out = new float[rows][cols];
  if (hi <= lo) {
    for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) out[r][c] = mask[r][c] ? 1.0 : 0;
    return out;
  }
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) out[r][c] = mask[r][c] ? constrain((src[r][c] - lo) / (hi - lo), 0, 1) : 0;
  }
  return out;
}

float[][] maskedReliefBlur(float[][] src, boolean[][] mask, int radius, int passes) {
  int rows = src.length;
  int cols = src[0].length;
  float[][] a = src;
  for (int pass = 0; pass < passes; pass++) {
    float[][] b = new float[rows][cols];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!mask[r][c]) continue;
        float sum = 0;
        float count = 0;
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            int rr = r + dy;
            int cc = c + dx;
            if (rr < 0 || rr >= rows || cc < 0 || cc >= cols || !mask[rr][cc]) continue;
            sum += a[rr][cc];
            count += 1.0f;
          }
        }
        b[r][c] = count > 0 ? sum / count : a[r][c];
      }
    }
    a = b;
  }
  return a;
}

SurfaceMesh buildFoundryReliefMesh(ReliefField field, String variant, float baseMM, float reliefMM, float gamma) {
  SurfaceMesh mesh = new SurfaceMesh("surface_foundry_relief_" + variant);
  int rows = field.rows;
  int cols = field.cols;
  float cell = field.xySpanMM / max(rows, cols);
  float[][] variantField = reliefVariantField(field, variant);
  float[][] height = new float[rows][cols];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) height[r][c] = field.mask[r][c] ? baseMM + reliefMM * pow(constrain(variantField[r][c], 0, 1), gamma) : 0;
  }
  float[][] vh = reliefVertexHeights(height, field.mask);
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!field.mask[r][c]) continue;
      PVector p00 = reliefPoint(r, c, vh[r][c], rows, cols, cell);
      PVector p10 = reliefPoint(r, c + 1, vh[r][c + 1], rows, cols, cell);
      PVector p11 = reliefPoint(r + 1, c + 1, vh[r + 1][c + 1], rows, cols, cell);
      PVector p01 = reliefPoint(r + 1, c, vh[r + 1][c], rows, cols, cell);
      PVector b00 = reliefPoint(r, c, 0, rows, cols, cell);
      PVector b10 = reliefPoint(r, c + 1, 0, rows, cols, cell);
      PVector b11 = reliefPoint(r + 1, c + 1, 0, rows, cols, cell);
      PVector b01 = reliefPoint(r + 1, c, 0, rows, cols, cell);
      mesh.addTri(p00, p10, p11);
      mesh.addTri(p00, p11, p01);
      mesh.addTri(b11, b10, b00);
      mesh.addTri(b01, b11, b00);
      if (!reliefMaskAt(field.mask, r - 1, c)) mesh.addQuad(p10, p00, b00, b10);
      if (!reliefMaskAt(field.mask, r + 1, c)) mesh.addQuad(p01, p11, b11, b01);
      if (!reliefMaskAt(field.mask, r, c - 1)) mesh.addQuad(p00, p01, b01, b00);
      if (!reliefMaskAt(field.mask, r, c + 1)) mesh.addQuad(p11, p10, b10, b11);
    }
  }
  return mesh;
}

float[][] reliefVariantField(ReliefField field, String variant) {
  if (!variant.equals("dramatic")) return field.height;
  int rows = field.rows;
  int cols = field.cols;
  float[][] broad = maskedReliefBlur(field.height, field.mask, 4, 3);
  float[][] dome = reliefInteriorDepth(field.mask, 40);
  float[][] volume = new float[rows][cols];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!field.mask[r][c]) continue;
      volume[r][c] = 0.18f * field.height[r][c] + 0.47f * broad[r][c] + 0.35f * dome[r][c];
    }
  }
  return normalizeReliefArray(volume, field.mask);
}

float[][] reliefInteriorDepth(boolean[][] mask, int maxLayers) {
  int rows = mask.length;
  int cols = mask[0].length;
  boolean[][] layer = new boolean[rows][cols];
  float[][] depthField = new float[rows][cols];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) layer[r][c] = mask[r][c];
  }
  float deepest = 0;
  for (int level = 1; level <= maxLayers; level++) {
    boolean any = false;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!layer[r][c]) continue;
        depthField[r][c] = level;
        deepest = max(deepest, level);
        any = true;
      }
    }
    if (!any) break;
    layer = reliefErodeMask(layer, 1);
  }
  if (deepest > 0) {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) depthField[r][c] = mask[r][c] ? depthField[r][c] / deepest : 0;
    }
  }
  return depthField;
}

float[][] reliefVertexHeights(float[][] height, boolean[][] mask) {
  int rows = height.length;
  int cols = height[0].length;
  float[][] vh = new float[rows + 1][cols + 1];
  float[][] count = new float[rows + 1][cols + 1];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (!mask[r][c]) continue;
      vh[r][c] += height[r][c]; count[r][c] += 1;
      vh[r][c + 1] += height[r][c]; count[r][c + 1] += 1;
      vh[r + 1][c + 1] += height[r][c]; count[r + 1][c + 1] += 1;
      vh[r + 1][c] += height[r][c]; count[r + 1][c] += 1;
    }
  }
  for (int r = 0; r <= rows; r++) {
    for (int c = 0; c <= cols; c++) if (count[r][c] > 0) vh[r][c] /= count[r][c];
  }
  return vh;
}

PVector reliefPoint(int r, int c, float z, int rows, int cols, float cell) {
  return new PVector((c - cols * 0.5) * cell, (rows * 0.5 - r) * cell, z);
}

boolean reliefMaskAt(boolean[][] mask, int r, int c) {
  return r >= 0 && r < mask.length && c >= 0 && c < mask[0].length && mask[r][c];
}

void writeFoundryReliefImage(ReliefField field, String filename, boolean shaded) {
  int size = 900;
  PGraphics pg = createGraphics(size, size);
  pg.beginDraw();
  pg.background(255);
  pg.noStroke();
  float cell = size / (float)max(field.rows, field.cols);
  float ox = (size - field.cols * cell) * 0.5;
  float oy = (size - field.rows * cell) * 0.5;
  for (int r = 0; r < field.rows; r++) {
    for (int c = 0; c < field.cols; c++) {
      if (!field.mask[r][c]) continue;
      float v = field.height[r][c];
      if (shaded) {
        float gx = field.height[r][min(field.cols - 1, c + 1)] - field.height[r][max(0, c - 1)];
        float gy = field.height[min(field.rows - 1, r + 1)][c] - field.height[max(0, r - 1)][c];
        v = constrain(0.65 + v * 0.25 - gx * 0.55 - gy * 0.35, 0, 1);
      }
      pg.fill(shaded ? 245 - v * 210 : v * 255);
      pg.rect(ox + c * cell, oy + r * cell, cell + 0.6f, cell + 0.6f);
    }
  }
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(1.1);
  for (int r = 0; r < field.rows; r++) {
    for (int c = 0; c < field.cols; c++) {
      if (!field.mask[r][c]) continue;
      float x0 = ox + c * cell;
      float y0 = oy + r * cell;
      float x1 = x0 + cell;
      float y1 = y0 + cell;
      if (!reliefMaskAt(field.mask, r - 1, c)) pg.line(x0, y0, x1, y0);
      if (!reliefMaskAt(field.mask, r + 1, c)) pg.line(x0, y1, x1, y1);
      if (!reliefMaskAt(field.mask, r, c - 1)) pg.line(x0, y0, x0, y1);
      if (!reliefMaskAt(field.mask, r, c + 1)) pg.line(x1, y0, x1, y1);
    }
  }
  pg.endDraw();
  pg.save(filename);
}

void ensureDir(String path) {
  File dir = new File(path);
  if (!dir.exists()) dir.mkdirs();
}

void writeFoundryCallSheetPng(String filename, String style) {
  PGraphics pg = createGraphics(1700, 1100);
  pg.beginDraw();
  renderFoundryCallSheet(pg, style);
  pg.endDraw();
  pg.save(filename);
}

void renderFoundryCallSheet(PGraphics pg, String style) {
  pg.background(255);
  if (cadGraphicDrafting) pg.noSmooth();
  else pg.smooth(4);
  pg.textFont(createFont("Helvetica", 10));

  int outerX = 18;
  int outerY = 18;
  int outerW = 1664;
  int outerH = 1064;
  int smallX = 34;
  int smallY = 34;
  int cell = 306;
  int gap = 16;
  int rightX = 1004;
  int rightY = 34;
  int rightW = 644;
  int rightH = 950;
  int titleBlockY = 1000;

  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(2.0);
  pg.rect(outerX, outerY, outerW, outerH);

  for (int i = 0; i < 9; i++) {
    int col = i % 3;
    int row = i / 3;
    float az = i * 30.0;
    drawCallSheetRasterPanel(pg, smallX + col * (cell + gap), smallY + row * (cell + gap), cell, cell, az, 35.26438968, "ROTATION VIEW " + (i + 1), style, false);
  }

  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(1.25);
  pg.rect(rightX, rightY, rightW, rightH);
  drawCallSheetRasterHeader(pg, rightX + 18, rightY + 18, rightW - 36, style);
  drawCallSheetRasterPanel(pg, rightX + 30, rightY + 370, rightW - 60, rightH - 390, 45, 35.26438968, "LARGE STANDARD ISOMETRIC VIEW", style, true);
  drawCallSheetRasterTitleBlock(pg, smallX, titleBlockY, rightX + rightW - smallX, 72, style);
}

void drawCallSheetRasterPanel(PGraphics pg, int x, int y, int w, int h, float az, float el, String label, String style, boolean large) {
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(large ? 1.8 : 1.25);
  if (!large) pg.rect(x, y, w, h);
  if (!cadGraphicDrafting) {
    drawRasterPanelLabels(pg, x, y, w, h, az, el, label, large);
  }

  CallSheetBasis basis = callSheetBasis(az, el);
  PVector center = foundryMeshCenter();
  int stride = max(1, foundryMesh.tris.size() / (large ? 24000 : 5200));
  CallSheetBounds bounds = callSheetBounds(center, basis, stride);
  int pad = large ? 18 : 22;
  float scale = callSheetScale(bounds, w - pad * 2, h - (large ? 78 : 34));

  if (cadGraphicDrafting) {
    drawCallSheetRasterGraphicBW(pg, x, y, w, h, az, el, label, style, large, basis, center, bounds, scale, stride);
    return;
  }

  if (style.equals("surface_silhouette")) {
    pg.noStroke();
    pg.fill(0, large ? 42 : 34);
    for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
      MeshTri t = foundryMesh.tris.get(i);
      if (!callSheetShadowFace(t, basis)) continue;
      PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
      PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
      PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
      pg.triangle(a.x, a.y, b.x, b.y, c.x, c.y);
    }
    pg.stroke(0, 64);
    pg.strokeWeight(large ? 0.58 : 0.42);
    drawCallSheetRasterEdges(pg, center, basis, bounds, x, y, w, h, scale, stride * 2, false);
    pg.stroke(0, 220);
    pg.strokeWeight(large ? 1.15 : 0.86);
    drawCallSheetRasterEdges(pg, center, basis, bounds, x, y, w, h, scale, stride, true);
  } else {
    if (foundryCallSheetSolid == null) return;
    bounds = callSheetVoxelBounds(basis);
    scale = callSheetScale(bounds, w - pad * 2, h - (large ? 78 : 34));
    if (cadShadowThreshold > 0.05) drawRasterVoxelShadowFaces(pg, basis, bounds, x, y, w, h, scale, large);
    if (cadInternalLattice) {
      pg.stroke(0, large ? 128 : 102);
      pg.strokeWeight(large ? 0.34 : 0.26);
      drawRasterVoxelEdgesForPanel(pg, center, basis, bounds, x, y, w, h, scale, new HashSet<String>(), false, true);
    }
    pg.stroke(0, 232);
    pg.strokeWeight(large ? 0.82 : 0.54);
    drawRasterVoxelEdgesForPanel(pg, center, basis, bounds, x, y, w, h, scale, new HashSet<String>(), true, false);
  }
}

void drawRasterPanelLabels(PGraphics pg, int x, int y, int w, int h, float az, float el, String label, boolean large) {
  pg.fill(0);
  pg.textSize(large ? 9 : 7);
  pg.textAlign(LEFT, BOTTOM);
  pg.text(label, x + 6, y + h - 6);
  pg.textSize(large ? 8 : 6);
  pg.textAlign(RIGHT, BOTTOM);
  pg.text("AZ " + nf(az, 3, 0) + " / EL " + nf(el, 2, 2), x + w - 6, y + h - 6);
}

void drawCallSheetRasterGraphicBW(PGraphics pg, int x, int y, int w, int h, float az, float el, String label, String style, boolean large, CallSheetBasis basis, PVector center, CallSheetBounds bounds, float scale, int stride) {
  if (style.equals("voxel_lattice") && foundryCallSheetSolid != null) {
    bounds = callSheetVoxelBounds(basis);
    scale = callSheetScale(bounds, w - (large ? 36 : 44), h - (large ? 78 : 34));
    drawRasterVoxelGraphicBW(pg, basis, bounds, x, y, w, h, scale, large);
  } else {
    drawRasterSurfaceGraphicBW(pg, basis, center, bounds, x, y, w, h, scale, stride, large);
  }
  drawRasterPanelLabels(pg, x, y, w, h, az, el, label, large);
}

void drawRasterSurfaceGraphicBW(PGraphics pg, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  stride = max(1, stride);

  pg.noStroke();
  pg.fill(255);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (t.normal().dot(basis.view) <= 0) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    pg.triangle(a.x, a.y, b.x, b.y, c.x, c.y);
  }

  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    if (n.dot(basis.view) <= 0) continue;
    float brightness = n.dot(light);
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    PVector[] pts = {a, b, c};
    if (brightness < 0.10) {
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 5.6 : 4.2), 45, large ? 0.30 : 0.22);
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 4.6 : 3.5), -45, large ? 0.24 : 0.18);
    } else if (brightness < 0.22) {
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.28 : 0.20);
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 5.0 : 3.8), -45, large ? 0.24 : 0.18);
    } else if (brightness < 0.34) {
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.28 : 0.20);
    }
  }

  drawRasterSurfaceSpectralStipple(pg, basis, center, bounds, x, y, w, h, scale, stride, large, light);
  drawRasterSurfaceConnectiveBands(pg, basis, center, bounds, x, y, w, h, scale, stride, large);
  if (large) drawRasterLargeIsoSurfaceDepthField(pg, basis, center, bounds, x, y, w, h, scale, stride, light);
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(large ? 0.28 : 0.20);
  drawCallSheetRasterEdges(pg, center, basis, bounds, x, y, w, h, scale, max(1, stride * 7), false);
  pg.strokeWeight(large ? 1.0 : 0.58);
  drawCallSheetRasterEdges(pg, center, basis, bounds, x, y, w, h, scale, stride, true);
}

void drawRasterVoxelGraphicBW(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  drawRasterVoxelGraphicMask(pg, basis, bounds, x, y, w, h, scale);
  drawRasterVoxelGraphicShadows(pg, basis, bounds, x, y, w, h, scale, large);
  drawRasterVoxelDepthBands(pg, basis, bounds, x, y, w, h, scale, large);
  if (large) drawRasterLargeIsoVoxelDepthField(pg, basis, bounds, x, y, w, h, scale);
  if (cadInternalLattice) {
    pg.noFill();
    pg.stroke(0);
    pg.strokeWeight(large ? 0.30 : 0.22);
    int oldStride = cadInternalStride;
    cadInternalStride = graphicCadStride();
    drawRasterVoxelEdgesForPanel(pg, new PVector(), basis, bounds, x, y, w, h, scale, new HashSet<String>(), false, true);
    cadInternalStride = oldStride;
  }
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(large ? 0.58 : 0.48);
  drawRasterVoxelEdgesForPanel(pg, new PVector(), basis, bounds, x, y, w, h, scale, new HashSet<String>(), true, false);
  pg.strokeWeight(large ? 1.08 : 0.62);
  drawRasterVoxelDepthContours(pg, basis, bounds, x, y, w, h, scale, large);
}

void drawRasterVoxelGraphicMask(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale) {
  if (foundryCallSheetSolid == null) return;
  pg.noStroke();
  pg.fill(255);
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          if (normal.dot(basis.view) <= 0.04) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          pg.quad(pts[0].x, pts[0].y, pts[1].x, pts[1].y, pts[2].x, pts[2].y, pts[3].x, pts[3].y);
        }
      }
    }
  }
}

void drawRasterVoxelGraphicShadows(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          if (normal.dot(basis.view) <= 0.04) continue;
          float brightness = normal.dot(light);
          if (brightness >= 0.38) continue;
          float gate = hashUnit(ix * 19 + face * 31 + seed, iy * 23 + face * 7, iz * 29 + face * 11);
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          if (brightness < 0.16 && gate > graphicAdaptiveKeep(0.18)) {
            drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.26 : 0.18);
            drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 5.0 : 3.8), -45, large ? 0.22 : 0.16);
          } else if (brightness < 0.38 && gate > graphicAdaptiveKeep(0.46)) {
            drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.26 : 0.18);
          }
        }
      }
    }
  }
}

void drawRasterSurfaceConnectiveBands(PGraphics pg, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  if (foundryMesh == null) return;
  int bandStride = max(1, stride * (large ? 2 : 4));
  for (int i = 0; i < foundryMesh.tris.size(); i += bandStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float edge = abs(front);
    boolean connector = edge > 0.18 && edge < 0.82;
    if (!connector && !callSheetKeepGraphicSurfaceEdge(t, basis, i)) continue;
    float gate = hashUnit(i + seed * 5, round(edge * 2000.0), round(abs(n.x - n.y) * 1300.0));
    if (connector && gate < graphicAdaptiveKeep(large ? 0.34 : 0.58)) continue;
    if (!connector && gate < graphicAdaptiveKeep(large ? 0.52 : 0.72)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    PVector[] pts = {a, b, c};
    float angle = hatchAngleForNormal(n, basis);
    drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 7.0 : 5.2), angle, large ? 0.26 : 0.18);
    if (edge < 0.38 && gate > 0.72) {
      drawRasterHatchPolygon(pg, pts, graphicAdaptiveSpacing(large ? 5.8 : 4.4), angle + 82.0, large ? 0.20 : 0.15);
    }
  }
}

void drawRasterSurfaceSpectralStipple(PGraphics pg, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large, PVector light) {
  if (foundryMesh == null) return;
  float lowBoost = graphicResolutionBoost();
  int stippleStride = max(1, stride * (large ? 2 : 5));
  pg.noStroke();
  pg.fill(0);
  for (int i = 0; i < foundryMesh.tris.size(); i += stippleStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float brightness = n.dot(light);
    float edge = abs(front);
    float spectral = spectralStippleField(triCentroid(t), n);
    float shadowNeed = constrain((0.36 - brightness) * 1.25, 0, 1);
    float connectorNeed = constrain((0.54 - edge) * 0.95, 0, 1);
    float density = (shadowNeed * 0.48 + connectorNeed * 0.34 + lowBoost * 0.20) * (0.50 + spectral * 0.70);
    if (density < 0.10) continue;
    float gate = hashUnit(i + seed * 7, round(spectral * 4000.0), round((brightness + 1.0) * 1300.0));
    if (gate > density) continue;

    PVector p = triangleSamplePoint(t, i);
    PVector s = callSheetScreen(p, center, basis, bounds, x, y, w, h, scale);
    if (s.x < x + 8 || s.x > x + w - 8 || s.y < y + 8 || s.y > y + h - 26) continue;
    float baseR = (large ? 1.25 : 0.62) + (large ? 2.1 : 0.95) * density;
    int blobs = 1 + (density > 0.40 ? 1 : 0) + (large && density > 0.62 ? 1 : 0);
    for (int b = 0; b < blobs; b++) {
      float a = TWO_PI * hashUnit(i + b * 31 + seed, b * 17 + 5, round(spectral * 900.0));
      float d = (large ? 3.2 : 1.6) * b * (0.55 + 0.45 * spectral);
      float rr = baseR * (1.0 - b * 0.22) * (0.78 + 0.44 * hashUnit(i + b * 19, seed + b * 23, 71));
      pg.ellipse(s.x + cos(a) * d, s.y + sin(a) * d, rr * 2.0, rr * 2.0);
    }
  }
}

void drawRasterLargeIsoSurfaceDepthField(PGraphics pg, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, PVector light) {
  if (foundryMesh == null) return;
  float lowBoost = graphicResolutionBoost();
  int detailStride = max(1, stride);
  pg.noFill();
  for (int i = 0; i < foundryMesh.tris.size(); i += detailStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float brightness = n.dot(light);
    float edge = 1.0 - abs(front);
    float spectral = spectralStippleField(triCentroid(t), n);
    float density = constrain((0.50 - brightness) * 0.72 + edge * 0.34 + spectral * 0.18 + lowBoost * 0.16, 0, 1);
    if (density < 0.24) continue;
    float gate = hashUnit(i + seed * 13, round((brightness + 1.0) * 1700.0), round(spectral * 2100.0));
    if (gate > density) continue;
    PVector p = triangleSamplePoint(t, i + 117);
    PVector s = callSheetScreen(p, center, basis, bounds, x, y, w, h, scale);
    if (s.x < x + 8 || s.x > x + w - 8 || s.y < y + 8 || s.y > y + h - 26) continue;
    float angle = radians(hatchAngleForNormal(n, basis) + lerp(-18, 18, spectral));
    float len = 5.2 + density * 10.5 + lowBoost * 3.0;
    float dx = cos(angle) * len * 0.5;
    float dy = sin(angle) * len * 0.5;
    pg.stroke(0);
    pg.strokeWeight(0.30 + density * 0.18);
    pg.line(s.x - dx, s.y - dy, s.x + dx, s.y + dy);
    if (density > 0.56 && gate > 0.38) {
      float a2 = angle + radians(76.0);
      float l2 = len * 0.58;
      pg.strokeWeight(0.24);
      pg.line(s.x - cos(a2) * l2 * 0.5, s.y - sin(a2) * l2 * 0.5, s.x + cos(a2) * l2 * 0.5, s.y + sin(a2) * l2 * 0.5);
    }
    if (density > 0.68 && gate > 0.66) {
      float r = 0.85 + density * 1.25;
      pg.noStroke();
      pg.fill(0);
      pg.ellipse(s.x + cos(angle) * 2.2, s.y + sin(angle) * 2.2, r * 2.0, r * 2.0);
      pg.noFill();
    }
  }
}

PVector triCentroid(MeshTri t) {
  return new PVector((t.a.x + t.b.x + t.c.x) / 3.0, (t.a.y + t.b.y + t.c.y) / 3.0, (t.a.z + t.b.z + t.c.z) / 3.0);
}

PVector triangleSamplePoint(MeshTri t, int salt) {
  float u = hashUnit(salt + seed, 19, 37);
  float v = hashUnit(salt * 3 + seed, 43, 71);
  if (u + v > 1.0) {
    u = 1.0 - u;
    v = 1.0 - v;
  }
  PVector ab = PVector.sub(t.b, t.a);
  PVector ac = PVector.sub(t.c, t.a);
  PVector p = t.a.copy();
  p.add(PVector.mult(ab, u));
  p.add(PVector.mult(ac, v));
  return p;
}

float spectralStippleField(PVector p, PVector n) {
  float f1 = 1.25 + depth * 0.055;
  float f2 = 2.10 + alpha * 0.12;
  float f3 = 3.00 + deepDetail * 1.40;
  float a = sin((p.x * f1 + p.y * 0.55 + braneTwist) * PI);
  float b = cos((p.y * f2 - p.z * 0.70 + recursionFalloff()) * PI);
  float c = sin((p.z * f3 + p.x * 0.42 + n.z * 0.35 + holoGamma) * PI);
  return constrain(0.5 + 0.23 * a + 0.18 * b + 0.14 * c, 0, 1);
}

void drawRasterVoxelDepthBands(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.04) continue;
          float side = 1.0 - abs(front);
          if (side < 0.22 && !large) continue;
          float gate = hashUnit(ix * 41 + face * 13 + seed, iy * 37 + face * 17, iz * 43 + face * 19);
          float keep = graphicAdaptiveKeep(large ? 0.18 : 0.46);
          if (gate < keep && side < 0.58) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          float angle = hatchAngleForNormal(normal, basis);
          float spacing = graphicAdaptiveSpacing(side > 0.55 ? (large ? 7.0 : 5.4) : (large ? 9.0 : 6.8));
          drawRasterHatchPolygon(pg, pts, spacing, angle, large ? 0.24 : 0.17);
          if (side > 0.64 && gate > 0.62) {
            drawRasterHatchPolygon(pg, pts, spacing * 0.82, angle + 82.0, large ? 0.19 : 0.14);
          }
        }
      }
    }
  }
}

void drawRasterLargeIsoVoxelDepthField(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  float lowBoost = graphicResolutionBoost();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.04) continue;
          float brightness = normal.dot(light);
          float side = 1.0 - abs(front);
          float layer = (ix + iy + iz) / max(1.0, n * 3.0);
          float density = constrain((0.46 - brightness) * 0.74 + side * 0.38 + lowBoost * 0.20 + 0.10 * sin(layer * TWO_PI + braneTwist), 0, 1);
          if (density < 0.25) continue;
          float gate = hashUnit(ix * 67 + face * 13 + seed, iy * 61 + face * 17, iz * 71 + face * 19);
          if (gate > density) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          float angle = hatchAngleForNormal(normal, basis) + lerp(-14, 14, layer);
          float spacing = graphicAdaptiveSpacing(density > 0.62 ? 4.6 : 6.2);
          drawRasterHatchPolygon(pg, pts, spacing, angle, 0.26);
          if (density > 0.58) drawRasterHatchPolygon(pg, pts, spacing * 0.82, angle + 82.0, 0.20);
          if (density > 0.72 && gate > 0.54) {
            PVector c = new PVector();
            for (int j = 0; j < pts.length; j++) c.add(pts[j]);
            c.div(pts.length);
            pg.noStroke();
            pg.fill(0);
            float r = 1.15 + density * 1.35;
            pg.ellipse(c.x, c.y, r * 2.0, r * 2.0);
          }
        }
      }
    }
  }
}

void drawRasterVoxelDepthContours(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  float lowBoost = graphicResolutionBoost();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.03) continue;
          float side = 1.0 - abs(front);
          float gate = hashUnit(ix * 53 + face * 11 + seed, iy * 47 + face * 23, iz * 59 + face * 29);
          float sideCut = large ? 0.36 - lowBoost * 0.08 : 0.46 - lowBoost * 0.10;
          if (side < sideCut && gate < 0.82 - lowBoost * 0.18) continue;
          if (gate < (large ? 0.18 : 0.36) - lowBoost * 0.12) continue;
          drawRasterVoxelFaceContour(pg, basis, bounds, x, y, w, h, scale, ix, iy, iz, face);
        }
      }
    }
  }
}

void drawRasterVoxelFaceContour(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int ix, int iy, int iz, int face) {
  PVector[] pts = voxelFacePoints(ix, iy, iz, face);
  for (int i = 0; i < pts.length; i++) pts[i] = callSheetScreen(pts[i], new PVector(), basis, bounds, x, y, w, h, scale);
  for (int i = 0; i < pts.length; i++) {
    PVector a = pts[i];
    PVector b = pts[(i + 1) % pts.length];
    if (a.x < x - 4 && b.x < x - 4) continue;
    if (a.x > x + w + 4 && b.x > x + w + 4) continue;
    if (a.y < y - 4 && b.y < y - 4) continue;
    if (a.y > y + h - 18 && b.y > y + h - 18) continue;
    pg.line(a.x, a.y, b.x, b.y);
  }
}

float hatchAngleForNormal(PVector n, CallSheetBasis basis) {
  float hx = n.dot(basis.horizontal);
  float hy = -n.dot(basis.vertical);
  if (abs(hx) + abs(hy) < 0.001) return 45.0;
  return degrees(atan2(hy, hx)) + 90.0;
}

void drawRasterHatchPolygon(PGraphics pg, PVector[] pts, float spacing, float angleDeg, float weight) {
  if (pts == null || pts.length < 3) return;
  float a = radians(angleDeg);
  PVector dir = new PVector(cos(a), sin(a));
  PVector normal = new PVector(-sin(a), cos(a));
  float minK = Float.MAX_VALUE;
  float maxK = -Float.MAX_VALUE;
  for (int i = 0; i < pts.length; i++) {
    float k = pts[i].x * normal.x + pts[i].y * normal.y;
    minK = min(minK, k);
    maxK = max(maxK, k);
  }
  float[] xs = new float[12];
  float[] ys = new float[12];
  float[] ds = new float[12];
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(weight);
  spacing = max(1.0, spacing);
  for (float k = minK - spacing; k <= maxK + spacing; k += spacing) {
    int count = hatchIntersections(pts, normal, dir, k, xs, ys, ds);
    if (count < 2) continue;
    sortHatchIntersections(xs, ys, ds, count);
    for (int i = 0; i < count - 1; i += 2) {
      pg.line(xs[i], ys[i], xs[i + 1], ys[i + 1]);
    }
  }
}

int hatchIntersections(PVector[] pts, PVector normal, PVector dir, float k, float[] xs, float[] ys, float[] ds) {
  int count = 0;
  for (int i = 0; i < pts.length; i++) {
    PVector a = pts[i];
    PVector b = pts[(i + 1) % pts.length];
    float da = a.x * normal.x + a.y * normal.y - k;
    float db = b.x * normal.x + b.y * normal.y - k;
    if ((da < 0 && db < 0) || (da > 0 && db > 0)) continue;
    float denom = da - db;
    if (abs(denom) < 0.0001) continue;
    float t = constrain(da / denom, 0, 1);
    float x = lerp(a.x, b.x, t);
    float y = lerp(a.y, b.y, t);
    boolean duplicate = false;
    for (int j = 0; j < count; j++) {
      if (abs(xs[j] - x) < 0.02 && abs(ys[j] - y) < 0.02) duplicate = true;
    }
    if (duplicate || count >= xs.length) continue;
    xs[count] = x;
    ys[count] = y;
    ds[count] = x * dir.x + y * dir.y;
    count++;
  }
  return count;
}

void sortHatchIntersections(float[] xs, float[] ys, float[] ds, int count) {
  for (int i = 0; i < count - 1; i++) {
    for (int j = i + 1; j < count; j++) {
      if (ds[j] < ds[i]) {
        float tx = xs[i], ty = ys[i], td = ds[i];
        xs[i] = xs[j];
        ys[i] = ys[j];
        ds[i] = ds[j];
        xs[j] = tx;
        ys[j] = ty;
        ds[j] = td;
      }
    }
  }
}

void drawCallSheetRasterEdges(PGraphics pg, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean emphasize) {
  stride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (emphasize && !callSheetEmphasizedFace(t, basis)) continue;
    if (cadGraphicDrafting && emphasize && !callSheetKeepGraphicSurfaceEdge(t, basis, i)) continue;
    if (cadGraphicDrafting && !emphasize && !callSheetKeepGraphicSurfaceInterior(t, basis, i)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    pg.line(a.x, a.y, b.x, b.y);
    pg.line(b.x, b.y, c.x, c.y);
    pg.line(c.x, c.y, a.x, a.y);
  }
}

void drawRasterVoxelEdgesForPanel(PGraphics pg, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, boolean exposedEdges, boolean internalLattice) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        if (internalLattice) {
          if ((ix + iy + iz + seed) % max(1, cadInternalStride) != 0) continue;
          drawVoxelCubeEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, false);
        }
        if (exposedEdges) {
          if (!isSolid(foundryCallSheetSolid, ix + 1, iy, iz, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 0);
          if (!isSolid(foundryCallSheetSolid, ix - 1, iy, iz, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 1);
          if (!isSolid(foundryCallSheetSolid, ix, iy + 1, iz, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 2);
          if (!isSolid(foundryCallSheetSolid, ix, iy - 1, iz, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 3);
          if (!isSolid(foundryCallSheetSolid, ix, iy, iz + 1, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 4);
          if (!isSolid(foundryCallSheetSolid, ix, iy, iz - 1, n)) drawVoxelFaceEdges(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 5);
        }
      }
    }
  }
}

void drawVoxelCubeEdges(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ix, int iy, int iz, boolean exposed) {
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix + 1, iy, iz, exposed, 30);
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix, iy + 1, iz, exposed, 31);
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix, iy, iz + 1, exposed, 32);
}

void drawVoxelFaceEdges(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ix, int iy, int iz, int face) {
  if (cadGraphicDrafting && voxelFaceNormal(face).dot(basis.view) <= 0.02) return;
  int x0 = ix, x1 = ix + 1;
  int y0 = iy, y1 = iy + 1;
  int z0 = iz, z1 = iz + 1;
  if (face == 0) drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x1, y0, z0, x1, y1, z0, x1, y1, z1, x1, y0, z1, ix, iy, iz, face);
  else if (face == 1) drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, ix, iy, iz, face);
  else if (face == 2) drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x0, y1, z0, x0, y1, z1, x1, y1, z1, x1, y1, z0, ix, iy, iz, face);
  else if (face == 3) drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, ix, iy, iz, face);
  else if (face == 4) drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, ix, iy, iz, face);
  else drawVoxelFaceEdgeSet(pg, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x0, y1, z0, x1, y1, z0, x1, y0, z0, ix, iy, iz, face);
}

void drawVoxelFaceEdgeSet(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ax, int ay, int az, int bx, int by, int bz, int cx, int cy, int cz, int dx, int dy, int dz, int ix, int iy, int iz, int face) {
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, ax, ay, az, bx, by, bz, true, face);
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, bx, by, bz, cx, cy, cz, true, face + 10);
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, cx, cy, cz, dx, dy, dz, true, face + 20);
  drawVoxelGridEdge(pg, basis, bounds, x, y, w, h, scale, seen, dx, dy, dz, ax, ay, az, true, face + 30);
}

void drawVoxelGridEdge(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ax, int ay, int az, int bx, int by, int bz, boolean exposed, int salt) {
  String key = voxelEdgeKey(ax, ay, az, bx, by, bz);
  if (seen.contains(key)) return;
  seen.add(key);
  if (!callSheetKeepVoxelEdge(ax, ay, az, bx, by, bz, salt, exposed)) return;
  PVector a = callSheetScreen(voxelGridPoint(ax, ay, az), new PVector(), basis, bounds, x, y, w, h, scale);
  PVector b = callSheetScreen(voxelGridPoint(bx, by, bz), new PVector(), basis, bounds, x, y, w, h, scale);
  if (a.x < x - 4 && b.x < x - 4) return;
  if (a.x > x + w + 4 && b.x > x + w + 4) return;
  if (a.y < y - 4 && b.y < y - 4) return;
  if (a.y > y + h - 18 && b.y > y + h - 18) return;
  pg.line(a.x, a.y, b.x, b.y);
}

void drawRasterVoxelShadowFaces(PGraphics pg, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  pg.noStroke();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float brightness = normal.dot(light);
          if (brightness >= cadShadowThreshold) continue;
          if (!callSheetKeepVoxelEdge(ix, iy, iz, ix + face + 1, iy + face + 2, iz + face + 3, face + 90, true)) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          PVector a = callSheetScreen(pts[0], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector b = callSheetScreen(pts[1], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector c = callSheetScreen(pts[2], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector d = callSheetScreen(pts[3], new PVector(), basis, bounds, x, y, w, h, scale);
          pg.fill(0, large ? 58 : 36);
          pg.quad(a.x, a.y, b.x, b.y, c.x, c.y, d.x, d.y);
        }
      }
    }
  }
}

void drawCallSheetRasterVoxelMasses(PGraphics pg, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride) {
  pg.noStroke();
  stride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (!callSheetShadowFace(t, basis)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    float density = callSheetProjectedDensity(a, b, c);
    pg.fill(0, density > 8.0 ? 72 : 34);
    pg.triangle(a.x, a.y, b.x, b.y, c.x, c.y);
  }
}

void drawCallSheetRasterVoxelGlyphs(PGraphics pg, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  stride = max(1, stride);
  float cell = constrain(scale * foundryScaleMM / max(1.0, foundryActiveVolumeResolution()) * (large ? 0.34 : 0.26), large ? 2.8 : 1.8, large ? 7.0 : 4.2);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector centroid = new PVector((t.a.x + t.b.x + t.c.x) / 3.0, (t.a.y + t.b.y + t.c.y) / 3.0, (t.a.z + t.b.z + t.c.z) / 3.0);
    PVector p = callSheetScreen(centroid, center, basis, bounds, x, y, w, h, scale);
    if (p.x < x + 4 || p.x > x + w - 4 || p.y < y + 4 || p.y > y + h - 24) continue;
    boolean dark = callSheetShadowFace(t, basis) || abs(t.normal().dot(basis.view)) < 0.24;
    pg.stroke(0, dark ? 230 : 122);
    pg.strokeWeight(dark ? (large ? 0.72 : 0.56) : (large ? 0.42 : 0.34));
    drawRasterIsoCell(pg, p.x, p.y, cell);
  }
}

void drawRasterIsoCell(PGraphics pg, float cx, float cy, float s) {
  float ix = s * 0.86;
  float iy = s * 0.50;
  float drop = s * 0.78;
  pg.line(cx - ix, cy, cx, cy - iy);
  pg.line(cx, cy - iy, cx + ix, cy);
  pg.line(cx + ix, cy, cx, cy + iy);
  pg.line(cx, cy + iy, cx - ix, cy);
  pg.line(cx - ix, cy, cx - ix, cy + drop);
  pg.line(cx + ix, cy, cx + ix, cy + drop);
  pg.line(cx, cy + iy, cx, cy + iy + drop);
  pg.line(cx - ix, cy + drop, cx, cy + iy + drop);
  pg.line(cx + ix, cy + drop, cx, cy + iy + drop);
}

void drawCallSheetRasterNodes(PGraphics pg, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  pg.noStroke();
  pg.fill(0, 180);
  stride = max(1, stride);
  float r = large ? 1.7 : 1.15;
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    pg.ellipse(a.x, a.y, r, r);
  }
}

void drawCallSheetRasterHeader(PGraphics pg, int x, int y, int w, String style) {
  pg.fill(0);
  pg.textAlign(LEFT, TOP);
  pg.textSize(22);
  pg.text("SURFACE FOUNDRY - ISOMETRIC DRAWING CALL SHEET", x, y);
  pg.textSize(10.4);
  pg.text(shortText(callSheetDraftLabel(style), 102), x, y + 32);
  pg.textSize(11.0);
  pg.text("CONFIGURATION SNAPSHOT", x, y + 50);
  pg.textSize(8.8);
  String[] lines = callSheetWrappedConfigurationLines(style, 48);
  int split = (lines.length + 1) / 2;
  int gutter = 18;
  int columnW = (w - gutter) / 2;
  pg.stroke(0, 72);
  pg.strokeWeight(0.65);
  pg.line(x, y + 65, x + w, y + 65);
  pg.line(x + columnW + gutter / 2, y + 65, x + columnW + gutter / 2, y + 344);
  for (int i = 0; i < lines.length; i++) {
    int col = i / split;
    int row = i % split;
    pg.text(lines[i], x + col * (columnW + gutter), y + 71 + row * 10.4);
  }
}

void drawCallSheetRasterTitleBlock(PGraphics pg, int x, int y, int w, int h, String style) {
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(1.25);
  pg.rect(x, y, w, h);
  int[] cuts = {420, 735, 930, 1125};
  for (int i = 0; i < cuts.length; i++) {
    pg.line(x + cuts[i], y, x + cuts[i], y + h);
  }
  callSheetRasterDrawingCell(pg, x + 8, y + 10);
  callSheetRasterDrawnForCell(pg, x + 430, y + 10, 295, h - 16);
  callSheetRasterTitleCell(pg, x + 745, y + 10, "SCALE", "NTS");
  callSheetRasterTitleCell(pg, x + 940, y + 10, "SHEET", "D-001");
  callSheetRasterNotesCell(pg, x + 1135, y + 10, style);
}

void callSheetRasterTitleCell(PGraphics pg, int x, int y, String title, String body) {
  pg.fill(0);
  pg.textAlign(LEFT, TOP);
  pg.textSize(8.2);
  pg.text(title, x, y);
  pg.textSize(9.0);
  pg.text(body, x, y + 30);
}

void callSheetRasterDrawingCell(PGraphics pg, int x, int y) {
  pg.fill(0);
  pg.textAlign(LEFT, TOP);
  pg.textSize(8.2);
  pg.text("DRAWING", x, y);
  pg.textSize(9.0);
  pg.text("Surface Foundry STL - Isometric Call Sheet", x, y + 24);
  pg.textSize(7.2);
  pg.text("Generated: " + callSheetGeneratedLabel(), x, y + 42);
}

void callSheetRasterNotesCell(PGraphics pg, int x, int y, String style) {
  pg.fill(0);
  pg.textAlign(LEFT, TOP);
  pg.textSize(10.2);
  pg.text("NOTES", x, y);
  pg.textSize(9.0);
  String[] lines = callSheetSettingsLines(style);
  for (int i = 0; i < lines.length; i++) {
    pg.text(lines[i], x, y + 15 + i * 12);
  }
}

void callSheetRasterDrawnForCell(PGraphics pg, int x, int y, int w, int h) {
  pg.fill(0);
  pg.textAlign(LEFT, TOP);
  pg.textSize(8.2);
  pg.text("DRAWN FOR", x, y);
  pg.textSize(13.0);
  pg.text("[Brian Fahey]", x, y + 32);
  PImage logo = fieldworksLogoImage();
  int logoX = x + 142;
  int logoY = y + 2;
  int logoW = max(1, w - 150);
  int logoH = 48;
  if (logo != null) {
    float scale = min(logoW / (float)logo.width, logoH / (float)logo.height);
    int drawW = max(1, round(logo.width * scale));
    int drawH = max(1, round(logo.height * scale));
    pg.image(logo, logoX, logoY + max(0, (logoH - drawH) / 2), drawW, drawH);
  } else {
    pg.textSize(9.0);
    pg.text("Fieldworks MindLAB", logoX, logoY + 14);
  }
}

PImage fieldworksLogoImage() {
  if (!fieldworksLogoAttempted) {
    fieldworksLogoAttempted = true;
    fieldworksLogo = loadImage(FIELDWORKS_LOGO_FILE);
    if (fieldworksLogo == null) {
      fieldworksLogo = loadImage(sketchPath("data/" + FIELDWORKS_LOGO_FILE));
    }
  }
  return fieldworksLogo;
}

void writeFoundryCallSheetSvg(String filename, String style) {
  PrintWriter out = createWriter(filename);
  out.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
  out.println("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 1700 1100\" width=\"17in\" height=\"11in\">");
  out.println("<rect width=\"1700\" height=\"1100\" fill=\"#ffffff\"/>");

  int outerX = 18;
  int outerY = 18;
  int outerW = 1664;
  int outerH = 1064;
  int smallX = 34;
  int smallY = 34;
  int cell = 306;
  int gap = 16;
  int rightX = 1004;
  int rightY = 34;
  int rightW = 644;
  int rightH = 950;
  int titleBlockY = 1000;

  svgRect(out, outerX, outerY, outerW, outerH, "none", "#000000", 1.0, 2.0);
  for (int i = 0; i < 9; i++) {
    int col = i % 3;
    int row = i / 3;
    float az = i * 30.0;
    writeCallSheetSvgPanel(out, smallX + col * (cell + gap), smallY + row * (cell + gap), cell, cell, az, 35.26438968, "ROTATION VIEW " + (i + 1), style, false);
  }
  svgRect(out, rightX, rightY, rightW, rightH, "none", "#000000", 1.0, 1.25);
  writeCallSheetSvgHeader(out, rightX + 18, rightY + 18, rightW - 36, style);
  writeCallSheetSvgPanel(out, rightX + 30, rightY + 370, rightW - 60, rightH - 390, 45, 35.26438968, "LARGE STANDARD ISOMETRIC VIEW", style, true);
  writeCallSheetSvgTitleBlock(out, smallX, titleBlockY, rightX + rightW - smallX, 72, style);
  out.println("</svg>");
  out.flush();
  out.close();
}

void writeCallSheetSvgPanel(PrintWriter out, int x, int y, int w, int h, float az, float el, String label, String style, boolean large) {
  if (!large) svgRect(out, x, y, w, h, "none", "#000000", 1.0, 1.25);
  if (!cadGraphicDrafting) {
    writeCallSheetSvgPanelLabels(out, x, y, w, h, az, el, label, large);
  }
  CallSheetBasis basis = callSheetBasis(az, el);
  PVector center = foundryMeshCenter();
  int stride = max(1, foundryMesh.tris.size() / (large ? 24000 : 5200));
  CallSheetBounds bounds = callSheetBounds(center, basis, stride);
  int pad = large ? 18 : 22;
  float scale = callSheetScale(bounds, w - pad * 2, h - (large ? 78 : 34));

  if (cadGraphicDrafting) {
    writeCallSheetSvgGraphicBW(out, x, y, w, h, az, el, label, style, large, basis, center, bounds, scale, stride);
    return;
  }

  if (style.equals("surface_silhouette")) {
    for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
      MeshTri t = foundryMesh.tris.get(i);
      if (!callSheetShadowFace(t, basis)) continue;
      PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
      PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
      PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
      svgPolygon(out, a, b, c, "#000000", large ? 0.18 : 0.14, "none", 0.0, 0.0);
    }
    writeCallSheetSvgEdges(out, center, basis, bounds, x, y, w, h, scale, stride * 2, false, 0.25, large ? 0.58 : 0.42);
    writeCallSheetSvgEdges(out, center, basis, bounds, x, y, w, h, scale, stride, true, 0.86, large ? 1.15 : 0.86);
  } else {
    if (foundryCallSheetSolid == null) return;
    bounds = callSheetVoxelBounds(basis);
    scale = callSheetScale(bounds, w - pad * 2, h - (large ? 78 : 34));
    if (cadShadowThreshold > 0.05) writeSvgVoxelShadowFaces(out, basis, bounds, x, y, w, h, scale, large);
    if (cadInternalLattice) writeSvgVoxelEdgesForPanel(out, basis, bounds, x, y, w, h, scale, new HashSet<String>(), false, true, large ? 0.40 : 0.30, large ? 0.34 : 0.26);
    writeSvgVoxelEdgesForPanel(out, basis, bounds, x, y, w, h, scale, new HashSet<String>(), true, false, 0.92, large ? 0.82 : 0.54);
  }
}

void writeCallSheetSvgPanelLabels(PrintWriter out, int x, int y, int w, int h, float az, float el, String label, boolean large) {
  svgTextStyled(out, x + 6, y + h - 6, large ? 9 : 7, label, "700", "start", "auto");
  svgTextStyled(out, x + w - 6, y + h - 6, large ? 8 : 6, "AZ " + nf(az, 3, 0) + " / EL " + nf(el, 2, 2), "400", "end", "auto");
}

void writeCallSheetSvgGraphicBW(PrintWriter out, int x, int y, int w, int h, float az, float el, String label, String style, boolean large, CallSheetBasis basis, PVector center, CallSheetBounds bounds, float scale, int stride) {
  if (style.equals("voxel_lattice") && foundryCallSheetSolid != null) {
    bounds = callSheetVoxelBounds(basis);
    scale = callSheetScale(bounds, w - (large ? 36 : 44), h - (large ? 78 : 34));
    writeSvgVoxelGraphicBW(out, basis, bounds, x, y, w, h, scale, large);
  } else {
    writeSvgSurfaceGraphicBW(out, basis, center, bounds, x, y, w, h, scale, stride, large);
  }
  writeCallSheetSvgPanelLabels(out, x, y, w, h, az, el, label, large);
}

void writeSvgSurfaceGraphicBW(PrintWriter out, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  stride = max(1, stride);

  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (t.normal().dot(basis.view) <= 0) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    svgPolygon(out, a, b, c, "#ffffff", 1.0, "none", 0.0, 0.0);
  }

  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    if (n.dot(basis.view) <= 0) continue;
    float brightness = n.dot(light);
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    PVector[] pts = {a, b, c};
    if (brightness < 0.10) {
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 5.6 : 4.2), 45, large ? 0.30 : 0.22);
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 4.6 : 3.5), -45, large ? 0.24 : 0.18);
    } else if (brightness < 0.22) {
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.28 : 0.20);
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 5.0 : 3.8), -45, large ? 0.24 : 0.18);
    } else if (brightness < 0.34) {
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.28 : 0.20);
    }
  }

  writeSvgSurfaceSpectralStipple(out, basis, center, bounds, x, y, w, h, scale, stride, large, light);
  writeSvgSurfaceConnectiveBands(out, basis, center, bounds, x, y, w, h, scale, stride, large);
  if (large) writeSvgLargeIsoSurfaceDepthField(out, basis, center, bounds, x, y, w, h, scale, stride, light);
  writeCallSheetSvgEdges(out, center, basis, bounds, x, y, w, h, scale, max(1, stride * 7), false, 1.0, large ? 0.28 : 0.20);
  writeCallSheetSvgEdges(out, center, basis, bounds, x, y, w, h, scale, stride, true, 1.0, large ? 1.0 : 0.58);
}

void writeSvgVoxelGraphicBW(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  writeSvgVoxelGraphicMask(out, basis, bounds, x, y, w, h, scale);
  writeSvgVoxelGraphicShadows(out, basis, bounds, x, y, w, h, scale, large);
  writeSvgVoxelDepthBands(out, basis, bounds, x, y, w, h, scale, large);
  if (large) writeSvgLargeIsoVoxelDepthField(out, basis, bounds, x, y, w, h, scale);
  if (cadInternalLattice) {
    int oldStride = cadInternalStride;
    cadInternalStride = graphicCadStride();
    writeSvgVoxelEdgesForPanel(out, basis, bounds, x, y, w, h, scale, new HashSet<String>(), false, true, 1.0, large ? 0.30 : 0.22);
    cadInternalStride = oldStride;
  }
  writeSvgVoxelEdgesForPanel(out, basis, bounds, x, y, w, h, scale, new HashSet<String>(), true, false, 1.0, large ? 0.58 : 0.48);
  writeSvgVoxelDepthContours(out, basis, bounds, x, y, w, h, scale, large);
}

void writeSvgVoxelGraphicMask(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          if (normal.dot(basis.view) <= 0.04) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          svgPolygonPts(out, pts, "#ffffff", 1.0, "none", 0.0, 0.0);
        }
      }
    }
  }
}

void writeSvgVoxelGraphicShadows(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          if (normal.dot(basis.view) <= 0.04) continue;
          float brightness = normal.dot(light);
          if (brightness >= 0.38) continue;
          float gate = hashUnit(ix * 19 + face * 31 + seed, iy * 23 + face * 7, iz * 29 + face * 11);
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          if (brightness < 0.16 && gate > graphicAdaptiveKeep(0.18)) {
            writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.26 : 0.18);
            writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 5.0 : 3.8), -45, large ? 0.22 : 0.16);
          } else if (brightness < 0.38 && gate > graphicAdaptiveKeep(0.46)) {
            writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 6.0 : 4.6), 45, large ? 0.26 : 0.18);
          }
        }
      }
    }
  }
}

void writeSvgSurfaceConnectiveBands(PrintWriter out, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  if (foundryMesh == null) return;
  int bandStride = max(1, stride * (large ? 2 : 4));
  for (int i = 0; i < foundryMesh.tris.size(); i += bandStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float edge = abs(front);
    boolean connector = edge > 0.18 && edge < 0.82;
    if (!connector && !callSheetKeepGraphicSurfaceEdge(t, basis, i)) continue;
    float gate = hashUnit(i + seed * 5, round(edge * 2000.0), round(abs(n.x - n.y) * 1300.0));
    if (connector && gate < graphicAdaptiveKeep(large ? 0.34 : 0.58)) continue;
    if (!connector && gate < graphicAdaptiveKeep(large ? 0.52 : 0.72)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    PVector[] pts = {a, b, c};
    float angle = hatchAngleForNormal(n, basis);
    writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 7.0 : 5.2), angle, large ? 0.26 : 0.18);
    if (edge < 0.38 && gate > 0.72) {
      writeSvgHatchPolygon(out, pts, graphicAdaptiveSpacing(large ? 5.8 : 4.4), angle + 82.0, large ? 0.20 : 0.15);
    }
  }
}

void writeSvgSurfaceSpectralStipple(PrintWriter out, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large, PVector light) {
  if (foundryMesh == null) return;
  float lowBoost = graphicResolutionBoost();
  int stippleStride = max(1, stride * (large ? 2 : 5));
  for (int i = 0; i < foundryMesh.tris.size(); i += stippleStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float brightness = n.dot(light);
    float edge = abs(front);
    float spectral = spectralStippleField(triCentroid(t), n);
    float shadowNeed = constrain((0.36 - brightness) * 1.25, 0, 1);
    float connectorNeed = constrain((0.54 - edge) * 0.95, 0, 1);
    float density = (shadowNeed * 0.48 + connectorNeed * 0.34 + lowBoost * 0.20) * (0.50 + spectral * 0.70);
    if (density < 0.10) continue;
    float gate = hashUnit(i + seed * 7, round(spectral * 4000.0), round((brightness + 1.0) * 1300.0));
    if (gate > density) continue;

    PVector p = triangleSamplePoint(t, i);
    PVector s = callSheetScreen(p, center, basis, bounds, x, y, w, h, scale);
    if (s.x < x + 8 || s.x > x + w - 8 || s.y < y + 8 || s.y > y + h - 26) continue;
    float baseR = (large ? 1.25 : 0.62) + (large ? 2.1 : 0.95) * density;
    int blobs = 1 + (density > 0.40 ? 1 : 0) + (large && density > 0.62 ? 1 : 0);
    for (int b = 0; b < blobs; b++) {
      float a = TWO_PI * hashUnit(i + b * 31 + seed, b * 17 + 5, round(spectral * 900.0));
      float d = (large ? 3.2 : 1.6) * b * (0.55 + 0.45 * spectral);
      float rr = baseR * (1.0 - b * 0.22) * (0.78 + 0.44 * hashUnit(i + b * 19, seed + b * 23, 71));
      svgCircle(out, s.x + cos(a) * d, s.y + sin(a) * d, rr);
    }
  }
}

void writeSvgLargeIsoSurfaceDepthField(PrintWriter out, CallSheetBasis basis, PVector center, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, PVector light) {
  if (foundryMesh == null) return;
  float lowBoost = graphicResolutionBoost();
  int detailStride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += detailStride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector n = t.normal();
    float front = n.dot(basis.view);
    if (front <= 0.02) continue;
    float brightness = n.dot(light);
    float edge = 1.0 - abs(front);
    float spectral = spectralStippleField(triCentroid(t), n);
    float density = constrain((0.50 - brightness) * 0.72 + edge * 0.34 + spectral * 0.18 + lowBoost * 0.16, 0, 1);
    if (density < 0.24) continue;
    float gate = hashUnit(i + seed * 13, round((brightness + 1.0) * 1700.0), round(spectral * 2100.0));
    if (gate > density) continue;
    PVector p = triangleSamplePoint(t, i + 117);
    PVector s = callSheetScreen(p, center, basis, bounds, x, y, w, h, scale);
    if (s.x < x + 8 || s.x > x + w - 8 || s.y < y + 8 || s.y > y + h - 26) continue;
    float angle = radians(hatchAngleForNormal(n, basis) + lerp(-18, 18, spectral));
    float len = 5.2 + density * 10.5 + lowBoost * 3.0;
    float dx = cos(angle) * len * 0.5;
    float dy = sin(angle) * len * 0.5;
    svgLine(out, s.x - dx, s.y - dy, s.x + dx, s.y + dy, 1.0, 0.30 + density * 0.18);
    if (density > 0.56 && gate > 0.38) {
      float a2 = angle + radians(76.0);
      float l2 = len * 0.58;
      svgLine(out, s.x - cos(a2) * l2 * 0.5, s.y - sin(a2) * l2 * 0.5, s.x + cos(a2) * l2 * 0.5, s.y + sin(a2) * l2 * 0.5, 1.0, 0.24);
    }
    if (density > 0.68 && gate > 0.66) {
      svgCircle(out, s.x + cos(angle) * 2.2, s.y + sin(angle) * 2.2, 0.85 + density * 1.25);
    }
  }
}

void writeSvgVoxelDepthBands(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.04) continue;
          float side = 1.0 - abs(front);
          if (side < 0.22 && !large) continue;
          float gate = hashUnit(ix * 41 + face * 13 + seed, iy * 37 + face * 17, iz * 43 + face * 19);
          float keep = graphicAdaptiveKeep(large ? 0.18 : 0.46);
          if (gate < keep && side < 0.58) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          float angle = hatchAngleForNormal(normal, basis);
          float spacing = graphicAdaptiveSpacing(side > 0.55 ? (large ? 7.0 : 5.4) : (large ? 9.0 : 6.8));
          writeSvgHatchPolygon(out, pts, spacing, angle, large ? 0.24 : 0.17);
          if (side > 0.64 && gate > 0.62) {
            writeSvgHatchPolygon(out, pts, spacing * 0.82, angle + 82.0, large ? 0.19 : 0.14);
          }
        }
      }
    }
  }
}

void writeSvgLargeIsoVoxelDepthField(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  float lowBoost = graphicResolutionBoost();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.04) continue;
          float brightness = normal.dot(light);
          float side = 1.0 - abs(front);
          float layer = (ix + iy + iz) / max(1.0, n * 3.0);
          float density = constrain((0.46 - brightness) * 0.74 + side * 0.38 + lowBoost * 0.20 + 0.10 * sin(layer * TWO_PI + braneTwist), 0, 1);
          if (density < 0.25) continue;
          float gate = hashUnit(ix * 67 + face * 13 + seed, iy * 61 + face * 17, iz * 71 + face * 19);
          if (gate > density) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          for (int j = 0; j < pts.length; j++) pts[j] = callSheetScreen(pts[j], new PVector(), basis, bounds, x, y, w, h, scale);
          float angle = hatchAngleForNormal(normal, basis) + lerp(-14, 14, layer);
          float spacing = graphicAdaptiveSpacing(density > 0.62 ? 4.6 : 6.2);
          writeSvgHatchPolygon(out, pts, spacing, angle, 0.26);
          if (density > 0.58) writeSvgHatchPolygon(out, pts, spacing * 0.82, angle + 82.0, 0.20);
          if (density > 0.72 && gate > 0.54) {
            PVector c = new PVector();
            for (int j = 0; j < pts.length; j++) c.add(pts[j]);
            c.div(pts.length);
            svgCircle(out, c.x, c.y, 1.15 + density * 1.35);
          }
        }
      }
    }
  }
}

void writeSvgVoxelDepthContours(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  float lowBoost = graphicResolutionBoost();
  float weight = large ? 1.08 : 0.62;
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          PVector normal = voxelFaceNormal(face);
          float front = normal.dot(basis.view);
          if (front <= 0.03) continue;
          float side = 1.0 - abs(front);
          float gate = hashUnit(ix * 53 + face * 11 + seed, iy * 47 + face * 23, iz * 59 + face * 29);
          float sideCut = large ? 0.36 - lowBoost * 0.08 : 0.46 - lowBoost * 0.10;
          if (side < sideCut && gate < 0.82 - lowBoost * 0.18) continue;
          if (gate < (large ? 0.18 : 0.36) - lowBoost * 0.12) continue;
          writeSvgVoxelFaceContour(out, basis, bounds, x, y, w, h, scale, ix, iy, iz, face, weight);
        }
      }
    }
  }
}

void writeSvgVoxelFaceContour(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int ix, int iy, int iz, int face, float weight) {
  PVector[] pts = voxelFacePoints(ix, iy, iz, face);
  for (int i = 0; i < pts.length; i++) pts[i] = callSheetScreen(pts[i], new PVector(), basis, bounds, x, y, w, h, scale);
  for (int i = 0; i < pts.length; i++) {
    PVector a = pts[i];
    PVector b = pts[(i + 1) % pts.length];
    if (a.x < x - 4 && b.x < x - 4) continue;
    if (a.x > x + w + 4 && b.x > x + w + 4) continue;
    if (a.y < y - 4 && b.y < y - 4) continue;
    if (a.y > y + h - 18 && b.y > y + h - 18) continue;
    svgLine(out, a.x, a.y, b.x, b.y, 1.0, weight);
  }
}

void writeCallSheetSvgEdges(PrintWriter out, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean emphasize, float opacity, float weight) {
  stride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (emphasize && !callSheetEmphasizedFace(t, basis)) continue;
    if (cadGraphicDrafting && emphasize && !callSheetKeepGraphicSurfaceEdge(t, basis, i)) continue;
    if (cadGraphicDrafting && !emphasize && !callSheetKeepGraphicSurfaceInterior(t, basis, i)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    svgLine(out, a.x, a.y, b.x, b.y, opacity, weight);
    svgLine(out, b.x, b.y, c.x, c.y, opacity, weight);
    svgLine(out, c.x, c.y, a.x, a.y, opacity, weight);
  }
}

void writeSvgVoxelEdgesForPanel(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, boolean exposedEdges, boolean internalLattice, float opacity, float weight) {
  if (foundryCallSheetSolid == null) return;
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        if (internalLattice) {
          if ((ix + iy + iz + seed) % max(1, cadInternalStride) != 0) continue;
          writeSvgVoxelCubeEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, false, opacity, weight);
        }
        if (exposedEdges) {
          if (!isSolid(foundryCallSheetSolid, ix + 1, iy, iz, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 0, opacity, weight);
          if (!isSolid(foundryCallSheetSolid, ix - 1, iy, iz, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 1, opacity, weight);
          if (!isSolid(foundryCallSheetSolid, ix, iy + 1, iz, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 2, opacity, weight);
          if (!isSolid(foundryCallSheetSolid, ix, iy - 1, iz, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 3, opacity, weight);
          if (!isSolid(foundryCallSheetSolid, ix, iy, iz + 1, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 4, opacity, weight);
          if (!isSolid(foundryCallSheetSolid, ix, iy, iz - 1, n)) writeSvgVoxelFaceEdges(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, 5, opacity, weight);
        }
      }
    }
  }
}

void writeSvgVoxelCubeEdges(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ix, int iy, int iz, boolean exposed, float opacity, float weight) {
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix + 1, iy, iz, exposed, 30, opacity, weight);
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix, iy + 1, iz, exposed, 31, opacity, weight);
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, ix, iy, iz, ix, iy, iz + 1, exposed, 32, opacity, weight);
}

void writeSvgVoxelFaceEdges(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ix, int iy, int iz, int face, float opacity, float weight) {
  if (cadGraphicDrafting && voxelFaceNormal(face).dot(basis.view) <= 0.02) return;
  int x0 = ix, x1 = ix + 1;
  int y0 = iy, y1 = iy + 1;
  int z0 = iz, z1 = iz + 1;
  if (face == 0) writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x1, y0, z0, x1, y1, z0, x1, y1, z1, x1, y0, z1, face, opacity, weight);
  else if (face == 1) writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x0, y0, z1, x0, y1, z1, x0, y1, z0, face, opacity, weight);
  else if (face == 2) writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x0, y1, z0, x0, y1, z1, x1, y1, z1, x1, y1, z0, face, opacity, weight);
  else if (face == 3) writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x1, y0, z0, x1, y0, z1, x0, y0, z1, face, opacity, weight);
  else if (face == 4) writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x0, y0, z1, x1, y0, z1, x1, y1, z1, x0, y1, z1, face, opacity, weight);
  else writeSvgVoxelFaceEdgeSet(out, basis, bounds, x, y, w, h, scale, seen, x0, y0, z0, x0, y1, z0, x1, y1, z0, x1, y0, z0, face, opacity, weight);
}

void writeSvgVoxelFaceEdgeSet(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ax, int ay, int az, int bx, int by, int bz, int cx, int cy, int cz, int dx, int dy, int dz, int face, float opacity, float weight) {
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, ax, ay, az, bx, by, bz, true, face, opacity, weight);
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, bx, by, bz, cx, cy, cz, true, face + 10, opacity, weight);
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, cx, cy, cz, dx, dy, dz, true, face + 20, opacity, weight);
  writeSvgVoxelGridEdge(out, basis, bounds, x, y, w, h, scale, seen, dx, dy, dz, ax, ay, az, true, face + 30, opacity, weight);
}

void writeSvgVoxelGridEdge(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, HashSet<String> seen, int ax, int ay, int az, int bx, int by, int bz, boolean exposed, int salt, float opacity, float weight) {
  String key = voxelEdgeKey(ax, ay, az, bx, by, bz);
  if (seen.contains(key)) return;
  seen.add(key);
  if (!callSheetKeepVoxelEdge(ax, ay, az, bx, by, bz, salt, exposed)) return;
  PVector a = callSheetScreen(voxelGridPoint(ax, ay, az), new PVector(), basis, bounds, x, y, w, h, scale);
  PVector b = callSheetScreen(voxelGridPoint(bx, by, bz), new PVector(), basis, bounds, x, y, w, h, scale);
  if (a.x < x - 4 && b.x < x - 4) return;
  if (a.x > x + w + 4 && b.x > x + w + 4) return;
  if (a.y < y - 4 && b.y < y - 4) return;
  if (a.y > y + h - 18 && b.y > y + h - 18) return;
  svgLine(out, a.x, a.y, b.x, b.y, opacity, weight);
}

void writeSvgVoxelShadowFaces(PrintWriter out, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, boolean large) {
  if (foundryCallSheetSolid == null) return;
  PVector light = new PVector(basis.view.x, basis.view.y, basis.view.z + 0.72);
  light.normalize();
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int face = 0; face < 6; face++) {
          if (!voxelFaceExposed(ix, iy, iz, face, n)) continue;
          float brightness = voxelFaceNormal(face).dot(light);
          if (brightness >= cadShadowThreshold) continue;
          if (!callSheetKeepVoxelEdge(ix, iy, iz, ix + face + 1, iy + face + 2, iz + face + 3, face + 90, true)) continue;
          PVector[] pts = voxelFacePoints(ix, iy, iz, face);
          PVector a = callSheetScreen(pts[0], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector b = callSheetScreen(pts[1], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector c = callSheetScreen(pts[2], new PVector(), basis, bounds, x, y, w, h, scale);
          PVector d = callSheetScreen(pts[3], new PVector(), basis, bounds, x, y, w, h, scale);
          svgPolygon4(out, a, b, c, d, "#000000", large ? 0.23 : 0.14);
        }
      }
    }
  }
}

void writeCallSheetSvgVoxelMasses(PrintWriter out, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride) {
  stride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    if (!callSheetShadowFace(t, basis)) continue;
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    PVector b = callSheetScreen(t.b, center, basis, bounds, x, y, w, h, scale);
    PVector c = callSheetScreen(t.c, center, basis, bounds, x, y, w, h, scale);
    float density = callSheetProjectedDensity(a, b, c);
    svgPolygon(out, a, b, c, "#000000", density > 8.0 ? 0.28 : 0.14, "none", 0.0, 0.0);
  }
}

void writeCallSheetSvgVoxelGlyphs(PrintWriter out, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  stride = max(1, stride);
  float cell = constrain(scale * foundryScaleMM / max(1.0, foundryActiveVolumeResolution()) * (large ? 0.34 : 0.26), large ? 2.8 : 1.8, large ? 7.0 : 4.2);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector centroid = new PVector((t.a.x + t.b.x + t.c.x) / 3.0, (t.a.y + t.b.y + t.c.y) / 3.0, (t.a.z + t.b.z + t.c.z) / 3.0);
    PVector p = callSheetScreen(centroid, center, basis, bounds, x, y, w, h, scale);
    if (p.x < x + 4 || p.x > x + w - 4 || p.y < y + 4 || p.y > y + h - 24) continue;
    boolean dark = callSheetShadowFace(t, basis) || abs(t.normal().dot(basis.view)) < 0.24;
    svgIsoCell(out, p.x, p.y, cell, dark ? 0.90 : 0.48, dark ? (large ? 0.72 : 0.56) : (large ? 0.42 : 0.34));
  }
}

void svgIsoCell(PrintWriter out, float cx, float cy, float s, float opacity, float weight) {
  float ix = s * 0.86;
  float iy = s * 0.50;
  float drop = s * 0.78;
  svgLine(out, cx - ix, cy, cx, cy - iy, opacity, weight);
  svgLine(out, cx, cy - iy, cx + ix, cy, opacity, weight);
  svgLine(out, cx + ix, cy, cx, cy + iy, opacity, weight);
  svgLine(out, cx, cy + iy, cx - ix, cy, opacity, weight);
  svgLine(out, cx - ix, cy, cx - ix, cy + drop, opacity, weight);
  svgLine(out, cx + ix, cy, cx + ix, cy + drop, opacity, weight);
  svgLine(out, cx, cy + iy, cx, cy + iy + drop, opacity, weight);
  svgLine(out, cx - ix, cy + drop, cx, cy + iy + drop, opacity, weight);
  svgLine(out, cx + ix, cy + drop, cx, cy + iy + drop, opacity, weight);
}

void writeCallSheetSvgNodes(PrintWriter out, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale, int stride, boolean large) {
  stride = max(1, stride);
  float r = large ? 1.7 : 1.15;
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    PVector a = callSheetScreen(t.a, center, basis, bounds, x, y, w, h, scale);
    out.println("<circle cx=\"" + svgNum(a.x) + "\" cy=\"" + svgNum(a.y) + "\" r=\"" + svgNum(r) + "\" fill=\"#000000\" fill-opacity=\"0.7\"/>");
  }
}

void writeCallSheetSvgHeader(PrintWriter out, int x, int y, int w, String style) {
  svgTextStyled(out, x, y + 20, 22, "SURFACE FOUNDRY - ISOMETRIC DRAWING CALL SHEET", "700", "start", "auto");
  svgTextStyled(out, x, y + 43, 10.4, shortText(callSheetDraftLabel(style), 102), "400", "start", "auto");
  svgTextStyled(out, x, y + 61, 11.0, "CONFIGURATION SNAPSHOT", "700", "start", "auto");
  String[] lines = callSheetWrappedConfigurationLines(style, 48);
  int split = (lines.length + 1) / 2;
  int gutter = 18;
  int columnW = (w - gutter) / 2;
  svgLine(out, x, y + 65, x + w, y + 65, 0.35, 0.65);
  svgLine(out, x + columnW + gutter / 2, y + 65, x + columnW + gutter / 2, y + 344, 0.35, 0.65);
  for (int i = 0; i < lines.length; i++) {
    int col = i / split;
    int row = i % split;
    svgTextStyled(out, x + col * (columnW + gutter), y + 80 + row * 10.4, 8.8, lines[i], "400", "start", "auto");
  }
}

void writeCallSheetSvgTitleBlock(PrintWriter out, int x, int y, int w, int h, String style) {
  svgRect(out, x, y, w, h, "none", "#000000", 1.0, 1.25);
  int[] cuts = {420, 735, 930, 1125};
  for (int i = 0; i < cuts.length; i++) {
    svgLine(out, x + cuts[i], y, x + cuts[i], y + h, 1.0, 1.25);
  }
  writeCallSheetSvgDrawingCell(out, x + 8, y + 18);
  writeCallSheetSvgDrawnForCell(out, x + 430, y + 18, 295, h - 16);
  writeCallSheetSvgTitleCell(out, x + 745, y + 18, "SCALE", "NTS");
  writeCallSheetSvgTitleCell(out, x + 940, y + 18, "SHEET", "D-001");
  writeCallSheetSvgNotesCell(out, x + 1135, y + 18, style);
}

void writeCallSheetSvgTitleCell(PrintWriter out, int x, int y, String title, String body) {
  svgTextStyled(out, x, y, 8.2, title, "700", "start", "auto");
  svgTextStyled(out, x, y + 34, 9.0, body, "400", "start", "auto");
}

void writeCallSheetSvgDrawingCell(PrintWriter out, int x, int y) {
  svgTextStyled(out, x, y, 8.2, "DRAWING", "700", "start", "auto");
  svgTextStyled(out, x, y + 28, 9.0, "Surface Foundry STL - Isometric Call Sheet", "400", "start", "auto");
  svgTextStyled(out, x, y + 45, 7.2, "Generated: " + callSheetGeneratedLabel(), "400", "start", "auto");
}

void writeCallSheetSvgNotesCell(PrintWriter out, int x, int y, String style) {
  svgTextStyled(out, x, y, 10.2, "NOTES", "700", "start", "auto");
  String[] lines = callSheetSettingsLines(style);
  for (int i = 0; i < lines.length; i++) {
    svgTextStyled(out, x, y + 14 + i * 11, 9.0, lines[i], "400", "start", "auto");
  }
}

void writeCallSheetSvgDrawnForCell(PrintWriter out, int x, int y, int w, int h) {
  svgTextStyled(out, x, y, 8.2, "DRAWN FOR", "700", "start", "auto");
  svgTextStyled(out, x, y + 35, 13.0, "[Brian Fahey]", "700", "start", "auto");
  float logoX = x + 142;
  float logoY = y - 6;
  float logoW = max(1, w - 150);
  float logoH = 48;
  String href = "../../data/" + FIELDWORKS_LOGO_FILE;
  out.println("<image href=\"" + safeXml(href) + "\" xlink:href=\"" + safeXml(href) + "\" x=\"" + svgNum(logoX) + "\" y=\"" + svgNum(logoY) + "\" width=\"" + svgNum(logoW) + "\" height=\"" + svgNum(logoH) + "\" preserveAspectRatio=\"xMinYMid meet\"/>");
}

void writeFoundryCallSheetManifest(String filename, String surfaceSvg, String surfacePng, String latticeSvg, String latticePng, String sourceStl, String reliefDefinedStl, String reliefDramaticStl, String reliefPreviewPng, String reliefHeightPng) {
  JSONObject meta = new JSONObject();
  float[] scores = currentTopologyScores();
  meta.setString("program", "Cosmosis Visual Observatory Surface Foundry");
  meta.setString("feature", "surface_foundry_call_sheet");
  meta.setString("generated_at", nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2));
  meta.setString("source_mesh", sourceStl);
  meta.setInt("triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
  meta.setString("wrap_geometry", foundryGeometryName());
  meta.setFloat("wrap_blend", foundryGeometryIndex == 0 ? 0.0 : foundryWrapBlend);
  meta.setString("topology", topologyName(activeTopologyIndex(scores)));
  meta.setString("material_target", callSheetMaterialLabel());
  MaterialProfile manifestMaterial = activeMaterial();
  meta.setInt("material_source_mode_index", materialSourceMode);
  meta.setString("material_source_mode", materialSourceLabel());
  meta.setInt("material_catalog_index", selectedMaterial);
  meta.setInt("material_catalog_size", materials.size());
  meta.setString("material_source", manifestMaterial == null ? "" : safeString(manifestMaterial.source, ""));
  meta.setString("material_source_id", manifestMaterial == null ? "" : safeString(manifestMaterial.sourceId, ""));
  meta.setString("material_provider", manifestMaterial == null ? "" : safeString(manifestMaterial.provider, ""));
  meta.setString("material_formula", manifestMaterial == null ? "" : safeString(manifestMaterial.formula, ""));
  meta.setString("material_confidence", manifestMaterial == null ? "" : safeString(manifestMaterial.confidence, ""));
  meta.setString("material_functional_tags", manifestMaterial == null ? "" : safeString(manifestMaterial.functionalTags, ""));
  meta.setFloat("material_stiffness_normalized", manifestMaterial == null ? 0 : manifestMaterial.stiffnessN);
  meta.setFloat("material_order_normalized", manifestMaterial == null ? 0 : manifestMaterial.orderN);
  meta.setFloat("material_porosity", manifestMaterial == null ? 0 : manifestMaterial.porosity);
  meta.setFloat("material_anisotropy", manifestMaterial == null ? 0 : manifestMaterial.anisotropy);
  meta.setFloat("material_phase_transform", manifestMaterial == null ? 0 : manifestMaterial.phaseTransform);
  meta.setFloat("material_topological_response", manifestMaterial == null ? 0 : manifestMaterial.topologicalResponse);
  meta.setFloat("material_superconducting_coherence", manifestMaterial == null ? 0 : manifestMaterial.superconductingCoherence);
  meta.setFloat("material_transition_temperature_k", manifestMaterial == null ? 0 : manifestMaterial.transitionTemperatureK);
  meta.setBoolean("source_mesh_watertight", foundryMeshIsPrintable());
  meta.setInt("source_mesh_boundary_edges", foundryBoundaryEdges);
  meta.setInt("source_mesh_non_manifold_edges", foundryNonManifoldEdges);
  meta.setInt("source_mesh_degenerate_faces", foundryDegenerateFaces);
  meta.setInt("source_mesh_bridge_voxels", foundryBridgeVoxels);
  meta.setInt("resolution", foundryActiveVolumeResolution());
  meta.setFloat("iso_band", foundryIsoBand);
  meta.setFloat("scale_mm", foundryScaleMM);
  meta.setBoolean("raised_transport_veins", foundryRaisedVeinsApplied());
  meta.setBoolean("raised_transport_veins_requested", foundryRaisedVeins);
  meta.setString("raised_transport_veins_policy", dcrteRaisedVeinsPolicy());
  meta.setFloat("vein_radius_mm", foundryVeinRadiusMM);
  meta.setFloat("vein_lift_mm", foundryVeinLiftMM);
  meta.setBoolean("stochastic_cad_preview", cadPreviewEnabled);
  meta.setBoolean("cad_internal_lattice", cadInternalLattice);
  meta.setInt("cad_internal_stride", cadInternalStride);
  meta.setFloat("cad_shadow_threshold", cadShadowThreshold);
  meta.setFloat("cad_edge_cull", cadEdgeCull);
  meta.setFloat("cad_stochastic", cadStochastic);
  meta.setString("cad_render_strategy", cadGraphicDrafting ? "graphic_drafting_bw" : "tonal_line_accumulation");
  meta.setInt("seed", seed);
  meta.setFloat("simulation_time", simT);
  meta.setBoolean("paused", paused);
  meta.setBoolean("reverse_holonomy", reverseHolonomy);
  meta.setFloat("alpha", alpha);
  meta.setInt("depth", depth);
  meta.setFloat("source", sourcePressure);
  meta.setFloat("floquet", floquetCoupling);
  meta.setFloat("quasi_energy", quasiEnergy);
  meta.setFloat("coherence", coherenceBias);
  meta.setFloat("ctc_bias", ctcBias);
  meta.setFloat("brane_twist", braneTwist);
  meta.setFloat("deep_detail", deepDetail);
  meta.setFloat("time_scale", timeScale);
  meta.setFloat("recursion_falloff", recursionFalloff());
  meta.setBoolean("shaper_enabled", shaperEnabled);
  meta.setBoolean("shaper_use_sender", shaperUseSender);
  meta.setBoolean("shaper_sender_online", shaperSenderOnline);
  meta.setString("shaper_source", shaperSourceStatus);
  meta.setFloat("shaper_mix", shaperMix);
  meta.setFloat("solar_wind", solarWindStream);
  meta.setFloat("xray_flux", xrayFluxStream);
  meta.setFloat("ocean_current", oceanCurrentStream);
  meta.setFloat("tide", tideStream);
  meta.setFloat("galactic_torsion", galacticTorsionStream);
  meta.setFloat("shaper_plasma", shaperPlasma);
  meta.setFloat("shaper_water", shaperWater);
  meta.setFloat("shaper_cosmic", shaperCosmic);
  meta.setFloat("shaper_drive", shaperDrive);
  meta.setString("camera", "orthographic isometric");
  meta.setFloat("elevation_degrees", 35.26438968);
  meta.setString("small_view_azimuths", "0,30,60,90,120,150,180,210,240");
  meta.setFloat("large_view_azimuth", 45);
  JSONArray outputs = new JSONArray();
  JSONObject a = new JSONObject();
  a.setString("style", "surface_silhouette");
  a.setString("svg", surfaceSvg);
  a.setBoolean("svg_available", surfaceSvg.length() > 0 && new File(sketchPath(surfaceSvg)).exists());
  a.setString("png", surfacePng);
  outputs.setJSONObject(0, a);
  JSONObject b = new JSONObject();
  b.setString("style", "voxel_lattice");
  b.setString("svg", latticeSvg);
  b.setBoolean("svg_available", latticeSvg.length() > 0 && new File(sketchPath(latticeSvg)).exists());
  b.setString("png", latticePng);
  outputs.setJSONObject(1, b);
  JSONObject c = new JSONObject();
  c.setString("style", "silhouette_cutout_bas_relief");
  c.setString("defined_stl", reliefDefinedStl);
  c.setString("dramatic_stl", reliefDramaticStl);
  c.setString("preview_png", reliefPreviewPng);
  c.setString("heightfield_png", reliefHeightPng);
  c.setString("source", "generated from filled Surface Foundry voxel volume, not SVG brightness");
  c.setString("defined_profile", "detail-preserving source field; base 2.0 mm; relief 9.0 mm; gamma 0.58; max 11.0 mm");
  c.setString("dramatic_profile", "volumetric contour field; base 2.6 mm; relief 18.0 mm; gamma 0.72; max 20.6 mm");
  c.setString("dramatic_field_blend", "18% source detail + 47% broad contour + 35% interior-distance dome");
  outputs.setJSONObject(2, c);
  meta.setJSONArray("outputs", outputs);
  JSONArray blend = new JSONArray();
  for (int i = 0; i < scores.length; i++) blend.setFloat(i, scores[i]);
  meta.setJSONArray("topology_blend", blend);
  appendDcrteMetadata(meta);
  saveJSONObject(meta, filename);
}

String callSheetMaterialLabel() {
  MaterialProfile m = activeMaterial();
  return m == null ? "none" : safeString(m.name, "Unknown");
}

String callSheetGeneratedLabel() {
  if (foundryCallSheetGeneratedAt != null && foundryCallSheetGeneratedAt.length() > 0) return foundryCallSheetGeneratedAt;
  return nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
}

String[] callSheetSettingsLines(String style) {
  float[] scores = currentTopologyScores();
  String[] base = new String[] {
    styleLabel(style) + " | " + (cadGraphicDrafting ? "GRAPHIC BW" : "TONAL") + " | stride " + cadInternalStride + " | cull " + nf(cadEdgeCull, 1, 2) + " | shade " + nf(cadShadowThreshold, 1, 2) + " | rand " + nf(cadStochastic, 1, 2),
    "res " + foundryActiveVolumeResolution() + "^3 | iso " + nf(foundryIsoBand, 1, 3) + " | scale " + nf(foundryScaleMM, 1, 0) + "mm | geom " + foundryGeometryName() + " | wrap " + nf(foundryGeometryIndex == 0 ? 0 : foundryWrapBlend, 1, 2),
    "alpha " + nf(alpha, 1, 2) + " | depth " + depth + " | source " + nf(sourcePressure, 1, 2) + " | floquet " + nf(floquetCoupling, 1, 2) + " | quasi " + nf(quasiEnergy, 1, 2) + " | coherence " + nf(coherenceBias, 1, 2),
    "topo " + topologyName(activeTopologyIndex(scores)) + " | mat " + shortText(callSheetMaterialLabel(), 18) + " | veins " + (foundryRaisedVeinsApplied() ? "applied" : (foundryRaisedVeins ? "suppressed" : "off")) + " | shaper " + (shaperEnabled ? shaperSourceStatus : "off")
  };
  return base;
}

String[] callSheetConfigurationLines(String style) {
  float[] scores = currentTopologyScores();
  MaterialProfile m = activeMaterial();
  String materialName = m == null ? "none" : shortText(safeString(m.name, "Unknown"), 38);
  String materialProvider = m == null ? "none" : shortText(safeString(m.provider, ""), 38);
  String materialSourceId = m == null ? "none" : shortText(safeString(m.sourceId, ""), 38);
  String materialSource = m == null ? "none" : shortText(safeString(m.source, ""), 38);
  float effectiveWrap = foundryGeometryIndex == 0 ? 0 : foundryWrapBlend;
  String meshAudit = foundryBoundaryEdges + "/" + foundryNonManifoldEdges + "/" + foundryDegenerateFaces;
  String dcrteValidation = dcrteLastValidationReport == null ? "not_run" : dcrteLastValidationReport.status.id();
  DCRTEVolume dcrteActiveVolume = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
    ? dcrteImportedVolume : dcrtePrimitiveVolume;
  int dcrteAdmitted = dcrteActiveVolume == null ? 0 : dcrteActiveVolume.admittedCount;
  int dcrteFinal = dcrteActiveVolume == null ? 0 : dcrteActiveVolume.finalSolidCount;
  int dcrteOutside = dcrteLastValidationReport == null ? 0 : dcrteLastValidationReport.outsideSolidSamples;
  boolean imported = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH;
  String importedSource = dcrteImportedSourceMesh == null ? "none" : shortText(dcrteImportedSourceMesh.sourceName, 24);
  String importedHash = dcrteImportedSourceMesh == null ? "-" : dcrteImportedSourceMesh.sourceHashSha256;
  if (importedHash.length() > 16) importedHash = importedHash.substring(0, 16);
  String observationDomain = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE
    ? dcrtePrimitiveDomainType.id()
    : imported ? "imported_mesh / " + importedSource : "not applied";
  String observerLabel = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE
    ? dcrtePrimitiveResolution + "^3 [-1,1]^3 voxel-center"
    : imported ? dcrteImportedResolution + "^3 [-1,1]^3 voxel-center" : "legacy direct sampler";
  String observationLabel = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE || imported
    ? dcrteObservationMode.id() + " | shell " + nf(dcrteShellThicknessVoxels, 1, 1) + " vox"
    : "not applied";
  String[] base = new String[] {
    "OUTPUT " + styleLabel(style) + " | " + (cadGraphicDrafting ? "graphic BW" : "tonal lines"),
    "DCRTE " + dcrtePipelineLabel() + " | engine " + (dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT ? "direct" : "legacy adapter"),
    "OBS DOMAIN " + observationDomain + " | field carrier remains independent",
    "OBSERVER " + observerLabel,
    "OBS LAYER " + observationLabel,
    "DCRTE VALID " + dcrteValidation + " | admitted " + dcrteAdmitted + " | final " + dcrteFinal + " | outside " + dcrteOutside,
    "CAD preview " + onOff(cadPreviewEnabled) + " | lattice " + onOff(cadInternalLattice) + " | stride " + cadInternalStride,
    "CAD cull " + nf(cadEdgeCull, 1, 2) + " | shade " + nf(cadShadowThreshold, 1, 2) + " | rand " + nf(cadStochastic, 1, 2),
    "FIELD alpha " + nf(alpha, 1, 3) + " | depth " + depth + " | deep " + nf(deepDetail, 1, 3),
    "FIELD source " + nf(sourcePressure, 1, 3) + " | floquet " + nf(floquetCoupling, 1, 3) + " | quasi " + nf(quasiEnergy, 1, 3),
    "FIELD coherence " + nf(coherenceBias, 1, 3) + " | CTC " + nf(ctcBias, 1, 3) + " | brane " + nf(braneTwist, 1, 3),
    "FIELD time " + nf(timeScale, 1, 3) + " | falloff " + nf(recursionFalloff(), 1, 3) + " | seed " + seed,
    "FOUNDRY res " + foundryActiveVolumeResolution() + "^3 | iso " + nf(foundryIsoBand, 1, 3) + " | scale " + nf(foundryScaleMM, 1, 1) + "mm",
    "CARRIER " + foundryGeometryName() + " | w " + nf(effectiveWrap, 1, 2) + " | vox " + nf(foundryScaleMM / max(1.0, foundryActiveVolumeResolution()), 1, 2) + "mm",
    "VEINS requested " + onOff(foundryRaisedVeins) + " | applied " + onOff(foundryRaisedVeinsApplied()) + " | " + dcrteRaisedVeinsPolicy(),
    "VEIN radius " + nf(foundryVeinRadiusMM, 1, 2) + "mm | lift " + nf(foundryVeinLiftMM, 1, 2) + "mm",
    "MATERIAL " + materialSourceLabel() + " | index " + (selectedMaterial + 1) + "/" + materials.size(),
    "TARGET " + materialName,
    "PROVIDER " + materialProvider,
    "SOURCE ID " + materialSourceId,
    "SOURCE " + materialSource,
    "MAT stiff " + nf(m == null ? 0 : m.stiffnessN, 1, 3) + " | order " + nf(m == null ? 0 : m.orderN, 1, 3) + " | porous " + nf(m == null ? 0 : m.porosity, 1, 3),
    "MAT anis " + nf(m == null ? 0 : m.anisotropy, 1, 3) + " | phase " + nf(m == null ? 0 : m.phaseTransform, 1, 3) + " | topo " + nf(m == null ? 0 : m.topologicalResponse, 1, 3),
    "MAT SC " + nf(m == null ? 0 : m.superconductingCoherence, 1, 3) + " | Tc " + nf(m == null ? 0 : m.transitionTemperatureK, 1, 2) + "K",
    "SHAPER " + onOff(shaperEnabled) + " | input " + (shaperUseSender ? "sender" : "sim") + " | mix " + nf(shaperMix, 1, 3),
    "STREAM solar " + nf(solarWindStream, 1, 3) + " | Xray " + nf(xrayFluxStream, 1, 3) + " | ocean " + nf(oceanCurrentStream, 1, 3),
    "STREAM tide " + nf(tideStream, 1, 3) + " | galactic " + nf(galacticTorsionStream, 1, 3) + " | drive " + nf(shaperDrive, 1, 3),
    "DRIVE plasma " + nf(shaperPlasma, 1, 3) + " | water " + nf(shaperWater, 1, 3) + " | cosmic " + nf(shaperCosmic, 1, 3),
    "TOPO " + topologyName(activeTopologyIndex(scores)) + " | blend " + topologyBlendLabel(scores),
    "MESH tris " + (foundryMesh == null ? 0 : foundryMesh.tris.size()) + " | bridge " + foundryBridgeVoxels + " | audit " + meshAudit,
    "STATE simT " + nf(simT, 1, 3) + " | paused " + onOff(paused) + " | holonomy " + (reverseHolonomy ? "reverse" : "forward")
  };
  if (!imported) return base;
  String[] expanded = new String[base.length + 3];
  System.arraycopy(base, 0, expanded, 0, 6);
  expanded[6] = "IMPORT source " + importedSource + " | sha " + importedHash + " | units unspecified";
  expanded[7] = "IMPORT policy " + dcrteImportedPolicy.id() + " | fit " + nf(dcrteImportedFitMargin, 1, 3) + " | scale " + nf(dcrteImportedScaleMultiplier, 1, 3);
  expanded[8] = "IMPORT rot " + dcrteImportedRotateX + "/" + dcrteImportedRotateY + "/" + dcrteImportedRotateZ
    + " quarter-turns | SDF " + (dcrteImportedSdf == null ? "not built" : dcrteImportedSdf.signed ? "signed" : "unsigned");
  System.arraycopy(base, 6, expanded, 9, base.length - 6);
  return expanded;
}

String[] callSheetWrappedConfigurationLines(String style, int maxChars) {
  String[] source = callSheetConfigurationLines(style);
  ArrayList<String> wrapped = new ArrayList<String>();
  for (int i = 0; i < source.length; i++) {
    String[] segments = callSheetWrapConfigurationLine(source[i], maxChars);
    for (int j = 0; j < segments.length; j++) wrapped.add(segments[j]);
  }
  return wrapped.toArray(new String[wrapped.size()]);
}

String[] callSheetWrapConfigurationLine(String value, int maxChars) {
  ArrayList<String> lines = new ArrayList<String>();
  String[] words = splitTokens(value == null ? "" : value, " \t\r\n");
  String line = "";
  for (int i = 0; i < words.length; i++) {
    String candidate = line.length() == 0 ? words[i] : line + " " + words[i];
    if (candidate.length() <= maxChars || line.length() == 0) {
      line = candidate;
    } else {
      lines.add(line);
      line = "  " + words[i];
    }
  }
  if (line.length() > 0) lines.add(line);
  if (lines.size() == 0) lines.add("-");
  return lines.toArray(new String[lines.size()]);
}

String onOff(boolean value) {
  return value ? "on" : "off";
}

String topologyBlendLabel(float[] scores) {
  String label = "";
  for (int i = 0; i < scores.length; i++) {
    if (i > 0) label += "/";
    label += nf(scores[i], 1, 2);
  }
  return label;
}

String styleLabel(String style) {
  if (style.equals("voxel_lattice")) return "VOXEL LATTICE";
  return "SURFACE SILHOUETTE";
}

String callSheetDraftLabel(String style) {
  if (style.equals("voxel_lattice")) return "Draft v2: exploratory voxel representation; 9-view rotation matrix at 30 degree increments; one large standard isometric view.";
  return "Draft v1: vector line-only plotter draft; 9-view rotation matrix at 30 degree increments; one large standard isometric view.";
}

String callSheetSourceName() {
  return "surface_foundry_live_" + foundryGeometryName() + "_" + topologyName(activeTopologyIndex(currentTopologyScores()));
}

PVector foundryMeshCenter() {
  PVector center = new PVector();
  int count = 0;
  if (foundryMesh == null) return center;
  int stride = max(1, foundryMesh.tris.size() / 24000);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    center.add(t.a);
    center.add(t.b);
    center.add(t.c);
    count += 3;
  }
  if (count > 0) center.div(count);
  return center;
}

CallSheetBasis callSheetBasis(float azDeg, float elDeg) {
  float az = radians(azDeg);
  float el = radians(elDeg);
  PVector horizontal = new PVector(cos(az), -sin(az), 0);
  PVector depthAxis = new PVector(sin(az), cos(az), 0);
  PVector vertical = new PVector(-depthAxis.x * sin(el), -depthAxis.y * sin(el), cos(el));
  PVector view = new PVector(depthAxis.x * cos(el), depthAxis.y * cos(el), sin(el));
  horizontal.normalize();
  vertical.normalize();
  view.normalize();
  return new CallSheetBasis(horizontal, vertical, view);
}

CallSheetBounds callSheetBounds(PVector center, CallSheetBasis basis, int stride) {
  CallSheetBounds b = new CallSheetBounds();
  if (foundryMesh == null) return b;
  stride = max(1, stride);
  for (int i = 0; i < foundryMesh.tris.size(); i += stride) {
    MeshTri t = foundryMesh.tris.get(i);
    b.include(callSheetProject(t.a, center, basis));
    b.include(callSheetProject(t.b, center, basis));
    b.include(callSheetProject(t.c, center, basis));
  }
  if (!b.valid) {
    b.include(new PVector(-1, -1, 0));
    b.include(new PVector(1, 1, 0));
  }
  return b;
}

CallSheetBounds callSheetVoxelBounds(CallSheetBasis basis) {
  CallSheetBounds b = new CallSheetBounds();
  if (foundryCallSheetSolid == null) {
    b.include(new PVector(-1, -1, 0));
    b.include(new PVector(1, 1, 0));
    return b;
  }
  int n = foundryActiveVolumeResolution();
  for (int ix = 0; ix < n; ix++) {
    for (int iy = 0; iy < n; iy++) {
      for (int iz = 0; iz < n; iz++) {
        if (!foundryCallSheetSolid[ix][iy][iz]) continue;
        for (int dx = 0; dx <= 1; dx++) {
          for (int dy = 0; dy <= 1; dy++) {
            for (int dz = 0; dz <= 1; dz++) {
              b.include(callSheetProject(voxelGridPoint(ix + dx, iy + dy, iz + dz), new PVector(), basis));
            }
          }
        }
      }
    }
  }
  if (!b.valid) {
    b.include(new PVector(-1, -1, 0));
    b.include(new PVector(1, 1, 0));
  }
  return b;
}

PVector callSheetProject(PVector p, PVector center, CallSheetBasis basis) {
  PVector q = PVector.sub(p, center);
  return new PVector(q.dot(basis.horizontal), -q.dot(basis.vertical), q.dot(basis.view));
}

PVector callSheetScreen(PVector p, PVector center, CallSheetBasis basis, CallSheetBounds bounds, int x, int y, int w, int h, float scale) {
  PVector q = callSheetProject(p, center, basis);
  float cx = x + w * 0.5;
  float cy = y + h * 0.53;
  float bx = (bounds.minX + bounds.maxX) * 0.5;
  float by = (bounds.minY + bounds.maxY) * 0.5;
  return new PVector(cx + (q.x - bx) * scale, cy + (q.y - by) * scale, q.z);
}

float callSheetScale(CallSheetBounds bounds, float drawW, float drawH) {
  float bw = max(1.0, bounds.maxX - bounds.minX);
  float bh = max(1.0, bounds.maxY - bounds.minY);
  return min(drawW / bw, drawH / bh);
}

float callSheetProjectedDensity(PVector a, PVector b, PVector c) {
  float area = abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) * 0.5;
  return 48.0 / max(1.0, area);
}

PVector voxelGridPoint(int ix, int iy, int iz) {
  int n = foundryActiveVolumeResolution();
  return new PVector(foundryCoord(ix, n), foundryCoord(iy, n), foundryCoord(iz, n));
}

String voxelEdgeKey(int ax, int ay, int az, int bx, int by, int bz) {
  String a = ax + "," + ay + "," + az;
  String b = bx + "," + by + "," + bz;
  return a.compareTo(b) <= 0 ? a + "|" + b : b + "|" + a;
}

boolean callSheetKeepVoxelEdge(int ax, int ay, int az, int bx, int by, int bz, int salt, boolean exposed) {
  float h = hashUnit(ax * 17 + bx * 29 + seed, ay * 31 + by * 43 + salt, az * 47 + bz * 59);
  float threshold = exposed ? cadEdgeCull * cadStochastic * 0.32 : cadEdgeCull * (0.28 + cadStochastic * 0.62);
  return h >= threshold;
}

float hashUnit(int a, int b, int c) {
  int h = a * 374761393 + b * 668265263 + c * 1442695041;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h & 0x7fffffff) / 2147483647.0;
}

boolean voxelFaceExposed(int ix, int iy, int iz, int face, int n) {
  if (face == 0) return !isSolid(foundryCallSheetSolid, ix + 1, iy, iz, n);
  if (face == 1) return !isSolid(foundryCallSheetSolid, ix - 1, iy, iz, n);
  if (face == 2) return !isSolid(foundryCallSheetSolid, ix, iy + 1, iz, n);
  if (face == 3) return !isSolid(foundryCallSheetSolid, ix, iy - 1, iz, n);
  if (face == 4) return !isSolid(foundryCallSheetSolid, ix, iy, iz + 1, n);
  return !isSolid(foundryCallSheetSolid, ix, iy, iz - 1, n);
}

PVector voxelFaceNormal(int face) {
  if (face == 0) return new PVector(1, 0, 0);
  if (face == 1) return new PVector(-1, 0, 0);
  if (face == 2) return new PVector(0, 1, 0);
  if (face == 3) return new PVector(0, -1, 0);
  if (face == 4) return new PVector(0, 0, 1);
  return new PVector(0, 0, -1);
}

PVector[] voxelFacePoints(int ix, int iy, int iz, int face) {
  int x0 = ix, x1 = ix + 1;
  int y0 = iy, y1 = iy + 1;
  int z0 = iz, z1 = iz + 1;
  PVector[] pts = new PVector[4];
  if (face == 0) { pts[0] = voxelGridPoint(x1, y0, z0); pts[1] = voxelGridPoint(x1, y1, z0); pts[2] = voxelGridPoint(x1, y1, z1); pts[3] = voxelGridPoint(x1, y0, z1); }
  else if (face == 1) { pts[0] = voxelGridPoint(x0, y0, z0); pts[1] = voxelGridPoint(x0, y0, z1); pts[2] = voxelGridPoint(x0, y1, z1); pts[3] = voxelGridPoint(x0, y1, z0); }
  else if (face == 2) { pts[0] = voxelGridPoint(x0, y1, z0); pts[1] = voxelGridPoint(x0, y1, z1); pts[2] = voxelGridPoint(x1, y1, z1); pts[3] = voxelGridPoint(x1, y1, z0); }
  else if (face == 3) { pts[0] = voxelGridPoint(x0, y0, z0); pts[1] = voxelGridPoint(x1, y0, z0); pts[2] = voxelGridPoint(x1, y0, z1); pts[3] = voxelGridPoint(x0, y0, z1); }
  else if (face == 4) { pts[0] = voxelGridPoint(x0, y0, z1); pts[1] = voxelGridPoint(x1, y0, z1); pts[2] = voxelGridPoint(x1, y1, z1); pts[3] = voxelGridPoint(x0, y1, z1); }
  else { pts[0] = voxelGridPoint(x0, y0, z0); pts[1] = voxelGridPoint(x0, y1, z0); pts[2] = voxelGridPoint(x1, y1, z0); pts[3] = voxelGridPoint(x1, y0, z0); }
  return pts;
}

boolean callSheetShadowFace(MeshTri t, CallSheetBasis basis) {
  PVector n = t.normal();
  PVector light = new PVector(-0.35, -0.42, 0.84);
  light.normalize();
  return n.dot(light) < -0.16 && n.dot(basis.view) < 0.82;
}

boolean callSheetEmphasizedFace(MeshTri t, CallSheetBasis basis) {
  PVector n = t.normal();
  float viewEdge = abs(n.dot(basis.view));
  boolean axial = callSheetAxisEdge(t.a, t.b) || callSheetAxisEdge(t.b, t.c) || callSheetAxisEdge(t.c, t.a);
  return viewEdge < 0.42 || axial;
}

boolean callSheetKeepGraphicSurfaceEdge(MeshTri t, CallSheetBasis basis, int triIndex) {
  PVector n = t.normal();
  float viewEdge = abs(n.dot(basis.view));
  boolean axial = callSheetAxisEdge(t.a, t.b) || callSheetAxisEdge(t.b, t.c) || callSheetAxisEdge(t.c, t.a);
  float h = hashUnit(triIndex + seed, round(viewEdge * 1000.0), round(abs(n.z) * 1000.0));
  if (viewEdge < 0.13) return true;
  if (axial && viewEdge < 0.58 && h > 0.42) return true;
  return viewEdge < 0.26 && h > 0.66;
}

boolean callSheetKeepGraphicSurfaceInterior(MeshTri t, CallSheetBasis basis, int triIndex) {
  PVector n = t.normal();
  float viewEdge = abs(n.dot(basis.view));
  if (viewEdge > 0.50) return false;
  float h = hashUnit(triIndex + seed * 3, round(viewEdge * 1200.0), round(abs(n.x + n.y) * 900.0));
  return h > 0.88;
}

boolean callSheetAxisEdge(PVector a, PVector b) {
  float eps = max(0.001, foundryScaleMM / max(1.0, foundryActiveVolumeResolution()) * 0.06);
  int moving = 0;
  if (abs(a.x - b.x) > eps) moving++;
  if (abs(a.y - b.y) > eps) moving++;
  if (abs(a.z - b.z) > eps) moving++;
  return moving <= 1;
}

void svgRect(PrintWriter out, float x, float y, float w, float h, String fill, String stroke, float opacity, float weight) {
  out.println("<rect x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" width=\"" + svgNum(w) + "\" height=\"" + svgNum(h) + "\" fill=\"" + fill + "\" stroke=\"" + stroke + "\" stroke-width=\"" + svgNum(weight) + "\" opacity=\"" + svgNum(opacity) + "\"/>");
}

void svgText(PrintWriter out, float x, float y, int size, String label) {
  out.println("<text x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" font-family=\"monospace\" font-size=\"" + size + "\" fill=\"#000000\">" + safeXml(label) + "</text>");
}

void svgTextStyled(PrintWriter out, float x, float y, float size, String label, String weight, String anchor, String baseline) {
  out.println("<text x=\"" + svgNum(x) + "\" y=\"" + svgNum(y) + "\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"" + svgNum(size) + "\" font-weight=\"" + weight + "\" text-anchor=\"" + anchor + "\" dominant-baseline=\"" + baseline + "\" fill=\"#000000\">" + safeXml(label) + "</text>");
}

void svgLine(PrintWriter out, float x1, float y1, float x2, float y2, float opacity, float weight) {
  out.println("<line x1=\"" + svgNum(x1) + "\" y1=\"" + svgNum(y1) + "\" x2=\"" + svgNum(x2) + "\" y2=\"" + svgNum(y2) + "\" stroke=\"#000000\" stroke-opacity=\"" + svgNum(opacity) + "\" stroke-width=\"" + svgNum(weight) + "\" stroke-linecap=\"butt\" stroke-linejoin=\"miter\"/>");
}

void svgCircle(PrintWriter out, float x, float y, float r) {
  out.println("<circle cx=\"" + svgNum(x) + "\" cy=\"" + svgNum(y) + "\" r=\"" + svgNum(r) + "\" fill=\"#000000\"/>");
}

void svgPolygon(PrintWriter out, PVector a, PVector b, PVector c, String fill, float fillOpacity, String stroke, float strokeOpacity, float weight) {
  out.println("<polygon points=\"" + svgNum(a.x) + "," + svgNum(a.y) + " " + svgNum(b.x) + "," + svgNum(b.y) + " " + svgNum(c.x) + "," + svgNum(c.y) + "\" fill=\"" + fill + "\" fill-opacity=\"" + svgNum(fillOpacity) + "\" stroke=\"" + stroke + "\" stroke-opacity=\"" + svgNum(strokeOpacity) + "\" stroke-width=\"" + svgNum(weight) + "\"/>");
}

void svgPolygon4(PrintWriter out, PVector a, PVector b, PVector c, PVector d, String fill, float fillOpacity) {
  out.println("<polygon points=\"" + svgNum(a.x) + "," + svgNum(a.y) + " " + svgNum(b.x) + "," + svgNum(b.y) + " " + svgNum(c.x) + "," + svgNum(c.y) + " " + svgNum(d.x) + "," + svgNum(d.y) + "\" fill=\"" + fill + "\" fill-opacity=\"" + svgNum(fillOpacity) + "\" stroke=\"none\"/>");
}

void svgPolygonPts(PrintWriter out, PVector[] pts, String fill, float fillOpacity, String stroke, float strokeOpacity, float weight) {
  if (pts == null || pts.length < 3) return;
  String s = "";
  for (int i = 0; i < pts.length; i++) {
    if (i > 0) s += " ";
    s += svgNum(pts[i].x) + "," + svgNum(pts[i].y);
  }
  out.println("<polygon points=\"" + s + "\" fill=\"" + fill + "\" fill-opacity=\"" + svgNum(fillOpacity) + "\" stroke=\"" + stroke + "\" stroke-opacity=\"" + svgNum(strokeOpacity) + "\" stroke-width=\"" + svgNum(weight) + "\"/>");
}

void writeSvgHatchPolygon(PrintWriter out, PVector[] pts, float spacing, float angleDeg, float weight) {
  if (pts == null || pts.length < 3) return;
  float a = radians(angleDeg);
  PVector dir = new PVector(cos(a), sin(a));
  PVector normal = new PVector(-sin(a), cos(a));
  float minK = Float.MAX_VALUE;
  float maxK = -Float.MAX_VALUE;
  for (int i = 0; i < pts.length; i++) {
    float k = pts[i].x * normal.x + pts[i].y * normal.y;
    minK = min(minK, k);
    maxK = max(maxK, k);
  }
  float[] xs = new float[12];
  float[] ys = new float[12];
  float[] ds = new float[12];
  spacing = max(1.0, spacing);
  for (float k = minK - spacing; k <= maxK + spacing; k += spacing) {
    int count = hatchIntersections(pts, normal, dir, k, xs, ys, ds);
    if (count < 2) continue;
    sortHatchIntersections(xs, ys, ds, count);
    for (int i = 0; i < count - 1; i += 2) {
      svgLine(out, xs[i], ys[i], xs[i + 1], ys[i + 1], 1.0, weight);
    }
  }
}

String svgNum(float v) {
  return trim(nf(v, 0, 3));
}

String safeXml(String v) {
  if (v == null) return "";
  String out = v.replace("&", "&amp;");
  out = out.replace("<", "&lt;");
  out = out.replace(">", "&gt;");
  out = out.replace("\"", "&quot;");
  return out;
}

float foundryScalar(float x, float y, float z, float[] scores) {
  float base = topologyScalar(x, y, z, scores);
  if (foundryGeometryIndex == 0) return base;
  float geom = geometryCarrierScalar(foundryGeometryIndex, x, y, z);
  float fieldWrap = sampleFieldWrap(x, y) * (0.35 + 0.25 * coherenceBias);
  float phaseLift = 0.08 * sin((x + y + z) * PI * (1.0 + braneTwist) + holoGamma + shaperCosmic * TWO_PI);
  return lerp(base, geom + base * 0.30 + fieldWrap + phaseLift, foundryWrapBlend);
}

float sampleFieldWrap(float x, float y) {
  int c = constrain(round(map(x, -1, 1, 0, GRID - 1)), 0, GRID - 1);
  int r = constrain(round(map(y, -1, 1, 0, GRID - 1)), 0, GRID - 1);
  return (field[r][c] - 0.5) * 0.42;
}

float geometryCarrierScalar(int mode, float x, float y, float z) {
  float freq = PI * (1.15 + depth * 0.045);
  float X = x * freq + simT * 0.14;
  float Y = y * freq - simT * 0.10;
  float Z = z * freq + braneTwist * TWO_PI;
  if (mode == 1) {
    return (sin(X) * cos(Y) + sin(Y) * cos(Z) + sin(Z) * cos(X)) / 1.7;
  }
  if (mode == 2) {
    return (cos(X) + cos(Y) + cos(Z)) / 2.15;
  }
  if (mode == 3) {
    float r = sqrt(x*x + y*y + z*z);
    float theta = atan2(y, x);
    return z * 0.62 - (x*x - y*y) * 0.52 + sin(2.0 * theta + simT + holoGamma) * exp(-0.9 * r*r) * 0.28;
  }
  if (mode == 4) {
    float major = 0.55;
    float tube = sqrt(x*x + y*y) - major;
    float torus = tube*tube + z*z - 0.18;
    float theta = atan2(y, x);
    float braid = sin(theta * (3.0 + floor(depth % 4)) + z * 4.0 + holoGamma);
    return torus * 1.7 + braid * 0.18;
  }
  if (mode == 5) {
    float a = sin(1.85 * X);
    float b = sin(1.85 * (0.309 * X + 0.951 * Y) - simT * 0.36);
    float c = sin(1.85 * (-0.809 * X + 0.588 * Y) + simT * 0.22);
    float d = sin(1.18 * Z + cos(X + Y) * 0.55);
    return (a + b + c + d) / 2.9;
  }
  if (mode == 6) {
    float escape = mandelbrotCarrier(x, y);
    return (escape - 0.5) * 1.35 + z * 0.46 + sin(Z + escape * TWO_PI) * 0.16;
  }
  if (mode == 7) {
    float escape = juliaCarrier(x, y);
    return (escape - 0.5) * 1.35 + z * 0.42 + cos(Z - escape * TWO_PI) * 0.16;
  }
  if (mode == 8) return fractalRidgeCarrier(x, y, z) - 0.56;
  if (mode == 9) {
    float d = sin(X) * sin(Y) * sin(Z)
            + sin(X) * cos(Y) * cos(Z)
            + cos(X) * sin(Y) * cos(Z)
            + cos(X) * cos(Y) * sin(Z);
    return d / 2.25;
  }
  if (mode == 10) {
    return (3.0 * (cos(X) + cos(Y) + cos(Z)) + 4.0 * cos(X) * cos(Y) * cos(Z)) / 7.0;
  }
  if (mode == 11) {
    float pair = 2.0 * (cos(X) * cos(Y) + cos(Y) * cos(Z) + cos(Z) * cos(X));
    float harmonic = cos(2.0 * X) + cos(2.0 * Y) + cos(2.0 * Z);
    return (pair - harmonic) / 5.0;
  }
  if (mode == 12) {
    float weave = sin(2.0 * X) * cos(Y) * sin(Z)
                + sin(2.0 * Y) * cos(Z) * sin(X)
                + sin(2.0 * Z) * cos(X) * sin(Y);
    float shell = cos(2.0 * X) * cos(2.0 * Y)
                + cos(2.0 * Y) * cos(2.0 * Z)
                + cos(2.0 * Z) * cos(2.0 * X);
    return (weave - shell + 0.30) / 3.4;
  }
  if (mode == 13) {
    float s = cos(2.0 * X) * sin(Y) * cos(Z)
            + cos(X) * cos(2.0 * Y) * sin(Z)
            + sin(X) * cos(Y) * cos(2.0 * Z);
    return s / 2.15;
  }
  if (mode == 14) {
    float cxyz = cos(X) * cos(Y) * cos(Z);
    float c2xyz = cos(2.0 * X) * cos(2.0 * Y) * cos(2.0 * Z);
    float faces = cos(2.0 * X) * cos(2.0 * Y)
                + cos(2.0 * Y) * cos(2.0 * Z)
                + cos(2.0 * Z) * cos(2.0 * X);
    return (8.0 * cxyz + c2xyz - faces) / 9.0;
  }
  if (mode == 15) {
    float primary = cos(X) + cos(Y) + cos(Z);
    float split = sin(2.0 * X) * sin(Y) * sin(Z)
                + sin(2.0 * Y) * sin(Z) * sin(X)
                + sin(2.0 * Z) * sin(X) * sin(Y);
    return (primary + 0.82 * split) / 3.25;
  }
  if (mode == 16) return mengerDistance(x, y, z);
  return mandelbulbDistance(x, y, z);
}

float repeatMod(float value, float period) {
  return value - period * floor(value / period);
}

float mengerDistance(float x, float y, float z) {
  float px = x / 0.92;
  float py = y / 0.92;
  float pz = z / 0.92;
  float d = max(abs(px), max(abs(py), abs(pz))) - 1.0;
  float scale = 1.0;
  for (int i = 0; i < 4; i++) {
    float ax = repeatMod(px * scale, 2.0) - 1.0;
    float ay = repeatMod(py * scale, 2.0) - 1.0;
    float az = repeatMod(pz * scale, 2.0) - 1.0;
    scale *= 3.0;
    float rx = abs(1.0 - 3.0 * abs(ax));
    float ry = abs(1.0 - 3.0 * abs(ay));
    float rz = abs(1.0 - 3.0 * abs(az));
    float da = max(rx, ry);
    float db = max(ry, rz);
    float dc = max(rz, rx);
    float carved = (min(da, min(db, dc)) - 1.0) / scale;
    d = max(d, carved);
  }
  return d * 4.0;
}

float mandelbulbDistance(float x, float y, float z) {
  float px = x * 1.08;
  float py = y * 1.08;
  float pz = z * 1.08;
  float zx = px;
  float zy = py;
  float zz = pz;
  float dr = 1.0;
  float radius = 0.0;
  boolean escaped = false;
  float power = 8.0;
  for (int i = 0; i < 7; i++) {
    radius = sqrt(zx*zx + zy*zy + zz*zz);
    if (radius > 2.2) {
      escaped = true;
      break;
    }
    float safeRadius = max(radius, 0.00001);
    float theta = acos(constrain(zz / safeRadius, -1.0, 1.0));
    float phi = atan2(zy, zx);
    dr = pow(safeRadius, power - 1.0) * power * dr + 1.0;
    float zr = pow(safeRadius, power);
    theta *= power;
    phi *= power;
    zx = zr * sin(theta) * cos(phi) + px;
    zy = zr * sin(theta) * sin(phi) + py;
    zz = zr * cos(theta) + pz;
  }
  if (!escaped) return -0.18;
  return 1.25 * log(max(radius, 0.00001)) * radius / max(dr, 0.00001);
}

float mandelbrotCarrier(float x, float y) {
  float cx = x / 2.4 - 0.55 + 0.10 * sin(simT * 0.25);
  float cy = y / 2.4 + 0.10 * cos(simT * 0.21);
  float zx = 0;
  float zy = 0;
  int maxIter = 34;
  int count = maxIter;
  for (int i = 0; i < maxIter; i++) {
    float nx = zx * zx - zy * zy + cx;
    float ny = 2.0 * zx * zy + cy;
    zx = nx;
    zy = ny;
    if (zx * zx + zy * zy > 8.0) {
      count = i;
      break;
    }
  }
  return count / (float)maxIter;
}

float juliaCarrier(float x, float y) {
  float zx = x / 2.2;
  float zy = y / 2.2;
  float cRe = -0.72 + 0.08 * sin(simT * 0.31 + shaperPlasma);
  float cIm = 0.22 + 0.08 * cos(simT * 0.27 + shaperWater);
  int maxIter = 32;
  int count = maxIter;
  for (int i = 0; i < maxIter; i++) {
    float nx = zx * zx - zy * zy + cRe;
    float ny = 2.0 * zx * zy + cIm;
    zx = nx;
    zy = ny;
    if (zx * zx + zy * zy > 8.0) {
      count = i;
      break;
    }
  }
  return count / (float)maxIter;
}

float fractalRidgeCarrier(float x, float y, float z) {
  float value = 0;
  float amp = 0.55;
  float freq = 1.05;
  for (int octave = 0; octave < 5; octave++) {
    float phase = simT * (0.18 + octave * 0.07);
    float n = sin((x + phase) * freq * PI) * cos((y - phase * 0.7) * freq * PI);
    n += 0.55 * sin((x * 0.73 + y * 1.21 + z * 0.64 + phase) * freq * PI);
    value += amp * (1.0 - abs(n / 1.55));
    amp *= 0.52;
    freq *= 1.92;
  }
  return value;
}

void drawFoundryWrappedGeometryPreview(float scale) {
  float[] scores = currentTopologyScores();
  color ca = color(95, 225, 210);
  int n = 30;
  strokeWeight(1.05);
  for (int axis = 0; axis < 3; axis++) {
    stroke(axis == 0 ? color(95, 225, 210, 120) : axis == 1 ? color(255, 178, 88, 95) : color(130, 165, 255, 88));
    for (int row = 0; row < n; row += 3) {
      noFill();
      beginShape();
      for (int col = 0; col < n; col++) {
        float a = map(col, 0, n - 1, -1, 1);
        float b = map(row, 0, n - 1, -1, 1);
        float v;
        float x;
        float y;
        float z;
        if (axis == 0) {
          v = foundryScalar(a, b, 0, scores);
          x = a; y = b; z = v * 0.42;
        } else if (axis == 1) {
          v = foundryScalar(a, 0, b, scores);
          x = a; y = v * 0.42; z = b;
        } else {
          v = foundryScalar(0, a, b, scores);
          x = v * 0.42; y = a; z = b;
        }
        vertex(x * scale, y * scale, z * scale);
      }
      endShape();
    }
  }

  stroke(ca, 135);
  strokeWeight(2.0);
  beginShape(POINTS);
  for (int ix = 0; ix < 18; ix++) {
    float x = map(ix, 0, 17, -1, 1);
    for (int iy = 0; iy < 18; iy++) {
      float y = map(iy, 0, 17, -1, 1);
      for (int iz = 0; iz < 18; iz++) {
        float z = map(iz, 0, 17, -1, 1);
        float v = foundryScalar(x, y, z, scores);
        if (abs(v) < foundryIsoBand * 1.35 && (ix + iy + iz) % 2 == 0) {
          vertex(x * scale, y * scale, z * scale);
        }
      }
    }
  }
  endShape();
}

void drawStatusStrip() {
  int y = height - 28;
  MaterialProfile m = activeMaterial();
  String target = m == null ? "none" : m.name;
  noStroke();
  fill(8, 12, 17);
  rect(UI_W, y, width - UI_W, 28);
  fill(125, 160, 170);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("lens=" + lensNames[activeLens] +
       "   fps=" + nf(frameRate, 1, 1) +
       "   entropy=" + nf(metricEntropy, 1, 3) +
       "   Df=" + nf(metricFractal, 1, 3) +
       "   gamma=" + nf(holoGamma, 1, 3) +
       "   ctc=" + nf(ctcScore, 1, 3) +
       "   layers=" + (depth + 1) +
       "   falloff=" + nf(recursionFalloff(), 1, 2) +
       "   shaper=" + (shaperEnabled ? nf(shaperDrive * shaperMix, 1, 2) : "off") +
       "   target=" + target, UI_W + 18, y + 14);
}

void drawPanelShell(int x, int y, int w, int h, String title) {
  noStroke();
  fill(9, 13, 19);
  rect(x, y, w, h, 8);
  stroke(40, 64, 75);
  noFill();
  rect(x, y, w, h, 8);
  fill(210, 240, 235);
  textSize(13);
  textAlign(LEFT, TOP);
  text(title, x + 18, y + 16);
}

void drawReadoutPanel(int x, int y, int w, int h, String title) {
  noStroke();
  fill(5, 9, 14, 210);
  rect(x, y, w, h, 7);
  stroke(38, 66, 76);
  noFill();
  rect(x, y, w, h, 7);
  fill(145, 230, 215);
  textSize(10);
  textAlign(LEFT, TOP);
  text(title, x + 12, y + 10);
}

void drawHeatmap(float[][] data, int x, int y, int w, int h, int palette) {
  noStroke();
  float cw = (float)w / GRID;
  float ch = (float)h / GRID;
  int step = 2;
  for (int r = 0; r < GRID; r += step) {
    for (int c = 0; c < GRID; c += step) {
      fill(paletteColor(constrain(data[r][c], 0, 1), palette));
      rect(x + c * cw, y + r * ch, cw * step + 0.5, ch * step + 0.5);
    }
  }
  stroke(70, 95, 102);
  noFill();
  rect(x, y, w, h);
}

color paletteColor(float t, int p) {
  t = constrain(t, 0, 1);
  if (p == 1) {
    color a = color(8, 20, 30);
    color b = color(78, 205, 190);
    color c = color(255, 92, 118);
    return t < 0.55 ? lerpColor(a, b, t / 0.55) : lerpColor(b, c, (t - 0.55) / 0.45);
  }
  color a = color(5, 10, 24);
  color b = color(35, 110, 150);
  color c = color(110, 235, 175);
  color d = color(255, 174, 84);
  if (t < 0.42) return lerpColor(a, b, t / 0.42);
  if (t < 0.78) return lerpColor(b, c, (t - 0.42) / 0.36);
  return lerpColor(c, d, (t - 0.78) / 0.22);
}

void drawFieldThreads(int x, int y, int w, int h) {
  strokeWeight(0.7);
  for (int r = 4; r < GRID - 4; r += 7) {
    for (int c = 4; c < GRID - 4; c += 7) {
      float v = field[r][c];
      float gx = field[r][c + 1] - field[r][c - 1];
      float gy = field[r + 1][c] - field[r - 1][c];
      float px = x + c * w / (float)GRID;
      float py = y + r * h / (float)GRID;
      stroke(180, 245, 220, 40 + 105 * v);
      line(px, py, px + gx * 80, py + gy * 80);
    }
  }
}

void drawOrbitOverlay(int x, int y, int w, int h) {
  float cx = x + w / 2.0;
  float cy = y + h / 2.0;
  float scale = w * 0.38 / 1.2;
  noFill();
  stroke(255, 190, 80, 70);
  ellipse(cx, cy, scale * 2.4, scale * 2.4);
  for (int i = 1; i < orbitTrail.size(); i++) {
    PVector a = orbitTrail.get(i - 1);
    PVector b = orbitTrail.get(i);
    float fade = map(i, 1, orbitTrail.size(), 25, 210);
    stroke(255, 155, 80, fade);
    line(cx + a.x * scale, cy - a.y * scale, cx + b.x * scale, cy - b.y * scale);
  }
  noStroke();
  fill(255, 220, 120);
  ellipse(cx + orbitX * scale, cy - orbitY * scale, 12, 12);
}

void drawCrossSectionGraph(int x, int y, int w, int h) {
  fill(4, 8, 12);
  stroke(35, 62, 70);
  rect(x, y, w, h, 5);
  noFill();
  stroke(105, 230, 205);
  beginShape();
  for (int i = 0; i < GRID; i++) {
    vertex(x + map(i, 0, GRID - 1, 8, w - 8), y + h - 8 - cross[i] * (h - 16));
  }
  endShape();
}

void drawParticleWindow(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 5);
  noStroke();
  for (Particle p : particles) {
    float px = x + p.x * w;
    float py = y + p.y * h;
    fill(90 + 160 * p.energy, 190 + 50 * metricCoherence, 180 + 60 * phiThreshold, 38);
    ellipse(px, py, 2.2 + p.energy * 2.5, 2.2 + p.energy * 2.5);
  }
}

void drawTracePanel(int x, int y, int w, int h) {
  if (h < 80) return;
  drawReadoutPanel(x, y, w, h, "LIVE TRACES");
  int gx = x + 16;
  int gy = y + 42;
  int gw = w - 32;
  int gh = h - 60;
  fill(3, 7, 11);
  stroke(35, 62, 70);
  rect(gx, gy, gw, gh, 4);
  drawTrace(entropyTrace, gx, gy, gw, gh, color(255, 160, 80));
  drawTrace(fractalTrace, gx, gy, gw, gh, color(105, 230, 160));
  drawTrace(lyapTrace, gx, gy, gw, gh, color(255, 95, 115));
  drawTrace(coherenceTrace, gx, gy, gw, gh, color(110, 180, 255));
}

void drawTrace(float[] arr, int x, int y, int w, int h, color c) {
  stroke(c, 185);
  noFill();
  beginShape();
  for (int i = 0; i < w; i++) {
    int idx = (traceHead + i * arr.length / max(1, w)) % arr.length;
    vertex(x + i, y + h - constrain(arr[idx], 0, 1) * h);
  }
  endShape();
}

void drawGridLines(int x, int y, int w, int h, int count, color c) {
  stroke(c);
  strokeWeight(1);
  for (int i = 1; i < count; i++) {
    float xx = x + i * w / (float)count;
    float yy = y + i * h / (float)count;
    line(xx, y, xx, y + h);
    line(x, yy, x + w, yy);
  }
}

void drawHoloBraid(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 5);
  for (int strand = 0; strand < 5; strand++) {
    noFill();
    stroke(strand % 2 == 0 ? color(100, 235, 210, 180) : color(210, 140, 255, 165));
    beginShape();
    for (int i = 0; i < w; i++) {
      float u = i / max(1.0, (float)w);
      float gamma = holoGamma + strand * 0.45;
      float yy = y + h * (0.5 + 0.32 * sin(u * TWO_PI * (2 + strand) + gamma + simT * 0.4));
      yy += sin(u * TWO_PI + metricBeltrami * 4.0) * h * 0.08;
      vertex(x + i, yy);
    }
    endShape();
  }
}

void drawHolonomyCurvatureOverlay(float x, float y, float w, float h) {
  if (w < 8 || h < 8) return;
  int cols = 18;
  int rows = 18;
  noStroke();
  for (int r = 0; r < rows; r++) {
    float dv = r / max(1.0, rows - 1.0);
    for (int c = 0; c < cols; c++) {
      float av = c / max(1.0, cols - 1.0);
      float a = lerp(alpha - (0.58 + 0.32 * braneTwist), alpha + (0.58 + 0.32 * braneTwist), av);
      float d = lerp(depth - (1.1 + 1.8 * floquetCoupling), depth + (1.1 + 1.8 * floquetCoupling), 1.0 - dv);
      float curvature = sin(a * 2.2 + d * 0.62 + simT * 0.55)
                      * cos(d * 0.78 - braneTwist * TWO_PI + holoGamma);
      curvature += (metricBeltrami - 0.5) * 0.85 + (phiThreshold - 0.5) * 0.45;
      float p = constrain(0.5 + curvature * 0.32, 0, 1);
      color ca = lerpColor(color(60, 120, 170), color(255, 180, 82), p);
      fill(red(ca), green(ca), blue(ca), 28 + 58 * abs(p - 0.5) * 2.0);
      rect(x + c * w / cols, y + r * h / rows, w / cols + 1, h / rows + 1);
    }
  }
}

void drawHolonomyLoopFibers(float x, float y, float w, float h) {
  if (w < 18 || h < 18) return;
  int strands = 6;
  for (int s = 0; s < strands; s++) {
    float strandPhase = s * 0.62 + holoGamma * (reverseHolonomy ? -1 : 1);
    color ca = s % 2 == 0 ? color(95, 235, 210) : color(215, 145, 255);
    stroke(red(ca), green(ca), blue(ca), 105 + s * 15);
    strokeWeight(s == 0 ? 2.2 : 1.15);
    noFill();
    beginShape();
    for (int i = 0; i <= 280; i++) {
      float u = i / 280.0;
      float[] pt = loopRectPoint(x, y, w, h, u);
      float nudge = (s - (strands - 1) * 0.5) * 2.2
                  + sin(u * TWO_PI * (2 + s) + strandPhase + simT * 0.35) * 4.8;
      vertex(pt[0] + pt[2] * nudge, pt[1] + pt[3] * nudge);
    }
    endShape(CLOSE);
  }

  noStroke();
  fill(255, 230, 120, 220);
  ellipse(x, y, 6, 6);
  ellipse(x + w, y, 6, 6);
  ellipse(x + w, y + h, 6, 6);
  ellipse(x, y + h, 6, 6);
}

float[] loopRectPoint(float x, float y, float w, float h, float u) {
  u = (u % 1.0 + 1.0) % 1.0;
  float px = x;
  float py = y;
  float nx = 0;
  float ny = -1;
  if (u < 0.25) {
    float t = u / 0.25;
    px = lerp(x, x + w, t);
    py = y;
    nx = 0; ny = -1;
  } else if (u < 0.5) {
    float t = (u - 0.25) / 0.25;
    px = x + w;
    py = lerp(y, y + h, t);
    nx = 1; ny = 0;
  } else if (u < 0.75) {
    float t = (u - 0.5) / 0.25;
    px = lerp(x + w, x, t);
    py = y + h;
    nx = 0; ny = 1;
  } else {
    float t = (u - 0.75) / 0.25;
    px = x;
    py = lerp(y + h, y, t);
    nx = -1; ny = 0;
  }
  return new float[] { px, py, nx, ny };
}

void drawResidualContours(int x, int y, int w, int h) {
  strokeWeight(1.1);
  for (int r = 3; r < GRID - 3; r += 5) {
    for (int c = 3; c < GRID - 3; c += 5) {
      float v = residual[r][c];
      if (v > 0.68) {
        float px = x + c * w / (float)GRID;
        float py = y + r * h / (float)GRID;
        stroke(255, 120, 120, map(v, 0.68, 1, 35, 170));
        noFill();
        ellipse(px, py, map(v, 0.68, 1, 4, 18), map(v, 0.68, 1, 4, 18));
      }
    }
  }
}

void drawThresholdGlyph(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(35, 62, 70);
  rect(x, y, w, h, 5);
  float cx = x + w * 0.5;
  float cy = y + h * 0.52;
  float r = min(w, h) * 0.34;
  for (int i = 0; i < 5; i++) {
    float p = constrain(phiThreshold + i * 0.08, 0, 1.2);
    stroke(lerpColor(color(90, 220, 205), color(255, 90, 115), constrain(p, 0, 1)), 60 + 38 * i);
    noFill();
    ellipse(cx, cy, r * 2 * (0.55 + p * 0.26 + i * 0.08), r * 1.15 * (0.55 + p * 0.26 + i * 0.08));
  }
  stroke(255, 190, 80);
  float sweep = TWO_PI * constrain(phiThreshold, 0, 1);
  arc(cx, cy, r * 2.2, r * 2.2, -HALF_PI, -HALF_PI + sweep);
}

void drawFloquetRadial(int cx, int cy, float rad) {
  noFill();
  stroke(34, 62, 72);
  for (int i = 1; i <= 5; i++) ellipse(cx, cy, rad * 2 * i / 5.0, rad * 2 * i / 5.0);
  stroke(90, 230, 210);
  strokeWeight(1.5);
  beginShape();
  for (int i = 0; i <= 420; i++) {
    float a = TWO_PI * i / 420.0;
    float rr = rad * (0.58 + 0.08 * sin(a * 3 + simT) + 0.18 * evaluateFloquet(a / TWO_PI + simT * 0.1));
    vertex(cx + cos(a) * rr, cy + sin(a) * rr);
  }
  endShape(CLOSE);
  for (int n = 0; n < 8; n++) {
    float a = TWO_PI * n / 8.0 + simT * 0.12;
    float rr = rad * (0.35 + abs(floquetNu[n]) * 1.15);
    stroke(255, 175, 80, 150);
    line(cx, cy, cx + cos(a) * rr, cy + sin(a) * rr);
    fill(255, 175, 80);
    noStroke();
    ellipse(cx + cos(a) * rr, cy + sin(a) * rr, 7, 7);
  }
}

void drawFloquetWave(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 5);
  stroke(255, 184, 84);
  noFill();
  beginShape();
  for (int i = 0; i < w; i++) {
    int idx = (floquetHead + i * floquetHistory.length / max(1, w)) % floquetHistory.length;
    vertex(x + i, y + h * 0.5 - floquetHistory[idx] * h * 0.32);
  }
  endShape();
}

void drawCTCRings(int cx, int cy, float r) {
  noFill();
  for (int i = 0; i < 8; i++) {
    float p = ctcScore;
    stroke(lerpColor(color(75, 130, 160), color(255, 80, 120), p), 38 + i * 18);
    strokeWeight(0.8 + p * 2.2);
    ellipse(cx, cy, r * 2 * (0.56 + i * 0.08 + p * 0.08), r * (0.78 + i * 0.05 - p * 0.05));
  }
  stroke(100, 230, 210);
  beginShape();
  for (int i = 0; i < orbitTrail.size(); i++) {
    PVector p = orbitTrail.get(i);
    float fade = map(i, 0, orbitTrail.size(), 20, 230);
    stroke(100, 230, 210, fade);
    vertex(cx + p.x * r * 0.8, cy - p.y * r * 0.8);
  }
  endShape();
  float sweep = TWO_PI * ctcScore;
  stroke(255, 190, 80, 230);
  strokeWeight(4);
  arc(cx, cy, r * 2.4, r * 2.4, -HALF_PI, -HALF_PI + sweep);
  if (ctcScore > 0.62) {
    stroke(255, 90, 120, 180);
    line(cx - r * 0.55, cy, cx + r * 0.55, cy);
    line(cx, cy - r * 0.55, cx, cy + r * 0.55);
  }
}

void drawWignerPlot(int x, int y, int w, int h) {
  fill(3, 7, 11);
  stroke(44, 70, 80);
  rect(x, y, w, h, 6);
  noStroke();
  int step = 5;
  for (int yy = 0; yy < h; yy += step) {
    float p = map(yy, 0, h, -PI, PI);
    for (int xx = 0; xx < w; xx += step) {
      float q = map(xx, 0, w, -PI, PI);
      float v = sin(q * (2 + depth * 0.35) + holoGamma)
              * cos(p * (1.5 + alpha * 0.2) - simT)
              * exp(-0.12 * (q*q + p*p));
      v += 0.35 * sin((q + p) * 2.0 + metricHelicity * TWO_PI);
      float neg = v < 0 ? constrain(abs(v), 0, 1) : 0;
      float pos = v > 0 ? constrain(v, 0, 1) : 0;
      fill(60 + 170 * pos, 80 + 130 * pos, 120 + 120 * neg, 70 + 150 * max(pos, neg));
      rect(x + xx, y + yy, step + 1, step + 1);
    }
  }
  stroke(90, 120, 130);
  line(x, y + h / 2, x + w, y + h / 2);
  line(x + w / 2, y, x + w / 2, y + h);
}

void drawBornBars(int x, int y, int w, int h) {
  float[] vals = new float[4];
  vals[0] = constrain(0.25 + (orbitX < 0 && orbitY > 0 ? 0.22 : -0.04) + metricCoherence * 0.15, 0.02, 1);
  vals[1] = constrain(0.25 + (orbitX > 0 && orbitY > 0 ? 0.22 : -0.04) + metricHelicity * 0.12, 0.02, 1);
  vals[2] = constrain(0.25 + (orbitX < 0 && orbitY < 0 ? 0.22 : -0.04) + metricEntropy * 0.12, 0.02, 1);
  vals[3] = constrain(0.25 + (orbitX > 0 && orbitY < 0 ? 0.22 : -0.04) + wignerNegativity * 0.15, 0.02, 1);
  float sum = vals[0] + vals[1] + vals[2] + vals[3];
  String[] names = {"NW", "NE", "SW", "SE"};
  for (int i = 0; i < 4; i++) {
    float v = vals[i] / sum;
    int by = y + i * (h / 4);
    fill(20, 32, 40);
    rect(x, by, w, 14, 3);
    fill(i % 2 == 0 ? color(105, 230, 180) : color(155, 160, 255));
    rect(x, by, w * v, 14, 3);
    fill(210);
    textSize(9);
    textAlign(LEFT, CENTER);
    text(names[i] + "  " + nf(v, 1, 3), x + 6, by + 7);
  }
}

void drawInteractingBraneSystem(float scale) {
  hint(DISABLE_DEPTH_TEST);

  pushMatrix();
  translate(-scale * 0.18, -scale * 0.01, 0);
  rotateY(-0.28 + 0.10 * sin(simT * 0.22));
  drawClosedBraneManifold(scale * 0.86, color(0, 210, 200), 0.0);
  popMatrix();

  pushMatrix();
  translate(scale * 0.20, scale * 0.02, scale * 0.08);
  rotateX(0.18);
  rotateY(0.46 + 0.12 * cos(simT * 0.20));
  rotateZ(0.34);
  drawClosedBraneManifold(scale * 0.74, color(255, 170, 80), PI * 0.55);
  popMatrix();

  drawBraneOverlapRibbon(scale);
  drawHopfFibrationWindings(scale);

  hint(ENABLE_DEPTH_TEST);
}

void drawClosedBraneManifold(float scale, color baseCol, float phaseShift) {
  int uRes = 48;
  int vRes = 22;
  float major = scale * 0.70;
  float minor = scale * (0.20 + braneTwist * 0.045);
  float rBase = red(baseCol);
  float gBase = green(baseCol);
  float bBase = blue(baseCol);

  stroke(rBase * 0.65, gBase * 0.85, bBase * 0.85, 70);
  fill(rBase * 0.10, gBase * 0.20, bBase * 0.22, 16);
  for (int vIdx = 0; vIdx < vRes; vIdx++) {
    float v0 = TWO_PI * vIdx / (float)vRes;
    float v1 = TWO_PI * (vIdx + 1) / (float)vRes;
    beginShape(TRIANGLE_STRIP);
    for (int uIdx = 0; uIdx <= uRes; uIdx++) {
      float u = TWO_PI * uIdx / (float)uRes;
      braneVertex(u, v0, major, minor, scale, true, baseCol, phaseShift);
      braneVertex(u, v1, major, minor, scale, true, baseCol, phaseShift);
    }
    endShape();
  }

  stroke(rBase * 0.78 + 55, gBase * 0.78 + 55, bBase * 0.78 + 55, 170);
  strokeWeight(1.1);
  noFill();
  for (int lane = 0; lane < 8; lane++) {
    float v = TWO_PI * lane / 8.0;
    beginShape();
    for (int uIdx = 0; uIdx <= uRes; uIdx++) {
      float u = TWO_PI * uIdx / (float)uRes;
      braneVertex(u, v, major, minor * 1.012, scale, false, baseCol, phaseShift);
    }
    endShape(CLOSE);
  }

  stroke(rBase * 0.45 + 42, gBase * 0.55 + 70, bBase * 0.55 + 70, 130);
  for (int lane = 0; lane < 12; lane++) {
    float u = TWO_PI * lane / 12.0 + simT * 0.025;
    beginShape();
    for (int vIdx = 0; vIdx <= vRes; vIdx++) {
      float v = TWO_PI * vIdx / (float)vRes;
      braneVertex(u, v, major, minor * 1.014, scale, false, baseCol, phaseShift);
    }
    endShape(CLOSE);
  }
}

void braneVertex(float u, float v, float major, float minor, float scale, boolean shaded, color baseCol, float phaseShift) {
  float pulse = 1.0 + 0.055 * sin(3.0 * u + 2.0 * v + simT + holoGamma + phaseShift);
  float seam = 0.035 * sin((2 + depth % 4) * u - v + braneTwist * TWO_PI + phaseShift);
  float tube = minor * pulse;
  float x = (major + tube * cos(v)) * cos(u);
  float y = (major + tube * cos(v)) * sin(u);
  float z = tube * sin(v) + seam * scale;
  if (shaded) {
    float light = 0.45 + 0.55 * constrain((sin(v) + 1.0) * 0.5, 0, 1);
    fill(red(baseCol) * (0.08 + 0.14 * light),
         green(baseCol) * (0.16 + 0.24 * light),
         blue(baseCol) * (0.18 + 0.26 * light),
         16 + 18 * light);
  }
  vertex(x, y, z);
}

void drawBraneOverlapRibbon(float scale) {
  float major = scale * 0.55;
  float amp = scale * (0.10 + 0.07 * braneTwist);
  strokeWeight(2.1);
  noFill();
  for (int lane = 0; lane < 5; lane++) {
    float off = lane * 0.24;
    stroke(255, 230, 130, 78 + lane * 22);
    beginShape();
    for (int i = 0; i <= 260; i++) {
      float u = TWO_PI * i / 260.0;
      float pinch = sin(u * 2.0 + holoGamma + off);
      float x = cos(u) * (major + amp * pinch);
      float y = sin(u) * (scale * 0.23 + amp * 0.25 * cos(u * 3.0 + off));
      float z = sin(u * 3.0 + simT + off) * scale * 0.10;
      vertex(x, y, z);
    }
    endShape(CLOSE);
  }
}

void drawHopfFibrationWindings(float scale) {
  float major = scale * 0.70;
  float minor = scale * (0.20 + braneTwist * 0.045);
  int strands = 18;
  int turns = 2 + depth % 5;

  for (int k = 0; k < strands; k++) {
    float off = TWO_PI * k / (float)strands;
    float lift = 1.05 + 0.014 * (k % 4);
    color c = lerpColor(color(118, 240, 216), color(255, 176, 84), k / (float)(strands - 1));
    stroke(c, 175);
    strokeWeight(k % 4 == 0 ? 2.15 : 1.18);
    noFill();
    beginShape();
    for (int i = 0; i <= 640; i++) {
      float u = TWO_PI * i / 640.0;
      float bridge = 0.22 * sin(u + off + metricHelicity * TWO_PI);
      float v = turns * u + off + holoGamma * 0.55 + 0.18 * sin(u * 3.0 + simT);
      float pulse = 1.0 + 0.045 * sin(3.0 * u + 2.0 * v + simT + holoGamma);
      float tube = minor * lift * pulse;
      float x = (major + tube * cos(v)) * cos(u) + bridge * scale * 0.22;
      float y = (major + tube * cos(v)) * sin(u) - bridge * scale * 0.10;
      float z = tube * sin(v) * (0.88 + metricBeltrami * 0.18) + bridge * scale * 0.14;
      vertex(x, y, z);
    }
    endShape(CLOSE);
  }

  stroke(210, 246, 238, 120);
  strokeWeight(1.0);
  noFill();
  for (int nested = 0; nested < 6; nested++) {
    float v = TWO_PI * nested / 6.0 + simT * 0.10;
    beginShape();
    for (int i = 0; i <= 360; i++) {
      float u = TWO_PI * i / 360.0;
      float tube = minor * (0.72 + nested * 0.08);
      float x = (major + tube * cos(v)) * cos(u);
      float y = (major + tube * cos(v)) * sin(u);
      float z = tube * sin(v);
      vertex(x, y, z);
    }
    endShape(CLOSE);
  }
}

void topologyScores(float[] s) {
  topologyScoresFor(alpha, depth, s);
}

void topologyScoresFor(float a, float d, float[] s) {
  float aN = constrain((a - 1.0) / (ALPHA_MAX - 1.0), 0, 1);
  float dN = constrain(d / (float)DEPTH_MAX, 0, 1);
  float entropyN = constrain(metricEntropy, 0, 1);
  float coherent = constrain(metricCoherence * 0.65 + coherenceBias * 0.35, 0, 1);
  float thresholdN = constrain(phiThreshold, 0, 1);
  float holoN = constrain(abs(holoGamma) / PI, 0, 1);

  s[0] = constrain(0.22 + coherent * 0.34 + floquetCoupling * 0.20 + (1.0 - entropyN) * 0.16 + (1.0 - abs(aN - 0.52) * 1.6) * 0.12, 0, 1);
  s[1] = constrain(0.16 + metricBeltrami * 0.30 + coherent * 0.24 + (1.0 - abs(aN - 0.44) * 1.8) * 0.22 + (1.0 - abs(dN - 0.44) * 1.5) * 0.12, 0, 1);
  s[2] = constrain(0.12 + thresholdN * 0.28 + sourcePressure * 0.22 + entropyN * 0.18 + dN * 0.12, 0, 1);
  s[3] = constrain(0.12 + dN * 0.30 + constrain((metricFractal - 1.0) / 1.55, 0, 1) * 0.28 + metricMI * 0.16 + (1.0 - abs(aN - 0.72) * 1.5) * 0.12, 0, 1);
  s[4] = constrain(0.10 + quasiEnergy * 0.26 + holoN * 0.25 + braneTwist * 0.20 + (1.0 - coherent) * 0.10 + abs(aN - dN) * 0.10, 0, 1);

  float sum = 0;
  for (int i = 0; i < 5; i++) sum += max(0.001, s[i]);
  for (int i = 0; i < 5; i++) s[i] = max(0.001, s[i]) / sum;
}

int activeTopologyIndex(float[] s) {
  int idx = 0;
  float best = s[0];
  for (int i = 1; i < 5; i++) {
    if (s[i] > best) {
      best = s[i];
      idx = i;
    }
  }
  return idx;
}

float topologyConfidence(float[] s) {
  float best = -1;
  float second = -1;
  for (int i = 0; i < 5; i++) {
    if (s[i] > best) {
      second = best;
      best = s[i];
    } else if (s[i] > second) {
      second = s[i];
    }
  }
  return constrain((best - second) * 3.6, 0, 1);
}

String topologyName(int idx) {
  if (idx == 0) return "B-GYROID";
  if (idx == 1) return "B-DIAMOND";
  if (idx == 2) return "IWP WALL";
  if (idx == 3) return "BCC NODE";
  return "BRACHISTO";
}

color topologyColor(int idx) {
  if (idx == 0) return color(105, 238, 202);
  if (idx == 1) return color(128, 170, 255);
  if (idx == 2) return color(255, 150, 92);
  if (idx == 3) return color(190, 235, 120);
  return color(255, 196, 80);
}

float topologyScalar(float x, float y, float z, float[] s) {
  float freq = PI * (1.25 + depth * 0.085);
  float X = x * freq + simT * 0.16;
  float Y = y * freq - simT * 0.11;
  float Z = z * freq + braneTwist * TWO_PI;

  float gyroid = (sin(X) * cos(Y) + sin(Y) * cos(Z) + sin(Z) * cos(X)) / 1.7;
  float diamond = cos(X) * cos(Y) * cos(Z) - sin(X) * sin(Y) * sin(Z);
  float iwp = (cos(X) + cos(Y) + cos(Z) - 0.45 * cos(X) * cos(Y) * cos(Z)) / 2.2;
  float bcc = (sin(X) * sin(Y) + sin(Y) * sin(Z) + sin(Z) * sin(X)) / 1.8;
  float brach = bsin(X * 0.65 + Z * 0.22) * 0.40 + bsin(Y * 0.72 - Z * 0.18) * 0.34 + sin(X * 0.35 + Y * 0.35 + Z) * 0.24;
  float v = gyroid * s[0] + diamond * s[1] + iwp * s[2] + bcc * s[3] + brach * s[4];
  if (shaperEnabled) {
    float plasmaWarp = sin(X * 0.72 + shaperPlasma * TWO_PI + simT * 0.21) * 0.08;
    float waterWarp = cos(Y * 0.58 - shaperWater * TWO_PI + Z * 0.22) * 0.07;
    float torsionWarp = sin((X + Y + Z) * 0.32 + shaperCosmic * TWO_PI) * 0.06;
    v += shaperMix * (plasmaWarp + waterWarp + torsionWarp);
  }
  return v - (sourcePressure - 0.65) * 0.18 + (quasiEnergy - 0.5) * 0.08;
}

void drawTopologyPhaseCell(int x, int y, int w, int h, float[] scores, int active, float confidence) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 6);

  pushMatrix();
  translate(x + w * 0.50, y + h * 0.52, -80);
  rotateX(0.74);
  rotateY(-0.46 + 0.12 * sin(simT * 0.23));
  rotateZ(simT * 0.08);
  float scale = min(w, h) * 0.36;

  stroke(40, 75, 85, 42);
  noFill();
  box(scale * 2.16);

  float isoBand = 0.070 + (1.0 - confidence) * 0.045;
  drawTopologyManifoldMesh(scores, active, scale, isoBand);
  drawTopologySkeleton(scores, active, scale);
  drawAnchoredTopologyFibers(scores, active, scale);
  popMatrix();

  fill(150, 185, 190);
  textSize(9);
  textAlign(LEFT, BOTTOM);
  text(topologyName(active) + " connected surface / skeleton / fibers", x + 12, y + h - 12);
  textAlign(RIGHT, BOTTOM);
  text("iso band " + nf(isoBand, 1, 3), x + w - 12, y + h - 12);
}

void drawTopologyManifoldMesh(float[] scores, int active, float scale, float isoBand) {
  int samples = 21;
  boolean[][][] near = new boolean[samples][samples][samples];
  float[][][] weight = new float[samples][samples][samples];
  for (int xi = 0; xi < samples; xi++) {
    float xx = map(xi, 0, samples - 1, -1, 1);
    for (int yi = 0; yi < samples; yi++) {
      float yy = map(yi, 0, samples - 1, -1, 1);
      for (int zi = 0; zi < samples; zi++) {
        float zz = map(zi, 0, samples - 1, -1, 1);
        float val = topologyScalar(xx, yy, zz, scores);
        if (abs(val) < isoBand) {
          near[xi][yi][zi] = true;
          weight[xi][yi][zi] = 1.0 - abs(val) / isoBand;
        }
      }
    }
  }

  color ca = topologyColor(active);
  strokeWeight(1.0);
  for (int xi = 0; xi < samples; xi++) {
    for (int yi = 0; yi < samples; yi++) {
      for (int zi = 0; zi < samples; zi++) {
        if (!near[xi][yi][zi]) continue;
        drawManifoldNeighbor(near, weight, xi, yi, zi, xi + 1, yi, zi, samples, scale, ca);
        drawManifoldNeighbor(near, weight, xi, yi, zi, xi, yi + 1, zi, samples, scale, ca);
        drawManifoldNeighbor(near, weight, xi, yi, zi, xi, yi, zi + 1, samples, scale, ca);
      }
    }
  }

  strokeWeight(2.4);
  beginShape(POINTS);
  for (int xi = 0; xi < samples; xi++) {
    for (int yi = 0; yi < samples; yi++) {
      for (int zi = 0; zi < samples; zi++) {
        if (near[xi][yi][zi] && (xi + yi + zi) % 2 == 0) {
          float glow = 80 + weight[xi][yi][zi] * 155;
          stroke(red(ca), green(ca), blue(ca), glow);
          vertex(gridCoord(xi, samples, scale), gridCoord(yi, samples, scale), gridCoord(zi, samples, scale));
        }
      }
    }
  }
  endShape();
}

void drawManifoldNeighbor(boolean[][][] near, float[][][] weight, int x0, int y0, int z0, int x1, int y1, int z1, int samples, float scale, color ca) {
  if (x1 < 0 || x1 >= samples || y1 < 0 || y1 >= samples || z1 < 0 || z1 >= samples) return;
  if (!near[x1][y1][z1]) return;
  float glow = 42 + (weight[x0][y0][z0] + weight[x1][y1][z1]) * 66;
  stroke(red(ca), green(ca), blue(ca), glow);
  line(gridCoord(x0, samples, scale), gridCoord(y0, samples, scale), gridCoord(z0, samples, scale),
       gridCoord(x1, samples, scale), gridCoord(y1, samples, scale), gridCoord(z1, samples, scale));
}

float gridCoord(int idx, int samples, float scale) {
  return map(idx, 0, samples - 1, -1, 1) * scale;
}

void drawTopologySkeleton(float[] scores, int active, float scale) {
  color ca = topologyColor(active);
  float r = scale * 0.72;
  drawTopologySkeletonLoop(scores, 0, r, ca);
  drawTopologySkeletonLoop(scores, 1, r * 0.86, color(255, 185, 90));
  drawTopologySkeletonLoop(scores, 2, r * 0.78, color(145, 170, 255));

  PVector[] nodes = topologyNodes(scale);
  stroke(165, 216, 224, 38);
  strokeWeight(0.8);
  for (int i = 0; i < nodes.length; i++) {
    for (int j = i + 1; j < nodes.length; j++) {
      if ((i + j) % 2 == 1 || abs(i - j) == 3) {
        line(nodes[i].x, nodes[i].y, nodes[i].z, nodes[j].x, nodes[j].y, nodes[j].z);
      }
    }
  }

  for (int i = 0; i < nodes.length; i++) {
    drawTopologyNode(nodes[i], i == active ? 6.4 : 4.2, i == active ? color(255, 230, 118) : ca);
  }
}

void drawTopologySkeletonLoop(float[] scores, int axis, float r, color ca) {
  stroke(red(ca), green(ca), blue(ca), 92);
  strokeWeight(1.35);
  noFill();
  beginShape();
  for (int i = 0; i <= 240; i++) {
    float u = TWO_PI * i / 240.0;
    float x = cos(u) * r;
    float y = sin(u) * r;
    float z = 0;
    float scalar = topologyScalar(cos(u) * 0.72, sin(u) * 0.72, sin(u * 2.0 + axis) * 0.25, scores);
    float lift = scalar * r * 0.22 + sin(u * 3.0 + simT + axis) * r * 0.055;
    if (axis == 0) {
      z = lift;
    } else if (axis == 1) {
      z = y;
      y = lift;
    } else {
      z = x;
      x = lift;
    }
    vertex(x, y, z);
  }
  endShape(CLOSE);
}

void drawTopologyNode(PVector p, float radius, color ca) {
  pushMatrix();
  translate(p.x, p.y, p.z);
  noStroke();
  fill(red(ca), green(ca), blue(ca), 215);
  sphere(radius);
  popMatrix();
}

PVector[] topologyNodes(float scale) {
  float r = scale * 0.72;
  PVector[] nodes = new PVector[6];
  nodes[0] = new PVector(r, 0, 0);
  nodes[1] = new PVector(-r, 0, 0);
  nodes[2] = new PVector(0, r, 0);
  nodes[3] = new PVector(0, -r, 0);
  nodes[4] = new PVector(0, 0, r * 0.82);
  nodes[5] = new PVector(0, 0, -r * 0.82);
  return nodes;
}

void drawAnchoredTopologyFibers(float[] scores, int active, float scale) {
  PVector[] nodes = topologyNodes(scale);
  int[][] pairs = {
    {0, 2}, {2, 1}, {1, 3}, {3, 0},
    {4, 0}, {4, 2}, {5, 1}, {5, 3}
  };
  for (int n = 0; n < nodes.length; n++) {
    drawTopologyAnchorSocket(nodes[n], n == active ? color(255, 230, 118) : topologyColor(active), scale, n);
  }
  for (int i = 0; i < pairs.length; i++) {
    color ca = lerpColor(topologyColor(active), color(255, 180, 86), i / max(1.0, pairs.length - 1.0));
    drawAnchoredFiber(nodes[pairs[i][0]], nodes[pairs[i][1]], scores, scale, i, ca);
  }
}

void drawAnchoredFiber(PVector a, PVector b, float[] scores, float scale, int idx, color ca) {
  for (int echo = 4; echo >= 0; echo--) {
    float lag = echo * 0.115;
    float fade = map(echo, 0, 4, 118, 18);
    stroke(red(ca), green(ca), blue(ca), fade);
    strokeWeight(map(echo, 0, 4, 2.1, 0.65));
    noFill();
    beginShape();
    for (int i = 0; i <= 110; i++) {
      float t = i / 110.0;
      PVector p = topologyFiberPoint(a, b, scores, scale, idx, t, lag);
      vertex(p.x, p.y, p.z);
    }
    endShape();
  }

  drawTransportRibbon(a, b, scores, scale, idx, ca);

  float beadT = (simT * 0.18 + idx * 0.137) % 1.0;
  if (beadT < 0) beadT += 1.0;
  for (int wake = 3; wake >= 1; wake--) {
    float wt = beadT - wake * 0.055;
    if (wt < 0) wt += 1.0;
    PVector ghost = topologyFiberPoint(a, b, scores, scale, idx, wt, wake * 0.045);
    pushMatrix();
    translate(ghost.x, ghost.y, ghost.z);
    noStroke();
    fill(red(ca), green(ca), blue(ca), 24 + wake * 18);
    sphere(2.1 + wake * 0.55);
    popMatrix();
  }
  PVector bead = topologyFiberPoint(a, b, scores, scale, idx, beadT, 0);
  pushMatrix();
  translate(bead.x, bead.y, bead.z);
  noStroke();
  fill(255, 238, 160, 205);
  sphere(3.8 + 2.2 * metricBeltrami);
  popMatrix();
}

void drawTransportRibbon(PVector a, PVector b, float[] scores, float scale, int idx, color ca) {
  noStroke();
  fill(red(ca), green(ca), blue(ca), 34);
  beginShape(TRIANGLE_STRIP);
  for (int i = 0; i <= 96; i++) {
    float t = i / 96.0;
    PVector p = topologyFiberPoint(a, b, scores, scale, idx, t, 0);
    PVector pa = topologyFiberPoint(a, b, scores, scale, idx, max(0, t - 0.015), 0);
    PVector pb = topologyFiberPoint(a, b, scores, scale, idx, min(1, t + 0.015), 0);
    PVector dir = PVector.sub(pb, pa);
    PVector side = new PVector(-dir.y, dir.x, 0);
    if (side.mag() < 0.0001) side = new PVector(1, 0, 0);
    side.normalize();
    float width = scale * (0.010 + 0.010 * metricBeltrami) * sin(PI * t);
    vertex(p.x + side.x * width, p.y + side.y * width, p.z + side.z * width);
    vertex(p.x - side.x * width, p.y - side.y * width, p.z - side.z * width);
  }
  endShape();
}

PVector topologyFiberPoint(PVector a, PVector b, float[] scores, float scale, int idx, float t, float phaseLag) {
  t = constrain(t, 0, 1);
  float ease = 0.5 - 0.5 * cos(t * PI);
  float x = lerp(a.x, b.x, ease);
  float y = lerp(a.y, b.y, ease);
  float z = lerp(a.z, b.z, ease);
  float phase = holoGamma - phaseLag * TWO_PI + simT * 0.20;
  float nx = sin(t * TWO_PI + idx * 0.73 + phase);
  float ny = cos(t * TWO_PI * 1.4 + idx * 0.41 + phase * 0.65);
  float nz = sin(t * TWO_PI * 0.7 + idx + braneTwist * TWO_PI - phaseLag * 3.0);
  float scalar = topologyScalar(constrain(x / scale, -1, 1), constrain(y / scale, -1, 1), constrain(z / scale, -1, 1), scores);
  float surfacePull = constrain(1.0 - abs(scalar) * 2.2, 0.28, 1.0);
  float amp = scale * (0.038 + 0.026 * metricBeltrami) * sin(t * PI) * surfacePull;
  float boundFade = constrain(1.0 - max(0, max(abs(x), max(abs(y), abs(z))) / (scale * 1.03)), 0.36, 1.0);
  return new PVector(x + nx * amp * boundFade + scalar * scale * 0.018,
                     y + ny * amp * boundFade,
                     z + nz * amp * boundFade - scalar * scale * 0.018);
}

void drawTopologyAnchorSocket(PVector p, color ca, float scale, int idx) {
  pushMatrix();
  translate(p.x, p.y, p.z);
  rotateX(simT * 0.18 + idx * 0.4);
  rotateY(simT * 0.13 + idx * 0.7);
  noFill();
  stroke(red(ca), green(ca), blue(ca), 82);
  strokeWeight(1.1);
  beginShape();
  float r = scale * 0.030;
  for (int i = 0; i <= 54; i++) {
    float u = TWO_PI * i / 54.0;
    vertex(cos(u) * r, sin(u) * r, 0);
  }
  endShape(CLOSE);
  noStroke();
  fill(red(ca), green(ca), blue(ca), 64);
  sphere(scale * 0.012);
  popMatrix();
}

void drawTopologyContourSheet(float[] scores, int axis, float scale, color c) {
  int n = 34;
  stroke(c, 95);
  strokeWeight(1.05);
  noFill();
  for (int row = 0; row < n; row += 2) {
    beginShape();
    for (int col = 0; col < n; col++) {
      float a = map(col, 0, n - 1, -1, 1);
      float b = map(row, 0, n - 1, -1, 1);
      float v;
      float x;
      float y;
      float z;
      if (axis == 0) {
        v = topologyScalar(a, b, 0, scores);
        x = a; y = b; z = v * 0.24;
      } else if (axis == 1) {
        v = topologyScalar(a, 0, b, scores);
        x = a; y = v * 0.24; z = b;
      } else {
        v = topologyScalar(0, a, b, scores);
        x = v * 0.24; y = a; z = b;
      }
      vertex(x * scale, y * scale, z * scale);
    }
    endShape();
  }
}

void drawTopologyPhaseMap(int x, int y, int w, int h) {
  int cols = 36;
  int rows = 24;
  float[] local = new float[5];
  noStroke();
  for (int r = 0; r < rows; r++) {
    float d = map(r, rows - 1, 0, 0, DEPTH_MAX);
    for (int c = 0; c < cols; c++) {
      float a = map(c, 0, cols - 1, 1.0, ALPHA_MAX);
      topologyScoresFor(a, d, local);
      int idx = activeTopologyIndex(local);
      float conf = topologyConfidence(local);
      color tc = topologyColor(idx);
      fill(red(tc) * (0.32 + conf * 0.42), green(tc) * (0.32 + conf * 0.42), blue(tc) * (0.32 + conf * 0.42), 225);
      rect(x + c * w / (float)cols, y + r * h / (float)rows, w / (float)cols + 1, h / (float)rows + 1);
    }
  }
  stroke(25, 45, 55);
  noFill();
  rect(x, y, w, h);
  float px = map(alpha, 1.0, ALPHA_MAX, x, x + w);
  float py = map(depth, 0, DEPTH_MAX, y + h, y);
  stroke(245, 255, 230);
  strokeWeight(1.4);
  line(px - 8, py, px + 8, py);
  line(px, py - 8, px, py + 8);
  noStroke();
  fill(255, 230, 120);
  ellipse(px, py, 7, 7);
  fill(120, 150, 160);
  textSize(8);
  textAlign(LEFT, TOP);
  text("alpha", x, y + h + 7);
  textAlign(RIGHT, TOP);
  text("depth", x + w, y + h + 7);
}

void drawTopologyMetrics(int x, int y, int w, float[] scores, float confidence) {
  float tunnelDensity = constrain(scores[0] * 0.72 + scores[1] * 0.58 + scores[2] * 0.62 + depth / (float)DEPTH_MAX * 0.24, 0, 1);
  float surfaceVolume = constrain((metricFractal - 1.0) / 1.55 * 0.56 + metricEntropy * 0.24 + sourcePressure * 0.16, 0, 1);
  float curvatureVariance = constrain(metricEntropy * 0.28 + phiThreshold * 0.30 + quasiEnergy * 0.22 + braneTwist * 0.12, 0, 1);
  float connectedness = constrain(metricCoherence * 0.38 + metricBeltrami * 0.30 + scores[3] * 0.20 + (1.0 - metricKL) * 0.12, 0, 1);
  float genusProxy = constrain(tunnelDensity * 0.56 + abs(holoGamma) / PI * 0.24 + floquetCoupling * 0.20, 0, 1);
  float transition = constrain(1.0 - confidence + metricKL * 0.18, 0, 1);

  drawGauge(x, y, w, "tunnel density", tunnelDensity, color(105, 238, 202));
  drawGauge(x, y + 27, w, "surface / volume", surfaceVolume, color(255, 178, 82));
  drawGauge(x, y + 54, w, "curvature variance", curvatureVariance, color(255, 110, 118));
  drawGauge(x, y + 81, w, "connectedness", connectedness, color(128, 170, 255));
  drawGauge(x, y + 108, w, "genus proxy", genusProxy, color(190, 235, 120));
  drawGauge(x, y + 135, w, "transition boundary", transition, color(220, 130, 255));

  fill(130, 160, 170);
  textAlign(LEFT, TOP);
  textSize(9);
  text("classification blend", x, y + 168);
  int bw = max(1, w / 5);
  for (int i = 0; i < 5; i++) {
    color tc = topologyColor(i);
    fill(red(tc), green(tc), blue(tc), 190);
    rect(x + i * bw, y + 186, bw - 3, 9);
    fill(150, 170, 174);
    textAlign(CENTER, TOP);
    text(nf(scores[i], 1, 2), x + i * bw + bw * 0.5, y + 199);
  }
}

void drawTopologySlices(int x, int y, int w, int h, float[] scores) {
  drawReadoutPanel(x, y, w, h, "ORTHOGONAL LEVEL-SET SLICES");
  if (h < 90) return;
  int pad = 16;
  int labelH = 20;
  int sw = (w - pad * 4) / 3;
  int sh = h - labelH - 32;
  drawTopologySlice(x + pad, y + 42, sw, sh, scores, 0, "XY");
  drawTopologySlice(x + pad * 2 + sw, y + 42, sw, sh, scores, 1, "XZ");
  drawTopologySlice(x + pad * 3 + sw * 2, y + 42, sw, sh, scores, 2, "YZ");
}

void drawTopologySlice(int x, int y, int w, int h, float[] scores, int axis, String label) {
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(x, y, w, h, 5);
  int cols = 54;
  int rows = 34;
  noStroke();
  for (int r = 0; r < rows; r++) {
    float b = map(r, 0, rows - 1, -1, 1);
    for (int c = 0; c < cols; c++) {
      float a = map(c, 0, cols - 1, -1, 1);
      float v = axis == 0 ? topologyScalar(a, b, 0, scores)
              : axis == 1 ? topologyScalar(a, 0, b, scores)
              : topologyScalar(0, a, b, scores);
      float edge = constrain(1.0 - abs(v) * 7.0, 0, 1);
      color tc = topologyColor(activeTopologyIndex(scores));
      fill(8 + red(tc) * edge * 0.55, 14 + green(tc) * edge * 0.55, 20 + blue(tc) * edge * 0.55, 235);
      rect(x + c * w / (float)cols, y + r * h / (float)rows, w / (float)cols + 1, h / (float)rows + 1);
    }
  }
  fill(150, 182, 188);
  textSize(9);
  textAlign(LEFT, TOP);
  text(label, x + 8, y + 8);
}

void drawTopologyReferences(int x, int y, int w, int h, float[] scores, int active) {
  if (h < 60) return;
  int cols = 5;
  int cellW = max(42, w / cols);
  for (int i = 0; i < cols; i++) {
    int cx = x + i * cellW + cellW / 2;
    int cy = y + h / 2 - 4;
    boolean on = i == active;
    drawTPMSGlyph(cx, cy, min(cellW, h) * (on ? 0.24 : 0.18), i, on);
    fill(on ? color(230, 250, 232) : color(110, 135, 140));
    textSize(7);
    textAlign(CENTER, TOP);
    text(topologyName(i), cx, y + h - 18);
  }
}

void drawTopologyCard(int x, int y, int w, int h, int type, String title) {
  drawReadoutPanel(x, y, w, h, title);
  float cx = x + w * 0.5;
  float cy = y + h * 0.54;
  float r = min(w, h) * 0.24;
  int active = constrain((depth + int(metricFractal * 3.0) + int(braneTwist * 5.0)) % 5, 0, 4);
  drawTPMSGlyph(cx, cy, r + (active == type ? 16 : 0), type, active == type);
  drawGauge(x + 16, y + h - 34, w - 32, "activation", active == type ? 1 : constrain(0.25 + metricFractal * 0.18 + type * 0.04, 0, 1), color(105, 230, 170));
}

void drawTPMSGlyph(float cx, float cy, float r, int type, boolean active) {
  pushMatrix();
  translate(cx, cy);
  strokeWeight(active ? 2.0 : 1.1);
  noFill();
  if (type == 0) {
    drawGyroidMaterialCell(r, active);
    popMatrix();
    return;
  }
  int strands = type == 4 ? 3 : 4;
  for (int s = 0; s < strands; s++) {
    stroke(active ? color(110, 240, 170, 230) : color(86, 140, 130, 150));
    beginShape();
    for (int i = 0; i <= 100; i++) {
      float a = TWO_PI * i / 100.0;
      float vx = 0;
      float vy = 0;
      if (type == 0) {
        vx = cos(a + s * HALF_PI) * r + sin(2 * a + simT) * r * 0.22;
        vy = sin(a * 1.35 + s + simT * 0.2) * r * 0.72;
      } else if (type == 1) {
        vx = cos(a + s * HALF_PI) * r;
        vy = sin(a + s * HALF_PI) * r;
        if (i % 18 < 9) vx *= 0.62;
      } else if (type == 2) {
        vx = cos(a * 2 + s) * r * 0.78;
        vy = sin(a + s * HALF_PI + simT * 0.15) * r;
      } else if (type == 3) {
        vx = cos(a + s * TWO_PI / 4.0) * r * (0.72 + 0.24 * sin(3 * a));
        vy = sin(a + s * TWO_PI / 4.0) * r * (0.72 + 0.24 * cos(3 * a));
      } else {
        vx = map(i, 0, 100, -r, r);
        vy = bsin(map(i, 0, 100, -PI, PI) + s * 0.8 + simT) * r * 0.32 + (s - 1) * 11;
      }
      vertex(vx, vy);
    }
    endShape();
  }
  if (active) {
    noStroke();
    fill(255, 160, 75);
    ellipse(cos(simT * 2) * r * 0.55, sin(simT * 1.4) * r * 0.35, 9, 9);
  }
  popMatrix();
}

void drawGyroidMaterialCell(float r, boolean active) {
  float t = simT * 0.55 + braneTwist * TWO_PI;
  float cell = r * 1.92;

  stroke(active ? color(72, 126, 132, 170) : color(48, 82, 88, 115));
  strokeWeight(active ? 1.25 : 0.8);
  noFill();
  rect(-cell * 0.5, -cell * 0.5, cell, cell, 10);

  int bands = 5;
  for (int family = 0; family < 3; family++) {
    color c = family == 0 ? color(112, 245, 208)
            : family == 1 ? color(255, 178, 82)
            : color(140, 164, 255);
    stroke(c, active ? 210 : 145);
    strokeWeight(active ? 1.8 : 1.15);
    for (int b = -bands; b <= bands; b++) {
      beginShape();
      for (int i = 0; i <= 110; i++) {
        float u = map(i, 0, 110, -1, 1);
        float v = b / (float)bands;
        float warp = 0.16 * sin(TWO_PI * (u * 0.85 + v * 0.35) + t + family * TWO_PI / 3.0);
        float x = u * r * 0.92;
        float y = (v + warp) * r * 0.70;
        float ca = family * TWO_PI / 3.0 + 0.16 * sin(t * 0.25);
        float xr = x * cos(ca) - y * sin(ca);
        float yr = x * sin(ca) + y * cos(ca);
        if (abs(xr) < cell * 0.49 && abs(yr) < cell * 0.49) vertex(xr, yr);
      }
      endShape();
    }
  }

  noStroke();
  for (int i = 0; i < 9; i++) {
    float a = TWO_PI * i / 9.0 + t * 0.18;
    float rr = r * (0.22 + 0.46 * ((i % 3) / 2.0));
    fill(active ? color(230, 255, 220, 150) : color(140, 175, 165, 100));
    ellipse(cos(a) * rr, sin(a * 1.6) * rr * 0.72, active ? 5.5 : 4.0, active ? 5.5 : 4.0);
  }

  stroke(active ? color(210, 255, 238, 210) : color(120, 165, 155, 130));
  strokeWeight(active ? 2.0 : 1.0);
  noFill();
  beginShape();
  for (int i = 0; i <= 180; i++) {
    float a = TWO_PI * i / 180.0;
    float rr = r * (0.42 + 0.10 * sin(a * 3.0 + t));
    vertex(cos(a) * rr, sin(a) * rr * 0.64);
  }
  endShape(CLOSE);
}

float bsin(float x) {
  return 1.104 * sin(x) + 0.01263 * sin(2 * x) + 0.1408 * sin(3 * x) +
         0.0122 * sin(4 * x) + 0.06373 * sin(5 * x);
}

void drawMaterialMap(int x, int y, int w, int h) {
  drawReadoutPanel(x, y, w, h, "MATERIAL RESPONSE");
  int gx = x + 24;
  int gy = y + 52;
  int gw = w - 48;
  int gh = h - 104;
  fill(3, 7, 11);
  stroke(36, 62, 70);
  rect(gx, gy, gw, gh, 5);
  float stiffness = constrain(metricCoherence * 0.55 + floquetCoupling * 0.22 - metricKL * 0.18, 0, 1);
  float absorption = constrain(metricEntropy * 0.28 + metricLyap * 0.26 + quasiEnergy * 0.32, 0, 1);
  float px = gx + stiffness * gw;
  float py = gy + gh - absorption * gh;
  stroke(80, 110, 120);
  line(gx, py, gx + gw, py);
  line(px, gy, px, gy + gh);
  noStroke();
  fill(255, 170, 80);
  ellipse(px, py, 13, 13);
  drawGauge(x + 18, y + h - 38, w - 36, "stiff / absorb", constrain((stiffness + absorption) * 0.5, 0, 1), color(255, 170, 80));
}

void drawMetricBlock(int x, int y, int w, String title) {
  fill(145, 230, 215);
  textAlign(LEFT, TOP);
  textSize(10);
  text(title, x, y);
  stroke(36, 62, 70);
  line(x, y + 18, x + w, y + 18);
}

void drawGauge(int x, int y, int w, String label, float v, color c) {
  v = constrain(v, 0, 1);
  noStroke();
  fill(24, 34, 42);
  rect(x, y + 11, w, 7, 3);
  fill(c);
  rect(x, y + 11, w * v, 7, 3);
  fill(145, 170, 178);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  textAlign(RIGHT, TOP);
  text(nf(v, 1, 3), x + w, y);
}

void metricLine(int x, int y, String label, String value) {
  fill(130, 160, 170);
  textSize(10);
  textAlign(LEFT, TOP);
  text(label, x, y);
  fill(220, 238, 236);
  textAlign(RIGHT, TOP);
  text(value, x + 230, y);
}

void drawButton(int x, int y, int w, int h, String label, color bg) {
  noStroke();
  fill(bg);
  rect(x, y, w, h, 5);
  fill(230);
  textSize(9);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
}

void drawHelpOverlay() {
  int w = 560;
  int h = 300;
  int x = width / 2 - w / 2;
  int y = height / 2 - h / 2;
  fill(4, 8, 12, 235);
  stroke(90, 220, 205);
  rect(x, y, w, h, 8);
  fill(230, 245, 242);
  textSize(14);
  textAlign(LEFT, TOP);
  text("Cosmosis Visual Observatory", x + 24, y + 22);
  fill(145, 178, 186);
  textSize(10);
  text("This sketch turns the theory vocabulary into visual lenses over one shared field state.\n\n1-9 select workspaces. Drag sliders to reshape the recursive field. Depth now spans 0-12, giving 13 recursive layers; Deep Detail controls how strongly deeper layers survive alpha falloff. Floquet Forge has an optional Shaper layer for simulated or Sender-fed environmental streams. [ and ] cycle material targets. M switches material source mode: heuristic, database, or Cosmosis CSV. O opens a Cosmosis/RDFT CSV run and creates an active run-imprint profile. U reloads generated material caches. V applies the selected material profile. N cycles the Surface Foundry geometry carrier. G generates a Surface Foundry mesh. C generates PNG/STL call sheets. X pulls optional SVG call sheets for the current render strategy. E exports STL plus metadata. SPACE pauses. R resets the orbit and trails. S saves a frame. H closes this overlay.\n\nSurface Foundry exports fabrication geometry from the same topology field, with geometry wrapping over TPMS, manifold, lattice, and recursive fractal carriers. Database material targets may add explicitly labeled phase-transform, topological-response, or superconducting-coherence traits to the RDFT mapping. The CTC and Wigner views are analogical diagnostics, intended for visual exploration rather than physical claims.", x + 24, y + 58, w - 48, h - 80);
}

void resetState() {
  orbitX = 0.58;
  orbitY = 0.06;
  orbitVX = 0;
  orbitVY = 0.72;
  orbitTrail.clear();
  holoTrail.clear();
  holoGammaTrail.clear();
  holoGamma = 0;
  simT = 0;
  initParticles();
  dirtyField = true;
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) markDcrtePrimitiveStale("field state reset; regenerate");
  else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) markDcrteImportedMaterialStale("field state reset; regenerate material");
}

void randomizeState() {
  seed = (int)random(999999);
  randomSeed(seed);
  noiseSeed(seed);
  for (SliderKnob s : sliders) {
    if (s.label.equals("DEPTH")) s.value = round(random(2, DEPTH_MAX + 1));
    else s.value = random(s.minVal, s.maxVal);
  }
  syncControls();
  initFloquet();
  resetState();
}

void mousePressed() {
  if (mouseY >= 70 && mouseY <= 100 && mouseX > UI_W) {
    int x0 = UI_W + 16;
    int usable = width - x0 - 18;
    int tabW = usable / lensNames.length;
    int idx = (mouseX - x0) / max(1, tabW);
    if (idx >= 0 && idx < lensNames.length) activeLens = idx;
  }
  if (over(width - 312, 15, 72, 26)) paused = !paused;
  if (over(width - 232, 15, 72, 26)) resetState();
  if (over(width - 152, 15, 92, 26)) randomizeState();
  if (over(width - 50, 15, 30, 26)) showHelp = !showHelp;
  int my = materialPanelY();
  int by = my + MATERIAL_PANEL_H - 24;
  if (activeMaterial() == null) {
    if (over(32, by, 54, 18)) cycleMaterialSource();
    if (over(92, by, 58, 18)) refreshMaterialSources();
    if (materialSourceMode == 2 && over(156, by, 52, 18)) openCosmosisCsv();
  } else {
    if (over(32, by, 28, 18)) selectMaterial(-1);
    if (over(66, by, 64, 18)) applySelectedMaterial();
    if (over(136, by, 28, 18)) selectMaterial(1);
    if (over(170, by, 48, 18)) cycleMaterialSource();
    if (materialSourceMode == 2 && over(224, by, 34, 18)) openCosmosisCsv();
  }
  if (activeLens == 1) {
    int x = UI_W + 18;
    int y = 112;
    int w = width - x - 20;
    int h = height - y - 48;
    int planeW = min(w - 360, h - 80);
    int rx = x + 34 + planeW + 32;
    int py = y + 54;
    if (over(rx + 16, py + 150, 132, 24)) reverseHolonomy = !reverseHolonomy;
  }
  if (activeLens == 3) {
    int x = UI_W + 18;
    int y = 112;
    int w = width - x - 20;
    int h = height - y - 48;
    int leftX = x + 24;
    int topY = y + 52;
    int leftW = 350;
    int mainX = leftX + leftW + 22;
    int sx = mainX + 18;
    int sy = topY + 38;
    if (over(sx, sy, 118, 26)) { shaperEnabled = !shaperEnabled; dirtyField = true; }
    if (over(sx + 130, sy, 132, 26)) { shaperUseSender = !shaperUseSender; shaperSenderOnline = false; shaperLastPoll = -999; }
    if (over(sx + 274, sy, 64, 26)) { shaperMix = max(0, shaperMix - 0.08); dirtyField = true; }
    if (over(sx + 348, sy, 64, 26)) { shaperMix = min(1, shaperMix + 0.08); dirtyField = true; }
  }
  if (activeLens == 8) {
    int x = UI_W + 18;
    int y = 112;
    int w = width - x - 20;
    int h = height - y - 48;
    int rightW = 330;
    int px = x + 24;
    int py = y + 52;
    int previewW = w - rightW - 72;
    int rightX = px + previewW + 24;
    int cx = rightX + 16;
    int cy = py + 42;
    if (handleDcrtePrimitivePanelMouse(px + 16, py + 40, previewW - 32, h - 82 - 58)) return;
    if (dcrtePreflightPanelOpen) {
      if (handleDcrtePreflightPanelMouse(px + 16, py + 40, previewW - 32, h - 82 - 58)) return;
    } else if (handleDcrteImportedPanelMouse(px + 16, py + 40, previewW - 32, h - 82 - 58)) return;
    if (over(cx, cy, 132, 26)) generateSelectedSurfaceFoundryMesh();
    if (over(cx + 142, cy, 102, 26)) generateFoundryCallSheets();
    if (over(cx + 252, cy, 78, 26)) pullFoundryCallSheetSvgs();
    if (over(cx, cy + 30, 132, 22)) cycleDcrtePipelineMode();
    if (over(cx + 142, cy + 30, 102, 22)) exportSurfaceFoundryMesh();
    if (over(cx, cy + 62, 78, 22)) {
      if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) adjustDcrtePrimitiveResolution(-1);
      else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) adjustDcrteImportedResolution(-1);
      else { foundryResolution = max(24, foundryResolution - 6); markFoundryStale(); }
    }
    if (over(cx + 88, cy + 62, 78, 22)) {
      if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) adjustDcrtePrimitiveResolution(1);
      else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) adjustDcrteImportedResolution(1);
      else { foundryResolution = min(96, foundryResolution + 6); markFoundryStale(); }
    }
    if (over(cx, cy + 112, 78, 22)) { foundryIsoBand = max(0.035, foundryIsoBand - 0.01); markCurrentFoundryStale("iso band changed; regenerate"); }
    if (over(cx + 88, cy + 112, 78, 22)) { foundryIsoBand = min(0.22, foundryIsoBand + 0.01); markCurrentFoundryStale("iso band changed; regenerate"); }
    if (over(cx, cy + 162, 78, 22)) cycleFoundryGeometry(-1);
    if (over(cx + 88, cy + 162, 78, 22)) cycleFoundryGeometry(1);
    if (over(cx, cy + 212, 112, 22)) { foundryRaisedVeins = !foundryRaisedVeins; markCurrentFoundryStale("raised vein request changed; regenerate"); }
    int cadY = py + 578;
    int cadW = rightW - 32;
    int topGap = 6;
    int topW = (cadW - topGap * 2) / 3;
    if (over(cx, cadY, topW, 22)) cadPreviewEnabled = !cadPreviewEnabled;
    if (over(cx + topW + topGap, cadY, topW, 22)) cadInternalLattice = !cadInternalLattice;
    if (over(cx + (topW + topGap) * 2, cadY, topW, 22)) cadGraphicDrafting = !cadGraphicDrafting;

    int cellGap = 10;
    int cellW = (cadW - cellGap) / 2;
    int buttonGap = 4;
    int buttonW = (cellW - buttonGap) / 2;
    int row1Buttons = cadY + 43;
    int row2Buttons = cadY + 81;
    int rightCell = cx + cellW + cellGap;
    if (over(cx, row1Buttons, buttonW, 20)) cadInternalStride = max(1, cadInternalStride - 1);
    if (over(cx + buttonW + buttonGap, row1Buttons, buttonW, 20)) cadInternalStride = min(8, cadInternalStride + 1);
    if (over(rightCell, row1Buttons, buttonW, 20)) cadEdgeCull = max(0, cadEdgeCull - 0.06);
    if (over(rightCell + buttonW + buttonGap, row1Buttons, buttonW, 20)) cadEdgeCull = min(0.92, cadEdgeCull + 0.06);
    if (over(cx, row2Buttons, buttonW, 20)) cadShadowThreshold = max(0.05, cadShadowThreshold - 0.03);
    if (over(cx + buttonW + buttonGap, row2Buttons, buttonW, 20)) cadShadowThreshold = min(0.55, cadShadowThreshold + 0.03);
    if (over(rightCell, row2Buttons, buttonW, 20)) cadStochastic = max(0, cadStochastic - 0.06);
    if (over(rightCell + buttonW + buttonGap, row2Buttons, buttonW, 20)) cadStochastic = min(1, cadStochastic + 0.06);
  }
  for (SliderKnob s : sliders) s.mousePressed();
}

void mouseDragged() {
  boolean changed = false;
  for (SliderKnob s : sliders) {
    if (s.dragging) {
      s.mouseDragged();
      changed = true;
    }
  }
  if (changed) {
    syncControls();
    dirtyField = true;
    if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) markDcrtePrimitiveStale("field controls changed; regenerate");
    else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) markDcrteImportedMaterialStale("field controls changed; regenerate material");
  }
}

void mouseReleased() {
  for (SliderKnob s : sliders) s.dragging = false;
}

void keyPressed() {
  if (key >= '1' && key <= '9') activeLens = key - '1';
  else if (key == ' ') paused = !paused;
  else if (key == 'r' || key == 'R') resetState();
  else if (key == 'h' || key == 'H') showHelp = !showHelp;
  else if (key == 's' || key == 'S') saveFrame("exports/cosmosis_visual_####.png");
  else if (key == 'g' || key == 'G') generateSelectedSurfaceFoundryMesh();
  else if (key == 'c' || key == 'C') generateFoundryCallSheets();
  else if (key == 'x' || key == 'X') pullFoundryCallSheetSvgs();
  else if (key == 'e' || key == 'E') exportSurfaceFoundryMesh();
  else if (key == 'n' || key == 'N') cycleFoundryGeometry(1);
  else if (key == 'm' || key == 'M') cycleMaterialSource();
  else if (key == 'o' || key == 'O') openCosmosisCsv();
  else if (key == 'u' || key == 'U') refreshMaterialSources();
  else if (key == '[' || key == ',') selectMaterial(-1);
  else if (key == ']' || key == '.') selectMaterial(1);
  else if (key == 'v' || key == 'V') applySelectedMaterial();
}

boolean over(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

class ReliefField {
  int rows;
  int cols;
  float[][] height;
  boolean[][] mask;
  float xySpanMM;

  ReliefField(int rows, int cols, float[][] height, boolean[][] mask, float xySpanMM) {
    this.rows = rows;
    this.cols = cols;
    this.height = height;
    this.mask = mask;
    this.xySpanMM = xySpanMM;
  }
}

class MeshTri {
  PVector a;
  PVector b;
  PVector c;

  MeshTri(PVector a, PVector b, PVector c) {
    this.a = a.copy();
    this.b = b.copy();
    this.c = c.copy();
  }

  PVector normal() {
    PVector u = PVector.sub(b, a);
    PVector v = PVector.sub(c, a);
    PVector n = u.cross(v);
    if (n.mag() < 0.000001) return new PVector(0, 0, 1);
    n.normalize();
    return n;
  }
}

class CallSheetBasis {
  PVector horizontal;
  PVector vertical;
  PVector view;

  CallSheetBasis(PVector horizontal, PVector vertical, PVector view) {
    this.horizontal = horizontal;
    this.vertical = vertical;
    this.view = view;
  }
}

class CallSheetBounds {
  float minX = 999999;
  float maxX = -999999;
  float minY = 999999;
  float maxY = -999999;
  boolean valid = false;

  void include(PVector p) {
    minX = min(minX, p.x);
    maxX = max(maxX, p.x);
    minY = min(minY, p.y);
    maxY = max(maxY, p.y);
    valid = true;
  }
}

class SurfaceMesh {
  String name;
  ArrayList<MeshTri> tris = new ArrayList<MeshTri>();

  SurfaceMesh(String name) {
    this.name = name;
  }

  void addTri(PVector a, PVector b, PVector c) {
    tris.add(new MeshTri(a, b, c));
  }

  void addQuad(PVector a, PVector b, PVector c, PVector d) {
    addTri(a, b, c);
    addTri(a, c, d);
  }

  int[] manifoldAudit() {
    HashMap<String, Integer> edgeCounts = new HashMap<String, Integer>();
    HashMap<String, Integer> edgeBalance = new HashMap<String, Integer>();
    int degenerate = 0;
    for (MeshTri tri : tris) {
      PVector ab = PVector.sub(tri.b, tri.a);
      PVector ac = PVector.sub(tri.c, tri.a);
      if (ab.cross(ac).magSq() < 0.00000001f) {
        degenerate++;
        continue;
      }
      auditEdge(edgeCounts, edgeBalance, tri.a, tri.b);
      auditEdge(edgeCounts, edgeBalance, tri.b, tri.c);
      auditEdge(edgeCounts, edgeBalance, tri.c, tri.a);
    }
    int boundary = 0;
    int nonManifold = 0;
    for (String key : edgeCounts.keySet()) {
      int count = edgeCounts.get(key);
      int balance = edgeBalance.get(key);
      if (count == 1) boundary++;
      else if (count > 2 || (count == 2 && abs(balance) == 2)) nonManifold++;
    }
    return new int[] { boundary, nonManifold, degenerate };
  }

  void auditEdge(HashMap<String, Integer> counts, HashMap<String, Integer> balance, PVector a, PVector b) {
    String ka = auditVertexKey(a);
    String kb = auditVertexKey(b);
    boolean forward = ka.compareTo(kb) <= 0;
    String key = forward ? ka + "|" + kb : kb + "|" + ka;
    counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
    int direction = forward ? 1 : -1;
    balance.put(key, balance.containsKey(key) ? balance.get(key) + direction : direction);
  }

  String auditVertexKey(PVector p) {
    return round(p.x * 100000.0f) + "," + round(p.y * 100000.0f) + "," + round(p.z * 100000.0f);
  }

  void addTube(ArrayList<PVector> path, float radius, int sides) {
    if (path.size() < 2) return;
    PVector[][] rings = new PVector[path.size()][sides];
    for (int i = 0; i < path.size(); i++) {
      PVector prev = path.get(max(0, i - 1));
      PVector next = path.get(min(path.size() - 1, i + 1));
      PVector dir = PVector.sub(next, prev);
      if (dir.mag() < 0.0001) dir = new PVector(0, 0, 1);
      dir.normalize();
      PVector up = abs(dir.z) < 0.88 ? new PVector(0, 0, 1) : new PVector(0, 1, 0);
      PVector side = dir.cross(up);
      if (side.mag() < 0.0001) side = new PVector(1, 0, 0);
      side.normalize();
      PVector binormal = side.cross(dir);
      binormal.normalize();
      float taper = 0.35 + 0.65 * sin(PI * i / max(1.0, path.size() - 1.0));
      for (int s = 0; s < sides; s++) {
        float a = TWO_PI * s / sides;
        PVector p = path.get(i).copy();
        PVector off = PVector.mult(side, cos(a) * radius * taper);
        off.add(PVector.mult(binormal, sin(a) * radius * taper));
        p.add(off);
        rings[i][s] = p;
      }
    }
    for (int i = 0; i < path.size() - 1; i++) {
      for (int s = 0; s < sides; s++) {
        int sn = (s + 1) % sides;
        addQuad(rings[i][s], rings[i + 1][s], rings[i + 1][sn], rings[i][sn]);
      }
    }
    PVector start = path.get(0);
    PVector end = path.get(path.size() - 1);
    for (int s = 0; s < sides; s++) {
      int sn = (s + 1) % sides;
      addTri(start, rings[0][sn], rings[0][s]);
      addTri(end, rings[path.size() - 1][s], rings[path.size() - 1][sn]);
    }
  }

  void drawPreview(float s) {
    hint(DISABLE_DEPTH_TEST);
    noStroke();
    fill(75, 180, 210, 44);
    int stride = max(1, tris.size() / 6500);
    beginShape(TRIANGLES);
    for (int i = 0; i < tris.size(); i += stride) {
      MeshTri t = tris.get(i);
      vertex(t.a.x * s, t.a.y * s, t.a.z * s);
      vertex(t.b.x * s, t.b.y * s, t.b.z * s);
      vertex(t.c.x * s, t.c.y * s, t.c.z * s);
    }
    endShape();
    stroke(120, 235, 220, 95);
    strokeWeight(0.8);
    noFill();
    beginShape(LINES);
    for (int i = 0; i < tris.size(); i += stride * 8) {
      MeshTri t = tris.get(i);
      vertex(t.a.x * s, t.a.y * s, t.a.z * s); vertex(t.b.x * s, t.b.y * s, t.b.z * s);
      vertex(t.b.x * s, t.b.y * s, t.b.z * s); vertex(t.c.x * s, t.c.y * s, t.c.z * s);
    }
    endShape();
    hint(ENABLE_DEPTH_TEST);
  }

  void writeSTL(String filename) {
    PrintWriter out = createWriter(filename);
    out.println("solid " + name);
    for (MeshTri t : tris) {
      PVector n = t.normal();
      out.println("  facet normal " + n.x + " " + n.y + " " + n.z);
      out.println("    outer loop");
      stlVertex(out, t.a);
      stlVertex(out, t.b);
      stlVertex(out, t.c);
      out.println("    endloop");
      out.println("  endfacet");
    }
    out.println("endsolid " + name);
    out.flush();
    out.close();
  }

  void stlVertex(PrintWriter out, PVector p) {
    out.println("      vertex " + p.x + " " + p.y + " " + p.z);
  }
}

class MaterialProfile {
  String name = "Unknown";
  String family = "material";
  String source = "local approximate profile";
  String sourceMode = "heuristic";
  String sourceId = "";
  String provider = "";
  String formula = "";
  String confidence = "approximate";
  String missingFields = "";
  String notes = "";
  String functionalTags = "";
  float density = 1;
  float youngs = 1;
  float bulk = 1;
  float shear = 1;
  float poisson = 0.3;
  float thermal = 1;
  float heatCapacity = 800;
  float bandGap = 0;
  float dielectric = 1;
  float anisotropy = 0;
  float porosity = 0;
  float crystalOrder = 0.5;
  float magnetic = 0;
  float phaseTransform = 0;
  float topologicalResponse = 0;
  float superconductingCoherence = 0;
  float transitionTemperatureK = 0;

  float densityN;
  float stiffnessN;
  float thermalN;
  float dielectricN;
  float orderN;
  float electronicN;

  float alphaMap;
  float depthMap;
  float sourceMap;
  float floquetMap;
  float quasiMap;
  float coherenceMap;
  float ctcMap;
  float braneMap;
  float detailMap;
  float timeMap;

  MaterialProfile() {
  }

  MaterialProfile(JSONObject obj) {
    name = jsonString(obj, "name", name);
    family = jsonString(obj, "family", family);
    source = jsonString(obj, "source", source);
    sourceMode = jsonString(obj, "source_mode", sourceMode);
    sourceId = jsonString(obj, "source_id", sourceId);
    provider = jsonString(obj, "provider", provider);
    formula = jsonString(obj, "formula", formula);
    confidence = jsonString(obj, "confidence", confidence);
    missingFields = jsonString(obj, "missing_fields", missingFields);
    notes = jsonString(obj, "notes", notes);
    functionalTags = jsonString(obj, "functional_tags", functionalTags);
    density = jsonFloat(obj, "density", density);
    youngs = jsonFloat(obj, "youngs_gpa", youngs);
    bulk = jsonFloat(obj, "bulk_gpa", bulk);
    shear = jsonFloat(obj, "shear_gpa", shear);
    poisson = jsonFloat(obj, "poisson", poisson);
    thermal = jsonFloat(obj, "thermal_w_mk", thermal);
    heatCapacity = jsonFloat(obj, "heat_capacity_j_kgk", heatCapacity);
    bandGap = jsonFloat(obj, "band_gap_ev", bandGap);
    dielectric = jsonFloat(obj, "dielectric", dielectric);
    anisotropy = jsonFloat(obj, "anisotropy", anisotropy);
    porosity = jsonFloat(obj, "porosity", porosity);
    crystalOrder = jsonFloat(obj, "crystal_order", crystalOrder);
    magnetic = jsonFloat(obj, "magnetic", magnetic);
    phaseTransform = jsonFloat(obj, "phase_transform", phaseTransform);
    topologicalResponse = jsonFloat(obj, "topological_response", topologicalResponse);
    superconductingCoherence = jsonFloat(obj, "superconducting_coherence", superconductingCoherence);
    transitionTemperatureK = jsonFloat(obj, "transition_temperature_k", transitionTemperatureK);
    normalizeStrings();
    computeMappings();
  }

  String provenanceLabel() {
    normalizeStrings();
    String label = sourceMode.length() == 0 ? "unknown" : sourceMode;
    if (provider.length() > 0) label += "/" + provider;
    else if (source.length() > 0) label += "/" + source;
    if (sourceId.length() > 0) label += " " + sourceId;
    return label;
  }

  void normalizeStrings() {
    name = safeString(name, "Unknown");
    family = safeString(family, "material");
    source = safeString(source, "");
    sourceMode = safeString(sourceMode, "heuristic");
    sourceId = safeString(sourceId, "");
    provider = safeString(provider, "");
    formula = safeString(formula, "");
    confidence = safeString(confidence, "");
    missingFields = safeString(missingFields, "");
    notes = safeString(notes, "");
    functionalTags = safeString(functionalTags, "");
  }

  void computeMappings() {
    normalizeStrings();
    anisotropy = constrain(anisotropy, 0, 1);
    porosity = constrain(porosity, 0, 1);
    crystalOrder = constrain(crystalOrder, 0, 1);
    magnetic = constrain(magnetic, 0, 1);
    phaseTransform = constrain(phaseTransform, 0, 1);
    topologicalResponse = constrain(topologicalResponse, 0, 1);
    superconductingCoherence = constrain(superconductingCoherence, 0, 1);
    transitionTemperatureK = max(0.0, transitionTemperatureK);

    densityN = logNorm(density, 0.05, 20.0);
    float youngN = logNorm(youngs, 0.003, 1200.0);
    float bulkN = logNorm(bulk, 0.003, 500.0);
    float shearN = logNorm(shear, 0.002, 500.0);
    stiffnessN = constrain(youngN * 0.48 + bulkN * 0.28 + shearN * 0.24, 0, 1);
    thermalN = logNorm(thermal, 0.015, 3200.0);
    float heatN = logNorm(heatCapacity, 300.0, 1600.0);
    float bandN = constrain(bandGap / 9.0, 0, 1);
    dielectricN = logNorm(dielectric, 1.0, 1800.0);
    orderN = constrain(crystalOrder * 0.72 + (1.0 - porosity) * 0.16 + stiffnessN * 0.12, 0, 1);
    electronicN = constrain(bandN * 0.42 + dielectricN * 0.36 + thermalN * 0.12 + magnetic * 0.10, 0, 1);
    float auxeticN = constrain((0.38 - poisson) / 0.36, 0, 1);

    alphaMap = constrain(1.05 + (ALPHA_MAX - 1.05) * (orderN * 0.34 + stiffnessN * 0.24 + anisotropy * 0.18 + electronicN * 0.14 + densityN * 0.10), 1.0, ALPHA_MAX);
    depthMap = constrain(1.0 + (DEPTH_MAX - 1.0) * (porosity * 0.32 + anisotropy * 0.24 + orderN * 0.22 + electronicN * 0.14 + magnetic * 0.08), 0, DEPTH_MAX);
    sourceMap = constrain(0.05 + 1.25 * (densityN * 0.32 + bulkN * 0.24 + stiffnessN * 0.22 + (1.0 - porosity) * 0.12 + thermalN * 0.10), 0.05, 1.3);
    floquetMap = constrain(thermalN * 0.28 + dielectricN * 0.24 + anisotropy * 0.18 + orderN * 0.15 + magnetic * 0.15, 0, 1);
    quasiMap = constrain(bandN * 0.34 + dielectricN * 0.28 + thermalN * 0.16 + magnetic * 0.14 + porosity * 0.08, 0, 1);
    coherenceMap = constrain(orderN * 0.42 + stiffnessN * 0.24 + (1.0 - porosity) * 0.18 + thermalN * 0.08 + (1.0 - anisotropy) * 0.08, 0, 1);
    ctcMap = constrain(anisotropy * 0.26 + dielectricN * 0.24 + magnetic * 0.24 + porosity * 0.16 + electronicN * 0.10, 0, 1);
    braneMap = constrain(anisotropy * 0.44 + porosity * 0.22 + auxeticN * 0.14 + magnetic * 0.10 + electronicN * 0.10, 0, 1);
    detailMap = constrain(0.18 + porosity * 0.24 + anisotropy * 0.22 + electronicN * 0.18 + orderN * 0.18, 0, 1);
    timeMap = constrain(0.18 + 1.25 * (thermalN * 0.34 + heatN * 0.20 + electronicN * 0.18 + magnetic * 0.14 + (1.0 - densityN) * 0.14), 0.05, 1.5);

    // Functional traits are provenance-labeled RDFT response modifiers. Zero-valued
    // heuristic profiles preserve the original material mapping exactly.
    alphaMap = constrain(alphaMap + topologicalResponse * 0.18 + superconductingCoherence * 0.12, 1.0, ALPHA_MAX);
    depthMap = constrain(depthMap + phaseTransform * 1.4 + topologicalResponse * 0.8, 0, DEPTH_MAX);
    floquetMap = constrain(floquetMap + phaseTransform * 0.14 + superconductingCoherence * 0.12, 0, 1);
    quasiMap = constrain(quasiMap + topologicalResponse * 0.16 + phaseTransform * 0.08, 0, 1);
    coherenceMap = constrain(coherenceMap + superconductingCoherence * 0.22 + topologicalResponse * 0.06, 0, 1);
    ctcMap = constrain(ctcMap + topologicalResponse * 0.16 + phaseTransform * 0.05, 0, 1);
    braneMap = constrain(braneMap + phaseTransform * 0.16 + topologicalResponse * 0.10, 0, 1);
    detailMap = constrain(detailMap + phaseTransform * 0.10 + topologicalResponse * 0.12 + superconductingCoherence * 0.08, 0, 1);
    timeMap = constrain(timeMap + phaseTransform * 0.12 + superconductingCoherence * 0.08, 0.05, 1.5);
  }
}

class SliderKnob {
  String label;
  float minVal;
  float maxVal;
  float value;
  int x;
  int y;
  int w;
  boolean dragging = false;

  SliderKnob(String label, float minVal, float maxVal, float value, int x, int y, int w) {
    this.label = label;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.value = value;
    this.x = x;
    this.y = y;
    this.w = w;
  }

  void draw() {
    float t = constrain((value - minVal) / max(0.0001, maxVal - minVal), 0, 1);
    fill(145, 170, 178);
    textSize(9);
    textAlign(LEFT, TOP);
    text(label, x, y - 17);
    textAlign(RIGHT, TOP);
    text(label.equals("DEPTH") ? str(round(value)) : nf(value, 1, 3), x + w, y - 17);
    noStroke();
    fill(26, 38, 46);
    rect(x, y, w, 10, 5);
    fill(95, 220, 205);
    rect(x, y, w * t, 10, 5);
    fill(240, 250, 246);
    ellipse(x + w * t, y + 5, 17, 17);
  }

  void mousePressed() {
    if (mouseX >= x - 8 && mouseX <= x + w + 8 && mouseY >= y - 10 && mouseY <= y + 18) {
      dragging = true;
      mouseDragged();
    }
  }

  void mouseDragged() {
    float t = constrain((mouseX - x) / (float)w, 0, 1);
    value = lerp(minVal, maxVal, t);
  }
}

class Particle {
  float x;
  float y;
  float vx;
  float vy;
  float energy;

  Particle(float x, float y) {
    this.x = x;
    this.y = y;
    vx = random(-0.002, 0.002);
    vy = random(-0.002, 0.002);
    energy = random(1);
  }

  void step() {
    int c = constrain(round(x * (GRID - 1)), 1, GRID - 2);
    int r = constrain(round(y * (GRID - 1)), 1, GRID - 2);
    float gx = field[r][c + 1] - field[r][c - 1];
    float gy = field[r + 1][c] - field[r - 1][c];
    vx = vx * 0.94 + gx * 0.012 + random(-0.001, 0.001);
    vy = vy * 0.94 + gy * 0.012 + random(-0.001, 0.001);
    x += vx * timeScale;
    y += vy * timeScale;
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      x = random(1);
      y = random(1);
      vx = vy = 0;
    }
    energy = lerp(energy, constrain(field[r][c] * 0.55 + residual[r][c] * 0.45, 0, 1), 0.08);
  }
}
