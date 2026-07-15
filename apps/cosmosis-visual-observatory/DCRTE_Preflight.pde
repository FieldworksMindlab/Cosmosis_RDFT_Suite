/* DCRTE-ET Milestone 2.5 preflight orchestration and report lifecycle. */

DomainPreflightReport dcrteImportedPreflightReport = new DomainPreflightReport();
DomainPreflightReport dcrteImportedAttemptPreflightReport = null;
DCRTEPreflightMeshAnalyzer dcrtePreflightMeshAnalyzer = new DCRTEPreflightMeshAnalyzer();
DCRTEPreflightVolumeAnalyzer dcrtePreflightVolumeAnalyzer = new DCRTEPreflightVolumeAnalyzer();
boolean dcrtePreflightPanelOpen = false;
boolean dcrtePreflightShowBlockers = true;
boolean dcrtePreflightShowWarnings = true;
boolean dcrtePreflightShowInformation = false;
int dcrtePreflightIssueIndex = 0;
int dcrtePreflightOverlayMode = 0;
int dcrtePreflightInspectorTab = 0;
String dcrtePreflightLastReportPath = "";

void initializeDcrteMilestone25() {
  dcrteImportedPreflightReport = new DomainPreflightReport();
  dcrteImportedPreflightReport.selectedResolution = dcrteImportedResolution;
  dcrteImportedPreflightReport.setStage("FILE", DCRTEPreflightStageState.NOT_RUN,
    "no imported source is loaded", 0);
  dcrteImportedPreflightReport.qualification = DomainQualification.NOT_LOADED;
  dcrteImportedPreflightReport.refreshSummary();
}

DomainPreflightReport runDcrteImportedPreflight() {
  return runDcrteImportedPreflightWithDerived(!dcrteImportedSdfDirty,
    !dcrteImportedSdfDirty && !dcrteImportedStale);
}

DomainPreflightReport runDcrteImportedPreflightWithDerived(boolean includeDerived, boolean materialCurrent) {
  DomainPreflightReport report = dcrtePreflightMeshAnalyzer.analyze(
    dcrteImportedSourceMesh, dcrteImportedWorldMesh, dcrteImportedMeshReport,
    dcrteImportedTransform, dcrteImportedResolution, dcrteObserverBounds);
  report.sanitationPolicy = SanitationPolicy.SAFE_AUTOMATIC;
  if (dcrteImportedSourceIsFixture && dcrteImportedFixtureMetadata != null) {
    report.referenceCaseId = dcrteImportedFixtureMetadata.getString("fixture_id", "");
  }

  VoxelBoundaryVolume boundary = includeDerived ? dcrteImportedBoundary : null;
  InsideOutsideVolume insideOutside = includeDerived ? dcrteImportedInsideOutside : null;
  SignedDistanceVolume sdf = includeDerived ? dcrteImportedSdf : null;
  DCRTEVolume material = materialCurrent ? dcrteImportedVolume : null;
  DCRTEValidationReport validation = materialCurrent ? dcrteLastValidationReport : null;
  dcrtePreflightVolumeAnalyzer.attach(report, dcrteImportedWorldMesh, boundary,
    insideOutside, sdf, material, validation, materialCurrent, dcrteRawImportedExportReady());
  report.reportStale = false;
  dcrteImportedPreflightReport = report;
  dcrtePreflightClampIssueIndex();
  return report;
}

void markDcrtePreflightStale() {
  if (dcrteImportedPreflightReport != null) dcrteImportedPreflightReport.reportStale = true;
}

boolean dcrtePreflightAllowsSdfBuild() {
  if (dcrteImportedPolicy == InvalidDomainPolicy.UNSIGNED_PREVIEW) return true;
  if (dcrteImportedPreflightReport == null || dcrteImportedPreflightReport.reportStale) {
    runDcrteImportedPreflight();
  }
  return dcrteImportedPreflightReport != null && dcrteImportedPreflightReport.sdfBuildEnabled;
}

boolean dcrtePreflightAllowsMaterialization() {
  if (dcrteImportedPreflightReport == null || dcrteImportedPreflightReport.reportStale) {
    runDcrteImportedPreflight();
  }
  return dcrteImportedPreflightReport != null && dcrteImportedPreflightReport.materializationEnabled;
}

boolean dcrteRawImportedExportReady() {
  return !dcrteImportedStale && !dcrteImportedSdfDirty
    && dcrteImportedDomain != null && dcrteImportedDomain.isValid()
    && dcrteImportedVolume != null && dcrteImportedVolume.isValid()
    && dcrteLastValidationReport != null && dcrteLastValidationReport.exportAllowed()
    && foundryMesh != null && foundryMeshIsPrintable() && !foundryMeshStale;
}

DomainPreflightReport createDcrteParseFailurePreflight(File file, String legacyCode, String message) {
  DomainPreflightReport report = new DomainPreflightReport();
  report.sourceName = file == null ? "" : file.getName();
  report.selectedResolution = dcrteImportedResolution;
  report.qualification = DomainQualification.PARSE_FAILED;
  report.previewEnabled = false;
  report.sdfBuildEnabled = false;
  report.materializationEnabled = false;
  report.exportEnabled = false;
  report.setStage("FILE", file != null && file.exists() ? DCRTEPreflightStageState.PASS : DCRTEPreflightStageState.BLOCKED,
    file != null && file.exists() ? "source selected" : "source is unavailable", 0);
  report.setStage("PARSE", DCRTEPreflightStageState.BLOCKED, message == null ? "parse failed" : message, 0);
  String code = dcrtePreflightParseCode(legacyCode, file);
  String title = code.equals(DCRTEPreflightCodes.PF_FILE_NOT_FOUND) ? "File not found"
    : code.equals(DCRTEPreflightCodes.PF_FILE_EMPTY) ? "Empty source file"
    : code.equals(DCRTEPreflightCodes.PF_BINARY_LENGTH_MISMATCH) ? "Binary STL length mismatch"
    : code.equals(DCRTEPreflightCodes.PF_ASCII_PARSE_INCOMPLETE) ? "ASCII STL parse incomplete"
    : "Mesh parse failed";
  report.addDiagnostic(new DomainDiagnostic(code, DiagnosticSeverity.BLOCKER,
    code.startsWith("PF_FILE") ? "FILE" : "PARSE", title,
    message == null ? "The source could not be parsed as a supported triangle mesh." : message,
    DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT));
  dcrteSkipPreflightStagesAfter(report, "PARSE", "parse did not produce a mesh");
  report.refreshSummary();
  return report;
}

String dcrtePreflightParseCode(String legacyCode, File file) {
  String code = legacyCode == null ? "" : legacyCode.toUpperCase();
  if (file == null || !file.exists()) return DCRTEPreflightCodes.PF_FILE_NOT_FOUND;
  if (file.length() == 0) return DCRTEPreflightCodes.PF_FILE_EMPTY;
  if (code.indexOf("UNREADABLE") >= 0) return DCRTEPreflightCodes.PF_FILE_UNREADABLE;
  if (code.indexOf("UNSUPPORTED") >= 0 || code.indexOf("EXTENSION") >= 0) return DCRTEPreflightCodes.PF_FORMAT_UNSUPPORTED;
  if (code.indexOf("AMBIG") >= 0) return DCRTEPreflightCodes.PF_STL_FORMAT_AMBIGUOUS;
  if (code.indexOf("LENGTH") >= 0 || code.indexOf("TRUNC") >= 0) return DCRTEPreflightCodes.PF_BINARY_LENGTH_MISMATCH;
  if (code.indexOf("ASCII") >= 0) return DCRTEPreflightCodes.PF_ASCII_PARSE_INCOMPLETE;
  if (code.indexOf("LIMIT") >= 0) return DCRTEPreflightCodes.PF_TRIANGLE_LIMIT_EXCEEDED;
  if (code.indexOf("NONFINITE") >= 0) return DCRTEPreflightCodes.PF_SOURCE_COORDINATE_NONFINITE;
  return DCRTEPreflightCodes.PF_FORMAT_UNSUPPORTED;
}

ArrayList<DomainDiagnostic> dcrteVisiblePreflightIssues() {
  ArrayList<DomainDiagnostic> visible = new ArrayList<DomainDiagnostic>();
  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  if (report == null) return visible;
  for (int i = 0; i < report.diagnostics.size(); i++) {
    DomainDiagnostic diagnostic = report.diagnostics.get(i);
    if (diagnostic.severity == DiagnosticSeverity.BLOCKER && dcrtePreflightShowBlockers) visible.add(diagnostic);
    else if (diagnostic.severity == DiagnosticSeverity.WARNING && dcrtePreflightShowWarnings) visible.add(diagnostic);
    else if (diagnostic.severity == DiagnosticSeverity.INFO && dcrtePreflightShowInformation) visible.add(diagnostic);
  }
  return visible;
}

DomainPreflightReport dcrteDisplayedPreflightReport() {
  if (dcrteImportedAttemptPreflightReport != null
      && dcrteImportedAttemptPreflightReport.qualification == DomainQualification.PARSE_FAILED) {
    return dcrteImportedAttemptPreflightReport;
  }
  return dcrteImportedPreflightReport;
}

void dcrtePreflightClampIssueIndex() {
  int count = dcrteVisiblePreflightIssues().size();
  dcrtePreflightIssueIndex = count == 0 ? 0 : constrain(dcrtePreflightIssueIndex, 0, count - 1);
}

void stepDcrtePreflightIssue(int direction) {
  int count = dcrteVisiblePreflightIssues().size();
  if (count == 0) { dcrtePreflightIssueIndex = 0; return; }
  dcrtePreflightIssueIndex = (dcrtePreflightIssueIndex + direction + count) % count;
}

void useDcrteUnsignedPreview() {
  if (dcrteImportedPolicy != InvalidDomainPolicy.UNSIGNED_PREVIEW) cycleDcrteImportedPolicy();
  dcrtePreflightPanelOpen = true;
  runDcrteImportedPreflight();
}

void exportDcrtePreflightReportJSON() {
  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  if (report == null) return;
  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_"
    + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  String path = "logs/dcrte_preflight_reports/dcrte_preflight_" + stamp + ".json";
  saveJSONObject(report.toJSON(), path);
  dcrtePreflightLastReportPath = path;
  dcrteImportedStatus = "preflight report exported: " + path;
}

void copyDcrtePreflightSummary() {
  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  if (report == null) return;
  try {
    java.awt.datatransfer.StringSelection selection =
      new java.awt.datatransfer.StringSelection(report.conciseSummary());
    java.awt.Toolkit.getDefaultToolkit().getSystemClipboard().setContents(selection, selection);
    dcrteImportedStatus = "preflight summary copied";
  }
  catch (Exception error) {
    dcrteImportedStatus = "clipboard unavailable; export report JSON instead";
  }
}
