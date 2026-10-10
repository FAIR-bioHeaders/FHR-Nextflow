// SPDX-License-Identifier: MPL-2.0
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

def isSampleId(Object id) {
    return id instanceof CharSequence && id.toString() ==~ /[A-Za-z0-9][A-Za-z0-9_.-]*/
}

def sampleId(Map meta) {
    def id = meta.id
    if (!isSampleId(id))
        throw new IllegalArgumentException('meta.id must contain only letters, digits, dot, underscore or hyphen, starting with a letter or digit')
    return id.toString()
}

def quote(Object value) {
    return "'" + value.toString().replace("'", "'\"'\"'") + "'"
}

def fhrFormat(Object value, List allowed) {
    if (!(value in allowed))
        throw new IllegalArgumentException("Unsupported format '${value}'; expected ${allowed.join(', ')}")
    return value.toString()
}

def metadataJson(Map fields) {
    // Serialization only: the converter owns all schema and format validation.
    // Map entries whose value is null are treated as absent optional fields and
    // omitted. Values without an unambiguous JSON representation are rejected.
    def json = new groovy.json.JsonGenerator.Options()
        .excludeNulls()
        .disableUnicodeEscaping()
        .build()
        .toJson(jsonValue(fields, '$'))
    return groovy.json.JsonOutput.prettyPrint(json, true) + '\n'
}

def jsonValue(Object value, String location) {
    if (value instanceof Map) {
        def copy = new LinkedHashMap()
        value.each { key, item ->
            if (!(key instanceof CharSequence))
                throw new IllegalArgumentException("FHR field ${location} has a non-string key '${key}' (${key?.getClass()?.name}); JSON object keys must be strings")
            if (item != null)
                copy.put(key.toString(), jsonValue(item, "${location}.${key}"))
        }
        return copy
    }
    if (value instanceof Collection || value.getClass().isArray()) {
        def items = value as List
        return items.withIndex().collect { item, index ->
            if (item == null)
                throw new IllegalArgumentException("FHR field ${location}[${index}] is null; JSON arrays passed to FHR must not contain null")
            jsonValue(item, "${location}[${index}]")
        }
    }
    if (value instanceof CharSequence)
        return value.toString()
    if (value instanceof Boolean)
        return value
    if (value instanceof Double || value instanceof Float) {
        if (value.isNaN() || value.isInfinite())
            throw new IllegalArgumentException("FHR field ${location} is ${value}; JSON has no NaN or Infinity")
        return value
    }
    if (value instanceof Integer || value instanceof Long || value instanceof Short || value instanceof Byte
        || value instanceof BigInteger || value instanceof BigDecimal)
        return value
    throw new IllegalArgumentException("FHR field ${location} has unsupported type ${value.getClass().name}; supply strings (for example ISO 8601 'YYYY-MM-DD' dates), numbers, booleans, lists or maps")
}

def directoryDigest(Path directory) {
    // SHA-256 over relative paths and contents of regular files, skipping VCS and
    // Python caches. Used as a task input so -resume notices nested edits.
    def skip = ['.git', '__pycache__', '.pytest_cache'] as Set
    def files = []
    directory.traverse(type: groovy.io.FileType.FILES, preDir: { dir -> dir.name in skip ? groovy.io.FileVisitResult.SKIP_SUBTREE : groovy.io.FileVisitResult.CONTINUE }, filter: { path -> !(path.name in skip) }) { path ->
        files << directory.relativize(path).toString()
    }
    def digest = java.security.MessageDigest.getInstance('SHA-256')
    files.sort().each { name ->
        digest.update((name + '\u0000').getBytes('UTF-8'))
        digest.update(directory.resolve(name).bytes)
        digest.update('\u0000'.getBytes('UTF-8'))
    }
    return digest.digest().encodeHex().toString()
}

def versionCheck() {
    return 'fhr_version="$(fhr-convert --version || true)"; if [ "$fhr_version" != "0.5.0" ]; then echo "FHR-Nextflow requires fhr-convert 0.5.0; found \'${fhr_version:-none}\'" >&2; exit 1; fi'
}

def versionReport() {
    // Escaped so that the shell, not Groovy, sees \n: a literal newline here
    // would defeat Nextflow's script indentation stripping.
    return 'printf "fhr: %s\\n" "$(fhr-convert --version)" > versions.yml'
}

def gff3VersionCheck() {
    return 'gff3_version="$(gff3-validate --version || true)"; if [ "$gff3_version" != "0.1.0" ]; then echo "FHR-Nextflow requires gff3-validate 0.1.0; found \'${gff3_version:-none}\'" >&2; exit 1; fi'
}

def gff3VersionReport() {
    return 'printf "gff3-validator: %s\\n" "$(gff3-validate --version)" > versions.yml'
}

def gff3Options(Object ext, Object genome) {
    // Builds quoted gff3-validate options from task.ext; the validator owns all
    // GFF3 rules. Unset options use the validator defaults; fail_on_errors is
    // handled by the module.
    def args = []
    def header = ext.header == null ? 'auto' : ext.header
    if (!(header in ['auto', 'require', 'skip']))
        throw new IllegalArgumentException("Unsupported GFF3 header mode '${header}'; expected auto, require, skip")
    if (header == 'require')
        args << '--require-header'
    if (header == 'skip')
        args << '--no-header'
    if (genome instanceof Collection && genome.size() > 1)
        throw new IllegalArgumentException("GFF3_VALIDATE accepts at most one genome FASTA; received ${genome.size()} files")
    def hasGenome = !(genome instanceof Collection) || !genome.isEmpty()
    if (hasGenome)
        args << '--genome' << quote(genome)
    if (ext.translation_table != null) {
        if (!hasGenome)
            throw new IllegalArgumentException('ext.translation_table needs a genome FASTA: the codon checks run only with --genome')
        args << '--translation-table' << quote(positiveInteger(ext.translation_table, 'ext.translation_table'))
    }
    if (ext.max_findings != null)
        args << '--max-findings' << quote(positiveInteger(ext.max_findings, 'ext.max_findings'))
    return args.join(' ')
}

def failOnErrors(Object ext) {
    def value = ext.fail_on_errors == null ? true : ext.fail_on_errors
    if (!(value instanceof Boolean))
        throw new IllegalArgumentException("ext.fail_on_errors must be true or false; found '${value}'")
    return value
}

def positiveInteger(Object value, String name) {
    def text = value.toString()
    if (!(value instanceof Number || value instanceof CharSequence) || !(text ==~ /[1-9][0-9]*/))
        throw new IllegalArgumentException("${name} must be a positive integer; found '${value}'")
    return text
}
