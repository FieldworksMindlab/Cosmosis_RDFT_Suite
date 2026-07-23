/* DCRTE-ET Milestone 1 Surface Foundry controls and diagnostics. */

void drawDcrtePrimitivePanel(int x, int y, int w, int h) {
  color accent = dcrteLastValidationReport == null ? color(255, 200, 90)
    : dcrteLastValidationReport.status == ValidationStatus.FAIL ? color(255, 104, 116)
    : dcrteLastValidationReport.status == ValidationStatus.PASS_WITH_WARNINGS ? color(255, 200, 90)
    : color(104, 236, 174);
  fill(3, 9, 13, 238);
  stroke(red(accent), green(accent), blue(accent), 210);
  strokeWeight(1.0);
  rect(x, y, w, h, 5);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(9);
  text("DCRTE-ET PRIMITIVE DOMAIN", x + 10, y + 8);

  int innerX = x + 10;
  int innerW = w - 20;
  fill(150, 184, 190);
  textSize(8);
  text("stage       " + dcrteBuildStage, innerX, y + 25);
  text("carrier     " + shortText(foundryGeometryName(), 18), innerX, y + 37);
  text("domain      " + dcrtePrimitiveDomainType.id().toUpperCase(), innerX, y + 49);
  text("observation " + dcrteObservationMode.id().toUpperCase(), innerX, y + 61);

  int halfGap = 6;
  int halfW = (innerW - halfGap) / 2;
  int by = y + 76;
  drawButton(innerX, by, halfW, 20, "DOMAIN " + dcrtePrimitiveDomainType.id().toUpperCase(), color(48, 72, 77));
  drawButton(innerX + halfW + halfGap, by, halfW, 20, dcrteObservationMode == DCRTEObservationMode.HARD_INTERIOR ? "HARD INTERIOR" : "SHELL BAND", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, halfW, 20, "RES " + dcrtePrimitiveResolution + "^3", color(48, 72, 77));
  drawButton(innerX + halfW + halfGap, by, halfW, 20, dcrteDomainPreviewEnabled ? "DOMAIN VIEW ON" : "DOMAIN VIEW OFF", color(48, 72, 77));
  by += 24;
  int thirdGap = 5;
  int thirdW = (innerW - thirdGap * 2) / 3;
  drawButton(innerX, by, thirdW, 20, "SHELL -", color(48, 72, 77));
  drawButton(innerX + thirdW + thirdGap, by, thirdW, 20, "SHELL +", color(48, 72, 77));
  drawButton(innerX + (thirdW + thirdGap) * 2, by, thirdW, 20, dcrteSlicePreviewEnabled ? "SLICE ON" : "SLICE OFF", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, halfW, 22, "BUILD", color(45, 86, 72));
  drawButton(innerX + halfW + halfGap, by, halfW, 22, "VALIDATE", color(62, 82, 96));

  int metricsY = by + 29;
  DCRTEVolume volume = dcrtePrimitiveVolume;
  DCRTEValidationReport validation = dcrteLastValidationReport;
  int admitted = volume == null ? 0 : volume.admittedCount;
  int finalCount = volume == null ? 0 : volume.finalSolidCount;
  int outside = validation == null ? 0 : validation.outsideSolidSamples;
  float fillRatio = admitted > 0 ? finalCount * 100.0f / admitted : 0;
  fill(150, 184, 190);
  textSize(8);
  text("admitted " + nf(admitted, 1) + "   final " + nf(finalCount, 1), innerX, metricsY);
  text("domain fill " + nf(fillRatio, 1, 2) + "%   outside " + outside, innerX, metricsY + 12);
  String validationText = validation == null ? "NOT RUN" : validation.status.id().toUpperCase();
  text("validation " + validationText + "   build " + nf(dcrteLastBuildMillis / 1000.0f, 1, 2) + " s", innerX, metricsY + 24);
  text("shell " + nf(dcrteShellThicknessVoxels, 1, 1) + " vox   tests " + dcrteM1Tests.status(), innerX, metricsY + 36);
}

boolean handleDcrtePrimitivePanelMouse(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE) return false;
  int x = previewX + previewW - 306;
  int y = previewY + 12;
  int w = 294;
  int innerX = x + 10;
  int innerW = w - 20;
  int halfGap = 6;
  int halfW = (innerW - halfGap) / 2;
  int by = y + 76;
  if (over(innerX, by, halfW, 20)) { cycleDcrtePrimitiveDomain(); return true; }
  if (over(innerX + halfW + halfGap, by, halfW, 20)) { cycleDcrteObservationMode(); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { cycleDcrtePrimitiveResolution(); return true; }
  if (over(innerX + halfW + halfGap, by, halfW, 20)) { dcrteDomainPreviewEnabled = !dcrteDomainPreviewEnabled; return true; }
  by += 24;
  int thirdGap = 5;
  int thirdW = (innerW - thirdGap * 2) / 3;
  if (over(innerX, by, thirdW, 20)) { adjustDcrteShellThickness(-1); return true; }
  if (over(innerX + thirdW + thirdGap, by, thirdW, 20)) { adjustDcrteShellThickness(1); return true; }
  if (over(innerX + (thirdW + thirdGap) * 2, by, thirdW, 20)) { dcrteSlicePreviewEnabled = !dcrteSlicePreviewEnabled; return true; }
  by += 24;
  if (over(innerX, by, halfW, 22)) { generateDcrtePrimitiveSurfaceMesh(); return true; }
  if (over(innerX + halfW + halfGap, by, halfW, 22)) { validateCurrentDcrtePrimitiveVolume(); return true; }
  return false;
}

void drawDcrtePrimitiveWireframe(float previewScale) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE || !dcrteDomainPreviewEnabled) return;
  noFill();
  stroke(255, 216, 76, 128);
  strokeWeight(1.0);
  if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.SPHERE) {
    pushMatrix();
    translate(dcrteDomainCenterX * previewScale, dcrteDomainCenterY * previewScale, dcrteDomainCenterZ * previewScale);
    sphereDetail(16);
    sphere(dcrteSphereRadius * previewScale);
    popMatrix();
  } else if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.BOX) {
    pushMatrix();
    translate(dcrteDomainCenterX * previewScale, dcrteDomainCenterY * previewScale, dcrteDomainCenterZ * previewScale);
    box(dcrteBoxHalfX * previewScale * 2, dcrteBoxHalfY * previewScale * 2, dcrteBoxHalfZ * previewScale * 2);
    popMatrix();
  } else {
    drawDcrteCylinderWireframe(previewScale);
  }
}

void drawDcrteCylinderWireframe(float previewScale) {
  int segments = 32;
  float radius = dcrteCylinderRadius * previewScale;
  float halfHeight = dcrteCylinderHalfHeight * previewScale;
  float cx = dcrteDomainCenterX * previewScale;
  float cy = dcrteDomainCenterY * previewScale;
  float cz = dcrteDomainCenterZ * previewScale;
  for (int ring = -1; ring <= 1; ring++) {
    float yy = cy + ring * halfHeight;
    beginShape();
    for (int i = 0; i <= segments; i++) {
      float angle = TWO_PI * i / segments;
      vertex(cx + cos(angle) * radius, yy, cz + sin(angle) * radius);
    }
    endShape();
  }
  for (int i = 0; i < 8; i++) {
    float angle = TWO_PI * i / 8.0f;
    float xx = cx + cos(angle) * radius;
    float zz = cz + sin(angle) * radius;
    line(xx, cy - halfHeight, zz, xx, cy + halfHeight, zz);
  }
}

void drawDcrteCenterSlice(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE || !dcrteSlicePreviewEnabled
      || dcrtePrimitiveVolume == null || !dcrtePrimitiveVolume.isValid()) return;
  DCRTEVolume volume = dcrtePrimitiveVolume;
  int n = volume.spec.nx;
  int sizePx = min(154, max(96, min(previewW, previewH) / 4));
  int x0 = previewX + 12;
  int y0 = previewY + previewH - sizePx - 32;
  float cell = sizePx / (float)n;
  noStroke();
  fill(3, 9, 13, 230);
  rect(x0 - 6, y0 - 18, sizePx + 12, sizePx + 24, 4);
  int z = n / 2;
  for (int y = 0; y < n; y++) {
    for (int x = 0; x < n; x++) {
      int idx = volume.index(x, y, z);
      if (volume.finalSolid[idx]) fill(255, 220, 78);
      else if (volume.admitted[idx]) fill(44, 164, 188);
      else fill(18, 29, 38);
      rect(x0 + x * cell, y0 + (n - 1 - y) * cell, max(1, cell + 0.2f), max(1, cell + 0.2f));
    }
  }
  noFill();
  stroke(112, 178, 188);
  rect(x0, y0, sizePx, sizePx);
  fill(150, 190, 198);
  textSize(8);
  textAlign(LEFT, TOP);
  text("CENTER Z  rejected / admitted / solid", x0, y0 - 14);
}

void drawDcrteImportedPanel(int x, int y, int w, int h) {
  boolean meshValid = dcrteImportedMeshReport != null && dcrteImportedMeshReport.strictValid();
  boolean sdfValid = dcrteImportedDomain != null && dcrteImportedDomain.isValid() && !dcrteImportedStale;
  color accent = sdfValid ? color(104, 236, 174) : meshValid ? color(255, 200, 90) : color(255, 104, 116);
  fill(3, 9, 13, 242);
  stroke(red(accent), green(accent), blue(accent), 220);
  strokeWeight(1);
  rect(x, y, w, h, 5);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(9);
  text("DCRTE-ET IMPORTED OBSERVATION DOMAIN", x + 10, y + 8);
  fill(150, 184, 190);
  textSize(8);
  text("stage   " + (dcrteImportedBuildState == null ? "UNKNOWN" : dcrteImportedBuildState.label()), x + 10, y + 24);
  text("source  " + shortText(dcrteImportedSourceMesh == null ? "NONE" : dcrteImportedSourceMesh.sourceName, 34), x + 10, y + 36);
  text("status  " + shortText(dcrteImportedStatus, 43), x + 10, y + 48);

  int innerX = x + 10;
  int innerW = w - 20;
  int gap = 6;
  int halfW = (innerW - gap) / 2;
  int thirdW = (innerW - gap * 2) / 3;
  int quarterW = (innerW - gap * 3) / 4;
  int by = y + 64;
  drawButton(innerX, by, thirdW, 20, "LOAD STL", color(48, 72, 77));
  drawButton(innerX + thirdW + gap, by, thirdW, 20, "LOAD EGG", color(58, 78, 65));
  drawButton(innerX + (thirdW + gap) * 2, by, thirdW, 20, "LOAD TORUS", color(62, 72, 92));
  by += 24;
  drawButton(innerX, by, halfW, 20, dcrteImportedResolution == 128 && millis() - dcrteImported128BuildArmedAt <= 10000 ? "CONFIRM 128 BUILD" : "REBUILD SDF", color(45, 86, 72));
  drawButton(innerX + halfW + gap, by, halfW, 20, "POLICY " + (dcrteImportedPolicy == InvalidDomainPolicy.STRICT ? "STRICT" : "UNSIGNED"), color(70, 66, 48));
  by += 24;
  drawButton(innerX, by, thirdW, 20, dcrteObservationMode == DCRTEObservationMode.HARD_INTERIOR ? "OBS HARD" : "OBS SHELL", color(52, 78, 72));
  drawButton(innerX + thirdW + gap, by, thirdW, 20, "SHELL -", color(48, 72, 77));
  drawButton(innerX + (thirdW + gap) * 2, by, thirdW, 20, "SHELL +", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, halfW, 20, "FIT / CENTER", color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "RESET TRANSFORM", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, thirdW, 20, "ROT X 90", color(48, 72, 77));
  drawButton(innerX + thirdW + gap, by, thirdW, 20, "ROT Y 90", color(48, 72, 77));
  drawButton(innerX + (thirdW + gap) * 2, by, thirdW, 20, "ROT Z 90", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, thirdW, 20, "SCALE -", color(48, 72, 77));
  drawButton(innerX + thirdW + gap, by, thirdW, 20, "SCALE +", color(48, 72, 77));
  drawButton(innerX + (thirdW + gap) * 2, by, thirdW, 20, "RES " + dcrteImportedResolution + "^3", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, thirdW, 20, "SLICE " + dcrteImportedSliceAxis.name(), color(48, 72, 77));
  drawButton(innerX + thirdW + gap, by, thirdW, 20, "SLICE -", color(48, 72, 77));
  drawButton(innerX + (thirdW + gap) * 2, by, thirdW, 20, "SLICE +", color(48, 72, 77));
  by += 24;
  String meshMode = dcrteImportedMeshPreviewMode == 0 ? "MESH OFF" : dcrteImportedMeshPreviewMode == 1 ? "WIRE" : "SURFACE";
  drawButton(innerX, by, quarterW, 20, meshMode, color(48, 72, 77));
  drawButton(innerX + quarterW + gap, by, quarterW, 20, dcrteImportedShowBoundary ? "BOUND ON" : "BOUND OFF", color(48, 72, 77));
  drawButton(innerX + (quarterW + gap) * 2, by, quarterW, 20, dcrteImportedShowSdf ? "SDF ON" : "SDF OFF", color(48, 72, 77));
  drawButton(innerX + (quarterW + gap) * 3, by, quarterW, 20, dcrteImportedShowMaterial ? "MAT ON" : "MAT OFF", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, halfW, 20, dcrtePreflightPanelOpen ? "PREFLIGHT OPEN" : "PREFLIGHT CLOSED",
    dcrtePreflightPanelOpen ? color(70, 78, 42) : color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "RUN PREFLIGHT", color(60, 82, 66));
  by += 24;
  drawButton(innerX, by, halfW, 20, "COORD " + (dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN ? "CARTESIAN" : "AXIAL"),
    dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL ? color(48, 92, 86) : color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "BUILD AXIAL", color(62, 82, 60));

  int metricsY = by + 28;
  MeshDomainReport report = dcrteImportedMeshReport;
  SDFQualityReport quality = dcrteImportedSdf == null ? null : dcrteImportedSdf.quality;
  String sha = dcrteImportedSourceMesh == null ? "-" : dcrteImportedSourceMesh.sourceHashSha256;
  fill(150, 184, 190);
  textSize(8);
  String sourceFormat = dcrteImportedSourceMesh == null ? null : dcrteImportedSourceMesh.sourceFormat;
  text("format " + (sourceFormat == null || sourceFormat.length() == 0 ? "-" : sourceFormat.toUpperCase())
    + "   sha " + (sha.length() > 12 ? sha.substring(0, 12) : sha), innerX, metricsY);
  text("tri " + (report == null ? 0 : report.outputTriangleCount)
    + "   boundary edges " + (report == null ? 0 : report.boundaryEdgeCount)
    + "   nonman " + (report == null ? 0 : report.nonManifoldEdgeCount), innerX, metricsY + 12);
  text("watertight " + (report != null && report.watertight ? "YES" : "NO")
    + "   oriented " + (report != null && report.consistentlyOriented ? "YES" : "NO")
    + "   policy " + dcrteImportedPolicy.id(), innerX, metricsY + 24);
  text("inside " + (quality == null ? 0 : quality.insideVoxelCount)
    + "   boundary vox " + (quality == null ? 0 : quality.boundaryVoxelCount)
    + "   failed rows " + (quality == null ? 0 : quality.failedScanlineCount), innerX, metricsY + 36);
  text("final " + (dcrteImportedVolume == null ? 0 : dcrteImportedVolume.finalSolidCount)
    + "   outside " + (dcrteImportedVolume == null || dcrteLastValidationReport == null ? 0 : dcrteLastValidationReport.outsideSolidSamples)
    + "   export " + (dcrteImportedExportAllowed() ? "ENABLED" : "DISABLED"), innerX, metricsY + 48);
  String sdfStatus = quality == null ? "NOT BUILT" : quality.status.id().toUpperCase();
  text("SDF " + sdfStatus + " " + dcrteImportedResolution + "^3   observation " + dcrteObservationMode.id()
    + "   build " + nf(dcrteLastBuildMillis / 1000.0f, 1, 2) + "s"
    + (report == null ? "" : "   import/san " + report.importParseMillis + "/" + report.sanitationMillis + "ms"), innerX, metricsY + 60);
  text("coord " + dcrteCoordinateMode.id() + "   intrinsic " + shortText(dcrteIntrinsicBuildStatus, 28), innerX, metricsY + 72);
  if (dcrteImportedPolicy == InvalidDomainPolicy.UNSIGNED_PREVIEW || (report != null && !report.strictValid())) {
    fill(255, 104, 116);
    text("PREVIEW ONLY - DOMAIN SIGN IS UNRELIABLE", innerX, metricsY + 84);
  }
  if (dcrteImportedWorldMesh != null) {
    int previewStride = max(1, dcrteImportedWorldMesh.triangleCount / 20000);
    if (previewStride > 1) {
      fill(150, 184, 190);
      text("preview stride " + previewStride + " only; SDF uses every accepted face", innerX, metricsY + 96);
    }
  }
}

boolean handleDcrteImportedPanelMouse(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return false;
  int w = min(370, max(330, previewW - 24));
  int x = previewX + previewW - w - 12;
  int y = previewY + 12;
  int innerX = x + 10;
  int innerW = w - 20;
  int gap = 6;
  int halfW = (innerW - gap) / 2;
  int thirdW = (innerW - gap * 2) / 3;
  int quarterW = (innerW - gap * 3) / 4;
  int by = y + 64;
  if (over(innerX, by, thirdW, 20)) { selectDcrteImportedStl(); return true; }
  if (over(innerX + thirdW + gap, by, thirdW, 20)) { loadDcrteEggFixture(); return true; }
  if (over(innerX + (thirdW + gap) * 2, by, thirdW, 20)) { loadDcrteTorusFixture(); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { requestDcrteImportedSdfBuild(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { cycleDcrteImportedPolicy(); return true; }
  by += 24;
  if (over(innerX, by, thirdW, 20)) { cycleDcrteObservationMode(); return true; }
  if (over(innerX + thirdW + gap, by, thirdW, 20)) { adjustDcrteShellThickness(-1); return true; }
  if (over(innerX + (thirdW + gap) * 2, by, thirdW, 20)) { adjustDcrteShellThickness(1); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { rebuildDcrteImportedTransform(true); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { resetDcrteImportedTransform(); return true; }
  by += 24;
  if (over(innerX, by, thirdW, 20)) { rotateDcrteImportedAxis('X'); return true; }
  if (over(innerX + thirdW + gap, by, thirdW, 20)) { rotateDcrteImportedAxis('Y'); return true; }
  if (over(innerX + (thirdW + gap) * 2, by, thirdW, 20)) { rotateDcrteImportedAxis('Z'); return true; }
  by += 24;
  if (over(innerX, by, thirdW, 20)) { adjustDcrteImportedScale(-0.05f); return true; }
  if (over(innerX + thirdW + gap, by, thirdW, 20)) { adjustDcrteImportedScale(0.05f); return true; }
  if (over(innerX + (thirdW + gap) * 2, by, thirdW, 20)) { cycleDcrteImportedResolution(); return true; }
  by += 24;
  if (over(innerX, by, thirdW, 20)) { cycleDcrteImportedSliceAxis(); return true; }
  if (over(innerX + thirdW + gap, by, thirdW, 20)) { adjustDcrteImportedSlice(-1); return true; }
  if (over(innerX + (thirdW + gap) * 2, by, thirdW, 20)) { adjustDcrteImportedSlice(1); return true; }
  by += 24;
  if (over(innerX, by, quarterW, 20)) { cycleDcrteImportedMeshPreview(); return true; }
  if (over(innerX + quarterW + gap, by, quarterW, 20)) { dcrteImportedShowBoundary = !dcrteImportedShowBoundary; return true; }
  if (over(innerX + (quarterW + gap) * 2, by, quarterW, 20)) { dcrteImportedShowSdf = !dcrteImportedShowSdf; return true; }
  if (over(innerX + (quarterW + gap) * 3, by, quarterW, 20)) { dcrteImportedShowMaterial = !dcrteImportedShowMaterial; return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { dcrtePreflightPanelOpen = !dcrtePreflightPanelOpen; return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { runDcrteImportedPreflight(); dcrtePreflightPanelOpen = true; return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { cycleDcrteCoordinateMode(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { buildDcrteImportedIntrinsicCoordinates(); dcrtePreflightPanelOpen = true; dcrtePreflightInspectorTab = 4; return true; }
  return false;
}

void drawDcrteImportedDomainPreview(float previewScale) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return;
  TriangleMeshData mesh = dcrteImportedWorldMesh;
  if (mesh != null && dcrteImportedMeshPreviewMode != 0) {
    int stride = max(1, mesh.triangleCount / 20000);
    if (dcrteImportedMeshPreviewMode == 2) {
      fill(40, 196, 184, 44);
      stroke(66, 220, 210, 90);
      strokeWeight(0.5f);
    } else {
      noFill();
      stroke(255, 216, 76, 145);
      strokeWeight(0.75f);
    }
    beginShape(TRIANGLES);
    for (int t = 0; t < mesh.triangleCount; t += stride) {
      dcrtePreviewVertex(mesh, mesh.ia(t), previewScale);
      dcrtePreviewVertex(mesh, mesh.ib(t), previewScale);
      dcrtePreviewVertex(mesh, mesh.ic(t), previewScale);
    }
    endShape();
    drawDcrteImportedInvalidEdges(mesh, previewScale);
    drawDcrteBoundsWireframe(mesh.worldBounds, previewScale);
  }
  if (dcrteImportedShowBoundary && dcrteImportedBoundary != null && dcrteImportedBoundary.isValid()) {
    VoxelBoundaryVolume boundary = dcrteImportedBoundary;
    int stride = max(1, boundary.boundaryCount / 8000);
    int seen = 0;
    stroke(255, 92, 162, 175);
    strokeWeight(2.2f);
    beginShape(POINTS);
    for (int z = 0; z < boundary.spec.nz; z++) for (int y = 0; y < boundary.spec.ny; y++) for (int x = 0; x < boundary.spec.nx; x++) {
      int index = boundary.index(x, y, z);
      if (!boundary.boundary[index]) continue;
      if ((seen++ % stride) != 0) continue;
      float wx = boundary.spec.bounds.minX + (x + 0.5f) * boundary.spec.spacingX();
      float wy = boundary.spec.bounds.minY + (y + 0.5f) * boundary.spec.spacingY();
      float wz = boundary.spec.bounds.minZ + (z + 0.5f) * boundary.spec.spacingZ();
      vertex(wx * previewScale, wy * previewScale, wz * previewScale);
    }
    endShape();
  }
  drawDcrteIntrinsicVisualization(previewScale);
  drawDcrteCompositionOverlay(previewScale);
  drawDcrtePreflightDiagnosticGeometry(previewScale);
}

void dcrtePreviewVertex(TriangleMeshData mesh, int index, float scale) {
  vertex(mesh.vx(index) * scale, mesh.vy(index) * scale, mesh.vz(index) * scale);
}

void drawDcrteImportedInvalidEdges(TriangleMeshData mesh, float scale) {
  if (mesh == null || dcrteImportedMeshReport == null) return;
  strokeWeight(2.2f);
  stroke(255, 92, 92, 230);
  drawDcrteEdgeKeys(mesh, dcrteImportedMeshReport.boundaryEdges, scale);
  stroke(255, 80, 220, 230);
  drawDcrteEdgeKeys(mesh, dcrteImportedMeshReport.nonManifoldEdges, scale);
  stroke(255, 170, 64, 230);
  drawDcrteEdgeKeys(mesh, dcrteImportedMeshReport.orientationErrorEdges, scale);
}

void drawDcrteEdgeKeys(TriangleMeshData mesh, long[] keys, float scale) {
  if (keys == null) return;
  for (int i = 0; i < keys.length; i++) {
    int a = (int)(keys[i] >>> 32);
    int b = (int)keys[i];
    if (a < 0 || b < 0 || a >= mesh.vertexCount || b >= mesh.vertexCount) continue;
    line(mesh.vx(a) * scale, mesh.vy(a) * scale, mesh.vz(a) * scale,
      mesh.vx(b) * scale, mesh.vy(b) * scale, mesh.vz(b) * scale);
  }
}

void drawDcrteBoundsWireframe(Bounds3D bounds, float scale) {
  if (bounds == null || !bounds.isValid()) return;
  float x0 = bounds.minX * scale; float x1 = bounds.maxX * scale;
  float y0 = bounds.minY * scale; float y1 = bounds.maxY * scale;
  float z0 = bounds.minZ * scale; float z1 = bounds.maxZ * scale;
  stroke(95, 150, 164, 90);
  strokeWeight(0.7f);
  line(x0,y0,z0,x1,y0,z0); line(x0,y1,z0,x1,y1,z0); line(x0,y0,z1,x1,y0,z1); line(x0,y1,z1,x1,y1,z1);
  line(x0,y0,z0,x0,y1,z0); line(x1,y0,z0,x1,y1,z0); line(x0,y0,z1,x0,y1,z1); line(x1,y0,z1,x1,y1,z1);
  line(x0,y0,z0,x0,y0,z1); line(x1,y0,z0,x1,y0,z1); line(x0,y1,z0,x0,y1,z1); line(x1,y1,z0,x1,y1,z1);
}

void drawDcrteImportedSdfSlice(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH || !dcrteImportedShowSdf
      || dcrteImportedSdfDirty || dcrteImportedSdf == null || !dcrteImportedSdf.isValid()) return;
  SignedDistanceVolume sdf = dcrteImportedSdf;
  int n = sdf.spec.nx;
  int sizePx = min(210, max(126, min(previewW, previewH) / 3));
  int x0 = previewX + 12;
  int y0 = previewY + previewH - sizePx - 34;
  float cell = sizePx / (float)n;
  int fixed = constrain(dcrteImportedSliceIndex, 0, n - 1);
  int insideCount = 0; int boundaryCount = 0; int outsideCount = 0;
  float sliceMin = Float.POSITIVE_INFINITY; float sliceMax = Float.NEGATIVE_INFINITY;
  noStroke();
  fill(3, 9, 13, 238);
  rect(x0 - 6, y0 - 28, sizePx + 12, sizePx + 36, 4);
  for (int v = 0; v < n; v++) for (int u = 0; u < n; u++) {
    int gx; int gy; int gz;
    if (dcrteImportedSliceAxis == DCRTESliceAxis.XY) { gx = u; gy = v; gz = fixed; }
    else if (dcrteImportedSliceAxis == DCRTESliceAxis.XZ) { gx = u; gy = fixed; gz = v; }
    else { gx = fixed; gy = u; gz = v; }
    int index = sdf.index(gx, gy, gz);
    float distance = sdf.signedDistance[index];
    sliceMin = min(sliceMin, distance); sliceMax = max(sliceMax, distance);
    if (sdf.boundary[index] || abs(distance) <= 0.75f * sdf.spec.minSpacing()) {
      fill(255, 218, 72); boundaryCount++;
    } else if (distance < 0) {
      fill(34, 142, 172); insideCount++;
    } else {
      fill(76, 31, 45); outsideCount++;
    }
    if (dcrteImportedShowMaterial && dcrteImportedVolume != null && dcrteImportedVolume.spec.nx == n
        && dcrteImportedVolume.finalSolid[index]) fill(255, 74, 166);
    rect(x0 + u * cell, y0 + (n - 1 - v) * cell, max(1, cell + 0.2f), max(1, cell + 0.2f));
  }
  noFill(); stroke(112, 178, 188); rect(x0, y0, sizePx, sizePx);
  fill(150, 190, 198); textSize(8); textAlign(LEFT, TOP);
  float world = dcrteImportedSliceAxis == DCRTESliceAxis.XY
    ? sdf.spec.bounds.minZ + (fixed + 0.5f) * sdf.spec.spacingZ()
    : dcrteImportedSliceAxis == DCRTESliceAxis.XZ
    ? sdf.spec.bounds.minY + (fixed + 0.5f) * sdf.spec.spacingY()
    : sdf.spec.bounds.minX + (fixed + 0.5f) * sdf.spec.spacingX();
  text("SDF " + dcrteImportedSliceAxis.name() + " slice " + fixed + "  world " + nf(world, 1, 3), x0, y0 - 24);
  text("in " + insideCount + "  zero " + boundaryCount + "  out " + outsideCount
    + "  range " + nf(sliceMin, 1, 3) + ".." + nf(sliceMax, 1, 3), x0, y0 - 13);
}

void drawDcrtePreflightPanel(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH || !dcrtePreflightPanelOpen) return;
  hint(DISABLE_DEPTH_TEST);
  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  color accent = report == null || report.qualification == DomainQualification.NOT_LOADED ? color(112, 164, 176)
    : report.status == ValidationStatus.FAIL ? color(255, 96, 112)
    : report.status == ValidationStatus.PASS_WITH_WARNINGS ? color(255, 198, 82) : color(98, 232, 168);

  int x = previewX;
  int y = previewY;
  int w = previewW;
  int h = previewH;
  fill(2, 7, 11);
  noStroke();
  rect(x, y, w, h, 6);
  stroke(accent);
  strokeWeight(1);
  noFill();
  rect(x + 1, y + 1, w - 2, h - 2, 6);

  int pad = 12;
  int gap = 7;
  int toolbarX = x + pad;
  int toolbarW = w - pad * 2;
  int fixtureButtonW = (toolbarW - gap * 4) / 5;
  int buttonW = (toolbarW - gap * 3) / 4;
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(10);
  text("DCRTE-ET DOMAIN PREFLIGHT", toolbarX, y + 9);
  fill(160, 192, 198);
  textSize(8);
  String qualification = report == null ? "NOT LOADED" : report.qualification.label();
  textAlign(RIGHT, TOP);
  text("qualification " + qualification + "  |  " + (report != null && report.reportStale ? "REPORT STALE" : "REPORT CURRENT"), x + w - pad, y + 10);

  int by = y + 25;
  drawButton(toolbarX, by, fixtureButtonW, 21, "CLOSE PREFLIGHT", color(70, 54, 60));
  drawButton(toolbarX + (fixtureButtonW + gap), by, fixtureButtonW, 21, "LOAD STL", color(48, 72, 77));
  drawButton(toolbarX + (fixtureButtonW + gap) * 2, by, fixtureButtonW, 21, "LOAD EGG", color(58, 78, 65));
  drawButton(toolbarX + (fixtureButtonW + gap) * 3, by, fixtureButtonW, 21, "LOAD TORUS", color(62, 72, 92));
  drawButton(toolbarX + (fixtureButtonW + gap) * 4, by, fixtureButtonW, 21, "RUN PREFLIGHT", color(55, 82, 68));
  by += 25;
  String[] overlayNames = {"ISSUE", "LOOPS", "COMPONENTS", "INTERSECTIONS", "SIGN VOXELS"};
  drawButton(toolbarX, by, buttonW, 21,
    dcrteImportedResolution == 128 && millis() - dcrteImported128BuildArmedAt <= 10000 ? "CONFIRM 128 BUILD" : "REBUILD SDF", color(45, 86, 72));
  drawButton(toolbarX + (buttonW + gap), by, buttonW, 21, "FIND PATH", color(76, 78, 40));
  drawButton(toolbarX + (buttonW + gap) * 2, by, buttonW, 21,
    "OVERLAY " + overlayNames[dcrtePreflightOverlayMode], color(46, 66, 78));
  drawButton(toolbarX + (buttonW + gap) * 3, by, buttonW, 21, "EXPORT REPORT JSON", color(48, 72, 77));

  int gateY = y + 78;
  dcrteDrawOperatorGateBand(toolbarX, gateY, toolbarW, 20, report);
  int bodyY = y + 105;
  int bodyH = h - 117;
  int inspectorW = constrain(round(w * 0.40f), 300, 390);
  int modelX = x + pad;
  int modelW = w - inspectorW - pad * 2 - gap;
  int inspectorX = modelX + modelW + gap;
  dcrteDrawPreflightViewport(modelX, bodyY, modelW, bodyH, report, accent);
  dcrteDrawPreflightInspector(inspectorX, bodyY, inspectorW, bodyH, report, accent);
}

int dcrteOperatorGateSeverity(DomainPreflightReport report) {
  IntrinsicValidationReport intrinsic = dcrteIntrinsicBuildResult == null ? null : dcrteIntrinsicBuildResult.validation;
  boolean intrinsicActive = dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL;
  if (intrinsicActive && dcrteIntrinsicClosedLoopBlocked()) return 1;
  if (intrinsicActive && intrinsic != null && !intrinsic.exportAllowed()) return 2;
  if (intrinsicActive && intrinsic == null) return 1;
  if (report == null || report.qualification == DomainQualification.NOT_LOADED) return 1;
  if (report.status == ValidationStatus.FAIL) return 2;
  if (report.reportStale) return 1;
  if (dcrteCompositionAuthoritative) {
    if (dcrteCompositionStale || dcrteCompositionStage == M6CompositionStage.BLOCKED
        || dcrteCompositionValidation != null && !dcrteCompositionValidation.valid()) return 2;
    if (dcrteCompositionVolume == null || !dcrteCompositionMaterialized) return 1;
  }
  if (!intrinsicActive && intrinsic != null && !intrinsic.exportAllowed()) return 1;
  if (intrinsic != null && intrinsic.status == ValidationStatus.PASS_WITH_WARNINGS) return 1;
  if (report.status == ValidationStatus.PASS_WITH_WARNINGS || !report.exportEnabled) return 1;
  return 0;
}

String dcrteOperatorGateMessage(DomainPreflightReport report) {
  IntrinsicValidationReport intrinsic = dcrteIntrinsicBuildResult == null ? null : dcrteIntrinsicBuildResult.validation;
  boolean intrinsicActive = dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL;
  if (intrinsicActive && dcrteIntrinsicClosedLoopBlocked()) {
    return "ROUTE AVAILABLE  |  CLOSED LOOP CANNOT USE ONE AXIAL CHART  |  FIND PATH USES CARTESIAN";
  }
  if (intrinsicActive && intrinsic != null && !intrinsic.exportAllowed()) {
    return "BLOCKED  |  AXIAL CHART  |  " + intrinsic.primaryIssue() + "  |  OPEN INTRINSIC TAB";
  }
  if (intrinsicActive && intrinsic == null) {
    return "ACTION REQUIRED  |  BUILD AXIAL CHART OR USE FIND PATH";
  }
  if (report == null || report.qualification == DomainQualification.NOT_LOADED) {
    return "DOMAIN NOT LOADED  |  LOAD STL, EGG, OR TORUS";
  }
  if (report.reportStale) return "ACTION REQUIRED  |  PREFLIGHT REPORT STALE  |  FIND PATH CAN CONTINUE";
  if (report.status == ValidationStatus.FAIL) {
    String blocker = report.firstBlockingCode.length() == 0 ? "PREFLIGHT FAILED" : report.firstBlockingCode;
    return "EXPORT LOCKED  |  PREFLIGHT  |  " + blocker + "  |  OPEN ISSUES TAB";
  }
  if (dcrteCompositionAuthoritative) {
    if (dcrteCompositionStale) {
      return "EXPORT LOCKED  |  COMPOSITION STALE  |  OPEN COMPOSITION TAB";
    }
    if (dcrteCompositionValidation != null && !dcrteCompositionValidation.valid()) {
      return "EXPORT LOCKED  |  COMPOSITION  |  "
        + dcrteCompositionValidation.firstBlocker() + "  |  OPEN COMPOSITION TAB";
    }
    if (dcrteCompositionVolume == null) {
      return "SOURCE QUALIFIED  |  BUILD M6 COMPOSITION  |  OPEN COMPOSITION TAB";
    }
    if (!dcrteCompositionMaterialized) {
      return "COMPOSITION READY  |  MATERIALIZE M6 OUTPUT  |  OPEN COMPOSITION TAB";
    }
  }
  if (!intrinsicActive && intrinsic != null && !intrinsic.exportAllowed()) {
    return "INTRINSIC BLOCKED (INACTIVE)  |  " + intrinsic.primaryIssue() + "  |  CARTESIAN PATH RETAINED";
  }
  if (!report.exportEnabled) return "DOMAIN QUALIFIED  |  NEXT: GENERATE MATERIAL  |  FIND PATH CAN CONTINUE";
  if (intrinsic != null && intrinsic.status == ValidationStatus.PASS_WITH_WARNINGS) {
    return "EXPORT READY WITH INTRINSIC WARNINGS  |  OPEN INTRINSIC TAB";
  }
  return "DOMAIN QUALIFIED  |  EXPORT READY";
}

void dcrteDrawOperatorGateBand(int x, int y, int w, int h, DomainPreflightReport report) {
  int severity = dcrteOperatorGateSeverity(report);
  color accent = severity == 2 ? color(255, 82, 104) : severity == 1 ? color(255, 196, 68) : color(82, 226, 164);
  color background = severity == 2 ? color(54, 18, 25) : severity == 1 ? color(48, 40, 18) : color(15, 47, 38);
  float pulse = severity == 2 ? 0.5f + 0.5f * sin(millis() * TWO_PI / 1500.0f) : 0;
  fill(background); stroke(accent); strokeWeight(1 + pulse);
  rect(x, y, w, h, 3);
  stroke(accent); strokeWeight(1);
  for (int sx = x + 5; sx < x + 45; sx += 8) line(sx, y + h - 2, sx + 8, y + 2);
  for (int sx = x + w - 45; sx < x + w - 5; sx += 8) line(sx, y + h - 2, sx + 8, y + 2);
  noStroke(); fill(accent); textAlign(CENTER, CENTER); textSize(8);
  text(shortText(dcrteOperatorGateMessage(report), max(48, w / 6)), x + w / 2, y + h / 2);
}

void dcrteActivateOperatorGate(DomainPreflightReport report) {
  IntrinsicValidationReport intrinsic = dcrteIntrinsicBuildResult == null ? null : dcrteIntrinsicBuildResult.validation;
  if (dcrteCompositionAuthoritative
      && (dcrteCompositionStale || dcrteCompositionStage == M6CompositionStage.BLOCKED
        || dcrteCompositionVolume == null || !dcrteCompositionMaterialized)) {
    dcrtePreflightInspectorTab = 5;
  } else if (dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL
      && (dcrteIntrinsicClosedLoopBlocked() || intrinsic == null)) {
    dcrteFindSafePath();
  } else if (intrinsic != null && !intrinsic.exportAllowed()) {
    dcrtePreflightInspectorTab = 4;
  } else if (report != null && report.status == ValidationStatus.FAIL) {
    dcrtePreflightInspectorTab = 2;
  } else if (report == null || report.reportStale || !report.exportEnabled) dcrteFindSafePath();
}

void dcrteDrawPreflightViewport(int x, int y, int w, int h, DomainPreflightReport report, color accent) {
  fill(2, 8, 12);
  stroke(34, 68, 76);
  strokeWeight(1);
  rect(x, y, w, h, 4);
  fill(112, 178, 188);
  textAlign(LEFT, TOP);
  textSize(8);
  text("QUALIFIED DOMAIN VIEW", x + 10, y + 9);
  fill(142, 174, 180);
  textAlign(RIGHT, TOP);
  text("overlay " + dcrtePreflightOverlayMode + "  |  model + diagnostics", x + w - 10, y + 9);

  hint(ENABLE_DEPTH_TEST);
  pushMatrix();
  translate(x + w * 0.50f, y + h * 0.52f, -80);
  rotateX(0.82f);
  rotateY(-0.55f + simT * 0.08f);
  rotateZ(0.18f);
  float previewScale = min(w, h) * 0.40f;
  drawDcrteImportedDomainPreview(previewScale);
  popMatrix();
  hint(DISABLE_DEPTH_TEST);

  noStroke();
  fill(2, 8, 12, 238);
  rect(x + 1, y + h - 40, w - 2, 39);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(8);
  text(report == null ? "NO REPORT" : report.qualification.label(), x + 10, y + h - 32);
  fill(142, 174, 180);
  String source = report == null ? "no source loaded" : shortText(report.sourceName, max(20, w / 8));
  text(source, x + 10, y + h - 19);
  textAlign(RIGHT, TOP);
  text("res " + dcrteImportedResolution + "^3  |  " + dcrteWorkflowStateLabel(report), x + w - 10, y + h - 19);
}

void dcrteDrawPreflightInspector(int x, int y, int w, int h, DomainPreflightReport report, color accent) {
  fill(3, 10, 14);
  stroke(34, 68, 76);
  strokeWeight(1);
  rect(x, y, w, h, 4);
  String[] tabs = {"SUMMARY", "STAGES", "ISSUES", "VOLUME", "INTRINSIC", "COMPOSITION"};
  int tabGap = 4;
  int tabW = (w - 16 - tabGap * 5) / 6;
  for (int i = 0; i < tabs.length; i++) {
    drawButton(x + 8 + i * (tabW + tabGap), y + 8, tabW, 21, tabs[i],
      i == dcrtePreflightInspectorTab ? color(54, 94, 92) : color(35, 54, 61));
  }
  int contentX = x + 10;
  int contentY = y + 39;
  int contentW = w - 20;
  int contentH = h - 49;
  if (dcrtePreflightInspectorTab == 1) dcrteDrawPreflightStages(contentX, contentY, contentW, contentH, report);
  else if (dcrtePreflightInspectorTab == 2) dcrteDrawPreflightIssues(contentX, contentY, contentW, contentH, report);
  else if (dcrtePreflightInspectorTab == 3) dcrteDrawPreflightVolume(contentX, contentY, contentW, contentH, report);
  else if (dcrtePreflightInspectorTab == 4) dcrteDrawIntrinsicInspector(contentX, contentY, contentW, contentH, report);
  else if (dcrtePreflightInspectorTab == 5) drawDcrteCompositionInspector(contentX, contentY, contentW, contentH);
  else dcrteDrawPreflightSummary(contentX, contentY, contentW, contentH, report, accent);
}

void dcrteDrawIntrinsicInspector(int x, int y, int w, int h, DomainPreflightReport report) {
  int gap = 5;
  int halfW = (w - gap) / 2;
  int quarterW = (w - gap * 3) / 4;
  int thirdW = (w - gap * 2) / 3;
  String fallbackLabel = dcrteIntrinsicFallbackPolicy == IntrinsicFallbackPolicy.BLOCK ? "BLOCK"
    : dcrteIntrinsicFallbackPolicy == IntrinsicFallbackPolicy.CARTESIAN_LOCAL_FALLBACK ? "CART LOCAL" : "CLAMP LOCAL";
  drawButton(x, y, halfW, 20, "MODE " + (dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN ? "CARTESIAN" : "AXIAL"), color(48, 76, 78));
  drawButton(x + halfW + gap, y, halfW, 20, "BUILD AXIAL", color(54, 88, 68));
  drawButton(x, y + 25, halfW, 20, "RESET INTRINSIC", color(68, 54, 58));
  drawButton(x + halfW + gap, y + 25, halfW, 20, "RADIAL " + dcrteIntrinsicRadialModel.label(), color(50, 70, 82));
  drawButton(x, y + 50, quarterW, 20, "L -", color(48, 72, 77));
  drawButton(x + quarterW + gap, y + 50, quarterW, 20, "L +", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 2, y + 50, quarterW, 20, "R -", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 3, y + 50, quarterW, 20, "R +", color(48, 72, 77));
  drawButton(x, y + 75, halfW, 20, "FALLBACK " + fallbackLabel, color(70, 66, 48));
  drawButton(x + halfW + gap, y + 75, halfW, 20, "VIEW " + dcrteIntrinsicVisualizationMode.label(), color(46, 66, 78));
  drawButton(x, y + 100, thirdW, 20, dcrteIntrinsicShowCenterline ? "CENTER ON" : "CENTER OFF", color(48, 72, 77));
  drawButton(x + thirdW + gap, y + 100, thirdW, 20, dcrteIntrinsicShowFrames ? "FRAMES ON" : "FRAMES OFF", color(48, 72, 77));
  drawButton(x + (thirdW + gap) * 2, y + 100, thirdW, 20, dcrteIntrinsicShowConfidence ? "CONF ON" : "CONF OFF", color(48, 72, 77));
  drawButton(x, y + 125, halfW, 20, "COMPARE " + (dcrteCoordinateComparisonMode == CoordinateComparisonMode.SINGLE ? "SINGLE" : "PAIRED"), color(50, 72, 82));
  drawButton(x + halfW + gap, y + 125, halfW, 20, "EXPORT INTRINSIC JSON", color(48, 72, 77));
  drawButton(x, y + 150, w, 20, "REVEAL CURRENT INTRINSIC REPORT", color(54, 78, 84));

  int lineY = y + 182;
  fill(112, 178, 188); textAlign(LEFT, TOP); textSize(8); text("INTRINSIC COORDINATE QUALIFICATION", x, lineY); lineY += 15;
  IntrinsicBuildResult result = dcrteIntrinsicBuildResult;
  IntrinsicValidationReport validation = result == null ? null : result.validation;
  IntrinsicSuitabilityReport suitability = validation == null ? null : validation.suitability;
  AxialSliceSet slices = result == null ? null : result.slices;
  CenterlineModel centerline = result == null ? null : result.centerline;
  int validSlices = slices == null || slices.slices == null ? 0 : round(slices.validFraction * slices.slices.length);
  lineY = dcrteInspectorPair(x, lineY, w, "COORDINATE MODE", dcrteCoordinateMode.label());
  String stateIssue = dcrteIntrinsicStateIssue(result);
  lineY = dcrteInspectorPair(x, lineY, w, "STATE GUARD", stateIssue.length() == 0 ? "CURRENT / CONTAINED" : stateIssue);
  lineY = dcrteInspectorPair(x, lineY, w, "BUILD STATUS", dcrteIntrinsicBuildStatus);
  lineY = dcrteInspectorPair(x, lineY, w, "PREFLIGHT", report != null && report.materializationEnabled ? "QUALIFIED" : "BLOCKED");
  lineY = dcrteInspectorPair(x, lineY, w, "SUITABILITY", suitability == null ? "NOT BUILT" : suitability.status.id().toUpperCase());
  lineY = dcrteInspectorPair(x, lineY, w, "DOMINANT COMPONENT", result == null || result.component == null ? "-" : nf(result.component.dominantFraction, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "PCA ELONGATION", suitability == null ? "-" : nf(suitability.elongationRatio12, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "SLICE COVERAGE", suitability == null ? "-" : nf(suitability.centerlineCoverage, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "VALID SLICES", slices == null || slices.slices == null ? "-" : validSlices + " / " + slices.slices.length);
  lineY = dcrteInspectorPair(x, lineY, w, "CENTERLINE SAMPLES", centerline == null || centerline.points == null ? "-" : str(centerline.points.length));
  lineY = dcrteInspectorPair(x, lineY, w, "CENTERLINE", validation == null ? "-" : nf(validation.centerlineLength, 1, 3) + " / " + nf(validation.centerlineCoverage, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "FRAME CONTINUITY", suitability == null ? "-" : nf(suitability.frameContinuityScore, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "AMBIGUOUS VOXELS", validation == null ? "-" : nf(100 * validation.ambiguityFraction, 1, 2) + "%");
  lineY = dcrteInspectorPair(x, lineY, w, "FALLBACK VOXELS", validation == null ? "-" : nf(100 * validation.fallbackFraction, 1, 2) + "% map / " + nf(100 * validation.appliedFallbackFraction, 1, 2) + "% used");
  lineY = dcrteInspectorPair(x, lineY, w, "CONFIDENCE", validation == null ? "-" : nf(validation.meanConfidence, 1, 3) + " mean");
  lineY = dcrteInspectorPair(x, lineY, w, "RADIAL MODEL", dcrteIntrinsicRadialModel.label());
  lineY = dcrteInspectorPair(x, lineY, w, "SCALES L / R", nf(dcrteIntrinsicLongitudinalScale, 1, 2) + " / " + nf(dcrteIntrinsicRadialScale, 1, 2));
  lineY = dcrteInspectorPair(x, lineY, w, "BUILD TIME", dcrteIntrinsicLastBuildMillis + " ms");
  lineY = dcrteInspectorPair(x, lineY, w, "REPORT DIRECTORY", "logs/dcrte_intrinsic_reports");
  if (dcrteCoordinateComparisonReport != null) {
    lineY = dcrteInspectorPair(x, lineY, w, "PAIR SOLID CART / INTR",
      nf(dcrteCoordinateComparisonReport.cartesianSolidFraction, 1, 3) + " / "
      + nf(dcrteCoordinateComparisonReport.intrinsicSolidFraction, 1, 3));
  }
  if (result != null && lineY + 80 < y + h) {
    int sliceSize = min(w, y + h - lineY - 4);
    dcrteDrawIntrinsicScalarSlice(x, lineY + 3, sliceSize, sliceSize);
  }
}

void dcrteDrawPreflightSummary(int x, int y, int w, int h, DomainPreflightReport report, color accent) {
  int boundaryEdges = report == null || report.meshReport == null ? 0 : report.meshReport.boundaryEdgeCount;
  int nonmanifold = report == null || report.meshReport == null ? 0 : report.meshReport.nonManifoldEdgeCount;
  int intersections = report == null || report.selfIntersectionReport == null ? 0 : report.selfIntersectionReport.confirmedIntersectionCount;
  fill(accent); textAlign(LEFT, TOP); textSize(9);
  text(report == null ? "NOT LOADED" : report.qualification.label(), x, y);
  fill(150, 184, 190); textSize(8);
  int lineY = y + 17;
  lineY = dcrteInspectorPair(x, lineY, w, "SOURCE", report == null ? "NONE" : shortText(report.sourceName, 38));
  lineY = dcrteInspectorPair(x, lineY, w, "FIRST BLOCKER", report == null || report.firstBlockingCode.length() == 0 ? "NONE" : report.firstBlockingCode);
  lineY = dcrteInspectorPair(x, lineY, w, "BOUNDARY EDGES", str(boundaryEdges));
  lineY = dcrteInspectorPair(x, lineY, w, "BOUNDARY LOOPS", str(report == null ? 0 : report.boundaryLoops.size()));
  lineY = dcrteInspectorPair(x, lineY, w, "NONMANIFOLD", str(nonmanifold));
  lineY = dcrteInspectorPair(x, lineY, w, "COMPONENTS", str(report == null ? 0 : report.componentCount));
  lineY = dcrteInspectorPair(x, lineY, w, "INTERSECTIONS", str(intersections));
  lineY = dcrteInspectorPair(x, lineY, w, "DOMINANT SURFACE", report == null ? "-" : nf(report.dominantComponentFraction, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "INSIDE CONNECTIVITY", report == null ? "-" : report.insideMaskComponentCount + " / " + nf(report.insideMaskDominantFraction, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "SDF CONFIDENCE", report == null ? "-" : nf(report.sdfResolutionConfidence, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "THIN FEATURE RISK", report != null && report.thinFeatureRisk ? "YES" : "NO");
  lineY += 5;
  fill(112, 178, 188); text("PERMISSIONS", x, lineY); lineY += 14;
  fill(150, 184, 190);
  text("preview " + dcrtePermissionWord(report != null && report.previewEnabled)
    + "  sdf " + dcrtePermissionWord(report != null && report.sdfBuildEnabled)
    + "  material " + dcrtePermissionWord(report != null && report.materializationEnabled)
    + "  export " + dcrtePermissionWord(report != null && report.exportEnabled), x, lineY);
  lineY += 22;
  fill(112, 178, 188); text("RECOMMENDED NEXT ACTION", x, lineY); lineY += 14;
  fill(185, 204, 205);
  String nextAction = dcrteWorkflowNextAction(report);
  if (report != null && report.recommendedNextAction != null && report.recommendedNextAction.length() > 0
      && report.status == ValidationStatus.FAIL) nextAction = dcrteWorkflowActionLabel(report.recommendedNextAction);
  dcrteDrawWrappedText(nextAction,
    x, lineY, w, 11, max(2, (h - (lineY - y)) / 11));
}

void dcrteDrawPreflightStages(int x, int y, int w, int h, DomainPreflightReport report) {
  fill(112, 178, 188); textAlign(LEFT, TOP); textSize(8); text("QUALIFICATION PIPELINE", x, y);
  String[] stages = dcrtePreflightStageNames();
  int gap = 8;
  int cellW = (w - gap) / 2;
  int cellH = max(48, (h - 24) / 7);
  for (int i = 0; i < stages.length; i++) {
    int sx = x + (i % 2) * (cellW + gap);
    int sy = y + 18 + (i / 2) * cellH;
    DCRTEPreflightStageRecord stage = report == null ? null : report.stageRecord(stages[i]);
    DCRTEPreflightStageState state = stage == null ? DCRTEPreflightStageState.NOT_RUN : stage.state;
    stroke(35, 58, 65); noFill(); rect(sx, sy, cellW, cellH - 6, 3);
    noStroke(); fill(dcrteStageColor(state)); rect(sx + 7, sy + 8, 6, 6);
    fill(180, 204, 205); textSize(7.5f); text(stages[i], sx + 18, sy + 5);
    fill(118, 158, 166); text(state.id() + (stage == null ? "" : "  " + stage.elapsedMillis + "ms"), sx + 7, sy + 18);
    fill(145, 174, 180);
    dcrteDrawWrappedText(stage == null ? "not run" : stage.reason, sx + 7, sy + 30, cellW - 14, 9, 2);
  }
}

void dcrteDrawPreflightIssues(int x, int y, int w, int h, DomainPreflightReport report) {
  int gap = 5;
  int thirdW = (w - gap * 2) / 3;
  drawButton(x, y, thirdW, 20, dcrtePreflightShowBlockers ? "BLOCKERS ON" : "BLOCKERS OFF",
    dcrtePreflightShowBlockers ? color(90, 47, 53) : color(48, 61, 66));
  drawButton(x + thirdW + gap, y, thirdW, 20, dcrtePreflightShowWarnings ? "WARNINGS ON" : "WARNINGS OFF",
    dcrtePreflightShowWarnings ? color(86, 72, 39) : color(48, 61, 66));
  drawButton(x + (thirdW + gap) * 2, y, thirdW, 20, dcrtePreflightShowInformation ? "INFO ON" : "INFO OFF",
    dcrtePreflightShowInformation ? color(38, 74, 90) : color(48, 61, 66));
  int halfW = (w - gap) / 2;
  drawButton(x, y + 25, halfW, 20, "PREVIOUS ISSUE", color(48, 72, 77));
  drawButton(x + halfW + gap, y + 25, halfW, 20, "NEXT ISSUE", color(48, 72, 77));
  drawButton(x, y + 50, w, 20, "COPY SUMMARY", color(48, 72, 77));

  ArrayList<DomainDiagnostic> issues = dcrteVisiblePreflightIssues();
  dcrtePreflightClampIssueIndex();
  DomainDiagnostic issue = issues.size() == 0 ? null : issues.get(dcrtePreflightIssueIndex);
  int detailY = y + 82;
  fill(112, 178, 188); textAlign(LEFT, TOP); textSize(8);
  text("DIAGNOSTIC " + (issues.size() == 0 ? "0 / 0" : (dcrtePreflightIssueIndex + 1) + " / " + issues.size()), x, detailY);
  if (issue == null) {
    fill(98, 232, 168);
    text("No diagnostics match the active filters.", x, detailY + 20);
    return;
  }
  fill(dcrteSeverityColor(issue.severity)); textSize(9); text(issue.code + "  [" + issue.stage + "]", x, detailY + 17);
  fill(205, 218, 218); textSize(8); text(issue.title, x, detailY + 34);
  fill(148, 178, 184);
  int nextY = dcrteDrawWrappedText(issue.message, x, detailY + 51, w, 11, 7);
  nextY += 5;
  text("count " + (issue.count < 0 ? "-" : str(issue.count))
    + "  value " + (!dcrteFinite(issue.value) ? "-" : nf(issue.value, 1, 4))
    + "  threshold " + (!dcrteFinite(issue.threshold) ? "-" : nf(issue.threshold, 1, 4)), x, nextY);
  nextY += 19;
  fill(112, 178, 188); text("RECOMMENDED ACTION", x, nextY); nextY += 14;
  fill(185, 204, 205);
  dcrteDrawWrappedText(issue.recommendedAction, x, nextY, w, 11, max(2, (h - (nextY - y)) / 11));
}

void dcrteDrawPreflightVolume(int x, int y, int w, int h, DomainPreflightReport report) {
  int gap = 5;
  int quarterW = (w - gap * 3) / 4;
  drawButton(x, y, quarterW, 20, "AXIS " + dcrteImportedSliceAxis.name(), color(48, 72, 77));
  drawButton(x + quarterW + gap, y, quarterW, 20, "SLICE -", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 2, y, quarterW, 20, "SLICE +", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 3, y, quarterW, 20, "RES " + dcrteImportedResolution, color(48, 72, 77));
  drawButton(x, y + 25, quarterW, 20, dcrteObservationMode == DCRTEObservationMode.HARD_INTERIOR ? "OBS HARD" : "OBS SHELL", color(52, 78, 72));
  drawButton(x + quarterW + gap, y + 25, quarterW, 20, dcrteImportedShowBoundary ? "BOUND ON" : "BOUND OFF", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 2, y + 25, quarterW, 20, dcrteImportedShowSdf ? "SDF ON" : "SDF OFF", color(48, 72, 77));
  drawButton(x + (quarterW + gap) * 3, y + 25, quarterW, 20, dcrteImportedShowMaterial ? "MAT ON" : "MAT OFF", color(48, 72, 77));

  fill(112, 178, 188); textAlign(LEFT, TOP); textSize(8); text("VOLUME QUALIFICATION", x, y + 57);
  int lineY = y + 73;
  lineY = dcrteInspectorPair(x, lineY, w, "SDF", dcrteImportedSdf == null ? "NOT BUILT" : (dcrteImportedSdf.signed ? "SIGNED" : "UNSIGNED"));
  lineY = dcrteInspectorPair(x, lineY, w, "INSIDE COMPONENTS", report == null ? "-" : str(report.insideMaskComponentCount));
  lineY = dcrteInspectorPair(x, lineY, w, "DOMINANT INSIDE", report == null ? "-" : nf(report.insideMaskDominantFraction, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "RES CONFIDENCE", report == null ? "-" : nf(report.sdfResolutionConfidence, 1, 3));
  lineY = dcrteInspectorPair(x, lineY, w, "GRID CURRENT / SUGGESTED",
    report == null || report.resolutionSuitability == null ? "-"
    : report.selectedResolution + "^3 / " + report.resolutionSuitability.recommendedMinimumResolution + "^3 (advisory)");
  if (dcrteImportedShowSdf) {
    int sliceY = lineY + 5;
    drawDcrteImportedSdfSlice(x - 2, sliceY, w + 4, max(150, h - (sliceY - y)));
  } else {
    fill(142, 174, 180);
    text("Enable SDF to inspect the orthogonal signed-distance slice.", x, lineY + 13);
  }
}

int dcrteInspectorPair(int x, int y, int w, String label, String value) {
  fill(112, 150, 158); textAlign(LEFT, TOP); textSize(8); text(label, x, y);
  fill(192, 210, 211); textAlign(RIGHT, TOP); text(shortText(value == null ? "-" : value, max(12, w / 7)), x + w, y);
  return y + 14;
}

int dcrteDrawWrappedText(String value, float x, float y, float maxWidth, float lineHeight, int maxLines) {
  String safe = value == null || value.length() == 0 ? "-" : value;
  String[] words = splitTokens(safe, " \t\n\r");
  String line = "";
  int lineCount = 0;
  for (int i = 0; i < words.length && lineCount < maxLines; i++) {
    String candidate = line.length() == 0 ? words[i] : line + " " + words[i];
    if (textWidth(candidate) <= maxWidth || line.length() == 0) {
      line = candidate;
    } else {
      text(line, x, y + lineCount * lineHeight);
      lineCount++;
      line = words[i];
    }
  }
  if (line.length() > 0 && lineCount < maxLines) {
    text(line, x, y + lineCount * lineHeight);
    lineCount++;
  }
  return round(y + lineCount * lineHeight);
}

String dcrtePermissionWord(boolean enabled) { return enabled ? "ON" : "OFF"; }

color dcrteStageColor(DCRTEPreflightStageState state) {
  if (state == DCRTEPreflightStageState.PASS) return color(78, 224, 162);
  if (state == DCRTEPreflightStageState.WARNING) return color(255, 192, 72);
  if (state == DCRTEPreflightStageState.BLOCKED) return color(255, 86, 108);
  if (state == DCRTEPreflightStageState.SKIPPED) return color(108, 110, 122);
  return color(72, 116, 126);
}

color dcrteSeverityColor(DiagnosticSeverity severity) {
  if (severity == DiagnosticSeverity.BLOCKER) return color(255, 86, 108);
  if (severity == DiagnosticSeverity.WARNING) return color(255, 192, 72);
  return color(86, 202, 228);
}

boolean handleDcrtePreflightPanelMouse(int previewX, int previewY, int previewW, int previewH) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH || !dcrtePreflightPanelOpen) return false;
  int x = previewX;
  int y = previewY;
  int w = previewW;
  int pad = 12;
  int gap = 7;
  int toolbarX = x + pad;
  int toolbarW = w - pad * 2;
  int fixtureButtonW = (toolbarW - gap * 4) / 5;
  int buttonW = (toolbarW - gap * 3) / 4;
  int by = y + 25;
  if (over(toolbarX, by, fixtureButtonW, 21)) { dcrtePreflightPanelOpen = false; return true; }
  if (over(toolbarX + fixtureButtonW + gap, by, fixtureButtonW, 21)) { selectDcrteImportedStl(); return true; }
  if (over(toolbarX + (fixtureButtonW + gap) * 2, by, fixtureButtonW, 21)) { loadDcrteEggFixture(); return true; }
  if (over(toolbarX + (fixtureButtonW + gap) * 3, by, fixtureButtonW, 21)) { loadDcrteTorusFixture(); return true; }
  if (over(toolbarX + (fixtureButtonW + gap) * 4, by, fixtureButtonW, 21)) { dcrteImportedAttemptPreflightReport = null; runDcrteImportedPreflight(); return true; }
  by += 25;
  if (over(toolbarX, by, buttonW, 21)) { requestDcrteImportedSdfBuild(); return true; }
  if (over(toolbarX + buttonW + gap, by, buttonW, 21)) { dcrteFindSafePath(); return true; }
  if (over(toolbarX + (buttonW + gap) * 2, by, buttonW, 21)) { dcrtePreflightOverlayMode = (dcrtePreflightOverlayMode + 1) % 5; return true; }
  if (over(toolbarX + (buttonW + gap) * 3, by, buttonW, 21)) { exportDcrtePreflightReportJSON(); return true; }

  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  if (over(toolbarX, y + 78, toolbarW, 20)) { dcrteActivateOperatorGate(report); return true; }
  int bodyY = y + 105;
  int inspectorW = constrain(round(w * 0.40f), 300, 390);
  int modelW = w - inspectorW - pad * 2 - gap;
  int inspectorX = x + pad + modelW + gap;
  int tabGap = 4;
  int tabW = (inspectorW - 16 - tabGap * 5) / 6;
  for (int i = 0; i < 6; i++) {
    if (over(inspectorX + 8 + i * (tabW + tabGap), bodyY + 8, tabW, 21)) {
      dcrtePreflightInspectorTab = i;
      return true;
    }
  }
  int contentX = inspectorX + 10;
  int contentY = bodyY + 39;
  int contentW = inspectorW - 20;
  if (dcrtePreflightInspectorTab == 2) {
    int controlGap = 5;
    int thirdW = (contentW - controlGap * 2) / 3;
    if (over(contentX, contentY, thirdW, 20)) { dcrtePreflightShowBlockers = !dcrtePreflightShowBlockers; dcrtePreflightClampIssueIndex(); return true; }
    if (over(contentX + thirdW + controlGap, contentY, thirdW, 20)) { dcrtePreflightShowWarnings = !dcrtePreflightShowWarnings; dcrtePreflightClampIssueIndex(); return true; }
    if (over(contentX + (thirdW + controlGap) * 2, contentY, thirdW, 20)) { dcrtePreflightShowInformation = !dcrtePreflightShowInformation; dcrtePreflightClampIssueIndex(); return true; }
    int halfW = (contentW - controlGap) / 2;
    if (over(contentX, contentY + 25, halfW, 20)) { stepDcrtePreflightIssue(-1); return true; }
    if (over(contentX + halfW + controlGap, contentY + 25, halfW, 20)) { stepDcrtePreflightIssue(1); return true; }
    if (over(contentX, contentY + 50, contentW, 20)) { copyDcrtePreflightSummary(); return true; }
  } else if (dcrtePreflightInspectorTab == 3) {
    int controlGap = 5;
    int quarterW = (contentW - controlGap * 3) / 4;
    if (over(contentX, contentY, quarterW, 20)) { cycleDcrteImportedSliceAxis(); return true; }
    if (over(contentX + quarterW + controlGap, contentY, quarterW, 20)) { adjustDcrteImportedSlice(-1); return true; }
    if (over(contentX + (quarterW + controlGap) * 2, contentY, quarterW, 20)) { adjustDcrteImportedSlice(1); return true; }
    if (over(contentX + (quarterW + controlGap) * 3, contentY, quarterW, 20)) { cycleDcrteImportedResolution(); return true; }
    if (over(contentX, contentY + 25, quarterW, 20)) { cycleDcrteObservationMode(); return true; }
    if (over(contentX + quarterW + controlGap, contentY + 25, quarterW, 20)) { dcrteImportedShowBoundary = !dcrteImportedShowBoundary; return true; }
    if (over(contentX + (quarterW + controlGap) * 2, contentY + 25, quarterW, 20)) { dcrteImportedShowSdf = !dcrteImportedShowSdf; return true; }
    if (over(contentX + (quarterW + controlGap) * 3, contentY + 25, quarterW, 20)) { dcrteImportedShowMaterial = !dcrteImportedShowMaterial; return true; }
  } else if (dcrtePreflightInspectorTab == 4) {
    int controlGap = 5;
    int halfW = (contentW - controlGap) / 2;
    int quarterW = (contentW - controlGap * 3) / 4;
    int thirdW = (contentW - controlGap * 2) / 3;
    if (over(contentX, contentY, halfW, 20)) { cycleDcrteCoordinateMode(); return true; }
    if (over(contentX + halfW + controlGap, contentY, halfW, 20)) { buildDcrteImportedIntrinsicCoordinates(); return true; }
    if (over(contentX, contentY + 25, halfW, 20)) { resetDcrteIntrinsic(); return true; }
    if (over(contentX + halfW + controlGap, contentY + 25, halfW, 20)) { cycleDcrteIntrinsicRadialModel(); return true; }
    if (over(contentX, contentY + 50, quarterW, 20)) { adjustDcrteIntrinsicLongitudinalScale(-0.10f); return true; }
    if (over(contentX + quarterW + controlGap, contentY + 50, quarterW, 20)) { adjustDcrteIntrinsicLongitudinalScale(0.10f); return true; }
    if (over(contentX + (quarterW + controlGap) * 2, contentY + 50, quarterW, 20)) { adjustDcrteIntrinsicRadialScale(-0.10f); return true; }
    if (over(contentX + (quarterW + controlGap) * 3, contentY + 50, quarterW, 20)) { adjustDcrteIntrinsicRadialScale(0.10f); return true; }
    if (over(contentX, contentY + 75, halfW, 20)) { cycleDcrteIntrinsicFallbackPolicy(); return true; }
    if (over(contentX + halfW + controlGap, contentY + 75, halfW, 20)) { cycleDcrteIntrinsicVisualizationMode(); return true; }
    if (over(contentX, contentY + 100, thirdW, 20)) { dcrteIntrinsicShowCenterline = !dcrteIntrinsicShowCenterline; return true; }
    if (over(contentX + thirdW + controlGap, contentY + 100, thirdW, 20)) { dcrteIntrinsicShowFrames = !dcrteIntrinsicShowFrames; return true; }
    if (over(contentX + (thirdW + controlGap) * 2, contentY + 100, thirdW, 20)) { dcrteIntrinsicShowConfidence = !dcrteIntrinsicShowConfidence; if (dcrteIntrinsicShowConfidence) dcrteIntrinsicVisualizationMode = IntrinsicVisualizationMode.INTRINSIC_CONFIDENCE; return true; }
    if (over(contentX, contentY + 125, halfW, 20)) { cycleDcrteCoordinateComparisonMode(); return true; }
    if (over(contentX + halfW + controlGap, contentY + 125, halfW, 20)) { exportDcrteIntrinsicReportJSON(); return true; }
    if (over(contentX, contentY + 150, contentW, 20)) { revealDcrteIntrinsicReport(); return true; }
  } else if (dcrtePreflightInspectorTab == 5) {
    return handleDcrteCompositionInspectorMouse(contentX, contentY, contentW, bodyY + (previewH - 117) - contentY);
  }
  return false;
}

void drawDcrtePreflightDiagnosticGeometry(float scale) {
  if (!dcrtePreflightPanelOpen || dcrteImportedWorldMesh == null || dcrteImportedPreflightReport == null) return;
  TriangleMeshData mesh = dcrteImportedWorldMesh;
  DomainPreflightReport report = dcrteImportedPreflightReport;
  if (dcrtePreflightOverlayMode == 1) drawDcrtePreflightLoops(mesh, report, scale);
  else if (dcrtePreflightOverlayMode == 2) drawDcrtePreflightComponents(report, scale);
  else if (dcrtePreflightOverlayMode == 3) drawDcrtePreflightIntersections(mesh, report, scale);
  else if (dcrtePreflightOverlayMode == 4) drawDcrtePreflightSignVoxels(report, scale);
  else drawDcrteSelectedDiagnostic(mesh, scale);
}

void drawDcrtePreflightLoops(TriangleMeshData mesh, DomainPreflightReport report, float scale) {
  noFill();
  for (int i = 0; i < report.boundaryLoops.size(); i++) {
    MeshBoundaryLoopReport loop = report.boundaryLoops.get(i);
    stroke(loop.largest ? color(255, 72, 96) : color(255, 192, 68));
    strokeWeight(loop.largest ? 3.2f : 2.0f);
    beginShape();
    for (int j = 0; j < loop.vertexIndices.length; j++) {
      int vertexIndex = loop.vertexIndices[j];
      if (vertexIndex >= 0 && vertexIndex < mesh.vertexCount) dcrtePreviewVertex(mesh, vertexIndex, scale);
    }
    endShape(loop.closed ? CLOSE : OPEN);
  }
}

void drawDcrtePreflightComponents(DomainPreflightReport report, float scale) {
  for (int i = 0; i < report.components.size(); i++) {
    MeshComponentReport component = report.components.get(i);
    color c = color(70 + (i * 73) % 180, 110 + (i * 47) % 130, 210 - (i * 31) % 120);
    dcrteDrawDiagnosticBounds(component.worldBounds, scale, c, component.tiny ? 2.8f : 1.5f);
  }
}

void drawDcrtePreflightIntersections(TriangleMeshData mesh, DomainPreflightReport report, float scale) {
  SelfIntersectionReport intersections = report.selfIntersectionReport;
  if (intersections == null) return;
  noFill(); stroke(255, 64, 96); strokeWeight(2.4f);
  int count = min(intersections.triangleA.length, intersections.triangleB.length);
  for (int i = 0; i < count; i++) {
    dcrteDrawDiagnosticTriangle(mesh, intersections.triangleA[i], scale);
    dcrteDrawDiagnosticTriangle(mesh, intersections.triangleB[i], scale);
  }
}

void drawDcrtePreflightSignVoxels(DomainPreflightReport report, float scale) {
  if (report.insideOutsideVerification == null || dcrteImportedBoundary == null) return;
  InsideOutsideVerification verification = report.insideOutsideVerification;
  stroke(255, 72, 158); strokeWeight(3.2f); beginShape(POINTS);
  for (int i = 0; i < verification.disagreementVoxelIndices.length; i++) {
    dcrteDiagnosticVoxelVertex(verification.disagreementVoxelIndices[i], dcrteImportedBoundary, scale);
  }
  endShape();
  stroke(74, 210, 255); strokeWeight(2.2f); beginShape(POINTS);
  for (int i = 0; i < verification.crossAxisDisagreementVoxelIndices.length; i++) {
    dcrteDiagnosticVoxelVertex(verification.crossAxisDisagreementVoxelIndices[i], dcrteImportedBoundary, scale);
  }
  endShape();
}

void drawDcrteSelectedDiagnostic(TriangleMeshData mesh, float scale) {
  ArrayList<DomainDiagnostic> issues = dcrteVisiblePreflightIssues();
  if (issues.size() == 0) return;
  dcrtePreflightClampIssueIndex();
  DomainDiagnostic diagnostic = issues.get(dcrtePreflightIssueIndex);
  stroke(dcrteSeverityColor(diagnostic.severity)); strokeWeight(3.0f); noFill();
  if (diagnostic.edgeVertexA >= 0 && diagnostic.edgeVertexB >= 0
      && diagnostic.edgeVertexA < mesh.vertexCount && diagnostic.edgeVertexB < mesh.vertexCount) {
    line(mesh.vx(diagnostic.edgeVertexA) * scale, mesh.vy(diagnostic.edgeVertexA) * scale, mesh.vz(diagnostic.edgeVertexA) * scale,
      mesh.vx(diagnostic.edgeVertexB) * scale, mesh.vy(diagnostic.edgeVertexB) * scale, mesh.vz(diagnostic.edgeVertexB) * scale);
  }
  if (diagnostic.triangleIndex >= 0) dcrteDrawDiagnosticTriangle(mesh, diagnostic.triangleIndex, scale);
  if (diagnostic.secondaryTriangleIndex >= 0) dcrteDrawDiagnosticTriangle(mesh, diagnostic.secondaryTriangleIndex, scale);
  if (diagnostic.voxelIndex >= 0 && dcrteImportedBoundary != null) {
    strokeWeight(7); beginShape(POINTS); dcrteDiagnosticVoxelVertex(diagnostic.voxelIndex, dcrteImportedBoundary, scale); endShape();
  }
  if (diagnostic.hasLocation) {
    pushMatrix();
    translate(diagnostic.worldX * scale, diagnostic.worldY * scale, diagnostic.worldZ * scale);
    noFill(); strokeWeight(2.2f); sphereDetail(8); sphere(max(0.012f, 0.025f * scale));
    popMatrix();
  }
}

void dcrteDrawDiagnosticTriangle(TriangleMeshData mesh, int triangleIndex, float scale) {
  if (triangleIndex < 0 || triangleIndex >= mesh.triangleCount) return;
  beginShape();
  dcrtePreviewVertex(mesh, mesh.ia(triangleIndex), scale);
  dcrtePreviewVertex(mesh, mesh.ib(triangleIndex), scale);
  dcrtePreviewVertex(mesh, mesh.ic(triangleIndex), scale);
  endShape(CLOSE);
}

void dcrteDiagnosticVoxelVertex(int index, VoxelBoundaryVolume boundary, float scale) {
  if (index < 0 || index >= boundary.boundary.length) return;
  int x = index % boundary.spec.nx;
  int y = (index / boundary.spec.nx) % boundary.spec.ny;
  int z = index / (boundary.spec.nx * boundary.spec.ny);
  vertex((boundary.spec.bounds.minX + (x + 0.5f) * boundary.spec.spacingX()) * scale,
    (boundary.spec.bounds.minY + (y + 0.5f) * boundary.spec.spacingY()) * scale,
    (boundary.spec.bounds.minZ + (z + 0.5f) * boundary.spec.spacingZ()) * scale);
}

void dcrteDrawDiagnosticBounds(Bounds3D bounds, float scale, color c, float weight) {
  if (bounds == null || !bounds.isValid()) return;
  float x0 = bounds.minX * scale; float x1 = bounds.maxX * scale;
  float y0 = bounds.minY * scale; float y1 = bounds.maxY * scale;
  float z0 = bounds.minZ * scale; float z1 = bounds.maxZ * scale;
  stroke(c); strokeWeight(weight); noFill();
  line(x0,y0,z0,x1,y0,z0); line(x0,y1,z0,x1,y1,z0); line(x0,y0,z1,x1,y0,z1); line(x0,y1,z1,x1,y1,z1);
  line(x0,y0,z0,x0,y1,z0); line(x1,y0,z0,x1,y1,z0); line(x0,y0,z1,x0,y1,z1); line(x1,y0,z1,x1,y1,z1);
  line(x0,y0,z0,x0,y0,z1); line(x1,y0,z0,x1,y0,z1); line(x0,y1,z0,x0,y1,z1); line(x1,y1,z0,x1,y1,z1);
}
