# Willowbrook roadmap

This is the maintainers' shortlist, not a release schedule. Open a GitHub issue using **Suggest an idea** for new ideas. Maintainers add accepted proposals here with a link to the issue. Unchecked means planned or being explored, not assigned. Check an item off after its implementation is merged and verified; link the PR. A merge is not a deployment.

## Game and expansions

- [ ] Reef photo scavenger hunt: the Dive Master gives players a list of fish and reef sights to photograph. Keep free diving available.
- [ ] Boat rentals: make the beach rental shop and docks playable, with optional Stars-based rentals.
- [ ] Fishing collection book: record discoveries even after the fish are sold.
- [ ] More ways to spend Stars: cosmetic rod styles, beach decorations, and housing items such as rugs, shelves, and lamps.
- [ ] More expressive NPCs: prototype a wave, sitting, and work gestures on one existing rig, then check browser and tablet performance.
- [ ] Avatar outfits: keep current avatars free, and show unlockable outfits only for compatible avatar families.
- [ ] Better swim animations: prototype a rig with independent ankles and knees so the feet and fins move together.
- [ ] Optional self-hosted asset imports: link to creators, keep licenses with every asset, and make imports upgrades rather than prerequisites.

## Community and hosting

- [ ] Standalone Willowbrook website, separate from GitHub: explain what the game is, show screenshots and updates, and help visitors decide if they want to run their own copy or contribute. Link to self-hosting requirements, setup docs, the public roadmap, and contributor guides. Informational only: no game to play, no player accounts, and no links to private family servers.
- [ ] Easier household hosting: publish one start-to-finish private HTTPS recipe, verify it on a real tablet, and document backups and upgrades. Keep loopback-only hosting as the default. Consider a setup helper once the guide is proven.

## Contributor setup and releases

- [ ] Add two or three screenshots and a short list of activities above the README quick start. Use demo accounts and saves, not private family footage.
- [ ] Document one command for the existing Node test suite and run it on PRs without secrets, write access, or deployment permissions. Add headless Godot tests as a follow-up.
- [ ] Add a private vulnerability reporting path in `SECURITY.md`, a bug report form that asks for sanitized details only, and a code of conduct.
- [ ] Publish one clearly named Docker bundle per new alpha with a standalone checksum. Keep existing Alpha 1 links valid.
- [ ] Add a Linux source build first, then validate macOS. Fix temporary staging cleanup and avoid duplicate splash settings in the Windows build.
- [ ] Explore prebuilt amd64 and arm64 container images after the standard build is repeatable. Verify ARM hosting and document whether the optional online Paintball worker is supported.

## Browser performance

- [ ] Add cache revalidation for public game assets. Keep account and Parent Desk responses uncached. Test repeat loads and confirm an upgrade fetches the new bundle.
- [ ] Convert the beach wave loop to Ogg, preserve asset credits, check the loop in-browser, and measure the difference in the exported pack and browser download.
- [ ] Measure proxy compression and duplicate binary assets after the above work. Change them only if measured savings are worthwhile, and keep license notices and Godot resources intact.

## Maintenance checklist

- [ ] **Parent Desk framing and CSP:** Prevent other sites from embedding the Parent Desk and restrict what it can load. Verify Parent Desk sign-in and invitations over HTTPS, and smoke-test the game and embedded arcade separately so their browser requirements are not accidentally blocked.
- [ ] **Docker image trimming:** Exclude tests and editor-only files after checking what Node and the optional Paintball worker actually use. Compare image sizes, then verify first start, Parent Desk, and the optional Paintball worker on a clean build.
- [ ] **Restart after reboot:** Evaluate `unless-stopped` for the household stack. Test normal shutdown, host reboot, save recovery, the single-writer lock, and that a deliberately stopped stack stays stopped before changing the default.
