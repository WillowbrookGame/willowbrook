extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const SCENE := "res://game/library/room.tscn"
const LAYOUT := "res://game/library/room_layout.tscn"

func _initialize() -> void:
	_run.call_deferred()

func expect(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok

func interact(map: Node3D) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	map._unhandled_key_input(event)

func _run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var profile: Dictionary = current_scene.profile_snapshot()
	profile.stars = 1
	if not expect(current_scene.profile_commit(profile),"Could not seed disposable profile"): return
	var door: Vector3 = TOWN.BUSINESS_DOORS["library"]
	for visit in range(2):
		var town := current_scene
		town.player.position = door + Vector3(0,.04,1.3)
		interact(town)
		if not expect(town.changing,"Town interaction did not enter Library"): return
		await scene_changed
		var map := current_scene
		var room: Node3D = map.room
		if not expect(map.room_id=="library" and room.scene_file_path==SCENE and room.id=="library","Library module not loaded"): return
		if not expect(map.player.position.is_equal_approx(Vector3(0,.04,5.5)),"Library spawn changed"): return
		if not expect(room.art.conversation_actor!=null,"Librarian missing"): return
		await physics_frame
		await physics_frame
		if not _check_layout(map,room): return
		map.player.position = Vector3(0,.04,1.2)
		interact(map)
		if not expect(room.is_modal_open() and room.active_panel=="library","Librarian did not open tuition panel"): return
		var buttons: Array[Node] = room.fields.find_children("*","Button",true,false).filter(func(node): return node.text=="Pay 1 star")
		if not expect(buttons.size()==1 and buttons[0].disabled==(visit==1),"One-star action visibility changed"): return
		if visit==0: buttons[0].pressed.emit()
		var saved: Dictionary = map.profile_snapshot()
		if not expect(saved.stars==0 and saved.classes["delivery"].paid==1,"Tuition not charged once or did not persist"): return
		room.close_modal()
		map.player.position = Vector3(0,.04,6.55)
		interact(map)
		if not expect(map.changing,"Could not exit Library through Town door"): return
		await scene_changed
		if not expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,2.0)),"Library return point changed"): return
	print("PASS: isolated Library scene, original door and spawn, one payment, persisted tuition and zero-balance disable on reentry.")
	quit(0)

func _check_layout(map: Node3D, room: Node3D) -> bool:
	if not expect(room.art.scene_file_path == LAYOUT, "Library did not load the editable layout"): return false
	if not expect(room.art.conversation_actor == room.art.get_node("Librarian"), "Librarian was not bound to the authored layout"): return false
	var chair: Node3D = room.art.get_node("LeftReadingChair")
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var desired := Vector3(-5,0,4.2) if edited else Vector3(-5,0,3)
	var space := chair.get_world_3d().direct_space_state
	if not expect(chair.position.is_equal_approx(desired), "Saved Library chair placement did not reach gameplay"): return false
	var ray := PhysicsRayQueryParameters3D.create(chair.global_position+Vector3.UP*3.0, chair.global_position+Vector3.UP*.1, 1)
	if not expect(space.intersect_ray(ray).get("collider") == chair.get_node("SolidBody"), "Library chair collision did not follow its scene node"): return false
	if edited:
		var old_ray := PhysicsRayQueryParameters3D.create(Vector3(-5,2,3),Vector3(-5,.1,3),1)
		if not expect(space.intersect_ray(old_ray).is_empty(), "A collider was left at the previous chair position"): return false
	map.player.position = chair.position+Vector3(0,.04,-1.2)
	var seat: Dictionary = room._near_seat()
	if not expect(not seat.is_empty() and seat.at.is_equal_approx(chair.position+Vector3.UP*.43) and is_equal_approx(float(seat.yaw),PI), "The Library seat position or facing changed"): return false
	var group: Node3D = room.art.get_node("JobStations")
	var props: Dictionary = room.job_art.props
	if not expect(group.get_child_count() == 5 and props.size() == 5, "A Library station is missing or duplicated"): return false
	for prop: Dictionary in props.values():
		var station: Node3D = prop.ring.get_parent()
		if not expect(station.get_parent() == group and station.get_node("TableTop").visible and not prop.ring.visible, "Library station art and highlight are not attached to the authored scene"): return false
		var origin := station.global_position
		var table_ray := PhysicsRayQueryParameters3D.create(origin+Vector3.UP,origin+Vector3.UP*.1,1)
		if not expect(space.intersect_ray(table_ray).get("collider") == station.get_node("TableBody"), "A Library job table is missing collision at its visible position"): return false
	return true
