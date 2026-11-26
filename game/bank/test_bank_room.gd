extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const SCENE := "res://game/bank/room.tscn"
const LAYOUT := "res://game/bank/room_layout.tscn"

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
	profile.stars = 150
	profile.employed = "bank"
	if not expect(current_scene.profile_commit(profile), "Could not seed disposable profile"): return
	var door: Vector3 = TOWN.BUSINESS_DOORS["bank"]
	for visit in range(2):
		var town := current_scene
		town.player.position = door + Vector3(0,.04,1.3)
		interact(town)
		if not expect(town.changing, "Town interaction did not enter Bank"): return
		await scene_changed
		var map := current_scene
		var room: Node3D = map.room
		if not expect(map.room_id == "bank" and room.scene_file_path == SCENE and room.id == "bank", "Bank module was not loaded"): return
		if not expect(map.player.position.is_equal_approx(Vector3(0,.04,5.5)), "Bank spawn moved"): return
		if not expect(room.art.public_seats.size() == 2 and room.art.conversation_actor != null, "Bank seats or clerk changed"): return
		await physics_frame
		await physics_frame
		if not _check_layout(map, room): return
		map.player.position = Vector3(0,.04,1.2)
		interact(map)
		if not expect(room.is_modal_open() and room.active_panel == "bank", "Bank interaction did not open teller panel"): return
		if visit == 0:
			var apply: Array[Node] = []
			for node in room.fields.find_children("*", "Button", true, false):
				if node.text.begins_with("Apply for starter home"): apply.append(node)
			if not expect(apply.size() == 1 and not apply[0].disabled, "Mortgage application absent or disabled after hire"): return
			apply[0].pressed.emit()
			room._repay(10)
		var saved: Dictionary = map.profile_snapshot()
		if not expect(saved.stars == 140 and int(saved.loan.get("balance", -1)) == 90, "Bank loan deduction, terms, or persistence changed"): return
		room.close_modal()
		map.player.position = Vector3(0,.04,6.55)
		interact(map)
		if not expect(map.changing, "Could not leave Bank through Town door"): return
		await scene_changed
		if not expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,2.0)), "Client Town return moved"): return
	print("PASS: isolated Bank scene, existing door/spawn, two visits, one zero-upfront starter loan, one ten-star payment, same balance on revisit.")
	quit(0)

func _check_layout(map: Node3D, room: Node3D) -> bool:
	if not expect(room.art.scene_file_path == LAYOUT, "Bank did not load the authored layout"): return false
	var chair: Node3D = room.art.get_node("WaitingChairNear")
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var expected := Vector3(-5,0,1) if edited else Vector3(-6,0,1)
	if not expect(chair.position.is_equal_approx(expected), "Saved chair placement did not reach gameplay"): return false
	if not expect(room.art.public_seats[0].chair == chair and room.art.conversation_actor == room.art.get_node("Teller"), "Seat or teller not attached to the authored prop"): return false
	var ray := PhysicsRayQueryParameters3D.create(chair.global_position+Vector3.UP*3.0, chair.global_position+Vector3.UP*.1, 1)
	var space := chair.get_world_3d().direct_space_state
	if not expect(space.intersect_ray(ray).get("collider") == chair.get_node("SolidBody"), "The chair collider did not follow"): return false
	if edited:
		var old_ray := PhysicsRayQueryParameters3D.create(Vector3(-6,2,1),Vector3(-6,.1,1),1)
		if not expect(space.intersect_ray(old_ray).is_empty(), "A collider was left at the previous chair spot"): return false
	map.player.position = chair.position+Vector3(1.2,.04,0)
	var nearby: Dictionary = room._near_seat()
	var sit_at: Vector3 = map.player.get_parent().to_local(chair.to_global(room.art.public_seats[0].surface))
	if not expect(not nearby.is_empty() and nearby.at.is_equal_approx(sit_at), "The sit interaction did not follow"): return false
	var group: Node3D = room.art.get_node("JobStations")
	var props: Dictionary = room.job_art.props
	if not expect(group.get_child_count() == 5 and props.size() == 5, "A job station is missing or duplicated"): return false
	for prop: Dictionary in props.values():
		var station: Node3D = prop.ring.get_parent()
		if not expect(station.get_parent() == group and station.get_node("TableTop").visible and not prop.ring.visible, "Job art or live highlight was not bound to the authored station"): return false
		var body := station.get_node_or_null("TableBody") as StaticBody3D
		if not expect(body != null, "Missing Bank table collider"): return false
		var origin := station.global_position
		var table_ray := PhysicsRayQueryParameters3D.create(origin+Vector3.UP,origin+Vector3.UP*.1,1)
		if not expect(space.intersect_ray(table_ray).get("collider") == body, "Bank table collision does not match the visible table"): return false
	return true
