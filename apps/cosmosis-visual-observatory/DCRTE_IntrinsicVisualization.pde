/* DCRTE-ET Milestone 3 centerline, frame, and intrinsic scalar diagnostics. */

void drawDcrteIntrinsicVisualization(float previewScale) {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH
      || dcrteIntrinsicBuildResult == null) return;
  IntrinsicBuildResult result = dcrteIntrinsicBuildResult;
  String stateIssue = dcrteIntrinsicStateIssue(result);
  if (stateIssue.length() > 0) {
    if (!dcrteIntrinsicBuildStatus.startsWith("BLOCKED - ")) dcrteIntrinsicBuildStatus = "STALE - " + stateIssue;
    return;
  }
  if (dcrteIntrinsicVisualizationMode == IntrinsicVisualizationMode.AXIAL_SLICES) {
    dcrteDrawIntrinsicAxialSlices(result, previewScale);
  } else if (dcrteIntrinsicVisualizationMode.ordinal() >= IntrinsicVisualizationMode.INTRINSIC_S.ordinal()) {
    dcrteDrawIntrinsicScalarCloud(result, previewScale, dcrteIntrinsicVisualizationMode);
  }
  if (dcrteIntrinsicShowCenterline || dcrteIntrinsicVisualizationMode == IntrinsicVisualizationMode.CENTERLINE
      || dcrteIntrinsicVisualizationMode == IntrinsicVisualizationMode.CENTERLINE_FRAMES) {
    dcrteDrawIntrinsicCenterline(result, previewScale);
  }
  if (dcrteIntrinsicShowFrames || dcrteIntrinsicVisualizationMode == IntrinsicVisualizationMode.CENTERLINE_FRAMES) {
    dcrteDrawIntrinsicFrames(result, previewScale);
  }
}

void dcrteDrawIntrinsicCenterline(IntrinsicBuildResult result, float scale) {
  if (result.centerline == null || result.centerline.points == null) return;
  noFill();
  stroke(255, 234, 94, 245);
  strokeWeight(3.0f);
  beginShape();
  for (int i = 0; i < result.centerline.points.length; i++) {
    CenterlinePoint point = result.centerline.points[i];
    vertex(point.x * scale, point.y * scale, point.z * scale);
  }
  endShape();
  stroke(255, 255, 255, 235);
  strokeWeight(7.0f);
  beginShape(POINTS);
  CenterlinePoint first = result.centerline.points[0];
  CenterlinePoint last = result.centerline.points[result.centerline.points.length - 1];
  vertex(first.x * scale, first.y * scale, first.z * scale);
  vertex(last.x * scale, last.y * scale, last.z * scale);
  endShape();
}

void dcrteDrawIntrinsicFrames(IntrinsicBuildResult result, float scale) {
  if (result.centerline == null || result.centerline.points == null
      || result.frames == null || result.frames.frames == null) return;
  int count = min(result.centerline.points.length, result.frames.frames.length);
  int stride = max(1, dcrteIntrinsicFrameStride);
  for (int i = 0; i < count; i += stride) {
    CenterlinePoint point = result.centerline.points[i];
    TransportFrame frame = result.frames.frames[i];
    float safeRadius = min(point.equivalentRadius, dcrteIntrinsicVisualizationRadiusCap());
    float length = max(0.03f, safeRadius * 0.72f) * scale;
    float px = point.x * scale, py = point.y * scale, pz = point.z * scale;
    strokeWeight(1.6f);
    stroke(70, 226, 255, 220);
    line(px, py, pz, px + frame.nx * length, py + frame.ny * length, pz + frame.nz * length);
    stroke(255, 92, 184, 220);
    line(px, py, pz, px + frame.bx * length, py + frame.by * length, pz + frame.bz * length);
    stroke(112, 255, 142, 190);
    line(px, py, pz, px + frame.tx * length * 0.8f, py + frame.ty * length * 0.8f, pz + frame.tz * length * 0.8f);
  }
}

void dcrteDrawIntrinsicAxialSlices(IntrinsicBuildResult result, float scale) {
  if (result.centerline == null || result.centerline.points == null
      || result.frames == null || result.frames.frames == null) return;
  int count = min(result.centerline.points.length, result.frames.frames.length);
  int stride = max(3, count / 14);
  noFill();
  strokeWeight(1.0f);
  for (int i = 0; i < count; i += stride) {
    CenterlinePoint point = result.centerline.points[i];
    TransportFrame frame = result.frames.frames[i];
    stroke(80, 214, 255, 155);
    beginShape();
    for (int ring = 0; ring <= 32; ring++) {
      float angle = TWO_PI * ring / 32.0f;
      float radius = min(point.equivalentRadius, dcrteIntrinsicVisualizationRadiusCap());
      float x = point.x + radius * (cos(angle) * frame.nx + sin(angle) * frame.bx);
      float y = point.y + radius * (cos(angle) * frame.ny + sin(angle) * frame.by);
      float z = point.z + radius * (cos(angle) * frame.nz + sin(angle) * frame.bz);
      vertex(x * scale, y * scale, z * scale);
    }
    endShape();
  }
}

void dcrteDrawIntrinsicScalarCloud(IntrinsicBuildResult result, float scale, IntrinsicVisualizationMode mode) {
  IntrinsicCoordinateVolume volume = result.volume;
  if (volume == null || volume.spec == null || !volume.isValid()) return;
  int stride = max(1, volume.validCount / 9000);
  int seen = 0;
  strokeWeight(mode == IntrinsicVisualizationMode.AMBIGUITY || mode == IntrinsicVisualizationMode.FALLBACK ? 4.2f : 2.4f);
  beginShape(POINTS);
  for (int z = 0; z < volume.spec.nz; z++) {
    float wz = volume.spec.bounds.minZ + (z + 0.5f) * volume.spec.spacingZ();
    for (int y = 0; y < volume.spec.ny; y++) {
      float wy = volume.spec.bounds.minY + (y + 0.5f) * volume.spec.spacingY();
      for (int x = 0; x < volume.spec.nx; x++) {
        int index = volume.index(x, y, z);
        if (!volume.valid[index]) continue;
        if ((mode == IntrinsicVisualizationMode.AMBIGUITY && !volume.ambiguous[index])
            || (mode == IntrinsicVisualizationMode.FALLBACK && !volume.fallbackUsed[index])) continue;
        if ((seen++ % stride) != 0) continue;
        int c = dcrteIntrinsicScalarColor(volume, index, mode);
        stroke(c);
        float wx = volume.spec.bounds.minX + (x + 0.5f) * volume.spec.spacingX();
        vertex(wx * scale, wy * scale, wz * scale);
      }
    }
  }
  endShape();
}

int dcrteIntrinsicScalarColor(IntrinsicCoordinateVolume volume, int index, IntrinsicVisualizationMode mode) {
  float value = 0;
  if (mode == IntrinsicVisualizationMode.INTRINSIC_S) value = volume.s[index];
  else if (mode == IntrinsicVisualizationMode.INTRINSIC_R) value = constrain(volume.radialDistance[index], 0, 1);
  else if (mode == IntrinsicVisualizationMode.INTRINSIC_RHO) value = constrain(volume.normalizedRadius[index], 0, 1);
  else if (mode == IntrinsicVisualizationMode.INTRINSIC_THETA) value = (volume.theta[index] + PI) / TWO_PI;
  else if (mode == IntrinsicVisualizationMode.INTRINSIC_CONFIDENCE) value = volume.confidence[index];
  else if (mode == IntrinsicVisualizationMode.AMBIGUITY) return color(255, 70, 96, 235);
  else if (mode == IntrinsicVisualizationMode.FALLBACK) return color(255, 168, 52, 235);
  else if (mode == IntrinsicVisualizationMode.INTRINSIC_RESULT) {
    boolean solid = dcrteCoordinateComparisonReport != null
      && dcrteCoordinateComparisonReport.intrinsicFinalMask != null
      && index < dcrteCoordinateComparisonReport.intrinsicFinalMask.length
      ? dcrteCoordinateComparisonReport.intrinsicFinalMask[index]
      : dcrteImportedVolume != null && dcrteImportedVolume.finalSolid != null
        && index < dcrteImportedVolume.finalSolid.length && dcrteImportedVolume.finalSolid[index];
    return solid ? color(255, 238, 92, 230) : color(72, 106, 118, 38);
  }
  else if (mode == IntrinsicVisualizationMode.CARTESIAN_RESULT) {
    boolean solid = dcrteCoordinateComparisonReport != null
      && dcrteCoordinateComparisonReport.cartesianFinalMask != null
      && index < dcrteCoordinateComparisonReport.cartesianFinalMask.length
      ? dcrteCoordinateComparisonReport.cartesianFinalMask[index]
      : dcrteImportedVolume != null && dcrteImportedVolume.finalSolid != null
        && index < dcrteImportedVolume.finalSolid.length && dcrteImportedVolume.finalSolid[index];
    return solid ? color(80, 218, 255, 230) : color(72, 106, 118, 38);
  }
  else return color(72, 106, 118, 55);
  value = constrain(value, 0, 1);
  if (mode == IntrinsicVisualizationMode.INTRINSIC_CONFIDENCE) {
    return color(lerp(255, 62, value), lerp(70, 232, value), lerp(92, 158, value), 220);
  }
  return color(lerp(42, 255, value), lerp(218, 82, value), lerp(255, 194, value), 205);
}

void dcrteDrawIntrinsicScalarSlice(int x, int y, int w, int h) {
  if (dcrteIntrinsicBuildResult == null || dcrteIntrinsicBuildResult.volume == null) return;
  if (dcrteIntrinsicStateIssue(dcrteIntrinsicBuildResult).length() > 0) return;
  IntrinsicCoordinateVolume volume = dcrteIntrinsicBuildResult.volume;
  if (volume.spec == null || !volume.isValid()) return;
  int n = dcrteImportedSliceAxis == DCRTESliceAxis.YZ ? volume.spec.ny : volume.spec.nx;
  int size = min(w, h);
  float cell = size / (float)n;
  int fixedLimit = dcrteImportedSliceAxis == DCRTESliceAxis.XY ? volume.spec.nz
    : dcrteImportedSliceAxis == DCRTESliceAxis.XZ ? volume.spec.ny : volume.spec.nx;
  int fixed = constrain(dcrteImportedSliceIndex, 0, fixedLimit - 1);
  noStroke();
  for (int v = 0; v < n; v++) for (int u = 0; u < n; u++) {
    int gx, gy, gz;
    if (dcrteImportedSliceAxis == DCRTESliceAxis.XY) { gx = u; gy = v; gz = fixed; }
    else if (dcrteImportedSliceAxis == DCRTESliceAxis.XZ) { gx = u; gy = fixed; gz = v; }
    else { gx = fixed; gy = u; gz = v; }
    if (gx < 0 || gy < 0 || gz < 0 || gx >= volume.spec.nx || gy >= volume.spec.ny || gz >= volume.spec.nz) continue;
    int index = volume.index(gx, gy, gz);
    fill(volume.valid[index] ? dcrteIntrinsicScalarColor(volume, index, dcrteIntrinsicVisualizationMode) : color(10, 20, 26));
    rect(x + u * cell, y + (n - 1 - v) * cell, max(1, cell + 0.2f), max(1, cell + 0.2f));
  }
  noFill(); stroke(48, 90, 98); rect(x, y, size, size);
}
