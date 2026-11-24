# Third-party art notices

**Provenance reviewed 2026-11-23.** This inventory documents the art carried forward from the Scuba R6 project. The original runtime check used the R6-final Web export, whose `index.pck` SHA-256 is `c0e8265a06730a614856e9290e56422fad592d9d4652ab16e6e071faaab753b3`. It does not cover audio, software dependencies, private test data, server configuration, or repository history. Recheck new or changed art against the exact release tree.

## What this means

Willowbrook code and the included art do not have to carry the same license. A code license governs the original code it identifies, not third-party models, textures, rendered derivatives or logos. Keep each credit or restriction with the assets and compiled game it covers. Most of the models below are CC0. The Shuriken Studio art is different: its license permits sharing an integrated game or its project source with the models included, but not offering the models on their own as downloads or repackaging them into an art kit. This is a mixed-license game release, not a CC0 asset collection. A title using only generally redistributable assets would need to substitute for the Shuriken art or obtain additional permission.

## Shuriken Studio model license (not CC0)

[Free Model License, version 2026-11-13](https://shuriken.studio/legal/models). The publisher permits use, modification and sharing as part of a project, expressly including game source; it prohibits standalone or asset-pack redistribution, claiming authorship, and implying endorsement. These files are excluded from the Willowbrook code license. Credits here identify the source even though the linked license does not require credit.

| Included source paths | Publisher source and scope |
| --- | --- |
| `game/warehouse-yard-arena.glb`; `game/town_assets/paintball-warehouse/warehouse-exterior.glb` | [Warehouse Yard Arena](https://shuriken.studio/models/scenery/warehouse-yard-arena), original full arena used by `arena.tscn` and Town-only adapted subset. The original matches the retained publisher download SHA-256 `6381056ded3a10bb42d779fa40302a51b377e82f512a83782f01c37b3c3f627c`. See the subset's `LICENSE-SOURCE.txt`. |
| `game/toy-paintball-marker.glb` | [Toy Paintball Marker](https://shuriken.studio/models/weapons/toy-paintball-marker), original downloaded asset used by `arena_marker.gd`. Download and project file SHA-256 match: `ce470bc8bd8f79c8d11f364d84f009253b719f4eee1c6dd7cd9ccfeb1bbb5a7f`. |
| `game/beach_art/beach-shops/{dive-shop,rental-dock,snack-kiosk,snack-slide}.glb` | Adapted pieces of [Beach & Water Park](https://shuriken.studio/kits/beach-and-water-park). Original kit ZIP and its included license summary retained separately, not in this source release. See `beach-shops/LICENSE.txt` and `SOURCE.md`. |
| `game/interiors/art/shuriken-salon/{reception,styling-station,trolley}.glb` | Adapted from [Hair Salon Set](https://shuriken.studio/models/furniture/hair-salon-set). See `shuriken-salon/LICENSE-SOURCE.txt`. |
| `game/beach_art/beach-town-backdrop/town-from-beach.png`; `game/town_assets/beach-snapshot-backdrop/beach-from-town.png` | Willowbrook's guest-only static scene renders. Their source notes describe capture; art pictured is not relicensed by rendering. Treat the coastal view containing the adapted beach art, and any Shuriken art visible in the Town view, as integrated game derivatives. |

**License-version evidence, reviewed 2026-11-23.** All four retained originals have Windows Internet-origin metadata naming the publisher and matching creation and write dates after the publisher's currently displayed November 13, 2026 version. The contemporaneous salon and warehouse source notes record checking that version on their download dates. The Beach & Water Park ZIP contains the publisher's own license summary, identical to the copy retained in this project; it permits sharing a project with the models integrated and links to the full terms that applied on the date of download. The ZIP does not independently timestamp that full text.

| Retained original (not a separate release download) | UTC date | SHA-256 |
| --- | --- | --- |
| Hair Salon Set GLB | 2026-11-15 | eb560f3037610aa551652263ef25112e3ceea45bd1b903af808b28f366d9dff9 |
| Warehouse Yard Arena GLB | 2026-11-18 | 6381056ded3a10bb42d779fa40302a51b377e82f512a83782f01c37b3c3f627c |
| Beach & Water Park ZIP | 2026-11-18 | 54fc5c1bb93700e86aeaae12d5660bbcdf8828d00d1073817530b58012a2ee44 |
| Toy Paintball Marker GLB | 2026-11-19 | ce470bc8bd8f79c8d11f364d84f009253b719f4eee1c6dd7cd9ccfeb1bbb5a7f |

The full warehouse and marker in this project match their originals byte-for-byte. The warehouse exterior, three salon props, and four beach props were traced to their corresponding originals by their geometry or retained source nodes. The retained records support distributing these specific assets only as part of the playable Willowbrook project and corresponding source, with the Shuriken terms identified separately from the code license. They do not support separate asset packages or relicensing these files. No independent full-text archive for each download day was found, and an attempted fresh download did not complete.

## CC0 art and animations

The paths below are relative to the project root. A directory reference covers the art and its companion buffers/textures there, not surrounding game code or any neighboring pack.

| Included source paths | Creator, license evidence and notes |
| --- | --- |
| `game/character-male-a.glb`; `game/Textures/colormap.png`; `game/avatars/models/`; `game/{beach_art/kenney-mini,town_assets/kenney-mini-npcs,interiors/art/kenney-mini}/`; `browser-preview/avatar-thumbs/*.webp` | Kenney Mini Characters 2.0, CC0, see `game/KENNEY-CHARACTER-LICENSE.txt`, `avatars/Kenney-Mini-Characters-LICENSE.txt` and the local pack notices. The palette at the prototype root is byte-identical to the one in the licensed avatar models; thumbnails are renders of selectable character models, not in-game player save files. |
| `game/town_assets/{kenney-cars,kenney-commercial,kenney-furniture,kenney-mini-arcade,kenney-nature,kenney-roads,kenney-skate,kenney-suburban}/`; `game/interiors/art/{kenney-food,kenney-furniture,kenney-mini-shop,kenney-pets}/`; `game/arcade/{kenney-mini-arcade,arcade-memory}/` | Kenney game kits, CC0, with local pack license notices. `arcade-memory/` uses six unchanged Animal Pack Remastered PNGs. Mini Arcade 1.2 notices additionally credit Fleur Keijsers and Guus Vermeulen. |
| `game/beach_art/beach-boats/`; `game/beach_art/beach-nature/tree_palm*.glb` | Kenney Watercraft Kit 2.1 and Nature Kit, CC0; original licenses and local source notes included. |
| `game/beach_art/beach-nature/{sand-color,sand-normal}.png` | Katsukagi's [Stylized Sand002](https://3dtextures.me/2024/08/02/stylized-sand-002/) with [publisher CC0 terms](https://3dtextures.me/about/). Water is a game shader, not an additional licensed texture pack. |
| `game/{fish_art,fish_thumbs}/`; `game/beach_art/beach-fishing/{Dock_Long,Dock_Wide,FishingRod_Lvl1}.glb` | Quaternius [Animated Cute Fish Pack](https://quaternius.com/packs/cutefish.html), CC0. Game includes a selected 35-fish catalog, renders of its models, two docks and an authored rod conversion. Source/adaptation notes in `fish_art/` and `beach-fishing/`. |
| `game/scuba/animation/quaternius_swim.json` | Quaternius [Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html), CC0; in-place Standard animation data only, source metadata and source GLB SHA-256 embedded in JSON, local license `Quaternius-UAL-CC0.txt`. This is not the separate KayKit animation download. |
| `game/ferry_art/innerscene-passenger-ferry.glb`; `game/ferry_art/innerscene-passenger-ferry_*_2k.png` | Innerscene Corp [Small Passenger Ferry, 25 m](https://www.innerscene.com/tools/library/3d-parts/small-passenger-ferry-25-m-bb6ba356), CC0. The game includes an adaptation and 12 companion texture PNGs. Source download SHA-256 matches `INNERSCENE-PROVENANCE.txt`; the source declares CC0 and is unchanged outside the project. |
| `game/town_assets/scuba-starter/*.glb`; that directory's `{dive-entry-platform,diver-equipment-bench,torn-wing-section,wreck-cockpit-section}_panel.png` | 3DAssets.dev [Diving and Underwater Salvage](https://3dassets.dev/packs/diving-and-underwater-salvage) and [Coral Reef and Underwater Scenery](https://3dassets.dev/packs/underwater-reef-worlds), CC0 and identified by the source as AI-made. All 16 GLB hashes match the per-model manifest. Four Godot-extracted texture sidecars are identical to each other, each SHA-256 `e4f24f8f789a922ea7fd3af180a6bec2a4556157004c2e883b387ca5e526a765`, and use the same declared CC0 source. |
| `game/town_assets/{3dassets-notice-board,beach-park-gate,scooter-rack}/` | 3DAssets.dev notice board, camp gate, and bike rack; CC0. See each directory's specific asset source and license notice, including the derived gate and texture sidecars. |
| `game/scavenger/pickups/{coin,gem,heart,key,medallion,ruby,scroll,star}.glb` | 3DAssets.dev [Pickups and Collectibles](https://3dassets.dev/packs/pickups-and-collectibles), CC0. Exact local source is the published Collectible Run starter scene, asset 19987 v1. See the verified source mapping below. This is separate from the trophy. |
| `game/interiors/art/scavenger/trophy.glb`; `game/interiors/art/scavenger/trophy_House_Props_Diffuse.png` | [Trophy by CreativeTrio](https://poly.pizza/m/fLy8KmmD1t), CC0. Model bytes match retained downloaded GLB. Retain `game/scavenger/CREDITS.txt` alongside the trophy and imported texture. |
| `game/town_assets/{tiny-homely,tiny-park,tiny-playground}/` | Isa Lousberg / [Tiny Treats](https://tinytreats.itch.io/), archived pack notices identify CC0 for Homely House, Pretty Park and Fun Playground. Companion glTF buffers and texture palettes are from the same packs. |
| `game/town_assets/ipoly-concert/` | iPoly3D [LowPoly Concert Props](https://opengameart.org/content/lowpoly-concert-props), CC0. Original README is included as `LICENSE.txt`; selected stage pieces are adapted GLB subsets. |

CC0 means [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) in these notices. The original creator's asset statements are the basis for the classification; this is not a guarantee against separate third-party rights.

### Verified scavenger pickup source mapping

The owner-retained Collectible Run GLB has 1,761,132 bytes and SHA-256 `f5edf3faa7f7139436fc653e7760b472ad1d4f11003b477aa3abcc799a2ed802`, matching the original Willowbrook Three.js `public/assets/scavenger/pickups/manifest.json` and its CC0 source notice. Source: 3DAssets.dev [Pickups and Collectibles](https://3dassets.dev/packs/pickups-and-collectibles), starter asset 19987 v1. Comparing the original GLB, original game subsets, and exact R6 GLBs verified all eight root names, child transforms, triangle indices, and materials. R6's Godot conversion changes the numeric representation of quantized vertex positions and normals, with a maximum absolute difference below 0.00000003; it does not introduce additional art.

| R6 GLB | Original node | Triangles |
| --- | --- | ---: |
| `coin.glb` | `000-spinning-coin` | 928 |
| `gem.glb` | `004-gem-spinning` | 176 |
| `ruby.glb` | `005-gem-spinning-ruby` | 176 |
| `heart.glb` | `013-heart-pickup` | 1,046 |
| `star.glb` | `020-invincibility-star` | 556 |
| `key.glb` | `034-key-floating` | 604 |
| `scroll.glb` | `036-scroll-pickup` | 1,462 |
| `medallion.glb` | `039-medallion` | 1,428 |

## Original presentation and engine logo

- `browser-preview/loading.webp`: generated specifically for Willowbrook using OpenAI image generation on November 21, 2026, according to the project generation record. Retained 1,922,277-byte original PNG SHA-256 `9288a6c37454732ff421a81d8d022f9a71f408ef1a1d10636987796c2166a0c8` matches that record. The documented 1279 x 720 WebP conversion, 116,464 bytes, matches both exact R6 source and R6-final Web package SHA-256 `1f79e06aedbfeb5f9380dd7b9cd5fe2e4580977520de3d395dd097df2d82ac15`. Do not label it a third-party pack or automatically apply a code license to the image.
- `browser-preview/willowbrook-favicon.svg`: original willow-and-creek SVG made for this release candidate, replacing the unverified older favicon. See `browser-preview/BRANDING.md` for exact provenance and hash.
- The stock Godot emblem and its import metadata are not in the clean tree. The Willowbrook SVG is the configured project icon. Engine notices remain in GODOT-NOTICES.txt.

## Distribution checklist

1. Publish only an exact reviewed tree, with the code license explicitly scoped away from third-party art. Keep the Shuriken notices and applicability evidence and close any item-level questions for newly added or changed art. Where an asset is uncertain, remove it only after verifying that its cleared replacement preserves a playable default game.
2. Do not include incoming asset ZIPs, unrelated asset packs such as the downloaded mixed-license Coral Reef Kit or the unused KayKit animation ZIP, separate marketplace downloads, or standalone original/intermediate Shuriken copies unrelated to the functioning game. An integrated runtime model is not a redistribution bundle.
3. Ship this notice and applicable license text alongside both source and compiled releases. The current export excludes Markdown and its packed art does not itself supply a complete notice set. Validate notices are visible and included in the exact archive and download; a file in the development tree alone is not enough.
4. Complete separate audio, dependency, secret, player-data and history gates. This inventory covers art only.

