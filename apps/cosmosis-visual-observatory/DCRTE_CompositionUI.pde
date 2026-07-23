/* DCRTE-ET Milestone 6 composition inspector and role overlays. */

int dcrteCompositionOverlayMode = 0;

void drawDcrteCompositionInspector(int x, int y, int w, int h) {
  int gap = 5;
  int thirdW = (w - gap * 2) / 3;
  String[] pages = {"ENVELOPE", "ATTACH", "REPORT"};
  for (int i = 0; i < pages.length; i++) {
    drawButton(x + i * (thirdW + gap), y, thirdW, 20, pages[i],
      dcrteCompositionInspectorPage == i ? color(54, 94, 92) : color(35, 54, 61));
  }
  int contentY = y + 26;
  if (dcrteCompositionInspectorPage == 1) {
    dcrteDrawCompositionAttachmentPage(x, contentY, w, h - 26);
  } else if (dcrteCompositionInspectorPage == 2) {
    dcrteDrawCompositionReportPage(x, contentY, w, h - 26);
  } else {
    dcrteDrawCompositionEnvelopePage(x, contentY, w, h - 26);
  }
}

void dcrteDrawCompositionEnvelopePage(int x, int y, int w, int h) {
  MaterialCompositionConfiguration config = dcrteCompositionConfiguration;
  int gap = 5;
  int halfW = (w - gap) / 2;
  int thirdW = (w - gap * 2) / 3;
  int row = y;
  drawButton(x, row, w, 20, "MODE " + config.mode.label(),
    config.mode == MaterialCompositionMode.SCAFFOLD_ONLY ? color(48, 72, 77) : color(48, 94, 82));
  row += 25;
  drawButton(x, row, thirdW, 20, "SHELL -", color(48, 72, 77));
  drawButton(x + thirdW + gap, row, thirdW, 20,
    config.sourceShell.fabricationShellThicknessVoxels + " VOX",
    config.sourceShell.fabricationShellThicknessVoxels < 2 ? color(112, 72, 36) : color(48, 76, 78));
  drawButton(x + (thirdW + gap) * 2, row, thirdW, 20, "SHELL +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, halfW, 20,
    config.sourceShell.lockSourceShell ? "SHELL LOCKED" : "SHELL UNLOCKED",
    config.sourceShell.lockSourceShell ? color(50, 96, 76) : color(78, 58, 58));
  drawButton(x + halfW + gap, row, halfW, 20,
    "ROLE " + dcrteShortCompositionRole(config.sourceShell.rolePolicy), color(50, 70, 82));
  row += 25;
  drawButton(x, row, halfW, 20, "CLEAR " + dcrteShortClearance(config.clearanceMode),
    config.clearanceMode == ScaffoldClearanceMode.NONE ? color(48, 72, 77) : color(70, 66, 48));
  drawButton(x + halfW + gap, row, thirdW, 20, "CLR -", color(48, 72, 77));
  drawButton(x + halfW + gap + thirdW + gap, row, halfW - thirdW - gap, 20,
    "CLR +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, halfW, 20, "BUILD SOURCE SHELL", color(50, 92, 70));
  drawButton(x + halfW + gap, row, halfW, 20, "COMPOSE ROLES", color(58, 82, 96));
  row += 25;
  drawButton(x, row, halfW, 20, "ANALYZE ATTACHMENT", color(66, 74, 94));
  drawButton(x + halfW + gap, row, halfW, 20, "MATERIALIZE", color(82, 72, 46));
  row += 25;
  String[] overlayNames = {"OFF", "SHELL", "SCAFFOLD", "ATTACH", "BRIDGES", "COMPOSED", "ALL ROLES"};
  drawButton(x, row, w, 20, "ROLE OVERLAY " + overlayNames[dcrteCompositionOverlayMode],
    dcrteCompositionOverlayMode == 0 ? color(48, 72, 77) : color(78, 62, 94));
  row += 31;

  fill(112, 178, 188);
  textAlign(LEFT, TOP);
  textSize(8);
  text("BOUNDARY-ANCHORED COMPOSITION", x, row);
  row += 15;
  row = dcrteInspectorPair(x, row, w, "STAGE", dcrteCompositionStage.label());
  row = dcrteInspectorPair(x, row, w, "STATUS", shortText(dcrteCompositionStatus, 32));
  row = dcrteInspectorPair(x, row, w, "SHELL THICKNESS",
    config.sourceShell.fabricationShellThicknessVoxels + " vox / "
    + nf(dcrteCompositionThicknessMM(), 1, 2) + " mm");
  row = dcrteInspectorPair(x, row, w, "CLEARANCE",
    nf(config.clearanceVoxels, 1, 1) + " vox / " + nf(dcrteCompositionClearanceMM(), 1, 2) + " mm");
  row = dcrteInspectorPair(x, row, w, "SOURCE COVERAGE",
    dcrteSourceShellBuild == null ? "-" : nf(100 * dcrteSourceShellBuild.coverage, 1, 2) + "%");
  row = dcrteInspectorPair(x, row, w, "SOURCE COMPONENTS",
    dcrteSourceShellBuild == null ? "-" : str(dcrteSourceShellBuild.shellComponentCount));
  row = dcrteInspectorPair(x, row, w, "STALE",
    dcrteCompositionStale ? shortText(dcrteCompositionStaleReason, 26) : "NO");
}

void dcrteDrawCompositionAttachmentPage(int x, int y, int w, int h) {
  MaterialCompositionConfiguration config = dcrteCompositionConfiguration;
  int gap = 5;
  int halfW = (w - gap) / 2;
  int thirdW = (w - gap * 2) / 3;
  int row = y;
  drawButton(x, row, w, 20, "POLICY " + dcrteShortAttachmentPolicy(config.attachmentPolicy),
    config.attachmentPolicy == BoundaryAttachmentPolicy.VALIDATE_ONLY
      ? color(48, 72, 77) : color(70, 66, 48));
  row += 25;
  drawButton(x, row, w, 20, "BOUNDARY SEED " + dcrteShortBoundarySeed(config.boundarySeedMode),
    config.boundarySeedMode == BoundarySeedMode.NONE ? color(48, 72, 77) : color(50, 88, 74));
  row += 25;
  drawButton(x, row, halfW, 20,
    config.attachmentNeighborhood == AttachmentNeighborhoodMode.SIX_CONNECTED ? "CONTACT 6-N" : "CONTACT 26-N",
    color(48, 72, 77));
  drawButton(x + halfW + gap, row, halfW, 20,
    "SEEDS " + config.distributedSeedCount, color(48, 72, 77));
  row += 25;
  drawButton(x, row, thirdW, 20, "MAX -", color(48, 72, 77));
  drawButton(x + thirdW + gap, row, thirdW, 20,
    "BRIDGE " + config.bridgeMaxDistanceVoxels, color(58, 72, 90));
  drawButton(x + (thirdW + gap) * 2, row, thirdW, 20, "MAX +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, thirdW, 20, "RAD -", color(48, 72, 77));
  drawButton(x + thirdW + gap, row, thirdW, 20,
    "RADIUS " + nf(config.bridgeRadiusVoxels, 1, 1), color(58, 72, 90));
  drawButton(x + (thirdW + gap) * 2, row, thirdW, 20, "RAD +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, thirdW, 20, "NEAR -", color(48, 72, 77));
  drawButton(x + thirdW + gap, row, thirdW, 20,
    "NEAR " + nf(config.nearBoundaryDistanceVoxels, 1, 1), color(48, 76, 78));
  drawButton(x + (thirdW + gap) * 2, row, thirdW, 20, "NEAR +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, thirdW, 20, "MIN -", color(48, 72, 77));
  drawButton(x + thirdW + gap, row, thirdW, 20,
    "COMP " + config.minimumComponentVoxels, color(48, 76, 78));
  drawButton(x + (thirdW + gap) * 2, row, thirdW, 20, "MIN +", color(48, 72, 77));
  row += 25;
  drawButton(x, row, halfW, 20, "ANALYZE ATTACHMENT", color(66, 74, 94));
  drawButton(x + halfW + gap, row, halfW, 20, "COMPOSE / BRIDGE", color(58, 82, 96));
  row += 31;

  BoundaryAttachmentReport report = dcrteBoundaryAttachmentReport;
  fill(112, 178, 188);
  textAlign(LEFT, TOP);
  textSize(8);
  text("ATTACHMENT CLASSIFICATION", x, row);
  row += 15;
  row = dcrteInspectorPair(x, row, w, "COMPONENTS", report == null ? "-" : str(report.componentCount));
  row = dcrteInspectorPair(x, row, w, "BOUNDARY ATTACHED", report == null ? "-" : str(report.boundaryAttachedCount));
  row = dcrteInspectorPair(x, row, w, "NEAR / FLOATING", report == null ? "-"
    : report.nearBoundaryUnattachedCount + " / " + report.floatingInteriorCount);
  row = dcrteInspectorPair(x, row, w, "TOO SMALL", report == null ? "-" : str(report.tooSmallCount));
  row = dcrteInspectorPair(x, row, w, "ATTACHED FRACTION", report == null ? "-"
    : nf(100 * report.attachedFraction, 1, 2) + "%");
  row = dcrteInspectorPair(x, row, w, "BRIDGE / SUPPORT VOX",
    dcrteCompositionVolume == null ? "-"
      : dcrteCompositionVolume.anchorBridgeCount + " / " + dcrteCompositionVolume.supportMaterialCount);
  row = dcrteInspectorPair(x, row, w, "CONTACT FACES", report == null ? "-" : str(report.directContactFaces));
}

void dcrteDrawCompositionReportPage(int x, int y, int w, int h) {
  int gap = 5;
  int halfW = (w - gap) / 2;
  int row = y;
  drawButton(x, row, halfW, 20, "EXPORT M6 JSON", color(48, 72, 77));
  drawButton(x + halfW + gap, row, halfW, 20, "RESET M6 LAYER", color(70, 54, 60));
  row += 25;
  drawButton(x, row, halfW, 20, "COMPOSE", color(58, 82, 96));
  drawButton(x + halfW + gap, row, halfW, 20, "MATERIALIZE", color(82, 72, 46));
  row += 31;
  MaterialCompositionValidationReport validation = dcrteCompositionValidation;
  FabricationCompositionVolume volume = dcrteCompositionVolume;
  ExteriorEnvelopeFidelityReport fidelity = dcrteEnvelopeFidelityReport;
  fill(112, 178, 188);
  textAlign(LEFT, TOP);
  textSize(8);
  text("COMPOSITION AUDIT", x, row);
  row += 15;
  row = dcrteInspectorPair(x, row, w, "MODE", dcrteCompositionConfiguration.mode.label());
  row = dcrteInspectorPair(x, row, w, "STAGE", dcrteCompositionStage.label());
  row = dcrteInspectorPair(x, row, w, "VALIDATION", validation == null ? "NOT RUN"
    : validation.valid() ? (validation.warningCount() > 0 ? "PASS WITH WARNINGS" : "PASS")
      : "BLOCKED " + validation.firstBlocker());
  row = dcrteInspectorPair(x, row, w, "BLOCKERS / WARNINGS", validation == null ? "-"
    : validation.blockerCount() + " / " + validation.warningCount());
  row = dcrteInspectorPair(x, row, w, "DOMAIN / SHELL", volume == null ? "-"
    : volume.domainCount + " / " + volume.sourceShellCount);
  row = dcrteInspectorPair(x, row, w, "SCAFFOLD / INSET", volume == null ? "-"
    : volume.scheduledScaffoldCount + " / " + volume.insetScaffoldCount);
  row = dcrteInspectorPair(x, row, w, "BRIDGE / SUPPORT", volume == null ? "-"
    : volume.anchorBridgeCount + " / " + volume.supportMaterialCount);
  row = dcrteInspectorPair(x, row, w, "COMPOSED / FINAL", volume == null ? "-"
    : volume.composedMaterialCount + " / " + volume.regularizedMaterialCount);
  row = dcrteInspectorPair(x, row, w, "OUTSIDE / LOCK LOST", volume == null ? "-"
    : volume.outsideCount + " / " + volume.lockedRemovalCount);
  row = dcrteInspectorPair(x, row, w, "SHELL COVERAGE", fidelity == null ? "-"
    : nf(100 * fidelity.sourceBoundaryCoverage, 1, 2) + "%");
  row = dcrteInspectorPair(x, row, w, "SOURCE P95 DIST", fidelity == null ? "-"
    : nf(fidelity.sourceVertexDistanceP95World, 1, 5) + " world");
  row = dcrteInspectorPair(x, row, w, "MATERIALIZER",
    dcrteCompositionMaterialized ? "CURRENT" : "NOT CURRENT");
  row = dcrteInspectorPair(x, row, w, "HASH", volume == null ? "-"
    : shortText(volume.compositionHash, 18));
  if (validation != null && row + 45 < y + h) {
    fill(validation.valid() ? color(92, 222, 164) : color(255, 92, 112));
    textAlign(LEFT, TOP);
    textSize(8);
    String issue = validation.firstBlocker();
    if (issue.length() == 0 && validation.diagnostics.size() > 0) {
      issue = validation.diagnostics.get(0).code;
    }
    text(issue.length() == 0 ? "NO COMPOSITION DIAGNOSTICS" : shortText(issue, 42), x, row + 5);
  }
}

boolean handleDcrteCompositionInspectorMouse(int x, int y, int w, int h) {
  int gap = 5;
  int thirdW = (w - gap * 2) / 3;
  for (int i = 0; i < 3; i++) {
    if (over(x + i * (thirdW + gap), y, thirdW, 20)) {
      dcrteCompositionInspectorPage = i;
      return true;
    }
  }
  int row = y + 26;
  MaterialCompositionConfiguration config = dcrteCompositionConfiguration;
  int halfW = (w - gap) / 2;
  if (dcrteCompositionInspectorPage == 0) {
    if (over(x, row, w, 20)) { dcrteCycleCompositionMode(); return true; }
    row += 25;
    if (over(x, row, thirdW, 20)) { dcrteAdjustCompositionShell(-1); return true; }
    if (over(x + (thirdW + gap) * 2, row, thirdW, 20)) { dcrteAdjustCompositionShell(1); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) {
      config.sourceShell.lockSourceShell = !config.sourceShell.lockSourceShell;
      markDcrteCompositionConfigurationChanged("source-shell lock changed");
      return true;
    }
    if (over(x + halfW + gap, row, halfW, 20)) { dcrteCycleCompositionSourceRole(); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) { dcrteCycleCompositionClearance(); return true; }
    int clearanceThird = thirdW;
    if (over(x + halfW + gap, row, clearanceThird, 20)) { dcrteAdjustCompositionClearance(-0.5f); return true; }
    if (over(x + halfW + gap + clearanceThird + gap, row, halfW - clearanceThird - gap, 20)) {
      dcrteAdjustCompositionClearance(0.5f);
      return true;
    }
    row += 25;
    if (over(x, row, halfW, 20)) { buildDcrteSourceShell(); return true; }
    if (over(x + halfW + gap, row, halfW, 20)) { composeDcrteCurrentMaterial(); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) { analyzeDcrteCurrentAttachment(); return true; }
    if (over(x + halfW + gap, row, halfW, 20)) { materializeDcrteComposition(); return true; }
    row += 25;
    if (over(x, row, w, 20)) {
      dcrteCompositionOverlayMode = (dcrteCompositionOverlayMode + 1) % 7;
      return true;
    }
  } else if (dcrteCompositionInspectorPage == 1) {
    if (over(x, row, w, 20)) { dcrteCycleAttachmentPolicy(); return true; }
    row += 25;
    if (over(x, row, w, 20)) { dcrteCycleBoundarySeedMode(); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) {
      config.attachmentNeighborhood = config.attachmentNeighborhood == AttachmentNeighborhoodMode.SIX_CONNECTED
        ? AttachmentNeighborhoodMode.TWENTY_SIX_CONNECTED : AttachmentNeighborhoodMode.SIX_CONNECTED;
      markDcrteCompositionConfigurationChanged("attachment neighborhood changed");
      return true;
    }
    if (over(x + halfW + gap, row, halfW, 20)) {
      config.distributedSeedCount = config.distributedSeedCount >= 16 ? 1 : config.distributedSeedCount + 1;
      markDcrteCompositionConfigurationChanged("boundary seed count changed");
      return true;
    }
    row += 25;
    if (over(x, row, thirdW, 20)) { config.bridgeMaxDistanceVoxels = max(1, config.bridgeMaxDistanceVoxels - 1); markDcrteCompositionConfigurationChanged("bridge range changed"); return true; }
    if (over(x + (thirdW + gap) * 2, row, thirdW, 20)) { config.bridgeMaxDistanceVoxels = min(32, config.bridgeMaxDistanceVoxels + 1); markDcrteCompositionConfigurationChanged("bridge range changed"); return true; }
    row += 25;
    if (over(x, row, thirdW, 20)) { config.bridgeRadiusVoxels = max(0.5f, config.bridgeRadiusVoxels - 0.25f); markDcrteCompositionConfigurationChanged("bridge radius changed"); return true; }
    if (over(x + (thirdW + gap) * 2, row, thirdW, 20)) { config.bridgeRadiusVoxels = min(6, config.bridgeRadiusVoxels + 0.25f); markDcrteCompositionConfigurationChanged("bridge radius changed"); return true; }
    row += 25;
    if (over(x, row, thirdW, 20)) { config.nearBoundaryDistanceVoxels = max(0, config.nearBoundaryDistanceVoxels - 0.5f); markDcrteCompositionConfigurationChanged("near-boundary threshold changed"); return true; }
    if (over(x + (thirdW + gap) * 2, row, thirdW, 20)) { config.nearBoundaryDistanceVoxels = min(16, config.nearBoundaryDistanceVoxels + 0.5f); markDcrteCompositionConfigurationChanged("near-boundary threshold changed"); return true; }
    row += 25;
    if (over(x, row, thirdW, 20)) { config.minimumComponentVoxels = max(1, config.minimumComponentVoxels - 1); markDcrteCompositionConfigurationChanged("minimum component changed"); return true; }
    if (over(x + (thirdW + gap) * 2, row, thirdW, 20)) { config.minimumComponentVoxels = min(128, config.minimumComponentVoxels + 1); markDcrteCompositionConfigurationChanged("minimum component changed"); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) { analyzeDcrteCurrentAttachment(); return true; }
    if (over(x + halfW + gap, row, halfW, 20)) { composeDcrteCurrentMaterial(); return true; }
  } else {
    if (over(x, row, halfW, 20)) { exportDcrteCompositionReport(); return true; }
    if (over(x + halfW + gap, row, halfW, 20)) { resetDcrteComposition(); return true; }
    row += 25;
    if (over(x, row, halfW, 20)) { composeDcrteCurrentMaterial(); return true; }
    if (over(x + halfW + gap, row, halfW, 20)) { materializeDcrteComposition(); return true; }
  }
  return false;
}

void drawDcrteCompositionOverlay(float previewScale) {
  if (dcrteCompositionOverlayMode == 0 || dcrteCompositionVolume == null
      || dcrteCompositionVolume.spec == null) return;
  FabricationCompositionVolume volume = dcrteCompositionVolume;
  if (dcrteCompositionOverlayMode == 1 || dcrteCompositionOverlayMode == 6) {
    dcrteDrawCompositionMask(volume.sourceShell, volume.spec, previewScale,
      color(28, 232, 202), 9000, 2.2f);
  }
  if (dcrteCompositionOverlayMode == 2 || dcrteCompositionOverlayMode == 6) {
    dcrteDrawCompositionMask(volume.scheduledScaffold, volume.spec, previewScale,
      color(74, 144, 238), 9000, 2.1f);
  }
  if (dcrteCompositionOverlayMode == 3 || dcrteCompositionOverlayMode == 6) {
    dcrteDrawFloatingAttachmentComponents(volume.spec, previewScale);
  }
  if (dcrteCompositionOverlayMode == 4 || dcrteCompositionOverlayMode == 6) {
    dcrteDrawCompositionMask(volume.anchorBridge, volume.spec, previewScale,
      color(232, 88, 244), 9000, 3.0f);
    dcrteDrawCompositionMask(volume.supportMaterial, volume.spec, previewScale,
      color(255, 156, 54), 9000, 3.0f);
  }
  if (dcrteCompositionOverlayMode == 5 || dcrteCompositionOverlayMode == 6) {
    dcrteDrawCompositionMask(volume.regularizedMaterialCount > 0
      ? volume.regularizedMaterial : volume.composedMaterial,
      volume.spec, previewScale, color(126, 242, 116), 10000, 1.8f);
  }
}

void dcrteDrawFloatingAttachmentComponents(VolumeSpec spec, float scale) {
  if (dcrteBoundaryAttachmentReport == null) return;
  for (int i = 0; i < dcrteBoundaryAttachmentReport.components.size(); i++) {
    BoundaryAttachmentComponentReport component = dcrteBoundaryAttachmentReport.components.get(i);
    if (component.classification == BoundaryAttachmentClass.BOUNDARY_ATTACHED
        || component.classification == BoundaryAttachmentClass.ATTACHED_THROUGH_SCAFFOLD) continue;
    boolean[] mask = new boolean[spec.voxelCount()];
    for (int j = 0; j < component.voxelIndices.length; j++) {
      int index = component.voxelIndices[j];
      if (index >= 0 && index < mask.length) mask[index] = true;
    }
    dcrteDrawCompositionMask(mask, spec, scale, color(255, 70, 92), 4000, 3.2f);
  }
}

void dcrteDrawCompositionMask(boolean[] mask, VolumeSpec spec, float scale,
    color maskColor, int maxPoints, float weight) {
  if (mask == null || spec == null || mask.length != spec.voxelCount()) return;
  int count = dcrteCountTrue(mask);
  int stride = max(1, count / max(1, maxPoints));
  int seen = 0;
  stroke(maskColor);
  strokeWeight(weight);
  beginShape(POINTS);
  for (int index = 0; index < mask.length; index++) {
    if (!mask[index] || (seen++ % stride) != 0) continue;
    int gx = index % spec.nx;
    int yz = index / spec.nx;
    int gy = yz % spec.ny;
    int gz = yz / spec.ny;
    float wx = spec.bounds.minX + (gx + 0.5f) * spec.spacingX();
    float wy = spec.bounds.minY + (gy + 0.5f) * spec.spacingY();
    float wz = spec.bounds.minZ + (gz + 0.5f) * spec.spacingZ();
    vertex(wx * scale, wy * scale, wz * scale);
  }
  endShape();
}

void dcrteCycleCompositionMode() {
  MaterialCompositionMode[] modes = MaterialCompositionMode.values();
  int next = (dcrteCompositionConfiguration.mode.ordinal() + 1) % modes.length;
  dcrteCompositionConfiguration.mode = modes[next];
  markDcrteCompositionConfigurationChanged("composition mode changed");
}

void dcrteAdjustCompositionShell(int delta) {
  SourceShellConfiguration shell = dcrteCompositionConfiguration.sourceShell;
  shell.fabricationShellThicknessVoxels = constrain(
    shell.fabricationShellThicknessVoxels + delta, 1, 32);
  markDcrteCompositionConfigurationChanged("fabrication shell thickness changed");
}

void dcrteCycleCompositionSourceRole() {
  SourceShellRolePolicy[] policies = SourceShellRolePolicy.values();
  SourceShellConfiguration shell = dcrteCompositionConfiguration.sourceShell;
  shell.rolePolicy = policies[(shell.rolePolicy.ordinal() + 1) % policies.length];
  markDcrteCompositionConfigurationChanged("source-shell role changed");
}

void dcrteCycleCompositionClearance() {
  dcrteCompositionConfiguration.clearanceMode =
    dcrteCompositionConfiguration.clearanceMode == ScaffoldClearanceMode.NONE
      ? ScaffoldClearanceMode.INSET_FROM_SOURCE_SHELL : ScaffoldClearanceMode.NONE;
  markDcrteCompositionConfigurationChanged("scaffold clearance mode changed");
}

void dcrteAdjustCompositionClearance(float delta) {
  dcrteCompositionConfiguration.clearanceVoxels = constrain(
    dcrteCompositionConfiguration.clearanceVoxels + delta, 0, 16);
  markDcrteCompositionConfigurationChanged("scaffold clearance changed");
}

void dcrteCycleAttachmentPolicy() {
  BoundaryAttachmentPolicy[] policies = BoundaryAttachmentPolicy.values();
  MaterialCompositionConfiguration config = dcrteCompositionConfiguration;
  config.attachmentPolicy = policies[(config.attachmentPolicy.ordinal() + 1) % policies.length];
  markDcrteCompositionConfigurationChanged("attachment policy changed");
}

void dcrteCycleBoundarySeedMode() {
  BoundarySeedMode[] modes = BoundarySeedMode.values();
  MaterialCompositionConfiguration config = dcrteCompositionConfiguration;
  config.boundarySeedMode = modes[(config.boundarySeedMode.ordinal() + 1) % modes.length];
  markDcrteCompositionConfigurationChanged("boundary seed mode changed");
  dcrteInvalidateScheduler("boundary seed strategy changed");
}

float dcrteCompositionThicknessMM() {
  VolumeSpec spec = dcrteCompositionVolume == null ? null : dcrteCompositionVolume.spec;
  int resolution = spec == null ? max(1, dcrteImportedResolution) : max(1, spec.nx);
  return dcrteCompositionConfiguration.sourceShell.fabricationShellThicknessVoxels
    * foundryScaleMM / resolution;
}

float dcrteCompositionClearanceMM() {
  VolumeSpec spec = dcrteCompositionVolume == null ? null : dcrteCompositionVolume.spec;
  int resolution = spec == null ? max(1, dcrteImportedResolution) : max(1, spec.nx);
  return dcrteCompositionConfiguration.clearanceVoxels * foundryScaleMM / resolution;
}

String dcrteShortCompositionRole(SourceShellRolePolicy policy) {
  if (policy == SourceShellRolePolicy.SINGLE_QUALIFIED_COMPONENT) return "SINGLE";
  if (policy == SourceShellRolePolicy.DOMINANT_QUALIFIED_COMPONENT) return "DOMINANT";
  return "EXPLICIT";
}

String dcrteShortClearance(ScaffoldClearanceMode mode) {
  return mode == ScaffoldClearanceMode.NONE ? "NONE" : "INSET";
}

String dcrteShortAttachmentPolicy(BoundaryAttachmentPolicy policy) {
  if (policy == BoundaryAttachmentPolicy.REQUIRE_EXISTING_CONTACT) return "REQUIRE CONTACT";
  if (policy == BoundaryAttachmentPolicy.SEED_FROM_BOUNDARY) return "SEED FROM BOUNDARY";
  if (policy == BoundaryAttachmentPolicy.BRIDGE_FIELD_CONSTRAINED) return "BRIDGE IN FIELD";
  if (policy == BoundaryAttachmentPolicy.BRIDGE_DOMAIN_CONSTRAINED) return "BRIDGE IN DOMAIN";
  return "VALIDATE ONLY";
}

String dcrteShortBoundarySeed(BoundarySeedMode mode) {
  if (mode == BoundarySeedMode.SOURCE_SHELL_NEAREST_CENTER) return "NEAREST CENTER";
  if (mode == BoundarySeedMode.SOURCE_SHELL_INTRINSIC_START) return "INTRINSIC START";
  if (mode == BoundarySeedMode.SOURCE_SHELL_INTRINSIC_END) return "INTRINSIC END";
  if (mode == BoundarySeedMode.SELECTED_PATCH) return "SELECTED PATCH";
  if (mode == BoundarySeedMode.DISTRIBUTED) return "DISTRIBUTED";
  return "NONE";
}
