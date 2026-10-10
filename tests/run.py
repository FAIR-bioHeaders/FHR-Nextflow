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
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PLACEHOLDER = 'A' * 43 + '='
parser = argparse.ArgumentParser()
parser.add_argument('--nextflow', default='nextflow')
parser.add_argument('--converter-source', type=Path)
args = parser.parse_args()
env = dict(os.environ, NXF_OFFLINE='true', NXF_SYNTAX_PARSER='v2')
passed = []


class CheckFailed(Exception):
    pass


def check(condition, message):
    """Explicit check that, unlike assert, is not removed by python -O."""
    if not condition:
        raise CheckFailed(message)


def run(script, directory, options=(), failure=None):
    result = subprocess.run([args.nextflow, 'run', str(script), '-ansi-log', 'false', '-c', str(directory / 'nextflow.config'), *options], cwd=directory, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if failure:
        check(result.returncode != 0 and failure in result.stdout, f'expected failure containing {failure!r}:\n{result.stdout}')
    else:
        check(result.returncode == 0, result.stdout)
    name = Path(script).name
    passed.append(name)
    print(f'{name}: expected rejection ({failure})' if failure else f'{name}: passed', flush=True)
    return result.stdout


def published(directory):
    return sorted(str(path.relative_to(directory)) for path in directory.rglob('*') if path.is_file())


def junit_totals(path):
    tests = failures = 0
    for suite in ET.parse(path).getroot().iter('testsuite'):
        tests += int(suite.get('tests', 0))
        failures += int(suite.get('failures', 0)) + int(suite.get('errors', 0))
    return tests, failures


def snapshot(directory):
    return {str(path.relative_to(directory)): path.stat().st_mtime_ns for path in directory.rglob('*') if '.git' not in path.parts}


def main():
    with tempfile.TemporaryDirectory(prefix='fhr-nextflow-tests-') as tmp:
        work = Path(tmp)
        (work / 'nextflow.config').write_text('nextflow.enable.dsl = 2\n')
        fields = json.loads((ROOT / 'examples/metadata.json').read_text())
        fields['documentation'] = "Unicode β; quotes ' and \\" + '"; $(touch SHOULD_NOT_EXIST)'
        fixture = work / "metadata with ' quotes.json"
        fixture.write_text(json.dumps(fields))

        # Native composition: five metadata round trips and two exact-byte sequence round trips.
        integration = work / 'integration.nf'
        integration.write_text((ROOT / 'tests/integration.nf').read_text().replace("from '../", f"from '{ROOT}/"))
        run(integration, work, ['--fixture', str(fixture), '--fixtures', str(ROOT / 'examples')])
        check(len(list((work / 'work').glob('*/*/*.ok'))) == 7, 'expected seven round-trip markers')
        check(not list(work.rglob('SHOULD_NOT_EXIST')), 'shell metacharacters in metadata were executed')
        created = next((work / 'work').glob('*/*/rich.fhr.json')).read_text(encoding='utf-8')
        check('Unicode β' in created and '\\u03b2' not in created, 'non-ASCII metadata was escaped')

        # Serializer edge cases: Unicode, nulls, sets, Date/NaN/Infinity rejection.
        json_test = work / 'json.nf'
        json_test.write_text((ROOT / 'tests/json.nf').read_text().replace("from '../", f"from '{ROOT}/"))
        check('JSON serialization:' in run(json_test, work), 'JSON edge-case script did not report')
        date_field = work / 'date-field.nf'
        date_field.write_text("include { FHR_CREATE_JSON } from '" + str(ROOT / 'modules/create_json/main') + "'\nworkflow { FHR_CREATE_JSON(Channel.of(tuple([id:'date'], [dateCreated: new Date(0)]))) }\n")
        run(date_field, work, failure='unsupported type java.util.Date')

        # Missing required metadata and invalid digest must fail before JSON is emitted.
        for name, change, message in [('missing', lambda f: f.pop('genome'), 'genome'), ('seqcol', lambda f: f.update(seqcol_id='bad'), 'seqcol_id')]:
            invalid = dict(fields)
            change(invalid)
            source = work / f'{name}.json'
            source.write_text(json.dumps(invalid))
            run(ROOT / 'main.nf', work, ['--metadata', str(source), '--outdir', str(work / name)], failure=message)
            check(not (work / name).exists(), f'{name}: outputs were published after a validation failure')
        malformed = work / 'malformed.json'
        malformed.write_text('{broken')
        run(ROOT / 'main.nf', work, ['--metadata', str(malformed)], failure='Cannot parse metadata JSON')
        run(ROOT / 'main.nf', work, ['--id', '../unsafe'], failure='meta.id')
        run(ROOT / 'main.nf', work, ['--id', '123', '--outdir', str(work / 'numeric-id')])
        check((work / 'numeric-id/123/metadata/123.fhr.json').exists(), 'numeric --id was not accepted as a sample ID')
        run(ROOT / 'main.nf', work, ['--metadata', str(fixture)], failure='rename the file or use --id')
        bad_format = work / 'bad-format.nf'
        bad_format.write_text("include { FHR_CONVERT } from '" + str(ROOT / 'modules/convert/main') + "'\nworkflow { FHR_CONVERT(Channel.of(tuple([id:'bad'], file(params.metadata), 'exe'))) }\n")
        run(bad_format, work, ['--metadata', str(fixture)], failure='Unsupported format')
        attached = next((work / 'work').glob('*/*/attached-fasta.fhr.fasta'))
        tampered = work / 'tampered.fasta'
        tampered.write_bytes(attached.read_bytes().replace(b'AAAATCGATCGGCATA', b'TAAATCGATCGGCATA'))
        bad_checksum = work / 'bad-checksum.nf'
        bad_checksum.write_text("include { FHR_VALIDATE } from '" + str(ROOT / 'modules/validate/main') + "'\nworkflow { FHR_VALIDATE(Channel.of(tuple([id:'tampered'], file(params.sequence), 'fasta'))) }\n")
        run(bad_checksum, work, ['--sequence', str(tampered)], failure='checksum')
        # FHR lines must form the leading header block (converter 0.3.1).
        late_header = work / 'late-header.fasta'
        late_header.write_bytes(attached.read_bytes() + b';~documentation: after the sequence\n')
        run(bad_checksum, work, ['--sequence', str(late_header)], failure='after sequence data')
        concatenated = work / 'concatenated.fasta'
        concatenated.write_bytes(attached.read_bytes() * 2)
        run(bad_checksum, work, ['--sequence', str(concatenated)], failure='after sequence data')

        # Several metadata files: one output directory per file-derived ID, never shared.
        batch = work / 'batch'
        for directory, name, genome in [('one', 'alpha.json', 'Alpha'), ('one', 'beta.fhr.json', 'Beta'), ('two', 'alpha.json', 'Alpha again')]:
            (batch / directory).mkdir(parents=True, exist_ok=True)
            (batch / directory / name).write_text(json.dumps(dict(fields, genome=genome)))
        output = work / 'batch-output'
        run(ROOT / 'main.nf', work, ['--metadata', str(batch / 'one/*.json'), '--outdir', str(output)])
        expected = ['alpha/metadata/alpha.fhr.json', 'alpha/metadata/alpha.fhr.yaml', 'beta/metadata/beta.fhr.json', 'beta/metadata/beta.fhr.yaml']
        check(published(output) == expected, f'unexpected batch outputs: {published(output)}')
        for sample, genome in [('alpha', 'Alpha'), ('beta', 'Beta')]:
            check(json.loads((output / sample / 'metadata' / f'{sample}.fhr.json').read_text())['genome'] == genome, f'{sample}: output belongs to another input')
        run(ROOT / 'main.nf', work, ['--metadata', str(batch / '*/alpha.json'), '--outdir', str(work / 'duplicate')], failure='Duplicate meta.id')
        run(ROOT / 'main.nf', work, ['--metadata', str(batch / 'one/*.json'), '--id', 'shared', '--outdir', str(work / 'shared')], failure='--id names a single output')
        check(not (work / 'duplicate').exists() and not (work / 'shared').exists(), 'outputs were published for ambiguous IDs')

        # With a sequence, only the attached file and metadata carrying its computed checksum are published.
        output = work / 'sequence-output'
        run(ROOT / 'main.nf', work, ['--sequence', str(ROOT / 'examples/assembly.gfa'), '--sequence_format', 'gfa', '--outdir', str(output)])
        expected = ['example/sequence/example.fhr.gfa', 'example/sequence/example.fhr.json', 'example/sequence/example.fhr.yaml']
        check(published(output) == expected, f'unexpected sequence outputs: {published(output)}')
        for name in published(output):
            check(PLACEHOLDER.encode() not in (output / name).read_bytes(), f'{name} contains the placeholder checksum')

        # GFF3 validation: optional genome ([]), gzip input, warnings, errors, incomplete input.
        gff3 = ROOT / 'tests/fixtures/gff3'
        module = "include { GFF3_VALIDATE } from '" + str(ROOT / 'modules/gff3_validate/main') + "'\n"
        gff3_module = work / 'gff3-module.nf'
        gff3_module.write_text(module + """workflow {
    def fixtures = params.fixtures
    GFF3_VALIDATE(Channel.of(
        tuple([id: 'plain'], file("${fixtures}/genes-with-genome.gff3"), []),
        tuple([id: 'gz'], file("${fixtures}/canonical-gene-gzip.gff3.gz"), []),
        tuple([id: 'stop'], file("${fixtures}/bio-008-internal-stop.gff3"), file("${fixtures}/genome.fa")),
        tuple([id: 'duplicate'], file("${fixtures}/str-001-duplicate-id.gff3"), [])
    ).filter { meta, gff3, genome -> meta.id in params.ids.tokenize(',') })
    GFF3_VALIDATE.out.valid.map { meta, gff3 -> "VALID ${meta.id} ${gff3.name}" }.view()
    GFF3_VALIDATE.out.reports.map { meta, json, html -> "REPORT ${meta.id} ${json.name} ${html.name}" }.view()
}
""")
        output = run(gff3_module, work, ['--fixtures', str(gff3), '--ids', 'plain,gz,stop'])
        for sample, name in [('plain', 'genes-with-genome.gff3'), ('gz', 'canonical-gene-gzip.gff3.gz'), ('stop', 'bio-008-internal-stop.gff3')]:
            check(f'VALID {sample} {name}' in output, f'{sample}: valid GFF3 not emitted on valid:\n{output}')
            check(f'REPORT {sample} {sample}.gff3-validate.json {sample}.gff3-validate.html' in output, f'{sample}: reports not emitted')
        report = json.loads(next((work / 'work').glob('*/*/stop.gff3-validate.json')).read_text())
        check(report['valid'] and report['tool']['version'] == '0.1.0', f'unexpected genome report: {report}')
        check([f['rule'] for f in report['findings']] == ['BIO-008'], f'expected one BIO-008 warning with the genome: {report["findings"]}')
        check('<html' in next((work / 'work').glob('*/*/stop.gff3-validate.html')).read_text().lower(), 'HTML report missing')
        run(gff3_module, work, ['--fixtures', str(gff3), '--ids', 'duplicate'], failure='GFF3 validation failed for str-001-duplicate-id.gff3')
        check(any('GFF-STR-001' in path.read_text() for path in (work / 'work').glob('*/*/duplicate.gff3-validate.json')), 'failing task did not keep its JSON report')
        bad_genome = work / 'bad-genome.nf'
        bad_genome.write_text(module + "workflow { GFF3_VALIDATE(Channel.of(tuple([id:'stop'], file(params.gff3), file(params.genome)))) }\n")
        run(bad_genome, work, ['--gff3', str(gff3 / 'bio-008-internal-stop.gff3'), '--genome', str(gff3 / 'str-001-duplicate-id.gff3')], failure='validation incomplete')
        bad_id = work / 'gff3-bad-id.nf'
        bad_id.write_text(module + "workflow { GFF3_VALIDATE(Channel.of(tuple([id:'../x'], file(params.gff3), []))) }\n")
        run(bad_id, work, ['--gff3', str(gff3 / 'genes-with-genome.gff3')], failure='meta.id')
        # fail_on_errors = false: invalid files emit reports but are not emitted on valid.
        lenient = work / 'gff3-continue'
        lenient.mkdir()
        (lenient / 'nextflow.config').write_text('nextflow.enable.dsl = 2\nprocess { withName: GFF3_VALIDATE { ext.fail_on_errors = false } }\n')
        output = run(gff3_module, lenient, ['--fixtures', str(gff3), '--ids', 'plain,duplicate'])
        check('VALID plain' in output and 'VALID duplicate' not in output, f'invalid GFF3 emitted on valid:\n{output}')
        check('REPORT duplicate duplicate.gff3-validate.json' in output, 'invalid GFF3 reports not emitted')

        # Example workflow: reports published per GFF3 ID; errors fail unless --gff3_fail_on_errors false.
        output = work / 'gff3-output'
        run(ROOT / 'main.nf', work, ['--gff3', str(gff3 / '*.gff3*'), '--gff3_genome', str(gff3 / 'genome.fa'), '--outdir', str(output), '--gff3_fail_on_errors', 'false'])
        expected = sorted(f'{sample}/gff3/{sample}.gff3-validate.{ext}' for sample in ['bio-008-internal-stop', 'canonical-gene-gzip', 'genes-with-genome', 'str-001-duplicate-id'] for ext in ['html', 'json'])
        check([name for name in published(output) if '/gff3/' in name] == expected, f'unexpected GFF3 outputs: {published(output)}')
        check(not json.loads((output / 'str-001-duplicate-id/gff3/str-001-duplicate-id.gff3-validate.json').read_text())['valid'], 'invalid GFF3 reported as valid')
        run(ROOT / 'main.nf', work, ['--gff3', str(gff3 / 'str-001-duplicate-id.gff3'), '--outdir', str(work / 'gff3-strict')], failure='GFF3 validation failed')
        check(not (work / 'gff3-strict/str-001-duplicate-id').exists(), 'reports published after a failing GFF3 validation')
        run(ROOT / 'main.nf', work, ['--gff3', str(gff3 / 'genes-with-genome.gff3'), '--gff3_genome', str(work / 'missing.fa')], failure='missing.fa')
        run(ROOT / 'main.nf', work, ['--gff3', str(gff3 / 'genes-with-genome.gff3'), '--gff3_translation_table', '11'], failure='needs a genome')
        duplicate_gff3 = work / 'duplicate-gff3'
        duplicate_gff3.mkdir()
        shutil.copy(gff3 / 'genes-with-genome.gff3', duplicate_gff3 / 'sample.gff3')
        shutil.copy(gff3 / 'canonical-gene-gzip.gff3.gz', duplicate_gff3 / 'sample.gff3.gz')
        run(ROOT / 'main.nf', work, ['--gff3', str(duplicate_gff3 / '*'), '--outdir', str(work / 'gff3-duplicate')], failure='Duplicate meta.id from GFF3 files')

        if args.converter_source:
            source = args.converter_source.resolve()
            before = snapshot(source)
            output = work / 'converter-output'
            run(ROOT / 'main.nf', work, ['--converter_source', str(source), '--outdir', str(output)])
            total, failures = junit_totals(output / 'converter-tests/converter-tests.xml')
            check(total > 0 and failures == 0, f'converter JUnit report: {total} tests, {failures} failures')
            check((output / 'example/metadata/example.fhr.json').exists(), 'results were not published after passing tests')
            check(snapshot(source) == before, 'converter tests modified the supplied checkout')
            print(f'Converter wrapper: {total} tests passed.', flush=True)

            # A failing test publishes reports, withholds results and fails the run, also
            # when -resume follows an edit to a nested test file.
            mutable = work / 'converter-copy'
            shutil.copytree(source, mutable, ignore=shutil.ignore_patterns('.git'))
            run(ROOT / 'main.nf', work, ['--converter_source', str(mutable), '--outdir', str(work / 'copy-output')])
            with (mutable / 'tests/fhr_test.py').open('a') as tests:
                tests.write('\n\ndef test_injected_failure():\n    assert False\n')
            output = work / 'failing-output'
            run(ROOT / 'main.nf', work, ['-resume', '--converter_source', str(mutable), '--outdir', str(output)], failure='Converter tests failed')
            check(published(output) == ['converter-tests/converter-tests.log', 'converter-tests/converter-tests.xml'], f'unexpected outputs after failing tests: {published(output)}')
            total, failures = junit_totals(output / 'converter-tests/converter-tests.xml')
            check(failures == 1, f'expected one failing converter test, found {failures}')
            check('test_injected_failure' in (output / 'converter-tests/converter-tests.log').read_text(), 'failure missing from published log')

            pyproject = mutable / 'pyproject.toml'
            pyproject.write_text(pyproject.read_text().replace('version = "0.5.0"', 'version = "0.6.0"', 1))
            run(ROOT / 'main.nf', work, ['--converter_source', str(mutable), '--outdir', str(work / 'mismatch')], failure="converter source version is '0.6.0'")
            check(not (work / 'mismatch' / 'example').exists(), 'results published with a mismatched converter checkout')
    print(f'PASS: {len(passed)} pipeline runs and rejection cases (round trips, exact bytes, JSON edge cases, per-file IDs, publication gates, GFF3 validation).')


if __name__ == '__main__':
    try:
        main()
    except CheckFailed as error:
        sys.exit(f'FAIL: {error}')
