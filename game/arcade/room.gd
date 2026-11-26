extends Node3D

const LAYOUT := preload("res://game/arcade/room_layout.tscn")

var host: Node3D
var player: CharacterBody3D
var menu: Control
var targets: Array[Dictionary] = []
var layout: Node3D
var exit_marker: Node3D
var browser_arcade: JavaScriptObject
var browser_close_cb: JavaScriptObject
var browser_send_cb: JavaScriptObject
var browser_session: Node
var browser_active := false
var browser_failed_id := ""


func setup(_room_id: String, owner_map: Node3D, walker: CharacterBody3D, hud: CanvasLayer) -> void:
	host = owner_map
	player = walker
	_build_room()
	if OS.has_feature("web"):
		browser_close_cb = JavaScriptBridge.create_callback(_browser_closed)
		browser_send_cb = JavaScriptBridge.create_callback(_browser_send)
		browser_session = get_node_or_null("/root/WillowbrookBrowserSession")
		if browser_session != null:
			browser_session.arcade_message.connect(_browser_receive)
			browser_session.status_changed.connect(_browser_status_changed)
		_load_browser_script()
	else:
		menu = load("res://game/arcade/menu.gd").new()
		hud.add_child(menu)
		menu.setup(host)


func _load_browser_script() -> void:
	JavaScriptBridge.eval("""if (!window.WillowbrookArcade && !document.querySelector('script[data-willowbrook-arcade]')) {
		const s = document.createElement('script');
		s.dataset.willowbrookArcade = 'true'; s.src = './web-arcade/shell.js';
		const timer = setTimeout(() => s.remove(),6000);
		s.addEventListener('load', () => clearTimeout(timer), {once:true});
		s.addEventListener('error', () => {clearTimeout(timer);s.remove();}, {once:true});
		document.head.append(s);
	}""",true)

func spawn_position() -> Vector3:
	return Vector3(0, 0.04, 5.5)


func interaction_prompt() -> String:
	var spot := _target()
	if spot.is_empty():
		return ""
	if spot.id == browser_failed_id:
		return "Cabinet didn't load · Retry"
	return "Back to Town" if spot.id == "exit" else "Play " + String(spot.label)


func interact() -> bool:
	var spot := _target()
	if spot.is_empty():
		return false
	if spot.id == "exit":
		host.go_to_town()
	elif OS.has_feature("web"):
		return _open_browser_cabinet(spot.id,spot.label)
	else:
		menu.open_cabinet(spot.id, spot.label)
	return true


func _open_browser_cabinet(id: String, caption: String) -> bool:
	var window := JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	browser_arcade = window.WillowbrookArcade
	if browser_arcade == null:
		browser_failed_id = id
		_load_browser_script()
		return false
	host.set_zone_modal(true)
	browser_active = bool(browser_arcade.open(id,caption,browser_close_cb,browser_send_cb,_browser_admitted()))
	browser_failed_id = "" if browser_active else id
	if not browser_active:
		host.set_zone_modal(false)
	return browser_active


func _browser_send(args: Array) -> void:
	if browser_arcade == null or args.size() != 2:
		return
	var ticket: Variant = args[1]
	var sent := false
	if browser_active and _browser_admitted() and args[0] is String:
		var body: Variant = JSON.parse_string(args[0])
		if body is Dictionary and body.get("type","") in ["airHockey","hoops88"]:
			sent = bool(browser_session.send_arcade(body))
	browser_arcade.reportSent(ticket,sent)


func _browser_receive(body: Dictionary) -> void:
	if browser_active and browser_arcade != null:
		browser_arcade.receive(JSON.stringify(body))


func _browser_status_changed(_status: String) -> void:
	if browser_active and browser_arcade != null:
		browser_arcade.setTransportReady(_browser_admitted())


func _browser_admitted() -> bool:
	return is_instance_valid(browser_session) and bool(browser_session.get("admitted"))


func _browser_closed(_args: Array) -> void:
	browser_active = false
	if is_instance_valid(host):
		host.set_zone_modal(false)


func _exit_tree() -> void:
	if browser_active and browser_arcade != null:
		browser_arcade.close()
	if is_instance_valid(browser_session):
		if browser_session.arcade_message.is_connected(_browser_receive):
			browser_session.arcade_message.disconnect(_browser_receive)
		if browser_session.status_changed.is_connected(_browser_status_changed):
			browser_session.status_changed.disconnect(_browser_status_changed)
	browser_close_cb = null
	browser_send_cb = null
	browser_arcade = null


func _target() -> Dictionary:
	if player == null or browser_active or (menu != null and menu.visible):
		return {}
	var p := player.global_position
	var exit_position := exit_marker.global_position
	if Vector2(p.x - exit_position.x,p.z - exit_position.z).length() < 1.5:
		return {"id": "exit"}
	var best := {}
	var near := 1.70
	for spot: Dictionary in targets:
		var at: Vector3 = spot.at
		var distance := Vector2(p.x-at.x, p.z-at.z).length()
		if distance < near:
			best = spot
			near = distance
	return best


func _build_room() -> void:
	layout = LAYOUT.instantiate()
	add_child(layout)
	exit_marker = layout.get_node("ExitMarker")
	for cabinet: Node3D in layout.get_node("Cabinets").get_children():
		var marker := cabinet.get_node("InteractHere") as Marker3D
		var caption := cabinet.get_node("Caption") as Label3D
		targets.append({"id":String(cabinet.get_meta("cabinet_id")),"label":caption.text,"at":marker.global_position})
