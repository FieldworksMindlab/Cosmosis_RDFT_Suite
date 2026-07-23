/* Guided, validation-preserving recovery for the imported-domain workflow. */

String dcrteWorkflowStateLabel(DomainPreflightReport report) {
  if (dcrteImportedSourceMesh == null || report == null || report.qualification == DomainQualification.NOT_LOADED) return "ACTION REQUIRED";
  if (report.status == ValidationStatus.FAIL) return "BLOCKED";
  if (dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL) {
    if (dcrteIntrinsicClosedLoopBlocked()) return "ROUTE AVAILABLE";
    if (!dcrteIntrinsicStateCurrent()) return "ACTION REQUIRED";
  }
  if (dcrteCompositionAuthoritative && (dcrteCompositionStale
      || dcrteCompositionStage == M6CompositionStage.BLOCKED
      || dcrteCompositionValidation != null && !dcrteCompositionValidation.valid())) return "BLOCKED";
  if (report.exportEnabled) return report.status == ValidationStatus.PASS_WITH_WARNINGS ? "READY WITH WARNINGS" : "READY";
  return "ACTION REQUIRED";
}

String dcrteWorkflowNextAction(DomainPreflightReport report) {
  if (dcrteImportedSourceMesh == null) return "Load a closed STL, egg, or torus domain.";
  if (report == null || report.reportStale) return "Run preflight to refresh the domain qualification.";
  if (report.status == ValidationStatus.FAIL) {
    return report.recommendedNextAction == null || report.recommendedNextAction.length() == 0
      ? "Review the first blocker in the Issues tab." : report.recommendedNextAction;
  }
  if (dcrteCompositionAuthoritative) {
    if (dcrteCompositionStale) return "Open Composition and rebuild the current M6 layer.";
    if (dcrteCompositionStage == M6CompositionStage.BLOCKED
        || dcrteCompositionValidation != null && !dcrteCompositionValidation.valid()) {
      return "Open Composition and resolve its first validation blocker.";
    }
    if (dcrteCompositionVolume == null) return "Open Composition and compose the current scheduler state.";
    if (!dcrteCompositionMaterialized) return "Open Composition and materialize the validated composition.";
  }
  if (dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL) {
    if (dcrteIntrinsicClosedLoopBlocked()) return "Closed loop detected: route fabrication through Cartesian coordinates.";
    if (!dcrteIntrinsicStateCurrent()) return "Build the axial intrinsic chart, or use Find Path for a safe alternate route.";
  }
  if (dcrteImportedSdfDirty || dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) return "Build the signed-distance volume.";
  if (report.materializationEnabled && !report.exportEnabled) return "Generate and validate the material mesh.";
  if (!report.exportEnabled) return "Run the next qualified pipeline stage.";
  return "The domain is ready for fabrication export.";
}

String dcrteWorkflowActionLabel(String action) {
  if (action == null || action.length() == 0) return "";
  if (action.equals(DCRTEPreflightActions.ACTION_BUILD_SDF)) return "Build the signed-distance volume.";
  if (action.equals(DCRTEPreflightActions.ACTION_GENERATE_MATERIAL)) return "Generate and validate the material mesh.";
  if (action.equals(DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION)) return "Increase SDF resolution if finer feature confidence is needed.";
  return action.replace('_', ' ').toLowerCase();
}

void dcrteRouteClosedLoopToCartesian() {
  dcrteCoordinateMode = DCRTECoordinateMode.CARTESIAN;
  dcrteCoordinateComparisonMode = CoordinateComparisonMode.SINGLE;
  dcrteIntrinsicBuildStatus = "AXIAL UNSUITABLE - CLOSED LOOP / CARTESIAN ACTIVE";
  markDcrteImportedMaterialStale("closed-loop domain routed through Cartesian coordinates");
  dcrteImportedStatus = "closed loop cannot use one axial chart; Cartesian fabrication path active";
  foundryStatus = dcrteImportedStatus;
}

void dcrteFindSafePath() {
  if (dcrteImportedSourceMesh == null) {
    dcrteImportedStatus = "choose a closed STL, egg, or torus to begin";
    selectDcrteImportedStl();
    return;
  }

  DomainPreflightReport report = dcrteImportedPreflightReport;
  if (report == null || report.reportStale) report = runDcrteImportedPreflight();
  if (report == null) {
    dcrteImportedStatus = "preflight unavailable; current source retained";
    return;
  }
  if (report.status == ValidationStatus.FAIL) {
    dcrtePreflightPanelOpen = true;
    dcrtePreflightInspectorTab = 2;
    dcrteImportedStatus = "find path stopped at hard blocker: "
      + (report.firstBlockingCode.length() == 0 ? "open Issues" : report.firstBlockingCode);
    return;
  }

  if (dcrteImportedSdfDirty || dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) {
    requestDcrteImportedSdfBuild();
    if (dcrteImportedSdfDirty || dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) {
      dcrtePreflightPanelOpen = true;
      dcrtePreflightInspectorTab = 3;
      return;
    }
    report = dcrteImportedPreflightReport;
  }

  if (dcrteCompositionAuthoritative && (dcrteCompositionStale
      || dcrteCompositionStage == M6CompositionStage.BLOCKED
      || dcrteCompositionVolume == null || !dcrteCompositionMaterialized)) {
    dcrtePreflightPanelOpen = true;
    dcrtePreflightInspectorTab = 5;
    dcrteImportedStatus = dcrteWorkflowNextAction(report);
    return;
  }

  boolean intrinsicRequired = dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL
    || dcrteCoordinateComparisonMode == CoordinateComparisonMode.CARTESIAN_AND_INTRINSIC;
  if (intrinsicRequired && !dcrteIntrinsicStateCurrent()) {
    if (!buildDcrteImportedIntrinsicCoordinates()) {
      if (dcrteIntrinsicClosedLoopBlocked()) {
        dcrteRouteClosedLoopToCartesian();
      } else {
        dcrtePreflightPanelOpen = true;
        dcrtePreflightInspectorTab = 4;
        dcrteImportedStatus = "find path needs intrinsic review: " + dcrteIntrinsicBuildStatus;
        return;
      }
    }
  }

  generateDcrteImportedSurfaceMesh();
  if (dcrteImportedPreflightReport != null && dcrteImportedPreflightReport.exportEnabled) {
    dcrteImportedStatus = "find path complete; validated material is export ready";
    foundryStatus = dcrteImportedStatus;
  } else if (dcrteImportedPreflightReport != null && dcrteImportedPreflightReport.status == ValidationStatus.FAIL) {
    dcrtePreflightPanelOpen = true;
    dcrtePreflightInspectorTab = 2;
  }
}
