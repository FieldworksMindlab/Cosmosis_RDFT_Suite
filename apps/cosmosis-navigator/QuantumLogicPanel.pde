/**
 * QuantumLogicPanel.pde
 *
 * Lightweight Q-LOGIC popup. It mirrors the FieldConfigPanel pattern: the main
 * sketch pushes state in, and reads user controls from public fields.
 */

class QuantumLogicPanel extends PApplet {
  volatile boolean qReady = false;

  final int FW = 720;
  final int FH = 460;
  final int M = 18;

  final int BG = 0xFF07090D;
  final int PANEL_BG = 0xFF0A0E12;
  final int GRID_COL = 0xFF1C2628;
  final int AXIS_COL = 0xFF41555A;
  final int TEXT_COL = 0xFFA0C3B9;
  final int HIGHLIGHT = 0xFFDCF0E6;
  final int ACCENT = 0xFF72E0FF;
  final int ACCENT_ALT = 0xFFFF77AA;
  final int OK_COL = 0xFF44DD88;
  final int WARN_COL = 0xFFFFAA44;

  volatile boolean qEnabled = true;
  volatile boolean qAutoMeasure = false;
  volatile int qBasis = 0;
  volatile float qMeasurementStrength = 0.35;
  volatile float qCollapseDepth = 0.22;
  volatile float qReopenRate = 0.035;
  volatile float qMemoryPersistence = 0.86;

  int btnEnableX, btnEnableY, btnEnableW, btnEnableH;
  int btnMeasureX, btnMeasureY, btnMeasureW, btnMeasureH;
  int btnAutoX, btnAutoY, btnAutoW, btnAutoH;
  int[][] basisRects = new int[3][4];
  int[][] sliderRects = new int[4][4];
  int dragging = -1;
  int measureRequest = 0;

  volatile int syncMeasurementId = 0;
  volatile int syncSelectedOutcome = -1;
  volatile float syncSelectedProbability = 0.0;
  volatile float syncDistributionEntropy = 0.0;
  volatile float syncAmpMean = 0.0;
  volatile float syncAmpPeak = 0.0;
  volatile float syncPhaseVariance = 0.0;
  volatile float syncChirality = 0.0;
  volatile float syncWinding = 0.0;
  volatile int syncLobes = 0;
  volatile int syncSingularities = 0;
  volatile float syncCollapsePulse = 0.0;
  volatile float syncMemoryTrace = 0.0;
  volatile float syncEntropyDelta = 0.0;
  volatile float[] syncDistribution = new float[]{0.25, 0.25, 0.25, 0.25};
  volatile String syncBasisName = "POSITION";
  volatile String syncOutcomeName = "NONE";

  final int HIST = 180;
  float[] ampHist = new float[HIST];
  float[] probHist = new float[HIST];
  float[] chirHist = new float[HIST];
  int histHead = 0;

  public void setup() {
    surface.setSize(FW, FH);
    surface.setTitle("Cosmosis Q-LOGIC");
    try {
      if (surface != null && surface.getNative() instanceof processing.awt.PSurfaceAWT.SmoothCanvas) {
        javax.swing.JFrame jf = (javax.swing.JFrame)
          ((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
        jf.setDefaultCloseOperation(javax.swing.WindowConstants.HIDE_ON_CLOSE);
      }
    } catch (Exception e) {
      println("QuantumLogicPanel: could not set HIDE_ON_CLOSE - " + e);
    }
    colorMode(RGB, 255);
    textFont(createFont("Monospaced", 11));
    frameRate(30);
    qReady = true;
  }

  public void setPanelVisible(boolean visible) {
    try {
      if (surface != null) surface.setVisible(visible);
    } catch (Exception e) {
      println("QuantumLogicPanel: could not set visibility - " + e);
    }
  }

  synchronized boolean consumeMeasureRequest() {
    if (measureRequest <= 0) return false;
    measureRequest = 0;
    return true;
  }

  synchronized void syncState(
    boolean enabled, int basis, int measurementId, int selectedOutcome,
    float selectedProbability, float distributionEntropy,
    float ampMean, float ampPeak, float phaseVariance,
    float chirality, float winding, int lobes, int singularities,
    float collapsePulse, float memoryTrace, float entropyDelta,
    float p0, float p1, float p2, float p3,
    String basisName, String outcomeName
  ) {
    qEnabled = enabled;
    qBasis = basis;
    syncMeasurementId = measurementId;
    syncSelectedOutcome = selectedOutcome;
    syncSelectedProbability = selectedProbability;
    syncDistributionEntropy = distributionEntropy;
    syncAmpMean = ampMean;
    syncAmpPeak = ampPeak;
    syncPhaseVariance = phaseVariance;
    syncChirality = chirality;
    syncWinding = winding;
    syncLobes = lobes;
    syncSingularities = singularities;
    syncCollapsePulse = collapsePulse;
    syncMemoryTrace = memoryTrace;
    syncEntropyDelta = entropyDelta;
    syncDistribution[0] = p0;
    syncDistribution[1] = p1;
    syncDistribution[2] = p2;
    syncDistribution[3] = p3;
    syncBasisName = basisName;
    syncOutcomeName = outcomeName;

    ampHist[histHead] = ampMean;
    probHist[histHead] = selectedProbability;
    chirHist[histHead] = chirality * 0.5 + 0.5;
    histHead = (histHead + 1) % HIST;
  }

  public void draw() {
    background(BG);
    drawHeader();
    drawControls(M, 58, 214, 260);
    drawProbabilityPanel(250, 58, 452, 168);
    drawTracePanel(250, 242, 452, 154);
    drawReadouts(M, 332, 214, 64);
    drawFooter();
  }

  void drawHeader() {
    fill(HIGHLIGHT);
    textSize(15);
    textAlign(LEFT, TOP);
    text("Q-LOGIC MEASUREMENT LAYER", M, 14);
    fill(qEnabled ? OK_COL : WARN_COL);
    textSize(10);
    textAlign(RIGHT, TOP);
    text(qEnabled ? "MODE ON" : "MODE OFF", FW - M, 17);
  }

  void drawControls(int x, int y, int w, int h) {
    panel(x, y, w, h, "MEASUREMENT");

    btnEnableX = x + 12; btnEnableY = y + 26; btnEnableW = 88; btnEnableH = 24;
    btnMeasureX = x + 108; btnMeasureY = y + 26; btnMeasureW = 88; btnMeasureH = 24;
    btnAutoX = x + 12; btnAutoY = y + 56; btnAutoW = 184; btnAutoH = 20;
    button(btnEnableX, btnEnableY, btnEnableW, btnEnableH, qEnabled ? "ON" : "OFF", qEnabled ? OK_COL : 0xFF334044);
    button(btnMeasureX, btnMeasureY, btnMeasureW, btnMeasureH, "MEASURE", ACCENT);
    button(btnAutoX, btnAutoY, btnAutoW, btnAutoH, qAutoMeasure ? "AUTO SAMPLE: ON" : "AUTO SAMPLE: OFF", qAutoMeasure ? ACCENT_ALT : 0xFF263238);

    String[] labels = {"POSITION", "CHIRALITY", "ENERGY"};
    int bx = x + 12;
    int by = y + 92;
    int bw = 60;
    for (int i = 0; i < 3; i++) {
      basisRects[i][0] = bx + i * (bw + 3);
      basisRects[i][1] = by;
      basisRects[i][2] = bw;
      basisRects[i][3] = 22;
      button(basisRects[i][0], by, bw, 22, labels[i], qBasis == i ? ACCENT : 0xFF263238);
    }

    drawSlider(0, x + 12, y + 138, w - 24, "MEASURE", qMeasurementStrength, 0, 1);
    drawSlider(1, x + 12, y + 172, w - 24, "COLLAPSE", qCollapseDepth, 0, 1);
    drawSlider(2, x + 12, y + 206, w - 24, "REOPEN", qReopenRate, 0, 0.12);
    drawSlider(3, x + 12, y + 240, w - 24, "MEMORY", qMemoryPersistence, 0.50, 0.99);
  }

  void drawProbabilityPanel(int x, int y, int w, int h) {
    panel(x, y, w, h, "BORN-RULE DISTRIBUTION");
    int bx = x + 18;
    int by = y + 42;
    int bw = (w - 54) / 4;
    int maxH = 74;
    for (int i = 0; i < 4; i++) {
      float p = syncDistribution[i];
      int bh = round(p * maxH);
      fill(16, 24, 28);
      noStroke();
      rect(bx + i * (bw + 6), by, bw, maxH);
      fill(i == syncSelectedOutcome ? ACCENT_ALT : ACCENT);
      rect(bx + i * (bw + 6), by + maxH - bh, bw, bh);
      fill(TEXT_COL);
      textAlign(CENTER, TOP);
      textSize(10);
      text(fmt(p, 3), bx + i * (bw + 6) + bw / 2, by + maxH + 8);
    }

    fill(HIGHLIGHT);
    textAlign(LEFT, TOP);
    textSize(11);
    text("basis " + syncBasisName, x + 18, y + 20);
    text("selected " + syncOutcomeName + "  p=" + fmt(syncSelectedProbability, 3), x + 18, y + h - 28);
    fill(TEXT_COL);
    text("entropy " + fmt(syncDistributionEntropy, 3) + "   measure #" + syncMeasurementId, x + w - 190, y + h - 28);
  }

  void drawTracePanel(int x, int y, int w, int h) {
    panel(x, y, w, h, "X/Y/Z TRACE OVER TIME");
    int gx = x + 18;
    int gy = y + 34;
    int gw = w - 36;
    int gh = h - 54;
    fill(4, 8, 12);
    stroke(GRID_COL);
    rect(gx, gy, gw, gh);
    stroke(AXIS_COL);
    line(gx, gy + gh / 2, gx + gw, gy + gh / 2);
    line(gx + gw / 2, gy, gx + gw / 2, gy + gh);

    noFill();
    strokeWeight(1.5);
    stroke(ACCENT);
    beginShape();
    for (int i = 0; i < HIST; i++) {
      int idx = (histHead + i) % HIST;
      float x3 = gx + i * gw / (float)(HIST - 1);
      float y3 = gy + gh - ampHist[idx] * gh;
      vertex(x3, y3);
    }
    endShape();

    stroke(ACCENT_ALT);
    beginShape();
    for (int i = 0; i < HIST; i++) {
      int idx = (histHead + i) % HIST;
      float x3 = gx + i * gw / (float)(HIST - 1);
      float y3 = gy + gh - probHist[idx] * gh;
      vertex(x3, y3);
    }
    endShape();

    stroke(OK_COL);
    beginShape();
    for (int i = 0; i < HIST; i++) {
      int idx = (histHead + i) % HIST;
      float x3 = gx + i * gw / (float)(HIST - 1);
      float y3 = gy + gh - chirHist[idx] * gh;
      vertex(x3, y3);
    }
    endShape();
    strokeWeight(1);

    fill(TEXT_COL);
    textSize(10);
    textAlign(LEFT, TOP);
    text("X amp   Y prob   Z chirality", gx + 8, gy + 8);
  }

  void drawReadouts(int x, int y, int w, int h) {
    panel(x, y, w, h, "STATE");
    fill(TEXT_COL);
    textSize(10);
    textAlign(LEFT, TOP);
    text("amp " + fmt(syncAmpMean, 3) + " / " + fmt(syncAmpPeak, 3), x + 12, y + 24);
    text("chir " + fmt(syncChirality, 3) + "  wind " + fmt(syncWinding, 3), x + 12, y + 40);
    text("lobes " + syncLobes + "  singular " + syncSingularities, x + 12, y + 56);
  }

  void drawFooter() {
    fill(TEXT_COL);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text("collapse " + fmt(syncCollapsePulse, 3)
      + "   memory " + fmt(syncMemoryTrace, 3)
      + "   entropy delta " + fmt(syncEntropyDelta, 4),
      M, FH - 16);
  }

  void panel(int x, int y, int w, int h, String title) {
    fill(PANEL_BG);
    stroke(GRID_COL);
    rect(x, y, w, h, 4);
    fill(TEXT_COL);
    textSize(10);
    textAlign(LEFT, TOP);
    text(title, x + 10, y + 8);
  }

  void button(int x, int y, int w, int h, String label, int col) {
    fill(col);
    noStroke();
    rect(x, y, w, h, 4);
    fill(0xFF061014);
    textAlign(CENTER, CENTER);
    textSize(10);
    text(label, x + w / 2, y + h / 2 - 1);
  }

  void drawSlider(int idx, int x, int y, int w, String label, float val, float mn, float mx) {
    sliderRects[idx][0] = x;
    sliderRects[idx][1] = y + 15;
    sliderRects[idx][2] = w;
    sliderRects[idx][3] = 12;
    fill(TEXT_COL);
    textAlign(LEFT, TOP);
    textSize(10);
    text(label, x, y);
    textAlign(RIGHT, TOP);
    text(fmt(val, 3), x + w, y);
    fill(18, 28, 32);
    noStroke();
    rect(x, y + 15, w, 12, 3);
    float t = constrain((val - mn) / max(0.0001, mx - mn), 0, 1);
    fill(ACCENT);
    rect(x, y + 15, w * t, 12, 3);
  }

  public void mousePressed() {
    if (hit(btnEnableX, btnEnableY, btnEnableW, btnEnableH)) {
      qEnabled = !qEnabled;
      return;
    }
    if (hit(btnMeasureX, btnMeasureY, btnMeasureW, btnMeasureH)) {
      measureRequest++;
      return;
    }
    if (hit(btnAutoX, btnAutoY, btnAutoW, btnAutoH)) {
      qAutoMeasure = !qAutoMeasure;
      return;
    }
    for (int i = 0; i < 3; i++) {
      if (hit(basisRects[i][0], basisRects[i][1], basisRects[i][2], basisRects[i][3])) {
        qBasis = i;
        return;
      }
    }
    for (int i = 0; i < 4; i++) {
      if (hit(sliderRects[i][0], sliderRects[i][1] - 5, sliderRects[i][2], sliderRects[i][3] + 10)) {
        dragging = i;
        updateSliderFromMouse(i);
        return;
      }
    }
  }

  public void mouseDragged() {
    if (dragging >= 0) updateSliderFromMouse(dragging);
  }

  public void mouseReleased() {
    dragging = -1;
  }

  boolean hit(int x, int y, int w, int h) {
    return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
  }

  void updateSliderFromMouse(int idx) {
    float t = constrain((mouseX - sliderRects[idx][0]) / max(1.0, (float)sliderRects[idx][2]), 0, 1);
    if (idx == 0) qMeasurementStrength = t;
    else if (idx == 1) qCollapseDepth = t;
    else if (idx == 2) qReopenRate = lerp(0.0, 0.12, t);
    else if (idx == 3) qMemoryPersistence = lerp(0.50, 0.99, t);
  }

  String fmt(float value, int decimals) {
    if (Float.isNaN(value) || Float.isInfinite(value)) value = 0;
    decimals = constrain(decimals, 0, 6);
    return String.format(java.util.Locale.US, "%." + decimals + "f", value);
  }
}
