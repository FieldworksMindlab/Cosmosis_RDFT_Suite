/* DCRTE-ET Milestone 4 scheduler operator panel. */

boolean dcrteSchedulerPanelOpen = false;
boolean dcrteSchedulerShowFrontier = true;
boolean dcrteSchedulerShowArrival = true;
boolean dcrteEntropicAdvancedControls = false;
EntropyVisualizationMode dcrteEntropyVisualizationMode =
  EntropyVisualizationMode.OCCUPANCY_ENTROPY;
int dcrteEntropicInspectionIndex = 0;

void drawDcrteSchedulerPanel(int x, int y, int w, int h) {
  SchedulerController c = dcrteSchedulerController;
  color accent = c.state == null ? color(112, 155, 166)
    : c.state.runState == SchedulerRunState.FAILED || c.state.runState == SchedulerRunState.INVALIDATED ? color(255, 92, 112)
    : c.state.runState == SchedulerRunState.COMPLETE ? color(90, 232, 174)
    : color(255, 204, 76);
  fill(2, 8, 12, 248);
  stroke(accent);
  strokeWeight(1.2);
  rect(x, y, w, h, 6);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(10);
  boolean entropicMode = c.configuration.mode == SchedulerMode.EMERGENT_ENTROPIC;
  text(entropicMode ? "DCRTE-ET M5 EMERGENT ENTROPIC SCHEDULER"
    : "DCRTE-ET M4 DETERMINISTIC SCHEDULER", x + 14, y + 12);

  int gap = 6;
  int topY = y + 32;
  int topW = max(64, (w - 28 - gap * 5) / 6);
  drawButton(x + 14, topY, topW, 22, "CLOSE", color(72, 54, 62));
  drawButton(x + 14 + (topW + gap), topY, topW, 22, "INITIALIZE", color(48, 76, 82));
  drawButton(x + 14 + (topW + gap) * 2, topY, topW, 22, "STEP", color(48, 76, 82));
  drawButton(x + 14 + (topW + gap) * 3, topY, topW, 22, c.running ? "PAUSE" : "RUN", c.running ? color(88, 68, 38) : color(45, 86, 72));
  drawButton(x + 14 + (topW + gap) * 4, topY, topW, 22, "COMPLETE", color(45, 86, 72));
  drawButton(x + 14 + (topW + gap) * 5, topY, topW, 22, "STOP", color(76, 52, 58));

  int configX = x + 14;
  int configY = y + 68;
  int configW = min(316, max(250, w / 3));
  int rowH = 31;
  drawDcrteSchedulerOption(configX, configY, configW, "MODE", c.configuration.mode.label());
  if (entropicMode) drawDcrteEntropicConfiguration(configX, configY, configW, rowH, c);
  else {
    drawDcrteSchedulerOption(configX, configY + rowH, configW, "SEED", c.configuration.seedMode.label());
    drawDcrteSchedulerOption(configX, configY + rowH * 2, configW, "COMPONENTS", c.configuration.componentPolicy.label());
    drawDcrteSchedulerOption(configX, configY + rowH * 3, configW, "NEIGHBORS", c.configuration.neighborhoodMode.label());
    drawDcrteSchedulerOption(configX, configY + rowH * 4, configW, "PRIORITY", c.configuration.priorityMode.label());
    drawDcrteSchedulerNumber(configX, configY + rowH * 5, configW, "BATCH SIZE", c.configuration.maxUpdatesPerBatch);
    drawDcrteSchedulerNumber(configX, configY + rowH * 6, configW, "BATCHES / FRAME", c.batchesPerRenderFrame);
  }

  int actionY = configY + rowH * 7 + 5;
  int actionGap = 5;
  int actionW = (configW - actionGap) / 2;
  drawButton(configX, actionY, actionW, 22, "RESET", color(48, 70, 78));
  drawButton(configX + actionW + actionGap, actionY, actionW, 22, "ARCHIVE RUN", color(50, 72, 80));
  drawButton(configX, actionY + 27, actionW, 22, "MATERIALIZE", color(48, 82, 68));
  drawButton(configX + actionW + actionGap, actionY + 27, actionW, 22, "MAT COMPLETE", color(48, 82, 68));
  if (entropicMode) {
    drawButton(configX, actionY + 54, actionW, 22,
      dcrteEntropicAdvancedControls ? "BASIC CONTROLS" : "ADVANCED CONTROLS",
      dcrteEntropicAdvancedControls ? color(88, 74, 38) : color(48, 66, 74));
    drawButton(configX + actionW + actionGap, actionY + 54, actionW, 22,
      shortText(dcrteEntropyVisualizationMode.label(), 18), color(55, 80, 88));
    drawDcrteSchedulerNumber(configX, actionY + 81, configW,
      "INSPECT CANDIDATE", dcrteEntropicInspectionIndex);
  } else {
    drawButton(configX, actionY + 54, actionW, 22, dcrteSchedulerShowFrontier ? "FRONTIER ON" : "FRONTIER OFF", dcrteSchedulerShowFrontier ? color(88, 74, 38) : color(48, 58, 64));
    drawButton(configX + actionW + actionGap, actionY + 54, actionW, 22, dcrteSchedulerShowArrival ? "ARRIVAL ON" : "ARRIVAL OFF", dcrteSchedulerShowArrival ? color(55, 80, 88) : color(48, 58, 64));
    drawDcrteSchedulerNumber(configX, actionY + 81, configW, "ARRIVAL BATCH", c.selectedArrivalBatch);
  }

  int readX = configX + configW + 16;
  int readW = w - (readX - x) - 14;
  int readY = configY;
  int readH = min(232, max(174, h / 3));
  fill(4, 12, 17, 238);
  stroke(36, 74, 82);
  rect(readX, readY, readW, readH, 4);
  if (entropicMode) drawDcrteEntropicReadout(readX + 12, readY + 11,
    readW - 24, c);
  else drawDcrteSchedulerReadout(readX + 12, readY + 11, readW - 24, c);

  int sliceY = max(actionY + 118, readY + readH + 12);
  int sliceH = h - (sliceY - y) - 14;
  int sliceGap = 8;
  int sliceW = (w - 28 - sliceGap * 2) / 3;
  String sliceSuffix = entropicMode
    ? " / " + shortText(dcrteEntropyVisualizationMode.label(), 18) : "";
  drawDcrteSchedulerSlice(x + 14, sliceY, sliceW, sliceH, 0, "XY / Z MID" + sliceSuffix);
  drawDcrteSchedulerSlice(x + 14 + sliceW + sliceGap, sliceY, sliceW, sliceH, 1, "XZ / Y MID" + sliceSuffix);
  drawDcrteSchedulerSlice(x + 14 + (sliceW + sliceGap) * 2, sliceY, sliceW, sliceH, 2, "YZ / X MID" + sliceSuffix);
}

void drawDcrteEntropicConfiguration(int x, int y, int w, int rowH,
    SchedulerController c) {
  EntropyConfiguration entropy = c.configuration.entropy;
  if (!dcrteEntropicAdvancedControls) {
    drawDcrteSchedulerOption(x, y + rowH, w, "ENTROPY NEIGHBORHOOD",
      entropy.neighborhoodMode.label());
    drawDcrteSchedulerOption(x, y + rowH * 2, w, "POLICY",
      entropy.policyMode.label());
    drawDcrteSchedulerOption(x, y + rowH * 3, w, "ACCEPTANCE",
      entropy.acceptanceMode.label());
    drawDcrteSchedulerNumber(x, y + rowH * 4, w, "ENTROPIC BATCH CAP",
      entropy.maxUpdatesPerBatch);
    drawDcrteSchedulerFloat(x, y + rowH * 5, w, "SCORE THRESHOLD",
      entropy.scoreThreshold, 3);
    drawDcrteSchedulerFloat(x, y + rowH * 6, w, "TEMPERATURE",
      entropy.acceptanceTemperature, 3);
  } else {
    drawDcrteSchedulerOption(x, y + rowH, w, "SEED",
      c.configuration.seedMode.label());
    drawDcrteSchedulerOption(x, y + rowH * 2, w, "COMPONENTS",
      c.configuration.componentPolicy.label());
    drawDcrteSchedulerOption(x, y + rowH * 3, w, "PROPAGATION NEIGHBORS",
      c.configuration.neighborhoodMode.label());
    drawDcrteSchedulerNumber(x, y + rowH * 4, w, "MINIMUM SUPPORT",
      entropy.minimumSupport);
    drawDcrteSchedulerNumber(x, y + rowH * 5, w, "FIELD HISTOGRAM BINS",
      entropy.fieldHistogramBins);
    drawDcrteSchedulerNumber(x, y + rowH * 6, w, "STABILITY WINDOW",
      entropy.stability.observationWindow);
  }
}

void drawDcrteSchedulerOption(int x, int y, int w, String label, String value) {
  fill(118, 158, 168);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  drawButton(x, y + 10, w, 19, "<  " + shortText(value, 28) + "  >", color(43, 66, 74));
}

void drawDcrteSchedulerNumber(int x, int y, int w, String label, int value) {
  fill(118, 158, 168);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  textAlign(RIGHT, TOP);
  text(str(value), x + w, y);
  int half = (w - 5) / 2;
  drawButton(x, y + 10, half, 19, "-", color(43, 66, 74));
  drawButton(x + half + 5, y + 10, half, 19, "+", color(43, 66, 74));
}

void drawDcrteSchedulerFloat(int x, int y, int w, String label,
    float value, int decimals) {
  fill(118, 158, 168);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  textAlign(RIGHT, TOP);
  text(nf(value, 1, decimals), x + w, y);
  int half = (w - 5) / 2;
  drawButton(x, y + 10, half, 19, "-", color(43, 66, 74));
  drawButton(x + half + 5, y + 10, half, 19, "+", color(43, 66, 74));
}

void drawDcrteSchedulerReadout(int x, int y, int w, SchedulerController c) {
  SchedulerDiagnostics d = c.diagnostics;
  CandidateVolumeSnapshot s = c.snapshot;
  PropagationState state = c.state;
  fill(158, 192, 198);
  textAlign(LEFT, TOP);
  textSize(8);
  int line = 13;
  text("state        " + (state == null ? "not initialized" : state.runState.id()), x, y);
  text("stop         " + (state == null ? "none" : state.stopReason.id()), x, y + line);
  text("snapshot     " + (s == null ? "none" : shortText(s.snapshotId, 26)), x, y + line * 2);
  text("candidates   " + d.candidateCount + "   active " + d.activeCount, x, y + line * 3);
  text("frontier     " + d.frontierCount + "   unreachable " + d.unreachableCount, x, y + line * 4);
  text("batch        " + d.batchIndex + "   progress " + nf(d.activationProgress * 100, 1, 2) + "%", x, y + line * 5);
  int newlyActive = c.history.size() == 0 ? 0 : c.history.get(c.history.size() - 1).newlyActivated;
  text("new active   " + newlyActive + "   seeds " + d.seedCount, x, y + line * 6);
  text("components   " + d.activeComponentCount + " / " + d.candidateComponentCount, x, y + line * 7);
  text("attempted    " + d.attemptedUpdates + "   accepted " + d.acceptedUpdates, x, y + line * 8);
  text("scheduler ms " + d.schedulerComputeMillis + "   materialize " + d.materializationMillis, x, y + line * 9);
  text("state hash   " + shortText(d.stateHash, 34), x, y + line * 10);
  text("mesh         " + (c.canExportCurrentMesh() ? "current / exportable" : "not current"), x, y + line * 11);
  text("M3 baseline  " + (s == null ? 0 : s.candidateCount) + " static candidates", x, y + line * 12);
  text("M4 compare   " + max(0, c.pendingCandidateCount()) + " pending / "
    + max(0, c.illegalActivationCount()) + " illegal", x, y + line * 13);
  text("archive      " + (c.lastExportDirectory.length() == 0 ? "not archived"
    : shortText(c.lastExportDirectory, 44)), x, y + line * 14);
  if (d.issues.size() > 0) {
    SchedulerDiagnostic issue = d.issues.get(d.issues.size() - 1);
    fill(issue.severity == SchedulerDiagnosticSeverity.ERROR ? color(255, 100, 118) : color(255, 205, 86));
    text(issue.code + "  " + shortText(issue.message, max(20, w / 7)), x, y + line * 15);
  }
}

void drawDcrteEntropicReadout(int x, int y, int w, SchedulerController c) {
  SchedulerDiagnostics d = c.diagnostics;
  CandidateVolumeSnapshot snapshot = c.snapshot;
  PropagationState state = c.state;
  EmergentEntropicScheduler scheduler = c.entropicScheduler();
  fill(158, 192, 198);
  textAlign(LEFT, TOP);
  textSize(8);
  int line = 13;
  text("state        " + (state == null ? "not initialized" : state.runState.id())
    + " / " + (scheduler == null ? "none" : scheduler.terminalState.id()), x, y);
  text("stop         " + (state == null ? "none" : state.stopReason.id()), x, y + line);
  text("snapshot     " + (snapshot == null ? "none"
    : shortText(snapshot.snapshotId, 24)), x, y + line * 2);
  text("candidates   " + d.candidateCount + "   active " + d.activeCount
    + "   frontier " + d.frontierCount, x, y + line * 3);
  EntropyConfiguration entropy = c.configuration.entropy;
  text("models       binary occupancy / field histogram " + entropy.fieldHistogramBins,
    x, y + line * 4);
  text("policy       " + entropy.policyMode.id() + " / "
    + entropy.acceptanceMode.id(), x, y + line * 5);
  text("threshold    " + nf(entropy.scoreThreshold, 1, 3)
    + "   temperature " + nf(entropy.acceptanceTemperature, 1, 3), x, y + line * 6);
  text("entropy H    " + (scheduler == null ? "0.000"
    : nf(scheduler.entropySummary.meanLocalEntropy, 1, 4))
    + "   field H " + (scheduler == null ? "0.000"
      : nf(scheduler.fieldSummary.meanLocalEntropy, 1, 4)), x, y + line * 7);
  text("score        mean " + (scheduler == null ? "0.000"
    : nf(scheduler.latestEvaluation.meanScore, 1, 4))
    + "   max " + (scheduler == null ? "0.000"
      : nf(scheduler.latestEvaluation.maximumScore, 1, 4)), x, y + line * 8);
  text("accepted     " + (scheduler == null ? 0
    : scheduler.latestEvaluation.acceptedCount) + "   eligible "
    + (scheduler == null ? 0 : scheduler.latestEvaluation.thresholdEligibleCount),
    x, y + line * 9);
  text("tau          " + (scheduler == null ? "0"
    : nf((float)scheduler.progress.tauRaw, 1, 6))
    + "   dimensionless progress", x, y + line * 10);
  text("stability    " + (scheduler == null || scheduler.stability == null
    ? "not evaluated" : scheduler.stability.state.consecutiveStableWindows + " windows / "
      + scheduler.stability.state.lastFailureCriterion), x, y + line * 11);
  text("cache        " + (scheduler == null || scheduler.entropyCache == null
    ? "not built" : shortText(scheduler.entropyCache.cacheHash, 18))
    + "   verify " + (scheduler == null ? "n/a"
      : scheduler.lastCacheVerification.pass ? "pass" : "pending/fail"), x, y + line * 12);
  EntropicScoreRecord inspected = scheduler == null ? null
    : scheduler.latestRecordAt(dcrteEntropicInspectionIndex);
  text("inspect      " + dcrteEntropicInspectionIndex + (inspected == null
    ? " / no current frontier score"
    : " / score " + nf(inspected.terms.combinedScore, 1, 4)
      + " dH " + nf(inspected.occupancyDelta.deltaEntropy, 1, 4)), x, y + line * 13);
  text("mesh         " + (c.canExportCurrentMesh()
    ? "current / exportable" : "not current") + "   illegal "
    + max(0, c.illegalActivationCount()), x, y + line * 14);
  text("archive      " + (c.lastExportDirectory.length() == 0 ? "not archived"
    : shortText(c.lastExportDirectory, 44)), x, y + line * 15);
  if (scheduler != null && w >= 620)
    drawDcrteEntropicHistoryPlot(x + w - 282, y + 5, 276, 184,
      scheduler);
  if (d.issues.size() > 0) {
    SchedulerDiagnostic issue = d.issues.get(d.issues.size() - 1);
    fill(issue.severity == SchedulerDiagnosticSeverity.ERROR
      ? color(255, 100, 118) : color(255, 205, 86));
    text(issue.code + "  " + shortText(issue.message, max(20, w / 7)),
      x, y + line * 16);
  }
}

void drawDcrteEntropicHistoryPlot(int x, int y, int w, int h,
    EmergentEntropicScheduler scheduler) {
  fill(2, 9, 13, 245);
  stroke(38, 72, 80);
  strokeWeight(1);
  rect(x, y, w, h, 3);
  fill(122, 166, 176);
  textAlign(LEFT, TOP);
  textSize(8);
  text("RELATIONAL PROGRESS / ENTROPY HISTORY", x + 7, y + 6);
  int plotX = x + 8;
  int plotY = y + 22;
  int plotW = w - 16;
  int plotH = h - 31;
  stroke(28, 51, 58);
  line(plotX, plotY + plotH, plotX + plotW, plotY + plotH);
  line(plotX, plotY, plotX, plotY + plotH);
  if (scheduler.entropicHistory == null
      || scheduler.entropicHistory.size() < 2) {
    fill(88, 120, 128);
    text("run two or more scheduler batches", plotX + 7, plotY + 8);
    return;
  }
  int count = scheduler.entropicHistory.size();
  double maximumTau = 0;
  for (int i = 0; i < count; i++)
    maximumTau = Math.max(maximumTau,
      scheduler.entropicHistory.get(i).tauRaw);
  maximumTau = Math.max(0.000000001, maximumTau);
  noFill();
  stroke(255, 207, 72);
  strokeWeight(1.35f);
  beginShape();
  for (int i = 0; i < count; i++) {
    EntropicSchedulerHistoryEntry entry =
      scheduler.entropicHistory.get(i);
    float px = plotX + i * plotW / (float)max(1, count - 1);
    float py = plotY + plotH
      - constrain((float)(entry.tauRaw / maximumTau), 0, 1) * plotH;
    vertex(px, py);
  }
  endShape();
  stroke(46, 222, 199);
  strokeWeight(1);
  beginShape();
  for (int i = 0; i < count; i++) {
    EntropicSchedulerHistoryEntry entry =
      scheduler.entropicHistory.get(i);
    float px = plotX + i * plotW / (float)max(1, count - 1);
    float py = plotY + plotH
      - constrain(entry.meanOccupancyEntropy, 0, 1) * plotH;
    vertex(px, py);
  }
  endShape();
  fill(255, 207, 72);
  text("tau", plotX + 5, plotY + 4);
  fill(46, 222, 199);
  text("H", plotX + 30, plotY + 4);
}

void drawDcrteSchedulerSlice(int x, int y, int w, int h, int plane, String label) {
  CandidateVolumeSnapshot s = dcrteSchedulerController.snapshot;
  PropagationState state = dcrteSchedulerController.state;
  fill(3, 9, 13);
  stroke(34, 67, 74);
  rect(x, y, w, h, 3);
  fill(124, 166, 176);
  textAlign(LEFT, TOP);
  textSize(8);
  text(label, x + 7, y + 6);
  if (s == null || state == null || s.spec == null) {
    text("generate a candidate volume", x + 7, y + 22);
    return;
  }
  int uCount = plane == 2 ? s.spec.ny : s.spec.nx;
  int vCount = plane == 0 ? s.spec.ny : s.spec.nz;
  int drawX = x + 7;
  int drawY = y + 20;
  int drawW = w - 14;
  int drawH = h - 27;
  int step = max(1, max((int)ceil(uCount / (float)max(1, drawW)), (int)ceil(vCount / (float)max(1, drawH))));
  float cellW = drawW / (float)uCount * step;
  float cellH = drawH / (float)vCount * step;
  EmergentEntropicScheduler entropic = dcrteSchedulerController.entropicScheduler();
  boolean entropicMode = dcrteSchedulerController.configuration.mode
    == SchedulerMode.EMERGENT_ENTROPIC && entropic != null;
  noStroke();
  for (int v = 0; v < vCount; v += step) for (int u = 0; u < uCount; u += step) {
    int ix = plane == 2 ? s.spec.nx / 2 : u;
    int iy = plane == 0 ? v : plane == 1 ? s.spec.ny / 2 : u;
    int iz = plane == 0 ? s.spec.nz / 2 : v;
    int index = ix + s.spec.nx * (iy + s.spec.ny * iz);
    color cell = color(7, 14, 18);
    if (s.admitted[index]) cell = color(17, 31, 38);
    if (s.candidateSolid[index]) cell = color(35, 70, 78);
    if (entropicMode && s.candidateSolid[index]) {
      float value = dcrteEntropicVisualizationValue(entropic, state, index,
        dcrteEntropyVisualizationMode);
      cell = dcrteEntropicVisualizationColor(value, dcrteEntropyVisualizationMode);
      if (index == dcrteEntropicInspectionIndex) cell = color(246, 250, 252);
    } else {
      boolean shownActive = dcrteSchedulerShowArrival
        ? state.activeAtBatch(index, dcrteSchedulerController.selectedArrivalBatch)
        : state.active[index];
      if (shownActive) {
        int arrival = max(0, state.arrivalBatch[index]);
        float t = state.batchIndex <= 0 ? 0 : constrain(arrival / (float)state.batchIndex, 0, 1);
        cell = t < 0.5 ? lerpColor(color(0, 210, 190), color(255, 220, 72), t * 2)
          : lerpColor(color(255, 220, 72), color(255, 80, 174), (t - 0.5) * 2);
      }
      if (dcrteSchedulerShowFrontier && state.frontier[index]) cell = color(255, 244, 106);
      if (state.arrivalBatch[index] == 0) cell = color(242, 252, 255);
    }
    fill(cell);
    rect(drawX + u * drawW / (float)uCount, drawY + v * drawH / (float)vCount, cellW + 0.5, cellH + 0.5);
  }
}

boolean handleDcrteSchedulerPanelMouse(int x, int y, int w, int h) {
  if (!dcrteSchedulerPanelOpen) return false;
  SchedulerController c = dcrteSchedulerController;
  int gap = 6;
  int topY = y + 32;
  int topW = max(64, (w - 28 - gap * 5) / 6);
  int firstX = x + 14;
  if (over(firstX, topY, topW, 22)) { dcrteSchedulerPanelOpen = false; return true; }
  if (over(firstX + (topW + gap), topY, topW, 22)) { c.initializeCurrent(); return true; }
  if (over(firstX + (topW + gap) * 2, topY, topW, 22)) { c.stepOnce(); return true; }
  if (over(firstX + (topW + gap) * 3, topY, topW, 22)) { if (c.running) c.pause(); else c.run(); return true; }
  if (over(firstX + (topW + gap) * 4, topY, topW, 22)) { c.complete(); return true; }
  if (over(firstX + (topW + gap) * 5, topY, topW, 22)) { c.stop(); return true; }

  int configX = x + 14;
  int configY = y + 68;
  int configW = min(316, max(250, w / 3));
  int rowH = 31;
  if (over(configX, configY + 10, configW, 19)) { c.configuration.mode = SchedulerMode.values()[(c.configuration.mode.ordinal() + 1) % SchedulerMode.values().length]; dcrteSchedulerConfigurationChanged(); return true; }
  boolean entropicMode = c.configuration.mode == SchedulerMode.EMERGENT_ENTROPIC;
  if (entropicMode) {
    if (handleDcrteEntropicConfigurationMouse(configX, configY, configW,
        rowH, c)) return true;
  } else {
    if (over(configX, configY + rowH + 10, configW, 19)) { c.configuration.seedMode = SchedulerSeedMode.values()[(c.configuration.seedMode.ordinal() + 1) % SchedulerSeedMode.values().length]; dcrteSchedulerConfigurationChanged(); return true; }
    if (over(configX, configY + rowH * 2 + 10, configW, 19)) { c.configuration.componentPolicy = SchedulerComponentPolicy.values()[(c.configuration.componentPolicy.ordinal() + 1) % SchedulerComponentPolicy.values().length]; dcrteSchedulerConfigurationChanged(); return true; }
    if (over(configX, configY + rowH * 3 + 10, configW, 19)) { c.configuration.neighborhoodMode = SchedulerNeighborhoodMode.values()[(c.configuration.neighborhoodMode.ordinal() + 1) % SchedulerNeighborhoodMode.values().length]; dcrteSchedulerConfigurationChanged(); return true; }
    if (over(configX, configY + rowH * 4 + 10, configW, 19)) { c.configuration.priorityMode = SchedulerPriorityMode.values()[(c.configuration.priorityMode.ordinal() + 1) % SchedulerPriorityMode.values().length]; dcrteSchedulerConfigurationChanged(); return true; }
    if (dcrteHandleSchedulerNumber(configX, configY + rowH * 5, configW, -256, 256, 1)) { c.configuration.maxUpdatesPerBatch = constrain(c.configuration.maxUpdatesPerBatch + dcrteSchedulerNumberDelta(configX, configY + rowH * 5, configW, 256), 1, 65536); dcrteSchedulerConfigurationChanged(); return true; }
    if (dcrteHandleSchedulerNumber(configX, configY + rowH * 6, configW, -1, 1, 1)) { c.batchesPerRenderFrame = constrain(c.batchesPerRenderFrame + dcrteSchedulerNumberDelta(configX, configY + rowH * 6, configW, 1), 1, 128); return true; }
  }

  int actionY = configY + rowH * 7 + 5;
  int actionGap = 5;
  int actionW = (configW - actionGap) / 2;
  if (over(configX, actionY, actionW, 22)) { c.reset(); return true; }
  if (over(configX + actionW + actionGap, actionY, actionW, 22)) { c.exportMetrics(); return true; }
  if (over(configX, actionY + 27, actionW, 22)) { c.materializeCurrent(); return true; }
  if (over(configX + actionW + actionGap, actionY + 27, actionW, 22)) { c.materializeComplete(); return true; }
  if (entropicMode) {
    if (over(configX, actionY + 54, actionW, 22)) {
      dcrteEntropicAdvancedControls = !dcrteEntropicAdvancedControls;
      return true;
    }
    if (over(configX + actionW + actionGap, actionY + 54, actionW, 22)) {
      dcrteEntropyVisualizationMode = EntropyVisualizationMode.values()[
        (dcrteEntropyVisualizationMode.ordinal() + 1)
        % EntropyVisualizationMode.values().length];
      return true;
    }
    int delta = dcrteSchedulerNumberDelta(configX, actionY + 81, configW, 1);
    if (delta != 0) {
      int maximum = c.snapshot == null || c.snapshot.spec == null
        ? 0 : c.snapshot.spec.voxelCount() - 1;
      dcrteEntropicInspectionIndex = constrain(
        dcrteEntropicInspectionIndex + delta, 0, max(0, maximum));
      return true;
    }
  } else {
    if (over(configX, actionY + 54, actionW, 22)) { dcrteSchedulerShowFrontier = !dcrteSchedulerShowFrontier; return true; }
    if (over(configX + actionW + actionGap, actionY + 54, actionW, 22)) { dcrteSchedulerShowArrival = !dcrteSchedulerShowArrival; return true; }
    int delta = dcrteSchedulerNumberDelta(configX, actionY + 81, configW, 1);
    if (delta != 0) { c.selectedArrivalBatch = constrain(c.selectedArrivalBatch + delta, 0, c.state == null ? 0 : c.state.batchIndex); return true; }
  }
  return true;
}

boolean handleDcrteEntropicConfigurationMouse(int x, int y, int w, int rowH,
    SchedulerController c) {
  EntropyConfiguration entropy = c.configuration.entropy;
  if (!dcrteEntropicAdvancedControls) {
    if (over(x, y + rowH + 10, w, 19)) {
      entropy.neighborhoodMode = EntropyNeighborhoodMode.values()[
        (entropy.neighborhoodMode.ordinal() + 1)
        % EntropyNeighborhoodMode.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    if (over(x, y + rowH * 2 + 10, w, 19)) {
      entropy.policyMode = EntropicPolicyMode.values()[
        (entropy.policyMode.ordinal() + 1) % EntropicPolicyMode.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    if (over(x, y + rowH * 3 + 10, w, 19)) {
      entropy.acceptanceMode = AcceptanceMode.values()[
        (entropy.acceptanceMode.ordinal() + 1) % AcceptanceMode.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int batchDelta = dcrteSchedulerNumberDelta(x, y + rowH * 4, w, 64);
    if (batchDelta != 0) {
      entropy.maxUpdatesPerBatch = constrain(entropy.maxUpdatesPerBatch
        + batchDelta, 1, 65536);
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int thresholdDelta = dcrteSchedulerNumberDelta(x, y + rowH * 5, w, 1);
    if (thresholdDelta != 0) {
      entropy.scoreThreshold = constrain(entropy.scoreThreshold
        + thresholdDelta * 0.025f, 0, 1);
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int temperatureDelta = dcrteSchedulerNumberDelta(x, y + rowH * 6, w, 1);
    if (temperatureDelta != 0) {
      entropy.acceptanceTemperature = constrain(entropy.acceptanceTemperature
        + temperatureDelta * 0.01f, 0.01f, 1);
      dcrteSchedulerConfigurationChanged(); return true;
    }
  } else {
    if (over(x, y + rowH + 10, w, 19)) {
      c.configuration.seedMode = SchedulerSeedMode.values()[
        (c.configuration.seedMode.ordinal() + 1)
        % SchedulerSeedMode.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    if (over(x, y + rowH * 2 + 10, w, 19)) {
      c.configuration.componentPolicy = SchedulerComponentPolicy.values()[
        (c.configuration.componentPolicy.ordinal() + 1)
        % SchedulerComponentPolicy.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    if (over(x, y + rowH * 3 + 10, w, 19)) {
      c.configuration.neighborhoodMode = SchedulerNeighborhoodMode.values()[
        (c.configuration.neighborhoodMode.ordinal() + 1)
        % SchedulerNeighborhoodMode.values().length];
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int supportDelta = dcrteSchedulerNumberDelta(x, y + rowH * 4, w, 1);
    if (supportDelta != 0) {
      entropy.minimumSupport = constrain(entropy.minimumSupport + supportDelta,
        1, 125);
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int histogramDelta = dcrteSchedulerNumberDelta(x, y + rowH * 5, w, 1);
    if (histogramDelta != 0) {
      entropy.fieldHistogramBins = constrain(entropy.fieldHistogramBins
        + histogramDelta, 2, 64);
      dcrteSchedulerConfigurationChanged(); return true;
    }
    int windowDelta = dcrteSchedulerNumberDelta(x, y + rowH * 6, w, 1);
    if (windowDelta != 0) {
      entropy.stability.observationWindow = constrain(
        entropy.stability.observationWindow + windowDelta, 1, 256);
      dcrteSchedulerConfigurationChanged(); return true;
    }
  }
  return false;
}

boolean dcrteHandleSchedulerNumber(int x, int y, int w, int lowDelta, int highDelta, int step) {
  return dcrteSchedulerNumberDelta(x, y, w, step) != 0;
}

int dcrteSchedulerNumberDelta(int x, int y, int w, int step) {
  int half = (w - 5) / 2;
  if (over(x, y + 10, half, 19)) return -step;
  if (over(x + half + 5, y + 10, half, 19)) return step;
  return 0;
}

void dcrteSchedulerConfigurationChanged() {
  dcrteSchedulerController.invalidate("scheduler configuration changed; initialize schedule");
  foundryStatus = "scheduler configuration changed; initialize schedule";
}
