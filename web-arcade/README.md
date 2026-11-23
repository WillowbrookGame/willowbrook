# Willowbrook browser arcade

The browser build loads the original Willowbrook arcade using a same-origin dialog. The game, iframe and assets must be served together over HTTP(S).

## Public source edition (default)

From PowerShell:

    .\package.ps1 -PreviewRoot <fresh Godot Web export>

This uses the in-tree `vendor-src` snapshot, not an installed home-directory project. Six cabinets are included: Memory Match, Road Crossing, Claw Machine, Blastemoids, Air Hockey and HOOPS '88. The existing Cosmic Breakout and Basic Survivors cabinet positions show a generic Coming soon notice and return focus to the game on dismissal. Their implementation and asset files are not packaged.

Air Hockey requires account multiplayer transport and a second player. HOOPS '88 has an authenticated scoreboard and an offline solo-practice mode without leaderboard saves.

## Tests

    node .\test-shell.mjs
    node .\test-local-hoops.mjs <Web export>
    node .\test-web.mjs <Web export>

The last test uses installed Chromium and loopback fixture accounts/transport; it does not replace a full Godot/WebAssembly integration test.

See [THIRD_PARTY.md](THIRD_PARTY.md) and retain each third-party copyright, license, and relevant source note.
