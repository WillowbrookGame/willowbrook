param(
  [Parameter(Mandatory)][string] $Godot,
  [Parameter(Mandatory)][string] $Out,
  [string] $Revision = 'HEAD'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$godotExe = (Resolve-Path -LiteralPath $Godot).Path
$outFile = [IO.Path]::GetFullPath($Out)
if (!$outFile.EndsWith('.tar.gz', [StringComparison]::OrdinalIgnoreCase)) { throw 'Use a .tar.gz output filename.' }
if ((Test-Path -LiteralPath $outFile) -or $outFile.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Choose a new output file outside the checkout.' }
if (!(Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($outFile)) -PathType Container)) { throw 'Create the output parent directory first.' }
$sha = & git -C $repo rev-parse --verify --end-of-options "$Revision^{commit}"
if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[a-f0-9]{40}$') { throw 'Choose an existing Git commit.' }
$original = & git -C $repo ls-tree -r --full-tree $sha
if ($LASTEXITCODE -ne 0 -or !$original.Count -or ($original | Where-Object {$_ -notmatch '^100(644|755) blob [0-9a-f]+\t[^"\\\x00-\x1f]+$'})) {
  throw 'Release source must contain only regular files with safe names.'
}
$tempRoot = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
$stage = Join-Path $tempRoot ('willowbrook-release-' + [Guid]::NewGuid().ToString('N'))
$release = Join-Path $stage 'willowbrook'
$utf8 = [Text.UTF8Encoding]::new($false)
$lf = [string][char]10
$packed = Join-Path $stage 'release.tar.gz'
New-Item -ItemType Directory -Path $release | Out-Null
try {
  $sourceArchive = Join-Path $stage 'source.tar'
  & git -C $repo archive --format=tar "--output=$sourceArchive" $sha
  if ($LASTEXITCODE -ne 0) { throw 'Git archive failed.' }
  & tar -xf $sourceArchive -C $release
  if ($LASTEXITCODE -ne 0) { throw 'Unpacking Git archive failed.' }
  $export = Join-Path $stage 'web-export'
  foreach ($required in @('LICENSE','LICENSING.md','Dockerfile','compose.yaml','compose.https-lan.yaml','deploy/DOCKER.md')) {
    if (!(Test-Path -LiteralPath (Join-Path $release $required) -PathType Leaf)) { throw "Commit is missing $required." }
  }
  & (Join-Path $release 'browser-preview/build-account.ps1') -Godot $godotExe -Out $export
  if ($LASTEXITCODE -ne 0) { throw 'Browser export failed.' }
  foreach ($required in @('index.html','index.pck','index.wasm','LICENSE','LICENSING.md','THIRD_PARTY_ART.md','THIRD_PARTY_BEACH_AUDIO.md','THIRD_PARTY_SCUBA_AUDIO.md','GODOT-NOTICES.txt','web-arcade/vendor/air-hockey/LICENSE.txt','web-arcade/vendor/air-hockey/SOURCE.txt')) {
    if (!(Test-Path -LiteralPath (Join-Path $export $required) -PathType Leaf)) { throw "Web export is missing $required." }
  }
  foreach ($held in @('arcade-survivors-template.js','arcade-survivors-template.css','arcade-cosmic-breakout.js','assets/arcade-survivors','assets/cosmic-breakout')) {
    if (Test-Path -LiteralPath (Join-Path $export ('web-arcade/' + $held))) { throw "Excluded arcade content present: $held" }
  }
  Move-Item -LiteralPath $export -Destination (Join-Path $release 'web-export')
  [IO.File]::WriteAllText((Join-Path $release 'BUILD-REVISION'),$sha+$lf,$utf8)
  $rows = @(Get-ChildItem -LiteralPath $release -Force -File -Recurse | Sort-Object FullName | ForEach-Object {
    $rel=[IO.Path]::GetRelativePath($release,$_.FullName).Replace([char]92,[char]47)
    if ($rel -match '[\x00-\x1f\\]' -or $rel -match '(^|/)(\.git|\.env|node_modules)(/|$)' -or $rel -match '\.(pem|key|p12|log|sqlite3?)$') { throw "Unexpected release member: $rel" }
    $hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $rel"
  })
  [IO.File]::WriteAllText((Join-Path $release 'SHA256SUMS'),[string]::Join($lf,$rows)+$lf,$utf8)
  & tar -czf $packed -C $stage willowbrook
  if ($LASTEXITCODE -ne 0) { throw 'Packing release failed.' }
  [IO.File]::Copy($packed,$outFile,$false)
  Get-FileHash -LiteralPath $outFile -Algorithm SHA256
  Write-Output "Source revision: $sha; manifest files: $($rows.Count)"
} finally {
  $resolved = (Resolve-Path -LiteralPath $stage).Path
  if ([IO.Path]::GetDirectoryName($resolved) -eq $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) -and [IO.Path]::GetFileName($resolved) -match '^willowbrook-release-[a-f0-9]{32}$') {
    Remove-Item -LiteralPath $resolved -Recurse -Force
  } else {
    Write-Warning 'Temporary directory path did not match the expected staging pattern and was left untouched.'
  }
}
