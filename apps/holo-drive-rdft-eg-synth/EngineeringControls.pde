// RDFT Engineering Controls - field parameter overlay
// Retired MLX camera controls have been replaced with Ocean field controls.
// orbitLockStrength is declared in the main sketch; not redeclared here.

float oceanEngCurrentGain = 0.5;   // multiplier on ocean current -> SC drive
float oceanEngSwellAmp    = 0.5;   // swell amplitude bias
float oceanEngBreakRate   = 0.5;   // ocean break event probability bias
float orbitEccentricityBias = 0.3;
float orbitResonanceDrive = 0.4;
float floquetDrive = 0.4;
float floquetInstability = 0.2;
float quasiEnergyBias = 0.5;
int engDragSlider = -1;
int engDragPanelX = 0;
int engDragBarW = 0;
boolean orbitLockManual = false;

void drawEngineeringControls() {
  int panelX = PX4;
  int y = PANEL_TOP - 10;
  fill(0, 180);
  rect(panelX - 20, 10, 260, 340);
  fill(255);
  textSize(13);
  text("FIELD CONTROL", panelX, y);
  y += 30;
  drawEngineeringSlider(panelX, y, "OCEAN CURRENT", oceanEngCurrentGain); y += 40;
  drawEngineeringSlider(panelX, y, "OCEAN SWELL", oceanEngSwellAmp); y += 40;
  drawEngineeringSlider(panelX, y, "OCEAN BREAK", oceanEngBreakRate); y += 60;
  drawEngineeringSlider(panelX, y, "ORBIT ECC", orbitEccentricityBias); y += 40;
  drawEngineeringSlider(panelX, y, "RESONANCE", orbitResonanceDrive); y += 40;
  drawEngineeringSlider(panelX, y, "LOCK", orbitLockStrength); y += 60;
  drawEngineeringSlider(panelX, y, "FLOQUET", floquetDrive); y += 40;
  drawEngineeringSlider(panelX, y, "INSTABILITY", floquetInstability); y += 40;
  drawEngineeringSlider(panelX, y, "QUASI ENERGY", quasiEnergyBias);
}

void drawEngineeringSlider(int x, int y, String label, float value) {
  fill(255);
  text(label, x, y);
  noStroke();
  fill(60);
  rect(x, y + 8, 180, 10);
  fill(0, 200, 210);
  rect(x, y + 8, constrain(value, 0, 1) * 180, 10);
  fill(255);
  text(safeNf(value, 1, 2), x + 190, y + 18);
}
