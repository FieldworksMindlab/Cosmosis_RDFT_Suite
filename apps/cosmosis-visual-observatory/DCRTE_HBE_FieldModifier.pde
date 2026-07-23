/* M6-HX optional frozen field modifier. Identity is exact when inactive. */

interface DCRTEFieldModifier {
  float modify(float baseScalar, FieldCoordinateSample coordinate,
    int voxelIndex, HBEFieldContext context);
  String getId();
  String getVersion();
  JSONObject toJSON();
}

class HBEFieldContext {
  final HBEConfig config;
  final HBEIntrinsicObservables intrinsic;
  final float nonlinearFeedbackAnalog;
  final float couplingAnalog;
  final String contextHash;

  HBEFieldContext(HBEConfig config, HBEFrozenMetrics metrics,
      HBEIntrinsicObservables intrinsic) {
    this.config = config == null ? new HBEConfig() : config.copy();
    this.intrinsic = intrinsic;
    nonlinearFeedbackAnalog = metrics == null ? 0 : metrics.feedback;
    couplingAnalog = constrain(this.config.coupling, 0, 1);
    contextHash = dcrteSha256Hex(this.config.configurationHash() + "|"
      + (metrics == null ? "missing" : metrics.contentHash) + "|"
      + (intrinsic == null ? "missing" : intrinsic.sourceHash));
  }

  boolean isValidFor(VolumeSpec spec) {
    return intrinsic != null && intrinsic.isValid()
      && dcrteHbeSpecsEqual(intrinsic.spec, spec)
      && dcrteFinite(nonlinearFeedbackAnalog) && dcrteFinite(couplingAnalog);
  }
}

class HBEFieldSensitivityReport {
  int observedCount;
  int baseCandidateCount;
  int modifiedCandidateCount;
  int changedToCandidateCount;
  int changedFromCandidateCount;
  int neckCandidateCount;
  int leftCandidateCount;
  int rightCandidateCount;
  float meanAbsoluteDelta;
  float maximumAbsoluteDelta;
  String contextHash = "";
  float[] scalarDelta = new float[0];
  boolean[] changedToCandidate = new boolean[0];
  boolean[] changedFromCandidate = new boolean[0];

  void observe(int index, float baseScalar, float modifiedScalar,
      boolean baseCandidate, boolean modifiedCandidate, HBEFieldContext context) {
    if (context == null || context.intrinsic == null || index < 0
        || index >= context.intrinsic.valid.length || !context.intrinsic.valid[index]) return;
    if (scalarDelta.length != context.intrinsic.valid.length) {
      scalarDelta = new float[context.intrinsic.valid.length];
      changedToCandidate = new boolean[context.intrinsic.valid.length];
      changedFromCandidate = new boolean[context.intrinsic.valid.length];
    }
    observedCount++;
    if (baseCandidate) baseCandidateCount++;
    if (modifiedCandidate) modifiedCandidateCount++;
    if (!baseCandidate && modifiedCandidate) changedToCandidateCount++;
    if (baseCandidate && !modifiedCandidate) changedFromCandidateCount++;
    changedToCandidate[index] = !baseCandidate && modifiedCandidate;
    changedFromCandidate[index] = baseCandidate && !modifiedCandidate;
    if (modifiedCandidate && context.intrinsic.neckBand[index]) neckCandidateCount++;
    if (modifiedCandidate && context.intrinsic.xi[index] < 0) leftCandidateCount++;
    if (modifiedCandidate && context.intrinsic.xi[index] > 0) rightCandidateCount++;
    float delta = abs(modifiedScalar - baseScalar);
    scalarDelta[index] = modifiedScalar - baseScalar;
    meanAbsoluteDelta += delta;
    maximumAbsoluteDelta = max(maximumAbsoluteDelta, delta);
    contextHash = context.contextHash;
  }

  void finish() {
    if (observedCount > 0) meanAbsoluteDelta /= observedCount;
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject();
    j.setInt("observed_voxels", observedCount);
    j.setInt("base_candidate_count", baseCandidateCount);
    j.setInt("modified_candidate_count", modifiedCandidateCount);
    j.setInt("changed_to_candidate", changedToCandidateCount);
    j.setInt("changed_from_candidate", changedFromCandidateCount);
    j.setInt("neck_candidate_count", neckCandidateCount);
    j.setInt("left_candidate_count", leftCandidateCount);
    j.setInt("right_candidate_count", rightCandidateCount);
    j.setFloat("mean_absolute_scalar_delta", meanAbsoluteDelta);
    j.setFloat("maximum_absolute_scalar_delta", maximumAbsoluteDelta);
    j.setString("context_sha256", contextHash);
    return j;
  }
}

class HolographicBridgeFieldModifier implements DCRTEFieldModifier {
  public String getId() { return "hbe_frozen_neck_bridge"; }
  public String getVersion() { return "hbe-field-1"; }

  public float modify(float baseScalar, FieldCoordinateSample coordinate,
      int voxelIndex, HBEFieldContext context) {
    if (!dcrteFinite(baseScalar) || context == null
        || !context.config.influenceMode.fieldEnabled()
        || context.intrinsic == null || voxelIndex < 0
        || voxelIndex >= context.intrinsic.valid.length
        || !context.intrinsic.valid[voxelIndex]) return baseScalar;
    float n = constrain(context.intrinsic.neckProximity[voxelIndex], 0, 1);
    float xi = context.intrinsic.xi[voxelIndex];
    float theta = context.intrinsic.theta[voxelIndex];
    float rho = context.intrinsic.rho[voxelIndex];
    float m = constrain(context.nonlinearFeedbackAnalog, 0, 1);
    float e = constrain(context.couplingAnalog, 0, 1);
    float profile = n * n;
    float frozenPhase = (context.config.deterministicSeed & 1023) * TWO_PI / 1024.0f;
    float relief = context.config.fieldAmplitude * m * profile
      * sin(3.0f * xi + 4.0f * theta + 2.0f * m + frozenPhase);
    // The legacy material rule uses abs(scalar) < isoBand, so coupling moves
    // both scalar signs toward zero instead of assuming a positive bias helps.
    float bridgeGain = constrain(0.28f * e * profile, 0, 0.45f);
    float lobeDelta = 0;
    if (context.config.lobeProxyMode == HBELobeProxyMode.MIRRORED_HIERARCHICAL_BRANCHING
        && context.config.lobeProxyBlend > 0) {
      float lobeT = constrain((abs(xi) - 0.22f) / 0.78f, 0, 1);
      float lobeSupport = lobeT * lobeT * (3 - 2 * lobeT)
        * (1 - constrain(rho * 0.45f, 0, 0.85f));
      float orderedBranching = sin(context.config.lobeAxialFrequency * abs(xi)
        + context.config.lobeRadialFrequency * rho
        + context.config.lobeAngularFrequency * theta + frozenPhase);
      lobeDelta = context.config.fieldAmplitude * context.config.lobeProxyBlend
        * e * lobeSupport * orderedBranching;
    }
    if (profile <= 0 && lobeDelta == 0) return baseScalar;
    return baseScalar * (1.0f - bridgeGain) + relief + lobeDelta;
  }

  public JSONObject toJSON() {
    JSONObject j = new JSONObject();
    j.setString("id", getId()); j.setString("version", getVersion());
    j.setString("formula", "base*(1-0.28*e*n^2)+neck_relief+optional_mirrored_hierarchical_lobe_proxy");
    j.setString("candidate_rule", "abs(modified_scalar) < iso_band");
    j.setString("semantics", "classical frozen field proxy; ordered lobe branching is not a tensor network");
    return j;
  }
}

DCRTEFieldModifier dcrteHbeFieldModifier = new HolographicBridgeFieldModifier();
HBEFieldSensitivityReport dcrteHbeFieldSensitivity = new HBEFieldSensitivityReport();

HBEFieldContext dcrteHbePrepareFieldContext(VolumeSpec spec) {
  if (!dcrteHbeEnabled || dcrteHbeConfig == null
      || !dcrteHbeConfig.influenceMode.fieldEnabled()) return null;
  HBEFieldContext context = new HBEFieldContext(dcrteHbeConfig,
    dcrteHbePreparedMetrics, dcrteHbePreparedObservables);
  return context.isValidFor(spec) ? context : null;
}
