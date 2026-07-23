/* M6-HX deterministic intrinsic mirror correspondence. */

class HBEMirrorMap {
  final int[] pairIndex;
  final float[] pairConfidence;
  final HBEMirrorPolicy requestedPolicy;
  final HBEMirrorPolicy resolvedPolicy;
  final int pairedCount;
  final float pairedFraction;
  final float meanResidual;
  final String contentHash;

  HBEMirrorMap(CandidateVolumeSnapshot candidate, HBEIntrinsicObservables observables,
      HBEMirrorPolicy policy) {
    int n = candidate == null || candidate.spec == null ? 0 : candidate.spec.voxelCount();
    pairIndex = new int[n]; pairConfidence = new float[n]; java.util.Arrays.fill(pairIndex, -1);
    requestedPolicy = policy == null ? HBEMirrorPolicy.AUTO_FRAME_CALIBRATED : policy;
    HBEMirrorPolicy[] trials = requestedPolicy == HBEMirrorPolicy.AUTO_FRAME_CALIBRATED
      ? new HBEMirrorPolicy[] {HBEMirrorPolicy.PRESERVE_THETA, HBEMirrorPolicy.NEGATE_THETA, HBEMirrorPolicy.PI_MINUS_THETA}
      : new HBEMirrorPolicy[] {requestedPolicy};
    int bestCount = -1; float bestResidual = Float.POSITIVE_INFINITY; HBEMirrorPolicy best = trials[0];
    int[] bestPairs = new int[n]; float[] bestConfidence = new float[n]; java.util.Arrays.fill(bestPairs, -1);
    for (int trial = 0; trial < trials.length; trial++) {
      int[] pairs = new int[n]; float[] confidence = new float[n]; java.util.Arrays.fill(pairs, -1);
      float[] totals = dcrteHbeBuildMirrorPairs(candidate, observables, trials[trial], pairs, confidence);
      int count = round(totals[0]); float residual = totals[1];
      if (count > bestCount || count == bestCount && residual < bestResidual) {
        bestCount = count; bestResidual = residual; best = trials[trial];
        bestPairs = pairs; bestConfidence = confidence;
      }
    }
    System.arraycopy(bestPairs, 0, pairIndex, 0, n);
    System.arraycopy(bestConfidence, 0, pairConfidence, 0, n);
    resolvedPolicy = best; pairedCount = max(0, bestCount);
    pairedFraction = candidate == null || candidate.candidateCount == 0 ? 0 : pairedCount / (float)candidate.candidateCount;
    meanResidual = bestResidual == Float.POSITIVE_INFINITY ? Float.NaN : bestResidual;
    contentHash = dcrteHbeMirrorHash();
  }

  boolean isValid() { return pairIndex.length > 0 && pairedCount > 0 && dcrteFinite(meanResidual); }

  String dcrteHbeMirrorHash() {
    try {
      java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
      dcrteDigestString(digest, resolvedPolicy.id());
      for (int i = 0; i < pairIndex.length; i++) if (pairIndex[i] >= 0) {
        dcrteDigestInt(digest, i); dcrteDigestInt(digest, pairIndex[i]);
        dcrteDigestInt(digest, Float.floatToIntBits(pairConfidence[i]));
      }
      return dcrteHex(digest.digest());
    } catch (Exception error) { return "sha256-error"; }
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("requested_policy", requestedPolicy.id());
    j.setString("resolved_policy", resolvedPolicy.id()); j.setInt("paired_voxels", pairedCount);
    j.setFloat("paired_fraction", pairedFraction);
    if (dcrteFinite(meanResidual)) j.setFloat("mean_intrinsic_residual", meanResidual);
    j.setString("sha256", contentHash); j.setBoolean("valid", isValid());
    j.setString("semantics", "classical intrinsic-coordinate correspondence proxy");
    return j;
  }
}

float[] dcrteHbeBuildMirrorPairs(CandidateVolumeSnapshot candidate,
    HBEIntrinsicObservables observables, HBEMirrorPolicy policy,
    int[] pairs, float[] pairConfidence) {
  java.util.HashMap<Long, ArrayList<Integer>> bins = new java.util.HashMap<Long, ArrayList<Integer>>();
  int n = candidate == null ? 0 : candidate.candidateSolid.length;
  for (int i = 0; i < n; i++) {
    if (!candidate.candidateSolid[i] || !observables.valid[i]) continue;
    long key = dcrteHbeMirrorBin(0.5f * (observables.xi[i] + 1), observables.rho[i], observables.theta[i]);
    ArrayList<Integer> list = bins.get(key);
    if (list == null) { list = new ArrayList<Integer>(); bins.put(key, list); }
    list.add(i);
  }
  int paired = 0; double residualSum = 0;
  for (int i = 0; i < n; i++) {
    if (!candidate.candidateSolid[i] || !observables.valid[i]) continue;
    float targetS = 0.5f * (1 - observables.xi[i]);
    float targetTheta = dcrteHbeMirrorTheta(observables.theta[i], policy);
    int sb = constrain(round(targetS * 63), 0, 63);
    int rb = constrain(round(constrain(observables.rho[i], 0, 2) * 16), 0, 32);
    int tb = dcrteHbeThetaBin(targetTheta);
    int best = -1; float bestResidual = Float.POSITIVE_INFINITY;
    for (int ds = -1; ds <= 1; ds++) for (int dr = -1; dr <= 1; dr++) for (int dt = -1; dt <= 1; dt++) {
      int ss = constrain(sb + ds, 0, 63), rr = constrain(rb + dr, 0, 32), tt = (tb + dt + 48) % 48;
      ArrayList<Integer> list = bins.get(dcrteHbePackBin(ss, rr, tt));
      if (list == null) continue;
      for (int q = 0; q < list.size(); q++) {
        int j = list.get(q); float s = 0.5f * (observables.xi[j] + 1);
        float angular = abs(atan2(sin(observables.theta[j] - targetTheta), cos(observables.theta[j] - targetTheta))) / PI;
        float residual = abs(s - targetS) + 0.35f * abs(observables.rho[j] - observables.rho[i]) + 0.20f * angular;
        if (residual < bestResidual || residual == bestResidual && (best < 0 || j < best)) { best = j; bestResidual = residual; }
      }
    }
    if (best >= 0 && bestResidual <= 0.12f) {
      pairs[i] = best; pairConfidence[i] = constrain(1 - bestResidual / 0.12f, 0, 1)
        * min(observables.confidence[i], observables.confidence[best]);
      paired++; residualSum += bestResidual;
    }
  }
  return new float[] {paired, paired == 0 ? Float.POSITIVE_INFINITY : (float)(residualSum / paired)};
}

float dcrteHbeMirrorTheta(float theta, HBEMirrorPolicy policy) {
  if (policy == HBEMirrorPolicy.NEGATE_THETA) return atan2(sin(-theta), cos(-theta));
  if (policy == HBEMirrorPolicy.PI_MINUS_THETA) return atan2(sin(PI - theta), cos(PI - theta));
  return atan2(sin(theta), cos(theta));
}

int dcrteHbeThetaBin(float theta) {
  float normalized = (atan2(sin(theta), cos(theta)) + PI) / TWO_PI;
  return constrain(floor(normalized * 48), 0, 47);
}

long dcrteHbeMirrorBin(float s, float rho, float theta) {
  return dcrteHbePackBin(constrain(round(s * 63), 0, 63),
    constrain(round(constrain(rho, 0, 2) * 16), 0, 32), dcrteHbeThetaBin(theta));
}

long dcrteHbePackBin(int s, int r, int t) { return ((long)s << 16) | ((long)r << 8) | (long)t; }
