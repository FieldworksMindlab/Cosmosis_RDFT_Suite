/* M6-HX isolated experiment snapshot and lifecycle. */

class HBEConnectionEvent {
  boolean candidateConnected;
  boolean occurred;
  int firstBatch = -1;
  float firstTau = Float.NaN;
  float firstEntropy = Float.NaN;
  float frontierEntropy = Float.NaN;
  int meetingVoxelIndex = -1;
  int neckActiveVoxelCount;
  int minimumNeckCrossSection;
  float neckBottleneckS = Float.NaN;
  float weightedPathCost = Float.NaN;
  int pathSteps = -1;
  float bottleneckFraction;
  String stateHash = "";
  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setBoolean("candidate_connected", candidateConnected);
    j.setBoolean("active_connected", occurred); j.setBoolean("occurred", occurred); j.setInt("first_batch", firstBatch);
    if (dcrteFinite(firstTau)) j.setFloat("first_tau", firstTau);
    if (dcrteFinite(firstEntropy)) j.setFloat("first_entropy", firstEntropy);
    if (dcrteFinite(frontierEntropy)) j.setFloat("frontier_entropy_at_connection", frontierEntropy);
    j.setInt("meeting_voxel_index", meetingVoxelIndex); j.setInt("path_steps", pathSteps);
    if (dcrteFinite(weightedPathCost)) j.setFloat("weighted_graph_path_cost", weightedPathCost);
    j.setInt("neck_active_voxels", neckActiveVoxelCount);
    j.setInt("minimum_neck_cross_section", minimumNeckCrossSection);
    if (dcrteFinite(neckBottleneckS)) j.setFloat("neck_bottleneck_s", neckBottleneckS);
    j.setFloat("bottleneck_fraction", bottleneckFraction);
    j.setString("scheduler_state_sha256", stateHash); return j;
  }
}

class HBEExperimentSnapshot {
  final HBEConfig config;
  final HBEFrozenMetrics metrics;
  final HBEIntrinsicObservables observables;
  final HBEMirrorMap mirrorMap;
  final HBEReachabilityMap reachability;
  final String candidateSnapshotHash;
  final String sourceDomainSignature;
  final HBEConnectivityReport candidateConnectivity;
  final HBEGraphPairingReport candidatePairing;
  final String contentHash;
  final boolean fieldChannelEnabled;
  final boolean schedulerChannelEnabled;

  HBEExperimentSnapshot(HBEConfig config, HBEFrozenMetrics metrics,
      HBEIntrinsicObservables observables, CandidateVolumeSnapshot candidate) {
    this.config = config.copy(); this.metrics = metrics; this.observables = observables;
    candidateSnapshotHash = candidate == null ? "" : candidate.contentHash;
    sourceDomainSignature = dcrteCurrentIntrinsicDomainSignature();
    mirrorMap = new HBEMirrorMap(candidate, observables, config.mirrorPolicy);
    reachability = new HBEReachabilityMap(candidate, observables);
    candidateConnectivity = dcrteHbeAnalyzeConnectivity(candidate == null ? null : candidate.candidateSolid, observables);
    dcrteHbeEnrichMirrorMetrics(candidateConnectivity,
      candidate == null ? null : candidate.candidateSolid, mirrorMap, null);
    candidatePairing = dcrteHbeAnalyzeGraphPairing(
      candidate == null ? null : candidate.candidateSolid, observables);
    fieldChannelEnabled = config.influenceMode.fieldEnabled();
    schedulerChannelEnabled = config.influenceMode.schedulerEnabled();
    contentHash = dcrteSha256Hex(config.configurationHash() + "|" + metrics.contentHash + "|"
      + observables.sourceHash + "|" + candidateSnapshotHash + "|" + mirrorMap.contentHash
      + "|" + reachability.contentHash);
  }

  boolean isValid() {
    return config != null && metrics != null && observables != null && observables.isValid()
      && candidateSnapshotHash.length() > 0 && mirrorMap != null
      && reachability != null && reachability.isValid()
      && candidateConnectivity != null && candidateConnectivity.validInput;
  }

  boolean matches(CandidateVolumeSnapshot candidate) {
    return isValid() && candidate != null && candidate.contentHash.equals(candidateSnapshotHash)
      && dcrteHbeSpecsEqual(candidate.spec, observables.spec);
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("module", "M6-HX"); j.setString("version", DCRTE_HBE_VERSION);
    j.setString("sha256", contentHash); j.setString("candidate_snapshot_sha256", candidateSnapshotHash);
    j.setString("source_domain_signature", sourceDomainSignature); j.setJSONObject("configuration", config.toJSON());
    j.setJSONObject("frozen_metrics", metrics.toJSON()); j.setJSONObject("intrinsic_observables", observables.toJSON());
    j.setJSONObject("mirror_map", mirrorMap.toJSON()); j.setJSONObject("candidate_connectivity", candidateConnectivity.toJSON());
    j.setJSONObject("candidate_graph_pairing", candidatePairing.toJSON());
    j.setJSONObject("candidate_reachability", reachability.toJSON());
    j.setBoolean("field_channel_enabled", fieldChannelEnabled); j.setBoolean("scheduler_channel_enabled", schedulerChannelEnabled);
    j.setJSONObject("exploratory_layer", dcrteHbeProvenanceJSON());
    j.setString("citation", DCRTE_HBE_CITATION); j.setString("nonclaim", DCRTE_HBE_NONCLAIM);
    j.setBoolean("quantum_code_implemented", false); j.setBoolean("physical_wormhole_claimed", false);
    return j;
  }
}

HBEState dcrteHbeState = HBEState.DISABLED;
String dcrteHbeStatus = "HBE disabled; legacy M0-M6 identity active";
String dcrteHbeLastExport = "";
HBEFrozenMetrics dcrteHbePreparedMetrics = null;
HBEIntrinsicObservables dcrteHbePreparedObservables = null;
HBEExperimentSnapshot dcrteHbeSnapshot = null;
HBEConnectivityReport dcrteHbeActiveConnectivity = null;
HBEGraphPairingReport dcrteHbeActivePairing = new HBEGraphPairingReport();
HBEConnectionEvent dcrteHbeConnectionEvent = new HBEConnectionEvent();
DCRTEM1TestReport dcrteHbeTests = new DCRTEM1TestReport();

void initializeDcrteHbe() {
  dcrteHbeEnabled = false; dcrteHbeState = HBEState.DISABLED;
  dcrteHbeTests = runDcrteHbeTests();
  println("DCRTE-ET M6-HX HBE deterministic tests: " + dcrteHbeTests.status());
  for (int i = 0; i < dcrteHbeTests.failures.size(); i++) println("  FAIL " + dcrteHbeTests.failures.get(i));
}

void dcrteHbeSetEnabled(boolean enabled) {
  if (dcrteHbeEnabled == enabled) return;
  dcrteHbeEnabled = enabled;
  if (!enabled) {
    dcrteHbeState = HBEState.DISABLED; dcrteHbeStatus = "HBE disabled; legacy M0-M6 identity active";
    dcrteHbePreparedMetrics = null; dcrteHbePreparedObservables = null; dcrteHbeSnapshot = null;
    dcrteHbeActiveConnectivity = null; dcrteHbeActivePairing = new HBEGraphPairingReport();
    dcrteHbeConnectionEvent = new HBEConnectionEvent();
    resetDcrteHbeSweepState();
    if (dcrteSchedulerController != null && dcrteSchedulerController.snapshot != null)
      dcrteSchedulerController.initializeCurrent();
  } else {
    dcrteHbeState = HBEState.CONFIGURED;
    dcrteHbeStatus = "HBE configured in " + dcrteHbeConfig.influenceMode.id() + " mode; build a frozen snapshot";
  }
}

void invalidateDcrteHbe(String reason) {
  if (!dcrteHbeEnabled) return;
  dcrteHbePreparedMetrics = null; dcrteHbePreparedObservables = null;
  dcrteHbeSnapshot = null; dcrteHbeActiveConnectivity = null;
  dcrteHbeActivePairing = new HBEGraphPairingReport(); dcrteHbeConnectionEvent = new HBEConnectionEvent();
  resetDcrteHbeSweepState();
  dcrteHbeState = HBEState.INVALIDATED;
  dcrteHbeStatus = "HBE snapshot invalidated: " + (reason == null ? "upstream state changed" : reason);
}

boolean captureDcrteHbeFeedback() {
  if (!dcrteHbeEnabled) {
    dcrteHbeStatus = "enable HBE before capturing feedback";
    return false;
  }
  dcrteHbePreparedMetrics = new HBEFrozenMetrics(dcrteHbeConfig.copy());
  dcrteHbeSnapshot = null; dcrteHbeActiveConnectivity = null;
  dcrteHbeActivePairing = new HBEGraphPairingReport();
  dcrteHbeConnectionEvent = new HBEConnectionEvent();
  resetDcrteHbeSweepState();
  dcrteHbeState = HBEState.CONFIGURED;
  dcrteHbeStatus = "feedback frozen at " + nf(dcrteHbePreparedMetrics.feedback, 1, 3)
    + "; build HBE snapshot to bind domain and candidacy";
  return true;
}

boolean buildDcrteHbeSnapshot() {
  if (!dcrteHbeEnabled) { dcrteHbeStatus = "enable HBE before building a snapshot"; return false; }
  if (dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) {
    dcrteHbeStatus = "building trusted SDF through the normal imported-domain pipeline";
    if (!buildDcrteImportedSdf()) { dcrteHbeState = HBEState.FAILED; dcrteHbeStatus = "HBE blocked: imported SDF is not qualified"; return false; }
  }
  if (dcrteIntrinsicBuildResult == null || dcrteIntrinsicBuildResult.volume == null
      || !dcrteIntrinsicBuildResult.volume.isValid()
      || !dcrteCurrentIntrinsicDomainSignature().equals(dcrteIntrinsicBuildResult.sourceDomainSignature)) {
    dcrteHbeStatus = "building intrinsic coordinates through the M3 pipeline";
    if (!buildDcrteImportedIntrinsicCoordinates()) { dcrteHbeState = HBEState.FAILED; dcrteHbeStatus = "HBE blocked: M3 intrinsic coordinates are unavailable"; return false; }
  }
  if (!dcrteHbePrepareCurrentIntrinsic()) return false;
  CandidateVolumeSnapshot candidate = dcrteSchedulerController == null ? null : dcrteSchedulerController.snapshot;
  if (candidate != null && dcrteHbeSpecsEqual(candidate.spec, dcrteHbePreparedObservables.spec)) {
    return dcrteHbeFinalizeForCandidate(candidate) != null;
  }
  dcrteHbeState = HBEState.CONFIGURED;
  dcrteHbeStatus = "intrinsic observables frozen; generate material to capture the candidate snapshot";
  return true;
}

boolean dcrteHbePrepareCurrentIntrinsic() {
  if (!dcrteHbeEnabled || dcrteIntrinsicBuildResult == null
      || dcrteIntrinsicBuildResult.volume == null
      || !dcrteIntrinsicBuildResult.volume.isValid()) return false;
  if (dcrteHbePreparedMetrics == null)
    dcrteHbePreparedMetrics = new HBEFrozenMetrics(dcrteHbeConfig.copy());
  dcrteHbePreparedObservables = dcrteHbeBuildObservables(
    dcrteIntrinsicBuildResult.volume, dcrteHbeConfig);
  if (dcrteHbePreparedObservables == null || !dcrteHbePreparedObservables.isValid()) {
    dcrteHbeState = HBEState.FAILED;
    dcrteHbeStatus = "HBE blocked: confident left, neck, and right intrinsic regions are required";
    return false;
  }
  dcrteHbeState = HBEState.CONFIGURED;
  return true;
}

HBEExperimentSnapshot dcrteHbeFinalizeForCandidate(CandidateVolumeSnapshot candidate) {
  if (!dcrteHbeEnabled || candidate == null || !candidate.valid
      || dcrteHbePreparedMetrics == null || dcrteHbePreparedObservables == null
      || !dcrteHbeSpecsEqual(candidate.spec, dcrteHbePreparedObservables.spec)) return null;
  HBEExperimentSnapshot next = new HBEExperimentSnapshot(dcrteHbeConfig, dcrteHbePreparedMetrics,
    dcrteHbePreparedObservables, candidate);
  if (!next.isValid()) { dcrteHbeState = HBEState.FAILED; dcrteHbeStatus = "HBE snapshot failed mirror or connectivity validation"; return null; }
  dcrteHbeSnapshot = next; dcrteHbeActiveConnectivity = null;
  dcrteHbeActivePairing = new HBEGraphPairingReport(); dcrteHbeConnectionEvent = new HBEConnectionEvent();
  dcrteHbeConnectionEvent.candidateConnected = next.candidateConnectivity.connected;
  dcrteHbeState = HBEState.SNAPSHOT_READY;
  dcrteHbeStatus = next.candidateConnectivity.connected
    ? "snapshot ready; candidate bridge path detected"
    : "snapshot ready; no candidate bridge path detected (valid result)";
  return next;
}

HBEExperimentSnapshot dcrteHbeSnapshotForCandidate(CandidateVolumeSnapshot candidate) {
  if (!dcrteHbeEnabled) return null;
  if (dcrteHbeSnapshot != null && dcrteHbeSnapshot.matches(candidate)) return dcrteHbeSnapshot;
  return dcrteHbeFinalizeForCandidate(candidate);
}

void runDcrteHbeAnalysis() {
  CandidateVolumeSnapshot candidate = dcrteSchedulerController == null ? null : dcrteSchedulerController.snapshot;
  if (dcrteHbeSnapshot == null || !dcrteHbeSnapshot.matches(candidate)) {
    if (!buildDcrteHbeSnapshot() || dcrteHbeSnapshot == null) return;
  }
  dcrteHbeState = HBEState.RUNNING;
  PropagationState state = dcrteSchedulerController == null ? null : dcrteSchedulerController.state;
  dcrteHbeActiveConnectivity = dcrteHbeAnalyzeConnectivity(state == null ? null : state.active,
    dcrteHbeSnapshot.observables);
  dcrteHbeEnrichMirrorMetrics(dcrteHbeActiveConnectivity, state == null ? null : state.active,
    dcrteHbeSnapshot.mirrorMap, state);
  dcrteHbeActivePairing = dcrteHbeAnalyzeGraphPairing(
    state == null ? null : state.active, dcrteHbeSnapshot.observables);
  dcrteHbeRecordConnectionEvent(state);
  dcrteHbeState = HBEState.COMPLETE;
  dcrteHbeStatus = dcrteHbeActiveConnectivity != null && dcrteHbeActiveConnectivity.connected
    ? "analysis complete; scheduler-realized bridge path detected"
    : "analysis complete; scheduler-realized bridge absent (valid result)";
}

void dcrteHbeOnSchedulerStep() {
  if (!dcrteHbeEnabled || dcrteHbeSnapshot == null || dcrteSchedulerController == null
      || dcrteSchedulerController.state == null) return;
  dcrteHbeActiveConnectivity = dcrteHbeAnalyzeConnectivity(dcrteSchedulerController.state.active,
    dcrteHbeSnapshot.observables);
  dcrteHbeEnrichMirrorMetrics(dcrteHbeActiveConnectivity,
    dcrteSchedulerController.state.active, dcrteHbeSnapshot.mirrorMap,
    dcrteSchedulerController.state);
  dcrteHbeRecordConnectionEvent(dcrteSchedulerController.state);
}

void dcrteHbeRecordConnectionEvent(PropagationState state) {
  if (state == null || dcrteHbeActiveConnectivity == null || !dcrteHbeActiveConnectivity.connected
      || dcrteHbeConnectionEvent.occurred) return;
  dcrteHbeConnectionEvent.occurred = true; dcrteHbeConnectionEvent.firstBatch = state.batchIndex;
  dcrteHbeConnectionEvent.pathSteps = dcrteHbeActiveConnectivity.shortestPathSteps;
  dcrteHbeConnectionEvent.meetingVoxelIndex = dcrteHbeActiveConnectivity.shortestPath.length == 0
    ? -1 : dcrteHbeActiveConnectivity.shortestPath[dcrteHbeActiveConnectivity.shortestPath.length / 2];
  dcrteHbeConnectionEvent.weightedPathCost = dcrteHbeActiveConnectivity.shortestPathWorld;
  dcrteHbeConnectionEvent.neckActiveVoxelCount = dcrteHbeActiveConnectivity.neckOccupiedCount;
  dcrteHbeConnectionEvent.minimumNeckCrossSection = dcrteHbeActiveConnectivity.minimumNeckCrossSection;
  dcrteHbeConnectionEvent.neckBottleneckS = dcrteHbeActiveConnectivity.neckBottleneckS;
  dcrteHbeConnectionEvent.bottleneckFraction = dcrteHbeActiveConnectivity.bottleneckFraction;
  dcrteHbeConnectionEvent.stateHash = state.stateHash;
  EmergentEntropicScheduler entropic = dcrteSchedulerController.entropicScheduler();
  if (entropic != null) {
    dcrteHbeConnectionEvent.firstTau = (float)entropic.progress.tauRaw;
    dcrteHbeConnectionEvent.firstEntropy = entropic.entropySummary.meanLocalEntropy;
    dcrteHbeConnectionEvent.frontierEntropy = entropic.entropySummary.frontierMeanEntropy;
  }
}

JSONObject dcrteHbeProvenanceJSON() {
  JSONObject layer = new JSONObject(); layer.setString("id", "holographic_bridge_explorer");
  layer.setString("version", DCRTE_HBE_VERSION); layer.setString("module", "M6-HX");
  JSONObject paper = new JSONObject(); paper.setString("title", "Observation of gravity-like signatures in holographic codes on a quantum computer");
  paper.setString("authors_short", "Biswas et al."); paper.setInt("year", 2026);
  paper.setString("arxiv", "2607.12047v1"); paper.setString("doi", "10.48550/arXiv.2607.12047");
  layer.setJSONObject("paper_citation", paper);
  JSONObject scope = new JSONObject();
  String[] flags = {"actual_happy_code", "actual_tensor_network", "actual_perfect_tensors",
    "actual_quantum_entanglement", "actual_magic", "actual_rt_surface", "actual_qes",
    "actual_flm_measurement", "actual_proto_area_entropy", "actual_regularized_geodesic",
    "actual_wormhole_geometry", "actual_semiclassical_gravity"};
  for (int i = 0; i < flags.length; i++) scope.setBoolean(flags[i], false);
  layer.setJSONObject("analogy_scope", scope); return layer;
}

boolean dcrteHbeSpecsEqual(VolumeSpec a, VolumeSpec b) {
  if (a == null || b == null || a.bounds == null || b.bounds == null) return false;
  return a.nx == b.nx && a.ny == b.ny && a.nz == b.nz
    && Float.floatToIntBits(a.bounds.minX) == Float.floatToIntBits(b.bounds.minX)
    && Float.floatToIntBits(a.bounds.minY) == Float.floatToIntBits(b.bounds.minY)
    && Float.floatToIntBits(a.bounds.minZ) == Float.floatToIntBits(b.bounds.minZ)
    && Float.floatToIntBits(a.bounds.maxX) == Float.floatToIntBits(b.bounds.maxX)
    && Float.floatToIntBits(a.bounds.maxY) == Float.floatToIntBits(b.bounds.maxY)
    && Float.floatToIntBits(a.bounds.maxZ) == Float.floatToIntBits(b.bounds.maxZ);
}
