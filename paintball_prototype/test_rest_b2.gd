extends SceneTree
const Profile = preload("res://paintball_prototype/progression/profile.gd")
const Schema = preload("res://paintball_prototype/network/browser/message_schema.gd")
const Session = preload("res://paintball_prototype/network/browser/browser_session.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var profile := Profile.new("")
	var p := profile.snapshot()
	p.home = {"plot":0,"variant":"starter"}
	p.furniture = [{"kind":"bed","id":"test-bed","room":0,"x":2.0,"z":-2.0,"rotation":0}]
	assert(profile.commit(p))
	set_meta("willowbrook_profile",profile)
	set_meta("room_plot",0)
	set_meta("room_destination","home")
	change_scene_to_file("res://paintball_prototype/room.tscn")
	await scene_changed
	var home := current_scene
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
	change_scene_to_file("res://paintball_prototype/room.tscn")
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
	print("PASS exact Home bed lies down, E and touch movement restore standing at safe origin, private pose omitted, Bank chair toggles via R, remote settled sit and stand render.")
	quit()
