/* DCRTE-ET Milestone 6 source-envelope composition configuration and lifecycle. */

enum MaterialCompositionMode {
  SCAFFOLD_ONLY,
  SHELL_ONLY,
  SHELL_PLUS_SCAFFOLD,
  BOUNDARY_ANCHORED_SCAFFOLD,
  INSET_SCAFFOLD;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum ScaffoldClearanceMode {
  NONE,
  INSET_FROM_SOURCE_SHELL;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum BoundaryAttachmentPolicy {
  VALIDATE_ONLY,
  REQUIRE_EXISTING_CONTACT,
  SEED_FROM_BOUNDARY,
  BRIDGE_FIELD_CONSTRAINED,
  BRIDGE_DOMAIN_CONSTRAINED;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum BoundarySeedMode {
  NONE,
  SOURCE_SHELL_NEAREST_CENTER,
  SOURCE_SHELL_INTRINSIC_START,
  SOURCE_SHELL_INTRINSIC_END,
  SELECTED_PATCH,
  DISTRIBUTED;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum AttachmentNeighborhoodMode {
  SIX_CONNECTED,
  TWENTY_SIX_CONNECTED;
  String id() { return name().toLowerCase(); }
  String label() { return name().replace('_', ' '); }
}

enum M6CompositionStage {
  NOT_BUILT,
  SHELL_READY,
  ATTACHMENT_ANALYZED,
  COMPOSED,
  MATERIALIZED,
  STALE,
  BLOCKED;
  String label() { return name().replace('_', ' '); }
}

class MaterialCompositionConfiguration {
  MaterialCompositionMode mode = MaterialCompositionMode.SCAFFOLD_ONLY;
  SourceShellConfiguration sourceShell = new SourceShellConfiguration();
  ScaffoldClearanceMode clearanceMode = ScaffoldClearanceMode.NONE;
  float clearanceVoxels = 2.0f;
  BoundaryAttachmentPolicy attachmentPolicy = BoundaryAttachmentPolicy.VALIDATE_ONLY;
  BoundarySeedMode boundarySeedMode = BoundarySeedMode.NONE;
  AttachmentNeighborhoodMode attachmentNeighborhood = AttachmentNeighborhoodMode.SIX_CONNECTED;
  int distributedSeedCount = 4;
  int selectedPatchIndex = 0;
  int minimumComponentVoxels = 4;
  float nearBoundaryDistanceVoxels = 2.0f;
  float minimumAttachmentAreaVoxels = 1.0f;
  float minimumAttachmentThicknessVoxels = 1.0f;
  int bridgeMaxDistanceVoxels = 6;
  float bridgeRadiusVoxels = 1.5f;
  float fieldPenaltyWeight = 0.75f;
  float confidencePenaltyWeight = 0.25f;

  MaterialCompositionConfiguration copy() {
    MaterialCompositionConfiguration copy = new MaterialCompositionConfiguration();
    copy.mode = mode;
    copy.sourceShell = sourceShell == null ? new SourceShellConfiguration() : sourceShell.copy();
    copy.clearanceMode = clearanceMode;
    copy.clearanceVoxels = clearanceVoxels;
    copy.attachmentPolicy = attachmentPolicy;
    copy.boundarySeedMode = boundarySeedMode;
    copy.attachmentNeighborhood = attachmentNeighborhood;
    copy.distributedSeedCount = distributedSeedCount;
    copy.selectedPatchIndex = selectedPatchIndex;
    copy.minimumComponentVoxels = minimumComponentVoxels;
    copy.nearBoundaryDistanceVoxels = nearBoundaryDistanceVoxels;
    copy.minimumAttachmentAreaVoxels = minimumAttachmentAreaVoxels;
    copy.minimumAttachmentThicknessVoxels = minimumAttachmentThicknessVoxels;
    copy.bridgeMaxDistanceVoxels = bridgeMaxDistanceVoxels;
    copy.bridgeRadiusVoxels = bridgeRadiusVoxels;
    copy.fieldPenaltyWeight = fieldPenaltyWeight;
    copy.confidencePenaltyWeight = confidencePenaltyWeight;
    return copy;
  }

  String canonical() {
    return "mode=" + mode.id()
      + "\nsource_shell={" + (sourceShell == null ? "" : sourceShell.canonical()) + "}"
      + "\nclearance_mode=" + clearanceMode.id()
      + "\nclearance_vox=" + clearanceVoxels
      + "\nattachment_policy=" + attachmentPolicy.id()
      + "\nboundary_seed=" + boundarySeedMode.id()
      + "\nattachment_neighborhood=" + attachmentNeighborhood.id()
      + "\ndistributed_seeds=" + distributedSeedCount
      + "\nselected_patch=" + selectedPatchIndex
      + "\nminimum_component=" + minimumComponentVoxels
      + "\nnear_distance_vox=" + nearBoundaryDistanceVoxels
      + "\nminimum_area_vox=" + minimumAttachmentAreaVoxels
      + "\nminimum_thickness_vox=" + minimumAttachmentThicknessVoxels
      + "\nbridge_max_vox=" + bridgeMaxDistanceVoxels
      + "\nbridge_radius_vox=" + bridgeRadiusVoxels
      + "\nfield_penalty=" + fieldPenaltyWeight
      + "\nconfidence_penalty=" + confidencePenaltyWeight;
  }

  String configurationHash() {
    return dcrteSha256Hex(canonical());
  }

  JSONObject toJSON(VolumeSpec spec) {
    JSONObject json = new JSONObject();
    json.setString("version", "1.0-m6");
    json.setString("mode", mode.id());
    json.setJSONObject("source_shell", sourceShell == null ? new JSONObject() : sourceShell.toJSON(spec));
    json.setString("clearance_mode", clearanceMode.id());
    json.setFloat("clearance_voxels", clearanceVoxels);
    json.setFloat("clearance_mm", spec == null || spec.nx <= 0 ? Float.NaN
      : clearanceVoxels * foundryScaleMM / spec.nx);
    json.setString("attachment_policy", attachmentPolicy.id());
    json.setString("boundary_seed_mode", boundarySeedMode.id());
    json.setString("attachment_neighborhood", attachmentNeighborhood.id());
    json.setInt("distributed_seed_count", distributedSeedCount);
    json.setInt("selected_patch_index", selectedPatchIndex);
    json.setInt("minimum_component_voxels", minimumComponentVoxels);
    json.setFloat("near_boundary_distance_voxels", nearBoundaryDistanceVoxels);
    json.setFloat("minimum_attachment_area_voxels", minimumAttachmentAreaVoxels);
    json.setFloat("minimum_attachment_thickness_voxels", minimumAttachmentThicknessVoxels);
    json.setInt("bridge_max_distance_voxels", bridgeMaxDistanceVoxels);
    json.setFloat("bridge_radius_voxels", bridgeRadiusVoxels);
    json.setFloat("field_penalty_weight", fieldPenaltyWeight);
    json.setFloat("confidence_penalty_weight", confidencePenaltyWeight);
    json.setString("configuration_hash", configurationHash());
    return json;
  }
}

MaterialCompositionConfiguration dcrteCompositionConfiguration = new MaterialCompositionConfiguration();
SourceShellBuildResult dcrteSourceShellBuild = null;
FabricationCompositionVolume dcrteCompositionVolume = null;
BoundaryAttachmentReport dcrteBoundaryAttachmentReport = null;
ExteriorEnvelopeFidelityReport dcrteEnvelopeFidelityReport = null;
MaterialCompositionValidationReport dcrteCompositionValidation = null;
M6CompositionStage dcrteCompositionStage = M6CompositionStage.NOT_BUILT;
boolean dcrteCompositionAuthoritative = false;
boolean dcrteCompositionMaterialized = false;
boolean dcrteCompositionStale = false;
String dcrteCompositionStatus = "choose a composition mode and build source shell";
String dcrteCompositionStaleReason = "";
int dcrteCompositionInspectorPage = 0;

void invalidateDcrteComposition(String reason) {
  dcrteSourceShellBuild = null;
  dcrteCompositionVolume = null;
  dcrteBoundaryAttachmentReport = null;
  dcrteEnvelopeFidelityReport = null;
  dcrteCompositionValidation = null;
  dcrteCompositionMaterialized = false;
  dcrteCompositionStale = true;
  dcrteCompositionStaleReason = reason == null ? "upstream state changed" : reason;
  dcrteCompositionStage = M6CompositionStage.STALE;
  dcrteCompositionStatus = "composition stale - " + dcrteCompositionStaleReason;
}

void resetDcrteComposition() {
  dcrteCompositionConfiguration = new MaterialCompositionConfiguration();
  dcrteCompositionAuthoritative = false;
  dcrteCompositionMaterialized = false;
  dcrteCompositionStale = false;
  dcrteCompositionStaleReason = "";
  dcrteCompositionStage = M6CompositionStage.NOT_BUILT;
  dcrteSourceShellBuild = null;
  dcrteCompositionVolume = null;
  dcrteBoundaryAttachmentReport = null;
  dcrteEnvelopeFidelityReport = null;
  dcrteCompositionValidation = null;
  dcrteCompositionStatus = "choose a composition mode and build source shell";
}

void markDcrteCompositionConfigurationChanged(String reason) {
  dcrteCompositionAuthoritative = dcrteCompositionConfiguration.mode != MaterialCompositionMode.SCAFFOLD_ONLY;
  invalidateDcrteComposition(reason);
}

boolean dcrteCompositionRequiresSourceShell() {
  return dcrteCompositionConfiguration.mode != MaterialCompositionMode.SCAFFOLD_ONLY;
}

JSONObject dcrteM6CompositionJSON() {
  JSONObject json = new JSONObject();
  json.setString("milestone", "6");
  json.setString("stage", dcrteCompositionStage.label().toLowerCase().replace(' ', '_'));
  json.setBoolean("authoritative", dcrteCompositionAuthoritative);
  json.setBoolean("materialized", dcrteCompositionMaterialized);
  json.setBoolean("stale", dcrteCompositionStale);
  json.setString("stale_reason", dcrteCompositionStaleReason);
  json.setString("status", dcrteCompositionStatus);
  VolumeSpec spec = dcrteSchedulerController == null || dcrteSchedulerController.snapshot == null
    ? null : dcrteSchedulerController.snapshot.spec;
  json.setJSONObject("configuration", dcrteCompositionConfiguration.toJSON(spec));
  if (dcrteSourceShellBuild != null) json.setJSONObject("source_shell", dcrteSourceShellBuild.toJSON());
  if (dcrteCompositionVolume != null) json.setJSONObject("volume", dcrteCompositionVolume.toJSON());
  if (dcrteCompositionValidation != null) json.setJSONObject("validation", dcrteCompositionValidation.toJSON());
  return json;
}

class MaterialCompositionLayer {
  FabricationCompositionVolume compose(DCRTEVolume sourceFieldVolume,
      CandidateVolumeSnapshot snapshot, PropagationState schedulerState,
      SignedDistanceVolume sdf, MaterialCompositionConfiguration requestedConfiguration) {
    MaterialCompositionConfiguration config = requestedConfiguration == null
      ? new MaterialCompositionConfiguration() : requestedConfiguration.copy();
    MaterialCompositionValidationReport validation = new MaterialCompositionValidationReport();
    dcrteCompositionValidation = validation;
    if (sourceFieldVolume == null || !sourceFieldVolume.isValid()
        || snapshot == null || !snapshot.valid
        || schedulerState == null) {
      validation.error(DCRTEM6Codes.COMPOSITION_STALE,
        "Composition requires a current candidate snapshot and scheduler propagation state.");
      return null;
    }
    if (!dcrteM6CompositionInputsShareGrid(sourceFieldVolume, snapshot,
        schedulerState, sdf)) {
      validation.stale = true;
      validation.error(DCRTEM6Codes.COMPOSITION_GRID_MISMATCH,
        "Composition inputs use different voxel grids. Rebuild the candidate snapshot, scheduler state, and SDF at the current resolution before composing.");
      return null;
    }
    String schedulerMaskBefore = dcrteBooleanMaskHash(schedulerState.active);
    FabricationCompositionVolume volume = new FabricationCompositionVolume(snapshot.spec);
    volume.sourceSnapshotHash = snapshot.contentHash;
    volume.schedulerStateHash = schedulerState.stateHash;
    volume.configurationHash = config.configurationHash();

    if (config.mode == MaterialCompositionMode.SCAFFOLD_ONLY) {
      for (int i = 0; i < volume.domainInside.length; i++) {
        volume.domainInside[i] = sdf != null && sdf.isValid()
          ? dcrteFinite(sdf.signedDistance[i]) && sdf.signedDistance[i] <= 0
          : snapshot.admitted[i];
        volume.scheduledScaffold[i] = schedulerState.active[i];
        volume.insetScaffold[i] = schedulerState.active[i];
        volume.composedMaterial[i] = schedulerState.active[i];
        volume.regularizedMaterial[i] = schedulerState.active[i];
      }
      volume.recount();
      volume.computeHash();
      validation.compositionHash = volume.compositionHash;
      validation.domainCount = volume.domainCount;
      validation.scaffoldCount = volume.scheduledScaffoldCount;
      validation.composedCount = volume.composedMaterialCount;
      validation.regularizedCount = volume.regularizedMaterialCount;
      if (volume.composedMaterialCount == 0) validation.error(DCRTEM6Codes.COMPOSITION_EMPTY,
        "The selected scheduler state contains no active scaffold.");
      dcrteVerifySchedulerMaskUnchanged(schedulerMaskBefore, schedulerState, validation);
      return volume;
    }

    SourceShellBuildResult shell = new SourceShellBuilder().build(sdf,
      dcrteImportedPreflightReport, config.sourceShell);
    dcrteSourceShellBuild = shell;
    dcrteMergeM6Diagnostics(validation, shell == null ? null : shell.validation);
    if (shell == null || !shell.valid()) {
      dcrteVerifySchedulerMaskUnchanged(schedulerMaskBefore, schedulerState, validation);
      return null;
    }
    System.arraycopy(shell.domainInside, 0, volume.domainInside, 0, volume.domainInside.length);
    System.arraycopy(shell.sourceShell, 0, volume.sourceShell, 0, volume.sourceShell.length);
    volume.boundaryEpsilonWorld = shell.boundaryEpsilonWorld;
    volume.sourceShellThicknessWorld = shell.thicknessWorld;
    volume.sourceShellCoverage = shell.coverage;
    for (int i = 0; i < volume.scheduledScaffold.length; i++) {
      volume.scheduledScaffold[i] = schedulerState.active[i];
      boolean inset = schedulerState.active[i];
      if (config.clearanceMode == ScaffoldClearanceMode.INSET_FROM_SOURCE_SHELL
          || config.mode == MaterialCompositionMode.INSET_SCAFFOLD) {
        float clearanceWorld = max(0, config.clearanceVoxels) * volume.spec.minSpacing();
        inset = inset && dcrteFinite(sdf.signedDistance[i])
          && sdf.signedDistance[i] <= -clearanceWorld;
      }
      volume.insetScaffold[i] = inset;
      if (schedulerState.active[i] && !inset) volume.clearanceRemovedCount++;
    }
    boolean[] workingScaffold = config.clearanceMode == ScaffoldClearanceMode.INSET_FROM_SOURCE_SHELL
      || config.mode == MaterialCompositionMode.INSET_SCAFFOLD
      ? volume.insetScaffold : volume.scheduledScaffold;

    boolean scaffoldRequired = config.mode != MaterialCompositionMode.SHELL_ONLY;
    int scheduledCount = dcrteCountTrue(volume.scheduledScaffold);
    int workingCount = dcrteCountTrue(workingScaffold);
    if (scaffoldRequired && workingCount == 0) {
      validation.error(scheduledCount > 0
        ? DCRTEM6Codes.SCAFFOLD_CLEARANCE_REMOVED_ALL : DCRTEM6Codes.SCAFFOLD_EMPTY,
        scheduledCount > 0
          ? "The requested source-shell clearance removed the complete scheduled scaffold."
          : "The selected scheduler state contains no active scaffold.");
    }

    AnchorBridgeResult bridgeResult = null;
    if (scaffoldRequired && workingCount > 0) {
      dcrteBoundaryAttachmentReport = dcrteBoundaryAttachmentAnalyzer.analyze(
        workingScaffold, volume.sourceShell, sdf, volume.spec, config);
      validation.attachmentReport = dcrteBoundaryAttachmentReport;
      if (config.attachmentPolicy == BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED
          || config.attachmentPolicy == BoundaryAttachmentPolicy.BRIDGE_DOMAIN_CONSTRAINED) {
        bridgeResult = dcrteAnchorBridgeBuilder.build(volume, snapshot,
          dcrteBoundaryAttachmentReport, config);
        for (int i = 0; i < bridgeResult.diagnostics.size(); i++) {
          M6Diagnostic diagnostic = bridgeResult.diagnostics.get(i);
          if (diagnostic.blocker) validation.error(diagnostic.code, diagnostic.message);
          else validation.warn(diagnostic.code, diagnostic.message);
        }
      }
      boolean[] scaffoldWithBridges = dcrteM6UnionScaffold(
        workingScaffold, volume.anchorBridge, volume.supportMaterial);
      dcrteBoundaryAttachmentReport = dcrteBoundaryAttachmentAnalyzer.analyze(
        scaffoldWithBridges, volume.sourceShell, sdf, volume.spec, config);
      validation.attachmentReport = dcrteBoundaryAttachmentReport;
      validateAttachmentPolicy(dcrteBoundaryAttachmentReport, config, validation);
    }

    for (int i = 0; i < volume.composedMaterial.length; i++) {
      boolean scaffold = workingScaffold[i] || volume.anchorBridge[i] || volume.supportMaterial[i];
      boolean composed = false;
      if (config.mode == MaterialCompositionMode.SHELL_ONLY) composed = volume.sourceShell[i];
      else if (config.mode == MaterialCompositionMode.SHELL_PLUS_SCAFFOLD
          || config.mode == MaterialCompositionMode.BOUNDARY_ANCHORED_SCAFFOLD
          || config.mode == MaterialCompositionMode.INSET_SCAFFOLD) {
        composed = volume.sourceShell[i] || scaffold;
      }
      composed = composed && volume.domainInside[i];
      volume.composedMaterial[i] = composed;
      volume.regularizedMaterial[i] = composed;
      volume.lockedMaterial[i] = config.sourceShell.lockSourceShell && volume.sourceShell[i];
    }
    volume.recount();
    volume.computeHash();
    validation.compositionHash = volume.compositionHash;
    validation.domainCount = volume.domainCount;
    validation.sourceShellCount = volume.sourceShellCount;
    validation.scaffoldCount = workingCount;
    validation.bridgeCount = volume.anchorBridgeCount;
    validation.supportCount = volume.supportMaterialCount;
    validation.composedCount = volume.composedMaterialCount;
    validation.regularizedCount = volume.regularizedMaterialCount;
    validation.outsideCount = volume.outsideCount;
    validation.lockedRemovalCount = volume.lockedRemovalCount;
    validation.sourceShellCoverage = volume.sourceShellCoverage;
    validation.attachedFraction = dcrteBoundaryAttachmentReport == null
      ? (scaffoldRequired ? 0 : 1) : dcrteBoundaryAttachmentReport.attachedFraction;
    if (volume.composedMaterialCount == 0) validation.error(DCRTEM6Codes.COMPOSITION_EMPTY,
      "No composed fabrication material remains.");
    if (volume.outsideCount > 0) validation.error(DCRTEM6Codes.COMPOSITION_OUTSIDE_DOMAIN,
      "Composition contains material outside the authoritative source domain.");
    if (volume.lockedRemovalCount > 0) validation.error(DCRTEM6Codes.LOCKED_SHELL_REMOVED,
      "A locked source-shell voxel was removed during composition.");

    dcrteEnvelopeFidelityReport = dcrteEnvelopeFidelityAnalyzer.analyze(volume, sdf,
      dcrteImportedWorldMesh);
    validation.fidelityReport = dcrteEnvelopeFidelityReport;
    if (dcrteEnvelopeFidelityReport.sourceBoundaryCoverage + 0.000001f
        < config.sourceShell.coverageRequired) {
      validation.error(DCRTEM6Codes.FABRICATION_SHELL_COVERAGE_LOW,
        "Composed material does not cover the required source-envelope boundary.");
    }
    if (dcrteEnvelopeFidelityReport.materialOutsideCount > 0) {
      validation.error(DCRTEM6Codes.COMPOSITION_OUTSIDE_DOMAIN,
        "Envelope fidelity analysis detected exterior material.");
    }
    if (dcrteFinite(dcrteEnvelopeFidelityReport.sourceVertexDistanceP95World)
        && dcrteEnvelopeFidelityReport.sourceVertexDistanceP95World > volume.spec.minSpacing() * 2.5f) {
      validation.error(DCRTEM6Codes.SOURCE_VERTEX_DISTANCE_HIGH,
        "The 95th-percentile source-vertex distance exceeds the voxel envelope tolerance.");
    }
    dcrteVerifySchedulerMaskUnchanged(schedulerMaskBefore, schedulerState, validation);
    return volume;
  }

  void validateAttachmentPolicy(BoundaryAttachmentReport report,
      MaterialCompositionConfiguration config, MaterialCompositionValidationReport validation) {
    if (report == null || report.scaffoldVoxelCount == 0) return;
    boolean strict = config.attachmentPolicy == BoundaryAttachmentPolicy.REQUIRE_EXISTING_CONTACT
      || config.attachmentPolicy == BoundaryAttachmentPolicy.SEED_FROM_BOUNDARY
      || config.attachmentPolicy == BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED
      || config.attachmentPolicy == BoundaryAttachmentPolicy.BRIDGE_DOMAIN_CONSTRAINED;
    if (report.floatingInteriorCount > 0) {
      if (strict) validation.error(DCRTEM6Codes.SCAFFOLD_COMPONENT_FLOATING,
        report.floatingInteriorCount + " scaffold component(s) remain floating inside the source envelope.");
      else validation.warn(DCRTEM6Codes.SCAFFOLD_COMPONENT_FLOATING,
        report.floatingInteriorCount + " floating scaffold component(s) were retained under validate-only policy.");
    }
    if (report.nearBoundaryUnattachedCount > 0) {
      if (strict) validation.error(DCRTEM6Codes.SCAFFOLD_COMPONENT_NEAR_UNATTACHED,
        report.nearBoundaryUnattachedCount + " near-boundary scaffold component(s) lack direct contact.");
      else validation.warn(DCRTEM6Codes.SCAFFOLD_COMPONENT_NEAR_UNATTACHED,
        report.nearBoundaryUnattachedCount + " near-boundary component(s) are not attached.");
    }
    if (report.tooSmallCount > 0) {
      if (strict) validation.error(DCRTEM6Codes.SCAFFOLD_COMPONENT_TOO_SMALL,
        report.tooSmallCount + " scaffold component(s) fall below the configured voxel minimum.");
      else validation.warn(DCRTEM6Codes.SCAFFOLD_COMPONENT_TOO_SMALL,
        report.tooSmallCount + " small scaffold component(s) were detected.");
    }
    for (int i = 0; i < report.components.size(); i++) {
      BoundaryAttachmentComponentReport component = report.components.get(i);
      if (component.classification != BoundaryAttachmentClass.BOUNDARY_ATTACHED) continue;
      if (component.contactAreaWorld
          < config.minimumAttachmentAreaVoxels * dcrteCompositionVoxelFaceArea()) {
        validation.warn(DCRTEM6Codes.ATTACHMENT_AREA_LOW,
          "Attachment component " + component.componentId + " has a small geometric contact patch.");
      }
      if (component.thicknessP05Voxels < config.minimumAttachmentThicknessVoxels) {
        validation.warn(DCRTEM6Codes.ATTACHMENT_NECK_THIN,
          "Attachment component " + component.componentId + " has a thin voxel-neighborhood proxy.");
      }
    }
  }
}

boolean dcrteM6CompositionInputsShareGrid(DCRTEVolume source,
    CandidateVolumeSnapshot snapshot, PropagationState state,
    SignedDistanceVolume sdf) {
  if (source == null || snapshot == null || state == null
      || source.spec == null || snapshot.spec == null) return false;
  int count = snapshot.spec.voxelCount();
  if (count <= 0 || !dcrteM6CompositionSpecsEqual(
      source.spec, snapshot.spec)) return false;
  if (source.scalar.length != count
      || source.admitted.length != count
      || source.candidateSolid.length != count
      || state.active.length != count
      || state.arrivalBatch.length != count
      || state.arrivalRank.length != count) return false;
  if (snapshot.admitted.length != count
      || snapshot.candidateSolid.length != count
      || snapshot.fieldScalar.length != count
      || snapshot.signedDistance.length != count) return false;
  return sdf == null || (sdf.isValid()
    && dcrteM6CompositionSpecsEqual(sdf.spec, snapshot.spec)
    && sdf.signedDistance.length == count
    && sdf.inside.length == count
    && sdf.boundary.length == count);
}

boolean dcrteM6CompositionSpecsEqual(VolumeSpec a, VolumeSpec b) {
  if (a == null || b == null || a.bounds == null || b.bounds == null) return false;
  return a.nx == b.nx && a.ny == b.ny && a.nz == b.nz
    && Float.floatToIntBits(a.bounds.minX) == Float.floatToIntBits(b.bounds.minX)
    && Float.floatToIntBits(a.bounds.minY) == Float.floatToIntBits(b.bounds.minY)
    && Float.floatToIntBits(a.bounds.minZ) == Float.floatToIntBits(b.bounds.minZ)
    && Float.floatToIntBits(a.bounds.maxX) == Float.floatToIntBits(b.bounds.maxX)
    && Float.floatToIntBits(a.bounds.maxY) == Float.floatToIntBits(b.bounds.maxY)
    && Float.floatToIntBits(a.bounds.maxZ) == Float.floatToIntBits(b.bounds.maxZ);
}

MaterialCompositionLayer dcrteMaterialCompositionLayer = new MaterialCompositionLayer();

boolean buildDcrteSourceShell() {
  if (dcrteCompositionConfiguration.mode == MaterialCompositionMode.SCAFFOLD_ONLY) {
    dcrteCompositionStatus = "scaffold-only uses the exact M5 scheduler baseline";
    dcrteCompositionStage = M6CompositionStage.SHELL_READY;
    dcrteCompositionStale = false;
    return true;
  }
  dcrteSourceShellBuild = new SourceShellBuilder().build(dcrteImportedSdf,
    dcrteImportedPreflightReport, dcrteCompositionConfiguration.sourceShell);
  if (dcrteSourceShellBuild == null || !dcrteSourceShellBuild.valid()) {
    dcrteCompositionStage = M6CompositionStage.BLOCKED;
    dcrteCompositionStatus = "source shell blocked - "
      + (dcrteSourceShellBuild == null ? DCRTEM6Codes.SOURCE_SHELL_UNQUALIFIED
        : dcrteSourceShellBuild.validation.firstBlocker());
    return false;
  }
  dcrteCompositionStale = false;
  dcrteCompositionStaleReason = "";
  dcrteCompositionStage = M6CompositionStage.SHELL_READY;
  dcrteCompositionStatus = "source shell ready - " + dcrteSourceShellBuild.shellCount + " voxels";
  return true;
}

boolean composeDcrteCurrentMaterial() {
  DCRTEVolume fieldVolume = dcrteSchedulerActiveVolume();
  SchedulerController controller = dcrteSchedulerController;
  if (controller == null || controller.snapshot == null || controller.state == null
      || fieldVolume == null) {
    dcrteCompositionStage = M6CompositionStage.BLOCKED;
    dcrteCompositionStatus = "composition blocked - scheduler state unavailable";
    return false;
  }
  dcrteCompositionAuthoritative = dcrteCompositionConfiguration.mode
    != MaterialCompositionMode.SCAFFOLD_ONLY;
  dcrteCompositionVolume = dcrteMaterialCompositionLayer.compose(fieldVolume,
    controller.snapshot, controller.state, dcrteImportedSdf, dcrteCompositionConfiguration);
  dcrteCompositionStale = false;
  dcrteCompositionStaleReason = "";
  dcrteCompositionMaterialized = false;
  if (dcrteCompositionVolume == null || dcrteCompositionValidation == null
      || !dcrteCompositionValidation.valid()) {
    dcrteCompositionStage = M6CompositionStage.BLOCKED;
    dcrteCompositionStatus = "composition blocked - "
      + (dcrteCompositionValidation == null ? DCRTEM6Codes.COMPOSITION_STALE
        : dcrteCompositionValidation.firstBlocker());
    return false;
  }
  dcrteCompositionStage = M6CompositionStage.COMPOSED;
  dcrteCompositionStatus = "composition ready - "
    + dcrteCompositionVolume.composedMaterialCount + " voxels";
  return true;
}

boolean analyzeDcrteCurrentAttachment() {
  if (dcrteCompositionVolume == null || dcrteCompositionVolume.spec == null) {
    if (!composeDcrteCurrentMaterial()) return false;
  }
  boolean[] scaffold = dcrteCompositionConfiguration.clearanceMode
      == ScaffoldClearanceMode.INSET_FROM_SOURCE_SHELL
    || dcrteCompositionConfiguration.mode == MaterialCompositionMode.INSET_SCAFFOLD
    ? dcrteCompositionVolume.insetScaffold : dcrteCompositionVolume.scheduledScaffold;
  dcrteBoundaryAttachmentReport = dcrteBoundaryAttachmentAnalyzer.analyze(scaffold,
    dcrteCompositionVolume.sourceShell, dcrteImportedSdf,
    dcrteCompositionVolume.spec, dcrteCompositionConfiguration);
  dcrteCompositionStage = M6CompositionStage.ATTACHMENT_ANALYZED;
  dcrteCompositionStatus = "attachment analyzed - "
    + dcrteBoundaryAttachmentReport.boundaryAttachedCount + "/"
    + dcrteBoundaryAttachmentReport.componentCount + " components attached";
  return true;
}

void exportDcrteCompositionReport() {
  ensureDir(sketchPath("logs"));
  String path = "logs/dcrte_m6_composition_" + dcrteSchedulerFileStamp() + ".json";
  saveJSONObject(dcrteM6CompositionJSON(), path);
  dcrteCompositionStatus = "composition report exported - " + path;
  foundryStatus = dcrteCompositionStatus;
}

void dcrteMergeM6Diagnostics(MaterialCompositionValidationReport target,
    MaterialCompositionValidationReport source) {
  if (target == null || source == null) return;
  for (int i = 0; i < source.diagnostics.size(); i++) {
    M6Diagnostic diagnostic = source.diagnostics.get(i);
    if (diagnostic.blocker) target.error(diagnostic.code, diagnostic.message);
    else target.warn(diagnostic.code, diagnostic.message);
  }
}

void dcrteVerifySchedulerMaskUnchanged(String before, PropagationState state,
    MaterialCompositionValidationReport validation) {
  String after = state == null ? "" : dcrteBooleanMaskHash(state.active);
  if (!before.equals(after)) validation.error(DCRTEM6Codes.COMPOSITION_HASH_MISMATCH,
    "Composition mutated the scheduler activation mask.");
}

int dcrteCountTrue(boolean[] mask) {
  int count = 0;
  if (mask != null) for (int i = 0; i < mask.length; i++) if (mask[i]) count++;
  return count;
}

boolean[] dcrteM6UnionScaffold(boolean[] scaffold, boolean[] bridge, boolean[] support) {
  int count = scaffold == null ? 0 : scaffold.length;
  boolean[] result = new boolean[count];
  for (int i = 0; i < count; i++) result[i] = scaffold[i]
    || bridge != null && bridge[i] || support != null && support[i];
  return result;
}

float dcrteCompositionVoxelFaceArea() {
  VolumeSpec spec = dcrteCompositionVolume == null ? null : dcrteCompositionVolume.spec;
  float spacing = spec == null ? 0 : spec.minSpacing();
  return spacing * spacing;
}
