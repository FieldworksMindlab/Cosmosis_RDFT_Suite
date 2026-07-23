/* DCRTE-ET Milestone 6 deterministic torus fixture and normal import round trip. */

final float DCRTE_TORUS_MAJOR_RADIUS = 0.62f;
final float DCRTE_TORUS_MINOR_RADIUS = 0.22f;
final int DCRTE_TORUS_MAJOR_SEGMENTS = 96;
final int DCRTE_TORUS_MINOR_SEGMENTS = 48;

TriangleMeshData createDcrteTorusFixtureMesh() {
  int vertexCount = DCRTE_TORUS_MAJOR_SEGMENTS * DCRTE_TORUS_MINOR_SEGMENTS;
  FloatArrayBuilder vertices = new FloatArrayBuilder(vertexCount * 3);
  for (int major = 0; major < DCRTE_TORUS_MAJOR_SEGMENTS; major++) {
    float u = TWO_PI * major / DCRTE_TORUS_MAJOR_SEGMENTS;
    float cu = cos(u);
    float su = sin(u);
    for (int minor = 0; minor < DCRTE_TORUS_MINOR_SEGMENTS; minor++) {
      float v = TWO_PI * minor / DCRTE_TORUS_MINOR_SEGMENTS;
      float radial = DCRTE_TORUS_MAJOR_RADIUS + DCRTE_TORUS_MINOR_RADIUS * cos(v);
      vertices.add3(radial * cu, DCRTE_TORUS_MINOR_RADIUS * sin(v), radial * su);
    }
  }

  IntArrayBuilder triangles = new IntArrayBuilder(
    DCRTE_TORUS_MAJOR_SEGMENTS * DCRTE_TORUS_MINOR_SEGMENTS * 6);
  for (int major = 0; major < DCRTE_TORUS_MAJOR_SEGMENTS; major++) {
    int nextMajor = (major + 1) % DCRTE_TORUS_MAJOR_SEGMENTS;
    for (int minor = 0; minor < DCRTE_TORUS_MINOR_SEGMENTS; minor++) {
      int nextMinor = (minor + 1) % DCRTE_TORUS_MINOR_SEGMENTS;
      int a = major * DCRTE_TORUS_MINOR_SEGMENTS + minor;
      int b = nextMajor * DCRTE_TORUS_MINOR_SEGMENTS + minor;
      int c = major * DCRTE_TORUS_MINOR_SEGMENTS + nextMinor;
      int d = nextMajor * DCRTE_TORUS_MINOR_SEGMENTS + nextMinor;
      triangles.add3(a, c, b);
      triangles.add3(b, c, d);
    }
  }

  TriangleMeshData mesh = new TriangleMeshData(vertices.toArray(), triangles.toArray());
  mesh.sourceName = "dcrte_torus_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount;
  return mesh;
}

JSONObject dcrteTorusFixtureMetadata() {
  JSONObject fixture = new JSONObject();
  fixture.setString("fixture_id", "dcrte_m6_torus_v1");
  fixture.setString("type", "canonical_torus");
  fixture.setString("version", "1.0-m6");
  fixture.setFloat("major_radius", DCRTE_TORUS_MAJOR_RADIUS);
  fixture.setFloat("minor_radius", DCRTE_TORUS_MINOR_RADIUS);
  fixture.setInt("major_segments", DCRTE_TORUS_MAJOR_SEGMENTS);
  fixture.setInt("minor_segments", DCRTE_TORUS_MINOR_SEGMENTS);
  fixture.setString("seam_policy", "wrapped_without_duplicate_rings");
  fixture.setString("semantic_scope", "deterministic closed-loop composition fixture");
  return fixture;
}

void loadDcrteTorusFixture() {
  try {
    TriangleMeshData generated = createDcrteTorusFixtureMesh();
    if (generated == null || !generated.isStructurallyValid()) {
      throw new Exception("generated torus is structurally invalid");
    }
    File directory = new File(sketchPath("exports/dcrte_fixtures"));
    if (!directory.exists() && !directory.mkdirs()) {
      throw new Exception("unable to create fixture output directory");
    }
    File fixture = new File(directory, "dcrte_torus_fixture.stl");
    writeDcrteBinaryStl(generated, fixture, "DCRTE-M6 canonical torus fixture v1.0");
    generated = null;
    System.gc();
    if (!loadDcrteImportedFile(fixture, true, dcrteTorusFixtureMetadata())) {
      throw new Exception("normal STL import rejected the torus fixture");
    }
    dcrteImportedStatus = dcrteCoordinateMode == DCRTECoordinateMode.INTRINSIC_AXIAL
      ? "torus loaded; closed loop needs Cartesian fabrication - use FIND PATH"
      : "torus loaded; Cartesian fabrication and composition supported";
  }
  catch (Exception error) {
    dcrteImportedErrorCode = DCRTEM6Codes.TORUS_FIXTURE_ROUNDTRIP_FAILED;
    dcrteImportedErrorMessage = error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage();
    dcrteImportedStatus = "torus fixture round trip failed";
    dcrteImportedBuildState = DCRTEImportedBuildState.MESH_INVALID;
  }
}
