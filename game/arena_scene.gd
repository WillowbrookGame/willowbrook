extends "res://game/map.gd"
## Warehouse Yard owns marker controls, local rounds, and the online match view.
## The map shell still owns player/avatar creation, camera, and common HUD.
const WAREHOUSE_YARD = preload("res://game/warehouse_yard.gd")

var marker_preview: Node3D
var arena_match: Node3D
var arena_online: Node
var touch_fire_button: Button
@onready var yard := $WarehouseYard as WAREHOUSE_YARD


func _build_zone_geometry() -> void:
	door_position = WAREHOUSE_YARD.TOWN_EXIT
	ZONE_GEOMETRY.build_arena_exit(self, door_position)


func _setup_zone_player() -> void:
	player.position = WAREHOUSE_YARD.SOUTH_LOBBY
	player.world_bounds = WAREHOUSE_YARD.WORLD_BOUNDS
	player.arena_movement = true
	player.collision_mask = 3
	player.process_physics_priority = -10
	player.floor_snap_length = 0.47


func _setup_zone_avatar() -> void:
	var marker_script := load("res://game/arena_marker.gd") as Script
	marker_preview = marker_script.new()
	marker_preview.name = "ArenaMarker"
	add_child(marker_preview)
	marker_preview.setup(arena_avatar, arena_animation, player)


func _build_zone_overlay(hud: CanvasLayer) -> void:
	var reticle := Label.new()
	reticle.text = "+"
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.add_theme_constant_override("outline_size", 4)
	hud.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _build_zone_buttons(hud: CanvasLayer) -> void:
	touch_fire_button = Button.new()
	touch_fire_button.name = "TouchFire"
	touch_fire_button.text = "Fire"
	touch_fire_button.focus_mode = Control.FOCUS_NONE
	touch_fire_button.hide()
	touch_fire_button.pressed.connect(_fire_marker)
	hud.add_child(touch_fire_button)


func _fit_zone_hud(physical_width: float, s: float) -> void:
	var side_by_side := physical_width >= 500.0
	var button_size := Vector2(76,52)*s
	var stick_left := movement_thumbstick.offset_left
	var stick_right := movement_thumbstick.offset_right
	var x := stick_right+12.0*s if side_by_side else stick_left+(stick_right-stick_left-button_size.x)*.5
	var bottom := movement_thumbstick.offset_bottom if side_by_side else movement_thumbstick.offset_top-12.0*s
	touch_fire_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	touch_fire_button.offset_left=x
	touch_fire_button.offset_right=x+button_size.x
	touch_fire_button.offset_bottom=bottom
	touch_fire_button.offset_top=bottom-button_size.y
	touch_fire_button.add_theme_font_size_override("font_size",roundi(18.0*s))


func _setup_zone(hud: CanvasLayer) -> void:
	if get_tree().has_meta("paintball_online"):
		get_tree().remove_meta("paintball_online")
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if account != null and account.has_method("paintball_epoch") and not account.paintball_epoch().is_empty():
			var online_script := load("res://game/network/paintball/online_paintball_view.gd") as Script
			arena_online = online_script.new()
			arena_online.name = "OnlinePaintball"
			add_child(arena_online)
			player.set_physics_process(false)
			arena_online.setup(self,hud,account,true)
	if get_tree().has_meta("paintball_single_player"):
		get_tree().remove_meta("paintball_single_player")
		var local_script := load("res://game/match_local.gd") as Script
		arena_match = local_script.new()
		arena_match.name = "SinglePlayerMatch"
		add_child(arena_match)
		arena_match.finished.connect(_return_to_town_after_match)
		arena_match.round_started.connect(_reset_arena_round_view)
		arena_match.setup(player, marker_preview, hud)


func _reset_arena_round_view() -> void:
	_reset_input_context()
	look_yaw = 0.0
	look_pitch = DEFAULT_LOOK_PITCH
	look_shoulder = 1.0
	player.rotation.y = look_yaw
	_update_camera()


func _bind_world_session(session: Node) -> void:
	if session.has_method("suspend_zone"):
		session.suspend_zone()
		if session.has_method("bind_arena_chat"):
			session.bind_arena_chat(self)


func _update_zone_controls(blocked: bool) -> void:
	if touch_fire_button != null:
		touch_fire_button.visible = camera_thumbstick.visible and not blocked


func _tick_zone(delta: float) -> void:
	_update_camera(delta)
	var clip := "walk" if player.active and player.get_real_velocity().length_squared() > 0.15 else "idle"
	if arena_online != null:
		arena_online.tick(delta)
		var pose: Dictionary = arena_online.owner_pose
		clip = "idle" if pose.is_empty() else ("fall" if not pose.grounded else ("walk" if pose.moving else "idle"))
	elif not player.is_on_floor():
		clip = "jump" if player.velocity.y > 0.0 else "fall"
	if arena_animation.current_animation != clip:
		arena_animation.play(clip, 0.12)
	arena_animation.advance(delta)
	marker_preview.update_hand(look_pitch, arena_avatar.visible)
	if arena_match != null:
		arena_match.tick(delta)
	if arena_online == null and (arena_match == null or arena_match.is_playing()):
		marker_preview.tick(delta, camera)


func _update_zone_cutaway() -> bool:
	return yard.update_cutaway(player.position)


func _zone_jump_active() -> bool:
	return super._zone_jump_active() or (arena_online != null and arena_online.is_playing())


func _zone_local_actions_paused() -> bool:
	return arena_match != null and not arena_match.is_playing()


func _zone_owns_interaction() -> bool:
	return arena_online != null


func _zone_blocks_world() -> bool:
	return arena_online != null and arena_online.blocks_world()


func _reset_zone_inputs() -> void:
	if arena_online != null:
		arena_online.reset_inputs()


func _request_world_jump() -> void:
	if arena_online != null:
		arena_online.jump()
		return
	super._request_world_jump()


func _consume_zone_input(event: InputEvent) -> bool:
	# Space is always jump, never a scoreboard confirmation. Filter before GUI
	# input, including releases and repeats across the round boundary.
	var not_playing: bool = _zone_local_actions_paused() or (arena_online != null and not arena_online.is_playing())
	return not_playing and event is InputEventKey and (event.physical_keycode == KEY_SPACE or event.keycode == KEY_SPACE)


func _world_primary_action() -> bool:
	_fire_marker()
	return true


func _fire_marker() -> void:
	if _world_input_blocked():
		return
	if arena_online != null:
		arena_online.paint()
	elif marker_preview != null:
		marker_preview.trigger()


func _try_door() -> void:
	if changing or not _near_door():
		return
	if arena_online != null:
		arena_online.leave()
	else:
		_return_to_town_after_match()


func _return_to_town_after_match() -> void:
	if changing:
		return
	var tree := get_tree()
	changing = true
	var result := tree.change_scene_to_file(TOWN)
	if result == OK:
		tree.set_meta("paintball_town_return",true)
	else:
		changing = false
		push_error("Could not return to town: %s" % error_string(result))
