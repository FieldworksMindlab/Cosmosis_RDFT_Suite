/* DCRTE-ET Milestone 5 entropy, scheduler, acceptance, and benchmark fixtures. */

class DCRTEM5TestReport extends DCRTEM4TestReport {}

class DCRTEM5RunResult {
  CandidateVolumeSnapshot snapshot;
  SchedulerConfiguration configuration;
  SchedulerContext context;
  PropagationState state;
  SchedulerDiagnostics diagnostics;
  EmergentEntropicScheduler scheduler;
  int executedSteps;
  long runtimeNanos;

  boolean terminal() {
    return state != null && (state.runState == SchedulerRunState.COMPLETE
      || state.runState == SchedulerRunState.STOPPED
      || state.runState == SchedulerRunState.FAILED
      || state.runState == SchedulerRunState.INVALIDATED);
  }
}

DCRTEM5TestReport dcrteM5Tests = new DCRTEM5TestReport();

DCRTEM5TestReport runDcrteMilestone5Tests() {
  DCRTEM5TestReport tests = new DCRTEM5TestReport();
  try {
    float expectedQuarter = (float)(-(0.25 * Math.log(0.25)
      + 0.75 * Math.log(0.75)) / Math.log(2.0));
    tests.check(abs(dcrteBinaryEntropy(0, 4)) <= 0.000001f
      && abs(dcrteBinaryEntropy(2, 4) - 1) <= 0.000001f
      && abs(dcrteBinaryEntropy(4, 4)) <= 0.000001f
      && abs(dcrteBinaryEntropy(1, 4) - expectedQuarter) <= 0.000001f
      && abs(dcrteBinaryEntropy(3, 4) - expectedQuarter) <= 0.000001f,
      "binary occupancy entropy matches normalized Shannon fixtures");

    CandidateVolumeSnapshot cube = dcrteM4BoxSnapshot(5, false, false);
    SchedulerConfiguration base = dcrteM5Configuration(
      EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K);
    EntropyConfiguration entropyConfig = base.entropy.copy();
    entropyConfig.minimumSupport = 1;
    EntropyContext entropyContext = new EntropyContext(cube,
      SchedulerNeighborhoodMode.SIX_CONNECTED, entropyConfig);
    PropagationState localState = new PropagationState(cube.spec.voxelCount());
    BinaryOccupancyEntropy occupancy = new BinaryOccupancyEntropy();
    FieldHistogramEntropy field = new FieldHistogramEntropy();
    occupancy.initialize(entropyContext);
    field.initialize(entropyContext);
    int center = dcrteM5Index(cube.spec, 2, 2, 2);
    int corner = dcrteM5Index(cube.spec, 0, 0, 0);
    tests.check(occupancy.supportAt(center) == 27
      && occupancy.supportAt(corner) == 8,
      "candidate-only entropy support is exact and never wraps at boundaries");

    DCRTEVolume filteredVolume = dcrteM4BoxVolume(3, false, false);
    int filteredCenter = dcrteM5Index(filteredVolume.spec, 1, 1, 1);
    filteredVolume.candidateSolid[filteredCenter] = false;
    filteredVolume.candidateSolidCount--;
    CandidateVolumeSnapshot filteredSnapshot =
      dcrteM4Snapshot(filteredVolume, null, null);
    EntropyContext filteredContext = new EntropyContext(filteredSnapshot,
      SchedulerNeighborhoodMode.SIX_CONNECTED, entropyConfig);
    BinaryOccupancyEntropy filteredOccupancy = new BinaryOccupancyEntropy();
    filteredOccupancy.initialize(filteredContext);
    tests.check(filteredSnapshot.admitted[filteredCenter]
      && !filteredSnapshot.candidateSolid[filteredCenter]
      && filteredOccupancy.supportAt(
        dcrteM5Index(filteredSnapshot.spec, 0, 0, 0)) == 7,
      "candidate-only support excludes admitted noncandidate voxels");

    PropagationState emptyHypotheticalState =
      new PropagationState(cube.spec.voxelCount());
    boolean[] emptyBefore = java.util.Arrays.copyOf(
      emptyHypotheticalState.active, emptyHypotheticalState.active.length);
    EntropyDelta exactHypothetical = occupancy.evaluateActivation(center,
      emptyHypotheticalState);
    float exactDelta = dcrteBinaryEntropy(1, 27);
    tests.check(exactHypothetical.valid
      && exactHypothetical.affectedCenterCount == 27
      && abs(exactHypothetical.beforeEntropy) <= 0.000001f
      && abs(exactHypothetical.afterEntropy - exactDelta) <= 0.000001f
      && abs(exactHypothetical.deltaEntropy - exactDelta) <= 0.000001f
      && abs(exactHypothetical.absoluteDeltaEntropy - exactDelta) <= 0.000001f
      && java.util.Arrays.equals(emptyBefore, emptyHypotheticalState.active),
      "exact empty-cube activation delta matches every affected center");

    localState.active[center] = true;
    localState.activeCount = 1;
    int activation = dcrteM5Index(cube.spec, 3, 2, 2);
    boolean[] beforeHypothetical = java.util.Arrays.copyOf(localState.active,
      localState.active.length);
    EntropyDelta hypothetical = occupancy.evaluateActivation(activation,
      localState);
    tests.check(hypothetical.valid && hypothetical.affectedCenterCount == 27
      && java.util.Arrays.equals(beforeHypothetical, localState.active),
      "hypothetical activation evaluates every affected center without mutating state");

    EntropyCache cache = new EntropyCache(entropyContext, occupancy, field);
    entropyContext.cache = cache;
    cache.build(localState);
    localState.active[activation] = true;
    localState.activeCount++;
    SchedulerBatch cacheBatch = new SchedulerBatch();
    cacheBatch.activatedIndices = new int[] { activation };
    cache.updateAffected(cacheBatch, localState);
    EntropyCacheVerification cacheVerification =
      cache.verifyAgainstFullRecompute(localState, 0.000001f);
    tests.check(cacheVerification.pass
      && cacheVerification.maximumOccupancyError <= 0.000001f,
      "incremental entropy cache equals exact full recomputation");

    DCRTEVolume constantVolume = dcrteM4BoxVolume(5, false, false);
    java.util.Arrays.fill(constantVolume.scalar, 0.375f);
    CandidateVolumeSnapshot constantSnapshot =
      dcrteM4Snapshot(constantVolume, null, null);
    EntropyContext constantContext = new EntropyContext(constantSnapshot,
      SchedulerNeighborhoodMode.SIX_CONNECTED, entropyConfig);
    FieldHistogramEntropy constantField = new FieldHistogramEntropy();
    constantField.initialize(constantContext);
    tests.check(constantField.isValid()
      && abs(constantField.sampleAt(center, localState).entropy) <= 0.000001f,
      "constant field histogram entropy is exactly zero");

    DCRTEVolume uniformVolume = dcrteM4BoxVolume(3, false, false);
    java.util.Arrays.fill(uniformVolume.scalar, 0);
    int[] uniformIndices = {
      dcrteM5Index(uniformVolume.spec, 0, 0, 0),
      dcrteM5Index(uniformVolume.spec, 1, 0, 0),
      dcrteM5Index(uniformVolume.spec, 0, 1, 0),
      dcrteM5Index(uniformVolume.spec, 1, 1, 0),
      dcrteM5Index(uniformVolume.spec, 0, 0, 1),
      dcrteM5Index(uniformVolume.spec, 1, 0, 1),
      dcrteM5Index(uniformVolume.spec, 0, 1, 1),
      dcrteM5Index(uniformVolume.spec, 1, 1, 1)
    };
    for (int i = 0; i < uniformIndices.length; i++)
      uniformVolume.scalar[uniformIndices[i]] = i;
    CandidateVolumeSnapshot uniformSnapshot =
      dcrteM4Snapshot(uniformVolume, null, null);
    EntropyConfiguration uniformConfig = entropyConfig.copy();
    uniformConfig.fieldHistogramBins = 8;
    EntropyContext uniformContext = new EntropyContext(uniformSnapshot,
      SchedulerNeighborhoodMode.SIX_CONNECTED, uniformConfig);
    FieldHistogramEntropy uniformField = new FieldHistogramEntropy();
    uniformField.initialize(uniformContext);
    LocalEntropySample uniformSample = uniformField.sampleAt(
      dcrteM5Index(uniformSnapshot.spec, 0, 0, 0),
      new PropagationState(uniformSnapshot.spec.voxelCount()));
    tests.check(uniformSample.valid
      && abs(uniformSample.entropy - 1) <= 0.000001f,
      "eight uniformly occupied field bins have normalized entropy one");

    DCRTEVolume twoBinVolume = dcrteM4BoxVolume(3, false, false);
    java.util.Arrays.fill(twoBinVolume.scalar, 0);
    int twoBinCenter = dcrteM5Index(twoBinVolume.spec, 1, 1, 1);
    int highBinCount = 0;
    for (int z = 0; z < 3; z++) for (int y = 0; y < 3; y++)
      for (int x = 0; x < 3; x++) {
        int index = dcrteM5Index(twoBinVolume.spec, x, y, z);
        if (index != twoBinCenter && highBinCount++ < 13)
          twoBinVolume.scalar[index] = 7;
      }
    CandidateVolumeSnapshot twoBinSnapshot =
      dcrteM4Snapshot(twoBinVolume, null, null);
    EntropyConfiguration twoBinConfig = uniformConfig.copy();
    twoBinConfig.includeCenterVoxel = false;
    EntropyContext twoBinContext = new EntropyContext(twoBinSnapshot,
      SchedulerNeighborhoodMode.SIX_CONNECTED, twoBinConfig);
    FieldHistogramEntropy twoBinField = new FieldHistogramEntropy();
    twoBinField.initialize(twoBinContext);
    LocalEntropySample twoBinSample = twoBinField.sampleAt(twoBinCenter,
      new PropagationState(twoBinSnapshot.spec.voxelCount()));
    tests.check(twoBinSample.valid && twoBinSample.supportCount == 26
      && abs(twoBinSample.entropy - 1.0f / 3.0f) <= 0.000001f,
      "two equally occupied bins normalize to ln(2) over ln(8)");

    SchedulerScoreWeights weights = new PresetEntropyPolicy(
      EntropicPolicyMode.RELAXATION).baseWeights(
        EntropicPolicyMode.RELAXATION);
    boolean normalized = weights.validateAndNormalize();
    tests.check(normalized && abs(dcrteM5WeightSum(weights) - 1) <= 0.000001f,
      "named score-policy weights normalize to one");
    SchedulerScoreWeights negative = new SchedulerScoreWeights();
    negative.fieldCompatibilityWeight = -1;
    SchedulerScoreWeights zero = new SchedulerScoreWeights();
    tests.check(!negative.validateAndNormalize() && !zero.validateAndNormalize(),
      "negative and all-zero score weights are rejected");

    SchedulerScoreTerms entropyDecrease = dcrteM5SyntheticTerms(1, 0);
    SchedulerScoreTerms entropyIncrease = dcrteM5SyntheticTerms(0, 1);
    SchedulerScoreWeights relaxationWeights = new PresetEntropyPolicy(
      EntropicPolicyMode.RELAXATION).baseWeights(EntropicPolicyMode.RELAXATION);
    SchedulerScoreWeights explorationWeights = new PresetEntropyPolicy(
      EntropicPolicyMode.EXPLORATION).baseWeights(EntropicPolicyMode.EXPLORATION);
    relaxationWeights.validateAndNormalize();
    explorationWeights.validateAndNormalize();
    tests.check(dcrteCombineEntropicScore(entropyDecrease, relaxationWeights)
        > dcrteCombineEntropicScore(entropyIncrease, relaxationWeights)
      && dcrteCombineEntropicScore(entropyIncrease, explorationWeights)
        > dcrteCombineEntropicScore(entropyDecrease, explorationWeights),
      "relaxation and exploration rank opposite entropy events as declared");

    float randomA = dcrteDeterministicUnitRandom(42L, 3, 17,
      DCRTE_ENTROPIC_RANDOM_SALT);
    float randomB = dcrteDeterministicUnitRandom(42L, 3, 17,
      DCRTE_ENTROPIC_RANDOM_SALT);
    float randomC = dcrteDeterministicUnitRandom(42L, 4, 17,
      DCRTE_ENTROPIC_RANDOM_SALT);
    tests.check(randomA == randomB && randomA >= 0 && randomA < 1
      && randomC >= 0 && randomC < 1 && randomA != randomC,
      "stateless seeded random is reproducible, bounded, and event-keyed");
    int changedSeedEvents = 0;
    for (int i = 0; i < 32; i++)
      if (dcrteDeterministicUnitRandom(42L, 3, i,
          DCRTE_ENTROPIC_RANDOM_SALT)
          != dcrteDeterministicUnitRandom(43L, 3, i,
          DCRTE_ENTROPIC_RANDOM_SALT)) changedSeedEvents++;
    tests.check(changedSeedEvents > 0,
      "changing the stochastic seed changes at least one frontier event");

    EntropyConfiguration adaptiveConfig = entropyConfig.copy();
    adaptiveConfig.stagnationTrigger = 1;
    adaptiveConfig.explorationBoostDuration = 2;
    EntropicPolicyState adaptiveState = new EntropicPolicyState();
    adaptiveState.initialize(adaptiveConfig);
    String adaptiveBoost = adaptiveState.updateAfterBatch(0, 8, adaptiveConfig);
    String adaptiveRecovery = adaptiveState.updateAfterBatch(2, 8, adaptiveConfig);
    tests.check(adaptiveBoost.equals("exploration_boost")
      && (adaptiveRecovery.equals("exploration_decay")
        || adaptiveRecovery.equals("return_to_relaxation"))
      && adaptiveState.transitionCount == 2,
      "adaptive policy enters exploration on stagnation and decays after growth resumes");

    float sigmoidLow = dcrteEntropicSigmoid(-2);
    float sigmoidMid = dcrteEntropicSigmoid(0);
    float sigmoidHigh = dcrteEntropicSigmoid(2);
    tests.check(dcrteFinite(sigmoidLow) && sigmoidLow < sigmoidMid
      && sigmoidMid < sigmoidHigh && abs(sigmoidMid - 0.5f) <= 0.000001f
      && dcrteEntropicSigmoid(-20) <= 0.000001f
      && dcrteEntropicSigmoid(20) >= 0.999999f,
      "sigmoid acceptance is finite, monotonic, and threshold-like at extremes");

    RelationalProgressTracker progress = new RelationalProgressTracker();
    RelationalProgressConfiguration progressConfig =
      new RelationalProgressConfiguration();
    progress.initialize(progressConfig);
    RelationalProgressIncrement zeroIncrement =
      progress.update(0, 100, 0, 20, 20);
    RelationalProgressIncrement knownIncrement =
      progress.update(10, 100, 0.2f, 20, 30);
    tests.check(zeroIncrement.deltaTau == 0
      && abs((float)knownIncrement.deltaTau - 0.325f) <= 0.000001f
      && progress.tauRaw >= knownIncrement.deltaTau && progress.isValid(),
      "relational progress is nondecreasing and matches the versioned formula");

    EntropicStabilityConfiguration stabilityConfig =
      new EntropicStabilityConfiguration();
    stabilityConfig.minimumBatches = 0;
    stabilityConfig.observationWindow = 2;
    stabilityConfig.requiredStableWindows = 2;
    stabilityConfig.activationFractionEpsilon = 0.001f;
    stabilityConfig.entropyDeltaEpsilon = 0.001f;
    stabilityConfig.frontierChangeEpsilon = 0.001f;
    stabilityConfig.maximumScoreEpsilon = 0.001f;
    EntropicStabilityDetector detector =
      new EntropicStabilityDetector(stabilityConfig);
    detector.update(1, 5, 100, 0, 20, 20, 0.5f, 0.5f);
    tests.check(!detector.isStable(),
      "continuing activation does not satisfy entropic stability");
    detector.reset();
    for (int i = 0; i < 3; i++)
      detector.update(i + 1, 0, 100, 0, 20, 20, 0.4f, 0.5f);
    tests.check(detector.isStable(),
      "all configured quiet-window criteria produce a stable state");
    detector.update(4, 2, 100, 0, 20, 20, 0.4f, 0.5f);
    tests.check(!detector.isStable()
      && detector.state.consecutiveStableWindows == 0,
      "a broken window resets conditional stability");

    DCRTEM5RunResult deterministicA = dcrteM5Run(cube, base, 1, -1);
    DCRTEM5RunResult deterministicB = dcrteM5Run(cube, base, 20, -1);
    tests.check(dcrteM5SameOutcome(deterministicA, deterministicB),
      "entropic execution is independent of scheduler batches per render frame");
    tests.check(dcrteM4NoGateViolations(cube, deterministicA.state)
      && deterministicA.scheduler.lastCacheVerification.pass,
      "entropic scheduler preserves domain gates and exact entropy cache");

    DCRTEM5RunResult paused = dcrteM5Run(cube, base, 1, 3);
    tests.check(dcrteM5SameOutcome(deterministicA, paused),
      "entropic pause and resume preserve arrival order, tau, and final hash");

    SchedulerConfiguration exploration = dcrteM5Configuration(
      EntropicPolicyMode.EXPLORATION, AcceptanceMode.DETERMINISTIC_TOP_K);
    DCRTEM5RunResult explorationRun = dcrteM5Run(cube, exploration, 1, -1);
    tests.check(explorationRun.terminal()
      && !deterministicA.configuration.canonical().equals(
        explorationRun.configuration.canonical())
      && !deterministicA.scheduler.currentWeights.toJSON().toString().equals(
        explorationRun.scheduler.currentWeights.toJSON().toString()),
      "relaxation and exploration retain distinct declared score policies");

    SchedulerConfiguration stochastic = dcrteM5Configuration(
      EntropicPolicyMode.EXPLORATION, AcceptanceMode.SEEDED_STOCHASTIC);
    stochastic.entropy.scoreThreshold = 0.5f;
    DCRTEM5RunResult stochasticA = dcrteM5Run(cube, stochastic, 1, -1);
    DCRTEM5RunResult stochasticB = dcrteM5Run(cube, stochastic, 7, -1);
    tests.check(dcrteM5SameOutcome(stochasticA, stochasticB),
      "seeded stochastic acceptance is reproducible across execution grouping");

    SchedulerConfiguration invalid = dcrteM5Configuration(
      EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K);
    invalid.entropy.fieldHistogramBins = 1;
    DCRTEM5RunResult invalidRun = dcrteM5Run(cube, invalid, 1, -1);
    tests.check(invalidRun.state.runState == SchedulerRunState.FAILED
      && invalidRun.state.stopReason == SchedulerStopReason.ENTROPY_MODEL_INVALID,
      "invalid entropy configuration blocks initialization explicitly");

    JSONObject provenance = deterministicA.scheduler.toJSON();
    tests.check(provenance.getString("clock_claim").equals("none")
      && provenance.getString("progress_interpretation").indexOf(
        "dimensionless") >= 0
      && provenance.getJSONObject("dynamic_entropy_model")
        .getString("id").equals("binary_occupancy_entropy")
      && provenance.getJSONObject("static_field_entropy_model")
        .getString("id").equals("field_histogram_entropy"),
      "M5 provenance versions entropy models and makes no physical-time claim");

    SchedulerConfiguration immediateConfig = new SchedulerConfiguration();
    immediateConfig.mode = SchedulerMode.IMMEDIATE;
    PropagationState immediate = dcrteM4Run(cube, immediateConfig,
      new SchedulerDiagnostics());
    PropagationState front = dcrteM4Run(cube, dcrteM4FrontConfiguration(),
      new SchedulerDiagnostics());
    tests.check(dcrteM4Tests.ok()
      && immediate.runState == SchedulerRunState.COMPLETE
      && front.runState == SchedulerRunState.COMPLETE,
      "M4 Immediate and Front Propagation baselines remain unchanged");
  }
  catch (Exception error) {
    tests.check(false, "M5 deterministic test exception: "
      + error.getClass().getSimpleName() + " " + error.getMessage());
  }
  return tests;
}

SchedulerScoreTerms dcrteM5SyntheticTerms(float relaxation, float exploration) {
  SchedulerScoreTerms terms = new SchedulerScoreTerms();
  terms.fieldCompatibility = 0.5f;
  terms.entropyRelaxation = relaxation;
  terms.entropyExploration = exploration;
  terms.entropyBalance = 0.5f;
  terms.frontierCoherence = 0.5f;
  terms.interiorDepth = 0.5f;
  terms.fieldComplexity = 0.5f;
  terms.seededNoise = 0.5f;
  terms.intrinsicDirectionAvailable = false;
  terms.coordinateConfidenceAvailable = false;
  return terms;
}

SchedulerConfiguration dcrteM5Configuration(EntropicPolicyMode policy,
    AcceptanceMode acceptance) {
  SchedulerConfiguration config = new SchedulerConfiguration();
  config.mode = SchedulerMode.EMERGENT_ENTROPIC;
  config.seedMode = SchedulerSeedMode.CENTER_NEAREST;
  config.componentPolicy = SchedulerComponentPolicy.SEED_EACH_COMPONENT;
  config.neighborhoodMode = SchedulerNeighborhoodMode.SIX_CONNECTED;
  config.priorityMode = SchedulerPriorityMode.BREADTH_FIRST_LAYER;
  config.maximumBatches = 4096;
  config.entropy.policyMode = policy;
  config.entropy.acceptanceMode = acceptance;
  config.entropy.minimumSupport = 1;
  config.entropy.maxUpdatesPerBatch = 8;
  config.entropy.minimumTopKScore = 0;
  config.entropy.scoreThreshold = 0.55f;
  config.entropy.verificationInterval = 5;
  config.entropy.scoreExportMode = ScoreExportMode.TOP_K_PER_BATCH;
  config.entropy.scoreExportK = 16;
  config.entropy.stability.minimumBatches = 100000;
  config.entropy.stability.allowStablePartial = false;
  return config;
}

DCRTEM5RunResult dcrteM5Run(CandidateVolumeSnapshot snapshot,
    SchedulerConfiguration source, int batchesPerFrame, int pauseAfter) {
  DCRTEM5RunResult result = new DCRTEM5RunResult();
  result.snapshot = snapshot;
  result.configuration = source.copy();
  result.context = new SchedulerContext(snapshot, result.configuration);
  result.state = new PropagationState(snapshot == null || snapshot.spec == null
    ? 0 : snapshot.spec.voxelCount());
  result.diagnostics = new SchedulerDiagnostics();
  result.scheduler = new EmergentEntropicScheduler();
  long started = System.nanoTime();
  if (!result.scheduler.initialize(result.context, result.state,
      result.diagnostics)) {
    result.runtimeNanos = System.nanoTime() - started;
    return result;
  }
  int guard = max(1, result.configuration.maximumBatches + 2);
  while (!result.terminal() && guard-- > 0) {
    int budget = max(1, batchesPerFrame);
    for (int i = 0; i < budget && !result.terminal(); i++) {
      result.scheduler.step(result.context, result.state, result.diagnostics);
      result.executedSteps++;
      if (pauseAfter >= 0 && result.executedSteps == pauseAfter)
        result.state.runState = SchedulerRunState.PAUSED;
    }
  }
  result.runtimeNanos = System.nanoTime() - started;
  return result;
}

boolean dcrteM5SameOutcome(DCRTEM5RunResult a, DCRTEM5RunResult b) {
  if (a == null || b == null || a.state == null || b.state == null
      || a.scheduler == null || b.scheduler == null) return false;
  return a.state.runState == b.state.runState
    && a.state.stopReason == b.state.stopReason
    && java.util.Arrays.equals(a.state.active, b.state.active)
    && java.util.Arrays.equals(a.state.arrivalBatch, b.state.arrivalBatch)
    && java.util.Arrays.equals(a.state.arrivalRank, b.state.arrivalRank)
    && a.state.stateHash.equals(b.state.stateHash)
    && abs((float)(a.scheduler.progress.tauRaw
      - b.scheduler.progress.tauRaw)) <= 0.000001f
    && a.scheduler.policyState.toJSON().toString().equals(
      b.scheduler.policyState.toJSON().toString())
    && a.scheduler.entropicHistory.size() == b.scheduler.entropicHistory.size();
}

int dcrteM5Index(VolumeSpec spec, int x, int y, int z) {
  return x + spec.nx * (y + spec.ny * z);
}

float dcrteM5WeightSum(SchedulerScoreWeights weights) {
  return weights.fieldCompatibilityWeight + weights.relaxationWeight
    + weights.explorationWeight + weights.balanceWeight
    + weights.coherenceWeight + weights.interiorDepthWeight
    + weights.intrinsicDirectionWeight
    + weights.coordinateConfidenceWeight
    + weights.fieldComplexityWeight + weights.noiseWeight;
}

void runDcrteMilestone5AcceptanceMatrix() {
  println("DCRTE-ET Milestone 5 acceptance matrix starting...");
  JSONArray cases = new JSONArray();
  int passed = 0;
  CandidateVolumeSnapshot cylinder = dcrteM4SnapshotFromSdf(
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.CYLINDER, 18), null);
  SignedDistanceVolume eggSdf =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 18);
  IntrinsicBuildResult eggIntrinsic =
    new DCRTEIntrinsicCoordinateBuilder().build(eggSdf, null, true);
  CandidateVolumeSnapshot egg = dcrteM4SnapshotFromSdf(eggSdf,
    eggIntrinsic == null ? null : eggIntrinsic.volume);
  SignedDistanceVolume bentSdf =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.BENT_CAPSULE, 18);
  IntrinsicBuildResult bentIntrinsic =
    new DCRTEIntrinsicCoordinateBuilder().build(bentSdf, null, true);
  CandidateVolumeSnapshot bent = dcrteM4SnapshotFromSdf(bentSdf,
    bentIntrinsic == null ? null : bentIntrinsic.volume);
  CandidateVolumeSnapshot disconnected = dcrteM4BoxSnapshot(9, false, true);

  DCRTEM5RunResult caseA = dcrteM5AcceptanceRun(cylinder,
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  passed += dcrteM5AcceptanceCase(cases, "M5-A", "primitive cylinder",
    "Cartesian", caseA, "pass") ? 1 : 0;
  DCRTEM5RunResult caseB = dcrteM5AcceptanceRun(cylinder,
    EntropicPolicyMode.EXPLORATION, AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  boolean differentOrdering = caseA.state != null && caseB.state != null
    && !java.util.Arrays.equals(caseA.state.arrivalRank, caseB.state.arrivalRank);
  passed += dcrteM5AcceptanceCase(cases, "M5-B", "primitive cylinder",
    "Cartesian", caseB, differentOrdering ? "different ordering"
      : "ordering-difference failure") ? 1 : 0;

  SchedulerConfiguration cConfig = dcrteM5Configuration(
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_THRESHOLD);
  cConfig.seedMode = SchedulerSeedMode.INTRINSIC_START;
  cConfig.entropy.scoreThreshold = 0.20f;
  DCRTEM5RunResult caseC = dcrteM5Run(egg, cConfig, 20, -1);
  passed += dcrteM5AcceptanceCase(cases, "M5-C", "imported egg",
    "Intrinsic", caseC, "narrow-end entropic propagation") ? 1 : 0;

  SchedulerConfiguration dConfig = dcrteM5Configuration(
    EntropicPolicyMode.EXPLORATION, AcceptanceMode.SEEDED_STOCHASTIC);
  dConfig.seedMode = SchedulerSeedMode.INTRINSIC_START;
  dConfig.entropy.scoreThreshold = 0.35f;
  DCRTEM5RunResult caseD = dcrteM5Run(egg, dConfig, 20, -1);
  DCRTEM5RunResult caseDRepeat = dcrteM5Run(egg, dConfig, 1, -1);
  boolean dReproducible = dcrteM5SameOutcome(caseD, caseDRepeat);
  passed += dcrteM5AcceptanceCase(cases, "M5-D", "imported egg",
    "Intrinsic", caseD, dReproducible ? "reproducible by seed"
      : "reproducibility failure") ? 1 : 0;

  DCRTEM5RunResult caseE = dcrteM5AcceptanceRun(egg,
    EntropicPolicyMode.BALANCED, AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  passed += dcrteM5AcceptanceCase(cases, "M5-E", "imported egg",
    "Intrinsic", caseE, "pass") ? 1 : 0;

  SchedulerConfiguration fConfig = dcrteM5Configuration(
    EntropicPolicyMode.ADAPTIVE_RELAX_EXPLORE, AcceptanceMode.SEEDED_STOCHASTIC);
  fConfig.entropy.scoreThreshold = 1.0f;
  fConfig.entropy.acceptanceTemperature = 0.01f;
  fConfig.entropy.stagnationTrigger = 1;
  fConfig.entropy.explorationBoostDuration = 2;
  fConfig.entropy.stability.minimumBatches = 4;
  fConfig.entropy.stability.observationWindow = 2;
  fConfig.entropy.stability.requiredStableWindows = 2;
  fConfig.entropy.stability.allowStablePartial = true;
  DCRTEM5RunResult caseF = dcrteM5Run(egg, fConfig, 20, -1);
  boolean transitioned = caseF.scheduler.policyState.transitionCount > 0;
  passed += dcrteM5AcceptanceCase(cases, "M5-F", "imported egg",
    "Intrinsic", caseF, transitioned ? "policy transitions recorded"
      : "missing policy transition") ? 1 : 0;

  SchedulerConfiguration gConfig = dcrteM5Configuration(
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_THRESHOLD);
  gConfig.seedMode = SchedulerSeedMode.INTRINSIC_START;
  gConfig.entropy.scoreThreshold = 0.20f;
  DCRTEM5RunResult caseG = dcrteM5Run(bent, gConfig, 20, -1);
  passed += dcrteM5AcceptanceCase(cases, "M5-G", "bent capsule",
    "Intrinsic", caseG, "pass") ? 1 : 0;

  DCRTEM5RunResult caseH = dcrteM5AcceptanceRun(disconnected,
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  boolean componentPolicy = caseH.context.candidateComponentCount == 2
    && caseH.state.activeCount == disconnected.candidateCount;
  passed += dcrteM5AcceptanceCase(cases, "M5-H",
    "multicomponent candidate", "Cartesian", caseH,
    componentPolicy ? "component policy respected"
      : "component policy failure") ? 1 : 0;

  DCRTEM5RunResult caseI = dcrteM5AcceptanceRun(dcrteM4EmptySnapshot(6),
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  passed += dcrteM5AcceptanceCase(cases, "M5-I",
    "invalid imported domain", "Cartesian", caseI,
    "initialization blocked") ? 1 : 0;

  SchedulerConfiguration jConfig = dcrteM5Configuration(
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_THRESHOLD);
  jConfig.entropy.scoreThreshold = 1.0f;
  jConfig.entropy.stability.minimumBatches = 4;
  jConfig.entropy.stability.observationWindow = 2;
  jConfig.entropy.stability.requiredStableWindows = 2;
  jConfig.entropy.stability.allowStablePartial = true;
  DCRTEM5RunResult caseJ = dcrteM5Run(egg, jConfig, 20, -1);
  boolean explicitPartial = caseJ.scheduler.terminalState
      == EntropicTerminalState.STABLE_PARTIAL_CONFIGURATION
    || caseJ.scheduler.terminalState == EntropicTerminalState.THRESHOLD_STALLED;
  passed += dcrteM5AcceptanceCase(cases, "M5-J", "canonical egg",
    "Intrinsic", caseJ, explicitPartial ? "stable partial or explicit stall"
      : "partial-state failure") ? 1 : 0;

  SchedulerConfiguration kConfig = dcrteM5Configuration(
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_THRESHOLD);
  kConfig.entropy.scoreThreshold = 0;
  DCRTEM5RunResult caseK = dcrteM5Run(egg, kConfig, 20, -1);
  passed += dcrteM5AcceptanceCase(cases, "M5-K", "canonical egg",
    "Intrinsic", caseK, "complete reachable set") ? 1 : 0;

  JSONObject comparison = new JSONObject();
  EntropicPolicyMode[] allPolicies = EntropicPolicyMode.values();
  boolean comparisonPass = true;
  for (int i = 0; i < allPolicies.length; i++) {
    DCRTEM5RunResult run = dcrteM5AcceptanceRun(egg, allPolicies[i],
      AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
    JSONObject policyResult = dcrteM5AcceptanceSummary(run);
    comparison.setJSONObject(allPolicies[i].id(), policyResult);
    comparisonPass &= dcrteM5ValidRunInvariants(run);
  }
  JSONObject caseL = new JSONObject();
  caseL.setString("id", "M5-L");
  caseL.setString("fixture", "same egg snapshot");
  caseL.setString("coordinates", "Intrinsic");
  caseL.setString("expected", "paired provenance complete");
  caseL.setJSONObject("policy_comparison", comparison);
  caseL.setBoolean("pass", comparisonPass);
  cases.setJSONObject(cases.size(), caseL);
  if (comparisonPass) passed++;

  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M5");
  output.setString("status", passed == 12 && dcrteM5Tests.ok()
    ? "pass" : "fail");
  output.setInt("passed_cases", passed);
  output.setInt("total_cases", 12);
  output.setBoolean("entropy_model_present", true);
  output.setString("physical_time_claim", "none");
  output.setString("relational_progress_units",
    "dimensionless_computational_progress");
  output.setString("exact_mode", "FULL_FRONTIER_EXACT");
  output.setJSONObject("deterministic_tests", dcrteM5Tests.toJSON());
  output.setJSONArray("cases", cases);
  ensureDir(sketchPath("logs"));
  saveJSONObject(output, "logs/dcrte_m5_acceptance_latest.json");
  println("DCRTE-ET Milestone 5 acceptance: "
    + output.getString("status") + " " + passed + "/12");
}

DCRTEM5RunResult dcrteM5AcceptanceRun(CandidateVolumeSnapshot snapshot,
    EntropicPolicyMode policy, AcceptanceMode acceptance,
    float threshold, long seed) {
  SchedulerConfiguration config = dcrteM5Configuration(policy, acceptance);
  config.entropy.scoreThreshold = threshold;
  config.entropy.schedulerSeed = seed;
  return dcrteM5Run(snapshot, config, 20, -1);
}

boolean dcrteM5AcceptanceCase(JSONArray cases, String id, String fixture,
    String coordinates, DCRTEM5RunResult run, String expected) {
  boolean pass;
  if (expected.indexOf("blocked") >= 0) {
    pass = run != null && run.state != null
      && run.state.runState == SchedulerRunState.FAILED;
  } else if (expected.indexOf("failure") >= 0
      || expected.indexOf("missing") >= 0) {
    pass = false;
  } else {
    pass = dcrteM5ValidRunInvariants(run);
  }
  JSONObject entry = dcrteM5AcceptanceSummary(run);
  entry.setString("id", id);
  entry.setString("fixture", fixture);
  entry.setString("coordinates", coordinates);
  entry.setString("expected", expected);
  entry.setBoolean("pass", pass);
  cases.setJSONObject(cases.size(), entry);
  return pass;
}

boolean dcrteM5ValidRunInvariants(DCRTEM5RunResult run) {
  if (run == null || run.snapshot == null || run.state == null
      || run.scheduler == null || !run.terminal()
      || run.state.runState == SchedulerRunState.FAILED) return false;
  if (!dcrteM4NoGateViolations(run.snapshot, run.state)
      || !run.scheduler.progress.isValid()
      || !run.scheduler.lastCacheVerification.pass
      || run.state.stopReason == SchedulerStopReason.NONE) return false;
  for (int i = 0; i < run.scheduler.entropicHistory.size(); i++) {
    EntropicSchedulerHistoryEntry entry =
      run.scheduler.entropicHistory.get(i);
    if (!dcrteFinite(entry.meanOccupancyEntropy)
        || !dcrteFinite(entry.meanFieldEntropy)
        || !dcrteFinite(entry.maxFrontierScore)
        || !Double.isFinite(entry.tauRaw)) return false;
  }
  return true;
}

JSONObject dcrteM5AcceptanceSummary(DCRTEM5RunResult run) {
  JSONObject entry = new JSONObject();
  if (run == null || run.state == null || run.scheduler == null) {
    entry.setString("actual", "missing");
    return entry;
  }
  entry.setString("actual", run.state.runState.id() + "/"
    + run.state.stopReason.id());
  entry.setString("terminal_state", run.scheduler.terminalState.id());
  entry.setString("state_hash", run.state.stateHash);
  entry.setInt("batch_count", run.state.batchIndex);
  entry.setInt("active_count", run.state.activeCount);
  entry.setFloat("active_fraction", run.state.activeCount
    / (float)max(1, run.snapshot.candidateCount));
  entry.setString("tau_raw", Double.toString(run.scheduler.progress.tauRaw));
  entry.setFloat("mean_occupancy_entropy",
    run.scheduler.entropySummary.meanLocalEntropy);
  entry.setFloat("frontier_entropy",
    run.scheduler.entropySummary.frontierMeanEntropy);
  entry.setInt("policy_transition_count",
    run.scheduler.policyState.transitionCount);
  entry.setFloat("runtime_millis",
    run.runtimeNanos / 1000000.0f);
  entry.setBoolean("cache_verified",
    run.scheduler.lastCacheVerification.pass);
  entry.setJSONObject("configuration", run.configuration.toJSON());
  entry.setJSONObject("scheduler", run.scheduler.toJSON());
  entry.setJSONObject("diagnostics", run.diagnostics.toJSON());
  return entry;
}

void runDcrteMilestone5Benchmarks() {
  println("DCRTE-ET Milestone 5 exact benchmarks starting...");
  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M5");
  output.setString("timing_role", "performance_diagnostic_only");
  output.setString("physical_time_claim", "none");
  output.setString("exact_mode", "FULL_FRONTIER_EXACT");
  JSONObject sixtyFour = dcrteM5BenchmarkResolution(64);
  JSONObject oneTwentyEight = dcrteM5BenchmarkResolution(128);
  output.setJSONObject("resolution_64", sixtyFour);
  output.setJSONObject("resolution_128", oneTwentyEight);
  output.setString("status", sixtyFour.getBoolean("correct")
    && oneTwentyEight.getBoolean("correct") ? "pass" : "fail");
  ensureDir(sketchPath("logs"));
  saveJSONObject(output, "logs/dcrte_m5_benchmark_latest.json");
  println("DCRTE-ET Milestone 5 benchmarks: "
    + output.getString("status"));
}

JSONObject dcrteM5BenchmarkResolution(int resolution) {
  JSONObject result = new JSONObject();
  long totalStarted = System.nanoTime();
  DCRTEVolume volume = dcrteM4BoxVolume(resolution, true, false);
  long snapshotStarted = System.nanoTime();
  CandidateVolumeSnapshot snapshot = dcrteM4Snapshot(volume, null, null);
  long snapshotNanos = System.nanoTime() - snapshotStarted;
  SchedulerConfiguration config = dcrteM5Configuration(
    EntropicPolicyMode.RELAXATION, AcceptanceMode.DETERMINISTIC_TOP_K);
  config.maximumBatches = 1;
  config.entropy.maxUpdatesPerBatch = 256;
  config.entropy.verificationInterval = 1;
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot.spec.voxelCount());
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  EmergentEntropicScheduler scheduler = new EmergentEntropicScheduler();
  long initializeStarted = System.nanoTime();
  boolean initialized = scheduler.initialize(context, state, diagnostics);
  long initializeNanos = System.nanoTime() - initializeStarted;
  long batchStarted = System.nanoTime();
  if (initialized) scheduler.step(context, state, diagnostics);
  long batchNanos = System.nanoTime() - batchStarted;
  long verificationStarted = System.nanoTime();
  EntropyCacheVerification verification = initialized
    ? scheduler.entropyCache.verifyAgainstFullRecompute(state, 0.000001f)
    : new EntropyCacheVerification();
  long verificationNanos = System.nanoTime() - verificationStarted;
  boolean correct = initialized && verification.pass
    && dcrteM4NoGateViolations(snapshot, state);
  result.setInt("resolution", resolution);
  result.setString("shape", resolution + "^3");
  result.setInt("candidate_count", snapshot.candidateCount);
  result.setFloat("snapshot_millis", snapshotNanos / 1000000.0f);
  result.setFloat("cache_and_initialize_millis",
    initializeNanos / 1000000.0f);
  result.setFloat("single_exact_batch_millis",
    batchNanos / 1000000.0f);
  result.setFloat("full_cache_verification_millis",
    verificationNanos / 1000000.0f);
  result.setFloat("total_millis",
    (System.nanoTime() - totalStarted) / 1000000.0f);
  result.setString("cache_storage_bytes", initialized
    ? Long.toString(scheduler.entropyCache.estimatedBytes()) : "0");
  result.setString("state_storage_bytes",
    Long.toString(state.estimatedBytes()));
  result.setBoolean("correct", correct);
  result.setString("scope",
    "exact initialization plus one full-frontier batch; no hidden downsampling");
  result.setJSONObject("diagnostics", diagnostics.toJSON());
  return result;
}
