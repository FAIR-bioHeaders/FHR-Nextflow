**This is a demo repository**, do not deploy. 

# FHR-Nextflow

Reusable Nextflow DSL2 modules for creating, converting, validating and attaching [FAIR bioHeaders](https://doi.org/10.1093/bib/bbae122). This development prototype implements [FHR-Specification issue #15](https://github.com/FAIR-bioHeaders/FHR-Specification/issues/15). The dedicated repository is [FHR-Nextflow](https://github.com/FAIR-bioHeaders/FHR-Nextflow); it has no published release.

Compatibility: Nextflow **26.04.6**, Java **21**, [FAIR-bioHeaders-Tools](https://github.com/FAIR-bioHeaders/FAIR-bioHeaders-Tools) **0.4.0**, FHR schemaVersion **1**. The suite version is **0.1.0-dev**. JSON creation and channel composition are native DSL2/Groovy; the converter supplies schema validation, format conversion and file checksums.

## Run the example

Install Nextflow and Java using the [official instructions](https://docs.seqera.io/nextflow/install). Then install the converter environment in an isolated Python 3.13 environment:

```sh
python3.13 -m venv .venv
. .venv/bin/activate
pip install --require-hashes -r environment/requirements.txt
nextflow run main.nf --metadata examples/metadata.json \
  --sequence examples/genome.fasta --sequence_format fasta
```

Alternatively, build the supplied container and enable Docker:

```sh
docker build -t fhr-nextflow:0.1.0 environment
nextflow run main.nf -profile docker \
  --sequence examples/assembly.gfa --sequence_format gfa
```

Outputs are copied to `--outdir` (default `results`) under one directory per ID. Without `--sequence`, the validated standalone JSON and YAML appear in `results/ID/metadata/`. With `--sequence`, only the attached sequence and JSON/YAML extracted from it appear in `results/ID/sequence/`: their checksum is computed from the attached file, so the caller-supplied standalone checksum is not published.

`--metadata` accepts one JSON file or a quoted glob. Each file's ID is its name without `.fhr.json` or `.json` (the bundled example uses `example`); duplicate or unsafe IDs stop the run before anything is published. `--id SAMPLE` overrides the ID for a single file and is rejected when several files match.

Add `--converter_source ../FAIR-bioHeaders-Tools` (a v0.4.0 checkout) to run the converter's pytest suite. Its JUnit XML and log are always published under `results/converter-tests/`. The metadata and sequence results of that run are **published only after every converter test passes**; if a test fails, the run exits non-zero and publishes only the test reports.

**Example metadata is synthetic.** Its standalone checksum is an explicit placeholder and it has no SeqCol digest. Replace all provenance and identifiers with your own inputs. Attaching a sequence replaces the checksum with its actual FHR checksum; it does not calculate or verify SeqCol identity.

## Create JSON inside your pipeline

Import the module using its path in your local checkout:

```nextflow
include { FHR_CREATE_JSON } from '/path/to/FHR-Nextflow/modules/create_json/main'

workflow {
    records = Channel.of(tuple([id: 'assembly1'], [
        schema: 'https://raw.githubusercontent.com/FAIR-bioHeaders/FHR-Specification/v0.3.0/fhr.json',
        schemaVersion: 1,
        genome: 'My assembly',
        taxon: [name: 'Homo sapiens', uri: 'https://identifiers.org/taxonomy:9606'],
        version: '1.0',
        metadataAuthor: [[name: 'Metadata author']],
        assemblyAuthor: [[name: 'Assembly author']],
        dateCreated: '2026-10-07',
        masking: 'not-masked',
        checksum: params.checksum
    ]))
    FHR_CREATE_JSON(records)
    // FHR_CREATE_JSON.out.json: tuple(meta, validated_json_path)
}
```

The input map accepts **all FHR schema fields**, including nested maps/lists, rather than a restricted set of CLI flags. Required fields are `schema`, `schemaVersion`, `genome`, `taxon`, `version`, `metadataAuthor`, `assemblyAuthor`, `dateCreated`, `masking`, and `checksum`. Optional fields include `genomeSynonym`, `voucherSpecimen`, `accessionID`, `instrument`, `scholarlyArticle`, `documentation`, `identifier`, `relatedLink`, `funding`, `reuseConditions`, `vitalStats`, `assemblySoftware`, `assemblyProtocol`, and `seqcol_id`. See [examples/metadata.json](examples/metadata.json) for a full map and the [specification](https://github.com/FAIR-bioHeaders/FHR-Specification/tree/v0.3.0) for field constraints.

No field values are inferred or silently supplied. Provide a valid checksum for standalone metadata. For sequence construction, provide the metadata checksum explicitly, then use `FHR_ATTACH` to compute the attached file's final checksum and extract JSON matching that file. No sequence statistics or SeqCol digest are inferred. The converter rejects fields outside the schema.

## Module contracts

Every input/output preserves `meta`, a map containing an `id`. IDs must start with a letter/digit and contain only letters, digits, dots, underscores or hyphens. Use unique IDs within a pipeline: output file names derive from the ID. File outputs remain in Nextflow task work directories; consumers control publication.

| Component | Input tuple | Named outputs |
| --- | --- | --- |
| `FHR_CREATE_JSON` workflow | `(meta, fields_map)` | `json`: `(meta, json)` after validation; `reports`: `(meta, validation.txt)`; `versions` |
| `FHR_CONVERT` process | `(meta, metadata_path, output_format)` | `converted`: `(meta, output)`; `versions` |
| `FHR_VALIDATE` process | `(meta, input_path, kind)` | `validated`: `(meta, input_path)` after success; `reports`; `versions` |
| `FHR_COMBINE` process | `(meta, metadata_path, sequence_path, kind)` | `combined`: `(meta, attached_sequence)`; `versions` |
| `FHR_STRIP` process | `(meta, sequence_path, kind)` | `stripped`: `(meta, sequence_without_header)`; `versions` |
| `FHR_CONVERTER_TESTS` workflow | `(meta, converter_source_directory)` | `reports`: `(meta, junit_xml, log)`, emitted whether or not tests pass; `passed`: `meta` after all tests pass; `versions` |
| `FHR_ATTACH` workflow | `(meta, metadata_path, sequence_path, kind)` | `sequence`: validated attached sequence; `json`: matching extracted metadata; `reports`; mixed `versions` |

`output_format`: `json`, `yaml`, `html`, `fasta`, `gfa`. Input format is inferred by the converter from extension; YAML `.yml` is also accepted. Converting metadata to FASTA/GFA produces **only a header**, not sequence content. Use `FHR_COMBINE` or preferably `FHR_ATTACH` to construct a complete file.

`kind`: `metadata` for JSON/YAML/HTML/schema validation, or `fasta`/`gfa` for full-file checksum validation. Combine and strip accept only `fasta`/`gfa`. Metadata schema validation cannot establish that a supplied checksum matches any sequence. Validation failures stop the task and gate downstream validated outputs. `FHR_CONVERTER_TESTS` emits its reports even when tests fail, then fails the run; gate dependent steps on its `passed` output.

Each command task checks the installed converter version and emits `(meta, versions.yml)`. The consuming pipeline must enable DSL2 (`nextflow.enable.dsl = 2` in its config). Importing modules does not inherit this project's config: install the pinned environment or configure the consuming pipeline's `withLabel: fhr` container and Docker executor. The JSON serialization task uses native `exec` and runs in Nextflow's JVM. It writes UTF-8 without `\u` escapes and omits map entries whose value is `null`. Values with no unambiguous JSON form (for example `Date`/`LocalDate`, NaN, Infinity, `null` list items or non-string keys) are rejected with the field location; supply dates as ISO 8601 strings. Sets are written as arrays. Converter tasks use the configured executor and request defaults from the consumer.

Compatibility and versioning rules are documented in [the release policy](CONTRIBUTING.md#compatibility-and-release-policy).

## Verify

```sh
python tests/run.py --converter-source ../FAIR-bioHeaders-Tools
```

The stdlib Python harness runs native DSL2 integration tests from an external project: five metadata format round trips; FASTA/GFA attach, checksum validation and exact-byte stripping; Unicode and shell metacharacters; JSON serialization edge cases; per-file IDs for several metadata files and duplicate-ID rejection; publication without placeholder checksums; invalid fields, malformed JSON, unsafe IDs, unsupported formats and tampered file checksums. With a converter checkout it also runs the converter's pytest suite and checks that failing tests (including after `-resume`) and mismatched checkout versions withhold results while publishing reports. The checkout must declare version **0.4.0**; it is copied into the task directory, so it is never modified, and its library tests import the installed, pinned distribution (tests that run the checkout's own scripts use the copied checkout, which the version check ties to 0.4.0). [CI](.github/workflows/ci.yml) runs the harness and the Docker example.

`environment/requirements.txt` is the single, hash-locked source of Python dependencies for the container, CI and local environments; edit `environment/requirements.in` and regenerate it with the command at its top. The container also pins its Python base image digest. Preserve the resulting image digest when sharing a reproducible pipeline. No network access is required for FHR validation after installation.

## Reference

Wright, Adam, Mark D. Wilkinson, Christopher Mungall, Scott Cain, Stephen Richards, Paul Sternberg, Ellen Provin, et al. 2024. “FAIR Header Reference Genome: A TRUSTworthy Standard.” *Briefings in Bioinformatics* 25 (3): bbae122. https://doi.org/10.1093/bib/bbae122.

## Project documentation

- [Pipeline guide](docs/PIPELINES.md): module composition, test integration, execution and troubleshooting.
- [Contributing](CONTRIBUTING.md): development checks, metadata coordination and release preparation.
- [Code of conduct](CODE_OF_CONDUCT.md) and [security policy](SECURITY.md): private reporting and independent conflict/appeal routing.
- [Agent instructions](AGENTS.md): repository layout and implementation strategy inferred from the FHR paper.
- [Citation metadata](CITATION.cff), [license notice](LICENSE) and [changelog](CHANGELOG.md).

This repository is licensed under the [Mozilla Public License 2.0](LICENSE) (`MPL-2.0`). External dependencies retain their own licenses. The suite has no published DOI; the paper citation describes the FHR standard. Schema governance rests with the maintainers, David and Adam ([GOVERNANCE](https://github.com/FAIR-bioHeaders/FHR-Specification/blob/main/GOVERNANCE.md)).

## Licensing

[![License: MPL-2.0](https://img.shields.io/badge/License-MPL--2.0-blue.svg)](LICENSE)

This repository already uses [MPL-2.0](LICENSE), consistent with the organization policy for new project work from March 2025 onward. It does not use the companion repositories’ historical USDA public-domain notice. External dependencies retain their own licenses and prior releases retain their published terms.
