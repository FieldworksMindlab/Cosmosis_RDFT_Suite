/* DCRTE-ET Milestone 5 entropy and scheduler-decision visualization helpers. */

float dcrteEntropicVisualizationValue(EmergentEntropicScheduler scheduler,
    PropagationState state, int voxelIndex, EntropyVisualizationMode mode) {
  if (scheduler == null || state == null || mode == null || voxelIndex < 0
      || voxelIndex >= state.active.length) return Float.NaN;
  EntropyCache cache = scheduler.entropyCache;
  EntropicScoreRecord scoreRecord = scheduler.latestRecordAt(voxelIndex);
  if (mode == EntropyVisualizationMode.OCCUPANCY_ENTROPY)
    return cache != null && cache.occupancyValid[voxelIndex]
      ? cache.occupancyEntropy[voxelIndex] : Float.NaN;
  if (mode == EntropyVisualizationMode.FIELD_ENTROPY)
    return cache != null && cache.fieldValid[voxelIndex]
      ? cache.fieldEntropy[voxelIndex] : Float.NaN;
  if (mode == EntropyVisualizationMode.DELTA_ENTROPY)
    return scoreRecord == null ? Float.NaN
      : constrain(0.5f + scoreRecord.occupancyDelta.deltaEntropy
        / max(0.000001f, scheduler.entropyContext.config.entropyDeltaScale * 2), 0, 1);
  if (mode == EntropyVisualizationMode.RELAXATION_SCORE)
    return scoreRecord == null ? Float.NaN : scoreRecord.terms.entropyRelaxation;
  if (mode == EntropyVisualizationMode.EXPLORATION_SCORE)
    return scoreRecord == null ? Float.NaN : scoreRecord.terms.entropyExploration;
  if (mode == EntropyVisualizationMode.COMBINED_SCORE)
    return scoreRecord == null ? Float.NaN : scoreRecord.terms.combinedScore;
  if (mode == EntropyVisualizationMode.ACCEPTANCE_PROBABILITY)
    return scoreRecord == null ? Float.NaN : scoreRecord.acceptanceProbability;
  if (mode == EntropyVisualizationMode.ACCEPTED_BATCH)
    return scoreRecord == null ? Float.NaN : scoreRecord.accepted ? 1 : 0;
  if (mode == EntropyVisualizationMode.REJECTED_FRONTIER)
    return scoreRecord == null ? Float.NaN : scoreRecord.accepted ? 0 : 1;
  if (mode == EntropyVisualizationMode.RELATIONAL_PROGRESS) {
    if (!state.active[voxelIndex]) return 0;
    return constrain((float)(scheduler.progress.tauRaw
      / Math.max(1.0, scheduler.progress.tauRaw + 1.0)), 0, 1);
  }
  if (mode == EntropyVisualizationMode.STABILITY) {
    if (!state.active[voxelIndex] || scheduler.stability == null) return 0;
    return constrain(scheduler.stability.state.consecutiveStableWindows
      / (float)max(1, scheduler.entropyContext.config.stability.requiredStableWindows),
      0, 1);
  }
  return Float.NaN;
}

color dcrteEntropicVisualizationColor(float value,
    EntropyVisualizationMode mode) {
  if (!dcrteFinite(value)) return color(16, 28, 34);
  float t = constrain(value, 0, 1);
  if (mode == EntropyVisualizationMode.DELTA_ENTROPY)
    return t < 0.5f
      ? lerpColor(color(50, 116, 238), color(240, 244, 246), t * 2)
      : lerpColor(color(240, 244, 246), color(255, 89, 126), (t - 0.5f) * 2);
  if (mode == EntropyVisualizationMode.ACCEPTED_BATCH)
    return t > 0.5f ? color(76, 239, 174) : color(32, 48, 54);
  if (mode == EntropyVisualizationMode.REJECTED_FRONTIER)
    return t > 0.5f ? color(255, 111, 88) : color(32, 48, 54);
  if (mode == EntropyVisualizationMode.STABILITY)
    return lerpColor(color(255, 181, 62), color(86, 235, 170), t);
  return t < 0.5f
    ? lerpColor(color(17, 57, 82), color(0, 211, 190), t * 2)
    : lerpColor(color(0, 211, 190), color(255, 221, 78), (t - 0.5f) * 2);
}
