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

func keyboard_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func check_pitch_controls(level: Node3D) -> void:
	var start: Vector3 = level.launch.global_position
	for pair in [[KEY_W, -1], [KEY_S, 1], [KEY_UP, -1], [KEY_DOWN, 1]]:
		level._launch()
		keyboard_event(pair[0], true)
		for _i in 36:
			level._physics_process(FRAME)
		keyboard_event(pair[0], false)
		check(level.state == level.State.FLYING, "Pitch input should leave the glider flying")
		var pitch: float = level.flight.pitch
		check(pitch * pair[1] > 0.15, "Wrong visual pitch for key %s" % pair[0])
		check((level.flight.position.y - start.y) * pair[1] > 0.06, "Wrong vertical travel for key %s" % pair[0])
		check(is_equal_approx(level.get_node("Glider").rotation.x, pitch), "Flight pitch was not shown on the glider")
		level._physics_process(FRAME)
		check(absf(level.flight.pitch) < absf(pitch) and absf(level.flight.pitch) > 0.1, "Released pitch should ease back")
		level._on_deck()
		check(level.flight.pitch == 0.0, "Returning to deck should reset pitch")
	level._launch()
	keyboard_event(KEY_W, true)
	keyboard_event(KEY_S, true)
	level._physics_process(FRAME)
	keyboard_event(KEY_W, false)
	keyboard_event(KEY_S, false)
	check(level.flight.pitch == 0.0 and level.flight.climb < 0.0, "Opposing pitch keys should cancel")
	level._on_deck()

	var flight = level.FLIGHT.new()
	flight.reset(Vector3.ZERO, 0.0)
	for _i in 180:
		flight.advance(FRAME, 0.0, 0.0, INF, 1.0, 0.0)
	check(flight.climb < 0.0, "Manual pitch must not climb past the course ceiling")
	for _i in 90:
		flight.advance(FRAME, 0.0, 1.0, INF, 1.0, 0.0)
	check(flight.climb > 4.0, "Waterfall lift must still work above the manual climb ceiling")
	for _i in 90:
		flight.advance(FRAME, 0.0, 0.0, 0.01, -1.0)
	check(flight.speed < 10.1 and flight.climb > -1.0, "Holding dive near the meadow should not defeat the landing flare")

func _run() -> void:
	var level := SKYHILL.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	var terrain_space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var shoulder := terrain_space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(75, 35, -130), Vector3(75, -8, -130), 1))
	check(not shoulder.is_empty() and shoulder.position.y > 2.0, "Sloped valley terrain should carry its collision")
	var basin := terrain_space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30, 4, -30), Vector3(30, -8, -30), 1))
	check(not basin.is_empty() and absf(basin.position.y + 1.0) < 0.05, "Creek basin must stay below the course")
	check(level.get_node("Scenery/Creek").scene_file_path.ends_with(".glb"), "Creek should be an independently editable art asset")
	for cliff_group in ["LaunchBluff", "WestCliffs", "EastCliffs", "ScenicRidge"]:
		var cliff: Node3D = level.get_node("Scenery/" + cliff_group)
		for piece in cliff.get_children():
			check(not piece.find_children("*", "CollisionShape3D", true, false).is_empty(), "Missing mesh collision on %s" % piece.name)
	# Test a lateral approach toward the west face without expecting a rectangle.
	var wall := terrain_space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-18, 4, -37), Vector3(-46, 4, -37), 1))
	check(not wall.is_empty() and level.get_node("Scenery/WestCliffs").is_ancestor_of(wall.collider), "West cliff face should stop a lateral flight")
	check_facing(level)
	check(level.state == level.State.DECK, "Should start on the deck")
	check(level.get_node("Glider/RiderAnchor").get_child_count() == 1, "Rider did not load")
	var launch: Vector3 = level.launch.global_position
	check(level.flight.position.is_equal_approx(launch), "Authored launch placement was ignored")
	check_pitch_controls(level)

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
		level.step_flight(FRAME, 1.0, -1.0)
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
		var lift_position: Vector3 = level.lift_zone.position
		level._camera_pose(1.0)
		for side in [-1.0, 1.0]:
			level.lift_zone.position.x = 300.0 * side
			level._update_route_guide()
			var expected := "< Waterfall lift" if side < 0 else "Waterfall lift >"
			check(level.guide.visible and level.guide_label.text == expected, "Offscreen cue should point toward the waterfall")
			var edge_rect: Rect2 = level.guide.get_global_rect()
			for _i in 5:
				level._update_route_guide()
			check(level.guide_label.text == expected and level.guide.get_global_rect().is_equal_approx(edge_rect), "Offscreen cue should stay steady on repeated updates")
			check(root.get_visible_rect().encloses(edge_rect) and is_equal_approx(edge_rect.size.x, guide_rect.size.x), "Arrow variant should fit without changing guide width")
		level.lift_zone.position = lift_position
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
		check(level.touch_index == 3 and level.touch_steer > .5 and level.touch_pitch == 0.0, "Horizontal touch input should only steer")
		var drag := InputEventScreenDrag.new()
		drag.position = level.stick.get_global_rect().get_center() + Vector2(-90, -90)
		drag.index = 7
		level._input(drag)
		check(level.touch_steer > .5 and level.touch_pitch == 0.0, "Second finger stole the flight stick")
		drag.index = touch.index
		level._input(drag)
		check(level.touch_steer == -1.0 and level.touch_pitch == -1.0, "Diagonal touch should steer and descend outside the stick")
		drag.position = level.stick.get_global_rect().get_center() + Vector2(0, 90)
		level._input(drag)
		var touch_start: Vector3 = level.flight.position
		for _i in 36:
			level._physics_process(FRAME)
		check(level.touch_steer == 0.0 and level.touch_pitch == 1.0 and level.flight.position.y > touch_start.y, "Touch down should climb without steering")
		drag.position = level.stick.get_global_rect().get_center() + Vector2(3.0, -3.0)
		level._input(drag)
		check(level.touch_steer == 0.0 and level.touch_pitch == 0.0, "Stick should ignore minor center jitter")
		touch.pressed = false
		level._input(touch)
		check(level.touch_index == -1 and level.touch_steer == 0.0 and level.touch_pitch == 0.0, "Touch release did not clear flight inputs")
		check(level.knob.get_global_rect().get_center().is_equal_approx(level.stick.get_global_rect().get_center()), "Released touch knob did not return to center")
		level._on_deck()
	if failures == 0:
		print("PASS Skyhill: keyboard and touch pitch, gentle steering, default and waterfall routes, landing runout, relaunch, return, bounds, and waterfall cues")
	level.free()
	quit(0 if failures == 0 else 1)
