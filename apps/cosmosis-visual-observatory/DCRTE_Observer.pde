/* DCRTE-ET Milestone 1 uniform voxel-center observer. */

class VolumeSpec {
  int nx;
  int ny;
  int nz;
  Bounds3D bounds;

  VolumeSpec(int nx, int ny, int nz, Bounds3D bounds) {
    this.nx = nx;
    this.ny = ny;
    this.nz = nz;
    this.bounds = bounds;
  }

  int voxelCount() {
    long count = (long)nx * (long)ny * (long)nz;
    return count > Integer.MAX_VALUE ? -1 : (int)count;
  }

  float spacingX() { return bounds == null || nx <= 0 ? Float.NaN : bounds.sizeX() / nx; }
  float spacingY() { return bounds == null || ny <= 0 ? Float.NaN : bounds.sizeY() / ny; }
  float spacingZ() { return bounds == null || nz <= 0 ? Float.NaN : bounds.sizeZ() / nz; }
  float minSpacing() { return min(spacingX(), min(spacingY(), spacingZ())); }
  float sampleVolume() { return spacingX() * spacingY() * spacingZ(); }

  boolean isValid() {
    return nx > 0 && ny > 0 && nz > 0 && voxelCount() > 0
      && bounds != null && bounds.isValid()
      && dcrteFinite(spacingX()) && dcrteFinite(spacingY()) && dcrteFinite(spacingZ())
      && spacingX() > 0 && spacingY() > 0 && spacingZ() > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    JSONArray resolution = new JSONArray();
    resolution.setInt(0, nx); resolution.setInt(1, ny); resolution.setInt(2, nz);
    json.setJSONArray("resolution", resolution);
    json.setJSONObject("bounds", bounds == null ? new JSONObject() : bounds.toJSON());
    json.setFloat("spacing_x", spacingX());
    json.setFloat("spacing_y", spacingY());
    json.setFloat("spacing_z", spacingZ());
    json.setFloat("sample_volume", sampleVolume());
    return json;
  }
}

class UniformGridObserver {
  VolumeSpec spec;

  void initialize(VolumeSpec spec) {
    this.spec = spec;
  }

  int index(int x, int y, int z) {
    return x + spec.nx * (y + spec.ny * z);
  }

  float worldX(int x) { return lerp(spec.bounds.minX, spec.bounds.maxX, normalizedX(x)); }
  float worldY(int y) { return lerp(spec.bounds.minY, spec.bounds.maxY, normalizedY(y)); }
  float worldZ(int z) { return lerp(spec.bounds.minZ, spec.bounds.maxZ, normalizedZ(z)); }
  float normalizedX(int x) { return (x + 0.5f) / spec.nx; }
  float normalizedY(int y) { return (y + 0.5f) / spec.ny; }
  float normalizedZ(int z) { return (z + 0.5f) / spec.nz; }
  boolean isValid() { return spec != null && spec.isValid(); }

  JSONObject toJSON() {
    JSONObject json = spec == null ? new JSONObject() : spec.toJSON();
    json.setString("type", "uniform_grid");
    json.setString("sample_policy", "voxel_center");
    json.setString("coordinate_mode", "cartesian");
    return json;
  }
}

int dcrtePrimitiveResolution = 64;
Bounds3D dcrteObserverBounds = new Bounds3D(-1, -1, -1, 1, 1, 1);

VolumeSpec createDcrteVolumeSpec() {
  return new VolumeSpec(dcrtePrimitiveResolution, dcrtePrimitiveResolution, dcrtePrimitiveResolution, dcrteObserverBounds);
}

void cycleDcrtePrimitiveResolution() {
  if (dcrtePrimitiveResolution == 32) dcrtePrimitiveResolution = 64;
  else if (dcrtePrimitiveResolution == 64) dcrtePrimitiveResolution = 128;
  else dcrtePrimitiveResolution = 32;
  markDcrtePrimitiveStale("observer resolution changed; regenerate");
}

void adjustDcrtePrimitiveResolution(int direction) {
  if (direction < 0) {
    if (dcrtePrimitiveResolution == 128) dcrtePrimitiveResolution = 64;
    else dcrtePrimitiveResolution = 32;
  } else {
    if (dcrtePrimitiveResolution == 32) dcrtePrimitiveResolution = 64;
    else dcrtePrimitiveResolution = 128;
  }
  markDcrtePrimitiveStale("observer resolution changed; regenerate");
}
