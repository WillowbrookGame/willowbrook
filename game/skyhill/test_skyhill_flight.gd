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

func check_facing(level: Node3D) -> void:
	var glider := level.get_node("Glider") as Node3D
	var nose := glider.get_node("Sail/Nose") as Marker3D
	var rider := glider.get_node("RiderAnchor") as Marker3D
	var heading := Vector3.FORWARD.rotated(Vector3.UP, level.flight.heading)
	var nose_forward := nose.global_position - glider.global_position
	nose_forward.y = 0.0
	var rider_forward := rider.global_basis.z
	rider_forward.y = 0.0
	check(nose_forward.normalized().dot(heading) > 0.95, "The sail nose faces away from flight")
	check(rider_forward.normalized().dot(heading) > 0.95, "The rider faces away from flight")

func _run() -> void:
	var level := SKYHILL.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	check_facing(level)
	check(level.state == level.State.DECK, "Should start on the deck")
	check(level.get_node("Glider/RiderAnchor").get_child_count() == 1, "Rider did not load")
	var launch: Vector3 = level.launch.global_position
	check(level.flight.position.is_equal_approx(launch), "Authored launch placement was ignored")

	level._action()
	var coast_frames := 0
	var touchdown := Vector3.ZERO
	var previous_speed := INF
	for _i in 780:
		if level.state != level.State.FLYING and level.state != level.State.LANDING:
			break
		level.step_flight(FRAME, 0.0)
		if level.state == level.State.LANDING:
			if coast_frames == 0:
				touchdown = level.flight.position
				check(level.flight.speed > 8.0 and level.flight.speed < level.FLIGHT.SPEED - 3.0, "Approach should slow before touchdown without stopping")
			coast_frames += 1
			check(level.flight.speed <= previous_speed, "Landing runout must keep slowing down")
			previous_speed = level.flight.speed
	check(coast_frames > 45 and touchdown.distance_to(level.flight.position) > 5.0 and level.flight.speed == 0.0, "Landing should coast visibly before stopping")
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
		if level.state != level.State.FLYING and level.state != level.State.LANDING:
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
	check_facing(level)
	check(level.flight.heading < 0 and level.flight.bank < 0, "Right steering must turn and visibly bank right")
	check(absf(level.flight.heading) < level.FLIGHT.TURN_RATE * FRAME * 0.2, "Steering should not jump to full rate on the first frame")
	for _i in 18:
		level.step_flight(FRAME, 1.0)
	var prior_heading: float = level.flight.heading
	level.step_flight(FRAME, 0.0)
	check(level.flight.heading < prior_heading, "Releasing steering should ease out, not snap")
	for _i in 42:
		level.step_flight(FRAME, 0.0)
	check(absf(level.flight.steering) < 0.03 and absf(level.flight.bank) < 0.03, "Released steering should settle quickly")
	level._action()
	check(level.state == level.State.DECK and level.flight.position == launch, "Return should work mid-air")
	level._action()
	level.flight.position = Vector3(106, 18, -25)
	level.step_flight(FRAME, 0)
	check(level.state == level.State.DECK, "Out-of-bounds glider was not recovered")

	level._launch()
	var near_edge: Vector3 = level.meadow.to_global(Vector3(0.0, level.GROUND_CLEARANCE, -level.landing_bounds.size.z * 0.5 + 2.0))
	level._land(near_edge)
	for _i in 90:
		level.step_flight(FRAME, 1.0)
	check(level.state == level.State.MEADOW and level.in_meadow(level.flight.position), "Short landing must stop inside the meadow")
	check(absf(level.flight.position.distance_to(near_edge) - 1.5) < 0.02, "Runout must shorten at the edge without turning")
	level._action()

	for view in [Vector2i(360, 640), Vector2i(640, 360), Vector2i(1280, 720)]:
		root.size = view
		level._touch_seen = true
		level._launch()
		await process_frame
		check(not level.stick.get_global_rect().intersects(level.action.get_global_rect()), "Touch stick and return overlap at %s" % view)
		level._update_route_guide()
		var guide_rect: Rect2 = level.guide.get_global_rect()
		check(level.guide.visible, "Waterfall guide should appear ahead at %s" % view)
		check(root.get_visible_rect().encloses(guide_rect), "Guide escapes viewport at %s" % view)
		check(not guide_rect.intersects(level.prompt.get_global_rect()) and not guide_rect.intersects(level.stick.get_global_rect()) and not guide_rect.intersects(level.action.get_global_rect()), "Guide overlaps instructions or controls at %s" % view)
		level.flight.lift = 0.5
		level._update_route_guide()
		check(level.guide_label.text == "Rising air!", "Guide confirms caught lift")
		level.flight.lift = 0.0
		level.flight.heading = PI
		level._update_route_guide()
		check(not level.guide.visible, "Guide should hide after passing or turning away")
		level.flight.heading = 0.0
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.index = 3
		touch.position = level.stick.get_global_rect().get_center() + Vector2(25, 0)
		level._input(touch)
		check(level.touch_index == 3 and level.touch_steer > .5, "Touch steering did not accept press")
		var drag := InputEventScreenDrag.new()
		drag.position = level.stick.get_global_rect().get_center() + Vector2(-90, 0)
		drag.index = 7
		level._input(drag)
		check(level.touch_steer > .5, "Second finger stole the steering stick")
		drag.index = touch.index
		level._input(drag)
		check(level.touch_steer == -1.0, "Touch should track outside the stick")
		drag.position = level.stick.get_global_rect().get_center() + Vector2(3.0, 0)
		level._input(drag)
		check(level.touch_steer == 0.0, "Stick should ignore minor center jitter")
		touch.pressed = false
		level._input(touch)
		check(level.touch_index == -1 and level.touch_steer == 0, "Touch release did not clear steering")
		level._on_deck()
	if failures == 0:
		print("PASS Skyhill: gentle steering, default and waterfall routes, landing runout, relaunch, return, bounds, waterfall cues and responsive touch")
	level.free()
	quit(0 if failures == 0 else 1)
