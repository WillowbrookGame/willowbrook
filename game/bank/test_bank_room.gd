extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const SCENE := "res://game/bank/room.tscn"

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
