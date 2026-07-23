/* DCRTE-ET Milestone 6 flat role-preserving fabrication composition volume. */

class FabricationCompositionVolume {
  final VolumeSpec spec;
  final boolean[] domainInside;
  final boolean[] sourceShell;
  final boolean[] scheduledScaffold;
  final boolean[] insetScaffold;
  final boolean[] anchorBridge;
  final boolean[] supportMaterial;
  final boolean[] composedMaterial;
  final boolean[] regularizedMaterial;
  final boolean[] lockedMaterial;
  int domainCount;
  int sourceShellCount;
  int scheduledScaffoldCount;
  int insetScaffoldCount;
  int anchorBridgeCount;
  int supportMaterialCount;
  int composedMaterialCount;
  int regularizedMaterialCount;
  int lockedMaterialCount;
  int outsideCount;
  int lockedRemovalAttemptCount;
  int lockedRemovalCount;
  int clearanceRemovedCount;
  float boundaryEpsilonWorld;
  float sourceShellThicknessWorld;
  float sourceShellCoverage;
  String compositionHash = "";
  String sourceSnapshotHash = "";
  String schedulerStateHash = "";
  String configurationHash = "";
  long createdAtMillisDiagnosticOnly;

  FabricationCompositionVolume(VolumeSpec spec) {
    this.spec = dcrteCopyVolumeSpec(spec);
    int count = this.spec == null ? 0 : max(0, this.spec.voxelCount());
    domainInside = new boolean[count];
    sourceShell = new boolean[count];
    scheduledScaffold = new boolean[count];
    insetScaffold = new boolean[count];
    anchorBridge = new boolean[count];
    supportMaterial = new boolean[count];
    composedMaterial = new boolean[count];
    regularizedMaterial = new boolean[count];
    lockedMaterial = new boolean[count];
    createdAtMillisDiagnosticOnly = System.currentTimeMillis();
  }

  int index(int x, int y, int z) {
    return x + spec.nx * (y + spec.ny * z);
  }

  boolean isValid() {
    return spec != null && spec.isValid()
      && domainInside.length == spec.voxelCount()
      && composedMaterial.length == domainInside.length;
  }

  void recount() {
    domainCount = sourceShellCount = scheduledScaffoldCount = insetScaffoldCount = 0;
    anchorBridgeCount = supportMaterialCount = composedMaterialCount = regularizedMaterialCount = 0;
    lockedMaterialCount = outsideCount = 0;
    for (int i = 0; i < domainInside.length; i++) {
      if (domainInside[i]) domainCount++;
      if (sourceShell[i]) sourceShellCount++;
      if (scheduledScaffold[i]) scheduledScaffoldCount++;
      if (insetScaffold[i]) insetScaffoldCount++;
      if (anchorBridge[i]) anchorBridgeCount++;
      if (supportMaterial[i]) supportMaterialCount++;
      if (composedMaterial[i]) composedMaterialCount++;
      if (regularizedMaterial[i]) regularizedMaterialCount++;
      if (lockedMaterial[i]) lockedMaterialCount++;
      if ((composedMaterial[i] || regularizedMaterial[i]) && !domainInside[i]) outsideCount++;
    }
  }

  String computeHash() {
    try {
      java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
      dcrteDigestString(digest, sourceSnapshotHash);
      dcrteDigestString(digest, schedulerStateHash);
      dcrteDigestString(digest, configurationHash);
      for (int i = 0; i < domainInside.length; i++) {
        int roles = (domainInside[i] ? 1 : 0)
          | (sourceShell[i] ? 2 : 0)
          | (scheduledScaffold[i] ? 4 : 0)
          | (insetScaffold[i] ? 8 : 0)
          | (anchorBridge[i] ? 16 : 0)
          | (supportMaterial[i] ? 32 : 0)
          | (composedMaterial[i] ? 64 : 0)
          | (regularizedMaterial[i] ? 128 : 0)
          | (lockedMaterial[i] ? 256 : 0);
        dcrteDigestInt(digest, roles);
      }
      compositionHash = dcrteHex(digest.digest());
    }
    catch (Exception error) {
      compositionHash = "sha256-error";
    }
    return compositionHash;
  }

  JSONObject toJSON() {
    recount();
    JSONObject json = new JSONObject();
    json.setString("version", "1.0-m6");
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setString("source_snapshot_hash", sourceSnapshotHash);
    json.setString("scheduler_state_hash", schedulerStateHash);
    json.setString("configuration_hash", configurationHash);
    json.setString("composition_hash", compositionHash);
    json.setString("created_at_millis_diagnostic_only", Long.toString(createdAtMillisDiagnosticOnly));
    json.setInt("domain_inside_count", domainCount);
    json.setInt("source_shell_count", sourceShellCount);
    json.setInt("scheduled_scaffold_count", scheduledScaffoldCount);
    json.setInt("inset_scaffold_count", insetScaffoldCount);
    json.setInt("anchor_bridge_count", anchorBridgeCount);
    json.setInt("support_material_count", supportMaterialCount);
    json.setInt("composed_material_count", composedMaterialCount);
    json.setInt("regularized_material_count", regularizedMaterialCount);
    json.setInt("locked_material_count", lockedMaterialCount);
    json.setInt("clearance_removed_count", clearanceRemovedCount);
    json.setInt("outside_count", outsideCount);
    json.setInt("locked_removal_attempt_count", lockedRemovalAttemptCount);
    json.setInt("locked_removal_count", lockedRemovalCount);
    json.setFloat("boundary_epsilon_world", boundaryEpsilonWorld);
    json.setFloat("source_shell_thickness_world", sourceShellThicknessWorld);
    json.setFloat("source_shell_coverage", sourceShellCoverage);
    json.setString("storage", "flat_role_masks");
    return json;
  }
}
