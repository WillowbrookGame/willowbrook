extends SceneTree

const PROFILE = preload("res://game/progression/profile.gd")
const TOWN = preload("res://game/town_layout.gd")
const VARIANTS := ["starter", "cottage", "family"]

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	var profile := PROFILE.new("")
	set_meta("willowbrook_profile",profile)
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	for plot in range(6):
		var variant: String = VARIANTS[plot%3]
		var furniture_id := "fixture-%d" % plot
		var next: Dictionary = profile.snapshot()
		next.home = {"plot":plot,"variant":variant}
		next.furniture = [{"kind":"chair","id":furniture_id,"room":plot%3,"x":2,"z":-2,"rotation":0}]
		if not expect(profile.commit(next),"Fixture profile rejected: %d" % plot): return
		var door: Vector3 = TOWN.HOME_DOORS[plot]
		var town := current_scene
		town.player.position = door+Vector3(0,.04,1.3)
		town._interact()
		if not expect(town.changing,"Town did not enter owner home %d" % plot): return
		await scene_changed
		var map := current_scene
		var saved: Dictionary = map.profile_snapshot()
		if not expect(map.current_zone_id() == "home:%d" % plot and int(saved.home.plot) == plot and saved.home.variant == variant,"Owner plot or variant changed"): return
		if not (await check_layout(map,variant)): return
		if not expect(not map.room._visiting() and map.room.pets != null and map.room.art.decor.get_child_count() == 1,"Owner furniture or pet runtime missing"): return
		var chair: Node3D = map.room.art.decor.get_child(0)
		if not expect(chair.get_meta("furniture_id") == furniture_id and chair.position.is_equal_approx(Vector3((plot%3)*12.0+2.0,0,-2)),"Saved chair identity or position changed"): return
		if not (await leave_home(map,door)): return
		if not expect(current_scene.profile_snapshot().furniture[0].id == furniture_id,"Furniture identity changed after exiting"): return
		# Simulate a successful server visit notice at another home's real Town door.
		var guest_plot := (plot+1)%6
		var guest_door: Vector3 = TOWN.HOME_DOORS[guest_plot]
		var guest_variant: String = VARIANTS[guest_plot%3]
		town = current_scene
		town.player.position = guest_door+Vector3(0,.04,1.3)
		town._home_enter_target = {"id":"home","guest":true,"plot":guest_plot,"at":guest_door,"side":1.0}
		town._home_visit_notice({"action":"enter","ok":true,"plot":guest_plot,"variant":guest_variant})
		if not expect(town.changing,"Approved visit did not open the guest home"): return
		await scene_changed
		map = current_scene
		if not expect(map.room._visiting() and map.room_plot == guest_plot and map.guest_variant == guest_variant,"Guest plot or variant changed"): return
		if not (await check_layout(map,guest_variant)): return
		if not expect(map.room.art.decor.get_child_count() == 0,"The owner's personal furniture leaked into the guest layout"): return
		var guest_row := {"kind":"chair","id":"guest-chair","room":guest_plot%3,"x":-2,"z":-2,"rotation":0}
		map.apply_home_scene({"owner":false,"variant":guest_variant,"decor":[guest_row]})
		if not expect(map.room.art.decor.get_child_count() == 1 and map.room.art.decor.get_child(0).get_meta("furniture_id") == "guest-chair","Live guest furniture failed to render"): return
		if not (await leave_home(map,guest_door)): return
		if not expect(current_scene.profile_snapshot().furniture[0].id == furniture_id,"Guest furniture replaced the owner's save"): return
	print("PASS: all six owner and guest doors, three editable shells, paths, collisions, and separate furniture.")
	quit(0)

func check_layout(map: Node3D, variant: String) -> bool:
	if not expect(map.room.scene_file_path == "res://game/home/room.tscn" and map.player.position.is_equal_approx(Vector3(0,.04,3.5)),"Home module or spawn changed"): return false
	var shell: Node3D = map.room.art.get_node("Layout")
	if not expect(shell.scene_file_path == "res://game/home/layout_%s.tscn" % variant,"Incorrect Home layout resource"): return false
	var count := VARIANTS.find(variant)+1
	var room_count := shell.get_children().filter(func(n: Node): return String(n.name).begins_with("Room") and String(n.name).trim_prefix("Room").is_valid_int()).size()
	if not expect(room_count == count,"Home layout room count changed"): return false
	await physics_frame
	await physics_frame
	var space := shell.get_world_3d().direct_space_state
	for index in range(count):
		var floor_node: MeshInstance3D = shell.get_node("Room%d/Floor" % (index+1))
		if not expect(floor_node.global_position.is_equal_approx(Vector3(index*12.0,-.12,0)),"Room floor shifted"): return false
		var ray := PhysicsRayQueryParameters3D.create(Vector3(index*12.0+3,1,0),Vector3(index*12.0+3,-1,0),1)
		if not expect(space.intersect_ray(ray).get("collider") == floor_node.get_node("SolidBody"),"Floor body no longer matches its mesh"): return false
		if index < count-1:
			var passage := PhysicsRayQueryParameters3D.create(Vector3(index*12.0+5,1,0),Vector3(index*12.0+7,1,0),1)
			if not expect(space.intersect_ray(passage).is_empty(),"Passage between rooms is blocked"): return false
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var back_wall: MeshInstance3D = shell.get_node("Room1/BackWall")
	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(3,1,-4),Vector3(3,1,-6),1)
	var hit := space.intersect_ray(wall_ray)
	if not expect(hit.get("collider") == back_wall.get_node("SolidBody"),"Wall collider no longer follows the authored mesh"): return false
	var at: Vector3 = hit.position
	return expect(absf(at.z - (-5.31 if edited else -4.91)) < .005,"Wall collision not at the expected saved location")

func leave_home(map: Node3D, door: Vector3) -> bool:
	map.player.position = Vector3(0,.04,4.35)
	map._interact()
	if not expect(map.changing,"Home exit did not return to Town"): return false
	await scene_changed
	return expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,2.0)),"Changed Town return position")
