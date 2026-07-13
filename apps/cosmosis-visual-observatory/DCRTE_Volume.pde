/* DCRTE-ET Milestone 1 flat authoritative volume storage. */

class DCRTEVolume {
  VolumeSpec spec;
  float[] scalar;
  boolean[] admitted;
  boolean[] candidateSolid;
  boolean[] active;
  boolean[] finalSolid;

  int domainInsideCount;
  int admittedCount;
  int candidateSolidCount;
  int activeCount;
  int finalSolidCount;
  int outsideSolidCount;
  int nonFiniteScalarCount;
  int firstNonFiniteIndex = -1;
  float firstNonFiniteX;
  float firstNonFiniteY;
  float firstNonFiniteZ;

  DCRTEVolume(VolumeSpec spec) {
    this.spec = spec;
    int count = spec == null ? 0 : max(0, spec.voxelCount());
    scalar = new float[count];
    admitted = new boolean[count];
    candidateSolid = new boolean[count];
    active = new boolean[count];
    finalSolid = new boolean[count];
  }

  int index(int x, int y, int z) {
    return x + spec.nx * (y + spec.ny * z);
  }

  boolean isValid() {
    int count = spec == null ? -1 : spec.voxelCount();
    return spec != null && spec.isValid() && count > 0
      && scalar.length == count
      && admitted.length == count
      && candidateSolid.length == count
      && active.length == count
      && finalSolid.length == count;
  }

  void recountFinal() {
    finalSolidCount = 0;
    outsideSolidCount = 0;
    activeCount = 0;
    for (int i = 0; i < finalSolid.length; i++) {
      if (active[i]) activeCount++;
      if (!finalSolid[i]) continue;
      finalSolidCount++;
      if (!admitted[i]) outsideSolidCount++;
    }
  }

  long estimatedBytes() {
    return (long)scalar.length * 4L
      + (long)(admitted.length + candidateSolid.length + active.length + finalSolid.length);
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    json.setInt("domain_inside_samples", domainInsideCount);
    json.setInt("admitted_samples", admittedCount);
    json.setInt("candidate_solid_samples", candidateSolidCount);
    json.setInt("active_samples", activeCount);
    json.setInt("final_solid_samples", finalSolidCount);
    json.setInt("outside_solid_samples", outsideSolidCount);
    json.setInt("nonfinite_scalar_samples", nonFiniteScalarCount);
    json.setString("estimated_storage_bytes", Long.toString(estimatedBytes()));
    return json;
  }
}

DCRTEVolume dcrtePrimitiveVolume = null;
ObservationDomain dcrteLastDomain = null;
UniformGridObserver dcrteLastObserver = null;
ObservationLayer dcrteLastObservation = null;
String dcrteBuildStage = "NOT BUILT";
boolean dcrtePrimitiveStale = true;
boolean dcrteDomainPreviewEnabled = true;
boolean dcrteSlicePreviewEnabled = true;
long dcrteLastBuildMillis = 0;

void markDcrtePrimitiveStale(String reason) {
  dcrtePrimitiveStale = true;
  dcrteBuildStage = "STALE";
  dcrteLastBuildConfiguration = null;
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) {
    markFoundryStale();
    foundryStatus = reason;
  }
}

int foundryActiveVolumeResolution() {
  if (foundryCallSheetSolid != null) return foundryCallSheetSolid.length;
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) return dcrteImportedResolution;
  return dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE ? dcrtePrimitiveResolution : foundryResolution;
}

void markCurrentFoundryStale(String reason) {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_PRIMITIVE) markDcrtePrimitiveStale(reason);
  else if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) markDcrteImportedMaterialStale(reason);
  else markFoundryStale();
}
