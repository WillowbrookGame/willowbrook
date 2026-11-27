extends SceneTree
const REEF := "res://game/scuba/reef.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, msg: String) -> bool:
	if not ok:
		push_error(msg)
		quit(1)
	return ok

func _mouse_button(button: MouseButton, pressed := true) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	ev.position = Vector2(320, 200)
	return ev

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev

func _run() -> void:
	if change_scene_to_file(REEF) != OK:
		quit(1)
		return
	await scene_changed
	var reef := current_scene
	await process_frame
	if not _require(not reef._is_mouse_looking(), "Reef should start with visible cursor"):
		return
	# Left-click must never capture the mouse.
	reef._unhandled_input(_mouse_button(MOUSE_BUTTON_LEFT, true))
	if not _require(not reef._is_mouse_looking(), "Left-click should not capture mouse-look in Scuba"):
		return
	# Right-click toggles mouse-look on, and mouse motion turns the camera.
	reef._unhandled_input(_mouse_button(MOUSE_BUTTON_RIGHT, true))
	if not _require(reef._is_mouse_looking(), "Right-click did not engage mouse-look in Scuba"):
		return
	var yaw_before: float = reef._yaw
	var motion := InputEventMouseMotion.new()
	motion.device = 0
	motion.screen_relative = Vector2(40.0, 0.0)
	reef._input(motion)
	if not _require(not is_equal_approx(reef._yaw, yaw_before), "Mouse motion did not rotate camera while captured"):
		return
	# Right-click again releases mouse-look.
	reef._input(_mouse_button(MOUSE_BUTTON_RIGHT, true))
	if not _require(not reef._is_mouse_looking(), "Second right-click did not release mouse-look"):
		return
	# C toggles mouse-look on, and Esc releases it.
	reef._unhandled_input(_key(KEY_C))
	if not _require(reef._is_mouse_looking(), "C key did not engage mouse-look"):
		return
	reef._unhandled_input(_key(KEY_ESCAPE))
	if not _require(not reef._is_mouse_looking(), "Esc did not release mouse-look"):
		return
	# Modal open releases mouse-look cleanly.
	reef._unhandled_input(_key(KEY_C))
	reef.set_zone_modal(true)
	if not _require(not reef._is_mouse_looking(), "Opening a modal did not release mouse-look"):
		return
	print("PASS: Scuba right-click/C toggle mouse-look, Esc/modal release, and left-click stays free")
	quit()
