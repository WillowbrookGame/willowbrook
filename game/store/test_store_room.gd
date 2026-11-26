extends SceneTree

const TOWN := preload("res://game/town_layout.gd")
const DATA := preload("res://game/interiors/room_data.json")
const LAYOUT := "res://game/store/room_layout.tscn"
const FIXTURES := ["CheckoutCounter","LeftBoxShelf","LeftBagShelf","RightBoxShelf","RightBagShelf","FruitDisplay","BreadDisplay","Freezers","LeftPlant","RightPlant","SideBookcase","WaitingChair"]
const STATIONS := {
	"StationWorkStartStore":"TableBody","StationCheckStock":"TableBody",
	"StationCollectStock":"BoxBody","StationFillShelf":"BoxBody","StationParcel":"BoxBody",
}

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
	profile.home = {"plot":0,"variant":"starter"}
	profile.stars = 50
	if not expect(current_scene.profile_commit(profile),"Could not seed disposable Store customer"): return
	var door: Vector3 = TOWN.BUSINESS_DOORS["store"]
	for visit in range(2):
		var town := current_scene
		town.player.position = door + Vector3(0,.04,-1.3)
		interact(town)
		if not expect(town.changing,"Town interaction did not enter Store"): return
		await scene_changed
		var map := current_scene
		var room: Node3D = map.room
		if not expect(map.room_id == "store" and room.art.scene_file_path == LAYOUT,"Store did not load the editable layout"): return
		if not expect(map.player.position.is_equal_approx(Vector3(0,.04,5.5)),"Store spawn moved"): return
		await physics_frame
		await physics_frame
		if not _check_layout(room): return
		map.player.position = Vector3(0,.04,-1.55)
		interact(map)
		if not expect(room.active_panel == "store" and room.is_modal_open(),"Default checkout approach did not open the store menu"): return
		var buttons: Array[Node] = room.fields.find_children("*","Button",true,false).filter(func(node): return node.text == "Order furniture")
		if not expect(buttons.size() == 1,"Furniture order button missing"): return
		if visit == 0: buttons[0].pressed.emit()
		var saved: Dictionary = map.profile_snapshot()
		if not expect(saved.deliveries.size() == 1 and int(saved.deliveries[0].quantity) == 1,"Furniture order did not persist exactly once"): return
		if not expect(saved.stars == 50-int(DATA.data.furnitureCatalog[saved.deliveries[0].kind].price),"Incorrect furniture charge"): return
		room.close_modal()
		map.player.position = Vector3(0,.04,-6.85)
		if not expect(not room._near_clerk(),"Counter should not be usable from behind the shopkeeper"): return
		map.player.position = Vector3(0,.04,6.55)
		interact(map)
		if not expect(map.changing,"Could not exit Store through Town door"): return
		await scene_changed
		if not expect(current_scene.player.position.is_equal_approx(door+Vector3(0,.04,-2.0)),"Store return point moved"): return
	print("PASS: editable Store layout, fixture and station collision, real doors and checkout, and one persistent furniture order.")
	quit(0)

func _check_layout(room: Node3D) -> bool:
	var art: Node3D = room.art
	if not expect(room.art.conversation_actor == art.get_node("Shopkeeper"),"Shopkeeper not attached to the authored scene"): return false
	var edited := "--relocated" in OS.get_cmdline_user_args()
	var chair: Node3D = art.get_node("WaitingChair")
	var target := Vector3(-4,0,-3.6) if edited else Vector3(-5,0,-2.7)
	if not expect(chair.position.is_equal_approx(target),"Saved chair placement did not reach gameplay"): return false
	var space := art.get_world_3d().direct_space_state
	for name_: String in FIXTURES:
		var prop: Node3D = art.get_node(name_)
		if not expect(prop.get_node("Model") != null and _hit(space,prop.global_position) == prop.get_node("SolidBody"),"Store fixture missing matching collision: "+name_): return false
	if edited and not expect(_hit(space,Vector3(-5,0,-2.7)) == null,"A collider remained at the old chair position"): return false
	var group: Node3D = art.get_node("JobStations")
	if not expect(group.get_child_count() == STATIONS.size() and room.job_art.props.size() == STATIONS.size(),"Store job stations missing or duplicated"): return false
	for key: String in STATIONS:
		var station: Node3D = group.get_node(key)
		if not expect(_hit(space,station.global_position) == station.get_node(STATIONS[key]),"Store station missing matching collision: "+key): return false
	for prop: Dictionary in room.job_art.props.values():
		if not expect(prop.ring.get_parent().get_parent() == group and not prop.ring.visible,"Station highlight is not attached or appears while idle"): return false
	return expect(room.job_art.starter_markers.size() == 2,"Store starter hints missing")

func _hit(space: PhysicsDirectSpaceState3D, point: Vector3) -> Object:
	var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*3.5,point+Vector3.UP*.1,1)
	return space.intersect_ray(ray).get("collider")
