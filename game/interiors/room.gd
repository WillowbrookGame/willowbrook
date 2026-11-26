extends Node3D
const ART = preload("res://game/interiors/room_art.gd")
const JOB_ART = preload("res://game/interiors/room_jobs.gd")
const DATA := preload("res://game/interiors/room_data.json")
const HOUSING_PLACEMENT := preload("res://game/interiors/housing_placement.gd")
const TITLE := {"home":"Your Home"}
const JOBS := ["delivery","bank","vet","salon","cafe","store","library","nursery","park","singing"]
const PETS = preload("res://game/pets/catalog.gd")
const PET_ACTORS = preload("res://game/pets/actors.gd")
var pets: PET_ACTORS
var _pet_request_until := 0

var id := ""
var host: Node3D
var player: CharacterBody3D
const PROX = preload("res://game/npc_proximity.gd")
var art: ART
var hud: CanvasLayer
var panel: CenterContainer
var fields: VBoxContainer
var heading: Label
var body: Label
var notice: Label
var balance: Label
var active_panel := ""
var job_art: JOB_ART
var hud_refresh := 0.0
var seated := false
var _lock_button: Button
var rest_pose := ""
var seat_origin := Vector3.ZERO
var seat_avatar_yaw := 0.0
var seat_visual: Node3D
var seat_visual_rest := Transform3D.IDENTITY
var _room_memberships: Array = []
var _pending_hire := ""
var _hire_timeout := 0
var state_message := ""
var notice_timer := 0.0

var _room_window: PanelContainer
var _room_scroll: ScrollContainer
var _edit_feedback: Label
var _edit_commands: HFlowContainer

func setup(room_id: String, room_host: Node3D, body_player: CharacterBody3D, room_hud: CanvasLayer) -> void:
	id = room_id if not _room_title(room_id).is_empty() else "home"
	host = room_host
	player = body_player
	hud = room_hud
	art = _new_room_art()
	art.name = "RoomArt"
	add_child(art)
	art.build(id,_snapshot())
	_create_hud()
	var account := _account()
	if _visiting(): return
	if account!=null and account.has_signal("pet_result"):
		account.pet_result.connect(_pet_result)
		account.pet_snapshot_changed.connect(_sync_pet_actors)
	if id=="home" and account!=null and account.has_signal("yard_result"):
		account.yard_result.connect(_on_yard_result)
	if _uses_furniture_account() and account!=null and account.has_signal("furniture_result"):
		account.furniture_result.connect(_on_furniture_result)
	if id=="home":
		pets = PET_ACTORS.new()
		pets.name = "IndoorPets"
		add_child(pets)
		pets.configure(player,HOUSING_PLACEMENT.room_count(_snapshot()))
		_sync_pet_actors()
	if id != "home":
		job_art = JOB_ART.new()
		add_child(job_art)
		job_art.setup(id,art,hud)
	if _welcomes_visitors(): feedback("Hi! Welcome to %s." % _room_title(id))

func _room_title(key: String) -> String:
	return TITLE.get(key, "")

func _new_room_art() -> ART:
	return ART.new()

func _welcomes_visitors() -> bool:
	return false

func _fallback_seats() -> Array:
	return []

func _publishes_sitting() -> bool:
	return false

func spawn_position() -> Vector3:
	return Vector3(0,.04,5.5)

func bounds() -> Vector2:
	return Vector2(9,7.12)

func close_modal() -> void:
	if is_modal_open():
		if active_panel == "home":
			art.clear_placement_ghost()
			_close_home_editor()
		_before_close_panel()
		active_panel = ""
		_pending_hire = ""
		panel.hide()
		host.set_zone_modal(false)
	elif seated:
		_stand()

func _before_close_panel() -> void:
	pass

func is_modal_open() -> bool:
	return is_instance_valid(panel) and panel.visible

func _visiting() -> bool:
	return id=="home" and is_instance_valid(host) and host.get("guest_variant") is String and not str(host.guest_variant).is_empty()

func refresh_guest_decor() -> void:
	if _visiting(): art.redraw_decor(_snapshot())

func refresh_home_lock() -> void:
	if is_instance_valid(_lock_button):
		_lock_button.text="Unlock front door" if host.home_locked==true else "Lock front door"

func _uses_furniture_account() -> bool:
	return id == "home"

func _snapshot() -> Dictionary:
	if _visiting(): return host.profile_snapshot()
	var snapshot: Dictionary = host.profile_snapshot() if is_instance_valid(host) and host.has_method("profile_snapshot") else {}
	var account := _account() if _uses_furniture_account() else null
	if account != null and account.furniture_available():
		snapshot.furniture = account.furniture_rows()
	return snapshot

func _on_yard_result(_ok: bool,message: String) -> void:
	if is_modal_open() and active_panel=="home":
		_home_menu(false)
	feedback(message)

func _on_furniture_result(ok: bool, message: String) -> void:
	if ok:
		if id=="home":
			art.redraw_decor(_snapshot())
		if is_modal_open():
			if active_panel=="home":
				_home_menu(false)
	feedback(message)

func _send_furniture(operation: String, args: Dictionary) -> void:
	var account := _account()
	if account.furniture_waiting():
		feedback("Waiting for the last furniture change.")
	elif account.furniture_command(operation,args):
		feedback("Saving your furniture change.")
	else:
		feedback("Could not reach the account server. Nothing was changed here.")

func _commit(next: Dictionary, message: String) -> bool:
	if not host.has_method("profile_commit") or not host.profile_commit(next):
		feedback("Could not save. Nothing was changed.")
		return false
	feedback(message)
	return true

func _service() -> RefCounted:
	return host.get("profile") as RefCounted

func _account() -> Node:
	var node := get_node_or_null("/root/WillowbrookBrowserSession")
	return node if OS.has_feature("web") and node != null and node.has_method("job_offer") else null

func _near(at: Vector3, radius := 1.75) -> bool:
	return absf(player.position.y-at.y)<1.35 and Vector2(player.position.x-at.x,player.position.z-at.z).length() <= radius

func _near_exit() -> bool:
	return _near(Vector3(0,0,6.57),.96)

func _desk() -> Vector3:
	return Vector3(0,0,1.2)

func _near_clerk() -> bool:
	var actor := art.conversation_actor
	if not is_instance_valid(actor):
		return false
	var at := player.global_position
	var npc_at := actor.global_position
	# Remain on the public side of the desk. Eye-level sight crosses low counters,
	# but not partitions, cabinets, or walls.
	if at.z <= npc_at.z + .45:
		return false
	return PROX.visible_from(self,at,npc_at,4.3,npc_at,[player.get_rid()])

func _face_customer() -> void:
	if is_instance_valid(art.conversation_actor):
		var actor := art.conversation_actor
		var direction := player.global_position - actor.global_position
		actor.rotation.y = atan2(direction.x,direction.z)

func interaction_prompt() -> String:
	if not is_instance_valid(player) or is_modal_open(): return ""
	if seated: return "Stand up"
	if _near_exit(): return "Return to town"
	if _visiting(): return ""
	var account := _account()
	var service := _service()
	if account != null:
		var offer: Dictionary = account.job_offer(false)
		if not offer.is_empty(): return String(offer.label)
	elif service != null and service.has_method("prompt"):
		var task: String = service.prompt(id,player.position)
		if not task.is_empty(): return task
	var candidate := _near_seat()
	if not candidate.is_empty(): return "Lie down" if candidate.get("pose") == "lie" else "Sit down"
	if id=="home": return "Decorate your home" if absf(player.position.z)<4.0 else ""
	return _clerk_prompt() if _near_clerk() else ""

func _clerk_prompt() -> String:
	return ""

func _interact_room_specific(_prompt: String) -> bool:
	return false

func interact() -> bool:
	var prompt := interaction_prompt()
	if prompt.is_empty(): return false
	if prompt.begins_with("Talk to "):
		_face_customer()
	match prompt:
		"Return to town": host.go_to_town()
		"Stand up": _stand()
		"Sit down","Lie down": toggle_rest()
		"Decorate your home": _home_menu()
		_:
			if _interact_room_specific(prompt): return true
			var account := _account()
			if account != null:
				account.interact_job(account.job_offer(false))
				return true
			var service := _service()
			if service == null or not service.has_method("perform"): return false
			_show_result(service.perform(id,player.position))
	return true

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(host): return
	if seated:
		_update_seat_visual()
	if _pet_request_until>0 and Time.get_ticks_msec()>_pet_request_until:
		_pet_request_until=0
		if is_modal_open(): feedback("The server did not respond. Check the connection before trying again.")
	if notice_timer>0:
		notice_timer-=delta
		if notice_timer<=0 and not is_modal_open():
			notice.text = ""
			state_message = ""
	hud_refresh -= delta
	if hud_refresh>0: return
	hud_refresh=.10
	var snapshot := _snapshot()
	var account := _account()
	if is_modal_open():
		var membership_list := _memberships(snapshot)
		var changed := membership_list != _room_memberships
		var expired := not _pending_hire.is_empty() and Time.get_ticks_msec() >= _hire_timeout
		if changed or expired:
			var hired := membership_list.has(_pending_hire)
			if hired:
				feedback("You're hired for %s!" % _pending_hire.capitalize())
			_pending_hire = ""
			_refresh_hire_menu()
	if balance != null:
		balance.text = ("Temporary Stars: %d" if account != null else "Stars: %d") % int(snapshot.get("stars",0))
	var service := _service()
	if job_art != null and service != null and service.has_method("current_marker"):
		var suggested: Dictionary = {}
		var actual: Dictionary = service.current_marker(id)
		if account != null:
			var active_items: Array = account.job_markers(true)
			actual = active_items[0] if not active_items.is_empty() else {}
		if actual.is_empty() and service.has_method("available_markers"):
			var best := 5.5
			for row: Dictionary in (account.job_markers() if account != null else service.available_markers(id)):
				if not row.has("position"): continue
				var distance := player.position.distance_to(row.position)
				if distance<best:
					best=distance
					suggested=row
		job_art.update_status(snapshot,actual,is_modal_open(),suggested)

func _show_result(result: Dictionary) -> void:
	var message: String = result.get("message",result.get("text",""))
	if not message.is_empty(): feedback(message)

func feedback(message: String) -> void:
	state_message = message
	notice_timer = 6.0
	if notice != null: notice.text = message
	if is_instance_valid(_edit_feedback) and active_panel == "home": _edit_feedback.text = message

func _work_menu(reset := true) -> void:
	_open_panel("job",_room_title(id), "Pick up the kit at the start marker, then follow each highlighted station. Stay there until each task finishes.",reset)
	_hire_button(id)


func _memberships(snapshot: Dictionary = {}) -> Array:
	var account := _account()
	if account != null:
		return account.job_memberships().duplicate()
	var service := _service()
	if service != null and service.has_method("memberships"):
		return service.memberships().duplicate()
	var result: Array = snapshot.get("memberships",[]).duplicate()
	var legacy: Variant = snapshot.get("employed","")
	if legacy is String and not legacy.is_empty() and not result.has(legacy):
		result.append(legacy)
	return result


func _refresh_hire_menu() -> void:
	match active_panel:
		"job": _work_menu(false)


func _hire_button(job: String) -> void:
	if job not in JOBS: return
	var memberships := _memberships(_snapshot())
	if memberships.has(job):
		_label("You are hired for %s. Find the shift's starting station." % job.capitalize())
		return
	# Talking is easier than reaching the small server-authorized hiring area.
	if not _near(_desk(),1.7):
		_label("Move closer to the front of the counter, then talk again to get hired.")
		return
	var button := _button("Get hired: " + job.capitalize(),func():
		var account := _account()
		if account != null:
			if not _pending_hire.is_empty():
				return
			_pending_hire = job
			_hire_timeout = Time.get_ticks_msec()+6000
			feedback("Checking with town staff.")
			account.job_action("hire",job)
			_refresh_hire_menu()
			return
		var service := _service()
		if service == null or not service.has_method("hire"):
			feedback("Visit the job board to get hired.")
			return
		_show_result(service.hire(job,id,player.position))
		_refresh_hire_menu()
	)
	button.disabled = not _pending_hire.is_empty()

func _pet_state() -> Dictionary:
	var account := _account()
	if account!=null and account.has_method("pets_available") and account.pets_available(): return account.pet_state()
	return PETS.state(_snapshot())

func _sync_pet_actors() -> void:
	if is_instance_valid(pets): pets.synchronize(_pet_state())

func _online_pet_action(feature: String,operation: String,argument: Variant) -> void:
	if _pet_request_until>0: return
	var account := _account()
	if account==null or not account.has_method("pet_command") or not account.pet_command(feature,operation,argument):
		feedback("Could not reach the town server.")
		return
	_pet_request_until=Time.get_ticks_msec()+8000
	feedback("Checking with the town server…")

func _pet_result(action: String,operation: String,ok: bool,text: String) -> void:
	if operation not in ["adopt","equip","claim"]: return
	_pet_request_until=0
	if ok:
		_sync_pet_actors()
		_on_room_pet_success(operation)
		if active_panel=="home" and operation=="equip": _home_menu()
		_on_room_service_success(action,operation)
	if is_modal_open() and not text.is_empty(): feedback(text)

func _on_room_service_success(_action: String,_operation: String) -> void:
	pass

func _on_room_pet_success(_operation: String) -> void:
	pass

func _home_pets() -> void:
	var state := _pet_state()
	var selection := OptionButton.new()
	selection.name="OutdoorPetChoice"
	selection.fit_to_longest_item=false
	selection.add_item("Leave all pets home")
	var ids: Array = [null]
	var kinds: Dictionary = {}
	for pet: Dictionary in state.get("owned",[]):
		var key: String=pet.species
		kinds[key]=int(kinds.get(key,0))+1
		selection.add_item("%s %d" % [PETS.display(key),kinds[key]])
		ids.append(pet.id)
		if pet.id==state.get("activeId"): selection.select(ids.size()-1)
	var change := func():
		var id_choice: Variant=ids[selection.selected]
		if _account()!=null:
			_online_pet_action("pets","equip",id_choice)
			return
		var next := _snapshot()
		var current := PETS.state(next)
		current.activeId=id_choice
		next.pet={}
		next.pets=current
		if _commit(next,"All pets will stay home." if id_choice==null else "Your pet will follow you outside."):
			_sync_pet_actors()
			_home_menu(false)
	_label("Outdoor companion")
	fields.add_child(selection)
	_button("Save companion choice",change)

func _home_menu(reset := true) -> void:
	if _visiting(): return
	var p := _snapshot()
	var account := _account()
	var intro := "Choose furniture and drag its preview into place. Small decor can go on furniture. Confirm to save. Right-drag or use Drag to orbit to look around."
	_open_panel("home","Decorate your home",intro,reset)
	_setup_home_editor(p)
	if account!=null and account.has_method("home_visits_available") and account.home_visits_available() and host.home_locked!=null:
		_lock_button=_button("",func():
			if not account.home_visit_command("lock",host.home_locked!=true): feedback("Could not change the door lock.")
		)
		refresh_home_lock()
	_home_pets()

	if account != null and account.yard_eligible():
		_label("Improve your yard - saved stars: %d" % account.saved_stars())
		for row: Array in [["fence","Yard fence",30],["trees","Yard trees",20],["decor","Yard decorations",15]]:
			var yard_kind: String = row[0]
			var installed := bool(account.yard_flags().get(yard_kind,false))
			var cost: int = row[2]
			var button := _button("%s: %s" % [row[1],"Installed" if installed else "Buy for %d stars" % cost],func():
				if account.buy_yard(yard_kind):
					feedback("Saving your yard improvement.")
				elif account.yard_waiting():
					feedback("Waiting for your last yard purchase.")
				else:
					feedback("Could not reach the server. Nothing changed here.")
			)
			button.disabled = installed or cost > account.saved_stars()

func _layout_room_panel() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	_room_scroll.custom_minimum_size = Vector2(320,210)
	if active_panel == "home":
		_layout_home_editor(get_viewport().get_visible_rect().size)

func _layout_home_editor(_viewport_size: Vector2) -> void:
	pass

func _setup_home_editor(_profile: Dictionary) -> void:
	pass

func _close_home_editor() -> void:
	pass


func _add_stock(pieces: Array, kind: String, qty: int) -> void:
	if qty<=0 or not DATA.data.furnitureCatalog.has(kind): return
	for item: Dictionary in pieces:
		if item.get("kind","")==kind and not item.has("x"):
			item.quantity = int(item.get("quantity",1))+qty
			return
	pieces.append({"kind":kind,"quantity":qty})

func _footprint(item: Dictionary) -> Rect2:
	return HOUSING_PLACEMENT.footprint(item)


func _placement_player_radius() -> float:
	for child: Node in player.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape is CapsuleShape3D:
			return float(child.shape.radius) * maxf(absf(child.global_basis.get_scale().x),absf(child.global_basis.get_scale().z)) + .015
	return .325


func _prepare_furniture(p: Dictionary,index: int,room_index: int,x: float,z: float,turns: int,support: Dictionary) -> Dictionary:
	var pieces: Array = p.get("furniture",[])
	if index<0 or index>=pieces.size():
		return {"error":"Choose a packed item first."}
	var source: Dictionary = pieces[index]
	var kind := String(source.get("kind",""))
	if source.has("x") or not DATA.data.furnitureCatalog.has(kind):
		return {"error":"Choose a packed item first."}
	var item := {"kind":kind,"room":room_index,"x":x,"z":z,"rotation":turns}
	var supporter: Dictionary = {}
	var surface: Dictionary = {}
	if not support.is_empty():
		var at := int(support.get("index",-1))
		if at<0 or at>=pieces.size():
			return {"item":item,"error":"Choose an available furniture surface."}
		supporter = pieces[at]
		var chosen: Variant = support.get("surface")
		if not supporter.has("x") or not supporter.has("id") or not chosen is Dictionary:
			return {"item":item,"error":"Choose an available furniture surface."}
		surface = HOUSING_PLACEMENT.surface_for(String(supporter.get("kind","")),String(chosen.get("id","")))
		if surface.is_empty():
			return {"item":item,"error":"Choose an available furniture surface."}
		item.supportId = supporter.id
		item.surfaceId = surface.id
		item.y = float(surface.y)
	var error := HOUSING_PLACEMENT.placement_error(item,pieces,HOUSING_PLACEMENT.room_count(p),art.to_local(player.global_position),_placement_player_radius(),supporter,surface)
	return {"item":item,"error":error}


func _place_furniture(index: int, room_index: int, x: float, z: float, turns: int, support: Dictionary = {}) -> void:
	var p := _snapshot()
	var result := _prepare_furniture(p,index,room_index,x,z,turns,support)
	var error := String(result.get("error",""))
	if not error.is_empty():
		feedback(error)
		return
	var pieces: Array = p.get("furniture",[])
	var source: Dictionary = pieces[index]
	var item: Dictionary = result.item
	var account := _account()
	if account != null:
		if not account.furniture_available():
			feedback("Reconnect to sync your saved trophy.")
			return
		item.erase("y")
		_send_furniture("place",item)
		return
	item.id = "f-%s" % str(Time.get_ticks_usec())
	if int(source.get("quantity",1))<=1: pieces.remove_at(index)
	else: source.quantity = int(source.quantity)-1
	pieces.append(item)
	p.furniture = pieces
	if _commit(p,"Furniture placed."):
		art.redraw_decor(p); _home_menu(false)


func _pack_furniture(index: int) -> void:
	var p := _snapshot()
	var pieces: Array = p.get("furniture",[])
	if index<0 or index>=pieces.size() or not pieces[index].has("x"): return
	var item: Dictionary = pieces[index]
	var account := _account()
	if account != null:
		if not account.furniture_available():
			feedback("Reconnect to sync your saved trophy.")
			return
		_send_furniture("pack",{"id":str(item.id),"expectedRevision":int(item.get("revision",0))})
		return
	pieces.remove_at(index)
	var packed: Array[String] = [str(item.kind)]
	for i in range(pieces.size()-1,-1,-1):
		if item.has("id") and pieces[i].get("supportId","")==item.id:
			packed.append(str(pieces[i].kind))
			pieces.remove_at(i)
	for kind in packed: _add_stock(pieces,kind,1)
	p.furniture = pieces
	if _commit(p,"Furniture packed away."):
		art.redraw_decor(p); _home_menu(false)

func _near_seat() -> Dictionary:
	if id=="home":
		var candidate := {}
		var closest := 1.85
		var stride := HOUSING_PLACEMENT.ROOM_STRIDE
		var room_index := int(floor((player.position.x+stride*.5)/stride))
		for item: Dictionary in _snapshot().get("furniture",[]):
			var kind := String(item.get("kind",""))
			if kind not in ["chair","sofa","bed"] or not item.has("x") or item.get("supportId")!=null or int(item.get("room",0)) != room_index: continue
			var point := Vector3(float(room_index)*stride+float(item.x),0,float(item.z))
			var reach := Vector2(player.position.x-point.x,player.position.z-point.z).length()
			if reach >= closest or not _near(point,closest): continue
			var mapped := art.to_global(point)
			if not PROX.visible_from(self,player.global_position,mapped,closest,mapped,[player.get_rid()]): continue
			var height := .61 if kind == "bed" else (.66 if kind == "sofa" else .60)
			candidate = {"at":point+Vector3.UP*height,"visual_yaw":float(item.get("rotation",0))*PI/2.0,"pose":"lie" if kind == "bed" else "sit"}
			closest = reach
		return candidate
	elif not art.public_seats.is_empty():
		var nearest := {}
		var closest := 1.45
		for spec: Dictionary in art.public_seats:
			var chair: Node3D = spec.chair
			var dist := Vector2(player.global_position.x-chair.global_position.x,player.global_position.z-chair.global_position.z).length()
			if dist <= closest and absf(player.global_position.y-chair.global_position.y)<1.35:
				closest = dist
				nearest = {"at":player.get_parent().to_local(chair.to_global(spec.surface)),"visual_yaw":chair.global_rotation.y}
		return nearest
	else:
		for at: Vector3 in _fallback_seats():
			if _near(at,1.45): return {"at":at+Vector3.UP*.43,"yaw":PI}
	return {}


func toggle_rest() -> bool:
	if _visiting(): return false
	if is_modal_open(): return false
	if seated:
		_stand()
		return true
	var spec := _near_seat()
	if spec.is_empty() or not player.is_physics_processing() or not player.is_on_floor(): return false
	_sit(spec)
	return true

func leave_rest_for_motion() -> void:
	if seated and not is_modal_open(): _stand()

func network_rest_pose() -> String:
	return "sit" if seated and _publishes_sitting() and rest_pose == "sit" else ""

func network_rest_yaw() -> float:
	return seat_avatar_yaw

func _sit(spec: Dictionary) -> void:
	if spec.is_empty(): return
	seated = true
	rest_pose = String(spec.get("pose","sit"))
	seat_origin = player.position
	player.velocity = Vector3.ZERO
	player.held.clear()
	player.set_physics_process(false)
	player.position = spec.at
	seat_avatar_yaw = float(spec.get("visual_yaw",spec.get("yaw",0.0)))
	seat_visual = host.get("arena_avatar") as Node3D
	if is_instance_valid(seat_visual):
		seat_visual_rest = seat_visual.transform
		_update_seat_visual()
	if host.has_method("set_room_seated"): host.set_room_seated(true)


func _update_seat_visual() -> void:
	if not is_instance_valid(seat_visual):
		return
	# The camera can still orbit; the avatar rather than camera follows the chair.
	var yaw := wrapf(seat_avatar_yaw-player.global_rotation.y,-PI,PI)
	seat_visual.rotation = Vector3(0,yaw,0)
	var offset := Vector3(0,-.02625*seat_visual.scale.y,.02875*seat_visual.scale.z)
	if rest_pose == "lie":
		seat_visual.rotate_object_local(Vector3.RIGHT,-PI/2.0)
		offset = Vector3(0,.11*seat_visual.scale.y,.26*seat_visual.scale.z)
	seat_visual.position = seat_visual_rest.origin+offset.rotated(Vector3.UP,yaw)


func _stand() -> void:
	seated = false
	rest_pose = ""
	if is_instance_valid(seat_visual):
		seat_visual.transform = seat_visual_rest
		seat_visual = null
	player.position = seat_origin
	player.velocity = Vector3.ZERO
	player.held.clear()
	player.set_physics_process(true)
	if host.has_method("set_room_seated"): host.set_room_seated(false)

func _create_hud() -> void:
	balance = Label.new()
	balance.position = Vector2(18,96)
	balance.add_theme_font_size_override("font_size",18)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(balance)
	notice = Label.new()
	notice.position = Vector2(18,122)
	notice.add_theme_font_size_override("font_size",16)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(notice)
	panel = CenterContainer.new()
	panel.name = "RoomDialog"
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var window := PanelContainer.new()
	_room_window = window
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(window)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	window.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",24)
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	body = Label.new()
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	var scroll := ScrollContainer.new()
	_room_scroll = scroll
	scroll.custom_minimum_size=Vector2(320,210)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	column.add_child(scroll)
	fields = VBoxContainer.new()
	fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation",6)
	scroll.add_child(fields)
	_edit_feedback = Label.new()
	_edit_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_edit_feedback.hide()
	column.add_child(_edit_feedback)
	_edit_commands = HFlowContainer.new()
	_edit_commands.hide()
	column.add_child(_edit_commands)
	var done := Button.new()
	done.text="Done"
	done.custom_minimum_size.y=44
	done.pressed.connect(close_modal)
	column.add_child(done)
	panel.hide()
	get_viewport().size_changed.connect(_layout_room_panel)

func _open_panel(name_: String,title: String,message: String,reset := true) -> void:
	active_panel=name_
	if art != null:
		art.clear_placement_ghost()
	_edit_feedback.visible = name_=="home"
	_edit_commands.visible = name_=="home"
	for child in _edit_commands.get_children():
		_edit_commands.remove_child(child)
		child.queue_free()
	_edit_feedback.text = state_message if not reset else ""
	_layout_room_panel()
	_room_memberships = _memberships(_snapshot())
	heading.text=title
	body.text=message
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	panel.show()
	host.set_zone_modal(true)
	if name_!="home" and not reset and not state_message.is_empty(): _label(state_message)

func _label(value: String) -> Label:
	var label := Label.new()
	label.text=value
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(label)
	return label

func _button(title: String,callback: Callable) -> Button:
	var button := Button.new()
	button.text=title
	button.custom_minimum_size.y=44
	button.pressed.connect(callback)
	fields.add_child(button)
	return button

func _spinner(title: String,low: float,high: float,value: float,step := 1.0) -> SpinBox:
	var row := HBoxContainer.new()
	fields.add_child(row)
	var caption := Label.new()
	caption.text=title
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.min_value=low
	spin.max_value=high
	spin.step=step
	spin.value=value
	row.add_child(spin)
	return spin

