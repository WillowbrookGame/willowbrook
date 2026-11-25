extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("e2eafa")

func _build_room_details(_id: String) -> void:
	piece("desk",Vector3(0,0,-.5),Vector3(3.6,1.25,1.25),PI,true)
	piece("computerScreen",Vector3(1.05,1.25,-.45),Vector3(.65,.55,.45),PI)
	piece("computerKeyboard",Vector3(1.05,1.26,-.95),Vector3(.6,.06,.22),PI)
	piece("desk",Vector3(5.5,0,1),Vector3(2.6,1.05,1.2),PI,true)
	piece("chairDesk",Vector3(5.5,0,2.7),Vector3(1.06,1.25,1.05),PI,true)
	_public_furniture()
	npc("female-a","Teller",Vector3(0,0,-2.0))
