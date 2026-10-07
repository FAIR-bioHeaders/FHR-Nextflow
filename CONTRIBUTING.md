# Contributing

This is the local prototype for [FHR-Specification issue #15](https://github.com/FAIR-bioHeaders/FHR-Specification/issues/15). There is no GitHub repository or published release yet. Develop on a focused local branch and provide a diff or commit for review. Creating a remote, publishing, or pushing requires an explicit request.

Start with a use case or reproducible failure. Keep changes focused and explain the resulting behavior, compatibility implications and relevant verification. Use synthetic fixtures; exclude private genome data, credentials and unrelated formatting. Follow the [code of conduct](CODE_OF_CONDUCT.md); report sensitive findings using [SECURITY.md](SECURITY.md).

## Development environment

Follow [README.md](README.md) for Nextflow 26.04.6, Java 21 and the Python 3.13 converter environment. The pinned converter is 0.3.0; its schema validation is the source of truth. From this checkout:

```sh
python tests/run.py
python tests/run.py --converter-source ../FHR-File-Converter
git diff --check
```

Use a converter v0.3.0 checkout for reproducible pytest inputs. To verify the container path:

```sh
docker build -t fhr-nextflow:0.1.0 environment
nextflow run main.nf -profile docker \
  --sequence examples/assembly.gfa --sequence_format gfa \
  --converter_source ../FHR-File-Converter
```

The integration harness checks imports from an external DSL2 project, five metadata formats, exact-byte FASTA/GFA preservation, quoting and six invalid cases. Add a regression case when changing behavior. For documentation-only changes, verify links, examples and command names; a full pipeline rerun is unnecessary unless an executable example changes.

## Module and metadata changes

Keep JSON serialization and orchestration native to Nextflow. Reuse the converter for validation, conversion and checksum calculation; do not introduce a second schema or validator. Preserve `meta` in tuples, validate output IDs, quote staged paths and whitelist command formats. Write native `exec` outputs under `task.workDir`. Preserve the intentional CRLF fixtures, protected by `.gitattributes`.

Update channel contracts in README and the [pipeline guide](docs/PIPELINES.md) when inputs or outputs change. Keep examples and tests consistent. Document checksum and SeqCol semantics: the former can be computed during attachment, while the latter is supplied by the caller. Do not infer authors, accessions or software provenance.

Schema changes belong in FHR-Specification and must coordinate converter schema copies, serializers, examples and mapping documentation. David Molik and Adam Wright retain schema authority. The [successor governance proposal](https://github.com/FAIR-bioHeaders/FHR-Specification/blob/main/GOVERNANCE.md) remains a proposal until explicitly adopted.

## Documentation, citations and releases

Use Chicago bibliography entries with DOI resolver links for human-readable citations. Keep the paper, preprint, specification, converter and module suite distinct. [CITATION.cff](CITATION.cff) records the preferred FHR paper; do not assign this suite the converter's or specification's DOI.

Record compatibility and user-facing changes in [CHANGELOG.md](CHANGELOG.md). Suite version, converter version and schemaVersion are separate. Before a release, review dependency pins, run integration and container checks, and record the converter checkout and image digest used. Preparing a release does not authorize publication or changes to ownership. Keep cross-repository work linked to the specification issue and release tracker.

Contributions to this repository are made under [MPL-2.0](LICENSE). Preserve license notices in source files and retain the licenses of external dependencies.
