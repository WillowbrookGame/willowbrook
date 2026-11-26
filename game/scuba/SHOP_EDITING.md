# Editing the Dive Shop

Open `game/scuba/shop_layout.tscn` in Godot. The game uses this layout directly. Move the `EquipmentBench`, `WetsuitDisplay`, or furniture roots to move the model and associated collision together. Small gear on the bench and the books on the reception desk move with their parent fixtures.

`RoomStructure` contains the original shell and doorway/camera collision; keep that geometry aligned with the existing spawn and exit. Preserve the hidden roof and duplicate exterior pieces inside the imported model. Dive Master animation and dialogue and the boat loading screen are added at runtime.

After importing the project:

```sh
godot --headless --path . --script res://game/scuba/test_scuba_route.gd
```
