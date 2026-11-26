extends SceneTree

const SCENERY := preload("res://game/town_scenery.tscn")
const TOWN := preload("res://game/town.tscn")
const TREE := "Trees/Plot2DrivewayTree"
const DELTA := Vector3(-3, 0, 0)

var failures: PackedStringArray = []


func _initialize() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	_test.call_deferred()


func _test() -> void:
	var town := TOWN.instantiate()
	root.add_child(town)
	var layout := town.get_node("TownLayout")
	var scenery := layout.get_node("TownScenery")
	var original := scenery.get_node(TREE) as Node3D
	_check(scenery.scene_file_path == SCENERY.resource_path, "Town must load the editable scene")
	var old_body := original.get_node("SolidBody") as StaticBody3D
	var old_at := old_body.global_position
	var old_art: Vector3 = original.get_node("Art").global_position
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = original.get_world_3d().direct_space_state
	_check(_hit(space,old_at) == old_body,"Default driveway tree must have its trunk collision")
	var starter := scenery.get_node("StarterHomes/HouseExterior_2") as Node3D
	var starter_body := starter.get_node("HouseWalls") as StaticBody3D
	var home_center := starter_body.global_position
	_check(_hit(space,home_center) == starter_body,"Starter facade should have its original collider")
	layout.set_home_exteriors([{"plot":1,"variant":"family"}])
	await physics_frame
	await physics_frame
	var upgraded := layout.get_node_or_null("HouseExterior_2") as Node3D
	_check(upgraded != null and upgraded.get_meta("variant") == "family" and not starter.visible,"Home upgrade replaces the starter shell")
	if upgraded != null:
		_check(_hit(space,home_center) == upgraded.get_node("HouseWalls"),"Only upgraded collision should be active")
	layout.set_home_exteriors([])
	await physics_frame
	await physics_frame
	_check(starter.visible and _hit(space,home_center) == starter_body,"Returning to starter restores authored facade and collision")
	town.free()

	var edited := SCENERY.instantiate()
	var tree := edited.get_node(TREE) as Node3D
	tree.position += DELTA
	var saved := PackedScene.new()
	var file := "user://town-editor-test-%d.tscn" % Time.get_ticks_usec()
	if saved.pack(edited) != OK or ResourceSaver.save(saved,file) != OK:
		edited.free()
		push_error("Could not save disposable copy of Town")
		quit(1)
		return
	edited.free()
	var reopened := (ResourceLoader.load(file,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	root.add_child(reopened)
	await physics_frame
	await physics_frame
	tree = reopened.get_node(TREE)
	var body := tree.get_node("SolidBody") as StaticBody3D
	space = tree.get_world_3d().direct_space_state
	_check((tree.get_node("Art").global_position as Vector3).is_equal_approx(old_art+DELTA),"Reopened tree art follows editor placement")
	_check(body.global_position.is_equal_approx(old_at+DELTA) and _hit(space,old_at+DELTA)==body,"Reopened trunk collider follows editor placement")
	_check(_hit(space,old_at)==null,"Original tree position has no leftover collision")
	reopened.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	for issue in failures:
		push_error(issue)
	if failures.is_empty():
		print("Town editor passed: save/reopen driveway tree with collision, starter and upgraded house collision.")
	quit(0 if failures.is_empty() else 1)


func _hit(space: PhysicsDirectSpaceState3D, at: Vector3) -> Object:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP*4,at - Vector3.UP*.3)).get("collider")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
