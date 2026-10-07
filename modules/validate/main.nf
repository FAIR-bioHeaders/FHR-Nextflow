include { fhrFormat; quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_VALIDATE {
    tag "${meta.id}: ${kind}"
    label 'fhr'

    input:
    tuple val(meta), path(metadata, stageAs: 'input/*'), val(kind)

    output:
    tuple val(meta), path(metadata), emit: validated
    tuple val(meta), path('validation.txt'), emit: reports
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    sampleId(meta)
    def type = fhrFormat(kind, ['metadata', 'fasta', 'gfa'])
    def command = type == 'metadata' ? 'fhr-validate' : "fhr-${type}-validate"
    """
    ${versionCheck()}
    ${command} ${quote(metadata)} > validation.txt
    ${versionReport()}
    """
}
