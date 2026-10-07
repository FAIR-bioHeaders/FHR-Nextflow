#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

"""Exercise DSL2 modules in an external project, with no testing framework dependency."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--nextflow', default='nextflow')
parser.add_argument('--converter-source', type=Path)
args = parser.parse_args()
env = dict(os.environ, NXF_OFFLINE='true', NXF_SYNTAX_PARSER='v2')

def run(script, directory, options=(), failure=None):
    result = subprocess.run([args.nextflow, 'run', str(script), '-ansi-log', 'false', '-c', str(directory / 'nextflow.config'), *options], cwd=directory, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if failure:
        assert result.returncode != 0 and failure in result.stdout, result.stdout
    else:
        assert result.returncode == 0, result.stdout
    print(f'{Path(script).name}: expected rejection ({failure})' if failure else f'{Path(script).name}: passed', flush=True)

with tempfile.TemporaryDirectory(prefix='fhr-nextflow-tests-') as tmp:
    work = Path(tmp)
    (work / 'nextflow.config').write_text('nextflow.enable.dsl = 2\n')
    fields = json.loads((ROOT / 'examples/metadata.json').read_text())
    fields['documentation'] = "Unicode β; quotes ' and \\" + '"; $(touch SHOULD_NOT_EXIST)'
    fixture = work / "metadata with ' quotes.json"
    fixture.write_text(json.dumps(fields))
    integration = work / 'integration.nf'
    integration.write_text((ROOT / 'tests/integration.nf').read_text().replace("from '../", f"from '{ROOT}/"))
    run(integration, work, ['--fixture', str(fixture), '--fixtures', str(ROOT / 'examples')])
    assert len(list((work / 'work').glob('*/*/*.ok'))) == 7
    assert not list(work.rglob('SHOULD_NOT_EXIST'))
    # Missing required metadata and invalid digest must fail before JSON is emitted.
    for name, change, message in [('missing', lambda f: f.pop('genome'), 'genome'), ('seqcol', lambda f: f.update(seqcol_id='bad'), 'seqcol_id')]:
        invalid = dict(fields)
        change(invalid)
        source = work / f'{name}.json'
        source.write_text(json.dumps(invalid))
        run(ROOT / 'main.nf', work, ['--metadata', str(source), '--outdir', str(work / name)], failure=message)
        assert not (work / name).exists()
    malformed = work / 'malformed.json'
    malformed.write_text('{broken')
    run(ROOT / 'main.nf', work, ['--metadata', str(malformed)], failure='ERROR')
    run(ROOT / 'main.nf', work, ['--id', '../unsafe'], failure='meta.id')
    bad_format = work / 'bad-format.nf'
    bad_format.write_text("include { FHR_CONVERT } from '" + str(ROOT / 'modules/convert/main') + "'\nworkflow { FHR_CONVERT(Channel.of(tuple([id:'bad'], file(params.metadata), 'exe'))) }\n")
    run(bad_format, work, ['--metadata', str(fixture)], failure='Unsupported format')
    attached = next((work / 'work').glob('*/*/attached-fasta.fhr.fasta'))
    tampered = work / 'tampered.fasta'
    tampered.write_bytes(attached.read_bytes().replace(b'AAAATCGATCGGCATA', b'TAAATCGATCGGCATA'))
    bad_checksum = work / 'bad-checksum.nf'
    bad_checksum.write_text("include { FHR_VALIDATE } from '" + str(ROOT / 'modules/validate/main') + "'\nworkflow { FHR_VALIDATE(Channel.of(tuple([id:'tampered'], file(params.sequence), 'fasta'))) }\n")
    run(bad_checksum, work, ['--sequence', str(tampered)], failure='checksum')
    if args.converter_source:
        output = work / 'converter-output'
        run(ROOT / 'main.nf', work, ['--converter_source', str(args.converter_source.resolve()), '--outdir', str(output)])
        report = ET.parse(output / 'converter-tests/converter-tests.xml')
        suites = report.getroot().iter('testsuite')
        total = 0
        for suite in suites:
            assert int(suite.get('failures', 0)) == int(suite.get('errors', 0)) == 0
            total += int(suite.get('tests', 0))
        assert total > 0
        print(f'Converter wrapper: {total} tests passed.')
print('PASS: five metadata round trips, two exact-byte sequence round trips, external imports, quoting, and six rejection cases.')
