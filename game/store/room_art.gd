extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("e0ebdf")

func _build_room_details(_id: String) -> void:
	# The supplied register already includes its counter. Keep the
	# customer aisle at z=-1.8 clear, on the server's employer point.
	npc("female-a","Shopkeeper",Vector3(0,0,-5.05))
	piece("bookcaseClosedWide",Vector3(-7.6,0,-3.4),Vector3(2,2.1,.7),PI/2,true)
	piece("chairCushion",Vector3(-5,0,-2.7),Vector3(.88,1.15,.83),PI/3,true)
