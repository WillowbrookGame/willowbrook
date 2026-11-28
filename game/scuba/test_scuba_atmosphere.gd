extends SceneTree
const REEF := "res://game/scuba/reef.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _require(ok: bool, msg: String) -> bool:
	if not ok:
		push_error(msg)
		quit(1)
	return ok

func _run() -> void:
	if change_scene_to_file(REEF) != OK:
		quit(1)
		return
	await scene_changed
	var reef := current_scene
	var geysers: Node3D = reef.geysers
	if not _require(geysers != null and geysers.geysers.size() == 3, "Reef should spawn 3 deep-floor bubble geysers"):
		return
	for i in geysers.geysers.size():
		var g: Dictionary = geysers.geysers[i]
		var base: Vector3 = g.base
		var floor_y: float = reef.art.floor_at(base)
		if not _require(absf(base.x) <= reef.EXTENT.x and absf(base.z) <= reef.EXTENT.y, "Geyser %d outside swim extent" % i):
			return
		if not _require(absf(base.y - floor_y) <= 0.25 and float(g.top_y) <= reef.TOP, "Geyser %d vertical bounds invalid: base=%s floor=%s top=%s" % [i, base.y, floor_y, g.top_y]):
			return
	# Updraft behavior: lifts inside column, yields when holding sink, zero at spawn.
	var g0_base: Vector3 = geysers.geysers[0].base
	var inside := Vector3(g0_base.x, g0_base.y + 3.0, g0_base.z)
	var lift_normal: float = float(geysers.updraft_at(inside, false))
	var lift_sink: float = float(geysers.updraft_at(inside, true))
	var lift_spawn: float = float(geysers.updraft_at(reef.spawn_position, false))
	if not _require(lift_normal > 2.0 and lift_sink == 0.0 and lift_spawn == 0.0, "Unexpected geyser updraft values: normal=%s sink=%s spawn=%s" % [lift_normal, lift_sink, lift_spawn]):
		return
	# Swimming passively inside a geyser should lift the diver upward.
	reef.diver.position = inside
	reef.diver.velocity = Vector3.ZERO
	var start_y: float = reef.diver.position.y
	for _step in range(18):
		await physics_frame
	if not _require(reef.diver.position.y > start_y + 0.4 and reef.diver.position.y <= reef.TOP, "Geyser should gently lift diver upward: start=%s end=%s" % [start_y, reef.diver.position.y]):
		return
	# Depth-based underwater mood shifts darker and deeper blue near the wreck.
	reef.art.update_depth_mood(-3.0)
	var shallow_bg: Color = reef.art._env.background_color
	var shallow_fog: Color = reef.art._env.fog_light_color
	var shallow_amb: float = reef.art._env.ambient_light_energy
	var shallow_sun: float = reef.art._sun.light_energy
	reef.art.update_depth_mood(-16.0)
	var deep_bg: Color = reef.art._env.background_color
	var deep_fog: Color = reef.art._env.fog_light_color
	var deep_amb: float = reef.art._env.ambient_light_energy
	var deep_sun: float = reef.art._sun.light_energy
	if not _require(deep_bg.g < shallow_bg.g - 0.15 and deep_fog.g < shallow_fog.g - 0.15 and deep_amb < shallow_amb and deep_sun < shallow_sun, "Deep water mood should darken/shift deeper blue"):
		return
	# Deep-water visitors cruise without altering the 24 reef school fish contract.
	if not _require(reef.art._fish.size() == 24, "Reef school fish count should remain 24, got %d" % reef.art._fish.size()):
		return
	if not _require(reef.art._visitors.size() == 2, "Reef should have 2 deep-water visitors"):
		return
	var v0_start: Vector3 = reef.art._visitors[0].node.position
	var v1_start: Vector3 = reef.art._visitors[1].node.position
	reef.art._process(1.0)
	var v0_end: Vector3 = reef.art._visitors[0].node.position
	var v1_end: Vector3 = reef.art._visitors[1].node.position
	if not _require(v0_start.distance_to(v0_end) > 0.2 and v1_start.distance_to(v1_end) > 0.2, "Deep-water visitors should glide smoothly over time"):
		return
	print("PASS: Scuba bubble geysers, depth mood shift, and deep-water visitors")
	quit()
