# Surface Foundry

Surface Foundry converts live RDFT topology fields into fabrication-oriented artifacts.

Outputs include:

- STL meshes for 3D printing.
- Technical call sheets with rotated isometric drawings.
- Voxel lattice and surface silhouette drawing modes.
- Relief/cutout STL variants derived from the same generated topology.
- Metadata JSON describing settings, material target, topology, geometry wrapper, and build parameters.

The important design rule is that drawings, STL exports, and relief outputs should come from the same in-memory generated field whenever possible. This keeps visual review, documentation, and fabrication connected to the same procedural source.

## Primitive Observation Domains

DCRTE-ET Milestone 1 separates the field carrier from the finite observation
domain. The carrier participates in the recursive scalar field. A sphere, box,
or cylinder domain does not deform that field; it determines where samples may
be admitted for materialization.

```text
final material = admitted by domain AND classified by existing field rule
```

The observer samples voxel centers over a normalized Cartesian box. Hard mode
admits the domain interior. Shell mode admits an inward boundary band. An
immediate, frame-independent scheduler activates admitted candidates, and a
single adapter hands the flat DCRTE volume to the existing voxel mesher. Export
validation rejects empty, non-finite, outside-domain, or non-manifold results.

This is a controlled generative-design instrument, not a constitutive material
simulation or mechanical performance claim.

Current surfaces are exploratory. Imported mesh domains, mesh-derived signed
distance fields, intrinsic coordinates, entropic scheduling, and mechanical
analysis are intentionally deferred to later milestones.
