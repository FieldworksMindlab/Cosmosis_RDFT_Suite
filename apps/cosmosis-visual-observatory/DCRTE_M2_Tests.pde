/* DCRTE-ET Milestone 2 deterministic mesh, importer, SDF, and regression tests. */

class DCRTEM2TestReport extends DCRTEM1TestReport {}

class DCRTEM2FixtureSdf {
  TriangleMeshData source;
  TriangleMeshData world;
  MeshDomainReport meshReport;
  MeshTransform transform;
  VoxelBoundaryVolume boundary;
  InsideOutsideVolume classification;
  SignedDistanceVolume sdf;
  ImportedMeshDomain domain;
}

DCRTEM2TestReport dcrteM2Tests = new DCRTEM2TestReport();

void initializeDcrteMilestone2() {
  dcrteM2Tests = runDcrteMilestone2Tests();
  println("DCRTE-ET Milestone 2 deterministic tests: " + dcrteM2Tests.status());
  for (int i = 0; i < dcrteM2Tests.failures.size(); i++) println("  FAIL " + dcrteM2Tests.failures.get(i));
}

DCRTEM2TestReport runDcrteMilestone2Tests() {
  DCRTEM2TestReport tests = new DCRTEM2TestReport();
  File directory = new File(sketchPath("exports/dcrte_m2_tests"));
  if (!directory.exists()) directory.mkdirs();
  try {
    TriangleMeshData cube = createDcrteCubeFixture();
    File binaryCube = new File(directory, "cube_binary.stl");
    File asciiCube = new File(directory, "cube_ascii.stl");
    File solidHeaderBinary = new File(directory, "cube_binary_solid_header.stl");
    writeDcrteBinaryStl(cube, binaryCube, "DCRTE cube binary fixture");
    writeDcrteAsciiStl(cube, asciiCube, "dcrte_cube_ascii");
    writeDcrteBinaryStl(cube, solidHeaderBinary, "solid this remains binary");
    STLMeshImporter importer = new STLMeshImporter();
    TriangleMeshData parsedBinary = importer.load(binaryCube);
    TriangleMeshData parsedAscii = importer.load(asciiCube);
    TriangleMeshData parsedSolidHeader = importer.load(solidHeaderBinary);
    tests.check(parsedBinary.triangleCount == 12 && parsedBinary.sourceFormat.equals("binary_stl"), "binary cube STL triangle count");
    tests.check(parsedAscii.triangleCount == 12 && parsedAscii.sourceFormat.equals("ascii_stl"), "ASCII cube STL triangle count");
    tests.check(parsedSolidHeader.sourceFormat.equals("binary_stl"), "binary STL solid header detection");
    tests.check(parsedBinary.sourceHashSha256.equals(importer.load(binaryCube).sourceHashSha256), "stable source SHA-256");

    File malformedAscii = new File(directory, "cube_malformed_ascii.stl");
    java.nio.file.Files.write(malformedAscii.toPath(), ("solid broken\nfacet normal 0 0 1\nouter loop\n"
      + "vertex 0 0 0\nvertex 1 0 0\nendloop\nendfacet\nendsolid broken\n").getBytes(java.nio.charset.StandardCharsets.UTF_8));
    boolean malformedAsciiRejected = false;
    try { importer.load(malformedAscii); } catch (MeshImportException error) { malformedAsciiRejected = true; }
    tests.check(malformedAsciiRejected, "malformed ASCII facet rejected");
    boolean triangleLimitRejected = false;
    try { importer.parseBinary(new byte[84], DCRTE_STL_HARD_MAX_TRIANGLES + 1); }
    catch (MeshImportException error) { triangleLimitRejected = "IMPORT_TRIANGLE_LIMIT".equals(error.code); }
    tests.check(triangleLimitRejected, "binary triangle hard limit enforced before allocation");

    byte[] validBytes = java.nio.file.Files.readAllBytes(binaryCube.toPath());
    File malformed = new File(directory, "cube_malformed.stl");
    java.nio.file.Files.write(malformed.toPath(), java.util.Arrays.copyOf(validBytes, validBytes.length - 1));
    boolean malformedRejected = false;
    try { importer.load(malformed); } catch (MeshImportException error) { malformedRejected = true; }
    tests.check(malformedRejected, "malformed binary length rejected");

    TriangleMeshData nonFinite = new TriangleMeshData(new float[] {0,0,0, 1,0,0, Float.NaN,1,0}, new int[] {0,1,2});
    File nonFiniteFile = new File(directory, "nonfinite.stl");
    writeDcrteBinaryStl(nonFinite, nonFiniteFile, "DCRTE nonfinite rejection fixture");
    boolean nonFiniteRejected = false;
    try { importer.load(nonFiniteFile); } catch (MeshImportException error) { nonFiniteRejected = "IMPORT_NONFINITE_VERTEX".equals(error.code); }
    tests.check(nonFiniteRejected, "non-finite vertex rejected");

    MeshValidationResult cubeValidation = new DCRTEMeshSanitizer().sanitize(parsedBinary);
    tests.check(cubeValidation.report.strictValid() && cubeValidation.report.boundaryEdgeCount == 0, "closed cube watertight");
    tests.check(cubeValidation.report.duplicateVerticesMerged > 0 && cubeValidation.mesh.vertexCount == 8, "duplicate STL vertices merged");
    MeshValidationResult openValidation = new DCRTEMeshSanitizer().sanitize(createDcrteOpenCubeFixture());
    tests.check(!openValidation.report.strictValid() && openValidation.report.boundaryEdgeCount > 0, "open cube strict rejection");
    MeshValidationResult nonManifoldValidation = new DCRTEMeshSanitizer().sanitize(createDcrteNonManifoldFixture());
    tests.check(!nonManifoldValidation.report.strictValid() && nonManifoldValidation.report.nonManifoldEdgeCount > 0, "non-manifold edge rejection");
    MeshValidationResult invertedValidation = new DCRTEMeshSanitizer().sanitize(createDcrteInvertedFixture(createDcrteUvSphereFixture(1, 12, 18)));
    tests.check(invertedValidation.report.strictValid() && invertedValidation.report.globalWindingFlipped
      && invertedValidation.report.signedVolumeSource > 0, "inverted sphere global winding correction");
    MeshValidationResult degenerateValidation = new DCRTEMeshSanitizer().sanitize(createDcrteDegenerateCubeFixture());
    tests.check(degenerateValidation.report.zeroAreaTrianglesRemoved == 2 && degenerateValidation.report.strictValid(), "degenerate triangles removed transparently");

    MeshTransform transform = createDcrteFitTransform(cubeValidation.mesh, dcrteObserverBounds, 0, 0, 0, 0.08f, 1);
    TriangleMeshData world = cubeValidation.mesh.copyTransformed(transform);
    float[] sourceCopy = java.util.Arrays.copyOf(cubeValidation.mesh.vertices, cubeValidation.mesh.vertices.length);
    float[] worldPoint = new float[3];
    float[] sourcePoint = new float[3];
    transform.apply(0.25f, -0.4f, 0.7f, worldPoint);
    transform.applyInverse(worldPoint[0], worldPoint[1], worldPoint[2], sourcePoint);
    tests.check(abs(world.worldBounds.centerX()) < 0.00001f && abs(world.worldBounds.centerY()) < 0.00001f
      && abs(world.worldBounds.centerZ()) < 0.00001f, "normalized transform centered");
    tests.check(world.worldBounds.maxX <= 0.92001f && world.worldBounds.minX >= -0.92001f, "normalized transform respects fit margin");
    float sourceAspect = cubeValidation.mesh.sourceBounds.sizeX() / cubeValidation.mesh.sourceBounds.sizeY();
    float worldAspect = world.worldBounds.sizeX() / world.worldBounds.sizeY();
    tests.check(abs(sourceAspect - worldAspect) < 0.00001f, "uniform fit preserves aspect ratio");
    tests.check(dcrteDistanceSq(0.25f, -0.4f, 0.7f, sourcePoint[0], sourcePoint[1], sourcePoint[2]) < 0.00000001f, "transform inverse round trip");
    tests.check(java.util.Arrays.equals(sourceCopy, cubeValidation.mesh.vertices), "source vertices remain immutable");
    MeshTransform fourTurns = createDcrteFitTransform(cubeValidation.mesh, dcrteObserverBounds, 4, 4, 4, 0.08f, 1);
    tests.check(fourTurns.rotateXQuarterTurns == 0 && fourTurns.rotateYQuarterTurns == 0 && fourTurns.rotateZQuarterTurns == 0, "four quarter-turn identity");

    tests.check(abs(dcrtePointTriangleDistanceSq(0.25f, 0.25f, 1, 0,0,0, 1,0,0, 0,1,0) - 1) < 0.00001f, "point-triangle face distance");
    tests.check(abs(dcrtePointTriangleDistanceSq(0.5f, -1, 0, 0,0,0, 1,0,0, 0,1,0) - 1) < 0.00001f, "point-triangle edge distance");
    tests.check(abs(dcrtePointTriangleDistanceSq(-1, 0, 0, 0,0,0, 1,0,0, 0,1,0) - 1) < 0.00001f, "point-triangle vertex distance");

    DCRTEM2FixtureSdf cubeSdf = dcrteBuildFixtureSdf(createDcrteCubeFixture(), 32);
    tests.check(cubeSdf != null && cubeSdf.boundary.boundaryCount > 0 && cubeSdf.classification.failedScanlineCount == 0, "cube boundary and parity classification");
    tests.check(cubeSdf != null && cubeSdf.sdf.sampleWorld(0,0,0) < 0 && cubeSdf.sdf.sampleWorld(0.99f,0.99f,0.99f) > 0, "cube SDF sign");
    tests.check(cubeSdf != null && cubeSdf.sdf.nonFiniteCount == 0, "cube SDF finite");
    DCRTEM2FixtureSdf cubeSdf64 = dcrteBuildFixtureSdf(createDcrteCubeFixture(), 64);
    tests.check(cubeSdf64 != null && cubeSdf64.boundary.boundaryCount >= cubeSdf.boundary.boundaryCount,
      "higher resolution preserves or increases cube boundary detail");
    InsideOutsideVolume repeatedClassification = cubeSdf == null ? null
      : new DeterministicInsideOutsideClassifier().classify(cubeSdf.world, cubeSdf.boundary);
    tests.check(cubeSdf != null && repeatedClassification != null
      && repeatedClassification.failedScanlineCount == cubeSdf.classification.failedScanlineCount
      && java.util.Arrays.equals(repeatedClassification.inside, cubeSdf.classification.inside),
      "inside-outside classification is deterministic");
    DCRTEM2FixtureSdf sphereSdf = dcrteBuildFixtureSdf(createDcrteUvSphereFixture(1, 12, 18), 32);
    float[] sphereNormal = new float[3];
    if (sphereSdf != null) sphereSdf.sdf.normalWorld(0.7f, 0, 0, sphereNormal);
    tests.check(sphereSdf != null && sphereSdf.sdf.sampleWorld(0,0,0) < 0 && sphereSdf.sdf.sampleWorld(0.99f,0.99f,0.99f) > 0, "sphere SDF sign");
    tests.check(sphereSdf != null && sphereNormal[0] > 0.5f, "sphere SDF normal outward");
    if (cubeSdf != null) {
      int hardCount = dcrteCountImportedAdmitted(cubeSdf.domain, new HardInteriorObservation(dcrteBoundaryEpsilon(cubeSdf.sdf.spec)));
      int shellCount = dcrteCountImportedAdmitted(cubeSdf.domain,
        new ShellBandObservation(dcrteBoundaryEpsilon(cubeSdf.sdf.spec), cubeSdf.sdf.spec.minSpacing() * 3, 3));
      tests.check(shellCount > 0 && shellCount < hardCount, "imported shell band smaller than hard interior");

      DCRTEPipelineMode savedPipeline = dcrtePipelineMode;
      DCRTEObservationMode savedObservation = dcrteObservationMode;
      float savedShell = dcrteShellThicknessVoxels;
      ImportedMeshDomain savedDomain = dcrteImportedDomain;
      boolean savedSdfDirty = dcrteImportedSdfDirty;
      boolean savedStale = dcrteImportedStale;
      int savedSlice = dcrteImportedSliceIndex;
      DCRTEImportedBuildState savedBuildState = dcrteImportedBuildState;
      String savedFoundryStatus = foundryStatus;
      boolean savedFoundryMeshStale = foundryMeshStale;
      dcrtePipelineMode = DCRTEPipelineMode.DCRTE_IMPORTED_MESH;
      dcrteImportedDomain = cubeSdf.domain;
      dcrteImportedSdfDirty = false;
      dcrteImportedStale = false;
      cycleDcrteObservationMode();
      tests.check(!dcrteImportedSdfDirty && dcrteImportedStale, "observation change preserves imported SDF and marks material stale");
      dcrteImportedStale = false;
      adjustDcrteShellThickness(1);
      tests.check(!dcrteImportedSdfDirty && dcrteImportedStale, "shell thickness change requires rematerialization only");
      dcrteImportedSdfDirty = false;
      adjustDcrteImportedSlice(1);
      tests.check(!dcrteImportedSdfDirty, "slice change does not invalidate imported SDF");
      dcrtePipelineMode = savedPipeline;
      dcrteObservationMode = savedObservation;
      dcrteShellThicknessVoxels = savedShell;
      dcrteImportedDomain = savedDomain;
      dcrteImportedSdfDirty = savedSdfDirty;
      dcrteImportedStale = savedStale;
      dcrteImportedSliceIndex = savedSlice;
      dcrteImportedBuildState = savedBuildState;
      foundryStatus = savedFoundryStatus;
      foundryMeshStale = savedFoundryMeshStale;
    }
  }
  catch (Exception error) {
    tests.check(false, "M2 deterministic test exception: " + error.getClass().getSimpleName() + " " + error.getMessage());
  }
  return tests;
}

DCRTEM2FixtureSdf dcrteBuildFixtureSdf(TriangleMeshData fixture, int resolution) {
  MeshValidationResult validation = new DCRTEMeshSanitizer().sanitize(fixture);
  if (validation.mesh == null || !validation.report.strictValid()) return null;
  MeshTransform transform = createDcrteFitTransform(validation.mesh, dcrteObserverBounds, 0, 0, 0, 0.08f, 1);
  TriangleMeshData world = validation.mesh.copyTransformed(transform);
  dcrteUpdateWorldReport(validation.report, world, transform);
  VolumeSpec spec = new VolumeSpec(resolution, resolution, resolution, dcrteObserverBounds);
  VoxelBoundaryVolume boundary = new ConservativeBoundaryVoxelizer().build(world, spec);
  InsideOutsideVolume classification = new DeterministicInsideOutsideClassifier().classify(world, boundary);
  SignedDistanceVolume sdf = new DCRTESignedDistanceBuilder().build(boundary, classification, validation.report.absoluteVolumeWorld, true);
  DCRTEM2FixtureSdf result = new DCRTEM2FixtureSdf();
  result.source = validation.mesh; result.world = world; result.meshReport = validation.report; result.transform = transform;
  result.boundary = boundary; result.classification = classification; result.sdf = sdf;
  result.domain = new ImportedMeshDomain(validation.mesh, world, validation.report, transform, sdf, InvalidDomainPolicy.STRICT);
  return result;
}

int dcrteCountImportedAdmitted(ImportedMeshDomain domain, ObservationLayer layer) {
  if (domain == null || domain.sdf == null) return 0;
  int count = 0;
  DomainSample ds = new DomainSample();
  ObservationSample os = new ObservationSample();
  VolumeSpec spec = domain.sdf.spec;
  for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
    domain.sampleAtIndex(x, y, z, ds);
    layer.observe(ds, os);
    if (os.admitted) count++;
  }
  return count;
}

TriangleMeshData createDcrteCubeFixture() {
  float[] vertices = {
    -1,-1,-1, 1,-1,-1, 1,1,-1, -1,1,-1,
    -1,-1, 1, 1,-1, 1, 1,1, 1, -1,1, 1
  };
  int[] triangles = {
    0,2,1, 0,3,2,
    4,5,6, 4,6,7,
    0,1,5, 0,5,4,
    3,7,6, 3,6,2,
    0,4,7, 0,7,3,
    1,2,6, 1,6,5
  };
  TriangleMeshData mesh = new TriangleMeshData(vertices, triangles);
  mesh.sourceName = "closed_cube_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount;
  return mesh;
}

TriangleMeshData createDcrteOpenCubeFixture() {
  TriangleMeshData cube = createDcrteCubeFixture();
  TriangleMeshData openMesh = new TriangleMeshData(java.util.Arrays.copyOf(cube.vertices, cube.vertices.length),
    java.util.Arrays.copyOf(cube.triangles, cube.triangles.length - 6));
  openMesh.sourceName = "open_cube_fixture.stl";
  openMesh.sourceFormat = "generated_fixture";
  openMesh.declaredTriangleCount = openMesh.triangleCount;
  return openMesh;
}

TriangleMeshData createDcrteNonManifoldFixture() {
  float[] vertices = {0,0,0, 1,0,0, 0,1,0, 0,-1,0, 0,0,1};
  int[] triangles = {0,1,2, 1,0,3, 0,1,4};
  TriangleMeshData mesh = new TriangleMeshData(vertices, triangles);
  mesh.sourceName = "nonmanifold_edge_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount;
  return mesh;
}

TriangleMeshData createDcrteUvSphereFixture(float radius, int latitudeSegments, int longitudeSegments) {
  TriangleMeshData mesh = createDcrteEggMesh(radius, radius, 0, latitudeSegments, longitudeSegments);
  mesh.sourceName = "closed_sphere_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  return mesh;
}

TriangleMeshData createDcrteInvertedFixture(TriangleMeshData source) {
  int[] triangles = java.util.Arrays.copyOf(source.triangles, source.triangles.length);
  for (int t = 0; t < triangles.length / 3; t++) {
    int offset = t * 3;
    int swap = triangles[offset + 1]; triangles[offset + 1] = triangles[offset + 2]; triangles[offset + 2] = swap;
  }
  TriangleMeshData inverted = new TriangleMeshData(java.util.Arrays.copyOf(source.vertices, source.vertices.length), triangles);
  inverted.sourceName = "inverted_sphere_fixture.stl";
  inverted.sourceFormat = "generated_fixture";
  inverted.declaredTriangleCount = inverted.triangleCount;
  return inverted;
}

TriangleMeshData createDcrteDegenerateCubeFixture() {
  TriangleMeshData cube = createDcrteCubeFixture();
  float[] vertices = java.util.Arrays.copyOf(cube.vertices, cube.vertices.length + 9);
  int base = cube.vertexCount;
  vertices[cube.vertices.length] = 0; vertices[cube.vertices.length + 1] = 0; vertices[cube.vertices.length + 2] = 0;
  vertices[cube.vertices.length + 3] = 0; vertices[cube.vertices.length + 4] = 0; vertices[cube.vertices.length + 5] = 0;
  vertices[cube.vertices.length + 6] = 1; vertices[cube.vertices.length + 7] = 0; vertices[cube.vertices.length + 8] = 0;
  int[] triangles = java.util.Arrays.copyOf(cube.triangles, cube.triangles.length + 6);
  triangles[cube.triangles.length] = base; triangles[cube.triangles.length + 1] = base; triangles[cube.triangles.length + 2] = base + 1;
  triangles[cube.triangles.length + 3] = base; triangles[cube.triangles.length + 4] = base + 1; triangles[cube.triangles.length + 5] = base + 2;
  TriangleMeshData mesh = new TriangleMeshData(vertices, triangles);
  mesh.sourceName = "degenerate_cube_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount;
  return mesh;
}

void runDcrteMilestone2AcceptanceMatrix() {
  println("DCRTE-ET Milestone 2 acceptance matrix starting...");
  File directory = new File(sketchPath("exports/dcrte_m2_acceptance"));
  if (!directory.exists()) directory.mkdirs();
  JSONArray runs = new JSONArray();
  int passed = 0;
  try {
    TriangleMeshData sphere = createDcrteUvSphereFixture(1, 24, 36);
    TriangleMeshData egg = createDcrteEggFixtureMesh();
    TriangleMeshData[] fixtures = {
      createDcrteCubeFixture(), sphere, egg, egg,
      egg, createDcrteOpenCubeFixture(), createDcrteNonManifoldFixture(), createDcrteInvertedFixture(sphere)
    };
    String[] ids = {"M2-A", "M2-B", "M2-C", "M2-D", "M2-E", "M2-F", "M2-G", "M2-H"};
    int[] resolutions = {64, 64, 64, 64, 128, 64, 64, 64};
    DCRTEObservationMode[] observations = {
      DCRTEObservationMode.HARD_INTERIOR, DCRTEObservationMode.HARD_INTERIOR,
      DCRTEObservationMode.HARD_INTERIOR, DCRTEObservationMode.SHELL_BAND,
      DCRTEObservationMode.HARD_INTERIOR, DCRTEObservationMode.HARD_INTERIOR,
      DCRTEObservationMode.HARD_INTERIOR, DCRTEObservationMode.HARD_INTERIOR
    };
    boolean[] expectedValid = {true, true, true, true, true, false, false, true};
    dcrtePipelineMode = DCRTEPipelineMode.DCRTE_IMPORTED_MESH;
    dcrteImportedPolicy = InvalidDomainPolicy.STRICT;
    for (int i = 0; i < ids.length; i++) {
      File fixtureFile = new File(directory, ids[i] + "_source.stl");
      writeDcrteBinaryStl(fixtures[i], fixtureFile, "DCRTE-ET " + ids[i] + " fixture");
      boolean loaded = loadDcrteImportedFile(fixtureFile, ids[i].startsWith("M2-C") || ids[i].startsWith("M2-D") || ids[i].startsWith("M2-E"),
        ids[i].startsWith("M2-C") || ids[i].startsWith("M2-D") || ids[i].startsWith("M2-E") ? dcrteEggFixtureMetadata() : null);
      dcrteImportedResolution = resolutions[i];
      dcrteImportedSliceIndex = resolutions[i] / 2;
      dcrteObservationMode = observations[i];
      markDcrteImportedStale("acceptance fixture configured");
      long start = millis();
      if (expectedValid[i]) generateDcrteImportedSurfaceMesh();
      boolean meshStrict = dcrteImportedMeshReport != null && dcrteImportedMeshReport.strictValid();
      boolean exportEnabled = dcrteImportedExportAllowed();
      boolean printable = foundryMeshIsPrintable() && !foundryMeshStale;
      boolean outsideZero = dcrteLastValidationReport != null && dcrteLastValidationReport.outsideSolidSamples == 0;
      boolean validPassed = loaded && meshStrict && dcrteImportedDomain != null && dcrteImportedDomain.isValid()
        && dcrteImportedInsideOutside != null && dcrteImportedInsideOutside.failedScanlineCount == 0
        && dcrteImportedSdf != null && dcrteImportedSdf.nonFiniteCount == 0
        && dcrteImportedVolume != null && dcrteImportedVolume.finalSolidCount > 0
        && outsideZero && printable && exportEnabled;
      boolean invalidPassed = loaded && !meshStrict && !exportEnabled
        && dcrteImportedDomain == null && dcrteImportedSdf == null && dcrteImportedVolume == null;
      boolean runPassed = expectedValid[i] ? validPassed : invalidPassed;
      if (runPassed) passed++;
      JSONObject run = new JSONObject();
      run.setString("id", ids[i]);
      run.setInt("resolution", resolutions[i]);
      run.setString("observation", observations[i].id());
      run.setBoolean("expected_valid", expectedValid[i]);
      run.setBoolean("loaded", loaded);
      run.setBoolean("mesh_strict_valid", meshStrict);
      run.setBoolean("domain_valid", dcrteImportedDomain != null && dcrteImportedDomain.isValid());
      run.setBoolean("mesh_printable", printable);
      run.setBoolean("export_enabled", exportEnabled);
      run.setBoolean("acceptance_passed", runPassed);
      run.setLong("elapsed_millis", millis() - start);
      if (dcrteImportedMeshReport != null) run.setJSONObject("mesh_report", dcrteImportedMeshReport.toJSON());
      if (dcrteImportedSdf != null) run.setJSONObject("sdf", dcrteImportedSdf.toJSON());
      if (dcrteLastValidationReport != null && expectedValid[i]) run.setJSONObject("validation", dcrteLastValidationReport.toJSON());
      if (runPassed && expectedValid[i]) {
        String outputName = new File(directory, ids[i] + "_material.stl").getAbsolutePath();
        foundryMesh.writeSTL(outputName);
        run.setString("material_stl", new File(outputName).getName());
      }
      runs.setJSONObject(i, run);
      println(ids[i] + " -> " + (runPassed ? "PASS" : "FAIL") + " in " + (millis() - start) + " ms");
    }
  }
  catch (Exception error) {
    println("M2 acceptance exception: " + error.getMessage());
  }

  JSONObject regressions = runDcrteM2RegressionMatrix();
  JSONObject report = new JSONObject();
  report.setString("architecture", "DCRTE-ET v0.3");
  report.setString("schema_version", "0.5-m2");
  report.setString("application", "Cosmosis Visual Observatory");
  report.setString("generated_at", nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2)
    + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2));
  report.setJSONObject("deterministic_tests", dcrteM2Tests.toJSON());
  report.setInt("acceptance_passed", passed);
  report.setInt("acceptance_total", 8);
  report.setJSONArray("runs", runs);
  report.setJSONObject("regressions", regressions);
  ensureDir(sketchPath("logs"));
  saveJSONObject(report, "logs/dcrte_m2_acceptance_latest.json");
  println("DCRTE-ET Milestone 2 acceptance matrix: " + passed + "/8");
}

JSONObject runDcrteM2RegressionMatrix() {
  JSONObject regressions = new JSONObject();
  dcrtePipelineMode = DCRTEPipelineMode.DCRTE_ADAPTER_TEST;
  runDcrteAdapterComparison();
  regressions.setString("adapter_status", dcrteAdapterDiagnostics.status);
  DCRTEPrimitiveDomainType[] domains = {DCRTEPrimitiveDomainType.SPHERE, DCRTEPrimitiveDomainType.BOX, DCRTEPrimitiveDomainType.CYLINDER};
  JSONArray primitive = new JSONArray();
  dcrtePipelineMode = DCRTEPipelineMode.DCRTE_PRIMITIVE;
  dcrtePrimitiveResolution = 64;
  dcrteObservationMode = DCRTEObservationMode.HARD_INTERIOR;
  for (int i = 0; i < domains.length; i++) {
    dcrtePrimitiveDomainType = domains[i];
    generateDcrtePrimitiveSurfaceMesh();
    JSONObject run = new JSONObject();
    run.setString("domain", domains[i].id());
    run.setBoolean("printable", foundryMeshIsPrintable());
    run.setInt("outside_solid", dcrteLastValidationReport == null ? -1 : dcrteLastValidationReport.outsideSolidSamples);
    primitive.setJSONObject(i, run);
  }
  dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.CYLINDER;
  dcrteObservationMode = DCRTEObservationMode.SHELL_BAND;
  generateDcrtePrimitiveSurfaceMesh();
  regressions.setBoolean("printed_cylinder_shell_printable", foundryMeshIsPrintable());
  regressions.setJSONArray("primitive_hard", primitive);
  dcrtePipelineMode = DCRTEPipelineMode.LEGACY_DIRECT;
  generateSurfaceFoundryMesh();
  regressions.setBoolean("legacy_printable", foundryMeshIsPrintable());
  regressions.setInt("legacy_triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
  regressions.setBoolean("m1_deterministic_tests", dcrteM1Tests.ok());
  return regressions;
}
