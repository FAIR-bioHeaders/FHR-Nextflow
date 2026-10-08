# Feature Specification: Adopt FHR-File-Converter 0.3.1

**Feature Branch**: `001-converter-0-3-1-upgrade`

**Created**: 2026-10-08

**Status**: Draft (blocked until converter 0.3.1 is released)

**Input**: The converter's next patch release tightens FASTA/GFA header parsing
(leading header block, single-line checksum value, duplicate keys and YAML
anchors rejected). The suite pins converter 0.3.0 and must move to 0.3.1 under
the CONTRIBUTING.md compatibility policy.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pipelines run on the patched converter (Priority: P1)

A pipeline author importing FHR-Nextflow modules gets the patched converter in
the pinned environment without changing their workflow.

**Independent Test**: The integration harness, converter tests, and Docker
example pass with the environment pinned to 0.3.1.

**Acceptance Scenarios**:

1. **Given** the environment pinned to converter 0.3.1, **When** `tests/run.py`
   runs, **Then** every positive and rejection case passes.
2. **Given** the Docker example, **When** run with 0.3.1, **Then** the attached
   GFA's checksum matches an independent SHA-512/256 calculation.

---

### User Story 2 - Newly invalid inputs fail clearly (Priority: P2)

A user who supplies a FASTA/GFA with FHR lines after sequence data, or
concatenated FHR files, sees the converter's error and no published output.

**Independent Test**: New rejection cases in `tests/run.py`.

### Edge Cases

- A sequence input that already carries an FHR header (combine replaces it).
- CRLF fixtures, which must stay byte-exact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `environment/requirements.in`, the hash-locked
  `requirements.txt`, the version guard, CI's converter ref, and README's tested
  combination MUST all move to 0.3.1 together.
- **FR-002**: Rejection cases MUST cover a late FHR line and concatenated files.
- **FR-003**: No module may pre-filter or rewrite FHR lines itself; parsing stays
  in the converter.
- **FR-004**: The suite version MUST follow CONTRIBUTING.md
  [NEEDS CLARIFICATION: patch, if the newly rejected inputs count as invalid
  under the specification, or minor, if any consumer relied on them?].

## Success Criteria *(mandatory)*

- **SC-001**: All verification gates in the constitution pass with 0.3.1.
- **SC-002**: The recorded image digest and converter commit are updated in
  CHANGELOG.

## Assumptions

- Converter 0.3.1 keeps the 0.3.0 checksum algorithm and CLI entry points.
- Builds on the `review/fixes` branch (publication gate, hash-locked environment).
