/* DCRTE-ET Milestone 5 entropy contracts and versioned research configuration. */

enum EntropyNeighborhoodMode {
  PROPAGATION_NEIGHBORS, CUBE_RADIUS_1, CUBE_RADIUS_2;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum HistogramRangeMode {
  GLOBAL_CANDIDATE_RANGE, FIXED_FIELD_RANGE;
  String id() { return name().toLowerCase(); }
}

enum EntropicPolicyMode {
  RELAXATION, EXPLORATION, BALANCED, ADAPTIVE_RELAX_EXPLORE;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum AcceptanceMode {
  DETERMINISTIC_THRESHOLD, DETERMINISTIC_TOP_K, SEEDED_STOCHASTIC;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum EntropicTerminalState {
  NONE, COMPLETE_ALL_REACHABLE, STABLE_PARTIAL_CONFIGURATION,
  FRONTIER_EXHAUSTED, THRESHOLD_STALLED, MAX_BATCHES,
  VALIDATION_FAILURE, USER_STOP;
  String id() { return name().toLowerCase(); }
}

enum ScoreExportMode {
  NONE, ACCEPTED_ONLY, TOP_K_PER_BATCH, FULL_DEBUG;
  String id() { return name().toLowerCase(); }
}

enum EntropyVisualizationMode {
  OCCUPANCY_ENTROPY, FIELD_ENTROPY, DELTA_ENTROPY, RELAXATION_SCORE,
  EXPLORATION_SCORE, COMBINED_SCORE, ACCEPTANCE_PROBABILITY,
  ACCEPTED_BATCH, REJECTED_FRONTIER, RELATIONAL_PROGRESS, STABILITY;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

class RelationalProgressConfiguration {
  float activationWeight = 1.0f;
  float entropyWeight = 1.0f;
  float frontierWeight = 0.25f;

  RelationalProgressConfiguration copy() {
    RelationalProgressConfiguration c = new RelationalProgressConfiguration();
    c.activationWeight = activationWeight;
    c.entropyWeight = entropyWeight;
    c.frontierWeight = frontierWeight;
    return c;
  }

  boolean isValid() {
    return dcrteFinite(activationWeight) && dcrteFinite(entropyWeight)
      && dcrteFinite(frontierWeight) && activationWeight >= 0
      && entropyWeight >= 0 && frontierWeight >= 0
      && activationWeight + entropyWeight + frontierWeight > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("formula_version", "m5-tau-1");
    json.setFloat("activation_weight", activationWeight);
    json.setFloat("entropy_weight", entropyWeight);
    json.setFloat("frontier_weight", frontierWeight);
    json.setString("units", "dimensionless_computational_progress");
    return json;
  }
}

class EntropicStabilityConfiguration {
  int minimumBatches = 20;
  int observationWindow = 8;
  float activationFractionEpsilon = 0.0001f;
  float entropyDeltaEpsilon = 0.0001f;
  float frontierChangeEpsilon = 0.0001f;
  float maximumScoreEpsilon = 0.0001f;
  int requiredStableWindows = 3;
  boolean allowStablePartial = true;
  boolean requireFrontierNonemptyForPartial = true;

  EntropicStabilityConfiguration copy() {
    EntropicStabilityConfiguration c = new EntropicStabilityConfiguration();
    c.minimumBatches = minimumBatches;
    c.observationWindow = observationWindow;
    c.activationFractionEpsilon = activationFractionEpsilon;
    c.entropyDeltaEpsilon = entropyDeltaEpsilon;
    c.frontierChangeEpsilon = frontierChangeEpsilon;
    c.maximumScoreEpsilon = maximumScoreEpsilon;
    c.requiredStableWindows = requiredStableWindows;
    c.allowStablePartial = allowStablePartial;
    c.requireFrontierNonemptyForPartial = requireFrontierNonemptyForPartial;
    return c;
  }

  boolean isValid() {
    return minimumBatches >= 0 && observationWindow > 0 && requiredStableWindows > 0
      && dcrteFinite(activationFractionEpsilon) && activationFractionEpsilon >= 0
      && dcrteFinite(entropyDeltaEpsilon) && entropyDeltaEpsilon >= 0
      && dcrteFinite(frontierChangeEpsilon) && frontierChangeEpsilon >= 0
      && dcrteFinite(maximumScoreEpsilon) && maximumScoreEpsilon >= 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("minimum_batches", minimumBatches);
    json.setInt("observation_window", observationWindow);
    json.setFloat("activation_fraction_epsilon", activationFractionEpsilon);
    json.setFloat("entropy_delta_epsilon", entropyDeltaEpsilon);
    json.setFloat("frontier_change_epsilon", frontierChangeEpsilon);
    json.setFloat("maximum_score_epsilon", maximumScoreEpsilon);
    json.setInt("required_stable_windows", requiredStableWindows);
    json.setBoolean("allow_stable_partial", allowStablePartial);
    json.setBoolean("require_frontier_nonempty_for_partial", requireFrontierNonemptyForPartial);
    return json;
  }
}

class EntropyConfiguration {
  EntropyNeighborhoodMode neighborhoodMode = EntropyNeighborhoodMode.CUBE_RADIUS_1;
  boolean includeCenterVoxel = true;
  int minimumSupport = 4;
  int fieldHistogramBins = 8;
  HistogramRangeMode histogramRangeMode = HistogramRangeMode.GLOBAL_CANDIDATE_RANGE;
  EntropicPolicyMode policyMode = EntropicPolicyMode.RELAXATION;
  AcceptanceMode acceptanceMode = AcceptanceMode.DETERMINISTIC_TOP_K;
  float entropyDeltaScale = 0.25f;
  float targetDeltaEntropy = 0;
  float balanceScale = 0.25f;
  float scoreThreshold = 0.55f;
  float minimumTopKScore = 0;
  int maxUpdatesPerBatch = 256;
  float acceptanceTemperature = 0.09f;
  int stagnationTrigger = 4;
  int explorationBoostDuration = 6;
  float explorationBoostMultiplier = 2.0f;
  float temperatureBoostMultiplier = 1.5f;
  float adaptiveDecay = 0.75f;
  int verificationInterval = 25;
  long schedulerSeed = 42017L;
  ScoreExportMode scoreExportMode = ScoreExportMode.TOP_K_PER_BATCH;
  int scoreExportK = 100;
  RelationalProgressConfiguration relationalProgress = new RelationalProgressConfiguration();
  EntropicStabilityConfiguration stability = new EntropicStabilityConfiguration();

  EntropyConfiguration copy() {
    EntropyConfiguration c = new EntropyConfiguration();
    c.neighborhoodMode = neighborhoodMode;
    c.includeCenterVoxel = includeCenterVoxel;
    c.minimumSupport = minimumSupport;
    c.fieldHistogramBins = fieldHistogramBins;
    c.histogramRangeMode = histogramRangeMode;
    c.policyMode = policyMode;
    c.acceptanceMode = acceptanceMode;
    c.entropyDeltaScale = entropyDeltaScale;
    c.targetDeltaEntropy = targetDeltaEntropy;
    c.balanceScale = balanceScale;
    c.scoreThreshold = scoreThreshold;
    c.minimumTopKScore = minimumTopKScore;
    c.maxUpdatesPerBatch = maxUpdatesPerBatch;
    c.acceptanceTemperature = acceptanceTemperature;
    c.stagnationTrigger = stagnationTrigger;
    c.explorationBoostDuration = explorationBoostDuration;
    c.explorationBoostMultiplier = explorationBoostMultiplier;
    c.temperatureBoostMultiplier = temperatureBoostMultiplier;
    c.adaptiveDecay = adaptiveDecay;
    c.verificationInterval = verificationInterval;
    c.schedulerSeed = schedulerSeed;
    c.scoreExportMode = scoreExportMode;
    c.scoreExportK = scoreExportK;
    c.relationalProgress = relationalProgress.copy();
    c.stability = stability.copy();
    return c;
  }

  boolean isValid() {
    return neighborhoodMode != null && minimumSupport > 0
      && fieldHistogramBins >= 2 && fieldHistogramBins <= 64
      && histogramRangeMode != null && policyMode != null && acceptanceMode != null
      && dcrteFinite(entropyDeltaScale) && entropyDeltaScale > 0
      && dcrteFinite(targetDeltaEntropy)
      && dcrteFinite(balanceScale) && balanceScale > 0
      && dcrteFinite(scoreThreshold) && scoreThreshold >= 0 && scoreThreshold <= 1
      && dcrteFinite(minimumTopKScore) && minimumTopKScore >= 0 && minimumTopKScore <= 1
      && maxUpdatesPerBatch > 0
      && dcrteFinite(acceptanceTemperature) && acceptanceTemperature >= 0.01f && acceptanceTemperature <= 1.0f
      && stagnationTrigger > 0 && explorationBoostDuration >= 0
      && dcrteFinite(explorationBoostMultiplier) && explorationBoostMultiplier >= 1
      && dcrteFinite(temperatureBoostMultiplier) && temperatureBoostMultiplier >= 1
      && dcrteFinite(adaptiveDecay) && adaptiveDecay >= 0 && adaptiveDecay <= 1
      && verificationInterval > 0 && scoreExportK > 0
      && relationalProgress != null && relationalProgress.isValid()
      && stability != null && stability.isValid();
  }

  String canonical() {
    return neighborhoodMode.id() + "|" + includeCenterVoxel + "|" + minimumSupport + "|"
      + fieldHistogramBins + "|" + histogramRangeMode.id() + "|" + policyMode.id() + "|"
      + acceptanceMode.id() + "|" + entropyDeltaScale + "|" + targetDeltaEntropy + "|"
      + balanceScale + "|" + scoreThreshold + "|" + minimumTopKScore + "|"
      + maxUpdatesPerBatch + "|" + acceptanceTemperature + "|" + stagnationTrigger + "|"
      + explorationBoostDuration + "|" + explorationBoostMultiplier + "|"
      + temperatureBoostMultiplier + "|" + adaptiveDecay + "|" + verificationInterval + "|"
      + schedulerSeed + "|" + relationalProgress.activationWeight + "|"
      + relationalProgress.entropyWeight + "|" + relationalProgress.frontierWeight + "|"
      + stability.minimumBatches + "|" + stability.observationWindow + "|"
      + stability.activationFractionEpsilon + "|" + stability.entropyDeltaEpsilon + "|"
      + stability.frontierChangeEpsilon + "|" + stability.maximumScoreEpsilon + "|"
      + stability.requiredStableWindows + "|" + stability.allowStablePartial + "|"
      + stability.requireFrontierNonemptyForPartial;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("neighborhood", neighborhoodMode.id());
    json.setString("support_policy", "candidate_only");
    json.setBoolean("include_center", includeCenterVoxel);
    json.setInt("minimum_support", minimumSupport);
    json.setInt("field_histogram_bins", fieldHistogramBins);
    json.setString("histogram_range", histogramRangeMode.id());
    json.setString("policy", policyMode.id());
    json.setString("acceptance", acceptanceMode.id());
    json.setFloat("entropy_delta_scale", entropyDeltaScale);
    json.setFloat("target_delta_entropy", targetDeltaEntropy);
    json.setFloat("balance_scale", balanceScale);
    json.setFloat("score_threshold", scoreThreshold);
    json.setFloat("minimum_top_k_score", minimumTopKScore);
    json.setInt("max_updates_per_batch", maxUpdatesPerBatch);
    json.setFloat("acceptance_temperature", acceptanceTemperature);
    json.setInt("stagnation_trigger", stagnationTrigger);
    json.setInt("exploration_boost_duration", explorationBoostDuration);
    json.setFloat("exploration_boost_multiplier", explorationBoostMultiplier);
    json.setFloat("temperature_boost_multiplier", temperatureBoostMultiplier);
    json.setFloat("adaptive_decay", adaptiveDecay);
    json.setInt("verification_interval", verificationInterval);
    json.setString("scheduler_seed", Long.toString(schedulerSeed));
    json.setString("score_export_mode", scoreExportMode.id());
    json.setInt("score_export_k", scoreExportK);
    json.setJSONObject("relational_progress", relationalProgress.toJSON());
    json.setJSONObject("stability", stability.toJSON());
    json.setString("score_formula_version", "m5-score-1");
    json.setString("stateless_random_version", "m5-mix64-1");
    return json;
  }
}

class LocalEntropySample {
  float entropy;
  float normalizedEntropy;
  int supportCount;
  int activeCount;
  int inactiveCandidateCount;
  int excludedCount;
  float activeFraction;
  boolean valid;
}

class EntropyDelta {
  float beforeEntropy;
  float afterEntropy;
  float deltaEntropy;
  float absoluteDeltaEntropy;
  float neighborhoodMeanBefore;
  float neighborhoodMeanAfter;
  float neighborhoodMeanDelta;
  int affectedCenterCount;
  boolean valid;
}

class EntropySummary {
  float meanLocalEntropy;
  float weightedMeanLocalEntropy;
  float frontierMeanEntropy;
  float activeRegionMeanEntropy;
  float minLocalEntropy;
  float maxLocalEntropy;
  int validSampleCount;
  int lowSupportCount;
  float totalEntropyChangeFromPrevious;
  float meanAbsoluteLocalChange;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("mean_local_entropy", meanLocalEntropy);
    json.setFloat("weighted_mean_local_entropy", weightedMeanLocalEntropy);
    json.setFloat("frontier_mean_entropy", frontierMeanEntropy);
    json.setFloat("active_region_mean_entropy", activeRegionMeanEntropy);
    json.setFloat("min_local_entropy", minLocalEntropy);
    json.setFloat("max_local_entropy", maxLocalEntropy);
    json.setInt("valid_sample_count", validSampleCount);
    json.setInt("low_support_count", lowSupportCount);
    json.setFloat("total_entropy_change_from_previous", totalEntropyChangeFromPrevious);
    json.setFloat("mean_absolute_local_change", meanAbsoluteLocalChange);
    return json;
  }
}

interface EntropyModel {
  void initialize(EntropyContext context);
  LocalEntropySample sampleAt(int centerIndex, PropagationState state);
  EntropyDelta evaluateActivation(int activationIndex, PropagationState state);
  EntropySummary summarize(PropagationState state);
  void updateAfterCommit(SchedulerBatch committedBatch, PropagationState state);
  String getId();
  String getVersion();
  boolean isDynamic();
  boolean isValid();
  String validationMessage();
  JSONObject toJSON();
}

class EntropyContext {
  final CandidateVolumeSnapshot candidate;
  final SchedulerNeighborhoodMode propagationNeighborhood;
  final EntropyConfiguration config;
  EntropyCache cache;
  float maximumAbsoluteField = 1;
  float maximumInteriorDepth = 1;

  EntropyContext(CandidateVolumeSnapshot candidate, SchedulerNeighborhoodMode propagationNeighborhood,
      EntropyConfiguration config) {
    this.candidate = candidate;
    this.propagationNeighborhood = propagationNeighborhood;
    this.config = config == null ? new EntropyConfiguration() : config.copy();
    if (candidate != null) {
      float maxField = 0, maxDepth = 0;
      for (int i = 0; i < candidate.candidateSolid.length; i++) if (candidate.candidateSolid[i]) {
        if (dcrteFinite(candidate.fieldScalar[i])) maxField = max(maxField, abs(candidate.fieldScalar[i]));
        if (dcrteFinite(candidate.signedDistance[i])) maxDepth = max(maxDepth, max(0, -candidate.signedDistance[i]));
      }
      maximumAbsoluteField = max(0.000001f, maxField);
      maximumInteriorDepth = max(0.000001f, maxDepth);
    }
  }

  boolean isValid() {
    return candidate != null && candidate.valid && propagationNeighborhood != null
      && config != null && config.isValid();
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("candidate_snapshot_hash", candidate == null ? "" : candidate.contentHash);
    json.setString("propagation_neighborhood", propagationNeighborhood == null ? "" : propagationNeighborhood.id());
    json.setJSONObject("configuration", config.toJSON());
    json.setBoolean("valid", isValid());
    return json;
  }
}
