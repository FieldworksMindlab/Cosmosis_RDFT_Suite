// =============================================================================
// Petaminx Experimental Modes
// =============================================================================
// Single-window JAVA2D implementation for the experimental Petaminx edition.
// It keeps the main synth renderer intact while adding live RDFT field
// interpreters derived from the attached Petaminx, star-projector, vault, and
// NPC cache-mode notes.

final int EXP_OFF       = 0;
final int EXP_PETAMINX  = 1;
final int EXP_STARS     = 2;
final int EXP_CACHE     = 3;
final int EXP_TIME_CTC  = 4;
int experimentalMode = EXP_OFF;
String[] experimentalModeNames = {
  "OFF",
  "PETAMINX FIELD",
  "STAR PROJECTORS",
  "VAULT / NPC CACHE",
  "TIME CTC"
};

final int PET_FACES = 12;
final int PET_FACELETS = 11;
// Facelet colour cache adapted from the standalone OSC Petaminx listener.
// This keeps the current in-window visual structure intact: no PeasyCam, no P3D requirement,
// no new OSC listener. The cache is refreshed from the existing RDFT field/alpha/depth data.
color[][][] petaminxFaceletColours = new color[PET_FACES][PET_FACELETS][PET_FACELETS];
float petaminxLastAlpha = -999;
int petaminxLastDepth = -999;
float petaminxLastCoupling = -999;
int petaminxLastColourFrame = -999;
float petaminxSpin = 0;
float petaminxScramble = 0;
float starAlphaSensitivity = 1.0;
float vaultCacheAlpha = 2.0;
float npcGateAlpha = 3.0;

ArrayList<StarProjectorNode> starProjectors = new ArrayList<StarProjectorNode>();
ArrayList<VaultCacheNode> vaultCacheNodes = new ArrayList<VaultCacheNode>();
float cacheStimX = -1;
float cacheStimY = -1;
int cacheStimTimer = 0;
boolean lastCacheHit = false;

void initPetaminxExperimentalModes() {
  seedStarProjectors();
  seedVaultCacheNodes();
  updatePetaminxFaceletColours(true);
}

void PETAMINXMODE(int val) {
  experimentalMode = (experimentalMode + 1) % experimentalModeNames.length;
  updatePetaminxModeButton();
  statusMsg = "Experimental Petaminx mode: " + experimentalModeNames[experimentalMode];
}

void updatePetaminxModeButton() {
  if (btnPetaminxMode == null) return;
  btnPetaminxMode.setLabel("PETAMINX: " + experimentalModeNames[experimentalMode]);
  if (experimentalMode == EXP_OFF) {
    btnPetaminxMode.setColorBackground(color(35, 35, 48));
  } else {
    btnPetaminxMode.setColorBackground(color(44, 78, 96));
  }
}

void handlePetaminxExperimentalKey() {
  if (key == 'p' || key == 'P') {
    PETAMINXMODE(0);
  } else if (key == 's' || key == 'S') {
    if (experimentalMode == EXP_PETAMINX) {
      petaminxScramble = 1.0;
      statusMsg = "Petaminx alpha injection: facelets scrambled then relaxing";
    } else if (experimentalMode == EXP_STARS) {
      starProjectors.add(new StarProjectorNode(random(0.12, 0.88), random(0.18, 0.82)));
      statusMsg = "Added star projector node";
    }
  } else if (key == 'r' || key == 'R') {
    if (experimentalMode == EXP_PETAMINX) {
      petaminxScramble = 0.0;
      statusMsg = "Petaminx field remapped from live RDFT combined field";
    } else if (experimentalMode == EXP_STARS) {
      seedStarProjectors();
      statusMsg = "Star projector field reset";
    }
  } else if (key == 'v' || key == 'V') {
    if (experimentalMode == EXP_CACHE) {
      vaultCacheNodes.add(new VaultCacheNode(random(0.12, 0.58), random(0.18, 0.82)));
      statusMsg = "Added vault cache line";
    }
  } else if (key == 'x' || key == 'X') {
    if (experimentalMode == EXP_CACHE && vaultCacheNodes.size() > 0) {
      vaultCacheNodes.remove(vaultCacheNodes.size() - 1);
      statusMsg = "Removed vault cache line";
    }
  }
}

void drawPetaminxExperimentalOverlay() {
  if (experimentalMode == EXP_OFF) return;

  int x = 20;
  int y = PANEL_TOP + PANEL_H + 28;
  int w = W - 320;
  int h = H - y - BTM_H - 14;
  if (w < 500 || h < 260) return;

  fill(5, 8, 14, 238);
  stroke(80, 145, 150, 190);
  strokeWeight(1);
  rect(x, y, w, h, 8);

  fill(230);
  textAlign(LEFT, TOP);
  textSize(13);
  text("EXPERIMENTAL PETAMINX EDITION / " + experimentalModeNames[experimentalMode], x + 14, y + 12);
  textSize(10);
  fill(155, 190, 190);
  text("P cycles layer | PETAMINX: S scramble, R reset | STARS: S add, R reset | CACHE: V add, X remove | TIME CTC: automatic", x + 14, y + 31);

  int innerX = x + 14;
  int innerY = y + 52;
  int innerW = w - 28;
  int innerH = h - 66;

  if (experimentalMode == EXP_PETAMINX) {
    drawPetaminxFieldAtlas(innerX, innerY, innerW, innerH);
  } else if (experimentalMode == EXP_STARS) {
    drawStarProjectorMode(innerX, innerY, innerW, innerH);
  } else if (experimentalMode == EXP_CACHE) {
    drawVaultNpcCacheMode(innerX, innerY, innerW, innerH);
  } else if (experimentalMode == EXP_TIME_CTC) {
    drawTimeTraversalCTCMode(innerX, innerY, innerW, innerH);
  }
}

void drawTimeTraversalCTCMode(int x, int y, int w, int h) {
  if (frameCount - ctcEstimatorLastFrame >= 6) updateCTCChannel();

  int readW = constrain(round(w * 0.34), 260, 310);
  int viewW = w - readW - 18;
  float cx = x + viewW * 0.50;
  float cy = y + h * 0.52;
  float r = min(viewW, h) * 0.30;
  float p = constrain(ctcProximity, 0.0, 1.2);
  float closure = constrain(ctcClosureMetric, 0.0, 1.0);
  float phase = frameCount * (0.014 + 0.022 * p);

  noStroke();
  fill(5, 8, 14);
  rect(x, y, viewW, h, 6);

  for (int i = 0; i < 9; i++) {
    float rr = r * (0.34 + i * 0.105);
    float a = 34 + i * 10 + 80 * p;
    stroke(40 + i * 8, 105 + i * 8, 135 + i * 9, a);
    strokeWeight(i == 8 ? 1.4 : 0.55);
    noFill();
    ellipse(cx, cy, rr * 2.0, rr * (1.10 + 0.05 * sin(phase + i)));
  }

  stroke(255, 190, 80, 105 + 120 * constrain((p - 0.6) / 0.4, 0, 1));
  strokeWeight(1.5 + 2.0 * p);
  noFill();
  float sweep = TWO_PI * constrain(p, 0, 1);
  arc(cx, cy, r * 2.42, r * 1.34, -HALF_PI + phase * 0.25, -HALF_PI + phase * 0.25 + sweep);
  arc(cx, cy, r * 1.62, r * 2.12, HALF_PI - phase * 0.18, HALF_PI - phase * 0.18 + sweep * 0.72);

  stroke(90, 230, 220, 85 + 90 * closure);
  strokeWeight(1.0);
  beginShape();
  for (int i = 0; i <= 260; i++) {
    float t = i / 260.0 * TWO_PI;
    float fold = sin(t * 2.0 + phase) * (0.20 + 0.22 * closure);
    float px = cx + cos(t + fold) * r * (0.84 + 0.18 * sin(t * 3.0 + phase));
    float py = cy + sin(t * 2.0 - phase * 0.65) * r * 0.42;
    vertex(px, py);
  }
  endShape(CLOSE);

  if (ctcOrbitTrail != null && ctcOrbitTrail.size() > 2) {
    stroke(255, 90, 130, 60 + 120 * closure);
    strokeWeight(1.0 + closure);
    noFill();
    beginShape();
    int start = max(0, ctcOrbitTrail.size() - 120);
    for (int i = start; i < ctcOrbitTrail.size(); i++) {
      PVector v = ctcOrbitTrail.get(i);
      float px = cx + constrain(v.x, -3.0, 3.0) / 3.0 * r * 0.70;
      float py = cy + constrain(v.y, -3.0, 3.0) / 3.0 * r * 0.70;
      vertex(px, py);
    }
    endShape();
  }

  drawCTCChannelGlyph(cx, cy, r * 0.24);

  if (ctcChannelClosed || ctcChannelActive) {
    stroke(255, 90, 130, 120 + 80 * sin(frameCount * 0.12));
    strokeWeight(1.2);
    line(cx - r * 1.12, cy, cx + r * 1.12, cy);
    line(cx, cy - r * 0.76, cx, cy + r * 0.76);
  }

  int rx = x + viewW + 18;
  drawCTCWindowEstimatorPanel(rx, y, readW, h);
}

void drawCTCWindowEstimatorPanel(int x, int y, int w, int h) {
  rdfPanelFrame(x, y, w, h, "CTC WINDOW ESTIMATOR");
  color zoneCol = ctcWindowColor(ctcWindowScore);
  int pad = 14;
  int ringCx = x + 48;
  int ringCy = y + 70;
  int ringR = 28;

  fill(zoneCol);
  textAlign(LEFT, TOP);
  textSize(12);
  text(ctcWindowLabel, x + 92, y + 36);
  fill(120, 160, 150);
  textSize(9);
  text(ctcWindowHint, x + 92, y + 53, w - 108, 30);

  noFill();
  stroke(40, 70, 62, 170);
  strokeWeight(5);
  ellipse(ringCx, ringCy, ringR * 2, ringR * 2);
  stroke(zoneCol);
  strokeWeight(5);
  arc(ringCx, ringCy, ringR * 2, ringR * 2, -HALF_PI, -HALF_PI + TWO_PI * constrain(ctcWindowScore, 0, 1));
  fill(zoneCol);
  textAlign(CENTER, CENTER);
  textSize(13);
  text(safeNf(ctcWindowScore, 1, 2), ringCx, ringCy);

  int dotY = y + 105;
  int dotX = x + pad;
  for (int i = 0; i < 4; i++) {
    stroke(70, 105, 90);
    strokeWeight(1);
    fill(i < ctcWindowCoreGates ? zoneCol : color(16, 25, 25));
    ellipse(dotX + i * 16, dotY, 9, 9);
  }
  fill(105, 145, 130);
  textAlign(LEFT, CENTER);
  textSize(8);
  text("CORE " + ctcWindowCoreGates + "/4   EXT " + ctcWindowExtendedGates + "/6", x + 82, dotY);

  int meterY = y + 124;
  int meterW = w - pad * 2;
  drawCTCWindowMeter(x + pad, meterY, meterW, "LYAPUNOV", ctcWindowLyapScore, safeNf(metricLyapunov, 1, 3), metricLyapunov < 0.60 ? color(111, 207, 90) : color(232, 160, 48));
  drawCTCWindowMeter(x + pad, meterY + 30, meterW, "ORBITAL R", ctcWindowOrbitalScore, safeNf(sqrt(orb_x * orb_x + orb_y * orb_y), 1, 3), sqrt(orb_x * orb_x + orb_y * orb_y) < 1.20 ? color(224, 64, 64) : color(74, 159, 232));
  drawCTCWindowMeter(x + pad, meterY + 60, meterW, "EG FACTOR", ctcWindowEGScore, safeNf(electroGravityFactor, 1, 3), electroGravityFactor < 0.30 ? color(111, 207, 90) : color(168, 123, 235));
  drawCTCWindowMeter(x + pad, meterY + 90, meterW, "FLOQ LOCK", ctcWindowFloquetScore, safeNf(fsLockScoreRaw, 1, 3), fsLockScoreRaw > 0.40 ? color(111, 207, 90) : color(232, 160, 48));

  int miniY = meterY + 126;
  drawCTCWindowMini(x + pad, miniY, w - pad * 2, "BASIN", ctcBasinShortName(), ctcWindowBasinScore > 0.75);
  drawCTCWindowMini(x + pad, miniY + 24, w - pad * 2, "G_EFF", safeNf(audioDiagFloquetGEffLive, 1, 4), audioDiagFloquetGEffLive > 0.05);
  drawCTCWindowMini(x + pad, miniY + 48, w - pad * 2, "ECO AGE", audioDiagEcoChirpLastAge < 0 ? "--" : safeNf(audioDiagEcoChirpLastAge, 1, 1) + "s", audioDiagEcoChirpLastAge >= 0 && audioDiagEcoChirpLastAge < 2.0);
  drawCTCWindowMini(x + pad, miniY + 72, w - pad * 2, "GAL CURV", safeNf(galaxyFieldCurvature, 1, 4), ctcWindowGalaxyScore > 0.85);

  fill(80, 120, 115);
  textSize(8);
  textAlign(LEFT, TOP);
  text("score = basin + lyap + orbital + EG + threshold + Floquet + ECO + galaxy", x + pad, y + h - 34, w - pad * 2, 24);
}

void drawCTCWindowMeter(int x, int y, int w, String label, float norm, String value, color c) {
  fill(95, 135, 125);
  textAlign(LEFT, TOP);
  textSize(8);
  text(label, x, y);
  fill(c);
  textAlign(RIGHT, TOP);
  text(value, x + w, y);
  noStroke();
  fill(22, 34, 34);
  rect(x, y + 14, w, 4);
  fill(c);
  rect(x, y + 14, constrain(norm, 0, 1) * w, 4);
}

void drawCTCWindowMini(int x, int y, int w, String label, String value, boolean hot) {
  color c = hot ? color(111, 207, 90) : color(105, 145, 130);
  stroke(hot ? color(80, 150, 95, 150) : color(40, 75, 70, 120));
  strokeWeight(1);
  fill(7, 13, 16, 160);
  rect(x, y, w, 18, 4);
  fill(c);
  textSize(8);
  textAlign(LEFT, CENTER);
  text(label, x + 7, y + 9);
  textAlign(RIGHT, CENTER);
  text(value, x + w - 7, y + 9);
}

String ctcBasinShortName() {
  if (cartBasin == null) return "--";
  if (cartBasin.equals("METASTABLE DRIFT")) return "MD";
  if (cartBasin.equals("TRANSITION RIDGE")) return "TR";
  if (cartBasin.equals("DISRUPTION ZONE")) return "DZ";
  if (cartBasin.equals("COHERENCE BASIN")) return "CB";
  if (cartBasin.equals("FLOQUET LOCK")) return "FL";
  if (cartBasin.equals("DENSE COUPLED FIELD")) return "DCF";
  return cartBasin;
}

void drawPetaminxFieldAtlas(int x, int y, int w, int h) {
  petaminxSpin += 0.012 + 0.006 * constrain(envFloquetCoupling(), 0, 1);
  petaminxScramble *= 0.965;
  updatePetaminxFaceletColours(false);

  int readW = 220;
  int viewW = w - readW - 18;
  float cx = x + viewW * 0.5;
  float cy = y + h * 0.52;
  float scale = min(viewW, h) * 0.28;

  noStroke();
  fill(9, 12, 20);
  rect(x, y, viewW, h, 6);

  // Soft field halo behind the solid Petaminx.
  float liveAlpha = safeAlphaValue(alpha);
  float coupling = envFloquetCoupling();
  float quasi = envFloquetQuasienergy();
  float ufoT = getPetaminxUfoTransition();
  boolean ufoOn = isPetaminxUfoModeOn();

  // In UFO mode the main field configuration panel already blends alpha/depth
  // toward its Floquet-optimised UFO targets. The Petaminx orbital proxy was
  // previously reading only raw alpha/depth/coupling, so it looked visually
  // disconnected from UFO mode. These effective values let the proxy respond
  // to the same transition without changing the rest of the program.
  float effectiveAlpha = lerp(liveAlpha, fsAlphaNow, ufoT * 0.62);
  float effectiveDepth = lerp((float)depth, 2.0 + 5.0 * ufoT, ufoT * 0.55);
  float depthNorm = constrain(effectiveDepth / 7.0, 0, 1);
  float alphaNorm = constrain((effectiveAlpha - 1.0) / 3.5, 0, 1);

  noFill();
  stroke(40, 105, 130, 70);
  strokeWeight(1);
  for (int rr = 0; rr < 4; rr++) {
    float halo = scale * (1.45 + rr * 0.17 + 0.06 * sin(frameCount * 0.018 + rr));
    ellipse(cx, cy, halo * 2.0, halo * 1.18);
  }

  // Rotate the full dodecahedral/Petaminx shell instead of distributing faces as a flat atlas.
  float rotY = petaminxSpin * (0.80 + 0.28 * alphaNorm);
  float rotX = -0.48 + 0.42 * sin(petaminxSpin * 0.63 + depthNorm * TWO_PI);
  float rotZ = 0.14 * sin(petaminxSpin * 0.37 + quasi * 3.0);
  drawPetaminxSolid(cx, cy, scale, rotX, rotY, rotZ);

  // Orbital proxy: an out-field body whose path responds to alpha separation, depth recursion,
  // and UFO mode when the Field Config panel is driving that transition.
  drawPetaminxOrbitalProxy(cx, cy, scale, rotX, rotY, rotZ, alphaNorm, depthNorm, coupling, quasi, ufoT, ufoOn);

  int rx = x + viewW + 18;
  rdfPanelFrame(rx, y, readW, h, "PETAMINX FACELET READOUT");
  drawExperimentalBar(rx + 14, y + 40, readW - 28, "alpha separation", alphaNorm, safeNf(liveAlpha, 1, 3), color(90, 220, 155));
  drawExperimentalBar(rx + 14, y + 76, readW - 28, "depth recursion", depthNorm, str(depth), color(110, 170, 255));
  drawExperimentalBar(rx + 14, y + 112, readW - 28, "floquet coupling", constrain(coupling, 0, 1), safeNf(coupling, 1, 3), color(255, 180, 90));
  drawExperimentalBar(rx + 14, y + 148, readW - 28, "quasienergy", constrain(abs(quasi), 0, 1), safeNf(quasi, 1, 3), color(210, 130, 255));
  drawExperimentalBar(rx + 14, y + 184, readW - 28, "scramble decay", constrain(petaminxScramble, 0, 1), safeNf(petaminxScramble, 1, 3), color(255, 90, 110));
  drawExperimentalBar(rx + 14, y + 220, readW - 28, "UFO orbit link", ufoT, ufoOn ? ("ON " + safeNf(ufoT, 1, 2)) : "OFF", color(80, 210, 255));

  fill(160, 190, 190);
  textSize(10);
  textAlign(LEFT, TOP);
  text("Live combined field is sampled into a rotating 12-face Petaminx shell. The orbital proxy traces alpha/depth recursion and now locks into UFO transition/orbital dynamics when UFO mode is active.", rx + 14, y + h - 64, readW - 28, 58);
}

void updatePetaminxFaceletColours(boolean force) {
  float liveAlpha = safeAlphaValue(alpha);
  float coupling = constrain(envFloquetCoupling(), 0, 1);
  boolean changed = force
    || abs(liveAlpha - petaminxLastAlpha) > 0.015
    || depth != petaminxLastDepth
    || abs(coupling - petaminxLastCoupling) > 0.015
    || frameCount - petaminxLastColourFrame > 12
    || petaminxScramble > 0.01;
  if (!changed) return;

  petaminxLastAlpha = liveAlpha;
  petaminxLastDepth = depth;
  petaminxLastCoupling = coupling;
  petaminxLastColourFrame = frameCount;

  for (int f = 0; f < PET_FACES; f++) {
    for (int i = 0; i < PET_FACELETS; i++) {
      for (int j = 0; j < PET_FACELETS; j++) {
        float fu = (i + 0.5) / PET_FACELETS;
        float fv = (j + 0.5) / PET_FACELETS;

        // Standalone-listener behaviour, but sourced from the existing live field.
        // Each face receives a slight coordinate offset so the 12 faces do not become identical copies.
        float val = sampleLiveField((fu + (f % 4) * 0.17) % 1.0, (fv + (f % 3) * 0.21) % 1.0);
        val = pow(constrain(val, 0, 1), 1.0 / max(0.1, liveAlpha / 2.0));
        val = constrain(val * (1.0 + depth / 10.0), 0, 1);

        // Low-coupling flicker from the standalone listener, made deterministic so the facelets
        // don't shimmer randomly or destabilize the current visual language.
        if (coupling < 0.3) {
          float grain = 0.8 + 0.4 * noise(f * 11.7 + i * 0.37, j * 0.41, frameCount * 0.025);
          val = constrain(val * grain, 0, 1);
        }

        if (petaminxScramble > 0.01) {
          float scrambled = noise(f * 3.1 + i * 0.7, j * 0.7, frameCount * 0.09);
          val = lerp(val, scrambled, petaminxScramble);
        }

        petaminxFaceletColours[f][i][j] = cmap_viridis[constrain((int)(val * 255), 0, 255)];
      }
    }
  }
}

void drawPetaminxSolid(float cx, float cy, float scale, float rotX, float rotY, float rotZ) {
  // TRUE SHARED-VERTEX SHELL PATCH
  // The prior visual built each pentagonal panel from its normal independently.
  // That looked like a 3D Petaminx, but the faces did not mathematically share vertices.
  // This version treats the 12 Petaminx faces as planes whose normals are the 12
  // vertices of an icosahedron, then computes every pentagon corner from the
  // intersection of three neighboring planes. Adjacent faces therefore project
  // to the same exact endpoints.
  float[][] normals = petIcosaFaceNormals();
  float shell = 0.86;

  int[] order = new int[PET_FACES];
  float[] zed = new float[PET_FACES];
  for (int i = 0; i < PET_FACES; i++) {
    order[i] = i;
    float[] rn = petRotate3(normals[i][0], normals[i][1], normals[i][2], rotX, rotY, rotZ);
    zed[i] = rn[2];
  }

  // Painter sort: far faces first.
  for (int a = 0; a < PET_FACES - 1; a++) {
    for (int b = a + 1; b < PET_FACES; b++) {
      if (zed[order[a]] > zed[order[b]]) {
        int tmp = order[a]; order[a] = order[b]; order[b] = tmp;
      }
    }
  }

  for (int pass = 0; pass < PET_FACES; pass++) {
    int f = order[pass];
    drawPetaminxSolidFace(f, normals, shell, cx, cy, scale, rotX, rotY, rotZ);
  }
}

float[][] petIcosaFaceNormals() {
  float g = (1.0 + sqrt(5.0)) * 0.5;
  float[][] raw = {
    {0, 1, g}, {0, -1, g}, {0, 1, -g}, {0, -1, -g},
    {1, g, 0}, {-1, g, 0}, {1, -g, 0}, {-1, -g, 0},
    {g, 0, 1}, {-g, 0, 1}, {g, 0, -1}, {-g, 0, -1}
  };
  float[][] out = new float[PET_FACES][3];
  for (int i = 0; i < PET_FACES; i++) {
    float[] q = petNormalize(raw[i][0], raw[i][1], raw[i][2]);
    out[i][0] = q[0];
    out[i][1] = q[1];
    out[i][2] = q[2];
  }
  return out;
}

void drawPetaminxSolidFace(int faceIdx, float[][] normals, float shell, float cx, float cy, float scale, float rotX, float rotY, float rotZ) {
  float[] n = normals[faceIdx];
  float[] helper = (abs(n[1]) < 0.82) ? new float[]{0, 1, 0} : new float[]{1, 0, 0};
  float[] u = petNormalizeCross(helper, n);
  float[] v = petNormalizeCross(n, u);

  float[][] verts3 = petDodecaFaceVertices(faceIdx, normals, shell);
  float[][] verts2 = new float[5][2];
  for (int k = 0; k < 5; k++) {
    float[] d = petSub3(verts3[k], petScale3(n, shell));
    verts2[k][0] = petDot3(d, u);
    verts2[k][1] = petDot3(d, v);
  }
  petSortPolygon2D(verts2, verts3);

  float[] rn = petRotate3(n[0], n[1], n[2], rotX, rotY, rotZ);
  float shade = map(rn[2], -1, 1, 0.38, 1.0);
  float alphaFace = map(rn[2], -1, 1, 70, 245);

  float[] bounds = petBounds2D(verts2);
  float minX = bounds[0], maxX = bounds[1], minY = bounds[2], maxY = bounds[3];
  float padX = (maxX - minX) * 0.006;
  float padY = (maxY - minY) * 0.006;
  float stepX = (maxX - minX) / PET_FACELETS;
  float stepY = (maxY - minY) / PET_FACELETS;

  // Facelet grid now uses the exact same local polygon as the outline.
  // This removes the slight field-map drift seen when the cells were clipped
  // against one pentagon but outlined with another.
  for (int i = 0; i < PET_FACELETS; i++) {
    for (int j = 0; j < PET_FACELETS; j++) {
      float x0 = minX + i * stepX + padX;
      float x1 = minX + (i + 1) * stepX - padX;
      float y0 = minY + j * stepY + padY;
      float y1 = minY + (j + 1) * stepY - padY;
      float mx = (x0 + x1) * 0.5;
      float my = (y0 + y1) * 0.5;
      if (!petPointInPoly2D(mx, my, verts2)) continue;

      color cc = petaminxFaceletColours[faceIdx][i][j];
      fill(red(cc) * shade, green(cc) * shade, blue(cc) * shade, alphaFace);
      noStroke();
      drawProjectedPetCell(n, u, v, shell, x0, y0, x1, y1, cx, cy, scale, rotX, rotY, rotZ);
    }
  }

  // Draw the real shared-vertex face boundary using the computed 3D corners.
  noFill();
  stroke(190 * shade, 220 * shade, 210 * shade, map(rn[2], -1, 1, 55, 190));
  strokeWeight(1.2);
  beginShape();
  for (int k = 0; k < 5; k++) {
    float[] rp = petRotate3(verts3[k][0], verts3[k][1], verts3[k][2], rotX, rotY, rotZ);
    PVector sp = petProject(rp, cx, cy, scale);
    vertex(sp.x, sp.y);
  }
  endShape(CLOSE);
}

float[][] petDodecaFaceVertices(int faceIdx, float[][] normals, float shell) {
  float targetDot = 1.0 / sqrt(5.0);
  int[] neigh = new int[5];
  int nCount = 0;
  for (int j = 0; j < PET_FACES; j++) {
    if (j == faceIdx) continue;
    float d = petDot3(normals[faceIdx], normals[j]);
    if (abs(d - targetDot) < 0.035 && nCount < 5) {
      neigh[nCount++] = j;
    }
  }

  float[][] verts = new float[5][3];
  int vCount = 0;
  for (int a = 0; a < nCount; a++) {
    for (int b = a + 1; b < nCount; b++) {
      float d = petDot3(normals[neigh[a]], normals[neigh[b]]);
      if (abs(d - targetDot) < 0.035 && vCount < 5) {
        float[] p = petPlaneIntersection(normals[faceIdx], normals[neigh[a]], normals[neigh[b]], shell);
        verts[vCount][0] = p[0];
        verts[vCount][1] = p[1];
        verts[vCount][2] = p[2];
        vCount++;
      }
    }
  }

  // Safety fallback: should not trigger, but keeps the mode drawable if the
  // adjacency tolerance ever fails on a different Processing float backend.
  if (vCount < 5) {
    float[] helper = (abs(normals[faceIdx][1]) < 0.82) ? new float[]{0, 1, 0} : new float[]{1, 0, 0};
    float[] u = petNormalizeCross(helper, normals[faceIdx]);
    float[] v = petNormalizeCross(normals[faceIdx], u);
    float r = 0.58;
    for (int k = 0; k < 5; k++) {
      float a = -HALF_PI + TWO_PI * k / 5.0;
      float[] p = petFacePoint(normals[faceIdx], u, v, shell, cos(a) * r, sin(a) * r);
      verts[k][0] = p[0]; verts[k][1] = p[1]; verts[k][2] = p[2];
    }
  }
  return verts;
}

float[] petPlaneIntersection(float[] a, float[] b, float[] c, float shell) {
  float[] bc = petCross3(b, c);
  float[] ca = petCross3(c, a);
  float[] ab = petCross3(a, b);
  float denom = petDot3(a, bc);
  if (abs(denom) < 0.0001) return petScale3(a, shell);
  return new float[] {
    shell * (bc[0] + ca[0] + ab[0]) / denom,
    shell * (bc[1] + ca[1] + ab[1]) / denom,
    shell * (bc[2] + ca[2] + ab[2]) / denom
  };
}

void petSortPolygon2D(float[][] verts2, float[][] verts3) {
  float cx = 0, cy = 0;
  for (int i = 0; i < 5; i++) { cx += verts2[i][0]; cy += verts2[i][1]; }
  cx /= 5.0;
  cy /= 5.0;
  for (int a = 0; a < 4; a++) {
    for (int b = a + 1; b < 5; b++) {
      float aa = atan2(verts2[a][1] - cy, verts2[a][0] - cx);
      float bb = atan2(verts2[b][1] - cy, verts2[b][0] - cx);
      if (aa > bb) {
        float tx = verts2[a][0], ty = verts2[a][1];
        verts2[a][0] = verts2[b][0]; verts2[a][1] = verts2[b][1];
        verts2[b][0] = tx; verts2[b][1] = ty;
        float[] tmp = verts3[a]; verts3[a] = verts3[b]; verts3[b] = tmp;
      }
    }
  }
}

float[] petBounds2D(float[][] verts2) {
  float minX = 9999, maxX = -9999, minY = 9999, maxY = -9999;
  for (int i = 0; i < 5; i++) {
    minX = min(minX, verts2[i][0]);
    maxX = max(maxX, verts2[i][0]);
    minY = min(minY, verts2[i][1]);
    maxY = max(maxY, verts2[i][1]);
  }
  return new float[] {minX, maxX, minY, maxY};
}

boolean petPointInPoly2D(float px, float py, float[][] poly) {
  boolean inside = false;
  for (int i = 0, j = 4; i < 5; j = i++) {
    float yi = poly[i][1];
    float yj = poly[j][1];
    float xi = poly[i][0];
    float xj = poly[j][0];
    float denom = yj - yi;
    if (abs(denom) < 0.0001) denom = 0.0001;
    if (((yi > py) != (yj > py)) &&
        (px < (xj - xi) * (py - yi) / denom + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

void drawProjectedPetCell(float[] n, float[] u, float[] v, float shell, float x0, float y0, float x1, float y1, float cx, float cy, float scale, float rotX, float rotY, float rotZ) {
  float[][] corners = {
    {x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}
  };
  beginShape();
  for (int q = 0; q < 4; q++) {
    float[] p = petFacePoint(n, u, v, shell, corners[q][0], corners[q][1]);
    float[] rp = petRotate3(p[0], p[1], p[2], rotX, rotY, rotZ);
    PVector sp = petProject(rp, cx, cy, scale);
    vertex(sp.x, sp.y);
  }
  endShape(CLOSE);
}

float petDot3(float[] a, float[] b) {
  return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}

float[] petCross3(float[] a, float[] b) {
  return new float[] {
    a[1]*b[2] - a[2]*b[1],
    a[2]*b[0] - a[0]*b[2],
    a[0]*b[1] - a[1]*b[0]
  };
}

float[] petScale3(float[] a, float s) {
  return new float[] {a[0]*s, a[1]*s, a[2]*s};
}

float[] petSub3(float[] a, float[] b) {
  return new float[] {a[0]-b[0], a[1]-b[1], a[2]-b[2]};
}

void drawPetaminxOrbitalProxy(float cx, float cy, float scale, float rotX, float rotY, float rotZ, float alphaNorm, float depthNorm, float coupling, float quasi, float ufoT, boolean ufoOn) {
  float liveOrbRadius = constrain(sqrt(orb_x * orb_x + orb_y * orb_y) / max(0.0001, ORB_BOUND), 0, 1.8);
  float liveOrbSpeed = constrain(sqrt(orb_vx * orb_vx + orb_vy * orb_vy) / 2.5, 0, 1.5);
  float liveOrbPhase = atan2(orb_y, orb_x);

  // Baseline Petaminx orbit: alpha widens separation, recursion deepens inclination.
  float baseA = 1.62 + 0.46 * alphaNorm;
  float baseB = 0.82 + 0.34 * depthNorm;
  float baseTilt = -0.58 + 0.96 * depthNorm;

  // UFO-linked orbit: blend toward the actual main orbital path and EG/Floquet lift.
  // This makes the proxy communicate with UFO mode without touching the main orbital solver.
  float orbitA = lerp(baseA, 1.18 + liveOrbRadius * 0.92 + fsHoldingStrength * 0.18, ufoT);
  float orbitB = lerp(baseB, 0.52 + liveOrbSpeed * 0.44 + (1.0 - electroGravityFactor) * 0.55, ufoT);
  float tilt = lerp(baseTilt, -0.18 + fcPetaminxUfoSignedTilt() * 0.92, ufoT);

  float freePhase = frameCount * (0.012 + 0.018 * alphaNorm + 0.010 * coupling) + petaminxSpin * (0.7 + depthNorm);
  float ufoPhase = liveOrbPhase + fsPhase * 0.45 + frameCount * (0.006 + 0.018 * liveOrbSpeed);
  float phase = lerp(freePhase, ufoPhase, ufoT);

  noFill();
  stroke(lerp(95, 70, ufoT), lerp(180, 220, ufoT), lerp(220, 255, ufoT), 105 + 55 * ufoT);
  strokeWeight(1);
  beginShape();
  for (int i = 0; i <= 140; i++) {
    float t = TWO_PI * i / 140.0;
    float ox = cos(t) * orbitA;
    float oy = sin(t) * orbitB * cos(tilt);
    float oz = sin(t) * orbitB * sin(tilt);
    float[] rp = petRotate3(ox, oy, oz, rotX * 0.35, rotY * 0.35, rotZ);
    PVector sp = petProject(rp, cx, cy, scale);
    vertex(sp.x, sp.y);
  }
  endShape();

  float ox = cos(phase) * orbitA;
  float oy = sin(phase) * orbitB * cos(tilt);
  float oz = sin(phase) * orbitB * sin(tilt);
  float[] rp = petRotate3(ox, oy, oz, rotX * 0.35, rotY * 0.35, rotZ);
  PVector sp = petProject(rp, cx, cy, scale);

  float pulse = 0.5 + 0.5 * sin(frameCount * (0.08 + 0.05 * ufoT) + quasi * TWO_PI + fsPhase * ufoT);
  noStroke();
  fill(lerp(255, 85, ufoT), lerp(210, 230, ufoT), lerp(105, 255, ufoT), 150 + 90 * pulse);
  ellipse(sp.x, sp.y, 8 + 8 * coupling + 9 * ufoT, 8 + 8 * coupling + 9 * ufoT);
  fill(255, 245, 190, 190 + 45 * ufoT);
  ellipse(sp.x, sp.y, 3.5 + 2.0 * ufoT, 3.5 + 2.0 * ufoT);

  if (ufoOn && ufoT > 0.08) {
    noFill();
    stroke(80, 220, 255, 65 + 80 * ufoT);
    strokeWeight(1.0);
    ellipse(sp.x, sp.y, 16 + 22 * ufoT + 10 * pulse, 8 + 13 * ufoT);
  }
}

boolean isPetaminxUfoModeOn() {
  // UFO controls live in FieldConfigPanel.pde:
  //   boolean ufoModeOn
  //   float   ufoTransition
  //   float getUfoBlend()
  // Use the panel state directly; do not depend on any Petaminx button/control.
  return fcPanel != null && fcPanel.fcReady && fcPanel.ufoModeOn;
}

float getPetaminxUfoTransition() {
  if (fcPanel == null || !fcPanel.fcReady) return 0.0;
  // getUfoBlend() already returns 0 when UFO MODE is off and ufoTransition when on.
  return constrain(fcPanel.getUfoBlend(), 0, 1);
}

float fcPetaminxUfoSignedTilt() {
  float t = getPetaminxUfoTransition();
  return sin(t * HALF_PI + fsPhase * 0.25);
}

float[] petFacePoint(float[] n, float[] u, float[] v, float shell, float px, float py) {
  return new float[] {
    n[0] * shell + u[0] * px + v[0] * py,
    n[1] * shell + u[1] * px + v[1] * py,
    n[2] * shell + u[2] * px + v[2] * py
  };
}

PVector petProject(float[] p, float cx, float cy, float scale) {
  float camera = 3.35;
  float z = p[2] + 1.25;
  float persp = camera / max(0.35, camera - z * 0.62);
  return new PVector(cx + p[0] * scale * persp, cy + p[1] * scale * persp);
}

float[] petRotate3(float x, float y, float z, float ax, float ay, float az) {
  float cx = cos(ax), sx = sin(ax);
  float cy = cos(ay), sy = sin(ay);
  float cz = cos(az), sz = sin(az);

  float y1 = y * cx - z * sx;
  float z1 = y * sx + z * cx;
  float x1 = x;

  float x2 = x1 * cy + z1 * sy;
  float z2 = -x1 * sy + z1 * cy;
  float y2 = y1;

  float x3 = x2 * cz - y2 * sz;
  float y3 = x2 * sz + y2 * cz;
  return new float[] {x3, y3, z2};
}

float[] petNormalize(float x, float y, float z) {
  float m = max(0.0001, sqrt(x*x + y*y + z*z));
  return new float[] {x/m, y/m, z/m};
}

float[] petNormalizeCross(float[] a, float[] b) {
  float x = a[1]*b[2] - a[2]*b[1];
  float y = a[2]*b[0] - a[0]*b[2];
  float z = a[0]*b[1] - a[1]*b[0];
  return petNormalize(x, y, z);
}

boolean pointInRegularPentagon(float px, float py, float r) {
  boolean inside = false;
  float[] vx = new float[5];
  float[] vy = new float[5];
  for (int i = 0; i < 5; i++) {
    float a = -HALF_PI + TWO_PI * i / 5.0;
    vx[i] = cos(a) * r;
    vy[i] = sin(a) * r;
  }
  for (int i = 0, j = 4; i < 5; j = i++) {
    float denom = vy[j] - vy[i];
    if (abs(denom) < 0.0001) denom = 0.0001;
    if (((vy[i] > py) != (vy[j] > py)) &&
        (px < (vx[j] - vx[i]) * (py - vy[i]) / denom + vx[i])) {
      inside = !inside;
    }
  }
  return inside;
}

void drawStarProjectorMode(int x, int y, int w, int h) {
  starAlphaSensitivity = constrain(starAlphaSensitivity + 0.012 * sin(frameCount * 0.01 + alpha), 0.35, 2.5);
  noStroke();
  fill(5, 7, 12);
  rect(x, y, w, h, 6);

  int cols = 72;
  int rows = 38;
  float cw = w / (float)cols;
  float ch = h / (float)rows;
  for (int gy = 0; gy < rows; gy++) {
    for (int gx = 0; gx < cols; gx++) {
      float nx = (gx + 0.5) / cols;
      float ny = (gy + 0.5) / rows;
      float phi = 0.06;
      for (StarProjectorNode s : starProjectors) {
        phi += s.influence(nx, ny) * starAlphaSensitivity;
      }
      float fieldFold = sampleLiveField(nx, ny) * 0.42;
      phi = constrain(phi + fieldFold, 0, 1);
      fill(phi * 255, phi * 115, (1 - phi) * 190, 210);
      rect(x + gx * cw, y + gy * ch, cw + 0.5, ch + 0.5);
    }
  }

  for (StarProjectorNode s : starProjectors) {
    s.update();
    s.display(x, y, w, h);
  }

  int planetX = x + int(w * constrain(0.48 + 0.18 * sin(frameCount * 0.006), 0.1, 0.9));
  int planetY = y + int(h * 0.54);
  float localPhi = 0;
  for (StarProjectorNode s : starProjectors) localPhi += s.influence((planetX - x) / (float)w, (planetY - y) / (float)h);
  fill(255);
  ellipse(planetX, planetY, 12, 12);
  fill(0, 210);
  ellipse(planetX, planetY, 6, 6);

  fill(8, 10, 14, 215);
  stroke(75, 125, 150);
  rect(x + 12, y + 12, 278, 90, 6);
  fill(230);
  textSize(11);
  textAlign(LEFT, TOP);
  text("stars: " + starProjectors.size(), x + 24, y + 24);
  text("alpha sensitivity: " + safeNf(starAlphaSensitivity, 1, 3), x + 24, y + 42);
  text("planet local alpha: " + safeNf(constrain(localPhi * 5.0, 0, 5), 1, 3), x + 24, y + 60);
  text("RDFT field fold: " + safeNf(combined != null ? getAverageValue(combined) : 0, 1, 3), x + 24, y + 78);
}

void drawVaultNpcCacheMode(int x, int y, int w, int h) {
  int leftW = int(w * 0.58);
  drawVaultCacheField(x, y, leftW - 8, h);
  drawNpcGateField(x + leftW + 8, y, w - leftW - 8, h);
}

void drawVaultCacheField(int x, int y, int w, int h) {
  noStroke();
  fill(7, 10, 16);
  rect(x, y, w, h, 6);

  int cols = 54;
  int rows = 36;
  float cw = w / (float)cols;
  float ch = h / (float)rows;
  for (int gy = 0; gy < rows; gy++) {
    for (int gx = 0; gx < cols; gx++) {
      float nx = (gx + 0.5) / cols;
      float ny = (gy + 0.5) / rows;
      float v = sampleLiveField(nx, ny);
      float cost = constrain((vaultCacheAlpha - 0.5) / 4.0, 0, 1);
      fill(v * 110 + cost * 135, v * 180, 145 + v * 80 - cost * 80, 210);
      rect(x + gx * cw, y + gy * ch, cw + 0.5, ch + 0.5);
    }
  }

  for (VaultCacheNode v : vaultCacheNodes) {
    v.update();
    v.display(x, y, w, h);
  }

  if (frameCount % 90 == 0 || cacheStimTimer <= 0) {
    cacheStimX = random(0.08, 0.92);
    cacheStimY = random(0.15, 0.85);
    lastCacheHit = vaultCacheHit(cacheStimX, cacheStimY);
    vaultCacheAlpha = lastCacheHit ? 0.55 : 4.5;
    cacheStimTimer = 42;
  }
  if (cacheStimTimer > 0) {
    cacheStimTimer--;
    vaultCacheAlpha = lerp(vaultCacheAlpha, 2.0, 0.035);
    noStroke();
    fill(lastCacheHit ? color(80, 230, 130, 115) : color(255, 80, 80, 120));
    ellipse(x + cacheStimX * w, y + cacheStimY * h, 46, 46);
    fill(255);
    ellipse(x + cacheStimX * w, y + cacheStimY * h, 7, 7);
  }

  fill(8, 10, 14, 215);
  stroke(80, 125, 120);
  rect(x + 12, y + 12, 260, 88, 6);
  fill(230);
  textSize(11);
  textAlign(LEFT, TOP);
  text("VAULT CACHE FIELD", x + 24, y + 24);
  text("vaults: " + vaultCacheNodes.size(), x + 24, y + 42);
  text("current alpha cost: " + safeNf(vaultCacheAlpha, 1, 3), x + 24, y + 60);
  text(lastCacheHit ? "last event: CACHE HIT" : "last event: CACHE MISS", x + 24, y + 78);
}

void drawNpcGateField(int x, int y, int w, int h) {
  fill(8, 10, 16);
  stroke(65, 110, 135);
  rect(x, y, w, h, 6);

  int gateW = max(28, int(w * 0.12));
  int gateX = x + w / 2 - gateW / 2;
  noStroke();
  fill(20, 40, 95, 105);
  rect(x, y, gateX - x, h);
  fill(120, 20, 25, 105);
  rect(gateX + gateW, y, x + w - gateX - gateW, h);

  npcGateAlpha = constrain(3.0 + 1.3 * envFloquetCoupling() + 0.35 * sin(frameCount * 0.018), 0.5, 4.8);
  for (int i = 0; i < gateW; i++) {
    float t = i / max(1.0, gateW - 1.0);
    stroke(lerpColor(color(30, 70, 255, 150), color(255, 70, 45, 170), t));
    line(gateX + i, y, gateX + i, y + h);
  }

  for (int i = 0; i < 34; i++) {
    float phase = frameCount * 0.012 + i * 0.73;
    float px = x + (noise(i * 4.1, frameCount * 0.006) * 0.88 + 0.06) * w;
    float py = y + (0.12 + 0.76 * noise(i * 2.7, frameCount * 0.008 + 5)) * h;
    float pull = constrain(npcGateAlpha / 5.0, 0, 1);
    px = lerp(px, gateX + gateW * 0.5 + sin(phase) * gateW * 0.8, pull * 0.38);
    fill(lerpColor(color(80, 150, 255), color(255, 115, 95), pull), 210);
    noStroke();
    ellipse(px, py, 6 + 3 * pull, 6 + 3 * pull);
  }

  stroke(255, 210, 90, 220);
  noFill();
  rect(gateX, y, gateW, h);
  fill(255, 210, 90);
  textAlign(CENTER, CENTER);
  textSize(11);
  text("NPC\nGATE", gateX + gateW / 2, y + h / 2);

  fill(230);
  textAlign(LEFT, TOP);
  textSize(11);
  text("CYTOPLASM", x + 14, y + 18);
  text("NUCLEUS", gateX + gateW + 18, y + 18);
  drawExperimentalBar(x + 14, y + h - 64, w - 28, "NPC alpha selectivity", constrain(npcGateAlpha / 5.0, 0, 1), safeNf(npcGateAlpha, 1, 3), color(255, 190, 80));
  drawExperimentalBar(x + 14, y + h - 32, w - 28, "Ran gradient drive", constrain((npcGateAlpha - 0.5) / 4.3, 0, 1), safeNf((npcGateAlpha - 0.5) / 4.3, 1, 3), color(110, 190, 255));
}

boolean vaultCacheHit(float nx, float ny) {
  for (VaultCacheNode v : vaultCacheNodes) {
    if (dist(nx, ny, v.x, v.y) < 0.095) return true;
  }
  return false;
}

void seedStarProjectors() {
  starProjectors.clear();
  starProjectors.add(new StarProjectorNode(0.50, 0.45));
  starProjectors.add(new StarProjectorNode(0.28, 0.30));
  starProjectors.add(new StarProjectorNode(0.72, 0.32));
  starProjectors.add(new StarProjectorNode(0.58, 0.70));
}

void seedVaultCacheNodes() {
  vaultCacheNodes.clear();
  for (int i = 0; i < 12; i++) {
    vaultCacheNodes.add(new VaultCacheNode(random(0.10, 0.60), random(0.14, 0.86)));
  }
}

float sampleLiveField(float nx, float ny) {
  float[][] src = combined != null ? combined : dominant;
  if (src == null || src.length == 0 || src[0].length == 0) return noise(nx * 3.0, ny * 3.0, frameCount * 0.01);
  int rows = src.length;
  int cols = src[0].length;
  int ix = constrain((int)(nx * (cols - 1)), 0, cols - 1);
  int iy = constrain((int)(ny * (rows - 1)), 0, rows - 1);
  return constrain(src[iy][ix], 0, 1);
}

void drawExperimentalBar(int x, int y, int w, String label, float norm, String value, color c) {
  fill(150, 180, 180);
  textAlign(LEFT, TOP);
  textSize(9);
  text(label, x, y - 12);
  noStroke();
  fill(35, 42, 48);
  rect(x, y, w, 8);
  fill(c);
  rect(x, y, constrain(norm, 0, 1) * w, 8);
  fill(230);
  textAlign(RIGHT, TOP);
  text(value, x + w, y - 12);
}

class StarProjectorNode {
  float x, y;
  float alphaNode;
  float radius;
  float phase;
  color c;

  StarProjectorNode(float x, float y) {
    this.x = x;
    this.y = y;
    alphaNode = random(1.5, 4.5);
    radius = random(0.18, 0.34);
    phase = random(TWO_PI);
    c = color(random(170, 255), random(150, 230), random(80, 170));
  }

  void update() {
    phase += 0.018;
  }

  float influence(float px, float py) {
    float d = dist(px, py, x, y);
    if (d > radius) return 0;
    float falloff = exp(-sq(d / max(0.01, radius * 0.48)));
    return alphaNode * falloff / 4.5;
  }

  void display(int px, int py, int pw, int ph) {
    float sx = px + x * pw;
    float sy = py + y * ph;
    float glow = 28 + 14 * sin(phase);
    noStroke();
    fill(c, 82);
    ellipse(sx, sy, glow, glow);
    fill(255, 218, 120);
    ellipse(sx, sy, 8, 8);
  }
}

class VaultCacheNode {
  float x, y;
  float intensity;
  float phase;

  VaultCacheNode(float x, float y) {
    this.x = x;
    this.y = y;
    intensity = random(0.6, 1.0);
    phase = random(TWO_PI);
  }

  void update() {
    x = constrain(x + random(-0.002, 0.002), 0.04, 0.70);
    y = constrain(y + random(-0.002, 0.002), 0.05, 0.95);
    phase += 0.024;
  }

  void display(int px, int py, int pw, int ph) {
    float sx = px + x * pw;
    float sy = py + y * ph;
    float rad = 8 + 5 * intensity + 2 * sin(phase);
    noStroke();
    fill(255, 205, 100, 120);
    ellipse(sx, sy, rad * 2.1, rad * 2.1);
    fill(255, 225, 150, 220);
    ellipse(sx, sy, rad, rad);
    noFill();
    stroke(255, 230, 150, 160);
    ellipse(sx, sy, rad * 1.4, rad * 0.72);
  }
}
