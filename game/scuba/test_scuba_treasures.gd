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
	var treasures: Node3D = reef.treasures
	if not _require(treasures != null and treasures.total_count() == 6 and treasures.found_count == 0, "Reef should start with 6 uncollected treasures"):
		return
	# Verify ALL candidate spots in ZONE_POOLS are reachable and cover all 5 zones.
	var all_zones := {}
	for pool_entry: Dictionary in treasures.ZONE_POOLS:
		for spec: Dictionary in pool_entry.spots:
			var pos: Vector3 = spec.pos
			var floor_y: float = reef.art.floor_at(pos)
			if not _require(absf(pos.x) <= reef.EXTENT.x and absf(pos.z) <= reef.EXTENT.y, "Candidate %s outside swim extent" % spec.id):
				return
			if not _require(pos.y >= floor_y + 0.9 and pos.y <= reef.TOP, "Candidate %s unreachable vertically: y=%s floor=%s" % [spec.id, pos.y, floor_y]):
				return
			all_zones[reef.art.landmark(pos)] = true
	if not _require(all_zones.size() == 5, "Candidate pools should cover all 5 reef zones, got: %s" % [all_zones.keys()]):
		return
	# Verify the active 6 treasures cover all 5 named zones.
	var zones := {}
	for i in treasures.items.size():
		var item: Dictionary = treasures.items[i]
		zones[reef.art.landmark(item.base)] = true
	if not _require(zones.size() == 5, "Active treasures should cover all 5 reef zones, got: %s" % [zones.keys()]):
		return
	# First treasure should be in plain sight ahead of entry in Sunbeam Shallows.
	var first_pos: Vector3 = treasures.items[0].base
	if not _require(absf(first_pos.x - reef.SPAWN.x) <= 3.2 and first_pos.z < reef.SPAWN.z and reef.SPAWN.distance_to(first_pos) < 8.0 and reef.art.landmark(first_pos) == "Sunbeam Shallows", "First treasure should be in plain sight ahead of entry"):
		return
	# Free swimmers see no treasure clutter before collecting one.
	await physics_frame
	if not _require("Treasures" not in reef.depth.text and not reef.treasure_banner.visible, "Treasure HUD should stay hidden until first discovery"):
		return
	# Collect all 6 treasures, verifying no double-counting and readable banners.
	for i in treasures.items.size():
		var item: Dictionary = treasures.items[i]
		reef.diver.position = item.base
		await physics_frame
		if not _require(treasures.found_count == i + 1 and not item.node.visible and reef.treasure_banner.visible, "Treasure %d (%s) was not collected cleanly" % [i + 1, item.id]):
			return
		# Staying at the same spot must not double-count.
		await physics_frame
		if not _require(treasures.found_count == i + 1, "Treasure %s double-counted" % item.id):
			return
	if not _require("6 / 6" in reef.depth.text and "All 6" in reef.treasure_banner.text, "Final treasure completion banner/readout missing"):
		return
	root.size = Vector2i(640, 360)
	await process_frame
	var view_w: float = reef.get_viewport().get_visible_rect().size.x
	var banner_rect: Rect2 = reef.treasure_banner.get_global_rect()
	if not _require(banner_rect.position.x >= 0.0 and banner_rect.end.x <= view_w and absf(banner_rect.get_center().x - view_w * 0.5) <= 2.0, "Discovery banner clipped or off-center in 640x360 viewport: %s (view_w=%s)" % [banner_rect, view_w]):
		return
	print("PASS: 6 Sunken Reef Treasures across all 5 zones, plain-sight entry pickup, no double-count, and clean HUD")
	quit()
