extends Control

const ACTION_GAME = preload("res://paintball_prototype/arcade/actions.gd")
const MEMORY_ART := "res://paintball_prototype/arcade/arcade-memory/"
const BACKBOARD := Rect2(416,68,15,60)
const BALL_RADIUS := 9.0
const LEFT_PADDLE := Vector2(95,180)
const RIGHT_PADDLE := Vector2(387,180)
const ORIGINAL_SCREENS := ["basketball","memory","claw","air-hockey"]
const BOARD := Vector2(480,360)
var action_game: RefCounted
var session: Node
var hockey: Dictionary = {}
var hockey_target := Vector2(-.6,0)
var send_clock := 0.0
var held: Dictionary = {}
var state: Dictionary
var kind := ""
var art: Array[Texture2D] = []
var rng := RandomNumberGenerator.new()
var pointer_id := -2
var offset := Vector2.ZERO
var ratio := 1.0

func _ready() -> void:
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP

func begin(id: String) -> void:
	leave_hockey()
	clear_inputs()
	kind = id
	action_game = null
	state = {"done":false,"msg":""}
	match kind:
		"basketball":
			state.merge({"time":60.0,"x":90.0,"arc":.92,"charge":0.0,"shots":[],"score":0,"combo":1})
		"memory":
			var cards := [0,0,1,1,2,2,3,3,4,4,5,5]
			for i: int in range(11,0,-1):
				var j := rng.randi_range(0,i)
				var t: int = cards[j]
				cards[j] = cards[i]
				cards[i] = t
			state.merge({"cards":cards,"found":[],"open":[],"selected":0,"delay":0.0,"score":0})
			if art.is_empty():
				for name: String in ["elephant","frog","giraffe","penguin","rabbit","whale"]:
					art.append(load(MEMORY_ART + name + ".png") as Texture2D)
		"claw":
			state.merge({"x":65.0,"y":56.0,"phase":"right","toy":-1,"collected":0,"tries":0,
				"positions":[Vector2(135,135),Vector2(212,238),Vector2(300,177),Vector2(386,130),Vector2(347,249),Vector2(112,244)],
				"gone":[],"timer":0.0})
		"air-hockey":
			state.merge({"player":LEFT_PADDLE,"enemy":RIGHT_PADDLE,"target":LEFT_PADDLE,"puck":Vector2(240,180),
				"velocity":Vector2.ZERO,"score":[0,0],"round":1,"wins":[0,0],"between":false,"serve":.8})
		_:
			action_game = ACTION_GAME.new()
			action_game.setup(kind)
	queue_redraw()

func bind_hockey(connection: Node) -> void:
	session = connection
	hockey.clear()
	hockey_target = Vector2(-.6,0)
	send_clock = 0.0
	session.hockey_changed.connect(_hockey_update)
	session.hockey_join()


func leave_hockey() -> void:
	if session != null:
		session.hockey_changed.disconnect(_hockey_update)
		session.hockey_leave()
	session = null
	hockey.clear()


func _hockey_update(snapshot: Dictionary) -> void:
	var old_side: int = hockey.get("side",-1)
	var old_round: int = hockey.get("round",-1)
	var was_playing: bool = hockey.get("phase","") == "playing"
	hockey = snapshot.duplicate()
	var new_side: int = hockey.get("side",-1)
	if new_side>=0 and hockey.get("phase")=="playing" and (new_side!=old_side or old_round!=hockey.get("round") or not was_playing):
		held.clear()
		pointer_id = -2
		var pads: Array = hockey.get("paddles",[])
		var paddle: Vector2 = pads[new_side] if pads.size()>new_side else Vector2(0,-.65 if new_side==0 else .65)
		hockey_target = Vector2(paddle.y,paddle.x)
		send_clock = 0.0
	queue_redraw()


func message() -> String:
	if session != null:
		if hockey.has("error"):
			return String(hockey.error)
		var online_round: int = hockey.get("round",1)
		match String(hockey.get("phase","waiting")):
			"playing":
				var names: Array = hockey.get("names", ["", ""])
				var side: int = clampi(hockey.get("side",0),0,1)
				var other: String = String(names[1-side])
				var colour := "blue" if side == 0 else "red"
				return "Round %d · You are %s · vs. %s" % [online_round, colour, other if not other.is_empty() else "your friend"]
			"round_over":
				return "Round %d complete. Next round starting..." % online_round
			"finished":
				return ("You win!" if hockey.get("winner",-1) == hockey.get("side",-2) else "Your friend wins!") + " Choose Rematch to play again."
		return "Waiting for a friend to join this cabinet..."
	if action_game != null:
		return action_game.message()
	if not String(state.get("msg","")).is_empty():
		return state.msg
	match kind:
		"basketball":
			return "Hold Shoot to charge. Release to shoot."
		"memory":
			return "Flip two cards and find all six pairs."
		"claw":
			return {"right":"Hold Right, then release to set position.","up":"Hold Up, then release to drop.","drop":"Claw descending…","collect":"Tap the chute or press Collect."}.get(state.phase,"")
		"air-hockey":
			return "Practice vs. computer • first to 5 • best of three"
	return ""

func clear_inputs() -> void:
	held.clear()
	pointer_id = -2
	if action_game != null:
		for a: String in ["left","right","up","down","action"]:
			action_game.input(a,false)
	if state.has("charge"):
		state.charge = 0.0

func play_input(a: String, down: bool) -> void:
	if action_game != null:
		action_game.input(a,down)
		return
	if kind.is_empty() or state.done:
		return
	var was_down := held.has(a)
	if down:
		held[a] = true
	else:
		held.erase(a)
	if was_down == down:
		return
	match kind:
		"memory":
			if down:
				match a:
					"left": state.selected = (state.selected+11)%12
					"right": state.selected = (state.selected+1)%12
					"up": state.selected = (state.selected+8)%12
					"down": state.selected = (state.selected+4)%12
					"action": _flip(state.selected)
		"basketball":
			if a == "action" and not down:
				_shoot()
		"claw":
			if a == "right" and not down and state.phase == "right":
				state.phase = "up"
			if a == "up" and not down and state.phase == "up":
				state.phase = "drop"
				state.timer = .48
			if a == "action" and down and state.phase == "collect":
				_collect()
		"air-hockey":
			if a == "action" and down and state.between:
				state.between = false
				state.msg = ""
				state.round += 1
				state.score = [0,0]
				held.clear()
				pointer_id = -2
				state.player = LEFT_PADDLE
				state.target = LEFT_PADDLE
				state.enemy = RIGHT_PADDLE
				_serve()
	queue_redraw()

func _flip(i: int) -> void:
	if state.done or state.delay > 0 or i in state.open or i in state.found:
		return
	state.open.append(i)
	if state.open.size() < 2:
		return
	if state.cards[state.open[0]] == state.cards[state.open[1]]:
		state.found.append_array(state.open)
		state.open.clear()
		state.score += 1
		state.done = state.score == 6
		if state.done:
			state.msg = "All six pairs found!"
	else:
		state.delay = .85

func _shoot() -> void:
	var charge: float = state.charge
	state.charge = 0.0
	if charge <= 0.0 or state.time <= 0.0 or state.shots.size() >= 4:
		return
	var start := Vector2(float(state.x),290)
	var speed := lerpf(240,670,charge)
	state.shots.append({"pos":start,"v":Vector2(cos(state.arc),-sin(state.arc))*speed,"scored":false})

func _collect() -> void:
	state.collected += 1
	state.toy = -1
	if state.tries >= 4:
		state.done = true
		state.msg = "Round complete: %d toys. Prizes stay in the arcade." % state.collected
	else:
		_reset_claw()

func _reset_claw() -> void:
	state.phase = "right"
	state.x = 65.0
	state.y = 56.0

func _serve() -> void:
	state.puck = Vector2(240,180)
	state.velocity = Vector2.ZERO
	state.serve = .8

func _direction(a: String,b: String) -> float:
	return float(int(held.has(a))-int(held.has(b)))

func step(dt: float) -> void:
	if session != null:
		send_clock += dt
		var keys := Vector2(_direction("right","left"),_direction("down","up"))
		if keys != Vector2.ZERO:
			hockey_target += keys.normalized() * dt * 1.8
		if hockey.get("side",-1)==0:
			hockey_target.x = clampf(hockey_target.x,-1.0,0.0)
		else:
			hockey_target.x = clampf(hockey_target.x,0.0,1.0)
		hockey_target.y = clampf(hockey_target.y,-1.0,1.0)
		if send_clock >= .04 and hockey.get("phase","") == "playing":
			send_clock = 0.0
			session.hockey_input(Vector2(hockey_target.y,hockey_target.x))
		queue_redraw()
		return
	if action_game != null:
		action_game.tick(dt)
	elif not kind.is_empty() and not state.done:
		match kind:
			"memory":
				if state.delay > 0:
					state.delay = maxf(0.0,state.delay-dt)
					if state.delay == 0:
						state.open.clear()
			"basketball":
				_step_basketball(dt)
			"claw":
				_step_claw(dt)
			"air-hockey":
				for i: int in 3:
					_step_hockey(dt/3)
	queue_redraw()

func _step_basketball(dt: float) -> void:
	state.time = maxf(0,state.time-dt)
	state.x = clampf(state.x + _direction("right","left")*175*dt,36,330)
	state.arc = clampf(state.arc + _direction("up","down")*.8*dt,.38,1.43)
	if held.has("action"):
		state.charge = clampf(state.charge+dt*.95,.04,1.0)
	var any_scored := false
	for shot: Dictionary in state.shots.duplicate():
		var before: Vector2 = shot.pos
		var velocity: Vector2 = shot.v
		velocity.y += 575.0*dt
		var at := before + velocity*dt
		var contact := _backboard_contact(before,at)
		if contact != Vector2.ZERO:
			var fraction := contact.length()
			var normal := contact.normalized()
			at = before.lerp(at,fraction) + normal*.05
			velocity -= normal * velocity.dot(normal)*1.62
			at += velocity*dt*(1.0-fraction)
		if not shot.scored and before.y < 129 and at.y >= 129 and at.x > 374 and at.x < 417:
			shot.scored = true
			state.score += 2*int(state.combo)
			state.combo = mini(5,state.combo+1)
			state.msg = "Swish! Combo ×%d" % state.combo
			any_scored = true
		if at.y > 360 or at.x > 500 or at.x < -20:
			state.shots.erase(shot)
			if not shot.scored and not any_scored:
				state.combo = 1
				state.msg = "Try a different arc or charge."
		shot.pos = at
		shot.v = velocity
	if state.time == 0 and state.shots.is_empty():
		state.done = true
		state.msg = "Time! %d points." % state.score


func _backboard_contact(from: Vector2,to: Vector2) -> Vector2:
	# Sweep the ball center against the same drawn board inflated by the ball radius.
	var box := BACKBOARD.grow(BALL_RADIUS)
	var movement := to-from
	var axis := Vector2.ZERO
	var first := 1.01
	for candidate: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		if movement.dot(candidate)>=0.0:
			continue
		var plane := (box.position.x if candidate.x<0 else box.end.x) if candidate.x!=0 else (box.position.y if candidate.y<0 else box.end.y)
		var from_axis := from.x if candidate.x!=0 else from.y
		var motion_axis := movement.x if candidate.x!=0 else movement.y
		var t := (plane-from_axis)/motion_axis
		if t<0.0 or t>1.0 or t>=first:
			continue
		var contact := from.lerp(to,t)
		if candidate.x!=0 and contact.y>=box.position.y and contact.y<=box.end.y or candidate.y!=0 and contact.x>=box.position.x and contact.x<=box.end.x:
			axis = candidate
			first = t
	return axis*maxf(first,0.00001) if axis!=Vector2.ZERO else Vector2.ZERO


func wants_survivor_action() -> bool:
	return kind=="survivors" and action_game!=null and bool(action_game.s.get("upgrade",false))


func _step_claw(dt: float) -> void:
	match state.phase:
		"right":
			if held.has("right"):
				state.x = minf(430,float(state.x)+dt*162.0)
		"up":
			if held.has("up"):
				state.y = minf(278,float(state.y)+dt*154.0)
		"drop":
			state.timer -= dt
			if state.timer <= 0.0:
				state.tries += 1
				for i: int in state.positions.size():
					var p: Vector2 = state.positions[i]
					if i not in state.gone and p.distance_to(Vector2(state.x,state.y)) < 28:
						state.toy = i
						state.gone.append(i)
						state.phase = "collect"
						return
				if state.tries >= 4:
					state.done = true
					state.msg = "Round complete: %d toys. Prizes stay in the arcade." % state.collected
				else:
					_reset_claw()

func _step_hockey(dt: float) -> void:
	if state.between or state.done:
		return
	var movement := Vector2(_direction("right","left"),_direction("down","up"))
	if movement != Vector2.ZERO:
		state.target = state.player + movement.normalized()*370*dt
	var wanted: Vector2 = state.target
	wanted = wanted.clamp(Vector2(27,35),Vector2(218,325))
	var p1: Vector2 = state.player
	var p2: Vector2 = state.enemy
	var disk: Vector2 = state.puck
	var v: Vector2 = state.velocity
	state.player = p1.move_toward(wanted,560*dt)
	var bot_target := Vector2(388,180).lerp(disk,.65)
	if disk.x > 270 and v.x >= -45:
		bot_target = disk + Vector2(26,0)
	bot_target = bot_target.clamp(Vector2(262,35),Vector2(460,325))
	state.enemy = p2.move_toward(bot_target,(168+22*int(state.round))*dt)
	if state.serve > 0:
		state.serve -= dt
		if state.serve <= 0:
			state.velocity = Vector2(145 if rng.randi_range(0,1)==1 else -145,rng.randf_range(-115,115))
		return
	disk += v*dt
	for paddle: Array in [[state.player,p1],[state.enemy,p2]]:
		var paddle_pos: Vector2 = paddle[0]
		if disk.distance_squared_to(paddle_pos) >= 32*32:
			continue
		var norm := (disk-paddle_pos).normalized()
		if norm == Vector2.ZERO:
			norm = Vector2.RIGHT if paddle_pos.x < 240 else Vector2.LEFT
		disk = paddle_pos+norm*32.1
		var old: Vector2 = paddle[1]
		var speed := (paddle_pos-old) / maxf(dt,.001)
		v = (v.bounce(norm) if v.dot(norm)<0 else v) + norm*96 + speed*.66
		v = v.limit_length(670)
	if disk.y < 23 or disk.y > 337:
		disk.y = clampf(disk.y,23,337)
		v.y *= -1
	if disk.x < 20 or disk.x > 460:
		if absf(disk.y-180) < 63:
			if disk.x < 10 or disk.x > 470:
				_goal(1 if disk.x < 10 else 0)
				return
		else:
			disk.x = clampf(disk.x,20,460)
			v.x *= -1
	state.puck = disk
	state.velocity = v*(1.0-dt*.12)
	if state.velocity.length() < 22.0:
		state.velocity = Vector2(120 if disk.x>240 else -120,12)

func _goal(side: int) -> void:
	state.score[side] += 1
	if state.score[side] < 5:
		_serve()
		return
	state.wins[side] += 1
	var name := "You win" if side == 0 else "Computer wins"
	if state.wins[side] >= 2:
		state.done = true
		state.msg = "%s the match, %d–%d." % ["You win" if state.wins[0] > state.wins[1] else "Computer wins",state.wins[0],state.wins[1]]
	else:
		state.between = true
		state.msg = "%s round %d. Choose Next round." % [name,state.round]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if pointer_id == -2:
				pointer_id = event.index
				_pointer(event.position,true)
		elif pointer_id == event.index:
			pointer_id = -2
		accept_event()
	elif event is InputEventScreenDrag and event.index == pointer_id:
		_pointer(event.position,false)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		pointer_id = -1 if event.pressed else -2
		if event.pressed:
			_pointer(event.position,true)
		accept_event()
	elif event is InputEventMouseMotion and pointer_id == -1:
		_pointer(event.position,false)
		accept_event()

func _pointer(pos: Vector2, pressed: bool) -> void:
	var at := (pos-offset)/maxf(.001,ratio)
	if not Rect2(Vector2.ZERO,BOARD).has_point(at):
		return
	if session != null:
		hockey_target = (at - Vector2(240,180)) / Vector2(230,165)
		return
	if action_game != null:
		if pressed or kind != "maze-chase":
			action_game.pointer(at)
		return
	if kind.is_empty() or state.done:
		return
	match kind:
		"memory":
			if pressed:
				for i: int in 12:
					if _card_rect(i).has_point(at):
						state.selected = i
						_flip(i)
		"claw":
			if pressed and state.phase == "collect" and at.y >= 284:
				_collect()
		"air-hockey":
			state.target = at
	queue_redraw()

func _draw() -> void:
	ratio = minf(size.x/BOARD.x,size.y/BOARD.y)
	offset = (size-BOARD*ratio)*.5
	draw_set_transform(offset,0,Vector2.ONE*ratio)
	if action_game != null:
		action_game.draw(self)
		return
	match kind:
		"memory": _draw_memory()
		"basketball": _draw_basketball()
		"claw": _draw_claw()
		"air-hockey": _draw_hockey()

func _card_rect(i: int) -> Rect2:
	return Rect2(30+(i%4)*110,45+int(i/4.0)*98,96,84)

func words(at: Vector2, value: String, shade := Color("#223744"), point_size := 18) -> void:
	draw_string(ThemeDB.fallback_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size,shade)

func _draw_memory() -> void:
	draw_rect(Rect2(Vector2.ZERO,BOARD),Color("#e8f3ec"))
	for i: int in 12:
		var rect := _card_rect(i)
		var open_card: bool = i in state.open or i in state.found
		draw_rect(rect,Color("#416f82") if not open_card else Color("#fff8ec"))
		if open_card and not art.is_empty() and art[state.cards[i]] != null:
			draw_texture_rect(art[state.cards[i]],Rect2(rect.position+Vector2(12,3),Vector2(72,72)),false)
		elif not open_card:
			words(rect.position+Vector2(37,53),"?",Color.WHITE,32)
		if i == state.selected:
			draw_rect(rect.grow(3),Color("#f2b836"),false,3)
	words(Vector2(30,26),"Pairs %d/6" % state.score)

func _draw_basketball() -> void:
	draw_rect(Rect2(Vector2.ZERO,BOARD),Color("#203e69"))
	for z: int in 6:
		draw_rect(Rect2(0,66+16*z,480,8),Color("#355476"))
	draw_rect(Rect2(0,296,480,64),Color("#c7794c"))
	draw_line(Vector2(0,319),Vector2(480,319),Color("#ffd998"),3)
	draw_rect(BACKBOARD,Color("#eee8cc"))
	draw_line(Vector2(373,129),Vector2(419,129),Color("#f38b50"),5,true)
	for x: int in [376,386,396,406,415]:
		draw_line(Vector2(x,131),Vector2(x*.8+79,155),Color("#f4ebd8"),2)
	var player_at := Vector2(float(state.x),290)
	draw_rect(Rect2(player_at+Vector2(-10,-33),Vector2(18,38)),Color("#c2648f"))
	draw_circle(player_at+Vector2(0,-42),9,Color("#efd2a8"))
	draw_line(player_at,player_at+Vector2(cos(state.arc),-sin(state.arc))*47,Color("#efc771"),2,true)
	draw_circle(player_at,8,Color("#e7954b"))
	draw_rect(Rect2(player_at+Vector2(-17,12),Vector2(45,5)),Color("#472c5a"))
	draw_rect(Rect2(player_at+Vector2(-17,12),Vector2(45*state.charge,5)),Color("#f9d273"))
	for shot: Dictionary in state.shots:
		draw_circle(shot.pos,BALL_RADIUS,Color("#ec9559"))
		draw_arc(shot.pos,6.5,2,PI*1.8,13,Color("#85452f"),1.4,true)
	words(Vector2(17,29),"%03d   %02ds   ×%d" % [state.score,ceili(state.time),state.combo],Color("#f4e5a9"),23)

func _draw_claw() -> void:
	draw_rect(Rect2(Vector2.ZERO,BOARD),Color("#dedff7"))
	draw_rect(Rect2(45,54,390,229),Color("#a4bfda"))
	draw_rect(Rect2(60,66,360,200),Color("#bbd8ea"))
	for i: int in state.positions.size():
		if i in state.gone:
			continue
		var p: Vector2 = state.positions[i]
		_draw_toy(p,i)
	var claw_at := Vector2(state.x,state.y) if state.phase != "collect" else Vector2(59,69)
	draw_line(Vector2(claw_at.x,42),claw_at,Color("#506578"),4)
	draw_line(claw_at+Vector2(-14,0),claw_at+Vector2(-8,13),Color("#506578"),4)
	draw_line(claw_at+Vector2(14,0),claw_at+Vector2(8,13),Color("#506578"),4)
	draw_rect(Rect2(164,289,152,58),Color("#563e67"))
	if state.phase == "collect":
		_draw_toy(Vector2(240,317),state.toy)
	words(Vector2(16,27),"Toys %d  |  Turns %d/4" % [state.collected,state.tries])

func _draw_toy(p: Vector2,i: int) -> void:
	var clr: Color = [Color("#e090af"),Color("#67b891"),Color("#d8af65"),Color("#6f99d5")][i%4]
	draw_circle(p,16,clr)
	draw_circle(p+Vector2(-11,-12),8,clr)
	draw_circle(p+Vector2(11,-12),8,clr)
	draw_circle(p+Vector2(-5,-2),2,Color("#f2eedf"))
	draw_circle(p+Vector2(5,-2),2,Color("#f2eedf"))

func _hockey_screen(at: Vector2) -> Vector2:
	return Vector2(240,180) + Vector2(at.y,at.x) * Vector2(230,165)

func _draw_hockey() -> void:
	var rnd: int = state.round
	var score: Array = state.score
	var first: Vector2 = state.player
	var second: Vector2 = state.enemy
	var disk: Vector2 = state.puck
	if session != null:
		rnd = int(hockey.get("round",1))
		score = hockey.get("scores",[0,0])
		var positions: Array = hockey.get("paddles",[Vector2(0,-.65),Vector2(0,.65)])
		first = _hockey_screen(positions[0])
		second = _hockey_screen(positions[1])
		disk = _hockey_screen(hockey.get("puck",Vector2.ZERO))
	var palette: Array = [["#c5e9f1","#639bbd"],["#9ae0ce","#408790"],["#eed49c","#b38858"]][clampi(rnd,1,3)-1]
	draw_rect(Rect2(Vector2.ZERO,BOARD),Color(palette[0]))
	var markings := Color(palette[1])
	draw_rect(Rect2(11,15,458,330),markings,false,3)
	draw_line(Vector2(240,15),Vector2(240,345),markings,3)
	draw_arc(Vector2(240,180),52,0,TAU,44,markings,3,true)
	draw_rect(Rect2(2,114,14,132),Color("#3e78c2"))
	draw_rect(Rect2(464,114,14,132),Color("#c65466"))
	for paddle: Array in [[first,Color("#458bdb")],[second,Color("#dc6972")]]:
		draw_circle(paddle[0],22,paddle[1])
		draw_circle(paddle[0],13,paddle[1].darkened(.25))
	draw_circle(disk,10,Color("#273750"))
	words(Vector2(18,48),"%d" % score[0],Color("#2b527d"),28)
	words(Vector2(415,48),"%d" % score[1],Color("#913e4e"),28)
	words(Vector2(205,42),"Round %d" % rnd,Color("#3d525d"))
