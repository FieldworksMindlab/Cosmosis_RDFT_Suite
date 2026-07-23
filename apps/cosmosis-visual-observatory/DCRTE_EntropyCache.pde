/* DCRTE-ET Milestone 5 flat entropy caches and exact incremental verification. */

class EntropyCacheVerification {
  float maximumOccupancyError;
  float maximumFieldError;
  int occupancyMismatchCount;
  int fieldMismatchCount;
  boolean pass;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setFloat("maximum_occupancy_error", maximumOccupancyError);
    json.setFloat("maximum_field_error", maximumFieldError);
    json.setInt("occupancy_mismatch_count", occupancyMismatchCount);
    json.setInt("field_mismatch_count", fieldMismatchCount);
    json.setBoolean("pass", pass);
    return json;
  }
}

class EntropyCache {
  final VolumeSpec spec;
  final float[] occupancyEntropy;
  final float[] fieldEntropy;
  final int[] occupancySupport;
  final int[] fieldSupport;
  final boolean[] occupancyValid;
  final boolean[] fieldValid;
  final int[] affectedMarks;
  int markToken = 1;
  int validOccupancyCount;
  int validFieldCount;
  String cacheHash = "";
  EntropyContext context;
  BinaryOccupancyEntropy occupancyModel;
  FieldHistogramEntropy fieldModel;

  EntropyCache(EntropyContext context, BinaryOccupancyEntropy occupancyModel,
      FieldHistogramEntropy fieldModel) {
    this.context = context;
    this.spec = context.candidate.spec;
    int count = spec.voxelCount();
    occupancyEntropy = new float[count];
    fieldEntropy = new float[count];
    occupancySupport = new int[count];
    fieldSupport = new int[count];
    occupancyValid = new boolean[count];
    fieldValid = new boolean[count];
    affectedMarks = new int[count];
    this.occupancyModel = occupancyModel;
    this.fieldModel = fieldModel;
  }

  void build(PropagationState state) {
    validOccupancyCount = 0;
    validFieldCount = 0;
    for (int i = 0; i < occupancyEntropy.length; i++) {
      if (!context.candidate.candidateSolid[i]) continue;
      LocalEntropySample occupancy = occupancyModel.sampleAt(i, state);
      occupancyEntropy[i] = occupancy.entropy;
      occupancySupport[i] = occupancy.supportCount;
      occupancyValid[i] = occupancy.valid;
      if (occupancy.valid) validOccupancyCount++;
      LocalEntropySample field = fieldModel.sampleAt(i, state);
      fieldEntropy[i] = field.entropy;
      fieldSupport[i] = field.supportCount;
      fieldValid[i] = field.valid;
      if (field.valid) validFieldCount++;
    }
    cacheHash = computeHash();
  }

  void updateAffected(SchedulerBatch committedBatch, PropagationState state) {
    if (committedBatch == null || committedBatch.activatedIndices == null
        || committedBatch.activatedIndices.length == 0) {
      cacheHash = computeHash();
      return;
    }
    if (++markToken == Integer.MAX_VALUE) {
      java.util.Arrays.fill(affectedMarks, 0);
      markToken = 1;
    }
    int radius = dcrteEntropyRadius(context.config);
    for (int a = 0; a < committedBatch.activatedIndices.length; a++) {
      int activationIndex = committedBatch.activatedIndices[a];
      int ax = activationIndex % spec.nx;
      int yz = activationIndex / spec.nx;
      int ay = yz % spec.ny;
      int az = yz / spec.ny;
      for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
        if (!dcrteEntropyOffsetIncluded(-dx, -dy, -dz, context)) continue;
        int x = ax + dx, y = ay + dy, z = az + dz;
        if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
        int center = x + spec.nx * (y + spec.ny * z);
        if (!context.candidate.candidateSolid[center] || affectedMarks[center] == markToken) continue;
        affectedMarks[center] = markToken;
        LocalEntropySample sample = occupancyModel.sampleAt(center, state);
        if (occupancyValid[center] && !sample.valid) validOccupancyCount--;
        else if (!occupancyValid[center] && sample.valid) validOccupancyCount++;
        occupancyEntropy[center] = sample.entropy;
        occupancySupport[center] = sample.supportCount;
        occupancyValid[center] = sample.valid;
      }
    }
    cacheHash = computeHash();
  }

  EntropyCacheVerification verifyAgainstFullRecompute(PropagationState state, float tolerance) {
    EntropyCacheVerification result = new EntropyCacheVerification();
    for (int i = 0; i < occupancyEntropy.length; i++) if (context.candidate.candidateSolid[i]) {
      LocalEntropySample occupancy = occupancyModel.sampleAt(i, state);
      float occupancyError = abs(occupancy.entropy - occupancyEntropy[i]);
      result.maximumOccupancyError = max(result.maximumOccupancyError, occupancyError);
      if (occupancyError > tolerance || occupancy.valid != occupancyValid[i]
          || occupancy.supportCount != occupancySupport[i]) result.occupancyMismatchCount++;
      LocalEntropySample field = fieldModel.sampleAt(i, state);
      float fieldError = abs(field.entropy - fieldEntropy[i]);
      result.maximumFieldError = max(result.maximumFieldError, fieldError);
      if (fieldError > tolerance || field.valid != fieldValid[i]
          || field.supportCount != fieldSupport[i]) result.fieldMismatchCount++;
    }
    result.pass = result.occupancyMismatchCount == 0 && result.fieldMismatchCount == 0
      && result.maximumOccupancyError <= tolerance && result.maximumFieldError <= tolerance;
    return result;
  }

  String computeHash() {
    try {
      java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
      dcrteDigestString(digest, context.candidate.contentHash);
      dcrteDigestString(digest, context.config.canonical());
      for (int i = 0; i < occupancyEntropy.length; i++) if (context.candidate.candidateSolid[i]) {
        dcrteDigestInt(digest, Float.floatToIntBits(occupancyEntropy[i]));
        dcrteDigestInt(digest, Float.floatToIntBits(fieldEntropy[i]));
        dcrteDigestInt(digest, occupancySupport[i]);
        dcrteDigestInt(digest, fieldSupport[i]);
        digest.update((byte)(occupancyValid[i] ? 1 : 0));
        digest.update((byte)(fieldValid[i] ? 1 : 0));
      }
      return dcrteHex(digest.digest());
    } catch (Exception error) {
      return "sha256-error";
    }
  }

  long estimatedBytes() {
    return occupancyEntropy.length * 8L + occupancySupport.length * 8L
      + occupancyValid.length * 2L + affectedMarks.length * 4L;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("valid_occupancy_count", validOccupancyCount);
    json.setInt("valid_field_count", validFieldCount);
    json.setString("cache_hash", cacheHash);
    json.setString("estimated_storage_bytes", Long.toString(estimatedBytes()));
    return json;
  }
}
