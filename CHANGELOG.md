# Changelog

## 0.1.0-dev

Initial local DSL2 suite for FHR-Specification #15: native JSON creation plus converter validation; generic conversion, metadata/checksum validation, FASTA/GFA combine/strip and converter pytest modules. Validated attach/extract subworkflow and runnable examples. Targets converter 0.3.0 and schemaVersion 1. No release has been published. The dedicated repository is https://github.com/FAIR-bioHeaders/FHR-Nextflow.

Verification uses Nextflow 26.04.6 / Java 21: all five metadata formats round-trip, FASTA and GFA payloads survive attach/strip byte-for-byte, and invalid metadata, IDs, formats and checksums stop execution. The pinned Docker environment also runs the example and converter pytest wrapper.

Added project documentation aligned with the companion repositories: contributing, conduct and security policies, shared private reporting contacts, citation metadata, license notice, expanded agent guidance and a pipeline composition guide. No release or DOI has been assigned. Documentation links and module contracts checked; executable module behavior unchanged.

Replaced the copied USDA government-work notice with Mozilla Public License 2.0, added source notices and MPL-2.0 citation metadata, and removed David Molik's outdated USDA affiliation and government email from this suite's citation record. Companion repositories and dependency licenses are unchanged.

Completed the issue #15 documentation review: explicit SHA-512/256 and padded-base64 checksum contract, supported compatibility baseline, patch/minor/major and pre-1.0 release policies, and current repository links. Documentation links and citation metadata checked; module behavior unchanged.

Correctness review fixes (behavior changes for the example and two modules):

- The example derives one ID per metadata file (file name without `.fhr.json`/`.json`; `example` for the bundled file), rejects duplicate or unsafe IDs, and rejects `--id` with several files; previously all files shared `--id` and overwrote each other's outputs.
- Publication uses workflow outputs (copy mode) instead of asynchronous `subscribe` copies. With `--converter_source`, metadata and sequence results are published only after converter tests pass; JUnit XML and log are always published. With `--sequence`, only attached-file outputs (whose checksum is computed) are published; the YAML now derives from the attached JSON.
- `FHR_CONVERTER_TESTS` is now a workflow: it copies the checkout into the task directory (no `__pycache__` in the input), requires the checkout to declare version 0.3.0, runs tests against the installed converter, always emits `reports`, adds a `passed` output and fails afterwards when tests fail. A content digest of the checkout keeps `-resume` from reusing stale results after nested edits.
- JSON serialization writes UTF-8 without `\u` escapes, omits `null` map entries and rejects Date, NaN/Infinity, `null` list items and non-string keys with the field location.
- The example metadata no longer contains a placeholder `seqcol_id`.
- `environment/requirements.txt` is a hash-locked file generated from `requirements.in` and installed by the Dockerfile, CI and local environments. Added GitHub Actions CI pinned by action digest. The Docker profile runs containers as the invoking user. Version-guard failures now explain the mismatch.
- `tests/run.py` uses explicit checks that survive `python -O` and covers each change.

Verification: `python -O tests/run.py --converter-source` (converter v0.3.0 worktree), `docker build -t fhr-nextflow:0.1.0 environment`, and the Docker GFA example with `--converter_source`, using Nextflow 26.04.6 / Java 21 / Python 3.13.

Moved to FHR-File-Converter 0.3.1, which fixes GHSA-pvq5-772j-fq72 and requires FHR lines to form the leading header block. The hash-locked environment, version guards, CI converter commit and docs now name 0.3.1; pytest in the environment moves to 9.1.1. New rejection cases cover an FHR line after sequence data and concatenated FHR files. Verification: `tests/run.py --converter-source` (converter v0.3.1 worktree; 21 runs, 77 converter tests), `docker build -t fhr-nextflow:0.1.0 environment` (image `sha256:e43b5d59…41bf1`) and the Docker GFA example with `--converter_source`.
