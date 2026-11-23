extends SceneTree

const Profile := preload("res://paintball_prototype/progression/profile.gd")
const Board := preload("res://paintball_prototype/progression/town_progression.gd")


class FakeHost extends Node3D:
	var profile: RefCounted
	var modal := false
	func set_zone_modal(open: bool) -> void:
		modal = open


var _fail := false


func _initialize() -> void:
	call_deferred("_run")


func check(test: bool, why: String) -> void:
	if not test:
		push_error(why)
		_fail = true


func _run() -> void:
	var path := "user://progress-test-%d-%d.cfg" % [OS.get_process_id(),Time.get_ticks_usec()]
	var profile := Profile.new(path,37)
	check(profile.get_stars() == 0 and not profile.starter_eligible(),"Fresh player starts at 0 and needs four activities")
	check(not profile.change_stars(-1),"Wallet cannot go below zero")
	check(profile.starter_checklist(0.0).size() == 4 and profile.available_markers("town").size()==2 and profile.available_markers("cafe").size()==1,"Starter checklist and initial markers show the correct locations")
	var stale := profile.snapshot()
	stale.fish.append("goldfish")
	stale.fishing_migrated = true
	check(profile.commit(stale),"Unified profile accepts fish migration")
	stale.fish.clear()
	check(profile.snapshot().fish == ["goldfish"],"Snapshot/commit copy nested data")
	check(not profile.hire("park","town",Vector3(24,0,-26)).ok,"Cannot hire before starter activities")
	check(profile.perform("town",Vector3(0,0,0)).is_empty(),"No action remotely")
	# The cafe's absolute web coordinates overlap town objects, but must never work outdoors.
	check(profile.perform("town",Vector3(16,0,20.6)).is_empty(),"Indoor task isn't exposed in town")
	check(profile.perform("cafe",Vector3(0,0,-3.4),100.0).ok,"Cafe starter timer begins in local room coordinates")
	check(profile.advance("cafe",Vector3(0,0,-3.4),101.99).is_empty(),"Starter task waits for two seconds")
	check(profile.advance("cafe",Vector3(7,0,5),102.1).ok,"Walking away cancels the active timer")
	check(profile.advance("cafe",Vector3(0,0,-3.4),104.0).is_empty(),"Walking back alone doesn't finish a canceled timer")
	check(profile.perform("cafe",Vector3(0,0,-3.4),105.0).ok,"Retry starts a fresh timer")
	check(profile.advance("cafe",Vector3(0,0,-3.4),107.1).ok,"Finish first starter step")
	_finish_step(profile,"cafe",Vector3(2.5,0,-0.5),108.0)
	check(profile.get_stars() == 1,"Cafe starter awards 1 star")
	_complete_starter(profile,"store",Vector3(3,0,2),Vector3(3.7,0,-0.5),112.0)
	_complete_starter(profile,"town",Vector3(11,0,-24),Vector3(21,0,-24),120.0)
	_complete_starter(profile,"town",Vector3(18.5,0,47),Vector3(21.5,0,51),128.0)
	check(profile.starter_eligible() and profile.get_stars() == 5,"Four starter activities unlock paid jobs; combined total is 5")
	_complete_starter(profile,"town",Vector3(18.5,0,47),Vector3(21.5,0,51),140.0)
	check(profile.get_stars() == 5,"Garden does not award twice within cooldown")
	var checklist: Array[Dictionary] = profile.starter_checklist(150.0)
	check(checklist[3].done and checklist[3].wait > 200 and checklist[3].reward == 2,"Starter checklist shows cooldown after a repeat")
	check(not profile.hire("park","town",Vector3.ZERO).ok,"Can't get hired away from employer")
	check(profile.hire("park","town",Vector3(24,0,-26)).ok and profile.memberships().has("park"),"Mayor hires a qualified candidate")
	check(profile.hire("delivery","store",Vector3(0,0,-1.8)).ok,"Shopkeeper can hire delivery without losing prior work")
	check(profile.hire("cafe","cafe",Vector3(4.5,0,-3.7)).ok,"Indoor hire uses room-local coordinates")
	_finish_park(profile,150.0)
	_finish_park(profile,160.0)
	check(profile.get_stars() == 11,"Entry pay is 3 per shift and hands-on shifts are repeatable right away")
	check(profile.perform("store",Vector3(-3,0,2),172.0).ok,"Begin parcel route at store")
	check(profile.perform("store",Vector3(-3,0,2),173.0).ok and profile.status_text().begins_with("Deliver to "),"Parcel pickup chooses a destination and exposes it in HUD")
	var marker := profile.current_marker("town")
	check(not marker.is_empty(),"Parcel route target is outdoors")
	check(profile.perform("town",marker.position,174.0).ok and profile.get_stars() == 14,"Correct door delivers parcel for 3 stars")
	check(profile.snapshot().job.deliveries == 1 and profile.perform("town",marker.position,175.0).is_empty(),"Delivery cannot be repeated without another parcel")
	check(profile.change_stars(50) and profile.take_class("park",20).ok,"Pay first class installment")
	check(profile.work_reward("park") == 3 and profile.snapshot().classes.park.paid == 20,"Partial installments do not unlock class")
	check(not profile.take_class("park",31).ok and profile.get_stars() == 44,"Overpaying leaves balance unchanged")
	check(profile.take_class("park",30).ok and profile.work_reward("park") == 5,"Full tier 1 class raises only its own job's pay")
	check(profile.work_reward("delivery") == 3,"Another job's pay remains unchanged")
	_finish_park(profile,180.0)
	check(profile.get_stars() == 19,"Tier 1 park shift pays 5")

	var host := FakeHost.new()
	host.profile = profile
	root.add_child(host)
	var player := CharacterBody3D.new()
	host.add_child(player)
	player.position = Vector3(10,0,4)
	var hud := CanvasLayer.new()
	host.add_child(hud)
	var board := Board.new()
	host.add_child(board)
	board.setup(host,player,hud)
	check(board.interaction_prompt() == "Read the job board" and board.interact() and host.modal,"Job Board opens at the original plaza")
	board.close_modal()
	check(not host.modal,"Board closes and releases world controls")
	board._checklist_button.pressed.emit()
	check(host.modal and board._heading.text=="Getting Started" and board._guide.text.contains("watering can"),"Getting Started opens the four-action checklist and directions")
	board.close_modal()
	player.position = Vector3(13,0,-20)
	board.interact()
	check(profile.active() and board.interaction_prompt().is_empty(),"Starting a shift makes its first actual work step active")
	check(profile.cancel().ok and not profile.active(),"Players can cancel work without stars")
	host.queue_free()

	var saved := Profile.new(path,50)
	check(saved.get_stars() == 19 and saved.snapshot().fish == ["goldfish"] and saved.snapshot().fishing_migrated,"Reload retains stars and migrated catch")
	check(saved.memberships().size() == 3 and saved.work_reward("park") == 5 and saved.snapshot().job.deliveries == 1,"Reload retains memberships, classes and deliveries")
	check(FileAccess.file_exists(path+".bak"),"Atomic save produces a known previous-state backup")
	var broken := FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("; simulates interruption before current save publication")
	broken.close()
	var recovered := Profile.new(path,53)
	check(recovered.get_stars() == 19 and recovered.snapshot().fish.size() == 1,"Recovery uses last validated backup")

	for name in [path,path+".bak",path+".tmp"]:
		if FileAccess.file_exists(name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(name))
	if not _fail:
		print("PASS: jobs, starter cooldowns, shared save and backup, parcel route, classes, and Job Board")
	quit(1 if _fail else 0)


func _complete_starter(p: Profile, zone: String, first: Vector3, second: Vector3, time: float) -> void:
	_finish_step(p,zone,first,time)
	_finish_step(p,zone,second,time+3.0)


func _finish_step(p: Profile, zone: String, point: Vector3, time: float) -> void:
	check(p.perform(zone,point,time).get("ok",false),"Begin expected task")
	check(p.advance(zone,point,time+2.1).get("ok",false),"Finish expected task")


func _finish_park(p: Profile, time: float) -> void:
	check(p.perform("town",Vector3(13,0,-20),time).get("ok",false),"Start park shift at supplies")
	_finish_step(p,"town",Vector3(12,0,-22),time+0.1)
	_finish_step(p,"town",Vector3(20,0,-22),time+3.1)
	_finish_step(p,"town",Vector3(20,0,-27),time+6.1)
