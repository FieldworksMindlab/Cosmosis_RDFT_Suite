/**
 * FloquetShaperEngine.pde
 *
 * Tab in HOLO_DRIVE_RDFT_EG_SYNTH sketch folder.
 *
 * THEORETICAL BASIS
 * =================
 * Castro et al. 2023 (New J. Phys. 25 043023) — Floquet engineering with
 * quantum optimal control theory.
 *
 * The RDFT field has intrinsic topological features: dominant-layer boundaries,
 * orbital trajectories, phase gradients, Berry holonomy. These are the system's
 * natural Floquet modes |u_α(t)⟩ with associated quasi-energies ε_α.
 *
 * Direct injection of external data (ocean, solar) into a drone synth fails
 * because those signals are NOT natural modes of the field — they cause
 * phase slippage, buffer overruns, and progressive crackling (non-stationary
 * aliasing).
 *
 * SOLUTION: Use Floquet optimal control to find a periodic drive g(t) whose
 * Fourier coefficients ν = [a₁,b₁,a₂,b₂,...,aₙ,bₙ] maximise a target
 * function G(ν) defined in terms of the field's own Floquet observables
 * (coupling κ, quasi-energy ε, coherence, orbital phase).
 *
 * This drive is already a natural mode of the field. It creates a potential
 * well (the "orb") that the drone can sit inside stably. External data
 * (ocean, solar) modulates the target function's WEIGHTS — it shapes
 * what state we want, not the drone directly.
 *
 * TOPOLOGY IMPRINTING (Barati Sedeh & Litchinitser 2025, IEEE Photonics J.)
 * The field's current phase topology φ(x,y) is encoded into the drive's
 * modulation envelope — analogous to encoding χ_eff^(3)(x,y) in a nonlinear
 * metasurface. The drone waveform inherits the field's topology rather than
 * fighting it.
 *
 * FLOQUET CLOCK
 * The optimised drive has a well-defined period T_F. All synth spawn decisions
 * (arp, glass, percussion) are referred to this clock via a phase comparator,
 * giving coherent timing derived from the field itself.
 *
 * CONTROL PARAMETERS
 * g(t) = Σ [aₙ cos(nΩt) + bₙ sin(nΩt)]  n=1..N_HARMONICS
 * Ω = fundamental Floquet frequency (derived from orbital period)
 * Injection: alpha(t) = baseAlpha + strength * g(t)
 *
 * GRADIENT ASCENT (Hellmann-Feynman analog)
 * ∂G/∂νₘ ≈ [G(ν + δeₘ) - G(ν - δeₘ)] / 2δ  (finite difference)
 * Update:   νₘ ← νₘ + η * ∂G/∂νₘ
 * Projected onto |νₘ| ≤ DRIVE_BOUND (amplitude constraint)
 *
 * OSC OUTPUT to SuperCollider:
 *   /rdf/floquet_drive  — Fourier coefficients of optimal drive
 *   /rdf/floquet_clock  — current phase φ_F, period T_F, cycle count
 *   /rdf/floquet_orb    — orb stability, holding strength, spawn gate
 */

// =============================================================================
// FLOQUET SHAPER ENGINE — global state
// =============================================================================

// Control parameters ν: [a1,b1,a2,b2,...,aN,bN] — Fourier amplitudes of drive
final int   FS_N_HARMONICS  = 4;         // number of Fourier components
final int   FS_N_PARAMS     = FS_N_HARMONICS * 2;
float[]     fsNu            = new float[FS_N_PARAMS];   // current ν
float[]     fsNuGrad        = new float[FS_N_PARAMS];   // gradient ∂G/∂ν

// Optimiser settings
final float FS_LEARN_RATE   = 0.018;     // η — gradient ascent step
final float FS_FD_DELTA     = 0.004;     // δ — finite-difference perturbation
final float FS_DRIVE_BOUND  = 0.55;      // max amplitude per Fourier component
final float FS_OMEGA_MIN    = 0.08;      // minimum Floquet frequency (Hz)
final float FS_OMEGA_MAX    = 0.65;      // maximum Floquet frequency (Hz)

// Floquet clock
float   fsOmega       = 0.18;   // Ω — fundamental Floquet frequency (Hz)
float   fsPhase       = 0.0;    // φ_F — current Floquet phase [0, 2π)
float   fsPeriod      = 0.0;    // T_F = 2π / Ω  (seconds)
int     fsCycleCount  = 0;      // number of completed Floquet cycles
float   fsLastCycleMs = 0;      // millis() at last cycle completion
boolean fsGateOpen    = false;  // spawn gate — true for brief window at cycle

// Drive output
float   fsDriveNow    = 0.0;    // g(t) evaluated at current time
float   fsAlphaNow    = 2.0;    // alpha(t) = baseAlpha + strength * g(t)
final float FS_STRENGTH = 0.28; // how strongly drive modulates alpha

// Target function G and its history
float   fsG           = 0.0;    // current G(ν)
float   fsGPrev       = 0.0;    // previous G for convergence check
final int FS_G_HIST   = 64;
float[] fsGHistory    = new float[FS_G_HIST];
int     fsGHistHead   = 0;

// Orb (drone) stability tracking
final int FS_ORB_HIST = 90;
float[] fsOrbFreqHistory = new float[FS_ORB_HIST];
int     fsOrbHistHead    = 0;
float   fsOrbFreqVar     = 0;
float   fsHoldingStrength = 0;

// Target function weights — modulated by ocean/solar
float fsW_coupling    = 0.35;   // w₁ — maximise Floquet coupling κ
float fsW_quasienergy = 0.20;   // w₂ — minimise quasi-energy ε
float fsW_phase_lock  = 0.25;   // w₃ — lock to orbital phase
float fsW_coherence   = 0.20;   // w₄ — maximise foundational coherence

// Phase comparator — how well drive phase tracks orbital phase
float fsPhaseLockScore = 0.0;

// Optimiser cadence
float fsLastOptimMs   = 0;
final int FS_OPT_INTERVAL_MS = 180;  // optimise every ~180ms
int  fsOptSteps      = 0;            // total optimisation steps taken
boolean fsEnabled    = true;         // master enable

// Floquet lock lifecycle: inject, then acclimate into the field instead of latching.
// States: IDLE -> ARMED -> LOCKING -> INJECTING -> INTEGRATED -> RELEASING -> COOLDOWN -> ARMED
final int FS_STATE_IDLE      = 0;
final int FS_STATE_ARMED     = 1;
final int FS_STATE_LOCKING   = 2;
final int FS_STATE_INJECTING = 3;
final int FS_STATE_RELEASING = 4;
final int FS_STATE_COOLDOWN  = 5;
final int FS_STATE_INTEGRATED = 6;
int   fsLifecycleState       = FS_STATE_ARMED;
// Crossing channel (Option A): the holonomy sweep IS the crossing
float fsCrossingGamma = 0;      // signed holonomy of the sealed loop (radians)
float fsCrossingArea  = 0;      // signed parameter-space area of the loop
int   fsSealCount     = 0;      // total sealed crossings this session
float fsGammaImprintTarget = 0; // |gamma|/PI - what fsFieldImprint acclimates toward
final float FS_GAMMA_MIN = 0.02; // minimum |gamma| (rad) for a seal to count as a connected crossing
float fsStateEnterMs         = 0;
float fsLockEnterMs          = 0;
float fsInjectionEnterMs     = 0;
float fsIntegratedEnterMs    = 0;
float fsReleaseEnterMs       = 0;
float fsCooldownEnterMs      = 0;
float fsLockAge              = 0;
float fsInjectionAge         = 0;
float fsReleaseAge           = 0;
float fsIntegratedAge        = 0;
float fsCooldownRemaining    = 0;
float fsCouplingEnvelope     = 0.0;   // actual drone/state-transfer gain
float fsFieldImprint         = 0.0;   // low-level harmonic residue after injection
float fsLockScoreRaw         = 0.0;   // detector before lifecycle gating
float fsLockScoreGated       = 0.0;   // detector after release/cooldown gating
float fsBestGDuringLock      = -999;
float fsLastImprovementMs    = 0;
boolean fsReleaseCommand     = false;

final float FS_LOCK_THRESHOLD       = 0.58;
final float FS_LOCK_CONFIRM_MS      = 400;
final float FS_LOCK_RAMP_MS         = 4500;
final float FS_INJECTION_MS         = 8500;
final float FS_INTEGRATED_MS        = 26000;
final float FS_INTEGRATED_ENV       = 0.22;
final float FS_MAX_LOCK_MS          = 35000;
final float FS_RELEASE_MS           = 8500;
final float FS_COOLDOWN_MS          = 12000;
final float FS_SETTLE_IMPROVE_EPS   = 0.004;
final float FS_PLATEAU_MS           = 6500;
final float FS_EREARM_LYAP_MAX      = 0.52;
final float FS_EREARM_ORB_MAX       = 1.60;
final float FS_EREARM_FLR_MIN       = 0.55;
final float FS_EREARM_COOLDOWN_MIN  = 3000;
float fsLockCandidateStartMs        = -1;

// Topology imprinting — field phase profile encoded into drive envelope
// Analogous to χ_eff^(3)(x,y) in Barati Sedeh et al.
// We project the field's dominant gradient onto 1D drive modulation.
float fsTopologyPhase  = 0.0;   // extracted from field's Berry phase / curl
float fsTopologyDepth  = 0.0;   // extracted from field's fractal dimension

// OSC broadcast cadence
float fsLastOscMs = 0;
final int FS_OSC_INTERVAL_MS = 55;   // ~18 Hz — enough for SC without flooding

// =============================================================================
// INITIALISATION
// =============================================================================
void floquetShaperInit() {
  // Seed ν with small random values so optimiser starts exploring
  for (int i = 0; i < FS_N_PARAMS; i++) {
    fsNu[i] = random(-0.08, 0.08);
  }
  fsLastOptimMs  = (float)millis();
  fsLastCycleMs  = (float)millis();
  fsStateEnterMs = (float)millis();
  fsPeriod       = TWO_PI / max(FS_OMEGA_MIN, fsOmega);
  println("[FloquetShaper] Initialised. N_HARMONICS=" + FS_N_HARMONICS +
          "  Ω=" + nf(fsOmega, 1, 3) + " Hz  T=" + nf(fsPeriod, 1, 2) + "s");
}

// =============================================================================
// MAIN UPDATE — call from draw() every frame
// =============================================================================
void floquetShaperUpdate() {
  if (!fsEnabled) return;

  float nowMs = (float)millis();
  float nowSec = nowMs / 1000.0;

  // Floquet lifecycle is autonomous. The visible drone toggle/manual spawn controls
  // are overrides, not the condition that permits automatic lock/inject/release.
  if (fsLifecycleState == FS_STATE_IDLE && fsReleaseCommand) {
    fsReleaseCommand = false;
    enterFloquetState(FS_STATE_ARMED, nowMs);
  }

  // 1. Update Floquet frequency from orbital period estimate
  fsOmega = constrain(estimateFloquetOmega() * (0.72 + constrain(floquetDrive, 0, 1) * 0.56),
                      FS_OMEGA_MIN, FS_OMEGA_MAX);
  fsPeriod = TWO_PI / max(FS_OMEGA_MIN, fsOmega);

  // 2. Advance Floquet phase
  float dt = 1.0 / max(1.0, (float)frameRate);
  fsPhase += fsOmega * TWO_PI * dt;
  if (fsPhase >= TWO_PI) {
    fsPhase -= TWO_PI;
    fsCycleCount++;
    fsLastCycleMs = (float)nowMs;
    fsGateOpen = ((fsLifecycleState == FS_STATE_LOCKING) || (fsLifecycleState == FS_STATE_INJECTING)) && fsCouplingEnvelope > 0.05;   // lifecycle-gated spawn gate
  }

  // 3. Close spawn gate after 80ms
  if (fsGateOpen && (nowMs - fsLastCycleMs) > 80) {
    fsGateOpen = false;
  }

  // 4. Evaluate drive g(t) at current phase
  fsDriveNow = evaluateDrive(fsPhase / TWO_PI * fsPeriod);  // t in seconds

  // 5. Compute driven alpha
  float baseAlpha = safeAlphaValue(alpha);
  float engDriveScale = 0.45 + constrain(floquetDrive, 0, 1) * 1.10;
  fsAlphaNow = constrain(baseAlpha + FS_STRENGTH * engDriveScale * fsCouplingEnvelope * fsDriveNow, 1.1, 4.5);

  // 6. Extract topology imprinting from field
  updateTopologyImprinting();

  // 7. Update target function weights from ocean/solar
  updateTargetWeights();

  // 8. Track orb frequency variance
  updateOrbFrequencyTracking();

  // 9. Evaluate current G(ν)
  fsGPrev = fsG;
  fsG     = evaluateTargetFunction(fsNu);
  fsGHistory[fsGHistHead] = fsG;
  fsGHistHead = (fsGHistHead + 1) % FS_G_HIST;

  // 9b. Update lock/inject/release lifecycle after current metrics are known
  updateFloquetLifecycle(nowMs);

  // 10. Run gradient-ascent step periodically
  if ((nowMs - fsLastOptimMs) > FS_OPT_INTERVAL_MS) {
    floquetGradientStep();
    fsLastOptimMs = (float)nowMs;
  }

  // 11. Broadcast to SC
  if ((nowMs - fsLastOscMs) > FS_OSC_INTERVAL_MS) {
    floquetShaperBroadcast();
    fsLastOscMs = (float)nowMs;
  }
}

// =============================================================================
// ESTIMATE FLOQUET FREQUENCY from orbital dynamics
// The orbital period provides the natural Floquet timescale.
// Ω = 2π / T_orbital, clamped to audio-safe range.
// =============================================================================
float estimateFloquetOmega() {
  // Use orbital radius history to estimate period from peak-to-peak
  if (orbitEventRadiusHistory == null || orbitEventRadiusHistory.size() < 20) {
    return constrain(fsOmega, FS_OMEGA_MIN, FS_OMEGA_MAX);
  }

  // Count radial peaks to estimate orbital period
  int peaks = 0;
  int n = orbitEventRadiusHistory.size();
  for (int i = 2; i < n - 2; i++) {
    float v = orbitEventRadiusHistory.get(i);
    if (v > orbitEventRadiusHistory.get(i-1) &&
        v > orbitEventRadiusHistory.get(i+1) &&
        v > orbitEventRadiusHistory.get(i-2) &&
        v > orbitEventRadiusHistory.get(i+2)) {
      peaks++;
    }
  }

  // Orbital history covers ~3 seconds of frames at ~24fps
  float estimatedPeriod = (peaks > 1) ? (3.0 / (peaks * 0.5)) : 5.5;
  float omega = TWO_PI / max(0.5, estimatedPeriod);

  // Slow exponential smoothing — don't let Ω jump abruptly
  return constrain(fsOmega * 0.96 + omega * 0.04, FS_OMEGA_MIN, FS_OMEGA_MAX);
}

// =============================================================================
// EVALUATE DRIVE g(t) at time t (seconds)
// g(t) = Σₙ [a_n cos(nΩt) + b_n sin(nΩt)]
// Plus topology imprinting: modulate envelope by field's phase profile
// =============================================================================
float evaluateDrive(float t) {
  float g = 0;
  for (int n = 1; n <= FS_N_HARMONICS; n++) {
    int ia = (n - 1) * 2;
    int ib = ia + 1;
    float an = (ia < FS_N_PARAMS) ? fsNu[ia] : 0;
    float bn = (ib < FS_N_PARAMS) ? fsNu[ib] : 0;
    g += an * cos(n * fsOmega * TWO_PI * t)
       + bn * sin(n * fsOmega * TWO_PI * t);
  }

  // Topology imprinting: modulate amplitude by field's topological phase
  // Analogous to χ_eff^(3)(x,y) encoding in Barati Sedeh et al.
  // This encodes the field's dominant Berry/fractal signature into the drive
  // envelope so the drone waveform inherits the field's topology.
  float topoFactor = 1.0 + 0.22 * cos(fsTopologyPhase) * fsTopologyDepth;
  g *= constrain(topoFactor, 0.65, 1.45);

  return constrain(g, -1.5, 1.5);
}

// =============================================================================
// EVALUATE TARGET FUNCTION G(ν)
// G = w₁κ - w₂ε + w₃cos(φ_F - φ_orbit) + w₄·coherence - w₅·freqVar
//
// This is the merit function from Castro et al. eq.(7).
// High G = drive is well-matched to the field's current topological state.
// =============================================================================
float evaluateTargetFunction(float[] nu) {
  float kappa    = constrain(envFloquetCoupling(), 0, 1);
  float epsilon  = constrain(envFloquetQuasienergy(), 0, 1);
  float coherence= constrain(foundationalCoherence, 0, 1);

  // Orbital phase for phase-lock term
  float phiOrbit = atan2(orb_y, orb_x);
  if (phiOrbit < 0) phiOrbit += TWO_PI;
  fsPhaseLockScore = 0.5 + 0.5 * cos(fsPhase - phiOrbit);

  // Orb frequency variance penalty — low variance = stable drone
  float freqVarPenalty = constrain(fsOrbFreqVar * 8.0, 0, 1);

  // Composite G
  float G = fsW_coupling    * kappa
          - fsW_quasienergy * epsilon
          + fsW_phase_lock  * fsPhaseLockScore
          + fsW_coherence   * coherence
          - 0.15            * freqVarPenalty;

  return constrain(G, -1, 1);
}

// =============================================================================
// GRADIENT ASCENT STEP — finite-difference Hellmann-Feynman analog
// ∂G/∂νₘ ≈ [G(ν+δeₘ) - G(ν-δeₘ)] / 2δ
// νₘ ← νₘ + η * ∂G/∂νₘ  (projected onto |νₘ| ≤ DRIVE_BOUND)
//
// This is the language-side analog of Castro et al. eq.(12)/(22).
// We use finite differences rather than the full costate propagation
// because the system dimension is small enough to make this tractable.
// =============================================================================
void floquetGradientStep() {
  // Save current state
  float gCenter = evaluateTargetFunction(fsNu);
  float[] nuPlus  = new float[FS_N_PARAMS];
  float[] nuMinus = new float[FS_N_PARAMS];

  for (int m = 0; m < FS_N_PARAMS; m++) {
    // Compute finite-difference gradient for parameter m
    arrayCopy(fsNu, nuPlus);  nuPlus[m]  += FS_FD_DELTA;
    arrayCopy(fsNu, nuMinus); nuMinus[m] -= FS_FD_DELTA;
    float gPlus  = evaluateTargetFunction(nuPlus);
    float gMinus = evaluateTargetFunction(nuMinus);
    fsNuGrad[m]  = (gPlus - gMinus) / (2.0 * FS_FD_DELTA);
  }

  // Gradient ascent update with adaptive rate
  // If G is improving, keep rate; if stagnating, add small random perturbation
  float improvement = fsG - fsGPrev;
  float eta = FS_LEARN_RATE * (0.65 + constrain(floquetDrive, 0, 1) * 0.70);
  if (abs(improvement) < 0.0005 && fsOptSteps > 20) {
    // Add small random noise to escape local optima (simulated annealing flavor)
    float jitter = 0.004 + constrain(floquetInstability, 0, 1) * 0.026;
    for (int m = 0; m < FS_N_PARAMS; m++) {
      fsNu[m] += random(-jitter, jitter);
    }
  }

  for (int m = 0; m < FS_N_PARAMS; m++) {
    fsNu[m] = constrain(fsNu[m] + eta * fsNuGrad[m], -FS_DRIVE_BOUND, FS_DRIVE_BOUND);
  }
  applyCTCFloquetAsymmetry();

  fsOptSteps++;
}

// =============================================================================
// TOPOLOGY IMPRINTING — extract field phase topology
// Analogous to encoding phase profile φ(x,y) into χ_eff^(3)(x,y)
// in Barati Sedeh et al. (2025).
// We extract the field's dominant topological signatures:
//   - Berry holonomy angle → fsTopologyPhase
//   - Fractal dimension normalised → fsTopologyDepth
// These modulate the drive envelope so the drone waveform
// inherits the field's current topological character.
// =============================================================================
void updateTopologyImprinting() {
  // Berry phase gives holonomy — the field's "winding" over a parameter cycle
  // This is the direct analog of φ(x,y) in the metasurface paper
  float berry = constrain(metricBerryPhase, -1, 1);
  fsTopologyPhase = berry * PI;   // map [-1,1] → [-π,π]

  // Fractal dimension encodes surface/volume topology of the field
  // Normalised to [0,1]: 1.0 → flat (no topological structure), 2.5 → rich
  fsTopologyDepth = constrain((metricFractalDim - 1.0) / 1.5, 0, 1);
}

// =============================================================================
// TARGET WEIGHT UPDATE — ocean and solar data modulate G's weights
// This is the safe way to inject external data: it changes WHAT STATE
// we optimise toward, not the drone frequency directly.
// =============================================================================
void updateTargetWeights() {
  // Ocean data: high current/temperature energy favours coupling and phase lock.
  float oceanActivity = 0;
  if (oceanBridge != null) {
    oceanActivity = constrain(
      oceanBridge.energyNorm * 0.58 + oceanBridge.thermalNorm * 0.42,
      0, 1);
  }

  // Solar data: high solar activity → favour coherence and low quasi-energy
  float solarActivity = 0;
  if (solarBridge != null) {
    solarActivity = constrain(
      solarBridge.kpNorm * 0.4 + solarBridge.xrayNorm * 0.3 + solarBridge.windNorm * 0.3,
      0, 1);
  }

  // Smoothly update weights — slow exponential filter prevents discontinuities
  float wc = 0.025;
  fsW_coupling    = fsW_coupling    * (1-wc) + (0.28 + oceanActivity * 0.20) * wc;
  fsW_quasienergy = fsW_quasienergy * (1-wc) + (0.15 + solarActivity  * 0.18) * wc;
  fsW_phase_lock  = fsW_phase_lock  * (1-wc) + (0.25 + oceanActivity * 0.12) * wc;
  fsW_coherence   = fsW_coherence   * (1-wc) + (0.20 + solarActivity  * 0.12) * wc;

  // Change 7 — UFO mode phase lock priority boost.
  // When UFO mode is active, the Floquet optimiser prioritises locking the
  // drive phase to the orbital phase. This is the mechanism by which the
  // Floquet drone stops being a loose influence and becomes a genuine guide —
  // the orbital and the drive converge toward the same topological clock.
  // ufoTransition scales linearly: disc (0) = no boost, jellyfish (1) = full.
  // Cap at 0.55 to prevent phase_lock from dominating entirely and starving
  // the coupling and coherence terms that keep the drive musically grounded.
  if (fcPanel != null && fcPanel.fcReady && fcPanel.ufoModeOn) {
    float ufoBoost = fcPanel.ufoTransition * 0.20;
    fsW_phase_lock = constrain(fsW_phase_lock + ufoBoost, 0, 0.55);
  }

  fsW_quasienergy = constrain(fsW_quasienergy + (constrain(quasiEnergyBias, 0, 1) - 0.5) * 0.18, 0.04, 0.58);
  fsW_phase_lock = constrain(fsW_phase_lock + (constrain(orbitResonanceDrive, 0, 1) - 0.5) * 0.12, 0.04, 0.58);

  // Normalise so weights sum to ~1
  float wsum = fsW_coupling + fsW_quasienergy + fsW_phase_lock + fsW_coherence + 0.001;
  fsW_coupling    /= wsum;
  fsW_quasienergy /= wsum;
  fsW_phase_lock  /= wsum;
  fsW_coherence   /= wsum;
}

// =============================================================================
// ORB FREQUENCY VARIANCE TRACKING
// Tracks how stable the drone's nominal frequency is over time.
// Low variance = drone is "held" in the potential well. High = drifting.
// =============================================================================
void updateOrbFrequencyTracking() {
  // Proxy for drone frequency: quantizeToScale would give exact value,
  // but we use the driven alpha's influence on rootFreq as a fast proxy.
  float nominalFreq = getSliderValueSafe("rootFreq", 55) * (1.0 + fsAlphaNow * 0.05);
  fsOrbFreqHistory[fsOrbHistHead] = nominalFreq;
  fsOrbHistHead = (fsOrbHistHead + 1) % FS_ORB_HIST;

  // Compute running variance
  float mean = 0;
  for (float v : fsOrbFreqHistory) mean += v;
  mean /= FS_ORB_HIST;
  float variance_ = 0;
  for (float v : fsOrbFreqHistory) variance_ += sq(v - mean);
  fsOrbFreqVar = variance_ / FS_ORB_HIST;

  // Holding strength = G * (1 - normalised variance)
  float varNorm = constrain(fsOrbFreqVar / (mean * mean + 0.001), 0, 1);
  fsHoldingStrength = constrain(fsG * 0.5 + 0.5 - varNorm * 0.5, 0, 1);
}



// =============================================================================
// FLOQUET LIFECYCLE STATE MACHINE
// Prevents the Floquet drone from proving its own lock forever. Release and
// cooldown explicitly ignore the resonance detector and force coupling down.
// =============================================================================
void updateFloquetLifecycle(float nowMs) {
  float gNorm = constrain((fsG + 1.0) * 0.5, 0, 1);
  fsLockScoreRaw = constrain(fsPhaseLockScore * 0.42 + fsHoldingStrength * 0.35 + gNorm * 0.23, 0, 1);

  boolean releasingOrCooling = (fsLifecycleState == FS_STATE_RELEASING) || (fsLifecycleState == FS_STATE_COOLDOWN);
  fsLockScoreGated = releasingOrCooling ? 0.0 : fsLockScoreRaw;

  fsLockAge = ((fsLifecycleState == FS_STATE_LOCKING) || (fsLifecycleState == FS_STATE_INJECTING) || (fsLifecycleState == FS_STATE_INTEGRATED) || (fsLifecycleState == FS_STATE_RELEASING)) ? (nowMs - fsLockEnterMs) / 1000.0 : 0;
  fsInjectionAge = (fsLifecycleState == FS_STATE_INJECTING) ? (nowMs - fsInjectionEnterMs) / 1000.0 : 0;
  fsIntegratedAge = (fsLifecycleState == FS_STATE_INTEGRATED) ? (nowMs - fsIntegratedEnterMs) / 1000.0 : 0;
  fsReleaseAge = (fsLifecycleState == FS_STATE_RELEASING) ? (nowMs - fsReleaseEnterMs) / 1000.0 : 0;
  fsCooldownRemaining = (fsLifecycleState == FS_STATE_COOLDOWN) ? max(0, (FS_COOLDOWN_MS - (nowMs - fsCooldownEnterMs)) / 1000.0) : 0;

  if (fsG > fsBestGDuringLock + FS_SETTLE_IMPROVE_EPS) {
    fsBestGDuringLock = fsG;
    fsLastImprovementMs = nowMs;
  }

  switch(fsLifecycleState) {
    case FS_STATE_IDLE:
      fsCouplingEnvelope = approach(fsCouplingEnvelope, 0.0, 0.06);
      fsGateOpen = false;
      break;

    case FS_STATE_ARMED: {
      fsCouplingEnvelope = approach(fsCouplingEnvelope, 0.0, 0.04);
      fsGateOpen = false;
      boolean recentlyDepartedCoherence = framesSinceCoherence < 180 && !cartBasin.equals("COHERENCE BASIN");
      // Option A: the lifecycle engages only when a crossing is being attempted.
      // The resonance score remains live for display/telemetry, but without a
      // running sweep there is nothing to inject; locking would only churn.
      boolean lockCandidate = holoSweep.running &&
        (fsLockScoreRaw > FS_LOCK_THRESHOLD || (recentlyDepartedCoherence && fsLockScoreRaw > (FS_LOCK_THRESHOLD - 0.06)));
      if (lockCandidate) {
        if (fsLockCandidateStartMs < 0) fsLockCandidateStartMs = nowMs;
        if ((nowMs - fsLockCandidateStartMs) > FS_LOCK_CONFIRM_MS) enterFloquetState(FS_STATE_LOCKING, nowMs);
      } else {
        fsLockCandidateStartMs = -1;
      }
      break;
    }

    case FS_STATE_LOCKING:
      fsCouplingEnvelope = constrain((nowMs - fsStateEnterMs) / FS_LOCK_RAMP_MS, 0, 1);
      if ((nowMs - fsStateEnterMs) > FS_LOCK_RAMP_MS) enterFloquetState(FS_STATE_INJECTING, nowMs);
      if (((nowMs - fsLockEnterMs) > FS_MAX_LOCK_MS) && !holoSweep.running) enterFloquetState(FS_STATE_RELEASING, nowMs);
      break;

    case FS_STATE_INJECTING:
      fsCouplingEnvelope = approach(fsCouplingEnvelope, 1.0, 0.04);
      boolean injectionDone = ((nowMs - fsInjectionEnterMs) > FS_INJECTION_MS) && !holoSweep.running;
      boolean plateaued = ((nowMs - fsLastImprovementMs) > FS_PLATEAU_MS) && !holoSweep.running;
      boolean maxedOut = ((nowMs - fsLockEnterMs) > FS_MAX_LOCK_MS) && !holoSweep.running;
      if (injectionDone || maxedOut || plateaued) {
        println("[FloquetLifecycle] injection window closed without holonomy seal - crossing failed, releasing.");
        enterFloquetState(FS_STATE_RELEASING, nowMs);
      }
      break;

    case FS_STATE_INTEGRATED:
      fsGateOpen = false;
      fsFieldImprint = approach(fsFieldImprint, fsGammaImprintTarget, 0.035);
      fsCouplingEnvelope = approach(fsCouplingEnvelope, FS_INTEGRATED_ENV, 0.025);
      if ((nowMs - fsIntegratedEnterMs) > FS_INTEGRATED_MS) enterFloquetState(FS_STATE_RELEASING, nowMs);
      break;

    case FS_STATE_RELEASING:
      fsReleaseCommand = true;
      fsGateOpen = false;
      fsCouplingEnvelope = constrain(1.0 - ((nowMs - fsReleaseEnterMs) / FS_RELEASE_MS), 0, 1);
      if ((nowMs - fsReleaseEnterMs) > FS_RELEASE_MS) enterFloquetState(FS_STATE_COOLDOWN, nowMs);
      break;

    case FS_STATE_COOLDOWN:
      fsReleaseCommand = false;
      fsGateOpen = false;
      fsCouplingEnvelope = approach(fsCouplingEnvelope, 0.0, 0.12);
      if ((nowMs - fsCooldownEnterMs) > FS_COOLDOWN_MS) {
        enterFloquetState(FS_STATE_ARMED, nowMs);
        break;
      }
      if ((nowMs - fsCooldownEnterMs) > FS_EREARM_COOLDOWN_MIN) {
        float r_o = sqrt(orb_x * orb_x + orb_y * orb_y);
        boolean basinReady = cartBasin.equals("METASTABLE DRIFT");
        boolean lyapReady = metricLyapunov < FS_EREARM_LYAP_MAX;
        boolean orbReady = r_o < FS_EREARM_ORB_MAX;
        boolean lockBuilding = fsLockScoreRaw > FS_EREARM_FLR_MIN;
        boolean scNotSaturated = scSaturation < 0.60;
        if (basinReady && lyapReady && orbReady && lockBuilding && scNotSaturated) {
          println("[FloquetLifecycle] EMERGENCY RE-ARM: window conditions met during cooldown. "
            + "lyap=" + nf(metricLyapunov, 1, 3)
            + " orb=" + nf(r_o, 1, 3)
            + " flr=" + nf(fsLockScoreRaw, 1, 3)
            + " scSat=" + nf(scSaturation, 1, 2));
          enterFloquetState(FS_STATE_ARMED, nowMs);
        }
      }
      break;
  }

  if (releasingOrCooling) fsGateOpen = false;
}

// =============================================================================
// CROSSING API - called by HolonomySweepInstrument (Option A unification).
// The sweep is the crossing: tracing the loop is the injection, sealing the
// loop with nonzero gamma is the arrival. INTEGRATED has no other entrance.
// =============================================================================

void floquetSweepStarted() {
  float nowMs = millis();
  if (fsLifecycleState == FS_STATE_COOLDOWN) {
    println("[Crossing] sweep started during COOLDOWN - lifecycle will not engage until re-armed.");
    return;
  }
  if (fsLifecycleState == FS_STATE_ARMED || fsLifecycleState == FS_STATE_IDLE) {
    enterFloquetState(FS_STATE_LOCKING, nowMs);
    println("[Crossing] sweep started: path begun, locking.");
  }
  // If already LOCKING/INJECTING (resonance got there first), the sweep simply
  // inherits the open window. If INTEGRATED, a new loop is beginning while the
  // previous arrival persists; a fresh seal will re-acclimate.
}

void floquetCrossingSealed(float gammaRad, float loopArea) {
  float nowMs = millis();
  fsCrossingGamma = gammaRad;
  fsCrossingArea  = loopArea;

  if (abs(gammaRad) < FS_GAMMA_MIN) {
    println("[Crossing] loop sealed but gamma=" + safeNf(gammaRad,1,5) +
            " rad below threshold - throat did not connect.");
    if (fsLifecycleState == FS_STATE_LOCKING || fsLifecycleState == FS_STATE_INJECTING) {
      enterFloquetState(FS_STATE_RELEASING, nowMs);
    }
    return;
  }

  fsSealCount++;
  fsGammaImprintTarget = constrain(abs(gammaRad) / PI, 0, 1);

  if (fsLifecycleState == FS_STATE_INTEGRATED) {
    // A further loop sealed while already inside: deepen/refresh the acclimation.
    fsIntegratedEnterMs = nowMs;
    println("[Crossing] re-seal while INTEGRATED: gamma=" + safeNf(gammaRad,1,5) +
            " rad - acclimation refreshed (seal #" + fsSealCount + ").");
  } else if (fsLifecycleState == FS_STATE_COOLDOWN) {
    println("[Crossing] seal during COOLDOWN ignored (gamma=" + safeNf(gammaRad,1,5) + " rad).");
    return;
  } else {
    enterFloquetState(FS_STATE_INTEGRATED, nowMs);
    println("[Crossing] SEALED & CONNECTED: gamma=" + safeNf(gammaRad,1,5) +
            " rad  area=" + safeNf(loopArea,1,4) + "  imprint->" +
            safeNf(fsGammaImprintTarget,1,3) + "  (seal #" + fsSealCount + ")");
  }
}

void floquetSweepStopped() {
  float nowMs = millis();
  if (fsLifecycleState == FS_STATE_LOCKING || fsLifecycleState == FS_STATE_INJECTING) {
    println("[Crossing] sweep stopped before seal - crossing abandoned, releasing.");
    enterFloquetState(FS_STATE_RELEASING, nowMs);
  }
  // If INTEGRATED: the arrival persists on its own acclimation timer.
}

void enterFloquetState(int newState, float nowMs) {
  fsLifecycleState = newState;
  fsStateEnterMs = nowMs;
  if (newState == FS_STATE_LOCKING) {
    fsLockEnterMs = nowMs;
    fsBestGDuringLock = fsG;
    fsLastImprovementMs = nowMs;
    fsReleaseCommand = false;
    println("[FloquetLifecycle] LOCKING: resonance confirmed, ramping drone coupling.");
  } else if (newState == FS_STATE_INJECTING) {
    fsInjectionEnterMs = nowMs;
    println("[FloquetLifecycle] INJECTING: transfer window open.");
  } else if (newState == FS_STATE_INTEGRATED) {
    fsIntegratedEnterMs = nowMs;
    fsReleaseCommand = false;
    fsGateOpen = false;
    println("[FloquetLifecycle] INTEGRATED: drone acclimating into field imprint.");
  } else if (newState == FS_STATE_RELEASING) {
    fsReleaseEnterMs = nowMs;
    fsReleaseCommand = true;
    fsGateOpen = false;
    println("[FloquetLifecycle] RELEASING: forced unlock, detector temporarily ignored.");
  } else if (newState == FS_STATE_COOLDOWN) {
    fsCooldownEnterMs = nowMs;
    fsReleaseCommand = false;
    fsGateOpen = false;
    fsFieldImprint = 0.0;
    println("[FloquetLifecycle] COOLDOWN: respawn blocked.");
  } else if (newState == FS_STATE_ARMED) {
    fsLockCandidateStartMs = -1;
    fsReleaseCommand = false;
    println("[FloquetLifecycle] ARMED: ready for next transfer.");
  }
}

float approach(float current, float target, float rate) {
  return current + (target - current) * constrain(rate, 0, 1);
}

String floquetStateName(int st) {
  if (st == FS_STATE_IDLE) return "IDLE";
  if (st == FS_STATE_ARMED) return "ARMED";
  if (st == FS_STATE_LOCKING) return "LOCKING";
  if (st == FS_STATE_INJECTING) return "INJECTING";
  if (st == FS_STATE_INTEGRATED) return "INTEGRATED";
  if (st == FS_STATE_RELEASING) return "RELEASING";
  if (st == FS_STATE_COOLDOWN) return "COOLDOWN";
  return "UNKNOWN";
}

// =============================================================================
// OSC BROADCAST to SuperCollider
// /rdf/floquet_drive  — Fourier coefficients for SC-side drive reconstruction
// /rdf/floquet_clock  — phase, period, cycle, gate
// /rdf/floquet_orb    — stability metrics for SC spawn decisions
// =============================================================================
void floquetShaperBroadcast() {
  if (oscP5 == null || supercollider == null) return;

  // 1. Drive coefficients — SC uses these to reconstruct g(t) and modulate alpha
  OscMessage mDrive = new OscMessage("/rdf/floquet_drive");
  mDrive.add(fsOmega);          // [1] fundamental frequency Hz
  mDrive.add((float)FS_N_HARMONICS);   // [2] number of harmonics
  for (int i = 0; i < FS_N_PARAMS; i++) {
    mDrive.add(fsNu[i]);        // [3..3+2N-1] Fourier coefficients
  }
  mDrive.add(fsDriveNow);       // [3+2N] current g(t) value
  mDrive.add(fsAlphaNow);       // [3+2N+1] current driven alpha
  mDrive.add(FS_STRENGTH);      // [3+2N+2] injection strength
  mDrive.add(fsTopologyPhase);  // [3+2N+3] topology imprint phase
  mDrive.add(fsTopologyDepth);  // [3+2N+4] topology imprint depth
  try { oscP5.send(mDrive, supercollider); } catch (Exception e) {}

  // 2. Floquet clock — SC uses this for coherent synth spawn timing
  OscMessage mClock = new OscMessage("/rdf/floquet_clock");
  mClock.add(fsPhase);          // [1] current Floquet phase [0, 2π)
  mClock.add(fsPeriod);         // [2] Floquet period T_F (seconds)
  mClock.add((float)fsCycleCount);     // [3] completed cycles (integer)
  mClock.add(fsGateOpen ? 1.0 : 0.0); // [4] spawn gate
  mClock.add(fsPhaseLockScore); // [5] phase lock quality [0,1]
  try { oscP5.send(mClock, supercollider); } catch (Exception e) {}

  // 3. Orb stability — SC uses this to gate drone spawning
  OscMessage mOrb = new OscMessage("/rdf/floquet_orb");
  mOrb.add(fsHoldingStrength);  // [1] drone holding strength [0,1]
  mOrb.add(fsG);                // [2] target function G current value
  mOrb.add(fsOrbFreqVar);       // [3] drone frequency variance
  mOrb.add(fsW_coupling);       // [4] current weight w_coupling
  mOrb.add(fsW_coherence);      // [5] current weight w_coherence
  try { oscP5.send(mOrb, supercollider); } catch (Exception e) {}

  // 4. Lifecycle — SC follows this command channel for lock/release behavior.
  OscMessage mLife = new OscMessage("/rdf/floquet_lifecycle");
  mLife.add((float)fsLifecycleState);      // [1] state id
  mLife.add(fsCouplingEnvelope);           // [2] commanded drone/state-transfer envelope
  mLife.add(fsLockAge);                    // [3] seconds since lock began
  mLife.add(fsInjectionAge);               // [4] seconds in injection state
  mLife.add(fsReleaseAge);                 // [5] seconds in release state
  mLife.add(fsCooldownRemaining);          // [6] seconds until respawn allowed
  mLife.add(fsLockScoreRaw);               // [7] raw resonance score
  mLife.add(fsLockScoreGated);             // [8] lifecycle-gated resonance score
  mLife.add(fsReleaseCommand ? 1.0 : 0.0); // [9] hard release command
  mLife.add(fsIntegratedAge);              // [10] seconds in integrated/acclimated state
  mLife.add(fsFieldImprint);               // [11] field imprint residue [0,1]
  mLife.add(fsCrossingGamma);              // [12] signed holonomy gamma of last sealed loop (rad)
  mLife.add(fsCrossingArea);               // [13] signed loop area in (alpha,depth) space
  try { oscP5.send(mLife, supercollider); } catch (Exception e) {}
}

// =============================================================================
// DRAW — embedded panel in main GUI
// Shows optimiser convergence, current drive waveform, clock, holding strength
// =============================================================================
void drawFloquetShaperPanel(int x, int y, int w, int h) {
  if (!fsEnabled) return;

  // Panel background
  fill(8, 12, 18, 230);
  stroke(55, 95, 120, 160);
  rect(x, y, w, h, 8);

  fill(160, 220, 240);
  textSize(9);
  textAlign(LEFT, TOP);
  text("FLOQUET SHAPER ENGINE", x+10, y+7);

  fill(100, 150, 160);
  textSize(8);
  text("Ω=" + nf(fsOmega,1,3) + "Hz  T=" + nf(fsPeriod,1,2) + "s  cycle=" +
       fsCycleCount + "  steps=" + fsOptSteps, x+10, y+20);

  // Drive waveform — one full period
  int wx = x+10, wy = y+36, ww = w-20, wh = 40;
  fill(5, 12, 16); noStroke(); rect(wx, wy, ww, wh);
  stroke(60, 160, 200, 160); strokeWeight(1.2); noFill(); beginShape();
  for (int i = 0; i < ww; i++) {
    float t = (float)i / ww * fsPeriod;
    float g = evaluateDrive(t);
    vertex(wx+i, wy + wh/2 - g * wh * 0.38);
  }
  endShape();
  // Floquet phase marker
  float phaseX = wx + (fsPhase / TWO_PI) * ww;
  stroke(255, 200, 80, 200); strokeWeight(1.5);
  line(phaseX, wy, phaseX, wy+wh);
  noStroke();
  fill(90, 150, 160); textSize(7); textAlign(LEFT, TOP);
  text("drive g(t)  φ=" + nf(degrees(fsPhase),1,0)+"°", wx+2, wy+2);

  // Spawn gate indicator
  if (fsGateOpen) {
    fill(80, 255, 120, 200);
    noStroke(); ellipse(x + w - 18, y + 18, 10, 10);
  }

  // G convergence sparkline
  int sx = x+10, sy = y+82, sw = w-20, sh = 28;
  fill(5, 12, 16); noStroke(); rect(sx, sy, sw, sh);
  stroke(120, 240, 160, 150); strokeWeight(1); noFill(); beginShape();
  float maxG = 0.001;
  for (float v : fsGHistory) maxG = max(maxG, abs(v));
  for (int i = 0; i < FS_G_HIST; i++) {
    int idx = (fsGHistHead + i) % FS_G_HIST;
    float gv = fsGHistory[idx] / maxG;
    vertex(sx + i * sw / FS_G_HIST, sy + sh/2 - gv * sh * 0.42);
  }
  endShape();
  fill(90, 140, 150); textSize(7); textAlign(LEFT, TOP);
  text("G=" + nf(fsG,1,3) + "  hold=" + nf(fsHoldingStrength,1,2) +
       "  lock=" + nf(fsPhaseLockScore,1,2) + "  " + floquetStateName(fsLifecycleState) +
       " env=" + nf(fsCouplingEnvelope,1,2) + " imprint=" + nf(fsFieldImprint,1,2), sx+2, sy+2);

  // Fourier coefficient bars
  int bx = x+10, by = y+118, bw = (w-20)/FS_N_PARAMS, bh = 22;
  for (int i = 0; i < FS_N_PARAMS; i++) {
    float v = constrain(fsNu[i] / FS_DRIVE_BOUND, -1, 1);
    fill(v > 0 ? color(60, 180, 220) : color(220, 100, 60));
    noStroke();
    if (v > 0) rect(bx + i*bw, by + bh/2 - v*bh/2, bw-1, v*bh/2);
    else       rect(bx + i*bw, by + bh/2, bw-1, -v*bh/2);
  }
  stroke(40, 70, 80, 130); strokeWeight(0.5);
  line(bx, by+bh/2, bx+FS_N_PARAMS*bw, by+bh/2);
  fill(90, 140, 150); textSize(7); textAlign(LEFT, TOP);
  text("ν (Fourier coefficients)  topo φ=" + nf(degrees(fsTopologyPhase),1,0)+"°", bx, by-8);

  // Weight readouts
  int ry = y + h - 22;
  fill(90, 140, 150); textSize(7); textAlign(LEFT, BOTTOM);
  text("κ=" + nf(fsW_coupling,1,2) + "  ε=" + nf(fsW_quasienergy,1,2) +
       "  Φ=" + nf(fsW_phase_lock,1,2) + "  C=" + nf(fsW_coherence,1,2) +
       "  αF=" + nf(fsAlphaNow,1,2), x+10, y+h-4);
}

// =============================================================================
// CONVENIENCE — reset optimiser
// =============================================================================
void floquetShaperReset() {
  for (int i = 0; i < FS_N_PARAMS; i++) fsNu[i] = random(-0.05, 0.05);
  fsOptSteps = 0;
  fsCycleCount = 0;
  fsPhase = 0;
  fsLifecycleState = FS_STATE_ARMED;
  fsCouplingEnvelope = 0;
  fsLockCandidateStartMs = -1;
  println("[FloquetShaper] Reset.");
}
