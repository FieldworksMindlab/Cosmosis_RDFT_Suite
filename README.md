# Cosmosis RDFT Suite

Cosmosis RDFT Suite is an experimental creative-code research environment for exploring Recursive Differential Field Theory through interactive audio, visual, geometric, and data-driven instruments. It brings together Processing sketches, SuperCollider synthesis systems, environmental data bridges, Hopf/topology visualization tools, material-profile adapters, and Surface Foundry workflows for printable topology and drafting artifacts.

The goal of this repository is preservation and invitation: a durable public archive that others can run, study, fork, and extend.

## Project Map

- `apps/cosmosis-navigator` - the mature Cosmosis performance/research instrument, combining the developed Chladni/RDFT synth interface, field dynamics, synthesis control, environmental bridges, quantum/holonomy panels, and SuperCollider routing.
- `apps/cosmosis-visual-observatory` - a visual-only RDFT laboratory with field atlases, topology lab, material targets, Surface Foundry, call-sheet generation, relief/STL workflows, and DCRTE primitive observation domains.
- `apps/holo-drive-rdft-eg-synth` - the Mac migration of the HOLO Drive RDFT/EG synth, including Floquet shaping, solar/ocean/galaxy bridges, CTC channel behavior, and SuperCollider integration.
- `apps/rdft-hopf-visualization-kit` - Python/PyGFX and TouchDesigner tools for Hopf, PCA, Berry, winding, and manifold portrait views from RDFT CSV runs.

## Quick Starts

Visual-only workspace:

```bash
open apps/cosmosis-visual-observatory/Cosmosis_Visual_Observatory.pde
```

Audio synth workspace:

```bash
cd apps/cosmosis-navigator
./start_cosmosis.sh
```

Hopf viewer:

```bash
cd apps/rdft-hopf-visualization-kit
./setup_mac.sh
./run_viewer.sh
```

Surface Foundry:

```text
Open Cosmosis Visual Observatory, select Surface Foundry, press G to generate a mesh, then C to generate call sheets and relief/STL artifacts.
```

Surface Foundry also includes an opt-in `DCRTE PRIMITIVE` pipeline for observing
the unchanged field through sphere, box, or cylinder constraints with validated
hard-interior and inward shell-band materialization.

## Requirements

- Processing 4 for the Processing sketches.
- SuperCollider for the audio-driven synth projects.
- Python 3.10+ recommended for adapters, senders, Hopf tools, and relief utilities.
- TouchDesigner is optional for the Hopf visualization kit.
- Some environmental data bridges use public APIs; keys are optional unless noted in each app.

## Repository Policy

This repo intentionally keeps source and curated samples, not every local output. Generated logs, recordings, caches, call-sheet output, exported STLs, virtual environments, private `.env` files, and large data archives are ignored. Regenerate those locally from the app workflows.

BasinNET is intentionally deferred for a later public cleanup pass. See `docs/roadmap/basinnet.md`.

## Status

This is an active experimental research suite. Expect sharp edges, Mac-oriented launch scripts, and systems that mix formal modeling with creative instrumentation. The code is shared to preserve the work and make the conceptual machinery available for exploration.
