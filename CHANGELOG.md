# Changelog

## 0.1.0-dev

Initial local DSL2 suite for FHR-Specification #15: native JSON creation plus converter validation; generic conversion, metadata/checksum validation, FASTA/GFA combine/strip and converter pytest modules. Validated attach/extract subworkflow and runnable examples. Targets converter 0.3.0 and schemaVersion 1. Not published and has no GitHub remote.

Verification uses Nextflow 26.04.6 / Java 21: all five metadata formats round-trip, FASTA and GFA payloads survive attach/strip byte-for-byte, and invalid metadata, IDs, formats and checksums stop execution. The pinned Docker environment also runs the example and converter pytest wrapper.

Added project documentation aligned with the companion repositories: contributing, conduct and security policies, shared private reporting contacts, citation metadata, license notice, expanded agent guidance and a pipeline composition guide. No release or DOI has been assigned. Documentation links and module contracts checked; executable module behavior unchanged.
