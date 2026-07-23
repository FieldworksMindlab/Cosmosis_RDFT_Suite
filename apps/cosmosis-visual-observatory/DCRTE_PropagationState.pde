/* DCRTE-ET Milestone 4 flat activation and arrival-order storage. */

class PropagationState {
  final boolean[] active;
  final boolean[] frontier;
  final boolean[] queued;
  final int[] arrivalBatch;
  final int[] arrivalRank;
  final float[] activationScore;
  int[] frontierIndices;
  int frontierCount;
  int activeCount;
  int batchIndex;
  int activationRank;
  long attemptedUpdates;
  long acceptedUpdates;
  SchedulerRunState runState = SchedulerRunState.NOT_INITIALIZED;
  SchedulerStopReason stopReason = SchedulerStopReason.NONE;
  String stateHash = "";
  double activeFieldSum, activeSdfSum, activeIntrinsicSSum, activeIntrinsicRhoSum, activeConfidenceSum;
  int activeFieldSamples, activeSdfSamples, activeIntrinsicSSamples, activeIntrinsicRhoSamples, activeConfidenceSamples;

  PropagationState(int count) {
    int n = max(0, count);
    active = new boolean[n]; frontier = new boolean[n]; queued = new boolean[n];
    arrivalBatch = new int[n]; arrivalRank = new int[n]; activationScore = new float[n];
    frontierIndices = new int[n];
    java.util.Arrays.fill(arrivalBatch, -1);
    java.util.Arrays.fill(arrivalRank, -1);
    java.util.Arrays.fill(activationScore, Float.NaN);
  }

  void clear() {
    java.util.Arrays.fill(active, false); java.util.Arrays.fill(frontier, false); java.util.Arrays.fill(queued, false);
    java.util.Arrays.fill(arrivalBatch, -1); java.util.Arrays.fill(arrivalRank, -1);
    java.util.Arrays.fill(activationScore, Float.NaN);
    frontierCount = 0; activeCount = 0; batchIndex = 0; activationRank = 0;
    attemptedUpdates = 0; acceptedUpdates = 0;
    activeFieldSum = activeSdfSum = activeIntrinsicSSum = activeIntrinsicRhoSum = activeConfidenceSum = 0;
    activeFieldSamples = activeSdfSamples = activeIntrinsicSSamples = activeIntrinsicRhoSamples = activeConfidenceSamples = 0;
    runState = SchedulerRunState.NOT_INITIALIZED; stopReason = SchedulerStopReason.NONE; stateHash = "";
  }

  void setFrontier(int[] indices, int count) {
    java.util.Arrays.fill(frontier, false); java.util.Arrays.fill(queued, false);
    frontierCount = constrain(count, 0, frontierIndices.length);
    for (int i = 0; i < frontierCount; i++) {
      int index = indices[i]; frontierIndices[i] = index; frontier[index] = true; queued[index] = true;
    }
  }

  boolean activeAtBatch(int index, int selectedBatch) {
    return index >= 0 && index < arrivalBatch.length && arrivalBatch[index] >= 0 && arrivalBatch[index] <= selectedBatch;
  }

  boolean[] reconstructAtBatch(int selectedBatch) {
    boolean[] result = new boolean[arrivalBatch.length];
    for (int i = 0; i < result.length; i++) result[i] = activeAtBatch(i, selectedBatch);
    return result;
  }

  int unreachableCount(CandidateVolumeSnapshot snapshot) {
    if (snapshot == null || snapshot.candidateSolid.length != active.length) return 0;
    int count = 0;
    for (int i = 0; i < active.length; i++) if (snapshot.candidateSolid[i] && !active[i]) count++;
    return count;
  }

  long estimatedBytes() {
    return active.length * 3L + arrivalBatch.length * 4L + arrivalRank.length * 4L
      + activationScore.length * 4L + frontierIndices.length * 4L;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("run_state", runState.id()); json.setString("stop_reason", stopReason.id());
    json.setInt("batch_index", batchIndex); json.setInt("active_count", activeCount);
    json.setInt("frontier_count", frontierCount);
    json.setString("attempted_updates", Long.toString(attemptedUpdates));
    json.setString("accepted_updates", Long.toString(acceptedUpdates));
    json.setString("state_hash", stateHash);
    json.setString("estimated_storage_bytes", Long.toString(estimatedBytes()));
    return json;
  }
}

String dcrteSchedulerStateHash(SchedulerContext context, PropagationState state, String schedulerId, String schedulerVersion) {
  if (context == null || state == null) return "";
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    dcrteDigestString(digest, context.snapshot.contentHash);
    dcrteDigestString(digest, schedulerId); dcrteDigestString(digest, schedulerVersion);
    dcrteDigestString(digest, context.configuration.canonical());
    if (context.hasHbeSchedulerChannel())
      dcrteDigestString(digest, context.hbeSnapshot.contentHash);
    dcrteDigestInt(digest, state.batchIndex);
    dcrteDigestInt(digest, context.resolvedSeeds.length);
    for (int i = 0; i < context.resolvedSeeds.length; i++) dcrteDigestInt(digest, context.resolvedSeeds[i]);
    for (int i = 0; i < state.arrivalBatch.length; i++) dcrteDigestInt(digest, state.arrivalBatch[i]);
    return dcrteHex(digest.digest());
  } catch (Exception error) { return "sha256-error"; }
}
