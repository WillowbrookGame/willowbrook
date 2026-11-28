extends SceneTree

const PARK := preload("res://game/skyhill/skyhill.tscn")
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		errors += 1

func _run() -> void:
	var level := PARK.instantiate()
	root.add_child(level)
	level.set_physics_process(false)
	level.set_process(false)
	await physics_frame
	await physics_frame
	var atmosphere: Node3D = level.atmosphere
	var paths := atmosphere.find_children("*", "Path3D", false, false)
	verify(atmosphere.global_transform == Transform3D.IDENTITY, "Birds are in the authored world coordinates")
	verify(paths.size() == 3, "Three editable valley bird paths")
	verify(atmosphere.find_children("*", "CollisionObject3D", true, false).is_empty(), "Birds and trails cannot collide")
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for path in paths:
		var curve: Curve3D = path.curve
		var length := curve.get_baked_length()
		var follow: PathFollow3D = path.get_node("Follow")
		var bird := follow.get_node("Bird")
		verify(length > 60.0 and curve.get_point_position(0).is_equal_approx(curve.get_point_position(curve.point_count - 1)), "Bird path closes and leaves room to glide")
		var start := follow.position
		var wing_flaps := false
		for _i in 600:
			atmosphere.tick(.016, false, 0.0, 0.0, 0.0)
			wing_flaps = wing_flaps or absf(float(bird.get_node("WingLeft").rotation.z)) > .15
		verify(follow.position.distance_to(start) > 2 and wing_flaps, "Bird should travel and flap")
		var ahead := curve.sample_baked(fposmod(follow.progress + 1.0, length))
		verify((-follow.basis.z).dot((ahead - follow.position).normalized()) > .85, "Bird should face along its path")
		for i in 48:
			var point: Vector3 = path.to_global(curve.sample_baked(length * i / 48.0))
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 150.0, point - Vector3.UP * .5, 1))
			verify(hit.is_empty(), "Bird path %s must clear terrain at %s" % [path.name, point])
	var sock := level.get_node("Scenery/RouteWindsocks/Windsock0/Pole") as CollisionShape3D
	verify(atmosphere._cloth.size() == 6 and atmosphere._cloth[0].get_shader_parameter("palette") != null, "The animated sock uses its existing amber and cream palette")
	var pole_start := sock.global_transform
	var phase: float = atmosphere._cloth[0].get_shader_parameter("sock_phase")
	atmosphere.tick(.1, false, 0, 0, 0)
	verify(not is_equal_approx(phase, atmosphere._cloth[0].get_shader_parameter("sock_phase")) and sock.global_transform == pole_start, "Only the windsock cloth animates")
	level._launch()
	for _i in 12:
		level.glider.position.z -= .3
		atmosphere.tick(.03, true, 18, .3, 0)
	verify(atmosphere.ribbons.mesh.get_surface_count() == 2, "Banking leaves two trails")
	for _i in 22:
		atmosphere.tick(.03, true, 18, 0, 0)
	verify(atmosphere.ribbons.mesh.get_surface_count() == 0, "Trails fade without steering or lift")
	for _i in 12:
		level.glider.position.z -= .3
		atmosphere.tick(.03, true, 18, 0, 1)
	verify(atmosphere.ribbons.mesh.get_surface_count() == 2, "Lift alone leaves two trails")
	level._app_unfocused = true
	level._update_suspension()
	verify(atmosphere.ribbons.mesh.get_surface_count() == 0 and atmosphere._silenced, "Focus loss clears trails and silences audio")
	level._app_unfocused = false
	level._update_suspension()
	verify(atmosphere._silenced, "Still silent until the player resumes")
	level._action()
	verify(not atmosphere._silenced, "Resume re-enables effects")
	var wind: AudioStreamWAV = atmosphere._make_sound("wind", 2.4)
	var nonzero := false
	for i in range(0, wind.data.size(), 2):
		if wind.data.decode_s16(i) != 0:
			nonzero = true
			break
	verify(nonzero and wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and wind.loop_end * 2 == wind.data.size(), "Wind has audio and a bounded loop")
	# The production crash event must stop the wind, select the impact and keep its gain separate.
	var crash: AudioStreamWAV = atmosphere._make_sound("crash", .39)
	atmosphere._streams["crash"] = crash
	atmosphere._streams["launch"] = atmosphere._make_sound("launch", .54)
	atmosphere.wind.stream = wind
	atmosphere.wind.play()
	verify(atmosphere.wind.playing, "Wind is active before the test crash")
	level._crash(level.flight.position, "Hard landing test")
	verify(atmosphere.cue.stream == crash and is_equal_approx(atmosphere.cue.volume_db, -7.0) and not atmosphere.wind.playing, "Crash uses an audible, separately mixed impact cue")
	var attack_energy := 0.0
	var tail_energy := 0.0
	var samples := int(crash.mix_rate * .07)
	for i in samples:
		attack_energy += pow(crash.data.decode_s16(i * 2) / 32768.0, 2)
		tail_energy += pow(crash.data.decode_s16(crash.data.size() - (i + 1) * 2) / 32768.0, 2)
	verify(sqrt(attack_energy / samples) > .15 and tail_energy < attack_energy * .01, "Impact has a distinct attack and a soft fade")
	level._on_deck()
	level._launch()
	verify(is_equal_approx(atmosphere.cue.volume_db, -15.0), "The louder impact gain does not carry over to later cues")
	atmosphere.reset_flight()
	await process_frame
	level.free()
	if errors == 0:
		print("PASS Skyhill atmosphere: birds move and flap above terrain, cloth keeps pole still, trails expire, pause, audio loop, and isolated impact cue")
	quit(int(errors > 0))
