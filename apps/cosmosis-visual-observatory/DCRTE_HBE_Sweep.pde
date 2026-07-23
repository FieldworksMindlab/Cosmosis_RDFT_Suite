/* M6-HX explicit fixed-envelope sweep. Each cell starts from the frozen candidate snapshot. */

enum HBESweepMode {
  FIXED_ENVELOPE_FAST, REBUILD_GEOMETRY_FULL;
  String id() { return name().toLowerCase(); }
}

class HBESweepCell {
  int eIndex, mIndex; float coupling, feedback;
  int candidateCount, changedTo, changedFrom, components, minimumNeckCrossSection;
  boolean candidateConnected; float bottleneckFraction; long runtimeMillis;
  String candidateHash = "", cellHash = "", failure = "";
  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setInt("coupling_index", eIndex); j.setInt("feedback_index", mIndex);
    j.setFloat("coupling_analog", coupling); j.setFloat("feedback_analog", feedback);
    j.setInt("candidate_voxels", candidateCount); j.setInt("changed_to_candidate", changedTo);
    j.setInt("changed_from_candidate", changedFrom); j.setBoolean("candidate_connected", candidateConnected);
    j.setInt("component_count", components); j.setInt("minimum_neck_cross_section", minimumNeckCrossSection);
    j.setFloat("neck_bottleneck_fraction", bottleneckFraction); j.setString("candidate_sha256", candidateHash);
    j.setString("cell_sha256", cellHash); j.setString("runtime_millis", Long.toString(runtimeMillis));
    j.setString("failure", failure); return j;
  }
}

class HBESweepManifest {
  HBESweepMode mode = HBESweepMode.FIXED_ENVELOPE_FAST;
  ArrayList<HBESweepCell> cells = new ArrayList<HBESweepCell>();
  int couplingSteps = 11, feedbackSteps = 6; String sourceSnapshotHash = "";
  String configurationHash = "", contentHash = "", outputDirectory = "";
  long runtimeMillis;
  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("module", "M6-HX"); j.setString("mode", mode.id());
    j.setInt("coupling_steps", couplingSteps); j.setInt("feedback_steps", feedbackSteps);
    j.setString("source_candidate_sha256", sourceSnapshotHash); j.setString("configuration_sha256", configurationHash);
    j.setString("manifest_sha256", contentHash); j.setString("runtime_millis", Long.toString(runtimeMillis));
    JSONArray rows = new JSONArray(); for (int i = 0; i < cells.size(); i++) rows.setJSONObject(i, cells.get(i).toJSON());
    j.setJSONArray("cells", rows); j.setJSONObject("exploratory_layer", dcrteHbeProvenanceJSON());
    j.setString("nonclaim", "fixed-envelope classical candidate-sensitivity sweep; no geometry or quantum claim");
    return j;
  }
}

HBESweepManifest dcrteHbeLastSweep = null;
boolean dcrteHbeSweepRunning = false;
CandidateVolumeSnapshot dcrteHbeSweepSource = null;
HBEIntrinsicObservables dcrteHbeSweepObservables = null;
HBESweepManifest dcrteHbeSweepManifest = null;
int dcrteHbeSweepEIndex = 0;
int dcrteHbeSweepMIndex = 0;
long dcrteHbeSweepStartedAt = 0;
long dcrteHbeSweepCompletedAt = 0;

void runDcrteHbeFastSweep() {
  if (dcrteHbeSweepRunning) {
    dcrteHbeStatus = "sweep already running " + dcrteHbeSweepProgress() + " / " + dcrteHbeSweepCellTotal();
    return;
  }
  if (dcrteHbeSnapshot == null || dcrteSchedulerController == null
      || dcrteSchedulerController.snapshot == null) {
    dcrteHbeStatus = "sweep requires a current frozen HBE candidate snapshot"; return;
  }
  CandidateVolumeSnapshot source = dcrteSchedulerController.snapshot;
  HBEIntrinsicObservables o = dcrteHbeSnapshot.observables;
  if (!dcrteHbeSpecsEqual(source.spec, o.spec)) { dcrteHbeStatus = "sweep blocked: frozen grids do not match"; return; }
  dcrteHbeLastSweep = null;
  dcrteHbeSweepSource = source;
  dcrteHbeSweepObservables = o;
  dcrteHbeSweepManifest = new HBESweepManifest();
  dcrteHbeSweepManifest.sourceSnapshotHash = source.contentHash;
  dcrteHbeSweepManifest.configurationHash = dcrteHbeConfig.configurationHash();
  dcrteHbeSweepEIndex = 0;
  dcrteHbeSweepMIndex = 0;
  dcrteHbeSweepStartedAt = millis();
  dcrteHbeSweepRunning = true;
  dcrteHbeStatus = "sweep running 0 / " + dcrteHbeSweepCellTotal();
}

void updateDcrteHbeSweep() {
  if (!dcrteHbeSweepRunning) return;
  if (dcrteHbeSweepSource == null || dcrteHbeSweepObservables == null
      || dcrteHbeSweepManifest == null || dcrteSchedulerController == null
      || dcrteSchedulerController.snapshot == null
      || !dcrteHbeSweepSource.contentHash.equals(dcrteSchedulerController.snapshot.contentHash)) {
    dcrteHbeAbortSweep("sweep cancelled: frozen candidate changed");
    return;
  }
  float feedback = dcrteHbeSweepMIndex / (float)(dcrteHbeSweepManifest.feedbackSteps - 1);
  float coupling = dcrteHbeSweepEIndex / (float)(dcrteHbeSweepManifest.couplingSteps - 1);
  dcrteHbeSweepManifest.cells.add(dcrteHbeRunFastSweepCell(
    dcrteHbeSweepSource, dcrteHbeSweepObservables,
    dcrteHbeSweepEIndex, dcrteHbeSweepMIndex, coupling, feedback));
  dcrteHbeSweepEIndex++;
  if (dcrteHbeSweepEIndex >= dcrteHbeSweepManifest.couplingSteps) {
    dcrteHbeSweepEIndex = 0;
    dcrteHbeSweepMIndex++;
  }
  dcrteHbeStatus = "sweep running " + dcrteHbeSweepProgress() + " / " + dcrteHbeSweepCellTotal();
  if (dcrteHbeSweepMIndex < dcrteHbeSweepManifest.feedbackSteps) return;

  StringBuilder hashes = new StringBuilder();
  for (int i = 0; i < dcrteHbeSweepManifest.cells.size(); i++)
    hashes.append(dcrteHbeSweepManifest.cells.get(i).cellHash).append('|');
  dcrteHbeSweepManifest.runtimeMillis = millis() - dcrteHbeSweepStartedAt;
  dcrteHbeSweepManifest.contentHash = dcrteSha256Hex(dcrteHbeSweepManifest.sourceSnapshotHash
    + "|" + dcrteHbeSweepManifest.configurationHash + "|" + hashes.toString());
  dcrteHbeLastSweep = dcrteHbeSweepManifest;
  dcrteHbeSweepCompletedAt = millis();
  dcrteHbeSweepRunning = false;
  dcrteHbeSweepSource = null;
  dcrteHbeSweepObservables = null;
  dcrteHbeSweepManifest = null;
  dcrteHbeVisualizationMode = HBEVisualizationMode.SWEEP_HEATMAP;
  dcrteHbeStatus = "sweep complete: " + dcrteHbeSweepConnectedCount() + " / "
    + dcrteHbeSweepCellTotal() + " cells connected; " + dcrteHbeSweepFailureCount() + " failed";
}

void dcrteHbeAbortSweep(String reason) {
  dcrteHbeSweepRunning = false;
  dcrteHbeSweepSource = null;
  dcrteHbeSweepObservables = null;
  dcrteHbeSweepManifest = null;
  dcrteHbeSweepEIndex = 0;
  dcrteHbeSweepMIndex = 0;
  dcrteHbeStatus = reason;
}

void resetDcrteHbeSweepState() {
  dcrteHbeSweepRunning = false;
  dcrteHbeSweepSource = null;
  dcrteHbeSweepObservables = null;
  dcrteHbeSweepManifest = null;
  dcrteHbeSweepEIndex = 0;
  dcrteHbeSweepMIndex = 0;
  dcrteHbeLastSweep = null;
  dcrteHbeSweepCompletedAt = 0;
}

int dcrteHbeSweepProgress() {
  return dcrteHbeSweepManifest == null ? 0 : dcrteHbeSweepManifest.cells.size();
}

int dcrteHbeSweepCellTotal() {
  HBESweepManifest manifest = dcrteHbeSweepManifest != null ? dcrteHbeSweepManifest : dcrteHbeLastSweep;
  return manifest == null ? 66 : manifest.couplingSteps * manifest.feedbackSteps;
}

int dcrteHbeSweepFailureCount() {
  if (dcrteHbeLastSweep == null) return 0;
  int failures = 0;
  for (int i = 0; i < dcrteHbeLastSweep.cells.size(); i++)
    if (dcrteHbeLastSweep.cells.get(i).failure.length() > 0) failures++;
  return failures;
}

int dcrteHbeSweepConnectedCount() {
  if (dcrteHbeLastSweep == null) return 0;
  int connected = 0;
  for (int i = 0; i < dcrteHbeLastSweep.cells.size(); i++)
    if (dcrteHbeLastSweep.cells.get(i).candidateConnected) connected++;
  return connected;
}

boolean dcrteHbeSweepCurrent() {
  return dcrteHbeLastSweep != null && dcrteHbeSnapshot != null
    && dcrteHbeLastSweep.sourceSnapshotHash.equals(dcrteHbeSnapshot.candidateSnapshotHash)
    && dcrteHbeLastSweep.configurationHash.equals(dcrteHbeConfig.configurationHash())
    && dcrteHbeLastSweep.cells.size() == dcrteHbeSweepCellTotal();
}

HBESweepCell dcrteHbeRunFastSweepCell(CandidateVolumeSnapshot source,
    HBEIntrinsicObservables o, int ei, int mi, float coupling, float feedback) {
  long started = millis(); HBESweepCell cell = new HBESweepCell();
  cell.eIndex = ei; cell.mIndex = mi; cell.coupling = coupling; cell.feedback = feedback;
  try {
    HBEConfig c = dcrteHbeConfig.copy(); c.influenceMode = HBEInfluenceMode.FIELD_ONLY;
    c.feedbackSource = HBEFeedbackSource.MANUAL; c.manualFeedback = feedback; c.coupling = coupling;
    HBEFrozenMetrics metrics = new HBEFrozenMetrics(0, 0, 0, 0, 0, 0, 0, c.deterministicSeed, c);
    HBEFieldContext context = new HBEFieldContext(c, metrics, o); boolean[] mask = new boolean[source.candidateSolid.length];
    FieldCoordinateSample coordinate = new FieldCoordinateSample().setCartesian(0, 0, 0);
    for (int i = 0; i < mask.length; i++) if (source.admitted[i] && o.valid[i]) {
      float modified = dcrteHbeFieldModifier.modify(source.fieldScalar[i], coordinate, i, context);
      mask[i] = dcrteFinite(modified) && abs(modified) < foundryIsoBand;
      if (mask[i]) cell.candidateCount++;
      if (!source.candidateSolid[i] && mask[i]) cell.changedTo++;
      if (source.candidateSolid[i] && !mask[i]) cell.changedFrom++;
    }
    HBEConnectivityReport report = dcrteHbeAnalyzeConnectivity(mask, o);
    cell.candidateConnected = report.connected; cell.components = report.componentCount;
    cell.minimumNeckCrossSection = report.minimumNeckCrossSection;
    cell.bottleneckFraction = report.bottleneckFraction; cell.candidateHash = dcrteHbeBooleanMaskHash(mask);
  } catch (Exception error) {
    cell.failure = error.getClass().getSimpleName() + ": " + (error.getMessage() == null ? "sweep cell failed" : error.getMessage());
  }
  cell.runtimeMillis = millis() - started;
  cell.cellHash = dcrteSha256Hex(ei + "|" + mi + "|" + coupling + "|" + feedback + "|"
    + cell.candidateHash + "|" + cell.candidateConnected + "|" + cell.failure);
  return cell;
}
