# Editing a Home interior

Open one of the fixed shells in Godot:

- [Starter](layout_starter.tscn): one room.
- [Cottage](layout_cottage.tscn): two rooms.
- [Family](layout_family.tscn): three rooms.

Each shell is used by the same [Home scene](room.tscn) for all six plots. Move a named fixture such as `Room1/BackWall` rather than its `SolidBody` child so the collision moves with it. Keep room origins, floors, the front doorway and the partition openings aligned with the existing placement coordinates; changing that contract also requires changes to progression and furniture placement.

Saved furniture, pets, placement previews and guest state are created in play. Do not put any player's furnishing or save into these scenes.

After importing the project:

```sh
godot --headless --path . --script res://game/home/test_home_routes.gd
node game/network/browser/test_home_visits_preview.mjs
```
