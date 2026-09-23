/*
  Aperiodic atlas provider for Geodesic Salon.

  The Hat and Penrose systems are logical source atlases. Fabrication remains
  on the Salon's audited triangular carrier, so these modes inherit the same
  manifold, miter, KICAS, portal, and guide contracts as established kits.
  This is an aperiodic-derived curved shell, not a claim that a planar tiling
  embeds on a sphere without chart seams or distortion.
*/

class GeodesicAperiodicSample {
  int tileId = -1;
  String kind = "UNRESOLVED";
  float edgeDistance = Float.POSITIVE_INFINITY;
}

class GeodesicAperiodicChartSample {
  int chartId = -1;
  float u = 0;
  float v = 0;
  float distortion = 0;
}

HashMap<Integer, DCRTEMonotileManifest> geodesicHatAtlasCache =
  new HashMap<Integer, DCRTEMonotileManifest>();

DCRTEMonotileManifest geodesicLoadHatAtlas(int recursion) {
  recursion = constrain(recursion, 1, 3);
  if (geodesicHatAtlasCache.containsKey(recursion))
    return geodesicHatAtlasCache.get(recursion);
  try {
    JSONObject root = loadJSONObject(sketchPath(
      "data/dcrte_monotile_L" + recursion + ".json"));
    if (root == null) throw new Exception("Hat manifest missing");
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
    float atlasScale = 1.90f / max(rawW, rawH);
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
        JSONArray point = vertices.getJSONArray(v);
        tile.x[v] = (point.getFloat(0) - centerX) * atlasScale;
        tile.y[v] = (point.getFloat(1) - centerY) * atlasScale;
        tile.cx += tile.x[v];
        tile.cy += tile.y[v];
        tile.minX = min(tile.minX, tile.x[v]);
        tile.maxX = max(tile.maxX, tile.x[v]);
        tile.minY = min(tile.minY, tile.y[v]);
        tile.maxY = max(tile.maxY, tile.y[v]);
      }
      tile.cx /= max(1, tile.x.length);
      tile.cy /= max(1, tile.y.length);
      manifest.tiles.add(tile);
    }
    manifest.tileCount = manifest.tiles.size();
    indexDcrteMonotileManifest(manifest);
    geodesicHatAtlasCache.put(recursion, manifest);
    return manifest;
  } catch (Exception error) {
    println("GEODESIC APERIODIC HAT LOAD FAILED / " + error.getMessage());
    return null;
  }
}

GeodesicAperiodicChartSample geodesicAperiodicCubeChart(PVector point) {
  GeodesicAperiodicChartSample sample = new GeodesicAperiodicChartSample();
  PVector p = point.copy();
  if (p.magSq() < 0.0000001f) return sample;
  p.normalize();
  float ax = abs(p.x), ay = abs(p.y), az = abs(p.z);
  float divisor;
  if (ax >= ay && ax >= az) {
    divisor = max(0.000001f, ax);
    if (p.x >= 0) {
      sample.chartId = 0; sample.u = -p.z / divisor; sample.v = p.y / divisor;
    } else {
      sample.chartId = 1; sample.u = p.z / divisor; sample.v = p.y / divisor;
    }
  } else if (ay >= ax && ay >= az) {
    divisor = max(0.000001f, ay);
    if (p.y >= 0) {
      sample.chartId = 2; sample.u = p.x / divisor; sample.v = -p.z / divisor;
    } else {
      sample.chartId = 3; sample.u = p.x / divisor; sample.v = p.z / divisor;
    }
  } else {
    divisor = max(0.000001f, az);
    if (p.z >= 0) {
      sample.chartId = 4; sample.u = p.x / divisor; sample.v = p.y / divisor;
    } else {
      sample.chartId = 5; sample.u = -p.x / divisor; sample.v = p.y / divisor;
    }
  }
  sample.distortion = sqrt(1.0f + sample.u * sample.u +
    sample.v * sample.v) - 1.0f;
  return sample;
}

PVector geodesicAperiodicChartCoordinate(GeodesicAperiodicChartSample chart,
  float phase) {
  float chartRotation = chart.chartId * 0.61803398875f + phase * TWO_PI;
  float cs = cos(chartRotation), sn = sin(chartRotation);
  float u = chart.u * 0.78f;
  float v = chart.v * 0.78f;
  return new PVector(u * cs - v * sn, u * sn + v * cs);
}

GeodesicAperiodicSample geodesicSampleHat(int recursion, int chartId,
  float u, float v) {
  GeodesicAperiodicSample sample = new GeodesicAperiodicSample();
  DCRTEMonotileManifest manifest = geodesicLoadHatAtlas(recursion);
  if (manifest == null || manifest.tiles.size() == 0) return sample;
  float nearest = Float.POSITIVE_INFINITY;
  DCRTEMonotileTile nearestTile = null;
  for (DCRTEMonotileTile tile : manifest.tiles) {
    float centerDistance = sq(u - tile.cx) + sq(v - tile.cy);
    if (centerDistance < nearest) {
      nearest = centerDistance;
      nearestTile = tile;
    }
    if (u < tile.minX - 0.01f || u > tile.maxX + 0.01f ||
        v < tile.minY - 0.01f || v > tile.maxY + 0.01f) continue;
    sample.edgeDistance = min(sample.edgeDistance,
      dcrteMonotileEdgeDistance(tile, u, v));
    if (dcrteMonotilePointInTile(tile, u, v)) {
      sample.tileId = chartId * 100000 + tile.index;
      sample.kind = tile.label == null ? "HAT" : tile.label;
      return sample;
    }
  }
  if (nearestTile != null) {
    sample.tileId = chartId * 100000 + nearestTile.index;
    sample.kind = nearestTile.label == null ? "HAT NEAREST" :
      nearestTile.label + " NEAREST";
  }
  return sample;
}

int geodesicAperiodicHash(int value) {
  value ^= value >>> 16;
  value *= 0x7feb352d;
  value ^= value >>> 15;
  value *= (int)0x846ca68bL;
  value ^= value >>> 16;
  return value;
}

GeodesicAperiodicSample geodesicSamplePenrose(int recursion, int chartId,
  float u, float v, float phase) {
  GeodesicAperiodicSample sample = new GeodesicAperiodicSample();
  int scale = 2 + recursion * 2;
  int hash = 0x45d9f3b ^ chartId * 7919;
  int parity = 0;
  float closest = Float.POSITIVE_INFINITY;
  for (int k = 0; k < 5; k++) {
    float angle = TWO_PI * k / 5.0f;
    float offset = 0.17320508f * k + phase * (0.37f + k * 0.071f);
    float coordinate = (u * cos(angle) + v * sin(angle)) * scale + offset;
    int band = floor(coordinate);
    float fractional = coordinate - floor(coordinate);
    closest = min(closest, min(fractional, 1.0f - fractional) / scale);
    hash = geodesicAperiodicHash(hash ^ (band + 2048) * (31 + k * 12));
    parity += abs(band) * (k + 1);
  }
  sample.tileId = chartId * 100000 + (hash & 0x0000ffff);
  sample.kind = (parity & 1) == 0 ? "THICK RHOMB" : "THIN RHOMB";
  sample.edgeDistance = closest;
  return sample;
}

GeodesicModel buildGeodesicAperiodicModel(GeodesicAperiodicFamily family,
  GeodesicExtentMode extent, int recursion, float radius, float cutRatio,
  float phase) {
  recursion = constrain(recursion, 1, family.maxRecursion());
  int carrierFrequency = constrain(recursion + 2, 3, 7);
  GeodesicModel model = buildGeodesicModel(GeodesicSeedFamily.ICOSAHEDRAL,
    extent, carrierFrequency, radius, cutRatio, GeodesicFormModifier.NONE, 0);
  model.topologyMode = GeodesicTopologyMode.APERIODIC;
  model.aperiodicFamily = family;
  model.aperiodicRecursion = recursion;
  model.topologyProvider = family == GeodesicAperiodicFamily.HAT ?
    "exact Hat substitution manifest / six-chart atlas" :
    "Penrose P3 de Bruijn pentagrid / six-chart atlas";
  model.topologyProvenance = family == GeodesicAperiodicFamily.HAT ?
    "Hat manifests ported from isohedral/hatviz BSD-3-Clause" :
    "deterministic five-family de Bruijn pentagrid classification";
  HashSet<Integer> charts = new HashSet<Integer>();
  HashSet<Integer> logicalTiles = new HashSet<Integer>();
  for (GeodesicFace face : model.faces) {
    GeodesicAperiodicChartSample chart =
      geodesicAperiodicCubeChart(face.centroid);
    PVector local = geodesicAperiodicChartCoordinate(chart, phase);
    GeodesicAperiodicSample source = family == GeodesicAperiodicFamily.HAT ?
      geodesicSampleHat(recursion, chart.chartId, local.x, local.y) :
      geodesicSamplePenrose(recursion, chart.chartId, local.x, local.y, phase);
    face.sourceChartId = chart.chartId;
    face.sourceU = local.x;
    face.sourceV = local.y;
    face.sourceDistortion = chart.distortion;
    face.sourceTileId = source.tileId;
    face.sourceTileKind = source.kind;
    charts.add(chart.chartId);
    logicalTiles.add(source.tileId);
    model.aperiodicMaxDistortion = max(model.aperiodicMaxDistortion,
      chart.distortion);
  }
  for (GeodesicFace face : model.faces) {
    for (int neighborId : face.neighbors) {
      if (neighborId < 0) continue;
      GeodesicFace neighbor = model.faces.get(neighborId);
      if (neighbor.sourceChartId != face.sourceChartId) {
        face.sourceDefect = true;
        break;
      }
    }
    if (face.sourceDefect) model.aperiodicDefectFaces++;
  }
  model.aperiodicChartCount = charts.size();
  model.aperiodicLogicalTiles = logicalTiles.size();
  model.fingerprint = model.fingerprint + "-A" +
    hex(geodesicAperiodicHash(family.ordinal() * 1000003 +
    recursion * 1009 + round(phase * 10000) +
    model.aperiodicLogicalTiles * 31), 8);
  return model;
}

boolean geodesicAperiodicSourceBoundary(GeodesicModel model,
  GeodesicEdge edge) {
  if (model == null || model.topologyMode != GeodesicTopologyMode.APERIODIC ||
      edge.faceA < 0 || edge.faceB < 0) return false;
  GeodesicFace a = model.faces.get(edge.faceA);
  GeodesicFace b = model.faces.get(edge.faceB);
  return a.sourceTileId != b.sourceTileId;
}

boolean geodesicAperiodicChartBoundary(GeodesicModel model,
  GeodesicEdge edge) {
  if (model == null || model.topologyMode != GeodesicTopologyMode.APERIODIC ||
      edge.faceA < 0 || edge.faceB < 0) return false;
  return model.faces.get(edge.faceA).sourceChartId !=
    model.faces.get(edge.faceB).sourceChartId;
}

int geodesicAperiodicDisplayColor(GeodesicFace face,
  GeodesicAperiodicOverlay overlay) {
  if (overlay == GeodesicAperiodicOverlay.CHART) {
    int[] palette = {
      color(30, 205, 188), color(78, 155, 238), color(231, 83, 164),
      color(255, 190, 55), color(112, 221, 91), color(154, 104, 225)
    };
    return palette[constrain(face.sourceChartId, 0, palette.length - 1)];
  }
  if (overlay == GeodesicAperiodicOverlay.DISTORTION) {
    float t = constrain(face.sourceDistortion / 0.62f, 0, 1);
    return lerpColor(color(32, 210, 190), color(255, 86, 103), t);
  }
  if (overlay == GeodesicAperiodicOverlay.DEFECT) {
    return face.sourceDefect ? color(255, 72, 92) : color(35, 79, 88);
  }
  int hashed = geodesicAperiodicHash(face.sourceTileId);
  int[] palette = {
    color(29, 205, 188), color(74, 154, 238), color(231, 83, 164),
    color(255, 195, 58), color(112, 223, 93), color(151, 98, 225),
    color(206, 225, 235), color(84, 98, 124)
  };
  return palette[(hashed & 0x7fffffff) % palette.length];
}

JSONObject geodesicAperiodicAtlasJSON(GeodesicModel model) {
  JSONObject json = new JSONObject();
  json.setString("schema", "fieldworks.geodesic_salon.aperiodic_atlas.v1");
  if (model == null || model.topologyMode != GeodesicTopologyMode.APERIODIC) {
    json.setBoolean("active", false);
    return json;
  }
  json.setBoolean("active", true);
  json.setString("family", model.aperiodicFamily.label());
  json.setString("provider", model.topologyProvider);
  json.setString("provenance", model.topologyProvenance);
  json.setString("surface_contract",
    "aperiodic-derived curved shell on audited triangular carrier");
  json.setString("extent", model.extent.label());
  json.setString("export_policy",
    "dome qualified through carrier boundary contract; sphere export locked pending explicit atlas closure qualification");
  json.setBoolean("sphere_export_qualified", false);
  json.setString("closure_note",
    "six planar charts require explicit seams and distortion on curved surfaces");
  json.setInt("recursion", model.aperiodicRecursion);
  json.setInt("chart_capacity", 6);
  json.setInt("chart_count", model.aperiodicChartCount);
  json.setInt("logical_tile_count", model.aperiodicLogicalTiles);
  json.setInt("defect_face_count", model.aperiodicDefectFaces);
  json.setFloat("maximum_chart_distortion", model.aperiodicMaxDistortion);
  JSONArray faces = new JSONArray();
  for (int i = 0; i < model.faces.size(); i++) {
    GeodesicFace face = model.faces.get(i);
    JSONObject value = new JSONObject();
    value.setInt("face_id", face.id);
    value.setInt("logical_tile_id", face.sourceTileId);
    value.setString("logical_tile_kind", face.sourceTileKind);
    value.setInt("chart_id", face.sourceChartId);
    value.setFloat("u", face.sourceU);
    value.setFloat("v", face.sourceV);
    value.setFloat("distortion", face.sourceDistortion);
    value.setBoolean("defect_seam_face", face.sourceDefect);
    JSONArray neighbors = new JSONArray();
    for (int n = 0; n < face.neighbors.length; n++)
      neighbors.setInt(n, face.neighbors[n]);
    value.setJSONArray("neighbors", neighbors);
    faces.setJSONObject(i, value);
  }
  json.setJSONArray("carrier_faces", faces);
  return json;
}

boolean runGeodesicAperiodicTests() {
  boolean passed = true;
  DCRTEMonotileManifest hat = geodesicLoadHatAtlas(1);
  passed &= hat != null && hat.tileCount == 25;
  GeodesicModel hatDome = buildGeodesicAperiodicModel(
    GeodesicAperiodicFamily.HAT, GeodesicExtentMode.DOME, 1, 72, 0, 0.17f);
  GeodesicModel hatRepeat = buildGeodesicAperiodicModel(
    GeodesicAperiodicFamily.HAT, GeodesicExtentMode.DOME, 1, 72, 0, 0.17f);
  passed &= hatDome.valid && hatDome.aperiodicLogicalTiles > 1;
  passed &= hatDome.fingerprint.equals(hatRepeat.fingerprint);
  GeodesicModel penrose = buildGeodesicAperiodicModel(
    GeodesicAperiodicFamily.PENROSE_P3, GeodesicExtentMode.DOME,
    2, 72, 0, 0.31f);
  passed &= penrose.valid && penrose.aperiodicLogicalTiles > 1;
  passed &= penrose.aperiodicDefectFaces > 0;
  println("GEODESIC APERIODIC TESTS " + (passed ? "PASS 5/5" : "FAIL"));
  return passed;
}
