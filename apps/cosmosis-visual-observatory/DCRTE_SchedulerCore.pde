/* DCRTE-ET Milestone 4 immutable candidate boundary and scheduler contracts. */

enum SchedulerMode {
  IMMEDIATE,
  FRONT_PROPAGATION,
  EMERGENT_ENTROPIC;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum SchedulerRunState {
  NOT_INITIALIZED, READY, RUNNING, PAUSED, COMPLETE, STOPPED, INVALIDATED, FAILED;
  String id() { return name().toLowerCase(); }
}

enum SchedulerStopReason {
  NONE, ALL_CANDIDATES_ACTIVE, FRONTIER_EMPTY, UNREACHABLE_CANDIDATES,
  MULTICOMPONENT_BLOCKED, MAX_BATCHES_REACHED, NO_ACCEPTED_UPDATES,
  CONFIGURATION_STALE, INVALID_DOMAIN, SEED_SELECTION_FAILED, USER_STOPPED,
  ENTROPIC_STABILITY_REACHED, ENTROPIC_STABLE_PARTIAL, ENTROPY_MODEL_INVALID,
  ENTROPY_CACHE_DIVERGENCE, ENTROPY_NONFINITE, SCORE_NONFINITE,
  SCORE_CONFIGURATION_INVALID, ACCEPTANCE_CONFIGURATION_INVALID,
  STOCHASTIC_HASH_FAILURE, RELATIONAL_PROGRESS_NONFINITE,
  STABILITY_CONFIGURATION_INVALID, THRESHOLD_STALL,
  ADAPTIVE_POLICY_EXHAUSTED, INTERNAL_ERROR;
  String id() { return name().toLowerCase(); }
}

enum SchedulerSeedMode {
  CENTER_NEAREST, INTRINSIC_START, INTRINSIC_END, COMPONENT_SEEDS;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum SchedulerComponentPolicy {
  SINGLE_INLET_REACHABLE_ONLY, SEED_EACH_COMPONENT, BLOCK_MULTICOMPONENT;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum SchedulerNeighborhoodMode {
  SIX_CONNECTED, EIGHTEEN_CONNECTED, TWENTY_SIX_CONNECTED;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum SchedulerPriorityMode {
  BREADTH_FIRST_LAYER, FIELD_COMPATIBILITY;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum SchedulerDiagnosticSeverity {
  INFO, WARNING, ERROR;
  String id() { return name().toLowerCase(); }
}

static class DCRTESchedulerCodes {
  static final String NOT_INITIALIZED = "SCH_NOT_INITIALIZED";
  static final String CANDIDATE_SNAPSHOT_INVALID = "SCH_CANDIDATE_SNAPSHOT_INVALID";
  static final String CONFIGURATION_STALE = "SCH_CONFIGURATION_STALE";
  static final String DOMAIN_INVALID = "SCH_DOMAIN_INVALID";
  static final String SEED_SELECTION_FAILED = "SCH_SEED_SELECTION_FAILED";
  static final String SEED_RELOCATED = "SCH_SEED_RELOCATED";
  static final String SEED_OUTSIDE_DOMAIN = "SCH_SEED_OUTSIDE_DOMAIN";
  static final String SEED_NOT_CANDIDATE = "SCH_SEED_NOT_CANDIDATE";
  static final String NO_CANDIDATES = "SCH_NO_CANDIDATES";
  static final String FRONTIER_EMPTY = "SCH_FRONTIER_EMPTY";
  static final String UNREACHABLE_CANDIDATES = "SCH_UNREACHABLE_CANDIDATES";
  static final String MULTICOMPONENT_BLOCKED = "SCH_MULTICOMPONENT_BLOCKED";
  static final String MAX_BATCHES_REACHED = "SCH_MAX_BATCHES_REACHED";
  static final String NO_ACCEPTED_UPDATES = "SCH_NO_ACCEPTED_UPDATES";
  static final String OUTSIDE_DOMAIN_ACTIVATION = "SCH_OUTSIDE_DOMAIN_ACTIVATION";
  static final String NONCANDIDATE_ACTIVATION = "SCH_NONCANDIDATE_ACTIVATION";
  static final String DUPLICATE_ACTIVATION = "SCH_DUPLICATE_ACTIVATION";
  static final String NONDETERMINISTIC_RESULT = "SCH_NONDETERMINISTIC_RESULT";
  static final String FRAME_RATE_DEPENDENCE = "SCH_FRAME_RATE_DEPENDENCE";
  static final String IMMEDIATE_MISMATCH = "SCH_IMMEDIATE_MISMATCH";
  static final String ARRIVAL_ORDER_INVALID = "SCH_ARRIVAL_ORDER_INVALID";
  static final String HISTORY_MISMATCH = "SCH_HISTORY_MISMATCH";
  static final String STATE_HASH_MISMATCH = "SCH_STATE_HASH_MISMATCH";
  static final String MATERIALIZER_STALE = "SCH_MATERIALIZER_STALE";
  static final String EXPORT_DISABLED = "SCH_EXPORT_DISABLED";
  static final String INTERNAL_ERROR = "SCH_INTERNAL_ERROR";
  static final String ENT_MODEL_NOT_INITIALIZED = "ENT_MODEL_NOT_INITIALIZED";
  static final String ENT_MODEL_CONFIGURATION_INVALID = "ENT_MODEL_CONFIGURATION_INVALID";
  static final String ENT_NEIGHBORHOOD_INVALID = "ENT_NEIGHBORHOOD_INVALID";
  static final String ENT_SUPPORT_TOO_LOW = "ENT_SUPPORT_TOO_LOW";
  static final String ENT_VALUE_NONFINITE = "ENT_VALUE_NONFINITE";
  static final String ENT_DELTA_NONFINITE = "ENT_DELTA_NONFINITE";
  static final String ENT_CACHE_MISMATCH = "ENT_CACHE_MISMATCH";
  static final String ENT_CACHE_HASH_MISMATCH = "ENT_CACHE_HASH_MISMATCH";
  static final String ENT_FIELD_RANGE_INVALID = "ENT_FIELD_RANGE_INVALID";
  static final String ENT_HISTOGRAM_INVALID = "ENT_HISTOGRAM_INVALID";
  static final String ENT_SCORE_WEIGHT_INVALID = "ENT_SCORE_WEIGHT_INVALID";
  static final String ENT_SCORE_ALL_ZERO = "ENT_SCORE_ALL_ZERO";
  static final String ENT_SCORE_TERM_UNAVAILABLE = "ENT_SCORE_TERM_UNAVAILABLE";
  static final String ENT_SCORE_NONFINITE = "ENT_SCORE_NONFINITE";
  static final String ENT_THRESHOLD_INVALID = "ENT_THRESHOLD_INVALID";
  static final String ENT_ACCEPTANCE_TEMPERATURE_INVALID = "ENT_ACCEPTANCE_TEMPERATURE_INVALID";
  static final String ENT_STATELESS_RANDOM_INVALID = "ENT_STATELESS_RANDOM_INVALID";
  static final String ENT_STOCHASTIC_ORDER_DEPENDENCE = "ENT_STOCHASTIC_ORDER_DEPENDENCE";
  static final String ENT_TAU_NONFINITE = "ENT_TAU_NONFINITE";
  static final String ENT_TAU_DECREASED = "ENT_TAU_DECREASED";
  static final String ENT_TAU_FORMULA_MISMATCH = "ENT_TAU_FORMULA_MISMATCH";
  static final String ENT_STABILITY_CONFIG_INVALID = "ENT_STABILITY_CONFIG_INVALID";
  static final String ENT_STABLE_PARTIAL_REACHED = "ENT_STABLE_PARTIAL_REACHED";
  static final String ENT_STABILITY_FALSE_POSITIVE = "ENT_STABILITY_FALSE_POSITIVE";
  static final String ENT_ADAPTIVE_TRANSITION_INVALID = "ENT_ADAPTIVE_TRANSITION_INVALID";
  static final String ENT_OUTSIDE_DOMAIN_ACTIVATION = "ENT_OUTSIDE_DOMAIN_ACTIVATION";
  static final String ENT_NONCANDIDATE_ACTIVATION = "ENT_NONCANDIDATE_ACTIVATION";
  static final String ENT_FRAME_RATE_DEPENDENCE = "ENT_FRAME_RATE_DEPENDENCE";
  static final String ENT_PAUSE_RESUME_MISMATCH = "ENT_PAUSE_RESUME_MISMATCH";
  static final String ENT_REPRODUCIBILITY_FAILURE = "ENT_REPRODUCIBILITY_FAILURE";
}

class CandidateVolumeSnapshot {
  final String snapshotId;
  final VolumeSpec spec;
  final boolean[] admitted;
  final boolean[] candidateSolid;
  final float[] fieldScalar;
  final float[] signedDistance;
  final float[] intrinsicS;
  final float[] intrinsicRho;
  final float[] intrinsicTheta;
  final float[] intrinsicConfidence;
  final float[] coordinateConfidence;
  final int admittedCount;
  final int candidateCount;
  final String fieldConfigurationId;
  final String domainConfigurationId;
  final String coordinateConfigurationId;
  final String materialConfigurationId;
  final long createdAtMillisDiagnosticOnly;
  final String diagnosticTimestamp;
  final String contentHash;
  final boolean valid;
  final String validationMessage;

  CandidateVolumeSnapshot(DCRTEVolume source, ObservationDomain domain, UniformGridObserver observer,
      SignedDistanceVolume sdf, IntrinsicCoordinateVolume intrinsic, DCRTEConfig config) {
    spec = dcrteCopyVolumeSpec(source == null ? null : source.spec);
    int count = spec == null ? 0 : max(0, spec.voxelCount());
    admitted = new boolean[count];
    candidateSolid = new boolean[count];
    fieldScalar = new float[count];
    signedDistance = new float[count];
    intrinsicS = intrinsic != null && intrinsic.s != null && intrinsic.s.length == count ? java.util.Arrays.copyOf(intrinsic.s, count) : null;
    intrinsicRho = intrinsic != null && intrinsic.normalizedRadius != null && intrinsic.normalizedRadius.length == count ? java.util.Arrays.copyOf(intrinsic.normalizedRadius, count) : null;
    intrinsicTheta = intrinsic != null && intrinsic.theta != null && intrinsic.theta.length == count ? java.util.Arrays.copyOf(intrinsic.theta, count) : null;
    coordinateConfidence = intrinsic != null && intrinsic.confidence != null && intrinsic.confidence.length == count ? java.util.Arrays.copyOf(intrinsic.confidence, count) : null;
    intrinsicConfidence = coordinateConfidence;
    java.util.Arrays.fill(signedDistance, Float.NaN);
    int admittedTotal = 0;
    int candidateTotal = 0;
    boolean sourceValid = source != null && source.isValid() && source.scalar.length == count;
    if (sourceValid) {
      for (int i = 0; i < count; i++) {
        admitted[i] = source.admitted[i];
        candidateSolid[i] = source.admitted[i] && source.candidateSolid[i];
        fieldScalar[i] = source.scalar[i];
        if (admitted[i]) admittedTotal++;
        if (candidateSolid[i]) candidateTotal++;
      }
      if (sdf != null && sdf.isValid() && sdf.signedDistance.length == count) {
        System.arraycopy(sdf.signedDistance, 0, signedDistance, 0, count);
      } else if (domain != null && observer != null && observer.isValid()) {
        for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
          int i = x + spec.nx * (y + spec.ny * z);
          signedDistance[i] = domain.signedDistance(observer.worldX(x), observer.worldY(y), observer.worldZ(z));
        }
      }
    }
    admittedCount = admittedTotal;
    candidateCount = candidateTotal;
    fieldConfigurationId = config == null ? "unknown" : config.configurationId;
    domainConfigurationId = dcrteSchedulerDomainConfigurationId();
    coordinateConfigurationId = dcrteSchedulerCoordinateConfigurationId();
    materialConfigurationId = dcrteSchedulerMaterialConfigurationId(config);
    createdAtMillisDiagnosticOnly = System.currentTimeMillis();
    diagnosticTimestamp = dcrteSchedulerTimestamp();
    contentHash = dcrteCandidateSnapshotHash(spec, admitted, candidateSolid, fieldScalar,
      signedDistance, intrinsicS, intrinsicRho, intrinsicTheta, coordinateConfidence,
      fieldConfigurationId, domainConfigurationId, coordinateConfigurationId,
      materialConfigurationId);
    snapshotId = "candidate-" + dcrteShortHash(contentHash, 16);
    valid = sourceValid && candidateCount > 0 && dcrteCandidateSubsetOfAdmission(admitted, candidateSolid);
    validationMessage = !sourceValid ? "source volume invalid"
      : candidateCount == 0 ? "no admitted candidate voxels"
      : !dcrteCandidateSubsetOfAdmission(admitted, candidateSolid) ? "candidate outside admission"
      : "valid";
  }

  int index(int x, int y, int z) { return x + spec.nx * (y + spec.ny * z); }
  boolean hasIntrinsic() { return intrinsicS != null && intrinsicRho != null && intrinsicConfidence != null; }
  boolean hasIntrinsicTheta() { return hasIntrinsic() && intrinsicTheta != null; }
  boolean hasSignedDistance() {
    for (int i = 0; i < signedDistance.length; i++) if (dcrteFinite(signedDistance[i])) return true;
    return false;
  }
  long estimatedBytes() {
    long total = admitted.length + candidateSolid.length + fieldScalar.length * 4L + signedDistance.length * 4L;
    if (intrinsicS != null) total += intrinsicS.length * 4L;
    if (intrinsicRho != null) total += intrinsicRho.length * 4L;
    if (intrinsicTheta != null) total += intrinsicTheta.length * 4L;
    if (intrinsicConfidence != null) total += intrinsicConfidence.length * 4L;
    return total;
  }
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", snapshotId);
    json.setString("sha256", contentHash);
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setInt("admitted_count", admittedCount);
    json.setInt("candidate_count", candidateCount);
    json.setString("field_configuration_id", fieldConfigurationId);
    json.setString("domain_configuration_id", domainConfigurationId);
    json.setString("coordinate_configuration_id", coordinateConfigurationId);
    json.setString("material_configuration_id", materialConfigurationId);
    json.setString("created_at_millis_diagnostic_only", Long.toString(createdAtMillisDiagnosticOnly));
    json.setString("diagnostic_timestamp", diagnosticTimestamp);
    json.setBoolean("intrinsic_available", hasIntrinsic());
    json.setBoolean("intrinsic_theta_available", hasIntrinsicTheta());
    json.setBoolean("signed_distance_available", hasSignedDistance());
    json.setBoolean("valid", valid);
    json.setString("validation", validationMessage);
    json.setString("estimated_storage_bytes", Long.toString(estimatedBytes()));
    return json;
  }
}

class SchedulerConfiguration {
  SchedulerMode mode = SchedulerMode.IMMEDIATE;
  SchedulerSeedMode seedMode = SchedulerSeedMode.CENTER_NEAREST;
  SchedulerComponentPolicy componentPolicy = SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY;
  SchedulerNeighborhoodMode neighborhoodMode = SchedulerNeighborhoodMode.SIX_CONNECTED;
  SchedulerPriorityMode priorityMode = SchedulerPriorityMode.BREADTH_FIRST_LAYER;
  int maxUpdatesPerBatch = 1024;
  int maximumBatches = 1000000;
  int deterministicSeed = 42017;
  EntropyConfiguration entropy = new EntropyConfiguration();

  SchedulerConfiguration copy() {
    SchedulerConfiguration c = new SchedulerConfiguration();
    c.mode = mode; c.seedMode = seedMode; c.componentPolicy = componentPolicy;
    c.neighborhoodMode = neighborhoodMode; c.priorityMode = priorityMode;
    c.maxUpdatesPerBatch = maxUpdatesPerBatch; c.maximumBatches = maximumBatches;
    c.deterministicSeed = deterministicSeed;
    c.entropy = entropy == null ? new EntropyConfiguration() : entropy.copy();
    return c;
  }
  String canonical() {
    return "mode=" + mode.id() + "\nseed=" + seedMode.id() + "\ncomponent=" + componentPolicy.id()
      + "\nneighborhood=" + neighborhoodMode.id() + "\npriority=" + priorityMode.id()
      + "\nmax_updates=" + maxUpdatesPerBatch + "\nmax_batches=" + maximumBatches
      + "\ndeterministic_seed=" + deterministicSeed
      + "\nentropy=" + (entropy == null ? "missing" : entropy.canonical());
  }
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("mode", mode.id());
    json.setString("seed_mode", seedMode.id());
    json.setString("component_policy", componentPolicy.id());
    json.setString("neighborhood", neighborhoodMode.id());
    json.setString("priority", priorityMode.id());
    json.setInt("max_updates_per_batch", maxUpdatesPerBatch);
    json.setInt("maximum_batches", maximumBatches);
    json.setInt("deterministic_seed", deterministicSeed);
    json.setJSONObject("entropy", entropy == null ? new JSONObject() : entropy.toJSON());
    return json;
  }
}

class SchedulerContext {
  final CandidateVolumeSnapshot snapshot;
  final SchedulerConfiguration configuration;
  final String configurationHash;
  final HBEExperimentSnapshot hbeSnapshot;
  int[] resolvedSeeds = new int[0];
  int candidateComponentCount;
  int[] componentLabels;

  SchedulerContext(CandidateVolumeSnapshot snapshot, SchedulerConfiguration configuration) {
    this(snapshot, configuration, null);
  }

  SchedulerContext(CandidateVolumeSnapshot snapshot, SchedulerConfiguration configuration,
      HBEExperimentSnapshot hbeSnapshot) {
    this.snapshot = snapshot;
    this.configuration = configuration == null ? new SchedulerConfiguration() : configuration.copy();
    configurationHash = dcrteSha256Hex(this.configuration.canonical());
    this.hbeSnapshot = hbeSnapshot != null && hbeSnapshot.matches(snapshot)
      ? hbeSnapshot : null;
  }
  boolean isValid() { return snapshot != null && snapshot.valid; }
  boolean hasHbeSchedulerChannel() {
    return hbeSnapshot != null && hbeSnapshot.schedulerChannelEnabled;
  }
}

class SchedulerBatch {
  int batchIndex;
  int[] activatedIndices = new int[0];
  int attemptedUpdates;
  int acceptedUpdates;
  int frontierCount;
  String stateHash = "";
  String event = "step";
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("batch_index", batchIndex);
    json.setInt("attempted_updates", attemptedUpdates);
    json.setInt("accepted_updates", acceptedUpdates);
    json.setInt("frontier_count", frontierCount);
    json.setString("state_hash", stateHash);
    json.setString("event", event);
    return json;
  }
}

interface FieldScheduler {
  String getId();
  String getVersion();
  boolean initialize(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics);
  SchedulerBatch step(SchedulerContext context, PropagationState state, SchedulerDiagnostics diagnostics);
  JSONObject toJSON();
}

VolumeSpec dcrteCopyVolumeSpec(VolumeSpec source) {
  if (source == null || source.bounds == null) return null;
  Bounds3D b = source.bounds;
  return new VolumeSpec(source.nx, source.ny, source.nz,
    new Bounds3D(b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ));
}

boolean dcrteCandidateSubsetOfAdmission(boolean[] admitted, boolean[] candidate) {
  if (admitted == null || candidate == null || admitted.length != candidate.length) return false;
  for (int i = 0; i < candidate.length; i++) if (candidate[i] && !admitted[i]) return false;
  return true;
}

String dcrteSchedulerTimestamp() {
  return nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2) + "T"
    + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
}

String dcrteSchedulerDomainConfigurationId() {
  String raw = dcrtePipelineMode.id() + "|" + dcrteObservationMode.id() + "|"
    + dcrteShellThicknessVoxels + "|" + dcrtePrimitiveDomainType.id() + "|"
    + (dcrteImportedSourceMesh == null ? "none" : dcrteImportedSourceMesh.sourceHashSha256) + "|"
    + dcrteImportedRotateX + "/" + dcrteImportedRotateY + "/" + dcrteImportedRotateZ + "|"
    + dcrteImportedScaleMultiplier;
  return dcrteSha256Hex(raw);
}

String dcrteSchedulerCoordinateConfigurationId() {
  return dcrteSha256Hex(dcrteCoordinateMode.id() + "|" + dcrteIntrinsicFallbackPolicy.id() + "|"
    + dcrteIntrinsicLongitudinalScale + "|" + dcrteIntrinsicRadialScale + "|" + dcrteIntrinsicRadialModel.id());
}

String dcrteSchedulerMaterialConfigurationId(DCRTEConfig config) {
  if (config == null) return "unknown";
  return dcrteSha256Hex(config.materialSourceModeValue + "|" + config.materialIndexValue + "|"
    + config.materialTargetValue + "|" + config.materialSourceIdValue);
}

String dcrteCandidateSnapshotHash(VolumeSpec spec, boolean[] admitted, boolean[] candidate,
    float[] scalar, float[] signedDistance, float[] intrinsicS, float[] intrinsicRho,
    float[] intrinsicTheta, float[] coordinateConfidence, String fieldId, String domainId,
    String coordinateId, String materialId) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    dcrteDigestString(digest, fieldId); dcrteDigestString(digest, domainId);
    dcrteDigestString(digest, coordinateId); dcrteDigestString(digest, materialId);
    if (spec != null) {
      dcrteDigestInt(digest, spec.nx); dcrteDigestInt(digest, spec.ny); dcrteDigestInt(digest, spec.nz);
      if (spec.bounds != null) {
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.minX));
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.minY));
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.minZ));
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.maxX));
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.maxY));
        dcrteDigestInt(digest, Float.floatToIntBits(spec.bounds.maxZ));
      }
    }
    for (int i = 0; i < candidate.length; i++) {
      digest.update((byte)(admitted[i] ? 1 : 0));
      digest.update((byte)(candidate[i] ? 1 : 0));
      dcrteDigestInt(digest, Float.floatToIntBits(scalar[i]));
    }
    dcrteDigestFloatArray(digest, signedDistance);
    dcrteDigestFloatArray(digest, intrinsicS);
    dcrteDigestFloatArray(digest, intrinsicRho);
    dcrteDigestFloatArray(digest, intrinsicTheta);
    dcrteDigestFloatArray(digest, coordinateConfidence);
    return dcrteHex(digest.digest());
  } catch (Exception error) { return "sha256-error"; }
}

String dcrteSha256Hex(String value) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    return dcrteHex(digest.digest((value == null ? "" : value).getBytes(java.nio.charset.StandardCharsets.UTF_8)));
  } catch (Exception error) { return "sha256-error"; }
}

void dcrteDigestString(java.security.MessageDigest digest, String value) {
  digest.update((value == null ? "" : value).getBytes(java.nio.charset.StandardCharsets.UTF_8));
  digest.update((byte)0);
}

void dcrteDigestInt(java.security.MessageDigest digest, int value) {
  digest.update((byte)(value >>> 24)); digest.update((byte)(value >>> 16));
  digest.update((byte)(value >>> 8)); digest.update((byte)value);
}

void dcrteDigestFloatArray(java.security.MessageDigest digest, float[] values) {
  if (values == null) {
    dcrteDigestInt(digest, -1);
    return;
  }
  dcrteDigestInt(digest, values.length);
  for (int i = 0; i < values.length; i++) dcrteDigestInt(digest, Float.floatToIntBits(values[i]));
}

String dcrteHex(byte[] bytes) {
  StringBuilder out = new StringBuilder();
  for (int i = 0; i < bytes.length; i++) out.append(String.format("%02x", bytes[i] & 0xff));
  return out.toString();
}

String dcrteShortHash(String hash, int count) {
  if (hash == null) return "-";
  return hash.substring(0, min(count, hash.length())).toUpperCase();
}
