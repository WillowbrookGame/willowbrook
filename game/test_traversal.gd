extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _tick(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	if change_scene_to_file("res://game/arena.tscn") != OK:
		quit(1)
		return
	await scene_changed
	var map := current_scene
	var p: CharacterBody3D = map.player
	for side in [-1.0, 1.0]:
		p.position = Vector3(side * 1.23, 0.03, -side * 3.22)
		p.velocity = Vector3.ZERO
		await _tick(8)
		var up := "left" if side < 0.0 else "right"
		p.held[up] = true
		await _tick(120)
		p.held.clear()
		print("stair top ", side, ": ", p.position)
		if p.position.y < 4.4:
			push_error("Couldn't walk up the stairs")
			quit(1)
			return
		var down := "right" if side < 0.0 else "left"
		p.held[down] = true
		await _tick(116)
		p.held.clear()
		if p.position.y > 0.12 or not p.is_on_floor():
			push_error("Couldn't walk down the stairs: %s" % p.position)
			quit(1)
			return
	p.position = Vector3(-11.45,0.02,7.98)
	p.velocity = Vector3.ZERO
	await _tick(8)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	map._unhandled_key_input(key)
	await _tick(18)
	if p.position.y < 1.7:
		push_error("Space didn't jump")
		quit(1)
		return
	p.held["up"] = true
	await _tick(12)
	p.held.clear()
	await _tick(45)
	if absf(p.position.y-1.8) > 0.08 or not p.is_on_floor():
		push_error("Didn't land on warehouse barrier: %s" % p.position)
		quit(1)
		return
	print("PASS: both warehouse stairs up/down, Space jump, and landing on real arena cover")
	quit()
