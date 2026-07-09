// =============================================================
//  CTC CHANNEL ENGINE
//  RDFT / Mallett-inspired channel state for Processing + SC.
// =============================================================

float ctcProximity = 0.0;
float ctcProximityRaw = 0.0;
float ctcFloquetAsymmetry = 1.0;
float ctcClosureMetric = 0.0;
float ctcClosureFreq = 55.0;
float ctcVaidyaAtten = 1.0;
int ctcZone = 0;              // 0 idle, 1 approach, 2 threshold, 3 inside
boolean ctcChannelClosed = false;
boolean ctcChannelActive = false;
String ctcZoneLabel = "IDLE";

// Lightweight real-time version of the external CTC window estimator.
// Updated at low cadence and rendered as scalar gauges only; it does not feed
// audio or Floquet state, so it remains observational.
float ctcWindowScore = 0.0;
float ctcWindowScoreRaw = 0.0;
float ctcWindowBasinScore = 0.0;
float ctcWindowLyapScore = 0.0;
float ctcWindowOrbitalScore = 0.0;
float ctcWindowEGScore = 0.0;
float ctcWindowTPScore = 0.0;
float ctcWindowFloquetScore = 0.0;
float ctcWindowGEffScore = 0.0;
float ctcWindowEcoScore = 0.0;
float ctcWindowGalaxyScore = 0.0;
int ctcWindowCoreGates = 0;
int ctcWindowExtendedGates = 0;
String ctcWindowLabel = "WINDOW CLOSED";
String ctcWindowHint = "conditions not aligned";
int ctcEstimatorLastFrame = -999999;

final int CTC_TRAIL_MAX = 180;
ArrayList<PVector> ctcOrbitTrail = new ArrayList<PVector>();

void updateCTCChannel() {
  float thresholdProximity = constrain(phi_threshold_prox, 0.0, 1.4);
  float localGInverse = constrain(1.0 - phi_gain, 0.0, 1.0);
  float orbitLockGate = orbitLockStrength > 0.85 ? 1.0 : 0.0;
  float berryAbs = constrain(abs(metricBerryPhase), 0.0, 1.0);
  float egVoltage = (fcPanel != null) ? constrain(fcPanel.egInjectedVoltage / 100.0, 0.0, 1.0) : 0.0;
  float solarXray = (solarBridge != null) ? constrain(solarBridge.xrayNorm, 0.0, 1.0) : 0.0;
  float solarWind = (solarBridge != null) ? constrain(solarBridge.windNorm, 0.0, 1.0) : 0.0;
  float solarDrive = (solarXray + solarWind) * 0.5;

  ctcProximityRaw =
    0.35 * thresholdProximity +
    0.20 * localGInverse +
    0.15 * orbitLockGate +
    0.15 * berryAbs +
    0.10 * egVoltage +
    0.05 * solarDrive;

  ctcProximity = 0.95 * ctcProximity + 0.05 * ctcProximityRaw;
  ctcZone = computeCTCZone(ctcProximity);
  ctcZoneLabel = ctcZoneName(ctcZone);

  updateCTCClosureMetric();

  ctcChannelClosed = ctcClosureMetric > 0.72;
  ctcChannelActive = (metricLyapunov < 0.0 && ctcProximity > 0.85) || ctcChannelClosed || ctcZone >= 3;

  float asymMix = constrain((ctcProximity - 0.70) / 0.30, 0.0, 1.0);
  ctcFloquetAsymmetry = lerp(1.0, 0.20, asymMix);
  ctcVaidyaAtten = ctcFloquetAsymmetry;

  float root = (sliderRootFreq != null) ? sliderRootFreq.getValue() : 55.0;
  ctcClosureFreq = constrain(root * (0.50 + ctcClosureMetric * 0.50 + max(0, metricBerryPhase) * 0.25), 28.0, 180.0);

  updateCTCWindowEstimator();
}

int computeCTCZone(float p) {
  if (p > 1.0) return 3;
  if (p >= 0.85) return 2;
  if (p >= 0.60) return 1;
  return 0;
}

String ctcZoneName(int zone) {
  switch(zone) {
    case 1: return "APPROACH";
    case 2: return "THRESHOLD";
    case 3: return "INSIDE";
    default: return "IDLE";
  }
}

void updateCTCClosureMetric() {
  ctcOrbitTrail.add(new PVector(orb_x, orb_y));
  while (ctcOrbitTrail.size() > CTC_TRAIL_MAX) ctcOrbitTrail.remove(0);

  if (ctcOrbitTrail.size() < 40) {
    ctcClosureMetric *= 0.96;
    return;
  }

  PVector now = ctcOrbitTrail.get(ctcOrbitTrail.size() - 1);
  PVector half = ctcOrbitTrail.get(ctcOrbitTrail.size() / 2);
  float d = PVector.dist(now, half);
  float radius = max(0.05, sqrt(orb_x * orb_x + orb_y * orb_y));
  float closeness = constrain(1.0 - d / max(0.12, radius * 1.25), 0.0, 1.0);
  float stableFold = metricLyapunov < 0 ? constrain(abs(metricLyapunov) * 0.35, 0.0, 1.0) : 0.0;
  float lockFold = constrain(orbitLockStrength, 0.0, 1.0);
  float rawClosure = closeness * (0.55 + 0.25 * lockFold + 0.20 * stableFold);

  ctcClosureMetric = 0.90 * ctcClosureMetric + 0.10 * rawClosure;
}

void updateCTCWindowEstimator() {
  if (frameCount - ctcEstimatorLastFrame < 6) return;
  ctcEstimatorLastFrame = frameCount;

  float orbitalRadius = sqrt(orb_x * orb_x + orb_y * orb_y);
  String basin = (cartBasin == null) ? "" : cartBasin;
  boolean basinMD = basin.equals("METASTABLE DRIFT");
  boolean basinCoherent = basin.equals("COHERENCE BASIN") || basin.equals("FLOQUET LOCK");
  boolean basinTransition = basin.equals("TRANSITION RIDGE") || basin.equals("DENSE COUPLED FIELD");

  ctcWindowBasinScore = basinMD ? 1.0 : basinCoherent ? 0.82 : basinTransition ? 0.35 : 0.0;
  ctcWindowLyapScore = constrain((1.20 - metricLyapunov) / 1.20, 0, 1);
  ctcWindowOrbitalScore = orbitalRadius < 1.20
      ? 1.0
      : 0.55 * constrain((2.00 - orbitalRadius) / 0.80, 0, 1);
  ctcWindowEGScore = constrain((0.80 - electroGravityFactor) / 0.50, 0, 1);
  ctcWindowTPScore = constrain(phi_threshold_prox, 0, 1);
  ctcWindowFloquetScore = constrain(fsLockScoreRaw / 0.74, 0, 1);
  ctcWindowGEffScore = constrain((audioDiagFloquetGEffLive + 0.12) / 0.32, 0, 1);
  ctcWindowEcoScore = (audioDiagEcoChirpLastAge >= 0)
      ? constrain(1.0 - audioDiagEcoChirpLastAge / 5.0, 0, 1)
      : 0.0;
  ctcWindowGalaxyScore = galaxyLoaded
      ? constrain(1.0 - abs(galaxyFieldCurvature - 0.88) / 0.25, 0, 1)
      : 0.0;

  ctcWindowScoreRaw =
    0.25 * ctcWindowBasinScore +
    0.25 * ctcWindowLyapScore +
    0.18 * ctcWindowOrbitalScore +
    0.10 * ctcWindowEGScore +
    0.06 * ctcWindowTPScore +
    0.06 * ctcWindowFloquetScore +
    0.04 * ctcWindowGEffScore +
    0.04 * ctcWindowEcoScore +
    0.02 * ctcWindowGalaxyScore;

  ctcWindowScore = 0.88 * ctcWindowScore + 0.12 * ctcWindowScoreRaw;

  ctcWindowCoreGates = 0;
  if (basinMD) ctcWindowCoreGates++;
  if (metricLyapunov < 0.60) ctcWindowCoreGates++;
  if (orbitalRadius < 2.00) ctcWindowCoreGates++;
  if (electroGravityFactor < 0.30) ctcWindowCoreGates++;

  ctcWindowExtendedGates = ctcWindowCoreGates;
  if (fsLockScoreRaw > 0.40) ctcWindowExtendedGates++;
  if (orbitalRadius < 1.20) ctcWindowExtendedGates++;

  if (ctcWindowScore > 0.62) {
    ctcWindowLabel = "WINDOW PEAK";
    ctcWindowHint = "sub-1.2 orbit plus near-closure";
  } else if (ctcWindowScore > 0.50) {
    ctcWindowLabel = "WINDOW OPEN";
    ctcWindowHint = "3+ conditions aligned";
  } else if (ctcWindowScore > 0.35) {
    ctcWindowLabel = "APPROACHING";
    ctcWindowHint = "watch lyapunov and EG";
  } else {
    ctcWindowLabel = "WINDOW CLOSED";
    ctcWindowHint = "conditions not aligned";
  }
}

color ctcWindowColor(float score) {
  if (score > 0.62) return color(224, 64, 64);
  if (score > 0.50) return color(111, 207, 90);
  if (score > 0.35) return color(232, 160, 48);
  return color(90, 130, 105);
}

void applyCTCFloquetAsymmetry() {
  if (ctcProximity <= 0.70) return;
  for (int i = 1; i < FS_N_PARAMS; i += 2) {
    fsNu[i] = constrain(fsNu[i] * ctcFloquetAsymmetry, -FS_DRIVE_BOUND, FS_DRIVE_BOUND);
  }
}

void sendCTCStateToSuperCollider() {
  if (oscP5 == null || supercollider == null) return;
  updateCTCChannel();

  OscMessage msg = new OscMessage("/rdf/ctcState");
  msg.add(ctcProximity);
  msg.add(ctcProximityRaw);
  msg.add((float)ctcZone);
  msg.add(ctcFloquetAsymmetry);
  msg.add(ctcChannelClosed ? 1.0 : 0.0);
  msg.add(ctcClosureMetric);
  msg.add(ctcClosureFreq);
  msg.add(ctcChannelActive ? 1.0 : 0.0);
  msg.add(ctcVaidyaAtten);
  try { oscP5.send(msg, supercollider); } catch (Exception e) {}
}

void drawCTCChannelGlyph(float cx, float cy, float r) {
  float pulse = 0.5 + 0.5 * sin(frameCount * 0.08);
  float p = constrain(ctcProximity, 0.0, 1.2);
  color ringCol = ctcZone >= 2 ? color(255, 190, 80) : ctcZone == 1 ? color(80, 220, 210) : color(80, 120, 150);

  noFill();
  stroke(ringCol, 70 + 140 * p);
  strokeWeight(1.0 + 2.0 * p);
  ellipse(cx, cy, r * 2.0, r * 2.0);

  stroke(ringCol, 35 + 80 * pulse * p);
  strokeWeight(0.7);
  ellipse(cx, cy, r * (1.25 + 0.12 * pulse), r * (1.25 - 0.08 * pulse));

  float sweep = TWO_PI * constrain(p, 0.0, 1.0);
  stroke(ctcChannelActive ? color(255, 90, 120) : ringCol, 230);
  strokeWeight(2.2);
  arc(cx, cy, r * 2.25, r * 2.25, -HALF_PI, -HALF_PI + sweep);

  if (ctcChannelClosed) {
    stroke(255, 90, 120, 210);
    strokeWeight(1.0);
    line(cx - r * 0.70, cy, cx + r * 0.70, cy);
    line(cx, cy - r * 0.70, cx, cy + r * 0.70);
  }

  textFont(createFont("Courier New", 8));
  textAlign(CENTER, CENTER);
  fill(ctcChannelActive ? color(255, 150, 170) : color(150, 215, 230));
  text("CTC", cx, cy - 4);
  fill(170, 190, 205);
  text(safeNf(ctcProximity, 1, 2), cx, cy + 7);
}
