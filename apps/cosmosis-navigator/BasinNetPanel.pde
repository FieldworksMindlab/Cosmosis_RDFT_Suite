/**
 * BasinNetPanel.pde
 *
 * Guarded live BasinNet window. BasinNet sends field intents over OSC;
 * this panel displays the soft-control stream while the main sketch applies
 * only low-authority, confidence-gated nudges.
 */

class BasinNetPanel extends PApplet {
  volatile boolean bnReady = false;

  final int FW = 720;
  final int FH = 420;
  final int M = 18;

  final int BG = 0xFF07090D;
  final int PANEL_BG = 0xFF0A0E12;
  final int GRID_COL = 0xFF1C2628;
  final int AXIS_COL = 0xFF41555A;
  final int TEXT_COL = 0xFFA0C3B9;
  final int HIGHLIGHT = 0xFFDCF0E6;
  final int ACCENT = 0xFF72E0FF;
  final int ACCENT_ALT = 0xFFFFCF77;
  final int OK_COL = 0xFF44DD88;
  final int WARN_COL = 0xFFFF8844;

  volatile boolean previewEnabled = true;
  volatile int intentCount = 0;
  volatile String intentId = "NONE";
  volatile String sourceMode = "none";
  volatile String reason = "waiting";
  volatile int targetBasin = -1;
  volatile int homeBasin = -1;
  volatile int authorityLevel = 0;
  volatile float confidence = 0;
  volatile float riskScore = 0;
  volatile float rootFreq = 0;
  volatile float arpBpm = 0;
  volatile float density = 0;
  volatile float glassLevel = 0;
  volatile float qMeasure = 0;
  volatile float qCollapse = 0;
  volatile float intentTimeSec = 0;
  volatile float intentDurationSec = 0;
  volatile int heartbeatAgeMs = 999999;
  volatile int intentAgeMs = 999999;

  final int HIST = 180;
  float[] confidenceHist = new float[HIST];
  float[] riskHist = new float[HIST];
  float[] densityHist = new float[HIST];
  int histHead = 0;
  int lastSeenCount = -1;

  public void setup() {
    surface.setSize(FW, FH);
    surface.setTitle("Cosmosis BasinNet Live");
    try {
      if (surface != null && surface.getNative() instanceof processing.awt.PSurfaceAWT.SmoothCanvas) {
        javax.swing.JFrame jf = (javax.swing.JFrame)
          ((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
        jf.setDefaultCloseOperation(javax.swing.WindowConstants.HIDE_ON_CLOSE);
      }
    } catch (Exception e) {
      println("BasinNetPanel: could not set HIDE_ON_CLOSE - " + e);
    }
    colorMode(RGB, 255);
    textFont(createFont("Monospaced", 11));
    frameRate(30);
    bnReady = true;
  }

  public void setPanelVisible(boolean visible) {
    try {
      if (surface != null) surface.setVisible(visible);
    } catch (Exception e) {
      println("BasinNetPanel: could not set visibility - " + e);
    }
  }

  synchronized void syncIntent(
    boolean enabled, int count,
    String id, String mode, String why,
    int target, int home, int authority,
    float conf, float risk,
    float root, float bpm,
    float dens, float glass,
    float qMeas, float qColl,
    float tSec, float durSec,
    int hbAge, int inAge
  ) {
    previewEnabled = enabled;
    intentCount = count;
    intentId = id;
    sourceMode = mode;
    reason = why;
    targetBasin = target;
    homeBasin = home;
    authorityLevel = authority;
    confidence = conf;
    riskScore = risk;
    rootFreq = root;
    arpBpm = bpm;
    density = dens;
    glassLevel = glass;
    qMeasure = qMeas;
    qCollapse = qColl;
    intentTimeSec = tSec;
    intentDurationSec = durSec;
    heartbeatAgeMs = hbAge;
    intentAgeMs = inAge;
    if (count != lastSeenCount) {
      confidenceHist[histHead] = constrain(conf, 0, 1);
      riskHist[histHead] = constrain(risk, 0, 1);
      densityHist[histHead] = constrain(dens, 0, 1);
      histHead = (histHead + 1) % HIST;
      lastSeenCount = count;
    }
  }

  public void draw() {
    background(BG);
    drawHeader();
    drawIntentCard(M, 58, 246, 218);
    drawControlCard(282, 58, 420, 218);
    drawTraceCard(M, 294, FW - M * 2, 82);
    drawFooter();
  }

  void drawHeader() {
    fill(HIGHLIGHT);
    textSize(15);
    textAlign(LEFT, TOP);
    text("BASINNET LIVE INTUITION", M, 14);
    boolean fresh = heartbeatAgeMs < 3500;
    fill(fresh ? OK_COL : WARN_COL);
    textAlign(RIGHT, TOP);
    textSize(10);
    text(fresh ? "OSC LIVE" : "WAITING", FW - M, 17);
    fill(TEXT_COL);
    text("guarded soft control | no hard takeover", FW - M, 33);
  }

  void drawIntentCard(int x, int y, int w, int h) {
    panel(x, y, w, h, "CURRENT INTENT");
    int line = y + 34;
    readText(x + 14, line, "mode", sourceMode); line += 22;
    readText(x + 14, line, "reason", reason); line += 22;
    readText(x + 14, line, "intent", shorten(intentId, 24)); line += 22;
    readText(x + 14, line, "target/home", targetBasin + " / " + homeBasin); line += 22;
    readText(x + 14, line, "authority", "level " + authorityLevel); line += 22;
    readText(x + 14, line, "count", str(intentCount)); line += 22;
    readText(x + 14, line, "age", fmt(intentAgeMs / 1000.0, 2) + "s"); line += 22;
    fill(previewEnabled ? OK_COL : WARN_COL);
    textAlign(LEFT, TOP);
    text(previewEnabled ? "SOFT LIVE ARMED" : "SOFT LIVE MUTED", x + 14, y + h - 26);
  }

  void drawControlCard(int x, int y, int w, int h) {
    panel(x, y, w, h, "PROPOSED SOFT CONTROLS");
    drawMeter(x + 18, y + 40, 160, "confidence", confidence, 0, 1, ACCENT);
    drawMeter(x + 222, y + 40, 160, "risk", riskScore, 0, 1, riskScore > 0.7 ? WARN_COL : ACCENT_ALT);
    drawMeter(x + 18, y + 86, 160, "density", density, 0, 1, ACCENT);
    drawMeter(x + 222, y + 86, 160, "glass", glassLevel, 0, 1, ACCENT);
    drawMeter(x + 18, y + 132, 160, "q-measure", qMeasure, 0, 1, ACCENT_ALT);
    drawMeter(x + 222, y + 132, 160, "q-collapse", qCollapse, 0, 1, ACCENT_ALT);
    fill(HIGHLIGHT);
    textAlign(LEFT, TOP);
    textSize(11);
    text("root " + fmt(rootFreq, 2) + " Hz", x + 18, y + h - 30);
    text("arp " + fmt(arpBpm, 1) + " BPM", x + 222, y + h - 30);
  }

  void drawTraceCard(int x, int y, int w, int h) {
    panel(x, y, w, h, "INTENT TRACE");
    int gx = x + 14;
    int gy = y + 28;
    int gw = w - 28;
    int gh = h - 42;
    fill(4, 8, 12);
    stroke(GRID_COL);
    rect(gx, gy, gw, gh, 4);
    drawTrace(confidenceHist, gx, gy, gw, gh, ACCENT);
    drawTrace(riskHist, gx, gy, gw, gh, WARN_COL);
    drawTrace(densityHist, gx, gy, gw, gh, OK_COL);
    fill(TEXT_COL);
    noStroke();
    textAlign(RIGHT, TOP);
    textSize(9);
    text("cyan=confidence  amber=risk  green=density", x + w - 14, y + h - 15);
  }

  void drawFooter() {
    fill(TEXT_COL);
    textAlign(LEFT, TOP);
    textSize(10);
    text("heartbeat age " + fmt(heartbeatAgeMs / 1000.0, 2) + "s   intent t=" + fmt(intentTimeSec, 2) + "s dur=" + fmt(intentDurationSec, 2) + "s", M, FH - 28);
  }

  void panel(int x, int y, int w, int h, String title) {
    noStroke();
    fill(PANEL_BG);
    rect(x, y, w, h, 7);
    stroke(GRID_COL);
    noFill();
    rect(x, y, w, h, 7);
    fill(HIGHLIGHT);
    textAlign(LEFT, TOP);
    textSize(12);
    text(title, x + 12, y + 10);
  }

  void readText(int x, int y, String label, String value) {
    fill(TEXT_COL);
    textAlign(LEFT, TOP);
    textSize(10);
    text(label, x, y);
    fill(HIGHLIGHT);
    text(value, x + 88, y);
  }

  void drawMeter(int x, int y, int w, String label, float value, float lo, float hi, int col) {
    float n = constrain((value - lo) / max(0.0001, hi - lo), 0, 1);
    fill(TEXT_COL);
    textAlign(LEFT, TOP);
    textSize(10);
    text(label + " " + fmt(value, 3), x, y);
    noStroke();
    fill(28, 40, 46);
    rect(x, y + 17, w, 7);
    fill(col);
    rect(x, y + 17, w * n, 7);
  }

  void drawTrace(float[] arr, int x, int y, int w, int h, int col) {
    stroke(col);
    noFill();
    beginShape();
    for (int i = 0; i < w; i++) {
      int idx = (histHead + i * arr.length / max(1, w)) % arr.length;
      float v = constrain(arr[idx], 0, 1);
      vertex(x + i, y + h - v * h);
    }
    endShape();
  }

  String shorten(String value, int maxLen) {
    if (value == null) return "";
    if (value.length() <= maxLen) return value;
    return value.substring(0, max(0, maxLen - 3)) + "...";
  }

  String fmt(float value, int decimals) {
    if (Float.isNaN(value) || Float.isInfinite(value)) value = 0;
    decimals = constrain(decimals, 0, 6);
    return String.format(java.util.Locale.US, "%." + decimals + "f", value);
  }
}
