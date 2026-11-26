# Editing Willowbrook Island

Open `game/beach_scenery.tscn` in Godot. It is the fixed scene the game loads. Group roots organize the ferry pier, fishing pier, rental dock, shops, palms, lounge areas and moored boats. Move the named roots rather than their model or collision children. The shared `beach_base.tscn` contains the shoreline, its collision, sky, lighting and water and is also used by the dive-departure scene.

Ferry movement, the folding gangway, animation, moored-boat bobbing, Finn's line, rentals, fishing and the slide ride remain runtime behavior. Keep major route landmarks aligned with the existing interaction coordinates, water footprints and slide/ferry paths unless you explicitly update and test those paths too. The first two fishing pier segments share a long deck collider: move them together with their deck and guard shapes, not as independent walkable ramps.

After importing the project:

```sh
godot --headless --path . --script res://game/test_beach_layout.gd
godot --headless --path . --script res://game/test_beach_route.gd
godot --headless --path . --script res://game/test_island_ferry.gd
godot --headless --path . --script res://game/scuba/test_scuba_route.gd
```
