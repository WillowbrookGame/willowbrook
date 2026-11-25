# Willowbrook

**A cozy, invite-only 3D browser town that families host themselves.** Kids can play together on PCs and tablets, with no public lobbies, no ads, and no tracking. The game does not send player data to the Willowbrook project.

> Looking for the family overview? Visit **[willowbrookgame.com](https://willowbrookgame.com)**.
>
> This repository does not contain any server accounts, credentials, or player saves.

<table>
  <tr>
    <td><img src="https://willowbrookgame.com/media/card-town.webp" alt="Willowbrook Town Square" width="100%" /></td>
    <td><img src="https://willowbrookgame.com/media/card-beach.webp" alt="Fishing from the beach pier" width="100%" /></td>
  </tr>
  <tr>
    <td><img src="https://willowbrookgame.com/media/card-arcade.webp" alt="Retro arcade cabinets and an Air Hockey table" width="100%" /></td>
    <td><img src="https://willowbrookgame.com/media/card-play.webp" alt="Warehouse Paintball Arena" width="100%" /></td>
  </tr>
</table>

**[Host Willowbrook](#quick-start-host-the-prebuilt-game-on-linux)** · [See what’s playable](#whats-playable-today-early-alpha) · [Contribute](#ideas-and-contributions)

## What's playable today (Early Alpha)

- **Town & Jobs:** Explore Town, take jobs and library classes, earn Stars, and claim and decorate a home.
- **Beach, Fishing & Scuba:** Cast from the pier, sell your catch at Marina's shop, or go diving offshore.
- **Retro Arcade:** Play solo cabinets or challenge an invited friend to Air Hockey or HOOPS '88.
- **Hide & Seek and Paintball:** Play Hide & Seek around Town or head to the warehouse for solo Paintball. Online Paintball is [optional and needs the matching worker](deploy/DOCKER.md#optional-online-paintball).
- **Parent Desk:** Create one-time invites for your household's players or for other trusted parents. Accounts are managed on your own host.

## Quick start: host the prebuilt game on Linux

**No PowerShell, Godot, or Node.js installation is needed on the host.**
Use a 64-bit Intel or AMD Linux machine with Docker Engine and Docker Compose.

1. Download the [Linux Docker bundle from Early Alpha 1](https://github.com/WillowbrookGame/willowbrook/releases/tag/v0.1.0-alpha.1). Choose `willowbrook-linux-x86_64-preview-docs-r2.tar.gz` under **Assets**, not the automatically generated Source code archives.
2. Extract it to a fresh directory and open a terminal in the extracted `willowbrook/` folder. Run `sha256sum -c SHA256SUMS` before starting.
3. Follow the [first-start instructions](deploy/DOCKER.md#first-start) to create your owner account, start Willowbrook, and invite players from Parent Desk.

Players only need a web browser. The default setup is reachable only on the
Linux host. To play on other devices in your household, follow the
[private LAN HTTPS instructions](deploy/DOCKER.md#optional-private-lan-https-for-a-second-device).

## Developer setup

The following steps are for building and testing changes from source. Skip
them if you're using the release bundle above.

### Build the browser files on Linux

Install Bash, Git, GNU coreutils, the standard **Godot 4.7.2** editor, and
its matching standard export templates, including the Web release template.
Get the editor and template package from the [Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable),
then install the templates in Godot using **Editor → Manage Export Templates**.
No PowerShell is required.

From the root of a Git checkout, use a new output directory outside it:

```sh
export_dir="$(mktemp -d)/web"
./browser-preview/build-web.sh /path/to/Godot_v4.7.2-stable_linux.x86_64 "$export_dir"
```

Use `godot` in place of the executable path if the correct version is on your
`PATH`. The build stages tracked working files (including local edits), so add
new source files to Git before building. No temporary Godot cache is written
inside the checkout. Start the preview with the Node.js command below, using
`"$export_dir"` as the web root.

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
node ./game/network/browser/server.mjs --web-root "/path/to/web-export" --port 24862
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

Willowbrook is in **Early Alpha**. We're looking for contributors to make the game better, easier to host, and ready for more families.

- **Godot 4 / GDScript:** Gameplay polish, browser and tablet performance, and making scenes easier to change and test.
- **Self-hosting:** Help validate the source build on macOS, prebuilt `amd64` and `arm64` container images, or simpler private LAN HTTPS for tablets. These are areas for future work, not requirements for running the current bundle.
- **3D art, animation & audio:** Cozy low-poly props, furniture, fish, gentle sound effects, and a proposed toy-style character rig. No Git experience needed. Start with the [Art & Asset Guide](ART_GUIDE.md).
- **Testing & docs:** Browser and tablet playtesting, and clearer setup instructions for parents.

Start with [Contributing](CONTRIBUTING.md), check the [Roadmap](ROADMAP.md), or [suggest an idea](https://github.com/WillowbrookGame/willowbrook/issues/new/choose). Read the [Code of Conduct](CODE_OF_CONDUCT.md) and report security concerns privately as described in the [Security Policy](SECURITY.md).
