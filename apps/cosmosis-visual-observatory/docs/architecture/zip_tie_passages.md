# Shared straight zip-tie passages

As of 2026-10-08, Salon's LEGACY PORTAL with HALF_DIHEDRAL_MITER uses
ASSEMBLED_STRAIGHT and requests three portals per edge (nine per triangle
when they fit). KICAS and Truss Yard retain their existing connector policy.
Square compatibility seams and unmatched rim holes remain panel-local.

For each reciprocal edge, the generator computes a common assembly-space frame:
the seam tangent defines strap width, the face-normal bisector defines strap
thickness, and their cross product defines the threading axis. Both parts use
the same height and width. A shared height is selected within the intersection
of the available material ranges at both ends of both rails. A tunnel that
cannot fit is marked infeasible and blocked at preflight; a preview alone does
not establish printability.

The rail parameterization preserves the miter's supporting plane, the inner
wall, caps, and membrane. Within the portal band it places floors, roofs, and
side walls around that shared prism. Five entrance segments widen the aperture
with a rounded profile over the inner 20% of the rail. Maximum entrance relief
is 0.35 mm per side, capped at 15% of passage height. The obsolete seam lip is
removed for this mode. Adjacent rail triangles share the same transformed
vertices, using the mesh audit's existing vertex identity tolerance.

## Balanced stations and size adaptation

The desired stations are 25%, 50%, and 75% along each shared edge. The usable
span is calculated from both panels' contracted inner edges and mitered outer
edges, with corner reserves retained. When required, the outside stations move
inward symmetrically. If three cannot fit, two symmetric stations are used;
if two cannot fit, a single centered station is used. Both panels receive the
same schedule. If even one usable aperture cannot fit, export is blocked.

Spacing scales with part size; strap apertures retain their requested size.
The minimum material between rounded mouths is max(1.2 mm, 40% of aperture
width). The rail mapping stays monotonic across the whole run between holes,
so solid web triangles cannot fold into a neighboring passage.

Part deduplication includes signed joint angle, shared height, bore height,
entrance relief, every station, and axis mode. Neighbor-dependent holes can therefore create
more reusable types than panel-local holes. The supplied dodeca F6 resolves to
208 types, compared with 125 in the original export. Regenerate the complete
kit before using its part IDs; do not mix old and new IDs.

## Clearance gate

Preflight clips actual generated triangles against a rectangular volume swept
continuously through both rails and extended 0.2 mm beyond their cavity mouths.
It checks the full width and height, including off-axis obstructions; checking
only a centerline or sampled seam aperture would miss those. Each side of the
nominal bore is inset by 0.05 mm for numerical tolerance. Certified clear
width/height must also accommodate the reference 2.5 × 1.1 mm strap with 0.4 mm
total clearance in each dimension. Existing manifold and assembled-seam gates
remain separate and required. The code-label fallback matches the catalog.

Each scheduled passage is tested independently, not just the midpoint. Results
appear in `zip_tie_passage_audit` in the manifest, with separate edge and passage
counts and a breakdown of one/two/three-passage edges. A failed passage reports
its edge fraction. `straight_passages` in each joint profile supplies all world
centers; the older scalar aperture fields now refer to an actual representative
hole, including on two-hole edges. These are geometry
checks at exported 100% scale, not a printer calibration or a mechanical load
rating. An extremely sharp joint may need different rail/skin dimensions;
the generator blocks it instead of squeezing the tie passage or breaking
through the rail. Auto-capped frame depth can limit how much increasing the
requested depth helps.

## Tie dimensions

Lengths do not uniquely determine strap width or thickness. The user's
[Zip Ties Zone chart](https://ziptieszone.com/blogs/zip-ties-zone-blogs/zip-ties-size-chart)
lists approximate widths but omits thickness. Manufacturer examples below
illustrate common sizes, not a universal dimensional standard:

| Example | Length | Strap width | Strap thickness |
| --- | ---: | ---: | ---: |
| [HellermannTyton T18R 111-01916](https://www.hellermanntyton.com/products/cable-ties-inside-serrated/t18r/111-01916) | 100 mm | 2.5 mm | 1.0 mm |
| [HellermannTyton T18R 111-00658](https://www.hellermanntyton.com/kr/products/cable-ties-inside-serrated/t18r/111-00658) | 100 mm | 2.5 mm | 1.1 mm |
| [HellermannTyton T30R 111-03011](https://www.hellermanntyton.com/products/cable-ties-inside-serrated/t30r/111-03011) | 150 mm | 3.5 mm | 1.1 mm |
| [HellermannTyton T50R 111-04819](https://www.hellermanntyton.com/products/cable-ties-inside-serrated/t50r/111-04819) | 202 mm | 4.6 mm | 1.2 mm |

The head stays outside the hole. Strap length must still accommodate the
complete loop and enough tail to engage and tighten the head. Measure the
actual ties and print the mating test pair before a full kit.

## Verification

Run from the repository root:

```sh
python3 apps/cosmosis-visual-observatory/tools/test_straight_portals.py
```

The runner uses Processing's installed PDE preprocessor and JDK, compiles the
entire sketch, and exercises the real generator without launching its UI.
`--compile-only` checks compilation without running the regression suite.
`--processing` overrides the Processing.app path. `--fit-output PATH` writes a
two-part test set and validation metadata, without modifying the source kit.

Verified: existing Geodesic core 72/72; 43 portal regression checks, including
all 5,192 passages across 1,944 seams of the labeled dodeca F6 export, all 208
catalog meshes, both
relief sides, open and skinned frames, convex/concave stellations, dome rims,
undersized and infeasible passages, and injected off-axis obstructions. The
kit has 1,434 edges with three passages, 380 with two, and 130 with one. The
fit-test pair has nine holes per piece. Tests also verify proportional spacing,
minimum webs, automatic count reduction, and the retained single-hole mode. The
same volume test rejects the old panel-local passage at the sharpest F6 seam.

Separately, Truss Yard reports 44/45: `a whole-section-step twist produces a
fully convex wall` fails identically in a saved pre-change source build and
the modified build. This existing failure was not changed or suppressed.
