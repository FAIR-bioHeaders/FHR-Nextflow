# GFF3 fixtures

Byte-exact copies of synthetic cases from the
[gff3-validator conformance suite](https://github.com/FAIR-bioHeaders/gff3-validator/tree/70f93a4dc385679119648e0c3419bcdd84ecad5c/conformance)
(commit `70f93a4`, 2026-10-09), used by `tests/run.py` for `GFF3_VALIDATE`.
The suite's contributions are distributed under [MPL-2.0](https://mozilla.org/MPL/2.0/),
the license of this repository; see the gff3-validator LICENSE for its retained
MIT notice. The expected outcome of each case is recorded in that suite's
`manifest.json`.

| File | Source | Expected with gff3-validate 0.1.0 |
| --- | --- | --- |
| `genes-with-genome.gff3` | `valid/` | valid, with or without the genome |
| `bio-008-internal-stop.gff3` | `valid/` | valid; BIO-008 warning (in-frame stop) with `genome.fa` |
| `canonical-gene-gzip.gff3.gz` | `valid/` | valid (gzip input) |
| `str-001-duplicate-id.gff3` | `invalid/` | invalid; GFF-STR-001 error (duplicate ID) |
| `genome.fa` | `genomes/` | 180 bp synthetic genome for the BIO-* checks |

Do not edit these files; copy updated cases from the suite instead.
