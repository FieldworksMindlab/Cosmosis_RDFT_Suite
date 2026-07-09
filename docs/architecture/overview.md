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
