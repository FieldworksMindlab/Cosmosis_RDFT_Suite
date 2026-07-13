/* DCRTE-ET Milestone 1 deterministic, file-free fixtures. */

class DCRTEM1TestReport {
  int passed;
  int failed;
  ArrayList<String> failures = new ArrayList<String>();

  void check(boolean condition, String name) {
    if (condition) passed++;
    else {
      failed++;
      failures.add(name);
    }
  }

  boolean ok() { return failed == 0; }
  String status() { return ok() ? "PASS " + passed : "FAIL " + failed + "/" + (passed + failed); }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("status", ok() ? "pass" : "fail");
    json.setInt("passed", passed);
    json.setInt("failed", failed);
    JSONArray values = new JSONArray();
    for (int i = 0; i < failures.size(); i++) values.setString(i, failures.get(i));
    json.setJSONArray("failures", values);
    return json;
  }
}

DCRTEM1TestReport dcrteM1Tests = new DCRTEM1TestReport();

boolean dcrteCommandLineFlag(String flag) {
  if (args == null) return false;
  for (int i = 0; i < args.length; i++) if (flag.equals(args[i])) return true;
  return false;
}

void initializeDcrteMilestone1() {
  dcrteM1Tests = runDcrteMilestone1Tests();
  println("DCRTE-ET Milestone 1 deterministic tests: " + dcrteM1Tests.status());
  for (int i = 0; i < dcrteM1Tests.failures.size(); i++) {
    println("  FAIL " + dcrteM1Tests.failures.get(i));
  }
}

DCRTEM1TestReport runDcrteMilestone1Tests() {
  DCRTEM1TestReport report = new DCRTEM1TestReport();
  final float tolerance = 0.00001f;

  SphereDomain sphere = new SphereDomain(0, 0, 0, 1);
  report.check(abs(sphere.signedDistance(0, 0, 0) + 1) <= tolerance, "sphere center sdf");
  report.check(abs(sphere.signedDistance(1, 0, 0)) <= tolerance, "sphere boundary sdf");
  report.check(abs(sphere.signedDistance(2, 0, 0) - 1) <= tolerance, "sphere exterior sdf");
  report.check(abs(sphere.signedDistance(0, 0.5f, 0) + 0.5f) <= tolerance, "sphere interior sdf");

  BoxDomain box = new BoxDomain(0, 0, 0, 1, 1, 1);
  report.check(abs(box.signedDistance(0, 0, 0) + 1) <= tolerance, "box center sdf");
  report.check(abs(box.signedDistance(1, 0, 0)) <= tolerance, "box face sdf");
  report.check(abs(box.signedDistance(2, 0, 0) - 1) <= tolerance, "box exterior sdf");
  report.check(abs(box.signedDistance(1, 1, 1)) <= tolerance, "box corner sdf");
  report.check(abs(box.signedDistance(2, 2, 2) - sqrt(3)) <= tolerance, "box exterior corner sdf");

  CylinderDomain cylinder = new CylinderDomain(0, 0, 0, 1, 1);
  report.check(abs(cylinder.signedDistance(0, 0, 0) + 1) <= tolerance, "cylinder center sdf");
  report.check(abs(cylinder.signedDistance(1, 0, 0)) <= tolerance, "cylinder side sdf");
  report.check(abs(cylinder.signedDistance(0, 1, 0)) <= tolerance, "cylinder cap sdf");
  report.check(abs(cylinder.signedDistance(2, 0, 0) - 1) <= tolerance, "cylinder radial exterior sdf");
  report.check(abs(cylinder.signedDistance(0, 2, 0) - 1) <= tolerance, "cylinder axial exterior sdf");

  VolumeSpec smallSpec = new VolumeSpec(4, 4, 4, new Bounds3D(-1, -1, -1, 1, 1, 1));
  UniformGridObserver smallObserver = new UniformGridObserver();
  smallObserver.initialize(smallSpec);
  report.check(abs(smallObserver.worldX(0) + 0.75f) <= tolerance, "observer first center");
  report.check(abs(smallObserver.worldX(3) - 0.75f) <= tolerance, "observer last center");
  boolean[] seen = new boolean[64];
  boolean unique = true;
  for (int z = 0; z < 4; z++) for (int y = 0; y < 4; y++) for (int x = 0; x < 4; x++) {
    int idx = smallObserver.index(x, y, z);
    if (idx < 0 || idx >= 64 || seen[idx]) unique = false;
    else seen[idx] = true;
  }
  report.check(unique && smallObserver.index(0, 0, 0) == 0 && smallObserver.index(3, 3, 3) == 63, "observer index mapping");
  report.check(abs(smallSpec.sampleVolume() * smallSpec.voxelCount() - smallSpec.bounds.volume()) <= tolerance, "observer sample volume");

  DomainSample domainSample = new DomainSample();
  ObservationSample observationSample = new ObservationSample();
  HardInteriorObservation hard = new HardInteriorObservation(0.01f);
  sphere.sample(0, 0, 0, domainSample); hard.observe(domainSample, observationSample);
  report.check(observationSample.admitted, "hard admits interior");
  sphere.sample(1, 0, 0, domainSample); hard.observe(domainSample, observationSample);
  report.check(observationSample.admitted, "hard admits boundary");
  sphere.sample(1.1f, 0, 0, domainSample); hard.observe(domainSample, observationSample);
  report.check(!observationSample.admitted, "hard rejects exterior");
  ShellBandObservation shell = new ShellBandObservation(0.01f, 0.2f, 4);
  sphere.sample(0.9f, 0, 0, domainSample); shell.observe(domainSample, observationSample);
  report.check(observationSample.admitted, "shell admits near boundary");
  sphere.sample(0, 0, 0, domainSample); shell.observe(domainSample, observationSample);
  report.check(!observationSample.admitted, "shell rejects deep interior");
  sphere.sample(1.1f, 0, 0, domainSample); shell.observe(domainSample, observationSample);
  report.check(!observationSample.admitted, "shell rejects exterior");
  report.check(dcrteCountAdmitted(sphere, hard, smallObserver) > dcrteCountAdmitted(sphere, shell, smallObserver), "shell smaller than interior");

  DCRTEValidationReport savedValidation = dcrteLastValidationReport;
  dcrteRunSyntheticVolumeTests(report);
  dcrteLastValidationReport = savedValidation;

  ObservationDomain[] convergenceDomains = {
    new SphereDomain(0, 0, 0, 0.88f),
    new BoxDomain(0, 0, 0, 0.78f, 0.78f, 0.78f),
    new CylinderDomain(0, 0, 0, 0.68f, 0.88f)
  };
  for (int i = 0; i < convergenceDomains.length; i++) {
    float error32 = dcrteDomainVolumeError(convergenceDomains[i], 32);
    float error64 = dcrteDomainVolumeError(convergenceDomains[i], 64);
    report.check(dcrteFinite(error32) && error32 < 0.25f, convergenceDomains[i].getId() + " 32 volume sane");
    report.check(dcrteFinite(error64) && error64 < 0.15f, convergenceDomains[i].getId() + " 64 volume sane");
    report.check(error64 <= error32 + 0.04f, convergenceDomains[i].getId() + " volume convergence");
  }
  return report;
}

int dcrteCountAdmitted(ObservationDomain domain, ObservationLayer layer, UniformGridObserver observer) {
  int count = 0;
  DomainSample ds = new DomainSample();
  ObservationSample os = new ObservationSample();
  for (int z = 0; z < observer.spec.nz; z++) for (int y = 0; y < observer.spec.ny; y++) for (int x = 0; x < observer.spec.nx; x++) {
    domain.sample(observer.worldX(x), observer.worldY(y), observer.worldZ(z), ds);
    layer.observe(ds, os);
    if (os.admitted) count++;
  }
  return count;
}

float dcrteDomainVolumeError(ObservationDomain domain, int resolution) {
  VolumeSpec spec = new VolumeSpec(resolution, resolution, resolution, new Bounds3D(-1, -1, -1, 1, 1, 1));
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(spec);
  DomainSample sample = new DomainSample();
  int inside = 0;
  for (int z = 0; z < resolution; z++) for (int y = 0; y < resolution; y++) for (int x = 0; x < resolution; x++) {
    domain.sample(observer.worldX(x), observer.worldY(y), observer.worldZ(z), sample);
    if (sample.inside) inside++;
  }
  float sampled = inside * spec.sampleVolume();
  return abs(sampled - domain.analyticVolume()) / domain.analyticVolume();
}

void dcrteRunSyntheticVolumeTests(DCRTEM1TestReport tests) {
  VolumeSpec spec = new VolumeSpec(32, 32, 32, new Bounds3D(-1, -1, -1, 1, 1, 1));
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(spec);
  ObservationDomain domain = new SphereDomain(0, 0, 0, 0.88f);
  ObservationLayer layer = new HardInteriorObservation(dcrteBoundaryEpsilon(spec));
  DCRTEVolume empty = dcrteSyntheticVolume(spec, observer, domain, layer, 0);
  DCRTEValidationReport emptyReport = new DCRTEValidationReport();
  validateDcrteVolume(emptyReport, empty, domain, true);
  tests.check(emptyReport.errors.contains("EMPTY_FINAL_VOLUME") && !emptyReport.exportAllowed(), "synthetic empty validation");

  DCRTEVolume full = dcrteSyntheticVolume(spec, observer, domain, layer, 1);
  DCRTEValidationReport fullReport = new DCRTEValidationReport();
  validateDcrteVolume(fullReport, full, domain, true);
  tests.check(fullReport.warnings.contains("FULL_FINAL_VOLUME") && fullReport.outsideSolidSamples == 0, "synthetic full validation");

  DCRTEVolume checker = dcrteSyntheticVolume(spec, observer, domain, layer, 2);
  DCRTEValidationReport checkerReport = new DCRTEValidationReport();
  validateDcrteVolume(checkerReport, checker, domain, true);
  tests.check(checkerReport.finalSolidSamples > 0 && checkerReport.finalSolidSamples < checkerReport.admittedSamples
    && checkerReport.outsideSolidSamples == 0 && checkerReport.exportAllowed(), "synthetic checker validation");
}

DCRTEVolume dcrteSyntheticVolume(VolumeSpec spec, UniformGridObserver observer, ObservationDomain domain, ObservationLayer layer, int mode) {
  DCRTEVolume volume = new DCRTEVolume(spec);
  DomainSample ds = new DomainSample();
  ObservationSample os = new ObservationSample();
  for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
    int idx = observer.index(x, y, z);
    domain.sample(observer.worldX(x), observer.worldY(y), observer.worldZ(z), ds);
    if (ds.inside) volume.domainInsideCount++;
    layer.observe(ds, os);
    volume.admitted[idx] = os.admitted;
    if (os.admitted) volume.admittedCount++;
    boolean candidate = mode == 1 || (mode == 2 && ((x + y + z) & 1) == 0);
    volume.candidateSolid[idx] = candidate;
    if (candidate) volume.candidateSolidCount++;
    volume.active[idx] = os.admitted && candidate;
    volume.finalSolid[idx] = volume.active[idx];
  }
  volume.recountFinal();
  return volume;
}

void runDcrteMilestone1AcceptanceMatrix() {
  println("DCRTE-ET Milestone 1 acceptance matrix starting...");
  DCRTEPipelineMode previousPipeline = dcrtePipelineMode;
  DCRTEPrimitiveDomainType previousDomain = dcrtePrimitiveDomainType;
  DCRTEObservationMode previousObservation = dcrteObservationMode;
  int previousResolution = dcrtePrimitiveResolution;
  dcrtePipelineMode = DCRTEPipelineMode.DCRTE_PRIMITIVE;
  dcrtePrimitiveResolution = 64;

  JSONArray runs = new JSONArray();
  int runIndex = 0;
  int passed = 0;
  for (DCRTEPrimitiveDomainType domainType : DCRTEPrimitiveDomainType.values()) {
    for (DCRTEObservationMode observationMode : DCRTEObservationMode.values()) {
      dcrtePrimitiveDomainType = domainType;
      dcrteObservationMode = observationMode;
      generateDcrtePrimitiveSurfaceMesh();
      JSONObject run = new JSONObject();
      run.setString("id", "M1-" + char('A' + runIndex));
      run.setString("domain", domainType.id());
      run.setString("observation", observationMode.id());
      run.setInt("resolution", dcrtePrimitiveResolution);
      run.setString("build_stage", dcrteBuildStage);
      run.setBoolean("mesh_printable", foundryMeshIsPrintable());
      run.setInt("triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
      run.setInt("mesh_boundary_edges", foundryBoundaryEdges);
      run.setInt("mesh_non_manifold_edges", foundryNonManifoldEdges);
      run.setInt("mesh_degenerate_faces", foundryDegenerateFaces);
      run.setInt("regularizer_bridge_voxels", foundryBridgeVoxels);
      run.setInt("domain_repair_additions", dcrteLegacyMaterializer.lastDomainRepairAdditions);
      run.setInt("domain_repair_removals", dcrteLegacyMaterializer.lastDomainRepairRemovals);
      if (dcrteLastValidationReport != null) run.setJSONObject("validation", dcrteLastValidationReport.toJSON());
      boolean runPassed = dcrteLastValidationReport != null
        && dcrteLastValidationReport.exportAllowed()
        && dcrteLastValidationReport.finalSolidSamples > 0
        && dcrteLastValidationReport.outsideSolidSamples == 0
        && foundryMeshIsPrintable();
      run.setBoolean("acceptance_passed", runPassed);
      if (runPassed) passed++;
      runs.setJSONObject(runIndex, run);
      println(run.getString("id") + " " + domainType.id() + " " + observationMode.id()
        + " -> " + (runPassed ? "PASS" : "FAIL") + " in " + dcrteLastBuildMillis + " ms");
      runIndex++;
    }
  }

  JSONObject sampleProvenance = dcrteLastBuildConfiguration == null
    ? new JSONObject()
    : dcrteLastBuildConfiguration.toJSONObject();
  if (dcrteLastValidationReport != null) sampleProvenance.setJSONObject("validation", dcrteLastValidationReport.toJSON());
  if (dcrtePrimitiveVolume != null) sampleProvenance.setJSONObject("volume", dcrtePrimitiveVolume.toJSON());

  JSONArray supplementalRuns = new JSONArray();
  int[] supplementalResolutions = {32, 128};
  for (int i = 0; i < supplementalResolutions.length; i++) {
    dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.SPHERE;
    dcrteObservationMode = DCRTEObservationMode.HARD_INTERIOR;
    dcrtePrimitiveResolution = supplementalResolutions[i];
    generateDcrtePrimitiveSurfaceMesh();
    JSONObject run = new JSONObject();
    run.setString("id", supplementalResolutions[i] == 32 ? "M1-DEBUG-32" : "M1-PREVIEW-128");
    run.setInt("resolution", supplementalResolutions[i]);
    run.setString("domain", "sphere");
    run.setString("observation", "hard_interior");
    run.setBoolean("mesh_printable", foundryMeshIsPrintable());
    run.setInt("triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
    if (dcrteLastValidationReport != null) run.setJSONObject("validation", dcrteLastValidationReport.toJSON());
    supplementalRuns.setJSONObject(i, run);
    println(run.getString("id") + " -> " + (foundryMeshIsPrintable() ? "PASS" : "FAIL")
      + " in " + dcrteLastBuildMillis + " ms");
  }

  dcrtePipelineMode = DCRTEPipelineMode.LEGACY_DIRECT;
  generateSurfaceFoundryMesh();
  JSONObject legacyRegression = new JSONObject();
  legacyRegression.setBoolean("mesh_generated", foundryMesh != null && foundryMesh.tris.size() > 0);
  legacyRegression.setBoolean("mesh_printable", foundryMeshIsPrintable());
  legacyRegression.setInt("triangles", foundryMesh == null ? 0 : foundryMesh.tris.size());
  legacyRegression.setInt("boundary_edges", foundryBoundaryEdges);
  legacyRegression.setInt("non_manifold_edges", foundryNonManifoldEdges);
  legacyRegression.setInt("degenerate_faces", foundryDegenerateFaces);

  dcrtePipelineMode = DCRTEPipelineMode.DCRTE_ADAPTER_TEST;
  runDcrteAdapterComparison();
  JSONObject adapterRegression = new JSONObject();
  adapterRegression.setString("status", dcrteAdapterDiagnostics.status);
  adapterRegression.setInt("sample_count", dcrteAdapterDiagnostics.sampleCount);
  adapterRegression.setFloat("max_absolute_error", dcrteAdapterDiagnostics.maxAbsoluteError);
  adapterRegression.setFloat("mean_absolute_error", dcrteAdapterDiagnostics.meanAbsoluteError);

  JSONObject report = new JSONObject();
  report.setString("architecture", "DCRTE-ET v0.3");
  report.setString("schema_version", "0.4-m1");
  report.setString("application", "Cosmosis Visual Observatory");
  report.setString("generated_at", nf(year(), 4) + "-" + nf(month(), 2) + "-" + nf(day(), 2)
    + " " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2));
  report.setJSONObject("deterministic_tests", dcrteM1Tests.toJSON());
  report.setInt("acceptance_passed", passed);
  report.setInt("acceptance_total", runIndex);
  report.setJSONArray("runs", runs);
  report.setJSONObject("sample_primitive_provenance", sampleProvenance);
  report.setJSONArray("supplemental_runs", supplementalRuns);
  report.setJSONObject("legacy_regression", legacyRegression);
  report.setJSONObject("adapter_regression", adapterRegression);
  ensureDir(sketchPath("logs"));
  saveJSONObject(report, "logs/dcrte_m1_acceptance_latest.json");
  println("DCRTE-ET Milestone 1 acceptance matrix: " + passed + "/" + runIndex);

  dcrtePipelineMode = previousPipeline;
  dcrtePrimitiveDomainType = previousDomain;
  dcrteObservationMode = previousObservation;
  dcrtePrimitiveResolution = previousResolution;
}
