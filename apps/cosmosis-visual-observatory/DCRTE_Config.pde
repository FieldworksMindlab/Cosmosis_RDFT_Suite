/*
  DCRTE-ET Milestone 0 configuration snapshot and provenance helpers.

  Configuration identity is derived from an explicitly ordered canonical
  string, not JSONObject serialization order.
*/

class DCRTEConfig {
  String schemaVersion = "0.3-m0";
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
    return out.toString();
  }

  JSONObject toJSONObject() {
    JSONObject root = new JSONObject();
    root.setString("schema_version", schemaVersion);
    root.setString("configuration_id", configurationId);

    JSONObject pipeline = new JSONObject();
    pipeline.setString("mode", pipelineMode);
    pipeline.setString("field_engine_id", fieldEngineId);
    pipeline.setString("field_engine_version", fieldEngineVersion);
    pipeline.setString("generation_path", "legacy_direct");
    pipeline.setString("adapter_role", "diagnostic_only");
    root.setJSONObject("pipeline", pipeline);

    JSONObject fieldConfig = new JSONObject();
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
    return root;
  }
}

DCRTEConfig captureDcrteConfig() {
  DCRTEConfig config = new DCRTEConfig();
  config.pipelineMode = dcrtePipelineMode.id();
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
  config.foundryResolutionValue = foundryResolution;
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
  config.finalizeIdentity();
  return config;
}

void appendDcrteMetadata(JSONObject metadata) {
  DCRTEConfig config = captureDcrteConfig();
  dcrteLastConfiguration = config;
  metadata.setString("dcrte_pipeline_mode", config.pipelineMode);
  metadata.setString("dcrte_field_engine_id", config.fieldEngineId);
  metadata.setString("dcrte_field_engine_version", config.fieldEngineVersion);
  metadata.setString("dcrte_configuration_id", config.configurationId);
  metadata.setString("dcrte_generation_path", "legacy_direct");
  metadata.setString("dcrte_adapter_role", "diagnostic_only");
  metadata.setJSONObject("dcrte_configuration", config.toJSONObject());
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
