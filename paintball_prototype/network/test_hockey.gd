extends SceneTree
const SESSION = preload("res://paintball_prototype/network/session.gd")
const MATCH = preload("res://paintball_prototype/network/hockey_match.gd")
var session: Node
var body: CharacterBody3D
var deadline: int
var side: String
var file: String
var port: int
var phase := 0
var wait_until := 0
var round_two := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	side = args[0]
	file = args[1]
	port = int(args[2])
	deadline = Time.get_ticks_msec() + 17000
	var match_logic = MATCH.new()
	if not match_logic.join(3) or not match_logic.join(4) or match_logic.join(5):
		_fail("incorrect two-seat limit")
		return
	match_logic.aim(3,Vector2(100.0,100.0),100)
	if match_logic.targets[0] != Vector2(0.89,-0.11):
		_fail("target crossed divider")
		return
	var world := Node3D.new()
	root.add_child(world)
	body = CharacterBody3D.new()
	world.add_child(body)
	var hud := CanvasLayer.new()
	world.add_child(hud)
	session = SESSION.new()
	session.name = "HockeyTestSession"
	root.add_child(session)
	session.bind_zone("arcade",world,body,hud)
	if side == "host":
		if not session.host_session("Keeper","127.0.0.1",port):
			_fail("host could not start")
			return
		if session.hockey_join():
			_fail("host could join from across room")
			return
		body.position.z = 2.3
		if not session.hockey_join():
			_fail("host seat unavailable")
			return
		var out := FileAccess.open(file,FileAccess.WRITE)
		out.store_string(session.invite_code())
		out.close()


func _process(_dt: float) -> bool:
	if session == null:
		return false
	var now := Time.get_ticks_msec()
	if now > deadline:
		_fail("%s timed out phase=%d state=%s" % [side,phase,session.hockey_state])
		return true
	var state: Dictionary = session.hockey_state
	if side == "host":
		if phase == 0 and state.get("phase") == "playing" and state.paddles[1].x > 0.3:
			phase = 1
			# Drive deterministic scoring inside the authority test, never over network.
			session.hockey.scores[0] = 4
			session.hockey.puck = Vector2(0,0.954)
			session.hockey.serve_left = 0.0
			session.hockey.velocity = Vector2(0,2)
		if phase == 1 and state.get("round") == 2 and state.phase == "playing":
			phase = 2
			session.hockey.scores[0] = 4
			session.hockey.puck = Vector2(0,0.954)
			session.hockey.serve_left = 0.0
			session.hockey.velocity = Vector2(0,2)
		if phase == 2 and state.get("winner") == 0 and not state.ready[0]:
			session.hockey_rematch()
		if phase == 2 and state.get("round") == 1 and state.phase == "playing":
			phase = 3
		if phase == 3 and state.get("phase") == "waiting" and state.names[1] == "":
			print("PASS host: cabinet proximity, guest paddle, authoritative goals, best of three, dual rematch, peer departure")
			quit()
			return true
	else:
		if phase == 0 and FileAccess.file_exists(file):
			phase = 1
			session.join_session("Visitor","127.0.0.1",FileAccess.get_file_as_string(file),port)
		if phase == 1 and session.admitted and session.rows.size() == 1:
			phase = 2
			session.hockey_join()
		if phase == 2 and state.has("error"):
			phase = 3
			body.position.z = 2.3
			wait_until = now + 350
		if phase == 3 and now >= wait_until:
			phase = 4
			session.hockey_join()
		if phase == 4 and state.get("side") == 1 and state.get("phase") == "playing":
			session.hockey_input(Vector2(0.65,0.55))
			if state.round == 2:
				round_two = true
		if phase == 4 and state.get("phase") == "finished":
			if state.winner != 0 or state.wins != [2,0] or not round_two:
				_fail("incorrect client match result")
				return true
			session.hockey_rematch()
			phase = 5
		if phase == 5 and state.get("phase") == "playing" and state.round == 1:
			session.leave_session()
			print("PASS guest: denied away from cabinet, joined, input reached host, result streamed, rematch")
			quit()
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
