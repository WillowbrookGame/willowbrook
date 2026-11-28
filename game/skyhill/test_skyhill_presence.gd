extends SceneTree

const SKY := preload("res://game/skyhill/presence.gd")
const ACCOUNT := preload("res://game/network/browser/account_session.gd")
const SCHEMA := preload("res://game/network/browser/message_schema.gd")
const LINK := preload("res://game/skyhill/town_link.gd")
const PARK := "res://game/skyhill/skyhill.tscn"
var failures := 0
var park: Node3D
var net: Node

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, why: String) -> void:
	if not ok:
		failures += 1
		push_error(why)

func until(condition: Callable, seconds := 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await create_timer(.04).timeout
	return false

func _run() -> void:
	set_meta("fishing_save_override","user://skyhill-presence-%s.cfg" % Time.get_ticks_usec())
	net = root.get_node("WillowbrookSession")
	LINK.enter(self, "female-a")
	await scene_changed
	await process_frame
	park = current_scene
	check(net.zone == SKY.ZONE and net._bound == park, "Town visit binds Skyhill")
	var args := OS.get_cmdline_user_args()
	if args.size() == 3:
		await lan(args[0],args[1],int(args[2]))
	else:
		await local_checks()
	if failures == 0:
		print("PASS Skyhill " + (args[0] + " native LAN" if args.size() == 3 else "schema, presentation, focus and HUD"))
	quit(1 if failures else 0)

func local_checks() -> void:
	var row := {"id":2,"alias":"Pilot","zone":"skyhill","x":23,"y":35.2,"z":-33,"yaw":1,"moving":true,"grounded":false,"glide":[.23,-.4]}
	var world := {"type":"world","zone":"skyhill","players":[row],"presence":[{"alias":"Pilot","place":"At Skyhill Park"}]}
	check(not SCHEMA.parse(JSON.stringify(world).to_utf8_buffer()).is_empty(),"World accepts Skyhill flight above old limit")
	row.y=42.1
	check(not SCHEMA.valid(world),"World rejects out-of-course height")
	row.y=35
	row.glide=[0,1.7]
	check(not SCHEMA.valid(world),"World rejects malformed bank")
	row.erase("glide")
	row.zone="town"
	world.zone="town"
	check(not SCHEMA.valid(world),"Town still rejects y above 25")
	row.y=0
	row.glide=[0,.1]
	check(not SCHEMA.valid(world),"Non-Skyhill rows may not carry gliding state")
	net._apply_pose(999,"skyhill",Vector3.ZERO,0,false,true)
	check(net._entries.is_empty(),"Unadmitted LAN pose does not create an entry")
	var at := Vector3(23,35.2,-33)
	var peer := {"id":2,"zone":"skyhill","alias":"Pilot","position":at,"yaw":1.0,"moving":true,"grounded":false,"character":"female-a","glide":[.23,-.4]}
	net._receive_local([peer],[])
	net._draw_ghosts(.1)
	var remote: Dictionary = net._ghosts[2].skyhill
	var glider: Node3D = remote.glider
	check(net._ghosts.size()==1 and glider.visible and not remote.walker.visible and absf(glider.rotation.z+.4)<.001,"Flight shows banked glider instead of a walker")
	check(glider.get_node("RiderAnchor").get_child(0).get_meta("avatar_id")=="female-a","Glider carries selected avatar")
	check(net._ghosts[2].node.find_children("*","CollisionObject3D",true,false).is_empty(),"Visitors cannot collide with local flight")
	peer.erase("glide")
	peer.position=park.get_node("Scenery/Overlook/Bench/Seat").global_position
	peer.moving=false
	peer.rest="sit"
	net._receive_local([peer],[])
	net._draw_ghosts(.1)
	check(net._ghosts.size()==1 and remote.walker.visible and not glider.visible and remote.animation.current_animation=="sit","Returning visitor switches immediately to seated walker")
	net._receive_local([],[])
	net._draw_ghosts(.1)
	await process_frame
	check(net._ghosts.is_empty() and not is_instance_valid(glider),"Departure removes visitor and its decorations")
	park._touch_seen=true
	park._refresh_deck_hud()
	for size in [Vector2i(360,640),Vector2i(640,360)]:
		root.size=size
		await process_frame
		await process_frame
		var menu: Control=net._zone_menu_button
		check(not menu.get_global_rect().intersects(park.prompt.get_global_rect()),"Multiplayer does not obscure instructions")
		check(root.get_visible_rect().encloses(park.town_return.get_global_rect()),"Town return fits viewport")
	var account := ACCOUNT.new()
	root.add_child(account)
	account.bind_zone("skyhill",park,park.walker,park.hud)
	for size in [Vector2i(360,640),Vector2i(640,360)]:
		root.size=size
		await process_frame
		await process_frame
		var prompt_rect: Rect2 = park.prompt.get_global_rect()
		check(not account._star_badge.get_global_rect().intersects(prompt_rect),"Browser wallet does not obscure instructions")
		check(not account._zone_menu_button.get_global_rect().intersects(prompt_rect),"Browser menu does not obscure instructions")
		check(account._hunt_view==null,"Skyhill does not mount Town scavenger controls")
	account.suspend_zone_for(park)
	account.queue_free()
	park.set_zone_modal(false)
	park._launch()
	check(not net._zone_menu_button.visible,"Flight hides the deck-only Multiplayer button")
	park._app_unfocused=true
	park._update_suspension()
	check(not park.network_skyhill_pose().moving,"Focus loss holds the glider's last pose")
	park._app_unfocused=false
	park._update_suspension()
	park._action()
	check(park.network_skyhill_pose().moving,"Resume republishes motion without rejoining")
	park._on_deck()
	check(net._zone_menu_button.visible,"Deck recovery restores Multiplayer")
	park._return_to_town()
	await scene_changed
	check(net.zone=="town" and net._ghosts.is_empty(),"Park exit clears visitors but rebinds Town")
	change_scene_to_file(PARK)
	await scene_changed
	check(net.zone!="skyhill","Standalone flight does not advertise a Skyhill visit")

func lan(role: String, path: String, port: int) -> void:
	if role == "host":
		check(net.host_session("Deck host","127.0.0.1",port),"LAN host listens on loopback")
		var invite := FileAccess.open(path,FileAccess.WRITE)
		invite.store_string(net.invite_code())
		invite.close()
		check(await until(func(): return any_visitor(func(row): return row.get("glide") is Array and row.position.y>30.0)),"Deck host sees the airborne guest above old cap")
		check(await until(func(): return any_visitor(func(row): return row.get("glide") is Array and row.grounded and row.position.z < -100)),"Deck host sees guest land in meadow")
		check(await until(func(): return net.rows.is_empty() and net._ghosts.is_empty() and net.roster.size()==2),"Guest returning to Town removes only their Skyhill presence")
		check(await until(func(): return any_visitor(func(row): return not row.has("glide"))),"Guest revisits without stale glider")
		check(await until(func(): return net.roster.size()==1 and net._ghosts.is_empty()),"Disconnect removes guest and view")
	else:
		check(await until(func(): return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).length()==12),"Host invite is ready")
		check(net.join_session("Pilot guest","127.0.0.1",FileAccess.get_file_as_string(path),port),"LAN guest joins")
		check(await until(func(): return any_visitor(func(row): return not row.has("glide"))),"Guest sees deck host")
		park._launch()
		# Pin the pose so this transport test is independent of terrain and frame timing.
		park._paused=true
		park.flight.position=Vector3(23,34,-33)
		park._glider_pose()
		await create_timer(1.3).timeout
		check(park.network_skyhill_pose().position.y > 30.0,"Guest sends a held high flight pose")
		park._land(Vector3(0,0,-125))
		park._paused=false
		await create_timer(1.8).timeout
		park._on_deck()
		park._return_to_town()
		await scene_changed
		check(net.zone=="town" and net.admitted,"Guest stays connected on Town return")
		await create_timer(1.0).timeout
		LINK.enter(self,"female-a")
		await scene_changed
		check(await until(func(): return any_visitor(func(row): return not row.has("glide"))),"Guest sees host again after re-entry")
		await create_timer(1.0).timeout
		net.leave_session()
		await create_timer(.5).timeout

func any_visitor(predicate: Callable) -> bool:
	return net.rows.values().any(predicate)
