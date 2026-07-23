/* DCRTE-ET Milestone 4 application controller and materializer adapter. */

class SchedulerController {
  SchedulerConfiguration configuration = new SchedulerConfiguration();
  CandidateVolumeSnapshot snapshot;
  SchedulerContext context;
  PropagationState state;
  SchedulerDiagnostics diagnostics = new SchedulerDiagnostics();
  ArrayList<SchedulerHistoryEntry> history = new ArrayList<SchedulerHistoryEntry>();
  FieldScheduler scheduler;
  boolean running;
  int batchesPerRenderFrame = 1;
  int selectedArrivalBatch;
  int materializedBatch = -1;
  String materializedStateHash = "";
  String metricsCsvPath = "";
  String arrivalDescriptorPath = "";
  String schedulerRunJsonPath = "";
  String lastExportDirectory = "";
  String lastExportStamp = "";
  String invalidationReason = "";

  FieldScheduler selectedScheduler() {
    if (configuration.mode == SchedulerMode.EMERGENT_ENTROPIC)
      return new EmergentEntropicScheduler();
    return configuration.mode == SchedulerMode.FRONT_PROPAGATION
      ? new FrontPropagationScheduler() : dcrteImmediateScheduler;
  }

  EmergentEntropicScheduler entropicScheduler() {
    return scheduler instanceof EmergentEntropicScheduler
      ? (EmergentEntropicScheduler)scheduler : null;
  }

  void refreshStateHash() {
    if (state == null || context == null || scheduler == null) return;
    EmergentEntropicScheduler entropic = entropicScheduler();
    state.stateHash = entropic == null
      ? dcrteSchedulerStateHash(context, state, scheduler.getId(), scheduler.getVersion())
      : entropic.entropicStateHash(context, state);
  }

  boolean capture(DCRTEVolume volume, ObservationDomain domain, UniformGridObserver observer,
      SignedDistanceVolume sdf, IntrinsicCoordinateVolume intrinsic, DCRTEConfig config) {
    invalidateDcrteComposition("scheduler candidate snapshot replaced");
    snapshot = new CandidateVolumeSnapshot(volume, domain, observer, sdf, intrinsic, config);
    HBEExperimentSnapshot hbe = dcrteHbeSnapshotForCandidate(snapshot);
    context = new SchedulerContext(snapshot, configuration, hbe);
    state = new PropagationState(snapshot == null || snapshot.spec == null ? 0 : snapshot.spec.voxelCount());
    diagnostics = new SchedulerDiagnostics(); history.clear(); running = false;
    selectedArrivalBatch = 0; materializedBatch = -1; materializedStateHash = ""; invalidationReason = "";
    metricsCsvPath = ""; arrivalDescriptorPath = ""; schedulerRunJsonPath = "";
    lastExportDirectory = ""; lastExportStamp = "";
    scheduler = selectedScheduler();
    boolean initialized = scheduler.initialize(context, state, diagnostics);
    if (initialized) {
      state.runState = state.runState == SchedulerRunState.COMPLETE ? SchedulerRunState.COMPLETE : SchedulerRunState.PAUSED;
      refreshStateHash();
      dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
      history.add(dcrteBuildSchedulerHistory(context, state, context.resolvedSeeds, "initialize"));
      applyStateToVolume(volume, state.active);
      dcrteHbeOnSchedulerStep();
    }
    return initialized;
  }

  void applyStateToVolume(DCRTEVolume volume, boolean[] mask) {
    if (volume == null || !volume.isValid() || mask == null || mask.length != volume.active.length) return;
    for (int i = 0; i < mask.length; i++) {
      boolean value = mask[i] && snapshot.admitted[i] && snapshot.candidateSolid[i];
      volume.active[i] = value; volume.finalSolid[i] = value;
    }
    volume.recountFinal();
  }

  boolean initializeCurrent() {
    DCRTEVolume volume = dcrteSchedulerActiveVolume();
    if (snapshot == null || volume == null) { foundryStatus = "generate candidate volume before scheduler initialize"; return false; }
    invalidateDcrteComposition("scheduler state reinitialized");
    HBEExperimentSnapshot hbe = dcrteHbeSnapshotForCandidate(snapshot);
    context = new SchedulerContext(snapshot, configuration, hbe);
    state = new PropagationState(snapshot.spec.voxelCount());
    diagnostics = new SchedulerDiagnostics(); history.clear(); scheduler = selectedScheduler();
    running = false; materializedBatch = -1; materializedStateHash = ""; invalidationReason = "";
    metricsCsvPath = ""; arrivalDescriptorPath = ""; schedulerRunJsonPath = "";
    lastExportDirectory = ""; lastExportStamp = "";
    boolean ok = scheduler.initialize(context, state, diagnostics);
    if (ok) {
      state.runState = state.runState == SchedulerRunState.COMPLETE ? SchedulerRunState.COMPLETE : SchedulerRunState.PAUSED;
      refreshStateHash();
      dcrteUpdateSchedulerDiagnostics(context, state, diagnostics);
      history.add(dcrteBuildSchedulerHistory(context, state, context.resolvedSeeds, "initialize"));
      applyStateToVolume(volume, state.active); selectedArrivalBatch = state.batchIndex;
      dcrteHbeOnSchedulerStep();
      markFoundryStale(); foundryStatus = "scheduler initialized; materialize current when ready";
    }
    return ok;
  }

  SchedulerBatch stepOnce() {
    if (scheduler == null || context == null || state == null) { diagnostics.error("SCH_NOT_INITIALIZED", "controller", "Scheduler has not been initialized", 0, -1, "generate candidate volume and initialize"); return new SchedulerBatch(); }
    if (state.runState == SchedulerRunState.INVALIDATED) return new SchedulerBatch();
    SchedulerBatch batch = scheduler.step(context, state, diagnostics);
    dcrteHbeOnSchedulerStep();
    selectedArrivalBatch = state.batchIndex;
    if (batch.acceptedUpdates > 0) {
      invalidateDcrteComposition("scheduler advanced to batch " + state.batchIndex);
      history.add(dcrteBuildSchedulerHistory(context, state, batch.activatedIndices, batch.event));
      if (materializedBatch >= 0) {
        foundryMeshStale = true; foundryCallSheetSolid = null;
        diagnostics.warn(DCRTESchedulerCodes.MATERIALIZER_STALE, "materializer",
          "Scheduler advanced beyond the materialized mesh", 1, -1, "materialize the selected scheduler state");
        foundryStatus = "scheduler advanced; materialized mesh stale";
      }
    }
    if (state.runState == SchedulerRunState.COMPLETE || state.runState == SchedulerRunState.STOPPED || state.runState == SchedulerRunState.FAILED) running = false;
    return batch;
  }

  void run() {
    if (state == null || state.runState == SchedulerRunState.INVALIDATED
        || state.runState == SchedulerRunState.FAILED
        || state.runState == SchedulerRunState.COMPLETE
        || state.runState == SchedulerRunState.STOPPED) return;
    running = true; state.runState = SchedulerRunState.RUNNING; diagnostics.runState = state.runState;
  }
  void pause() { running = false; if (state != null && state.runState == SchedulerRunState.RUNNING) state.runState = SchedulerRunState.PAUSED; }
  void stop() { running = false; if (state != null) { state.runState = SchedulerRunState.STOPPED; state.stopReason = SchedulerStopReason.USER_STOPPED; dcrteUpdateSchedulerDiagnostics(context, state, diagnostics); } }
  void reset() { initializeCurrent(); }
  void complete() {
    if (state == null || state.runState == SchedulerRunState.INVALIDATED || state.runState == SchedulerRunState.FAILED) return;
    running = false; int guard = max(1, configuration.maximumBatches - state.batchIndex + 1);
    while (state.runState != SchedulerRunState.COMPLETE && state.runState != SchedulerRunState.STOPPED
        && state.runState != SchedulerRunState.FAILED && guard-- > 0) stepOnce();
  }
  void updateRenderBudget() {
    if (!running || state == null) return;
    for (int i = 0; i < max(1, batchesPerRenderFrame) && running; i++) stepOnce();
  }

  void invalidate(String reason) {
    if (state == null || state.runState == SchedulerRunState.NOT_INITIALIZED) return;
    running = false; invalidationReason = reason == null ? "upstream configuration changed" : reason;
    state.runState = SchedulerRunState.INVALIDATED; state.stopReason = SchedulerStopReason.CONFIGURATION_STALE;
    diagnostics.runState = state.runState; diagnostics.stopReason = state.stopReason;
    diagnostics.error("SCH_CONFIGURATION_STALE", "invalidation", invalidationReason, 1, -1, "rebuild candidate volume and reset scheduler");
  }

  boolean canMaterialize() {
    return snapshot != null && snapshot.valid && state != null
      && state.runState != SchedulerRunState.INVALIDATED && state.runState != SchedulerRunState.FAILED
      && state.activeCount > 0;
  }
  boolean canExportCurrentMesh() {
    return canMaterialize() && materializedBatch == state.batchIndex
      && materializedStateHash.equals(state.stateHash) && !foundryMeshStale;
  }

  int baselineMismatchCount() {
    if (snapshot == null || state == null || snapshot.candidateSolid.length != state.active.length) return -1;
    int mismatches = 0;
    for (int i = 0; i < state.active.length; i++) if (state.active[i] != snapshot.candidateSolid[i]) mismatches++;
    return mismatches;
  }

  int illegalActivationCount() {
    if (snapshot == null || state == null || snapshot.candidateSolid.length != state.active.length) return -1;
    int violations = 0;
    for (int i = 0; i < state.active.length; i++) if (state.active[i]
        && (!snapshot.admitted[i] || !snapshot.candidateSolid[i])) violations++;
    return violations;
  }

  int pendingCandidateCount() {
    if (snapshot == null || state == null) return -1;
    return max(0, snapshot.candidateCount - state.activeCount);
  }

  JSONObject baselineComparisonToJSON() {
    JSONObject json = new JSONObject();
    json.setString("baseline", "m3_static_candidate_mask");
    json.setString("layer", configuration.mode == SchedulerMode.EMERGENT_ENTROPIC
      ? "m5_entropic_scheduler_activation_order"
      : "m4_scheduler_activation_order");
    json.setInt("candidate_count", snapshot == null ? 0 : snapshot.candidateCount);
    json.setInt("active_count", state == null ? 0 : state.activeCount);
    json.setInt("pending_candidate_count", max(0, pendingCandidateCount()));
    json.setInt("mask_mismatch_count", max(0, baselineMismatchCount()));
    json.setInt("illegal_activation_count", max(0, illegalActivationCount()));
    json.setBoolean("complete_equivalence", state != null
      && state.runState == SchedulerRunState.COMPLETE && baselineMismatchCount() == 0);
    return json;
  }

  boolean materializeCurrent() {
    if (!canMaterialize()) { foundryStatus = "scheduler materialization blocked"; return false; }
    DCRTEVolume volume = dcrteSchedulerActiveVolume();
    if (volume == null) return false;
    long started = millis(); applyStateToVolume(volume, state.active);
    boolean succeeded = dcrteLegacyMaterializer.materialize(volume);
    diagnostics.materializationMillis = millis() - started;
    DCRTEValidationReport report = dcrteLastDomain != null && dcrteLastObserver != null && dcrteLastObservation != null
      ? validateDcrteConfiguration(dcrteLastDomain, dcrteLastObserver, dcrteLastObservation)
      : new DCRTEValidationReport();
    validateDcrteVolume(report, volume, dcrteLastDomain, succeeded);
    dcrteLastValidationReport = report;
    materializedBatch = state.batchIndex; materializedStateHash = state.stateHash;
    foundryMeshStale = !succeeded;
    if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) dcrtePrimitiveStale = false;
    if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) dcrteImportedStale = false;
    foundryStatus = succeeded ? "scheduler batch " + state.batchIndex + " materialized" : "scheduler materializer audit failed";
    return succeeded;
  }

  boolean materializeComplete() { complete(); return state != null && state.runState == SchedulerRunState.COMPLETE && materializeCurrent(); }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", scheduler == null ? configuration.mode.id() : scheduler.getId());
    json.setString("version", scheduler == null ? "1.0-m4" : scheduler.getVersion());
    json.setBoolean("deterministic", true); json.setJSONObject("configuration", configuration.toJSON());
    if (scheduler != null) json.setJSONObject("scheduler_detail", scheduler.toJSON());
    if (snapshot != null) json.setJSONObject("candidate_snapshot", snapshot.toJSON());
    if (context != null) {
      JSONArray seeds = new JSONArray(); for (int i = 0; i < context.resolvedSeeds.length; i++) seeds.setInt(i, context.resolvedSeeds[i]);
      json.setJSONArray("resolved_seed_indices", seeds); json.setInt("candidate_components", context.candidateComponentCount);
    }
    if (state != null) {
      json.setJSONObject("state", state.toJSON());
      json.setInt("unreachable_count", snapshot == null ? 0 : state.unreachableCount(snapshot));
      json.setFloat("activation_progress", snapshot == null || snapshot.candidateCount == 0 ? 0 : state.activeCount / (float)snapshot.candidateCount);
      json.setBoolean("partial", state.runState != SchedulerRunState.COMPLETE);
      json.setString("arrival_convention", "seed_batch_zero; committed_frontier_batches_positive; never_activated_minus_one");
    }
    json.setInt("materialized_batch", materializedBatch); json.setString("materialized_state_hash", materializedStateHash);
    json.setBoolean("mesh_current", canExportCurrentMesh()); json.setString("metrics_csv", metricsCsvPath);
    json.setString("history_csv", metricsCsvPath);
    json.setString("arrival_descriptor", arrivalDescriptorPath);
    json.setString("scheduler_run_json", schedulerRunJsonPath);
    json.setString("export_directory", lastExportDirectory);
    json.setString("export_stamp", lastExportStamp);
    json.setBoolean("arrival_order_exported", arrivalDescriptorPath.length() > 0);
    json.setJSONObject("baseline_comparison", baselineComparisonToJSON());
    int relocations = 0;
    for (int i = 0; i < diagnostics.issues.size(); i++) if (diagnostics.issues.get(i).code.equals(DCRTESchedulerCodes.SEED_RELOCATED)) relocations++;
    json.setInt("seed_relocations", relocations);
    json.setJSONObject("diagnostics", diagnostics.toJSON());
    JSONArray historyJson = new JSONArray(); for (int i = 0; i < history.size(); i++) historyJson.setJSONObject(i, history.get(i).toJSON());
    json.setJSONArray("history", historyJson); return json;
  }

  void exportMetrics() {
    EmergentEntropicScheduler entropic = entropicScheduler();
    if (history.size() == 0 && (entropic == null || entropic.entropicHistory.size() == 0)) {
      foundryStatus = "scheduler history is empty";
      return;
    }
    String stamp = dcrteSchedulerFileStamp();
    String runDir = lastExportDirectory.length() > 0
      ? lastExportDirectory : schedulerExportDirectory(stamp);
    ensureDir(sketchPath("exports/scheduler"));
    ensureDir(sketchPath(runDir));
    lastExportDirectory = runDir;
    if (lastExportStamp.length() == 0) lastExportStamp = stamp;
    if (entropic != null) {
      entropic.exportEntropicMetrics(runDir);
      entropic.exportScoreSamples(runDir);
    }
    metricsCsvPath = runDir + "/scheduler_metrics.csv";
    PrintWriter out = createWriter(metricsCsvPath);
    out.println("batch_index,newly_activated,active_count,frontier_count,remaining_candidates,active_fraction,mean_new_field,mean_active_field,mean_new_sdf,mean_active_sdf,mean_new_intrinsic_s,mean_new_intrinsic_rho,mean_coordinate_confidence,active_components,state_hash,event");
    for (int i = 0; i < history.size(); i++) {
      SchedulerHistoryEntry e = history.get(i);
      out.println(e.batchIndex + "," + e.newlyActivated + "," + e.activeCount + "," + e.frontierCount + "," + e.remainingCandidateCount + "," + e.activeFraction
        + "," + dcrteCsvFloat(e.meanNewField) + "," + dcrteCsvFloat(e.meanActivatedField) + "," + dcrteCsvFloat(e.meanNewSDF) + "," + dcrteCsvFloat(e.meanActivatedSDF)
        + "," + dcrteCsvFloat(e.meanNewIntrinsicS) + "," + dcrteCsvFloat(e.meanNewIntrinsicRho) + "," + dcrteCsvFloat(e.meanCoordinateConfidence)
        + "," + e.activeComponentCount + "," + e.stateHash + "," + e.event);
    }
    out.flush(); out.close(); exportArrivalOrder(runDir);
    schedulerRunJsonPath = runDir + "/scheduler_run.json";
    saveJSONObject(toJSON(), schedulerRunJsonPath);
    saveJSONObject(exportManifest(entropic), runDir + "/manifest.json");
    foundryStatus = "scheduler run archived: " + new File(runDir).getName();
  }

  String schedulerExportDirectory(String stamp) {
    String mode = configuration == null || configuration.mode == null
      ? "scheduler" : configuration.mode.id();
    mode = mode.replaceAll("[^A-Za-z0-9_-]", "_");
    String stateTag = state == null || state.stateHash == null || state.stateHash.length() == 0
      ? "unhashed" : state.stateHash.substring(0, min(8, state.stateHash.length()));
    return "exports/scheduler/" + stamp + "_" + mode + "_" + stateTag;
  }

  JSONObject exportManifest(EmergentEntropicScheduler entropic) {
    JSONObject manifest = new JSONObject();
    manifest.setString("schema", "dcrte_scheduler_export_manifest_v1");
    manifest.setString("generated", lastExportStamp);
    manifest.setString("directory", lastExportDirectory);
    manifest.setString("mode", configuration == null || configuration.mode == null
      ? "unknown" : configuration.mode.id());
    manifest.setString("state_hash", state == null ? "" : state.stateHash);
    manifest.setString("candidate_hash", snapshot == null ? "" : snapshot.contentHash);
    manifest.setInt("batch_index", state == null ? -1 : state.batchIndex);
    manifest.setInt("active_count", state == null ? 0 : state.activeCount);
    manifest.setBoolean("materialized_current", canExportCurrentMesh());
    JSONArray files = new JSONArray();
    appendManifestFile(files, "scheduler_history", metricsCsvPath);
    appendManifestFile(files, "scheduler_run", schedulerRunJsonPath);
    appendManifestFile(files, "arrival_descriptor", arrivalDescriptorPath);
    if (arrivalDescriptorPath.length() > 0)
      appendManifestFile(files, "arrival_binary", lastExportDirectory + "/arrival_order.bin");
    if (entropic != null) {
      appendManifestFile(files, "entropic_metrics", entropic.metricsPath);
      appendManifestFile(files, "entropic_score_samples", entropic.scoreSamplePath);
    }
    manifest.setJSONArray("files", files);
    return manifest;
  }

  void appendManifestFile(JSONArray files, String role, String path) {
    if (path == null || path.length() == 0) return;
    JSONObject item = new JSONObject();
    item.setString("role", role);
    item.setString("path", path);
    File file = new File(sketchPath(path));
    item.setBoolean("exists", file.exists());
    item.setString("bytes", file.exists() ? Long.toString(file.length()) : "0");
    files.setJSONObject(files.size(), item);
  }

  void exportArrivalOrder(String runDir) {
    if (state == null || snapshot == null) return;
    String binaryPath = runDir + "/arrival_order.bin";
    try {
      java.io.DataOutputStream out = new java.io.DataOutputStream(new java.io.BufferedOutputStream(new java.io.FileOutputStream(sketchPath(binaryPath))));
      for (int i = 0; i < state.arrivalBatch.length; i++) out.writeInt(Integer.reverseBytes(state.arrivalBatch[i]));
      out.flush(); out.close();
      byte[] bytes = java.nio.file.Files.readAllBytes(new File(sketchPath(binaryPath)).toPath());
      JSONObject descriptor = new JSONObject(); descriptor.setString("format", "int32_little_endian");
      JSONArray shape = new JSONArray(); shape.setInt(0, snapshot.spec.nx); shape.setInt(1, snapshot.spec.ny); shape.setInt(2, snapshot.spec.nz);
      descriptor.setJSONArray("shape", shape); descriptor.setString("index_order", "x_plus_nx_times_y_plus_ny_times_z");
      descriptor.setInt("never_activated", -1); descriptor.setInt("seed_batch", 0); descriptor.setInt("max_batch", state.batchIndex);
      descriptor.setString("binary_file", binaryPath); descriptor.setString("sha256", dcrteSha256Bytes(bytes));
      arrivalDescriptorPath = runDir + "/arrival_order.json"; saveJSONObject(descriptor, arrivalDescriptorPath);
    } catch (Exception error) {
      diagnostics.error("SCH_INTERNAL_ERROR", "arrival_export", error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage(), 1, -1, "inspect logs directory permissions");
    }
  }
}

SchedulerController dcrteSchedulerController = new SchedulerController();

void initializeDcrteMilestone4() {
  dcrteM4Tests = runDcrteMilestone4Tests();
  println("DCRTE-ET Milestone 4 deterministic tests: " + dcrteM4Tests.status());
  for (int i = 0; i < dcrteM4Tests.failures.size(); i++) println("  FAIL " + dcrteM4Tests.failures.get(i));
}
void initializeDcrteMilestone5() {
  dcrteM5Tests = runDcrteMilestone5Tests();
  println("DCRTE-ET Milestone 5 deterministic tests: "
    + dcrteM5Tests.status());
  for (int i = 0; i < dcrteM5Tests.failures.size(); i++)
    println("  FAIL " + dcrteM5Tests.failures.get(i));
}
void dcrteUpdateSchedulerFrame() { if (dcrteSchedulerController != null) dcrteSchedulerController.updateRenderBudget(); }
void dcrteInvalidateScheduler(String reason) {
  if (dcrteSchedulerController != null) dcrteSchedulerController.invalidate(reason);
  invalidateDcrteComposition(reason);
}

boolean dcrtePrepareSchedulerForVolume(DCRTEVolume volume, ObservationDomain domain, UniformGridObserver observer, DCRTEConfig config) {
  SignedDistanceVolume sdf = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH ? dcrteImportedSdf : null;
  IntrinsicCoordinateVolume intrinsic = dcrteIntrinsicBuildResult == null ? null : dcrteIntrinsicBuildResult.volume;
  return dcrteSchedulerController.capture(volume, domain, observer, sdf, intrinsic, config);
}

void dcrteRecordExternalMaterialization(long millisTaken) {
  if (dcrteSchedulerController == null || dcrteSchedulerController.state == null) return;
  dcrteSchedulerController.materializedBatch = dcrteSchedulerController.state.batchIndex;
  dcrteSchedulerController.materializedStateHash = dcrteSchedulerController.state.stateHash;
  dcrteSchedulerController.diagnostics.materializationMillis = millisTaken;
}

DCRTEVolume dcrteSchedulerActiveVolume() {
  return dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH ? dcrteImportedVolume : dcrtePrimitiveVolume;
}

boolean dcrteSchedulerExportAllowed() {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_PRIMITIVE && dcrtePipelineMode != DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return true;
  return dcrteSchedulerController == null || dcrteSchedulerController.snapshot == null || dcrteSchedulerController.canExportCurrentMesh();
}

String dcrteSchedulerExportBlockMessage() {
  if (dcrteSchedulerController == null || dcrteSchedulerController.snapshot == null) return "";
  SchedulerController controller = dcrteSchedulerController;
  if (controller.state == null) return "blocked: initialize the scheduler, then materialize";
  if (controller.state.runState == SchedulerRunState.INVALIDATED)
    return "blocked: scheduler state invalidated; rebuild the candidate";
  if (controller.state.runState == SchedulerRunState.FAILED)
    return "blocked: scheduler failed; inspect scheduler diagnostics";
  if (!controller.canMaterialize()) return "blocked: scheduler has no active material to build";
  if (controller.materializedBatch != controller.state.batchIndex
      || !controller.materializedStateHash.equals(controller.state.stateHash))
    return "blocked: scheduler batch " + controller.state.batchIndex + " needs MATERIALIZE";
  if (foundryMeshStale) return "blocked: materialized mesh is stale; press MATERIALIZE";
  return "blocked: scheduler mesh is not current";
}

String dcrteSchedulerFileStamp() {
  return nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
}
String dcrteCsvFloat(Float value) { return value == null || !dcrteFinite(value.floatValue()) ? "" : Float.toString(value.floatValue()); }
