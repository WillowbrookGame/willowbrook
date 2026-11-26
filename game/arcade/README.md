# Editing the Arcade

Open `game/arcade/room_layout.tscn`. It contains the room shell and all eight cabinet fixtures. Move a cabinet root such as `Cabinets/MemoryCabinet`: its model, sign, collision and `InteractHere` prompt move with it. Keep each cabinet's ID unchanged. Leave the exit group at the doorway for layout-only edits.

The layout does not change which games are bundled or enabled in a particular build. Cabinet menus, multiplayer and browser startup still run through the Arcade gameplay code.

After importing the project:

```sh
godot --headless --path . --script res://game/arcade/test_arcade.gd
```
