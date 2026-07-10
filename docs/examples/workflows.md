# Example Workflows

## Visual-Only Topology Exploration

1. Open `apps/cosmosis-visual-observatory/Cosmosis_Visual_Observatory.pde`.
2. Select `Topology Lab` or `Surface Foundry`.
3. Adjust field parameters and material target.
4. Press `G` to generate a mesh.
5. Press `C` to generate call sheets and relief outputs.

## Cosmosis Navigator Synth Session

1. Open SuperCollider.
2. Start Cosmosis Navigator, which contains the developed Chladni/RDFT synth workspace:

```bash
cd apps/cosmosis-navigator
./start_cosmosis.sh
```

3. Use Processing controls to shape field, surface, holonomy, and layer behavior.

## Hopf Dataset Viewer

```bash
cd apps/rdft-hopf-visualization-kit
./setup_mac.sh
./run_viewer.sh
```

Drop a compatible `osc_state_*.csv` into the viewer or press `O` to load one.
