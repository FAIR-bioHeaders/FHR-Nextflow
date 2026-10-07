**This is a demo repository**, do not deploy. 

# FHR-Nextflow

Reusable Nextflow DSL2 modules for creating, converting, validating and attaching [FAIR bioHeaders](https://doi.org/10.1093/bib/bbae122). This local prototype implements [FHR-Specification issue #15](https://github.com/FAIR-bioHeaders/FHR-Specification/issues/15). It has no GitHub remote and is not a published release.

Compatibility: Nextflow **26.04.6**, Java **21**, FHR-File-Converter **0.3.0**, FHR schemaVersion **1**. The suite version is **0.1.0-dev**. JSON creation and channel composition are native DSL2/Groovy; the converter supplies schema validation, format conversion and file checksums.

## Run the example

Install Nextflow and Java using the [official instructions](https://docs.seqera.io/nextflow/install). Then install the converter environment in an isolated Python 3.13 environment:

```sh
python3.13 -m venv .venv
. .venv/bin/activate
pip install -r environment/requirements.txt
nextflow run main.nf --metadata examples/metadata.json \
  --sequence examples/genome.fasta --sequence_format fasta
```

Alternatively, build the supplied container and enable Docker:

```sh
docker build -t fhr-nextflow:0.1.0 environment
nextflow run main.nf -profile docker \
  --sequence examples/assembly.gfa --sequence_format gfa
```

Outputs appear under `results/example/metadata/` (standalone JSON/YAML) and `results/example/sequence/` (attached sequence and its matching JSON). Use `--id SAMPLE --outdir DIRECTORY` to change these. Without `--sequence`, only metadata is created. Add `--converter_source ../FHR-File-Converter` to emit pytest JUnit XML and the test log under `results/converter-tests/`.

**Example metadata is synthetic.** Its checksum and SeqCol digest are explicit placeholders. Replace all provenance and identifiers with your own inputs. Attaching a sequence replaces the checksum with its actual FHR checksum; it does not calculate or verify SeqCol identity.

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

Every input/output preserves `meta`, a map containing an `id`. IDs must start with a letter/digit and contain only letters, digits, dots, underscores or hyphens. Use unique IDs within a pipeline. File outputs remain in Nextflow task work directories; consumers control publication.

| Component | Input tuple | Named outputs |
| --- | --- | --- |
| `FHR_CREATE_JSON` workflow | `(meta, fields_map)` | `json`: `(meta, json)` after validation; `reports`: `(meta, validation.txt)`; `versions` |
| `FHR_CONVERT` process | `(meta, metadata_path, output_format)` | `converted`: `(meta, output)`; `versions` |
| `FHR_VALIDATE` process | `(meta, input_path, kind)` | `validated`: `(meta, input_path)` after success; `reports`; `versions` |
| `FHR_COMBINE` process | `(meta, metadata_path, sequence_path, kind)` | `combined`: `(meta, attached_sequence)`; `versions` |
| `FHR_STRIP` process | `(meta, sequence_path, kind)` | `stripped`: `(meta, sequence_without_header)`; `versions` |
| `FHR_CONVERTER_TESTS` process | `(meta, converter_source_directory)` | `reports`: `(meta, junit_xml, log)`; `versions` |
| `FHR_ATTACH` workflow | `(meta, metadata_path, sequence_path, kind)` | `sequence`: validated attached sequence; `json`: matching extracted metadata; `reports`; mixed `versions` |

`output_format`: `json`, `yaml`, `html`, `fasta`, `gfa`. Input format is inferred by the converter from extension; YAML `.yml` is also accepted. Converting metadata to FASTA/GFA produces **only a header**, not sequence content. Use `FHR_COMBINE` or preferably `FHR_ATTACH` to construct a complete file.

`kind`: `metadata` for JSON/YAML/HTML/schema validation, or `fasta`/`gfa` for full-file checksum validation. Combine and strip accept only `fasta`/`gfa`. Metadata schema validation cannot establish that a supplied checksum matches any sequence. Validation failures stop the task and gate downstream validated outputs. Converter tests likewise fail the task if any test fails; failure logs remain in its work directory.

Each command task checks the installed converter version and emits `(meta, versions.yml)`. The consuming pipeline must enable DSL2 (`nextflow.enable.dsl = 2` in its config). Importing modules does not inherit this project's config: install the pinned environment or configure the consuming pipeline's `withLabel: fhr` container and Docker executor. The JSON serialization task uses native `exec` and runs in Nextflow's JVM. Converter tasks use the configured executor and request defaults from the consumer.

## Verify

```sh
python tests/run.py --converter-source ../FHR-File-Converter
```

The stdlib Python harness runs native DSL2 integration tests from an external project: five metadata format round trips; FASTA/GFA attach, checksum validation and exact-byte stripping; Unicode and shell metacharacters; invalid fields, malformed JSON, unsafe IDs, unsupported formats and tampered file checksums. The optional converter checkout runs its own pytest suite and checks JUnit failures. Use a checkout of converter **v0.3.0** for reproducible test inputs. Installed converter code remains the pinned distribution.

The container pins its Python base image digest, converter wheel SHA256 and direct Python dependencies. Transitive dependencies are resolved at build time; preserve the resulting image digest when sharing a reproducible pipeline. No network access is required for FHR validation after installation.

## Reference

Wright, Adam, Mark D. Wilkinson, Christopher Mungall, Scott Cain, Stephen Richards, Paul Sternberg, Ellen Provin, et al. 2024. “FAIR Header Reference Genome: A TRUSTworthy Standard.” *Briefings in Bioinformatics* 25 (3): bbae122. https://doi.org/10.1093/bib/bbae122.

## Project documentation

- [Pipeline guide](docs/PIPELINES.md): module composition, test integration, execution and troubleshooting.
- [Contributing](CONTRIBUTING.md): development checks, metadata coordination and release preparation.
- [Code of conduct](CODE_OF_CONDUCT.md) and [security policy](SECURITY.md): private reporting and independent conflict/appeal routing.
- [Agent instructions](AGENTS.md): repository layout and implementation strategy inferred from the FHR paper.
- [Citation metadata](CITATION.cff), [license notice](LICENSE) and [changelog](CHANGELOG.md).

This repository is licensed under the [Mozilla Public License 2.0](LICENSE) (`MPL-2.0`). External dependencies retain their own licenses. The suite has no published DOI; the paper citation describes the FHR standard. Schema governance remains with David and Adam until the companion successor proposal is adopted.
