/* DCRTE-ET Milestone 5 transparent, normalized frontier score terms. */

class EntropyObservables {
  float occupancyEntropy;
  float occupancyDelta;
  float fieldEntropy;
  float frontierActiveFraction;
  float localCandidateSupport;
  float signedDistanceNormalized;
  float intrinsicS;
  float intrinsicRho;
  float coordinateConfidence;
  boolean intrinsicAvailable;
  boolean confidenceAvailable;
  boolean valid;
}

class SchedulerScoreTerms {
  float fieldCompatibility;
  float entropyRelaxation;
  float entropyExploration;
  float entropyBalance;
  float frontierCoherence;
  float interiorDepth;
  float intrinsicDirection;
  float coordinateConfidence;
  float fieldComplexity;
  float seededNoise;
  float hbeNeckProximity;
  float hbeBilateralBalance;
  float hbeMirrorSupport;
  float hbeConnectionGain;
  float hbeFeedbackCoupling;
  float hbeCrossLobeReachability;
  float hbeCombinedScore;
  boolean hbeAvailable;
  float combinedScore;
  boolean intrinsicDirectionAvailable;
  boolean coordinateConfidenceAvailable;
  boolean valid;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("field_compatibility", fieldCompatibility);
    json.setFloat("entropy_relaxation", entropyRelaxation);
    json.setFloat("entropy_exploration", entropyExploration);
    json.setFloat("entropy_balance", entropyBalance);
    json.setFloat("frontier_coherence", frontierCoherence);
    json.setFloat("interior_depth", interiorDepth);
    json.setFloat("intrinsic_direction", intrinsicDirection);
    json.setBoolean("intrinsic_direction_available", intrinsicDirectionAvailable);
    json.setFloat("coordinate_confidence", coordinateConfidence);
    json.setBoolean("coordinate_confidence_available", coordinateConfidenceAvailable);
    json.setFloat("field_complexity", fieldComplexity);
    json.setFloat("seeded_noise", seededNoise);
    json.setBoolean("hbe_available", hbeAvailable);
    if (hbeAvailable) {
      json.setFloat("hbe_neck_proximity", hbeNeckProximity);
      json.setFloat("hbe_bilateral_balance", hbeBilateralBalance);
      json.setFloat("hbe_mirror_support", hbeMirrorSupport);
      json.setFloat("hbe_connection_gain", hbeConnectionGain);
      json.setFloat("hbe_feedback_coupling", hbeFeedbackCoupling);
      json.setFloat("hbe_cross_lobe_reachability", hbeCrossLobeReachability);
      json.setFloat("hbe_combined_score", hbeCombinedScore);
    }
    json.setFloat("combined_score", combinedScore);
    json.setBoolean("valid", valid);
    return json;
  }
}

class EntropicScoreRecord {
  int batchIndex;
  int voxelIndex;
  EntropyDelta occupancyDelta = new EntropyDelta();
  SchedulerScoreTerms terms = new SchedulerScoreTerms();
  SchedulerScoreWeights weights;
  float acceptanceProbability;
  float statelessRandomValue;
  boolean thresholdEligible;
  boolean accepted;

  JSONObject toJSON(CandidateVolumeSnapshot snapshot) {
    JSONObject json = new JSONObject();
    json.setInt("batch", batchIndex);
    json.setInt("voxel_index", voxelIndex);
    if (snapshot != null && snapshot.spec != null && voxelIndex >= 0
        && voxelIndex < snapshot.spec.voxelCount()) {
      int x = voxelIndex % snapshot.spec.nx;
      int yz = voxelIndex / snapshot.spec.nx;
      int y = yz % snapshot.spec.ny;
      int z = yz / snapshot.spec.ny;
      JSONObject world = new JSONObject();
      world.setFloat("x", snapshot.spec.bounds.minX + (x + 0.5f) * snapshot.spec.spacingX());
      world.setFloat("y", snapshot.spec.bounds.minY + (y + 0.5f) * snapshot.spec.spacingY());
      world.setFloat("z", snapshot.spec.bounds.minZ + (z + 0.5f) * snapshot.spec.spacingZ());
      json.setJSONObject("world_position", world);
      if (snapshot.hasIntrinsic()) {
        JSONObject intrinsic = new JSONObject();
        intrinsic.setFloat("s", snapshot.intrinsicS[voxelIndex]);
        intrinsic.setFloat("rho", snapshot.intrinsicRho[voxelIndex]);
        if (snapshot.hasIntrinsicTheta()) intrinsic.setFloat("theta", snapshot.intrinsicTheta[voxelIndex]);
        intrinsic.setFloat("confidence", snapshot.intrinsicConfidence[voxelIndex]);
        json.setJSONObject("intrinsic", intrinsic);
      }
    }
    JSONObject entropy = new JSONObject();
    entropy.setFloat("before", occupancyDelta.beforeEntropy);
    entropy.setFloat("after", occupancyDelta.afterEntropy);
    entropy.setFloat("delta", occupancyDelta.deltaEntropy);
    entropy.setFloat("mean_absolute_change", occupancyDelta.absoluteDeltaEntropy);
    entropy.setInt("affected_centers", occupancyDelta.affectedCenterCount);
    json.setJSONObject("occupancy_entropy", entropy);
    json.setFloat("field_entropy", terms.fieldComplexity);
    json.setJSONObject("terms", terms.toJSON());
    if (weights != null) json.setJSONObject("weights", weights.toJSON());
    json.setFloat("acceptance_probability", acceptanceProbability);
    json.setFloat("stateless_random", statelessRandomValue);
    json.setBoolean("threshold_eligible", thresholdEligible);
    json.setBoolean("accepted", accepted);
    return json;
  }
}

class FrontierEvaluation {
  EntropicScoreRecord[] records = new EntropicScoreRecord[0];
  int evaluatedCount;
  int acceptedCount;
  int thresholdEligibleCount;
  int stochasticAcceptedCount;
  float meanScore;
  float maximumScore;
  float meanAcceptedScore;
  float minimumAcceptedScore;
  float meanAcceptedDeltaEntropy;
  float meanAbsoluteAcceptedDeltaEntropy;

  void summarizeAccepted() {
    double frontierSum = 0, acceptedSum = 0, deltaSum = 0, absoluteDeltaSum = 0;
    acceptedCount = 0;
    maximumScore = records.length == 0 ? 0 : Float.NEGATIVE_INFINITY;
    minimumAcceptedScore = Float.POSITIVE_INFINITY;
    thresholdEligibleCount = 0;
    stochasticAcceptedCount = 0;
    for (int i = 0; i < records.length; i++) {
      EntropicScoreRecord scoreRecord = records[i];
      frontierSum += scoreRecord.terms.combinedScore;
      maximumScore = max(maximumScore, scoreRecord.terms.combinedScore);
      if (scoreRecord.thresholdEligible) thresholdEligibleCount++;
      if (scoreRecord.accepted) {
        acceptedCount++;
        acceptedSum += scoreRecord.terms.combinedScore;
        minimumAcceptedScore = min(minimumAcceptedScore, scoreRecord.terms.combinedScore);
        deltaSum += scoreRecord.occupancyDelta.deltaEntropy;
        absoluteDeltaSum += scoreRecord.occupancyDelta.absoluteDeltaEntropy;
        if (scoreRecord.acceptanceProbability > 0 && scoreRecord.acceptanceProbability < 1) stochasticAcceptedCount++;
      }
    }
    evaluatedCount = records.length;
    meanScore = records.length == 0 ? 0 : (float)(frontierSum / records.length);
    maximumScore = records.length == 0 ? 0 : maximumScore;
    meanAcceptedScore = acceptedCount == 0 ? 0 : (float)(acceptedSum / acceptedCount);
    minimumAcceptedScore = acceptedCount == 0 ? 0 : minimumAcceptedScore;
    meanAcceptedDeltaEntropy = acceptedCount == 0 ? 0 : (float)(deltaSum / acceptedCount);
    meanAbsoluteAcceptedDeltaEntropy = acceptedCount == 0 ? 0 : (float)(absoluteDeltaSum / acceptedCount);
  }
}

SchedulerScoreTerms dcrteEntropicScoreTerms(int voxelIndex, EntropyDelta delta,
    EntropyContext entropyContext, PropagationState state, SchedulerScoreWeights weights,
    int batchIndex, long schedulerSeed, HBEScoreBatchContext hbeBatch) {
  SchedulerScoreTerms terms = new SchedulerScoreTerms();
  CandidateVolumeSnapshot snapshot = entropyContext.candidate;
  float field = snapshot.fieldScalar[voxelIndex];
  terms.fieldCompatibility = dcrteFinite(field)
    ? constrain(abs(field) / entropyContext.maximumAbsoluteField, 0, 1) : 0;
  terms.entropyRelaxation = delta.valid
    ? constrain(-delta.deltaEntropy / entropyContext.config.entropyDeltaScale, 0, 1) : 0;
  terms.entropyExploration = delta.valid
    ? constrain(delta.deltaEntropy / entropyContext.config.entropyDeltaScale, 0, 1) : 0;
  terms.entropyBalance = delta.valid
    ? 1.0f - constrain(abs(delta.deltaEntropy - entropyContext.config.targetDeltaEntropy)
      / entropyContext.config.balanceScale, 0, 1) : 0;
  int[] neighbors = dcrteSchedulerNeighbors(voxelIndex, snapshot.spec,
    entropyContext.propagationNeighborhood);
  int candidateNeighbors = 0, activeNeighbors = 0;
  for (int i = 0; i < neighbors.length; i++) {
    int neighbor = neighbors[i];
    if (!snapshot.candidateSolid[neighbor]) continue;
    candidateNeighbors++;
    if (state.active[neighbor]) activeNeighbors++;
  }
  terms.frontierCoherence = candidateNeighbors == 0 ? 0
    : activeNeighbors / (float)candidateNeighbors;
  float sdf = snapshot.signedDistance[voxelIndex];
  terms.interiorDepth = dcrteFinite(sdf)
    ? constrain(-sdf / entropyContext.maximumInteriorDepth, 0, 1) : 0;
  terms.intrinsicDirectionAvailable = snapshot.hasIntrinsic()
    && dcrteFinite(snapshot.intrinsicS[voxelIndex]);
  terms.intrinsicDirection = terms.intrinsicDirectionAvailable
    ? constrain(1.0f - snapshot.intrinsicS[voxelIndex], 0, 1) : 0;
  terms.coordinateConfidenceAvailable = snapshot.hasIntrinsic()
    && dcrteFinite(snapshot.intrinsicConfidence[voxelIndex]);
  terms.coordinateConfidence = terms.coordinateConfidenceAvailable
    ? constrain(snapshot.intrinsicConfidence[voxelIndex], 0, 1) : 0;
  terms.fieldComplexity = entropyContext.cache != null
    && entropyContext.cache.fieldValid[voxelIndex]
    ? constrain(entropyContext.cache.fieldEntropy[voxelIndex], 0, 1) : 0;
  terms.seededNoise = dcrteDeterministicUnitRandom(schedulerSeed, batchIndex,
    voxelIndex, DCRTE_ENTROPIC_RANDOM_SALT);
  terms.combinedScore = dcrteCombineEntropicScore(terms, weights);
  dcrteHbeApplyScoreOverlay(terms, voxelIndex, entropyContext, state, hbeBatch);
  terms.valid = dcrteEntropicTermsFinite(terms);
  return terms;
}

float dcrteCombineEntropicScore(SchedulerScoreTerms terms, SchedulerScoreWeights sourceWeights) {
  if (terms == null || sourceWeights == null || !sourceWeights.valid) return 0;
  float availableWeight = sourceWeights.fieldCompatibilityWeight
    + sourceWeights.relaxationWeight + sourceWeights.explorationWeight
    + sourceWeights.balanceWeight + sourceWeights.coherenceWeight
    + sourceWeights.interiorDepthWeight + sourceWeights.fieldComplexityWeight
    + sourceWeights.noiseWeight;
  if (terms.intrinsicDirectionAvailable) availableWeight += sourceWeights.intrinsicDirectionWeight;
  if (terms.coordinateConfidenceAvailable) availableWeight += sourceWeights.coordinateConfidenceWeight;
  if (availableWeight <= 0) return 0;
  float score = sourceWeights.fieldCompatibilityWeight * terms.fieldCompatibility
    + sourceWeights.relaxationWeight * terms.entropyRelaxation
    + sourceWeights.explorationWeight * terms.entropyExploration
    + sourceWeights.balanceWeight * terms.entropyBalance
    + sourceWeights.coherenceWeight * terms.frontierCoherence
    + sourceWeights.interiorDepthWeight * terms.interiorDepth
    + sourceWeights.fieldComplexityWeight * terms.fieldComplexity
    + sourceWeights.noiseWeight * terms.seededNoise;
  if (terms.intrinsicDirectionAvailable) score += sourceWeights.intrinsicDirectionWeight * terms.intrinsicDirection;
  if (terms.coordinateConfidenceAvailable) score += sourceWeights.coordinateConfidenceWeight * terms.coordinateConfidence;
  return constrain(score / availableWeight, 0, 1);
}

boolean dcrteEntropicTermsFinite(SchedulerScoreTerms terms) {
  return terms != null && dcrteFinite(terms.fieldCompatibility)
    && dcrteFinite(terms.entropyRelaxation) && dcrteFinite(terms.entropyExploration)
    && dcrteFinite(terms.entropyBalance) && dcrteFinite(terms.frontierCoherence)
    && dcrteFinite(terms.interiorDepth) && dcrteFinite(terms.intrinsicDirection)
    && dcrteFinite(terms.coordinateConfidence) && dcrteFinite(terms.fieldComplexity)
    && dcrteFinite(terms.seededNoise) && dcrteFinite(terms.combinedScore)
    && (!terms.hbeAvailable || dcrteFinite(terms.hbeNeckProximity)
      && dcrteFinite(terms.hbeBilateralBalance) && dcrteFinite(terms.hbeMirrorSupport)
      && dcrteFinite(terms.hbeConnectionGain) && dcrteFinite(terms.hbeFeedbackCoupling)
      && dcrteFinite(terms.hbeCrossLobeReachability) && dcrteFinite(terms.hbeCombinedScore))
    && terms.combinedScore >= 0 && terms.combinedScore <= 1;
}
