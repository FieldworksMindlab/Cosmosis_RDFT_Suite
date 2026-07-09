# RDFT Chladni Sphere Synth

## Purpose

RDFT Chladni Sphere Synth is a performance-focused version of the RDFT synth. It keeps the field, orbit, holonomy, Floquet, surface, environmental, and SuperCollider synthesis model while presenting a clearer playable sphere interface.

## Requirements

- Processing 4
- SuperCollider
- Python 3 for bridge/sender scripts
- Processing libraries: `controlP5`, `oscP5`

## First Run

```bash
./start_chladni_mac.sh
```

To stop background senders:

```bash
./stop_chladni_mac.sh
```

## Controls

- Main sphere: playable field/orbit surface.
- Left rail: compact RDFT diagnostic panels.
- Right rail: transport, holonomy, layer, surface, and performance controls.
- Bottom strip: field, frequency, modulation, ocean/solar, and recording controls.

## Data Inputs And Outputs

- Receives environmental bridge values from local Python senders.
- Sends RDFT and performance state to SuperCollider over OSC.
- Generates local CSV run logs for downstream analysis.

## Known Limitations

- macOS launch scripts are the maintained path.
- Full SuperCollider behavior requires the associated `.scd` patch.
- Generated logs and recordings are intentionally not tracked.

## Example Workflow

Launch the synth, shape the sphere interaction and environmental layers, record a run, then inspect the run in `apps/rdft-hopf-visualization-kit`.
