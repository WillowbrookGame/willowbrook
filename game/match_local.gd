extends Node3D
signal finished
signal round_started
signal player_scored_tag
signal player_was_tagged(color: Color, duration: float)
const ARENA_ACTOR_LAYER := 4
const ARENA_COLLISION_MASK := 7
const BOT_TURN_SPEED := 7.0
const BOT_AIM_TOLERANCE := 0.17
const BOT_AIM_TIMEOUT := 0.55
const TAG_COOLDOWN := 2.2
const SOLO_ROUND_LENGTH := 75.0
const SOLO_TARGET_POINTS := 12
const COUNTDOWN_STEP := 0.65
const YARD = preload("res://game/warehouse_yard.gd")
const RULES = preload("res://game/match_rules.gd")
const AVATARS = preload("res://game/avatars/catalog.gd")
const FX = preload("res://game/arena_marker.gd")
const SFX = preload("res://game/paintball_audio.gd")
const NAMES: Array[String] = ["You", "Pip", "Scout", "Sunny"]
const COLORS := [Color("#4ce9fc"), Color("#ff7886"), Color("#9cff6b"), Color("#ffbc52")]
var rules := RULES.new()
var player: CharacterBody3D
var fx: Node3D
var yard: YARD
var profile: RefCounted
var bots: Array[Dictionary] = []
var roster: Dictionary = {}
var actor_colors: Dictionary = {}
var tagged_until: Dictionary = {}
var overlay: CenterContainer
var heading: Label
var summary: Label
var action: Button
var hud: Label
var popup: Label
var notice := ""
var notice_time := 0.0
var clock_label := ""
var last_countdown_sec := -1
var start_countdown := 0.0
var last_start_beat := 0
var awarded_stars := 0
var rng := RandomNumberGenerator.new()

func setup(body: CharacterBody3D, paint: Node3D, canvas: CanvasLayer, authored_yard: YARD, user_profile: RefCounted = null) -> void:
	player = body
	fx = paint
	yard = authored_yard
	profile = user_profile
	rng.randomize()
	rules.setup(NAMES, SOLO_ROUND_LENGTH, SOLO_TARGET_POINTS)
	player.collision_layer = ARENA_ACTOR_LAYER
	player.collision_mask = ARENA_COLLISION_MASK
	roster[player] = NAMES[0]
	actor_colors[player] = COLORS[0]
	fx.actor_tag.connect(_on_player_tag)
	_build_hud(canvas)
	_set_player_enabled(false)

func is_playing() -> bool:
	return rules.phase == RULES.Phase.PLAYING and start_countdown <= 0.0

func is_counting_down() -> bool:
	return rules.phase == RULES.Phase.PLAYING and start_countdown > 0.0

func _allows_local_stars() -> bool:
	return not OS.has_feature("web") and profile != null and profile.has_method("change_stars")

func _build_hud(canvas: CanvasLayer) -> void:
	hud = Label.new()
	hud.position = Vector2(18,110)
	hud.add_theme_font_size_override("font_size", 19)
	hud.add_theme_constant_override("outline_size", 6)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	popup = Label.new()
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 26)
	popup.add_theme_constant_override("outline_size", 7)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.hide()
	canvas.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 64)
	overlay = CenterContainer.new()
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330,0)
	overlay.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+edge,22)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	heading = Label.new()
	heading.text = "Willowbrook Paintball"
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	summary = Label.new()
	var reward_line := "Finish all 3 rounds to earn Stars!" if _allows_local_stars() else "Every tag earns 1 point."
	summary.text = "You vs. Pip, Scout, and Sunny\n3 rounds · 1:15 each (or first to %d tags)\n%s" % [SOLO_TARGET_POINTS, reward_line]
	summary.add_theme_font_size_override("font_size", 18)
	column.add_child(summary)
	action = Button.new()
	action.text = "Start Round 1"
	action.custom_minimum_size.y = 46
	action.pressed.connect(_on_action)
	column.add_child(action)

func _set_player_enabled(enabled: bool) -> void:
	player.set_physics_process(enabled)
	player.held.clear()
	player.jump_buffer = 0.0
	player.active = false
	if not enabled:
		player.velocity = Vector3.ZERO
		fx.pending_shot = false

func _on_action() -> void:
	if rules.phase == RULES.Phase.FINISHED:
		action.disabled = true
		finished.emit()
	elif rules.start_round():
		overlay.hide()
		notice = ""
		notice_time = 0.0
		_reset_field()
		start_countdown = COUNTDOWN_STEP * 3.0
		last_start_beat = 4
		round_started.emit()
		_set_player_enabled(false)
		_update_countdown_ui()
		_update_hud(0.0)

func _pick_bot_avatars(count: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in AVATARS.MODELS.keys():
		pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var chosen: Array[String] = []
	for i in range(mini(count, pool.size())):
		chosen.append(pool[i])
	return chosen

func _reset_field() -> void:
	if bots.is_empty():
		var picks := _pick_bot_avatars(NAMES.size() - 1)
		for index in range(1,NAMES.size()):
			var avatar_id := picks[index - 1] if index - 1 < picks.size() else AVATARS.DEFAULT
			_create_bot(index, avatar_id)
	player.position = yard.match_spawns[0]
	player.velocity = Vector3.ZERO
	tagged_until.clear()
	last_countdown_sec = -1
	if popup != null:
		popup.hide()
	fx.clear_round_paint()
	for index in range(bots.size()):
		var bot := bots[index]
		var body: CharacterBody3D = bot.body
		body.position = yard.match_spawns[index+1]
		body.velocity = Vector3.ZERO
		bot.reload = 1.5 + index * 0.4
		bot.target = null
		bot.aim_left = 0.0
		bot.flee_delay = 0.0
		bot.flee_from = Vector3.ZERO
		bot.route = (index * 3) % yard.bot_waypoints.size()
		bot.stuck = 0.0
		var facing: Vector3 = yard.bot_waypoints[bot.route] - body.position
		body.rotation.y = atan2(-facing.x,-facing.z)
		bot.animation.play("idle")
		bot.animation.advance(0.0)
		bot.prop.update_hand(0.0,true)

func _create_bot(index: int, avatar_id := AVATARS.DEFAULT) -> void:
	var body := CharacterBody3D.new()
	body.name = NAMES[index]
	body.collision_layer = ARENA_ACTOR_LAYER
	body.collision_mask = ARENA_COLLISION_MASK
	body.floor_snap_length = 0.35
	add_child(body)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.52
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.77
	body.add_child(collider)
	var avatar := AVATARS.instantiate(avatar_id)
	body.add_child(avatar)
	avatar.rotation.y = PI
	avatar.scale = Vector3.ONE * 2.9
	var animation := AVATARS.animator(avatar)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle","walk"]:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var prop := FX.new()
	add_child(prop)
	prop.setup(avatar, animation, body)
	var badge := Label3D.new()
	badge.text = NAMES[index]
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.font_size = 46
	badge.pixel_size = 0.004
	badge.modulate = COLORS[index]
	badge.position.y = 1.72
	body.add_child(badge)
	roster[body] = NAMES[index]
	actor_colors[body] = COLORS[index]
	var strafe := 1.0 if index % 2 == 1 else -1.0
	bots.append({"body":body, "animation":animation, "prop":prop, "badge":badge, "avatar_id":String(avatar.get_meta("avatar_id", avatar_id)), "color":COLORS[index], "reload":0.0, "route":0,"stuck":0.0,"target":null,"aim_left":0.0,"flee_delay":0.0,"flee_from":Vector3.ZERO,"strafe_dir":strafe})

func _update_countdown_ui() -> void:
	var beat := ceili(start_countdown / COUNTDOWN_STEP)
	if beat != last_start_beat and beat > 0:
		last_start_beat = beat
		SFX.play(self, "tick", -7.0, 0.92 + (3 - beat) * 0.12)
	if popup != null and beat > 0:
		popup.text = "%d" % beat
		popup.add_theme_color_override("font_color", Color("#ffbc52"))
		popup.show()

func tick(delta: float) -> void:
	if rules.phase != RULES.Phase.PLAYING:
		return
	if start_countdown > 0.0:
		start_countdown = maxf(0.0, start_countdown - delta)
		if start_countdown > 0.0:
			_update_countdown_ui()
			_update_hud(0.0)
			return
		_set_player_enabled(true)
		SFX.play(self, "finish", -7.0, 1.12)
		notice = "PAINT!"
		notice_time = 0.7
		_update_hud(0.0)
		return
	for actor: Variant in tagged_until.keys():
		var left: float = float(tagged_until[actor]) - delta
		if left <= 0.0:
			tagged_until.erase(actor)
		else:
			tagged_until[actor] = left
	if rules.tick(delta):
		SFX.play(self, "finish", -6.0, 1.0)
		_show_results()
		return
	var sec := ceili(rules.remaining)
	if sec <= 5 and sec > 0 and sec != last_countdown_sec:
		last_countdown_sec = sec
		SFX.play(self, "tick", -8.0, 1.0 + (5 - sec) * 0.06)
	for bot in bots:
		_update_bot(bot,delta)
	_update_hud(delta)

func _update_bot(bot: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = bot.body
	if float(bot.flee_delay) > 0.0:
		bot.flee_delay = maxf(0.0, float(bot.flee_delay) - delta)
		if float(bot.flee_delay) <= 0.0:
			_flee_waypoint(bot, bot.flee_from)
	var goal: Vector3 = yard.bot_waypoints[bot.route]
	var move := goal - body.position
	move.y = 0.0
	if move.length_squared() < 0.9 or bot.stuck > 0.65:
		bot.route = (int(bot.route) + rng.randi_range(1,3)) % yard.bot_waypoints.size()
		bot.stuck = 0.0
		bot.strafe_dir = -float(bot.strafe_dir)
		goal = yard.bot_waypoints[bot.route]
		move = Vector3(goal.x-body.position.x,0,goal.z-body.position.z)
	bot.reload -= delta
	if bot.reload <= 0.0 and not is_instance_valid(bot.target):
		bot.reload = rng.randf_range(0.8,1.45)
		bot.target = _visible_target(body)
		bot.aim_left = BOT_AIM_TIMEOUT
	var target := bot.target as CharacterBody3D
	var facing := move
	var direction := move.normalized()
	if is_instance_valid(target):
		facing = target.position - body.position
		facing.y = 0.0
		bot.aim_left -= delta
		if facing.length_squared() > 0.04:
			var strafe := Vector3(-facing.z, 0.0, facing.x).normalized() * float(bot.strafe_dir)
			direction = (direction * 0.35 + strafe * 0.65).normalized()
	var aligned := false
	if facing.length_squared() > 0.01:
		var desired_yaw := atan2(-facing.x,-facing.z)
		body.rotation.y = rotate_toward(body.rotation.y,desired_yaw,BOT_TURN_SPEED*delta)
		aligned = absf(angle_difference(body.rotation.y,desired_yaw)) <= BOT_AIM_TOLERANCE
	body.velocity = Vector3(direction.x * 3.15, -0.3 if body.is_on_floor() else body.velocity.y - 19.0 * delta, direction.z * 3.15)
	body.move_and_slide()
	var speed := Vector2(body.get_real_velocity().x,body.get_real_velocity().z).length()
	bot.stuck = bot.stuck + delta if speed < 0.5 else 0.0
	var clip := "walk" if speed > 0.35 else "idle"
	var animation: AnimationPlayer = bot.animation
	if animation.current_animation != clip:
		animation.play(clip,0.15)
	animation.advance(delta)
	bot.prop.update_hand(0.0,true)
	var badge: Label3D = bot.badge
	if tagged_until.has(body):
		badge.text = "%s (tagged!)" % roster[body]
		badge.modulate = Color.WHITE if int(Time.get_ticks_msec() / 120) % 2 == 0 else bot.color
	else:
		badge.text = roster[body]
		badge.modulate = bot.color
	if is_instance_valid(target) and (aligned or bot.aim_left <= 0.0):
		bot.target = null
		if aligned:
			_bot_paint(bot,target)

func _visible_target(body: CharacterBody3D) -> CharacterBody3D:
	var nearest: CharacterBody3D
	var range_sq := 15.0 * 15.0
	for actor: CharacterBody3D in roster:
		if actor == body or tagged_until.has(actor):
			continue
		var score := body.position.distance_squared_to(actor.position)
		if score >= range_sq:
			continue
		var hit := _ray(body,body.position + Vector3.UP*1.02,actor.position + Vector3.UP*0.95)
		if hit.get("collider") == actor:
			nearest = actor
			range_sq = score
	return nearest

func _bot_paint(bot: Dictionary, target: CharacterBody3D) -> void:
	var body: CharacterBody3D = bot.body
	var origin: Vector3 = bot.prop.marker.to_global(Vector3(0,0.65,1.26))
	var end := target.position + Vector3(rng.randf_range(-0.58,0.58),rng.randf_range(0.61,1.43),rng.randf_range(-0.58,0.58))
	var ray := _ray(body,body.position + Vector3.UP*1.02,origin)
	if not ray.is_empty():
		return
	ray = _ray(body,origin,end + (end-origin).normalized()*1.8)
	var victim: Variant = ray.get("collider")
	var impact: Vector3 = ray.get("position",end)
	if roster.has(victim):
		fx._animate_paint(origin,impact,{},bot.color,_on_bot_tag.bind(body,victim,impact,bot.color))
	else:
		fx._animate_paint(origin,impact,ray,bot.color)

func _on_bot_tag(shooter: Node3D, victim: Variant, at: Vector3, tint: Color) -> void:
	fx.burst_at(at, tint)
	_record_tag(shooter, victim, true)

func _ray(body: CharacterBody3D, origin: Vector3, end: Vector3) -> Dictionary:
	var excluded: Array[RID] = [body.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,5,excluded))

func _on_player_tag(victim: Node3D) -> void:
	_record_tag(player,victim,true)

func is_tagged(actor: Variant) -> bool:
	return tagged_until.has(actor)

func _flee_waypoint(bot: Dictionary, away_from: Vector3) -> void:
	var body: CharacterBody3D = bot.body
	var best_idx: int = bot.route
	var best_dist := -1.0
	for i in yard.bot_waypoints.size():
		var waypoint: Vector3 = yard.bot_waypoints[i]
		var dist := waypoint.distance_squared_to(away_from)
		if dist > best_dist and waypoint.distance_squared_to(body.position) > 9.0:
			best_dist = dist
			best_idx = i
	bot.route = best_idx
	bot.stuck = 0.0
	bot.target = null

func _record_tag(shooter: Variant, victim: Variant, respect_cooldown := false) -> bool:
	if not roster.has(shooter) or not roster.has(victim):
		return false
	if respect_cooldown and tagged_until.has(victim):
		if shooter == player:
			notice = "%s is recovering!" % roster[victim]
			notice_time = 0.85
		return false
	var from_name: String = roster[shooter]
	var to_name: String = roster[victim]
	if not rules.tag(from_name,to_name):
		return false
	if respect_cooldown:
		tagged_until[victim] = TAG_COOLDOWN
		for bot in bots:
			if bot.body == victim and shooter is Node3D:
				bot.flee_delay = 0.55
				bot.flee_from = (shooter as Node3D).position
				break
	if shooter == player:
		notice = "Tagged %s!  +1" % to_name
		notice_time = 1.4
		SFX.play(self, "tag", -5.0, 1.0)
		player_scored_tag.emit()
	elif victim == player:
		notice = "%s tagged you!" % from_name
		notice_time = 1.4
		SFX.play(self, "tagged", -5.0, 1.0)
		player_was_tagged.emit(actor_colors.get(shooter, COLORS[1]), TAG_COOLDOWN)
	if rules.phase != RULES.Phase.PLAYING:
		SFX.play(self, "finish", -6.0, 1.0)
		_show_results()
	return true

func _update_hud(delta: float) -> void:
	notice_time = maxf(0.0, notice_time-delta)
	var sec := ceili(rules.remaining)
	var board := PackedStringArray()
	for row in rules.rankings(false):
		board.append("%d. %s %d" % row)
	var current := "Round %d / %d   •   %d:%02d   •   You: %d\n%s" % [
		rules.round_number, RULES.ROUND_COUNT, floori(sec/60.0), sec%60, rules.points["You"], "  ·  ".join(board)
	]
	if notice_time > 0.0:
		current += "\n"+notice
	if clock_label != current:
		clock_label = current
		hud.text = current
	if popup != null and start_countdown <= 0.0:
		if notice_time > 0.0 and not notice.is_empty():
			popup.text = notice
			popup.add_theme_color_override("font_color", Color("#4ce9fc") if notice.begins_with("Tagged") or notice == "PAINT!" else Color("#ffbc52"))
			popup.show()
		else:
			popup.hide()

func _award_match_stars(final_rankings: Array) -> int:
	if awarded_stars > 0 or not _allows_local_stars():
		return awarded_stars
	var rank := 4
	for row in final_rankings:
		if row[1] == "You":
			rank = int(row[0])
			break
	var reward := 10 if rank == 1 else (7 if rank == 2 else 5)
	if profile.change_stars(reward):
		awarded_stars = reward
	return awarded_stars

func _show_results() -> void:
	_set_player_enabled(false)
	tagged_until.clear()
	start_countdown = 0.0
	if popup != null:
		popup.hide()
	fx.clear_round_paint()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var final := rules.phase == RULES.Phase.FINISHED
	heading.text = "Final rankings" if final else "Round %d rankings" % rules.round_number
	var ranked := rules.rankings(final)
	var lines := PackedStringArray()
	for row in ranked:
		lines.append("%d.  %s   ·   %d" % row)
	var footer := ""
	if final:
		var earned := _award_match_stars(ranked)
		if earned > 0:
			footer = "\n\nMatch reward: +%d Stars!" % earned
	summary.text = ("Total points across all 3 rounds\n\n" if final else "Points this round (first to %d or 1:15)\n\n" % SOLO_TARGET_POINTS) + "\n".join(lines) + footer
	action.text = "Back to Town" if final else "Start Round %d" % (rules.round_number+1)
	overlay.show()
	action.grab_focus()
