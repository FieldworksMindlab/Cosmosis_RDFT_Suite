# Work Order: DCRTE-ET Milestone 0

Repository:
`FieldworksMindlab/Cosmosis_RDFT_Suite`

Primary target:
`apps/cosmosis-visual-observatory/Cosmosis_Visual_Observatory.pde`

Canonical architecture:
`docs/architecture/DCRTE_ET_ARCHITECTURE_SPEC.md`

## Objective

Introduce the minimum architecture needed to support future domain-constrained generation while preserving all current Surface Foundry behavior.

Do not implement STL domain import, signed distance fields, intrinsic coordinates, or the entropic scheduler in this work order.

## Required tasks

1. Inspect the existing Surface Foundry field sampling and mesh generation path.
2. Identify the current function or functions that evaluate the 3D topology scalar.
3. Add a new PDE tab named `DCRTE_Field.pde`.
4. Define a minimal `FieldEngine` interface.
5. Implement `LegacyTopologyScalarAdapter` that calls the existing field function without changing its numerical behavior.
6. Add `DCRTE_Config.pde` containing a minimal serializable configuration snapshot for existing Surface Foundry field parameters.
7. Add a pipeline selector with these modes:
   - `LEGACY_DIRECT`
   - `DCRTE_ADAPTER_TEST`
8. Keep `LEGACY_DIRECT` as the default.
9. In adapter-test mode, sample both the direct function and adapter at a deterministic set of points and report maximum and mean absolute error.
10. Add a small on-screen diagnostics block showing adapter status and comparison error.
11. Add JSON metadata fields for pipeline mode, field engine ID, field engine version, and configuration ID.
12. Update Surface Foundry documentation with the new optional adapter-test mode.

## Constraints

- Preserve current keyboard controls.
- Preserve current mesh and call-sheet generation.
- Do not change existing field equations.
- Do not add dependencies.
- Do not move the whole sketch into Java packages.
- Keep the sketch compiling in Processing 4.
- Use deterministic samples and no unseeded randomness.
- Make the change in small, readable units.

## Acceptance tests

- The sketch compiles and opens.
- Legacy Surface Foundry generation still works.
- Adapter comparison reports zero or negligible floating-point difference.
- Existing STL and JSON export still works.
- New metadata is present.
- Turning adapter-test mode off restores the exact previous control path.

## Deliverables

- modified Processing sketch;
- new PDE tabs;
- updated README section;
- concise implementation notes;
- list of functions and globals that should be refactored in Milestone 1, without refactoring them yet.
