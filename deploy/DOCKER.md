# Self-host Willowbrook for a household (Linux / Dockge)

Run Docker Engine and Compose on Linux. The host does not need Godot, Node.js,
or PowerShell installed. Put a **clean prebuilt Web export from the same
Willowbrook revision as this server** in the stack's `web-export/` directory
(`index.html`, `index.pck`, `index.wasm`, the notices, and all sibling folders).
If using a release archive, extract it to a fresh directory and run "sha256sum -c SHA256SUMS" there before starting.

The export is read-only and separate from the private account volume. Set
`WILLOWBROOK_WEB_EXPORT` only if it lives at another local absolute path.

## First start

From the directory containing `compose.yaml`:

```bash
docker compose build willowbrook
read -rsp 'Choose the owner password (10+ characters): ' willowbrook_pw; printf '\n'
printf '%s\n' "$willowbrook_pw" | docker compose run --rm -T --entrypoint node willowbrook /app/deploy/bootstrap-owner.mjs family_owner
unset willowbrook_pw
docker compose up -d
```

This is a one-time owner setup for a new named volume. The password goes through
stdin, not Compose, shell history, environment files, or a command argument.
Open `http://127.0.0.1:24863/parent.html` on the Linux host. Sign in as
`family_owner` and choose **Make parent invite**. In a separate browser profile
or after signing out, redeem that code under **Parent invite** and sign in as
the new parent. The parent can then choose **Make player invite**. Open
**Player invite** to redeem the child's code, choose a nickname and character,
and sign into the game at `http://127.0.0.1:24863/`. Local HTTP is not a LAN
address. To administer remotely
without opening ingress, use a local SSH port-forward to the same loopback port
from an authorized administrator computer and open the same URL there.

This default stack does **not** publish a container port or bind a LAN address.
It uses Linux host networking so Willowbrook can continue to listen on
`127.0.0.1`. Other users with local access to the Linux host still need the
owner/player credentials. The default does not configure a tunnel, port forward,
or LAN account access.

## Optional: private LAN HTTPS for a second device

Use the extra Compose file only on a trusted household network. It adds Nginx,
binding HTTPS to exactly the assigned RFC1918 LAN IPv4 on **8443**. There is no
HTTP LAN listener or public exposure by default. Before enabling it:

- Choose a household DNS name (e.g. `willowbrook.home.arpa`) and configure it in
  your local DNS to resolve to the Linux host's private IP on every device.
- Supply a TLS certificate with that exact DNS name and a private key under an
  **external private directory** as `cert.pem` and `key.pem`. Both must be
  readable by the container's numeric UID 1000; keep the key permissions narrow,
  do not add it to the repository, and keep the issuing CA private key off this
  host. All playing devices need to already trust the certificate's issuer.
  Do not click through certificate warnings.
- Do not forward router ports or attach a public tunnel. Restrict access to your
  household through your existing firewall policy and verify this separately.

Example non-secret environment variables (substitute your actual values):

```bash
export WILLOWBROOK_PRIVATE_HOST=willowbrook.home.arpa
export WILLOWBROOK_PRIVATE_IP=192.168.50.10
export WILLOWBROOK_TLS_DIR=/path/to/private/willowbrook-tls
docker compose -f compose.yaml -f compose.https-lan.yaml up -d
```

Open `https://willowbrook.home.arpa:8443/` and append `parent.html` for Parent
Desk. Use this exact name and port; an IP-address URL is intentionally not
accepted. The Node origin still binds loopback, checks HTTP authority and WebSocket
Origin, and uses a Secure parent cookie. Do not use a proxy which rewrites browser
Host/Origin or makes the loopback origin publicly reachable. An optional private
DNS/certificate setup is separate from the game and not performed by this stack.

## Updates and backups

Before replacing the server or export, stop the stack and back up its named
`willowbrook-state` volume in private storage. Keep the previous source and Web
export together for rollback. Use a fresh static export directory and validate the
browser build there before copying it to the runtime path. `docker compose down`
leaves account data intact; **do not use `down -v` unless deleting the account data
is intended**. Stop normally to release the single-writer lock; do not remove a
writer lock while any instance may be using the account store.

For Dockge, put the same files inside a new dedicated stack directory and use the
Compose files above. Use the terminal for one-time provisioning and the explicit
two-file HTTPS command; do not paste a password into the stack editor. The starter stack leaves optional Family Chat off.

## Optional: online Paintball

Use the matching Linux x86-64 Paintball runtime for this release in
`paintball-runtime/` alongside the Compose files. It contains the pinned Godot
4.7.2 executable, the executable `godot-paintball-stdio` wrapper, and the imported
worker project. Keep the archive's executable permissions when extracting it.
Use `WILLOWBROOK_PAINTBALL_RUNTIME` only to override that directory.

```bash
docker compose -f compose.yaml -f compose.https-lan.yaml -f compose.paintball.yaml up -d --build
```

Omit the HTTPS overlay for play on the server computer only. The worker uses
local pipes and adds no network listener or publishable port. Two signed-in
players can meet at the Paintball entrance and select Multiplayer; solo play
remains available if the worker is disabled or unavailable.
