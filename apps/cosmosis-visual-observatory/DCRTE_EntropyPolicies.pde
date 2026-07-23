/* DCRTE-ET Milestone 5 named, versioned entropic score policies. */

class SchedulerScoreWeights {
  float fieldCompatibilityWeight;
  float relaxationWeight;
  float explorationWeight;
  float balanceWeight;
  float coherenceWeight;
  float interiorDepthWeight;
  float intrinsicDirectionWeight;
  float coordinateConfidenceWeight;
  float fieldComplexityWeight;
  float noiseWeight;
  boolean valid;
  String validation = "not validated";

  SchedulerScoreWeights copy() {
    SchedulerScoreWeights c = new SchedulerScoreWeights();
    c.fieldCompatibilityWeight = fieldCompatibilityWeight;
    c.relaxationWeight = relaxationWeight;
    c.explorationWeight = explorationWeight;
    c.balanceWeight = balanceWeight;
    c.coherenceWeight = coherenceWeight;
    c.interiorDepthWeight = interiorDepthWeight;
    c.intrinsicDirectionWeight = intrinsicDirectionWeight;
    c.coordinateConfidenceWeight = coordinateConfidenceWeight;
    c.fieldComplexityWeight = fieldComplexityWeight;
    c.noiseWeight = noiseWeight;
    c.valid = valid;
    c.validation = validation;
    return c;
  }

  boolean validateAndNormalize() {
    float[] values = {
      fieldCompatibilityWeight, relaxationWeight, explorationWeight, balanceWeight,
      coherenceWeight, interiorDepthWeight, intrinsicDirectionWeight,
      coordinateConfidenceWeight, fieldComplexityWeight, noiseWeight
    };
    float sum = 0;
    for (int i = 0; i < values.length; i++) {
      if (!dcrteFinite(values[i]) || values[i] < 0) {
        valid = false;
        validation = "weights must be finite and nonnegative";
        return false;
      }
      sum += values[i];
    }
    if (!dcrteFinite(sum) || sum <= 0) {
      valid = false;
      validation = "at least one positive score weight is required";
      return false;
    }
    fieldCompatibilityWeight /= sum;
    relaxationWeight /= sum;
    explorationWeight /= sum;
    balanceWeight /= sum;
    coherenceWeight /= sum;
    interiorDepthWeight /= sum;
    intrinsicDirectionWeight /= sum;
    coordinateConfidenceWeight /= sum;
    fieldComplexityWeight /= sum;
    noiseWeight /= sum;
    valid = true;
    validation = "valid";
    return true;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("field", fieldCompatibilityWeight);
    json.setFloat("relaxation", relaxationWeight);
    json.setFloat("exploration", explorationWeight);
    json.setFloat("balance", balanceWeight);
    json.setFloat("coherence", coherenceWeight);
    json.setFloat("interior_depth", interiorDepthWeight);
    json.setFloat("intrinsic_direction", intrinsicDirectionWeight);
    json.setFloat("coordinate_confidence", coordinateConfidenceWeight);
    json.setFloat("field_complexity", fieldComplexityWeight);
    json.setFloat("seeded_noise", noiseWeight);
    json.setBoolean("valid", valid);
    json.setString("validation", validation);
    return json;
  }
}

class EntropicPolicyState {
  int stagnationBatches;
  int explorationBoostBatchesRemaining;
  float relaxationMultiplier = 1;
  float explorationMultiplier = 1;
  float currentTemperature = 0.09f;
  String lastTransition = "initialized";
  int transitionCount;

  void initialize(EntropyConfiguration config) {
    stagnationBatches = 0;
    explorationBoostBatchesRemaining = 0;
    relaxationMultiplier = 1;
    explorationMultiplier = 1;
    currentTemperature = config.acceptanceTemperature;
    lastTransition = "initialized";
    transitionCount = 0;
  }

  String updateAfterBatch(int acceptedCount, int frontierCount, EntropyConfiguration config) {
    String transition = "none";
    if (acceptedCount > 0) {
      stagnationBatches = 0;
      if (explorationBoostBatchesRemaining > 0 || explorationMultiplier > 1.0001f) {
        explorationBoostBatchesRemaining = max(0, explorationBoostBatchesRemaining - 1);
        explorationMultiplier = max(1, 1 + (explorationMultiplier - 1) * config.adaptiveDecay);
        currentTemperature = max(config.acceptanceTemperature,
          config.acceptanceTemperature + (currentTemperature - config.acceptanceTemperature) * config.adaptiveDecay);
        transition = explorationBoostBatchesRemaining == 0 && explorationMultiplier <= 1.01f
          ? "return_to_relaxation" : "exploration_decay";
      }
    } else if (frontierCount > 0) {
      stagnationBatches++;
      if (stagnationBatches >= config.stagnationTrigger
          && explorationBoostBatchesRemaining == 0) {
        explorationBoostBatchesRemaining = config.explorationBoostDuration;
        explorationMultiplier = config.explorationBoostMultiplier;
        currentTemperature = min(1, config.acceptanceTemperature * config.temperatureBoostMultiplier);
        stagnationBatches = 0;
        transition = "exploration_boost";
      } else if (explorationBoostBatchesRemaining > 0) {
        explorationBoostBatchesRemaining--;
        transition = "exploration_hold";
      }
    }
    if (!transition.equals("none")) {
      lastTransition = transition;
      transitionCount++;
    }
    return transition;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("stagnation_batches", stagnationBatches);
    json.setInt("exploration_boost_batches_remaining", explorationBoostBatchesRemaining);
    json.setFloat("relaxation_multiplier", relaxationMultiplier);
    json.setFloat("exploration_multiplier", explorationMultiplier);
    json.setFloat("current_acceptance_temperature", currentTemperature);
    json.setString("last_transition", lastTransition);
    json.setInt("transition_count", transitionCount);
    return json;
  }
}

class EntropicPolicyContext {
  EntropyConfiguration config;
  EntropicPolicyState state;
  int batchIndex;
  int frontierCount;
}

interface EntropyPolicy {
  SchedulerScoreWeights weightsFor(EntropicPolicyContext context);
  String getId();
  String getVersion();
  JSONObject toJSON();
}

class PresetEntropyPolicy implements EntropyPolicy {
  final EntropicPolicyMode mode;

  PresetEntropyPolicy(EntropicPolicyMode mode) {
    this.mode = mode == null ? EntropicPolicyMode.RELAXATION : mode;
  }

  SchedulerScoreWeights baseWeights(EntropicPolicyMode requestedMode) {
    SchedulerScoreWeights weights = new SchedulerScoreWeights();
    if (requestedMode == EntropicPolicyMode.EXPLORATION) {
      weights.fieldCompatibilityWeight = 0.20f;
      weights.explorationWeight = 0.35f;
      weights.coherenceWeight = 0.15f;
      weights.fieldComplexityWeight = 0.15f;
      weights.noiseWeight = 0.10f;
      weights.coordinateConfidenceWeight = 0.05f;
    } else if (requestedMode == EntropicPolicyMode.BALANCED) {
      weights.fieldCompatibilityWeight = 0.25f;
      weights.balanceWeight = 0.30f;
      weights.coherenceWeight = 0.20f;
      weights.interiorDepthWeight = 0.10f;
      weights.fieldComplexityWeight = 0.05f;
      weights.coordinateConfidenceWeight = 0.10f;
    } else {
      weights.fieldCompatibilityWeight = 0.20f;
      weights.relaxationWeight = 0.45f;
      weights.coherenceWeight = 0.20f;
      weights.interiorDepthWeight = 0.05f;
      weights.coordinateConfidenceWeight = 0.10f;
    }
    return weights;
  }

  public SchedulerScoreWeights weightsFor(EntropicPolicyContext context) {
    if (mode != EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE) {
      SchedulerScoreWeights weights = baseWeights(mode);
      weights.validateAndNormalize();
      return weights;
    }
    SchedulerScoreWeights relaxation = baseWeights(EntropicPolicyMode.RELAXATION);
    SchedulerScoreWeights exploration = baseWeights(EntropicPolicyMode.EXPLORATION);
    float boost = context == null || context.state == null
      ? 1 : max(1, context.state.explorationMultiplier);
    SchedulerScoreWeights weights = new SchedulerScoreWeights();
    weights.fieldCompatibilityWeight = relaxation.fieldCompatibilityWeight
      + exploration.fieldCompatibilityWeight * boost;
    weights.relaxationWeight = relaxation.relaxationWeight;
    weights.explorationWeight = exploration.explorationWeight * boost;
    weights.coherenceWeight = relaxation.coherenceWeight + exploration.coherenceWeight * boost;
    weights.interiorDepthWeight = relaxation.interiorDepthWeight;
    weights.coordinateConfidenceWeight = relaxation.coordinateConfidenceWeight
      + exploration.coordinateConfidenceWeight * boost;
    weights.fieldComplexityWeight = exploration.fieldComplexityWeight * boost;
    weights.noiseWeight = exploration.noiseWeight * boost;
    weights.validateAndNormalize();
    return weights;
  }

  public String getId() { return mode.id(); }
  public String getVersion() { return "1.0-m5"; }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", getId());
    json.setString("version", getVersion());
    json.setString("interpretation", mode == EntropicPolicyMode.RELAXATION
      ? "prefer entropy-reducing coherent frontier events"
      : mode == EntropicPolicyMode.EXPLORATION
        ? "prefer entropy-increasing diverse frontier events"
        : mode == EntropicPolicyMode.BALANCED
          ? "prefer frontier events near a configured entropy delta"
          : "relaxation dominant with bounded exploration during stagnation");
    return json;
  }
}

EntropyPolicy dcrteEntropyPolicy(EntropicPolicyMode mode) {
  return new PresetEntropyPolicy(mode);
}
