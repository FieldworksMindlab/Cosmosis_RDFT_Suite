/* DCRTE-ET Milestone 4 diagnostics and compact per-batch history. */

class SchedulerDiagnostic {
  String code;
  SchedulerDiagnosticSeverity severity;
  String stage;
  String message;
  int count;
  int index;
  String recommendedAction;
  SchedulerDiagnostic(String code, SchedulerDiagnosticSeverity severity, String stage,
      String message, int count, int index, String action) {
    this.code = code; this.severity = severity; this.stage = stage; this.message = message;
    this.count = count; this.index = index; recommendedAction = action;
  }
  JSONObject toJSON() {
    JSONObject json = new JSONObject(); json.setString("code", code); json.setString("severity", severity.id());
    json.setString("stage", stage); json.setString("message", message); json.setInt("count", count);
    json.setInt("index", index); json.setString("recommended_action", recommendedAction); return json;
  }
}

class SchedulerDiagnostics {
  SchedulerRunState runState = SchedulerRunState.NOT_INITIALIZED;
  SchedulerStopReason stopReason = SchedulerStopReason.NONE;
  int batchIndex, seedCount, candidateCount, activeCount, frontierCount, unreachableCount;
  long attemptedUpdates, acceptedUpdates;
  float activationProgress;
  int candidateComponentCount, activeComponentCount;
  long initializationMillis, schedulerComputeMillis, materializationMillis;
  String candidateSnapshotHash = "";
  String stateHash = "";
  ArrayList<SchedulerDiagnostic> issues = new ArrayList<SchedulerDiagnostic>();

  void add(String code, SchedulerDiagnosticSeverity severity, String stage, String message,
      int count, int index, String action) {
    issues.add(new SchedulerDiagnostic(code, severity, stage, message, count, index, action));
  }
  void error(String code, String stage, String message, int count, int index, String action) {
    add(code, SchedulerDiagnosticSeverity.ERROR, stage, message, count, index, action);
  }
  void warn(String code, String stage, String message, int count, int index, String action) {
    add(code, SchedulerDiagnosticSeverity.WARNING, stage, message, count, index, action);
  }
  boolean hasErrors() {
    for (int i = 0; i < issues.size(); i++) if (issues.get(i).severity == SchedulerDiagnosticSeverity.ERROR) return true;
    return false;
  }
  JSONObject toJSON() {
    JSONObject json = new JSONObject(); json.setString("run_state", runState.id()); json.setString("stop_reason", stopReason.id());
    json.setInt("batch_index", batchIndex); json.setInt("seed_count", seedCount); json.setInt("candidate_count", candidateCount);
    json.setInt("active_count", activeCount); json.setInt("frontier_count", frontierCount); json.setInt("unreachable_count", unreachableCount);
    json.setString("attempted_updates", Long.toString(attemptedUpdates)); json.setString("accepted_updates", Long.toString(acceptedUpdates));
    json.setFloat("activation_progress", activationProgress); json.setInt("candidate_component_count", candidateComponentCount);
    json.setInt("active_component_count", activeComponentCount); json.setLong("initialization_millis", initializationMillis);
    json.setLong("scheduler_compute_millis", schedulerComputeMillis); json.setLong("materialization_millis", materializationMillis);
    json.setString("candidate_snapshot_hash", candidateSnapshotHash); json.setString("state_hash", stateHash);
    JSONArray array = new JSONArray();
    JSONArray errors = new JSONArray();
    JSONArray warnings = new JSONArray();
    int errorIndex = 0, warningIndex = 0;
    for (int i = 0; i < issues.size(); i++) {
      SchedulerDiagnostic issue = issues.get(i);
      array.setJSONObject(i, issue.toJSON());
      if (issue.severity == SchedulerDiagnosticSeverity.ERROR) errors.setJSONObject(errorIndex++, issue.toJSON());
      if (issue.severity == SchedulerDiagnosticSeverity.WARNING) warnings.setJSONObject(warningIndex++, issue.toJSON());
    }
    json.setJSONArray("issues", array); json.setJSONArray("errors", errors); json.setJSONArray("warnings", warnings); return json;
  }
}

class SchedulerHistoryEntry {
  int batchIndex, newlyActivated, activeCount, frontierCount, remainingCandidateCount, activeComponentCount;
  float activeFraction;
  Float meanActivatedField, meanNewField, meanActivatedSDF, meanNewSDF;
  Float meanActivatedIntrinsicS, meanNewIntrinsicS, meanActivatedIntrinsicRho, meanNewIntrinsicRho;
  Float meanCoordinateConfidence;
  String stateHash = "", event = "step";
  JSONObject toJSON() {
    JSONObject json = new JSONObject(); json.setInt("batch_index", batchIndex); json.setInt("newly_activated", newlyActivated);
    json.setInt("active_count", activeCount); json.setInt("frontier_count", frontierCount);
    json.setInt("remaining_candidate_count", remainingCandidateCount); json.setFloat("active_fraction", activeFraction);
    dcrteSetNullableFloat(json, "mean_activated_field", meanActivatedField); dcrteSetNullableFloat(json, "mean_new_field", meanNewField);
    dcrteSetNullableFloat(json, "mean_activated_sdf", meanActivatedSDF); dcrteSetNullableFloat(json, "mean_new_sdf", meanNewSDF);
    dcrteSetNullableFloat(json, "mean_activated_intrinsic_s", meanActivatedIntrinsicS); dcrteSetNullableFloat(json, "mean_new_intrinsic_s", meanNewIntrinsicS);
    dcrteSetNullableFloat(json, "mean_activated_intrinsic_rho", meanActivatedIntrinsicRho); dcrteSetNullableFloat(json, "mean_new_intrinsic_rho", meanNewIntrinsicRho);
    dcrteSetNullableFloat(json, "mean_coordinate_confidence", meanCoordinateConfidence);
    json.setInt("active_component_count", activeComponentCount); json.setString("state_hash", stateHash); json.setString("event", event); return json;
  }
}

void dcrteSetNullableFloat(JSONObject json, String key, Float value) {
  if (value == null || !dcrteFinite(value.floatValue())) json.setString(key, "unavailable");
  else json.setFloat(key, value.floatValue());
}

SchedulerHistoryEntry dcrteBuildSchedulerHistory(SchedulerContext context, PropagationState state,
    int[] newlyActivated, String event) {
  SchedulerHistoryEntry entry = new SchedulerHistoryEntry();
  CandidateVolumeSnapshot snapshot = context.snapshot;
  entry.batchIndex = state.batchIndex; entry.newlyActivated = newlyActivated == null ? 0 : newlyActivated.length;
  entry.activeCount = state.activeCount; entry.frontierCount = state.frontierCount;
  entry.remainingCandidateCount = max(0, snapshot.candidateCount - state.activeCount);
  entry.activeFraction = snapshot.candidateCount == 0 ? 0 : state.activeCount / (float)snapshot.candidateCount;
  entry.meanActivatedField = dcrteRunningMean(state.activeFieldSum, state.activeFieldSamples);
  entry.meanNewField = dcrteMeanIndices(snapshot.fieldScalar, newlyActivated);
  entry.meanActivatedSDF = dcrteRunningMean(state.activeSdfSum, state.activeSdfSamples);
  entry.meanNewSDF = dcrteMeanIndices(snapshot.signedDistance, newlyActivated);
  if (snapshot.hasIntrinsic()) {
    entry.meanActivatedIntrinsicS = dcrteRunningMean(state.activeIntrinsicSSum, state.activeIntrinsicSSamples);
    entry.meanNewIntrinsicS = dcrteMeanIndices(snapshot.intrinsicS, newlyActivated);
    entry.meanActivatedIntrinsicRho = dcrteRunningMean(state.activeIntrinsicRhoSum, state.activeIntrinsicRhoSamples);
    entry.meanNewIntrinsicRho = dcrteMeanIndices(snapshot.intrinsicRho, newlyActivated);
    entry.meanCoordinateConfidence = dcrteRunningMean(state.activeConfidenceSum, state.activeConfidenceSamples);
  }
  entry.activeComponentCount = state.activeCount == 0 ? 0
    : context.configuration.mode == SchedulerMode.IMMEDIATE ? context.candidateComponentCount
    : context.configuration.componentPolicy == SchedulerComponentPolicy.SEED_EACH_COMPONENT
      ? context.resolvedSeeds.length : 1;
  entry.stateHash = state.stateHash; entry.event = event; return entry;
}

Float dcrteRunningMean(double sum, int count) {
  return count <= 0 ? null : Float.valueOf((float)(sum / count));
}

Float dcrteMeanMask(float[] values, boolean[] mask) {
  if (values == null || mask == null || values.length != mask.length) return null;
  double sum = 0; int count = 0;
  for (int i = 0; i < values.length; i++) if (mask[i] && dcrteFinite(values[i])) { sum += values[i]; count++; }
  return count == 0 ? null : Float.valueOf((float)(sum / count));
}

Float dcrteMeanIndices(float[] values, int[] indices) {
  if (values == null || indices == null) return null;
  double sum = 0; int count = 0;
  for (int i = 0; i < indices.length; i++) { int index = indices[i]; if (index >= 0 && index < values.length && dcrteFinite(values[index])) { sum += values[index]; count++; } }
  return count == 0 ? null : Float.valueOf((float)(sum / count));
}

int dcrteMaskComponentCount(boolean[] mask, VolumeSpec spec) {
  return dcrteBooleanVolumeComponentStats(mask, spec)[0];
}
