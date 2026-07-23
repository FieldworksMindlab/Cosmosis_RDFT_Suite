/* DCRTE-ET Milestone 4 deterministic frontier ordering and propagation. */

class FrontPropagationScheduler implements FieldScheduler {
  public String getId() { return "front_propagation"; }
  public String getVersion() { return "1.0-m4"; }

  public boolean initialize(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
    long started = millis(); state.clear(); diagnostics.issues.clear();
    if (context == null || context.snapshot == null) {
      diagnostics.error(DCRTESchedulerCodes.CANDIDATE_SNAPSHOT_INVALID, "initialize", "Candidate snapshot is unavailable", 0, -1, "regenerate field candidate volume");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN; return false;
    }
    if (context.snapshot.candidateCount == 0) {
      diagnostics.error(DCRTESchedulerCodes.NO_CANDIDATES, "initialize", "Candidate snapshot contains no admitted candidate voxels", 0, -1, "adjust the field threshold or observation domain");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN; return false;
    }
    if (!context.isValid()) {
      diagnostics.error(DCRTESchedulerCodes.DOMAIN_INVALID, "initialize", context.snapshot.validationMessage, 0, -1, "regenerate the qualified candidate volume");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INVALID_DOMAIN; return false;
    }
    int[] componentCount = new int[1];
    context.componentLabels = dcrteCandidateComponentLabels(context.snapshot, componentCount);
    context.candidateComponentCount = componentCount[0];
    diagnostics.candidateComponentCount = componentCount[0];
    if (context.configuration.componentPolicy == SchedulerComponentPolicy.BLOCK_MULTICOMPONENT && componentCount[0] > 1) {
      diagnostics.error("SCH_MULTICOMPONENT_BLOCKED", "initialize", "Candidate volume has multiple connected components", componentCount[0], -1, "select seed-each-component or single-inlet policy");
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.MULTICOMPONENT_BLOCKED; return false;
    }
    SchedulerSeedMode requested = context.configuration.seedMode;
    if (context.configuration.componentPolicy == SchedulerComponentPolicy.SEED_EACH_COMPONENT) requested = SchedulerSeedMode.COMPONENT_SEEDS;
    context.resolvedSeeds = dcrteResolveSeedsForContext(requested, context, diagnostics);
    if (context.resolvedSeeds.length == 0 || diagnostics.hasErrors()) {
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.SEED_SELECTION_FAILED; return false;
    }
    for (int i = 0; i < context.resolvedSeeds.length; i++) {
      int seed = context.resolvedSeeds[i];
      if (seed < 0 || seed >= state.active.length || !context.snapshot.admitted[seed]) {
        diagnostics.error(DCRTESchedulerCodes.SEED_OUTSIDE_DOMAIN, "initialize", "Resolved seed is outside the admitted domain", 1, seed, "choose a valid seed strategy");
        state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.SEED_SELECTION_FAILED; return false;
      }
      if (!context.snapshot.candidateSolid[seed]) {
        diagnostics.error(DCRTESchedulerCodes.SEED_NOT_CANDIDATE, "initialize", "Resolved seed is not a candidate voxel", 1, seed, "choose a valid seed strategy");
        state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.SEED_SELECTION_FAILED; return false;
      }
      if (!state.active[seed]) {
        state.active[seed] = true; state.arrivalBatch[seed] = 0; state.arrivalRank[seed] = state.activationRank++;
        state.activationScore[seed] = 0; state.activeCount++; dcrteAccumulateSchedulerActivation(context, state, seed);
      }
    }
    dcrteRebuildFrontier(context, state, new int[0], context.resolvedSeeds);
    state.runState = state.activeCount == context.snapshot.candidateCount ? SchedulerRunState.COMPLETE : SchedulerRunState.READY;
    state.stopReason = state.runState == SchedulerRunState.COMPLETE ? SchedulerStopReason.ALL_CANDIDATES_ACTIVE : SchedulerStopReason.NONE;
    state.stateHash = dcrteSchedulerStateHash(context, state, getId(), getVersion());
    diagnostics.initializationMillis = millis() - started;
    dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
    return true;
  }

  public SchedulerBatch step(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
    SchedulerBatch batch = new SchedulerBatch();
    long started = millis();
    if (context == null || state == null || state.runState == SchedulerRunState.INVALIDATED || state.runState == SchedulerRunState.FAILED) {
      diagnostics.error("SCH_NOT_INITIALIZED", "step", "Scheduler cannot step in its current state", 0, -1, "initialize scheduler");
      batch.event = "blocked"; return batch;
    }
    if (state.runState == SchedulerRunState.COMPLETE || state.runState == SchedulerRunState.STOPPED) { batch.event = "no_op"; return batch; }
    if (state.batchIndex >= context.configuration.maximumBatches) {
      state.runState = SchedulerRunState.STOPPED; state.stopReason = SchedulerStopReason.MAX_BATCHES_REACHED;
      diagnostics.warn("SCH_MAX_BATCHES_REACHED", "step", "Maximum batch count reached", state.batchIndex, -1, "increase maximum batches or inspect reachability");
      return batch;
    }
    if (state.frontierCount == 0) {
      dcrteFinishEmptyFrontier(context, state, diagnostics); batch.event = "frontier_empty"; return batch;
    }
    int limit = context.configuration.maxUpdatesPerBatch <= 0
      ? state.frontierCount : min(context.configuration.maxUpdatesPerBatch, state.frontierCount);
    int[] selected = java.util.Arrays.copyOf(state.frontierIndices, limit);
    dcrteSortFrontier(selected, context);
    int[] accepted = new int[limit]; int acceptedCount = 0;
    state.batchIndex++;
    for (int i = 0; i < selected.length; i++) {
      int index = selected[i]; state.attemptedUpdates++; batch.attemptedUpdates++;
      if (index < 0 || index >= state.active.length || !context.snapshot.admitted[index]) {
        diagnostics.error("SCH_OUTSIDE_DOMAIN_ACTIVATION", "commit", "Frontier contains an outside-domain voxel", 1, index, "invalidate scheduler and rebuild snapshot"); continue;
      }
      if (!context.snapshot.candidateSolid[index]) {
        diagnostics.error("SCH_NONCANDIDATE_ACTIVATION", "commit", "Frontier contains a noncandidate voxel", 1, index, "invalidate scheduler and rebuild snapshot"); continue;
      }
      if (state.active[index]) {
        diagnostics.error("SCH_DUPLICATE_ACTIVATION", "commit", "Voxel activation was attempted twice", 1, index, "inspect frontier queue invariants"); continue;
      }
      state.active[index] = true; state.frontier[index] = false; state.queued[index] = false;
      state.arrivalBatch[index] = state.batchIndex; state.arrivalRank[index] = state.activationRank++;
      state.activationScore[index] = dcrteFrontierScore(index, context); state.activeCount++;
      dcrteAccumulateSchedulerActivation(context, state, index);
      state.acceptedUpdates++; batch.acceptedUpdates++; accepted[acceptedCount++] = index;
    }
    batch.activatedIndices = java.util.Arrays.copyOf(accepted, acceptedCount);
    if (diagnostics.hasErrors()) {
      state.runState = SchedulerRunState.FAILED; state.stopReason = SchedulerStopReason.INTERNAL_ERROR;
    } else {
      int remainingCount = state.frontierCount - limit;
      int[] remaining = new int[max(0, remainingCount)];
      if (remainingCount > 0) System.arraycopy(state.frontierIndices, limit, remaining, 0, remainingCount);
      dcrteRebuildFrontier(context, state, remaining, batch.activatedIndices);
      if (state.activeCount == context.snapshot.candidateCount) {
        state.runState = SchedulerRunState.COMPLETE; state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE;
      } else if (acceptedCount == 0) {
        state.runState = SchedulerRunState.STOPPED; state.stopReason = SchedulerStopReason.NO_ACCEPTED_UPDATES;
        diagnostics.warn("SCH_NO_ACCEPTED_UPDATES", "step", "Batch accepted no candidate voxels", 0, -1, "inspect candidate connectivity and scheduler diagnostics");
      } else if (state.frontierCount == 0) dcrteFinishEmptyFrontier(context, state, diagnostics);
      else state.runState = SchedulerRunState.PAUSED;
    }
    state.stateHash = dcrteSchedulerStateHash(context, state, getId(), getVersion());
    batch.batchIndex = state.batchIndex; batch.frontierCount = state.frontierCount; batch.stateHash = state.stateHash;
    diagnostics.schedulerComputeMillis += millis() - started;
    dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
    return batch;
  }

  public JSONObject toJSON() {
    JSONObject json = new JSONObject(); json.setString("type", getId()); json.setString("version", getVersion());
    json.setBoolean("deterministic", true); json.setString("batch_commit", "double_buffered");
    json.setString("physical_time_claim", "none"); return json;
  }
}

void dcrteFinishEmptyFrontier(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
  int unreachable = state.unreachableCount(context.snapshot);
  if (unreachable == 0) { state.runState = SchedulerRunState.COMPLETE; state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE; }
  else {
    diagnostics.warn(DCRTESchedulerCodes.FRONTIER_EMPTY, "reachability", "Frontier is empty before all candidates were activated", 0, -1, "inspect component policy and candidate connectivity");
    state.runState = SchedulerRunState.STOPPED; state.stopReason = SchedulerStopReason.UNREACHABLE_CANDIDATES;
    diagnostics.warn("SCH_UNREACHABLE_CANDIDATES", "reachability", "Candidate components remain unreachable from the selected inlet", unreachable, -1, "use component seeds or inspect candidate connectivity");
  }
}

void dcrteRebuildFrontier(SchedulerContext context, PropagationState state, int[] retained, int[] newlyActive) {
  java.util.Arrays.fill(state.frontier, false); java.util.Arrays.fill(state.queued, false);
  int count = 0;
  if (retained != null) for (int i = 0; i < retained.length; i++) {
    int index = retained[i];
    if (!state.active[index] && context.snapshot.candidateSolid[index] && !state.queued[index]) {
      state.queued[index] = true; state.frontier[index] = true; state.frontierIndices[count++] = index;
    }
  }
  if (newlyActive == null) newlyActive = new int[0];
  for (int a = 0; a < newlyActive.length; a++) {
    int index = newlyActive[a];
    if (index < 0 || index >= state.active.length || !state.active[index]) continue;
    VolumeSpec spec = context.snapshot.spec;
    int x = index % spec.nx;
    int yz = index / spec.nx;
    int y = yz % spec.ny;
    int z = yz / spec.ny;
    if (context.configuration.neighborhoodMode == SchedulerNeighborhoodMode.SIX_CONNECTED) {
      int plane = spec.nx * spec.ny;
      if (x > 0) count = dcrteAddFrontierNeighbor(index - 1, context, state, count);
      if (x + 1 < spec.nx) count = dcrteAddFrontierNeighbor(index + 1, context, state, count);
      if (y > 0) count = dcrteAddFrontierNeighbor(index - spec.nx, context, state, count);
      if (y + 1 < spec.ny) count = dcrteAddFrontierNeighbor(index + spec.nx, context, state, count);
      if (z > 0) count = dcrteAddFrontierNeighbor(index - plane, context, state, count);
      if (z + 1 < spec.nz) count = dcrteAddFrontierNeighbor(index + plane, context, state, count);
    } else {
      for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0 && dz == 0) continue;
        if (context.configuration.neighborhoodMode == SchedulerNeighborhoodMode.EIGHTEEN_CONNECTED
            && abs(dx) + abs(dy) + abs(dz) == 3) continue;
        int xx = x + dx, yy = y + dy, zz = z + dz;
        if (xx < 0 || yy < 0 || zz < 0 || xx >= spec.nx || yy >= spec.ny || zz >= spec.nz) continue;
        count = dcrteAddFrontierNeighbor(xx + spec.nx * (yy + spec.ny * zz), context, state, count);
      }
    }
  }
  if (count > 1) dcrteQuickSortFrontier(state.frontierIndices, 0, count - 1, context);
  state.frontierCount = count;
}

int dcrteAddFrontierNeighbor(int index, SchedulerContext context, PropagationState state, int count) {
  if (state.active[index] || !context.snapshot.candidateSolid[index] || state.queued[index]) return count;
  state.queued[index] = true;
  state.frontier[index] = true;
  state.frontierIndices[count] = index;
  return count + 1;
}

void dcrteAccumulateSchedulerActivation(SchedulerContext context, PropagationState state, int index) {
  CandidateVolumeSnapshot snapshot = context.snapshot;
  if (dcrteFinite(snapshot.fieldScalar[index])) { state.activeFieldSum += snapshot.fieldScalar[index]; state.activeFieldSamples++; }
  if (dcrteFinite(snapshot.signedDistance[index])) { state.activeSdfSum += snapshot.signedDistance[index]; state.activeSdfSamples++; }
  if (snapshot.hasIntrinsic()) {
    if (dcrteFinite(snapshot.intrinsicS[index])) { state.activeIntrinsicSSum += snapshot.intrinsicS[index]; state.activeIntrinsicSSamples++; }
    if (dcrteFinite(snapshot.intrinsicRho[index])) { state.activeIntrinsicRhoSum += snapshot.intrinsicRho[index]; state.activeIntrinsicRhoSamples++; }
    if (dcrteFinite(snapshot.intrinsicConfidence[index])) { state.activeConfidenceSum += snapshot.intrinsicConfidence[index]; state.activeConfidenceSamples++; }
  }
}

float dcrteFrontierScore(int index, SchedulerContext context) {
  if (context.configuration.priorityMode == SchedulerPriorityMode.FIELD_COMPATIBILITY) return abs(context.snapshot.fieldScalar[index]);
  return index;
}

void dcrteSortFrontier(int[] values, SchedulerContext context) {
  if (values == null || values.length < 2) return;
  dcrteQuickSortFrontier(values, 0, values.length - 1, context);
}

void dcrteQuickSortFrontier(int[] values, int low, int high, SchedulerContext context) {
  int i = low, j = high; int pivot = values[(low + high) >>> 1];
  while (i <= j) {
    while (dcrteFrontierLess(values[i], pivot, context)) i++;
    while (dcrteFrontierLess(pivot, values[j], context)) j--;
    if (i <= j) { int tmp = values[i]; values[i] = values[j]; values[j] = tmp; i++; j--; }
  }
  if (low < j) dcrteQuickSortFrontier(values, low, j, context);
  if (i < high) dcrteQuickSortFrontier(values, i, high, context);
}

boolean dcrteFrontierLess(int a, int b, SchedulerContext context) {
  float sa = dcrteFrontierScore(a, context), sb = dcrteFrontierScore(b, context);
  return sa < sb || sa == sb && a < b;
}

void dcrteUpdateSchedulerDiagnostics(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics) {
  diagnostics.runState = state.runState; diagnostics.stopReason = state.stopReason; diagnostics.batchIndex = state.batchIndex;
  diagnostics.seedCount = context.resolvedSeeds.length; diagnostics.candidateCount = context.snapshot.candidateCount;
  diagnostics.activeCount = state.activeCount; diagnostics.frontierCount = state.frontierCount;
  diagnostics.candidateComponentCount = context.candidateComponentCount;
  diagnostics.unreachableCount = state.unreachableCount(context.snapshot);
  diagnostics.attemptedUpdates = state.attemptedUpdates; diagnostics.acceptedUpdates = state.acceptedUpdates;
  diagnostics.activationProgress = context.snapshot.candidateCount == 0 ? 0 : state.activeCount / (float)context.snapshot.candidateCount;
  diagnostics.activeComponentCount = state.activeCount == 0 ? 0
    : context.configuration.mode == SchedulerMode.IMMEDIATE ? context.candidateComponentCount
    : context.configuration.componentPolicy == SchedulerComponentPolicy.SEED_EACH_COMPONENT
      ? context.resolvedSeeds.length : 1;
  diagnostics.candidateSnapshotHash = context.snapshot.contentHash; diagnostics.stateHash = state.stateHash;
}
