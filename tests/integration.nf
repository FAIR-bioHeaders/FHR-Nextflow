include { FHR_CREATE_JSON } from '../modules/create_json/main'
include { FHR_CONVERT as TO_FORMAT } from '../modules/convert/main'
include { FHR_CONVERT as BACK_JSON } from '../modules/convert/main'
include { FHR_ATTACH } from '../subworkflows/attach/main'
include { FHR_STRIP } from '../modules/strip/main'

process ASSERT_ROUNDTRIP {
    input:
    tuple val(meta), val(json)
    output:
    path "${meta.id}.ok"
    exec:
    def actual = new groovy.json.JsonSlurper().parseText(json.text)
    assert actual == meta.expected
    task.workDir.resolve("${meta.id}.ok").text = 'OK\n'
}
process ASSERT_BYTES {
    input:
    tuple val(meta), val(sequence)
    output:
    path "${meta.id}.ok"
    exec:
    assert java.util.Arrays.equals(sequence.bytes, file(meta.original).bytes)
    task.workDir.resolve("${meta.id}.ok").text = 'OK\n'
}
workflow {
    def fields = new groovy.json.JsonSlurper().parseText(file(params.fixture).text)
    FHR_CREATE_JSON(Channel.of(tuple([id: 'rich'], fields)))
    TO_FORMAT(FHR_CREATE_JSON.out.json.flatMap { meta, json ->
        ['json', 'yaml', 'html', 'fasta', 'gfa'].collect { fmt -> tuple([id: fmt, expected: fields], json, fmt) }
    })
    BACK_JSON(TO_FORMAT.out.converted.map { meta, metadata -> tuple(meta, metadata, 'json') })
    ASSERT_ROUNDTRIP(BACK_JSON.out.converted)
    FHR_ATTACH(FHR_CREATE_JSON.out.json.flatMap { meta, json ->
        ['fasta', 'gfa'].collect { kind ->
            def original = file("${params.fixtures}/${kind == 'fasta' ? 'genome.fasta' : 'assembly.gfa'}")
            tuple([id: "attached-${kind}", original: original.toString()], json, original, kind)
        }
    })
    FHR_STRIP(FHR_ATTACH.out.sequence.map { meta, sequence -> tuple(meta, sequence, sequence.name.endsWith('.fasta') ? 'fasta' : 'gfa') })
    ASSERT_BYTES(FHR_STRIP.out.stripped)
}
