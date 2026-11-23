extends SceneTree
func _initialize() -> void:
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
	game.action.pressed.emit()
	if not require(game.is_playing() and game.bots.size()==3 and is_equal_approx(game.rules.remaining,180.0) and not game.overlay.visible,"Round 1 did not start with three bots and 3:00"):
		return
	var bot: CharacterBody3D = game.bots[0].body
	var initial := bot.position
	for i in range(12):
		await physics_frame
	if not require(bot.position.distance_to(initial)>0.4,"Bot cannot move from spawn"):
		return
	# Controlled lane for a real player hit and bot hit, separate from the
	# normal arena's patrol and obstruction checks.
	(map.yard.get_node("YardCollision") as StaticBody3D).collision_layer = 0
	map._box("MatchTestFloor", Vector3(0,-0.15,5), Vector3(46,0.3,38), Color.WHITE, true)
	map.player.position = Vector3(0,0.03,10)
	map.look_pitch = -0.12
	bot.position = Vector3(0.70,0.03,4)
	game.bots[1].body.position = Vector3(-12,0.03,1)
	game.bots[2].body.position = Vector3(12,0.03,1)
	for i in range(4):
		await physics_frame
	for opponent in game.bots:
		opponent.reload = 30.0
	map.marker_preview.trigger()
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
	if not require(game.rules.points["You"]==1 and game._record_tag(bot,game.bots[1].body) and game.rules.points["Pip"]==2 and not game._record_tag(bot,bot),"Human, bot and bot-vs-bot scoring must use the same rule"):
		return
	game.tick(180.0)
	if not require(game.overlay.visible and not map.player.is_physics_processing() and game.action.text=="Start Round 2" and game.rules.rankings(false)[0][1]=="Pip" and not game._record_tag(bot,map.player),"Round 1 standings/lock failed"):
		return
	game.action.pressed.emit()
	if not require(game.rules.round_number==2 and game.rules.points["Pip"]==0 and game.rules.totals["Pip"]==2,"Round 2 did not reset per-round scores while keeping totals"):
		return
	game._record_tag(map.player,bot)
	game._record_tag(map.player,bot)
	game.tick(180.0)
	game.action.pressed.emit()
	if not require(game.rules.round_number==3 and is_equal_approx(game.rules.remaining,180.0),"Round 3 did not start"):
		return
	game.tick(180.0)
	if not require(game.action.text=="Back to Town" and game.rules.rankings(true)[0]==[1,"You",3] and not game.is_playing(),"Final ranking or return button was incorrect"):
		return
	game.action.pressed.emit()
	await scene_changed
	if not require(current_scene.name=="WillowbrookTown" and current_scene.player.position.distance_to(current_scene.door_position)<2.0,"Did not land outside the arena door"):
		return
	print("PASS: single-player entry, three bots, equal scoring, three 180s rounds, rankings, and return spawn")
	quit()
