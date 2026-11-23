#!/bin/bash
# SPDX-License-Identifier: MIT
set -euo pipefail
if [[ $# != 3 || $(uname -m) != x86_64 ]]; then
  echo 'Usage on x86-64 Linux: build-paintball-runtime.sh RELEASE_ROOT OFFICIAL_GODOT_ZIP NEW_RUNTIME_DIR' >&2
  exit 2
fi
src=$(realpath -e -- "$1")
archive=$(realpath -e -- "$2")
parent=$(realpath -e -- "$(dirname -- "$3")")
out="$parent/$(basename -- "$3")"
[[ ! -e $out && ! -L $out && -f $src/BUILD-REVISION && -f $src/SHA256SUMS ]]
revision=$(cat -- "$src/BUILD-REVISION")
[[ $revision =~ ^[0-9a-f]{40}$ ]]
(cd "$src" && sha256sum --quiet -c SHA256SUMS)
engine=Godot_v4.7.2-stable_linux.x86_64
digest=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
[[ $(sha256sum < "$archive") == "$digest  -" ]]
[[ $(unzip -Z1 "$archive") == "$engine" ]]
stage=$(mktemp -d -- "$parent/.willowbrook-worker.XXXXXXXX")
cleanup() { if [[ $stage == "$parent"/.willowbrook-worker.* && -d $stage && ! -L $stage ]]; then rm -rf -- "$stage"; fi; }
trap cleanup EXIT
mkdir -p "$stage/runtime/project/browser-preview"
work="$stage/runtime"
unzip -p "$archive" "$engine" > "$work/$engine"
install -m 0755 -- "$src/deploy/godot-paintball-stdio" "$work/godot-paintball-stdio"
chmod 0755 "$work/$engine"
cp -a -- "$src/paintball_prototype" "$work/project/"
cp -- "$src/project.godot" "$work/project/"
cp -- "$src/browser-preview/"{willowbrook-favicon.svg,write-engine-notices.gd} "$work/project/browser-preview/"
cp -- "$src/"{LICENSE,LICENSING.md,THIRD_PARTY_ART.md,BUILD-REVISION} "$work/"
cat > "$work/GODOT-SOURCE.txt" <<'NOTICES'
Godot Engine 4.7.2-stable Linux x86-64 official binary.
https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable
https://github.com/godotengine/godot/tree/4.7.2-stable
See GODOT-NOTICES.txt for the engine license and bundled third-party notices.
NOTICES
# This is a release-engineering step, never required for running a prebuilt bundle.
# Mount only the generated tree; import without network access or Docker privileges.
chown -R 1000:1000 -- "$work"
docker run --rm --network none --read-only --cap-drop ALL \
  --security-opt no-new-privileges --user 1000:1000 \
  --tmpfs /tmp:rw,nosuid,nodev,mode=1777,size=256m \
  -e HOME=/tmp -e XDG_DATA_HOME=/tmp/data -e XDG_CONFIG_HOME=/tmp/config -e XDG_CACHE_HOME=/tmp/cache \
  --mount "type=bind,src=$work,dst=/worker" --entrypoint /bin/bash \
  node:24-bookworm-slim -euc '
    exe=/worker/Godot_v4.7.2-stable_linux.x86_64
    timeout 120 "$exe" --headless --path /worker/project --editor --import --quit > /tmp/import.log 2>&1 || { tail -30 /tmp/import.log; exit 1; }
    if grep -E "SCRIPT ERROR|ERROR: Failed to (load|import)" /tmp/import.log; then exit 1; fi
    timeout 25 "$exe" --headless --path /worker/project --script res://browser-preview/write-engine-notices.gd -- /worker/GODOT-NOTICES.txt
    test -s /worker/GODOT-NOTICES.txt
    test -s /worker/project/.godot/global_script_class_cache.cfg
  '
if [[ -d $work/project/.godot/editor ]]; then
  find "$work/project/.godot/editor" -depth -delete
fi
chown -R 0:0 -- "$work"
chmod -R go-w -- "$work"
(cd "$work" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$stage/manifest"
mv -- "$stage/manifest" "$work/WORKER-SHA256SUMS"
(cd "$work" && sha256sum --quiet -c WORKER-SHA256SUMS)
mv -T -- "$work" "$out"
printf 'Prepared verified Linux worker for revision %s\n' "$revision"
