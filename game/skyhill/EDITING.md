# Skyhill Park: first flight
Open game/skyhill/skyhill.tscn in Godot and run the current scene (F6). This prototype is standalone: Town, multiplayer, and the live game are unchanged.

- Press E or choose Launch. The glider moves forward; A/D, arrow keys, or the touch stick bank it. Keep straight for the easy approach, or steer right toward the Waterfall lift marker and blue wind ribbons, then aim down the valley over the ridge.
- Landing in the meadow is automatic: the glider eases into its approach, then coasts to a stop. Press E or choose Ride back up to try again. Return to deck works mid-flight; out-of-bounds trips and impacts return you without a penalty.
- In the editor, Course/Launch sets the start and facing. Course/WaterfallLift and its LiftBounds set the updraft center and size. Course/MeadowCenter and LandingBounds set the touchdown target; keep them aligned with Scenery/LandingMeadow. Move any rail, tree, or prop in Scenery. Move solid course geometry by its StaticBody3D so its collision comes with it.
- Scenery uses instanced GLB assets (original Skyhill terrain, deck, waterfall, and flight markers, plus the selected Kenney props). Select each instance or its parent in Godot to move it. The valley terrain asset imports its own triangle collision from the same geometry, so the rolling shoulders stay solid when moved. The nearby cliffs, landing surface, and deck keep separate simple collision shapes; preserve their fit when swapping art. Move Creek, Woodland, and BanksAndWildflowers independently in the scene. Original models can also be opened in Blender or rebuilt with `python game/skyhill/art/build_skyhill_art.py`.
- The lift sound is an original, local cue. Visible ribbons and the climb carry the mechanic with sound off. Positional waterfall ambience is deferred until browser and device testing.

Automated check:

    godot --headless --path . --script res://game/skyhill/test_skyhill_flight.gd
