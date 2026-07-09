/**
 * PI 4 / PROCESSING 4.5 COMPATIBLE PACKAGE
 * Open this folder directly in Processing:
 *   HOLO_DRIVE_RDFT_EG_SYNTH/HOLO_DRIVE_RDFT_EG_SYNTH.pde
 * Folder name and main .pde name now match, so Processing will not open a blank sketch.
 * Single-window JAVA2D build. No popup windows or secondary PApplet launchers.
 */

import controlP5.*;

import netP5.*;
import oscP5.*;
import java.io.FileWriter;
import java.io.File;
import java.io.PrintWriter;

/**
 * RecursiveDifferentiation.pde
 * Processing companion for RDF SuperCollider sketch:
 * RDF panels + Orbital visualizer + Arduino MAX7219 modes + OSC to SuperCollider
 * Matches SC OSC payload: synth volumes, mode source, and environmental controls
 *
 * Required libraries (Sketch -> Import Library -> Manage Libraries):
 *   controlP5   (by Andreas Schlegel)
 *   oscP5       (by Andreas Schlegel)
 *
 * NO_ARDUINO mode: set true to run without any Arduino connected.
 * OSC/synth and RDF visuals work normally; CONNECT/PUSH buttons are disabled.
 */
final boolean NO_ARDUINO = true;  // UDP/OSC-only build: no Arduino Serial dependency
final boolean BRAINSTATE_LAYER_ENABLED = false;  // Future replacement slot for BCI brainstate input.

// OSC / SuperCollider
OscP5 oscP5;
NetAddress supercollider;

// MIDI pilot input: maps a USB keyboard onto the root-frequency control.
final boolean MIDI_PILOT_ENABLED = true;
MidiPilotHelper midiPilotHelper = null;
boolean midiPilotConnected = false;
boolean midiLaunchpadDetected = false;
String midiPilotStatus = "MIDI: no keyboard";
String launchpadLastAction = "";
String launchpadActiveMode = "MAIN PRESET";
int launchpadActiveSlot = 0;
int launchpadActiveColumn = 0;
float launchpadActiveVelocity = 0.0;
int launchpadActiveFrame = -9999;
int launchpadActivePage = 0;
int launchpadLastControl = -1;
float launchpadLastValue = 0.0;
int launchpadPitchShiftSemis = 0;
float launchpadPolyFilterTone = 0.45;
final int LAUNCHPAD_ROW_AUTORESTORE_FRAMES = 72;   // 3s at the 24 fps GUI cap
final int LAUNCHPAD_NOTE_AUTORELEASE_FRAMES = 72; // safety for toggle-style custom pads
int[] launchpadRowHeld = new int[9];
int[] launchpadRowLastFrame = new int[9];
boolean[] launchpadRowRestoreArmed = new boolean[9];
int[] launchpadRowRestorePage = new int[9];
float[] launchpadRowRestoreA = new float[9];
float[] launchpadRowRestoreB = new float[9];
float[] launchpadRowRestoreC = new float[9];
float[] launchpadRowRestoreD = new float[9];
float[] launchpadRowRestoreE = new float[9];
boolean[] launchpadRowRestoreT = new boolean[9];
boolean[] launchpadRestoreDroneOn = new boolean[9];
boolean[] launchpadRestoreArpOn = new boolean[9];
boolean[] launchpadRestoreGlassOn = new boolean[9];
boolean[] launchpadRestoreChoirOn = new boolean[9];
boolean[] launchpadRestoreEcoChirpOn = new boolean[9];
boolean[] launchpadRestoreEcoCallOn = new boolean[9];
boolean[] launchpadRestoreEcoGrowthOn = new boolean[9];
boolean[] launchpadRestoreEcoFissureOn = new boolean[9];
boolean[] launchpadRestoreEgProbeOn = new boolean[9];
boolean[] launchpadRestoreMidiPolyOn = new boolean[9];
float[] launchpadRestoreDroneVol = new float[9];
float[] launchpadRestoreArpVol = new float[9];
float[] launchpadRestoreArpRate = new float[9];
float[] launchpadRestoreGlassVol = new float[9];
float[] launchpadRestoreChoirVol = new float[9];
float[] launchpadRestoreEcoChirpLevel = new float[9];
float[] launchpadRestoreEcoCallLevel = new float[9];
float[] launchpadRestoreEcoGrowthLevel = new float[9];
float[] launchpadRestoreEcoFissureLevel = new float[9];
float[] launchpadRestoreEgProbeLevel = new float[9];
float[] launchpadRestoreMidiPolyVol = new float[9];
float[] launchpadRestoreSolarVol = new float[9];
float[] launchpadRestoreOceanCurrent = new float[9];
float[] launchpadRestoreOceanSwell = new float[9];
float[] launchpadRestoreOrbSensitivity = new float[9];
float[] launchpadRestoreMasterAmp = new float[9];
boolean[] launchpadMappedNoteFromLaunchpad = new boolean[128];
int[] launchpadMappedNoteLastFrame = new int[128];
int midiHeldCount = 0;
int midiLastRootNote = -1;
float midiLastVelocity = 0.0;
boolean midiPolyMode = false;
boolean midiPolyModePrev = false;
boolean[] midiPolyActiveNotes = new boolean[128];
float[] midiPolyVelocities = new float[128];
float midiPolyMemoryCharge = 0.0;
float midiPolyHarmonicDensity = 0.0;
float midiPolyChordSpread = 0.0;
float midiPolyReleasePressure = 0.0;
float midiPolyRootTargetFreq = 55.0;
float midiPolyLastRootApplied = 55.0;
int midiPolyTriggerCount = 0;
int midiPolyReleaseCount = 0;

// Polyphonic field-excitation diagnostics for CSV logging.
float rootFreqRaw = 55.0;
float rootFreqSmoothed = 55.0;
float rootFreqPrevious = 55.0;
float rootFreqDelta = 0.0;
float rootFreqPrevDelta = 0.0;
float rootFreqAccel = 0.0;
float rootFreqSlewRate = 0.0;
float rootFreqTarget = 55.0;
int rootFreqJumpEvent = 0;
int rootFreqExcursion = 0;
// Keyboard interaction detectors — semitone-relative (register-independent).
final float KB_EXCURSION_SEMITONES = 7.0;   // a fifth away from baseline = excursion
final float KB_JUMP_SEMITONES      = 3.0;   // >= minor third between logged frames = jump
final float KB_BASELINE_SMOOTH     = 0.02;  // slow EMA per logged update (~10-25 s half-life)
final float KB_PRESSURE_GATE       = 0.55;  // harmonic pressure gate for escape/capture
float rootFreqBaselineSlow = 0;             // running tonal center estimate (Hz)
int prevRootFreqExcursion = 0;
int rootFreqExcursionEvent = 0;
boolean polyFieldDiagInitialized = false;
float rootFreqExcursionPeak = 0.0;
float rootFreqExcursionStartMs = -1.0;
float rootFreqExcursionDuration = 0.0;
float rootFreqExcursionBaseline = 55.0;
float rootFreqReturnError = 0.0;
float harmonicPressure = 0.0;
float harmonicPressureSmoothed = 0.0;
float harmonicPressureDelta = 0.0;
float harmonicPressurePeak = 0.0;
int harmonicPressureEvent = 0;
float freqFieldCoupling = 0.0;
float freqEntropyDrive = 0.0;
float freqStabilityDrive = 0.0;
float freqFloquetDrive = 0.0;
float freqOrbitDrive = 0.0;
int keyboardEvent = 0;
String keyboardEventType = "none";
int prevMidiPolyTriggerCount = 0;
int prevMidiPolyReleaseCount = 0;
float prevCartStabilityForFreq = 0.0;
int harmonicEscapeEvent = 0;
int harmonicCaptureEvent = 0;
int sweepLegDiag = -999;
boolean sweepLegKeyboardActive = false;
float sweepLegMaxRootFreq = 0.0;
float sweepLegHarmonicPressureSum = 0.0;
int sweepLegHarmonicPressureSamples = 0;
int sweepLegFreqExcursionCount = 0;
float hopfFiberPhase = 0.0;
float hopfPrevFiberPhase = 0.0;
float hopfFiberWinding = 0.0;
float hopfFiberDelta = 0.0;
float hopfBaseX = 0.0;
float hopfBaseY = 0.0;
float hopfBaseZ = 1.0;
float hopfThreadPhase = 0.0;
float hopfPrevThreadPhase = 0.0;
float hopfThreadWinding = 0.0;
float hopfLinkProxy = 0.0;
float hopfActivityProxy = 0.0;
boolean hopfDiagInitialized = false;



// UDP/OSC-only build. Arduino Serial has been fully removed for the Raspberry Pi MLX90640 pipeline.
boolean ledConnected      = false;
RDFSpecializedNodesWindow nodesWin = null;
boolean nodesWinOpen      = false;
RDFMaterialTopologyWindow materialWin = null;
boolean materialWinOpen   = false;
boolean connected = false;
boolean solarAffectsSynth = false;    // solar data is visual by default; this gates the solar drone/audio layer
boolean oceanAffectsSynth = true;     // ocean/tide data supplies the low-gain sensing layer
float solarDroneVolume = 0.035;  // quieter default; SC also hard-limits solar gain
float oceanFieldVolume = 0.010;  // ocean excitation stays intentionally subtle
float oceanCurrentBias = 0.5;   // biases SC ocean current floor 0-1
float oceanSwellDepth  = 0.5;   // biases swell body amplitude 0-1
float oceanVolumeBias  = 0.010; // master ocean synth volume
SolarDataBridge solarBridge = null;
OceanDataBridge oceanBridge = null;
SurfaceDataBridge surfaceBridge = null;  // Imported/synthetic manifold surface overlay for orbit panel, UDP :5056
int currentMode = 0;
String statusMsg = "Not connected";

// Window/Layout
final int W = 1540;
final int H = 1040;
final boolean CHLADNI_SPHERE_UI = true;

// Cinematic control surface: square RDFT diagnostics at left, sphere as the
// primary interface, action/mix at right, engineering at far right.
final int CH_MARGIN = 12;
final int CH_LEFT_X = 12;
final int CH_LEFT_W = 190;
final int CH_SIDE_SIZE = 160;
final int CH_MAIN_X = CH_LEFT_X + CH_LEFT_W + 16;
final int CH_SPHERE_X = CH_MAIN_X;
final int CH_SPHERE_Y = 82;
final int CH_SPHERE_SIZE = 720;
final int CH_RIGHT_X = CH_SPHERE_X + CH_SPHERE_SIZE + 16;
final int CH_RIGHT_W = 300;
final int CH_ENG_X = CH_RIGHT_X + CH_RIGHT_W + 14;
final int CH_ENG_W = W - CH_ENG_X - CH_MARGIN;
final int CH_BOTTOM_Y = CH_SPHERE_Y + CH_SPHERE_SIZE + 14;
final int CH_BOTTOM_H = H - CH_BOTTOM_Y - 48;
final int CH_MAIN_W = W - CH_MAIN_X - 14;
final int CH_MODE_Y = CH_SPHERE_Y;
final int CH_MODE_H = CH_SPHERE_SIZE;
final int CH_SPHERE_H = CH_SPHERE_SIZE;

int chladniSelectedMode = 5;
final int CH_VIS_MAIN = 0;
final int CH_VIS_FOUNDATION_STREAM = 1;
int chladniVisualMode = CH_VIS_MAIN;
final int FOUNDATION_TOUCH_MAX = 18;
float[] foundationTouchX = new float[FOUNDATION_TOUCH_MAX];
float[] foundationTouchY = new float[FOUNDATION_TOUCH_MAX];
float[] foundationTouchStrength = new float[FOUNDATION_TOUCH_MAX];
int[] foundationTouchFrame = new int[FOUNDATION_TOUCH_MAX];
int foundationTouchHead = 0;

// Performance shell layout: square panels reduce pixel work on Raspberry Pi 400
// and keep the main RDF visualizer from stretching into oversized rectangles.
final int PANEL_TOP = 118;
final int PANEL_H = 220;
final int PANEL_W = 220;
final int GAP = 12;
final int BTM_H = 100;
final int GRID = 100;


final int PX0 = 20;
final int PX1 = PX0 + PANEL_W + GAP;
final int PX2 = PX1 + PANEL_W + GAP;
final int PX3 = PX2 + PANEL_W + GAP;
final int PX4 = PX3 + PANEL_W + GAP;

// Sweep Cache
final int SWEEP_STEPS = 60;
float[][][] sweepCache;
float[] sweepAlphas;

int sweepIdx = 0;
int sweepDir = 1;
int animFrameCounter = 0;
final int ANIM_SPEED = 2;

// RDF Core Parameters
int depth = 3;
float alpha = 2.0;

boolean animating = false;
volatile boolean sweepReady = false;
volatile boolean sweepBuilding = false;

float[][] dominant;
float[][] combined;
float[] cross1D;
float[][][] layerCache = null;

float[][] lastMatrixFrame = new float[8][8];

// Orbital Parameters
float orb_G0 = 1.0;
float orb_M = 1.0;
float orb_gamma = -0.65;

float orb_x = 1.2;
float orb_y = 0.0;
float orb_vx = 0.0;
float orb_vy = 0.85;

final float ORB_DT = 0.008;
final int ORB_STEPS_PER_FRAME = 6;
final float ORB_BOUND = 2.2;

final int TRAIL_LEN = 300;
float[] trailX = new float[TRAIL_LEN];
float[] trailY = new float[TRAIL_LEN];
float[] trailPhi = new float[TRAIL_LEN];

int trailHead = 0;
int trailCount = 0;

boolean hyperbolicMode = false;
boolean skipHeavyPanels = false;

int logFrameCounter = 0;


NetAddress surfaceControl;  // retained for compatibility; raw UDP below controls surface_sender.py
java.net.DatagramSocket surfaceUdpSocket = null;
java.net.InetAddress surfaceUdpHost = null;
final int SURFACE_CONTROL_PORT = 5057;
boolean surfaceControlReady = false;
String surfaceControlStatus = "SURFACE CTRL: INIT";

// Clean area-independence test: same depth band on every rung, alpha width varies.
// This removes the shifted-depth-center confound from the wider 1.5 / 3 / 6 run.
final float[][] LADDER_PRESET = {
  {2.75, 3.5, 3, 5, 1.5},
  {2.0,  3.5, 3, 5, 3},
  {2.0,  4.0, 3, 5, 4}
};
final int   LADDER_PAIRS = 5;
final float LADDER_LEGT = 6.0;
final float LADDER_DWELL = 0.5;
final int   LADDER_SETTLE_MS = 3000;
boolean ladderActive = false;
boolean ladderSurfAck = false;
int     ladderRung = 0;
int     ladderStage = 0;       // 0 launch, 1 batch running, 2 settling
int     ladderStageMs = 0;
String  ladderStatus = "ladder: idle";

// ── FTLE shadow particle (Benettin algorithm) ──────────────────
// A second particle runs the identical force law from a position
// offset by ftleEpsilon.  After each step the shadow is rescaled
// back onto the epsilon sphere (renormalisation) and the log of
// the stretch factor is accumulated.  The running mean is the
// finite-time Lyapunov exponent in natural-units per time-step.
// Positive  →  chaotic / diverging orbit
// Near zero →  quasi-periodic / regular
// Negative  →  converging / attracting

float shad_x        = 1.2 + 1e-5;
float shad_y        = 0.0;
float shad_vx       = 0.0;
float shad_vy       = 0.85;
final float FTLE_EPS = 1e-5;
float ftleAccum     = 0.0;
int   ftleSteps     = 0;

// Colors
color[] cmap_plasma;
color[] cmap_viridis;
color[] cmap_inferno;

color[] depthColors = new color[]{
  color(60, 120, 255),
  color(100, 90, 255),
  color(140, 80, 255),
  color(190, 70, 240),
  color(230, 60, 210),
  color(255, 80, 160),
  color(255, 110, 120),
  color(255, 140, 80),
  color(255, 180, 60),
  color(220, 220, 60),
  color(140, 255, 120),
  color(80, 255, 200)
};

// GUI
ControlP5 cp5;

Slider sliderDepth;
Slider sliderAlpha;
Slider sliderGamma;
Slider sliderRootFreq;
Slider sliderAmp;
Slider sliderReverb;
Slider sliderOrbSensitivity;
Slider sliderSolarVolume;
Textfield fieldDepth;
Textfield fieldAlpha;
Textfield fieldGamma;
Textfield fieldRootFreq;
Textfield fieldSweepAlphaTarget;
Textfield fieldSweepDepthTarget;
Textfield fieldSweepDuration;
Button btnApplyParams;
ScrollableList menuScale;
ScrollableList menuModSource;
Toggle toggleDrone;
Toggle toggleArp;
Toggle toggleGlass;
Toggle toggleGhost;
Toggle toggleEcoChirp;
Toggle toggleEcoCall;
Toggle toggleEcoGrowth;
Toggle toggleEcoFissure;
Toggle toggleEGProbe;
Toggle toggleMidiPoly;

Button btnCompute;
Button btnAnimate;
Button btnConnect;
Button btnPush;
Button btnResetOrbit;
Button btnLadder;
Button btnSolar;
Button btnDroneSpawn;
Button btnDroneKill;
Button btnNodes;
Button btnMaterial;
Button btnCloseViews;
Button btnAdiabaticSweep;
Button btnBerryReset;
Button btnRecordData;
Button btnFieldConfig;
Button btnPetaminxMode;

// ── Electrogravity globals (computed each frame, read by FieldConfigPanel) ──
// emergentEG: the baseline factor from α/depth/mass — always running.
// effectiveVoltage: emergentEG contribution + injected voltage perturbation.
// electroGravityFactor: final multiplier applied in orbEffectiveGravity().
float emergentEG           = 1.0;
float effectiveVoltage     = 0.0;
float electroGravityFactor = 1.0;

// Controlled EG probe: independent of the FieldConfig/UFO window.
// It briefly opens an EG reduction window when orbital, Floquet, ECO, and
// galaxy conditions align, then cools down so the field can re-normalize.
boolean egProbeActive = false;
float egProbeGateScore = 0.0;
float egProbeDepth = 0.0;
float egProbeTarget = 1.0;
float egProbeBaseFactor = 1.0;
float egProbeCooldownRemaining = 0.0;
int egProbeTriggerCount = 0;
int egProbeEnterMs = -999999;
int egProbeLastTriggerMs = -999999;
final float EG_PROBE_GATE_THRESHOLD = 0.62;
final int EG_PROBE_HOLD_MS = 4400;
final int EG_PROBE_COOLDOWN_MS = 18000;

// ── PhiFieldEngine globals (§0–§12 of the phi field derivation document) ─────
PhiFieldEngine phiEngine = new PhiFieldEngine();
float phi_field_value    = 0.0;   // φ(r) at current orbital radius  (§5)
float phi_residual       = 0.0;   // F = φ + ½|∇φ|² + A·e^(−2φ)·S  (§0)
float phi_gain           = 1.0;   // G_local = 1 − 2A·e^(−2φ)·S     (§8)
float phi_threshold_prox = 0.0;   // normalised proximity to G_local=0 (§12)

// ── Holographic surface projection physics ────────────────────────────────────
// These globals carry the surface boundary's causal influence into the phi field.
// The TPMS surface is the boundary onto which the RDFT field is projected.
// Under Landauer's principle, the surface curvature sets a local information
// density floor — high curvature = more compressed information = higher source S.
// Under the quantum eraser analogy, high-curvature regions force path
// distinguishability (BELTRAMI_SHEARED), low-curvature regions allow coherence.
//
// surfaceZ:         normalised elevation at orbital position [0,1]
// surfaceCurv:      normalised Gaussian curvature at orbital position [0,1]
// surfaceDepth:     TPMS recursion depth layer at orbital position [1,7]
// landauerS:        Landauer information density contribution to phi field S
// landauerCoherence: coherence suppression from curvature (eraser analogy)
// surfaceReady:     true when a valid surface is being received
float surfaceZ         = 0.0;
float surfaceCurv      = 0.0;
int   surfaceDepthAt   = 1;
float landauerS        = 0.0;   // curvature → information density → added to phiEngine S
float landauerCoherence = 1.0;  // 1=fully coherent (flat), 0=fully erased (high curv)
boolean surfaceReady   = false;

// Panel screen coordinates — set once in drawOrbitalPanel, read in updateSurfacePhysics
// so the physics update doesn't need to know panel layout details.
int orbPanelX = 0, orbPanelY = 0, orbPanelW = 0, orbPanelH = 0;

FieldConfigPanel fcPanel   = null;
boolean fcPanelOpen        = false;


// Data logging + quantitative mode globals.
// Logs are written beside the sketch when Processing is run.
PrintWriter oscLogWriter;
String oscLogFilename = "";
boolean oscLoggingEnabled = false;
boolean recordDataRequested = false;
final int LOG_EVERY_N_FRAMES = 12;      // about 5 Hz at 60 FPS; lighter on Raspberry Pi
final int LOG_FLUSH_EVERY_N_LINES = 20; // buffered logging avoids disk stalls
int logLineCounter = 0;
int metricUpdateDivider = 0;
final int METRIC_UPDATE_EVERY_N_FRAMES = 6;
final int MAIN_PANEL_SAMPLE_STEP = 2;  // draw 50x50 blocks instead of 100x100 pixels; data is unchanged
float audioDiagPsiGhostProb = 0.0;
int audioDiagGhostTriggerCount = 0;
float audioDiagLastGhostAge = -1.0;
float audioDiagNextGlassAllowedTime = 0.0;
int audioDiagActualGlassTriggerCount = 0;
float audioDiagFloquetGEffLive = 0.0;
int audioDiagEcoChirpTriggerCount = 0;
float audioDiagEcoChirpLastAge = -1.0;
int audioDiagEcoCallTriggerCount = 0;
float audioDiagEcoCallLastAge = -1.0;
int audioDiagEcoGrowthTriggerCount = 0;
float audioDiagEcoGrowthLastAge = -1.0;
int audioDiagEcoFissureTriggerCount = 0;
float audioDiagEcoFissureLastAge = -1.0;
int audioDiagLastFrame = -1;
float scDiagRootFreq = 55.0;
float scDiagDroneVolume = 0.20;
float scDiagArpVolume = 0.20;
float scDiagGlassVolume = 0.20;
float scDiagChoirVolume = 0.20;
float scDiagDynamicBPM = 120.0;
float scDiagRhythmComplexity = 0.0;
float[][] previousCombinedField = null;
String prevCartBasin = "METASTABLE DRIFT";
int framesInCurrentBasin = 0;
int framesSinceCoherence = 9999;
ArrayList<Float> orbitSpeedHistory = new ArrayList<Float>();
ArrayList<Float> orbitRadiusHistory = new ArrayList<Float>();

// Orbital resonance/event detector.  This turns emergent orbit behavior into
// lightweight symbolic data for logging and SuperCollider event marking.
ArrayList<Float> orbitEventRadiusHistory = new ArrayList<Float>();
ArrayList<Float> orbitEventSpeedHistory = new ArrayList<Float>();
ArrayList<Float> orbitEventAngleHistory = new ArrayList<Float>();
String orbitEventLabel = "ORBIT_STABLE_DRIFT";
String lastOrbitEventLabel = "ORBIT_STABLE_DRIFT";
float orbitEccentricity = 0;
float orbitPeriapsisIntensity = 0;
float orbitResonanceScore = 0;
int orbitLobeEstimate = 1;
int orbitEventChangeFrame = 0;
float orbitLockStrength = 0.0;

final int MODE_BRIGHTNESS = 0;
final int MODE_DENSITY = 1;
final int MODE_SWEEP = 2;
final int MODE_ORBIT = 3;
final int MODE_ENTROPY = 4;
final int MODE_FRACTAL = 5;
final int MODE_LYAPUNOV = 6;
final int MODE_KL = 7;
final int MODE_MUTUAL_INFO = 8;
final int MODE_MCMC = 9;
final int MODE_FOUNDATIONAL = 10;

final String[] MODE_NAMES = {
  "Brightness", "Density", "Sweep", "Orbit",
  "Entropy", "Fractal Dimension", "Lyapunov",
  "KL Divergence", "Mutual Information", "MCMC Inference",
  "Foundational Field"
};

float metricEntropy = 0;
float metricFractalDim = 0;
float metricLyapunov = 0;
float metricKLDivergence = 0;
float metricMutualInfo = 0;
float metricAdiabaticParam = 0;
float metricBerryPhase = 0;
float metricCorrelationTau = 0;
float metricStandardFit = 0;
float metricRDFit = 0;
float metricKLForward  = 0;
float metricKLReverse  = 0;
float metricKLSymmetric = 0;
int metricBreakdownCount = 0;
String lastBreakdownEvent = "none";
AdiabaticTracker adiabaticTracker;
BerryPhaseTracker berryTracker;
CriticalSlowingDetector criticalDetector;
RecursiveStateSpaceCartographer stateCartographer;

// SC feedback state. Updated by /sc/state from ColdSun_Shimmer.scd.
float scSaturation = 0.0;
boolean scDroneAlive = false;
float scHoldStrength = 0.0;
float scGlassAge = 30.0;
int scVoiceCount = 0;
int scLifecycleState = 1;
int lastSCHeartbeatMs = -999999;

// Recursive State-Space Cartography readouts.
// These describe a virtual/hypothetical RDFT phase-space trajectory, not literal physical position.
float cartX = 0.5;
float cartY = 0.5;
float cartZ = 0.5;
float cartStability = 0.5;
float cartVelocity = 0.0;
String cartBasin = "INITIALIZING";

// Foundational Field Layer metrics.
// These are lightweight interpretive physics diagnostics, not full EM/quantum simulations.
// Maxwell layer: gradient/curl/divergence proxies over the RDFT field.
// Schrodinger layer: normalized probability-amplitude and uncertainty proxies.
// Planck layer: normalized minimum-distinction gate.
// RDFT layer: coherence score combining low entropy, coupling, MI, and stability.
float foundationalDivE = 0.0;              // legacy normalized Maxwell activity gauge
float foundationalCurlB = 0.0;             // compatibility alias; now mirrors foundationalRotActivity, not true curl
float foundationalRotActivity = 0.0;       // old curl proxy renamed honestly: gradient + angular momentum + phi gain activity
float foundationalMaxwellDivETrue = 0.0;   // signed true divergence of E=-grad(phi): divE=-laplacian(phi)
float foundationalMaxwellLaplacianPhi = 0.0;
float beltramiBx = 0.0;
float beltramiBy = 0.0;
float beltramiBz = 0.0;
float beltramiBMag = 0.0;
float beltramiCurlX = 0.0;
float beltramiCurlY = 0.0;
float beltramiCurlZ = 0.0;
float beltramiCurlMag = 0.0;
float beltramiLambda = 0.0;
float beltramiAlignment = 0.0;
float beltramiHelicity = 0.0;
String symbolicBeltramiState = "BELTRAMI_UNINITIALIZED";
String symbolicMaxwellState = "MAXWELL_UNINITIALIZED";
String symbolicHolonomyEvent = "HOLO_NONE";
float foundationalPsiDensity = 0.0;
float foundationalUncertainty = 0.0;
float foundationalPlanckGate = 0.0;
float foundationalCoherence = 0.0;
float foundationalCoupling = 0.0;
float[] foundationalTrace = new float[180];
int foundationalTraceHead = 0;
int foundationalTraceCount = 0;

// Thread-safe replacement for Processing nf().
// Processing's nf()/DecimalFormat can throw fastPathData NullPointerExceptions on
// some Java builds when multiple update paths format numbers close together.
// This formatter avoids that shared path.
String safeNf(int value, int left) {
  try {
    return String.format(java.util.Locale.US, "%0" + max(1, left) + "d", value);
  } catch (Exception e) {
    return str(value);
  }
}

String safeNf(float value, int left, int right) {
  try {
    if (Float.isNaN(value) || Float.isInfinite(value)) return "0." + "000000".substring(0, min(6, max(0, right)));
    return String.format(java.util.Locale.US, "%" + max(1, left) + "." + max(0, right) + "f", value);
  } catch (Exception e) {
    return str(value);
  }
}

String safeNf(double value, int left, int right) {
  return safeNf((float)value, left, right);
}

// Signed pitch distance in semitones; guards non-positive inputs.
float semitoneDiff(float fA, float fB) {
  if (fA <= 0 || fB <= 0) return 0;
  return 12.0 * (log(fA / fB) / log(2));
}

float safeAlphaValue(float v) {
  if (Float.isNaN(v) || Float.isInfinite(v)) return 2.0;
  v = constrain(v, 1.0, 4.5);
  // Planck threshold zone: alpha in [1.0, 1.05]
  // At exactly 1.0, recursive scaling collapses — all layers equally weighted.
  // This is the RDFT analog of the Planck scale: minimum distinguishable recursion.
  if (v < 1.001) return 1.0;   // allow true threshold
  return v;
}

int safeDepthValue(float v) {
  if (Float.isNaN(v) || Float.isInfinite(v)) return 3;
  return constrain(round(v), 0, 7);
}

float[][] safeField(float[][] candidate) {
  if (candidate != null) return candidate;
  if (combined != null) return combined;
  return new float[GRID][GRID];
}


float getSliderValueSafe(String name, float fallback) {
  if (cp5 == null) return fallback;
  Controller c = cp5.getController(name);
  if (c == null) return fallback;
  return c.getValue();
}

void styleSliderLabel(String name) {
  if (cp5 == null) return;
  Controller c = cp5.getController(name);
  if (c == null) return;
  c.getCaptionLabel()
    .align(ControlP5.RIGHT, ControlP5.CENTER)
    .setPaddingX(4);
}

void initMidiPilot() {
  if (!MIDI_PILOT_ENABLED) return;
  try {
    midiPilotHelper = new MidiPilotHelper();
    midiPilotHelper.start();
    midiPilotConnected = midiPilotHelper.connected;
    midiPilotStatus = midiPilotHelper.status;
    statusMsg = statusMsg + " | " + midiPilotStatus;
  } catch (Exception e) {
    midiPilotConnected = false;
    midiPilotStatus = "MIDI failed: " + e.getMessage();
    println(midiPilotStatus);
  }
}

void applyMidiPilotUpdate() {
  if (midiPilotHelper == null) return;
  midiPilotConnected = midiPilotHelper.connected;
  midiLaunchpadDetected = midiPilotHelper.launchpadDetected;
  midiPolyMode = (toggleMidiPoly != null && toggleMidiPoly.getState());
  if (midiPolyMode != midiPolyModePrev) {
    if (!midiPolyMode) {
      midiPolyMemoryCharge = min(midiPolyMemoryCharge, 0.08);
      midiPolyReleasePressure = 1.0;
      sendMidiPolyStateToSC();
    }
    midiPolyModePrev = midiPolyMode;
  }

  float[][] controlEvents = midiPilotHelper.consumeControlEvents();
  if (controlEvents != null) {
    for (int i = 0; i < controlEvents.length; i++) {
      handleLaunchpadControlEvent(round(controlEvents[i][1]), controlEvents[i][2], round(controlEvents[i][3]));
    }
  }

  float[][] noteEvents = midiPilotHelper.consumeNoteEvents();
  if (noteEvents != null) {
    for (int i = 0; i < noteEvents.length; i++) {
      int rawNote = round(noteEvents[i][0]);
      float vel = noteEvents[i][1];
      boolean on = noteEvents[i][2] > 0.5;
      if (midiLaunchpadDetected && on && !launchpadGridRawNote(rawNote) && handleLaunchpadNoteControl(rawNote, vel)) continue;
      int note = midiLaunchpadDetected ? launchpadMappedNote(rawNote) : rawNote;
      if (midiLaunchpadDetected && launchpadGridRawNote(rawNote) && on) launchpadPreparePolyKey(vel);
      if (midiLaunchpadDetected) launchpadTrackMappedNote(note, on);
      handleMidiNoteEvent(note, vel, on, round(noteEvents[i][3]));
    }
  }

  if (!midiPolyMode) {
    float[] event = midiPilotHelper.consumePendingValues();
    if (midiLaunchpadDetected) {
      midiPilotStatus = "Launchpad pages active";
      if (launchpadLastAction.length() > 0) midiPilotStatus += " | " + launchpadLastAction;
      return;
    }
    if (event == null) {
      midiPilotStatus = midiPilotHelper.status;
      if (launchpadLastAction.length() > 0) {
        midiPilotStatus += " | " + launchpadLastAction;
      }
      return;
    }
    float freq = event[0];
    int note = round(event[1]);
    int held = round(event[2]);
    float vel = event[3];
    if (midiLaunchpadDetected) {
      note = launchpadMappedNote(note);
      freq = constrain(midiNoteFreqLocal(note), 20, 880);
    }
    if (sliderRootFreq != null) sliderRootFreq.setValue(freq);
    if (fieldRootFreq != null && !fieldRootFreq.isFocus()) fieldRootFreq.setText(safeNf(freq, 1, 1));
    midiLastRootNote = note;
    midiHeldCount = held;
    midiLastVelocity = vel;
    midiPilotStatus = (midiLaunchpadDetected ? "Launchpad scalar " : "MIDI scalar ") + note + " -> " + safeNf(freq, 1, 2) + " Hz" + (held > 1 ? (" chord x" + held) : "");
  } else {
    midiPilotHelper.consumePendingValues();
    updateMidiPolyMemory();
    midiPilotStatus = (midiLaunchpadDetected ? "Launchpad poly voices=" : "MIDI poly voices=") + midiHeldCount + " mem=" + safeNf(midiPolyMemoryCharge, 1, 2);
  }
  if (launchpadLastAction.length() > 0) {
    midiPilotStatus += " | " + launchpadLastAction;
  }
}

int launchpadMappedNote(int rawNote) {
  int[] cell = launchpadGridCell(rawNote);
  if (cell != null) {
    return launchpadPlayableNote(launchpadActivePage, cell[0], cell[1]);
  }
  return constrain(rawNote, 0, 127);
}

int launchpadPlayableNote(int page, int row, int col) {
  // Launchpad rows are top-to-bottom, but the playable pitch field should feel
  // like an instrument: low at the bottom, bright at the top, capped near A4.
  row = constrain(row, 1, 8);
  col = constrain(col, 1, 8);
  int[] scale = launchpadPageScale(page);
  int root = launchpadPageRootNote(page);
  int rowLift = launchpadPageRowLift(page, row);
  int note = root + scale[col - 1] + rowLift;
  return constrain(note + launchpadPitchShiftSemis, 33, 69); // 55 Hz .. 440 Hz
}

float launchpadPlayableFreq(int row, int col) {
  return midiNoteFreqLocal(launchpadPlayableNote(launchpadActivePage, row, col));
}

int[] launchpadPageScale(int page) {
  if (page == 1) return new int[] { 0, 3, 5, 7, 10, 12, 15, 17 }; // foundation: minor pentatonic octaves
  if (page == 2) return new int[] { 0, 2, 4, 6, 7, 9, 11, 12 };  // orbit: lydian
  if (page == 3) return new int[] { 0, 2, 3, 5, 7, 10, 12, 14 }; // eco: dorian/minor field
  if (page == 4) return new int[] { 0, 3, 7, 10, 12, 15, 19, 22 }; // legacy: chord tones
  return new int[] { 0, 2, 3, 5, 7, 8, 10, 12 }; // rainbow main: warm minor grid
}

int launchpadPageRootNote(int page) {
  if (page == 1) return 33; // A1
  if (page == 2) return 36; // C2
  if (page == 3) return 31; // G1
  if (page == 4) return 33; // A1
  return 33;
}

int launchpadPageRowLift(int page, int row) {
  if (page == 4) return round((8 - row) * (19.0 / 7.0)); // tighter chord surface
  if (page == 1) return round((8 - row) * (14.0 / 7.0)); // deeper foundation
  return round((8 - row) * (21.0 / 7.0));
}

int[] launchpadChordIntervals(int page, int row, int col) {
  // Keep Launchpad poly performance monophonic per pad. Earlier chord spawning
  // made page modes feel powerful, but it also made releases and tonal balance
  // unpredictable. Chord color now comes from page scales instead of extra notes.
  return new int[] {};
}

void launchpadHandleChordVoicing(int rawNote, int baseNote, float velocity, boolean on) {
  int[] cell = launchpadGridCell(rawNote);
  if (cell == null) return;
  int[] intervals = launchpadChordIntervals(launchpadActivePage, cell[0], cell[1]);
  for (int i = 0; i < intervals.length; i++) {
    int chordNote = constrain(baseNote + intervals[i], 33, 69);
    if (chordNote == baseNote) continue;
    launchpadTrackMappedNote(chordNote, on);
    handleMidiNoteEvent(chordNote, velocity * (0.62 - i * 0.10), on, midiHeldCount);
  }
}

boolean launchpadGridRawNote(int rawNote) {
  return launchpadGridCell(rawNote) != null;
}

int[] launchpadGridCell(int rawNote) {
  // Novation custom modes often emit chromatic 36..99 or indexed 0..63 notes,
  // while programmer mode emits 11..88. Accept all three so the synth can
  // recognize the user's existing Launchpad custom presets.
  if (rawNote >= 36 && rawNote <= 99) {
    int idx = rawNote - 36;
    return new int[] { constrain(idx / 8 + 1, 1, 8), constrain(idx % 8 + 1, 1, 8) };
  }
  if (rawNote >= 0 && rawNote <= 63) {
    return new int[] { constrain(rawNote / 8 + 1, 1, 8), constrain(rawNote % 8 + 1, 1, 8) };
  }
  int col = rawNote % 10;
  int row = rawNote / 10;
  if (col >= 1 && col <= 8 && row >= 1 && row <= 8) return new int[] { row, col };
  return null;
}

void launchpadHandleRDFTPadPreset(int rawNote, float velocity, boolean on) {
  int[] cell = launchpadGridCell(rawNote);
  if (cell == null) return;
  int row = cell[0];
  if (on) {
    if (launchpadRowHeld[row] <= 0) launchpadSnapshotRow(row);
    launchpadRowHeld[row]++;
    launchpadRowLastFrame[row] = frameCount;
    launchpadApplyRDFTPadPreset(rawNote, velocity);
  } else {
    launchpadRowHeld[row] = max(0, launchpadRowHeld[row] - 1);
    if (launchpadRowHeld[row] == 0) launchpadRestoreRow(row);
  }
}

void launchpadPreparePolyKey(float velocity) {
  float v = constrain(velocity, 0, 1);
  midiPolyMemoryCharge = 0;
  midiPolyHarmonicDensity = 0;
  midiPolyChordSpread = 0;
  midiPolyReleasePressure = 0;
  launchpadSetControl("midiPolyOn", 1);
  midiPolyMode = true;
  launchpadSetControl("midiPolyVolume", max(getSliderValueSafe("midiPolyVolume", 0.55), 0.42 + v * 0.36));
  sendPolyKeyIsolationToSC();
}

void sendPolyKeyIsolationToSC() {
  if (oscP5 == null || supercollider == null) return;
  OscMessage msg = new OscMessage("/rdf/polyKeyIsolation");
  msg.add(1.0f);
  try { oscP5.send(msg, supercollider); } catch (Exception e) {}
}

void launchpadApplyRDFTPadPreset(int rawNote, float velocity) {
  int[] cell = launchpadGridCell(rawNote);
  if (cell == null) return;
  int row = cell[0];
  int col = cell[1];
  float v = constrain(velocity, 0, 1);
  float colNorm = (col - 1) / 7.0;
  float perform = 0.30 + v * 0.62;
  launchpadSetActiveMode(row, col, v);
  if (launchpadActivePage > 0) {
    launchpadApplyPagePad(launchpadActivePage, row, col, v, colNorm, perform);
    return;
  }
  if (row != 1) chladniVisualMode = CH_VIS_MAIN;

  // The Launchpad's eight rows become eight RDFT preset banks while the notes
  // still feed the existing poly/key voice path.
  launchpadSetControl("midiPolyOn", 1);
  midiPolyMode = true;
  launchpadSetControl("midiPolyVolume", max(getSliderValueSafe("midiPolyVolume", 0.55), 0.34 + v * 0.50));

  if (row == 1) {
    chladniVisualMode = CH_VIS_FOUNDATION_STREAM;
    addFoundationStreamTouch(map(colNorm, 0, 1, -0.82, 0.82), map(v, 0, 1, 0.74, -0.74), 0.58 + v * 0.55);
    launchpadSetControl("orbSensitivity", lerp(0.55, 2.2, colNorm));
    launchpadSetControl("masterAmp", max(getSliderValueSafe("masterAmp", 0.72), 0.58 + v * 0.34));
    launchpadRemember("SLOT 1 FOUNDATION FIELD");
  } else if (row == 2) {
    launchpadSetControl("droneOn", 1);
    launchpadSetControl("droneVolume", perform);
    launchpadRemember("SLOT 2 DRONE");
  } else if (row == 3) {
    launchpadSetControl("arpOn", 1);
    launchpadSetControl("arpVolume", perform);
    launchpadSetControl("arpRate", lerp(0.16, 1.15, colNorm));
    launchpadRemember("SLOT 3 ARP");
  } else if (row == 4) {
    launchpadSetControl("solarDroneVolume", lerp(0.02, 0.12, max(v, colNorm)));
    launchpadSetControl("oceanCurrentBias", max(getSliderValueSafe("oceanCurrentBias", 0.5), 0.20 + colNorm * 0.72));
    launchpadSetControl("oceanSwellDepth", max(getSliderValueSafe("oceanSwellDepth", 0.5), 0.22 + v * 0.70));
    launchpadRemember("SLOT 4 SURFACE");
  } else if (row == 5) {
    launchpadSetControl("glassOn", 1);
    launchpadSetControl("glassVolume", perform);
    launchpadRemember("SLOT 5 GLASS");
  } else if (row == 6) {
    launchpadSetControl("choirOn", 1);
    launchpadSetControl("choirVolume", perform);
    launchpadRemember("SLOT 6 CHOIR");
  } else if (row == 7) {
    launchpadSetControl("midiPolyVolume", max(getSliderValueSafe("midiPolyVolume", 0.55), perform));
    midiPolyMemoryCharge = constrain(midiPolyMemoryCharge + 0.04 + v * 0.06, 0, 1);
    launchpadRemember("SLOT 7 HOPF KEYS");
  } else {
    if (col <= 2) {
      launchpadSetControl("ecoChirpOn", 1);
      launchpadSetControl("ecoChirpLevel", perform);
      launchpadRemember("SLOT 8 CHIRP");
    } else if (col <= 4) {
      launchpadSetControl("ecoCallOn", 1);
      launchpadSetControl("ecoCallLevel", perform);
      launchpadRemember("SLOT 8 CALL");
    } else if (col <= 6) {
      launchpadSetControl("ecoGrowthOn", 1);
      launchpadSetControl("ecoGrowthLevel", perform);
      launchpadRemember("SLOT 8 GROWTH");
    } else if (col == 7) {
      launchpadSetControl("ecoFissureOn", 1);
      launchpadSetControl("ecoFissureLevel", perform);
      launchpadRemember("SLOT 8 FISSURE");
    } else {
      launchpadSetControl("egProbeOn", 1);
      launchpadSetControl("egProbeLevel", perform);
      launchpadRemember("SLOT 8 EG");
    }
  }
}

void launchpadApplyPagePad(int page, int row, int col, float v, float colNorm, float perform) {
  float rowNorm = (row - 1) / 7.0;
  if (page == 1) {
    chladniVisualMode = CH_VIS_FOUNDATION_STREAM;
    addFoundationStreamTouch(map(colNorm, 0, 1, -0.86, 0.86), map(rowNorm, 0, 1, -0.86, 0.86), 0.55 + v * 0.65);
    launchpadSetControl("orbSensitivity", lerp(0.45, 2.6, max(v, 0.15)));
    launchpadSetControl("masterAmp", max(getSliderValueSafe("masterAmp", 0.72), 0.50 + v * 0.35));
    launchpadRemember("FOUNDATION STREAM");
  } else if (page == 2) {
    chladniVisualMode = CH_VIS_MAIN;
    orb_x = constrain(map(colNorm, 0, 1, -ORB_BOUND, ORB_BOUND), -ORB_BOUND, ORB_BOUND);
    orb_y = constrain(map(rowNorm, 0, 1, ORB_BOUND, -ORB_BOUND), -ORB_BOUND, ORB_BOUND);
    float tangent = atan2(orb_y, orb_x) + HALF_PI + (v - 0.5) * 0.8;
    float spd = 0.22 + colNorm * 0.55 + v * 0.42;
    orb_vx = cos(tangent) * spd;
    orb_vy = sin(tangent) * spd;
    launchpadSetControl("orbSensitivity", lerp(0.35, 2.85, v));
    if (row <= 2 && col >= 7) STARTSWEEP(1);
    if (row >= 7 && col <= 2) RESETORBIT(1);
    launchpadRemember("ORBIT HOLO");
  } else if (page == 3) {
    chladniVisualMode = CH_VIS_MAIN;
    if (row <= 2) {
      launchpadSetControl("ecoChirpOn", 1);
      launchpadSetControl("ecoChirpLevel", perform);
      launchpadSetControl("solarDroneVolume", min(0.12, 0.02 + v * 0.10));
      launchpadRemember("ECO CHIRP CANOPY");
    } else if (row <= 4) {
      launchpadSetControl("ecoCallOn", 1);
      launchpadSetControl("ecoCallLevel", perform);
      launchpadSetControl("oceanSwellDepth", max(getSliderValueSafe("oceanSwellDepth", 0.5), 0.25 + v * 0.70));
      launchpadRemember("ECO CALL VALLEY");
    } else if (row <= 6) {
      launchpadSetControl("ecoGrowthOn", 1);
      launchpadSetControl("ecoGrowthLevel", perform);
      launchpadSetControl("oceanCurrentBias", max(getSliderValueSafe("oceanCurrentBias", 0.5), 0.25 + colNorm * 0.70));
      launchpadRemember("ECO GROWTH");
    } else {
      launchpadSetControl("ecoFissureOn", 1);
      launchpadSetControl("ecoFissureLevel", perform);
      if (col >= 6) launchpadSetControl("egProbeOn", 1);
      launchpadSetControl("egProbeLevel", max(getSliderValueSafe("egProbeLevel", 0.55), 0.35 + v * 0.55));
      launchpadRemember("ECO FISSURE / EG");
    }
  } else if (page == 4) {
    chladniVisualMode = CH_VIS_MAIN;
    float bandLevel = lerp(0.12, 0.92, v);
    if (col <= 2) {
      launchpadSetControl("droneOn", 1);
      launchpadSetControl("droneVolume", bandLevel);
      launchpadRemember("LEGACY DRONE");
    } else if (col <= 4) {
      launchpadSetControl("arpOn", 1);
      launchpadSetControl("arpVolume", bandLevel);
      launchpadSetControl("arpRate", lerp(0.12, 1.1, rowNorm));
      launchpadRemember("LEGACY ARP WALK");
    } else if (col <= 6) {
      launchpadSetControl("glassOn", 1);
      launchpadSetControl("glassVolume", bandLevel);
      launchpadRemember("LEGACY GLASS");
    } else {
      launchpadSetControl("choirOn", 1);
      launchpadSetControl("choirVolume", bandLevel);
      launchpadRemember("LEGACY CHOIR");
    }
  } else {
    launchpadRemember(launchpadPageName(page));
  }
}

void launchpadSnapshotRow(int row) {
  row = constrain(row, 1, 8);
  launchpadRowRestoreArmed[row] = true;
  launchpadRowRestorePage[row] = launchpadActivePage;
  launchpadRestoreMidiPolyOn[row] = launchpadControlValue("midiPolyOn", 0) > 0.5;
  launchpadRestoreMidiPolyVol[row] = launchpadControlValue("midiPolyVolume", 0.55);
  if (launchpadActivePage > 0) launchpadSnapshotPageControls(row);
  if (row == 1) {
    launchpadRowRestoreA[row] = launchpadControlValue("orbSensitivity", 1.0);
    launchpadRowRestoreB[row] = launchpadControlValue("masterAmp", 0.72);
  } else if (row == 2) {
    launchpadRowRestoreT[row] = launchpadControlValue("droneOn", 0) > 0.5;
    launchpadRowRestoreA[row] = launchpadControlValue("droneVolume", 0.20);
  } else if (row == 3) {
    launchpadRowRestoreT[row] = launchpadControlValue("arpOn", 1) > 0.5;
    launchpadRowRestoreA[row] = launchpadControlValue("arpVolume", 0.20);
    launchpadRowRestoreB[row] = launchpadControlValue("arpRate", 0.40);
  } else if (row == 4) {
    launchpadRowRestoreA[row] = launchpadControlValue("solarDroneVolume", 0.0);
    launchpadRowRestoreB[row] = launchpadControlValue("oceanCurrentBias", oceanCurrentBias);
    launchpadRowRestoreC[row] = launchpadControlValue("oceanSwellDepth", oceanSwellDepth);
  } else if (row == 5) {
    launchpadRowRestoreT[row] = launchpadControlValue("glassOn", 1) > 0.5;
    launchpadRowRestoreA[row] = launchpadControlValue("glassVolume", 0.20);
  } else if (row == 6) {
    launchpadRowRestoreT[row] = launchpadControlValue("choirOn", 1) > 0.5;
    launchpadRowRestoreA[row] = launchpadControlValue("choirVolume", 0.20);
  } else if (row == 7) {
    launchpadRowRestoreA[row] = launchpadControlValue("midiPolyVolume", 0.55);
  } else if (row == 8) {
    launchpadRowRestoreA[row] = launchpadControlValue("ecoChirpLevel", 0.58);
    launchpadRowRestoreB[row] = launchpadControlValue("ecoCallLevel", 0.58);
    launchpadRowRestoreC[row] = launchpadControlValue("ecoGrowthLevel", 0.64);
    launchpadRowRestoreD[row] = launchpadControlValue("ecoFissureLevel", 0.64);
    launchpadRowRestoreE[row] = launchpadControlValue("egProbeLevel", 0.72);
  }
}

void launchpadRestoreRow(int row) {
  row = constrain(row, 1, 8);
  if (!launchpadRowRestoreArmed[row]) return;
  launchpadRowRestoreArmed[row] = false;
  if (launchpadRowRestorePage[row] > 0) {
    launchpadRestorePageControls(row);
    launchpadRowRestorePage[row] = 0;
    return;
  }
  launchpadSetControl("midiPolyOn", launchpadRestoreMidiPolyOn[row] ? 1 : 0);
  launchpadSetControl("midiPolyVolume", launchpadRestoreMidiPolyVol[row]);
  if (row == 1) {
    launchpadSetControl("orbSensitivity", launchpadRowRestoreA[row]);
    launchpadSetControl("masterAmp", launchpadRowRestoreB[row]);
  } else if (row == 2) {
    launchpadSetControl("droneOn", launchpadRowRestoreT[row] ? 1 : 0);
    launchpadSetControl("droneVolume", launchpadRowRestoreA[row]);
  } else if (row == 3) {
    launchpadSetControl("arpOn", launchpadRowRestoreT[row] ? 1 : 0);
    launchpadSetControl("arpVolume", launchpadRowRestoreA[row]);
    launchpadSetControl("arpRate", launchpadRowRestoreB[row]);
  } else if (row == 4) {
    launchpadSetControl("solarDroneVolume", launchpadRowRestoreA[row]);
    launchpadSetControl("oceanCurrentBias", launchpadRowRestoreB[row]);
    launchpadSetControl("oceanSwellDepth", launchpadRowRestoreC[row]);
  } else if (row == 5) {
    launchpadSetControl("glassOn", launchpadRowRestoreT[row] ? 1 : 0);
    launchpadSetControl("glassVolume", launchpadRowRestoreA[row]);
  } else if (row == 6) {
    launchpadSetControl("choirOn", launchpadRowRestoreT[row] ? 1 : 0);
    launchpadSetControl("choirVolume", launchpadRowRestoreA[row]);
  } else if (row == 7) {
    launchpadSetControl("midiPolyVolume", launchpadRowRestoreA[row]);
  } else if (row == 8) {
    launchpadSetControl("ecoChirpLevel", launchpadRowRestoreA[row]);
    launchpadSetControl("ecoCallLevel", launchpadRowRestoreB[row]);
    launchpadSetControl("ecoGrowthLevel", launchpadRowRestoreC[row]);
    launchpadSetControl("ecoFissureLevel", launchpadRowRestoreD[row]);
    launchpadSetControl("egProbeLevel", launchpadRowRestoreE[row]);
  }
}

void launchpadSnapshotPageControls(int row) {
  launchpadRestoreDroneOn[row] = launchpadControlValue("droneOn", 0) > 0.5;
  launchpadRestoreArpOn[row] = launchpadControlValue("arpOn", 1) > 0.5;
  launchpadRestoreGlassOn[row] = launchpadControlValue("glassOn", 1) > 0.5;
  launchpadRestoreChoirOn[row] = launchpadControlValue("choirOn", 1) > 0.5;
  launchpadRestoreEcoChirpOn[row] = launchpadControlValue("ecoChirpOn", 1) > 0.5;
  launchpadRestoreEcoCallOn[row] = launchpadControlValue("ecoCallOn", 1) > 0.5;
  launchpadRestoreEcoGrowthOn[row] = launchpadControlValue("ecoGrowthOn", 1) > 0.5;
  launchpadRestoreEcoFissureOn[row] = launchpadControlValue("ecoFissureOn", 1) > 0.5;
  launchpadRestoreEgProbeOn[row] = launchpadControlValue("egProbeOn", 0) > 0.5;
  launchpadRestoreDroneVol[row] = launchpadControlValue("droneVolume", 0.20);
  launchpadRestoreArpVol[row] = launchpadControlValue("arpVolume", 0.20);
  launchpadRestoreArpRate[row] = launchpadControlValue("arpRate", 0.40);
  launchpadRestoreGlassVol[row] = launchpadControlValue("glassVolume", 0.20);
  launchpadRestoreChoirVol[row] = launchpadControlValue("choirVolume", 0.20);
  launchpadRestoreEcoChirpLevel[row] = launchpadControlValue("ecoChirpLevel", 0.58);
  launchpadRestoreEcoCallLevel[row] = launchpadControlValue("ecoCallLevel", 0.58);
  launchpadRestoreEcoGrowthLevel[row] = launchpadControlValue("ecoGrowthLevel", 0.64);
  launchpadRestoreEcoFissureLevel[row] = launchpadControlValue("ecoFissureLevel", 0.64);
  launchpadRestoreEgProbeLevel[row] = launchpadControlValue("egProbeLevel", 0.72);
  launchpadRestoreSolarVol[row] = launchpadControlValue("solarDroneVolume", 0.0);
  launchpadRestoreOceanCurrent[row] = launchpadControlValue("oceanCurrentBias", oceanCurrentBias);
  launchpadRestoreOceanSwell[row] = launchpadControlValue("oceanSwellDepth", oceanSwellDepth);
  launchpadRestoreOrbSensitivity[row] = launchpadControlValue("orbSensitivity", 1.0);
  launchpadRestoreMasterAmp[row] = launchpadControlValue("masterAmp", 0.72);
}

void launchpadRestorePageControls(int row) {
  launchpadSetControl("droneOn", launchpadRestoreDroneOn[row] ? 1 : 0);
  launchpadSetControl("arpOn", launchpadRestoreArpOn[row] ? 1 : 0);
  launchpadSetControl("glassOn", launchpadRestoreGlassOn[row] ? 1 : 0);
  launchpadSetControl("choirOn", launchpadRestoreChoirOn[row] ? 1 : 0);
  launchpadSetControl("ecoChirpOn", launchpadRestoreEcoChirpOn[row] ? 1 : 0);
  launchpadSetControl("ecoCallOn", launchpadRestoreEcoCallOn[row] ? 1 : 0);
  launchpadSetControl("ecoGrowthOn", launchpadRestoreEcoGrowthOn[row] ? 1 : 0);
  launchpadSetControl("ecoFissureOn", launchpadRestoreEcoFissureOn[row] ? 1 : 0);
  launchpadSetControl("egProbeOn", launchpadRestoreEgProbeOn[row] ? 1 : 0);
  launchpadSetControl("midiPolyOn", launchpadRestoreMidiPolyOn[row] ? 1 : 0);
  launchpadSetControl("droneVolume", launchpadRestoreDroneVol[row]);
  launchpadSetControl("arpVolume", launchpadRestoreArpVol[row]);
  launchpadSetControl("arpRate", launchpadRestoreArpRate[row]);
  launchpadSetControl("glassVolume", launchpadRestoreGlassVol[row]);
  launchpadSetControl("choirVolume", launchpadRestoreChoirVol[row]);
  launchpadSetControl("ecoChirpLevel", launchpadRestoreEcoChirpLevel[row]);
  launchpadSetControl("ecoCallLevel", launchpadRestoreEcoCallLevel[row]);
  launchpadSetControl("ecoGrowthLevel", launchpadRestoreEcoGrowthLevel[row]);
  launchpadSetControl("ecoFissureLevel", launchpadRestoreEcoFissureLevel[row]);
  launchpadSetControl("egProbeLevel", launchpadRestoreEgProbeLevel[row]);
  launchpadSetControl("midiPolyVolume", launchpadRestoreMidiPolyVol[row]);
  launchpadSetControl("solarDroneVolume", launchpadRestoreSolarVol[row]);
  launchpadSetControl("oceanCurrentBias", launchpadRestoreOceanCurrent[row]);
  launchpadSetControl("oceanSwellDepth", launchpadRestoreOceanSwell[row]);
  launchpadSetControl("orbSensitivity", launchpadRestoreOrbSensitivity[row]);
  launchpadSetControl("masterAmp", launchpadRestoreMasterAmp[row]);
}

void launchpadSetActiveMode(int slot, int col, float velocity) {
  launchpadActiveSlot = constrain(slot, 1, 8);
  launchpadActiveColumn = constrain(col, 1, 8);
  launchpadActiveVelocity = constrain(velocity, 0, 1);
  launchpadActiveMode = launchpadSlotName(launchpadActiveSlot);
  launchpadActiveFrame = frameCount;
}

String launchpadSlotName(int slot) {
  if (slot == 1) return "FOUNDATION FIELD";
  if (slot == 2) return "DRONE FIELD";
  if (slot == 3) return "ARP WALK";
  if (slot == 4) return "SURFACE / SOLAR / OCEAN";
  if (slot == 5) return "GLASS LATTICE";
  if (slot == 6) return "CHOIR SHIMMER";
  if (slot == 7) return "KEYS / HOPF";
  if (slot == 8) return "ECO / EG";
  return "MAIN PRESET";
}

String launchpadPageName(int page) {
  if (page == 0) return "RAINBOW MAIN";
  if (page == 1) return "FOUNDATION STREAM";
  if (page == 2) return "ORBIT / HOLO";
  if (page == 3) return "ECO FOREST";
  if (page == 4) return "LEGACY MIX";
  if (page == 5) return "GALAXY SHEAR";
  if (page == 6) return "SURFACE TOPO";
  if (page == 7) return "PANIC / UTILITY";
  return "RAINBOW MAIN";
}

int launchpadPageFromSideCC(int cc) {
  int[] side = { 89, 79, 69, 59, 49, 39, 29, 19 };
  for (int i = 0; i < side.length; i++) if (cc == side[i]) return i;
  return -1;
}

void launchpadSelectPage(int page) {
  launchpadActivePage = constrain(page, 0, 7);
  if (launchpadActivePage != 1) chladniVisualMode = CH_VIS_MAIN;
  else chladniVisualMode = CH_VIS_FOUNDATION_STREAM;
  launchpadRemember("PAGE " + (launchpadActivePage + 1) + " " + launchpadPageName(launchpadActivePage));
}

color launchpadSlotColor(int slot) {
  if (slot == 1) return color(235, 245, 245);
  if (slot == 2) return color(255, 40, 28);
  if (slot == 3) return color(255, 138, 22);
  if (slot == 4) return color(255, 214, 48);
  if (slot == 5) return color(42, 220, 76);
  if (slot == 6) return color(48, 145, 255);
  if (slot == 7) return color(75, 72, 235);
  if (slot == 8) return color(170, 74, 255);
  return color(90, 220, 255);
}

boolean handleLaunchpadNoteControl(int rawNote, float velocity) {
  if (launchpadGridRawNote(rawNote)) return false;
  if (rawNote < 89 || rawNote > 104) return false;
  int slot = rawNote - 89;
  if (slot == 0) { COMPUTE(1); launchpadRemember("RUN"); return true; }
  if (slot == 1) { RESETORBIT(1); launchpadRemember("RESET"); return true; }
  if (slot == 2) { ANIMATE(1); launchpadRemember("HOLD"); return true; }
  if (slot == 3) { STARTSWEEP(1); launchpadRemember("SWEEP"); return true; }
  if (slot == 4) { launchpadToggle("midiPolyOn"); launchpadRemember("POLY"); return true; }
  if (slot == 5) { SPAWNDRONE(1); launchpadRemember("FLQ ON"); return true; }
  if (slot == 6) { KILLDRONE(1); launchpadMidiPanic(); launchpadRemember("FLQ OFF + PANIC"); return true; }
  if (slot == 7) { RESETBERRY(1); launchpadRemember("BERRY"); return true; }
  if (slot == 8) { HSRUN(1); launchpadRemember("HOLO"); return true; }
  if (slot == 9) { HSRUNREV(1); launchpadRemember("REV"); return true; }
  if (slot == 10) { HSORIENT(1); launchpadRemember("ORIENT"); return true; }
  if (slot == 11) { HSSTOP(1); launchpadRemember("STOP"); return true; }
  if (slot == 12) { HSLAGPAUSE(1); launchpadRemember("LAG"); return true; }
  if (slot == 13) { HSFREEZE(1); launchpadRemember("FREEZE"); return true; }
  if (slot == 14) { surfaceToggle(); launchpadRemember("SURF"); return true; }
  if (slot == 15) { surfaceLocation(); launchpadRemember("LOC"); return true; }
  return true;
}

boolean handleLaunchpadTopControl(int cc) {
  if (cc == 91) { launchpadSelectPage((launchpadActivePage + 7) % 8); launchpadRemember("PAGE PREV"); return true; }
  if (cc == 92) { launchpadSelectPage((launchpadActivePage + 1) % 8); launchpadRemember("PAGE NEXT"); return true; }
  if (cc == 93) { launchpadPitchShiftSemis = max(-24, launchpadPitchShiftSemis - 12); launchpadRemember("OCT - " + launchpadPitchShiftSemis); return true; }
  if (cc == 94) { launchpadPitchShiftSemis = min(24, launchpadPitchShiftSemis + 12); launchpadRemember("OCT + " + launchpadPitchShiftSemis); return true; }
  if (cc == 95) { launchpadPolyFilterTone = max(0.0, launchpadPolyFilterTone - 0.10); sendMidiPolyStateToSC(); launchpadRemember("FILTER DARK " + safeNf(launchpadPolyFilterTone, 1, 2)); return true; }
  if (cc == 96) { launchpadPolyFilterTone = min(1.0, launchpadPolyFilterTone + 0.10); sendMidiPolyStateToSC(); launchpadRemember("FILTER OPEN " + safeNf(launchpadPolyFilterTone, 1, 2)); return true; }
  if (cc == 97) { KILLDRONE(1); launchpadMidiPanic(); launchpadRemember("PANIC"); return true; }
  if (cc == 98) { launchpadPitchShiftSemis = 0; launchpadPolyFilterTone = 0.45; sendMidiPolyStateToSC(); launchpadRemember("KEY RESET"); return true; }
  return false;
}

void handleLaunchpadControlEvent(int cc, float value, int rawValue) {
  value = constrain(value, 0, 1);
  launchpadLastControl = cc;
  launchpadLastValue = value;

  if (rawValue > 0) {
    int page = launchpadPageFromSideCC(cc);
    if (page >= 0) {
      launchpadSelectPage(page);
      return;
    }
  }

  // Common Launchpad X top-row / side buttons in programmer/custom modes.
  // Ignore release value 0 for actions so a button press fires once.
  if (rawValue > 0) {
    if (handleLaunchpadTopControl(cc)) return;
    if (cc == 91) { COMPUTE(1); launchpadRemember("CC91 RUN"); return; }
    if (cc == 92) { RESETORBIT(1); launchpadRemember("CC92 RESET"); return; }
    if (cc == 93) { ANIMATE(1); launchpadRemember("CC93 HOLD"); return; }
    if (cc == 94) { STARTSWEEP(1); launchpadRemember("CC94 SWEEP"); return; }
    if (cc == 95) { launchpadToggle("midiPolyOn"); launchpadRemember("CC95 POLY"); return; }
    if (cc == 96) { SPAWNDRONE(1); launchpadRemember("CC96 FLQ ON"); return; }
    if (cc == 97) { KILLDRONE(1); launchpadMidiPanic(); launchpadRemember("CC97 FLQ OFF + PANIC"); return; }
    if (cc == 98) { RESETBERRY(1); launchpadRemember("CC98 BERRY"); return; }
    if (cc == 19) { HSRUN(1); launchpadRemember("CC19 HOLO"); return; }
    if (cc == 20) { HSRUNREV(1); launchpadRemember("CC20 REV"); return; }
    if (cc == 21) { HSORIENT(1); launchpadRemember("CC21 ORIENT"); return; }
    if (cc == 22) { HSSTOP(1); launchpadRemember("CC22 STOP"); return; }
    if (cc == 23) { HSLAGPAUSE(1); launchpadRemember("CC23 LAG"); return; }
    if (cc == 24) { HSFREEZE(1); launchpadRemember("CC24 FREEZE"); return; }
    if (cc == 25) { surfaceToggle(); launchpadRemember("CC25 SURF"); return; }
    if (cc == 26) { surfaceLocation(); launchpadRemember("CC26 LOC"); return; }
  }

  // Optional custom-mode faders/knobs. These let the Launchpad become a real mix surface
  // when the Novation Components editor assigns pads/faders to CC 1..16.
  if (cc == 1) { launchpadSetControl("masterAmp", value); launchpadRemember("OUT " + safeNf(value, 1, 2)); return; }
  if (cc == 2) { launchpadSetControl("reverbMix", value); launchpadRemember("REVERB " + safeNf(value, 1, 2)); return; }
  if (cc == 3) { launchpadSetControl("orbSensitivity", lerp(0.1, 3.0, value)); launchpadRemember("ACTION " + safeNf(value, 1, 2)); return; }
  if (cc == 4) { launchpadSetControl("droneVolume", value); launchpadRemember("DRONE " + safeNf(value, 1, 2)); return; }
  if (cc == 5) { launchpadSetControl("arpVolume", value); launchpadRemember("ARP " + safeNf(value, 1, 2)); return; }
  if (cc == 6) { launchpadSetControl("glassVolume", value); launchpadRemember("GLASS " + safeNf(value, 1, 2)); return; }
  if (cc == 7) { launchpadSetControl("choirVolume", value); launchpadRemember("CHOIR " + safeNf(value, 1, 2)); return; }
  if (cc == 8) { launchpadSetControl("midiPolyVolume", value); launchpadRemember("KEYS " + safeNf(value, 1, 2)); return; }
  if (cc == 9) { launchpadSetControl("ecoChirpLevel", value); launchpadRemember("CHIRP " + safeNf(value, 1, 2)); return; }
  if (cc == 10) { launchpadSetControl("ecoCallLevel", value); launchpadRemember("CALL " + safeNf(value, 1, 2)); return; }
  if (cc == 11) { launchpadSetControl("ecoGrowthLevel", value); launchpadRemember("GROW " + safeNf(value, 1, 2)); return; }
  if (cc == 12) { launchpadSetControl("ecoFissureLevel", value); launchpadRemember("FISS " + safeNf(value, 1, 2)); return; }
  if (cc == 13) { launchpadSetControl("egProbeLevel", value); launchpadRemember("EG " + safeNf(value, 1, 2)); return; }
  if (cc == 14) { launchpadSetControl("oceanCurrentBias", value); launchpadRemember("CURRENT " + safeNf(value, 1, 2)); return; }
  if (cc == 15) { launchpadSetControl("oceanSwellDepth", value); launchpadRemember("SWELL " + safeNf(value, 1, 2)); return; }
  if (cc == 16) { launchpadSetControl("solarDroneVolume", value * 0.12); launchpadRemember("SOLAR " + safeNf(value, 1, 2)); return; }
}

void launchpadSetControl(String name, float value) {
  if (cp5 == null) return;
  Controller c = cp5.getController(name);
  if (c == null) return;
  c.setValue(value);
}

float launchpadControlValue(String name, float fallback) {
  if (cp5 == null) return fallback;
  Controller c = cp5.getController(name);
  if (c == null) return fallback;
  return c.getValue();
}

void launchpadToggle(String name) {
  if (cp5 == null) return;
  Controller c = cp5.getController(name);
  if (c == null) return;
  c.setValue(c.getValue() > 0.5 ? 0 : 1);
}

void launchpadMidiPanic() {
  for (int row = 1; row <= 8; row++) {
    launchpadRowHeld[row] = 0;
    launchpadRestoreRow(row);
  }
  for (int i = 0; i < midiPolyActiveNotes.length; i++) {
    if (midiPolyActiveNotes[i] || launchpadMappedNoteFromLaunchpad[i]) sendMidiPolyNoteToSC(i, 0, false);
    midiPolyActiveNotes[i] = false;
    midiPolyVelocities[i] = 0;
    launchpadMappedNoteFromLaunchpad[i] = false;
    launchpadMappedNoteLastFrame[i] = 0;
  }
  midiHeldCount = 0;
  midiPolyMemoryCharge = 0;
  midiPolyHarmonicDensity = 0;
  midiPolyChordSpread = 0;
  midiPolyReleasePressure = 1.0;
  launchpadSetControl("midiPolyOn", 0);
  midiPolyMode = false;
  launchpadSetControl("arpVolume", min(launchpadControlValue("arpVolume", 0.20), 0.20));
  launchpadSetControl("glassVolume", min(launchpadControlValue("glassVolume", 0.20), 0.20));
  launchpadSetControl("choirVolume", min(launchpadControlValue("choirVolume", 0.20), 0.20));
  launchpadSetControl("midiPolyVolume", min(launchpadControlValue("midiPolyVolume", 0.55), 0.35));
  sendMidiPolyStateToSC();
}

void launchpadTrackMappedNote(int note, boolean on) {
  note = constrain(note, 0, 127);
  if (on) {
    launchpadMappedNoteFromLaunchpad[note] = true;
    launchpadMappedNoteLastFrame[note] = frameCount;
  } else {
    launchpadMappedNoteFromLaunchpad[note] = false;
    launchpadMappedNoteLastFrame[note] = 0;
  }
}

void launchpadUpdateMomentarySafeties() {
  boolean releasedAnyNote = false;
  for (int row = 1; row <= 8; row++) {
    if (launchpadRowHeld[row] > 0 && frameCount - launchpadRowLastFrame[row] > LAUNCHPAD_ROW_AUTORESTORE_FRAMES) {
      launchpadRowHeld[row] = 0;
      launchpadRestoreRow(row);
    }
  }
  for (int note = 0; note < launchpadMappedNoteFromLaunchpad.length; note++) {
    if (launchpadMappedNoteFromLaunchpad[note] && frameCount - launchpadMappedNoteLastFrame[note] > LAUNCHPAD_NOTE_AUTORELEASE_FRAMES) {
      launchpadMappedNoteFromLaunchpad[note] = false;
      launchpadMappedNoteLastFrame[note] = 0;
      midiPolyActiveNotes[note] = false;
      midiPolyVelocities[note] = 0;
      sendMidiPolyNoteToSC(note, 0, false);
      releasedAnyNote = true;
    }
  }
  if (releasedAnyNote) {
    midiHeldCount = countMidiPolyHeldNotes();
    midiPolyReleaseCount++;
    if (midiHeldCount == 0) {
      midiPolyMemoryCharge = 0;
      midiPolyHarmonicDensity = 0;
      midiPolyChordSpread = 0;
    }
    sendMidiPolyStateToSC();
    launchpadRemember("AUTO RELEASE");
  }
}

void launchpadRemember(String action) {
  launchpadLastAction = "Launchpad " + action;
}

float midiNoteFreqLocal(int note) {
  return 440.0f * pow(2.0f, (note - 69) / 12.0f);
}

void handleMidiNoteEvent(int note, float velocity, boolean on, int heldFromDevice) {
  note = constrain(note, 0, 127);
  velocity = constrain(velocity, 0, 1);
  boolean wasActive = midiPolyActiveNotes[note];
  if (on) {
    midiPolyActiveNotes[note] = true;
    midiPolyVelocities[note] = velocity;
    midiPolyTriggerCount++;
    midiLastRootNote = note;
    midiLastVelocity = velocity;
  } else {
    midiPolyActiveNotes[note] = false;
    midiPolyVelocities[note] = 0.0;
    midiPolyReleaseCount++;
  }
  midiHeldCount = countMidiPolyHeldNotes();
  if (midiPolyMode || wasActive || !on) sendMidiPolyNoteToSC(note, velocity, on);
  if (!on && midiHeldCount == 0) {
    midiPolyMemoryCharge = 0;
    midiPolyHarmonicDensity = 0;
    midiPolyChordSpread = 0;
    sendMidiPolyStateToSC();
  }
}

int countMidiPolyHeldNotes() {
  int n = 0;
  for (int i = 0; i < midiPolyActiveNotes.length; i++) if (midiPolyActiveNotes[i]) n++;
  return n;
}

int lowestMidiPolyNote() {
  for (int i = 0; i < midiPolyActiveNotes.length; i++) if (midiPolyActiveNotes[i]) return i;
  return -1;
}

int highestMidiPolyNote() {
  for (int i = midiPolyActiveNotes.length - 1; i >= 0; i--) if (midiPolyActiveNotes[i]) return i;
  return -1;
}

void updateMidiPolyMemory() {
  int held = countMidiPolyHeldNotes();
  int low = lowestMidiPolyNote();
  int high = highestMidiPolyNote();
  float planckRelease = constrain(foundationalPlanckGate * 0.70 + phi_threshold_prox * 0.20 + max(0, metricLyapunov - 0.9) * 0.15, 0, 1);
  midiPolyReleasePressure = lerp(midiPolyReleasePressure, planckRelease, 0.08);
  if (held > 0 && low >= 0) {
    midiPolyRootTargetFreq = constrain(midiNoteFreqLocal(low), 20, 880);
    midiPolyChordSpread = constrain((high - low) / 24.0, 0, 1);
    midiPolyHarmonicDensity = constrain(held / 8.0 + midiPolyChordSpread * 0.35, 0, 1);
    midiPolyMemoryCharge = constrain(midiPolyMemoryCharge + 0.0025 * held * (1.0 - midiPolyReleasePressure), 0, 0.28);
  } else {
    midiPolyChordSpread = lerp(midiPolyChordSpread, 0, 0.05);
    midiPolyHarmonicDensity = lerp(midiPolyHarmonicDensity, 0, 0.045 + midiPolyReleasePressure * 0.08);
    midiPolyMemoryCharge = max(0, midiPolyMemoryCharge - (0.026 + midiPolyReleasePressure * 0.055));
  }

  midiPolyLastRootApplied = midiPolyRootTargetFreq;
  if (frameCount % 6 == 0) sendMidiPolyStateToSC();
}

void sendMidiPolyNoteToSC(int note, float velocity, boolean on) {
  if (oscP5 == null || supercollider == null) return;
  OscMessage msg = new OscMessage("/rdf/midiPoly");
  msg.add((float)note);
  msg.add(midiNoteFreqLocal(note));
  msg.add(velocity);
  msg.add(on ? 1.0f : 0.0f);
  msg.add(getSliderValueSafe("midiPolyVolume", 0.55));
  msg.add(midiPolyMemoryCharge);
  msg.add(midiPolyReleasePressure);
  msg.add(midiPolyHarmonicDensity);
  msg.add(launchpadPolyFilterTone);
  try { oscP5.send(msg, supercollider); } catch (Exception e) {}
}

void sendMidiPolyStateToSC() {
  if (oscP5 == null || supercollider == null) return;
  OscMessage msg = new OscMessage("/rdf/midiPolyState");
  msg.add(midiPolyMode ? 1.0f : 0.0f);
  msg.add((float)midiHeldCount);
  msg.add(getSliderValueSafe("midiPolyVolume", 0.55));
  msg.add(midiPolyMemoryCharge);
  msg.add(midiPolyReleasePressure);
  msg.add(midiPolyHarmonicDensity);
  msg.add(midiPolyChordSpread);
  msg.add(launchpadPolyFilterTone);
  try { oscP5.send(msg, supercollider); } catch (Exception e) {}
}

void shutdownMidiPilot() {
  if (midiPilotHelper != null) midiPilotHelper.shutdown();
  midiPilotHelper = null;
  midiPilotConnected = false;
}


// ============================================================
void settings() {
  // IMPORTANT: use the default JAVA2D renderer.
  // P2D/JOGL was causing Raspberry Pi / Processing 4 animator lockups:
  //   Waited 5000ms ... main-FPSAWTAnimator ... Timer0/Timer1
  // This sketch only uses 2D drawing, so JAVA2D is the safer single-window path.
  size(W, H, JAVA2D);
}

void setup() {
  surface.setTitle(CHLADNI_SPHERE_UI ? "RDFT Chladni Sphere Synth" : "Recursive Differentiation Framework");
  colorMode(RGB, 255);
  textFont(createFont("Monospaced", 12));
  frameRate(24); // main GUI performance cap: smoother Pi 400 operation without changing synthesis mapping

  oscP5 = new OscP5(this, 12000);
  supercollider = new NetAddress("127.0.0.1", 60001);  
  
  println("OSC initialized - sending to 127.0.0.1:60001");
  println("UDP/OSC-only build: Processing Serial is intentionally disabled.");

  cmap_plasma = buildCmap("plasma", 256);
  cmap_viridis = buildCmap("viridis", 256);
  cmap_inferno = buildCmap("inferno", 256);

  computeFrames();
  phiEngine.rebuildRadialTable(0.3);  // §5 initial radial table
  thread("buildSweepCache");

  cp5 = new ControlP5(this);
  
  surfaceControl = new NetAddress("127.0.0.1", 5057);
  initSurfaceControl();

sliderDepth = cp5.addSlider("depth")
    .setPosition(60, 22)
    .setSize(126, 14)
    .setRange(0, 7)
    .setValue(depth)
    .setNumberOfTickMarks(8)
    .setDecimalPrecision(0)
    .setLabel("Depth")
    .setColorBackground(color(30))
    .setColorForeground(color(80, 180, 220))
    .setColorActive(color(120, 220, 255))
    .setColorCaptionLabel(color(200));

sliderAlpha = cp5.addSlider("alpha")
    .setPosition(60, 42)
    .setSize(126, 14)
    .setRange(1.0, 4.5)
    .setValue(alpha)
    .setNumberOfTickMarks(0)
    .setDecimalPrecision(3)
    .setLabel("Alpha")
    .setColorBackground(color(30))
    .setColorForeground(color(80, 220, 140))
    .setColorActive(color(120, 255, 180))
    .setColorCaptionLabel(color(200));

 sliderGamma = cp5.addSlider("orb_gamma")
    .setPosition(60, 62)
    .setSize(126, 14)
    .setRange(-2.5, 0.5)
    .setValue(orb_gamma)
    .setNumberOfTickMarks(16)
    .setDecimalPrecision(2)
    .setLabel("Orb Gamma")
    .setColorBackground(color(30))
    .setColorForeground(color(220, 140, 80))
    .setColorActive(color(255, 180, 100))
    .setColorCaptionLabel(color(200));

 btnCompute = cp5.addButton("COMPUTE")
    .setPosition(196, 20)
    .setSize(63, 18)
    .setLabel("COMPUTE")
    .setColorBackground(color(40, 100, 160))
    .setColorForeground(color(60, 140, 210))
    .setColorActive(color(80, 180, 255));

btnAnimate = cp5.addButton("ANIMATE")
    .setPosition(196, 44)
    .setSize(63, 18)
    .setLabel("ANIMATE")
    .setColorBackground(color(80, 50, 130))
    .setColorForeground(color(110, 70, 180))
    .setColorActive(color(150, 100, 255));
  cp5.addButton("surfaceToggle")
    .setPosition(724, 82)
    .setSize(78, 16)
    .setLabel("SURF: ON/OFF")
    .setColorBackground(color(45, 65, 95))
    .setColorForeground(color(70, 100, 145))
    .setColorActive(color(110, 150, 220));

  cp5.addButton("surfaceMode")
    .setPosition(808, 82)
    .setSize(78, 16)
    .setLabel("SURF: NEXT")
    .setColorBackground(color(65, 45, 95))
    .setColorForeground(color(100, 70, 145))
    .setColorActive(color(150, 110, 220));

  cp5.addButton("surfaceTopo")
    .setPosition(892, 82)
    .setSize(78, 16)
    .setLabel("SURF: TOPO")
    .setColorBackground(color(45, 75, 70))
    .setColorForeground(color(70, 120, 110))
    .setColorActive(color(100, 190, 170));

  cp5.addButton("surfaceLocation")
    .setPosition(976, 82)
    .setSize(78, 16)
    .setLabel("SURF: LOC")
    .setColorBackground(color(75, 60, 35))
    .setColorForeground(color(130, 100, 55))
    .setColorActive(color(210, 160, 80));
    

btnResetOrbit = cp5.addButton("RESETORBIT")
    .setPosition(196, 68)
    .setSize(63, 16)
    .setLabel("RESET ORBIT")
    .setColorBackground(color(80, 60, 20))
    .setColorForeground(color(140, 100, 30))
    .setColorActive(color(200, 160, 50));

  btnLadder = cp5.addButton("LADDER")
    .setPosition(196, 46)
    .setSize(126, 16)
    .setLabel("AREA LADDER")
    .setColorBackground(color(45, 72, 96))
    .setColorForeground(color(64, 112, 150))
    .setColorActive(color(92, 170, 220));
    
  btnConnect = cp5.addButton("CONNECT")
    .setPosition(W - 410, 30)
    .setSize(90, 28)
    .setLabel("CONNECT")
    .setColorBackground(color(40, 100, 50))
    .setColorForeground(color(60, 150, 70))
    .setColorActive(color(80, 200, 100));

  btnPush = cp5.addButton("PUSH")
    .setPosition(W - 312, 30)
    .setSize(90, 28)
    .setLabel("PUSH FRAME")
    .setColorBackground(color(130, 60, 20))
    .setColorForeground(color(180, 90, 30))
    .setColorActive(color(255, 130, 50));
    
  // Materials and Nodes are now always-on embedded interpretation layers.
  // Their old auxiliary-view buttons were removed to reduce GUI clutter and prevent
  // accidental extra rendering load.

  // Precision parameter + adiabatic sweep panel.
  // This gives the sweep explicit target/duration controls for repeatable runs.
int sx = 300;
  int sy = 22;
  cp5.addTextlabel("sweepTitle")
    .setText("ADIABATIC SWEEP / PARAMETER PRECISION")
    .setPosition(sx, sy - 16)
    .setColorValue(color(180, 230, 240));

  fieldDepth = cp5.addTextfield("depthBox")
    .setPosition(sx, sy)
    .setSize(52, 20)
    .setText(str(depth))
    .setAutoClear(false)
    .setLabel("depth");

  fieldAlpha = cp5.addTextfield("alphaBox")
    .setPosition(sx + 64, sy)
    .setSize(62, 20)
    .setText(safeNf(alpha, 1, 2))
    .setAutoClear(false)
    .setLabel("alpha");

  fieldGamma = cp5.addTextfield("gammaBox")
    .setPosition(sx + 138, sy)
    .setSize(62, 20)
    .setText(safeNf(orb_gamma, 1, 2))
    .setAutoClear(false)
    .setLabel("gamma");

  btnApplyParams = cp5.addButton("APPLYPARAMS")
    .setPosition(sx + 212, sy)
    .setSize(78, 22)
    .setLabel("APPLY")
    .setColorBackground(color(45, 90, 95))
    .setColorForeground(color(70, 135, 140))
    .setColorActive(color(110, 210, 215));

  fieldSweepAlphaTarget = cp5.addTextfield("sweepAlphaTargetBox")
    .setPosition(sx, sy + 42)
    .setSize(62, 20)
    .setText("4.20")
    .setAutoClear(false)
    .setLabel("target a");

  fieldSweepDepthTarget = cp5.addTextfield("sweepDepthTargetBox")
    .setPosition(sx + 74, sy + 42)
    .setSize(52, 20)
    .setText("3")
    .setAutoClear(false)
    .setLabel("target d");

  fieldSweepDuration = cp5.addTextfield("sweepDurationBox")
    .setPosition(sx + 138, sy + 42)
    .setSize(62, 20)
    .setText("60")
    .setAutoClear(false)
    .setLabel("seconds");

  btnAdiabaticSweep = cp5.addButton("STARTSWEEP")
    .setPosition(sx + 212, sy + 42)
    .setSize(106, 22)
    .setLabel("START SWEEP")
    .setColorBackground(color(40, 80, 130))
    .setColorForeground(color(70, 120, 190))
    .setColorActive(color(120, 170, 255));

btnFieldConfig = cp5.addButton("FIELDCONFIG")
    .setPosition(640, 58)
    .setSize(78, 16)
    .setLabel("FIELD CFG: OFF")
    .setColorBackground(color(25, 55, 75))
    .setColorForeground(color(40, 90, 120))
    .setColorActive(color(60, 150, 200));
 

  btnRecordData = cp5.addButton("RECORDDATA")
    .setPosition(724, 58)
    .setSize(78, 16)
    .setLabel("REC DATA: OFF")
    .setColorBackground(color(90, 30, 35))
    .setColorForeground(color(150, 45, 55))
    .setColorActive(color(230, 70, 85));

  btnBerryReset = cp5.addButton("RESETBERRY")
    .setPosition(808, 58)
    .setSize(78, 16)
    .setLabel("RESET BERRY")
    .setColorBackground(color(90, 55, 110))
    .setColorForeground(color(130, 80, 160))
    .setColorActive(color(190, 120, 220));

  btnPetaminxMode = cp5.addButton("PETAMINXMODE")
    .setPosition(892, 58)
    .setSize(150, 16)
    .setLabel("PETAMINX: OFF")
    .setColorBackground(color(35, 35, 48))
    .setColorForeground(color(55, 95, 115))
    .setColorActive(color(90, 170, 190));
  initPetaminxExperimentalModes();
    
    
  // Solar bridge listens for a lightweight local UDP feed from solar_weather_bridge.py.
  // It is visual-only until SOLAR→SYNTH is enabled.
  try {
    solarBridge = new SolarDataBridge(5060);
    solarBridge.start();
    statusMsg = statusMsg + " | Solar UDP :5060";
  } catch (Exception e) {
    println("Solar bridge failed to start: " + e);
    solarBridge = null;
  }

  // Ocean bridge listens for NOAA CO-OPS tide/temperature packets from ocean_current_bridge.py.
  // It restores sensed environmental modulation through water temperature/current packets.
  try {
    oceanBridge = new OceanDataBridge(5062);
    oceanBridge.start();
    statusMsg = statusMsg + " | Ocean UDP :5062";
  } catch (Exception e) {
    println("Ocean bridge failed to start: " + e);
    oceanBridge = null;
  }

  // Surface bridge listens for lightweight manifold/import surface packets from surface_sender.py.
  // This is drawn as an overlay inside the Resolution Orbit panel.
  try {
    surfaceBridge = new SurfaceDataBridge(5056);
    surfaceBridge.start();
    statusMsg = statusMsg + " | Surface UDP :5056";
  } catch (Exception e) {
    println("Surface bridge failed to start: " + e);
    surfaceBridge = null;
  }

  buildSynthControls();
galaxyMapInit();
buildGalaxyControls();
  initMidiPilot();
  // Logging is now manual. Continuous auto-logging was a major Raspberry Pi bottleneck.
  // Press REC DATA when you want a full experiment CSV captured.
  oscLoggingEnabled = false;
  adiabaticTracker = new AdiabaticTracker();
  berryTracker = new BerryPhaseTracker();
  createHolonomySweepControls(HOLO_PANEL_X, HOLO_PANEL_Y);
  // ── PhiFieldEngine init (§5 radial table, §9 step size) ──────────────────
  phiEngine.A   = 0.5;    // coupling constant A = 4πG₀/c⁴ in RDFT units
  phiEngine.mu  = 0.08;   // base recursion step (§9 practical notes)
  phiEngine.rebuildRadialTable(0.3);  // initial S estimate ≈ typical avgBright
  floquetShaperInit();
  criticalDetector = new CriticalSlowingDetector();
  stateCartographer = new RecursiveStateSpaceCartographer();
  statusMsg = statusMsg + " | BCI slot reserved";
  if (CHLADNI_SPHERE_UI) {
    applyChladniControlLayout();
  }
}


// ============================================================
// SURFACE SENDER CONTROL
// Sends plain UDP text commands to surface_sender.py on port 5057.
// This is intentionally raw UDP, not OSC, because the Python sender listens
// for simple text commands: SURFACE_TOGGLE and SURFACE_MODE_NEXT.
// ============================================================
void initSurfaceControl() {
  try {
    surfaceUdpSocket = new java.net.DatagramSocket();
    surfaceUdpHost = java.net.InetAddress.getByName("127.0.0.1");
    surfaceControlReady = true;
    surfaceControlStatus = "SURFACE CTRL: 127.0.0.1:" + SURFACE_CONTROL_PORT;
    println(surfaceControlStatus);
  } catch (Exception e) {
    surfaceControlReady = false;
    surfaceControlStatus = "SURFACE CTRL FAILED";
    println("Surface control UDP failed: " + e);
  }
}

void sendSurfaceCommand(String cmd) {
  if (!surfaceControlReady || surfaceUdpSocket == null || surfaceUdpHost == null) {
    println("Surface command skipped, UDP not ready: " + cmd);
    return;
  }
  try {
    byte[] buf = cmd.getBytes("UTF-8");
    java.net.DatagramPacket packet = new java.net.DatagramPacket(
      buf,
      buf.length,
      surfaceUdpHost,
      SURFACE_CONTROL_PORT
    );
    surfaceUdpSocket.send(packet);
    println("Surface command -> " + cmd);
  } catch (Exception e) {
    println("Surface command failed: " + cmd + " / " + e);
  }
}

void LADDER(int val) {
  if (ladderActive) {
    ladderAbort("operator stop");
    return;
  }

  if (holoSweep == null) {
    statusMsg = "LADDER: sweep instrument not ready.";
    return;
  }
  if (!envFloquetFrozen) {
    statusMsg = "LADDER: freeze the environment first (ENV: FROZEN).";
    return;
  }
  if (!ladderSurfAck) {
    ladderSurfAck = true;
    statusMsg = "LADDER: confirm SURF mode is ON, then press AREA LADDER again.";
    return;
  }

  ladderActive = true;
  ladderRung = 0;
  ladderStage = 0;
  ladderStageMs = millis();
  ladderStatus = "ladder: starting (" + LADDER_PRESET.length + " rungs x " + LADDER_PAIRS + " pairs)";
  statusMsg = ladderStatus;
  updateLadderButton();
  ladderTick();
}

void LADDER() {
  LADDER(0);
}

void ladderAbort(String why) {
  if (holoSweep != null && holoSweep.orientRunActive) {
    holoSweep.orientAbort("ladder abort: " + why);
  }
  ladderActive = false;
  ladderStage = 0;
  ladderSurfAck = false;
  ladderStatus = "LADDER ABORTED: " + why;
  statusMsg = ladderStatus;
  println("[Ladder] ABORTED: " + why);
  updateLadderButton();
}

void ladderFinish() {
  ladderActive = false;
  ladderStage = 0;
  ladderSurfAck = false;
  ladderStatus = "LADDER COMPLETE: " + LADDER_PRESET.length + " rungs logged.";
  statusMsg = ladderStatus;
  println("[Ladder] COMPLETE");
  updateLadderButton();
}

void ladderTick() {
  if (!ladderActive || holoSweep == null) return;

  if (!envFloquetFrozen) {
    ladderAbort("environment unfrozen mid-ladder");
    return;
  }

  if (ladderStage == 0) {
    float[] r = LADDER_PRESET[ladderRung];
    boolean ok = holoSweep.orientLaunchWith(r[0], r[1], (int)r[2], (int)r[3],
                                            LADDER_LEGT, LADDER_DWELL, LADDER_PAIRS, r[4]);
    if (!ok) {
      ladderAbort("rung " + (ladderRung + 1) + " area " + safeNf(r[4], 1, 1) + " failed to launch");
      return;
    }
    ladderStage = 1;
    ladderStatus = "ladder: rung " + (ladderRung + 1) + "/" + LADDER_PRESET.length
      + " area " + safeNf(r[4], 1, 1) + " running";
    statusMsg = ladderStatus;
    updateLadderButton();
    return;
  }

  if (ladderStage == 1) {
    if (!holoSweep.orientRunActive) {
      if (holoSweep.orientLastResult == -1) {
        ladderAbort("rung " + (ladderRung + 1) + " area "
          + safeNf(LADDER_PRESET[ladderRung][4], 1, 1) + " batch aborted");
        return;
      }
      ladderStage = 2;
      ladderStageMs = millis();
      ladderStatus = "ladder: rung " + (ladderRung + 1) + " complete, settling";
      statusMsg = ladderStatus;
      updateLadderButton();
    }
    return;
  }

  if (ladderStage == 2 && millis() - ladderStageMs >= LADDER_SETTLE_MS) {
    ladderRung++;
    if (ladderRung >= LADDER_PRESET.length) {
      ladderFinish();
      return;
    }
    ladderStage = 0;
  }
}

void updateLadderButton() {
  if (btnLadder == null) return;
  btnLadder.setLabel(ladderActive ? "STOP LADDER" : (ladderSurfAck ? "CONFIRM LADDER" : "AREA LADDER"));
  btnLadder.setColorBackground(ladderActive ? color(110, 45, 42) : (ladderSurfAck ? color(94, 80, 35) : color(45, 72, 96)));
}

void surfaceToggle() {
  sendSurfaceCommand("SURFACE_TOGGLE");
}

void surfaceToggle(int val) {
  surfaceToggle();
}

void surfaceMode() {
  sendSurfaceCommand("SURFACE_MODE_NEXT");
}

void surfaceMode(int val) {
  surfaceMode();
}

void surfaceTopo() {
  sendSurfaceCommand("SURFACE_SOURCE_TERRAIN");
}

void surfaceTopo(int val) {
  surfaceTopo();
}

void surfaceLocation() {
  sendSurfaceCommand("SURFACE_NEXT_LOCATION");
}

void surfaceLocation(int val) {
  surfaceLocation();
}

void buildSynthControls() {
  int x   = W - 280;
  int x2  = x + 128;
  int cw  = 116;
  int y   = PANEL_TOP;
  int sw  = 248;
  int sh  = 13;
  int dy  = 18;

  cp5.addTextlabel("synthTitle")
    .setText("AUDIO / SENSOR CONTROL")
    .setPosition(x, y - 18)
    .setColorValue(color(220));

  sliderRootFreq = cp5.addSlider("rootFreq")
    .setPosition(x, y)
    .setSize(cw - 58, sh)
    .setRange(20, 880)
    .setValue(55)
    .setLabel("Root Freq");

  fieldRootFreq = cp5.addTextfield("rootFreqBox")
    .setPosition(x + cw - 54, y)
    .setSize(52, sh)
    .setText("55.0")
    .setAutoClear(false)
    .setLabel("");

  sliderAmp = cp5.addSlider("masterAmp")
    .setPosition(x, y + dy)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.72)
    .setLabel("Master Amp");

  sliderReverb = cp5.addSlider("reverbMix")
    .setPosition(x, y + dy*2)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.35)
    .setLabel("Reverb");

  sliderOrbSensitivity = cp5.addSlider("orbSensitivity")
    .setPosition(x, y + dy*3)
    .setSize(cw, sh)
    .setRange(0.1, 3.0)
    .setValue(1.0)
    .setLabel("Orb Sens");

  cp5.addSlider("droneVolume")
    .setPosition(x, y + dy*4)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.20)
    .setLabel("Drone Vol");

  cp5.addSlider("arpVolume")
    .setPosition(x, y + dy*5)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.20)
    .setLabel("Arp Vol");

  cp5.addSlider("arpRate")
    .setPosition(x, y + dy*6)
    .setSize(cw, sh)
    .setRange(0.1, 1.5)   // whole slider now operates in the slow-spacious zone
    .setValue(0.4)
    .setLabel("Arp Rate");

  cp5.addSlider("glassVolume")
    .setPosition(x, y + dy*7)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.20)
    .setLabel("Glass Vol");

  // Choir Vol slider removed from left column — it lives under Solar Vol in the right column below

  // ── Toggle column (left of sliders) ──────────────────────────────────
  // Drone arm/spawn/kill
  toggleDrone = cp5.addToggle("droneOn")
    .setPosition(x - 46, y + dy*7 + 3)
    .setSize(40, 16)
    .setValue(false)
    .setLabel("DRONE ARM");

  btnDroneSpawn = cp5.addButton("SPAWNDRONE")
    .setPosition(x - 46, y + dy*6 + 3)
    .setSize(40, 16)
    .setLabel("FLQ ON")
    .setColorBackground(color(28, 92, 68));

btnDroneKill = cp5.addButton("KILLDRONE")
    .setPosition(x - 46, y + dy*5 + 3)
    .setSize(40, 16)
    .setLabel("FLQ OFF")
    .setColorBackground(color(115, 35, 35));

  toggleArp = cp5.addToggle("arpOn")
    .setPosition(x - 46, y + dy*8 + 3)
    .setSize(40, 16)
    .setValue(true)
    .setLabel("ARP");

  toggleGlass = cp5.addToggle("glassOn")
    .setPosition(x - 46, y + dy*9 + 3)
    .setSize(40, 16)
    .setValue(true)
    .setLabel("GLASS");

  // Choir toggle back in left column, under GLASS
  cp5.addToggle("choirOn")
    .setPosition(x - 46, y + dy*10 + 3)
    .setSize(40, 16)
    .setValue(true)
    .setLabel("CHOIR");

  toggleGhost = cp5.addToggle("ghostOn")
    .setPosition(x - 46, y + dy*11 + 3)
    .setSize(40, 16)
    .setValue(true)
    .setLabel("GHOST");

  // ── Ocean / Solar column ──────────────────────────────────────────────
  cp5.addTextlabel("sensorTitle")
    .setText("OCEAN / SOLAR")
    .setPosition(x2, y - 18)
    .setColorValue(color(170, 230, 220));

  cp5.addSlider("oceanCurrentBias")
    .setPosition(x2, y)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(oceanCurrentBias)
    .setLabel("Ocean Current");

  cp5.addSlider("oceanSwellDepth")
    .setPosition(x2, y + dy)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(oceanSwellDepth)
    .setLabel("Swell Depth");

  cp5.addSlider("oceanVolumeBias")
    .setPosition(x2, y + dy*2)
    .setSize(cw, sh)
    .setRange(0.0, 0.05)
    .setValue(oceanVolumeBias)
    .setLabel("Ocean Vol");

  btnSolar = cp5.addButton("SOLAR")
    .setPosition(x2, y + dy*3 + 3)
    .setSize(cw, 18)
    .setLabel("SOLAR: OFF")
    .setColorBackground(color(85, 55, 25))
    .setColorForeground(color(140, 90, 35))
    .setColorActive(color(220, 150, 60));

  sliderSolarVolume = cp5.addSlider("solarDroneVolume")
    .setPosition(x2, y + dy*4 + 5)
    .setSize(cw, sh)
    .setRange(0.0, 0.12)
    .setValue(solarDroneVolume)
    .setLabel("Solar Vol");

  // Choir Vol slider lives here in the right column, directly under Solar Vol
  cp5.addSlider("choirVolume")
    .setPosition(x2, y + dy*5 + 5)
    .setSize(cw, sh)
    .setRange(0.0, 1.0)
    .setValue(0.20)
    .setLabel("Choir Vol");

  cp5.addTextlabel("ecoTitle")
    .setText("ECO LAYERS")
    .setPosition(x2, y + dy*6 + 2)
    .setColorValue(color(175, 230, 185));

  toggleEcoChirp = cp5.addToggle("ecoChirpOn")
    .setPosition(x2, y + dy*7)
    .setSize(36, 14)
    .setValue(true)
    .setLabel("CHIRP");
  cp5.addSlider("ecoChirpLevel")
    .setPosition(x2 + 44, y + dy*7)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.58)
    .setLabel("Chirp");

  toggleEcoCall = cp5.addToggle("ecoCallOn")
    .setPosition(x2, y + dy*8)
    .setSize(36, 14)
    .setValue(true)
    .setLabel("CALL");
  cp5.addSlider("ecoCallLevel")
    .setPosition(x2 + 44, y + dy*8)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.58)
    .setLabel("Call");

  toggleEcoGrowth = cp5.addToggle("ecoGrowthOn")
    .setPosition(x2, y + dy*9)
    .setSize(36, 14)
    .setValue(true)
    .setLabel("GROW");
  cp5.addSlider("ecoGrowthLevel")
    .setPosition(x2 + 44, y + dy*9)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.64)
    .setLabel("Growth");

  toggleEcoFissure = cp5.addToggle("ecoFissureOn")
    .setPosition(x2, y + dy*10)
    .setSize(36, 14)
    .setValue(true)
    .setLabel("FISS");
  cp5.addSlider("ecoFissureLevel")
    .setPosition(x2 + 44, y + dy*10)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.64)
    .setLabel("Fissure");

  toggleEGProbe = cp5.addToggle("egProbeOn")
    .setPosition(x2, y + dy*11)
    .setSize(36, 14)
    .setValue(true)
    .setLabel("EG");
  cp5.addSlider("egProbeLevel")
    .setPosition(x2 + 44, y + dy*11)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.72)
    .setLabel("Probe");

  toggleMidiPoly = cp5.addToggle("midiPolyOn")
    .setPosition(x2, y + dy*12)
    .setSize(36, 14)
    .setValue(false)
    .setLabel("POLY");
  cp5.addSlider("midiPolyVolume")
    .setPosition(x2 + 44, y + dy*12)
    .setSize(cw - 44, sh)
    .setRange(0.0, 1.0)
    .setValue(0.55)
    .setLabel("Keys");

// ── Header dropdown row ───────────────────────────────────────────────
  int sx  = 640;
  int sy  = 18;
  int sel_w = 110;
  int sel_gap = 8;

  cp5.addTextlabel("scaleLabel")
    .setText("SCALE")
    .setPosition(sx, sy - 10)
    .setColorValue(color(180, 220, 200));

  menuScale = cp5.addScrollableList("scaleSelect")
    .setPosition(sx, sy)
    .setSize(sel_w, 88)
    .setBarHeight(16)
    .setItemHeight(14)
    .addItems(new String[] {
      "Lydian", "Major", "Pentatonic", "Whole Tone", "Minor", "Dorian",
      "Phrygian", "Mixolydian", "Minor Pentatonic", "Blues",
      "Harmonic Minor", "Melodic Minor", "Chromatic"
    })
    .setValue(0)
    .setLabel("Scale");

  cp5.addTextlabel("modLabel")
    .setText("MOD SOURCE")
    .setPosition(sx + sel_w + sel_gap, sy - 10)
    .setColorValue(color(180, 200, 220));

  menuModSource = cp5.addScrollableList("modSource")
    .setPosition(sx + sel_w + sel_gap, sy)
    .setSize(sel_w, 88)
    .setBarHeight(16)
    .setItemHeight(14)
    .addItems(MODE_NAMES)
    .setValue(3)
    .setLabel("Mod Source");
  styleSliderLabel("rootFreq");
  styleSliderLabel("masterAmp");
  styleSliderLabel("reverbMix");
  styleSliderLabel("orbSensitivity");
  styleSliderLabel("droneVolume");
  styleSliderLabel("arpVolume");
  styleSliderLabel("arpRate");
  styleSliderLabel("glassVolume");
  styleSliderLabel("choirVolume");
  styleSliderLabel("oceanCurrentBias");
  styleSliderLabel("oceanSwellDepth");
  styleSliderLabel("oceanVolumeBias");
  styleSliderLabel("solarDroneVolume");
  styleSliderLabel("ecoChirpLevel");
  styleSliderLabel("ecoCallLevel");
  styleSliderLabel("ecoGrowthLevel");
  styleSliderLabel("ecoFissureLevel");
  styleSliderLabel("egProbeLevel");
  styleSliderLabel("midiPolyVolume");
}

void applyChladniControlLayout() {
  chHide("CONNECT");
  chHide("PUSH");
  chHide("synthTitle");
  chHide("sensorTitle");
  chHide("ecoTitle");
  chHide("scaleLabel");
  chHide("modLabel");
  chHide("sweepTitle");
  chHide("galaxyTitle");
  chHide("galaxyBlendAmt");
  chHide("galaxySelect");
  chHide("RELOADGALAXY");
  chHide("galaxyStatusField");
  chHide("hsTitle");
  chHide("PETAMINXMODE");

  int h = 14;
  int rx = CH_RIGHT_X + 14;
  int ry = CH_SPHERE_Y + 44;
  int rw = CH_RIGHT_W - 28;
  int gap = 8;
  int bw = (rw - gap) / 2;
  chPlace("LADDER", rx, ry, rw, 22, ladderActive ? "STOP LADDER" : (ladderSurfAck ? "CONFIRM LADDER" : "AREA LADDER"));
  chPlace("COMPUTE", rx, ry + 30, bw, 24, "RUN");
  chPlace("RESETORBIT", rx + bw + gap, ry + 30, bw, 24, "RESET");
  chPlace("ANIMATE", rx, ry + 62, bw, 24, "HOLD");
  chPlace("STARTSWEEP", rx + bw + gap, ry + 62, bw, 24, "SWEEP");

  int sweepY = ry + 100;
  chPlace("sweepAlphaTargetBox", rx, sweepY, 62, 18, "");
  chPlace("sweepDepthTargetBox", rx + 70, sweepY, 54, 18, "");
  chPlace("sweepDurationBox", rx + 132, sweepY, 62, 18, "");

  int holoY = ry + 146;
  int hb = (rw - gap * 2) / 3;
  chPlace("HSRUN", rx, holoY, hb, 22, "HOLO");
  chPlace("HSRUNREV", rx + hb + gap, holoY, hb, 22, "REV");
  chPlace("HSORIENT", rx + (hb + gap) * 2, holoY, hb, 22, "ORIENT");
  chPlace("HSSTOP", rx, holoY + 28, hb, 22, "STOP");
  chPlace("HSLAGPAUSE", rx + hb + gap, holoY + 28, hb, 22, "LAG");
  chPlace("HSFREEZE", rx + (hb + gap) * 2, holoY + 28, hb, 22, "FREEZE");

  int rsy = ry + 236;
  chPlace("masterAmp", rx, rsy, rw, h, "OUT");
  chPlace("reverbMix", rx, rsy + 22, rw, h, "REVERB");
  chPlace("orbSensitivity", rx, rsy + 44, rw, h, "ACTION");
  int tg = 3;
  int tw = max(38, (rw - tg * 5) / 6);
  int toggleY = rsy + 76;
  chPlace("droneOn", rx, toggleY, tw, 16, "DRONE");
  chPlace("arpOn", rx + (tw + tg), toggleY, tw, 16, "ARP");
  chPlace("glassOn", rx + (tw + tg) * 2, toggleY, tw, 16, "GLASS");
  chPlace("choirOn", rx + (tw + tg) * 3, toggleY, tw, 16, "CHOIR");
  chPlace("ghostOn", rx + (tw + tg) * 4, toggleY, tw, 16, "GHOST");
  chPlace("midiPolyOn", rx + (tw + tg) * 5, toggleY, tw, 16, "POLY");
  chPlace("SPAWNDRONE", rx, toggleY + 28, bw, 22, "FLQ ON");
  chPlace("KILLDRONE", rx + bw + gap, toggleY + 28, bw, 22, "FLQ OFF");

  int selectY = toggleY + 66;
  int selectW = (rw - gap) / 2;
  chPlace("scaleSelect", rx, selectY, selectW, 86, "SCALE");
  chPlace("modSource", rx + selectW + gap, selectY, selectW, 86, "MOD");

  int geomY = selectY + 104;
  chPlace("FIELDCONFIG", rx, geomY, 68, 18, "FIELD");
  chPlace("surfaceToggle", rx + 76, geomY, 52, 18, "SURF");
  chPlace("surfaceMode", rx + 136, geomY, 52, 18, "NEXT");
  chPlace("surfaceTopo", rx, geomY + 24, 52, 18, "TOPO");
  chPlace("surfaceLocation", rx + 60, geomY + 24, 52, 18, "LOC");

  int fieldX = CH_MAIN_X + 18;
  int fieldY = CH_BOTTOM_Y + 34;
  chPlace("depth", fieldX, fieldY, 126, h, "DEPTH");
  chPlace("depthBox", fieldX + 136, fieldY - 2, 48, 18, "");
  chPlace("alpha", fieldX, fieldY + 22, 126, h, "ALPHA");
  chPlace("alphaBox", fieldX + 136, fieldY + 20, 48, 18, "");
  chPlace("orb_gamma", fieldX, fieldY + 44, 126, h, "Q-DAMP");
  chPlace("gammaBox", fieldX + 136, fieldY + 42, 48, 18, "");
  chPlace("rootFreq", fieldX, fieldY + 66, 126, h, "F0");
  chPlace("rootFreqBox", fieldX + 136, fieldY + 64, 48, h, "");
  chPlace("APPLYPARAMS", fieldX + 136, fieldY + 88, 48, 18, "APPLY");

  int holoX = CH_MAIN_X + 242;
  int hf = 50;
  int hg = 8;
  chPlace("hsA0", holoX, fieldY + 6, hf, 18, "");
  chPlace("hsA1", holoX + (hf + hg), fieldY + 6, hf, 18, "");
  chPlace("hsD0", holoX + (hf + hg) * 2, fieldY + 6, hf, 18, "");
  chPlace("hsD1", holoX + (hf + hg) * 3, fieldY + 6, hf, 18, "");
  chPlace("hsLegTime", holoX, fieldY + 54, hf, 18, "");
  chPlace("hsDwell", holoX + (hf + hg), fieldY + 54, hf, 18, "");
  chPlace("hsLoops", holoX + (hf + hg) * 2, fieldY + 54, hf, 18, "");
  chPlace("hsFieldPairs", holoX + (hf + hg) * 3, fieldY + 54, hf, 18, "");

  int mixX = CH_MAIN_X + 500;
  chPlace("droneVolume", mixX, fieldY, 190, h, "DRONE");
  chPlace("arpVolume", mixX, fieldY + 18, 190, h, "ARP");
  chPlace("arpRate", mixX, fieldY + 36, 190, h, "ARP RATE");
  chPlace("glassVolume", mixX, fieldY + 54, 190, h, "GLASS");
  chPlace("choirVolume", mixX, fieldY + 72, 190, h, "CHOIR");
  chPlace("midiPolyVolume", mixX, fieldY + 90, 190, h, "KEYS");

  int ecoX = CH_MAIN_X + 732;
  chPlace("ecoChirpOn", ecoX, fieldY, 58, 16, "CHIRP");
  chPlace("ecoChirpLevel", ecoX + 66, fieldY, 172, h, "CHIRP LVL");
  chPlace("ecoCallOn", ecoX, fieldY + 22, 58, 16, "CALL");
  chPlace("ecoCallLevel", ecoX + 66, fieldY + 22, 172, h, "CALL LVL");
  chPlace("ecoGrowthOn", ecoX, fieldY + 44, 58, 16, "GROWTH");
  chPlace("ecoGrowthLevel", ecoX + 66, fieldY + 44, 172, h, "GROW LVL");
  chPlace("ecoFissureOn", ecoX, fieldY + 66, 58, 16, "FISSURE");
  chPlace("ecoFissureLevel", ecoX + 66, fieldY + 66, 172, h, "FISS LVL");
  chPlace("egProbeOn", ecoX, fieldY + 88, 58, 16, "EG");
  chPlace("egProbeLevel", ecoX + 66, fieldY + 88, 172, h, "EG LVL");

  int envX = CH_MAIN_X + 1006;
  chPlace("oceanCurrentBias", envX, fieldY, 172, h, "CURRENT");
  chPlace("oceanSwellDepth", envX, fieldY + 18, 172, h, "SWELL");
  chPlace("oceanVolumeBias", envX, fieldY + 36, 172, h, "OCEAN VOL");
  chPlace("solarDroneVolume", envX, fieldY + 54, 172, h, "SOLAR VOL");
  chPlace("SOLAR", envX, fieldY + 80, 44, 18, "SOLAR");
  chPlace("RECORDDATA", envX + 50, fieldY + 80, 42, 18, "REC");
  chPlace("RESETBERRY", envX + 98, fieldY + 80, 44, 18, "BERRY");

  int galaxyX = chEngSliderX();
  int galaxyY = CH_SPHERE_Y + 526;
  int galaxyW = chEngSliderW();
  chPlace("galaxySelect", galaxyX, galaxyY, 104, 66, "GALAXY");
  chPlace("galaxyBlendAmt", galaxyX + 112, galaxyY, galaxyW - 112, h, "GAL BLEND");
  chPlace("RELOADGALAXY", galaxyX + 112, galaxyY + 28, galaxyW - 112, 18, "RELOAD");
  chPlace("galaxyStatusField", galaxyX + 112, galaxyY + 52, galaxyW - 112, 18, "");
}

void chPlace(String name, int x, int y, int w, int h, String label) {
  if (cp5 == null) return;
  try {
    Controller c = cp5.getController(name);
    if (c == null) return;
    c.setVisible(true);
    c.setPosition(x, y);
    c.setSize(w, h);
    if (label != null) c.setLabel(label);
  } catch (Exception e) {
    println("Chladni layout skipped control " + name + ": " + e);
  }
}

void chHide(String name) {
  if (cp5 == null) return;
  try {
    Controller c = cp5.getController(name);
    if (c != null) c.setVisible(false);
  } catch (Exception e) {
    // Some ControlP5 labels are not normal controllers on every build.
  }
}


// ============================================================
void draw() {
  background(18, 18, 24);
  applyMidiPilotUpdate();
  launchpadUpdateMomentarySafeties();

  // Sync root freq textfield to slider (when slider is moved)
  if (sliderRootFreq != null && fieldRootFreq != null) {
    float sliderFreq = sliderRootFreq.getValue();
    try {
      float boxVal = Float.parseFloat(fieldRootFreq.getText().trim());
      if (abs(boxVal - sliderFreq) > 0.5 && !fieldRootFreq.isFocus()) {
        fieldRootFreq.setText(safeNf(sliderFreq, 1, 1));
      }
    } catch (Exception e) {
      if (!fieldRootFreq.isFocus()) fieldRootFreq.setText(safeNf(sliderFreq, 1, 1));
    }
  }

  holoSweep.update();
  ladderTick();
  if (adiabaticTracker != null) adiabaticTracker.update();

  if (animating && sweepReady && !sweepBuilding && sweepCache != null && sweepAlphas != null) {
    animFrameCounter++;
    if (animFrameCounter >= ANIM_SPEED) {
      animFrameCounter = 0;
      sweepIdx += sweepDir;
      if (sweepIdx >= SWEEP_STEPS) {
        sweepIdx = SWEEP_STEPS - 2;
        sweepDir = -1;
      }
      if (sweepIdx < 0) {
        sweepIdx = 1;
        sweepDir = 1;
      }
    }
  }

  for (int s = 0; s < ORB_STEPS_PER_FRAME; s++) {
    stepOrbit();
  }
  updateOrbitEventDetector();
  
  // Hyperbolic runtime protection
  float currentOrbitalRadius = sqrt(orb_x * orb_x + orb_y * orb_y);
  float currentOrbitalSpeed = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);

  hyperbolicMode = currentOrbitalRadius > 3.5 || currentOrbitalSpeed > 6.0 || orbitEccentricity > 0.9;
  skipHeavyPanels = hyperbolicMode;

  if (CHLADNI_SPHERE_UI) {
    drawChladniSphereMode();
  } else {
    drawPanel(dominant, PX0, PANEL_TOP, PANEL_W, PANEL_H, cmap_plasma, "DOMINANT LAYER MAP");
    drawPanel(combined, PX1, PANEL_TOP, PANEL_W, PANEL_H, cmap_viridis, "TOTAL DIFF FIELD");
    drawCrossSection(PX2, PANEL_TOP, PANEL_W, PANEL_H);
    drawSweepPanel(PX3, PANEL_TOP, PANEL_W, PANEL_H);
    drawOrbitalPanel(PX4, PANEL_TOP, PANEL_W, PANEL_H);

    // Always-on lightweight interpretation layer. These panels replace the heavy
    // separate Node/Material windows during normal performance, so the audio mapping
    // keeps running while the GUI does less work.
    drawEmbeddedInterpretationLayer();

    if (!skipHeavyPanels) {
      drawGalaxyLowerBand();
      drawSolarNodePanel(W - 280, H - 190, 248, 168);
      drawFloquetShaperPanel(W - 280, H - 360, 248, 160);
      drawGalaxyImagePanel(W - 280, H - 560, 248, 185);
    } else {
      drawHyperbolicSafetyBadge(W - 280, H - 560, 248, 185);
    }

    drawPerformanceFooter();
    drawPetaminxExperimentalOverlay();
    drawHeader();
    //drawEngineeringControls();
      // Matrix mirror hidden in this layout to keep the right-side synth strip clear.
      // The underlying matrix frame is still computed for compatibility.
      drawRDTShellReadouts();
      drawHolonomySweepPanel(HOLO_PANEL_X, HOLO_PANEL_Y, HOLO_PANEL_W, HOLO_PANEL_H);
  }

if (!hyperbolicMode || frameCount % 6 == 0) {
  updateSolarBridge();
  updateOceanBridge();
}

if (frameCount % 2 == 0) {
  updateSurfaceBridge();
  updateSurfacePhysics();   // Landauer + quantum eraser surface→field coupling
}

  // Embedded NODE readouts are drawn in the main GUI now.
  // No separate node-window sync is needed, reducing redraw/GPU load.

  // Embedded MATERIAL topology readouts are drawn in the main GUI now.
  // No separate material-window sync is needed, reducing redraw/GPU load.

  if (connected && currentMode % 4 == 3 && frameCount % 6 == 0) {
    PUSH(0);
  }

   if (!hyperbolicMode && frameCount % 4 == 0) {
  updateElectroGravity();
  syncFieldConfigPanel();
  floquetShaperUpdate();
}

   if (frameCount % 8 == 0) {
    sendRDFToSuperCollider();
    sendCTCStateToSuperCollider();
    sendGalaxyToSuperCollider();
    sendModeParameters();
    sendFoundationalToSuperCollider();
    sendSolarToSuperCollider();
    sendOceanToSuperCollider();
    sendOrbitEventToSuperCollider();
  }

  // Advanced trackers stay live for the node visualizer, but logging is manual and buffered.
  if (frameCount % METRIC_UPDATE_EVERY_N_FRAMES == 0) {
    updateCurrentMetricsOnly();
    updatePhiEngine();
    updateCTCChannel();
    applyGalaxyTopologyToField();
    updateAdvancedRDTrackers();
  }

  if (oscLoggingEnabled && frameCount % LOG_EVERY_N_FRAMES == 0) {
    logOscStateFrame();
  }

  if (holoSweep != null) {
    holoSweep.orientTick();
  }

  if (!sweepReady) {
    fill(0, 0, 0, 160);
    noStroke();
    rect(PX3, PANEL_TOP, PANEL_W, PANEL_H);
    fill(150, 100, 255);
    textSize(11);
    textAlign(CENTER, CENTER);
    int dots = (frameCount / 15) % 4;
    String lbl = "BUILDING CACHE";
    for (int i = 0; i < dots; i++) lbl += ".";
    text(lbl, PX3 + PANEL_W / 2, PANEL_TOP + PANEL_H / 2);
  }
}

void drawHyperbolicSafetyBadge(float x, float y, float w, float h) {
  pushStyle();
  noStroke();
  fill(30, 18, 24, 230);
  rect(x, y, w, h, 14);

  fill(255, 120, 80);
  textAlign(LEFT, TOP);
  textSize(13);
  text("HYPERBOLIC SAFETY MODE", x + 14, y + 14);

  fill(220);
  textSize(11);
  text("Heavy visual panels throttled", x + 14, y + 40);
  text("Physics/orbit remains active", x + 14, y + 58);
  text("radius/speed/eccentricity high", x + 14, y + 76);

  popStyle();
}



// ============================================================
// EMBEDDED RDFT INTERPRETATION LAYER
// Lightweight, always-on Materials + Nodes readouts for Raspberry Pi 400.
// These panels use simple 2D procedural glyphs instead of full separate-window redraws.
// They remain true to the RDFT idea: material/topology is an interpretive layer
// over recursive distinction fields, not a separate display dependency.
// ============================================================
void drawEmbeddedInterpretationLayer() {
  int y = PANEL_TOP + PANEL_H + 18;
  int lowerBandY = H - 214;
  int h = lowerBandY - y - 12;
  if (h < 150) return;
  int contentRight = W - 300;
  int x1 = 20;
  int gap = 8;
  int wCol = (contentRight - x1 - 20 - gap * 3) / 4;
  int x2 = x1 + wCol + gap;
  int x3 = x2 + wCol + gap;
  int x4 = x3 + wCol + gap;  // kept to avoid parse error; slot consumed by spectral module

  drawEmbeddedMaterialPanel(x1, y, wCol, h);
  drawEmbeddedNodesPanel(x2, y, wCol, h);
  drawSpectralGeometryModule(x3, y, wCol*2 + gap, h);
}

void rdfPanelFrame(int x, int y, int w, int h, String title) {
  fill(9, 12, 18, 218);
  stroke(55, 95, 105, 160);
  rect(x, y, w, h, 10);
  fill(135, 235, 220);
  textSize(10);
  textAlign(LEFT, TOP);
  text(title, x + 12, y + 8);
}

void drawEmbeddedMaterialPanel(int x, int y, int w, int h) {
  rdfPanelFrame(x, y, w, h, "MATERIAL / TOPOLOGIC INTERPRETATION LAYER");

  String mat = materialCycleName();
  float fd = constrain(metricFractalDim, 0, 3);
  float fdNorm = constrain((fd - 1.0) / 1.2, 0, 1);
  float surfaceProxy = constrain(fdNorm * 0.62 + metricEntropy * 0.08 + depth * 0.035, 0, 1);
  float stiffnessProxy = constrain(1.0 - metricLyapunov * 0.8 + envFloquetCoupling() * 0.25, 0, 1);
  float absorptionProxy = constrain(metricKLDivergence * 1.5 + (1.0 - stiffnessProxy) * 0.55 + envFloquetQuasienergy() * 0.25, 0, 1);

  int top = y + 34;
  int glyphX = x + 14;
  int glyphW = min(230, max(175, w / 3));
  int glyphH = max(130, h - 72);
  drawBrachistochroneGlyph(glyphX, top, glyphW, glyphH);

  int iconX = glyphX + glyphW + 14;
  int iconY = top + 4;
  int iconAreaW = w - (iconX - x) - 14;
  int iconR = max(24, min(34, iconAreaW / 12));
  String[] names = {"B-GYROID", "B-DIAMOND", "B-IWP", "B-BCC", "BRACH"};
  int active = constrain((int(menuModSource.getValue()) + depth + int(fd * 2.0)) % names.length, 0, names.length - 1);
  // Only the active topology is shown. Others are hidden.
  // Active icon is centered in the full icon area and drawn larger.
  float cx = iconX + iconAreaW * 0.5;
  float cy = iconY + 58;
  int activeR = iconR + 18;
  drawTPMSIconEmbedded(cx, cy, activeR, active, true);
  fill(235, 255, 180);
  textAlign(CENTER, TOP);
  textSize(9);
  text(names[active], cx, cy + activeR + 8);

  // Draw inactive names as a small dim legend row beneath.
  textSize(7);
  for (int i = 0; i < names.length; i++) {
    if (i == active) continue;
    float lx = iconX + iconAreaW * (i + 0.5) / names.length;
    fill(70, 85, 80);
    textAlign(CENTER, TOP);
    text(names[i], lx, iconY + 118);
  }

  int traceX = iconX;
  int traceY = iconY + 118;
  int traceW = iconAreaW;
  int traceH = max(42, h - 205);
  drawTopologyTrace(traceX, traceY, traceW, traceH);

  int readY = y + h - 92;
  int readW = max(110, (w - 48) / 2);
  drawMiniReadout(x + 16, readY, readW, "fractal Df", fdNorm, safeNf(fd, 1, 3));
  drawMiniReadout(x + 16, readY + 26, readW, "surface / volume", surfaceProxy, safeNf(surfaceProxy, 1, 3));
  drawMiniReadout(x + 30 + readW, readY, readW, "stiffness", stiffnessProxy, safeNf(stiffnessProxy, 1, 3));
  drawMiniReadout(x + 30 + readW, readY + 26, readW, "absorption", absorptionProxy, safeNf(absorptionProxy, 1, 3));

  fill(135, 165, 165);
  textSize(9);
  textAlign(LEFT, TOP);
  text("active topology: " + mat + " | B-gyroid response maps toward softer, shock-absorbing sonic transitions", x + 16, y + h - 28);
  text("Lissajous / orbital TPMS glyphs are interpretive, low-cost topology signatures reading the same RDFT field.", x + 16, y + h - 14);
}

float bsinTopo(float u) {
  return 1.104 * sin(u) + 0.01263 * sin(2*u) + 0.1408 * sin(3*u) + 0.0122 * sin(4*u) + 0.06373 * sin(5*u);
}

void drawTPMSIconEmbedded(float cx, float cy, float r, int type, boolean active) {
  pushMatrix();
  translate(cx, cy);
  float t0 = frameCount * 0.018 + orbitalPhi() * TWO_PI;
  strokeWeight(active ? 1.8 : 1.0);
  noFill();
  int strands = type == 4 ? 3 : 4;
  for (int s = 0; s < strands; s++) {
    beginShape();
    stroke(active ? color(110, 240, 170, 220) : color(80, 140, 120, 150));
    for (int i = 0; i <= 72; i++) {
      float a = TWO_PI * i / 72.0;
      float rr = r * 0.72;
      float vx = 0;
      float vy = 0;
      if (type == 0) { // gyroid-like flowing lissajous crossing
        vx = cos(a + s * HALF_PI) * rr + sin(2 * a + t0) * r * 0.20;
        vy = sin(a * 1.35 + s + t0*0.3) * rr * 0.72;
      } else if (type == 1) { // diamond crystalline diagonals
        vx = cos(a + s * HALF_PI) * rr;
        vy = sin(a + s * HALF_PI) * rr;
        if (i % 14 < 7) vx *= 0.62;
      } else if (type == 2) { // IWP walls
        vx = cos(a * 2 + s + t0*0.2) * rr * 0.72;
        vy = sin(a + s * HALF_PI) * rr;
      } else if (type == 3) { // BCC node network
        vx = cos(a + s * TWO_PI / 4.0) * rr * (0.7 + 0.24 * sin(3 * a));
        vy = sin(a + s * TWO_PI / 4.0) * rr * (0.7 + 0.24 * cos(3 * a));
      } else { // brachistochrone waveform cell
        vx = map(i, 0, 72, -rr, rr);
        vy = bsinTopo(map(i, 0, 72, -PI, PI) + s * 0.8 + t0) * r * 0.34 + (s - 1) * 9;
      }
      vertex(vx, vy);
    }
    endShape();
  }
  if (active) {
    noStroke();
    fill(255, 155, 70, 190);
    ellipse(cos(t0 * 2) * r * 0.45, sin(t0 * 1.4) * r * 0.35, 7, 7);
  }
  popMatrix();
}

void drawTopologyTrace(int x, int y, int w, int h) {
  if (h <= 10) return;
  fill(5, 16, 14, 160);
  stroke(35, 65, 55, 160);
  rect(x, y, w, h, 6);
  noFill();
  stroke(95, 210, 135, 185);
  beginShape();
  for (int i = 0; i < w; i += 2) {
    float u = map(i, 0, max(1, w-1), 0, TWO_PI * 2.0);
    float v = 0.5 + 0.35 * sin(u + metricFractalDim + frameCount*0.018) + 0.12 * sin(3*u + metricEntropy);
    vertex(x + i, y + h - constrain(v, 0, 1) * h);
  }
  endShape();
  fill(145, 170, 150);
  textAlign(LEFT, TOP);
  textSize(8);
  text("fractal/surface signature", x + 8, y + 6);
}

float orbitalPhi() {
  return orbResolutionField(sqrt(orb_x*orb_x + orb_y*orb_y));
}


void drawBrachistochroneGlyph(int x, int y, int w, int h) {
  pushMatrix();
  translate(x, y);
  noStroke();
  fill(0, 0, 0, 80);
  rect(0, 0, w, h, 8);
  stroke(35, 55, 60, 160);
  for (int gx = 0; gx <= w; gx += 18) line(gx, 0, gx, h);
  for (int gy = 0; gy <= h; gy += 18) line(0, gy, w, gy);

  float tPhase = frameCount * 0.018;
  for (int layer = 0; layer < 4; layer++) {
    float amp = (h * 0.16) * (1.0 - layer * 0.12);
    float yy = h * (0.28 + 0.15 * layer);
    stroke(80 + layer * 30, 220 - layer * 20, 190, 190);
    strokeWeight(1.2);
    noFill();
    beginShape();
    for (int i = 0; i < w; i += 3) {
      float u = map(i, 0, w, 0, TWO_PI * 1.15);
      // Fifth-order Fourier fit flavor: brachistochrone-inspired, lightweight.
      float b = 1.104*sin(u + tPhase) + 0.1408*sin(3*u + tPhase*0.7) + 0.06373*sin(5*u);
      vertex(i, yy + amp * b * 0.42);
    }
    endShape();
  }

  // TPMS-like node lattice overlay.
  float pulse = 0.45 + 0.55 * sin(frameCount * 0.025);
  for (int i = 16; i < w; i += 26) {
    for (int j = 18; j < h; j += 26) {
      float q = sin(i*0.04 + frameCount*0.02) + cos(j*0.05 - alpha);
      float r = 2.5 + 3.5 * constrain(abs(q) * 0.45 + metricEntropy * 0.12, 0, 1);
      fill(255, 140 + 80*pulse, 75, 55 + 70*constrain(metricKLDivergence*1.5,0,1));
      noStroke();
      ellipse(i, j, r, r);
    }
  }
  popMatrix();
}

void drawEmbeddedNodesPanel(int x, int y, int w, int h) {
  rdfPanelFrame(x, y, w, h, "SPECIALIZED RDFT NODES / FIELD DIAGNOSTICS");
  int rad = int(min(96, h / 3) * 0.6);
  int cx = x + 14 + rad;
  int cy = y + h / 2 + 8;


  // Berry / holonomy morph glyph.  Instead of only rotating, the path
  // changes topology by selected mode, active material cycle, entropy, KL,
  // and mutual-information coherence.  This gives intelligible state feedback
  // without reintroducing the heavy separate-window renderer.
  int modeIdx = int(menuModSource.getValue());
  int matIdx = (modeIdx + depth + int(metricFractalDim * 2.0)) % 5;
  float closure = constrain(1.0 - abs(metricBerryPhase), 0, 1);
  float disorder = constrain(metricEntropy / max(1.0, log(max(2, depth + 1)) / log(2)), 0, 1);
  float phase = frameCount * 0.012 + metricBerryPhase * TWO_PI;
  noFill();
  stroke(100, 160, 255, 105);
  strokeWeight(1);
  ellipse(cx, cy, rad*2, rad*2);
  stroke(230, 120, 255, 190);
  strokeWeight(1.4);
  beginShape();
  int lobes = 2 + (matIdx % 4) + max(0, modeIdx - 6) % 2;
  for (int i = 0; i < 144; i++) {
    float a = map(i, 0, 143, 0, TWO_PI);
    float lissX = cos(a * (1 + (matIdx % 3)) + phase) * rad * (0.48 + 0.22 * closure);
    float lissY = sin(a * (2 + (modeIdx % 4)) - phase * 0.7) * rad * (0.48 + 0.18 * metricMutualInfo);
    float rr = rad * (0.56 + 0.22 * sin(lobes*a + phase) + 0.12 * sin((lobes+2)*a + metricKLDivergence*9.0));
    float px = (matIdx == 0 || matIdx == 4) ? cx + lissX : cx + cos(a + phase*0.18) * rr;
    float py = (matIdx == 0 || matIdx == 4) ? cy + lissY : cy + sin(a - phase*0.12) * rr * (0.82 + disorder*0.28);
    if (matIdx == 2) { px += sin(3*a + phase) * rad * 0.14; }
    if (matIdx == 3) { py += cos(4*a - phase) * rad * 0.14; }
    vertex(px, py);
  }
  endShape(CLOSE);
  noStroke();
  fill(255, 170, 75, 210);
  float dotA = phase * (1.0 + metricMutualInfo);
  ellipse(cx + cos(dotA) * rad * (0.55 + 0.2*closure), cy + sin(dotA*1.3) * rad * (0.45 + 0.16*disorder), 7, 7);
  fill(210);
  textSize(10);
  textAlign(CENTER, TOP);
  text("Berry / Holonomy", cx, y + 10);
  fill(145, 170, 180);
  textSize(8);
  text("state " + MODE_NAMES[modeIdx] + " / " + materialCycleName(), cx, y + 22);

// Engineering controls in the middle column — 35% smaller to fit inside nodes panel
  drawEngineeringControlsInPanel(x + (rad*2 + 28), y + 8, 143, h - 16);

  int fx = x + 375;
  int fy = y + 40;
  int fw = max(160, w - 275);

  int ty = fy + 76;
  drawMiniReadout(fx, ty, fw, "entropy", constrain(metricEntropy / 3.0, 0, 1), safeNf(metricEntropy,1,3));
  drawMiniReadout(fx, ty + 26, fw, "KL divergence", constrain(metricKLDivergence * 2.0, 0, 1), safeNf(metricKLDivergence,1,4));
  drawMiniReadout(fx, ty + 52, fw, "mutual info", constrain(metricMutualInfo, 0, 1), safeNf(metricMutualInfo,1,3));
  drawMiniReadout(fx, ty + 78, fw, "Lyapunov", constrain(metricLyapunov, 0, 1), safeNf(metricLyapunov,1,3));
  drawMiniReadout(fx, ty + 104, fw, "quasi-energy", constrain(envFloquetQuasienergy(), 0, 1), safeNf(envFloquetQuasienergy(),1,3));

  fill(135, 165, 165);
  textSize(9);
  textAlign(LEFT, TOP);
  text("Node layer remains computationally live inside the single-window interface.", fx, y + h - 30);
  text("Displays are decimated/low-cost; audio mappings continue from the same recursive state vector.", fx, y + h - 16);
}

void drawFloquetMiniSpectrum(int x, int y, int w, int h) {
  fill(0, 0, 0, 80);
  stroke(45, 70, 75, 160);
  rect(x, y, w, h, 6);

  fill(160, 235, 220);
  textSize(10);
  textAlign(LEFT, TOP);
  text("Floquet temporal drive", x + 8, y + 6);

float phase = fsPhase;
float displayPhase = phase + frameCount * 0.04;
float k = envFloquetCoupling();
float eps = envFloquetQuasienergy();

  stroke(90, 220, 210, 190);
  noFill();
  beginShape();
  for (int i = 0; i < w - 16; i += 3) {
    float u = map(i, 0, w - 16, 0, TWO_PI * 2.0);
    float yy = y + h - 12 - (sin(u + displayPhase) * 0.5 + 0.5) * (h - 28) * (0.3 + 0.7 * k);
    vertex(x + 8 + i, yy);
  }
  endShape();

  // Orbital phase marker
  float ox = x + w - 32;
  float oy = y + 28;
  float orbitR = 16;

  noFill();
  stroke(60, 120, 130, 160);
  ellipse(ox, oy, orbitR * 2, orbitR * 2);
  

  float px = ox + cos(displayPhase) * orbitR;
float py = oy + sin(displayPhase) * orbitR;

  stroke(255, 210, 90, 120);
  line(ox, oy, px, py);

  fill(255, 210, 90, 220);
  noStroke();
  ellipse(px, py, 6, 6);

  fill(210);
  noStroke();
  text("phase=" + safeNf(phase,1,2) + "  k=" + safeNf(k,1,2) + "  eps=" + safeNf(eps,1,2), x + 8, y + h - 14);
}

void drawEngineeringControlsInPanel(int px, int py, int pw, int ph) {
  // Compact engineering controls sized to fit inside the nodes panel
  fill(9, 12, 18, 200);
  stroke(55, 95, 105, 160);
  rect(px, py, pw, ph, 8);
  
  fill(180, 240, 200);
  textSize(9);
  textAlign(LEFT, TOP);
  text("FIELD CONTROL", px + 8, py + 6);
  
  int y = py + 22;
  int dy = (ph - 28) / 9;
  int bw = pw - 16;
  
  drawCompactSlider(px + 8, y, bw, "OCEAN CURRENT",  oceanEngCurrentGain); y += dy;
  drawCompactSlider(px + 8, y, bw, "OCEAN SWELL",    oceanEngSwellAmp);    y += dy;
  drawCompactSlider(px + 8, y, bw, "OCEAN BREAK",    oceanEngBreakRate);   y += dy;
  drawCompactSlider(px + 8, y, bw, "ORBIT ECC",       orbitEccentricityBias); y += dy;
  drawCompactSlider(px + 8, y, bw, "RESONANCE",       orbitResonanceDrive); y += dy;
  drawCompactSlider(px + 8, y, bw, "LOCK",            orbitLockStrength);  y += dy;
  drawCompactSlider(px + 8, y, bw, "FLOQUET",         floquetDrive);       y += dy;
  drawCompactSlider(px + 8, y, bw, "INSTABILITY",     floquetInstability); y += dy;
  drawCompactSlider(px + 8, y, bw, "QUASI ENERGY",    quasiEnergyBias);
}

void mousePressed() {
  if (CHLADNI_SPHERE_UI && chladniModeMousePressed(mouseX, mouseY)) {
    return;
  }
  engDragSlider = getEngSliderAt(mouseX, mouseY);
  if (engDragSlider >= 0) {
    updateEngSlider(engDragSlider, mouseX);
  }
}

void mouseDragged() {
  if (engDragSlider >= 0) {
    updateEngSlider(engDragSlider, mouseX);
  }
}

void mouseReleased() {
  engDragSlider = -1;
}


int getEngSliderAt(int mx, int my) {
  if (CHLADNI_SPHERE_UI) {
    int chIdx = getChladniEngSliderAt(mx, my);
    if (chIdx >= 0) return chIdx;
  }

  // Must match the layout in drawEngineeringControlsInPanel exactly
  int rad = int(min(86, (PANEL_TOP + PANEL_H + 18 > 0 ? 300 : 300) / 3) * 0.6);
  // Find the panel position — same calculation as in draw
  int px = 20 + (rad*2 + 28);  // x + (rad*2+28)
  // We need the actual y of the nodes panel
  int panelY = PANEL_TOP + PANEL_H + 18;
  int lowerBandY = H - 214;
  int h = lowerBandY - panelY - 12;
  int contentRight = W - 300;
  int x1 = 20;
  int gap = 8;
  int wCol = (contentRight - x1 - 20 - gap * 3) / 4;
  int x2 = x1 + wCol + gap;
  
  px = x2 + (rad*2 + 28);
  int py = panelY + 8;
  int pw = 143;
  int ph = h - 16;
  int bw = pw - 16 - 42;
  int dy = (ph - 28) / 9;
  int sy = py + 22;
  
  for (int i = 0; i < 9; i++) {
    int barY = sy + 12;
    if (mx >= px + 8 && mx <= px + 8 + bw && my >= barY && my <= barY + 10) {
      engDragPanelX = px + 8;
      engDragBarW = bw;
      return i;
    }
    sy += dy;
  }
  return -1;
}

int getChladniEngSliderAt(int mx, int my) {
  int x = chEngSliderX();
  int barW = chEngSliderW() - 52;
  for (int i = 0; i < 9; i++) {
    int barY = chEngSliderTop(i) + 16;
    if (mx >= x && mx <= x + barW && my >= barY - 4 && my <= barY + 12) {
      engDragPanelX = x;
      engDragBarW = barW;
      return i;
    }
  }
  return -1;
}

int chEngSliderTop(int idx) {
  int y0 = CH_SPHERE_Y + 44;
  int step = chEngSliderStep();
  if (idx < 3) return y0 + idx * step;
  if (idx < 6) return y0 + step * 3 + 16 + (idx - 3) * step;
  return y0 + step * 6 + 32 + (idx - 6) * step;
}

void updateEngSlider(int idx, int mx) {
  float val = constrain((float)(mx - engDragPanelX) / engDragBarW, 0, 1);
  switch(idx) {
    case 0: oceanEngCurrentGain = val; break;
    case 1: oceanEngSwellAmp = val; break;
    case 2: oceanEngBreakRate = val; break;
    case 3: orbitEccentricityBias = val; break;
    case 4: orbitResonanceDrive = val; break;
    case 5: orbitLockStrength = val; orbitLockManual = true; break;
    case 6: floquetDrive = val; break;
    case 7: floquetInstability = val; break;
    case 8: quasiEnergyBias = val; break;
  }
}

void drawCompactSlider(int x, int y, int w, String label, float value) {
  int barW = w - 42;
  fill(140, 170, 160);
  textSize(7);
  textAlign(LEFT, CENTER);
  text(label, x, y + 6);
  noStroke();
  fill(35, 50, 45, 200);
  rect(x, y + 12, barW, 5, 2);
  fill(60, 210, 140, 180);
  rect(x, y + 12, constrain(value, 0, 1) * barW, 5, 2);
  fill(180);
  textSize(7);
  textAlign(RIGHT, CENTER);
  text(safeNf(value, 1, 2), x + w, y + 14);
}

void drawMiniReadout(int x, int y, int w, String label, float val, String sval) {
  val = constrain(val, 0, 1);
  fill(18, 22, 28, 190);
  stroke(45, 75, 85, 130);
  rect(x, y, w, 18, 4);
  noStroke();
  fill(60, 210, 185, 160);
  rect(x + 1, y + 1, max(1, (w - 2) * val), 16, 4);
  fill(230);
  textSize(9);
  textAlign(LEFT, CENTER);
  text(label, x + 6, y + 9);
  textAlign(RIGHT, CENTER);
  text(sval, x + w - 6, y + 9);
}


// ========== ORBITAL PHYSICS FUNCTIONS ==========
float orbResolutionField(float r) {
  r = max(r, 0.05);
  // §5 radial ODE solution from PhiFieldEngine.
  // phiEngine.radialPhi(r) returns φ in [−1.5, 0].
  // Remapped to [0.1, 2.0] to preserve the downstream numerical range.
  float phi_raw = phiEngine.radialPhi(r);
  float phi_scaled = map(phi_raw, -1.5, 0.0, 0.1, 2.0);
  return constrain(phi_scaled, 0.1, 2.0);
}

float orbEffectiveGravity(float r) {
  r = max(r, 0.05);
  float phi   = orbResolutionField(r);
  float gNewt = orb_G0 * orb_M / (r * r);

  // Base RDFT gravity: field curvature from α and recursion depth.
  // In UFO mode the Floquet-optimised alpha (fsAlphaNow) is blended in,
  // scaled by how far along the disc→jellyfish transition we are.
  // This closes the Floquet→orbital feedback loop so the drive actually
  // steers the orbital geometry rather than just informing SuperCollider.
  float ufoBlend = (fcPanel != null && fcPanel.fcReady && fcPanel.ufoModeOn)
      ? constrain(fcPanel.ufoTransition, 0, 1) : 0.0;
  float activeAlpha = lerp(safeAlphaValue(alpha), fsAlphaNow, ufoBlend * 0.6);
  float gBase = gNewt * (float)Math.pow(
    max(activeAlpha, 1.001),
    2.0 * orb_gamma * phi
  );

  // Apply electrogravity factor when the FieldConfig EG path is enabled, or
  // when the local probe is actively modulating the field.
  boolean egActive = (fcPanel != null && fcPanel.fcReady && fcPanel.egEnabled)
      || egProbeActive
      || egProbeDepth > 0.001;

  // §8 stability modulation via G_local = 1 − 2A·e^(−2φ)·S.
  // Near threshold (G_local → 0) gravity softens; past it the orbit loosens.
  // Floor at 0.15 keeps integration stable even in runaway regime.
  float gModifier = constrain(0.6 + 0.4 * phiEngine.G_local, 0.15, 1.4);
  float gPhiField = gBase * gModifier;

  float gFinal = egActive ? gPhiField * electroGravityFactor : gPhiField;

  return max(gFinal, 0.0);
}


void stepOrbit() {
  float r = sqrt(orb_x * orb_x + orb_y * orb_y);
  float g = orbEffectiveGravity(r);
  float rSafe = max(r, 0.05);

  // §7 Hamilton-Jacobi characteristic acceleration.
  // Blends Newtonian centripetal with HJ source-gradient and field-memory terms.
  float[] acc = phiEngine.orbitalAcceleration(orb_x, orb_y, orb_vx, orb_vy, g, r);
  float ax = acc[0];
  float ay = acc[1];

  orb_vx += ax * ORB_DT;
  orb_vy += ay * ORB_DT;
  orb_x += orb_vx * ORB_DT;
  orb_y += orb_vy * ORB_DT;
  if (abs(orb_x) > ORB_BOUND * 1.5 || abs(orb_y) > ORB_BOUND * 1.5) {
    RESETORBIT(0);
  }
  float phi = orbResolutionField(sqrt(orb_x * orb_x + orb_y * orb_y));
  trailX[trailHead] = orb_x;
  trailY[trailHead] = orb_y;
  trailPhi[trailHead] = phi;
  trailHead = (trailHead + 1) % TRAIL_LEN;
  if (trailCount < TRAIL_LEN) trailCount++;

  // ── FTLE: step shadow and accumulate Benettin stretch ──────────
  stepShadow();
}

// Advances the shadow particle under the identical force law,
// measures separation from the primary, accumulates ln(stretch),
// then renormalises the shadow back onto the FTLE_EPS sphere.
// Called once per stepOrbit() call — same timestep, same force.
void stepShadow() {
  float rs = sqrt(shad_x * shad_x + shad_y * shad_y);
  float gs = orbEffectiveGravity(rs);
  float rsSafe = max(rs, 0.05);
  float ax = -gs * shad_x / rsSafe;
  float ay = -gs * shad_y / rsSafe;
  shad_vx += ax * ORB_DT;
  shad_vy += ay * ORB_DT;
  shad_x  += shad_vx * ORB_DT;
  shad_y  += shad_vy * ORB_DT;

  // Separation vector between shadow and primary
  float dx  = shad_x  - orb_x;
  float dy  = shad_y  - orb_y;
  float dvx = shad_vx - orb_vx;
  float dvy = shad_vy - orb_vy;
  float sep = sqrt(dx*dx + dy*dy);

  if (sep > 1e-12) {
    // Accumulate log-stretch: this is the core Benettin sum
    ftleAccum += log(sep / FTLE_EPS);
    ftleSteps++;

    // Renormalise shadow back onto epsilon sphere (position only).
    // Velocity offset is scaled proportionally so the phase-space
    // direction is preserved while the magnitude is reset.
    float scale = FTLE_EPS / sep;
    shad_x  = orb_x  + dx  * scale;
    shad_y  = orb_y  + dy  * scale;
    shad_vx = orb_vx + dvx * scale;
    shad_vy = orb_vy + dvy * scale;
  }

  // Running FTLE in units of (nats / timestep).
  // Divide by ORB_DT to get nats/second if you prefer physical units.
  metricLyapunov = (ftleSteps > 0) ? ftleAccum / ftleSteps : 0.0;
}


// ========== ORBIT EVENT / RESONANCE DETECTOR ==========
float circularAngleDelta(float a, float b) {
  float d = a - b;
  while (d > PI) d -= TWO_PI;
  while (d < -PI) d += TWO_PI;
  return d;
}

float listMean(ArrayList<Float> vals) {
  if (vals == null || vals.size() == 0) return 0;
  float sum = 0;
  for (float v : vals) sum += v;
  return sum / vals.size();
}

float listStd(ArrayList<Float> vals, float mean) {
  if (vals == null || vals.size() < 2) return 0;
  float sum = 0;
  for (float v : vals) sum += sq(v - mean);
  return sqrt(sum / max(1, vals.size() - 1));
}

int countRadialPeaks(ArrayList<Float> vals) {
  if (vals == null || vals.size() < 9) return 0;
  int peaks = 0;
  for (int i = 2; i < vals.size() - 2; i++) {
    float v = vals.get(i);
    if (v > vals.get(i-1) && v > vals.get(i+1) && v > vals.get(i-2) && v > vals.get(i+2)) {
      peaks++;
    }
  }
  return peaks;
}

void updateOrbitEventDetector() {
  float r = sqrt(orb_x * orb_x + orb_y * orb_y);
  float speed = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);
  float angle = atan2(orb_y, orb_x);

  orbitEventRadiusHistory.add(r);
  orbitEventSpeedHistory.add(speed);
  orbitEventAngleHistory.add(angle);
  while (orbitEventRadiusHistory.size() > 180) orbitEventRadiusHistory.remove(0);
  while (orbitEventSpeedHistory.size() > 180) orbitEventSpeedHistory.remove(0);
  while (orbitEventAngleHistory.size() > 180) orbitEventAngleHistory.remove(0);

  float meanR = listMean(orbitEventRadiusHistory);
  float stdR = listStd(orbitEventRadiusHistory, meanR);
  float minR = 9999;
  float maxR = 0;
  for (float rv : orbitEventRadiusHistory) {
    if (rv < minR) minR = rv;
    if (rv > maxR) maxR = rv;
  }
  float rawEccentricity = constrain((maxR - minR) / max(0.001, maxR + minR), 0, 1);
  orbitEccentricity = constrain(rawEccentricity + (orbitEccentricityBias - 0.5) * 0.42, 0, 1);
  float computedLock = constrain((0.55 - meanR) / 0.42, 0, 1) * constrain(1.0 - orbitEccentricity * 1.35, 0, 1);
  if (!orbitLockManual) orbitLockStrength = computedLock;
  // Manual override fades back to computed after 8 seconds
  if (orbitLockManual && frameCount % 192 == 0) orbitLockManual = false;
  orbitPeriapsisIntensity = constrain((0.42 - r) / 0.32, 0, 1) * constrain(speed / 1.8, 0, 1);

  int peaks = countRadialPeaks(orbitEventRadiusHistory);
  orbitLobeEstimate = constrain(round(peaks / 2.0f), 1, 6);
  float rawResonance = constrain((1.0 - abs(orbitLobeEstimate - 3) / 3.0) * orbitEccentricity * constrain(peaks / 8.0, 0, 1), 0, 1);
  orbitResonanceScore = constrain(rawResonance * (0.75 + orbitResonanceDrive * 0.50), 0, 1);

  String next = "ORBIT_STABLE_DRIFT";
  if (orbitPeriapsisIntensity > 0.72) {
    next = "PERIAPSIS_AUDIO_SURGE";
  } else if (orbitLockStrength > 0.55) {
    next = "ORBIT_LOCK";
  } else if (orbitResonanceScore > 0.34 && orbitLobeEstimate == 3) {
    next = "ORBIT_RESONANCE_3";
  } else if ((lastOrbitEventLabel.equals("ORBIT_LOCK") || lastOrbitEventLabel.equals("ORBIT_RESONANCE_3")) && r > meanR + stdR * 1.4 && speed > 0.55) {
    next = "ORBIT_ESCAPE";
  } else if (orbitEccentricity > 0.62 && meanR < ORB_BOUND * 0.9) {
    next = "ORBIT_ECCENTRIC_SWING";
  }

  if (!next.equals(orbitEventLabel)) {
    lastOrbitEventLabel = orbitEventLabel;
    orbitEventLabel = next;
    orbitEventChangeFrame = frameCount;
    if (frameCount % 12 == 0) println("ORBIT EVENT: " + orbitEventLabel + " lobes=" + orbitLobeEstimate + " ecc=" + safeNf(orbitEccentricity,1,3));
  }
}

void sendOrbitEventToSuperCollider() {
  if (oscP5 == null || supercollider == null) return;
  // Send slowly, plus immediately after event changes.  This marks regimes without spamming OSC.
  if (frameCount % 18 != 0 && frameCount - orbitEventChangeFrame > 3) return;
  OscMessage m = new OscMessage("/rdf/orbitEvent");
  m.add(orbitEventLabel);
  m.add(orbitLockStrength);
  m.add((float)orbitLobeEstimate);
  m.add(orbitEccentricity);
  m.add(orbitPeriapsisIntensity);
  m.add(orbitResonanceScore);
  m.add(sqrt(orb_vx * orb_vx + orb_vy * orb_vy));
  m.add(sqrt(orb_x * orb_x + orb_y * orb_y));
  oscP5.send(m, supercollider);
}

// ========== COLOR FUNCTIONS ==========
color plasma(float t) {
  t = constrain(t, 0, 1);
  return color(
    constrain(0.050 + t * (2.560 + t * (-1.380)), 0, 1) * 255,
    constrain(0.030 + t * (-0.200 + t * (1.310)), 0, 1) * 255,
    constrain(0.528 + t * (1.107 + t * (-1.220)), 0, 1) * 255
  );
}

color viridis(float t) {
  t = constrain(t, 0, 1);
  return color(
    constrain(0.267 + t * (-0.003 + t * (1.398 + t * (-0.945))), 0, 1) * 255,
    constrain(0.005 + t * (1.085 + t * (-0.722 + t * (0.150))), 0, 1) * 255,
    constrain(0.329 + t * (1.536 + t * (-2.478 + t * (1.172))), 0, 1) * 255
  );
}

color inferno(float t) {
  t = constrain(t, 0, 1);
  return color(
    constrain(0.000 + t * (0.333 + t * (2.667 + t * (-2.000))), 0, 1) * 255,
    constrain(0.000 + t * (-0.167 + t * (2.000 + t * (-0.833))), 0, 1) * 255,
    constrain(0.014 + t * (2.486 + t * (-4.000 + t * (2.500))), 0, 1) * 255
  );
}

color[] buildCmap(String name, int steps) {
  color[] c = new color[steps];
  for (int i = 0; i < steps; i++) {
    float t = (float)i / (steps - 1);
    if (name.equals("plasma")) c[i] = plasma(t);
    else if (name.equals("viridis")) c[i] = viridis(t);
    else if (name.equals("inferno")) c[i] = inferno(t);
    else c[i] = color(255, 255, 255);
  }
  return c;
}

color sampleCmap(color[] cmap, float t) {
  int idx = (int)constrain(t * (cmap.length - 1), 0, cmap.length - 1);
  return cmap[idx];
}


// ============================================================
// RECURSIVE STATE-SPACE CARTOGRAPHY
// A lightweight phase-space map of the current RDFT state. This is not a
// literal object in physical space; it is a virtual trajectory through a
// topology/metric space assembled from alpha, depth, entropy, Lyapunov,
// mutual information, Floquet coupling, ocean temperature/current state, and solar forcing.
// ============================================================
/*
void drawStateSpaceCartographyPanel(int x, int y, int w, int h) {

   ALL OF IT


void drawStateSpaceCartographyPanel(int x, int y, int w, int h) {
  rdfPanelFrame(x, y, w, h, "RECURSIVE STATE-SPACE CARTOGRAPHY");
  if (stateCartographer == null) return;

  int gx = x + 14;
  int gy = y + 34;
  int gw = w - 28;
  int gh = max(130, h - 118);

  noStroke();
  int cols = 18;
  int rows = 12;
  float cw = gw / float(cols);
  float ch = gh / float(rows);
  for (int j = 0; j < rows; j++) {
    for (int i = 0; i < cols; i++) {
      float nx = i / max(1.0, cols - 1.0);
      float ny = j / max(1.0, rows - 1.0);
      float basin = virtualBasinPotential(nx, ny);
      fill(20 + int(80 * basin), 40 + int(120 * (1-basin)), 70 + int(70 * basin), int(map(basin, 0, 1, 18, 72)));
      rect(gx + i*cw, gy + j*ch, cw+0.5, ch+0.5);
    }
  }

  stroke(60, 120, 130, 120);
  strokeWeight(1);
  line(gx, gy + gh*0.5, gx + gw, gy + gh*0.5);
  line(gx + gw*0.5, gy, gx + gw*0.5, gy + gh);
  fill(110, 170, 175);
  textSize(7);
  textAlign(LEFT, TOP);
  text("coherence basin", gx + 4, gy + 4);
  textAlign(RIGHT, BOTTOM);
  text("dense / unstable", gx + gw - 4, gy + gh - 4);

 // ── 3D orthographic projection ────────────────────────────────────
float theta = stateCartographer.rotTheta;
int n = stateCartographer.count;

if (n > 1) {
  for (int k = 1; k < n; k++) {
    int idx0 = stateCartographer.indexFromOldest(k - 1);
    int idx1 = stateCartographer.indexFromOldest(k);

    float age = k / float(max(1, n - 1));

    float x0 = stateCartographer.xTrace[idx0] - 0.5;
    float y0 = stateCartographer.yTrace[idx0] - 0.5;
    float z0 = stateCartographer.zTrace[idx0] - 0.5;

    float x1 = stateCartographer.xTrace[idx1] - 0.5;
    float y1 = stateCartographer.yTrace[idx1] - 0.5;
    float z1 = stateCartographer.zTrace[idx1] - 0.5;

    float rx0 = x0 * cos(theta) - z0 * sin(theta);
    float rz0 = x0 * sin(theta) + z0 * cos(theta);

    float rx1 = x1 * cos(theta) - z1 * sin(theta);
    float rz1 = x1 * sin(theta) + z1 * cos(theta);

    float sx0 = 0.5 + rx0;
    float sy0 = 0.5 - y0 - rz0 * 0.38;

    float sx1 = 0.5 + rx1;
    float sy1 = 0.5 - y1 - rz1 * 0.38;

    float zTint = constrain(0.5 + rz0, 0, 1);

    stroke(
      80 + int(140 * age) + int(60 * zTint),
      int(230 - 60 * age - 80 * zTint),
      int(210 - 100 * zTint),
      35 + int(150 * age)
    );

    strokeWeight(0.8 + age * 1.4);

    line(
      gx + sx0 * gw,
      gy + sy0 * gh,
      gx + sx1 * gw,
      gy + sy1 * gh
    );
  }
}

// Current position projected through same centered rotation.
float cx0 = cartX - 0.5;
float cy0 = cartY - 0.5;
float cz0 = cartZ - 0.5;

float crx = cx0 * cos(theta) - cz0 * sin(theta);
float crz = cx0 * sin(theta) + cz0 * cos(theta);

float cpx = 0.5 + crx;
float cpy = 0.5 - cy0 - crz * 0.38;

float px = gx + cpx * gw;
float py = gy + cpy * gh;

float pulse = 6 + 8 * constrain(cartVelocity * 8.0, 0, 1);

noFill();
stroke(255, 230, 120, 180);
strokeWeight(1.5);
ellipse(px, py, pulse * 2, pulse * 2);

fill(255, 240, 150);
noStroke();
ellipse(px, py, 6, 6);

// Rotation angle readout
fill(90, 130, 140);
textSize(7);
textAlign(RIGHT, TOP);
text("θ=" + safeNf(degrees(theta), 1, 0) + "°", gx + gw - 2, gy + 2);

int by = y + h - 76;
fill(140, 230, 220);
textSize(9);
textAlign(LEFT, TOP);
text("basin: " + cartBasin, x + 14, by);

drawMiniReadout(x + 14, by + 20, w - 28, "stability", cartStability, safeNf(cartStability, 1, 3));
drawMiniReadout(x + 14, by + 44, w - 28, "trajectory speed", constrain(cartVelocity * 10.0, 0, 1), safeNf(cartVelocity, 1, 4));
}


float virtualBasinPotential(float nx, float ny) {
  float b1 = exp(-6.5 * (sq(nx - 0.25) + sq(ny - 0.72)));
  float b2 = exp(-8.0 * (sq(nx - 0.68) + sq(ny - 0.38)));
  float b3 = exp(-7.0 * (sq(nx - 0.82) + sq(ny - 0.80)));

  float ridge = 0.22 * sin(
    (nx * 4.0 + ny * 3.0 + frameCount * 0.002) * TWO_PI
  );

  return constrain(0.55 * b1 + 0.38 * b2 + 0.48 * b3 + ridge, 0, 1);
}
}
*/

// ========== DRAW PANEL FUNCTIONS ==========

// ============================================================
// FOUNDATIONAL FIELD LAYER
// Interpretive physics layer: Maxwell proxies, Schrodinger amplitude/uncertainty,
// Planck minimum-distinction gate, and RDFT coherence. This is intentionally
// lightweight so it can run on the Pi 400 in the main single-window GUI.
// ============================================================

// ============================================================
// TRUE MAXWELL / BELTRAMI DIAGNOSTIC HELPERS
// ============================================================
// The legacy foundationalCurlB channel was a rotational-activity proxy.
// These helpers construct an actual RDFT vector field for Beltrami analysis:
//   B = perp(grad psi) + orbital flow + Floquet twist
// with Bz supplied by Berry/Floquet/field amplitude.  This lets us compute
// curl(B), lambda=(B·curlB)/|B|², and alignment=(B·curlB)/(|B||curlB|).

float angleDiff(float a, float b) {
  return atan2(sin(a - b), cos(a - b));
}

float rdfPsiAt(float[][] field, int ix, int iy) {
  ix = constrain(ix, 0, GRID - 1);
  iy = constrain(iy, 0, GRID - 1);
  float cx = (GRID - 1) * 0.5;
  float cy = (GRID - 1) * 0.5;
  float nx = (ix - cx) / max(1.0, cx);
  float ny = (iy - cy) / max(1.0, cy);
  float theta = atan2(ny, nx);
  float localPhi = constrain(field[iy][ix], 0, 1);
  float floquetPhase = fsPhase;
  return theta + TWO_PI * localPhi + floquetPhase * 0.55 + metricBerryPhase * TWO_PI;
}

float beltramiBxAt(float[][] field, int ix, int iy, float orbSpeed) {
  ix = constrain(ix, 1, GRID - 2);
  iy = constrain(iy, 1, GRID - 2);
  float dpsi_dy = 0.5 * angleDiff(rdfPsiAt(field, ix, iy + 1), rdfPsiAt(field, ix, iy - 1));
  float cx = (GRID - 1) * 0.5;
  float cy = (GRID - 1) * 0.5;
  float ny = (iy - cy) / max(1.0, cy);
  float theta = atan2(ny, (ix - cx) / max(1.0, cx));
  float orbitalFlowX = -ny * constrain(orbSpeed / 2.0, 0, 1) * 0.22;
  float floquetTwistX = cos(theta + fsPhase) * constrain(envFloquetCoupling(), 0, 1) * 0.12;
  return -dpsi_dy + orbitalFlowX + floquetTwistX;
}

float beltramiByAt(float[][] field, int ix, int iy, float orbSpeed) {
  ix = constrain(ix, 1, GRID - 2);
  iy = constrain(iy, 1, GRID - 2);
  float dpsi_dx = 0.5 * angleDiff(rdfPsiAt(field, ix + 1, iy), rdfPsiAt(field, ix - 1, iy));
  float cx = (GRID - 1) * 0.5;
  float cy = (GRID - 1) * 0.5;
  float nx = (ix - cx) / max(1.0, cx);
  float theta = atan2((iy - cy) / max(1.0, cy), nx);
  float orbitalFlowY = nx * constrain(orbSpeed / 2.0, 0, 1) * 0.22;
  float floquetTwistY = sin(theta + fsPhase) * constrain(envFloquetCoupling(), 0, 1) * 0.12;
  return dpsi_dx + orbitalFlowY + floquetTwistY;
}

float beltramiBzAt(float[][] field, int ix, int iy) {
  ix = constrain(ix, 0, GRID - 1);
  iy = constrain(iy, 0, GRID - 1);
  float localPhi = constrain(field[iy][ix], 0, 1);
  return metricBerryPhase + 0.20 * (localPhi - 0.5) + 0.10 * envFloquetQuasienergy();
}

void updateSymbolicFieldStates() {
  if (abs(foundationalMaxwellDivETrue) < 0.0004) symbolicMaxwellState = "MAXWELL_NEUTRAL";
  else if (foundationalMaxwellDivETrue > 0) symbolicMaxwellState = "MAXWELL_SOURCE";
  else symbolicMaxwellState = "MAXWELL_SINK";

  if (abs(beltramiAlignment) > 0.72 && abs(beltramiLambda) > 0.02) symbolicBeltramiState = "BELTRAMI_ALIGNED";
  else if (beltramiCurlMag < 0.02 || beltramiBMag < 0.02) symbolicBeltramiState = "BELTRAMI_NULL";
  else if (abs(beltramiAlignment) < 0.25) symbolicBeltramiState = "BELTRAMI_SHEARED";
  else symbolicBeltramiState = "BELTRAMI_PARTIAL";

  if (abs(metricBerryPhase) > 0.0012 && cartVelocity < 0.08) symbolicHolonomyEvent = "HOLONOMY_CLOSURE";
  else if (abs(metricBerryPhase) > 0.0012) symbolicHolonomyEvent = "BERRY_SECTOR_SHIFT";
  else if (cartVelocity > 0.16) symbolicHolonomyEvent = "CURVATURE_SPIKE";
  else symbolicHolonomyEvent = "HOLO_NONE";
}

void computeFoundationalFieldMetrics(float[][] field, float finest, float dominantVal, float avgBright, float maxBright, float orbSpeed, float orbRadius) {
  if (field == null) return;

  float gradSum = 0;
  float lapAbsSum = 0;
  float lapSignedSum = 0;
  float divESignedSum = 0;
  float varSum = 0;
  float mean = avgBright;
  float gateCount = 0;

  float BxSum = 0, BySum = 0, BzSum = 0;
  float BMagSum = 0;
  float curlXSum = 0, curlYSum = 0, curlZSum = 0, curlMagSum = 0;
  float lambdaSum = 0;
  float alignSum = 0;
  float helicitySum = 0;

  int n = 0;
  int step = 4;
  float planckThreshold = 1.0 / max(2.0, pow(max(alpha, 1.1), max(depth, 1)) * 4.0);

  // Planck threshold detection: alpha at or near 1.0 collapses recursive distinction.
  boolean atPlanckThreshold = (alpha <= 1.001);
  if (atPlanckThreshold) {
    foundationalPlanckGate = 1.0;
    foundationalCoherence = constrain(foundationalCoherence * 1.4, 0, 1);
  }

  for (int y = 2; y < GRID - 2; y += step) {
    for (int x = 2; x < GRID - 2; x += step) {
      float c = constrain(field[y][x], 0, 1);

      // Scalar phi field differential structure.
      float gx = field[y][x+1] - field[y][x-1];
      float gy = field[y+1][x] - field[y-1][x];
      float g = sqrt(gx*gx + gy*gy);
      float lapSigned = field[y][x+1] + field[y][x-1] + field[y+1][x] + field[y-1][x] - 4.0*c;
      float divETrue = -lapSigned;   // E = -grad(phi), so div(E) = -laplacian(phi)

      gradSum += g;
      lapAbsSum += abs(lapSigned);
      lapSignedSum += lapSigned;
      divESignedSum += divETrue;
      varSum += sq(c - mean);
      if (g > planckThreshold || abs(lapSigned) > planckThreshold * 1.5) gateCount++;

      // RDFT Beltrami vector field B = perp(grad psi) + orbital flow + Floquet twist.
      float bx = beltramiBxAt(field, x, y, orbSpeed);
      float by = beltramiByAt(field, x, y, orbSpeed);
      float bz = beltramiBzAt(field, x, y);

      float dBy_dx = 0.5 * (beltramiByAt(field, x + 1, y, orbSpeed) - beltramiByAt(field, x - 1, y, orbSpeed));
      float dBx_dy = 0.5 * (beltramiBxAt(field, x, y + 1, orbSpeed) - beltramiBxAt(field, x, y - 1, orbSpeed));
      float dBz_dx = 0.5 * (beltramiBzAt(field, x + 1, y) - beltramiBzAt(field, x - 1, y));
      float dBz_dy = 0.5 * (beltramiBzAt(field, x, y + 1) - beltramiBzAt(field, x, y - 1));

      float curlX = dBz_dy;
      float curlY = -dBz_dx;
      float curlZ = dBy_dx - dBx_dy;

      float bMag = sqrt(bx*bx + by*by + bz*bz);
      float cMag = sqrt(curlX*curlX + curlY*curlY + curlZ*curlZ);
      float helicity = bx*curlX + by*curlY + bz*curlZ;
      float lambda = helicity / max(0.000001, bMag*bMag);
      float alignment = helicity / max(0.000001, bMag*cMag);

      BxSum += bx;
      BySum += by;
      BzSum += bz;
      BMagSum += bMag;
      curlXSum += curlX;
      curlYSum += curlY;
      curlZSum += curlZ;
      curlMagSum += cMag;
      lambdaSum += lambda;
      alignSum += alignment;
      helicitySum += helicity;

      n++;
    }
  }

  float gradMean = gradSum / max(1, n);
  float lapAbsMean = lapAbsSum / max(1, n);
  float variance = varSum / max(1, n);

  foundationalMaxwellLaplacianPhi = lapSignedSum / max(1, n);
  foundationalMaxwellDivETrue = divESignedSum / max(1, n);

  // Legacy normalized display gauge: magnitude of true divergence plus phi residual gradient.
  foundationalDivE = constrain(abs(foundationalMaxwellDivETrue) * 18.0 + phiEngine.gradFMag * 4.0, 0, 1);

  float angularMomentum = abs(orb_x * orb_vy - orb_y * orb_vx);
  float G_contribution = constrain((1.0 - phiEngine.G_local) * 0.6, 0, 1);

  // Old curl proxy, renamed honestly.  Kept as foundationalCurlB alias for SC compatibility.
  foundationalRotActivity = constrain((gradMean * 10.0) + angularMomentum * 0.18 + G_contribution, 0, 1);
  foundationalCurlB = foundationalRotActivity;

  beltramiBx = BxSum / max(1, n);
  beltramiBy = BySum / max(1, n);
  beltramiBz = BzSum / max(1, n);
  beltramiBMag = BMagSum / max(1, n);
  beltramiCurlX = curlXSum / max(1, n);
  beltramiCurlY = curlYSum / max(1, n);
  beltramiCurlZ = curlZSum / max(1, n);
  beltramiCurlMag = curlMagSum / max(1, n);
  beltramiLambda = lambdaSum / max(1, n);
  beltramiAlignment = constrain(alignSum / max(1, n), -1, 1);
  beltramiHelicity = helicitySum / max(1, n);

  foundationalPsiDensity = constrain(mean, 0, 1);
  foundationalUncertainty = constrain(sqrt(max(0, variance)) * 0.9 + metricLyapunov * 0.12 + metricKLDivergence * 0.25, 0, 1);
  foundationalPlanckGate = constrain(gateCount / max(1.0, (float)n), 0, 1);

  float entropyNorm = constrain(metricEntropy / max(0.1, log(max(depth + 1, 2)) / log(2)), 0, 1);
  float miNorm = constrain(metricMutualInfo / 1.5, 0, 1);
  float lyapInv = 1.0 - constrain(metricLyapunov / 1.8, 0, 1);
  float floquet = constrain(envFloquetCoupling(), 0, 1);
  foundationalCoherence = constrain((1.0 - entropyNorm) * 0.30 + miNorm * 0.25 + lyapInv * 0.25 + floquet * 0.20, 0, 1);

  // ── Quantum eraser boundary modulation ───────────────────────────────────
  // landauerCoherence is 1.0 at flat surface regions (paths indistinguishable,
  // interference maintained) and approaches 0.05 at high-curvature saddle points
  // (paths distinguishable, coherence erased). Multiplying here means the orbital
  // naturally loses foundational coherence when crossing curvature peaks on the
  // manifold — BELTRAMI_SHEARED emerges at those points without any explicit rule.
  // When surfaceReady is false the factor is 1.0 (no-op), preserving prior behaviour.
  foundationalCoherence = constrain(foundationalCoherence * landauerCoherence, 0, 1);

  // Coupling now uses the honest rot-activity proxy plus true Beltrami alignment.
  float beltramiAlignNorm = 0.5 + 0.5 * beltramiAlignment;
  foundationalCoupling = constrain((foundationalRotActivity * 0.12) + beltramiAlignNorm * 0.12 + (1.0 - foundationalUncertainty) * 0.20 + foundationalPlanckGate * 0.16 + foundationalCoherence * 0.40, 0, 1);

  if (!midiLaunchpadDetected && (midiPolyMode || midiPolyMemoryCharge > 0.001)) {
    float midiField = midiPolyMemoryCharge * (1.0 - midiPolyReleasePressure);
    foundationalCoherence = constrain(foundationalCoherence + midiField * 0.030, 0, 1);
    foundationalCoupling = constrain(foundationalCoupling + midiField * (0.025 + midiPolyHarmonicDensity * 0.025), 0, 1);
    foundationalPsiDensity = constrain(foundationalPsiDensity + midiPolyHarmonicDensity * midiField * 0.020, 0, 1);
    foundationalUncertainty = constrain(foundationalUncertainty + midiPolyReleasePressure * midiPolyMemoryCharge * 0.035, 0, 1);
  }

  foundationalTrace[foundationalTraceHead] = foundationalCoupling;
  foundationalTraceHead = (foundationalTraceHead + 1) % foundationalTrace.length;
  foundationalTraceCount = min(foundationalTraceCount + 1, foundationalTrace.length);

  updateSymbolicFieldStates();

  // EG is owned by updateElectroGravity().  Keep foundational metrics as inputs
  // only so the local EG probe cannot be overwritten by this slower diagnostic pass.
}

void drawFoundationalFieldPanel(int x, int y, int w, int h) {
  rdfPanelFrame(x, y, w, h, "FOUNDATIONAL FIELD LAYER");
  int pad = 10;
  int top = y + 22;
  int qh = max(34, (h - 42) / 4);
  drawMaxwellMini(x + pad, top, w - pad*2, qh);
  drawSchrodingerMini(x + pad, top + qh + 4, w - pad*2, qh);
  drawPlanckGateMini(x + pad, top + (qh + 4)*2, w - pad*2, qh);
  drawRDFTCoherenceMini(x + pad, top + (qh + 4)*3, w - pad*2, h - (top + (qh + 4)*3 - y) - 8);
}

void drawGaugeBar(int x, int y, int w, int h, float v, color c) {
  v = constrain(v, 0, 1);
  noStroke();
  fill(20, 25, 32, 220); rect(x, y, w, h, 5);
  fill(c); rect(x, y, max(1, int(w * v)), h, 5);
  stroke(255, 255, 255, 30); noFill(); rect(x, y, w, h, 5);
}

void drawMaxwellMini(int x, int y, int w, int h) {
  fill(170, 230, 255); textSize(9); textAlign(LEFT, TOP);
  text("Maxwell divE / rot activity", x, y);
  int gy = y + 14;
  drawGaugeBar(x, gy, w, 7, foundationalDivE, color(255, 130, 80, 150));
  drawGaugeBar(x, gy + 11, w, 7, foundationalRotActivity, color(80, 180, 255, 160));
  noFill(); stroke(70, 200, 255, 90);
  float cx = x + w - 32; float cy = y + h * 0.55;
  for (int i = 0; i < 3; i++) {
    float r = 8 + i * 7 + foundationalRotActivity * 8;
    ellipse(cx, cy, r*2, r*2);
  }
  stroke(255, 130, 80, 100);
  line(cx - 28, cy, cx + 28, cy + (foundationalDivE - 0.5) * 24);
}

void drawSchrodingerMini(int x, int y, int w, int h) {
  fill(210, 190, 255); textSize(9); textAlign(LEFT, TOP);
  text("Schrodinger psi / uncertainty", x, y);
  int baseY = y + h - 8;
  stroke(190, 130, 255, 125); noFill();
  beginShape();
  for (int i = 0; i < w; i += 4) {
    float t = map(i, 0, max(1, w-1), -2.4, 2.4);
    float sigma = 0.35 + foundationalUncertainty * 1.05;
    float psi = exp(-(t*t) / (2*sigma*sigma)) * foundationalPsiDensity;
    float yy = baseY - psi * max(12, h - 18);
    vertex(x + i, yy);
  }
  endShape();
  drawGaugeBar(x, y + 14, w - 46, 6, foundationalUncertainty, color(200, 110, 255, 145));
  fill(180); textSize(8); textAlign(RIGHT, TOP);
  text("d=" + safeNf(foundationalUncertainty,1,2), x + w, y + 12);
}

void drawPlanckGateMini(int x, int y, int w, int h) {
  fill(180, 255, 190); textSize(9); textAlign(LEFT, TOP);
  text("Planck resolution gate", x, y);
  int cols = 18;
  int rows = 4;
  float cellW = w / (float)cols;
  float cellH = max(4, (h - 18) / (float)rows);
  int active = int(foundationalPlanckGate * cols * rows);
  noStroke();
  for (int j = 0; j < rows; j++) {
    for (int i = 0; i < cols; i++) {
      int idx = j * cols + i;
      float shimmer = 0.5 + 0.5 * sin(frameCount * 0.07 + idx * 1.7);
      if (idx < active) fill(90, 255, 140, 70 + 90 * shimmer);
      else fill(40, 55, 48, 90);
      rect(x + i * cellW, y + 16 + j * cellH, max(1, cellW - 1), max(1, cellH - 1));
    }
  }
}

void drawRDFTCoherenceMini(int x, int y, int w, int h) {
  fill(235, 235, 190); textSize(9); textAlign(LEFT, TOP);
  text("RDFT coherence score", x, y);
  drawGaugeBar(x, y + 14, w, 9, foundationalCoherence, color(245, 220, 90, 160));
  drawGaugeBar(x, y + 28, w, 7, foundationalCoupling, color(110, 245, 220, 140));
  stroke(120, 240, 220, 95); noFill();
  int n = foundationalTraceCount;
  if (n > 2) {
    beginShape();
    for (int i = 0; i < n; i++) {
      int idx = (foundationalTraceHead - n + i + foundationalTrace.length) % foundationalTrace.length;
      float xx = map(i, 0, n - 1, x, x + w);
      float yy = map(foundationalTrace[idx], 0, 1, y + h - 4, y + 42);
      vertex(xx, yy);
    }
    endShape();
  }
  fill(170); textSize(8); textAlign(LEFT, BOTTOM);
  text("coupling=" + safeNf(foundationalCoupling,1,2), x, y + h - 2);
}

void sendFoundationalToSuperCollider() {
  if (oscP5 == null || supercollider == null) return;
  OscMessage msg = new OscMessage("/rdf/foundational");
  msg.add(foundationalDivE);
  msg.add(foundationalRotActivity);  // legacy SC slot: rotational activity, not true curl
  msg.add(foundationalPsiDensity);
  msg.add(foundationalUncertainty);
  msg.add(foundationalPlanckGate);
  msg.add(foundationalCoherence);
  msg.add(foundationalCoupling);
  // §12 phi-field additions
  msg.add(phi_residual);          // [8]  F — field mismatch
  msg.add(phi_gain);              // [9]  G_local — stability margin
  msg.add(phiEngine.phi1_energy); // [10] φ₁ self-steepening energy (§6)
  oscP5.send(msg, supercollider);
}

void drawPanel(float[][] data, int px, int py, int pw, int ph, color[] cmap, String title) {
  stroke(60);
  strokeWeight(1);
  noFill();
  rect(px - 1, py - 1, pw + 2, ph + 2);
  float cW = (float)pw / GRID;
  float cH = (float)ph / GRID;
  noStroke();
  int step = MAIN_PANEL_SAMPLE_STEP;
  for (int r = 0; r < GRID; r += step) {
    for (int c = 0; c < GRID; c += step) {
      fill(sampleCmap(cmap, constrain(data[r][c], 0, 1)));
      rect(px + c * cW, py + r * cH, cW * step + 0.5, cH * step + 0.5);
    }
  }
  fill(220);
  noStroke();
  textSize(11);
  textAlign(LEFT, TOP);
  text(title, px, py - 18);
  drawMiniAxes(px, py, pw, ph);
}

void drawSweepPanel(int px, int py, int pw, int ph) {
  fill(22, 22, 30);
  noStroke();
  rect(px, py, pw, ph);
  stroke(60);
  strokeWeight(1);
  noFill();
  rect(px - 1, py - 1, pw + 2, ph + 2);
  fill(220);
  noStroke();
  textSize(11);
  textAlign(LEFT, TOP);
  text("ALPHA SWEEP", px, py - 18);
  boolean useSweepFrame = (animating && sweepReady && !sweepBuilding && sweepCache != null && sweepAlphas != null && sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float[][] data = useSweepFrame ? sweepCache[sweepIdx] : combined;
  float dA = useSweepFrame ? safeAlphaValue(sweepAlphas[sweepIdx]) : safeAlphaValue(alpha);
  float cW = (float)pw / GRID;
  float cH = (float)ph / GRID;
  noStroke();
  int step = MAIN_PANEL_SAMPLE_STEP;
  for (int r = 0; r < GRID; r += step) {
    for (int c = 0; c < GRID; c += step) {
      fill(sampleCmap(cmap_inferno, constrain(data[r][c], 0, 1)));
      rect(px + c * cW, py + r * cH, cW * step + 0.5, cH * step + 0.5);
    }
  }
  drawMiniAxes(px, py, pw, ph);
  fill(255, 255, 255, 200);
  textSize(12);
  textAlign(RIGHT, BOTTOM);
  text("a=" + safeNf(dA, 1, 2), px + pw - 6, py + ph - 6);
	  if (animating && sweepReady) {
	    float prog = map(sweepIdx, 0, SWEEP_STEPS - 1, 0, pw);
	    fill(sweepDir > 0 ? color(100, 120, 255, 180) : color(255, 140, 60, 180));
	    noStroke();
	    rect(px, py + ph - 5, prog, 5);
	  }
		}

void drawCrossSection(int px, int py, int pw, int ph) {
  fill(22, 22, 30);
  noStroke();
  rect(px, py, pw, ph);
  stroke(60);
  strokeWeight(1);
  noFill();
  rect(px - 1, py - 1, pw + 2, ph + 2);
  fill(220);
  noStroke();
  textSize(11);
  textAlign(LEFT, TOP);
  text("CROSS-SECTION", px, py - 18);
  if (cross1D == null) return;
  stroke(40);
  strokeWeight(1);
  for (int i = 1; i < 4; i++) {
    int gy = py + (int)(ph * i / 4.0);
    line(px, gy, px + pw, gy);
  }
  for (int d = 0; d <= depth; d++) {
    float[] ll = getCrossAtDepth(d);
    if (ll == null) continue;
    float wt = (float)Math.pow(alpha, -d);
    stroke(depthColors[d % depthColors.length]);
    strokeWeight(1.5);
    noFill();
    beginShape();
    for (int i = 0; i < GRID; i++) {
      float x = px + map(i, 0, GRID - 1, 0, pw);
      float y = py + ph - map(ll[i] * wt, 0, 1, 0, ph * 0.9);
      vertex(x, constrain(y, py, py + ph));
    }
    endShape();
  }
  drawCrossSectionAxes(px, py, pw, ph);
  textSize(9);
  textAlign(LEFT, TOP);
  for (int d = 0; d <= min(depth, 7); d++) {
    fill(depthColors[d % depthColors.length]);
    text("D" + d, px + pw - 28, py + 6 + d * 13);
  }
}

void drawMiniAxes(int px, int py, int pw, int ph) {
  stroke(180, 180, 190, 120);
  strokeWeight(1);
  fill(180, 180, 190);
  textSize(9);
  noFill();
  rect(px, py, pw, ph);
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 4; i++) {
    float x = px + map(i, 0, 4, 0, pw);
    stroke(180, 180, 190, 120);
    line(x, py + ph, x, py + ph + 4);
    fill(180, 180, 190);
    text(str(i * 25), x, py + ph + 6);
  }
  textAlign(RIGHT, CENTER);
  for (int i = 0; i <= 4; i++) {
    float y = py + map(i, 0, 4, 0, ph);
    stroke(180, 180, 190, 120);
    line(px - 4, y, px, y);
    fill(180, 180, 190);
    text(str(i * 25), px - 7, y);
  }
  fill(160, 160, 180);
  textAlign(CENTER, TOP);
  text("Space", px + pw / 2, py + ph + 20);
  pushMatrix();
  translate(px - 32, py + ph / 2);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("Space", 0, 0);
  popMatrix();
}

void drawCrossSectionAxes(int px, int py, int pw, int ph) {
  stroke(180, 180, 190, 120);
  strokeWeight(1);
  fill(180, 180, 190);
  textSize(9);
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 4; i++) {
    float x = px + map(i, 0, 4, 0, pw);
    stroke(180, 180, 190, 120);
    line(x, py + ph, x, py + ph + 4);
    fill(180, 180, 190);
    text(str(i * 25), x, py + ph + 6);
  }
  textAlign(RIGHT, CENTER);
  for (int i = 0; i <= 4; i++) {
    float y = py + ph - map(i, 0, 4, 0, ph);
    stroke(180, 180, 190, 120);
    line(px - 4, y, px, y);
    fill(180, 180, 190);
    text(safeNf(i * 0.25, 1, 2), px - 7, y);
  }
  fill(160, 160, 180);
  textAlign(CENTER, TOP);
  text("Space", px + pw / 2, py + ph + 20);
  pushMatrix();
  translate(px - 38, py + ph / 2);
  rotate(-HALF_PI);
  textAlign(CENTER, CENTER);
  text("Weighted Intensity", 0, 0);
  popMatrix();
}

void drawOrbitalPanel(int px, int py, int pw, int ph) {
  // Record panel bounds so updateSurfacePhysics() can map orbital coords to screen
  orbPanelX = px; orbPanelY = py; orbPanelW = pw; orbPanelH = ph;
  fill(12, 12, 18);
  noStroke();
  rect(px, py, pw, ph);
  stroke(60);
  strokeWeight(1);
  noFill();
  rect(px - 1, py - 1, pw + 2, ph + 2);
  fill(220);
  noStroke();
  textSize(11);
  textAlign(LEFT, TOP);
  text("RESOLUTION ORBIT", px, py - 18);
  float cx = px + pw / 2.0;
  float cy = py + ph / 2.0;
  float scale = (pw * 0.42) / ORB_BOUND;
  noStroke();
  int fieldRes = 40;
  float cellW = (float)pw / fieldRes;
  float cellH = (float)ph / fieldRes;
  for (int ri = 0; ri < fieldRes; ri++) {
    for (int ci = 0; ci < fieldRes; ci++) {
      float wx = map(ci, 0, fieldRes, -ORB_BOUND, ORB_BOUND);
      float wy = map(ri, 0, fieldRes, -ORB_BOUND, ORB_BOUND);
      float phi = orbResolutionField(sqrt(wx * wx + wy * wy));
      float t = map(phi, 0.1, 2.0, 0, 1);
      fill(sampleCmap(cmap_inferno, t * 0.55));
      rect(px + ci * cellW, py + ri * cellH, cellW + 0.5, cellH + 0.5);
    }
  }

  // Imported/synthetic manifold surface substrate from surface_sender.py.
  // Drawn behind the orbit trail so the orb visibly explores the current surface.
  drawSurfaceOverlayInOrbit(px, py, pw, ph);

  strokeWeight(1.5);
  noFill();
  int count = min(trailCount, TRAIL_LEN);
  for (int i = 0; i < count - 1; i++) {
    int idxA = (trailHead - count + i + TRAIL_LEN) % TRAIL_LEN;
    int idxB = (trailHead - count + i + 1 + TRAIL_LEN) % TRAIL_LEN;
    float phi = trailPhi[idxA];
    float t = map(phi, 0.1, 2.0, 0, 1);
    float bright = map(t, 0, 1, 60, 255);
    float alphaFade = map(i, 0, count, 30, 220);
    stroke(bright, bright * 0.3, bright * 0.1, alphaFade);
    line(cx + trailX[idxA] * scale, cy - trailY[idxA] * scale,
         cx + trailX[idxB] * scale, cy - trailY[idxB] * scale);
  }
  noStroke();
  fill(sampleCmap(cmap_inferno, 0.95));
  ellipse(cx, cy, 12, 12);
  stroke(255, 100, 50, 80);
  strokeWeight(1);
  noFill();
  ellipse(cx, cy, 22, 22);
  ellipse(cx, cy, 34, 34);
  float r_curr = sqrt(orb_x * orb_x + orb_y * orb_y);
  float phi_curr = orbResolutionField(r_curr);
  float t_curr = map(phi_curr, 0.1, 2.0, 0, 1);
  float bright = map(t_curr, 0, 1, 80, 255);
  float sx = cx + orb_x * scale;
  float sy = cy - orb_y * scale;
  
  stroke(60, 60, 80, 120);
  strokeWeight(1);
  line(cx, py + 4, cx, py + ph - 4);
  line(px + 4, cy, px + pw - 4, cy);
 float ufoT = (fcPanel != null && fcPanel.ufoModeOn) ? fcPanel.ufoTransition : 0.0;

  int discCol  = color(bright, bright * 0.3, bright * 0.1);
  int jellyCol = color(bright * 0.4, bright * 0.7, bright);
  int pCol     = lerpColor(discCol, jellyCol, ufoT);

  float coreSize = lerp(8,  18, ufoT);
  float glowSize = lerp(18, 38, ufoT);
  float glowA    = lerp(60, 28, ufoT);

  // Outer halos — jellyfish gets more rings
  int nHalos = ufoT > 0.25 ? (ufoT > 0.65 ? 3 : 2) : 1;
  for (int hi = nHalos; hi >= 1; hi--) {
    float hr = glowSize + hi * lerp(0, 12, ufoT);
    float ha = glowA / hi;
    fill(red(pCol), green(pCol), blue(pCol), ha);
    ellipse(sx, sy, hr, hr);
  }

  // Hard edge ring — disc regime only, fades out toward jellyfish
  if (ufoT < 0.55) {
    noFill();
    stroke(red(pCol), green(pCol), blue(pCol),
           lerp(140, 0, ufoT / 0.55));
    strokeWeight(lerp(1.2, 0, ufoT / 0.55));
    ellipse(sx, sy, coreSize + 5, coreSize + 5);
    noStroke();
  }

  // Core
  fill(pCol);
  ellipse(sx, sy, coreSize, coreSize);

  // Surface contact marker: shows the exact point where the orb is sampling/interacting
  // with the current imported/synthetic manifold overlay.
  drawSurfaceContactMarker(sx, sy, px, py, pw, ph);

  // Disc hot-spot — bright white center, fades in jellyfish regime
  if (ufoT < 0.5) {
    fill(255, 255, 255, lerp(160, 0, ufoT * 2));
    ellipse(sx, sy, coreSize * 0.3, coreSize * 0.3);
  }
  // ── FTLE Phase Portrait ──────────────────────────────────────
  // Draws the shadow trajectory alongside the primary.
  // Colour encodes the current FTLE value:
  //   metricLyapunov ≈ 0   → blue  (regular / quasi-periodic)
  //   metricLyapunov > 0   → red   (chaotic / diverging)
  //   metricLyapunov < 0   → cyan  (contracting)
  // The separation distance is shown as a bar in the bottom-left.
  float shadSep = dist(orb_x, orb_y, shad_x, shad_y);
  float ftleNorm = constrain(metricLyapunov / 0.30, -1.0, 1.0);

  // Shadow current position
  float ssx = cx + shad_x * scale;
  float ssy = cy - shad_y * scale;
  // Colour: blue=regular, red=chaotic, cyan=contracting
  color shadCol;
  if (ftleNorm > 0.04) {
    shadCol = color(220 + int(35 * ftleNorm), 40, 40, 180);          // red
  } else if (ftleNorm < -0.04) {
    shadCol = color(40, 200 + int(55 * abs(ftleNorm)), 220, 180);    // cyan
  } else {
    shadCol = color(80, 120, 255, 160);                               // blue
  }
  noFill();
  stroke(shadCol);
  strokeWeight(1.2);
  ellipse(ssx, ssy, 5, 5);

  // Line from primary to shadow — shows divergence direction
  if (shadSep * scale > 2) {
    stroke(red(shadCol), green(shadCol), blue(shadCol), 100);
    strokeWeight(0.8);
    line(sx, sy, ssx, ssy);
  }

  // Separation bar: thin rect in bottom-left corner of the panel.
  // Full width = FTLE_EPS * 1e5 (normalised to panel width at max visible sep).
  float sepNorm = constrain(log(1 + shadSep / FTLE_EPS) / 12.0, 0, 1);
  int barX = px + 4;
  int barY = py + ph - 36;
  int barW = 60;
  int barH = 4;
  noStroke();
  fill(40, 40, 55);
  rect(barX, barY, barW, barH);
  fill(shadCol);
  rect(barX, barY, barW * sepNorm, barH);
  fill(140, 140, 170);
  textSize(7);
  textAlign(LEFT, BOTTOM);
  text("FTLE sep", barX, barY - 1);

  // FTLE numeric readout
  fill(ftleNorm > 0.04 ? color(255, 100, 80) :
       ftleNorm < -0.04 ? color(80, 220, 240) : color(120, 160, 255));
  textSize(8);
  textAlign(LEFT, BOTTOM);
  text("λ=" + safeNf(metricLyapunov, 1, 4), barX, barY + barH + 10);

  int ledSize = 56;
  drawOrbitalLEDPreview(px + pw - ledSize - 6, py + ph - ledSize - 6, ledSize);
  fill(180, 180, 200);
  textSize(9);
  textAlign(LEFT, BOTTOM);
  float speed = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);
  text("r=" + safeNf(r_curr, 1, 3) + "  v=" + safeNf(speed, 1, 3), px + 4, py + ph - 16);
  text("phi=" + safeNf(phi_curr, 1, 3) + "  G=" + safeNf(orbEffectiveGravity(r_curr), 1, 4), px + 4, py + ph - 4);
  fill(255, 190, 90);
  textAlign(RIGHT, BOTTOM);
  textSize(8);
  text(orbitEventLabel.replace("ORBIT_", "") + "  L" + orbitLobeEstimate, px + pw - 6, py + ph - 4);
}

void drawOrbitalLEDPreview(int px, int py, int size) {
  float[][] frame8 = makeOrbitalMatrixFrame();
  float cell = size / 8.0;
  fill(10, 10, 15);
  noStroke();
  rect(px, py, size, size);
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      float v = frame8[r][c] / 255.0;
      if (v > 0.1) fill(v * 255, v * 64, v * 20);
      else fill(25, 8, 4);
      noStroke();
      rect(px + c * cell, py + r * cell, cell - 0.5, cell - 0.5);
    }
  }
}

void drawMatrixMirror(int px, int py, int size) {
  fill(22, 22, 30);
  noStroke();
  rect(px, py, size, size);
  stroke(60);
  noFill();
  rect(px - 1, py - 1, size + 2, size + 2);
  fill(220);
  textSize(10);
  textAlign(RIGHT, TOP);
  text("LED MIRROR", px + size - 2, py - 16);
  float cell = size / 8.0;
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      float v = lastMatrixFrame[r][c];
      fill(v >= 128 ? color(255, 80, 60) : color(40, 20, 20));
      noStroke();
      ellipse(px + c * cell + cell / 2, py + r * cell + cell / 2, cell * 0.65, cell * 0.65);
    }
  }
}


int safeModeIndex(int idx, int len) {
  if (len <= 0) return 0;
  int m = idx % len;
  if (m < 0) m += len;
  return m;
}

String getSCModeName(int m) {
  switch (m) {
    case 0: return "BRIGHTNESS";
    case 1: return "DENSITY";
    case 2: return "SWEEP";
    case 3: return "ORBIT";
    default: return "UNKNOWN";
  }
}

void drawRDTShellReadouts() {
  int x = W - 410;
  int y = 6;
  int w = 392;
  int h = 108;
  fill(10, 14, 18, 210);
  stroke(70, 120, 125, 160);
  rect(x, y, w, h, 8);
  fill(160, 240, 230);
  textSize(10);
  textAlign(LEFT, TOP);
  text("RDFT PROCEDURAL SHELL", x + 10, y + 8);
  fill(220);
  String m = MODE_NAMES[(int)constrain(menuModSource.getValue(), 0, MODE_NAMES.length-1)];
  text("mode: " + m + "   material-cycle: " + materialCycleName(), x + 10, y + 25);
  text("a=" + safeNf(alpha,1,2) + "  depth=" + depth + "  entropy=" + safeNf(metricEntropy,1,3) + "  Df=" + safeNf(metricFractalDim,1,3), x + 10, y + 42);
  text("MI=" + safeNf(metricMutualInfo,1,3) + "  KL=" + safeNf(metricKLDivergence,1,3) + "  Lyap=" + safeNf(metricLyapunov,1,3), x + 10, y + 59);
  text("cart=" + safeNf(cartX,1,2) + "/" + safeNf(cartY,1,2) + "  stability=" + safeNf(cartStability,1,2) + "  " + cartBasin, x + 10, y + 93);
  fill(recordDataRequested ? color(255,90,90) : color(140,170,170));
  text(recordDataRequested ? "REC DATA: ON" : "REC DATA: OFF", x + 10, y + 76);
  fill(145, 180, 180);
  text("Ocean=" + (oceanAffectsSynth ? "ACTIVE" : "STANDBY") + "  Solar=" + (solarAffectsSynth ? "AUDIO" : "VIS"), x + 116, y + 76);
}

String materialCycleName() {
  String[] names = {"B-GYROID", "B-DIAMOND", "B-IWP", "B-BCC", "BRACHISTO"};
  int idx = (int)((frameCount / 180) % names.length);
  return names[idx];
}


void drawPerformanceFooter() {
  fill(10, 12, 18, 200);
  noStroke();
  rect(470, H - 36, W - 752, 30, 6);
  fill(100, 210, 160);
  textSize(9);
  textAlign(LEFT, CENTER);
  if (phiEngine != null) text(phiEngine.oscStatusString(), 480, H - 26);
  fill(120, 170, 165);
  text("RDFT shell: embedded material + node layers active | MIDI pilot: " + midiPilotStatus + " | audio mapping independent of display visibility | " + statusMsg, 480, H - 15);
}

void drawBottomBar() {
  fill(24, 24, 32);
  noStroke();
  rect(0, H - BTM_H, W, BTM_H);
  stroke(50);
  strokeWeight(1);
  line(0, H - BTM_H, W, H - BTM_H);
  fill(120);
  textSize(11);
  textAlign(LEFT, CENTER);
  boolean oceanLive = oceanBridge != null && oceanBridge.isLive();
  String envLine = "OCEAN: " + (oceanLive ? "LIVE" : "WAIT") +
                   "  env k=" + safeNf(envFloquetCoupling(),1,2) +
                   " eps=" + safeNf(envFloquetQuasienergy(),1,2);
  text("UDP/OSC ONLY — Ocean UDP :5062  |  Solar UDP :5060  |  OSC :60001", 30, H - BTM_H / 2);
  color sc = oceanLive ? color(80, 220, 100) : color(220, 120, 60);
  fill(sc);
  noStroke();
  ellipse(W - 300, H - BTM_H / 2, 10, 10);
  fill(sc);
  textSize(11);
  textAlign(LEFT, CENTER);
  text(envLine, W - 288, H - BTM_H / 2);
  String[] modeNames = {"DOMINANT MAP", "DIFF FIELD", "CROSS-SECTION", "ORBITAL ANIMATION"};
  fill(160);
  textSize(10);
  textAlign(RIGHT, CENTER);
  text("ARDUINO MODE: " + modeNames[safeModeIndex(currentMode, modeNames.length)], W - 140, H - BTM_H + 18);

  fill(160);
  textAlign(RIGHT, CENTER);
  int _scModeIdx = constrain((int)menuModSource.getValue(), 0, MODE_NAMES.length-1);
  text("SC MODE: " + MODE_NAMES[_scModeIdx],
       W - 140, H - BTM_H + 42);
  text("ADIAB=" + safeNf(metricAdiabaticParam,1,3) + "  BERRY=" + safeNf(metricBerryPhase,1,3) +
       "  TAU=" + safeNf(metricCorrelationTau,1,2) + "  BREAKS=" + metricBreakdownCount +
       "  FLOQ k=" + safeNf(envFloquetCoupling(),1,2) + " eps=" + safeNf(envFloquetQuasienergy(),1,2),
       W - 140, H - BTM_H + 66);
}

void drawHeader() {
  fill(180);
  textSize(10);
  textAlign(LEFT, TOP);
  text("RECURSIVE DIFFERENTIATION FRAMEWORK", 20, 6);
  fill(120);
  text("depth=" + depth + "  alpha=" + safeNf(alpha, 1, 2) + "  gamma=" + safeNf(orb_gamma, 1, 2), 20, 18);
  if (adiabaticTracker != null && adiabaticTracker.isSweeping) {
    fill(150, 100, 255);
    textAlign(LEFT, TOP);
    text("ACTIVE SWEEP → a=" + safeNf(adiabaticTracker.targetAlpha,1,2) + " d=" + safeNf(adiabaticTracker.targetDepth,1,0) + " t=" + safeNf(adiabaticTracker.sweepDuration,1,0) + "s", 330, 6);
  } else {
    fill(90, 130, 140);
    textAlign(LEFT, TOP);
    text("set exact values in boxes, then APPLY or START SWEEP", 330, 6);
  }

  // Change 4 — UFO / Field mode indicator.
  // Shown in the header whenever the FieldConfigPanel is open, so the
  // operator always knows which perspective the system is running from.
  if (fcPanel != null && fcPanel.fcReady) {
    boolean ufoOn = fcPanel.ufoModeOn;
    float   ufoT  = fcPanel.ufoTransition;
    // Disc (field mode) = amber, Jellyfish (UFO) = cyan — mirrors the panel
    color modeCol = ufoOn
        ? lerpColor(color(255, 200, 80), color(80, 200, 255), ufoT)
        : color(90, 110, 100);
    fill(modeCol);
    textAlign(RIGHT, TOP);
    textSize(10);
    String modeLabel = ufoOn
        ? ("UFO  [" + (ufoT < 0.25 ? "DISC" : ufoT < 0.75 ? "TIC-TAC" : "JELLYFISH")
           + "  T=" + safeNf(ufoT, 1, 2)
           + "  γ=" + safeNf(orb_gamma, 1, 2)
           + "  αF=" + safeNf(fsAlphaNow, 1, 2) + "]")
        : "FIELD MODE";
    text(modeLabel, W - 20, 6);

    // EG factor readout below mode label
    color egCol = electroGravityFactor > 0.7
        ? color(60, 200, 120)
        : electroGravityFactor > 0.4
            ? color(220, 180, 40)
            : color(220, 80, 40);
    fill(egCol);
    text("g_eff=" + safeNf(electroGravityFactor, 1, 3)
         + "  hold=" + safeNf(fsHoldingStrength, 1, 2)
         + "  lock=" + safeNf(fsPhaseLockScore, 1, 2),
         W - 20, 18);
  }
}

void drawChladniSphereMode() {
  background(4, 8, 10);
  drawChladniTopShell();
  drawChladniLeftDiagnostics();
  drawCollectiveChladniSphere();
  drawChladniRightPanels();
  drawChladniEngineeringColumn();
  drawChladniBottomPanels();
  drawChladniStatusBar();

  if (!sweepReady) {
    fill(0, 0, 0, 170);
    noStroke();
    rect(CH_SPHERE_X + CH_SPHERE_SIZE - 182, CH_SPHERE_Y + CH_SPHERE_SIZE - 34, 166, 20, 4);
    fill(140, 210, 255);
    textSize(10);
    textAlign(CENTER, CENTER);
    int dots = (frameCount / 15) % 4;
    String lbl = "BUILDING CACHE";
    for (int i = 0; i < dots; i++) lbl += ".";
    text(lbl, CH_SPHERE_X + CH_SPHERE_SIZE - 99, CH_SPHERE_Y + CH_SPHERE_SIZE - 24);
  }
}

void drawChladniTopShell() {
  chCard(CH_LEFT_X, 12, CH_LEFT_W, 58, "");
  drawRDFTMark(CH_LEFT_X + 14, 22, 38);
  fill(210, 222, 224);
  textSize(20);
  textAlign(LEFT, TOP);
  text("RDFT", CH_LEFT_X + 72, 22);
  fill(110, 145, 148);
  textSize(8);
  text("FIELD SYNTHESIS", CH_LEFT_X + 74, 45);

  fill(210, 225, 225);
  textSize(18);
  textAlign(LEFT, TOP);
  text("CHLADNI SPHERE SYNTH", CH_MAIN_X, 18);
  fill(125, 154, 156);
  textSize(10);
  text("RDFT field -> quantum action orbit -> SuperCollider layer waveforms -> sphere geometry", CH_MAIN_X, 43);
  fill(40, 220, 90);
  ellipse(W - 122, 28, 8, 8);
  fill(165, 190, 190);
  textAlign(LEFT, CENTER);
  text(oscLoggingEnabled ? "RECORDING" : "LIVE", W - 108, 28);
}

void drawChladniLeftDiagnostics() {
  int x = CH_LEFT_X + 11;
  int y = 82;
  int s = CH_SIDE_SIZE;
  int gap = 8;
  chMiniHeat(x, y, s, s, combined, cmap_plasma, "01 INPUT"); y += s + gap;
  chMiniHeat(x, y, s, s, dominant, cmap_viridis, "02 RDFT"); y += s + gap;
  chMiniSpectrum(x, y, s, s, "03 HARMONICS"); y += s + gap;
  chMiniHeat(x, y, s, s, combined, cmap_inferno, "04 ENERGY"); y += s + gap;
  chMiniOrbit(x, y, s, s, "05 ACTION");
}

void drawConstituentModeGrid() {
  chCard(CH_MAIN_X, CH_MODE_Y, CH_MAIN_W, CH_MODE_H, "CONSTITUENT WAVEFORMS (CHLADNI MODES)");
  int cols = 8;
  int rows = 2;
  int pad = 16;
  int gap = 10;
  int tileW = (CH_MAIN_W - pad * 2 - gap * (cols - 1)) / cols;
  int tileH = (CH_MODE_H - 42 - gap) / rows;
  int startY = CH_MODE_Y + 30;
  for (int i = 0; i < cols * rows; i++) {
    int c = i % cols;
    int r = i / cols;
    int x = CH_MAIN_X + pad + c * (tileW + gap);
    int y = startY + r * (tileH + gap);
    drawModeTile(i, x, y, tileW, tileH);
  }
}

void drawModeTile(int idx, int x, int y, int w, int h) {
  boolean sel = idx == chladniSelectedMode;
  fill(sel ? color(18, 32, 36) : color(8, 12, 16));
  stroke(sel ? color(90, 210, 255) : color(55, 70, 74));
  strokeWeight(sel ? 2 : 1);
  rect(x, y, w, h, 4);
  int step = 3;
  noStroke();
  float t = frameCount * 0.014;
  for (int yy = 3; yy < h - 3; yy += step) {
    for (int xx = 3; xx < w - 3; xx += step) {
      float nx = map(xx, 0, w, -1, 1);
      float ny = map(yy, 0, h, -1, 1);
      float v = chladniModeValue(idx, nx, ny, t);
      float line = 1.0 - constrain(abs(v) * 5.5, 0, 1);
      if (line > 0.28) {
        fill(210 + 45 * line, 230 + 25 * line, 235 + 20 * line, 80 + 150 * line);
        rect(x + xx, y + yy, step, step);
      } else if (random(1) < 0.014) {
        fill(120, 145, 150, 65);
        rect(x + xx, y + yy, 1, 1);
      }
    }
  }
  fill(225);
  textSize(10);
  textAlign(LEFT, TOP);
  text(safeNf(idx + 1, 2), x + 5, y + 4);
}

boolean chladniModeMousePressed(int mx, int my) {
  int boxX = CH_SPHERE_X + 14;
  int boxY = CH_SPHERE_Y + 34;
  int boxW = CH_SPHERE_SIZE - 28;
  int boxH = CH_SPHERE_SIZE - 50;
  float cx = boxX + boxW * 0.50;
  float cy = boxY + boxH * 0.52;
  float rad = min(boxW, boxH) * 0.49;
  float nx = (mx - cx) / rad;
  float ny = (my - cy) / rad;
  if (nx * nx + ny * ny <= 1.0) {
    orb_x = constrain(nx * ORB_BOUND, -ORB_BOUND, ORB_BOUND);
    orb_y = constrain(-ny * ORB_BOUND, -ORB_BOUND, ORB_BOUND);
    if (chladniVisualMode == CH_VIS_FOUNDATION_STREAM) addFoundationStreamTouch(nx, ny, 0.95);
    float tangent = atan2(orb_y, orb_x) + HALF_PI;
    float spd = 0.52 + chLayerDrive(1) * 0.38 + chLayerDrive(5) * 0.22;
    orb_vx = cos(tangent) * spd;
    orb_vy = sin(tangent) * spd;
    trailHead = 0;
    trailCount = 0;
    statusMsg = "Action orbit placed on sphere: x=" + safeNf(orb_x,1,2) + " y=" + safeNf(orb_y,1,2);
    return true;
  }
  return false;
}

void drawCollectiveChladniSphere() {
  chCard(CH_SPHERE_X, CH_SPHERE_Y, CH_SPHERE_SIZE, CH_SPHERE_SIZE, "SPHERE INTERFACE // ACTION ORBIT");
  int boxX = CH_SPHERE_X + 14;
  int boxY = CH_SPHERE_Y + 34;
  int boxW = CH_SPHERE_SIZE - 28;
  int boxH = CH_SPHERE_SIZE - 50;
  orbPanelX = boxX; orbPanelY = boxY; orbPanelW = boxW; orbPanelH = boxH;
  float cx = boxX + boxW * 0.50;
  float cy = boxY + boxH * 0.52;
  float rad = min(boxW, boxH) * 0.49;

  drawChladniGrid(boxX, boxY, boxW, boxH);

  noStroke();
  int step = 4;
  float t = frameCount * 0.012;
  for (int yy = int(-rad); yy <= rad; yy += step) {
    for (int xx = int(-rad); xx <= rad; xx += step) {
      float rr = sqrt(xx * xx + yy * yy) / rad;
      if (rr > 1) continue;
      float nx = xx / rad;
      float ny = yy / rad;
      int gr = constrain(int(map(ny, -1, 1, 0, GRID - 1)), 0, GRID - 1);
      int gc = constrain(int(map(nx, -1, 1, 0, GRID - 1)), 0, GRID - 1);
      float field = combined != null ? combined[gr][gc] : 0.0;
      float mode = chladniAudioFieldValue(nx, ny, t);
      float nodal = 1.0 - constrain(abs(mode) * 5.8, 0, 1);
      float shell = sqrt(max(0, 1 - rr * rr));
      float geom = constrain(surfaceCurv * 0.35 + landauerS * 0.45 + foundationalCoherence * 0.20, 0, 1);
      float energy = constrain(field * 0.52 + abs(mode) * 0.42 + nodal * 0.74 + geom * 0.28 + shell * 0.12, 0, 1);
      color hot = lerpColor(color(12, 26, 28), color(255, 82, 38), constrain(energy * 1.25, 0, 1));
      color cool = lerpColor(color(4, 15, 22), color(68, 205, 255), constrain(nodal * 0.85 + landauerCoherence * 0.18, 0, 1));
      color pxCol = lerpColor(hot, cool, constrain(nodal * 0.66 + shell * 0.16 + geom * 0.10, 0, 1));
      float edge = constrain((1 - rr) * 3.5, 0, 1);
      fill(red(pxCol), green(pxCol), blue(pxCol), 55 + 200 * edge);
      rect(cx + xx, cy + yy, step + 0.5, step + 0.5);
    }
  }

  drawFoundationalSphereUnderlayers(cx, cy, rad, t);
  drawSurfaceTopologyOnSphere(cx, cy, rad, t);
  drawGalaxyBeltramiShearOnSphere(cx, cy, rad, t);
  drawSphereGeometryLayers(cx, cy, rad, t);
  drawFoundationFieldGeometryWrap(cx, cy, rad, t);
  drawAudioChannelChladniLines(cx, cy, rad, t);
  drawActionOrbitTrailOnSphere(cx, cy, rad, t);
  drawCyanChladniPlasmaShell(cx, cy, rad, t);

  noFill();
  stroke(210, 245, 255, 215);
  strokeWeight(2);
  ellipse(cx, cy, rad * 2, rad * 2);

  fill(160, 190, 194);
  textSize(10);
  textAlign(LEFT, TOP);
  text("F=" + safeNf(phi_residual, 1, 4) + "  G=" + safeNf(phi_gain, 1, 3), boxX + 18, boxY + 20);
  text("ACTION r=" + safeNf(sqrt(orb_x * orb_x + orb_y * orb_y), 1, 3) +
       "  v=" + safeNf(sqrt(orb_vx * orb_vx + orb_vy * orb_vy), 1, 3), boxX + 18, boxY + 38);
  text("SC wave mix  D/A/G/C " + safeNf(chLayerDrive(0),1,2) + "/"
       + safeNf(chLayerDrive(1),1,2) + "/" + safeNf(chLayerDrive(2),1,2) + "/"
       + safeNf(chLayerDrive(3),1,2), boxX + 18, boxY + 56);

  drawSphereLegend(boxX + boxW - 150, boxY + 18);
}

float chladniAudioFieldValue(float x, float y, float t) {
  float accum = 0;
  float total = 0;
  for (int i = 0; i < 6; i++) {
    float drive = chLayerDrive(i);
    accum += chChannelWave(i, x, y, t) * drive;
    total += drive;
  }
  return accum / max(0.001, total);
}

float chChannelWave(int layer, float x, float y, float t) {
  float r = sqrt(x * x + y * y);
  float th = atan2(y, x);
  float rootRatio = constrain(scDiagRootFreq / 55.0, 0.35, 16.0);
  float pitch = log(rootRatio) / log(2);

  float vDrone = sin((2.0 + pitch * 0.25) * PI * x + t * 0.55)
               * sin((2.0 + alpha * 0.20) * PI * y - t * 0.38);
  float vArp = cos((4.0 + floor(depth * 0.6)) * th + t * (2.0 + getSliderValueSafe("arpRate", 0.4) * 2.5))
             * sin((3.0 + metricFractalDim) * PI * r - t * 0.7);
  float vGlass = sin((7.0 + metricLyapunov * 1.5) * PI * x + t * 1.7)
               * cos((5.0 + surfaceCurv * 4.0) * PI * y - t * 1.2);
  float vChoir = cos(2.0 * th - t * 0.22) * sin((1.0 + foundationalCoherence * 3.0) * PI * r + t * 0.18);
  float vKeys = sin((3.0 + midiPolyHarmonicDensity * 5.0) * th + midiPolyChordSpread * 2.0 + t * 0.9)
              * cos((2.0 + midiPolyMemoryCharge * 4.0) * PI * r);
  float ecoNoise = noise((x + 1.2) * 1.7, (y + 1.2) * 1.7, t * 0.35) * 2.0 - 1.0;
  float vEco = ecoNoise * sin((4.0 + scDiagRhythmComplexity * 5.0) * PI * r - t * 1.35);

  if (layer == 0) return vDrone;
  if (layer == 1) return vArp;
  if (layer == 2) return vGlass;
  if (layer == 3) return vChoir;
  if (layer == 4) return vKeys;
  return vEco;
}

float chLayerDrive(int layer) {
  boolean scFresh = audioDiagLastFrame > 0 && (frameCount - audioDiagLastFrame) < 160;
  if (layer == 0) return (chToggle("droneOn", false) ? max(getSliderValueSafe("droneVolume", 0.20), scFresh ? scDiagDroneVolume : 0) : 0);
  if (layer == 1) return (chToggle("arpOn", true) ? max(getSliderValueSafe("arpVolume", 0.20), scFresh ? scDiagArpVolume : 0) : 0);
  if (layer == 2) return (chToggle("glassOn", true) ? max(getSliderValueSafe("glassVolume", 0.20), scFresh ? scDiagGlassVolume : 0) : 0);
  if (layer == 3) return (chToggle("choirOn", true) ? max(getSliderValueSafe("choirVolume", 0.20), scFresh ? scDiagChoirVolume : 0) : 0);
  if (layer == 4) return (chToggle("midiPolyOn", false) ? getSliderValueSafe("midiPolyVolume", 0.55) * max(0.15, midiPolyMemoryCharge) : 0);
  boolean chirp = chToggle("ecoChirpOn", true);
  boolean call = chToggle("ecoCallOn", true);
  boolean growth = chToggle("ecoGrowthOn", true);
  boolean fissure = chToggle("ecoFissureOn", true);
  float eventPulse = max(max(chirp ? chPulse(audioDiagEcoChirpLastAge) : 0, call ? chPulse(audioDiagEcoCallLastAge) : 0),
                         max(growth ? chPulse(audioDiagEcoGrowthLastAge) : 0, fissure ? chPulse(audioDiagEcoFissureLastAge) : 0));
  float ecoLevel = 0;
  ecoLevel += chirp ? getSliderValueSafe("ecoChirpLevel", 0.58) : 0;
  ecoLevel += call ? getSliderValueSafe("ecoCallLevel", 0.58) : 0;
  ecoLevel += growth ? getSliderValueSafe("ecoGrowthLevel", 0.64) : 0;
  ecoLevel += fissure ? getSliderValueSafe("ecoFissureLevel", 0.64) : 0;
  boolean anyEco = chirp || call || growth || fissure;
  if (!anyEco) return 0;
  return constrain(0.03 + ecoLevel * 0.16 + eventPulse * 0.82 + scDiagRhythmComplexity * 0.20, 0, 1);
}

float chPulse(float age) {
  if (age < 0) return 0;
  return exp(-age * 1.35);
}

boolean chToggle(String name, boolean fallback) {
  if (cp5 == null) return fallback;
  Controller c = cp5.getController(name);
  if (c == null) return fallback;
  return c.getValue() > 0.5;
}

boolean foundationStreamModeActive() {
  return chladniVisualMode == CH_VIS_FOUNDATION_STREAM || launchpadActiveSlot == 1;
}

void addFoundationStreamTouch(float nx, float ny, float strength) {
  float r = sqrt(nx * nx + ny * ny);
  if (r > 0.98) {
    nx *= 0.98 / max(0.001, r);
    ny *= 0.98 / max(0.001, r);
  }
  foundationTouchX[foundationTouchHead] = constrain(nx, -0.98, 0.98);
  foundationTouchY[foundationTouchHead] = constrain(ny, -0.98, 0.98);
  foundationTouchStrength[foundationTouchHead] = constrain(strength, 0, 1.25);
  foundationTouchFrame[foundationTouchHead] = frameCount;
  foundationTouchHead = (foundationTouchHead + 1) % FOUNDATION_TOUCH_MAX;
}

float foundationStreamDisturbance(float nx, float ny, float t) {
  float accum = 0;
  for (int i = 0; i < FOUNDATION_TOUCH_MAX; i++) {
    int ageFrames = frameCount - foundationTouchFrame[i];
    if (ageFrames < 0 || ageFrames > 210 || foundationTouchStrength[i] <= 0) continue;
    float age = ageFrames / 24.0;
    float dx = nx - foundationTouchX[i];
    float dy = ny - foundationTouchY[i];
    float d = sqrt(dx * dx + dy * dy);
    float wake = exp(-d * (5.4 + age * 0.95)) * exp(-age * 0.72) * foundationTouchStrength[i];
    float ring = 0.5 + 0.5 * sin(d * (24.0 + foundationalRotActivity * 18.0) - age * 6.6 + t * 2.0);
    float shear = constrain((dx * 0.55 + dy * 0.24) + 0.5, 0, 1);
    accum += wake * (0.48 + ring * 0.38 + shear * 0.18);
  }
  return constrain(accum, 0, 1);
}

void drawFoundationalSphereUnderlayers(float cx, float cy, float rad, float t) {
  pushStyle();
  noStroke();
  float coh = constrain(foundationalCoherence, 0, 1);
  float phi = constrain(phi_threshold_prox * 0.5, 0, 1);
  float entropy = constrain(metricEntropy, 0, 1);
  int samples = 760;
  for (int i = 0; i < samples; i++) {
    float h1 = fractHash(i * 19.13 + 71.7);
    float h2 = fractHash(i * 7.31 + 117.0);
    float h3 = fractHash(i * 43.91 + 5.0);
    float a = h1 * TWO_PI + t * 0.045 + 0.06 * sin(t * 0.7 + h3 * TWO_PI);
    float rr = pow(h2, 0.62) * (0.34 + 0.62 * h3);
    float nx = cos(a) * rr;
    float ny = sin(a) * rr * (0.72 + 0.12 * sin(t * 0.6 + h1 * TWO_PI));
    float inside = nx * nx + ny * ny;
    if (inside > 1.0) continue;

    float inverse = constrain(abs(chladniAudioFieldValue(nx, ny, t + h1 * 1.7)) * 1.85, 0, 1);
    float interior = 1.0 - constrain(sqrt(inside), 0, 1);
    float grain = noise((nx + 1.4) * 3.2, (ny + 1.4) * 3.2, t * 0.18 + h3);
    float score = constrain(inverse * 0.66 + interior * 0.18 + coh * 0.14 + phi * 0.10 + grain * 0.12, 0, 1);
    if (score < 0.24 + h3 * 0.42) continue;

    float sx = cx + nx * rad;
    float sy = cy + ny * rad;
    float ps = (0.8 + score * 3.4 + entropy * 0.8) * chSpriteTierScale(h1, score);
    float alphaPt = (28 + 118 * score) * (0.52 + interior * 0.48);
    fill(0, 0, 0, alphaPt);
    rect(sx - ps * 0.5, sy - ps * 0.5, ps, ps);
    if (h2 < 0.08 + phi * 0.05) {
      fill(245, 248, 250, 14 + 34 * phi);
      rect(sx - ps * 0.16, sy - ps * 0.16, ps * 0.32, ps * 0.32);
    }
  }
  popStyle();
}

void drawFoundationFieldGeometryWrap(float cx, float cy, float rad, float t) {
  if (!foundationStreamModeActive()) return;
  pushStyle();
  noStroke();
  int step = 6;
  float fieldAmp = constrain(foundationalCoupling * 0.46 + foundationalCoherence * 0.30 + foundationalPsiDensity * 0.24, 0, 1);
  for (int yy = int(-rad); yy <= rad; yy += step) {
    for (int xx = int(-rad); xx <= rad; xx += step) {
      float nx = xx / rad;
      float ny = yy / rad;
      float rr = sqrt(nx * nx + ny * ny);
      if (rr > 1.0) continue;
      float shell = sqrt(max(0, 1 - rr * rr));
      float wake = foundationStreamDisturbance(nx, ny, t);
      float geomWave = sin((nx * 6.0 + ny * 2.2) + t * (1.2 + foundationalRotActivity * 2.0))
                     * cos((ny * 5.4 - nx * 1.8) - t * (0.8 + landauerS * 3.0));
      float wrapped = abs(geomWave + chladniAudioFieldValue(nx + wake * 0.08, ny - wake * 0.04, t) * 0.65);
      float contour = 1.0 - constrain(wrapped * (1.7 + metricFractalDim * 0.18), 0, 1);
      float pressure = constrain(contour * 0.42 + wake * 0.72 + fieldAmp * 0.22 + shell * 0.16, 0, 1);
      float dither = fractHash((xx + 331.0) * 6.17 + (yy + 901.0) * 10.43 + floor(t * 20.0));
      if (pressure < 0.18 + dither * 0.38) continue;
      float px = cx + xx + wake * rad * 0.035 * sin(t * 4.0 + ny * 6.0);
      float py = cy + yy + wake * rad * 0.026 * cos(t * 3.3 + nx * 5.0);
      float ps = (1.7 + pressure * 5.2 + wake * 4.0) * chSpriteTierScale(dither, pressure);
      fill(3, 6, 7, 56 + pressure * 86);
      rect(px - ps * 0.55, py - ps * 0.55, ps * 1.1, ps * 1.1);
      fill(235, 248, 244, (30 + 135 * pressure) * (0.35 + wake * 0.65));
      rect(px - ps * 0.21, py - ps * 0.21, ps * 0.42, ps * 0.42);
      if (wake > 0.08) {
        fill(65, 225, 255, 34 + wake * 120);
        ellipse(px, py, ps * (2.0 + wake * 2.4), ps * (0.85 + wake));
      }
    }
  }
  noFill();
  for (int i = 0; i < FOUNDATION_TOUCH_MAX; i++) {
    int ageFrames = frameCount - foundationTouchFrame[i];
    if (ageFrames < 0 || ageFrames > 160 || foundationTouchStrength[i] <= 0) continue;
    float age = ageFrames / 24.0;
    float fade = exp(-age * 0.8) * foundationTouchStrength[i];
    float px = cx + foundationTouchX[i] * rad;
    float py = cy + foundationTouchY[i] * rad;
    stroke(110, 235, 255, 90 * fade);
    strokeWeight(1.0 + fade * 2.0);
    ellipse(px, py, rad * (0.06 + age * 0.16) * fade, rad * (0.035 + age * 0.10) * fade);
  }
  popStyle();
}

void drawCyanChladniPlasmaShell(float cx, float cy, float rad, float t) {
  pushStyle();
  noStroke();
  int samples = 760;
  for (int i = 0; i < samples; i++) {
    float h1 = fractHash(i * 31.17 + 9.0);
    float h2 = fractHash(i * 11.73 + 51.0);
    float h3 = fractHash(i * 5.91 + floor(t * 18.0));
    float a = h1 * TWO_PI + t * 0.06 + 0.05 * sin(t * 0.9 + h2 * TWO_PI);
    float rr = pow(h2, 0.58) * 0.995;
    float nx = cos(a) * rr;
    float ny = sin(a) * rr;
    float inside = nx * nx + ny * ny;
    if (inside > 1.0) continue;

    float wave = abs(chladniAudioFieldValue(nx, ny, t + h1 * 0.7));
    float nodal = 1.0 - constrain(wave * 6.4, 0, 1);
    float shell = sqrt(max(0, 1 - inside));
    float edge = constrain((rr - 0.55) * 2.0, 0, 1);
    float score = constrain(nodal * 0.74 + edge * 0.18 + shell * 0.08, 0, 1);
    if (score < 0.50 + h3 * 0.30) continue;

    float px = cx + nx * rad;
    float py = cy + ny * rad;
    float ps = (1.2 + score * 4.7) * chSpriteTierScale(h1, score);
    float alphaPt = (32 + 148 * score) * (0.38 + edge * 0.42);
    fill(70, 220, 255, alphaPt * 0.28);
    ellipse(px, py, ps * 2.55, ps * 2.25);
    fill(185, 245, 255, alphaPt);
    ellipse(px, py, ps, ps * 0.82);
  }

  noFill();
  for (int ring = 0; ring < 3; ring++) {
    stroke(105, 230, 255, 32 + ring * 10);
    strokeWeight(1.0 + ring * 0.45);
    float ringR = rad * (0.94 + ring * 0.018 + 0.005 * sin(t * 1.6 + ring));
    ellipse(cx, cy, ringR * 2, ringR * 2);
  }
  popStyle();
}

void drawSurfaceTopologyOnSphere(float cx, float cy, float rad, float t) {
  pushStyle();
  noStroke();
  boolean liveSurface = surfaceReady && surfaceBridge != null;
  color surfaceGold = chMappedLayerColor(1);
  int step = 8;
  if (liveSurface) {
    for (int yy = int(-rad); yy <= rad; yy += step) {
      for (int xx = int(-rad); xx <= rad; xx += step) {
        float rr = sqrt(xx * xx + yy * yy) / rad;
        if (rr > 1.0) continue;
        float sx = cx + xx;
        float sy = cy + yy;
        float z = sampleSurfaceZAtScreen(sx, sy, orbPanelX, orbPanelY, orbPanelW, orbPanelH);
        float curv = sampleSurfaceCurvAtScreen(sx, sy, orbPanelX, orbPanelY, orbPanelW, orbPanelH);
        float contour = 1.0 - constrain(abs(((z * 9.0) % 1.0) - 0.5) * 2.4, 0, 1);
        float dither = fractHash((xx + 420.0) * 13.71 + (yy + 910.0) * 5.33 + floor(t * 18.0));
        float shell = sqrt(max(0, 1 - rr * rr));
        float score = constrain(contour * 0.48 + curv * 0.40 + shell * 0.14 + landauerCoherence * 0.10, 0, 1);
        if (score < dither * 0.76) continue;
        float ps = step * (0.42 + score * 0.88 + curv * 0.45);
        fill(red(surfaceGold), green(surfaceGold), blue(surfaceGold), 38 + 130 * score);
        rect(sx - ps * 0.5, sy - ps * 0.5, ps, ps);
        if (curv > 0.70 || dither < 0.08) {
          fill(255, 244, 180, 38 + 74 * score);
          rect(sx - ps * 0.22, sy - ps * 0.22, ps * 0.44, ps * 0.44);
        }
      }
    }
  } else {
    float topo = constrain(surfaceCurv + landauerS * 3.0 + metricFractalDim * 0.08, 0, 1);
    for (int yy = int(-rad); yy <= rad; yy += step) {
      for (int xx = int(-rad); xx <= rad; xx += step) {
        float rr = sqrt(xx * xx + yy * yy) / rad;
        if (rr > 1.0) continue;
        float nx = xx / rad;
        float ny = yy / rad;
        float rings = 0.5 + 0.5 * sin((sqrt(nx * nx + ny * ny) * 34.0) + t * (1.4 + topo));
        float grain = noise((nx + 1.6) * 4.2, (ny + 1.6) * 4.2, t * 0.30);
        float dither = fractHash((xx + 200.0) * 8.19 + (yy + 600.0) * 2.91 + floor(t * 14.0));
        float shell = sqrt(max(0, 1 - rr * rr));
        float score = constrain(rings * 0.42 + grain * 0.34 + topo * 0.32 + shell * 0.12, 0, 1);
        if (score < dither * 0.82) continue;
        float ps = step * (0.38 + score * 0.90);
        fill(red(surfaceGold), green(surfaceGold), blue(surfaceGold), 29 + 110 * score);
        rect(cx + xx - ps * 0.5, cy + yy - ps * 0.5, ps, ps);
      }
    }
  }
  popStyle();
}

void drawAudioChannelChladniLines(float cx, float cy, float rad, float t) {
  pushStyle();
  drawChannelSpriteLayer(cx, cy, rad, t + 0.05, 0, 0);
  drawChannelSpriteLayer(cx, cy, rad, t + 0.21, 1, 1);
  drawChannelSpriteLayer(cx, cy, rad, t + 0.39, 2, 2);
  drawChoirShimmerLayer(cx, cy, rad, t + 0.53);
  drawChannelSpriteLayer(cx, cy, rad, t + 0.71, 4, 3);
  drawChannelSpriteLayer(cx, cy, rad, t + 0.89, 5, 4);
  popStyle();
}

void drawChannelSpriteLayer(float cx, float cy, float rad, float t, int layer, int style) {
  float drive = constrain(chLayerDrive(layer), 0, 1);
  if (drive < 0.012) return;
  color c = chChannelColor(layer);
  int count = 210 + style * 38 + int(drive * 190);
  noStroke();
  for (int i = 0; i < count; i++) {
    float h1 = fractHash(i * 12.9898 + layer * 78.233);
    float h2 = fractHash(i * 39.3467 + layer * 11.135);
    float h3 = fractHash(i * 4.717 + layer * 31.31);
    float drift = t * (0.08 + style * 0.035);
    float a = h1 * TWO_PI + drift + 0.12 * sin(t * (0.7 + style * 0.13) + h2 * TWO_PI);
    float rr = pow(h2, 0.52 + style * 0.04) * 0.985;
    float nx = cos(a) * rr;
    float ny = sin(a) * rr;
    float wave = abs(chChannelWave(layer, nx, ny, t + h1 * 2.0));
    float grain = noise((nx + 1.5) * (2.0 + style), (ny + 1.5) * (2.0 + style), t * 0.22 + h3);
    float band = constrain(1.0 - wave * (1.42 + style * 0.18), 0, 1);
    float shell = sqrt(max(0, 1 - rr * rr));
    float score = constrain(band * 0.62 + grain * 0.30 + shell * 0.16, 0, 1);
    if (score < 0.18 + h3 * 0.40) continue;
    float px = cx + nx * rad;
    float py = cy + ny * rad;
    float alphaPt = (34 + 176 * drive) * score * (0.36 + shell * 0.64);
    float ps = (1.5 + score * (style == 0 ? 6.2 : style == 2 ? 3.6 : 2.8) + drive * 1.5)
             * chSpriteTierScale(h1, score);

    if (style == 0) {
      fill(red(c), green(c), blue(c), alphaPt * 0.48);
      ellipse(px, py, ps * 2.2, ps * 2.2);
      fill(red(c), green(c), blue(c), alphaPt);
      ellipse(px, py, ps, ps);
    } else if (style == 1) {
      fill(red(c), green(c), blue(c), alphaPt);
      rect(px - ps * 0.5, py - ps * 0.5, ps, ps);
    } else if (style == 2) {
      fill(red(c), green(c), blue(c), alphaPt * 0.78);
      rect(px - ps * 0.55, py - ps * 0.55, ps * 1.1, ps * 1.1);
      if (score > 0.72) {
        fill(245, 250, 255, alphaPt * 0.48);
        rect(px - ps * 0.18, py - ps * 0.18, ps * 0.36, ps * 0.36);
      }
    } else if (style == 3) {
      fill(red(c), green(c), blue(c), alphaPt * 0.86);
      rect(px - ps * 0.48, py - ps * 0.48, ps * 0.96, ps * 0.96);
      if (h1 < 0.16) {
        fill(0, 0, 0, alphaPt * 0.42);
        rect(px + ps * 0.28, py + ps * 0.28, ps * 0.55, ps * 0.55);
      }
    } else {
      fill(red(c), green(c), blue(c), alphaPt * 0.72);
      ellipse(px, py, ps * 1.25, ps * 1.25);
      fill(red(c), green(c), blue(c), alphaPt);
      rect(px - ps * 0.32, py - ps * 0.32, ps * 0.64, ps * 0.64);
    }
  }
}

void drawChoirShimmerLayer(float cx, float cy, float rad, float t) {
  float drive = constrain(chLayerDrive(3), 0, 1);
  if (drive < 0.012) return;
  color c = chChannelColor(3);
  noStroke();
  int count = 330 + int(drive * 280);
  for (int i = 0; i < count; i++) {
    float h1 = fractHash(i * 17.27 + 301.0);
    float h2 = fractHash(i * 6.91 + 97.0);
    float h3 = fractHash(i * 28.13 + 13.0);
    float bandLat = sin(t * 1.55 + h1 * TWO_PI + h2 * 3.0) * 0.18;
    float a = h1 * TWO_PI + t * (0.18 + drive * 0.25);
    float rr = constrain(0.18 + h2 * 0.78 + 0.025 * sin(a * 5.0 + t * 2.8), 0.04, 0.985);
    float nx = cos(a) * rr;
    float ny = constrain(sin(a) * rr * 0.82 + bandLat, -0.985, 0.985);
    float shell = sqrt(max(0, 1 - min(1, nx * nx + ny * ny)));
    float wave = abs(chChannelWave(3, nx, ny, t + h3 * 2.0));
    float shimmer = 0.5 + 0.5 * sin(t * 8.0 + h1 * 21.0 + ny * 9.0);
    float score = constrain((1.0 - wave * 1.65) * 0.62 + shimmer * 0.28 + shell * 0.22, 0, 1);
    if (score < 0.22 + h3 * 0.34) continue;
    float px = cx + nx * rad;
    float py = cy + ny * rad;
    float ps = (1.2 + score * 4.2 + drive * 1.4) * chSpriteTierScale(h2, score);
    float alphaPt = (42 + 178 * drive) * score * (0.45 + shell * 0.55);
    fill(red(c), green(c), blue(c), alphaPt * 0.45);
    ellipse(px, py, ps * 2.4, ps * 1.05);
    fill(245, 250, 255, alphaPt * (0.20 + shimmer * 0.32));
    rect(px - ps * 0.22, py - ps * 0.22, ps * 0.44, ps * 0.44);
  }
}

float fractHash(float x) {
  float h = sin(x) * 43758.5453;
  return h - floor(h);
}

float chSpriteTierScale(float h, float score) {
  float tier = constrain(h * 0.72 + score * 0.28, 0, 1);
  float base = tier < 0.34 ? 0.78 : (tier < 0.67 ? 1.0 : 1.22);
  float jitter = 0.97 + 0.06 * fractHash(h * 817.31 + score * 113.7);
  return base * jitter;
}

color chChannelColor(int layer) {
  if (layer == 0) return chMappedLayerColor(2);
  if (layer == 1) return chMappedLayerColor(3);
  if (layer == 2) return chMappedLayerColor(4);
  if (layer == 3) return chMappedLayerColor(5);
  if (layer == 4) return chMappedLayerColor(6);
  return chMappedLayerColor(7);
}

color chMappedLayerColor(int mappedLayer) {
  if (mappedLayer == 0) return color(0, 0, 0);          // FOUNDATION: black
  if (mappedLayer == 1) return color(255, 214, 48);     // SURFACE: yellow/gold
  if (mappedLayer == 2) return color(255, 40, 28);      // DRONE: red
  if (mappedLayer == 3) return color(255, 138, 22);     // ARP: orange
  if (mappedLayer == 4) return color(42, 220, 76);      // GLASS: green
  if (mappedLayer == 5) return color(48, 145, 255);     // CHOIR: blue
  if (mappedLayer == 6) return color(75, 72, 235);      // KEYS: indigo
  if (mappedLayer == 7) return color(170, 74, 255);     // ECO: violet
  return color(250, 252, 245);                          // ACTION: white
}

void drawSphereGeometryLayers(float cx, float cy, float rad, float t) {
  pushStyle();
  noStroke();
  color white = chMappedLayerColor(8);
  color black = chMappedLayerColor(0);

  // --- Global opacity scale for the whole dithered skin. Lower = more see-through.
  // Tune SURFACE_OPACITY in [0.20 .. 0.70] to taste; 0.42 reads as a translucent veil.
  final float SURFACE_OPACITY = 0.42;

  // ===== Latitudinal banded dither (the body of the skin) =====
  for (int band = -6; band <= 6; band++) {
    float k = band / 7.0;
    float bandY = cy + k * rad;
    float bandW = rad * 2.0 * sqrt(max(0, 1 - k * k));
    int pts = 150;
    for (int i = 0; i < pts; i++) {
      float h = fractHash(i * 17.9 + band * 101.3);
      if (h > 0.62 + landauerCoherence * 0.20) continue;

      float a = TWO_PI * i / pts + t * 0.025;
      float px = cx + cos(a) * bandW * 0.5;
      float py = bandY + sin(a) * rad * 0.055;

      float local = chSurfaceFieldAt(px, py, cx, cy, rad, t);
      float cellScale = lerp(2.6, 0.7, constrain(local, 0, 1)) * chSpriteTierScale(h, local);

      float alphaPt = (10 + 40 * h + 44 * foundationalCoherence) * SURFACE_OPACITY;
      fill(red(black), green(black), blue(black), alphaPt);
      rect(px - cellScale * 0.5, py - cellScale * 0.5, cellScale, cellScale);

      if (h < 0.11 + landauerCoherence * 0.08) {
        float bs = cellScale * 0.5;
        fill(red(white), green(white), blue(white), (16 + 46 * landauerCoherence) * SURFACE_OPACITY);
        rect(px - bs * 0.5, py - bs * 0.5, bs, bs);
      }
    }
  }

  // ===== Meridional dither (front-facing shading) =====
  for (int mer = 0; mer < 12; mer++) {
    float meridian = TWO_PI * mer / 12.0 + t * 0.05;
    for (int i = 0; i < 130; i++) {
      float lat = map(i, 0, 129, -HALF_PI, HALF_PI);
      float z = cos(lat) * cos(meridian);
      if (z < -0.18) continue;
      float h = fractHash(i * 9.37 + mer * 45.7 + floor(t * 12));
      if (h > 0.60) continue;

      float x3 = cos(lat) * sin(meridian);
      float y3 = sin(lat);
      float px = cx + x3 * rad;
      float py = cy - y3 * rad;

      float front = map(z, -0.18, 1, 0.22, 1.0);
      float local = chSurfaceFieldAt(px, py, cx, cy, rad, t);
      float ps = (0.7 + h * 1.6 + surfaceCurv * 1.1)
               * lerp(1.4, 0.6, constrain(local, 0, 1))
               * chSpriteTierScale(h, local);

      float aPt = (14 + 64 * front) * (0.45 + landauerCoherence * 0.55) * SURFACE_OPACITY;
      fill(red(white), green(white), blue(white), aPt);
      rect(px - ps * 0.5, py - ps * 0.5, ps, ps);
    }
  }
  popStyle();
}

void drawGalaxyBeltramiShearOnSphere(float cx, float cy, float rad, float t) {
  if (!galaxyLoaded || galaxyBlend < 0.01) return;
  pushStyle();
  float mn = 999;
  float mx = -999;
  for (int r = 0; r < 32; r++) {
    for (int c = 0; c < 32; c++) {
      float gv = galaxyGrid[r][c];
      mn = min(mn, gv);
      mx = max(mx, gv);
    }
  }
  float spin = t * (0.08 + galaxyFloquetCoupling * 0.20);
  float shear = constrain(abs(beltramiAlignment) * 0.55 + galaxyBoundaryPersist * 0.25 + galaxyBlend * 0.20, 0, 1);
  noStroke();
  for (int i = 0; i < 260; i++) {
    float h1 = fractHash(i * 23.17 + 501.0);
    float h2 = fractHash(i * 9.43 + 113.0);
    float h3 = fractHash(i * 41.91 + 37.0);
    float a = h1 * TWO_PI + spin + sin(t * 0.22 + h2 * TWO_PI) * shear * 0.34;
    float rr = pow(h2, 0.58) * 0.985;
    float nx = cos(a + beltramiBx * 0.28) * rr;
    float ny = sin(a + beltramiBy * 0.28) * rr * (0.88 + 0.08 * sin(t * 0.35 + h1 * TWO_PI));
    float inside = nx * nx + ny * ny;
    if (inside > 1.0) continue;
    int gr = constrain(int(map(ny, -1, 1, 0, 31)), 0, 31);
    int gc = constrain(int(map(nx, -1, 1, 0, 31)), 0, 31);
    float gv = galaxyDisplayValue(galaxyGrid[gr][gc], mn, mx);
    float gate = constrain(gv * 0.70 + shear * 0.30, 0, 1);
    if (gate < 0.18 + h3 * 0.46) continue;
    float shell = sqrt(max(0, 1 - inside));
    float px = cx + nx * rad;
    float py = cy + ny * rad;
    color gcx = galaxyColor(gv);
    float ps = (1.2 + gate * 4.4 + galaxyBlend * 1.7) * chSpriteTierScale(h2, gate);
    float alphaPt = (24 + 150 * galaxyBlend) * gate * (0.40 + shell * 0.60);
    fill(red(gcx), green(gcx), blue(gcx), alphaPt * 0.48);
    ellipse(px, py, ps * 1.75, ps * 1.1);
    fill(245, 232, 255, alphaPt * 0.28);
    rect(px - ps * 0.18, py - ps * 0.18, ps * 0.36, ps * 0.36);
  }
  popStyle();
}

float chSurfaceFieldAt(float px, float py, float cx, float cy, float rad, float t) {
  float nx = (px - cx) / max(1.0, rad);
  float ny = (py - cy) / max(1.0, rad);
  float n = noise(nx * 2.4 + 10.0, ny * 2.4 + 10.0, t * 0.12);
  float fieldBias = constrain(surfaceCurv * 0.6 + foundationalCoherence * 0.4, 0, 1);
  return constrain(0.35 * n + 0.65 * (n * fieldBias + (1 - fieldBias) * 0.5), 0, 1);
}

void drawActionOrbitTrailOnSphere(float cx, float cy, float rad, float t) {
  int count = min(trailCount, TRAIL_LEN);
  noStroke();
  color white = chMappedLayerColor(8);
  for (int i = 1; i < count; i += 2) {
    int idx = (trailHead - count + i + TRAIL_LEN) % TRAIL_LEN;
    float[] pTrail = chProjectActionPoint(trailX[idx], trailY[idx], t - (count - i) * 0.012);
    float fade = map(i, 1, count, 16, 165);
    float front = map(pTrail[2], -1, 1, 0.35, 1.0);
    float ps = 1.5 + front * 3.3 + i / max(1.0, (float)count) * 2.0;
    fill(red(white), green(white), blue(white), fade * front);
    ellipse(cx + pTrail[0] * rad, cy + pTrail[1] * rad, ps, ps);
  }

  float[] p = chProjectActionPoint(orb_x, orb_y, t);
  float sx = cx + p[0] * rad;
  float sy = cy + p[1] * rad;
  float front = map(p[2], -1, 1, 0.45, 1.0);
  noStroke();
  fill(red(white), green(white), blue(white), 220 * front);
  ellipse(sx, sy, 14 + 5 * front, 14 + 5 * front);
  fill(red(white), green(white), blue(white), 42 + 80 * front);
  ellipse(sx, sy, 36 + 12 * front, 36 + 12 * front);
  fill(chMappedLayerColor(2), 115);
  ellipse(sx, sy, 7, 7);
}

float[] chProjectActionPoint(float ox, float oy, float t) {
  float theta = atan2(oy, ox) + 0.22 * sin(t * 2.4 + chLayerDrive(1) * 3.0);
  float radiusNorm = constrain(sqrt(ox * ox + oy * oy) / ORB_BOUND, 0, 1);
  float lat = constrain((radiusNorm - 0.5) * PI * 0.82
             + 0.22 * sin(theta * 2.0 + t * (0.8 + scDiagRhythmComplexity)), -1.18, 1.18);
  float x = cos(lat) * sin(theta);
  float y = -sin(lat);
  float z = cos(lat) * cos(theta);
  float[] p = {x, y, z};
  return p;
}

void drawSphereLegend(int x, int y) {
  String[] labels = {"FOUNDATION", "SURFACE", "DRONE", "ARP", "GLASS", "CHOIR", "KEYS", "ECO", "ACTION"};
  fill(170, 190, 190);
  textSize(9);
  textAlign(LEFT, TOP);
  text("MAPPED LAYERS", x - 18, y - 18);
  for (int i = 0; i < labels.length; i++) {
    fill(chMappedLayerColor(i));
    noStroke();
    if (i == 0) {
      stroke(90, 105, 105);
      rect(x, y + i * 15, 7, 7);
      noStroke();
    } else if (i == 8) {
      ellipse(x + 3.5, y + i * 15 + 3.5, 7, 7);
    } else {
      rect(x, y + i * 15, 7, 7);
    }
    fill(185, 205, 205);
    text(labels[i], x + 13, y + i * 15 - 2);
  }
}

void drawChladniRightPanels() {
  chCard(CH_RIGHT_X, CH_SPHERE_Y, CH_RIGHT_W, CH_SPHERE_SIZE, "ACTION / MIX");
  int x = CH_RIGHT_X + 14;
  int y = CH_SPHERE_Y + 22;
  fill(160, 190, 192);
  textSize(9);
  textAlign(LEFT, TOP);
  text("TRANSPORT", x, y);
  text("SWEEP TARGET", x, y + 104);
  chTinyLabel(x, y + 120, "A*");
  chTinyLabel(x + 70, y + 120, "D*");
  chTinyLabel(x + 132, y + 120, "SEC");
  text("HOLONOMY RUNNERS", x, y + 146);
  text("OUTPUT / ACTION", x, y + 236);
  text("VOICE GATES", x, y + 312);
  text("PROJECTORS", x, y + 378);
  text("MANIFOLD GEOMETRY", x, y + 482);
  text("SC LAYER ENERGY", x, y + 536);

  y += 554;
  chLayerMeter(x, y, "DRONE", chLayerDrive(0), chChannelColor(0)); y += 18;
  chLayerMeter(x, y, "ARP", chLayerDrive(1), chChannelColor(1)); y += 18;
  chLayerMeter(x, y, "GLASS", chLayerDrive(2), chChannelColor(2)); y += 18;
  chLayerMeter(x, y, "CHOIR", chLayerDrive(3), chChannelColor(3)); y += 18;
  chLayerMeter(x, y, "KEYS", chLayerDrive(4), chChannelColor(4)); y += 18;
  chLayerMeter(x, y, "ECO", chLayerDrive(5), chChannelColor(5)); y += 28;
  fill(120, 150, 152);
  text("geometry", x, y); fill(72, 205, 255); textAlign(RIGHT, TOP);
  text((surfaceReady && surfaceBridge != null) ? surfaceBridge.name : "local field", CH_RIGHT_X + CH_RIGHT_W - 14, y);
  textAlign(LEFT, TOP);
  y += 18;
  fill(120, 150, 152);
  text("curvature", x, y); fill(72, 205, 255); textAlign(RIGHT, TOP);
  text(safeNf(surfaceCurv, 1, 3), CH_RIGHT_X + CH_RIGHT_W - 14, y);
  textAlign(LEFT, TOP);
  y += 18;
  fill(120, 150, 152);
  text("coherence", x, y); fill(72, 205, 255); textAlign(RIGHT, TOP);
  text(safeNf(landauerCoherence, 1, 3), CH_RIGHT_X + CH_RIGHT_W - 14, y);
}

void drawLaunchpadModeIndicator(int x, int y, int w) {
  pushStyle();
  int active = launchpadActiveSlot;
  color activeColor = launchpadSlotColor(active);
  float pulse = constrain(1.0 - (frameCount - launchpadActiveFrame) / 90.0, 0, 1);
  noStroke();
  fill(6, 12, 15, 210);
  rect(x, y, w, 58, 4);
  stroke(36, 85, 94, 185);
  noFill();
  rect(x, y, w, 58, 4);

  fill(132, 174, 178);
  textSize(8);
  textAlign(LEFT, TOP);
  text("LPX MODE", x + 8, y + 6);

  fill(red(activeColor), green(activeColor), blue(activeColor), 170 + 70 * pulse);
  textSize(9);
  textAlign(LEFT, TOP);
  text(launchpadActiveMode, x + 8, y + 19);

  int pad = max(8, min(13, (w - 22) / 8));
  int px = x + 8;
  int py = y + 36;
  for (int i = 1; i <= 8; i++) {
    color c = launchpadSlotColor(i);
    int bx = px + (i - 1) * (pad + 2);
    if (i == active) {
      fill(red(c), green(c), blue(c), 58 + 84 * pulse);
      rect(bx - 2, py - 2, pad + 4, pad + 4, 3);
      fill(red(c), green(c), blue(c), 230);
    } else {
      fill(red(c), green(c), blue(c), 72);
    }
    rect(bx, py, pad, pad, 2);
  }

  if (active > 0) {
    int barX = x + 8;
    int barY = y + 52;
    int barW = w - 16;
    noStroke();
    fill(20, 35, 38);
    rect(barX, barY, barW, 3, 2);
    fill(red(activeColor), green(activeColor), blue(activeColor), 185);
    rect(barX, barY, barW * max(0.08, launchpadActiveVelocity), 3, 2);
    fill(120, 150, 152);
    textSize(7);
    textAlign(RIGHT, BOTTOM);
    text("COL " + launchpadActiveColumn, x + w - 8, y + 35);
  }
  popStyle();
}

void drawLaunchpadModeStatus(int x, int y, int w, int h) {
  pushStyle();
  int active = launchpadActiveSlot;
  color c = launchpadSlotColor(active);
  float pulse = constrain(1.0 - (frameCount - launchpadActiveFrame) / 75.0, 0, 1);
  noStroke();
  fill(5, 12, 15, 185);
  rect(x, y, w, h, 4);
  stroke(30, 72, 80, 180);
  noFill();
  rect(x, y, w, h, 4);

  int pad = 8;
  int px = x + 8;
  int py = y + 6;
  for (int i = 1; i <= 8; i++) {
    color pc = launchpadSlotColor(i);
    if (i == active) {
      fill(255, 255, 255, 68 + 90 * pulse);
      rect(px + (i - 1) * 11 - 3, py - 3, pad + 6, pad + 6, 3);
      fill(red(pc), green(pc), blue(pc), 220);
      rect(px + (i - 1) * 11 - 1, py - 1, pad + 2, pad + 2, 2);
    } else {
      fill(red(pc), green(pc), blue(pc), 72);
      rect(px + (i - 1) * 11, py, pad, pad, 2);
    }
  }

  fill(red(c), green(c), blue(c), 210);
  int barX = x + 104;
  int barY = y + h - 5;
  rect(barX, barY, max(10, (w - 208) * launchpadActiveVelocity), 2, 2);
  fill(184, 210, 212);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("LPX P" + (launchpadActivePage + 1) + "  " + launchpadPageName(launchpadActivePage) + "  /  " + launchpadActiveMode, x + 104, y + h * 0.48);
  fill(112, 146, 150);
  textAlign(RIGHT, CENTER);
  text(active > 0 ? ("COL " + launchpadActiveColumn) : "MAIN", x + w - 8, y + h * 0.48);
  popStyle();
}

void chLayerMeter(int x, int y, String label, float v, color c) {
  fill(126, 152, 154);
  textSize(8);
  textAlign(LEFT, CENTER);
  text(label, x, y + 5);
  noStroke();
  fill(23, 34, 38);
  int mw = max(104, CH_RIGHT_W - 106);
  rect(x + 58, y, mw, 8, 3);
  fill(c);
  rect(x + 58, y, constrain(v, 0, 1) * mw, 8, 3);
}

void drawChladniEngineeringColumn() {
  chCard(CH_ENG_X, CH_SPHERE_Y, CH_ENG_W, CH_SPHERE_SIZE, "ENGINEERING");
  int x = chEngSliderX();
  int y = CH_SPHERE_Y + 24;
  int w = chEngSliderW();

  fill(160, 190, 192);
  textSize(9);
  textAlign(LEFT, TOP);
  text("FIELD INPUT COUPLING", x, y);
  y += 20;
  drawChladniEngSlider(0, x, y, w, "OCEAN CURRENT", oceanEngCurrentGain, color(55, 190, 255)); y += chEngSliderStep();
  drawChladniEngSlider(1, x, y, w, "OCEAN SWELL", oceanEngSwellAmp, color(70, 225, 210)); y += chEngSliderStep();
  drawChladniEngSlider(2, x, y, w, "OCEAN BREAK", oceanEngBreakRate, color(120, 210, 120)); y += chEngSliderStep();

  fill(160, 190, 192);
  textSize(9);
  text("ORBIT ENGINE", x, y - 4);
  y += 16;
  drawChladniEngSlider(3, x, y, w, "ECC BIAS", orbitEccentricityBias, color(255, 150, 70)); y += chEngSliderStep();
  drawChladniEngSlider(4, x, y, w, "RESONANCE", orbitResonanceDrive, color(255, 210, 70)); y += chEngSliderStep();
  drawChladniEngSlider(5, x, y, w, "LOCK STRENGTH", orbitLockStrength, color(90, 220, 255)); y += chEngSliderStep();

  fill(160, 190, 192);
  textSize(9);
  text("FLOQUET / PDE", x, y - 4);
  y += 16;
  drawChladniEngSlider(6, x, y, w, "FLOQUET DRIVE", floquetDrive, color(190, 120, 255)); y += chEngSliderStep();
  drawChladniEngSlider(7, x, y, w, "INSTABILITY", floquetInstability, color(255, 80, 130)); y += chEngSliderStep();
  drawChladniEngSlider(8, x, y, w, "QUASI ENERGY", quasiEnergyBias, color(80, 235, 150));

  drawChladniGalaxyBlendBlock(x, y + 44, w);

  int ry = CH_SPHERE_Y + CH_SPHERE_SIZE - 96;
  chEngReadout(x, ry, w, "ORBIT EVENT", orbitEventLabel);
  chEngReadout(x, ry + 22, w, "FLOQUET", fsLifecycleName());
  chEngReadout(x, ry + 44, w, "LOCK/G", safeNf(orbitLockStrength, 1, 2) + " / " + safeNf(fsG, 1, 2));
  chEngReadout(x, ry + 66, w, "OMEGA", safeNf(fsOmega, 1, 3) + " Hz");
  chEngReadout(x, ry + 88, w, "WEIGHTS", "k " + safeNf(fsW_coupling, 1, 2)
                + " e " + safeNf(fsW_quasienergy, 1, 2)
                + " p " + safeNf(fsW_phase_lock, 1, 2));
}

void drawChladniGalaxyBlendBlock(int x, int y, int w) {
  fill(160, 190, 192);
  textSize(9);
  textAlign(LEFT, TOP);
  text("GALAXY / BELTRAMI SHEAR", x, y - 4);

  int mapSize = 62;
  int mapX = x;
  int mapY = y + 16;
  if (galaxyLoaded) {
    float mn = 999;
    float mx = -999;
    for (int r = 0; r < 32; r++) {
      for (int c = 0; c < 32; c++) {
        float gv = galaxyGrid[r][c];
        mn = min(mn, gv);
        mx = max(mx, gv);
      }
    }
    noStroke();
    float cell = mapSize / 32.0;
    for (int r = 0; r < 32; r++) {
      for (int c = 0; c < 32; c++) {
        fill(galaxyColor(galaxyDisplayValue(galaxyGrid[r][c], mn, mx)));
        rect(mapX + c * cell, mapY + r * cell, cell + 0.2, cell + 0.2);
      }
    }
  } else {
    noStroke();
    fill(32, 20, 44, 190);
    rect(mapX, mapY, mapSize, mapSize);
    fill(210, 120, 100);
    textSize(8);
    text("NO MAP", mapX + 8, mapY + 24);
  }
  noFill();
  stroke(92, 130, 150, 140);
  rect(mapX, mapY, mapSize, mapSize);

  int rx = x + mapSize + 12;
  int rw = w - mapSize - 12;
  chEngReadout(rx, mapY, rw, "MAP", galaxyLoaded ? galaxyDisplayName : "not loaded");
  chEngReadout(rx, mapY + 18, rw, "BLEND", safeNf(galaxyBlend, 1, 2));
  chEngReadout(rx, mapY + 36, rw, "CURV / FLQ", safeNf(galaxyFieldCurvature, 1, 2) + " / " + safeNf(galaxyFloquetCoupling, 1, 2));
  chEngReadout(rx, mapY + 54, rw, "BELTRAMI", symbolicBeltramiState);

  fill(20, 34, 38, 230);
  noStroke();
  rect(x, y + 88, w, 7, 3);
  fill(120, 80, 210, 210);
  rect(x, y + 88, constrain(galaxyBlend, 0, 1) * w, 7, 3);
}

int chEngSliderX() {
  return CH_ENG_X + 14;
}

int chEngSliderW() {
  return CH_ENG_W - 28;
}

int chEngSliderStep() {
  return 38;
}

void drawChladniEngSlider(int idx, int x, int y, int w, String label, float value, color c) {
  int barW = w - 52;
  int barY = y + 16;
  fill(140, 168, 170);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  fill(86, 220, 255);
  textAlign(RIGHT, TOP);
  text(safeNf(value, 1, 2), x + w, y);
  noStroke();
  fill(20, 34, 38, 230);
  rect(x, barY, barW, 7, 3);
  fill(red(c), green(c), blue(c), 215);
  rect(x, barY, constrain(value, 0, 1) * barW, 7, 3);
  stroke(60, 80, 82, 170);
  line(x + barW * 0.5, barY - 2, x + barW * 0.5, barY + 10);
  if (idx == 5 && orbitLockManual) {
    noStroke();
    fill(255, 210, 90, 190);
    rect(x + barW + 8, barY - 2, 34, 11, 2);
    fill(5, 10, 12);
    textAlign(CENTER, CENTER);
    textSize(7);
    text("MAN", x + barW + 25, barY + 3);
  }
}

void chEngReadout(int x, int y, int w, String label, String value) {
  fill(88, 124, 128);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
  fill(70, 220, 255);
  textAlign(RIGHT, TOP);
  text(value, x + w, y);
}

String fsLifecycleName() {
  if (fsLifecycleState == FS_STATE_IDLE) return "IDLE";
  if (fsLifecycleState == FS_STATE_ARMED) return "ARMED";
  if (fsLifecycleState == FS_STATE_LOCKING) return "LOCKING";
  if (fsLifecycleState == FS_STATE_INJECTING) return "INJECT";
  if (fsLifecycleState == FS_STATE_INTEGRATED) return "INTEGRATED";
  if (fsLifecycleState == FS_STATE_RELEASING) return "RELEASE";
  if (fsLifecycleState == FS_STATE_COOLDOWN) return "COOLDOWN";
  return "STATE " + fsLifecycleState;
}

void drawChladniBottomPanels() {
  chCard(CH_MAIN_X, CH_BOTTOM_Y, W - CH_MAIN_X - 14, CH_BOTTOM_H, "FIELD / AUDIO / GEOMETRY");

  int fieldY = CH_BOTTOM_Y + 34;
  int fieldX = CH_MAIN_X + 18;
  int holoX = CH_MAIN_X + 242;
  int mixX = CH_MAIN_X + 500;
  int ecoX = CH_MAIN_X + 732;
  int envX = CH_MAIN_X + 1006;

  chSectionLabel(fieldX, fieldY - 20, "RDFT FIELD");
  chTinyLabel(fieldX + 136, fieldY - 10, "EXACT");
  chTinyLabel(fieldX, fieldY + 108, "F=" + safeNf(phi_residual, 1, 3)
              + "  G=" + safeNf(phi_gain, 1, 3)
              + "  T=" + safeNf(phi_threshold_prox, 1, 2));

  chSectionLabel(holoX, fieldY - 20, "HOLONOMY LOOP");
  String[] holoTop = {"A0", "A1", "D0", "D1"};
  String[] holoBot = {"LEG", "DWELL", "LOOPS", "PAIRS"};
  for (int i = 0; i < 4; i++) {
    int tx = holoX + i * 58;
    chTinyLabel(tx, fieldY - 8, holoTop[i]);
    chTinyLabel(tx, fieldY + 40, holoBot[i]);
  }
  chTinyLabel(holoX, fieldY + 94,
              "leg " + holoSweep.legIndex + "  loop " + holoSweep.loopIndex
              + "  area " + safeNf(holoSweep.lastLoopArea, 1, 3));

  chSectionLabel(mixX, fieldY - 20, "SUPERCOLLIDER LAYERS");
  chTinyLabel(mixX, fieldY + 108, "root " + safeNf(scDiagRootFreq, 1, 1)
              + " Hz  bpm " + safeNf(scDiagDynamicBPM, 1, 1)
              + "  voices " + scVoiceCount);

  chSectionLabel(ecoX, fieldY - 20, "ECO / EG EVENTS");
  chTinyLabel(ecoX, fieldY - 8, "CHIRP     LEVEL");
  chTinyLabel(ecoX, fieldY + 14, "CALL      LEVEL");
  chTinyLabel(ecoX, fieldY + 36, "GROWTH    LEVEL");
  chTinyLabel(ecoX, fieldY + 58, "FISSURE   LEVEL");
  chTinyLabel(ecoX, fieldY + 80, "EG PROBE  LEVEL");
  chTinyLabel(ecoX, fieldY + 108, "chirp "
              + (audioDiagEcoChirpLastAge < 0 ? "--" : safeNf(audioDiagEcoChirpLastAge, 1, 1) + "s")
              + "  call "
              + (audioDiagEcoCallLastAge < 0 ? "--" : safeNf(audioDiagEcoCallLastAge, 1, 1) + "s"));

  chSectionLabel(envX, fieldY - 20, "ENVIRONMENT");
  chTinyLabel(envX, fieldY + 108, "surf " + safeNf(surfaceCurv, 1, 2)
              + "  coh " + safeNf(landauerCoherence, 1, 2));
}

void chSectionLabel(int x, int y, String label) {
  fill(164, 198, 202);
  textSize(9);
  textAlign(LEFT, TOP);
  text(label, x, y);
}

void chTinyLabel(int x, int y, String label) {
  fill(96, 130, 134);
  textSize(8);
  textAlign(LEFT, TOP);
  text(label, x, y);
}

void drawParamLine(int x, int y, String label, String val) {
  fill(125, 150, 152);
  textSize(10);
  textAlign(LEFT, TOP);
  text(label, x, y);
  fill(80, 205, 255);
  textAlign(RIGHT, TOP);
  text(val, x + 145, y);
}

void drawChladniStatusBar() {
  chCard(CH_LEFT_X, H - 38, W - 24, 28, "");
  fill(120, 150, 150);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("STATUS", CH_LEFT_X + 18, H - 24);
  fill(40, 230, 95);
  ellipse(CH_LEFT_X + 76, H - 24, 8, 8);
  fill(185, 205, 205);
  text(oscLoggingEnabled ? "RECORDING" : "PROCESSING", CH_LEFT_X + 92, H - 24);
  textAlign(CENTER, CENTER);
  drawLaunchpadModeStatus(W / 2 - 230, H - 34, 460, 20);
  textAlign(RIGHT, CENTER);
  text("RDFT Chladni v0.1", W - 42, H - 24);
}

void chMiniHeat(int x, int y, int w, int h, float[][] data, color[] cmap, String title) {
  chCard(x, y, w, h, title);
  int s = min(w - 18, h - 34);
  int gx = x + (w - s) / 2;
  int gy = y + h - s - 9;
  int gw = s;
  int gh = s;
  int step = 4;
  noStroke();
  for (int r = 0; r < GRID; r += step) {
    for (int c = 0; c < GRID; c += step) {
      float v = data != null ? data[r][c] : 0;
      fill(sampleCmap(cmap, constrain(v, 0, 1)));
      rect(gx + map(c, 0, GRID, 0, gw), gy + map(r, 0, GRID, 0, gh), max(1, gw / 25.0), max(1, gh / 25.0));
    }
  }
}

void chMiniSpectrum(int x, int y, int w, int h, String title) {
  chCard(x, y, w, h, title);
  int s = min(w - 18, h - 34);
  int gx = x + (w - s) / 2;
  int gy = y + h - s - 9;
  int gw = s;
  int gh = s;
  stroke(35, 45, 55);
  for (int i = 1; i < 4; i++) line(gx, gy + gh * i / 4, gx + gw, gy + gh * i / 4);
  if (cross1D != null) {
    for (int d = 0; d <= min(depth, 4); d++) {
      float[] ll = getCrossAtDepth(d);
      if (ll == null) continue;
      stroke(depthColors[d % depthColors.length]);
      strokeWeight(d == 0 ? 2 : 1);
      noFill();
      beginShape();
      for (int i = 0; i < GRID; i++) {
        float wt = pow(alpha, -d);
        vertex(gx + map(i, 0, GRID - 1, 0, gw), gy + gh - map(ll[i] * wt, 0, 1, 0, gh));
      }
      endShape();
    }
  }
}

void chMiniOrbit(int x, int y, int w, int h, String title) {
  chCard(x, y, w, h, title);
  int s = min(w - 18, h - 34);
  int gx = x + (w - s) / 2;
  int gy = y + h - s - 9;
  int gw = s;
  int gh = s;
  stroke(50, 64, 70);
  noFill();
  rect(gx, gy, gw, gh);
  drawMiniActionGeometry(gx, gy, gw, gh);
  float cx = gx + gw / 2.0;
  float cy = gy + gh / 2.0;
  float scale = min(gw, gh) / (ORB_BOUND * 2.2);
  int count = min(trailCount, 90);
  noStroke();
  for (int i = 0; i < count; i += 2) {
    int idx = (trailHead - count + i + TRAIL_LEN) % TRAIL_LEN;
    float fade = map(i, 0, max(1, count - 1), 30, 140);
    fill(250, 252, 245, fade);
    ellipse(cx + trailX[idx] * scale, cy - trailY[idx] * scale, 2.2, 2.2);
  }
  noStroke();
  fill(chMappedLayerColor(2));
  ellipse(cx + orb_x * scale, cy - orb_y * scale, 8, 8);
}

void drawMiniActionGeometry(int gx, int gy, int gw, int gh) {
  float cx = gx + gw / 2.0;
  float cy = gy + gh / 2.0;
  float rad = min(gw, gh) * 0.46;
  float t = frameCount * 0.018;

  noStroke();
  for (int yy = -int(rad); yy <= int(rad); yy += 5) {
    for (int xx = -int(rad); xx <= int(rad); xx += 5) {
      float rr = sqrt(xx * xx + yy * yy) / rad;
      if (rr > 1.0) continue;
      float nx = xx / rad;
      float ny = yy / rad;
      float field = abs(chladniAudioFieldValue(nx, ny, t));
      float shell = sqrt(max(0, 1 - rr * rr));
      color pc = lerpColor(color(8, 16, 22), color(70, 205, 255), constrain((1.0 - field) * 0.68 + shell * 0.20, 0, 1));
      fill(red(pc), green(pc), blue(pc), 28 + 90 * shell);
      rect(cx + xx, cy + yy, 4, 4);
    }
  }

  noStroke();
  for (int b = 0; b < 3; b++) {
    color c = chChannelColor(b + 1);
    float base = 0.28 + b * 0.22;
    for (int i = 0; i <= 96; i += 2) {
      float a = map(i, 0, 96, -PI, PI);
      float wave = chChannelWave(b + 1, cos(a) * base, sin(a) * base, t + b * 0.3);
      float rr = constrain(base + wave * 0.055, 0.05, 0.98);
      float h = fractHash(i * 17.1 + b * 44.7);
      if (h > 0.58) continue;
      float px = cx + cos(a) * rr * rad;
      float py = cy + sin(a) * rr * rad;
      fill(red(c), green(c), blue(c), 54 + 92 * h);
      rect(px - 1.2, py - 1.2, 2.4, 2.4);
    }
  }

  for (int i = 0; i < 80; i++) {
    float h = fractHash(i * 8.13);
    float a = TWO_PI * i / 80.0;
    float rr = rad * (0.42 + h * 0.43);
    fill(250, 252, 245, 28 + 72 * h);
    rect(cx + cos(a) * rr - 1, cy + sin(a) * rr - 1, 2, 2);
  }
}

void chMiniCoherence(int x, int y, int w, int h, String title) {
  chCard(x, y, w, h, title);
  int gx = x + 60;
  int gy = y + 22;
  int gw = w - 86;
  int gh = h - 30;
  noStroke();
  for (int i = 0; i < 160; i++) {
    float px = gx + random(gw);
    float py = gy + random(gh);
    float v = noise(px * 0.018, py * 0.018, frameCount * 0.01);
    fill(lerpColor(color(60, 30, 130), color(255, 70, 180), v), 110);
    ellipse(px, py, 2, 2);
  }
  drawRDFTMark(x + 16, y + 23, 34);
}

void chMetrics(int x, int y, int w, int h) {
  chCard(x, y, w, h, "07  STATE METRICS");
  int tx = x + 76;
  int ty = y + 28;
  drawParamLine(tx, ty, "COHERENCE", safeNf(foundationalCoherence, 1, 3)); ty += 18;
  drawParamLine(tx, ty, "ENTROPY", safeNf(metricEntropy, 1, 3)); ty += 18;
  drawParamLine(tx, ty, "SYMMETRY", safeNf(1.0 - constrain(metricKLDivergence, 0, 1), 1, 3)); ty += 18;
  drawParamLine(tx, ty, "COMPLEXITY", safeNf(metricFractalDim, 1, 3)); ty += 18;
  drawParamLine(tx, ty, "STABILITY", safeNf(cartStability, 1, 3));
  drawRDFTMark(x + 16, y + 28, 34);
}

void chCard(int x, int y, int w, int h, String title) {
  fill(5, 10, 13, 230);
  stroke(37, 55, 60);
  strokeWeight(1);
  rect(x, y, w, h, 6);
  if (title != null && title.length() > 0) {
    fill(190, 210, 210);
    textSize(11);
    textAlign(LEFT, TOP);
    text(title, x + 12, y + 8);
  }
}

void drawChladniGrid(int x, int y, int w, int h) {
  stroke(34, 48, 54);
  strokeWeight(1);
  for (int gx = x; gx <= x + w; gx += 44) line(gx, y, gx, y + h);
  for (int gy = y; gy <= y + h; gy += 44) line(x, gy, x + w, gy);
}

void drawRDFTMark(int x, int y, int s) {
  noFill();
  stroke(180, 196, 200, 185);
  strokeWeight(2);
  triangle(x, y + s, x + s * 0.5, y, x + s, y + s);
  triangle(x + s * 0.22, y + s * 0.76, x + s * 0.5, y + s * 0.22, x + s * 0.78, y + s * 0.76);
  strokeWeight(1);
}

float chladniModeValue(int idx, float x, float y, float t) {
  int n = 1 + (idx % 4);
  int m = 2 + ((idx / 4) % 4);
  float radial = sqrt(x * x + y * y);
  float theta = atan2(y, x);
  float rectPart = sin(n * PI * (x + 1.0) * 0.5 + t) * sin(m * PI * (y + 1.0) * 0.5 - t * 0.7);
  float polarPart = cos((n + m) * theta + t * 0.9) * sin((m + 1) * PI * radial - t * 0.35);
  return rectPart * 0.58 + polarPart * 0.42;
}

// ========== COMPUTATION FUNCTIONS ==========
void computeFrames() {
  dominant = computeDominant(depth, alpha);
  combined = computeCombined(depth, alpha);
  cross1D = computeCross1D(depth, alpha);
}

void buildSweepCache() {
  // Build into local arrays first.  Older builds allocated the global sweepCache
  // before filling it, so the draw/OSC thread could briefly read zero-filled
  // alpha slots and transmit alpha=0.00.  That was a major freeze/glitch source.
  if (sweepBuilding) return;
  sweepBuilding = true;
  int localDepth = safeDepthValue(depth);
  float[][][] localCache = new float[SWEEP_STEPS][GRID][GRID];
  float[] localAlphas = new float[SWEEP_STEPS];
  for (int i = 0; i < SWEEP_STEPS; i++) {
    float a = safeAlphaValue(map(i, 0, SWEEP_STEPS - 1, 1.0, 4.5));
    localAlphas[i] = a;
    localCache[i] = computeCombined(localDepth, a);
  }
  sweepCache = localCache;
  sweepAlphas = localAlphas;
  sweepIdx = 0;
  sweepDir = 1;
  sweepReady = true;
  sweepBuilding = false;
}

float[][] makeSoftLayer(int target, float a, int sz) {
  float[][] p = new float[sz][sz];
  int n = (int)Math.pow(2, target);
  float sp = (float)sz / (n + 1);
  float sig = sp / 2.5;
  // At alpha=1.0 all layers have equal weight (1.0^-n = 1.0) — Planck threshold behavior
  float wt = (a <= 1.001) ? 1.0 : (float)Math.pow(a, -target);
  for (int r = 0; r < sz; r++) {
    for (int c = 0; c < sz; c++) {
      float val = 0;
      for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
          float dx = c - sp * (i + 1);
          float dy = r - sp * (j + 1);
          val += (float)Math.exp(-(dx * dx + dy * dy) / (2 * sig * sig));
        }
      }
      p[r][c] = val * wt;
    }
  }
  float mx = 0;
  for (int r = 0; r < sz; r++) {
    for (int c = 0; c < sz; c++) {
      if (p[r][c] > mx) mx = p[r][c];
    }
  }
  if (mx > 0) {
    for (int r = 0; r < sz; r++) {
      for (int c = 0; c < sz; c++) {
        p[r][c] /= mx;
      }
    }
  }
  return p;
}

float[][] computeDominant(int d, float a) {
  float[][][] layers = new float[d + 1][GRID][GRID];
  for (int i = 0; i <= d; i++) {
    layers[i] = makeSoftLayer(i, a, GRID);
  }
  float[][] dom = new float[GRID][GRID];
  for (int r = 0; r < GRID; r++) {
    for (int c = 0; c < GRID; c++) {
      int best = 0;
      float bv = layers[0][r][c];
      for (int i = 1; i <= d; i++) {
        if (layers[i][r][c] > bv) {
          bv = layers[i][r][c];
          best = i;
        }
      }
      dom[r][c] = (float)best / Math.max(d, 1);
    }
  }
  return dom;
}

float[][] computeCombined(int d, float a) {
  float[][] combo = new float[GRID][GRID];
  for (int i = 0; i <= d; i++) {
    float[][] l = makeSoftLayer(i, a, GRID);
    float wt = (a <= 1.001) ? 1.0 : (float)Math.pow(a, -i * 0.3);
    for (int r = 0; r < GRID; r++) {
      for (int c = 0; c < GRID; c++) {
        combo[r][c] += l[r][c] * wt;
      }
    }
  }
  float mx = 0;
  for (int r = 0; r < GRID; r++) {
    for (int c = 0; c < GRID; c++) {
      if (combo[r][c] > mx) mx = combo[r][c];
    }
  }
  if (mx > 0) {
    for (int r = 0; r < GRID; r++) {
      for (int c = 0; c < GRID; c++) {
        combo[r][c] /= mx;
      }
    }
  }
  return combo;
}

float[][] computeCombinedFractal(int d, float a, float intermittency) {
    float[][] combo = new float[GRID][GRID];
    
    for (int i = 0; i <= d; i++) {
        float[][] l = makeSoftLayer(i, a, GRID);
        float wt = pow(a, -i * 0.3);
        for (int r = 0; r < GRID; r++) {
            for (int c = 0; c < GRID; c++) {
                combo[r][c] += l[r][c] * wt;
            }
        }
    }
    
    float mx = 0;
    for (float[] row : combo) for (float v : row) if (v > mx) mx = v;
    if (mx > 0) {
        for (float[] row : combo) for (int c = 0; c < row.length; c++) row[c] /= mx;
    }
    
    return combo;
}




float[] computeCross1D(int d, float a) {
  float[] cross = new float[GRID];
  int mid = GRID / 2;
  for (int i = 0; i <= d; i++) {
    float[][] l = makeSoftLayer(i, a, GRID);
    float wt = (a <= 1.001) ? 1.0 : (float)Math.pow(a, -i);
    for (int c = 0; c < GRID; c++) {
      cross[c] += l[mid][c] * wt;
    }
  }
  float mx = 0;
  for (float v : cross) {
    if (v > mx) mx = v;
  }
  if (mx > 0) {
    for (int c = 0; c < GRID; c++) {
      cross[c] /= mx;
    }
  }
  return cross;
}

float[] getCrossAtDepth(int d) {
  if (layerCache == null || layerCache.length != depth + 1) {
    layerCache = new float[depth + 1][GRID][GRID];
    for (int i = 0; i <= depth; i++) {
      layerCache[i] = makeSoftLayer(i, alpha, GRID);
    }
  }
  if (d >= layerCache.length) return null;
  return layerCache[d][GRID / 2];
}




void updateSolarBridge() {
  if (solarBridge == null) return;
  try {
    solarBridge.consumeLatest();
    solarDroneVolume = (sliderSolarVolume != null) ? sliderSolarVolume.getValue() : solarDroneVolume;
  } catch (Exception e) {
    statusMsg = "Solar bridge guarded: " + e;
  }
}

void SOLAR(int val) {
  solarAffectsSynth = !solarAffectsSynth;
  if (btnSolar != null) {
    btnSolar.setLabel(solarAffectsSynth ? "SOLAR→SYNTH: ON" : "SOLAR→SYNTH: OFF");
    btnSolar.setColorBackground(solarAffectsSynth ? color(110, 75, 20) : color(85, 55, 25));
  }
  statusMsg = solarAffectsSynth ? "Solar forcing layer modulates synth" : "Solar layer visual-only";
}

void updateOceanBridge() {
  if (oceanBridge == null) return;
  try {
    oceanBridge.consumeLatest();
  } catch (Exception e) {
    statusMsg = "Ocean bridge guarded: " + e;
  }
}

void drawSolarNodePanel(int x, int y, int w, int h) {
  if (w < 160 || h < 70) return;
  fill(7, 9, 15, 232);
  stroke(120, 88, 50, 170);
  rect(x, y, w, h, 9);
  fill(255, 210, 125);
  textSize(9);
  textAlign(LEFT, TOP);
  text("SOLAR / OCEAN FORCING", x + 9, y + 7);

  float xray = (solarBridge != null) ? solarBridge.xrayNorm : 0;
  float wind = (solarBridge != null) ? solarBridge.windNorm : 0;
  float bz   = (solarBridge != null) ? solarBridge.bzNorm : 0.5;
  float kp   = (solarBridge != null) ? solarBridge.kpNorm : 0;
  float flare = (solarBridge != null) ? solarBridge.flareNorm : 0;
  boolean live = (solarBridge != null) && solarBridge.isLive();

  int cx = x + 47;
  int cy = y + h/2 + 10;
  float t = frameCount * 0.028;
  float polarity = (bz - 0.5) * 2.0;
  float jitter = 2.0 + kp * 7.0 + flare * 9.0;
  float baseR = min(42, h * 0.26) + xray * 6 + kp * 3;

  // Amorphous dithered mesh sphere: low-cost polar lattice, not a bitmap.
  noFill();
  for (int ring = 0; ring < 5; ring++) {
    float rr = baseR + ring * 4.7 + sin(t * 1.5 + ring + wind * 3) * (1.5 + kp * 2.0);
    int alphaRing = 42 + ring * 20;
    stroke(180 + ring * 10, 90 + xray * 120, 45 + flare * 80, alphaRing);
    beginShape();
    for (int i = 0; i <= 36; i++) {
      float a = TWO_PI * i / 36.0;
      float n = sin(a * 3 + t + polarity * 2.5) * jitter + cos(a * 5 - t * 0.7) * (1.2 + wind * 3);
      float px = cx + cos(a) * (rr + n);
      float py = cy + sin(a) * (rr * (0.72 + 0.10 * sin(t + ring)) + n * 0.45);
      vertex(px, py);
    }
    endShape();
  }

  // Dithered internal grid points. More points light up as xray / Kp rise.
  strokeWeight(1);
  for (int gx = -4; gx <= 4; gx++) {
    for (int gy = -3; gy <= 3; gy++) {
      float px = cx + gx * 5.2 + sin(t + gy * 0.8) * (1.0 + wind * 2.5);
      float py = cy + gy * 5.2 + cos(t * 1.2 + gx * 0.7) * (1.0 + abs(polarity) * 3.0);
      float d = dist(px, py, cx, cy);
      if (d < baseR + 8) {
        float gate = (sin(gx * 1.7 + gy * 2.1 + frameCount * 0.11) + 1) * 0.5;
        if (gate < 0.32 + xray * 0.45 + kp * 0.18) {
          stroke(250, 145 + xray * 95, 65 + flare * 110, 105 + gate * 110);
          point(px, py);
        }
      }
    }
  }

  // Electric corona arcs: direction/twist follows Bz; speed follows solar wind.
  noFill();
  strokeWeight(1);
  for (int i = 0; i < 9; i++) {
    float a0 = t * (0.8 + wind * 1.7) + i * TWO_PI / 9.0;
    float arcLen = 0.32 + xray * 0.42 + flare * 0.35;
    float r0 = baseR + 11 + 5 * sin(t + i);
    stroke(255, 145 + 85 * xray, 80 + 120 * flare, 110 + 80 * kp);
    beginShape();
    for (int j = 0; j < 7; j++) {
      float a = a0 + arcLen * j / 6.0 + polarity * 0.22 * sin(j + t);
      float rr = r0 + sin(j * 1.7 + t * 2.0 + i) * (3 + kp * 5);
      vertex(cx + cos(a) * rr, cy + sin(a) * rr * 0.78);
    }
    endShape();
  }

  fill(live ? color(80, 235, 120) : color(220, 130, 70));
  noStroke();
  ellipse(x + w - 18, y + 18, 8, 8);
  fill(165, 190, 190);
  textSize(8);
  textAlign(LEFT, TOP);
  String src = (solarBridge != null) ? solarBridge.sourceLabel : "waiting UDP :5060";
  text((solarAffectsSynth ? "AUDIO ON" : "VISUAL ONLY") + "  " + src, x + 88, y + 24);
  drawMiniReadout(x + 88, y + 49, w - 102, "xray / flare", max(xray, flare), safeNf(xray,1,3) + " / " + safeNf(flare,1,3));
  drawMiniReadout(x + 88, y + 76, w - 102, "wind / Bz", wind, safeNf(wind,1,3) + " / " + safeNf(polarity,1,2));
  drawMiniReadout(x + 88, y + 103, w - 102, "Kp tension", kp, safeNf(kp,1,3));
  drawMiniReadout(x + 88, y + 130, w - 102, "solar vol", solarDroneVolume / 0.12, safeNf(solarDroneVolume,1,3));

  if (oceanBridge != null) {
    float oy = y + h - 22;
    fill(oceanBridge.isLive() && oceanBridge.liveNorm > 0.5 ? color(90, 235, 220) : color(95, 125, 135));
    textSize(7);
    textAlign(LEFT, TOP);
    text("OCEAN e" + safeNf(oceanBridge.energyNorm,1,2) +
      " mem" + safeNf(oceanBridge.memoryNorm,1,2) +
      " v" + safeNf(oceanBridge.velocityNorm,1,2) +
      " a" + safeNf(oceanBridge.accelNorm,1,2), x + 9, oy);
    noStroke();
    fill(40, 150, 170, 120);
    rect(x + 9, y + h - 9, (w - 18) * constrain(oceanBridge.oceanPersistence, 0, 1), 3);
    fill(oceanBridge.oceanBurst > 0.5 ? color(255, 210, 120) : color(80, 230, 220));
    ellipse(x + w - 18, y + h - 19, 6 + oceanBridge.oceanBurst * 6, 6 + oceanBridge.oceanBurst * 6);
  }
}

void sendSolarToSuperCollider() {
  if (oscP5 == null || supercollider == null || solarBridge == null) return;
  if (frameCount % 60 != 0) return; // slower control; solar data changes slowly and SC stays lighter
  OscMessage m = new OscMessage("/rdf/solar");
  m.add(solarAffectsSynth ? 1.0f : 0.0f);
  m.add(solarDroneVolume);
  m.add(solarBridge.xrayNorm);
  m.add(solarBridge.windNorm);
  m.add(solarBridge.bzNorm);
  m.add(solarBridge.kpNorm);
  m.add(solarBridge.flareNorm);
  m.add(solarBridge.rawXray);
  m.add(solarBridge.rawWind);
  m.add(solarBridge.rawBz);
  m.add(solarBridge.rawKp);
  oscP5.send(m, supercollider);
}

void sendOceanToSuperCollider() {
  if (oscP5 == null || supercollider == null || oceanBridge == null) return;
  if (frameCount % 30 != 0) return; // tides move slowly; SC receives smoothed control-rate values
  OscMessage m = new OscMessage("/rdf/ocean");
  float oceanVolBias = getSliderValueSafe("oceanVolumeBias", oceanVolumeBias);
  float oceanCurBias = constrain(getSliderValueSafe("oceanCurrentBias", oceanCurrentBias) * (0.5 + oceanEngCurrentGain), 0.0, 1.0);
  float oceanSwBias  = constrain(getSliderValueSafe("oceanSwellDepth", oceanSwellDepth) * (0.5 + oceanEngSwellAmp), 0.0, 1.0);
  float oceanBreakBias = constrain(0.5 + oceanEngBreakRate, 0.5, 1.5);
  oceanVolumeBias = oceanVolBias;
  oceanCurrentBias = oceanCurBias;
  oceanSwellDepth = oceanSwBias;
  m.add(oceanAffectsSynth ? oceanBridge.liveNorm : 0.0f);
  m.add(oceanBridge.oceanExcite);
  m.add(oceanBridge.oceanColor);
  m.add(oceanBridge.oceanBurst);
  m.add(oceanBridge.oceanPersistence);
  m.add(oceanBridge.oceanDepthBias);
  m.add(oceanBridge.oceanCurvature);
  m.add(oceanBridge.oceanArpDrive);
  m.add(oceanBridge.oceanGlassDrive);
  m.add(oceanBridge.oceanReverbDrive);
  m.add(oceanBridge.rawTide);
  m.add(oceanBridge.rawTempC);
  m.add(constrain(oceanBridge.currentNorm * (0.65 + oceanEngCurrentGain), 0.0, 1.0));
  m.add(oceanBridge.phaseNorm);
  m.add(oceanBridge.thermalNorm);
  m.add(oceanBridge.rawRange);
  m.add(oceanBridge.velocityNorm);
  m.add(constrain(oceanBridge.accelNorm * oceanBreakBias, 0.0, 1.0));
  m.add(oceanBridge.energyNorm);
  m.add(oceanBridge.memoryNorm);
  m.add(oceanVolBias);
  m.add(oceanCurBias);
  m.add(oceanSwBias);
  oscP5.send(m, supercollider);
}

class SolarDataBridge {
  int udpPort;
  java.net.DatagramSocket socket = null;
  Thread thread = null;
  volatile boolean running = false;
  volatile String pending = null;
  volatile boolean hasPending = false;
  int packets = 0;
  int lastPacketMs = -999999;
  String sourceLabel = "waiting UDP :5060";

  float rawXray = 0;
  float rawWind = 0;
  float rawBz = 0;
  float rawKp = 0;
  float xrayNorm = 0;
  float windNorm = 0;
  float bzNorm = 0.5;
  float kpNorm = 0;
  float flareNorm = 0;

  SolarDataBridge(int port) {
    udpPort = port;
  }

  void start() {
    if (running) return;
    try {
      socket = new java.net.DatagramSocket(udpPort);
      socket.setSoTimeout(1000);
      running = true;
      thread = new Thread(new Runnable() {
        public void run() {
          byte[] buf = new byte[4096];
          while (running) {
            try {
              java.net.DatagramPacket packet = new java.net.DatagramPacket(buf, buf.length);
              socket.receive(packet);
              pending = new String(packet.getData(), 0, packet.getLength()).trim();
              hasPending = true;
              packets++;
              lastPacketMs = millis();
            } catch (java.net.SocketTimeoutException ste) {
              // normal
            } catch (Exception e) {
              if (running) println("Solar UDP error: " + e);
            }
          }
        }
      });
      thread.setDaemon(true);
      thread.start();
      sourceLabel = "UDP :" + udpPort;
      println("Solar UDP listener started on port " + udpPort);
    } catch (Exception e) {
      sourceLabel = "SOLAR UDP FAILED";
      println("Could not start solar UDP listener: " + e);
    }
  }

  void consumeLatest() {
    if (!hasPending) return;
    String msg = pending;
    pending = null;
    hasPending = false;
    parse(msg);
  }

  void parse(String msg) {
    if (msg == null) return;
    msg = trim(msg);
    if (msg.startsWith("SOLAR:")) msg = msg.substring(6);
    String[] parts = split(msg, ',');
    for (int i = 0; i < parts.length; i++) {
      String[] kv = split(parts[i], '=');
      if (kv == null || kv.length < 2) continue;
      String k = trim(kv[0]).toLowerCase();
      float v = 0;
      try { v = float(trim(kv[1])); } catch (Exception e) { continue; }
      if (k.equals("xray")) rawXray = max(0, v);
      else if (k.equals("wind")) rawWind = max(0, v);
      else if (k.equals("bz")) rawBz = v;
      else if (k.equals("kp")) rawKp = constrain(v, 0, 9);
      else if (k.equals("flare")) flareNorm = constrain(v, 0, 1);
    }
    // Lightweight, stable normalizations for synthesis/visuals.
    xrayNorm = constrain((log(max(rawXray, 1e-9)) - log(1e-8)) / (log(1e-4) - log(1e-8)), 0, 1);
    windNorm = constrain((rawWind - 250.0) / 650.0, 0, 1);
    bzNorm   = constrain((rawBz + 20.0) / 40.0, 0, 1);
    kpNorm   = constrain(rawKp / 9.0, 0, 1);
    flareNorm = max(flareNorm, xrayNorm);
    sourceLabel = "pkts=" + packets + " x=" + safeNf(xrayNorm,1,2) + " w=" + safeNf(windNorm,1,2);
  }

 boolean isLive() {
    return millis() - lastPacketMs < 600000; // 10 minutes
  }
}

class OceanDataBridge {
  int udpPort;
  java.net.DatagramSocket socket = null;
  Thread thread = null;
  volatile boolean running = false;
  volatile String pending = null;
  volatile boolean hasPending = false;
  int packets = 0;
  int lastPacketMs = -999999;
  String sourceLabel = "waiting UDP :5062";

  float rawTide = 0;
  float rawTempC = 12;
  float rawRange = 0;
  float currentNorm = 0;
  float phaseNorm = 0.5;
  float thermalNorm = 0.35;
  float rangeNorm = 0;
  float velocityNorm = 0;
  float accelNorm = 0;
  float energyNorm = 0;
  float memoryNorm = 0;
  float liveNorm = 0;
  float oceanExcite = 0;
  float oceanColor = 0;
  float oceanBurst = 0;
  float oceanDepthBias = 0;
  float oceanCurvature = 0;
  float oceanPersistence = 0;
  float oceanArpDrive = 0;
  float oceanGlassDrive = 0;
  float oceanReverbDrive = 0;

  OceanDataBridge(int port) {
    udpPort = port;
  }

  void start() {
    if (running) return;
    try {
      socket = new java.net.DatagramSocket(udpPort);
      socket.setSoTimeout(1000);
      running = true;
      thread = new Thread(new Runnable() {
        public void run() {
          byte[] buf = new byte[2048];
          while (running) {
            try {
              java.net.DatagramPacket packet = new java.net.DatagramPacket(buf, buf.length);
              socket.receive(packet);
              pending = new String(packet.getData(), 0, packet.getLength()).trim();
              hasPending = true;
              packets++;
              lastPacketMs = millis();
            } catch (java.net.SocketTimeoutException ste) {
              // normal
            } catch (Exception e) {
              if (running) println("Ocean UDP error: " + e);
            }
          }
        }
      });
      thread.setDaemon(true);
      thread.start();
      sourceLabel = "UDP :" + udpPort;
      println("Ocean UDP listener started on port " + udpPort);
    } catch (Exception e) {
      sourceLabel = "OCEAN UDP FAILED";
      println("Could not start ocean UDP listener: " + e);
    }
  }

  void consumeLatest() {
    if (!hasPending) return;
    String msg = pending;
    pending = null;
    hasPending = false;
    parse(msg);
  }

  void parse(String msg) {
    if (msg == null) return;
    msg = trim(msg);
    if (msg.startsWith("OCEAN:")) msg = msg.substring(6);
    String[] parts = split(msg, ',');
    for (int i = 0; i < parts.length; i++) {
      String[] kv = split(parts[i], '=');
      if (kv == null || kv.length < 2) continue;
      String k = trim(kv[0]).toLowerCase();
      float v = 0;
      try { v = float(trim(kv[1])); } catch (Exception e) { continue; }
      if (k.equals("tide")) rawTide = v;
      else if (k.equals("temp_c")) rawTempC = v;
      else if (k.equals("current")) currentNorm = constrain(v, 0, 1);
      else if (k.equals("phase")) phaseNorm = constrain(v, 0, 1);
      else if (k.equals("thermal")) thermalNorm = constrain(v, 0, 1);
      else if (k.equals("range")) rawRange = max(0, v);
      else if (k.equals("velocity")) velocityNorm = constrain(v, 0, 1);
      else if (k.equals("accel")) accelNorm = constrain(v, 0, 1);
      else if (k.equals("energy")) energyNorm = constrain(v, 0, 1);
      else if (k.equals("memory")) memoryNorm = constrain(v, 0, 1);
      else if (k.equals("live")) liveNorm = constrain(v, 0, 1);
    }
    rangeNorm = constrain(rawRange / 3.0, 0, 1);
    updateFieldInterpreter();
    sourceLabel = "pkts=" + packets + " cur=" + safeNf(currentNorm,1,2) + " e=" + safeNf(energyNorm,1,2);
  }

  void updateFieldInterpreter() {
    float live = liveNorm;
    float currentShape = pow(currentNorm, 1.7);
    float velocityShape = pow(velocityNorm, 1.4);
    float accelShape = pow(accelNorm, 2.2);

    oceanExcite = live * constrain(
      currentShape * 0.40 +
      velocityShape * 0.25 +
      accelShape * 0.20 +
      thermalNorm * 0.15,
      0, 1
    );
    oceanBurst = (live > 0.5 && accelNorm > 0.72 && currentNorm > 0.35) ? 1.0 : 0.0;
    oceanPersistence = lerp(oceanPersistence, memoryNorm, 0.015);
    oceanColor = constrain(map(rawTempC, 0, 32, 0, 1) * 0.70 + thermalNorm * 0.30, 0, 1);
    oceanDepthBias = live * constrain(rangeNorm * 0.35 + energyNorm * 0.65, 0, 1);
    oceanCurvature = live * ((phaseNorm - 0.5) * 2.0) * (0.35 + rangeNorm * 0.20);
    oceanArpDrive = live * constrain(oceanExcite * 0.65 + oceanBurst * 0.35, 0, 1);
    oceanGlassDrive = live * constrain(thermalNorm * 0.45 + accelNorm * 0.35 + velocityNorm * 0.20, 0, 1);
    oceanReverbDrive = live * constrain(oceanPersistence * 0.75 + rangeNorm * 0.25, 0, 1);
  }

  boolean isLive() {
    return millis() - lastPacketMs < 900000; // 15 minutes
  }
}


// ============================================================
// SURFACE / MANIFOLD UDP BRIDGE
// Receives compact UDP text packets from surface_sender.py:
//
//   SURFACE:seq|name|grid|angle|zbytes|depths|curvbytes
//   SURFACE_DONE:seq
//
// This intentionally mirrors the existing solar/ocean bridge architecture:
// Python does the heavy work; Processing receives a small normalized surface.
// ============================================================
void updateSurfaceBridge() {
  if (surfaceBridge == null) return;
  try {
    surfaceBridge.consumeLatest();
  } catch (Exception e) {
    statusMsg = "Surface bridge guarded: " + e;
  }
}

void drawSurfaceOverlayInOrbit(int x, int y, int w, int h) {
  if (surfaceBridge == null || !surfaceBridge.ready) return;

  pushStyle();

  int g = surfaceBridge.grid;
  float cellW = w / float(max(1, g));
  float cellH = h / float(max(1, g));

  noStroke();

  for (int gy = 0; gy < g; gy++) {
    for (int gx = 0; gx < g; gx++) {
      int i = gy * g + gx;
      if (i < 0 || i >= surfaceBridge.z.length) continue;

      float z = constrain(surfaceBridge.z[i], 0, 1);
      float c = constrain(surfaceBridge.curv[i], 0, 1);
      int d = constrain(surfaceBridge.depth[i], 1, 7);

      // Keep the existing RDFT palette language: inferno/plasma-like hot topology.
      color base = sampleCmap(cmap_inferno, constrain(z * 0.85 + d / 14.0, 0, 1));
      float a = 32 + z * 62 + c * 52;

      fill(red(base), green(base), blue(base), constrain(a, 18, 128));
      rect(x + gx * cellW, y + gy * cellH, cellW + 0.7, cellH + 0.7);
    }
  }

  // Lightweight wireframe contour pass.
  stroke(120, 230, 255, 28);
  strokeWeight(0.65);
  for (int gy = 0; gy < g; gy += 4) {
    float yy = y + gy * cellH;
    line(x, yy, x + w, yy);
  }
  for (int gx = 0; gx < g; gx += 4) {
    float xx = x + gx * cellW;
    line(xx, y, xx, y + h);
  }

  // Sender status label, kept small so it does not overpower orbit readouts.
  fill(180, 230, 235, 170);
  textSize(7);
  textAlign(LEFT, TOP);
  text("SURFACE " + surfaceBridge.name + " g" + g + " seq " + surfaceBridge.seq, x + 5, y + 5);

  popStyle();
}

float sampleSurfaceZAtScreen(float sx, float sy, int panelX, int panelY, int panelW, int panelH) {
  if (surfaceBridge == null || !surfaceBridge.ready) return 0;

  int g = surfaceBridge.grid;
  float u = constrain((sx - panelX) / float(max(1, panelW)), 0, 0.999);
  float v = constrain((sy - panelY) / float(max(1, panelH)), 0, 0.999);

  int gx = constrain(int(u * g), 0, g - 1);
  int gy = constrain(int(v * g), 0, g - 1);
  int i = gy * g + gx;

  if (i < 0 || i >= surfaceBridge.z.length) return 0;
  return constrain(surfaceBridge.z[i], 0, 1);
}

float sampleSurfaceCurvAtScreen(float sx, float sy, int panelX, int panelY, int panelW, int panelH) {
  if (surfaceBridge == null || !surfaceBridge.ready) return 0;

  int g = surfaceBridge.grid;
  float u = constrain((sx - panelX) / float(max(1, panelW)), 0, 0.999);
  float v = constrain((sy - panelY) / float(max(1, panelH)), 0, 0.999);

  int gx = constrain(int(u * g), 0, g - 1);
  int gy = constrain(int(v * g), 0, g - 1);
  int i = gy * g + gx;

  if (i < 0 || i >= surfaceBridge.curv.length) return 0;
  return constrain(surfaceBridge.curv[i], 0, 1);
}

int sampleSurfaceDepthAtScreen(float sx, float sy, int panelX, int panelY, int panelW, int panelH) {
  if (surfaceBridge == null || !surfaceBridge.ready) return 1;

  int g = surfaceBridge.grid;
  float u = constrain((sx - panelX) / float(max(1, panelW)), 0, 0.999);
  float v = constrain((sy - panelY) / float(max(1, panelH)), 0, 0.999);

  int gx = constrain(int(u * g), 0, g - 1);
  int gy = constrain(int(v * g), 0, g - 1);
  int i = gy * g + gx;

  if (i < 0 || i >= surfaceBridge.depth.length) return 1;
  return constrain(surfaceBridge.depth[i], 1, 7);
}

void drawSurfaceContactMarker(float sx, float sy, int panelX, int panelY, int panelW, int panelH) {
  if (surfaceBridge == null || !surfaceBridge.ready) return;

  float z = sampleSurfaceZAtScreen(sx, sy, panelX, panelY, panelW, panelH);
  float c = sampleSurfaceCurvAtScreen(sx, sy, panelX, panelY, panelW, panelH);
  int d = sampleSurfaceDepthAtScreen(sx, sy, panelX, panelY, panelW, panelH);

  pushStyle();

  // Outer ring size encodes surface elevation + curvature (unchanged)
  float ring = 10 + z * 22 + c * 18;
  noFill();

  // Outer ring: amber→cyan by Landauer coherence.
  // Amber = high curvature, erased coherence. Cyan = flat, coherent.
  color coherentCol = color(100, 235, 255);
  color erasedCol   = color(255, 160, 60);
  color ringCol     = lerpColor(erasedCol, coherentCol, landauerCoherence);
  stroke(red(ringCol), green(ringCol), blue(ringCol), 175);
  strokeWeight(1.4);
  ellipse(sx, sy, ring, ring);

  // Inner ring: Landauer source intensity (landauerS) as brightness
  float innerBright = constrain(100 + landauerS * 800, 80, 255);
  stroke(innerBright, innerBright * 0.9, innerBright * 0.4, 130);
  strokeWeight(0.9);
  ellipse(sx, sy, ring * 0.55, ring * 0.55);

  // Curvature vector tick (unchanged behaviour, colour follows ring)
  stroke(red(ringCol), green(ringCol), blue(ringCol), 140);
  float a = frameCount * 0.025 + surfaceBridge.angle;
  line(sx, sy, sx + cos(a) * (8 + c * 18), sy + sin(a) * (8 + c * 18));

  // Label: now shows Landauer state alongside geometry readout
  fill(230, 235, 200, 170);
  textSize(7);
  textAlign(LEFT, TOP);
  text("D" + d + " z=" + safeNf(z,1,2)
       + " Ls=" + safeNf(landauerS,1,3)
       + " coh=" + safeNf(landauerCoherence,1,2),
       sx + 8, sy + 8);

  popStyle();
}

// ============================================================
// HOLOGRAPHIC SURFACE PHYSICS UPDATE
// ============================================================
// Reads the surface boundary geometry at the orbital's current
// screen position and translates it into causal physics inputs.
//
// LANDAUER COUPLING (information thermodynamics):
//   Surface curvature sets the local information density floor.
//   High curvature compresses more field structure onto a smaller
//   boundary region — equivalent to higher temperature/energy density
//   under Landauer's principle (kT·ln2 per bit erased at boundary).
//   This adds to phiEngine's source term S, stiffening the field
//   locally and making the orbital feel the manifold's geometry.
//
// QUANTUM ERASER COUPLING (coherence boundary):
//   High curvature forces path distinguishability — the orbital's
//   "which path" information becomes available at saddle points,
//   suppressing interference (coherence). This directly modulates
//   foundationalCoherence, so BELTRAMI_SHEARED emerges naturally
//   at high-curvature surface features.
//
// DEPTH LAYER COUPLING (recursive scale):
//   The surface depth channel encodes which recursion scale is
//   dominant at the orbital position. This biases the phi field's
//   adaptive step mu, making deeper-layer regions feel recursively
//   stiffer — the orbital experiences more resistance when crossing
//   into finer-grained surface structure.
// ============================================================
void updateSurfacePhysics() {
  surfaceReady = (surfaceBridge != null && surfaceBridge.ready);
  if (!surfaceReady || orbPanelW == 0) {
    landauerS        = 0.0;
    landauerCoherence = 1.0;
    return;
  }

  // Map orbital position (orbital coords) to screen coords in the orbital panel.
  // The panel draws the orbit scaled around (cx, cy) = panel centre.
  float cx   = orbPanelX + orbPanelW * 0.5;
  float cy   = orbPanelY + orbPanelH * 0.5;
  float scale = (orbPanelW * 0.42) / ORB_BOUND;
  float sx   = cx + orb_x * scale;
  float sy   = cy - orb_y * scale;   // y-inverted as in drawOrbitalPanel

  // Sample surface boundary at orbital screen position
  surfaceZ       = sampleSurfaceZAtScreen(sx, sy, orbPanelX, orbPanelY, orbPanelW, orbPanelH);
  surfaceCurv    = sampleSurfaceCurvAtScreen(sx, sy, orbPanelX, orbPanelY, orbPanelW, orbPanelH);
  surfaceDepthAt = sampleSurfaceDepthAtScreen(sx, sy, orbPanelX, orbPanelY, orbPanelW, orbPanelH);

  // ── Landauer coupling ─────────────────────────────────────────────────────
  // Information density ∝ curvature (more structure compressed per boundary area).
  // The Landauer contribution to S is scaled so it stays sub-dominant at rest
  // (max +0.18 to S_typical of 0.3–0.6) but becomes significant at high curvature.
  // surfaceZ modulates magnitude: raised terrain has more field "pressing" on boundary.
  float rawLandauer  = surfaceCurv * (0.6 + surfaceZ * 0.6);
  landauerS          = constrain(rawLandauer * 0.18, 0, 0.18);

  // ── Quantum eraser coherence suppression ─────────────────────────────────
  // At flat regions (curv≈0): landauerCoherence≈1, paths indistinguishable,
  // interference maintained. At saddle/ridge points (curv≈1): coherence→0,
  // paths become distinguishable, Berry phase accumulation accelerates.
  // Smooth exponential so the transition isn't abrupt.
  landauerCoherence  = constrain(exp(-surfaceCurv * 2.8), 0.05, 1.0);

  // ── Depth layer stiffness ─────────────────────────────────────────────────
  // Surface depth biases phiEngine's adaptive step. Deeper layers = finer
  // recursion = stiffer field response. We write directly to phiEngine.mu
  // with a slow filter so it doesn't jump abruptly.
  float targetMu = 0.1 * (1.0 - (surfaceDepthAt - 1) / 6.0 * 0.55);
  phiEngine.mu = lerp(phiEngine.mu, targetMu, 0.04);
}

class SurfaceDataBridge {
  int udpPort;
  java.net.DatagramSocket socket = null;
  Thread thread = null;
  volatile boolean running = false;
  volatile String pending = null;
  volatile boolean hasPending = false;

  int packets = 0;
  int lastPacketMs = -999999;

  int seq = 0;
  int grid = 32;
  String name = "none";
  float angle = 0.0;
  boolean ready = false;

  float[] z = new float[32 * 32];
  int[] depth = new int[32 * 32];
  float[] curv = new float[32 * 32];

  SurfaceDataBridge(int port) {
    udpPort = port;
  }

  void start() {
    if (running) return;
    try {
      socket = new java.net.DatagramSocket(udpPort);
      socket.setSoTimeout(1000);
      running = true;

      thread = new Thread(new Runnable() {
        public void run() {
          byte[] buf = new byte[65535];
          while (running) {
            try {
              java.net.DatagramPacket packet = new java.net.DatagramPacket(buf, buf.length);
              socket.receive(packet);
              String msg = new String(packet.getData(), 0, packet.getLength()).trim();
              if (msg.startsWith("SURFACE:")) {
                pending = msg;
                hasPending = true;
                packets++;
                lastPacketMs = millis();
              }
            } catch (java.net.SocketTimeoutException ste) {
              // normal
            } catch (Exception e) {
              if (running) println("Surface UDP error: " + e);
            }
          }
        }
      });

      thread.setDaemon(true);
      thread.start();
      println("Surface UDP listener started on port " + udpPort);
    } catch (Exception e) {
      println("Could not start surface UDP listener: " + e);
    }
  }

  void consumeLatest() {
    if (!hasPending) return;
    String msg = pending;
    pending = null;
    hasPending = false;
    parse(msg);
  }

  void parse(String msg) {
    if (msg == null || !msg.startsWith("SURFACE:")) return;

    try {
      String body = msg.substring(8);
      String[] parts = split(body, '|');
      if (parts == null || parts.length < 7) return;

      int nextSeq = int(trim(parts[0]));
      String nextName = trim(parts[1]);
      int nextGrid = constrain(int(trim(parts[2])), 8, 128);
      float nextAngle = float(trim(parts[3]));
      int n = nextGrid * nextGrid;

      String[] zVals = split(parts[4], ',');
      String[] dVals = split(parts[5], ',');
      String[] cVals = split(parts[6], ',');

      if (zVals == null || dVals == null || cVals == null) return;
      if (zVals.length < n || dVals.length < n || cVals.length < n) return;

      if (z.length != n) {
        z = new float[n];
        depth = new int[n];
        curv = new float[n];
      }

      for (int i = 0; i < n; i++) {
        z[i] = constrain(int(trim(zVals[i])) / 255.0, 0, 1);
        depth[i] = constrain(int(trim(dVals[i])), 1, 7);
        curv[i] = constrain(int(trim(cVals[i])) / 255.0, 0, 1);
      }

      seq = nextSeq;
      name = nextName;
      grid = nextGrid;
      angle = nextAngle;
      ready = true;
    } catch (Exception e) {
      println("Surface parse error: " + e);
    }
  }

  boolean isLive() {
    return millis() - lastPacketMs < 10000;
  }
}

// ========== BUTTON HANDLERS ==========
void COMPUTE(int val) {
  depth = (int)sliderDepth.getValue();
  alpha = sliderAlpha.getValue();
  orb_gamma = sliderGamma.getValue();
  if (fieldDepth != null) fieldDepth.setText(str(depth));
  if (fieldAlpha != null) fieldAlpha.setText(safeNf(alpha,1,2));
  if (fieldGamma != null) fieldGamma.setText(safeNf(orb_gamma,1,2));
  layerCache = null;
  computeFrames();
  phiEngine.rebuildRadialTable(getAverageValue(combined != null ? combined : new float[GRID][GRID]));
  thread("buildSweepCache");
  statusMsg = connected ? "Ready" : "Not connected";
}

void ANIMATE(int val) {
  animating = !animating;
  if (animating) {
    sweepIdx = 0;
    sweepDir = 1;
    animFrameCounter = 0;
    btnAnimate.setLabel("STOP");
  } else {
    btnAnimate.setLabel("ANIMATE");
  }
}

void RESETORBIT(int val) {
  orb_x = 1.2;
  orb_y = 0.0;
  orb_vx = 0.0;
  orb_vy = 0.85;
  trailHead = 0;
  trailCount = 0;

  // Reset shadow onto epsilon-offset from new primary position.
  // FTLE accumulator also resets — we're starting a fresh measurement.
  shad_x  = orb_x + FTLE_EPS;
  shad_y  = orb_y;
  shad_vx = orb_vx;
  shad_vy = orb_vy;
  ftleAccum = 0.0;
  ftleSteps = 0;
}

void CONNECT(int val) {
  // Serial hardware is disabled in this Raspberry Pi MLX90640 UDP build.
  ledConnected = false;
  connected = false;
  statusMsg = "UDP/OSC-only build — Serial disabled; ocean/solar listeners active";
  btnConnect.setLabel("UDP ONLY");
}
void PUSH(int val) {
  // In this build PUSH updates the GUI's 8x8 matrix mirror only.
  // No Arduino/MAX7219 serial write is attempted.
  float[][] frame8;
  int safeMode = safeModeIndex(currentMode, 4);
  switch (safeMode) {
    case 0: frame8 = floydSteinberg(downsample8x8(dominant)); break;
    case 1: frame8 = floydSteinberg(downsample8x8(combined)); break;
    case 2: frame8 = floydSteinberg(downsample8x8(crossTo2D())); break;
    case 3: frame8 = makeOrbitalMatrixFrame(); break;
    default: frame8 = floydSteinberg(downsample8x8(combined)); break;
  }
  lastMatrixFrame = frame8;
  statusMsg = "Updated local 8x8 mirror MODE " + safeMode + " — Serial disabled";
}

// ========== UTILITY FUNCTIONS ==========
void keyPressed() {
  if (!CHLADNI_SPHERE_UI) handlePetaminxExperimentalKey();
  if (key == 't') {
    OscMessage test = new OscMessage("/test");
    test.add(1.0);
    test.add(2.0);
    oscP5.send(test, supercollider);
    println("Test OSC sent");
  }
}


void CLOSEVIEWS(int val) {
  closeFloatingViewersExcept("none");
  statusMsg = "Single-window mode active; there are no floating panels to close.";
}

void closeFloatingViewersExcept(String keep) {
  // No programmatic window shutdown on Raspberry Pi/JOGL.
  // Calling PApplet.exit() on secondary P2D windows can trigger ThreadDeath and
  // kill the whole sketch. Auxiliary windows are now fully avoided in this build.
}

void NODES(int val) {
  statusMsg = "Nodes are embedded in the main GUI; no secondary window is launched.";
}

void SPAWNDRONE(int val) {
  // Explicit manual drone spawn. The drone no longer appears just because /rdf/mix is flowing.
  float f = getSliderValueSafe("rootFreq", 55);
  float v = getSliderValueSafe("droneVolume", 0.20);

  if (toggleDrone != null) toggleDrone.setState(true);

  OscMessage msg = new OscMessage("/rdf/droneSpawn");
  msg.add(constrain(f, 32, 440));
  msg.add(constrain(v, 0, 1));
  oscP5.send(msg, supercollider);

  statusMsg = "DRONE SPAWN sent: freq=" + safeNf(f,1,2) + " vol=" + safeNf(v,1,3);
  println(statusMsg);
}

void KILLDRONE(int val) {
  // Explicit hard kill/release for the drone.
  if (toggleDrone != null) toggleDrone.setState(false);

  OscMessage msg = new OscMessage("/rdf/droneKill");
  msg.add(1.0f);
  oscP5.send(msg, supercollider);

  statusMsg = "DRONE KILL sent";
  println(statusMsg);
}


void openNodesWindow() {
  statusMsg = "Nodes are embedded in the main GUI; no secondary window is launched.";
}


void MATERIALS(int val) {
  statusMsg = "Material topology is embedded in the main GUI; no secondary window is launched.";
}

void openMaterialTopologyWindow() {
  statusMsg = "Material topology is embedded in the main GUI; no secondary window is launched.";
}



void sendFrame(int mode, float[][] frame8) {
  // Local mirror/cache only. Serial output has been removed from this build.
  lastMatrixFrame = frame8;
}


float[][] downsample8x8(float[][] src) {
  float[][] out = new float[8][8];
  int block = GRID / 8;
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      float sum = 0;
      for (int dr = 0; dr < block; dr++) {
        for (int dc = 0; dc < block; dc++) {
          sum += src[r * block + dr][c * block + dc];
        }
      }
      out[r][c] = sum / (block * block);
    }
  }
  float mn = 1e9, mx = -1e9;
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      if (out[r][c] < mn) mn = out[r][c];
      if (out[r][c] > mx) mx = out[r][c];
    }
  }
  if (mx > mn) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        out[r][c] = (out[r][c] - mn) / (mx - mn);
      }
    }
  }
  return out;
}

float[][] floydSteinberg(float[][] img) {
  float[][] buf = new float[8][8];
  float[][] out = new float[8][8];
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      buf[r][c] = img[r][c];
    }
  }
  for (int r = 0; r < 8; r++) {
    for (int c = 0; c < 8; c++) {
      float old = buf[r][c];
      float nw = old >= 0.5 ? 255 : 0;
      out[r][c] = nw;
      float err = old - nw / 255.0;
      if (c + 1 < 8) buf[r][c + 1] += err * 7.0 / 16;
      if (r + 1 < 8) {
        if (c - 1 >= 0) buf[r + 1][c - 1] += err * 3.0 / 16;
        buf[r + 1][c] += err * 5.0 / 16;
        if (c + 1 < 8) buf[r + 1][c + 1] += err * 1.0 / 16;
      }
    }
  }
  return out;
}

float[][] crossTo2D() {
  float[][] out = new float[GRID][GRID];
  if (cross1D == null) return out;
  for (int c = 0; c < GRID; c++) {
    int bH = (int)(cross1D[c] * GRID);
    for (int r = GRID - bH; r < GRID; r++) {
      out[r][c] = cross1D[c];
    }
  }
  return out;
}

float[][] makeOrbitalMatrixFrame() {
  float[][] frame = new float[8][8];
  float t = frameCount * 0.12;
  float cx = 3.5;
  float cy = 3.5;
  for (int i = 0; i < 3; i++) {
    float radius = 1.2 + i * 1.0;
    float angle = t + i * TWO_PI / 3.0;
    int x = round(cx + cos(angle) * radius);
    int y = round(cy + sin(angle) * radius);
    if (x >= 0 && x < 8 && y >= 0 && y < 8) {
      frame[y][x] = 255;
    }
  }
  frame[3][3] = 255;
  frame[3][4] = 255;
  frame[4][3] = 255;
  frame[4][4] = 255;
  return frame;  // ADDED THIS MISSING RETURN STATEMENT
}

// ========== PHI FIELD ENGINE UPDATE ==========
// Called every frame from draw() after updateCurrentMetricsOnly().
void updatePhiEngine() {
  boolean useSweep = (animating && sweepReady && !sweepBuilding
                      && sweepCache != null && sweepAlphas != null
                      && sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float[][] field = safeField(useSweep ? sweepCache[sweepIdx] : combined);
  float avgBright = getAverageValue(field);

  // Variance proxy for pressure term 3p (§3)
  float variance = 0;
  if (field != null) {
    float vsum = 0; int vn = 0;
    for (int row = 0; row < field.length; row += 4) {
      for (int col = 0; col < field[row].length; col += 4) {
        vsum += sq(field[row][col] - avgBright);
        vn++;
      }
    }
    variance = (vn > 0) ? sqrt(vsum / vn) : 0;
  }

  float r = sqrt(orb_x * orb_x + orb_y * orb_y);

  // ── Holographic surface → phi field source injection ──────────────────────
  // landauerS is the information-density contribution from the TPMS boundary
  // geometry at the orbital's current position. Adding it to avgBright before
  // it becomes phiEngine's source S makes the surface curvature causally stiffen
  // the field — high-curvature regions of the manifold produce a denser field
  // source, which raises G_local's denominator and softens local gravity,
  // steering the orbital away from curvature peaks. This is the Landauer
  // normalization: information compressed onto a curved boundary costs energy,
  // and that cost manifests as a local field stiffness the orbital must navigate.
  float avgBrightWithSurface = constrain(avgBright + landauerS, 0, 1.5);

  phiEngine.update(avgBrightWithSurface, variance, r, field);

  // Rebuild radial table periodically if S has drifted (§5)
  if (frameCount % 90 == 0) {
    if (abs(phiEngine.S - phiEngine.S0_bg) > 0.05 || !phiEngine.radialTableReady) {
      phiEngine.rebuildRadialTable(phiEngine.S);
    }
  }

  // Mirror to named globals (§12)
  phi_field_value    = phiEngine.phi;
  phi_residual       = phiEngine.F;
  phi_gain           = phiEngine.G_local;
  phi_threshold_prox = phiEngine.thresholdProximity;

  // §12: threshold proximity feeds into Planck gate when near boundary
  if (phiEngine.thresholdProximity > 0.85) {
    foundationalPlanckGate = constrain(
      foundationalPlanckGate + phiEngine.thresholdProximity * 0.04, 0, 1);
  }
}

// ========== OSC FUNCTIONS ==========
void sendRDFToSuperCollider() {
  if (oscP5 == null || supercollider == null) return;

  boolean useSweepFrame = (animating && sweepReady && !sweepBuilding &&
    sweepCache != null && sweepAlphas != null &&
    sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float sA        = useSweepFrame ? safeAlphaValue(sweepAlphas[sweepIdx]) : safeAlphaValue(alpha);
  float[][] field = safeField(useSweepFrame ? sweepCache[sweepIdx] : combined);

  float r_o       = sqrt(orb_x * orb_x + orb_y * orb_y);
  float orbSpeed  = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);
  float phi       = orbResolutionField(r_o);
  float avgBright = getAverageValue(field);
  float maxBright = getMaxValue(field);
  float finest    = getFinestScaleValue(field);
  float dominantVal = getDominantLayerValue();
  float effectiveD = computeFractalDimensionRobust(combined);
  float spectralRolloff = 2.0 - effectiveD;  // D<<2 → high frequencies dominate

  // ── /rdf/field — RDF field state ─────────────────────────────
  // [0] alpha      [1] depth      [2] finest     [3] dominantVal
  // [4] avgBright  [5] maxBright  [6] phi        [7] ftle
  OscMessage fMsg = new OscMessage("/rdf/field");
  fMsg.add(sA);
  fMsg.add((float)depth);
  fMsg.add(finest);
  fMsg.add(dominantVal);
  fMsg.add(avgBright);
  fMsg.add(maxBright);
  fMsg.add(phi);
  fMsg.add(metricLyapunov);   // true FTLE — new in this slot
  // §12 phi-field scalars: residual F, G_local, threshold proximity
  fMsg.add(phi_residual);         // [9]  F — field equation mismatch
  fMsg.add(phi_gain);             // [10] G_local — stability margin (§8)
  fMsg.add(phi_threshold_prox);   // [11] threshold proximity [0,2] (§12)
  oscP5.send(fMsg, supercollider);

  // ── /rdf/orbit — orbital dynamics ────────────────────────────
  // [0] orbSpeed   [1] r_o   [2] orbSensitivity
  // [3] shad_x     [4] shad_y   (shadow position for phase portrait)
  OscMessage oMsg = new OscMessage("/rdf/orbit");
  oMsg.add(orbSpeed);
  oMsg.add(r_o);
  oMsg.add(sliderOrbSensitivity.getValue());
  oMsg.add(shad_x);
  oMsg.add(shad_y);
  oscP5.send(oMsg, supercollider);

  // ── /rdf/surface — holographic boundary physics ───────────────
  // Sends Landauer and quantum eraser state to SC for synthesis use.
  // SC can use landauerS to modulate reverb/density (denser boundary
  // = more spatial compression) and landauerCoherence to gate
  // interference-based effects (chorus, phasing, spectral smearing).
  // [0] surfaceZ        — boundary elevation at orbital position
  // [1] surfaceCurv     — Gaussian curvature at orbital position
  // [2] surfaceDepthAt  — recursion depth layer at orbital position
  // [3] landauerS       — information density contribution to S
  // [4] landauerCoherence — quantum eraser coherence [0=erased, 1=coherent]
  // [5] surfaceReady    — 1 if live surface data is being received
  OscMessage sMsg = new OscMessage("/rdf/surface");
  sMsg.add(surfaceZ);
  sMsg.add(surfaceCurv);
  sMsg.add((float)surfaceDepthAt);
  sMsg.add(landauerS);
  sMsg.add(landauerCoherence);
  sMsg.add(surfaceReady ? 1.0 : 0.0);
  oscP5.send(sMsg, supercollider);

  // ── /rdf/mix — all audio controls ────────────────────────────
  // [0]  modSource      [1]  scaleIndex    [2]  rootFreq
  // [3]  masterAmp      [4]  reverbMix
  // [5]  droneOn        [6]  arpOn         [7]  glassOn
  // [8]  droneVolume    [9]  arpVolume     [10] glassVolume
  // [11] choirVolume    [12] ghostOn      [13] arpRate
  // [14] effectiveD     [15] spectralRolloff
  // [16-19] eco toggles: chirp/call/growth/fissure
  // [20-23] eco levels:  chirp/call/growth/fissure
  
  

  OscMessage mMsg = new OscMessage("/rdf/mix");
  mMsg.add((float)menuModSource.getValue());
  mMsg.add((float)menuScale.getValue());
  mMsg.add(sliderRootFreq.getValue());
  mMsg.add(sliderAmp.getValue());
  mMsg.add(sliderReverb.getValue());
  mMsg.add(toggleDrone.getState() ? 1.0f : 0.0f);
  mMsg.add(toggleArp.getState() ? 1.0f : 0.0f);
  mMsg.add(toggleGlass.getState() ? 1.0f : 0.0f);
mMsg.add(getSliderValueSafe("droneVolume", 0.20));
  mMsg.add(getSliderValueSafe("arpVolume", 0.20));
  mMsg.add(getSliderValueSafe("glassVolume", 0.2));
  Controller choirToggleCtrl = cp5.getController("choirOn");
  boolean choirOnState = (choirToggleCtrl != null) && choirToggleCtrl.getValue() > 0.5;
  mMsg.add(choirOnState ? getSliderValueSafe("choirVolume", 0.20) : 0.0f);
  mMsg.add((toggleGhost == null || toggleGhost.getState()) ? 1.0f : 0.0f);
  mMsg.add(getSliderValueSafe("arpRate", 1.0));
  // Map to synthesis parameters:
// - D→1.0 (rough, line-like): granular, noisy textures
// - D→2.0 (smooth, surface-like): sinusoidal, resonant
// - D→2.5+ (space-filling, turbulent): dense cluster, inharmonic
mMsg.add(effectiveD);
mMsg.add(spectralRolloff);
mMsg.add((toggleEcoChirp == null || toggleEcoChirp.getState()) ? 1.0f : 0.0f);
mMsg.add((toggleEcoCall == null || toggleEcoCall.getState()) ? 1.0f : 0.0f);
mMsg.add((toggleEcoGrowth == null || toggleEcoGrowth.getState()) ? 1.0f : 0.0f);
mMsg.add((toggleEcoFissure == null || toggleEcoFissure.getState()) ? 1.0f : 0.0f);
mMsg.add(getSliderValueSafe("ecoChirpLevel", 0.58));
mMsg.add(getSliderValueSafe("ecoCallLevel", 0.58));
mMsg.add(getSliderValueSafe("ecoGrowthLevel", 0.64));
mMsg.add(getSliderValueSafe("ecoFissureLevel", 0.64));

oscP5.send(mMsg, supercollider);

  OscMessage egMsg = new OscMessage("/rdf/egProbe");
  egMsg.add((toggleEGProbe == null || toggleEGProbe.getState()) ? 1.0f : 0.0f);
  egMsg.add(egProbeActive ? 1.0f : 0.0f);
  egMsg.add(egProbeDepth);
  egMsg.add(egProbeGateScore);
  egMsg.add(egProbeTarget);
  egMsg.add(effectiveVoltage);
  egMsg.add(electroGravityFactor);
  egMsg.add(sliderRootFreq.getValue());
  oscP5.send(egMsg, supercollider);

  if (frameCount % 120 == 0) {
    println("OSC/rdf: alpha=" + safeNf(sA,1,2) +
      " avgBright=" + safeNf(avgBright,1,3) +
      " ftle=" + safeNf(metricLyapunov,1,4) +
      "");
  }
}


// ========== DATA LOGGING + QUANTITATIVE MODES ==========
void setupExperimentLogging() {
  String stamp = safeNf(year(), 4) + "-" + safeNf(month(), 2) + "-" + safeNf(day(), 2) + "_" +
                 safeNf(hour(), 2) + "-" + safeNf(minute(), 2) + "-" + safeNf(second(), 2);
  oscLogFilename = "osc_state_" + stamp + ".csv";
  oscLogWriter = createWriter(oscLogFilename);
  oscLogWriter.println(
    "timestamp,frameCount," +
    "alpha,depth,finest,dominant_avg,avg_brightness,max_brightness," +
    "orbital_phi,orbital_speed,orbital_radius," +
    "mod_source,scale_index,root_freq,midi_pilot_connected,midi_root_note,midi_held_count,midi_velocity,midi_poly_mode,midi_poly_memory_charge,midi_poly_harmonic_density,midi_poly_chord_spread,midi_poly_release_pressure,midi_poly_trigger_count,midi_poly_release_count,master_amp,reverb," +
    "drone_toggle,arp_toggle,glass_toggle," +
    "drone_vol,arp_vol,glass_vol,choir_vol," +
    "entropy,fractal_dim,lyapunov," +
    "kl_divergence,kl_forward,kl_reverse,mutual_info," +
    "adiabatic_param,berry_phase,berry_phase_principal,berry_winding_turns,berry_curvature_density,orient_run_id,orient_loop_seq,orient_area,correlation_tau," +
    "standard_fit_chi2,rd_fit_chi2,breakdown_count," +
    "floquet_phase,floquet_quasienergy,floquet_coupling,floquet_cycle,floquet_g_eff,floquet_env_frozen,floquet_kappa_held,floquet_eps_held," +
    "floquet_state,floquet_lock_age,floquet_injection_age,floquet_release_age,floquet_coupling_env,floquet_cooldown,floquet_lock_raw,floquet_lock_gated,floquet_release_cmd,floquet_integrated_age,floquet_field_imprint," +
    "solar_enabled,solar_xray_norm,solar_wind_norm,solar_bz_norm,solar_kp_norm,solar_volume," +
    "ocean_live,ocean_tide_m,ocean_temp_c,ocean_current_norm,ocean_phase,ocean_thermal_norm,ocean_range_m,ocean_velocity,ocean_accel,ocean_energy,ocean_memory,ocean_excite,ocean_color,ocean_burst,ocean_persistence,ocean_depth_bias,ocean_curvature,ocean_arp_drive,ocean_glass_drive,ocean_reverb_drive," +
    "cart_x,cart_y,cart_z,cart_stability,cart_velocity,cart_basin," +
    "orbit_event,orbit_lock,orbit_lobes,orbit_eccentricity,orbit_periapsis,orbit_resonance," +
    "found_divE,found_rot_activity,found_psi_density,found_uncertainty," +
    "found_planck_gate,found_coherence,found_coupling," +
    "maxwell_divE_true,maxwell_laplacian_phi," +
    "beltrami_Bx,beltrami_By,beltrami_Bz,beltrami_Bmag," +
    "beltrami_curl_x,beltrami_curl_y,beltrami_curl_z,beltrami_curl_mag," +
    "beltrami_lambda,beltrami_alignment,beltrami_helicity," +
    "symbolic_beltrami_state,symbolic_maxwell_state,symbolic_holonomy_event," +
    "emergent_eg,effective_voltage,eg_factor,ufo_transition,eg_probe_enabled,eg_probe_active,eg_probe_gate_score,eg_probe_depth,eg_probe_target,eg_probe_base_factor,eg_probe_cooldown,eg_probe_trigger_count," +
    "phi_residual,phi_gain,phi_threshold_prox,phi1_energy," +
    "surface_z,surface_curv,surface_depth,landauer_s,landauer_coherence,surface_ready," +
    "sc_voice_count,sc_drone_alive,sc_saturation,sc_glass_age,sc_hold_strength,sc_lifecycle_state,sc_feedback_age," +
    "galaxy_name,galaxy_loaded,galaxy_blend,galaxy_field_curvature,galaxy_floquet_coupling,galaxy_boundary_persistence," +
    "eco_chirp_toggle,eco_call_toggle,eco_growth_toggle,eco_fissure_toggle,eco_chirp_level,eco_call_level,eco_growth_level,eco_fissure_level," +
	    "eco_chirp_trigger_count,eco_chirp_last_age,eco_call_trigger_count,eco_call_last_age,eco_growth_trigger_count,eco_growth_last_age,eco_fissure_trigger_count,eco_fissure_last_age," +
		    "sweep_type,sweep_id,sweep_name,sweep_leg,waypoint,sweep_progress,target_alpha,target_depth,actual_alpha,actual_depth,timestamp_delta,frame_delta,estimated_fps,loop_closed,return_error,auto_mode,hold_active,sweep_area,return_fidelity," +
    "ghost_toggle,psiGhostProb,ghost_trigger_count,lastGhostAge,nextGlassAllowedTime,actualGlassTriggerCount,floquet_g_eff_live," +
    "root_freq_target,root_freq_previous,root_freq_delta,root_freq_accel,root_freq_slew_rate,root_freq_smoothed,root_freq_raw,root_freq_jump_event," +
    "harmonic_pressure,harmonic_pressure_smoothed,harmonic_pressure_delta,harmonic_pressure_peak,harmonic_pressure_event," +
    "freq_field_coupling,freq_entropy_drive,freq_stability_drive,freq_floquet_drive,freq_orbit_drive," +
    "keyboard_event,keyboard_event_type,root_freq_excursion,root_freq_excursion_peak,root_freq_excursion_duration,root_freq_return_error," +
    "harmonic_escape_event,harmonic_capture_event,sweep_leg_keyboard_active,sweep_leg_max_root_freq,sweep_leg_mean_harmonic_pressure,sweep_leg_freq_excursion_count," +
    "hopf_fiber_phase,hopf_fiber_winding,hopf_fiber_delta,hopf_base_x,hopf_base_y,hopf_base_z,hopf_thread_phase,hopf_thread_winding,hopf_link_proxy,hopf_activity_proxy"
  );
	  oscLogWriter.flush();
	  logLineCounter = 0;
	  polyFieldDiagInitialized = false;
	  harmonicPressurePeak = 0;
	  rootFreqExcursionPeak = 0;
	  rootFreqExcursionStartMs = -1;
	  rootFreqExcursionDuration = 0;
	  rootFreqReturnError = 0;
	  sweepLegDiag = -999;
	  sweepLegKeyboardActive = false;
	  sweepLegMaxRootFreq = 0;
	  sweepLegHarmonicPressureSum = 0;
	  sweepLegHarmonicPressureSamples = 0;
	  sweepLegFreqExcursionCount = 0;
	  oscLoggingEnabled = true;
  statusMsg = "Recording RDFT data: " + oscLogFilename;
  println("OSC/RDF state logging to: " + oscLogFilename);
}

void stopExperimentLogging() {
  if (oscLogWriter != null) {
    oscLogWriter.flush();
    oscLogWriter.close();
    oscLogWriter = null;
  }
  oscLoggingEnabled = false;
  statusMsg = "Recording stopped: " + oscLogFilename;
  println(statusMsg);
}

void RECORDDATA(int value) {
  if (oscLoggingEnabled) {
    stopExperimentLogging();
    if (btnRecordData != null) btnRecordData.setLabel("REC DATA: OFF");
  } else {
    setupExperimentLogging();
    if (btnRecordData != null) btnRecordData.setLabel("REC DATA: ON");
  }
}

void oscEvent(OscMessage msg) {
  try {
    if (msg == null) return;
    if (msg.checkAddrPattern("/sc/state")) {
      scVoiceCount = round(oscArgFloat(msg, 0, scVoiceCount));
      scDroneAlive = oscArgFloat(msg, 1, scDroneAlive ? 1 : 0) > 0.5;
      scGlassAge = oscArgFloat(msg, 2, scGlassAge);
      scSaturation = constrain(oscArgFloat(msg, 3, scSaturation), 0, 1);
      scHoldStrength = constrain(oscArgFloat(msg, 4, scHoldStrength), 0, 1);
      scLifecycleState = round(oscArgFloat(msg, 5, scLifecycleState));
      lastSCHeartbeatMs = millis();
      return;
    }
    if (msg.checkAddrPattern("/launchpad/note") || msg.checkAddrPattern("/midi/note")) {
      int rawNote = round(oscArgFloat(msg, 0, -1));
      int rawVel = round(oscArgFloat(msg, 1, 0));
      boolean on = oscArgFloat(msg, 2, rawVel > 0 ? 1 : 0) > 0.5;
      handleLaunchpadOscNote(rawNote, rawVel, on);
      return;
    }
    if (msg.checkAddrPattern("/launchpad/page")) {
      int page = round(oscArgFloat(msg, 0, 0));
      launchpadSelectPage(page);
      return;
    }
    if (msg.checkAddrPattern("/launchpad/cc") || msg.checkAddrPattern("/midi/cc")) {
      int cc = round(oscArgFloat(msg, 0, -1));
      int rawValue = round(oscArgFloat(msg, 1, 0));
      handleLaunchpadOscControl(cc, rawValue);
      return;
    }
    if (!msg.checkAddrPattern("/rdf/audioDiag")) return;
    String tags = msg.typetag();
    if (tags == null || tags.length() < 6) return;
    audioDiagPsiGhostProb = oscArgFloat(msg, 0, audioDiagPsiGhostProb);
    audioDiagGhostTriggerCount = round(oscArgFloat(msg, 1, audioDiagGhostTriggerCount));
    audioDiagLastGhostAge = oscArgFloat(msg, 2, audioDiagLastGhostAge);
    audioDiagNextGlassAllowedTime = oscArgFloat(msg, 3, audioDiagNextGlassAllowedTime);
    audioDiagActualGlassTriggerCount = round(oscArgFloat(msg, 4, audioDiagActualGlassTriggerCount));
    audioDiagFloquetGEffLive = oscArgFloat(msg, 5, audioDiagFloquetGEffLive);
    audioDiagEcoChirpTriggerCount = round(oscArgFloat(msg, 6, audioDiagEcoChirpTriggerCount));
    audioDiagEcoChirpLastAge = oscArgFloat(msg, 7, audioDiagEcoChirpLastAge);
    audioDiagEcoCallTriggerCount = round(oscArgFloat(msg, 8, audioDiagEcoCallTriggerCount));
    audioDiagEcoCallLastAge = oscArgFloat(msg, 9, audioDiagEcoCallLastAge);
    audioDiagEcoGrowthTriggerCount = round(oscArgFloat(msg, 10, audioDiagEcoGrowthTriggerCount));
    audioDiagEcoGrowthLastAge = oscArgFloat(msg, 11, audioDiagEcoGrowthLastAge);
    audioDiagEcoFissureTriggerCount = round(oscArgFloat(msg, 12, audioDiagEcoFissureTriggerCount));
    audioDiagEcoFissureLastAge = oscArgFloat(msg, 13, audioDiagEcoFissureLastAge);
    scDiagRootFreq = oscArgFloat(msg, 14, scDiagRootFreq);
    scDiagDroneVolume = constrain(oscArgFloat(msg, 15, scDiagDroneVolume), 0, 1);
    scDiagArpVolume = constrain(oscArgFloat(msg, 16, scDiagArpVolume), 0, 1);
    scDiagGlassVolume = constrain(oscArgFloat(msg, 17, scDiagGlassVolume), 0, 1);
    scDiagChoirVolume = constrain(oscArgFloat(msg, 18, scDiagChoirVolume), 0, 1);
    scDiagDynamicBPM = oscArgFloat(msg, 19, scDiagDynamicBPM);
    scDiagRhythmComplexity = constrain(oscArgFloat(msg, 20, scDiagRhythmComplexity), 0, 1);
    audioDiagLastFrame = frameCount;
  } catch (Exception e) {
    if (frameCount % 120 == 0) {
      println("audioDiag OSC ignored: " + e.getMessage());
    }
  }
}

void handleLaunchpadOscNote(int rawNote, int rawVelocity, boolean on) {
  if (rawNote < 0) return;
  midiPilotConnected = true;
  midiLaunchpadDetected = true;
  float velocity = constrain(rawVelocity / 127.0, 0, 1);
  if (on && !launchpadGridRawNote(rawNote) && handleLaunchpadNoteControl(rawNote, velocity)) return;
  int note = launchpadMappedNote(rawNote);
  if (launchpadGridRawNote(rawNote) && on) launchpadPreparePolyKey(velocity);
  launchpadTrackMappedNote(note, on);
  handleMidiNoteEvent(note, velocity, on, midiHeldCount);
  midiPilotStatus = "Launchpad OSC poly voices=" + midiHeldCount + " mem=" + safeNf(midiPolyMemoryCharge, 1, 2);
}

void handleLaunchpadOscControl(int cc, int rawValue) {
  if (cc < 0) return;
  midiPilotConnected = true;
  midiLaunchpadDetected = true;
  handleLaunchpadControlEvent(cc, constrain(rawValue / 127.0, 0, 1), rawValue);
  midiPilotStatus = "Launchpad OSC CC " + cc + " = " + rawValue
    + (launchpadLastAction.length() > 0 ? (" | " + launchpadLastAction) : "");
}

float oscArgFloat(OscMessage msg, int idx, float fallback) {
  try { return msg.get(idx).floatValue(); } catch (Exception e) {}
  try { return (float)msg.get(idx).intValue(); } catch (Exception e) {}
  try { return Float.parseFloat(msg.get(idx).stringValue()); } catch (Exception e) {}
  return fallback;
}

float computeEntropyMetric(float[][] dom, int maxDepth) {
  if (dom == null) return 0;
  int bins = max(2, maxDepth + 1);
  int[] counts = new int[bins];
  int total = 0;
  for (int r = 0; r < dom.length; r++) {
    for (int c = 0; c < dom[r].length; c++) {
      int idx = constrain(round(dom[r][c] * (bins - 1)), 0, bins - 1);
      counts[idx]++;
      total++;
    }
  }
  float h = 0;
 for (int i = 0; i < bins; i++) {
    if (counts[i] > 0) {
      float p = (float)counts[i] / max(1, total);
      h -= p * log(p) / log(2);
    }
  }
  return h;
}

// Replace your computeFractalDimensionMetric with this:

float computeFractalDimensionMFDFA(float[][] field, int maxScale) {
    int N = GRID * GRID;
    float[] profile = new float[N];
    
    float mean = getAverageValue(field);
    int idx = 0;
    for (int r = 0; r < GRID; r++) {
        for (int c = 0; c < GRID; c++) {
            profile[idx] = (idx == 0) ? 0 : profile[idx-1] + (field[r][c] - mean);
            idx++;
        }
    }
    
    ArrayList<Float> logS = new ArrayList<Float>();
    ArrayList<Float> logF = new ArrayList<Float>();
    
    for (int s = 4; s <= maxScale; s *= 2) {
        int nSegments = N / s;
        float f2Sum = 0;
        
        for (int v = 0; v < nSegments; v++) {
            float[] seg = copyOfRange(profile, v*s, (v+1)*s);
            float[] trend = linearFit(seg);
            
            float variance = 0;
            for (int i = 0; i < s; i++) {
                variance += sq(seg[i] - trend[i]);
            }
            f2Sum += variance / s;
        }
        
        float F = sqrt(f2Sum / nSegments);
        logS.add(log(s));
        logF.add(log(F));
    }
    
    return linearSlope(logS, logF);
}
    
   
// ── 1. linearSlope ────────────────────────────────────────────
// Ordinary least-squares slope of logF vs logS arrays.
// Used by computeFractalDimensionRobust.
float linearSlope(float[] xs, float[] ys) {
  int n = min(xs.length, ys.length);
  if (n < 2) return 1.0;
  float mx = 0, my = 0;
  for (int i = 0; i < n; i++) { mx += xs[i]; my += ys[i]; }
  mx /= n; my /= n;
  float num = 0, den = 0;
  for (int i = 0; i < n; i++) {
    float dx = xs[i] - mx;
    num += dx * (ys[i] - my);
    den += dx * dx;
  }
  return den > 1e-10 ? num / den : 1.0;
}

// ArrayList overload used by the old CriticalSlowingDetector fits.
float linearSlope(ArrayList<Float> xs, ArrayList<Float> ys) {
  int n = min(xs.size(), ys.size());
  if (n < 2) return 1.0;
  float[] xa = new float[n], ya = new float[n];
  for (int i = 0; i < n; i++) { xa[i] = xs.get(i); ya[i] = ys.get(i); }
  return linearSlope(xa, ya);
}


// ── 2. differentialBoxCount ───────────────────────────────────
// Counts "occupied" boxes using the differential method:
// for each box, variance of values inside it contributes to the count.
// This is more accurate than a hard threshold for smooth gradient fields
// like the RDFT combined field.
int differentialBoxCount(float[][] field, int boxSize) {
  if (field == null || boxSize < 1) return 1;
  int rows = field.length;
  int cols = field[0].length;
  int count = 0;
  for (int r = 0; r < rows; r += boxSize) {
    for (int c = 0; c < cols; c += boxSize) {
      float mn = 1e9, mx = -1e9;
      for (int dr = 0; dr < boxSize && r + dr < rows; dr++) {
        for (int dc = 0; dc < boxSize && c + dc < cols; dc++) {
          float v = field[r + dr][c + dc];
          if (v < mn) mn = v;
          if (v > mx) mx = v;
        }
      }
      // Number of distinct intensity levels this box spans (>=1 always).
      count += max(1, ceil((mx - mn) * GRID));
    }
  }
  return max(1, count);
}


// ── 3. findElbowPoint ─────────────────────────────────────────
// Finds the index that minimises total SSE when the data is split
// into two linear segments.  Keeps the fit to the "finer scales"
// region that tends to be more reliably fractal.
int findElbowPoint(float[] xs, float[] ys) {
  int n = min(xs.length, ys.length);
  if (n < 4) return max(1, n - 1);
  float bestSSE = Float.MAX_VALUE;
  int bestK = n / 2;
  for (int k = 2; k < n - 1; k++) {
    float sse = segmentSSE(xs, ys, 0, k) + segmentSSE(xs, ys, k, n);
    if (sse < bestSSE) { bestSSE = sse; bestK = k; }
  }
  return bestK;
}

// SSE of a single linear fit over xs[from..to), ys[from..to).
float segmentSSE(float[] xs, float[] ys, int from, int toIdx) {
  int n = toIdx - from;
  if (n < 2) return 0;
  float mx = 0, my = 0;
  for (int i = from; i < toIdx; i++) { mx += xs[i]; my += ys[i]; }
  mx /= n; my /= n;
  float num = 0, den = 0;
  for (int i = from; i < toIdx; i++) {
    float dx = xs[i] - mx;
    num += dx * (ys[i] - my);
    den += dx * dx;
  }
  float slope = den > 1e-10 ? num / den : 0;
  float intercept = my - slope * mx;
  float sse = 0;
  for (int i = from; i < toIdx; i++) {
    float err = ys[i] - (intercept + slope * xs[i]);
    sse += err * err;
  }
  return sse;
}


// ── 4. computeFractalDimensionRobust ─────────────────────────
// Replaces the version that called the missing helpers.
// Uses geometric box scales from ~GRID/25 down to 2 pixels,
// differential box counting, elbow detection, and linear fit
// over the finer-scale region.
//
// Typical values for RDFT combined fields:
//   depth=1, alpha=4.5  → D ≈ 1.05  (sparse, nearly 1-D)
//   depth=6, alpha=2.0  → D ≈ 1.65  (moderately complex)
//   depth=7, alpha=1.1  → D ≈ 2.0   (space-filling)
float computeFractalDimensionRobust(float[][] field) {
  if (field == null) return 1.0;

  // Build a set of box sizes in geometric progression from GRID/2 down to 2.
  // 10 scales gives good log-log linearity without excessive compute.
  int nScales = 10;
  float[] logInvScale = new float[nScales];
  float[] logCount    = new float[nScales];

  for (int i = 0; i < nScales; i++) {
    // Geometric spacing: box = GRID * 0.5^(i * step)
    float t = (float) i / (nScales - 1);
    int box = max(2, round(GRID * pow(0.5f, t * 3.5f)));  // range ~GRID/2 down to ~2
    int occupied = differentialBoxCount(field, box);
    logInvScale[i] = log(1.0 / max(1, box));
    logCount[i]    = log(max(1, occupied));
  }

  // Find the region with the best linear fit (avoids saturation at coarse scales).
  int elbow = findElbowPoint(logInvScale, logCount);

  // Fit only the finer-scale region [0 .. elbow).
  float[] xs = new float[elbow];
  float[] ys = new float[elbow];
  for (int i = 0; i < elbow; i++) { xs[i] = logInvScale[i]; ys[i] = logCount[i]; }

  float D = linearSlope(xs, ys);

  // Clamp to a physically meaningful range for a 2-D field.
  return constrain(D, 1.0, 2.5);
}


// ── 5. computeFractalDimensionMetric ─────────────────────────
// Thin alias kept for any call sites that still use the old name.
float computeFractalDimensionMetric(float[][] field) {
  return computeFractalDimensionRobust(field);
}


// ── 6. linearFit (used by computeFractalDimensionMFDFA) ──────
// Returns a detrended array (segment - linear fit).
// Note: computeFractalDimensionMFDFA in the original code calls
// linearFit() and Arrays.copyOfRange() which are not available in
// Processing.  The MFDFA path is NOT wired into the main update loop
// so it is safe to leave it as an unused method.  This stub makes it
// compile cleanly.
float[] linearFit(float[] seg) {
  int n = seg.length;
  float[] trend = new float[n];
  if (n < 2) return trend;
  float sx = 0, sy = 0, sxy = 0, sx2 = 0;
  for (int i = 0; i < n; i++) {
    sx  += i; sy  += seg[i];
    sxy += i * seg[i]; sx2 += i * i;
  }
  float denom = n * sx2 - sx * sx;
  float slope     = denom > 1e-10 ? (n * sxy - sx * sy) / denom : 0;
  float intercept = (sy - slope * sx) / n;
  for (int i = 0; i < n; i++) trend[i] = intercept + slope * i;
  return trend;
}

// Arrays.copyOfRange stub — Processing does not have java.util.Arrays imported
// by default.  This avoids the compile error in computeFractalDimensionMFDFA.
float[] copyOfRange(float[] src, int from, int toIdx) {
  int len = max(0, toIdx - from);
  float[] out = new float[len];
  for (int i = 0; i < len && from + i < src.length; i++) out[i] = src[from + i];
  return out;
}


float computeKLDivergenceMetric(float[][] current, float[][] previous) {
  if (current == null || previous == null) return 0;
  float eps = 1e-6;

  // Pass 1: totals for normalization.
  float sumP = 0, sumQ = 0;
  int n = 0;
  for (int r = 0; r < current.length; r++) {
    for (int c = 0; c < current[r].length; c++) {
      sumP += constrain(current[r][c],  0, 1) + eps;
      sumQ += constrain(previous[r][c], 0, 1) + eps;
      n++;
    }
  }
  if (n == 0 || sumP < 1e-9 || sumQ < 1e-9) return 0;

  // Pass 2: true KL over normalized distributions.
  float klFwd = 0, klRev = 0;
  for (int r = 0; r < current.length; r++) {
    for (int c = 0; c < current[r].length; c++) {
      float p = (constrain(current[r][c],  0, 1) + eps) / sumP;
      float q = (constrain(previous[r][c], 0, 1) + eps) / sumQ;
      klFwd += p * log(p / q);
      klRev += q * log(q / p);
    }
  }

  metricKLForward   = klFwd;
  metricKLReverse   = klRev;
  metricKLSymmetric = (klFwd + klRev) * 0.5;
  return metricKLSymmetric;
}




// computeLyapunovMetric() retired — FTLE is now computed continuously
// inside stepShadow() using the Benettin renormalisation algorithm.
// metricLyapunov is updated every orbit step; no batch call needed.
// The orbitSpeedHistory / orbitRadiusHistory arrays are kept intact
// because the orbit event detector still reads from them.
float computeLyapunovMetric() {
  return metricLyapunov; // passthrough — real value lives in stepShadow()
}




// Rename: was computeMutualInfoMetric — now correctly labeled as linear MI proxy
// Exact only for jointly Gaussian variables. For RDFT fields this is an
// efficient real-time approximation; true MI would require histogram binning.
float computeLinearMIProxy(float a, float b, float c, float x, float y, float z) {
  float mx = (a + b + c) / 3.0;
  float my = (x + y + z) / 3.0;
  float cov = (a - mx) * (x - my) + (b - mx) * (y - my) + (c - mx) * (z - my);
  float vx = sq(a - mx) + sq(b - mx) + sq(c - mx);
  float vy = sq(x - my) + sq(y - my) + sq(z - my);
  float rho = cov / (sqrt(vx) * sqrt(vy) + 0.000001);
  rho = constrain(rho, -0.999, 0.999);
  return -0.5 * log(1 - rho * rho);
}

float[][] copyGrid(float[][] source) {
  if (source == null) return null;
  float[][] dest = new float[source.length][source[0].length];
  for (int r = 0; r < source.length; r++) {
    arrayCopy(source[r], dest[r]);
  }
  return dest;
}

void updateQuantitativeMetrics(float[][] field, float finest, float dominantVal, float avgBright, float maxBright, float orbSpeed, float orbRadius) {
  float instantaneousH = computeEntropyMetric(dominant, depth);
  // Alternate between robust box-count (every frame) and MFDFA (every 6 frames).
  // MFDFA is more accurate for multifractal fields but heavier to compute.
  if (frameCount % 6 == 0) {
    float mfdfa = computeFractalDimensionMFDFA(field, 256);
    float robust = computeFractalDimensionRobust(field);
    // Blend: MFDFA weighted more when field is active, robust as anchor
    float activity = constrain(metricEntropy / 2.0, 0, 1);
    metricFractalDim = lerp(robust, mfdfa, activity * 0.6);
  } else {
    metricFractalDim = computeFractalDimensionRobust(field);
  }
  orbitSpeedHistory.add(orbSpeed);
  orbitRadiusHistory.add(orbRadius);
  if (orbitSpeedHistory.size() > 120) orbitSpeedHistory.remove(0);
  if (orbitRadiusHistory.size() > 120) orbitRadiusHistory.remove(0);
  // metricLyapunov is written by stepShadow() every orbit step.
  // No batch recompute needed here; leave the value as-is.
  computeKLDivergenceMetric(field, previousCombinedField);
  previousCombinedField = copyGrid(field);
  metricKLDivergence = constrain(metricKLSymmetric, 0, 4.0);
  float klActivity = metricKLDivergence;
  metricEntropy = 0.92 * metricEntropy + 0.08 * (instantaneousH + klActivity * 0.8);
  metricMutualInfo = computeLinearMIProxy(finest, dominantVal, avgBright, maxBright, sliderAmp.getValue(), sliderReverb.getValue());
  computeFoundationalFieldMetrics(field, finest, dominantVal, avgBright, maxBright, orbSpeed, orbRadius);
}

void updateCurrentMetricsOnly() {
  boolean useSweepFrame = (animating && sweepReady && !sweepBuilding && sweepCache != null && sweepAlphas != null && sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float[][] field = safeField(useSweepFrame ? sweepCache[sweepIdx] : combined);
  if (field == null) return;
  float r_o = sqrt(orb_x * orb_x + orb_y * orb_y);
  float orbSpeed = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);
  float avgBright = getAverageValue(field);
  float maxBright = getMaxValue(field);
  float finest = getFinestScaleValue(field);
  float dominantVal = getDominantLayerValue();
  updateQuantitativeMetrics(field, finest, dominantVal, avgBright, maxBright, orbSpeed, r_o);
}

void updatePolyFieldDiagnostics(float nowMs, float r_o) {
  float currentRoot = (sliderRootFreq != null) ? sliderRootFreq.getValue() : rootFreqRaw;
  float heldNorm = constrain(midiHeldCount / 8.0, 0, 1);
  float velocityNorm = constrain(midiLastVelocity, 0, 1);
  float pressureRaw = constrain(
    heldNorm * 0.25 +
    velocityNorm * 0.20 +
    midiPolyHarmonicDensity * 0.25 +
    midiPolyChordSpread * 0.15 +
    midiPolyMemoryCharge * 0.15,
    0, 1);
  int triggerDelta = midiPolyTriggerCount - prevMidiPolyTriggerCount;
  int releaseDelta = midiPolyReleaseCount - prevMidiPolyReleaseCount;
  float stabilityDelta = cartStability - prevCartStabilityForFreq;

  if (!polyFieldDiagInitialized) {
    rootFreqRaw = currentRoot;
    rootFreqSmoothed = currentRoot;
    rootFreqPrevious = currentRoot;
    rootFreqPrevDelta = 0;
    prevCartStabilityForFreq = cartStability;
    prevMidiPolyTriggerCount = midiPolyTriggerCount;
    prevMidiPolyReleaseCount = midiPolyReleaseCount;
    polyFieldDiagInitialized = true;
    triggerDelta = 0;
    releaseDelta = 0;
    stabilityDelta = 0;
  }

  rootFreqRaw = currentRoot;
  rootFreqTarget = (midiPolyMode && midiHeldCount > 0) ? midiPolyRootTargetFreq : currentRoot;
  rootFreqPrevious = rootFreqSmoothed;
  rootFreqSmoothed = (rootFreqSmoothed <= 0) ? currentRoot : lerp(rootFreqSmoothed, currentRoot, 0.35);
  rootFreqDelta = currentRoot - rootFreqPrevious;
  rootFreqAccel = rootFreqDelta - rootFreqPrevDelta;
  rootFreqSlewRate = rootFreqDelta / max(0.001, LOG_EVERY_N_FRAMES / max(frameRate, 1.0));
  rootFreqJumpEvent =
    (abs(semitoneDiff(currentRoot, max(20, rootFreqPrevious))) >= KB_JUMP_SEMITONES) ? 1 : 0;

  harmonicPressureDelta = pressureRaw - harmonicPressure;
  harmonicPressure = pressureRaw;
  harmonicPressureSmoothed = lerp(harmonicPressureSmoothed, harmonicPressure, 0.25);
  harmonicPressurePeak = max(harmonicPressurePeak * 0.995, harmonicPressure);
  harmonicPressureEvent = (harmonicPressure > 0.65 && harmonicPressureDelta > 0.05) ? 1 : 0;

  // v2 detectors: semitone-relative (2026-06-12). Absolute-Hz gates removed.
  if (rootFreqBaselineSlow <= 0) rootFreqBaselineSlow = max(20, currentRoot);
  if (rootFreqExcursion == 0) {
    rootFreqBaselineSlow = lerp(rootFreqBaselineSlow, currentRoot, KB_BASELINE_SMOOTH);
  }

  float excursionSemis = abs(semitoneDiff(currentRoot, rootFreqBaselineSlow));
  rootFreqExcursion = (excursionSemis >= KB_EXCURSION_SEMITONES) ? 1 : 0;
  rootFreqExcursionEvent = (rootFreqExcursion == 1 && prevRootFreqExcursion == 0) ? 1 : 0;
  if (rootFreqExcursion == 1) {
    if (rootFreqExcursionStartMs < 0) {
      rootFreqExcursionStartMs = nowMs;
      rootFreqExcursionBaseline = rootFreqBaselineSlow;
      rootFreqExcursionPeak = currentRoot;
    }
    rootFreqExcursionPeak = max(rootFreqExcursionPeak, currentRoot);
    rootFreqExcursionDuration = (nowMs - rootFreqExcursionStartMs) / 1000.0;
    rootFreqReturnError = abs(currentRoot - rootFreqExcursionBaseline);
  } else {
    if (rootFreqExcursionStartMs >= 0) rootFreqReturnError = abs(currentRoot - rootFreqExcursionBaseline);
    rootFreqExcursionStartMs = -1.0;
    rootFreqExcursionDuration = 0.0;
    rootFreqExcursionPeak *= 0.995;
  }

  keyboardEvent = (triggerDelta != 0 || releaseDelta != 0) ? 1 : 0;
  if (triggerDelta > 0 && releaseDelta > 0) keyboardEventType = "note_on_off";
  else if (triggerDelta > 0) keyboardEventType = "note_on";
  else if (releaseDelta > 0) keyboardEventType = "note_off";
  else if (midiHeldCount > 0) keyboardEventType = "held";
  else keyboardEventType = "none";

  freqFieldCoupling = constrain(harmonicPressure * (0.50 + foundationalCoupling * 0.50), 0, 1);
  freqEntropyDrive = constrain(harmonicPressure * metricEntropy, 0, 1);
  freqStabilityDrive = constrain(harmonicPressure * (1.0 - cartStability), 0, 1);
  freqFloquetDrive = constrain(harmonicPressure * fsLockScoreGated, 0, 1);
  freqOrbitDrive = constrain(harmonicPressure * (r_o / 2.0), 0, 1);
  harmonicEscapeEvent = (rootFreqExcursion == 1 && harmonicPressure > KB_PRESSURE_GATE && stabilityDelta < -0.10) ? 1 : 0;
  harmonicCaptureEvent = (rootFreqExcursion == 1 && harmonicPressure > KB_PRESSURE_GATE && stabilityDelta > 0.10) ? 1 : 0;

  if (holoSweep != null && holoSweep.running) {
    if (sweepLegDiag != holoSweep.legIndex) {
      sweepLegDiag = holoSweep.legIndex;
      sweepLegKeyboardActive = false;
      sweepLegMaxRootFreq = currentRoot;
      sweepLegHarmonicPressureSum = 0;
      sweepLegHarmonicPressureSamples = 0;
      sweepLegFreqExcursionCount = 0;
    }
    sweepLegKeyboardActive = sweepLegKeyboardActive || midiHeldCount > 0 || keyboardEvent == 1 || harmonicPressure > 0.10;
    sweepLegMaxRootFreq = max(sweepLegMaxRootFreq, currentRoot);
    sweepLegHarmonicPressureSum += harmonicPressure;
    sweepLegHarmonicPressureSamples++;
    if (rootFreqExcursionEvent == 1) sweepLegFreqExcursionCount++;
  } else {
    sweepLegDiag = -999;
    sweepLegKeyboardActive = false;
    sweepLegMaxRootFreq = currentRoot;
    sweepLegHarmonicPressureSum = harmonicPressure;
    sweepLegHarmonicPressureSamples = 1;
    sweepLegFreqExcursionCount = rootFreqExcursionEvent;
  }

  prevRootFreqExcursion = rootFreqExcursion;
  prevMidiPolyTriggerCount = midiPolyTriggerCount;
  prevMidiPolyReleaseCount = midiPolyReleaseCount;
  prevCartStabilityForFreq = cartStability;
  rootFreqPrevDelta = rootFreqDelta;
}

float signedAngleDelta(float nowPhase, float prevPhase) {
  float d = nowPhase - prevPhase;
  while (d > PI) d -= TWO_PI;
  while (d < -PI) d += TWO_PI;
  return d;
}

void updateHopfDiagnostics(float phi, float r_o) {
  float cartNorm = sqrt(cartX * cartX + cartY * cartY + cartZ * cartZ);
  hopfFiberPhase = atan2(sin(phi), cos(phi));
  hopfThreadPhase = atan2(cartY, cartX);
  if (!hopfDiagInitialized) {
    hopfPrevFiberPhase = hopfFiberPhase;
    hopfPrevThreadPhase = hopfThreadPhase;
    hopfFiberWinding = 0;
    hopfThreadWinding = 0;
    hopfDiagInitialized = true;
  }
  hopfFiberDelta = signedAngleDelta(hopfFiberPhase, hopfPrevFiberPhase);
  hopfFiberWinding += hopfFiberDelta / TWO_PI;
  hopfThreadWinding += signedAngleDelta(hopfThreadPhase, hopfPrevThreadPhase) / TWO_PI;
  if (cartNorm > 0.0001) {
    hopfBaseX = cartX / cartNorm;
    hopfBaseY = cartY / cartNorm;
    hopfBaseZ = cartZ / cartNorm;
  } else {
    hopfBaseX = 0;
    hopfBaseY = 0;
    hopfBaseZ = 1;
  }
  hopfLinkProxy = hopfFiberWinding - hopfThreadWinding;
  hopfActivityProxy = constrain((abs(hopfFiberDelta) / PI) * 0.55 + orbitLockStrength * 0.25 + orbitResonanceScore * 0.20, 0, 1);
  hopfPrevFiberPhase = hopfFiberPhase;
  hopfPrevThreadPhase = hopfThreadPhase;
}

void logOscStateFrame() {
  if (!oscLoggingEnabled || oscLogWriter == null) return;

  boolean useSweepFrame = (animating && sweepReady && !sweepBuilding &&
    sweepCache != null && sweepAlphas != null &&
    sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float[][] field  = safeField(useSweepFrame ? sweepCache[sweepIdx] : combined);
  float r_o        = sqrt(orb_x * orb_x + orb_y * orb_y);
  float orbSpeed   = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);
  float phi        = orbResolutionField(r_o);
  float avgBright  = getAverageValue(field);
  float maxBright  = getMaxValue(field);
  float finest     = getFinestScaleValue(field);
  float dominantVal= getDominantLayerValue();
  updateHopfDiagnostics(phi, r_o);
  updatePolyFieldDiagnostics(millis(), r_o);
  float sweepLegMeanHarmonicPressure = sweepLegHarmonicPressureSamples > 0 ?
    (sweepLegHarmonicPressureSum / sweepLegHarmonicPressureSamples) : 0;

  // Safe UFO transition — guards against panel not yet initialized
  float ufoT = (fcPanel != null && fcPanel.fcReady) ? fcPanel.ufoTransition : 0.0;

  String line =
    // 1-2  time
    safeNf(millis() / 1000.0, 1, 3) + "," + frameCount + "," +
    // 3-11  field + orbit basics
    safeNf(safeAlphaValue(alpha), 1, 4) + "," +
    safeDepthValue(depth) + "," +
    safeNf(finest, 1, 4) + "," +
    safeNf(dominantVal, 1, 4) + "," +
    safeNf(avgBright, 1, 4) + "," +
    safeNf(maxBright, 1, 4) + "," +
    safeNf(phi, 1, 4) + "," +
    safeNf(orbSpeed, 1, 4) + "," +
    safeNf(r_o, 1, 4) + "," +
    // 12-13  mod source / scale
    int(menuModSource.getValue()) + "," +
    int(menuScale.getValue()) + "," +
    // 14-20  audio basics + MIDI pilot
    safeNf(sliderRootFreq.getValue(), 1, 2) + "," +
    (midiPilotConnected ? 1 : 0) + "," +
    midiLastRootNote + "," +
    midiHeldCount + "," +
    safeNf(midiLastVelocity, 1, 4) + "," +
    (midiPolyMode ? 1 : 0) + "," +
    safeNf(midiPolyMemoryCharge, 1, 4) + "," +
    safeNf(midiPolyHarmonicDensity, 1, 4) + "," +
    safeNf(midiPolyChordSpread, 1, 4) + "," +
    safeNf(midiPolyReleasePressure, 1, 4) + "," +
    midiPolyTriggerCount + "," +
    midiPolyReleaseCount + "," +
    safeNf(sliderAmp.getValue(), 1, 4) + "," +
    safeNf(sliderReverb.getValue(), 1, 4) + "," +
    // 17-19  toggles
    (toggleDrone.getState() ? 1 : 0) + "," +
    (toggleArp.getState() ? 1 : 0) + "," +
    (toggleGlass.getState() ? 1 : 0) + "," +
    // 20-23  volumes
    safeNf(getSliderValueSafe("droneVolume", 0.20), 1, 4) + "," +
    safeNf(getSliderValueSafe("arpVolume", 0.20), 1, 4) + "," +
    safeNf(getSliderValueSafe("glassVolume", 0.2), 1, 4) + "," +
    safeNf(getSliderValueSafe("choirVolume", 0.20), 1, 4) + "," +
    // 26-32  metrics
    safeNf(metricEntropy, 1, 4) + "," +
    safeNf(metricFractalDim, 1, 4) + "," +
    safeNf(metricLyapunov, 1, 4) + "," +
    safeNf(metricKLDivergence, 1, 4) + "," +
    safeNf(metricKLForward, 1, 4) + "," +
    safeNf(metricKLReverse, 1, 4) + "," +
    safeNf(metricMutualInfo, 1, 4) + "," +
    // 33-38  advanced trackers
    safeNf(metricAdiabaticParam, 1, 4) + "," +
    safeNf(metricBerryPhase, 1, 4) + "," +
    safeNf(berryTracker != null ? berryTracker.holonomyPrincipalRad / PI : 0, 1, 4) + "," +
    (berryTracker != null ? berryTracker.holonomyWindingTurns : 0) + "," +
    safeNf((berryTracker != null && holoSweep != null && abs(holoSweep.lastLoopArea) > 1e-6)
      ? berryTracker.holonomyRaw / holoSweep.lastLoopArea : 0, 1, 5) + "," +
    (holoSweep != null ? holoSweep.orientTagRunId : 0) + "," +
    (holoSweep != null ? holoSweep.orientTagLoopSeq : -1) + "," +
    safeNf(holoSweep != null ? holoSweep.orientTagArea : 0, 1, 1) + "," +
    safeNf(metricCorrelationTau, 1, 4) + "," +
    safeNf(metricStandardFit, 1, 4) + "," +
    safeNf(metricRDFit, 1, 4) + "," +
    metricBreakdownCount + "," +
    // 39-43  floquet
    safeNf(fsPhase, 1, 4) + "," +
    safeNf(envFloquetQuasienergy(), 1, 4) + "," +
    safeNf(envFloquetCoupling(), 1, 4) + "," +
    fsCycleCount + "," +
    safeNf(fsG, 1, 4) + "," +
    (envFloquetFrozen ? 1 : 0) + "," +
    safeNf(envFloquetFrozen ? envFloquetCouplingHeld : envFloquetCouplingLive(), 1, 4) + "," +
    safeNf(envFloquetFrozen ? envFloquetQuasienergyHeld : envFloquetQuasienergyLive(), 1, 4) + "," +
    // Floquet lifecycle gate diagnostics
    fsLifecycleState + "," +
    safeNf(fsLockAge, 1, 4) + "," +
    safeNf(fsInjectionAge, 1, 4) + "," +
    safeNf(fsReleaseAge, 1, 4) + "," +
    safeNf(fsCouplingEnvelope, 1, 4) + "," +
    safeNf(fsCooldownRemaining, 1, 4) + "," +
    safeNf(fsLockScoreRaw, 1, 4) + "," +
    safeNf(fsLockScoreGated, 1, 4) + "," +
    (fsReleaseCommand ? 1 : 0) + "," +
    safeNf(fsIntegratedAge, 1, 4) + "," +
    safeNf(fsFieldImprint, 1, 4) + "," +
    // solar
    (solarAffectsSynth ? 1 : 0) + "," +
    safeNf(solarBridge != null ? solarBridge.xrayNorm : 0, 1, 4) + "," +
    safeNf(solarBridge != null ? solarBridge.windNorm : 0, 1, 4) + "," +
    safeNf(solarBridge != null ? solarBridge.bzNorm : 0.5, 1, 4) + "," +
    safeNf(solarBridge != null ? solarBridge.kpNorm : 0, 1, 4) + "," +
    safeNf(solarDroneVolume, 1, 4) + "," +
    // ocean raw + interpreted field state
    safeNf(oceanBridge != null ? oceanBridge.liveNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.rawTide : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.rawTempC : 0, 1, 3) + "," +
    safeNf(oceanBridge != null ? oceanBridge.currentNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.phaseNorm : 0.5, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.thermalNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.rawRange : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.velocityNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.accelNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.energyNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.memoryNorm : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanExcite : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanColor : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanBurst : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanPersistence : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanDepthBias : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanCurvature : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanArpDrive : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanGlassDrive : 0, 1, 4) + "," +
    safeNf(oceanBridge != null ? oceanBridge.oceanReverbDrive : 0, 1, 4) + "," +
    // 50-55  cartography
    safeNf(cartX, 1, 4) + "," +
    safeNf(cartY, 1, 4) + "," +
    safeNf(cartZ, 1, 4) + "," +
    safeNf(cartStability, 1, 4) + "," +
    safeNf(cartVelocity, 1, 4) + "," +
    cartBasin.replace(",", "_") + "," +
    // 56-61  orbit event
    orbitEventLabel.replace(",", "_") + "," +
    safeNf(orbitLockStrength, 1, 4) + "," +
    orbitLobeEstimate + "," +
    safeNf(orbitEccentricity, 1, 4) + "," +
    safeNf(orbitPeriapsisIntensity, 1, 4) + "," +
    safeNf(orbitResonanceScore, 1, 4) + "," +
    // 62-68  foundational field / honest rot-activity proxy
    safeNf(foundationalDivE, 1, 4) + "," +
    safeNf(foundationalRotActivity, 1, 4) + "," +
    safeNf(foundationalPsiDensity, 1, 4) + "," +
    safeNf(foundationalUncertainty, 1, 4) + "," +
    safeNf(foundationalPlanckGate, 1, 4) + "," +
    safeNf(foundationalCoherence, 1, 4) + "," +
    safeNf(foundationalCoupling, 1, 4) + "," +
    // true Maxwell + Beltrami diagnostics
    safeNf(foundationalMaxwellDivETrue, 1, 6) + "," +
    safeNf(foundationalMaxwellLaplacianPhi, 1, 6) + "," +
    safeNf(beltramiBx, 1, 6) + "," +
    safeNf(beltramiBy, 1, 6) + "," +
    safeNf(beltramiBz, 1, 6) + "," +
    safeNf(beltramiBMag, 1, 6) + "," +
    safeNf(beltramiCurlX, 1, 6) + "," +
    safeNf(beltramiCurlY, 1, 6) + "," +
    safeNf(beltramiCurlZ, 1, 6) + "," +
    safeNf(beltramiCurlMag, 1, 6) + "," +
    safeNf(beltramiLambda, 1, 6) + "," +
    safeNf(beltramiAlignment, 1, 6) + "," +
    safeNf(beltramiHelicity, 1, 6) + "," +
    symbolicBeltramiState.replace(",", "_") + "," +
    symbolicMaxwellState.replace(",", "_") + "," +
    symbolicHolonomyEvent.replace(",", "_") + "," +
    // electrogravity + UFO
    safeNf(emergentEG, 1, 4) + "," +
    safeNf(effectiveVoltage, 1, 4) + "," +
    safeNf(electroGravityFactor, 1, 4) + "," +
    safeNf(ufoT, 1, 4) + "," +
    ((toggleEGProbe == null || toggleEGProbe.getState()) ? 1 : 0) + "," +
    (egProbeActive ? 1 : 0) + "," +
    safeNf(egProbeGateScore, 1, 4) + "," +
    safeNf(egProbeDepth, 1, 4) + "," +
    safeNf(egProbeTarget, 1, 4) + "," +
    safeNf(egProbeBaseFactor, 1, 4) + "," +
    safeNf(egProbeCooldownRemaining, 1, 4) + "," +
    egProbeTriggerCount + "," +
    // §12 phi-field scalars
    safeNf(phi_residual, 1, 6) + "," +
    safeNf(phi_gain, 1, 6) + "," +
    safeNf(phi_threshold_prox, 1, 4) + "," +
    safeNf(phiEngine.phi1_energy, 1, 6) + "," +
    // holographic surface boundary physics
    safeNf(surfaceZ, 1, 4) + "," +
    safeNf(surfaceCurv, 1, 4) + "," +
    surfaceDepthAt + "," +
    safeNf(landauerS, 1, 6) + "," +
    safeNf(landauerCoherence, 1, 4) + "," +
    (surfaceReady ? 1 : 0) + "," +
    scVoiceCount + "," +
    (scDroneAlive ? 1 : 0) + "," +
    safeNf(scSaturation, 1, 4) + "," +
    safeNf(scGlassAge, 1, 2) + "," +
    safeNf(scHoldStrength, 1, 4) + "," +
    scLifecycleState + "," +
    safeNf((millis() - lastSCHeartbeatMs) / 1000.0, 1, 2) + "," +
    galaxyName.replace(",", "_") + "," +
    (galaxyLoaded ? 1 : 0) + "," +
    safeNf(galaxyBlend, 1, 4) + "," +
    safeNf(galaxyFieldCurvature, 1, 4) + "," +
    safeNf(galaxyFloquetCoupling, 1, 4) + "," +
    safeNf(galaxyBoundaryPersist, 1, 4) + "," +
    ((toggleEcoChirp == null || toggleEcoChirp.getState()) ? 1 : 0) + "," +
    ((toggleEcoCall == null || toggleEcoCall.getState()) ? 1 : 0) + "," +
    ((toggleEcoGrowth == null || toggleEcoGrowth.getState()) ? 1 : 0) + "," +
    ((toggleEcoFissure == null || toggleEcoFissure.getState()) ? 1 : 0) + "," +
    safeNf(getSliderValueSafe("ecoChirpLevel", 0.58), 1, 4) + "," +
    safeNf(getSliderValueSafe("ecoCallLevel", 0.58), 1, 4) + "," +
    safeNf(getSliderValueSafe("ecoGrowthLevel", 0.64), 1, 4) + "," +
    safeNf(getSliderValueSafe("ecoFissureLevel", 0.64), 1, 4) + "," +
    audioDiagEcoChirpTriggerCount + "," +
    safeNf(audioDiagEcoChirpLastAge, 1, 4) + "," +
    audioDiagEcoCallTriggerCount + "," +
    safeNf(audioDiagEcoCallLastAge, 1, 4) + "," +
	    audioDiagEcoGrowthTriggerCount + "," +
	    safeNf(audioDiagEcoGrowthLastAge, 1, 4) + "," +
	    audioDiagEcoFissureTriggerCount + "," +
		    safeNf(audioDiagEcoFissureLastAge, 1, 4) + "," +
			    (holoSweep.running ? "RECTANGLE" : "NONE") + "," +
			    (holoSweep.running ? "holonomy_rectangle" : "") + "," +
			    (holoSweep.running ? "holonomy_rectangle" : "") + "," +
			    holoSweep.legIndex + "," +
			    (holoSweep.dwelling ? 1 : 0) + "," +
			    safeNf(holoSweep.legProgress, 1, 4) + "," +
			    safeNf(holoSweep.running ? holoSweep.cornerA(holoSweep.legIndex + 1) : alpha, 1, 4) + "," +
			    safeNf(holoSweep.running ? holoSweep.cornerD(holoSweep.legIndex + 1) : depth, 1, 4) + "," +
			    safeNf(alpha, 1, 4) + "," +
			    depth + "," +
			    "0.0000,0," + safeNf(frameRate, 1, 2) + "," +
			    holoSweep.loopClosedFlag + "," +
			    safeNf(holoSweep.lastReturnError, 1, 6) + "," +
			    (holoSweep.running ? 1 : 0) + "," +
			    (holoSweep.pausedForLag ? 1 : 0) + "," +
			    safeNf(holoSweep.lastLoopArea, 1, 6) + "," +
			    safeNf(1.0 - constrain(holoSweep.lastReturnError, 0, 1), 1, 4) + "," +
	    ((toggleGhost == null || toggleGhost.getState()) ? 1 : 0) + "," +
    safeNf(audioDiagPsiGhostProb, 1, 6) + "," +
    audioDiagGhostTriggerCount + "," +
	    safeNf(audioDiagLastGhostAge, 1, 4) + "," +
	    safeNf(audioDiagNextGlassAllowedTime, 1, 4) + "," +
	    audioDiagActualGlassTriggerCount + "," +
	    // TODO: keep this duplicate as the SuperCollider live diagnostic; canonical fsG is logged in floquet_g_eff.
	    safeNf(audioDiagFloquetGEffLive, 1, 6) + "," +
	    safeNf(rootFreqTarget, 1, 4) + "," +
	    safeNf(rootFreqPrevious, 1, 4) + "," +
	    safeNf(rootFreqDelta, 1, 4) + "," +
	    safeNf(rootFreqAccel, 1, 4) + "," +
	    safeNf(rootFreqSlewRate, 1, 4) + "," +
	    safeNf(rootFreqSmoothed, 1, 4) + "," +
	    safeNf(rootFreqRaw, 1, 4) + "," +
	    rootFreqJumpEvent + "," +
	    safeNf(harmonicPressure, 1, 4) + "," +
	    safeNf(harmonicPressureSmoothed, 1, 4) + "," +
	    safeNf(harmonicPressureDelta, 1, 4) + "," +
	    safeNf(harmonicPressurePeak, 1, 4) + "," +
	    harmonicPressureEvent + "," +
	    safeNf(freqFieldCoupling, 1, 4) + "," +
	    safeNf(freqEntropyDrive, 1, 4) + "," +
	    safeNf(freqStabilityDrive, 1, 4) + "," +
	    safeNf(freqFloquetDrive, 1, 4) + "," +
	    safeNf(freqOrbitDrive, 1, 4) + "," +
	    keyboardEvent + "," +
	    keyboardEventType + "," +
	    rootFreqExcursion + "," +
	    safeNf(rootFreqExcursionPeak, 1, 4) + "," +
	    safeNf(rootFreqExcursionDuration, 1, 4) + "," +
	    safeNf(rootFreqReturnError, 1, 4) + "," +
	    harmonicEscapeEvent + "," +
	    harmonicCaptureEvent + "," +
	    (sweepLegKeyboardActive ? 1 : 0) + "," +
	    safeNf(sweepLegMaxRootFreq, 1, 4) + "," +
	    safeNf(sweepLegMeanHarmonicPressure, 1, 4) + "," +
	    sweepLegFreqExcursionCount + "," +
	    safeNf(hopfFiberPhase, 1, 6) + "," +
	    safeNf(hopfFiberWinding, 1, 6) + "," +
	    safeNf(hopfFiberDelta, 1, 6) + "," +
	    safeNf(hopfBaseX, 1, 6) + "," +
	    safeNf(hopfBaseY, 1, 6) + "," +
	    safeNf(hopfBaseZ, 1, 6) + "," +
	    safeNf(hopfThreadPhase, 1, 6) + "," +
	    safeNf(hopfThreadWinding, 1, 6) + "," +
	    safeNf(hopfLinkProxy, 1, 6) + "," +
	    safeNf(hopfActivityProxy, 1, 6);

	  oscLogWriter.println(line);
	  if (holoSweep != null && holoSweep.loopClosedFlag == 1) holoSweep.loopClosedFlag = 0;
	  logLineCounter++;
  if (logLineCounter % LOG_FLUSH_EVERY_N_LINES == 0) {
    oscLogWriter.flush();
  }
}

void sendModeParameters() {
  if (oscP5 == null || supercollider == null || menuModSource == null) return;
  int mode = constrain(round(menuModSource.getValue()), 0, MODE_NAMES.length - 1);
  boolean useSweepFrame = (animating && sweepReady && !sweepBuilding && sweepCache != null && sweepAlphas != null && sweepIdx >= 0 && sweepIdx < sweepAlphas.length);
  float[][] field = safeField(useSweepFrame ? sweepCache[sweepIdx] : combined);
  float avgBright = getAverageValue(field);
  float finest = getFinestScaleValue(field);
  float r_o = sqrt(orb_x * orb_x + orb_y * orb_y);
  float orbSpeed = sqrt(orb_vx * orb_vx + orb_vy * orb_vy);

  OscMessage msg = new OscMessage("/rdf/mode");
  msg.add((float)mode);
  msg.add(MODE_NAMES[mode]);
  msg.add(avgBright);
  msg.add(finest);
  msg.add(metricEntropy);
  msg.add(metricFractalDim);
  msg.add(metricLyapunov);
  msg.add(metricKLDivergence);
  msg.add(metricMutualInfo);
  msg.add(orbSpeed);
  msg.add(r_o);
  msg.add(sliderRootFreq.getValue());
  msg.add(sliderAmp.getValue());
  msg.add(metricAdiabaticParam);
  msg.add(metricBerryPhase);
  msg.add(metricCorrelationTau);
  msg.add(metricBreakdownCount);
  msg.add(envFloquetCoupling());
  msg.add(envFloquetQuasienergy());
  oscP5.send(msg, supercollider);
}


// ========== FLOQUET / ADIABATIC / BERRY / CRITICAL RD MODULES ==========
void STARTSWEEP(int val) {
  applyParameterBoxes(false);
  if (adiabaticTracker == null) adiabaticTracker = new AdiabaticTracker();
  float targetA = parseTextFloat(fieldSweepAlphaTarget, (alpha < 2.8) ? 4.2 : 1.4);
  float targetD = parseTextFloat(fieldSweepDepthTarget, (depth < 6) ? 7 : 3);
  float dur = parseTextFloat(fieldSweepDuration, 60.0);
  targetA = constrain(targetA, 1.0, 4.5);
  targetD = constrain(targetD, 0, 7);
  dur = constrain(dur, 5.0, 300.0);
  fieldSweepAlphaTarget.setText(safeNf(targetA,1,2));
  fieldSweepDepthTarget.setText(str(round(targetD)));
  fieldSweepDuration.setText(str(round(dur)));
  adiabaticTracker.closeOnComplete = true;
  adiabaticTracker.captureSnapshots = true;
  adiabaticTracker.startSweep(targetA, targetD, dur);
  phiEngine.beginSweep(phiEngine.phi, phiEngine.S);  // §6 perturbation tracking
  statusMsg = "Adiabatic sweep started: a " + safeNf(alpha,1,2) + " -> " + safeNf(targetA,1,2) + " depth " + depth + " -> " + round(targetD);
}

void APPLYPARAMS(int val) {
  applyParameterBoxes(true);
}

void rootFreqBox(String val) {
  // Called when user presses Enter in the root freq text box
  try {
    float freq = Float.parseFloat(val.trim());
    freq = constrain(freq, 20, 880);
    if (sliderRootFreq != null) sliderRootFreq.setValue(freq);
    if (fieldRootFreq != null) fieldRootFreq.setText(safeNf(freq, 1, 1));
  } catch (Exception e) {
    if (fieldRootFreq != null && sliderRootFreq != null)
      fieldRootFreq.setText(safeNf(sliderRootFreq.getValue(), 1, 1));
  }
}

float parseTextFloat(Textfield tf, float fallback) {
  if (tf == null) return fallback;
  try {
    String t = trim(tf.getText());
    if (t == null || t.length() == 0) return fallback;
    return Float.parseFloat(t);
  } catch (Exception e) {
    return fallback;
  }
}

void applyParameterBoxes(boolean recomputeNow) {
  float dRaw = parseTextFloat(fieldDepth, depth);
  float aRaw = parseTextFloat(fieldAlpha, alpha);
  float gRaw = parseTextFloat(fieldGamma, orb_gamma);
  int newDepth = round(constrain(dRaw, 0, 7));
  float newAlpha = constrain(aRaw, 1.1, 4.5);
  float newGamma = constrain(gRaw, -2.5, 0.5);
  depth = newDepth;
  alpha = newAlpha;
  orb_gamma = newGamma;
  if (sliderDepth != null) sliderDepth.setValue(depth);
  if (sliderAlpha != null) sliderAlpha.setValue(alpha);
  if (sliderGamma != null) sliderGamma.setValue(orb_gamma);
  if (fieldDepth != null) fieldDepth.setText(str(depth));
  if (fieldAlpha != null) fieldAlpha.setText(safeNf(alpha,1,2));
  if (fieldGamma != null) fieldGamma.setText(safeNf(orb_gamma,1,2));
  if (recomputeNow) {
    layerCache = null;
    computeFrames();
    phiEngine.rebuildRadialTable(getAverageValue(combined != null ? combined : new float[GRID][GRID]));
    // Sweep cache rebuild is intentionally deferred.  Rebuilding all 60 cached
    // alpha frames immediately after every typed value caused Pi 400 hiccups.
    // The live adiabatic sweep computes only the frames it needs.
    statusMsg = "Precise RDFT parameters applied";
  }
}

void RESETBERRY(int val) {
  if (berryTracker == null) berryTracker = new BerryPhaseTracker();
  berryTracker.reset();
  if (stateCartographer != null) stateCartographer.reset();
  metricBerryPhase = 0;
  statusMsg = "Berry/cartography paths reset";
}

// Frozen-environment mode: hold kappa/epsilon constant so holonomy area-scaling
// runs see a fixed Floquet drive. Default OFF = live environmental sourcing.
boolean envFloquetFrozen = false;
float   envFloquetCouplingHeld    = 0;
float   envFloquetQuasienergyHeld = 0;

float envFloquetCouplingLive() {
  float ocean = 0;
  if (oceanBridge != null) {
    ocean = constrain(
      oceanBridge.energyNorm * 0.42 +
      oceanBridge.currentNorm * 0.20 +
      oceanBridge.thermalNorm * 0.20 +
      oceanBridge.oceanExcite * 0.18,
      0, 1);
  }

  float solar = 0;
  if (solarBridge != null) {
    float bzStress = abs((solarBridge.bzNorm - 0.5) * 2.0);
    solar = constrain(
      solarBridge.kpNorm * 0.32 +
      solarBridge.windNorm * 0.24 +
      solarBridge.xrayNorm * 0.24 +
      bzStress * 0.20,
      0, 1);
  }

  float env = constrain(ocean * 0.68 + solar * 0.32, 0, 1);
  if (galaxyLoaded) {
    env = lerp(env, constrain(galaxyFloquetCoupling, 0, 1), constrain(galaxyBlend, 0, 1) * 0.45);
  }
  return constrain(env, 0, 1);
}

float envFloquetCoupling() {
  return envFloquetFrozen ? envFloquetCouplingHeld : envFloquetCouplingLive();
}

float envFloquetQuasienergyLive() {
  float ocean = 0;
  if (oceanBridge != null) {
    ocean = constrain(
      oceanBridge.velocityNorm * 0.42 +
      oceanBridge.accelNorm * 0.34 +
      oceanBridge.energyNorm * 0.24,
      0, 1);
  }

  float solar = 0;
  if (solarBridge != null) {
    float bzStress = abs((solarBridge.bzNorm - 0.5) * 2.0);
    solar = constrain(
      solarBridge.xrayNorm * 0.34 +
      solarBridge.kpNorm * 0.26 +
      solarBridge.windNorm * 0.20 +
      bzStress * 0.20,
      0, 1);
  }

  return constrain(ocean * 0.70 + solar * 0.30, 0, 1);
}

float envFloquetQuasienergy() {
  return envFloquetFrozen ? envFloquetQuasienergyHeld : envFloquetQuasienergyLive();
}

void updateAdvancedRDTrackers() {
  // Berry/holonomy: snapshots are fed only during adiabatic sweeps
  // (inside AdiabaticTracker.update()). Outside sweeps the value is
  // frozen at the last computed holonomy — it doesn't drift or accumulate.
  // metricBerryPhase is written by closeSweepLoop() at sweep completion.
  // Nothing to do here between sweeps.
  if (criticalDetector != null) {
    criticalDetector.addSample(alpha, metricEntropy + metricKLDivergence);
    metricCorrelationTau = criticalDetector.computeCorrelationTime(criticalDetector.responseHistory);
    if (criticalDetector.responseHistory.size() > 24) {
      criticalDetector.compareFits();
      metricStandardFit = criticalDetector.standardFitChi2;
      metricRDFit = criticalDetector.rdFitChi2;
    }
  }
  if (stateCartographer != null) {
    stateCartographer.update();
  }
}

void sendBreakdownToSC(float adiabaticParam) {
  if (oscP5 == null || supercollider == null) return;
  OscMessage msg = new OscMessage("/rdf/breakdown");
  msg.add(adiabaticParam);
  msg.add(metricEntropy);
  msg.add(metricKLDivergence);
  msg.add((float)metricBreakdownCount);
  oscP5.send(msg, supercollider);
}

class AdiabaticTracker {
  float startAlpha, targetAlpha;
  float startDepth, targetDepth;
  float sweepStartTime, sweepDuration;
  boolean isSweeping = false;
  boolean closeOnComplete = true;
  boolean captureSnapshots = true;
  int lastHeavyComputeMs = 0;
  float lastComputedAlpha = -999;
  int lastComputedDepth = -999;
  final int MIN_COMPUTE_INTERVAL_MS = 160;
  final float MIN_ALPHA_STEP_FOR_RECOMPUTE = 0.035;
  ArrayList<Float> alphaHistory = new ArrayList<Float>();
  ArrayList<Float> depthHistory = new ArrayList<Float>();
  ArrayList<Float> entropyHistory = new ArrayList<Float>();
  ArrayList<Float> timeHistory = new ArrayList<Float>();

  void startSweep(float targetA, float targetD, float durationSeconds) {
    startAlpha = alpha;
    targetAlpha = constrain(targetA, 1.0, 4.5);
    startDepth = depth;
    targetDepth = constrain(targetD, 0, 7);
    sweepDuration = max(1.0, durationSeconds);
    sweepStartTime = millis();
    isSweeping = true;
    alphaHistory.clear(); depthHistory.clear(); entropyHistory.clear(); timeHistory.clear();
    lastHeavyComputeMs = 0;
    lastComputedAlpha = -999;
    lastComputedDepth = -999;
  }

  void update() {
  if (!isSweeping) return;

  float elapsed = (millis() - sweepStartTime) / 1000.0;
  float progress = constrain(elapsed / sweepDuration, 0, 1);

  // Smoothstep gives a continuous, adiabatic-feeling ramp without abrupt velocity changes.
  // Heavy recursive recomputation is throttled below so the GUI/audio path stays responsive.
  float smoothProgress = progress * progress * (3 - 2 * progress);
  float nextAlpha = lerp(startAlpha, targetAlpha, smoothProgress);
  int nextDepth = round(lerp(startDepth, targetDepth, smoothProgress));

  alpha = safeAlphaValue(nextAlpha);
  depth = safeDepthValue(nextDepth);

  boolean depthChanged = (nextDepth != lastComputedDepth);
  boolean alphaMoved = abs(nextAlpha - lastComputedAlpha) >= MIN_ALPHA_STEP_FOR_RECOMPUTE;
  boolean enoughTime = millis() - lastHeavyComputeMs >= MIN_COMPUTE_INTERVAL_MS;
  boolean forceFinal = progress >= 1.0;

  // Do not call slider.setValue() or computeFrames() every draw cycle.
  if ((enoughTime && (depthChanged || alphaMoved)) || forceFinal) {
    sliderAlpha.setValue(alpha);
    sliderDepth.setValue(depth);

    if (fieldAlpha != null) fieldAlpha.setText(safeNf(alpha, 1, 2));
    if (fieldDepth != null) fieldDepth.setText(str(depth));

    layerCache = null;
    computeFrames();

	    phiEngine.rebuildRadialTable(getAverageValue(combined != null ? combined : new float[GRID][GRID]));

    lastHeavyComputeMs = millis();
    lastComputedAlpha = nextAlpha;
    lastComputedDepth = nextDepth;
  }

  alphaHistory.add(alpha);
  depthHistory.add((float)depth);
  entropyHistory.add(metricEntropy);
  timeHistory.add(elapsed);
  if (alphaHistory.size() > 10) detectBreakdown();

  if (progress >= 1.0) {
    isSweeping = false;
    phiEngine.endSweep();

    layerCache = null;
    computeFrames();

	    phiEngine.rebuildRadialTable(getAverageValue(combined != null ? combined : new float[GRID][GRID]));

		    // Single-target sweeps trace an OPEN path; their closure is gauge-dependent
		    // and not a true holonomy. Loop closure belongs only to HolonomySweepInstrument.
		    if (berryTracker != null) {
		      berryTracker.reset();
		    }
		    closeOnComplete = true;
		    captureSnapshots = true;

    println("=== ADIABATIC SWEEP COMPLETE === alpha " 
      + startAlpha + " -> " + targetAlpha 
      + " depth " + startDepth + " -> " + targetDepth);
  }
}

void detectBreakdown() {
  int n = alphaHistory.size();
  float dt = timeHistory.get(n - 1) - timeHistory.get(n - 2);
  if (dt < 0.001) return;

  float a0 = max(alphaHistory.get(n - 2), 1.01);
  float a1 = max(alphaHistory.get(n - 1), 1.01);
  float d0 = max(depthHistory.get(n - 2), 1.0);
  float d1 = max(depthHistory.get(n - 1), 1.0);

  float r0 = log(d0) / log(a0);
  float r1 = log(d1) / log(a1);
  float dRdt = (r1 - r0) / dt;
  float R = r1;

  metricAdiabaticParam = abs(dRdt) / max(0.0001, pow(a1, R));

  float entropyChange = 0;
  if (n > 20) {
    entropyChange = abs(entropyHistory.get(n - 1) - entropyHistory.get(n - 11));
  }

  if (metricAdiabaticParam > 1.0 || entropyChange > 0.5) {
    recordBreakdownEvent(n - 1, metricAdiabaticParam, entropyChange);
  }
}

  void recordBreakdownEvent(int idx, float adiabaticParam, float entropyChange) {
    metricBreakdownCount++;
    lastBreakdownEvent = "BREAKDOWN frame=" + frameCount + " t=" + safeNf(timeHistory.get(idx),1,3) +
      " alpha=" + safeNf(alphaHistory.get(idx),1,3) + " depth=" + safeNf(depthHistory.get(idx),1,1) +
      " adiabatic=" + safeNf(adiabaticParam,1,3) + " dEntropy=" + safeNf(entropyChange,1,3);
    println(lastBreakdownEvent);
    sendBreakdownToSC(adiabaticParam);
  }
}


class RecursiveStateSpaceCartographer {
  final int MAX_POINTS = 420;
  float[] xTrace = new float[MAX_POINTS];
  float[] yTrace = new float[MAX_POINTS];
  float[] zTrace = new float[MAX_POINTS];
  float[] stabilityTrace = new float[MAX_POINTS];
  int head = 0;
  int count = 0;
  float lastX = 0.5;
  float lastY = 0.5;

    

  // Slowly rotating orthographic projection angle (x-z plane).
  // One full rotation every ~600 update() calls at 8Hz ≈ 75 seconds.
  // This lets z accumulate as a parallax offset so the 3D shape of the
  // trajectory becomes readable over time without a 3D renderer.
  
  float rotTheta = 0;
  final float ROT_RATE = TWO_PI / 600.0;

  void reset() {
    head = 0;
    count = 0;
    lastX = 0.5;
    lastY = 0.5;
    cartVelocity = 0;
  }

  void update() {
    float aN = constrain((safeAlphaValue(alpha) - 1.1) / 3.4, 0, 1);
    float dN = constrain(safeDepthValue(depth) / 7.0, 0, 1);
    float eN = constrain(metricEntropy / 3.0, 0, 1);
    float fN = constrain((metricFractalDim - 1.0) / 1.4, 0, 1);
    float lN = constrain(metricLyapunov / 1.2, 0, 1);
    float kN = constrain(metricKLDivergence * 2.5, 0, 1);
    float miN = constrain(metricMutualInfo / 1.0, 0, 1);
    float flN = constrain(envFloquetCoupling(), 0, 1);
    float qN = constrain(envFloquetQuasienergy(), 0, 1);
    float solN = solarBridge != null ? constrain((solarBridge.windNorm + solarBridge.xrayNorm + solarBridge.kpNorm) / 3.0, 0, 1) : 0;

    // Virtual phase-space projection.  X favors coherence/alpha/mutual information;
    // Y favors active recursive density, Lyapunov growth, and change energy.
    float x = 0.50 + 0.30*(aN - 0.5) + 0.22*(miN - 0.5) - 0.18*(eN - 0.5) + 0.16*(flN - 0.5) + 0.08*(solN - 0.5);
    float y = 0.50 + 0.28*(dN - 0.5) + 0.25*(lN - 0.5) + 0.18*(kN - 0.5) + 0.12*(qN - 0.5) - 0.12*(fN - 0.5);
    float z = constrain(0.40*eN + 0.25*lN + 0.20*kN + 0.15*qN, 0, 1);
    float stability = constrain(0.34*(1.0-eN) + 0.24*miN + 0.18*flN + 0.16*(1.0-lN) + 0.08*(1.0-kN), 0, 1);

    x = constrain(x, 0.02, 0.98);
    y = constrain(y, 0.02, 0.98);
    cartVelocity = dist(x, y, lastX, lastY);
    lastX = x;
    lastY = y;

    cartX = x;
    cartY = y;
    cartZ = z;
    cartStability = stability;
    cartBasin = classifyBasin(eN, lN, kN, miN, stability, flN);
    if (cartBasin.equals(prevCartBasin)) {
      framesInCurrentBasin++;
    } else {
      framesInCurrentBasin = 0;
      prevCartBasin = cartBasin;
    }
    if (cartBasin.equals("COHERENCE BASIN")) {
      framesSinceCoherence = 0;
    } else {
      framesSinceCoherence++;
    }

    xTrace[head] = x;
    yTrace[head] = y;
    zTrace[head] = z;
    stabilityTrace[head] = stability;
    head = (head + 1) % MAX_POINTS;
    count = min(count + 1, MAX_POINTS);
    rotTheta += ROT_RATE;
    if (rotTheta > TWO_PI) rotTheta -= TWO_PI;
  }

  int indexFromOldest(int k) {
    int start = (head - count + MAX_POINTS) % MAX_POINTS;
    return (start + k) % MAX_POINTS;
  }

  String classifyBasin(float eN, float lN, float kN, float miN, float stability, float flN) {
    if (stability > 0.70 && eN < 0.48 && lN < 0.55) return "COHERENCE BASIN";
    if (eN > 0.70 && miN > 0.35) return "DENSE COUPLED FIELD";
    if (kN > 0.55 || lN > 0.72) return "TRANSITION RIDGE";
    if (flN > 0.78 && stability > 0.55) return "FLOQUET LOCK";
    if (stability < 0.32) return "DISRUPTION ZONE";
    return "METASTABLE DRIFT";
  }
}

// ── True Berry / Holonomy tracker ────────────────────────────────────────────
// Uses the Pancharatnam inner-product (discrete holonomy) method.
// Each field snapshot is treated as a state vector |ψᵢ⟩.
// The geometric phase around a closed parameter-space loop is:
//
//   γ = -Im( ln( ⟨ψ₀|ψ₁⟩ · ⟨ψ₁|ψ₂⟩ · ... · ⟨ψₙ₋₁|ψ₀⟩ ) )
//
// The complex product of consecutive overlaps accumulates as (re, im).
// atan2(im, re) at loop closure gives the true holonomy angle in [-π, π].
//
// Snapshots are only recorded during an adiabatic sweep (called from
// AdiabaticTracker.update()). The loop is only closed — and holonomy
// computed — when the sweep completes. Outside sweeps the value is frozen
// at the last computed result and the snapshot buffer is idle.
//
// A holonomy crossing zero or π signals a topological transition in the
// parameter space (a Berry phase "winding" change). These are the moments
// worth marking sonically.
// Control-space normalization for holonomy snapshots. Spans should generously
// cover the instrument's operating rectangle so theta is well-conditioned.
final float HOLO_ALPHA_CENTER = 2.75;   // midpoint of alpha range [1.0, 4.5]
final float HOLO_ALPHA_SPAN   = 1.75;   // half-width
final float HOLO_DEPTH_CENTER = 3.0;    // midpoint of depth range [1, 5]
final float HOLO_DEPTH_SPAN   = 2.0;    // half-width
class BerryPhaseTracker {

  // Field snapshot ring buffer.
  // Each entry is a flattened GRID×GRID float array (10000 values).
  // 20s-leg rectangles generate 90+ snapshots; 64 wrapped and broke loop closure.
  static final int MAX_SNAPS = 256;
  static final int PHASE_SLOTS = 14;
  static final float PHASE_WEIGHT = 30.0; // overall phase-vs-field-bulk amplification
  float phaseWeight(int i) {
    if (i <= 1)  return PHASE_WEIGHT * 1.6;   // control-space theta sin/cos: orientation-odd
    if (i <= 3)  return PHASE_WEIGHT * 1.2;   // Floquet quasienergy/coupling
    if (i <= 5)  return PHASE_WEIGHT * 0.9;   // normalized alpha/depth control coordinates
    if (i <= 9)  return PHASE_WEIGHT * 0.35;  // autonomous orbital pos/vel: de-emphasized
    if (i <= 13) return PHASE_WEIGHT * 0.8;   // entropy, Lyapunov, coherence, coupling
    return 1.0;                               // field bulk
  }
  float[][] snaps       = new float[MAX_SNAPS][GRID * GRID];
  float[]   snapAlpha   = new float[MAX_SNAPS];
  float[]   snapDepth   = new float[MAX_SNAPS];
  int       snapCount   = 0;
  int       snapHead    = 0;

  boolean   loopActive  = false;
  float     berryPhase  = 0;      // unwrapped gamma in pi units; may exceed ±1 for large loops
  float     holonomyRaw = 0;      // unwrapped gamma in radians, for SC and display
  float     holonomyPrincipalRad = 0;  // principal-branch atan2, cross-check
  int       holonomyWindingTurns = 0;  // full 2π turns the loop wound

  // Overlap cache — avoids recomputing norms on every inner product call.
  float[]   snapNorms   = new float[MAX_SNAPS];

  // Called by AdiabaticTracker.update() on every throttled recompute tick
  // during a sweep. Not called outside sweeps.
	  void addStateSnapshot(float[][] field, float a, float d) {
	    if (field == null) return;
    int idx = snapHead % MAX_SNAPS;

    // Flatten field into snapshot slot and compute its L2 norm.
    float norm = 0;
    for (int r = 0; r < GRID; r++) {
      for (int c = 0; c < GRID; c++) {
        float v = constrain(field[r][c], 0, 1);
        snaps[idx][r * GRID + c] = v;
        norm += v * v;
      }
    }
    snapNorms[idx] = sqrt(norm);
    snapAlpha[idx] = a;
    snapDepth[idx] = d;

    snapHead++;
	    snapCount = min(snapCount + 1, MAX_SNAPS);
	    loopActive = true;
	  }

	  void addSnapshot(float[][] field, float a, float d) {
	    addStateSnapshot(field, a, d);
	  }
	  
	void addStateSnapshot(float a, float d) {
  if (combined == null) return;

  addStateSnapshot(combined, a, d);

  int idx = (snapHead - 1 + MAX_SNAPS) % MAX_SNAPS;

  // v2 holonomy seeding (2026-06-12): snapshot phase anchored to CONTROL-SPACE
  // position (alpha, depth) rather than the time-forward Floquet/orbital clocks.
  // Reversing the sweep direction reverses thetaCtl, making the accumulated
  // holonomy gamma orientation-odd — the defining property of a geometric phase.
  // Prior sessions' berry_phase values measured field-phase winding instead and
  // are NOT comparable to v2 values.
  float uCtl = (a - HOLO_ALPHA_CENTER) / max(0.001, HOLO_ALPHA_SPAN);
  float vCtl = (d - HOLO_DEPTH_CENTER) / max(0.001, HOLO_DEPTH_SPAN);
  float thetaCtl = atan2(vCtl, uCtl);
  snaps[idx][0] = sin(thetaCtl);
  snaps[idx][1] = cos(thetaCtl);
  snaps[idx][2]  = envFloquetQuasienergy();
  snaps[idx][3]  = envFloquetCoupling();

  snaps[idx][4] = uCtl;
  snaps[idx][5] = vCtl;

  snaps[idx][6]  = orb_x;
  snaps[idx][7]  = orb_y;
  snaps[idx][8]  = orb_vx;
  snaps[idx][9]  = orb_vy;

  snaps[idx][10] = metricEntropy;
  snaps[idx][11] = metricLyapunov;
  snaps[idx][12] = foundationalCoherence;
  snaps[idx][13] = foundationalCoupling;
}

 void closeSweepLoop() {
  if (snapCount < 4) {
    println("Holonomy: not enough snapshots (" + snapCount + "), need >= 4");
    loopActive = false;
    return;
  }

  // Construct complex representation: real = field values, imag = spatial gradient magnitude.
  // This gives the state vector a phase structure analogous to position-momentum in QM,
  // enabling signed holonomy — the imaginary component tracks field topology change
  // direction, allowing the accumulated phase to wind past zero and go negative.
  // This is the closest real-valued analog to true Berry phase for a classical field.
  float[] snapNormsComplex = new float[MAX_SNAPS];
	  for (int k = 0; k < snapCount; k++) {
	    int idx = (snapHead - snapCount + k + MAX_SNAPS * 2) % MAX_SNAPS;
	    float normSq = 0;
	    for (int i = 0; i < snaps[idx].length; i++) {
	      float w  = phaseWeight(i);
	      float re = snaps[idx][i] * w;
	      float im = ((i % GRID != 0) ? snaps[idx][i] - snaps[idx][i-1] : 0) * w;  // gradient as imag
	      normSq += re*re + im*im;
	    }
    snapNormsComplex[idx] = sqrt(normSq);
  }

  float re = 1.0;
  float im = 0.0;
  float holonomyAccum = 0.0;   // unwrapped: sum of per-step overlap angles
  int n = snapCount;

  for (int k = 0; k < n - 1; k++) {
    int iA = (snapHead - n + k     + MAX_SNAPS * 2) % MAX_SNAPS;
    int iB = (snapHead - n + k + 1 + MAX_SNAPS * 2) % MAX_SNAPS;

	    // Complex inner product: <A|B> = sum(re_A*re_B + im_A*im_B) + i*sum(re_A*im_B - im_A*re_B)
	    float dotRe = 0, dotIm = 0;
	    for (int i = 0; i < snaps[iA].length; i++) {
	      float w   = phaseWeight(i);
	      float reA = snaps[iA][i] * w;
	      float imA = ((i % GRID != 0) ? snaps[iA][i] - snaps[iA][i-1] : 0) * w;
	      float reB = snaps[iB][i] * w;
	      float imB = ((i % GRID != 0) ? snaps[iB][i] - snaps[iB][i-1] : 0) * w;
	      dotRe += reA*reB + imA*imB;
	      dotIm += reA*imB - imA*reB;
    }

    float normA = snapNormsComplex[iA];
    float normB = snapNormsComplex[iB];
    float denom = normA * normB;
    if (denom < 1e-9) continue;

    // Overlap as complex number on unit circle
    float overlapRe = dotRe / denom;
    float overlapIm = dotIm / denom;
    float overlapMag = sqrt(overlapRe*overlapRe + overlapIm*overlapIm);
    if (overlapMag > 1e-9) {
      overlapRe /= overlapMag;
      overlapIm /= overlapMag;

      // Multiply into running product: (re + i*im) * (overlapRe + i*overlapIm)
      float newRe = re * overlapRe - im * overlapIm;
      float newIm = re * overlapIm + im * overlapRe;
      re = newRe;
      im = newIm;
      holonomyAccum += atan2(overlapIm, overlapRe);   // small, unwrapped increment
    }
  }

  // Close the loop
  int iLast  = (snapHead - 1         + MAX_SNAPS * 2) % MAX_SNAPS;
	  int iFirst = (snapHead - snapCount + MAX_SNAPS * 2) % MAX_SNAPS;
	  float dotRe = 0, dotIm = 0;
	  for (int i = 0; i < snaps[iLast].length; i++) {
	    float w   = phaseWeight(i);
	    float reA = snaps[iLast][i] * w;
	    float imA = ((i % GRID != 0) ? snaps[iLast][i] - snaps[iLast][i-1] : 0) * w;
	    float reB = snaps[iFirst][i] * w;
	    float imB = ((i % GRID != 0) ? snaps[iFirst][i] - snaps[iFirst][i-1] : 0) * w;
	    dotRe += reA*reB + imA*imB;
	    dotIm += reA*imB - imA*reB;
  }
  float denomClose = snapNormsComplex[iLast] * snapNormsComplex[iFirst];
  if (denomClose > 1e-9) {
    float oRe = dotRe / denomClose;
    float oIm = dotIm / denomClose;
    float oMag = sqrt(oRe*oRe + oIm*oIm);
    if (oMag > 1e-9) {
      oRe /= oMag;
      oIm /= oMag;
      float newRe = re * oRe - im * oIm;
      float newIm = re * oIm + im * oRe;
      re = newRe;
      im = newIm;
      holonomyAccum += atan2(oIm, oRe);
    }
  }

  float holonomyPrincipal = atan2(im, re);   // principal branch, cross-check only
  holonomyRaw = holonomyAccum;               // UNWRAPPED total — the physics value
  berryPhase  = holonomyRaw / PI;            // may exceed ±1 for large loops
  int windingTurns = round((holonomyAccum - holonomyPrincipal) / TWO_PI);
  holonomyPrincipalRad = holonomyPrincipal;
  holonomyWindingTurns = windingTurns;
  println("[Holonomy] gamma_unwrapped=" + safeNf(holonomyRaw,1,5) + " rad" +
          "  (" + safeNf(holonomyRaw/PI,1,4) + " pi)" +
          "  principal=" + safeNf(holonomyPrincipal,1,5) + " rad" +
          "  winding_turns=" + windingTurns +
          "  |product|=" + safeNf(sqrt(re*re+im*im),1,4) +
          "  (PHASE_WEIGHT=" + safeNf(PHASE_WEIGHT,1,1) + ")");

  println("=== HOLONOMY (complex field) === gamma = " + safeNf(holonomyRaw, 1, 5) +
    " rad (" + safeNf(degrees(holonomyRaw), 1, 2) + " deg, " + windingTurns +
    " turns)  snapshots=" + n + "  re=" + safeNf(re,1,4) + " im=" + safeNf(im,1,4));

  snapCount = 0;
  snapHead  = 0;
  loopActive = false;
}

   
  // Dot product of two flattened field vectors.
  float innerProduct(float[] a, float[] b) {
    float s = 0;
    for (int i = 0; i < a.length; i++) s += a[i] * b[i];
    return s;
  }

  void reset() {
    snapCount    = 0;
    snapHead     = 0;
    loopActive   = false;
    berryPhase   = 0;
    holonomyRaw  = 0;
    holonomyPrincipalRad = 0;
    holonomyWindingTurns = 0;
  }
}

class CriticalSlowingDetector {
  ArrayList<Float> parameterHistory = new ArrayList<Float>();
  ArrayList<Float> responseHistory = new ArrayList<Float>();
  float standardFitChi2 = 0;
  float rdFitChi2 = 0;

  void addSample(float parameter, float response) {
    parameterHistory.add(max(parameter, 0.001));
    responseHistory.add(max(response, 0.001));
    if (parameterHistory.size() > 160) parameterHistory.remove(0);
    if (responseHistory.size() > 160) responseHistory.remove(0);
  }

  float computeCorrelationTime(ArrayList<Float> series) {
    if (series.size() < 20) return 0;
    float mean = 0;
    for (float v : series) mean += v;
    mean /= series.size();
    float c0 = 0, c1 = 0;
    for (int i = 0; i < series.size(); i++) {
      float diff = series.get(i) - mean;
      c0 += diff * diff;
      if (i > 0) c1 += diff * (series.get(i-1) - mean);
    }
    float autocorr = c1 / (c0 + 0.000001);
    if (autocorr > 0 && autocorr < 1) return -1.0 / log(autocorr);
    return 0;
  }


  float fitPowerLaw(ArrayList<Float> x, ArrayList<Float> y) {
    float sumX=0, sumY=0, sumXY=0, sumX2=0;
    int n = min(x.size(), y.size());
    if (n < 3) return 0;
    for (int i=0; i<n; i++) {
      float lx = log(x.get(i) + 0.001);
      float ly = log(y.get(i) + 0.001);
      sumX += lx; sumY += ly; sumXY += lx*ly; sumX2 += lx*lx;
    }
    float b = (n*sumXY - sumX*sumY) / max(0.000001, (n*sumX2 - sumX*sumX));
    float a = (sumY - b*sumX) / n;
    float chi2 = 0;
    for (int i=0; i<n; i++) {
      float predicted = a + b * log(x.get(i) + 0.001);
      chi2 += sq(log(y.get(i) + 0.001) - predicted);
    }
    return chi2;
  }

  float fitRDScaling(ArrayList<Float> x, ArrayList<Float> y) {
    float rdAlpha = 2.0;
    float sumX=0, sumY=0, sumXY=0, sumX2=0;
    int n = min(x.size(), y.size());
    if (n < 3) return 0;
    for (int i=0; i<n; i++) {
      float rx = log(x.get(i) + 0.001) / log(rdAlpha);
      float ly = log(y.get(i) + 0.001);
      sumX += rx; sumY += ly; sumXY += rx*ly; sumX2 += rx*rx;
    }
    float b = (n*sumXY - sumX*sumY) / max(0.000001, (n*sumX2 - sumX*sumX));
    float a = (sumY - b*sumX) / n;
    float chi2 = 0;
    for (int i=0; i<n; i++) {
      float rx = log(x.get(i) + 0.001) / log(rdAlpha);
      float predicted = a + b * rx;
      chi2 += sq(log(y.get(i) + 0.001) - predicted);
    }
    return chi2;
  }
  // In CriticalSlowingDetector:
void compareFits() {
    // Only fit where we have sufficient dynamic range
    if (parameterHistory.size() < 30) return;
    
    // Check if we're in the "trivial" regime where response saturates
    float rMax = -1e9, rMin = 1e9;
    for (float v : responseHistory) { if (v > rMax) rMax = v; if (v < rMin) rMin = v; }
    float responseRange = rMax - rMin;
    if (responseRange < 0.1) {
        // Saturation regime — neither model is valid
        standardFitChi2 = 0;
        rdFitChi2 = 0;
        return;
    }
    
    standardFitChi2 = fitPowerLaw(parameterHistory, responseHistory);
    rdFitChi2 = fitRDScaling(parameterHistory, responseHistory);
    
    // The "catastrophe" is when both fits are bad — indicates phase transition
    if (standardFitChi2 > 100 && rdFitChi2 > 100) {
        metricBreakdownCount++;
        // This is a real physical signal, not a numerical error
        sendBreakdownToSC((standardFitChi2 + rdFitChi2) / 2);
    }
}
}


// ===================================================================== // FIELD CONFIGURATION PANEL  (replaces Spectrum Analyzer) // =====================================================================

void FIELDCONFIG(int val) {
  if (fcPanelOpen && fcPanel != null) {
    fcPanel.setPanelVisible(false);
    fcPanelOpen = false;
    if (btnFieldConfig != null) btnFieldConfig.setLabel("FIELD CFG: OFF");
    statusMsg = "Field Config panel hidden.";
  } else if (fcPanel != null && fcPanel.fcReady) {
    fcPanel.setPanelVisible(true);
    fcPanelOpen = true;
    if (btnFieldConfig != null) btnFieldConfig.setLabel("FIELD CFG: ON");
    statusMsg = "Field Config panel open.";
  } else {
    try {
      String[] args = { "FieldConfigPanel" };
      fcPanel = new FieldConfigPanel();
      PApplet.runSketch(args, fcPanel);
      fcPanelOpen = true;
      if (btnFieldConfig != null) btnFieldConfig.setLabel("FIELD CFG: ON");
      statusMsg = "Field Config panel open.";
    } catch (Exception e) {
      println("Could not open FieldConfigPanel: " + e);
      statusMsg = "Field Config panel failed: " + e.getMessage();
    }
  }
}

void updateElectroGravity() {
  float a   = max(safeAlphaValue(alpha), 1.001);
  float R   = max(depth, 1);
  float r   = sqrt(orb_x * orb_x + orb_y * orb_y);
  float phi = orbResolutionField(r);

  // Mass proxy: normalised orbital radius — tighter orbit = heavier coupling
  float massProxy = constrain(1.0 - (r / ORB_BOUND), 0, 1) * orb_M;

  // Emergent factor from field configuration
  float fieldFactor = (float)Math.pow(a, orb_gamma * phi);
  float depthDamp   = 1.0 / (1.0 + (R - 1) * massProxy * 0.08);
  emergentEG = constrain(fieldFactor * depthDamp, 0.2, 1.0);

  // Voltage perturbation — only active when panel is open and enabled
  float coupling = 0.015;
  float voltage  = 0.0;
  if (fcPanel != null && fcPanel.fcReady && fcPanel.egEnabled) {
    coupling = fcPanel.egCouplingStrength;
    voltage  = fcPanel.egInjectedVoltage;
  }

  float injectionEffect = coupling * voltage;
  float solarBoost      = 0.0;
  if (solarBridge != null) {
    solarBoost = (solarBridge.xrayNorm + solarBridge.windNorm) * 0.012;
  }
  effectiveVoltage = voltage
    + (1.0 - emergentEG) * 100.0 * coupling
    + solarBoost * 100;

  electroGravityFactor = constrain(
    emergentEG - injectionEffect - solarBoost,
    0.2, 1.0
  );

  // Floquet INJECTING suppression: full coupling is the strongest EG-lift window.
  if (fsLifecycleState == 3 && fsCouplingEnvelope > 0.1) {
    float suppressionDepth = 0.70 * fsCouplingEnvelope;
    electroGravityFactor = constrain(
      electroGravityFactor * (1.0 - suppressionDepth),
      0.05, 1.0
    );
  }

  // Change 3 — UFO mode electrogravitic amplification.
  // In UFO mode the Floquet holding strength actively reduces effective
  // gravity beyond the baseline emergent reduction. High fsHoldingStrength
  // means the drone is locked in a stable well — that coherent state is
  // precisely when electrogravitic lift should be strongest.
  // ufoTransition scales the effect: disc=0 (no amplification), jellyfish=1
  // (full lift). Floor at 0.05 keeps orbital integration stable.
  if (fcPanel != null && fcPanel.fcReady && fcPanel.ufoModeOn) {
    float ufoAmp = fcPanel.ufoTransition * 0.35;
    electroGravityFactor = constrain(
      electroGravityFactor - ufoAmp * fsHoldingStrength,
      0.05, 1.0
    );
  }

  egProbeBaseFactor = electroGravityFactor;
  updateEGProbe(r);
}

float egProbeAgeScore(float ageSeconds) {
  if (ageSeconds < 0 || Float.isNaN(ageSeconds) || Float.isInfinite(ageSeconds)) return 0.0;
  return constrain(exp(-ageSeconds / 5.0), 0, 1);
}

boolean scFeedbackFresh() {
  return millis() - lastSCHeartbeatMs < 8000;
}

void updateEGProbe(float orbitalRadius) {
  boolean enabled = (toggleEGProbe == null || toggleEGProbe.getState());
  int now = millis();

  float radiusScore = constrain((1.35 - orbitalRadius) / 0.95, 0, 1);
  float lockScore = constrain(fsLockScoreRaw, 0, 1);
  float lyapScore = constrain(1.0 - metricLyapunov / 1.8, 0, 1);
  float ecoScore = max(
    max(egProbeAgeScore(audioDiagEcoChirpLastAge), egProbeAgeScore(audioDiagEcoCallLastAge)),
    max(egProbeAgeScore(audioDiagEcoGrowthLastAge), egProbeAgeScore(audioDiagEcoFissureLastAge))
  );
  float galaxyScore = galaxyLoaded ? constrain(galaxyBlend * galaxyBoundaryPersist, 0, 1) : 0.0;

  egProbeGateScore = constrain(
    radiusScore * 0.38
    + lockScore * 0.32
    + lyapScore * 0.14
    + ecoScore * 0.10
    + galaxyScore * 0.06,
    0, 1
  );

  egProbeCooldownRemaining = max(0, (EG_PROBE_COOLDOWN_MS - (now - egProbeLastTriggerMs)) / 1000.0);
  boolean cooled = egProbeCooldownRemaining <= 0.0;
  boolean fieldIsStableEnough = metricLyapunov < 2.4 && orbitalRadius < 1.55;
  boolean scAllowsProbe = !scFeedbackFresh() || (scSaturation < 0.55 && scDroneAlive && electroGravityFactor < 0.40);

  if (!enabled) {
    egProbeActive = false;
  } else if (!egProbeActive && cooled && fieldIsStableEnough && scAllowsProbe && egProbeGateScore >= EG_PROBE_GATE_THRESHOLD) {
    egProbeActive = true;
    egProbeEnterMs = now;
    egProbeLastTriggerMs = now;
    egProbeTriggerCount++;
  } else if (egProbeActive) {
    boolean holdExpired = (now - egProbeEnterMs) > EG_PROBE_HOLD_MS;
    if (holdExpired || !fieldIsStableEnough) egProbeActive = false;
  }

  float requestedLevel = enabled ? getSliderValueSafe("egProbeLevel", 0.82) : 0.0;
  float targetDepth = egProbeActive ? constrain(requestedLevel, 0, 1) : 0.0;
  float slew = egProbeActive ? 0.045 : 0.035;
  egProbeDepth = lerp(egProbeDepth, targetDepth, slew);
  if (egProbeDepth < 0.001) egProbeDepth = 0.0;

  egProbeTarget = lerp(0.88, 0.24, egProbeDepth);
  if (egProbeDepth > 0.0) {
    electroGravityFactor = min(electroGravityFactor, egProbeTarget);
    effectiveVoltage += egProbeDepth * 70.0;
  }
}

// =====================================================================
// SNIP F — syncFieldConfigPanel()
// =====================================================================

void syncFieldConfigPanel() {
  if (fcPanel == null || !fcPanel.fcReady) return;

  float sXray   = (solarBridge != null) ? solarBridge.xrayNorm : 0;
  float sWind   = (solarBridge != null) ? solarBridge.windNorm : 0;
  float sKp     = (solarBridge != null) ? solarBridge.kpNorm   : 0;
  boolean sLive = (solarBridge != null) && solarBridge.isLive();
  float r_o     = sqrt(orb_x * orb_x + orb_y * orb_y);

  fcPanel.syncState(
    safeAlphaValue(alpha), (float)depth, orb_M, r_o,
    orbitLockStrength, foundationalCoherence, metricLyapunov,
    sXray, sWind, sKp, sLive,
    emergentEG, effectiveVoltage
  );

  // Push Beltrami alignment so the panel can display field-line threading status
  fcPanel.syncBeltrami(beltramiAlignment);

  // Push holographic surface state so the panel shows boundary physics
  fcPanel.syncLandauer(landauerS, landauerCoherence, surfaceCurv, surfaceReady);

  if (fcPanel.ufoModeOn) {
    float targetAlpha = lerp(4.5, 1.1, fcPanel.ufoTransition);
    float targetDepth = lerp(2,   7,   fcPanel.ufoTransition);
    alpha = lerp(alpha, targetAlpha, 0.015);
    depth = round(lerp(depth, targetDepth, 0.015));
    if (sliderAlpha != null) sliderAlpha.setValue(alpha);
    if (sliderDepth != null) sliderDepth.setValue(depth);

    // Change 2 — Solar influence on orb_gamma in UFO mode.
    // In field mode gamma is a static slider. In UFO mode solar activity
    // (Kp index = geomagnetic disturbance, xray = solar flux) drives gamma
    // more negative, tightening orbital coupling so the orbital threads the
    // field's own curvature lines rather than drifting between basins.
    // Kp and xray are weighted to bias toward the macro field reference
    // (sun as large-scale stable differentiation). Rate 0.008 keeps it slow.
    if (solarAffectsSynth && solarBridge != null) {
      float solarGammaBias = (solarBridge.kpNorm * 0.18 + solarBridge.xrayNorm * 0.10)
          * fcPanel.ufoTransition;
      float targetGamma = lerp(-0.5, -0.9, solarGammaBias);
      orb_gamma = lerp(orb_gamma, targetGamma, 0.008);
      if (sliderGamma != null) sliderGamma.setValue(orb_gamma);
    }
  }
}


// updateElectroGravity() is defined above (clean version).
// Duplicate removed — was a malformed run-on block causing syntax errors.



void dispose() {
  // Processing 4-safe cleanup hook. Do not call super.stop(); stop() is not available
  // in this single-window build and caused compile errors after popup removal.
  shutdownMidiPilot();
  if (oscLogWriter != null) {
    oscLogWriter.flush();
    oscLogWriter.close();
    oscLogWriter = null;
  }
}

// ========== HELPER FUNCTIONS ==========
float getAverageValue(float[][] d) {
  float s = 0;
  int n = 0;
  for (float[] r : d) {
    for (float v : r) {
      s += v;
      n++;
    }
  }
  return n > 0 ? constrain(s / n, 0, 1) : 0;
}

float getMaxValue(float[][] d) {
  float m = 0;
  for (float[] r : d) {
    for (float v : r) {
      if (v > m) m = v;
    }
  }
  return constrain(m, 0, 1);
}

float getFinestScaleValue(float[][] d) {
  float s = 0;
  int n = 0;
  for (int r = 1; r < d.length - 1; r++) {
    for (int c = 1; c < d[r].length - 1; c++) {
      s += abs(d[r][c] - d[r][c - 1]) + abs(d[r][c] - d[r - 1][c]);
      n++;
    }
  }
  return n > 0 ? constrain(s / n * 8, 0, 1) : 0;
}

float getDominantLayerValue() {
  if (dominant == null) return 0;
  float s = 0;
  int n = 0;
  for (float[] r : dominant) {
    for (float v : r) {
      s += v;
      n++;
    }
  }
  return n > 0 ? constrain(s / n, 0, 1) : 0;
}


// ============================================================
// EMBEDDED CORE / LEGACY COMPATIBILITY CLASSES
// These classes are included directly in the main tab so Processing
// can find the legacy class names, but launch() is disabled and no windows are opened.
// ============================================================

// ────────────────────────────────────────────────────────────────
// Specialized Recursive Nodes Visualizer
// 2x2 embedded-window-legacy for Floquet / Berry-Holonomy / Fractal-Lyapunov / Info-Energy nodes.
// This window is intentionally lightweight: it receives already-computed metrics
// from the main Processing loop and renders them as conceptual readouts instead
// of recomputing the full RDF field.  That keeps the adiabatic sweep smoother.
// ────────────────────────────────────────────────────────────────
class RDFSpecializedNodesWindow {
  // Wide/short layout for smaller secondary displays.
  // The original square-ish 2x2 embedded-window-legacy could open taller than the monitor,
  // hiding the title bar.  This rectangle keeps the same 2x2 conceptual grid
  // while reducing height and increasing width.
  final int PW = 420;
  final int PH = 175;
  final int GAP = 14;
  final int M = 14;
  final int HEADER_H = 52;
  final int WN = M * 2 + PW * 2 + GAP;
  final int HN = HEADER_H + PH * 2 + GAP + M;

  // Software window position used for drag-anywhere movement.
  int winX = 70;
  int winY = 70;

  float berry = 0;
  float adiabatic = 0;
  float fractal = 1;
  float lyapunov = 0;
  float mutualInfo = 0;
  float kl = 0;
  float entropy = 0;
  float floquetPhase = 0;
  float quasienergy = 0;
  float coupling = 0;
  float corrTau = 0;
  int breakdowns = 0;
  float nodeAlpha = 2;
  int nodeDepth = 6;
  float orbitalSpeed = 0;
  float orbitalPhi = 0;

  float[] entropyTrace = new float[180];
  float[] klTrace = new float[180];
  float[] lyapTrace = new float[180];
  float[] miTrace = new float[180];
  int traceHead = 0;
  int frameTick = 0;
  int lastTraceMillis = 0;
  final int TRACE_UPDATE_MS = 80;

  RDFSpecializedNodesWindow() { }
  // Compatibility constructors intentionally removed: no window lifecycle.

  void launch() {
    // Disabled in embedded-only build to prevent extra X11/JOGL display contexts.
  }

  public void settings() {
    // Secondary-window size is applied in setup with surface.setSize().
  }

  public void setup() {
    // Legacy setup retained only for compatibility; no secondary surface exists.
    colorMode(RGB, 255);
    textFont(createFont("Monospaced", 12));
    for (int i = 0; i < entropyTrace.length; i++) {
      entropyTrace[i] = 0;
      klTrace[i] = 0;
      lyapTrace[i] = 0;
      miTrace[i] = 0;
    }
  }

  void syncNodes(float b, float a, float fd, float ly, float mi, float kld, float ent,
                 float fp, float qe, float fc, float tau, int br, float al, int dep,
                 float spd, float phi) {
    berry = b;
    adiabatic = a;
    fractal = fd;
    lyapunov = ly;
    mutualInfo = mi;
    kl = kld;
    entropy = ent;
    floquetPhase = fp;
    quasienergy = qe;
    coupling = fc;
    corrTau = tau;
    breakdowns = br;
    nodeAlpha = al;
    nodeDepth = dep;
    orbitalSpeed = spd;
    orbitalPhi = phi;

    // Trace arrays are intentionally throttled. Updating them on every main-frame sync
    // caused extra garbage and redraw pressure on Raspberry Pi class hardware.
    if (millis() - lastTraceMillis >= TRACE_UPDATE_MS) {
      entropyTrace[traceHead] = constrain(entropy / max(0.001, log(max(2, nodeDepth + 1)) / log(2)), 0, 1);
      klTrace[traceHead] = constrain(kl * 2.0, 0, 1);
      lyapTrace[traceHead] = constrain(abs(lyapunov) * 0.75, 0, 1);
      miTrace[traceHead] = constrain(mutualInfo / 2.0, 0, 1);
      traceHead = (traceHead + 1) % entropyTrace.length;
      lastTraceMillis = millis();
    }
  }

  public void draw() {
    background(10, 12, 18);
    frameTick++;
    drawHeader();
    int topY = HEADER_H;
    drawBerryHolonomy(M, topY, PW, PH);
    drawFloquetDrive(M + PW + GAP, topY, PW, PH);
    drawFractalLyapunov(M, topY + PH + GAP, PW, PH);
    drawInfoEnergy(M + PW + GAP, topY + PH + GAP, PW, PH);
  }

  public void mouseDragged() {
    // Dragging disabled: embedded single-window build has no secondary surface.
  }

  void drawHeader() {
    fill(210, 240, 245);
    textAlign(LEFT, TOP);
    textSize(15);
    text("RDFT SPECIALIZED NODES VISUALIZER", M, 9);
    textSize(10);
    fill(140, 170, 180);
    text("wide/short 2x2 readout  |  drag anywhere to reposition", M, 31);
  }

  void panel(int x, int y, int w, int h, String title) {
    noStroke();
    fill(18, 22, 30);
    rect(x, y, w, h, 12);
    stroke(60, 90, 110);
    noFill();
    rect(x, y, w, h, 12);
    fill(210, 230, 240);
    textSize(12);
    textAlign(LEFT, TOP);
    text(title, x + 12, y + 10);
  }

  void drawBerryHolonomy(int x, int y, int w, int h) {
    panel(x, y, w, h, "BERRY PHASE + RECURSIVE HOLONOMY");
    float cx = x + w * 0.62;
    float cy = y + h * 0.55;
    float r = min(w, h) * 0.22;
    noFill();
    stroke(40, 80, 100);
    ellipse(cx, cy, r * 2, r * 2);

    // Recursive loop path: polar/Lissajous morph whose closure quality is interpreted as holonomy.
    beginShape();
    stroke(80, 210, 230);
    noFill();
    int lobes = 2 + int(nodeDepth) % 5;
    float disorder = constrain(entropy / max(1.0, log(max(2, nodeDepth + 1)) / log(2)), 0, 1);
    for (int i = 0; i < 160; i++) {
      float t = TWO_PI * i / 160.0;
      float rr = r * (0.62 + 0.18 * sin(t * lobes + berry * TWO_PI) + 0.13 * sin((lobes+2)*t + kl*2.0));
      float px = cx + cos(t + berry * TWO_PI + frameTick*0.006) * rr + sin(t*2.0 + mutualInfo) * r * 0.10;
      float py = cy + sin(t - adiabatic * 0.15) * rr * (0.86 + disorder*0.22) + cos(t*3.0 + lyapunov) * r * 0.08;
      vertex(px, py);
    }
    endShape(CLOSE);

    fill(255, 160, 80);
    noStroke();
    float dotAng = berry * TWO_PI + frameTick * 0.012;
    ellipse(cx + cos(dotAng) * r, cy + sin(dotAng) * r, 9, 9);

    readout(x + w * 0.68, y + 36, "berry", berry, -1, 1);
    readout(x + w * 0.68, y + 62, "adiab", adiabatic, 0, 2);
    readout(x + w * 0.68, y + 88, "tau", corrTau, 0, 8);
    fill(160, 190, 200);
    text("breakdowns: " + breakdowns, x + w * 0.68, y + 122);
  }

  void drawFloquetDrive(int x, int y, int w, int h) {
    panel(x, y, w, h, "FLOQUET TEMPORAL DRIVING");
    float mid = y + h * 0.48;
    stroke(50, 90, 120);
    line(x + 20, mid, x + w - 20, mid);
    noFill();
    stroke(90, 190, 255);
    beginShape();
    for (int i = 0; i < w - 40; i++) {
      float t = i * 0.055 + floquetPhase;
      float amp = 24 + 44 * constrain(coupling, 0, 1);
      vertex(x + 20 + i, mid + sin(t) * amp);
    }
    endShape();

    float cx = x + w - 72;
    float cy = y + 72;
    float rr = 36;
    noFill();
    stroke(60, 110, 130);
    ellipse(cx, cy, rr * 2, rr * 2);
    stroke(255, 170, 80);
    line(cx, cy, cx + cos(floquetPhase) * rr, cy + sin(floquetPhase) * rr);
    fill(255, 170, 80);
    noStroke();
    ellipse(cx + cos(floquetPhase) * rr, cy + sin(floquetPhase) * rr, 7, 7);

    readout(x + 18, y + 118, "phase", floquetPhase % TWO_PI, 0, TWO_PI);
    readout(x + 150, y + 118, "quasiE", quasienergy, 0, 2);
    readout(x + 282, y + 118, "couple", coupling, 0, 1);
  }

  void drawFractalLyapunov(int x, int y, int w, int h) {
    panel(x, y, w, h, "FRACTAL DIMENSION + LYAPUNOV GROWTH");
    pushMatrix();
    translate(x + w * 0.30, y + h - 24);
    stroke(120, 240, 170, 190);
    float fdNorm = constrain((fractal - 1.0) / 1.4, 0, 1);
    int branches = 4 + int(fdNorm * 5);
    float angle = 0.28 + fdNorm * 0.35 + constrain(abs(lyapunov), 0, 1) * 0.08;
    drawBranch(48, branches, angle);
    popMatrix();

    // Lyapunov trace as a spectrum analyzer.
    int tx = x + int(w * 0.58);
    int ty = y + 42;
    int tw = int(w * 0.36);
    int th = 82;
    stroke(45, 75, 85);
    noFill();
    rect(tx, ty, tw, th);
    noStroke();
    for (int i = 0; i < tw; i += 5) {
      int idx = (traceHead + i * lyapTrace.length / max(1, tw)) % lyapTrace.length;
      float v = lyapTrace[idx];
      fill(255, 120 + 90 * v, 80, 190);
      rect(tx + i, ty + th - v * th, 4, v * th);
    }
    readout(x + w * 0.58, y + 132, "fracD", fractal, 0, 2.5);
    readout(x + w * 0.58, y + 154, "lyap", lyapunov, -2, 2);
  }

  void drawInfoEnergy(int x, int y, int w, int h) {
    panel(x, y, w, h, "INFORMATION + QUASI-ENERGY CRT READOUT");
    int gx = x + 20;
    int gy = y + 42;
    int gw = w - 40;
    int gh = 82;
    fill(6, 18, 18);
    stroke(40, 95, 80);
    rect(gx, gy, gw, gh, 4);

    // CRT scanlines
    stroke(20, 60, 50, 110);
    for (int yy = gy + 4; yy < gy + gh; yy += 6) line(gx + 2, yy, gx + gw - 2, yy);

    drawTrace(entropyTrace, gx, gy, gw, gh, color(90, 255, 180));
    drawTrace(klTrace, gx, gy, gw, gh, color(255, 160, 70));
    drawTrace(miTrace, gx, gy, gw, gh, color(120, 170, 255));

    int by = y + 134;
    readout(x + 20, by, "entropy", entropy, 0, 4);
    readout(x + 154, by, "MI", mutualInfo, 0, 2);
    readout(x + 286, by, "KL", kl, 0, 1);
  }

  void drawBranch(float len, int depthLeft, float ang) {
    if (depthLeft <= 0 || len < 4) return;
    line(0, 0, 0, -len);
    translate(0, -len);
    pushMatrix();
    rotate(ang + 0.08 * sin(frameTick * 0.018 + lyapunov));
    drawBranch(len * 0.68, depthLeft - 1, ang);
    popMatrix();
    pushMatrix();
    rotate(-ang + 0.06 * cos(frameTick * 0.02 + fractal));
    drawBranch(len * 0.66, depthLeft - 1, ang);
    popMatrix();
    if (depthLeft % 2 == 0 && fractal > 1.25) {
      pushMatrix();
      rotate(0.12 * sin(frameTick * 0.01));
      drawBranch(len * 0.45, depthLeft - 2, ang * 0.8);
      popMatrix();
    }
  }

  void drawTrace(float[] arr, int x, int y, int w, int h, color c) {
    stroke(c);
    noFill();
    beginShape();
    for (int i = 0; i < w; i++) {
      int idx = (traceHead + i * arr.length / max(1, w)) % arr.length;
      float v = constrain(arr[idx], 0, 1);
      vertex(x + i, y + h - v * h);
    }
    endShape();
  }

  void readout(float x, float y, String label, float value, float lo, float hi) {
    fill(155, 185, 195);
    textAlign(LEFT, TOP);
    textSize(10);
    text(label + " " + safeNf(value, 1, 3), x, y);
    float bw = 82;
    float bh = 6;
    float n = constrain((value - lo) / max(0.0001, hi - lo), 0, 1);
    noStroke();
    fill(32, 45, 52);
    rect(x, y + 15, bw, bh);
    fill(90 + 120 * n, 210, 180);
    rect(x, y + 15, bw * n, bh);
  }
}

// ────────────────────────────────────────────────────────────────
// Material / Topology Glyph Visualizer
// Lightweight procedural lattice window inspired by brachistochrone-based TPMS
// lattice design, fractal dimension, and volume/surface structural signatures.
// It deliberately avoids heavy 3D mesh or FEA.  Instead, it renders compact
// 2D glyphs that sonically/visually complement RDFT: geometry as recursive
// distinction structure across material resolution layers.
// ────────────────────────────────────────────────────────────────
class RDFMaterialTopologyWindow {
  final int PW = 430;
  final int PH = 180;
  final int GAP = 14;
  final int M = 14;
  final int HEADER_H = 54;
  final int WN = M * 2 + PW * 2 + GAP;
  final int HN = HEADER_H + PH * 2 + GAP + M;

  int winX = 120;
  int winY = 90;

  float fractalDim = 1.0;
  float entropy = 0;
  float lyapunov = 0;
  float kl = 0;
  float mutualInfo = 0;
  float quasiEnergy = 0;
  float floquetCoupling = 0;
  float nodeAlpha = 2.0;
  int nodeDepth = 6;
  float orbitalSpeed = 0;
  float orbitalPhi = 0;
  int modeIndex = 0;
  int tick = 0;

  float[] structureTrace = new float[160];
  float[] energyTrace = new float[160];
  int traceHead = 0;
  int lastTraceMillis = 0;

  String[] latticeNames = {"B-GYROID", "B-DIAMOND", "B-IWP", "B-BCC", "BRACHISTO"};

  RDFMaterialTopologyWindow() { }
  // Compatibility constructors intentionally removed: no window lifecycle.

  void launch() {
    // Disabled in embedded-only build to prevent extra X11/JOGL display contexts.
  }

  public void settings() {
    // Secondary-window size is applied in setup with surface.setSize().
  }

  public void setup() {
    // Legacy setup retained only for compatibility; no secondary surface exists.
    colorMode(RGB, 255);
    textFont(createFont("Monospaced", 12));
    for (int i = 0; i < structureTrace.length; i++) {
      structureTrace[i] = 0;
      energyTrace[i] = 0;
    }
  }

  void syncMaterialTopology(float fd, float ent, float ly, float kld, float mi, float qe, float fc,
                            float al, int dep, float spd, float phi, int mode) {
    fractalDim = fd;
    entropy = ent;
    lyapunov = ly;
    kl = kld;
    mutualInfo = mi;
    quasiEnergy = qe;
    floquetCoupling = fc;
    nodeAlpha = al;
    nodeDepth = dep;
    orbitalSpeed = spd;
    orbitalPhi = phi;
    modeIndex = mode;

    if (millis() - lastTraceMillis > 95) {
      structureTrace[traceHead] = constrain((fractalDim - 0.8) / 1.7, 0, 1);
      energyTrace[traceHead] = constrain((quasiEnergy * 0.6 + kl * 5.0 + abs(lyapunov) * 0.35), 0, 1);
      traceHead = (traceHead + 1) % structureTrace.length;
      lastTraceMillis = millis();
    }
  }

  public void draw() {
    tick++;
    background(8, 10, 14);
    drawHeader();
    int topY = HEADER_H;
    drawBrachistochroneLattice(M, topY, PW, PH);
    drawTPMSGlyphs(M + PW + GAP, topY, PW, PH);
    drawScaleSignature(M, topY + PH + GAP, PW, PH);
    drawMaterialResponse(M + PW + GAP, topY + PH + GAP, PW, PH);
  }

  public void mouseDragged() {
    // Dragging disabled: embedded single-window build has no secondary surface.
  }

  void drawHeader() {
    fill(225, 240, 225);
    textAlign(LEFT, TOP);
    textSize(15);
    text("RDFT MATERIAL / TOPOLOGY GLYPH VIEWER", M, 8);
    fill(145, 170, 150);
    textSize(10);
    text("Brachistochrone lattice glyphs | fractal D | V/A signature | energy absorption mapping | drag anywhere", M, 31);
  }

  void panel(int x, int y, int w, int h, String title) {
    noStroke();
    fill(17, 21, 24);
    rect(x, y, w, h, 12);
    stroke(60, 95, 75);
    noFill();
    rect(x, y, w, h, 12);
    fill(215, 235, 215);
    textSize(12);
    textAlign(LEFT, TOP);
    text(title, x + 12, y + 10);
  }

  // Fifth-order sine fit from the brachistochrone-lattice paper.
  float bsin(float x) {
    return 1.104 * sin(x) + 0.01263 * sin(2 * x) + 0.1408 * sin(3 * x) +
           0.0122 * sin(4 * x) + 0.06373 * sin(5 * x);
  }

  float bcos(float x) {
    float xx = x + HALF_PI;
    return 1.104 * sin(xx) + 0.01263 * sin(2 * xx) + 0.1408 * sin(3 * xx) +
           0.0122 * sin(4 * xx) + 0.06373 * sin(5 * xx);
  }

  void drawBrachistochroneLattice(int x, int y, int w, int h) {
    panel(x, y, w, h, "BRACHISTOCHRONE LATTICE FIELD");
    float fdNorm = constrain((fractalDim - 1.0) / 1.5, 0, 1);
    int rows = 5 + int(fdNorm * 5);
    float amp = 16 + 24 * constrain(floquetCoupling, 0, 1);
    float speed = tick * 0.018 + orbitalPhi * TWO_PI;
    strokeWeight(1.2);
    for (int r = 0; r < rows; r++) {
      float yy = y + 45 + r * ((h - 72) / max(1.0, rows - 1));
      float phase = r * 0.75 + speed;
      stroke(70 + r * 12, 210, 140, 170);
      noFill();
      beginShape();
      for (int i = 0; i < w - 36; i += 4) {
        float t = map(i, 0, w - 36, -PI, PI);
        float curve = bsin(t * (1.0 + nodeDepth * 0.08) + phase);
        vertex(x + 18 + i, yy + curve * amp * 0.35);
      }
      endShape();
    }
    // mirrored return curves suggest the cycloid reflection used for periodic lattice generation.
    stroke(255, 170, 80, 150);
    for (int c = 0; c < 7; c++) {
      float xx = x + 28 + c * (w - 56) / 6.0;
      line(xx, y + 42, xx + bcos(c + tick * 0.015) * 18, y + h - 24);
    }
    readout(x + 18, y + h - 36, "alpha", nodeAlpha, 1, 4.5, 80);
    readout(x + 140, y + h - 36, "depth", nodeDepth, 0, 8, 80);
    readout(x + 262, y + h - 36, "couple", floquetCoupling, 0, 1, 80);
  }

  void drawTPMSGlyphs(int x, int y, int w, int h) {
    panel(x, y, w, h, "TPMS MATERIAL TOPOLOGY GLYPHS");
    int active = constrain((modeIndex + int(nodeDepth) + int(fractalDim * 2)) % latticeNames.length, 0, latticeNames.length - 1);
    int cols = 5;
    float cellW = (w - 34) / cols;
    for (int i = 0; i < cols; i++) {
      float cx = x + 17 + cellW * (i + 0.5);
      float cy = y + 94;
      float rad = 32 + 10 * (i == active ? 1 : 0);
      drawTPMSIcon(cx, cy, rad, i, i == active);
      fill(i == active ? color(235, 255, 180) : color(145, 165, 150));
      textAlign(CENTER, TOP);
      textSize(9);
      text(latticeNames[i], cx, y + h - 38);
    }
    fill(150, 175, 155);
    textAlign(LEFT, TOP);
    textSize(10);
    text("blue/green = surface pathway   orange = high absorption / flexible response", x + 14, y + h - 18);
  }

  void drawTPMSIcon(float cx, float cy, float r, int type, boolean active) {
    pushMatrix();
    translate(cx, cy);
    float t0 = tick * 0.018;
    strokeWeight(active ? 2.0 : 1.1);
    noFill();
    int strands = type == 4 ? 3 : 4;
    for (int s = 0; s < strands; s++) {
      beginShape();
      stroke(active ? color(110, 240, 170, 220) : color(80, 140, 120, 150));
      for (int i = 0; i <= 90; i++) {
        float a = TWO_PI * i / 90.0;
        float rr = r * 0.65;
        float vx = 0;
        float vy = 0;
        if (type == 0) { // gyroid-like flowing triply periodic crossings
          vx = cos(a + s * HALF_PI) * rr + sin(2 * a + t0) * r * 0.18;
          vy = sin(a * 1.35 + s) * rr * 0.72;
        } else if (type == 1) { // diamond-like crystalline diagonals
          vx = cos(a + s * HALF_PI) * rr;
          vy = sin(a + s * HALF_PI) * rr;
          if (i % 18 < 9) vx *= 0.65;
        } else if (type == 2) { // IWP-like interlocking walls
          vx = cos(a * 2 + s) * rr * 0.75;
          vy = sin(a + s * HALF_PI) * rr;
        } else if (type == 3) { // BCC node-centered network
          vx = cos(a + s * TWO_PI / 4.0) * rr * (0.7 + 0.25 * sin(3 * a));
          vy = sin(a + s * TWO_PI / 4.0) * rr * (0.7 + 0.25 * cos(3 * a));
        } else { // brachistochrone waveform cell
          vx = map(i, 0, 90, -rr, rr);
          vy = bsin(map(i, 0, 90, -PI, PI) + s * 0.8 + t0) * r * 0.32 + (s - 1) * 12;
        }
        vertex(vx, vy);
      }
      endShape();
    }
    if (active) {
      noStroke();
      fill(255, 155, 70, 190);
      ellipse(cos(t0 * 2) * r * 0.5, sin(t0 * 1.4) * r * 0.35, 8, 8);
    }
    popMatrix();
  }

  void drawScaleSignature(int x, int y, int w, int h) {
    panel(x, y, w, h, "FRACTAL / VOLUME-SURFACE SIGNATURE");
    int gx = x + 18;
    int gy = y + 45;
    int gw = w - 36;
    int gh = 62;
    noStroke();
    fill(5, 16, 14);
    rect(gx, gy, gw, gh, 4);
    for (int i = 0; i < gw; i += 5) {
      int idx = (traceHead + i * structureTrace.length / max(1, gw)) % structureTrace.length;
      float v = structureTrace[idx];
      fill(70 + 120 * v, 160 + 80 * v, 100, 190);
      rect(gx + i, gy + gh - v * gh, 4, v * gh);
    }
    stroke(30, 65, 50, 130);
    for (int yy = gy; yy <= gy + gh; yy += 8) line(gx, yy, gx + gw, yy);

    float fdNorm = constrain((fractalDim - 1.0) / 1.5, 0, 1);
    float vaProxy = constrain(1.0 / (1.0 + fdNorm * 2.8 + entropy * 0.12), 0, 1);
    float surfaceProxy = constrain(fdNorm * 0.65 + entropy * 0.08 + nodeDepth * 0.04, 0, 1);
    readout(x + 20, y + 123, "Df", fractalDim, 0, 3, 80);
    readout(x + 140, y + 123, "V/A", vaProxy, 0, 1, 80);
    readout(x + 260, y + 123, "surface", surfaceProxy, 0, 1, 92);
    fill(150, 175, 155);
    textSize(9);
    textAlign(LEFT, TOP);
    text("compact descriptor: high Df / high surface = finer distinction capacity", x + 18, y + h - 18);
  }

  void drawMaterialResponse(int x, int y, int w, int h) {
    panel(x, y, w, h, "MATERIAL RESPONSE / ENERGY ABSORPTION MAP");
    float stiffness = constrain(0.55 + mutualInfo * 0.22 - kl * 1.2 + floquetCoupling * 0.18, 0, 1);
    float absorption = constrain(0.25 + abs(lyapunov) * 0.28 + entropy * 0.11 + quasiEnergy * 0.18, 0, 1);
    float flexibility = constrain(1.0 - stiffness * 0.65 + absorption * 0.25, 0, 1);

    int ax = x + 24;
    int ay = y + 48;
    int aw = w - 50;
    int ah = 78;
    stroke(40, 80, 60);
    fill(8, 18, 14);
    rect(ax, ay, aw, ah, 4);
    drawResponseTrace(energyTrace, ax, ay, aw, ah);

    // material position dot: x = stiffness, y = absorption/flexibility
    float px = ax + stiffness * aw;
    float py = ay + ah - absorption * ah;
    stroke(255, 165, 80, 190);
    line(px, ay, px, ay + ah);
    line(ax, py, ax + aw, py);
    noStroke();
    fill(255, 170, 70);
    ellipse(px, py, 11, 11);

    readout(x + 20, y + 136, "stiff", stiffness, 0, 1, 72);
    readout(x + 125, y + 136, "absorb", absorption, 0, 1, 72);
    readout(x + 230, y + 136, "flex", flexibility, 0, 1, 72);
    fill(150, 175, 155);
    textAlign(LEFT, TOP);
    textSize(9);
    text("B-gyroid interpretation: softer response, higher energy absorption", x + 20, y + h - 17);
  }

  void drawResponseTrace(float[] arr, int x, int y, int w, int h) {
    noFill();
    stroke(95, 210, 135);
    beginShape();
    for (int i = 0; i < w; i++) {
      int idx = (traceHead + i * arr.length / max(1, w)) % arr.length;
      float v = constrain(arr[idx], 0, 1);
      vertex(x + i, y + h - v * h);
    }
    endShape();
  }

  void readout(float x, float y, String label, float value, float lo, float hi, float bw) {
    fill(155, 185, 160);
    textAlign(LEFT, TOP);
    textSize(10);
    text(label + " " + safeNf(value, 1, 3), x, y);
    float n = constrain((value - lo) / max(0.0001, hi - lo), 0, 1);
    noStroke();
    fill(30, 42, 34);
    rect(x, y + 15, bw, 6);
    fill(100 + 90 * n, 220, 130);
    rect(x, y + 15, bw * n, 6);
  }
}
