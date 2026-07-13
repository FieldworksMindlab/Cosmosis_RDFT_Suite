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
