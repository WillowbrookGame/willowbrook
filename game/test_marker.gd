extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://game/arena.tscn")
	await scene_changed
	var map := current_scene
	var preview: Node3D = map.marker_preview
	var loose := preview.marker.find_child("Paintballs", true, false) as Node3D
	if preview.right_arm < 0 or not preview.marker.visible or loose == null or loose.visible:
		push_error("Marker mount or loose preview paintballs incorrect")
		quit(1)
		return
	var yard_body := map.yard.get_node("YardCollision") as StaticBody3D
	yard_body.collision_layer = 0
	map.ZONE_GEOMETRY.box(map, "TestPaintFloor", Vector3(0,-0.1,7), Vector3(40,0.2,40), Color.WHITE, true)
	map.ZONE_GEOMETRY.box(map, "TestPaintWall", Vector3(-1.6,2.5,4.5), Vector3(5,5,0.25), Color.WHITE, true)
	for i in range(5):
		await physics_frame
	preview.trigger()
	for i in range(3):
		await physics_frame
	preview.trigger()
	for i in range(19):
		await physics_frame
	if preview.shot_count != 1 or preview.splats.size() != 1 or absf(preview.splats[0].global_position.z - 4.64) > 0.12:
		push_error("Paintball preview did not create one splat at the wall: %s %s" % [preview.shot_count,preview.splats])
		quit(1)
		return
	print("PASS: handheld model, preview paintball travel, surface splat, and shot cooldown")
	quit()
