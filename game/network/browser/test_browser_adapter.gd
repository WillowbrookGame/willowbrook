extends SceneTree
## Test the exact Godot client adapter against the Node loopback server.
const BROWSER_SESSION = preload("res://game/network/browser/browser_session.gd")
var a: Node
var b: Node
var avatar_a: CharacterBody3D
var avatar_b: CharacterBody3D
var zone_a: Node3D
var zone_b: Node3D
var hud_a: CanvasLayer
var hud_b: CanvasLayer
var deadline := 0
var phase := 0
var got_frame := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected WebSocket endpoint and fixture invite")
		quit(1)
		return
	a = BROWSER_SESSION.new()
	b = BROWSER_SESSION.new()
	root.add_child(a)
	root.add_child(b)
	zone_a = Node3D.new()
	zone_b = Node3D.new()
	root.add_child(zone_a)
	root.add_child(zone_b)
	avatar_a = CharacterBody3D.new()
	avatar_b = CharacterBody3D.new()
	hud_a = CanvasLayer.new()
	hud_b = CanvasLayer.new()
	zone_a.add_child(avatar_a)
	zone_b.add_child(avatar_b)
	zone_a.add_child(hud_a)
	zone_b.add_child(hud_b)
	a.bind_zone("town",zone_a,avatar_a,hud_a)
	b.bind_zone("town",zone_b,avatar_b,hud_b)
	avatar_a.position.x = 4
	avatar_b.position.x = 7
	b.arcade_message.connect(func(packet: Dictionary):
		if packet.get("type") == "airHockeyFrame":
			got_frame = true
	)
	a.join_web("Wave",args[1],args[0])
	b.join_web("Brook",args[1],args[0])
	deadline = Time.get_ticks_msec()+9000


func _process(_delta: float) -> bool:
	if a == null:
		return false
	if Time.get_ticks_msec() > deadline:
		push_error("Browser adapter timed out, phase %d" % phase)
		quit(1)
		return true
	if phase == 0 and a.admitted and b.admitted and _seen(a,7.0) and _seen(b,4.0):
		b.suspend_zone()
		phase = 1
	if phase == 1 and a.rows.is_empty() and b.rows.is_empty():
		zone_a = Node3D.new()
		zone_b = Node3D.new()
		root.add_child(zone_a)
		root.add_child(zone_b)
		avatar_a.reparent(zone_a,false)
		avatar_b.reparent(zone_b,false)
		hud_a = CanvasLayer.new()
		hud_b = CanvasLayer.new()
		zone_a.add_child(hud_a)
		zone_b.add_child(hud_b)
		avatar_a.position = Vector3(0,0,2.3)
		avatar_b.position = Vector3(0,0,2.3)
		a.bind_zone("arcade",zone_a,avatar_a,hud_a)
		b.bind_zone("arcade",zone_b,avatar_b,hud_b)
		phase = 2
	if phase == 2 and a.rows.size() == 1 and b.rows.size() == 1:
		a.send_arcade({"type":"airHockey","action":"join"})
		b.send_arcade({"type":"airHockey","action":"join"})
		phase = 3
	if phase == 3 and got_frame:
		b.leave_session()
		phase = 4
	if phase == 4 and a.roster.size() == 1:
		print("PASS Godot WebSocket adapter: 2 clients, scope, original arcade frames, disconnect")
		quit()
		return true
	return false


func _seen(session: Node, x: float) -> bool:
	for row: Dictionary in session.rows.values():
		if is_equal_approx(row.position.x,x):
			return true
	return false
