// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

include { failOnErrors; gff3Options; gff3VersionCheck; gff3VersionReport; quote; sampleId } from '../utils/main'

// Validates a GFF3 file (plain, gzip or BGZF) with the pinned gff3-validate
// 0.1.0 and writes JSON and HTML reports. Pass [] as the genome when there is
// none; a genome FASTA enables the BIO-* sequence checks. Options come from
// task.ext: header ('auto', 'require' or 'skip'), translation_table (needs a
// genome), max_findings and fail_on_errors (default true).
//
// Exit status 1 (errors found) fails the task unless ext.fail_on_errors is
// false; the reports are then emitted and the file is omitted from `valid`.
// Exit status 2 (unreadable input or genome, incomplete validation) always
// fails the task.
process GFF3_VALIDATE {
    tag "${meta.id}"
    label 'fhr'

    input:
    tuple val(meta), path(gff3, stageAs: 'input/*'), path(genome, stageAs: 'genome/*')

    output:
    tuple val(meta), path("${meta.id}.gff3-validate.json"), path("${meta.id}.gff3-validate.html"), emit: reports
    // A file with no errors is linked into valid/ by the script; only those
    // links are emitted, so an invalid file never reaches `valid`.
    tuple val(meta), path("valid/*"), emit: valid, optional: true
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    def id = sampleId(meta)
    def options = gff3Options(task.ext, genome)
    def failOnError = failOnErrors(task.ext)
    def input = quote(gff3)
    def json = quote("${id}.gff3-validate.json")
    def html = quote("${id}.gff3-validate.html")
    def name = quote(gff3.toString().tokenize('/').last())
    """
    ${gff3VersionCheck()}
    set +e
    gff3-validate --format json ${options} ${input} > ${json}
    status=\$?
    set -e
    if [ "\$status" -ne 0 ] && [ "\$status" -ne 1 ]; then
        printf 'GFF3 validation of %s is incomplete (gff3-validate exit status %s): the GFF3 or genome input is unreadable or an option is invalid; see the message above\\n' ${name} "\$status" >&2
        exit 2
    fi
    gff3-validate --format html ${options} ${input} > ${html} || [ "\$?" -eq 1 ]
    if [ "\$status" -eq 1 ]; then
        if ${failOnError}; then
            gff3-validate --format text --max-findings 20 ${options} ${input} >&2 || true
            printf 'GFF3 validation failed for %s: the file has errors (reports: %s, %s). Set ext.fail_on_errors = false to emit the reports and continue.\\n' ${name} ${json} ${html} >&2
            exit 1
        fi
        # Continue: emit the reports but do not link the file into valid/.
    else
        mkdir -p valid
        ln -s ../${input} valid/
    fi
    ${gff3VersionReport()}
    """
}
