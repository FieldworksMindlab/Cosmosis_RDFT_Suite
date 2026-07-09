// =============================================================================
// PhiFieldEngine.pde
// =============================================================================
// Centralized nonlinear phi field engine.
//
// Core equation (§0 of the derivation document):
//
//   F[φ,ρ,p] = φ + ½|∇φ|² + A·e^(−2φ)·S = 0
//
//   where  S := ρc² + 3p     (active gravitational source, §3)
//          A := 4πG₀/c⁴      (coupling constant)
//
// This class computes and exposes:
//   • φ(r)         — radial scalar field from §5 ODE, replacing the old log proxy
//   • F            — full residual (§0/§9) for recursive update tracking
//   • ∇F           — gradient of residual including self-steepening term (§1)
//   • G_local      — local gain / stability indicator (§8)
//   • thresholdProximity — normalised distance to the instability boundary
//   • φ₁           — first-order perturbation field (§6), tracked during sweeps
//   • μ_adaptive   — adaptive recursion step per §9 practical notes
//
// All downstream systems — orbResolutionField(), orbEffectiveGravity(),
// computeFoundationalFieldMetrics(), AdiabaticTracker, BerryPhaseTracker,
// OSC payload — read from the single PhiFieldEngine instance `phiEngine`.
//
// Physical units are normalised:
//   r is in "orbital units" (ORB_BOUND ≈ 2.2)
//   φ is dimensionless
//   S is taken from the RDFT field average as a proxy for source density
//   A is set so A·S_typical ≈ 0.3, keeping G_local comfortably positive at rest
//
// =============================================================================

class PhiFieldEngine {

  // ── Coupling constant A = 4πG₀/c⁴ (normalised to RDFT units) ─────────────
  // In dimensionless RDFT units we set A so that A·S_typical ≈ 0.25.
  // S_typical (avgBright, normally 0.3–0.6) → A ≈ 0.5 gives A·S ≈ 0.15–0.30,
  // keeping the system well below the G_local = 0 stability boundary at rest.
  float A = 0.5;

  // ── Source combination S = ρc² + 3p  (§0, §3) ────────────────────────────
  // In the synth, ρc² is proxied by the field average brightness,
  // and 3p (pressure) is proxied by 3× the field variance.
  // Both are updated every frame via update().
  float S          = 0.3;   // current source value
  float S_prev     = 0.3;   // previous frame — for ∂ₜS in time derivative
  float dS_dt      = 0.0;   // time derivative of S (§1 time derivative)

  // ── Field state ────────────────────────────────────────────────────────────
  float phi        = 0.0;   // scalar field value at orbital position
  float phi_prev   = 0.0;   // previous step — for perturbation tracking

  // Gradient components of φ over the 2D RDFT grid (§1)
  float gradPhi_x  = 0.0;   // ∂φ/∂x  (field-grid gradient, not orbital)
  float gradPhi_y  = 0.0;
  float gradPhiMag = 0.0;   // |∇φ|

  // ── Core derived quantities ────────────────────────────────────────────────
  float F          = 0.0;   // residual:  φ + ½|∇φ|² + A·e^(−2φ)·S
  float F_prev     = 0.0;

  // §1: gradient of the full residual (self-steepening included)
  // ∇F = ∇φ + (∇φ·∇)(∇φ) + A·e^(−2φ)·(∇S − 2S·∇φ)
  float gradF_x    = 0.0;
  float gradF_y    = 0.0;
  float gradFMag   = 0.0;

  // §8: local gain  G_local = 1 − 2A·e^(−2φ)·S
  // Positive → damping (stable). Negative → runaway. Zero → threshold.
  float G_local    = 1.0;

  // Normalised proximity to the instability threshold  2A·e^(−2φ)·S = 1.
  // 0.0 = far from threshold, 1.0 = exactly at threshold, >1.0 = past it.
  float thresholdProximity = 0.0;

  // §9: adaptive recursion step  μ → μ / (1 + |F| + |∇φ|²)
  float mu         = 0.1;   // base step
  float mu_adaptive = 0.1;

  // §6: first-order perturbation field φ₁ (scalar summary — field average)
  // Tracks how the field responds to source changes during adiabatic sweeps.
  // Full equation: (1 − 2A·e^(−2φ₀)·S₀)φ₁ + ∇φ₀·∇φ₁ = −A·e^(−2φ₀)·S₁
  float phi1       = 0.0;
  float phi1_energy = 0.0;   // ½|∇φ₁|² — the self-steepening contribution (§6 §2nd order)

  // §5 radial ODE integration — φ(r) over the orbital radial range
  // φ′(r) = ±√[−2φ − 2A·S·e^(−2φ)]
  // Stored as a lookup table for fast evaluation during orbit steps.
  static final int PHI_RADIAL_SAMPLES = 200;
  float[] phiRadial = new float[PHI_RADIAL_SAMPLES];  // φ(r) at r = i/N * ORB_BOUND
  boolean radialTableReady = false;

  // §7 Hamilton-Jacobi characteristic — momentum-like quantities
  // q_i = ∂ᵢφ,   ∂H/∂φ = 1 − 2A·e^(−2φ)·S
  float HJ_dHdPhi  = 1.0;   // = G_local  (same expression)
  float HJ_dHdS    = 0.0;   // A·e^(−2φ)  — source-gradient force prefactor

  // ── Soft saturation guard ─────────────────────────────────────────────────
  // §12: "Clamp or soft-saturate e^(−2φ) when φ becomes strongly negative."
  // We cap the exponential at expCap to prevent runaway when φ ≪ 0.
  float expCap     = 20.0;

  // ── Smoothing for S ───────────────────────────────────────────────────────
  // §12: "Low-pass filter S before feeding the exponential channel."
  float S_smooth   = 0.3;
  float S_lpAlpha  = 0.12;   // IIR coefficient (lower = smoother)

  // ── Internal bookkeeping ───────────────────────────────────────────────────
  float orb_r_last  = 1.0;   // last orbital radius — for radial table lookup
  boolean sweepActive = false;
  float phi0_bg    = 0.0;   // background field during sweep (§6)
  float S0_bg      = 0.3;   // background source during sweep


  // ===========================================================================
  // update()
  // ===========================================================================
  // Call once per draw() frame, after the RDFT combined field and orbit have
  // been stepped.  Accepts the scalar summaries that proxy ρ and p.
  //
  // avgBright  — average field brightness ≈ ρc² proxy
  // variance   — field variance ≈ 3p proxy (pressure)
  // r          — current orbital radius
  // field      — full RDFT combined field (100×100), for spatial ∇ computation
  // ===========================================================================
  void update(float avgBright, float variance, float r, float[][] field) {

    // 1. Build source S = ρc² + 3p  (§0, §3)
    S_prev  = S;
    float S_raw = constrain(avgBright + 3.0 * variance, 0.01, 2.0);
    S_smooth    = S_smooth + S_lpAlpha * (S_raw - S_smooth);  // §12 low-pass
    S           = S_smooth;
    dS_dt       = S - S_prev;   // finite-difference ∂ₜS

    // 2. Compute φ at current orbital radius from radial lookup table (§5)
    phi_prev = phi;
    orb_r_last = r;
    phi = radialPhi(r);

    // 3. Compute exponential factor — soft-saturated (§12)
    float expFactor = softExp(-2.0 * phi);   // e^(−2φ), capped

    // 4. Compute spatial gradient of φ over the RDFT grid (§1)
    computeGradPhi(field);

    // 5. Residual  F = φ + ½|∇φ|² + A·e^(−2φ)·S  (§0)
    F_prev = F;
    F      = phi + 0.5 * gradPhiMag * gradPhiMag + A * expFactor * S;

    // 6. Gradient of residual ∇F (§1):
    //    ∇F = ∇φ + (∇φ·∇)(∇φ) + A·e^(−2φ)·(∇S − 2S·∇φ)
    // ∇S proxy: finite difference of S over recent frames (simplified to 0
    // because S is spatially uniform in the current model — only ∂ₜS is known).
    // Self-steepening term: (∇φ·∇)(∇φ) ≈ |∇φ|² direction along ∇φ.
    float selfSteep = gradPhiMag * gradPhiMag;  // magnitude of self-steepening
    gradF_x = gradPhi_x + gradPhi_x * selfSteep
              + A * expFactor * (0 - 2.0 * S * gradPhi_x);
    gradF_y = gradPhi_y + gradPhi_y * selfSteep
              + A * expFactor * (0 - 2.0 * S * gradPhi_y);
    gradFMag = sqrt(gradF_x * gradF_x + gradF_y * gradF_y);

    // 7. Local gain  G_local = 1 − 2A·e^(−2φ)·S  (§8)
    float coupling = 2.0 * A * expFactor * S;
    G_local = 1.0 - coupling;

    // 8. Threshold proximity  (§8, §12)
    //    coupling = 2A·e^(−2φ)·S;  threshold at coupling = 1
    thresholdProximity = constrain(coupling, 0, 2.0);  // 1.0 = at threshold

    // 9. Adaptive recursion step  μ → μ / (1 + |F| + |∇φ|²)  (§9)
    mu_adaptive = mu / (1.0 + abs(F) + gradPhiMag * gradPhiMag);

    // 10. Hamilton-Jacobi quantities (§7)
    HJ_dHdPhi = G_local;                 // ∂H/∂φ = 1 − 2A·e^(−2φ)·S
    HJ_dHdS   = A * expFactor;           // prefactor for source-gradient force

    // 11. First-order perturbation φ₁ (§6)
    //     (1 − 2A·e^(−2φ₀)·S₀)φ₁ + ∇φ₀·∇φ₁ ≈ −A·e^(−2φ₀)·S₁
    // During a sweep S₁ = S − S₀; outside a sweep S₁ = dS_dt.
    if (sweepActive) {
      float S1    = S - S0_bg;
      float coeff = 1.0 - 2.0 * A * softExp(-2.0 * phi0_bg) * S0_bg;
      float rhs   = -A * softExp(-2.0 * phi0_bg) * S1;
      // Simple relaxation update for φ₁:
      phi1 = phi1 + mu_adaptive * (rhs - coeff * phi1);
    } else {
      phi1 = 0.0;  // no sweep — no perturbation tracked
    }
    phi1_energy = 0.5 * phi1 * phi1;  // scalar proxy for ½|∇φ₁|²

    // 12. Rebuild radial table if parameters have changed significantly
    //     (Deferred: triggered by caller via rebuildRadialTable() when α/S change)
  }


  // ===========================================================================
  // radialPhi(r)
  // ===========================================================================
  // Returns φ(r) from the precomputed radial ODE table (§5).
  // Falls back to the weak-field approximation (§4) if the table is not yet ready.
  //
  // §5 ODE:   φ′(r) = ±√[−2φ − 2A·S·e^(−2φ)]
  // §4 limit: φ ≈ −A·S  (when |∇φ|² is small)
  // ===========================================================================
  float radialPhi(float r) {
    r = max(r, 0.01);
    if (!radialTableReady) {
      // §4 weak-field fallback: φ ≈ −A·S (leading order, no gradient term)
      // Constrain to keep field negative but not wildly so.
      return constrain(-A * S_smooth, -1.5, 0.0);
    }
    // Linear interpolation in radial table
    float t = constrain(r / max(ORB_BOUND, 0.1), 0, 1);
    float idx = t * (PHI_RADIAL_SAMPLES - 1);
    int i0 = (int)idx;
    int i1 = min(i0 + 1, PHI_RADIAL_SAMPLES - 1);
    float frac = idx - i0;
    return lerp(phiRadial[i0], phiRadial[i1], frac);
  }


  // ===========================================================================
  // rebuildRadialTable(S_for_table)
  // ===========================================================================
  // Numerically integrates the §5 radial ODE outward from r=0 using a simple
  // Euler step.  Should be called when A or S changes significantly
  // (e.g. on COMPUTE, at sweep start, when avgBright shifts > 0.05).
  //
  // §5:  φ′(r) = ±√max(0, −2φ − 2A·S·e^(−2φ))
  //
  // We integrate outward (increasing r), so we choose the positive root and
  // start from a boundary condition: φ(0) = φ_center where the radicand = 0,
  // i.e. −2φ₀ = 2A·S·e^(−2φ₀).  We find φ₀ by Newton iteration, then
  // integrate outward.  If Newton fails we fall back to the weak-field value.
  // ===========================================================================
  void rebuildRadialTable(float S_for_table) {
    // Clamp source to a sensible range
    S_for_table = constrain(S_for_table, 0.01, 2.0);

    // Find φ₀ = φ(r=0): solve  −2φ = 2A·S·e^(−2φ)  i.e. φ + A·S·e^(−2φ) = 0
    // Newton iteration on g(φ) = φ + A·S·e^(−2φ)
    float pv = -A * S_for_table;  // weak-field starting guess (§4)
    for (int iter = 0; iter < 40; iter++) {
      float gv  = pv + A * S_for_table * softExp(-2.0 * pv);
      float dgv = 1.0 - 2.0 * A * S_for_table * softExp(-2.0 * pv);
      if (abs(dgv) < 1e-9) break;
      float step = gv / dgv;
      pv -= step;
      if (abs(step) < 1e-7) break;
    }
    float phi_center = constrain(pv, -3.0, 0.0);

    // Euler integration outward from r=0
    float dr = ORB_BOUND / (float)(PHI_RADIAL_SAMPLES - 1);
    phiRadial[0] = phi_center;
    float phi_cur = phi_center;
    for (int i = 1; i < PHI_RADIAL_SAMPLES; i++) {
      float expF  = softExp(-2.0 * phi_cur);
      float radicand = -2.0 * phi_cur - 2.0 * A * S_for_table * expF;
      if (radicand <= 0) {
        // Radicand non-positive → field is locally complex-valued → clamp and hold
        phiRadial[i] = phi_cur;
      } else {
        float dphi_dr = sqrt(radicand);   // positive root (field rises with r)
        phi_cur = phi_cur + dphi_dr * dr;
        phiRadial[i] = constrain(phi_cur, -3.0, 2.0);
      }
    }
    radialTableReady = true;
  }


  // ===========================================================================
  // computeGradPhi(field)
  // ===========================================================================
  // Estimates ∇φ over the RDFT combined field grid.
  // Uses a central-difference stencil at the grid centre — representative of
  // the global field gradient that enters ∇F in §1.
  // Sampled at a stride to keep it lightweight.
  // ===========================================================================
  void computeGradPhi(float[][] field) {
    if (field == null || field.length < 3) {
      gradPhi_x = 0; gradPhi_y = 0; gradPhiMag = 0;
      return;
    }
    int sz = field.length;
    float gxSum = 0, gySum = 0;
    int count = 0;
    int stride = 8;  // sample every 8th cell — cheap and representative
    for (int row = stride; row < sz - stride; row += stride) {
      for (int col = stride; col < sz - stride; col += stride) {
        gxSum += field[row][col + stride] - field[row][col - stride];
        gySum += field[row + stride][col] - field[row - stride][col];
        count++;
      }
    }
    if (count > 0) {
      gradPhi_x = gxSum / (count * 2.0 * stride);
      gradPhi_y = gySum / (count * 2.0 * stride);
    }
    gradPhiMag = sqrt(gradPhi_x * gradPhi_x + gradPhi_y * gradPhi_y);
  }


  // ===========================================================================
  // orbitalAcceleration(x, y, vx, vy)
  // ===========================================================================
  // Returns the phi-field acceleration components for the orbital integrator,
  // derived from the Hamilton-Jacobi characteristic equations (§7):
  //
  //   dqᵢ/dτ = −∂H/∂xᵢ − qᵢ · ∂H/∂φ
  //           = −A·e^(−2φ)·∂ᵢS − qᵢ · (1 − 2A·e^(−2φ)·S)
  //
  // Here qᵢ = vᵢ (momentum conjugate to position in the HJ sense).
  // The ∂ᵢS term is the source-gradient force (towards denser regions).
  // The qᵢ·G_local term is the field-memory damping/driving term.
  //
  // This replaces the simple Newtonian ax = -g·x/r with a proper
  // characteristic-flow force law grounded in the phi field equation.
  //
  // Returns: float[2] {ax, ay}
  // ===========================================================================
  float[] orbitalAcceleration(float x, float y, float vx, float vy,
                               float gNewt, float r) {
    // Newtonian centripetal base (preserves existing orbit scale)
    float rSafe = max(r, 0.05);
    float ax_newton = -gNewt * x / rSafe;
    float ay_newton = -gNewt * y / rSafe;

    // §7: HJ source-gradient force   −A·e^(−2φ)·∂ᵢS
    // ∂ᵢS is approximated as −(∂ᵢφ)·S because in a spherically symmetric field
    // the source gradient opposes the field gradient.
    float expF  = softExp(-2.0 * phi);
    float HJ_src_x = -A * expF * (-gradPhi_x * S);
    float HJ_src_y = -A * expF * (-gradPhi_y * S);

    // §7: field-memory term   −qᵢ · G_local
    // When G_local < 0 (past threshold), this term flips sign and drives the
    // orbit outward — the HJ runaway the synth treats as a creative boundary.
    float HJ_mem_x = -vx * G_local;
    float HJ_mem_y = -vy * G_local;

    // Blend: Newtonian gives overall orbital shape; HJ terms are a perturbation.
    // Scale HJ contribution by mu_adaptive so it can't dominate at large |F|.
    float hjScale = constrain(mu_adaptive * 2.0, 0, 0.35);
    float ax = ax_newton + hjScale * (HJ_src_x + HJ_mem_x);
    float ay = ay_newton + hjScale * (HJ_src_y + HJ_mem_y);
    return new float[]{ ax, ay };
  }


  // ===========================================================================
  // softExp(x)
  // ===========================================================================
  // §12: soft-saturated exponential — avoids e^(very large positive) when
  // φ is strongly negative (e^(−2φ) would explode).
  // Returns  min(exp(x), expCap).
  // ===========================================================================
  float softExp(float x) {
    if (x > log(expCap)) return expCap;
    return (float)Math.exp(x);
  }


  // ===========================================================================
  // Sweep support (§6)
  // ===========================================================================
  void beginSweep(float phi0, float S0) {
    sweepActive = true;
    phi0_bg     = phi0;
    S0_bg       = S0;
    phi1        = 0.0;
    phi1_energy = 0.0;
  }

  void endSweep() {
    sweepActive = false;
    phi1        = 0.0;
    phi1_energy = 0.0;
  }


  // ===========================================================================
  // oscStatusString()
  // ===========================================================================
  // Human-readable one-liner for the status bar / logging.
  // ===========================================================================
  String oscStatusString() {
    return "φ=" + nf(phi, 1, 3)
         + " F=" + nf(F, 1, 4)
         + " G=" + nf(G_local, 1, 3)
         + " thr=" + nf(thresholdProximity, 1, 3)
         + " |∇F|=" + nf(gradFMag, 1, 3);
  }
}
// =============================================================================
// End PhiFieldEngine.pde
// =============================================================================
