/* DCRTE-ET Milestone 2 canonical ovoid fixture and deterministic binary STL writer. */

final float DCRTE_EGG_HALF_HEIGHT = 1.20f;
final float DCRTE_EGG_BASE_RADIUS = 0.78f;
final float DCRTE_EGG_ASYMMETRY = 0.18f;
final int DCRTE_EGG_LATITUDE_SEGMENTS = 64;
final int DCRTE_EGG_LONGITUDE_SEGMENTS = 96;

TriangleMeshData createDcrteEggFixtureMesh() {
  return createDcrteEggMesh(DCRTE_EGG_HALF_HEIGHT, DCRTE_EGG_BASE_RADIUS, DCRTE_EGG_ASYMMETRY,
    DCRTE_EGG_LATITUDE_SEGMENTS, DCRTE_EGG_LONGITUDE_SEGMENTS);
}

TriangleMeshData createDcrteEggMesh(float halfHeight, float baseRadius, float asymmetry,
    int latitudeSegments, int longitudeSegments) {
  int ringCount = latitudeSegments - 1;
  int vertexCount = 2 + ringCount * longitudeSegments;
  FloatArrayBuilder vertices = new FloatArrayBuilder(vertexCount * 3);
  vertices.add3(0, halfHeight, 0);
  for (int latitude = 1; latitude < latitudeSegments; latitude++) {
    float u = PI * latitude / latitudeSegments;
    float y = halfHeight * cos(u);
    float radial = baseRadius * sin(u) * (1.0f - asymmetry * cos(u));
    for (int longitude = 0; longitude < longitudeSegments; longitude++) {
      float v = TWO_PI * longitude / longitudeSegments;
      vertices.add3(radial * cos(v), y, radial * sin(v));
    }
  }
  int bottom = vertices.size / 3;
  vertices.add3(0, -halfHeight, 0);

  IntArrayBuilder triangles = new IntArrayBuilder((2 * longitudeSegments * ringCount) * 3);
  int firstRing = 1;
  for (int longitude = 0; longitude < longitudeSegments; longitude++) {
    int current = firstRing + longitude;
    int next = firstRing + (longitude + 1) % longitudeSegments;
    triangles.add3(0, next, current);
  }
  for (int ring = 0; ring < ringCount - 1; ring++) {
    int upper = firstRing + ring * longitudeSegments;
    int lower = upper + longitudeSegments;
    for (int longitude = 0; longitude < longitudeSegments; longitude++) {
      int nextLongitude = (longitude + 1) % longitudeSegments;
      int a = upper + longitude;
      int b = upper + nextLongitude;
      int c = lower + longitude;
      int d = lower + nextLongitude;
      triangles.add3(a, b, c);
      triangles.add3(b, d, c);
    }
  }
  int lastRing = firstRing + (ringCount - 1) * longitudeSegments;
  for (int longitude = 0; longitude < longitudeSegments; longitude++) {
    int current = lastRing + longitude;
    int next = lastRing + (longitude + 1) % longitudeSegments;
    triangles.add3(bottom, current, next);
  }
  TriangleMeshData mesh = new TriangleMeshData(vertices.toArray(), triangles.toArray());
  mesh.sourceName = "dcrte_egg_fixture.stl";
  mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount;
  return mesh;
}

JSONObject dcrteEggFixtureMetadata() {
  JSONObject fixture = new JSONObject();
  fixture.setString("type", "canonical_egg");
  fixture.setString("version", "1.0");
  fixture.setFloat("half_height", DCRTE_EGG_HALF_HEIGHT);
  fixture.setFloat("base_radius", DCRTE_EGG_BASE_RADIUS);
  fixture.setFloat("asymmetry", DCRTE_EGG_ASYMMETRY);
  fixture.setInt("latitude_segments", DCRTE_EGG_LATITUDE_SEGMENTS);
  fixture.setInt("longitude_segments", DCRTE_EGG_LONGITUDE_SEGMENTS);
  fixture.setString("semantic_scope", "deterministic computational ovoid fixture");
  return fixture;
}

void loadDcrteEggFixture() {
  try {
    TriangleMeshData generated = createDcrteEggFixtureMesh();
    File directory = new File(sketchPath("exports/dcrte_fixtures"));
    if (!directory.exists() && !directory.mkdirs()) throw new Exception("unable to create fixture output directory");
    File fixture = new File(directory, "dcrte_egg_fixture.stl");
    writeDcrteBinaryStl(generated, fixture, "DCRTE-M2 canonical egg fixture v1.0");
    generated = null;
    System.gc();
    loadDcrteImportedFile(fixture, true, dcrteEggFixtureMetadata());
  }
  catch (Exception error) {
    dcrteImportedErrorCode = "IMPORT_PARSE_FAILURE";
    dcrteImportedErrorMessage = error.getMessage();
    dcrteImportedStatus = "egg fixture round trip failed";
    dcrteImportedBuildState = DCRTEImportedBuildState.MESH_INVALID;
  }
}

void writeDcrteBinaryStl(TriangleMeshData mesh, File file, String headerText) throws Exception {
  if (mesh == null || mesh.triangleCount <= 0) throw new Exception("cannot write empty STL fixture");
  long byteCount = 84L + 50L * mesh.triangleCount;
  if (byteCount > Integer.MAX_VALUE) throw new Exception("fixture STL is too large for deterministic writer");
  java.nio.ByteBuffer buffer = java.nio.ByteBuffer.allocate((int)byteCount).order(java.nio.ByteOrder.LITTLE_ENDIAN);
  byte[] header = new byte[80];
  byte[] headerSource = (headerText == null ? "DCRTE-ET fixture" : headerText).getBytes(java.nio.charset.StandardCharsets.US_ASCII);
  System.arraycopy(headerSource, 0, header, 0, min(header.length, headerSource.length));
  buffer.put(header);
  buffer.putInt(mesh.triangleCount);
  for (int t = 0; t < mesh.triangleCount; t++) {
    int ai = mesh.ia(t) * 3;
    int bi = mesh.ib(t) * 3;
    int ci = mesh.ic(t) * 3;
    float ax = mesh.vertices[ai]; float ay = mesh.vertices[ai + 1]; float az = mesh.vertices[ai + 2];
    float bx = mesh.vertices[bi]; float by = mesh.vertices[bi + 1]; float bz = mesh.vertices[bi + 2];
    float cx = mesh.vertices[ci]; float cy = mesh.vertices[ci + 1]; float cz = mesh.vertices[ci + 2];
    float ux = bx - ax; float uy = by - ay; float uz = bz - az;
    float vx = cx - ax; float vy = cy - ay; float vz = cz - az;
    float nx = uy * vz - uz * vy;
    float ny = uz * vx - ux * vz;
    float nz = ux * vy - uy * vx;
    float magnitude = sqrt(nx * nx + ny * ny + nz * nz);
    if (magnitude > 0.0000001f) { nx /= magnitude; ny /= magnitude; nz /= magnitude; }
    else { nx = 0; ny = 0; nz = 0; }
    buffer.putFloat(nx); buffer.putFloat(ny); buffer.putFloat(nz);
    buffer.putFloat(ax); buffer.putFloat(ay); buffer.putFloat(az);
    buffer.putFloat(bx); buffer.putFloat(by); buffer.putFloat(bz);
    buffer.putFloat(cx); buffer.putFloat(cy); buffer.putFloat(cz);
    buffer.putShort((short)0);
  }
  java.nio.file.Files.write(file.toPath(), buffer.array());
}

void writeDcrteAsciiStl(TriangleMeshData mesh, File file, String solidName) throws Exception {
  java.io.PrintWriter writer = new java.io.PrintWriter(new java.io.OutputStreamWriter(
    new java.io.FileOutputStream(file), java.nio.charset.StandardCharsets.UTF_8));
  String name = solidName == null ? "dcrte_fixture" : solidName.replaceAll("[^A-Za-z0-9_-]", "_");
  writer.println("solid " + name);
  for (int t = 0; t < mesh.triangleCount; t++) {
    int ai = mesh.ia(t) * 3; int bi = mesh.ib(t) * 3; int ci = mesh.ic(t) * 3;
    writer.println("  facet normal 0 0 0");
    writer.println("    outer loop");
    writer.println("      vertex " + mesh.vertices[ai] + " " + mesh.vertices[ai + 1] + " " + mesh.vertices[ai + 2]);
    writer.println("      vertex " + mesh.vertices[bi] + " " + mesh.vertices[bi + 1] + " " + mesh.vertices[bi + 2]);
    writer.println("      vertex " + mesh.vertices[ci] + " " + mesh.vertices[ci + 1] + " " + mesh.vertices[ci + 2]);
    writer.println("    endloop");
    writer.println("  endfacet");
  }
  writer.println("endsolid " + name);
  writer.close();
}
