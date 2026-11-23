extends SceneTree
const BEACH := "res://game/beach.tscn"
const RECOVERY = preload("res://game/beach_recovery.gd")
var failures := 0

func _initialize() -> void:
	create_timer(14).timeout.connect(func(): push_error("Beach diagnostic timed out"); quit(1))
	call_deferred("_run")


func _run() -> void:
	# Never migrate or write a player's regular profile on this run.
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file(BEACH)
	await scene_changed
	var beach := current_scene
	var player: CharacterBody3D = beach.player
	var fishing: Node3D = beach.fishing_ui
	# Immediate void drop with no grounded sample exercises validated fallback.
	player.position = Vector3(12,-1,-21)
	await _frames(3)
	_check(player.position.distance_to(RECOVERY.FALLBACKS[0]) < .25,"No valid checkpoint uses solid beach spawn")

	player.position = Vector3(0,.66,-15)
	player.velocity = Vector3.ZERO
	await _frames(16)
	_check(beach.beach_recovery.last_safe.distance_to(Vector3(0,.635,-15))<.15,"Safe grounded deck point gets recorded")
	var checkpoint: Vector3 = beach.beach_recovery.last_safe
	beach._request_world_jump()
	await _frames(9)
	_check(player.position.y>1.1 and beach.beach_recovery.last_safe.is_equal_approx(checkpoint),"A legitimate deck jump doesn't reset, and airborne positions aren't checkpoints")
	await _frames(68)
	_check(player.is_on_floor() and player.position.z<-14.7,"A normal jump lands on the deck without teleporting")

	fishing.game.equip_pole()
	fishing.game.inventory.append("tetra")
	fishing.game.stars = 17
	var cast_from: Vector3 = player.position
	fishing.cast_origin = cast_from
	fishing.game.cast_at(Vector3(7,-.17,-15))
	fishing.splash_pending = true
	player.position = Vector3(6,1.6,-15)
	# Carry nonzero controls into the fall and let actual gravity take the player below water.
	player.velocity = Vector3(0,-3,0)
	var crossed_void := false
	var last := player.position
	for i in range(45):
		await physics_frame
		if player.position.x < 2.19:
			crossed_void = true
			break
		last = player.position
	_check(crossed_void and last.y < 0.0 and player.position.distance_to(checkpoint) < .18,"A genuine ungrounded fall returns to the last pier checkpoint")
	_check(fishing.game.line.is_empty() and fishing.game.equipped and fishing.game.inventory==["tetra"] and fishing.game.stars==17
		and not fishing.splash_pending and not fishing.bobber.visible,"Recovery clears fishing line, not the equipped pole, catch bag, or stars")
	# Force a second void frame while stale touch/jump/velocity are all present.
	fishing.game.cast_at(Vector3(8,-.17,-15))
	fishing.splash_pending = true
	player.position = Vector3(6,-.95,-15)
	player.velocity = Vector3(3,-8,-3)
	player.held["up"] = true
	player.jump_buffer = .09
	beach._touches._look_index = 1
	beach._touches._touches[1] = {"kind":"look"}
	beach._touches._mouse_stick = true
	player.touch_motion = Vector2.UP
	await _frames(2)
	_check(player.held.is_empty() and player.jump_buffer==0.0 and beach._touches._look_index==-1 and beach._touches._touches.is_empty() and not beach._touches._mouse_stick and player.touch_motion == Vector2.ZERO
		and absf(player.velocity.x)<.05 and absf(player.velocity.z)<.05 and absf(player.velocity.y)<1.0,"Recovery resets stale input, aim finger, and falling velocity")
	_check(fishing.game.line.is_empty() and not fishing.splash_pending and fishing.game.equipped,"A live cast is canceled by recovery in the same physics frame")
	await _frames(8)
	var from := player.position
	beach._request_world_jump()
	await _frames(9)
	_check(player.position.y>from.y+.4,"Jump controls work after recovery")

	# Finish an ordinary beach slide and verify its landing remains authoritative.
	player.position = beach.beach_scenery.SLIDE_ENTRY
	player.velocity = Vector3.ZERO
	beach._interact()
	_check(beach.slide_time>=0.0,"Slide boarding still works")
	beach.slide_time = beach.beach_scenery.SLIDE_SECONDS-.035
	_check(fishing.game.line.is_empty() and not fishing.splash_pending and fishing.game.equipped,"A live cast is canceled by recovery in the same physics frame")
	await _frames(8)
	_check(beach.slide_time<0.0 and player.is_physics_processing() and player.position.distance_to(Vector3(-46.05,.04,14.35))<.3,"Recovery doesn't override the slide's on-land exit")
	print("Beach water recovery checks: ",failures," failures")
	quit(failures)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
