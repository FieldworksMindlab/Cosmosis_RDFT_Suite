/*
 * Optional aperiodic hat-monotile field carrier and connected swatch export.
 * Geometry manifests are deterministic ports of the BSD-3-Clause hatviz
 * substitution system. This is a geometric substrate, not a material claim.
 */

final int DCRTE_MONOTILE_GEOMETRY_INDEX = 18;
final int DCRTE_MONOTILE_GRID = 48;
int dcrteMonotileLevel = 2;
int dcrteMonotileMarkMode = 1; // 0 off, 1 raised bump, 2 through-hole
int dcrteMonotileMarkedTile = -1;
String dcrteMonotileStatus = "select APERIODIC MONOTILE to inspect";
DCRTEMonotileManifest dcrteMonotileManifest = null;

class DCRTEMonotileTile {
  int index;
  String label;
  float[] x;
  float[] y;
  float cx, cy;
  float minX, maxX, minY, maxY;
}

class DCRTEMonotileSample {
  float edgeDistance = Float.POSITIVE_INFINITY;
  int containingTile = -1;
  boolean inMarkedTile = false;
}

class DCRTEMonotileManifest {
  int level;
  int tileCount;
  ArrayList<DCRTEMonotileTile> tiles = new ArrayList<DCRTEMonotileTile>();
  IntList[] cells = new IntList[DCRTE_MONOTILE_GRID * DCRTE_MONOTILE_GRID];

  DCRTEMonotileManifest() {
    for (int i = 0; i < cells.length; i++) cells[i] = new IntList();
  }
}

boolean dcrteMonotileModeActive() {
  return foundryGeometryIndex == DCRTE_MONOTILE_GEOMETRY_INDEX;
}

String dcrteMonotileMarkLabel() {
  return dcrteMonotileMarkMode == 0 ? "MARK OFF" : dcrteMonotileMarkMode == 1 ? "MARK BUMP" : "MARK HOLE";
}

void cycleDcrteMonotileLevel(int delta) {
  dcrteMonotileLevel = constrain(dcrteMonotileLevel + delta, 1, 3);
  dcrteMonotileManifest = null;
  dcrteMonotileMarkedTile = -1;
  ensureDcrteMonotileManifest();
  markCurrentFoundryStale("monotile recursion changed; regenerate");
}

void cycleDcrteMonotileMark() {
  dcrteMonotileMarkMode = (dcrteMonotileMarkMode + 1) % 3;
  markCurrentFoundryStale("monotile marker changed; regenerate");
  dcrteMonotileStatus = "level " + dcrteMonotileLevel + " / " + dcrteMonotileMarkLabel().toLowerCase();
}

boolean ensureDcrteMonotileManifest() {
  if (dcrteMonotileManifest != null && dcrteMonotileManifest.level == dcrteMonotileLevel) return true;
  try {
    JSONObject root = loadJSONObject(sketchPath("data/dcrte_monotile_L" + dcrteMonotileLevel + ".json"));
    if (root == null) throw new Exception("manifest file is missing");
    DCRTEMonotileManifest manifest = new DCRTEMonotileManifest();
    manifest.level = root.getInt("level");
    JSONArray sourceTiles = root.getJSONArray("tiles");
    JSONObject bounds = root.getJSONObject("bounds");
    float rawMinX = bounds.getFloat("min_x");
    float rawMaxX = bounds.getFloat("max_x");
    float rawMinY = bounds.getFloat("min_y");
    float rawMaxY = bounds.getFloat("max_y");
    float rawW = max(0.0001f, rawMaxX - rawMinX);
    float rawH = max(0.0001f, rawMaxY - rawMinY);
    float scale = 1.80f / max(rawW, rawH);
    float centerX = (rawMinX + rawMaxX) * 0.5f;
    float centerY = (rawMinY + rawMaxY) * 0.5f;

    for (int i = 0; i < sourceTiles.size(); i++) {
      JSONObject source = sourceTiles.getJSONObject(i);
      JSONArray vertices = source.getJSONArray("vertices");
      DCRTEMonotileTile tile = new DCRTEMonotileTile();
      tile.index = source.getInt("index");
      tile.label = source.getString("label");
      tile.x = new float[vertices.size()];
      tile.y = new float[vertices.size()];
      tile.minX = tile.minY = Float.POSITIVE_INFINITY;
      tile.maxX = tile.maxY = Float.NEGATIVE_INFINITY;
      for (int v = 0; v < vertices.size(); v++) {
        JSONArray p = vertices.getJSONArray(v);
        tile.x[v] = (p.getFloat(0) - centerX) * scale;
        tile.y[v] = (p.getFloat(1) - centerY) * scale;
        tile.cx += tile.x[v];
        tile.cy += tile.y[v];
        tile.minX = min(tile.minX, tile.x[v]);
        tile.maxX = max(tile.maxX, tile.x[v]);
        tile.minY = min(tile.minY, tile.y[v]);
        tile.maxY = max(tile.maxY, tile.y[v]);
      }
      tile.cx /= tile.x.length;
      tile.cy /= tile.y.length;
      manifest.tiles.add(tile);
    }
    manifest.tileCount = manifest.tiles.size();
    indexDcrteMonotileManifest(manifest);
    dcrteMonotileManifest = manifest;
    chooseDcrteMonotileMarkedTile();
    dcrteMonotileStatus = "level " + manifest.level + " / " + manifest.tileCount + " hats ready";
    return true;
  } catch (Exception error) {
    dcrteMonotileManifest = null;
    dcrteMonotileStatus = "manifest load failed: " + (error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage());
    println("DCRTE monotile substrate: " + dcrteMonotileStatus);
    return false;
  }
}

void indexDcrteMonotileManifest(DCRTEMonotileManifest manifest) {
  for (DCRTEMonotileTile tile : manifest.tiles) {
    int x0 = dcrteMonotileGridCoordinate(tile.minX);
    int x1 = dcrteMonotileGridCoordinate(tile.maxX);
    int y0 = dcrteMonotileGridCoordinate(tile.minY);
    int y1 = dcrteMonotileGridCoordinate(tile.maxY);
    for (int gy = y0; gy <= y1; gy++)
      for (int gx = x0; gx <= x1; gx++)
        manifest.cells[gx + gy * DCRTE_MONOTILE_GRID].append(tile.index);
  }
}

int dcrteMonotileGridCoordinate(float value) {
  return constrain(floor(map(value, -1.0f, 1.0f, 0, DCRTE_MONOTILE_GRID)), 0, DCRTE_MONOTILE_GRID - 1);
}

void chooseDcrteMonotileMarkedTile() {
  if (dcrteMonotileManifest == null || dcrteMonotileManifest.tiles.size() == 0) {
    dcrteMonotileMarkedTile = -1;
    return;
  }
  float best = Float.POSITIVE_INFINITY;
  dcrteMonotileMarkedTile = 0;
  for (DCRTEMonotileTile tile : dcrteMonotileManifest.tiles) {
    float edgeMargin = min(0.88f - abs(tile.cx), 0.88f - abs(tile.cy));
    if (edgeMargin < 0.18f) continue;
    float score = sq(tile.cx - 0.24f) + sq(tile.cy + 0.10f);
    if (score < best) {
      best = score;
      dcrteMonotileMarkedTile = tile.index;
    }
  }
}

DCRTEMonotileSample sampleDcrteMonotile(float x, float y) {
  DCRTEMonotileSample sample = new DCRTEMonotileSample();
  if (!ensureDcrteMonotileManifest()) return sample;
  int gx = dcrteMonotileGridCoordinate(x);
  int gy = dcrteMonotileGridCoordinate(y);
  boolean[] visited = new boolean[dcrteMonotileManifest.tileCount];
  for (int oy = -1; oy <= 1; oy++) {
    int sy = gy + oy;
    if (sy < 0 || sy >= DCRTE_MONOTILE_GRID) continue;
    for (int ox = -1; ox <= 1; ox++) {
      int sx = gx + ox;
      if (sx < 0 || sx >= DCRTE_MONOTILE_GRID) continue;
      IntList candidates = dcrteMonotileManifest.cells[sx + sy * DCRTE_MONOTILE_GRID];
      for (int ci = 0; ci < candidates.size(); ci++) {
        int index = candidates.get(ci);
        if (index < 0 || index >= visited.length || visited[index]) continue;
        visited[index] = true;
        DCRTEMonotileTile tile = dcrteMonotileManifest.tiles.get(index);
        if (x < tile.minX - 0.08f || x > tile.maxX + 0.08f || y < tile.minY - 0.08f || y > tile.maxY + 0.08f) continue;
        float edge = dcrteMonotileEdgeDistance(tile, x, y);
        sample.edgeDistance = min(sample.edgeDistance, edge);
        if (dcrteMonotilePointInTile(tile, x, y)) {
          sample.containingTile = tile.index;
          if (tile.index == dcrteMonotileMarkedTile) sample.inMarkedTile = true;
        }
      }
    }
  }
  return sample;
}

float dcrteMonotileEdgeDistance(DCRTEMonotileTile tile, float x, float y) {
  float best = Float.POSITIVE_INFINITY;
  for (int i = 0; i < tile.x.length; i++) {
    int j = (i + 1) % tile.x.length;
    float ax = tile.x[i], ay = tile.y[i];
    float bx = tile.x[j], by = tile.y[j];
    float dx = bx - ax, dy = by - ay;
    float t = constrain(((x - ax) * dx + (y - ay) * dy) / max(0.0000001f, dx * dx + dy * dy), 0, 1);
    best = min(best, dist(x, y, ax + dx * t, ay + dy * t));
  }
  return best;
}

boolean dcrteMonotilePointInTile(DCRTEMonotileTile tile, float x, float y) {
  boolean inside = false;
  for (int i = 0, j = tile.x.length - 1; i < tile.x.length; j = i++) {
    float denominator = tile.y[j] - tile.y[i];
    if (abs(denominator) < 0.0000001f) denominator = denominator < 0 ? -0.0000001f : 0.0000001f;
    boolean crosses = ((tile.y[i] > y) != (tile.y[j] > y))
      && (x < (tile.x[j] - tile.x[i]) * (y - tile.y[i]) / denominator + tile.x[i]);
    if (crosses) inside = !inside;
  }
  return inside;
}

float evaluateDcrteMonotileSubstrate(float x, float y, float z) {
  DCRTEMonotileSample sample = sampleDcrteMonotile(x, y);
  if (!Float.isFinite(sample.edgeDistance)) return 2.4f;
  if (dcrteMonotileMarkMode == 2 && sample.inMarkedTile) return 3.0f;
  float ribbon = dcrteMonotileLevel == 1 ? 0.055f : dcrteMonotileLevel == 2 ? 0.030f : 0.017f;
  float layers = 2.0f + dcrteMonotileLevel;
  float fixedLayer = 0.13f * sin(z * PI * layers + sample.containingTile * 0.173f);
  float value = (sample.edgeDistance - ribbon) * 4.2f + fixedLayer;
  if (dcrteMonotileMarkMode == 1 && sample.inMarkedTile) {
    DCRTEMonotileTile marked = dcrteMonotileManifest.tiles.get(dcrteMonotileMarkedTile);
    float radial = dist(x, y, marked.cx, marked.cy);
    value -= 0.30f * exp(-radial * radial / max(0.0003f, ribbon * ribbon * 5.0f));
  }
  return value;
}

void drawDcrteMonotileOverlay(int x, int y, int w, int h) {
  if (!dcrteMonotileModeActive() || !ensureDcrteMonotileManifest()) return;
  int insetW = min(250, max(190, w / 3));
  int insetH = min(210, max(150, h / 3));
  int ix = x + 14;
  int iy = y + h - insetH - 14;
  fill(3, 8, 12, 232);
  stroke(42, 88, 90);
  rect(ix, iy, insetW, insetH, 5);
  fill(145, 230, 215);
  textSize(8);
  textAlign(LEFT, TOP);
  text("APERIODIC CARRIER / LEVEL " + dcrteMonotileLevel, ix + 9, iy + 8);
  float scale = min((insetW - 20) / 2.0f, (insetH - 34) / 2.0f);
  float cx = ix + insetW * 0.5f;
  float cy = iy + 20 + (insetH - 24) * 0.5f;
  int stride = max(1, ceil(dcrteMonotileManifest.tileCount / 520.0f));
  for (int ti = 0; ti < dcrteMonotileManifest.tiles.size(); ti += stride) {
    DCRTEMonotileTile tile = dcrteMonotileManifest.tiles.get(ti);
    if (tile.index == dcrteMonotileMarkedTile && dcrteMonotileMarkMode > 0) {
      fill(dcrteMonotileMarkMode == 1 ? color(255, 196, 72, 205) : color(255, 82, 112, 210));
      stroke(255, 236, 126);
    } else {
      noFill();
      stroke(52, 205, 186, 138);
    }
    beginShape();
    for (int v = 0; v < tile.x.length; v++) vertex(cx + tile.x[v] * scale, cy - tile.y[v] * scale);
    endShape(CLOSE);
  }
  fill(132, 168, 176);
  textAlign(LEFT, BOTTOM);
  text(dcrteMonotileManifest.tileCount + " hats / " + dcrteMonotileMarkLabel().toLowerCase(), ix + 9, iy + insetH - 7);
}

void exportDcrteMonotileSwatch() {
  if (!ensureDcrteMonotileManifest()) return;
  try {
    int nx = dcrteMonotileLevel == 3 ? 168 : 144;
    int ny = nx;
    int nz = 10;
    boolean[][][] occupied = new boolean[nx][ny][nz];
    int baseLayers = 3;
    float ribbon = dcrteMonotileLevel == 1 ? 0.060f : dcrteMonotileLevel == 2 ? 0.036f : 0.021f;
    for (int ix = 0; ix < nx; ix++) {
      float x = map(ix + 0.5f, 0, nx, -0.96f, 0.96f);
      for (int iy = 0; iy < ny; iy++) {
        float y = map(iy + 0.5f, 0, ny, -0.96f, 0.96f);
        DCRTEMonotileSample sample = sampleDcrteMonotile(x, y);
        boolean marked = sample.inMarkedTile && dcrteMonotileMarkMode > 0;
        for (int iz = 0; iz < nz; iz++) {
          boolean base = iz < baseLayers;
          boolean relief = iz < baseLayers + 3 && sample.edgeDistance < ribbon;
          boolean bump = dcrteMonotileMarkMode == 1 && marked && iz < baseLayers + 5;
          boolean hole = dcrteMonotileMarkMode == 2 && marked;
          occupied[ix][iy][iz] = (base || relief || bump) && !hole;
        }
      }
    }
    SurfaceMesh swatch = dcrteMonotileVoxelMesh(occupied, 90.0f, 90.0f, 5.0f);
    int[] audit = swatch.manifoldAudit();
    if (audit[0] != 0 || audit[1] != 0 || audit[2] != 0)
      throw new Exception("swatch audit failed boundary/nonmanifold/degenerate " + audit[0] + "/" + audit[1] + "/" + audit[2]);
    String mark = dcrteMonotileMarkMode == 0 ? "plain" : dcrteMonotileMarkMode == 1 ? "bump" : "hole";
    File directory = new File(sketchPath("exports/dcrte_fixtures/aperiodic_monotile/level_" + nf(dcrteMonotileLevel, 2)));
    if (!directory.exists() && !directory.mkdirs()) throw new Exception("unable to create swatch output directory");
    File stl = new File(directory, "dcrte_monotile_swatch_L" + dcrteMonotileLevel + "_" + mark + ".stl");
    swatch.writeSTL(stl.getAbsolutePath());
    JSONObject metadata = new JSONObject();
    metadata.setString("schema", "fieldworks.dcrte.monotile_swatch.v1");
    metadata.setString("geometry", "aperiodic hat monotile connected relief swatch");
    metadata.setInt("recursion_level", dcrteMonotileLevel);
    metadata.setInt("tile_count", dcrteMonotileManifest.tileCount);
    metadata.setString("marker", mark);
    metadata.setInt("marked_tile", dcrteMonotileMarkedTile);
    metadata.setString("source", "https://github.com/isohedral/hatviz");
    metadata.setString("license", "BSD-3-Clause");
    metadata.setString("nonclaim", "Geometric substrate and fabrication swatch only; no material or physics claim.");
    metadata.setInt("triangles", swatch.tris.size());
    metadata.setString("manifold_audit", audit[0] + "/" + audit[1] + "/" + audit[2]);
    saveJSONObject(metadata, new File(directory, "dcrte_monotile_swatch_L" + dcrteMonotileLevel + "_" + mark + ".json").getAbsolutePath());
    dcrteMonotileStatus = "swatch exported: " + stl.getName();
    foundryStatus = dcrteMonotileStatus;
    println("DCRTE monotile swatch: " + stl.getAbsolutePath());
  } catch (Exception error) {
    dcrteMonotileStatus = "swatch blocked safely: " + (error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage());
    foundryStatus = dcrteMonotileStatus;
    println("DCRTE monotile swatch: " + dcrteMonotileStatus);
  }
}

SurfaceMesh dcrteMonotileVoxelMesh(boolean[][][] occupied, float width, float height, float depthMm) {
  int nx = occupied.length;
  int ny = occupied[0].length;
  int nz = occupied[0][0].length;
  float dx = width / nx, dy = height / ny, dz = depthMm / nz;
  SurfaceMesh mesh = new SurfaceMesh("dcrte_aperiodic_monotile_swatch");
  for (int ix = 0; ix < nx; ix++) for (int iy = 0; iy < ny; iy++) for (int iz = 0; iz < nz; iz++) {
    if (!occupied[ix][iy][iz]) continue;
    float x0 = -width * 0.5f + ix * dx, x1 = x0 + dx;
    float y0 = -height * 0.5f + iy * dy, y1 = y0 + dy;
    float z0 = iz * dz, z1 = z0 + dz;
    if (ix == 0 || !occupied[ix - 1][iy][iz]) mesh.addQuad(new PVector(x0,y0,z0), new PVector(x0,y0,z1), new PVector(x0,y1,z1), new PVector(x0,y1,z0));
    if (ix == nx - 1 || !occupied[ix + 1][iy][iz]) mesh.addQuad(new PVector(x1,y0,z0), new PVector(x1,y1,z0), new PVector(x1,y1,z1), new PVector(x1,y0,z1));
    if (iy == 0 || !occupied[ix][iy - 1][iz]) mesh.addQuad(new PVector(x0,y0,z0), new PVector(x1,y0,z0), new PVector(x1,y0,z1), new PVector(x0,y0,z1));
    if (iy == ny - 1 || !occupied[ix][iy + 1][iz]) mesh.addQuad(new PVector(x0,y1,z0), new PVector(x0,y1,z1), new PVector(x1,y1,z1), new PVector(x1,y1,z0));
    if (iz == 0 || !occupied[ix][iy][iz - 1]) mesh.addQuad(new PVector(x0,y0,z0), new PVector(x0,y1,z0), new PVector(x1,y1,z0), new PVector(x1,y0,z0));
    if (iz == nz - 1 || !occupied[ix][iy][iz + 1]) mesh.addQuad(new PVector(x0,y0,z1), new PVector(x1,y0,z1), new PVector(x1,y1,z1), new PVector(x0,y1,z1));
  }
  return mesh;
}

void runDcrteMonotileTests() {
  int failures = 0;
  int[] expected = {25, 169, 1156};
  int previousLevel = dcrteMonotileLevel;
  for (int level = 1; level <= 3; level++) {
    dcrteMonotileLevel = level;
    dcrteMonotileManifest = null;
    if (!ensureDcrteMonotileManifest() || dcrteMonotileManifest.tileCount != expected[level - 1]) failures++;
  }
  dcrteMonotileLevel = previousLevel;
  dcrteMonotileManifest = null;
  ensureDcrteMonotileManifest();
  float before = evaluateDcrteMonotileSubstrate(0.1f, -0.2f, 0.3f);
  float oldT = simT;
  simT += 10.0f;
  float after = evaluateDcrteMonotileSubstrate(0.1f, -0.2f, 0.3f);
  simT = oldT;
  if (!Float.isFinite(before) || abs(before - after) > 0.000001f) failures++;
  println("DCRTE APERIODIC MONOTILE TESTS " + (failures == 0 ? "PASS 5/5" : "FAIL " + failures));
}
