extends "res://game/interiors/room_art.gd"

const ROOM_FLOORS := ["e3c6a1","e1d4b5","d5d6bd"]
const ROOM_WALLS := ["f1e6d5","e0ebe4","e8e2ef"]

func _build_special_room(_id: String, profile: Dictionary) -> bool:
	_home(maxi(1,int(DATA.data.homeVariants.get(profile.get("home",{}).get("variant","starter"),{}).get("rooms",1))))
	redraw_decor(profile)
	return true

func _home(count: int) -> void:
	for i in range(count):
		var x := float(i)*12.0
		var tint := Color(ROOM_WALLS[i])
		box("HomeFloor",Vector3(x,-.12,0),Vector3(12,.24,10),Color(ROOM_FLOORS[i]),true)
		box("HomeBackWall",Vector3(x,2,-5),Vector3(12,4,.18),tint,true,3)
		window_at(x,-4.87)
		if i == 0:
			for side: float in [-1.0,1.0]:
				box("HomeDoorWall",Vector3(side*3.75,2,5),Vector3(4.5,4,.18),tint,true,3)
			box("HomeLintel",Vector3(0,3.65,5),Vector3(3,.7,.18),tint,true,3)
			box("HomeLeftWall",Vector3(-6,2,0),Vector3(.18,4,10),tint,true,3)
		else:
			box("HomeFrontWall",Vector3(x,2,5),Vector3(12,4,.18),tint,true,3)
		if i == count-1:
			box("HomeSideWall",Vector3(x+6,2,0),Vector3(.18,4,10),tint,true,3)
		else:
			for side: float in [-1.0,1.0]:
				box("Partition",Vector3(x+6,2,side*3.25),Vector3(.18,4,3.5),tint,true,3)
			box("PartitionLintel",Vector3(x+6,3.65,0),Vector3(.18,.7,3),tint,true,3)
	exit_mat(4.35)
	decor = Node3D.new()
	decor.name = "Furniture"
	add_child(decor)
