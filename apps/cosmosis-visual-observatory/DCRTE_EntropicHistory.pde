/* DCRTE-ET Milestone 5 entropy-specific history and compact score provenance. */

class EntropicSchedulerHistoryEntry {
  SchedulerHistoryEntry base;
  float meanOccupancyEntropy;
  float frontierOccupancyEntropy;
  float meanFieldEntropy;
  float meanAcceptedDeltaEntropy;
  float meanAbsoluteAcceptedDeltaEntropy;
  float meanFrontierScore;
  float maxFrontierScore;
  float meanAcceptedScore;
  float minAcceptedScore;
  int evaluatedFrontierCount;
  int thresholdEligibleCount;
  int stochasticAcceptedCount;
  float acceptanceTemperature;
  float scoreThreshold;
  String policyMode = "";
  String acceptanceMode = "";
  String policyTransition = "none";
  double deltaTau;
  double tauRaw;
  boolean stableWindow;
  int consecutiveStableWindows;
  String stopReason = "none";
  String stateHash = "";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    if (base != null) json.setJSONObject("base", base.toJSON());
    json.setFloat("mean_occupancy_entropy", meanOccupancyEntropy);
    json.setFloat("frontier_occupancy_entropy", frontierOccupancyEntropy);
    json.setFloat("mean_field_entropy", meanFieldEntropy);
    json.setFloat("mean_accepted_delta_entropy", meanAcceptedDeltaEntropy);
    json.setFloat("mean_absolute_accepted_delta_entropy", meanAbsoluteAcceptedDeltaEntropy);
    json.setFloat("mean_frontier_score", meanFrontierScore);
    json.setFloat("max_frontier_score", maxFrontierScore);
    json.setFloat("mean_accepted_score", meanAcceptedScore);
    json.setFloat("min_accepted_score", minAcceptedScore);
    json.setInt("evaluated_frontier_count", evaluatedFrontierCount);
    json.setInt("threshold_eligible_count", thresholdEligibleCount);
    json.setInt("stochastic_accepted_count", stochasticAcceptedCount);
    json.setFloat("acceptance_temperature", acceptanceTemperature);
    json.setFloat("score_threshold", scoreThreshold);
    json.setString("policy_mode", policyMode);
    json.setString("acceptance_mode", acceptanceMode);
    json.setString("policy_transition", policyTransition);
    json.setString("delta_tau", Double.toString(deltaTau));
    json.setString("tau_raw", Double.toString(tauRaw));
    json.setBoolean("stable_window", stableWindow);
    json.setInt("consecutive_stable_windows", consecutiveStableWindows);
    json.setString("stop_reason", stopReason);
    json.setString("state_hash", stateHash);
    return json;
  }
}
