/* DCRTE-ET Milestone 2 reversible source-to-observation fit transform. */

class MeshTransform {
  float sourceCenterX;
  float sourceCenterY;
  float sourceCenterZ;
  float worldCenterX;
  float worldCenterY;
  float worldCenterZ;
  float uniformScale = 1;
  float fitScale = 1;
  float scaleMultiplier = 1;
  int rotateXQuarterTurns;
  int rotateYQuarterTurns;
  int rotateZQuarterTurns;
  float fitMargin = 0.08f;
  String mode = "fit_centered_uniform";

  void apply(float x, float y, float z, float[] out) {
    float px = x - sourceCenterX;
    float py = y - sourceCenterY;
    float pz = z - sourceCenterZ;
    dcrteRotateQuarterTurns(px, py, pz, rotateXQuarterTurns, rotateYQuarterTurns, rotateZQuarterTurns, out);
    out[0] = worldCenterX + out[0] * uniformScale;
    out[1] = worldCenterY + out[1] * uniformScale;
    out[2] = worldCenterZ + out[2] * uniformScale;
  }

  void applyInverse(float x, float y, float z, float[] out) {
    float px = (x - worldCenterX) / uniformScale;
    float py = (y - worldCenterY) / uniformScale;
    float pz = (z - worldCenterZ) / uniformScale;
    dcrteRotateQuarterTurnsInverse(px, py, pz, rotateXQuarterTurns, rotateYQuarterTurns, rotateZQuarterTurns, out);
    out[0] = sourceCenterX + out[0];
    out[1] = sourceCenterY + out[1];
    out[2] = sourceCenterZ + out[2];
  }

  boolean isValid() {
    return dcrteFinite(sourceCenterX) && dcrteFinite(sourceCenterY) && dcrteFinite(sourceCenterZ)
      && dcrteFinite(worldCenterX) && dcrteFinite(worldCenterY) && dcrteFinite(worldCenterZ)
      && dcrteFinite(uniformScale) && uniformScale > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("mode", mode);
    JSONArray sourceCenter = new JSONArray();
    sourceCenter.setFloat(0, sourceCenterX); sourceCenter.setFloat(1, sourceCenterY); sourceCenter.setFloat(2, sourceCenterZ);
    JSONArray worldCenter = new JSONArray();
    worldCenter.setFloat(0, worldCenterX); worldCenter.setFloat(1, worldCenterY); worldCenter.setFloat(2, worldCenterZ);
    JSONArray quarterTurns = new JSONArray();
    quarterTurns.setInt(0, rotateXQuarterTurns); quarterTurns.setInt(1, rotateYQuarterTurns); quarterTurns.setInt(2, rotateZQuarterTurns);
    json.setJSONArray("source_center", sourceCenter);
    json.setJSONArray("world_center", worldCenter);
    json.setJSONArray("quarter_turns", quarterTurns);
    json.setFloat("fit_scale", fitScale);
    json.setFloat("scale_multiplier", scaleMultiplier);
    json.setFloat("uniform_scale", uniformScale);
    json.setFloat("fit_margin", fitMargin);
    json.setBoolean("reversible", isValid());
    return json;
  }
}

MeshTransform createDcrteFitTransform(TriangleMeshData source, Bounds3D observerBounds,
    int rotateX, int rotateY, int rotateZ, float fitMargin, float scaleMultiplier) {
  if (source == null || source.sourceBounds == null || !source.sourceBounds.isValid()
      || observerBounds == null || !observerBounds.isValid()) return null;
  MeshTransform transform = new MeshTransform();
  transform.sourceCenterX = source.sourceBounds.centerX();
  transform.sourceCenterY = source.sourceBounds.centerY();
  transform.sourceCenterZ = source.sourceBounds.centerZ();
  transform.worldCenterX = observerBounds.centerX();
  transform.worldCenterY = observerBounds.centerY();
  transform.worldCenterZ = observerBounds.centerZ();
  transform.rotateXQuarterTurns = dcrteNormalizeQuarterTurns(rotateX);
  transform.rotateYQuarterTurns = dcrteNormalizeQuarterTurns(rotateY);
  transform.rotateZQuarterTurns = dcrteNormalizeQuarterTurns(rotateZ);
  transform.fitMargin = constrain(fitMargin, 0, min(observerBounds.sizeX(), min(observerBounds.sizeY(), observerBounds.sizeZ())) * 0.45f);
  transform.scaleMultiplier = constrain(scaleMultiplier, 0.35f, 1.0f);

  float[] corners = new float[] {
    source.sourceBounds.minX, source.sourceBounds.minY, source.sourceBounds.minZ,
    source.sourceBounds.maxX, source.sourceBounds.minY, source.sourceBounds.minZ,
    source.sourceBounds.minX, source.sourceBounds.maxY, source.sourceBounds.minZ,
    source.sourceBounds.maxX, source.sourceBounds.maxY, source.sourceBounds.minZ,
    source.sourceBounds.minX, source.sourceBounds.minY, source.sourceBounds.maxZ,
    source.sourceBounds.maxX, source.sourceBounds.minY, source.sourceBounds.maxZ,
    source.sourceBounds.minX, source.sourceBounds.maxY, source.sourceBounds.maxZ,
    source.sourceBounds.maxX, source.sourceBounds.maxY, source.sourceBounds.maxZ
  };
  float minX = Float.POSITIVE_INFINITY; float minY = Float.POSITIVE_INFINITY; float minZ = Float.POSITIVE_INFINITY;
  float maxX = Float.NEGATIVE_INFINITY; float maxY = Float.NEGATIVE_INFINITY; float maxZ = Float.NEGATIVE_INFINITY;
  float[] rotated = new float[3];
  for (int i = 0; i < corners.length; i += 3) {
    dcrteRotateQuarterTurns(
      corners[i] - transform.sourceCenterX,
      corners[i + 1] - transform.sourceCenterY,
      corners[i + 2] - transform.sourceCenterZ,
      transform.rotateXQuarterTurns, transform.rotateYQuarterTurns, transform.rotateZQuarterTurns, rotated);
    minX = min(minX, rotated[0]); minY = min(minY, rotated[1]); minZ = min(minZ, rotated[2]);
    maxX = max(maxX, rotated[0]); maxY = max(maxY, rotated[1]); maxZ = max(maxZ, rotated[2]);
  }
  float sizeX = maxX - minX;
  float sizeY = maxY - minY;
  float sizeZ = maxZ - minZ;
  float availableX = observerBounds.sizeX() - 2 * transform.fitMargin;
  float availableY = observerBounds.sizeY() - 2 * transform.fitMargin;
  float availableZ = observerBounds.sizeZ() - 2 * transform.fitMargin;
  transform.fitScale = min(availableX / sizeX, min(availableY / sizeY, availableZ / sizeZ));
  transform.uniformScale = transform.fitScale * transform.scaleMultiplier;
  return transform.isValid() ? transform : null;
}

void dcrteRotateQuarterTurns(float x, float y, float z, int rx, int ry, int rz, float[] out) {
  float px = x; float py = y; float pz = z;
  for (int i = 0; i < dcrteNormalizeQuarterTurns(rx); i++) {
    float nextY = -pz; pz = py; py = nextY;
  }
  for (int i = 0; i < dcrteNormalizeQuarterTurns(ry); i++) {
    float nextX = pz; pz = -px; px = nextX;
  }
  for (int i = 0; i < dcrteNormalizeQuarterTurns(rz); i++) {
    float nextX = -py; py = px; px = nextX;
  }
  out[0] = px; out[1] = py; out[2] = pz;
}

void dcrteRotateQuarterTurnsInverse(float x, float y, float z, int rx, int ry, int rz, float[] out) {
  float px = x; float py = y; float pz = z;
  for (int i = 0; i < dcrteNormalizeQuarterTurns(-rz); i++) {
    float nextX = -py; py = px; px = nextX;
  }
  for (int i = 0; i < dcrteNormalizeQuarterTurns(-ry); i++) {
    float nextX = pz; pz = -px; px = nextX;
  }
  for (int i = 0; i < dcrteNormalizeQuarterTurns(-rx); i++) {
    float nextY = -pz; pz = py; py = nextY;
  }
  out[0] = px; out[1] = py; out[2] = pz;
}

int dcrteNormalizeQuarterTurns(int value) {
  int normalized = value % 4;
  return normalized < 0 ? normalized + 4 : normalized;
}

void dcrteUpdateWorldReport(MeshDomainReport report, TriangleMeshData worldMesh, MeshTransform transform) {
  if (report == null || worldMesh == null || transform == null) return;
  report.worldBounds = worldMesh.worldBounds;
  report.signedVolumeWorld = report.signedVolumeSource * transform.uniformScale * transform.uniformScale * transform.uniformScale;
  report.absoluteVolumeWorld = Math.abs(report.signedVolumeWorld);
}
