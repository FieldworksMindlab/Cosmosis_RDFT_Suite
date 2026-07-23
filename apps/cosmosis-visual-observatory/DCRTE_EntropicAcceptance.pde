/* DCRTE-ET Milestone 5 deterministic and stateless seeded acceptance. */

final int DCRTE_ENTROPIC_RANDOM_SALT = 0x5EED5105;

interface SchedulerAcceptancePolicy {
  SchedulerBatch select(FrontierEvaluation frontier, SchedulerConfiguration config,
    int batchIndex);
  String getId();
  String getVersion();
  JSONObject toJSON();
}

class ConfiguredEntropicAcceptance implements SchedulerAcceptancePolicy {
  final AcceptanceMode mode;
  final float temperature;

  ConfiguredEntropicAcceptance(AcceptanceMode mode, float temperature) {
    this.mode = mode == null ? AcceptanceMode.DETERMINISTIC_TOP_K : mode;
    this.temperature = temperature;
  }

  public SchedulerBatch select(FrontierEvaluation frontier, SchedulerConfiguration config,
      int batchIndex) {
    SchedulerBatch batch = new SchedulerBatch();
    batch.batchIndex = batchIndex;
    if (frontier == null || frontier.records == null || config == null
        || config.entropy == null) {
      batch.event = "acceptance_invalid";
      return batch;
    }
    EntropyConfiguration entropy = config.entropy;
    int count = frontier.records.length;
    int[] order = new int[count];
    for (int i = 0; i < count; i++) order[i] = i;
    dcrteSortEntropicScoreOrder(order, frontier.records);
    int cap = min(max(1, entropy.maxUpdatesPerBatch), count);
    int[] accepted = new int[cap];
    int acceptedCount = 0;
    for (int rank = 0; rank < order.length; rank++) {
      EntropicScoreRecord scoreRecord = frontier.records[order[rank]];
      scoreRecord.thresholdEligible = scoreRecord.terms.combinedScore >= entropy.scoreThreshold;
      boolean selected = false;
      if (mode == AcceptanceMode.DETERMINISTIC_THRESHOLD) {
        scoreRecord.acceptanceProbability = scoreRecord.thresholdEligible ? 1 : 0;
        selected = scoreRecord.thresholdEligible;
      } else if (mode == AcceptanceMode.DETERMINISTIC_TOP_K) {
        scoreRecord.thresholdEligible = scoreRecord.terms.combinedScore >= entropy.minimumTopKScore;
        scoreRecord.acceptanceProbability = scoreRecord.thresholdEligible ? 1 : 0;
        selected = scoreRecord.thresholdEligible;
      } else {
        scoreRecord.acceptanceProbability = dcrteEntropicSigmoid(
          (scoreRecord.terms.combinedScore - entropy.scoreThreshold)
          / max(0.000001f, temperature));
        scoreRecord.statelessRandomValue = dcrteDeterministicUnitRandom(
          entropy.schedulerSeed, batchIndex, scoreRecord.voxelIndex,
          DCRTE_ENTROPIC_RANDOM_SALT);
        selected = scoreRecord.statelessRandomValue < scoreRecord.acceptanceProbability;
      }
      if (selected && acceptedCount < cap) {
        scoreRecord.accepted = true;
        accepted[acceptedCount++] = scoreRecord.voxelIndex;
      }
    }
    batch.attemptedUpdates = count;
    batch.acceptedUpdates = acceptedCount;
    batch.activatedIndices = java.util.Arrays.copyOf(accepted, acceptedCount);
    batch.event = mode.id();
    frontier.summarizeAccepted();
    return batch;
  }

  public String getId() { return mode.id(); }
  public String getVersion() { return "1.0-m5"; }
  public JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("id", getId());
    json.setString("version", getVersion());
    json.setFloat("acceptance_temperature", temperature);
    json.setString("random_version", "m5-mix64-1");
    json.setInt("policy_salt", DCRTE_ENTROPIC_RANDOM_SALT);
    return json;
  }
}

float dcrteEntropicSigmoid(float value) {
  if (!dcrteFinite(value)) return value > 0 ? 1 : 0;
  if (value >= 20) return 1;
  if (value <= -20) return 0;
  return (float)(1.0 / (1.0 + Math.exp(-value)));
}

float dcrteDeterministicUnitRandom(long schedulerSeed, int batchIndex,
    int voxelIndex, int policyVersionSalt) {
  long value = schedulerSeed;
  value ^= ((long)batchIndex * 0x9E3779B97F4A7C15L);
  value ^= ((long)voxelIndex * 0xBF58476D1CE4E5B9L);
  value ^= ((long)policyVersionSalt * 0x94D049BB133111EBL);
  value = dcrteMix64(value);
  return (float)((value >>> 40) * (1.0 / (1L << 24)));
}

void dcrteSortEntropicScoreOrder(int[] order, EntropicScoreRecord[] records) {
  if (order == null || order.length < 2) return;
  dcrteQuickSortEntropicScoreOrder(order, 0, order.length - 1, records);
}

void dcrteQuickSortEntropicScoreOrder(int[] order, int low, int high,
    EntropicScoreRecord[] records) {
  int i = low, j = high;
  int pivot = order[(low + high) >>> 1];
  while (i <= j) {
    while (dcrteEntropicRecordBefore(records[order[i]], records[pivot])) i++;
    while (dcrteEntropicRecordBefore(records[pivot], records[order[j]])) j--;
    if (i <= j) {
      int temp = order[i];
      order[i] = order[j];
      order[j] = temp;
      i++;
      j--;
    }
  }
  if (low < j) dcrteQuickSortEntropicScoreOrder(order, low, j, records);
  if (i < high) dcrteQuickSortEntropicScoreOrder(order, i, high, records);
}

boolean dcrteEntropicRecordBefore(EntropicScoreRecord a, EntropicScoreRecord b) {
  if (a.terms.combinedScore > b.terms.combinedScore) return true;
  if (a.terms.combinedScore < b.terms.combinedScore) return false;
  return a.voxelIndex < b.voxelIndex;
}
