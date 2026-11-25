extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const SCENE := "res://game/vet/room.tscn"

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func interact(map: Node3D) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	map._unhandled_key_input(event)

func _run() -> void:
	set_meta("willowbrook_save_override", "")
	set_meta("fishing_save_override", "")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var profile: Dictionary = current_scene.profile_snapshot()
	profile.stars = 32
	if not expect(current_scene.profile_commit(profile), "Could not seed disposable profile"): return
	var door: Vector3 = TOWN.BUSINESS_DOORS["vet"]
	for visit in range(2):
		var town := current_scene
		town.player.position = door + Vector3(0,.04,1.3)
		interact(town)
		if not expect(town.changing, "Town interaction did not enter Vet"): return
		await scene_changed
		var map := current_scene
		var room: Node3D = map.room
		if not expect(map.room_id == "vet" and room.scene_file_path == SCENE and room.id == "vet", "Vet module was not loaded"): return
		if not expect(map.player.position.is_equal_approx(Vector3(0,.04,5.5)), "Vet spawn moved"): return
		if not expect(room.art.public_seats.size() == 2 and room.art.conversation_actor != null, "Vet seats or clerk changed"): return
		await physics_frame
		await physics_frame
		if not _check_layout(map, room): return
		map.player.position = Vector3(0,.04,1.2)
		interact(map)
		if not expect(room.is_modal_open() and room.active_panel == "vet", "Vet interaction did not open adoption"): return
		var adopt: Array[Node] = []
		for node in room.fields.find_children("*", "Button", true, false):
			if node.text.begins_with("Adopt"): adopt.append(node)
		if not expect(adopt.size() == 1, "Adoption control absent or duplicated"): return
		if visit == 0: adopt[0].pressed.emit()
		var saved: Dictionary = map.profile_snapshot()
		if not expect(saved.stars == 24 and saved.pets.owned.size() == 1, "Adoption cost or persistence changed"): return
		room.close_modal()
		map.player.position = Vector3(0,.04,6.55)
		interact(map)
		if not expect(map.changing, "Could not leave Vet through Town door"): return
		await scene_changed
		if not expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,2.0)), "Client Town return moved"): return
	print("PASS: isolated Vet scene, existing door/spawn, two visits, one adoption and eight-star deduction, persisted pet and no duplicate action.")
	quit(0)

func _check_layout(map: Node3D, room: Node3D) -> bool:
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var chair: Node3D = room.art.get_node("WaitingChairNear")
	var plant: Node3D = room.art.get_node("LeftPlant")
	var authored := (load("res://game/vet/room_layout.tscn") as PackedScene).instantiate()
	var chair_at: Vector3 = authored.get_node("WaitingChairNear").position
	var plant_at: Vector3 = authored.get_node("LeftPlant").position
	authored.free()
	if edited and not expect(chair_at.is_equal_approx(Vector3(-4.5,0,1)) and plant_at.is_equal_approx(Vector3(-7.5,0,4.2)), "The edited scene fixture was not saved"): return false
	if not expect(room.art.scene_file_path == "res://game/vet/room_layout.tscn", "Runtime did not use the authored layout"): return false
	if not expect(chair.position.is_equal_approx(chair_at) and plant.position.is_equal_approx(plant_at), "Saved furniture transforms did not reach gameplay"): return false
	if not expect(room.art.public_seats[0].chair == chair, "Seat was not bound to the saved chair"): return false
	for prop: Node3D in [chair,plant]:
		var body: StaticBody3D = prop.get_node("SolidBody")
		var model: Node3D = prop.get_node("Model")
		if not expect(body.collision_layer == 3 and body.collision_mask == 0 and model.get_child_count() > 0, "Furniture geometry or collision changed"): return false
		var hit := prop.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(prop.global_position + Vector3.UP*3.0, prop.global_position + Vector3.UP*.1, 1))
		if not expect(hit.get("collider") == body, "Collision did not follow the authored prop"): return false
	map.player.position = chair.position + Vector3(1.2,.04,0)
	var nearest: Dictionary = room._near_seat()
	var expected_placement: Vector3 = map.player.get_parent().to_local(chair.to_global(room.art.public_seats[0].surface))
	if not expect(not nearest.is_empty() and nearest.at.is_equal_approx(expected_placement), "Seat interaction did not follow the authored chair"): return false
	if edited:
		var old_hit := chair.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-6,2,1),Vector3(-6,.1,1),1))
		if not expect(old_hit.is_empty(), "A second collider was left at the old chair position"): return false
	return true
