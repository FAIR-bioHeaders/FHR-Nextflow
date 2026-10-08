# FHR-Nextflow Constitution

> **Status: draft.** Proposed for Spec Kit planning gates. It restates existing
> AGENTS.md, CONTRIBUTING.md, and docs/PIPELINES.md practice and adds no
> authority. David and Adam must approve it before it is treated as ratified.

## Core Principles

### I. Delegate FHR semantics to the converter

Validation, conversion, and exact-byte checksums come from the pinned
FHR-File-Converter. This repository never copies schema rules or adds a second
validator. Required fields and schemaVersion semantics belong to
FHR-Specification.

### II. Native, composable DSL2 modules

Orchestration and JSON serialization stay native to Nextflow. Modules work when
imported into an external DSL2 project. `meta` and sample IDs survive every
channel operation; output IDs are validated and staged paths are quoted.

### III. Never invent or fake identity

No placeholder checksum or SeqCol digest is silently supplied or published as
real. Standalone JSON carries a caller-supplied checksum; attachment computes the
final file's checksum. Authors, software, and accessions are never invented.

### IV. Validate before exposing outputs

Outputs are published only after the steps that check them succeed, and test
reports are kept when tests fail. Sequence bytes, including CRLF fixtures, are
preserved exactly.

### V. Reproducible, pinned environments

The supported baseline is pinned (Nextflow, Java, Python, converter version,
container base image, hash-locked Python dependencies). Changing any pin needs
the integration harness, converter tests, and container example to pass.

## Verification gates

```bash
python tests/run.py --converter-source ../FHR-File-Converter
docker build -t fhr-nextflow:0.1.0 environment
nextflow run main.nf -profile docker \
  --sequence examples/assembly.gfa --sequence_format gfa \
  --converter_source ../FHR-File-Converter
```

## Decision boundaries

David and Adam hold schema authority. Releases, tags, DOIs, deployment, and
repository visibility changes are separate maintainer actions; a spec, plan, or
task list never authorizes them. Sensitive findings follow SECURITY.md. The
suite is MPL-2.0; the companion repositories' notices are not applied here.

## Governance

This constitution guides Spec Kit specify/plan/tasks gates. Versioning follows the
CONTRIBUTING.md compatibility and release policy. Amendments follow normal
review with a CHANGELOG note.

**Version**: 0.1.0 (draft) | **Ratified**: pending maintainer approval | **Last Amended**: 2026-10-08
