# Editing Willowbrook Town

Open `game/town_scenery.tscn` in Godot for fixed placements. It is the same scene used by `game/town.tscn`, not a separate preview. The scene tree groups landmarks by area.

- To move the tree by the second west-side driveway, select **Trees → Plot2DrivewayTree**, then move that parent. Its art and trunk collider are children. Do the same with named props such as village-green benches, nursery planters, and the scooter rack. Use the Move tool; scaling collision bodies is not supported.
- The original imported meshes remain instances. Move their placement roots, not the source models. The house numbers and notice-board panels move with their parents.
- Leave road, building entrances, driveways, ferry and playground route landmarks aligned with their current routes. Their gameplay anchors are maintained separately and are not moved by scenery edits. Where a structure spans several pieces, move the area root rather than leaving its collision or approach behind, and update and test the matching routes.
- The houses shown in the editor are starter exteriors. Save-driven exterior upgrades, NPCs, quests, weather, vehicles, and the ferry boat and gangway still run in code. The garden sign and watering marker only appear in the browser when the garden feature is active.

After importing the project, verify the edited scene and its routes:

```sh
godot --headless --path . --script res://game/test_town_editor.gd
godot --headless --path . --script res://game/test_town_layout.gd
godot --headless --path . --script res://game/test_island_ferry.gd
godot --headless --path . --script res://game/home/test_home_routes.gd
godot --headless --path . --script res://game/activities/test_playground.gd
```
