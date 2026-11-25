extends SceneTree
const PROFILE = preload("res://game/progression/profile.gd")
const TOWN = preload("res://game/town_layout.gd")
func _initialize() -> void:
	run.call_deferred()
func require(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	var profile := PROFILE.new("")
	set_meta("willowbrook_profile",profile)
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var variants := ["starter","cottage","family"]
	for plot in range(6):
		var current: Dictionary=profile.snapshot()
		var variant: String=variants[plot%3]
		current.home={"plot":plot,"variant":variant}
		current.furniture=[{"kind":"chair","id":"fixture-"+str(plot),"room":plot%3,"x":2,"z":-2,"rotation":0}]
		if not require(profile.commit(current),"Fixture profile rejected: "+str(plot)): return
		var door: Vector3=TOWN.HOME_DOORS[plot]
		var town := current_scene
		town.player.position=door+Vector3(0,.04,1.3)
		town._interact()
		if not require(town.changing,"Town did not enter home "+str(plot)): return
		await scene_changed
		var map := current_scene
		var t: Dictionary=map.profile_snapshot()
		if not require(map.current_zone_id()=="home:%d"%plot and int(t.home.plot)==plot and t.home.variant==variant,"Lost plot identity: "+str(plot)): return
		if not require(map.player.position.is_equal_approx(Vector3(0,.04,3.5)),"Changed home spawn: "+str(plot)): return
		var floor_count := 0
		for child in map.room.art.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.is_equal_approx(Vector3(12,.24,10)):
				floor_count+=1
		if not require(floor_count==plot%3+1,"Incorrect home shell room count: "+str(plot)+", got "+str(floor_count)): return
		if not require(map.room.scene_file_path=="res://game/home/room.tscn","Plot didn't use the shared Home scene"): return
		map.player.position=Vector3(0,.04,4.35)
		map._interact()
		if not require(map.changing,"Couldn't exit Home "+str(plot)): return
		await scene_changed
		if not require(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,2.0)),"Changed Town return: "+str(plot)): return
		if not require(current_scene.profile_snapshot().furniture[0].id=="fixture-"+str(plot),"Changed furniture identity: "+str(plot)): return
	print("PASS: all six existing Home IDs, three shell variants, spawn/return and unchanged furniture IDs.")
	quit(0)
