# RDFT Hopf Visualization Kit

This folder packages the PyGFX Hopf manifold viewer and the TouchDesigner Script SOP helper around the `06/15` RDFT Chladni run.

## Quick Start

```bash
cd apps/rdft-hopf-visualization-kit
./setup_mac.sh
./run_viewer.sh
```

You can also double-click either launcher in Finder:

```text
RDFT Hopf Viewer.app
RDFT Hopf Viewer.command
```

The default launch opens the phase-derived Hopf projection from:

```text
data/osc_state_2026-06-23_18-23-44.csv
```

## Viewer Controls

- Drag: orbit camera
- Scroll: zoom
- Drop CSV onto window: load dataset
- `O`: open CSV file picker
- `P`: generate/open Berry portrait dashboard for the current CSV
- `D`: generate/open dimensional portrait dashboard for the current CSV
- `E`: record/export spinning GIFs and portrait graphs for the current CSV
- `M`: cycle path metric color
- `V`: color path by velocity
- `B`: color path by holonomy / Berry phase
- `C`: color path by curvature density
- `1`: Hopf base trajectory
- `2`: phase-derived Hopf projection
- `3`: PCA manifold embedding
- `4`: winding-space transit
- `A`: toggle auto-rotation
- `Space`: pause or resume transit marker
- `T`: toggle dissipative trail
- `G`: cycle trail glow strength
- `Y`: toggle tesseract scaffold
- `R`: reset camera
- `H`: print help

## Other Views

```bash
./run_viewer.sh --view base
./run_viewer.sh --view pca
./run_viewer.sh --view winding
```

Metric color encodings:

```bash
./run_viewer.sh --view phase --metric velocity
./run_viewer.sh --view base --metric holonomy
./run_viewer.sh --view winding --metric curvature
./run_viewer.sh --view pca --metric time
```

## Portrait Pages

Generate dashboard pages inspired by the Berry/Hopf and dimensional analysis references:

```bash
./run_dashboard.sh --page berry --open
./run_dashboard.sh --page dimensional --open
```

Use a different CSV:

```bash
./run_dashboard.sh data/your_osc_state_file.csv --page berry --open
```

Generated PNGs are written to `dashboards/`.

## Recording Package

Press `E` in the viewer to generate a timestamped recording package for the current CSV. It writes low-data spinning GIFs for `base`, `phase`, `pca`, and `winding`, cycling through metric coloring during the spin, plus fresh Berry and dimensional portrait PNGs.

Terminal version:

```bash
./run_recording.sh
./run_recording.sh data/your_osc_state_file.csv --frames 48 --fps 10 --open-folder
```

Outputs are written to `recordings/<csv-name>_recording_<timestamp>/`.

## Schema Compatibility

The viewer supports both older Hopf CSVs and the current Cosmosis schema. In particular, the phase projection accepts either `hopf_link_proxy` or the newer `hopf_fieldorient_proxy`, with fourth-sphere columns included in PCA/dashboard analysis when present.

Trail options:

```bash
./run_viewer.sh --trail-length 260
./run_viewer.sh --no-trails
```

## Loading Datasets

List datasets already copied into this project:

```bash
./list_datasets.sh
```

Use any CSV by passing it as the first argument:

```bash
./run_viewer.sh "/absolute/path/to/osc_state_file.csv" --view phase
```

While the viewer is open, drag an `osc_state_*.csv` file onto the window, or press `O` to choose one with a file picker.

Or set `CSV_PATH`:

```bash
CSV_PATH="/absolute/path/to/osc_state_file.csv" ./run_viewer.sh --view phase
```

For a cleaner local library, copy `osc_state_*.csv` files into `data/`, then run:

```bash
./run_viewer.sh data/osc_state_2026-06-15_08-20-12.csv --view pca
```

## If Python 3.9 Cannot Install The Graphics Stack

This Mac currently exposes Apple Python `3.9.6`. The setup script tries that first. If `pygfx`, `wgpu`, or `rendercanvas` refuses to install because Python is too old, install a newer Python and rerun:

```bash
python3.11 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
./run_viewer.sh
```

If `python3.11` is not installed, use the Python.org macOS installer or Homebrew:

```bash
brew install python@3.11
```

## TouchDesigner

TouchDesigner support lives in `touchdesigner/`.

The included callback file defaults to the project copy of the sample CSV, or
you can override it with `RDFT_HOPF_CSV`:

```text
data/osc_state_2026-06-15_08-20-12.csv
```

Open `touchdesigner/rdft_touchdesigner_hopf_method.md` for the network recipe.
