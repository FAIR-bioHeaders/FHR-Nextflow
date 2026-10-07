include { FHR_COMBINE } from '../../modules/combine/main'
include { FHR_VALIDATE as CHECK_COMBINED } from '../../modules/validate/main'
include { FHR_CONVERT as EXTRACT_JSON } from '../../modules/convert/main'

workflow FHR_ATTACH {
    take:
    records // tuple(meta, metadata, sequence, kind)

    main:
    FHR_COMBINE(records)
    CHECK_COMBINED(FHR_COMBINE.out.combined.map { meta, sequence ->
        tuple(meta, sequence, sequence.name.endsWith('.fasta') ? 'fasta' : 'gfa')
    })
    EXTRACT_JSON(CHECK_COMBINED.out.validated.map { meta, sequence -> tuple(meta, sequence, 'json') })

    emit:
    sequence = CHECK_COMBINED.out.validated
    json = EXTRACT_JSON.out.converted
    reports = CHECK_COMBINED.out.reports
    versions = FHR_COMBINE.out.versions.mix(CHECK_COMBINED.out.versions, EXTRACT_JSON.out.versions)
}
