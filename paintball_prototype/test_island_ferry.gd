extends SceneTree
const TOWN := preload("res://paintball_prototype/town_layout.gd")
const ISLAND := preload("res://paintball_prototype/beach_layout.gd")
const TOWN_SCENE := "res://paintball_prototype/town.tscn"
const ISLAND_SCENE := "res://paintball_prototype/beach.tscn"
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failed = true
		push_error(detail)

func _terrain(scene: Node3D, at: Vector3) -> Dictionary:
	var space := scene.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP,at-Vector3.UP,1))

func _run() -> void:
	set_meta("willowbrook_save_override","user://b9-ferry-disposable.cfg")
	change_scene_to_file(TOWN_SCENE)
	await scene_changed
	await physics_frame
	await physics_frame
	var town := current_scene
	_check(town.has_node("TownLayout/FerryLanding/WillowbrookShuttle"),"Town ferry is missing its boat")
	_check(town.has_node("TownLayout/TownBayWater") and not town.has_node("TownLayout/OpenBeachGate"),"Old gate is still present or no water was added")
	_check(_terrain(town,Vector3(-24,0,65)).is_empty(),"Town floor stretches over the bay")
	_check(not _terrain(town,Vector3(-5,0,61)).is_empty(),"Town ferry pier is not solid")
	_check(town._interaction_text() != "Ferry to the island","Ferry prompt visible from Town spawn")
	town.player.position = TOWN.BEACH_DOOR + Vector3(0,2,0)
	_check(not town._near_ferry(),"Ferry can be activated from above the pier")
	town.player.position = TOWN.BEACH_DOOR + Vector3(0,.04,-1.4)
	_check(town._interaction_text() == "Ferry to the island","Ferry prompt missing at Town approach")
	town._interact()
	town._interact()
	_check(town.changing and town.player.movement_locked,"Repeating ferry activation did not preserve the crossing lock")
	_check(await _check_ride(town),"Town boarding, visible departure and late card did not complete")
	await scene_changed
	await physics_frame
	await physics_frame
	var island := current_scene
	_check(island.scene_file_path == ISLAND_SCENE and island.current_zone_id() == "beach","Island changed its multiplayer scene identity")
	_check(island.player.position.distance_to(ISLAND.SPAWN) < .25 and not _terrain(island,ISLAND.SPAWN).is_empty(),"Arrival didn't use safe Island landing")
	_check(_terrain(island,Vector3(22,0,46)).is_empty(),"Island terrain stretches past the visible shore")
	_check(island.has_node("BeachLayout/FerryLanding/WillowbrookShuttle"),"Island return boat is missing")
	_check(island.fishing_ui != null and island.fishing_ui.wave_audio.playing,"Existing fishing or island waves missing")
	var range_checks := [[Vector3(2.8,0,2),"rod"],[Vector3(0,0,-17),"fishing pier"],[Vector3(32,0,-7),"rental dock"],[Vector3(-19,0,28.5),"shop"],[Vector3(-46.05,0,3.5),"slide"]]
	for pair: Array in range_checks:
		_check(not _terrain(island,pair[0]).is_empty(),"Missing floor for "+pair[1])
	island.player.position = ISLAND.TOWN_DOOR
	_check(island._interaction_text() == "Ferry to town","Island return prompt missing")
	island.enter_button.pressed.emit()
	_check(island.changing,"Existing on-screen interaction button didn't board the ferry")
	_check(await _check_ride(island),"Island boarding, visible departure and late card did not complete")
	if not island.changing:
		quit(1)
		return
	await scene_changed
	_check(current_scene.scene_file_path == TOWN_SCENE and current_scene.player.position.distance_to(TOWN.BEACH_RETURN) < .25,"Return arrival didn't use safe Town landing")
	if not failed:
		print("PASS two ferry landings, water isolation, proximity/height/repeat gate, crossing input lock, safe entry and button return, and existing beach paths.")
	quit(1 if failed else 0)


func _check_ride(origin) -> bool:
	if origin == null or not origin.changing or origin._ferry_landing == null:
		return false
	var landing = origin._ferry_landing
	var boat := landing.get_node("WillowbrookShuttle") as Node3D
	var mesh := boat.find_child("InnerscenePassengerFerry",false,false) as Node3D
	var gate := boat.find_child("PortGate",true,false) as Node3D
	_check(mesh != null and gate != null,"Bundled passenger ferry / hinged port gate missing")
	if gate != null:
		_check(is_equal_approx(gate.rotation.x,PI/2),"Port gate not open while docked")
		_check(absf(gate.global_position.z-landing.boarding_points()[3].z)<.07,"Port gate not aligned to boarding approach")
	var start_z := boat.global_position.z
	var start_player: Vector3 = origin.player.global_position
	var saw_walk := false
	var saw_deck := false
	var saw_carried := false
	var saw_late_card := false
	while is_instance_valid(origin) and current_scene == origin:
		await process_frame
		if not is_instance_valid(origin) or current_scene != origin:
			break
		var moved := boat.global_position.z-start_z
		var on_deck: bool = origin._ferry_segment == origin._ferry_points.size()
		if not on_deck:
			_check(moved < .01 and not is_instance_valid(origin._ferry_card),"Boat departed or card covered player before boarding")
			saw_walk = saw_walk or (origin.arena_avatar.visible and origin.arena_animation.current_animation=="walk" and origin._ferry_foot.distance_to(start_player) > 1.0)
		elif moved < .01:
			saw_deck = saw_deck or (saw_walk and origin.arena_avatar.visible and origin.arena_avatar.global_position.distance_to(landing.deck_position()) < .28)
		elif moved > 1.3 and not is_instance_valid(origin._ferry_card):
			_check(gate == null or gate.rotation.x < 1.50,"Port gate did not begin closing after boarding")
			saw_carried = saw_carried or (saw_deck and origin.arena_avatar.visible and origin.arena_avatar.global_position.distance_to(landing.deck_position()) < .28)
		_check(Vector2(origin.player.global_position.x-start_player.x,origin.player.global_position.z-start_player.z).length() < .14,"Ferry moved network player hull position before scene transition")
		if is_instance_valid(origin._ferry_card):
			_check(on_deck and moved > 4.0,"Sailing card hid the rider too early")
			saw_late_card = true
			return saw_walk and saw_deck and saw_carried
	return saw_walk and saw_deck and saw_carried and saw_late_card
