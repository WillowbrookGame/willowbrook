extends SceneTree
## Check that saved layout edits drive the playable Reef, not just editor guides.

const REEF := preload("res://game/scuba/reef.tscn")
const LAYOUT := preload("res://game/scuba/reef_layout.tscn")
const ORIGINAL_RING_YAWS := [0.15, -0.35, -0.35, 0.0, 0.45, -0.35, -0.85, -1.1]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var layout := LAYOUT.instantiate()
	var activities := layout.get_node("Activities")
	var ring_markers := activities.get_node("MusicalRings").get_children()
	if ring_markers.size() != ORIGINAL_RING_YAWS.size():
		push_error("Authored ring count changed")
		layout.free()
		quit(1)
		return
	for i in ring_markers.size():
		if not ring_markers[i].basis.is_equal_approx(Basis(Vector3.UP, ORIGINAL_RING_YAWS[i])):
			push_error("Authored ring %d changed its original facing" % (i + 1))
			layout.free()
			quit(1)
			return
	var spawn := activities.get_node("DiverSpawn") as Marker3D
	var ring := activities.get_node("MusicalRings/Ring01") as Marker3D
	var vent := activities.get_node("BubbleGeysers/wreck_center_geyser") as Marker3D
	var top := vent.get_node("Top") as Marker3D
	var pearl := activities.get_node("TreasurePools/SunbeamShallows/sunbeam_pearl") as Marker3D
	var visitor := activities.get_node("WildlifeLanes/Shark") as Marker3D
	spawn.position.x += 1.0
	ring.position.x += 1.2
	ring.rotation.y += 0.45
	vent.position.x += 1.5
	top.position.y -= 2.0
	pearl.position.x += 0.7
	visitor.position.z += 1.3
	var save_path := "user://reef_editor_layout_test_%d.tscn" % OS.get_process_id()
	var pack := PackedScene.new()
	var packed := pack.pack(layout)
	var saved := ResourceSaver.save(pack, save_path) if packed == OK else packed
	var loaded := ResourceLoader.load(save_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene if saved == OK else null
	if loaded == null:
		push_error("Could not save/reload the edited Reef layout")
		layout.free()
		quit(1)
		return
	var reef := REEF.instantiate()
	var art := reef.get_node("ReefArt")
	art.get_node("ReefLayout").free()
	art.add_child(loaded.instantiate())
	root.add_child(reef)

	var ring_runtime: Dictionary = reef.rings.rings[0]
	var vent_runtime: Dictionary = reef.geysers.geysers[0]
	var pearl_runtime: Dictionary = reef.treasures.candidate_pools()[0].spots[0]
	var results := [
		reef.diver.position.is_equal_approx(spawn.position),
		ring_runtime.base.is_equal_approx(ring.position),
		ring_runtime.node.basis.is_equal_approx(ring.basis),
		vent_runtime.base.is_equal_approx(vent.position),
		is_equal_approx(float(vent_runtime.top_y), vent.position.y + top.position.y),
		reef.geysers.updraft_at(vent.position + Vector3.UP * 2) > 2.0,
		pearl_runtime.pos.is_equal_approx(pearl.position),
		reef.art._visitors[0].origin.is_equal_approx(visitor.position),
	]
	layout.free()
	DirAccess.remove_absolute(save_path)
	if results.has(false):
		push_error("Saved Reef positions did not reach gameplay: %s" % [results])
		quit(1)
		return
	print("PASS: saved Reef entry, ring pose, geyser column, treasure, and wildlife edits reach gameplay")
	quit()
