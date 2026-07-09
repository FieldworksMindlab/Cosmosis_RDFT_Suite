// ============================================================
// SpectralGeometryModule.pde
// RDFT Spectral Geometry Module
// Replaces the old State Space Cartography panel.
//
// DROP-IN WIRING — in drawEmbeddedInterpretationLayer():
//
//   drawEmbeddedMaterialPanel(x1, y, wCol, h);
//   drawEmbeddedNodesPanel   (x2, y, wCol, h);
//   drawSpectralGeometryModule(x3, y, wCol*2 + gap, h);  // spans cols 3+4
//   // remove drawFoundationalFieldPanel call, or move it elsewhere
//
// The module spans two layout columns (616 x 354 px at default layout).
// It reads these globals directly — all exist in the main sketch:
//   alpha, cartX, cartY, cartZ, cartStability
//   envFloquetCoupling(), envFloquetQuasienergy(), fsPhase, depth
//   fsPhase, envFloquetCoupling(),
//   envFloquetQuasienergy()
// ============================================================

// ---- Mathematical constants ----------------------------------
// NOTE: no function calls at field level — Processing compiles all tabs
// as one class and sqrt()/exp() are not available at static-init time.
// SGM_A_COEFF is computed once on first call inside sgmInit().
final float SGM_ZETA3    = 1.2020569;
final float SGM_FINE     = 1.0 / 137.0360824;
float       SGM_A_COEFF  = 0;          // set in sgmInit()
final float[] SGM_D_VALS = { 1.203011, 4.806545, 10.818229 };
final int[]   SGM_LK_VALS = { 3, 8, 15, 24 };

// ---- Colours — plain hex literals only, no cross-references ----
final color SGM_CYAN   = #00E5CC;
final color SGM_TEAL   = #00B4A0;
final color SGM_ORANGE = #FF6B2B;
final color SGM_AMBER  = #FFB347;
final color SGM_PURPLE = #A78BFA;
final color SGM_GREEN  = #4ADE80;
final color SGM_RED    = #F87171;
final color SGM_MUTED  = #2A4050;
final color SGM_TEXT   = #C8DDE8;
final color SGM_BRIGHT = #E8F4FF;
// Arrays that reference other color fields must also be deferred
color[]  SGM_KNOT_COLS  = null;        // set in sgmInit()
final String[] SGM_KNOT_NAMES = { "UNKNOT", "HOPF LINK", "TREFOIL", "FIGURE-8" };

boolean sgmReady = false;
void sgmInit() {
  if (sgmReady) return;
  SGM_A_COEFF    = 6.0 * sqrt(2.0) * exp(SGM_ZETA3 / (24.0 * PI * PI));
  SGM_KNOT_COLS  = new color[]{ SGM_CYAN, SGM_TEAL, SGM_ORANGE, SGM_RED };
  sgmReady = true;
}

// ---- Holonomy trail ------------------------------------------
final int SGM_HOL_MAX   = 140;
float[] sgmHolX         = new float[SGM_HOL_MAX];
float[] sgmHolY         = new float[SGM_HOL_MAX];
int     sgmHolIdx       = 0;
int     sgmHolCount     = 0;

// ---- Module counters (independent of main frameCount) --------
int   sgmFrame          = 0;
float sgmFloqPhase      = 0.0;

// =============================================================
//  MAIN ENTRY POINT
//  Call: drawSpectralGeometryModule(x3, y, wCol*2+gap, h)
// =============================================================
void drawSpectralGeometryModule(int mx, int my, int mw, int mh) {
  sgmInit();
  sgmFrame++;
  sgmFloqPhase += 0.018;

  int statusH = 32;
  int gap     = 1;
  int pw      = (mw - gap) / 2;
  int ph      = (mh - statusH - gap) / 2;

  int x1 = mx,        y1 = my;
  int x2 = mx+pw+gap, y2 = my;
  int x3 = mx,        y3 = my + ph + gap;
  int x4 = mx+pw+gap, y4 = my + ph + gap;

  // panel backgrounds
  noStroke();
  fill(6,  9, 13);   rect(x1, y1, pw, ph);
  fill(6, 14, 20);   rect(x2, y2, pw, ph);
  fill(6, 12, 16);   rect(x3, y3, pw, ph);
  fill(6,  9, 14);   rect(x4, y4, pw, ph);

  sgmPanel01_Spectrum   (x1, y1, pw, ph);
  sgmPanel02_Shell      (x2, y2, pw, ph);
  sgmPanel03_Torsion    (x3, y3, pw, ph);
  sgmPanel04_Contact    (x4, y4, pw, ph);
  sgmStatusBar          (mx, my + mh - statusH, mw, statusH);
}

// =============================================================
//  PANEL 01 — BELTRAMI EIGENVALUE SPECTRUM
// =============================================================
void sgmPanel01_Spectrum(int px, int py, int pw, int ph) {
  sgmPanelLabel(px, py, "01", SGM_CYAN, "BELTRAMI", "EIGENVALUE SPECTRUM");

  int kActive  = sgmGetK();
  float specX  = px + 12;
  float specW  = pw - 24;
  float baseY  = py + ph - 28;
  float maxPH  = min(ph - 56, 110);

  // grid lines
  stroke(SGM_MUTED, 30); strokeWeight(0.4); noFill();
  for (int g = 1; g <= 4; g++) {
    line(specX, baseY - g*(maxPH/4), specX+specW, baseY - g*(maxPH/4));
  }
  stroke(SGM_MUTED, 60); strokeWeight(0.5);
  line(specX, py+22, specX, baseY+2);
  line(specX, baseY+2, specX+specW, baseY+2);

  float[] xNorms  = { 0.16, 0.38, 0.60, 0.82 };
  float   sigFrac = 0.055;
  float   sigPx   = sigFrac * specW;

  for (int k = 1; k <= 4; k++) {
    boolean isAct = (k == kActive);
    float   xPeak = specX + xNorms[k-1] * specW;
    float   lk    = SGM_LK_VALS[k-1];
    float   pulse = isAct ? (1 + 0.06*sin(sgmFrame*0.08)) : 1.0;
    float   amp   = isAct ? pulse : 0.28;
    float   peakH = maxPH * amp * (lk / 24.0);
    color   col   = SGM_KNOT_COLS[k-1];

    // filled area under active peak
    if (isAct) {
      beginShape(); noStroke();
      for (int i = 0; i <= 100; i++) {
        float xx = specX + i/100.0*specW;
        float g  = sgmGauss(xx, xPeak, sigPx);
        fill(red(col), green(col), blue(col), g*110);
        vertex(xx, baseY - g*peakH);
      }
      fill(red(col), green(col), blue(col), 0);
      vertex(specX+specW, baseY); vertex(specX, baseY);
      endShape(CLOSE);
    }

    // curve
    noFill();
    stroke(col, isAct ? 255 : 80);
    strokeWeight(isAct ? 2.0 : 0.8);
    beginShape();
    for (int i = 0; i <= 100; i++) {
      float xx = specX + i/100.0*specW;
      vertex(xx, baseY - sgmGauss(xx, xPeak, sigPx)*peakH);
    }
    endShape();

    // active dashed centre line (manual — JAVA2D has no drawingContext)
    if (isAct) {
      stroke(col, 80); strokeWeight(0.4);
      sgmDashedLine(xPeak, baseY-peakH-2, xPeak, baseY+2, 2, 3);
    }

    // knot glyph above peak tip
    sgmKnotGlyph(xPeak, baseY-peakH-16, k, isAct, col, isAct ? 8 : 5);

    // labels
    textFont(createFont("Courier New", 9));
    textAlign(CENTER, TOP);
    fill(isAct ? col : SGM_MUTED);
    text("k="+k, xPeak, baseY+7);
    fill(isAct ? SGM_BRIGHT : SGM_MUTED);
    text("λ="+SGM_LK_VALS[k-1], xPeak, baseY+17);
  }

  // bottom readouts
  textFont(createFont("Courier New", 8));
  textAlign(LEFT, BOTTOM); fill(SGM_MUTED);
  String dn = (kActive<=3) ? nf(SGM_D_VALS[kActive-1],1,3) : "—";
  text("D("+kActive+")="+dn, specX, py+ph-4);
  textAlign(RIGHT, BOTTOM); fill(SGM_PURPLE);
  String z3 = (kActive<=3) ? nf(SGM_ZETA3*kActive*kActive,1,3) : "—";
  text("ζ(3)·"+kActive+"²="+z3, px+pw-8, py+ph-4);
  textAlign(RIGHT, TOP); fill(kActive>=4 ? SGM_RED : SGM_GREEN);
  text(kActive>=4 ? "HYPERBOLIC":"INTEGRABLE", px+pw-8, py+6);
}

// =============================================================
//  PANEL 02 — SHELL HIERARCHY TELEMETRY
// =============================================================
void sgmPanel02_Shell(int px, int py, int pw, int ph) {
  sgmPanelLabel(px, py, "02", SGM_ORANGE, "SHELL", "HIERARCHY TELEMETRY");

  float cx = px + pw/2.0 - 10;
  float cy = py + ph/2.0 + 10;

  float[][] shellR   = {{ 42,68,94 }};
  color[]   shellCol = { SGM_CYAN, SGM_ORANGE, SGM_PURPLE };
  String[]  shellN   = { "S³","S⁵","S⁹" };
  String[]  shellD   = { "LEPTON","QUARK","NEUTRINO" };
  String[][] shellPts = { {"e","μ","τ"}, {"u/d","s/c","b/t"}, {"ν₁","ν₂","ν₃"} };
  float[][] shellMass = {
    { 0.511,  105.66,    1776.9  },
    { 3.4,    685,       88517   },
    { 0.00097, 0.00871,  0.0496  }
  };
  String[]  shellUnit = { "MeV","MeV","eV" };

  for (int i = 0; i < 3; i++) {
    float r = shellR[0][i] * (1 + 0.018*sin(sgmFrame*0.035+i*1.3)*(0.4+0.6*cartStability));
    noFill();
    stroke(shellCol[i], 55+25*sin(sgmFrame*0.025+i));
    strokeWeight(0.5);
    ellipse(cx, cy, r*2, r*2);

    textFont(createFont("Courier New", 9));
    textAlign(LEFT, CENTER); fill(shellCol[i]);
    text(shellN[i], cx+r+5, cy-(2-i)*14+4);
    textFont(createFont("Courier New", 7));
    fill(SGM_MUTED);
    text(shellD[i], cx+r+5, cy-(2-i)*14+13);

    for (int j = 0; j < 3; j++) {
      float angle = -HALF_PI+(j-1)*0.52+sgmFrame*0.008*(i+1)*0.4;
      noStroke(); fill(shellCol[i], 77+153*cartStability);
      ellipse(cx+r*cos(angle), cy+r*sin(angle), 4, 4);
    }
  }

  // active shell particle readout
  int di = (envFloquetCoupling()>0.66) ? 2 : (envFloquetCoupling()>0.33) ? 1 : 0;
  textFont(createFont("Courier New", 9));
  textAlign(LEFT, TOP);
  for (int i = 0; i < 3; i++) {
    float m = shellMass[di][i];
    String ms = (m<0.01) ? nf(m,1,5) : (m<1) ? nf(m,1,4) : (m<1000) ? nf(m,1,2) : nf(m,1,0);
    fill(shellCol[di]); text(shellPts[di][i], px+8, py+22+i*13);
    fill(SGM_TEXT);     text(" "+ms+" "+shellUnit[di], px+22, py+22+i*13);
  }

  textFont(createFont("Courier New", 8));
  fill(SGM_MUTED); textAlign(LEFT, BOTTOM);
  text("m_geom(1)="+nf(sgmMassGeom(1),1,4)+"e-3", px+8, py+ph-4);
}

// =============================================================
//  PANEL 03 — TORSION–HOLONOMY FIELD OVERLAY
// =============================================================
void sgmPanel03_Torsion(int px, int py, int pw, int ph) {
  sgmPanelLabel(px, py, "03", SGM_TEAL, "TORSION-HOLONOMY", "FIELD OVERLAY");

  float cx = px + pw/2.0 - 18;
  float cy = py + ph/2.0 + 6;
  float baseR = min(pw, ph) * 0.38;

  // orb position on S²
  float theta = cartX * TWO_PI;
  float phi_a = cartY * PI;
  float ox    = baseR * sin(phi_a) * cos(theta);
  float oy    = baseR * cos(phi_a);
  float oz    = baseR * sin(phi_a) * sin(theta);
  float sx    = cx + ox - oz*0.4;
  float sy    = cy - oy - oz*0.2;

  // latitude rings on S²
  noFill();
  for (int i = 1; i <= 3; i++) {
    float lat = i*PI/4;
    float r2  = baseR*sin(lat);
    float ly  = cy - baseR*cos(lat);
    stroke(SGM_MUTED, 33); strokeWeight(0.3);
    ellipse(cx, ly, r2*2, r2*0.56);
  }
  stroke(SGM_MUTED, 45); strokeWeight(0.4);
  ellipse(cx, cy, baseR*2, baseR*2);

  // --- dynamic fiber ring -----------------------------------------
  int   kNow       = sgmGetK();
  float breathe    = 1 + 0.22*sin(sgmFrame*0.06*envFloquetCoupling() + envFloquetCoupling()*PI);
  float ringR      = (10 + 10*envFloquetCoupling()) * breathe;
  float twistAmp   = 0.12 + 0.22*(alpha-1.1)/3.4;
  int   twistFreq  = kNow;  // harmonic = current Beltrami level

  // local perpendicular frame at orb
  float nLen = sqrt(ox*ox+oy*oy+oz*oz);
  float nx = (nLen>0.001) ? ox/nLen : 0;
  float ny = (nLen>0.001) ? oy/nLen : 1;
  float nz = (nLen>0.001) ? oz/nLen : 0;
  float ux = -ny, uy = nx, uz = 0;
  float uLen = sqrt(ux*ux+uy*uy);
  if (uLen>0.001) { ux/=uLen; uy/=uLen; }
  float vx = ny*uz - nz*uy;
  float vy = nz*ux - nx*uz;

  // fibre colour: blue→red with quasi-energy
  float rc = lerp(80, 255, envFloquetQuasienergy());
  float bc = lerp(255, 80, envFloquetQuasienergy());
  color fCol = color(rc, 80, bc);

  int segs = 64;

  // ghost depth rail layers (back to front)
  int railLayers = 6;
  for (int li = railLayers; li >= 0; li--) {
    float tOff   = li * 0.18;
    float radOff = li * 1.8;
    float aFade  = (li==0) ? 1.0 : (1.0-(float)li/railLayers)*0.55;
    float lw     = (li==0) ? 1.8 : 0.5 + 0.3*(1.0-(float)li/railLayers);
    stroke(fCol, 255*aFade); strokeWeight(lw); noFill();
    beginShape();
    for (int i = 0; i <= segs; i++) {
      float a    = TWO_PI*i/segs;
      float warp = ringR*(1 + twistAmp*sin(a*twistFreq + sgmFrame*0.05 + sgmFloqPhase + tOff));
      float rx   = warp*(cos(a)*ux + sin(a)*vx) + radOff*nx;
      float ry   = warp*(cos(a)*uy + sin(a)*vy) + radOff*ny;
      float rz   = warp*(cos(a)*uz + sin(a)*0)  + radOff*nz;
      vertex(sx + rx - rz*0.4, sy - ry - rz*0.2);
    }
    endShape(CLOSE);
  }

  // orb dot
  noStroke(); fill(SGM_AMBER, 190+60*sin(sgmFrame*0.1));
  ellipse(sx, sy, 8, 8);

  // holonomy trail
  sgmHolX[sgmHolIdx] = sx; sgmHolY[sgmHolIdx] = sy;
  sgmHolIdx = (sgmHolIdx+1) % SGM_HOL_MAX;
  if (sgmHolCount < SGM_HOL_MAX) sgmHolCount++;
  if (sgmHolCount > 2) {
    noFill(); stroke(SGM_CYAN, 65); strokeWeight(0.7);
    beginShape();
    for (int i = 0; i < sgmHolCount; i++) {
      int idx = (sgmHolIdx - sgmHolCount + i + SGM_HOL_MAX) % SGM_HOL_MAX;
      vertex(sgmHolX[idx], sgmHolY[idx]);
    }
    endShape();
  }

  // holonomy phase arc — top right corner
  float hp    = cartX * TWO_PI;
  float hSnap = round(hp/HALF_PI)*HALF_PI;
  float drift = abs(hp-hSnap);
  float arcCX = px + pw - 36;
  float arcCY = py + 38;
  noFill(); stroke(drift<0.15 ? SGM_GREEN : SGM_AMBER, 200); strokeWeight(2);
  arc(arcCX, arcCY, 32, 32, -HALF_PI, -HALF_PI+hp%TWO_PI);
  textFont(createFont("Courier New", 8));
  textAlign(CENTER, TOP);
  fill(drift<0.15 ? SGM_GREEN : SGM_AMBER);
  text(drift<0.15 ? "LOCKED":"DRIFT", arcCX, arcCY+22);
  fill(SGM_MUTED);
  text("c₁≈"+nf(hp/TWO_PI,1,2), arcCX, arcCY+32);

  // bottom readouts
  textFont(createFont("Courier New", 8));
  textAlign(LEFT, BOTTOM); fill(SGM_MUTED);
  text("T=α∧dα  k="+kNow+"  twist×"+twistFreq, px+8, py+ph-16);
  fill(SGM_TEAL);
  text("|T|="+nf(envFloquetCoupling()*alpha,1,3), px+8, py+ph-5);
  textAlign(RIGHT, BOTTOM); fill(SGM_MUTED);
  text("φ="+nf(cartX*TWO_PI,1,3), px+pw-8, py+ph-5);
}

// =============================================================
//  PANEL 04 — CONTACT SPECTRAL GEOMETRY
// =============================================================
void sgmPanel04_Contact(int px, int py, int pw, int ph) {
  sgmPanelLabel(px, py, "04", SGM_PURPLE, "CONTACT SPECTRAL", "GEOMETRY");

  float cx    = px + pw/2.0;
  float cy    = py + ph/2.0 + 10;
  int   kNow  = sgmGetK();
  boolean isH = (kNow >= 4);
  float R_tor = min(pw, ph) * 0.30;
  float r_tor = R_tor * 0.38;
  float rot   = sgmFrame * 0.011 * cartStability;

  // depth-layered torus wireframe — 5 ghost layers + solid top
  for (int layer = 5; layer >= 0; layer--) {
    float layA  = (1.0-(float)layer/5) * 0.13;
    float vOff  = layer * 0.08;
    stroke(SGM_MUTED, 255*layA); strokeWeight(0.3); noFill();
    for (int i = 0; i < 36; i++) {
      float u = i/36.0*TWO_PI;
      beginShape();
      for (int j = 0; j <= 14; j++) {
        float v = j/14.0*TWO_PI + vOff;
        PVector p = sgmTorusProj(u, v, R_tor, r_tor, rot, cx, cy);
        vertex(p.x, p.y);
      }
      endShape(CLOSE);
    }
  }
  // solid top-layer wireframe
  stroke(#1A3040, 76); strokeWeight(0.35); noFill();
  for (int i = 0; i < 36; i++) {
    float u = i/36.0*TWO_PI;
    beginShape();
    for (int j = 0; j <= 14; j++) {
      PVector p = sgmTorusProj(u, j/14.0*TWO_PI, R_tor, r_tor, rot, cx, cy);
      vertex(p.x, p.y);
    }
    endShape(CLOSE);
  }

  // T(2,n) orbit curves — glow passes + depth rails
  for (int gen = 1; gen <= 3; gen++) {
    color col    = SGM_KNOT_COLS[gen-1];
    boolean isAct = (gen==kNow && !isH);
    float oSpeed  = sgmFrame * 0.014 * (isH ? 2.2 : 1.0);
    int   glowN   = isAct ? 4 : 1;

    // glow passes (widest first)
    for (int gl = glowN; gl >= 0; gl--) {
      float glA = isAct ? (gl==0 ? 0.95 : 0.12*(1.0-(float)gl/glowN)) : 0.18;
      float glW = isAct ? (gl==0 ? 2.0  : 2.5 + gl*1.8) : 0.55;
      stroke(col, 255*glA); strokeWeight(glW); noFill();
      beginShape();
      for (int i = 0; i <= 220; i++) {
        float phi2   = i/220.0*TWO_PI*gen;
        float theta2 = i/220.0*TWO_PI*2 + oSpeed;
        PVector p = sgmTorusProj(phi2, theta2, R_tor, r_tor, rot, cx, cy);
        vertex(p.x, p.y);
      }
      endShape(CLOSE);
    }

    // trailing depth rails
    for (int dl = 1; dl <= 3; dl++) {
      float depA = (1.0-(float)dl/3)*0.18*(isAct ? 1.0 : 0.4);
      stroke(col, 255*depA); strokeWeight(0.8); noFill();
      beginShape();
      for (int i = 0; i <= 220; i++) {
        float phi2   = i/220.0*TWO_PI*gen;
        float theta2 = i/220.0*TWO_PI*2 + oSpeed + dl*0.04;
        PVector p = sgmTorusProj(phi2, theta2, R_tor, r_tor, rot, cx, cy);
        vertex(p.x, p.y);
      }
      endShape(CLOSE);
    }

    // T(2,n) legend
    textFont(createFont("Courier New", 8));
    textAlign(RIGHT, TOP); fill(col, isAct ? 255 : 77);
    text("T(2,"+gen+")", px+pw-8, py+(gen-1)*12+24);
  }

  // hyperbolic flash overlay
  if (isH) {
    fill(SGM_RED, 255*(0.1+0.06*sin(sgmFrame*0.18)));
    noStroke(); rect(px, py, pw, ph);
    textFont(createFont("Courier New", 10));
    fill(SGM_RED); textAlign(CENTER, BOTTOM);
    text("HYPERBOLIC — k≥4", cx, py+ph-22);
    textFont(createFont("Courier New", 8));
    fill(SGM_MUTED);
    text("TORUS FOLIATION BROKEN", cx, py+ph-11);
  } else {
    textFont(createFont("Courier New", 8));
    fill(SGM_GREEN); textAlign(CENTER, BOTTOM);
    text("INTEGRABLE  k="+kNow+"  TORUS PRESERVED", cx, py+ph-11);
  }

  drawCTCChannelGlyph(px + pw - 38, py + ph - 42, 18);

  // bottom-left readouts
  textFont(createFont("Courier New", 9));
  textAlign(LEFT, BOTTOM); fill(SGM_MUTED);
  text("λ_k="+sgmBeltramiLk(kNow), px+8, py+ph-22);
  fill(SGM_PURPLE);
  text("a="+nf(SGM_A_COEFF,1,4), px+8, py+ph-11);
}

// =============================================================
//  STATUS BAR
// =============================================================
void sgmStatusBar(int bx, int by, int bw, int bh) {
  noStroke(); fill(6, 14, 20); rect(bx, by, bw, bh);
  stroke(#1A2A3A); strokeWeight(1); line(bx, by, bx+bw, by);

  int k = sgmGetK();
  String shell = (envFloquetCoupling()>0.66) ? "S⁹" : (envFloquetCoupling()>0.33) ? "S⁵" : "S³";
  String dn    = (k<=3) ? nf(SGM_D_VALS[k-1],1,3) : "—";

  textFont(createFont("Courier New", 10));
  float ty = by + bh/2.0;
  float tx = bx + 10;
  tx = sgmStatPair(tx, ty, "SHELL",  shell,  62);
  tx = sgmStatPair(tx, ty, "k",      str(k),  32);
  tx = sgmStatPair(tx, ty, "KNOT",   SGM_KNOT_NAMES[min(k-1,3)], 82);
  tx = sgmStatPair(tx, ty, "α",      "1/137", 58);
  tx = sgmStatPair(tx, ty, "ζ(3)",   "1.202",  58);
  tx = sgmStatPair(tx, ty, "REGIME", k>=4 ? "HYPER":"INTEG", 76);
  tx = sgmStatPair(tx, ty, "λ_k",    str(sgmBeltramiLk(k)), 58);
  tx = sgmStatPair(tx, ty, "D", dn, 46);

  textAlign(RIGHT, CENTER);
  fill(ctcChannelActive ? color(255, 150, 170) : SGM_CYAN);
  text("CTC " + ctcZoneLabel + " " + nf(ctcProximity, 1, 2), bx + bw - 10, ty);
}

float sgmStatPair(float tx, float ty, String lbl, String val, float colW) {
  textAlign(LEFT, CENTER);
  fill(SGM_MUTED); text(lbl+" ", tx, ty);
  fill(SGM_CYAN);  text(val, tx + lbl.length()*6.2 + 4, ty);
  fill(#1A2A3A);   text(" | ", tx + colW - 16, ty);
  return tx + colW;
}

// =============================================================
//  HELPERS
// =============================================================

PVector sgmTorusProj(float u, float v, float R, float r, float rot, float cx, float cy) {
  float x  = (R + r*cos(v))*cos(u);
  float y  = (R + r*cos(v))*sin(u);
  float z  = r*sin(v);
  float x2 = x*cos(rot) - z*sin(rot);
  float z2 = x*sin(rot) + z*cos(rot);
  return new PVector(cx + x2 - y*0.3, cy - y*0.5 - z2*0.6);
}

float sgmGauss(float x, float mu, float sig) {
  return exp(-0.5*((x-mu)/sig)*((x-mu)/sig));
}

int sgmGetK() {
  return max(1, min(4, round(1 + ((alpha-1.1)/3.4)*3)));
}

int sgmBeltramiLk(int k) { return k*(k+2); }

float sgmMassGeom(int n) {
  float phi = exp((float)n/6.0 * SGM_FINE);
  return (n+1) * exp(SGM_A_COEFF*n - SGM_D_VALS[n-1]) * phi;
}

void sgmPanelLabel(int px, int py, String num, color col, String w1, String w2) {
  textFont(createFont("Courier New", 9));
  textAlign(LEFT, TOP);
  fill(SGM_MUTED); text(num+" ", px+8, py+6);
  fill(col);       text(w1, px+8+18, py+6);
  fill(SGM_MUTED); text(" "+w2, px+8+18+w1.length()*6.2, py+6);
}

// Manual dashed line — works in JAVA2D (no drawingContext needed)
// dashLen = length of each dash, gapLen = length of each gap
void sgmDashedLine(float x1, float y1, float x2, float y2, float dashLen, float gapLen) {
  float dx   = x2 - x1;
  float dy   = y2 - y1;
  float total = sqrt(dx*dx + dy*dy);
  if (total < 0.001) return;
  float ux = dx/total, uy = dy/total;
  float pos = 0;
  boolean drawing = true;
  while (pos < total) {
    float segLen = drawing ? dashLen : gapLen;
    float end    = min(pos + segLen, total);
    if (drawing) {
      line(x1 + ux*pos, y1 + uy*pos, x1 + ux*end, y1 + uy*end);
    }
    pos += segLen;
    drawing = !drawing;
  }
}

void sgmKnotGlyph(float gx, float gy, int k, boolean active, color col, float sz) {
  pushMatrix(); translate(gx, gy);
  stroke(col, active ? 255 : 102);
  strokeWeight(active ? 1.4 : 0.7);
  noFill();
  if (k==1) {
    ellipse(0, 0, sz*2, sz*2);
  } else if (k==2) {
    ellipse(-sz*.55, 0, sz*1.2, sz*1.2);
    ellipse( sz*.55, 0, sz*1.2, sz*1.2);
  } else if (k==3) {
    float a = sgmFrame*0.04;
    beginShape();
    for (int i = 0; i <= 72; i++) {
      float t = i/72.0*TWO_PI;
      float rr = sz + sz*0.45*cos(3*t);
      vertex(rr*cos(2*t+a), rr*sin(2*t+a));
    }
    endShape(CLOSE);
  } else {
    beginShape();
    for (int i = 0; i <= 90; i++) {
      float t  = i/90.0*TWO_PI;
      float rr = sz*cos(2*t + HALF_PI/2);
      vertex(rr*cos(t), rr*sin(t));
    }
    endShape();
  }
  popMatrix();
}
