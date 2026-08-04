# biome/tests/smoke.star — stable across upstream biome releases.
#
# Asserts the contract (exit codes, version SHAPE, the bytes biome's own
# formatter WROTE, and biome's own JSON report of a lint run), never
# help/version prose.
#
# WHY NOTHING ASSERTS ON THE DEFAULT REPORTER'S OUTPUT: biome paints its
# diagnostic report with ANSI colour and box-drawing rules, and a plain
# multi-word substring check against that is a coin flip because SGR lands per
# token. So every Tier 3 assertion below is one of:
#   * an exit code biome COMPUTED,
#   * the CONTENT OF A FILE biome rewrote, or
#   * a token inside `--reporter=json`, which is a machine format biome emits
#     with zero escape bytes (measured: `tr -cd '\033' | wc -c` → 0).
# `--colors=off` is passed anyway, belt and braces, so the assertions hold even
# if a leg is ever given a tty.
#
# HERMETIC BY CONSTRUCTION. biome is a formatter/linter for local files and
# opens no sockets: every fixture below is written into the scratch sandbox by
# this script, and `cwd` defaults to the scratch root so all paths stay
# relative — correct on Windows too, with no separator juggling. No config file
# is written: biome runs with its built-in defaults when it finds no
# `biome.json`, which is what makes the expected bytes in FORMATTED below a
# property of the binary rather than of a config this test supplied.
#
# `HOME` is redirected into scratch so nothing the tool might read or persist
# can reach a real user profile. biome does not shell out to a toolchain, so
# the rustup-style HOME hazard does not apply here.

BIOME = "biome.exe" if ocx.target_platform.os == ocx.os.Windows else "biome"

ENV = {"HOME": ocx.scratch_root}

# What biome's formatter produces from MESSY below, byte for byte. This is NOT
# a hand-crafted "correct" artifact used as a check-mode input — that is the
# trap the fixer-tool rule warns about. It is the OUTPUT of biome's own
# `format --write`, asserted after the fact, and the follow-up check-mode run
# below is the independent confirmation. Deliberately free of indentation: the
# default indent style is tabs, and pinning a whitespace default this test does
# not control would be asserting biome's config surface, not its formatter.
MESSY = "const   x=1\nexport   default    x\n"
FORMATTED = "const x = 1;\nexport default x;\n"

# ─── Tier 1 + 2: liveness on the composed PATH + version SHAPE ──────────────
#
# The digits are the contract; the `Version: ` banner around them is not. An
# `expect.contains(stdout, "biome")` would break on a rebrand, and an
# `expect.eq(stdout, "Version: 2.5.6")` would churn every release.
r_version = ocx.run(BIOME, "--version", env = ENV)
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ─── Tier 3a: the formatter, as a three-step round trip ─────────────────────
#
# Step 1 — check mode on an UNFORMATTED but syntactically valid file must
# refuse it. This is the half that makes step 3 mean something: a `format` that
# rubber-stamped everything would exit 0 here, and the round trip would still
# look green.
ocx.write_file("messy.js", MESSY)
r_unformatted = ocx.run(BIOME, "format", "--colors=off", "messy.js", env = ENV)
expect.eq(r_unformatted.exit_code, 1)

# Step 2 — the write. The assertion is on the resulting BYTES, which only
# biome's own formatter could have produced: the input had no semicolons and
# irregular runs of spaces, and nothing in this script's arguments contains the
# output text.
r_write = ocx.run(BIOME, "format", "--colors=off", "--write", "messy.js", env = ENV)
expect.ok(r_write)
# `\r` is stripped before comparing so the assertion stays byte-exact about the
# thing under test (spacing collapsed, semicolons inserted) without also
# pinning a line-ending default that could differ on the Windows legs.
expect.eq(ocx.read_file("messy.js").replace("\r", ""), FORMATTED)

# Step 3 — check mode again, now that biome has rendered its own canonical
# form. Verifying with the tool's own check mode (rather than a second
# hand-written expectation) is what keeps this stable across releases.
r_formatted = ocx.run(BIOME, "format", "--colors=off", "messy.js", env = ENV)
expect.ok(r_formatted)

# ─── Tier 3b: the linter, read through biome's own JSON reporter ────────────
#
# `a === a` is `lint/suspicious/noSelfCompare`, a recommended rule that is on
# by default. The rule ID is a single unbroken token and a documented contract
# (it is the string a user writes in `biome.json` to configure the rule);
# `count()` is asserted rather than mere presence, because a search-shaped
# assertion that only checks exit status greens on an empty result.
#
# The file is exported so `noUnusedVariables` cannot fire and change the count:
# `"errors":1,` pins that biome found EXACTLY the one defect planted here,
# neither missing it nor inventing others. The trailing comma is not
# decoration — without it the needle is a prefix of `"errors":10` and a run
# with ten findings would still count 1.
ocx.write_file("self.js", "export const a = 1;\nexport const b = a === a;\n")
r_lint = ocx.run(BIOME, "lint", "--colors=off", "--reporter=json", "self.js", env = ENV)
expect.eq(r_lint.exit_code, 1)
expect.eq(r_lint.stdout.count("lint/suspicious/noSelfCompare"), 1)
expect.eq(r_lint.stdout.count("\"errors\":1,"), 1)

# ─── Tier 3c: NEGATIVE CONTROL — the clean direction ────────────────────────
#
# The pair matters more than either half. A linter stuck reporting nothing
# passes 3c but fails 3b; one stuck reporting everything passes 3b but fails
# 3c. Only running both proves the analysis actually depends on the input.
ocx.write_file("clean.js", "export const a = 1;\n")
r_clean = ocx.run(BIOME, "lint", "--colors=off", "--reporter=json", "clean.js", env = ENV)
expect.ok(r_clean)
expect.eq(r_clean.stdout.count("\"errors\":0,"), 1)

# ─── Tier 3d: NEGATIVE CONTROL — malformed input ────────────────────────────
#
# Not a lint finding but a PARSE failure, which reaches a different layer of
# the binary: this is the one assertion that would still red if the entire
# lint rule registry were stripped out of the bundle. Exit 1 is biome's
# documented failure code and is POSITIVE on every platform — measured on all
# three in-range versions — so no platform-dependent exit-code constant is
# needed here (a tool exiting -1 would report 255 on unix and -1 on Windows).
ocx.write_file("broken.js", "const = = = ;;;\n")
r_broken = ocx.run(BIOME, "lint", "--colors=off", "broken.js", env = ENV)
expect.eq(r_broken.exit_code, 1)

# No Tier 4: metadata.json declares PATH only (proven by the Tier 1 liveness
# call resolving `biome` off the composed PATH).
