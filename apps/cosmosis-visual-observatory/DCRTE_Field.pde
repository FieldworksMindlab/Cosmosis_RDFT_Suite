/*
  DCRTE-ET Milestone 0 field compatibility layer.

  The adapter is diagnostic only. Surface Foundry generation continues to call
  the legacy direct field path until a later milestone explicitly changes it.
*/

final int DCRTE_ADAPTER_SAMPLE_COUNT = 256;
final float DCRTE_ADAPTER_TOLERANCE = 0.0000001f;
final int DCRTE_ADAPTER_REFRESH_FRAMES = 30;
final String DCRTE_LEGACY_DIRECT_VERSION = "legacy-topology-scalar-v1";

enum DCRTEPipelineMode {
  LEGACY_DIRECT,
  DCRTE_ADAPTER_TEST;

  String id() {
    return name();
  }
}

interface FieldEngine {
  void configure(DCRTEConfig config);
  float sample(PVector worldPosition, float[] topologyBlend);
  String getId();
  String getVersion();
}

class LegacyTopologyScalarAdapter implements FieldEngine {
  DCRTEConfig configuredSnapshot;

  public void configure(DCRTEConfig config) {
    configuredSnapshot = config;
  }

  public float sample(PVector worldPosition, float[] topologyBlend) {
    return topologyScalar(worldPosition.x, worldPosition.y, worldPosition.z, topologyBlend);
  }

  public String getId() {
    return "legacy_topology_scalar_adapter";
  }

  public String getVersion() {
    return "0.1.0-m0";
  }
}

class DCRTEAdapterDiagnostics {
  String status = "IDLE";
  float maxAbsoluteError = 0;
  float meanAbsoluteError = 0;
  int sampleCount = 0;
  int comparedFrame = -1;
  String configurationId = "";

  boolean passed() {
    return status.equals("PASS");
  }
}

DCRTEPipelineMode dcrtePipelineMode = DCRTEPipelineMode.LEGACY_DIRECT;
FieldEngine dcrteFieldEngine = null;
DCRTEAdapterDiagnostics dcrteAdapterDiagnostics = new DCRTEAdapterDiagnostics();
DCRTEConfig dcrteLastConfiguration = null;
int dcrteLastComparisonFrame = -9999;

void initializeDcrteMilestone0() {
  dcrteFieldEngine = new LegacyTopologyScalarAdapter();
  dcrteLastConfiguration = captureDcrteConfig();
  dcrteFieldEngine.configure(dcrteLastConfiguration);
}

void cycleDcrtePipelineMode() {
  if (dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT) {
    dcrtePipelineMode = DCRTEPipelineMode.DCRTE_ADAPTER_TEST;
    runDcrteAdapterComparison();
  } else {
    dcrtePipelineMode = DCRTEPipelineMode.LEGACY_DIRECT;
    dcrteAdapterDiagnostics.status = "IDLE";
  }
}

void updateDcrteMilestone0() {
  if (dcrtePipelineMode != DCRTEPipelineMode.DCRTE_ADAPTER_TEST) return;
  if (frameCount - dcrteLastComparisonFrame < DCRTE_ADAPTER_REFRESH_FRAMES) return;
  runDcrteAdapterComparison();
}

void runDcrteAdapterComparison() {
  if (dcrteFieldEngine == null) dcrteFieldEngine = new LegacyTopologyScalarAdapter();
  DCRTEConfig config = captureDcrteConfig();
  dcrteFieldEngine.configure(config);
  float[] scores = config.topologyBlendCopy();
  float maxError = 0;
  double sumError = 0;
  boolean finite = true;

  for (int i = 0; i < DCRTE_ADAPTER_SAMPLE_COUNT; i++) {
    PVector point = dcrteDeterministicPoint(i);
    float direct = topologyScalar(point.x, point.y, point.z, scores);
    float adapted = dcrteFieldEngine.sample(point, scores);
    float error = abs(direct - adapted);
    if (Float.isNaN(error) || Float.isInfinite(error)) {
      finite = false;
      break;
    }
    maxError = max(maxError, error);
    sumError += error;
  }

  dcrteAdapterDiagnostics.maxAbsoluteError = maxError;
  dcrteAdapterDiagnostics.meanAbsoluteError = finite ? (float)(sumError / DCRTE_ADAPTER_SAMPLE_COUNT) : Float.NaN;
  dcrteAdapterDiagnostics.sampleCount = finite ? DCRTE_ADAPTER_SAMPLE_COUNT : 0;
  dcrteAdapterDiagnostics.comparedFrame = frameCount;
  dcrteAdapterDiagnostics.configurationId = config.configurationId;
  dcrteAdapterDiagnostics.status = finite && maxError <= DCRTE_ADAPTER_TOLERANCE ? "PASS" : "WARN";
  dcrteLastConfiguration = config;
  dcrteLastComparisonFrame = frameCount;
}

PVector dcrteDeterministicPoint(int index) {
  int sampleIndex = index + 1;
  return new PVector(
    dcrteRadicalInverse(sampleIndex, 2) * 2.0f - 1.0f,
    dcrteRadicalInverse(sampleIndex, 3) * 2.0f - 1.0f,
    dcrteRadicalInverse(sampleIndex, 5) * 2.0f - 1.0f
  );
}

float dcrteRadicalInverse(int value, int base) {
  float result = 0;
  float fraction = 1.0f / base;
  int remaining = value;
  while (remaining > 0) {
    result += (remaining % base) * fraction;
    remaining /= base;
    fraction /= base;
  }
  return result;
}

String dcrtePipelineLabel() {
  return dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT ? "LEGACY" : "ADAPTER TEST";
}

String dcrteGenerationFieldEngineId() {
  if (dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT) return "legacy_topology_scalar_direct";
  return dcrteFieldEngine == null ? "legacy_topology_scalar_adapter" : dcrteFieldEngine.getId();
}

String dcrteGenerationFieldEngineVersion() {
  if (dcrtePipelineMode == DCRTEPipelineMode.LEGACY_DIRECT) return DCRTE_LEGACY_DIRECT_VERSION;
  return dcrteFieldEngine == null ? "0.1.0-m0" : dcrteFieldEngine.getVersion();
}
