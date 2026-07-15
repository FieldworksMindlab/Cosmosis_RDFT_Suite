/* DCRTE-ET Milestone 3 deterministic intrinsic-coordinate fixtures and acceptance matrix. */

class DCRTEM3TestReport extends DCRTEM25TestReport {}

enum DCRTEM3FixtureKind {
  CYLINDER,
  ROTATED_CYLINDER,
  EGG,
  ROTATED_EGG,
  BENT_CAPSULE,
  SPHERE,
  TORUS,
  Y_BRANCH,
  TWO_BODIES
}

DCRTEM3TestReport dcrteM3Tests = new DCRTEM3TestReport();

DCRTEM3TestReport runDcrteMilestone3Tests() {
  DCRTEM3TestReport tests = new DCRTEM3TestReport();
  try {
    CartesianCoordinateSystem cartesian = new CartesianCoordinateSystem();
    FieldCoordinateSample identity = cartesian.mapAtIndex(3, 4, 5, 0.125f, -0.375f, 0.625f);
    tests.check(identity.valid && identity.fieldX == 0.125f && identity.fieldY == -0.375f && identity.fieldZ == 0.625f,
      "Cartesian coordinate identity is exact");

    IntrinsicBuildResult cylinder = dcrteBuildM3Fixture(DCRTEM3FixtureKind.CYLINDER, 30);
    IntrinsicBuildResult cylinderRepeat = dcrteBuildM3Fixture(DCRTEM3FixtureKind.CYLINDER, 30);
    tests.check(dcrteM3Accepted(cylinder), "straight cylinder intrinsic build passes");
    tests.check(dcrteM3VolumesEqual(cylinder == null ? null : cylinder.volume,
      cylinderRepeat == null ? null : cylinderRepeat.volume), "intrinsic volume is deterministic");
    tests.check(cylinder != null && cylinder.frames != null && cylinder.frames.valid
      && cylinder.frames.discontinuityCount == 0, "straight cylinder transport frames are continuous");

    IntrinsicBuildResult rotatedCylinder = dcrteBuildM3Fixture(DCRTEM3FixtureKind.ROTATED_CYLINDER, 30);
    tests.check(dcrteM3Accepted(rotatedCylinder), "rotated cylinder intrinsic build passes");
    tests.check(dcrteM3Comparable(cylinder, rotatedCylinder, 0.18f), "rotated cylinder domain-relative metrics remain comparable");

    IntrinsicBuildResult egg = dcrteBuildM3Fixture(DCRTEM3FixtureKind.EGG, 30);
    IntrinsicBuildResult rotatedEgg = dcrteBuildM3Fixture(DCRTEM3FixtureKind.ROTATED_EGG, 30);
    tests.check(dcrteM3Accepted(egg), "canonical egg intrinsic build passes");
    tests.check(dcrteM3Accepted(rotatedEgg), "rotated egg intrinsic build passes");
    tests.check(dcrteM3Comparable(egg, rotatedEgg, 0.22f), "rotated egg domain-relative metrics remain comparable");

    IntrinsicBuildResult ellipticalCylinder = dcrteBuildM3FixtureWithRadialModel(
      DCRTEM3FixtureKind.CYLINDER, 30, DCRTERadialModel.ELLIPTICAL);
    tests.check(dcrteM3Accepted(ellipticalCylinder) && dcrteM3NoNonFinite(ellipticalCylinder),
      "optional elliptical radial model passes the cylinder fixture");

    IntrinsicBuildResult bent = dcrteBuildM3Fixture(DCRTEM3FixtureKind.BENT_CAPSULE, 30);
    tests.check(dcrteM3Accepted(bent), "bent capsule intrinsic build passes");
    tests.check(bent != null && bent.frames != null && bent.frames.discontinuityCount == 0,
      "bent capsule frames have no discontinuity");

    IntrinsicBuildResult sphere = dcrteBuildM3Fixture(DCRTEM3FixtureKind.SPHERE, 30);
    tests.check(sphere != null && sphere.validation != null
      && (sphere.validation.status == ValidationStatus.PASS_WITH_WARNINGS
        || sphere.validation.status == ValidationStatus.FAIL), "sphere is warned or policy-blocked");
    tests.check(sphere != null && sphere.validation != null && sphere.validation.suitability != null
      && sphere.validation.suitability.warnings.contains(DCRTEIntrinsicCodes.IC_LOW_ELONGATION),
      "sphere reports low elongation");

    IntrinsicBuildResult torus = dcrteBuildM3Fixture(DCRTEM3FixtureKind.TORUS, 30);
    IntrinsicBuildResult branch = dcrteBuildM3Fixture(DCRTEM3FixtureKind.Y_BRANCH, 30);
    IntrinsicBuildResult bodies = dcrteBuildM3Fixture(DCRTEM3FixtureKind.TWO_BODIES, 30);
    tests.check(dcrteM3Blocked(torus), "torus intrinsic mode is blocked");
    tests.check(dcrteM3Blocked(branch), "Y-branch intrinsic mode is blocked");
    tests.check(dcrteM3Blocked(bodies), "multiple dominant bodies are blocked");

    tests.check(dcrteM3NoNonFinite(cylinder) && dcrteM3NoNonFinite(egg) && dcrteM3NoNonFinite(bent),
      "accepted fixtures contain no non-finite intrinsic coordinates");
  }
  catch (Exception error) {
    tests.check(false, "M3 deterministic test exception: " + error.getClass().getSimpleName() + " " + error.getMessage());
  }
  return tests;
}

IntrinsicBuildResult dcrteBuildM3Fixture(DCRTEM3FixtureKind kind, int resolution) {
  SignedDistanceVolume sdf = dcrteCreateM3AnalyticSdf(kind, resolution);
  return new DCRTEIntrinsicCoordinateBuilder().build(sdf, null, true);
}

IntrinsicBuildResult dcrteBuildM3FixtureWithRadialModel(DCRTEM3FixtureKind kind,
    int resolution, DCRTERadialModel radialModel) {
  DCRTERadialModel previous = dcrteIntrinsicRadialModel;
  try {
    dcrteIntrinsicRadialModel = radialModel;
    return dcrteBuildM3Fixture(kind, resolution);
  }
  finally {
    dcrteIntrinsicRadialModel = previous;
  }
}

boolean dcrteM3Accepted(IntrinsicBuildResult result) {
  return result != null && result.validation != null && result.validation.exportAllowed();
}

boolean dcrteM3Blocked(IntrinsicBuildResult result) {
  return result != null && result.validation != null && result.validation.status == ValidationStatus.FAIL;
}

boolean dcrteM3NoNonFinite(IntrinsicBuildResult result) {
  return result != null && result.validation != null && result.validation.nonFiniteVoxels == 0;
}

boolean dcrteM3Comparable(IntrinsicBuildResult a, IntrinsicBuildResult b, float tolerance) {
  if (!dcrteM3Accepted(a) || !dcrteM3Accepted(b)) return false;
  float lengthScale = max(0.0001f, max(a.validation.centerlineLength, b.validation.centerlineLength));
  return abs(a.validation.centerlineLength - b.validation.centerlineLength) / lengthScale <= tolerance
    && abs(a.validation.meanConfidence - b.validation.meanConfidence) <= tolerance
    && abs(a.validation.validFraction - b.validation.validFraction) <= tolerance;
}

boolean dcrteM3VolumesEqual(IntrinsicCoordinateVolume a, IntrinsicCoordinateVolume b) {
  if (a == null || b == null || a.valid.length != b.valid.length) return false;
  for (int i = 0; i < a.valid.length; i++) {
    if (a.valid[i] != b.valid[i] || a.centerlineIndex[i] != b.centerlineIndex[i]) return false;
    if (a.valid[i] && (Float.floatToIntBits(a.s[i]) != Float.floatToIntBits(b.s[i])
        || Float.floatToIntBits(a.normalizedRadius[i]) != Float.floatToIntBits(b.normalizedRadius[i])
        || Float.floatToIntBits(a.theta[i]) != Float.floatToIntBits(b.theta[i]))) return false;
  }
  return true;
}

SignedDistanceVolume dcrteCreateM3AnalyticSdf(DCRTEM3FixtureKind kind, int resolution) {
  Bounds3D bounds = new Bounds3D(-1, -1, -1, 1, 1, 1);
  VolumeSpec spec = new VolumeSpec(resolution, resolution, resolution, bounds);
  int count = spec.voxelCount();
  float[] distance = new float[count];
  boolean[] inside = new boolean[count];
  boolean[] boundary = new boolean[count];
  float zeroBand = 0.75f * spec.minSpacing();
  for (int z = 0; z < spec.nz; z++) {
    float wz = bounds.minZ + (z + 0.5f) * spec.spacingZ();
    for (int y = 0; y < spec.ny; y++) {
      float wy = bounds.minY + (y + 0.5f) * spec.spacingY();
      for (int x = 0; x < spec.nx; x++) {
        float wx = bounds.minX + (x + 0.5f) * spec.spacingX();
        float value = dcrteM3FixtureDistance(kind, wx, wy, wz);
        int index = x + spec.nx * (y + spec.ny * z);
        distance[index] = value;
        inside[index] = value <= 0;
        boundary[index] = abs(value) <= zeroBand;
      }
    }
  }
  return new SignedDistanceVolume(spec, distance, inside, boundary, true);
}

float dcrteM3FixtureDistance(DCRTEM3FixtureKind kind, float x, float y, float z) {
  if (kind == DCRTEM3FixtureKind.ROTATED_CYLINDER || kind == DCRTEM3FixtureKind.ROTATED_EGG) {
    float cz = cos(0.67f), sz = sin(0.67f), cy = cos(-0.42f), sy = sin(-0.42f);
    float rx = cz * x + sz * y;
    float ry = -sz * x + cz * y;
    float rz = z;
    float qx = cy * rx - sy * rz;
    float qz = sy * rx + cy * rz;
    x = qx; y = ry; z = qz;
    kind = kind == DCRTEM3FixtureKind.ROTATED_CYLINDER ? DCRTEM3FixtureKind.CYLINDER : DCRTEM3FixtureKind.EGG;
  }
  if (kind == DCRTEM3FixtureKind.CYLINDER) return dcrteM3CappedCylinderDistance(x, y, z, 0.72f, 0.28f);
  if (kind == DCRTEM3FixtureKind.EGG) {
    float halfLength = 0.76f;
    float axial = constrain(x / halfLength, -1, 1);
    float profile = sqrt(max(0, 1 - axial * axial));
    float radius = (0.34f + 0.10f * (axial + 1) * 0.5f) * profile;
    float radial = sqrt(y * y + z * z);
    return max(abs(x) - halfLength, radial - radius);
  }
  if (kind == DCRTEM3FixtureKind.SPHERE) return sqrt(x*x + y*y + z*z) - 0.62f;
  if (kind == DCRTEM3FixtureKind.TORUS) {
    float q = sqrt(x*x + y*y) - 0.52f;
    return sqrt(q*q + z*z) - 0.19f;
  }
  if (kind == DCRTEM3FixtureKind.BENT_CAPSULE) {
    float best = Float.POSITIVE_INFINITY;
    for (int i = 0; i <= 56; i++) {
      float t = -1 + 2 * i / 56.0f;
      float cx = 0.68f * t;
      float cy0 = 0.23f * sin(PI * t);
      float cz0 = 0.06f * sin(TWO_PI * t);
      best = min(best, dcrteMagnitude(x - cx, y - cy0, z - cz0));
    }
    return best - 0.22f;
  }
  if (kind == DCRTEM3FixtureKind.Y_BRANCH) {
    float trunk = dcrteM3PointSegmentDistance(x, y, z, -0.75f, 0, 0, 0.02f, 0, 0) - 0.19f;
    float upper = dcrteM3PointSegmentDistance(x, y, z, 0, 0, 0, 0.73f, 0.48f, 0) - 0.18f;
    float lower = dcrteM3PointSegmentDistance(x, y, z, 0, 0, 0, 0.73f, -0.48f, 0) - 0.18f;
    return min(trunk, min(upper, lower));
  }
  if (kind == DCRTEM3FixtureKind.TWO_BODIES) {
    float a = sqrt((x/0.50f)*(x/0.50f) + ((y-0.47f)/0.30f)*((y-0.47f)/0.30f) + (z/0.30f)*(z/0.30f)) - 1;
    float b = sqrt((x/0.50f)*(x/0.50f) + ((y+0.47f)/0.30f)*((y+0.47f)/0.30f) + (z/0.30f)*(z/0.30f)) - 1;
    return min(a, b) * 0.30f;
  }
  return 1;
}

float dcrteM3CappedCylinderDistance(float x, float y, float z, float halfLength, float radius) {
  float axial = abs(x) - halfLength;
  float radial = sqrt(y*y + z*z) - radius;
  return min(max(axial, radial), 0) + sqrt(max(axial, 0)*max(axial, 0) + max(radial, 0)*max(radial, 0));
}

float dcrteM3PointSegmentDistance(float px, float py, float pz,
    float ax, float ay, float az, float bx, float by, float bz) {
  float vx = bx - ax, vy = by - ay, vz = bz - az;
  float denominator = max(0.0000001f, vx*vx + vy*vy + vz*vz);
  float t = constrain(((px-ax)*vx + (py-ay)*vy + (pz-az)*vz) / denominator, 0, 1);
  return dcrteMagnitude(px - (ax + t*vx), py - (ay + t*vy), pz - (az + t*vz));
}

void runDcrteMilestone3AcceptanceMatrix() {
  println("DCRTE-ET Milestone 3 acceptance matrix starting...");
  String[] ids = {"M3-A", "M3-B", "M3-C", "M3-D", "M3-E", "M3-F", "M3-G", "M3-H", "M3-I", "M3-J"};
  DCRTEM3FixtureKind[] fixtures = {
    DCRTEM3FixtureKind.CYLINDER, DCRTEM3FixtureKind.CYLINDER,
    DCRTEM3FixtureKind.EGG, DCRTEM3FixtureKind.EGG, DCRTEM3FixtureKind.ROTATED_EGG,
    DCRTEM3FixtureKind.BENT_CAPSULE, DCRTEM3FixtureKind.SPHERE,
    DCRTEM3FixtureKind.TORUS, DCRTEM3FixtureKind.Y_BRANCH, DCRTEM3FixtureKind.TWO_BODIES
  };
  boolean[] cartesian = {true, false, true, false, false, false, false, false, false, false};
  boolean[] expectPass = {true, true, true, true, true, true, true, false, false, false};
  JSONArray cases = new JSONArray();
  int passed = 0;
  for (int i = 0; i < ids.length; i++) {
    JSONObject entry = new JSONObject();
    entry.setString("id", ids[i]);
    entry.setString("fixture", fixtures[i].name().toLowerCase());
    entry.setString("coordinate_mode", cartesian[i] ? "cartesian" : "intrinsic_axial");
    boolean actual;
    if (cartesian[i]) {
      SignedDistanceVolume sdf = dcrteCreateM3AnalyticSdf(fixtures[i], 36);
      CartesianCoordinateSystem system = new CartesianCoordinateSystem();
      FieldCoordinateSample sample = system.mapAtIndex(1, 1, 1, 0.21f, -0.17f, 0.43f);
      actual = sdf.isValid() && sample.valid && sample.fieldX == 0.21f && sample.fieldY == -0.17f && sample.fieldZ == 0.43f;
      entry.setJSONObject("coordinates", system.toJSON());
    } else {
      IntrinsicBuildResult result = dcrteBuildM3Fixture(fixtures[i], 36);
      actual = dcrteM3Accepted(result);
      if (fixtures[i] == DCRTEM3FixtureKind.SPHERE) actual = result != null && result.validation != null
        && result.validation.status != ValidationStatus.PASS;
      entry.setJSONObject("intrinsic", result == null ? new JSONObject() : result.toJSON());
    }
    boolean casePass = expectPass[i] ? actual : !actual;
    entry.setString("expected", expectPass[i] ? "pass_or_warning" : "blocked");
    entry.setString("actual", actual ? "pass_or_warning" : "blocked");
    entry.setBoolean("pass", casePass);
    if (casePass) passed++;
    cases.setJSONObject(i, entry);
  }
  JSONObject output = new JSONObject();
  output.setString("milestone", "DCRTE-ET M3");
  output.setString("status", passed == ids.length && dcrteM3Tests.ok() ? "pass" : "fail");
  output.setInt("passed_cases", passed);
  output.setInt("total_cases", ids.length);
  output.setJSONObject("deterministic_tests", dcrteM3Tests.toJSON());
  output.setJSONArray("cases", cases);
  saveJSONObject(output, "logs/dcrte_m3_acceptance_latest.json");
  println("DCRTE-ET Milestone 3 acceptance: " + output.getString("status") + " " + passed + "/" + ids.length);
}
