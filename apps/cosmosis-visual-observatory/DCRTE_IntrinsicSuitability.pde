/* DCRTE-ET Milestone 3 suitability and validation reports. */

class DCRTEIntrinsicCodes {
  static final String IC_DOMAIN_NOT_PREFLIGHT_QUALIFIED="IC_DOMAIN_NOT_PREFLIGHT_QUALIFIED";
  static final String IC_INSIDE_MASK_EMPTY="IC_INSIDE_MASK_EMPTY";
  static final String IC_MULTIPLE_DOMINANT_COMPONENTS="IC_MULTIPLE_DOMINANT_COMPONENTS";
  static final String IC_AXIS_UNDEFINED="IC_AXIS_UNDEFINED";
  static final String IC_CENTERLINE_COVERAGE_LOW="IC_CENTERLINE_COVERAGE_LOW";
  static final String IC_CENTERLINE_DISCONTINUOUS="IC_CENTERLINE_DISCONTINUOUS";
  static final String IC_BRANCHING_SUSPECTED="IC_BRANCHING_SUSPECTED";
  static final String IC_CLOSED_LOOP_SUSPECTED="IC_CLOSED_LOOP_SUSPECTED";
  static final String IC_FRAME_BUILD_FAILED="IC_FRAME_BUILD_FAILED";
  static final String IC_MAPPING_AMBIGUITY_HIGH="IC_MAPPING_AMBIGUITY_HIGH";
  static final String IC_MAPPING_FAILED="IC_MAPPING_FAILED";
  static final String IC_NONFINITE_COORDINATES="IC_NONFINITE_COORDINATES";
  static final String IC_FALLBACK_FRACTION_HIGH="IC_FALLBACK_FRACTION_HIGH";
  static final String IC_LOW_ELONGATION="IC_LOW_ELONGATION";
  static final String IC_CROSS_SECTION_VARIATION_HIGH="IC_CROSS_SECTION_VARIATION_HIGH";
  static final String IC_CONCAVITY_HIGH="IC_CONCAVITY_HIGH";
  static final String IC_NEAREST_CENTERLINE_AMBIGUOUS="IC_NEAREST_CENTERLINE_AMBIGUOUS";
  static final String IC_RADIAL_NORMALIZATION_APPROXIMATE="IC_RADIAL_NORMALIZATION_APPROXIMATE";
  static final String IC_ENDPOINT_CONFIDENCE_LOW="IC_ENDPOINT_CONFIDENCE_LOW";
  static final String IC_FRAME_TWIST_ELEVATED="IC_FRAME_TWIST_ELEVATED";
  static final String IC_THIN_FEATURE_RISK="IC_THIN_FEATURE_RISK";
}

class IntrinsicSuitabilityReport {
  ValidationStatus status=ValidationStatus.PASS;
  int insideComponentCount;
  float dominantComponentFraction;
  float principalEigenvalue1,principalEigenvalue2,principalEigenvalue3;
  float elongationRatio12,elongationRatio13;
  float centerlineCoverage,validSliceFraction,maximumSliceGapFraction;
  float centerlineSelfApproachRisk,nearestPointAmbiguityFraction,frameContinuityScore,radialNormalizationConfidence;
  boolean singleDominantComponent,closedLoopSuspected,branchingSuspected,suitable;
  ArrayList<String> blockers=new ArrayList<String>();
  ArrayList<String> warnings=new ArrayList<String>();

  void block(String code){if(!blockers.contains(code))blockers.add(code);status=ValidationStatus.FAIL;suitable=false;}
  void warn(String code){if(!warnings.contains(code))warnings.add(code);if(status!=ValidationStatus.FAIL)status=ValidationStatus.PASS_WITH_WARNINGS;}
  void finalizeStatus(){suitable=blockers.isEmpty();if(!suitable)status=ValidationStatus.FAIL;else if(!warnings.isEmpty())status=ValidationStatus.PASS_WITH_WARNINGS;else status=ValidationStatus.PASS;}
  JSONObject toJSON(){JSONObject json=new JSONObject();json.setString("status",status.id());json.setInt("inside_component_count",insideComponentCount);json.setFloat("dominant_component_fraction",dominantComponentFraction);json.setFloat("principal_eigenvalue_1",principalEigenvalue1);json.setFloat("principal_eigenvalue_2",principalEigenvalue2);json.setFloat("principal_eigenvalue_3",principalEigenvalue3);json.setFloat("elongation_ratio_12",elongationRatio12);json.setFloat("elongation_ratio_13",elongationRatio13);json.setFloat("centerline_coverage",centerlineCoverage);json.setFloat("valid_slice_fraction",validSliceFraction);json.setFloat("maximum_slice_gap_fraction",maximumSliceGapFraction);json.setFloat("centerline_self_approach_risk",centerlineSelfApproachRisk);json.setFloat("nearest_point_ambiguity_fraction",nearestPointAmbiguityFraction);json.setFloat("frame_continuity_score",frameContinuityScore);json.setFloat("radial_normalization_confidence",radialNormalizationConfidence);json.setBoolean("single_dominant_component",singleDominantComponent);json.setBoolean("closed_loop_suspected",closedLoopSuspected);json.setBoolean("branching_suspected",branchingSuspected);json.setBoolean("suitable",suitable);json.setJSONArray("blockers",dcrteStringListJSON(blockers));json.setJSONArray("warnings",dcrteStringListJSON(warnings));return json;}
}

class IntrinsicValidationReport {
  ValidationStatus status=ValidationStatus.PASS;
  IntrinsicSuitabilityReport suitability;
  int totalInsideVoxels,validIntrinsicVoxels,ambiguousVoxels,fallbackVoxels,nonFiniteVoxels,poleClampedVoxels;
  int appliedFallbackVoxels;
  float validFraction,ambiguityFraction,fallbackFraction;
  float appliedFallbackFraction;
  float centerlineLength,centerlineCoverage,maxCenterlineStep,minimumCenterlineSDFMargin;
  float meanFrameRotation,maxFrameRotation;int frameDiscontinuityCount;
  float meanConfidence,p05Confidence,minimumConfidence;
  long pcaMillis,sliceMillis,centerlineMillis,frameMillis,mappingMillis,totalMillis;
  ArrayList<String> errors=new ArrayList<String>();ArrayList<String>warnings=new ArrayList<String>();
  void error(String code){if(!errors.contains(code))errors.add(code);status=ValidationStatus.FAIL;}
  void warn(String code){if(!warnings.contains(code))warnings.add(code);if(status!=ValidationStatus.FAIL)status=ValidationStatus.PASS_WITH_WARNINGS;}
  void finalizeStatus(){if(!errors.isEmpty())status=ValidationStatus.FAIL;else if(!warnings.isEmpty())status=ValidationStatus.PASS_WITH_WARNINGS;else status=ValidationStatus.PASS;}
  boolean exportAllowed(){return status!=ValidationStatus.FAIL&&nonFiniteVoxels==0&&fallbackFraction<=0.01f&&validIntrinsicVoxels>0;}
  String primaryIssue(){if(!errors.isEmpty())return errors.get(0);if(suitability!=null&&!suitability.blockers.isEmpty())return suitability.blockers.get(0);return status.id().toUpperCase();}
  JSONObject toJSON(){JSONObject json=new JSONObject();json.setString("status",status.id());if(suitability!=null)json.setJSONObject("suitability",suitability.toJSON());json.setInt("total_inside_voxels",totalInsideVoxels);json.setInt("valid_intrinsic_voxels",validIntrinsicVoxels);json.setInt("ambiguous_voxels",ambiguousVoxels);json.setInt("fallback_voxels",fallbackVoxels);json.setInt("applied_fallback_voxels",appliedFallbackVoxels);json.setInt("nonfinite_voxels",nonFiniteVoxels);json.setInt("pole_clamped_voxels",poleClampedVoxels);json.setFloat("valid_fraction",validFraction);json.setFloat("ambiguity_fraction",ambiguityFraction);json.setFloat("fallback_fraction",fallbackFraction);json.setFloat("applied_fallback_fraction",appliedFallbackFraction);json.setFloat("centerline_length",centerlineLength);json.setFloat("centerline_coverage",centerlineCoverage);json.setFloat("max_centerline_step",maxCenterlineStep);json.setFloat("minimum_centerline_sdf_margin",minimumCenterlineSDFMargin);json.setFloat("mean_frame_rotation",meanFrameRotation);json.setFloat("max_frame_rotation",maxFrameRotation);json.setInt("frame_discontinuity_count",frameDiscontinuityCount);json.setFloat("mean_confidence",meanConfidence);json.setFloat("p05_confidence",p05Confidence);json.setFloat("minimum_confidence",minimumConfidence);JSONObject timings=new JSONObject();timings.setLong("pca_millis",pcaMillis);timings.setLong("slice_millis",sliceMillis);timings.setLong("centerline_millis",centerlineMillis);timings.setLong("frame_millis",frameMillis);timings.setLong("mapping_millis",mappingMillis);timings.setLong("total_millis",totalMillis);json.setJSONObject("timings",timings);json.setJSONArray("errors",dcrteStringListJSON(errors));json.setJSONArray("warnings",dcrteStringListJSON(warnings));json.setBoolean("export_allowed",exportAllowed());return json;}
}
