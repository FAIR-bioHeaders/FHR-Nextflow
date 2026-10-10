# Agent instructions

This DSL2 module suite implements FHR-Specification issue #15 in https://github.com/FAIR-bioHeaders/FHR-Nextflow. Commit or push only within the user-authorized scope; publication of a release or a visibility change requires an explicit request.

Keep orchestration and JSON creation native to Nextflow. `modules/utils/main.nf` performs serialization, filename checks and shell quoting; it is not a second schema validator. Use the pinned converter for field validation, conversion and exact-byte checksums, and the pinned gff3-validate (0.1.0) for GFF3 rules; never reimplement either. Required FHR fields and schemaVersion semantics belong to the companion specification.

The FHR paper (https://doi.org/10.1093/bib/bbae122) motivates provenance preservation, minimal required metadata and interoperable serializations. Interpreting those goals here: pass sample IDs through channels, never invent authors/software/accessions/SeqCol digests, preserve sequence bytes, and validate before exposing outputs downstream.

Run `python tests/run.py` with Nextflow 26.04.6, Java 21 and the hash-locked environment in environment/requirements.txt (generated from requirements.in). Tests exercise module composition, both sequence formats, all conversions, malformed/missing metadata, metadata quoting and converter tests. Use `--converter-source ../FAIR-bioHeaders-Tools` to run its tests. Docker environment checks use `docker build -t fhr-nextflow:0.1.0 environment` and `-profile docker`.

Inspect module channel contracts and docs together. Native exec tasks write only under task.workDir. Quote staged paths, whitelist command formats and constrain output IDs. Do not copy or change schema rules in this repository. No placeholder checksum is silently supplied: standalone JSON requires a checksum; combine calculates the attached file's checksum, and the example publishes only attached-file metadata when given a sequence. Exceptions thrown from helper functions reach users as an opaque InvocationTargetException outside tasks; return a problem message and throw from the closure instead. Record verification and compatibility changes in CHANGELOG.md.

## Repository map and review

`main.nf` is the runnable example; `modules/*/main.nf` contains reusable processes and the JSON workflow; `subworkflows/attach/main.nf` composes attachment, validation and JSON extraction. `nextflow.config` configures the example, not importing projects. `environment/` pins the converter runtime. `tests/integration.nf` checks native composition; `tests/run.py` drives positive and rejection cases from an external project.

Read README, CONTRIBUTING, SECURITY and the pipeline guide before changing their contracts. Preserve CRLF fixture bytes and sample IDs. For documentation-only changes, check relative links and examples; rerun pipelines when executable behavior changes. Update CHANGELOG with relevant verification. Keep human-readable citations in Chicago style with DOI links and machine-readable citation metadata distinct from release identifiers.

David and Adam are the maintainers and jointly hold schema authority; the steering-group option in the companion GOVERNANCE.md is not active. Follow the conduct and security policies for private reporting and conflicts. Never invent a published repository URL, release date, DOI or archival record for this development prototype.

This repository uses MPL-2.0. Preserve its source notices and keep CITATION.cff and README licensing consistent. Do not apply the companion repositories' USDA government-work notice to this suite. External dependencies retain their own licenses.

## Licensing policy (2026-10-09)

This repository already uses MPL-2.0. Preserve its existing LICENSE and all
third-party terms. The USDA public-domain notices in companion repositories
do not apply here. Keep README badges and package/citation metadata consistent;
do not rewrite historical releases or silently relicense upstream material.
