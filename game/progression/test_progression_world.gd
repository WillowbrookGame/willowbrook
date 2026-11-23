extends SceneTree
const TOWN = preload("res://game/town_layout.gd")
var current: Node3D

func _initialize() -> void:
	call_deferred("_run")

func require(guard: bool, message: String) -> bool:
	if not guard:
		push_error(message)
		quit(1)
	return guard

func _run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	current = current_scene
	if not require(current.profile != null and current.town_progress != null,"Town didn't initialize the profile/Job Board"): return
	var profile: RefCounted = current.profile
	var checks := [
		["cafe",Vector3(0,0,-3.4),Vector3(2.5,0,-.5)],
		["store",Vector3(3,0,2),Vector3(3.7,0,-.5)],
		["town",Vector3(11,0,-24),Vector3(21,0,-24)],
		["town",Vector3(18.5,0,47),Vector3(21.5,0,51)]
	]
	for row in checks:
		var zone: String = row[0]
		if zone != "town" and not await _door(zone): return
		if not _task(zone,row[1]) or not _task(zone,row[2]): return
		if zone != "town":
			current.go_to_town()
			await scene_changed
			current = current_scene
		if not require(is_same(current.profile,profile),"Scene change lost the persistent profile"): return
	if not require(profile.get_stars()==5 and profile.starter_eligible(),"Completing the four room/town activities didn't pay and unlock hiring"): return

	current.player.position = Vector3(24,.04,-26)
	if not require(current._interaction_text().contains("Mayor"),"Mayor action missing, possibly shadowed by another interaction"): return
	current._interact()
	if not require(profile.memberships().has("park"),"Interacting with the Mayor did not hire player"): return
	if not _shift(): return
	if not require(profile.get_stars()==8,"Entry park job didn't pay 3 stars"): return

	if not await _door("library"): return
	current.player.position = Vector3(0,.04,1.2)
	if not require(current._interaction_text()=="Talk to the librarian","Librarian UI not reachable"): return
	current._interact()
	var ui: Node3D = current.room
	if not require(ui.is_modal_open(),"Pressing E did not open Classes dialog"): return
	# Credit test wallet only, then exercise the actual Classes UI for all tiers.
	var costs := [50,120,200]
	var rewards := [5,8,10]
	for i in range(3):
		var cost: int = costs[i]
		profile.change_stars(cost)
		ui.course_index = 8
		ui._library_menu(false)
		var button := _find_button(ui.fields,"Pay remaining %d stars" % cost)
		if not require(button != null and not button.disabled,"Tier %d pay button unavailable" % (i+1)): return
		button.pressed.emit()
		if not require(profile.get_stars() == 8 and profile.work_reward("park") == rewards[i] and profile.work_reward("cafe") == 3,"Tier %d tuition/pay was not applied just to this job" % (i+1)): return
	ui.close_modal()
	current.go_to_town()
	await scene_changed
	current = current_scene
	if not _shift(): return
	if not require(current.profile.get_stars()==18,"Post-education park shift didn't pay advertised 10 stars"): return
	if not _start_outdoor("nursery",Vector3(-23,0,46.6),Vector3(-23,0,50),[
		Vector3(-25.5,0,47),Vector3(-20.5,0,50),Vector3(-25.5,0,53),Vector3(-23,0,52.2)]): return
	if not _start_outdoor("singing",Vector3(49,0,-47.5),Vector3(54,0,-46),[
		Vector3(52,0,-48),Vector3(54,0,-48),Vector3(56,0,-48),Vector3(54,0,-49.5)]): return
	if not require(current.profile.get_stars()==24,"Entry nursery and singing jobs didn't pay 3 stars each"): return
	print("PASS: actual town and business scenes share profile; four starter routes, Mayor hiring and all three outdoor shifts, Librarian UI purchases all tiers, top-tier shift pays 10")
	quit()

func _find_button(node: Node, caption: String) -> Button:
	for candidate in node.get_children():
		if candidate is Button and candidate.text == caption: return candidate
		var nested := _find_button(candidate,caption)
		if nested != null: return nested
	return null

func _door(zone: String) -> bool:
	var entrance: Vector3 = TOWN.BUSINESS_DOORS[zone]
	var side := -1.0 if zone in ["store","cafe"] else 1.0
	current.player.position = entrance + Vector3(0,.04,side*1.3)
	if not require(current._interaction_text().begins_with("Enter"),"Can't enter "+zone): return false
	current._interact()
	if not require(current.changing,"E wasn't routed to "+zone): return false
	await scene_changed
	current = current_scene
	return require(current.current_zone_id()==zone,"Wrong room for "+zone)

func _shift() -> bool:
	current.player.position = Vector3(13,.04,-20)
	if not require(current._interaction_text()=="Collect the cleanup basket","Missing park shift entry action"): return false
	current._interact()
	return _task("town",Vector3(12,0,-22)) and _task("town",Vector3(20,0,-22)) and _task("town",Vector3(20,0,-27))

func _start_outdoor(id: String, employer: Vector3, station: Vector3, route: Array) -> bool:
	current.player.position = employer + Vector3.UP*.04
	current._interact()
	if not require(current.profile.memberships().has(id),"Hiring proximity/action failed for "+id): return false
	current.player.position = station + Vector3.UP*.04
	current._interact()
	if not require(current.profile.snapshot().work.get("name") == id,"Can't start shift "+id): return false
	for task: Vector3 in route:
		if not _task("town",task): return false
	return require(current.profile.snapshot().work.is_empty(),"Shift did not finish "+id)

func _task(zone: String, pos: Vector3) -> bool:
	current.player.position = pos+Vector3.UP*.04
	if not require(not current._interaction_text().is_empty(),"Task prompt missing at %s %s" % [zone,pos]): return false
	current._interact()
	# Real action passes wall time to service; advance explicitly to avoid sleeping for each task.
	var now := Time.get_unix_time_from_system()+3.0
	var r: Dictionary = current.profile.advance(zone,current.player.position,now)
	return require(r.get("ok",false),"No task timer completed at %s %s" % [zone,pos])
