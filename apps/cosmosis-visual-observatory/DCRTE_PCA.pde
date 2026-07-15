/* DCRTE-ET Milestone 3 dominant-component selection and weighted PCA. */

enum DCRTEPCAWeightingMode {
  UNIFORM_INSIDE,
  DISTANCE_WEIGHTED;

  String id() { return name().toLowerCase(); }
}

class DominantInsideComponent {
  VolumeSpec spec;
  boolean[] mask;
  int componentCount;
  int dominantCount;
  int secondaryCount;
  int totalInsideCount;
  float dominantFraction;
  boolean valid;

  int index(int x, int y, int z) { return x + spec.nx * (y + spec.ny * z); }
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("component_count", componentCount);
    json.setInt("total_inside_voxels", totalInsideCount);
    json.setInt("dominant_voxels", dominantCount);
    json.setInt("secondary_voxels", secondaryCount);
    json.setFloat("dominant_fraction", dominantFraction);
    json.setBoolean("valid", valid);
    return json;
  }
}

class DCRTEDominantComponentSelector {
  DominantInsideComponent select(SignedDistanceVolume sdf) {
    DominantInsideComponent result = new DominantInsideComponent();
    if (sdf == null || !sdf.isValid()) return result;
    result.spec = sdf.spec;
    int count = sdf.spec.voxelCount();
    int[] labels = new int[count];
    java.util.Arrays.fill(labels, -1);
    int[] queue = new int[count];
    int[] componentSizes = new int[max(8, count / 64)];
    int componentCount = 0;
    int largestLabel = -1;
    int largestSize = 0;
    int totalInside = 0;
    for (int i = 0; i < count; i++) if (sdf.inside[i]) totalInside++;
    for (int seedIndex = 0; seedIndex < count; seedIndex++) {
      if (!sdf.inside[seedIndex] || labels[seedIndex] >= 0) continue;
      if (componentCount >= componentSizes.length) componentSizes = java.util.Arrays.copyOf(componentSizes, componentSizes.length * 2);
      int head = 0; int tail = 0;
      queue[tail++] = seedIndex;
      labels[seedIndex] = componentCount;
      while (head < tail) {
        int idx = queue[head++];
        int x = idx % sdf.spec.nx;
        int yz = idx / sdf.spec.nx;
        int y = yz % sdf.spec.ny;
        int z = yz / sdf.spec.ny;
        if (x > 0) tail = enqueue(sdf, labels, queue, tail, idx - 1, componentCount);
        if (x + 1 < sdf.spec.nx) tail = enqueue(sdf, labels, queue, tail, idx + 1, componentCount);
        if (y > 0) tail = enqueue(sdf, labels, queue, tail, idx - sdf.spec.nx, componentCount);
        if (y + 1 < sdf.spec.ny) tail = enqueue(sdf, labels, queue, tail, idx + sdf.spec.nx, componentCount);
        int plane = sdf.spec.nx * sdf.spec.ny;
        if (z > 0) tail = enqueue(sdf, labels, queue, tail, idx - plane, componentCount);
        if (z + 1 < sdf.spec.nz) tail = enqueue(sdf, labels, queue, tail, idx + plane, componentCount);
      }
      componentSizes[componentCount] = tail;
      if (tail > largestSize) { largestSize = tail; largestLabel = componentCount; }
      componentCount++;
    }
    result.mask = new boolean[count];
    for (int i = 0; i < count; i++) result.mask[i] = labels[i] == largestLabel;
    result.componentCount = componentCount;
    result.dominantCount = largestSize;
    result.totalInsideCount = totalInside;
    result.secondaryCount = max(0, totalInside - largestSize);
    result.dominantFraction = totalInside == 0 ? 0 : largestSize / (float)totalInside;
    result.valid = largestSize > 0;
    return result;
  }

  int enqueue(SignedDistanceVolume sdf, int[] labels, int[] queue, int tail, int idx, int label) {
    if (!sdf.inside[idx] || labels[idx] >= 0) return tail;
    labels[idx] = label;
    queue[tail] = idx;
    return tail + 1;
  }
}

class PCAFrame {
  float centerX, centerY, centerZ;
  float axis1X, axis1Y, axis1Z;
  float axis2X, axis2Y, axis2Z;
  float axis3X, axis3Y, axis3Z;
  float eigenvalue1, eigenvalue2, eigenvalue3;
  float narrowEndRadius = Float.NaN;
  float broadEndRadius = Float.NaN;
  String signPolicy = "unresolved";
  boolean valid;

  void flipLongitudinal() {
    axis1X = -axis1X; axis1Y = -axis1Y; axis1Z = -axis1Z;
    axis3X = -axis3X; axis3Y = -axis3Y; axis3Z = -axis3Z;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    JSONArray center = new JSONArray();
    center.setFloat(0, centerX); center.setFloat(1, centerY); center.setFloat(2, centerZ);
    json.setJSONArray("center", center);
    json.setJSONArray("axis_1", dcrteVectorJSON(axis1X, axis1Y, axis1Z));
    json.setJSONArray("axis_2", dcrteVectorJSON(axis2X, axis2Y, axis2Z));
    json.setJSONArray("axis_3", dcrteVectorJSON(axis3X, axis3Y, axis3Z));
    JSONArray values = new JSONArray();
    values.setFloat(0, eigenvalue1); values.setFloat(1, eigenvalue2); values.setFloat(2, eigenvalue3);
    json.setJSONArray("eigenvalues", values);
    json.setString("weighting", DCRTEPCAWeightingMode.DISTANCE_WEIGHTED.id());
    json.setString("sign_policy", signPolicy);
    if (dcrteFinite(narrowEndRadius)) json.setFloat("s0_end_radius", narrowEndRadius);
    if (dcrteFinite(broadEndRadius)) json.setFloat("s1_end_radius", broadEndRadius);
    json.setBoolean("valid", valid);
    return json;
  }
}

class DCRTEWeightedPCA {
  PCAFrame compute(SignedDistanceVolume sdf, DominantInsideComponent component, DCRTEPCAWeightingMode mode) {
    PCAFrame result = new PCAFrame();
    if (sdf == null || component == null || !component.valid) return result;
    VolumeSpec spec = sdf.spec;
    double weightSum = 0;
    double cx = 0, cy = 0, cz = 0;
    float minimumWeight = spec.minSpacing() * 0.25f;
    for (int z = 0; z < spec.nz; z++) {
      float wz = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float wy = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        for (int x = 0; x < spec.nx; x++) {
          int idx = x + spec.nx * (y + spec.ny * z);
          if (!component.mask[idx]) continue;
          float wx = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          double weight = mode == DCRTEPCAWeightingMode.UNIFORM_INSIDE ? 1.0 : max(minimumWeight, -sdf.signedDistance[idx]);
          weightSum += weight; cx += weight * wx; cy += weight * wy; cz += weight * wz;
        }
      }
    }
    if (weightSum <= 0 || !Double.isFinite(weightSum)) return result;
    cx /= weightSum; cy /= weightSum; cz /= weightSum;
    double[][] covariance = new double[3][3];
    for (int z = 0; z < spec.nz; z++) {
      float wz = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float wy = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        for (int x = 0; x < spec.nx; x++) {
          int idx = x + spec.nx * (y + spec.ny * z);
          if (!component.mask[idx]) continue;
          float wx = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          double weight = mode == DCRTEPCAWeightingMode.UNIFORM_INSIDE ? 1.0 : max(minimumWeight, -sdf.signedDistance[idx]);
          double dx = wx - cx, dy = wy - cy, dz = wz - cz;
          covariance[0][0] += weight * dx * dx;
          covariance[0][1] += weight * dx * dy;
          covariance[0][2] += weight * dx * dz;
          covariance[1][1] += weight * dy * dy;
          covariance[1][2] += weight * dy * dz;
          covariance[2][2] += weight * dz * dz;
        }
      }
    }
    covariance[1][0] = covariance[0][1]; covariance[2][0] = covariance[0][2]; covariance[2][1] = covariance[1][2];
    for (int row = 0; row < 3; row++) for (int col = 0; col < 3; col++) covariance[row][col] /= weightSum;
    double[][] vectors = {{1,0,0},{0,1,0},{0,0,1}};
    dcrteJacobiSymmetric3(covariance, vectors);
    int[] order = dcrteEigenvalueOrder(covariance[0][0], covariance[1][1], covariance[2][2]);
    result.centerX = (float)cx; result.centerY = (float)cy; result.centerZ = (float)cz;
    float[][] axes = new float[3][3];
    float[] eigenvalues = new float[3];
    for (int rank = 0; rank < 3; rank++) {
      int column = order[rank];
      eigenvalues[rank] = (float)covariance[column][column];
      axes[rank][0] = (float)vectors[0][column]; axes[rank][1] = (float)vectors[1][column]; axes[rank][2] = (float)vectors[2][column];
      dcrteNormalizeInPlace(axes[rank]);
    }
    float[] cross = new float[3];
    dcrteCross(axes[0], axes[1], cross);
    dcrteNormalizeInPlace(cross);
    axes[2] = cross;
    float[] axis2 = new float[3];
    dcrteCross(axes[2], axes[0], axis2);
    dcrteNormalizeInPlace(axis2);
    axes[1] = axis2;
    result.axis1X = axes[0][0]; result.axis1Y = axes[0][1]; result.axis1Z = axes[0][2];
    result.axis2X = axes[1][0]; result.axis2Y = axes[1][1]; result.axis2Z = axes[1][2];
    result.axis3X = axes[2][0]; result.axis3Y = axes[2][1]; result.axis3Z = axes[2][2];
    result.eigenvalue1 = eigenvalues[0]; result.eigenvalue2 = eigenvalues[1]; result.eigenvalue3 = eigenvalues[2];
    result.valid = dcrteFinite(result.eigenvalue1) && result.eigenvalue1 > 0
      && dcrteFinite(result.axis1X) && dcrteMagnitude(result.axis1X, result.axis1Y, result.axis1Z) > 0.99f;
    return result;
  }
}

void dcrteJacobiSymmetric3(double[][] a, double[][] v) {
  for (int iteration = 0; iteration < 32; iteration++) {
    int p = 0, q = 1;
    double maximum = Math.abs(a[0][1]);
    if (Math.abs(a[0][2]) > maximum) { p = 0; q = 2; maximum = Math.abs(a[0][2]); }
    if (Math.abs(a[1][2]) > maximum) { p = 1; q = 2; maximum = Math.abs(a[1][2]); }
    if (maximum < 1e-12) break;
    double angle = 0.5 * Math.atan2(2.0 * a[p][q], a[q][q] - a[p][p]);
    double c = Math.cos(angle), s = Math.sin(angle);
    double app = c*c*a[p][p] - 2*s*c*a[p][q] + s*s*a[q][q];
    double aqq = s*s*a[p][p] + 2*s*c*a[p][q] + c*c*a[q][q];
    for (int k = 0; k < 3; k++) {
      if (k == p || k == q) continue;
      double akp = a[k][p], akq = a[k][q];
      a[k][p] = a[p][k] = c * akp - s * akq;
      a[k][q] = a[q][k] = s * akp + c * akq;
    }
    a[p][p] = app; a[q][q] = aqq; a[p][q] = a[q][p] = 0;
    for (int k = 0; k < 3; k++) {
      double vkp = v[k][p], vkq = v[k][q];
      v[k][p] = c * vkp - s * vkq;
      v[k][q] = s * vkp + c * vkq;
    }
  }
}

int[] dcrteEigenvalueOrder(double a, double b, double c) {
  double[] values = {a, b, c};
  int[] order = {0, 1, 2};
  for (int i = 0; i < 2; i++) for (int j = i + 1; j < 3; j++) {
    if (values[order[j]] > values[order[i]]) { int swap = order[i]; order[i] = order[j]; order[j] = swap; }
  }
  return order;
}

JSONArray dcrteVectorJSON(float x, float y, float z) {
  JSONArray array = new JSONArray(); array.setFloat(0, x); array.setFloat(1, y); array.setFloat(2, z); return array;
}

void dcrteCross(float[] a, float[] b, float[] out) {
  out[0] = a[1] * b[2] - a[2] * b[1];
  out[1] = a[2] * b[0] - a[0] * b[2];
  out[2] = a[0] * b[1] - a[1] * b[0];
}

float dcrteDot(float ax, float ay, float az, float bx, float by, float bz) { return ax*bx + ay*by + az*bz; }
float dcrteMagnitude(float x, float y, float z) { return sqrt(x*x + y*y + z*z); }
void dcrteNormalizeInPlace(float[] vector) {
  float length = dcrteMagnitude(vector[0], vector[1], vector[2]);
  if (length <= 0.0000001f || !dcrteFinite(length)) { vector[0] = 1; vector[1] = 0; vector[2] = 0; return; }
  vector[0] /= length; vector[1] /= length; vector[2] /= length;
}
