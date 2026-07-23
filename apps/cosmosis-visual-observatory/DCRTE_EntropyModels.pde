/* DCRTE-ET Milestone 5 declared local entropy models. */

float dcrteBinaryEntropy(int activeCount, int supportCount) {
  if (supportCount <= 0 || activeCount <= 0 || activeCount >= supportCount) return 0;
  double p = activeCount / (double)supportCount;
  double q = 1.0 - p;
  return (float)(-(p * Math.log(p) + q * Math.log(q)) / Math.log(2.0));
}

int dcrteEntropyRadius(EntropyConfiguration config) {
  return config.neighborhoodMode == EntropyNeighborhoodMode.CUBE_RADIUS_2 ? 2 : 1;
}

boolean dcrteEntropyOffsetIncluded(int dx, int dy, int dz, EntropyContext context) {
  if (dx == 0 && dy == 0 && dz == 0) return context.config.includeCenterVoxel;
  if (context.config.neighborhoodMode != EntropyNeighborhoodMode.PROPAGATION_NEIGHBORS) return true;
  int distance = abs(dx) + abs(dy) + abs(dz);
  if (context.propagationNeighborhood == SchedulerNeighborhoodMode.SIX_CONNECTED) return distance == 1;
  if (context.propagationNeighborhood == SchedulerNeighborhoodMode.EIGHTEEN_CONNECTED) return distance <= 2;
  return max(abs(dx), max(abs(dy), abs(dz))) == 1;
}

class BinaryOccupancyEntropy implements EntropyModel {
  EntropyContext context;
  boolean valid;
  String message = "not initialized";

  public void initialize(EntropyContext context) {
    this.context = context;
    valid = context != null && context.isValid();
    message = valid ? "valid" : "entropy context invalid";
  }

  float entropyAt(int centerIndex, PropagationState state, int hypotheticalActiveIndex) {
    if (!valid || state == null || centerIndex < 0 || centerIndex >= state.active.length) return 0;
    VolumeSpec spec = context.candidate.spec;
    int cx = centerIndex % spec.nx;
    int yz = centerIndex / spec.nx;
    int cy = yz % spec.ny;
    int cz = yz / spec.ny;
    int support = 0, active = 0;
    int radius = dcrteEntropyRadius(context.config);
    for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
      if (!dcrteEntropyOffsetIncluded(dx, dy, dz, context)) continue;
      int x = cx + dx, y = cy + dy, z = cz + dz;
      if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
      int index = x + spec.nx * (y + spec.ny * z);
      if (!context.candidate.admitted[index] || !context.candidate.candidateSolid[index]) continue;
      support++;
      if (state.active[index] || index == hypotheticalActiveIndex) active++;
    }
    return support < context.config.minimumSupport ? 0 : dcrteBinaryEntropy(active, support);
  }

  int supportAt(int centerIndex) {
    if (!valid || centerIndex < 0 || centerIndex >= context.candidate.candidateSolid.length) return 0;
    VolumeSpec spec = context.candidate.spec;
    int cx = centerIndex % spec.nx;
    int yz = centerIndex / spec.nx;
    int cy = yz % spec.ny;
    int cz = yz / spec.ny;
    int support = 0;
    int radius = dcrteEntropyRadius(context.config);
    for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
      if (!dcrteEntropyOffsetIncluded(dx, dy, dz, context)) continue;
      int x = cx + dx, y = cy + dy, z = cz + dz;
      if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
      int index = x + spec.nx * (y + spec.ny * z);
      if (context.candidate.admitted[index] && context.candidate.candidateSolid[index]) support++;
    }
    return support;
  }

  int activeCountAt(int centerIndex, PropagationState state) {
    if (!valid || state == null) return 0;
    VolumeSpec spec = context.candidate.spec;
    int cx = centerIndex % spec.nx;
    int yz = centerIndex / spec.nx;
    int cy = yz % spec.ny;
    int cz = yz / spec.ny;
    int active = 0;
    int radius = dcrteEntropyRadius(context.config);
    for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
      if (!dcrteEntropyOffsetIncluded(dx, dy, dz, context)) continue;
      int x = cx + dx, y = cy + dy, z = cz + dz;
      if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
      int index = x + spec.nx * (y + spec.ny * z);
      if (context.candidate.admitted[index] && context.candidate.candidateSolid[index] && state.active[index]) active++;
    }
    return active;
  }

  public LocalEntropySample sampleAt(int centerIndex, PropagationState state) {
    LocalEntropySample sample = new LocalEntropySample();
    sample.supportCount = supportAt(centerIndex);
    sample.activeCount = activeCountAt(centerIndex, state);
    sample.inactiveCandidateCount = max(0, sample.supportCount - sample.activeCount);
    int radius = dcrteEntropyRadius(context.config);
    int possible = context.config.neighborhoodMode == EntropyNeighborhoodMode.PROPAGATION_NEIGHBORS
      ? (context.propagationNeighborhood == SchedulerNeighborhoodMode.SIX_CONNECTED ? 6
        : context.propagationNeighborhood == SchedulerNeighborhoodMode.EIGHTEEN_CONNECTED ? 18 : 26)
      : (int)Math.pow(radius * 2 + 1, 3) - (context.config.includeCenterVoxel ? 0 : 1);
    if (context.config.neighborhoodMode == EntropyNeighborhoodMode.PROPAGATION_NEIGHBORS
        && context.config.includeCenterVoxel) possible++;
    sample.excludedCount = max(0, possible - sample.supportCount);
    sample.activeFraction = sample.supportCount == 0 ? 0 : sample.activeCount / (float)sample.supportCount;
    sample.valid = sample.supportCount >= context.config.minimumSupport;
    sample.entropy = sample.valid ? dcrteBinaryEntropy(sample.activeCount, sample.supportCount) : 0;
    sample.normalizedEntropy = sample.entropy;
    return sample;
  }

  public EntropyDelta evaluateActivation(int activationIndex, PropagationState state) {
    EntropyDelta delta = new EntropyDelta();
    if (!valid || state == null || activationIndex < 0 || activationIndex >= state.active.length
        || state.active[activationIndex] || !context.candidate.candidateSolid[activationIndex]) return delta;
    VolumeSpec spec = context.candidate.spec;
    int ax = activationIndex % spec.nx;
    int yz = activationIndex / spec.nx;
    int ay = yz % spec.ny;
    int az = yz / spec.ny;
    int radius = dcrteEntropyRadius(context.config);
    double beforeSum = 0, afterSum = 0, absSum = 0;
    int affected = 0;
    for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
      if (!dcrteEntropyOffsetIncluded(-dx, -dy, -dz, context)) continue;
      int x = ax + dx, y = ay + dy, z = az + dz;
      if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
      int center = x + spec.nx * (y + spec.ny * z);
      if (!context.candidate.candidateSolid[center] || supportAt(center) < context.config.minimumSupport) continue;
      float before = entropyAt(center, state, -1);
      float after = entropyAt(center, state, activationIndex);
      if (!dcrteFinite(before) || !dcrteFinite(after)) continue;
      beforeSum += before;
      afterSum += after;
      absSum += abs(after - before);
      affected++;
    }
    if (affected == 0) return delta;
    delta.beforeEntropy = (float)(beforeSum / affected);
    delta.afterEntropy = (float)(afterSum / affected);
    delta.deltaEntropy = delta.afterEntropy - delta.beforeEntropy;
    delta.absoluteDeltaEntropy = (float)(absSum / affected);
    delta.neighborhoodMeanBefore = delta.beforeEntropy;
    delta.neighborhoodMeanAfter = delta.afterEntropy;
    delta.neighborhoodMeanDelta = delta.deltaEntropy;
    delta.affectedCenterCount = affected;
    delta.valid = dcrteFinite(delta.deltaEntropy) && dcrteFinite(delta.absoluteDeltaEntropy);
    return delta;
  }

  public EntropySummary summarize(PropagationState state) {
    EntropySummary summary = new EntropySummary();
    if (!valid || state == null) return summary;
    float minValue = Float.POSITIVE_INFINITY, maxValue = Float.NEGATIVE_INFINITY;
    double sum = 0, weighted = 0, weightSum = 0, frontierSum = 0, activeSum = 0;
    int validCount = 0, low = 0, frontierCount = 0, activeCount = 0;
    for (int i = 0; i < state.active.length; i++) if (context.candidate.candidateSolid[i]) {
      LocalEntropySample sample = sampleAt(i, state);
      if (!sample.valid) { low++; continue; }
      float value = context.cache == null ? sample.entropy : context.cache.occupancyEntropy[i];
      sum += value;
      weighted += value * sample.supportCount;
      weightSum += sample.supportCount;
      minValue = min(minValue, value);
      maxValue = max(maxValue, value);
      validCount++;
      if (state.frontier[i]) { frontierSum += value; frontierCount++; }
      if (state.active[i]) { activeSum += value; activeCount++; }
    }
    summary.validSampleCount = validCount;
    summary.lowSupportCount = low;
    summary.meanLocalEntropy = validCount == 0 ? 0 : (float)(sum / validCount);
    summary.weightedMeanLocalEntropy = weightSum == 0 ? 0 : (float)(weighted / weightSum);
    summary.frontierMeanEntropy = frontierCount == 0 ? 0 : (float)(frontierSum / frontierCount);
    summary.activeRegionMeanEntropy = activeCount == 0 ? 0 : (float)(activeSum / activeCount);
    summary.minLocalEntropy = validCount == 0 ? 0 : minValue;
    summary.maxLocalEntropy = validCount == 0 ? 0 : maxValue;
    return summary;
  }

  public void updateAfterCommit(SchedulerBatch committedBatch, PropagationState state) {}
  public String getId() { return "binary_occupancy_entropy"; }
  public String getVersion() { return "1.0"; }
  public boolean isDynamic() { return true; }
  public boolean isValid() { return valid; }
  public String validationMessage() { return message; }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", getId());
    json.setString("version", getVersion());
    json.setBoolean("dynamic", true);
    json.setString("normalization", "ln_2");
    json.setString("support_policy", "candidate_only");
    json.setString("neighborhood", context == null ? "" : context.config.neighborhoodMode.id());
    json.setBoolean("include_center", context != null && context.config.includeCenterVoxel);
    json.setInt("minimum_support", context == null ? 0 : context.config.minimumSupport);
    json.setBoolean("valid", valid);
    json.setString("validation", message);
    return json;
  }
}

class FieldHistogramEntropy implements EntropyModel {
  EntropyContext context;
  boolean valid;
  String message = "not initialized";
  float rangeMin, rangeMax;

  public void initialize(EntropyContext context) {
    this.context = context;
    valid = context != null && context.isValid() && context.config.fieldHistogramBins >= 2;
    if (!valid) { message = "entropy context or histogram configuration invalid"; return; }
    if (context.config.histogramRangeMode == HistogramRangeMode.FIXED_FIELD_RANGE) {
      rangeMin = -context.maximumAbsoluteField;
      rangeMax = context.maximumAbsoluteField;
    } else {
      rangeMin = Float.POSITIVE_INFINITY;
      rangeMax = Float.NEGATIVE_INFINITY;
      for (int i = 0; i < context.candidate.candidateSolid.length; i++) if (context.candidate.candidateSolid[i]) {
        float value = context.candidate.fieldScalar[i];
        if (dcrteFinite(value)) { rangeMin = min(rangeMin, value); rangeMax = max(rangeMax, value); }
      }
    }
    if (!dcrteFinite(rangeMin) || !dcrteFinite(rangeMax)) {
      valid = false;
      message = "candidate field range unavailable";
      return;
    }
    if (rangeMax <= rangeMin) rangeMax = rangeMin + 1.0f;
    message = "valid";
  }

  public LocalEntropySample sampleAt(int centerIndex, PropagationState state) {
    LocalEntropySample sample = new LocalEntropySample();
    if (!valid || centerIndex < 0 || centerIndex >= context.candidate.candidateSolid.length) return sample;
    int bins = context.config.fieldHistogramBins;
    int[] histogram = new int[bins];
    VolumeSpec spec = context.candidate.spec;
    int cx = centerIndex % spec.nx;
    int yz = centerIndex / spec.nx;
    int cy = yz % spec.ny;
    int cz = yz / spec.ny;
    int radius = dcrteEntropyRadius(context.config);
    for (int dz = -radius; dz <= radius; dz++) for (int dy = -radius; dy <= radius; dy++) for (int dx = -radius; dx <= radius; dx++) {
      if (!dcrteEntropyOffsetIncluded(dx, dy, dz, context)) continue;
      int x = cx + dx, y = cy + dy, z = cz + dz;
      if (x < 0 || y < 0 || z < 0 || x >= spec.nx || y >= spec.ny || z >= spec.nz) continue;
      int index = x + spec.nx * (y + spec.ny * z);
      if (!context.candidate.admitted[index] || !context.candidate.candidateSolid[index]) continue;
      float value = context.candidate.fieldScalar[index];
      if (!dcrteFinite(value)) continue;
      int bin = constrain((int)((value - rangeMin) / max(0.000001f, rangeMax - rangeMin) * bins), 0, bins - 1);
      histogram[bin]++;
      sample.supportCount++;
    }
    sample.valid = sample.supportCount >= context.config.minimumSupport;
    if (!sample.valid) return sample;
    double entropy = 0;
    for (int i = 0; i < bins; i++) if (histogram[i] > 0) {
      double p = histogram[i] / (double)sample.supportCount;
      entropy -= p * Math.log(p);
    }
    sample.entropy = bins <= 1 ? 0 : (float)(entropy / Math.log(bins));
    sample.normalizedEntropy = constrain(sample.entropy, 0, 1);
    return sample;
  }

  public EntropyDelta evaluateActivation(int activationIndex, PropagationState state) {
    EntropyDelta delta = new EntropyDelta();
    delta.valid = valid;
    return delta;
  }

  public EntropySummary summarize(PropagationState state) {
    EntropySummary summary = new EntropySummary();
    if (!valid || state == null) return summary;
    double sum = 0;
    int count = 0, low = 0;
    float minValue = Float.POSITIVE_INFINITY, maxValue = Float.NEGATIVE_INFINITY;
    for (int i = 0; i < state.active.length; i++) if (context.candidate.candidateSolid[i]) {
      LocalEntropySample sample = sampleAt(i, state);
      if (!sample.valid) { low++; continue; }
      sum += sample.entropy;
      minValue = min(minValue, sample.entropy);
      maxValue = max(maxValue, sample.entropy);
      count++;
    }
    summary.meanLocalEntropy = count == 0 ? 0 : (float)(sum / count);
    summary.weightedMeanLocalEntropy = summary.meanLocalEntropy;
    summary.minLocalEntropy = count == 0 ? 0 : minValue;
    summary.maxLocalEntropy = count == 0 ? 0 : maxValue;
    summary.validSampleCount = count;
    summary.lowSupportCount = low;
    return summary;
  }

  public void updateAfterCommit(SchedulerBatch committedBatch, PropagationState state) {}
  public String getId() { return "field_histogram_entropy"; }
  public String getVersion() { return "1.0"; }
  public boolean isDynamic() { return false; }
  public boolean isValid() { return valid; }
  public String validationMessage() { return message; }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", getId());
    json.setString("version", getVersion());
    json.setBoolean("dynamic", false);
    json.setInt("bins", context == null ? 0 : context.config.fieldHistogramBins);
    json.setString("range_mode", context == null ? "" : context.config.histogramRangeMode.id());
    json.setFloat("range_min", rangeMin);
    json.setFloat("range_max", rangeMax);
    json.setBoolean("valid", valid);
    json.setString("validation", message);
    return json;
  }
}
