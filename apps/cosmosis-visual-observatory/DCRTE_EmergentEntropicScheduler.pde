/* DCRTE-ET Milestone 5 state-dependent entropic activation scheduler. */

class EmergentEntropicScheduler implements FieldScheduler {
  EntropyContext entropyContext;
  BinaryOccupancyEntropy occupancyModel;
  FieldHistogramEntropy fieldModel;
  EntropyCache entropyCache;
  EntropyPolicy policy;
  EntropicPolicyState policyState = new EntropicPolicyState();
  SchedulerScoreWeights currentWeights;
  RelationalProgressTracker progress = new RelationalProgressTracker();
  EntropicStabilityDetector stability;
  EntropySummary entropySummary = new EntropySummary();
  EntropySummary fieldSummary = new EntropySummary();
  FrontierEvaluation latestEvaluation = new FrontierEvaluation();
  EntropicScoreRecord[] latestRecordByVoxel;
  EntropyCacheVerification lastCacheVerification = new EntropyCacheVerification();
  ArrayList<EntropicSchedulerHistoryEntry> entropicHistory =
    new ArrayList<EntropicSchedulerHistoryEntry>();
  ArrayList<JSONObject> scoreSamples = new ArrayList<JSONObject>();
  EntropicTerminalState terminalState = EntropicTerminalState.NONE;
  int consecutiveNoAccepted;
  String metricsPath = "";
  String scoreSamplePath = "";
  String lastPolicyTransition = "initialized";
  long cacheBuildMillis;
  long cacheVerificationMillis;

  public String getId() { return "emergent_entropic"; }
  public String getVersion() { return "1.0-m5"; }

  public boolean initialize(SchedulerContext context, PropagationState state,
      SchedulerDiagnostics diagnostics) {
    long started = millis();
    state.clear();
    diagnostics.issues.clear();
    entropicHistory.clear();
    scoreSamples.clear();
    terminalState = EntropicTerminalState.NONE;
    consecutiveNoAccepted = 0;
    lastPolicyTransition = "initialized";
    if (!validateInitialization(context, state, diagnostics)) return false;
    latestRecordByVoxel = new EntropicScoreRecord[state.active.length];

    int[] componentCount = new int[1];
    context.componentLabels = dcrteCandidateComponentLabels(context.snapshot, componentCount);
    context.candidateComponentCount = componentCount[0];
    diagnostics.candidateComponentCount = componentCount[0];
    if (context.configuration.componentPolicy == SchedulerComponentPolicy.BLOCK_MULTICOMPONENT
        && componentCount[0] > 1) {
      return failInitialization(state, diagnostics, "SCH_MULTICOMPONENT_BLOCKED",
        SchedulerStopReason.MULTICOMPONENT_BLOCKED,
        "Candidate volume has multiple connected components",
        "select seed-each-component or single-inlet policy");
    }
    SchedulerSeedMode requested = context.configuration.seedMode;
    if (context.configuration.componentPolicy == SchedulerComponentPolicy.SEED_EACH_COMPONENT)
      requested = SchedulerSeedMode.COMPONENT_SEEDS;
    context.resolvedSeeds = dcrteResolveSeedsForContext(requested, context, diagnostics);
    if (context.resolvedSeeds.length == 0 || diagnostics.hasErrors()) {
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.SEED_SELECTION_FAILED;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    for (int i = 0; i < context.resolvedSeeds.length; i++) {
      int seed = context.resolvedSeeds[i];
      if (seed < 0 || seed >= state.active.length || !context.snapshot.admitted[seed]) {
        return failInitialization(state, diagnostics,
          DCRTESchedulerCodes.ENT_OUTSIDE_DOMAIN_ACTIVATION,
          SchedulerStopReason.SEED_SELECTION_FAILED,
          "Resolved seed is outside the admitted domain",
          "choose a valid M4 seed strategy");
      }
      if (!context.snapshot.candidateSolid[seed]) {
        return failInitialization(state, diagnostics,
          DCRTESchedulerCodes.ENT_NONCANDIDATE_ACTIVATION,
          SchedulerStopReason.SEED_SELECTION_FAILED,
          "Resolved seed is not in the frozen candidate mask",
          "choose a valid M4 seed strategy");
      }
      if (!state.active[seed]) {
        state.active[seed] = true;
        state.arrivalBatch[seed] = 0;
        state.arrivalRank[seed] = state.activationRank++;
        state.activationScore[seed] = 0;
        state.activeCount++;
        dcrteAccumulateSchedulerActivation(context, state, seed);
      }
    }
    dcrteRebuildFrontier(context, state, new int[0], context.resolvedSeeds);

    entropyContext = new EntropyContext(context.snapshot,
      context.configuration.neighborhoodMode, context.configuration.entropy);
    occupancyModel = new BinaryOccupancyEntropy();
    fieldModel = new FieldHistogramEntropy();
    occupancyModel.initialize(entropyContext);
    fieldModel.initialize(entropyContext);
    if (!entropyContext.isValid() || !occupancyModel.isValid() || !fieldModel.isValid()) {
      diagnostics.error(DCRTESchedulerCodes.ENT_MODEL_NOT_INITIALIZED, "entropy",
        !occupancyModel.isValid() ? occupancyModel.validationMessage()
        : fieldModel.validationMessage(), 1, -1,
        "inspect entropy neighborhood, support, and histogram configuration");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.ENTROPY_MODEL_INVALID;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    long cacheStarted = millis();
    entropyCache = new EntropyCache(entropyContext, occupancyModel, fieldModel);
    entropyContext.cache = entropyCache;
    entropyCache.build(state);
    cacheBuildMillis = millis() - cacheStarted;
    entropySummary = occupancyModel.summarize(state);
    fieldSummary = fieldModel.summarize(state);
    policy = dcrteEntropyPolicy(context.configuration.entropy.policyMode);
    policyState.initialize(context.configuration.entropy);
    progress.initialize(context.configuration.entropy.relationalProgress);
    stability = new EntropicStabilityDetector(context.configuration.entropy.stability);
    currentWeights = currentPolicyWeights(context, state);
    if (currentWeights == null || !currentWeights.valid) {
      diagnostics.error(DCRTESchedulerCodes.ENT_SCORE_WEIGHT_INVALID, "score",
        currentWeights == null ? "score weights unavailable" : currentWeights.validation,
        1, -1, "select a valid entropic policy");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.SCORE_CONFIGURATION_INVALID;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    if (state.activeCount == context.snapshot.candidateCount) {
      state.runState = SchedulerRunState.COMPLETE;
      state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE;
      terminalState = EntropicTerminalState.COMPLETE_ALL_REACHABLE;
      progress.finalizeProgress();
    } else {
      state.runState = SchedulerRunState.READY;
      state.stopReason = SchedulerStopReason.NONE;
    }
    state.stateHash = entropicStateHash(context, state);
    diagnostics.initializationMillis = millis() - started;
    dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
    recordHistory(context, state, context.resolvedSeeds, latestEvaluation,
      "initialize", "initialized", 0);
    return true;
  }

  boolean validateInitialization(SchedulerContext context, PropagationState state,
      SchedulerDiagnostics diagnostics) {
    if (context == null || context.snapshot == null) {
      diagnostics.error(DCRTESchedulerCodes.CANDIDATE_SNAPSHOT_INVALID,
        "initialize", "Candidate snapshot is unavailable", 0, -1,
        "regenerate field candidate volume");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.INVALID_DOMAIN;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    if (!context.isValid() || context.snapshot.candidateCount == 0) {
      diagnostics.error(DCRTESchedulerCodes.DOMAIN_INVALID, "initialize",
        context.snapshot.validationMessage, 0, -1,
        "regenerate the qualified candidate volume");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.INVALID_DOMAIN;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    if (context.configuration.entropy == null
        || !context.configuration.entropy.isValid()) {
      diagnostics.error(DCRTESchedulerCodes.ENT_MODEL_CONFIGURATION_INVALID,
        "entropy", "Entropy configuration is invalid", 1, -1,
        "review entropy, acceptance, relational-progress, and stability settings");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.ENTROPY_MODEL_INVALID;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      return false;
    }
    return true;
  }

  boolean failInitialization(PropagationState state, SchedulerDiagnostics diagnostics,
      String code, SchedulerStopReason reason, String message, String action) {
    diagnostics.error(code, "initialize", message, 1, -1, action);
    state.runState = SchedulerRunState.FAILED;
    state.stopReason = reason;
    terminalState = EntropicTerminalState.VALIDATION_FAILURE;
    return false;
  }

  public SchedulerBatch step(SchedulerContext context, PropagationState state,
      SchedulerDiagnostics diagnostics) {
    SchedulerBatch empty = new SchedulerBatch();
    long started = millis();
    if (context == null || state == null || entropyContext == null
        || state.runState == SchedulerRunState.INVALIDATED
        || state.runState == SchedulerRunState.FAILED) {
      diagnostics.error(DCRTESchedulerCodes.NOT_INITIALIZED, "step",
        "Entropic scheduler cannot step in its current state", 0, -1,
        "initialize the scheduler");
      empty.event = "blocked";
      return empty;
    }
    if (state.runState == SchedulerRunState.COMPLETE
        || state.runState == SchedulerRunState.STOPPED) {
      empty.event = "no_op";
      return empty;
    }
    if (state.batchIndex >= context.configuration.maximumBatches) {
      terminalState = EntropicTerminalState.MAX_BATCHES;
      state.runState = SchedulerRunState.STOPPED;
      state.stopReason = SchedulerStopReason.MAX_BATCHES_REACHED;
      progress.finalizeProgress();
      empty.event = "max_batches";
      return empty;
    }
    if (state.frontierCount == 0) {
      finishEmptyFrontier(context, state, diagnostics);
      empty.event = "frontier_empty";
      return empty;
    }

    int frontierBefore = state.frontierCount;
    int[] preBatchFrontier = java.util.Arrays.copyOf(state.frontierIndices,
      state.frontierCount);
    java.util.Arrays.sort(preBatchFrontier);
    currentWeights = currentPolicyWeights(context, state);
    if (currentWeights == null || !currentWeights.valid) {
      failRun(state, diagnostics, DCRTESchedulerCodes.ENT_SCORE_WEIGHT_INVALID,
        SchedulerStopReason.SCORE_CONFIGURATION_INVALID,
        "Entropic score weights are invalid");
      empty.event = "invalid_weights";
      return empty;
    }
    int nextBatch = state.batchIndex + 1;
    latestEvaluation = evaluateFrontier(preBatchFrontier, context, state,
      currentWeights, nextBatch, diagnostics);
    if (diagnostics.hasErrors()) {
      failRun(state, diagnostics, DCRTESchedulerCodes.ENT_SCORE_NONFINITE,
        SchedulerStopReason.SCORE_NONFINITE,
        "One or more entropic score terms were nonfinite");
      empty.event = "score_failure";
      return empty;
    }
    float temperature = context.configuration.entropy.policyMode
      == EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE
      ? policyState.currentTemperature
      : context.configuration.entropy.acceptanceTemperature;
    SchedulerAcceptancePolicy acceptance = new ConfiguredEntropicAcceptance(
      context.configuration.entropy.acceptanceMode, temperature);
    SchedulerBatch batch = acceptance.select(latestEvaluation,
      context.configuration, nextBatch);
    state.batchIndex = nextBatch;
    state.attemptedUpdates += batch.attemptedUpdates;
    int[] accepted = commitBatch(batch, context, state, diagnostics);
    batch.activatedIndices = accepted;
    batch.acceptedUpdates = accepted.length;
    state.acceptedUpdates += accepted.length;
    batch.event = "entropic_" + context.configuration.entropy.policyMode.id()
      + "_" + context.configuration.entropy.acceptanceMode.id();
    if (diagnostics.hasErrors()) {
      failRun(state, diagnostics, DCRTESchedulerCodes.ENT_NONCANDIDATE_ACTIVATION,
        SchedulerStopReason.INTERNAL_ERROR,
        "Entropic commit violated frozen domain or candidate gates");
      return batch;
    }

    int[] retained = dcrteRetainedFrontier(preBatchFrontier, state);
    dcrteRebuildFrontier(context, state, retained, accepted);
    entropyCache.updateAffected(batch, state);
    EntropySummary previous = entropySummary;
    entropySummary = occupancyModel.summarize(state);
    entropySummary.totalEntropyChangeFromPrevious =
      entropySummary.meanLocalEntropy - previous.meanLocalEntropy;
    entropySummary.meanAbsoluteLocalChange =
      latestEvaluation.meanAbsoluteAcceptedDeltaEntropy;
    RelationalProgressIncrement increment = progress.update(accepted.length,
      context.snapshot.candidateCount,
      latestEvaluation.meanAbsoluteAcceptedDeltaEntropy,
      frontierBefore, state.frontierCount);
    if (!progress.isValid() || !Double.isFinite(increment.deltaTau)) {
      failRun(state, diagnostics, DCRTESchedulerCodes.ENT_TAU_NONFINITE,
        SchedulerStopReason.RELATIONAL_PROGRESS_NONFINITE,
        "Relational progress became nonfinite");
      return batch;
    }
    lastPolicyTransition = context.configuration.entropy.policyMode
      == EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE
      ? policyState.updateAfterBatch(accepted.length, state.frontierCount,
        context.configuration.entropy)
      : "none";
    if (accepted.length == 0) consecutiveNoAccepted++;
    else consecutiveNoAccepted = 0;
    stability.update(state.batchIndex, accepted.length,
      context.snapshot.candidateCount,
      latestEvaluation.meanAbsoluteAcceptedDeltaEntropy,
      frontierBefore, state.frontierCount, latestEvaluation.maximumScore,
      context.configuration.entropy.scoreThreshold);

    boolean verifyNow = state.batchIndex
      % context.configuration.entropy.verificationInterval == 0;
    if (state.activeCount == context.snapshot.candidateCount
        || state.frontierCount == 0 || stability.isStable()) verifyNow = true;
    int deterministicStallLimit = max(
      context.configuration.entropy.stability.minimumBatches,
      context.configuration.entropy.stability.observationWindow
        * context.configuration.entropy.stability.requiredStableWindows);
    if (accepted.length == 0
        && context.configuration.entropy.policyMode
          != EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE
        && consecutiveNoAccepted >= deterministicStallLimit) verifyNow = true;
    if (verifyNow && !verifyCache(state, diagnostics)) {
      batch.event = "entropy_cache_failure";
      return batch;
    }

    if (state.activeCount == context.snapshot.candidateCount) {
      state.runState = SchedulerRunState.COMPLETE;
      state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE;
      terminalState = EntropicTerminalState.COMPLETE_ALL_REACHABLE;
      progress.finalizeProgress();
    } else if (state.frontierCount == 0) {
      finishEmptyFrontier(context, state, diagnostics);
    } else if (stability.isStable()
        && context.configuration.entropy.stability.allowStablePartial
        && (!context.configuration.entropy.stability.requireFrontierNonemptyForPartial
          || state.frontierCount > 0)) {
      state.runState = SchedulerRunState.STOPPED;
      state.stopReason = SchedulerStopReason.ENTROPIC_STABLE_PARTIAL;
      terminalState = EntropicTerminalState.STABLE_PARTIAL_CONFIGURATION;
      diagnostics.add(DCRTESchedulerCodes.ENT_STABLE_PARTIAL_REACHED,
        SchedulerDiagnosticSeverity.INFO, "stability",
        "Stable partial recursive field configuration reached",
        state.activeCount, -1,
        "materialize or export this explicitly labeled partial state");
      progress.finalizeProgress();
    } else if (accepted.length == 0
        && context.configuration.entropy.policyMode
          != EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE
        && consecutiveNoAccepted >= deterministicStallLimit) {
      state.runState = SchedulerRunState.STOPPED;
      state.stopReason = SchedulerStopReason.THRESHOLD_STALL;
      terminalState = EntropicTerminalState.THRESHOLD_STALLED;
      progress.finalizeProgress();
    } else {
      state.runState = SchedulerRunState.PAUSED;
      state.stopReason = SchedulerStopReason.NONE;
    }
    state.stateHash = entropicStateHash(context, state);
    batch.batchIndex = state.batchIndex;
    batch.frontierCount = state.frontierCount;
    batch.stateHash = state.stateHash;
    captureScoreSamples(context, latestEvaluation);
    recordHistory(context, state, accepted, latestEvaluation, batch.event,
      lastPolicyTransition, increment.deltaTau);
    diagnostics.schedulerComputeMillis += millis() - started;
    dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
    return batch;
  }

  SchedulerScoreWeights currentPolicyWeights(SchedulerContext context,
      PropagationState state) {
    EntropicPolicyContext policyContext = new EntropicPolicyContext();
    policyContext.config = context.configuration.entropy;
    policyContext.state = policyState;
    policyContext.batchIndex = state.batchIndex;
    policyContext.frontierCount = state.frontierCount;
    return policy.weightsFor(policyContext);
  }

  FrontierEvaluation evaluateFrontier(int[] frontier, SchedulerContext context,
      PropagationState state, SchedulerScoreWeights weights, int batchIndex,
      SchedulerDiagnostics diagnostics) {
    if (latestEvaluation != null && latestEvaluation.records != null
        && latestRecordByVoxel != null) {
      for (int i = 0; i < latestEvaluation.records.length; i++) {
        EntropicScoreRecord previousRecord = latestEvaluation.records[i];
        if (previousRecord != null && previousRecord.voxelIndex >= 0
            && previousRecord.voxelIndex < latestRecordByVoxel.length)
          latestRecordByVoxel[previousRecord.voxelIndex] = null;
      }
    }
    FrontierEvaluation evaluation = new FrontierEvaluation();
    evaluation.records = new EntropicScoreRecord[frontier.length];
    HBEScoreBatchContext hbeBatch = new HBEScoreBatchContext(context, state);
    for (int i = 0; i < frontier.length; i++) {
      int voxelIndex = frontier[i];
      EntropicScoreRecord scoreRecord = new EntropicScoreRecord();
      scoreRecord.batchIndex = batchIndex;
      scoreRecord.voxelIndex = voxelIndex;
      scoreRecord.weights = weights.copy();
      scoreRecord.occupancyDelta = occupancyModel.evaluateActivation(voxelIndex, state);
      scoreRecord.terms = dcrteEntropicScoreTerms(voxelIndex, scoreRecord.occupancyDelta,
        entropyContext, state, weights, batchIndex,
        context.configuration.entropy.schedulerSeed, hbeBatch);
      if (!scoreRecord.occupancyDelta.valid || !scoreRecord.terms.valid) {
        diagnostics.error(!scoreRecord.occupancyDelta.valid
          ? DCRTESchedulerCodes.ENT_DELTA_NONFINITE
          : DCRTESchedulerCodes.ENT_SCORE_NONFINITE,
          "score", "Invalid entropy delta or score terms", 1, voxelIndex,
          "inspect entropy support and score configuration");
      }
      evaluation.records[i] = scoreRecord;
      if (latestRecordByVoxel != null) latestRecordByVoxel[voxelIndex] = scoreRecord;
    }
    evaluation.summarizeAccepted();
    return evaluation;
  }

  EntropicScoreRecord latestRecordAt(int voxelIndex) {
    return latestRecordByVoxel == null || voxelIndex < 0
      || voxelIndex >= latestRecordByVoxel.length
      ? null : latestRecordByVoxel[voxelIndex];
  }

  int[] commitBatch(SchedulerBatch batch, SchedulerContext context,
      PropagationState state, SchedulerDiagnostics diagnostics) {
    int[] committed = new int[batch.activatedIndices.length];
    int count = 0;
    for (int i = 0; i < batch.activatedIndices.length; i++) {
      int index = batch.activatedIndices[i];
      if (index < 0 || index >= state.active.length
          || !context.snapshot.admitted[index]) {
        diagnostics.error(DCRTESchedulerCodes.ENT_OUTSIDE_DOMAIN_ACTIVATION,
          "commit", "Accepted voxel is outside the admitted domain", 1,
          index, "invalidate the entropic run");
        continue;
      }
      if (!context.snapshot.candidateSolid[index]) {
        diagnostics.error(DCRTESchedulerCodes.ENT_NONCANDIDATE_ACTIVATION,
          "commit", "Accepted voxel is outside the frozen candidate mask", 1,
          index, "invalidate the entropic run");
        continue;
      }
      if (state.active[index]) continue;
      state.active[index] = true;
      state.frontier[index] = false;
      state.queued[index] = false;
      state.arrivalBatch[index] = state.batchIndex;
      state.arrivalRank[index] = state.activationRank++;
      state.activationScore[index] = dcrteEntropicScoreForIndex(
        latestEvaluation, index);
      state.activeCount++;
      dcrteAccumulateSchedulerActivation(context, state, index);
      committed[count++] = index;
    }
    return java.util.Arrays.copyOf(committed, count);
  }

  float dcrteEntropicScoreForIndex(FrontierEvaluation evaluation, int index) {
    if (evaluation == null || evaluation.records == null) return 0;
    for (int i = 0; i < evaluation.records.length; i++)
      if (evaluation.records[i].voxelIndex == index)
        return evaluation.records[i].terms.combinedScore;
    return 0;
  }

  int[] dcrteRetainedFrontier(int[] preBatchFrontier, PropagationState state) {
    int[] retained = new int[preBatchFrontier.length];
    int count = 0;
    for (int i = 0; i < preBatchFrontier.length; i++) {
      int index = preBatchFrontier[i];
      if (!state.active[index]) retained[count++] = index;
    }
    return java.util.Arrays.copyOf(retained, count);
  }

  boolean verifyCache(PropagationState state, SchedulerDiagnostics diagnostics) {
    long started = millis();
    lastCacheVerification = entropyCache.verifyAgainstFullRecompute(state,
      0.000001f);
    cacheVerificationMillis += millis() - started;
    if (!lastCacheVerification.pass) {
      diagnostics.error(DCRTESchedulerCodes.ENT_CACHE_MISMATCH, "entropy_cache",
        "Incremental entropy cache diverged from full recomputation",
        lastCacheVerification.occupancyMismatchCount, -1,
        "stop and inspect affected-center cache updates");
      state.runState = SchedulerRunState.FAILED;
      state.stopReason = SchedulerStopReason.ENTROPY_CACHE_DIVERGENCE;
      terminalState = EntropicTerminalState.VALIDATION_FAILURE;
      progress.finalizeProgress();
      return false;
    }
    return true;
  }

  void finishEmptyFrontier(SchedulerContext context, PropagationState state,
      SchedulerDiagnostics diagnostics) {
    int unreachable = state.unreachableCount(context.snapshot);
    if (unreachable == 0) {
      state.runState = SchedulerRunState.COMPLETE;
      state.stopReason = SchedulerStopReason.ALL_CANDIDATES_ACTIVE;
      terminalState = EntropicTerminalState.COMPLETE_ALL_REACHABLE;
    } else {
      state.runState = SchedulerRunState.STOPPED;
      state.stopReason = SchedulerStopReason.UNREACHABLE_CANDIDATES;
      terminalState = EntropicTerminalState.FRONTIER_EXHAUSTED;
      diagnostics.warn(DCRTESchedulerCodes.FRONTIER_EMPTY, "reachability",
        "Entropic frontier exhausted before all frozen candidates were reached",
        unreachable, -1,
        "inspect component policy and candidate connectivity");
    }
    progress.finalizeProgress();
    state.stateHash = entropicStateHash(context, state);
  }

  void failRun(PropagationState state, SchedulerDiagnostics diagnostics,
      String code, SchedulerStopReason reason, String message) {
    if (!diagnostics.hasErrors()) diagnostics.error(code, "entropic_scheduler",
      message, 1, -1, "inspect the exported entropic run report");
    state.runState = SchedulerRunState.FAILED;
    state.stopReason = reason;
    terminalState = EntropicTerminalState.VALIDATION_FAILURE;
    progress.finalizeProgress();
  }

  void recordHistory(SchedulerContext context, PropagationState state,
      int[] newlyActivated, FrontierEvaluation evaluation, String event,
      String transition, double deltaTau) {
    EntropicSchedulerHistoryEntry entry = new EntropicSchedulerHistoryEntry();
    entry.base = dcrteBuildSchedulerHistory(context, state,
      newlyActivated == null ? new int[0] : newlyActivated, event);
    entry.meanOccupancyEntropy = entropySummary.meanLocalEntropy;
    entry.frontierOccupancyEntropy = entropySummary.frontierMeanEntropy;
    entry.meanFieldEntropy = fieldSummary.meanLocalEntropy;
    entry.meanAcceptedDeltaEntropy = evaluation == null
      ? 0 : evaluation.meanAcceptedDeltaEntropy;
    entry.meanAbsoluteAcceptedDeltaEntropy = evaluation == null
      ? 0 : evaluation.meanAbsoluteAcceptedDeltaEntropy;
    entry.meanFrontierScore = evaluation == null ? 0 : evaluation.meanScore;
    entry.maxFrontierScore = evaluation == null ? 0 : evaluation.maximumScore;
    entry.meanAcceptedScore = evaluation == null ? 0 : evaluation.meanAcceptedScore;
    entry.minAcceptedScore = evaluation == null ? 0 : evaluation.minimumAcceptedScore;
    entry.evaluatedFrontierCount = evaluation == null ? 0 : evaluation.evaluatedCount;
    entry.thresholdEligibleCount = evaluation == null
      ? 0 : evaluation.thresholdEligibleCount;
    entry.stochasticAcceptedCount = evaluation == null
      ? 0 : evaluation.stochasticAcceptedCount;
    entry.acceptanceTemperature = policyState.currentTemperature;
    entry.scoreThreshold = context.configuration.entropy.scoreThreshold;
    entry.policyMode = context.configuration.entropy.policyMode.id();
    entry.acceptanceMode = context.configuration.entropy.acceptanceMode.id();
    entry.policyTransition = transition;
    entry.deltaTau = deltaTau;
    entry.tauRaw = progress.tauRaw;
    entry.stableWindow = stability != null && stability.state.lastWindowStable;
    entry.consecutiveStableWindows = stability == null
      ? 0 : stability.state.consecutiveStableWindows;
    entry.stopReason = state.stopReason.id();
    entry.stateHash = state.stateHash;
    entropicHistory.add(entry);
  }

  void captureScoreSamples(SchedulerContext context, FrontierEvaluation evaluation) {
    if (evaluation == null || evaluation.records == null
        || context.configuration.entropy.scoreExportMode == ScoreExportMode.NONE)
      return;
    int[] order = new int[evaluation.records.length];
    for (int i = 0; i < order.length; i++) order[i] = i;
    dcrteSortEntropicScoreOrder(order, evaluation.records);
    int limit = context.configuration.entropy.scoreExportMode
      == ScoreExportMode.FULL_DEBUG ? order.length
      : context.configuration.entropy.scoreExportMode == ScoreExportMode.ACCEPTED_ONLY
        ? order.length : min(context.configuration.entropy.scoreExportK, order.length);
    int saved = 0;
    for (int rank = 0; rank < order.length && saved < limit; rank++) {
      EntropicScoreRecord scoreRecord = evaluation.records[order[rank]];
      if (context.configuration.entropy.scoreExportMode
          == ScoreExportMode.ACCEPTED_ONLY && !scoreRecord.accepted) continue;
      scoreSamples.add(scoreRecord.toJSON(context.snapshot));
      saved++;
    }
  }

  String entropicStateHash(SchedulerContext context, PropagationState state) {
    if (context == null || state == null) return "";
    try {
      java.security.MessageDigest digest =
        java.security.MessageDigest.getInstance("SHA-256");
      dcrteDigestString(digest, context.snapshot.contentHash);
      dcrteDigestString(digest, getId());
      dcrteDigestString(digest, getVersion());
      dcrteDigestString(digest, context.configuration.canonical());
      if (context.hasHbeSchedulerChannel())
        dcrteDigestString(digest, context.hbeSnapshot.contentHash);
      dcrteDigestString(digest, occupancyModel == null ? "" : occupancyModel.getId()
        + "@" + occupancyModel.getVersion());
      dcrteDigestString(digest, fieldModel == null ? "" : fieldModel.getId()
        + "@" + fieldModel.getVersion());
      dcrteDigestString(digest, currentWeights == null ? ""
        : currentWeights.toJSON().toString());
      dcrteDigestString(digest, policyState.toJSON().toString());
      dcrteDigestString(digest, "m5-mix64-1");
      dcrteDigestString(digest, entropyCache == null ? "" : entropyCache.cacheHash);
      dcrteDigestString(digest, Double.toString(progress.tauRaw));
      dcrteDigestString(digest, terminalState.id());
      dcrteDigestInt(digest, state.batchIndex);
      for (int i = 0; i < state.arrivalBatch.length; i++)
        dcrteDigestInt(digest, state.arrivalBatch[i]);
      return dcrteHex(digest.digest());
    } catch (Exception error) {
      return "sha256-error";
    }
  }

  void exportEntropicMetrics(String runDir) {
    if (entropicHistory.size() == 0) return;
    ensureDir(sketchPath(runDir));
    metricsPath = runDir + "/entropic_metrics.csv";
    PrintWriter out = createWriter(metricsPath);
    out.println("batch_index,newly_activated,active_count,frontier_count,remaining_candidates,active_fraction,mean_occupancy_entropy,frontier_occupancy_entropy,mean_field_entropy,mean_accepted_delta_entropy,mean_absolute_accepted_delta_entropy,mean_frontier_score,max_frontier_score,mean_accepted_score,min_accepted_score,evaluated_frontier_count,threshold_eligible_count,stochastic_accepted_count,policy_mode,acceptance_mode,acceptance_temperature,score_threshold,policy_transition,delta_tau,tau_raw,stable_window,consecutive_stable_windows,stop_reason,state_hash");
    for (int i = 0; i < entropicHistory.size(); i++) {
      EntropicSchedulerHistoryEntry e = entropicHistory.get(i);
      SchedulerHistoryEntry b = e.base;
      boolean frontierScoresAvailable = e.evaluatedFrontierCount > 0;
      boolean acceptedScoresAvailable = frontierScoresAvailable
        && b.newlyActivated > 0;
      out.println(b.batchIndex + "," + b.newlyActivated + "," + b.activeCount
        + "," + b.frontierCount + "," + b.remainingCandidateCount + ","
        + b.activeFraction + "," + dcrteCsvFloat(e.meanOccupancyEntropy)
        + "," + dcrteCsvFloat(e.frontierOccupancyEntropy) + ","
        + dcrteCsvFloat(e.meanFieldEntropy) + ","
        + dcrteCsvAvailableFloat(e.meanAcceptedDeltaEntropy,
          acceptedScoresAvailable) + ","
        + dcrteCsvAvailableFloat(e.meanAbsoluteAcceptedDeltaEntropy,
          acceptedScoresAvailable) + ","
        + dcrteCsvAvailableFloat(e.meanFrontierScore,
          frontierScoresAvailable) + ","
        + dcrteCsvAvailableFloat(e.maxFrontierScore,
          frontierScoresAvailable) + ","
        + dcrteCsvAvailableFloat(e.meanAcceptedScore,
          acceptedScoresAvailable) + ","
        + dcrteCsvAvailableFloat(e.minAcceptedScore,
          acceptedScoresAvailable) + ","
        + e.evaluatedFrontierCount + "," + e.thresholdEligibleCount + ","
        + e.stochasticAcceptedCount + "," + e.policyMode + ","
        + e.acceptanceMode + "," + dcrteCsvFloat(e.acceptanceTemperature)
        + "," + dcrteCsvFloat(e.scoreThreshold) + "," + e.policyTransition
        + "," + e.deltaTau + "," + e.tauRaw + "," + e.stableWindow + ","
        + e.consecutiveStableWindows + "," + e.stopReason + "," + e.stateHash);
    }
    out.flush();
    out.close();
  }

  void exportScoreSamples(String runDir) {
    if (scoreSamples.size() == 0) return;
    ensureDir(sketchPath(runDir));
    JSONArray records = new JSONArray();
    for (int i = 0; i < scoreSamples.size(); i++)
      records.setJSONObject(i, scoreSamples.get(i));
    JSONObject root = new JSONObject();
    root.setString("formula_version", "m5-score-1");
    root.setString("random_version", "m5-mix64-1");
    root.setString("export_mode", entropyContext.config.scoreExportMode.id());
    root.setJSONArray("records", records);
    scoreSamplePath = runDir + "/entropic_score_samples.json";
    saveJSONObject(root, scoreSamplePath);
  }

  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setBoolean("deterministic_for_fixed_configuration_and_seed", true);
    json.setString("clock_claim", "none");
    json.setString("progress_interpretation",
      "dimensionless computational relational progress");
    json.setString("terminal_state", terminalState.id());
    if (entropyContext != null) json.setJSONObject("entropy_context",
      entropyContext.toJSON());
    if (occupancyModel != null) json.setJSONObject("dynamic_entropy_model",
      occupancyModel.toJSON());
    if (fieldModel != null) json.setJSONObject("static_field_entropy_model",
      fieldModel.toJSON());
    if (entropyCache != null) json.setJSONObject("entropy_cache",
      entropyCache.toJSON());
    json.setJSONObject("cache_verification", lastCacheVerification.toJSON());
    if (currentWeights != null) json.setJSONObject("score_weights",
      currentWeights.toJSON());
    if (policy != null) json.setJSONObject("policy", policy.toJSON());
    json.setJSONObject("policy_state", policyState.toJSON());
    json.setJSONObject("relational_progress", progress.toJSON());
    if (stability != null) json.setJSONObject("stability", stability.toJSON());
    json.setJSONObject("entropy_summary", entropySummary.toJSON());
    json.setJSONObject("field_entropy_summary", fieldSummary.toJSON());
    json.setString("cache_build_millis_diagnostic_only",
      Long.toString(cacheBuildMillis));
    json.setString("cache_verification_millis_diagnostic_only",
      Long.toString(cacheVerificationMillis));
    json.setString("metrics_csv", metricsPath);
    json.setString("score_sample_json", scoreSamplePath);
    JSONArray history = new JSONArray();
    for (int i = 0; i < entropicHistory.size(); i++)
      history.setJSONObject(i, entropicHistory.get(i).toJSON());
    json.setJSONArray("entropic_history", history);
    return json;
  }
}

String dcrteCsvAvailableFloat(float value, boolean available) {
  return available ? dcrteCsvFloat(value) : "";
}
