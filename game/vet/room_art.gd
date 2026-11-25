extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("e0f1e7")

func _build_room_details(_id: String) -> void:
	piece("desk",Vector3(0,0,-.6),Vector3(3,1.05,1.1),PI,true)
	piece("computerScreen",Vector3(.9,1.05,-.55),Vector3(.55,.48,.4),PI)
	piece("computerKeyboard",Vector3(.9,1.05,-.9),Vector3(.5,.06,.2),PI)
	piece("table",Vector3(5,0,-2),Vector3(1.8,1.1,2),0,true)
	box("ExaminationPad",Vector3(5,1.15,-2),Vector3(1.65,.08,1.85),Color("#86bcb1"))
	piece("rugRectangle",Vector3(5,.015,3.5),Vector3(3.4,.025,3))
	piece("animal-dog",Vector3(5,0,3.5),Vector3(.88,.95,.83))
	for x: float in [4.0,6.0]:
		piece("food/plate-rectangle",Vector3(x,.02,4.5),Vector3(.42,.09,.37))
	_public_furniture()
	npc("male-a","Vet",Vector3(0,0,-2.1))
