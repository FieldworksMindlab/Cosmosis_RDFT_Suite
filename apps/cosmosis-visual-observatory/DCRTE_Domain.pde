/* DCRTE-ET Milestone 1 analytic primitive observation domains. */

enum DCRTEPrimitiveDomainType {
  SPHERE,
  BOX,
  CYLINDER;

  String id() {
    return name().toLowerCase();
  }
}

class Bounds3D {
  float minX;
  float minY;
  float minZ;
  float maxX;
  float maxY;
  float maxZ;

  Bounds3D(float minX, float minY, float minZ, float maxX, float maxY, float maxZ) {
    this.minX = minX;
    this.minY = minY;
    this.minZ = minZ;
    this.maxX = maxX;
    this.maxY = maxY;
    this.maxZ = maxZ;
  }

  float sizeX() { return maxX - minX; }
  float sizeY() { return maxY - minY; }
  float sizeZ() { return maxZ - minZ; }
  float centerX() { return (minX + maxX) * 0.5f; }
  float centerY() { return (minY + maxY) * 0.5f; }
  float centerZ() { return (minZ + maxZ) * 0.5f; }
  float volume() { return sizeX() * sizeY() * sizeZ(); }

  boolean isValid() {
    return dcrteFinite(minX) && dcrteFinite(minY) && dcrteFinite(minZ)
      && dcrteFinite(maxX) && dcrteFinite(maxY) && dcrteFinite(maxZ)
      && sizeX() > 0 && sizeY() > 0 && sizeZ() > 0;
  }

  boolean overlaps(Bounds3D other) {
    if (other == null || !isValid() || !other.isValid()) return false;
    return maxX >= other.minX && minX <= other.maxX
      && maxY >= other.minY && minY <= other.maxY
      && maxZ >= other.minZ && minZ <= other.maxZ;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    JSONArray minValues = new JSONArray();
    minValues.setFloat(0, minX);
    minValues.setFloat(1, minY);
    minValues.setFloat(2, minZ);
    JSONArray maxValues = new JSONArray();
    maxValues.setFloat(0, maxX);
    maxValues.setFloat(1, maxY);
    maxValues.setFloat(2, maxZ);
    json.setJSONArray("min", minValues);
    json.setJSONArray("max", maxValues);
    json.setFloat("volume", volume());
    return json;
  }
}

class DomainSample {
  boolean inside;
  float signedDistance;
  float normalX;
  float normalY;
  float normalZ;
  int regionId;
  boolean valid;

  void set(boolean inside, float signedDistance, float nx, float ny, float nz, int regionId, boolean valid) {
    this.inside = inside;
    this.signedDistance = signedDistance;
    this.normalX = nx;
    this.normalY = ny;
    this.normalZ = nz;
    this.regionId = regionId;
    this.valid = valid;
  }
}

interface ObservationDomain {
  void sample(float x, float y, float z, DomainSample target);
  float signedDistance(float x, float y, float z);
  Bounds3D bounds();
  float analyticVolume();
  String getId();
  String getVersion();
  JSONObject toJSON();
  boolean isValid();
  String validationMessage();
}

class SphereDomain implements ObservationDomain {
  float cx;
  float cy;
  float cz;
  float radius;

  SphereDomain(float cx, float cy, float cz, float radius) {
    this.cx = cx;
    this.cy = cy;
    this.cz = cz;
    this.radius = radius;
  }

  public float signedDistance(float x, float y, float z) {
    float dx = x - cx;
    float dy = y - cy;
    float dz = z - cz;
    return sqrt(dx * dx + dy * dy + dz * dz) - radius;
  }

  public void sample(float x, float y, float z, DomainSample target) {
    float dx = x - cx;
    float dy = y - cy;
    float dz = z - cz;
    float distance = sqrt(dx * dx + dy * dy + dz * dz);
    float sdf = distance - radius;
    boolean normalValid = distance > 0.000001f;
    float inverse = normalValid ? 1.0f / distance : 0;
    target.set(sdf <= 0, sdf,
      normalValid ? dx * inverse : 0,
      normalValid ? dy * inverse : 1,
      normalValid ? dz * inverse : 0,
      sdf <= 0 ? 1 : 0,
      dcrteFinite(sdf));
  }

  public Bounds3D bounds() {
    return new Bounds3D(cx - radius, cy - radius, cz - radius, cx + radius, cy + radius, cz + radius);
  }

  public float analyticVolume() { return 4.0f * PI * radius * radius * radius / 3.0f; }
  public String getId() { return "sphere"; }
  public String getVersion() { return "1.0"; }
  public boolean isValid() { return dcrteFinite(cx) && dcrteFinite(cy) && dcrteFinite(cz) && dcrteFinite(radius) && radius > 0; }
  public String validationMessage() { return isValid() ? "valid" : "radius and center must be finite; radius must be positive"; }

  public JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    JSONArray center = new JSONArray();
    center.setFloat(0, cx); center.setFloat(1, cy); center.setFloat(2, cz);
    json.setJSONArray("center", center);
    json.setFloat("radius", radius);
    return json;
  }
}

class BoxDomain implements ObservationDomain {
  float cx;
  float cy;
  float cz;
  float hx;
  float hy;
  float hz;

  BoxDomain(float cx, float cy, float cz, float hx, float hy, float hz) {
    this.cx = cx; this.cy = cy; this.cz = cz;
    this.hx = hx; this.hy = hy; this.hz = hz;
  }

  public float signedDistance(float x, float y, float z) {
    float qx = abs(x - cx) - hx;
    float qy = abs(y - cy) - hy;
    float qz = abs(z - cz) - hz;
    float ox = max(qx, 0);
    float oy = max(qy, 0);
    float oz = max(qz, 0);
    float outside = sqrt(ox * ox + oy * oy + oz * oz);
    float inside = min(max(qx, max(qy, qz)), 0);
    return outside + inside;
  }

  public void sample(float x, float y, float z, DomainSample target) {
    float dx = x - cx;
    float dy = y - cy;
    float dz = z - cz;
    float qx = abs(dx) - hx;
    float qy = abs(dy) - hy;
    float qz = abs(dz) - hz;
    float ox = max(qx, 0);
    float oy = max(qy, 0);
    float oz = max(qz, 0);
    float outside = sqrt(ox * ox + oy * oy + oz * oz);
    float sdf = outside + min(max(qx, max(qy, qz)), 0);
    float nx = 0;
    float ny = 0;
    float nz = 0;
    if (outside > 0.000001f) {
      nx = (dx < 0 ? -ox : ox) / outside;
      ny = (dy < 0 ? -oy : oy) / outside;
      nz = (dz < 0 ? -oz : oz) / outside;
    } else if (qx >= qy && qx >= qz) {
      nx = dx < 0 ? -1 : 1;
    } else if (qy >= qz) {
      ny = dy < 0 ? -1 : 1;
    } else {
      nz = dz < 0 ? -1 : 1;
    }
    target.set(sdf <= 0, sdf, nx, ny, nz, sdf <= 0 ? 1 : 0, dcrteFinite(sdf));
  }

  public Bounds3D bounds() { return new Bounds3D(cx - hx, cy - hy, cz - hz, cx + hx, cy + hy, cz + hz); }
  public float analyticVolume() { return 8.0f * hx * hy * hz; }
  public String getId() { return "box"; }
  public String getVersion() { return "1.0"; }
  public boolean isValid() {
    return dcrteFinite(cx) && dcrteFinite(cy) && dcrteFinite(cz)
      && dcrteFinite(hx) && dcrteFinite(hy) && dcrteFinite(hz)
      && hx > 0 && hy > 0 && hz > 0;
  }
  public String validationMessage() { return isValid() ? "valid" : "center and half extents must be finite and positive"; }

  public JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    JSONArray center = new JSONArray();
    center.setFloat(0, cx); center.setFloat(1, cy); center.setFloat(2, cz);
    JSONArray extents = new JSONArray();
    extents.setFloat(0, hx); extents.setFloat(1, hy); extents.setFloat(2, hz);
    json.setJSONArray("center", center);
    json.setJSONArray("half_extents", extents);
    return json;
  }
}

class CylinderDomain implements ObservationDomain {
  float cx;
  float cy;
  float cz;
  float radius;
  float halfHeight;

  CylinderDomain(float cx, float cy, float cz, float radius, float halfHeight) {
    this.cx = cx; this.cy = cy; this.cz = cz;
    this.radius = radius; this.halfHeight = halfHeight;
  }

  public float signedDistance(float x, float y, float z) {
    float dx = x - cx;
    float dz = z - cz;
    float q0 = sqrt(dx * dx + dz * dz) - radius;
    float q1 = abs(y - cy) - halfHeight;
    float ox = max(q0, 0);
    float oy = max(q1, 0);
    return sqrt(ox * ox + oy * oy) + min(max(q0, q1), 0);
  }

  public void sample(float x, float y, float z, DomainSample target) {
    float dx = x - cx;
    float dy = y - cy;
    float dz = z - cz;
    float radial = sqrt(dx * dx + dz * dz);
    float q0 = radial - radius;
    float q1 = abs(dy) - halfHeight;
    float ox = max(q0, 0);
    float oy = max(q1, 0);
    float outside = sqrt(ox * ox + oy * oy);
    float sdf = outside + min(max(q0, q1), 0);
    float radialX = radial > 0.000001f ? dx / radial : 1;
    float radialZ = radial > 0.000001f ? dz / radial : 0;
    float nx = 0;
    float ny = 0;
    float nz = 0;
    if (outside > 0.000001f) {
      nx = radialX * ox / outside;
      ny = (dy < 0 ? -oy : oy) / outside;
      nz = radialZ * ox / outside;
    } else if (q0 >= q1) {
      nx = radialX;
      nz = radialZ;
    } else {
      ny = dy < 0 ? -1 : 1;
    }
    target.set(sdf <= 0, sdf, nx, ny, nz, sdf <= 0 ? 1 : 0, dcrteFinite(sdf));
  }

  public Bounds3D bounds() {
    return new Bounds3D(cx - radius, cy - halfHeight, cz - radius, cx + radius, cy + halfHeight, cz + radius);
  }

  public float analyticVolume() { return PI * radius * radius * (2.0f * halfHeight); }
  public String getId() { return "cylinder"; }
  public String getVersion() { return "1.0"; }
  public boolean isValid() {
    return dcrteFinite(cx) && dcrteFinite(cy) && dcrteFinite(cz)
      && dcrteFinite(radius) && dcrteFinite(halfHeight)
      && radius > 0 && halfHeight > 0;
  }
  public String validationMessage() { return isValid() ? "valid" : "center, radius, and half height must be finite and positive"; }

  public JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    JSONArray center = new JSONArray();
    center.setFloat(0, cx); center.setFloat(1, cy); center.setFloat(2, cz);
    json.setJSONArray("center", center);
    json.setFloat("radius", radius);
    json.setFloat("half_height", halfHeight);
    json.setString("axis", "Y");
    return json;
  }
}

DCRTEPrimitiveDomainType dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.SPHERE;
float dcrteDomainCenterX = 0;
float dcrteDomainCenterY = 0;
float dcrteDomainCenterZ = 0;
float dcrteSphereRadius = 0.88f;
float dcrteBoxHalfX = 0.78f;
float dcrteBoxHalfY = 0.78f;
float dcrteBoxHalfZ = 0.78f;
float dcrteCylinderRadius = 0.68f;
float dcrteCylinderHalfHeight = 0.88f;

ObservationDomain createDcrteObservationDomain() {
  if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.BOX) {
    return new BoxDomain(dcrteDomainCenterX, dcrteDomainCenterY, dcrteDomainCenterZ, dcrteBoxHalfX, dcrteBoxHalfY, dcrteBoxHalfZ);
  }
  if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.CYLINDER) {
    return new CylinderDomain(dcrteDomainCenterX, dcrteDomainCenterY, dcrteDomainCenterZ, dcrteCylinderRadius, dcrteCylinderHalfHeight);
  }
  return new SphereDomain(dcrteDomainCenterX, dcrteDomainCenterY, dcrteDomainCenterZ, dcrteSphereRadius);
}

void cycleDcrtePrimitiveDomain() {
  if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.SPHERE) dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.BOX;
  else if (dcrtePrimitiveDomainType == DCRTEPrimitiveDomainType.BOX) dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.CYLINDER;
  else dcrtePrimitiveDomainType = DCRTEPrimitiveDomainType.SPHERE;
  markDcrtePrimitiveStale("observation domain changed; regenerate");
}

JSONObject dcrteDomainBaseJSON(ObservationDomain domain) {
  JSONObject json = new JSONObject();
  json.setString("type", domain.getId());
  json.setString("version", domain.getVersion());
  json.setFloat("analytic_volume", domain.analyticVolume());
  json.setJSONObject("bounds", domain.bounds().toJSON());
  return json;
}

boolean dcrteFinite(float value) {
  return !Float.isNaN(value) && !Float.isInfinite(value);
}
