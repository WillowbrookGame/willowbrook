# Editing Warehouse Yard

Open `game/warehouse_yard.tscn` in Godot. Expand the editable `WarehouseModel` instance to select named containers, forklifts, pallets, barrels, or other scenery. Some pieces, such as the barrel clusters, are one mesh in the original asset and move as a group. Keep the original GLB unchanged.

The client and match worker both build collision from the placed scene, so solid props follow their edited transforms. Keep original node names and do not move the ground, barrel pocket groups, catwalk/stair runs, roof, spawns, or exits without rechecking their corresponding traversal rules and test fixtures. Keep edits to gameplay logic in a separate PR.

After importing the project:

```sh
godot --headless --path . --script res://game/test_warehouse_editor.gd
godot --headless --path . --script res://game/test_warehouse_parity.gd
```
