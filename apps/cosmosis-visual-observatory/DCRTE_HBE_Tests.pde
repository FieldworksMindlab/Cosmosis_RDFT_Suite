/* M6-HX deterministic sidecar tests. Expanded as each isolated channel is installed. */

DCRTEM1TestReport runDcrteHbeTests() {
  DCRTEM1TestReport tests = new DCRTEM1TestReport();
  try {
    HBEConfig defaults = new HBEConfig();
    tests.check(!dcrteHbeEnabled
      && defaults.influenceMode == HBEInfluenceMode.ANALYSIS_ONLY,
      "HBE defaults disabled and analysis-only");
    tests.check(defaults.configurationHash().equals(defaults.copy().configurationHash()),
      "HBE configuration identity is deterministic");

    HBEConfig geometry = defaults.copy();
    geometry.domainResponseMode = HBEDomainResponseMode.PAPER_INSPIRED_NECK_SHORTENING;
    float previous = geometry.effectiveNeckLength(0);
    boolean monotonic = abs(previous - geometry.neckLengthMaximum) <= 0.000001f;
    for (int i = 1; i <= 10; i++) {
      float next = geometry.effectiveNeckLength(i / 10.0f);
      monotonic &= next <= previous + 0.000001f;
      previous = next;
    }
    monotonic &= abs(previous - geometry.neckLengthMinimum) <= 0.000001f;
    tests.check(monotonic, "HBE neck shortening is monotonic with exact endpoints");

    HBEFrozenMetrics frozenA = new HBEFrozenMetrics(0.31f, 0.72f, 0.18f,
      0.44f, 0.63f, 0.56f, 12.5f, 812, defaults);
    HBEFrozenMetrics frozenB = new HBEFrozenMetrics(0.31f, 0.72f, 0.18f,
      0.44f, 0.63f, 0.56f, 12.5f, 812, defaults.copy());
    tests.check(frozenA.contentHash.equals(frozenB.contentHash)
      && dcrteFinite(frozenA.feedback),
      "HBE feedback capture is finite and immutable by value");

    HBEConfig manual = defaults.copy();
    manual.feedbackSource = HBEFeedbackSource.MANUAL;
    manual.manualFeedback = 0.24f;
    HBEFrozenMetrics frozenManual = new HBEFrozenMetrics(0, 0, 0, 0, 0, 0,
      4.5f, 99, manual);
    manual.manualFeedback = 0.91f;
    tests.check(abs(frozenManual.feedback - 0.24f) <= 0.000001f,
      "HBE feedback remains frozen after live configuration changes");

    TriangleMeshData fixtureA = createDcrteHbeDualLobeFixtureMesh(geometry, 0.25f);
    TriangleMeshData fixtureB = createDcrteHbeDualLobeFixtureMesh(geometry, 0.25f);
    MeshValidationResult fixtureValidation = new DCRTEMeshSanitizer().sanitize(fixtureA);
    tests.check(fixtureA != null && fixtureA.isStructurallyValid()
      && fixtureValidation != null && fixtureValidation.report != null
      && fixtureValidation.report.strictValid() && dcrteSignedMeshVolume(fixtureA) > 0,
      "HBE two-sided fixture is outward, watertight, and manifold");
    tests.check(dcrteHbeMeshHash(fixtureA).equals(dcrteHbeMeshHash(fixtureB)),
      "HBE fixture mesh is deterministic");

    IntrinsicCoordinateVolume intrinsic = dcrteHbeSyntheticIntrinsic(9, 3, 3);
    HBEIntrinsicObservables observables = new HBEIntrinsicObservables(intrinsic, defaults);
    int left = intrinsic.index(0, 1, 1), neck = intrinsic.index(4, 1, 1);
    int right = intrinsic.index(8, 1, 1);
    tests.check(observables.isValid() && observables.leftAnchor[left]
      && observables.neckBand[neck] && observables.rightAnchor[right]
      && abs(observables.xi[left] + 1) <= 0.000001f
      && abs(observables.xi[neck]) <= 0.000001f
      && abs(observables.xi[right] - 1) <= 0.000001f,
      "HBE intrinsic observables distinguish left, neck, and right");

    CandidateVolumeSnapshot candidate = dcrteHbeSyntheticCandidate(intrinsic, true);
    HBEMirrorMap mirrorA = new HBEMirrorMap(candidate, observables,
      HBEMirrorPolicy.AUTO_FRAME_CALIBRATED);
    HBEMirrorMap mirrorB = new HBEMirrorMap(candidate, observables,
      HBEMirrorPolicy.AUTO_FRAME_CALIBRATED);
    tests.check(mirrorA.isValid() && mirrorA.contentHash.equals(mirrorB.contentHash)
      && mirrorA.pairedFraction > 0.70f,
      "HBE mirror map is deterministic with broad symmetric coverage");

    HBEConnectivityReport connected = dcrteHbeAnalyzeConnectivity(
      candidate.candidateSolid, observables);
    boolean[] active = java.util.Arrays.copyOf(candidate.candidateSolid,
      candidate.candidateSolid.length);
    for (int z = 0; z < intrinsic.spec.nz; z++)
      for (int y = 0; y < intrinsic.spec.ny; y++)
        active[intrinsic.index(4, y, z)] = false;
    HBEConnectivityReport disconnected = dcrteHbeAnalyzeConnectivity(active, observables);
    tests.check(connected.validInput && connected.connected
      && connected.shortestPathSteps >= 0,
      "HBE candidate graph detects a six-connected bridge");
    tests.check(disconnected.validInput && !disconnected.connected,
      "HBE distinguishes a disconnected active state from connected candidacy");
    tests.check(connected.analysisHash.equals(
      dcrteHbeAnalyzeConnectivity(candidate.candidateSolid, observables).analysisHash),
      "HBE connectivity analysis is deterministic");

    HBEConfig analysisOnly = defaults.copy();
    analysisOnly.influenceMode = HBEInfluenceMode.ANALYSIS_ONLY;
    HBEFieldContext analysisContext = new HBEFieldContext(analysisOnly, frozenA, observables);
    FieldCoordinateSample coordinate = new FieldCoordinateSample().setCartesian(0, 0, 0);
    float identityBase = -0.1234567f;
    float identityResult = dcrteHbeFieldModifier.modify(
      identityBase, coordinate, neck, analysisContext);
    tests.check(Float.floatToIntBits(identityBase) == Float.floatToIntBits(identityResult),
      "HBE analysis-only field modifier is bit-exact identity");

    HBEConfig fieldOnly = defaults.copy();
    fieldOnly.influenceMode = HBEInfluenceMode.FIELD_ONLY;
    fieldOnly.feedbackSource = HBEFeedbackSource.MANUAL;
    fieldOnly.manualFeedback = 0.65f;
    fieldOnly.coupling = 0.75f;
    HBEFrozenMetrics fieldMetrics = new HBEFrozenMetrics(0, 0, 0, 0, 0, 0,
      7.0f, fieldOnly.deterministicSeed, fieldOnly);
    HBEFieldContext fieldContext = new HBEFieldContext(fieldOnly, fieldMetrics, observables);
    float outside = dcrteHbeFieldModifier.modify(identityBase, coordinate, left, fieldContext);
    float insideA = dcrteHbeFieldModifier.modify(identityBase, coordinate, neck, fieldContext);
    float insideB = dcrteHbeFieldModifier.modify(identityBase, coordinate, neck, fieldContext);
    tests.check(Float.floatToIntBits(outside) == Float.floatToIntBits(identityBase)
      && dcrteFinite(insideA) && Float.floatToIntBits(insideA) == Float.floatToIntBits(insideB)
      && Float.floatToIntBits(insideA) != Float.floatToIntBits(identityBase),
      "HBE field relief is finite, deterministic, and confined to the neck");

    HBEConfig lobeProxy = fieldOnly.copy();
    lobeProxy.lobeProxyMode = HBELobeProxyMode.MIRRORED_HIERARCHICAL_BRANCHING;
    lobeProxy.lobeProxyBlend = 0.35f;
    HBEFieldContext lobeContext = new HBEFieldContext(lobeProxy, fieldMetrics, observables);
    float lobeA = dcrteHbeFieldModifier.modify(identityBase, coordinate, left, lobeContext);
    float lobeB = dcrteHbeFieldModifier.modify(identityBase, coordinate, left, lobeContext);
    tests.check(dcrteFinite(lobeA)
      && Float.floatToIntBits(lobeA) == Float.floatToIntBits(lobeB)
      && Float.floatToIntBits(lobeA) != Float.floatToIntBits(identityBase),
      "HBE opt-in mirrored lobe proxy is finite and deterministic");

    HBEConfig schedulerOnly = fieldOnly.copy();
    schedulerOnly.influenceMode = HBEInfluenceMode.SCHEDULER_ONLY;
    HBEFieldContext schedulerContext = new HBEFieldContext(
      schedulerOnly, fieldMetrics, observables);
    float schedulerIdentity = dcrteHbeFieldModifier.modify(
      identityBase, coordinate, neck, schedulerContext);
    tests.check(Float.floatToIntBits(schedulerIdentity) == Float.floatToIntBits(identityBase)
      && !schedulerOnly.influenceMode.fieldEnabled()
      && schedulerOnly.influenceMode.schedulerEnabled()
      && !fieldOnly.influenceMode.schedulerEnabled(),
      "HBE field-only and scheduler-only channels remain isolated");

    HBEFieldSensitivityReport sensitivity = new HBEFieldSensitivityReport();
    sensitivity.observe(left, -0.30f, -0.10f, false, true, fieldContext);
    sensitivity.observe(neck, 0.02f, 0.03f, true, true, fieldContext);
    sensitivity.observe(right, 0.01f, 0.40f, true, false, fieldContext);
    sensitivity.finish();
    tests.check(sensitivity.baseCandidateCount + sensitivity.changedToCandidateCount
      - sensitivity.changedFromCandidateCount == sensitivity.modifiedCandidateCount
      && sensitivity.observedCount == 3,
      "HBE candidate sensitivity counts reconcile exactly");

    int leftSeed = dcrteHbeBestSeed(candidate, observables, 0.04f);
    int rightSeed = dcrteHbeBestSeed(candidate, observables, 0.96f);
    tests.check(leftSeed >= 0 && rightSeed >= 0 && leftSeed != rightSeed
      && candidate.candidateSolid[leftSeed] && candidate.candidateSolid[rightSeed]
      && observables.leftAnchor[leftSeed] && observables.rightAnchor[rightSeed],
      "HBE dual-end seeds are deterministic candidate anchors");

    dcrteHbeEnrichMirrorMetrics(connected, candidate.candidateSolid, mirrorA, null);
    tests.check(abs(connected.bilateralBalance - 1.0f) <= 0.000001f
      && dcrteFinite(connected.mirrorAgreement)
      && connected.mirrorPairCount > 0,
      "HBE symmetric fixture has exact bilateral balance and finite mirror agreement");

    IntrinsicCoordinateVolume graphIntrinsic = dcrteHbeSyntheticIntrinsic(9, 5, 5);
    HBEIntrinsicObservables graphObservables = new HBEIntrinsicObservables(
      graphIntrinsic, defaults);
    CandidateVolumeSnapshot graphCandidate = dcrteHbeSyntheticCandidate(graphIntrinsic, true);
    HBEGraphPairingReport graphA = dcrteHbeAnalyzeGraphPairing(
      graphCandidate.candidateSolid, graphObservables);
    HBEGraphPairingReport graphB = dcrteHbeAnalyzeGraphPairing(
      graphCandidate.candidateSolid, graphObservables);
    tests.check(graphA.isValid() && graphA.graphHash.equals(graphB.graphHash)
      && graphA.selected == graphB.selected,
      "HBE graph-pairing proxy is finite and deterministic");

    HBESweepCell sweepA = dcrteHbeRunFastSweepCell(
      candidate, observables, 2, 1, 0.20f, 0.20f);
    HBESweepCell sweepB = dcrteHbeRunFastSweepCell(
      candidate, observables, 2, 1, 0.20f, 0.20f);
    tests.check(sweepA.failure.length() == 0 && sweepB.failure.length() == 0
      && sweepA.cellHash.equals(sweepB.cellHash)
      && sweepA.candidateHash.equals(sweepB.candidateHash),
      "HBE fixed-envelope sweep cells reproduce exact hashes");
  } catch (Exception error) {
    tests.check(false, "HBE deterministic test exception: "
      + error.getClass().getSimpleName() + " "
      + (error.getMessage() == null ? "" : error.getMessage()));
  }
  return tests;
}

IntrinsicCoordinateVolume dcrteHbeSyntheticIntrinsic(int nx, int ny, int nz) {
  VolumeSpec spec = new VolumeSpec(nx, ny, nz,
    new Bounds3D(-1, -0.4f, -0.4f, 1, 0.4f, 0.4f));
  IntrinsicCoordinateVolume volume = new IntrinsicCoordinateVolume(spec);
  for (int z = 0; z < nz; z++) for (int y = 0; y < ny; y++) for (int x = 0; x < nx; x++) {
    int i = volume.index(x, y, z);
    float yy = ny <= 1 ? 0 : (y / (float)(ny - 1) - 0.5f) * 2;
    float zz = nz <= 1 ? 0 : (z / (float)(nz - 1) - 0.5f) * 2;
    volume.s[i] = nx <= 1 ? 0.5f : x / (float)(nx - 1);
    volume.normalizedRadius[i] = sqrt(yy * yy + zz * zz);
    volume.radialDistance[i] = volume.normalizedRadius[i];
    volume.theta[i] = atan2(zz, yy);
    volume.signedBoundaryDistance[i] = -0.1f;
    volume.confidence[i] = 1;
    volume.valid[i] = true;
    volume.validCount++;
  }
  return volume;
}

CandidateVolumeSnapshot dcrteHbeSyntheticCandidate(
    IntrinsicCoordinateVolume intrinsic, boolean allCandidate) {
  DCRTEVolume volume = new DCRTEVolume(intrinsic.spec);
  for (int i = 0; i < volume.scalar.length; i++) {
    volume.admitted[i] = true;
    volume.candidateSolid[i] = allCandidate;
    volume.scalar[i] = allCandidate ? 0 : 1;
    volume.domainInsideCount++;
    volume.admittedCount++;
    if (allCandidate) volume.candidateSolidCount++;
  }
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(intrinsic.spec);
  return new CandidateVolumeSnapshot(volume, null, observer, null, intrinsic, null);
}

String dcrteHbeMeshHash(TriangleMeshData mesh) {
  if (mesh == null) return "missing";
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    for (int i = 0; i < mesh.vertices.length; i++)
      dcrteDigestInt(digest, Float.floatToIntBits(mesh.vertices[i]));
    for (int i = 0; i < mesh.triangles.length; i++) dcrteDigestInt(digest, mesh.triangles[i]);
    return dcrteHex(digest.digest());
  } catch (Exception error) { return "sha256-error"; }
}
