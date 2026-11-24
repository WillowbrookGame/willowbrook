# Contributing to Willowbrook

## Repository map

- [`project.godot`](project.godot) and [`export_presets.cfg`](export_presets.cfg): open the repository root in Godot; the Web export preset lives here too.
- [`game/`](game/): Godot scenes, scripts, and assets for Town, the beach, interiors, activities, and Paintball. Most Godot tests also live alongside the features here.
- [`game/network/browser/`](game/network/browser/): the Node browser server, Parent Desk and game services, and their tests. Godot's network client is in [`game/network/`](game/network/).
- [`browser-preview/`](browser-preview/): browser export tools, loading UI, and preview shell. [`web-arcade/`](web-arcade/) contains the browser arcade games.
- [`deploy/`](deploy/) and the root [Compose files](compose.yaml): Docker hosting, private LAN HTTPS, and the optional multiplayer Paintball worker. Start with the [household hosting guide](deploy/DOCKER.md).

## Proposing changes

Start with the [roadmap](ROADMAP.md). Have a new idea? Open a GitHub issue using **Suggest an idea**. Describe what a player or host would gain. Maintainers can discuss the scope, combine duplicates, and add accepted ideas to the roadmap. A roadmap entry is not a promise or an assignment. For a large change, agree on the scope in the issue before writing code.

Open a pull request that links the issue. Describe what changed and how you verified it. Use a fresh local game and made-up players, never a live or family server. For changes to controls or UI, say what you tested on keyboard, touch, and controller; be clear about anything you could not test. For assets, include the creator, exact source, license, and modifications. Do not add asset packs that cannot be redistributed.

Maintainers review, run the relevant checks, and verify the finished behavior. Only then check off the roadmap item after merge and link the PR. We deploy separately; please do not assume a merge will publish or deploy anything.

Issues and pull requests are public. Do not include children's names, account details, chat, save files, tokens, or private URLs. Redact screenshots and use disposable test data.
