#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
if [[ $# != 2 ]]; then
  echo 'Usage: assemble-linux-release.sh STAGED_WILLOWBROOK_DIR NEW_ARCHIVE.tar.gz' >&2
  exit 2
fi
src=$(realpath -e -- "$1")
base=$(realpath -e -- "$(dirname -- "$2")")
out="$base/$(basename -- "$2")"
[[ $(basename -- "$src") == willowbrook && $out == *.tar.gz && $out != "$src"/* && ! -e $out && ! -L $out ]]
[[ -f $src/BUILD-REVISION && -f $src/SHA256SUMS && -f $src/paintball-runtime/WORKER-SHA256SUMS ]]
cmp -- "$src/BUILD-REVISION" "$src/paintball-runtime/BUILD-REVISION"
(cd "$src" && sha256sum --quiet -c SHA256SUMS)
(cd "$src/paintball-runtime" && sha256sum --quiet -c WORKER-SHA256SUMS)
if find "$src" \( ! -type f -a ! -type d \) -print -quit | grep -q .; then
  echo 'Unexpected link or special file in release' >&2
  exit 1
fi
# Staged source contains no live data. Rebuild the top-level manifest to cover
# the same-revision Godot worker as well as source and prebuilt browser files.
stage=$(mktemp -d -- "$base/.willowbrook-package.XXXXXXXX")
cleanup() { if [[ $stage == "$base"/.willowbrook-package.* && -d $stage && ! -L $stage ]]; then rm -rf -- "$stage"; fi; }
trap cleanup EXIT
(cd "$src" && find . -type f ! -path ./SHA256SUMS -print0 | sort -z | xargs -0 sha256sum) > "$stage/manifest"
install -m 0644 -- "$stage/manifest" "$src/SHA256SUMS"
(cd "$src" && sha256sum --quiet -c SHA256SUMS)
tar --sort=name --owner=0 --group=0 --numeric-owner -czf "$stage/release.tar.gz" -C "$(dirname -- "$src")" willowbrook
mv -T --no-clobber -- "$stage/release.tar.gz" "$out"
test ! -e "$stage/release.tar.gz"
sha256sum -- "$out"
