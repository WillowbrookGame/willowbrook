# Willowbrook local multiplayer

Native Godot builds only (Windows or other desktop/native builds with ENet). It is off until you select Multiplayer.

- First window: open Multiplayer or press **M**, choose a nickname, and select **Host**. Keep IP `127.0.0.1` and port `24861` for two windows on the same computer.
- Second window: use **Join** with the host's IP, port and invite code. Nicknames are not accounts. The code lasts only as long as the host's session.
- On a trusted private LAN, the host must select that computer's actual LAN IPv4 before hosting, and friends enter that same address. Listening is on that IP only; no firewall rules or public port forwarding are configured. This prototype is not for public internet play. ENet traffic is not encrypted.
- Players see each other's avatars only in the same public zone. The roster shows aliases and general locations. Home and solo-paintball poses are not transmitted. No chat, production login, or household data is used.
- For two-player Air Hockey, meet inside the Arcade and stand near the machine. The host simulates the two-player table; five goals win a round and two rounds win the match. Both players must choose rematch. Leaving the arcade or losing the connection frees the player's seat.
- If disconnected, return to the Multiplayer menu to join again. Local saves and progression are not shared. Shared fish, vehicles, houses, account controls, and public internet/HTML deployment remain separate work.

## Loopback tests (PowerShell)
Run `test_network.ps1` with the full path of the Godot Windows console executable as `-Godot` and the project directory as `-Project`. Tests open separate instances, use temporary invite files only, and do not use player saves. No native or router settings are changed.
