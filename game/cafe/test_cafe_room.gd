extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const LAYOUT := "res://game/cafe/room_layout.tscn"
const CHAIR_ORIGIN := Vector3(-3.65,.03,3.6)
const MOVED_CHAIR := Vector3(-3.65,.03,4.65)

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
	var town := current_scene
	var door: Vector3 = TOWN.BUSINESS_DOORS["cafe"]
	town.player.position = door+Vector3(0,.04,-1.3)
	interact(town)
	if not expect(town.changing,"Town door did not open the Cafe"): return
	await scene_changed
	var map := current_scene
	var room: Node3D = map.room
	var art: Node3D = room.art
	if not expect(map.room_id == "cafe" and art.scene_file_path == LAYOUT and room.art.conversation_actor == art.get_node("Barista"),"Authored Cafe layout or barista missing"): return
	if not expect(map.player.position.is_equal_approx(Vector3(0,.04,5.5)),"Cafe spawn moved"): return
	await physics_frame
	await physics_frame
	var space := art.get_world_3d().direct_space_state
	if not expect(room.art.public_seats.size() == 8,"Cafe seating inventory changed"): return
	for row: Dictionary in room.art.public_seats:
		var chair: Node3D = row.chair
		if not expect(_hit(space,chair.global_position) == chair.get_node("SolidBody"),"A Cafe chair is missing its collider"): return
	for key: String in ["PastryCounter","BackLeftTable","FrontLeftTable","BackRightTable","FrontRightTable","LeftPlant","RightPlant"]:
		var fixture: Node3D = art.get_node(key)
		if not expect(_hit(space,fixture.global_position) == fixture.get_node("SolidBody"),"A Cafe fixture is missing its collider: "+key): return
	if not expect(art.has_node("FrontLeftTable/FrontLeftCoffee/Model") and art.has_node("PastryCounter/MiddlePastry/Model") and art.has_node("MenuBoard/MenuBoardText"),"Food props or menu text are not attached to their fixture"): return
	var stations: Node3D = art.get_node("JobStations")
	if not expect(stations.get_child_count() == 4 and room.job_art.props.size() == 4 and room.job_art.starter_markers.size() == 2,"Cafe work/starter stations missing or duplicated"): return
	for row: Dictionary in room.job_art.props.values():
		var station := row.ring.get_parent() as Node3D
		if not expect(station.get_parent() == stations and not row.ring.visible and _hit(space,station.global_position) == station.get_node("TableBody"),"Cafe station collider or idle state is incorrect"): return
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var seat: Node3D = art.get_node("FrontLeftInnerChair")
	if not expect(seat.position.is_equal_approx(MOVED_CHAIR if edited else CHAIR_ORIGIN),"Expected Cafe chair placement not loaded"): return
	if edited and not expect(_hit(space,CHAIR_ORIGIN) == null,"A collider remained at the old Cafe chair position"): return
	map.player.global_position = seat.global_position+Vector3(0,.04,1.12)
	for frame in range(5):
		await physics_frame
	var origin: Vector3 = map.player.position
	if not expect(room.interaction_prompt() == "Sit down","Cafe chair did not offer sitting"): return
	interact(map)
	var cushion := seat.to_global(Vector3(0,.548,-.02))
	if not expect(room.seated and map.player.global_position.distance_to(cushion) < .003 and absf(angle_difference(room.network_rest_yaw(),seat.global_rotation.y)) < .001,"Cafe seating did not follow cushion or orientation"): return
	interact(map)
	if not expect(not room.seated and map.player.position.is_equal_approx(origin),"Standing did not return the player to the approach point"): return
	map.player.position = Vector3(0,.04,6.55)
	interact(map)
	if not expect(map.changing,"Cafe exit did not return to Town"): return
	await scene_changed
	if not expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,-2.0)),"Cafe Town return moved"): return
	print("PASS: Cafe doors, eight seats, cushion/facing, furniture, four colliding job tables, and idle markers.")
	quit(0)

func _hit(space: PhysicsDirectSpaceState3D, point: Vector3) -> Object:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.5,point+Vector3.UP*.1,1)
	return space.intersect_ray(ray).get("collider")
