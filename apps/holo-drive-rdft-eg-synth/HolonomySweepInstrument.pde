// ═══════════════════════════════════════════════════════════════════════════
// HOLONOMY SWEEP INSTRUMENT  —  drop-in tab
// ═══════════════════════════════════════════════════════════════════════════
//
// Plain parametric rectangle-loop instrumentation:
//
//   you set the loop, you press RUN, it traverses, it logs. Nothing aborts it.
//
// Path is a rectangle in (alpha, depth) parameter space — the minimal closed
// loop with nonzero enclosed area, which is what holonomy needs:
//
//     (a0,d0) ──leg0──▶ (a1,d0)
//        ▲                 │
//      leg3              leg1
//        │                 ▼
//     (a0,d1) ◀──leg2── (a1,d1)
//
// Field snapshots are fed to berryTracker exactly when computeFrames() fires
// (fixing the inverted snapshot throttle), and closeSweepLoop() is called only
// when the path geometrically returns to (a0,d0) — a true closed loop, so the
// closure overlap is physically meaningful and the S4 winding can be sealed.
//
// There is NO recovery mode. The only concession to load is an OPTIONAL lag
// pause (default OFF): if sustained fps collapses below a floor, the leg clock
// simply freezes in place and resumes when fps recovers. Position is held,
// nothing resets, no targets snap back.
//
// ── INTEGRATION (4 lines) ──────────────────────────────────────────────────
//  1. setup():    createHolonomySweepControls(HOLO_PANEL_X, HOLO_PANEL_Y);
//                 (set the two constants below to your bottom-left section origin)
//  2. draw():     holoSweep.update();
//  3. draw():     drawHolonomySweepPanel(HOLO_PANEL_X, HOLO_PANEL_Y, HOLO_PANEL_W, HOLO_PANEL_H);
//  4. This instrument owns rectangle-loop traversal and holonomy sealing.
//
// ── CSV LOGGER HOOK ────────────────────────────────────────────────────────
// Your per-frame logger can read these public fields (same column names you
// already log): holoSweep.legIndex, .legProgress, .loopIndex, .loopClosedFlag,
// .lastHolonomyRad, .lastBerryNorm, .lastLoopArea, .lastReturnError,
// .running, .pausedForLag.
// Per-loop results additionally append to data/holonomy_sweep_results.csv.
//
// ── BERRYPHASETRACKER PATCHES (apply in your tracker tab) ──────────────────
// PATCH 1 — double-counted closure when ring buffer wraps (>=64 snapshots):
//     in closeSweepLoop(), main product loop:
//        for (int k = 0; k < n - 1; k++)    // CORRECT
//
// PATCH 2 — row-seam artifact in gradient-as-imaginary (everywhere the
// pattern appears, both in norm precompute and both overlap loops):
//        float im = (i > 0) ? v[i] - v[i-1] : 0;                  // WRONG
//        float im = (i % GRID != 0) ? v[i] - v[i-1] : 0;          // CORRECT
//     (the flattened index crosses a grid-row boundary every GRID cells;
//      the difference across that seam is not a spatial gradient)
// ═══════════════════════════════════════════════════════════════════════════

// Position of the panel — point these at your existing bottom-left section.
final int HOLO_PANEL_X = 16;
final int HOLO_PANEL_Y = 684;
final int HOLO_PANEL_W = 300;
final int HOLO_PANEL_H = 210;

HoloSweepInstrumentState holoSweep = new HoloSweepInstrumentState();

Textfield hsFieldA0, hsFieldA1, hsFieldD0, hsFieldD1;
Textfield hsFieldLegTime, hsFieldDwell, hsFieldLoops, hsFieldPairs;
Button    hsBtnRun, hsBtnRunRev, hsBtnOrient, hsBtnStop, hsBtnLagPause, hsBtnFreeze;

// ─────────────────────────────────────────────────────────────────────────────
// GUI construction. Call once from setup().
// ─────────────────────────────────────────────────────────────────────────────
void createHolonomySweepControls(int px, int py) {
  int fx = px + 12;
  int fy = py + 34;
  int fw = 56, fh = 18, gap = 8;

  cp5.addTextlabel("hsTitle")
    .setText("HOLONOMY SWEEP — RECTANGLE LOOP")
    .setPosition(px + 10, py + 8)
    .setColorValue(color(190, 215, 255));

  hsFieldA0 = hsMakeField("hsA0", fx,                 fy, fw, fh, safeNf(alpha, 1, 2));
  hsFieldA1 = hsMakeField("hsA1", fx + fw + gap,      fy, fw, fh, "3.50");
  hsFieldD0 = hsMakeField("hsD0", fx + 2*(fw + gap),  fy, fw, fh, str(depth));
  hsFieldD1 = hsMakeField("hsD1", fx + 3*(fw + gap),  fy, fw, fh, str(min(depth + 2, 7)));

  int fy2 = fy + fh + 22;
  hsFieldLegTime = hsMakeField("hsLegTime", fx,                fy2, fw, fh, "20");
  hsFieldDwell   = hsMakeField("hsDwell",   fx + fw + gap,     fy2, fw, fh, "4");
  hsFieldLoops   = hsMakeField("hsLoops",   fx + 2*(fw + gap), fy2, fw, fh, "1");
  hsFieldPairs   = hsMakeField("hsFieldPairs", fx + 3*(fw + gap), fy2, fw, fh, "6");

  // Keep controls outside the readout box so leg/progress/holonomy text stays clear.
  int bxCtl = px + HOLO_PANEL_W + 12;
  int by = py + 10;
  int bwCtl = 110;
  int bhCtl = 22;
  int bgap = 8;
  hsBtnRun = cp5.addButton("HSRUN")
    .setPosition(bxCtl, by).setSize(bwCtl, bhCtl).setLabel("RUN")
    .setColorBackground(color(25, 95, 45));
  hsBtnRunRev = cp5.addButton("HSRUNREV")
    .setPosition(bxCtl, by + (bhCtl + bgap)).setSize(bwCtl, bhCtl).setLabel("RUN REVERSED")
    .setColorBackground(color(70, 55, 95));
  hsBtnOrient = cp5.addButton("HSORIENT")
    .setPosition(bxCtl, by + 2 * (bhCtl + bgap)).setSize(bwCtl, bhCtl).setLabel("RUN ORIENTATION")
    .setColorBackground(color(40, 95, 80));
  hsBtnStop = cp5.addButton("HSSTOP")
    .setPosition(bxCtl, by + 3 * (bhCtl + bgap)).setSize(bwCtl, bhCtl).setLabel("STOP")
    .setColorBackground(color(95, 35, 30));
  hsBtnLagPause = cp5.addButton("HSLAGPAUSE")
    .setPosition(bxCtl, by + 4 * (bhCtl + bgap)).setSize(bwCtl, bhCtl).setLabel("LAG PAUSE: OFF")
    .setColorBackground(color(60, 60, 60));
  hsBtnFreeze = cp5.addButton("HSFREEZE")
    .setPosition(bxCtl, by + 5 * (bhCtl + bgap)).setSize(bwCtl, bhCtl).setLabel("ENV: LIVE")
    .setColorBackground(color(60, 60, 60));
}

Textfield hsMakeField(String name, int x, int y, int w, int h, String initial) {
  return cp5.addTextfield(name)
    .setPosition(x, y).setSize(w, h)
    .setAutoClear(false)
    .setText(initial)
    .setColorBackground(color(18, 24, 32))
    .setCaptionLabel("");
}

// ─────────────────────────────────────────────────────────────────────────────
// Control handlers
// ─────────────────────────────────────────────────────────────────────────────
void HSRUN(int v) {
  hsLaunchSweep(false);
}

void HSRUNREV(int v) {
  hsLaunchSweep(true);
}

void hsLaunchSweep(boolean reversed) {
  if (holoSweep != null) {
    holoSweep.cancelOrientationIfRunning("manual run");
    holoSweep.clearOrientationTags();
  }

  float a0 = constrain(parseTextFloat(hsFieldA0, alpha),       1.0, 4.5);
  float a1 = constrain(parseTextFloat(hsFieldA1, 3.5),         1.0, 4.5);
  int   d0 = round(constrain(parseTextFloat(hsFieldD0, depth), 0, 7));
  int   d1 = round(constrain(parseTextFloat(hsFieldD1, depth), 0, 7));
  float legT  = constrain(parseTextFloat(hsFieldLegTime, 20), 2.0, 300.0);
  float dwell = constrain(parseTextFloat(hsFieldDwell, 4),    0.0,  60.0);
  int   loops = round(constrain(parseTextFloat(hsFieldLoops, 1), 1, 99));

  // Reflect clamped values back so the boxes always show what will run.
  // Fields always show the forward corners; reversal happens at launch only.
  hsFieldA0.setText(safeNf(a0, 1, 2));  hsFieldA1.setText(safeNf(a1, 1, 2));
  hsFieldD0.setText(str(d0));           hsFieldD1.setText(str(d1));
  hsFieldLegTime.setText(safeNf(legT, 1, 1));
  hsFieldDwell.setText(safeNf(dwell, 1, 1));
  hsFieldLoops.setText(str(loops));

  if (a0 == a1 && d0 == d1) {
    statusMsg = "Holonomy sweep: zero-area loop (a0==a1, d0==d1) — nothing to enclose";
    return;
  }

  // Swap the alpha pair only to reverse traversal around the same rectangle.
  float startA = reversed ? a1 : a0;
  float endA   = reversed ? a0 : a1;

  holoSweep.start(startA, endA, d0, d1, legT, dwell, loops);
  statusMsg = "Holonomy sweep " + (reversed ? "REVERSED" : "FORWARD")
            + ": a[" + safeNf(startA,1,2) + " -> " + safeNf(endA,1,2) + "]"
            + " d[" + d0 + " -> " + d1 + "]";
}

void HSSTOP(int v) {
  if (holoSweep != null && holoSweep.cancelOrientationIfRunning("manual stop")) return;
  holoSweep.stop("manual stop");
}

void HSORIENT(int v) {
  if (holoSweep != null) {
    holoSweep.orientLaunchOrAbort();
  }
}

void HSLAGPAUSE(int v) {
  holoSweep.lagPauseEnabled = !holoSweep.lagPauseEnabled;
  hsBtnLagPause.setLabel(holoSweep.lagPauseEnabled ? "LAG PAUSE: ON" : "LAG PAUSE: OFF");
  hsBtnLagPause.setColorBackground(holoSweep.lagPauseEnabled ? color(30, 80, 55) : color(60, 60, 60));
}

void HSFREEZE(int v) {
  envFloquetFrozen = !envFloquetFrozen;
  if (envFloquetFrozen) {
    // Capture the current LIVE values and hold them.
    envFloquetCouplingHeld    = envFloquetCouplingLive();
    envFloquetQuasienergyHeld = envFloquetQuasienergyLive();
    statusMsg = "ENV FLOQUET FROZEN: kappa=" + safeNf(envFloquetCouplingHeld,1,4)
              + " eps=" + safeNf(envFloquetQuasienergyHeld,1,4);
  } else {
    statusMsg = "ENV FLOQUET LIVE (unfrozen)";
  }
  if (hsBtnFreeze != null) {
    hsBtnFreeze.setLabel(envFloquetFrozen ? "ENV: FROZEN" : "ENV: LIVE");
    hsBtnFreeze.setColorBackground(envFloquetFrozen ? color(120, 90, 30) : color(60, 60, 60));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The instrument
// ─────────────────────────────────────────────────────────────────────────────
class HoloSweepInstrumentState {

  // ── configuration (set at start()) ──
  float a0, a1;
  int   d0, d1;
  float legDuration;        // seconds per leg
  float dwellDuration;      // seconds held at each corner
  int   totalLoops;

  // ── live state ──
  boolean running = false;
  boolean dwelling = false;
  boolean pausedForLag = false;
  int     legIndex = 0;             // 0..3
  int     loopIndex = 0;            // completed loops
  float   legProgress = 0;          // 0..1 within current leg
  float   legClock = 0;             // seconds elapsed in current leg/dwell
  int     lastTickMs = 0;

  // ── recompute throttle (same philosophy as AdiabaticTracker) ──
  final int   MIN_COMPUTE_INTERVAL_MS  = 160;
  final float MIN_ALPHA_STEP_RECOMPUTE = 0.035;
  int   lastHeavyComputeMs = 0;
  float lastComputedAlpha  = -999;
  int   lastComputedDepth  = -999;

  // ── lag pause (optional, default OFF) ──
  boolean lagPauseEnabled = false;
  final float LAG_FPS_FLOOR    = 8.0;   // pause below this
  final float LAG_FPS_RESUME   = 14.0;  // resume above this
  final float LAG_SUSTAIN_SEC  = 2.0;   // must persist this long to trigger
  float lagAccum = 0;
  float fpsSmoothed = 30;

  // ── Orientation-test sequencer ─────────────────────────────────────────────
  boolean orientRunActive    = false;
  int     orientPairTarget   = 6;       // pairs to run (read from field at launch)
  int     orientPairDone     = 0;       // completed pairs
  boolean orientPhaseReverse = false;   // false = forward loop of pair, true = reverse loop
  int     orientRunId        = 0;       // increments each batch; tags CSV rows
  int     orientLoopSeq      = 0;       // 0,1,2,... over the whole batch (F=even, R=odd)
  int     orientStage        = 0;       // 0 idle, 1 await completion/log seal, 2 await rearm
  int     orientStageEnterMs = 0;
  float   orientFwdAreaCheck = 0;       // first forward area, for sign-flip verification
  boolean orientPreflightOK  = false;
  String  orientStatus       = "orientation: idle";
  float   orientA0, orientA1;
  int     orientD0, orientD1;
  float   orientLegT, orientDwell;
  int     orientTagRunId     = 0;       // row tag for the loop currently sealing
  int     orientTagLoopSeq   = -1;      // -1 outside an orientation batch
  final int ORIENT_REARM_TIMEOUT_MS = 20000;

  // ── results / logging ──
  int     loopClosedFlag = 0;       // set at loop close; main CSV logger consumes it
  float   lastHolonomyRad = 0;
  float   lastBerryNorm   = 0;
  float   lastLoopArea    = 0;      // shoelace area of actual traversed path
  float   lastReturnError = 0;      // |alpha_end - a0| + |depth_end - d0|
  int     lastSnapCount   = 0;
  ArrayList<Float> pathA = new ArrayList<Float>();
  ArrayList<Float> pathD = new ArrayList<Float>();
  PrintWriter resultsWriter = null;
  String  statusLine = "idle";

  // corner coordinates per leg: leg i goes corner[i] -> corner[i+1]
  float cornerA(int i) { i = ((i % 4) + 4) % 4; return (i == 0 || i == 3) ? a0 : a1; }
  int   cornerD(int i) { i = ((i % 4) + 4) % 4; return (i == 0 || i == 1) ? d0 : d1; }

  void start(float pa0, float pa1, int pd0, int pd1, float legT, float dwellT, int loops) {
    a0 = pa0; a1 = pa1; d0 = pd0; d1 = pd1;
    legDuration = legT; dwellDuration = dwellT; totalLoops = loops;

    running = true; dwelling = false; pausedForLag = false;
    legIndex = 0; loopIndex = 0; legProgress = 0; legClock = 0;
    lastTickMs = millis();
    lastHeavyComputeMs = 0; lastComputedAlpha = -999; lastComputedDepth = -999;
    loopClosedFlag = 0;
    pathA.clear(); pathD.clear();
    lagAccum = 0; fpsSmoothed = 30;

    // Jump to origin corner and arm the berry tracker fresh.
    applyParams(a0, d0, true);
    if (berryTracker != null) berryTracker.reset();
    snapshotNow();

    floquetSweepStarted();
    openResultsWriter();
    statusLine = "running";
    statusMsg = "Holonomy sweep: " + describeLoop() + "  x" + totalLoops + " loop(s)";
    println("=== HOLONOMY SWEEP START === " + describeLoop() +
            "  legT=" + safeNf(legDuration,1,1) + "s dwell=" + safeNf(dwellDuration,1,1) +
            "s loops=" + totalLoops);
  }

  void stop(String why) {
    if (!running) return;
    running = false;
    pausedForLag = false;
    statusLine = "stopped (" + why + ")";
    statusMsg = "Holonomy sweep stopped: " + why;
    floquetSweepStopped();
    closeResultsWriter();
    println("=== HOLONOMY SWEEP STOP === " + why +
            " at leg " + legIndex + " progress " + safeNf(legProgress,1,3));
  }

  String describeLoop() {
    return "a[" + safeNf(a0,1,2) + " - " + safeNf(a1,1,2) + "] x d[" + d0 + " - " + d1 + "]";
  }

  boolean isOrientationRunning() {
    return orientRunActive;
  }

  boolean cancelOrientationIfRunning(String why) {
    if (!orientRunActive) return false;
    orientAbort(why);
    return true;
  }

  void orientLaunchOrAbort() {
    if (orientRunActive) {
      orientAbort("operator stop");
      return;
    }
    if (!envFloquetFrozen) {
      statusMsg = "ORIENTATION: freeze the environment first (ENV: FROZEN) before running.";
      return;
    }

    orientA0 = constrain(parseTextFloat(hsFieldA0, alpha), 1.0, 4.5);
    orientA1 = constrain(parseTextFloat(hsFieldA1, 3.5),  1.0, 4.5);
    orientD0 = round(constrain(parseTextFloat(hsFieldD0, depth), 0, 7));
    orientD1 = round(constrain(parseTextFloat(hsFieldD1, depth), 0, 7));
    orientLegT  = constrain(parseTextFloat(hsFieldLegTime, 8), 2.0, 300.0);
    orientDwell = constrain(parseTextFloat(hsFieldDwell, 2),  0.0,  60.0);
    orientPairTarget = round(constrain(parseTextFloat(hsFieldPairs, 6), 1, 50));

    hsFieldA0.setText(safeNf(orientA0, 1, 2));  hsFieldA1.setText(safeNf(orientA1, 1, 2));
    hsFieldD0.setText(str(orientD0));           hsFieldD1.setText(str(orientD1));
    hsFieldLegTime.setText(safeNf(orientLegT, 1, 1));
    hsFieldDwell.setText(safeNf(orientDwell, 1, 1));
    hsFieldPairs.setText(str(orientPairTarget));

    if (orientA0 == orientA1) {
      statusMsg = "ORIENTATION: alpha corners equal — zero-width loop, nothing to enclose.";
      return;
    }
    if (orientD0 == orientD1) {
      statusMsg = "ORIENTATION: depth corners equal — zero-height loop, nothing to enclose.";
      return;
    }

    orientRunActive = true;
    orientPreflightOK = false;
    orientPairDone = 0;
    orientLoopSeq = 0;
    orientPhaseReverse = false;
    orientRunId++;
    orientStage = 1;
    orientStageEnterMs = millis();
    orientStatus = "orientation: run " + orientRunId + " starting (" + orientPairTarget + " pairs)";
    statusMsg = orientStatus;
    updateOrientButton();
    orientFireCurrentLoop();
  }

  void orientTick() {
    if (!orientRunActive) return;

    if (!envFloquetFrozen) {
      orientAbort("environment unfrozen during orientation run");
      return;
    }

    if (orientStage == 1) {
      if (!running) {
        if (loopClosedFlag == 1 && oscLoggingEnabled && oscLogWriter != null) {
          orientStatus = "orientation run " + orientRunId + ": waiting CSV seal for seq " + orientLoopSeq;
          statusMsg = orientStatus;
          return;
        }
        orientCompleteCurrentLoop();
      }
      return;
    }

    if (orientStage == 2) {
      boolean rearmed = (fsLifecycleState == FS_STATE_ARMED);
      boolean timedOut = (millis() - orientStageEnterMs) > ORIENT_REARM_TIMEOUT_MS;
      if (rearmed || timedOut) {
        if (timedOut && !rearmed) {
          println("[Orientation] rearm timeout; launching next loop from lifecycle state " + fsLifecycleState);
        }
        orientStage = 1;
        orientStageEnterMs = millis();
        orientFireCurrentLoop();
      } else {
        orientStatus = "orientation run " + orientRunId + ": waiting ARMED  pair "
          + (orientPairDone + 1) + "/" + orientPairTarget;
        statusMsg = orientStatus;
      }
    }
  }

  void orientCompleteCurrentLoop() {
    if (!oscLoggingEnabled || oscLogWriter == null) {
      loopClosedFlag = 0;
    }

    if (orientLoopSeq == 0) {
      orientFwdAreaCheck = lastLoopArea;
    }

    if (orientLoopSeq == 1 && !orientPreflightOK) {
      boolean flipped = (orientFwdAreaCheck * lastLoopArea) < 0;
      if (!flipped) {
        orientAbort("PREFLIGHT FAIL: area did not change sign (fwd="
          + safeNf(orientFwdAreaCheck,1,2) + " rev=" + safeNf(lastLoopArea,1,2)
          + ") — reversed run not working; batch aborted.");
        return;
      }
      orientPreflightOK = true;
    }

    orientLoopSeq++;
    if (orientPhaseReverse) {
      orientPairDone++;
      orientPhaseReverse = false;
    } else {
      orientPhaseReverse = true;
    }

    if (orientPairDone >= orientPairTarget) {
      orientFinish();
      return;
    }

    orientStage = 2;
    orientStageEnterMs = millis();
    orientStatus = "orientation run " + orientRunId + ": waiting ARMED  pair "
      + (orientPairDone + 1) + "/" + orientPairTarget;
    statusMsg = orientStatus;
  }

  void orientFireCurrentLoop() {
    orientTagRunId = orientRunId;
    orientTagLoopSeq = orientLoopSeq;
    loopClosedFlag = 0;

    float startA = orientPhaseReverse ? orientA1 : orientA0;
    float endA   = orientPhaseReverse ? orientA0 : orientA1;
    this.start(startA, endA, orientD0, orientD1, orientLegT, orientDwell, 1);
    orientStatus = "orientation run " + orientRunId + ": "
      + (orientPhaseReverse ? "REVERSE" : "FORWARD")
      + " seq " + orientLoopSeq + "  pair " + (orientPairDone + 1) + "/" + orientPairTarget;
    statusMsg = orientStatus;
    updateOrientButton();
  }

  void orientFinish() {
    orientRunActive = false;
    orientStage = 0;
    orientTagLoopSeq = -1;
    orientStatus = "orientation run " + orientRunId + " COMPLETE: " + orientPairDone + " pairs logged.";
    statusMsg = orientStatus;
    updateOrientButton();
  }

  void orientAbort(String why) {
    if (running) stop("orientation abort");
    orientRunActive = false;
    orientStage = 0;
    orientTagLoopSeq = -1;
    orientStatus = "orientation ABORTED: " + why;
    statusMsg = orientStatus;
    println("[Orientation] " + why);
    updateOrientButton();
  }

  void clearOrientationTags() {
    orientTagRunId = 0;
    orientTagLoopSeq = -1;
  }

  void updateOrientButton() {
    if (hsBtnOrient == null) return;
    hsBtnOrient.setLabel(orientRunActive ? "ORIENT: STOP" : "RUN ORIENTATION");
    hsBtnOrient.setColorBackground(orientRunActive ? color(120, 70, 40) : color(40, 95, 80));
  }

  // ── main tick: call every frame from draw() ──
  void update() {
    if (!running) return;

    int nowMs = millis();
    float dt = (nowMs - lastTickMs) / 1000.0;
    lastTickMs = nowMs;
    dt = constrain(dt, 0, 0.25);   // clamp pathological frame gaps

    // fps tracking for the optional lag pause
    float instFps = (dt > 0.0001) ? 1.0 / dt : 60;
    fpsSmoothed = lerp(fpsSmoothed, instFps, 0.12);
    if (lagPauseEnabled) {
      if (!pausedForLag) {
        if (fpsSmoothed < LAG_FPS_FLOOR) {
          lagAccum += dt;
          if (lagAccum >= LAG_SUSTAIN_SEC) {
            pausedForLag = true;
            statusLine = "lag pause (fps " + safeNf(fpsSmoothed,1,1) + ") — holding position";
            println("Holonomy sweep: lag pause engaged (fps=" + safeNf(fpsSmoothed,1,1) + ")");
          }
        } else {
          lagAccum = 0;
        }
      } else if (fpsSmoothed > LAG_FPS_RESUME) {
        pausedForLag = false;
        lagAccum = 0;
        statusLine = "running";
        println("Holonomy sweep: lag pause released");
      }
    } else {
      pausedForLag = false;
      lagAccum = 0;
    }
    if (pausedForLag) return;   // clock frozen, position held, nothing resets

    legClock += dt;

    if (dwelling) {
      if (legClock >= dwellDuration) {
        dwelling = false;
        legClock = 0;
        advanceLeg();
      }
      return;
    }

    legProgress = constrain(legClock / legDuration, 0, 1);
    float s = legProgress * legProgress * (3 - 2 * legProgress);  // smoothstep

    float fromA = cornerA(legIndex),     toA = cornerA(legIndex + 1);
    int   fromD = cornerD(legIndex);     int toD = cornerD(legIndex + 1);
    float nextAlpha = lerp(fromA, toA, s);
    int   nextDepth = round(lerp(fromD, toD, s));

    applyParams(nextAlpha, nextDepth, legProgress >= 1.0);

    if (legProgress >= 1.0) {
      // Pin exactly onto the corner so return error is honest.
      applyParams(toA, toD, true);
      legClock = 0;
      legProgress = 0;
      if (dwellDuration > 0.001) {
        dwelling = true;
        statusLine = "dwell @ corner " + ((legIndex + 1) % 4);
      } else {
        advanceLeg();
      }
    }
  }

  void advanceLeg() {
    legIndex++;
    if (legIndex >= 4) {
      // Path has geometrically returned to (a0, d0): the loop is truly closed.
      sealLoop();
      legIndex = 0;
      loopIndex++;
      if (loopIndex >= totalLoops) {
        running = false;
        statusLine = "complete — γ=" + safeNf(lastHolonomyRad,1,4) + " rad";
        statusMsg = "Holonomy sweep complete: γ=" + safeNf(lastHolonomyRad,1,4) +
                    " rad over " + totalLoops + " loop(s)";
        closeResultsWriter();
      } else {
        // Re-arm tracker so each loop yields an independent holonomy reading.
        if (berryTracker != null) berryTracker.reset();
        snapshotNow();
        statusLine = "running — loop " + (loopIndex + 1) + "/" + totalLoops;
      }
    } else {
      statusLine = "running — leg " + legIndex + "/4";
    }
  }

  void sealLoop() {
    lastReturnError = abs(alpha - a0) + abs(depth - d0);
    lastSnapCount = (berryTracker != null) ? berryTracker.snapCount : 0;
    if (berryTracker != null && berryTracker.snapCount >= 256) {
      println("[Crossing] WARNING: snapshot ring saturated (" + berryTracker.snapCount +
              ") - outbound leg may be overwritten; shorten legs or raise MAX_SNAPS.");
    }
    lastLoopArea = shoelaceArea();

    if (berryTracker != null) {
      berryTracker.closeSweepLoop();
      lastHolonomyRad = berryTracker.holonomyRaw;
      lastBerryNorm   = berryTracker.berryPhase;
      metricBerryPhase = berryTracker.berryPhase;
    }
    floquetCrossingSealed(lastHolonomyRad, lastLoopArea);
    loopClosedFlag = 1;
    logLoopResult();
    println("=== LOOP SEALED === loop " + (loopIndex + 1) + "/" + totalLoops +
            "  γ=" + safeNf(lastHolonomyRad,1,5) + " rad" +
            "  area=" + safeNf(lastLoopArea,1,4) +
            "  returnErr=" + safeNf(lastReturnError,1,5) +
            "  snaps=" + lastSnapCount);
    pathA.clear(); pathD.clear();
  }

  // Signed area of the actually-traversed path in (alpha, depth) space.
  // Ideal rectangle gives ±(a1-a0)*(d1-d0); deviation flags imperfect traversal.
  float shoelaceArea() {
    int n = pathA.size();
    if (n < 3) return 0;
    float area = 0;
    for (int i = 0; i < n; i++) {
      int j = (i + 1) % n;
      area += pathA.get(i) * pathD.get(j) - pathA.get(j) * pathD.get(i);
    }
    return area * 0.5;
  }

  // ── parameter application with the proven throttle, plus CORRECT snapshot
  //    timing: snapshot fires on the same frame the field actually recomputes ──
  void applyParams(float nextAlpha, int nextDepth, boolean force) {
    alpha = safeAlphaValue(nextAlpha);
    depth = safeDepthValue(nextDepth);

    boolean depthChanged = (nextDepth != lastComputedDepth);
    boolean alphaMoved   = abs(nextAlpha - lastComputedAlpha) >= MIN_ALPHA_STEP_RECOMPUTE;
    boolean enoughTime   = millis() - lastHeavyComputeMs >= MIN_COMPUTE_INTERVAL_MS;

    if ((enoughTime && (depthChanged || alphaMoved)) || force) {
      sliderAlpha.setValue(alpha);
      sliderDepth.setValue(depth);
      if (fieldAlpha != null) fieldAlpha.setText(safeNf(alpha, 1, 2));
      if (fieldDepth != null) fieldDepth.setText(str(depth));
      layerCache = null;
      computeFrames();
      lastHeavyComputeMs = millis();
      lastComputedAlpha = nextAlpha;
      lastComputedDepth = nextDepth;
      snapshotNow();                 // fresh field -> snapshot NOW, not later
      pathA.add(alpha);
      pathD.add((float)depth);
    }
  }

  void snapshotNow() {
    if (berryTracker != null && combined != null) {
      // Phase-bearing snapshot: injects sin/cos of Floquet and orbital phase,
      // orbital position+velocity, entropy, Lyapunov into the state vector.
      // These conjugate pairs carry the genuine winding of the traversal;
      // the raw field alone is real-positive and yields gamma near zero.
      berryTracker.addStateSnapshot(alpha, (float)depth);
    }
  }

  // ── per-loop results CSV ──
  void openResultsWriter() {
    if (resultsWriter != null) return;
    try {
      File outFile = new File(dataPath("holonomy_sweep_results.csv"));
      File parent = outFile.getParentFile();
      if (parent != null) parent.mkdirs();
      boolean fresh = !outFile.exists();
      resultsWriter = new PrintWriter(new FileWriter(outFile, true));
      if (fresh) {
        resultsWriter.println("wall_time,session_t,loop,a0,a1,d0,d1,leg_s,dwell_s," +
          "holonomy_rad,berry_norm,loop_area,return_error,snapshots,fps_mean");
      }
    } catch (Exception e) {
      println("Holonomy sweep: results writer failed: " + e);
      resultsWriter = null;
    }
  }

  void logLoopResult() {
    if (resultsWriter == null) return;
    resultsWriter.println(
      System.currentTimeMillis() + "," + safeNf(millis()/1000.0,1,3) + "," + (loopIndex + 1) + "," +
      safeNf(a0,1,3) + "," + safeNf(a1,1,3) + "," + d0 + "," + d1 + "," +
      safeNf(legDuration,1,1) + "," + safeNf(dwellDuration,1,1) + "," +
      safeNf(lastHolonomyRad,1,6) + "," + safeNf(lastBerryNorm,1,6) + "," +
      safeNf(lastLoopArea,1,5) + "," + safeNf(lastReturnError,1,6) + "," +
      lastSnapCount + "," + safeNf(fpsSmoothed,1,1));
    resultsWriter.flush();
  }

  void closeResultsWriter() {
    if (resultsWriter != null) { resultsWriter.flush(); resultsWriter.close(); resultsWriter = null; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel rendering — bottom-left. Call every frame from draw().
// ─────────────────────────────────────────────────────────────────────────────
void drawHolonomySweepPanel(int x, int y, int w, int h) {
  noStroke();
  fill(12, 16, 22, 235);
  rect(x, y, w, h, 6);
  stroke(holoSweep.running ? color(90, 160, 255, 160) : color(70, 80, 95, 120));
  noFill();
  rect(x, y, w, h, 6);

  // column labels above the textfields
  fill(120, 140, 165);
  textSize(9);
  textAlign(LEFT, BOTTOM);
  int fx = x + 12, fw = 56, gap = 8;
  text("α start", fx, y + 32);
  text("α far",   fx + fw + gap, y + 32);
  text("d start", fx + 2*(fw + gap), y + 32);
  text("d far",   fx + 3*(fw + gap), y + 32);
  text("leg (s)", fx, y + 32 + 40);
  text("dwell",   fx + fw + gap, y + 32 + 40);
  text("loops",   fx + 2*(fw + gap), y + 32 + 40);
  text("pairs",   fx + 3*(fw + gap), y + 32 + 40);

  // status + progress
  int sy = y + h - 64;
  fill(holoSweep.pausedForLag ? color(255, 190, 90) : color(170, 200, 235));
  textSize(10);
  textAlign(LEFT, TOP);
  String live = holoSweep.running
    ? ("LEG " + holoSweep.legIndex + "/4   loop " + (holoSweep.loopIndex + 1) + "/" + holoSweep.totalLoops +
       (holoSweep.dwelling ? "   [dwell]" : "") +
       "   α=" + safeNf(alpha,1,2) + "  d=" + depth)
    : holoSweep.statusLine;
  text(live, x + 12, sy);

  // progress bar: whole-loop progress (4 legs + dwells)
  float legUnit = 1.0 / 4.0;
  float p = holoSweep.running
    ? constrain(holoSweep.legIndex * legUnit + (holoSweep.dwelling ? legUnit : holoSweep.legProgress * legUnit), 0, 1)
    : 0;
  int bx = x + 12, bw = w - 24, bh = 8, by2 = sy + 16;
  noStroke();
  fill(28, 36, 48);
  rect(bx, by2, bw, bh, 3);
  fill(holoSweep.pausedForLag ? color(220, 160, 60) : color(80, 150, 255));
  rect(bx, by2, bw * p, bh, 3);

  // last sealed result
  fill(150, 230, 170);
  int tx = x + 12;
  int ty = by2 + 14;
  text("gamma = " + safeNf(berryTracker.holonomyRaw, 1, 4) + " rad  ("
       + safeNf(berryTracker.holonomyRaw / PI, 1, 3) + " pi)", tx, ty);
  text("winding = " + berryTracker.holonomyWindingTurns + " turn(s)"
       + "   |  curvature = "
       + safeNf((abs(holoSweep.lastLoopArea) > 1e-6)
           ? berryTracker.holonomyRaw / holoSweep.lastLoopArea : 0, 1, 4)
       + " rad/area", tx, ty + 16);
}
