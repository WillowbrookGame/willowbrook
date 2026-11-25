extends "res://game/interiors/room_art.gd"

func _room_tint(_id: String) -> Color:
	return Color("ece4d6")

func _build_room_details(_id: String) -> void:
	piece("table",Vector3(0,0,-.5),Vector3(3.6,1.1,1.25),0,true)
	for x: float in [-3.8,3.8]:
		piece("bookcaseClosedWide",Vector3(x,0,-6.3),Vector3(2.4,2.8,.7),0,true)
		for y: float in [.52,1.22,1.92]:
			for i: int in range(8):
				box("Book",Vector3(x-.91+i*.26,y,-5.87),Vector3(.19,.43+(i%3)*.04,.12),Color(["a96579","739d9a","c5a35f","738db2","a18caf"][i%5]))
	for x: float in [-8.3,8.3]:
		piece("bookcaseClosedWide",Vector3(x,0,-2.5),Vector3(2.4,2.8,.7),-signf(x)*PI/2,true)
	for x: float in [-5.0,5.0]:
		piece("rugRectangle",Vector3(x,.015,2.5),Vector3(3.4,.025,4.4))
		piece("chairCushion",Vector3(x,0,3),Vector3(1.15,1.3,1.1),PI,true)
		piece("table",Vector3(x,0,1.4),Vector3(1.1,.65,.85),0,true)
		piece("books",Vector3(x,.67,1.4),Vector3(.65,.13,.42))
		piece("lampRoundFloor",Vector3(x+signf(x)*1.5,0,3.8),Vector3(.6,1.9,.6),0,true)
		piece("pottedPlant",Vector3(x+signf(x)*2.5,0,5.3),Vector3(.8,1.5,.8),0,true)
	piece("books",Vector3(1.1,1.1,-.5),Vector3(.72,.36,.5))
	npc("female-b","Librarian",Vector3(0,0,-2.0))
