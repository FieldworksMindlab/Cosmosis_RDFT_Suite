/* DCRTE-ET Milestone 2.5 mesh, topology, transform, and resolution diagnostics. */

final int DCRTE_PREFLIGHT_MAX_INTERSECTION_CANDIDATES = 500000;
final int DCRTE_PREFLIGHT_MAX_INTERSECTION_EXAMPLES = 128;

class DCRTEUnionFind {
  int[] parent;
  byte[] rank;

  DCRTEUnionFind(int count) {
    parent = new int[max(0, count)];
    rank = new byte[parent.length];
    for (int i = 0; i < parent.length; i++) parent[i] = i;
  }

  int find(int value) {
    int root = value;
    while (parent[root] != root) root = parent[root];
    while (parent[value] != value) {
      int next = parent[value];
      parent[value] = root;
      value = next;
    }
    return root;
  }

  void union(int a, int b) {
    int rootA = find(a);
    int rootB = find(b);
    if (rootA == rootB) return;
    if (rank[rootA] < rank[rootB]) parent[rootA] = rootB;
    else if (rank[rootA] > rank[rootB]) parent[rootB] = rootA;
    else { parent[rootB] = rootA; rank[rootA]++; }
  }
}

class DCRTEMeshTopologyAnalysis {
  ArrayList<MeshComponentReport> components = new ArrayList<MeshComponentReport>();
  int[] componentByTriangle = new int[0];
  int[] nonManifoldVertices = new int[0];
  int[] bowtieVertices = new int[0];
}

class DCRTEPreflightMeshAnalyzer {
  DomainPreflightReport analyze(TriangleMeshData sourceMesh, TriangleMeshData worldMesh,
      MeshDomainReport meshReport, MeshTransform transform, int resolution, Bounds3D observerBounds) {
    long totalStart = millis();
    DomainPreflightReport report = new DomainPreflightReport();
    report.selectedResolution = resolution;
    report.meshReport = meshReport;
    report.sourceName = sourceMesh == null ? "" : sourceMesh.sourceName;
    report.sourceHashSha256 = sourceMesh == null ? "" : sourceMesh.sourceHashSha256;
    report.previewEnabled = sourceMesh != null && sourceMesh.triangleCount > 0;

    if (sourceMesh == null) {
      report.qualification = DomainQualification.NOT_LOADED;
      report.setStage("FILE", DCRTEPreflightStageState.NOT_RUN, "no imported source is loaded", 0);
      dcrteSkipPreflightStagesAfter(report, "FILE", "no imported source is loaded");
      report.refreshSummary();
      report.totalMillis = millis() - totalStart;
      return report;
    }

    report.setStage("FILE", DCRTEPreflightStageState.PASS, "source file was read without retaining its private path", 0);
    report.setStage("PARSE", DCRTEPreflightStageState.PASS, "supported triangle mesh parsed", meshReport == null ? 0 : meshReport.importParseMillis);
    report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SOURCE_UNITS_UNSPECIFIED,
      DiagnosticSeverity.INFO, "FILE", "Source units unspecified",
      "STL does not encode physical units; normalized fit mode is active.", ""));

    long stageStart = millis();
    addGeometryDiagnostics(report, sourceMesh, meshReport);
    completeStage(report, "GEOMETRY", stageStart, "safe sanitation and geometric bounds inspected");

    TriangleMeshData spatialMesh = worldMesh == null ? sourceMesh : worldMesh;
    stageStart = millis();
    report.boundaryLoops = extractBoundaryLoops(spatialMesh, meshReport == null ? null : meshReport.boundaryEdges);
    addBoundaryDiagnostics(report, spatialMesh, meshReport, report.boundaryLoops, resolution, observerBounds);
    DCRTEMeshTopologyAnalysis topology = analyzeComponentsAndVertices(spatialMesh, meshReport);
    report.components = topology.components;
    report.componentCount = topology.components.size();
    report.nonManifoldVertexIndices = topology.nonManifoldVertices;
    report.bowtieVertexIndices = topology.bowtieVertices;
    report.nonManifoldVertexCount = topology.nonManifoldVertices.length;
    report.bowtieVertexCount = topology.bowtieVertices.length;
    addVertexTopologyDiagnostics(report, spatialMesh, topology);
    completeStage(report, "TOPOLOGY", stageStart, "edge, loop, and vertex neighborhoods inspected");

    stageStart = millis();
    addComponentDiagnostics(report, spatialMesh, topology);
    completeStage(report, "COMPONENTS", stageStart, "connected surface components characterized");

    stageStart = millis();
    addOrientationDiagnostics(report, spatialMesh, meshReport, topology);
    completeStage(report, "ORIENTATION", stageStart, "edge winding and component volumes inspected");

    stageStart = millis();
    report.selfIntersectionReport = analyzeSelfIntersections(spatialMesh, topology.componentByTriangle);
    addSelfIntersectionDiagnostics(report, spatialMesh, topology, report.selfIntersectionReport);
    completeStage(report, "SELF_INTERSECTION", stageStart, "broad-phase candidates and exact triangle tests completed");

    stageStart = millis();
    addTransformDiagnostics(report, sourceMesh, worldMesh, transform, observerBounds, resolution);
    completeStage(report, "TRANSFORM", stageStart, "fit, clipping, aspect, and inverse transform inspected");

    stageStart = millis();
    report.resolutionSuitability = inspectResolution(spatialMesh, resolution, observerBounds, null);
    addResolutionDiagnostics(report, spatialMesh, report.resolutionSuitability);
    report.sdfResolutionConfidence = report.resolutionSuitability == null ? 0 : report.resolutionSuitability.estimatedConfidence;
    completeStage(report, "RESOLUTION", stageStart, "mesh-derived feature risk estimated; no wall-thickness claim is made");

    report.sdfBuildEnabled = !report.hasBlockerAtOrBefore("RESOLUTION");
    String downstreamReason = report.sdfBuildEnabled
      ? "not run; build or rebuild the signed distance volume to continue"
      : "not run due to " + (report.firstBlockingCode.length() == 0 ? "mesh preflight blocker" : report.firstBlockingCode);
    report.setStage("BOUNDARY_VOXELIZATION", report.sdfBuildEnabled ? DCRTEPreflightStageState.NOT_RUN : DCRTEPreflightStageState.SKIPPED, downstreamReason, 0);
    report.setStage("INSIDE_OUTSIDE", report.sdfBuildEnabled ? DCRTEPreflightStageState.NOT_RUN : DCRTEPreflightStageState.SKIPPED, downstreamReason, 0);
    report.setStage("SIGNED_DISTANCE", report.sdfBuildEnabled ? DCRTEPreflightStageState.NOT_RUN : DCRTEPreflightStageState.SKIPPED, downstreamReason, 0);
    report.setStage("MATERIALIZATION", DCRTEPreflightStageState.SKIPPED, "not run until a trusted signed distance volume exists", 0);
    report.setStage("EXPORT", DCRTEPreflightStageState.BLOCKED, "export requires a validated materialization", 0);
    report.materializationEnabled = false;
    report.exportEnabled = false;
    report.qualification = report.hasBlockerAtOrBefore("SELF_INTERSECTION")
      ? DomainQualification.TOPOLOGY_INVALID
      : DomainQualification.TOPOLOGY_VALID_SDF_UNRESOLVED;
    if (report.qualification == DomainQualification.TOPOLOGY_INVALID && report.previewEnabled) {
      report.previewEnabled = true;
    }
    report.refreshSummary();
    if (report.qualification == DomainQualification.TOPOLOGY_INVALID && report.firstBlockingCode.length() == 0) {
      report.qualification = DomainQualification.PREVIEW_ONLY;
    }
    report.totalMillis = millis() - totalStart;
    return report;
  }

  void addGeometryDiagnostics(DomainPreflightReport report, TriangleMeshData mesh, MeshDomainReport meshReport) {
    if (mesh.sourceBounds == null || !mesh.sourceBounds.isValid()) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INVALID_BOUNDS, DiagnosticSeverity.BLOCKER,
        "GEOMETRY", "Invalid source bounds", "The mesh does not define finite nonzero three-dimensional bounds.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT));
      return;
    }
    float sx = mesh.sourceBounds.sizeX();
    float sy = mesh.sourceBounds.sizeY();
    float sz = mesh.sourceBounds.sizeZ();
    float minimum = min(sx, min(sy, sz));
    float maximum = max(sx, max(sy, sz));
    float diagonal = sqrt(sx * sx + sy * sy + sz * sz);
    if (minimum <= 0 || mesh.sourceBounds.volume() <= 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_ZERO_VOLUME_BOUNDS, DiagnosticSeverity.BLOCKER,
        "GEOMETRY", "Zero-volume source bounds", "At least one source extent is zero.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT));
    }
    if (minimum > 0 && maximum / minimum > 100.0f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_EXTREME_ASPECT_RATIO, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Extreme source aspect ratio", "The source bounding-box aspect ratio can amplify voxel resolution risk.",
        DCRTEPreflightActions.ACTION_REORIENT_DOMAIN).withValue(maximum / minimum, 100.0f));
    }
    if (diagonal < 0.0000001f || diagonal > 10000000.0f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SOURCE_SCALE_EXTREME, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Extreme source coordinate scale", "Normalization is available, but source coordinates may lose precision.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT).withValue(diagonal, 0));
    }
    if (meshReport == null) return;
    if (meshReport.zeroAreaTrianglesRemoved > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_ZERO_AREA_TRIANGLES, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Zero-area triangles sanitized", "Degenerate faces were removed without changing neighboring topology.",
        DCRTEPreflightActions.ACTION_INCREASE_SOURCE_MESH_QUALITY).withCount(meshReport.zeroAreaTrianglesRemoved).sanitizable(true));
    }
    if (meshReport.nearZeroAreaTrianglesRemoved > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_NEAR_ZERO_AREA_TRIANGLES, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Near-zero-area triangles sanitized", "Faces below the established conservative area tolerance were removed.",
        DCRTEPreflightActions.ACTION_INCREASE_SOURCE_MESH_QUALITY).withCount(meshReport.nearZeroAreaTrianglesRemoved).sanitizable(true));
    }
    if (meshReport.invalidIndexTrianglesRemoved > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INVALID_TRIANGLE_INDICES, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Invalid triangle indices sanitized", "Triangles referencing unusable geometry were removed.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT).withCount(meshReport.invalidIndexTrianglesRemoved).sanitizable(true));
    }
    if (meshReport.duplicateTrianglesRemoved > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_DUPLICATE_TRIANGLES, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Exact duplicate triangles sanitized", "Orientation-independent exact duplicate faces were removed.",
        DCRTEPreflightActions.ACTION_REMOVE_INTERNAL_FACES).withCount(meshReport.duplicateTrianglesRemoved).sanitizable(true));
    }
    if (meshReport.exactDuplicateVerticesMerged > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_DUPLICATE_VERTICES, DiagnosticSeverity.INFO,
        "GEOMETRY", "Exact duplicate vertices merged", "Coincident STL vertices were indexed as shared vertices.", "")
        .withCount(meshReport.exactDuplicateVerticesMerged).sanitizable(true));
    }
    if (meshReport.nearDuplicateVerticesMerged > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_NEAR_DUPLICATE_VERTICES, DiagnosticSeverity.WARNING,
        "GEOMETRY", "Near-duplicate vertices merged", "Vertices within the established conservative merge tolerance were welded.",
        DCRTEPreflightActions.ACTION_INCREASE_SOURCE_MESH_QUALITY).withCount(meshReport.nearDuplicateVerticesMerged)
        .withValue(meshReport.mergeTolerance, meshReport.mergeTolerance).sanitizable(true));
    }
    if (meshReport.isolatedVerticesRemoved > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_ISOLATED_VERTICES, DiagnosticSeverity.INFO,
        "GEOMETRY", "Isolated vertices removed", "Unused vertices were removed after face sanitation.", "")
        .withCount(meshReport.isolatedVerticesRemoved).sanitizable(true));
    }
  }

  void addBoundaryDiagnostics(DomainPreflightReport report, TriangleMeshData mesh, MeshDomainReport meshReport,
      ArrayList<MeshBoundaryLoopReport> loops, int resolution, Bounds3D observerBounds) {
    if (meshReport == null) return;
    if (meshReport.boundaryEdgeCount > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_EDGES, DiagnosticSeverity.BLOCKER,
        "TOPOLOGY", "Open boundary edges", "Edges with one incident face prevent a reliable inside/outside domain.",
        DCRTEPreflightActions.ACTION_CLOSE_BOUNDARY_LOOPS).withCount(meshReport.boundaryEdgeCount).topologyChange(true);
      if (meshReport.boundaryEdges.length > 0) locateEdgeDiagnostic(diagnostic, mesh, meshReport.boundaryEdges[0]);
      report.addDiagnostic(diagnostic);
    }
    if (loops.size() > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_LOOPS, DiagnosticSeverity.BLOCKER,
        "TOPOLOGY", "Boundary loops detected", "Open edge chains were grouped into spatially navigable boundary loops.",
        DCRTEPreflightActions.ACTION_CLOSE_BOUNDARY_LOOPS).withCount(loops.size()).topologyChange(true));
      for (int i = 0; i < loops.size(); i++) {
        MeshBoundaryLoopReport loop = loops.get(i);
        String code = loop.edgeCount <= 3 ? DCRTEPreflightCodes.PF_BOUNDARY_LOOP_SMALL : DCRTEPreflightCodes.PF_BOUNDARY_LOOP_LARGE;
        String title = loop.edgeCount <= 3 ? "Small boundary loop" : "Large boundary opening";
        report.addDiagnostic(new DomainDiagnostic(code, DiagnosticSeverity.BLOCKER, "TOPOLOGY", title,
          "Loop " + loop.loopIndex + " has " + loop.edgeCount + " edges and perimeter " + nf(loop.perimeter, 1, 5) + ".",
          DCRTEPreflightActions.ACTION_CLOSE_BOUNDARY_LOOPS).withCount(loop.edgeCount).withValue(loop.perimeter, 0)
          .at(loop.centerX, loop.centerY, loop.centerZ).topologyChange(true));
      }
    }
    if (meshReport.nonManifoldEdgeCount > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_NONMANIFOLD_EDGES, DiagnosticSeverity.BLOCKER,
        "TOPOLOGY", "Non-manifold edges", "Edges with more than two incident faces cannot define a trusted boundary.",
        DCRTEPreflightActions.ACTION_REMOVE_NONMANIFOLD_GEOMETRY).withCount(meshReport.nonManifoldEdgeCount).topologyChange(true);
      if (meshReport.nonManifoldEdges.length > 0) locateEdgeDiagnostic(diagnostic, mesh, meshReport.nonManifoldEdges[0]);
      report.addDiagnostic(diagnostic);
    }
  }

  ArrayList<MeshBoundaryLoopReport> extractBoundaryLoops(TriangleMeshData mesh, long[] boundaryEdges) {
    ArrayList<MeshBoundaryLoopReport> loops = new ArrayList<MeshBoundaryLoopReport>();
    if (mesh == null || boundaryEdges == null || boundaryEdges.length == 0) return loops;
    long[] sortedEdges = java.util.Arrays.copyOf(boundaryEdges, boundaryEdges.length);
    java.util.Arrays.sort(sortedEdges);
    java.util.HashMap<Integer, ArrayList<Integer>> adjacency = new java.util.HashMap<Integer, ArrayList<Integer>>();
    java.util.HashSet<Long> remaining = new java.util.HashSet<Long>();
    for (int i = 0; i < sortedEdges.length; i++) {
      int a = dcrteEdgeKeyA(sortedEdges[i]);
      int b = dcrteEdgeKeyB(sortedEdges[i]);
      dcrteAddAdjacentVertex(adjacency, a, b);
      dcrteAddAdjacentVertex(adjacency, b, a);
      remaining.add(sortedEdges[i]);
    }
    java.util.Iterator<ArrayList<Integer>> values = adjacency.values().iterator();
    while (values.hasNext()) java.util.Collections.sort(values.next());
    for (int edgeIndex = 0; edgeIndex < sortedEdges.length; edgeIndex++) {
      long seed = sortedEdges[edgeIndex];
      if (!remaining.contains(seed)) continue;
      int start = dcrteEdgeKeyA(seed);
      int previous = start;
      int current = dcrteEdgeKeyB(seed);
      IntArrayBuilder vertices = new IntArrayBuilder(16);
      vertices.add(start);
      vertices.add(current);
      remaining.remove(seed);
      boolean closed = current == start;
      int guard = 0;
      while (!closed && guard++ <= boundaryEdges.length + 1) {
        ArrayList<Integer> neighbors = adjacency.get(current);
        int next = -1;
        if (neighbors != null) {
          for (int n = 0; n < neighbors.size(); n++) {
            int candidate = neighbors.get(n);
            long key = dcrteCanonicalEdgeKey(current, candidate);
            if (!remaining.contains(key)) continue;
            if (candidate != previous) { next = candidate; break; }
            if (next < 0) next = candidate;
          }
        }
        if (next < 0) break;
        remaining.remove(dcrteCanonicalEdgeKey(current, next));
        previous = current;
        current = next;
        vertices.add(current);
        closed = current == start;
      }
      MeshBoundaryLoopReport loop = createBoundaryLoopReport(mesh, loops.size(), vertices.toArray(), closed);
      loops.add(loop);
    }
    if (!loops.isEmpty()) {
      int largest = 0;
      int smallest = 0;
      for (int i = 1; i < loops.size(); i++) {
        if (loops.get(i).perimeter > loops.get(largest).perimeter) largest = i;
        if (loops.get(i).perimeter < loops.get(smallest).perimeter) smallest = i;
      }
      loops.get(largest).largest = true;
      loops.get(smallest).smallest = true;
    }
    return loops;
  }

  MeshBoundaryLoopReport createBoundaryLoopReport(TriangleMeshData mesh, int index, int[] vertices, boolean closed) {
    MeshBoundaryLoopReport loop = new MeshBoundaryLoopReport();
    loop.loopIndex = index;
    loop.vertexIndices = vertices;
    loop.edgeCount = max(0, vertices.length - 1);
    loop.closed = closed;
    float minX = Float.POSITIVE_INFINITY; float minY = Float.POSITIVE_INFINITY; float minZ = Float.POSITIVE_INFINITY;
    float maxX = Float.NEGATIVE_INFINITY; float maxY = Float.NEGATIVE_INFINITY; float maxZ = Float.NEGATIVE_INFINITY;
    int centroidCount = closed && vertices.length > 1 ? vertices.length - 1 : vertices.length;
    for (int i = 0; i < vertices.length; i++) {
      int vertex = vertices[i];
      if (vertex < 0 || vertex >= mesh.vertexCount) continue;
      float x = mesh.vx(vertex); float y = mesh.vy(vertex); float z = mesh.vz(vertex);
      minX = min(minX, x); minY = min(minY, y); minZ = min(minZ, z);
      maxX = max(maxX, x); maxY = max(maxY, y); maxZ = max(maxZ, z);
      if (i < centroidCount) { loop.centerX += x; loop.centerY += y; loop.centerZ += z; }
      if (i > 0) {
        int previous = vertices[i - 1];
        float dx = x - mesh.vx(previous); float dy = y - mesh.vy(previous); float dz = z - mesh.vz(previous);
        loop.perimeter += sqrt(dx * dx + dy * dy + dz * dz);
      }
    }
    if (centroidCount > 0) {
      loop.centerX /= centroidCount; loop.centerY /= centroidCount; loop.centerZ /= centroidCount;
    }
    loop.worldBounds = new Bounds3D(minX, minY, minZ, maxX, maxY, maxZ);
    return loop;
  }

  DCRTEMeshTopologyAnalysis analyzeComponentsAndVertices(TriangleMeshData mesh, MeshDomainReport meshReport) {
    DCRTEMeshTopologyAnalysis result = new DCRTEMeshTopologyAnalysis();
    if (mesh == null || mesh.triangleCount == 0) return result;
    DCRTEUnionFind union = new DCRTEUnionFind(mesh.triangleCount);
    java.util.HashMap<Long, Integer> firstTriangleByEdge = new java.util.HashMap<Long, Integer>();
    for (int t = 0; t < mesh.triangleCount; t++) {
      int[] vertices = {mesh.ia(t), mesh.ib(t), mesh.ic(t)};
      for (int edge = 0; edge < 3; edge++) {
        long key = dcrteCanonicalEdgeKey(vertices[edge], vertices[(edge + 1) % 3]);
        Integer first = firstTriangleByEdge.get(key);
        if (first == null) firstTriangleByEdge.put(key, t);
        else union.union(t, first.intValue());
      }
    }
    java.util.HashMap<Integer, Integer> componentIndexByRoot = new java.util.HashMap<Integer, Integer>();
    ArrayList<IntArrayBuilder> triangleLists = new ArrayList<IntArrayBuilder>();
    result.componentByTriangle = new int[mesh.triangleCount];
    for (int t = 0; t < mesh.triangleCount; t++) {
      int root = union.find(t);
      Integer componentIndex = componentIndexByRoot.get(root);
      if (componentIndex == null) {
        componentIndex = triangleLists.size();
        componentIndexByRoot.put(root, componentIndex);
        triangleLists.add(new IntArrayBuilder(64));
      }
      result.componentByTriangle[t] = componentIndex;
      triangleLists.get(componentIndex).add(t);
    }
    float totalArea = 0;
    double totalVolume = 0;
    for (int i = 0; i < triangleLists.size(); i++) {
      MeshComponentReport component = inspectComponent(mesh, i, triangleLists.get(i).toArray());
      result.components.add(component);
      totalArea += component.surfaceArea;
      totalVolume += component.absoluteVolume;
    }
    for (int i = 0; i < result.components.size(); i++) {
      MeshComponentReport component = result.components.get(i);
      component.surfaceAreaFraction = totalArea > 0 ? component.surfaceArea / totalArea : 0;
      component.volumeFraction = totalVolume > 0 ? (float)(component.absoluteVolume / totalVolume) : 0;
      component.tiny = component.surfaceAreaFraction < 0.01f || (component.closed && component.volumeFraction < 0.01f);
    }
    result.nonManifoldVertices = findNonManifoldVertices(mesh, meshReport, result.bowtieVertices, true);
    result.bowtieVertices = findBowtieVertices(mesh);
    result.nonManifoldVertices = mergeSortedUnique(result.nonManifoldVertices, result.bowtieVertices);
    return result;
  }

  MeshComponentReport inspectComponent(TriangleMeshData mesh, int componentIndex, int[] triangleIndices) {
    MeshComponentReport component = new MeshComponentReport();
    component.componentIndex = componentIndex;
    component.triangleIndices = triangleIndices;
    component.triangleCount = triangleIndices.length;
    boolean[] usedVertices = new boolean[mesh.vertexCount];
    java.util.HashMap<Long, Integer> edgeIncidence = new java.util.HashMap<Long, Integer>();
    java.util.HashMap<Long, Integer> edgeDirection = new java.util.HashMap<Long, Integer>();
    float minX = Float.POSITIVE_INFINITY; float minY = Float.POSITIVE_INFINITY; float minZ = Float.POSITIVE_INFINITY;
    float maxX = Float.NEGATIVE_INFINITY; float maxY = Float.NEGATIVE_INFINITY; float maxZ = Float.NEGATIVE_INFINITY;
    for (int i = 0; i < triangleIndices.length; i++) {
      int t = triangleIndices[i];
      int a = mesh.ia(t); int b = mesh.ib(t); int c = mesh.ic(t);
      usedVertices[a] = true; usedVertices[b] = true; usedVertices[c] = true;
      component.surfaceArea += (float)(0.5 * dcrteTriangleArea2(mesh.vertices, a, b, c));
      component.signedVolume += dcrteSignedTriangleVolume(mesh, t);
      int[] vertices = {a, b, c};
      for (int v = 0; v < 3; v++) {
        int vertex = vertices[v];
        minX = min(minX, mesh.vx(vertex)); minY = min(minY, mesh.vy(vertex)); minZ = min(minZ, mesh.vz(vertex));
        maxX = max(maxX, mesh.vx(vertex)); maxY = max(maxY, mesh.vy(vertex)); maxZ = max(maxZ, mesh.vz(vertex));
        int next = vertices[(v + 1) % 3];
        long key = dcrteCanonicalEdgeKey(vertex, next);
        Integer incidence = edgeIncidence.get(key);
        edgeIncidence.put(key, incidence == null ? 1 : incidence + 1);
        Integer direction = edgeDirection.get(key);
        int sign = vertex < next ? 1 : -1;
        edgeDirection.put(key, direction == null ? sign : direction + sign);
      }
    }
    for (int i = 0; i < usedVertices.length; i++) if (usedVertices[i]) component.vertexCount++;
    java.util.Iterator<Long> keys = edgeIncidence.keySet().iterator();
    int orientationErrors = 0;
    while (keys.hasNext()) {
      long key = keys.next();
      int incidence = edgeIncidence.get(key);
      if (incidence == 1) component.boundaryEdgeCount++;
      else if (incidence > 2) component.nonManifoldEdgeCount++;
      else if (incidence == 2 && edgeDirection.get(key) != 0) orientationErrors++;
    }
    component.closed = component.boundaryEdgeCount == 0 && component.nonManifoldEdgeCount == 0;
    component.isOpen = !component.closed;
    component.consistentlyOriented = orientationErrors == 0;
    component.absoluteVolume = Math.abs(component.signedVolume);
    component.worldBounds = new Bounds3D(minX, minY, minZ, maxX, maxY, maxZ);
    return component;
  }

  int[] findBowtieVertices(TriangleMeshData mesh) {
    ArrayList<IntArrayBuilder> incident = new ArrayList<IntArrayBuilder>();
    for (int i = 0; i < mesh.vertexCount; i++) incident.add(new IntArrayBuilder(8));
    for (int t = 0; t < mesh.triangleCount; t++) {
      incident.get(mesh.ia(t)).add(t); incident.get(mesh.ib(t)).add(t); incident.get(mesh.ic(t)).add(t);
    }
    IntArrayBuilder bowties = new IntArrayBuilder(16);
    for (int vertex = 0; vertex < mesh.vertexCount; vertex++) {
      int[] triangles = incident.get(vertex).toArray();
      if (triangles.length < 2) continue;
      boolean[] visited = new boolean[triangles.length];
      int fanCount = 0;
      int[] queue = new int[triangles.length];
      for (int seed = 0; seed < triangles.length; seed++) {
        if (visited[seed]) continue;
        fanCount++;
        int head = 0; int tail = 0;
        queue[tail++] = seed; visited[seed] = true;
        while (head < tail) {
          int current = queue[head++];
          for (int candidate = 0; candidate < triangles.length; candidate++) {
            if (visited[candidate]) continue;
            if (trianglesShareEdgeAtVertex(mesh, triangles[current], triangles[candidate], vertex)) {
              visited[candidate] = true;
              queue[tail++] = candidate;
            }
          }
        }
      }
      if (fanCount > 1) bowties.add(vertex);
    }
    return bowties.toArray();
  }

  int[] findNonManifoldVertices(TriangleMeshData mesh, MeshDomainReport meshReport, int[] ignored, boolean includeBoundaryBranches) {
    boolean[] marked = new boolean[mesh.vertexCount];
    if (meshReport != null) {
      for (int i = 0; i < meshReport.nonManifoldEdges.length; i++) {
        int a = dcrteEdgeKeyA(meshReport.nonManifoldEdges[i]);
        int b = dcrteEdgeKeyB(meshReport.nonManifoldEdges[i]);
        if (a >= 0 && a < marked.length) marked[a] = true;
        if (b >= 0 && b < marked.length) marked[b] = true;
      }
      if (includeBoundaryBranches) {
        int[] boundaryDegree = new int[mesh.vertexCount];
        for (int i = 0; i < meshReport.boundaryEdges.length; i++) {
          boundaryDegree[dcrteEdgeKeyA(meshReport.boundaryEdges[i])]++;
          boundaryDegree[dcrteEdgeKeyB(meshReport.boundaryEdges[i])]++;
        }
        for (int i = 0; i < boundaryDegree.length; i++) if (boundaryDegree[i] > 2) marked[i] = true;
      }
    }
    IntArrayBuilder vertices = new IntArrayBuilder(16);
    for (int i = 0; i < marked.length; i++) if (marked[i]) vertices.add(i);
    return vertices.toArray();
  }

  void addVertexTopologyDiagnostics(DomainPreflightReport report, TriangleMeshData mesh, DCRTEMeshTopologyAnalysis topology) {
    if (topology.nonManifoldVertices.length > 0) {
      int vertex = topology.nonManifoldVertices[0];
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_NONMANIFOLD_VERTICES, DiagnosticSeverity.BLOCKER,
        "TOPOLOGY", "Non-manifold vertices", "At least one vertex does not have a single disk-like surface neighborhood.",
        DCRTEPreflightActions.ACTION_REMOVE_NONMANIFOLD_GEOMETRY).withCount(topology.nonManifoldVertices.length)
        .at(mesh.vx(vertex), mesh.vy(vertex), mesh.vz(vertex)).topologyChange(true));
    }
    if (topology.bowtieVertices.length > 0) {
      int vertex = topology.bowtieVertices[0];
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOWTIE_VERTICES, DiagnosticSeverity.BLOCKER,
        "TOPOLOGY", "Bowtie vertex neighborhoods", "Disconnected surface fans touch only at a vertex.",
        DCRTEPreflightActions.ACTION_REMOVE_NONMANIFOLD_GEOMETRY).withCount(topology.bowtieVertices.length)
        .at(mesh.vx(vertex), mesh.vy(vertex), mesh.vz(vertex)).topologyChange(true));
    }
  }

  void addComponentDiagnostics(DomainPreflightReport report, TriangleMeshData mesh, DCRTEMeshTopologyAnalysis topology) {
    report.componentCount = topology.components.size();
    report.openComponentCount = 0;
    report.closedComponentCount = 0;
    int dominant = -1;
    float dominantFraction = 0;
    int tinyCount = 0;
    for (int i = 0; i < topology.components.size(); i++) {
      MeshComponentReport component = topology.components.get(i);
      if (component.closed) report.closedComponentCount++; else report.openComponentCount++;
      float fraction = component.closed && component.volumeFraction > 0 ? component.volumeFraction : component.surfaceAreaFraction;
      if (fraction > dominantFraction) { dominantFraction = fraction; dominant = i; }
      if (component.tiny) tinyCount++;
    }
    report.dominantComponentFraction = dominantFraction;
    report.singleDominantClosedComponent = dominant >= 0 && topology.components.get(dominant).closed && dominantFraction >= 0.98f;
    if (dominant >= 0 && topology.components.get(dominant).worldBounds != null) {
      float[] dimensions = {topology.components.get(dominant).worldBounds.sizeX(), topology.components.get(dominant).worldBounds.sizeY(), topology.components.get(dominant).worldBounds.sizeZ()};
      java.util.Arrays.sort(dimensions);
      report.elongationRatio = dimensions[1] > 0 ? dimensions[2] / dimensions[1] : 0;
      report.principalAxisConfidence = dimensions[2] > 0 ? constrain((dimensions[2] - dimensions[1]) / dimensions[2], 0, 1) : 0;
    }
    if (topology.components.size() > 1) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_DISCONNECTED_COMPONENTS, DiagnosticSeverity.BLOCKER,
        "COMPONENTS", "Disconnected surface components", "Strict imported-domain mode currently requires one connected closed shell.",
        DCRTEPreflightActions.ACTION_BOOLEAN_UNION_COMPONENTS).withCount(topology.components.size()).topologyChange(true));
      if (report.closedComponentCount > 1) {
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_CLOSED_COMPONENTS_MULTIPLE, DiagnosticSeverity.BLOCKER,
          "COMPONENTS", "Multiple closed shells", "Multi-shell containment semantics are not enabled in this milestone.",
          DCRTEPreflightActions.ACTION_BOOLEAN_UNION_COMPONENTS).withCount(report.closedComponentCount).topologyChange(true));
      }
    }
    if (report.openComponentCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_OPEN_COMPONENTS, DiagnosticSeverity.BLOCKER,
        "COMPONENTS", "Open components", "One or more surface components contain open boundaries.",
        DCRTEPreflightActions.ACTION_CLOSE_BOUNDARY_LOOPS).withCount(report.openComponentCount).topologyChange(true));
    }
    if (tinyCount > 0 && topology.components.size() > 1) {
      MeshComponentReport firstTiny = null;
      for (int i = 0; i < topology.components.size(); i++) if (topology.components.get(i).tiny) { firstTiny = topology.components.get(i); break; }
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_TINY_DISCONNECTED_COMPONENTS,
        DiagnosticSeverity.WARNING, "COMPONENTS", "Tiny disconnected shell", "A secondary component contributes less than one percent of area or closed volume; it was not deleted.",
        DCRTEPreflightActions.ACTION_DELETE_TINY_COMPONENTS).withCount(tinyCount).topologyChange(true);
      if (firstTiny != null && firstTiny.worldBounds != null) diagnostic.at(firstTiny.worldBounds.centerX(), firstTiny.worldBounds.centerY(), firstTiny.worldBounds.centerZ());
      report.addDiagnostic(diagnostic);
    }
    int nestedCount = detectNestedComponents(mesh, topology.components);
    report.nestedShellCount = nestedCount;
    report.nestedShellStatus = nestedCount > 0 ? "ambiguous_nested_shells" : "none_detected";
    if (nestedCount > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_NESTED_SHELLS, DiagnosticSeverity.BLOCKER,
        "COMPONENTS", "Nested shells", "A closed component lies inside another shell and cavity semantics are not enabled.",
        DCRTEPreflightActions.ACTION_REMOVE_INTERNAL_FACES).withCount(nestedCount).topologyChange(true));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_INTERNAL_SHELL_CANDIDATE, DiagnosticSeverity.WARNING,
        "COMPONENTS", "Internal shell candidate", "The nested component may be an internal face set or intentional cavity boundary.",
        DCRTEPreflightActions.ACTION_REMOVE_INTERNAL_FACES).withCount(nestedCount).topologyChange(true));
    }
  }

  int detectNestedComponents(TriangleMeshData mesh, ArrayList<MeshComponentReport> components) {
    int nested = 0;
    for (int inner = 0; inner < components.size(); inner++) {
      MeshComponentReport candidate = components.get(inner);
      if (!candidate.closed || candidate.triangleIndices.length == 0) continue;
      int vertex = mesh.ia(candidate.triangleIndices[0]);
      float x = mesh.vx(vertex); float y = mesh.vy(vertex); float z = mesh.vz(vertex);
      for (int outer = 0; outer < components.size(); outer++) {
        if (inner == outer) continue;
        MeshComponentReport container = components.get(outer);
        if (!container.closed || !dcrteBoundsContains(container.worldBounds, candidate.worldBounds, 0.000001f)) continue;
        if (pointInsideTriangleSubsetX(mesh, container.triangleIndices, x, y + 0.000003f, z + 0.000007f)) {
          candidate.nested = true;
          nested++;
          break;
        }
      }
    }
    return nested;
  }

  void addOrientationDiagnostics(DomainPreflightReport report, TriangleMeshData mesh,
      MeshDomainReport meshReport, DCRTEMeshTopologyAnalysis topology) {
    if (meshReport != null && meshReport.inconsistentOrientationEdgeCount > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_INCONSISTENT_EDGE_WINDING,
        DiagnosticSeverity.BLOCKER, "ORIENTATION", "Inconsistent edge winding",
        "Two-face edges do not consistently traverse in opposite directions.", DCRTEPreflightActions.ACTION_UNIFY_NORMALS)
        .withCount(meshReport.inconsistentOrientationEdgeCount).topologyChange(true);
      if (meshReport.orientationErrorEdges.length > 0) locateEdgeDiagnostic(diagnostic, mesh, meshReport.orientationErrorEdges[0]);
      report.addDiagnostic(diagnostic);
    }
    int inverted = 0;
    int nearZero = 0;
    float diagonal = mesh.worldBounds == null ? 1 : sqrt(sq(mesh.worldBounds.sizeX()) + sq(mesh.worldBounds.sizeY()) + sq(mesh.worldBounds.sizeZ()));
    double volumeTolerance = max(0.000000000001, diagonal * diagonal * diagonal * 0.000000001);
    for (int i = 0; i < topology.components.size(); i++) {
      MeshComponentReport component = topology.components.get(i);
      if (!component.consistentlyOriented) {
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_COMPONENT_WINDING_INCONSISTENT,
          DiagnosticSeverity.BLOCKER, "ORIENTATION", "Component winding inconsistent",
          "Component " + i + " has inconsistent local edge orientation.", DCRTEPreflightActions.ACTION_UNIFY_NORMALS).topologyChange(true));
      }
      if (component.closed && component.signedVolume < -volumeTolerance) inverted++;
      if (component.closed && component.absoluteVolume <= volumeTolerance) nearZero++;
    }
    if (inverted > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_COMPONENT_WINDING_INVERTED,
        topology.components.size() == 1 ? DiagnosticSeverity.INFO : DiagnosticSeverity.BLOCKER,
        "ORIENTATION", "Inverted component winding",
        topology.components.size() == 1 ? "The single valid closed component may be globally flipped safely."
          : "Per-component winding normalization is not automatic while containment is unresolved.",
        DCRTEPreflightActions.ACTION_UNIFY_NORMALS).withCount(inverted).topologyChange(topology.components.size() != 1));
    }
    if (meshReport != null && meshReport.globalWindingFlipped) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_GLOBAL_WINDING_INVERTED,
        DiagnosticSeverity.INFO, "ORIENTATION", "Global winding normalized",
        "The one closed consistently oriented component had negative volume and was globally flipped.", "").sanitizable(true));
    }
    if (nearZero > 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SIGNED_VOLUME_NEAR_ZERO,
        DiagnosticSeverity.BLOCKER, "ORIENTATION", "Near-zero signed volume",
        "A closed component has insufficient signed volume for reliable orientation semantics.",
        DCRTEPreflightActions.ACTION_REEXPORT_WATERTIGHT).withCount(nearZero));
    }
  }

  void addSelfIntersectionDiagnostics(DomainPreflightReport report, TriangleMeshData mesh,
      DCRTEMeshTopologyAnalysis topology, SelfIntersectionReport intersections) {
    if (intersections == null) return;
    report.selfIntersectionStatus = intersections.confirmedIntersectionCount > 0 ? "confirmed"
      : intersections.candidateLimitReached ? "suspected_unresolved" : "none_confirmed";
    if (intersections.confirmedIntersectionCount > 0) {
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_SELF_INTERSECTION,
        DiagnosticSeverity.BLOCKER, "SELF_INTERSECTION", "Self-intersecting surface",
        "Non-adjacent triangle crossings prevent the mesh from acting as a reliable signed boundary.",
        DCRTEPreflightActions.ACTION_INSPECT_SELF_INTERSECTIONS).withCount(intersections.confirmedIntersectionCount).topologyChange(true);
      if (intersections.triangleA.length > 0) diagnostic.withTrianglePair(intersections.triangleA[0], intersections.triangleB[0]);
      if (intersections.worldLocations.length >= 3) diagnostic.at(intersections.worldLocations[0], intersections.worldLocations[1], intersections.worldLocations[2]);
      report.addDiagnostic(diagnostic);
      if (intersections.coplanarOverlapCount > 0) {
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_COPLANAR_OVERLAP, DiagnosticSeverity.BLOCKER,
          "SELF_INTERSECTION", "Coplanar triangle overlap", "Non-adjacent coplanar faces overlap geometrically.",
          DCRTEPreflightActions.ACTION_REMOVE_INTERNAL_FACES).withCount(intersections.coplanarOverlapCount).topologyChange(true));
      }
      int componentIntersections = 0;
      for (int i = 0; i < intersections.triangleA.length; i++) {
        int a = intersections.triangleA[i]; int b = intersections.triangleB[i];
        if (a >= 0 && b >= 0 && a < topology.componentByTriangle.length && b < topology.componentByTriangle.length
            && topology.componentByTriangle[a] != topology.componentByTriangle[b]) componentIntersections++;
      }
      if (componentIntersections > 0) {
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_COMPONENT_INTERSECTION, DiagnosticSeverity.BLOCKER,
          "SELF_INTERSECTION", "Intersecting components", "Disconnected shells cross or overlap in space.",
          DCRTEPreflightActions.ACTION_SEPARATE_INTERSECTING_SHELLS).withCount(componentIntersections).topologyChange(true));
        report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_COMPONENT_CONTACT_OR_OVERLAP, DiagnosticSeverity.BLOCKER,
          "COMPONENTS", "Component contact or overlap", "Component boundaries are not spatially independent.",
          DCRTEPreflightActions.ACTION_SEPARATE_INTERSECTING_SHELLS).withCount(componentIntersections).topologyChange(true));
      }
    }
    if (intersections.candidateLimitReached) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SELF_INTERSECTION_SUSPECTED,
        DiagnosticSeverity.WARNING, "SELF_INTERSECTION", "Intersection candidate limit reached",
        "Candidate density exceeded the deterministic in-app test budget; absence of further crossings is not claimed.",
        DCRTEPreflightActions.ACTION_SIMPLIFY_SOURCE_MESH).withCount(intersections.candidatePairCount));
    }
  }

  void addTransformDiagnostics(DomainPreflightReport report, TriangleMeshData sourceMesh, TriangleMeshData worldMesh,
      MeshTransform transform, Bounds3D observerBounds, int resolution) {
    if (transform == null || !transform.isValid() || worldMesh == null || worldMesh.worldBounds == null || !worldMesh.worldBounds.isValid()) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_INVALID, DiagnosticSeverity.BLOCKER,
        "TRANSFORM", "Invalid source-to-world transform", "The normalized mesh transform is missing or non-finite.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
      return;
    }
    if (transform.uniformScale <= 0) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_NONINVERTIBLE, DiagnosticSeverity.BLOCKER,
        "TRANSFORM", "Non-invertible transform", "The uniform scale is not positive.",
        DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
    }
    if (transform.rotateXQuarterTurns < 0 || transform.rotateXQuarterTurns > 3
        || transform.rotateYQuarterTurns < 0 || transform.rotateYQuarterTurns > 3
        || transform.rotateZQuarterTurns < 0 || transform.rotateZQuarterTurns > 3) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_ROTATION_STATE_INVALID, DiagnosticSeverity.BLOCKER,
        "TRANSFORM", "Invalid quarter-turn state", "Rotation state must remain in the normalized range 0..3.",
        DCRTEPreflightActions.ACTION_REORIENT_DOMAIN));
    }
    Bounds3D world = worldMesh.worldBounds;
    boolean outside = world.minX < observerBounds.minX || world.minY < observerBounds.minY || world.minZ < observerBounds.minZ
      || world.maxX > observerBounds.maxX || world.maxY > observerBounds.maxY || world.maxZ > observerBounds.maxZ;
    if (outside) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_OUTSIDE_OBSERVER, DiagnosticSeverity.BLOCKER,
        "TRANSFORM", "Transformed mesh outside observer", "The fitted mesh exceeds the signed-distance build bounds.",
        DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_CLIPPING, DiagnosticSeverity.BLOCKER,
        "TRANSFORM", "Transform clipping", "One or more triangles would be clipped by the observer volume.",
        DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN));
    }
    float margin = min(world.minX - observerBounds.minX, min(world.minY - observerBounds.minY, min(world.minZ - observerBounds.minZ,
      min(observerBounds.maxX - world.maxX, min(observerBounds.maxY - world.maxY, observerBounds.maxZ - world.maxZ)))));
    float spacing = min(observerBounds.sizeX(), min(observerBounds.sizeY(), observerBounds.sizeZ())) / max(1, resolution);
    if (margin < spacing * 2.0f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_MARGIN_TOO_SMALL, DiagnosticSeverity.WARNING,
        "TRANSFORM", "Transform margin below two voxels", "Boundary diagnostics may touch or alias against the grid edge.",
        DCRTEPreflightActions.ACTION_REDUCE_DOMAIN_SCALE_MARGIN).withValue(margin, spacing * 2.0f));
    }
    float[] sourceDimensions = {sourceMesh.sourceBounds.sizeX(), sourceMesh.sourceBounds.sizeY(), sourceMesh.sourceBounds.sizeZ()};
    float[] worldDimensions = {world.sizeX(), world.sizeY(), world.sizeZ()};
    java.util.Arrays.sort(sourceDimensions);
    java.util.Arrays.sort(worldDimensions);
    float sourceRatioA = sourceDimensions[2] > 0 ? sourceDimensions[1] / sourceDimensions[2] : 0;
    float sourceRatioB = sourceDimensions[2] > 0 ? sourceDimensions[0] / sourceDimensions[2] : 0;
    float worldRatioA = worldDimensions[2] > 0 ? worldDimensions[1] / worldDimensions[2] : 0;
    float worldRatioB = worldDimensions[2] > 0 ? worldDimensions[0] / worldDimensions[2] : 0;
    if (abs(sourceRatioA - worldRatioA) > 0.00001f || abs(sourceRatioB - worldRatioB) > 0.00001f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_TRANSFORM_ASPECT_PRESERVATION_FAILURE,
        DiagnosticSeverity.BLOCKER, "TRANSFORM", "Aspect preservation failure",
        "The source-to-world fit is not uniformly scaled.", DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE));
    }
    float[] worldPoint = new float[3];
    float[] sourcePoint = new float[3];
    float maxError = 0;
    int sampleStride = max(1, sourceMesh.vertexCount / 256);
    for (int vertex = 0; vertex < sourceMesh.vertexCount; vertex += sampleStride) {
      transform.apply(sourceMesh.vx(vertex), sourceMesh.vy(vertex), sourceMesh.vz(vertex), worldPoint);
      transform.applyInverse(worldPoint[0], worldPoint[1], worldPoint[2], sourcePoint);
      maxError = max(maxError, sqrt(dcrteDistanceSq(sourceMesh.vx(vertex), sourceMesh.vy(vertex), sourceMesh.vz(vertex),
        sourcePoint[0], sourcePoint[1], sourcePoint[2])));
    }
    float sourceDiagonal = sqrt(sq(sourceMesh.sourceBounds.sizeX()) + sq(sourceMesh.sourceBounds.sizeY()) + sq(sourceMesh.sourceBounds.sizeZ()));
    if (!dcrteFinite(maxError) || maxError > max(0.000001f, sourceDiagonal * 0.00001f)) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_SOURCE_TO_WORLD_PRECISION_LOSS,
        DiagnosticSeverity.BLOCKER, "TRANSFORM", "Source-to-world precision loss",
        "Inverse transform round-trip error exceeds tolerance.", DCRTEPreflightActions.ACTION_RETRY_WITH_CANONICAL_FIXTURE)
        .withValue(maxError, max(0.000001f, sourceDiagonal * 0.00001f)));
    }
  }

  ResolutionSuitability inspectResolution(TriangleMeshData mesh, int resolution, Bounds3D observerBounds,
      VoxelBoundaryVolume boundary) {
    ResolutionSuitability result = new ResolutionSuitability();
    if (mesh == null || mesh.triangleCount == 0 || observerBounds == null || !observerBounds.isValid()) return result;
    result.voxelSpacing = min(observerBounds.sizeX(), min(observerBounds.sizeY(), observerBounds.sizeZ())) / max(1, resolution);
    Bounds3D bounds = mesh.worldBounds == null ? mesh.sourceBounds : mesh.worldBounds;
    result.meshDiagonal = sqrt(sq(bounds.sizeX()) + sq(bounds.sizeY()) + sq(bounds.sizeZ()));
    float[] edges = new float[mesh.triangleCount * 3];
    float[] altitudes = new float[mesh.triangleCount];
    int edgeCount = 0;
    for (int t = 0; t < mesh.triangleCount; t++) {
      float ab = dcrteVertexDistance(mesh, mesh.ia(t), mesh.ib(t));
      float bc = dcrteVertexDistance(mesh, mesh.ib(t), mesh.ic(t));
      float ca = dcrteVertexDistance(mesh, mesh.ic(t), mesh.ia(t));
      edges[edgeCount++] = ab; edges[edgeCount++] = bc; edges[edgeCount++] = ca;
      float longest = max(ab, max(bc, ca));
      altitudes[t] = longest > 0 ? (float)dcrteTriangleArea2(mesh.vertices, mesh.ia(t), mesh.ib(t), mesh.ic(t)) / longest : 0;
    }
    java.util.Arrays.sort(edges, 0, edgeCount);
    java.util.Arrays.sort(altitudes);
    result.minimumEdge = edgeCount == 0 ? 0 : edges[0];
    result.edgeP05 = edgeCount == 0 ? 0 : edges[min(edgeCount - 1, (int)floor((edgeCount - 1) * 0.05f))];
    result.medianEdge = edgeCount == 0 ? 0 : edges[edgeCount / 2];
    result.minimumTriangleAltitude = altitudes.length == 0 ? 0 : altitudes[0];
    result.triangleAltitudeP05 = altitudes.length == 0 ? 0 : altitudes[min(altitudes.length - 1, (int)floor((altitudes.length - 1) * 0.05f))];
    if (boundary != null && boundary.boundary.length > 0) {
      float expectedSurfaceCells = dcrteMeshSurfaceArea(mesh) / max(0.000000001f, result.voxelSpacing * result.voxelSpacing);
      result.boundaryCoverageRatio = expectedSurfaceCells > 0 ? boundary.boundaryCount / expectedSurfaceCells : 0;
    }
    float edgeConfidence = result.voxelSpacing > 0 ? constrain(result.edgeP05 / (2.0f * result.voxelSpacing), 0, 1) : 0;
    float altitudeConfidence = result.voxelSpacing > 0 ? constrain(result.triangleAltitudeP05 / (2.0f * result.voxelSpacing), 0, 1) : 0;
    result.estimatedConfidence = min(edgeConfidence, altitudeConfidence);
    if (boundary != null && result.boundaryCoverageRatio >= 0) {
      float coverageConfidence = constrain(result.boundaryCoverageRatio / 0.55f, 0, 1);
      result.estimatedConfidence = min(result.estimatedConfidence, coverageConfidence);
    }
    result.estimatedMinimumResolvedWall = result.voxelSpacing * 2.0f;
    result.estimatedMinimumResolvedChannel = result.voxelSpacing * 2.0f;
    float riskSize = min(result.edgeP05, result.triangleAltitudeP05);
    result.recommendedMinimumResolution = riskSize > 0
      ? max(32, (int)Math.ceil(min(observerBounds.sizeX(), min(observerBounds.sizeY(), observerBounds.sizeZ())) * 2.0f / riskSize))
      : 128;
    if (result.estimatedConfidence < 0.38f) result.reasons.add("mesh-derived feature indicators fall below two voxel spacings");
    if (result.minimumEdge < result.voxelSpacing) result.reasons.add("at least one source edge projects below one voxel");
    if (result.minimumTriangleAltitude < result.voxelSpacing) result.reasons.add("at least one triangle altitude projects below one voxel");
    result.reasons.add("edge and triangle sizes are risk indicators, not physical wall-thickness measurements");
    return result;
  }

  void addResolutionDiagnostics(DomainPreflightReport report, TriangleMeshData mesh, ResolutionSuitability suitability) {
    if (suitability == null) return;
    if (suitability.minimumEdge < suitability.voxelSpacing || suitability.minimumTriangleAltitude < suitability.voxelSpacing) {
      report.thinFeatureRisk = true;
      int triangle = dcrteSmallestAltitudeTriangle(mesh);
      DomainDiagnostic diagnostic = new DomainDiagnostic(DCRTEPreflightCodes.PF_FEATURE_BELOW_ONE_VOXEL,
        DiagnosticSeverity.WARNING, "RESOLUTION", "Mesh feature indicator below one voxel",
        "At least one tessellation feature is smaller than the selected voxel spacing; physical wall thickness is not inferred.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(min(suitability.minimumEdge, suitability.minimumTriangleAltitude), suitability.voxelSpacing)
        .withTriangle(triangle);
      locateTriangleDiagnostic(diagnostic, mesh, triangle);
      report.addDiagnostic(diagnostic);
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_THIN_WALL_UNRESOLVED,
        DiagnosticSeverity.WARNING, "RESOLUTION", "Thin-wall risk unresolved",
        "The selected grid cannot prove that sub-voxel walls or channels persist.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(suitability.estimatedMinimumResolvedWall, suitability.voxelSpacing * 2.0f));
    } else if (suitability.edgeP05 < suitability.voxelSpacing * 2.0f || suitability.triangleAltitudeP05 < suitability.voxelSpacing * 2.0f) {
      report.thinFeatureRisk = true;
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_FEATURE_BELOW_TWO_VOXELS,
        DiagnosticSeverity.WARNING, "RESOLUTION", "Mesh feature indicators below two voxels",
        "Fine structure may alias at the selected resolution.", DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION)
        .withValue(min(suitability.edgeP05, suitability.triangleAltitudeP05), suitability.voxelSpacing * 2.0f));
    }
    if (suitability.estimatedConfidence < 0.38f) {
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_VOXEL_RESOLUTION_TOO_LOW,
        DiagnosticSeverity.WARNING, "RESOLUTION", "Low SDF resolution confidence",
        "Increase resolution to test whether fine components and channels persist; resolution was not changed automatically.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION).withValue(suitability.estimatedConfidence, 0.38f));
      report.addDiagnostic(new DomainDiagnostic(DCRTEPreflightCodes.PF_BOUNDARY_ALIASING_HIGH,
        DiagnosticSeverity.WARNING, "RESOLUTION", "Boundary aliasing risk high",
        "Tessellation-derived feature indicators are too close to the voxel spacing for a strong boundary claim.",
        DCRTEPreflightActions.ACTION_INCREASE_SDF_RESOLUTION));
    }
  }

  SelfIntersectionReport analyzeSelfIntersections(TriangleMeshData mesh, int[] componentByTriangle) {
    long start = millis();
    SelfIntersectionReport report = new SelfIntersectionReport();
    if (mesh == null || mesh.triangleCount < 2 || mesh.worldBounds == null || !mesh.worldBounds.isValid()) return report;
    int gridSize = constrain((int)Math.ceil(Math.cbrt(max(1, mesh.triangleCount)) * 1.5), 4, 36);
    Bounds3D bounds = mesh.worldBounds;
    float dx = max(0.0000001f, bounds.sizeX() / gridSize);
    float dy = max(0.0000001f, bounds.sizeY() / gridSize);
    float dz = max(0.0000001f, bounds.sizeZ() / gridSize);
    java.util.HashMap<Long, IntArrayBuilder> cells = new java.util.HashMap<Long, IntArrayBuilder>();
    java.util.HashSet<Long> candidatePairs = new java.util.HashSet<Long>();
    for (int t = 0; t < mesh.triangleCount; t++) {
      float[] aabb = dcrteTriangleAabb(mesh, t);
      int x0 = constrain((int)floor((aabb[0] - bounds.minX) / dx), 0, gridSize - 1);
      int y0 = constrain((int)floor((aabb[1] - bounds.minY) / dy), 0, gridSize - 1);
      int z0 = constrain((int)floor((aabb[2] - bounds.minZ) / dz), 0, gridSize - 1);
      int x1 = constrain((int)floor((aabb[3] - bounds.minX) / dx), 0, gridSize - 1);
      int y1 = constrain((int)floor((aabb[4] - bounds.minY) / dy), 0, gridSize - 1);
      int z1 = constrain((int)floor((aabb[5] - bounds.minZ) / dz), 0, gridSize - 1);
      for (int z = z0; z <= z1; z++) for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) {
        long cellKey = (((long)x) << 42) | (((long)y) << 21) | (long)z;
        IntArrayBuilder occupants = cells.get(cellKey);
        if (occupants == null) { occupants = new IntArrayBuilder(8); cells.put(cellKey, occupants); }
        for (int i = 0; i < occupants.size; i++) {
          int other = occupants.values[i];
          long pair = dcrteTrianglePairKey(other, t);
          if (candidatePairs.size() < DCRTE_PREFLIGHT_MAX_INTERSECTION_CANDIDATES) candidatePairs.add(pair);
          else report.candidateLimitReached = true;
        }
        occupants.add(t);
      }
    }
    report.candidatePairCount = candidatePairs.size();
    long[] sortedPairs = new long[candidatePairs.size()];
    int pairIndex = 0;
    java.util.Iterator<Long> iterator = candidatePairs.iterator();
    while (iterator.hasNext()) sortedPairs[pairIndex++] = iterator.next();
    java.util.Arrays.sort(sortedPairs);
    IntArrayBuilder triangleA = new IntArrayBuilder(32);
    IntArrayBuilder triangleB = new IntArrayBuilder(32);
    FloatArrayBuilder locations = new FloatArrayBuilder(96);
    float epsilon = max(0.0000001f, sqrt(sq(bounds.sizeX()) + sq(bounds.sizeY()) + sq(bounds.sizeZ())) * 0.0000001f);
    for (int i = 0; i < sortedPairs.length; i++) {
      int a = (int)(sortedPairs[i] >>> 32);
      int b = (int)sortedPairs[i];
      int shared = dcrteSharedVertexCount(mesh, a, b);
      boolean sameComponent = componentByTriangle != null && a < componentByTriangle.length && b < componentByTriangle.length
        && componentByTriangle[a] == componentByTriangle[b];
      if (shared >= 2 || (sameComponent && shared > 0)) { report.skippedAdjacentPairCount++; continue; }
      if (!dcrteTriangleAabbOverlap(mesh, a, b, epsilon)) continue;
      report.testedPairCount++;
      int intersectionType = dcrteTriangleIntersectionType(mesh, a, b, epsilon);
      if (intersectionType == 0) continue;
      report.confirmedIntersectionCount++;
      if (intersectionType == 2) report.coplanarOverlapCount++;
      if (triangleA.size < DCRTE_PREFLIGHT_MAX_INTERSECTION_EXAMPLES) {
        triangleA.add(a); triangleB.add(b);
        float[] center = dcrteTrianglePairCenter(mesh, a, b);
        locations.add3(center[0], center[1], center[2]);
      }
    }
    report.triangleA = triangleA.toArray();
    report.triangleB = triangleB.toArray();
    report.worldLocations = locations.toArray();
    report.elapsedMillis = millis() - start;
    return report;
  }

  void completeStage(DomainPreflightReport report, String stage, long start, String passReason) {
    boolean blocker = false;
    boolean warning = false;
    for (int i = 0; i < report.diagnostics.size(); i++) {
      DomainDiagnostic diagnostic = report.diagnostics.get(i);
      if (!stage.equals(diagnostic.stage)) continue;
      if (diagnostic.severity == DiagnosticSeverity.BLOCKER) blocker = true;
      else if (diagnostic.severity == DiagnosticSeverity.WARNING) warning = true;
    }
    report.setStage(stage, blocker ? DCRTEPreflightStageState.BLOCKED : warning ? DCRTEPreflightStageState.WARNING : DCRTEPreflightStageState.PASS,
      blocker ? "one or more blocking diagnostics were found" : warning ? "completed with warnings" : passReason, millis() - start);
    report.refreshSummary();
  }
}

void dcrteSkipPreflightStagesAfter(DomainPreflightReport report, String stage, String reason) {
  int start = dcrtePreflightStageIndex(stage) + 1;
  String[] names = dcrtePreflightStageNames();
  for (int i = start; i < names.length; i++) report.setStage(names[i], DCRTEPreflightStageState.SKIPPED, reason, 0);
}

void dcrteAddAdjacentVertex(java.util.HashMap<Integer, ArrayList<Integer>> adjacency, int vertex, int neighbor) {
  ArrayList<Integer> neighbors = adjacency.get(vertex);
  if (neighbors == null) { neighbors = new ArrayList<Integer>(); adjacency.put(vertex, neighbors); }
  if (!neighbors.contains(neighbor)) neighbors.add(neighbor);
}

int dcrteEdgeKeyA(long key) { return (int)(key >>> 32); }
int dcrteEdgeKeyB(long key) { return (int)key; }
long dcrteCanonicalEdgeKey(int a, int b) {
  int low = min(a, b); int high = max(a, b);
  return ((long)low << 32) | (high & 0xffffffffL);
}

long dcrteTrianglePairKey(int a, int b) {
  int low = min(a, b); int high = max(a, b);
  return ((long)low << 32) | (high & 0xffffffffL);
}

void locateEdgeDiagnostic(DomainDiagnostic diagnostic, TriangleMeshData mesh, long edgeKey) {
  int a = dcrteEdgeKeyA(edgeKey); int b = dcrteEdgeKeyB(edgeKey);
  if (mesh == null || a < 0 || b < 0 || a >= mesh.vertexCount || b >= mesh.vertexCount) return;
  diagnostic.withEdge(a, b).at((mesh.vx(a) + mesh.vx(b)) * 0.5f,
    (mesh.vy(a) + mesh.vy(b)) * 0.5f, (mesh.vz(a) + mesh.vz(b)) * 0.5f);
}

void locateTriangleDiagnostic(DomainDiagnostic diagnostic, TriangleMeshData mesh, int triangle) {
  if (diagnostic == null || mesh == null || triangle < 0 || triangle >= mesh.triangleCount) return;
  diagnostic.at((mesh.vx(mesh.ia(triangle)) + mesh.vx(mesh.ib(triangle)) + mesh.vx(mesh.ic(triangle))) / 3.0f,
    (mesh.vy(mesh.ia(triangle)) + mesh.vy(mesh.ib(triangle)) + mesh.vy(mesh.ic(triangle))) / 3.0f,
    (mesh.vz(mesh.ia(triangle)) + mesh.vz(mesh.ib(triangle)) + mesh.vz(mesh.ic(triangle))) / 3.0f);
}

boolean trianglesShareEdgeAtVertex(TriangleMeshData mesh, int triangleA, int triangleB, int vertex) {
  int[] a = {mesh.ia(triangleA), mesh.ib(triangleA), mesh.ic(triangleA)};
  int[] b = {mesh.ia(triangleB), mesh.ib(triangleB), mesh.ic(triangleB)};
  for (int i = 0; i < 3; i++) {
    if (a[i] == vertex) continue;
    for (int j = 0; j < 3; j++) if (b[j] == a[i] && b[j] != vertex) return true;
  }
  return false;
}

int[] mergeSortedUnique(int[] a, int[] b) {
  java.util.HashSet<Integer> values = new java.util.HashSet<Integer>();
  for (int i = 0; i < a.length; i++) values.add(a[i]);
  for (int i = 0; i < b.length; i++) values.add(b[i]);
  int[] result = new int[values.size()];
  int index = 0;
  java.util.Iterator<Integer> iterator = values.iterator();
  while (iterator.hasNext()) result[index++] = iterator.next();
  java.util.Arrays.sort(result);
  return result;
}

double dcrteSignedTriangleVolume(TriangleMeshData mesh, int triangle) {
  int ai = mesh.ia(triangle) * 3; int bi = mesh.ib(triangle) * 3; int ci = mesh.ic(triangle) * 3;
  double ax = mesh.vertices[ai]; double ay = mesh.vertices[ai + 1]; double az = mesh.vertices[ai + 2];
  double bx = mesh.vertices[bi]; double by = mesh.vertices[bi + 1]; double bz = mesh.vertices[bi + 2];
  double cx = mesh.vertices[ci]; double cy = mesh.vertices[ci + 1]; double cz = mesh.vertices[ci + 2];
  return (ax * (by * cz - bz * cy) + ay * (bz * cx - bx * cz) + az * (bx * cy - by * cx)) / 6.0;
}

boolean dcrteBoundsContains(Bounds3D outer, Bounds3D inner, float epsilon) {
  return outer != null && inner != null && outer.isValid() && inner.isValid()
    && inner.minX >= outer.minX - epsilon && inner.maxX <= outer.maxX + epsilon
    && inner.minY >= outer.minY - epsilon && inner.maxY <= outer.maxY + epsilon
    && inner.minZ >= outer.minZ - epsilon && inner.maxZ <= outer.maxZ + epsilon;
}

boolean pointInsideTriangleSubsetX(TriangleMeshData mesh, int[] triangles, float px, float py, float pz) {
  float[] intersections = new float[max(8, triangles.length)];
  int count = 0;
  for (int i = 0; i < triangles.length; i++) {
    int t = triangles[i];
    int ai = mesh.ia(t) * 3; int bi = mesh.ib(t) * 3; int ci = mesh.ic(t) * 3;
    float ay = mesh.vertices[ai + 1]; float az = mesh.vertices[ai + 2];
    float by = mesh.vertices[bi + 1]; float bz = mesh.vertices[bi + 2];
    float cy = mesh.vertices[ci + 1]; float cz = mesh.vertices[ci + 2];
    float denominator = (by - cy) * (az - cz) + (cz - bz) * (ay - cy);
    if (abs(denominator) <= 0.0000000001f) continue;
    float u = ((by - cy) * (pz - cz) + (cz - bz) * (py - cy)) / denominator;
    float v = ((cy - ay) * (pz - cz) + (az - cz) * (py - cy)) / denominator;
    float w = 1 - u - v;
    if (u < -0.000001f || v < -0.000001f || w < -0.000001f) continue;
    float x = u * mesh.vertices[ai] + v * mesh.vertices[bi] + w * mesh.vertices[ci];
    if (x > px) intersections[count++] = x;
  }
  java.util.Arrays.sort(intersections, 0, count);
  int unique = dcrteDeduplicateIntersections(intersections, count, 0.000001f);
  return (unique & 1) == 1;
}

float dcrteVertexDistance(TriangleMeshData mesh, int a, int b) {
  return sqrt(dcrteDistanceSq(mesh.vx(a), mesh.vy(a), mesh.vz(a), mesh.vx(b), mesh.vy(b), mesh.vz(b)));
}

float dcrteMeshSurfaceArea(TriangleMeshData mesh) {
  float area = 0;
  for (int t = 0; t < mesh.triangleCount; t++) area += (float)(0.5 * dcrteTriangleArea2(mesh.vertices, mesh.ia(t), mesh.ib(t), mesh.ic(t)));
  return area;
}

int dcrteSmallestAltitudeTriangle(TriangleMeshData mesh) {
  int best = -1;
  float minimum = Float.POSITIVE_INFINITY;
  for (int t = 0; t < mesh.triangleCount; t++) {
    float ab = dcrteVertexDistance(mesh, mesh.ia(t), mesh.ib(t));
    float bc = dcrteVertexDistance(mesh, mesh.ib(t), mesh.ic(t));
    float ca = dcrteVertexDistance(mesh, mesh.ic(t), mesh.ia(t));
    float longest = max(ab, max(bc, ca));
    float altitude = longest > 0 ? (float)dcrteTriangleArea2(mesh.vertices, mesh.ia(t), mesh.ib(t), mesh.ic(t)) / longest : 0;
    if (altitude < minimum) { minimum = altitude; best = t; }
  }
  return best;
}

float[] dcrteTriangleAabb(TriangleMeshData mesh, int triangle) {
  int a = mesh.ia(triangle); int b = mesh.ib(triangle); int c = mesh.ic(triangle);
  return new float[] {min(mesh.vx(a), min(mesh.vx(b), mesh.vx(c))), min(mesh.vy(a), min(mesh.vy(b), mesh.vy(c))),
    min(mesh.vz(a), min(mesh.vz(b), mesh.vz(c))), max(mesh.vx(a), max(mesh.vx(b), mesh.vx(c))),
    max(mesh.vy(a), max(mesh.vy(b), mesh.vy(c))), max(mesh.vz(a), max(mesh.vz(b), mesh.vz(c)))};
}

boolean dcrteTriangleAabbOverlap(TriangleMeshData mesh, int a, int b, float epsilon) {
  float[] aa = dcrteTriangleAabb(mesh, a); float[] bb = dcrteTriangleAabb(mesh, b);
  return aa[3] + epsilon >= bb[0] && bb[3] + epsilon >= aa[0]
    && aa[4] + epsilon >= bb[1] && bb[4] + epsilon >= aa[1]
    && aa[5] + epsilon >= bb[2] && bb[5] + epsilon >= aa[2];
}

int dcrteSharedVertexCount(TriangleMeshData mesh, int a, int b) {
  int[] av = {mesh.ia(a), mesh.ib(a), mesh.ic(a)};
  int[] bv = {mesh.ia(b), mesh.ib(b), mesh.ic(b)};
  int count = 0;
  for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) if (av[i] == bv[j]) count++;
  return count;
}

float[] dcrteTrianglePairCenter(TriangleMeshData mesh, int a, int b) {
  int[] vertices = {mesh.ia(a), mesh.ib(a), mesh.ic(a), mesh.ia(b), mesh.ib(b), mesh.ic(b)};
  float x = 0; float y = 0; float z = 0;
  for (int i = 0; i < vertices.length; i++) { x += mesh.vx(vertices[i]); y += mesh.vy(vertices[i]); z += mesh.vz(vertices[i]); }
  return new float[] {x / 6.0f, y / 6.0f, z / 6.0f};
}

int dcrteTriangleIntersectionType(TriangleMeshData mesh, int triangleA, int triangleB, float epsilon) {
  float[] a = dcrteTriangleCoordinates(mesh, triangleA);
  float[] b = dcrteTriangleCoordinates(mesh, triangleB);
  float[] normalA = dcrteTriangleNormal(a);
  float[] normalB = dcrteTriangleNormal(b);
  float crossX = normalA[1] * normalB[2] - normalA[2] * normalB[1];
  float crossY = normalA[2] * normalB[0] - normalA[0] * normalB[2];
  float crossZ = normalA[0] * normalB[1] - normalA[1] * normalB[0];
  float crossMagnitude = sqrt(crossX * crossX + crossY * crossY + crossZ * crossZ);
  float normalProduct = sqrt((sq(normalA[0]) + sq(normalA[1]) + sq(normalA[2]))
    * (sq(normalB[0]) + sq(normalB[1]) + sq(normalB[2])));
  boolean parallel = normalProduct > 0 && crossMagnitude <= epsilon * normalProduct * 10.0f;
  if (parallel && abs(dcrtePointPlaneDistance(b[0], b[1], b[2], a[0], a[1], a[2], normalA)) <= epsilon * 10.0f) {
    return dcrteCoplanarTrianglesOverlap(a, b, normalA, epsilon) ? 2 : 0;
  }
  for (int edge = 0; edge < 3; edge++) {
    int next = (edge + 1) % 3;
    if (dcrteSegmentTriangleIntersection(a[edge * 3], a[edge * 3 + 1], a[edge * 3 + 2],
        a[next * 3], a[next * 3 + 1], a[next * 3 + 2], b, epsilon)) return 1;
    if (dcrteSegmentTriangleIntersection(b[edge * 3], b[edge * 3 + 1], b[edge * 3 + 2],
        b[next * 3], b[next * 3 + 1], b[next * 3 + 2], a, epsilon)) return 1;
  }
  return 0;
}

float[] dcrteTriangleCoordinates(TriangleMeshData mesh, int triangle) {
  int[] vertices = {mesh.ia(triangle), mesh.ib(triangle), mesh.ic(triangle)};
  float[] result = new float[9];
  for (int i = 0; i < 3; i++) {
    result[i * 3] = mesh.vx(vertices[i]); result[i * 3 + 1] = mesh.vy(vertices[i]); result[i * 3 + 2] = mesh.vz(vertices[i]);
  }
  return result;
}

float[] dcrteTriangleNormal(float[] triangle) {
  float ux = triangle[3] - triangle[0]; float uy = triangle[4] - triangle[1]; float uz = triangle[5] - triangle[2];
  float vx = triangle[6] - triangle[0]; float vy = triangle[7] - triangle[1]; float vz = triangle[8] - triangle[2];
  return new float[] {uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx};
}

float dcrtePointPlaneDistance(float x, float y, float z, float px, float py, float pz, float[] normal) {
  float magnitude = sqrt(sq(normal[0]) + sq(normal[1]) + sq(normal[2]));
  return magnitude > 0 ? ((x - px) * normal[0] + (y - py) * normal[1] + (z - pz) * normal[2]) / magnitude : Float.POSITIVE_INFINITY;
}

boolean dcrteSegmentTriangleIntersection(float sx, float sy, float sz, float ex, float ey, float ez,
    float[] triangle, float epsilon) {
  float dx = ex - sx; float dy = ey - sy; float dz = ez - sz;
  float edge1x = triangle[3] - triangle[0]; float edge1y = triangle[4] - triangle[1]; float edge1z = triangle[5] - triangle[2];
  float edge2x = triangle[6] - triangle[0]; float edge2y = triangle[7] - triangle[1]; float edge2z = triangle[8] - triangle[2];
  float hx = dy * edge2z - dz * edge2y; float hy = dz * edge2x - dx * edge2z; float hz = dx * edge2y - dy * edge2x;
  float determinant = edge1x * hx + edge1y * hy + edge1z * hz;
  if (abs(determinant) <= epsilon) return false;
  float inverse = 1.0f / determinant;
  float qx = sx - triangle[0]; float qy = sy - triangle[1]; float qz = sz - triangle[2];
  float u = inverse * (qx * hx + qy * hy + qz * hz);
  if (u < -epsilon || u > 1.0f + epsilon) return false;
  float rx = qy * edge1z - qz * edge1y; float ry = qz * edge1x - qx * edge1z; float rz = qx * edge1y - qy * edge1x;
  float v = inverse * (dx * rx + dy * ry + dz * rz);
  if (v < -epsilon || u + v > 1.0f + epsilon) return false;
  float t = inverse * (edge2x * rx + edge2y * ry + edge2z * rz);
  return t >= -epsilon && t <= 1.0f + epsilon;
}

boolean dcrteCoplanarTrianglesOverlap(float[] a, float[] b, float[] normal, float epsilon) {
  int drop = abs(normal[0]) >= abs(normal[1]) && abs(normal[0]) >= abs(normal[2]) ? 0
    : abs(normal[1]) >= abs(normal[2]) ? 1 : 2;
  float[] a2 = dcrteProjectTriangle2D(a, drop);
  float[] b2 = dcrteProjectTriangle2D(b, drop);
  for (int ea = 0; ea < 3; ea++) for (int eb = 0; eb < 3; eb++) {
    int na = (ea + 1) % 3; int nb = (eb + 1) % 3;
    if (dcrteSegmentsIntersect2D(a2[ea * 2], a2[ea * 2 + 1], a2[na * 2], a2[na * 2 + 1],
      b2[eb * 2], b2[eb * 2 + 1], b2[nb * 2], b2[nb * 2 + 1], epsilon)) return true;
  }
  return dcrtePointInTriangle2D(a2[0], a2[1], b2, epsilon) || dcrtePointInTriangle2D(b2[0], b2[1], a2, epsilon);
}

float[] dcrteProjectTriangle2D(float[] triangle, int drop) {
  float[] result = new float[6];
  for (int i = 0; i < 3; i++) {
    if (drop == 0) { result[i * 2] = triangle[i * 3 + 1]; result[i * 2 + 1] = triangle[i * 3 + 2]; }
    else if (drop == 1) { result[i * 2] = triangle[i * 3]; result[i * 2 + 1] = triangle[i * 3 + 2]; }
    else { result[i * 2] = triangle[i * 3]; result[i * 2 + 1] = triangle[i * 3 + 1]; }
  }
  return result;
}

float dcrteOrient2D(float ax, float ay, float bx, float by, float cx, float cy) {
  return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
}

boolean dcrteSegmentsIntersect2D(float ax, float ay, float bx, float by, float cx, float cy, float dx, float dy, float epsilon) {
  float o1 = dcrteOrient2D(ax, ay, bx, by, cx, cy);
  float o2 = dcrteOrient2D(ax, ay, bx, by, dx, dy);
  float o3 = dcrteOrient2D(cx, cy, dx, dy, ax, ay);
  float o4 = dcrteOrient2D(cx, cy, dx, dy, bx, by);
  return ((o1 > epsilon && o2 < -epsilon) || (o1 < -epsilon && o2 > epsilon))
    && ((o3 > epsilon && o4 < -epsilon) || (o3 < -epsilon && o4 > epsilon));
}

boolean dcrtePointInTriangle2D(float x, float y, float[] triangle, float epsilon) {
  float a = dcrteOrient2D(triangle[0], triangle[1], triangle[2], triangle[3], x, y);
  float b = dcrteOrient2D(triangle[2], triangle[3], triangle[4], triangle[5], x, y);
  float c = dcrteOrient2D(triangle[4], triangle[5], triangle[0], triangle[1], x, y);
  boolean negative = a < -epsilon || b < -epsilon || c < -epsilon;
  boolean positive = a > epsilon || b > epsilon || c > epsilon;
  return !(negative && positive);
}
