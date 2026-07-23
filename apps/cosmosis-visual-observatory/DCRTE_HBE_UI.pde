/* M6-HX dedicated operator lens. The established M0-M6 controls remain unchanged. */

void drawDcrteHbeLens(int x, int y, int w, int h) {
  drawPanelShell(x, y, w, h, "HOLOGRAPHIC BRIDGE EXPLORER");
  fill(105, 155, 164); textAlign(LEFT, TOP); textSize(9);
  text("CLASSICAL ANALOG TESTBED | INSPIRED BY BISWAS ET AL. 2026", x + 18, y + 34);

  int bannerY = y + 50;
  fill(24, 18, 14); stroke(180, 127, 52); rect(x + 18, bannerY, w - 36, 32, 4);
  fill(255, 196, 82); textAlign(CENTER, CENTER); textSize(9);
  text("CLASSICAL FIELD / GRAPH / SCHEDULER PROXIES   |   NOT A QUANTUM CODE OR WORMHOLE SIMULATION",
    x + w / 2, bannerY + 16);

  int bodyY = y + 94;
  int rightW = constrain(round(w * 0.32f), 360, 418);
  int gap = 18;
  int viewW = w - rightW - gap - 36;
  int rightX = x + 18 + viewW + gap;
  drawDcrteHbeVisualization(x + 18, bodyY, viewW, h - 112);
  drawDcrteHbeControls(rightX, bodyY, rightW, h - 112);
}

void drawDcrteHbeControls(int x, int y, int w, int h) {
  int controlH = min(548, h - 172);
  drawReadoutPanel(x, y, w, controlH, "EXPERIMENT CONTROL");
  int px = x + 12, py = y + 32, gap = 6;
  int bw = (w - 30) / 2;
  color on = color(24, 116, 94), neutral = color(45, 72, 82);
  color warn = color(126, 82, 34), off = color(75, 64, 73);
  boolean feedbackReady = dcrteHbePreparedMetrics != null;
  boolean snapshotReady = dcrteHbeSnapshot != null && dcrteHbeSnapshot.isValid();
  boolean candidateReady = dcrteSchedulerController != null && dcrteSchedulerController.snapshot != null;
  boolean canMaterialize = dcrteSchedulerController != null && dcrteSchedulerController.canMaterialize();
  boolean meshCurrent = dcrteSchedulerController != null && dcrteSchedulerController.canExportCurrentMesh();

  drawButton(px, py, bw, 24, dcrteHbeEnabled ? "HBE ON" : "HBE OFF",
    dcrteHbeEnabled ? on : off);
  drawButton(px + bw + gap, py, bw, 24, "LOAD FIXTURE", neutral);
  py += 29;
  drawButton(px, py, w - 24, 24, feedbackReady ? "FEEDBACK CAPTURED" : "CAPTURE FEEDBACK",
    feedbackReady ? on : color(66, 83, 104));
  py += 29;
  drawButton(px, py, bw, 24, snapshotReady ? "SNAPSHOT READY" : "BUILD SNAPSHOT",
    snapshotReady ? on : neutral);
  drawButton(px + bw + gap, py, bw, 24, candidateReady ? "CANDIDATE READY" : "GENERATE CANDIDATE",
    candidateReady ? on : neutral);
  py += 29;
  drawButton(px, py, bw, 24, "INITIALIZE EES", neutral);
  drawButton(px + bw + gap, py, bw, 24, "STEP ONCE", neutral);
  py += 29;
  boolean running = dcrteSchedulerController != null && dcrteSchedulerController.running;
  drawButton(px, py, bw, 24, running ? "PAUSE EES" : "RUN EES", running ? warn : neutral);
  drawButton(px + bw + gap, py, bw, 24, "COMPLETE EES", warn);
  py += 29;
  drawButton(px, py, bw, 24, meshCurrent ? "MESH CURRENT" : "MATERIALIZE",
    meshCurrent ? on : canMaterialize ? warn : off);
  drawButton(px + bw + gap, py, bw, 24,
    dcrteHbeActiveConnectivity == null ? "ANALYZE" : "ANALYSIS READY",
    dcrteHbeActiveConnectivity == null ? neutral : on);
  py += 29;
  String sweepLabel = dcrteHbeSweepRunning
    ? "SWEEP " + dcrteHbeSweepProgress() + " / " + dcrteHbeSweepCellTotal()
    : dcrteHbeSweepCurrent() ? "SWEEP COMPLETE " + dcrteHbeSweepCellTotal() + " / " + dcrteHbeSweepCellTotal()
    : "RUN 11 x 6 SWEEP";
  drawButton(px, py, w - 24, 24, sweepLabel,
    dcrteHbeSweepRunning ? warn : dcrteHbeSweepCurrent() ? on : color(85, 69, 36));
  py += 29;
  drawButton(px, py, w - 24, 24, "EXPORT HBE EVIDENCE", color(67, 83, 116));
  py += 33;

  drawDcrteHbeCycleRow(px, py, w - 24, "INFLUENCE", dcrteHbeConfig.influenceMode.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "FEEDBACK", dcrteHbeConfig.feedbackSource.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "DOMAIN", dcrteHbeConfig.domainResponseMode.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "MIRROR", dcrteHbeConfig.mirrorPolicy.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "LOBE PROXY", dcrteHbeConfig.lobeProxyMode.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "SEED", dcrteHbeConfig.seedMode.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "SCORE", dcrteHbeConfig.scorePreset.id()); py += 25;
  drawDcrteHbeCycleRow(px, py, w - 24, "VIEW", dcrteHbeVisualizationMode.label()); py += 25;
  drawDcrteHbeAdjustRow(px, py, w - 24, "COUPLING", dcrteHbeConfig.coupling); py += 27;
  drawDcrteHbeAdjustRow(px, py, w - 24, "MANUAL FB", dcrteHbeConfig.manualFeedback);

  int metricsY = y + controlH + 12;
  drawReadoutPanel(x, metricsY, w, h - controlH - 12, "BRIDGE OBSERVABLES");
  drawDcrteHbeMetrics(x + 12, metricsY + 32, w - 24, h - controlH - 50);
}

void drawDcrteHbeCycleRow(int x, int y, int w, String label, String value) {
  fill(87, 124, 132); textAlign(LEFT, CENTER); textSize(8); text(label, x, y + 11);
  int bx = x + 74;
  drawButton(bx, y, w - 74, 22, shortText(value == null ? "" : value.toUpperCase(), 31), color(38, 68, 78));
}

void drawDcrteHbeAdjustRow(int x, int y, int w, String label, float value) {
  fill(87, 124, 132); textAlign(LEFT, CENTER); textSize(8); text(label, x, y + 10);
  int bx = x + 74, available = w - 74, buttonW = 42;
  drawButton(bx, y, buttonW, 22, "-", color(38, 68, 78));
  fill(212, 235, 230); textAlign(CENTER, CENTER); textSize(9);
  text(nf(value, 1, 2), bx + available / 2, y + 11);
  drawButton(bx + available - buttonW, y, buttonW, 22, "+", color(38, 68, 78));
}

void drawDcrteHbeMetrics(int x, int y, int w, int h) {
  HBEConnectivityReport candidate = dcrteHbeSnapshot == null ? null
    : dcrteHbeSnapshot.candidateConnectivity;
  HBEConnectivityReport active = dcrteHbeActiveConnectivity;
  PropagationState state = dcrteSchedulerController == null ? null : dcrteSchedulerController.state;
  int line = 0;
  dcrteHbeMetricRow(x, y + line++ * 17, w, "state", dcrteHbeState.id());
  dcrteHbeMetricRow(x, y + line++ * 17, w, "next action", dcrteHbeNextActionLabel());
  dcrteHbeMetricRow(x, y + line++ * 17, w, "feedback capture",
    dcrteHbePreparedMetrics == null ? "not frozen" : dcrteHbeMetric(dcrteHbePreparedMetrics.feedback));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "snapshot", dcrteHbeSnapshot == null ? "not frozen" : "current");
  dcrteHbeMetricRow(x, y + line++ * 17, w, "candidate bridge", dcrteHbeConnectionLabel(candidate));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "active bridge", dcrteHbeConnectionLabel(active));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "active / candidate",
    (state == null ? "-" : state.activeCount) + " / "
      + (dcrteSchedulerController == null || dcrteSchedulerController.snapshot == null
        ? "-" : dcrteSchedulerController.snapshot.candidateCount));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "neck minimum",
    active == null ? "-" : str(active.minimumNeckCrossSection));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "bilateral balance",
    active == null ? "-" : dcrteHbeMetric(active.bilateralBalance));
  dcrteHbeMetricRow(x, y + line++ * 17, w, "field changed + / -",
    dcrteHbeFieldSensitivity.changedToCandidateCount + " / "
      + dcrteHbeFieldSensitivity.changedFromCandidateCount);
  String sweepStatus = dcrteHbeSweepRunning
    ? dcrteHbeSweepProgress() + " / " + dcrteHbeSweepCellTotal() + " running"
    : dcrteHbeSweepCurrent() ? dcrteHbeSweepConnectedCount() + " connected / "
      + dcrteHbeSweepFailureCount() + " failed" : "not run";
  dcrteHbeMetricRow(x, y + line++ * 17, w, "sweep", sweepStatus);
  int statusY = y + line * 17 + 5;
  if (statusY < y + h - 24) {
    fill(dcrteHbeState == HBEState.FAILED ? color(255, 88, 102) : color(155, 191, 194));
    textAlign(LEFT, TOP); textSize(8);
    text(dcrteHbeStatus, x, statusY, w, max(22, y + h - statusY));
  }
}

void dcrteHbeMetricRow(int x, int y, int w, String label, String value) {
  fill(100, 137, 144); textAlign(LEFT, TOP); textSize(8); text(label, x, y);
  fill(215, 236, 232); textAlign(RIGHT, TOP); textSize(8);
  text(shortText(value == null ? "" : value, 30), x + w, y);
}

String dcrteHbeConnectionLabel(HBEConnectivityReport report) {
  if (report == null || !report.validInput) return "not analyzed";
  return report.connected ? "PATH DETECTED" : "absent (valid)";
}

String dcrteHbeNextActionLabel() {
  if (!dcrteHbeEnabled) return "enable HBE";
  if (dcrteHbePreparedMetrics == null) return "capture feedback";
  if (dcrteHbeSnapshot == null) return "build snapshot / candidate";
  if (dcrteSchedulerController == null || dcrteSchedulerController.state == null) return "initialize EES";
  if (dcrteHbeActiveConnectivity == null) return "run or complete, then analyze";
  if (!dcrteSchedulerController.canExportCurrentMesh()) return "materialize current state";
  return "ready: call sheet / export";
}

boolean handleDcrteHbeMouse(int x, int y, int w, int h) {
  int bodyY = y + 94;
  int rightW = constrain(round(w * 0.32f), 360, 418);
  int gap = 18;
  int viewW = w - rightW - gap - 36;
  int rx = x + 18 + viewW + gap;
  int px = rx + 12, py = bodyY + 32, bw = (rightW - 30) / 2;
  if (over(px, py, bw, 24)) { dcrteHbeSetEnabled(!dcrteHbeEnabled); return true; }
  if (over(px + bw + 6, py, bw, 24)) { loadDcrteHbeDualLobeFixture(); return true; }
  py += 29;
  if (over(px, py, rightW - 24, 24)) { captureDcrteHbeFeedback(); return true; }
  py += 29;
  if (over(px, py, bw, 24)) { buildDcrteHbeSnapshot(); return true; }
  if (over(px + bw + 6, py, bw, 24)) { generateSelectedSurfaceFoundryMesh(); return true; }
  py += 29;
  if (over(px, py, bw, 24)) { dcrteSchedulerController.initializeCurrent(); return true; }
  if (over(px + bw + 6, py, bw, 24)) { dcrteSchedulerController.stepOnce(); return true; }
  py += 29;
  if (over(px, py, bw, 24)) {
    if (dcrteSchedulerController.running) dcrteSchedulerController.pause();
    else dcrteSchedulerController.run();
    return true;
  }
  if (over(px + bw + 6, py, bw, 24)) { dcrteSchedulerController.complete(); return true; }
  py += 29;
  if (over(px, py, bw, 24)) { dcrteSchedulerController.materializeCurrent(); return true; }
  if (over(px + bw + 6, py, bw, 24)) { runDcrteHbeAnalysis(); return true; }
  py += 29;
  if (over(px, py, rightW - 24, 24)) { runDcrteHbeFastSweep(); return true; }
  py += 29;
  if (over(px, py, rightW - 24, 24)) { exportDcrteHbeReport(); return true; }
  py += 33;

  int valueX = px + 74, valueW = rightW - 24 - 74;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeInfluence(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeFeedback(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeDomainResponse(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeMirror(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeLobeProxy(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeSeed(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeScore(); return true; } py += 25;
  if (over(valueX, py, valueW, 22)) { cycleDcrteHbeVisualization(1); return true; } py += 25;
  if (handleDcrteHbeAdjust(valueX, py, valueW, true)) return true; py += 27;
  if (handleDcrteHbeAdjust(valueX, py, valueW, false)) return true;
  return false;
}

boolean handleDcrteHbeAdjust(int x, int y, int w, boolean coupling) {
  int buttonW = 42; float delta = 0;
  if (over(x, y, buttonW, 22)) delta = -0.05f;
  else if (over(x + w - buttonW, y, buttonW, 22)) delta = 0.05f;
  if (delta == 0) return false;
  if (coupling) dcrteHbeConfig.coupling = constrain(dcrteHbeConfig.coupling + delta, 0, 1);
  else dcrteHbeConfig.manualFeedback = constrain(dcrteHbeConfig.manualFeedback + delta, 0, 1);
  dcrteHbeConfigurationChanged(coupling ? "coupling changed" : "manual feedback changed");
  return true;
}

void dcrteHbeConfigurationChanged(String reason) {
  if (dcrteHbeEnabled) invalidateDcrteHbe(reason);
  else dcrteHbeStatus = "HBE disabled; configuration staged for the next experiment";
}

void cycleDcrteHbeInfluence() {
  HBEInfluenceMode[] v = HBEInfluenceMode.values();
  dcrteHbeConfig.influenceMode = v[(dcrteHbeConfig.influenceMode.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("influence mode changed");
}
void cycleDcrteHbeFeedback() {
  HBEFeedbackSource[] v = HBEFeedbackSource.values();
  dcrteHbeConfig.feedbackSource = v[(dcrteHbeConfig.feedbackSource.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("feedback source changed");
}
void cycleDcrteHbeDomainResponse() {
  HBEDomainResponseMode[] v = HBEDomainResponseMode.values();
  dcrteHbeConfig.domainResponseMode = v[(dcrteHbeConfig.domainResponseMode.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("domain response changed");
}
void cycleDcrteHbeMirror() {
  HBEMirrorPolicy[] v = HBEMirrorPolicy.values();
  dcrteHbeConfig.mirrorPolicy = v[(dcrteHbeConfig.mirrorPolicy.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("mirror policy changed");
}
void cycleDcrteHbeLobeProxy() {
  HBELobeProxyMode[] v = HBELobeProxyMode.values();
  dcrteHbeConfig.lobeProxyMode = v[(dcrteHbeConfig.lobeProxyMode.ordinal() + 1) % v.length];
  dcrteHbeConfig.lobeProxyBlend = dcrteHbeConfig.lobeProxyMode == HBELobeProxyMode.OFF
    ? 0 : max(0.35f, dcrteHbeConfig.lobeProxyBlend);
  dcrteHbeConfigurationChanged("lobe proxy changed");
}
void cycleDcrteHbeSeed() {
  HBESeedMode[] v = HBESeedMode.values();
  dcrteHbeConfig.seedMode = v[(dcrteHbeConfig.seedMode.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("seed mode changed");
}
void cycleDcrteHbeScore() {
  HBEScorePreset[] v = HBEScorePreset.values();
  dcrteHbeConfig.scorePreset = v[(dcrteHbeConfig.scorePreset.ordinal() + 1) % v.length];
  dcrteHbeConfigurationChanged("score preset changed");
}
