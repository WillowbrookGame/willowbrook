extends "res://game/network/browser/browser_session.gd"
## Isolated account-backed browser preview. Guest/canonical browser build retains its original adapter.
const SESSION_KEY := "willowbrook-account-preview-session"
const TOWN_HUD_FIT = preload("res://game/hud_fit.gd")
const TOWN_SCENE := "res://game/town.tscn"
const HUNT = preload("res://game/scavenger/client.gd")
signal class_result(ok: bool, message: String)
var _class_state: Dictionary = {}
var _bank_request: Dictionary = {}
var _class_request: Dictionary = {}
var _neighbor_state: Dictionary = {}
var _neighbor_request: Dictionary = {}
var _neighbor_ui: JavaScriptObject
var _neighbor_toggle_cb: JavaScriptObject
var _neighbor_action_cb: JavaScriptObject
var _neighbor_modal_owner: Node3D
var _neighbor_open:=false
var _neighbor_retry_at := 0
signal yard_public_changed
signal yard_result(ok: bool, text: String)
var _yard: Dictionary = {}
var _yard_public: Array = []
var _yard_retry: Dictionary = {}
var _yard_until := 0
signal furniture_snapshot_changed
signal furniture_result(ok: bool, message: String)
var _furniture: Dictionary = {}
var _furniture_retry: Dictionary = {}
var _furniture_waiting_until := 0
signal home_visit_notice(message: Dictionary)
var _home_visits := false
signal pet_snapshot_changed
signal bank_result(message: String)
signal vehicle_result(message: String)
var _vehicle_offer: Dictionary = {}
var _vehicle_request: Dictionary = {}
var _vehicle_sent_at := 0
signal pet_result(action: String, operation: String, ok: bool, message: String)
var _pet_store: Dictionary = {}
var _owned_home: Dictionary = {}
var _mortgage: Dictionary = {}
var _home_plots: Array = []
var _bank_eligible := false
var _has_pet_service := false
var _pet_retry: Dictionary = {}
var _auth: Dictionary = {}
var _login_panel: Control
var _arena_chat_host: Node3D
var _family_chat: JavaScriptObject
var _chat_send_cb: JavaScriptObject
var _chat_toggle_cb: JavaScriptObject
var _chat_modal_owner: Node3D
var _chat_over_cabinet := false
var _chat_available := false
var _character := AVATAR_CATALOG.DEFAULT
var _html_gate: JavaScriptObject
var _html_gate_open := false
var _auto_resume_active := false
const RECONNECT_DELAYS := [500, 1000, 2000, 4000]
var _reconnect_attempt := -1
var _reconnect_at := 0
var _html_submit_cb: JavaScriptObject
var _html_resume_cb: JavaScriptObject
var _html_cancel_cb: JavaScriptObject
var _login_status: Label
var _username: LineEdit
var _password: LineEdit
var _login_button: Button
var _retry_login_button: Button
var _cancel_login_button: Button
var _star_badge: Label
var _garden_notice: Label
var _garden_notice_until := 0
var _login_layer: CanvasLayer
signal fishing_reply(message: Dictionary)
signal reef_photos_reply(message: Dictionary)
var _fishing_state: Dictionary = {}
var _reef_photos: Array = []
var _fishing_world: Dictionary = {}
var _town_home_exteriors: Array = []
var _fishing_clock := 0.0
var _stars := 0
var _job_state: Dictionary = {}
var _starter_wait_until: Dictionary = {}
var _hunt_state: Dictionary = {}
var _hunt_rows: Array = []
var _hunt_view: Node
var _employer_panel: PanelContainer
var _garden_until := 0.0
var _garden_pending_until := 0

signal paintball_packet(packet: Dictionary)
signal paintball_capability_changed
var _paintball_available := false
var _paintball_epoch := ""
var _paintball_resume_wait := 0
const PAINTBALL_SCENE := "res://game/arena.tscn"

func can_show_paintball_lobby() -> bool:
	return admitted and _paintball_available and zone=="town"

func paintball_epoch() -> String:
	return _paintball_epoch

func paintball_lobby(action: String, ready := false) -> bool:
	if not admitted or zone!="town": return false
	if action in ["join","ready"] and not can_show_paintball_lobby(): return false
	_send_pose()
	var packet := {"type":"paintballLobby","action":action}
	if action=="ready":packet.ready=ready
	return _send_packet(packet)

func paintball_match(action: String, epoch: String, frame: Dictionary = {}) -> bool:
	if not admitted or _paintball_epoch.is_empty() or epoch!=_paintball_epoch:return false
	var packet := {"type":"paintballMatch","action":action,"epoch":epoch}
	if action=="input":packet.frame=frame
	return _send_packet(packet)

func forget_paintball_view(epoch: String) -> void:
	if epoch==_paintball_epoch:
		_paintball_epoch=""
		_paintball_resume_wait=0

func _enter_private_paintball(epoch: String) -> void:
	if not admitted:return
	_paintball_resume_wait=0
	var tree:=get_tree()
	if tree.current_scene!=null and String(tree.current_scene.scene_file_path)==PAINTBALL_SCENE and _paintball_epoch==epoch:
		return
	_paintball_epoch=epoch
	tree.set_meta("paintball_online",true)
	if tree.change_scene_to_file(PAINTBALL_SCENE)!=OK:
		tree.remove_meta("paintball_online")
		paintball_match("leave",epoch)
		forget_paintball_view(epoch)
		_set_status("Could not load the private arena.")

const HIDE_ZONES := ["town","bank","vet","salon","store","cafe","library","arcade"]
var _hide_enabled := false
var _hide_state: Dictionary = {}
var _hide_hint_until := 0
var _hide_hint_zone := ""
var _hide_hint_pose := Vector3.ZERO
var _hide_host: Node
var _hide_bridge: JavaScriptObject
var _hide_callback: JavaScriptObject
var _hide_view_key := ""
var _hide_lock_host: Node
var _hide_invite_id := ""

func _hide_sync_lock() -> void:
	var host: Node = _bound if admitted and _hide_enabled and zone in HIDE_ZONES and _hide_state.get("phase") == "hide" and _hide_state.get("role") == "seeker" and is_instance_valid(_bound) else null
	if host != _hide_lock_host:
		if is_instance_valid(_hide_lock_host) and _hide_lock_host.has_method("hide_seek_lock"):
			_hide_lock_host.hide_seek_lock(false)
		_hide_lock_host = host
		if is_instance_valid(host) and host.has_method("hide_seek_lock"):
			host.hide_seek_lock(true)
	if _hide_bridge != null:
		_hide_bridge.blackout(is_instance_valid(host))

func _hide_command(args: Array) -> void:
	if args.size() != 1 or not admitted or not _hide_enabled:
		return
	var action := str(args[0])
	if action in ["accept","decline"]:
		if _hide_invite_id.is_empty():
			return
		if not _send_packet({"type":"hideSeek","action":action,"inviteId":_hide_invite_id}) and _hide_bridge != null:
			_hide_bridge.inviteFeedback("Not connected. Try again.")
		return
	if action not in ["join","leave","start"] or (zone not in HIDE_ZONES and action != "leave"):
		return
	if not _send_packet({"type":"hideSeek","action":action}) and _hide_bridge != null:
		_hide_bridge.feedback("Not connected. Try again.")

func _hide_render() -> void:
	if _hide_bridge == null or not OS.has_feature("web"):
		return
	var eligible := admitted and _hide_enabled and zone in HIDE_ZONES
	var can_launch := eligible and zone == "town"
	var membership_visible := admitted and _hide_enabled and not _hide_state.is_empty()
	var key := str([can_launch, membership_visible, eligible, _hide_state.get("phase"), _hide_state.get("role"), _hide_state.get("host"), _hide_state.get("memberCount"), _hide_state.get("found"), _hide_state.get("remaining"), _hide_state.get("result")])
	if key != _hide_view_key:
		_hide_view_key = key
		_hide_bridge.context(can_launch,membership_visible,eligible)
	_hide_bridge.update(JSON.stringify(_hide_state) if membership_visible else "{}")

func _hide_receive(snapshot: Variant) -> void:
	_hide_state = snapshot if snapshot is Dictionary else {}
	_hide_sync_lock()
	_hide_hint_until = 0
	if _hide_state.get("tagEligible") == true and is_instance_valid(_bound) and is_instance_valid(_player):
		_hide_host = _bound
		_hide_hint_zone = zone
		_hide_hint_pose = _player.global_position
		_hide_hint_until = Time.get_ticks_msec()+450
	_hide_render()

func hide_seek_can_tag(host: Node) -> bool:
	return admitted and _hide_enabled and zone in HIDE_ZONES and host == _bound and host == _hide_host and zone == _hide_hint_zone and _hide_state.get("phase") == "seek" and _hide_state.get("role") == "seeker" and Time.get_ticks_msec() < _hide_hint_until and is_instance_valid(_player) and _player.is_on_floor() and _player.global_position.distance_to(_hide_hint_pose) < 0.9

func hide_seek_tag(host: Node) -> void:
	if not hide_seek_can_tag(host):
		return
	_hide_hint_until = 0
	_send_pose()
	if not _send_packet({"type":"hideSeek","action":"tag"}) and _hide_bridge != null:
		_hide_bridge.feedback("Not connected. Try again.")

func _ready() -> void:
	if OS.has_feature("web"):
		_hide_bridge = JavaScriptBridge.get_interface("WillowbrookHideSeek")
		if _hide_bridge != null:
			_hide_callback = JavaScriptBridge.create_callback(_hide_command)
			_hide_bridge.bind(_hide_callback)
		call_deferred("_resume_if_possible")

func _resume_if_possible() -> void:
	var token := _read_token()
	if not token.is_empty() and not admitted and _web == null:
		_auto_resume_active = true
		_begin_login({"type":"resume","session":token})

func _read_token() -> String:
	var data: Variant = JavaScriptBridge.eval("try { sessionStorage.getItem('%s') || '' } catch { '' }" % SESSION_KEY, true)
	return String(data) if data is String else ""

func _store_token(token: String) -> void:
	if OS.has_feature("web"):
		var key := JSON.stringify(SESSION_KEY)
		var data := JSON.stringify(token)
		JavaScriptBridge.eval("try { if (%s) sessionStorage.setItem(%s,%s); else sessionStorage.removeItem(%s) } catch {}" % [data,key,data,key], true)

func _begin_login(packet: Dictionary) -> void:
	if _web != null or not OS.has_feature("web"):
		return
	var socket := WebSocketPeer.new()
	socket.inbound_buffer_size = 1048576
	socket.outbound_buffer_size = 32768
	if socket.connect_to_url(_browser_endpoint()) != OK:
		_auto_resume_active = false
		if _reconnect_attempt >= 0:
			_schedule_reconnect()
		else:
			_set_status("Could not connect to the local server.")
		return
	_auth = packet.duplicate()
	_web = socket
	_join_sent = false
	_hello_deadline = Time.get_ticks_msec() + (4000 if _reconnect_attempt >= 0 else 8000)
	if _reconnect_attempt < 0:
		_set_status("Signing in…")

func _submit_login() -> void:
	if admitted or _web != null or not is_instance_valid(_username) or not is_instance_valid(_password):
		return
	if _username.text.strip_edges().is_empty() or _password.text.is_empty():
		_set_status("Enter your test username and password.")
		return
	_begin_login({"type":"login","username":_username.text.strip_edges(),"password":_password.text})
	_password.clear()
	_password.release_focus()

func _cancel_login() -> void:
	if not admitted and (_web != null or _reconnect_attempt >= 0):
		_web_leave("Connection canceled. Sign in when ready.")


func _sign_out() -> void:
	_store_token("")
	_send_packet({"type":"logout"})
	if _web != null:
		_web.poll()
	_web_leave("Signed out. Sign in to play.")
	
func _web_leave(message: String) -> void:
	_hide_enabled = false
	_hide_invite_id = ""
	if _hide_bridge != null:
		_hide_bridge.clearInvite()
	_hide_receive(null)
	_paintball_available=false
	_paintball_epoch=""
	_paintball_resume_wait=0
	_home_visits=false
	_neighbor_toggle([false])
	_neighbor_state.clear()
	_neighbor_request.clear()
	_neighbor_retry_at=0
	if _neighbor_ui!=null:
		_neighbor_ui.setContext(false,false)
		_neighbor_ui.setPending(false,false)
		_neighbor_ui.feedback("")
	_bank_request.clear()
	_vehicle_offer.clear()
	_vehicle_request.clear()
	_vehicle_sent_at = 0
	_class_state.clear()
	_class_request.clear()
	_character = AVATAR_CATALOG.DEFAULT
	var reset_world := admitted or _reconnect_attempt >= 0
	_reconnect_attempt = -1
	_reconnect_at = 0
	_has_pet_service = false
	_pet_retry.clear()
	_pet_store.clear()
	_furniture.clear()
	_yard.clear()
	_yard_public.clear()
	_yard_retry.clear()
	_yard_until = 0
	yard_public_changed.emit()
	furniture_snapshot_changed.emit()
	_furniture_retry.clear()
	_furniture_waiting_until = 0
	_owned_home.clear()
	_mortgage.clear()
	_home_plots.clear()
	_bank_eligible = false
	pet_snapshot_changed.emit()
	_chat_available = false
	_sync_family_chat()
	_auto_resume_active = false
	_auth.clear()
	_garden_pending_until = 0
	_garden_until = 0.0
	_stars = 0
	_fishing_state.clear()
	_reef_photos.clear()
	_fishing_world.clear()
	_town_home_exteriors.clear()
	_job_state.clear()
	_starter_wait_until.clear()
	_hunt_state.clear()
	_hunt_rows.clear()
	_sync_hunt()
	close_employer()
	super._web_leave(message)
	if is_instance_valid(_panel):
		_panel.hide()
	_sync_gate()
	if reset_world:
		call_deferred("_forget_local_world")

func _forget_local_world() -> void:
	var tree := get_tree()
	for key in ["willowbrook_profile","room_destination","room_plot","town_room_return","paintball_town_return"]:
		if tree.has_meta(key):
			tree.remove_meta(key)
	tree.change_scene_to_file(TOWN_SCENE)

func _schedule_reconnect() -> void:
	_retire_current_web()
	_auth.clear()
	_join_sent = false
	_hello_deadline = 0
	if _reconnect_attempt >= RECONNECT_DELAYS.size() or _read_token().is_empty():
		_web_leave("Couldn't reconnect. Choose Retry session or sign in again.")
		return
	if admitted:
		admitted = false
		_hide_invite_id = ""
		if _hide_bridge != null:
			_hide_bridge.clearInvite()
		_hide_receive(null)
		_elapsed = 0.0
		_receive_local([],[])
		_sync_family_chat()
		_neighbor_context()
		_sync_gate()
	_reconnect_at = Time.get_ticks_msec() + int(RECONNECT_DELAYS[_reconnect_attempt])
	_set_status("Connection lost. Reconnecting... (%d of %d)" % [_reconnect_attempt + 1, RECONNECT_DELAYS.size()])

func _transport_lost(code: int) -> void:
	# Explicit sign-out, suspension and replaced sessions must not reconnect.
	if code == 1008:
		_store_token("")
		_web_leave("This play session ended. Sign in to continue.")
	elif code == 1000:
		_web_leave("Disconnected. Sign in again when ready.")
	elif admitted or _reconnect_attempt >= 0:
		_reconnect_attempt = maxi(0,_reconnect_attempt)
		_schedule_reconnect()
	else:
		_web_leave("Local multiplayer unavailable. Try signing in again.")

func _process(delta: float) -> void:
	_poll_retired_web()
	if _web != null:
		_web.poll()
		match _web.get_ready_state():
			WebSocketPeer.STATE_CLOSED:
				var closed := _web
				var code := closed.get_close_code()
				_poll_browser_messages()
				if _web == closed:
					_transport_lost(code)
			WebSocketPeer.STATE_OPEN:
				if not _join_sent and not _auth.is_empty():
					_join_sent = _send_packet(_auth)
					if _join_sent:
						_auth.clear()
				_poll_browser_messages()
	var now := Time.get_ticks_msec()
	if _neighbor_retry_at>0 and now>=_neighbor_retry_at:
		_neighbor_retry_at=0
		if _neighbor_ui!=null and not _neighbor_request.is_empty():
			_neighbor_ui.setPending(true,false)
			_neighbor_ui.feedback("No acknowledgment yet. Retry the same quest action.")
	if is_instance_valid(_garden_notice):
		var town_modal := zone == "town" and is_instance_valid(_bound) and bool(_bound.get("zone_modal"))
		_garden_notice.visible = now <= _garden_notice_until and not town_modal
	if _hello_deadline > 0 and now > _hello_deadline:
		if _reconnect_attempt >= 0:
			_schedule_reconnect()
		else:
			_web_leave("The local server didn't answer.")
	elif admitted and now - _world_at > 12000:
		_transport_lost(-1)
	if _web == null and _reconnect_at > 0 and now >= _reconnect_at:
		_reconnect_at = 0
		_reconnect_attempt += 1
		var session := _read_token()
		if session.is_empty():
			_web_leave("This play session ended. Sign in to continue.")
		else:
			_begin_login({"type":"resume","session":session})
	if admitted:
		_elapsed += delta
		if _elapsed >= PERIOD:
			_elapsed = fmod(_elapsed,PERIOD)
			_send_pose()
	_draw_ghosts(delta)
	if _hide_enabled and not admitted:
		_hide_render()
	if _paintball_resume_wait>0 and now>_paintball_resume_wait:
		var lost_epoch:=_paintball_epoch
		forget_paintball_view(lost_epoch)
		paintball_packet.emit({"type":"paintballMatch","action":"ended","ok":true,"returnTown":true,"text":"Your private match could not resume."})
	if _garden_pending_until > 0 and now > _garden_pending_until:
		_garden_pending_until = 0
		_garden_feedback("The garden didn't respond. Try again.")

func _on_web_message(message: Dictionary) -> void:
	match String(message.get("type","")):
		"welcome":
			if admitted or not _join_sent:
				return
			var token := String(message.get("session",""))
			if token.is_empty() or not message.get("progress") is Dictionary:
				_store_token("")
				_web_leave("This server is not the account playtest.")
				return
			var return_to_town := _reconnect_attempt >= 0 and not _network_zone(zone)
			_reconnect_attempt = -1
			_reconnect_at = 0
			_auto_resume_active = false
			_store_token(token)
			_hide_enabled = message.get("hideSeekEnabled") == true
			_home_visits = message.get("homeVisits") == true
			_character = AVATAR_CATALOG.sanitize(message.get("character"))
			if is_instance_valid(_bound) and zone == "town" and _bound.has_method("_apply_player_avatar"):
				_bound._apply_player_avatar(_character)
			_update_progress(message.progress)
			super._on_web_message(message)
			if message.get("type") == "welcome": pet_snapshot_changed.emit()
			_sync_hunt(message.progress.get("serverTime"))
			_neighbor_context()
			_chat_available = message.get("chatEnabled",false)
			_sync_gate()
			_sync_family_chat()
			if return_to_town and not _paintball_epoch.is_empty():
				_paintball_resume_wait=Time.get_ticks_msec()+3500
			elif return_to_town:
				_set_status("Reconnected. Restart private activities from Town.")
				call_deferred("_forget_local_world")
		"hideSeekInvite":
			if admitted and _hide_enabled and _hide_bridge != null and message.id != _hide_invite_id:
				_hide_invite_id = message.id
				_hide_bridge.invite(message.id,message.host,int(message.get("remainingMs",60000)))
		"hideSeekInviteClosed":
			if message.id == _hide_invite_id:
				_hide_invite_id = ""
				if _hide_bridge != null:
					_hide_bridge.clearInvite()
		"hideSeek":
			if admitted and _hide_enabled:
				_hide_receive(message.get("state"))
				if message.action in ["accept","decline","join"] and _hide_bridge != null and (message.action == "join" or message.get("inviteId",_hide_invite_id) == _hide_invite_id):
					if message.ok:
						_hide_bridge.clearInvite()
					elif message.action == "accept":
						_hide_bridge.inviteFeedback(message.get("error","Couldn't join."))
				if _hide_bridge != null and message.has("error"):
					_hide_bridge.feedback(message.error)
				elif _hide_bridge != null and message.get("found") == true:
					_hide_bridge.feedback("Found someone!")
		"paintballCapability":
			if admitted and _paintball_available!=message.available:
				_paintball_available=message.available
				paintball_capability_changed.emit()
		"paintballLobby","paintballMatch":
			if not admitted:return
			if message.type=="paintballMatch" and message.action=="enter" and message.ok:
				_enter_private_paintball(message.epoch)
			paintball_packet.emit(message)
		"chat":
			if admitted and _chat_available and _family_chat != null:
				_family_chat.receive(message.from,message.text)
		"chatStatus":
			_chat_available = admitted and bool(message.available)
			_sync_family_chat()
		"chatError":
			if admitted and _chat_available and _family_chat != null:
				_family_chat.feedback(message.text,false)
		"homeVisit":
			if admitted and _home_visits:
				if message.get("action")=="eject" and is_instance_valid(_bound) and _bound.is_inside_tree() and _bound.has_method("visit_ejected"):
					_bound.call_deferred("visit_ejected")
				home_visit_notice.emit(message)
		"world":
			if admitted and _hide_enabled:
				_hide_receive(message.get("hideSeek"))
			if admitted and message.get("zone")=="town":
				_town_home_exteriors = message.get("homeExteriors",[])
			if message.get("zone") == "town" and message.get("yards") is Array and message.yards != _yard_public:
				_yard_public = message.yards
				yard_public_changed.emit()
			if message.get("zone") == "beach" and message.has("fishPopulation"):
				_fishing_world = message
				_sync_fishing_clock(message)
			elif message.get("zone") != "beach":
				_fishing_world.clear()
			if message.has("chatEnabled") and message.get("zone") == zone:
				var available: bool = admitted and bool(message.chatEnabled)
				if _chat_available != available:
					_chat_available = available
					_sync_family_chat()
			super._on_web_message(message)
			if _home_visits and zone.begins_with("home:") and message.get("homeScene") is Dictionary and is_instance_valid(_bound) and _bound.is_inside_tree():
				var scene: Dictionary = message.homeScene
				var visible: Array = []
				for row: Dictionary in scene.visitors:
					visible.append({"id":int(row.id),"alias":str(row.alias),"zone":zone,"position":Vector3(row.x,row.y,row.z),"yaw":float(row.yaw),"moving":row.moving,"grounded":row.grounded,"character":AVATAR_CATALOG.sanitize(row.character)})
				_receive_local(visible,message.get("presence",[]))
				if _bound.has_method("apply_home_scene"):
					_bound.apply_home_scene(scene)
			if message.get("type") == "welcome": pet_snapshot_changed.emit()
		"progress":
			if not admitted:
				return
			_update_progress(message)
			if message.get("action")=="neighborQuest" and not _neighbor_request.is_empty() and message.get("requestId")==_neighbor_request.get("requestId"):
				_neighbor_request.clear()
				_neighbor_retry_at=0
				if _neighbor_ui!=null:
					_neighbor_ui.setPending(false,false)
					_neighbor_ui.feedback(str(message.get("text","")))
			if message.get("action")=="classes" and not _class_request.is_empty() and message.get("requestId")==_class_request.get("requestId"):
				_class_request.clear()
				class_result.emit(bool(message.get("ok",false)),str(message.get("error",message.get("text",""))))
			if message.get("action") == "vehicles" and not _vehicle_request.is_empty() and message.get("requestId")==_vehicle_request.get("requestId"):
				_vehicle_request.clear()
				_vehicle_sent_at = 0
				vehicle_result.emit(str(message.get("error",message.get("text",""))))
			if message.get("action") == "fishing":
				fishing_reply.emit(message)
			if message.get("action") == "reefPhotos":
				reef_photos_reply.emit(message)
			if message.get("action") == "yard" and message.get("requestId") == _yard_retry.get("id"):
				_yard_retry.clear()
				_yard_until = 0
				yard_result.emit(bool(message.get("ok",false)),str(message.get("error",message.get("text",""))))
			if message.get("action") == "furniture" and not _furniture_retry.is_empty() and message.get("requestId") == _furniture_retry.get("requestId"):
				_furniture_waiting_until = 0
				_furniture_retry.clear()
				furniture_result.emit(bool(message.get("ok",false)),str(message.get("error",message.get("text",""))))
			if message.get("action") in ["pets","housing"]:
				var operation: String = message.get("operation","")
				if message.action=="housing" and operation in ["repay","upgrade"]:
					if not _bank_request.is_empty() and message.get("requestId")==_bank_request.get("requestId"):
						_bank_request.clear()
						bank_result.emit(str(message.get("error",message.get("text",""))))
				else:
					if _pet_retry.get("operation")==operation: _pet_retry.clear()
					pet_result.emit(str(message.action),operation,bool(message.get("ok",false)),str(message.get("error",message.get("text",""))))
			if message.get("action") == "scavenger":
				_activity_feedback(String(message.get("error",message.get("text",""))))
			if message.get("action") == "jobs":
				_activity_feedback(String(message.get("error",message.get("text",""))))
			if message.get("action") == "tendGarden":
				_garden_pending_until = 0
				_garden_feedback("Garden watered! +2 stars. Total: %s." % _stars if message.get("ok") == true else String(message.get("error","The garden isn't ready.")))
		"denied":
			_store_token("")
			super._on_web_message(message)
			if message.get("type") == "welcome": pet_snapshot_changed.emit()
		"scavengerLeaderboard":
			if not admitted:
				return
			_hunt_rows = message.get("rows",[])
			_sync_hunt()
		_:
			super._on_web_message(message)
			if message.get("type") == "welcome": pet_snapshot_changed.emit()

func home_visits_available() -> bool:
	return admitted and _home_visits

func home_visit_command(action: String, value: Variant = null) -> bool:
	if not home_visits_available(): return false
	match action:
		"enter":
			if zone!="town" or not is_instance_valid(_player) or not _player.is_on_floor(): return false
			_send_pose()
			return _send_packet({"type":"homeVisit","action":"enter","plot":int(value)})
		"lock":
			if not zone.begins_with("home:"): return false
			return _send_packet({"type":"homeVisit","action":"lock","locked":bool(value)})
		"leave": return _send_packet({"type":"homeVisit","action":"leave"})
	return false

func _send_pose() -> void:
	super._send_pose()
	if home_visits_available() and zone.begins_with("home:") and is_instance_valid(_player) and _player.is_inside_tree():
		var location := _player.global_position
		_send_packet({"type":"homeVisit","action":"pose","x":location.x,"y":location.y,"z":location.z,"yaw":wrapf(_player.rotation.y,-PI,PI),"moving":_player.velocity.length_squared()>.0225,"grounded":_player.is_on_floor()})
	if furniture_available() and zone == "home:%s" % str(int(_owned_home.get("plot",-1))) and is_instance_valid(_player) and _player.is_inside_tree():
		var at := _player.global_position
		_send_packet({"type":"progress","action":"furniture","operation":"pose","x":at.x,"y":at.y,"z":at.z})

func yard_eligible() -> bool:
	return admitted and bool(_yard.get("eligible",false))

func yard_flags() -> Dictionary:
	return _yard.get("flags",{})

func yard_exterior() -> Array:
	return _yard_public

func yard_waiting() -> bool:
	return _yard_until > Time.get_ticks_msec()

func buy_yard(kind: String) -> bool:
	if not yard_eligible() or (zone!="town" and not zone.begins_with("home:")) or yard_waiting():
		return false
	if _yard_retry.get("kind") != kind:
		_yard_retry = {"kind":kind,"id":Crypto.new().generate_random_bytes(16).hex_encode()}
	_send_pose()
	if not _send_packet({"type":"progress","action":"yard","operation":"buy","kind":kind,"requestId":_yard_retry.id}):
		return false
	_yard_until = Time.get_ticks_msec()+5000
	return true

func furniture_available() -> bool:
	return admitted and not _furniture.is_empty() and not _owned_home.is_empty()

func furniture_rows() -> Array:
	var result: Array = _furniture.get("stock",[]).duplicate(true)
	for row: Dictionary in _furniture.get("placed",[]).duplicate(true):
		if row.get("supportId")==null:
			row.erase("supportId")
			row.erase("surfaceId")
		result.append(row)
	return result

func furniture_deliveries() -> Array:
	var deliveries: Array = _furniture.get("deliveries",[]).duplicate(true)
	for row: Dictionary in deliveries:
		row.quantity = int(row.quantity)
	return deliveries

func furniture_waiting() -> bool:
	return _furniture_waiting_until > Time.get_ticks_msec()

func furniture_command(operation: String, args: Dictionary) -> bool:
	var right_zone := (zone == "store" if operation in ["buy","sell"] else zone == "town" if operation=="pickup" else zone.begins_with("home:"))
	if not furniture_available() or not right_zone or furniture_waiting():
		return false
	_send_pose()
	var body := {"type":"progress","action":"furniture","operation":operation}
	body.merge(args)
	if _furniture_retry.get("body") != body:
		_furniture_retry = {"body":body.duplicate(true),"requestId":Crypto.new().generate_random_bytes(16).hex_encode()}
	body.requestId = _furniture_retry.requestId
	if not _send_packet(body):
		return false
	_furniture_waiting_until = Time.get_ticks_msec()+5000
	return true

func pets_available() -> bool:
	return admitted and _has_pet_service

func pet_state() -> Dictionary:
	return _pet_store

func homes_for_bank() -> Array:
	return _home_plots

func saved_home() -> Dictionary:
	return _owned_home

func saved_mortgage() -> Dictionary:
	return _mortgage

func eligible_for_home() -> bool:
	return _bank_eligible

func vehicle_shop_available() -> bool:
	return admitted and not _vehicle_offer.is_empty()

func vehicle_tier() -> int:
	return int(_vehicle_offer.get("tier",-1))

func vehicle_purchase_pending() -> bool:
	return not _vehicle_request.is_empty()

func can_retry_vehicle_purchase() -> bool:
	return vehicle_purchase_pending() and Time.get_ticks_msec()-_vehicle_sent_at > 2500

func vehicle_purchase() -> bool:
	if not vehicle_shop_available() or zone != "town": return false
	var fresh := _vehicle_request.is_empty()
	if fresh:
		var tier := vehicle_tier()
		if tier>=2: return false
		_vehicle_request={"type":"progress","action":"vehicles","operation":"buy" if tier<0 else "upgrade","expectedTier":tier,"requestId":Crypto.new().generate_random_bytes(16).hex_encode()}
	elif not can_retry_vehicle_purchase():
		return false
	_send_pose()
	if _send_packet(_vehicle_request):
		_vehicle_sent_at=Time.get_ticks_msec()
		return true
	if fresh: _vehicle_request.clear()
	return false

func saved_stars() -> int:
	return _stars

func pet_command(feature: String, operation: String, argument: Variant = null) -> bool:
	if not pets_available(): return false
	_send_pose()
	var message: Dictionary = {"type":"progress","action":feature,"operation":operation}
	if operation in ["adopt","equip","claim"]:
		if _pet_retry.get("operation")!=operation or _pet_retry.get("argument")!=argument:
			_pet_retry={"operation":operation,"argument":argument,"id":Crypto.new().generate_random_bytes(16).hex_encode()}
		message.requestId=_pet_retry.id
	match operation:
		"adopt": message.species=argument
		"equip": message.id=argument
		"claim","enter": message.plot=argument
	return _send_packet(message)

func pending_bank_action() -> bool:
	return not _bank_request.is_empty()

func bank_command(operation: String, argument: Variant = null) -> bool:
	if not pets_available() or zone!="bank": return false
	var fresh := _bank_request.is_empty()
	if fresh:
		var loan: Variant = _mortgage.get("id")
		if not loan is String or loan.length()!=32: return false
		var balance := int(_mortgage.get("balance",-1))
		var plot := int(_owned_home.get("plot",-1))
		if plot<0 or int(_mortgage.get("homeId",-1))!=plot: return false
		var next_variant: String = {"starter":"cottage","cottage":"family"}.get(_owned_home.get("variant",""),"")
		var payload: Dictionary
		match operation:
			"repay":
				if not argument is int or argument<1 or argument>mini(balance,_stars): return false
				payload={"amount":argument}
			"upgrade":
				if balance!=0 or next_variant.is_empty() or argument!=next_variant: return false
				payload={"plot":plot,"variant":argument}
			_: return false
		_bank_request=payload.merged({"type":"progress","action":"housing","operation":operation,"loanId":loan,"requestId":Crypto.new().generate_random_bytes(16).hex_encode()})
	elif operation!="retry":
		return false
	_send_pose()
	if _send_packet(_bank_request): return true
	if fresh: _bank_request.clear()
	return false

func send_fishing(operation: String, request_id: String, fields: Dictionary = {}) -> bool:
	if not admitted or zone != "beach":
		return false
	_send_pose()
	var packet := {"type":"progress","action":"fishing","operation":operation,"requestId":request_id}
	packet.merge(fields)
	return _send_packet(packet)

func fishing_snapshot() -> Dictionary:
	return _fishing_state

func reef_photos_snapshot() -> Array:
	return _reef_photos.duplicate() if admitted else []

func send_reef_photo(species_id: String, request_id: String) -> bool:
	if not admitted:
		return false
	return _send_packet({"type":"progress","action":"reefPhotos","operation":"record","species":species_id,"requestId":request_id})

func town_home_exteriors() -> Array:
	return _town_home_exteriors if admitted else []

func fishing_world() -> Dictionary:
	return _fishing_world

func fishing_peer(id: int) -> Node3D:
	return _ghosts.get(id,{}).get("node") as Node3D

func fishing_now() -> float:
	return float(Time.get_ticks_msec()) + _fishing_clock

func _sync_fishing_clock(data: Dictionary) -> void:
	if data.has("serverTime"):
		_fishing_clock = float(data.serverTime) - float(Time.get_ticks_msec())

func classes_available() -> bool:
	return admitted and not _class_state.is_empty()

func class_state() -> Dictionary:
	return _class_state

func pending_class_payment() -> Dictionary:
	if _class_request.is_empty(): return {}
	return {"course":_class_request.course,"amount":_class_request.amount}

func class_command(course: String, amount: int) -> bool:
	if not classes_available() or zone!="library": return false
	var fresh := _class_request.is_empty()
	if fresh:
		var row: Dictionary = _class_state.get(course,{})
		if row.is_empty() or int(row.tier)>=3: return false
		_class_request={"type":"progress","action":"classes","operation":"pay","course":course,"amount":amount,"tier":int(row.tier),"paid":int(row.paid),"requestId":Crypto.new().generate_random_bytes(16).hex_encode()}
	elif _class_request.course!=course or _class_request.amount!=amount:
		return false
	_send_pose()
	if _send_packet(_class_request): return true
	if fresh: _class_request.clear()
	return false

func _update_progress(data: Dictionary) -> void:
	if data.get("yard") is Dictionary:
		_yard = data.yard
	if data.get("furniture") is Dictionary and _furniture != data.furniture:
		_furniture = data.furniture
		furniture_snapshot_changed.emit()
	if data.get("neighborQuests") is Dictionary:
		_neighbor_state=data.neighborQuests
		if _neighbor_ui!=null:
			_neighbor_ui.setState(JSON.stringify(_neighbor_state))
			_neighbor_context()
	if data.get("classes") is Dictionary:
		_class_state = data.classes
	if data.has("fishing"):
		_fishing_state = data.fishing.duplicate()
		_fishing_state["_received_at"] = data.serverTime
		_sync_fishing_clock(data)
	if data.get("reefPhotos") is Array:
		_reef_photos = data.reefPhotos.duplicate()
	if data.get("pets") is Dictionary:
		var next_home: Dictionary = data.home if data.get("home") is Dictionary else {}
		var changed: bool = _pet_store != data.pets or _owned_home != next_home or not _has_pet_service
		_has_pet_service = true
		_pet_store = data.pets
		_owned_home = next_home
		_mortgage = data.mortgage if data.get("mortgage") is Dictionary else {}
		_home_plots = data.homePlots if data.get("homePlots") is Array else []
		_bank_eligible = bool(data.get("bankEligible",false))
		if changed: pet_snapshot_changed.emit()
	if data.get("scavenger") is Dictionary:
		_hunt_state = data.scavenger
	if data.get("scavengerLeaderboard") is Array:
		_hunt_rows = data.scavengerLeaderboard
	_sync_hunt(data.get("serverTime"))
	if data.get("jobs") is Dictionary:
		_job_state = data.jobs
		_starter_wait_until.clear()
		var remaining: Variant = data.jobs.get("starterWaitMs")
		if remaining is Dictionary:
			var tick := Time.get_ticks_msec()
			for id: String in ["cafe","store","park","garden"]:
				if remaining.has(id):
					_starter_wait_until[id] = tick + int(remaining[id])
	_vehicle_offer = data.get("vehicleOffer",{})
	_stars = maxi(0,int(data.get("stars",_stars)))
	var tended_at: Variant = data.get("gardenLastTendedAt")
	if (tended_at is int or tended_at is float) and data.has("serverTime"):
		var remaining_ms := clampf(float(tended_at) + 300000.0 - float(data.serverTime),0.0,300000.0)
		_garden_until = float(Time.get_ticks_msec()) + remaining_ms
	if is_instance_valid(_star_badge):
		_star_badge.text = "Stars: %s" % _stars

func garden_approach() -> bool:
	if not admitted or zone != "town" or not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	var p := _player.global_position
	return Vector2(p.x-20.0,p.z-49.0).length() <= 8.0

func garden_available() -> bool:
	if not admitted or zone != "town" or not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	var p := _player.global_position
	return Vector2(p.x-20.0,p.z-49.0).length() <= 4.9 and absf(p.y) < 1.0

func garden_prompt() -> String:
	if not garden_available():
		return "Walk between the garden beds" if garden_approach() else ""
	if _garden_pending_until > 0:
		return "Watering garden…"
	var remaining := ceili((_garden_until-float(Time.get_ticks_msec()))/1000.0)
	return "Garden watered (%ss until ready)" % remaining if remaining > 0 else "Water garden (+2 saved stars)"

func tend_garden() -> void:
	if not garden_available():
		_garden_feedback("Move between the garden beds.")
		return
	if _garden_pending_until > 0:
		_garden_feedback("Watering garden…")
		return
	var remaining := ceili((_garden_until-float(Time.get_ticks_msec()))/1000.0)
	if remaining > 0:
		_garden_feedback("Garden is still wet. Try again in %ss." % remaining)
		return
	_send_pose()
	if _send_packet({"type":"progress","action":"tendGarden"}):
		_garden_feedback("Watering garden…")
		_garden_pending_until = Time.get_ticks_msec()+7000
	else:
		_garden_feedback("Could not reach the garden server. Try again.")

func _garden_feedback(message: String) -> void:
	if is_instance_valid(_garden_notice):
		_garden_notice.text = message
		_garden_notice_until = Time.get_ticks_msec()+6000
		_garden_notice.show()

func _build_menu(hud: CanvasLayer) -> void:
	if _neighbor_ui==null:
		_neighbor_bind()
	_neighbor_context()
	var multiplayer_button := Button.new()
	_zone_menu_button = multiplayer_button
	multiplayer_button.text = "Multiplayer (M)"
	multiplayer_button.focus_mode = Control.FOCUS_NONE
	hud.add_child(multiplayer_button)
	multiplayer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,Control.PRESET_MODE_MINSIZE,14)
	multiplayer_button.pressed.connect(func(): _toggle_menu(true))
	_star_badge = Label.new()
	_star_badge.text = "Stars: %s" % _stars
	hud.add_child(_star_badge)
	_star_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT,Control.PRESET_MODE_MINSIZE)
	_star_badge.offset_left = -140.0 if zone in ["reef",SKYHILL.ZONE] else -440.0
	_star_badge.offset_right = -14.0
	_star_badge.offset_top = 48.0
	_star_badge.offset_bottom = 72.0
	_star_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_star_badge.add_theme_color_override("font_outline_color",Color(0.05,0.10,0.16,0.92))
	_star_badge.add_theme_constant_override("outline_size",5)
	if OS.has_feature("web"):
		_star_badge.item_rect_changed.connect(_position_family_chat, CONNECT_DEFERRED)
		_position_family_chat.call_deferred()
	_garden_notice = Label.new()
	_garden_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_garden_notice)
	_garden_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE)
	_garden_notice.offset_left = -310.0
	_garden_notice.offset_right = -16.0
	_garden_notice.offset_top = -187.0
	_garden_notice.offset_bottom = -131.0
	_garden_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_garden_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_garden_notice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_garden_notice.add_theme_font_size_override("font_size",20)
	_garden_notice.add_theme_color_override("font_outline_color",Color(0.05,0.10,0.16,1.0))
	_garden_notice.add_theme_constant_override("outline_size",7)
	_garden_notice.hide()
	if zone == "town":
		_fit_town_feedback(hud,_garden_notice)
	_panel = PanelContainer.new()
	hud.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER,Control.PRESET_MODE_MINSIZE)
	_panel.position -= Vector2(145,85)
	var menu := VBoxContainer.new()
	_panel.add_child(menu)
	_summary = Label.new()
	_summary.custom_minimum_size.x = 290
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(_summary)
	var scope := Label.new()
	scope.text = "Garden and job stars are saved. Fishing catches and sales are saved."
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(scope)
	_add_button(menu,"Sign out",_sign_out)
	_add_button(menu,"Close",func(): _toggle_menu(false))
	_refresh_menu()
	_panel.hide()
	_create_gate(hud)
	_sync_gate()
	if _network_zone(zone) and zone not in ["reef",SKYHILL.ZONE]:
		_hunt_view = HUNT.new()
		_bound.add_child(_hunt_view)
		_hunt_view.setup(self,_bound,_player,hud,zone)
		_sync_hunt()


func _fit_town_feedback(hud: CanvasLayer, notice: Label) -> void:
	var viewport := hud.get_viewport()
	var resize := func() -> void:
		if not is_instance_valid(notice):
			return
		var view := viewport.get_visible_rect().size
		var scale: float = TOWN_HUD_FIT.physical_scale(viewport)
		if view.x/scale < 690.0:
			notice.set_anchors_preset(Control.PRESET_TOP_LEFT)
			notice.position = Vector2(12,150)*scale
			notice.size = Vector2(view.x-24*scale,75*scale)
			notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			notice.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			notice.add_theme_font_size_override("font_size",roundi(15*scale))
		else:
			notice.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			notice.offset_left = -310.0
			notice.offset_right = -16.0
			notice.offset_top = -187.0
			notice.offset_bottom = -131.0
			notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			notice.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			notice.add_theme_font_size_override("font_size",20)
	viewport.size_changed.connect(resize)
	notice.tree_exiting.connect(func():
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(resize):
			viewport.size_changed.disconnect(resize)
	,CONNECT_ONE_SHOT)
	resize.call()




func _bind_family_chat(window: JavaScriptObject) -> void:
	if window.WillowbrookFamilyChat == null:
		return
	_family_chat = window.WillowbrookFamilyChat
	if _chat_send_cb == null:
		_chat_send_cb = JavaScriptBridge.create_callback(_send_family_chat)
		_chat_toggle_cb = JavaScriptBridge.create_callback(_toggle_family_chat)
	if not bool(_family_chat.bind(_chat_send_cb,_chat_toggle_cb)):
		_family_chat = null
	_sync_family_chat()


func set_skyhill_controls_available(host: Node3D, available: bool) -> void:
	if _bound != host or zone != SKYHILL.ZONE:
		return
	super.set_skyhill_controls_available(host, available)
	if _family_chat != null:
		_family_chat.setOccluded(not available)


func set_zone_book_open(host: Node3D, open: bool) -> void:
	if _bound != host or zone != "reef":
		return
	super.set_zone_book_open(host, open)
	if is_instance_valid(_star_badge):
		_star_badge.visible = not open
	if _family_chat != null:
		_family_chat.setOccluded(open)


func suspend_zone() -> void:
	if zone in ["reef",SKYHILL.ZONE] and _family_chat != null:
		_family_chat.setOccluded(false)
	super.suspend_zone()


func _sync_family_chat() -> void:
	var available := admitted and _chat_available
	if not available:
		_release_family_chat()
	if _family_chat != null:
		if available:
			_position_family_chat()
		_family_chat.setAvailable(available)


func _position_family_chat() -> void:
	if _family_chat == null:
		return
	if is_instance_valid(_arena_chat_host) or not is_instance_valid(_star_badge):
		_family_chat.useFallbackAnchor()
		return
	var viewport := _star_badge.get_viewport()
	var rect := viewport.get_visible_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var end := _star_badge.get_global_rect().end - rect.position
	_family_chat.anchorUnderStars(end.x / rect.size.x, end.y / rect.size.x)


func bind_arena_chat(host: Node3D) -> void:
	_arena_chat_host = host
	_sync_family_chat()


func _release_family_chat() -> void:
	_chat_over_cabinet = false
	if is_instance_valid(_chat_modal_owner):
		_chat_modal_owner.set_zone_modal(false)
	_chat_modal_owner = null


func _toggle_family_chat(args: Array) -> void:
	if _family_chat == null or args.size() != 1 or not args[0] is bool:
		return
	if not args[0]:
		_release_family_chat()
		_family_chat.setOpen(false)
		return
	if not admitted or not _chat_available:
		return
	if bool(_family_chat.hasCabinet()):
		_chat_over_cabinet = true
	else:
		var host := _arena_chat_host if is_instance_valid(_arena_chat_host) else _bound
		if not is_instance_valid(host) or not host.can_open_network_menu():
			return
		_chat_modal_owner = host
		_chat_modal_owner.set_zone_modal(true)
	_family_chat.setOpen(true)


func _send_family_chat(args: Array) -> void:
	if _family_chat == null or not admitted or not _chat_available or (not is_instance_valid(_chat_modal_owner) and not _chat_over_cabinet) or args.size() != 1 or not args[0] is String:
		return
	var body: String = args[0]
	if body.strip_edges().is_empty() or body.length()>160:
		_family_chat.feedback("Use 1–160 characters.",false)
		return
	var accepted := _send_packet({"type":"chat","text":body})
	_family_chat.feedback("" if accepted else "Chat is disconnected. Try again.",accepted)


func _bind_html_gate() -> bool:
	if not OS.has_feature("web"):
		return false
	var window := JavaScriptBridge.get_interface("window")
	if window == null or window.WillowbrookSignIn == null:
		return false
	_html_gate = window.WillowbrookSignIn
	_bind_family_chat(window)
	if _html_submit_cb == null:
		_html_submit_cb = JavaScriptBridge.create_callback(_submit_html_login)
		_html_resume_cb = JavaScriptBridge.create_callback(func(_args: Array): _resume_if_possible())
		_html_cancel_cb = JavaScriptBridge.create_callback(func(_args: Array): _cancel_login())
	if not bool(_html_gate.bind(_html_submit_cb,_html_resume_cb,_html_cancel_cb)):
		_html_gate = null
		return false
	_refresh_menu()
	return true


func _submit_html_login(args: Array) -> void:
	if admitted or _web != null or args.size() != 2 or not args[0] is String or not args[1] is String:
		return
	var username: String = args[0].strip_edges()
	var password: String = args[1]
	if username.is_empty() or password.is_empty() or username.length()>32 or password.length()>128:
		_set_status("Enter your test username and password.")
		return
	_begin_login({"type":"login","username":username,"password":password})


func _create_gate(hud: CanvasLayer) -> void:
	if _bind_html_gate():
		return
	_login_layer = CanvasLayer.new()
	_login_layer.layer = 80
	hud.add_child(_login_layer)
	var backdrop := ColorRect.new()
	_login_layer.add_child(backdrop)
	backdrop.color = Color("#142b48")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_login_panel = backdrop
	var center := CenterContainer.new()
	backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 250
	col.add_theme_constant_override("separation",10)
	margin.add_child(col)
	var title := Label.new()
	title.text = "Willowbrook Playtest"
	title.add_theme_font_size_override("font_size",24)
	col.add_child(title)
	var details := Label.new()
	details.text = "Sign in with a local test account."
	col.add_child(details)
	var user_label := Label.new()
	user_label.text = "Username"
	col.add_child(user_label)
	_username = LineEdit.new()
	_username.max_length = 32
	_username.custom_minimum_size.y = 40
	col.add_child(_username)
	var pass_label := Label.new()
	pass_label.text = "Password"
	col.add_child(pass_label)
	_password = LineEdit.new()
	_password.secret = true
	_password.max_length = 128
	_password.custom_minimum_size.y = 40
	col.add_child(_password)
	_username.text_submitted.connect(func(_value): _password.grab_focus())
	_password.text_submitted.connect(func(_value): _submit_login())
	_login_button = Button.new()
	_login_button.text = "Sign in"
	_login_button.custom_minimum_size.y = 42
	_login_button.pressed.connect(_submit_login)
	col.add_child(_login_button)
	_retry_login_button = Button.new()
	_retry_login_button.text = "Retry session"
	_retry_login_button.custom_minimum_size.y = 42
	_retry_login_button.pressed.connect(_resume_if_possible)
	col.add_child(_retry_login_button)
	_cancel_login_button = Button.new()
	_cancel_login_button.text = "Cancel connection"
	_cancel_login_button.custom_minimum_size.y = 42
	_cancel_login_button.pressed.connect(_cancel_login)
	col.add_child(_cancel_login_button)
	_login_status = Label.new()
	_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_login_status.custom_minimum_size = Vector2(250,43)
	col.add_child(_login_status)
	_refresh_menu()

func _refresh_menu() -> void:
	super._refresh_menu()
	if is_instance_valid(_login_status):
		_login_status.text = "" if status == "Playing offline" else status
	var connecting := not admitted and (_web != null or _reconnect_attempt >= 0)
	if _html_gate != null:
		_html_gate.setStatus("" if status == "Playing offline" else status,connecting,not admitted and not connecting and not _read_token().is_empty(),_auto_resume_active)
	if is_instance_valid(_login_button):
		_login_button.disabled = connecting
	if is_instance_valid(_retry_login_button):
		_retry_login_button.visible = not admitted and not connecting and OS.has_feature("web") and not _read_token().is_empty()
	if is_instance_valid(_cancel_login_button):
		_cancel_login_button.visible = connecting

func _sync_gate() -> void:
	if _html_gate != null:
		var show := not admitted
		if (show or _html_gate_open) and is_instance_valid(_bound) and _bound.has_method("set_zone_modal"):
			_bound.call("set_zone_modal",show)
		_html_gate_open = show
		_html_gate.setOpen(show)
		return
	if not is_instance_valid(_login_panel):
		return
	var open := not admitted
	var was_open := _login_panel.visible
	_login_panel.visible = open
	if (open or was_open) and is_instance_valid(_bound) and _bound.has_method("set_zone_modal"):
		_bound.call("set_zone_modal",open)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and _web != null and not admitted:
		_cancel_login()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_hunt_view) and _hunt_view.is_open() and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_hunt_view.close_menu()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(_employer_panel) and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close_employer()
		get_viewport().set_input_as_handled()
	elif admitted:
		super._input(event)

func job_memberships() -> Array:
	return _job_state.get("memberships",[])

func job_status() -> String:
	return String(_job_state.get("status",""))

func job_starter_wait(id: String) -> int:
	if not admitted or not _starter_wait_until.has(id):
		return -1
	return ceili(maxf(0.0,float(_starter_wait_until[id] - Time.get_ticks_msec()))/1000.0)


func job_state() -> Dictionary:
	return _job_state.duplicate(true)

func job_markers(only_current := false) -> Array:
	if not admitted:
		return []
	var current: Variant = _job_state.get("current")
	var list: Array = [current] if current is Dictionary else []
	if not only_current:
		list.append_array(_job_state.get("available",[]))
		list.append_array(_job_state.get("employers",[]))
	var rows: Array = []
	for item: Variant in list:
		if item is Dictionary and item.get("zone") == zone:
			var row := (item as Dictionary).duplicate()
			row.position = Vector3(float(row.get("x",0)),0,float(row.get("z",0)))
			rows.append(row)
	return rows

func job_offer(include_hire := true) -> Dictionary:
	if not admitted or not is_instance_valid(_player) or not _player.is_on_floor():
		return {}
	var p := _player.global_position
	var best: Dictionary = {}
	var closest := INF
	for row: Dictionary in job_markers():
		if row.get("kind") == "hire" and not include_hire:
			continue
		var at: Vector3 = row.position
		var distance := Vector2(p.x-at.x,p.z-at.z).length()
		if distance <= float(row.get("radius",1.5)) and distance < closest:
			best = row
			closest = distance
	return best

func interact_job(offer: Dictionary) -> void:
	if offer.is_empty():
		return
	if offer.get("kind") == "hire":
		_open_employer(offer)
	else:
		job_action("interact",String(offer.get("job","")))

func job_action(operation: String, job := "") -> void:
	if not admitted:
		return
	_send_pose()
	var packet := {"type":"progress","action":"jobs","operation":operation}
	if not job.is_empty():
		packet.job = job
	if _send_packet(packet):
		_activity_feedback("Checking with town staff…")
	else:
		_activity_feedback("Could not reach town staff. Try again.")

func _activity_feedback(message: String) -> void:
	if message.is_empty() or not is_instance_valid(_garden_notice):
		return
	_garden_notice.text = message
	_garden_notice_until = Time.get_ticks_msec()+8000
	_garden_notice.show()

func _open_employer(offer: Dictionary) -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_bound) or is_instance_valid(_employer_panel):
		return
	var job := String(offer.get("job",""))
	var hired := job_memberships().has(job)
	var heading := String(offer.get("label","Town jobs")).trim_prefix("Talk to ")
	var guide: Dictionary = _bound.profile.job_guide(job) if _bound.profile != null else {}
	_employer_panel = PanelContainer.new()
	_panel.get_parent().add_child(_employer_panel)
	_employer_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER,Control.PRESET_MODE_MINSIZE)
	_employer_panel.position -= Vector2(164,125)
	var col := VBoxContainer.new()
	_employer_panel.add_child(col)
	var title := Label.new()
	title.text = heading.capitalize()
	title.add_theme_font_size_override("font_size",23)
	col.add_child(title)
	var description := Label.new()
	description.custom_minimum_size.x = 330
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.text = ("You're already hired. " if hired else "Need a job? ") + "Start at: " + String(guide.get("station","the marked work station")) + "."
	col.add_child(description)
	if not hired and bool(offer.get("hire_in_reach",true)):
		_add_button(col,"Get hired",func(): close_employer();job_action("hire",job))
	elif not hired:
		description.text += " Come closer to the front if you'd like to get hired."
	if job == "park" and is_instance_valid(_hunt_view):
		_add_button(col,"Treasure hunt",func(): close_employer(); _hunt_view.open_menu(true))
	_add_button(col,"Close",close_employer)
	_bound.set_zone_modal(true)

func close_employer() -> void:
	if not is_instance_valid(_employer_panel):
		return
	_employer_panel.queue_free()
	_employer_panel = null
	if is_instance_valid(_bound):
		_bound.set_zone_modal(false)

func _sync_hunt(server_time: Variant = null) -> void:
	if is_instance_valid(_hunt_view):
		_hunt_view.update_state(_hunt_state,_hunt_rows,server_time)

func player_avatar_id() -> String:
	return _character

func hunt_first_completed() -> bool:
	# The trophy is lifetime; completedAt is reset for each replay.
	return admitted and bool(_hunt_state.get("trophyAwarded",false))

func hunt_prompt() -> String:
	return _hunt_view.prompt() if is_instance_valid(_hunt_view) else ""

func collect_hunt() -> bool:
	return is_instance_valid(_hunt_view) and _hunt_view.interact()

func hunt_action(operation: String, item := "") -> void:
	if not admitted:
		return
	_send_pose()
	var packet := {"type":"progress","action":"scavenger","operation":operation,"runId":_hunt_state.get("runId")}
	if operation == "start":
		packet.requestId = Crypto.new().generate_random_bytes(12).hex_encode()
	elif operation == "collect":
		packet.item = item
	if _send_packet(packet):
		_activity_feedback("Starting the treasure hunt…" if operation == "start" else "Collecting treasure…")
	else:
		_activity_feedback("Could not reach the treasure hunt. Try again.")


func _neighbor_bind() -> void:
	if not OS.has_feature("web"):
		return
	var w := JavaScriptBridge.get_interface("window")
	_neighbor_ui = w.WillowbrookNeighborQuests if w != null else null
	if _neighbor_ui == null:
		return
	_neighbor_toggle_cb = JavaScriptBridge.create_callback(_neighbor_toggle)
	_neighbor_action_cb = JavaScriptBridge.create_callback(_neighbor_action)
	_neighbor_ui.bind(_neighbor_toggle_cb,_neighbor_action_cb)

func _neighbor_context() -> void:
	if _neighbor_ui == null:
		return
	if _neighbor_open and (not is_instance_valid(_neighbor_modal_owner) or _neighbor_modal_owner != _bound or not admitted or zone not in ["town","library","cafe"]):
		_neighbor_toggle([false])
	_neighbor_ui.setContext(admitted and zone in ["town","library","cafe"] and bool(_neighbor_state.get("available",false)),zone=="town",zone!="town" and not neighbor_quests_completed())

func neighbor_quests_completed() -> bool:
	if not bool(_neighbor_state.get("available",false)):
		return false
	var flags := {}
	for row: Dictionary in _neighbor_state.get("routes",[]):
		if row.get("completed")==true: flags[str(row.get("route",""))]=true
	return flags.has("gardener") and flags.has("librarian")

func activity_hud_allowed() -> bool:
	return admitted or _reconnect_attempt>=0

func neighbor_quests_supported() -> bool:
	return _neighbor_ui!=null and admitted and bool(_neighbor_state.get("available",false))

func open_neighbor_quests() -> void:
	if neighbor_quests_supported(): _neighbor_toggle([true])

func _neighbor_toggle(args: Array) -> void:
	if _neighbor_ui == null or args.size()!=1 or not args[0] is bool:
		return
	if not args[0]:
		_neighbor_open=false
		if is_instance_valid(_neighbor_modal_owner):
			_neighbor_modal_owner.call("set_zone_modal",false)
		_neighbor_modal_owner=null
		_neighbor_ui.setOpen(false)
		return
	if not admitted or zone not in ["town","library","cafe"] or not is_instance_valid(_bound) or not _bound.has_method("set_zone_modal") or bool(_bound.get("zone_modal")):
		return
	_neighbor_modal_owner=_bound
	_neighbor_open=true
	_bound.call("set_zone_modal",true)
	_neighbor_ui.setOpen(true)

func _neighbor_visit(route: String) -> void:
	if zone != "town" or not is_instance_valid(_player) or not _player.is_on_floor():
		_neighbor_ui.feedback("Return to town and stand on the ground before using Visit.")
		return
	var vehicles: Variant = _bound.get("vehicles")
	var playground: Variant = _bound.get("playground")
	if (is_instance_valid(vehicles) and vehicles.is_driving()) or (is_instance_valid(playground) and not playground.ride.is_empty()) or bool(_bound.get("room_seated")):
		_neighbor_ui.feedback("Step away from your vehicle, seat or playground ride first.")
		return
	var mark: Dictionary = {}
	var current: Variant = _neighbor_state.get("current")
	if current is Dictionary and current.get("route")==route:
		mark=current.marker
	elif current==null:
		for item: Dictionary in _neighbor_state.get("routes",[]):
			if item.get("route")==route:
				mark=item.marker
	if mark.is_empty():
		return
	# Known walkable approach points, 1–6 units from the server-owned anchors.
	var arrival := Vector3.ZERO
	var anchor := Vector2(float(mark.worldX),float(mark.worldZ))
	if anchor==Vector2(-23,48): arrival=Vector3(-23,0.08,44)
	elif anchor==Vector2(20,48): arrival=Vector3(20,0.08,44)
	elif anchor==Vector2(16,-24): arrival=Vector3(16,0.08,-30)
	elif anchor==Vector2(-16,-24): arrival=Vector3(-16,0.08,-18)
	elif anchor==Vector2(16,19): arrival=Vector3(16,0.08,17)
	else:
		_neighbor_ui.feedback("Walk to the quest stop shown in the route.")
		return
	_player.global_position=arrival
	_player.velocity=Vector3.ZERO
	_neighbor_ui.feedback("Arrived near the quest stop. Use the separate Start or Complete button.")

func _neighbor_action(args: Array) -> void:
	if args.size()!=2 or not args[0] is String or not args[1] is String or not admitted or not is_instance_valid(_neighbor_modal_owner) or _neighbor_modal_owner!=_bound:
		return
	var op := String(args[0])
	var route := String(args[1])
	var now := Time.get_ticks_msec()
	if op=="retry":
		if _neighbor_request.is_empty() or _neighbor_retry_at>now: return
	elif op=="visit":
		if _neighbor_request.is_empty(): _neighbor_visit(route)
		return
	elif not _neighbor_request.is_empty() or op not in ["start","step","cancel"] or route not in ["gardener","librarian"] or not bool(_neighbor_state.get("available",false)):
		return
	else:
		_neighbor_request={"type":"progress","action":"neighborQuest","operation":op,"route":route,"revision":int(_neighbor_state.revision),"requestId":Crypto.new().generate_random_bytes(16).hex_encode()}
	if op!="retry" and op!="cancel":
		if not is_instance_valid(_player) or not _player.is_on_floor():
			_neighbor_request.clear()
			_neighbor_ui.feedback("Stand on the ground near the quest stop.")
			return
		var vehicles: Variant = _bound.get("vehicles")
		var playground: Variant = _bound.get("playground")
		if (is_instance_valid(vehicles) and vehicles.is_driving()) or (is_instance_valid(playground) and not playground.ride.is_empty()) or bool(_bound.get("room_seated")):
			_neighbor_request.clear()
			_neighbor_ui.feedback("Step away from your vehicle, seat or playground ride first.")
			return
	_send_pose()
	if _send_packet(_neighbor_request):
		_neighbor_retry_at=now+2500
		_neighbor_ui.setPending(true,true)
		_neighbor_ui.feedback("Saving quest progress...")
	else:
		_neighbor_retry_at=0
		_neighbor_ui.setPending(true,false)
		_neighbor_ui.feedback("Not connected. Retry this quest action after reconnecting.")

