// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

include { quote; sampleId; versionCheck; versionReport } from '../utils/main'

process FHR_CONVERTER_TESTS {
    tag "${meta.id}"
    label 'fhr'

    input:
    tuple val(meta), path(converter_source)

    output:
    tuple val(meta), path('converter-tests.xml'), path('converter-tests.log'), emit: reports
    tuple val(meta), path('versions.yml'), emit: versions

    script:
    sampleId(meta)
    """
    ${versionCheck()}
    python -m pytest ${quote(converter_source.resolve('tests'))} --rootdir=${quote(converter_source)} -c ${quote(converter_source.resolve('pytest.ini'))} -p no:cacheprovider --junitxml=converter-tests.xml > converter-tests.log 2>&1
    ${versionReport()}
    """
}
