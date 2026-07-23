/* DCRTE-ET Milestone 5 conditional entropy-window stability detection. */

class EntropicStabilityState {
  boolean stable;
  boolean lastWindowStable;
  int consecutiveStableWindows;
  int evaluatedWindows;
  String lastFailureCriterion = "not_evaluated";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("stable", stable);
    json.setBoolean("last_window_stable", lastWindowStable);
    json.setInt("consecutive_stable_windows", consecutiveStableWindows);
    json.setInt("evaluated_windows", evaluatedWindows);
    json.setString("last_failure_criterion", lastFailureCriterion);
    return json;
  }
}

class EntropicStabilityReport {
  boolean stable;
  boolean stableWindow;
  int consecutiveStableWindows;
  float meanActivationFraction;
  float meanAbsoluteEntropyChange;
  float meanFrontierChangeFraction;
  float maximumAvailableScore;
  String failureCriterion = "none";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("stable", stable);
    json.setBoolean("stable_window", stableWindow);
    json.setInt("consecutive_stable_windows", consecutiveStableWindows);
    json.setFloat("mean_activation_fraction", meanActivationFraction);
    json.setFloat("mean_absolute_entropy_change", meanAbsoluteEntropyChange);
    json.setFloat("mean_frontier_change_fraction", meanFrontierChangeFraction);
    json.setFloat("maximum_available_score", maximumAvailableScore);
    json.setString("failure_criterion", failureCriterion);
    return json;
  }
}

class EntropicStabilityDetector {
  EntropicStabilityConfiguration config;
  EntropicStabilityState state = new EntropicStabilityState();
  ArrayList<Float> activationFractions = new ArrayList<Float>();
  ArrayList<Float> entropyChanges = new ArrayList<Float>();
  ArrayList<Float> frontierChanges = new ArrayList<Float>();
  ArrayList<Float> maximumScores = new ArrayList<Float>();
  EntropicStabilityReport lastReport = new EntropicStabilityReport();

  EntropicStabilityDetector(EntropicStabilityConfiguration config) {
    this.config = config == null ? new EntropicStabilityConfiguration() : config.copy();
  }

  void reset() {
    state = new EntropicStabilityState();
    activationFractions.clear();
    entropyChanges.clear();
    frontierChanges.clear();
    maximumScores.clear();
    lastReport = new EntropicStabilityReport();
  }

  void update(int batchIndex, int newlyActivated, int candidateCount,
      float meanAbsoluteEntropyChange, int frontierBefore, int frontierAfter,
      float maximumScore, float scoreThreshold) {
    int denominator = max(1, candidateCount);
    activationFractions.add(max(0, newlyActivated) / (float)denominator);
    entropyChanges.add(max(0, meanAbsoluteEntropyChange));
    frontierChanges.add(abs(frontierAfter - frontierBefore) / (float)denominator);
    maximumScores.add(maximumScore);
    trimToWindow(activationFractions);
    trimToWindow(entropyChanges);
    trimToWindow(frontierChanges);
    trimToWindow(maximumScores);
    lastReport = new EntropicStabilityReport();
    lastReport.consecutiveStableWindows = state.consecutiveStableWindows;
    if (!config.isValid() || batchIndex < config.minimumBatches
        || activationFractions.size() < config.observationWindow) {
      state.lastWindowStable = false;
      state.lastFailureCriterion = "observation_window_incomplete";
      lastReport.failureCriterion = state.lastFailureCriterion;
      return;
    }
    lastReport.meanActivationFraction = dcrteMeanFloatList(activationFractions);
    lastReport.meanAbsoluteEntropyChange = dcrteMeanFloatList(entropyChanges);
    lastReport.meanFrontierChangeFraction = dcrteMeanFloatList(frontierChanges);
    lastReport.maximumAvailableScore = dcrteMaxFloatList(maximumScores);
    boolean activationStable = lastReport.meanActivationFraction <= config.activationFractionEpsilon;
    boolean entropyStable = lastReport.meanAbsoluteEntropyChange <= config.entropyDeltaEpsilon;
    boolean frontierStable = lastReport.meanFrontierChangeFraction <= config.frontierChangeEpsilon;
    boolean scoreStable = lastReport.maximumAvailableScore
      <= scoreThreshold + config.maximumScoreEpsilon;
    state.evaluatedWindows++;
    state.lastWindowStable = activationStable && entropyStable && frontierStable && scoreStable;
    if (state.lastWindowStable) {
      state.consecutiveStableWindows++;
      state.lastFailureCriterion = "none";
    } else {
      state.consecutiveStableWindows = 0;
      state.lastFailureCriterion = !activationStable ? "activation"
        : !entropyStable ? "entropy" : !frontierStable ? "frontier" : "score";
    }
    state.stable = state.consecutiveStableWindows >= config.requiredStableWindows;
    lastReport.stableWindow = state.lastWindowStable;
    lastReport.stable = state.stable;
    lastReport.consecutiveStableWindows = state.consecutiveStableWindows;
    lastReport.failureCriterion = state.lastFailureCriterion;
  }

  void trimToWindow(ArrayList<Float> values) {
    while (values.size() > config.observationWindow) values.remove(0);
  }

  boolean isStable() { return state.stable; }
  EntropicStabilityReport report() { return lastReport; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("definition", "stable under the configured entropy, activation, frontier, and score criteria");
    json.setJSONObject("configuration", config.toJSON());
    json.setJSONObject("state", state.toJSON());
    json.setJSONObject("report", lastReport.toJSON());
    return json;
  }
}

float dcrteMeanFloatList(ArrayList<Float> values) {
  if (values == null || values.size() == 0) return 0;
  double sum = 0;
  for (int i = 0; i < values.size(); i++) sum += values.get(i);
  return (float)(sum / values.size());
}

float dcrteMaxFloatList(ArrayList<Float> values) {
  if (values == null || values.size() == 0) return 0;
  float result = Float.NEGATIVE_INFINITY;
  for (int i = 0; i < values.size(); i++) result = max(result, values.get(i));
  return result;
}
