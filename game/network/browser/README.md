# Willowbrook standalone browser server

See the [project quickstart](../../../README.md). The server defaults to loopback and needs no external game checkout. All runtime code and game catalogs are included; keep the accounts directory outside both the checkout and the web output. The account mode is opt-in. Test only with fresh disposable data, never a real server state directory.

Run `node game/network/browser/test-standalone-runtime.mjs` from the project root for the relocated runtime smoke test. The test uses synthetic accounts and disposable local ports.