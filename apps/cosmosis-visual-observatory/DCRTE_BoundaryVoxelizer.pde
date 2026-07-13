/* DCRTE-ET Milestone 2 conservative triangle-to-grid boundary voxelization. */

class VoxelBoundaryVolume {
  VolumeSpec spec;
  boolean[] boundary;
  int boundaryCount;
  int sourceTriangleCount;
  long candidateVoxelTests;
  int markedBoundaryVoxels;
  int trianglesWithZeroCandidates;
  int outOfBoundsTriangles;
  float boundaryThreshold;
  float boundaryEpsilon;
  long buildMillis;

  VoxelBoundaryVolume(VolumeSpec spec) {
    this.spec = spec;
    boundary = new boolean[spec == null ? 0 : max(0, spec.voxelCount())];
  }

  int index(int x, int y, int z) { return x + spec.nx * (y + spec.ny * z); }
  boolean isValid() { return spec != null && spec.isValid() && boundary.length == spec.voxelCount() && boundaryCount > 0; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setInt("source_triangle_count", sourceTriangleCount);
    json.setString("candidate_voxel_tests", Long.toString(candidateVoxelTests));
    json.setInt("marked_boundary_voxels", markedBoundaryVoxels);
    json.setInt("boundary_count", boundaryCount);
    json.setFloat("boundary_fraction", boundary.length > 0 ? boundaryCount / (float)boundary.length : 0);
    json.setInt("triangles_with_zero_candidates", trianglesWithZeroCandidates);
    json.setInt("out_of_bounds_triangles", outOfBoundsTriangles);
    json.setFloat("boundary_threshold", boundaryThreshold);
    json.setFloat("boundary_epsilon", boundaryEpsilon);
    json.setLong("build_millis", buildMillis);
    return json;
  }
}

class ConservativeBoundaryVoxelizer {
  VoxelBoundaryVolume build(TriangleMeshData mesh, VolumeSpec spec) {
    long start = millis();
    VoxelBoundaryVolume result = new VoxelBoundaryVolume(spec);
    if (mesh == null || spec == null || !spec.isValid()) return result;
    result.sourceTriangleCount = mesh.triangleCount;
    float dx = spec.spacingX();
    float dy = spec.spacingY();
    float dz = spec.spacingZ();
    float voxelDiagonal = sqrt(dx * dx + dy * dy + dz * dz);
    result.boundaryEpsilon = spec.minSpacing() * 0.00001f;
    result.boundaryThreshold = 0.5f * voxelDiagonal + result.boundaryEpsilon;
    float thresholdSq = result.boundaryThreshold * result.boundaryThreshold;

    for (int t = 0; t < mesh.triangleCount; t++) {
      int ia = mesh.ia(t) * 3;
      int ib = mesh.ib(t) * 3;
      int ic = mesh.ic(t) * 3;
      float ax = mesh.vertices[ia]; float ay = mesh.vertices[ia + 1]; float az = mesh.vertices[ia + 2];
      float bx = mesh.vertices[ib]; float by = mesh.vertices[ib + 1]; float bz = mesh.vertices[ib + 2];
      float cx = mesh.vertices[ic]; float cy = mesh.vertices[ic + 1]; float cz = mesh.vertices[ic + 2];
      float minX = min(ax, min(bx, cx)) - result.boundaryThreshold;
      float minY = min(ay, min(by, cy)) - result.boundaryThreshold;
      float minZ = min(az, min(bz, cz)) - result.boundaryThreshold;
      float maxX = max(ax, max(bx, cx)) + result.boundaryThreshold;
      float maxY = max(ay, max(by, cy)) + result.boundaryThreshold;
      float maxZ = max(az, max(bz, cz)) + result.boundaryThreshold;
      if (minX < spec.bounds.minX || minY < spec.bounds.minY || minZ < spec.bounds.minZ
          || maxX > spec.bounds.maxX || maxY > spec.bounds.maxY || maxZ > spec.bounds.maxZ) {
        if (mesh.worldBounds.minX < spec.bounds.minX || mesh.worldBounds.minY < spec.bounds.minY || mesh.worldBounds.minZ < spec.bounds.minZ
            || mesh.worldBounds.maxX > spec.bounds.maxX || mesh.worldBounds.maxY > spec.bounds.maxY || mesh.worldBounds.maxZ > spec.bounds.maxZ) {
          result.outOfBoundsTriangles++;
        }
      }
      int x0 = dcrteFirstVoxelCenterAtOrAbove(minX, spec.bounds.minX, dx, spec.nx);
      int y0 = dcrteFirstVoxelCenterAtOrAbove(minY, spec.bounds.minY, dy, spec.ny);
      int z0 = dcrteFirstVoxelCenterAtOrAbove(minZ, spec.bounds.minZ, dz, spec.nz);
      int x1 = dcrteLastVoxelCenterAtOrBelow(maxX, spec.bounds.minX, dx, spec.nx);
      int y1 = dcrteLastVoxelCenterAtOrBelow(maxY, spec.bounds.minY, dy, spec.ny);
      int z1 = dcrteLastVoxelCenterAtOrBelow(maxZ, spec.bounds.minZ, dz, spec.nz);
      if (x0 > x1 || y0 > y1 || z0 > z1) {
        result.trianglesWithZeroCandidates++;
        continue;
      }
      for (int z = z0; z <= z1; z++) {
        float pz = spec.bounds.minZ + (z + 0.5f) * dz;
        for (int y = y0; y <= y1; y++) {
          float py = spec.bounds.minY + (y + 0.5f) * dy;
          for (int x = x0; x <= x1; x++) {
            float px = spec.bounds.minX + (x + 0.5f) * dx;
            result.candidateVoxelTests++;
            if (dcrtePointTriangleDistanceSq(px, py, pz, ax, ay, az, bx, by, bz, cx, cy, cz) <= thresholdSq) {
              int index = result.index(x, y, z);
              if (!result.boundary[index]) {
                result.boundary[index] = true;
                result.boundaryCount++;
              }
            }
          }
        }
      }
    }
    result.markedBoundaryVoxels = result.boundaryCount;
    result.buildMillis = millis() - start;
    return result;
  }
}

int dcrteFirstVoxelCenterAtOrAbove(float world, float minimum, float spacing, int count) {
  return constrain((int)Math.ceil((world - minimum) / spacing - 0.5), 0, count - 1);
}

int dcrteLastVoxelCenterAtOrBelow(float world, float minimum, float spacing, int count) {
  return constrain((int)Math.floor((world - minimum) / spacing - 0.5), 0, count - 1);
}

float dcrtePointTriangleDistanceSq(float px, float py, float pz,
    float ax, float ay, float az, float bx, float by, float bz, float cx, float cy, float cz) {
  float abx = bx - ax; float aby = by - ay; float abz = bz - az;
  float acx = cx - ax; float acy = cy - ay; float acz = cz - az;
  float apx = px - ax; float apy = py - ay; float apz = pz - az;
  float d1 = abx * apx + aby * apy + abz * apz;
  float d2 = acx * apx + acy * apy + acz * apz;
  if (d1 <= 0 && d2 <= 0) return apx * apx + apy * apy + apz * apz;

  float bpx = px - bx; float bpy = py - by; float bpz = pz - bz;
  float d3 = abx * bpx + aby * bpy + abz * bpz;
  float d4 = acx * bpx + acy * bpy + acz * bpz;
  if (d3 >= 0 && d4 <= d3) return bpx * bpx + bpy * bpy + bpz * bpz;

  float vc = d1 * d4 - d3 * d2;
  if (vc <= 0 && d1 >= 0 && d3 <= 0) {
    float v = d1 / (d1 - d3);
    float qx = ax + v * abx; float qy = ay + v * aby; float qz = az + v * abz;
    return dcrteDistanceSq(px, py, pz, qx, qy, qz);
  }

  float cpx = px - cx; float cpy = py - cy; float cpz = pz - cz;
  float d5 = abx * cpx + aby * cpy + abz * cpz;
  float d6 = acx * cpx + acy * cpy + acz * cpz;
  if (d6 >= 0 && d5 <= d6) return cpx * cpx + cpy * cpy + cpz * cpz;

  float vb = d5 * d2 - d1 * d6;
  if (vb <= 0 && d2 >= 0 && d6 <= 0) {
    float w = d2 / (d2 - d6);
    float qx = ax + w * acx; float qy = ay + w * acy; float qz = az + w * acz;
    return dcrteDistanceSq(px, py, pz, qx, qy, qz);
  }

  float va = d3 * d6 - d5 * d4;
  if (va <= 0 && (d4 - d3) >= 0 && (d5 - d6) >= 0) {
    float edgeX = cx - bx; float edgeY = cy - by; float edgeZ = cz - bz;
    float w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
    float qx = bx + w * edgeX; float qy = by + w * edgeY; float qz = bz + w * edgeZ;
    return dcrteDistanceSq(px, py, pz, qx, qy, qz);
  }

  float denominator = va + vb + vc;
  if (abs(denominator) < 0.000000000001f) {
    return min(dcrteSegmentDistanceSq(px, py, pz, ax, ay, az, bx, by, bz),
      min(dcrteSegmentDistanceSq(px, py, pz, bx, by, bz, cx, cy, cz),
      dcrteSegmentDistanceSq(px, py, pz, cx, cy, cz, ax, ay, az)));
  }
  float inverse = 1.0f / denominator;
  float v = vb * inverse;
  float w = vc * inverse;
  float qx = ax + abx * v + acx * w;
  float qy = ay + aby * v + acy * w;
  float qz = az + abz * v + acz * w;
  return dcrteDistanceSq(px, py, pz, qx, qy, qz);
}

float dcrteSegmentDistanceSq(float px, float py, float pz,
    float ax, float ay, float az, float bx, float by, float bz) {
  float dx = bx - ax; float dy = by - ay; float dz = bz - az;
  float lengthSq = dx * dx + dy * dy + dz * dz;
  float t = lengthSq > 0 ? ((px - ax) * dx + (py - ay) * dy + (pz - az) * dz) / lengthSq : 0;
  t = constrain(t, 0, 1);
  return dcrteDistanceSq(px, py, pz, ax + t * dx, ay + t * dy, az + t * dz);
}

float dcrteDistanceSq(float ax, float ay, float az, float bx, float by, float bz) {
  float dx = ax - bx; float dy = ay - by; float dz = az - bz;
  return dx * dx + dy * dy + dz * dz;
}
