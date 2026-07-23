/* DCRTE-ET Milestone 6 source-envelope role and inward fabrication shell. */

enum SourceShellRolePolicy {
  SINGLE_QUALIFIED_COMPONENT,
  DOMINANT_QUALIFIED_COMPONENT,
  EXPLICIT_COMPONENT;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

class SourceShellConfiguration {
  int fabricationShellThicknessVoxels = 3;
  float boundaryEpsilonVoxels = 0.35f;
  boolean lockSourceShell = true;
  float coverageRequired = 1.0f;
  SourceShellRolePolicy rolePolicy = SourceShellRolePolicy.SINGLE_QUALIFIED_COMPONENT;
  int explicitComponentIndex = 0;

  SourceShellConfiguration copy() {
    SourceShellConfiguration copy = new SourceShellConfiguration();
    copy.fabricationShellThicknessVoxels = fabricationShellThicknessVoxels;
    copy.boundaryEpsilonVoxels = boundaryEpsilonVoxels;
    copy.lockSourceShell = lockSourceShell;
    copy.coverageRequired = coverageRequired;
    copy.rolePolicy = rolePolicy;
    copy.explicitComponentIndex = explicitComponentIndex;
    return copy;
  }

  String canonical() {
    return "thickness_vox=" + fabricationShellThicknessVoxels
      + "\nepsilon_vox=" + boundaryEpsilonVoxels
      + "\nlock=" + lockSourceShell
      + "\ncoverage=" + coverageRequired
      + "\nrole=" + rolePolicy.id()
      + "\nexplicit_component=" + explicitComponentIndex;
  }

  JSONObject toJSON(VolumeSpec spec) {
    JSONObject json = new JSONObject();
    float spacing = spec == null ? Float.NaN : spec.minSpacing();
    float mmPerVoxel = spec == null || spec.nx <= 0 ? Float.NaN : foundryScaleMM / spec.nx;
    json.setInt("thickness_voxels", fabricationShellThicknessVoxels);
    json.setFloat("thickness_world", dcrteFinite(spacing) ? fabricationShellThicknessVoxels * spacing : Float.NaN);
    json.setFloat("thickness_mm", dcrteFinite(mmPerVoxel) ? fabricationShellThicknessVoxels * mmPerVoxel : Float.NaN);
    json.setFloat("boundary_epsilon_voxels", boundaryEpsilonVoxels);
    json.setBoolean("locked", lockSourceShell);
    json.setFloat("coverage_required", coverageRequired);
    json.setString("role_policy", rolePolicy.id());
    json.setInt("explicit_component", explicitComponentIndex);
    return json;
  }
}

class SourceShellBuildResult {
  VolumeSpec spec;
  boolean[] domainInside;
  boolean[] sourceShell;
  int domainCount;
  int shellCount;
  int boundaryReferenceCount;
  int boundaryCoveredCount;
  int shellComponentCount;
  float coverage;
  float thicknessWorld;
  float thicknessMM;
  float boundaryEpsilonWorld;
  String maskHash = "";
  MaterialCompositionValidationReport validation = new MaterialCompositionValidationReport();

  boolean valid() {
    return spec != null && spec.isValid() && sourceShell != null
      && sourceShell.length == spec.voxelCount() && shellCount > 0
      && validation.blockerCount() == 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("valid", valid());
    json.setInt("domain_voxels", domainCount);
    json.setInt("shell_voxels", shellCount);
    json.setInt("boundary_reference_voxels", boundaryReferenceCount);
    json.setInt("boundary_covered_voxels", boundaryCoveredCount);
    json.setInt("shell_components", shellComponentCount);
    json.setFloat("coverage", coverage);
    json.setFloat("thickness_world", thicknessWorld);
    json.setFloat("thickness_mm", thicknessMM);
    json.setFloat("boundary_epsilon_world", boundaryEpsilonWorld);
    json.setString("mask_sha256", maskHash);
    json.setJSONObject("validation", validation.toJSON());
    return json;
  }
}

class SourceShellBuilder {
  SourceShellBuildResult build(SignedDistanceVolume sdf, DomainPreflightReport preflight,
      SourceShellConfiguration configuration) {
    SourceShellBuildResult result = new SourceShellBuildResult();
    SourceShellConfiguration config = configuration == null
      ? new SourceShellConfiguration() : configuration.copy();
    if (sdf == null || !sdf.isValid() || sdf.spec == null || !sdf.spec.isValid()) {
      result.validation.error(DCRTEM6Codes.SOURCE_SHELL_UNQUALIFIED,
        "A valid signed-distance volume is required for source-shell composition.");
      return result;
    }
    result.spec = dcrteCopyVolumeSpec(sdf.spec);
    int count = result.spec.voxelCount();
    result.domainInside = new boolean[count];
    result.sourceShell = new boolean[count];

    if (!dcrteM6SourceRoleQualified(preflight, config, result.validation)) return result;

    int thicknessVoxels = constrain(config.fabricationShellThicknessVoxels, 1, 32);
    float spacing = result.spec.minSpacing();
    float thickness = thicknessVoxels * spacing;
    float epsilon = max(0.0f, config.boundaryEpsilonVoxels) * spacing;
    result.thicknessWorld = thickness;
    result.thicknessMM = thicknessVoxels * foundryScaleMM / max(1.0f, result.spec.nx);
    result.boundaryEpsilonWorld = epsilon;
    for (int i = 0; i < count; i++) {
      float distance = sdf.signedDistance[i];
      boolean inside = dcrteFinite(distance) && distance <= epsilon;
      boolean boundaryReference = dcrteFinite(distance) && abs(distance) <= epsilon;
      boolean shell = inside && distance >= -(thickness + epsilon);
      result.domainInside[i] = inside;
      result.sourceShell[i] = shell;
      if (inside) result.domainCount++;
      if (shell) result.shellCount++;
      if (boundaryReference) {
        result.boundaryReferenceCount++;
        if (shell) result.boundaryCoveredCount++;
      }
    }
    result.coverage = result.boundaryReferenceCount == 0 ? 0
      : result.boundaryCoveredCount / (float)result.boundaryReferenceCount;
    result.shellComponentCount = dcrteCountMaskComponents(result.sourceShell, result.spec, false);
    result.maskHash = dcrteBooleanMaskHash(result.sourceShell);
    if (result.shellCount == 0) {
      result.validation.error(DCRTEM6Codes.FABRICATION_SHELL_EMPTY,
        "The inward fabrication shell contains no voxels.");
    }
    if (thicknessVoxels < 2) {
      result.validation.warn(DCRTEM6Codes.FABRICATION_SHELL_TOO_THIN,
        "Fabrication shell thickness is below two voxels and may not survive materialization.");
    }
    if (result.shellComponentCount > 1) {
      result.validation.error(DCRTEM6Codes.FABRICATION_SHELL_FRAGMENTED,
        "The fabrication shell is not one six-connected envelope.");
    }
    if (result.coverage + 0.000001f < config.coverageRequired) {
      result.validation.error(DCRTEM6Codes.FABRICATION_SHELL_COVERAGE_LOW,
        "The source boundary is not fully represented by the inward fabrication shell.");
    }
    return result;
  }
}

boolean dcrteM6SourceRoleQualified(DomainPreflightReport preflight,
    SourceShellConfiguration config, MaterialCompositionValidationReport validation) {
  boolean signedBoundaryQualified = preflight != null
    && !preflight.reportStale
    && preflight.materializationEnabled
    && preflight.sdfReport != null
    && preflight.sdfReport.isValid()
    && !preflight.hasBlockerAtOrBefore("SIGNED_DISTANCE");
  if (!signedBoundaryQualified) {
    validation.error(DCRTEM6Codes.SOURCE_SHELL_UNQUALIFIED,
      "Source-shell composition requires a current preflight report with a qualified signed boundary.");
    return false;
  }
  if (preflight.nestedShellCount > 0) {
    validation.error(DCRTEM6Codes.NESTED_SHELL_UNSUPPORTED,
      "Nested shells remain blocked in the M6 production envelope role.");
    return false;
  }
  if (config.rolePolicy == SourceShellRolePolicy.SINGLE_QUALIFIED_COMPONENT) {
    if (preflight.componentCount != 1 || preflight.closedComponentCount != 1) {
      validation.error(DCRTEM6Codes.MULTIBODY_ENVELOPE_UNSUPPORTED,
        "The production source-shell role requires exactly one qualified closed component.");
      return false;
    }
  } else if (config.rolePolicy == SourceShellRolePolicy.DOMINANT_QUALIFIED_COMPONENT) {
    if (!preflight.singleDominantClosedComponent) {
      validation.error(DCRTEM6Codes.SOURCE_SHELL_ROLE_AMBIGUOUS,
        "No single dominant qualified component can be assigned as the source envelope.");
      return false;
    }
  } else if (config.explicitComponentIndex < 0
      || config.explicitComponentIndex >= preflight.componentCount) {
    validation.error(DCRTEM6Codes.SOURCE_SHELL_ROLE_AMBIGUOUS,
      "The requested explicit source component does not exist.");
    return false;
  }
  return true;
}

int dcrteCountMaskComponents(boolean[] mask, VolumeSpec spec, boolean twentySixConnected) {
  if (mask == null || spec == null || mask.length != spec.voxelCount()) return 0;
  boolean[] visited = new boolean[mask.length];
  int[] queue = new int[mask.length];
  int components = 0;
  for (int start = 0; start < mask.length; start++) {
    if (!mask[start] || visited[start]) continue;
    int head = 0;
    int tail = 0;
    queue[tail++] = start;
    visited[start] = true;
    while (head < tail) {
      int index = queue[head++];
      int[] neighbors = twentySixConnected
        ? dcrteSchedulerNeighbors(index, spec, SchedulerNeighborhoodMode.TWENTY_SIX_CONNECTED)
        : dcrteSixNeighbors(index, spec);
      for (int i = 0; i < neighbors.length; i++) {
        int neighbor = neighbors[i];
        if (!mask[neighbor] || visited[neighbor]) continue;
        visited[neighbor] = true;
        queue[tail++] = neighbor;
      }
    }
    components++;
  }
  return components;
}

String dcrteBooleanMaskHash(boolean[] mask) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    if (mask == null) return dcrteHex(digest.digest());
    dcrteDigestInt(digest, mask.length);
    for (int i = 0; i < mask.length; i++) digest.update((byte)(mask[i] ? 1 : 0));
    return dcrteHex(digest.digest());
  }
  catch (Exception error) {
    return "sha256-error";
  }
}
