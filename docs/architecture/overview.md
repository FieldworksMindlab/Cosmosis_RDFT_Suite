# Architecture Overview

Cosmosis RDFT Suite is organized as a monorepo of independent but related instruments.

The apps share a conceptual vocabulary:

- recursive fields
- phase thresholds
- holonomy and Berry-like loop behavior
- Floquet shaping
- topology and surface wrapping
- environmental data bridges
- material and run-imprint profiles

The apps do not share one runtime. Some are Processing sketches, some use SuperCollider, some are Python tools, and some include optional TouchDesigner workflows. This repository keeps them together because the research language and workflows are connected.

## Data Flow Pattern

Typical live systems follow this shape:

```text
external data or controls -> Processing field engine -> OSC / visual / geometry outputs
                                   |
                                   +-> SuperCollider synthesis
                                   +-> CSV logs and run imprints
                                   +-> STL, call sheet, and dashboard artifacts
```

Generated outputs are intentionally ignored by default. The repo preserves source, docs, and small examples; users regenerate outputs locally.

## DCRTE-ET

Surface Foundry is being extended incrementally through the Domain-Constrained
Recursive Topology Engine with Emergent Entropic Scheduling (DCRTE-ET). The
architecture treats fields as primary, domains as observation constraints, and
geometry as one materialized output.

Milestone 0 established a compatibility layer. The existing Surface Foundry
direct pipeline remains the default, while the `FieldEngine` adapter provides
deterministic numerical parity testing.

Milestone 1 adds an opt-in primitive-domain pipeline. It samples the unchanged
field through a uniform Cartesian observer, admits samples through analytic
sphere, box, or cylinder domains, and adapts the masked flat volume into the
existing voxel materializer. Hard-interior and inside-only shell-band modes are
validated before export. The carrier that shapes the field remains independent
from the domain that bounds observation.

Milestone 2 adds imported closed-mesh observation domains, deterministic mesh
sanitation, fit-centered transforms, boundary voxelization, inside/outside
classification, and signed-distance volumes. Milestone 2.5 adds the staged
preflight report that identifies topology, component, orientation,
self-intersection, resolution, SDF, materialization, and export blockers without
silently repairing or relaxing an invalid source.

Milestone 3 adds an optional intrinsic axial coordinate implementation between
the qualified observer and the unchanged field engine. A distance-weighted PCA
axis, slice-centroid centerline, parallel-transport frame, and radial model map
one dominant non-branching domain into longitudinal and local radial field
coordinates. Cartesian sampling remains the default. Loops, branches, multiple
dominant components, excessive ambiguity, and unqualified domains are blocked
from intrinsic axial mode.

- [Canonical DCRTE-ET architecture](DCRTE_ET_ARCHITECTURE_SPEC.md)
- [Milestone 0 work order](DCRTE_ET_MILESTONE_0_WORK_ORDER.md)
- [Milestone 0 implementation notes](../../apps/cosmosis-visual-observatory/DCRTE_MILESTONE_0_IMPLEMENTATION_NOTES.md)
- [Milestone 1 work order](DCRTE_ET_MILESTONE_1_WORK_ORDER.md)
- [Milestone 1 implementation report](../../apps/cosmosis-visual-observatory/DCRTE_MILESTONE_1_IMPLEMENTATION_REPORT.md)
- [Milestone 1 acceptance metrics](../verification/dcrte_m1_acceptance.json)
- [Milestone 2 work order](DCRTE_ET_MILESTONE_2_WORK_ORDER.md)
- [Milestone 2 implementation report](../../apps/cosmosis-visual-observatory/DCRTE_MILESTONE_2_IMPLEMENTATION_REPORT.md)
- [Milestone 2 acceptance metrics](../verification/dcrte_m2_acceptance.json)
- [Milestone 2.5 preflight work order](DCRTE_ET_MILESTONE_2_5_PREFLIGHT_WORK_ORDER.md)
- [Milestone 2.5 implementation report](../../apps/cosmosis-visual-observatory/DCRTE_MILESTONE_2_5_IMPLEMENTATION_REPORT.md)
- [Milestone 2.5 acceptance metrics](../verification/dcrte_m25_acceptance.json)
- [Milestone 3 intrinsic-coordinate work order](DCRTE_ET_MILESTONE_3_INTRINSIC_COORDINATES_WORK_ORDER.md)
- [Milestone 3 implementation report](../../apps/cosmosis-visual-observatory/DCRTE_MILESTONE_3_IMPLEMENTATION_REPORT.md)
- [Milestone 3 acceptance metrics](../verification/dcrte_m3_acceptance.json)
