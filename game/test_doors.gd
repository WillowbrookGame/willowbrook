extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	set_meta("paintball_practice_test",true)
	var town := "res://game/town.tscn"
	if change_scene_to_file(town) != OK:
		quit(1)
		return
	await scene_changed
	current_scene._try_door()
	await process_frame
	if current_scene == null or current_scene.name != "WillowbrookTown" or current_scene.enter_button.visible:
		push_error("Door accepted interaction from spawn or showed the prompt too far away")
		quit(1)
		return
	current_scene.player.position = current_scene.door_position + Vector3(0,0,1.25)
	current_scene._refresh_prompt()
	if not current_scene.enter_button.visible:
		push_error("Door prompt not visible in range")
		quit(1)
		return
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.pressed = true
	current_scene._unhandled_key_input(interact)
	await scene_changed
	if current_scene.name != "PaintballArena":
		push_error("E did not load the separate arena")
		quit(1)
		return
	current_scene.player.position = current_scene.door_position - Vector3(0,0,1.25)
	current_scene._refresh_prompt()
	if not current_scene.enter_button.visible:
		push_error("Exit prompt not visible in range")
		quit(1)
		return
	current_scene.enter_button.pressed.emit()
	await scene_changed
	if current_scene.name != "WillowbrookTown":
		push_error("On-screen exit did not return to town")
		quit(1)
		return
	print("PASS: town and arena load; proximity, E entry, and button return")
	quit(0)
