/* DCRTE-ET Milestone 2 transparent sanitation and strict mesh-domain inspection. */

enum InvalidDomainPolicy {
  STRICT,
  UNSIGNED_PREVIEW;

  String id() { return name().toLowerCase(); }
}

class MeshDomainReport {
  ValidationStatus status = ValidationStatus.PASS;
  String sourceName = "";
  String sourceFormat = "unknown";
  String sourceHashSha256 = "";
  long sourceBytes;
  long importParseMillis;
  long sanitationMillis;
  int declaredTriangleCount;
  int parsedTriangleCount;
  int inputVertexCount;
  int outputVertexCount;
  int duplicateVerticesMerged;
  int inputTriangleCount;
  int outputTriangleCount;
  int zeroAreaTrianglesRemoved;
  int invalidIndexTrianglesRemoved;
  int duplicateTrianglesRemoved;
  int uniqueEdgeCount;
  int boundaryEdgeCount;
  int nonManifoldEdgeCount;
  int inconsistentOrientationEdgeCount;
  boolean watertight;
  boolean manifold;
  boolean consistentlyOriented;
  boolean globalWindingFlipped;
  double signedVolumeSource;
  double absoluteVolumeSource;
  double signedVolumeWorld;
  double absoluteVolumeWorld;
  float mergeTolerance;
  float areaTolerance;
  Bounds3D sourceBounds;
  Bounds3D worldBounds;
  long[] boundaryEdges = new long[0];
  long[] nonManifoldEdges = new long[0];
  long[] orientationErrorEdges = new long[0];
  ArrayList<String> errors = new ArrayList<String>();
  ArrayList<String> warnings = new ArrayList<String>();

  void addError(String code) {
    if (!errors.contains(code)) errors.add(code);
    updateStatus();
  }

  void addWarning(String code) {
    if (!warnings.contains(code)) warnings.add(code);
    updateStatus();
  }

  void updateStatus() {
    if (!errors.isEmpty()) status = ValidationStatus.FAIL;
    else if (!warnings.isEmpty()) status = ValidationStatus.PASS_WITH_WARNINGS;
    else status = ValidationStatus.PASS;
  }

  boolean strictValid() {
    return outputTriangleCount > 0 && watertight && manifold && consistentlyOriented
      && sourceBounds != null && sourceBounds.isValid()
      && dcrteFinite((float)absoluteVolumeSource) && absoluteVolumeSource > 0;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("status", status.id());
    json.setString("source_name", sourceName);
    json.setString("source_format", sourceFormat);
    json.setString("source_sha256", sourceHashSha256);
    json.setString("source_bytes", Long.toString(sourceBytes));
    json.setLong("import_parse_millis", importParseMillis);
    json.setLong("sanitation_millis", sanitationMillis);
    json.setInt("declared_triangle_count", declaredTriangleCount);
    json.setInt("parsed_triangle_count", parsedTriangleCount);
    json.setInt("input_vertex_count", inputVertexCount);
    json.setInt("output_vertex_count", outputVertexCount);
    json.setInt("duplicate_vertices_merged", duplicateVerticesMerged);
    json.setInt("input_triangle_count", inputTriangleCount);
    json.setInt("output_triangle_count", outputTriangleCount);
    json.setInt("zero_area_triangles_removed", zeroAreaTrianglesRemoved);
    json.setInt("invalid_index_triangles_removed", invalidIndexTrianglesRemoved);
    json.setInt("duplicate_triangles_removed", duplicateTrianglesRemoved);
    json.setInt("unique_edge_count", uniqueEdgeCount);
    json.setInt("boundary_edge_count", boundaryEdgeCount);
    json.setInt("nonmanifold_edge_count", nonManifoldEdgeCount);
    json.setInt("inconsistent_orientation_edge_count", inconsistentOrientationEdgeCount);
    json.setBoolean("watertight", watertight);
    json.setBoolean("manifold", manifold);
    json.setBoolean("consistently_oriented", consistentlyOriented);
    json.setBoolean("global_winding_flipped", globalWindingFlipped);
    json.setDouble("signed_volume_source", signedVolumeSource);
    json.setDouble("absolute_volume_source", absoluteVolumeSource);
    json.setDouble("signed_volume_world", signedVolumeWorld);
    json.setDouble("absolute_volume_world", absoluteVolumeWorld);
    json.setFloat("merge_tolerance", mergeTolerance);
    json.setFloat("area_tolerance", areaTolerance);
    if (sourceBounds != null) json.setJSONObject("source_bounds", sourceBounds.toJSON());
    if (worldBounds != null) json.setJSONObject("world_bounds", worldBounds.toJSON());
    json.setJSONArray("errors", dcrteStringListJSON(errors));
    json.setJSONArray("warnings", dcrteStringListJSON(warnings));
    return json;
  }
}

class MeshValidationResult {
  TriangleMeshData mesh;
  MeshDomainReport report;

  MeshValidationResult(TriangleMeshData mesh, MeshDomainReport report) {
    this.mesh = mesh;
    this.report = report;
  }
}

class DCRTEMeshSanitizer {
  MeshValidationResult sanitize(TriangleMeshData input) {
    MeshDomainReport report = new MeshDomainReport();
    if (input == null) {
      report.addError("IMPORT_EMPTY_MESH");
      return new MeshValidationResult(null, report);
    }
    report.sourceName = input.sourceName == null ? "" : input.sourceName;
    report.sourceFormat = input.sourceFormat == null ? "unknown" : input.sourceFormat;
    report.sourceHashSha256 = input.sourceHashSha256 == null ? "" : input.sourceHashSha256;
    report.sourceBytes = input.sourceBytes;
    report.declaredTriangleCount = input.declaredTriangleCount;
    report.parsedTriangleCount = input.triangleCount;
    report.inputVertexCount = input.vertexCount;
    report.inputTriangleCount = input.triangleCount;
    report.sourceBounds = input.sourceBounds;
    if (input.vertexCount == 0 || input.triangleCount == 0) {
      report.addError("IMPORT_EMPTY_MESH");
      return new MeshValidationResult(null, report);
    }
    if (input.sourceBounds == null || !input.sourceBounds.isValid()) {
      report.addError("IMPORT_INVALID_BOUNDS");
      return new MeshValidationResult(null, report);
    }

    float diagonal = sqrt(input.sourceBounds.sizeX() * input.sourceBounds.sizeX()
      + input.sourceBounds.sizeY() * input.sourceBounds.sizeY()
      + input.sourceBounds.sizeZ() * input.sourceBounds.sizeZ());
    report.mergeTolerance = max(diagonal * 0.000001f, 0.0000001f);
    report.areaTolerance = max(diagonal * diagonal * 0.000000000001f, 0.000000000001f);

    QuantizedVertexTable vertexTable = new QuantizedVertexTable(input.vertexCount);
    FloatArrayBuilder mergedVertices = new FloatArrayBuilder(input.vertices.length);
    int[] remap = new int[input.vertexCount];
    for (int i = 0; i < input.vertexCount; i++) {
      float x = input.vx(i);
      float y = input.vy(i);
      float z = input.vz(i);
      if (!dcrteFinite(x) || !dcrteFinite(y) || !dcrteFinite(z)) {
        remap[i] = -1;
        continue;
      }
      long qx = Math.round((double)x / report.mergeTolerance);
      long qy = Math.round((double)y / report.mergeTolerance);
      long qz = Math.round((double)z / report.mergeTolerance);
      int existing = vertexTable.find(qx, qy, qz);
      if (existing >= 0) {
        remap[i] = existing;
        report.duplicateVerticesMerged++;
      } else {
        int index = mergedVertices.size / 3;
        mergedVertices.add3(x, y, z);
        vertexTable.put(qx, qy, qz, index);
        remap[i] = index;
      }
    }

    float[] compactVertices = mergedVertices.toArray();
    IntArrayBuilder keptTriangles = new IntArrayBuilder(input.triangles.length);
    TriangleKeyTable triangleKeys = new TriangleKeyTable(input.triangleCount);
    for (int t = 0; t < input.triangleCount; t++) {
      int rawA = input.ia(t);
      int rawB = input.ib(t);
      int rawC = input.ic(t);
      if (rawA < 0 || rawA >= remap.length || rawB < 0 || rawB >= remap.length || rawC < 0 || rawC >= remap.length) {
        report.invalidIndexTrianglesRemoved++;
        continue;
      }
      int a = remap[rawA];
      int b = remap[rawB];
      int c = remap[rawC];
      if (a < 0 || b < 0 || c < 0) {
        report.invalidIndexTrianglesRemoved++;
        continue;
      }
      if (a == b || b == c || c == a || dcrteTriangleArea2(compactVertices, a, b, c) <= report.areaTolerance) {
        report.zeroAreaTrianglesRemoved++;
        continue;
      }
      if (!triangleKeys.addIfAbsent(a, b, c)) {
        report.duplicateTrianglesRemoved++;
        continue;
      }
      keptTriangles.add3(a, b, c);
    }

    int[] compactTriangles = keptTriangles.toArray();
    TriangleMeshData output = new TriangleMeshData(compactVertices, compactTriangles);
    output.sourceName = input.sourceName;
    output.sourceFormat = input.sourceFormat;
    output.sourceHashSha256 = input.sourceHashSha256;
    output.sourceBytes = input.sourceBytes;
    output.declaredTriangleCount = input.declaredTriangleCount;
    output.sourceNormalsPresent = input.sourceNormalsPresent;
    output.sourceBounds = computeBounds(compactVertices);
    output.worldBounds = output.sourceBounds;
    report.sourceBounds = output.sourceBounds;
    report.outputVertexCount = output.vertexCount;
    report.outputTriangleCount = output.triangleCount;

    if (report.duplicateVerticesMerged > 0) report.addWarning("MESH_DUPLICATE_VERTICES_MERGED");
    if (report.zeroAreaTrianglesRemoved > 0) report.addWarning("MESH_DEGENERATE_TRIANGLES_REMOVED");
    if (output.triangleCount == 0 || output.vertexCount == 0) {
      report.addError("IMPORT_EMPTY_MESH");
      return new MeshValidationResult(output, report);
    }

    inspectTopology(output, report);
    if (report.watertight && report.consistentlyOriented && report.signedVolumeSource < 0 && report.absoluteVolumeSource > 0) {
      for (int t = 0; t < output.triangleCount; t++) {
        int offset = t * 3;
        int swap = output.triangles[offset + 1];
        output.triangles[offset + 1] = output.triangles[offset + 2];
        output.triangles[offset + 2] = swap;
      }
      report.globalWindingFlipped = true;
      report.addWarning("MESH_GLOBAL_WINDING_FLIPPED");
      report.signedVolumeSource = dcrteSignedMeshVolume(output);
      report.absoluteVolumeSource = Math.abs(report.signedVolumeSource);
    }

    if (report.boundaryEdgeCount > 0) {
      report.addError("MESH_BOUNDARY_EDGES");
      report.addError("MESH_NOT_WATERTIGHT");
    }
    if (report.nonManifoldEdgeCount > 0) report.addError("MESH_NONMANIFOLD_EDGES");
    if (report.inconsistentOrientationEdgeCount > 0) report.addError("MESH_ORIENTATION_INCONSISTENT");
    if (!dcrteFinite((float)report.absoluteVolumeSource) || report.absoluteVolumeSource <= 0) report.addError("MESH_SIGNED_VOLUME_INVALID");
    report.updateStatus();
    return new MeshValidationResult(output, report);
  }

  void inspectTopology(TriangleMeshData mesh, MeshDomainReport report) {
    MeshEdgeTable edges = new MeshEdgeTable(mesh.triangleCount * 3);
    for (int t = 0; t < mesh.triangleCount; t++) {
      int a = mesh.ia(t);
      int b = mesh.ib(t);
      int c = mesh.ic(t);
      edges.add(a, b);
      edges.add(b, c);
      edges.add(c, a);
    }
    LongArrayBuilder boundary = new LongArrayBuilder(64);
    LongArrayBuilder nonManifold = new LongArrayBuilder(32);
    LongArrayBuilder orientation = new LongArrayBuilder(32);
    for (int i = 0; i < edges.used.length; i++) {
      if (!edges.used[i]) continue;
      int count = edges.incidence[i];
      if (count == 1) boundary.add(edges.keys[i]);
      else if (count > 2) nonManifold.add(edges.keys[i]);
      else if (count == 2 && edges.directionBalance[i] != 0) orientation.add(edges.keys[i]);
    }
    report.uniqueEdgeCount = edges.size;
    report.boundaryEdges = boundary.toArray();
    report.nonManifoldEdges = nonManifold.toArray();
    report.orientationErrorEdges = orientation.toArray();
    report.boundaryEdgeCount = report.boundaryEdges.length;
    report.nonManifoldEdgeCount = report.nonManifoldEdges.length;
    report.inconsistentOrientationEdgeCount = report.orientationErrorEdges.length;
    report.watertight = report.boundaryEdgeCount == 0 && report.nonManifoldEdgeCount == 0 && mesh.triangleCount > 0;
    report.manifold = report.nonManifoldEdgeCount == 0;
    report.consistentlyOriented = report.inconsistentOrientationEdgeCount == 0;
    report.signedVolumeSource = dcrteSignedMeshVolume(mesh);
    report.absoluteVolumeSource = Math.abs(report.signedVolumeSource);
  }
}

double dcrteTriangleArea2(float[] vertices, int ia, int ib, int ic) {
  int a = ia * 3; int b = ib * 3; int c = ic * 3;
  double ux = vertices[b] - vertices[a];
  double uy = vertices[b + 1] - vertices[a + 1];
  double uz = vertices[b + 2] - vertices[a + 2];
  double vx = vertices[c] - vertices[a];
  double vy = vertices[c + 1] - vertices[a + 1];
  double vz = vertices[c + 2] - vertices[a + 2];
  double cx = uy * vz - uz * vy;
  double cy = uz * vx - ux * vz;
  double cz = ux * vy - uy * vx;
  return Math.sqrt(cx * cx + cy * cy + cz * cz);
}

double dcrteSignedMeshVolume(TriangleMeshData mesh) {
  if (mesh == null) return 0;
  double volume6 = 0;
  for (int t = 0; t < mesh.triangleCount; t++) {
    int ai = mesh.ia(t) * 3;
    int bi = mesh.ib(t) * 3;
    int ci = mesh.ic(t) * 3;
    double ax = mesh.vertices[ai];
    double ay = mesh.vertices[ai + 1];
    double az = mesh.vertices[ai + 2];
    double bx = mesh.vertices[bi];
    double by = mesh.vertices[bi + 1];
    double bz = mesh.vertices[bi + 2];
    double cx = mesh.vertices[ci];
    double cy = mesh.vertices[ci + 1];
    double cz = mesh.vertices[ci + 2];
    volume6 += ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx);
  }
  return volume6 / 6.0;
}

JSONArray dcrteStringListJSON(ArrayList<String> values) {
  JSONArray array = new JSONArray();
  if (values == null) return array;
  for (int i = 0; i < values.size(); i++) array.setString(i, values.get(i));
  return array;
}
