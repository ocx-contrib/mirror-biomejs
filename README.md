# mirror-biomejs

OCX mirror for [Biome](https://biomejs.dev), the Rust formatter/linter/import
sorter for web projects. One repository, one spec directory per package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [biome](https://github.com/biomejs/biome) | [`biome/mirror.yml`](biome/mirror.yml) | `ghcr.io/ocx-contrib/biomejs/biome` | [`ocx.sh/biomejs/biome`](https://index.ocx.sh/biomejs/biome) | `MIT OR Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`biomejs` is the project's own brand rather than a maintainer's personal
handle — the org exists for Biome and nothing else — so the org names the
namespace: the package is `biomejs/biome`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
biome/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `biome/mirror.yml` does not restate it at all, which removes the
trap structurally.

## The npm-scoped tag

Biome is released from a JS monorepo and its git tags are literal npm
coordinates — `@biomejs/biome@2.5.6`. The spec's `tag_pattern` anchors the
package name as a **literal string**, not as a wildcard scope, because the same
repository tags other packages under the same scope. `@biomejs/js-api` releases
carry **zero assets** and interleave by date (`@biomejs/js-api@6.0.0` was
published two minutes before `@biomejs/biome@2.5.0`), and an asset-less release
inside the mirrored range is *silently dropped* by the pipeline rather than
reported. A wildcard-scope pattern would admit it and nothing would red. The
end anchor additionally excludes the `-beta`/`-nightly` suffixed js-api tags,
which GitHub flags `prerelease: false` and `skip_prereleases` therefore does
not catch, plus the abandoned pre-2.0 `cli/vX.Y.Z` scheme.

## Platforms

Six platform entries: both Linux arches, both macOS arches and both Windows
arches. Upstream's os/arch tokens are npm/Node convention rather than Rust or
Go convention — `win32` for Windows, `x64` for amd64 — so the asset regexes
spell it upstream's way while the platform keys use ocx's (`windows/amd64`).

Upstream ships **four** Linux artifacts per release, a glibc and a musl build
for each arch, so the libc question had to be measured per variant rather than
inferred. All four were byte-measured at **both ends** of the mirrored range,
2.5.4 and 2.5.6:

- `biome-linux-{x64,arm64}-musl` — `statically linked` / `static-pie linked`,
  `readelf -l | grep -c INTERP` → 0, `readelf -d | grep -c NEEDED` → 0, no UPX
  stub (`strings -a | grep -c '^UPX'` → 0, section headers present).
- `biome-linux-{x64,arm64}` — `dynamically linked`, interpreter
  `/lib64/ld-linux-x86-64.so.2` (resp. `/lib/ld-linux-aarch64.so.1`), five
  `DT_NEEDED` entries ending in `libc.so.6`.

`os.features` states what an artifact requires *of the host*, so this mirror
publishes the **musl** builds under **bare** Linux keys: static means it
requires nothing, and `+libc.musl` on a static binary would be a false
requirement that hides the package from every glibc host it in fact runs on.
The `alpine:3.20` container leg on both arches is what turns that claim into
evidence, and the claim is falsifiable — the glibc build exits 127 in the same
image, the musl build exits 0 with no `apk add` at all.

The glibc builds are **not** published under a second `+libc.glibc` key. That
would be safe (specificity scoring would hand a glibc host the gnu build), but
it was measured and declined: the gnu build carries no capability the musl one
lacks. Biome resolves no hostnames, opens no sockets, `dlopen`s nothing and
bundles no runtime — its plugins are interpreted GritQL text, not shared
objects — so the usual justification, musl's resolver ignoring
`nsswitch.conf`, cannot arise. The only reachable difference is throughput:
formatting a generated 4 000-function file, five runs each, the gnu build's
median was 0.064 s against the musl build's 0.085 s. A ~33 % delta on an
operation taking under a tenth of a second is not a capability, and two keys is
the fallback rather than the goal.

### `windows/arm64` is broken on 2.5.4, upstream

`biome-win32-arm64.exe` **2.5.4** loads and runs — `biome --version` exits 0
and prints its version — but faults on the first real filesystem operation:
`biome format` against a two-line scratch file returns exit `-1073741819`,
i.e. `0xC0000005` STATUS_ACCESS_VIOLATION. Measured twice on `windows-11-arm`
with a byte-identical failure, so not a flake, while the same script and the
same fixture pass on `windows/amd64` for every in-range version and on every
Linux and macOS leg.

That version is therefore excluded for that one platform via
`platforms."windows/arm64".exclude` with `severity: broken`, which surfaces it
as a 🔒 row rather than hiding the tile. The smoke test was **not** weakened to
accommodate it — the assertion that caught the crash is unchanged and still
runs on every other `(version, platform)`.

No container leg runs `containers[].setup`. The artifacts have zero
`DT_NEEDED`, and biome shells out to nothing — it only reads and writes files
the smoke test creates in its own scratch sandbox. Provisioning packages into
the images would weaken the claim rather than support it; a bare image is what
makes "needs nothing of the host" testable.

### Raw binaries, and the prefix collision

Every asset is a **raw uncompressed binary** — no tarball, no zip, not even a
bare `.gz` twin — so `asset_type` is `{type: binary, name: biome}` and the file
lands directly at the bundle content root.

Every pattern is **end-anchored**, and here that is load-bearing rather than
hygiene: `biome-linux-x64` is a strict prefix of `biome-linux-x64-musl`
(identically for arm64). An unanchored `^biome-linux-x64` matches both, which
is a hard ambiguous error; the mirror-image mistake — dropping `-musl` from the
pattern while intending the static build — would *silently* ship the
glibc-dynamic binary under a bare key, which is exactly the false universality
claim the libc gate exists to prevent.

Resolution was verified **both ways on every in-range release** (2.5.4, 2.5.5,
2.5.6): each release ships exactly the same 8 assets and each pattern matches
exactly one. A pattern matching zero is silently skipped rather than reported,
so this check is not optional.

Biome's asset filenames are **version-independent** (`biome-linux-x64` on every
release), so the usual "do the asset names agree with the tag?" check is not
expressible by name and was replaced: all 24 in-range asset digests are
distinct, and each of the three linux/amd64 binaries was executed and
self-reported its own tag.

Upstream publishes no checksum and no signature sidecar on any release —
unusual for this fleet. `verify.github_asset_digest` does not depend on one: it
compares against the `sha256:` digest GitHub itself records per asset, which is
populated for all 8 assets on all three in-range tags.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `biome/mirror.yml` | hand | yes — see below |
| `biome/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `biome/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec biome/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`biome/metadata.json` declares `binaries: ["biome"]` by hand, and
`mirror-base.yml` sets `bin_scan: "off"` — forced, not preferred. Every asset
is a raw binary, so it lands at the bundle content root and `PATH` is a bare
`${installPath}`; the scan only inspects an interface-visible
`${installPath}/<dir>` entry, so with no subdirectory to point at, `auto` and
`verify` both fail spec load at exit 65 rather than offer a hollow check.

The hand list is **load-bearing beyond documentation**: GitHub serves raw
release assets with mode `0644` (measured on all nine downloaded biome assets),
and `prepare` chmods `0755` exactly the names `metadata.json` declares. An
undeclared binary would ship non-executable, and `bin_scan: auto` could not
rescue it — the scan only reports candidates it finds *already* executable.

## The smoke test

`biome/tests/smoke.star` writes every fixture into the test scratch sandbox and
asserts what biome *did*, never what it printed:

- `biome --version` matches a version **shape** regex — the digits are the
  contract, the `Version: ` banner is not.
- A three-step formatter round trip. Check mode on an unformatted-but-valid
  file must exit 1 first; without that half, a `format` that rubber-stamped
  everything would still make the round trip look green. `format --write` then
  renders biome's own canonical bytes, which are compared exactly (modulo
  `\r`), and check mode must pass on the result.
- The linter read through `--reporter=json`, a machine format biome emits with
  **zero** escape bytes. The assertions are the `lint/suspicious/noSelfCompare`
  rule ID (a single unbroken token, and the documented string a user writes to
  configure that rule) and `"errors":1,` — a *count*, not mere presence, and
  the trailing comma matters because without it the needle is a prefix of
  `"errors":10`.
- Two negative controls. A clean file must report `"errors":0,` and exit 0 —
  a linter stuck reporting nothing passes that but fails the case above, one
  stuck reporting everything does the reverse, and only the pair proves the
  analysis depends on the input. Separately, syntactically invalid input must
  exit 1 through the **parser**, which is the one assertion that would still
  red if the whole lint rule registry were stripped from the bundle.

Nothing asserts on the default reporter's output: biome paints its diagnostics
with ANSI colour and box-drawing rules, and a plain multi-word substring check
against that is a coin flip because SGR lands per token. Every assertion is an
exit code biome computed, a file it wrote, or a token inside its JSON reporter.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; the
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md), as is
the separate CC-BY-SA-4.0 license covering the logo.
