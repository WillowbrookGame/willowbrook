# Willowbrook Art & Asset Guide

Help make Willowbrook a brighter, cozier place for kids and families to play. **No Git or Godot experience is needed.** If you make 3D models, icons, or sound effects, start with an issue and a preview. A maintainer can help with import and placement after review.

## Start here

Pick one small asset or pitch an idea in a [GitHub issue](https://github.com/WillowbrookGame/willowbrook/issues/new/choose). For a larger project, show a sketch or rough model first so we can agree on scale, style, and what the game needs.

- **Town:** A flower planter, notice board, bench, or lamppost.
- **Homes:** A bedside lamp, bookshelf, rug, or simple wall decoration.
- **Beach:** A bait bucket, rod rack, umbrella, or small stylized fish.
- **Arcade:** A cabinet shell, stool, or prize-counter prop. Use original names and graphics.
- **Audio:** A soft menu click, a fishing splash, or a gentle beach ambience loop.

These are ideas, not assignments. Check the [roadmap](ROADMAP.md) and open issues before starting a bigger piece.

## The Willowbrook look

Think sunny, colorful, and cozy. Use chunky silhouettes that are easy to recognize from the third-person camera, even on a tablet. Start with a few clear shapes and cheerful colors: sky blue, grassy green, warm red, soft wood, and cream. Save small details for close-up objects. Avoid gritty realism and busy textures.

| Reference | What to look for |
| --- | --- |
| [Town Square](https://willowbrookgame.com/media/card-town.webp) | Sunny palette, clear silhouettes, and how props read at normal camera distance. |
| [Arcade and Air Hockey table](https://willowbrookgame.com/media/card-arcade.webp) | A prop that reads through its big shapes and a few strong colors. |
| [Willowbrook avatar](https://willowbrookgame.com/media/avatar-female-b.webp) | Friendly proportions and a face that's easy to read. This is a style reference, not a rig template. |

These are previews from the public project site. Use a local test world and made-up players for your own screenshots.

## 3D models

- **Export:** Use a binary glTF file (`.glb`). Keep the `.blend` file if you can share editable source. Use meter scale and include the intended dimensions in your submission. Apply object rotation and scale before exporting ordinary props.
- **Facing:** For a prop or character with a front, face `-Y` in Blender before export. The resulting glTF/Godot model is `+Y` up and faces `+Z`. The camera's forward direction is different. Include a front-view screenshot, especially for vehicles, cabinets, fish, and characters. [Godot's model export guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html)
- **Pivot:** For a freestanding item, put the origin at the bottom center where it rests on the floor or tabletop. For something that moves around a hinge, axle, or other attachment point, use that point or tell us where it belongs.
- **Materials:** Prefer flat colors, vertex colors, or a small shared palette texture. Aim for 1–3 materials per ordinary prop. Avoid large textures and extra maps unless the asset needs them.
- **Collision:** You don't need to make colliders. Flag any parts players are meant to stand on, sit on, walk through, or interact with.

### Starting triangle budgets

| Asset | Suggested triangles |
| --- | ---: |
| Small prop, fish, or tabletop item | 100–800 |
| Furniture, cabinet, bench, or small boat | 500–2,000 |
| Building or large landmark | 1,500–4,000 |
| Character or outfit | 1,000–2,500 |

These are starting points, not pass/fail limits. A dozen copies of the same prop can cost more than one landmark; material count, transparency, and texture size matter too. Maintainers check how the asset looks and performs in the browser before shipping it.

## 2D art and audio

- **Icons and UI:** PNG or SVG. Use a transparent background when appropriate and check that the shape reads at its actual size in the game. A 128 px or 256 px square is a good starting point for an icon, not a requirement for every UI asset.
- **Sound effects and ambience:** Prefer Ogg Vorbis (`.ogg`). Trim dead space from short effects. For ambience, test the loop boundary so it doesn't click or jump. Keep sounds gentle and leave room for other game audio.

## Character rig upgrade (proposed)

We want characters and NPCs to sit, wave, hold tools, fish, and eventually kick naturally while swimming. We're not asking contributors to build a full avatar set against an untested rig.

The first milestone is **one base character and one reusable animation** that we can import and test in Godot and the browser. The proposed rig has a shared humanoid skeleton with articulated elbows, knees, and ankles; a clean A- or T-pose to agree on before modeling; no more than four bone influences per vertex as a starting target; and a hand attachment point for tools. We'll confirm the scale, bone map, rest pose, and attachment conventions with a reference rig before building outfits or animation packs.

Keep the cute, chunky, toy-like proportions shown in the avatar reference rather than realistic adult proportions.

## Licensing and credit

For original contributions, we prefer [CC0](https://creativecommons.org/publicdomain/zero/1.0/) or [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Submit only work you have the right to share. If you want to adapt someone else's work, ask in an issue first and include the exact source, creator, license, and proposed changes. Buying or downloading a pack doesn't by itself give us permission to bundle it. Don't assume the game's MIT code license covers art or audio.

Include your preferred public credit name and, optionally, a portfolio link. We'll keep the creator, license, required credit, and modifications with the relevant project notices. See [Licensing](LICENSING.md) and [Third-Party Art](THIRD_PARTY_ART.md).

## How to submit

1. Open or find an issue for the asset. Tell us what it is and where you see it fitting in Willowbrook.
2. Add a screenshot or render and a ZIP with the export (`.glb`, PNG/SVG, or OGG). Include editable source if you'd like and have permission to share it. ZIP is the easiest way to send formats GitHub doesn't accept individually. [GitHub's attachment guide](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/attaching-files)
3. Include the creator, source (say “original” if it's yours), license, changes to any source assets, and how you'd like to be credited.
4. Keep the issue public-safe: no children's names, chat, saves, credentials, or private family server URLs. See the [Code of Conduct](CODE_OF_CONDUCT.md).

If you prefer to open a PR, start with [Contributing](CONTRIBUTING.md). You don't need to integrate the asset yourself to suggest it.
