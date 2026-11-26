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

## In-game home decorating

Stand in the room you own and open **Decorate your home**. Choose an item
from storage to place it, or select an existing item in the room to move it.
Drag the preview with a mouse or finger, use the arrow buttons to nudge it,
and use **Turn 90°** to rotate it. **Place furniture** or **Save move** saves
the result; **Done** discards an unconfirmed preview.

Small decorations can sit on a valid furniture surface. Drag onto a
table or shelf, or select a specific surface from the list. A red preview
explains why the item cannot be saved. Move or pack any objects resting on
a piece before moving the piece itself.

Right-drag or switch on **Drag to orbit** to turn the camera. The view and
zoom buttons also work with touch. Close the editor and walk into another
room to edit it. Visits remain read-only.

To run the Godot input and placement regression after a project import:

```sh
godot --headless --path . --script res://game/home/test_home_decorator.gd
```
