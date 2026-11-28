extends SceneTree

const SKYHILL := preload("res://game/skyhill/skyhill.tscn")
const FRAME := 1.0 / 60.0

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var level := SKYHILL.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(level.state == level.State.DECK, "Should start on the deck")
	check(level.get_node("Glider/RiderAnchor").get_child_count() == 1, "Rider did not load")
	var launch: Vector3 = level.launch.global_position
	check(level.flight.position.is_equal_approx(launch), "Authored launch placement was ignored")

	level._action()
	for _i in 780:
		if level.state != level.State.FLYING:
			break
		level.step_flight(FRAME, 0.0)
	check(level.state == level.State.MEADOW, "Hands-free route should land automatically")
	var direct_z: float = level.flight.position.z
	check(level.in_meadow(level.flight.position), "Direct route touched down outside the meadow")
	level._action()
	check(level.state == level.State.DECK and level.flight.position == launch, "Ride should return to launch")

	level._action()
	var peak_lift := 0.0
	var rose := false
	var crossed_ridge := false
	var ridge_height := 0.0
	for _i in 960:
		if level.state != level.State.FLYING:
			break
		var p: Vector3 = level.flight.position
		var aim_x := 25.0
		var aim_z := -32.0 if p.z > -24.0 else p.z - 20.0
		var target := Vector3(aim_x, p.y, aim_z) - p
		var yaw := atan2(-target.x, -target.z)
		var steer := clampf(angle_difference(yaw, level.flight.heading) * 2.7, -1.0, 1.0)
		level.step_flight(FRAME, steer)
		peak_lift = maxf(peak_lift, level.flight.lift)
		rose = rose or (level.flight.lift > .5 and level.flight.position.y > p.y)
		if level.flight.position.z < -78.0 and not crossed_ridge:
			crossed_ridge = true
			ridge_height = level.flight.position.y
	check(peak_lift > .85 and rose, "Waterfall route did not lift the glider")
	check(crossed_ridge and ridge_height > 11.5, "Scenic route did not clear the ridge")
	check(level.state == level.State.MEADOW and level.flight.position.z < direct_z - 8.0, "Scenic route should land farther down the meadow")
	level._action()
	level._action()
	level.step_flight(FRAME, 1.0)
	check(level.flight.heading < 0 and level.flight.bank < 0, "Right steering must turn and visibly bank right")
	level._action()
	check(level.state == level.State.DECK and level.flight.position == launch, "Return should work mid-air")
	level._action()
	level.flight.position = Vector3(106, 18, -25)
	level.step_flight(FRAME, 0)
	check(level.state == level.State.DECK, "Out-of-bounds glider was not recovered")

	for view in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = view
		level._touch_seen = true
		level._launch()
		await process_frame
		check(not level.stick.get_global_rect().intersects(level.action.get_global_rect()), "Touch stick and return overlap at %s" % view)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.index = 3
		touch.position = level.stick.get_global_rect().get_center() + Vector2(25, 0)
		level._input(touch)
		check(level.touch_index == 3 and level.touch_steer > .5, "Touch steering did not accept press")
		touch.pressed = false
		level._input(touch)
		check(level.touch_index == -1 and level.touch_steer == 0, "Touch release did not clear steering")
		level._on_deck()
	if failures == 0:
		print("PASS Skyhill: default and waterfall routes, auto-land, relaunch, return, bounds and responsive touch")
	level.free()
	quit(0 if failures == 0 else 1)
