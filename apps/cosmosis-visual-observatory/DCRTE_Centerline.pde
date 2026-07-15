/* DCRTE-ET Milestone 3 axial slices and deterministic centerline construction. */

class AxialSliceSample {
  int sliceIndex;
  float axialPosition;
  int insideVoxelCount;
  float weightSum;
  float centroidX, centroidY, centroidZ;
  float equivalentRadius;
  float maxRadialExtent;
  float covariance00, covariance01, covariance11;
  float majorRadius, minorRadius, crossSectionAngle;
  boolean valid;
  boolean interpolated;
  float confidence;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("slice_index", sliceIndex); json.setFloat("axial_position", axialPosition);
    json.setInt("inside_voxel_count", insideVoxelCount); json.setFloat("weight_sum", weightSum);
    JSONArray center = new JSONArray(); center.setFloat(0, centroidX); center.setFloat(1, centroidY); center.setFloat(2, centroidZ);
    json.setJSONArray("centroid", center);
    json.setFloat("equivalent_radius", equivalentRadius); json.setFloat("max_radial_extent", maxRadialExtent);
    json.setFloat("major_radius", majorRadius); json.setFloat("minor_radius", minorRadius);
    json.setFloat("cross_section_angle", crossSectionAngle);
    json.setBoolean("valid", valid); json.setBoolean("interpolated", interpolated); json.setFloat("confidence", confidence);
    return json;
  }
}

class AxialSliceSet {
  AxialSliceSample[] slices;
  float axialMin;
  float axialMax;
  int rawValidCount;
  int interpolatedCount;
  int firstValid = -1;
  int lastValid = -1;
  int maximumGap;
  float rawValidFraction;
  float validFraction;
  float coverage;
  float maximumGapFraction;
  boolean longGap;

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setInt("slice_count", slices == null ? 0 : slices.length);
    json.setFloat("axial_min", axialMin); json.setFloat("axial_max", axialMax);
    json.setInt("raw_valid_count", rawValidCount); json.setInt("interpolated_count", interpolatedCount);
    json.setFloat("raw_valid_fraction", rawValidFraction); json.setFloat("valid_fraction", validFraction); json.setFloat("coverage", coverage);
    json.setInt("maximum_gap_slices", maximumGap); json.setFloat("maximum_gap_fraction", maximumGapFraction);
    json.setBoolean("long_gap", longGap);
    return json;
  }
}

class DCRTEAxialSliceBuilder {
  int minimumSliceVoxelCount = 4;

  AxialSliceSet build(SignedDistanceVolume sdf, DominantInsideComponent component, PCAFrame pca, int sliceCount) {
    AxialSliceSet set = new AxialSliceSet();
    if (sdf == null || component == null || pca == null || !pca.valid || sliceCount < 2) return set;
    set.slices = new AxialSliceSample[sliceCount];
    for (int i = 0; i < sliceCount; i++) { set.slices[i] = new AxialSliceSample(); set.slices[i].sliceIndex = i; }
    float minAxial = Float.POSITIVE_INFINITY, maxAxial = Float.NEGATIVE_INFINITY;
    VolumeSpec spec = sdf.spec;
    for (int z = 0; z < spec.nz; z++) {
      float wz = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float wy = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        for (int x = 0; x < spec.nx; x++) {
          int idx = x + spec.nx * (y + spec.ny * z); if (!component.mask[idx]) continue;
          float wx = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          float axial = dcrteDot(wx-pca.centerX, wy-pca.centerY, wz-pca.centerZ, pca.axis1X, pca.axis1Y, pca.axis1Z);
          minAxial = min(minAxial, axial); maxAxial = max(maxAxial, axial);
        }
      }
    }
    if (!dcrteFinite(minAxial) || !dcrteFinite(maxAxial) || maxAxial <= minAxial) return set;
    set.axialMin = minAxial; set.axialMax = maxAxial;
    double[] wxSum = new double[sliceCount], wySum = new double[sliceCount], wzSum = new double[sliceCount], weights = new double[sliceCount];
    float minimumWeight = spec.minSpacing() * 0.25f;
    for (int z = 0; z < spec.nz; z++) {
      float wz = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float wy = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        for (int x = 0; x < spec.nx; x++) {
          int idx = x + spec.nx * (y + spec.ny * z); if (!component.mask[idx]) continue;
          float wx = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          float axial = dcrteDot(wx-pca.centerX, wy-pca.centerY, wz-pca.centerZ, pca.axis1X, pca.axis1Y, pca.axis1Z);
          int slice = constrain((int)floor((axial-minAxial) / max(0.0000001f, maxAxial-minAxial) * sliceCount), 0, sliceCount-1);
          float weight = max(minimumWeight, -sdf.signedDistance[idx]);
          AxialSliceSample sample = set.slices[slice]; sample.insideVoxelCount++; weights[slice] += weight;
          wxSum[slice] += weight * wx; wySum[slice] += weight * wy; wzSum[slice] += weight * wz;
        }
      }
    }
    for (int i = 0; i < sliceCount; i++) {
      AxialSliceSample sample = set.slices[i];
      sample.axialPosition = lerp(minAxial, maxAxial, (i + 0.5f) / sliceCount);
      sample.weightSum = (float)weights[i];
      if (weights[i] > 0) {
        sample.centroidX = (float)(wxSum[i]/weights[i]); sample.centroidY = (float)(wySum[i]/weights[i]); sample.centroidZ = (float)(wzSum[i]/weights[i]);
      }
      sample.equivalentRadius = sqrt(max(0, sample.insideVoxelCount * spec.minSpacing() * spec.minSpacing() / PI));
      sample.valid = sample.insideVoxelCount >= minimumSliceVoxelCount && weights[i] > 0;
      sample.confidence = constrain(sample.insideVoxelCount / 16.0f, 0, 1);
      if (sample.valid) { set.rawValidCount++; if (set.firstValid < 0) set.firstValid = i; set.lastValid = i; }
    }
    accumulateCrossSections(sdf, component, pca, set);
    set.rawValidFraction = set.rawValidCount / (float)sliceCount;
    set.coverage = set.firstValid < 0 ? 0 : (set.lastValid - set.firstValid + 1) / (float)sliceCount;
    interpolateShortGaps(set);
    int effectiveValidCount = 0;
    for (int i = 0; i < sliceCount; i++) if (set.slices[i].valid) effectiveValidCount++;
    set.validFraction = effectiveValidCount / (float)sliceCount;
    return set;
  }

  void accumulateCrossSections(SignedDistanceVolume sdf, DominantInsideComponent component, PCAFrame pca, AxialSliceSet set) {
    int count = set.slices.length; double[] c00 = new double[count], c01 = new double[count], c11 = new double[count];
    VolumeSpec spec = sdf.spec;
    for (int z=0; z<spec.nz; z++) { float wz=spec.bounds.minZ+(z+0.5f)*spec.spacingZ();
      for (int y=0; y<spec.ny; y++) { float wy=spec.bounds.minY+(y+0.5f)*spec.spacingY();
        for (int x=0; x<spec.nx; x++) { int idx=x+spec.nx*(y+spec.ny*z); if (!component.mask[idx]) continue;
          float wx=spec.bounds.minX+(x+0.5f)*spec.spacingX();
          float axial=dcrteDot(wx-pca.centerX,wy-pca.centerY,wz-pca.centerZ,pca.axis1X,pca.axis1Y,pca.axis1Z);
          int slice=constrain((int)floor((axial-set.axialMin)/max(0.0000001f,set.axialMax-set.axialMin)*count),0,count-1);
          AxialSliceSample s=set.slices[slice]; if (s.weightSum<=0) continue;
          float dx=wx-s.centroidX,dy=wy-s.centroidY,dz=wz-s.centroidZ;
          float u=dcrteDot(dx,dy,dz,pca.axis2X,pca.axis2Y,pca.axis2Z);
          float v=dcrteDot(dx,dy,dz,pca.axis3X,pca.axis3Y,pca.axis3Z);
          c00[slice]+=u*u; c01[slice]+=u*v; c11[slice]+=v*v; s.maxRadialExtent=max(s.maxRadialExtent,sqrt(u*u+v*v));
        }
      }
    }
    for (int i=0;i<count;i++) { AxialSliceSample s=set.slices[i]; if (s.insideVoxelCount<=0) continue;
      s.covariance00=(float)(c00[i]/s.insideVoxelCount); s.covariance01=(float)(c01[i]/s.insideVoxelCount); s.covariance11=(float)(c11[i]/s.insideVoxelCount);
      float trace=s.covariance00+s.covariance11; float disc=sqrt(max(0,(s.covariance00-s.covariance11)*(s.covariance00-s.covariance11)+4*s.covariance01*s.covariance01));
      s.majorRadius=sqrt(max(0,2*(trace+disc)*0.5f)); s.minorRadius=sqrt(max(0,2*(trace-disc)*0.5f));
      s.crossSectionAngle=0.5f*atan2(2*s.covariance01,s.covariance00-s.covariance11);
    }
  }

  void interpolateShortGaps(AxialSliceSet set) {
    if (set.slices == null || set.firstValid < 0) return;
    int allowed = max(2, round(0.04f * set.slices.length));
    int i = set.firstValid;
    while (i <= set.lastValid) {
      if (set.slices[i].valid) { i++; continue; }
      int start = i; while (i <= set.lastValid && !set.slices[i].valid) i++;
      int gap = i - start; set.maximumGap = max(set.maximumGap, gap);
      if (start > set.firstValid && i <= set.lastValid && gap <= allowed) {
        AxialSliceSample a=set.slices[start-1], b=set.slices[i];
        for (int g=0;g<gap;g++) { float t=(g+1)/(float)(gap+1); AxialSliceSample s=set.slices[start+g];
          s.centroidX=lerp(a.centroidX,b.centroidX,t); s.centroidY=lerp(a.centroidY,b.centroidY,t); s.centroidZ=lerp(a.centroidZ,b.centroidZ,t);
          s.equivalentRadius=lerp(a.equivalentRadius,b.equivalentRadius,t); s.majorRadius=lerp(a.majorRadius,b.majorRadius,t); s.minorRadius=lerp(a.minorRadius,b.minorRadius,t);
          s.valid=true; s.interpolated=true; s.confidence=0.55f; set.interpolatedCount++;
        }
      } else set.longGap = true;
    }
    set.maximumGapFraction = set.maximumGap / (float)set.slices.length;
  }
}

class CenterlinePoint {
  float x,y,z,arcLength,normalizedS,equivalentRadius,majorRadius,minorRadius;
  float tangentX,tangentY,tangentZ,confidence;
  boolean interpolated;

  JSONObject toJSON() {
    JSONObject json=new JSONObject(); json.setFloat("x",x); json.setFloat("y",y); json.setFloat("z",z);
    json.setFloat("arc_length",arcLength); json.setFloat("s",normalizedS); json.setFloat("equivalent_radius",equivalentRadius);
    json.setFloat("confidence",confidence); json.setBoolean("interpolated",interpolated); return json;
  }
}

class CenterlineModel {
  CenterlinePoint[] points;
  float length;
  float coverage;
  float maxStep;
  float minimumSdfMargin;
  float endpointInset;
  float originalStartX, originalStartY, originalStartZ;
  float originalEndX, originalEndY, originalEndZ;
  int smoothingPasses = 3;
  String smoothingMethod = "weighted_moving_average";
  boolean valid;
  boolean leavesDomain;
  boolean selfApproachSuspected;

  JSONObject toJSON() {
    JSONObject json=new JSONObject(); json.setInt("sample_count",points==null?0:points.length); json.setFloat("length",length);
    json.setFloat("coverage",coverage); json.setFloat("max_step",maxStep); json.setFloat("minimum_sdf_margin",minimumSdfMargin);
    json.setFloat("endpoint_inset",endpointInset); json.setString("smoothing_method",smoothingMethod); json.setInt("smoothing_passes",smoothingPasses);
    json.setBoolean("leaves_domain",leavesDomain); json.setBoolean("self_approach_suspected",selfApproachSuspected); json.setBoolean("valid",valid); return json;
  }
}

class DCRTECenterlineBuilder {
  CenterlineModel build(SignedDistanceVolume sdf, AxialSliceSet set) {
    CenterlineModel model=new CenterlineModel();
    if (sdf==null||set==null||set.slices==null||set.firstValid<0||set.longGap) return model;
    int n=set.lastValid-set.firstValid+1; if(n<4)return model;
    float[] x=new float[n],y=new float[n],z=new float[n],r=new float[n],major=new float[n],minor=new float[n],conf=new float[n]; boolean[] interp=new boolean[n];
    for(int i=0;i<n;i++){AxialSliceSample s=set.slices[set.firstValid+i];x[i]=s.centroidX;y[i]=s.centroidY;z[i]=s.centroidZ;r[i]=s.equivalentRadius;major[i]=max(s.majorRadius,r[i]);minor[i]=max(sdf.spec.minSpacing()*0.5f,s.minorRadius);conf[i]=s.confidence;interp[i]=s.interpolated;}
    model.originalStartX=x[0];model.originalStartY=y[0];model.originalStartZ=z[0];model.originalEndX=x[n-1];model.originalEndY=y[n-1];model.originalEndZ=z[n-1];
    float[] rawX=java.util.Arrays.copyOf(x,n),rawY=java.util.Arrays.copyOf(y,n),rawZ=java.util.Arrays.copyOf(z,n);
    for(int pass=0;pass<model.smoothingPasses;pass++) smooth(x,y,z);
    for(int i=0;i<n;i++) if(sdf.sampleWorld(x[i],y[i],z[i])>0){
      boolean restored=false; for(int attempt=1;attempt<=8;attempt++){float t=attempt/8.0f;float cx=lerp(x[i],rawX[i],t),cy=lerp(y[i],rawY[i],t),cz=lerp(z[i],rawZ[i],t);
        if(sdf.sampleWorld(cx,cy,cz)<=0){x[i]=cx;y[i]=cy;z[i]=cz;conf[i]*=0.65f;restored=true;break;}}
      if(!restored){model.leavesDomain=true;return model;}
    }
    float[] cumulative=new float[n];for(int i=1;i<n;i++)cumulative[i]=cumulative[i-1]+dcrteMagnitude(x[i]-x[i-1],y[i]-y[i-1],z[i]-z[i-1]);
    float fullLength=cumulative[n-1];if(!dcrteFinite(fullLength)||fullLength<=0)return model;
    model.endpointInset=min(1.5f*sdf.spec.minSpacing(),fullLength*0.18f);float startArc=model.endpointInset,endArc=fullLength-model.endpointInset;if(endArc<=startArc){startArc=0;endArc=fullLength;model.endpointInset=0;}
    int outputCount=max(32,set.slices.length);model.points=new CenterlinePoint[outputCount];
    for(int i=0;i<outputCount;i++){float target=lerp(startArc,endArc,i/(float)(outputCount-1));int seg=0;while(seg+1<n&&cumulative[seg+1]<target)seg++;int next=min(n-1,seg+1);float denom=max(0.0000001f,cumulative[next]-cumulative[seg]);float t=constrain((target-cumulative[seg])/denom,0,1);CenterlinePoint p=new CenterlinePoint();
      p.x=lerp(x[seg],x[next],t);p.y=lerp(y[seg],y[next],t);p.z=lerp(z[seg],z[next],t);p.arcLength=target-startArc;p.equivalentRadius=max(sdf.spec.minSpacing()*0.5f,lerp(r[seg],r[next],t));p.majorRadius=max(p.equivalentRadius,lerp(major[seg],major[next],t));p.minorRadius=max(sdf.spec.minSpacing()*0.5f,lerp(minor[seg],minor[next],t));p.confidence=lerp(conf[seg],conf[next],t);p.interpolated=interp[seg]||interp[next];model.points[i]=p;}
    model.length=max(0,endArc-startArc);model.coverage=set.coverage;model.minimumSdfMargin=Float.POSITIVE_INFINITY;
    for(int i=0;i<outputCount;i++){CenterlinePoint p=model.points[i];p.normalizedS=outputCount==1?0:i/(float)(outputCount-1);int a=max(0,i-1),b=min(outputCount-1,i+1);float[] tangent={model.points[b].x-model.points[a].x,model.points[b].y-model.points[a].y,model.points[b].z-model.points[a].z};dcrteNormalizeInPlace(tangent);p.tangentX=tangent[0];p.tangentY=tangent[1];p.tangentZ=tangent[2];float d=sdf.sampleWorld(p.x,p.y,p.z);model.minimumSdfMargin=min(model.minimumSdfMargin,-d);if(i>0)model.maxStep=max(model.maxStep,dcrteMagnitude(p.x-model.points[i-1].x,p.y-model.points[i-1].y,p.z-model.points[i-1].z));}
    model.selfApproachSuspected=detectSelfApproach(model,sdf.spec.minSpacing());model.valid=!model.leavesDomain&&!model.selfApproachSuspected&&model.length>0&&model.minimumSdfMargin>=-0.25f*sdf.spec.minSpacing();return model;
  }
  void smooth(float[] x,float[] y,float[] z){float[] nx=java.util.Arrays.copyOf(x,x.length),ny=java.util.Arrays.copyOf(y,y.length),nz=java.util.Arrays.copyOf(z,z.length);for(int i=1;i<x.length-1;i++){nx[i]=(x[i-1]+2*x[i]+x[i+1])*0.25f;ny[i]=(y[i-1]+2*y[i]+y[i+1])*0.25f;nz[i]=(z[i-1]+2*z[i]+z[i+1])*0.25f;}System.arraycopy(nx,0,x,0,x.length);System.arraycopy(ny,0,y,0,y.length);System.arraycopy(nz,0,z,0,z.length);}
  boolean detectSelfApproach(CenterlineModel model, float spacing) {
    if (model.points == null || model.points.length < 8) return false;
    for (int i = 0; i < model.points.length; i++) {
      CenterlinePoint a = model.points[i];
      for (int j = i + 1; j < model.points.length; j++) {
        CenterlinePoint b = model.points[j];
        float arcSeparation = abs(b.arcLength - a.arcLength);
        float localRadius = max(spacing, min(a.equivalentRadius, b.equivalentRadius));

        // Nearby samples on one thick centerline are expected to be close in space.
        // A loop risk must be nonlocal along the curve and form a real shortcut.
        if (arcSeparation <= max(spacing * 6.0f, localRadius * 1.75f)) continue;
        float spatialSeparation = dcrteMagnitude(a.x-b.x, a.y-b.y, a.z-b.z);
        float proximityThreshold = max(spacing * 2.0f, localRadius * 0.45f);
        float shortcutRatio = spatialSeparation / max(spacing, arcSeparation);
        if (spatialSeparation < proximityThreshold && shortcutRatio < 0.42f) return true;
      }
    }
    return false;
  }
}

void dcrteResolvePcaSign(PCAFrame pca, AxialSliceSet slices) {
  if(pca==null||slices==null||slices.slices==null||slices.firstValid<0)return;
  int band=max(2,slices.slices.length/10);float first=0,last=0;int fc=0,lc=0;
  for(int i=slices.firstValid;i<=min(slices.lastValid,slices.firstValid+band-1);i++)if(slices.slices[i].valid){first+=slices.slices[i].equivalentRadius;fc++;}
  for(int i=max(slices.firstValid,slices.lastValid-band+1);i<=slices.lastValid;i++)if(slices.slices[i].valid){last+=slices.slices[i].equivalentRadius;lc++;}
  first=fc==0?0:first/fc;last=lc==0?0:last/lc;boolean flip=false;float tolerance=0.04f*max(first,last);
  if(first>last+tolerance){flip=true;pca.signPolicy="smaller_end_radius_is_s_zero";}else if(last>first+tolerance){pca.signPolicy="smaller_end_radius_is_s_zero";}else{float ax=abs(pca.axis1X),ay=abs(pca.axis1Y),az=abs(pca.axis1Z);float dominant=ax>=ay&&ax>=az?pca.axis1X:ay>=az?pca.axis1Y:pca.axis1Z;flip=dominant<0;pca.signPolicy="positive_dominant_world_axis";}
  if(flip){pca.flipLongitudinal();float swap=first;first=last;last=swap;}
  pca.narrowEndRadius=first;pca.broadEndRadius=last;
}
