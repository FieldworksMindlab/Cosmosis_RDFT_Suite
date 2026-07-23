/* DCRTE-ET Milestone 3 flat intrinsic-coordinate volume and build pipeline. */

class IntrinsicCoordinateVolume {
  VolumeSpec spec;
  float[] s,radialDistance,normalizedRadius,theta,signedBoundaryDistance,confidence;
  int[] centerlineIndex;
  boolean[] valid,ambiguous,fallbackUsed;
  int validCount,ambiguousCount,fallbackCount,nonFiniteCount,poleClampedCount;

  IntrinsicCoordinateVolume(VolumeSpec spec){this.spec=spec;int n=spec==null?0:max(0,spec.voxelCount());s=new float[n];radialDistance=new float[n];normalizedRadius=new float[n];theta=new float[n];signedBoundaryDistance=new float[n];confidence=new float[n];centerlineIndex=new int[n];valid=new boolean[n];ambiguous=new boolean[n];fallbackUsed=new boolean[n];java.util.Arrays.fill(centerlineIndex,-1);}
  int index(int x,int y,int z){return x+spec.nx*(y+spec.ny*z);}
  boolean isValid(){
    int count=spec==null?-1:spec.voxelCount();
    return spec!=null&&spec.isValid()&&count>0
      &&s!=null&&s.length==count&&radialDistance!=null&&radialDistance.length==count
      &&normalizedRadius!=null&&normalizedRadius.length==count&&theta!=null&&theta.length==count
      &&signedBoundaryDistance!=null&&signedBoundaryDistance.length==count
      &&confidence!=null&&confidence.length==count&&centerlineIndex!=null&&centerlineIndex.length==count
      &&valid!=null&&valid.length==count&&ambiguous!=null&&ambiguous.length==count
      &&fallbackUsed!=null&&fallbackUsed.length==count&&nonFiniteCount==0&&validCount>0;
  }
  JSONObject toJSON(){JSONObject json=new JSONObject();json.setJSONObject("spec",spec==null?new JSONObject():spec.toJSON());json.setInt("valid_voxels",validCount);json.setInt("ambiguous_voxels",ambiguousCount);json.setInt("fallback_voxels",fallbackCount);json.setInt("nonfinite_voxels",nonFiniteCount);json.setInt("pole_clamped_voxels",poleClampedCount);json.setBoolean("valid",isValid());json.setString("storage","flat_primitive_arrays");return json;}
}

class IntrinsicBuildResult {
  String sourceDomainSignature="";
  DominantInsideComponent component;
  PCAFrame pca;
  AxialSliceSet slices;
  CenterlineModel centerline;
  TransportFrameField frames;
  IntrinsicCoordinateVolume volume;
  IntrinsicValidationReport validation;
  String radialModel="equivalent_circular";
  JSONObject toJSON(){JSONObject json=new JSONObject();json.setString("coordinate_system","intrinsic_axial");json.setString("version","1.0-m3");json.setString("mapping","INTRINSIC_CYLINDRICAL_EMBEDDING");json.setString("radial_model",radialModel);json.setString("source_domain_signature",sourceDomainSignature==null?"":sourceDomainSignature);if(component!=null)json.setJSONObject("dominant_component",component.toJSON());if(pca!=null)json.setJSONObject("pca",pca.toJSON());if(slices!=null)json.setJSONObject("axial_slices",slices.toJSON());if(centerline!=null)json.setJSONObject("centerline",centerline.toJSON());if(frames!=null)json.setJSONObject("frames",frames.toJSON());if(volume!=null)json.setJSONObject("intrinsic_volume",volume.toJSON());if(validation!=null)json.setJSONObject("validation",validation.toJSON());return json;}
}

class DCRTEIntrinsicCoordinateBuilder {
  IntrinsicBuildResult build(SignedDistanceVolume sdf,DomainPreflightReport preflight,boolean allowSyntheticQualified){
    long totalStart=millis();IntrinsicBuildResult result=new IntrinsicBuildResult();IntrinsicValidationReport validation=new IntrinsicValidationReport();IntrinsicSuitabilityReport suitability=new IntrinsicSuitabilityReport();validation.suitability=suitability;result.validation=validation;result.radialModel=dcrteIntrinsicRadialModel.id();
    boolean preflightQualified=allowSyntheticQualified||(preflight!=null&&!preflight.reportStale&&preflight.materializationEnabled&&preflight.status!=ValidationStatus.FAIL);
    if(!preflightQualified){suitability.block(DCRTEIntrinsicCodes.IC_DOMAIN_NOT_PREFLIGHT_QUALIFIED);validation.error(DCRTEIntrinsicCodes.IC_DOMAIN_NOT_PREFLIGHT_QUALIFIED);finish(result,totalStart);return result;}
    if(sdf==null||!sdf.isValid()||sdf.inside==null){suitability.block(DCRTEIntrinsicCodes.IC_INSIDE_MASK_EMPTY);validation.error(DCRTEIntrinsicCodes.IC_INSIDE_MASK_EMPTY);finish(result,totalStart);return result;}
    long phase=millis();DominantInsideComponent component=new DCRTEDominantComponentSelector().select(sdf);result.component=component;
    if(component==null||!component.valid){suitability.block(DCRTEIntrinsicCodes.IC_INSIDE_MASK_EMPTY);validation.error(DCRTEIntrinsicCodes.IC_INSIDE_MASK_EMPTY);finish(result,totalStart);return result;}
    validation.totalInsideVoxels=component.totalInsideCount;suitability.insideComponentCount=component.componentCount;suitability.dominantComponentFraction=component.dominantFraction;suitability.singleDominantComponent=component.dominantFraction>=0.98f;
    if(component.dominantFraction<0.98f){suitability.block(DCRTEIntrinsicCodes.IC_MULTIPLE_DOMINANT_COMPONENTS);validation.error(DCRTEIntrinsicCodes.IC_MULTIPLE_DOMINANT_COMPONENTS);finish(result,totalStart);return result;}
    PCAFrame pca=new DCRTEWeightedPCA().compute(sdf,component,DCRTEPCAWeightingMode.DISTANCE_WEIGHTED);validation.pcaMillis=millis()-phase;result.pca=pca;
    if(pca==null||!pca.valid){suitability.block(DCRTEIntrinsicCodes.IC_AXIS_UNDEFINED);validation.error(DCRTEIntrinsicCodes.IC_AXIS_UNDEFINED);finish(result,totalStart);return result;}
    suitability.principalEigenvalue1=pca.eigenvalue1;suitability.principalEigenvalue2=pca.eigenvalue2;suitability.principalEigenvalue3=pca.eigenvalue3;suitability.elongationRatio12=pca.eigenvalue1/max(0.0000001f,pca.eigenvalue2);suitability.elongationRatio13=pca.eigenvalue1/max(0.0000001f,pca.eigenvalue3);if(suitability.elongationRatio12<1.25f)suitability.warn(DCRTEIntrinsicCodes.IC_LOW_ELONGATION);
    phase=millis();int sliceCount=max(32,sdf.spec.nx);DCRTEAxialSliceBuilder sliceBuilder=new DCRTEAxialSliceBuilder();AxialSliceSet slices=sliceBuilder.build(sdf,component,pca,sliceCount);
    if(slices==null){suitability.block(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);validation.error(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);finish(result,totalStart);return result;}
    dcrteResolvePcaSign(pca,slices);slices=sliceBuilder.build(sdf,component,pca,sliceCount);result.slices=slices;validation.sliceMillis=millis()-phase;
    if(slices==null||slices.slices==null){suitability.block(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);validation.error(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);finish(result,totalStart);return result;}
    suitability.validSliceFraction=slices.validFraction;suitability.centerlineCoverage=slices.coverage;suitability.maximumSliceGapFraction=slices.maximumGapFraction;
    if(slices.validFraction<0.85f||slices.coverage<0.90f){suitability.block(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);validation.error(DCRTEIntrinsicCodes.IC_CENTERLINE_COVERAGE_LOW);finish(result,totalStart);return result;}
    if(slices.longGap||slices.maximumGapFraction>0.08f){suitability.block(DCRTEIntrinsicCodes.IC_CENTERLINE_DISCONTINUOUS);validation.error(DCRTEIntrinsicCodes.IC_CENTERLINE_DISCONTINUOUS);finish(result,totalStart);return result;}
    int dispersedSlices=0, evaluatedSlices=0;for(int i=slices.firstValid;i<=slices.lastValid&&i>=0;i++){AxialSliceSample slice=slices.slices[i];if(!slice.valid)continue;evaluatedSlices++;float spread=slice.maxRadialExtent/max(sdf.spec.minSpacing(),slice.equivalentRadius);if(spread>1.62f)dispersedSlices++;}
    float dispersedFraction=evaluatedSlices==0?0:dispersedSlices/(float)evaluatedSlices;if(dispersedFraction>0.18f&&suitability.elongationRatio12>=1.25f){suitability.branchingSuspected=true;suitability.block(DCRTEIntrinsicCodes.IC_BRANCHING_SUSPECTED);validation.error(DCRTEIntrinsicCodes.IC_BRANCHING_SUSPECTED);finish(result,totalStart);return result;}
    phase=millis();CenterlineModel centerline=new DCRTECenterlineBuilder().build(sdf,slices);validation.centerlineMillis=millis()-phase;result.centerline=centerline;
    if(centerline==null||!centerline.valid){boolean loop=suitability.elongationRatio12<1.35f||centerline!=null&&centerline.selfApproachSuspected;suitability.closedLoopSuspected=loop;suitability.branchingSuspected=!loop;String code=loop?DCRTEIntrinsicCodes.IC_CLOSED_LOOP_SUSPECTED:DCRTEIntrinsicCodes.IC_BRANCHING_SUSPECTED;suitability.block(code);validation.error(code);finish(result,totalStart);return result;}
    suitability.centerlineSelfApproachRisk=centerline.selfApproachSuspected?1:0;validation.centerlineLength=centerline.length;validation.centerlineCoverage=centerline.coverage;validation.maxCenterlineStep=centerline.maxStep;validation.minimumCenterlineSDFMargin=centerline.minimumSdfMargin;
    phase=millis();TransportFrameField frames=new DCRTEParallelTransportBuilder().build(centerline,pca);validation.frameMillis=millis()-phase;result.frames=frames;
    if(frames==null||!frames.valid){suitability.block(DCRTEIntrinsicCodes.IC_FRAME_BUILD_FAILED);validation.error(DCRTEIntrinsicCodes.IC_FRAME_BUILD_FAILED);finish(result,totalStart);return result;}
    suitability.frameContinuityScore=frames.continuityScore;
    if(frames.elevatedRotationCount>max(2,frames.frames.length/10))suitability.warn(DCRTEIntrinsicCodes.IC_FRAME_TWIST_ELEVATED);
    validation.meanFrameRotation=frames.meanRotation;validation.maxFrameRotation=frames.maxRotation;validation.frameDiscontinuityCount=frames.discontinuityCount;
    phase=millis();IntrinsicCoordinateVolume volume=mapVolume(sdf,component,pca,slices,centerline,frames,validation);validation.mappingMillis=millis()-phase;result.volume=volume;
    if(volume==null){suitability.block(DCRTEIntrinsicCodes.IC_MAPPING_FAILED);validation.error(DCRTEIntrinsicCodes.IC_MAPPING_FAILED);finish(result,totalStart);return result;}
    validation.validIntrinsicVoxels=volume.validCount;validation.ambiguousVoxels=volume.ambiguousCount;validation.fallbackVoxels=volume.fallbackCount;validation.nonFiniteVoxels=volume.nonFiniteCount;validation.poleClampedVoxels=volume.poleClampedCount;validation.validFraction=component.dominantCount==0?0:volume.validCount/(float)component.dominantCount;validation.ambiguityFraction=component.dominantCount==0?0:volume.ambiguousCount/(float)component.dominantCount;validation.fallbackFraction=component.dominantCount==0?0:volume.fallbackCount/(float)component.dominantCount;suitability.nearestPointAmbiguityFraction=validation.ambiguityFraction;suitability.radialNormalizationConfidence=0.82f;
    computeConfidenceStats(volume,validation);
    suitability.warn(DCRTEIntrinsicCodes.IC_RADIAL_NORMALIZATION_APPROXIMATE);
    if(preflight!=null&&preflight.thinFeatureRisk)suitability.warn(DCRTEIntrinsicCodes.IC_THIN_FEATURE_RISK);
    if(validation.ambiguityFraction>0.05f){suitability.block(DCRTEIntrinsicCodes.IC_MAPPING_AMBIGUITY_HIGH);validation.error(DCRTEIntrinsicCodes.IC_MAPPING_AMBIGUITY_HIGH);}else if(validation.ambiguityFraction>0.01f)suitability.warn(DCRTEIntrinsicCodes.IC_NEAREST_CENTERLINE_AMBIGUOUS);
    if(volume.nonFiniteCount>0){suitability.block(DCRTEIntrinsicCodes.IC_NONFINITE_COORDINATES);validation.error(DCRTEIntrinsicCodes.IC_NONFINITE_COORDINATES);}
    if(validation.fallbackFraction>0.01f)validation.error(DCRTEIntrinsicCodes.IC_FALLBACK_FRACTION_HIGH);
    suitability.finalizeStatus();for(String warning:suitability.warnings)validation.warn(warning);validation.finalizeStatus();finish(result,totalStart);return result;
  }

  IntrinsicCoordinateVolume mapVolume(SignedDistanceVolume sdf, DominantInsideComponent component,
      PCAFrame pca, AxialSliceSet slices, CenterlineModel centerline,
      TransportFrameField frames, IntrinsicValidationReport validation) {
    IntrinsicCoordinateVolume volume = new IntrinsicCoordinateVolume(sdf.spec);
    VolumeSpec spec = sdf.spec;
    int segmentCount = centerline.points.length - 1;
    int localNeighborThreshold = max(6, round(0.10f * segmentCount));
    float radialEpsilon = 0.35f * spec.minSpacing();
    float radiusEpsilon = 0.50f * spec.minSpacing();
    float ambiguityTolerance = 0.55f * spec.minSpacing();
    float resolutionConfidence = 1.0f;
    if (sdf.quality != null) {
      resolutionConfidence = sdf.quality.resolutionX >= 128 ? 0.95f
        : sdf.quality.resolutionX >= 64 ? 0.88f : 0.72f;
    }

    for (int z = 0; z < spec.nz; z++) {
      float wz = spec.bounds.minZ + (z + 0.5f) * spec.spacingZ();
      for (int y = 0; y < spec.ny; y++) {
        float wy = spec.bounds.minY + (y + 0.5f) * spec.spacingY();
        for (int x = 0; x < spec.nx; x++) {
          int idx = x + spec.nx * (y + spec.ny * z);
          if (!component.mask[idx]) continue;
          float wx = spec.bounds.minX + (x + 0.5f) * spec.spacingX();
          float axial = dcrteDot(wx-pca.centerX, wy-pca.centerY, wz-pca.centerZ,
            pca.axis1X, pca.axis1Y, pca.axis1Z);
          float normalizedAxial = constrain((axial-slices.axialMin)
            / max(0.0000001f, slices.axialMax-slices.axialMin), 0, 1);
          int estimate = constrain(round(normalizedAxial * segmentCount), 0, segmentCount-1);
          int searchRadius = 6;
          int searchStart = 0, searchEnd = segmentCount - 1;
          float best = Float.POSITIVE_INFINITY;
          float bestT = 0;
          int bestSegment = -1;

          for (int pass = 0; pass < 2; pass++) {
            searchStart = max(0, estimate-searchRadius);
            searchEnd = min(segmentCount-1, estimate+searchRadius);
            for (int segment = searchStart; segment <= searchEnd; segment++) {
              CenterlinePoint a = centerline.points[segment];
              CenterlinePoint b = centerline.points[segment+1];
              float vx = b.x-a.x, vy = b.y-a.y, vz = b.z-a.z;
              float denominator = max(0.0000001f, vx*vx + vy*vy + vz*vz);
              float t = constrain(((wx-a.x)*vx + (wy-a.y)*vy + (wz-a.z)*vz) / denominator, 0, 1);
              float qx = a.x+t*vx, qy = a.y+t*vy, qz = a.z+t*vz;
              float distance = (wx-qx)*(wx-qx) + (wy-qy)*(wy-qy) + (wz-qz)*(wz-qz);
              if (distance < best) { best = distance; bestSegment = segment; bestT = t; }
            }
            if (bestSegment > searchStart && bestSegment < searchEnd) break;
            searchRadius *= 2;
          }
          if (bestSegment < 0 || !dcrteFinite(best)) {
            volume.fallbackUsed[idx] = true;
            volume.fallbackCount++;
            continue;
          }

          // Evaluate the second candidate only after the final best segment is known.
          // This keeps adjacent pieces of one smooth arc from looking nonlocal.
          float second = Float.POSITIVE_INFINITY;
          int secondSegment = -1;
          for (int segment = searchStart; segment <= searchEnd; segment++) {
            if (abs(segment-bestSegment) <= localNeighborThreshold) continue;
            CenterlinePoint sa = centerline.points[segment];
            CenterlinePoint sb = centerline.points[segment+1];
            float svx = sb.x-sa.x, svy = sb.y-sa.y, svz = sb.z-sa.z;
            float denominator = max(0.0000001f, svx*svx + svy*svy + svz*svz);
            float t = constrain(((wx-sa.x)*svx + (wy-sa.y)*svy + (wz-sa.z)*svz) / denominator, 0, 1);
            float qx = sa.x+t*svx, qy = sa.y+t*svy, qz = sa.z+t*svz;
            float distance = (wx-qx)*(wx-qx) + (wy-qy)*(wy-qy) + (wz-qz)*(wz-qz);
            if (distance < second) { second = distance; secondSegment = segment; }
          }

          CenterlinePoint a = centerline.points[bestSegment];
          CenterlinePoint b = centerline.points[bestSegment+1];
          float cx = lerp(a.x, b.x, bestT), cy = lerp(a.y, b.y, bestT), cz = lerp(a.z, b.z, bestT);
          TransportFrame fa = frames.frames[bestSegment], fb = frames.frames[bestSegment+1];
          float tx = lerp(fa.tx, fb.tx, bestT), ty = lerp(fa.ty, fb.ty, bestT), tz = lerp(fa.tz, fb.tz, bestT);
          float tangentLength = max(0.0000001f, sqrt(tx*tx + ty*ty + tz*tz));
          tx /= tangentLength; ty /= tangentLength; tz /= tangentLength;
          float nx = lerp(fa.nx, fb.nx, bestT), ny = lerp(fa.ny, fb.ny, bestT), nz = lerp(fa.nz, fb.nz, bestT);
          float projection = nx*tx + ny*ty + nz*tz;
          nx -= projection*tx; ny -= projection*ty; nz -= projection*tz;
          float normalLength = max(0.0000001f, sqrt(nx*nx + ny*ny + nz*nz));
          nx /= normalLength; ny /= normalLength; nz /= normalLength;
          float bx = ty*nz-tz*ny, by = tz*nx-tx*nz, bz = tx*ny-ty*nx;
          float binormalLength = max(0.0000001f, sqrt(bx*bx + by*by + bz*bz));
          bx /= binormalLength; by /= binormalLength; bz /= binormalLength;
          float dx = wx-cx, dy = wy-cy, dz = wz-cz;
          float u = dx*nx + dy*ny + dz*nz;
          float v = dx*bx + dy*by + dz*bz;
          float r = sqrt(u*u + v*v);
          float angle = r < radialEpsilon ? 0 : atan2(v, u);
          float equivalentRadius = dcrteEquivalentRadiusAt(centerline, bestT, bestSegment, radiusEpsilon);
          if (equivalentRadius <= radiusEpsilon + 0.000001f) volume.poleClampedCount++;
          float rho;
          if (dcrteIntrinsicRadialModel == DCRTERadialModel.ELLIPTICAL) {
            float major = max(radiusEpsilon, lerp(a.majorRadius, b.majorRadius, bestT));
            float minor = max(radiusEpsilon, lerp(a.minorRadius, b.minorRadius, bestT));
            rho = sqrt((u/major)*(u/major) + (v/minor)*(v/minor));
          } else rho = r / equivalentRadius;

          float longitudinal = lerp(a.normalizedS, b.normalizedS, bestT);
          boolean ambiguous = secondSegment >= 0 && sqrt(second)-sqrt(best) < ambiguityTolerance;
          float uniqueness = ambiguous ? 0.45f : 1.0f;
          float endpoint = constrain(min(longitudinal, 1-longitudinal) * 10.0f, 0.35f, 1.0f);
          float frameConfidence = min(fa.confidence, fb.confidence);
          float radialConfidence = dcrteIntrinsicRadialModel == DCRTERadialModel.EQUIVALENT_CIRCULAR ? 0.82f : 0.74f;
          float confidence = min(resolutionConfidence, min(lerp(a.confidence, b.confidence, bestT),
            min(frameConfidence, min(uniqueness, min(radialConfidence, endpoint)))));
          if (!dcrteFinite(longitudinal) || !dcrteFinite(r) || !dcrteFinite(rho)
              || !dcrteFinite(angle) || !dcrteFinite(confidence)) {
            volume.nonFiniteCount++;
            volume.fallbackUsed[idx] = true;
            volume.fallbackCount++;
            continue;
          }
          volume.s[idx] = longitudinal;
          volume.radialDistance[idx] = r;
          volume.normalizedRadius[idx] = rho;
          volume.theta[idx] = angle;
          volume.signedBoundaryDistance[idx] = sdf.signedDistance[idx];
          volume.confidence[idx] = constrain(confidence, 0, 1);
          volume.centerlineIndex[idx] = bestSegment;
          volume.valid[idx] = true;
          volume.ambiguous[idx] = ambiguous;
          volume.validCount++;
          if (ambiguous) volume.ambiguousCount++;
        }
      }
    }
    return volume;
  }

  void computeConfidenceStats(IntrinsicCoordinateVolume volume,IntrinsicValidationReport validation){if(volume==null||volume.validCount==0){validation.minimumConfidence=0;return;}float[] values=new float[volume.validCount];int n=0;double sum=0;float minimum=1;for(int i=0;i<volume.valid.length;i++)if(volume.valid[i]){float value=volume.confidence[i];values[n++]=value;sum+=value;minimum=min(minimum,value);}java.util.Arrays.sort(values);validation.meanConfidence=(float)(sum/n);validation.p05Confidence=values[constrain(round(0.05f*(n-1)),0,n-1)];validation.minimumConfidence=minimum;}
  void finish(IntrinsicBuildResult result,long totalStart){result.validation.totalMillis=millis()-totalStart;if(result.validation.suitability!=null)result.validation.suitability.finalizeStatus();result.validation.finalizeStatus();}
}

class DCRTECoordinateComparisonReport {
  int admittedVoxelCount;
  int cartesianCandidateCount,intrinsicCandidateCount,cartesianFinalCount,intrinsicFinalCount;
  int cartesianComponents,intrinsicComponents;
  float cartesianLargestComponentFraction,intrinsicLargestComponentFraction;
  int cartesianOutsideSolidCount,intrinsicOutsideSolidCount;
  float cartesianSolidFraction,intrinsicSolidFraction;
  long cartesianFieldMillis,intrinsicFieldMillis,intrinsicBuildMillis,mappingMillis;
  float ambiguityFraction,fallbackFraction,meanConfidence;
  boolean[] cartesianFinalMask,intrinsicFinalMask;
  JSONObject toJSON(){JSONObject json=new JSONObject();json.setString("mode",CoordinateComparisonMode.CARTESIAN_AND_INTRINSIC.id());json.setInt("admitted_voxels",admittedVoxelCount);json.setInt("cartesian_candidate_solid",cartesianCandidateCount);json.setInt("intrinsic_candidate_solid",intrinsicCandidateCount);json.setInt("cartesian_final_solid",cartesianFinalCount);json.setInt("intrinsic_final_solid",intrinsicFinalCount);json.setFloat("cartesian_solid_fraction",cartesianSolidFraction);json.setFloat("intrinsic_solid_fraction",intrinsicSolidFraction);json.setInt("cartesian_components",cartesianComponents);json.setInt("intrinsic_components",intrinsicComponents);json.setFloat("cartesian_largest_component_fraction",cartesianLargestComponentFraction);json.setFloat("intrinsic_largest_component_fraction",intrinsicLargestComponentFraction);json.setInt("cartesian_outside_solid",cartesianOutsideSolidCount);json.setInt("intrinsic_outside_solid",intrinsicOutsideSolidCount);json.setLong("cartesian_field_millis",cartesianFieldMillis);json.setLong("intrinsic_field_millis",intrinsicFieldMillis);json.setLong("intrinsic_build_millis",intrinsicBuildMillis);json.setLong("mapping_millis",mappingMillis);json.setFloat("ambiguity_fraction",ambiguityFraction);json.setFloat("fallback_fraction",fallbackFraction);json.setFloat("mean_confidence",meanConfidence);return json;}
}

int[] dcrteBooleanVolumeComponentStats(boolean[] mask, VolumeSpec spec) {
  int[] result = {0, 0, 0};
  if (mask == null || spec == null || mask.length != spec.voxelCount()) return result;
  boolean[] visited = new boolean[mask.length];
  int[] queue = new int[mask.length];
  int plane = spec.nx * spec.ny;
  for (int seedIndex = 0; seedIndex < mask.length; seedIndex++) {
    if (!mask[seedIndex] || visited[seedIndex]) continue;
    int head = 0, tail = 0;
    queue[tail++] = seedIndex;
    visited[seedIndex] = true;
    while (head < tail) {
      int idx = queue[head++];
      int x = idx % spec.nx;
      int yz = idx / spec.nx;
      int y = yz % spec.ny;
      int z = yz / spec.ny;
      if (x > 0) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx - 1);
      if (x + 1 < spec.nx) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx + 1);
      if (y > 0) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx - spec.nx);
      if (y + 1 < spec.ny) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx + spec.nx);
      if (z > 0) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx - plane);
      if (z + 1 < spec.nz) tail = dcrteEnqueueBooleanVoxel(mask, visited, queue, tail, idx + plane);
    }
    result[0]++;
    result[1] = max(result[1], tail);
    result[2] += tail;
  }
  return result;
}

int dcrteEnqueueBooleanVoxel(boolean[] mask, boolean[] visited, int[] queue, int tail, int index) {
  if (!mask[index] || visited[index]) return tail;
  visited[index] = true;
  queue[tail] = index;
  return tail + 1;
}
