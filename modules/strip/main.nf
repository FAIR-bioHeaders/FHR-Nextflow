include { fhrFormat; quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_STRIP {
    tag "${meta.id}: ${kind}"
    label 'fhr'

    input:
    tuple val(meta), path(sequence, stageAs: 'input/*'), val(kind)

    output:
    tuple val(meta), path("${meta.id}.stripped.${kind}"), emit: stripped
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    def id = sampleId(meta)
    def type = fhrFormat(kind, ['fasta', 'gfa'])
    """
    ${versionCheck()}
    fhr-${type}-strip ${quote(sequence)} ${quote("${id}.stripped.${type}")}
    ${versionReport()}
    """
}
