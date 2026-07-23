/* DCRTE-ET Milestone 2 grid-backed imported observation domain and lifecycle. */

enum DCRTEImportedBuildState {
  NO_MESH,
  IMPORTING,
  MESH_READY,
  MESH_INVALID,
  SDF_DIRTY,
  BUILDING_BOUNDARY,
  CLASSIFYING_INTERIOR,
  COMPUTING_DISTANCE,
  VALIDATING_SDF,
  SDF_READY,
  SDF_FAILED,
  MATERIALIZING,
  READY;

  String label() { return name().replace('_', ' '); }
}

enum DCRTESliceAxis {
  XY,
  XZ,
  YZ
}

class ImportedMeshDomain implements ObservationDomain {
  TriangleMeshData sourceMesh;
  TriangleMeshData worldMesh;
  MeshDomainReport meshReport;
  MeshTransform transform;
  SignedDistanceVolume sdf;
  InvalidDomainPolicy invalidPolicy;
  float[] normalScratch = new float[3];

  ImportedMeshDomain(TriangleMeshData sourceMesh, TriangleMeshData worldMesh,
      MeshDomainReport meshReport, MeshTransform transform, SignedDistanceVolume sdf,
      InvalidDomainPolicy invalidPolicy) {
    this.sourceMesh = sourceMesh;
    this.worldMesh = worldMesh;
    this.meshReport = meshReport;
    this.transform = transform;
    this.sdf = sdf;
    this.invalidPolicy = invalidPolicy;
  }

  public void sample(float x, float y, float z, DomainSample target) {
    if (target == null) return;
    if (!isValid()) {
      target.set(false, Float.POSITIVE_INFINITY, 0, 1, 0, 0, false);
      return;
    }
    float distance = sdf.sampleWorld(x, y, z);
    sdf.normalWorld(x, y, z, normalScratch);
    target.set(distance <= 0, distance, normalScratch[0], normalScratch[1], normalScratch[2], distance <= 0 ? 1 : 0, dcrteFinite(distance));
  }

  void sampleAtIndex(int x, int y, int z, DomainSample target) {
    if (target == null) return;
    if (!isValid() || x < 0 || y < 0 || z < 0 || x >= sdf.spec.nx || y >= sdf.spec.ny || z >= sdf.spec.nz) {
      target.set(false, Float.POSITIVE_INFINITY, 0, 1, 0, 0, false);
      return;
    }
    float distance = sdf.sampleAtIndex(x, y, z);
    sdf.normalAtIndex(x, y, z, normalScratch);
    target.set(sdf.inside[sdf.index(x, y, z)] || sdf.boundary[sdf.index(x, y, z)], distance,
      normalScratch[0], normalScratch[1], normalScratch[2], distance <= 0 ? 1 : 0, dcrteFinite(distance));
  }

  public float signedDistance(float x, float y, float z) { return isValid() ? sdf.sampleWorld(x, y, z) : Float.POSITIVE_INFINITY; }
  public Bounds3D bounds() { return worldMesh == null || worldMesh.worldBounds == null ? dcrteObserverBounds : worldMesh.worldBounds; }
  public float analyticVolume() { return meshReport == null ? 0 : (float)meshReport.absoluteVolumeWorld; }
  public String getId() { return "imported_mesh"; }
  public String getVersion() { return "1.0-m2"; }
  public boolean isValid() {
    return invalidPolicy == InvalidDomainPolicy.STRICT
      && meshReport != null && meshReport.strictValid()
      && transform != null && transform.isValid()
      && sdf != null && sdf.signed && sdf.isValid()
      && sdf.quality != null && sdf.quality.isValid();
  }
  boolean isPreviewOnly() { return !isValid(); }
  public String validationMessage() {
    if (meshReport == null) return "no imported mesh";
    if (!meshReport.strictValid()) return "preview only - source mesh is not a reliable closed domain";
    if (sdf == null) return "SDF not built";
    if (!sdf.signed) return "preview only - unsigned distance";
    if (sdf.quality == null || !sdf.quality.isValid()) return "SDF quality validation failed";
    return "valid";
  }

  JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    json.setString("reference_volume_type", "signed_triangle_mesh_volume");
    json.setString("invalid_domain_policy", invalidPolicy.id());
    json.setBoolean("preview_only", isPreviewOnly());
    json.setBoolean("valid", isValid());
    json.setString("validation_message", validationMessage());
    if (sourceMesh != null) json.setJSONObject("source_mesh", sourceMesh.toJSON());
    if (meshReport != null) json.setJSONObject("mesh_report", meshReport.toJSON());
    if (transform != null) json.setJSONObject("transform", transform.toJSON());
    if (sdf != null) json.setJSONObject("sdf", sdf.toJSON());
    return json;
  }
}

STLMeshImporter dcrteStlImporter = new STLMeshImporter();
DCRTEMeshSanitizer dcrteMeshSanitizer = new DCRTEMeshSanitizer();
TriangleMeshData dcrteImportedSourceMesh = null;
TriangleMeshData dcrteImportedWorldMesh = null;
MeshDomainReport dcrteImportedMeshReport = null;
MeshTransform dcrteImportedTransform = null;
VoxelBoundaryVolume dcrteImportedBoundary = null;
InsideOutsideVolume dcrteImportedInsideOutside = null;
SignedDistanceVolume dcrteImportedSdf = null;
ImportedMeshDomain dcrteImportedDomain = null;
DCRTEVolume dcrteImportedVolume = null;
DCRTEImportedBuildState dcrteImportedBuildState = DCRTEImportedBuildState.NO_MESH;
InvalidDomainPolicy dcrteImportedPolicy = InvalidDomainPolicy.STRICT;
int dcrteImportedResolution = 64;
int dcrteImportedRotateX = 0;
int dcrteImportedRotateY = 0;
int dcrteImportedRotateZ = 0;
float dcrteImportedFitMargin = 0.08f;
float dcrteImportedScaleMultiplier = 1.0f;
boolean dcrteImportedStale = true;
boolean dcrteImportedSdfDirty = true;
boolean dcrteImportedShowMesh = true;
int dcrteImportedMeshPreviewMode = 1;
boolean dcrteImportedShowBoundary = false;
boolean dcrteImportedShowSdf = true;
boolean dcrteImportedShowMaterial = true;
DCRTESliceAxis dcrteImportedSliceAxis = DCRTESliceAxis.XY;
int dcrteImportedSliceIndex = 32;
String dcrteImportedStatus = "load a watertight STL";
String dcrteImportedErrorCode = "";
String dcrteImportedErrorMessage = "";
boolean dcrteImportedSourceIsFixture = false;
JSONObject dcrteImportedFixtureMetadata = null;
DCRTEConfig dcrteImportedLastBuildConfiguration = null;
int dcrteImported128BuildArmedAt = -999999;

class DCRTEImportedMeshCandidate {
  TriangleMeshData sourceMesh;
  TriangleMeshData worldMesh;
  MeshDomainReport meshReport;
  MeshTransform transform;
  DomainPreflightReport preflightReport;
  boolean sourceIsFixture;
  JSONObject fixtureMetadata;
}

VolumeSpec createDcrteImportedVolumeSpec() {
  return new VolumeSpec(dcrteImportedResolution, dcrteImportedResolution, dcrteImportedResolution, dcrteObserverBounds);
}

void selectDcrteImportedStl() {
  selectInput("Select a closed watertight STL observation domain", "dcrteImportedMeshSelected");
}

void dcrteImportedMeshSelected(File selection) {
  if (selection == null) {
    dcrteImportedStatus = "load canceled; current domain retained";
    return;
  }
  loadDcrteImportedFile(selection, false, null);
}

boolean loadDcrteImportedFile(File file, boolean fixture, JSONObject fixtureMetadata) {
  DCRTEImportedBuildState previousState = dcrteImportedBuildState;
  boolean hadCurrentDomain = dcrteImportedSourceMesh != null;
  dcrteImportedBuildState = DCRTEImportedBuildState.IMPORTING;
  dcrteImportedErrorCode = "";
  dcrteImportedErrorMessage = "";
  try {
    DCRTEImportedMeshCandidate candidate = buildDcrteImportedCandidate(file, fixture, fixtureMetadata);
    commitDcrteImportedCandidate(candidate);
    return true;
  }
  catch (MeshImportException error) {
    dcrteImportedErrorCode = error.code;
    dcrteImportedErrorMessage = dcrteImportedExceptionMessage(error);
  }
  catch (Exception error) {
    dcrteImportedErrorCode = "IMPORT_PARSE_FAILURE";
    dcrteImportedErrorMessage = dcrteImportedExceptionMessage(error);
    println("DCRTE imported-domain replacement failed before commit: "
      + error.getClass().getSimpleName() + " " + dcrteImportedErrorMessage);
    error.printStackTrace();
  }
  dcrteImportedBuildState = hadCurrentDomain ? previousState : DCRTEImportedBuildState.MESH_INVALID;
  dcrteImportedStatus = "import failed: " + dcrteImportedErrorCode
    + (hadCurrentDomain ? "; current domain retained" : "");
  dcrteImportedAttemptPreflightReport = createDcrteParseFailurePreflight(file,
    dcrteImportedErrorCode, dcrteImportedErrorMessage);
  dcrtePreflightPanelOpen = true;
  return false;
}

DCRTEImportedMeshCandidate buildDcrteImportedCandidate(File file, boolean fixture,
    JSONObject fixtureMetadata) throws Exception {
  if (file == null) throw new MeshImportException("IMPORT_FILE_NOT_FOUND", "No STL source was selected");

  DCRTEImportedMeshCandidate candidate = new DCRTEImportedMeshCandidate();
  candidate.sourceIsFixture = fixture;
  candidate.fixtureMetadata = fixtureMetadata;

  long importStart = millis();
  TriangleMeshData parsed = dcrteStlImporter.load(file);
  long importMillis = millis() - importStart;
  long sanitationStart = millis();
  MeshValidationResult validation = dcrteMeshSanitizer.sanitize(parsed);
  long sanitationMillis = millis() - sanitationStart;
  if (validation == null || validation.mesh == null) {
    throw new MeshImportException("IMPORT_EMPTY_MESH", "Mesh sanitation produced no usable triangles");
  }
  if (validation.report == null) {
    throw new MeshImportException("IMPORT_VALIDATION_FAILURE", "Mesh sanitation produced no validation report");
  }

  candidate.sourceMesh = validation.mesh;
  candidate.meshReport = validation.report;
  candidate.meshReport.importParseMillis = importMillis;
  candidate.meshReport.sanitationMillis = sanitationMillis;
  candidate.transform = createDcrteFitTransform(candidate.sourceMesh, dcrteObserverBounds,
    0, 0, 0, dcrteImportedFitMargin, 1.0f);
  if (candidate.transform == null) {
    throw new MeshImportException("TRANSFORM_INVALID", "Imported mesh could not be fitted into the observation domain");
  }
  candidate.worldMesh = candidate.sourceMesh.copyTransformed(candidate.transform);
  if (candidate.worldMesh == null || !candidate.worldMesh.isStructurallyValid()) {
    throw new MeshImportException("TRANSFORM_INVALID", "Imported mesh transform produced an invalid world mesh");
  }
  dcrteUpdateWorldReport(candidate.meshReport, candidate.worldMesh, candidate.transform);

  candidate.preflightReport = dcrtePreflightMeshAnalyzer.analyze(
    candidate.sourceMesh, candidate.worldMesh, candidate.meshReport,
    candidate.transform, dcrteImportedResolution, dcrteObserverBounds);
  if (candidate.preflightReport == null) {
    throw new MeshImportException("IMPORT_PREFLIGHT_FAILURE", "Imported mesh preflight produced no report");
  }
  candidate.preflightReport.sanitationPolicy = SanitationPolicy.SAFE_AUTOMATIC;
  if (fixture && fixtureMetadata != null) {
    candidate.preflightReport.referenceCaseId = fixtureMetadata.getString("fixture_id", "");
  }
  dcrtePreflightVolumeAnalyzer.attach(candidate.preflightReport, candidate.worldMesh,
    null, null, null, null, null, false, false);
  candidate.preflightReport.reportStale = false;
  return candidate;
}

void commitDcrteImportedCandidate(DCRTEImportedMeshCandidate candidate) throws MeshImportException {
  if (candidate == null || candidate.sourceMesh == null || candidate.worldMesh == null
      || candidate.meshReport == null || candidate.transform == null || candidate.preflightReport == null) {
    throw new MeshImportException("IMPORT_COMMIT_FAILURE", "Imported mesh candidate is incomplete");
  }

  clearDcrteImportedDerivedState();
  dcrteImportedSourceMesh = candidate.sourceMesh;
  dcrteImportedWorldMesh = candidate.worldMesh;
  dcrteImportedMeshReport = candidate.meshReport;
  dcrteImportedTransform = candidate.transform;
  dcrteImportedSourceIsFixture = candidate.sourceIsFixture;
  dcrteImportedFixtureMetadata = candidate.fixtureMetadata;
  dcrteImportedRotateX = 0;
  dcrteImportedRotateY = 0;
  dcrteImportedRotateZ = 0;
  dcrteImportedScaleMultiplier = 1.0f;
  dcrteImportedSdfDirty = true;
  dcrteImportedStale = true;
  dcrteImportedLastBuildConfiguration = null;
  dcrteImported128BuildArmedAt = -999999;
  dcrteImportedBuildState = dcrteImportedMeshReport.strictValid()
    ? DCRTEImportedBuildState.SDF_DIRTY
    : DCRTEImportedBuildState.MESH_INVALID;
  dcrteImportedStatus = dcrteImportedMeshReport.strictValid()
    ? "mesh inspected; rebuild SDF when ready"
    : "preview only - domain sign is unreliable";
  dcrteImportedAttemptPreflightReport = null;
  dcrteImportedPreflightReport = candidate.preflightReport;
  dcrteImportedPreflightReport.reportStale = false;
  dcrtePreflightIssueIndex = 0;
  dcrtePreflightClampIssueIndex();
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    markFoundryStale();
    foundryStatus = "imported source changed; rebuild SDF";
  }
}

String dcrteImportedExceptionMessage(Exception error) {
  if (error == null) return "unknown import failure";
  String message = error.getMessage();
  return message == null || message.length() == 0 ? error.getClass().getSimpleName() : message;
}

void clearDcrteImportedDerivedState() {
  dcrteInvalidateScheduler("imported derived state cleared");
  dcrteImportedWorldMesh = null;
  dcrteImportedTransform = null;
  dcrteImportedBoundary = null;
  dcrteImportedInsideOutside = null;
  dcrteImportedSdf = null;
  dcrteImportedDomain = null;
  dcrteImportedVolume = null;
  dcrteImportedLastBuildConfiguration = null;
  dcrteLastValidationReport = null;
  invalidateDcrteIntrinsic("imported derived state cleared");
}

void rebuildDcrteImportedTransform(boolean markStale) {
  if (dcrteImportedSourceMesh == null) return;
  MeshTransform next = createDcrteFitTransform(dcrteImportedSourceMesh, dcrteObserverBounds,
    dcrteImportedRotateX, dcrteImportedRotateY, dcrteImportedRotateZ,
    dcrteImportedFitMargin, dcrteImportedScaleMultiplier);
  if (next == null) {
    dcrteImportedErrorCode = "TRANSFORM_INVALID";
    dcrteImportedStatus = "transform invalid";
    return;
  }
  TriangleMeshData world = dcrteImportedSourceMesh.copyTransformed(next);
  dcrteImportedTransform = next;
  dcrteImportedWorldMesh = world;
  dcrteUpdateWorldReport(dcrteImportedMeshReport, world, next);
  if (markStale) {
    markDcrteImportedStale("transform changed; rebuild SDF");
    runDcrteImportedPreflight();
  }
}

void markDcrteImportedStale(String reason) {
  dcrteInvalidateScheduler(reason);
  dcrteImportedSdfDirty = true;
  dcrteImportedStale = true;
  invalidateDcrteIntrinsic(reason);
  markDcrtePreflightStale();
  dcrteImportedLastBuildConfiguration = null;
  if (dcrteImportedSourceMesh != null) {
    boolean strictInvalid = dcrteImportedPolicy == InvalidDomainPolicy.STRICT
      && dcrteImportedMeshReport != null && !dcrteImportedMeshReport.strictValid();
    dcrteImportedBuildState = strictInvalid
      ? DCRTEImportedBuildState.MESH_INVALID
      : DCRTEImportedBuildState.SDF_DIRTY;
  }
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    markFoundryStale();
    foundryStatus = reason;
  }
}

void markDcrteImportedMaterialStale(String reason) {
  dcrteInvalidateScheduler(reason);
  dcrteImportedStale = true;
  markDcrtePreflightStale();
  dcrteImportedLastBuildConfiguration = null;
  if (!dcrteImportedSdfDirty && dcrteImportedDomain != null && dcrteImportedDomain.isValid()) {
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_READY;
  }
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    markFoundryStale();
    foundryStatus = reason;
  }
}

boolean buildDcrteImportedSdf() {
  if (dcrteImportedSourceMesh == null || dcrteImportedWorldMesh == null || dcrteImportedMeshReport == null) {
    dcrteImportedStatus = "load a mesh before building SDF";
    return false;
  }
  runDcrteImportedPreflight();
  boolean strict = dcrteImportedPolicy == InvalidDomainPolicy.STRICT;
  if (strict && !dcrteImportedMeshReport.strictValid()) {
    dcrteImportedBuildState = DCRTEImportedBuildState.MESH_INVALID;
    dcrteImportedStatus = "strict SDF disabled - invalid closed domain";
    return false;
  }
  if (strict && !dcrtePreflightAllowsSdfBuild()) {
    dcrteImportedBuildState = DCRTEImportedBuildState.MESH_INVALID;
    dcrteImportedStatus = "strict SDF disabled - " + dcrteImportedPreflightReport.firstBlockingCode;
    dcrtePreflightPanelOpen = true;
    return false;
  }
  VolumeSpec spec = createDcrteImportedVolumeSpec();
  dcrteImportedBuildState = DCRTEImportedBuildState.BUILDING_BOUNDARY;
  VoxelBoundaryVolume nextBoundary = new ConservativeBoundaryVoxelizer().build(dcrteImportedWorldMesh, spec);
  if (!nextBoundary.isValid()) {
    dcrteImportedBoundary = nextBoundary;
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "boundary voxelization failed";
    runDcrteImportedPreflightWithDerived(true, false);
    return false;
  }
  InsideOutsideVolume nextClassification = null;
  if (strict) {
    dcrteImportedBuildState = DCRTEImportedBuildState.CLASSIFYING_INTERIOR;
    nextClassification = new DeterministicInsideOutsideClassifier().classify(dcrteImportedWorldMesh, nextBoundary);
    if (!nextClassification.isValid()) {
      dcrteImportedBoundary = nextBoundary;
      dcrteImportedInsideOutside = nextClassification;
      dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
      dcrteImportedStatus = "inside/outside parity failed";
      runDcrteImportedPreflightWithDerived(true, false);
      return false;
    }
  }
  dcrteImportedBuildState = DCRTEImportedBuildState.COMPUTING_DISTANCE;
  DCRTESignedDistanceBuilder builder = new DCRTESignedDistanceBuilder();
  builder.halfVoxelCorrection = false;
  SignedDistanceVolume nextSdf = builder.build(nextBoundary, nextClassification,
    dcrteImportedMeshReport.absoluteVolumeWorld, strict);
  dcrteImportedBuildState = DCRTEImportedBuildState.VALIDATING_SDF;
  dcrteImportedBoundary = nextBoundary;
  dcrteImportedInsideOutside = nextClassification;
  dcrteImportedSdf = nextSdf;
  dcrteImportedDomain = new ImportedMeshDomain(dcrteImportedSourceMesh, dcrteImportedWorldMesh,
    dcrteImportedMeshReport, dcrteImportedTransform, nextSdf, dcrteImportedPolicy);
  invalidateDcrteIntrinsic("signed distance volume rebuilt");
  dcrteImportedSliceIndex = constrain(dcrteImportedSliceIndex, 0, dcrteImportedResolution - 1);
  if (strict && (nextSdf == null || nextSdf.quality == null || !nextSdf.quality.isValid() || !dcrteImportedDomain.isValid())) {
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "SDF quality validation failed";
    runDcrteImportedPreflightWithDerived(true, false);
    return false;
  }
  dcrteImportedSdfDirty = false;
  dcrteImportedStale = true;
  dcrteImportedBuildState = strict ? DCRTEImportedBuildState.SDF_READY : DCRTEImportedBuildState.MESH_INVALID;
  dcrteImportedStatus = strict ? "signed distance domain ready" : "preview only - unsigned distance ready";
  runDcrteImportedPreflightWithDerived(true, false);
  return strict;
}

void requestDcrteImportedSdfBuild() {
  if (dcrteImportedResolution == 128 && millis() - dcrteImported128BuildArmedAt > 10000) {
    dcrteImported128BuildArmedAt = millis();
    dcrteImportedStatus = "128^3 research build; click REBUILD again to confirm";
    return;
  }
  dcrteImported128BuildArmedAt = -999999;
  buildDcrteImportedSdf();
}

void cycleDcrteImportedPolicy() {
  dcrteImportedPolicy = dcrteImportedPolicy == InvalidDomainPolicy.STRICT
    ? InvalidDomainPolicy.UNSIGNED_PREVIEW
    : InvalidDomainPolicy.STRICT;
  markDcrteImportedStale("invalid-domain policy changed; rebuild SDF");
  runDcrteImportedPreflight();
}

void cycleDcrteImportedResolution() {
  if (dcrteImportedResolution == 32) dcrteImportedResolution = 64;
  else if (dcrteImportedResolution == 64) dcrteImportedResolution = 128;
  else dcrteImportedResolution = 32;
  dcrteImportedSliceIndex = dcrteImportedResolution / 2;
  markDcrteImportedStale("imported SDF resolution changed; rebuild");
  runDcrteImportedPreflight();
}

void adjustDcrteImportedResolution(int direction) {
  if (direction < 0) dcrteImportedResolution = dcrteImportedResolution == 128 ? 64 : 32;
  else dcrteImportedResolution = dcrteImportedResolution == 32 ? 64 : 128;
  dcrteImportedSliceIndex = dcrteImportedResolution / 2;
  markDcrteImportedStale("imported SDF resolution changed; rebuild");
  runDcrteImportedPreflight();
}

void rotateDcrteImportedAxis(char axis) {
  if (axis == 'X') dcrteImportedRotateX = (dcrteImportedRotateX + 1) % 4;
  else if (axis == 'Y') dcrteImportedRotateY = (dcrteImportedRotateY + 1) % 4;
  else dcrteImportedRotateZ = (dcrteImportedRotateZ + 1) % 4;
  rebuildDcrteImportedTransform(true);
}

void resetDcrteImportedTransform() {
  dcrteImportedRotateX = 0; dcrteImportedRotateY = 0; dcrteImportedRotateZ = 0;
  dcrteImportedScaleMultiplier = 1.0f;
  rebuildDcrteImportedTransform(true);
}

void adjustDcrteImportedScale(float delta) {
  dcrteImportedScaleMultiplier = constrain(dcrteImportedScaleMultiplier + delta, 0.35f, 1.0f);
  rebuildDcrteImportedTransform(true);
}

void cycleDcrteImportedSliceAxis() {
  if (dcrteImportedSliceAxis == DCRTESliceAxis.XY) dcrteImportedSliceAxis = DCRTESliceAxis.XZ;
  else if (dcrteImportedSliceAxis == DCRTESliceAxis.XZ) dcrteImportedSliceAxis = DCRTESliceAxis.YZ;
  else dcrteImportedSliceAxis = DCRTESliceAxis.XY;
}

void cycleDcrteImportedMeshPreview() {
  dcrteImportedMeshPreviewMode = (dcrteImportedMeshPreviewMode + 1) % 3;
  dcrteImportedShowMesh = dcrteImportedMeshPreviewMode != 0;
}

void adjustDcrteImportedSlice(int delta) {
  dcrteImportedSliceIndex = constrain(dcrteImportedSliceIndex + delta, 0, max(0, dcrteImportedResolution - 1));
}

boolean dcrteImportedExportAllowed() {
  return dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH
    || (dcrteRawImportedExportReady()
      && dcrteImportedPreflightReport != null
      && !dcrteImportedPreflightReport.reportStale
      && dcrteImportedPreflightReport.qualification == DomainQualification.MATERIALIZATION_READY
      && dcrteImportedPreflightReport.exportEnabled
      && dcrteSchedulerExportAllowed()
      && dcrteM6CompositionExportAllowed());
}
