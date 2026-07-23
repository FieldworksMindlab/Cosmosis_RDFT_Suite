/* M6-HX evidence export. Every artifact carries the paper citation and nonclaim scope. */

void exportDcrteHbeReport() {
  CandidateVolumeSnapshot candidate = dcrteSchedulerController == null
    ? null : dcrteSchedulerController.snapshot;
  if (!dcrteHbeEnabled || dcrteHbeSnapshot == null
      || !dcrteHbeSnapshot.matches(candidate)) {
    dcrteHbeStatus = "HBE export requires a current frozen experiment snapshot"; return;
  }
  if (dcrteHbeActiveConnectivity == null) runDcrteHbeAnalysis();
  try {
    String stamp = dcrteSchedulerFileStamp();
    String shortHash = dcrteHbeSnapshot.contentHash.length() < 10
      ? dcrteHbeSnapshot.contentHash : dcrteHbeSnapshot.contentHash.substring(0, 10);
    File directory = new File(sketchPath("exports/hbe/" + stamp + "_" + shortHash));
    if (!directory.exists() && !directory.mkdirs()) throw new Exception("unable to create HBE export directory");
    JSONObject root = new JSONObject();
    root.setString("schema", "dcrte-hbe-experiment-1.0");
    root.setString("generated_at", stamp); root.setString("output_directory", directory.getAbsolutePath());
    root.setJSONObject("exploratory_layer", dcrteHbeProvenanceJSON());
    root.setString("citation", DCRTE_HBE_CITATION); root.setString("nonclaim", DCRTE_HBE_NONCLAIM);
    root.setJSONObject("experiment_snapshot", dcrteHbeSnapshot.toJSON());
    root.setJSONObject("field_sensitivity", dcrteHbeFieldSensitivity.toJSON());
    root.setJSONObject("seed_selection", dcrteHbeSeedSelection.toJSON());
    if (dcrteHbeActiveConnectivity != null)
      root.setJSONObject("active_connectivity", dcrteHbeActiveConnectivity.toJSON());
    if (dcrteHbeActivePairing != null)
      root.setJSONObject("active_graph_pairing", dcrteHbeActivePairing.toJSON());
    root.setJSONObject("connection_event", dcrteHbeConnectionEvent.toJSON());
    if (dcrteSchedulerController != null) root.setJSONObject("scheduler", dcrteSchedulerController.toJSON());
    if (dcrteHbeLastSweep != null) root.setJSONObject("latest_sweep", dcrteHbeLastSweep.toJSON());
    root.setBoolean("actual_quantum_code", false); root.setBoolean("actual_wormhole_geometry", false);
    saveJSONObject(root, new File(directory, "hbe_manifest.json").getAbsolutePath());
    dcrteHbeWriteMetricsCsv(new File(directory, "hbe_voxel_metrics.csv"));
    dcrteHbeWriteConnectionPathCsv(new File(directory, "hbe_connection_path.csv"));
    if (dcrteHbeLastSweep != null) dcrteHbeWriteSweepEvidence(directory);
    dcrteHbeLastExport = directory.getAbsolutePath();
    dcrteHbeStatus = "HBE evidence exported with citation and nonclaim metadata";
  } catch (Exception error) {
    dcrteHbeState = HBEState.FAILED;
    dcrteHbeStatus = "HBE export failed safely: "
      + (error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage());
  }
}

void dcrteHbeWriteMetricsCsv(File file) {
  PrintWriter out = createWriter(file.getAbsolutePath());
  out.println("state,occupied_voxels,components,largest_component_fraction,left_fraction,right_fraction,bilateral_balance,neck_voxels,minimum_neck_cross_section,bottleneck_s,connected,path_steps,path_world_proxy,path_tortuosity,mirror_agreement,mirror_jaccard,mirror_arrival_mean,analysis_sha256,citation,nonclaim");
  dcrteHbeWriteMetricRow(out, "candidate", dcrteHbeSnapshot.candidateConnectivity);
  dcrteHbeWriteMetricRow(out, "active", dcrteHbeActiveConnectivity);
  out.flush(); out.close();
}

void dcrteHbeWriteMetricRow(PrintWriter out, String state, HBEConnectivityReport r) {
  if (r == null) return;
  out.println(state + "," + r.occupiedCount + "," + r.componentCount + ","
    + dcrteCsvFloat(r.largestComponentFraction) + "," + dcrteCsvFloat(r.leftOccupiedFraction) + ","
    + dcrteCsvFloat(r.rightOccupiedFraction) + "," + dcrteCsvFloat(r.bilateralBalance) + ","
    + r.neckOccupiedCount + "," + r.minimumNeckCrossSection + "," + dcrteCsvFloat(r.neckBottleneckS) + ","
    + r.connected + "," + r.shortestPathSteps + "," + dcrteCsvFloat(r.shortestPathWorld) + ","
    + dcrteCsvFloat(r.pathTortuosity) + "," + dcrteCsvFloat(r.mirrorAgreement) + ","
    + dcrteCsvFloat(r.mirrorJaccard) + "," + dcrteCsvFloat(r.mirrorArrivalMean) + ","
    + r.analysisHash + ",\"Biswas et al. 2026 arXiv:2607.12047\",\"classical graph proxy; not a wormhole or geodesic\"");
}

void dcrteHbeWriteConnectionPathCsv(File file) {
  PrintWriter out = createWriter(file.getAbsolutePath());
  out.println("state,order,voxel_index,x,y,z,intrinsic_xi,intrinsic_rho,intrinsic_theta,world_step_proxy");
  dcrteHbeWritePathRows(out, "candidate", dcrteHbeSnapshot.candidateConnectivity);
  dcrteHbeWritePathRows(out, "active", dcrteHbeActiveConnectivity);
  out.flush(); out.close();
}

void dcrteHbeWritePathRows(PrintWriter out, String state, HBEConnectivityReport r) {
  if (r == null || r.shortestPath == null || dcrteHbeSnapshot == null) return;
  VolumeSpec spec = dcrteHbeSnapshot.observables.spec;
  for (int p = 0; p < r.shortestPath.length; p++) {
    int i = r.shortestPath[p], xx = i % spec.nx;
    int yy = (i / spec.nx) % spec.ny, z = i / (spec.nx * spec.ny);
    out.println(state + "," + p + "," + i + "," + xx + "," + yy + "," + z + ","
      + dcrteCsvFloat(dcrteHbeSnapshot.observables.xi[i]) + ","
      + dcrteCsvFloat(dcrteHbeSnapshot.observables.rho[i]) + ","
      + dcrteCsvFloat(dcrteHbeSnapshot.observables.theta[i]) + ","
      + dcrteCsvFloat(p * spec.minSpacing()));
  }
}

void dcrteHbeWriteSweepEvidence(File directory) {
  dcrteHbeLastSweep.outputDirectory = directory.getAbsolutePath();
  saveJSONObject(dcrteHbeLastSweep.toJSON(),
    new File(directory, "hbe_sweep_manifest.json").getAbsolutePath());
  PrintWriter out = createWriter(new File(directory, "hbe_sweep_results.csv").getAbsolutePath());
  out.println("coupling_index,feedback_index,coupling_analog,feedback_analog,candidate_voxels,changed_to_candidate,changed_from_candidate,candidate_connected,component_count,minimum_neck_cross_section,bottleneck_fraction,candidate_sha256,cell_sha256,runtime_millis,failure");
  JSONArray failures = new JSONArray(); int failureIndex = 0;
  for (int i = 0; i < dcrteHbeLastSweep.cells.size(); i++) {
    HBESweepCell c = dcrteHbeLastSweep.cells.get(i);
    out.println(c.eIndex + "," + c.mIndex + "," + c.coupling + "," + c.feedback + ","
      + c.candidateCount + "," + c.changedTo + "," + c.changedFrom + ","
      + c.candidateConnected + "," + c.components + "," + c.minimumNeckCrossSection + ","
      + c.bottleneckFraction + "," + c.candidateHash + "," + c.cellHash + ","
      + c.runtimeMillis + ",\"" + c.failure.replace("\"", "'") + "\"");
    if (c.failure.length() > 0) failures.setJSONObject(failureIndex++, c.toJSON());
  }
  out.flush(); out.close();
  JSONObject failureRoot = new JSONObject(); failureRoot.setString("schema", "dcrte-hbe-sweep-failures-1.0");
  failureRoot.setJSONObject("exploratory_layer", dcrteHbeProvenanceJSON());
  failureRoot.setInt("failure_count", failures.size()); failureRoot.setJSONArray("failures", failures);
  saveJSONObject(failureRoot, new File(directory, "hbe_sweep_failures.json").getAbsolutePath());
}
