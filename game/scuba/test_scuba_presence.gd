extends SceneTree
## Run alone for HUD/schema checks, or as two processes with -- host|guest <invite-file> <port>.
const SCHEMA = preload("res://game/network/browser/message_schema.gd")
const SWIM = preload("res://game/scuba/animation/swim_animation.gd")
const ACCOUNT = preload("res://game/network/browser/account_session.gd")
const PHOTOS = preload("res://game/scuba/reef_photos.gd")
const REEF = "res://game/scuba/reef.tscn"
var failures := 0
var reef: Node3D
var session: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	set_meta("willowbrook_save_override","")
	var args := OS.get_cmdline_user_args()
	await _enter()
	session = root.get_node("WillowbrookSession")
	_check(session.zone=="reef" and session._bound==reef,"Native Reef binds the actual scene and body")
	if args.size() >= 3:
		await _lan(args)
	else:
		await _layout_and_schema()
	if failures==0: print("PASS Reef "+("native LAN "+args[0] if args.size()>=3 else "schema and real HUD layout"))
	quit(failures)


func _enter() -> void:
	if change_scene_to_file(REEF)!=OK:
		_check(false,"Reef scene did not load")
		quit(1)
		return
	await scene_changed
	await process_frame
	reef=current_scene


func _layout_and_schema() -> void:
	var pose := {"id":2,"alias":"Diver","zone":"reef","x":0,"y":-17.4,"z":12,"yaw":1,"moving":true,"grounded":false}
	var packet := {"type":"world","zone":"reef","players":[pose],"presence":[{"alias":"Diver","place":"At the reef"}]}
	_check(not SCHEMA.parse(JSON.stringify(packet).to_utf8_buffer()).is_empty(),"Full Reef world packet accepts a deep pose")
	packet.zone="town"
	pose.zone="town"
	pose.y=-15.0
	_check(SCHEMA.parse(JSON.stringify(packet).to_utf8_buffer()).is_empty(),"Town still rejects a deep pose")
	await _check_hud(null)
	# Replace only the test HUD session widgets; never start a second real game connection.
	for n: Node in reef.hud.get_children():
		if (n is Button and n.text=="Multiplayer (M)") or n==session._panel:
			n.queue_free()
	var account := ACCOUNT.new()
	root.add_child(account)
	account.bind_zone("reef",reef,reef.diver,reef.hud)
	_check(account._hunt_view==null,"Reef does not mount Town scavenger HUD")
	await _check_hud(account._star_badge)
	account.suspend_zone_for(reef)
	account.queue_free()


func _check_hud(stars: Control) -> void:
	for size in [Vector2i(360,640),Vector2i(640,360),Vector2i(1024,768)]:
		root.size=size
		await process_frame
		reef._layout(true)
		await process_frame
		var box := root.get_visible_rect()
		var controls: Array[Control]=[reef.photo_button,reef.book_button,reef.depth,reef.activity_counts,reef.hud.get_node("SwimHint"),reef.back,reef.rise,reef.sink,reef.move_stick,reef.look_stick]
		if stars!=null: controls.append(stars)
		for node in reef.hud.get_children():
			if node is Button and node.text in ["Multiplayer (M)","Account"]: controls.append(node)
		for action: Control in [reef.photo_button,reef.book_button]:
			var rect:=action.get_global_rect()
			_check(box.encloses(rect),"Photo/Book stay on-screen at %s: %s" % [size,rect])
			for other: Control in controls:
				if other!=action and other.visible:
					_check(not rect.intersects(other.get_global_rect()),"%s overlaps %s at %s" % [action.name,other.name,size])


func _lan(args: PackedStringArray) -> void:
	var port := int(args[2])
	var path := args[1]
	if args[0]=="host":
		_check(session.host_session("Reef host","127.0.0.1",port),"Host LAN on loopback")
		reef.diver.position=Vector3(-23,-16,-21)
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(session.invite_code())
		file.close()
		_check(await _until(func(): return _remote_at(-16.45)),"Host sees guest at the reef floor")
		_check(await _until(func(): return _remote_gear()),"Host sees animated diver wearing tank and both fins")
		reef.treasures.check_diver(reef.treasures.items[0].base)
		var hoop: Node3D=reef.rings.rings[0].node
		reef.rings.check_diver(hoop.to_global(Vector3(0,0,-.6)))
		reef.rings.check_diver(hoop.to_global(Vector3(0,0,.6)))
		PHOTOS.record_photo("shark",reef._profile)
		_check(reef.treasures.found_count==1 and reef.rings.passed_count==1 and PHOTOS.load_discovered(reef._profile)==["shark"],"Host can complete local activities while connected")
		_check(await _until(func(): return _remote_moving(),7.0),"Vertical-only guest swim animates; last rows %s" % str(session.rows))
		_check(await _until(func(): return session.rows.is_empty() and session._ghosts.is_empty()),"Guest leaving Reef removes their diver")
		_check(await _until(func(): return _remote_at(-16.0)),"Guest re-enters without stale ghost")
		_check(await _until(func(): return session.rows.is_empty() and session.roster.size()==1,15.0),"Disconnect removes guest from host roster")
	else:
		_check(await _until(func(): return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length()>=12),"Invite available")
		reef.diver.position=Vector3(23,-16.45,-21)
		_check(session.join_session("Reef guest","127.0.0.1",FileAccess.get_file_as_string(path),port),"Join LAN reef")
		_check(await _until(func(): return _remote_at(-16.0) and _remote_gear()),"Guest sees host diving at depth")
		var initial_treasures: int=reef.treasures.found_count
		var initial_rings: int=reef.rings.passed_count
		await create_timer(.7).timeout
		_check(reef.treasures.found_count==initial_treasures and reef.rings.passed_count==initial_rings and PHOTOS.load_discovered(reef._profile).is_empty(),"Host's discoveries do not change the guest's collection")
		reef.diver.position=Vector3(23,-13,-21)
		reef.rise.button_down.emit()
		await create_timer(1.5).timeout
		reef.rise.button_up.emit()
		_check(reef.diver.position.y > -12.0,"Local guest rises without horizontal motion")
		reef.return_to_shop()
		await scene_changed
		_check(session.zone!="reef" and session._ghosts.is_empty(),"Returning to shop clears old Reef binding")
		await create_timer(.7).timeout
		await _enter()
		reef.diver.position=Vector3(23,-16,-21)
		_check(await _until(func(): return _remote_at(-16.0)),"Guest sees host again after re-entry")
		await create_timer(.7).timeout
		session.leave_session()


func _remote_at(y: float) -> bool:
	if session.rows.size()!=1: return false
	var row: Dictionary=session.rows.values()[0]
	return absf(row.position.y-y)<.08 and session.roster.any(func(r): return r.place=="At the reef")


func _remote_gear() -> bool:
	if session._ghosts.size()!=1: return false
	var ghost: Dictionary=session._ghosts.values()[0]
	return ghost.model.find_child("DiveTanks",true,false)!=null \
		and ghost.model.find_child("LeftDiveFin",true,false)!=null \
		and ghost.model.find_child("RightDiveFin",true,false)!=null \
		and ghost.animation!=null and ghost.animation.has_animation(SWIM.STROKE) \
		and ghost.companion==null


func _remote_moving() -> bool:
	return _remote_gear() and session._ghosts.values()[0].animation.current_animation==SWIM.STROKE 		and session.rows.values()[0].moving


func _until(predicate: Callable, seconds:=5.0) -> bool:
	var end:=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<end:
		if predicate.call(): return true
		await process_frame
	return false


func _check(ok: bool, detail: String) -> void:
	if not ok:
		failures+=1
		push_error(detail)
