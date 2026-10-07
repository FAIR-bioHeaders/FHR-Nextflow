include { FHR_CREATE_JSON } from './modules/create_json/main'
include { FHR_CONVERT } from './modules/convert/main'
include { FHR_ATTACH } from './subworkflows/attach/main'
include { FHR_CONVERTER_TESTS } from './modules/converter_tests/main'

workflow {
    def input = params.metadata ?: "${projectDir}/examples/metadata.json"
    records = Channel.fromPath(input, checkIfExists: true).map { source ->
        tuple([id: params.id], new groovy.json.JsonSlurper().parseText(source.text))
    }
    FHR_CREATE_JSON(records)
    FHR_CONVERT(FHR_CREATE_JSON.out.json.map { meta, json -> tuple(meta, json, 'yaml') })

    FHR_CREATE_JSON.out.json.subscribe { meta, json ->
        def dest = file("${params.outdir}/${meta.id}/metadata"); dest.mkdirs()
        java.nio.file.Files.copy(json, dest.resolve(json.name), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
    }
    FHR_CONVERT.out.converted.subscribe { meta, yaml ->
        def dest = file("${params.outdir}/${meta.id}/metadata"); dest.mkdirs()
        java.nio.file.Files.copy(yaml, dest.resolve(yaml.name), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
    }
    if (params.sequence) {
        FHR_ATTACH(FHR_CREATE_JSON.out.json.map { meta, json ->
            tuple(meta, json, file(params.sequence, checkIfExists: true), params.sequence_format)
        })
        FHR_ATTACH.out.sequence.subscribe { meta, sequence ->
            def dest = file("${params.outdir}/${meta.id}/sequence"); dest.mkdirs()
            java.nio.file.Files.copy(sequence, dest.resolve(sequence.name), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        }
        FHR_ATTACH.out.json.subscribe { meta, json ->
            def dest = file("${params.outdir}/${meta.id}/sequence"); dest.mkdirs()
            java.nio.file.Files.copy(json, dest.resolve(json.name), java.nio.file.StandardCopyOption.REPLACE_EXISTING)
        }
    }
    if (params.converter_source) {
        FHR_CONVERTER_TESTS(Channel.value(tuple([id:'converter'], file(params.converter_source, checkIfExists:true))))
        FHR_CONVERTER_TESTS.out.reports.subscribe { meta, xml, log ->
            def dest = file("${params.outdir}/converter-tests"); dest.mkdirs()
            [xml, log].each { source -> java.nio.file.Files.copy(source, dest.resolve(source.name), java.nio.file.StandardCopyOption.REPLACE_EXISTING) }
        }
    }
}
