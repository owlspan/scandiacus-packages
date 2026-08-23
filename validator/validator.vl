// validator - checking data before you trust it.
//
//     import "validator"
//
//     let v = vNew()
//     vRequired(v, "name", name)
//     vEmail(v, "email", email)
//     vRange(v, "age", age, 13, 120)
//
//     if !vOK(v) {
//         print(vReport(v))
//         return
//     }
//
// It collects every problem rather than stopping at the first. A form
// that tells you about one mistake at a time is the reason people give
// up on forms, and the same is true of a config file or a CSV row.
//
// Each check takes a field name so the message can say which one. A
// check on an empty value passes unless it is vRequired: "optional, but
// must be an email if given" is the common case, and requiring it is a
// separate decision.
//
// Every name is prefixed because an import lands in one flat namespace.

struct Validator {
    problems: []str
    fields: []str
}

pub fn vNew() -> Validator {
    let v = Validator{}
    return v
}

fn vAdd(v: Validator, field: str, problem: str) {
    push(v.problems, "{field} {problem}")
    push(v.fields, field)
}

// ---- presence ----

pub fn vRequired(v: Validator, field: str, value: str) {
    if trim(value) == "" {
        vAdd(v, field, "is required")
    }
}

// ---- length ----

pub fn vMinLength(v: Validator, field: str, value: str, n: int) {
    if value == "" { return }
    if len(value) < n {
        vAdd(v, field, "must be at least {n} characters")
    }
}

pub fn vMaxLength(v: Validator, field: str, value: str, n: int) {
    if len(value) > n {
        vAdd(v, field, "must be at most {n} characters")
    }
}

pub fn vLength(v: Validator, field: str, value: str, lo: int, hi: int) {
    vMinLength(v, field, value, lo)
    vMaxLength(v, field, value, hi)
}

// ---- numbers ----

pub fn vInt(v: Validator, field: str, value: str) {
    if value == "" { return }
    if !isInt(value) {
        vAdd(v, field, "must be a whole number")
    }
}

pub fn vRange(v: Validator, field: str, value: int, lo: int, hi: int) {
    if value < lo || value > hi {
        vAdd(v, field, "must be between {lo} and {hi}")
    }
}

pub fn vMin(v: Validator, field: str, value: int, lo: int) {
    if value < lo {
        vAdd(v, field, "must be at least {lo}")
    }
}

pub fn vMax(v: Validator, field: str, value: int, hi: int) {
    if value > hi {
        vAdd(v, field, "must be at most {hi}")
    }
}

// ---- shapes ----

// Deliberately not RFC 5322. That grammar allows things no real system
// accepts, and the only way to know an address works is to send to it.
// This rejects what is obviously wrong and nothing else.
pub fn vEmail(v: Validator, field: str, value: str) {
    if value == "" { return }
    if !vIsEmail(value) {
        vAdd(v, field, "is not a valid email address")
    }
}

pub fn vIsEmail(value: str) -> bool {
    let at = indexOf(value, "@")
    if at < 1 { return false }
    let local = substr(value, 0, at)
    let domain = substr(value, at + 1, len(value))

    if len(domain) < 3 { return false }
    if indexOf(domain, "@") >= 0 { return false }
    if contains(value, " ") { return false }

    let dot = indexOf(domain, ".")
    if dot < 1 { return false }
    if endsWith(domain, ".") { return false }
    if startsWith(domain, ".") { return false }
    if contains(domain, "..") { return false }
    if startsWith(local, ".") || endsWith(local, ".") { return false }
    return true
}

pub fn vURL(v: Validator, field: str, value: str) {
    if value == "" { return }
    if !vIsURL(value) {
        vAdd(v, field, "is not a valid url")
    }
}

pub fn vIsURL(value: str) -> bool {
    if !startsWith(value, "http://") && !startsWith(value, "https://") {
        return false
    }
    let rest = value
    if startsWith(value, "https://") {
        rest = substr(value, 8, len(value))
    } else {
        rest = substr(value, 7, len(value))
    }
    if rest == "" { return false }
    if startsWith(rest, "/") { return false }
    if contains(rest, " ") { return false }
    return true
}

// A regular expression, for anything with a shape this file does not
// know about.
pub fn vMatches(v: Validator, field: str, value: str, pattern: str, what: str) {
    if value == "" { return }
    if !re.matches(pattern, value) {
        vAdd(v, field, "must be {what}")
    }
}

// ---- sets ----

pub fn vOneOf(v: Validator, field: str, value: str, allowed: []str) {
    if value == "" { return }
    if !contains(allowed, value) {
        vAdd(v, field, "must be one of: {join(allowed, ", ")}")
    }
}

pub fn vEquals(v: Validator, field: str, value: str, other: str, otherName: str) {
    if value != other {
        vAdd(v, field, "must match {otherName}")
    }
}

// ---- your own ----

// For a rule this file cannot express: check it yourself and report.
pub fn vCheck(v: Validator, field: str, ok: bool, problem: str) {
    if !ok {
        vAdd(v, field, problem)
    }
}

// ---- the answer ----

pub fn vOK(v: Validator) -> bool {
    return len(v.problems) == 0
}

pub fn vProblems(v: Validator) -> []str {
    return v.problems
}

pub fn vFailed(v: Validator, field: str) -> bool {
    return contains(v.fields, field)
}

pub fn vCount(v: Validator) -> int {
    return len(v.problems)
}

// Every problem, one per line.
pub fn vReport(v: Validator) -> str {
    if len(v.problems) == 0 { return "" }
    return join(v.problems, "\n")
}

// The whole thing as a failure, for a function returning T!.
//
//     fn signUp(name: str, email: str) -> void! {
//         let v = vNew()
//         vRequired(v, "name", name)
//         vEmail(v, "email", email)
//         vResult(v)?
//         ...
//     }
pub fn vResult(v: Validator) -> void! {
    if len(v.problems) > 0 {
        return fail(join(v.problems, "; "))
    }
}
