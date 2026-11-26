# Editing the Bank layout

Open `game/bank/room_layout.tscn` in the Godot editor. This is the layout the Bank uses in play, not a separate preview.

1. Select the parent node for the prop you want to move. For a quick test, select `WaitingChairNear`, change X or Z, and leave Y alone. Do not move its `Model` or `SolidBody` separately.
2. Save, then press **F5** and enter the Bank from Town. Check that the prop, collision, and sit prompt line up at the new position.
3. Set the chair back to **X -6, Y 0, Z 1** after the test. Keep the exit/arrival area clear. Leave the teller, door, and station roots in their original positions unless you also plan to update the gameplay positions. The five fixed station props are under `JobStations`; the shift highlights, menus, and teller animation are runtime behavior.

From the project root, after importing it in Godot, run:

```sh
godot --headless --path . --script res://game/bank/test_bank_room.gd
godot --headless --path . --script res://game/interiors/test_room_shifts.gd -- bank
```

These tests use disposable profiles. They check the default layout, seating, Town doors, mortgage and repayment, and the full coin-sorting shift.
