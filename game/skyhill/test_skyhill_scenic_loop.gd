extends SceneTree
## Fly through the actual terrain and wind fields without moving the pilot by hand.
const PARK := preload("res://game/skyhill/skyhill.tscn")
const DT := 1.0 / 60.0
var level: Node3D
var elapsed := 0.0
var completed_laps := 0
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message + " at %.1fs: %s" % [elapsed,level.flight.position])

func _run() -> void:
	level = PARK.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	await physics_frame
	await physics_frame
	level._launch()
	var east: Node3D = level.ridge_lift
	var west: Node3D = level.west_lift
	var falls: Node3D = level.lift_zone
	var meadow: Node3D = level.meadow
	_check(level._inside_flight_boundary(Vector3(-118.0,52.0,-112.0)), "Leave turning room beyond the west ridge lift")
	if _seek(falls.global_position, 8.0, 10.0, INF):
		for lap in 4:
			if not _seek(east.global_position, 25.0, 14.0, INF):
				break
			if not _climb_and_align(east, 25.0, 70.0, west.global_position, 30.0):
				break
			if not _seek(west.global_position, 20.0, 24.0, INF):
				break
			if lap == 3:
				_check(elapsed >= 60.0,"Linked circuits should pass one minute in the air")
				if _climb_and_align(west, 19.0, 50.0, meadow.global_position, 22.0):
					_land_from_west()
				break
			if not _climb_and_align(west, 19.0, 55.0, falls.global_position, 24.0):
				break
			if not _seek(falls.global_position, 8.0, 18.0, 31.0):
				break
			_check(level.lift_at(level.flight.position) > .5, "The waterfall should still give lift at the end of each circuit")
			completed_laps += 1
			print("Skyhill circuit ",lap+1," at ",snappedf(elapsed,.1)," s, waterfall y=",snappedf(level.flight.position.y,.1))
	_check(completed_laps == 3, "Expected three renewals of the full loop")
	if not failed:
		print("PASS Skyhill: three complete linked ridge/waterfall circuits, %.1f s without reset, then clean meadow landing" % elapsed)
	level.free()
	quit(1 if failed else 0)

func _step(direction: Vector2, pitch := 0.0) -> void:
	var target_yaw := atan2(-direction.x, -direction.y)
	var steer := clampf(angle_difference(target_yaw, level.flight.heading) * 3.0, -1.0, 1.0)
	level.step_flight(DT, steer, pitch)
	elapsed += DT

func _xz(location: Vector3) -> Vector2:
	return Vector2(location.x,location.z)

func _forward() -> Vector2:
	return _xz(Vector3.FORWARD.rotated(Vector3.UP,level.flight.heading))

func _seek(target: Vector3, radius: float, limit: float, descent_altitude: float) -> bool:
	for _i in int(limit/DT):
		if level.state != level.State.FLYING:
			break
		var point: Vector3 = level.flight.position
		var direction := _xz(target - point)
		if direction.length() <= radius:
			return true
		_step(direction, -1.0 if point.y > descent_altitude else 0.0)
	_check(false,"Could not reach %s within %.1f seconds, %s" % [target,limit,level.prompt.text])
	return false

func _climb_and_align(field: Node3D, radius: float, altitude: float, destination: Vector3, limit: float) -> bool:
	var start: Vector3 = level.flight.position
	var radial_start := _xz(start-field.global_position).normalized()
	var direction_sign := 1.0 if _forward().dot(radial_start.rotated(PI/2.0)) >= 0.0 else -1.0
	for _i in int(limit/DT):
		if level.state != level.State.FLYING:
			break
		var point: Vector3 = level.flight.position
		var radial := _xz(point-field.global_position)
		var aside := radial.normalized()
		if aside.is_zero_approx():
			aside = _forward().rotated(-direction_sign * PI/2.0)
		var exit_dir := _xz(destination-point).normalized()
		if point.y >= maxf(altitude, start.y + 4.0) and _forward().dot(exit_dir) > .96 and field.weight_at(point) > .12:
			_check(point.y > start.y+4.0, "%s must replenish altitude before departing" % field.caption)
			print(field.caption, " y=",snappedf(start.y,.1)," -> ",snappedf(point.y,.1)," after ",snappedf(elapsed,.1)," s")
			return true
		var tangent := aside.rotated(direction_sign * PI/2.0)
		_step(tangent - aside * clampf((radial.length()-radius) * .12,-1.2,1.2))
	_check(false,"Could not climb and align out of %s (%s)" % [field.caption, level.prompt.text])
	return false

func _land_from_west() -> void:
	# Pick a touchdown line down the center of the meadow, away from the approach poles.
	var target := Vector3(16.0,0.0,-130.0)
	for _i in 1800:
		var point: Vector3 = level.flight.position
		if level.state == level.State.LANDING:
			level.step_flight(DT,0)
			elapsed += DT
		elif level.state == level.State.FLYING:
			var to_field := _xz(target-point)
			var inside: bool = level.in_meadow(point)
			if inside and point.y <= 7.0:
				level.step_flight(DT,0.0,0.0)
				elapsed += DT
			else:
				_step(to_field if not inside else Vector2.RIGHT, -1.0 if point.y > 10.0 else 0.0)
		else:
			break
	_check(level.state == level.State.MEADOW and level.prompt.text.begins_with("Nice landing!"),"Extended flight must still end with a clean meadow landing (%s, state=%s)" % [level.prompt.text, level.state])
