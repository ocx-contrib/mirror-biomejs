# NOTICE

This repository packages and redistributes upstream software published by the
[Biome](https://github.com/biomejs/biome) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — the redistributed bytes carry their
own license, recorded below.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `biome` | `ghcr.io/ocx-contrib/biomejs/biome` | `MIT OR Apache-2.0` |

---

## `biome`

Upstream: <https://github.com/biomejs/biome>
Published to `ghcr.io/ocx-contrib/biomejs/biome`.

| Component | SPDX | Holder |
|---|---|---|
| biome | **MIT OR Apache-2.0** | Copyright (c) 2023-present Biome Developers and Contributors; Copyright (c) 2020-2023 Rome Tools, Inc. and its affiliates |

Verified at the Phase 1.5 license gate:

```
$ gh api repos/biomejs/biome/license --jq '{spdx: .license.spdx_id, path: .path}'
{"path":"LICENSE-APACHE","spdx":"Apache-2.0"}
```

GitHub's detector reports only the first license file it recognises. The
repository is in fact **dual licensed**: `LICENSE-APACHE` and `LICENSE-MIT`
both sit at the root, and the workspace `Cargo.toml` declares
`license = "MIT OR Apache-2.0"`. The honest SPDX expression is therefore the
disjunction, and it is what every published manifest carries in
`org.opencontainers.image.licenses`, alongside an
`org.opencontainers.image.source` annotation pointing at this repository.

Both halves are permissive and either alone grants redistribution of the
compiled binary subject to its notice-retention condition. Upstream's release
assets are **raw uncompressed binaries** — a single file per platform with no
archive around it, so no `LICENSE` file travels alongside — and the notice is
therefore retained here instead. The canonical texts are
<https://github.com/biomejs/biome/blob/main/LICENSE-APACHE> and
<https://github.com/biomejs/biome/blob/main/LICENSE-MIT>.

The published binaries are Rust builds that statically vendor third-party
crates under permissive licenses, enumerated in the `Cargo.lock` of the tagged
upstream source for each mirrored version.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle. The only transformation is the
executable mode bit: GitHub serves raw release assets as `0644`, and `prepare`
chmods the declared binary to `0755` so it can be run at all.

### Logo

`biome/logo.svg` is upstream's own mark, taken from
[`biomejs/resources`](https://github.com/biomejs/resources) at
[`svg/icon-light-transparent.svg`](https://github.com/biomejs/resources/blob/main/svg/icon-light-transparent.svg),
and `biome/logo.png` is a 512×512 raster of it for catalog identification only.

Those brand assets are licensed
[**CC-BY-SA-4.0**](https://creativecommons.org/licenses/by-sa/4.0/) by
*Alexandru-Ștefan Gârleanu, Biome Core Contributors and Maintainers*
(see [`LICENSE.md`](https://github.com/biomejs/resources/blob/main/LICENSE.md)
in that repository). This copy is **adapted** — a `viewBox` attribute was added
so the mark scales, and the PNG is a re-encoding at 512×512 — and both adapted
files are redistributed here under the same CC-BY-SA-4.0 terms. No endorsement
is implied, and no trademark claim is made.
