# Cosmosis RDFT Suite

**Explore a field. Play it as sound. Turn its geometry into something you can build.**

Cosmosis RDFT Suite is a collection of experimental instruments for moving between sound, interactive geometry, data, and physical form. Explore recursive fields, follow a recorded run through a Hopf projection, or generate a geodesic dome kit with printable parts and an assembly plan.

The shared research language is Recursive Differential Field Theory (RDFT). The tools bring that exploration into Processing, SuperCollider, and Python, with source you can run, study, fork, and extend.

## Explore the Programs

### [Cosmosis Visual Observatory](apps/cosmosis-visual-observatory/) — from live fields to physical forms

An interactive visual laboratory spanning field atlases, phase, topology, and fabrication. Start here to explore geometry without an audio setup, then follow a field from the screen into a mesh or a kit of parts.

- **Holonomy Loom** lets you explore a woven field atlas and capture it for Surface Foundry, preserving the same field through mesh generation.
- **Surface Foundry** turns field geometry into STL meshes, reliefs, and drafting sheets, with primitive and imported-mesh workflows.
- **Geodesic Salon** builds domes and spheres, then exports reusable panel types, quantities, and illustrated assembly guides. Legacy zip-tie assemblies use straight shared passages, with up to three portals per edge where the part size allows.
- **Truss Yard** builds modular towers and tunnels from triangle frames, with reusable printable parts and assembly plans.

[Open the Observatory →](apps/cosmosis-visual-observatory/README.md) · [Explore the fabrication architecture →](docs/architecture/overview.md)

### [Cosmosis Navigator](apps/cosmosis-navigator/) — play the field

A performance and research instrument connecting interactive field dynamics to SuperCollider synthesis. Shape the field with Chladni/RDFT controls, explore holonomy and topology panels, and bring solar, ocean, or galaxy data into a session through environmental bridges. Record a run, then inspect its trajectories with the Hopf Visualization Kit.

[Launch Navigator →](apps/cosmosis-navigator/README.md)

### [HOLO Drive RDFT EG Synth](apps/holo-drive-rdft-eg-synth/) — explore coupled sound and geometry

An experimental Processing/SuperCollider synth with Floquet shaping, CTC channel controls, and surface/topology overlays. This Mac migration preserves the HOLO Drive instrument and its environmental bridges for hands-on exploration of how changing field controls affects the synthesis system.

[Launch HOLO Drive →](apps/holo-drive-rdft-eg-synth/README.md)

### [RDFT Hopf Visualization Kit](apps/rdft-hopf-visualization-kit/) — step inside a recorded run

Turn RDFT CSV recordings into interactive 3D trajectories. Orbit a Hopf projection, switch to PCA or winding-space views, and color the path by velocity, holonomy, or curvature. Generate Berry and dimensional portrait dashboards, export spinning GIFs, or bring the data into TouchDesigner.

[Open the viewer →](apps/rdft-hopf-visualization-kit/README.md)

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

## Research Prospectus

The [Fieldworks MindLAB prospectus package](docs/fieldworks-mindlab/README.md)
collects the foundational organizational prospectus, technical appendices,
combined omnibus edition, editable source document, and public-safe source
register.

## Status

This is an active experimental research suite. Expect sharp edges, Mac-oriented launch scripts, and systems that mix formal modeling with creative instrumentation. The code is shared to preserve the work and make the conceptual machinery available for exploration.
