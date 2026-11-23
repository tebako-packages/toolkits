#!/usr/bin/env bash
# Shared helpers for the toolkits feedstock (tebako-packages/toolkits).
# Sourced by tools/build, tools/boot_smoke, tools/stage.
# Hard rule (docs/conventions.md in tebako-packages/index): every download
# is sha256-verified; there are no silent fallbacks — every helper fails
# loudly.

set -euo pipefail

# Map a recipe platform triplet to the infix used by the toolchain
# release assets (tamatebako/tebako releases ship the tfs CLI as
# tfs-<version>-<infix>[.exe]).
asset_infix() {
  case "$1" in
    x86_64-linux-gnu)    printf '%s' linux-gnu-x86_64 ;;
    aarch64-linux-gnu)   printf '%s' linux-gnu-arm64 ;;
    aarch64-macos)       printf '%s' macos-arm64 ;;
    x86_64-macos)        printf '%s' macos-x86_64 ;;
    x86_64-windows-ucrt) printf '%s' windows-ucrt64 ;;
    *) echo "asset_infix: unknown platform triplet '$1'" >&2; return 1 ;;
  esac
}

# The PE suffix a platform's executables carry on disk (in the staging
# tree, hence in the image and its manifest): windows-ucrt assets produce
# <name>.exe where the recipe declares the canonical suffix-free path.
exe_suffix_for() {
  case "$1" in
    *-windows-ucrt) printf '%s' .exe ;;
    *)              : ;;
  esac
}

# tfs_bin TOOLSDIR — the leg's verified tfs CLI (tfs.exe on windows-ucrt).
tfs_bin() {
  if [ -f "$1/tfs.exe" ]; then printf '%s' "$1/tfs.exe"; else printf '%s' "$1/tfs"; fi
}

# pack_image PLATFORM TOOLSDIR ROOT IMAGE — pack ROOT as the payload IMAGE
# with the leg's verified tfs CLI: `tfs mkimage --format limnifs` (the
# product's in-process writer; limnifs is the default tebako image
# format). Hard error on an unknown platform — no silent fallback.
pack_image() {
  case "$1" in
    *-windows-ucrt|*-linux-gnu|*-macos) "$(tfs_bin "$2")" mkimage --format limnifs "$3" --output "$4" ;;
    *) echo "pack_image: unknown platform triplet '$1'" >&2; return 1 ;;
  esac
}

# image_reader PLATFORM OUTDIR — echo the image-reader binary one built
# leg carries: the same verified tfs CLI on every platform (subcommand
# parity: info/tree/cat/stat/extract -d).
image_reader() {
  case "$1" in
    *-windows-ucrt|*-linux-gnu|*-macos)  tfs_bin "$2/tools" ;;
    *) echo "image_reader: unknown platform triplet '$1'" >&2; return 1 ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# fetch URL DEST — plain download, no verification (internal).
fetch() {
  echo "fetch: $1" >&2
  curl -fSL --retry 3 --retry-delay 2 -o "$2" "$1"
}

# fetch_verified URL EXPECTED_SHA256 DEST — download + verify, else die.
fetch_verified() {
  fetch "$1" "$3"
  local got
  got="$(sha256_of "$3")"
  if [ "$got" != "$2" ]; then
    echo "SHA256 MISMATCH: $1" >&2
    echo "  expected: $2" >&2
    echo "  got:      $got" >&2
    return 1
  fi
  echo "verified: $3 (sha256 $got)" >&2
}

# asset_field RECIPE PLATFORM FIELD — one field of the recipe's
# upstream.assets.<triplet> map (file, sha256, archive, member). Missing
# optional fields print empty (archive/member are absent for bare-binary
# assets). A missing file/sha256 is a hard error (recipe_query's own
# refusal).
asset_field() {
  local v
  case "$3" in
    file|sha256) v="$("$HERE/recipe_query" "$1" "upstream.assets.$2.$3")" ;;
    *)           v="$("$HERE/recipe_query" -o "$1" "upstream.assets.$2.$3")" ;;
  esac
  [ "$v" = "[]" ] && v=""
  printf '%s' "$v"
}

# asset_licenses RECIPE PLATFORM — the archive-carried license members,
# one per line (empty for bare-binary assets).
asset_licenses() {
  "$HERE/recipe_query" -o "$1" "upstream.assets.$2.licenses" \
    | ruby -rjson -e 'JSON.parse(STDIN.read).each { |g| puts g }'
}

# cross_check_sums RECIPE PLATFORM FILE EXPECTED_SHA256 DESTDIR
# Cross-check the recipe pin against the upstream-published checksum data
# (the pin stays the trust anchor; this guards pin drift — the same
# doctrine as download_tfs's SHA256SUMS cross-check). The recipe's
# upstream.sums block selects the shape:
#   {file: F, format: sha256sum}                    "<sha>  <file>" lines
#   {file: F, format: rhash, order_file: O}         "<file>  <hash>…" lines,
#                                                   the SHA-256 column located
#                                                   via O (never hardcoded)
#   {format: sidecar}                               per-asset <file>.sha256;
#                                                   the first 64-hex token
#                                                   (covers both shasum and
#                                                   certutil spellings)
# A declared sums block that does not contain the asset's checksum is a
# hard error — never a silent skip.
cross_check_sums() {
  local recipe="$1" platform="$2" file="$3" want="$4" destdir="$5"
  local release format sums_file upstream got
  release="$("$HERE/recipe_query" "$recipe" upstream.release)"
  format="$("$HERE/recipe_query" -o "$recipe" upstream.sums.format)"
  [ "$format" = "[]" ] && format=""
  [ -n "$format" ] || { echo "cross_check_sums: recipe declares no upstream.sums — skipping" >&2; return 0; }
  mkdir -p "$destdir"
  case "$format" in
    sha256sum)
      sums_file="$destdir/$("$HERE/recipe_query" "$recipe" upstream.sums.file)"
      [ -f "$sums_file" ] || fetch "$release/$("$HERE/recipe_query" "$recipe" upstream.sums.file)" "$sums_file"
      upstream="$(awk -v f="$file" '$2 == f {print $1}' "$sums_file")"
      ;;
    rhash)
      local order_file order sums
      sums="$("$HERE/recipe_query" "$recipe" upstream.sums.file)"
      order="$("$HERE/recipe_query" "$recipe" upstream.sums.order_file)"
      sums_file="$destdir/$sums"
      order_file="$destdir/$order"
      [ -f "$sums_file" ]  || fetch "$release/$sums" "$sums_file"
      [ -f "$order_file" ] || fetch "$release/$order" "$order_file"
      upstream="$(ruby -e '
        order = File.readlines(ARGV[0], chomp: true)
        col = order.index("SHA-256") or abort "cross_check_sums: no SHA-256 column in #{ARGV[0]}"
        line = File.readlines(ARGV[1], chomp: true).find { |l| l.split.first == ARGV[2] }
        puts(line ? line.split[col + 1].to_s : "")
      ' "$order_file" "$sums_file" "$file")"
      ;;
    sidecar)
      sums_file="$destdir/$file.sha256"
      [ -f "$sums_file" ] || fetch "$release/$file.sha256" "$sums_file"
      upstream="$(grep -oiE '[0-9a-f]{64}' "$sums_file" | head -1 | tr 'A-F' 'a-f')"
      ;;
    *)
      echo "cross_check_sums: unknown upstream.sums.format '$format'" >&2; return 1 ;;
  esac
  [ -n "$upstream" ] || { echo "cross_check_sums: no checksum for $file in upstream's sums data" >&2; return 1; }
  if [ "$upstream" != "$want" ]; then
    echo "cross_check_sums: PIN DRIFT for $file: recipe=$want upstream=$upstream" >&2
    return 1
  fi
  echo "cross_check_sums: pin matches upstream's published checksum for $file" >&2
}

# download_tfs DESTDIR REPO RELEASE TRIPLET EXPECTED_SHA256
# Downloads tfs-<version>-<infix>[.exe] from the tamatebako/tebako
# release as tfs[.exe]. The recipe pin (tools.sha256.<infix>) is the
# trust anchor AND is cross-checked against the release's own SHA256SUMS
# (both anchored — the same rule the workflow pin checks follow).
download_tfs() {
  local destdir="$1" repo="$2" release="$3" triplet="$4" want="$5"
  local infix asset base sums got exe
  infix="$(asset_infix "$triplet")"
  exe=""; case "$triplet" in *-windows-ucrt) exe=".exe" ;; esac
  asset="tfs-${release#v}-${infix}${exe}"
  base="https://github.com/${repo}/releases/download/${release}"
  sums="${destdir}/SHA256SUMS.${release}"
  mkdir -p "$destdir"
  if [ ! -f "$sums" ]; then
    fetch "${base}/SHA256SUMS" "$sums"
  fi
  got="$(awk -v a="$asset" '$2 == a {print $1}' "$sums")"
  if [ "$got" != "$want" ]; then
    echo "download_tfs: pin mismatch for $asset: recipe=$want release=${got:-ABSENT}" >&2
    return 1
  fi
  fetch_verified "${base}/${asset}" "$want" "${destdir}/tfs${exe}"
  chmod +x "${destdir}/tfs${exe}"
}
