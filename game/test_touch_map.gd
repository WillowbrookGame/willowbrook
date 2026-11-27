
extends SceneTree

func _initialize() -> void:
	call_deferred("_run")
func tap(game: Node, index: int, point: Vector2, pressed := true) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index=index
	ev.position=point
	ev.pressed=pressed
	root.push_input(ev,true)
func drag(index: int, delta: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index=index
	ev.position=Vector2(650,250)
	ev.relative=delta
	ev.screen_relative=delta
	root.push_input(ev,true)
func at(button: Button) -> Vector2:
	return button.get_global_rect().get_center()
func control_in(hud: Node, starts: String) -> Button:
	for child: Node in hud.get_children():
		if child is Button and child.text.begins_with(starts):
			return child
	return null
func spawn(scene: String) -> Node:
	var game: Node = load("res://game/"+scene+".tscn").instantiate()
	root.add_child(game)
	return game
func _run() -> void:
	root.size = Vector2i(1024,608)
	OS.get_user_data_dir()
	var beach := spawn("beach")
	await process_frame
	await physics_frame
	var look_before: float = beach.look_yaw
	tap(beach,6,Vector2(630,205));drag(6,Vector2(25,0))
	assert(not is_equal_approx(beach.look_yaw,look_before))
	tap(beach,6,Vector2(630,205),false)
	tap(beach,6,at(beach.jump_button))
	assert(beach.player.jump_buffer>0)
	tap(beach,6,at(beach.jump_button),false)
	beach.player.jump_buffer=0
	beach.player.position=beach.beach_scenery.POLE+Vector3.UP*.06
	beach._refresh_prompt()
	assert(beach.enter_button.visible and "fishing pole" in beach.enter_button.text)
	var p:=at(beach.enter_button)
	tap(beach,7,p);drag(7,Vector2(110,20));tap(beach,7,p,false)
	assert(beach.fishing_ui.game.equipped)
	await physics_frame
	await physics_frame
	await process_frame
	assert(beach.fishing_ui.cast_button.visible)
	beach.player.position=Vector3(-7,0.05,1.75)
	beach.look_yaw=0
	beach._update_camera()
	p=at(beach.fishing_ui.cast_button)
	tap(beach,8,p);tap(beach,8,p,false)
	assert(not beach.fishing_ui.game.line.is_empty(),"cast through touch HUD")
	p=at(beach.fishing_ui.put_away_button)
	tap(beach,9,p);tap(beach,9,p,false)
	assert(not beach.fishing_ui.game.equipped and beach.fishing_ui.game.line.is_empty())
	# Real keyboard and mouse paths still work alongside touch.
	beach.player.position=beach.beach_scenery.POLE+Vector3.UP*.06
	beach._refresh_prompt()
	var desktop_e:=InputEventKey.new()
	desktop_e.physical_keycode=KEY_E
	desktop_e.pressed=true
	root.push_input(desktop_e,true)
	assert(beach.fishing_ui.game.equipped)
	beach.player.position=Vector3(-7,0.05,1.75)
	beach._update_camera()
	var desktop_cast:=InputEventMouseButton.new()
	desktop_cast.device=0
	desktop_cast.button_index=MOUSE_BUTTON_LEFT
	desktop_cast.position=Vector2(550,300)
	desktop_cast.pressed=true
	root.push_input(desktop_cast,true)
	assert(not beach.fishing_ui.game.line.is_empty(),"desktop mouse still casts")
	beach.fishing_ui.put_away()
	tap(beach,10,Vector2(630,205));drag(10,Vector2(18,0))
	var prior: float=beach.look_yaw
	beach.set_zone_modal(true)
	beach.set_zone_modal(false)
	drag(10,Vector2(18,0))
	assert(is_equal_approx(beach.look_yaw,prior),"modal cancels old finger")
	tap(beach,11,Vector2(630,205));drag(11,Vector2(18,0))
	prior=beach.look_yaw
	beach.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	drag(11,Vector2(18,0))
	assert(is_equal_approx(beach.look_yaw,prior),"focus loss cancels old finger")
	var multiplayer:=control_in(beach.get_node("WorldHUD"),"Multiplayer")
	assert(multiplayer!=null)
	p=at(multiplayer);tap(beach,12,p);tap(beach,12,p,false)
	assert(beach.zone_modal,"Multiplayer touch opens real menu")
	beach.queue_free()
	await process_frame
	set_meta("paintball_single_player",true)
	var arena:=spawn("arena")
	await process_frame
	arena.arena_match._on_action()
	arena.arena_match.tick(arena.arena_match.COUNTDOWN_STEP * 3.0 + 0.05)
	await process_frame
	assert(arena.arena_match.is_playing())
	tap(arena,2,Vector2(639,234));drag(2,Vector2(21,0))
	prior=arena.look_yaw
	arena.arena_match.tick(arena.arena_match.SOLO_ROUND_LENGTH + 1.0)
	assert(not arena.arena_match.is_playing())
	await process_frame
	arena.arena_match._on_action()
	arena.arena_match.tick(arena.arena_match.COUNTDOWN_STEP * 3.0 + 0.05)
	await process_frame
	assert(arena.arena_match.is_playing())
	drag(2,Vector2(30,0))
	assert(is_equal_approx(arena.look_yaw,prior),"round end cancels old finger")
	print("PASS real Godot scenes: Jump/E/Cast/Put Away/Multiplayer buttons, look, modal/focus recovery, and paintball round end.")
	quit()

