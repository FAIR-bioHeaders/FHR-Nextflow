# Changelog

## Unreleased

- Add the `GFF3_VALIDATE` module (FHR-Specification #71, Nextflow part), which runs the pinned gff3-validator 0.1.0 on plain, gzip or BGZF GFF3 with an optional genome FASTA (`[]` for none) and emits JSON and HTML reports, `valid` for files without errors and versions. `task.ext` sets the header mode, translation table, findings cap and `fail_on_errors` (default `true`: a file with errors fails the task; `false` emits its reports and omits it from `valid`); unreadable input (validator exit status 2) always fails. The example accepts `--gff3` (with `--gff3_genome` and `--gff3_*` options) and publishes reports under `ID/gff3/` behind the existing converter-test gate. `gff3-validator==0.1.0` joins `environment/requirements.in` and the hash-locked `requirements.txt` (its PyYAML requirement is satisfied by the existing 6.0.3 pin); the tested combination now includes it. Fixtures are byte-exact copies of gff3-validator conformance cases (commit `70f93a4`, MPL-2.0). CI runs a Docker GFF3 example. Verification: `tests/run.py --converter-source` (v0.4.0 worktree `6a71377`; 31 runs, 133 converter tests), `docker build -t fhr-nextflow:0.1.0 environment` (image `sha256:524c6ac6…9bf64b`), and the Docker GFA and GFF3 examples.
- Clarify the existing MPL-2.0 policy in the README, contribution guidance and agent instructions, and add a README license badge. No runtime behavior changes.

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

Moved to FHR-File-Converter 0.3.2, which streams FASTA/GFA files with bounded memory (about 35 MB peak instead of about five times the file size); checksums and outputs are unchanged. The hash-locked environment, version guards, CI converter commit and docs now name 0.3.2. Verification: `tests/run.py --converter-source` (converter v0.3.2 worktree; 21 runs, 102 converter tests), `docker build -t fhr-nextflow:0.1.0 environment` (image `sha256:1b0ffe39…fda47`) and the Docker GFA example with `--converter_source`.

Moved to FHR-File-Converter 0.3.3, which adds gzip/bgzip input and output and stdin/stdout pipes; plain-file checksums are unchanged. Verification: `tests/run.py --converter-source` (converter v0.3.3 worktree; 21 runs, 116 converter tests), `docker build -t fhr-nextflow:0.1.0 environment` (image `sha256:7a9bd9b3…f5053f`) and the Docker GFA example.

Moved to the converter's new name, fair-bioheaders 0.4.0, from the renamed FAIR-bioHeaders-Tools repository (formerly FHR-File-Converter). The modules still call the unchanged `fhr-*` commands. Verification: `tests/run.py --converter-source` (v0.4.0 worktree; 21 runs, 133 converter tests), `docker build -t fhr-nextflow:0.1.0 environment` (image `0a566862…`) and the Docker GFA example.
