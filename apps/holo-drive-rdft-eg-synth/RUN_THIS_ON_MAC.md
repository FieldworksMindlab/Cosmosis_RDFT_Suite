# Run HOLO Drive On This Mac

## Normal Full Start

Open Terminal and run exactly:

```bash
cd apps/holo-drive-rdft-eg-synth
./start_holo_mac.sh
```

That starts:

- solar sender
- ocean/tide sender
- cached galaxy maps
- surface/topology sender
- Processing
- SuperCollider file

Then:

1. In SuperCollider, boot/evaluate `ColdSun_Shimmer.scd`.
2. In Processing, press Run if it did not start automatically.

## If Only Topology Is Missing

If Processing and SuperCollider are already running, open a second Terminal window and run:

```bash
cd apps/holo-drive-rdft-eg-synth
./start_surface_topo.sh
```

This starts real Grand Canyon topography by default.

Other examples:

```bash
./start_surface_topo.sh mandelbrot
./start_surface_topo.sh julia
./start_surface_topo.sh fractal_ridge
./start_surface_topo.sh real_topography mauna_loa
./start_surface_topo.sh real_topography st_helens
```

## Ocean / Tide Sensing Layer

The normal launcher now starts `ocean_current_bridge.py` automatically. It sends NOAA CO-OPS tide, water temperature, tidal-current proxy, velocity, acceleration, energy, and memory data to Processing on UDP `5062`. Processing interprets those values as an ocean boundary field, then forwards the interpreted state to SuperCollider as `/rdf/ocean`.

Default station:

```bash
OCEAN_STATION=9414290 ./start_holo_mac.sh
```

That station is San Francisco. To test the ocean panel/audio path without internet/API data:

```bash
OCEAN_SIMULATE=1 ./start_holo_mac.sh
```

## Processing GUI Controls

- `SURF: ON/OFF` toggles the orbital topology overlay.
- `SURF: NEXT` cycles through all surface modes:
  `gyroid`, `schwarz_p`, `beltrami_saddle`, `hopf_torus`, `petaminx_lattice`, `mandelbrot`, `julia`, `fractal_ridge`, `real_topography`.
- `SURF: TOPO` jumps directly to real terrain/topography mode.
- `SURF: LOC` cycles real terrain locations:
  `grand_canyon`, `mauna_loa`, `iceland_rift`, `st_helens`, `yosemite`.

## Stop Background Senders

```bash
cd apps/holo-drive-rdft-eg-synth
./stop_holo_mac.sh
```

## Refresh Galaxy Maps Manually

The normal launcher uses cached galaxy maps so startup is fast. To refresh live astronomy data:

```bash
cd apps/holo-drive-rdft-eg-synth
source .venv/bin/activate
python galaxy_bridge.py
```

Or run the full launcher with refresh enabled:

```bash
GALAXY_REFRESH=1 ./start_holo_mac.sh
```

## Notes

- Do not type `python ...` directly unless the `.venv` is active. Use `./start_surface_topo.sh` instead.
- Real terrain is cached in `maps/surface_cache/`.
- If the terrain API rate-limits, the sender falls back to synthetic terrain and keeps running.
- If NOAA tide data is unavailable, the ocean sender sends `OCEAN:live=0.0` and keeps running. Use `OCEAN_SIMULATE=1` when you want simulated live test data.
