# Editing the Town Store

Open `game/store/room_layout.tscn`. The game uses this same layout.

- Move a fixture root such as `WaitingChair`, not its Model or SolidBody child. Save, reopen the scene, and verify the fixture and collider move together in play.
- Keep the checkout, shopkeeper, job-station roots and exit in their default positions for art-only changes. Changing those positions can also require changes to fixed checkout or progression coordinates. Do not bake runtime starter hints, job highlights, or the furniture order UI into the scene.

After importing the project, verify with:

```sh
godot --headless --path . --script res://game/store/test_store_room.gd
godot --headless --path . --script res://game/interiors/test_room_shifts.gd -- store
```
