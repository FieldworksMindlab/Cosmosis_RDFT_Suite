/* DCRTE-ET Milestone 2.5 deterministic preflight fixtures and acceptance matrix. */

class DCRTEM25TestReport extends DCRTEM2TestReport {}

class DCRTEM25FixtureAnalysis {
  TriangleMeshData source;
  TriangleMeshData world;
  MeshDomainReport meshReport;
  MeshTransform transform;
  DomainPreflightReport report;
}

DCRTEM25TestReport dcrteM25Tests = new DCRTEM25TestReport();

String dcrteCommandLineValue(String prefix) {
  if (args == null || prefix == null) return null;
  for (int i = 0; i < args.length; i++) {
    if (args[i] != null && args[i].startsWith(prefix)) return args[i].substring(prefix.length());
  }
  return null;
}

void initializeDcrteMilestone25Tests() {
  dcrteM25Tests = runDcrteMilestone25Tests();
  println("DCRTE-ET Milestone 2.5 deterministic tests: " + dcrteM25Tests.status());
  for (int i = 0; i < dcrteM25Tests.failures.size(); i++) println("  FAIL " + dcrteM25Tests.failures.get(i));
}

DCRTEM25TestReport runDcrteMilestone25Tests() {
  DCRTEM25TestReport tests = new DCRTEM25TestReport();
  try {
    DCRTEM25FixtureAnalysis closed = dcrteAnalyzeM25Fixture(createDcrteCubeFixture(), 32);
    tests.check(closed != null && closed.report.sdfBuildEnabled
      && closed.report.qualification == DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED,
      "closed cube reaches topology-valid SDF-unresolved qualification");
    tests.check(closed != null && closed.report.singleDominantClosedComponent
      && closed.report.dominantComponentFraction >= 0.98f,
      "closed cube exposes Milestone 3 dominant-component handoff");

    DCRTEM25FixtureAnalysis smallHole = dcrteAnalyzeM25Fixture(createDcrteSmallHoleFixture(), 32);
    tests.check(smallHole != null && smallHole.report.hasDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_LOOP_SMALL)
      && !smallHole.report.sdfBuildEnabled, "small hole is localized and blocks strict SDF");

    DCRTEM25FixtureAnalysis largeOpening = dcrteAnalyzeM25Fixture(createDcrteLargeOpeningFixture(), 32);
    tests.check(largeOpening != null && largeOpening.report.hasDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_LOOP_LARGE)
      && largeOpening.report.boundaryLoops.size() > 0, "large opening is distinguished from small hole");

    DCRTEM25FixtureAnalysis bowtie = dcrteAnalyzeM25Fixture(createDcrteBowtieVertexFixture(), 32);
    tests.check(bowtie != null && bowtie.report.hasDiagnostic(DCRTEPreflightCodes.PF_BOWTIE_VERTICES),
      "bowtie vertex neighborhood detected");

    DCRTEM25FixtureAnalysis intersections = dcrteAnalyzeM25Fixture(createDcrteIntersectingShellFixture(), 32);
    tests.check(intersections != null
      && (intersections.report.hasDiagnostic(DCRTEPreflightCodes.PF_COMPONENT_INTERSECTION)
        || intersections.report.hasDiagnostic(DCRTEPreflightCodes.PF_SELF_INTERSECTION)),
      "intersecting shells detected by spatial broad phase and exact tests");

    DCRTEM25FixtureAnalysis nested = dcrteAnalyzeM25Fixture(createDcrteNestedShellFixture(), 32);
    tests.check(nested != null && nested.report.hasDiagnostic(DCRTEPreflightCodes.PF_NESTED_SHELLS)
      && nested.report.nestedShellCount > 0, "nested shell ambiguity detected");

    DCRTEM25FixtureAnalysis thin = dcrteAnalyzeM25Fixture(createDcrteThinWallFixture(), 32);
    tests.check(thin != null && thin.report.thinFeatureRisk
      && (thin.report.hasDiagnostic(DCRTEPreflightCodes.PF_FEATURE_BELOW_ONE_VOXEL)
        || thin.report.hasDiagnostic(DCRTEPreflightCodes.PF_FEATURE_BELOW_TWO_VOXELS)),
      "thin feature risk is reported without repair");

    DCRTEM25FixtureAnalysis tiny = dcrteAnalyzeM25Fixture(createDcrteTinyDisconnectedShellFixture(), 32);
    tests.check(tiny != null && tiny.report.hasDiagnostic(DCRTEPreflightCodes.PF_TINY_DISCONNECTED_COMPONENTS)
      && tiny.report.hasDiagnostic(DCRTEPreflightCodes.PF_DISCONNECTED_COMPONENTS),
      "tiny disconnected shell is retained and reported");

    MeshValidationResult safeSanitation = new DCRTEMeshSanitizer().sanitize(createDcrteDegenerateCubeFixture());
    tests.check(safeSanitation.report.zeroAreaTrianglesRemoved == 2
      && safeSanitation.report.nearZeroAreaTrianglesRemoved == 0
      && safeSanitation.report.strictValid(), "safe sanitation remains transparent and topology preserving");

    DCRTEM2FixtureSdf cubeSdf = dcrteBuildFixtureSdf(createDcrteCubeFixture(), 32);
    DomainPreflightReport volumeReport = dcrteAnalyzeM25Fixture(createDcrteCubeFixture(), 32).report;
    if (cubeSdf != null) {
      new DCRTEPreflightVolumeAnalyzer().attach(volumeReport, cubeSdf.world, cubeSdf.boundary,
        cubeSdf.classification, cubeSdf.sdf, null, null, false, false);
    }
    tests.check(cubeSdf != null && volumeReport.insideOutsideVerification != null
      && volumeReport.sdfReport != null && volumeReport.materializationEnabled,
      "canonical cube passes boundary, parity, flood-fill, and SDF qualification");
    tests.check(volumeReport.qualification == DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED
      && !volumeReport.exportEnabled, "qualified SDF remains export blocked until materialization");

    DomainPreflightReport parseFailure = createDcrteParseFailurePreflight(null,
      "IMPORT_PARSE_FAILURE", "deterministic missing-file fixture");
    tests.check(parseFailure.qualification == DomainQualification.PARSE_FAILED
      && parseFailure.firstBlockingCode.equals(DCRTEPreflightCodes.PF_FILE_NOT_FOUND),
      "failed load produces a separate staged parse report");
  }
  catch (Exception error) {
    tests.check(false, "M2.5 deterministic test exception: " + error.getClass().getSimpleName() + " " + error.getMessage());
  }
  return tests;
}

DCRTEM25FixtureAnalysis dcrteAnalyzeM25Fixture(TriangleMeshData fixture, int resolution) {
  MeshValidationResult validation = new DCRTEMeshSanitizer().sanitize(fixture);
  if (validation == null || validation.mesh == null) return null;
  MeshTransform transform = createDcrteFitTransform(validation.mesh, dcrteObserverBounds, 0, 0, 0, 0.08f, 1);
  TriangleMeshData world = validation.mesh.copyTransformed(transform);
  dcrteUpdateWorldReport(validation.report, world, transform);
  DCRTEM25FixtureAnalysis result = new DCRTEM25FixtureAnalysis();
  result.source = validation.mesh;
  result.world = world;
  result.meshReport = validation.report;
  result.transform = transform;
  result.report = new DCRTEPreflightMeshAnalyzer().analyze(validation.mesh, world,
    validation.report, transform, resolution, dcrteObserverBounds);
  return result;
}

TriangleMeshData createDcrteSmallHoleFixture() {
  TriangleMeshData sphere = createDcrteUvSphereFixture(1, 8, 12);
  return dcrteRemoveFixtureTriangles(sphere, new int[] {17}, "small_triangular_hole_fixture.stl");
}

TriangleMeshData createDcrteLargeOpeningFixture() {
  TriangleMeshData cube = createDcrteCubeFixture();
  return dcrteRemoveFixtureTriangles(cube, new int[] {10, 11}, "large_opening_fixture.stl");
}

TriangleMeshData createDcrteBowtieVertexFixture() {
  TriangleMeshData a = dcrteTransformFixture(createDcrteCubeFixture(), 0.5f, 0.5f, 0.5f, 0, 0, 0, "bowtie_a");
  TriangleMeshData b = dcrteTransformFixture(createDcrteCubeFixture(), 0.2f, 0.2f, 0.2f, 0.7f, 0.7f, 0.7f, "bowtie_b");
  return dcrteCombineFixtures(a, b, "bowtie_vertex_fixture.stl");
}

TriangleMeshData createDcrteIntersectingShellFixture() {
  TriangleMeshData a = dcrteTransformFixture(createDcrteCubeFixture(), 0.72f, 0.72f, 0.72f, -0.28f, 0, 0, "intersection_a");
  TriangleMeshData b = dcrteTransformFixture(createDcrteCubeFixture(), 0.72f, 0.72f, 0.72f, 0.28f, 0.18f, 0.12f, "intersection_b");
  return dcrteCombineFixtures(a, b, "intersecting_shells_fixture.stl");
}

TriangleMeshData createDcrteNestedShellFixture() {
  TriangleMeshData outer = createDcrteCubeFixture();
  TriangleMeshData inner = dcrteTransformFixture(createDcrteCubeFixture(), 0.32f, 0.32f, 0.32f, 0, 0, 0, "nested_inner");
  return dcrteCombineFixtures(outer, inner, "nested_shells_fixture.stl");
}

TriangleMeshData createDcrteThinWallFixture() {
  return dcrteTransformFixture(createDcrteCubeFixture(), 1.0f, 0.018f, 1.0f, 0, 0, 0, "thin_wall_fixture.stl");
}

TriangleMeshData createDcrteTinyDisconnectedShellFixture() {
  TriangleMeshData main = dcrteTransformFixture(createDcrteCubeFixture(), 0.72f, 0.72f, 0.72f, -0.18f, 0, 0, "main_shell");
  TriangleMeshData tiny = dcrteTransformFixture(createDcrteCubeFixture(), 0.045f, 0.045f, 0.045f, 0.76f, 0, 0, "tiny_shell");
  return dcrteCombineFixtures(main, tiny, "tiny_disconnected_shell_fixture.stl");
}

TriangleMeshData dcrteRemoveFixtureTriangles(TriangleMeshData source, int[] removed, String name) {
  boolean[] skip = new boolean[source.triangleCount];
  for (int i = 0; i < removed.length; i++) if (removed[i] >= 0 && removed[i] < skip.length) skip[removed[i]] = true;
  IntArrayBuilder triangles = new IntArrayBuilder(source.triangles.length);
  for (int t = 0; t < source.triangleCount; t++) {
    if (!skip[t]) triangles.add3(source.ia(t), source.ib(t), source.ic(t));
  }
  TriangleMeshData result = new TriangleMeshData(java.util.Arrays.copyOf(source.vertices, source.vertices.length), triangles.toArray());
  result.sourceName = name;
  result.sourceFormat = "generated_fixture";
  result.declaredTriangleCount = result.triangleCount;
  return result;
}

TriangleMeshData dcrteTransformFixture(TriangleMeshData source, float sx, float sy, float sz,
    float tx, float ty, float tz, String name) {
  float[] vertices = java.util.Arrays.copyOf(source.vertices, source.vertices.length);
  for (int i = 0; i < vertices.length; i += 3) {
    vertices[i] = vertices[i] * sx + tx;
    vertices[i + 1] = vertices[i + 1] * sy + ty;
    vertices[i + 2] = vertices[i + 2] * sz + tz;
  }
  TriangleMeshData result = new TriangleMeshData(vertices, java.util.Arrays.copyOf(source.triangles, source.triangles.length));
  result.sourceName = name;
  result.sourceFormat = "generated_fixture";
  result.declaredTriangleCount = result.triangleCount;
  return result;
}

TriangleMeshData dcrteCombineFixtures(TriangleMeshData a, TriangleMeshData b, String name) {
  float[] vertices = java.util.Arrays.copyOf(a.vertices, a.vertices.length + b.vertices.length);
  System.arraycopy(b.vertices, 0, vertices, a.vertices.length, b.vertices.length);
  int[] triangles = java.util.Arrays.copyOf(a.triangles, a.triangles.length + b.triangles.length);
  int vertexOffset = a.vertexCount;
  for (int i = 0; i < b.triangles.length; i++) triangles[a.triangles.length + i] = b.triangles[i] + vertexOffset;
  TriangleMeshData result = new TriangleMeshData(vertices, triangles);
  result.sourceName = name;
  result.sourceFormat = "generated_fixture";
  result.declaredTriangleCount = result.triangleCount;
  return result;
}

void runDcrteMilestone25AcceptanceMatrix() {
  println("DCRTE-ET Milestone 2.5 acceptance matrix starting...");
  JSONObject output = new JSONObject();
  JSONArray runs = new JSONArray();
  String[] ids = {"M25-CLOSED", "M25-SMALL-HOLE", "M25-LARGE-OPENING", "M25-BOWTIE",
    "M25-INTERSECT", "M25-NESTED", "M25-THIN", "M25-TINY-SHELL"};
  TriangleMeshData[] fixtures = {createDcrteCubeFixture(), createDcrteSmallHoleFixture(),
    createDcrteLargeOpeningFixture(), createDcrteBowtieVertexFixture(), createDcrteIntersectingShellFixture(),
    createDcrteNestedShellFixture(), createDcrteThinWallFixture(), createDcrteTinyDisconnectedShellFixture()};
  for (int i = 0; i < ids.length; i++) {
    DCRTEM25FixtureAnalysis analysis = dcrteAnalyzeM25Fixture(fixtures[i], 32);
    if (i == 0 && analysis != null) {
      DCRTEM2FixtureSdf sdfFixture = dcrteBuildFixtureSdf(createDcrteCubeFixture(), 32);
      if (sdfFixture != null) new DCRTEPreflightVolumeAnalyzer().attach(analysis.report,
        sdfFixture.world, sdfFixture.boundary, sdfFixture.classification, sdfFixture.sdf,
        null, null, false, false);
    }
    JSONObject run = analysis == null ? new JSONObject() : analysis.report.toJSON();
    run.setString("case_id", ids[i]);
    runs.setJSONObject(i, run);
  }
  output.setString("milestone", "DCRTE-ET M2.5");
  output.setString("generated_at", nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2)
    + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2));
  output.setJSONObject("deterministic_tests", dcrteM25Tests.toJSON());
  output.setJSONArray("runs", runs);
  output.setBoolean("milestone_3_implementation_present", false);
  output.setString("repair_policy", "diagnose_and_gate_only; no topology-changing repair");
  saveJSONObject(output, "logs/dcrte_m25_acceptance_latest.json");
  println("DCRTE-ET Milestone 2.5 acceptance matrix: " + dcrteM25Tests.status());
}

void runDcrteMilestone25ExternalReferenceCase(String sourcePath) {
  final String caseId = "DCRTE-M2-INVALID-EXT-001";
  File source = sourcePath == null ? null : new File(sourcePath);
  boolean parsed = loadDcrteImportedFile(source, false, null);
  DomainPreflightReport report = parsed ? dcrteImportedPreflightReport : dcrteImportedAttemptPreflightReport;
  if (report == null) report = createDcrteParseFailurePreflight(source,
    "IMPORT_PARSE_FAILURE", "reference case produced no report");
  report.referenceCaseId = caseId;
  report.selectedResolution = dcrteImportedResolution;
  report.refreshSummary();

  JSONObject output = new JSONObject();
  output.setString("reference_case_id", caseId);
  output.setString("generated_at", nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2)
    + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2));
  output.setString("source_filename", source == null ? "" : source.getName());
  output.setString("source_sha256", report.sourceHashSha256 == null ? "" : report.sourceHashSha256);
  output.setBoolean("parser_succeeded", parsed);
  output.setString("parser_result", parsed ? "pass" : "blocked");
  output.setString("sanitation_result", report.meshReport == null ? "not_run" : report.meshReport.status.id());
  output.setInt("selected_resolution", report.selectedResolution);
  output.setString("failed_stage", report.firstBlockingStage == null ? "" : report.firstBlockingStage.toLowerCase());
  output.setString("first_blocker", report.firstBlockingCode == null ? "" : report.firstBlockingCode);
  output.setInt("blocker_count", report.blockers.size());
  output.setString("recommended_action", report.recommendedNextAction == null ? "" : report.recommendedNextAction);
  output.setBoolean("materially_more_useful_than_generic_failure",
    report.firstBlockingCode != null && report.firstBlockingCode.length() > 0
      && report.recommendedNextAction != null && report.recommendedNextAction.length() > 0
      && report.diagnostics.size() > 0);
  output.setJSONObject("preflight_report", report.toJSON());
  saveJSONObject(output, "logs/dcrte_reference_cases/DCRTE-M2-INVALID-EXT-001.json");
  println("DCRTE-ET Milestone 2.5 external reference case:");
  println(report.conciseSummary());
}
