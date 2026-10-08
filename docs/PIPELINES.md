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
    // reports emits tuple(meta, junit_xml, test_log) whether or not tests pass.
    // passed emits meta only after every test passes.
}
```

Provide a converter source directory containing `pyproject.toml`, `tests/` and `pytest.ini` that declares version 0.3.1, preferably the v0.3.1 checkout; other versions are rejected, and the installed converter version is checked separately. The workflow copies the checkout into its task directory (the input is never modified and no bytecode is written), runs its tests against the installed converter (tests that invoke the checkout's own scripts use the copy), and always emits JUnit XML plus a log so that they can be published. A separate check task then fails the run if pytest failed. An independent test branch does not gate other workflow outputs automatically: combine release or publication channels with `FHR_CONVERTER_TESTS.out.passed` if those steps must wait for passing tests, as the example `main.nf` does:

```nextflow
gate = FHR_CONVERTER_TESTS.out.passed.first()
gated = FHR_ATTACH.out.json.combine(gate).map { meta, json, _passed -> tuple(meta, json) }
```

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

Modules leave files in their task work directories. The example workflow publishes with Nextflow workflow outputs (`publish:` and `output {}`), copying results into `params.outdir` per sample ID, and withholds them until converter tests pass when `--converter_source` is given; production consumers should define their own publication rules and retain logs and version reports appropriate to their provenance needs. Use unique sample IDs and keep Nextflow work directories while downstream tasks still require them. The supplied Docker profile runs containers as the invoking user, so work files are not root-owned.

## Diagnosing failures

- **Invalid metadata:** inspect the validator error and compare the map with the pinned specification. JSON serialization succeeds independently of schema validation; only validated JSON is emitted by `FHR_CREATE_JSON`.
- **Converter version mismatch:** install the pinned distribution or use the supplied image. Upgrade the compatibility contract and tests together before accepting another version.
- **Checksum mismatch:** verify that no program changed the header, whitespace, line endings or sequence bytes after attachment. Reattach when changing metadata.
- **Unsafe ID or unsupported format:** use IDs and format values from the README contract. Paths are quoted; command formats are explicitly restricted.
- **Failed converter tests:** inspect the published `converter-tests/converter-tests.log` and JUnit XML. A checkout that does not declare version 0.3.1 is rejected before tests run.
- **JSON serialization errors:** the message names the field location, for example `$.dateCreated`; convert dates to ISO 8601 strings and remove NaN, Infinity and `null` list items.

See [SECURITY.md](../SECURITY.md) for sensitive findings and [CONTRIBUTING.md](../CONTRIBUTING.md) for changes to modules or their contracts.
