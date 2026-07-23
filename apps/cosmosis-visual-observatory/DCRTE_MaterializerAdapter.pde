/*
  DCRTE-ET Milestone 1 boundary to the established Surface Foundry voxel mesher.

  The flat DCRTE volume is authoritative. Conversion to boolean[][][] happens
  only here because the existing regularizer, call-sheet pipeline, and voxel
  face materializer consume that legacy representation.
*/

class LegacyVoxelMaterializerAdapter {
  int lastDomainRepairAdditions;
  int lastDomainRepairRemovals;
  String getId() { return "legacy_voxel_materializer_adapter"; }
  String getVersion() { return "1.0-m1"; }

  boolean[][][] toLegacyBooleanVolume(DCRTEVolume volume) {
    if (volume == null || !volume.isValid()) return null;
    VolumeSpec spec = volume.spec;
    boolean[][][] solid = new boolean[spec.nx][spec.ny][spec.nz];
    for (int z = 0; z < spec.nz; z++) {
      for (int y = 0; y < spec.ny; y++) {
        for (int x = 0; x < spec.nx; x++) {
          solid[x][y][z] = volume.finalSolid[volume.index(x, y, z)];
        }
      }
    }
    return solid;
  }

  int clipLegacyVolumeToAdmission(boolean[][][] solid, DCRTEVolume volume) {
    if (solid == null || volume == null || !volume.isValid()) return 0;
    int clipped = 0;
    VolumeSpec spec = volume.spec;
    for (int z = 0; z < spec.nz; z++) {
      for (int y = 0; y < spec.ny; y++) {
        for (int x = 0; x < spec.nx; x++) {
          int idx = volume.index(x, y, z);
          if (solid[x][y][z] && !volume.admitted[idx]) {
            solid[x][y][z] = false;
            clipped++;
          }
        }
      }
    }
    return clipped;
  }

  void synchronizeFlatVolume(boolean[][][] solid, DCRTEVolume volume) {
    if (solid == null || volume == null || !volume.isValid()) return;
    VolumeSpec spec = volume.spec;
    for (int z = 0; z < spec.nz; z++) {
      for (int y = 0; y < spec.ny; y++) {
        for (int x = 0; x < spec.nx; x++) {
          int idx = volume.index(x, y, z);
          boolean finalValue = solid[x][y][z] && volume.admitted[idx];
          volume.active[idx] = finalValue;
          volume.finalSolid[idx] = finalValue;
        }
      }
    }
    volume.recountFinal();
  }

  void regularizeWithinAdmission(boolean[][][] solid, DCRTEVolume volume, int maxPasses) {
    lastDomainRepairAdditions = 0;
    lastDomainRepairRemovals = 0;
    int n = solid.length;
    for (int pass = 0; pass < maxPasses; pass++) {
      int changed = 0;
      for (int x = 0; x < n; x++) for (int y = 1; y < n; y++) for (int z = 1; z < n; z++) {
        changed += resolveWithinAdmission(solid, volume,
          x, y - 1, z - 1, x, y, z - 1, x, y, z, x, y - 1, z);
      }
      for (int y = 0; y < n; y++) for (int x = 1; x < n; x++) for (int z = 1; z < n; z++) {
        changed += resolveWithinAdmission(solid, volume,
          x - 1, y, z - 1, x, y, z - 1, x, y, z, x - 1, y, z);
      }
      for (int z = 0; z < n; z++) for (int x = 1; x < n; x++) for (int y = 1; y < n; y++) {
        changed += resolveWithinAdmission(solid, volume,
          x - 1, y - 1, z, x, y - 1, z, x, y, z, x - 1, y, z);
      }
      if (changed == 0) break;
    }
  }

  int resolveWithinAdmission(boolean[][][] solid, DCRTEVolume volume,
    int ax, int ay, int az, int bx, int by, int bz,
    int cx, int cy, int cz, int dx, int dy, int dz) {
    boolean a = solid[ax][ay][az];
    boolean b = solid[bx][by][bz];
    boolean c = solid[cx][cy][cz];
    boolean d = solid[dx][dy][dz];
    if (a && c && !b && !d) {
      return bridgeOrCull(solid, volume,
        bx, by, bz, dx, dy, dz,
        ax, ay, az, cx, cy, cz);
    }
    if (b && d && !a && !c) {
      return bridgeOrCull(solid, volume,
        ax, ay, az, cx, cy, cz,
        bx, by, bz, dx, dy, dz);
    }
    return 0;
  }

  int bridgeOrCull(boolean[][][] solid, DCRTEVolume volume,
    int bridgeAX, int bridgeAY, int bridgeAZ, int bridgeBX, int bridgeBY, int bridgeBZ,
    int solidAX, int solidAY, int solidAZ, int solidBX, int solidBY, int solidBZ) {
    boolean admitA = volume.admitted[volume.index(bridgeAX, bridgeAY, bridgeAZ)];
    boolean admitB = volume.admitted[volume.index(bridgeBX, bridgeBY, bridgeBZ)];
    if (admitA || admitB) {
      if (admitA && admitB) {
        fillFoundryBridge(solid, bridgeAX, bridgeAY, bridgeAZ, bridgeBX, bridgeBY, bridgeBZ);
      } else if (admitA) {
        solid[bridgeAX][bridgeAY][bridgeAZ] = true;
      } else {
        solid[bridgeBX][bridgeBY][bridgeBZ] = true;
      }
      lastDomainRepairAdditions++;
      return 1;
    }

    int neighborsA = foundryFaceNeighborCount(solid, solidAX, solidAY, solidAZ);
    int neighborsB = foundryFaceNeighborCount(solid, solidBX, solidBY, solidBZ);
    boolean removeA = neighborsA < neighborsB
      || (neighborsA == neighborsB && ((solidAX + solidAY + solidAZ) & 1) == 0);
    if (removeA) solid[solidAX][solidAY][solidAZ] = false;
    else solid[solidBX][solidBY][solidBZ] = false;
    lastDomainRepairRemovals++;
    return 1;
  }

  boolean materialize(DCRTEVolume volume) {
    boolean[][][] solid = toLegacyBooleanVolume(volume);
    if (solid == null) return false;

    foundryBridgeVoxels = regularizeFoundrySolid(solid, 24);
    int clippedBridges = clipLegacyVolumeToAdmission(solid, volume);
    foundryBridgeVoxels = max(0, foundryBridgeVoxels - clippedBridges);
    regularizeWithinAdmission(solid, volume, 24);
    foundryBridgeVoxels += lastDomainRepairAdditions;
    synchronizeFlatVolume(solid, volume);
    foundryCallSheetSolid = solid;

    int n = volume.spec.nx;
    String meshName = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH && dcrteImportedSourceMesh != null
      ? "rdft_dcrte_imported_" + dcrteImportedSourceMesh.sourceName
      : "rdft_dcrte_primitive_" + dcrtePrimitiveDomainType.id();
    foundryMesh = new SurfaceMesh(meshName);
    for (int z = 0; z < n; z++) {
      for (int y = 0; y < n; y++) {
        for (int x = 0; x < n; x++) {
          if (!solid[x][y][z]) continue;
          addVoxelBoundaryFaces(foundryMesh, solid, x, y, z, n);
        }
      }
    }

    int[] audit = foundryMesh.manifoldAudit();
    foundryBoundaryEdges = audit[0];
    foundryNonManifoldEdges = audit[1];
    foundryDegenerateFaces = audit[2];
    return foundryMesh.tris.size() > 0
      && foundryBoundaryEdges == 0
      && foundryNonManifoldEdges == 0
      && foundryDegenerateFaces == 0;
  }

  boolean materialize(FabricationCompositionVolume composition,
      DCRTEVolume sourceFieldVolume) {
    if (composition == null || !composition.isValid()
        || sourceFieldVolume == null || !sourceFieldVolume.isValid()
        || sourceFieldVolume.spec.voxelCount() != composition.spec.voxelCount()) return false;

    if (dcrteCompositionConfiguration.mode == MaterialCompositionMode.SCAFFOLD_ONLY) {
      DCRTEVolume isolated = new DCRTEVolume(composition.spec);
      for (int i = 0; i < isolated.active.length; i++) {
        isolated.admitted[i] = sourceFieldVolume.admitted[i];
        isolated.candidateSolid[i] = sourceFieldVolume.candidateSolid[i];
        isolated.scalar[i] = sourceFieldVolume.scalar[i];
        isolated.active[i] = composition.composedMaterial[i];
        isolated.finalSolid[i] = composition.composedMaterial[i];
      }
      isolated.recountFinal();
      boolean exactBaseline = materialize(isolated);
      dcrteM6CopyLegacyToFlat(foundryCallSheetSolid, composition.regularizedMaterial,
        composition.spec);
      composition.recount();
      composition.computeHash();
      return exactBaseline;
    }

    boolean[][][] solid = dcrteM6ToLegacyBooleanVolume(composition.composedMaterial,
      composition.spec);
    if (solid == null) return false;
    boolean[] beforeRegularization = java.util.Arrays.copyOf(
      composition.composedMaterial, composition.composedMaterial.length);
    foundryBridgeVoxels = regularizeFoundrySolid(solid, 24);

    composition.lockedRemovalAttemptCount = 0;
    composition.lockedRemovalCount = 0;
    int clippedOutside = 0;
    for (int z = 0; z < composition.spec.nz; z++) {
      for (int y = 0; y < composition.spec.ny; y++) {
        for (int x = 0; x < composition.spec.nx; x++) {
          int index = composition.index(x, y, z);
          if (composition.lockedMaterial[index] && beforeRegularization[index]
              && !solid[x][y][z]) composition.lockedRemovalAttemptCount++;
          if (solid[x][y][z] && !composition.domainInside[index]) {
            solid[x][y][z] = false;
            clippedOutside++;
          }
          if (composition.lockedMaterial[index]) solid[x][y][z] = true;
          composition.regularizedMaterial[index] = solid[x][y][z];
        }
      }
    }
    foundryBridgeVoxels = max(0, foundryBridgeVoxels - clippedOutside);
    for (int i = 0; i < composition.lockedMaterial.length; i++) {
      if (composition.lockedMaterial[i] && !composition.regularizedMaterial[i]) {
        composition.lockedRemovalCount++;
      }
    }
    composition.recount();
    composition.computeHash();
    foundryCallSheetSolid = solid;

    int n = composition.spec.nx;
    String sourceName = dcrteImportedSourceMesh == null
      ? "unknown" : dcrteImportedSourceMesh.sourceName;
    foundryMesh = new SurfaceMesh("rdft_dcrte_m6_composed_" + sourceName);
    for (int z = 0; z < n; z++) {
      for (int y = 0; y < n; y++) {
        for (int x = 0; x < n; x++) {
          if (!solid[x][y][z]) continue;
          addVoxelBoundaryFaces(foundryMesh, solid, x, y, z, n);
        }
      }
    }
    int[] audit = foundryMesh.manifoldAudit();
    foundryBoundaryEdges = audit[0];
    foundryNonManifoldEdges = audit[1];
    foundryDegenerateFaces = audit[2];
    boolean valid = foundryMesh.tris.size() > 0
      && foundryBoundaryEdges == 0
      && foundryNonManifoldEdges == 0
      && foundryDegenerateFaces == 0
      && composition.lockedRemovalCount == 0;
    if (dcrteCompositionValidation != null) {
      dcrteCompositionValidation.materializerValid = valid;
      dcrteCompositionValidation.regularizedCount = composition.regularizedMaterialCount;
      dcrteCompositionValidation.lockedRemovalCount = composition.lockedRemovalCount;
      dcrteCompositionValidation.outsideCount = composition.outsideCount;
      dcrteCompositionValidation.compositionHash = composition.compositionHash;
      if (composition.lockedRemovalCount > 0) {
        dcrteCompositionValidation.error(DCRTEM6Codes.LOCKED_SHELL_REMOVED,
          "Materialization removed locked source-shell voxels.");
      }
      if (!valid) {
        dcrteCompositionValidation.error(DCRTEM6Codes.MATERIALIZER_MANIFOLD_FAILURE,
          "The composed voxel boundary failed the manifold materializer audit.");
      }
      dcrteEnvelopeFidelityReport = dcrteEnvelopeFidelityAnalyzer.analyze(
        composition, dcrteImportedSdf, dcrteImportedWorldMesh);
      dcrteCompositionValidation.fidelityReport = dcrteEnvelopeFidelityReport;
    }
    return valid;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setString("authoritative_volume", dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
      ? "flat_imported_domain_arrays"
      : "flat_primitive_arrays");
    json.setString("legacy_conversion", "boolean_3d_at_materializer_boundary");
    json.setString("regularization", "legacy_regularizer_then_domain_clip_then_admission_aware_cleanup");
    json.setInt("last_domain_repair_additions", lastDomainRepairAdditions);
    json.setInt("last_domain_repair_removals", lastDomainRepairRemovals);
    json.setString("raised_veins_policy", dcrteRaisedVeinsPolicy());
    return json;
  }
}

LegacyVoxelMaterializerAdapter dcrteLegacyMaterializer = new LegacyVoxelMaterializerAdapter();

boolean[][][] dcrteM6ToLegacyBooleanVolume(boolean[] mask, VolumeSpec spec) {
  if (mask == null || spec == null || !spec.isValid() || mask.length != spec.voxelCount()) return null;
  boolean[][][] solid = new boolean[spec.nx][spec.ny][spec.nz];
  for (int z = 0; z < spec.nz; z++) {
    for (int y = 0; y < spec.ny; y++) {
      for (int x = 0; x < spec.nx; x++) {
        solid[x][y][z] = mask[x + spec.nx * (y + spec.ny * z)];
      }
    }
  }
  return solid;
}

void dcrteM6CopyLegacyToFlat(boolean[][][] solid, boolean[] target, VolumeSpec spec) {
  if (solid == null || target == null || spec == null || target.length != spec.voxelCount()) return;
  for (int z = 0; z < spec.nz; z++) {
    for (int y = 0; y < spec.ny; y++) {
      for (int x = 0; x < spec.nx; x++) {
        target[x + spec.nx * (y + spec.ny * z)] = solid[x][y][z];
      }
    }
  }
}

boolean materializeDcrteComposition() {
  if (dcrteCompositionVolume == null || dcrteCompositionValidation == null
      || !dcrteCompositionValidation.valid()) {
    if (!composeDcrteCurrentMaterial()) return false;
  }
  DCRTEVolume source = dcrteSchedulerActiveVolume();
  if (source == null) {
    dcrteCompositionStatus = "composition materialization blocked - source field unavailable";
    return false;
  }
  long started = millis();
  boolean valid = dcrteLegacyMaterializer.materialize(dcrteCompositionVolume, source);
  long elapsed = millis() - started;
  dcrteCompositionMaterialized = valid;
  dcrteCompositionStale = false;
  dcrteCompositionStage = valid ? M6CompositionStage.MATERIALIZED : M6CompositionStage.BLOCKED;
  dcrteCompositionStatus = valid
    ? "composition materialized - " + foundryMesh.tris.size() + " triangles"
    : "composition materializer audit failed";
  foundryStatus = dcrteCompositionStatus;
  foundryMeshStale = !valid;
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) dcrteImportedStale = !valid;
  if (dcrteSchedulerController != null && dcrteSchedulerController.state != null) {
    dcrteSchedulerController.materializedBatch = dcrteSchedulerController.state.batchIndex;
    dcrteSchedulerController.materializedStateHash = dcrteSchedulerController.state.stateHash;
    dcrteSchedulerController.diagnostics.materializationMillis = elapsed;
  }
  return valid;
}

boolean legacyCandidateSolid(float scalarValue) {
  return abs(scalarValue) < foundryIsoBand;
}

void generateSelectedSurfaceFoundryMesh() {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) generateDcrtePrimitiveSurfaceMesh();
  else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) generateDcrteImportedSurfaceMesh();
  else generateSurfaceFoundryMesh();
}

void generateDcrteImportedSurfaceMesh() {
  long totalStart = millis();
  foundryMeshStale = true;
  foundryLastExport = "";
  if (dcrteImportedSourceMesh == null) {
    dcrteImportedStatus = "load a watertight STL first";
    foundryStatus = dcrteImportedStatus;
    return;
  }
  if (dcrteImportedSdfDirty || dcrteImportedDomain == null || !dcrteImportedDomain.isValid()) {
    if (!buildDcrteImportedSdf()) {
      foundryStatus = dcrteImportedStatus;
      return;
    }
  }
  runDcrteImportedPreflightWithDerived(true, false);
  if (!dcrtePreflightAllowsMaterialization()) {
    dcrteImportedStatus = "materialization disabled - "
      + (dcrteImportedPreflightReport.firstBlockingCode.length() == 0
        ? "preflight unresolved" : dcrteImportedPreflightReport.firstBlockingCode);
    foundryStatus = dcrteImportedStatus;
    dcrtePreflightPanelOpen = true;
    return;
  }

  boolean intrinsicRequired = dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL
    || dcrteCoordinateComparisonMode == CoordinateComparisonMode.CARTESIAN_AND_INTRINSIC
    || dcrteHbeEnabled;
  if (intrinsicRequired && !dcrteIntrinsicStateCurrent()) {
    String staleIssue = dcrteIntrinsicStateIssue(dcrteIntrinsicBuildResult);
    if (dcrteIntrinsicBuildResult != null && (staleIssue.equals("INTRINSIC_SOURCE_STALE")
        || staleIssue.equals("INTRINSIC_GRID_MISMATCH") || staleIssue.equals("INTRINSIC_SOURCE_SDF_MISSING")
        || staleIssue.equals("INTRINSIC_CENTERLINE_OUT_OF_BOUNDS") || staleIssue.equals("INTRINSIC_CENTERLINE_NONFINITE")
        || staleIssue.equals("INTRINSIC_FRAME_NONFINITE") || staleIssue.equals("INTRINSIC_FRAME_SCALE_INVALID"))) {
      invalidateDcrteIntrinsic(staleIssue);
    }
    if (!buildDcrteImportedIntrinsicCoordinates()) {
      dcrteImportedStatus = "intrinsic materialization blocked - " + dcrteIntrinsicBuildStatus;
      foundryStatus = dcrteImportedStatus;
      dcrtePreflightPanelOpen = true;
      dcrtePreflightInspectorTab = 4;
      return;
    }
  }
  FieldCoordinateSystem coordinateSystem = dcrteSelectedCoordinateSystem();
  if (coordinateSystem == null || !coordinateSystem.isValid()) {
    dcrteImportedStatus = "coordinate system invalid - " + (coordinateSystem == null
      ? "not built" : coordinateSystem.validationMessage());
    foundryStatus = dcrteImportedStatus;
    dcrtePreflightPanelOpen = true;
    dcrtePreflightInspectorTab = 4;
    return;
  }

  dcrteImportedBuildState = DCRTEImportedBuildState.MATERIALIZING;
  VolumeSpec spec = createDcrteImportedVolumeSpec();
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(spec);
  ObservationLayer observation = createDcrteObservationLayer(spec);
  DCRTEValidationReport report = validateDcrteConfiguration(dcrteImportedDomain, observer, observation);
  if (report.status == ValidationStatus.FAIL) {
    dcrteLastValidationReport = report;
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "imported configuration invalid";
    foundryStatus = dcrteImportedStatus;
    runDcrteImportedPreflightWithDerived(true, false);
    return;
  }

  DCRTEVolume volume;
  try {
    volume = new DCRTEVolume(spec);
  }
  catch (OutOfMemoryError error) {
    report.addError("VOLUME_ALLOCATION_FAILED");
    dcrteLastValidationReport = report;
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "imported field volume allocation failed";
    foundryStatus = dcrteImportedStatus;
    runDcrteImportedPreflightWithDerived(true, false);
    return;
  }

  DCRTEConfig buildConfig = captureDcrteConfig();
  if (dcrteFieldEngine == null) dcrteFieldEngine = new LegacyTopologyScalarAdapter();
  dcrteFieldEngine.configure(buildConfig);
  float[] scores = buildConfig.topologyBlendCopy();
  if (dcrteHbeEnabled && (dcrteHbePreparedObservables == null
      || !dcrteHbeSpecsEqual(dcrteHbePreparedObservables.spec, spec))) {
    if (!dcrteHbePrepareCurrentIntrinsic()) {
      dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
      dcrteImportedStatus = dcrteHbeStatus;
      foundryStatus = dcrteImportedStatus;
      return;
    }
  }
  HBEFieldContext hbeFieldContext = dcrteHbePrepareFieldContext(spec);
  if (dcrteHbeEnabled && dcrteHbeConfig.influenceMode.fieldEnabled()
      && hbeFieldContext == null) {
    dcrteHbeState = HBEState.FAILED;
    dcrteHbeStatus = "HBE field blocked: frozen intrinsic grid does not match materializer grid";
    dcrteImportedStatus = dcrteHbeStatus;
    foundryStatus = dcrteImportedStatus;
    return;
  }
  dcrteHbeFieldSensitivity = new HBEFieldSensitivityReport();
  DomainSample domainSample = new DomainSample();
  ObservationSample observationSample = new ObservationSample();
  long domainNanos = 0;
  long fieldNanos = 0;
  boolean pairedComparison = dcrteCoordinateComparisonMode == CoordinateComparisonMode.CARTESIAN_AND_INTRINSIC;
  boolean[] comparisonCartesian = pairedComparison ? new boolean[spec.voxelCount()] : null;
  boolean[] comparisonIntrinsic = pairedComparison ? new boolean[spec.voxelCount()] : null;
  DCRTECoordinateComparisonReport comparison = pairedComparison ? new DCRTECoordinateComparisonReport() : null;
  long comparisonCartesianNanos = 0;
  long comparisonIntrinsicNanos = 0;
  long comparisonMappingNanos = 0;
  int selectedFallbackCount = 0;
  for (int z = 0; z < spec.nz; z++) {
    float wz = observer.worldZ(z);
    for (int y = 0; y < spec.ny; y++) {
      float wy = observer.worldY(y);
      for (int x = 0; x < spec.nx; x++) {
        int idx = observer.index(x, y, z);
        float wx = observer.worldX(x);
        long domainTick = System.nanoTime();
        dcrteImportedDomain.sampleAtIndex(x, y, z, domainSample);
        if (domainSample.inside) volume.domainInsideCount++;
        observation.observe(domainSample, observationSample);
        volume.admitted[idx] = observationSample.admitted;
        if (observationSample.admitted) volume.admittedCount++;
        domainNanos += System.nanoTime() - domainTick;

        long fieldTick = System.nanoTime();
        FieldCoordinateSample coordinate = coordinateSystem.mapAtIndex(x, y, z, wx, wy, wz);
        float scalarValue = 0;
        if (observationSample.admitted) {
          if (!coordinate.valid) scalarValue = Float.NaN;
          else {
            scalarValue = dcrteSampleFoundryField(coordinate.fieldX, coordinate.fieldY, coordinate.fieldZ, scores);
            if (coordinate.fallbackUsed) selectedFallbackCount++;
          }
        } else if (dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN) {
          // Preserve the exact Milestone 2 Cartesian sampling baseline outside the admitted mask.
          scalarValue = dcrteSampleFoundryField(wx, wy, wz, scores);
        }
        float baseScalarValue = scalarValue;
        if (observationSample.admitted && coordinate.valid && hbeFieldContext != null)
          scalarValue = dcrteHbeFieldModifier.modify(baseScalarValue, coordinate, idx, hbeFieldContext);
        volume.scalar[idx] = scalarValue;
        if (!dcrteFinite(scalarValue)) {
          volume.nonFiniteScalarCount++;
          if (volume.firstNonFiniteIndex < 0) {
            volume.firstNonFiniteIndex = idx;
            volume.firstNonFiniteX = wx;
            volume.firstNonFiniteY = wy;
            volume.firstNonFiniteZ = wz;
          }
        }
        boolean baseCandidate = dcrteFinite(baseScalarValue) && legacyCandidateSolid(baseScalarValue);
        boolean candidate = dcrteFinite(scalarValue) && legacyCandidateSolid(scalarValue);
        if (hbeFieldContext != null)
          dcrteHbeFieldSensitivity.observe(idx, baseScalarValue, scalarValue,
            baseCandidate, candidate, hbeFieldContext);
        volume.candidateSolid[idx] = candidate;
        if (candidate) volume.candidateSolidCount++;
        boolean active = dcrteImmediateScheduler.activate(observationSample.admitted, candidate);
        volume.active[idx] = active;
        volume.finalSolid[idx] = active;
        fieldNanos += System.nanoTime() - fieldTick;

        if (pairedComparison && observationSample.admitted) {
          long cartTick = System.nanoTime();
          float cartScalar = dcrteSampleFoundryField(wx, wy, wz, scores);
          comparisonCartesianNanos += System.nanoTime() - cartTick;
          boolean cartCandidate = dcrteFinite(cartScalar) && legacyCandidateSolid(cartScalar);
          comparisonCartesian[idx] = cartCandidate;
          if (cartCandidate) { comparison.cartesianCandidateCount++; comparison.cartesianFinalCount++; }

          long mappingTick = System.nanoTime();
          FieldCoordinateSample intrinsicCoordinate = dcrteIntrinsicCoordinateSystem.mapAtIndex(x, y, z, wx, wy, wz);
          comparisonMappingNanos += System.nanoTime() - mappingTick;
          long intrinsicTick = System.nanoTime();
          float intrinsicScalar = intrinsicCoordinate.valid
            ? dcrteSampleFoundryField(intrinsicCoordinate.fieldX, intrinsicCoordinate.fieldY, intrinsicCoordinate.fieldZ, scores)
            : Float.NaN;
          comparisonIntrinsicNanos += System.nanoTime() - intrinsicTick;
          boolean intrinsicCandidate = dcrteFinite(intrinsicScalar) && legacyCandidateSolid(intrinsicScalar);
          comparisonIntrinsic[idx] = intrinsicCandidate;
          if (intrinsicCandidate) { comparison.intrinsicCandidateCount++; comparison.intrinsicFinalCount++; }
          comparison.admittedVoxelCount++;
        }
      }
    }
  }
  dcrteHbeFieldSensitivity.finish();
  report.domainBuildMillis = domainNanos / 1000000L;
  report.fieldSampleMillis = fieldNanos / 1000000L;
  if (pairedComparison) {
    comparison.cartesianFieldMillis = comparisonCartesianNanos / 1000000L;
    comparison.intrinsicFieldMillis = comparisonIntrinsicNanos / 1000000L;
    comparison.mappingMillis = comparisonMappingNanos / 1000000L;
    int[] cartStats = dcrteBooleanVolumeComponentStats(comparisonCartesian, spec);
    int[] intrinsicStats = dcrteBooleanVolumeComponentStats(comparisonIntrinsic, spec);
    comparison.cartesianComponents = cartStats[0];
    comparison.intrinsicComponents = intrinsicStats[0];
    comparison.cartesianLargestComponentFraction = cartStats[2] == 0 ? 0 : cartStats[1] / (float)cartStats[2];
    comparison.intrinsicLargestComponentFraction = intrinsicStats[2] == 0 ? 0 : intrinsicStats[1] / (float)intrinsicStats[2];
    comparison.cartesianSolidFraction = comparison.admittedVoxelCount == 0 ? 0
      : comparison.cartesianFinalCount / (float)comparison.admittedVoxelCount;
    comparison.intrinsicSolidFraction = comparison.admittedVoxelCount == 0 ? 0
      : comparison.intrinsicFinalCount / (float)comparison.admittedVoxelCount;
    comparison.cartesianFinalMask = comparisonCartesian;
    comparison.intrinsicFinalMask = comparisonIntrinsic;
    comparison.intrinsicBuildMillis = dcrteIntrinsicLastBuildMillis;
    if (dcrteIntrinsicBuildResult != null && dcrteIntrinsicBuildResult.validation != null) {
      comparison.ambiguityFraction = dcrteIntrinsicBuildResult.validation.ambiguityFraction;
      comparison.fallbackFraction = dcrteIntrinsicBuildResult.validation.fallbackFraction;
      comparison.meanConfidence = dcrteIntrinsicBuildResult.validation.meanConfidence;
    }
    dcrteCoordinateComparisonReport = comparison;
  } else dcrteCoordinateComparisonReport = null;
  if (dcrteIntrinsicBuildResult != null && dcrteIntrinsicBuildResult.validation != null) {
    IntrinsicValidationReport intrinsicValidation = dcrteIntrinsicBuildResult.validation;
    intrinsicValidation.appliedFallbackVoxels = selectedFallbackCount;
    intrinsicValidation.appliedFallbackFraction = volume.admittedCount == 0
      ? 0 : selectedFallbackCount / (float)volume.admittedCount;
    if (intrinsicValidation.appliedFallbackFraction > 0.01f) {
      intrinsicValidation.error(DCRTEIntrinsicCodes.IC_FALLBACK_FRACTION_HIGH);
      intrinsicValidation.finalizeStatus();
      report.addError(DCRTEIntrinsicCodes.IC_FALLBACK_FRACTION_HIGH);
      dcrteLastValidationReport = report;
      dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
      dcrteImportedStatus = "intrinsic materialization blocked - fallback threshold exceeded";
      foundryStatus = dcrteImportedStatus;
      runDcrteImportedPreflightWithDerived(true, false);
      return;
    }
  }
  volume.recountFinal();
  dcrteLastDomain = dcrteImportedDomain;
  dcrteLastObserver = observer;
  dcrteLastObservation = observation;
  if (!dcrtePrepareSchedulerForVolume(volume, dcrteImportedDomain, observer, buildConfig)) {
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "scheduler initialization failed";
    foundryStatus = dcrteImportedStatus;
    return;
  }
  long materializeStart = millis();
  boolean materializerSucceeded = dcrteLegacyMaterializer.materialize(volume);
  report.materializeMillis = millis() - materializeStart;
  dcrteRecordExternalMaterialization(report.materializeMillis);

  dcrteImportedVolume = volume;
  validateDcrteVolume(report, volume, dcrteImportedDomain, materializerSucceeded);
  report.totalMillis = millis() - totalStart;
  dcrteLastBuildMillis = report.totalMillis;
  dcrteImportedLastBuildConfiguration = buildConfig;
  dcrteLastBuildConfiguration = buildConfig;
  dcrteImportedStale = false;
  foundryMeshStale = false;

  if (report.status == ValidationStatus.FAIL) {
    dcrteImportedBuildState = DCRTEImportedBuildState.SDF_FAILED;
    dcrteImportedStatus = "imported material validation failed";
    foundryStatus = dcrteImportedStatus;
  } else {
    dcrteImportedBuildState = DCRTEImportedBuildState.READY;
    dcrteImportedStatus = report.status == ValidationStatus.PASS_WITH_WARNINGS
      ? "imported material ready with warnings"
      : "imported material ready";
    foundryStatus = dcrteImportedStatus + " " + foundryMesh.tris.size() + " tris";
  }
  runDcrteImportedPreflightWithDerived(true, true);
}

void generateDcrtePrimitiveSurfaceMesh() {
  long totalStart = millis();
  dcrteBuildStage = "BUILDING DOMAIN";
  dcrtePrimitiveStale = true;
  foundryMeshStale = true;
  foundryLastExport = "";

  VolumeSpec spec = createDcrteVolumeSpec();
  UniformGridObserver observer = new UniformGridObserver();
  observer.initialize(spec);
  ObservationDomain domain = createDcrteObservationDomain();
  ObservationLayer observation = createDcrteObservationLayer(spec);
  DCRTEValidationReport report = validateDcrteConfiguration(domain, observer, observation);
  if (report.status == ValidationStatus.FAIL) {
    dcrteLastValidationReport = report;
    dcrteBuildStage = "VALIDATION FAIL";
    foundryStatus = "primitive configuration invalid";
    return;
  }

  DCRTEVolume volume;
  try {
    volume = new DCRTEVolume(spec);
  }
  catch (OutOfMemoryError error) {
    report.addError("VOLUME_ALLOCATION_FAILED");
    dcrteLastValidationReport = report;
    dcrteBuildStage = "ALLOCATION FAIL";
    foundryStatus = "primitive volume allocation failed";
    return;
  }

  DCRTEConfig buildConfig = captureDcrteConfig();
  if (dcrteFieldEngine == null) dcrteFieldEngine = new LegacyTopologyScalarAdapter();
  dcrteFieldEngine.configure(buildConfig);
  float[] scores = buildConfig.topologyBlendCopy();
  DomainSample domainSample = new DomainSample();
  ObservationSample observationSample = new ObservationSample();

  long domainNanos = 0;
  long fieldNanos = 0;
  dcrteBuildStage = "SAMPLING FIELD";
  for (int z = 0; z < spec.nz; z++) {
    float wz = observer.worldZ(z);
    for (int y = 0; y < spec.ny; y++) {
      float wy = observer.worldY(y);
      for (int x = 0; x < spec.nx; x++) {
        int idx = observer.index(x, y, z);
        float wx = observer.worldX(x);
        long domainTick = System.nanoTime();
        domain.sample(wx, wy, wz, domainSample);
        if (domainSample.inside) volume.domainInsideCount++;
        observation.observe(domainSample, observationSample);
        volume.admitted[idx] = observationSample.admitted;
        if (observationSample.admitted) volume.admittedCount++;
        domainNanos += System.nanoTime() - domainTick;

        long fieldTick = System.nanoTime();
        float scalarValue = dcrteSampleFoundryField(wx, wy, wz, scores);
        volume.scalar[idx] = scalarValue;
        if (!dcrteFinite(scalarValue)) {
          volume.nonFiniteScalarCount++;
          if (volume.firstNonFiniteIndex < 0) {
            volume.firstNonFiniteIndex = idx;
            volume.firstNonFiniteX = wx;
            volume.firstNonFiniteY = wy;
            volume.firstNonFiniteZ = wz;
          }
        }

        boolean candidate = dcrteFinite(scalarValue) && legacyCandidateSolid(scalarValue);
        volume.candidateSolid[idx] = candidate;
        if (candidate) volume.candidateSolidCount++;
        boolean active = dcrteImmediateScheduler.activate(observationSample.admitted, candidate);
        volume.active[idx] = active;
        volume.finalSolid[idx] = active;
        fieldNanos += System.nanoTime() - fieldTick;
      }
    }
  }
  report.domainBuildMillis = domainNanos / 1000000L;
  report.fieldSampleMillis = fieldNanos / 1000000L;

  dcrteBuildStage = "APPLYING OBSERVATION";
  volume.recountFinal();
  dcrteLastDomain = domain;
  dcrteLastObserver = observer;
  dcrteLastObservation = observation;
  if (!dcrtePrepareSchedulerForVolume(volume, domain, observer, buildConfig)) {
    dcrteBuildStage = "SCHEDULER FAIL";
    foundryStatus = "scheduler initialization failed";
    return;
  }
  long materializeStart = millis();
  dcrteBuildStage = "MATERIALIZING";
  boolean materializerSucceeded = dcrteLegacyMaterializer.materialize(volume);
  report.materializeMillis = millis() - materializeStart;
  dcrteRecordExternalMaterialization(report.materializeMillis);

  dcrteBuildStage = "VALIDATING";
  dcrtePrimitiveVolume = volume;
  validateDcrteVolume(report, volume, domain, materializerSucceeded);
  report.totalMillis = millis() - totalStart;
  dcrteLastBuildMillis = report.totalMillis;
  dcrteLastBuildConfiguration = buildConfig;
  dcrtePrimitiveStale = false;
  foundryMeshStale = false;

  if (report.status == ValidationStatus.FAIL) {
    dcrteBuildStage = "VALIDATION FAIL";
    foundryStatus = "primitive validation failed";
  } else if (report.status == ValidationStatus.PASS_WITH_WARNINGS) {
    dcrteBuildStage = "READY";
    foundryStatus = "primitive ready with warnings";
  } else {
    dcrteBuildStage = "READY";
    foundryStatus = "primitive ready " + foundryMesh.tris.size() + " tris";
  }
}

boolean foundryRaisedVeinsApplied() {
  return foundryRaisedVeins
    && dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE
    && dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH;
}

String dcrteRaisedVeinsPolicy() {
  if (dcrteSchedulerController != null && dcrteSchedulerController.state != null
      && dcrteSchedulerController.state.runState != SchedulerRunState.COMPLETE) {
    return "disabled_for_partial_scheduler_state";
  }
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return "disabled_until_imported_sdf_clipping";
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE) return "legacy_behavior";
  return "disabled_until_domain_clipping";
}

String dcrteBaseRaisedVeinsPolicy() {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return "disabled_until_imported_sdf_clipping";
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) return "disabled_until_domain_clipping";
  return "legacy_behavior";
}
