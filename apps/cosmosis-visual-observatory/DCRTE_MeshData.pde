/* DCRTE-ET Milestone 2 flat imported triangle-mesh storage and compact helpers. */

class MeshImportException extends Exception {
  String code;

  MeshImportException(String code, String message) {
    super(message);
    this.code = code;
  }
}

class FloatArrayBuilder {
  float[] values;
  int size;

  FloatArrayBuilder(int initialCapacity) {
    values = new float[max(16, initialCapacity)];
  }

  void add(float value) {
    ensure(size + 1);
    values[size++] = value;
  }

  void add3(float a, float b, float c) {
    ensure(size + 3);
    values[size++] = a;
    values[size++] = b;
    values[size++] = c;
  }

  void ensure(int needed) {
    if (needed <= values.length) return;
    int capacity = values.length;
    while (capacity < needed) capacity = max(capacity + 1, capacity * 2);
    values = java.util.Arrays.copyOf(values, capacity);
  }

  float[] toArray() {
    return java.util.Arrays.copyOf(values, size);
  }
}

class IntArrayBuilder {
  int[] values;
  int size;

  IntArrayBuilder(int initialCapacity) {
    values = new int[max(16, initialCapacity)];
  }

  void add(int value) {
    ensure(size + 1);
    values[size++] = value;
  }

  void add3(int a, int b, int c) {
    ensure(size + 3);
    values[size++] = a;
    values[size++] = b;
    values[size++] = c;
  }

  void ensure(int needed) {
    if (needed <= values.length) return;
    int capacity = values.length;
    while (capacity < needed) capacity = max(capacity + 1, capacity * 2);
    values = java.util.Arrays.copyOf(values, capacity);
  }

  int[] toArray() {
    return java.util.Arrays.copyOf(values, size);
  }
}

class LongArrayBuilder {
  long[] values;
  int size;

  LongArrayBuilder(int initialCapacity) {
    values = new long[max(16, initialCapacity)];
  }

  void add(long value) {
    if (size >= values.length) values = java.util.Arrays.copyOf(values, values.length * 2);
    values[size++] = value;
  }

  long[] toArray() {
    return java.util.Arrays.copyOf(values, size);
  }
}

class TriangleMeshData {
  final float[] vertices;
  final int[] triangles;
  final int vertexCount;
  final int triangleCount;

  Bounds3D sourceBounds;
  Bounds3D worldBounds;
  String sourceName = "";
  String sourceFormat = "unknown";
  String sourceHashSha256 = "";
  long sourceBytes;
  int declaredTriangleCount;
  boolean sourceNormalsPresent;
  boolean transformed;

  TriangleMeshData(float[] vertices, int[] triangles) {
    this.vertices = vertices == null ? new float[0] : vertices;
    this.triangles = triangles == null ? new int[0] : triangles;
    this.vertexCount = this.vertices.length / 3;
    this.triangleCount = this.triangles.length / 3;
    sourceBounds = computeBounds(this.vertices);
    worldBounds = sourceBounds;
  }

  float vx(int vertexIndex) { return vertices[vertexIndex * 3]; }
  float vy(int vertexIndex) { return vertices[vertexIndex * 3 + 1]; }
  float vz(int vertexIndex) { return vertices[vertexIndex * 3 + 2]; }
  int ia(int triangleIndex) { return triangles[triangleIndex * 3]; }
  int ib(int triangleIndex) { return triangles[triangleIndex * 3 + 1]; }
  int ic(int triangleIndex) { return triangles[triangleIndex * 3 + 2]; }

  TriangleMeshData copyTransformed(MeshTransform transform) {
    if (transform == null) return null;
    float[] output = new float[vertices.length];
    float[] point = new float[3];
    for (int i = 0; i < vertexCount; i++) {
      transform.apply(vx(i), vy(i), vz(i), point);
      output[i * 3] = point[0];
      output[i * 3 + 1] = point[1];
      output[i * 3 + 2] = point[2];
    }
    TriangleMeshData copy = new TriangleMeshData(output, java.util.Arrays.copyOf(triangles, triangles.length));
    copy.sourceBounds = sourceBounds;
    copy.worldBounds = computeBounds(output);
    copy.sourceName = sourceName;
    copy.sourceFormat = sourceFormat;
    copy.sourceHashSha256 = sourceHashSha256;
    copy.sourceBytes = sourceBytes;
    copy.declaredTriangleCount = declaredTriangleCount;
    copy.sourceNormalsPresent = sourceNormalsPresent;
    copy.transformed = true;
    return copy;
  }

  boolean isStructurallyValid() {
    if (vertices.length == 0 || triangles.length == 0 || vertices.length % 3 != 0 || triangles.length % 3 != 0) return false;
    for (int i = 0; i < vertices.length; i++) if (!dcrteFinite(vertices[i])) return false;
    for (int i = 0; i < triangles.length; i++) if (triangles[i] < 0 || triangles[i] >= vertexCount) return false;
    Bounds3D bounds = transformed ? worldBounds : sourceBounds;
    return bounds != null && bounds.isValid();
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("source_name", sourceName == null ? "" : sourceName);
    json.setString("source_format", sourceFormat == null ? "unknown" : sourceFormat);
    json.setString("source_sha256", sourceHashSha256 == null ? "" : sourceHashSha256);
    json.setString("source_bytes", Long.toString(sourceBytes));
    json.setInt("declared_triangles", declaredTriangleCount);
    json.setInt("vertices", vertexCount);
    json.setInt("triangles", triangleCount);
    json.setBoolean("source_normals_present", sourceNormalsPresent);
    json.setBoolean("transformed", transformed);
    if (sourceBounds != null) json.setJSONObject("source_bounds", sourceBounds.toJSON());
    if (worldBounds != null) json.setJSONObject("world_bounds", worldBounds.toJSON());
    return json;
  }
}

Bounds3D computeBounds(float[] vertices) {
  if (vertices == null || vertices.length < 3) return new Bounds3D(0, 0, 0, 0, 0, 0);
  float minX = Float.POSITIVE_INFINITY;
  float minY = Float.POSITIVE_INFINITY;
  float minZ = Float.POSITIVE_INFINITY;
  float maxX = Float.NEGATIVE_INFINITY;
  float maxY = Float.NEGATIVE_INFINITY;
  float maxZ = Float.NEGATIVE_INFINITY;
  for (int i = 0; i + 2 < vertices.length; i += 3) {
    float x = vertices[i];
    float y = vertices[i + 1];
    float z = vertices[i + 2];
    if (!dcrteFinite(x) || !dcrteFinite(y) || !dcrteFinite(z)) continue;
    minX = min(minX, x); minY = min(minY, y); minZ = min(minZ, z);
    maxX = max(maxX, x); maxY = max(maxY, y); maxZ = max(maxZ, z);
  }
  return new Bounds3D(minX, minY, minZ, maxX, maxY, maxZ);
}

long dcrteMix64(long value) {
  value ^= value >>> 33;
  value *= 0xff51afd7ed558ccdl;
  value ^= value >>> 33;
  value *= 0xc4ceb9fe1a85ec53l;
  value ^= value >>> 33;
  return value;
}

int dcrteTableCapacity(int expectedEntries) {
  int capacity = 16;
  int target = max(1, expectedEntries) * 2;
  while (capacity < target && capacity < (1 << 29)) capacity <<= 1;
  return capacity;
}

class QuantizedVertexTable {
  long[] qx;
  long[] qy;
  long[] qz;
  int[] value;
  boolean[] used;
  int mask;

  QuantizedVertexTable(int expectedEntries) {
    int capacity = dcrteTableCapacity(expectedEntries);
    qx = new long[capacity]; qy = new long[capacity]; qz = new long[capacity];
    value = new int[capacity]; used = new boolean[capacity]; mask = capacity - 1;
  }

  int find(long x, long y, long z) {
    int slot = (int)dcrteMix64(x ^ Long.rotateLeft(y, 21) ^ Long.rotateLeft(z, 42)) & mask;
    while (used[slot]) {
      if (qx[slot] == x && qy[slot] == y && qz[slot] == z) return value[slot];
      slot = (slot + 1) & mask;
    }
    return -1;
  }

  void put(long x, long y, long z, int indexValue) {
    int slot = (int)dcrteMix64(x ^ Long.rotateLeft(y, 21) ^ Long.rotateLeft(z, 42)) & mask;
    while (used[slot]) {
      if (qx[slot] == x && qy[slot] == y && qz[slot] == z) return;
      slot = (slot + 1) & mask;
    }
    used[slot] = true; qx[slot] = x; qy[slot] = y; qz[slot] = z; value[slot] = indexValue;
  }
}

class TriangleKeyTable {
  int[] a;
  int[] b;
  int[] c;
  boolean[] used;
  int mask;

  TriangleKeyTable(int expectedEntries) {
    int capacity = dcrteTableCapacity(expectedEntries);
    a = new int[capacity]; b = new int[capacity]; c = new int[capacity];
    used = new boolean[capacity]; mask = capacity - 1;
  }

  boolean addIfAbsent(int ia, int ib, int ic) {
    int x = min(ia, min(ib, ic));
    int z = max(ia, max(ib, ic));
    int y = ia + ib + ic - x - z;
    long hash = dcrteMix64((((long)x) << 32) ^ (y & 0xffffffffL) ^ Long.rotateLeft((long)z, 17));
    int slot = (int)hash & mask;
    while (used[slot]) {
      if (a[slot] == x && b[slot] == y && c[slot] == z) return false;
      slot = (slot + 1) & mask;
    }
    used[slot] = true; a[slot] = x; b[slot] = y; c[slot] = z;
    return true;
  }
}

class MeshEdgeTable {
  long[] keys;
  int[] incidence;
  int[] directionBalance;
  boolean[] used;
  int mask;
  int size;

  MeshEdgeTable(int expectedEntries) {
    int capacity = dcrteTableCapacity(expectedEntries);
    keys = new long[capacity]; incidence = new int[capacity]; directionBalance = new int[capacity];
    used = new boolean[capacity]; mask = capacity - 1;
  }

  long edgeKey(int a, int b) {
    int lo = min(a, b);
    int hi = max(a, b);
    return ((long)lo << 32) | (hi & 0xffffffffL);
  }

  void add(int fromIndex, int toIndex) {
    long key = edgeKey(fromIndex, toIndex);
    int slot = (int)dcrteMix64(key) & mask;
    while (used[slot] && keys[slot] != key) slot = (slot + 1) & mask;
    if (!used[slot]) {
      used[slot] = true;
      keys[slot] = key;
      size++;
    }
    incidence[slot]++;
    directionBalance[slot] += fromIndex < toIndex ? 1 : -1;
  }
}

String dcrteSha256Bytes(byte[] bytes) throws Exception {
  java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
  digest.update(bytes);
  byte[] hash = digest.digest();
  StringBuilder out = new StringBuilder();
  for (int i = 0; i < hash.length; i++) {
    int value = hash[i] & 0xff;
    if (value < 16) out.append('0');
    out.append(Integer.toHexString(value));
  }
  return out.toString();
}
