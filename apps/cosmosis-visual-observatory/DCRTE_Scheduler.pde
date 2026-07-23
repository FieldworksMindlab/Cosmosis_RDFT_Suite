/* DCRTE-ET Milestone 1 immediate, render-cadence-independent activation. */

class ImmediateScheduler implements FieldScheduler {
  String getId() { return "immediate"; }
  String getVersion() { return "1.0-m4"; }
  boolean activate(boolean admitted, boolean candidateSolid) {
    return admitted && candidateSolid;
  }

  public boolean initialize(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
    long started = millis();
    state.clear(); diagnostics.issues.clear();
    if (context == null || context.snapshot == null) {
      diagnostics.error(DCRTESchedulerCodes.CANDIDATE_SNAPSHOT_INVALID, "initialize", "Candidate snapshot is unavailable", 0, -1, "regenerate field candidate volume");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN;
      return false;
    }
    if (context.snapshot.candidateCount == 0) {
      diagnostics.error(DCRTESchedulerCodes.NO_CANDIDATES, "initialize", "Candidate snapshot contains no admitted candidate voxels", 0, -1, "adjust the field threshold or observation domain");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN;
      return false;
    }
    if (!context.isValid()) {
      diagnostics.error(DCRTESchedulerCodes.DOMAIN_INVALID, "initialize", context.snapshot.validationMessage, 0, -1, "regenerate the qualified candidate volume");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN;
      return false;
    }
    int[] components = new int[1];
    context.componentLabels = dcrteCandidateComponentLabels(context.snapshot, components);
    context.candidateComponentCount = components[0];
    context.resolvedSeeds = new int[0];
    for (int i = 0; i < state.active.length; i++) if (context.snapshot.candidateSolid[i]) {
      state.active[i] = true; state.arrivalBatch[i] = 0; state.arrivalRank[i] = state.activationRank++;
      state.activationScore[i] = 0; state.activeCount++; dcrteAccumulateSchedulerActivation(context, state, i);
    }
    state.runState = SchedulerRunState.COMPLETE;
    state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE;
    state.stateHash = dcrteSchedulerStateHash(context, state, getId(), getVersion());
    diagnostics.initializationMillis = millis() - started;
    dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
    return true;
  }

  public SchedulerBatch step(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
    SchedulerBatch batch = new SchedulerBatch();
    batch.batchIndex = state == null ? 0 : state.batchIndex;
    batch.event = "immediate_complete";
    batch.stateHash = state == null ? "" : state.stateHash;
    return batch;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setBoolean("stateful", false);
    json.setBoolean("deterministic", true);
    json.setString("arrival_convention", "all_candidates_batch_zero");
    json.setString("relational_progress", "not_applicable");
    return json;
  }
}

ImmediateScheduler dcrteImmediateScheduler = new ImmediateScheduler();
