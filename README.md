# tebako-packages/toolkits

**Homebrew without the admin.** Curated, hash-pinned, native toolkits as
tebako payloads — the jq/yq/ripgrep class of tools, pressed as
binary+license `.tfs` slices, cached once machine-wide, shimmed onto
PATH, jailable. No `sudo`, no `/usr/local`, no compiler, no cellar:
`tebako install jq` and the shim answers.

This is the no-runtime lane of the tebako ecosystem (the toolkit lane of
tebako-packages/index#22, leverage-ranked first in the runtime census):
a toolkit payload is the hello-feedstock shape minus the build — the
binary *is* the payload, and it needs no runtime edge.

## The model — repack, honestly

This increment ships **upstream's own official static builds**, never
source-built anything: each leg fetches upstream's release asset,
sha256-verifies it against the recipe pin, cross-checks the pin against
upstream's own published checksum document, stages the binary plus its
license notice(s) into a payload root, and presses it as a limnifs
`.tfs` image (the default tebako image format) with the pinned `tfs`
CLI. Nothing compiles on any leg — not on the CI runners, and never on
the user's machine.

Where upstream ships no acceptable build for a wanted triplet, the gap
is **named**, not compiled (see *Limits*). A future increment may build
static from source for those gaps; this one does not.

**One feedstock, per-tool payload rows.** Each tool is an independent
payload (`jq`, `yq`, `ripgrep`) with its own recipe in `recipes/` and
its own version line — tools version independently, and
`tebako install jq` must fetch jq only. A single multi-entrypoint
`toolkits` payload was rejected: it would version-lockstep unrelated
tools and download every tool for any one.

Each payload is `kind: toolkit`, declares its entrypoints in the
in-image spec-03 manifest (`/__tpkg__/manifest.yaml`), and carries **no
runtime edge** — there is no interpreter; the mounted binary runs
directly.

## The tools

Rendered from `recipes/*.yml` (the machine-readable SSOT for every pin;
the tables below are a human render — if they ever disagree, the recipe
is right).

### jq 1.8.2 — entrypoint `jq`

- upstream release: <https://github.com/jqlang/jq/releases/download/jq-1.8.2>
- license: MIT (the code license; jq's manual is CC-BY-3.0 — both
  notices are in the `COPYING` file the payload carries at
  `/share/licenses/jq/COPYING`)
- upstream checksum cross-check: `sha256sum.txt` (sha256sum format)

| tebako triplet | upstream asset | sha256 |
|---|---|---|
| aarch64-macos | `jq-macos-arm64` | `2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e` |
| x86_64-macos | `jq-macos-amd64` | `e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0` |
| x86_64-linux-gnu | `jq-linux-amd64` | `b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f` |
| aarch64-linux-gnu | `jq-linux-arm64` | `8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309` |
| x86_64-windows-ucrt | `jq-windows-amd64.exe` | `a6fc67fedaf9128a3309a1e2ebb8b986aeccf70122ee46d2cb4849e423f0c627` |

### yq 4.54.3 — entrypoint `yq`

- upstream release: <https://github.com/mikefarah/yq/releases/download/v4.54.3>
- license: MIT (the payload carries `/share/licenses/yq/LICENSE`)
- upstream checksum cross-check: `checksums` (rhash multi-hash format;
  the SHA-256 column is located via `checksums_hashes_order`, never
  hardcoded)

| tebako triplet | upstream asset | sha256 |
|---|---|---|
| aarch64-macos | `yq_darwin_arm64` | `a2aebb93b5bdcb61bb76f630e42a0ef6a3ee10842a6516cd7b9e4080786ec593` |
| x86_64-macos | `yq_darwin_amd64` | `96d5105ffd693d6845c54fbd825b2d1bbdb8619e0a2ce6af95e5654e841e0984` |
| x86_64-linux-gnu | `yq_linux_amd64` | `129534601871538efe0ba4c5e62a34fb1d5f469bcb975c4fddeb467d82974973` |
| aarch64-linux-gnu | `yq_linux_arm64` | `89f69310b61b68d1245065a1241d1fc843f7a36cd6103ffd77ad987613bd1b67` |
| x86_64-windows-ucrt | `yq_windows_amd64.exe` | `066ea0a09a282e47588ec1e1867280ff5ede458f7183617a2d99012e4e34f18a` |

### ripgrep 16.0.0 — entrypoint `rg`

- upstream release: <https://github.com/BurntSushi/ripgrep/releases/download/16.0.0>
- license: MIT OR Unlicense (dual-licensed; the payload carries
  `COPYING`, `LICENSE-MIT`, `UNLICENSE` under `/share/licenses/ripgrep/`,
  staged from the archive itself)
- upstream checksum cross-check: per-asset `<asset>.sha256` sidecars

| tebako triplet | upstream asset | sha256 |
|---|---|---|
| aarch64-macos | `ripgrep-16.0.0-aarch64-apple-darwin.tar.gz` | `5a145656d5067144001bfce6648767fd3254599aa736f1ffdb7fb907760b8ca1` |
| x86_64-macos | `ripgrep-16.0.0-x86_64-apple-darwin.tar.gz` | `aa9183b0e0bfac03c5818895ad18b75001c402d230063898abfe5a58cd413caa` |
| x86_64-linux-gnu | `ripgrep-16.0.0-x86_64-unknown-linux-musl.tar.gz` | `54268ab4643c00a290a29b0086066d64b3f56236dd805ec64629a86f9bd29fd0` |
| aarch64-linux-gnu | `ripgrep-16.0.0-aarch64-unknown-linux-musl.tar.gz` | `374f1886be881e8e8683d7107278f7af1b6017fda75eb97de71f5783f42b0110` |
| x86_64-windows-ucrt | `ripgrep-16.0.0-x86_64-pc-windows-msvc.zip` | `f418ae83e63046a94a7b5f3a44bf3a169f66e689164856ecee02547131c73931` |

## Static-ness, verified (2026-11-23)

Every shipped binary was inspected, not assumed:

- **linux**: `file` reports *statically linked* for every leg — jq
  (`jq-linux-amd64`, `jq-linux-arm64`), yq (Go, CGO-free), ripgrep
  (upstream's musl builds: `x86_64-unknown-linux-musl`,
  `aarch64-unknown-linux-musl`). The tebako triplets stay `-linux-gnu`
  (the payloads run on gnu hosts — a static binary does not care which
  libc the host has).
- **macOS**: `otool -L` shows OS libraries only — jq: `libSystem` alone;
  yq: `libSystem`, `libresolv`, `CoreFoundation`, `Security`; ripgrep:
  `libSystem`, `libiconv`. No third-party dylibs anywhere.
- **windows**: the PE import tables list OS DLLs only — jq:
  `KERNEL32`, `SHLWAPI`, `api-ms-win-crt-*` (the in-box UCRT); yq:
  `kernel32` alone; ripgrep (`x86_64-pc-windows-msvc`): `KERNEL32`,
  `ntdll`, `bcryptprimitives`, `api-ms-win-core-synch` — **no
  `VCRUNTIME140` dependency**, so the msvc build runs on a stock
  Windows install.

## The repo

- `recipes/<tool>.yml` — one recipe per tool: upstream release + per-triplet
  asset pins, the checksum cross-check shape, the license notice source,
  the toolchain pins (`tamatebako/tebako` v2.8.83: `tfs` for the legs,
  `tebako` + `tebako-shim` for publish/dogfood — per-infix sha256), the
  `signing:` block (spec 09 §9), the declared entrypoints, and the
  boot-smoke contract.
- `tools/` — the build machine: `emit_matrix` (one CI leg per
  recipe × platform), `build` (fetch → verify → stage → `tfs mkimage`),
  `boot_smoke` (extract-and-run the recipe's `smoke:` contract),
  `stage` (embed the manifest, repack, read-back-validate, sidecar),
  `fetch_publisher` (the pinned tebako CLI + shim, sha256-verified),
  `publish` (per-recipe `tebako publish` → release + registry upsert;
  `--dry-run` rehearses into a file:// mirror),
  `set_registry_defaults.rb`, `recipe_query`, `lib/common.sh`.
- `manifests/payload.yaml` — the spec-03 manifest template `stage` fills.
- `tpkg-registry.yaml` — the feedstock's resolved registry (spec 04 §2).
  Upserted ONLY by the publish job; empty until the first tag.
- `.github/workflows/build-payload.yml` — matrix build → boot-smoke →
  staged artifacts → the publish legs: `publish-dry-run` (every non-publish
  run rehearses the full publish into a file:// mirror, install verify
  included) and `release` (the owner's tag dispatch, publish=true), then
  `ping-registry` (the aggregate poke).
- `.github/workflows/dogfood.yml` — the dogfood: per desktop triplet,
  `tebako install <tool>` from the PUBLISHED registry on a scratch
  `TEBAKO_HOME`, each tool's shim answers. Gated on the published rows
  (skips loudly pre-publish).

Local build (one leg):

```console
$ tools/build recipes/jq.yml 1.8.2 aarch64-macos
$ tools/boot_smoke out/jq/aarch64-macos recipes/jq.yml
$ tools/stage out/jq/aarch64-macos aarch64-macos recipes/jq.yml
# dist/jq-1.8.2-macos-arm64.tfs (+ .manifest.yaml sidecar)
```

## Publishing (the owner's act)

Nothing publishes on push, on a PR, or on a tag push. Publishing is the
owner's explicit act, per the ecosystem hard rule:

1. Push the tag. Grammar: `<feedstock-version>[-<buildno>]` (e.g.
   `0.1.0-1`) — the feedstock's own release line, independent of the
   per-tool recipe versions. A version carrying a non-numeric segment
   after the numeric prefix (`0.2.0rc1-1`) is a PRERELEASE shape: its
   rows publish like any other, but the release is flagged
   `--prerelease` and the registry `default:` entries stay on the latest
   stable publish.
2. Dispatch `.github/workflows/build-payload.yml` ON THE TAG with
   `publish=true`.
3. The `release` job then: republishes every recipe's staged artifacts
   to the tag's release (15 `.tfs` + 15 `.sha256` + 15 `.blksum.json` +
   15 `.asc` — spec-09 §9 signatures by the tamatebako root CI subkey,
   keyid `efc3c250f7862a48`), verifies each published row with a
   clean-cache install before the registry moves, upserts
   `tpkg-registry.yaml`, and lands it on main by bot PR + auto-merge
   (main is branch-protected).
4. `ping-registry` pokes the aggregate registry
   (tebako-packages/registry) so the publish is visible there the same
   day; its 6-hourly aggregate is the self-healing backstop.

Every other run of the workflow exercises the same pipeline as
`publish-dry-run`: a full publish into a file:// mirror — the CLI's pin
verification and clean-cache install verify through the mirror included
— with nothing leaving the runner.

## Limits (this increment, honestly)

- **Nothing is published yet — by rule, not by absence.** The publish
  pipeline (build → mirror-rehearsed dry-run → tag-gated real publish →
  registry bot PR → aggregate ping) is landed and CI-proven, but the
  first tag is the owner's explicit go. Until then `tpkg-registry.yaml`
  carries no rows and the dogfood's gate skips its legs loudly.
- **Upstream's builds, not ours.** We repack what upstream ships. If an
  upstream build is buggy or compromised, the pin protects the *bytes'*
  identity, not their goodness; the trust story is the spec-09 §9
  signature the publish stamps plus upstream's own release provenance
  (ripgrep attests its archives; jq/yq publish checksums we
  cross-check).
- **Coverage is exactly the five triplets listed.** Named gaps we do
  NOT cover yet: aarch64-windows (upstream ships `jq-windows-arm64.exe`
  and `ripgrep-…-aarch64-pc-windows-msvc.zip`; tebako's windows lane is
  x86_64-ucrt today), 32-bit anything (not tebako triplets).
- **ripgrep's windows asset is the msvc build.** Its imports are OS-only
  (verified above), so it needs no redistributable; the tebako
  `x86_64-windows-ucrt` triplet names the platform, not the compiler
  that produced the opaque binary.
- **Payload names vs entrypoints.** The payload is `ripgrep`; the shim
  is `rg` (the declared entrypoint). `tebako install ripgrep` → `rg`
  answers.

## Next increments (named, in order)

1. **More tools** — fd-class, git (if license/static-clean), per the
   census's candidate set.
2. **Source-built statics for the gaps** — only where upstream ships no
   acceptable build for a wanted triplet (aarch64-windows first, if the
   windows lane widens).
