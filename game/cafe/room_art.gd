extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("f5e5d0")

func _register_shop_piece(spec: Dictionary, holder: Node3D, dimensions: Vector3) -> void:
	if spec.file == "chairCushion":
		_register_public_seat(holder,dimensions.y)

func _build_room_details(_id: String) -> void:
	npc("male-b","Barista",Vector3(4.5,0,-4.9))
	box("MenuBoard",Vector3(0,2.8,-6.65),Vector3(4.4,1.8,.12),Color("#52746e"))
	label_3d("Sunny Cafe  •  Fresh from the oven",Vector3(0,2.8,-6.56),44,false)
	for x: float in [-1.55,0,1.55]:
		piece("food/plate-rectangle",Vector3(x,1.23,-4.8),Vector3(.75,.1,.7))
		piece("food/muffin" if x==0 else "food/croissant",Vector3(x,1.33,-4.8),Vector3(.45,.28,.48))
	for x: float in [-5.0,5.0]:
		for z: float in [-.5,3.6]:
			piece("food/cup-coffee",Vector3(x-.4,.88,z),Vector3(.24,.22,.25))
			piece("food/croissant",Vector3(x+.35,.88,z+.12),Vector3(.42,.23,.4))
