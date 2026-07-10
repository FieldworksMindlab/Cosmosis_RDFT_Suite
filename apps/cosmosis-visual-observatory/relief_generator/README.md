# Surface Foundry Relief Generator

This folder contains a standalone helper for making silhouette-cutout bas-relief STLs from Surface Foundry source STLs.

The easiest workflow is now built into Cosmosis Visual Observatory: press `CALL SHEET` in Surface Foundry and the suite writes:

- `*_source.stl`
- `*_surface_silhouette.svg/.png`
- `*_voxel_lattice.svg/.png`
- `*_relief_defined.stl`
- `*_relief_dramatic.stl`
- `*_relief_preview.png`
- `*_relief_heightfield.png`

The relief STLs are generated from the filled 3D Surface Foundry volume, not from SVG or PNG brightness.

`defined` preserves the original detailed heightfield mapping: 2.0 mm base,
9.0 mm relief range, and gamma 0.58. `dramatic` is intentionally a different
object rather than a taller duplicate. It blends source detail with a broad
contour field and an interior-distance dome, then maps that field over a 2.6 mm
base and 18.0 mm relief range for a maximum height of 20.6 mm.

Both relief meshes are audited before writing. The generator refuses output if
it finds open boundaries, edges shared by more than two faces, winding
conflicts, or degenerate triangles.

## Standalone Usage

Install dependencies:

```bash
python3 -m pip install -r requirements.txt
```

Run from this folder:

```bash
python3 relief_generator.py \
  --stl ../call_sheet/output/surface_foundry_call_sheet_YYYYMMDD_HHMMSS_source.stl \
  --out output
```

You can also pass a call-sheet SVG. The SVG is used only to find the matching `_source.stl` or optional view metadata:

```bash
python3 relief_generator.py \
  --svg ../call_sheet/output/surface_foundry_call_sheet_YYYYMMDD_HHMMSS_surface_silhouette.svg \
  --out output
```

## Important Rule

Do not use the call-sheet SVG as a heightmap. This tool follows:

```text
source STL -> oriented voxel volume -> front depth + thickness -> silhouette cutout bas-relief STL
```

not:

```text
SVG/PNG brightness -> raised-line plaque
```

The main Observatory also regularizes diagonal voxel contacts before extracting
the source spheroid. Raised transport veins are unioned into the same voxel
volume instead of being appended as intersecting tube shells. The source STL is
written only after its manifold audit passes.
