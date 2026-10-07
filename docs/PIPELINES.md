# Building FHR pipelines

See [README](../README.md) for setup and complete module contracts. These modules preserve caller-supplied metadata and use the converter's schema; they do not infer biological provenance or query external services.

## Construct metadata, attach it, and validate

A record has two separate maps: `meta` carries the pipeline ID and any routing information; `fields` contains the FHR document. Pipeline IDs do not automatically become FHR identifiers. Load fields from JSON as in the example workflow or construct a map from upstream results. Supply every required field and any known optional fields.

The following composition consumes an existing `records` channel of `(meta, fields)` tuples and a single sequence file supplied as `params.sequence`:

```nextflow
include { FHR_CREATE_JSON } from '/path/to/FHR-Nextflow/modules/create_json/main'
include { FHR_ATTACH } from '/path/to/FHR-Nextflow/subworkflows/attach/main'

workflow {
    // Define records upstream: tuple([id: 'assembly1'], fields).
    FHR_CREATE_JSON(records)
    FHR_ATTACH(FHR_CREATE_JSON.out.json.map { meta, json ->
        tuple(meta, json, file(params.sequence, checkIfExists: true), 'fasta')
    })
    // FHR_ATTACH.out.sequence contains checksum-validated FASTA files.
    // FHR_ATTACH.out.json contains JSON with each attached file's checksum.
}
```

This is a composition fragment: define `records` in the consuming workflow before using it. Set `nextflow.enable.dsl = 2` in that project's config. For several assemblies, pair each validated JSON with its corresponding sequence by a stable sample ID rather than relying on channel arrival order. Use `gfa` instead of `fasta` for GFA files.

Standalone JSON requires an explicit schema-valid checksum. Attachment replaces that value with the final file checksum; downstream consumers should use `FHR_ATTACH.out.json` when referring to the attached sequence. The algorithm is **SHA-512/256**, not a manually truncated SHA-512 digest. Encode its 32-byte digest using standard padded base64 (44 characters), without a prefix. It covers the exact file bytes except the scalar root checksum line and its terminator; preserve line endings, whitespace, comments and all other metadata. See the [specification checksum contract](https://github.com/FAIR-bioHeaders/FHR-Specification/blob/v0.3.0/docs/FORMAT.md#checksum-decision-for-v03). It is not a checksum of sequence letters alone. A supplied `seqcol_id` is preserved, not computed or verified against sequence content.

## Run converter tests as part of a pipeline

```nextflow
include { FHR_CONVERTER_TESTS } from '/path/to/FHR-Nextflow/modules/converter_tests/main'

workflow {
    FHR_CONVERTER_TESTS(Channel.value(tuple(
        [id: 'converter-tests'],
        file(params.converter_source, checkIfExists: true)
    )))
    // reports emits tuple(meta, junit_xml, test_log) after pytest succeeds.
}
```

Provide a converter source directory containing `tests/` and `pytest.ini`, preferably the v0.3.0 checkout. The installed converter version is checked separately. The module runs that checkout's tests and emits JUnit XML plus a log. It fails the task if pytest fails; inspect the task work directory for failed-run logs. An independent test branch does not gate other workflow outputs automatically. Connect it to your release or publication dependency graph if those steps must wait for passing tests.

## Execution and publication

Converter processes have the label `fhr`. Configuration from this repository does not accompany imports into another project. With the supplied image built locally, a consumer can configure:

```groovy
nextflow.enable.dsl = 2
docker.enabled = true
process {
    withLabel: fhr {
        container = 'fhr-nextflow:0.1.0'
        cpus = 1
        memory = '1 GB'
        time = '30m'
    }
}
```

The native JSON writer executes in Nextflow's JVM. Command wrappers use the consumer's executor. Remote executors need access to the converter environment or an available container image; a locally built Docker tag is not automatically accessible on a cluster.

Modules leave files in their task work directories. The example workflow copies successful outputs into `params.outdir`; production consumers should define their own publication rules and retain logs and version reports appropriate to their provenance needs. Use unique sample IDs and keep Nextflow work directories while downstream tasks still require them.

## Diagnosing failures

- **Invalid metadata:** inspect the validator error and compare the map with the pinned specification. JSON serialization succeeds independently of schema validation; only validated JSON is emitted by `FHR_CREATE_JSON`.
- **Converter version mismatch:** install the pinned distribution or use the supplied image. Upgrade the compatibility contract and tests together before accepting another version.
- **Checksum mismatch:** verify that no program changed the header, whitespace, line endings or sequence bytes after attachment. Reattach when changing metadata.
- **Unsafe ID or unsupported format:** use IDs and format values from the README contract. Paths are quoted; command formats are explicitly restricted.
- **Failed converter tests:** inspect `converter-tests.log` in the task work directory and confirm the supplied checkout matches the pinned converter.

See [SECURITY.md](../SECURITY.md) for sensitive findings and [CONTRIBUTING.md](../CONTRIBUTING.md) for changes to modules or their contracts.
