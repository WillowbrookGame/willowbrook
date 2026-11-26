# Editing Sunny Cafe

Open `game/cafe/room_layout.tscn`. Godot uses the same layout in the game.

- Move a fixture root such as `FrontLeftInnerChair`, not its model or collision child. Save, reopen the scene and enter the Cafe in play. Press **E** when **Sit down** appears and check that the seat and collision moved with the chair.
- Plates and pastries move with their tables. Keep the barista, exit and job-station roots at their default locations for art-only changes; their interaction coordinates are part of progression. Starter cues and job highlights are added during play.

After importing the project:

```sh
godot --headless --path . --script res://game/cafe/test_cafe_room.gd
godot --headless --path . --script res://game/interiors/test_room_shifts.gd -- cafe
```
