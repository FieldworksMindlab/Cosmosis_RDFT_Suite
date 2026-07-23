/* DCRTE-ET Milestone 5 dimensionless computational relational progress. */

class RelationalProgressIncrement {
  double activationChange;
  double entropyChange;
  double frontierChange;
  double deltaTau;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("activation_change", Double.toString(activationChange));
    json.setString("entropy_change", Double.toString(entropyChange));
    json.setString("frontier_change", Double.toString(frontierChange));
    json.setString("delta_tau", Double.toString(deltaTau));
    return json;
  }
}

class RelationalProgressTracker {
  double tauRaw;
  double tauNormalized;
  double cumulativeActivationChange;
  double cumulativeEntropyChange;
  double cumulativeFrontierChange;
  int eventBatchCount;
  RelationalProgressIncrement lastIncrement = new RelationalProgressIncrement();
  RelationalProgressConfiguration config = new RelationalProgressConfiguration();

  void initialize(RelationalProgressConfiguration source) {
    config = source == null ? new RelationalProgressConfiguration() : source.copy();
    tauRaw = 0;
    tauNormalized = 0;
    cumulativeActivationChange = 0;
    cumulativeEntropyChange = 0;
    cumulativeFrontierChange = 0;
    eventBatchCount = 0;
    lastIncrement = new RelationalProgressIncrement();
  }

  RelationalProgressIncrement update(int newlyActivated, int candidateCount,
      float meanAbsoluteLocalEntropyChange, int frontierBefore, int frontierAfter) {
    RelationalProgressIncrement increment = new RelationalProgressIncrement();
    int denominator = max(1, candidateCount);
    increment.activationChange = max(0, newlyActivated) / (double)denominator;
    increment.entropyChange = max(0, meanAbsoluteLocalEntropyChange);
    increment.frontierChange = abs(frontierAfter - frontierBefore) / (double)denominator;
    increment.deltaTau = config.activationWeight * increment.activationChange
      + config.entropyWeight * increment.entropyChange
      + config.frontierWeight * increment.frontierChange;
    if (!Double.isFinite(increment.deltaTau) || increment.deltaTau < 0) {
      increment.deltaTau = Double.NaN;
      lastIncrement = increment;
      return increment;
    }
    tauRaw += increment.deltaTau;
    cumulativeActivationChange += increment.activationChange;
    cumulativeEntropyChange += increment.entropyChange;
    cumulativeFrontierChange += increment.frontierChange;
    eventBatchCount++;
    lastIncrement = increment;
    return increment;
  }

  void finalizeProgress() {
    tauNormalized = tauRaw <= 0 ? 0 : 1.0;
  }

  boolean isValid() {
    return Double.isFinite(tauRaw) && tauRaw >= 0
      && Double.isFinite(tauNormalized) && tauNormalized >= 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("formula_version", "m5-tau-1");
    json.setString("interpretation", "dimensionless computational relational progress");
    json.setString("tau_raw", Double.toString(tauRaw));
    json.setString("tau_normalized", Double.toString(tauNormalized));
    json.setString("cumulative_activation_change", Double.toString(cumulativeActivationChange));
    json.setString("cumulative_entropy_change", Double.toString(cumulativeEntropyChange));
    json.setString("cumulative_frontier_change", Double.toString(cumulativeFrontierChange));
    json.setInt("event_batch_count", eventBatchCount);
    json.setJSONObject("last_increment", lastIncrement.toJSON());
    json.setJSONObject("configuration", config.toJSON());
    return json;
  }
}
