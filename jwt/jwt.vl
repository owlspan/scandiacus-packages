// jwt - JSON Web Tokens, signed with HMAC-SHA256.
//
//     import "jwt"
//
//     let token = must(jwtSign("{\"sub\":\"ada\"}", secret, 3600))
//     let claims = must(jwtVerify(token, secret))
//
// HS256 only. RS256 and ES256 need RSA and elliptic curves, which are
// not something to implement casually, and a library that quietly
// supported fewer algorithms than it claimed would be worse than one
// that says so.
//
// Two things this gets right that are the classic JWT holes:
//
// **The algorithm is not read from the token.** A verifier that trusts
// the header's `alg` can be handed `{"alg":"none"}` and will accept an
// unsigned token. This checks the header says HS256 and verifies with
// HS256 regardless.
//
// **The signature is compared in constant time.** A byte-at-a-time
// comparison that returns early leaks where the first difference is,
// which is enough to forge a signature given enough attempts.
//
// Every name is prefixed because an import lands in one flat namespace.

// ---- base64url, which is base64 with two characters swapped and no
// padding ----

pub fn jwtB64Encode(data: []int) -> str! {
    let b = bytes.ofList(data)?
    let s = bytes.base64(b)
    let out = ""
    let i = 0
    while i < len(s) {
        let c = charAt(s, i)
        if c == "+" { out = out + "-" }
        if c == "/" { out = out + "_" }
        if c == "=" {
            // padding is dropped
        }
        if c != "+" && c != "/" && c != "=" { out = out + c }
        i = i + 1
    }
    return out
}

pub fn jwtB64Decode(s: str) -> []int! {
    let fixed = ""
    let i = 0
    while i < len(s) {
        let c = charAt(s, i)
        if c == "-" { fixed = fixed + "+" }
        if c == "_" { fixed = fixed + "/" }
        if c != "-" && c != "_" { fixed = fixed + c }
        i = i + 1
    }
    // Put the padding back, which base64 decoding needs and a JWT omits.
    while len(fixed) % 4 != 0 {
        fixed = fixed + "="
    }
    return bytes.list(bytes.fromBase64(fixed)?)
}

fn jwtBytesOf(s: str) -> []int {
    return bytes.list(bytes.of(s))
}

fn jwtStrOf(data: []int) -> str! {
    return bytes.str(bytes.ofList(data)?)
}

// ---- HMAC-SHA256 ----

fn jwtSha256(data: []int) -> []int! {
    let b = bytes.ofList(data)?
    let hex = bytes.hash(b, "sha256")?
    return bytes.list(bytes.fromHex(hex)?)
}

pub fn jwtHmacSha256(key: []int, msg: []int) -> []int! {
    const BLOCK = 64

    let k = key
    if len(k) > BLOCK {
        k = jwtSha256(k)?
    }
    while len(k) < BLOCK {
        push(k, 0)
    }

    let inner: []int = []
    let outer: []int = []
    let i = 0
    while i < BLOCK {
        push(inner, k[i] ^ 54)
        push(outer, k[i] ^ 92)
        i = i + 1
    }

    i = 0
    while i < len(msg) {
        push(inner, msg[i])
        i = i + 1
    }

    let innerHash = jwtSha256(inner)?
    i = 0
    while i < len(innerHash) {
        push(outer, innerHash[i])
        i = i + 1
    }
    return jwtSha256(outer)?
}

// ---- signing ----

// Sign a JSON payload. ttlSeconds of 0 means no expiry.
//
// The payload is JSON you build - this does not parse it, so any claims
// you want are yours to put in. exp and iat are added when ttl is set.
pub fn jwtSign(payloadJSON: str, secret: str, ttlSeconds: int) -> str! {
    if secret == "" {
        return fail("refusing to sign with an empty secret")
    }

    const HEADER = `{"alg":"HS256","typ":"JWT"}`

    let payload = trim(payloadJSON)
    if ttlSeconds > 0 {
        let now = time.now()
        let exp = now + ttlSeconds
        // Spliced in before the closing brace rather than by decoding
        // and re-encoding, which would reorder the caller's claims and
        // change the token for no reason.
        if !endsWith(payload, `}`) {
            return fail("the payload is not a JSON object")
        }
        let body = trim(substr(payload, 0, len(payload) - 1))
        let sep = ","
        if body == `{` { sep = "" }
        // A literal brace in a string is written twice, since a single
        // one opens an interpolation.
        payload = body + sep + "\"iat\":{now},\"exp\":{exp}}}"
    }

    let head = jwtB64Encode(jwtBytesOf(HEADER))?
    let body = jwtB64Encode(jwtBytesOf(payload))?
    let signing = head + "." + body
    let mac = jwtHmacSha256(jwtBytesOf(secret), jwtBytesOf(signing))?
    return signing + "." + jwtB64Encode(mac)?
}

// ---- verifying ----

// Check the signature and the expiry, and give back the payload JSON.
//
// The algorithm comes from this function, not from the token. A token
// whose header says none, or RS256, or anything else is refused rather
// than trusted.
pub fn jwtVerify(token: str, secret: str) -> str! {
    let parts = split(token, ".")
    if len(parts) != 3 {
        return fail("a JWT has three parts, this has {len(parts)}")
    }

    let headerJSON = jwtStrOf(jwtB64Decode(parts[0])?)?
    if !contains(headerJSON, "\"HS256\"") {
        return fail("only HS256 is supported, and this token does not use it")
    }

    let signing = parts[0] + "." + parts[1]
    let want = jwtHmacSha256(jwtBytesOf(secret), jwtBytesOf(signing))?
    let got = jwtB64Decode(parts[2])?

    if !jwtSameBytes(want, got) {
        return fail("the signature does not match")
    }

    let payload = jwtStrOf(jwtB64Decode(parts[1])?)?

    let exp = jwtClaimInt(payload, "exp")
    if exp > 0 && time.now() >= exp {
        return fail("the token expired")
    }
    let nbf = jwtClaimInt(payload, "nbf")
    if nbf > 0 && time.now() < nbf {
        return fail("the token is not valid yet")
    }

    return payload
}

// Constant time: every byte is compared and the answer is the
// accumulated difference. Returning early on the first mismatch tells
// an attacker how much of a guess was right.
fn jwtSameBytes(a: []int, b: []int) -> bool {
    if len(a) != len(b) { return false }
    let diff = 0
    let i = 0
    while i < len(a) {
        diff = diff | (a[i] ^ b[i])
        i = i + 1
    }
    return diff == 0
}

// A numeric claim, or 0 when it is absent. Read out of the JSON text
// rather than by decoding, since the payload's shape is the caller's
// and decoding it would need a type this package cannot know.
fn jwtClaimInt(payload: str, name: str) -> int {
    let needle = "\"{name}\""
    let at = indexOf(payload, needle)
    if at < 0 { return 0 }

    let i = at + len(needle)
    while i < len(payload) && (charAt(payload, i) == " " || charAt(payload, i) == ":") {
        i = i + 1
    }
    let start = i
    while i < len(payload) {
        let c = __strAt(payload, i)
        if c < 48 || c > 57 { break }
        i = i + 1
    }
    if i == start { return 0 }
    return toInt(substr(payload, start, i))
}

// The payload without checking anything.
//
// For reading a claim before deciding which secret to verify with. Do
// not trust what it returns: nothing has been verified at this point.
pub fn jwtPayloadUnverified(token: str) -> str! {
    let parts = split(token, ".")
    if len(parts) != 3 {
        return fail("a JWT has three parts, this has {len(parts)}")
    }
    return jwtStrOf(jwtB64Decode(parts[1])?)?
}

pub fn jwtExpired(token: str) -> bool! {
    let payload = jwtPayloadUnverified(token)?
    let exp = jwtClaimInt(payload, "exp")
    if exp == 0 { return false }
    return time.now() >= exp
}
