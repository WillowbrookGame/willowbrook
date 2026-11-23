extends SceneTree

const TOWN = preload("res://game/town_layout.gd")

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func _jump(map: Node3D, touch := false) -> bool:
	for i in range(12):
		await physics_frame
	var baseline: float = map.player.position.y
	if touch:
		var press := InputEventScreenTouch.new()
		press.pressed = true
		press.index = 13
		press.position = map.jump_button.get_global_rect().get_center()
		root.push_input(press,true)
	else:
		var space := InputEventKey.new()
		space.pressed = true
		space.keycode = KEY_SPACE
		space.physical_keycode = KEY_SPACE
		root.push_input(space,true)
	for i in range(12):
		await physics_frame
	var jumped: bool = map.player.position.y > baseline + .45
	for i in range(58):
		await physics_frame
	return jumped and map.player.is_on_floor()

func _run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var town := current_scene
	if not check(await _jump(town),"Town Space jump did not return to floor."):
		return
	town.player.position = Vector3(51,.05,49.8)
	town._interact()
	if not check(town.playground.ride == "swing-0" and not town.player.is_physics_processing(),"Couldn't get onto swing"):
		return
	for i in range(20):
		await physics_frame
	town._interact()
	if not check(town.playground.ride.is_empty() and town.player.is_physics_processing(),"Couldn't get off the swing"):
		return
	for id: String in ["bank","vet","salon","store","cafe","library","arcade"]:
		town = current_scene
		var entrance: Vector3 = TOWN.BUSINESS_DOORS[id]
		var side := -1.0 if id in ["store","cafe"] else 1.0
		town.player.position = entrance + Vector3(0,.05,side * 1.3)
		if not check(town._interaction_text().begins_with("Enter") and town._town_room_at().get("id")==id,"Missing door prompt: "+id):
			return
		town._interact()
		if not check(town.changing,"Door not connected: "+id):
			return
		await scene_changed
		var indoor := current_scene
		if not check(indoor.current_zone_id()==id and indoor.room != null,"Missing room: "+id):
			return
		if id == "library" or id == "arcade":
			if not check(await _jump(indoor,id=="arcade"),"Jump did not work in "+id):
				return
		indoor.go_to_town()
		await scene_changed
		if not check(current_scene.player.position.distance_to(entrance+Vector3(0,.04,side*2.0))<.25,"Bad return from "+id):
			return
	town = current_scene
	town.player.position = TOWN.BEACH_DOOR+Vector3(0,.04,-1.4)
	town._interact()
	await scene_changed
	if not check(await _jump(current_scene,true),"Beach jump through touch button failed."):
		return
	print("PASS: 7 indoor doors and returns, town swing, all-zone keyboard and touch jumping")
	quit()
