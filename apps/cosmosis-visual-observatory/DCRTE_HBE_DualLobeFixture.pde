/* M6-HX deterministic connected two-lobed fixture, round-tripped through normal STL import. */

TriangleMeshData createDcrteHbeDualLobeFixtureMesh(HBEConfig config, float feedback) {
  HBEConfig c = config == null ? new HBEConfig() : config.copy();
  int axial = max(24, c.axialSegments); int azimuth = max(16, c.azimuthSegments);
  int rings = axial - 1; float neckLength = c.effectiveNeckLength(feedback);
  float half = neckLength * 0.5f + c.lobeHalfLength;
  FloatArrayBuilder vertices = new FloatArrayBuilder((2 + rings * azimuth) * 3);
  vertices.add3(-half, 0, 0);
  for (int ring = 1; ring < axial; ring++) {
    float t = ring / (float)axial; float x = lerp(-half, half, t); float ax = abs(x);
    float pole = sqrt(max(0, 1 - pow(ax / max(0.000001f, half), 6)));
    float center = neckLength * 0.5f + 0.48f * c.lobeHalfLength;
    float width = max(0.000001f, 0.34f * c.lobeHalfLength);
    float lobe = exp(-pow((ax - center) / width, 2));
    float radius = (c.neckRadius + (c.lobeRadius - c.neckRadius) * lobe) * pole;
    if (c.radiusMode == HBERadiusMode.CONNECTIVITY_GAIN)
      radius *= 0.88f + 0.22f * constrain(feedback, 0, 1);
    else if (c.radiusMode == HBERadiusMode.STYLIZED_CONSTRICTION)
      radius *= 1 - 0.16f * constrain(feedback, 0, 1) * exp(-pow(x / max(0.000001f, neckLength), 2));
    for (int a = 0; a < azimuth; a++) {
      float theta = TWO_PI * a / azimuth;
      vertices.add3(x, radius * cos(theta), radius * sin(theta));
    }
  }
  int rightPole = vertices.size / 3; vertices.add3(half, 0, 0);
  IntArrayBuilder triangles = new IntArrayBuilder(2 * azimuth * rings * 3);
  int first = 1;
  for (int a = 0; a < azimuth; a++) {
    int current = first + a, next = first + (a + 1) % azimuth;
    triangles.add3(0, current, next);
  }
  for (int ring = 0; ring < rings - 1; ring++) {
    int left = first + ring * azimuth, right = left + azimuth;
    for (int a = 0; a < azimuth; a++) {
      int next = (a + 1) % azimuth;
      int p = left + a, q = left + next, r = right + a, s = right + next;
      triangles.add3(p, r, q); triangles.add3(q, r, s);
    }
  }
  int last = first + (rings - 1) * azimuth;
  for (int a = 0; a < azimuth; a++) {
    int current = last + a, next = last + (a + 1) % azimuth;
    triangles.add3(rightPole, next, current);
  }
  int[] indices = triangles.toArray(); TriangleMeshData mesh = new TriangleMeshData(vertices.toArray(), indices);
  if (dcrteSignedMeshVolume(mesh) < 0) {
    for (int t = 0; t < indices.length; t += 3) { int swap = indices[t + 1]; indices[t + 1] = indices[t + 2]; indices[t + 2] = swap; }
    mesh = new TriangleMeshData(mesh.vertices, indices);
  }
  mesh.sourceName = "dcrte_hbe_dual_lobe_fixture.stl"; mesh.sourceFormat = "generated_fixture";
  mesh.declaredTriangleCount = mesh.triangleCount; return mesh;
}

JSONObject dcrteHbeFixtureMetadata(HBEConfig config, float feedback) {
  HBEConfig c = config == null ? new HBEConfig() : config;
  JSONObject j = new JSONObject(); j.setString("fixture_id", "dcrte_m6_hx_dual_lobe_v1");
  j.setString("type", "connected_axial_dual_lobe"); j.setString("version", DCRTE_HBE_VERSION);
  j.setFloat("resolved_feedback", feedback); j.setFloat("effective_neck_length", c.effectiveNeckLength(feedback));
  j.setFloat("lobe_radius", c.lobeRadius); j.setFloat("lobe_half_length", c.lobeHalfLength);
  j.setFloat("neck_radius", c.neckRadius); j.setInt("axial_segments", c.axialSegments);
  j.setInt("azimuth_segments", c.azimuthSegments); j.setString("topology", "one connected watertight genus-zero surface");
  j.setString("semantic_scope", "classical two-sided connectivity test fixture"); return j;
}

void loadDcrteHbeDualLobeFixture() {
  if (!dcrteHbeEnabled) dcrteHbeSetEnabled(true);
  try {
    HBEFrozenMetrics metrics = new HBEFrozenMetrics(dcrteHbeConfig.copy());
    TriangleMeshData generated = createDcrteHbeDualLobeFixtureMesh(dcrteHbeConfig, metrics.feedback);
    MeshValidationResult validation = new DCRTEMeshSanitizer().sanitize(generated);
    if (generated == null || !generated.isStructurallyValid() || validation == null
        || validation.report == null || !validation.report.strictValid())
      throw new Exception("generated dual-lobe fixture failed closed-manifold validation");
    File directory = new File(sketchPath("exports/dcrte_fixtures"));
    if (!directory.exists() && !directory.mkdirs()) throw new Exception("unable to create fixture output directory");
    File fixture = new File(directory, "dcrte_hbe_dual_lobe_fixture.stl");
    writeDcrteBinaryStl(generated, fixture, "DCRTE M6-HX dual-lobe fixture v1.0");
    generated = null; System.gc();
    if (!loadDcrteImportedFile(fixture, true, dcrteHbeFixtureMetadata(dcrteHbeConfig, metrics.feedback)))
      throw new Exception("normal STL import rejected the dual-lobe fixture");
    dcrteHbePreparedMetrics = metrics; dcrteHbeState = HBEState.CONFIGURED;
    dcrteHbeStatus = "two-sided fixture loaded through normal preflight; build HBE snapshot";
  } catch (Exception error) {
    dcrteHbeState = HBEState.FAILED;
    dcrteHbeStatus = "dual-lobe fixture failed safely: " + (error.getMessage() == null ? error.getClass().getSimpleName() : error.getMessage());
  }
}
