# Security Policy

Willowbrook is built for kids and families to play together in a private, invite-only space. Please tell us privately if you find a problem that could affect player privacy, Parent Desk access, or the security of a self-hosted server.

## Supported Versions

Willowbrook is in early alpha. We investigate reports affecting the latest `main` or the newest published alpha. Fixes land on `main` first and ship in a new alpha release when available. We do not backport fixes to older alpha bundles. Back up your data before upgrading.

## Report a Vulnerability Privately

Use [GitHub’s private vulnerability reporting form](https://github.com/WillowbrookGame/willowbrook/security/advisories/new). If you can’t use GitHub’s form, email [criticalbitflip@willowbrookgame.com](mailto:criticalbitflip@willowbrookgame.com).

**Do not report vulnerabilities in public issues, pull requests, or discussions.**

### What to include

- The affected release tag or commit, the component involved, and how you ran Willowbrook (for example, Docker Compose or a local development build).
- What you expected, what happened, and who or what could be affected.
- Relevant screenshots or log excerpts with private information and secrets removed. If you have a suggested mitigation, include it.

### Safe testing and family privacy

Test only on a local Willowbrook instance you control, with disposable accounts and made-up data. Never test against a live or family-hosted server. If you discovered a problem while using a live server, stop testing and report what you observed privately.

Never share children’s names or photos, real account details, chat logs, save files, tokens, or private family server URLs. Use synthetic examples instead.

## What We Prioritize

- **Invites and access control:** Unauthorized access to the game, Parent Desk, or another household’s data.
- **Unexpected data sharing:** Willowbrook or a bundled asset sending data to a third party unexpectedly.
- **Browser security:** Problems with Parent Desk sessions, request protections, page framing, or isolation of the embedded arcade.
- **Self-hosting:** Unintended exposure in the default Docker Compose setup, unsafe file handling, or unnecessary container privileges.

## What to Expect

We aim to acknowledge private reports within three business days. That’s an acknowledgment target, not a deadline for a fix. We’ll share updates as we investigate and coordinate disclosure with you. If you’d like public credit once a fix is released, tell us the name you’d like us to use.
