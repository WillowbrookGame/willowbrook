extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://game/arena.tscn")
	await scene_changed
	var map := current_scene
	var player: CharacterBody3D = map.player
	var yard_body := map.yard.get_node("YardCollision") as StaticBody3D
	yard_body.collision_layer = 0
	player.set_physics_process(false)
	player.position = Vector3(0,0,9)
	await physics_frame
	var first: Vector3 = map.camera.position
	player.position.x = 6.0
	await physics_frame
	var shift: float = map.camera.position.x - first.x
	var free_distance: float = map.camera_distance
	map.ZONE_GEOMETRY.box(map, "TestCameraWall", Vector3(6,2.0,10.45), Vector3(3,4,0.2), Color.WHITE, true)
	for n in range(4):
		await physics_frame
	var shortened: float = map.camera_distance
	var eye_position: Vector3 = map.camera.global_position
	var tight_forward := eye_position.z < player.position.z + 0.02 and eye_position.y > player.position.y + 1.3
	if map.camera.projection != Camera3D.PROJECTION_PERSPECTIVE or shift < 5.9 or free_distance < 3.4 or shortened > 0.05 or not map.camera_tight or not tight_forward or map.arena_avatar.visible:
		push_error("chase camera didn't follow or retract: %s %s %s" % [shift, free_distance, shortened])
		quit(1)
		return
	map.get_node("TestCameraWall").queue_free()
	for n in range(25):
		await physics_frame
	if map.camera_distance < 3.4 or not map.arena_avatar.visible or map.camera_tight:
		push_error("camera didn't extend after obstruction cleared")
		quit(1)
		return
	if map.arena_avatar == null or not map.arena_animation.has_animation("walk") or not map.arena_animation.has_animation("idle"):
		push_error("Willowbrook avatar or animation missing")
		quit(1)
		return
	map._turn_arena_view(Vector2(PI / 2.0 / 0.003,0), 0.003)
	map.ZONE_GEOMETRY.box(map, "TestMovementFloor", Vector3(0,-0.1,9), Vector3(40,0.2,40), Color.WHITE, true)
	var body_start := player.position
	player.held["up"] = true
	player.set_physics_process(true)
	for n in range(12):
		await physics_frame
	player.held.clear()
	var forward: Vector3 = -map.camera.global_basis.z
	if forward.x < 0.95 or player.position.x - body_start.x < 0.7 or absf(player.position.z-body_start.z) > 0.1 or map.arena_animation.current_animation != "walk":
		push_error("Turn, camera-relative movement, or walk animation failed")
		quit(1)
		return
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	if current_scene.camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		push_error("town did not reuse the chase camera")
		quit(1)
		return
	print("PASS: shoulder camera follow, forward close-quarters view and over-shoulder recovery, turning, relative movement, avatar animation and shared town camera")
	quit()
