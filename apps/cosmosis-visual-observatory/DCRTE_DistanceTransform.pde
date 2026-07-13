/* DCRTE-ET Milestone 2 exact squared Euclidean distance transform on an isotropic grid. */

class DCRTEGridDistanceTransform {
  static final float INF = 1.0e20f;

  float[] squaredDistance(boolean[] boundary, VolumeSpec spec) {
    if (boundary == null || spec == null || !spec.isValid() || boundary.length != spec.voxelCount()) return new float[0];
    int count = spec.voxelCount();
    float[] distance = new float[count];
    for (int i = 0; i < count; i++) distance[i] = boundary[i] ? 0 : INF;
    int maxLength = max(spec.nx, max(spec.ny, spec.nz));
    float[] input = new float[maxLength];
    float[] output = new float[maxLength];
    int[] sites = new int[maxLength];
    float[] separators = new float[maxLength + 1];

    for (int z = 0; z < spec.nz; z++) for (int y = 0; y < spec.ny; y++) {
      int base = spec.nx * (y + spec.ny * z);
      for (int x = 0; x < spec.nx; x++) input[x] = distance[base + x];
      dcrteDistanceTransform1D(input, output, spec.nx, sites, separators);
      for (int x = 0; x < spec.nx; x++) distance[base + x] = output[x];
    }

    for (int z = 0; z < spec.nz; z++) for (int x = 0; x < spec.nx; x++) {
      for (int y = 0; y < spec.ny; y++) input[y] = distance[x + spec.nx * (y + spec.ny * z)];
      dcrteDistanceTransform1D(input, output, spec.ny, sites, separators);
      for (int y = 0; y < spec.ny; y++) distance[x + spec.nx * (y + spec.ny * z)] = output[y];
    }

    for (int y = 0; y < spec.ny; y++) for (int x = 0; x < spec.nx; x++) {
      for (int z = 0; z < spec.nz; z++) input[z] = distance[x + spec.nx * (y + spec.ny * z)];
      dcrteDistanceTransform1D(input, output, spec.nz, sites, separators);
      for (int z = 0; z < spec.nz; z++) distance[x + spec.nx * (y + spec.ny * z)] = output[z];
    }
    return distance;
  }
}

void dcrteDistanceTransform1D(float[] input, float[] output, int length, int[] sites, float[] separators) {
  int first = -1;
  for (int i = 0; i < length; i++) {
    if (input[i] < DCRTEGridDistanceTransform.INF * 0.5f && dcrteFinite(input[i])) {
      first = i;
      break;
    }
  }
  if (first < 0) {
    for (int i = 0; i < length; i++) output[i] = DCRTEGridDistanceTransform.INF;
    return;
  }

  int envelope = 0;
  sites[0] = first;
  separators[0] = Float.NEGATIVE_INFINITY;
  separators[1] = Float.POSITIVE_INFINITY;
  for (int q = first + 1; q < length; q++) {
    if (input[q] >= DCRTEGridDistanceTransform.INF * 0.5f || !dcrteFinite(input[q])) continue;
    float intersection;
    while (true) {
      int p = sites[envelope];
      intersection = ((input[q] + q * q) - (input[p] + p * p)) / (2.0f * q - 2.0f * p);
      if (intersection > separators[envelope] || envelope == 0) break;
      envelope--;
    }
    envelope++;
    sites[envelope] = q;
    separators[envelope] = intersection;
    separators[envelope + 1] = Float.POSITIVE_INFINITY;
  }

  int siteIndex = 0;
  for (int q = 0; q < length; q++) {
    while (separators[siteIndex + 1] < q) siteIndex++;
    int p = sites[siteIndex];
    float delta = q - p;
    output[q] = delta * delta + input[p];
  }
}
