# Curated Material Database Targets

This cache is a reproducible instrumentation layer, not a substitute for a
constitutive material model. Each profile combines source-backed descriptors
with clearly marked visualization inferences and RDFT response traits.

## Verified records

| Target | Source record | Structure | Source-backed fields |
| --- | --- | --- | --- |
| Nitinol Austenite | NIST JARVIS `JVASP-14790` | cubic `Pm-3m` TiNi | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor |
| Nitinol Martensite | NIST JARVIS `JVASP-19608` | monoclinic `P2_1/m` TiNi | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor |
| Bismuth | Materials Project `mp-23152`; NIST JARVIS `JVASP-837` | trigonal `R-3m` Bi | structure cross-reference, density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor, SOC spillage |
| Niobium-Tin | NIST JARVIS `JVASP-19668` | cubic A15 `Pm-3n` Nb3Sn | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor, SOC spillage, superconducting Tc descriptor |
| Bismuth Selenide | NIST JARVIS `JVASP-1067` | trigonal `R-3m` Bi2Se3 | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor, SOC spillage |
| Bismuth Telluride | NIST JARVIS `JVASP-25` | trigonal `R-3m` Bi2Te3 | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor, SOC spillage |
| Vanadium Dioxide | NIST JARVIS `JVASP-10053` | tetragonal `P4_2/mnm` VO2 | density, band gap, bulk/shear modulus, Poisson ratio, dielectric tensor |

Records were checked on 2026-07-09 through the public NIST JARVIS OPTIMADE
endpoint. The Materials Project identity of `mp-23152` was cross-checked against
the DOE OSTI record for trigonal bismuth.

## Interpretation

- `missing_fields` lists values absent from the source record and filled only
  to keep the shared visual instrument schema operational.
- `phase_transform` describes how strongly the RDFT controls should expose
  phase-boundary behavior. It does not predict a transformation temperature.
- `topological_response` is informed by structure, SOC spillage, and known
  material class, then normalized for visual mapping.
- `superconducting_coherence` is an RDFT mapping trait. For Nb3Sn the stored
  transition temperature is the JARVIS database descriptor, not a fabrication
  guarantee.
- Nitinol properties depend strongly on composition, heat treatment, strain,
  and temperature. The two profiles are phase anchors, not a complete hysteretic
  shape-memory model.

## Source interfaces

- Materials Project: https://materialsproject.org/
- Materials Project API documentation: https://docs.materialsproject.org/downloading-data/using-the-api
- DOE OSTI record for `mp-23152`: https://www.osti.gov/biblio/1199272
- NIST JARVIS: https://jarvis.nist.gov/
- JARVIS OPTIMADE: https://jarvis.nist.gov/optimade/jarvisdft

