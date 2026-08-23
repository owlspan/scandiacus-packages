// ini - config files, the .ini and .conf shape.
//
//     import "ini"
//
//     let cfg = must(iniParse(must(os.file.read("app.ini"))))
//     print(iniGet(cfg, "server", "port", "8080"))
//
// Sections in [brackets], `key = value` under them, `#` or `;` for a
// comment. Keys before any section land in the section named "", which
// is what a file with no sections at all parses as.
//
// Every name is prefixed because an import lands in one flat namespace.
//
// What it accepts, deliberately: values are taken whole after the first
// `=`, trimmed, with surrounding quotes removed if both are there. A
// value containing `=` or `#` is fine as long as it is quoted. Repeated
// keys keep the last one, which is what every ini reader does.

// A parsed file: section name -> key -> value.
//
// A map of maps rather than a struct, so a program can walk sections it
// did not know about.

pub fn iniParse(text: str) -> {str: {str: str}}! {
    let out: {str: {str: str}} = {}
    let section = ""
    out[section] = {}

    let all = lines(text)
    let n = 0
    while n < len(all) {
        let raw = trim(all[n])
        n = n + 1

        if raw == "" { continue }
        if startsWith(raw, "#") || startsWith(raw, ";") { continue }

        if startsWith(raw, "[") {
            if !endsWith(raw, "]") {
                return fail("line {n}: section \"{raw}\" has no closing bracket")
            }
            section = trim(substr(raw, 1, len(raw) - 1))
            if section == "" {
                return fail("line {n}: a section needs a name")
            }
            if !has(out, section) { out[section] = {} }
            continue
        }

        let eq = indexOf(raw, "=")
        if eq < 0 {
            return fail("line {n}: \"{raw}\" is neither a section nor key = value")
        }
        let key = trim(substr(raw, 0, eq))
        if key == "" {
            return fail("line {n}: a value with no key")
        }
        let value = iniUnquote(trim(substr(raw, eq + 1, len(raw))))

        // Read back, changed, written back: a map value is a copy here,
        // so updating it in place would update the copy.
        let entries = out[section]
        entries[key] = value
        out[section] = entries
    }
    return out
}

// Strip one matching pair of surrounding quotes, so `path = "C:\x"`
// keeps the spaces and loses the quotes.
fn iniUnquote(s: str) -> str {
    if len(s) < 2 { return s }
    let first = charAt(s, 0)
    let last = charAt(s, len(s) - 1)
    if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
        return substr(s, 1, len(s) - 1)
    }
    return s
}

// A value, or the fallback when the section or key is missing.
pub fn iniGet(cfg: {str: {str: str}}, section: str, key: str, fallback: str) -> str {
    if !has(cfg, section) { return fallback }
    let entries = cfg[section]
    if !has(entries, key) { return fallback }
    return entries[key]
}

pub fn iniHas(cfg: {str: {str: str}}, section: str, key: str) -> bool {
    if !has(cfg, section) { return false }
    return has(cfg[section], key)
}

// An int value, failing rather than guessing when it is not one. A port
// that silently reads as zero is worse than a config file that will not
// load.
pub fn iniInt(cfg: {str: {str: str}}, section: str, key: str, fallback: int) -> int! {
    if !iniHas(cfg, section, key) { return fallback }
    let raw = iniGet(cfg, section, key, "")
    if !isInt(raw) {
        return fail("[{section}] {key} = \"{raw}\" is not a number")
    }
    return toInt(raw)
}

// true, yes, on and 1 are true; false, no, off and 0 are false.
pub fn iniBool(cfg: {str: {str: str}}, section: str, key: str, fallback: bool) -> bool! {
    if !iniHas(cfg, section, key) { return fallback }
    let raw = lower(iniGet(cfg, section, key, ""))
    if raw == "true" || raw == "yes" || raw == "on" || raw == "1" {
        return true
    }
    if raw == "false" || raw == "no" || raw == "off" || raw == "0" {
        return false
    }
    return fail("[{section}] {key} = \"{raw}\" is not true or false")
}

pub fn iniSections(cfg: {str: {str: str}}) -> []str {
    return keys(cfg)
}

pub fn iniKeys(cfg: {str: {str: str}}, section: str) -> []str {
    if !has(cfg, section) { return [] }
    return keys(cfg[section])
}

// Put the quotes back on a value that needs them.
//
// Without this the round trip is not stable: a value with surrounding
// spaces writes out bare, and reading it back trims them off. The
// parser also trims, so anything whose trimmed form differs has to be
// quoted or it changes every time the file is rewritten.
fn iniQuote(v: str) -> str {
    if v == "" { return "\"\"" }
    if trim(v) != v { return "\"{v}\"" }
    // A value that already starts with a quote would read back as a
    // quoted value and lose a character at each end.
    let first = charAt(v, 0)
    if first == "\"" || first == "'" { return "\"{v}\"" }
    return v
}

// Back to text. Sections and keys come out sorted, so writing a file
// back produces the same bytes every time rather than whatever order
// the map happened to be in.
pub fn iniWrite(cfg: {str: {str: str}}) -> str {
    let out = ""

    // The unnamed section first and without a header, or reading it
    // back would put those keys under a section called "".
    if has(cfg, "") {
        let bare = cfg[""]
        for k in sort(keys(bare)) {
            out = out + "{k} = {iniQuote(bare[k])}\n"
        }
        if len(keys(bare)) > 0 { out = out + "\n" }
    }

    for name in sort(keys(cfg)) {
        if name == "" { continue }
        out = out + "[{name}]\n"
        let entries = cfg[name]
        for k in sort(keys(entries)) {
            out = out + "{k} = {iniQuote(entries[k])}\n"
        }
        out = out + "\n"
    }
    return trim(out) + "\n"
}

pub fn iniRead(path: str) -> {str: {str: str}}! {
    return iniParse(os.file.read(path)?)
}

pub fn iniSave(path: str, cfg: {str: {str: str}}) -> void! {
    return os.file.write(path, iniWrite(cfg))
}
