/* M6-HX Holographic Bridge Explorer configuration and declared semantics. */

final String DCRTE_HBE_VERSION = "1.0-m6-hx";
final String DCRTE_HBE_CITATION = "Biswas, D., Cheng, G., Karthikeyan, K., et al. (2026). Observation of gravity-like signatures in holographic codes on a quantum computer. arXiv:2607.12047v1. https://doi.org/10.48550/arXiv.2607.12047";
final String DCRTE_HBE_NONCLAIM = "Classical field, graph, and scheduler proxy only; no quantum, gravitational, or physical-wormhole claim is made.";

enum HBEState {
  DISABLED, CONFIGURED, SNAPSHOT_READY, RUNNING, COMPLETE, INVALIDATED, FAILED;
  String id() { return name().toLowerCase(); }
}

enum HBEInfluenceMode {
  ANALYSIS_ONLY, FIELD_ONLY, SCHEDULER_ONLY, FIELD_AND_SCHEDULER;
  String id() { return name().toLowerCase(); }
  boolean fieldEnabled() { return this == FIELD_ONLY || this == FIELD_AND_SCHEDULER; }
  boolean schedulerEnabled() { return this == SCHEDULER_ONLY || this == FIELD_AND_SCHEDULER; }
}

enum HBEFeedbackSource {
  MANUAL, KL_DIVERGENCE, COHERENCE_DEFICIT, WIGNER_NEGATIVITY_PROXY,
  QUASI_ENERGY, FOUNDATIONAL_COHERENCE_DEFICIT, ENTROPIC_STATE,
  COMPOSITE_NONLINEAR_FEEDBACK;
  String id() { return name().toLowerCase(); }
}

enum HBEMirrorPolicy {
  NEGATE_THETA, PI_MINUS_THETA, PRESERVE_THETA, AUTO_FRAME_CALIBRATED;
  String id() { return name().toLowerCase(); }
}

enum HBEDomainResponseMode {
  FIXED_LATENT_ENVELOPE, PAPER_INSPIRED_NECK_SHORTENING;
  String id() { return name().toLowerCase(); }
}

enum HBERadiusMode {
  FIXED, CONNECTIVITY_GAIN, STYLIZED_CONSTRICTION;
  String id() { return name().toLowerCase(); }
}

enum HBELobeProxyMode {
  OFF, MIRRORED_HIERARCHICAL_BRANCHING;
  String id() { return name().toLowerCase(); }
}

enum HBESeedMode {
  LEGACY, DUAL_ENDS, NECK_CENTER, MIRRORED_PAIR;
  String id() { return name().toLowerCase(); }
}

enum HBEScorePreset {
  BILATERAL_RELAXATION, BILATERAL_EXPLORATION, BRIDGE_SEEKING, CONNECTION_NEUTRAL;
  String id() { return name().toLowerCase(); }
}

class HBEConfig {
  HBEInfluenceMode influenceMode = HBEInfluenceMode.ANALYSIS_ONLY;
  HBEFeedbackSource feedbackSource = HBEFeedbackSource.COMPOSITE_NONLINEAR_FEEDBACK;
  HBEMirrorPolicy mirrorPolicy = HBEMirrorPolicy.AUTO_FRAME_CALIBRATED;
  HBEDomainResponseMode domainResponseMode = HBEDomainResponseMode.FIXED_LATENT_ENVELOPE;
  HBERadiusMode radiusMode = HBERadiusMode.FIXED;
  HBELobeProxyMode lobeProxyMode = HBELobeProxyMode.OFF;
  HBESeedMode seedMode = HBESeedMode.DUAL_ENDS;
  HBEScorePreset scorePreset = HBEScorePreset.BRIDGE_SEEKING;
  float manualFeedback = 0.50f;
  float coupling = 0.42f;
  float fieldAmplitude = 0.075f;
  float lobeProxyBlend = 0.0f;
  float lobeAxialFrequency = 5.0f;
  float lobeRadialFrequency = 3.0f;
  float lobeAngularFrequency = 5.0f;
  float schedulerWeight = 0.16f;
  float confidenceFloor = 0.20f;
  float anchorFraction = 0.12f;
  float neckMin = 0.40f;
  float neckMax = 0.60f;
  float lobeRadius = 0.52f;
  float lobeHalfLength = 0.56f;
  float neckRadius = 0.16f;
  float neckLengthMaximum = 0.80f;
  float neckLengthMinimum = 0.18f;
  int axialSegments = 160;
  int azimuthSegments = 96;
  int deterministicSeed = 62026;

  HBEConfig copy() {
    HBEConfig c = new HBEConfig();
    c.influenceMode = influenceMode; c.feedbackSource = feedbackSource;
    c.mirrorPolicy = mirrorPolicy; c.domainResponseMode = domainResponseMode;
    c.radiusMode = radiusMode; c.lobeProxyMode = lobeProxyMode;
    c.seedMode = seedMode; c.scorePreset = scorePreset;
    c.manualFeedback = manualFeedback; c.coupling = coupling;
    c.fieldAmplitude = fieldAmplitude; c.lobeProxyBlend = lobeProxyBlend;
    c.lobeAxialFrequency = lobeAxialFrequency; c.lobeRadialFrequency = lobeRadialFrequency;
    c.lobeAngularFrequency = lobeAngularFrequency; c.schedulerWeight = schedulerWeight;
    c.confidenceFloor = confidenceFloor; c.anchorFraction = anchorFraction;
    c.neckMin = neckMin; c.neckMax = neckMax;
    c.lobeRadius = lobeRadius; c.lobeHalfLength = lobeHalfLength;
    c.neckRadius = neckRadius; c.neckLengthMaximum = neckLengthMaximum;
    c.neckLengthMinimum = neckLengthMinimum; c.axialSegments = axialSegments;
    c.azimuthSegments = azimuthSegments; c.deterministicSeed = deterministicSeed;
    return c;
  }

  float effectiveNeckLength(float feedback) {
    if (domainResponseMode == HBEDomainResponseMode.FIXED_LATENT_ENVELOPE)
      return neckLengthMaximum;
    float t = constrain(feedback, 0, 1);
    return lerp(neckLengthMaximum, neckLengthMinimum, t);
  }

  String canonical() {
    return "version=" + DCRTE_HBE_VERSION + "\ninfluence=" + influenceMode.id()
      + "\nfeedback=" + feedbackSource.id() + "\nmirror=" + mirrorPolicy.id()
      + "\ndomain_response=" + domainResponseMode.id() + "\nradius=" + radiusMode.id()
      + "\nlobe_proxy=" + lobeProxyMode.id() + "\nlobe_proxy_blend=" + lobeProxyBlend
      + "\nlobe_axial_frequency=" + lobeAxialFrequency
      + "\nlobe_radial_frequency=" + lobeRadialFrequency
      + "\nlobe_angular_frequency=" + lobeAngularFrequency
      + "\nseed=" + seedMode.id() + "\nscore_preset=" + scorePreset.id()
      + "\nmanual=" + manualFeedback
      + "\ncoupling=" + coupling + "\nfield_amplitude=" + fieldAmplitude
      + "\nscheduler_weight=" + schedulerWeight + "\nconfidence_floor=" + confidenceFloor
      + "\nanchor_fraction=" + anchorFraction + "\nneck_min=" + neckMin
      + "\nneck_max=" + neckMax + "\nlobe_radius=" + lobeRadius
      + "\nlobe_half_length=" + lobeHalfLength + "\nneck_radius=" + neckRadius
      + "\nneck_length_max=" + neckLengthMaximum + "\nneck_length_min=" + neckLengthMinimum
      + "\naxial_segments=" + axialSegments + "\nazimuth_segments=" + azimuthSegments
      + "\ndeterministic_seed=" + deterministicSeed;
  }

  String configurationHash() { return dcrteSha256Hex(canonical()); }

  JSONObject toJSON() {
    JSONObject j = new JSONObject();
    j.setString("version", DCRTE_HBE_VERSION); j.setString("sha256", configurationHash());
    j.setString("influence_mode", influenceMode.id()); j.setString("feedback_source", feedbackSource.id());
    j.setString("mirror_policy", mirrorPolicy.id()); j.setString("domain_response_mode", domainResponseMode.id());
    j.setString("radius_mode", radiusMode.id()); j.setString("lobe_proxy_mode", lobeProxyMode.id());
    j.setString("seed_mode", seedMode.id());
    j.setString("score_preset", scorePreset.id());
    j.setFloat("manual_feedback", manualFeedback); j.setFloat("coupling", coupling);
    j.setFloat("field_amplitude", fieldAmplitude); j.setFloat("lobe_proxy_blend", lobeProxyBlend);
    j.setFloat("lobe_axial_frequency", lobeAxialFrequency);
    j.setFloat("lobe_radial_frequency", lobeRadialFrequency);
    j.setFloat("lobe_angular_frequency", lobeAngularFrequency);
    j.setFloat("scheduler_weight", schedulerWeight);
    j.setFloat("confidence_floor", confidenceFloor); j.setFloat("anchor_fraction", anchorFraction);
    j.setFloat("neck_min", neckMin); j.setFloat("neck_max", neckMax);
    j.setFloat("lobe_radius", lobeRadius); j.setFloat("lobe_half_length", lobeHalfLength);
    j.setFloat("neck_radius", neckRadius); j.setFloat("neck_length_maximum", neckLengthMaximum);
    j.setFloat("neck_length_minimum", neckLengthMinimum); j.setInt("axial_segments", axialSegments);
    j.setInt("azimuth_segments", azimuthSegments); j.setInt("deterministic_seed", deterministicSeed);
    return j;
  }
}

class HBEFrozenMetrics {
  final float kl;
  final float coherence;
  final float wignerNegativityProxy;
  final float quasiEnergyValue;
  final float foundationalCoherence;
  final float entropicState;
  final float simulationTime;
  final int fieldSeed;
  final float feedback;
  final String contentHash;

  HBEFrozenMetrics(HBEConfig config) {
    kl = metricKL; coherence = metricCoherence;
    wignerNegativityProxy = wignerNegativity; quasiEnergyValue = quasiEnergy;
    foundationalCoherence = coherenceBias; entropicState = metricEntropy;
    simulationTime = simT; fieldSeed = seed;
    feedback = dcrteHbeResolveFeedback(config, this);
    contentHash = dcrteSha256Hex(canonical());
  }

  HBEFrozenMetrics(float kl, float coherence, float wigner, float quasi,
      float foundational, float entropy, float simulationTime, int fieldSeed,
      HBEConfig config) {
    this.kl = kl; this.coherence = coherence; this.wignerNegativityProxy = wigner;
    this.quasiEnergyValue = quasi; this.foundationalCoherence = foundational;
    this.entropicState = entropy; this.simulationTime = simulationTime; this.fieldSeed = fieldSeed;
    feedback = dcrteHbeResolveFeedback(config, this);
    contentHash = dcrteSha256Hex(canonical());
  }

  String canonical() {
    return "kl=" + kl + "\ncoherence=" + coherence + "\nwigner_proxy=" + wignerNegativityProxy
      + "\nquasi_energy=" + quasiEnergyValue + "\nfoundational_coherence=" + foundationalCoherence
      + "\nentropic_state=" + entropicState + "\nsimulation_time=" + simulationTime
      + "\nfield_seed=" + fieldSeed + "\nfeedback=" + feedback;
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("sha256", contentHash);
    j.setFloat("kl_divergence", kl); j.setFloat("coherence", coherence);
    j.setFloat("wigner_negativity_proxy", wignerNegativityProxy);
    j.setFloat("quasi_energy", quasiEnergyValue); j.setFloat("foundational_coherence", foundationalCoherence);
    j.setFloat("entropic_state", entropicState); j.setFloat("simulation_time", simulationTime);
    j.setInt("field_seed", fieldSeed); j.setFloat("resolved_feedback", feedback);
    j.setString("magic_analog_definition", "frozen nonlinear-feedback control derived from declared Cosmosis metrics");
    j.setBoolean("quantum_nonstabilizerness_measurement", false);
    j.setBoolean("stabilizer_renyi_entropy_measurement", false);
    return j;
  }
}

float dcrteHbeResolveFeedback(HBEConfig config, HBEFrozenMetrics m) {
  if (config == null || m == null) return 0;
  if (config.feedbackSource == HBEFeedbackSource.MANUAL) return constrain(config.manualFeedback, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.KL_DIVERGENCE) return constrain(m.kl, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.COHERENCE_DEFICIT) return constrain(1 - m.coherence, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.WIGNER_NEGATIVITY_PROXY) return constrain(m.wignerNegativityProxy, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.QUASI_ENERGY) return constrain(m.quasiEnergyValue, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.FOUNDATIONAL_COHERENCE_DEFICIT) return constrain(1 - m.foundationalCoherence, 0, 1);
  if (config.feedbackSource == HBEFeedbackSource.ENTROPIC_STATE) return constrain(m.entropicState, 0, 1);
  float product = (0.20f + 0.80f * constrain(m.kl, 0, 1))
    * (0.25f + 0.75f * constrain(1 - m.coherence, 0, 1))
    * (0.30f + 0.70f * constrain(m.wignerNegativityProxy, 0, 1));
  return constrain(pow(product, 1.0f / 3.0f) * 0.72f
    + constrain(m.quasiEnergyValue, 0, 1) * 0.18f
    + constrain(m.entropicState, 0, 1) * 0.10f, 0, 1);
}

HBEConfig dcrteHbeConfig = new HBEConfig();
boolean dcrteHbeEnabled = false;
