# Editing the Vet layout

Open `game/vet/room_layout.tscn` in the Godot editor. This is the layout the game actually loads when you enter the Vet in Town. The project requires the Godot version listed in the root README.

1. In the Scene tree, select `WaitingChairNear` or `LeftPlant`, not the imported `Model` under it. Press **W** for Move or edit **Transform → Position** in the Inspector. Leave Y at its default and make a small adjustment on X or Z.
2. Save the scene (**Ctrl+S**), then run the project (**F5**). Enter the Vet from Town with **E**. The model and its collider move together, and the chair's sit prompt follows the chair. Press **E** to talk to the Vet at reception and to leave via the Town exit.
3. Check your diff. A placement-only edit should only touch `game/vet/room_layout.tscn`. Keep the exit and the arrival area clear, don't rename the chair or Vet nodes, and leave the walls, doors, and trigger logic alone in a placement change.

To run the automated default-layout and gameplay regression after a code change, import the project and then run:

```sh
godot --headless --path . --script res://game/vet/test_vet_room.gd
```

The test starts in Town and uses a disposable in-memory profile. It covers the default chair and plant, seat and collider placement, adoption, and the return door. The test uses the saved layout as its placement reference.
