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
	var rings: Node3D = reef.rings
	if not _require(rings != null and rings.total_count() == 8 and rings.passed_count == 0, "Reef should start with 8 unpassed musical rings"):
		return
	# Verify all 8 rings sit inside swim bounds and clear of the floor/surface.
	for i in rings.rings.size():
		var pos: Vector3 = rings.rings[i].base
		var floor_y: float = reef.art.floor_at(pos)
		if not _require(absf(pos.x) <= reef.EXTENT.x and absf(pos.z) <= reef.EXTENT.y, "Ring %d outside swim extent" % i):
			return
		if not _require(pos.y >= floor_y + 0.9 and pos.y <= reef.TOP, "Ring %d unreachable vertically: y=%s floor=%s" % [i, pos.y, floor_y]):
			return
	# Free swimmers see no ring clutter before passing one.
	await physics_frame
	if not _require("Rings" not in reef.depth.text, "Ring HUD should stay hidden until first ring"):
		return
	# Swim through all 8 rings; verify velocity is unchanged (no fin boost) and completion banner shows.
	for i in rings.rings.size():
		var pos: Vector3 = rings.rings[i].base
		reef.diver.position = pos
		reef.diver.velocity = Vector3.ZERO
		await physics_frame
		if not _require(rings.passed_count == i + 1, "Ring %d was not counted" % (i + 1)):
			return
		if not _require(reef.diver.velocity.length() < 0.01, "Passing a ring should not add a fin speed boost"):
			return
		await physics_frame
		if not _require(rings.passed_count == i + 1, "Ring %d double-counted" % (i + 1)):
			return
	if not _require("8 / 8" in reef.depth.text and "melody complete" in reef.treasure_banner.text, "Ring melody completion banner/readout missing"):
		return
	# Verify rings reset cleanly after RESET_DELAY so kids can replay the melody.
	rings._process(rings.RESET_DELAY + 0.1)
	if not _require(rings.passed_count == 0 and not rings.rings[0].passed, "Rings did not reset after completion delay"):
		return
	print("PASS: 8 Musical Bubble Rings, reachable ribbon, no fin boost, melody completion, and replay reset")
	quit()
