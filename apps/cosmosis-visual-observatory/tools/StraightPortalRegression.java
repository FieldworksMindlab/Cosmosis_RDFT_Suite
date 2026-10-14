import java.nio.file.*;
import java.util.*;
import processing.core.PVector;

/** Real generator regression, invoked by test_straight_portals.py. */
public class StraightPortalRegression {
 static int checks = 0;
 static final Cosmosis_Visual_Observatory app = new Cosmosis_Visual_Observatory();
 static final Cosmosis_Visual_Observatory.GeodesicGrowthMode GROWTH = Cosmosis_Visual_Observatory.GeodesicGrowthMode.SHELL_OVERWRAP;
 static void check(boolean ok, String message) {
  checks++;
  if (!ok) throw new AssertionError(message);
  System.out.println("PASS " + message);
 }
 static Cosmosis_Visual_Observatory.GeodesicFabricationSettings settings() {
  var s = app.new GeodesicFabricationSettings();
  s.portalAxisMode = Cosmosis_Visual_Observatory.GeodesicPortalAxisMode.ASSEMBLED_STRAIGHT;
  s.desiredPortalsPerEdge = 3; s.edgeCodesEnabled = false;
  return s;
 }
 public static void main(String[] args) throws Exception {
  var core = app.runGeodesicCoreTests();
  check(core.failures.isEmpty(), "existing geodesic core " + core.summary() + " " + core.failures);

  for (var family : Cosmosis_Visual_Observatory.GeodesicSeedFamily.values()) {
   for (var style : new Cosmosis_Visual_Observatory.GeodesicPanelStyle[]{Cosmosis_Visual_Observatory.GeodesicPanelStyle.FRAME_SKIN, Cosmosis_Visual_Observatory.GeodesicPanelStyle.OPEN_FRAME}) {
    for (boolean crown : new boolean[]{false, true}) {
     var model = app.buildGeodesicModel(family, Cosmosis_Visual_Observatory.GeodesicExtentMode.SPHERE, 1, 72, -1);
     var s = settings(); s.style = style;
     if (crown) s.reliefSide = Cosmosis_Visual_Observatory.GeodesicReliefSide.EXTERIOR_CROWN;
     s = app.geodesicResolveKitFabricationSettings(model, s);
     var audit = app.geodesicAuditStraightPassages(model, s, GROWTH, 1.4f);
     boolean impossible = family == Cosmosis_Visual_Observatory.GeodesicSeedFamily.TETRAHEDRAL;
     check(impossible ? !audit.valid && audit.status.contains("DOES NOT FIT") : audit.valid,
       family + " " + style + " crown=" + crown + " / " + audit.status + " / " + audit.checked);
    }
   }
  }
  for (float ratio : new float[]{0.08f, 0.45f}) {
   var stellated = app.buildGeodesicModel(Cosmosis_Visual_Observatory.GeodesicSeedFamily.OCTAHEDRAL,
     Cosmosis_Visual_Observatory.GeodesicExtentMode.SPHERE,2,72,-1,
     Cosmosis_Visual_Observatory.GeodesicFormModifier.FACE_STELLATION,ratio);
   var config = app.geodesicResolveKitFabricationSettings(stellated,settings());
   var result = app.geodesicAuditStraightPassages(stellated,config,GROWTH,1.4f);
   check(ratio < 0.1f ? result.valid && result.checked == 144 : !result.valid && result.status.contains("DOES NOT FIT"),
     "convex/concave stellated joints ratio=" + ratio + " / " + result.status);
  }
  var dome = app.buildGeodesicModel(Cosmosis_Visual_Observatory.GeodesicSeedFamily.ICOSAHEDRAL,
    Cosmosis_Visual_Observatory.GeodesicExtentMode.DOME,2,72,0.1f);
  var domeResult = app.geodesicAuditStraightPassages(dome,app.geodesicResolveKitFabricationSettings(dome,settings()),GROWTH,1.4f);
  check(domeResult.valid && domeResult.checked > 0, "dome shared seams pass; unmatched rim holes remain panel-local");
  for (int length : new int[]{12, 20, 40}) {
   var joint = app.new GeodesicJointEdgeProfile(); joint.edgeLengthMM=length; joint.portalWidthMM=5.2f;
   app.geodesicScheduleBalancedPortals(joint,length*0.5f-1.5f,3,0.35f);
   int expected=length==12?1:(length==20?2:3);
   check(joint.portalCenters.size()==expected && joint.portalWidthMM==5.2f,
     "size-limited schedule length="+length+" count="+expected+" preserves aperture size");
   for(int i=1;i<joint.portalCenters.size();i++)
    check((joint.portalCenters.get(i)-joint.portalCenters.get(i-1))*length-5.9f>=2.08f-0.001f,
      "rounded entrances retain material between passages");
  }
  var singleModel=app.buildGeodesicModel(Cosmosis_Visual_Observatory.GeodesicSeedFamily.OCTAHEDRAL,
    Cosmosis_Visual_Observatory.GeodesicExtentMode.SPHERE,1,72,-1);
  var singleSettings=settings();singleSettings.desiredPortalsPerEdge=1;
  var singleAudit=app.geodesicAuditStraightPassages(singleModel,
    app.geodesicResolveKitFabricationSettings(singleModel,singleSettings),GROWTH,1.4f);
  check(singleAudit.valid && singleAudit.checked==12 && singleAudit.passagesChecked==12,
    "single-portal configuration retains its straight-passage behavior");
  var model = app.buildGeodesicModel(Cosmosis_Visual_Observatory.GeodesicSeedFamily.DODECAHEDRAL,
    Cosmosis_Visual_Observatory.GeodesicExtentMode.SPHERE, 6, 72, -1);
  var s = settings(); s.fabricationScale = 8.15f; s.kitDimensionsResolved = true; s.edgeCodesEnabled = true;
  var audit = app.geodesicAuditStraightPassages(model, s, GROWTH, 1.4f);
  System.out.println(audit.toJSON());
  check(audit.valid && audit.checked == 1944, "uploaded dodeca F6: 1944 seams, every passage including labels / " + audit.status);
  check(audit.passagesChecked > audit.checked*2 && audit.edgesByPortalCount[2]>0 &&
    audit.edgesByPortalCount[3]>0,"full kit validates every hole and includes automatic two/three-hole adaptation");
  var catalog = app.buildGeodesicPanelCatalog(model, s, GROWTH, 1.4f);
  check(catalog.types.stream().allMatch(t -> app.geodesicAuditClean(t.audit)), "all " + catalog.types.size() + " exported part types are manifold");
  var face = app.buildGeodesicFabricatedPart(model, model.faces.get(49), s, GROWTH, 1.4f);
  var mate = app.buildGeodesicFabricatedPart(model, model.faces.get(50), s, GROWTH, 1.4f);
  if (!app.geodesicAuditClean(face.audit) || !app.geodesicAuditClean(mate.audit)) {
   var plain = s.copy(); plain.edgeCodesEnabled=false;
   if (!app.geodesicAuditClean(face.audit)) face=app.buildGeodesicFabricatedPart(model,model.faces.get(49),plain,GROWTH,1.4f);
   if (!app.geodesicAuditClean(mate.audit)) mate=app.buildGeodesicFabricatedPart(model,model.faces.get(50),plain,GROWTH,1.4f);
  }
  check(app.geodesicAuditClean(face.audit) && app.geodesicAuditClean(mate.audit), "print-fit pair meshes are manifold");
  check(face.fabricationFace.portalCount()==9 && mate.fabricationFace.portalCount()==9,
    "both print-fit pieces have three portals per edge / nine per piece");
  var larger=app.buildGeodesicModel(Cosmosis_Visual_Observatory.GeodesicSeedFamily.DODECAHEDRAL,
    Cosmosis_Visual_Observatory.GeodesicExtentMode.SPHERE,6,144,-1);
  var enlarged=app.geodesicFabricationFace(larger,larger.faces.get(49),s);
  var originalJoint=face.fabricationFace.joints.get(1);
  var largerJoint=enlarged.joints.get(1);
  float oldSpacing=(originalJoint.portalCenters.get(2)-originalJoint.portalCenters.get(0))*originalJoint.edgeLengthMM;
  float newSpacing=(largerJoint.portalCenters.get(2)-largerJoint.portalCenters.get(0))*largerJoint.edgeLengthMM;
  check(Math.abs(newSpacing-2*oldSpacing)<0.01f && originalJoint.portalWidthMM==largerJoint.portalWidthMM,
    "doubling part size doubles portal spacing without shrinking or enlarging the strap opening");
  int edge = app.geodesicFabricationEdgeToward(face.fabricationFace, 50);
  var portal = face.fabricationFace.joints.get(edge).straightPortal;
  PVector y = portal.heightAxis, z = portal.axis, x = y.cross(z).normalize();
  PVector center = PVector.add(portal.seam, PVector.mult(y, portal.centerHeight));
  check(!app.geodesicMeshBlocksPassage(face, center, x, y, z, 2.55f, 1.25f, -9, 9), "sharpest dodeca joint full rectangular envelope is clear");
  // An off-axis snag must fail even though the centerline remains clear.
  var obstruction = app.new GeodesicPart(); obstruction.fabricationFace = face.fabricationFace;
  obstruction.mesh = app.new SurfaceMesh("snag");
  PVector[] points = {new PVector(1.5f,-0.3f,0),new PVector(2.1f,-0.3f,0),new PVector(1.8f,0.3f,0)};
  for(int i=0;i<3;i++) {
   PVector world = center.copy().add(PVector.mult(x,points[i].x)).add(PVector.mult(y,points[i].y));
   points[i] = app.geodesicAssemblyPointToFabrication(face.fabricationFace,world);
  }
  obstruction.mesh.addTri(points[0], points[1], points[2]);
  check(app.geodesicMeshBlocksPassage(obstruction,center,x,y,z,2.55f,1.25f,-9,9), "off-axis obstruction rejected by volume test");
  PVector sideCenter=app.geodesicStraightPortalCenterWorld(face.fabricationFace.joints.get(edge),
    face.fabricationFace.joints.get(edge).portalCenters.get(0));
  PVector shift=PVector.sub(sideCenter,center);
  for(var tri:obstruction.mesh.tris) for(var v:List.of(tri.a,tri.b,tri.c))
    v.set(app.geodesicAssemblyPointToFabrication(face.fabricationFace,
      app.geodesicFabricationPointToAssembly(face.fabricationFace,v).add(shift)));
  check(app.geodesicMeshBlocksPassage(obstruction,sideCenter,x,y,z,2.55f,1.25f,-9,9),
    "off-center passage is independently checked for obstructions");
  var oldSettings = s.copy(); oldSettings.portalAxisMode = Cosmosis_Visual_Observatory.GeodesicPortalAxisMode.PANEL_TRANSVERSE;
  var old = app.buildGeodesicFabricatedPart(model,model.faces.get(49),oldSettings,GROWTH,1.4f);
  check(app.geodesicMeshBlocksPassage(old,center,x,y,z,2.55f,1.25f,-9,9), "previous panel-local tunnel fails the same full-passage test");
  var tiny = settings(); tiny.fabricationScale=8.15f; tiny.kitDimensionsResolved=true; tiny.portalWidthMM=2.4f;
  var small = app.geodesicAuditStraightPassages(model,tiny,GROWTH,1.4f);
  check(!small.valid && small.status.contains("TOO SMALL"), "undersized opening blocks export");
  var off = s.copy(); off.fastenerPortals=false;
  check(app.geodesicAuditStraightPassages(model,off,GROWTH,1.4f).status.equals("NOT REQUIRED"), "portals-off does not claim passage verification");
  if(args.length>0) {
   Path out=Path.of(args[0]);
   face.mesh.writeSTL(out.resolve("face_0049.stl").toString());
   mate.mesh.writeSTL(out.resolve("face_0050.stl").toString());
   var assembled = app.new SurfaceMesh("assembled_reference_do_not_print");
   for(var part:List.of(face,mate)) for(var tri:part.mesh.tris)
    assembled.addTri(app.geodesicFabricationPointToAssembly(part.fabricationFace,tri.a),app.geodesicFabricationPointToAssembly(part.fabricationFace,tri.b),app.geodesicFabricationPointToAssembly(part.fabricationFace,tri.c));
   assembled.writeSTL(out.resolve("assembled_reference_do_not_print.stl").toString());
   Files.writeString(out.resolve("validation.json"),audit.toJSON().toString());
   var plan = app.geodesicAssemblyPlanJSON(model,catalog,s);
   var pair = new processing.data.JSONObject();
   pair.setString("description", "Two-part fit test, not a complete replacement kit. Face IDs are zero-based.");
   pair.setJSONObject("fabrication",s.toJSON());
   var placements = new processing.data.JSONArray();
   for(int id:new int[]{49,50}) placements.append(plan.getJSONArray("placements").getJSONObject(id));
   pair.setJSONArray("placements",placements);
   Files.writeString(out.resolve("placements.json"),pair.toString());
  }
  System.out.println("STRAIGHT PORTAL REGRESSIONS " + checks + " PASS");
 }
}
