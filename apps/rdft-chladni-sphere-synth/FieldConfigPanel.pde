/**
 * FieldConfigPanel.pde
 *
 * Tab in HOLO_DRIVE_RDFT_EG_SYNTH sketch folder.
 * PApplet subclass — launched as a second window via PApplet.runSketch().
 * Replaces SpectrumAnalyzer.pde entirely.
 *
 * Two panels:
 *   LEFT  — Electrogravity (Biefeld-Brown RDFT interpretation)
 *   RIGHT — UFO Field Morphology (disc ↔ jellyfish transition)
 *
 * The main sketch calls fcPanel.syncState(...) every frame to push
 * current field values in. The panel never reaches back into the main
 * sketch — all communication is one-way push + return of user-set
 * control values via public fields that the main sketch reads.
 */

class FieldConfigPanel extends PApplet {

  // ── Ready guard ───────────────────────────────────────────────────────────
  volatile boolean fcReady = false;

  // ── Window geometry ───────────────────────────────────────────────────────
  final int FW = 720;
  final int FH = 460;
  final int M  = 18;   // margin

  // ── Palette (matches main sketch dark theme) ──────────────────────────────
  final int BG        = 0xFF07090D;
  final int PANEL_BG  = 0xFF0A0E12;
  final int GRID_COL  = 0xFF1C2628;
  final int AXIS_COL  = 0xFF41555A;
  final int TEXT_COL  = 0xFFA0C3B9;
  final int HIGHLIGHT = 0xFFDCF0E6;
  final int ACCENT_EG = 0xFF44AAFF;   // electrogravity blue
  final int ACCENT_UFO= 0xFFFFAA33;   // UFO amber→cyan handled via lerp
  final int WARN_COL  = 0xFFFF5533;
  final int OK_COL    = 0xFF44DD88;

  // ── State synced from main sketch each frame ──────────────────────────────
  volatile float syncAlpha          = 2.0;
  volatile float syncDepth          = 4.0;
  volatile float syncOrbM           = 1.0;
  volatile float syncOrbR           = 1.2;       // current orbital radius
  volatile float syncOrbitLock      = 0.0;
  volatile float syncCoherence      = 0.0;
  volatile float syncLyapunov       = 0.0;
  volatile float syncSolarXray      = 0.0;
  volatile float syncSolarWind      = 0.0;
  volatile float syncSolarKp        = 0.0;
  volatile boolean syncSolarLive    = false;

  // ── Computed emergent electrogravity (written by main sketch) ────────────
  // Main sketch computes this from the field; panel displays it.
  volatile float syncEmergentEG     = 1.0;   // 0=fully reduced, 1=normal gravity
  volatile float syncVoltageEG      = 0.0;   // current effective injection voltage

  // ── USER CONTROLS — main sketch reads these public fields ─────────────────
  // Electrogravity
  float  egCouplingStrength  = 0.015;   // how hard voltage pushes the field
  float  egInjectedVoltage   = 0.0;    // 0–100 kV manual injection
  boolean egEnabled          = true;
  boolean egSolarAuto        = false;  // solar data drives injection

  // UFO morphology
  boolean ufoModeOn          = false;
  float   ufoTransition      = 0.0;   // 0=disc, 1=jellyfish

  // Button rects — stored at draw time, used in mousePressed
  int[] btnSolarRect = new int[]{0,0,0,0};
  int[] btnEGRect    = new int[]{0,0,0,0};
  int[] btnUFORect   = new int[]{0,0,0,0};

  // ── Layout rects ─────────────────────────────────────────────────────────
  // Left panel: electrogravity
  int egX, egY, egW, egH;
  // Right panel: UFO morphology
  int ufX, ufY, ufW, ufH;
  // Shared bottom strip: field state readout
  int rdX, rdY, rdW, rdH;

  // ── Slider drag state ────────────────────────────────────────────────────
  // Simple hand-rolled sliders — no ControlP5 dependency in the popup.
  int   dragging      = -1;   // which slider is active (-1 = none)
  // Slider ids:
  //  0 = egInjectedVoltage  (0–100)
  //  1 = egCouplingStrength (0–0.05)
  //  2 = ufoTransition      (0–1)
  final int SL_VOLTAGE  = 0;
  final int SL_COUPLING = 1;
  final int SL_UFO      = 2;

  // slider screen rects [x,y,w,h]
  int[][] sliderRects = new int[3][4];

  // ── History sparklines ────────────────────────────────────────────────────
  final int HIST = 180;
  float[] egHistory  = new float[HIST];
  float[] ufoHistory = new float[HIST];   // alpha proxy over time
  int histHead = 0;

  int tick = 0;

  // ==========================================================================
  // setup
  // ==========================================================================
  public void setup() {
    surface.setSize(FW, FH);
    surface.setTitle("RDFT Field Configuration");
    try {
      if (surface != null && surface.getNative() instanceof processing.awt.PSurfaceAWT.SmoothCanvas) {
        javax.swing.JFrame jf = (javax.swing.JFrame)
          ((processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative()).getFrame();
        jf.setDefaultCloseOperation(javax.swing.WindowConstants.HIDE_ON_CLOSE);
      }
    } catch (Exception e) {
      println("FieldConfigPanel: could not set HIDE_ON_CLOSE - " + e);
    }
    colorMode(RGB, 255);
    textFont(createFont("Monospaced", 11));
    frameRate(30);

    int halfW = (FW - M * 3) / 2;

    egX = M;            egY = 44;
    egW = halfW;        egH = FH - egY - M - 70;

    ufX = M*2 + halfW;  ufY = 44;
    ufW = halfW;        ufH = egH;

    rdX = M;            rdY = egY + egH + 8;
    rdW = FW - M*2;     rdH = FH - rdY - M;

    // Pre-position sliders inside panels (set in drawEGPanel / drawUFOPanel)
    fcReady = true;
  }

  public void setPanelVisible(boolean visible) {
    try {
      if (surface != null) surface.setVisible(visible);
    } catch (Exception e) {
      println("FieldConfigPanel: could not set visibility - " + e);
    }
  }

  // ==========================================================================
  // Main sketch calls this every frame to push field state in
  // ==========================================================================
  synchronized void syncState(
      float alpha, float depth, float orbM, float orbR,
      float orbitLock, float coherence, float lyapunov,
      float solarXray, float solarWind, float solarKp, boolean solarLive,
      float emergentEG, float voltageEG
  ) {
    syncAlpha       = alpha;
    syncDepth       = depth;
    syncOrbM        = orbM;
    syncOrbR        = orbR;
    syncOrbitLock   = orbitLock;
    syncCoherence   = coherence;
    syncLyapunov    = lyapunov;
    syncSolarXray   = solarXray;
    syncSolarWind   = solarWind;
    syncSolarKp     = solarKp;
    syncSolarLive   = solarLive;
    syncEmergentEG  = emergentEG;
    syncVoltageEG   = voltageEG;
  }

  // ==========================================================================
  // draw
  // ==========================================================================
  public void draw() {
    if (!fcReady) return;
    tick++;

    // Solar auto-drive: if enabled, push injection voltage from solar data
    if (egSolarAuto && syncSolarLive) {
      egInjectedVoltage = constrain((syncSolarXray + syncSolarWind) * 50.0, 0, 100);
    }

    // History
    if (tick % 2 == 0) {
      egHistory[histHead]  = syncEmergentEG;
      ufoHistory[histHead] = syncAlpha;
      histHead = (histHead + 1) % HIST;
    }

    background(BG);
    drawFCHeader();
    drawEGPanel();
    drawUFOPanel();
    drawFieldStateStrip();
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================
  void drawFCHeader() {
    fill(HIGHLIGHT); textSize(14); textAlign(LEFT, TOP);
    text("RDFT FIELD CONFIGURATION", M, M);

    fill(TEXT_COL); textSize(9); textAlign(RIGHT, TOP);
    String solarStr = syncSolarLive
      ? ("SOLAR LIVE  x=" + nf(syncSolarXray,1,2) + " w=" + nf(syncSolarWind,1,2) + " kp=" + nf(syncSolarKp,1,1))
      : "SOLAR: WAITING";
    fill(syncSolarLive ? OK_COL : AXIS_COL);
    text(solarStr, FW - M, M + 2);

    stroke(GRID_COL); strokeWeight(1);
    line(M, 40, FW - M, 40);
    noStroke();
  }

  // ==========================================================================
  // LEFT — ELECTROGRAVITY PANEL
  // ==========================================================================
  void drawEGPanel() {
    int x = egX, y = egY, w = egW, h = egH;

    // Background
    fill(PANEL_BG); noStroke(); rect(x, y, w, h, 4);
    noFill(); stroke(egEnabled ? ACCENT_EG : AXIS_COL); strokeWeight(1);
    rect(x, y, w, h, 4);
    noStroke();

    // Title
    fill(ACCENT_EG); textSize(11); textAlign(LEFT, TOP);
    text("ELECTROGRAVITY", x + 8, y + 7);
    fill(egEnabled ? OK_COL : WARN_COL); textSize(9);
    text(egEnabled ? "ENABLED" : "DISABLED", x + w - 70, y + 8);

    int cy = y + 28;
    int sw = w - 20;   // slider width
    int sx = x + 10;

    // ── EMERGENT BASE readout (computed, not draggable) ───────────────────
    fill(TEXT_COL); textSize(9); textAlign(LEFT, TOP);
    text("EMERGENT FIELD FACTOR  [α=" + nf(syncAlpha,1,2) + "  R=" + nf(syncDepth,1,0) + "  m=" + nf(syncOrbM,1,2) + "]", sx, cy);
    cy += 13;

    // Gauge bar for emergent EG factor
    float egF = constrain(syncEmergentEG, 0, 1);
    fill(30, 40, 50); rect(sx, cy, sw, 10, 2);
    // Color: green=normal gravity, amber=reduced, red=near-zero
    int barCol = egF > 0.7 ? color(60, 200, 120) :
                   egF > 0.4 ? color(220, 180, 40) : color(220, 60, 40);
    fill(barCol); rect(sx, cy, sw * egF, 10, 2);
    fill(HIGHLIGHT); textSize(8); textAlign(RIGHT, TOP);
    text("g_eff = " + nf(egF, 1, 3), sx + sw, cy + 12);
    cy += 26;

    // EG sparkline
    fill(TEXT_COL); textSize(8); textAlign(LEFT, TOP);
    text("g_eff history", sx, cy);
    cy += 11;
    fill(18, 24, 30); rect(sx, cy, sw, 32, 2);
    stroke(ACCENT_EG, 160); strokeWeight(1); noFill(); beginShape();
    for (int i = 0; i < HIST; i++) {
      int idx = (histHead + i) % HIST;
      float hx = map(i, 0, HIST - 1, sx + 2, sx + sw - 2);
      float hy = map(egHistory[idx], 0, 1, cy + 30, cy + 2);
      vertex(hx, hy);
    }
    endShape();
    noStroke();
    cy += 40;

    // ── VOLTAGE INJECTION slider ──────────────────────────────────────────
    text("VOLTAGE INJECTION  (kV)  — perturbation force", sx, cy);
    cy += 13;
    sliderRects[SL_VOLTAGE] = new int[]{sx, cy, sw, 12};
    drawSlider(SL_VOLTAGE, egInjectedVoltage, 0, 100,
               egSolarAuto ? color(80, 130, 100) : color(ACCENT_EG),
               egSolarAuto ? "SOLAR AUTO" : (nf(egInjectedVoltage, 1, 1) + " kV"));
    cy += 24;

    // Effective voltage (injection + emergent combined) readout
    fill(TEXT_COL); textSize(8); textAlign(LEFT, TOP);
    text("EFFECTIVE:  " + nf(syncVoltageEG, 1,2) + " kV   [injection + emergent composite]", sx, cy);
    cy += 20;

    // ── COUPLING STRENGTH slider ──────────────────────────────────────────
    fill(TEXT_COL); textSize(9); textAlign(LEFT, TOP);
    text("FIELD COUPLING  (α→g sensitivity)", sx, cy);
    cy += 13;
    sliderRects[SL_COUPLING] = new int[]{sx, cy, sw, 12};
    drawSlider(SL_COUPLING, egCouplingStrength, 0, 0.05,
               color(180, 140, 60),
               nf(egCouplingStrength, 1, 4));
    cy += 28;

    // ── SOLAR AUTO toggle ─────────────────────────────────────────────────
    btnSolarRect = new int[]{sx, cy, 110, 18};
    btnEGRect    = new int[]{sx + 120, cy, 90, 18};
    drawToggleButton(sx, cy, 110, 18, "SOLAR AUTO",
                     egSolarAuto, 10001);
    drawToggleButton(sx + 120, cy, 90, 18, egEnabled ? "ON" : "OFF",
                     egEnabled, 10002);
    cy += 26;

    // ── Physics annotation ────────────────────────────────────────────────
    fill(AXIS_COL); textSize(8); textAlign(LEFT, TOP);
    text("g_eff = G₀M/r²  · pow(α, 2·γ·φ)  · f(voltage, coupling)", sx, cy);
    cy += 12;
    text("Voltage shifts field toward alt α/R minimum — not mass change", sx, cy);
  }

  // ==========================================================================
  // RIGHT — UFO MORPHOLOGY PANEL
  // ==========================================================================
  void drawUFOPanel() {
    int x = ufX, y = ufY, w = ufW, h = ufH;
    float t = constrain(ufoTransition, 0, 1);

    // Border color interpolates disc→jellyfish
    int discCol  = color(255, 200, 80);    // warm amber — metallic disc
    int jellyCol = color(80, 180, 255);    // cool cyan — diffuse jellyfish
    int borderC  = lerpColor(discCol, jellyCol, t);

    fill(PANEL_BG); noStroke(); rect(x, y, w, h, 4);
    noFill(); stroke(ufoModeOn ? borderC : AXIS_COL); strokeWeight(1);
    rect(x, y, w, h, 4);
    noStroke();

    // Title
    fill(borderC); textSize(11); textAlign(LEFT, TOP);
    text("UFO FIELD MORPHOLOGY", x + 8, y + 7);
    fill(ufoModeOn ? OK_COL : AXIS_COL); textSize(9);
    text(ufoModeOn ? "ACTIVE" : "PASSIVE", x + w - 65, y + 8);

    int cy = y + 28;
    int sw = w - 20;
    int sx = x + 10;

    // ── PARTICLE PREVIEW ──────────────────────────────────────────────────
    // Visual demonstration of disc vs jellyfish appearance
    int previewW = sw;
    int previewH = 80;
    fill(12, 14, 20); rect(sx, cy, previewW, previewH, 3);

    // Draw the particle in its current morphology state
    float pcx = sx + previewW * 0.5;
    float pcy = cy + previewH * 0.5;
    drawMorphParticle(pcx, pcy, t);

    // Labels at each end
    fill(discCol); textSize(8); textAlign(LEFT, CENTER);
    text("DISC", sx + 4, cy + previewH * 0.5);
    fill(jellyCol); textAlign(RIGHT, CENTER);
    text("JELLYFISH", sx + previewW - 4, cy + previewH * 0.5);

    // Field config annotation
    fill(TEXT_COL); textSize(8); textAlign(CENTER, TOP);
    String regime = t < 0.25 ? "HIGH α  LOW R" :
                    t < 0.75 ? "TRANSITIONAL" : "LOW α  HIGH R";
    text(regime, pcx, cy + previewH - 11);
    cy += previewH + 8;

    // ── DISC→JELLYFISH slider ─────────────────────────────────────────────
    fill(TEXT_COL); textSize(9); textAlign(LEFT, TOP);
    text("DISC  ←————→  JELLYFISH", sx, cy);
    cy += 13;
    sliderRects[SL_UFO] = new int[]{sx, cy, sw, 12};
    drawSlider(SL_UFO, ufoTransition, 0, 1, borderC,
               nf(t, 1, 2));
    cy += 24;

    // ── Implied field parameters readout ──────────────────────────────────
    float impliedAlpha = lerp(4.5, 1.1, t);
    float impliedDepth = lerp(2,   7,   t);
    fill(TEXT_COL); textSize(9); textAlign(LEFT, TOP);
    text("IMPLIED FIELD STATE:", sx, cy);
    cy += 13;

    // Alpha bar
    fill(28, 36, 44); rect(sx, cy, sw, 9, 2);
    fill(lerpColor(discCol, jellyCol, t));
    rect(sx, cy, sw * map(impliedAlpha, 1.1, 4.5, 0, 1), 9, 2);
    fill(TEXT_COL); textSize(8); textAlign(RIGHT, TOP);
    text("α=" + nf(impliedAlpha, 1, 2), sx + sw, cy + 10);
    cy += 20;

    // Depth bar
    fill(28, 36, 44); rect(sx, cy, sw, 9, 2);
    fill(lerpColor(jellyCol, discCol, t));   // inverted — depth rises with jellyfish
    rect(sx, cy, sw * map(impliedDepth, 2, 7, 0, 1), 9, 2);
    fill(TEXT_COL); textSize(8); textAlign(RIGHT, TOP);
    text("R=" + nf(impliedDepth, 1, 1), sx + sw, cy + 10);
    cy += 24;

    // ── UFO MODE toggle + annotation ──────────────────────────────────────
    btnUFORect = new int[]{sx, cy, 100, 18};
    drawToggleButton(sx, cy, 100, 18, "UFO MODE", ufoModeOn, 10003);
    cy += 26;

    // Morphology table
    fill(AXIS_COL); textSize(8); textAlign(LEFT, TOP);
    String[] rows = {
      "  DISC    high α  low R   sharp  metallic  silent",
      "  TIC-TAC  med α  med R   smooth  detail  wake",
      "  JELLY   low α  high R  diffuse  glow  drifts"
    };
    color[] rowCols = { discCol, color(200, 200, 120), jellyCol };
    for (int i = 0; i < rows.length; i++) {
      float rowT = i / 2.0;
      fill(t > rowT - 0.33 && t < rowT + 0.5 ? rowCols[i] : AXIS_COL);
      text(rows[i], sx, cy);
      cy += 11;
    }
  }

  // ==========================================================================
  // PARTICLE MORPH VISUAL
  // The heart of the UFO visual. Lightweight — only ellipse() calls.
  // Disc: tight bright hot core, sharp edge, minimal glow
  // Jellyfish: large diffuse halos, cool color, no hard edge, pulsing feel
  // ==========================================================================
  void drawMorphParticle(float cx, float cy, float t) {
    // Colors
    int discCore  = color(255, 210, 100);
    int jellyCore = color(100, 200, 255);
    int coreCol   = lerpColor(discCore, jellyCore, t);

    // Geometry
    float coreSize  = lerp(7,  16,  t);   // disc is tight; jellyfish spreads
    float glowCount = lerp(1,   4,  t);   // disc has 1 glow ring; jellyfish has 4
    float glowBase  = lerp(12, 28,  t);   // glow start radius
    float glowStep  = lerp(5,  14,  t);   // spacing between halos
    float glowAlpha = lerp(80, 35,  t);   // disc glow is brighter; jellyfish fainter per ring

    // Trail color shift — drawn externally by drawOrbitalPanel, but we preview it
    // here as a horizontal smear to the left of the particle
    noStroke();
    for (int i = 1; i <= 8; i++) {
      float trailX = cx - i * lerp(4, 2, t);
      float trailA = map(i, 1, 8, lerp(120, 60, t), 0);
      float trailR = lerp(3, 6, t);
      fill(red(coreCol), green(coreCol), blue(coreCol), trailA);
      ellipse(trailX, cy, trailR, trailR);
    }

    // Glow halos — only drawn for jellyfish regime (t > 0)
    int nHalos = max(1, round(glowCount));
    for (int i = nHalos; i >= 1; i--) {
      float hr = glowBase + i * glowStep;
      float ha = glowAlpha * (1.0 - (float)i / (nHalos + 1));
      // Jellyfish halos pulse slightly
      if (t > 0.3) {
        float pulse = sin(millis() * 0.002 * (1 + t * 2) + i) * t * 4;
        hr += pulse;
      }
      fill(red(coreCol), green(coreCol), blue(coreCol), ha * (1 - t * 0.4));
      ellipse(cx, cy, hr, hr * lerp(1.0, 0.85, t));  // jellyfish is slightly oblate
    }

    // Hard edge ring — disc only (fades out with t)
    if (t < 0.6) {
      stroke(coreCol); strokeWeight(lerp(1.5, 0.2, t));
      noFill(); ellipse(cx, cy, coreSize + 4, coreSize + 4);
      noStroke();
    }

    // Core
    fill(coreCol);
    ellipse(cx, cy, coreSize, coreSize);

    // Disc: bright hot center spot
    if (t < 0.5) {
      fill(255, 255, 255, lerp(180, 0, t * 2));
      ellipse(cx, cy, coreSize * 0.35, coreSize * 0.35);
    }
  }

  // ==========================================================================
  // BOTTOM STRIP — live field state
  // ==========================================================================
  void drawFieldStateStrip() {
    int x = rdX, y = rdY, w = rdW, h = rdH;
    fill(PANEL_BG); noStroke(); rect(x, y, w, h, 3);
    noFill(); stroke(GRID_COL); rect(x, y, w, h, 3); noStroke();

    int cx = x + 10;
    fill(TEXT_COL); textSize(8); textAlign(LEFT, CENTER);
    float my = y + h * 0.5;

    // Change 6 — Beltrami alignment added to field state strip.
    // Values near ±1 = orbital on a field line (BELTRAMI_ALIGNED).
    // Values near 0  = orbital shearing across field lines (BELTRAMI_SHEARED).
    // In UFO mode, sustained alignment here confirms traversal is working.
    String[] labels = { "α", "R", "orb_r", "lock", "coh", "lyap", "B·curl" };
    float[]  vals   = {
      syncAlpha, syncDepth, syncOrbR,
      syncOrbitLock, syncCoherence, syncLyapunov,
      syncBeltramiAlignment
    };
    int colW = (w - 20) / labels.length;
    for (int i = 0; i < labels.length; i++) {
      // Highlight Beltrami alignment specially — color-coded by alignment quality
      if (i == 6) {
        float bAlign = constrain(abs(syncBeltramiAlignment), 0, 1);
        fill(lerpColor(color(180, 60, 60), color(60, 220, 140), bAlign));
      } else {
        fill(AXIS_COL);
      }
      text(labels[i], cx + i * colW, my - 7);
      fill(HIGHLIGHT); textSize(9);
      text(nf(vals[i], 1, 3), cx + i * colW, my + 5);
      textSize(8);
    }

    // EG factor large readout on right
    fill(syncEmergentEG < 0.7 ? WARN_COL : OK_COL);
    textAlign(RIGHT, CENTER); textSize(10);
    text("g_eff " + nf(syncEmergentEG, 1, 3)
         + "   V=" + nf(syncVoltageEG, 1, 1) + "kV"
         + "   UFO-T=" + nf(constrain(ufoTransition, 0, 1), 1, 2),
         x + w - 10, my);

    // Holographic surface Landauer readout — shown when surface is live
    if (syncSurfaceReady) {
      // Colour: amber=high curvature/erased, cyan=flat/coherent
      color lCol = lerpColor(color(255, 140, 40), color(60, 220, 240),
                             syncLandauerCoherence);
      fill(lCol); textSize(8); textAlign(LEFT, BOTTOM);
      text("SURFACE  curv=" + nf(syncSurfaceCurv, 1, 2)
           + "  Ls=" + nf(syncLandauerS, 1, 3)
           + "  coh=" + nf(syncLandauerCoherence, 1, 2)
           + "  [HOLOGRAPHIC BOUNDARY ACTIVE]",
           x + 10, y + h - 3);
    } else {
      fill(AXIS_COL); textSize(8); textAlign(LEFT, BOTTOM);
      text("SURFACE: waiting for surface_sender.py on :5056", x + 10, y + h - 3);
    }
  }

  // ==========================================================================
  // SLIDER — hand-rolled, minimal
  // ==========================================================================
  void drawSlider(int id, float val, float mn, float mx, color c, String label) {
    int[] r = sliderRects[id];
    if (r == null) return;
    int sx = r[0], sy = r[1], sw = r[2], sh = r[3];

    float norm = constrain(map(val, mn, mx, 0, 1), 0, 1);

    // Track
    fill(25, 35, 45); noStroke(); rect(sx, sy, sw, sh, 2);

    // Fill
    fill(red(c) * 0.5, green(c) * 0.5, blue(c) * 0.5, 180);
    rect(sx, sy, sw * norm, sh, 2);

    // Thumb
    float tx = sx + sw * norm;
    stroke(c); strokeWeight(1.5);
    line(tx, sy - 2, tx, sy + sh + 2);
    noStroke();

    // Label
    fill(c); textSize(8); textAlign(CENTER, TOP);
    text(label, sx + sw * 0.5, sy + sh + 3);
  }

  // ==========================================================================
  // TOGGLE BUTTON — drawn, clicked via mousePressed
  // ==========================================================================
  void drawToggleButton(int bx, int by, int bw, int bh,
                        String label, boolean state, int id) {
    int on  = color(40, 100, 70);
    int off = color(50, 30, 30);
    int onB = color(60, 200, 120);
    int offB= color(140, 60, 60);
    fill(state ? on : off); noStroke(); rect(bx, by, bw, bh, 3);
    noFill(); stroke(state ? onB : offB); rect(bx, by, bw, bh, 3); noStroke();
    fill(state ? onB : offB); textSize(9); textAlign(CENTER, CENTER);
    text(label, bx + bw * 0.5, by + bh * 0.5);
  }

  // ==========================================================================
  // Mouse interaction
  // ==========================================================================
  public void mousePressed() {
    // Check toggle buttons using rects stored at draw time
    checkToggle(mouseX, mouseY, btnSolarRect, 10001);
    checkToggle(mouseX, mouseY, btnEGRect,    10002);
    checkToggle(mouseX, mouseY, btnUFORect,   10003);

    // Check sliders
    for (int id = 0; id < 3; id++) {
      int[] r = sliderRects[id];
      if (r == null) continue;
      if (mouseX >= r[0] - 4 && mouseX <= r[0] + r[2] + 4 &&
          mouseY >= r[1] - 6 && mouseY <= r[1] + r[3] + 6) {
        dragging = id;
        applyDrag(id, mouseX);
        break;
      }
    }
  }

  void checkToggle(int mx, int my, int[] r, int id) {
    if (r == null) return;
    if (mx >= r[0] && mx <= r[0] + r[2] && my >= r[1] && my <= r[1] + r[3]) {
      switch (id) {
        case 10001: egSolarAuto = !egSolarAuto; break;
        case 10002: egEnabled   = !egEnabled;   break;
        case 10003: ufoModeOn   = !ufoModeOn;   break;
      }
    }
  }

  public void mouseDragged() {
    if (dragging >= 0) applyDrag(dragging, mouseX);
  }

  public void mouseReleased() {
    dragging = -1;
  }

  void applyDrag(int id, int mx) {
    int[] r = sliderRects[id];
    if (r == null) return;
    float norm = constrain(map(mx, r[0], r[0] + r[2], 0, 1), 0, 1);
    switch (id) {
      case SL_VOLTAGE:  egInjectedVoltage   = norm * 100.0;   break;
      case SL_COUPLING: egCouplingStrength  = norm * 0.05;    break;
      case SL_UFO:      ufoTransition       = norm;           break;
    }
  }

  // ==========================================================================
  // Keyboard shortcuts
  // ==========================================================================
  public void keyPressed() {
    switch (key) {
      case 'e': case 'E': egEnabled  = !egEnabled;  break;
      case 's': case 'S': egSolarAuto= !egSolarAuto; break;
      case 'u': case 'U': ufoModeOn  = !ufoModeOn;  break;
      case '0': ufoTransition = 0.0; break;   // snap to disc
      case '1': ufoTransition = 1.0; break;   // snap to jellyfish
      case 'r': case 'R':                      // reset injection
        egInjectedVoltage = 0;
        egSolarAuto = false;
        break;
    }
  }

  // ==========================================================================
  // Change 5 — getUfoBlend()
  // Single normalised float representing current mode:
  //   0.0 = full field mode (UFO off, or disc with no transition)
  //   1.0 = full UFO jellyfish mode
  // The main sketch can use this instead of checking two conditions everywhere.
  // ==========================================================================
  float getUfoBlend() {
    return ufoModeOn ? constrain(ufoTransition, 0, 1) : 0.0;
  }

  // ==========================================================================
  // Change 6 — Beltrami alignment sync from main sketch
  // The main sketch pushes beltramiAlignment each frame so the panel can
  // display the field-line threading status. When alignment is sustained
  // near ±1 in UFO mode, the orbital is on a field line.
  // ==========================================================================
  volatile float syncBeltramiAlignment = 0.0;

  // Holographic surface boundary state (pushed from main sketch)
  volatile float syncLandauerS         = 0.0;
  volatile float syncLandauerCoherence = 1.0;
  volatile float syncSurfaceCurv       = 0.0;
  volatile boolean syncSurfaceReady    = false;

  void syncBeltrami(float alignment) {
    syncBeltramiAlignment = alignment;
  }

  // Push holographic surface state from main sketch each frame
  void syncLandauer(float landS, float landCoh, float curv, boolean ready) {
    syncLandauerS         = landS;
    syncLandauerCoherence = landCoh;
    syncSurfaceCurv       = curv;
    syncSurfaceReady      = ready;
  }
}
