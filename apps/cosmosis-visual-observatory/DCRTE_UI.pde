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
