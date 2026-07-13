/* DCRTE-ET Milestone 1 immediate, render-cadence-independent activation. */

class ImmediateScheduler {
  String getId() { return "immediate"; }
  String getVersion() { return "1.0"; }
  boolean activate(boolean admitted, boolean candidateSolid) {
    return admitted && candidateSolid;
  }

  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", getId());
    json.setString("version", getVersion());
    json.setBoolean("stateful", false);
    json.setString("relational_progress", "not_applicable");
    return json;
  }
}

ImmediateScheduler dcrteImmediateScheduler = new ImmediateScheduler();
