/* DCRTE-ET Milestone 2.5 voxel, sign, SDF, and fabrication diagnostics. */

class DCRTEPreflightVolumeAnalyzer {
  void attach(DomainPreflightReport report, TriangleMeshData worldMesh, VoxelBoundaryVolume boundary,
      InsideOutsideVolume classification, SignedDistanceVolume sdf, DCRTEVolume materialVolume,
      DCRTEValidationReport materializationReport, boolean materialIsCurrent, boolean rawExportReady) {
    if (report == null) return;
    long totalStart = millis();

    if (boundary == null) {
      finishWithoutBoundary(report);
      report.totalMillis += millis() - totalStart;
      return;
    }

    long stageStart = millis();
    attachBoundaryDiagnostics(report, boundary);
    if (report.resolutionSuitability != null && worldMesh != null) {
      ResolutionSuitability updated = new DCRTEPreflightMeshAnalyzer().inspectResolution(worldMesh,
        report.selectedResolution, boundary.spec.bounds, boundary);
      report.resolutionSuitability = updated;
      report.sdfResolutionConfidence = updated.estimatedConfidence;
    }
    completeStage(report, "BOUNDARY_VOXELIZATION", stageStart, "boundary coverage and grid contact inspected");

    if (report.hasBlockerAtOrBefore("SELF_INTERSECTION")) {
      report.setStage("INSIDE_OUTSIDE", DCRTEPreflightStageState.SKIPPED, "topology is not a reliable signed boundary", 0);
      report.setStage("SIGNED_DISTANCE", sdf == null ? DCRTEPreflightStageState.SKIPPED : DCRTEPreflightStageState.WARNING,
        sdf == null ? "not run due to topology blocker" : "unsigned preview distance only", 0);
      report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "signed materialization is disabled", 0);
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "topology blocker cannot be acknowledged away", 0);
      report.qualification = DomainQualification.TOPOLOGY_INVALID;
      report.materializationEnabled = false;
      report.exportEnabled = false;
      report.refreshSummary();
      report.totalMillis += millis() - totalStart;
      return;
    }

    if (classification == null) {
      report.setStage("INSIDE_OUTSIDE", DCRTEPreflightStageState.SKIPPED,
        "unsigned preview does not make inside/outside claims", 0);
      report.setStage("SIGNED_DISTANCE", sdf == null ? DCRTEPreflightStageState.NOT_RUN : DCRTEPreflightStageState.WARNING,
        sdf == null ? "signed distance has not been built" : "unsigned preview distance only", 0);
      report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "signed materialization requires strict policy", 0);
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "unsigned preview cannot be exported as trusted material", 0);
      report.qualification = DomainQualification.PREVIEW_ONLY;
      report.materializationEnabled = false;
      report.exportEnabled = false;
      report.refreshSummary();
      report.totalMillis += millis() - totalStart;
      return;
    }

    stageStart = millis();
    report.insideOutsideVerification = verifyInsideOutside(worldMesh, boundary, classification);
    attachInsideOutsideDiagnostics(report, boundary, classification, report.insideOutsideVerification);
    report.insideMaskComponentCount = report.insideOutsideVerification.insideComponentCount;
    report.insideMaskDominantFraction = report.insideOutsideVerification.largestInsideComponentFraction;
    completeStage(report, "INSIDE_OUTSIDE", stageStart, "X parity, Y parity, exterior flood fill, and connectivity compared");

    if (sdf == null) {
      report.setStage("SIGNED_DISTANCE", DCRTEPreflightStageState.NOT_RUN,
        report.hasBlockerAtOrBefore("INSIDE_OUTSIDE") ? "not run due to inside/outside blocker" : "distance transform has not completed", 0);
      report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "trusted signed distance is not available", 0);
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "materialization has not passed", 0);
      report.qualification = DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED;
      report.materializationEnabled = false;
      report.exportEnabled = false;
      report.refreshSummary();
      report.totalMillis += millis() - totalStart;
      return;
    }

    stageStart = millis();
    report.sdfReport = sdf.quality;
    attachSdfDiagnostics(report, sdf, classification);
    completeStage(report, "SIGNED_DISTANCE", stageStart, "finite values, sign, zero band, volume, gradient, and grid agreement inspected");
    boolean sdfTrusted = sdf.signed && sdf.isValid() && sdf.quality != null && sdf.quality.isValid()
      && !report.hasBlockerAtOrBefore("SIGNED_DISTANCE");
    report.materializationEnabled = sdfTrusted;
    report.sdfBuildEnabled = !report.hasBlockerAtOrBefore("RESOLUTION");
    if (!sdfTrusted) {
      report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "signed-distance qualification is unresolved", 0);
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "signed-distance qualification is unresolved", 0);
      report.qualification = DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED;
      report.exportEnabled = false;
      report.refreshSummary();
      report.totalMillis += millis() - totalStart;
      return;
    }

    if (!materialIsCurrent || materialVolume == null || materializationReport == null) {
      report.setStage("MATERIALIZATION", DCRTEPreflightStageState.NOT_RUN, "SDF is qualified; generate material to continue", 0);
      report.setStage("EXPORT", DCRTEPreflightStageState.NOT_RUN, "awaiting validated materialization", 0);
      report.qualification = DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED;
      report.exportEnabled = false;
      report.refreshSummary();
      report.totalMillis += millis() - totalStart;
      return;
    }

    stageStart = millis();
    report.materializationReport = materializationReport;
    attachMaterializationDiagnostics(report, materialVolume, materializationReport);
    completeStage(report, "MATERIALIZATION", stageStart, "field and final fabricated volume inspected");
    boolean materialReady = materializationReport.status != ValidationStatus.FAIL
      && materialVolume.finalSolidCount > 0 && materializationReport.outsideSolidSamples == 0
      && !report.hasBlockerAtOrBefore("MATERIALIZATION");
    if (!materialReady) {
      report.qualification = DomainQualification.SDF_VALID_MATERIALIZATION_BLOCKED;
      report.exportEnabled = false;
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "materialization diagnostics contain a blocker", 0);
      if (!report.hasDiagnostic(DCRTEPreflightCodes.PF_EXPORT_DISABLED)) {
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_EXPORT_DISABLED, DiagnosticSeverity.BLOCKER,
          "EXPORT", "Export disabled", "Fabrication output did not pass all materialization gates.",
          DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD));
      }
    } else if (rawExportReady) {
      report.qualification = DomainQualification.MATERIALIZATION_READY;
      report.exportEnabled = true;
      report.setStage("EXPORT", DCRTEPreflightStageState.PASS, "strict mesh, SDF, materialization, and printable mesh gates passed", 0);
    } else {
      report.qualification = DomainQualification.SDF_VALID_MATERIALIZATION_BLOCKED;
      report.exportEnabled = false;
      report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "legacy printable/export gate remains disabled", 0);
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_EXPORT_DISABLED, DiagnosticSeverity.BLOCKER,
        "EXPORT", "Export disabled", "The existing printable-mesh or stale-state export gate remains closed.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
    }
    report.refreshSummary();
    report.totalMillis += millis() - totalStart;
  }

  void finishWithoutBoundary(DomainPreflightReport report) {
    boolean canBuild = !report.hasBlockerAtOrBefore("RESOLUTION");
    report.sdfBuildEnabled = canBuild;
    report.materializationEnabled = false;
    report.exportEnabled = false;
    if (report.hasBlockerAtOrBefore("SELF_INTERSECTION")) report.qualification = DomainQualification.TOPOLOGY_INVALID;
    else report.qualification = DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED;
    String reason = canBuild ? "not run; use REBUILD SDF" : "skipped due to earlier blocker";
    report.setStage("BOUNDARY_VOXELIZATION", canBuild ? DCRTEPreflightStageState.NOT_RUN : DCRTEPreflightStageState.SKIPPED, reason, 0);
    report.setStage("INSIDE_OUTSIDE", DCRTEPreflightStageState.SKIPPED, reason, 0);
    report.setStage("SIGNED_DISTANCE", DCRTEPreflightStageState.SKIPPED, reason, 0);
    report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "trusted SDF is not available", 0);
    report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "validated materialization is required", 0);
    report.refreshSummary();
  }

  void attachBoundaryDiagnostics(DomainPreflightReport report, VoxelBoundaryVolume boundary) {
    if (boundary.boundaryCount == 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_VOXELIZATION_EMPTY,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Empty boundary voxelization",
        "No grid cells were marked as surface boundary.", DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION));
    }
    if (boundary.trianglesWithZeroCandidates > 0 || boundary.trianglesWithNoMarkedVoxels > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRIANGLE_MARKED_NO_VOXELS,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Triangles without boundary voxels",
        "At least one source triangle has no verified boundary coverage at the selected resolution.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION)
        .withCount(max(boundary.trianglesWithZeroCandidates, boundary.trianglesWithNoMarkedVoxels)));
    }
    if (boundary.outOfBoundsTriangles > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_TOUCHES_GRID_EDGE,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Boundary outside grid fit",
        "Triangle boundary candidates extend beyond the observer bounds.",
        DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN).withCount(boundary.outOfBoundsTriangles));
    }
    int edgeTouches = dcrteCountBoundaryGridEdgeVoxels(boundary);
    if (edgeTouches > 0) {
      int edgeVoxelCount = dcrteGridEdgeVoxelCount(boundary.spec);
      boolean saturated = edgeVoxelCount > 0 && edgeTouches >= max(1, edgeVoxelCount - 8);
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_TOUCHES_GRID_EDGE,
        saturated ? DiagnosticSeverity.BLOCKER : DiagnosticSeverity.WARNING, "BOUNDARY_VOXELIZATION",
        saturated ? "Boundary saturates grid edge" : "Conservative boundary band reaches grid edge",
        saturated
          ? "The boundary band leaves no reliable exterior path at the build-volume edge."
          : "Some conservative boundary cells reach the grid edge, but unsaturated edge cells remain for exterior verification.",
        DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN).withCount(edgeTouches)
        .withValue(edgeVoxelCount > 0 ? edgeTouches / (float)edgeVoxelCount : 1, 1.0f));
    }
    float fraction = boundary.boundary.length > 0 ? boundary.boundaryCount / (float)boundary.boundary.length : 0;
    if (fraction > 0.35f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_THICKNESS_EXCESSIVE,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Boundary band consumes excessive grid volume",
        "The conservative surface band is too thick relative to the selected grid.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(fraction, 0.35f));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_VOXEL_COUNT_IMPLAUSIBLE,
        DiagnosticSeverity.WARNING, "BOUNDARY_VOXELIZATION", "Implausible boundary voxel fraction",
        "Boundary occupancy is unusually high for a surface representation.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(fraction, 0.35f));
    }
    int boundaryComponents = dcrteCountBooleanComponents(boundary.boundary, boundary.spec, true, null);
    if (boundaryComponents > max(1, report.componentCount)) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_FRAGMENTED,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Boundary voxelization fragmented",
        "The grid boundary has more connected pieces than the source surface.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withCount(boundaryComponents));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_COMPONENT_MISMATCH,
        DiagnosticSeverity.BLOCKER, "BOUNDARY_VOXELIZATION", "Boundary component mismatch",
        "Source and voxel boundary component counts do not agree.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(boundaryComponents, report.componentCount));
    }
  }

  int dcrteGridEdgeVoxelCount(VolumeSpec spec) {
    if (spec == null || !spec.isValid()) return 0;
    int total = spec.voxelCount();
    int innerX = max(0, spec.nx - 2);
    int innerY = max(0, spec.ny - 2);
    int innerZ = max(0, spec.nz - 2);
    return total - innerX * innerY * innerZ;
  }

  InsideOutsideVerification verifyInsideOutside(TriangleMeshData mesh, VoxelBoundaryVolume boundary,
      InsideOutsideVolume classification) {
    long start = millis();
    InsideOutsideVerification result = new InsideOutsideVerification();
    VolumeSpec spec = boundary.spec;
    result.parityInsideCount = classification.insideCount;
    boolean[] exterior = dcrteFloodExterior(boundary);
    boolean[] floodInside = new boolean[exterior.length];
    boolean[] disagreements = new boolean[exterior.length];
    IntArrayBuilder examples = new IntArrayBuilder(256);
    for (int i = 0; i < exterior.length; i++) {
      if (exterior[i]) result.floodFillExteriorCount++;
      floodInside[i] = !exterior[i];
      if (floodInside[i]) result.floodFillInsideCount++;
      if (boundary.boundary[i] || dcrteVoxelTouchesBoundary(i, boundary)) continue;
      if (classification.inside[i] != floodInside[i]) {
        disagreements[i] = true;
        result.disagreementVoxelCount++;
        if (examples.size < 4096) examples.add(i);
      }
    }
    result.disagreementVoxelIndices = examples.toArray();
    int[] largestDisagreement = new int[1];
    dcrteCountBooleanComponents(disagreements, spec, false, largestDisagreement);
    result.largestDisagreementComponent = largestDisagreement[0];
    int[] largestInside = new int[1];
    result.insideComponentCount = dcrteCountBooleanComponents(classification.inside, spec, false, largestInside);
    result.largestInsideComponent = largestInside[0];
    result.largestInsideComponentFraction = classification.insideCount > 0
      ? largestInside[0] / (float)classification.insideCount : 0;
    result.boundaryComponentCount = dcrteCountBooleanComponents(boundary.boundary, spec, true, null);

    DCRTEAxisParityVolume yParity = dcrteClassifyYParity(mesh, boundary);
    IntArrayBuilder crossExamples = new IntArrayBuilder(256);
    for (int i = 0; i < yParity.checked.length; i++) {
      if (!yParity.checked[i] || boundary.boundary[i] || dcrteVoxelTouchesBoundary(i, boundary)) continue;
      result.crossAxisCheckedVoxelCount++;
      if (yParity.inside[i] != classification.inside[i]) {
        result.crossAxisDisagreementCount++;
        if (crossExamples.size < 4096) crossExamples.add(i);
      }
    }
    result.crossAxisDisagreementVoxelIndices = crossExamples.toArray();
    result.elapsedMillis = millis() - start;
    return result;
  }

  void attachInsideOutsideDiagnostics(DomainPreflightReport report, VoxelBoundaryVolume boundary,
      InsideOutsideVolume classification, InsideOutsideVerification verification) {
    if (classification.ambiguousScanlineCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_PARITY_RETRY_REQUIRED,
        DiagnosticSeverity.WARNING, "INSIDE_OUTSIDE", "Parity jitter retry required",
        "Some X scanlines required deterministic sub-voxel jitter to avoid vertex or edge ambiguity.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withCount(classification.ambiguousScanlineCount));
    }
    if (classification.failedScanlineCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_PARITY_RETRY_FAILED,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Parity retry failed",
        "One or more scanlines retained an odd or unresolved intersection count.",
        DCRTEPreflightActions.ACTION_INSPECT_SELF_INTERSECTIONS).withCount(classification.failedScanlineCount));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_PARITY_ODD_INTERSECTION_COUNT,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Odd parity intersection count",
        "A closed consistently oriented boundary should resolve to even complete scanline crossings.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT).withCount(classification.failedScanlineCount));
    }
    if (classification.insideCount == 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INSIDE_MASK_EMPTY,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Inside mask empty",
        "No interior voxels were classified.", DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION));
    }
    if (classification.insideCount >= classification.inside.length) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INSIDE_MASK_FULL,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Inside mask full",
        "No exterior region remains in the observer volume.", DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN));
    }
    int floodTolerance = max(4, (int)(classification.inside.length * 0.001f));
    if (verification.disagreementVoxelCount > floodTolerance) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_INTERIOR_LEAK,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Parity and flood-fill disagreement",
        "Exterior flood fill disagrees with parity above the configured tolerance.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(verification.disagreementVoxelCount, floodTolerance);
      if (verification.disagreementVoxelIndices.length > 0) locateVoxelDiagnostic(diagnostic, boundary.spec, verification.disagreementVoxelIndices[0]);
      report.addDiagnostic(diagnostic);
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_AMBIGUOUS_VOXELS,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Ambiguous inside/outside voxels",
        "A connected disagreement region remains after independent sign checks.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withCount(verification.disagreementVoxelCount));
    }
    int axisTolerance = max(4, (int)(verification.crossAxisCheckedVoxelCount * 0.002f));
    if (verification.crossAxisDisagreementCount > axisTolerance) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_PARITY_INCONSISTENT_AXIS,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Cross-axis parity disagreement",
        "Independent X and Y parity classification disagree above tolerance.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(verification.crossAxisDisagreementCount, axisTolerance);
      if (verification.crossAxisDisagreementVoxelIndices.length > 0) locateVoxelDiagnostic(diagnostic, boundary.spec, verification.crossAxisDisagreementVoxelIndices[0]);
      report.addDiagnostic(diagnostic);
    }
    if (verification.insideComponentCount != max(1, report.closedComponentCount)) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INSIDE_COMPONENT_MISMATCH,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Inside component mismatch",
        "Voxel interior connectivity does not agree with the qualified source shell count.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(verification.insideComponentCount, max(1, report.closedComponentCount)));
    }
    if (report.singleDominantClosedComponent && verification.largestInsideComponentFraction < 0.98f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SIGN_ISLAND,
        DiagnosticSeverity.BLOCKER, "INSIDE_OUTSIDE", "Interior sign islands",
        "The dominant interior component occupies less than 98 percent of inside voxels.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(verification.largestInsideComponentFraction, 0.98f));
    }
  }

  void attachSdfDiagnostics(DomainPreflightReport report, SignedDistanceVolume sdf, InsideOutsideVolume classification) {
    if (!sdf.isValid() || sdf.nonFiniteCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_NONFINITE,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "Non-finite SDF samples",
        "The signed-distance grid contains NaN or infinite values.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE).withCount(sdf.nonFiniteCount));
    }
    if (sdf.zeroBandCount == 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_ZERO_BAND_EMPTY,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "Empty SDF zero band",
        "No samples occur near the reconstructed boundary.", DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION));
    }
    float zeroFraction = sdf.signedDistance.length > 0 ? sdf.zeroBandCount / (float)sdf.signedDistance.length : 0;
    if (zeroFraction > 0.35f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_ZERO_BAND_EXCESSIVE,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "Excessive SDF zero band",
        "The near-surface band consumes too much of the grid.", DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION)
        .withValue(zeroFraction, 0.35f));
    }
    int signConflicts = 0;
    int firstConflict = -1;
    for (int i = 0; i < sdf.signedDistance.length; i++) {
      if (sdf.boundary[i]) continue;
      boolean expectedInside = classification.inside[i];
      if ((expectedInside && sdf.signedDistance[i] >= 0) || (!expectedInside && sdf.signedDistance[i] <= 0)) {
        signConflicts++;
        if (firstConflict < 0) firstConflict = i;
      }
    }
    if (signConflicts > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_SIGN_CONFLICT,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "SDF sign conflict",
        "Distance signs do not agree with the independently classified interior.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE).withCount(signConflicts);
      locateVoxelDiagnostic(diagnostic, sdf.spec, firstConflict);
      report.addDiagnostic(diagnostic);
    }
    if (sdf.quality != null && (!Double.isFinite(sdf.quality.volumeRelativeError) || sdf.quality.volumeRelativeError > 0.35)) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_VOLUME_ERROR_HIGH,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "SDF volume error high",
        "Sampled interior volume differs from signed mesh volume by more than 35 percent.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue((float)sdf.quality.volumeRelativeError, 0.35f));
    } else if (sdf.quality != null && sdf.quality.volumeRelativeError > (report.selectedResolution >= 128 ? 0.07 : 0.12)) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_VOLUME_ERROR_HIGH,
        DiagnosticSeverity.WARNING, "SIGNED_DISTANCE", "SDF volume convergence warning",
        "Sampled volume exceeds the resolution-specific warning threshold.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue((float)sdf.quality.volumeRelativeError,
        report.selectedResolution >= 128 ? 0.07f : 0.12f));
    }
    if (classification.spec.nx != sdf.spec.nx || classification.spec.ny != sdf.spec.ny || classification.spec.nz != sdf.spec.nz) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_GRID_MISMATCH,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "SDF grid mismatch",
        "Inside/outside and distance volumes do not share an explicit grid.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
    }
    int[] gradient = inspectSdfGradient(sdf);
    if (gradient[0] > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_GRADIENT_INVALID,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "Invalid near-boundary gradient",
        "Near-boundary exterior samples include zero or non-finite SDF gradients.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withCount(gradient[0]));
    }
    int gradientTolerance = max(4, gradient[2] / 20);
    if (gradient[1] > gradientTolerance) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SDF_GRADIENT_DIRECTION_CONFLICT,
        DiagnosticSeverity.BLOCKER, "SIGNED_DISTANCE", "SDF gradient direction conflict",
        "Near-boundary gradients do not generally point from the boundary toward exterior samples.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(gradient[1], gradientTolerance));
    }
  }

  void attachMaterializationDiagnostics(DomainPreflightReport report, DCRTEVolume volume, DCRTEValidationReport validation) {
    if (volume.nonFiniteScalarCount > 0 || validation.nonFiniteScalarSamples > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_FIELD_NONFINITE,
        DiagnosticSeverity.BLOCKER, "MATERIALIZATION", "Non-finite field samples",
        "The recursive field produced non-finite values inside the observation grid.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD).withCount(max(volume.nonFiniteScalarCount, validation.nonFiniteScalarSamples));
      if (volume.firstNonFiniteIndex >= 0) diagnostic.withVoxel(volume.firstNonFiniteIndex)
        .at(volume.firstNonFiniteX, volume.firstNonFiniteY, volume.firstNonFiniteZ);
      report.addDiagnostic(diagnostic);
    }
    if (volume.finalSolidCount == 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FINAL_VOLUME_EMPTY,
        DiagnosticSeverity.BLOCKER, "MATERIALIZATION", "Final material volume empty",
        "No fabricated voxels survived the field and observation rules.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD));
    }
    if (volume.admittedCount > 0 && volume.finalSolidCount >= volume.admittedCount) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FINAL_VOLUME_FULL,
        DiagnosticSeverity.WARNING, "MATERIALIZATION", "Final material fills admitted domain",
        "Field differentiation is minimal because nearly every admitted voxel became material.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD));
    }
    if (validation.outsideSolidSamples > 0 || volume.outsideSolidCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_OUTSIDE_DOMAIN_MATERIAL,
        DiagnosticSeverity.BLOCKER, "MATERIALIZATION", "Material outside trusted domain",
        "Final material escaped the qualified observation domain.",
        DCRTEPreflightActions.ACTION_DISABLE_RAISED_VEINS).withCount(max(validation.outsideSolidSamples, volume.outsideSolidCount)));
    }
    int[] largest = new int[1];
    int finalComponents = dcrteCountBooleanComponents(volume.finalSolid, volume.spec, false, largest);
    if (finalComponents > 64) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FINAL_COMPONENTS_EXCESSIVE,
        DiagnosticSeverity.BLOCKER, "MATERIALIZATION", "Excessive final components",
        "The output contains too many disconnected material islands for a reliable fabrication claim.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD).withCount(finalComponents));
    } else if (finalComponents > 1) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FINAL_COMPONENTS_EXCESSIVE,
        DiagnosticSeverity.WARNING, "MATERIALIZATION", "Disconnected final components",
        "The output contains multiple disconnected material components.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD).withCount(finalComponents));
    }
    if (volume.finalSolidCount > 0 && largest[0] < max(8, (int)(volume.finalSolidCount * 0.01f))) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FINAL_COMPONENT_TOO_SMALL,
        DiagnosticSeverity.WARNING, "MATERIALIZATION", "Final components are very small",
        "No connected material component reaches the minimum reporting threshold.",
        DCRTEPreflightActions.ACTION_ADJUST_FIELD_THRESHOLD).withValue(largest[0], max(8, (int)(volume.finalSolidCount * 0.01f))));
    }
    if (validation.errors.contains("LEGACY_ADAPTER_FAILURE")) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_MATERIALIZER_FAILURE,
        DiagnosticSeverity.BLOCKER, "MATERIALIZATION", "Materializer failure",
        "The existing voxel materializer did not produce a closed printable mesh.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
    }
  }

  int[] inspectSdfGradient(SignedDistanceVolume sdf) {
    int invalid = 0; int directionConflict = 0; int checked = 0;
    VolumeSpec spec = sdf.spec;
    for (int z = 1; z < spec.nz - 1; z++) for (int y = 1; y < spec.ny - 1; y++) for (int x = 1; x < spec.nx - 1; x++) {
      int index = sdf.index(x, y, z);
      if (sdf.inside[index] || sdf.boundary[index]) continue;
      int bx = 0; int by = 0; int bz = 0; int neighbors = 0;
      int[] offsets = {-1,0,0, 1,0,0, 0,-1,0, 0,1,0, 0,0,-1, 0,0,1};
      for (int n = 0; n < offsets.length; n += 3) {
        int neighbor = sdf.index(x + offsets[n], y + offsets[n + 1], z + offsets[n + 2]);
        if (sdf.boundary[neighbor]) { bx -= offsets[n]; by -= offsets[n + 1]; bz -= offsets[n + 2]; neighbors++; }
      }
      if (neighbors == 0) continue;
      float gx = sdf.sampleAtIndex(x + 1, y, z) - sdf.sampleAtIndex(x - 1, y, z);
      float gy = sdf.sampleAtIndex(x, y + 1, z) - sdf.sampleAtIndex(x, y - 1, z);
      float gz = sdf.sampleAtIndex(x, y, z + 1) - sdf.sampleAtIndex(x, y, z - 1);
      float magnitude = sqrt(gx * gx + gy * gy + gz * gz);
      checked++;
      if (!dcrteFinite(magnitude) || magnitude < 0.0000001f) { invalid++; continue; }
      float directionMagnitude = sqrt(bx * bx + by * by + bz * bz);
      if (directionMagnitude > 0 && (gx * bx + gy * by + gz * bz) / (magnitude * directionMagnitude) < -0.05f) directionConflict++;
    }
    return new int[] {invalid, directionConflict, checked};
  }

  void completeStage(DomainPreflightReport report, String stage, long start, String passReason) {
    boolean blocker = false; boolean warning = false;
    for (int i = 0; i < report.diagnostics.size(); i++) {
      DomainDiagnostic diagnostic = report.diagnostics.get(i);
      if (!stage.equals(diagnostic.stage)) continue;
      if (diagnostic.severity == DiagnosticSeverity.BLOCKER) blocker = true;
      else if (diagnostic.severity == DiagnosticSeverity.WARNING) warning = true;
    }
    report.setStage(stage, blocker ? DCRTEPreflightStageState.BLOCKED : warning ? DCRTEPreflightStageState.WARNING : DCRTEPreflightStageState.PASS,
      blocker ? "one or more blocking diagnostics were found" : warning ? "completed with warnings" : passReason, millis() - start);
    report.refreshSummary();
  }
}

class DCRTEAxisParityVolume {
  boolean[] inside;
  boolean[] checked;
  int failedScanlines;

  DCRTEAxisParityVolume(int count) {
    inside = new boolean[max(0, count)];
    checked = new boolean[inside.length];
  }
}

DCRTEAxisParityVolume dcrteClassifyYParity(TriangleMeshData mesh, VoxelBoundaryVolume boundary) {
  VolumeSpec spec = boundary.spec;
  DCRTEAxisParityVolume result = new DCRTEAxisParityVolume(spec.voxelCount());
  long estimatedOperations = (long)spec.nx * (long)spec.nz * (long)mesh.triangleCount;
  int lineStride = estimatedOperations > 80000000L ? max(1, (int)Math.ceil(Math.sqrt(estimatedOperations / 80000000.0))) : 1;
  float[] intersections = new float[max(8, mesh.triangleCount)];
  float tolerance = 0.20f * spec.minSpacing();
  for (int z = 0; z < spec.nz; z += lineStride) {
    float worldZ = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
    for (int x = 0; x < spec.nx; x += lineStride) {
      float worldX = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
      int rawCount = dcrteCollectYIntersections(mesh, worldX + 0.000003f * spec.minSpacing(),
        worldZ + 0.000007f * spec.minSpacing(), intersections);
      java.util.Arrays.sort(intersections, 0, rawCount);
      int uniqueCount = dcrteDeduplicateIntersections(intersections, rawCount, tolerance);
      if ((uniqueCount & 1) != 0) { result.failedScanlines++; continue; }
      int crossing = 0; boolean rowInside = false;
      for (int y = 0; y < spec.ny; y++) {
        float worldY = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        while (crossing < uniqueCount && intersections[crossing] <= worldY) { rowInside = !rowInside; crossing++; }
        int index = x + spec.nx * (y + spec.ny * z);
        result.checked[index] = true;
        result.inside[index] = rowInside || boundary.boundary[index];
      }
    }
  }
  return result;
}

int dcrteCollectYIntersections(TriangleMeshData mesh, float px, float pz, float[] output) {
  int count = 0;
  for (int t = 0; t < mesh.triangleCount; t++) {
    int ai = mesh.ia(t) * 3; int bi = mesh.ib(t) * 3; int ci = mesh.ic(t) * 3;
    float ax = mesh.vertices[ai]; float az = mesh.vertices[ai + 2];
    float bx = mesh.vertices[bi]; float bz = mesh.vertices[bi + 2];
    float cx = mesh.vertices[ci]; float cz = mesh.vertices[ci + 2];
    float denominator = (bx - cx) * (az - cz) + (cz - bz) * (ax - cx);
    if (abs(denominator) <= 0.0000000001f) continue;
    float u = ((bx - cx) * (pz - cz) + (cz - bz) * (px - cx)) / denominator;
    float v = ((cx - ax) * (pz - cz) + (az - cz) * (px - cx)) / denominator;
    float w = 1.0f - u - v;
    if (u < -0.000001f || v < -0.000001f || w < -0.000001f) continue;
    output[count++] = u * mesh.vertices[ai + 1] + v * mesh.vertices[bi + 1] + w * mesh.vertices[ci + 1];
  }
  return count;
}

boolean[] dcrteFloodExterior(VoxelBoundaryVolume boundary) {
  VolumeSpec spec = boundary.spec;
  boolean[] exterior = new boolean[spec.voxelCount()];
  int[] queue = new int[exterior.length];
  int head = 0; int tail = 0;
  for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) {
    tail = dcrteSeedFloodVoxel(0, y, z, boundary, exterior, queue, tail);
    tail = dcrteSeedFloodVoxel(spec.nx - 1, y, z, boundary, exterior, queue, tail);
  }
  for (int z = 0; z < spec.nz; z++) for (int x = 0; x < spec.nx; x++) {
    tail = dcrteSeedFloodVoxel(x, 0, z, boundary, exterior, queue, tail);
    tail = dcrteSeedFloodVoxel(x, spec.ny - 1, z, boundary, exterior, queue, tail);
  }
  for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
    tail = dcrteSeedFloodVoxel(x, y, 0, boundary, exterior, queue, tail);
    tail = dcrteSeedFloodVoxel(x, y, spec.nz - 1, boundary, exterior, queue, tail);
  }
  int[] offsets = {-1,0,0, 1,0,0, 0,-1,0, 0,1,0, 0,0,-1, 0,0,1};
  while (head < tail) {
    int index = queue[head++];
    int x = index % spec.nx;
    int yz = index / spec.nx;
    int y = yz % spec.ny;
    int z = yz / spec.ny;
    for (int i = 0; i < offsets.length; i += 3) {
      int nx = x + offsets[i]; int ny = y + offsets[i + 1]; int nz = z + offsets[i + 2];
      if (nx < 0 || ny < 0 || nz < 0 || nx >= spec.nx || ny >= spec.ny || nz >= spec.nz) continue;
      int neighbor = nx + spec.nx * (ny + spec.ny * nz);
      if (exterior[neighbor] || boundary.boundary[neighbor]) continue;
      exterior[neighbor] = true;
      queue[tail++] = neighbor;
    }
  }
  return exterior;
}

int dcrteSeedFloodVoxel(int x, int y, int z, VoxelBoundaryVolume boundary, boolean[] exterior, int[] queue, int tail) {
  int index = boundary.index(x, y, z);
  if (!boundary.boundary[index] && !exterior[index]) { exterior[index] = true; queue[tail++] = index; }
  return tail;
}

boolean dcrteVoxelTouchesBoundary(int index, VoxelBoundaryVolume boundary) {
  VolumeSpec spec = boundary.spec;
  int x = index % spec.nx;
  int yz = index / spec.nx;
  int y = yz % spec.ny;
  int z = yz / spec.ny;
  for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
    if (dx == 0 && dy == 0 && dz == 0) continue;
    int nx = x + dx; int ny = y + dy; int nz = z + dz;
    if (nx < 0 || ny < 0 || nz < 0 || nx >= spec.nx || ny >= spec.ny || nz >= spec.nz) continue;
    if (boundary.boundary[nx + spec.nx * (ny + spec.ny * nz)]) return true;
  }
  return false;
}

int dcrteCountBoundaryGridEdgeVoxels(VoxelBoundaryVolume boundary) {
  int count = 0;
  VolumeSpec spec = boundary.spec;
  for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
    if (x != 0 && y != 0 && z != 0 && x != spec.nx - 1 && y != spec.ny - 1 && z != spec.nz - 1) continue;
    if (boundary.boundary[boundary.index(x, y, z)]) count++;
  }
  return count;
}

int dcrteCountBooleanComponents(boolean[] mask, VolumeSpec spec, boolean useTwentySixNeighbors, int[] largestOut) {
  if (mask == null || spec == null || mask.length != spec.voxelCount()) return 0;
  boolean[] visited = new boolean[mask.length];
  int[] queue = new int[mask.length];
  int components = 0;
  int largest = 0;
  for (int seed = 0; seed < mask.length; seed++) {
    if (!mask[seed] || visited[seed]) continue;
    components++;
    int head = 0; int tail = 0; int size = 0;
    visited[seed] = true; queue[tail++] = seed;
    while (head < tail) {
      int index = queue[head++]; size++;
      int x = index % spec.nx; int yz = index / spec.nx; int y = yz % spec.ny; int z = yz / spec.ny;
      for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0 && dz == 0) continue;
        if (!useTwentySixNeighbors && abs(dx) + abs(dy) + abs(dz) != 1) continue;
        int nx = x + dx; int ny = y + dy; int nz = z + dz;
        if (nx < 0 || ny < 0 || nz < 0 || nx >= spec.nx || ny >= spec.ny || nz >= spec.nz) continue;
        int neighbor = nx + spec.nx * (ny + spec.ny * nz);
        if (!mask[neighbor] || visited[neighbor]) continue;
        visited[neighbor] = true; queue[tail++] = neighbor;
      }
    }
    largest = max(largest, size);
  }
  if (largestOut != null && largestOut.length > 0) largestOut[0] = largest;
  return components;
}

void locateVoxelDiagnostic(DomainDiagnostic diagnostic, VolumeSpec spec, int index) {
  if (diagnostic == null || spec == null || index < 0 || index >= spec.voxelCount()) return;
  int x = index % spec.nx; int yz = index / spec.nx; int y = yz % spec.ny; int z = yz / spec.ny;
  diagnostic.withVoxel(index).at(spec.bounds.minX + (x + 0.5f) * spec.spacingX(),
    spec.bounds.minY + (y + 0.5f) * spec.spacingY(), spec.bounds.minZ + (z + 0.5f) * spec.spacingZ());
}
