include { quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_CONVERTER_TESTS {
    tag "${meta.id}"
    label 'fhr'

    input:
    tuple val(meta), path(converter_source)

    output:
    tuple val(meta), path('converter-tests.xml'), path('converter-tests.log'), emit: reports
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    sampleId(meta)
    """
    ${versionCheck()}
    python -m pytest ${quote(converter_source.resolve('tests'))} --rootdir=${quote(converter_source)} -c ${quote(converter_source.resolve('pytest.ini'))} -p no:cacheprovider --junitxml=converter-tests.xml > converter-tests.log 2>&1
    ${versionReport()}
    """
}
