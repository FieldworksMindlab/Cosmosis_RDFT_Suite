/* DCRTE-ET Milestone 2 generic triangle importer and safe STL implementation. */

interface TriangleMeshImporter {
  TriangleMeshData load(File file) throws MeshImportException;
  String getFormatId();
  boolean supports(File file);
}

final int DCRTE_STL_WARNING_TRIANGLES = 100000;
final int DCRTE_STL_SOFT_MAX_TRIANGLES = 500000;
final int DCRTE_STL_HARD_MAX_TRIANGLES = 2000000;
final long DCRTE_STL_HARD_MAX_BYTES = 84L + 50L * DCRTE_STL_HARD_MAX_TRIANGLES;

class STLMeshImporter implements TriangleMeshImporter {
  String getFormatId() { return "stl"; }

  boolean supports(File file) {
    if (file == null || !file.isFile()) return false;
    String name = file.getName().toLowerCase();
    return name.endsWith(".stl");
  }

  TriangleMeshData load(File file) throws MeshImportException {
    if (file == null || !file.isFile()) throw new MeshImportException("IMPORT_FILE_NOT_FOUND", "STL source was not found");
    long fileLength = file.length();
    if (fileLength < 15) throw new MeshImportException("IMPORT_PARSE_FAILURE", "STL file is too short");
    if (fileLength > DCRTE_STL_HARD_MAX_BYTES) throw new MeshImportException("IMPORT_FILE_TOO_LARGE", "STL exceeds the Milestone 2 byte limit");
    byte[] bytes;
    try {
      bytes = java.nio.file.Files.readAllBytes(file.toPath());
    }
    catch (Exception error) {
      throw new MeshImportException("IMPORT_PARSE_FAILURE", "Unable to read STL: " + error.getMessage());
    }

    String hash;
    try {
      hash = dcrteSha256Bytes(bytes);
    }
    catch (Exception error) {
      throw new MeshImportException("IMPORT_PARSE_FAILURE", "Unable to hash STL: " + error.getMessage());
    }

    TriangleMeshData mesh;
    long declared = bytes.length >= 84 ? dcrteUnsignedIntLE(bytes, 80) : -1;
    long expectedBinaryLength = declared >= 0 && declared <= Integer.MAX_VALUE
      ? 84L + 50L * declared
      : -1;
    boolean exactBinaryLength = expectedBinaryLength == bytes.length;

    if (exactBinaryLength) {
      mesh = parseBinary(bytes, (int)declared);
    } else {
      MeshImportException asciiFailure = null;
      try {
        mesh = parseASCII(bytes);
      }
      catch (MeshImportException error) {
        asciiFailure = error;
        mesh = null;
      }
      if (mesh == null) {
        if (declared >= 0 && declared <= DCRTE_STL_HARD_MAX_TRIANGLES && expectedBinaryLength > 0) {
          throw new MeshImportException("IMPORT_PARSE_FAILURE", "Binary STL length mismatch: expected " + expectedBinaryLength + " bytes, found " + bytes.length);
        }
        throw asciiFailure == null
          ? new MeshImportException("IMPORT_UNSUPPORTED_FORMAT", "File is neither valid binary nor ASCII STL")
          : asciiFailure;
      }
    }

    if (mesh.triangleCount > DCRTE_STL_HARD_MAX_TRIANGLES) {
      throw new MeshImportException("IMPORT_TRIANGLE_LIMIT", "STL exceeds the Milestone 2 triangle limit");
    }
    if (mesh.triangleCount == 0) throw new MeshImportException("IMPORT_EMPTY_MESH", "STL contains no complete triangles");
    mesh.sourceName = file.getName();
    mesh.sourceHashSha256 = hash;
    mesh.sourceBytes = bytes.length;
    if (mesh.declaredTriangleCount <= 0) mesh.declaredTriangleCount = mesh.triangleCount;
    if (mesh.sourceBounds == null || !mesh.sourceBounds.isValid()) {
      throw new MeshImportException("IMPORT_INVALID_BOUNDS", "STL has empty or zero-size bounds");
    }
    return mesh;
  }

  TriangleMeshData parseBinary(byte[] bytes, int declaredTriangles) throws MeshImportException {
    if (declaredTriangles < 0 || declaredTriangles > DCRTE_STL_HARD_MAX_TRIANGLES) {
      throw new MeshImportException("IMPORT_TRIANGLE_LIMIT", "Binary STL triangle count is outside the supported range");
    }
    long expectedLength = 84L + 50L * declaredTriangles;
    if (expectedLength != bytes.length) throw new MeshImportException("IMPORT_PARSE_FAILURE", "Binary STL byte length does not match its triangle count");
    FloatArrayBuilder vertices = new FloatArrayBuilder(min(declaredTriangles * 9, 900000));
    IntArrayBuilder triangles = new IntArrayBuilder(min(declaredTriangles * 3, 300000));
    int offset = 84;
    for (int triangle = 0; triangle < declaredTriangles; triangle++) {
      offset += 12;
      int baseVertex = vertices.size / 3;
      for (int vertex = 0; vertex < 3; vertex++) {
        float x = dcrteFloatLE(bytes, offset); offset += 4;
        float y = dcrteFloatLE(bytes, offset); offset += 4;
        float z = dcrteFloatLE(bytes, offset); offset += 4;
        if (!dcrteFinite(x) || !dcrteFinite(y) || !dcrteFinite(z)) {
          throw new MeshImportException("IMPORT_NONFINITE_VERTEX", "Binary STL contains a non-finite vertex at triangle " + triangle);
        }
        vertices.add3(x, y, z);
      }
      triangles.add3(baseVertex, baseVertex + 1, baseVertex + 2);
      offset += 2;
    }
    TriangleMeshData mesh = new TriangleMeshData(vertices.toArray(), triangles.toArray());
    mesh.sourceFormat = "binary_stl";
    mesh.declaredTriangleCount = declaredTriangles;
    mesh.sourceNormalsPresent = true;
    return mesh;
  }

  TriangleMeshData parseASCII(byte[] bytes) throws MeshImportException {
    FloatArrayBuilder vertices = new FloatArrayBuilder(4096);
    IntArrayBuilder triangles = new IntArrayBuilder(2048);
    int lineNumber = 0;
    boolean inFacet = false;
    int facetVertexCount = 0;
    int facetStartVertex = 0;
    boolean sawFacet = false;
    try {
      java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(
        new java.io.ByteArrayInputStream(bytes), java.nio.charset.StandardCharsets.UTF_8));
      String line;
      while ((line = reader.readLine()) != null) {
        lineNumber++;
        String trimmed = line.trim();
        if (trimmed.length() == 0) continue;
        String lower = trimmed.toLowerCase(java.util.Locale.ROOT);
        if (lower.startsWith("facet")) {
          if (inFacet) throw new MeshImportException("IMPORT_PARSE_FAILURE", "Nested ASCII facet at line " + lineNumber);
          inFacet = true;
          sawFacet = true;
          facetVertexCount = 0;
          facetStartVertex = vertices.size / 3;
        } else if (lower.startsWith("vertex")) {
          if (!inFacet) throw new MeshImportException("IMPORT_PARSE_FAILURE", "ASCII vertex outside facet at line " + lineNumber);
          String[] tokens = trimmed.split("\\s+");
          if (tokens.length < 4) throw new MeshImportException("IMPORT_PARSE_FAILURE", "Incomplete ASCII vertex at line " + lineNumber);
          float x = Float.parseFloat(tokens[1]);
          float y = Float.parseFloat(tokens[2]);
          float z = Float.parseFloat(tokens[3]);
          if (!dcrteFinite(x) || !dcrteFinite(y) || !dcrteFinite(z)) {
            throw new MeshImportException("IMPORT_NONFINITE_VERTEX", "ASCII STL contains a non-finite vertex at line " + lineNumber);
          }
          if (facetVertexCount >= 3) throw new MeshImportException("IMPORT_PARSE_FAILURE", "ASCII facet has more than three vertices at line " + lineNumber);
          vertices.add3(x, y, z);
          facetVertexCount++;
        } else if (lower.startsWith("endfacet")) {
          if (!inFacet || facetVertexCount != 3) throw new MeshImportException("IMPORT_PARSE_FAILURE", "Incomplete ASCII facet at line " + lineNumber);
          triangles.add3(facetStartVertex, facetStartVertex + 1, facetStartVertex + 2);
          inFacet = false;
          if (triangles.size / 3 > DCRTE_STL_HARD_MAX_TRIANGLES) {
            throw new MeshImportException("IMPORT_TRIANGLE_LIMIT", "ASCII STL exceeds the Milestone 2 triangle limit");
          }
        }
      }
      reader.close();
    }
    catch (MeshImportException error) {
      throw error;
    }
    catch (NumberFormatException error) {
      throw new MeshImportException("IMPORT_PARSE_FAILURE", "Invalid ASCII number at line " + lineNumber);
    }
    catch (Exception error) {
      throw new MeshImportException("IMPORT_PARSE_FAILURE", "ASCII STL parse failed at line " + lineNumber + ": " + error.getMessage());
    }
    if (!sawFacet || inFacet || triangles.size == 0) {
      throw new MeshImportException("IMPORT_PARSE_FAILURE", "ASCII STL contains no complete facets");
    }
    TriangleMeshData mesh = new TriangleMeshData(vertices.toArray(), triangles.toArray());
    mesh.sourceFormat = "ascii_stl";
    mesh.declaredTriangleCount = mesh.triangleCount;
    mesh.sourceNormalsPresent = true;
    return mesh;
  }
}

long dcrteUnsignedIntLE(byte[] bytes, int offset) {
  if (bytes == null || offset < 0 || offset + 4 > bytes.length) return -1;
  return ((long)bytes[offset] & 0xffL)
    | (((long)bytes[offset + 1] & 0xffL) << 8)
    | (((long)bytes[offset + 2] & 0xffL) << 16)
    | (((long)bytes[offset + 3] & 0xffL) << 24);
}

float dcrteFloatLE(byte[] bytes, int offset) throws MeshImportException {
  if (offset < 0 || offset + 4 > bytes.length) throw new MeshImportException("IMPORT_PARSE_FAILURE", "Unexpected end of binary STL");
  int bits = (bytes[offset] & 0xff)
    | ((bytes[offset + 1] & 0xff) << 8)
    | ((bytes[offset + 2] & 0xff) << 16)
    | ((bytes[offset + 3] & 0xff) << 24);
  return Float.intBitsToFloat(bits);
}
