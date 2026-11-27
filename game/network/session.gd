extends Node
## Local/native presence. The host alone chooses names, validates poses, and routes snapshots.
signal hockey_changed(state: Dictionary)
signal roster_changed
signal status_changed(message: String)
const SCOOTER_RIDER = preload("res://game/vehicles/scooter_rider.gd")
const AVATAR_CATALOG = preload("res://game/avatars/catalog.gd")
const DIVER_VIEW := preload("res://game/scuba/diver_presentation.gd")
const HOCKEY = preload("res://game/network/hockey_match.gd")
const PORT := 24861
const MAX_GUESTS := 11
const PERIOD := 0.09
var zone := "town"
var rows: Dictionary = {}
var roster: Array = []
var admitted := false
var hosting := false
var status := "Playing offline"
var _peer: ENetMultiplayerPeer
var _name := "Player"
var _invite := ""
var _address := "127.0.0.1"
var _port := PORT
var _bound: Node3D
var _player: CharacterBody3D
var _ghost_root: Node3D
var _ghosts := {}
var _panel: PanelContainer
var _summary: Label
var _inputs: Dictionary
var _entries := {}
var _pending := {}
var _denied := {}
var hockey = HOCKEY.new()
var hockey_state: Dictionary = {}
var _hockey_requested := false
var _elapsed := 0.0
var _join_deadline := 0
var _last_snapshot := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_lost)
	multiplayer.connected_to_server.connect(_client_connected)
	multiplayer.connection_failed.connect(_client_failed)
	multiplayer.server_disconnected.connect(_host_lost)


func bind_zone(zone_id: String, host: Node3D, player: CharacterBody3D, hud: CanvasLayer) -> void:
	if not _valid_zone(zone_id):
		return
	if zone == "arcade" and zone_id != "arcade":
		hockey_leave()
	zone = zone_id
	rows.clear()
	_bound = host
	_player = player
	_ghosts.clear()
	_ghost_root = Node3D.new()
	_ghost_root.name = "OnlineVisitors"
	host.add_child(_ghost_root)
	_build_menu(hud)
	_elapsed = PERIOD


func suspend_zone_for(host: Node3D) -> void:
	if _bound == host:
		suspend_zone()


func suspend_zone() -> void:
	if zone == "arcade":
		hockey_leave()
	zone = ""
	rows.clear()
	if is_instance_valid(_ghost_root):
		_ghost_root.queue_free()
	_ghost_root = null
	_ghosts.clear()
	_player = null
	_bound = null
	_panel = null
	_summary = null
	_elapsed = PERIOD


func host_session(alias: String, bind_ip: String = "127.0.0.1", port: int = PORT) -> bool:
	if _peer != null:
		_set_status("Leave the current session first.")
		return false
	if OS.has_feature("web"):
		_set_status("Local multiplayer is available in the native build.")
		return false
	if not _private_ip(bind_ip) or not IP.get_local_addresses().has(bind_ip) or not _valid_port(port):
		_set_status("Choose this computer’s private network IP and a valid port.")
		return false
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	if peer.create_server(port, MAX_GUESTS, 2) != OK:
		_set_status("Could not host. Check the address or try a different port.")
		return false
	_name = _clean_name(alias)
	_address = bind_ip
	_port = port
	_invite = Crypto.new().generate_random_bytes(6).hex_encode().to_upper()
	_peer = peer
	hosting = true
	admitted = true
	multiplayer.multiplayer_peer = peer
	_entries[1] = _new_entry(_name)
	_set_status("Hosting at %s:%d • code %s" % [_address, _port, _invite])
	return true


func join_session(alias: String, host_ip: String, code: String, port: int = PORT) -> bool:
	if _peer != null:
		_set_status("Leave the current session first.")
		return false
	if OS.has_feature("web"):
		_set_status("Local multiplayer is available in the native build.")
		return false
	code = code.strip_edges().to_upper()
	if not _private_ip(host_ip) or code.length() != 12 or not _valid_port(port):
		_set_status("Enter a private host IP, port, and the 12-character invite code.")
		return false
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(host_ip, port, 2) != OK:
		_set_status("Could not start connection.")
		return false
	_name = _clean_name(alias)
	_address = host_ip
	_port = port
	_invite = code
	_peer = peer
	_join_deadline = Time.get_ticks_msec() + 8000
	multiplayer.multiplayer_peer = peer
	_set_status("Connecting…")
	return true


func leave_session(message := "Playing offline") -> void:
	if _peer != null:
		_peer.close()
		multiplayer.multiplayer_peer = null
		_peer = null
	hosting = false
	admitted = false
	_join_deadline = 0
	_last_snapshot = 0
	_entries.clear()
	hockey = HOCKEY.new()
	_set_hockey({})
	_pending.clear()
	_denied.clear()
	_hockey_requested = false
	_receive_local([], [])
	_set_status(message)


func invite_code() -> String:
	return _invite if hosting else ""


func _private_ip(address: String) -> bool:
	if address == "127.0.0.1":
		return true
	if not address.is_valid_ip_address() or address.contains(":"):
		return false
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	var a := int(octets[0])
	var b := int(octets[1])
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


func _valid_port(port: int) -> bool:
	return port >= 1024 and port <= 65535


func _clean_name(alias: String) -> String:
	var cleaned := ""
	for ch: String in alias.substr(0, 32).strip_edges():
		if ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -_":
			cleaned += ch
		if cleaned.length() >= 18:
			break
	return cleaned.strip_edges() if not cleaned.strip_edges().is_empty() else "Player"


func _valid_zone(candidate: String) -> bool:
	if candidate.is_empty() or candidate.length() > 36:
		return false
	for ch: String in candidate:
		if not ch in "abcdefghijklmnopqrstuvwxyz0123456789-_:":
			return false
	return true


func _network_zone(candidate: String) -> bool:
	return candidate in ["town","beach","arcade","bank","vet","salon","store","cafe","library","reef"]


func _new_entry(alias: String) -> Dictionary:
	return {"alias":alias,"zone":"","position":Vector3.ZERO,"yaw":0.0,"moving":false,"grounded":true,"seen":Time.get_ticks_msec(),"pose_at":0}


func _peer_connected(id: int) -> void:
	if hosting and id != 1:
		_pending[id] = Time.get_ticks_msec() + 6000


func _peer_lost(id: int) -> void:
	hockey.leave(id)
	_entries.erase(id)
	_pending.erase(id)
	_denied.erase(id)


func _client_connected() -> void:
	if not hosting and _peer != null:
		_request_join.rpc_id(1, _name, _invite)


func _client_failed() -> void:
	leave_session("Connection failed. Open Multiplayer to try again.")


func _host_lost() -> void:
	leave_session("Host disconnected. Open Multiplayer to rejoin.")


@rpc("any_peer", "call_remote", "reliable")
func _request_join(alias: String, code: String) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _pending.has(id) or _denied.has(id):
		return
	_pending.erase(id)
	if code != _invite:
		_join_reply.rpc_id(id, false, "")
		# Give the reliable reply a moment to leave before disconnecting.
		_denied[id] = true
		_pending[id] = Time.get_ticks_msec() + 800
		return
	var chosen := _clean_name(alias)
	var used := {}
	for row: Dictionary in _entries.values():
		used[String(row.alias).to_lower()] = true
	var counter := 2
	var base := chosen
	while used.has(chosen.to_lower()):
		chosen = "%s %d" % [base.substr(0, 15), counter]
		counter += 1
	_entries[id] = _new_entry(chosen)
	_join_reply.rpc_id(id, true, chosen)


@rpc("authority", "call_remote", "reliable")
func _join_reply(accepted: bool, assigned_name: String) -> void:
	if hosting or _peer == null:
		return
	if not accepted:
		leave_session("That invite code didn’t match.")
		return
	_name = assigned_name
	_join_deadline = 0
	admitted = true
	_last_snapshot = Time.get_ticks_msec()
	_set_status("Joined as %s" % _name)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _pose(candidate: String, pos: Vector3, yaw: float, moving: bool, grounded: bool) -> void:
	if hosting:
		_apply_pose(multiplayer.get_remote_sender_id(), candidate, pos, yaw, moving, grounded)


func _apply_pose(id: int, candidate: String, pos: Vector3, yaw: float, moving: bool, grounded: bool) -> void:
	if not _entries.has(id) or (not candidate.is_empty() and not _network_zone(candidate)) or not pos.is_finite() or not is_finite(yaw):
		return
	if absf(pos.x) > 240 or absf(pos.z) > 240 or pos.y < (-22.0 if candidate == "reef" else -10.0) or pos.y > 25:
		return
	var now := Time.get_ticks_msec()
	var row: Dictionary = _entries[id]
	if now - int(row.pose_at) < 30:
		return
	if row.zone == "arcade" and candidate != "arcade":
		hockey.leave(id)
	row.merge({"zone":candidate,"position":pos,"yaw":wrapf(yaw,-PI,PI),"moving":moving,"grounded":grounded,"seen":now,"pose_at":now}, true)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot(visible: Array, online: Array) -> void:
	if admitted and not hosting:
		_last_snapshot = Time.get_ticks_msec()
		_receive_local(visible, online)


func _receive_local(visible: Array, online: Array) -> void:
	rows.clear()
	for row: Dictionary in visible:
		if row.zone == zone:
			rows[row.id] = row
	var changed := roster != online
	roster = online
	if changed:
		roster_changed.emit()
		_refresh_menu()


func _share(now: int) -> void:
	for id: int in _pending.keys():
		if now >= int(_pending[id]):
			_pending.erase(id)
			_denied.erase(id)
			_peer.disconnect_peer(id)
	for id: int in _entries.keys():
		if id != 1 and now - int(_entries[id].seen) > 12000:
			hockey.leave(id)
			_entries.erase(id)
			_peer.disconnect_peer(id)
	var public_roster: Array = []
	for row: Dictionary in _entries.values():
		var place := "In town"
		match String(row.zone):
			"beach": place = "At the beach"
			"reef": place = "At the reef"
			"arcade": place = "At the arcade"
			"town": pass
			"": place = "In another activity"
			_: place = "Indoors"
		public_roster.append({"alias":row.alias, "place":place})
	for viewer: int in _entries.keys():
		var visible: Array = []
		var viewer_zone: String = _entries[viewer].zone
		if not viewer_zone.is_empty():
			for id: int in _entries.keys():
				var row: Dictionary = _entries[id]
				if viewer != id and row.zone == viewer_zone:
					visible.append({"id":id,"alias":row.alias,"zone":row.zone,"position":row.position,"yaw":row.yaw,"moving":row.moving,"grounded":row.grounded})
		if hockey.side(viewer) >= 0:
			if viewer == 1:
				_set_hockey(hockey.state(viewer,_entries))
			else:
				_hockey_snapshot.rpc_id(viewer,hockey.state(viewer,_entries))
		if viewer == 1:
			_receive_local(visible, public_roster)
		else:
			_snapshot.rpc_id(viewer, visible, public_roster)


func _process(delta: float) -> void:
	if _peer == null:
		_draw_ghosts(delta)
		return
	var now := Time.get_ticks_msec()
	if _join_deadline != 0 and now > _join_deadline:
		leave_session("Host didn’t answer. Open Multiplayer to try again.")
		return
	if admitted and not hosting and now - _last_snapshot > 12000:
		leave_session("Connection timed out. Open Multiplayer to rejoin.")
		return
	if hosting:
		hockey.advance(delta)
	_elapsed += delta
	if _elapsed >= PERIOD:
		_elapsed = fmod(_elapsed, PERIOD)
		if admitted and is_instance_valid(_player) and _network_zone(zone):
			var p := _player.global_position
			var motion := _presence_motion()
			var y := motion.x
			var walk := motion.y > .0225
			if hosting:
				_apply_pose(1, zone, p, y, walk, _player.is_on_floor())
			else:
				_pose.rpc_id(1, zone, p, y, walk, _player.is_on_floor())
		elif admitted and not _network_zone(zone):
			if hosting:
				_apply_pose(1,"",Vector3.ZERO,0.0,false,true)
			else:
				_pose.rpc_id(1,"",Vector3.ZERO,0.0,false,true)
		if hosting:
			_share(now)
	_draw_ghosts(delta)


const PET_CATALOG = preload("res://game/pets/catalog.gd")
const PET_ACTORS = preload("res://game/pets/actors.gd")

func _presence_motion() -> Vector2:
	if zone == "reef" and is_instance_valid(_bound) and _bound.has_method("network_presence_motion"):
		return _bound.network_presence_motion()
	return Vector2(_player.rotation.y, Vector2(_player.velocity.x,_player.velocity.z).length_squared())


func _draw_ghosts(delta: float) -> void:
	if not is_instance_valid(_ghost_root) or not _ghost_root.is_inside_tree():
		return
	for id: int in _ghosts.keys():
		if not rows.has(id):
			_ghosts[id].node.queue_free()
			_ghosts.erase(id)
	for id: int in rows:
		var row: Dictionary = rows[id]
		var character := AVATAR_CATALOG.sanitize(row.get("character"))
		if _ghosts.has(id) and _ghosts[id].character != character:
			_ghosts[id].node.queue_free()
			_ghosts.erase(id)
		if not _ghosts.has(id):
			var root := Node3D.new()
			_ghost_root.add_child(root)
			root.global_position = row.position
			root.rotation.y = row.yaw
			var model := AVATAR_CATALOG.instantiate(character)
			root.add_child(model)
			model.rotation.y = PI
			model.scale = Vector3.ONE * (2.9 if zone == "beach" else 2.5)
			var label := Label3D.new()
			label.text = row.alias
			label.position.y = 2.12
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.pixel_size = 0.0065
			label.modulate = Color("#fff9c9")
			root.add_child(label)
			var animation := AVATAR_CATALOG.animator(model)
			if zone == "reef":
				model.rotation.y = 0.0 # Reef yaw already describes the +Z-facing avatar.
				animation = DIVER_VIEW.fit(model)
			_ghosts[id] = {"node":root,"model":model,"animation":animation,"character":character,"companion":null,"kind":""}
		var ghost: Node3D = _ghosts[id].node
		if ghost.global_position.distance_to(row.position) > 8.0:
			ghost.global_position = row.position
		else:
			ghost.global_position = ghost.global_position.lerp(row.position, 1.0 - exp(-18.0 * delta))
		ghost.rotation.y = lerp_angle(ghost.rotation.y, row.yaw, 1.0 - exp(-18.0 * delta))
		if zone == "reef":
			DIVER_VIEW.animate(_ghosts[id].animation, bool(row.moving))
			continue
		var active_kind: String = str(row.get("companionSpecies","")) if zone in ["town","beach"] and not row.get("vehicleSeat",false) else ""
		if active_kind not in PET_CATALOG.SPECIES: active_kind=""
		var view: Dictionary = _ghosts[id]
		if active_kind!=view.kind:
			view.kind=active_kind
			if is_instance_valid(view.companion): view.companion.queue_free()
			view.companion=null
			if not active_kind.is_empty():
				var companion := PET_ACTORS.new()
				ghost.add_child(companion)
				companion.configure(ghost,0)
				companion.synchronize({"owned":[{"id":"other","species":active_kind}],"activeId":"other"})
				view.companion=companion
		var animator: AnimationPlayer = _ghosts[id].animation
		var sitting: bool = row.get("rest") == "sit" and zone in ["bank","vet","salon","store","cafe","library"]
		var model: Node3D = view.model
		var scooter_id: String = row.get("scooterRide","") if zone=="town" else ""
		var standing := not scooter_id.is_empty()
		var scooter: Node3D = _bound.scooter_for_peer(scooter_id) if standing and is_instance_valid(_bound) and _bound.has_method("scooter_for_peer") else null
		model.rotation.y = 0.0 if sitting else PI
		if not standing:
			if model.has_meta(SCOOTER_RIDER.ACTIVE):
				animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
			SCOOTER_RIDER.clear(model)
			model.position = Vector3(0,-.02625*model.scale.y,.02875*model.scale.z) if sitting else Vector3.ZERO
		var clip := "idle" if standing else ("sit" if sitting or row.get("vehicleSeat",false) else ("fall" if not row.grounded else ("walk" if row.moving else "idle")))
		if animator.current_animation != clip and animator.has_animation(clip):
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animator.play(clip, 0.0 if standing else .1)
		if standing:
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			if not model.has_meta(SCOOTER_RIDER.ACTIVE):
				animator.advance(0.0)
			if is_instance_valid(scooter):
				model.rotation.y = wrapf(PI+scooter.rotation.y-ghost.rotation.y,-PI,PI)
				SCOOTER_RIDER.present(model,scooter.to_global(SCOOTER_RIDER.STAND))
			else:
				var footprint := ghost.global_position
				footprint.y = SCOOTER_RIDER.BODY_WORLD_Y+SCOOTER_RIDER.STAND.y
				SCOOTER_RIDER.present(model,footprint+Vector3(0,0,SCOOTER_RIDER.STAND.z).rotated(Vector3.UP,ghost.rotation.y))


func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)
	_refresh_menu()


func _build_menu(hud: CanvasLayer) -> void:
	var open_button := Button.new()
	open_button.text = "Multiplayer (M)"
	open_button.focus_mode = Control.FOCUS_NONE
	hud.add_child(open_button)
	open_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 14)
	open_button.pressed.connect(func(): _toggle_menu(true))
	_panel = PanelContainer.new()
	hud.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.position -= Vector2(140,145)
	_panel.custom_minimum_size = Vector2(280, 0)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_summary = Label.new()
	_summary.custom_minimum_size.x = 280
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)
	_inputs = {}
	for spec: Array in [["alias", "Nickname (not your real name)", _name],["ip", "Private IP", _address],["port", "Port", str(_port)],["code", "Invite code (for joining)", "" if hosting else _invite]]:
		var field := LineEdit.new()
		field.placeholder_text = spec[1]
		field.text = spec[2]
		field.max_length = 32
		column.add_child(field)
		_inputs[spec[0]] = field
	var hint := Label.new()
	hint.custom_minimum_size.x = 280
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Use 127.0.0.1 for two windows on this computer. For LAN, enter the host’s private IP. Trusted networks only; no chat."
	column.add_child(hint)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_add_button(buttons,"Host",func(): host_session(_inputs.alias.text,_inputs.ip.text.strip_edges(),_inputs.port.text.to_int()))
	_add_button(buttons,"Join",func(): join_session(_inputs.alias.text,_inputs.ip.text.strip_edges(),_inputs.code.text,_inputs.port.text.to_int()))
	_add_button(buttons,"Leave",func(): leave_session())
	_add_button(buttons,"Close",func(): _toggle_menu(false))
	_refresh_menu()
	_panel.hide()


func _add_button(parent: Control, label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 40
	parent.add_child(button)
	button.pressed.connect(action)


func _toggle_menu(value: bool) -> void:
	if not is_instance_valid(_panel):
		return
	if value and is_instance_valid(_bound) and _bound.has_method("can_open_network_menu") and not _bound.call("can_open_network_menu"):
		return
	_panel.visible = value
	if is_instance_valid(_bound) and _bound.has_method("set_zone_modal"):
		_bound.call("set_zone_modal", value)
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_menu()


func _refresh_menu() -> void:
	if not is_instance_valid(_summary):
		return
	var names: Array[String] = []
	for row: Dictionary in roster:
		names.append("%s (%s)" % [row.alias, row.place])
	_summary.text = status + ("\nOnline: " + ", ".join(names) if not names.is_empty() else "")
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not is_instance_valid(_panel):
		return
	if _panel.visible and event.physical_keycode == KEY_ESCAPE:
		_toggle_menu(false)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_M:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return # Preserve ordinary typing, even in the Multiplayer dialog.
		var was_open := _panel.visible
		_toggle_menu(not was_open)
		if _panel.visible != was_open:
			get_viewport().set_input_as_handled()

func hockey_join() -> bool:
	if not admitted or zone != "arcade":
		return false
	if hosting:
		if is_instance_valid(_player):
			_entries[1].zone = zone
			_entries[1].position = _player.global_position
		_hockey_requested = _hockey_command(1,"join")
		return _hockey_requested
	_hockey_requested = true
	_hockey_action.rpc_id(1,"join")
	return true


func hockey_leave() -> void:
	var was_requested := _hockey_requested
	_hockey_requested = false
	if admitted and was_requested:
		if hosting:
			_hockey_command(1,"leave")
		else:
			_hockey_action.rpc_id(1,"leave")
	_set_hockey({})


func hockey_rematch() -> void:
	if admitted:
		if hosting:
			_hockey_command(1,"rematch")
		else:
			_hockey_action.rpc_id(1,"rematch")


func hockey_input(target: Vector2) -> void:
	if not admitted or hockey_state.is_empty() or not target.is_finite():
		return
	if hosting:
		hockey.aim(1,target,Time.get_ticks_msec())
	else:
		_hockey_target.rpc_id(1,target)


@rpc("any_peer", "call_remote", "reliable")
func _hockey_action(action: String) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if not _hockey_command(id,action) and _entries.has(id):
		_hockey_error.rpc_id(id,"Walk closer to the air hockey table, or try again once a seat opens.")


func _hockey_command(id: int, action: String) -> bool:
	if not _entries.has(id):
		return false
	if action == "leave":
		hockey.leave(id)
		return true
	if _entries[id].zone != "arcade":
		return false
	match action:
		"join":
			var pos: Vector3 = _entries[id].position
			if Vector2(pos.x,pos.z).distance_to(Vector2(0.0,2.3)) > 1.9 or absf(pos.y) > 2.0:
				return false
			return hockey.join(id)
		"rematch":
			hockey.rematch(id)
			return true
		_: return false


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _hockey_target(target: Vector2) -> void:
	if hosting:
		hockey.aim(multiplayer.get_remote_sender_id(),target,Time.get_ticks_msec())


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _hockey_snapshot(state: Dictionary) -> void:
	if admitted and _hockey_requested and zone == "arcade":
		_set_hockey(state)


@rpc("authority", "call_remote", "reliable")
func _hockey_error(error: String) -> void:
	if _hockey_requested:
		_hockey_requested = false
		_set_hockey({"error":error})


func _set_hockey(state: Dictionary) -> void:
	hockey_state = state
	hockey_changed.emit(state)
