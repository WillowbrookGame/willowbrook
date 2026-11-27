extends SceneTree
## Runs the real arena controller and online view with synthetic authority packets.
## A transport fixture records view/input/leave requests without accounts or a live server.

class TestSession extends Node:
	signal paintball_packet(packet: Dictionary)
	var admitted := true
	var requests: Array[Dictionary] = []
	var forgotten := ""

	func paintball_epoch() -> String:
		return "disposable-test-match"

	func paintball_match(action: String, epoch: String, frame: Dictionary = {}) -> bool:
		requests.append({"action":action, "epoch":epoch, "frame":frame.duplicate()})
		return true

	func forget_paintball_view(epoch: String) -> void:
		forgotten = epoch


func _initialize() -> void:
	set_meta("willowbrook_save_override","")
	call_deferred("_run")


func _run() -> void:
	root.get_node("WillowbrookBrowserSession").name = "InactiveBrowserSession"
	var session := TestSession.new()
	session.name = "WillowbrookBrowserSession"
	root.add_child(session)
	set_meta("paintball_online",true)
	change_scene_to_file("res://game/arena.tscn")
	await scene_changed
	var arena := current_scene
	var online: Node = arena.arena_online
	if not _require(online != null and arena.arena_match == null and not arena.player.is_physics_processing(),"Online entry owns movement and does not start local rounds"):
		return
	arena.set_physics_process(false)
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	if not _require(arena._consume_zone_input(space) and arena._world_input_blocked(),"Loading suppresses Space and marker controls"):
		return
	var epoch := session.paintball_epoch()
	var state := {
		"round":1, "phase":"playing", "countdownMs":0, "remainingMs":75000, "events":[],
		"selfSlot":"a","hostSlot":"a","ranking":[],
		"players":[{"slot":"a", "alias":"You", "position":[0,0,7], "grounded":true, "moving":false, "points":0},
			{"slot":"b", "position":[2,0,7], "connected":true, "alias":"Test Peer", "avatar":"robot", "yaw":0, "moving":false, "immuneMs":0, "points":0}]
	}
	session.paintball_packet.emit({"type":"paintballMatch", "action":"ready", "epoch":epoch, "ok":true, "view":state})
	if not _require(online.is_playing() and online._actors.size() == 1 and online._actors["b"].node.get_meta("avatar_id","") == "robot" and not arena._consume_zone_input(space), "Playing view renders a remote peer with its avatar and enables keyboard input"):
		return
	# Verify online tag hitmarker and visor paint splat events.
	state.events = [
		{"eid":1, "kind":"paint", "slot":"a", "tagged":"b", "immuneMs":2200, "from":[0,1,7], "to":[2,1,7]},
		{"eid":2, "kind":"paint", "slot":"b", "tagged":"a", "immuneMs":2200, "from":[2,1,7], "to":[0,1,7]},
	]
	session.paintball_packet.emit({"type":"paintballMatch", "action":"view", "epoch":epoch, "ok":true, "view":state})
	if not _require(arena.hitmarker.visible and arena.visor_splat.visible and arena.visor_splat.remaining > 1.5, "Online paint tag events did not trigger hitmarker and visor paint splat"):
		return
	state.events = []
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	arena._unhandled_input(mouse)
	arena._unhandled_key_input(space)
	online._pending = ""
	online._next = 0
	online.tick(0.1)
	var input: Dictionary = session.requests.back()
	if not _require(input.action == "input" and input.frame.paint and input.frame.jump,"Mouse and keyboard reach the authority frame"):
		return
	arena.camera_thumbstick.show()
	arena._process(0.0)
	if not _require(arena.touch_fire_button.visible and arena.jump_button.visible,"Touch controls appear during play"):
		return
	arena.touch_fire_button.pressed.emit()
	if not _require(online._frame().paint,"Touch Fire reaches the same authority input"):
		return
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	arena._gamepad = arena.GAMEPAD.new()
	arena._gamepad_blurred = false
	arena._gamepad_connected_grace_until = 0
	arena._route_gamepad(trigger)
	if not _require(online._frame().paint,"Gamepad primary reaches the same authority input"):
		return
	arena._world_primary_action()
	arena._request_world_jump()
	arena._reset_input_context()
	var cleared: Dictionary = online._frame()
	if not _require(not cleared.paint and not cleared.jump,"Reset clears queued shot and jump"):
		return
	state.phase = "between"
	session.paintball_packet.emit({"type":"paintballMatch", "action":"input", "epoch":epoch, "ok":true, "view":state})
	arena._process(0.0)
	arena.touch_fire_button.pressed.emit()
	if not _require(arena._consume_zone_input(space) and not arena.touch_fire_button.visible and not online._frame().paint,"Scoreboard blocks Space and Fire again"):
		return
	online.leave()
	if not _require(session.requests.back().action == "leave","Leave is sent through the match session"):
		return
	session.paintball_packet.emit({"type":"paintballMatch","action":"leave","epoch":epoch,"ok":true,"returnTown":true})
	await scene_changed
	if not _require(current_scene.name == &"WillowbrookTown" and current_scene.player.position.distance_to(current_scene.door_position) < 2.0 and session.forgotten == epoch,"Acknowledged leave restores the Town entrance"):
		return
	print("PASS: online arena entry, remote peer, keyboard/mouse/touch/gamepad routing, round gates and Town return")
	quit()


func _require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
