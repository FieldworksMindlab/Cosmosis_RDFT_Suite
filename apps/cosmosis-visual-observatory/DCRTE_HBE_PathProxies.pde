/* M6-HX graph-pairing proxy. These costs are not RT surfaces or geodesic lengths. */

enum HBEPairingProxy {
  CONNECTED, DISCONNECTED, UNAVAILABLE;
  String id() { return name().toLowerCase(); }
}

class HBEGraphPairingReport {
  float connectedCost = Float.NaN;
  float disconnectedCost = Float.NaN;
  float deltaCost = Float.NaN;
  HBEPairingProxy selected = HBEPairingProxy.UNAVAILABLE;
  int validAnchorPatches;
  String graphHash = "";

  boolean isValid() {
    return dcrteFinite(connectedCost) && dcrteFinite(disconnectedCost)
      && dcrteFinite(deltaCost) && selected != HBEPairingProxy.UNAVAILABLE;
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setBoolean("available", isValid());
    if (dcrteFinite(connectedCost)) j.setFloat("connected_graph_cost", connectedCost);
    if (dcrteFinite(disconnectedCost)) j.setFloat("disconnected_graph_cost", disconnectedCost);
    if (dcrteFinite(deltaCost)) j.setFloat("delta_cost", deltaCost);
    j.setString("selected_pairing_proxy", selected.id());
    j.setInt("valid_anchor_patches", validAnchorPatches); j.setString("graph_sha256", graphHash);
    j.setString("semantics", "deterministic voxel-graph pairing proxy");
    j.setBoolean("rt_surface", false); j.setBoolean("regularized_geodesic", false);
    return j;
  }
}

class HBEGraphNode implements Comparable<HBEGraphNode> {
  final int index; final float cost;
  HBEGraphNode(int index, float cost) { this.index = index; this.cost = cost; }
  public int compareTo(HBEGraphNode other) {
    int byCost = Float.compare(cost, other.cost);
    return byCost != 0 ? byCost : index - other.index;
  }
}

HBEGraphPairingReport dcrteHbeAnalyzeGraphPairing(boolean[] mask,
    HBEIntrinsicObservables observables) {
  HBEGraphPairingReport report = new HBEGraphPairingReport();
  if (mask == null || observables == null || !observables.isValid()
      || mask.length != observables.valid.length) return report;
  for (int patch = 0; patch < 4; patch++)
    if (dcrteHbePatchCount(mask, observables, patch) > 0) report.validAnchorPatches++;
  if (report.validAnchorPatches < 4) return report;
  float left = dcrteHbePatchPathCost(mask, observables, 0, 1);
  float right = dcrteHbePatchPathCost(mask, observables, 2, 3);
  float upper = dcrteHbePatchPathCost(mask, observables, 0, 2);
  float lower = dcrteHbePatchPathCost(mask, observables, 1, 3);
  report.disconnectedCost = dcrteFinite(left) && dcrteFinite(right) ? left + right : Float.NaN;
  report.connectedCost = dcrteFinite(upper) && dcrteFinite(lower) ? upper + lower : Float.NaN;
  if (dcrteFinite(report.connectedCost) && dcrteFinite(report.disconnectedCost)) {
    report.deltaCost = report.connectedCost - report.disconnectedCost;
    report.selected = report.deltaCost < 0 ? HBEPairingProxy.CONNECTED : HBEPairingProxy.DISCONNECTED;
  }
  report.graphHash = dcrteSha256Hex(dcrteHbeBooleanMaskHash(mask) + "|"
    + report.connectedCost + "|" + report.disconnectedCost + "|" + report.selected.id());
  return report;
}

int dcrteHbePatchCount(boolean[] mask, HBEIntrinsicObservables o, int patch) {
  int count = 0;
  for (int i = 0; i < mask.length; i++) if (mask[i] && dcrteHbeInPatch(o, i, patch)) count++;
  return count;
}

boolean dcrteHbeInPatch(HBEIntrinsicObservables o, int index, int patch) {
  if (o == null || index < 0 || index >= o.valid.length || !o.valid[index]
      || o.rho[index] < 0.30f) return false;
  boolean left = patch < 2;
  boolean upper = patch == 0 || patch == 2;
  boolean side = left ? o.leftAnchor[index] : o.rightAnchor[index];
  float vertical = sin(o.theta[index]);
  return side && (upper ? vertical >= 0.35f : vertical <= -0.35f);
}

float dcrteHbePatchPathCost(boolean[] mask, HBEIntrinsicObservables o,
    int sourcePatch, int targetPatch) {
  int n = mask.length; float[] distance = new float[n]; boolean[] closed = new boolean[n];
  java.util.Arrays.fill(distance, Float.POSITIVE_INFINITY);
  java.util.PriorityQueue<HBEGraphNode> queue = new java.util.PriorityQueue<HBEGraphNode>();
  for (int i = 0; i < n; i++) if (mask[i] && dcrteHbeInPatch(o, i, sourcePatch)) {
    distance[i] = 0; queue.add(new HBEGraphNode(i, 0));
  }
  while (!queue.isEmpty()) {
    HBEGraphNode node = queue.poll(); int index = node.index;
    if (closed[index] || node.cost != distance[index]) continue;
    closed[index] = true;
    if (dcrteHbeInPatch(o, index, targetPatch)) return node.cost * o.spec.minSpacing();
    int[] neighbors = dcrteSixNeighbors(index, o.spec);
    for (int k = 0; k < neighbors.length; k++) {
      int next = neighbors[k]; if (closed[next] || !mask[next] || !o.valid[next]) continue;
      float step = 1.0f + 0.50f * (1 - constrain(o.confidence[next], 0, 1))
        + 0.12f * constrain(o.neckProximity[next], 0, 1);
      float candidate = node.cost + step;
      if (candidate < distance[next]) { distance[next] = candidate; queue.add(new HBEGraphNode(next, candidate)); }
    }
  }
  return Float.NaN;
}
