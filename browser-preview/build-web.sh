#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: ./browser-preview/build-web.sh GODOT NEW_OUTPUT_DIRECTORY' \
    'Use standard Godot 4.7.2 with matching export templates. The output directory must be new and outside the checkout.' >&2
}
die() { printf 'Willowbrook web build: %s\n' "$*" >&2; exit 1; }
if [[ ${1:-} == --help && $# == 1 ]]; then usage; exit 0; fi
if [[ $# != 2 ]]; then usage; exit 2; fi

project=$(realpath -e -- "$(dirname -- "${BASH_SOURCE[0]}")/..")
godot=$(command -v -- "$1") || die "Godot executable not found: $1"
godot=$(realpath -e -- "$godot")
[[ -x $godot && -f $godot ]] || die 'Godot must be an executable file.'
version=$("$godot" --version) || die 'Could not read the Godot version.'
[[ $version =~ ^4\.7\.2\.stable\.official\.[[:xdigit:]]+$ ]] ||
  die "Expected standard official Godot 4.7.2 stable, found: $version"
templates=${XDG_DATA_HOME:-"${HOME:?}/.local/share"}/godot/export_templates/4.7.2.stable
for template in web_nothreads_debug.zip web_nothreads_release.zip; do
  [[ -s $templates/$template ]] ||
    die "Missing Godot 4.7.2 Web template at $templates/$template. Install the matching standard export templates and retry."
done

[[ -n $2 ]] || die 'The output directory cannot be empty.'
# Resolve the parent, but never follow or replace an existing output entry.
target=${2%/}
parent=$(realpath -e -- "$(dirname -- "$target")") || die 'The output parent directory must already exist.'
[[ -d $parent ]] || die 'The output parent must be a directory.'
out="$parent/$(basename -- "$target")"
[[ $out != "$project" && $out != "$project/"* ]] || die 'Choose an output directory outside the checkout.'
[[ ! -e $out && ! -L $out ]] || die "Output already exists: $out"
[[ $(git -C "$project" rev-parse --show-toplevel) == "$project" ]] ||
  die 'Run this script from the Willowbrook Git checkout.'

stage=$(mktemp -d -- "${TMPDIR:-/tmp}/willowbrook-web-src.XXXXXXXX")
web=''
cleanup() {
  if [[ -n $web ]]; then rm -rf -- "$web"; fi
  rm -rf -- "$stage"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
web=$(mktemp -d -- "$parent/.willowbrook-web.XXXXXXXX")

# Stage working copies of tracked source only, excluding caches, local saves,
# installed workers, and untracked assets. Never import into the checkout.
git -C "$project" ls-files --cached -z -- project.godot export_presets.cfg \
  LICENSE LICENSING.md THIRD_PARTY_ART.md game web-arcade browser-preview > "$stage/tracked"
while IFS= read -r -d '' path; do
  case "$path" in
    game/network/browser/standalone-runtime/*|game/network/browser/standalone-runtime-manifest.json) continue ;;
  esac
  if [[ ! -e $project/$path && ! -L $project/$path ]]; then continue; fi
  [[ -f $project/$path && $(realpath -e -- "$project/$path") == "$project/$path" ]] ||
    die "Tracked source is not a regular in-tree file: $path"
  install -D -m 0644 -- "$project/$path" "$stage/src/$path"
done < "$stage/tracked"
source="$stage/src"
[[ -s $source/project.godot && -s $source/export_presets.cfg ]] || die 'Incomplete project source.'
if grep -Fq 'addons/godot_ai/' "$source/project.godot"; then
  die 'The staged public project refers to an unavailable editor addon.'
fi
# The browser shell owns the loading artwork. Set this once in the staged project.
sed -e '/^[[:space:]]*boot_splash\/show_image[[:space:]]*=/d' \
  -e '/^\[application\][[:space:]]*$/a boot_splash/show_image=false' \
  "$source/project.godot" > "$stage/project.godot"
mv -- "$stage/project.godot" "$source/project.godot"

run_godot() {
  local step=$1
  shift
  if ! "$godot" --headless --path "$source" "$@" > "$stage/godot.log" 2>&1 ||
    grep -Eq 'SCRIPT ERROR|ERROR: Failed to (load|import)|ERROR: Cannot export' "$stage/godot.log"; then
    tail -n 60 "$stage/godot.log" >&2
    die "Godot $step failed. Confirm the engine and templates are both 4.7.2 stable."
  fi
}

printf 'Importing Willowbrook with Godot %s...\n' "$version"
run_godot import --import
printf 'Exporting Web Preview...\n'
run_godot export --export-release 'Web Preview' "$web/index.html"
for artifact in index.html index.js index.pck index.wasm; do
  [[ -s $web/$artifact ]] || die "Godot did not write $artifact."
done

# Match the existing Windows browser shell, licenses and public Arcade allowlist.
preview="$source/browser-preview"
grep -Fq 'href="./willowbrook-favicon.svg"' "$web/index.html" ||
  die 'Loading shell is missing its Willowbrook icon.'
sed -i 's|<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />||' "$web/index.html"
cp -- "$preview/"{willowbrook-favicon.svg,loading.webp,parent.html,family-desk.css,family-desk.js,neighbor-quests.css,neighbor-quests.js,activity-launchers.css,activity-launchers.js,hide-seek.css,hide-seek.js} "$web/"
cp -R -- "$preview/avatar-thumbs" "$web/"
arcade="$web/web-arcade"
vendor="$source/web-arcade/vendor-src"
mkdir -p -- "$arcade/assets" "$arcade/vendor"
cp -- "$source/web-arcade/"{shell.js,index.html,page.js,local-hoops.js} "$arcade/"
cp -- "$vendor/"{arcade-ui.js,arcade-cabinets.js,arcade-solo.js,memory-card-art.js,arcade-codepen-claw.js,arcade-road-template.js,arcade-road-template.css,arcade-blastemoids.js,arcade-template-runtime.js,upstream-hockey-client.js,hoops-view.js,hoops-simulation.js,request-id.js} "$arcade/"
cp -R -- "$vendor/assets/"{arcade-memory,arcade-road-template,blastemoids,codepen-claw} "$arcade/assets/"
cp -R -- "$vendor/vendor/"{air-hockey,hoops88,three.module.js,three.core.js,THREE-LICENSE.txt} "$arcade/vendor/"
printf '%s\n' 'export const unavailableCabinets = Object.freeze(["survivors","brick-breaker"]);' > "$arcade/available-games.js"

run_godot notices --script res://browser-preview/write-engine-notices.gd -- "$web/GODOT-NOTICES.txt"
[[ -s $web/GODOT-NOTICES.txt ]] || die 'Godot license and third-party notices were not written.'
cp -- "$source/"{LICENSE,LICENSING.md,THIRD_PARTY_ART.md} "$web/"
cp -- "$source/game/beach_audio/SOURCES.md" "$web/THIRD_PARTY_BEACH_AUDIO.md"
cp -- "$source/game/scuba/audio/SOURCES.md" "$web/THIRD_PARTY_SCUBA_AUDIO.md"

# Publish only a completed export and never overwrite an existing path.
chmod 0755 -- "$web"
mv -nT -- "$web" "$out"
[[ ! -e $web ]] || die "Output appeared while building: $out"
web=''
printf 'Preview export: %s\nSee the repository README for the local server command.\n' "$out"
