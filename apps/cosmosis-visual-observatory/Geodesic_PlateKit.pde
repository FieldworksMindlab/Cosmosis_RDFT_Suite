/*
  Portable Geodesic Salon plate preparation.

  The standard kit remains the fabrication authority. This additive layer
  instances the same audited panel meshes into generic, printer-neutral 3MF
  build plates. It embeds no machine, filament, process, support, or G-code
  settings.
*/

final float GEODESIC_PLATE_WIDTH_MM = 256.0f;
final float GEODESIC_PLATE_HEIGHT_MM = 256.0f;
final float GEODESIC_PLATE_MARGIN_MM = 5.0f;
final float GEODESIC_PLATE_SPACING_MM = 5.0f;

boolean geodesicPlateKitRequested = false;
GeodesicPlateKitExportResult geodesicLastPlateKitResult = null;

class GeodesicPlateMeshResource {
  String key;
  String partId;
  SurfaceMesh mesh;
  ArrayList<PVector> vertices = new ArrayList<PVector>();
  ArrayList<int[]> triangles = new ArrayList<int[]>();
  float minX = Float.MAX_VALUE;
  float minY = Float.MAX_VALUE;
  float minZ = Float.MAX_VALUE;
  float maxX = -Float.MAX_VALUE;
  float maxY = -Float.MAX_VALUE;
  float maxZ = -Float.MAX_VALUE;

  GeodesicPlateMeshResource(String key, String partId, SurfaceMesh mesh) {
    this.key = key;
    this.partId = partId;
    this.mesh = mesh;
    buildIndexedMesh();
  }

  void buildIndexedMesh() {
    HashMap<String, Integer> lookup = new HashMap<String, Integer>();
    if (mesh == null) return;
    for (MeshTri tri : mesh.tris) {
      int a = vertexIndex(tri.a, lookup);
      int b = vertexIndex(tri.b, lookup);
      int c = vertexIndex(tri.c, lookup);
      if (a == b || b == c || c == a) continue;
      triangles.add(new int[] { a, b, c });
    }
  }

  int vertexIndex(PVector point, HashMap<String, Integer> lookup) {
    String vertexKey = geodesicPlateVertexKey(point);
    if (lookup.containsKey(vertexKey)) return lookup.get(vertexKey);
    int index = vertices.size();
    PVector value = point.copy();
    vertices.add(value);
    lookup.put(vertexKey, index);
    minX = min(minX, value.x);
    minY = min(minY, value.y);
    minZ = min(minZ, value.z);
    maxX = max(maxX, value.x);
    maxY = max(maxY, value.y);
    maxZ = max(maxZ, value.z);
    return index;
  }

  boolean valid() {
    return mesh != null && vertices.size() >= 3 && triangles.size() > 0 &&
      minX <= maxX && minY <= maxY && minZ <= maxZ;
  }

  float widthMM() { return valid() ? maxX - minX : 0; }
  float heightMM() { return valid() ? maxY - minY : 0; }
  float depthMM() { return valid() ? maxZ - minZ : 0; }
}

class GeodesicPlateInstance {
  int faceId = -1;
  String colorId = "C00";
  int rgb = color(170);
  String partId = "UNASSIGNED";
  String label = "";
  GeodesicPlateMeshResource resource;
  float x;
  float y;
  float z;
  float width;
  float height;

  GeodesicPlateInstance(int faceId, String colorId, int rgb,
    String partId, GeodesicPlateMeshResource resource) {
    this.faceId = faceId;
    this.colorId = colorId;
    this.rgb = rgb;
    this.partId = partId;
    this.resource = resource;
    width = resource == null ? 0 : resource.widthMM();
    height = resource == null ? 0 : resource.heightMM();
  }

  float right() { return x + width; }
  float top() { return y + height; }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("instance_label", label);
    json.setInt("face_id", faceId);
    json.setString("part_id", partId);
    json.setString("color_id", colorId);
    json.setFloat("x_mm", x);
    json.setFloat("y_mm", y);
    json.setFloat("z_mm", z);
    json.setFloat("width_mm", width);
    json.setFloat("height_mm", height);
    return json;
  }
}

class GeodesicPackedPlate {
  String colorId;
  int rgb;
  int plateIndex;
  String relativePath = "";
  String sha256 = "";
  boolean packageValid = false;
  ArrayList<GeodesicPlateInstance> instances =
    new ArrayList<GeodesicPlateInstance>();

  GeodesicPackedPlate(String colorId, int rgb, int plateIndex) {
    this.colorId = colorId;
    this.rgb = rgb;
    this.plateIndex = plateIndex;
  }

  int uniqueResourceCount() {
    HashSet<String> keys = new HashSet<String>();
    for (GeodesicPlateInstance instance : instances)
      if (instance.resource != null) keys.add(instance.resource.key);
    return keys.size();
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("plate_index", plateIndex);
    json.setString("color_id", colorId);
    json.setString("color_hex", geodesicPaintHex(rgb));
    json.setString("file", relativePath);
    json.setString("sha256", sha256);
    json.setBoolean("package_valid", packageValid);
    json.setInt("instances", instances.size());
    json.setInt("mesh_resources", uniqueResourceCount());
    JSONArray placements = new JSONArray();
    for (int i = 0; i < instances.size(); i++)
      placements.setJSONObject(i, instances.get(i).toJSON());
    json.setJSONArray("placements", placements);
    return json;
  }
}

class GeodesicPlateKitValidation {
  boolean valid = false;
  String status = "NOT CHECKED";
  int expectedInstances = 0;
  int packedInstances = 0;
  int uniqueFaceIds = 0;
  int duplicateFaceIds = 0;
  int missingFaceIds = 0;
  int invalidResources = 0;
  int oversizedInstances = 0;
  int outOfBoundsInstances = 0;
  int overlapPairs = 0;
  int colorQuantityMismatches = 0;
  int plateFiles = 0;
  int invalidPackages = 0;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("schema",
      "fieldworks.geodesic_salon.plate_validation.v1");
    json.setBoolean("valid", valid);
    json.setString("status", status);
    json.setInt("expected_instances", expectedInstances);
    json.setInt("packed_instances", packedInstances);
    json.setInt("unique_face_ids", uniqueFaceIds);
    json.setInt("duplicate_face_ids", duplicateFaceIds);
    json.setInt("missing_face_ids", missingFaceIds);
    json.setInt("invalid_mesh_resources", invalidResources);
    json.setInt("oversized_instances", oversizedInstances);
    json.setInt("out_of_bounds_instances", outOfBoundsInstances);
    json.setInt("overlap_pairs", overlapPairs);
    json.setInt("color_quantity_mismatches", colorQuantityMismatches);
    json.setInt("plate_files", plateFiles);
    json.setInt("invalid_3mf_packages", invalidPackages);
    return json;
  }
}

class GeodesicPlateKitExportResult {
  boolean requested = false;
  boolean success = false;
  String status = "PLATE KIT NOT REQUESTED";
  String manifestJson = "";
  String validationJson = "";
  String scheduleCsv = "";
  int colorGroups = 0;
  int plateFiles = 0;
  int instances = 0;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setBoolean("requested", requested);
    json.setBoolean("success", success);
    json.setString("status", status);
    json.setString("format", "3MF Core / generic");
    json.setBoolean("printer_neutral", true);
    json.setBoolean("slicer_settings_embedded", false);
    json.setString("manifest_json", manifestJson);
    json.setString("validation_json", validationJson);
    json.setString("plate_schedule_csv", scheduleCsv);
    json.setInt("color_groups", colorGroups);
    json.setInt("plate_files", plateFiles);
    json.setInt("panel_instances", instances);
    json.setFloat("bed_width_mm", GEODESIC_PLATE_WIDTH_MM);
    json.setFloat("bed_height_mm", GEODESIC_PLATE_HEIGHT_MM);
    json.setFloat("margin_mm", GEODESIC_PLATE_MARGIN_MM);
    json.setFloat("part_spacing_mm", GEODESIC_PLATE_SPACING_MM);
    return json;
  }
}

void exportGeodesicSalonPlateKit() {
  boolean previous = geodesicPlateKitRequested;
  geodesicPlateKitRequested = true;
  try {
    exportGeodesicSalonKit();
  } finally {
    geodesicPlateKitRequested = previous;
  }
}

GeodesicPlateKitExportResult exportGeodesicPlateKitPackage(
  File runFolder, GeodesicPanelCatalog catalog,
  GeodesicFabricationSettings fabrication, GeodesicPaintPlan paintPlan,
  String stamp) {
  GeodesicPlateKitExportResult result =
    new GeodesicPlateKitExportResult();
  result.requested = true;
  result.manifestJson = "print_ready/plate_manifest.json";
  result.validationJson = "print_ready/plate_validation.json";
  result.scheduleCsv = "print_ready/plate_schedule.csv";
  File root = new File(runFolder, "print_ready");
  if (!root.exists() && !root.mkdirs()) {
    result.status = "PLATE KIT BLOCKED / FOLDER";
    return result;
  }

  GeodesicPlateKitValidation validation =
    new GeodesicPlateKitValidation();
  validation.expectedInstances = geodesicModel == null ?
    0 : geodesicModel.faces.size();

  HashMap<String, GeodesicPlateMeshResource> resourceCache =
    new HashMap<String, GeodesicPlateMeshResource>();
  HashMap<String, ArrayList<GeodesicPlateInstance>> byColor =
    new HashMap<String, ArrayList<GeodesicPlateInstance>>();
  HashMap<String, Integer> expectedByColor =
    new HashMap<String, Integer>();

  if (geodesicModel == null || catalog == null || fabrication == null) {
    validation.status = "PLATE KIT INVALID / SOURCE";
    saveJSONObject(validation.toJSON(),
      new File(runFolder, result.validationJson).getAbsolutePath());
    result.status = validation.status;
    return result;
  }

  boolean usePaint = geodesicPaintEnabled && paintPlan != null &&
    paintPlan.assignments.size() == geodesicModel.faces.size();
  for (GeodesicFace face : geodesicModel.faces) {
    GeodesicPaintAssignment assignment = usePaint ?
      paintPlan.forFace(face.id) : null;
    String colorId = assignment == null ? "C00" : assignment.colorId;
    int rgb = assignment == null ? color(170) : assignment.rgb;
    String partId;
    SurfaceMesh mesh;
    if (fabrication.assemblyMode == GeodesicAssemblyMode.KICAS) {
      partId = geodesicKicasPlacementForFace(fabrication, face.id);
      mesh = buildGeodesicFabricatedPart(geodesicModel, face,
        fabrication, geodesicGrowth, geodesicReliefMM).mesh;
    } else {
      partId = assignment != null && assignment.typeId != null &&
        !assignment.typeId.equals("UNASSIGNED") ?
        assignment.typeId : catalog.faceToType.get(face.id);
      GeodesicPartType type = catalog.typeById(partId);
      mesh = type == null ? null : type.mesh;
    }
    String resourceKey = partId == null ? "UNASSIGNED" : partId;
    GeodesicPlateMeshResource resource = resourceCache.get(resourceKey);
    if (resource == null) {
      resource = new GeodesicPlateMeshResource(resourceKey,
        resourceKey, mesh);
      resourceCache.put(resourceKey, resource);
    }
    if (!resource.valid()) validation.invalidResources++;
    GeodesicPlateInstance instance = new GeodesicPlateInstance(face.id,
      colorId, rgb, resourceKey, resource);
    if (!byColor.containsKey(colorId))
      byColor.put(colorId, new ArrayList<GeodesicPlateInstance>());
    byColor.get(colorId).add(instance);
    expectedByColor.put(colorId,
      expectedByColor.containsKey(colorId) ?
      expectedByColor.get(colorId) + 1 : 1);
  }

  ArrayList<String> colorIds =
    new ArrayList<String>(byColor.keySet());
  java.util.Collections.sort(colorIds);
  ArrayList<GeodesicPackedPlate> plates =
    new ArrayList<GeodesicPackedPlate>();
  for (String colorId : colorIds) {
    ArrayList<GeodesicPlateInstance> colorInstances = byColor.get(colorId);
    if (colorInstances == null || colorInstances.size() == 0) continue;
    int rgb = colorInstances.get(0).rgb;
    ArrayList<GeodesicPackedPlate> colorPlates =
      packGeodesicColorPlates(colorId, rgb, colorInstances, validation);
    plates.addAll(colorPlates);
  }

  HashSet<Integer> seenFaces = new HashSet<Integer>();
  HashMap<String, Integer> packedByColor = new HashMap<String, Integer>();
  for (GeodesicPackedPlate plate : plates) {
    File colorFolder = new File(root, plate.colorId);
    if (!colorFolder.exists() && !colorFolder.mkdirs()) {
      validation.invalidPackages++;
      continue;
    }
    String filename = plate.colorId + "_plate_" +
      nf(plate.plateIndex, 2) + ".3mf";
    plate.relativePath = "print_ready/" + plate.colorId + "/" + filename;
    File output = new File(colorFolder, filename);
    boolean wrote = writeGeodesicGeneric3mf(output, plate, stamp);
    plate.packageValid = wrote && validateGeodesicGeneric3mf(output);
    plate.sha256 = plate.packageValid ?
      geodesicPlateFileSha256(output) : "";
    validation.plateFiles++;
    if (!plate.packageValid) validation.invalidPackages++;
    for (GeodesicPlateInstance instance : plate.instances) {
      validation.packedInstances++;
      if (!seenFaces.add(instance.faceId))
        validation.duplicateFaceIds++;
      packedByColor.put(instance.colorId,
        packedByColor.containsKey(instance.colorId) ?
        packedByColor.get(instance.colorId) + 1 : 1);
    }
  }
  validation.uniqueFaceIds = seenFaces.size();
  validation.missingFaceIds = max(0,
    validation.expectedInstances - validation.uniqueFaceIds);
  for (String colorId : expectedByColor.keySet()) {
    int expected = expectedByColor.get(colorId);
    int actual = packedByColor.containsKey(colorId) ?
      packedByColor.get(colorId) : 0;
    if (expected != actual) validation.colorQuantityMismatches++;
  }
  validation.valid = validation.expectedInstances > 0 &&
    validation.packedInstances == validation.expectedInstances &&
    validation.uniqueFaceIds == validation.expectedInstances &&
    validation.duplicateFaceIds == 0 && validation.missingFaceIds == 0 &&
    validation.invalidResources == 0 &&
    validation.oversizedInstances == 0 &&
    validation.outOfBoundsInstances == 0 &&
    validation.overlapPairs == 0 &&
    validation.colorQuantityMismatches == 0 &&
    validation.plateFiles > 0 && validation.invalidPackages == 0;
  validation.status = validation.valid ?
    "PLATE KIT PASS" : "PLATE KIT INVALID";

  writeGeodesicPlateSchedule(
    new File(runFolder, result.scheduleCsv), plates);
  JSONObject manifest = geodesicPlateManifestJSON(plates, validation,
    usePaint, paintPlan, stamp);
  saveJSONObject(manifest,
    new File(runFolder, result.manifestJson).getAbsolutePath());
  saveJSONObject(validation.toJSON(),
    new File(runFolder, result.validationJson).getAbsolutePath());

  result.colorGroups = colorIds.size();
  result.plateFiles = validation.plateFiles;
  result.instances = validation.packedInstances;
  result.success = validation.valid &&
    new File(runFolder, result.manifestJson).exists() &&
    new File(runFolder, result.validationJson).exists() &&
    new File(runFolder, result.scheduleCsv).exists();
  result.status = result.success ?
    "PLATE KIT / " + result.colorGroups + " COLORS / " +
    result.plateFiles + " PLATES / " + result.instances + " PARTS" :
    validation.status;
  return result;
}

ArrayList<GeodesicPackedPlate> packGeodesicColorPlates(
  String colorId, int rgb, ArrayList<GeodesicPlateInstance> source,
  GeodesicPlateKitValidation validation) {
  ArrayList<GeodesicPlateInstance> instances =
    new ArrayList<GeodesicPlateInstance>(source);
  java.util.Collections.sort(instances,
    new java.util.Comparator<GeodesicPlateInstance>() {
      public int compare(GeodesicPlateInstance a,
        GeodesicPlateInstance b) {
        int heightCompare = Float.compare(b.height, a.height);
        if (heightCompare != 0) return heightCompare;
        int widthCompare = Float.compare(b.width, a.width);
        if (widthCompare != 0) return widthCompare;
        if (!a.partId.equals(b.partId))
          return a.partId.compareTo(b.partId);
        return a.faceId - b.faceId;
      }
    });

  ArrayList<GeodesicPackedPlate> plates =
    new ArrayList<GeodesicPackedPlate>();
  GeodesicPackedPlate plate = new GeodesicPackedPlate(colorId, rgb, 1);
  plates.add(plate);
  float x = GEODESIC_PLATE_MARGIN_MM;
  float y = GEODESIC_PLATE_MARGIN_MM;
  float shelfHeight = 0;
  HashMap<String, Integer> labelCounts = new HashMap<String, Integer>();
  for (GeodesicPlateInstance instance : instances) {
    if (instance.resource == null || !instance.resource.valid()) continue;
    if (instance.width > GEODESIC_PLATE_WIDTH_MM -
        GEODESIC_PLATE_MARGIN_MM * 2 ||
        instance.height > GEODESIC_PLATE_HEIGHT_MM -
        GEODESIC_PLATE_MARGIN_MM * 2) {
      validation.oversizedInstances++;
      continue;
    }
    if (x + instance.width >
        GEODESIC_PLATE_WIDTH_MM - GEODESIC_PLATE_MARGIN_MM + 0.0001f) {
      x = GEODESIC_PLATE_MARGIN_MM;
      y += shelfHeight + GEODESIC_PLATE_SPACING_MM;
      shelfHeight = 0;
    }
    if (y + instance.height >
        GEODESIC_PLATE_HEIGHT_MM - GEODESIC_PLATE_MARGIN_MM + 0.0001f) {
      plate = new GeodesicPackedPlate(colorId, rgb, plates.size() + 1);
      plates.add(plate);
      x = GEODESIC_PLATE_MARGIN_MM;
      y = GEODESIC_PLATE_MARGIN_MM;
      shelfHeight = 0;
    }
    instance.x = x;
    instance.y = y;
    instance.z = -instance.resource.minZ;
    int count = labelCounts.containsKey(instance.partId) ?
      labelCounts.get(instance.partId) + 1 : 1;
    labelCounts.put(instance.partId, count);
    instance.label = instance.partId + "_" + colorId + "_" + nf(count, 3);
    plate.instances.add(instance);
    x += instance.width + GEODESIC_PLATE_SPACING_MM;
    shelfHeight = max(shelfHeight, instance.height);
  }

  for (int i = plates.size() - 1; i >= 0; i--)
    if (plates.get(i).instances.size() == 0) plates.remove(i);
  for (GeodesicPackedPlate value : plates)
    validateGeodesicPackedPlate(value, validation);
  return plates;
}

void validateGeodesicPackedPlate(GeodesicPackedPlate plate,
  GeodesicPlateKitValidation validation) {
  for (int i = 0; i < plate.instances.size(); i++) {
    GeodesicPlateInstance a = plate.instances.get(i);
    if (a.x < GEODESIC_PLATE_MARGIN_MM - 0.0001f ||
        a.y < GEODESIC_PLATE_MARGIN_MM - 0.0001f ||
        a.right() > GEODESIC_PLATE_WIDTH_MM -
          GEODESIC_PLATE_MARGIN_MM + 0.0001f ||
        a.top() > GEODESIC_PLATE_HEIGHT_MM -
          GEODESIC_PLATE_MARGIN_MM + 0.0001f)
      validation.outOfBoundsInstances++;
    for (int j = i + 1; j < plate.instances.size(); j++) {
      GeodesicPlateInstance b = plate.instances.get(j);
      if (geodesicPlateRectanglesOverlap(a, b))
        validation.overlapPairs++;
    }
  }
}

boolean geodesicPlateRectanglesOverlap(
  GeodesicPlateInstance a, GeodesicPlateInstance b) {
  float epsilon = 0.0001f;
  return a.x < b.right() - epsilon && a.right() > b.x + epsilon &&
    a.y < b.top() - epsilon && a.top() > b.y + epsilon;
}

JSONObject geodesicPlateManifestJSON(
  ArrayList<GeodesicPackedPlate> plates,
  GeodesicPlateKitValidation validation, boolean paintEnabled,
  GeodesicPaintPlan paintPlan, String stamp) {
  JSONObject json = new JSONObject();
  json.setString("schema",
    "fieldworks.geodesic_salon.plate_kit.v1");
  json.setString("generated_at", stamp);
  json.setString("format", "3MF Core / generic");
  json.setString("unit", "millimeter");
  json.setBoolean("printer_neutral", true);
  json.setBoolean("slicer_settings_embedded", false);
  json.setBoolean("gcode_embedded", false);
  json.setString("operator_action",
    "open each plate in a slicer, verify printer and filament settings, slice, and inspect before printing");
  json.setFloat("bed_width_mm", GEODESIC_PLATE_WIDTH_MM);
  json.setFloat("bed_height_mm", GEODESIC_PLATE_HEIGHT_MM);
  json.setFloat("margin_mm", GEODESIC_PLATE_MARGIN_MM);
  json.setFloat("part_spacing_mm", GEODESIC_PLATE_SPACING_MM);
  json.setString("packing_policy",
    "deterministic conservative axis_aligned_shelf");
  json.setString("model_fingerprint",
    geodesicModel == null ? "" : geodesicModel.fingerprint);
  json.setBoolean("paint_mode_enabled", paintEnabled);
  json.setString("paint_scheme", paintEnabled && paintPlan != null ?
    paintPlan.scheme.label() : "UNCOLORED");
  json.setInt("panel_instances", validation.expectedInstances);
  json.setInt("plate_files", plates.size());
  json.setJSONObject("validation", validation.toJSON());
  JSONArray values = new JSONArray();
  for (int i = 0; i < plates.size(); i++)
    values.setJSONObject(i, plates.get(i).toJSON());
  json.setJSONArray("plates", values);
  return json;
}

void writeGeodesicPlateSchedule(File file,
  ArrayList<GeodesicPackedPlate> plates) {
  PrintWriter writer = createWriter(file.getAbsolutePath());
  writer.println("color_id,color_hex,plate_index,plate_file,instance_label,face_id,part_id,x_mm,y_mm,z_mm,width_mm,height_mm");
  for (GeodesicPackedPlate plate : plates)
    for (GeodesicPlateInstance instance : plate.instances)
      writer.println(instance.colorId + "," +
        geodesicPaintHex(instance.rgb) + "," + plate.plateIndex + "," +
        geodesicCsv(plate.relativePath) + "," +
        geodesicCsv(instance.label) + "," + instance.faceId + "," +
        geodesicCsv(instance.partId) + "," +
        nf(instance.x, 1, 4) + "," + nf(instance.y, 1, 4) + "," +
        nf(instance.z, 1, 4) + "," + nf(instance.width, 1, 4) + "," +
        nf(instance.height, 1, 4));
  writer.flush();
  writer.close();
}

boolean writeGeodesicGeneric3mf(File file, GeodesicPackedPlate plate,
  String stamp) {
  java.util.zip.ZipOutputStream zip = null;
  try {
    File parent = file.getParentFile();
    if (parent != null && !parent.exists() && !parent.mkdirs())
      return false;
    zip = new java.util.zip.ZipOutputStream(
      new java.io.BufferedOutputStream(
      new java.io.FileOutputStream(file)));
    geodesicWrite3mfEntry(zip, "[Content_Types].xml",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
      "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n" +
      "  <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>\n" +
      "  <Default Extension=\"model\" ContentType=\"application/vnd.ms-package.3dmanufacturing-3dmodel+xml\"/>\n" +
      "</Types>\n");
    geodesicWrite3mfEntry(zip, "_rels/.rels",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
      "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
      "  <Relationship Target=\"/3D/3dmodel.model\" Id=\"rel0\" Type=\"http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel\"/>\n" +
      "</Relationships>\n");
    zip.putNextEntry(new java.util.zip.ZipEntry("3D/3dmodel.model"));
    PrintWriter out = new PrintWriter(new java.io.OutputStreamWriter(zip,
      java.nio.charset.StandardCharsets.UTF_8));
    geodesicWrite3mfModel(out, plate, stamp);
    out.flush();
    zip.closeEntry();
    zip.finish();
    zip.close();
    return file.exists() && file.length() > 0;
  } catch (Exception error) {
    println("PLATE KIT 3MF WRITE FAILED " + file.getAbsolutePath() +
      " / " + error);
    try { if (zip != null) zip.close(); } catch (Exception ignored) {}
    return false;
  }
}

void geodesicWrite3mfEntry(java.util.zip.ZipOutputStream zip,
  String name, String content) throws Exception {
  zip.putNextEntry(new java.util.zip.ZipEntry(name));
  byte[] bytes = content.getBytes(java.nio.charset.StandardCharsets.UTF_8);
  zip.write(bytes, 0, bytes.length);
  zip.closeEntry();
}

void geodesicWrite3mfModel(PrintWriter out, GeodesicPackedPlate plate,
  String stamp) {
  HashMap<String, GeodesicPlateMeshResource> resources =
    new HashMap<String, GeodesicPlateMeshResource>();
  for (GeodesicPlateInstance instance : plate.instances)
    resources.put(instance.resource.key, instance.resource);
  ArrayList<String> keys = new ArrayList<String>(resources.keySet());
  java.util.Collections.sort(keys);
  HashMap<String, Integer> objectIds = new HashMap<String, Integer>();

  out.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
  out.println("<model unit=\"millimeter\" xml:lang=\"en-US\" xmlns=\"http://schemas.microsoft.com/3dmanufacturing/core/2015/02\">");
  out.println("  <metadata name=\"Title\">" +
    geodesicPlateXml("Geodesic Salon " + plate.colorId +
    " Plate " + nf(plate.plateIndex, 2)) + "</metadata>");
  out.println("  <metadata name=\"Designer\">Fieldworks MindLAB [Brian Fahey]</metadata>");
  out.println("  <metadata name=\"Application\">Cosmosis Visual Observatory / Geodesic Salon</metadata>");
  out.println("  <metadata name=\"Description\">" +
    geodesicPlateXml("Generic plate-ready geometry; verify slicer settings before printing. Generated " + stamp) +
    "</metadata>");
  out.println("  <metadata name=\"Fieldworks.ColorID\">" +
    geodesicPlateXml(plate.colorId) + "</metadata>");
  out.println("  <resources>");
  out.println("    <basematerials id=\"1\">");
  out.println("      <base name=\"" +
    geodesicPlateXml(plate.colorId + " " +
    geodesicPaintHex(plate.rgb)) + "\" displaycolor=\"" +
    geodesicPaintHex(plate.rgb) + "FF\"/>");
  out.println("    </basematerials>");
  int nextObjectId = 2;
  for (String key : keys) {
    GeodesicPlateMeshResource resource = resources.get(key);
    int objectId = nextObjectId++;
    objectIds.put(key, objectId);
    out.println("    <object id=\"" + objectId +
      "\" type=\"model\" name=\"" +
      geodesicPlateXml(resource.partId) + "\" partnumber=\"" +
      geodesicPlateXml(resource.partId) +
      "\" pid=\"1\" pindex=\"0\">");
    out.println("      <mesh>");
    out.println("        <vertices>");
    for (PVector vertex : resource.vertices)
      out.println("          <vertex x=\"" +
        geodesicPlateFloat(vertex.x) + "\" y=\"" +
        geodesicPlateFloat(vertex.y) + "\" z=\"" +
        geodesicPlateFloat(vertex.z) + "\"/>");
    out.println("        </vertices>");
    out.println("        <triangles>");
    for (int[] triangle : resource.triangles)
      out.println("          <triangle v1=\"" + triangle[0] +
        "\" v2=\"" + triangle[1] + "\" v3=\"" +
        triangle[2] + "\"/>");
    out.println("        </triangles>");
    out.println("      </mesh>");
    out.println("    </object>");
  }
  out.println("  </resources>");
  out.println("  <build>");
  for (GeodesicPlateInstance instance : plate.instances) {
    float tx = instance.x - instance.resource.minX;
    float ty = instance.y - instance.resource.minY;
    float tz = instance.z;
    out.println("    <item objectid=\"" +
      objectIds.get(instance.resource.key) + "\" partnumber=\"" +
      geodesicPlateXml(instance.label) +
      "\" transform=\"1 0 0 0 1 0 0 0 1 " +
      geodesicPlateFloat(tx) + " " + geodesicPlateFloat(ty) + " " +
      geodesicPlateFloat(tz) + "\"/>");
  }
  out.println("  </build>");
  out.println("</model>");
}

boolean validateGeodesicGeneric3mf(File file) {
  if (file == null || !file.exists() || file.length() < 256) return false;
  java.util.zip.ZipFile zip = null;
  try {
    zip = new java.util.zip.ZipFile(file);
    java.util.zip.ZipEntry content =
      zip.getEntry("[Content_Types].xml");
    java.util.zip.ZipEntry relations = zip.getEntry("_rels/.rels");
    java.util.zip.ZipEntry model = zip.getEntry("3D/3dmodel.model");
    boolean valid = content != null && relations != null && model != null &&
      content.getSize() != 0 && relations.getSize() != 0 &&
      model.getSize() != 0;
    zip.close();
    return valid;
  } catch (Exception error) {
    try { if (zip != null) zip.close(); } catch (Exception ignored) {}
    return false;
  }
}

String geodesicPlateFileSha256(File file) {
  if (file == null || !file.exists()) return "";
  java.io.InputStream input = null;
  try {
    java.security.MessageDigest digest =
      java.security.MessageDigest.getInstance("SHA-256");
    input = new java.io.BufferedInputStream(
      new java.io.FileInputStream(file));
    byte[] buffer = new byte[65536];
    int read;
    while ((read = input.read(buffer)) >= 0)
      if (read > 0) digest.update(buffer, 0, read);
    input.close();
    byte[] hash = digest.digest();
    StringBuilder value = new StringBuilder();
    for (byte part : hash) {
      int unsigned = part & 0xff;
      if (unsigned < 16) value.append('0');
      value.append(Integer.toHexString(unsigned));
    }
    return value.toString();
  } catch (Exception error) {
    try { if (input != null) input.close(); } catch (Exception ignored) {}
    return "";
  }
}

String geodesicPlateVertexKey(PVector point) {
  return round(point.x * 100000.0f) + "," +
    round(point.y * 100000.0f) + "," +
    round(point.z * 100000.0f);
}

String geodesicPlateFloat(float value) {
  if (abs(value) < 0.0000005f) value = 0;
  return String.format(java.util.Locale.US, "%.6f", value);
}

String geodesicPlateXml(String value) {
  if (value == null) return "";
  return value.replace("&", "&amp;").replace("<", "&lt;")
    .replace(">", "&gt;").replace("\"", "&quot;")
    .replace("'", "&apos;");
}
