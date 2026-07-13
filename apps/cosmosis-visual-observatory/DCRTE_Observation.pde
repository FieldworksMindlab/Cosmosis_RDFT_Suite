/* DCRTE-ET Milestone 1 binary observation layers. */

enum DCRTEObservationMode {
  HARD_INTERIOR,
  SHELL_BAND;

  String id() {
    return name().toLowerCase();
  }
}

class ObservationSample {
  boolean admitted;
  float maskWeight;
  float boundaryWeight;
  float domainDistance;
  int regionId;

  void set(boolean admitted, float boundaryWeight, float domainDistance, int regionId) {
    this.admitted = admitted;
    this.maskWeight = admitted ? 1 : 0;
    this.boundaryWeight = boundaryWeight;
    this.domainDistance = domainDistance;
    this.regionId = regionId;
  }
}

interface ObservationLayer {
  void observe(DomainSample domainSample, ObservationSample target);
  String getId();
  JSONObject toJSON();
  boolean isValid();
  String validationMessage();
}

class HardInteriorObservation implements ObservationLayer {
  float boundaryEpsilon;

  HardInteriorObservation(float boundaryEpsilon) {
    this.boundaryEpsilon = boundaryEpsilon;
  }

  public void observe(DomainSample domainSample, ObservationSample target) {
    boolean admitted = domainSample.valid && domainSample.signedDistance <= boundaryEpsilon;
    target.set(admitted, admitted ? 1 : 0, domainSample.signedDistance, domainSample.regionId);
  }

  public String getId() { return "hard_interior"; }
  public boolean isValid() { return dcrteFinite(boundaryEpsilon) && boundaryEpsilon >= 0; }
  public String validationMessage() { return isValid() ? "valid" : "boundary epsilon must be finite and non-negative"; }

  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("mode", getId());
    json.setFloat("boundary_epsilon", boundaryEpsilon);
    return json;
  }
}

class ShellBandObservation implements ObservationLayer {
  float boundaryEpsilon;
  float thickness;
  float thicknessVoxels;

  ShellBandObservation(float boundaryEpsilon, float thickness, float thicknessVoxels) {
    this.boundaryEpsilon = boundaryEpsilon;
    this.thickness = thickness;
    this.thicknessVoxels = thicknessVoxels;
  }

  public void observe(DomainSample domainSample, ObservationSample target) {
    float sdf = domainSample.signedDistance;
    boolean admitted = domainSample.valid
      && sdf <= boundaryEpsilon
      && sdf >= -(thickness + boundaryEpsilon);
    float boundaryWeight = admitted ? constrain(1.0f - abs(sdf) / max(0.000001f, thickness), 0, 1) : 0;
    target.set(admitted, boundaryWeight, sdf, domainSample.regionId);
  }

  public String getId() { return "shell_band"; }
  public boolean isValid() { return dcrteFinite(boundaryEpsilon) && boundaryEpsilon >= 0 && dcrteFinite(thickness) && thickness > 0; }
  public String validationMessage() { return isValid() ? "valid" : "shell thickness must be finite and positive"; }

  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("mode", getId());
    json.setString("side", "inside_only");
    json.setFloat("boundary_epsilon", boundaryEpsilon);
    json.setFloat("thickness", thickness);
    json.setFloat("thickness_voxels", thicknessVoxels);
    return json;
  }
}

DCRTEObservationMode dcrteObservationMode = DCRTEObservationMode.HARD_INTERIOR;
float dcrteShellThicknessVoxels = 4.0f;

float dcrteBoundaryEpsilon(VolumeSpec spec) {
  return spec == null ? 0 : spec.minSpacing() * 0.25f;
}

float dcrteShellThickness(VolumeSpec spec) {
  return spec == null ? 0 : spec.minSpacing() * dcrteShellThicknessVoxels;
}

ObservationLayer createDcrteObservationLayer(VolumeSpec spec) {
  float epsilon = dcrteBoundaryEpsilon(spec);
  if (dcrteObservationMode == DCRTEObservationMode.SHELL_BAND) {
    return new ShellBandObservation(epsilon, dcrteShellThickness(spec), dcrteShellThicknessVoxels);
  }
  return new HardInteriorObservation(epsilon);
}

void cycleDcrteObservationMode() {
  dcrteObservationMode = dcrteObservationMode == DCRTEObservationMode.HARD_INTERIOR
    ? DCRTEObservationMode.SHELL_BAND
    : DCRTEObservationMode.HARD_INTERIOR;
  markDcrteObservationMaterialStale("observation mode changed; regenerate");
}

void adjustDcrteShellThickness(float deltaVoxels) {
  dcrteShellThicknessVoxels = constrain(dcrteShellThicknessVoxels + deltaVoxels, 1.0f, 24.0f);
  markDcrteObservationMaterialStale("shell thickness changed; regenerate");
}

void markDcrteObservationMaterialStale(String reason) {
  if (dcrtePipelineMode == DCRTEPipelineMode.DCRTE_IMPORTED_MESH) {
    markDcrteImportedMaterialStale(reason);
  } else {
    markDcrtePrimitiveStale(reason);
  }
}
