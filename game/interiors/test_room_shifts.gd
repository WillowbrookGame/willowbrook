extends SceneTree
const TOWN = preload("res://game/town_layout.gd")
const TASK_DATA := preload("res://game/progression/web_tasks.json")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(test: bool, message: String) -> bool:
	if not test:
		failures+=1
		push_error(message)
	return test

func _key_e() -> void:
	var event := InputEventKey.new()
	event.keycode=KEY_E
	event.physical_keycode=KEY_E
	event.pressed=true
	root.push_input(event,true)

func _find_button(container: Node, name_: String) -> Button:
	for candidate in container.find_children("*","Button",true,false):
		if candidate.text==name_: return candidate
	return null

func _clear_position(zone: String, where: Dictionary, map: Node3D) -> Vector3:
	var b: Dictionary = TASK_DATA.data.businessDefinitions[zone]
	var centered := Vector3(float(where.x)-float(b.x),.04,float(where.z)-float(b.z))
	var shape := CapsuleShape3D.new()
	shape.radius=.26
	shape.height=1.33
	var query := PhysicsShapeQueryParameters3D.new()
	query.collision_mask=1
	query.exclude=[map.player.get_rid()]
	query.shape=shape
	var state := map.player.get_world_3d().direct_space_state as PhysicsDirectSpaceState3D
	for r: float in [0.0,.45,.75,1.0,1.30,1.54]:
		for i in range(16 if r>0 else 1):
			var candidate := centered+Vector3(sin(i*TAU/16)*r,0,cos(i*TAU/16)*r)
			query.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*.76)
			if state.intersect_shape(query,1).is_empty(): return candidate
	check(false,"No capsule clearance for %s/%s" % [zone,str(where.get("id","employer"))])
	return centered

func _run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var initial: Dictionary=current_scene.profile_snapshot()
	for key: String in ["cafe","store","garden","park"]: initial.starter.completed[key]=Time.get_unix_time_from_system()
	check(current_scene.profile_commit(initial),"Couldn't initialize disposable profile")
	for zone: String in ["bank","vet","salon","store","cafe","library"]:
		var town := current_scene
		var front := -1.0 if zone in ["store","cafe"] else 1.0
		var entry: Vector3 = TOWN.BUSINESS_DOORS[zone]
		town.player.position=entry+Vector3(0,.05,front*1.3)
		_key_e()
		if not check(town.changing,"Press E didn't open "+zone):
			quit(failures); return
		await scene_changed
		var room_map := current_scene
		await physics_frame
		await physics_frame
		var employer: Dictionary=TASK_DATA.data.employerSites[zone]
		room_map.player.position=_clear_position(zone,employer,room_map)
		_key_e()
		if not check(room_map.room.is_modal_open(),"Employer talk not accessible for "+zone):
			quit(failures); return
		var hire := _find_button(room_map.room.fields,"Get hired: "+zone.capitalize())
		if not check(hire!=null,"Employer did not offer "+zone):
			quit(failures); return
		hire.pressed.emit()
		check(room_map.profile.memberships().has(zone),"Hire did not persist for "+zone)
		room_map.room.close_modal()
		var job: Dictionary=TASK_DATA.data.workTaskDefinitions[zone]
		room_map.player.position=_clear_position(zone,job.station,room_map)
		var stars: int=room_map.profile_snapshot().stars
		_key_e()
		check(room_map.profile_snapshot().work.get("name","")==zone,"Failed to start "+zone+" shift with E")
		for step: Dictionary in job.tasks:
			var position := _clear_position(zone,step,room_map)
			room_map.player.position=position
			_key_e()
			var active: Dictionary=room_map.profile_snapshot()
			if not check(active.work.has("started"),"Could not do "+zone+"/"+step.id): break
			room_map.room._process(.2)
			check(room_map.room.job_art.panel.visible and room_map.room.job_art.progress.visible,"Checklist not shown for "+zone)
			var started: float=active.work.started
			var completed: Dictionary=room_map.profile.advance(zone,position,started+float(step.durationMs)*.001+.015)
			check(completed.get("ok",false),"Progression could not advance "+zone+"/"+step.id)
		check(room_map.profile_snapshot().stars==stars+3 and room_map.profile_snapshot().work.is_empty(),"Shift didn't persist stars: "+zone)
		room_map.player.position=Vector3(0,.05,6.55)
		_key_e()
		if not check(room_map.changing,"Press E didn't exit "+zone):
			quit(failures); return
		await scene_changed
		check(current_scene.profile.memberships().has(zone) and current_scene.profile_snapshot().stars==stars+3,"Lost profile on door from "+zone)
	print("ROOM SHIFTS: enter, employer NPC, station and active checklist, timed steps, awarded stars, exit across six businesses.")
	quit(failures)
