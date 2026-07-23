/* M6-HX optional zero-default overlay on the existing M5 score path. */

class HBEScoreWeights {
  float neck, balance, mirror, connection, feedback, reachability;
  float sum() { return neck + balance + mirror + connection + feedback + reachability; }
  boolean isValid() {
    return dcrteFinite(neck) && dcrteFinite(balance) && dcrteFinite(mirror)
      && dcrteFinite(connection) && dcrteFinite(feedback)
      && dcrteFinite(reachability) && neck >= 0 && balance >= 0 && mirror >= 0
      && connection >= 0 && feedback >= 0 && reachability >= 0;
  }
  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setFloat("neck", neck); j.setFloat("balance", balance);
    j.setFloat("mirror", mirror); j.setFloat("connection", connection);
    j.setFloat("feedback", feedback); j.setFloat("reachability", reachability);
    j.setFloat("sum", sum()); return j;
  }
}

HBEScoreWeights dcrteHbeScoreWeights(HBEScorePreset preset) {
  HBEScoreWeights w = new HBEScoreWeights();
  if (preset == HBEScorePreset.BILATERAL_RELAXATION) {
    w.balance=.30f; w.mirror=.20f; w.neck=.10f; w.connection=.20f; w.feedback=.10f; w.reachability=.10f;
  } else if (preset == HBEScorePreset.BILATERAL_EXPLORATION) {
    w.mirror=.15f; w.neck=.20f; w.connection=.20f; w.feedback=.20f; w.reachability=.15f; w.balance=.10f;
  } else if (preset == HBEScorePreset.BRIDGE_SEEKING) {
    w.connection=.35f; w.reachability=.25f; w.neck=.15f; w.mirror=.10f; w.balance=.10f; w.feedback=.05f;
  }
  return w;
}

class HBEReachabilityMap {
  final int[] distanceFromLeft;
  final int[] distanceFromRight;
  final int maximumLeftDistance;
  final int maximumRightDistance;
  final String contentHash;

  HBEReachabilityMap(CandidateVolumeSnapshot candidate,
      HBEIntrinsicObservables observables) {
    int n = candidate == null || candidate.spec == null ? 0 : candidate.spec.voxelCount();
    distanceFromLeft = new int[n]; distanceFromRight = new int[n];
    java.util.Arrays.fill(distanceFromLeft, -1); java.util.Arrays.fill(distanceFromRight, -1);
    maximumLeftDistance = dcrteHbeCandidateDistances(candidate, observables, true, distanceFromLeft);
    maximumRightDistance = dcrteHbeCandidateDistances(candidate, observables, false, distanceFromRight);
    contentHash = dcrteSha256Hex(dcrteHbeIntArrayHash(distanceFromLeft) + "|"
      + dcrteHbeIntArrayHash(distanceFromRight));
  }

  boolean isValid() { return distanceFromLeft.length > 0 && maximumLeftDistance >= 0 && maximumRightDistance >= 0; }
  float oppositeAnchorScore(int index, float xi) {
    if (index < 0 || index >= distanceFromLeft.length) return 0;
    int distance = xi <= 0 ? distanceFromRight[index] : distanceFromLeft[index];
    int maximum = xi <= 0 ? maximumRightDistance : maximumLeftDistance;
    return distance < 0 || maximum <= 0 ? 0 : 1.0f - constrain(distance / (float)maximum, 0, 1);
  }
  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setBoolean("valid", isValid());
    j.setInt("maximum_left_distance", maximumLeftDistance);
    j.setInt("maximum_right_distance", maximumRightDistance);
    j.setString("sha256", contentHash);
    j.setString("semantics", "candidate six-connected graph distance; not geodesic length");
    return j;
  }
}

int dcrteHbeCandidateDistances(CandidateVolumeSnapshot candidate,
    HBEIntrinsicObservables observables, boolean left, int[] distances) {
  if (candidate == null || observables == null || distances == null
      || distances.length != candidate.candidateSolid.length) return -1;
  int[] queue = new int[distances.length]; int head = 0, tail = 0, maximum = 0;
  for (int i = 0; i < distances.length; i++) {
    boolean anchor = left ? observables.leftAnchor[i] : observables.rightAnchor[i];
    if (anchor && candidate.candidateSolid[i] && observables.valid[i]) {
      distances[i] = 0; queue[tail++] = i;
    }
  }
  while (head < tail) {
    int index = queue[head++];
    int[] neighbors = dcrteSixNeighbors(index, candidate.spec);
    for (int k = 0; k < neighbors.length; k++) {
      int next = neighbors[k];
      if (distances[next] >= 0 || !candidate.candidateSolid[next]
          || !observables.valid[next]) continue;
      distances[next] = distances[index] + 1; maximum = max(maximum, distances[next]);
      queue[tail++] = next;
    }
  }
  return tail == 0 ? -1 : maximum;
}

String dcrteHbeIntArrayHash(int[] values) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    if (values != null) for (int i = 0; i < values.length; i++) dcrteDigestInt(digest, values[i]);
    return dcrteHex(digest.digest());
  } catch (Exception error) { return "sha256-error"; }
}

class HBEScoreBatchContext {
  final HBEExperimentSnapshot hbe;
  final HBEScoreWeights weights;
  final boolean[] candidateSolid;
  final boolean[] activeBeforeBatch;
  final boolean[] leftReach;
  final boolean[] rightReach;
  final int leftTotal;
  final int rightTotal;
  final int leftActive;
  final int rightActive;
  final float bilateralBalance;
  final boolean available;

  HBEScoreBatchContext(SchedulerContext context, PropagationState state) {
    hbe = context != null && context.hasHbeSchedulerChannel() ? context.hbeSnapshot : null;
    weights = hbe == null ? new HBEScoreWeights() : dcrteHbeScoreWeights(hbe.config.scorePreset);
    int n = state == null ? 0 : state.active.length;
    candidateSolid = context == null || context.snapshot == null
      ? new boolean[n] : java.util.Arrays.copyOf(context.snapshot.candidateSolid, n);
    activeBeforeBatch = state == null
      ? new boolean[n] : java.util.Arrays.copyOf(state.active, n);
    leftReach = new boolean[n]; rightReach = new boolean[n];
    if (hbe == null || state == null || !hbe.matches(context.snapshot)
        || !weights.isValid() || weights.sum() <= 0) {
      leftTotal = 0; rightTotal = 0; leftActive = 0; rightActive = 0;
      bilateralBalance = 0; available = false; return;
    }
    int countedLeftTotal=0, countedRightTotal=0;
    int countedLeftActive=0, countedRightActive=0;
    for (int i = 0; i < n; i++) if (context.snapshot.candidateSolid[i]
        && hbe.observables.valid[i]) {
      if (hbe.observables.xi[i] < 0) {
        countedLeftTotal++; if (state.active[i]) countedLeftActive++;
      } else if (hbe.observables.xi[i] > 0) {
        countedRightTotal++; if (state.active[i]) countedRightActive++;
      }
    }
    leftTotal = countedLeftTotal; rightTotal = countedRightTotal;
    leftActive = countedLeftActive; rightActive = countedRightActive;
    float lf = leftTotal == 0 ? 0 : leftActive / (float)leftTotal;
    float rf = rightTotal == 0 ? 0 : rightActive / (float)rightTotal;
    bilateralBalance = 1 - abs(lf - rf);
    dcrteHbeActiveReach(activeBeforeBatch, hbe.observables, true, leftReach);
    dcrteHbeActiveReach(activeBeforeBatch, hbe.observables, false, rightReach);
    available = true;
  }

  float balanceGain(int index) {
    if (!available || index < 0 || index >= hbe.observables.xi.length) return 0;
    // A side-local activation improves balance when it occurs on the lagging side.
    int nextLeftActive = leftActive;
    int nextRightActive = rightActive;
    if (hbe.observables.xi[index] < 0) nextLeftActive++;
    else if (hbe.observables.xi[index] > 0) nextRightActive++;
    float before = bilateralBalance;
    float after = 1 - abs((leftTotal == 0 ? 0 : nextLeftActive / (float)leftTotal)
      - (rightTotal == 0 ? 0 : nextRightActive / (float)rightTotal));
    return constrain(max(0, after - before) * max(leftTotal, rightTotal), 0, 1);
  }

  float connectionGain(int index, VolumeSpec spec) {
    if (!available || index < 0 || index >= leftReach.length) return 0;
    boolean touchesLeft = leftReach[index], touchesRight = rightReach[index];
    int[] neighbors = dcrteSixNeighbors(index, spec);
    for (int i = 0; i < neighbors.length; i++) {
      touchesLeft |= leftReach[neighbors[i]]; touchesRight |= rightReach[neighbors[i]];
    }
    return touchesLeft && touchesRight ? 1 : 0;
  }
}

void dcrteHbeActiveReach(boolean[] active, HBEIntrinsicObservables observables,
    boolean left, boolean[] reach) {
  if (active == null || observables == null || reach == null || active.length != reach.length) return;
  int[] queue = new int[active.length]; int head=0, tail=0;
  for(int i=0;i<active.length;i++){
    boolean anchor=left?observables.leftAnchor[i]:observables.rightAnchor[i];
    if(active[i]&&anchor&&observables.valid[i]){reach[i]=true;queue[tail++]=i;}
  }
  while(head<tail){int index=queue[head++];int[] neighbors=dcrteSixNeighbors(index,observables.spec);
    for(int k=0;k<neighbors.length;k++){int next=neighbors[k];if(reach[next]||!active[next]||!observables.valid[next])continue;
      reach[next]=true;queue[tail++]=next;}}
}

void dcrteHbeApplyScoreOverlay(SchedulerScoreTerms terms, int voxelIndex,
    EntropyContext entropyContext, PropagationState state,
    HBEScoreBatchContext batch) {
  if (terms == null || batch == null || !batch.available || batch.hbe == null) return;
  HBEExperimentSnapshot hbe = batch.hbe; HBEIntrinsicObservables o = hbe.observables;
  if (voxelIndex < 0 || voxelIndex >= o.valid.length || !o.valid[voxelIndex]) return;
  HBEScoreWeights w = batch.weights;
  boolean mirrorAvailable = hbe.mirrorMap != null && hbe.mirrorMap.isValid();
  boolean reachabilityAvailable = hbe.reachability != null && hbe.reachability.isValid();
  float sum = w.neck + w.balance + w.connection + w.feedback
    + (mirrorAvailable ? w.mirror : 0)
    + (reachabilityAvailable ? w.reachability : 0);
  if (sum <= 0) return;
  terms.hbeAvailable = true;
  terms.hbeNeckProximity = constrain(o.neckProximity[voxelIndex], 0, 1);
  terms.hbeBilateralBalance = batch.balanceGain(voxelIndex);
  int mirror = hbe.mirrorMap == null || voxelIndex >= hbe.mirrorMap.pairIndex.length
    ? -1 : hbe.mirrorMap.pairIndex[voxelIndex];
  terms.hbeMirrorSupport = !mirrorAvailable || mirror < 0 ? 0 : state.active[mirror] ? 1.0f
    : state.frontier[mirror] ? 0.70f
    : entropyContext.candidate.candidateSolid[mirror] ? 0.40f : 0;
  terms.hbeConnectionGain = batch.connectionGain(voxelIndex, entropyContext.candidate.spec);
  terms.hbeFeedbackCoupling = constrain(hbe.metrics.feedback
    * terms.hbeNeckProximity * terms.fieldComplexity, 0, 1);
  terms.hbeCrossLobeReachability = reachabilityAvailable
    ? hbe.reachability.oppositeAnchorScore(voxelIndex, o.xi[voxelIndex]) : 0;
  terms.hbeCombinedScore = constrain((w.neck*terms.hbeNeckProximity
    + w.balance*terms.hbeBilateralBalance + (mirrorAvailable ? w.mirror*terms.hbeMirrorSupport : 0)
    + w.connection*terms.hbeConnectionGain + w.feedback*terms.hbeFeedbackCoupling
    + (reachabilityAvailable ? w.reachability*terms.hbeCrossLobeReachability : 0)) / sum, 0, 1);
  float overlay = constrain(hbe.config.schedulerWeight, 0, 1);
  terms.combinedScore = constrain(lerp(terms.combinedScore, terms.hbeCombinedScore, overlay), 0, 1);
}
