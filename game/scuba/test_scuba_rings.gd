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
	for i in rings.rings.size():
		var pos: Vector3 = rings.rings[i].base
		var floor_y: float = reef.art.floor_at(pos)
		if not _require(absf(pos.x) <= reef.EXTENT.x and absf(pos.z) <= reef.EXTENT.y, "Ring %d outside swim extent" % i):
			return
		if not _require(pos.y >= floor_y + 0.9 and pos.y <= reef.TOP, "Ring %d unreachable vertically: y=%s floor=%s" % [i, pos.y, floor_y]):
			return
	await physics_frame
	if not _require(not reef.activity_counts.visible, "Activity counts should stay hidden until first ring or treasure"):
		return
	# Passing outside the hoop opening must NOT count.
	var r0: Node3D = rings.rings[0].node
	reef.diver.position = r0.to_global(Vector3(2.2, 0.0, 0.8))
	await physics_frame
	reef.diver.position = r0.to_global(Vector3(2.2, 0.0, -0.8))
	await physics_frame
	if not _require(rings.passed_count == 0, "Swimming outside the ring hoop should not count"):
		return
	# Swim cleanly through all 8 rings (alternating front->back and back->front directions).
	for i in rings.rings.size():
		var node: Node3D = rings.rings[i].node
		var side := 0.8 if i % 2 == 0 else -0.8
		reef.diver.position = node.to_global(Vector3(0.0, 0.0, side))
		reef.diver.velocity = Vector3.ZERO
		await physics_frame
		reef.diver.position = node.to_global(Vector3(0.0, 0.0, -side))
		reef.diver.velocity = Vector3.ZERO
		await physics_frame
		if not _require(rings.passed_count == i + 1, "Crossing through ring %d opening did not count" % (i + 1)):
			return
		if not _require(reef.diver.velocity.length() < 0.01, "Passing a ring should not add a fin speed boost"):
			return
		# Staying still or crossing again must not double-count.
		await physics_frame
		if not _require(rings.passed_count == i + 1, "Ring %d double-counted" % (i + 1)):
			return
	if not _require("8 / 8" in reef.activity_counts.text and "melody complete" in reef.treasure_banner.text, "Ring melody completion banner/readout missing"):
		return
	# Verify both treasures and rings fit cleanly on a narrow 360px viewport without clipping.
	reef.diver.position = reef.treasures.items[0].base
	await physics_frame
	root.size = Vector2i(360, 640)
	await process_frame
	var view_w: float = reef.get_viewport().get_visible_rect().size.x
	var counts_rect: Rect2 = reef.activity_counts.get_global_rect()
	var expected_treasures := "Treasures %d / 6" % reef.treasures.found_count
	if not _require(reef.treasures.found_count >= 1 and expected_treasures in reef.activity_counts.text and "Rings 8 / 8" in reef.activity_counts.text and counts_rect.end.x <= view_w, "Activity counts clipped or missing in 360px viewport: text='%s' rect=%s view_w=%s" % [reef.activity_counts.text, counts_rect, view_w]):
		return
	# Sitting still inside the last ring after reset must stay at 0 / 8 (never immediately trigger 1 / 8).
	var last_node: Node3D = rings.rings[7].node
	reef.diver.position = last_node.global_position
	await physics_frame
	rings._process(rings.RESET_DELAY + 0.1)
	await physics_frame
	await physics_frame
	if not _require(rings.passed_count == 0 and not rings.rings[7].passed, "Sitting still inside last ring after reset wrongly triggered: passed=%d r7=%s timer=%s" % [rings.passed_count, rings.rings[7].passed, rings._reset_timer]):
		return
	print("PASS: 8 Musical Bubble Rings plane-crossing, outside-hoop reject, idle-reset guard, and 360px HUD")
	quit()
