# Contributing to Willowbrook

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

Open a pull request that links the issue. Describe what changed and how you verified it. Use a fresh local game and made-up players, never a live or family server. For changes to controls or UI, say what you tested on keyboard, touch, and controller; be clear about anything you could not test. For assets, include the creator, exact source, license, and modifications. Do not add asset packs that cannot be redistributed.

Maintainers review, run the relevant checks, and verify the finished behavior. Only then check off the roadmap item after merge and link the PR. We deploy separately; please do not assume a merge will publish or deploy anything.

Issues and pull requests are public. Do not include children's names, account details, chat, save files, tokens, or private URLs. Redact screenshots and use disposable test data.
