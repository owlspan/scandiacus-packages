// toml - TOML configuration files.
//
//     import "toml"
//
//     let cfg = must(tomlParse(text))
//     print(tomlGet(cfg, "server.host", "localhost"))
//     print(must(tomlInt(cfg, "server.port", 8080)))
//     print(must(tomlList(cfg, "server.tags")))
//
// Keys are flattened to dotted paths, so `[server]` with `port = 8080`
// under it is read as `server.port`. That keeps the whole file one map
// rather than needing a value type Scandiacus has no way to express without
// unions.
//
// Values are stored as their raw TOML text and converted on the way
// out, which is why the typed readers can fail: asking for an int and
// getting `"eight"` is an error rather than a zero.
//
// What is supported:
//
//   # comment
//   bare = "basic string"        with \n \t \r \\ \" escapes
//   literal = 'no escapes here'
//   number = 42                  underscores allowed: 1_000_000
//   hex = 0xff                   also 0o755 and 0b1010
//   float = 3.14                 and 1e9, -2.5e-3, inf, nan
//   yes = true
//   list = [1, 2, 3]             nested arrays too
//   [table]
//   [table.nested]
//   dotted.key = 1
//
// What is not, and is a clear error rather than a wrong answer:
// dates and times, inline tables `{a = 1}`, arrays of tables `[[x]]`,
// and multi-line strings. Those are the parts of TOML that need a real
// value type to represent, and this returns strings.
//
// Every name is prefixed because an import lands in one flat namespace.

pub fn tomlParse(text: str) -> {str: str}! {
    let out: {str: str} = {}
    let prefix = ""

    let all = lines(text)
    let n = 0
    while n < len(all) {
        let raw = trim(all[n])
        n = n + 1

        if raw == "" { continue }
        if startsWith(raw, "#") { continue }

        if startsWith(raw, "[") {
            if startsWith(raw, "[[") {
                return fail("line {n}: arrays of tables are not supported")
            }
            if !endsWith(raw, "]") {
                return fail("line {n}: table header \"{raw}\" has no closing bracket")
            }
            let name = trim(substr(raw, 1, len(raw) - 1))
            if name == "" {
                return fail("line {n}: a table needs a name")
            }
            prefix = name + "."
            continue
        }

        let eq = tomlSplitAt(raw)
        if eq < 0 {
            return fail("line {n}: \"{raw}\" is neither a table header nor key = value")
        }
        let key = trim(substr(raw, 0, eq))
        let value = trim(substr(raw, eq + 1, len(raw)))

        key = tomlUnquoteKey(key)
        if key == "" {
            return fail("line {n}: a value with no key")
        }
        if value == "" {
            return fail("line {n}: \"{key}\" has no value")
        }
        if startsWith(value, `{`) {
            return fail("line {n}: inline tables are not supported")
        }
        if startsWith(value, "\"\"\"") || startsWith(value, "'''") {
            return fail("line {n}: multi-line strings are not supported")
        }

        out[prefix + key] = tomlNormalise(value)
    }
    return out
}

// The first = that is not inside a string. `a = "x = y"` splits at the
// first one, not the second.
fn tomlSplitAt(line: str) -> int {
    let i = 0
    let inBasic = false
    let inLiteral = false
    while i < len(line) {
        let c = charAt(line, i)
        if c == "\\" && inBasic {
            i = i + 2
            continue
        }
        if c == "\"" && !inLiteral { inBasic = !inBasic }
        if c == "'" && !inBasic { inLiteral = !inLiteral }
        if c == "=" && !inBasic && !inLiteral { return i }
        i = i + 1
    }
    return -1
}

// A key may be quoted: "my key" = 1
fn tomlUnquoteKey(key: str) -> str {
    if len(key) < 2 { return key }
    let first = charAt(key, 0)
    let last = charAt(key, len(key) - 1)
    if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
        return substr(key, 1, len(key) - 1)
    }
    return key
}

// Strip a trailing comment from an unquoted value, and unquote a quoted
// one. The stored form is what the typed readers below expect.
fn tomlNormalise(value: str) -> str {
    if startsWith(value, "\"") {
        let end = tomlStringEnd(value, "\"")
        if end > 0 {
            return tomlUnescape(substr(value, 1, end))
        }
        return value
    }
    if startsWith(value, "'") {
        let end = tomlStringEnd(value, "'")
        if end > 0 {
            // Literal strings have no escapes at all, which is what
            // makes them right for a Windows path or a regex.
            return substr(value, 1, end)
        }
        return value
    }
    if startsWith(value, "[") {
        // Arrays keep their brackets; tomlList splits them.
        return tomlStripComment(value, true)
    }
    return trim(tomlStripComment(value, false))
}

// Where the closing quote is, skipping an escaped one.
fn tomlStringEnd(value: str, quote: str) -> int {
    let i = 1
    while i < len(value) {
        let c = charAt(value, i)
        if c == "\\" && quote == "\"" {
            i = i + 2
            continue
        }
        if c == quote { return i }
        i = i + 1
    }
    return -1
}

// A # outside a string starts a comment.
fn tomlStripComment(value: str, insideBrackets: bool) -> str {
    let i = 0
    let inBasic = false
    let inLiteral = false
    let depth = 0
    while i < len(value) {
        let c = charAt(value, i)
        if c == "\\" && inBasic {
            i = i + 2
            continue
        }
        if c == "\"" && !inLiteral { inBasic = !inBasic }
        if c == "'" && !inBasic { inLiteral = !inLiteral }
        if !inBasic && !inLiteral {
            if c == "[" { depth = depth + 1 }
            if c == "]" { depth = depth - 1 }
            if c == "#" && (!insideBrackets || depth <= 0) {
                return trim(substr(value, 0, i))
            }
        }
        i = i + 1
    }
    return trim(value)
}

fn tomlUnescape(s: str) -> str {
    let out = ""
    let i = 0
    while i < len(s) {
        let c = charAt(s, i)
        if c == "\\" && i + 1 < len(s) {
            let next = charAt(s, i + 1)
            if next == "n" { out = out + "\n" }
            if next == "t" { out = out + "\t" }
            if next == "r" { out = out + "\r" }
            if next == "\\" { out = out + "\\" }
            if next == "\"" { out = out + "\"" }
            let known = next == "n" || next == "t" || next == "r"
            known = known || next == "\\" || next == "\""
            if !known { out = out + c + next }
            i = i + 2
        } else {
            out = out + c
            i = i + 1
        }
    }
    return out
}

// ---- reading ----

pub fn tomlHas(cfg: {str: str}, key: str) -> bool {
    return has(cfg, key)
}

pub fn tomlKeys(cfg: {str: str}) -> []str {
    return sort(keys(cfg))
}

pub fn tomlGet(cfg: {str: str}, key: str, fallback: str) -> str {
    if !has(cfg, key) { return fallback }
    return cfg[key]
}

pub fn tomlInt(cfg: {str: str}, key: str, fallback: int) -> int! {
    if !has(cfg, key) { return fallback }
    return tomlToInt(cfg[key], key)
}

fn tomlToInt(raw: str, key: str) -> int! {
    let s = replace(raw, "_", "")
    let negative = false
    if startsWith(s, "-") {
        negative = true
        s = substr(s, 1, len(s))
    }
    if startsWith(s, "+") { s = substr(s, 1, len(s)) }

    let n = 0
    if startsWith(s, "0x") || startsWith(s, "0X") {
        n = must(bits.fromBase(substr(s, 2, len(s)), 16))
    } else {
        if startsWith(s, "0o") || startsWith(s, "0O") {
            n = must(bits.fromBase(substr(s, 2, len(s)), 8))
        } else {
            if startsWith(s, "0b") || startsWith(s, "0B") {
                n = must(bits.fromBase(substr(s, 2, len(s)), 2))
            } else {
                if !isInt(s) {
                    return fail("{key} = \"{raw}\" is not a whole number")
                }
                n = toInt(s)
            }
        }
    }
    if negative { return 0 - n }
    return n
}

pub fn tomlFloat(cfg: {str: str}, key: str, fallback: float) -> float! {
    if !has(cfg, key) { return fallback }
    let raw = replace(cfg[key], "_", "")
    if raw == "inf" || raw == "+inf" { return fallback }
    if raw == "nan" { return fallback }
    // float() accepts what Scandiacus's own literals accept, which covers
    // TOML's exponents and signs.
    if !tomlLooksNumeric(raw) {
        return fail("{key} = \"{cfg[key]}\" is not a number")
    }
    return float(toInt(tomlIntPart(raw))) + tomlFracPart(raw)
}

fn tomlLooksNumeric(s: str) -> bool {
    if s == "" { return false }
    let i = 0
    let digits = 0
    while i < len(s) {
        let c = __strAt(s, i)
        let isDigit = c >= 48 && c <= 57
        if isDigit { digits = digits + 1 }
        let ok = isDigit || c == 46 || c == 45 || c == 43 || c == 101 || c == 69
        if !ok { return false }
        i = i + 1
    }
    return digits > 0
}

fn tomlIntPart(s: str) -> str {
    let dot = indexOf(s, ".")
    if dot < 0 { return s }
    return substr(s, 0, dot)
}

fn tomlFracPart(s: str) -> float {
    let dot = indexOf(s, ".")
    if dot < 0 { return 0.0 }
    let frac = substr(s, dot + 1, len(s))
    if !isInt(frac) { return 0.0 }
    let scale = 1.0
    let i = 0
    while i < len(frac) {
        scale = scale * 10.0
        i = i + 1
    }
    let v = float(toInt(frac)) / scale
    if startsWith(s, "-") { return 0.0 - v }
    return v
}

pub fn tomlBool(cfg: {str: str}, key: str, fallback: bool) -> bool! {
    if !has(cfg, key) { return fallback }
    let raw = cfg[key]
    if raw == "true" { return true }
    if raw == "false" { return false }
    return fail("{key} = \"{raw}\" is not true or false")
}

// An array, as the raw text of each element.
//
// Nested arrays come back as their own bracketed text, which tomlList
// can be called on again.
pub fn tomlList(cfg: {str: str}, key: str) -> []str! {
    let empty: []str = []
    if !has(cfg, key) { return empty }
    return tomlSplitArray(cfg[key], key)
}

fn tomlSplitArray(raw: str, key: str) -> []str! {
    let s = trim(raw)
    if !startsWith(s, "[") || !endsWith(s, "]") {
        return fail("{key} = \"{raw}\" is not an array")
    }
    let body = trim(substr(s, 1, len(s) - 1))
    let out: []str = []
    if body == "" { return out }

    let depth = 0
    let inBasic = false
    let inLiteral = false
    let start = 0
    let i = 0
    while i < len(body) {
        let c = charAt(body, i)
        if c == "\\" && inBasic {
            i = i + 2
            continue
        }
        if c == "\"" && !inLiteral { inBasic = !inBasic }
        if c == "'" && !inBasic { inLiteral = !inLiteral }
        if !inBasic && !inLiteral {
            if c == "[" { depth = depth + 1 }
            if c == "]" { depth = depth - 1 }
            if c == "," && depth == 0 {
                push(out, tomlNormalise(trim(substr(body, start, i))))
                start = i + 1
            }
        }
        i = i + 1
    }
    let last = trim(substr(body, start, len(body)))
    if last != "" {
        push(out, tomlNormalise(last))
    }
    return out
}

// Every key under a table, without the prefix.
//
//     [server]
//     host = "x"
//     port = 1
//
//     tomlTable(cfg, "server")  ->  ["host", "port"]
pub fn tomlTable(cfg: {str: str}, table: str) -> []str {
    let prefix = table + "."
    let out: []str = []
    for k in sort(keys(cfg)) {
        if startsWith(k, prefix) {
            let rest = substr(k, len(prefix), len(k))
            if !contains(rest, ".") {
                push(out, rest)
            }
        }
    }
    return out
}

pub fn tomlRead(path: str) -> {str: str}! {
    return tomlParse(os.file.read(path)?)
}
