/* DCRTE-ET Milestone 2 deterministic X-scanline parity classification. */

class InsideOutsideVolume {
  VolumeSpec spec;
  boolean[] inside;
  int insideCount;
  int outsideCount;
  int ambiguousScanlineCount;
  int retriedScanlineCount;
  int failedScanlineCount;
  int deduplicatedIntersectionCount;
  float intersectionTolerance;
  float jitterMagnitude;
  long buildMillis;

  InsideOutsideVolume(VolumeSpec spec) {
    this.spec = spec;
    inside = new boolean[spec == null ? 0 : max(0, spec.voxelCount())];
  }

  int index(int x, int y, int z) { return x + spec.nx * (y + spec.ny * z); }
  boolean isValid() { return spec != null && spec.isValid() && inside.length == spec.voxelCount() && failedScanlineCount == 0; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setInt("inside_count", insideCount);
    json.setInt("outside_count", outsideCount);
    json.setInt("ambiguous_scanline_count", ambiguousScanlineCount);
    json.setInt("retried_scanline_count", retriedScanlineCount);
    json.setInt("failed_scanline_count", failedScanlineCount);
    json.setInt("deduplicated_intersection_count", deduplicatedIntersectionCount);
    json.setFloat("intersection_tolerance", intersectionTolerance);
    json.setFloat("jitter_magnitude", jitterMagnitude);
    json.setLong("build_millis", buildMillis);
    json.setString("method", "x_scanline_parity");
    json.setString("boundary_policy", "boundary_voxels_admitted_inside");
    return json;
  }
}

class DeterministicInsideOutsideClassifier {
  InsideOutsideVolume classify(TriangleMeshData mesh, VoxelBoundaryVolume boundary) {
    long start = millis();
    VolumeSpec spec = boundary == null ? null : boundary.spec;
    InsideOutsideVolume result = new InsideOutsideVolume(spec);
    if (mesh == null || boundary == null || spec == null || !spec.isValid()) return result;
    result.intersectionTolerance = 0.20f * spec.minSpacing();
    result.jitterMagnitude = 0.0001f * spec.minSpacing();
    float[] intersections = new float[max(8, mesh.triangleCount)];
    float[] offsetsY = new float[] {0, result.jitterMagnitude, 0, result.jitterMagnitude};
    float[] offsetsZ = new float[] {0, 0, result.jitterMagnitude, result.jitterMagnitude};

    for (int z = 0; z < spec.nz; z++) {
      float worldZ = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float worldY = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        int uniqueCount = -1;
        boolean retried = false;
        for (int attempt = 0; attempt < offsetsY.length; attempt++) {
          int rawCount = dcrteCollectXIntersections(mesh, worldY + offsetsY[attempt], worldZ + offsetsZ[attempt], intersections);
          java.util.Arrays.sort(intersections, 0, rawCount);
          uniqueCount = dcrteDeduplicateIntersections(intersections, rawCount, result.intersectionTolerance);
          result.deduplicatedIntersectionCount += rawCount - uniqueCount;
          if ((uniqueCount & 1) == 0) break;
          if (attempt == 0) result.ambiguousScanlineCount++;
          retried = true;
        }
        if (retried) result.retriedScanlineCount++;
        if (uniqueCount < 0 || (uniqueCount & 1) != 0) {
          result.failedScanlineCount++;
          continue;
        }
        int crossing = 0;
        boolean rowInside = false;
        for (int x = 0; x < spec.nx; x++) {
          float worldX = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          while (crossing < uniqueCount && intersections[crossing] <= worldX) {
            rowInside = !rowInside;
            crossing++;
          }
          if (rowInside) result.inside[result.index(x, y, z)] = true;
        }
      }
    }

    for (int i = 0; i < result.inside.length; i++) {
      if (boundary.boundary[i]) result.inside[i] = true;
      if (result.inside[i]) result.insideCount++;
      else result.outsideCount++;
    }
    result.buildMillis = millis() - start;
    return result;
  }
}

int dcrteCollectXIntersections(TriangleMeshData mesh, float py, float pz, float[] output) {
  int count = 0;
  final float projectedAreaTolerance = 0.0000000001f;
  final float barycentricTolerance = 0.000001f;
  for (int t = 0; t < mesh.triangleCount; t++) {
    int ai = mesh.ia(t) * 3;
    int bi = mesh.ib(t) * 3;
    int ci = mesh.ic(t) * 3;
    float ax = mesh.vertices[ai]; float ay = mesh.vertices[ai + 1]; float az = mesh.vertices[ai + 2];
    float bx = mesh.vertices[bi]; float by = mesh.vertices[bi + 1]; float bz = mesh.vertices[bi + 2];
    float cx = mesh.vertices[ci]; float cy = mesh.vertices[ci + 1]; float cz = mesh.vertices[ci + 2];
    float denominator = (by - cy) * (az - cz) + (cz - bz) * (ay - cy);
    if (abs(denominator) <= projectedAreaTolerance) continue;
    float u = ((by - cy) * (pz - cz) + (cz - bz) * (py - cy)) / denominator;
    float v = ((cy - ay) * (pz - cz) + (az - cz) * (py - cy)) / denominator;
    float w = 1.0f - u - v;
    if (u < -barycentricTolerance || v < -barycentricTolerance || w < -barycentricTolerance) continue;
    output[count++] = u * ax + v * bx + w * cx;
  }
  return count;
}

int dcrteDeduplicateIntersections(float[] values, int count, float tolerance) {
  if (count <= 1) return count;
  int write = 1;
  float clusterSum = values[0];
  int clusterCount = 1;
  for (int i = 1; i < count; i++) {
    float clusterMean = clusterSum / clusterCount;
    if (abs(values[i] - clusterMean) <= tolerance) {
      clusterSum += values[i];
      clusterCount++;
    } else {
      values[write - 1] = clusterMean;
      clusterSum = values[i];
      clusterCount = 1;
      write++;
    }
  }
  values[write - 1] = clusterSum / clusterCount;
  return write;
}
