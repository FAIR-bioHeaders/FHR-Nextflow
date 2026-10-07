# Agent instructions

This is a local-only DSL2 module suite for FHR-Specification issue #15. Do not create a GitHub repository or push a remote unless requested.

Keep orchestration and JSON creation native to Nextflow. `modules/utils/main.nf` performs serialization, filename checks and shell quoting; it is not a second schema validator. Use the pinned converter for field validation, conversion and exact-byte checksums. Required FHR fields and schemaVersion semantics belong to the companion specification.

The FHR paper (https://doi.org/10.1093/bib/bbae122) motivates provenance preservation, minimal required metadata and interoperable serializations. Interpreting those goals here: pass sample IDs through channels, never invent authors/software/accessions/SeqCol digests, preserve sequence bytes, and validate before exposing outputs downstream.

Run `python tests/run.py` with Nextflow 26.04.6, Java 21 and the environment in environment/requirements.txt. Tests exercise module composition, both sequence formats, all conversions, malformed/missing metadata, metadata quoting and converter tests. Use `--converter-source ../FHR-File-Converter` to run its tests. Docker environment checks use `docker build -t fhr-nextflow:0.1.0 environment` and `-profile docker`.

Inspect module channel contracts and docs together. Native exec tasks write only under task.workDir. Quote staged paths, whitelist command formats and constrain output IDs. Do not copy or change schema rules in this repository. No placeholder checksum is silently supplied: standalone JSON requires a checksum; combine calculates the attached file's checksum. Record verification and compatibility changes in CHANGELOG.md.

## Repository map and review

`main.nf` is the runnable example; `modules/*/main.nf` contains reusable processes and the JSON workflow; `subworkflows/attach/main.nf` composes attachment, validation and JSON extraction. `nextflow.config` configures the example, not importing projects. `environment/` pins the converter runtime. `tests/integration.nf` checks native composition; `tests/run.py` drives positive and rejection cases from an external project.

Read README, CONTRIBUTING, SECURITY and the pipeline guide before changing their contracts. Preserve CRLF fixture bytes and sample IDs. For documentation-only changes, check relative links and examples; rerun pipelines when executable behavior changes. Update CHANGELOG with relevant verification. Keep human-readable citations in Chicago style with DOI links and machine-readable citation metadata distinct from release identifiers.

David and Adam retain schema authority; the companion governance proposal is not adopted. Follow the conduct and security policies for private reporting and conflicts. Never invent a published repository URL, release date, DOI or archival record for this local prototype.
