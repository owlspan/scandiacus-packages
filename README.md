# Scandiacus packages

The official library registry for [Scandiacus](https://github.com/owlspan/Scandiacus).

```
Scandiacus get totp
```

That reads from this repository, drops the package into
`./veyl_modules/totp/` next to your program, and `import "totp"` finds
it.

| Package | What it is |
| --- | --- |
| [`dotenv`](dotenv/) | `.env` files, with quoting and typed reads |
| [`gl`](gl/) | OpenGL on a `win` window, Windows and Linux: context, shaders, buffers, textures, matrices |
| [`ini`](ini/) | Config files: `[sections]`, `key = value`, comments |
| [`jwt`](jwt/) | JSON Web Tokens, HS256, signing and verifying |
| [`querybuilder`](querybuilder/) | Building SQL without pasting values into it |
| [`sqlite`](sqlite/) | SQLite, and the `sqlite3.dll` that `db.*` needs |
| [`toml`](toml/) | TOML config, flattened to dotted keys, typed reads |
| [`totp`](totp/) | TOTP and HOTP, the six-digit codes an authenticator app shows |
| [`validator`](validator/) | Checking data, collecting every problem |
| [`vulkan`](vulkan/) | Vulkan on a `win` window, Windows and Linux: swapchain, depth, SPIR-V pipelines, textures, uniforms |

---

## Why packages exist

The scandiacus installer is small and the point is keeping it that way.
Anything most programs do not need lives out here instead, so a program
that never generates a 2FA code never carries the code that does.

It also means a package can ship a **native `.dll`** without every Scandiacus
install carrying it. `scandiacus build` copies any DLL from an installed
package next to the executable it writes.

---

## Installing

```
scandiacus get totp                          from this registry
scandiacus get github.com/someone/their-lib  from anyone's repository
scandiacus get https://example.com/thing.vl  from a single file
scandiacus list                              what is installed here
scandiacus remove totp                       uninstall it
```

All of them at once:

```
scandiacus get officials            every package here
scandiacus get officials --nodlls   the same, minus the ones carrying a
                              native library
```

`--nodlls` matters for size. Everything here is a few kilobytes except
`sqlite`, which is three megabytes because it carries the real library.

The same works for anyone's registry. It only needs a `veyl.index`
listing its packages, one name per line:

```
scandiacus get github.com/you/your-registry --all
```

Packages install into `./scandiacus_modules` **next to your program**, not
machine-wide. Two projects can want different versions of the same
thing, and deleting `scandiacus_modules` uninstalls everything.

Add `scandiacus_modules/` to your `.gitignore` and let `scandiacus get` restore it,
or commit it and have the dependency travel with the project. Both work.

---

## Making your own package repository

You do not need permission and you do not need to be in this registry.
A package repository is just files in a GitHub repo.

### The simplest possible package

Create a repo, put one `.scd` file in it named after the repo:

```
my-thing/
  my-thing.scd
```

Anyone can now install it:

```
scandiacus get github.com/you/my-thing
```

With no manifest, `scandiacus get` fetches `<repo-name>.scd` from the root.
That is the whole convention.

### More than one file

Add a `scandiacus.pkg` listing what the package is made of, one file per
line:

```
# my-thing/scandiacus.pkg
my-thing.scd
helpers.scd
tables.scd
```

Blank lines and lines starting with `#` are ignored. Every file named
is fetched; nothing else in the repo is.

The file the import resolves to is always `<name>.scd`, so a package
called `my-thing` must contain `my-thing.scd`. The other files are for
that one to `import`.

### Shipping a native library

Name the `.dll` in the manifest alongside the source:

```
sqlite.vl
sqlite3.dll
```

It is installed with the rest, and `scandiacus build` copies it next to the
executable. Nothing else is needed - no build step, no linker flags.

### A registry with several packages

Put each one in its own directory, the way this repository does:

```
your-registry/
  README.md
  thing-one/
    scandiacus.pkg
    thing-one.scd
  thing-two/
    thing-two.scd
```

Then people install from it by path:

```
scandiacus get github.com/you/your-registry/thing-one
```

### Which branch is used

`scandiacus get github.com/...` reads from the repository's **default
branch**, whatever it is called. There is no version pinning yet: you
get whatever is on the default branch at the moment you run it. If that
matters to you, install from a URL that names a tag.

---

## Writing the code

### Prefix every name

An `import` lands in one **flat namespace**. There is no `totp.`
qualifier - `import "totp"` brings `totpNow` into scope, not
`totp.now`.

So prefix everything a package exports:

```scandiacus
pub fn totpNow(secret: str) -> str! { ... }     // good
pub fn now(secret: str) -> str! { ... }         // will collide
```

Two packages that both export `parse` cannot be used in the same
program, and the error names both files. This is a known limitation
rather than a design choice, and the convention is what works today.

### `pub` decides what escapes

Anything without `pub` is private to the package. Keep the surface
small - every `pub` name is one more chance of a collision.

```scandiacus
fn helper(x: int) -> int { ... }         // private
pub fn thingHelper(x: int) -> int { ... } // exported
```

### Report failure, do not stop the program

Return `T!` and let the caller decide. A library that calls `must()` or
`exit()` takes that decision away from every program that uses it.

```scandiacus
pub fn thingParse(s: str) -> Config! {
    if s == "" {
        return fail("nothing to parse")
    }
    ...
}
```

### Do not run code at import time

A package is declarations. Top-level statements in an imported file are
a compile error, which is deliberate: code that runs on import runs at
a moment nobody chose.

Use a `const` for shared state, or an init function the caller calls.

---

## Getting a package into this registry

Open a pull request on this repository adding your package as a
directory, or an issue with a link to yours and it can be vendored in.

What is looked for:

- **It works.** Tested, ideally against published test vectors if the
  thing it implements has any.
- **It is useful to more than one person.**
- **The names are prefixed** so it composes with other packages.
- **Failures are `T!`**, not `must()`.
- **No surprises.** A package that reads files or opens sockets should
  say so at the top of the file.

Being in this registry only means `scandiacus get <name>` works without the
`github.com/you/` prefix. Everything else about a package is the same
either way, and you are not required to be here to publish.
