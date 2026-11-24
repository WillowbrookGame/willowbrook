extends Node3D

const ART := "res://game/arcade/kenney-mini-arcade/"
const EXIT := Vector3(0, 0, 6.5)
const CABINETS := [
	["basketball", "HOOPS '88", "basketball-game", -6.0, -5.5, 2.3, 2.3, 0.0],
	["memory", "Memory Match", "arcade-machine", -2.0, -5.8, 1.5, 1.8, 0.0],
	["road-hop", "Road Crossing", "arcade-machine", 2.0, -5.8, 1.5, 1.8, 0.0],
	["maze-chase", "Blastemoids", "arcade-machine", 6.0, -5.8, 1.5, 1.8, 0.0],
	["claw", "Claw Machine", "claw-machine", -7.8, 0.0, 1.8, 1.8, PI / 2],
	["air-hockey", "Air Hockey", "air-hockey", 0.0, 0.0, 4.0, 2.8, 0.0],
	["brick-breaker", "Cosmic Breakout", "arcade-machine", 7.8, 1.0, 1.5, 1.8, -PI / 2],
	["survivors", "Basic Survivors", "arcade-machine", -7.8, 3.6, 1.5, 1.8, PI / 2],
]
const FACES := {
	"arcade-machine": [0.65, 0.18125, 0.36], "claw-machine": [0.60, 0.3265, 0.5],
	"basketball-game": [0.768, -0.3, 0.4], "air-hockey": [0.128, 0.3, 0.56]
}
var host: Node3D
var player: CharacterBody3D
var menu: Control
var targets: Array[Dictionary] = []
var bounds: Dictionary = {}
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
	if Vector2(p.x - EXIT.x,p.z - EXIT.z).length() < 1.5:
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
	var floor_color := Color("#e1c9a4")
	var wall_color := Color("#dedcf5")
	_box("Floor", Vector3(0,-0.12,0), Vector3(18.4,.24,14.4), floor_color,true)
	_box("BackWall",Vector3(0,2.5,-7.2),Vector3(18.4,5,.2),wall_color,true)
	for side: float in [-1.0,1.0]:
		_box("SideWall",Vector3(side*9.2,2.5,0),Vector3(.2,5,14.4),wall_color,true)
		_box("FrontWall",Vector3(side*5.35,2.5,7.2),Vector3(7.7,5,.2),wall_color,true)
	_box("DoorHeader",Vector3(0,4.3,7.2),Vector3(3,1.4,.2),wall_color,true)
	_box("ExitLimit",Vector3(0,1.25,7.35),Vector3(3,2.5,.12),Color("#aab8dd"),true)
	_box("ExitMarker",Vector3(0,.025,6.5),Vector3(2.4,.05,.7),Color("#8dbbb0"))
	_label(self,"EXIT",Vector3(0,2.7,7.24),2.0, PI)
	_box("Window",Vector3(0,2.6,-7.08),Vector3(3,1.8,.05),Color("#a9d3de"))
	_box("WindowFrame",Vector3(0,2.6,-7.04),Vector3(.08,1.8,.04),Color("#fffaf0"))
	for rec: Array in CABINETS:
		_make_cabinet(rec)


func _make_cabinet(rec: Array) -> void:
	var id: String = rec[0]
	var caption: String = rec[1]
	var asset: String = rec[2]
	var width: float = rec[5]
	var depth: float = rec[6]
	var yaw: float = rec[7]
	var holder := Node3D.new()
	holder.name = id.replace("-","_").capitalize().replace(" ","")
	add_child(holder)
	holder.position = Vector3(rec[3],.03,rec[4])
	holder.rotation.y = yaw
	var path := ART + asset + ".glb"
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		holder.add_child(model)
		if not bounds.has(asset):
			bounds[asset] = _mesh_bounds(model)
		var aabb: AABB = bounds[asset]
		var horizontal := minf(width/aabb.size.x,depth/aabb.size.z)
		var uniform := minf(horizontal,2.6/aabb.size.y)
		model.scale = Vector3(horizontal,1.1/aabb.size.y,horizontal) if id == "air-hockey" else Vector3.ONE * uniform
		model.position = -Vector3(aabb.get_center().x,aabb.position.y,aabb.get_center().z) * model.scale
		var face: Array = FACES[asset]
		var sign_pos := model.position + Vector3(0,face[0],face[1]+.004) * model.scale
		_label(holder,caption,sign_pos,face[2]*model.scale.x,0.0)
	var axis_side := absf(sin(yaw)) > 0.5
	_solid(Vector3(rec[3],.65,rec[4]),Vector3(depth if axis_side else width,1.3,width if axis_side else depth))
	var front := holder.global_position + Vector3(sin(yaw),0,cos(yaw))*(depth*.5+.9)
	targets.append({"id":id,"label":caption,"at":front})


func _mesh_bounds(model: Node3D) -> AABB:
	var aggregate := AABB()
	var populated := false
	for n: Node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := n as MeshInstance3D
		var local := model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		aggregate = aggregate.merge(local) if populated else local
		populated = true
	return aggregate if populated else AABB(Vector3.ZERO,Vector3.ONE)


func _box(node_name: String, at: Vector3, dims: Vector3, tint: Color, solid := false) -> void:
	var m := MeshInstance3D.new()
	m.name = node_name
	var cuboid := BoxMesh.new()
	cuboid.size = dims
	m.mesh = cuboid
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	m.material_override = material
	add_child(m)
	m.position = at
	if solid:
		_solid(at,dims)


func _solid(at: Vector3, dims: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dims
	collider.shape = box
	body.add_child(collider)


func _label(parent: Node3D, value: String, at: Vector3, width: float, yaw: float) -> void:
	var sign := Label3D.new()
	sign.text = value
	sign.font_size = 68
	sign.pixel_size = width / (float(maxi(4,value.length())) * 45.0)
	sign.outline_size = 12
	sign.modulate = Color("#ffdf7b")
	sign.outline_modulate = Color("#243b63")
	parent.add_child(sign)
	sign.position = at
	sign.rotation.y = yaw
