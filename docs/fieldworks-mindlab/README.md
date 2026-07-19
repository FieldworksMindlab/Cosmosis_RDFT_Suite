# Fieldworks MindLAB Prospectus Package

This directory contains the public repository edition of the Fieldworks MindLAB
organizational prospectus and its supporting research register. The package
describes the laboratory, its RDFT/Cosmosis research program, its technical
appendices, and the source materials used to assemble the prospectus.

## Documents

| Document | Format | Scope |
| --- | --- | --- |
| [Omnibus Prospectus](Fieldworks_MindLAB_Omnibus_Prospectus.pdf) | PDF, 170 pages | Combined prospectus and technical appendices |
| [Foundational Prospectus](Fieldworks_MindLAB_Foundational_Prospectus.pdf) | PDF, 22 pages | Organizational prospectus and program overview |
| [Foundational Prospectus Source](Fieldworks_MindLAB_Foundational_Prospectus.docx) | DOCX | Editable companion source for the foundational prospectus |
| [Technical Appendices](Fieldworks_MindLAB_Technical_Appendices.pdf) | PDF, 148 pages | Technical papers and supporting materials |
| [Source Register](Fieldworks_MindLAB_Source_Register.csv) | CSV, 18 records | Authored appendices and third-party development references |

The omnibus edition combines the 22-page foundational prospectus with the
148-page technical appendices. The separate volumes are retained for readers
who want the organizational and technical material independently.

## Source Register

The source register preserves titles, authors, dates, publication status, and
the role of each source in the prospectus. Machine-specific absolute paths were
replaced with `reference-only:` identifiers before publication. Those
identifiers document provenance without exposing a contributor's local
filesystem and do not imply that the referenced third-party files are
redistributed in this repository.

## Integrity

File hashes are recorded in [SHA256SUMS](SHA256SUMS). From this directory, run:

```bash
shasum -a 256 -c SHA256SUMS
```

## Publication Note

The prospectus identifies itself as a partnership edition and includes a notice
about controlled circulation of patent-sensitive technical details. Inclusion
here constitutes publication in this repository. Third-party works listed in
the source register remain subject to their original licenses and rights; they
are cited rather than reproduced here.

