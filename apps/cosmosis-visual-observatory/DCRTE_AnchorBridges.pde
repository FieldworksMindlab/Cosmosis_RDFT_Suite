/* DCRTE-ET Milestone 6 deterministic shortest-path attachment bridges. */

class M6BridgeNode implements Comparable<M6BridgeNode> {
  int index;
  float cost;
  int steps;

  M6BridgeNode(int index, float cost, int steps) {
    this.index = index;
    this.cost = cost;
    this.steps = steps;
  }

  public int compareTo(M6BridgeNode other) {
    int byCost = Float.compare(cost, other.cost);
    if (byCost != 0) return byCost;
    int bySteps = Integer.compare(steps, other.steps);
    if (bySteps != 0) return bySteps;
    return Integer.compare(index, other.index);
  }
}

class AnchorBridgeResult {
  int attemptedComponents;
  int bridgedComponents;
  int failedComponents;
  int bridgeVoxelCount;
  int supportVoxelCount;
  int longestPathVoxels;
  ArrayList<M6Diagnostic> diagnostics = new ArrayList<M6Diagnostic>();

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("attempted_components", attemptedComponents);
    json.setInt("bridged_components", bridgedComponents);
    json.setInt("failed_components", failedComponents);
    json.setInt("bridge_voxels", bridgeVoxelCount);
    json.setInt("support_voxels", supportVoxelCount);
    json.setInt("longest_path_voxels", longestPathVoxels);
    JSONArray entries = new JSONArray();
    for (int i = 0; i < diagnostics.size(); i++) entries.setJSONObject(i, diagnostics.get(i).toJSON());
    json.setJSONArray("diagnostics", entries);
    return json;
  }
}

class DeterministicAnchorBridgeBuilder {
  AnchorBridgeResult build(FabricationCompositionVolume volume,
      CandidateVolumeSnapshot snapshot, BoundaryAttachmentReport attachment,
      MaterialCompositionConfiguration config) {
    AnchorBridgeResult result = new AnchorBridgeResult();
    if (volume == null || !volume.isValid() || snapshot == null || attachment == null) {
      result.failedComponents = 1;
      result.diagnostics.add(new M6Diagnostic(DCRTEM6Codes.BRIDGE_NOT_FOUND,
        "Bridge construction inputs are incomplete.", true));
      return result;
    }
    boolean fieldConstrained = config.attachmentPolicy == BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED;
    for (int i = 0; i < attachment.components.size(); i++) {
      BoundaryAttachmentComponentReport component = attachment.components.get(i);
      if (component.classification == BoundaryAttachmentClass.BOUNDARY_ATTACHED
          || component.classification == BoundaryAttachmentClass.ATTACHED_THROUGH_SCAFFOLD) continue;
      result.attemptedComponents++;
      int[] path = shortestPath(component.voxelIndices, volume.sourceShell,
        volume.domainInside, snapshot, config, fieldConstrained);
      if (path.length == 0) {
        result.failedComponents++;
        result.diagnostics.add(new M6Diagnostic(DCRTEM6Codes.BRIDGE_NOT_FOUND,
          "No deterministic bridge satisfying the active attachment policy was found for component "
            + component.componentId + ".", true));
        continue;
      }
      result.bridgedComponents++;
      result.longestPathVoxels = max(result.longestPathVoxels, path.length - 1);
      applyDilatedPath(path, volume, snapshot, config, fieldConstrained);
    }
    for (int i = 0; i < volume.anchorBridge.length; i++) {
      if (volume.anchorBridge[i]) result.bridgeVoxelCount++;
      if (volume.supportMaterial[i]) result.supportVoxelCount++;
    }
    if (!fieldConstrained && result.supportVoxelCount > 0) {
      result.diagnostics.add(new M6Diagnostic(DCRTEM6Codes.SUPPORT_BRIDGE_USED,
        "Domain-constrained bridge voxels are explicitly labeled as support material.", false));
    }
    return result;
  }

  int[] shortestPath(int[] starts, boolean[] targetShell, boolean[] domainInside,
      CandidateVolumeSnapshot snapshot, MaterialCompositionConfiguration config,
      boolean fieldConstrained) {
    int count = domainInside.length;
    float[] distance = new float[count];
    int[] steps = new int[count];
    int[] previous = new int[count];
    boolean[] closed = new boolean[count];
    java.util.Arrays.fill(distance, Float.POSITIVE_INFINITY);
    java.util.Arrays.fill(steps, Integer.MAX_VALUE);
    java.util.Arrays.fill(previous, -1);
    java.util.PriorityQueue<M6BridgeNode> queue = new java.util.PriorityQueue<M6BridgeNode>();
    int[] sortedStarts = java.util.Arrays.copyOf(starts, starts.length);
    java.util.Arrays.sort(sortedStarts);
    for (int i = 0; i < sortedStarts.length; i++) {
      int start = sortedStarts[i];
      if (start < 0 || start >= count) continue;
      distance[start] = 0;
      steps[start] = 0;
      queue.add(new M6BridgeNode(start, 0, 0));
    }
    int reached = -1;
    while (!queue.isEmpty()) {
      M6BridgeNode node = queue.poll();
      if (closed[node.index]) continue;
      closed[node.index] = true;
      if (targetShell[node.index]) {
        reached = node.index;
        break;
      }
      if (node.steps >= max(1, config.bridgeMaxDistanceVoxels)) continue;
      int[] neighbors = dcrteSixNeighbors(node.index, snapshot.spec);
      for (int n = 0; n < neighbors.length; n++) {
        int neighbor = neighbors[n];
        if (!domainInside[neighbor]) continue;
        if (fieldConstrained && !snapshot.candidateSolid[neighbor] && !targetShell[neighbor]) continue;
        float fieldCompatibility = dcrteFinite(snapshot.fieldScalar[neighbor])
          ? 1.0f - constrain(abs(snapshot.fieldScalar[neighbor]) / max(0.0001f, foundryIsoBand), 0, 1)
          : 0;
        float confidence = snapshot.coordinateConfidence != null
          && neighbor < snapshot.coordinateConfidence.length
          && dcrteFinite(snapshot.coordinateConfidence[neighbor])
          ? constrain(snapshot.coordinateConfidence[neighbor], 0, 1) : 1.0f;
        float edgeCost = 1.0f
          + config.fieldPenaltyWeight * (1.0f - fieldCompatibility)
          + config.confidencePenaltyWeight * (1.0f - confidence);
        float nextCost = node.cost + edgeCost;
        int nextSteps = node.steps + 1;
        boolean better = nextCost < distance[neighbor] - 0.000001f
          || abs(nextCost - distance[neighbor]) <= 0.000001f
            && (nextSteps < steps[neighbor]
              || nextSteps == steps[neighbor] && node.index < previous[neighbor]);
        if (!better) continue;
        distance[neighbor] = nextCost;
        steps[neighbor] = nextSteps;
        previous[neighbor] = node.index;
        queue.add(new M6BridgeNode(neighbor, nextCost, nextSteps));
      }
    }
    if (reached < 0 || steps[reached] > config.bridgeMaxDistanceVoxels) return new int[0];
    int length = steps[reached] + 1;
    int[] path = new int[length];
    int cursor = reached;
    for (int i = length - 1; i >= 0; i--) {
      path[i] = cursor;
      cursor = previous[cursor];
    }
    return path;
  }

  void applyDilatedPath(int[] path, FabricationCompositionVolume volume,
      CandidateVolumeSnapshot snapshot, MaterialCompositionConfiguration config,
      boolean fieldConstrained) {
    int radius = max(0, ceil(config.bridgeRadiusVoxels));
    float radiusSquared = config.bridgeRadiusVoxels * config.bridgeRadiusVoxels + 0.0001f;
    for (int p = 0; p < path.length; p++) {
      int index = path[p];
      int x = index % volume.spec.nx;
      int yz = index / volume.spec.nx;
      int y = yz % volume.spec.ny;
      int z = yz / volume.spec.ny;
      for (int dz = -radius; dz <= radius; dz++) {
        for (int dy = -radius; dy <= radius; dy++) {
          for (int dx = -radius; dx <= radius; dx++) {
            if (dx * dx + dy * dy + dz * dz > radiusSquared) continue;
            int xx = x + dx, yy = y + dy, zz = z + dz;
            if (xx < 0 || yy < 0 || zz < 0
                || xx >= volume.spec.nx || yy >= volume.spec.ny || zz >= volume.spec.nz) continue;
            int target = volume.index(xx, yy, zz);
            if (!volume.domainInside[target]) continue;
            if (fieldConstrained && !snapshot.candidateSolid[target] && !volume.sourceShell[target]) continue;
            if (fieldConstrained) volume.anchorBridge[target] = true;
            else volume.supportMaterial[target] = true;
          }
        }
      }
    }
  }
}

DeterministicAnchorBridgeBuilder dcrteAnchorBridgeBuilder = new DeterministicAnchorBridgeBuilder();
