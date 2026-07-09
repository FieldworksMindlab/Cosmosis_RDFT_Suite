# Surface Foundry

Surface Foundry converts live RDFT topology fields into fabrication-oriented artifacts.

Outputs include:

- STL meshes for 3D printing.
- Technical call sheets with rotated isometric drawings.
- Voxel lattice and surface silhouette drawing modes.
- Relief/cutout STL variants derived from the same generated topology.
- Metadata JSON describing settings, material target, topology, geometry wrapper, and build parameters.

The important design rule is that drawings, STL exports, and relief outputs should come from the same in-memory generated field whenever possible. This keeps visual review, documentation, and fabrication connected to the same procedural source.

Current surfaces are exploratory. Future production passes may add smoother marching-cubes or surface-nets extraction, stronger mesh repair, and more formal geometry validation.
