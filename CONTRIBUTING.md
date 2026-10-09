# Contributing

This is the development prototype for [FHR-Specification issue #15](https://github.com/FAIR-bioHeaders/FHR-Specification/issues/15). Development is hosted in [FHR-Nextflow](https://github.com/FAIR-bioHeaders/FHR-Nextflow); there is no published release yet. Develop on a focused branch and submit a pull request for review, or commit directly to main when explicitly requested. Publishing releases or changing repository visibility requires an explicit request.

Start with a use case or reproducible failure. Keep changes focused and explain the resulting behavior, compatibility implications and relevant verification. Use synthetic fixtures; exclude private genome data, credentials and unrelated formatting. Follow the [code of conduct](CODE_OF_CONDUCT.md); report sensitive findings using [SECURITY.md](SECURITY.md).

## Development environment

Follow [README.md](README.md) for Nextflow 26.04.6, Java 21 and the Python 3.13 converter environment. The pinned converter is 0.4.0; its schema validation is the source of truth. From this checkout:

```sh
python tests/run.py
python tests/run.py --converter-source ../FAIR-bioHeaders-Tools
git diff --check
```

Use a converter v0.4.0 checkout for reproducible pytest inputs. To verify the container path:

```sh
docker build -t fhr-nextflow:0.1.0 environment
nextflow run main.nf -profile docker \
  --sequence examples/assembly.gfa --sequence_format gfa \
  --converter_source ../FAIR-bioHeaders-Tools
```

The integration harness checks imports from an external DSL2 project, five metadata formats, exact-byte FASTA/GFA preservation, quoting, JSON serialization edge cases, per-file IDs, publication gates and invalid cases. It uses explicit checks, so it remains effective under `python -O`. Add a regression case when changing behavior. [CI](.github/workflows/ci.yml) runs the harness and the Docker example on the supported baseline; keep its pinned versions and action digests in step with the compatibility baseline. For documentation-only changes, verify links, examples and command names; a full pipeline rerun is unnecessary unless an executable example changes.

## Module and metadata changes

Keep JSON serialization and orchestration native to Nextflow. Reuse the converter for validation, conversion and checksum calculation; do not introduce a second schema or validator. Preserve `meta` in tuples, validate output IDs, quote staged paths and whitelist command formats. Write native `exec` outputs under `task.workDir`. Preserve the intentional CRLF fixtures, protected by `.gitattributes`.

Update channel contracts in README and the [pipeline guide](docs/PIPELINES.md) when inputs or outputs change. Keep examples and tests consistent. Document checksum and SeqCol semantics: the former can be computed during attachment, while the latter is supplied by the caller. Do not infer authors, accessions or software provenance.

Schema changes belong in FHR-Specification and must coordinate converter schema copies, serializers, examples and mapping documentation. David Molik and Adam Wright are the maintainers and jointly hold schema authority ([GOVERNANCE](https://github.com/FAIR-bioHeaders/FHR-Specification/blob/main/GOVERNANCE.md)); the steering-group option described there is not active.

## Documentation, citations and releases

Use Chicago bibliography entries with DOI resolver links for human-readable citations. Keep the paper, preprint, specification, converter and module suite distinct. [CITATION.cff](CITATION.cff) records the preferred FHR paper; do not assign this suite the converter's or specification's DOI.

Record compatibility and user-facing changes in [CHANGELOG.md](CHANGELOG.md). Suite version, converter version and schemaVersion are separate. Before a release, review dependency pins, run integration and container checks, and record the converter checkout and image digest used. Preparing a release does not authorize publication or changes to ownership. Keep cross-repository work linked to the specification issue and release tracker.

Contributions to this repository are made under [MPL-2.0](LICENSE). Preserve license notices in source files and retain the licenses of external dependencies.

## Compatibility and release policy

The current tested combination is Nextflow 26.04.6, Java 21, Python 3.13, FAIR-bioHeaders-Tools 0.4.0 and FHR schemaVersion 1. These are the supported development baseline; newer Nextflow versions allowed by the manifest are not automatically verified. Other converters or schema versions require explicit compatibility review and passing integration tests before being declared supported. Older suite releases have no maintenance or long-term support commitment.

Suite versions describe this module API independently of converter releases and schemaVersion:

- **Patch:** compatible bug fixes, documentation corrections or environment updates that preserve channel contracts, metadata semantics and supported inputs.
- **Minor:** additive modules, optional inputs or outputs, or newly tested compatibility combinations that preserve existing consumers.
- **Major:** changes that break existing tuple contracts, remove modules or supported inputs, change output semantics, or drop a supported runtime combination. Document migration instructions.

During the initial `0.x` development series, breaking changes increment the minor version and include migration notes; compatible fixes increment the patch version. `0.1.0-dev` is an unreleased development identifier, not an issued release. The first stable `1.0.0` release establishes the stable API policy above.

A converter or schema upgrade is reviewed on its actual effect on consumers, rather than automatically matching the dependency's version number. Do not silently change checksum semantics. Record tested combinations in README and CHANGELOG, update `environment/requirements.in`, the regenerated hash-locked `environment/requirements.txt`, CI pins and version guards together, and run the integration harness plus converter tests and the container example. Pin the resulting container digest and record the converter source commit for release verification. Publish a version tag and release notes only when authorized. This project's release lifecycle is independent of the companion schema/converter release.

## License of contributions

Contributions to this repository are made under [MPL-2.0](LICENSE). Contributors must have the rights needed to submit their contributions under that license. This repository does not use the companion repositories’ historical USDA public-domain notice. External dependencies retain their own licenses. Future releases must preserve this repository’s MPL-2.0 terms and retain source notices.
