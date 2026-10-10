// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

include { FHR_CREATE_JSON } from './modules/create_json/main'
include { FHR_CONVERT } from './modules/convert/main'
include { FHR_ATTACH } from './subworkflows/attach/main'
include { FHR_CONVERTER_TESTS } from './modules/converter_tests/main'
include { GFF3_VALIDATE } from './modules/gff3_validate/main'
include { isSampleId } from './modules/utils/main'

// One record per metadata file. --id names the output of a single file;
// otherwise each ID is the file name without .fhr.json or .json. Functions
// return problems rather than throwing so that Nextflow reports the message.
def metadataId(Path source) {
    return params.id ? params.id.toString() : (params.metadata ? source.name.replaceFirst(/(\.fhr)?\.json$/, '') : 'example')
}

def metadataIdProblem(List sources) {
    if (params.id && sources.size() > 1)
        return "--id names a single output, but --metadata matched ${sources.size()} files; omit --id to derive each ID from its file name"
    def invalid = sources.find { source -> !isSampleId(metadataId(source)) }
    if (invalid)
        return "Invalid meta.id '${metadataId(invalid)}' for ${invalid}: meta.id must contain only letters, digits, dot, underscore or hyphen, starting with a letter or digit; rename the file or use --id"
    def duplicates = sources.groupBy { source -> metadataId(source) }.findAll { id, group -> group.size() > 1 }
    if (duplicates)
        return 'Duplicate meta.id from metadata files: ' + duplicates.collect { id, group -> "${id} (${group.join(', ')})" }.join('; ')
    return null
}

// One record per --gff3 file; its ID is the file name without .gff3/.gff and .gz.
def gff3Id(Path source) {
    return source.name.replaceFirst(/\.(gff3|gff)(\.gz)?$/, '')
}

def gff3IdProblem(List sources) {
    def invalid = sources.find { source -> !isSampleId(gff3Id(source)) }
    if (invalid)
        return "Invalid meta.id '${gff3Id(invalid)}' for ${invalid}: meta.id must contain only letters, digits, dot, underscore or hyphen, starting with a letter or digit; rename the GFF3 file"
    def duplicates = sources.groupBy { source -> gff3Id(source) }.findAll { id, group -> group.size() > 1 }
    if (duplicates)
        return 'Duplicate meta.id from GFF3 files: ' + duplicates.collect { id, group -> "${id} (${group.join(', ')})" }.join('; ')
    return null
}

workflow {
    main:
    def input = params.metadata ?: "${projectDir}/examples/metadata.json"
    records = channel.fromPath(input, checkIfExists: true).toSortedList().flatMap { sources ->
        def problem = metadataIdProblem(sources)
        if (problem)
            throw new IllegalArgumentException(problem)
        sources.collect { source ->
            def fields
            try {
                fields = new groovy.json.JsonSlurper().parseText(source.getText('UTF-8'))
            } catch (Exception e) {
                throw new IllegalArgumentException("Cannot parse metadata JSON ${source}: ${e.message}")
            }
            tuple([id: metadataId(source)], fields)
        }
    }
    FHR_CREATE_JSON(records)

    // With --sequence, only the attached file and metadata extracted from it are
    // published: their checksum is computed from the attached file, whereas the
    // standalone checksum is whatever the input supplied (a placeholder in the example).
    FHR_ATTACH(params.sequence
        ? FHR_CREATE_JSON.out.json.map { meta, json -> tuple(meta, json, file(params.sequence, checkIfExists: true), params.sequence_format) }
        : channel.empty())
    final_json = params.sequence ? FHR_ATTACH.out.json : FHR_CREATE_JSON.out.json
    FHR_CONVERT(final_json.map { meta, json -> tuple(meta, json, 'yaml') })

    // With --gff3, each file is validated (optionally against --gff3_genome); see
    // the gff3_* options in nextflow.config. Reports are published per ID.
    def genome = params.gff3_genome ? file(params.gff3_genome, checkIfExists: true) : []
    GFF3_VALIDATE(params.gff3
        ? channel.fromPath(params.gff3, checkIfExists: true).toSortedList().flatMap { sources ->
            def problem = gff3IdProblem(sources)
            if (problem)
                throw new IllegalArgumentException(problem)
            sources.collect { source -> tuple([id: gff3Id(source)], source, genome) }
        }
        : channel.empty())

    // With --converter_source, results are published only after converter tests
    // pass. Test reports are published either way and failing tests fail the run.
    FHR_CONVERTER_TESTS(params.converter_source
        ? channel.of(tuple([id: 'converter'], file(params.converter_source, checkIfExists: true)))
        : channel.empty())
    gate = params.converter_source ? FHR_CONVERTER_TESTS.out.passed.first() : channel.value([id: 'converter'])
    results = final_json.mix(FHR_CONVERT.out.converted, FHR_ATTACH.out.sequence)
        .combine(gate)
        .map { meta, path, _passed -> tuple(meta, path) }
    gff3_reports = GFF3_VALIDATE.out.reports
        .combine(gate)
        .flatMap { meta, json, html, _passed -> [tuple(meta, json), tuple(meta, html)] }

    publish:
    metadata = params.sequence ? channel.empty() : results
    sequence = params.sequence ? results : channel.empty()
    gff3 = gff3_reports
    converter_tests = FHR_CONVERTER_TESTS.out.reports
}

output {
    metadata {
        path { meta, path -> path >> "${meta.id}/metadata/${path.name}" }
    }
    sequence {
        path { meta, path -> path >> "${meta.id}/sequence/${path.name}" }
    }
    gff3 {
        path { meta, path -> path >> "${meta.id}/gff3/${path.name}" }
    }
    converter_tests {
        path 'converter-tests'
    }
}
