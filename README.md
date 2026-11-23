# Willowbrook

Willowbrook is a browser game families can host for their own players. This
repository does not include any server accounts, credentials, or saves.

## Build the browser files on Windows

PowerShell is used in these build instructions, not to run the server. A host
using an existing web export does not need PowerShell, Godot, or export templates.

Prerequisites for this Windows build: standard Godot 4.7.2, the matching Web
export templates, and PowerShell 7. From the project root:

```powershell
$godot = Read-Host 'Full path to the Godot 4.7.2 console executable'
$export = Join-Path $env:TEMP ('willowbrook-web-' + [Guid]::NewGuid().ToString('N'))
& ./browser-preview/build-account.ps1 -Godot $godot -Out $export
```

Use an empty output directory outside the project.

## Run a local preview on Linux or Windows

With Node.js 24, run the command below from the repository root. Replace
`/path/to/web-export` with the export directory from the same revision as the
server source (`$export` in the Windows example).

```sh
node ./paintball_prototype/network/browser/server.mjs --web-root "/path/to/web-export" --port 24862
```

Open **http://127.0.0.1:24862/** on the server itself. This is a loopback-only
preview, not a LAN or internet deployment. No accounts directory is supplied, so
it does not reuse existing player accounts. Stop the preview with Ctrl+C.

For account and Parent Desk tests, use a fresh disposable accounts directory
and the explicit Parent Desk opt-in. Never run tests against the live server.

## Host a game on Linux with Docker

Use the [household hosting guide](deploy/DOCKER.md) to run the prebuilt game,
create the first parent account, or enable private HTTPS for other devices.
You do not need Godot or PowerShell to run the Docker package.

## Arcade and assets

The browser build does not require a separate Three.js project or privately
downloaded arcade packs. It excludes two arcade templates whose public-source
terms are unresolved. Willowbrook's original code is [MIT licensed](LICENSE).
Bundled art, audio, the engine, and other third-party software keep their own
terms. See [Licensing](LICENSING.md) before changing what ships.

## Ideas and contributions

See the [roadmap](ROADMAP.md) for proposed features and community plans,
and [contributing](CONTRIBUTING.md) for proposing an idea or opening a pull request.
