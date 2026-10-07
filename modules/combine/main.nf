include { fhrFormat; quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_COMBINE {
    tag "${meta.id}: ${kind}"
    label 'fhr'

    input:
    tuple val(meta), path(metadata, stageAs: 'metadata/*'), path(sequence, stageAs: 'sequence/*'), val(kind)

    output:
    tuple val(meta), path("${meta.id}.fhr.${kind}"), emit: combined
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    def id = sampleId(meta)
    def type = fhrFormat(kind, ['fasta', 'gfa'])
    """
    ${versionCheck()}
    fhr-${type}-combine ${quote(metadata)} ${quote(sequence)} -o ${quote("${id}.fhr.${type}")}
    ${versionReport()}
    """
}
