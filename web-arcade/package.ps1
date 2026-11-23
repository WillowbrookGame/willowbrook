param(
  [Parameter(Mandatory=$true)][string]$PreviewRoot
)
$ErrorActionPreference = 'Stop'
$publicSource = Join-Path $PSScriptRoot 'vendor-src'
$dest = Join-Path $PreviewRoot 'web-arcade'
$heldFiles = @('arcade-survivors-template.js','arcade-survivors-template.css','arcade-cosmic-breakout.js')
$heldAssets = @('arcade-survivors','cosmic-breakout')
foreach ($name in ($heldFiles + @($heldAssets | ForEach-Object { "assets/$_" }))) {
  if (Test-Path -LiteralPath (Join-Path $dest $name)) { throw 'Output contains excluded arcade files. Use a fresh Web export directory.' }
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null
foreach($name in 'shell.js','index.html','page.js','local-hoops.js') {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $dest $name)
}
$modules = @(
  'arcade-ui.js','arcade-cabinets.js','arcade-solo.js','memory-card-art.js',
  'arcade-codepen-claw.js','arcade-road-template.js','arcade-road-template.css',
  'arcade-blastemoids.js','arcade-template-runtime.js',
  'upstream-hockey-client.js','hoops-view.js','hoops-simulation.js','request-id.js'
)
foreach($name in $modules) {
  Copy-Item -LiteralPath (Join-Path $publicSource $name) -Destination $dest
}
foreach($dir in 'assets','vendor') {
  New-Item -ItemType Directory -Path (Join-Path $dest $dir) -Force | Out-Null
}
$assetSets = @('arcade-memory','arcade-road-template','blastemoids','codepen-claw')
foreach($name in $assetSets) {
  Copy-Item -LiteralPath (Join-Path $publicSource "assets\$name") -Destination (Join-Path $dest 'assets') -Recurse -Force
}
foreach($name in 'air-hockey','hoops88','three.module.js','three.core.js','THREE-LICENSE.txt') {
  Copy-Item -LiteralPath (Join-Path $publicSource "vendor\$name") -Destination (Join-Path $dest 'vendor') -Recurse -Force
}

$unavailable = '["survivors","brick-breaker"]'
[IO.File]::WriteAllText((Join-Path $dest 'available-games.js'), "export const unavailableCabinets = Object.freeze($unavailable);" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
