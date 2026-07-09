import java.io.File;

String   galaxyName           = "milky_way";
String   galaxyDisplayName    = "Milky Way";
String   galaxyDescription    = "";
float    galaxyFieldCurvature = 0.68;
float    galaxyFloquetCoupling= 0.35;
float    galaxyFieldExcit     = 0.42;
float    galaxyBoundaryPersist= 0.81;
float[][]galaxyGrid           = new float[32][32];
boolean  galaxyLoaded         = false;
String   galaxyStatus         = "No map loaded";
float    galaxyBlend          = 0.35;

String[] galaxyOptions = {"milky_way","andromeda","hubble_deep_field","random_galaxy"};
String[] galaxyLabels  = {"Milky Way","Andromeda","Hubble Deep Field","Random Galaxy"};

ScrollableList menuGalaxySelect;
Slider         sliderGalaxyBlend;
Button         btnReloadGalaxy;
Textfield      fieldGalaxyStatus;

String MAPS_DIR = "";

void galaxyMapInit() {
  MAPS_DIR = sketchPath("maps");
  File mapsDir = new File(MAPS_DIR);
  if (!mapsDir.exists()) {
    galaxyStatus = "maps/ folder not found — run galaxy_bridge.py first";
    println("GalaxyMapLoader: " + galaxyStatus);
    return;
  }
  loadGalaxyMap(galaxyName);
}

void loadGalaxyMap(String name) {
  String path = MAPS_DIR + "/" + name + ".json";
  File f = new File(path);
  if (!f.exists()) {
    galaxyStatus = "Map not found: " + name + ".json";
    println("GalaxyMapLoader: " + galaxyStatus);
    return;
  }
  try {
    String raw = join(loadStrings(path), "\n");
    JSONObject j = parseJSONObject(raw);
    galaxyName            = name;
    galaxyDisplayName     = j.getString("display_name");
    galaxyDescription     = j.getString("description");
    galaxyFieldCurvature  = j.getFloat("field_curvature");
    galaxyFloquetCoupling = j.getFloat("floquet_coupling");
    galaxyFieldExcit      = j.getFloat("field_excitation");
    galaxyBoundaryPersist = j.getFloat("boundary_persistence");
    JSONArray rows = j.getJSONArray("spatial_grid");
    for (int r = 0; r < min(rows.size(), 32); r++) {
      JSONArray cols = rows.getJSONArray(r);
      for (int c = 0; c < min(cols.size(), 32); c++) {
        galaxyGrid[r][c] = cols.getFloat(c);
      }
    }
    galaxyLoaded = true;
    galaxyStatus = "Loaded: " + galaxyDisplayName;
    println("GalaxyMapLoader: " + galaxyStatus +
            " | fc=" + safeNf(galaxyFieldCurvature,1,2) +
            " flq=" + safeNf(galaxyFloquetCoupling,1,2) +
            " ex=" + safeNf(galaxyFieldExcit,1,2) +
            " bp=" + safeNf(galaxyBoundaryPersist,1,2));
    if (fieldGalaxyStatus != null)
      fieldGalaxyStatus.setText(galaxyDisplayName + " — " +
        galaxyDescription.substring(0, min(50, galaxyDescription.length())));
    sendGalaxyToSuperCollider();
  } catch (Exception e) {
    galaxyStatus = "Parse error: " + e.getMessage();
    println("GalaxyMapLoader ERROR: " + galaxyStatus);
    e.printStackTrace();
  }
}

void buildGalaxyControls() {
  int sx      = 876;
  int sy      = 18;
  int sel_w   = 112;
  int sel_gap = 8;
  int gal_x   = sx;
  int contentRight = W - 300;
  int leftX = 20;
  int gap = 8;
  int wCol = (contentRight - leftX - 20 - gap * 3) / 4;
  int moduleX = leftX + (wCol + gap) * 2;
  int moduleW = wCol * 2 + gap;
  int x = moduleX + 12;
  int sw = moduleW - 24;

 cp5.addTextlabel("galaxyTitle")
    .setText("GALAXY")
    .setPosition(gal_x, sy - 10)
    .setColorValue(color(200, 170, 255));

  menuGalaxySelect = cp5.addScrollableList("galaxySelect")
    .setPosition(gal_x, sy)
    .setSize(sel_w, 88)
    .setBarHeight(16)
    .setItemHeight(14)
    .addItems(galaxyLabels)
    .setValue(0)
    .setLabel("Galaxy");

  int by = H - 132;

  sliderGalaxyBlend = cp5.addSlider("galaxyBlendAmt")
    .setPosition(x, by)
    .setSize(sw, 11)
    .setRange(0.0, 1.0)
    .setValue(galaxyBlend)
    .setLabel("Galaxy Blend")
    .setColorBackground(color(30))
    .setColorForeground(color(100, 70, 180))
    .setColorActive(color(150, 110, 240))
    .setColorCaptionLabel(color(200));
  styleSliderLabel("galaxyBlendAmt");

  btnReloadGalaxy = cp5.addButton("RELOADGALAXY")
    .setPosition(x, by + 36)
    .setSize(sw, 14)
    .setLabel("RELOAD MAP")
    .setColorBackground(color(55, 35, 80))
    .setColorForeground(color(90, 60, 130))
    .setColorActive(color(140, 100, 200));

  fieldGalaxyStatus = cp5.addTextfield("galaxyStatusField")
    .setPosition(x, by + 14)
    .setSize(sw, 14)
    .setText("No map loaded")
    .setAutoClear(false)
    .setLabel("")
    .setColorBackground(color(18))
    .setColorForeground(color(60))
    .setColorActive(color(60));
}

void drawGalaxyInlineStatus(int x, int y, int w, int h) {
  if (w < 90 || h < 24) return;
  pushStyle();
  noStroke();
  fill(10, 8, 22, 150);
  rect(x, y, w, h, 4);
  fill(170, 140, 220);
  textFont(createFont("Courier New", 8));
  textAlign(LEFT, TOP);
  text("GALAXY", x + 5, y + 4);
  int bx = x + 47;
  int bw = max(20, w - 70);
  fill(26, 18, 42, 190);
  rect(bx, y + 5, bw, 7, 3);
  fill(110, 80, 190, 190);
  rect(bx, y + 5, bw * constrain(galaxyBlend, 0, 1), 7, 3);
  fill(galaxyLoaded ? color(90, 220, 160) : color(220, 130, 70));
  ellipse(x + w - 12, y + 8, 7, 7);
  fill(150, 135, 190);
  textAlign(LEFT, TOP);
  text(galaxyLoaded ? galaxyDisplayName : "not loaded", x + 5, y + 15);
  textAlign(RIGHT, TOP);
  text(safeNf(galaxyBlend * 100, 1, 0) + "%", x + w - 22, y + 15);
  popStyle();
}

void drawGalaxyLowerBand() {
  int contentRight = W - 300;
  int leftX = 20;
  int gap = 8;
  int wCol = (contentRight - leftX - 20 - gap * 3) / 4;
  int moduleX = leftX + (wCol + gap) * 2;
  int moduleW = wCol * 2 + gap;
  drawGalaxyInlineStatus(moduleX + 12, H - 162, moduleW - 24, 36);
}

void galaxySelect(int val) {
  if (val >= 0 && val < galaxyOptions.length) {
    loadGalaxyMap(galaxyOptions[val]);
  }
}

void galaxyBlendAmt(float val) {
  galaxyBlend = constrain(val, 0, 1);
}

void RELOADGALAXY(int val) {
  loadGalaxyMap(galaxyName);
  galaxyStatus = "Reloaded: " + galaxyDisplayName;
}

void sendGalaxyToSuperCollider() {
  if (!galaxyLoaded || oscP5 == null || supercollider == null) return;
  OscMessage m = new OscMessage("/rdf/galaxy");
  m.add(galaxyFieldCurvature);
  m.add(galaxyFloquetCoupling);
  m.add(galaxyFieldExcit);
  m.add(galaxyBoundaryPersist);
  m.add(galaxyBlend);
  m.add((float) indexOfGalaxy(galaxyName));
  try { oscP5.send(m, supercollider); }
  catch (Exception e) { println("Galaxy OSC send failed: " + e); }
}

int indexOfGalaxy(String name) {
  for (int i = 0; i < galaxyOptions.length; i++)
    if (galaxyOptions[i].equals(name)) return i;
  return 0;
}

void drawGalaxyPanel(int x, int y, int w, int h) {
  if (w < 80 || h < 60) return;
  fill(7, 5, 16, 232);
  stroke(100, 70, 180, 170);
  rect(x, y, w, h, 9);
  fill(200, 170, 255);
  textSize(9);
  textAlign(LEFT, TOP);
  text("GALAXY FIELD MAP", x + 9, y + 7);
  if (!galaxyLoaded) {
    fill(180, 100, 100);
    text(galaxyStatus, x + 9, y + 24);
    return;
  }
  fill(230, 220, 255);
  textSize(11);
  text(galaxyDisplayName, x + 9, y + 22);
  fill(140, 130, 160);
  textSize(8);
  String desc = galaxyDescription;
  if (desc.length() > 55) desc = desc.substring(0, 52) + "...";
  text(desc, x + 9, y + 36);
  int gridX = x + 9;
  int gridY = y + 50;
  int gridW = min(w - 130, 96);
  int gridH = min(h - 80, 96);
  if (gridW > 20 && gridH > 20) {
    noStroke();
    float cw = gridW / 32.0;
    float ch = gridH / 32.0;
    for (int r = 0; r < 32; r++) {
      for (int c = 0; c < 32; c++) {
        float v = galaxyGrid[r][c];
        fill(int(30 + v*120), int(15 + v*80), int(60 + v*180));
        rect(gridX + c*cw, gridY + r*ch, cw+0.3, ch+0.3);
      }
    }
    noFill();
    stroke(100, 70, 180, 120);
    rect(gridX, gridY, gridW, gridH);
  }
  int rx = gridX + gridW + 10;
  int ry = gridY;
  int rw = w - (rx - x) - 9;
  drawMiniReadout(rx, ry,      rw, "field curv",  galaxyFieldCurvature,  safeNf(galaxyFieldCurvature,1,2));
  drawMiniReadout(rx, ry + 24, rw, "flq couple",  galaxyFloquetCoupling, safeNf(galaxyFloquetCoupling,1,2));
  drawMiniReadout(rx, ry + 48, rw, "excite",      galaxyFieldExcit,      safeNf(galaxyFieldExcit,1,2));
  drawMiniReadout(rx, ry + 72, rw, "boundary",    galaxyBoundaryPersist, safeNf(galaxyBoundaryPersist,1,2));
  drawMiniReadout(rx, ry + 96, rw, "blend",       galaxyBlend,           safeNf(galaxyBlend,1,2));
  int bx = x + 9;
  int by2 = y + h - 18;
  fill(18, 12, 32, 180);
  noStroke();
  rect(bx, by2, w - 18, 10, 3);
  fill(100, 70, 180, 160);
  rect(bx, by2, (w - 18) * galaxyBlend, 10, 3);
  fill(160, 140, 200);
  textSize(8);
  textAlign(LEFT, CENTER);
  text("blend " + safeNf(galaxyBlend*100,1,0) + "%", bx + 4, by2 + 5);
  fill(galaxyLoaded ? color(90, 220, 160) : color(220, 130, 70));
  noStroke();
  ellipse(x + w - 14, y + 18, 7, 7);
}

void drawGalaxyImagePanel(int x, int y, int w, int h) {
  if (w < 80 || h < 60) return;
  fill(7, 5, 16, 232);
  stroke(100, 70, 180, 170);
  rect(x, y, w, h, 9);
  fill(200, 170, 255);
  textSize(9);
  textAlign(LEFT, TOP);
  text("GALAXY FIELD MAP", x + 9, y + 7);
  fill(galaxyLoaded ? color(90, 220, 160) : color(220, 130, 70));
  noStroke();
  ellipse(x + w - 14, y + 18, 7, 7);

  if (!galaxyLoaded) {
    fill(180, 100, 100);
    text(galaxyStatus, x + 9, y + 26);
    return;
  }

  fill(230, 220, 255);
  textSize(11);
  text(galaxyDisplayName, x + 9, y + 22);
  fill(140, 130, 160);
  textSize(8);
  String desc = galaxyDescription;
  if (desc.length() > 55) desc = desc.substring(0, 52) + "...";
  text(desc, x + 9, y + 36);

  int gridX = x + 9;
  int gridY = y + 52;
  int gridW = min(w - 96, h - 66);
  int gridH = gridW;
  float mn = 999;
  float mx = -999;
  for (int r = 0; r < 32; r++) {
    for (int c = 0; c < 32; c++) {
      float gv = galaxyGrid[r][c];
      mn = min(mn, gv);
      mx = max(mx, gv);
    }
  }
  if (gridW > 20) {
    noStroke();
    float cw = gridW / 32.0;
    float ch = gridH / 32.0;
    for (int r = 0; r < 32; r++) {
      for (int c = 0; c < 32; c++) {
        float v = galaxyDisplayValue(galaxyGrid[r][c], mn, mx);
        fill(galaxyColor(v));
        rect(gridX + c*cw, gridY + r*ch, cw+0.3, ch+0.3);
      }
    }
    noFill();
    stroke(100, 70, 180, 120);
    rect(gridX, gridY, gridW, gridH);
  }

  int rx = gridX + gridW + 10;
  int ry = gridY;
  int rw = w - (rx - x) - 9;
  drawMiniReadout(rx, ry,      rw, "curv", galaxyFieldCurvature,  safeNf(galaxyFieldCurvature,1,2));
  drawMiniReadout(rx, ry + 24, rw, "flq",  galaxyFloquetCoupling, safeNf(galaxyFloquetCoupling,1,2));
  drawMiniReadout(rx, ry + 48, rw, "bound", galaxyBoundaryPersist, safeNf(galaxyBoundaryPersist,1,2));
}

float galaxyDisplayValue(float v, float mn, float mx) {
  float span = max(0.0001, mx - mn);
  float n = constrain((v - mn) / span, 0, 1);
  n = pow(n, galaxyName.equals("random_galaxy") ? 0.42 : 0.62);
  return constrain(n * 1.12, 0, 1);
}

color galaxyColor(float v) {
  color c0 = color(8, 5, 22);
  color c1 = color(42, 18, 85);
  color c2 = color(132, 62, 170);
  color c3 = color(245, 160, 95);
  color c4 = color(250, 232, 185);
  if (v < 0.35) return lerpColor(c0, c1, v / 0.35);
  if (v < 0.68) return lerpColor(c1, c2, (v - 0.35) / 0.33);
  if (v < 0.90) return lerpColor(c2, c3, (v - 0.68) / 0.22);
  return lerpColor(c3, c4, (v - 0.90) / 0.10);
}

void applyGalaxyTopologyToField() {
  if (!galaxyLoaded || galaxyBlend < 0.01) return;
  foundationalCoherence = lerp(foundationalCoherence,
                               galaxyFieldCurvature,
                               galaxyBlend * 0.4);
  foundationalPsiDensity = lerp(foundationalPsiDensity,
                                galaxyFieldExcit,
                                galaxyBlend * 0.25);
}
