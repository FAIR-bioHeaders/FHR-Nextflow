include { fhrFormat; quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_CONVERT {
    tag "${meta.id}: ${format}"
    label 'fhr'

    input:
    tuple val(meta), path(metadata, stageAs: 'input/*'), val(format)

    output:
    tuple val(meta), path("${meta.id}.fhr.${format}"), emit: converted
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    def id = sampleId(meta)
    def ext = fhrFormat(format, ['json', 'yaml', 'html', 'fasta', 'gfa'])
    """
    ${versionCheck()}
    fhr-convert ${quote(metadata)} ${quote("${id}.fhr.${ext}")}
    ${versionReport()}
    """
}
