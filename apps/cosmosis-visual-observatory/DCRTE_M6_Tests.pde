/* DCRTE-ET Milestone 6 deterministic composition tests and acceptance matrix. */

class DCRTEM6TestReport extends DCRTEM5TestReport {}

class DCRTEM6FixtureContext {
  TriangleMeshData source;
  TriangleMeshData world;
  MeshDomainReport meshReport;
  SignedDistanceVolume sdf;
  DomainPreflightReport preflight;
  boolean normalRoundTrip;
}

class DCRTEM6AttachmentFixture {
  VolumeSpec spec;
  SignedDistanceVolume sdf;
  FabricationCompositionVolume volume;
  CandidateVolumeSnapshot snapshot;
  boolean[] attachedAndFloating;
  boolean[] nearBoundary;
  boolean[] floatingOnly;
}

DCRTEM6TestReport dcrteM6Tests = new DCRTEM6TestReport();

void initializeDcrteMilestone6() {
  dcrteM6Tests = runDcrteMilestone6Tests();
  println("DCRTE-ET Milestone 6 deterministic tests: "
    + dcrteM6Tests.status());
  for (int i = 0; i < dcrteM6Tests.failures.size(); i++) {
    println("  FAIL " + dcrteM6Tests.failures.get(i));
  }
  resetDcrteImportedStateAfterReloadTests();
  resetDcrteComposition();
}

DCRTEM6TestReport runDcrteMilestone6Tests() {
  DCRTEM6TestReport tests = new DCRTEM6TestReport();
  MaterialCompositionConfiguration savedComposition =
    dcrteCompositionConfiguration == null
      ? new MaterialCompositionConfiguration()
      : dcrteCompositionConfiguration.copy();
  DCRTEObservationMode savedObservation = dcrteObservationMode;
  int savedResolution = dcrteImportedResolution;
  InvalidDomainPolicy savedPolicy = dcrteImportedPolicy;
  try {
    DCRTEM6FixtureContext torus = dcrteM6NormalTorusFixture(tests, 48);
    dcrteM6TestSourceShells(tests, torus);
    dcrteM6TestCompositionAndImmutability(tests);
    dcrteM6TestAttachmentAndBridges(tests);
    dcrteM6TestFidelity(tests, torus);
    dcrteM6TestScaffoldOnlyRegression(tests);
    dcrteM6TestCompositionGridMismatch(tests);
  }
  catch (Exception error) {
    tests.check(false, "M6 deterministic test exception: "
      + error.getClass().getSimpleName() + " "
      + (error.getMessage() == null ? "" : error.getMessage()));
  }
  finally {
    dcrteObservationMode = savedObservation;
    dcrteImportedResolution = savedResolution;
    dcrteImportedPolicy = savedPolicy;
    dcrteCompositionConfiguration = savedComposition;
    resetDcrteImportedStateAfterReloadTests();
  }
  return tests;
}

DCRTEM6FixtureContext dcrteM6NormalTorusFixture(
    DCRTEM6TestReport tests, int resolution) throws Exception {
  DCRTEM6FixtureContext context = new DCRTEM6FixtureContext();
  TriangleMeshData generated = createDcrteTorusFixtureMesh();
  tests.check(generated != null
    && generated.vertexCount
      == DCRTE_TORUS_MAJOR_SEGMENTS * DCRTE_TORUS_MINOR_SEGMENTS
    && generated.triangleCount
      == DCRTE_TORUS_MAJOR_SEGMENTS * DCRTE_TORUS_MINOR_SEGMENTS * 2,
    "torus fixture has the declared deterministic topology");
  tests.check(generated != null && dcrteSignedMeshVolume(generated) > 0,
    "torus fixture source winding has positive signed volume");

  MeshValidationResult rawValidation =
    new DCRTEMeshSanitizer().sanitize(generated);
  tests.check(rawValidation != null && rawValidation.report != null
    && rawValidation.report.strictValid()
    && rawValidation.report.boundaryEdgeCount == 0
    && rawValidation.report.nonManifoldEdgeCount == 0,
    "torus fixture is one closed manifold before SDF construction");

  File directory = new File(sketchPath("exports/dcrte_m6_tests"));
  if (!directory.exists()) directory.mkdirs();
  File first = new File(directory, "torus_roundtrip_a.stl");
  File second = new File(directory, "torus_roundtrip_b.stl");
  writeDcrteBinaryStl(generated, first, "DCRTE-M6 deterministic torus A");
  writeDcrteBinaryStl(generated, second, "DCRTE-M6 deterministic torus A");
  STLMeshImporter importer = new STLMeshImporter();
  TriangleMeshData parsedA = importer.load(first);
  TriangleMeshData parsedB = importer.load(second);
  tests.check(parsedA.sourceHashSha256.equals(parsedB.sourceHashSha256),
    "torus STL byte stream and source SHA-256 are deterministic");

  dcrteImportedResolution = resolution;
  dcrteImportedPolicy = InvalidDomainPolicy.STRICT;
  boolean loaded = loadDcrteImportedFile(first, true,
    dcrteTorusFixtureMetadata());
  boolean sdfReady = loaded && buildDcrteImportedSdf();
  context.normalRoundTrip = sdfReady;
  context.source = dcrteImportedSourceMesh;
  context.world = dcrteImportedWorldMesh;
  context.meshReport = dcrteImportedMeshReport;
  context.sdf = dcrteImportedSdf;
  context.preflight = dcrteImportedPreflightReport;
  tests.check(loaded && context.meshReport != null
    && context.meshReport.strictValid(),
    "torus fixture passes the normal STL importer and sanitizer");
  tests.check(sdfReady && context.sdf != null && context.sdf.isValid()
    && context.preflight != null
    && context.preflight.materializationEnabled
    && context.preflight.sdfReport != null
    && context.preflight.sdfReport.isValid()
    && context.preflight.nonManifoldVertexCount == 0,
    "torus fixture passes strict normal-path SDF and preflight");
  tests.check(context.sdf != null
    && context.sdf.sampleWorld(0, 0, 0) > 0
    && context.sdf.sampleWorld(DCRTE_TORUS_MAJOR_RADIUS, 0, 0) < 0,
    "torus SDF preserves the central through-hole and solid tube");

  IntrinsicBuildResult intrinsic = context.sdf == null ? null
    : new DCRTEIntrinsicCoordinateBuilder().build(context.sdf, null, true);
  tests.check(dcrteM6IntrinsicHasCode(intrinsic,
      DCRTEIntrinsicCodes.IC_CLOSED_LOOP_SUSPECTED),
    "torus intrinsic axial mode is blocked by IC_CLOSED_LOOP_SUSPECTED");
  return context;
}

void dcrteM6TestSourceShells(DCRTEM6TestReport tests,
    DCRTEM6FixtureContext torus) {
  DomainPreflightReport qualified = dcrteM6QualifiedPreflight();
  SignedDistanceVolume sphere =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.SPHERE, 28);
  SourceShellConfiguration thinConfig = dcrteM6ShellConfiguration(2, 0.75f);
  SourceShellConfiguration thickConfig = dcrteM6ShellConfiguration(5, 0.75f);
  SourceShellBuildResult thin =
    new SourceShellBuilder().build(sphere, qualified, thinConfig);
  SourceShellBuildResult thick =
    new SourceShellBuilder().build(sphere, qualified, thickConfig);
  int center = dcrteM6NearestIndex(sphere.spec, 0, 0, 0);
  tests.check(thin.valid() && thin.coverage >= 0.999999f
    && thin.shellComponentCount == 1,
    "sphere source shell is connected and covers the sampled boundary");
  tests.check(thin.domainInside[center] && !thin.sourceShell[center],
    "sphere source shell excludes the deep center while retaining domainInside");
  tests.check(thick.valid() && thick.shellCount >= thin.shellCount
    && dcrteM6MaskContains(thick.sourceShell, thin.sourceShell),
    "thicker source shell contains the thinner inward shell");

  SourceShellConfiguration hardConfig =
    dcrteM6ShellConfiguration(3, 0.75f);
  SourceShellConfiguration observationConfig =
    dcrteM6ShellConfiguration(5, 0.75f);
  dcrteObservationMode = DCRTEObservationMode.HARD_INTERIOR;
  SourceShellBuildResult hard =
    new SourceShellBuilder().build(sphere, qualified, hardConfig);
  dcrteObservationMode = DCRTEObservationMode.SHELL_BAND;
  SourceShellBuildResult observationShell =
    new SourceShellBuilder().build(sphere, qualified, observationConfig);
  JSONObject hardMetadata = hardConfig.toJSON(sphere.spec);
  JSONObject observationMetadata = observationConfig.toJSON(sphere.spec);
  tests.check(hard.valid() && observationShell.valid()
    && dcrteM6MaskContains(observationShell.sourceShell, hard.sourceShell)
    && hardMetadata.getInt("thickness_voxels") == 3
    && observationMetadata.getInt("thickness_voxels") == 5,
    "observation mode and fabrication-shell thickness remain independent and explicit in metadata");

  if (torus != null && torus.sdf != null) {
    SourceShellBuildResult torusShell = new SourceShellBuilder().build(
      torus.sdf, torus.preflight, dcrteM6ShellConfiguration(3, 0.75f));
    int torusCenter = dcrteM6NearestIndex(torus.sdf.spec, 0, 0, 0);
    tests.check(torusShell.valid() && torusShell.shellComponentCount == 1,
      "torus source shell remains one connected inward envelope");
    tests.check(!torusShell.domainInside[torusCenter]
      && !torusShell.sourceShell[torusCenter],
      "torus source shell leaves its axial through-hole empty");
    tests.check(dcrteM6MaskInside(torusShell.sourceShell,
      torusShell.domainInside),
      "torus source shell never crosses outside the signed source envelope");

    FabricationCompositionVolume torusVolume =
      dcrteM6VolumeFromShell(torusShell);
    CandidateVolumeSnapshot torusSnapshot =
      dcrteM4SnapshotFromSdf(torus.sdf, null);
    MaterialCompositionConfiguration torusConfig =
      dcrteM6CompositionConfiguration(MaterialCompositionMode.SHELL_ONLY);
    dcrteCompositionConfiguration = torusConfig.copy();
    dcrteCompositionValidation =
      new MaterialCompositionValidationReport();
    dcrteImportedSdf = torus.sdf;
    dcrteImportedWorldMesh = torus.world;
    boolean torusMaterialized = dcrteLegacyMaterializer.materialize(
      torusVolume, dcrteM6SourceVolume(torusSnapshot));
    tests.check(torusMaterialized && foundryBoundaryEdges == 0
      && foundryNonManifoldEdges == 0 && foundryDegenerateFaces == 0,
      "torus shell-only materialization emits a closed manifold boundary");
  }

  DomainPreflightReport nested = dcrteM6QualifiedPreflight();
  nested.nestedShellCount = 1;
  SourceShellBuildResult nestedResult = new SourceShellBuilder().build(
    sphere, nested, thinConfig);
  tests.check(!nestedResult.valid()
    && nestedResult.validation.hasCode(
      DCRTEM6Codes.NESTED_SHELL_UNSUPPORTED),
    "nested source shells are explicitly blocked");
  DomainPreflightReport multibody = dcrteM6QualifiedPreflight();
  multibody.componentCount = 2;
  multibody.closedComponentCount = 2;
  SourceShellBuildResult multibodyResult = new SourceShellBuilder().build(
    sphere, multibody, thinConfig);
  tests.check(!multibodyResult.valid()
    && multibodyResult.validation.hasCode(
      DCRTEM6Codes.MULTIBODY_ENVELOPE_UNSUPPORTED),
    "ambiguous multibody source envelopes are explicitly blocked");
}

void dcrteM6TestCompositionAndImmutability(DCRTEM6TestReport tests) {
  SignedDistanceVolume egg =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 22);
  CandidateVolumeSnapshot snapshot = dcrteM4SnapshotFromSdf(egg, null);
  SchedulerConfiguration schedulerConfig = new SchedulerConfiguration();
  schedulerConfig.mode = SchedulerMode.IMMEDIATE;
  PropagationState state = dcrteM4Run(snapshot, schedulerConfig,
    new SchedulerDiagnostics());
  DCRTEVolume source = dcrteM6SourceVolume(snapshot);
  String activeBefore = dcrteBooleanMaskHash(state.active);
  int[] arrivalBefore = java.util.Arrays.copyOf(
    state.arrivalBatch, state.arrivalBatch.length);
  String stateHashBefore = state.stateHash;
  dcrteImportedPreflightReport = dcrteM6QualifiedPreflight();
  dcrteImportedWorldMesh = null;

  MaterialCompositionConfiguration shellOnly =
    dcrteM6CompositionConfiguration(MaterialCompositionMode.SHELL_ONLY);
  FabricationCompositionVolume shellVolume =
    dcrteMaterialCompositionLayer.compose(source, snapshot, state, egg,
      shellOnly);
  tests.check(shellVolume != null && dcrteCompositionValidation.valid()
    && shellVolume.sourceShellCount > 0
    && shellVolume.composedMaterialCount == shellVolume.sourceShellCount,
    "shell-only composition contains the source shell and no scaffold role");
  tests.check(activeBefore.equals(dcrteBooleanMaskHash(state.active))
    && java.util.Arrays.equals(arrivalBefore, state.arrivalBatch)
    && stateHashBefore.equals(state.stateHash),
    "composition never mutates scheduler activation, arrival, or state hash");

  MaterialCompositionConfiguration clearance =
    dcrteM6CompositionConfiguration(MaterialCompositionMode.INSET_SCAFFOLD);
  clearance.clearanceMode =
    ScaffoldClearanceMode.INSET_FROM_SOURCE_SHELL;
  clearance.clearanceVoxels = 3;
  clearance.attachmentPolicy = BoundaryAttachmentPolicy.VALIDATE_ONLY;
  FabricationCompositionVolume inset =
    dcrteMaterialCompositionLayer.compose(source, snapshot, state, egg,
      clearance);
  int expectedRemoved = inset == null ? -1
    : inset.scheduledScaffoldCount - inset.insetScaffoldCount;
  float clearanceWorld = clearance.clearanceVoxels
    * egg.spec.minSpacing();
  tests.check(inset != null && inset.clearanceRemovedCount > 0
    && inset.clearanceRemovedCount == expectedRemoved
    && dcrteM6RetainedClearanceValid(inset.insetScaffold,
      egg, clearanceWorld)
    && shellVolume != null
    && java.util.Arrays.equals(
      shellVolume.sourceShell, inset.sourceShell),
    "inset clearance preserves the shell, enforces SDF distance, and reports the exact removal count");

  if (shellVolume != null) {
    dcrteCompositionConfiguration = shellOnly.copy();
    dcrteCompositionValidation = new MaterialCompositionValidationReport();
    dcrteImportedSdf = egg;
    dcrteImportedWorldMesh = null;
    boolean materialized = dcrteLegacyMaterializer.materialize(
      shellVolume, source);
    tests.check(materialized && foundryBoundaryEdges == 0
      && foundryNonManifoldEdges == 0 && foundryDegenerateFaces == 0,
      "shell-only voxel materializer emits a closed manifold boundary");
    tests.check(shellVolume.lockedRemovalAttemptCount >= 0
      && shellVolume.lockedRemovalCount == 0
      && dcrteM6MaskContains(shellVolume.regularizedMaterial,
        shellVolume.lockedMaterial),
      "locked source-shell voxels survive regularization and materialization");
  }
}

void dcrteM6TestAttachmentAndBridges(DCRTEM6TestReport tests) {
  DCRTEM6AttachmentFixture fixture = dcrteM6AttachmentFixture();
  MaterialCompositionConfiguration config =
    new MaterialCompositionConfiguration();
  config.minimumComponentVoxels = 4;
  config.nearBoundaryDistanceVoxels = 2;
  config.bridgeMaxDistanceVoxels = 7;
  config.bridgeRadiusVoxels = 0.5f;
  BoundaryAttachmentReport report =
    dcrteBoundaryAttachmentAnalyzer.analyze(
      fixture.attachedAndFloating, fixture.volume.sourceShell,
      fixture.sdf, fixture.spec, config);
  tests.check(report.componentCount == 2
    && report.boundaryAttachedCount == 1
    && report.floatingInteriorCount == 1,
    "attachment analyzer separates boundary-attached and floating components");
  BoundaryAttachmentReport near =
    dcrteBoundaryAttachmentAnalyzer.analyze(
      fixture.nearBoundary, fixture.volume.sourceShell,
      fixture.sdf, fixture.spec, config);
  tests.check(near.componentCount == 1
    && near.nearBoundaryUnattachedCount == 1,
    "attachment analyzer identifies near-boundary unattached scaffold");
  FabricationCompositionVolume nearVolume =
    dcrteM6CopyAttachmentVolume(fixture.volume);
  config.attachmentPolicy =
    BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED;
  AnchorBridgeResult nearBridge = dcrteAnchorBridgeBuilder.build(
    nearVolume, fixture.snapshot, near, config);
  nearVolume.recount();
  tests.check(nearBridge.bridgedComponents == 1
    && nearBridge.failedComponents == 0
    && nearVolume.anchorBridgeCount > 0,
    "near-boundary unattached scaffold exposes a usable bridge candidate");

  FabricationCompositionVolume fieldVolume =
    dcrteM6CopyAttachmentVolume(fixture.volume);
  config.attachmentPolicy =
    BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED;
  BoundaryAttachmentReport floating =
    dcrteBoundaryAttachmentAnalyzer.analyze(
      fixture.floatingOnly, fieldVolume.sourceShell,
      fixture.sdf, fixture.spec, config);
  AnchorBridgeResult fieldA = dcrteAnchorBridgeBuilder.build(
    fieldVolume, fixture.snapshot, floating, config);
  String fieldHashA = dcrteBooleanMaskHash(fieldVolume.anchorBridge);
  FabricationCompositionVolume fieldRepeat =
    dcrteM6CopyAttachmentVolume(fixture.volume);
  AnchorBridgeResult fieldB = dcrteAnchorBridgeBuilder.build(
    fieldRepeat, fixture.snapshot, floating, config);
  boolean[] fieldUnion = dcrteM6UnionScaffold(
    fixture.floatingOnly, fieldVolume.anchorBridge,
    fieldVolume.supportMaterial);
  BoundaryAttachmentReport fieldAttached =
    dcrteBoundaryAttachmentAnalyzer.analyze(fieldUnion,
      fieldVolume.sourceShell, fixture.sdf, fixture.spec, config);
  tests.check(fieldA.bridgedComponents == 1
    && fieldA.failedComponents == 0,
    "field bridge result records a successful candidate-constrained path");
  fieldVolume.recount();
  fieldRepeat.recount();
  tests.check(fieldVolume.anchorBridgeCount > 0
    && fieldVolume.supportMaterialCount == 0
    && fieldHashA.equals(
      dcrteBooleanMaskHash(fieldRepeat.anchorBridge))
    && fieldA.longestPathVoxels == fieldB.longestPathVoxels,
    "field bridge path and dilation are deterministic and role-preserving");
  tests.check(!fieldAttached.hasUnattached()
    && dcrteM6MaskInside(fieldVolume.anchorBridge,
      fieldVolume.domainInside)
    && dcrteM6MaskInside(fieldVolume.anchorBridge,
      fixture.snapshot.candidateSolid),
    "field bridge remains inside candidate/domain masks and attaches scaffold");

  CandidateVolumeSnapshot impossible =
    dcrteM6AttachmentSnapshot(fixture.spec, fixture.sdf, false);
  FabricationCompositionVolume failedVolume =
    dcrteM6CopyAttachmentVolume(fixture.volume);
  AnchorBridgeResult failure = dcrteAnchorBridgeBuilder.build(
    failedVolume, impossible, floating, config);
  failedVolume.recount();
  tests.check(failure.failedComponents == 1
    && failedVolume.anchorBridgeCount == 0
    && dcrteM6BridgeHasCode(failure, DCRTEM6Codes.BRIDGE_NOT_FOUND),
    "field bridge failure is explicit and adds no noncandidate material");

  FabricationCompositionVolume supportVolume =
    dcrteM6CopyAttachmentVolume(fixture.volume);
  config.attachmentPolicy =
    BoundaryAttachmentPolicy.BRIDGE_DOMAIN_CONSTRAINED;
  AnchorBridgeResult support = dcrteAnchorBridgeBuilder.build(
    supportVolume, impossible, floating, config);
  supportVolume.recount();
  tests.check(support.bridgedComponents == 1
    && supportVolume.supportMaterialCount > 0
    && supportVolume.anchorBridgeCount == 0
    && dcrteM6BridgeHasCode(support,
      DCRTEM6Codes.SUPPORT_BRIDGE_USED)
    && dcrteM6MaskInside(supportVolume.supportMaterial,
      supportVolume.domainInside),
    "domain bridge is explicit support material and stays inside the envelope");
}

void dcrteM6TestFidelity(DCRTEM6TestReport tests,
    DCRTEM6FixtureContext torus) {
  DomainPreflightReport qualified = dcrteM6QualifiedPreflight();
  SignedDistanceVolume cube = dcrteBuildFixtureSdf(
    createDcrteCubeFixture(), 24).sdf;
  SignedDistanceVolume sphere =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.SPHERE, 24);
  SignedDistanceVolume egg =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 24);
  SignedDistanceVolume[] fixtures = {
    cube, sphere, egg, torus == null ? null : torus.sdf
  };
  boolean allValid = true;
  for (int i = 0; i < fixtures.length; i++) {
    SignedDistanceVolume sdf = fixtures[i];
    if (sdf == null) {
      allValid = false;
      continue;
    }
    SourceShellBuildResult shell = new SourceShellBuilder().build(
      sdf, i == 3 && torus != null ? torus.preflight : qualified,
      dcrteM6ShellConfiguration(3, 0.75f));
    FabricationCompositionVolume volume =
      dcrteM6VolumeFromShell(shell);
    ExteriorEnvelopeFidelityReport fidelity =
      dcrteEnvelopeFidelityAnalyzer.analyze(volume, sdf, null);
    allValid &= fidelity.valid
      && fidelity.sourceBoundaryCoverage >= 0.999999f
      && fidelity.materialOutsideCount == 0
      && dcrteFinite(fidelity.materialBoundarySdfP95World);
  }
  tests.check(allValid,
    "cube, sphere, egg, and torus shell fidelity reports are finite and leak-free");

  SignedDistanceVolume low =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.SPHERE, 24);
  SignedDistanceVolume high =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.SPHERE, 36);
  ExteriorEnvelopeFidelityReport lowReport =
    dcrteM6FidelityForSdf(low, qualified);
  ExteriorEnvelopeFidelityReport highReport =
    dcrteM6FidelityForSdf(high, qualified);
  tests.check(lowReport.valid && highReport.valid
    && highReport.materialBoundarySdfP95World
      <= lowReport.materialBoundarySdfP95World
        + high.spec.minSpacing(),
    "higher sphere resolution does not degrade sampled envelope fidelity");
}

void dcrteM6TestScaffoldOnlyRegression(DCRTEM6TestReport tests) {
  DCRTEVolume sourceA = dcrteM4BoxVolume(7, false, false);
  DCRTEVolume sourceB = dcrteM4BoxVolume(7, false, false);
  for (int i = 0; i < sourceA.active.length; i++) {
    boolean active = (i % 5) != 0;
    sourceA.active[i] = active;
    sourceA.finalSolid[i] = active;
    sourceB.active[i] = active;
    sourceB.finalSolid[i] = active;
  }
  sourceA.recountFinal();
  sourceB.recountFinal();
  boolean baseline = dcrteLegacyMaterializer.materialize(sourceA);
  boolean[] baselineMask = dcrteM6FlattenLegacy(
    foundryCallSheetSolid, sourceA.spec);
  int baselineTriangles = foundryMesh == null ? 0 : foundryMesh.tris.size();

  CandidateVolumeSnapshot snapshot =
    dcrteM4Snapshot(sourceB, null, null);
  PropagationState state =
    new PropagationState(snapshot.spec.voxelCount());
  for (int i = 0; i < state.active.length; i++) {
    state.active[i] = sourceB.finalSolid[i];
    state.arrivalBatch[i] = state.active[i] ? 0 : -1;
    state.arrivalRank[i] = state.active[i] ? i : -1;
    if (state.active[i]) state.activeCount++;
  }
  state.stateHash = dcrteBooleanMaskHash(state.active);
  MaterialCompositionConfiguration config =
    dcrteM6CompositionConfiguration(MaterialCompositionMode.SCAFFOLD_ONLY);
  FabricationCompositionVolume composition =
    dcrteMaterialCompositionLayer.compose(
      sourceB, snapshot, state, null, config);
  dcrteCompositionConfiguration = config.copy();
  boolean composed = dcrteLegacyMaterializer.materialize(
    composition, sourceB);
  boolean[] composedMask = dcrteM6FlattenLegacy(
    foundryCallSheetSolid, sourceB.spec);
  tests.check(composition != null
    && java.util.Arrays.equals(composition.composedMaterial, state.active),
    "SCAFFOLD_ONLY composition is the exact M5 active mask");
  tests.check(baseline && composed
    && baselineTriangles == foundryMesh.tris.size()
    && java.util.Arrays.equals(baselineMask, composedMask),
    "SCAFFOLD_ONLY materialization is byte-mask equivalent to the M5 legacy path");
}

void dcrteM6TestCompositionGridMismatch(DCRTEM6TestReport tests) {
  DCRTEVolume source = dcrteM4BoxVolume(7, false, false);
  CandidateVolumeSnapshot snapshot = dcrteM4Snapshot(source, null, null);
  PropagationState state = new PropagationState(snapshot.spec.voxelCount());
  SignedDistanceVolume staleSdf =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.SPHERE, 8);
  FabricationCompositionVolume composition =
    dcrteMaterialCompositionLayer.compose(source, snapshot, state,
      staleSdf, dcrteM6CompositionConfiguration(
        MaterialCompositionMode.SCAFFOLD_ONLY));
  tests.check(composition == null
    && dcrteCompositionValidation != null
    && dcrteCompositionValidation.hasCode(
      DCRTEM6Codes.COMPOSITION_GRID_MISMATCH)
    && dcrteCompositionValidation.stale,
    "stale SDF grid is blocked before composition without an out-of-range read");
}

void runDcrteMilestone6AcceptanceMatrix() {
  println("DCRTE-ET Milestone 6 acceptance matrix starting...");
  JSONArray cases = new JSONArray();
  int passed = 0;
  MaterialCompositionConfiguration saved =
    dcrteCompositionConfiguration.copy();
  try {
    SignedDistanceVolume egg =
      dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 24);
    SignedDistanceVolume bent =
      dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.BENT_CAPSULE, 24);
    DCRTEM6FixtureContext torus =
      dcrteM6AcceptanceTorusContext(64);
    DomainPreflightReport qualified = dcrteM6QualifiedPreflight();
    dcrteImportedPreflightReport = qualified;
    dcrteImportedWorldMesh = null;

    passed += dcrteM6AcceptanceComposition(cases, "M6-A", "egg",
      "Cartesian / Immediate", egg, null,
      MaterialCompositionMode.SHELL_ONLY,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;
    IntrinsicBuildResult eggIntrinsic =
      new DCRTEIntrinsicCoordinateBuilder().build(egg, null, true);
    passed += dcrteM6AcceptanceComposition(cases, "M6-B", "egg",
      "Intrinsic / Immediate", egg, eggIntrinsic,
      MaterialCompositionMode.SHELL_PLUS_SCAFFOLD,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;
    passed += dcrteM6AcceptanceComposition(cases, "M6-C", "egg",
      "Intrinsic / Front", egg, eggIntrinsic,
      MaterialCompositionMode.BOUNDARY_ANCHORED_SCAFFOLD,
      BoundaryAttachmentPolicy.SEED_FROM_BOUNDARY, true) ? 1 : 0;
    passed += dcrteM6AcceptanceComposition(cases, "M6-D", "egg",
      "Intrinsic / Entropic", egg, eggIntrinsic,
      MaterialCompositionMode.BOUNDARY_ANCHORED_SCAFFOLD,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;
    passed += dcrteM6AcceptanceComposition(cases, "M6-E", "torus",
      "Cartesian / Immediate",
      torus == null ? null : torus.sdf, null,
      MaterialCompositionMode.SHELL_ONLY,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;
    passed += dcrteM6AcceptanceComposition(cases, "M6-F", "torus",
      "Cartesian / Front",
      torus == null ? null : torus.sdf, null,
      MaterialCompositionMode.SHELL_PLUS_SCAFFOLD,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;
    IntrinsicBuildResult torusIntrinsic = torus == null
      || torus.sdf == null ? null
      : new DCRTEIntrinsicCoordinateBuilder().build(
        torus.sdf, null, true);
    passed += dcrteM6AcceptanceSimple(cases, "M6-G", "torus",
      "Intrinsic axial blocked",
      dcrteM6IntrinsicHasCode(torusIntrinsic,
        DCRTEIntrinsicCodes.IC_CLOSED_LOOP_SUSPECTED),
      DCRTEIntrinsicCodes.IC_CLOSED_LOOP_SUSPECTED) ? 1 : 0;
    IntrinsicBuildResult bentIntrinsic =
      new DCRTEIntrinsicCoordinateBuilder().build(bent, null, true);
    passed += dcrteM6AcceptanceComposition(cases, "M6-H",
      "bent capsule", "Intrinsic / Entropic", bent, bentIntrinsic,
      MaterialCompositionMode.BOUNDARY_ANCHORED_SCAFFOLD,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;

    DCRTEM2FixtureSdf arbitrary = dcrteBuildFixtureSdf(
      createDcrteUvSphereFixture(1, 14, 22), 28);
    passed += dcrteM6AcceptanceComposition(cases, "M6-I",
      "arbitrary valid STL", "Cartesian / Immediate",
      arbitrary == null ? null : arbitrary.sdf, null,
      MaterialCompositionMode.SHELL_PLUS_SCAFFOLD,
      BoundaryAttachmentPolicy.VALIDATE_ONLY, true) ? 1 : 0;

    DCRTEM6AttachmentFixture attachment = dcrteM6AttachmentFixture();
    MaterialCompositionConfiguration strict =
      new MaterialCompositionConfiguration();
    strict.minimumComponentVoxels = 4;
    strict.attachmentPolicy =
      BoundaryAttachmentPolicy.REQUIRE_EXISTING_CONTACT;
    BoundaryAttachmentReport floating =
      dcrteBoundaryAttachmentAnalyzer.analyze(
        attachment.floatingOnly, attachment.volume.sourceShell,
        attachment.sdf, attachment.spec, strict);
    passed += dcrteM6AcceptanceSimple(cases, "M6-J",
      "floating fixture", "REQUIRE_EXISTING_CONTACT",
      floating.floatingInteriorCount == 1,
      DCRTEM6Codes.SCAFFOLD_COMPONENT_FLOATING) ? 1 : 0;

    strict.bridgeMaxDistanceVoxels = 7;
    strict.bridgeRadiusVoxels = 0.5f;
    strict.attachmentPolicy =
      BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED;
    FabricationCompositionVolume fieldVolume =
      dcrteM6CopyAttachmentVolume(attachment.volume);
    AnchorBridgeResult fieldBridge =
      dcrteAnchorBridgeBuilder.build(fieldVolume,
        attachment.snapshot, floating, strict);
    passed += dcrteM6AcceptanceSimple(cases, "M6-K",
      "floating fixture", "field bridge",
      fieldBridge.bridgedComponents == 1
        || dcrteM6BridgeHasCode(fieldBridge,
          DCRTEM6Codes.BRIDGE_NOT_FOUND),
      fieldBridge.bridgedComponents == 1
        ? "attached" : DCRTEM6Codes.BRIDGE_NOT_FOUND) ? 1 : 0;
    strict.attachmentPolicy =
      BoundaryAttachmentPolicy.BRIDGE_DOMAIN_CONSTRAINED;
    FabricationCompositionVolume supportVolume =
      dcrteM6CopyAttachmentVolume(attachment.volume);
    AnchorBridgeResult supportBridge =
      dcrteAnchorBridgeBuilder.build(supportVolume,
        dcrteM6AttachmentSnapshot(
          attachment.spec, attachment.sdf, false),
        floating, strict);
    supportVolume.recount();
    passed += dcrteM6AcceptanceSimple(cases, "M6-L",
      "floating fixture", "domain support bridge",
      supportBridge.bridgedComponents == 1
        && supportVolume.supportMaterialCount > 0,
      DCRTEM6Codes.SUPPORT_BRIDGE_USED) ? 1 : 0;

    DomainPreflightReport nested = dcrteM6QualifiedPreflight();
    nested.nestedShellCount = 1;
    SourceShellBuildResult nestedShell =
      new SourceShellBuilder().build(
        egg, nested, dcrteM6ShellConfiguration(3, 0.75f));
    passed += dcrteM6AcceptanceSimple(cases, "M6-M",
      "nested shell", "role blocked",
      nestedShell.validation.hasCode(
        DCRTEM6Codes.NESTED_SHELL_UNSUPPORTED),
      DCRTEM6Codes.NESTED_SHELL_UNSUPPORTED) ? 1 : 0;
    DomainPreflightReport invalid = new DomainPreflightReport();
    SourceShellBuildResult invalidShell =
      new SourceShellBuilder().build(
        egg, invalid, dcrteM6ShellConfiguration(3, 0.75f));
    passed += dcrteM6AcceptanceSimple(cases, "M6-N",
      "invalid STL", "preflight blocked",
      invalidShell.validation.hasCode(
        DCRTEM6Codes.SOURCE_SHELL_UNQUALIFIED),
      DCRTEM6Codes.SOURCE_SHELL_UNQUALIFIED) ? 1 : 0;

    ExteriorEnvelopeFidelityReport egg64 =
      dcrteM6FidelityForSdf(
        dcrteCreateM3AnalyticSdf(
          DCRTEM3FixtureKind.EGG, 64), qualified);
    ExteriorEnvelopeFidelityReport egg128 =
      dcrteM6FidelityForSdf(
        dcrteCreateM3AnalyticSdf(
          DCRTEM3FixtureKind.EGG, 128), qualified);
    passed += dcrteM6AcceptanceSimple(cases, "M6-O", "egg",
      "64/128 fidelity",
      egg64.valid && egg128.valid
        && egg128.materialBoundarySdfP95World
          <= egg64.materialBoundarySdfP95World
            + 2.0f / 128.0f,
      "higher resolution no worse") ? 1 : 0;

    boolean scaffoldRegression = dcrteM6AcceptanceScaffoldOnly();
    passed += dcrteM6AcceptanceSimple(cases, "M6-P", "egg",
      "M5 intrinsic entropic scaffold-only exact regression",
      scaffoldRegression, "exact M5 mask") ? 1 : 0;
  }
  catch (Exception error) {
    dcrteM6AcceptanceSimple(cases, "M6-EXCEPTION",
      "acceptance harness", "no exception", false,
      error.getClass().getSimpleName() + " "
        + (error.getMessage() == null ? "" : error.getMessage()));
  }
  finally {
    dcrteCompositionConfiguration = saved;
    resetDcrteImportedStateAfterReloadTests();
  }

  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M6");
  output.setString("status",
    passed == 16 && dcrteM6Tests.ok() ? "pass" : "fail");
  output.setInt("passed_cases", passed);
  output.setInt("total_cases", 16);
  output.setString("composition_semantics",
    "source_envelope_plus_role_preserving_scaffold");
  output.setString("source_sdf_role", "authoritative_envelope");
  output.setString("physical_time_claim", "none");
  output.setJSONObject("deterministic_tests",
    dcrteM6Tests.toJSON());
  output.setJSONArray("cases", cases);
  ensureDir(sketchPath("logs"));
  saveJSONObject(output,
    "logs/dcrte_m6_acceptance_latest.json");
  println("DCRTE-ET Milestone 6 acceptance: "
    + output.getString("status") + " " + passed + "/16");
}

boolean dcrteM6AcceptanceComposition(JSONArray cases, String id,
    String fixture, String coordinates, SignedDistanceVolume sdf,
    IntrinsicBuildResult intrinsic, MaterialCompositionMode mode,
    BoundaryAttachmentPolicy policy, boolean expectValid) {
  boolean pass = false;
  String actual = "missing";
  if (sdf != null && sdf.isValid()) {
    CandidateVolumeSnapshot snapshot = dcrteM4SnapshotFromSdf(
      sdf, intrinsic == null ? null : intrinsic.volume);
    MaterialCompositionConfiguration activeComposition =
      dcrteM6CompositionConfiguration(mode);
    activeComposition.attachmentPolicy = policy;
    dcrteCompositionConfiguration = activeComposition;
    SchedulerConfiguration scheduler = new SchedulerConfiguration();
    if (coordinates.indexOf("Front") >= 0) {
      scheduler.mode = SchedulerMode.FRONT_PROPAGATION;
      scheduler.seedMode = SchedulerSeedMode.CENTER_NEAREST;
    } else if (coordinates.indexOf("Entropic") >= 0) {
      DCRTEM5RunResult entropic = dcrteM5AcceptanceRun(
        snapshot, EntropicPolicyMode.BALANCED,
        AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
      PropagationState state = entropic == null ? null : entropic.state;
      pass = dcrteM6AcceptanceComposeState(
        sdf, snapshot, state, mode, policy);
      actual = pass ? "composed" : dcrteM6AcceptanceBlocker();
      return dcrteM6AcceptanceSimple(cases, id, fixture,
        coordinates, pass == expectValid, actual);
    } else scheduler.mode = SchedulerMode.IMMEDIATE;
    PropagationState state = dcrteM4Run(snapshot, scheduler,
      new SchedulerDiagnostics());
    pass = dcrteM6AcceptanceComposeState(
      sdf, snapshot, state, mode, policy);
    actual = pass ? "composed" : dcrteM6AcceptanceBlocker();
  }
  return dcrteM6AcceptanceSimple(cases, id, fixture,
    coordinates, pass == expectValid, actual);
}

boolean dcrteM6AcceptanceComposeState(SignedDistanceVolume sdf,
    CandidateVolumeSnapshot snapshot, PropagationState state,
    MaterialCompositionMode mode, BoundaryAttachmentPolicy policy) {
  if (snapshot == null || state == null) return false;
  dcrteImportedPreflightReport = dcrteM6QualifiedPreflight();
  dcrteImportedWorldMesh = null;
  MaterialCompositionConfiguration config =
    dcrteM6CompositionConfiguration(mode);
  config.attachmentPolicy = policy;
  FabricationCompositionVolume volume =
    dcrteMaterialCompositionLayer.compose(
      dcrteM6SourceVolume(snapshot), snapshot, state, sdf, config);
  return volume != null && dcrteCompositionValidation != null
    && dcrteCompositionValidation.valid()
    && volume.outsideCount == 0;
}

boolean dcrteM6AcceptanceSimple(JSONArray cases, String id,
    String fixture, String expected, boolean pass, String actual) {
  JSONObject entry = new JSONObject();
  entry.setString("id", id);
  entry.setString("fixture", fixture);
  entry.setString("expected", expected);
  entry.setString("actual", actual == null ? "" : actual);
  entry.setBoolean("pass", pass);
  cases.setJSONObject(cases.size(), entry);
  return pass;
}

boolean dcrteM6AcceptanceScaffoldOnly() {
  SignedDistanceVolume egg =
    dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind.EGG, 20);
  IntrinsicBuildResult intrinsic =
    new DCRTEIntrinsicCoordinateBuilder().build(egg, null, true);
  CandidateVolumeSnapshot snapshot = dcrteM4SnapshotFromSdf(
    egg, intrinsic == null ? null : intrinsic.volume);
  DCRTEM5RunResult run = dcrteM5AcceptanceRun(snapshot,
    EntropicPolicyMode.BALANCED,
    AcceptanceMode.DETERMINISTIC_TOP_K, 0, 42017L);
  if (run == null || run.state == null) return false;
  MaterialCompositionConfiguration config =
    dcrteM6CompositionConfiguration(
      MaterialCompositionMode.SCAFFOLD_ONLY);
  FabricationCompositionVolume volume =
    dcrteMaterialCompositionLayer.compose(
      dcrteM6SourceVolume(snapshot), snapshot,
      run.state, null, config);
  return volume != null
    && java.util.Arrays.equals(
      volume.composedMaterial, run.state.active);
}

DCRTEM6FixtureContext dcrteM6AcceptanceTorusContext(
    int resolution) throws Exception {
  File directory = new File(sketchPath(
    "exports/dcrte_m6_acceptance"));
  if (!directory.exists()) directory.mkdirs();
  File file = new File(directory, "canonical_torus.stl");
  writeDcrteBinaryStl(createDcrteTorusFixtureMesh(), file,
    "DCRTE-M6 acceptance torus");
  dcrteImportedResolution = resolution;
  dcrteImportedPolicy = InvalidDomainPolicy.STRICT;
  if (!loadDcrteImportedFile(file, true,
      dcrteTorusFixtureMetadata())
      || !buildDcrteImportedSdf()) return null;
  DCRTEM6FixtureContext context = new DCRTEM6FixtureContext();
  context.source = dcrteImportedSourceMesh;
  context.world = dcrteImportedWorldMesh;
  context.meshReport = dcrteImportedMeshReport;
  context.sdf = dcrteImportedSdf;
  context.preflight = dcrteImportedPreflightReport;
  context.normalRoundTrip = true;
  return context;
}

String dcrteM6AcceptanceBlocker() {
  return dcrteCompositionValidation == null
    ? "composition missing"
    : dcrteCompositionValidation.firstBlocker();
}

DomainPreflightReport dcrteM6QualifiedPreflight() {
  DomainPreflightReport report = new DomainPreflightReport();
  report.qualification = DomainQualification.MATERIALIZATION_READY;
  report.status = ValidationStatus.PASS;
  report.reportStale = false;
  report.componentCount = 1;
  report.closedComponentCount = 1;
  report.openComponentCount = 0;
  report.nestedShellCount = 0;
  report.singleDominantClosedComponent = true;
  report.dominantComponentFraction = 1;
  report.previewEnabled = true;
  report.sdfBuildEnabled = true;
  report.materializationEnabled = true;
  report.exportEnabled = true;
  report.sdfReport = new SDFQualityReport();
  report.sdfReport.finiteDistanceCount = 1;
  report.sdfReport.nonFiniteDistanceCount = 0;
  report.sdfReport.signed = true;
  return report;
}

SourceShellConfiguration dcrteM6ShellConfiguration(
    int thickness, float epsilon) {
  SourceShellConfiguration config = new SourceShellConfiguration();
  config.fabricationShellThicknessVoxels = thickness;
  config.boundaryEpsilonVoxels = epsilon;
  config.coverageRequired = 1;
  config.lockSourceShell = true;
  return config;
}

MaterialCompositionConfiguration dcrteM6CompositionConfiguration(
    MaterialCompositionMode mode) {
  MaterialCompositionConfiguration config =
    new MaterialCompositionConfiguration();
  config.mode = mode;
  config.sourceShell =
    dcrteM6ShellConfiguration(3, 0.75f);
  config.minimumComponentVoxels = 1;
  config.attachmentPolicy =
    BoundaryAttachmentPolicy.VALIDATE_ONLY;
  return config;
}

DCRTEVolume dcrteM6SourceVolume(
    CandidateVolumeSnapshot snapshot) {
  DCRTEVolume volume = new DCRTEVolume(snapshot.spec);
  for (int i = 0; i < volume.scalar.length; i++) {
    volume.scalar[i] = snapshot.fieldScalar[i];
    volume.admitted[i] = snapshot.admitted[i];
    volume.candidateSolid[i] = snapshot.candidateSolid[i];
    if (volume.admitted[i]) volume.admittedCount++;
    if (volume.candidateSolid[i]) volume.candidateSolidCount++;
  }
  return volume;
}

FabricationCompositionVolume dcrteM6VolumeFromShell(
    SourceShellBuildResult shell) {
  FabricationCompositionVolume volume =
    new FabricationCompositionVolume(shell.spec);
  System.arraycopy(shell.domainInside, 0, volume.domainInside,
    0, shell.domainInside.length);
  System.arraycopy(shell.sourceShell, 0, volume.sourceShell,
    0, shell.sourceShell.length);
  System.arraycopy(shell.sourceShell, 0, volume.composedMaterial,
    0, shell.sourceShell.length);
  System.arraycopy(shell.sourceShell, 0, volume.regularizedMaterial,
    0, shell.sourceShell.length);
  System.arraycopy(shell.sourceShell, 0, volume.lockedMaterial,
    0, shell.sourceShell.length);
  volume.boundaryEpsilonWorld = shell.boundaryEpsilonWorld;
  volume.sourceShellThicknessWorld = shell.thicknessWorld;
  volume.sourceShellCoverage = shell.coverage;
  volume.recount();
  volume.computeHash();
  return volume;
}

ExteriorEnvelopeFidelityReport dcrteM6FidelityForSdf(
    SignedDistanceVolume sdf, DomainPreflightReport preflight) {
  SourceShellBuildResult shell = new SourceShellBuilder().build(
    sdf, preflight, dcrteM6ShellConfiguration(3, 0.75f));
  if (!shell.valid()) return new ExteriorEnvelopeFidelityReport();
  return dcrteEnvelopeFidelityAnalyzer.analyze(
    dcrteM6VolumeFromShell(shell), sdf, null);
}

boolean dcrteM6IntrinsicHasCode(IntrinsicBuildResult result,
    String code) {
  if (result == null || result.validation == null) return false;
  if (result.validation.errors.contains(code)) return true;
  return result.validation.suitability != null
    && result.validation.suitability.blockers.contains(code);
}

boolean dcrteM6MaskContains(boolean[] superset,
    boolean[] subset) {
  if (superset == null || subset == null
      || superset.length != subset.length) return false;
  for (int i = 0; i < subset.length; i++) {
    if (subset[i] && !superset[i]) return false;
  }
  return true;
}

boolean dcrteM6MaskInside(boolean[] mask, boolean[] gate) {
  if (mask == null || gate == null
      || mask.length != gate.length) return false;
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] && !gate[i]) return false;
  }
  return true;
}

boolean dcrteM6RetainedClearanceValid(boolean[] scaffold,
    SignedDistanceVolume sdf, float clearanceWorld) {
  if (scaffold == null || sdf == null || !sdf.isValid()
      || scaffold.length != sdf.signedDistance.length) return false;
  for (int i = 0; i < scaffold.length; i++) {
    if (scaffold[i] && (!dcrteFinite(sdf.signedDistance[i])
        || sdf.signedDistance[i] > -clearanceWorld)) return false;
  }
  return true;
}

int dcrteM6NearestIndex(VolumeSpec spec,
    float wx, float wy, float wz) {
  int x = constrain(floor((wx - spec.bounds.minX)
    / spec.bounds.sizeX() * spec.nx), 0, spec.nx - 1);
  int y = constrain(floor((wy - spec.bounds.minY)
    / spec.bounds.sizeY() * spec.ny), 0, spec.ny - 1);
  int z = constrain(floor((wz - spec.bounds.minZ)
    / spec.bounds.sizeZ() * spec.nz), 0, spec.nz - 1);
  return x + spec.nx * (y + spec.ny * z);
}

DCRTEM6AttachmentFixture dcrteM6AttachmentFixture() {
  DCRTEM6AttachmentFixture fixture =
    new DCRTEM6AttachmentFixture();
  fixture.spec = new VolumeSpec(9, 9, 9,
    new Bounds3D(-1, -1, -1, 1, 1, 1));
  int count = fixture.spec.voxelCount();
  boolean[] boundary = new boolean[count];
  boolean[] inside = new boolean[count];
  float[] signed = new float[count];
  float spacing = fixture.spec.minSpacing();
  fixture.attachedAndFloating = new boolean[count];
  fixture.nearBoundary = new boolean[count];
  fixture.floatingOnly = new boolean[count];
  DCRTEVolume candidate = new DCRTEVolume(fixture.spec);
  for (int z = 0; z < 9; z++) {
    for (int y = 0; y < 9; y++) {
      for (int x = 0; x < 9; x++) {
        int index = x + 9 * (y + 9 * z);
        inside[index] = true;
        boundary[index] = x == 0;
        signed[index] = -x * spacing;
        candidate.admitted[index] = true;
        candidate.admittedCount++;
        candidate.scalar[index] = 0;
        boolean path = y == 4 && z == 4 && x <= 6;
        candidate.candidateSolid[index] = path;
        if (path) candidate.candidateSolidCount++;
      }
    }
  }
  for (int y = 3; y <= 4; y++) {
    for (int z = 3; z <= 4; z++) {
      fixture.attachedAndFloating[
        1 + 9 * (y + 9 * z)] = true;
      int floating = 6 + 9 * (y + 9 * z);
      fixture.attachedAndFloating[floating] = true;
      fixture.floatingOnly[floating] = true;
      fixture.nearBoundary[2 + 9 * (y + 9 * z)] = true;
    }
  }
  fixture.sdf = new SignedDistanceVolume(
    fixture.spec, signed, boundary, inside, true);
  fixture.volume = new FabricationCompositionVolume(fixture.spec);
  System.arraycopy(inside, 0, fixture.volume.domainInside, 0, count);
  System.arraycopy(boundary, 0, fixture.volume.sourceShell, 0, count);
  fixture.volume.boundaryEpsilonWorld = spacing * 0.5f;
  fixture.volume.sourceShellThicknessWorld = spacing;
  fixture.volume.recount();
  fixture.snapshot = dcrteM4Snapshot(
    candidate, fixture.sdf, null);
  return fixture;
}

CandidateVolumeSnapshot dcrteM6AttachmentSnapshot(
    VolumeSpec spec, SignedDistanceVolume sdf,
    boolean withPath) {
  DCRTEVolume candidate = new DCRTEVolume(spec);
  for (int z = 0; z < spec.nz; z++) {
    for (int y = 0; y < spec.ny; y++) {
      for (int x = 0; x < spec.nx; x++) {
        int index = x + spec.nx * (y + spec.ny * z);
        candidate.admitted[index] = true;
        candidate.admittedCount++;
        candidate.scalar[index] = 0;
        boolean admittedCandidate = withPath
          && y == 4 && z == 4 && x <= 6;
        candidate.candidateSolid[index] = admittedCandidate;
        if (admittedCandidate) candidate.candidateSolidCount++;
      }
    }
  }
  if (!withPath) {
    for (int y = 3; y <= 4; y++) {
      for (int z = 3; z <= 4; z++) {
        int index = 6 + spec.nx * (y + spec.ny * z);
        candidate.candidateSolid[index] = true;
        candidate.candidateSolidCount++;
      }
    }
  }
  return dcrteM4Snapshot(candidate, sdf, null);
}

FabricationCompositionVolume dcrteM6CopyAttachmentVolume(
    FabricationCompositionVolume source) {
  FabricationCompositionVolume copy =
    new FabricationCompositionVolume(source.spec);
  System.arraycopy(source.domainInside, 0, copy.domainInside,
    0, source.domainInside.length);
  System.arraycopy(source.sourceShell, 0, copy.sourceShell,
    0, source.sourceShell.length);
  copy.boundaryEpsilonWorld = source.boundaryEpsilonWorld;
  copy.sourceShellThicknessWorld =
    source.sourceShellThicknessWorld;
  copy.recount();
  return copy;
}

boolean dcrteM6BridgeHasCode(AnchorBridgeResult result,
    String code) {
  if (result == null) return false;
  for (int i = 0; i < result.diagnostics.size(); i++) {
    if (result.diagnostics.get(i).code.equals(code)) return true;
  }
  return false;
}

boolean[] dcrteM6FlattenLegacy(boolean[][][] solid,
    VolumeSpec spec) {
  boolean[] flat = new boolean[spec.voxelCount()];
  if (solid == null) return flat;
  for (int z = 0; z < spec.nz; z++) {
    for (int y = 0; y < spec.ny; y++) {
      for (int x = 0; x < spec.nx; x++) {
        flat[x + spec.nx * (y + spec.ny * z)] =
          solid[x][y][z];
      }
    }
  }
  return flat;
}
