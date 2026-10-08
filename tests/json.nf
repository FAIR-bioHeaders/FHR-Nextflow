// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Serializer edge cases for modules/utils/main.nf metadataJson().
include { metadataJson } from '../modules/utils/main'

def failure(Closure action) {
    try {
        action.call()
    } catch (Exception e) {
        return (e.cause ?: e).message
    }
    return null
}

workflow {
    def text = 'β α 😀 "quoted" back\\slash\nnew line\ttab \u0001'
    def json = metadataJson([genome: text, optional: null, synonyms: ['b', 'a'] as LinkedHashSet, numbers: [1, 2.5, 10000000000, 1.0], nested: [drop: null, keep: false]])
    def parsed = new groovy.json.JsonSlurper().parseText(json)
    def expected = [genome: text, synonyms: ['b', 'a'], numbers: [1, 2.5, 10000000000, 1.0], nested: [keep: false]]
    if (parsed != expected)
        error("JSON round trip mismatch: ${parsed}")
    if (!json.contains('β α 😀') || json.contains('\\u03b2'))
        error("non-ASCII characters were escaped: ${json}")
    if (json.contains('null') || json.contains('optional') || json.contains('drop'))
        error("null map entries were emitted: ${json}")
    if (!json.endsWith('}\n'))
        error('JSON must end with a newline')
    def rejected = [
        'java.util.Date': [dateCreated: new Date(0)],
        'java.time.LocalDate': [dateCreated: java.time.LocalDate.of(2020, 1, 1)],
        'NaN': [vitalStats: [gcContent: Double.NaN]],
        'Infinity': [vitalStats: [gcContent: Float.POSITIVE_INFINITY]],
        '$.instrument[1] is null': [instrument: ['a', null]],
        'non-string key': [(1): 'a'],
        'java.lang.Object': [x: new Object()],
    ]
    rejected.each { message, fields ->
        def actual = failure { metadataJson(fields) }
        if (actual == null || !actual.contains(message))
            error("expected rejection containing '${message}', got: ${actual}")
    }
    println "JSON serialization: 5 accepted edge cases and ${rejected.size()} rejections passed"
}
