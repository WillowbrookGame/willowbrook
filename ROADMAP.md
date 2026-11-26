# Willowbrook roadmap

This is the maintainers' shortlist, not a release schedule. Open a GitHub issue using **Suggest an idea** for new ideas. Maintainers add accepted proposals here with a link to the issue. Unchecked means planned or being explored, not assigned. Check an item off after its implementation is merged and verified; link the PR. A merge is not a deployment.

## Game and expansions

- [ ] Reef photo scavenger hunt: the Dive Master gives players a list of fish and reef sights to photograph. Keep free diving available.
- [ ] Boat rentals: make the beach rental shop and docks playable, with optional Stars-based rentals.
- [ ] Fishing collection book: record discoveries even after the fish are sold. [Issue #19](https://github.com/WillowbrookGame/willowbrook/issues/19)
- [ ] More ways to spend Stars: cosmetic rod styles, beach decorations, and housing items such as rugs, shelves, and lamps.
- [ ] More expressive NPCs: prototype a wave, sitting, and work gestures on one existing rig, then check browser and tablet performance.
- [ ] Avatar outfits: keep current avatars free, and show unlockable outfits only for compatible avatar families.
- [ ] Prototype one articulated toy-style character rig and a seated animation. [Issue #18](https://github.com/WillowbrookGame/willowbrook/issues/18)
- [ ] Better swim animations: prototype a rig with independent ankles and knees so the feet and fins move together.
- [ ] Optional self-hosted asset imports: link to creators, keep licenses with every asset, and make imports upgrades rather than prerequisites.

## Community and hosting

- [x] Launch a standalone, informational [Willowbrook website](https://willowbrookgame.com/) with family setup and contributor pages.
- [ ] Easier household hosting: publish one start-to-finish private HTTPS recipe, verify it on a real tablet, and document backups and upgrades. Keep loopback-only hosting as the default. Consider a setup helper once the guide is proven.
- [ ] Explore one-click cloud hosting: let families launch their own invite-only Willowbrook server so friends can join without opening ports on the home network. Start with DigitalOcean, then evaluate Linode and Vultr. Reuse the same portable install and verify backups and upgrades before pursuing listings.

## Contributor setup and releases

- [x] Add screenshots and a playable-activities overview above the [README quick start](README.md).
- [x] Document and run the standalone Node smoke test on PRs without secrets, write access, or deployments. [PR #12](https://github.com/WillowbrookGame/willowbrook/pull/12)
- [x] Add [private vulnerability reporting](SECURITY.md), a [public-safe bug report form](.github/ISSUE_TEMPLATE/bug.yml), and a [Code of Conduct](CODE_OF_CONDUCT.md).
- [x] Document one runnable headless Godot test for contributors. [Issue #14](https://github.com/WillowbrookGame/willowbrook/issues/14) Automate headless checks separately after the command is proven.
- [ ] Publish one clearly named Docker bundle per new alpha with a standalone checksum. Keep existing Alpha 1 links valid.
- [x] Add a Linux browser source build ([issue #15](https://github.com/WillowbrookGame/willowbrook/issues/15)).
- [ ] Validate the source build on macOS. Fix temporary staging cleanup and avoid duplicate splash settings in the Windows build.
- [ ] Explore prebuilt amd64 and arm64 container images after the standard build is repeatable. Verify ARM hosting and document whether the optional online Paintball worker is supported before publishing images. [Issue #16](https://github.com/WillowbrookGame/willowbrook/issues/16)

## Browser performance

- [ ] Add cache revalidation for public game assets. Keep account and Parent Desk responses uncached. Test repeat loads and confirm an upgrade fetches the new bundle.
- [ ] Convert the beach wave loop to Ogg, preserve asset credits, check the loop in-browser, and measure the difference in the exported pack and browser download. [Issue #13](https://github.com/WillowbrookGame/willowbrook/issues/13)
- [ ] Measure proxy compression and duplicate binary assets after the above work. Change them only if measured savings are worthwhile, and keep license notices and Godot resources intact.

## Maintenance checklist

- [ ] **Parent Desk framing and CSP:** Prevent other sites from embedding the Parent Desk and restrict what it can load. Verify Parent Desk sign-in and invitations over HTTPS, and smoke-test the game and embedded arcade separately so their browser requirements are not accidentally blocked.
- [ ] **Docker image trimming:** Exclude tests and editor-only files after checking what Node and the optional Paintball worker actually use. Compare image sizes, then verify first start, Parent Desk, and the optional Paintball worker on a clean build. [Issue #17](https://github.com/WillowbrookGame/willowbrook/issues/17)
- [ ] **Restart after reboot:** Both Compose services now use `unless-stopped`. In [PR #1](https://github.com/WillowbrookGame/willowbrook/pull/1), the services restarted once Docker came back, saved data was recovered, and normal shutdown was clean. Still verify that a deliberately stopped stack stays stopped across a reboot and that the single-writer lock works.
