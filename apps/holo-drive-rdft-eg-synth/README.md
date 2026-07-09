# HOLO Drive RDFT EG Synth

## Purpose

HOLO Drive RDFT EG Synth is the Mac migration of the HOLO Drive/RDFT experimental synth. It preserves the Processing/SuperCollider field model, environmental data bridges, CTC channel behavior, Floquet shaping, and surface/topology overlay system.

## Requirements

- Processing 4
- SuperCollider
- Python 3
- Processing libraries: `controlP5`, `oscP5`

## First Run

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements-mac.txt
cp .env.example .env
./start_holo_mac.sh
```

To stop background senders:

```bash
./stop_holo_mac.sh
```

## Controls

The Processing sketch manages RDFT field controls, environmental bridge state, topology overlays, holonomy, CTC channel metrics, and SuperCollider synthesis routing.

## Data Inputs And Outputs

- Solar, ocean, galaxy, and topology bridges can run locally.
- Optional API keys belong in `.env`, never in Git.
- Generated CSVs, logs, recordings, and caches are local artifacts.

## Known Limitations

- This is a Mac migration of a larger hardware-oriented system.
- Thermal and future brainstate layers are preserved as code slots but disabled by default.
- Some public API behavior may drift over time.

## Example Workflow

Create `.env`, run `./start_holo_mac.sh`, evaluate the SuperCollider patch, and use the Processing controls to explore CTC/Floquet/surface coupling.
