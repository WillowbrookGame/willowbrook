extends SceneTree
func _initialize() -> void:
	set_meta("willowbrook_save_override", "")
	call_deferred("_run")

func require(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func _run() -> void:
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	current_scene.player.position = current_scene.door_position + Vector3(0,0,1.6)
	current_scene._try_door()
	await scene_changed
	var map := current_scene
	var game: Node3D = map.arena_match
	if not require(game != null and game.overlay.visible and not game.is_playing(),"Single-player start screen was not reached from town"):
		return
	var stars_before: int = map.profile.get_stars() if map.profile != null else 0
	game.action.pressed.emit()
	if not require(game.is_counting_down() and not game.is_playing() and not game.overlay.visible,"Round 1 did not enter 3-2-1 start countdown"):
		return
	game.tick(game.COUNTDOWN_STEP * 3.0 + 0.05)
	if not require(game.is_playing() and game.bots.size()==3 and is_equal_approx(game.rules.remaining,game.SOLO_ROUND_LENGTH) and not game.overlay.visible,"Round 1 did not start with three bots and 1:15 after countdown"):
		return
	var bot_avatars := {}
	for opponent in game.bots:
		bot_avatars[opponent.avatar_id] = true
	if not require(bot_avatars.size() == 3,"Solo Paintball bots did not receive three distinct avatars: %s" % [bot_avatars.keys()]):
		return
	game.notice = ""
	game.notice_time = 0.0
	var bot: CharacterBody3D = game.bots[0].body
	var initial := bot.position
	for i in range(12):
		await physics_frame
	if not require(bot.position.distance_to(initial)>0.4,"Bot cannot move from spawn"):
		return
	# Controlled lane for a real player hit and bot hit, separate from the
	# normal arena's patrol and obstruction checks.
	(map.yard.get_node("YardCollision") as StaticBody3D).collision_layer = 0
	map.ZONE_GEOMETRY.box(map, "MatchTestFloor", Vector3(0,-0.15,5), Vector3(46,0.3,38), Color.WHITE, true)
	map.player.position = Vector3(0,0.03,10)
	map.look_pitch = -0.12
	bot.position = Vector3(0.70,0.03,4)
	game.bots[1].body.position = Vector3(-12,0.03,1)
	game.bots[2].body.position = Vector3(12,0.03,1)
	for i in range(4):
		await physics_frame
	for opponent in game.bots:
		opponent.reload = 30.0
	map._world_primary_action()
	for i in range(2):
		await physics_frame
	if not require(game.rules.points["You"]==0 and game.notice.is_empty(),"Human tag was announced before the projectile arrived"):
		return
	for i in range(34):
		await physics_frame
	if not require(game.rules.points["You"]==1 and game.notice.begins_with("Tagged Pip"),"An arriving paintball did not count for the human"):
		return
	game.rng.seed = 129
	for i in range(30):
		game._bot_paint(game.bots[0],map.player)
		if not game.fx.flights.is_empty():
			break
	if not require(game.rules.points["Pip"]==0 and not game.notice.contains("tagged you"),"Bot tag was announced before the projectile arrived"):
		return
	for i in range(34):
		await physics_frame
	if not require(game.rules.points["Pip"]==1 and game.notice=="Pip tagged you!","An arriving bot paintball did not count"):
		return
	if not require(map.visor_splat != null and map.visor_splat.visible and map.visor_splat.remaining > 0.0,"Visor paint splat did not appear when player was tagged"):
		return
	map.visor_splat.tick(game.TAG_COOLDOWN + 0.1)
	if not require(not map.visor_splat.visible,"Visor paint splat did not clear after immunity ended"):
		return
	if not require(game.rules.points["You"]==1 and game._record_tag(bot,game.bots[1].body) and game.rules.points["Pip"]==2 and not game._record_tag(bot,bot),"Human, bot and bot-vs-bot scoring must use the same rule"):
		return
	game.tick(game.SOLO_ROUND_LENGTH)
	if not require(game.overlay.visible and not map.player.is_physics_processing() and game.action.text=="Start Round 2" and game.rules.rankings(false)[0][1]=="Pip" and not game._record_tag(bot,map.player),"Round 1 standings/lock failed"):
		return
	game.action.pressed.emit()
	game.tick(game.COUNTDOWN_STEP * 3.0 + 0.05)
	if not require(game.rules.round_number==2 and game.rules.points["Pip"]==0 and game.rules.totals["Pip"]==2,"Round 2 did not reset per-round scores while keeping totals"):
		return
	# Verify tag protection through the real hit handler: first hit scores,
	# an immediate repeat is blocked, and a hit after TAG_COOLDOWN scores again.
	game._on_player_tag(bot)
	if not require(game.rules.points["You"]==1 and game.is_tagged(bot),"First real hit did not score and activate tag protection"):
		return
	game._on_player_tag(bot)
	if not require(game.rules.points["You"]==1 and game.is_tagged(bot),"Immediate repeat hit bypassed tag protection"):
		return
	game.tick(game.TAG_COOLDOWN + 0.1)
	if not require(not game.is_tagged(bot),"Tag protection did not expire after cooldown"):
		return
	game._on_player_tag(bot)
	if not require(game.rules.points["You"]==2 and game.is_tagged(bot),"Hit after tag protection expired did not score"):
		return
	# Verify TouchFire stays onscreen in a compact 480x280 viewport at 2x scale.
	map.camera_thumbstick.show()
	root.size = Vector2i(960, 560)
	map._fit_zone_hud(480.0, 2.0)
	var fire_rect: Rect2 = map.touch_fire_button.get_global_rect()
	if not require(fire_rect.position.x >= 0.0 and fire_rect.position.y >= 0.0 and fire_rect.end.x <= 960.0 and fire_rect.end.y <= 560.0,"TouchFire clipped outside compact 480x280@2x viewport: %s" % [fire_rect]):
		return
	game.tick(game.SOLO_ROUND_LENGTH)
	game.action.pressed.emit()
	game.tick(game.COUNTDOWN_STEP * 3.0 + 0.05)
	if not require(game.rules.round_number==3 and is_equal_approx(game.rules.remaining,game.SOLO_ROUND_LENGTH),"Round 3 did not start"):
		return
	# Reaching SOLO_TARGET_POINTS ends the final round early and awards Stars.
	for i in range(game.SOLO_TARGET_POINTS):
		game._record_tag(map.player, bot)
	if not require(game.action.text=="Back to Town" and game.rules.rankings(true)[0]==[1,"You",3 + game.SOLO_TARGET_POINTS] and not game.is_playing() and game.awarded_stars == 10,"Early round finish, final ranking, or Stars reward was incorrect"):
		return
	if map.profile != null and not require(map.profile.get_stars() == stars_before + 10,"Stars reward was not saved to profile"):
		return
	game.action.pressed.emit()
	await scene_changed
	if not require(current_scene.name=="WillowbrookTown" and current_scene.player.position.distance_to(current_scene.door_position)<2.0,"Did not land outside the arena door"):
		return
	print("PASS: single-player countdown, 75s/12-tag pacing, tag protection, compact TouchFire, Stars reward, and return spawn")
	quit()
