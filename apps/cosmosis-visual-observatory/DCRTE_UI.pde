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
  text("stage   " + dcrteImportedBuildState.label(), x + 10, y + 24);
  text("source  " + shortText(dcrteImportedSourceMesh == null ? "NONE" : dcrteImportedSourceMesh.sourceName, 34), x + 10, y + 36);
  text("status  " + shortText(dcrteImportedStatus, 43), x + 10, y + 48);

  int innerX = x + 10;
  int innerW = w - 20;
  int gap = 6;
  int halfW = (innerW - gap) / 2;
  int thirdW = (innerW - gap * 2) / 3;
  int quarterW = (innerW - gap * 3) / 4;
  int by = y + 64;
  drawButton(innerX, by, halfW, 20, "LOAD STL", color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "LOAD EGG FIXTURE", color(58, 78, 65));
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

  int metricsY = by + 28;
  MeshDomainReport report = dcrteImportedMeshReport;
  SDFQualityReport quality = dcrteImportedSdf == null ? null : dcrteImportedSdf.quality;
  String sha = dcrteImportedSourceMesh == null ? "-" : dcrteImportedSourceMesh.sourceHashSha256;
  fill(150, 184, 190);
  textSize(8);
  text("format " + (dcrteImportedSourceMesh == null ? "-" : dcrteImportedSourceMesh.sourceFormat.toUpperCase())
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
  if (dcrteImportedPolicy == InvalidDomainPolicy.UNSIGNED_PREVIEW || (report != null && !report.strictValid())) {
    fill(255, 104, 116);
    text("PREVIEW ONLY - DOMAIN SIGN IS UNRELIABLE", innerX, metricsY + 72);
  }
  if (dcrteImportedWorldMesh != null) {
    int previewStride = max(1, dcrteImportedWorldMesh.triangleCount / 20000);
    if (previewStride > 1) {
      fill(150, 184, 190);
      text("preview stride " + previewStride + " only; SDF uses every accepted face", innerX, metricsY + 84);
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
  if (over(innerX, by, halfW, 20)) { selectDcrteImportedStl(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { loadDcrteEggFixture(); return true; }
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
  drawDcrtePreflightDiagnosticGeometry(previewScale);
}

void dcrtePreviewVertex(TriangleMeshData mesh, int index, float scale) {
  vertex(mesh.vx(index) * scale, mesh.vy(index) * scale, mesh.vz(index) * scale);
}

void drawDcrteImportedInvalidEdges(TriangleMeshData mesh, float scale) {
  if (dcrteImportedMeshReport == null) return;
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
  int w = max(250, min(360, previewW - 400));
  int h = min(510, previewH - 24);
  int x = previewX + 12;
  int y = previewY + 12;
  DomainPreflightReport report = dcrteDisplayedPreflightReport();
  color accent = report == null || report.qualification == DomainQualification.NOT_LOADED ? color(112, 164, 176)
    : report.status == ValidationStatus.FAIL ? color(255, 96, 112)
    : report.status == ValidationStatus.PASS_WITH_WARNINGS ? color(255, 198, 82) : color(98, 232, 168);
  fill(3, 9, 13, 248);
  stroke(accent);
  strokeWeight(1);
  rect(x, y, w, h, 5);
  fill(accent);
  textAlign(LEFT, TOP);
  textSize(9);
  text("DCRTE-ET DOMAIN PREFLIGHT", x + 10, y + 8);
  fill(160, 192, 198);
  textSize(8);
  String qualification = report == null ? "NOT LOADED" : report.qualification.label();
  text("qualification  " + qualification, x + 10, y + 24);
  text("source         " + shortText(report == null ? "NONE" : report.sourceName, 34), x + 10, y + 36);
  text("first blocker  " + (report == null || report.firstBlockingCode.length() == 0 ? "NONE" : report.firstBlockingCode), x + 10, y + 48);
  text("permissions    preview " + dcrtePermissionWord(report != null && report.previewEnabled)
    + "  sdf " + dcrtePermissionWord(report != null && report.sdfBuildEnabled)
    + "  mat " + dcrtePermissionWord(report != null && report.materializationEnabled)
    + "  export " + dcrtePermissionWord(report != null && report.exportEnabled), x + 10, y + 60);

  int innerX = x + 10;
  int innerW = w - 20;
  int gap = 6;
  int halfW = (innerW - gap) / 2;
  int by = y + 76;
  drawButton(innerX, by, halfW, 20, "RUN PREFLIGHT", color(55, 82, 68));
  drawButton(innerX + halfW + gap, by, halfW, 20,
    dcrteImportedPolicy == InvalidDomainPolicy.UNSIGNED_PREVIEW ? "UNSIGNED ACTIVE" : "USE UNSIGNED PREVIEW", color(72, 62, 42));
  by += 24;
  drawButton(innerX, by, halfW, 20, dcrtePreflightShowBlockers ? "BLOCKERS SHOWN" : "SHOW BLOCKERS",
    dcrtePreflightShowBlockers ? color(90, 47, 53) : color(48, 61, 66));
  drawButton(innerX + halfW + gap, by, halfW, 20, dcrtePreflightShowWarnings ? "WARNINGS SHOWN" : "SHOW WARNINGS",
    dcrtePreflightShowWarnings ? color(86, 72, 39) : color(48, 61, 66));
  by += 24;
  drawButton(innerX, by, halfW, 20, "PREVIOUS ISSUE", color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "NEXT ISSUE", color(48, 72, 77));
  by += 24;
  drawButton(innerX, by, halfW, 20, "EXPORT REPORT JSON", color(48, 72, 77));
  drawButton(innerX + halfW + gap, by, halfW, 20, "COPY SUMMARY", color(48, 72, 77));
  by += 24;
  String[] overlayNames = {"ISSUE", "LOOPS", "COMPONENTS", "INTERSECTIONS", "SIGN VOXELS"};
  drawButton(innerX, by, innerW, 20, "OVERLAY " + overlayNames[dcrtePreflightOverlayMode], color(46, 66, 78));

  int stageY = by + 30;
  fill(112, 178, 188);
  textSize(8);
  text("STAGE QUALIFICATION", innerX, stageY);
  int stageCellW = (innerW - 6) / 2;
  String[] stages = dcrtePreflightStageNames();
  for (int i = 0; i < stages.length; i++) {
    int sx = innerX + (i % 2) * (stageCellW + 6);
    int sy = stageY + 13 + (i / 2) * 14;
    DCRTEPreflightStageRecord stage = report == null ? null : report.stageRecord(stages[i]);
    color stageColor = dcrteStageColor(stage == null ? DCRTEPreflightStageState.NOT_RUN : stage.state);
    noStroke(); fill(stageColor); rect(sx, sy + 2, 5, 5);
    fill(142, 174, 180); textSize(7); text(stages[i] + "  " + (stage == null ? "not_run" : stage.state.id()), sx + 9, sy);
  }

  int detailY = stageY + 116;
  ArrayList<DomainDiagnostic> issues = dcrteVisiblePreflightIssues();
  dcrtePreflightClampIssueIndex();
  DomainDiagnostic issue = issues.size() == 0 ? null : issues.get(dcrtePreflightIssueIndex);
  fill(112, 178, 188); textSize(8);
  int boundaryEdges = report == null || report.meshReport == null ? 0 : report.meshReport.boundaryEdgeCount;
  int nonmanifold = report == null || report.meshReport == null ? 0 : report.meshReport.nonManifoldEdgeCount;
  int intersections = report == null || report.selfIntersectionReport == null ? 0 : report.selfIntersectionReport.confirmedIntersectionCount;
  text("NUMERICAL LEGEND", innerX, detailY);
  fill(150, 184, 190);
  text("boundary edges " + boundaryEdges + "   loops " + (report == null ? 0 : report.boundaryLoops.size())
    + "   nonmanifold " + nonmanifold, innerX, detailY + 13);
  text("components " + (report == null ? 0 : report.componentCount) + "   intersections " + intersections
    + "   resolution " + dcrteImportedResolution + "^3", innerX, detailY + 25);
  text("issue " + (issues.size() == 0 ? "0/0" : (dcrtePreflightIssueIndex + 1) + "/" + issues.size()), innerX, detailY + 37);
  if (issue != null) {
    fill(dcrteSeverityColor(issue.severity));
    text(issue.code + "  [" + issue.stage + "]", innerX, detailY + 51);
    fill(190, 204, 206);
    text(shortText(issue.title, 46), innerX, detailY + 63);
    fill(142, 174, 180);
    text(shortText(issue.message, 50), innerX, detailY + 75);
    text("count " + (issue.count < 0 ? "-" : str(issue.count))
      + "  value " + (!dcrteFinite(issue.value) ? "-" : nf(issue.value, 1, 4))
      + "  threshold " + (!dcrteFinite(issue.threshold) ? "-" : nf(issue.threshold, 1, 4)), innerX, detailY + 87);
    text("action  " + shortText(issue.recommendedAction, 42), innerX, detailY + 99);
  } else {
    fill(98, 232, 168);
    text("No diagnostics match the active filters.", innerX, detailY + 53);
  }
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
  int w = max(250, min(360, previewW - 400));
  int x = previewX + 12;
  int y = previewY + 12;
  int innerX = x + 10;
  int innerW = w - 20;
  int gap = 6;
  int halfW = (innerW - gap) / 2;
  int by = y + 76;
  if (over(innerX, by, halfW, 20)) { dcrteImportedAttemptPreflightReport = null; runDcrteImportedPreflight(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { useDcrteUnsignedPreview(); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { dcrtePreflightShowBlockers = !dcrtePreflightShowBlockers; dcrtePreflightClampIssueIndex(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { dcrtePreflightShowWarnings = !dcrtePreflightShowWarnings; dcrtePreflightClampIssueIndex(); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { stepDcrtePreflightIssue(-1); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { stepDcrtePreflightIssue(1); return true; }
  by += 24;
  if (over(innerX, by, halfW, 20)) { exportDcrtePreflightReportJSON(); return true; }
  if (over(innerX + halfW + gap, by, halfW, 20)) { copyDcrtePreflightSummary(); return true; }
  by += 24;
  if (over(innerX, by, innerW, 20)) { dcrtePreflightOverlayMode = (dcrtePreflightOverlayMode + 1) % 5; return true; }
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
