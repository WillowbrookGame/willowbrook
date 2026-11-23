# Willowbrook release candidate

This local candidate is not cleared for publication. It does not contain or use the family server's accounts, credentials, or saves. Do not point it at an existing family server state directory.

## Run a fresh local preview

Prerequisites for the tested Windows workflow: standard Godot 4.7.2, the matching Web export templates, PowerShell 7 and Node.js 24. In a PowerShell window at the project root:

```powershell
$godot = Read-Host 'Full path to the Godot 4.7.2 console executable'
$export = Join-Path $env:TEMP ('willowbrook-web-' + [Guid]::NewGuid().ToString('N'))
& ./browser-preview/build-account.ps1 -Godot $godot -Out $export

node ./paintball_prototype/network/browser/server.mjs --web-root $export --port 24862
```

Open **http://127.0.0.1:24862/**. This is a loopback-only preview. No accounts directory is supplied, so it does not reuse existing player accounts. Stop the preview with Ctrl+C. Keep the build output outside the project and start with an empty directory. The default commands do not need a separate Three.js project or a privately downloaded arcade pack.

For account and Parent Desk tests, use a fresh disposable accounts directory and the explicit Parent Desk opt-in. Never run tests against the live server. No private legacy build option is needed.

## Arcade and assets

The standalone browser package does not include the two arcade templates whose public-source terms are unresolved. See the arcade source notices and [the draft art inventory](THIRD_PARTY_ART.md) before changing what ships. Engine and engine-dependency notices are generated into each fresh web export. A release still needs final clearance for the exact files included and verification of the packaged files.

## Ideas and contributions

See the [roadmap](ROADMAP.md) for proposed features and community plans, and [contributing](CONTRIBUTING.md) for proposing an idea or opening a pull request.
