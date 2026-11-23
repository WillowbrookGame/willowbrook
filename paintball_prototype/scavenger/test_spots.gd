extends SceneTree
const PATH := "res://paintball_prototype/"
var points: Array
var problems := 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("willowbrook_separate_profile",true)
	points = JSON.parse_string(FileAccess.get_file_as_string(PATH+"scavenger/spots.json"))
	var zones := {}
	for point: Dictionary in points:
		if not zones.has(point.zone): zones[point.zone] = []
		zones[point.zone].append(point)
	for zone: String in zones.keys():
		if zone not in ["town","beach","bank","vet","salon","store","cafe","library","arcade"]:
			problems += 1
			continue
		if zone not in ["town","beach"]:
			set_meta("room_destination",zone)
		var scene: String = zone if zone in ["town","beach"] else "room"
		change_scene_to_file(PATH+scene+".tscn")
		await process_frame
		for n in 4: await physics_frame
		var map := current_scene as Node3D
		var space := map.get_world_3d().direct_space_state
		var shape := CapsuleShape3D.new()
		shape.radius = 0.27
		shape.height = 1.45
		var body: CharacterBody3D = map.get_node("Player")
		var exclude: Array[RID] = [body.get_rid()]
		for p: Dictionary in zones[zone]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,2.75,p.z),Vector3(p.x,-.4,p.z),3,exclude)
			var floor_hit := space.intersect_ray(query)
			if floor_hit.is_empty() or absf(floor_hit.position.y) > .15:
				printerr("Blocked or no ground: ",p.id," at ",floor_hit.get("position","none"))
				problems += 1
				continue
			var volume := PhysicsShapeQueryParameters3D.new()
			volume.shape = shape
			volume.transform.origin = Vector3(p.x,floor_hit.position.y+.77,p.z)
			volume.collision_mask = 3
			volume.exclude = exclude
			var blockers := space.intersect_shape(volume)
			if not blockers.is_empty():
				printerr("Blocked capsule: ",p.id," by ",blockers[0].collider.name)
				problems += 1
			else: print("Clear hunt spot: ",p.id)
	print(points.size()," curated hunt points; ",problems," collision problems")
	quit(0 if problems == 0 else 1)