extends SceneTree

const REEF := "res://game/scuba/reef.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _run() -> void:
	if change_scene_to_file(REEF) != OK:
		quit(1)
		return
	await scene_changed
	var reef := current_scene
	reef.set_physics_process(false)
	var diver: CharacterBody3D = reef.diver
	var origin := diver.position
	var hint: Label = reef.hud.get_node("SwimHint")
	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	reef._physics_process(1.0 / 60.0)
	var moved_forward := Vector2(diver.velocity.x, diver.velocity.z).length() > 0.1
	var descended := diver.velocity.y < -0.1
	_key(KEY_SHIFT, false)
	diver.position = origin
	diver.velocity = Vector3.ZERO
	_key(KEY_CTRL, true)
	reef._physics_process(1.0 / 60.0)
	var ctrl_did_not_dive := is_zero_approx(diver.velocity.y)
	_key(KEY_CTRL, false)
	_key(KEY_W, false)
	if not (moved_forward and descended and ctrl_did_not_dive and "Space/Shift" in hint.text and "Ctrl" not in hint.text):
		push_error("Reef must advertise Shift, allow W+Shift to swim forward and down, and not bind Ctrl to dive")
		quit(1)
		return
	print("PASS: W+Shift swims forward and down; Ctrl is not a dive key; hint matches binding")
	quit()