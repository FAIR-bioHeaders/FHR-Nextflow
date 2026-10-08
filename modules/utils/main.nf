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
    return 'fhr_version="$(fhr-convert --version || true)"; if [ "$fhr_version" != "0.3.3" ]; then echo "FHR-Nextflow requires fhr-convert 0.3.3; found \'${fhr_version:-none}\'" >&2; exit 1; fi'
}

def versionReport() {
    // Escaped so that the shell, not Groovy, sees \n: a literal newline here
    // would defeat Nextflow's script indentation stripping.
    return 'printf "fhr: %s\\n" "$(fhr-convert --version)" > versions.yml'
}
