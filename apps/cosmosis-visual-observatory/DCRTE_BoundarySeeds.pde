/* DCRTE-ET Milestone 6 boundary-derived SeedStrategy implementation. */

class BoundaryAnchoredSeedStrategy implements SeedStrategy {
  BoundarySeedMode mode;
  SourceShellConfiguration shellConfiguration;
  int distributedCount;
  int selectedPatch;

  BoundaryAnchoredSeedStrategy(MaterialCompositionConfiguration configuration) {
    mode = configuration == null ? BoundarySeedMode.SOURCE_SHELL_NEAREST_CENTER
      : configuration.boundarySeedMode;
    shellConfiguration = configuration == null || configuration.sourceShell == null
      ? new SourceShellConfiguration() : configuration.sourceShell.copy();
    distributedCount = configuration == null ? 4 : max(1, configuration.distributedSeedCount);
    selectedPatch = configuration == null ? 0 : max(0, configuration.selectedPatchIndex);
  }

  public String getId() {
    return "m6_boundary_" + mode.id();
  }

  public int[] resolve(SchedulerContext context, SchedulerDiagnostics diagnostics) {
    if (context == null || context.snapshot == null || !context.snapshot.hasSignedDistance()) {
      diagnostics.error(DCRTEM6Codes.BOUNDARY_SEED_FAILED, "seed",
        "Boundary seeding requires a candidate snapshot with signed distance.",
        0, -1, "build a qualified signed-distance source domain");
      return new int[0];
    }
    CandidateVolumeSnapshot snapshot = context.snapshot;
    float spacing = snapshot.spec.minSpacing();
    float shellDepth = (max(1, shellConfiguration.fabricationShellThicknessVoxels) + 1.0f) * spacing;
    float epsilon = max(0, shellConfiguration.boundaryEpsilonVoxels) * spacing;
    IntArrayBuilder eligibleBuilder = new IntArrayBuilder(256);
    for (int i = 0; i < snapshot.candidateSolid.length; i++) {
      if (!snapshot.candidateSolid[i]) continue;
      float sdf = snapshot.signedDistance[i];
      if (dcrteFinite(sdf) && sdf <= epsilon && sdf >= -(shellDepth + epsilon)) eligibleBuilder.add(i);
    }
    int[] eligible = eligibleBuilder.toArray();
    if (eligible.length == 0) {
      diagnostics.error(DCRTEM6Codes.BOUNDARY_SEED_FAILED, "seed",
        "No candidate voxel intersects the inward source-shell seed band.",
        0, -1, "increase shell depth or inspect candidate/source intersection");
      return new int[0];
    }
    java.util.Arrays.sort(eligible);
    if (mode == BoundarySeedMode.DISTRIBUTED) {
      return distributedFarthest(eligible, snapshot.spec, min(distributedCount, eligible.length));
    }
    int selected = selectOne(eligible, snapshot);
    if (selected < 0) {
      diagnostics.error(DCRTEM6Codes.BOUNDARY_SEED_FAILED, "seed",
        "No deterministic boundary seed could be resolved.",
        0, -1, "inspect the active boundary seed mode");
      return new int[0];
    }
    if (mode == BoundarySeedMode.SELECTED_PATCH) {
      diagnostics.warn(DCRTEM6Codes.BOUNDARY_SEED_RELOCATED, "seed",
        "Selected patch was resolved to its nearest eligible candidate voxel.",
        1, selected, "inspect the composition patch overlay");
    }
    return new int[] {selected};
  }

  int selectOne(int[] eligible, CandidateVolumeSnapshot snapshot) {
    if (mode == BoundarySeedMode.SOURCE_SHELL_INTRINSIC_START
        || mode == BoundarySeedMode.SOURCE_SHELL_INTRINSIC_END) {
      if (!snapshot.hasIntrinsic()) return nearestCenter(eligible, snapshot.spec);
      boolean start = mode == BoundarySeedMode.SOURCE_SHELL_INTRINSIC_START;
      int best = -1;
      float bestValue = start ? Float.POSITIVE_INFINITY : Float.NEGATIVE_INFINITY;
      for (int i = 0; i < eligible.length; i++) {
        int index = eligible[i];
        float value = snapshot.intrinsicS[index];
        if (!dcrteFinite(value)) continue;
        boolean better = start ? value < bestValue : value > bestValue;
        if (better || value == bestValue && (best < 0 || index < best)) {
          best = index;
          bestValue = value;
        }
      }
      return best < 0 ? nearestCenter(eligible, snapshot.spec) : best;
    }
    if (mode == BoundarySeedMode.SELECTED_PATCH) {
      int patch = selectedPatch % 8;
      int best = -1;
      float bestDistance = Float.POSITIVE_INFINITY;
      float cx = (snapshot.spec.nx - 1) * 0.5f;
      float cy = (snapshot.spec.ny - 1) * 0.5f;
      float cz = (snapshot.spec.nz - 1) * 0.5f;
      for (int i = 0; i < eligible.length; i++) {
        int index = eligible[i];
        int x = index % snapshot.spec.nx;
        int yz = index / snapshot.spec.nx;
        int y = yz % snapshot.spec.ny;
        int z = yz / snapshot.spec.ny;
        int octant = (x >= cx ? 1 : 0) | (y >= cy ? 2 : 0) | (z >= cz ? 4 : 0);
        if (octant != patch) continue;
        float d = (x - cx) * (x - cx) + (y - cy) * (y - cy) + (z - cz) * (z - cz);
        if (d < bestDistance || d == bestDistance && (best < 0 || index < best)) {
          best = index;
          bestDistance = d;
        }
      }
      return best < 0 ? nearestCenter(eligible, snapshot.spec) : best;
    }
    return nearestCenter(eligible, snapshot.spec);
  }

  int nearestCenter(int[] eligible, VolumeSpec spec) {
    float cx = (spec.nx - 1) * 0.5f;
    float cy = (spec.ny - 1) * 0.5f;
    float cz = (spec.nz - 1) * 0.5f;
    int best = -1;
    float bestDistance = Float.POSITIVE_INFINITY;
    for (int i = 0; i < eligible.length; i++) {
      int index = eligible[i];
      int x = index % spec.nx;
      int yz = index / spec.nx;
      int y = yz % spec.ny;
      int z = yz / spec.ny;
      float distance = (x - cx) * (x - cx) + (y - cy) * (y - cy) + (z - cz) * (z - cz);
      if (distance < bestDistance || distance == bestDistance && (best < 0 || index < best)) {
        best = index;
        bestDistance = distance;
      }
    }
    return best;
  }

  int[] distributedFarthest(int[] eligible, VolumeSpec spec, int requested) {
    int[] seeds = new int[requested];
    seeds[0] = nearestCenter(eligible, spec);
    for (int count = 1; count < requested; count++) {
      int best = -1;
      float bestMinimum = -1;
      for (int i = 0; i < eligible.length; i++) {
        int candidate = eligible[i];
        boolean used = false;
        for (int s = 0; s < count; s++) if (seeds[s] == candidate) used = true;
        if (used) continue;
        float minimum = Float.POSITIVE_INFINITY;
        for (int s = 0; s < count; s++) minimum = min(minimum,
          dcrteM6VoxelDistanceSquared(candidate, seeds[s], spec));
        if (minimum > bestMinimum || minimum == bestMinimum && (best < 0 || candidate < best)) {
          best = candidate;
          bestMinimum = minimum;
        }
      }
      seeds[count] = best;
    }
    java.util.Arrays.sort(seeds);
    return seeds;
  }
}

float dcrteM6VoxelDistanceSquared(int a, int b, VolumeSpec spec) {
  int ax = a % spec.nx, ayz = a / spec.nx, ay = ayz % spec.ny, az = ayz / spec.ny;
  int bx = b % spec.nx, byz = b / spec.nx, by = byz % spec.ny, bz = byz / spec.ny;
  return (ax - bx) * (ax - bx) + (ay - by) * (ay - by) + (az - bz) * (az - bz);
}

boolean dcrteM6BoundarySeedEnabled() {
  return dcrteCompositionConfiguration != null
    && dcrteCompositionConfiguration.mode == MaterialCompositionMode.BOUNDARY_ANCHORED_SCAFFOLD
    && dcrteCompositionConfiguration.attachmentPolicy == BoundaryAttachmentPolicy.SEED_FROM_BOUNDARY
    && dcrteCompositionConfiguration.boundarySeedMode != BoundarySeedMode.NONE;
}
