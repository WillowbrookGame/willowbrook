# Editing the Library layout

Open `game/library/room_layout.tscn`. The game uses this same layout.

1. In the Scene tree, move `LeftReadingChair` on X or Z, not its model or collider. Save, close and reopen the scene, and confirm the position persisted.
2. Press **F5**, enter the Library from Town, and confirm the chair and its collision moved together and the avatar sits on the cushion, facing the same direction as the chair. Restore the chair to **X -5, Y 0, Z 3** after testing.
3. Keep the librarian, exit, and job station roots at their default positions for art-only edits. Class menus and job highlights are added during play.

After importing the project, verify with:

```sh
godot --headless --path . --script res://game/library/test_library_room.gd
godot --headless --path . --script res://game/interiors/test_room_shifts.gd -- library
```
