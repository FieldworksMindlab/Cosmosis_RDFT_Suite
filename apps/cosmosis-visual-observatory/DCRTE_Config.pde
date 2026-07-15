/*
  DCRTE-ET Milestone 0 configuration snapshot and provenance helpers.

  Configuration identity is derived from an explicitly ordered canonical
  string, not JSONObject serialization order.
*/

class DCRTEConfig {
  String schemaVersion = "0.4-m1";
  int dcrteMilestone = 1;
  String pipelineMode = "LEGACY_DIRECT";
  String fieldEngineId = "legacy_topology_scalar_direct";
  String fieldEngineVersion = "legacy-topology-scalar-v1";
  String configurationId = "";

  int seedValue;
  float simulationTime;
  float alphaValue;
  int depthValue;
  float sourceValue;
  float floquetValue;
  float quasiEnergyValue;
  float coherenceValue;
  float ctcBiasValue;
  float braneTwistValue;
  float deepDetailValue;
  float timeScaleValue;
  float recursionFalloffValue;
  float[] topologyBlend = new float[0];

  int foundryResolutionValue;
  float foundryIsoBandValue;
  float foundryScaleMMValue;
  int foundryGeometryIndexValue;
  String foundryGeometryNameValue = "";
  float foundryWrapBlendValue;
  boolean foundryRaisedVeinsValue;
  float foundryVeinRadiusMMValue;
  float foundryVeinLiftMMValue;

  boolean shaperEnabledValue;
  boolean shaperUseSenderValue;
  float shaperMixValue;
  float solarWindValue;
  float xrayFluxValue;
  float oceanCurrentValue;
  float tideValue;
  float galacticTorsionValue;
  float shaperPlasmaValue;
  float shaperWaterValue;
  float shaperCosmicValue;
  float shaperDriveValue;

  String materialSourceModeValue = "";
  int materialIndexValue;
  String materialTargetValue = "";
  String materialSourceIdValue = "";

  String primitiveDomainTypeValue = "none";
  float primitiveCenterXValue;
  float primitiveCenterYValue;
  float primitiveCenterZValue;
  float primitiveSphereRadiusValue;
  float primitiveBoxHalfXValue;
  float primitiveBoxHalfYValue;
  float primitiveBoxHalfZValue;
  float primitiveCylinderRadiusValue;
  float primitiveCylinderHalfHeightValue;
  int observerResolutionValue;
  float observerMinXValue;
  float observerMinYValue;
  float observerMinZValue;
  float observerMaxXValue;
  float observerMaxYValue;
  float observerMaxZValue;
  String observationModeValue = "none";
  float boundaryEpsilonValue;
  float shellThicknessValue;
  float shellThicknessVoxelsValue;
  String schedulerIdValue = "none";
  String materializerIdValue = "none";
  String raisedVeinsPolicyValue = "legacy_behavior";

  String importedSourceNameValue = "";
  String importedSourceFormatValue = "";
  String importedSourceHashValue = "";
  long importedSourceBytesValue;
  int importedParsedTrianglesValue;
  String importedPolicyValue = "strict";
  int importedResolutionValue;
  int importedRotateXValue;
  int importedRotateYValue;
  int importedRotateZValue;
  float importedFitMarginValue;
  float importedScaleMultiplierValue;
  float importedUniformScaleValue;
  boolean importedSdfSignedValue;
  String importedSdfAlgorithmValue = "none";
  float importedBoundaryThresholdValue;
  float importedIntersectionToleranceValue;
  float importedJitterMagnitudeValue;
  int importedBoundaryVoxelsValue;
  int importedInsideVoxelsValue;
  int importedFailedScanlinesValue;
  double importedVolumeErrorValue;
  String coordinateModeValue = "cartesian";
  String coordinateVersionValue = "1.0-m3";
  String coordinateMappingValue = "observer_world_identity";
  String coordinateRadialModelValue = "equivalent_circular";
  String coordinateFallbackPolicyValue = "block";
  String coordinateComparisonModeValue = "single";
  float coordinateLongitudinalScaleValue = 1.0f;
  float coordinateRadialScaleValue = 1.0f;
  String coordinateBuildStatusValue = "not_built";
  float coordinateValidFractionValue;
  float coordinateAmbiguityFractionValue;
  float coordinateFallbackFractionValue;
  float coordinateMeanConfidenceValue;

  float[] topologyBlendCopy() {
    float[] copy = new float[topologyBlend.length];
    System.arraycopy(topologyBlend, 0, copy, 0, topologyBlend.length);
    return copy;
  }

  void finalizeIdentity() {
    configurationId = dcrteSha256(canonicalString());
  }

  String canonicalString() {
    StringBuilder out = new StringBuilder();
    dcrteCanonical(out, "schema_version", schemaVersion);
    dcrteCanonical(out, "dcrte_milestone", dcrteMilestone);
    dcrteCanonical(out, "pipeline_mode", pipelineMode);
    dcrteCanonical(out, "field_engine_id", fieldEngineId);
    dcrteCanonical(out, "field_engine_version", fieldEngineVersion);
    dcrteCanonical(out, "seed", seedValue);
    dcrteCanonical(out, "simulation_time", simulationTime);
    dcrteCanonical(out, "alpha", alphaValue);
    dcrteCanonical(out, "depth", depthValue);
    dcrteCanonical(out, "source", sourceValue);
    dcrteCanonical(out, "floquet", floquetValue);
    dcrteCanonical(out, "quasi_energy", quasiEnergyValue);
    dcrteCanonical(out, "coherence", coherenceValue);
    dcrteCanonical(out, "ctc_bias", ctcBiasValue);
    dcrteCanonical(out, "brane_twist", braneTwistValue);
    dcrteCanonical(out, "deep_detail", deepDetailValue);
    dcrteCanonical(out, "time_scale", timeScaleValue);
    dcrteCanonical(out, "recursion_falloff", recursionFalloffValue);
    dcrteCanonical(out, "topology_blend", dcrteFloatArray(topologyBlend));
    dcrteCanonical(out, "foundry_resolution", foundryResolutionValue);
    dcrteCanonical(out, "foundry_iso_band", foundryIsoBandValue);
    dcrteCanonical(out, "foundry_scale_mm", foundryScaleMMValue);
    dcrteCanonical(out, "foundry_geometry_index", foundryGeometryIndexValue);
    dcrteCanonical(out, "foundry_geometry_name", foundryGeometryNameValue);
    dcrteCanonical(out, "foundry_wrap_blend", foundryWrapBlendValue);
    dcrteCanonical(out, "foundry_raised_veins", foundryRaisedVeinsValue);
    dcrteCanonical(out, "foundry_vein_radius_mm", foundryVeinRadiusMMValue);
    dcrteCanonical(out, "foundry_vein_lift_mm", foundryVeinLiftMMValue);
    dcrteCanonical(out, "shaper_enabled", shaperEnabledValue);
    dcrteCanonical(out, "shaper_use_sender", shaperUseSenderValue);
    dcrteCanonical(out, "shaper_mix", shaperMixValue);
    dcrteCanonical(out, "solar_wind", solarWindValue);
    dcrteCanonical(out, "xray_flux", xrayFluxValue);
    dcrteCanonical(out, "ocean_current", oceanCurrentValue);
    dcrteCanonical(out, "tide", tideValue);
    dcrteCanonical(out, "galactic_torsion", galacticTorsionValue);
    dcrteCanonical(out, "shaper_plasma", shaperPlasmaValue);
    dcrteCanonical(out, "shaper_water", shaperWaterValue);
    dcrteCanonical(out, "shaper_cosmic", shaperCosmicValue);
    dcrteCanonical(out, "shaper_drive", shaperDriveValue);
    dcrteCanonical(out, "material_source_mode", materialSourceModeValue);
    dcrteCanonical(out, "material_index", materialIndexValue);
    dcrteCanonical(out, "material_target", materialTargetValue);
    dcrteCanonical(out, "material_source_id", materialSourceIdValue);
    if (pipelineMode.equals("DCRTE_PRIMITIVE")) {
      dcrteCanonical(out, "primitive_domain_type", primitiveDomainTypeValue);
      dcrteCanonical(out, "primitive_center_x", primitiveCenterXValue);
      dcrteCanonical(out, "primitive_center_y", primitiveCenterYValue);
      dcrteCanonical(out, "primitive_center_z", primitiveCenterZValue);
      dcrteCanonical(out, "primitive_sphere_radius", primitiveSphereRadiusValue);
      dcrteCanonical(out, "primitive_box_half_x", primitiveBoxHalfXValue);
      dcrteCanonical(out, "primitive_box_half_y", primitiveBoxHalfYValue);
      dcrteCanonical(out, "primitive_box_half_z", primitiveBoxHalfZValue);
      dcrteCanonical(out, "primitive_cylinder_radius", primitiveCylinderRadiusValue);
      dcrteCanonical(out, "primitive_cylinder_half_height", primitiveCylinderHalfHeightValue);
      dcrteCanonical(out, "observer_resolution", observerResolutionValue);
      dcrteCanonical(out, "observer_min_x", observerMinXValue);
      dcrteCanonical(out, "observer_min_y", observerMinYValue);
      dcrteCanonical(out, "observer_min_z", observerMinZValue);
      dcrteCanonical(out, "observer_max_x", observerMaxXValue);
      dcrteCanonical(out, "observer_max_y", observerMaxYValue);
      dcrteCanonical(out, "observer_max_z", observerMaxZValue);
      dcrteCanonical(out, "observation_mode", observationModeValue);
      dcrteCanonical(out, "boundary_epsilon", boundaryEpsilonValue);
      dcrteCanonical(out, "shell_thickness", shellThicknessValue);
      dcrteCanonical(out, "shell_thickness_voxels", shellThicknessVoxelsValue);
      dcrteCanonical(out, "scheduler_id", schedulerIdValue);
      dcrteCanonical(out, "materializer_id", materializerIdValue);
      dcrteCanonical(out, "raised_veins_policy", raisedVeinsPolicyValue);
    } else if (pipelineMode.equals("DCRTE_IMPORTED_MESH")) {
      dcrteCanonical(out, "imported_source_name", importedSourceNameValue);
      dcrteCanonical(out, "imported_source_format", importedSourceFormatValue);
      dcrteCanonical(out, "imported_source_hash", importedSourceHashValue);
      dcrteCanonical(out, "imported_source_bytes", Long.toString(importedSourceBytesValue));
      dcrteCanonical(out, "imported_parsed_triangles", importedParsedTrianglesValue);
      dcrteCanonical(out, "imported_policy", importedPolicyValue);
      dcrteCanonical(out, "imported_resolution", importedResolutionValue);
      dcrteCanonical(out, "imported_rotate_x", importedRotateXValue);
      dcrteCanonical(out, "imported_rotate_y", importedRotateYValue);
      dcrteCanonical(out, "imported_rotate_z", importedRotateZValue);
      dcrteCanonical(out, "imported_fit_margin", importedFitMarginValue);
      dcrteCanonical(out, "imported_scale_multiplier", importedScaleMultiplierValue);
      dcrteCanonical(out, "imported_uniform_scale", importedUniformScaleValue);
      dcrteCanonical(out, "imported_sdf_signed", importedSdfSignedValue);
      dcrteCanonical(out, "imported_sdf_algorithm", importedSdfAlgorithmValue);
      dcrteCanonical(out, "imported_boundary_threshold", importedBoundaryThresholdValue);
      dcrteCanonical(out, "imported_intersection_tolerance", importedIntersectionToleranceValue);
      dcrteCanonical(out, "imported_jitter_magnitude", importedJitterMagnitudeValue);
      dcrteCanonical(out, "imported_boundary_voxels", importedBoundaryVoxelsValue);
      dcrteCanonical(out, "imported_inside_voxels", importedInsideVoxelsValue);
      dcrteCanonical(out, "imported_failed_scanlines", importedFailedScanlinesValue);
      dcrteCanonical(out, "imported_volume_error", Double.toString(importedVolumeErrorValue));
      dcrteCanonical(out, "observation_mode", observationModeValue);
      dcrteCanonical(out, "boundary_epsilon", boundaryEpsilonValue);
      dcrteCanonical(out, "shell_thickness", shellThicknessValue);
      dcrteCanonical(out, "shell_thickness_voxels", shellThicknessVoxelsValue);
      dcrteCanonical(out, "scheduler_id", schedulerIdValue);
      dcrteCanonical(out, "materializer_id", materializerIdValue);
      dcrteCanonical(out, "raised_veins_policy", raisedVeinsPolicyValue);
      dcrteCanonical(out, "coordinate_mode", coordinateModeValue);
      dcrteCanonical(out, "coordinate_version", coordinateVersionValue);
      dcrteCanonical(out, "coordinate_mapping", coordinateMappingValue);
      dcrteCanonical(out, "coordinate_radial_model", coordinateRadialModelValue);
      dcrteCanonical(out, "coordinate_fallback_policy", coordinateFallbackPolicyValue);
      dcrteCanonical(out, "coordinate_comparison_mode", coordinateComparisonModeValue);
      dcrteCanonical(out, "coordinate_longitudinal_scale", coordinateLongitudinalScaleValue);
      dcrteCanonical(out, "coordinate_radial_scale", coordinateRadialScaleValue);
      dcrteCanonical(out, "coordinate_build_status", coordinateBuildStatusValue);
      dcrteCanonical(out, "coordinate_valid_fraction", coordinateValidFractionValue);
      dcrteCanonical(out, "coordinate_ambiguity_fraction", coordinateAmbiguityFractionValue);
      dcrteCanonical(out, "coordinate_fallback_fraction", coordinateFallbackFractionValue);
      dcrteCanonical(out, "coordinate_mean_confidence", coordinateMeanConfidenceValue);
    }
    return out.toString();
  }

  JSONObject toJSONObject() {
    JSONObject root = new JSONObject();
    root.setString("schema_version", schemaVersion);
    root.setInt("dcrte_milestone", dcrteMilestone);
    root.setString("configuration_id", configurationId);
    root.setString("architecture_version", "DCRTE-ET v0.3");
    root.setString("application_version", dcrteMilestone >= 3 ? "Cosmosis Visual Observatory M3"
      : dcrteMilestone >= 2 ? "Cosmosis Visual Observatory M2" : "Cosmosis Visual Observatory M1");

    JSONObject pipeline = new JSONObject();
    pipeline.setString("mode", pipelineMode);
    pipeline.setString("field_engine_id", fieldEngineId);
    pipeline.setString("field_engine_version", fieldEngineVersion);
    boolean dcrteGeneration = pipelineMode.equals("DCRTE_PRIMITIVE") || pipelineMode.equals("DCRTE_IMPORTED_MESH");
    pipeline.setString("generation_path", pipelineMode.equals("DCRTE_IMPORTED_MESH") ? "dcrte_imported_mesh" : pipelineMode.equals("DCRTE_PRIMITIVE") ? "dcrte_primitive" : "legacy_direct");
    pipeline.setString("adapter_role", dcrteGeneration ? "field_and_materializer_boundary" : "diagnostic_only");
    root.setJSONObject("pipeline", pipeline);

    JSONObject fieldConfig = new JSONObject();
    fieldConfig.setString("engine_id", fieldEngineId);
    fieldConfig.setString("engine_version", fieldEngineVersion);
    fieldConfig.setString("configuration_id", configurationId);
    fieldConfig.setInt("seed", seedValue);
    fieldConfig.setFloat("simulation_time", simulationTime);
    fieldConfig.setFloat("alpha", alphaValue);
    fieldConfig.setInt("depth", depthValue);
    fieldConfig.setFloat("source", sourceValue);
    fieldConfig.setFloat("floquet", floquetValue);
    fieldConfig.setFloat("quasi_energy", quasiEnergyValue);
    fieldConfig.setFloat("coherence", coherenceValue);
    fieldConfig.setFloat("ctc_bias", ctcBiasValue);
    fieldConfig.setFloat("brane_twist", braneTwistValue);
    fieldConfig.setFloat("deep_detail", deepDetailValue);
    fieldConfig.setFloat("time_scale", timeScaleValue);
    fieldConfig.setFloat("recursion_falloff", recursionFalloffValue);
    JSONArray blend = new JSONArray();
    for (int i = 0; i < topologyBlend.length; i++) blend.setFloat(i, topologyBlend[i]);
    fieldConfig.setJSONArray("topology_blend", blend);
    root.setJSONObject("field", fieldConfig);

    JSONObject foundry = new JSONObject();
    foundry.setInt("resolution", foundryResolutionValue);
    foundry.setFloat("iso_band", foundryIsoBandValue);
    foundry.setFloat("scale_mm", foundryScaleMMValue);
    foundry.setInt("geometry_index", foundryGeometryIndexValue);
    foundry.setString("geometry_name", foundryGeometryNameValue);
    foundry.setFloat("wrap_blend", foundryWrapBlendValue);
    foundry.setBoolean("raised_veins", foundryRaisedVeinsValue);
    foundry.setFloat("vein_radius_mm", foundryVeinRadiusMMValue);
    foundry.setFloat("vein_lift_mm", foundryVeinLiftMMValue);
    root.setJSONObject("surface_foundry", foundry);

    JSONObject shaper = new JSONObject();
    shaper.setBoolean("enabled", shaperEnabledValue);
    shaper.setBoolean("use_sender", shaperUseSenderValue);
    shaper.setFloat("mix", shaperMixValue);
    shaper.setFloat("solar_wind", solarWindValue);
    shaper.setFloat("xray_flux", xrayFluxValue);
    shaper.setFloat("ocean_current", oceanCurrentValue);
    shaper.setFloat("tide", tideValue);
    shaper.setFloat("galactic_torsion", galacticTorsionValue);
    shaper.setFloat("plasma", shaperPlasmaValue);
    shaper.setFloat("water", shaperWaterValue);
    shaper.setFloat("cosmic", shaperCosmicValue);
    shaper.setFloat("drive", shaperDriveValue);
    root.setJSONObject("shaper", shaper);

    JSONObject material = new JSONObject();
    material.setString("source_mode", materialSourceModeValue);
    material.setInt("catalog_index", materialIndexValue);
    material.setString("target", materialTargetValue);
    material.setString("source_id", materialSourceIdValue);
    root.setJSONObject("material", material);

    if (pipelineMode.equals("DCRTE_PRIMITIVE")) {
      ObservationDomain domain;
      if (primitiveDomainTypeValue.equals("box")) {
        domain = new BoxDomain(primitiveCenterXValue, primitiveCenterYValue, primitiveCenterZValue,
          primitiveBoxHalfXValue, primitiveBoxHalfYValue, primitiveBoxHalfZValue);
      } else if (primitiveDomainTypeValue.equals("cylinder")) {
        domain = new CylinderDomain(primitiveCenterXValue, primitiveCenterYValue, primitiveCenterZValue,
          primitiveCylinderRadiusValue, primitiveCylinderHalfHeightValue);
      } else {
        domain = new SphereDomain(primitiveCenterXValue, primitiveCenterYValue, primitiveCenterZValue,
          primitiveSphereRadiusValue);
      }
      VolumeSpec spec = new VolumeSpec(observerResolutionValue, observerResolutionValue, observerResolutionValue,
        new Bounds3D(observerMinXValue, observerMinYValue, observerMinZValue, observerMaxXValue, observerMaxYValue, observerMaxZValue));
      UniformGridObserver observer = new UniformGridObserver();
      observer.initialize(spec);
      ObservationLayer observation = observationModeValue.equals("shell_band")
        ? new ShellBandObservation(boundaryEpsilonValue, shellThicknessValue, shellThicknessVoxelsValue)
        : new HardInteriorObservation(boundaryEpsilonValue);
      root.setJSONObject("domain", domain.toJSON());
      root.setJSONObject("observer", observer.toJSON());
      root.setJSONObject("observation", observation.toJSON());
      root.setJSONObject("scheduler", dcrteImmediateScheduler.toJSON());
      root.setJSONObject("materializer", dcrteLegacyMaterializer.toJSON());
      JSONObject coordinates = new JSONObject();
      coordinates.setString("type", "cartesian");
      coordinates.setString("source", "uniform_grid_observer");
      root.setJSONObject("coordinates", coordinates);
      JSONObject raisedVeins = new JSONObject();
      raisedVeins.setBoolean("requested", foundryRaisedVeinsValue);
      raisedVeins.setBoolean("applied", false);
      raisedVeins.setString("reason", raisedVeinsPolicyValue);
      root.setJSONObject("raised_veins", raisedVeins);
    } else if (pipelineMode.equals("DCRTE_IMPORTED_MESH")) {
      JSONObject sourceMesh = new JSONObject();
      sourceMesh.setString("filename", importedSourceNameValue);
      sourceMesh.setString("format", importedSourceFormatValue);
      sourceMesh.setString("sha256", importedSourceHashValue);
      sourceMesh.setString("source_units", "unspecified");
      sourceMesh.setString("source_bytes", Long.toString(importedSourceBytesValue));
      sourceMesh.setInt("parsed_triangles", importedParsedTrianglesValue);
      root.setJSONObject("source_mesh", sourceMesh);
      if (dcrteImportedMeshReport != null) root.setJSONObject("mesh_report", dcrteImportedMeshReport.toJSON());
      if (dcrteImportedTransform != null) root.setJSONObject("transform", dcrteImportedTransform.toJSON());
      VolumeSpec spec = new VolumeSpec(importedResolutionValue, importedResolutionValue, importedResolutionValue,
        new Bounds3D(observerMinXValue, observerMinYValue, observerMinZValue, observerMaxXValue, observerMaxYValue, observerMaxZValue));
      UniformGridObserver observer = new UniformGridObserver();
      observer.initialize(spec);
      root.setJSONObject("observer", observer.toJSON());
      if (dcrteImportedSdf != null) root.setJSONObject("sdf", dcrteImportedSdf.toJSON());
      ObservationLayer observation = observationModeValue.equals("shell_band")
        ? new ShellBandObservation(boundaryEpsilonValue, shellThicknessValue, shellThicknessVoxelsValue)
        : new HardInteriorObservation(boundaryEpsilonValue);
      root.setJSONObject("observation", observation.toJSON());
      root.setJSONObject("scheduler", dcrteImmediateScheduler.toJSON());
      root.setJSONObject("materializer", dcrteLegacyMaterializer.toJSON());
      JSONObject coordinates = new JSONObject();
      coordinates.setString("type", coordinateModeValue);
      coordinates.setString("version", coordinateVersionValue);
      coordinates.setString("mapping", coordinateMappingValue);
      coordinates.setString("source", "uniform_grid_observer");
      coordinates.setString("source_to_observation", "fit_centered_uniform");
      coordinates.setString("radial_model", coordinateRadialModelValue);
      coordinates.setString("fallback_policy", coordinateFallbackPolicyValue);
      coordinates.setString("comparison_mode", coordinateComparisonModeValue);
      coordinates.setFloat("longitudinal_scale", coordinateLongitudinalScaleValue);
      coordinates.setFloat("radial_scale", coordinateRadialScaleValue);
      coordinates.setString("build_status", coordinateBuildStatusValue);
      coordinates.setFloat("valid_fraction", coordinateValidFractionValue);
      coordinates.setFloat("ambiguity_fraction", coordinateAmbiguityFractionValue);
      coordinates.setFloat("fallback_fraction", coordinateFallbackFractionValue);
      coordinates.setFloat("mean_confidence", coordinateMeanConfidenceValue);
      root.setJSONObject("coordinates", coordinates);
      JSONObject raisedVeins = new JSONObject();
      raisedVeins.setBoolean("requested", foundryRaisedVeinsValue);
      raisedVeins.setBoolean("applied", false);
      raisedVeins.setString("reason", raisedVeinsPolicyValue);
      root.setJSONObject("raised_veins", raisedVeins);
      if (dcrteImportedSourceIsFixture && dcrteImportedFixtureMetadata != null) root.setJSONObject("fixture", dcrteImportedFixtureMetadata);
    }
    return root;
  }
}

DCRTEConfig dcrteLastBuildConfiguration = null;

DCRTEConfig captureDcrteConfig() {
  DCRTEConfig config = new DCRTEConfig();
  config.pipelineMode = dcrtePipelineMode.id();
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    config.schemaVersion = "0.6-m3";
    config.dcrteMilestone = 3;
  }
  config.fieldEngineId = dcrteGenerationFieldEngineId();
  config.fieldEngineVersion = dcrteGenerationFieldEngineVersion();
  config.seedValue = seed;
  config.simulationTime = simT;
  config.alphaValue = alpha;
  config.depthValue = depth;
  config.sourceValue = sourcePressure;
  config.floquetValue = floquetCoupling;
  config.quasiEnergyValue = quasiEnergy;
  config.coherenceValue = coherenceBias;
  config.ctcBiasValue = ctcBias;
  config.braneTwistValue = braneTwist;
  config.deepDetailValue = deepDetail;
  config.timeScaleValue = timeScale;
  config.recursionFalloffValue = recursionFalloff();
  config.topologyBlend = currentTopologyScores();
  config.foundryResolutionValue = foundryActiveVolumeResolution();
  config.foundryIsoBandValue = foundryIsoBand;
  config.foundryScaleMMValue = foundryScaleMM;
  config.foundryGeometryIndexValue = foundryGeometryIndex;
  config.foundryGeometryNameValue = foundryGeometryName();
  config.foundryWrapBlendValue = foundryGeometryIndex == 0 ? 0 : foundryWrapBlend;
  config.foundryRaisedVeinsValue = foundryRaisedVeins;
  config.foundryVeinRadiusMMValue = foundryVeinRadiusMM;
  config.foundryVeinLiftMMValue = foundryVeinLiftMM;
  config.shaperEnabledValue = shaperEnabled;
  config.shaperUseSenderValue = shaperUseSender;
  config.shaperMixValue = shaperMix;
  config.solarWindValue = solarWindStream;
  config.xrayFluxValue = xrayFluxStream;
  config.oceanCurrentValue = oceanCurrentStream;
  config.tideValue = tideStream;
  config.galacticTorsionValue = galacticTorsionStream;
  config.shaperPlasmaValue = shaperPlasma;
  config.shaperWaterValue = shaperWater;
  config.shaperCosmicValue = shaperCosmic;
  config.shaperDriveValue = shaperDrive;
  config.materialSourceModeValue = materialSourceLabel();
  config.materialIndexValue = selectedMaterial;
  MaterialProfile material = activeMaterial();
  config.materialTargetValue = material == null ? "none" : safeString(material.name, "Unknown");
  config.materialSourceIdValue = material == null ? "" : safeString(material.sourceId, "");
  config.primitiveDomainTypeValue = dcrtePrimitiveDomainType.id();
  config.primitiveCenterXValue = dcrteDomainCenterX;
  config.primitiveCenterYValue = dcrteDomainCenterY;
  config.primitiveCenterZValue = dcrteDomainCenterZ;
  config.primitiveSphereRadiusValue = dcrteSphereRadius;
  config.primitiveBoxHalfXValue = dcrteBoxHalfX;
  config.primitiveBoxHalfYValue = dcrteBoxHalfY;
  config.primitiveBoxHalfZValue = dcrteBoxHalfZ;
  config.primitiveCylinderRadiusValue = dcrteCylinderRadius;
  config.primitiveCylinderHalfHeightValue = dcrteCylinderHalfHeight;
  config.observerResolutionValue = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
    ? dcrteImportedResolution : dcrtePrimitiveResolution;
  config.observerMinXValue = dcrteObserverBounds.minX;
  config.observerMinYValue = dcrteObserverBounds.minY;
  config.observerMinZValue = dcrteObserverBounds.minZ;
  config.observerMaxXValue = dcrteObserverBounds.maxX;
  config.observerMaxYValue = dcrteObserverBounds.maxY;
  config.observerMaxZValue = dcrteObserverBounds.maxZ;
  config.observationModeValue = dcrteObservationMode.id();
  VolumeSpec observationSpec = dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH
    ? createDcrteImportedVolumeSpec() : createDcrteVolumeSpec();
  config.boundaryEpsilonValue = dcrteBoundaryEpsilon(observationSpec);
  config.shellThicknessValue = dcrteShellThickness(observationSpec);
  config.shellThicknessVoxelsValue = dcrteShellThicknessVoxels;
  config.schedulerIdValue = dcrteImmediateScheduler.getId();
  config.materializerIdValue = dcrteLegacyMaterializer.getId();
  config.raisedVeinsPolicyValue = dcrteRaisedVeinsPolicy();
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    config.importedSourceNameValue = dcrteImportedSourceMesh == null ? "" : dcrteImportedSourceMesh.sourceName;
    config.importedSourceFormatValue = dcrteImportedSourceMesh == null ? "" : dcrteImportedSourceMesh.sourceFormat;
    config.importedSourceHashValue = dcrteImportedSourceMesh == null ? "" : dcrteImportedSourceMesh.sourceHashSha256;
    config.importedSourceBytesValue = dcrteImportedSourceMesh == null ? 0 : dcrteImportedSourceMesh.sourceBytes;
    config.importedParsedTrianglesValue = dcrteImportedMeshReport == null ? 0 : dcrteImportedMeshReport.parsedTriangleCount;
    config.importedPolicyValue = dcrteImportedPolicy.id();
    config.importedResolutionValue = dcrteImportedResolution;
    config.importedRotateXValue = dcrteImportedRotateX;
    config.importedRotateYValue = dcrteImportedRotateY;
    config.importedRotateZValue = dcrteImportedRotateZ;
    config.importedFitMarginValue = dcrteImportedFitMargin;
    config.importedScaleMultiplierValue = dcrteImportedScaleMultiplier;
    config.importedUniformScaleValue = dcrteImportedTransform == null ? 0 : dcrteImportedTransform.uniformScale;
    config.importedSdfSignedValue = dcrteImportedSdf != null && dcrteImportedSdf.signed;
    config.importedSdfAlgorithmValue = dcrteImportedSdf == null || dcrteImportedSdf.quality == null ? "none" : dcrteImportedSdf.quality.algorithm;
    config.importedBoundaryThresholdValue = dcrteImportedBoundary == null ? 0 : dcrteImportedBoundary.boundaryThreshold;
    config.importedIntersectionToleranceValue = dcrteImportedInsideOutside == null ? 0 : dcrteImportedInsideOutside.intersectionTolerance;
    config.importedJitterMagnitudeValue = dcrteImportedInsideOutside == null ? 0 : dcrteImportedInsideOutside.jitterMagnitude;
    config.importedBoundaryVoxelsValue = dcrteImportedBoundary == null ? 0 : dcrteImportedBoundary.boundaryCount;
    config.importedInsideVoxelsValue = dcrteImportedInsideOutside == null ? 0 : dcrteImportedInsideOutside.insideCount;
    config.importedFailedScanlinesValue = dcrteImportedInsideOutside == null ? 0 : dcrteImportedInsideOutside.failedScanlineCount;
    config.importedVolumeErrorValue = dcrteImportedSdf == null || dcrteImportedSdf.quality == null ? Double.NaN : dcrteImportedSdf.quality.volumeRelativeError;
    config.coordinateModeValue = dcrteCoordinateMode.id();
    config.coordinateVersionValue = dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN
      ? dcrteCartesianCoordinateSystem.getVersion() : "1.0-m3";
    config.coordinateMappingValue = dcrteCoordinateMode == DCRTECoordinateMode.CARTESIAN
      ? "observer_world_identity" : "INTRINSIC_CYLINDRICAL_EMBEDDING";
    config.coordinateRadialModelValue = dcrteIntrinsicRadialModel.id();
    config.coordinateFallbackPolicyValue = dcrteIntrinsicFallbackPolicy.id();
    config.coordinateComparisonModeValue = dcrteCoordinateComparisonMode.id();
    config.coordinateLongitudinalScaleValue = dcrteIntrinsicLongitudinalScale;
    config.coordinateRadialScaleValue = dcrteIntrinsicRadialScale;
    config.coordinateBuildStatusValue = dcrteIntrinsicBuildStatus;
    if (dcrteIntrinsicBuildResult != null && dcrteIntrinsicBuildResult.validation != null) {
      IntrinsicValidationReport intrinsic = dcrteIntrinsicBuildResult.validation;
      config.coordinateValidFractionValue = intrinsic.validFraction;
      config.coordinateAmbiguityFractionValue = intrinsic.ambiguityFraction;
      config.coordinateFallbackFractionValue = intrinsic.fallbackFraction;
      config.coordinateMeanConfidenceValue = intrinsic.meanConfidence;
    }
  }
  config.finalizeIdentity();
  return config;
}

void appendDcrteMetadata(JSONObject metadata) {
  DCRTEConfig config;
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE && dcrteLastBuildConfiguration != null && !dcrtePrimitiveStale) {
    config = dcrteLastBuildConfiguration;
  } else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH && dcrteImportedLastBuildConfiguration != null && !dcrteImportedStale) {
    config = dcrteImportedLastBuildConfiguration;
  } else config = captureDcrteConfig();
  dcrteLastConfiguration = config;
  metadata.setString("dcrte_pipeline_mode", config.pipelineMode);
  metadata.setString("dcrte_field_engine_id", config.fieldEngineId);
  metadata.setString("dcrte_field_engine_version", config.fieldEngineVersion);
  metadata.setString("dcrte_configuration_id", config.configurationId);
  boolean primitive = config.pipelineMode.equals("DCRTE_PRIMITIVE");
  boolean imported = config.pipelineMode.equals("DCRTE_IMPORTED_MESH");
  metadata.setString("dcrte_generation_path", imported ? "dcrte_imported_mesh" : primitive ? "dcrte_primitive" : "legacy_direct");
  metadata.setString("dcrte_adapter_role", primitive || imported ? "field_and_materializer_boundary" : "diagnostic_only");
  JSONObject configuration = config.toJSONObject();
  if (primitive && dcrteLastValidationReport != null) {
    configuration.setJSONObject("validation", dcrteLastValidationReport.toJSON());
    if (dcrtePrimitiveVolume != null) configuration.setJSONObject("volume", dcrtePrimitiveVolume.toJSON());
    configuration.setJSONObject("deterministic_tests", dcrteM1Tests.toJSON());
  } else if (imported) {
    if (dcrteLastValidationReport != null) configuration.setJSONObject("validation", dcrteLastValidationReport.toJSON());
    if (dcrteImportedVolume != null) configuration.setJSONObject("volume", dcrteImportedVolume.toJSON());
    JSONObject tests = new JSONObject();
    tests.setJSONObject("milestone_2", dcrteM2Tests.toJSON());
    tests.setJSONObject("milestone_2_5", dcrteM25Tests.toJSON());
    tests.setJSONObject("milestone_3", dcrteM3Tests.toJSON());
    configuration.setJSONObject("deterministic_tests", tests);
    configuration.setJSONObject("coordinate_system", dcrteCoordinateMetadataJSON());
  }
  metadata.setJSONObject("dcrte_configuration", configuration);
}

void dcrteCanonical(StringBuilder out, String key, String value) {
  out.append(key).append('=').append(dcrteCanonicalEscape(value)).append('\n');
}

void dcrteCanonical(StringBuilder out, String key, int value) {
  dcrteCanonical(out, key, Integer.toString(value));
}

void dcrteCanonical(StringBuilder out, String key, float value) {
  dcrteCanonical(out, key, Float.toString(value));
}

void dcrteCanonical(StringBuilder out, String key, boolean value) {
  dcrteCanonical(out, key, Boolean.toString(value));
}

String dcrteFloatArray(float[] values) {
  StringBuilder out = new StringBuilder();
  for (int i = 0; i < values.length; i++) {
    if (i > 0) out.append(',');
    out.append(Float.toString(values[i]));
  }
  return out.toString();
}

String dcrteCanonicalEscape(String value) {
  if (value == null) return "";
  String escaped = value.replace("\\", "\\\\");
  escaped = escaped.replace("\r", "\\r");
  escaped = escaped.replace("\n", "\\n");
  escaped = escaped.replace("=", "\\=");
  return escaped;
}

String dcrteSha256(String value) {
  try {
    java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
    byte[] bytes = digest.digest(value.getBytes("UTF-8"));
    StringBuilder hex = new StringBuilder();
    for (int i = 0; i < bytes.length; i++) {
      int unsigned = bytes[i] & 0xff;
      if (unsigned < 16) hex.append('0');
      hex.append(Integer.toHexString(unsigned));
    }
    return hex.toString();
  }
  catch (Exception error) {
    println("DCRTE configuration hash failed: " + error);
    return "sha256-unavailable";
  }
}
