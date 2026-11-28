extends SceneTree

const TOWN := "res://game/town.tscn"
const PARK := "res://game/skyhill/skyhill.tscn"
const LINK := preload("res://game/skyhill/town_link.gd")
const AVATARS := preload("res://game/avatars/catalog.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func _expect_scene(path: String) -> Node:
	for _i in 30:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path:
			return current_scene
	check(false, "Expected scene " + path)
	return null

func _run() -> void:
	set_meta("fishing_save_override", "user://skyhill-round-trip-%s.cfg" % Time.get_ticks_usec())
	var account := root.get_node("WillowbrookBrowserSession")
	var native := root.get_node("WillowbrookSession")
	account._character = "female-a"
	change_scene_to_file(TOWN)
	var town := await _expect_scene(TOWN)
	if town == null:
		quit(1)
		return
	check(town.arena_avatar.get_meta("avatar_id") == "female-a", "Town must start with the selected avatar")
	check(town._interaction_text() != "Visit Skyhill Park", "Skyhill should not be interactable from the main spawn")
	check(native.zone == "town", "Original Town session should start bound")
	var trail := town.get_node("TownLayout/SkyhillTrailhead")
	var point: Vector3 = trail.get_node("InteractPoint").global_position
	var arrival: Vector3 = trail.get_node("TownReturn").global_position
	var avatar: CharacterBody3D = town.player
	avatar.global_position = arrival
	avatar.rotation.y = PI
	avatar.held["up"] = true
	for _i in 25:
		await physics_frame
	avatar.held.clear()
	check(avatar.is_on_floor(), "The approach to the trailhead should be walkable")
	check(avatar.global_position.distance_to(point) < 2.4 and town._interaction_text() == "Visit Skyhill Park", "Walk-up must show the regular interaction prompt")
	press(KEY_E)
	var park := await _expect_scene(PARK)
	if park == null:
		quit(1)
		return
	check(park.get_node("Glider/RiderAnchor").get_child(0).get_meta("avatar_id") == "female-a", "Skyhill did not receive the selected avatar")
	check(native.zone.is_empty() and not has_meta(LINK.ARRIVAL), "Solo Skyhill must suspend Town presence and consume arrival data")
	check(park.town_return.visible and park.get_node("Scenery/Overlook/PicnicTable").scene_file_path.ends_with(".gltf"), "Town entry should offer return and show the editable picnic scenery")
	park.set_physics_process(false)
	park.action.pressed.emit()
	check(park.state == park.State.FLYING and not park.town_return.visible, "Launch should not show a conflicting return button")
	park._return_to_town()
	check(not park._returning_to_town, "Return to Town must not interrupt a flight")
	for _i in 850:
		park.step_flight(1.0 / 60.0, 0.0)
		if park.state != park.State.FLYING and park.state != park.State.LANDING:
			break
	check(park.state == park.State.MEADOW and park.town_return.visible, "Solo flight should land and offer Town return")
	park.action.pressed.emit()
	check(park.state == park.State.DECK and park.town_return.visible, "After the ride back up, the player can fly again or leave")
	park.town_return.pressed.emit()
	town = await _expect_scene(TOWN)
	if town == null:
		quit(1)
		return
	check(town.player.global_position.distance_to(arrival) < 0.15, "Return must use the authored Town marker")
	check(town.arena_avatar.get_meta("avatar_id") == "female-a" and native.zone == "town" and not has_meta(LINK.RETURN), "Town return must retain the avatar and rebind presence")
	check(town._interaction_text() != "Visit Skyhill Park", "Return marker should leave room before re-entering")
	town.player.global_position = point + Vector3.UP * 0.06
	town._interact()
	park = await _expect_scene(PARK)
	if park == null:
		quit(1)
		return
	check(park.town_return.visible, "Repeated visits must still allow return")
	press(KEY_R)
	town = await _expect_scene(TOWN)
	change_scene_to_file(PARK)
	park = await _expect_scene(PARK)
	if park != null:
		check(park.get_node("Glider/RiderAnchor").get_child(0).get_meta("avatar_id") == AVATARS.DEFAULT and not park.town_return.visible, "Standalone opens with the default rider and no Town return")
	if failures == 0:
		print("PASS Town/Skyhill round trip: walk-up, selected rider, launch, touchdown/retry, both return controls, session restore and standalone")
	quit(0 if failures == 0 else 1)
