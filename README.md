# Willowbrook

Willowbrook is a browser game families can host for their own players. This
repository does not include any server accounts, credentials, or saves.

## Quick start: host the prebuilt game on Linux

**No PowerShell, Godot, or Node.js installation is needed on the host.**
Use a 64-bit Intel or AMD Linux machine with Docker Engine and Docker Compose.

1. Download the [Linux Docker bundle from Early Alpha 1](https://github.com/WillowbrookGame/willowbrook/releases/tag/v0.1.0-alpha.1). Choose `willowbrook-linux-x86_64-preview.tar.gz` under **Assets**, not the automatically generated Source code archives.
2. Extract it to a fresh directory and open a terminal in the extracted `willowbrook/` folder. Run `sha256sum -c SHA256SUMS` before starting.
3. Follow the [first-start instructions](deploy/DOCKER.md#first-start) to create your owner account, start Willowbrook, and invite players from Parent Desk.

Players only need a web browser. The default setup is reachable only on the
Linux host. To play on other devices in your household, follow the
[private LAN HTTPS instructions](deploy/DOCKER.md#optional-private-lan-https-for-a-second-device).

## Developer setup

The following steps are for building and testing changes from source. Skip
them if you're using the release bundle above.

### Build the browser files on Windows

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

### Run a local preview on Linux or Windows

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

## Arcade and assets

The browser build does not require a separate Three.js project or privately
downloaded arcade packs. It excludes two arcade templates whose public-source
terms are unresolved. Willowbrook's original code is [MIT licensed](LICENSE).
Bundled art, audio, the engine, and other third-party software keep their own
terms. See [Licensing](LICENSING.md) before changing what ships.

## Ideas and contributions

See the [roadmap](ROADMAP.md) for proposed features and community plans,
and [contributing](CONTRIBUTING.md) for proposing an idea or opening a pull request.
