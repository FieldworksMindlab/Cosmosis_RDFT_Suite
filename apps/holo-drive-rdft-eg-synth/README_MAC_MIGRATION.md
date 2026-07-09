# HOLO Drive Mac Migration

This folder is the Mac migration copy of the Raspberry Pi project. The original archive remains untouched in Downloads.

## What changed

- Python senders are run as a local package with `start_holo_mac.sh`.
- Solar weather sends UDP packets to Processing on `127.0.0.1:5060`.
- The synthetic topology/spectral-geometry surface sender sends orbital overlays to Processing on `127.0.0.1:5056`.
- Galaxy maps refresh into `maps/` before the GUI opens.
- The Raspberry Pi thermal layer is preserved in code but disabled with `THERMAL_LAYER_ENABLED = false`.
- A future BCI/brainstate replacement slot is reserved with `BRAINSTATE_LAYER_ENABLED = false`.
- The RDFT/Mallett document has been integrated as `CTCChannelEngine.pde`.
  Processing now computes `ctcProximity`, shows a CTC glyph in Spectral Geometry, sends `/rdf/ctcState` to SuperCollider, and applies the 1:5 Vaidya-style Floquet asymmetry near threshold.
- SuperCollider still listens on OSC port `60001`.
- Processing still listens for its sender inputs locally.

## First-time Python setup

```bash
cd /path/to/HOLO_DRIVE_RDFT_EG_SYNTH
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements-mac.txt
cp .env.example .env
```

The solar sender can run without third-party packages. Galaxy map live refresh needs the packages in `requirements-mac.txt`; if they are missing, existing map files remain usable.
The surface sender uses only Python's standard library.

## Run

```bash
cd /path/to/HOLO_DRIVE_RDFT_EG_SYNTH
source .venv/bin/activate
./start_holo_mac.sh
```

Then boot/evaluate `ColdSun_Shimmer.scd` in SuperCollider and run the Processing sketch if the apps did not open automatically.

If Processing is already running and only the orbital topology overlay is missing, start just the surface sender:

```bash
cd /path/to/HOLO_DRIVE_RDFT_EG_SYNTH
source .venv/bin/activate
python surface_sender.py
```

Use the Processing `SURF: ON/OFF` and `SURF: NEXT` controls to toggle the overlay and cycle topology modes.

## CTC Channel Mode

The CTC channel is automatic. It derives its state from the existing synth metrics:

- phi threshold proximity
- local phi gain
- orbit lock strength
- Lyapunov contraction
- Berry phase
- EG injected voltage
- solar x-ray and solar wind normalization

The Spectral Geometry module shows a compact `CTC` ring/readout. Zones are `IDLE`, `APPROACH`, `THRESHOLD`, and `INSIDE`.

SuperCollider receives the state at `/rdf/ctcState` and adds a low closure tone when the channel approaches threshold. The Floquet shaper attenuates sine coefficients toward `0.20` as `ctcProximity` rises past `0.70`, matching the document's outgoing/ingoing 1:5 asymmetry concept.

## Surface / Topology Modes

The surface sender supports synthetic topology, fractal topology, and real terrain:

```bash
python surface_sender.py --mode gyroid
python surface_sender.py --mode mandelbrot
python surface_sender.py --mode julia
python surface_sender.py --mode fractal_ridge
python surface_sender.py --mode real_topography --terrain-source opentopodata --terrain-preset grand_canyon
```

Available terrain presets:

- `grand_canyon`
- `mauna_loa`
- `iceland_rift`
- `st_helens`
- `yosemite`

Available terrain sources:

- `opentopodata`: no API key, point-sampled DEM API.
- `opentopography`: uses OpenTopography global DEM API and requires `OPENTOPO_API_KEY`.
- `fallback`: local synthetic terrain, useful offline.

To start the full package directly in real terrain mode, copy `.env.example` to `.env` and set:

```bash
SURFACE_MODE=real_topography
SURFACE_TERRAIN_SOURCE=opentopodata
SURFACE_TERRAIN_PRESET=grand_canyon
SURFACE_TERRAIN_BATCH_DELAY=1.1
```

For OpenTopography, set:

```bash
SURFACE_MODE=real_topography
SURFACE_TERRAIN_SOURCE=opentopography
SURFACE_TERRAIN_DEMTYPE=SRTMGL1
OPENTOPO_API_KEY=your_key_here
```

OpenTopoData point sampling is rate-limited, so a fresh 32x32 terrain cache can take several seconds. After the terrain is cached under `maps/surface_cache/`, normal starts reuse the local copy.

## Stop Background Senders

```bash
./stop_holo_mac.sh
```

## Processing Libraries

Install these in Processing using Sketch -> Import Library -> Manage Libraries:

- controlP5
- oscP5

## Thermal Layer

The thermal layer is disabled for Mac because the RPi4 sensor hardware is not present. To restore the old layer on sensor hardware, change:

```java
final boolean THERMAL_LAYER_ENABLED = false;
```

to:

```java
final boolean THERMAL_LAYER_ENABLED = true;
```

For the future BCI version, the clean replacement point is the same area near the top of the main Processing file:

```java
final boolean BRAINSTATE_LAYER_ENABLED = false;
```
