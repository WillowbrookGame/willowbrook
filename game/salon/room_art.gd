extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("f3e2ec")

func _build_room_details(_id: String) -> void:
	npc("female-b","Stylist",Vector3(0,0,-5.7))
	for x: float in [-5.0,5.0]:
		piece("rugRectangle",Vector3(x,.018,3),Vector3(2.8,.025,3))
		piece("lampRoundFloor",Vector3(x+signf(x)*1.5,0,3.8),Vector3(.55,1.9,.55),0,true)
