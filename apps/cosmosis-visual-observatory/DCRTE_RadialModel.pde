/* DCRTE-ET Milestone 3 approximate radial normalization model. */

enum DCRTERadialModel {
  EQUIVALENT_CIRCULAR,
  ELLIPTICAL;

  String id(){return name().toLowerCase();}
  String label(){return name().replace('_',' ');}
}

DCRTERadialModel dcrteIntrinsicRadialModel=DCRTERadialModel.EQUIVALENT_CIRCULAR;

void cycleDcrteIntrinsicRadialModel(){
  dcrteIntrinsicRadialModel=dcrteIntrinsicRadialModel==DCRTERadialModel.EQUIVALENT_CIRCULAR
    ? DCRTERadialModel.ELLIPTICAL:DCRTERadialModel.EQUIVALENT_CIRCULAR;
  invalidateDcrteIntrinsic("radial model changed");
  markDcrteImportedMaterialStale("radial model changed; rebuild intrinsic coordinates");
}

float dcrteEquivalentRadiusAt(CenterlineModel centerline,float segmentT,int segment,float epsilon){
  if(centerline==null||centerline.points==null||centerline.points.length==0)return epsilon;
  int a=constrain(segment,0,centerline.points.length-1),b=min(centerline.points.length-1,a+1);
  return max(epsilon,lerp(centerline.points[a].equivalentRadius,centerline.points[b].equivalentRadius,segmentT));
}
