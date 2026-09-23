/*
  Truss Yard watertight union.

  The assembly preview is every panel placed in its final position in one file:
  geometrically correct, but a pile of overlapping closed solids rather than one
  body. Printing a mast whole needs a real union, because a slicer filling that
  pile by the even-odd rule treats double-covered overlap as outside and can
  hollow out the seams.

  Method: sample the preview's non-zero winding number on a regular grid, then
  extract the boundary with surface nets. Winding rather than parity is the
  point -- overlapping solids must count as inside instead of cancelling.

  This file is additive. It reads the preview mesh and writes a new STL; it does
  not touch the panel catalog, the sealed component list, or any existing audit,
  so the fabrication authority remains the parts in parts/.
*/

// Cube corner offsets and the twelve edges joining them, shared by the
// occupancy scan and the surface extraction.
final int[][] TRUSS_UNION_CORNERS = {
  { 0, 0, 0 }, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 },
  { 0, 0, 1 }, { 1, 0, 1 }, { 1, 1, 1 }, { 0, 1, 1 }
};
final int[][] TRUSS_UNION_EDGES = {
  { 0, 1 }, { 1, 2 }, { 2, 3 }, { 3, 0 }, { 4, 5 }, { 5, 6 },
  { 6, 7 }, { 7, 4 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 }
};

// Sampling budget. A finer grid resolves the portal slots more crisply at
// roughly cubic cost, so the requested spacing is coarsened when a model would
// otherwise blow past this.
final int TRUSS_UNION_MAX_CELLS = 14000000;

float trussUnionVoxelMM = 0.55f;
int trussUnionSmoothPasses = 3;

class TrussUnionResult {
  boolean evaluated = false;
  boolean closed = false;
  int triangles = 0;
  int holes = 0;
  int pinchEdges = 0;
  int degenerate = 0;
  float volumeMM3 = 0;
  float voxelMM = 0;
  int[] gridDimensions = { 0, 0, 0 };
  int repairedCells = 0;
  String filename = "";
  String status = "not generated";

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("evaluated", evaluated);
    json.setBoolean("closed", closed);
    json.setString("status", status);
    json.setString("stl", filename);
    json.setFloat("voxel_mm", voxelMM);
    JSONArray dims = new JSONArray();
    for (int i = 0; i < 3; i++) dims.setInt(i, gridDimensions[i]);
    json.setJSONArray("grid", dims);
    json.setInt("triangles", triangles);
    json.setInt("holes", holes);
    json.setInt("pinch_edges", pinchEdges);
    json.setInt("repaired_cells", repairedCells);
    json.setInt("degenerate_triangles", degenerate);
    json.setFloat("volume_mm3", volumeMM3);
    json.setString("authority",
      "render and whole-body printing only; the parts in parts/ remain the " +
      "fabrication authority");
    json.setString("closure_policy",
      "watertight means no holes and no four-incident-face edges. Cells whose " +
      "surface would need more vertices than the extractor gives them are " +
      "filled solid beforehand, which costs at most one voxel of material at a " +
      "pinch point; splitting them instead tears thousands of holes");
    return json;
  }
}

/* True when this cell would need more vertices than it will be given.

   The extractor places one vertex per group of solid corners. The surface
   actually crossing the cell has one sheet per (solid group, empty group) pair.
   Where there are more sheets than vertices, one vertex has to serve two sheets
   and the mesh pinches -- an edge with four incident faces, which slicers
   reject as non-manifold. */
boolean trussUnionCellPinches(int[] mask) {
  int[] parent = new int[16];       // 0-7 solid corners, 8-15 empty corners
  for (int i = 0; i < 16; i++) parent[i] = i;
  for (int e = 0; e < 12; e++) {
    int e0 = TRUSS_UNION_EDGES[e][0], e1 = TRUSS_UNION_EDGES[e][1];
    if (mask[e0] != mask[e1]) continue;
    int offset = mask[e0] == 1 ? 0 : 8;
    int ra = trussUnionFind(parent, e0 + offset);
    int rb = trussUnionFind(parent, e1 + offset);
    if (ra != rb) parent[ra] = rb;
  }
  IntList sheets = new IntList();
  IntList vertices = new IntList();
  for (int e = 0; e < 12; e++) {
    int e0 = TRUSS_UNION_EDGES[e][0], e1 = TRUSS_UNION_EDGES[e][1];
    if (mask[e0] == mask[e1]) continue;
    int solid = mask[e0] == 1 ? e0 : e1;
    int empty = mask[e0] == 1 ? e1 : e0;
    int solidRoot = trussUnionFind(parent, solid);
    int sheetKey = solidRoot * 16 + trussUnionFind(parent, empty + 8);
    if (!sheets.hasValue(sheetKey)) sheets.append(sheetKey);
    if (!vertices.hasValue(solidRoot)) vertices.append(solidRoot);
  }
  return sheets.size() > vertices.size();
}

/* Fills the pinching cells solid before extraction.

   Splitting them into several vertices instead tears the surface open
   (measured: about 2500 holes on a five-bay tunnel). Filling costs at most one
   voxel of material at a handful of pinch points, is monotone so it
   terminates, and leaves every boundary cell unambiguous. */
int trussUnionMakeManifoldSafe(byte[] inside, int nx, int ny, int nz) {
  int filledTotal = 0;
  int[] mask = new int[8];
  IntList pending = new IntList();
  for (int pass = 0; pass < 8; pass++) {
    pending.clear();
    for (int i = 0; i < nx - 1; i++)
      for (int j = 0; j < ny - 1; j++)
        for (int k = 0; k < nz - 1; k++) {
          int total = 0;
          for (int c = 0; c < 8; c++) {
            mask[c] = inside[(i + TRUSS_UNION_CORNERS[c][0]) * ny * nz +
              (j + TRUSS_UNION_CORNERS[c][1]) * nz +
              (k + TRUSS_UNION_CORNERS[c][2])];
            total += mask[c];
          }
          if (total == 0 || total == 8) continue;
          if (trussUnionCellPinches(mask)) {
            pending.append(i); pending.append(j); pending.append(k);
          }
        }
    if (pending.size() == 0) break;
    for (int p = 0; p < pending.size(); p += 3)
      for (int c = 0; c < 8; c++)
        inside[(pending.get(p) + TRUSS_UNION_CORNERS[c][0]) * ny * nz +
          (pending.get(p + 1) + TRUSS_UNION_CORNERS[c][1]) * nz +
          (pending.get(p + 2) + TRUSS_UNION_CORNERS[c][2])] = 1;
    filledTotal += pending.size() / 3;
  }
  return filledTotal;
}

int trussUnionFind(int[] parent, int value) {
  while (parent[value] != value) {
    parent[value] = parent[parent[value]];
    value = parent[value];
  }
  return value;
}

int trussUnionCornerIndex(int dx, int dy, int dz) {
  for (int i = 0; i < 8; i++)
    if (TRUSS_UNION_CORNERS[i][0] == dx && TRUSS_UNION_CORNERS[i][1] == dy &&
        TRUSS_UNION_CORNERS[i][2] == dz) return i;
  return -1;
}

int trussUnionEdgeIndex(int cornerA, int cornerB) {
  for (int i = 0; i < 12; i++) {
    if ((TRUSS_UNION_EDGES[i][0] == cornerA && TRUSS_UNION_EDGES[i][1] == cornerB) ||
        (TRUSS_UNION_EDGES[i][0] == cornerB && TRUSS_UNION_EDGES[i][1] == cornerA))
      return i;
  }
  return -1;
}

/* Builds one closed solid from an intersecting pile of closed solids. */
SurfaceMesh trussBuildUnionMesh(SurfaceMesh source, TrussUnionResult result) {
  SurfaceMesh union = new SurfaceMesh("truss_watertight_union");
  if (source == null || source.tris.size() == 0) {
    result.status = "no preview geometry";
    return union;
  }

  float voxel = max(0.05f, trussUnionVoxelMM);
  float spanX = source.previewMaxX - source.previewMinX;
  float spanY = source.previewMaxY - source.previewMinY;
  float spanZ = source.previewMaxZ - source.previewMinZ;
  if (spanX <= 0 || spanY <= 0 || spanZ <= 0) {
    result.status = "degenerate preview bounds";
    return union;
  }
  // Coarsen rather than run out of memory on a long mast.
  for (int guard = 0; guard < 24; guard++) {
    float cells = ((spanX / voxel) + 5) * ((spanY / voxel) + 5) *
      ((spanZ / voxel) + 5);
    if (cells <= TRUSS_UNION_MAX_CELLS) break;
    voxel *= 1.26f;
  }
  int pad = 2;
  float originX = source.previewMinX - pad * voxel;
  float originY = source.previewMinY - pad * voxel;
  float originZ = source.previewMinZ - pad * voxel;
  int nx = ceil(spanX / voxel) + 2 * pad + 1;
  int ny = ceil(spanY / voxel) + 2 * pad + 1;
  int nz = ceil(spanZ / voxel) + 2 * pad + 1;
  result.voxelMM = voxel;
  result.gridDimensions = new int[] { nx, ny, nz };

  // Bucket triangles by the (y, z) lines they can cross, so each scanline only
  // tests the few triangles above it.
  ArrayList<IntList> buckets = new ArrayList<IntList>();
  for (int i = 0; i < ny * nz; i++) buckets.add(null);
  for (int index = 0; index < source.tris.size(); index++) {
    MeshTri tri = source.tris.get(index);
    PVector normal = PVector.sub(tri.b, tri.a).cross(PVector.sub(tri.c, tri.a));
    // A triangle parallel to every ray contributes nothing to the winding.
    if (abs(normal.x) < 0.000000001f) continue;
    int j0 = max(0, floor((min(tri.a.y, min(tri.b.y, tri.c.y)) - originY) / voxel));
    int j1 = min(ny - 1, ceil((max(tri.a.y, max(tri.b.y, tri.c.y)) - originY) / voxel));
    int k0 = max(0, floor((min(tri.a.z, min(tri.b.z, tri.c.z)) - originZ) / voxel));
    int k1 = min(nz - 1, ceil((max(tri.a.z, max(tri.b.z, tri.c.z)) - originZ) / voxel));
    for (int j = j0; j <= j1; j++)
      for (int k = k0; k <= k1; k++) {
        int slot = j * nz + k;
        if (buckets.get(slot) == null) buckets.set(slot, new IntList());
        buckets.get(slot).append(index);
      }
  }

  byte[] inside = new byte[nx * ny * nz];
  FloatList crossX = new FloatList();
  IntList crossSign = new IntList();
  for (int j = 0; j < ny; j++) {
    float y = originY + j * voxel;
    for (int k = 0; k < nz; k++) {
      IntList candidates = buckets.get(j * nz + k);
      if (candidates == null) continue;
      crossX.clear();
      crossSign.clear();
      for (int c = 0; c < candidates.size(); c++) {
        MeshTri tri = source.tris.get(candidates.get(c));
        // Barycentric test in the y-z plane, then solve x on the triangle.
        float y0 = tri.a.y - y, z0 = tri.a.z - (originZ + k * voxel);
        float y1 = tri.b.y - y, z1 = tri.b.z - (originZ + k * voxel);
        float y2 = tri.c.y - y, z2 = tri.c.z - (originZ + k * voxel);
        float d = (z1 - z2) * (y0 - y2) + (y2 - y1) * (z0 - z2);
        if (abs(d) < 0.000000000001f) continue;
        float l0 = ((z1 - z2) * (-y2) + (y2 - y1) * (-z2)) / d;
        float l1 = ((z2 - z0) * (-y2) + (y0 - y2) * (-z2)) / d;
        float l2 = 1.0f - l0 - l1;
        if (l0 < 0 || l1 < 0 || l2 < 0) continue;
        PVector normal = PVector.sub(tri.b, tri.a).cross(PVector.sub(tri.c, tri.a));
        crossX.append(l0 * tri.a.x + l1 * tri.b.x + l2 * tri.c.x);
        crossSign.append(normal.x < 0 ? 1 : -1);
      }
      if (crossX.size() == 0) continue;
      // Sort crossings by x, carrying their signs.
      for (int a = 1; a < crossX.size(); a++)
        for (int b = a; b > 0 && crossX.get(b) < crossX.get(b - 1); b--) {
          float fv = crossX.get(b); crossX.set(b, crossX.get(b - 1)); crossX.set(b - 1, fv);
          int iv = crossSign.get(b); crossSign.set(b, crossSign.get(b - 1)); crossSign.set(b - 1, iv);
        }
      int winding = 0;
      int cursor = 0;
      int base = j * nz + k;
      for (int c = 0; c < crossX.size(); c++) {
        if (winding != 0) {
          int stop = min(nx - 1, floor((crossX.get(c) - originX) / voxel));
          for (int i = cursor; i <= stop; i++) inside[i * ny * nz + base] = 1;
        }
        winding += crossSign.get(c);
        cursor = max(cursor, max(0, ceil((crossX.get(c) - originX) / voxel)));
      }
    }
  }

  // Remove pinching cells before extraction, so the result is 2-manifold and
  // not merely closed. Slicers reject four-incident-face edges.
  result.repairedCells = trussUnionMakeManifoldSafe(inside, nx, ny, nz);

  // --- surface nets ------------------------------------------------------
  ArrayList<PVector> positions = new ArrayList<PVector>();
  IntList ownerI = new IntList(), ownerJ = new IntList(), ownerK = new IntList();
  HashMap<Long, Integer> vertexOf = new HashMap<Long, Integer>();
  int[] mask = new int[8];
  int[] parent = new int[8];

  for (int i = 0; i < nx - 1; i++)
    for (int j = 0; j < ny - 1; j++)
      for (int k = 0; k < nz - 1; k++) {
        int solidCount = 0;
        for (int c = 0; c < 8; c++) {
          int ci = i + TRUSS_UNION_CORNERS[c][0];
          int cj = j + TRUSS_UNION_CORNERS[c][1];
          int ck = k + TRUSS_UNION_CORNERS[c][2];
          mask[c] = inside[ci * ny * nz + cj * nz + ck];
          solidCount += mask[c];
        }
        if (solidCount == 0 || solidCount == 8) continue;

        // Connected groups of solid corners along cube edges. Grouping the
        // sign-changing edges by solid group keeps the output closed.
        for (int c = 0; c < 8; c++) parent[c] = c;
        for (int e = 0; e < 12; e++) {
          int e0 = TRUSS_UNION_EDGES[e][0], e1 = TRUSS_UNION_EDGES[e][1];
          if (mask[e0] == 1 && mask[e1] == 1) {
            int ra = trussUnionFind(parent, e0), rb = trussUnionFind(parent, e1);
            if (ra != rb) parent[ra] = rb;
          }
        }

        long cellKey = ((long)((i * (long)(ny - 1) + j) * (long)(nz - 1) + k)) * 16L;
        for (int root = 0; root < 8; root++) {
          if (mask[root] == 0 || trussUnionFind(parent, root) != root) continue;
          float ax = 0, ay = 0, az = 0;
          int count = 0;
          for (int e = 0; e < 12; e++) {
            int e0 = TRUSS_UNION_EDGES[e][0], e1 = TRUSS_UNION_EDGES[e][1];
            if (mask[e0] == mask[e1]) continue;
            int solid = mask[e0] == 1 ? e0 : e1;
            if (trussUnionFind(parent, solid) != root) continue;
            ax += (TRUSS_UNION_CORNERS[e0][0] + TRUSS_UNION_CORNERS[e1][0]) * 0.5f;
            ay += (TRUSS_UNION_CORNERS[e0][1] + TRUSS_UNION_CORNERS[e1][1]) * 0.5f;
            az += (TRUSS_UNION_CORNERS[e0][2] + TRUSS_UNION_CORNERS[e1][2]) * 0.5f;
            count++;
          }
          if (count == 0) continue;
          int vertexId = positions.size();
          positions.add(new PVector(
            originX + (i + ax / count) * voxel,
            originY + (j + ay / count) * voxel,
            originZ + (k + az / count) * voxel));
          ownerI.append(i); ownerJ.append(j); ownerK.append(k);
          for (int e = 0; e < 12; e++) {
            int e0 = TRUSS_UNION_EDGES[e][0], e1 = TRUSS_UNION_EDGES[e][1];
            if (mask[e0] == mask[e1]) continue;
            int solid = mask[e0] == 1 ? e0 : e1;
            if (trussUnionFind(parent, solid) != root) continue;
            vertexOf.put(cellKey + e, vertexId);
          }
        }
      }

  // One quad per sign-changing grid edge, spanning the four cells sharing it.
  // Each ring is counter-clockwise seen down its own axis, so a solid point
  // with an empty neighbour along that axis faces outward.
  ArrayList<int[]> quads = new ArrayList<int[]>();
  int[][] ring = new int[4][3];
  for (int i = 1; i < nx - 1; i++)
    for (int j = 1; j < ny - 1; j++)
      for (int k = 1; k < nz - 1; k++) {
        int here = inside[i * ny * nz + j * nz + k];
        for (int axis = 0; axis < 3; axis++) {
          int fi = i + (axis == 0 ? 1 : 0);
          int fj = j + (axis == 1 ? 1 : 0);
          int fk = k + (axis == 2 ? 1 : 0);
          if (here == inside[fi * ny * nz + fj * nz + fk]) continue;
          if (axis == 0) {
            ring[0] = new int[] { i, j - 1, k - 1 }; ring[1] = new int[] { i, j, k - 1 };
            ring[2] = new int[] { i, j, k };         ring[3] = new int[] { i, j - 1, k };
          } else if (axis == 1) {
            ring[0] = new int[] { i - 1, j, k - 1 }; ring[1] = new int[] { i - 1, j, k };
            ring[2] = new int[] { i, j, k };         ring[3] = new int[] { i, j, k - 1 };
          } else {
            ring[0] = new int[] { i - 1, j - 1, k }; ring[1] = new int[] { i, j - 1, k };
            ring[2] = new int[] { i, j, k };         ring[3] = new int[] { i - 1, j, k };
          }
          int[] quad = new int[4];
          boolean complete = true;
          for (int r = 0; r < 4; r++) {
            int nearLocal = trussUnionCornerIndex(i - ring[r][0], j - ring[r][1], k - ring[r][2]);
            int farLocal = trussUnionCornerIndex(fi - ring[r][0], fj - ring[r][1], fk - ring[r][2]);
            if (nearLocal < 0 || farLocal < 0) { complete = false; break; }
            long key = ((long)((ring[r][0] * (long)(ny - 1) + ring[r][1]) *
              (long)(nz - 1) + ring[r][2])) * 16L + trussUnionEdgeIndex(nearLocal, farLocal);
            Integer vertexId = vertexOf.get(key);
            if (vertexId == null) { complete = false; break; }
            quad[r] = vertexId;
          }
          if (!complete) continue;
          if (here == 0) {
            int swap = quad[0]; quad[0] = quad[3]; quad[3] = swap;
            swap = quad[1]; quad[1] = quad[2]; quad[2] = swap;
          }
          quads.add(quad);
        }
      }

  // Laplacian relaxation over the surface graph, each vertex clamped inside its
  // own cell so the surface cannot migrate across a rail and pinch it off.
  if (trussUnionSmoothPasses > 0 && positions.size() > 0) {
    int[] neighbourCount = new int[positions.size()];
    for (int pass = 0; pass < trussUnionSmoothPasses; pass++) {
      PVector[] accumulator = new PVector[positions.size()];
      for (int i = 0; i < accumulator.length; i++) {
        accumulator[i] = new PVector();
        neighbourCount[i] = 0;
      }
      for (int[] quad : quads)
        for (int r = 0; r < 4; r++) {
          int a = quad[r], b = quad[(r + 1) % 4];
          accumulator[a].add(positions.get(b)); neighbourCount[a]++;
          accumulator[b].add(positions.get(a)); neighbourCount[b]++;
        }
      for (int i = 0; i < positions.size(); i++) {
        if (neighbourCount[i] == 0) continue;
        PVector target = PVector.mult(accumulator[i], 0.5f / neighbourCount[i]);
        target.add(PVector.mult(positions.get(i), 0.5f));
        float loX = originX + ownerI.get(i) * voxel;
        float loY = originY + ownerJ.get(i) * voxel;
        float loZ = originZ + ownerK.get(i) * voxel;
        positions.get(i).set(
          constrain(target.x, loX, loX + voxel),
          constrain(target.y, loY, loY + voxel),
          constrain(target.z, loZ, loZ + voxel));
      }
    }
  }

  for (int[] quad : quads) {
    union.addTri(positions.get(quad[0]), positions.get(quad[1]), positions.get(quad[2]));
    union.addTri(positions.get(quad[0]), positions.get(quad[2]), positions.get(quad[3]));
  }

  int[] audit = union.manifoldAudit();
  result.evaluated = true;
  result.triangles = union.tris.size();
  result.holes = audit[0];
  result.pinchEdges = audit[1];
  result.degenerate = audit[2];
  result.volumeMM3 = trussMeshVolumeMM3(union);
  // Closure is what a slicer needs; pinch edges are reported, not gated.
  // Watertight means closed AND free of four-incident-face edges: a slicer
  // rejects the latter even when there are no holes.
  result.closed = result.triangles > 0 && result.holes == 0 &&
    result.degenerate == 0 && result.pinchEdges == 0 && result.volumeMM3 > 0;
  result.status = result.closed ?
    "WATERTIGHT at " + nf(voxel, 1, 2) + " mm" :
    "NOT WATERTIGHT / " + result.holes + " holes / " +
      result.pinchEdges + " pinch edges";
  return union;
}

float trussMeshVolumeMM3(SurfaceMesh mesh) {
  float volume = 0;
  if (mesh == null) return 0;
  for (MeshTri tri : mesh.tris) {
    volume += (tri.a.x * (tri.b.y * tri.c.z - tri.b.z * tri.c.y) -
      tri.a.y * (tri.b.x * tri.c.z - tri.b.z * tri.c.x) +
      tri.a.z * (tri.b.x * tri.c.y - tri.b.y * tri.c.x)) / 6.0f;
  }
  return volume;
}

TrussUnionResult exportTrussUnion(File runFolder, SurfaceMesh preview, String label) {
  TrussUnionResult result = new TrussUnionResult();
  if (runFolder == null || preview == null || preview.tris.size() == 0) {
    result.status = "no preview geometry";
    return result;
  }
  try {
    SurfaceMesh union = trussBuildUnionMesh(preview, result);
    if (union.tris.size() == 0) return result;
    result.filename = "triangulated_frame_" + label + "_watertight_union.stl";
    union.writeSTL(new File(runFolder, result.filename).getAbsolutePath());
  } catch (Exception error) {
    result.status = "union failed: " + error.getClass().getSimpleName();
    result.closed = false;
  }
  return result;
}
