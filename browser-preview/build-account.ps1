param(
 [Parameter(Mandatory=$true)][string] $Godot,
 [Parameter(Mandatory=$true)][string] $Out
)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$exe=(Resolve-Path -LiteralPath $Godot).Path
$output=[IO.Path]::GetFullPath($Out)
if($output -eq $project -or $output.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Export to a directory outside the canonical project.'}
$stage=Join-Path ([IO.Path]::GetTempPath()) ('willowbrook-export-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage|Out-Null
foreach($node in @('project.godot','export_presets.cfg','LICENSE','LICENSING.md','THIRD_PARTY_ART.md','game','web-arcade','browser-preview')){
 Copy-Item -LiteralPath (Join-Path $project $node) -Destination $stage -Recurse
}
$file=Join-Path $stage 'project.godot'
$text=[IO.File]::ReadAllText($file)
$text=[regex]::Replace($text,'(?ms)^\[editor_plugins\]\s*.*?(?=^\[|\z)','')
$text=[regex]::Replace($text,'(?m)^[^\r\n]*addons/godot_ai/runtime/game_helper\.gd[^\r\n]*\r?\n','')
if($text -match 'addons/godot_ai/'){throw 'Unexpected editor-addon reference remains in stage; no web export generated.'}
if(Test-Path (Join-Path $stage "browser-preview/loading-shell.html")){
 $text=$text.Replace("[application]",("[application]"+[Environment]::NewLine+"boot_splash/show_image=false"))
}
[IO.File]::WriteAllText($file,$text,[Text.UTF8Encoding]::new($false))
& $exe --headless --path $stage --import
if($LASTEXITCODE){throw "Godot import failed from $stage."}
$buildArgs=@{Godot=$exe;Out=$output}
& (Join-Path $stage 'browser-preview\build.ps1') @buildArgs
if($LASTEXITCODE){exit $LASTEXITCODE}
Write-Output "Isolated browser export source: $stage (canonical editor project untouched)"