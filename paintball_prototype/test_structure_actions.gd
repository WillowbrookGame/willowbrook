extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _check(world: Node, allowed: bool, reason: String) -> int:
	world.player.jump_buffer = 0.0
	world._request_world_jump()
	var actual_jump: bool = world.player.jump_buffer > 0.0
	var actual_menu: bool = world.can_open_network_menu()
	if actual_jump == allowed and actual_menu == allowed:
		return 0
	push_error("%s: expected %s, jump %s, menu %s" % [reason, allowed, actual_jump, actual_menu])
	return 1


func _run() -> void:
	if change_scene_to_file("res://paintball_prototype/town.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var town := current_scene
	var failures := _check(town, true, "Town idle")
	town.set_zone_modal(true)
	failures += _check(town, false, "Modal")
	town.set_zone_modal(false)
	town.changing = true
	failures += _check(town, false, "Changing zone")
	town.changing = false
	town.player.set_physics_process(false)
	failures += _check(town, false, "Player physics off")
	town.player.set_physics_process(true)
	town.slide_time = 0.2
	failures += _check(town, false, "Slide in progress")
	town.slide_time = -1.0
	town.playground.ride = "swing"
	failures += _check(town, false, "Playground ride")
	town.playground.ride = ""
	failures += _check(town, true, "Restored controls")
	if failures == 0:
		print("PASS: both control actions agree through seven world states")
	quit(1 if failures > 0 else 0)
