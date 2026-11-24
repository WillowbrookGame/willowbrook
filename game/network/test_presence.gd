extends SceneTree
## Use two Godot processes on the same Windows computer. See README.md.
const SESSION = preload("res://game/network/session.gd")
var session: Node
var body: CharacterBody3D
var deadline := 0
var code_path: String
var side: String
var port: int
var phase := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		_fail("Expected: host|guest, absolute temp file, UDP port")
		return
	side = args[0]
	code_path = args[1]
	port = int(args[2])
	var world := Node3D.new()
	root.add_child(world)
	body = CharacterBody3D.new()
	world.add_child(body)
	var hud := CanvasLayer.new()
	world.add_child(hud)
	session = SESSION.new()
	session.name = "LocalSessionTest"
	root.add_child(session)
	session.bind_zone("town",world,body,hud)
	deadline = Time.get_ticks_msec() + 18000
	if side == "host":
		if not session.host_session("Host", "127.0.0.1", port):
			_fail("Could not bind test host: " + str(session.status))
			return
		body.position.x = 12
		var out := FileAccess.open(code_path, FileAccess.WRITE)
		if out == null:
			_fail("Could not write temporary code")
			return
		out.store_string(session.invite_code())
		out.close()
	elif side != "guest":
		_fail("Unknown role")


func _process(_delta: float) -> bool:
	if session == null:
		return false
	if Time.get_ticks_msec() >= deadline:
		_fail("%s timed out at phase %d: %s" % [side,phase,session.status])
		return true
	if side == "host":
		if phase == 0 and session.rows.size() == 1 and _saw(7):
			phase = 1
		if phase == 1 and session.rows.is_empty() and session.roster.size() == 2:
			for row: Dictionary in session.roster:
				if row.alias == "Host 2" and row.place == "At the beach":
					phase = 2
		if phase == 2 and _saw(22):
			phase = 3
		if phase == 3 and session.rows.is_empty() and session.roster.size() == 1:
			phase = 4
		if phase == 4 and _saw(28):
			phase = 5
		if phase == 5 and session.rows.is_empty() and session.roster.size() == 1:
			print("PASS host: validate invite, deduplicate names, filter rooms, detect departure, allow rejoin")
			quit()
			return true
	else:
		if phase == 0 and FileAccess.file_exists(code_path):
			phase = 1
			if not session.join_session("Other", "127.0.0.1", "INVALID00000", port):
				_fail("Malformed test fixture invite")
				return true
		if phase == 1 and "didn’t match" in session.status:
			phase = 2
			body.position.x = 7
			if not session.join_session("Host", "127.0.0.1", FileAccess.get_file_as_string(code_path), port):
				_fail("Could not reconnect with good invite")
				return true
		if phase == 2 and _saw(12):
			if session.roster.size() != 2 or session._ghost_root.get_child_count() != 1:
				return false
			phase = 3
			session.zone = "beach"
		if phase == 3 and session.rows.is_empty() and session._ghost_root.get_child_count() == 0:
			# Let server receive and filter snapshots for several network ticks.
			phase = 4
			create_timer(0.7).timeout.connect(func():
				body.position.x = 22
				session.zone = "town"
				phase = 5
			)
		if phase == 5 and _saw(12):
			phase = 6
			create_timer(0.45).timeout.connect(func():
				session.leave_session()
				create_timer(0.7).timeout.connect(func():
					body.position.x = 28
					session.join_session("Host", "127.0.0.1", FileAccess.get_file_as_string(code_path), port)
					phase = 7
				)
			)
		if phase == 7 and _saw(12):
			phase = 8
			create_timer(0.45).timeout.connect(func():
				session.leave_session()
				print("PASS guest: rejected wrong invite, animated visible peer, filtered room, joined again")
				quit()
			)
	return false


func _saw(x: float) -> bool:
	for row: Dictionary in session.rows.values():
		if is_equal_approx(row.position.x, x):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
