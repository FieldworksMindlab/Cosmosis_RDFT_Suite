/* M6-HX immutable classical intrinsic-coordinate observables. */

class HBEIntrinsicObservables {
  final VolumeSpec spec;
  final float[] xi;
  final float[] lobeDepth;
  final float[] neckProximity;
  final float[] leftWeight;
  final float[] rightWeight;
  final float[] theta;
  final float[] rho;
  final float[] confidence;
  final boolean[] valid;
  final boolean[] leftAnchor;
  final boolean[] rightAnchor;
  final boolean[] neckBand;
  final int validCount;
  final int leftAnchorCount;
  final int rightAnchorCount;
  final int neckCount;
  final String sourceHash;

  HBEIntrinsicObservables(IntrinsicCoordinateVolume source, HBEConfig config) {
    spec = dcrteCopyVolumeSpec(source == null ? null : source.spec);
    int n = spec == null ? 0 : max(0, spec.voxelCount());
    xi = new float[n]; lobeDepth = new float[n]; neckProximity = new float[n];
    leftWeight = new float[n]; rightWeight = new float[n]; theta = new float[n];
    rho = new float[n]; confidence = new float[n]; valid = new boolean[n];
    leftAnchor = new boolean[n]; rightAnchor = new boolean[n]; neckBand = new boolean[n];
    int validTotal = 0, leftTotal = 0, rightTotal = 0, neckTotal = 0;
    float floor = config == null ? 0.20f : config.confidenceFloor;
    float anchor = config == null ? 0.12f : config.anchorFraction;
    float neckLo = config == null ? 0.40f : config.neckMin;
    float neckHi = config == null ? 0.60f : config.neckMax;
    if (source != null && source.isValid() && source.s.length == n) {
      for (int i = 0; i < n; i++) {
        float s = source.s[i]; float c = source.confidence[i];
        boolean usable = source.valid[i] && dcrteFinite(s) && dcrteFinite(c) && c >= floor;
        valid[i] = usable;
        if (!usable) continue;
        s = constrain(s, 0, 1); xi[i] = 2 * s - 1;
        lobeDepth[i] = abs(xi[i]);
        neckProximity[i] = 1 - constrain(abs(s - 0.5f) / max(0.000001f, 0.5f * (neckHi - neckLo)), 0, 1);
        leftWeight[i] = 1 - s; rightWeight[i] = s;
        theta[i] = source.theta[i]; rho[i] = source.normalizedRadius[i]; confidence[i] = c;
        leftAnchor[i] = s <= anchor; rightAnchor[i] = s >= 1 - anchor;
        neckBand[i] = s >= neckLo && s <= neckHi;
        validTotal++; if (leftAnchor[i]) leftTotal++; if (rightAnchor[i]) rightTotal++; if (neckBand[i]) neckTotal++;
      }
    }
    validCount = validTotal; leftAnchorCount = leftTotal; rightAnchorCount = rightTotal; neckCount = neckTotal;
    sourceHash = dcrteHbeObservablesHash();
  }

  boolean isValid() {
    int n = spec == null ? -1 : spec.voxelCount();
    return spec != null && spec.isValid() && n > 0 && valid.length == n
      && validCount > 0 && leftAnchorCount > 0 && rightAnchorCount > 0 && neckCount > 0;
  }

  String dcrteHbeObservablesHash() {
    try {
      java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
      dcrteDigestString(digest, spec == null ? "missing" : spec.toJSON().toString());
      for (int i = 0; i < valid.length; i++) if (valid[i]) {
        dcrteDigestInt(digest, i); dcrteDigestInt(digest, Float.floatToIntBits(xi[i]));
        dcrteDigestInt(digest, Float.floatToIntBits(rho[i]));
        dcrteDigestInt(digest, Float.floatToIntBits(theta[i]));
        dcrteDigestInt(digest, Float.floatToIntBits(confidence[i]));
      }
      return dcrteHex(digest.digest());
    } catch (Exception error) { return "sha256-error"; }
  }

  JSONObject toJSON() {
    JSONObject j = new JSONObject(); j.setString("sha256", sourceHash);
    j.setJSONObject("spec", spec == null ? new JSONObject() : spec.toJSON());
    j.setInt("valid_voxels", validCount); j.setInt("left_anchor_voxels", leftAnchorCount);
    j.setInt("right_anchor_voxels", rightAnchorCount); j.setInt("neck_voxels", neckCount);
    j.setBoolean("valid", isValid());
    j.setString("coordinate_semantics", "xi=2s-1; lobe_depth=abs(xi); neck_proximity peaks in declared neck band");
    return j;
  }
}

HBEIntrinsicObservables dcrteHbeBuildObservables(IntrinsicCoordinateVolume source, HBEConfig config) {
  return new HBEIntrinsicObservables(source, config == null ? new HBEConfig() : config.copy());
}
