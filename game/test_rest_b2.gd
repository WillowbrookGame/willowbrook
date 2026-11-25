extends SceneTree
const Profile = preload("res://game/progression/profile.gd")
const Schema = preload("res://game/network/browser/message_schema.gd")
const Session = preload("res://game/network/browser/browser_session.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var profile := Profile.new("")
	var p := profile.snapshot()
	p.home = {"plot":0,"variant":"starter"}
	p.furniture = [
		{"kind":"bed","id":"test-bed","room":0,"x":2.0,"z":-2.0,"rotation":0},
		{"kind":"chair","id":"test-chair","room":0,"x":-2.5,"z":-2.0,"rotation":0},
		{"kind":"sofa","id":"test-sofa","room":0,"x":4.5,"z":1.0,"rotation":0},
	]
	assert(profile.commit(p))
	set_meta("willowbrook_profile",profile)
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var town := current_scene
	town.player.position = Vector3(-51,.04,-17)
	town._interact()
	assert(town.changing)
	await scene_changed
	var home := current_scene
	assert(home.room_id=="home" and home.room_plot==0)
	for fixture: Array in [[Vector3(-2.5,.05,-.8),Vector3(-2.5,.6,-2)],[Vector3(4.5,.05,2.45),Vector3(4.5,.66,1)]]:
		home.player.position = fixture[0]
		for i in 16: await physics_frame
		var grounded_origin: Vector3 = home.player.position
		assert(home.player.is_on_floor() and home.room.interaction_prompt()=="Sit down")
		home._interact()
		assert(home.room_seated and home.room.rest_pose=="sit")
		assert(not home.player.is_physics_processing() and home.player.position.is_equal_approx(fixture[1]))
		assert(home.room.network_rest_pose()=="")
		home._interact()
		assert(not home.room_seated and home.player.is_physics_processing())
		assert(home.player.position.distance_to(grounded_origin)<.001)
	home.player.position = Vector3(0.42,.05,-2)
	for i in 16: await physics_frame
	var original: Vector3 = home.player.position
	assert(home.room.interaction_prompt() == "Lie down")
	home._interact()
	for i in 3: await physics_frame
	assert(home.room_seated and home.room.rest_pose=="lie")
	assert(not home.player.is_physics_processing() and absf(home.arena_avatar.global_basis.y.normalized().dot(Vector3.UP))<.01)
	assert(home.room.network_rest_pose()=="")
	home._interact()
	assert(not home.room_seated and home.player.position.distance_to(original)<.001)
	assert(home.player.is_physics_processing())
	home._interact()
	home.player.touch_motion = Vector2(1,0)
	await physics_frame
	await physics_frame
	home.player.touch_motion=Vector2.ZERO
	assert(not home.room_seated)
	set_meta("room_destination","bank")
	change_scene_to_file("res://game/room.tscn")
	await scene_changed
	var bank := current_scene
	bank.player.position = Vector3(-4.93,.05,1)
	for i in 16: await physics_frame
	assert(bank.room.interaction_prompt()=="Sit down")
	var r := InputEventKey.new()
	r.physical_keycode = KEY_R
	r.pressed = true
	bank._unhandled_key_input(r)
	assert(bank.room_seated and bank.room.network_rest_pose()=="sit")
	bank._unhandled_key_input(r)
	assert(not bank.room_seated and bank.room.network_rest_pose()=="")
	var sess := Session.new()
	root.add_child(sess)
	var hud := CanvasLayer.new()
	bank.add_child(hud)
	sess.bind_zone("bank",bank,bank.player,hud)
	sess._receive_local([{"id":2,"alias":"fixture","zone":"bank","position":Vector3(-6,.55,1),"yaw":PI/2.,"moving":false,"grounded":true,"rest":"sit"}],[])
	sess._draw_ghosts(.1)
	assert(sess._ghosts[2].animation.current_animation == "sit")
	sess.rows[2].rest = ""
	sess._draw_ghosts(.1)
	assert(sess._ghosts[2].animation.current_animation != "sit")
	print("PASS owned Home chair and sofa sit, bed lies down, E and touch movement restore standing at safe origin, private pose omitted, Bank chair toggles via R, remote settled sit and stand render.")
	quit()
