/*
  Physical panel observation domains for DCRTE primitive generation.

  A continuous panel clips one global field observation with a rectangular
  envelope. A cell array repeats the field in local spheroid coordinates and
  joins neighboring cells with a polynomial smooth union. Panel coordinates
  remain normalized against the longest physical dimension so the established
  cubic observer and voxel materializer retain isotropic physical voxels.
*/

enum DCRTEPanelLayoutMode {
  CONTINUOUS_FIELD,
  SPHEROID_CELLS;

  String id() { return name().toLowerCase(); }
  String label() { return this == CONTINUOUS_FIELD ? "CONTINUOUS" : "CELLS"; }
}

DCRTEPanelLayoutMode dcrtePanelLayoutMode = DCRTEPanelLayoutMode.CONTINUOUS_FIELD;
float dcrtePanelWidthMM = 180.0f;
float dcrtePanelHeightMM = 180.0f;
float dcrtePanelDepthMM = 30.0f;
int dcrtePanelColumns = 3;
int dcrtePanelRows = 3;
float dcrtePanelOverlap = 0.18f;
float dcrtePanelSmoothBlendRatio = 0.65f;

float dcrtePanelMaxDimensionMM() {
  return max(dcrtePanelWidthMM, max(dcrtePanelHeightMM, dcrtePanelDepthMM));
}

int dcrtePanelEffectiveVoxels(float dimensionMM) {
  return max(1, round(dcrtePrimitiveResolution * dimensionMM / max(0.001f, dcrtePanelMaxDimensionMM())));
}

class ContinuousPanelDomain extends BoxDomain {
  float widthMM;
  float heightMM;
  float depthMM;

  ContinuousPanelDomain(float widthMM, float heightMM, float depthMM) {
    super(0, 0, 0,
      widthMM / max(widthMM, max(heightMM, depthMM)),
      heightMM / max(widthMM, max(heightMM, depthMM)),
      depthMM / max(widthMM, max(heightMM, depthMM)));
    this.widthMM = widthMM;
    this.heightMM = heightMM;
    this.depthMM = depthMM;
  }

  public String getId() { return "panel_continuous"; }
  public String getVersion() { return "1.0-panel"; }
  public boolean isValid() {
    return super.isValid() && dcrteFinite(widthMM) && dcrteFinite(heightMM)
      && dcrteFinite(depthMM) && widthMM > 0 && heightMM > 0 && depthMM > 0;
  }
  public String validationMessage() {
    return isValid() ? "valid" : "panel width, height, and depth must be finite and positive";
  }

  public JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    json.setString("layout", DCRTEPanelLayoutMode.CONTINUOUS_FIELD.id());
    json.setFloat("width_mm", widthMM);
    json.setFloat("height_mm", heightMM);
    json.setFloat("depth_mm", depthMM);
    json.setFloat("normalization_scale_mm", max(widthMM, max(heightMM, depthMM)));
    json.setString("field_mapping", "global_isotropic_longest_dimension");
    return json;
  }
}

class SmoothSpheroidCellArrayDomain implements ObservationDomain {
  float widthMM;
  float heightMM;
  float depthMM;
  int columns;
  int rows;
  float overlap;
  float smoothBlendRatio;
  float halfX;
  float halfY;
  float halfZ;
  float radiusX;
  float radiusY;
  float radiusZ;
  float pitchX;
  float pitchY;
  float smoothK;
  float referenceVolume = -1;

  SmoothSpheroidCellArrayDomain(float widthMM, float heightMM, float depthMM,
      int columns, int rows, float overlap, float smoothBlendRatio) {
    this.widthMM = widthMM;
    this.heightMM = heightMM;
    this.depthMM = depthMM;
    this.columns = columns;
    this.rows = rows;
    this.overlap = overlap;
    this.smoothBlendRatio = smoothBlendRatio;
    float scaleMM = max(widthMM, max(heightMM, depthMM));
    halfX = widthMM / scaleMM;
    halfY = heightMM / scaleMM;
    halfZ = depthMM / scaleMM;
    float diameterX = 2.0f * halfX / max(0.001f, 1.0f + (columns - 1) * (1.0f - overlap));
    float diameterY = 2.0f * halfY / max(0.001f, 1.0f + (rows - 1) * (1.0f - overlap));
    radiusX = diameterX * 0.5f;
    radiusY = diameterY * 0.5f;
    radiusZ = halfZ;
    pitchX = columns <= 1 ? 0 : diameterX * (1.0f - overlap);
    pitchY = rows <= 1 ? 0 : diameterY * (1.0f - overlap);
    smoothK = min(radiusX, radiusY) * overlap * smoothBlendRatio;
  }

  float centerX(int column) {
    return columns <= 1 ? 0 : -halfX + radiusX + column * pitchX;
  }

  float centerY(int row) {
    return rows <= 1 ? 0 : -halfY + radiusY + row * pitchY;
  }

  float ellipsoidDistance(float x, float y, float z, float cx, float cy) {
    float px = x - cx;
    float py = y - cy;
    float pz = z;
    float qx = px / max(0.000001f, radiusX);
    float qy = py / max(0.000001f, radiusY);
    float qz = pz / max(0.000001f, radiusZ);
    float k0 = sqrt(qx * qx + qy * qy + qz * qz);
    float rx2 = radiusX * radiusX;
    float ry2 = radiusY * radiusY;
    float rz2 = radiusZ * radiusZ;
    float k1 = sqrt(px * px / max(0.000001f, rx2 * rx2)
      + py * py / max(0.000001f, ry2 * ry2)
      + pz * pz / max(0.000001f, rz2 * rz2));
    if (k1 <= 0.000001f) return -min(radiusX, min(radiusY, radiusZ));
    return k0 * (k0 - 1.0f) / k1;
  }

  float smoothMinimum(float a, float b) {
    if (smoothK <= 0.000001f) return min(a, b);
    float h = max(smoothK - abs(a - b), 0.0f) / smoothK;
    return min(a, b) - h * h * smoothK * 0.25f;
  }

  public float signedDistance(float x, float y, float z) {
    float result = Float.POSITIVE_INFINITY;
    for (int row = 0; row < rows; row++) {
      float cy = centerY(row);
      for (int column = 0; column < columns; column++) {
        float d = ellipsoidDistance(x, y, z, centerX(column), cy);
        result = result == Float.POSITIVE_INFINITY ? d : smoothMinimum(result, d);
      }
    }
    return result;
  }

  int nearestCell(float x, float y, float z) {
    float nearest = Float.POSITIVE_INFINITY;
    int region = 0;
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        float dx = (x - centerX(column)) / max(0.000001f, radiusX);
        float dy = (y - centerY(row)) / max(0.000001f, radiusY);
        float dz = z / max(0.000001f, radiusZ);
        float d2 = dx * dx + dy * dy + dz * dz;
        if (d2 < nearest) {
          nearest = d2;
          region = row * columns + column + 1;
        }
      }
    }
    return region;
  }

  public void sample(float x, float y, float z, DomainSample target) {
    float sdf = signedDistance(x, y, z);
    int region = nearestCell(x, y, z);
    int cellIndex = max(0, region - 1);
    int row = cellIndex / max(1, columns);
    int column = cellIndex % max(1, columns);
    // The nearest ellipsoid gradient is a stable normal proxy throughout the
    // smooth neck. Observation policies consume the signed distance; the
    // proxy avoids six additional whole-array SDF evaluations per voxel.
    float nx = (x - centerX(column)) / max(0.000001f, radiusX * radiusX);
    float ny = (y - centerY(row)) / max(0.000001f, radiusY * radiusY);
    float nz = z / max(0.000001f, radiusZ * radiusZ);
    float length = sqrt(nx * nx + ny * ny + nz * nz);
    boolean normalValid = length > 0.000001f;
    if (normalValid) { nx /= length; ny /= length; nz /= length; }
    target.set(sdf <= 0, sdf, normalValid ? nx : 0, normalValid ? ny : 0,
      normalValid ? nz : 1, sdf <= 0 ? region : 0, dcrteFinite(sdf));
  }

  public Bounds3D bounds() {
    return new Bounds3D(-halfX, -halfY, -halfZ, halfX, halfY, halfZ);
  }

  public float analyticVolume() {
    if (referenceVolume >= 0) return referenceVolume;
    Bounds3D b = bounds();
    int nx = 56;
    int ny = max(24, round(nx * b.sizeY() / max(0.000001f, b.sizeX())));
    int nz = max(16, round(nx * b.sizeZ() / max(0.000001f, b.sizeX())));
    float dx = b.sizeX() / nx;
    float dy = b.sizeY() / ny;
    float dz = b.sizeZ() / nz;
    int inside = 0;
    for (int z = 0; z < nz; z++) {
      float wz = b.minZ + (z + 0.5f) * dz;
      for (int y = 0; y < ny; y++) {
        float wy = b.minY + (y + 0.5f) * dy;
        for (int x = 0; x < nx; x++) {
          float wx = b.minX + (x + 0.5f) * dx;
          if (signedDistance(wx, wy, wz) <= 0) inside++;
        }
      }
    }
    referenceVolume = inside * dx * dy * dz;
    return referenceVolume;
  }

  public String getId() { return "panel_cells"; }
  public String getVersion() { return "1.0-panel"; }
  public boolean isValid() {
    return dcrteFinite(widthMM) && dcrteFinite(heightMM) && dcrteFinite(depthMM)
      && widthMM > 0 && heightMM > 0 && depthMM > 0
      && columns > 0 && rows > 0 && columns <= 12 && rows <= 12
      && dcrteFinite(overlap) && overlap >= 0 && overlap < 0.75f
      && dcrteFinite(smoothBlendRatio) && smoothBlendRatio >= 0 && smoothBlendRatio <= 2.0f
      && radiusX > 0 && radiusY > 0 && radiusZ > 0;
  }
  public String validationMessage() {
    return isValid() ? "valid" : "panel dimensions, cell grid, overlap, or blend is invalid";
  }

  public JSONObject toJSON() {
    JSONObject json = dcrteDomainBaseJSON(this);
    json.setString("layout", DCRTEPanelLayoutMode.SPHEROID_CELLS.id());
    json.setFloat("width_mm", widthMM);
    json.setFloat("height_mm", heightMM);
    json.setFloat("depth_mm", depthMM);
    json.setInt("columns", columns);
    json.setInt("rows", rows);
    json.setInt("cell_count", columns * rows);
    json.setFloat("overlap_ratio", overlap);
    json.setFloat("smooth_blend_ratio", smoothBlendRatio);
    json.setFloat("smooth_blend_world", smoothK);
    json.setFloat("cell_radius_x_world", radiusX);
    json.setFloat("cell_radius_y_world", radiusY);
    json.setFloat("cell_radius_z_world", radiusZ);
    json.setFloat("cell_pitch_x_world", pitchX);
    json.setFloat("cell_pitch_y_world", pitchY);
    json.setFloat("normalization_scale_mm", max(widthMM, max(heightMM, depthMM)));
    json.setString("field_mapping", "repeated_cell_local_with_nearest_pair_blend");
    json.setString("outer_boundary", "natural_spheroidal_scallop");
    json.setString("fusion", "polynomial_smooth_union");
    return json;
  }
}

ObservationDomain createDcrtePanelDomain() {
  if (dcrtePanelLayoutMode == DCRTEPanelLayoutMode.SPHEROID_CELLS) {
    return new SmoothSpheroidCellArrayDomain(dcrtePanelWidthMM, dcrtePanelHeightMM,
      dcrtePanelDepthMM, dcrtePanelColumns, dcrtePanelRows, dcrtePanelOverlap,
      dcrtePanelSmoothBlendRatio);
  }
  return new ContinuousPanelDomain(dcrtePanelWidthMM, dcrtePanelHeightMM, dcrtePanelDepthMM);
}

float dcrteSamplePanelCellField(SmoothSpheroidCellArrayDomain domain,
    float x, float y, float z, float[] topologyBlend) {
  float firstDistance = Float.POSITIVE_INFINITY;
  float secondDistance = Float.POSITIVE_INFINITY;
  int firstColumn = 0;
  int firstRow = 0;
  int secondColumn = 0;
  int secondRow = 0;
  for (int row = 0; row < domain.rows; row++) {
    for (int column = 0; column < domain.columns; column++) {
      float dx = (x - domain.centerX(column)) / max(0.000001f, domain.radiusX);
      float dy = (y - domain.centerY(row)) / max(0.000001f, domain.radiusY);
      float dz = z / max(0.000001f, domain.radiusZ);
      float distance = sqrt(dx * dx + dy * dy + dz * dz);
      if (distance < firstDistance) {
        secondDistance = firstDistance;
        secondColumn = firstColumn;
        secondRow = firstRow;
        firstDistance = distance;
        firstColumn = column;
        firstRow = row;
      } else if (distance < secondDistance) {
        secondDistance = distance;
        secondColumn = column;
        secondRow = row;
      }
    }
  }

  float localX = (x - domain.centerX(firstColumn)) / max(0.000001f, domain.radiusX);
  float localY = (y - domain.centerY(firstRow)) / max(0.000001f, domain.radiusY);
  float localZ = z / max(0.000001f, domain.radiusZ);
  float first = dcrteSampleFoundryField(localX, localY, localZ, topologyBlend);
  if (domain.columns * domain.rows <= 1 || !dcrteFinite(secondDistance)) return first;

  float secondX = (x - domain.centerX(secondColumn)) / max(0.000001f, domain.radiusX);
  float secondY = (y - domain.centerY(secondRow)) / max(0.000001f, domain.radiusY);
  float secondZ = localZ;
  float second = dcrteSampleFoundryField(secondX, secondY, secondZ, topologyBlend);
  float blendWidth = max(0.04f, domain.overlap * 1.6f);
  float separation = constrain((secondDistance - firstDistance) / blendWidth, 0, 1);
  float eased = separation * separation * (3.0f - 2.0f * separation);
  float secondWeight = 0.5f * (1.0f - eased);
  return lerp(first, second, secondWeight);
}

float dcrteSamplePrimitiveFoundryField(ObservationDomain domain,
    float x, float y, float z, float[] topologyBlend) {
  if (domain instanceof SmoothSpheroidCellArrayDomain) {
    return dcrteSamplePanelCellField((SmoothSpheroidCellArrayDomain)domain,
      x, y, z, topologyBlend);
  }
  return dcrteSampleFoundryField(x, y, z, topologyBlend);
}

void cycleDcrtePanelLayoutMode() {
  dcrtePanelLayoutMode = dcrtePanelLayoutMode == DCRTEPanelLayoutMode.CONTINUOUS_FIELD
    ? DCRTEPanelLayoutMode.SPHEROID_CELLS : DCRTEPanelLayoutMode.CONTINUOUS_FIELD;
  markDcrtePrimitiveStale("panel layout changed; regenerate");
}

void adjustDcrtePanelWidth(float deltaMM) {
  dcrtePanelWidthMM = constrain(dcrtePanelWidthMM + deltaMM, 60, 480);
  markDcrtePrimitiveStale("panel width changed; regenerate");
}

void adjustDcrtePanelHeight(float deltaMM) {
  dcrtePanelHeightMM = constrain(dcrtePanelHeightMM + deltaMM, 60, 480);
  markDcrtePrimitiveStale("panel height changed; regenerate");
}

void adjustDcrtePanelDepth(float deltaMM) {
  dcrtePanelDepthMM = constrain(dcrtePanelDepthMM + deltaMM, 10, 160);
  markDcrtePrimitiveStale("panel depth changed; regenerate");
}

void adjustDcrtePanelColumns(int delta) {
  dcrtePanelColumns = constrain(dcrtePanelColumns + delta, 1, 8);
  markDcrtePrimitiveStale("panel columns changed; regenerate");
}

void adjustDcrtePanelRows(int delta) {
  dcrtePanelRows = constrain(dcrtePanelRows + delta, 1, 8);
  markDcrtePrimitiveStale("panel rows changed; regenerate");
}

void adjustDcrtePanelOverlap(float delta) {
  dcrtePanelOverlap = constrain(dcrtePanelOverlap + delta, 0.05f, 0.45f);
  markDcrtePrimitiveStale("panel overlap changed; regenerate");
}
