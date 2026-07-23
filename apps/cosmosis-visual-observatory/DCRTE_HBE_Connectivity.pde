/* M6-HX strict six-connected bridge analysis. Paths are graph proxies, not geodesics. */

class HBEConnectivityReport {
  boolean validInput;
  boolean connected;
  int occupiedCount;
  int componentCount;
  int leftAnchorOccupied;
  int rightAnchorOccupied;
  int reachableCount;
  int largestComponentCount;
  float largestComponentFraction;
  int leftOccupiedCount;
  int rightOccupiedCount;
  int neckOccupiedCount;
  float leftOccupiedFraction;
  float rightOccupiedFraction;
  float bilateralBalance;
  int minimumNeckCrossSection;
  float neckBottleneckS = Float.NaN;
  float neckBinWidth;
  int shortestPathSteps = -1;
  float shortestPathWorld = Float.NaN;
  float pathTortuosity = Float.NaN;
  float bottleneckFraction;
  int mirrorPairCount;
  float mirrorAgreement = Float.NaN;
  float mirrorJaccard = Float.NaN;
  int mirrorArrivalPairCount;
  float mirrorArrivalMean = Float.NaN;
  float mirrorArrivalMedian = Float.NaN;
  float mirrorArrivalP95 = Float.NaN;
  int mirrorArrivalMaximum = -1;
  int[] shortestPath = new int[0];
  String maskHash = "";
  String analysisHash = "";

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setBoolean("valid_input", validInput);
    j.setBoolean("left_right_connected", connected); j.setInt("occupied_voxels", occupiedCount);
    j.setInt("components", componentCount); j.setInt("left_anchor_occupied", leftAnchorOccupied);
    j.setInt("right_anchor_occupied", rightAnchorOccupied); j.setInt("reachable_voxels", reachableCount);
    j.setInt("largest_component_voxels", largestComponentCount);
    j.setFloat("largest_component_fraction", largestComponentFraction);
    j.setInt("left_occupied_voxels", leftOccupiedCount); j.setInt("right_occupied_voxels", rightOccupiedCount);
    j.setInt("neck_occupied_voxels", neckOccupiedCount);
    j.setFloat("left_occupied_fraction", leftOccupiedFraction); j.setFloat("right_occupied_fraction", rightOccupiedFraction);
    j.setFloat("bilateral_balance", bilateralBalance);
    j.setInt("minimum_neck_cross_section", minimumNeckCrossSection);
    if (dcrteFinite(neckBottleneckS)) j.setFloat("neck_bottleneck_s", neckBottleneckS);
    j.setFloat("neck_bin_width", neckBinWidth);
    j.setInt("shortest_path_steps", shortestPathSteps);
    if (dcrteFinite(shortestPathWorld)) j.setFloat("shortest_path_world_proxy", shortestPathWorld);
    if (dcrteFinite(pathTortuosity)) j.setFloat("path_tortuosity", pathTortuosity);
    j.setFloat("neck_bottleneck_fraction", bottleneckFraction);
    j.setInt("mirror_pair_count", mirrorPairCount);
    if (dcrteFinite(mirrorAgreement)) j.setFloat("mirror_active_agreement", mirrorAgreement);
    if (dcrteFinite(mirrorJaccard)) j.setFloat("mirror_active_jaccard", mirrorJaccard);
    j.setInt("mirror_arrival_pair_count", mirrorArrivalPairCount);
    if (dcrteFinite(mirrorArrivalMean)) j.setFloat("mirror_arrival_mean_batches", mirrorArrivalMean);
    if (dcrteFinite(mirrorArrivalMedian)) j.setFloat("mirror_arrival_median_batches", mirrorArrivalMedian);
    if (dcrteFinite(mirrorArrivalP95)) j.setFloat("mirror_arrival_p95_batches", mirrorArrivalP95);
    j.setInt("mirror_arrival_maximum_batches", mirrorArrivalMaximum);
    j.setString("mask_sha256", maskHash); j.setString("analysis_sha256", analysisHash);
    j.setString("path_semantics", "six-connected voxel graph path proxy; not a geodesic");
    return j;
  }
}

HBEConnectivityReport dcrteHbeAnalyzeConnectivity(boolean[] mask,
    HBEIntrinsicObservables observables) {
  HBEConnectivityReport report = new HBEConnectivityReport();
  if (mask == null || observables == null || !observables.isValid()
      || mask.length != observables.valid.length) return report;
  report.validInput = true;
  int n = mask.length; int[] queue = new int[n]; int[] parent = new int[n];
  int[] labels = new int[n]; java.util.Arrays.fill(parent, -1); java.util.Arrays.fill(labels, -1);
  int head = 0, tail = 0; int neckOccupied = 0;
  for (int i = 0; i < n; i++) {
    if (!mask[i] || !observables.valid[i]) continue;
    report.occupiedCount++;
    if (observables.leftAnchor[i]) { report.leftAnchorOccupied++; queue[tail++] = i; labels[i] = -2; }
    if (observables.rightAnchor[i]) report.rightAnchorOccupied++;
    if (observables.neckBand[i]) neckOccupied++;
  }
  int target = -1;
  while (head < tail) {
    int index = queue[head++]; report.reachableCount++;
    if (observables.rightAnchor[index]) { target = index; break; }
    int[] neighbors = dcrteSixNeighbors(index, observables.spec);
    for (int k = 0; k < neighbors.length; k++) {
      int next = neighbors[k];
      if (!mask[next] || !observables.valid[next] || labels[next] != -1) continue;
      labels[next] = -2; parent[next] = index; queue[tail++] = next;
    }
  }
  report.connected = target >= 0;
  if (report.connected) {
    int count = 1; for (int at = target; parent[at] >= 0; at = parent[at]) count++;
    report.shortestPath = new int[count]; int at = target;
    for (int p = count - 1; p >= 0; p--) { report.shortestPath[p] = at; at = parent[at]; }
    report.shortestPathSteps = count - 1;
    report.shortestPathWorld = report.shortestPathSteps * observables.spec.minSpacing();
  }
  report.neckOccupiedCount = neckOccupied;
  report.bottleneckFraction = observables.neckCount == 0 ? 0 : neckOccupied / (float)observables.neckCount;
  int[] componentStats = dcrteHbeComponentStats(mask, observables);
  report.componentCount = componentStats[0]; report.largestComponentCount = componentStats[1];
  report.largestComponentFraction = report.occupiedCount == 0 ? 0 : report.largestComponentCount / (float)report.occupiedCount;
  dcrteHbeMeasureSidesAndNeck(report, mask, observables);
  if (report.connected && report.shortestPath.length > 1) {
    int first = report.shortestPath[0], last = report.shortestPath[report.shortestPath.length - 1];
    float straight = dcrteHbeVoxelDistance(first, last, observables.spec);
    report.pathTortuosity = straight <= 0 ? Float.NaN : report.shortestPathWorld / straight;
  }
  report.maskHash = dcrteHbeBooleanMaskHash(mask);
  report.analysisHash = dcrteSha256Hex(report.maskHash + "|" + report.connected + "|"
    + report.componentCount + "|" + report.shortestPathSteps + "|" + report.bottleneckFraction);
  return report;
}

int dcrteHbeCountComponents(boolean[] mask, HBEIntrinsicObservables observables) {
  return dcrteHbeComponentStats(mask, observables)[0];
}

int[] dcrteHbeComponentStats(boolean[] mask, HBEIntrinsicObservables observables) {
  int n = mask.length; boolean[] seen = new boolean[n]; int[] queue = new int[n]; int components = 0;
  int largest = 0;
  for (int start = 0; start < n; start++) {
    if (seen[start] || !mask[start] || !observables.valid[start]) continue;
    int head = 0, tail = 0, count = 0; queue[tail++] = start; seen[start] = true; components++;
    while (head < tail) {
      int index = queue[head++]; count++; int[] neighbors = dcrteSixNeighbors(index, observables.spec);
      for (int k = 0; k < neighbors.length; k++) {
        int next = neighbors[k];
        if (seen[next] || !mask[next] || !observables.valid[next]) continue;
        seen[next] = true; queue[tail++] = next;
      }
    }
    largest = max(largest, count);
  }
  return new int[] {components, largest};
}

void dcrteHbeMeasureSidesAndNeck(HBEConnectivityReport report, boolean[] mask,
    HBEIntrinsicObservables observables) {
  int bins = 24; int[] cross = new int[bins]; int leftTotal = 0, rightTotal = 0;
  for (int i = 0; i < mask.length; i++) if (observables.valid[i]) {
    if (observables.xi[i] < 0) leftTotal++; else if (observables.xi[i] > 0) rightTotal++;
    if (!mask[i]) continue;
    if (observables.xi[i] < 0) report.leftOccupiedCount++;
    else if (observables.xi[i] > 0) report.rightOccupiedCount++;
    float s = 0.5f * (observables.xi[i] + 1);
    if (observables.neckBand[i]) cross[constrain(floor(s * bins), 0, bins - 1)]++;
  }
  report.leftOccupiedFraction = leftTotal == 0 ? 0 : report.leftOccupiedCount / (float)leftTotal;
  report.rightOccupiedFraction = rightTotal == 0 ? 0 : report.rightOccupiedCount / (float)rightTotal;
  report.bilateralBalance = 1 - abs(report.leftOccupiedFraction - report.rightOccupiedFraction);
  report.neckBinWidth = 1.0f / bins;
  int minimum = Integer.MAX_VALUE, minimumBin = -1;
  float neckLo = 1, neckHi = 0;
  for (int i = 0; i < mask.length; i++) if (observables.valid[i] && observables.neckBand[i]) {
    float s = 0.5f * (observables.xi[i] + 1);
    neckLo = min(neckLo, s); neckHi = max(neckHi, s);
  }
  for (int b = 0; b < bins; b++) {
    float center = (b + 0.5f) / bins;
    if (center < neckLo || center > neckHi || cross[b] <= 0) continue;
    if (cross[b] < minimum) { minimum = cross[b]; minimumBin = b; }
  }
  report.minimumNeckCrossSection = minimum == Integer.MAX_VALUE ? 0 : minimum;
  report.neckBottleneckS = minimumBin < 0 ? Float.NaN : (minimumBin + 0.5f) / bins;
}

void dcrteHbeEnrichMirrorMetrics(HBEConnectivityReport report, boolean[] mask,
    HBEMirrorMap mirror, PropagationState state) {
  if (report == null || mask == null || mirror == null || !mirror.isValid()
      || mirror.pairIndex.length != mask.length) return;
  int agreement = 0, union = 0, intersection = 0;
  ArrayList<Integer> arrival = new ArrayList<Integer>();
  for (int i = 0; i < mask.length; i++) {
    int pair = mirror.pairIndex[i];
    if (pair < 0 || pair >= mask.length || pair < i) continue;
    report.mirrorPairCount++;
    boolean a = mask[i], b = mask[pair];
    if (a == b) agreement++; if (a || b) union++; if (a && b) intersection++;
    if (state != null && i < state.arrivalBatch.length && pair < state.arrivalBatch.length
        && state.arrivalBatch[i] >= 0 && state.arrivalBatch[pair] >= 0)
      arrival.add(abs(state.arrivalBatch[i] - state.arrivalBatch[pair]));
  }
  report.mirrorAgreement = report.mirrorPairCount == 0 ? Float.NaN : agreement / (float)report.mirrorPairCount;
  report.mirrorJaccard = union == 0 ? 1 : intersection / (float)union;
  report.mirrorArrivalPairCount = arrival.size();
  if (arrival.size() > 0) {
    java.util.Collections.sort(arrival); long total = 0;
    for (int i = 0; i < arrival.size(); i++) total += arrival.get(i);
    report.mirrorArrivalMean = total / (float)arrival.size();
    report.mirrorArrivalMedian = arrival.get((arrival.size() - 1) / 2);
    report.mirrorArrivalP95 = arrival.get(constrain(ceil(arrival.size() * 0.95f) - 1, 0, arrival.size() - 1));
    report.mirrorArrivalMaximum = arrival.get(arrival.size() - 1);
  }
}

float dcrteHbeVoxelDistance(int a, int b, VolumeSpec spec) {
  if (spec == null || a < 0 || b < 0) return Float.NaN;
  int ax = a % spec.nx, ay = (a / spec.nx) % spec.ny, az = a / (spec.nx * spec.ny);
  int bx = b % spec.nx, by = (b / spec.nx) % spec.ny, bz = b / (spec.nx * spec.ny);
  float dx = (ax - bx) * spec.spacingX(), dy = (ay - by) * spec.spacingY(), dz = (az - bz) * spec.spacingZ();
  return sqrt(dx * dx + dy * dy + dz * dz);
}

String dcrteHbeBooleanMaskHash(boolean[] values) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    if (values != null) for (int i = 0; i < values.length; i++) digest.update((byte)(values[i] ? 1 : 0));
    return dcrteHex(digest.digest());
  } catch (Exception error) { return "sha256-error"; }
}
