# Editing the Reef

Open `game/scuba/reef_layout.tscn`. The group folders organize coral, the arch, reef walls, the wreck, and rocks. Move named fixture roots, not just their imported Model children. Collision on the arch, solid reef walls and cockpit moves with its fixture. The arch must have two supports and an open gap under its lintel.

Expand **Activities** to move the placement markers in the 3D viewport. Their marker gizmos are editor-only; the actual rings, bubbles, pickups and swimming fish appear when you run the reef.

- **DiverSpawn** sets the entry point.
- **MusicalRings** sets each ring's position and facing. Translate or rotate the whole marker; the hoop and its swim-through trigger follow it.
- **BubbleGeysers** uses a base marker plus a `Top` child. Keep the base on the seabed; move `Top` vertically to set the end of the lift column.
- **TreasurePools** groups the candidate pickups by reef zone. Move a named candidate marker; the number chosen per zone and random selection still apply. Keep each candidate within its named zone and reachable.
- **WildlifeLanes** sets each species' swim-lane center. Leave room around that center for the fish to circle; the name identifies the species and its Photo Book entry.

Fish movement, swim controls, depth-based lighting, effects and the return trip remain runtime behavior. Before moving major landmarks, check that they do not block the swimming route or overlap a fish lane. Keep the sand surfaces aligned with the depth calculation in `reef_art.gd` unless you update and test both together.

After importing the project:

```sh
godot --headless --path . --script res://game/scuba/test_scuba_route.gd
godot --headless --path . --script res://game/scuba/test_scuba_editor_layout.gd
```
