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

func key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	root.push_input(event)

func press(key: Key) -> void:
	key_event(key, true)
	key_event(key, false)

func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

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
	check(native.zone == "skyhill" and not has_meta(LINK.ARRIVAL), "Skyhill must replace Town presence and consume arrival data")
	check(park.town_return.visible and park.get_node("Scenery/Overlook/PicnicTable/Art").scene_file_path.ends_with(".gltf"), "Town entry should offer return and show the editable picnic scenery")
	check(park.walker.get_node("Body").get_child(0).get_meta("avatar_id") == "female-a", "Walking should use the same selected avatar")
	check(park.walker.visible and not park.get_node("Glider/RiderAnchor").visible and not park.action.visible, "Town entry should start on foot, away from the mount")
	press(KEY_E)
	check(park.state == park.State.DECK, "E from the overlook should not auto-launch")
	var table: Node3D = park.get_node("Scenery/Overlook/PicnicTable")
	park.walker.global_position = table.to_global(Vector3(0.0, 0.08, 1.25))
	for _i in 14:
		await physics_frame
	press(KEY_E)
	check(not park.walker.is_seated() and not park.action.visible, "The short end of the picnic table has no seat")
	var seats := ["PicnicTable/EastSeat", "PicnicTable/WestSeat", "Bench/Seat"]
	for index in seats.size():
		var seat: Marker3D = park.get_node("Scenery/Overlook/" + seats[index])
		var approach: Marker3D = seat.get_node("Approach")
		# Move close, then walk toward the furniture using normal physics/input.
		var outside := (approach.global_position - seat.global_position).slide(Vector3.UP).normalized()
		park.walker.global_position = approach.global_position + outside * 0.22 + Vector3.UP * 0.08
		var key := KEY_S if outside.z < 0.0 else KEY_W
		if index < 2:
			key = KEY_A if outside.x > 0.0 else KEY_D
			var local := seat.position
			# Scaled upper faces of the imported picnic plank, not the short ends.
			check(absf(local.x) >= 0.45 * 1.01 and absf(local.x) <= 0.95 * 1.01 and absf(local.z) <= 0.95 * 0.82 and is_equal_approx(local.y, 0.60 * 0.78), "Picnic seat must be on the modeled plank")
			check(seat.basis.z.dot(Vector3(-signf(local.x), 0.0, 0.0)) > 0.99, "Picnic seat must face the table")
		key_event(key, true)
		for _i in 12:
			await physics_frame
		key_event(key, false)
		park._refresh_deck_hud()
		check(park.walker.nearby_seat() == seat and park.action.text.begins_with("Sit") and park.action.visible, "Walking up should offer Sit at " + seats[index])
		if index == 2:
			park._touch_seen = true
			park._refresh_deck_hud()
			check(park.action.text == "Sit", "Touch Sit should omit the keyboard hint")
			await process_frame
		var approach_position: Vector3 = park.walker.global_position
		if index == 2:
			click(park.action)
		else:
			press(KEY_E)
		check(park.walker.is_seated() and park.walker.global_position.is_equal_approx(seat.global_position), "Sit should place the walker on " + seats[index])
		check(absf(angle_difference(park.walker.body.global_rotation.y, seat.global_rotation.y)) < 0.001 and park.walker._animation.current_animation == "sit", "Sit should face the authored direction and play the sitting animation")
		check(park.action.text.begins_with("Stand up") and not park.walk_stick.visible and not park.walker.can_mount(), "Seated action must stand up, not launch")
		key_event(KEY_W, true)
		for _i in 4:
			await physics_frame
		key_event(KEY_W, false)
		check(park.walker.global_position.is_equal_approx(seat.global_position), "Movement must not dislodge a seated player")
		if index == 2:
			click(park.action)
		else:
			press(KEY_E)
		check(not park.walker.is_seated() and park.walker.global_position.is_equal_approx(approach_position), "Stand should return to the walk-up point")
		check(park.walker.body.position.is_zero_approx() and park.walker._animation.current_animation == "idle", "Standing should reset the visual offset and pose")
		for _i in 4:
			await physics_frame
		check(park.walker.is_on_floor(), "Standing up should leave the walker grounded")
	park._on_deck()
	var arrival_on_deck: Vector3 = park.walker.global_position
	key_event(KEY_D, true)
	for _i in 135:
		await physics_frame
	key_event(KEY_D, false)
	check(park.walker.global_position.x > 4.0 and park.walker.global_position.x < 6.1 and park.walker.is_on_floor(), "Deck rails should stop the walker without falling")
	park._on_deck()
	park._touch_seen = true
	park._refresh_deck_hud()
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 12
	touch.position = park.walk_stick.get_global_rect().get_center() + Vector2(0,-25)
	park._input(touch)
	var walk_touch: Vector2 = park._walk_touch
	for _i in 26:
		await physics_frame
	touch.pressed = false
	park._input(touch)
	check(park.walker.global_position.z < arrival_on_deck.z - 1.0 and park.touch_index < 0, "Touch should move the walker and release cleanly (%s → %s; touch: %s; index: %d)" % [arrival_on_deck, park.walker.global_position, walk_touch, park.touch_index])
	key_event(KEY_W, true)
	for _i in 90:
		await physics_frame
		if park.action.visible:
			break
	key_event(KEY_W, false)
	check(park.action.visible and park.walker.can_mount(), "Launch must become available beside the glider")
	if not park.action.visible:
		quit(1)
		return
	park.set_physics_process(false)
	park.action.pressed.emit()
	check(park.state == park.State.FLYING and not park.town_return.visible and not park.walker.visible and park.get_node("Glider/RiderAnchor").visible and not park.walk_stick.visible, "Launch should switch from deck walking to flight")
	park._return_to_town()
	check(not park._returning_to_town, "Return to Town must not interrupt a flight")
	for _i in 850:
		park.step_flight(1.0 / 60.0, 0.0)
		if park.state != park.State.FLYING and park.state != park.State.LANDING:
			break
	check(park.state == park.State.MEADOW and not park.town_return.visible, "After landing, the player rides up before going to Town")
	park.action.pressed.emit()
	check(park.state == park.State.DECK and park.town_return.visible and park.walker.visible and not park.action.visible, "Ride back up should restore on-foot deck mode")
	park.walker.global_position = park.walker.mount.global_position
	park._refresh_deck_hud()
	press(KEY_E)
	check(park.state == park.State.FLYING, "The player can walk up and relaunch")
	park._crash(park.flight.position, "Test crash")
	for _i in 125:
		park._physics_process(1.0/60.0)
	check(park.state == park.State.DECK and park.walker.visible and not park.action.visible, "Crash recovery must return to the overlook on foot")
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
		print("PASS Town/Skyhill round trip: selected avatar, keyboard/touch deck walking, all three seats, edge guards, deliberate launch, landing/crash recovery, and Town/standalone return")
	quit(0 if failures == 0 else 1)
