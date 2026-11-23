param(
 [Parameter(Mandatory=$true)][string]$Build,
 [string]$ThreeJs
)
$ErrorActionPreference='Stop'
if(!(Test-Path -LiteralPath (Join-Path $Build 'index.pck'))){throw 'The local Scuba web export was not found.'}
if($ThreeJs -and !(Test-Path -LiteralPath (Join-Path $ThreeJs 'world-store.mjs'))){throw 'The local Willowbrook runtime dependencies were not found.'}
$OutputEncoding = [Text.UTF8Encoding]::new($false)
$a=Read-Host 'Choose a temporary password for scuba_demo (10+ characters)' -AsSecureString
try {
 $data = @{first=([pscredential]::new('scuba_demo',$a)).GetNetworkCredential().Password} | ConvertTo-Json -Compress
 $launchArgs=@($Build)
 if($ThreeJs){$launchArgs+=@($ThreeJs)}
 $data | node (Join-Path $PSScriptRoot 'serve-scuba-demo.mjs') @launchArgs
}finally{
 $a.Dispose()
 Remove-Variable a,data -ErrorAction SilentlyContinue
}
