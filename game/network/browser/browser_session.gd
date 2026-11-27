extends "res://game/network/session.gd"
## Same-origin browser WebSocket. Never starts an ENet host or uses saved web credentials.
signal arcade_message(message: Dictionary)
signal shared_vehicle_event(message: Dictionary)
var _town_vehicle_state: Dictionary = {}
const MESSAGE_SCHEMA = preload("res://game/network/browser/message_schema.gd")
const CLOSE_GRACE_MS := 2000
var _retired_web: Array[Dictionary] = []
var _web: WebSocketPeer
var _join_sent := false
var _hello_deadline := 0
var _world_at := 0
var _town_rides_available := false
var _weather_phase := 0.0
var _weather_received := 0
var _weather_kind := ""


func _ready() -> void:
	pass


func _browser_endpoint() -> String:
	if not OS.has_feature("web"):
		return ""
	var location = JavaScriptBridge.get_interface("window").location
	var protocol := "wss://" if String(location.protocol) == "https:" else "ws://"
	return protocol + String(location.host) + "/play"


func join_web(alias: String, code: String, endpoint := "") -> bool:
	if _web != null:
		return false
	code = code.strip_edges().to_upper()
	if code.length() != 12:
		_set_status("Enter the 12-character invite code.")
		return false
	if endpoint.is_empty():
		endpoint = _browser_endpoint()
	if not endpoint.begins_with("ws://") and not endpoint.begins_with("wss://"):
		_set_status("No browser multiplayer server is configured.")
		return false
	var next := WebSocketPeer.new()
	next.inbound_buffer_size = 32768
	next.outbound_buffer_size = 32768
	if next.connect_to_url(endpoint) != OK:
		_set_status("Could not open the browser multiplayer connection.")
		return false
	_name = _clean_name(alias)
	_invite = code
	_web = next
	_join_sent = false
	_hello_deadline = Time.get_ticks_msec() + 8000
	_set_status("Connecting…")
	return true


func leave_session(message := "Playing offline") -> void:
	_web_leave(message)


func _web_leave(message: String) -> void:
	_retire_current_web()
	admitted = false
	_join_sent = false
	_invite = ""
	_elapsed = 0.0
	_hello_deadline = 0
	_world_at = 0
	_town_rides_available = false
	_receive_local([],[])
	_set_status(message)


func _retire_current_web() -> void:
	var socket := _web
	_web = null
	if socket == null:
		return
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
		socket.close()
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_retired_web.append({"socket":socket,"until":Time.get_ticks_msec()+CLOSE_GRACE_MS})


func _poll_retired_web() -> void:
	var now := Time.get_ticks_msec()
	for i in range(_retired_web.size()-1,-1,-1):
		var row: Dictionary = _retired_web[i]
		var socket: WebSocketPeer = row.socket
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or now >= int(row.until):
			_retired_web.remove_at(i)


func _poll_browser_messages() -> void:
	var socket := _web
	if socket == null:
		return
	for i in range(48):
		if _web != socket or socket.get_available_packet_count() == 0:
			return
		var packet := socket.get_packet()
		if not socket.was_string_packet():
			continue
		var data := MESSAGE_SCHEMA.parse(packet)
		if not data.is_empty():
			_on_web_message(data)


func _send_packet(m: Dictionary) -> bool:
	return _web != null and _web.get_ready_state() == WebSocketPeer.STATE_OPEN and _web.send_text(JSON.stringify(m)) == OK


func outdoor_environment() -> Dictionary:
	if not admitted or zone != "town" or _weather_kind.is_empty():
		return {}
	var elapsed := Time.get_ticks_msec()-_weather_received
	if elapsed > 3000:
		return {}
	return {"phase":fposmod(_weather_phase+float(elapsed)/1200000.0,1.0),"weather":_weather_kind}


func _accept_weather(packet: Variant) -> void:
	_weather_kind = ""
	if not packet is Dictionary or packet.get("weather") not in ["sunny","cloudy","rain"]:
		return
	var phase: Variant = packet.get("phase")
	if (not phase is float and not phase is int) or not is_finite(float(phase)) or phase < 0.0 or phase >= 1.0:
		return
	_weather_phase = float(phase)
	_weather_received = Time.get_ticks_msec()
	_weather_kind = String(packet.weather)


func _send_pose() -> void:
	var public_zone := _network_zone(zone) and is_instance_valid(_player) and _player.is_inside_tree()
	var pos: Vector3 = _player.global_position if public_zone else Vector3.ZERO
	var motion := _presence_motion() if public_zone else Vector2.ZERO
	var yaw := wrapf(motion.x,-PI,PI)
	var moving := public_zone and motion.y > .0225
	var packet := {"type":"move","zone":zone if public_zone else "private","x":pos.x,"y":pos.y,"z":pos.z,"yaw":yaw,"moving":moving,"grounded":not public_zone or _player.is_on_floor()}
	if public_zone and is_instance_valid(_bound) and zone in ["bank","vet","salon","store","cafe","library"]:
		var indoor_room := _bound.get("room") as Node
		if is_instance_valid(indoor_room) and indoor_room.has_method("network_rest_pose") and indoor_room.network_rest_pose()=="sit":
			packet.rest = "sit"
			packet.yaw = wrapf(float(indoor_room.network_rest_yaw()),-PI,PI)
	_send_packet(packet)


func town_rides_available() -> bool:
	return admitted and zone=="town" and _town_rides_available and Time.get_ticks_msec()-_world_at<3500


func town_ride(action: String, target := "") -> bool:
	if not town_rides_available(): return false
	if action=="board":
		_send_pose()
		return _send_packet({"type":"playground","action":"board","target":target,"onFoot":true})
	return action=="exit" and _send_packet({"type":"playground","action":"exit"})


func town_vehicle_state() -> Dictionary:
	return _town_vehicle_state if admitted and zone=="town" else {}

func send_vehicle(message: Dictionary) -> bool:
	if not admitted or zone!="town" or message.get("type") not in ["vehicleAction","vehicleInput"]: return false
	if message.type=="vehicleAction" and message.get("operation") in ["enter","recall"]: _send_pose()
	return _send_packet(message)

func send_arcade(message: Dictionary) -> bool:
	if not admitted or zone != "arcade" or message.get("type") not in ["airHockey","hoops88"]:
		return false
	if message.get("action") in ["join","start"]:
		_send_pose()
	return _send_packet(message)


func hockey_leave() -> void:
	# Scene exit frees either original arcade service; an active iframe also leaves explicitly.
	if admitted and zone == "arcade":
		_send_packet({"type":"airHockey","action":"leave"})
		_send_packet({"type":"hoops88","action":"leave"})


func _process(delta: float) -> void:
	_poll_retired_web()
	if _web != null:
		_web.poll()
		var now := Time.get_ticks_msec()
		match _web.get_ready_state():
			WebSocketPeer.STATE_CLOSED:
				_web_leave("Disconnected. Open Multiplayer to rejoin." if admitted else "Browser multiplayer unavailable. Check the local server and invite code.")
			WebSocketPeer.STATE_OPEN:
				if not _join_sent:
					_join_sent = _send_packet({"type":"join","alias":_name,"code":_invite})
				_poll_browser_messages()
		if _hello_deadline > 0 and now > _hello_deadline:
			_web_leave("The browser server didn’t answer.")
		elif admitted and now - _world_at > 12000:
			_web_leave("The browser multiplayer connection timed out.")
		if admitted:
			_elapsed += delta
			if _elapsed >= PERIOD:
				_elapsed = fmod(_elapsed,PERIOD)
				_send_pose()
	_draw_ghosts(delta)


func _on_web_message(m: Dictionary) -> void:
	match m.get("type"):
		"welcome":
			if admitted or not _join_sent:
				return
			_name = String(m.get("alias","Player"))
			admitted = true
			_hello_deadline = 0
			_world_at = Time.get_ticks_msec()
			_set_status("Joined as %s" % _name)
			_send_pose()
		"denied":
			_web_leave(String(m.get("error","Invite denied.")))
		"world":
			if not admitted:
				return
			_world_at = Time.get_ticks_msec()
			_accept_weather(m.get("environment"))
			_town_vehicle_state=m.get("vehicles",{}) if m.get("zone")==zone and zone=="town" else {}
			if m.get("zone")=="town" and zone=="town":
				_town_rides_available = m.get("playground") is Dictionary
				if _town_rides_available and is_instance_valid(_bound) and _bound.has_method("sync_town_rides"):
					_bound.sync_town_rides(m.playground)
			var visible: Array = []
			var scooter_drivers := {}
			for body: Dictionary in _town_vehicle_state.get("rows",[]):
				if body.get("kind")=="scooter" and body.get("driver")!=null:
					scooter_drivers[str(body.id)]=int(body.driver)
			for row: Variant in m.get("players",[]):
				if not row is Dictionary or row.get("zone") != zone:
					continue
				var pos := Vector3(float(row.x),float(row.y),float(row.z))
				var seat: Variant = row.get("vehicleSeat")
				var scooter_id := str(seat.get("car","")) if seat is Dictionary and seat.get("seat")=="driver" else ""
				if not scooter_drivers.has(scooter_id) or scooter_drivers[scooter_id]!=int(row.id):
					scooter_id=""
				visible.append({"scooterRide":scooter_id,"id":int(row.id),"alias":String(row.alias),"zone":zone,"position":pos,"yaw":float(row.yaw),"moving":row.moving==true,"grounded":row.grounded==true,"character":AVATAR_CATALOG.sanitize(row.get("character")),"companionSpecies":row.get("companionSpecies"),"rest":row.get("rest",""),"vehicleSeat":row.get("vehicleSeat") is Dictionary})
			_receive_local(visible,m.get("presence",[]))
		"playground":
			if admitted and zone=="town" and not m.ok and is_instance_valid(_bound) and _bound.has_method("town_ride_error"):
				_bound.town_ride_error(str(m.get("error","Could not use this spot.")))
		"vehicleEvent":
			if admitted and zone=="town": shared_vehicle_event.emit(m)
		"airHockeyFrame","airHockeyError","hoops88":
			if admitted and zone == "arcade":
				arcade_message.emit(m)


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
	_panel.position -= Vector2(145,110)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_summary = Label.new()
	_summary.custom_minimum_size.x = 290
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_summary)
	var alias := LineEdit.new()
	alias.placeholder_text = "Nickname (not your real name)"
	alias.text = _name
	alias.max_length = 32
	column.add_child(alias)
	var invite := LineEdit.new()
	invite.placeholder_text = "12-character invite code"
	invite.max_length = 12
	invite.secret = true
	column.add_child(invite)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_add_button(buttons,"Join",func():
		if join_web(alias.text,invite.text):
			invite.clear()
	)
	_add_button(buttons,"Leave / Cancel",func():
		_web_leave("Disconnected. Join again when ready." if admitted else "Connection canceled. Join again when ready.")
	)
	_add_button(buttons,"Close",func(): _toggle_menu(false))
	_refresh_menu()
	_panel.hide()
