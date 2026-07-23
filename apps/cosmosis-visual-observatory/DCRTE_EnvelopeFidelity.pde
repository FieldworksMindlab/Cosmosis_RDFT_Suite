/* DCRTE-ET Milestone 6 source-envelope fidelity measurements. */

class ExteriorEnvelopeFidelityReport {
  int sourceBoundaryReferenceCount;
  int sourceBoundaryCoveredCount;
  float sourceBoundaryCoverage;
  int materialOutsideCount;
  int exteriorLeakCount;
  float sourceVertexDistanceMeanWorld = Float.NaN;
  float sourceVertexDistanceP95World = Float.NaN;
  float sourceVertexDistanceMaxWorld = Float.NaN;
  float sourceVertexDistanceMeanMM = Float.NaN;
  float sourceVertexDistanceP95MM = Float.NaN;
  float sourceVertexDistanceMaxMM = Float.NaN;
  float materialBoundarySdfMeanWorld = Float.NaN;
  float materialBoundarySdfP95World = Float.NaN;
  float materialBoundarySdfMaxWorld = Float.NaN;
  boolean valid;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("version", "1.0-m6");
    json.setInt("source_boundary_reference_voxels", sourceBoundaryReferenceCount);
    json.setInt("source_boundary_covered_voxels", sourceBoundaryCoveredCount);
    json.setFloat("source_boundary_coverage", sourceBoundaryCoverage);
    json.setInt("material_outside_voxels", materialOutsideCount);
    json.setInt("exterior_leak_voxels", exteriorLeakCount);
    json.setFloat("source_vertex_distance_mean_world", sourceVertexDistanceMeanWorld);
    json.setFloat("source_vertex_distance_p95_world", sourceVertexDistanceP95World);
    json.setFloat("source_vertex_distance_max_world", sourceVertexDistanceMaxWorld);
    json.setFloat("source_vertex_distance_mean_mm", sourceVertexDistanceMeanMM);
    json.setFloat("source_vertex_distance_p95_mm", sourceVertexDistanceP95MM);
    json.setFloat("source_vertex_distance_max_mm", sourceVertexDistanceMaxMM);
    json.setFloat("material_boundary_sdf_mean_world", materialBoundarySdfMeanWorld);
    json.setFloat("material_boundary_sdf_p95_world", materialBoundarySdfP95World);
    json.setFloat("material_boundary_sdf_max_world", materialBoundarySdfMaxWorld);
    json.setBoolean("valid", valid);
    json.setString("claim_scope", "voxelized source-envelope fidelity; not exact CAD coincidence");
    return json;
  }
}

class ExteriorEnvelopeFidelityAnalyzer {
  ExteriorEnvelopeFidelityReport analyze(FabricationCompositionVolume volume,
      SignedDistanceVolume sdf, TriangleMeshData sourceWorldMesh) {
    ExteriorEnvelopeFidelityReport report = new ExteriorEnvelopeFidelityReport();
    if (volume == null || !volume.isValid() || sdf == null || !sdf.isValid()) return report;
    boolean[] material = volume.regularizedMaterialCount > 0
      ? volume.regularizedMaterial : volume.composedMaterial;
    float spacing = volume.spec.minSpacing();
    float boundaryEpsilon = max(0, volume.boundaryEpsilonWorld);
    ArrayList<Float> boundarySdf = new ArrayList<Float>();
    for (int i = 0; i < material.length; i++) {
      float distance = sdf.signedDistance[i];
      if (dcrteFinite(distance) && abs(distance) <= boundaryEpsilon) {
        report.sourceBoundaryReferenceCount++;
        if (material[i]) report.sourceBoundaryCoveredCount++;
      }
      if (material[i] && !volume.domainInside[i]) {
        report.materialOutsideCount++;
        if (dcrteFinite(distance) && distance > 0) report.exteriorLeakCount++;
      }
      if (material[i] && dcrteM6MaskBoundary(material, i, volume.spec)
          && dcrteFinite(distance)) boundarySdf.add(abs(distance));
    }
    report.sourceBoundaryCoverage = report.sourceBoundaryReferenceCount == 0 ? 0
      : report.sourceBoundaryCoveredCount / (float)report.sourceBoundaryReferenceCount;
    float[] materialDistances = dcrteM6FloatList(boundarySdf);
    float[] materialStats = dcrteM6Stats(materialDistances);
    report.materialBoundarySdfMeanWorld = materialStats[0];
    report.materialBoundarySdfP95World = materialStats[1];
    report.materialBoundarySdfMaxWorld = materialStats[2];

    if (sourceWorldMesh != null && sourceWorldMesh.vertexCount > 0) {
      float[] vertexDistances = new float[sourceWorldMesh.vertexCount];
      for (int v = 0; v < sourceWorldMesh.vertexCount; v++) {
        vertexDistances[v] = nearestMaterialDistance(sourceWorldMesh.vx(v), sourceWorldMesh.vy(v),
          sourceWorldMesh.vz(v), material, volume.spec, 8);
      }
      float[] vertexStats = dcrteM6Stats(vertexDistances);
      report.sourceVertexDistanceMeanWorld = vertexStats[0];
      report.sourceVertexDistanceP95World = vertexStats[1];
      report.sourceVertexDistanceMaxWorld = vertexStats[2];
      float worldToMM = volume.spec.bounds == null || volume.spec.bounds.sizeX() <= 0
        ? 1.0f : foundryScaleMM / volume.spec.bounds.sizeX();
      report.sourceVertexDistanceMeanMM = report.sourceVertexDistanceMeanWorld * worldToMM;
      report.sourceVertexDistanceP95MM = report.sourceVertexDistanceP95World * worldToMM;
      report.sourceVertexDistanceMaxMM = report.sourceVertexDistanceMaxWorld * worldToMM;
    }
    report.valid = report.sourceBoundaryCoverage >= 0.999999f
      && report.materialOutsideCount == 0 && report.exteriorLeakCount == 0
      && (!dcrteFinite(report.sourceVertexDistanceP95World)
        || report.sourceVertexDistanceP95World <= spacing * 2.5f);
    return report;
  }

  float nearestMaterialDistance(float wx, float wy, float wz, boolean[] material,
      VolumeSpec spec, int maxRadius) {
    float fx = (wx - spec.bounds.minX) / spec.bounds.sizeX() * spec.nx - 0.5f;
    float fy = (wy - spec.bounds.minY) / spec.bounds.sizeY() * spec.ny - 0.5f;
    float fz = (wz - spec.bounds.minZ) / spec.bounds.sizeZ() * spec.nz - 0.5f;
    int cx = constrain(round(fx), 0, spec.nx - 1);
    int cy = constrain(round(fy), 0, spec.ny - 1);
    int cz = constrain(round(fz), 0, spec.nz - 1);
    float best = Float.POSITIVE_INFINITY;
    for (int radius = 0; radius <= maxRadius; radius++) {
      boolean foundAtRadius = false;
      for (int dz = -radius; dz <= radius; dz++) {
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (max(abs(dx), max(abs(dy), abs(dz))) != radius) continue;
            int x = cx + dx, y = cy + dy, z = cz + dz;
            if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
            int index = x + spec.nx * (y + spec.ny * z);
            if (!material[index]) continue;
            float vx = lerp(spec.bounds.minX, spec.bounds.maxX, (x + 0.5f) / spec.nx);
            float vy = lerp(spec.bounds.minY, spec.bounds.maxY, (y + 0.5f) / spec.ny);
            float vz = lerp(spec.bounds.minZ, spec.bounds.maxZ, (z + 0.5f) / spec.nz);
            float distance = sqrt((vx - wx) * (vx - wx) + (vy - wy) * (vy - wy) + (vz - wz) * (vz - wz));
            best = min(best, distance);
            foundAtRadius = true;
          }
        }
      }
      if (foundAtRadius) break;
    }
    return best;
  }
}

ExteriorEnvelopeFidelityAnalyzer dcrteEnvelopeFidelityAnalyzer = new ExteriorEnvelopeFidelityAnalyzer();

boolean dcrteM6MaskBoundary(boolean[] mask, int index, VolumeSpec spec) {
  int[] neighbors = dcrteSixNeighbors(index, spec);
  if (neighbors.length < 6) return true;
  for (int i = 0; i < neighbors.length; i++) if (!mask[neighbors[i]]) return true;
  return false;
}

float[] dcrteM6FloatList(ArrayList<Float> values) {
  float[] result = new float[values == null ? 0 : values.size()];
  for (int i = 0; i < result.length; i++) result[i] = values.get(i);
  return result;
}

float[] dcrteM6Stats(float[] values) {
  if (values == null || values.length == 0) return new float[] {Float.NaN, Float.NaN, Float.NaN};
  float[] finite = new float[values.length];
  int count = 0;
  double sum = 0;
  for (int i = 0; i < values.length; i++) {
    if (!dcrteFinite(values[i])) continue;
    finite[count++] = values[i];
    sum += values[i];
  }
  if (count == 0) return new float[] {Float.NaN, Float.NaN, Float.NaN};
  finite = java.util.Arrays.copyOf(finite, count);
  java.util.Arrays.sort(finite);
  int p95 = constrain(ceil((count - 1) * 0.95f), 0, count - 1);
  return new float[] {(float)(sum / count), finite[p95], finite[count - 1]};
}
