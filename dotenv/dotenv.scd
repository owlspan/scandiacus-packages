// dotenv - .env configuration files.
//
//     import "dotenv"
//
//     let env = must(dotenvLoad(".env"))
//     print(dotenvGet(env, "DATABASE_URL", "sqlite://local.db"))
//
// The format everyone uses and nobody specified: KEY=value, one per
// line, # for a comment. What is accepted here:
//
//   KEY=value            plain, trimmed
//   KEY = value          spaces around = are ignored
//   KEY="two words"      quotes removed, spaces kept
//   KEY='literal'        single quotes, no escapes processed
//   KEY="line\nbreak"    \n \t \r \\ and \" inside double quotes only
//   export KEY=value     the export prefix is ignored
//   KEY=                 an empty value
//   # comment            skipped, as is a blank line
//
// A `#` inside a quoted value is part of the value. Outside one it
// starts a comment, which is what a password ending in # runs into and
// why quoting it matters.
//
// Every name is prefixed because an import lands in one flat namespace.

pub fn dotenvParse(text: str) -> {str: str}! {
    let out: {str: str} = {}

    let all = lines(text)
    let n = 0
    while n < len(all) {
        let raw = trim(all[n])
        n = n + 1

        if raw == "" { continue }
        if startsWith(raw, "#") { continue }

        // `export KEY=value` is a .env file that is also a shell script.
        if startsWith(raw, "export ") {
            raw = trim(substr(raw, 7, len(raw)))
        }

        let eq = indexOf(raw, "=")
        if eq < 0 {
            return fail("line {n}: \"{raw}\" has no =")
        }

        let key = trim(substr(raw, 0, eq))
        if key == "" {
            return fail("line {n}: a value with no name")
        }
        if !dotenvValidName(key) {
            return fail("line {n}: \"{key}\" is not a valid name")
        }

        out[key] = dotenvValue(trim(substr(raw, eq + 1, len(raw))))
    }
    return out
}

// Letters, digits and underscore, not starting with a digit. Anything
// else is almost always a malformed line rather than a real name.
fn dotenvValidName(name: str) -> bool {
    let first = __strAt(name, 0)
    let ok = (first >= 65 && first <= 90) || (first >= 97 && first <= 122)
    if !ok && first != 95 { return false }

    let i = 0
    while i < len(name) {
        let c = __strAt(name, i)
        let good = (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
        good = good || (c >= 48 && c <= 57) || c == 95
        if !good { return false }
        i = i + 1
    }
    return true
}

// Unquote, and strip a trailing comment from a bare value.
fn dotenvValue(raw: str) -> str {
    if len(raw) >= 2 {
        let first = charAt(raw, 0)
        let last = charAt(raw, len(raw) - 1)
        if first == "\"" && last == "\"" {
            return dotenvUnescape(substr(raw, 1, len(raw) - 1))
        }
        // Single quotes are literal: no escape processing, which is what
        // makes them the right place to put a Windows path.
        if first == "'" && last == "'" {
            return substr(raw, 1, len(raw) - 1)
        }
    }

    // Unquoted, so a # starts a comment.
    let hash = indexOf(raw, "#")
    if hash >= 0 {
        return trim(substr(raw, 0, hash))
    }
    return raw
}

fn dotenvUnescape(s: str) -> str {
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
            // An unknown escape keeps both characters rather than
            // eating the backslash, so \d stays \d.
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

pub fn dotenvLoad(path: str) -> {str: str}! {
    return dotenvParse(os.file.read(path)?)
}

// Load if it is there, and an empty map if it is not.
//
// Most programs want this: a .env is for local development and is
// absent in production, where the real environment is set properly.
pub fn dotenvLoadOr(path: str) -> {str: str}! {
    if !os.file.exists(path) {
        let empty: {str: str} = {}
        return empty
    }
    return dotenvLoad(path)
}

pub fn dotenvGet(env: {str: str}, key: str, fallback: str) -> str {
    if !has(env, key) { return fallback }
    return env[key]
}

pub fn dotenvInt(env: {str: str}, key: str, fallback: int) -> int! {
    if !has(env, key) { return fallback }
    let raw = env[key]
    if !isInt(raw) {
        return fail("{key}=\"{raw}\" is not a number")
    }
    return toInt(raw)
}

pub fn dotenvBool(env: {str: str}, key: str, fallback: bool) -> bool! {
    if !has(env, key) { return fallback }
    let raw = lower(env[key])
    if raw == "true" || raw == "yes" || raw == "on" || raw == "1" { return true }
    if raw == "false" || raw == "no" || raw == "off" || raw == "0" { return false }
    return fail("{key}=\"{raw}\" is not true or false")
}

// Fail if something is missing, naming everything that is rather than
// the first one. A program that needs four settings should say so once,
// not four runs in a row.
pub fn dotenvRequire(env: {str: str}, names: []str) -> void! {
    let missing: []str = []
    for name in names {
        if !has(env, name) || env[name] == "" {
            push(missing, name)
        }
    }
    if len(missing) > 0 {
        return fail("missing required settings: {join(missing, ", ")}")
    }
}

// Copy into the real process environment, so anything reading
// os.env.get sees them too.
//
// Existing variables win: a .env is a default for local development,
// and something set in the shell was set deliberately.
pub fn dotenvApply(env: {str: str}) -> void! {
    for key in keys(env) {
        if !os.env.has(key) {
            os.env.set(key, env[key])?
        }
    }
}
