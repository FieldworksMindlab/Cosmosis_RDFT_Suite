/* DCRTE-ET Milestone 6 composition diagnostics and export gate. */

static class DCRTEM6Codes {
  static final String SOURCE_SHELL_UNQUALIFIED = "M6_SOURCE_SHELL_UNQUALIFIED";
  static final String SOURCE_SHELL_ROLE_AMBIGUOUS = "M6_SOURCE_SHELL_ROLE_AMBIGUOUS";
  static final String NESTED_SHELL_UNSUPPORTED = "M6_NESTED_SHELL_UNSUPPORTED";
  static final String MULTIBODY_ENVELOPE_UNSUPPORTED = "M6_MULTIBODY_ENVELOPE_UNSUPPORTED";
  static final String TORUS_FIXTURE_GENERATION_FAILED = "M6_TORUS_FIXTURE_GENERATION_FAILED";
  static final String TORUS_FIXTURE_ROUNDTRIP_FAILED = "M6_TORUS_FIXTURE_ROUNDTRIP_FAILED";
  static final String TORUS_INTRINSIC_AXIAL_BLOCKED = "M6_TORUS_INTRINSIC_AXIAL_BLOCKED";
  static final String FABRICATION_SHELL_EMPTY = "M6_FABRICATION_SHELL_EMPTY";
  static final String FABRICATION_SHELL_TOO_THIN = "M6_FABRICATION_SHELL_TOO_THIN";
  static final String FABRICATION_SHELL_FRAGMENTED = "M6_FABRICATION_SHELL_FRAGMENTED";
  static final String FABRICATION_SHELL_COVERAGE_LOW = "M6_FABRICATION_SHELL_COVERAGE_LOW";
  static final String LOCKED_SHELL_REMOVED = "M6_LOCKED_SHELL_REMOVED";
  static final String SCAFFOLD_EMPTY = "M6_SCAFFOLD_EMPTY";
  static final String SCAFFOLD_CLEARANCE_REMOVED_ALL = "M6_SCAFFOLD_CLEARANCE_REMOVED_ALL";
  static final String SCAFFOLD_COMPONENT_FLOATING = "M6_SCAFFOLD_COMPONENT_FLOATING";
  static final String SCAFFOLD_COMPONENT_NEAR_UNATTACHED = "M6_SCAFFOLD_COMPONENT_NEAR_UNATTACHED";
  static final String SCAFFOLD_COMPONENT_TOO_SMALL = "M6_SCAFFOLD_COMPONENT_TOO_SMALL";
  static final String ATTACHMENT_AREA_LOW = "M6_ATTACHMENT_AREA_LOW";
  static final String ATTACHMENT_NECK_THIN = "M6_ATTACHMENT_NECK_THIN";
  static final String BOUNDARY_SEED_FAILED = "M6_BOUNDARY_SEED_FAILED";
  static final String BOUNDARY_SEED_RELOCATED = "M6_BOUNDARY_SEED_RELOCATED";
  static final String BOUNDARY_PATCH_INVALID = "M6_BOUNDARY_PATCH_INVALID";
  static final String BRIDGE_NOT_FOUND = "M6_BRIDGE_NOT_FOUND";
  static final String BRIDGE_EXCEEDS_MAX_DISTANCE = "M6_BRIDGE_EXCEEDS_MAX_DISTANCE";
  static final String BRIDGE_OUTSIDE_DOMAIN = "M6_BRIDGE_OUTSIDE_DOMAIN";
  static final String FIELD_CONSTRAINED_BRIDGE_NONCANDIDATE = "M6_FIELD_CONSTRAINED_BRIDGE_NONCANDIDATE";
  static final String SUPPORT_BRIDGE_USED = "M6_SUPPORT_BRIDGE_USED";
  static final String BRIDGE_THICKNESS_LOW = "M6_BRIDGE_THICKNESS_LOW";
  static final String COMPOSITION_EMPTY = "M6_COMPOSITION_EMPTY";
  static final String COMPOSITION_OUTSIDE_DOMAIN = "M6_COMPOSITION_OUTSIDE_DOMAIN";
  static final String COMPOSITION_HASH_MISMATCH = "M6_COMPOSITION_HASH_MISMATCH";
  static final String COMPOSITION_STALE = "M6_COMPOSITION_STALE";
  static final String COMPOSITION_GRID_MISMATCH = "M6_COMPOSITION_GRID_MISMATCH";
  static final String ENVELOPE_DEVIATION_HIGH = "M6_ENVELOPE_DEVIATION_HIGH";
  static final String SOURCE_VERTEX_DISTANCE_HIGH = "M6_SOURCE_VERTEX_DISTANCE_HIGH";
  static final String MATERIALIZER_MANIFOLD_FAILURE = "M6_MATERIALIZER_MANIFOLD_FAILURE";
  static final String EXPORT_DISABLED = "M6_EXPORT_DISABLED";
}

class M6Diagnostic {
  String code;
  String message;
  boolean blocker;

  M6Diagnostic(String code, String message, boolean blocker) {
    this.code = code == null ? "" : code;
    this.message = message == null ? "" : message;
    this.blocker = blocker;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("code", code);
    json.setString("message", message);
    json.setString("severity", blocker ? "blocker" : "warning");
    return json;
  }
}

class MaterialCompositionValidationReport {
  ArrayList<M6Diagnostic> diagnostics = new ArrayList<M6Diagnostic>();
  BoundaryAttachmentReport attachmentReport;
  ExteriorEnvelopeFidelityReport fidelityReport;
  String compositionHash = "";
  int domainCount;
  int sourceShellCount;
  int scaffoldCount;
  int bridgeCount;
  int supportCount;
  int composedCount;
  int regularizedCount;
  int outsideCount;
  int lockedRemovalCount;
  float sourceShellCoverage;
  float attachedFraction;
  boolean materializerValid;
  boolean stale;

  void error(String code, String message) {
    if (!has(code, true)) diagnostics.add(new M6Diagnostic(code, message, true));
  }

  void warn(String code, String message) {
    if (!has(code, false)) diagnostics.add(new M6Diagnostic(code, message, false));
  }

  boolean has(String code, boolean blocker) {
    for (int i = 0; i < diagnostics.size(); i++) {
      M6Diagnostic diagnostic = diagnostics.get(i);
      if (diagnostic.code.equals(code) && diagnostic.blocker == blocker) return true;
    }
    return false;
  }

  boolean hasCode(String code) {
    for (int i = 0; i < diagnostics.size(); i++) if (diagnostics.get(i).code.equals(code)) return true;
    return false;
  }

  int blockerCount() {
    int count = 0;
    for (int i = 0; i < diagnostics.size(); i++) if (diagnostics.get(i).blocker) count++;
    return count;
  }

  int warningCount() {
    return diagnostics.size() - blockerCount();
  }

  String firstBlocker() {
    for (int i = 0; i < diagnostics.size(); i++) if (diagnostics.get(i).blocker) return diagnostics.get(i).code;
    return "";
  }

  boolean valid() {
    return blockerCount() == 0 && !stale;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("version", "1.0-m6");
    json.setString("status", valid() ? (warningCount() > 0 ? "pass_with_warnings" : "pass") : "fail");
    json.setString("first_blocker", firstBlocker());
    json.setString("composition_hash", compositionHash);
    json.setInt("domain_voxels", domainCount);
    json.setInt("source_shell_voxels", sourceShellCount);
    json.setInt("scheduled_scaffold_voxels", scaffoldCount);
    json.setInt("anchor_bridge_voxels", bridgeCount);
    json.setInt("support_voxels", supportCount);
    json.setInt("composed_voxels", composedCount);
    json.setInt("regularized_voxels", regularizedCount);
    json.setInt("outside_voxels", outsideCount);
    json.setInt("locked_shell_removals", lockedRemovalCount);
    json.setFloat("source_shell_coverage", sourceShellCoverage);
    json.setFloat("attached_scaffold_fraction", attachedFraction);
    json.setBoolean("materializer_valid", materializerValid);
    json.setBoolean("stale", stale);
    JSONArray entries = new JSONArray();
    for (int i = 0; i < diagnostics.size(); i++) entries.setJSONObject(i, diagnostics.get(i).toJSON());
    json.setJSONArray("diagnostics", entries);
    if (attachmentReport != null) json.setJSONObject("attachment", attachmentReport.toJSON());
    if (fidelityReport != null) json.setJSONObject("envelope_fidelity", fidelityReport.toJSON());
    return json;
  }
}

boolean dcrteM6CompositionExportAllowed() {
  if (!dcrteCompositionAuthoritative) return true;
  return dcrteCompositionVolume != null
    && dcrteCompositionValidation != null
    && dcrteCompositionValidation.valid()
    && dcrteCompositionMaterialized
    && !dcrteCompositionStale;
}
