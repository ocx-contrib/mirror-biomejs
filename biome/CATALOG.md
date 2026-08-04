---
title: biome
description: One fast Rust toolchain for web projects — formatter, linter and import sorter for JavaScript, TypeScript, JSX, JSON, CSS and GraphQL
keywords: biome,biomejs,formatter,linter,javascript,typescript,jsx,tsx,json,css,graphql,prettier,eslint,import-sort,rust,cli
---

# biome

[Biome](https://biomejs.dev) is a single binary that formats, lints and sorts
imports for web projects — JavaScript, TypeScript, JSX/TSX, JSON/JSONC, CSS,
GraphQL and HTML — replacing a Prettier + ESLint stack with one tool and no
Node, npm or plugin tree to install. It grew out of Rome Tools and is written
in Rust.

Formatting is Prettier-compatible by design (upstream reports ~97 % agreement
on their test suite), and the linter ships hundreds of rules, many carrying
safe or suggested automatic fixes.

## What's included

- **biome** — the CLI. `biome format` formats, `biome lint` lints,
  `biome check` runs formatter + linter + import sorting together, and each
  takes `--write` to apply fixes in place. `biome ci` is the non-writing
  variant for pipelines, `biome init` scaffolds a `biome.json`,
  `biome migrate` updates it across breaking changes, `biome explain <rule>`
  prints a rule's documentation, and `biome lsp-proxy` speaks LSP over
  stdin/stdout for editor integration.

Reports can be emitted for other tools with
`--reporter=<json|junit|github|gitlab|checkstyle|rdjson|sarif|summary|concise>`.

## Quick start

```sh
biome check --write ./src            # format + lint + organise imports, in place
biome format --write ./src           # formatting only
biome lint ./src                     # lint only, exits non-zero on findings
biome ci ./src                       # CI mode: never writes, reports and exits
```

Configuration is optional — Biome runs on sensible defaults with no config file
at all. `biome init` writes a `biome.json` when you want to change them:

```json
{
  "formatter": { "indentStyle": "space", "indentWidth": 2 },
  "linter": { "rules": { "recommended": true } }
}
```

## Links

- [Biome website](https://biomejs.dev)
- [biome on GitHub](https://github.com/biomejs/biome)
- [CLI reference](https://biomejs.dev/reference/cli/)
- [Configuration reference](https://biomejs.dev/reference/configuration/)
- [Lint rule index](https://biomejs.dev/linter/rules/)
