/* DCRTE-ET Milestone 1 primitive-domain and volume validation. */

enum ValidationStatus {
  PASS,
  PASS_WITH_WARNINGS,
  FAIL;

  String id() { return name().toLowerCase(); }
}

class DCRTEValidationReport {
  ValidationStatus status = ValidationStatus.PASS;
  ArrayList<String> errors = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();

  int totalSamples;
  int domainInsideSamples;
  int admittedSamples;
  int candidateSolidSamples;
  int finalSolidSamples;
  int outsideSolidSamples;
  int nonFiniteScalarSamples;
  int firstNonFiniteIndex = -1;
  float firstNonFiniteX;
  float firstNonFiniteY;
  float firstNonFiniteZ;

  float admittedFraction;
  float finalFractionOfGrid;
  float finalFractionOfDomain;
  float analyticDomainVolume;
  float sampledDomainVolume;
  float domainVolumeRelativeError;
  float domainVolumeWarningThreshold;

  long domainBuildMillis;
  long fieldSampleMillis;
  long materializeMillis;
  long validationMillis;
  long totalMillis;

  void addError(String code) {
    if (!errors.contains(code)) errors.add(code);
    updateStatus();
  }

  void addWarning(String code) {
    if (!warnings.contains(code)) warnings.add(code);
    updateStatus();
  }

  void updateStatus() {
    if (errors.size() > 0) status = ValidationStatus.FAIL;
    else if (warnings.size() > 0) status = ValidationStatus.PASS_WITH_WARNINGS;
    else status = ValidationStatus.PASS;
  }

  boolean exportAllowed() { return status != ValidationStatus.FAIL; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("status", status.id());
    JSONArray errorValues = new JSONArray();
    for (int i = 0; i < errors.size(); i++) errorValues.setString(i, errors.get(i));
    JSONArray warningValues = new JSONArray();
    for (int i = 0; i < warnings.size(); i++) warningValues.setString(i, warnings.get(i));
    json.setJSONArray("errors", errorValues);
    json.setJSONArray("warnings", warningValues);
    json.setInt("total_samples", totalSamples);
    json.setInt("domain_inside_samples", domainInsideSamples);
    json.setInt("admitted_samples", admittedSamples);
    json.setInt("candidate_solid_samples", candidateSolidSamples);
    json.setInt("final_solid_samples", finalSolidSamples);
    json.setInt("outside_solid_samples", outsideSolidSamples);
    json.setInt("nonfinite_scalar_samples", nonFiniteScalarSamples);
    json.setInt("first_nonfinite_index", firstNonFiniteIndex);
    JSONArray firstPoint = new JSONArray();
    firstPoint.setFloat(0, firstNonFiniteX);
    firstPoint.setFloat(1, firstNonFiniteY);
    firstPoint.setFloat(2, firstNonFiniteZ);
    json.setJSONArray("first_nonfinite_world", firstPoint);
    json.setFloat("admitted_fraction", admittedFraction);
    json.setFloat("final_fraction_of_grid", finalFractionOfGrid);
    json.setFloat("final_fraction_of_domain", finalFractionOfDomain);
    json.setFloat("analytic_domain_volume", analyticDomainVolume);
    json.setFloat("sampled_domain_volume", sampledDomainVolume);
    json.setFloat("domain_volume_relative_error", domainVolumeRelativeError);
    json.setFloat("domain_volume_warning_threshold", domainVolumeWarningThreshold);
    json.setLong("domain_build_millis", domainBuildMillis);
    json.setLong("field_sample_millis", fieldSampleMillis);
    json.setLong("materialize_millis", materializeMillis);
    json.setLong("validation_millis", validationMillis);
    json.setLong("total_millis", totalMillis);
    return json;
  }
}

DCRTEValidationReport dcrteLastValidationReport = null;

DCRTEValidationReport validateDcrteConfiguration(ObservationDomain domain, UniformGridObserver observer, ObservationLayer observation) {
  DCRTEValidationReport report = new DCRTEValidationReport();
  VolumeSpec spec = observer == null ? null : observer.spec;
  if (spec == null || spec.bounds == null || !spec.bounds.isValid()) report.addError("INVALID_BOUNDS");
  if (spec == null || !spec.isValid() || !(spec.nx == 32 || spec.nx == 64 || spec.nx == 128)
      || spec.nx != spec.ny || spec.nx != spec.nz) report.addError("INVALID_RESOLUTION");
  if (domain == null || !domain.isValid()) report.addError("INVALID_DOMAIN_PARAMETERS");
  if (domain != null && spec != null && spec.bounds != null && !domain.bounds().overlaps(spec.bounds)) report.addError("NO_DOMAIN_OVERLAP");
  if (observation == null || !observation.isValid()) report.addError("INVALID_OBSERVATION_PARAMETERS");

  if (domain != null && spec != null && spec.bounds != null && domain.bounds().isValid()) {
    Bounds3D db = domain.bounds();
    Bounds3D ob = spec.bounds;
    if (db.minX < ob.minX || db.minY < ob.minY || db.minZ < ob.minZ
        || db.maxX > ob.maxX || db.maxY > ob.maxY || db.maxZ > ob.maxZ) {
      report.addWarning("DOMAIN_EXCEEDS_OBSERVER_BOUNDS");
    }
  }

  if (dcrteObservationMode == DCRTEObservationMode.SHELL_BAND && spec != null && spec.isValid()) {
    float shell = dcrteShellThickness(spec);
    if (!dcrteFinite(shell) || shell <= 0) report.addError("INVALID_OBSERVATION_PARAMETERS");
    if (shell < spec.minSpacing() * 1.5f) report.addWarning("SHELL_TOO_THIN");
    if (domain != null && shell > min(domain.bounds().sizeX(), min(domain.bounds().sizeY(), domain.bounds().sizeZ())) * 0.5f) {
      report.addWarning("SHELL_TOO_THICK");
    }
  }
  if (foundryRaisedVeins) report.addWarning("RAISED_VEINS_SUPPRESSED");
  report.updateStatus();
  return report;
}

void validateDcrteVolume(DCRTEValidationReport report, DCRTEVolume volume, ObservationDomain domain, boolean materializerSucceeded) {
  long start = millis();
  if (report == null) report = new DCRTEValidationReport();
  if (volume == null || !volume.isValid()) {
    report.addError("INVALID_VOLUME");
    report.validationMillis += millis() - start;
    dcrteLastValidationReport = report;
    return;
  }

  volume.recountFinal();
  report.totalSamples = volume.spec.voxelCount();
  report.domainInsideSamples = volume.domainInsideCount;
  report.admittedSamples = volume.admittedCount;
  report.candidateSolidSamples = volume.candidateSolidCount;
  report.finalSolidSamples = volume.finalSolidCount;
  report.outsideSolidSamples = volume.outsideSolidCount;
  report.nonFiniteScalarSamples = volume.nonFiniteScalarCount;
  report.firstNonFiniteIndex = volume.firstNonFiniteIndex;
  report.firstNonFiniteX = volume.firstNonFiniteX;
  report.firstNonFiniteY = volume.firstNonFiniteY;
  report.firstNonFiniteZ = volume.firstNonFiniteZ;
  report.admittedFraction = report.totalSamples > 0 ? report.admittedSamples / (float)report.totalSamples : 0;
  report.finalFractionOfGrid = report.totalSamples > 0 ? report.finalSolidSamples / (float)report.totalSamples : 0;
  report.finalFractionOfDomain = report.admittedSamples > 0 ? report.finalSolidSamples / (float)report.admittedSamples : 0;
  report.analyticDomainVolume = domain == null ? 0 : domain.analyticVolume();
  report.sampledDomainVolume = volume.domainInsideCount * volume.spec.sampleVolume();
  report.domainVolumeRelativeError = report.analyticDomainVolume > 0
    ? abs(report.sampledDomainVolume - report.analyticDomainVolume) / report.analyticDomainVolume
    : Float.POSITIVE_INFINITY;
  report.domainVolumeWarningThreshold = dcrteDomainVolumeWarningThreshold(domain);

  if (report.admittedSamples == 0) report.addError("EMPTY_ADMITTED_DOMAIN");
  if (report.finalSolidSamples == 0) report.addError("EMPTY_FINAL_VOLUME");
  if (report.admittedSamples > 0 && report.finalFractionOfDomain >= 0.999f) report.addWarning("FULL_FINAL_VOLUME");
  if (report.outsideSolidSamples > 0) report.addError("OUTSIDE_DOMAIN_MATERIAL");
  if (report.nonFiniteScalarSamples > 0) report.addError("NONFINITE_SCALAR");
  if (!materializerSucceeded) report.addError("LEGACY_ADAPTER_FAILURE");
  if (!dcrteFinite(report.domainVolumeRelativeError) || report.domainVolumeRelativeError > 0.25f) {
    report.addError("DOMAIN_VOLUME_ERROR_HIGH");
  } else if (report.domainVolumeRelativeError > report.domainVolumeWarningThreshold) {
    report.addWarning("DOMAIN_VOLUME_ERROR_HIGH");
  }
  if (dcrteObservationMode == DCRTEObservationMode.SHELL_BAND && report.admittedSamples == 0) report.addWarning("SHELL_EMPTY");
  report.validationMillis += millis() - start;
  report.updateStatus();
  dcrteLastValidationReport = report;
}

float dcrteDomainVolumeWarningThreshold(ObservationDomain domain) {
  if (domain != null && domain.getId().equals("box")) return 0.04f;
  return 0.08f;
}

void validateCurrentDcrtePrimitiveVolume() {
  if (dcrtePrimitiveVolume == null || dcrteLastDomain == null || dcrteLastObserver == null || dcrteLastObservation == null) {
    dcrteBuildStage = "NO VOLUME";
    return;
  }
  DCRTEValidationReport report = validateDcrteConfiguration(dcrteLastDomain, dcrteLastObserver, dcrteLastObservation);
  if (dcrteLastValidationReport != null) {
    report.domainBuildMillis = dcrteLastValidationReport.domainBuildMillis;
    report.fieldSampleMillis = dcrteLastValidationReport.fieldSampleMillis;
    report.materializeMillis = dcrteLastValidationReport.materializeMillis;
    report.totalMillis = dcrteLastValidationReport.totalMillis;
  }
  validateDcrteVolume(report, dcrtePrimitiveVolume, dcrteLastDomain, foundryMeshIsPrintable());
  dcrteBuildStage = report.exportAllowed() ? "READY" : "VALIDATION FAIL";
}

boolean dcrtePrimitiveExportAllowed() {
  return dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE
    || (dcrteLastValidationReport != null && dcrteLastValidationReport.exportAllowed() && !dcrtePrimitiveStale);
}
