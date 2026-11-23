extends SceneTree
const PLAYGROUND = preload("res://paintball_prototype/activities/playground.gd")
const TOWN = preload("res://paintball_prototype/town_layout.gd")
const CHARACTER = preload("res://paintball_prototype/character-male-a.glb")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var town := TOWN.new()
	scene.add_child(town)
	var ride := PLAYGROUND.new()
	ride.bind_layout(town)
	_check(is_instance_valid(ride.swing_pin) and is_instance_valid(ride.seesaw_pin) and is_instance_valid(ride.slide_asset),"Binds all three real Tiny Treats model meshes")
	var player := Node3D.new()
	scene.add_child(player)
	var avatar := CHARACTER.instantiate() as Node3D
	player.add_child(avatar)
	avatar.rotation.y = PI
	avatar.scale = Vector3.ONE * 2.5
	var animation := avatar.find_children("*","AnimationPlayer",true,false).front() as AnimationPlayer
	_check(animation.has_animation("sit") and animation.has_animation("walk"),"Uses real Kenney sit and walk clips")
	var initial := avatar.transform
	_check(ride.nearby(TOWN.PLAYGROUND_ENTRIES["swing-0"]) == "swing-0","Swing E prompt follows original entry")
	_check(ride.nearby(TOWN.PLAYGROUND_ENTRIES["swing-0"]+Vector3.UP*2).is_empty(),"Cannot start a ride while standing overhead")
	_check(ride.nearby(PLAYGROUND.SWING_BACK_ENTRY)=="swing-0","Second swing approach uses the same occupancy id")
	ride.begin("swing-0",PLAYGROUND.SWING_BACK_ENTRY)
	_check(ride.exit_position().distance_to(PLAYGROUND.SWING_BACK_ENTRY)<.1,"Rear-side boarding dismounts on the same safe side")
	var starting := ride.pose()
	_check(starting.distance_to(Vector3(51,.7209782,47)) < 0.01,"Initial swing rider matches original seat")
	player.rotation.y = 1.23
	ride.tick(.8)
	ride.apply_avatar(avatar)
	var swinging := ride.pose()
	_check(starting.distance_to(swinging) > .5 and absf(ride.swing_pin.rotation.x-ride.swing_rest_pitch) > .10,"Swing visibly moves the model with the rider")
	_check(swinging.is_equal_approx(ride.swing_pin.to_global(PLAYGROUND.SWING_SEAT)),"Rider stays glued to animated swing surface")
	_check(absf(avatar.rotation.x-ride.motion_angle()) < .001 and avatar.global_basis.z.z > 0.0,"Swing avatar faces forward and pitches with seat")
	_check(ride.animation_name() == "sit","Swing uses sitting animation")
	ride.end(avatar)
	_check(ride.ride.is_empty() and is_equal_approx(ride.swing_pin.rotation.x,ride.swing_rest_pitch) and avatar.transform.is_equal_approx(initial),"Dismount resets art and walking pose")

	ride.begin("seesaw-0")
	ride.tick(.65)
	var side0 := ride.pose()
	ride.apply_avatar(avatar)
	_check(ride.seesaw_pin.rotation.x>ride.seesaw_rest_pitch and avatar.global_basis.z.z>0,"First seesaw rider faces inward with the beam")
	ride.end(avatar)
	ride.begin("seesaw-1")
	ride.tick(.65)
	var side1 := ride.pose()
	ride.apply_avatar(avatar)
	_check(side0.z < 55.0 and side1.z > 55.0 and side0.y > side1.y and avatar.global_basis.z.z < 0,"Seesaw seats face inward and rise on opposite sides")
	_check(ride.exit_position().distance_to(TOWN.PLAYGROUND_ENTRIES["seesaw-1"]) < .1,"Seesaw exits back beside its seat")
	ride.end(avatar)
	_check(is_equal_approx(ride.seesaw_pin.rotation.x,ride.seesaw_rest_pitch),"Seesaw art returns to rest")

	ride.begin("slide")
	var slide_start := ride.pose()
	_check(ride.animation_name()=="walk" and slide_start.distance_to(Vector3(43.15279,.12,46.3056))<0.01,"Slide starts on imported ladder path")
	ride.tick(2.03)
	var slide_high := ride.pose()
	ride.apply_avatar(avatar)
	_check(ride.animation_name()=="sit" and slide_high.y>1.9 and avatar.global_basis.z.z>0,"Slide switches to seated glide facing down chute")
	ride.tick(PLAYGROUND.SLIDE_SECONDS*.61-2.03)
	var slope := ride.slide_asset.to_local(ride.pose())
	_check(absf(slope.y-1.33)<.015 and absf(slope.z-2.45)<.015,"Seated glide follows measured center of the chute, not the bounding box")
	ride.tick(4.0)
	_check(ride.is_finished() and ride.pose().z>50.8 and ride.exit_position().z>52.0,"Slide tracks chute and exits past its collision")
	ride.end(avatar)
	_check(avatar.transform.is_equal_approx(initial),"Slide releases avatar pose")
	scene.queue_free()
	await process_frame
	await _test_scene_route()
	print("Town playground checks: ",failures," failures")
	quit(failures)

func _test_scene_route() -> void:
	var save := "user://playground-integration-%d.cfg" % Time.get_ticks_usec()
	set_meta("willowbrook_save_override",save)
	change_scene_to_file("res://paintball_prototype/town.tscn")
	await scene_changed
	var town := current_scene
	var player: CharacterBody3D = town.player
	player.position = TOWN.PLAYGROUND_ENTRIES["swing-0"]+Vector3.UP*.04
	await physics_frame
	_check(town._interaction_text().contains("swing"),"Real town exposes Swing through the interaction prompt")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	player.held["up"] = true
	player.jump_buffer = .12
	root.push_input(e)
	_check(town.playground.ride=="swing-0" and not player.is_physics_processing() and player.held.is_empty() and player.jump_buffer==0.0,"Boarding with E freezes walking and flushes queued jump")
	town._request_world_jump()
	_check(player.jump_buffer==0.0,"Jump requests are blocked while riding")
	for i in range(34):
		await physics_frame
	_check(town.arena_animation.current_animation=="sit" and player.position.is_equal_approx(town.playground.pose()),"Map drives the seated avatar with the moving swing")
	root.push_input(e)
	_check(town.playground.ride.is_empty() and player.is_physics_processing() and player.jump_buffer==0.0,"E leaves swing and restores physics")
	for i in range(6):
		await physics_frame
	var at := player.position
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space)
	for i in range(6):
		await physics_frame
	_check(player.position.y>at.y+.2,"Space jump works again on foot after the ride")

	player.position = TOWN.PLAYGROUND_ENTRIES["slide"]+Vector3.UP*.05
	root.push_input(e)
	for i in range(6):
		await physics_frame
	_check(town.playground.ride=="slide" and town.arena_animation.current_animation=="walk","Slide walks through first ladder segment")
	root.push_input(e)
	_check(town.playground.ride=="slide","E cannot abandon slide over the ladder")
	town.playground.tick(2.1)
	for i in range(8):
		await physics_frame
	_check(town.arena_animation.current_animation=="sit" and player.position.is_equal_approx(town.playground.pose()),"Real town switches from walk to seated chute motion")
	town.playground.tick(5.0)
	for i in range(6):
		await physics_frame
	_check(town.playground.ride.is_empty() and player.is_physics_processing() and player.position.distance_to(Vector3(43,.05,52.1))<.20,"Slide exits safely and restores on-foot controls")
	if FileAccess.file_exists(save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save))


func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
		push_error(detail)
