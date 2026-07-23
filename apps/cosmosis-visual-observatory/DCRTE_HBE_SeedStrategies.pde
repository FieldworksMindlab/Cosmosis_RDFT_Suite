/* M6-HX optional seed resolution layered over the established M4 strategies. */

class HBESeedSelectionReport {
  HBESeedMode requested = HBESeedMode.LEGACY;
  int[] selectedIndices = new int[0];
  float[] selectedS = new float[0];
  float[] selectedRho = new float[0];
  float[] selectedConfidence = new float[0];
  String status = "not resolved";

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("requested_mode", requested.id());
    j.setString("status", status); JSONArray rows = new JSONArray();
    for (int i = 0; i < selectedIndices.length; i++) {
      JSONObject row = new JSONObject(); row.setInt("index", selectedIndices[i]);
      row.setFloat("s", selectedS[i]); row.setFloat("rho", selectedRho[i]);
      row.setFloat("confidence", selectedConfidence[i]); rows.setJSONObject(i, row);
    }
    j.setJSONArray("seeds", rows); return j;
  }
}

HBESeedSelectionReport dcrteHbeSeedSelection = new HBESeedSelectionReport();

int[] dcrteResolveSeedsForContext(SchedulerSeedMode legacyMode,
    SchedulerContext context, SchedulerDiagnostics diagnostics) {
  if (context == null || !context.hasHbeSchedulerChannel()
      || context.hbeSnapshot.config.seedMode == HBESeedMode.LEGACY)
    return dcrteSeedStrategy(legacyMode).resolve(context, diagnostics);
  return dcrteResolveHbeSeeds(context, diagnostics);
}

int[] dcrteResolveHbeSeeds(SchedulerContext context,
    SchedulerDiagnostics diagnostics) {
  HBEExperimentSnapshot hbe = context == null ? null : context.hbeSnapshot;
  dcrteHbeSeedSelection = new HBESeedSelectionReport();
  if (hbe == null || !hbe.matches(context.snapshot)) {
    diagnostics.error("HBE_SNAPSHOT_STALE", "hbe_seed",
      "HBE seed resolution requires a current frozen experiment snapshot", 1, -1,
      "rebuild the HBE snapshot");
    return new int[0];
  }
  HBESeedMode mode = hbe.config.seedMode;
  dcrteHbeSeedSelection.requested = mode;
  int[] result;
  if (mode == HBESeedMode.NECK_CENTER) {
    int neck = dcrteHbeBestSeed(context.snapshot, hbe.observables, 0.5f);
    result = neck < 0 ? new int[0] : new int[] {neck};
  } else if (mode == HBESeedMode.MIRRORED_PAIR) {
    int left = dcrteHbeBestSeed(context.snapshot, hbe.observables, 0.04f);
    int mirror = left < 0 || hbe.mirrorMap == null || !hbe.mirrorMap.isValid()
      ? -1 : hbe.mirrorMap.pairIndex[left];
    if (mirror < 0 || hbe.mirrorMap.pairConfidence[left] < hbe.config.confidenceFloor) {
      diagnostics.error("HBE_MIRROR_UNRELIABLE", "hbe_seed",
        "Mirrored-pair seeding requires a confidence-qualified partner", 1, left,
        "select dual-end seeds or rebuild the mirror map");
      result = new int[0];
    } else result = new int[] {left, mirror};
  } else {
    int left = dcrteHbeBestSeed(context.snapshot, hbe.observables, 0.04f);
    int right = dcrteHbeBestSeed(context.snapshot, hbe.observables, 0.96f);
    result = left < 0 || right < 0 || left == right
      ? new int[0] : new int[] {left, right};
  }
  if (result.length == 0 && !diagnostics.hasErrors())
    diagnostics.error("HBE_SEED_SELECTION_FAILED", "hbe_seed",
      "No confidence-qualified HBE candidate seeds were found", 0, -1,
      "inspect intrinsic anchors and candidate connectivity");
  dcrteHbeSeedSelection.selectedIndices = result;
  dcrteHbeSeedSelection.selectedS = new float[result.length];
  dcrteHbeSeedSelection.selectedRho = new float[result.length];
  dcrteHbeSeedSelection.selectedConfidence = new float[result.length];
  for (int i = 0; i < result.length; i++) {
    int index = result[i];
    dcrteHbeSeedSelection.selectedS[i] = 0.5f * (hbe.observables.xi[index] + 1);
    dcrteHbeSeedSelection.selectedRho[i] = hbe.observables.rho[index];
    dcrteHbeSeedSelection.selectedConfidence[i] = hbe.observables.confidence[index];
  }
  dcrteHbeSeedSelection.status = result.length == 0 ? "failed" : "resolved";
  return result;
}

int dcrteHbeBestSeed(CandidateVolumeSnapshot candidate,
    HBEIntrinsicObservables observables, float targetS) {
  if (candidate == null || observables == null) return -1;
  float maxDepth = 0;
  for (int i = 0; i < candidate.signedDistance.length; i++)
    if (candidate.candidateSolid[i] && dcrteFinite(candidate.signedDistance[i]))
      maxDepth = max(maxDepth, -candidate.signedDistance[i]);
  int best = -1; float bestCost = Float.POSITIVE_INFINITY;
  for (int i = 0; i < candidate.candidateSolid.length; i++) {
    if (!candidate.candidateSolid[i] || !observables.valid[i]) continue;
    float s = 0.5f * (observables.xi[i] + 1);
    float depth = dcrteFinite(candidate.signedDistance[i]) && maxDepth > 0
      ? constrain(-candidate.signedDistance[i] / maxDepth, 0, 1) : 0;
    float cost = 4.0f * abs(s - targetS) + observables.rho[i]
      + 0.5f * (1 - observables.confidence[i]) + 0.25f * (1 - depth);
    if (cost < bestCost || cost == bestCost && (best < 0 || i < best)) {
      best = i; bestCost = cost;
    }
  }
  return best;
}
