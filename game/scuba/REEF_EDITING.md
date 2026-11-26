# Editing the Reef

Open `game/scuba/reef_layout.tscn`. The group folders organize coral, the arch, reef walls, the wreck, and rocks. Move named fixture roots, not just their imported Model children. Collision on the arch, solid reef walls and cockpit moves with its fixture. The arch must have two supports and an open gap under its lintel.

Fish schools, swim controls, bubbles and the return trip remain runtime behavior. Before moving major landmarks, check that they do not block the swimming route or overlap a fish lane. Keep the sand surfaces aligned with the depth calculation in `reef_art.gd` unless you update and test both together.

After importing the project:

```sh
godot --headless --path . --script res://game/scuba/test_scuba_route.gd
```
