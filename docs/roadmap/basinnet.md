# BasinNET Roadmap

BasinNET is intentionally deferred from the first public release.

Before adding it as `apps/rdft-basin-net`, the project needs a cleanup pass:

- separate source from generated model outputs
- exclude training artifacts and large output folders
- document datasets and feature schemas
- add reproducible smoke tests
- preserve learned summaries without committing bulky intermediate files
- review private/local data paths

The first public monorepo focuses on the core Cosmosis, RDFT synth, visual observatory, Hopf, and Surface Foundry tools.
