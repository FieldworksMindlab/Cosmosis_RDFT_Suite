/**
 * QuantumMeasurementEngine.pde
 *
 * Measurement-aware statistical layer for Cosmosis Navigator.
 *
 * V1 is intentionally non-invasive: it computes quantum-analog diagnostics,
 * Born-rule outcome sampling, and an internal collapse/memory trace only when
 * Q-LOGIC is enabled. It does not overwrite the main field or audio state.
 */

class QuantumMeasurementEngine {
  final int BASIS_POSITION  = 0;
  final int BASIS_CHIRALITY = 1;
  final int BASIS_ENERGY    = 2;
  final int OUTCOME_COUNT   = 4;

  boolean enabled = false;
  int basis = BASIS_POSITION;
  boolean autoMeasure = false;

  float measurementStrength = 0.35;
  float collapseDepth = 0.22;
  float reopenRate = 0.035;
  float memoryPersistence = 0.86;

  int measurementId = 0;
  int selectedOutcome = -1;
  float selectedProbability = 0.0;
  int bornSeed = 0;
  int lastMeasureMs = -999999;

  float[] distribution = new float[OUTCOME_COUNT];
  float distributionEntropy = 0.0;

  float psiAmpMean = 0.0;
  float psiAmpPeak = 0.0;
  float psiPhaseMean = 0.0;
  float psiPhaseVariance = 0.0;
  float probabilityWeightPeak = 0.0;

  float chiralityIndex = 0.0;
  int chiralitySign = 0;
  float fieldTorqueProxy = 0.0;
  float windingNumber = 0.0;
  int lobeCount = 0;
  int phaseSingularityCount = 0;

  float collapsePulse = 0.0;
  float memoryTrace = 0.0;
  float entropyBeforeMeasurement = 0.0;
  float entropyAfterMeasurement = 0.0;
  float entropyDeltaAfterMeasurement = 0.0;
  float coherenceDeltaAfterMeasurement = 0.0;
  float stateUpdateEnergy = 0.0;

  void update(
    boolean active, float[][] field,
    float entropy, float coherence, float berryPhase,
    float rootFreq, float floquetCoupling, float floquetPhase,
    int floquetCycle, int orbitLobes, int nowMs
  ) {
    enabled = active;

    float reopen = constrain(reopenRate, 0.0, 1.0);
    collapsePulse = max(0.0, collapsePulse - reopen);
    memoryTrace *= constrain(memoryPersistence, 0.0, 0.999);
    stateUpdateEnergy = collapsePulse * measurementStrength;

    if (!enabled || field == null || field.length < 3 || field[0].length < 3) {
      return;
    }

    computePsiStats(field, floquetPhase, orbitLobes);
    computeDistribution(entropy, coherence, berryPhase, rootFreq, floquetCoupling, floquetCycle);

    if (autoMeasure && nowMs - lastMeasureMs > 1600) {
      performMeasurement(nowMs);
    }
  }

  void computePsiStats(float[][] field, float floquetPhase, int orbitLobes) {
    int rows = field.length;
    int cols = field[0].length;
    int rStep = max(1, rows / 28);
    int cStep = max(1, cols / 28);
    float ampSum = 0.0;
    float phaseX = 0.0;
    float phaseY = 0.0;
    float torque = 0.0;
    float gradSum = 0.0;
    float singular = 0.0;
    int n = 0;

    float[] posWeights = new float[OUTCOME_COUNT];
    psiAmpPeak = 0.0;
    probabilityWeightPeak = 0.0;

    for (int r = 1; r < rows - 1; r += rStep) {
      for (int c = 1; c < cols - 1; c += cStep) {
        float v = constrain(field[r][c], 0.0, 1.0);
        float amp = sqrt(max(v, 0.0));
        float gx = field[r][min(cols - 1, c + 1)] - field[r][max(0, c - 1)];
        float gy = field[min(rows - 1, r + 1)][c] - field[max(0, r - 1)][c];
        float phase = atan2(gy, gx) + floquetPhase;
        float px = map(c, 0, cols - 1, -1.0, 1.0);
        float py = map(r, 0, rows - 1, -1.0, 1.0);
        float gmag = sqrt(gx * gx + gy * gy);
        int q = (px >= 0 ? 1 : 0) + (py >= 0 ? 2 : 0);

        posWeights[q] += amp * amp + 0.0001;
        ampSum += amp;
        psiAmpPeak = max(psiAmpPeak, amp);
        probabilityWeightPeak = max(probabilityWeightPeak, amp * amp);
        phaseX += cos(phase);
        phaseY += sin(phase);
        torque += px * gy - py * gx;
        gradSum += gmag;
        if (amp < 0.12 && gmag > 0.18) singular += 1.0;
        n++;
      }
    }

    if (n <= 0) return;

    psiAmpMean = ampSum / n;
    psiPhaseMean = atan2(phaseY, phaseX);
    float phaseLock = sqrt(phaseX * phaseX + phaseY * phaseY) / n;
    psiPhaseVariance = constrain(1.0 - phaseLock, 0.0, 1.0);
    fieldTorqueProxy = torque / max(1.0, n * 0.08);
    chiralityIndex = constrain(fieldTorqueProxy, -1.0, 1.0);
    chiralitySign = chiralityIndex > 0.04 ? 1 : (chiralityIndex < -0.04 ? -1 : 0);
    lobeCount = max(1, orbitLobes);
    windingNumber = chiralityIndex * max(1.0, lobeCount) * 0.5;
    phaseSingularityCount = round(singular);

    if (basis == BASIS_POSITION) {
      copyNormalized(posWeights, distribution);
      distributionEntropy = normalizedEntropy(distribution, OUTCOME_COUNT);
    }
  }

  void computeDistribution(
    float entropy, float coherence, float berryPhase,
    float rootFreq, float floquetCoupling, int floquetCycle
  ) {
    float[] w = new float[OUTCOME_COUNT];

    if (basis == BASIS_POSITION) {
      // Already computed directly from amp^2 quadrant weights.
      return;
    } else if (basis == BASIS_CHIRALITY) {
      float right = max(0.0, chiralityIndex);
      float left = max(0.0, -chiralityIndex);
      float balanced = max(0.0, 1.0 - abs(chiralityIndex));
      float winding = constrain(abs(windingNumber) * 0.45 + abs(berryPhase) * 0.10, 0.0, 1.0);
      w[0] = left + 0.001;
      w[1] = right + 0.001;
      w[2] = balanced * 0.75 + 0.001;
      w[3] = winding + 0.001;
    } else {
      float low = constrain((1.0 - entropy) * 0.45 + (1.0 - floquetCoupling) * 0.20, 0.001, 1.0);
      float mid = constrain(coherence * 0.55 + floquetCoupling * 0.30, 0.001, 1.0);
      float high = constrain(entropy * 0.45 + probabilityWeightPeak * 0.35, 0.001, 1.0);
      float side = constrain((sin(floquetCycle * 0.35 + rootFreq * 0.01) * 0.5 + 0.5) * floquetCoupling + 0.05, 0.001, 1.0);
      w[0] = low;
      w[1] = mid;
      w[2] = high;
      w[3] = side;
    }

    copyNormalized(w, distribution);
    distributionEntropy = normalizedEntropy(distribution, OUTCOME_COUNT);
  }

  void performMeasurement(int nowMs) {
    if (!enabled) return;
    bornSeed = (int)(System.currentTimeMillis() & 0x7fffffff) ^ frameCount ^ (measurementId * 1103515245);
    java.util.Random rng = new java.util.Random((long)bornSeed);
    float pick = rng.nextFloat();
    float accum = 0.0;
    selectedOutcome = OUTCOME_COUNT - 1;
    for (int i = 0; i < OUTCOME_COUNT; i++) {
      accum += distribution[i];
      if (pick <= accum) {
        selectedOutcome = i;
        break;
      }
    }
    selectedProbability = distribution[selectedOutcome];
    measurementId++;
    lastMeasureMs = nowMs;

    entropyBeforeMeasurement = distributionEntropy;
    float collapse = constrain(measurementStrength * collapseDepth, 0.0, 1.0);
    entropyAfterMeasurement = distributionEntropy * (1.0 - collapse * 0.45);
    entropyDeltaAfterMeasurement = entropyAfterMeasurement - entropyBeforeMeasurement;
    coherenceDeltaAfterMeasurement = collapse * (1.0 - distributionEntropy) * 0.35;
    collapsePulse = max(collapsePulse, collapse);
    memoryTrace = constrain(memoryTrace + collapse * selectedProbability, 0.0, 1.0);
    stateUpdateEnergy = collapsePulse * measurementStrength;
  }

  void copyNormalized(float[] src, float[] dst) {
    float sum = 0.0;
    for (int i = 0; i < OUTCOME_COUNT; i++) sum += max(0.0, src[i]);
    if (sum <= 0.0) sum = 1.0;
    for (int i = 0; i < OUTCOME_COUNT; i++) dst[i] = max(0.0, src[i]) / sum;
  }

  float normalizedEntropy(float[] p, int count) {
    float h = 0.0;
    for (int i = 0; i < count; i++) {
      if (p[i] > 0.000001) h -= p[i] * (log(p[i]) / log(2));
    }
    return constrain(h / max(0.0001, log(count) / log(2)), 0.0, 1.0);
  }

  String basisName() {
    if (basis == BASIS_CHIRALITY) return "CHIRALITY";
    if (basis == BASIS_ENERGY) return "ENERGY";
    return "POSITION";
  }

  String outcomeName() {
    return outcomeName(selectedOutcome);
  }

  String outcomeName(int idx) {
    if (idx < 0) return "NONE";
    if (basis == BASIS_POSITION) {
      if (idx == 0) return "NW LOBE";
      if (idx == 1) return "NE LOBE";
      if (idx == 2) return "SW LOBE";
      return "SE LOBE";
    }
    if (basis == BASIS_CHIRALITY) {
      if (idx == 0) return "LEFT";
      if (idx == 1) return "RIGHT";
      if (idx == 2) return "BALANCED";
      return "WINDING";
    }
    if (idx == 0) return "LOW BAND";
    if (idx == 1) return "MID BAND";
    if (idx == 2) return "HIGH BAND";
    return "SIDEBAND";
  }
}
