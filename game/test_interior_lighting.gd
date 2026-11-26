extends SceneTree

const ROOM := preload("res://game/room.tscn")
const SCENERY := preload("res://game/town_scenery.tscn")
const ROUTES := preload("res://game/town_routes.gd")
var failures: PackedStringArray = []


func _initialize() -> void:
	set_meta("willowbrook_save_override", "")
	set_meta("fishing_save_override", "")
	_run.call_deferred()


func _run() -> void:
	for destination in ["bank", "vet", "salon", "store", "cafe", "library", "home", "arcade", "dive_shop"]:
		set_meta("room_destination", destination)
		var map := ROOM.instantiate()
		root.add_child(map)
		var worlds := map.find_children("*", "WorldEnvironment", true, false)
		var suns := map.find_children("*", "DirectionalLight3D", true, false)
		_check(worlds.size() == 1 and suns.size() == 1, "%s must have one environment and one key light" % destination)
		if worlds.size() == 1 and suns.size() == 1:
			var authored: bool = destination not in ["arcade", "dive_shop"]
			_check((worlds[0].get_parent() != map) == authored, "%s must use the intended environment" % destination)
			_check((suns[0].get_parent() != map) == authored, "%s must use the intended key light" % destination)
		map.free()
	var scenery := SCENERY.instantiate()
	root.add_child(scenery)
	var exterior := scenery.get_node("PaintballExterior")
	var front_door := exterior.get_node("PaintballWarehouseExterior/warehouse-exterior/RollUpDoor_West") as Node3D
	_check(front_door.is_visible_in_tree() and absf(front_door.global_position.x - ROUTES.ARENA_DOOR.x) < 0.05,
		"The imported warehouse shutter must remain aligned with the entrance")
	for child in exterior.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var size: Vector3 = child.mesh.size
			_check(size.y < 1.0 or absf(child.global_position.z - ROUTES.ARENA_DOOR.z) > 1.0,
				"No second door mesh in front of the warehouse shutter")
	_check(exterior.has_node("Sign_PaintballArena") and exterior.has_node("StaticBody3D3"),
		"Keep the arena sign and exterior collision")
	scenery.free()
	for issue in failures:
		push_error(issue)
	if failures.is_empty():
		print("PASS: nine interior lighting rigs and a single signed Paintball entrance")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
