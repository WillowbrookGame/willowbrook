extends "res://game/map.gd"
## Warehouse Yard owns marker controls, local rounds, and the online match view.
## The map shell still owns player/avatar creation, camera, and common HUD.
const WAREHOUSE_YARD = preload("res://game/warehouse_yard.gd")

class VisorSplatOverlay extends Control:
	var tint := Color("#ff7886")
	var duration := 2.2
	var remaining := 0.0
	var blobs: Array[Dictionary] = []
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rng.randomize()
		hide()

	func splat(color: Color, seconds: float) -> void:
		tint = color
		duration = maxf(0.1, seconds)
		remaining = duration
		blobs.clear()
		# Place 6 main splatters + 10 smaller droplets, keeping dead-center clear enough to see.
		for i in 6:
			var angle := (TAU / 6.0) * i + _rng.randf_range(-0.35, 0.35)
			var dist := _rng.randf_range(0.18, 0.42)
			blobs.append({
				"uv": Vector2(0.5 + cos(angle) * dist, 0.5 + sin(angle) * dist * 0.85),
				"radius": _rng.randf_range(0.065, 0.125),
				"drip": _rng.randf_range(0.025, 0.065),
				"alpha": 0.30,
			})
		for i in 10:
			var angle := _rng.randf_range(0.0, TAU)
			var dist := _rng.randf_range(0.12, 0.46)
			blobs.append({
				"uv": Vector2(0.5 + cos(angle) * dist, 0.5 + sin(angle) * dist * 0.88),
				"radius": _rng.randf_range(0.016, 0.042),
				"drip": _rng.randf_range(0.0, 0.03),
				"alpha": 0.36,
			})
		show()
		queue_redraw()

	func clear() -> void:
		remaining = 0.0
		blobs.clear()
		hide()

	func tick(delta: float) -> void:
		if remaining <= 0.0:
			return
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			hide()
		else:
			queue_redraw()

	func _draw() -> void:
		if remaining <= 0.0:
			return
		var progress := 1.0 - (remaining / duration)
		var fade := clampf(remaining / minf(0.55, duration), 0.0, 1.0)
		var sz := size
		var min_dim := minf(sz.x, sz.y)
		# Soft full-viewport glaze so the immunity state reads immediately.
		draw_rect(Rect2(Vector2.ZERO, sz), Color(tint.r, tint.g, tint.b, 0.08 * fade), true)
		for b: Dictionary in blobs:
			var uv: Vector2 = b.uv
			var r: float = float(b.radius) * min_dim
			var drip_len: float = float(b.drip) * min_dim * progress
			var pos := Vector2(uv.x * sz.x, uv.y * sz.y + drip_len * 0.35)
			var col := Color(tint.r, tint.g, tint.b, float(b.alpha) * fade)
			draw_circle(pos, r, col)
			if drip_len > 2.0:
				var drip_w := maxf(3.0, r * 0.24)
				draw_line(pos, pos + Vector2(0.0, r * 0.65 + drip_len), col, drip_w, true)
				draw_circle(pos + Vector2(0.0, r * 0.65 + drip_len), drip_w * 0.55, col)

var marker_preview: Node3D
var arena_match: Node3D
var arena_online: Node
var touch_fire_button: Button
var reticle: Label
var hitmarker: Label
var visor_splat: VisorSplatOverlay
var _hitmarker_time := 0.0
var _tagged_flash_time := 0.0
var _tagged_flash_color := Color("#ff7886")
var _flash_edges: Array[ColorRect] = []
var _mouse_holding_fire := false
@onready var yard := $WarehouseYard as WAREHOUSE_YARD


func _build_zone_geometry() -> void:
	door_position = yard.town_exit
	ZONE_GEOMETRY.build_arena_exit(self, door_position)


func _setup_zone_player() -> void:
	player.position = yard.south_lobby
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
	visor_splat = VisorSplatOverlay.new()
	visor_splat.name = "VisorPaintSplat"
	visor_splat.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(visor_splat)
	reticle = Label.new()
	reticle.text = "+"
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.add_theme_font_size_override("font_size", 24)
	reticle.add_theme_constant_override("outline_size", 5)
	hud.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	hitmarker = Label.new()
	hitmarker.text = "×"
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hitmarker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hitmarker.add_theme_font_size_override("font_size", 32)
	hitmarker.add_theme_constant_override("outline_size", 6)
	hitmarker.add_theme_color_override("font_color", Color("#4ce9fc"))
	hitmarker.hide()
	hud.add_child(hitmarker)
	hitmarker.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	for preset in [Control.PRESET_TOP_WIDE, Control.PRESET_BOTTOM_WIDE, Control.PRESET_LEFT_WIDE, Control.PRESET_RIGHT_WIDE]:
		var edge := ColorRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.color = Color(1, 1, 1, 0)
		edge.set_anchors_preset(preset)
		match preset:
			Control.PRESET_TOP_WIDE: edge.offset_bottom = 18.0
			Control.PRESET_BOTTOM_WIDE: edge.offset_top = -18.0
			Control.PRESET_LEFT_WIDE: edge.offset_right = 18.0
			Control.PRESET_RIGHT_WIDE: edge.offset_left = -18.0
		edge.hide()
		hud.add_child(edge)
		_flash_edges.append(edge)


func flash_hitmarker() -> void:
	_hitmarker_time = 0.22
	if hitmarker != null:
		hitmarker.show()


func flash_tagged(tint: Color, duration := 2.2) -> void:
	_tagged_flash_color = tint
	_tagged_flash_time = 0.65
	if visor_splat != null:
		visor_splat.splat(tint, duration)


func _build_zone_buttons(hud: CanvasLayer) -> void:
	touch_fire_button = Button.new()
	touch_fire_button.name = "TouchFire"
	touch_fire_button.text = "Fire"
	touch_fire_button.focus_mode = Control.FOCUS_NONE
	touch_fire_button.hide()
	touch_fire_button.pressed.connect(_fire_marker)
	hud.add_child(touch_fire_button)


func _fit_zone_hud(physical_width: float, s: float) -> void:
	# Place Fire on the right side so tablet players can move with their left
	# thumb and aim/fire with their right thumb. On compact viewports (<500 CSS px),
	# sit Fire beside Jump instead of stacking vertically above the camera stick.
	var view := get_viewport().get_visible_rect().size
	if physical_width >= 500.0:
		HUD_FIT.right_button(touch_fire_button, Vector2(88, 52), 116.0, s, true)
	else:
		HUD_FIT.right_button(touch_fire_button, Vector2(82, 46), 58.0, s, true)
		var beside_shift := (82.0 + 10.0) * s
		touch_fire_button.offset_left -= beside_shift
		touch_fire_button.offset_right -= beside_shift
	var top_y := view.y + touch_fire_button.offset_top
	var min_top := 8.0 * s
	if top_y < min_top:
		var push_down := min_top - top_y
		touch_fire_button.offset_top += push_down
		touch_fire_button.offset_bottom += push_down
	touch_fire_button.add_theme_font_size_override("font_size", roundi(18.0 * s))


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
		arena_match.player_scored_tag.connect(flash_hitmarker)
		arena_match.player_was_tagged.connect(flash_tagged)
		arena_match.setup(player, marker_preview, hud, yard, profile)


func _reset_arena_round_view() -> void:
	_reset_input_context()
	if visor_splat != null:
		visor_splat.clear()
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
	var local_active: bool = arena_online == null and (arena_match == null or bool(arena_match.is_playing()))
	var online_active: bool = arena_online != null and bool(arena_online.is_playing())
	if _mouse_holding_fire and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_holding_fire = false
	if local_active:
		marker_preview.set_holding_fire(_mouse_holding_fire and not _world_input_blocked())
		marker_preview.tick(delta, camera)
	else:
		if marker_preview != null:
			marker_preview.set_holding_fire(false)
		if online_active and _mouse_holding_fire and not _world_input_blocked():
			arena_online.paint()
	_update_reticle_and_flash(delta, local_active, local_active or online_active)


func _update_reticle_and_flash(delta: float, local_active: bool, match_active: bool) -> void:
	if reticle != null:
		var aimed: bool = local_active and not _world_input_blocked() and marker_preview != null and bool(marker_preview.has_aim_target(camera))
		reticle.add_theme_color_override("font_color", Color("#7dff9b") if aimed else Color.WHITE)
	if _hitmarker_time > 0.0:
		_hitmarker_time = maxf(0.0, _hitmarker_time - delta)
		if hitmarker != null:
			hitmarker.visible = _hitmarker_time > 0.0
	if visor_splat != null:
		if not match_active:
			visor_splat.clear()
		else:
			visor_splat.tick(delta)
	if _tagged_flash_time > 0.0:
		_tagged_flash_time = maxf(0.0, _tagged_flash_time - delta)
		var alpha := (_tagged_flash_time / 0.65) * 0.55
		for edge in _flash_edges:
			edge.color = Color(_tagged_flash_color.r, _tagged_flash_color.g, _tagged_flash_color.b, alpha)
			edge.visible = alpha > 0.01


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
	_mouse_holding_fire = false
	if marker_preview != null:
		marker_preview.set_holding_fire(false)
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
	if not _world_input_blocked() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_holding_fire = true
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
