# Skyhill Park: first flight
Open game/skyhill/skyhill.tscn in Godot and run the current scene (F6). This prototype is standalone: Town, multiplayer, and the live game are unchanged.

- Press E or choose Launch. The glider moves forward; A/D, arrow keys, or the touch stick bank it. Keep straight for the easy approach, or turn right toward the pale wind ribbons beside the waterfall, then aim down the valley over the ridge.
- Landing in the meadow is automatic. Press E or choose Ride back up to try again. Return to deck works mid-flight; out-of-bounds trips and impacts return you without a penalty.
- In the editor, Course/Launch sets the start and facing. Course/WaterfallLift and its LiftBounds set the updraft center and size. Course/MeadowCenter and LandingBounds set the touchdown target; keep them aligned with Scenery/LandingMeadow. Move any rail, tree, or prop in Scenery. Move solid course geometry by its StaticBody3D so its collision comes with it.
- The lift sound is an original, local cue. Visible ribbons and the climb carry the mechanic with sound off. Positional waterfall ambience is deferred until browser and device testing.

Automated check:

    godot --headless --path . --script res://game/skyhill/test_skyhill_flight.gd
