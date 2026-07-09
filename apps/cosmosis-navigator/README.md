# Cosmosis Navigator

## Purpose

Cosmosis Navigator is the original RDFT performance and research instrument in this suite. It combines Processing-based field dynamics, SuperCollider synthesis routing, holonomy and quantum panels, environmental bridges, and topology/surface control.

## Requirements

- Processing 4
- SuperCollider
- Python 3 for bridge/sender scripts
- Processing libraries: `controlP5`, `oscP5`

## First Run

```bash
./start_cosmosis.sh
```

or open `Cosmosis_Navigator.pde` directly in Processing 4 and boot the SuperCollider patch manually.

## Controls

The sketch includes panels for field controls, holonomy, quantum logic/measurement, topology, surface overlays, environmental data, and synthesis routing. See in-app labels and `RUN_CHLADNI_SPHERE.md` for the closest current operation notes.

## Data Inputs And Outputs

- Python bridges can provide solar, ocean, galaxy, and surface/topology data.
- SuperCollider receives OSC synthesis state.
- CSV run logs and generated outputs are local artifacts and are ignored by default in this public repo.

## Known Limitations

- BasinNET is intentionally excluded from this first public release.
- Launch scripts are currently macOS-oriented.
- Some scripts may still need local path review as the suite becomes more portable.

## Example Workflow

Start the synth, enable environmental bridges, perform or record a run, then load the resulting CSV into the Hopf Visualization Kit or Cosmosis Visual Observatory for analysis.
