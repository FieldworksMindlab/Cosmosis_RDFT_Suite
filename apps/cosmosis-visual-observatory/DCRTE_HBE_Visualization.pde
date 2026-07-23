/* M6-HX deterministic visual diagnostics. All paths are classical voxel-graph proxies. */

enum HBEVisualizationMode {
  DUAL_LOBE_PROXY, NECK_PROXIMITY, SIDE_COORDINATE_XI, MIRROR_PARTNERS,
  MIRROR_CONFIDENCE, HBE_FIELD_DELTA, HBE_CANDIDATE_CHANGES, HBE_SCORE,
  CONNECTION_GAIN, CROSS_LOBE_REACHABILITY, LEFT_RIGHT_ACTIVE,
  CONNECTION_PATH, GRAPH_PAIRING_PROXY, NECK_CROSS_SECTION,
  ARRIVAL_DIFFERENCE, SWEEP_HEATMAP;
  String label() { return name().replace('_', ' '); }
}

HBEVisualizationMode dcrteHbeVisualizationMode = HBEVisualizationMode.DUAL_LOBE_PROXY;

void cycleDcrteHbeVisualization(int direction) {
  HBEVisualizationMode[] values = HBEVisualizationMode.values();
  int next = (dcrteHbeVisualizationMode.ordinal() + direction + values.length) % values.length;
  dcrteHbeVisualizationMode = values[next];
}

void drawDcrteHbeVisualization(int x, int y, int w, int h) {
  fill(3, 10, 15); stroke(30, 70, 78); rect(x, y, w, h, 4);
  fill(92, 214, 202); textAlign(LEFT, TOP); textSize(10);
  text(dcrteHbeVisualizationMode.label(), x + 12, y + 10);
  fill(120, 150, 158); textSize(8);
  text("deterministic voxel and graph diagnostics", x + 12, y + 25);
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.SWEEP_HEATMAP) {
    drawDcrteHbeSweepHeatmap(x + 14, y + 48, w - 28, h - 66); return;
  }
  CandidateVolumeSnapshot candidate = dcrteSchedulerController == null
    ? null : dcrteSchedulerController.snapshot;
  HBEIntrinsicObservables o = dcrteHbeSnapshot == null
    ? dcrteHbePreparedObservables : dcrteHbeSnapshot.observables;
  if (candidate == null || o == null || !o.isValid()
      || !dcrteHbeSpecsEqual(candidate.spec, o.spec)) {
    fill(180, 150, 80); textSize(12); textAlign(CENTER, CENTER);
    text("LOAD FIXTURE  >  BUILD SNAPSHOT  >  GENERATE CANDIDATE",
      x + w / 2, y + h / 2 - 10);
    fill(110, 140, 148); textSize(9);
    text("No HBE candidate volume is available for this view.", x + w / 2, y + h / 2 + 16);
    return;
  }
  boolean[] active = dcrteSchedulerController.state == null ? null
    : dcrteSchedulerController.state.active;
  int[] arrival = dcrteSchedulerController.state == null ? null
    : dcrteSchedulerController.state.arrivalBatch;
  int count = candidate.candidateSolid.length;
  int stride = max(1, ceil(pow(count / 62000.0f, 1.0f / 3.0f)));
  float scale = min(w * 0.78f, h * 0.84f);
  int cx = x + w / 2, cy = y + h / 2 + 18;
  strokeWeight(1.4f);
  for (int z = 0; z < candidate.spec.nz; z += stride)
    for (int yy = 0; yy < candidate.spec.ny; yy += stride)
      for (int xx = 0; xx < candidate.spec.nx; xx += stride) {
        int index = xx + candidate.spec.nx * (yy + candidate.spec.ny * z);
        if (!candidate.candidateSolid[index] || !o.valid[index]) continue;
        if (stride == 1 && !dcrteHbeExposed(index, candidate.candidateSolid, candidate.spec)
            && (active == null || !active[index])) continue;
        color c = dcrteHbeVoxelColor(index, candidate, o, active, arrival);
        float px = dcrteHbeProjectX(xx, z, candidate.spec, cx, scale);
        float py = dcrteHbeProjectY(xx, yy, z, candidate.spec, cy, scale);
        stroke(c); point(px, py);
      }
  strokeWeight(1);
  HBEConnectivityReport visiblePath = dcrteHbeVisibleConnectionReport();
  if (visiblePath != null && visiblePath.connected && visiblePath.shortestPath.length > 1) {
    boolean prominent = dcrteHbeVisualizationMode == HBEVisualizationMode.CONNECTION_PATH;
    drawDcrteHbeConnectionPath(visiblePath, candidate.spec, cx, cy, scale, prominent);
    drawDcrteHbePathBadge(x + w - 252, y + 9, 240, 34, visiblePath);
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.GRAPH_PAIRING_PROXY)
    drawDcrteHbePairingOverlay(x, y, w, h);
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.NECK_CROSS_SECTION)
    drawDcrteHbeNeckCrossSection(x + 18, y + h - 116, w - 36, 86, candidate, o, active);
  drawDcrteHbeViewLegend(x + 12, y + h - 20);
}

boolean dcrteHbeExposed(int index, boolean[] mask, VolumeSpec spec) {
  int[] neighbors = dcrteSixNeighbors(index, spec);
  if (neighbors.length < 6) return true;
  for (int i = 0; i < neighbors.length; i++) if (!mask[neighbors[i]]) return true;
  return false;
}

float dcrteHbeProjectX(int xx, int z, VolumeSpec spec, int cx, float scale) {
  float nx = spec.nx <= 1 ? 0 : xx / (float)(spec.nx - 1) - 0.5f;
  float nz = spec.nz <= 1 ? 0 : z / (float)(spec.nz - 1) - 0.5f;
  return cx + (0.88f * nx - 0.42f * nz) * scale;
}

float dcrteHbeProjectY(int xx, int yy, int z, VolumeSpec spec, int cy, float scale) {
  float nx = spec.nx <= 1 ? 0 : xx / (float)(spec.nx - 1) - 0.5f;
  float ny = spec.ny <= 1 ? 0 : yy / (float)(spec.ny - 1) - 0.5f;
  float nz = spec.nz <= 1 ? 0 : z / (float)(spec.nz - 1) - 0.5f;
  return cy + (-0.70f * ny + 0.18f * nx + 0.22f * nz) * scale;
}

color dcrteHbeVoxelColor(int index, CandidateVolumeSnapshot candidate,
    HBEIntrinsicObservables o, boolean[] active, int[] arrival) {
  float xi = o.xi[index], neck = o.neckProximity[index];
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.NECK_PROXIMITY)
    return lerpColor(color(24, 86, 112), color(255, 190, 48), neck);
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.SIDE_COORDINATE_XI)
    return xi < 0 ? lerpColor(color(220, 64, 142), color(250, 230, 96), xi + 1)
      : lerpColor(color(250, 230, 96), color(30, 205, 190), xi);
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.MIRROR_PARTNERS)
    return dcrteHbeSnapshot != null && dcrteHbeSnapshot.mirrorMap.pairIndex[index] >= 0
      ? color(194, 104, 232) : color(54, 75, 84);
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.MIRROR_CONFIDENCE) {
    float c = dcrteHbeSnapshot == null ? 0 : dcrteHbeSnapshot.mirrorMap.pairConfidence[index];
    return lerpColor(color(60, 65, 76), color(62, 232, 180), c);
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.HBE_FIELD_DELTA) {
    float delta = index < dcrteHbeFieldSensitivity.scalarDelta.length
      ? dcrteHbeFieldSensitivity.scalarDelta[index] : 0;
    return delta < 0 ? lerpColor(color(130, 210, 255), color(20, 75, 180), min(1, -delta * 10))
      : lerpColor(color(255, 220, 130), color(235, 68, 96), min(1, delta * 10));
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.HBE_CANDIDATE_CHANGES) {
    if (index < dcrteHbeFieldSensitivity.changedToCandidate.length
        && dcrteHbeFieldSensitivity.changedToCandidate[index]) return color(50, 240, 180);
    if (index < dcrteHbeFieldSensitivity.changedFromCandidate.length
        && dcrteHbeFieldSensitivity.changedFromCandidate[index]) return color(255, 72, 92);
    return color(72, 86, 94);
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.HBE_SCORE
      || dcrteHbeVisualizationMode == HBEVisualizationMode.CONNECTION_GAIN
      || dcrteHbeVisualizationMode == HBEVisualizationMode.CROSS_LOBE_REACHABILITY) {
    float reach = 0;
    if (dcrteHbeSnapshot != null && dcrteHbeSnapshot.reachability != null
        && dcrteHbeSnapshot.reachability.isValid())
      reach = dcrteHbeSnapshot.reachability.oppositeAnchorScore(index, xi);
    float score = dcrteHbeVisualizationMode == HBEVisualizationMode.CONNECTION_GAIN
      ? neck * reach : dcrteHbeVisualizationMode == HBEVisualizationMode.HBE_SCORE
      ? 0.55f * neck + 0.45f * reach : reach;
    return lerpColor(color(34, 50, 67), color(255, 120, 52), constrain(score, 0, 1));
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.LEFT_RIGHT_ACTIVE) {
    if (active == null || !active[index]) return color(42, 55, 62);
    return xi < 0 ? color(236, 78, 154) : color(30, 220, 190);
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.ARRIVAL_DIFFERENCE) {
    if (arrival == null || arrival[index] < 0 || dcrteHbeSnapshot == null) return color(48, 58, 65);
    int pair = dcrteHbeSnapshot.mirrorMap.pairIndex[index];
    float d = pair < 0 || arrival[pair] < 0 ? 1 : constrain(abs(arrival[index] - arrival[pair]) / 12.0f, 0, 1);
    return lerpColor(color(58, 222, 187), color(248, 76, 84), d);
  }
  if (dcrteHbeVisualizationMode == HBEVisualizationMode.CONNECTION_PATH && active != null)
    return active[index] ? color(55, 220, 190) : color(35, 57, 64);
  return xi < 0 ? color(224, 74, 154) : color(30, 205, 190);
}

HBEConnectivityReport dcrteHbeVisibleConnectionReport() {
  if (dcrteHbeActiveConnectivity != null && dcrteHbeActiveConnectivity.connected)
    return dcrteHbeActiveConnectivity;
  return dcrteHbeSnapshot == null ? null : dcrteHbeSnapshot.candidateConnectivity;
}

boolean dcrteHbeShowingActivePath(HBEConnectivityReport report) {
  return report != null && report == dcrteHbeActiveConnectivity
    && dcrteHbeActiveConnectivity.connected;
}

void drawDcrteHbeConnectionPath(HBEConnectivityReport report, VolumeSpec spec,
    int cx, int cy, float scale, boolean prominent) {
  if (report == null || report.shortestPath.length < 2) return;
  boolean activePath = dcrteHbeShowingActivePath(report);
  color pathColor = activePath ? color(255, 222, 72) : color(54, 226, 204);
  noFill();
  stroke(red(pathColor), green(pathColor), blue(pathColor), prominent ? 72 : 34);
  strokeWeight(prominent ? 8.0f : 5.0f);
  beginShape();
  for (int i = 0; i < report.shortestPath.length; i++) {
    int index = report.shortestPath[i]; int xx = index % spec.nx;
    int yy = (index / spec.nx) % spec.ny; int z = index / (spec.nx * spec.ny);
    vertex(dcrteHbeProjectX(xx, z, spec, cx, scale), dcrteHbeProjectY(xx, yy, z, spec, cy, scale));
  }
  endShape();
  stroke(pathColor); strokeWeight(prominent ? 2.6f : 1.5f); beginShape();
  for (int i = 0; i < report.shortestPath.length; i++) {
    int index = report.shortestPath[i]; int xx = index % spec.nx;
    int yy = (index / spec.nx) % spec.ny; int z = index / (spec.nx * spec.ny);
    vertex(dcrteHbeProjectX(xx, z, spec, cx, scale), dcrteHbeProjectY(xx, yy, z, spec, cy, scale));
  }
  endShape();

  int start = report.shortestPath[0];
  int end = report.shortestPath[report.shortestPath.length - 1];
  int meeting = activePath && dcrteHbeConnectionEvent != null
    && dcrteHbeConnectionEvent.meetingVoxelIndex >= 0
    ? dcrteHbeConnectionEvent.meetingVoxelIndex
    : report.shortestPath[report.shortestPath.length / 2];
  drawDcrteHbePathEndpoint(start, spec, cx, cy, scale, color(231, 78, 158));
  drawDcrteHbePathEndpoint(end, spec, cx, cy, scale, color(52, 222, 205));
  drawDcrteHbeMeetingMarker(meeting, spec, cx, cy, scale, pathColor, prominent);
  strokeWeight(1);
}

void drawDcrteHbePathEndpoint(int index, VolumeSpec spec, int cx, int cy,
    float scale, color markerColor) {
  int xx = index % spec.nx;
  int yy = (index / spec.nx) % spec.ny;
  int z = index / (spec.nx * spec.ny);
  float px = dcrteHbeProjectX(xx, z, spec, cx, scale);
  float py = dcrteHbeProjectY(xx, yy, z, spec, cy, scale);
  fill(3, 10, 15); stroke(markerColor); strokeWeight(2.0f); ellipse(px, py, 10, 10);
}

void drawDcrteHbeMeetingMarker(int index, VolumeSpec spec, int cx, int cy,
    float scale, color markerColor, boolean prominent) {
  int xx = index % spec.nx;
  int yy = (index / spec.nx) % spec.ny;
  int z = index / (spec.nx * spec.ny);
  float px = dcrteHbeProjectX(xx, z, spec, cx, scale);
  float py = dcrteHbeProjectY(xx, yy, z, spec, cy, scale);
  noFill(); stroke(markerColor); strokeWeight(prominent ? 2.0f : 1.2f);
  ellipse(px, py, prominent ? 26 : 18, prominent ? 26 : 18);
  line(px - 9, py, px + 9, py); line(px, py - 9, px, py + 9);
  fill(markerColor); noStroke(); ellipse(px, py, 4, 4);
}

void drawDcrteHbePathBadge(int x, int y, int w, int h, HBEConnectivityReport report) {
  boolean activePath = dcrteHbeShowingActivePath(report);
  color c = activePath ? color(255, 211, 70) : color(54, 220, 201);
  fill(3, 12, 17, 238); stroke(c); strokeWeight(1.2f); rect(x, y, w, h, 3);
  fill(c); textAlign(LEFT, TOP); textSize(9);
  text(activePath ? "ACTIVE TRANSPORT PATH DETECTED" : "CANDIDATE TRANSPORT PATH DETECTED", x + 8, y + 5);
  fill(157, 188, 191); textSize(8);
  text(report.shortestPathSteps + " steps   neck " + report.minimumNeckCrossSection
    + "   bottleneck " + dcrteHbeMetric(report.bottleneckFraction), x + 8, y + 19);
}

void drawDcrteHbePairingOverlay(int x, int y, int w, int h) {
  HBEGraphPairingReport pairing = dcrteHbeActivePairing != null && dcrteHbeActivePairing.isValid()
    ? dcrteHbeActivePairing : dcrteHbeSnapshot == null ? null : dcrteHbeSnapshot.candidatePairing;
  fill(5, 12, 18, 230); stroke(50, 92, 98); rect(x + 18, y + h - 108, 310, 78, 3);
  fill(155, 190, 195); textAlign(LEFT, TOP); textSize(9);
  text("GRAPH PAIRING PROXY", x + 28, y + h - 98);
  text("connected cost     " + dcrteHbeMetric(pairing == null ? Float.NaN : pairing.connectedCost), x + 28, y + h - 80);
  text("disconnected cost  " + dcrteHbeMetric(pairing == null ? Float.NaN : pairing.disconnectedCost), x + 28, y + h - 64);
  text("NOT RT SURFACE / NOT REGULARIZED GEODESIC", x + 28, y + h - 48);
}

void drawDcrteHbeNeckCrossSection(int x, int y, int w, int h,
    CandidateVolumeSnapshot candidate, HBEIntrinsicObservables o, boolean[] active) {
  int bins = 24; int[] c = new int[bins]; int[] a = new int[bins]; int maximum = 1;
  for (int i = 0; i < candidate.candidateSolid.length; i++) if (o.valid[i] && o.neckBand[i]) {
    int b = constrain(floor((0.5f * (o.xi[i] + 1)) * bins), 0, bins - 1);
    if (candidate.candidateSolid[i]) c[b]++;
    if (active != null && active[i]) a[b]++;
    maximum = max(maximum, c[b]);
  }
  fill(4, 11, 16, 230); stroke(42, 80, 86); rect(x, y, w, h, 3);
  for (int b = 0; b < bins; b++) {
    float bx = map(b, 0, bins - 1, x + 8, x + w - 8);
    stroke(55, 130, 142); line(bx, y + h - 10, bx, y + h - 10 - (h - 24) * c[b] / maximum);
    stroke(255, 195, 65); line(bx + 2, y + h - 10, bx + 2, y + h - 10 - (h - 24) * a[b] / maximum);
  }
}

void drawDcrteHbeSweepHeatmap(int x, int y, int w, int h) {
  HBESweepManifest sweep = dcrteHbeSweepRunning ? dcrteHbeSweepManifest : dcrteHbeLastSweep;
  if (sweep == null || sweep.cells.size() == 0) {
    fill(170, 145, 76); textAlign(CENTER, CENTER); textSize(12);
    text("RUN SWEEP to populate the fixed-envelope 11 x 6 response map", x + w / 2, y + h / 2);
    return;
  }
  int summaryH = 28;
  int gridH = max(40, h - summaryH - 18);
  float cw = w / (float)sweep.couplingSteps;
  float ch = gridH / (float)sweep.feedbackSteps;
  noStroke(); fill(16, 26, 34); rect(x, y + summaryH, w, gridH);
  for (int i = 0; i < sweep.cells.size(); i++) {
    HBESweepCell cell = sweep.cells.get(i);
    float v = constrain(cell.bottleneckFraction, 0, 1);
    fill(cell.failure.length() > 0 ? color(205, 64, 75)
      : cell.candidateConnected ? lerpColor(color(24, 88, 118), color(42, 226, 172), v)
      : color(58, 62, 74));
    stroke(4, 12, 18); rect(x + cell.eIndex * cw,
      y + summaryH + (sweep.feedbackSteps - 1 - cell.mIndex) * ch, cw, ch);
  }
  int connected = 0, failed = 0;
  for (int i = 0; i < sweep.cells.size(); i++) {
    HBESweepCell cell = sweep.cells.get(i);
    if (cell.candidateConnected) connected++;
    if (cell.failure.length() > 0) failed++;
  }
  fill(dcrteHbeSweepRunning ? color(255, 190, 66) : color(54, 222, 185));
  textAlign(LEFT, TOP); textSize(9);
  text(dcrteHbeSweepRunning ? "SWEEP RUNNING " + sweep.cells.size() + " / " + dcrteHbeSweepCellTotal()
    : "SWEEP COMPLETE " + sweep.cells.size() + " / " + dcrteHbeSweepCellTotal(), x, y + 2);
  fill(132, 166, 171); textAlign(RIGHT, TOP); textSize(8);
  long displayedRuntime = dcrteHbeSweepRunning
    ? Math.max(0L, (long)millis() - dcrteHbeSweepStartedAt) : sweep.runtimeMillis;
  text(connected + " connected   " + failed + " failed   "
    + nf(displayedRuntime / 1000.0f, 1, 2) + "s", x + w, y + 3);

  float currentFeedback = dcrteHbePreparedMetrics == null
    ? dcrteHbeConfig.manualFeedback : dcrteHbePreparedMetrics.feedback;
  int currentE = constrain(round(dcrteHbeConfig.coupling * (sweep.couplingSteps - 1)), 0, sweep.couplingSteps - 1);
  int currentM = constrain(round(currentFeedback * (sweep.feedbackSteps - 1)), 0, sweep.feedbackSteps - 1);
  noFill(); stroke(255); strokeWeight(2.0f);
  rect(x + currentE * cw + 2,
    y + summaryH + (sweep.feedbackSteps - 1 - currentM) * ch + 2, cw - 4, ch - 4);
  strokeWeight(1);
  fill(125, 158, 164); textAlign(LEFT, BOTTOM); textSize(9);
  text("coupling analog 0 -> 1", x, y + h);
  pushMatrix(); translate(x - 6, y + h - 2); rotate(-HALF_PI); text("feedback analog 0 -> 1", 0, 0); popMatrix();
}

void drawDcrteHbeViewLegend(int x, int y) {
  fill(95, 132, 140); textAlign(LEFT, BASELINE); textSize(8);
  text("DISPLAY: CLASSICAL FIELD / VOXEL-GRAPH PROXY", x, y);
}

String dcrteHbeMetric(float value) { return dcrteFinite(value) ? nf(value, 1, 3) : "n/a"; }
