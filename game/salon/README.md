# Editing the Beauty Salon

Open `game/salon/room_layout.tscn`. Godot uses that layout in play.

- Move a fixture root such as `LeftWaitingChair`, not its model or collider. Save and reopen the scene, then press **E** when **Sit down** appears to check cushion height and facing.
- The waiting chairs are usable seats; the chairs at the styling stations remain scenery. Leave the reception desk, stylist, exit and job-station roots in place for art-only changes. Moving them may need corresponding changes to interaction coordinates.
- Job highlights and character animation are applied at runtime.

After importing the project:

```sh
godot --headless --path . --script res://game/salon/test_salon_room.gd
godot --headless --path . --script res://game/interiors/test_room_shifts.gd -- salon
```
