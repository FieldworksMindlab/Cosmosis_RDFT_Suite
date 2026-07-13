/* DCRTE-ET Milestone 2 immutable grid-backed signed distance field and quality report. */

class SDFQualityReport {
  ValidationStatus status = ValidationStatus.PASS;
  String algorithm = "grid_euclidean_distance_transform";
  int resolutionX;
  int resolutionY;
  int resolutionZ;
  float voxelSpacing;
  float boundaryThreshold;
  float intersectionTolerance;
  float jitterMagnitude;
  int boundaryVoxelCount;
  int insideVoxelCount;
  int outsideVoxelCount;
  int ambiguousScanlineCount;
  int retriedScanlineCount;
  int failedScanlineCount;
  int deduplicatedIntersectionCount;
  int finiteDistanceCount;
  int nonFiniteDistanceCount;
  int zeroBandCount;
  double referenceMeshVolume;
  double sampledInsideVolume;
  double volumeRelativeError;
  float minSignedDistance;
  float maxSignedDistance;
  long boundaryBuildMillis;
  long insideOutsideMillis;
  long distanceTransformMillis;
  long qualityCheckMillis;
  long totalMillis;
  boolean halfVoxelCorrection;
  boolean signed;
  ArrayList<String> errors = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();

  void addError(String code) { if (!errors.contains(code)) errors.add(code); updateStatus(); }
  void addWarning(String code) { if (!warnings.contains(code)) warnings.add(code); updateStatus(); }
  void updateStatus() {
    if (!errors.isEmpty()) status = ValidationStatus.FAIL;
    else if (!warnings.isEmpty()) status = ValidationStatus.PASS_WITH_WARNINGS;
    else status = ValidationStatus.PASS;
  }
  boolean isValid() { return status != ValidationStatus.FAIL && finiteDistanceCount > 0 && nonFiniteDistanceCount == 0; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("status", status.id());
    json.setString("algorithm", algorithm);
    JSONArray resolution = new JSONArray();
    resolution.setInt(0, resolutionX); resolution.setInt(1, resolutionY); resolution.setInt(2, resolutionZ);
    json.setJSONArray("resolution", resolution);
    json.setFloat("voxel_spacing", voxelSpacing);
    json.setFloat("boundary_threshold", boundaryThreshold);
    json.setFloat("intersection_tolerance", intersectionTolerance);
    json.setFloat("jitter_magnitude", jitterMagnitude);
    json.setInt("boundary_voxel_count", boundaryVoxelCount);
    json.setInt("inside_voxel_count", insideVoxelCount);
    json.setInt("outside_voxel_count", outsideVoxelCount);
    json.setInt("ambiguous_scanline_count", ambiguousScanlineCount);
    json.setInt("retried_scanline_count", retriedScanlineCount);
    json.setInt("failed_scanline_count", failedScanlineCount);
    json.setInt("deduplicated_intersection_count", deduplicatedIntersectionCount);
    json.setInt("finite_distance_count", finiteDistanceCount);
    json.setInt("nonfinite_distance_count", nonFiniteDistanceCount);
    json.setInt("zero_band_count", zeroBandCount);
    json.setDouble("reference_mesh_volume", referenceMeshVolume);
    json.setDouble("sampled_inside_volume", sampledInsideVolume);
    json.setDouble("volume_relative_error", volumeRelativeError);
    json.setFloat("min_signed_distance", minSignedDistance);
    json.setFloat("max_signed_distance", maxSignedDistance);
    json.setLong("boundary_build_millis", boundaryBuildMillis);
    json.setLong("inside_outside_millis", insideOutsideMillis);
    json.setLong("distance_transform_millis", distanceTransformMillis);
    json.setLong("quality_check_millis", qualityCheckMillis);
    json.setLong("total_millis", totalMillis);
    json.setBoolean("half_voxel_correction", halfVoxelCorrection);
    json.setBoolean("signed", signed);
    json.setString("surface_distance_model", "euclidean_distance_to_nearest_boundary_voxel_center");
    json.setJSONArray("errors", dcrteStringListJSON(errors));
    json.setJSONArray("warnings", dcrteStringListJSON(warnings));
    return json;
  }
}

class SignedDistanceVolume {
  final VolumeSpec spec;
  final float[] signedDistance;
  final boolean[] inside;
  final boolean[] boundary;
  float minDistance;
  float maxDistance;
  int finiteCount;
  int nonFiniteCount;
  int zeroBandCount;
  boolean signed;
  SDFQualityReport quality;

  SignedDistanceVolume(VolumeSpec spec, float[] signedDistance, boolean[] inside, boolean[] boundary, boolean signed) {
    this.spec = spec;
    this.signedDistance = signedDistance == null ? new float[0] : signedDistance;
    this.inside = inside == null ? new boolean[this.signedDistance.length] : inside;
    this.boundary = boundary == null ? new boolean[this.signedDistance.length] : boundary;
    this.signed = signed;
    inspect();
  }

  int index(int x, int y, int z) { return x + spec.nx * (y + spec.ny * z); }

  void inspect() {
    minDistance = Float.POSITIVE_INFINITY;
    maxDistance = Float.NEGATIVE_INFINITY;
    finiteCount = 0;
    nonFiniteCount = 0;
    zeroBandCount = 0;
    float zeroBand = spec == null ? 0 : 0.75f * spec.minSpacing();
    for (int i = 0; i < signedDistance.length; i++) {
      float value = signedDistance[i];
      if (!dcrteFinite(value)) { nonFiniteCount++; continue; }
      finiteCount++;
      minDistance = min(minDistance, value);
      maxDistance = max(maxDistance, value);
      if (abs(value) <= zeroBand) zeroBandCount++;
    }
  }

  boolean isValid() {
    int count = spec == null ? -1 : spec.voxelCount();
    return spec != null && spec.isValid() && count > 0
      && signedDistance.length == count && inside.length == count && boundary.length == count
      && finiteCount == count && nonFiniteCount == 0;
  }

  float sampleAtIndex(int x, int y, int z) {
    if (!isValid() || x < 0 || x >= spec.nx || y < 0 || y >= spec.ny || z < 0 || z >= spec.nz) return Float.POSITIVE_INFINITY;
    return signedDistance[index(x, y, z)];
  }

  float sampleWorld(float x, float y, float z) {
    if (!isValid()) return Float.POSITIVE_INFINITY;
    float outsideX = max(spec.bounds.minX - x, max(0, x - spec.bounds.maxX));
    float outsideY = max(spec.bounds.minY - y, max(0, y - spec.bounds.maxY));
    float outsideZ = max(spec.bounds.minZ - z, max(0, z - spec.bounds.maxZ));
    if (outsideX > 0 || outsideY > 0 || outsideZ > 0) {
      return max(0, maxDistance) + sqrt(outsideX * outsideX + outsideY * outsideY + outsideZ * outsideZ);
    }
    float gx = (x - spec.bounds.minX) / spec.spacingX() - 0.5f;
    float gy = (y - spec.bounds.minY) / spec.spacingY() - 0.5f;
    float gz = (z - spec.bounds.minZ) / spec.spacingZ() - 0.5f;
    int x0 = constrain((int)floor(gx), 0, spec.nx - 1);
    int y0 = constrain((int)floor(gy), 0, spec.ny - 1);
    int z0 = constrain((int)floor(gz), 0, spec.nz - 1);
    int x1 = min(spec.nx - 1, x0 + 1);
    int y1 = min(spec.ny - 1, y0 + 1);
    int z1 = min(spec.nz - 1, z0 + 1);
    float tx = constrain(gx - x0, 0, 1);
    float ty = constrain(gy - y0, 0, 1);
    float tz = constrain(gz - z0, 0, 1);
    float c00 = lerp(sampleAtIndex(x0, y0, z0), sampleAtIndex(x1, y0, z0), tx);
    float c10 = lerp(sampleAtIndex(x0, y1, z0), sampleAtIndex(x1, y1, z0), tx);
    float c01 = lerp(sampleAtIndex(x0, y0, z1), sampleAtIndex(x1, y0, z1), tx);
    float c11 = lerp(sampleAtIndex(x0, y1, z1), sampleAtIndex(x1, y1, z1), tx);
    return lerp(lerp(c00, c10, ty), lerp(c01, c11, ty), tz);
  }

  void normalAtIndex(int x, int y, int z, float[] outNormal) {
    int xm = max(0, x - 1); int xp = min(spec.nx - 1, x + 1);
    int ym = max(0, y - 1); int yp = min(spec.ny - 1, y + 1);
    int zm = max(0, z - 1); int zp = min(spec.nz - 1, z + 1);
    float gx = sampleAtIndex(xp, y, z) - sampleAtIndex(xm, y, z);
    float gy = sampleAtIndex(x, yp, z) - sampleAtIndex(x, ym, z);
    float gz = sampleAtIndex(x, y, zp) - sampleAtIndex(x, y, zm);
    dcrteNormalizeVector(gx, gy, gz, outNormal);
  }

  void normalWorld(float x, float y, float z, float[] outNormal) {
    float h = spec.minSpacing();
    float gx = sampleWorld(x + h, y, z) - sampleWorld(x - h, y, z);
    float gy = sampleWorld(x, y + h, z) - sampleWorld(x, y - h, z);
    float gz = sampleWorld(x, y, z + h) - sampleWorld(x, y, z - h);
    dcrteNormalizeVector(gx, gy, gz, outNormal);
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setBoolean("signed", signed);
    json.setFloat("min_distance", minDistance);
    json.setFloat("max_distance", maxDistance);
    json.setInt("finite_count", finiteCount);
    json.setInt("nonfinite_count", nonFiniteCount);
    json.setInt("zero_band_count", zeroBandCount);
    if (quality != null) json.setJSONObject("quality", quality.toJSON());
    return json;
  }
}

class DCRTESignedDistanceBuilder {
  boolean halfVoxelCorrection;

  SignedDistanceVolume build(VoxelBoundaryVolume boundary, InsideOutsideVolume classification,
      double referenceVolume, boolean signed) {
    long totalStart = millis();
    if (boundary == null || boundary.spec == null || !boundary.spec.isValid()) return null;
    VolumeSpec spec = boundary.spec;
    long distanceStart = millis();
    float[] squared = new DCRTEGridDistanceTransform().squaredDistance(boundary.boundary, spec);
    long distanceMillis = millis() - distanceStart;
    float[] values = new float[squared.length];
    boolean[] inside = classification == null ? new boolean[squared.length] : java.util.Arrays.copyOf(classification.inside, classification.inside.length);
    float spacing = spec.minSpacing();
    for (int i = 0; i < values.length; i++) {
      float magnitude = squared[i] >= DCRTEGridDistanceTransform.INF * 0.5f
        ? Float.POSITIVE_INFINITY
        : sqrt(max(0, squared[i])) * spacing;
      if (halfVoxelCorrection && dcrteFinite(magnitude) && !boundary.boundary[i]) magnitude = max(0, magnitude - 0.5f * spacing);
      if (boundary.boundary[i]) values[i] = 0;
      else if (signed && inside[i]) values[i] = -magnitude;
      else values[i] = magnitude;
    }
    SignedDistanceVolume sdf = new SignedDistanceVolume(spec, values, inside,
      java.util.Arrays.copyOf(boundary.boundary, boundary.boundary.length), signed);
    long qualityStart = millis();
    SDFQualityReport quality = new SDFQualityReport();
    quality.resolutionX = spec.nx; quality.resolutionY = spec.ny; quality.resolutionZ = spec.nz;
    quality.voxelSpacing = spacing;
    quality.boundaryThreshold = boundary.boundaryThreshold;
    quality.boundaryVoxelCount = boundary.boundaryCount;
    quality.insideVoxelCount = classification == null ? 0 : classification.insideCount;
    quality.outsideVoxelCount = classification == null ? spec.voxelCount() : classification.outsideCount;
    quality.intersectionTolerance = classification == null ? 0 : classification.intersectionTolerance;
    quality.jitterMagnitude = classification == null ? 0 : classification.jitterMagnitude;
    quality.ambiguousScanlineCount = classification == null ? 0 : classification.ambiguousScanlineCount;
    quality.retriedScanlineCount = classification == null ? 0 : classification.retriedScanlineCount;
    quality.failedScanlineCount = classification == null ? 0 : classification.failedScanlineCount;
    quality.deduplicatedIntersectionCount = classification == null ? 0 : classification.deduplicatedIntersectionCount;
    quality.finiteDistanceCount = sdf.finiteCount;
    quality.nonFiniteDistanceCount = sdf.nonFiniteCount;
    quality.zeroBandCount = sdf.zeroBandCount;
    quality.referenceMeshVolume = referenceVolume;
    quality.sampledInsideVolume = quality.insideVoxelCount * (double)spec.sampleVolume();
    quality.volumeRelativeError = referenceVolume > 0
      ? Math.abs(quality.sampledInsideVolume - referenceVolume) / referenceVolume
      : Double.POSITIVE_INFINITY;
    quality.minSignedDistance = sdf.minDistance;
    quality.maxSignedDistance = sdf.maxDistance;
    quality.boundaryBuildMillis = boundary.buildMillis;
    quality.insideOutsideMillis = classification == null ? 0 : classification.buildMillis;
    quality.distanceTransformMillis = distanceMillis;
    quality.halfVoxelCorrection = halfVoxelCorrection;
    quality.signed = signed;
    if (boundary.boundaryCount == 0) quality.addError("BOUNDARY_VOXELIZATION_EMPTY");
    if (sdf.nonFiniteCount > 0) quality.addError("SDF_NONFINITE");
    if (signed) {
      if (classification == null || classification.failedScanlineCount > 0) quality.addError("INSIDE_OUTSIDE_FAILED");
      if (quality.insideVoxelCount == 0) quality.addError("INSIDE_VOLUME_EMPTY");
      if (quality.insideVoxelCount >= spec.voxelCount()) quality.addError("INSIDE_VOLUME_FULL");
      if (!Double.isFinite(quality.volumeRelativeError) || quality.volumeRelativeError > 0.35) quality.addError("SDF_VOLUME_ERROR_HIGH");
      else {
        double warningThreshold = spec.nx >= 128 ? 0.07 : 0.12;
        if (quality.volumeRelativeError > warningThreshold) quality.addWarning("SDF_VOLUME_ERROR_HIGH");
      }
    } else {
      quality.addWarning("DOMAIN_PREVIEW_ONLY");
      quality.addWarning("DOMAIN_EXPORT_DISABLED");
    }
    quality.qualityCheckMillis = millis() - qualityStart;
    quality.totalMillis = millis() - totalStart + boundary.buildMillis + (classification == null ? 0 : classification.buildMillis);
    quality.updateStatus();
    sdf.quality = quality;
    return sdf;
  }
}

void dcrteNormalizeVector(float x, float y, float z, float[] out) {
  float magnitude = sqrt(x * x + y * y + z * z);
  if (!dcrteFinite(magnitude) || magnitude < 0.000001f) {
    out[0] = 0; out[1] = 1; out[2] = 0;
    return;
  }
  out[0] = x / magnitude; out[1] = y / magnitude; out[2] = z / magnitude;
}
