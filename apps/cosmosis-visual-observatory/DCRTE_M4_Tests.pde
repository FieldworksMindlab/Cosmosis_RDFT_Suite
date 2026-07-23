/* DCRTE-ET Milestone 4 deterministic scheduler fixtures and acceptance matrix. */

class DCRTEM4TestReport extends DCRTEM3TestReport {}

DCRTEM4TestReport dcrteM4Tests = new DCRTEM4TestReport();

DCRTEM4TestReport runDcrteMilestone4Tests() {
  DCRTEM4TestReport tests = new DCRTEM4TestReport();
  try {
    CandidateVolumeSnapshot cube = dcrteM4BoxSnapshot(5, false, false);
    tests.check(cube != null && cube.valid && cube.candidateCount == 125,
      "candidate snapshot captures a complete admitted cube");

    DCRTEVolume mutable = dcrteM4BoxVolume(5, false, false);
    CandidateVolumeSnapshot immutable = dcrteM4Snapshot(mutable, null, null);
    String immutableHash = immutable.contentHash;
    mutable.candidateSolid[0] = false;
    mutable.scalar[1] = 999;
    tests.check(immutable.candidateSolid[0] && immutable.fieldScalar[1] != 999
      && immutableHash.equals(immutable.contentHash), "candidate snapshot is immutable after capture");

    DCRTEVolume provenanceVolume = dcrteM4BoxVolume(3, false, false);
    IntrinsicCoordinateVolume provenanceIntrinsic = new IntrinsicCoordinateVolume(provenanceVolume.spec);
    for (int i = 0; i < provenanceIntrinsic.s.length; i++) {
      provenanceIntrinsic.s[i] = i / (float)max(1, provenanceIntrinsic.s.length - 1);
      provenanceIntrinsic.normalizedRadius[i] = 0.5f;
      provenanceIntrinsic.theta[i] = i * 0.03125f;
      provenanceIntrinsic.confidence[i] = 0.9f;
      provenanceIntrinsic.valid[i] = true;
    }
    provenanceIntrinsic.validCount = provenanceIntrinsic.s.length;
    DCRTEConfig provenanceConfig = new DCRTEConfig();
    provenanceConfig.materialSourceModeValue = "fixture";
    provenanceConfig.materialIndexValue = 7;
    provenanceConfig.materialTargetValue = "M4 provenance material";
    provenanceConfig.materialSourceIdValue = "fixture:m4";
    provenanceConfig.finalizeIdentity();
    CandidateVolumeSnapshot provenance = new CandidateVolumeSnapshot(provenanceVolume, null,
      dcrteM4Observer(provenanceVolume.spec), null, provenanceIntrinsic, provenanceConfig);
    float frozenTheta = provenance.intrinsicTheta[1];
    provenanceIntrinsic.theta[1] = 999;
    tests.check(provenance.hasIntrinsicTheta() && provenance.intrinsicTheta[1] == frozenTheta
      && provenance.materialConfigurationId.length() == 64
      && provenance.createdAtMillisDiagnosticOnly > 0,
      "snapshot freezes intrinsic theta and records material provenance");

    DCRTEVolume outsideCandidate = dcrteM4BoxVolume(4, false, false);
    outsideCandidate.admitted[0] = false;
    outsideCandidate.candidateSolid[0] = true;
    CandidateVolumeSnapshot gated = dcrteM4Snapshot(outsideCandidate, null, null);
    tests.check(gated.valid && !gated.candidateSolid[0]
      && dcrteCandidateSubsetOfAdmission(gated.admitted, gated.candidateSolid),
      "candidate snapshot enforces the admission gate");

    SchedulerConfiguration immediateConfig = new SchedulerConfiguration();
    immediateConfig.mode = SchedulerMode.IMMEDIATE;
    PropagationState immediate = dcrteM4Run(cube, immediateConfig, new SchedulerDiagnostics());
    tests.check(immediate != null && immediate.runState == SchedulerRunState.COMPLETE
      && immediate.activeCount == cube.candidateCount && dcrteM4MaskEquals(immediate.active, cube.candidateSolid),
      "Immediate scheduler exactly equals the frozen candidate mask");
    tests.check(dcrteM4MaskMismatchCount(immediate.active, cube.candidateSolid) == 0,
      "Immediate scheduler reports exactly zero baseline mask mismatches");

    SchedulerConfiguration frontConfig = dcrteM4FrontConfiguration();
    SchedulerDiagnostics cubeDiagnostics = new SchedulerDiagnostics();
    PropagationState cubeFront = dcrteM4Run(cube, frontConfig, cubeDiagnostics);
    tests.check(cubeFront != null && cubeFront.runState == SchedulerRunState.COMPLETE
      && cubeFront.activeCount == cube.candidateCount, "front scheduler completes the connected cube");
    tests.check(dcrteM4ManhattanArrival(cubeFront, cube.spec),
      "six-connected cube arrival batches match Manhattan distance");
    tests.check(dcrteM4NoGateViolations(cube, cubeFront),
      "front propagation never activates outside-domain or noncandidate voxels");
    tests.check(dcrteM4ArrivalOrderValid(cube, cubeFront)
      && java.util.Arrays.equals(cubeFront.reconstructAtBatch(cubeFront.batchIndex), cubeFront.active),
      "arrival batches and ranks reconstruct the completed active state");

    SchedulerConfiguration eighteen = dcrteM4FrontConfiguration();
    eighteen.neighborhoodMode = SchedulerNeighborhoodMode.EIGHTEEN_CONNECTED;
    SchedulerConfiguration twentySix = dcrteM4FrontConfiguration();
    twentySix.neighborhoodMode = SchedulerNeighborhoodMode.TWENTY_SIX_CONNECTED;
    PropagationState eighteenState = dcrteM4Run(cube, eighteen, new SchedulerDiagnostics());
    PropagationState twentySixState = dcrteM4Run(cube, twentySix, new SchedulerDiagnostics());
    tests.check(eighteenState.runState == SchedulerRunState.COMPLETE
      && twentySixState.runState == SchedulerRunState.COMPLETE
      && dcrteM4NoGateViolations(cube, eighteenState)
      && dcrteM4NoGateViolations(cube, twentySixState),
      "eighteen- and twenty-six-connected modes complete without gate violations");

    CandidateVolumeSnapshot shell = dcrteM4BoxSnapshot(7, true, false);
    PropagationState shellState = dcrteM4Run(shell, frontConfig, new SchedulerDiagnostics());
    tests.check(shellState != null && shellState.runState == SchedulerRunState.COMPLETE
      && shellState.activeCount == shell.candidateCount, "hollow shell propagates over its connected wall");

    CandidateVolumeSnapshot disconnected = dcrteM4BoxSnapshot(7, false, true);
    SchedulerConfiguration single = dcrteM4FrontConfiguration();
    single.componentPolicy = SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY;
    PropagationState singleState = dcrteM4Run(disconnected, single, new SchedulerDiagnostics());
    tests.check(singleState != null && singleState.stopReason == SchedulerStopReason.UNREACHABLE_CANDIDATES
      && singleState.activeCount < disconnected.candidateCount,
      "single-inlet policy reports unreachable disconnected candidates");

    SchedulerConfiguration each = dcrteM4FrontConfiguration();
    each.componentPolicy = SchedulerComponentPolicy.SEED_EACH_COMPONENT;
    PropagationState eachState = dcrteM4Run(disconnected, each, new SchedulerDiagnostics());
    tests.check(eachState != null && eachState.runState == SchedulerRunState.COMPLETE
      && eachState.activeCount == disconnected.candidateCount,
      "seed-each-component policy completes disconnected candidates");

    SchedulerConfiguration block = dcrteM4FrontConfiguration();
    block.componentPolicy = SchedulerComponentPolicy.BLOCK_MULTICOMPONENT;
    SchedulerDiagnostics blockDiagnostics = new SchedulerDiagnostics();
    PropagationState blockState = dcrteM4Initialize(disconnected, block, blockDiagnostics);
    tests.check(blockState != null && blockState.runState == SchedulerRunState.FAILED
      && blockState.stopReason == SchedulerStopReason.MULTICOMPONENT_BLOCKED,
      "block-multicomponent policy fails explicitly");

    SchedulerConfiguration fieldPriority = dcrteM4FrontConfiguration();
    fieldPriority.priorityMode = SchedulerPriorityMode.FIELD_COMPATIBILITY;
    fieldPriority.maxUpdatesPerBatch = 3;
    PropagationState tieA = dcrteM4Run(cube, fieldPriority, new SchedulerDiagnostics());
    PropagationState tieB = dcrteM4Run(cube, fieldPriority, new SchedulerDiagnostics());
    tests.check(tieA != null && tieB != null && tieA.stateHash.equals(tieB.stateHash)
      && java.util.Arrays.equals(tieA.arrivalBatch, tieB.arrivalBatch),
      "field-priority ties resolve deterministically by flat index");

    SchedulerConfiguration rate = dcrteM4FrontConfiguration();
    rate.maxUpdatesPerBatch = 4;
    PropagationState continuous = dcrteM4Run(cube, rate, new SchedulerDiagnostics());
    PropagationState resumed = dcrteM4RunWithPause(cube, rate, 3);
    tests.check(continuous != null && resumed != null && continuous.stateHash.equals(resumed.stateHash)
      && java.util.Arrays.equals(continuous.arrivalBatch, resumed.arrivalBatch),
      "pause and resume preserve deterministic arrival order");

    PropagationState frameRateA = dcrteM4RunWithRenderBudget(cube, rate, 1);
    PropagationState frameRateB = dcrteM4RunWithRenderBudget(cube, rate, 7);
    tests.check(frameRateA != null && frameRateB != null && frameRateA.stateHash.equals(frameRateB.stateHash)
      && java.util.Arrays.equals(frameRateA.arrivalBatch, frameRateB.arrivalBatch),
      "render batch budget does not change scheduler ordering");

    int[] resetSeedsA = dcrteM4ResolvedSeeds(cube, rate);
    int[] resetSeedsB = dcrteM4ResolvedSeeds(cube, rate);
    PropagationState resetA = dcrteM4Run(cube, rate, new SchedulerDiagnostics());
    PropagationState resetB = dcrteM4Run(cube, rate, new SchedulerDiagnostics());
    tests.check(java.util.Arrays.equals(resetSeedsA, resetSeedsB)
      && resetA.stateHash.equals(resetB.stateHash)
      && java.util.Arrays.equals(resetA.arrivalBatch, resetB.arrivalBatch),
      "reset reproduces deterministic seeds, arrival order, and final hash");

    SchedulerController historyController = new SchedulerController();
    historyController.configuration = rate.copy();
    DCRTEVolume historyVolume = dcrteM4BoxVolume(5, false, false);
    historyController.capture(historyVolume, new BoxDomain(0, 0, 0, 1, 1, 1),
      dcrteM4Observer(historyVolume.spec), null, null, null);
    historyController.complete();
    tests.check(dcrteM4HistoryConsistent(historyController),
      "compact scheduler history is monotonic and accounts for every activation");

    SchedulerController invalidated = new SchedulerController();
    invalidated.configuration = rate.copy();
    DCRTEVolume invalidationVolume = dcrteM4BoxVolume(5, false, false);
    UniformGridObserver invalidationObserver = dcrteM4Observer(invalidationVolume.spec);
    invalidated.capture(invalidationVolume, new BoxDomain(0, 0, 0, 1, 1, 1), invalidationObserver, null, null, null);
    invalidated.invalidate("fixture upstream mutation");
    tests.check(invalidated.state != null && invalidated.state.runState == SchedulerRunState.INVALIDATED
      && !invalidated.canExportCurrentMesh(), "upstream configuration change invalidates scheduler export");

    CandidateVolumeSnapshot empty = dcrteM4EmptySnapshot(4);
    SchedulerDiagnostics emptyDiagnostics = new SchedulerDiagnostics();
    PropagationState emptyState = dcrteM4Initialize(empty, frontConfig, emptyDiagnostics);
    tests.check(emptyState != null && emptyState.runState == SchedulerRunState.FAILED
      && emptyDiagnostics.hasErrors(), "invalid empty candidate domain blocks scheduler initialization");
  }
  catch (Exception error) {
    tests.check(false, "M4 deterministic test exception: " + error.getClass().getSimpleName() + " " + error.getMessage());
  }
  return tests;
}

SchedulerConfiguration dcrteM4FrontConfiguration() {
  SchedulerConfiguration config = new SchedulerConfiguration();
  config.mode = SchedulerMode.FRONT_PROPAGATION;
  config.seedMode = SchedulerSeedMode.CENTER_NEAREST;
  config.componentPolicy = SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY;
  config.neighborhoodMode = SchedulerNeighborhoodMode.SIX_CONNECTED;
  config.priorityMode = SchedulerPriorityMode.BREADTH_FIRST_LAYER;
  config.maxUpdatesPerBatch = 0;
  return config;
}

DCRTEVolume dcrteM4BoxVolume(int resolution, boolean shell, boolean disconnected) {
  VolumeSpec spec = new VolumeSpec(resolution, resolution, resolution, new Bounds3D(-1, -1, -1, 1, 1, 1));
  DCRTEVolume volume = new DCRTEVolume(spec);
  for (int z = 0; z < resolution; z++) for (int y = 0; y < resolution; y++) for (int x = 0; x < resolution; x++) {
    int index = volume.index(x, y, z);
    boolean candidate = true;
    if (shell) candidate = x == 0 || y == 0 || z == 0 || x == resolution - 1 || y == resolution - 1 || z == resolution - 1;
    if (disconnected) candidate = (x <= 1 && y <= 1 && z <= 1)
      || (x >= resolution - 2 && y >= resolution - 2 && z >= resolution - 2);
    volume.admitted[index] = candidate;
    volume.candidateSolid[index] = candidate;
    volume.scalar[index] = (x + y + z) % 3 == 0 ? 0.25f : -0.25f;
    if (candidate) { volume.admittedCount++; volume.candidateSolidCount++; }
  }
  return volume;
}

CandidateVolumeSnapshot dcrteM4BoxSnapshot(int resolution, boolean shell, boolean disconnected) {
  return dcrteM4Snapshot(dcrteM4BoxVolume(resolution, shell, disconnected), null, null);
}

CandidateVolumeSnapshot dcrteM4EmptySnapshot(int resolution) {
  VolumeSpec spec = new VolumeSpec(resolution, resolution, resolution, new Bounds3D(-1, -1, -1, 1, 1, 1));
  return dcrteM4Snapshot(new DCRTEVolume(spec), null, null);
}

CandidateVolumeSnapshot dcrteM4Snapshot(DCRTEVolume volume, SignedDistanceVolume sdf, IntrinsicCoordinateVolume intrinsic) {
  UniformGridObserver observer = dcrteM4Observer(volume.spec);
  return new CandidateVolumeSnapshot(volume, null, observer, sdf, intrinsic, null);
}

UniformGridObserver dcrteM4Observer(VolumeSpec spec) {
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(spec);
  return observer;
}

PropagationState dcrteM4Initialize(CandidateVolumeSnapshot snapshot, SchedulerConfiguration config, SchedulerDiagnostics diagnostics) {
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot == null || snapshot.spec == null ? 0 : snapshot.spec.voxelCount());
  FieldScheduler scheduler = config.mode == SchedulerMode.IMMEDIATE ? new ImmediateScheduler() : new FrontPropagationScheduler();
  scheduler.initialize(context, state, diagnostics);
  return state;
}

PropagationState dcrteM4Run(CandidateVolumeSnapshot snapshot, SchedulerConfiguration config, SchedulerDiagnostics diagnostics) {
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot == null || snapshot.spec == null ? 0 : snapshot.spec.voxelCount());
  FieldScheduler scheduler = config.mode == SchedulerMode.IMMEDIATE ? new ImmediateScheduler() : new FrontPropagationScheduler();
  if (!scheduler.initialize(context, state, diagnostics)) return state;
  int guard = config.maximumBatches + 2;
  while (state.runState != SchedulerRunState.COMPLETE && state.runState != SchedulerRunState.STOPPED
      && state.runState != SchedulerRunState.FAILED && guard-- > 0) scheduler.step(context, state, diagnostics);
  return state;
}

PropagationState dcrteM4RunWithPause(CandidateVolumeSnapshot snapshot, SchedulerConfiguration config, int pauseAfter) {
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot.spec.voxelCount());
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  FieldScheduler scheduler = new FrontPropagationScheduler();
  if (!scheduler.initialize(context, state, diagnostics)) return state;
  for (int i = 0; i < pauseAfter && state.runState != SchedulerRunState.COMPLETE; i++) scheduler.step(context, state, diagnostics);
  state.runState = SchedulerRunState.PAUSED;
  int guard = config.maximumBatches + 2;
  while (state.runState != SchedulerRunState.COMPLETE && state.runState != SchedulerRunState.STOPPED
      && state.runState != SchedulerRunState.FAILED && guard-- > 0) scheduler.step(context, state, diagnostics);
  return state;
}

PropagationState dcrteM4RunWithRenderBudget(CandidateVolumeSnapshot snapshot, SchedulerConfiguration config, int batchesPerFrame) {
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot.spec.voxelCount());
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  FieldScheduler scheduler = new FrontPropagationScheduler();
  if (!scheduler.initialize(context, state, diagnostics)) return state;
  int guard = config.maximumBatches + 2;
  while (state.runState != SchedulerRunState.COMPLETE && state.runState != SchedulerRunState.STOPPED
      && state.runState != SchedulerRunState.FAILED && guard-- > 0) {
    for (int i = 0; i < batchesPerFrame && state.runState != SchedulerRunState.COMPLETE
        && state.runState != SchedulerRunState.STOPPED && state.runState != SchedulerRunState.FAILED; i++) {
      scheduler.step(context, state, diagnostics);
    }
  }
  return state;
}

boolean dcrteM4ManhattanArrival(PropagationState state, VolumeSpec spec) {
  if (state == null || spec == null) return false;
  int cx = spec.nx / 2, cy = spec.ny / 2, cz = spec.nz / 2;
  for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
    int index = x + spec.nx * (y + spec.ny * z);
    if (state.arrivalBatch[index] != abs(x - cx) + abs(y - cy) + abs(z - cz)) return false;
  }
  return true;
}

boolean dcrteM4NoGateViolations(CandidateVolumeSnapshot snapshot, PropagationState state) {
  if (snapshot == null || state == null) return false;
  for (int i = 0; i < state.active.length; i++) if (state.active[i]
      && (!snapshot.admitted[i] || !snapshot.candidateSolid[i])) return false;
  return true;
}

boolean dcrteM4MaskEquals(boolean[] a, boolean[] b) {
  return a != null && b != null && java.util.Arrays.equals(a, b);
}

int dcrteM4MaskMismatchCount(boolean[] a, boolean[] b) {
  if (a == null || b == null || a.length != b.length) return -1;
  int mismatches = 0;
  for (int i = 0; i < a.length; i++) if (a[i] != b[i]) mismatches++;
  return mismatches;
}

boolean dcrteM4ArrivalOrderValid(CandidateVolumeSnapshot snapshot, PropagationState state) {
  if (snapshot == null || state == null || state.arrivalBatch.length != snapshot.candidateSolid.length
      || state.arrivalRank.length != snapshot.candidateSolid.length) return false;
  boolean[] ranks = new boolean[state.activeCount];
  int active = 0;
  for (int i = 0; i < state.active.length; i++) {
    if (!state.active[i]) {
      if (state.arrivalBatch[i] != -1 || state.arrivalRank[i] != -1) return false;
      continue;
    }
    if (!snapshot.admitted[i] || !snapshot.candidateSolid[i]
        || state.arrivalBatch[i] < 0 || state.arrivalBatch[i] > state.batchIndex
        || state.arrivalRank[i] < 0 || state.arrivalRank[i] >= ranks.length
        || ranks[state.arrivalRank[i]]) return false;
    ranks[state.arrivalRank[i]] = true;
    active++;
  }
  return active == state.activeCount;
}

int[] dcrteM4ResolvedSeeds(CandidateVolumeSnapshot snapshot, SchedulerConfiguration config) {
  SchedulerContext context = new SchedulerContext(snapshot, config);
  PropagationState state = new PropagationState(snapshot.spec.voxelCount());
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  FieldScheduler scheduler = config.mode == SchedulerMode.IMMEDIATE
    ? new ImmediateScheduler() : new FrontPropagationScheduler();
  if (!scheduler.initialize(context, state, diagnostics)) return new int[0];
  return java.util.Arrays.copyOf(context.resolvedSeeds, context.resolvedSeeds.length);
}

boolean dcrteM4HistoryConsistent(SchedulerController controller) {
  if (controller == null || controller.state == null || controller.snapshot == null
      || controller.history.size() == 0) return false;
  int totalActivated = 0;
  int previousActive = -1;
  for (int i = 0; i < controller.history.size(); i++) {
    SchedulerHistoryEntry entry = controller.history.get(i);
    if (entry.activeCount < previousActive || entry.stateHash == null || entry.stateHash.length() == 0) return false;
    totalActivated += entry.newlyActivated;
    previousActive = entry.activeCount;
  }
  SchedulerHistoryEntry last = controller.history.get(controller.history.size() - 1);
  return totalActivated == controller.state.activeCount
    && last.activeCount == controller.state.activeCount
    && last.remainingCandidateCount == controller.snapshot.candidateCount - controller.state.activeCount;
}

CandidateVolumeSnapshot dcrteM4SnapshotFromSdf(SignedDistanceVolume sdf, IntrinsicCoordinateVolume intrinsic) {
  if (sdf == null || !sdf.isValid()) return null;
  DCRTEVolume volume = new DCRTEVolume(sdf.spec);
  for (int i = 0; i < volume.scalar.length; i++) {
    boolean candidate = sdf.inside[i];
    volume.admitted[i] = candidate;
    volume.candidateSolid[i] = candidate;
    volume.scalar[i] = sdf.signedDistance[i];
    if (candidate) { volume.admittedCount++; volume.candidateSolidCount++; }
  }
  return dcrteM4Snapshot(volume, sdf, intrinsic);
}

void runDcrteMilestone4AcceptanceMatrix() {
  println("DCRTE-ET Milestone 4 acceptance matrix starting...");
  JSONArray cases = new JSONArray();
  int passed = 0;
  CandidateVolumeSnapshot cylinder = dcrteM4SnapshotFromSdf(dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.CYLINDER, 28), null);
  SignedDistanceVolume eggSdf = dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 28);
  IntrinsicBuildResult eggIntrinsic = new DCRTEIntrinsicCoordinateBuilder().build(eggSdf, null, true);
  CandidateVolumeSnapshot egg = dcrteM4SnapshotFromSdf(eggSdf, eggIntrinsic == null ? null : eggIntrinsic.volume);
  SignedDistanceVolume bentSdf = dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.BENT_CAPSULE, 28);
  IntrinsicBuildResult bentIntrinsic = new DCRTEIntrinsicCoordinateBuilder().build(bentSdf, null, true);
  CandidateVolumeSnapshot bent = dcrteM4SnapshotFromSdf(bentSdf, bentIntrinsic == null ? null : bentIntrinsic.volume);
  CandidateVolumeSnapshot disconnected = dcrteM4BoxSnapshot(9, false, true);

  passed += dcrteM4AcceptanceCase(cases, "M4-A", "primitive cylinder", cylinder, SchedulerMode.IMMEDIATE,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SEED_EACH_COMPONENT, "complete") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-B", "primitive cylinder", cylinder, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-C", "canonical egg Cartesian", egg, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete_or_unreachable") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-D", "canonical egg intrinsic start", egg, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.INTRINSIC_START, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete_or_unreachable") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-E", "canonical egg intrinsic end", egg, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.INTRINSIC_END, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete_or_unreachable") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-F", "bent capsule intrinsic", bent, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.INTRINSIC_START, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete_or_unreachable") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-G", "multicomponent seed each", disconnected, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.COMPONENT_SEEDS, SchedulerComponentPolicy.SEED_EACH_COMPONENT, "complete") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-H", "multicomponent single inlet", disconnected, SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "unreachable") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-I", "invalid imported domain", dcrteM4EmptySnapshot(6), SchedulerMode.FRONT_PROPAGATION,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "blocked") ? 1 : 0;
  passed += dcrteM4AcceptanceCase(cases, "M4-J", "canonical egg immediate", egg, SchedulerMode.IMMEDIATE,
    SchedulerSeedMode.CENTER_NEAREST, SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY, "complete") ? 1 : 0;

  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M4");
  output.setString("status", passed == 10 && dcrteM4Tests.ok() ? "pass" : "fail");
  output.setInt("passed_cases", passed);
  output.setInt("total_cases", 10);
  output.setBoolean("entropy_model_present", false);
  output.setString("physical_time_claim", "none");
  output.setJSONObject("deterministic_tests", dcrteM4Tests.toJSON());
  output.setJSONArray("cases", cases);
  ensureDir(sketchPath("logs"));
  saveJSONObject(output, "logs/dcrte_m4_acceptance_latest.json");
  println("DCRTE-ET Milestone 4 acceptance: " + output.getString("status") + " " + passed + "/10");
}

void runDcrteMilestone4Benchmarks() {
  println("DCRTE-ET Milestone 4 deterministic benchmarks starting...");
  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M4");
  output.setString("timing_role", "performance_diagnostic_only");
  output.setString("physical_time_claim", "none");
  JSONObject sixtyFour = dcrteM4BenchmarkResolution(64);
  JSONObject oneTwentyEight = dcrteM4BenchmarkResolution(128);
  output.setJSONObject("resolution_64", sixtyFour);
  output.setJSONObject("resolution_128", oneTwentyEight);
  boolean pass = sixtyFour.getBoolean("pass") && oneTwentyEight.getBoolean("pass");
  output.setString("status", pass ? "pass" : "fail");
  ensureDir(sketchPath("logs"));
  saveJSONObject(output, "logs/dcrte_m4_benchmark_latest.json");
  println("DCRTE-ET Milestone 4 benchmarks: " + output.getString("status"));
}

JSONObject dcrteM4BenchmarkResolution(int resolution) {
  JSONObject result = new JSONObject();
  long totalStarted = System.nanoTime();
  DCRTEVolume volume = dcrteM4BoxVolume(resolution, false, false);
  long snapshotStarted = System.nanoTime();
  CandidateVolumeSnapshot snapshot = dcrteM4Snapshot(volume, null, null);
  long snapshotNanos = System.nanoTime() - snapshotStarted;
  SchedulerConfiguration config = dcrteM4FrontConfiguration();
  config.componentPolicy = SchedulerComponentPolicy.SINGLE_INLET_REACHABLE_ONLY;
  long schedulerStarted = System.nanoTime();
  PropagationState state = dcrteM4Run(snapshot, config, new SchedulerDiagnostics());
  long schedulerNanos = System.nanoTime() - schedulerStarted;
  long reconstructionStarted = System.nanoTime();
  boolean[] reconstructed = state.reconstructAtBatch(state.batchIndex);
  long reconstructionNanos = System.nanoTime() - reconstructionStarted;
  int mismatchCount = dcrteM4MaskMismatchCount(reconstructed, snapshot.candidateSolid);
  boolean pass = state.runState == SchedulerRunState.COMPLETE && mismatchCount == 0
    && dcrteM4ArrivalOrderValid(snapshot, state);
  result.setInt("resolution", resolution);
  result.setString("shape", resolution + "^3");
  result.setInt("candidate_count", snapshot.candidateCount);
  result.setInt("batch_count", state.batchIndex);
  result.setFloat("snapshot_millis", snapshotNanos / 1000000.0f);
  result.setFloat("scheduler_millis", schedulerNanos / 1000000.0f);
  result.setFloat("reconstruction_millis", reconstructionNanos / 1000000.0f);
  result.setFloat("total_millis", (System.nanoTime() - totalStarted) / 1000000.0f);
  result.setString("snapshot_storage_bytes", Long.toString(snapshot.estimatedBytes()));
  result.setString("state_storage_bytes", Long.toString(state.estimatedBytes()));
  result.setInt("mismatch_count", mismatchCount);
  result.setString("state_hash", state.stateHash);
  result.setBoolean("pass", pass);
  return result;
}

boolean dcrteM4AcceptanceCase(JSONArray cases, String id, String fixture,
    CandidateVolumeSnapshot snapshot, SchedulerMode mode, SchedulerSeedMode seed,
    SchedulerComponentPolicy components, String expected) {
  SchedulerConfiguration config = dcrteM4FrontConfiguration();
  config.mode = mode;
  config.seedMode = seed;
  config.componentPolicy = components;
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  PropagationState state = dcrteM4Run(snapshot, config, diagnostics);
  boolean pass = state != null;
  if (expected.equals("complete")) pass = pass && state.runState == SchedulerRunState.COMPLETE;
  else if (expected.equals("unreachable")) pass = pass && state.stopReason == SchedulerStopReason.UNREACHABLE_CANDIDATES;
  else if (expected.equals("blocked")) pass = pass && state.runState == SchedulerRunState.FAILED;
  else pass = pass && (state.runState == SchedulerRunState.COMPLETE
    || state.stopReason == SchedulerStopReason.UNREACHABLE_CANDIDATES);
  JSONObject entry = new JSONObject();
  entry.setString("id", id);
  entry.setString("fixture", fixture);
  entry.setString("scheduler", mode.id());
  entry.setString("seed", seed.id());
  entry.setString("component_policy", components.id());
  entry.setString("expected", expected);
  entry.setString("actual", state == null ? "missing" : state.runState.id() + "/" + state.stopReason.id());
  entry.setBoolean("pass", pass);
  if (state != null) entry.setString("state_hash", state.stateHash);
  entry.setJSONObject("diagnostics", diagnostics.toJSON());
  cases.setJSONObject(cases.size(), entry);
  return pass;
}
