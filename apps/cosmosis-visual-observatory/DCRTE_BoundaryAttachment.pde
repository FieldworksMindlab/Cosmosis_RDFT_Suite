/* DCRTE-ET Milestone 6 deterministic scaffold-to-source-shell attachment analysis. */

enum BoundaryAttachmentClass {
  BOUNDARY_ATTACHED,
  ATTACHED_THROUGH_SCAFFOLD,
  NEAR_BOUNDARY_UNATTACHED,
  FLOATING_INTERIOR,
  TOO_SMALL,
  INVALID;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

class BoundaryAttachmentComponentReport {
  int componentId;
  BoundaryAttachmentClass classification = BoundaryAttachmentClass.INVALID;
  int voxelCount;
  int directContactFaces;
  int directContactVoxels;
  int contactPatchCount;
  float contactAreaWorld;
  float contactAreaMM2;
  float minimumBoundaryDistanceVoxels = Float.POSITIVE_INFINITY;
  float meanBoundaryDistanceVoxels = Float.NaN;
  float thicknessP05Voxels = Float.NaN;
  float thicknessMedianVoxels = Float.NaN;
  boolean exportBlocking;
  int minX, minY, minZ, maxX, maxY, maxZ;
  float centroidX, centroidY, centroidZ;
  int[] voxelIndices = new int[0];

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("component_id", componentId);
    json.setString("classification", classification.id());
    json.setInt("voxel_count", voxelCount);
    json.setInt("direct_contact_faces", directContactFaces);
    json.setInt("direct_contact_voxels", directContactVoxels);
    json.setInt("contact_patches", contactPatchCount);
    json.setFloat("contact_area_world", contactAreaWorld);
    json.setFloat("contact_area_mm2", contactAreaMM2);
    json.setFloat("minimum_boundary_distance_voxels", minimumBoundaryDistanceVoxels);
    json.setFloat("mean_boundary_distance_voxels", meanBoundaryDistanceVoxels);
    json.setFloat("thickness_p05_voxels", thicknessP05Voxels);
    json.setFloat("thickness_median_voxels", thicknessMedianVoxels);
    json.setString("thickness_semantics", "geometric voxel-neighborhood proxy; not a mechanical strength estimate");
    json.setBoolean("export_blocking", exportBlocking);
    JSONArray boundsMin = new JSONArray();
    boundsMin.setInt(0, minX); boundsMin.setInt(1, minY); boundsMin.setInt(2, minZ);
    JSONArray boundsMax = new JSONArray();
    boundsMax.setInt(0, maxX); boundsMax.setInt(1, maxY); boundsMax.setInt(2, maxZ);
    json.setJSONArray("bounds_min", boundsMin);
    json.setJSONArray("bounds_max", boundsMax);
    JSONArray centroid = new JSONArray();
    centroid.setFloat(0, centroidX); centroid.setFloat(1, centroidY); centroid.setFloat(2, centroidZ);
    json.setJSONArray("centroid_voxels", centroid);
    return json;
  }
}

class BoundaryAttachmentReport {
  ArrayList<BoundaryAttachmentComponentReport> components =
    new ArrayList<BoundaryAttachmentComponentReport>();
  int scaffoldVoxelCount;
  int componentCount;
  int boundaryAttachedCount;
  int attachedThroughScaffoldCount;
  int nearBoundaryUnattachedCount;
  int floatingInteriorCount;
  int tooSmallCount;
  int invalidCount;
  int attachedVoxelCount;
  int directContactFaces;
  float attachedFraction;
  String maskHash = "";

  boolean hasUnattached() {
    return nearBoundaryUnattachedCount > 0 || floatingInteriorCount > 0
      || tooSmallCount > 0 || invalidCount > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("version", "1.0-m6");
    json.setInt("scaffold_voxels", scaffoldVoxelCount);
    json.setInt("component_count", componentCount);
    json.setInt("boundary_attached_components", boundaryAttachedCount);
    json.setInt("attached_through_scaffold_components", attachedThroughScaffoldCount);
    json.setInt("near_boundary_unattached_components", nearBoundaryUnattachedCount);
    json.setInt("floating_interior_components", floatingInteriorCount);
    json.setInt("too_small_components", tooSmallCount);
    json.setInt("invalid_components", invalidCount);
    json.setInt("attached_voxels", attachedVoxelCount);
    json.setInt("direct_contact_faces", directContactFaces);
    json.setFloat("attached_fraction", attachedFraction);
    json.setString("scaffold_mask_sha256", maskHash);
    JSONArray entries = new JSONArray();
    for (int i = 0; i < components.size(); i++) entries.setJSONObject(i, components.get(i).toJSON());
    json.setJSONArray("components", entries);
    return json;
  }
}

class BoundaryAttachmentAnalyzer {
  BoundaryAttachmentReport analyze(boolean[] scaffold, boolean[] sourceShell,
      SignedDistanceVolume sdf, VolumeSpec spec, MaterialCompositionConfiguration config) {
    BoundaryAttachmentReport report = new BoundaryAttachmentReport();
    if (scaffold == null || sourceShell == null || spec == null || !spec.isValid()
        || scaffold.length != spec.voxelCount() || sourceShell.length != scaffold.length) {
      report.invalidCount = 1;
      return report;
    }
    MaterialCompositionConfiguration configuration = config == null
      ? new MaterialCompositionConfiguration() : config;
    report.maskHash = dcrteBooleanMaskHash(scaffold);
    for (int i = 0; i < scaffold.length; i++) if (scaffold[i]) report.scaffoldVoxelCount++;
    boolean[] visited = new boolean[scaffold.length];
    int[] queue = new int[scaffold.length];
    int componentId = 0;
    for (int start = 0; start < scaffold.length; start++) {
      if (!scaffold[start] || visited[start]) continue;
      IntArrayBuilder members = new IntArrayBuilder(128);
      int head = 0;
      int tail = 0;
      queue[tail++] = start;
      visited[start] = true;
      while (head < tail) {
        int index = queue[head++];
        members.add(index);
        int[] neighbors = configuration.attachmentNeighborhood == AttachmentNeighborhoodMode.TWENTY_SIX_CONNECTED
          ? dcrteSchedulerNeighbors(index, spec, SchedulerNeighborhoodMode.TWENTY_SIX_CONNECTED)
          : dcrteSixNeighbors(index, spec);
        for (int i = 0; i < neighbors.length; i++) {
          int neighbor = neighbors[i];
          if (!scaffold[neighbor] || visited[neighbor]) continue;
          visited[neighbor] = true;
          queue[tail++] = neighbor;
        }
      }
      BoundaryAttachmentComponentReport component = analyzeComponent(componentId++,
        members.toArray(), scaffold, sourceShell, sdf, spec, configuration);
      report.components.add(component);
      report.directContactFaces += component.directContactFaces;
      if (component.classification == BoundaryAttachmentClass.BOUNDARY_ATTACHED) {
        report.boundaryAttachedCount++;
        report.attachedVoxelCount += component.voxelCount;
      } else if (component.classification == BoundaryAttachmentClass.ATTACHED_THROUGH_SCAFFOLD) {
        report.attachedThroughScaffoldCount++;
        report.attachedVoxelCount += component.voxelCount;
      } else if (component.classification == BoundaryAttachmentClass.NEAR_BOUNDARY_UNATTACHED) {
        report.nearBoundaryUnattachedCount++;
      } else if (component.classification == BoundaryAttachmentClass.FLOATING_INTERIOR) {
        report.floatingInteriorCount++;
      } else if (component.classification == BoundaryAttachmentClass.TOO_SMALL) {
        report.tooSmallCount++;
      } else report.invalidCount++;
    }
    report.componentCount = report.components.size();
    report.attachedFraction = report.scaffoldVoxelCount == 0 ? 0
      : report.attachedVoxelCount / (float)report.scaffoldVoxelCount;
    return report;
  }

  BoundaryAttachmentComponentReport analyzeComponent(int componentId, int[] members,
      boolean[] scaffold, boolean[] sourceShell, SignedDistanceVolume sdf,
      VolumeSpec spec, MaterialCompositionConfiguration config) {
    BoundaryAttachmentComponentReport result = new BoundaryAttachmentComponentReport();
    result.componentId = componentId;
    result.voxelIndices = members;
    result.voxelCount = members.length;
    result.minX = result.minY = result.minZ = Integer.MAX_VALUE;
    result.maxX = result.maxY = result.maxZ = Integer.MIN_VALUE;
    float spacing = spec.minSpacing();
    float faceAreaWorld = spacing * spacing;
    float worldToMM = spec.bounds == null || spec.bounds.sizeX() <= 0
      ? 1.0f : foundryScaleMM / spec.bounds.sizeX();
    float distanceSum = 0;
    int distanceSamples = 0;
    float[] thickness = new float[members.length];
    boolean[] contactMask = new boolean[sourceShell.length];
    float sumX = 0, sumY = 0, sumZ = 0;
    for (int m = 0; m < members.length; m++) {
      int index = members[m];
      int x = index % spec.nx;
      int yz = index / spec.nx;
      int y = yz % spec.ny;
      int z = yz / spec.ny;
      sumX += x; sumY += y; sumZ += z;
      result.minX = min(result.minX, x); result.minY = min(result.minY, y); result.minZ = min(result.minZ, z);
      result.maxX = max(result.maxX, x); result.maxY = max(result.maxY, y); result.maxZ = max(result.maxZ, z);
      int localNeighbors = 0;
      boolean touches = sourceShell[index];
      int[] neighbors = dcrteSixNeighbors(index, spec);
      for (int i = 0; i < neighbors.length; i++) {
        int neighbor = neighbors[i];
        if (scaffold[neighbor]) localNeighbors++;
        if (sourceShell[neighbor]) {
          result.directContactFaces++;
          contactMask[neighbor] = true;
          touches = true;
        }
      }
      if (touches) result.directContactVoxels++;
      thickness[m] = 1.0f + localNeighbors * 0.5f;
      float boundaryDistance = sdf == null || !sdf.isValid() || !dcrteFinite(sdf.signedDistance[index])
        ? Float.POSITIVE_INFINITY : max(0, -sdf.signedDistance[index] / max(0.000001f, spacing));
      result.minimumBoundaryDistanceVoxels = min(result.minimumBoundaryDistanceVoxels, boundaryDistance);
      if (dcrteFinite(boundaryDistance)) {
        distanceSum += boundaryDistance;
        distanceSamples++;
      }
    }
    result.centroidX = members.length == 0 ? 0 : sumX / members.length;
    result.centroidY = members.length == 0 ? 0 : sumY / members.length;
    result.centroidZ = members.length == 0 ? 0 : sumZ / members.length;
    result.meanBoundaryDistanceVoxels = distanceSamples == 0 ? Float.NaN : distanceSum / distanceSamples;
    java.util.Arrays.sort(thickness);
    result.thicknessP05Voxels = thickness.length == 0 ? Float.NaN
      : thickness[constrain(floor((thickness.length - 1) * 0.05f), 0, thickness.length - 1)];
    result.thicknessMedianVoxels = thickness.length == 0 ? Float.NaN
      : thickness[(thickness.length - 1) / 2];
    result.contactPatchCount = dcrteCountMaskComponents(contactMask, spec, false);
    result.contactAreaWorld = result.directContactFaces * faceAreaWorld;
    result.contactAreaMM2 = result.contactAreaWorld * worldToMM * worldToMM;

    if (members.length == 0) result.classification = BoundaryAttachmentClass.INVALID;
    else if (members.length < max(1, config.minimumComponentVoxels)) result.classification = BoundaryAttachmentClass.TOO_SMALL;
    else if (result.directContactFaces > 0 || result.directContactVoxels > 0) {
      result.classification = BoundaryAttachmentClass.BOUNDARY_ATTACHED;
    } else if (result.minimumBoundaryDistanceVoxels <= config.nearBoundaryDistanceVoxels) {
      result.classification = BoundaryAttachmentClass.NEAR_BOUNDARY_UNATTACHED;
    } else result.classification = BoundaryAttachmentClass.FLOATING_INTERIOR;
    result.exportBlocking = result.classification == BoundaryAttachmentClass.INVALID
      || result.classification == BoundaryAttachmentClass.TOO_SMALL
      || result.classification == BoundaryAttachmentClass.NEAR_BOUNDARY_UNATTACHED
      || result.classification == BoundaryAttachmentClass.FLOATING_INTERIOR;
    return result;
  }
}

BoundaryAttachmentAnalyzer dcrteBoundaryAttachmentAnalyzer = new BoundaryAttachmentAnalyzer();
