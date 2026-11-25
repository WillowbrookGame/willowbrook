extends SceneTree

const AUTHORITY = preload("res://game/network/paintball/match_authority.gd")
const YARD = preload("res://game/warehouse_yard.gd")
const POCKETS := [Vector2(-10.8,6.35), Vector2(10.8,-6.35), Vector2(-6.3,19.3)]
# Characterization of the pre-extraction layout. Update deliberately if the map changes.
const ORIGINAL_SPAWNS := [
	Vector3(-1.65,0.04,7.05), Vector3(-17.6,0.08,4.4),
	Vector3(13.8,0.08,5.2), Vector3(2.3,0.08,-8.0),
]
const ORIGINAL_PATROL := [
	Vector3(-11.1,0,-8.1), Vector3(-18.6,0,3.7), Vector3(-10.5,0,8.3),
	Vector3(5.6,0,8.0), Vector3(10.1,0,5.7), Vector3(19.2,0,5.0),
	Vector3(10.0,0,-6.0), Vector3(4.2,0,-8.0), Vector3(-8.9,0,-9.3),
]

func _initialize() -> void:
	_run.call_deferred()

func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func _ray(world: Node3D, start: Vector3, end: Vector3, mask: int) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(start, end, mask))

func _check_yard(yard: Node3D, label: String) -> bool:
	var model := yard.get_node("WarehouseModel") as Node3D
	var solid := yard.get_node("YardCollision") as StaticBody3D
	var guards := yard.get_node("BarrelPocketGuards") as StaticBody3D
	if not _require(yard.scene_file_path == "res://game/warehouse_yard.tscn"
			and yard.transform == Transform3D.IDENTITY
			and model.position.is_equal_approx(Vector3(0,-0.45,0))
			and model.scale.is_equal_approx(Vector3.ONE*0.45),
			label + ": yard ownership or original model transform changed"):
		return false
	if not _require(solid.collision_layer == 1 and guards.collision_layer == 2
			and guards.collision_mask == 0, label + ": solid/guard layer contract changed"):
		return false
	for pocket: Vector2 in POCKETS:
		var from := Vector3(pocket.x,1.66,pocket.y)
		var to := Vector3(pocket.x,1.20,pocket.y)
		var hit := _ray(yard,from,to,2)
		if not _require(hit.get("collider") == guards and is_equal_approx(hit.position.y,1.37)
				and _ray(yard,from,to,1).is_empty() and _ray(yard,from,to,5).is_empty(),
				"%s: a pocket no longer supports movement alone at %s" % [label,pocket]):
			return false
	var floor := _ray(yard,Vector3(6.4,0.28,-18.0),Vector3(6.4,-0.3,-18.0),5)
	return _require(floor.get("collider") == solid,
		label + ": regular solid cover disappeared from the paint mask")

func _shape_faces(yard: Node3D, path: NodePath) -> PackedVector3Array:
	var node := yard.get_node(path).get_child(0) as CollisionShape3D
	return (node.shape as ConcavePolygonShape3D).get_faces()

func _move_body(body: CharacterBody3D, frames: int) -> void:
	# The authoritative actor normally advances from a worker tick, not _physics_process dispatch.
	for _frame in range(frames):
		await physics_frame
		body._physics_process(1.0/60.0)

func _walk_catwalk(body: CharacterBody3D, label: String) -> bool:
	# Walk along the original platform by the top of the east stair.
	body.position = Vector3(4.5,4.68,-4.62)
	body.velocity = Vector3.ZERO
	await _move_body(body,12)
	body.touch_motion = Vector2(1,0)
	for _segment in range(3):
		await _move_body(body,7)
		if not _require(body.is_on_floor() and absf(body.position.y-4.50) < 0.08,
				"%s actor lost floor support along the catwalk: %s" % [label,body.position]):
			return false
	body.touch_motion = Vector2.ZERO
	return _require(body.position.x > 6.2,label + " actor was blocked on the catwalk")

func _run() -> void:
	if not _require(YARD.SPAWNS == ORIGINAL_SPAWNS and YARD.PATROL == ORIGINAL_PATROL,
			"Original spawn order or patrol route changed"):
		return
	if not _require(change_scene_to_file("res://game/arena.tscn") == OK, "Client arena failed to load"):
		return
	await scene_changed
	await physics_frame
	await physics_frame
	var client := current_scene
	var client_yard := client.get_node("WarehouseYard") as Node3D
	if not _check_yard(client_yard,"client"):
		return
	var solid_faces := _shape_faces(client_yard,"YardCollision")
	var guard_faces := _shape_faces(client_yard,"BarrelPocketGuards")
	var guard_start := Vector3(-10.8,1.66,6.35)
	var guard_end := Vector3(-10.8,1.20,6.35)
	var camera_motion := guard_end-guard_start
	if not _require(client.player.collision_mask == 3 and client.has_node("ExitFrame")
			and client.marker_preview._ray(guard_start,guard_end).is_empty()
			and is_equal_approx(client._camera_clear_distance(guard_start,camera_motion),camera_motion.length()),
			"Client exit or movement/paint/camera collision contract changed"):
		return
	var frame := _ray(client,Vector3(-1.65,1.6,9.65),Vector3(-1.65,1.6,10.55),1).get("collider") as StaticBody3D
	if not _require(frame != null and frame.get_parent() == client.get_node("ExitFrame"),
			"Client exit frame stopped blocking traversal"):
		return
	client.player.set_physics_process(false)
	if not await _walk_catwalk(client.player,"Client"):
		return
	unload_current_scene()
	await physics_frame

	var authority := AUTHORITY.new()
	root.add_child(authority)
	await physics_frame
	await physics_frame
	var worker_yard := authority.arena.get_node("WarehouseYard") as Node3D
	if not _check_yard(worker_yard,"worker"):
		return
	if not _require(_shape_faces(worker_yard,"YardCollision") == solid_faces
			and _shape_faces(worker_yard,"BarrelPocketGuards") == guard_faces,
			"Client and native authority produce different warehouse collision triangles"):
		return
	var worker_exit := _ray(authority.arena,Vector3(-1.65,1.6,9.65),Vector3(-1.65,1.6,10.55),1)
	var blocker := worker_exit.get("collider") as StaticBody3D
	if not _require(blocker != null and blocker.get_parent() == authority.arena
			and authority.arena.get_script() == null and not authority.arena.has_node("ExitFrame")
			and not authority.arena.has_node("WorldHUD"),
			"Authoritative arena lost its blocker or picked up client presentation"):
		return
	if not _require(authority.open([{"slot":"one","alias":"Test One"},{"slot":"two","alias":"Test Two"}],"one",100)
			and authority.ready_slot("one",100) and authority.ready_slot("two",100),
			"Native authority failed to populate the match"):
		return
	var index := 0
	for slot: Dictionary in authority.slots.values():
		if not _require(slot.body.position.is_equal_approx(ORIGINAL_SPAWNS[index])
				and slot.body.collision_mask == 7 and slot.body.collision_layer == 4,
				"An authoritative human or bot lost its original spawn or movement mask"):
			return
		index += 1
	var body: CharacterBody3D = authority.slots["one"].body
	if not _require(authority._ray(body,guard_start,guard_end).is_empty(),
			"Authoritative paint/visibility rays hit the movement-only guard"):
		return
	for pocket: Vector2 in POCKETS:
		body.position = Vector3(pocket.x,2.25,pocket.y)
		body.velocity = Vector3.ZERO
		await _move_body(body,28)
		if not _require(body.is_on_floor() and absf(body.position.y-1.37) < 0.05,
				"Authoritative feet did not land safely at pocket %s" % pocket):
			return
		body.request_jump()
		await _move_body(body,10)
		if not _require(body.position.y >= 2.35,"Authoritative actor could not jump out of a pocket"):
			return
	for side in [-1.0,1.0]:
		body.position = Vector3(side*1.23,0.03,-side*3.22)
		body.velocity = Vector3.ZERO
		await _move_body(body,8)
		body.touch_motion = Vector2(side,0)
		await _move_body(body,120)
		if not _require(body.position.y >= 4.4,"Authoritative actor couldn't ascend a stair"):
			return
		body.touch_motion = Vector2(-side,0)
		await _move_body(body,116)
		body.touch_motion = Vector2.ZERO
		if not _require(body.is_on_floor() and body.position.y <= 0.12,
				"Authoritative actor couldn't descend a stair"):
			return
	if not await _walk_catwalk(body,"Authoritative"):
		return
	print("PASS: editable yard, identical collision, movement-only pockets, native stair/catwalk, and distinct exits")
	quit()
