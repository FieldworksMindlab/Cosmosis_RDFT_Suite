/* DCRTE-ET Milestone 4 deterministic component and seed strategies. */

interface SeedStrategy {
  String getId();
  int[] resolve(SchedulerContext context, SchedulerDiagnostics diagnostics);
}

class CenterNearestSeedStrategy implements SeedStrategy {
  public String getId() { return "center_nearest"; }
  public int[] resolve(SchedulerContext context, SchedulerDiagnostics diagnostics) {
    int seed = dcrteNearestCandidateToCenter(context.snapshot, -1, context.componentLabels);
    if (seed < 0) diagnostics.error("SCH_SEED_SELECTION_FAILED", "seed", "No admitted candidate seed exists", 0, -1, "rebuild candidate snapshot");
    return seed < 0 ? new int[0] : new int[] {seed};
  }
}

class IntrinsicEndpointSeedStrategy implements SeedStrategy {
  boolean start;
  IntrinsicEndpointSeedStrategy(boolean start) { this.start = start; }
  public String getId() { return start ? "intrinsic_start" : "intrinsic_end"; }
  public int[] resolve(SchedulerContext context, SchedulerDiagnostics diagnostics) {
    CandidateVolumeSnapshot snapshot = context.snapshot;
    if (!snapshot.hasIntrinsic()) {
      diagnostics.warn("SCH_SEED_RELOCATED", "seed", "Intrinsic coordinates unavailable; center-nearest seed used", 1, -1, "build intrinsic coordinates for endpoint seeding");
      return new CenterNearestSeedStrategy().resolve(context, diagnostics);
    }
    int best = -1; float bestValue = start ? Float.POSITIVE_INFINITY : Float.NEGATIVE_INFINITY;
    for (int i = 0; i < snapshot.candidateSolid.length; i++) {
      if (!snapshot.candidateSolid[i] || !dcrteFinite(snapshot.intrinsicS[i])) continue;
      float value = snapshot.intrinsicS[i];
      boolean better = start ? value < bestValue : value > bestValue;
      if (better || value == bestValue && (best < 0 || i < best)) { best = i; bestValue = value; }
    }
    if (best < 0) diagnostics.error("SCH_SEED_SELECTION_FAILED", "seed", "No valid intrinsic endpoint candidate exists", 0, -1, "inspect intrinsic confidence and candidate mask");
    return best < 0 ? new int[0] : new int[] {best};
  }
}

class ComponentSeedStrategy implements SeedStrategy {
  public String getId() { return "component_seeds"; }
  public int[] resolve(SchedulerContext context, SchedulerDiagnostics diagnostics) {
    int components = context.candidateComponentCount;
    if (components <= 0 || context.componentLabels == null) return new int[0];
    int[] seeds = new int[components]; java.util.Arrays.fill(seeds, -1);
    float[] distance = new float[components]; java.util.Arrays.fill(distance, Float.POSITIVE_INFINITY);
    CandidateVolumeSnapshot snapshot = context.snapshot;
    float cx = (snapshot.spec.nx - 1) * 0.5f, cy = (snapshot.spec.ny - 1) * 0.5f, cz = (snapshot.spec.nz - 1) * 0.5f;
    for (int i = 0; i < snapshot.candidateSolid.length; i++) {
      int component = context.componentLabels[i]; if (component < 0) continue;
      int x = i % snapshot.spec.nx; int yz = i / snapshot.spec.nx;
      int y = yz % snapshot.spec.ny; int z = yz / snapshot.spec.ny;
      float d = (x-cx)*(x-cx) + (y-cy)*(y-cy) + (z-cz)*(z-cz);
      if (d < distance[component] || d == distance[component] && (seeds[component] < 0 || i < seeds[component])) {
        distance[component] = d; seeds[component] = i;
      }
    }
    return seeds;
  }
}

SeedStrategy dcrteSeedStrategy(SchedulerSeedMode mode) {
  if (dcrteM6BoundarySeedEnabled()) {
    return new BoundaryAnchoredSeedStrategy(dcrteCompositionConfiguration);
  }
  if (mode == SchedulerSeedMode.INTRINSIC_START) return new IntrinsicEndpointSeedStrategy(true);
  if (mode == SchedulerSeedMode.INTRINSIC_END) return new IntrinsicEndpointSeedStrategy(false);
  if (mode == SchedulerSeedMode.COMPONENT_SEEDS) return new ComponentSeedStrategy();
  return new CenterNearestSeedStrategy();
}

int dcrteNearestCandidateToCenter(CandidateVolumeSnapshot snapshot, int requiredComponent, int[] labels) {
  if (snapshot == null) return -1;
  float cx = (snapshot.spec.nx - 1) * 0.5f, cy = (snapshot.spec.ny - 1) * 0.5f, cz = (snapshot.spec.nz - 1) * 0.5f;
  int best = -1; float bestDistance = Float.POSITIVE_INFINITY;
  for (int i = 0; i < snapshot.candidateSolid.length; i++) {
    if (!snapshot.candidateSolid[i] || requiredComponent >= 0 && (labels == null || labels[i] != requiredComponent)) continue;
    int x = i % snapshot.spec.nx; int yz = i / snapshot.spec.nx; int y = yz % snapshot.spec.ny; int z = yz / snapshot.spec.ny;
    float d = (x-cx)*(x-cx) + (y-cy)*(y-cy) + (z-cz)*(z-cz);
    if (d < bestDistance || d == bestDistance && (best < 0 || i < best)) { best = i; bestDistance = d; }
  }
  return best;
}

int[] dcrteCandidateComponentLabels(CandidateVolumeSnapshot snapshot, int[] componentCountOut) {
  int n = snapshot == null ? 0 : snapshot.candidateSolid.length;
  int[] labels = new int[n]; java.util.Arrays.fill(labels, -1);
  int[] queue = new int[n]; int components = 0;
  if (snapshot != null) {
    for (int start = 0; start < n; start++) {
      if (!snapshot.candidateSolid[start] || labels[start] >= 0) continue;
      int head = 0, tail = 0; queue[tail++] = start; labels[start] = components;
      while (head < tail) {
        int index = queue[head++];
        int x = index % snapshot.spec.nx;
        int yz = index / snapshot.spec.nx;
        int y = yz % snapshot.spec.ny;
        int z = yz / snapshot.spec.ny;
        int plane = snapshot.spec.nx * snapshot.spec.ny;
        if (x > 0) tail = dcrteQueueComponentNeighbor(index - 1, snapshot, labels, components, queue, tail);
        if (x + 1 < snapshot.spec.nx) tail = dcrteQueueComponentNeighbor(index + 1, snapshot, labels, components, queue, tail);
        if (y > 0) tail = dcrteQueueComponentNeighbor(index - snapshot.spec.nx, snapshot, labels, components, queue, tail);
        if (y + 1 < snapshot.spec.ny) tail = dcrteQueueComponentNeighbor(index + snapshot.spec.nx, snapshot, labels, components, queue, tail);
        if (z > 0) tail = dcrteQueueComponentNeighbor(index - plane, snapshot, labels, components, queue, tail);
        if (z + 1 < snapshot.spec.nz) tail = dcrteQueueComponentNeighbor(index + plane, snapshot, labels, components, queue, tail);
      }
      components++;
    }
  }
  if (componentCountOut != null && componentCountOut.length > 0) componentCountOut[0] = components;
  return labels;
}

int dcrteQueueComponentNeighbor(int index, CandidateVolumeSnapshot snapshot, int[] labels,
    int component, int[] queue, int tail) {
  if (!snapshot.candidateSolid[index] || labels[index] >= 0) return tail;
  labels[index] = component;
  queue[tail] = index;
  return tail + 1;
}

int[] dcrteSixNeighbors(int index, VolumeSpec spec) {
  int x = index % spec.nx; int yz = index / spec.nx; int y = yz % spec.ny; int z = yz / spec.ny;
  int count = (x > 0 ? 1 : 0) + (x + 1 < spec.nx ? 1 : 0) + (y > 0 ? 1 : 0)
    + (y + 1 < spec.ny ? 1 : 0) + (z > 0 ? 1 : 0) + (z + 1 < spec.nz ? 1 : 0);
  int[] result = new int[count]; int p = 0;
  if (x > 0) result[p++] = index - 1; if (x + 1 < spec.nx) result[p++] = index + 1;
  if (y > 0) result[p++] = index - spec.nx; if (y + 1 < spec.ny) result[p++] = index + spec.nx;
  int plane = spec.nx * spec.ny;
  if (z > 0) result[p++] = index - plane; if (z + 1 < spec.nz) result[p++] = index + plane;
  return result;
}

int[] dcrteSchedulerNeighbors(int index, VolumeSpec spec, SchedulerNeighborhoodMode mode) {
  if (mode == SchedulerNeighborhoodMode.SIX_CONNECTED) return dcrteSixNeighbors(index, spec);
  int x = index % spec.nx; int yz = index / spec.nx; int y = yz % spec.ny; int z = yz / spec.ny;
  int[] buffer = new int[26]; int count = 0;
  for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
    if (dx == 0 && dy == 0 && dz == 0) continue;
    int manhattan = abs(dx) + abs(dy) + abs(dz);
    if (mode == SchedulerNeighborhoodMode.EIGHTEEN_CONNECTED && manhattan == 3) continue;
    int xx = x + dx, yy = y + dy, zz = z + dz;
    if (xx < 0 || yy < 0 || zz < 0 || xx >= spec.nx || yy >= spec.ny || zz >= spec.nz) continue;
    buffer[count++] = xx + spec.nx * (yy + spec.ny * zz);
  }
  return java.util.Arrays.copyOf(buffer, count);
}
