# Contributing to Willowbrook

## Quick start for contributors

Clone the public repository, then open it in the standard [Godot 4.7.2 editor](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
You don't need Docker, a browser export, or an account to try native gameplay.

```sh
git clone https://github.com/WillowbrookGame/willowbrook.git
cd willowbrook
```

1. In Godot's Project Manager, choose **Import** and select `project.godot` at the
   root of that clone. Open the project and let the first asset import finish.
2. Press **F5** (**Run Project**). You should spawn in Town. Try walking with
   **WASD** and entering a building with **E** when prompted.
3. For scenery edits, open [Town scenery](game/town_scenery.tscn), not an
   imported model file. The [Town editing guide](game/TOWN_EDITING.md) walks
   through the driveway tree, its collision, and other useful checks. Fixed
   placements are editable; NPCs, vehicles, save-driven dÃ©cor and gameplay
   are still created or managed at runtime.

F5 is for native play. Browser sign-in and invites, Parent Desk, online
multiplayer and browser-specific arcade behavior need the
[local browser preview](README.md#run-a-local-preview-on-linux-or-windows).
If you already play Willowbrook in Godot, use a separate OS user profile for
manual testing; a different clone alone does not isolate Godot's local saves.

### Run the first checks

Run these from the repository root. Use the Godot 4.7.2 executable in place of
`godot` if it is not on your PATH (the console executable on Windows).
Open/import the project once before running the two Godot checks.

```sh
godot --headless --path . --script res://game/test_town_editor.gd
godot --headless --path . --script res://game/test_town_layout.gd
node game/network/browser/test-standalone-runtime.mjs
```

Use **Node.js 24** for the browser tests. The last command is the same smoke
test used by PR checks, prints `PASS filesystem-isolated relocated standalone
closure...`, and needs no dependency install or browser export. It uses
made-up accounts and a disposable local port.

For bank or account-restoration changes, run the checks below. The argument
is a directory of runtime **code**, not a save directory. Both use disposable
accounts and print `PASS` on success.

```sh
node game/network/browser/test_bank_progress_preview.mjs game/network/browser/standalone-runtime
node game/network/browser/test_b2_combined_restore.mjs game/network/browser/standalone-runtime
```

Not every `test_*.mjs` is a clean-clone smoke test. In particular,
`test-missing-starters.mjs <old-runtime-dir> <fixed-runtime-dir>` compares a
known broken runtime snapshot against a fixed one. Do not pass the current
directory twice or copy any real saves for this comparison.

## Repository map

- [`project.godot`](project.godot) and [`export_presets.cfg`](export_presets.cfg): open the repository root in Godot; the Web export preset lives here too.
- [`game/`](game/): Godot scenes, scripts, and assets for Town, the beach, interiors, activities, and Paintball. Most Godot tests also live alongside the features here.
- [`game/network/browser/`](game/network/browser/): the Node browser server, Parent Desk and game services, and their tests. Godot's network client is in [`game/network/`](game/network/).
- [`browser-preview/`](browser-preview/): browser export tools, loading UI, and preview shell. [`web-arcade/`](web-arcade/) contains the browser arcade games.
- [`deploy/`](deploy/) and the root [Compose files](compose.yaml): Docker hosting, private LAN HTTPS, and the optional multiplayer Paintball worker. Start with the [household hosting guide](deploy/DOCKER.md).


For world changes, start with the scene that owns the area:

- **Town:** [Town scene](game/town.tscn), [editable scenery](game/town_scenery.tscn), [Town editing guide](game/TOWN_EDITING.md), and [Town route coordinates](game/town_routes.gd). The Town scene wires up Town-only progression, home exteriors, and vehicles.
- **Island and scuba:** [Island scene](game/beach.tscn) owns the beach layout and activities. [Ferry crossing](game/ferry_crossing.gd) is shared by the Town and Island docks. The [Dive Shop](game/scuba/shop.tscn) and [reef](game/scuba/reef.tscn) are separate scenes.
- **Interiors:** Each business has a room module; all six starter houses use [one Home scene](game/home/room.tscn) with per-home identity and décor. [Arcade room](game/arcade/room.tscn) and browser cabinets are separate.
- **Paintball:** The [arena scene](game/arena.tscn) and optional worker share the [Warehouse Yard](game/warehouse_yard.tscn). Keep its collision and spawn contract compatible in both modes.

Use the [shared map shell](game/map.gd) for player controls, camera, common HUD, and scene transitions. Keep location-specific resources in the relevant scene, and preserve world/room IDs and save keys when reorganizing a module.

## Proposing changes

Start with the [roadmap](ROADMAP.md). Have a new idea? Open a GitHub issue using **Suggest an idea**. Describe what a player or host would gain. Maintainers can discuss the scope, combine duplicates, and add accepted ideas to the roadmap. A roadmap entry is not a promise or an assignment. For a large change, agree on the scope in the issue before writing code.

If you want to take an existing issue, leave a quick comment before starting so
two people don't duplicate work. Keep the diff focused: don't auto-format or
normalize line endings in untouched code. Agree on scope before making broad
changes to shared scripts like [account_session.gd](game/network/browser/account_session.gd)
or [map.gd](game/map.gd).

Open a pull request that links the issue. Describe what changed and how you verified it. Use a fresh local game and made-up players, never a live or family server. For changes to controls or UI, say what you tested on keyboard, touch, and controller; be clear about anything you could not test. For assets, include the creator, exact source, license, and modifications. Do not add asset packs that cannot be redistributed.

Maintainers review, run the relevant checks, and verify the finished behavior. Only then check off the roadmap item after merge and link the PR. We deploy separately; please do not assume a merge will publish or deploy anything.

Issues and pull requests are public. Do not include children's names, account details, chat, save files, tokens, or private URLs. Redact screenshots and use disposable test data.
