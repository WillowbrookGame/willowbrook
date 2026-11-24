extends Node3D
## Authoritative virtual match. No account persistence/open sockets or user-facing HUD.
const YARD_SCENE = preload("res://game/warehouse_yard.tscn")
const RULES = preload("res://game/match_rules.gd")
const PLAYER = preload("res://game/player.gd")
const YARD = preload("res://game/warehouse_yard.gd")
const ROUND_MS := 180000
const HOLD_MS := 20000
const LOAD_MS := 12000
const PAINT_COOLDOWN_MS := 160
const INPUT_STALE_MS := 350
const BOT_NAMES := ["Pip","Scout","Sunny"]

var phase := "idle"
var deadline := 0
var slots: Dictionary = {}
var host_slot := ""
var rules := RULES.new()
var next_events: Array[Dictionary] = []
var arena: Node3D
var _spawns: Array[String] = []
var _room_time := 0
var _event_id := 0
var _next_bot_id := 0

func _ready() -> void:
	# Share only the yard; the client scene owns its own HUD, camera and exit.
	arena = Node3D.new()
	arena.name = "PaintballArena"
	arena.add_child(YARD_SCENE.instantiate())
	add_child(arena)
	var exit_collision := StaticBody3D.new()
	var mask := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.65,3,.24)
	mask.shape = shape
	exit_collision.position = YARD.TOWN_EXIT+Vector3(0,1.5,.34)
	exit_collision.add_child(mask)
	arena.add_child(exit_collision)

func open(humans: Array, host: String, now: int) -> bool:
	if phase != "idle" or humans.size()<2 or humans.size()>4:
		return false
	var seen := {}
	for row: Variant in humans:
		if not row is Dictionary or not row.get("slot") is String or not row.get("alias") is String:
			return false
		if row.slot.is_empty() or row.slot.length()>24 or row.slot.begins_with("npc_") or row.alias.is_empty() or row.alias.length()>32 or seen.has(row.slot):
			return false
		seen[row.slot] = true
	if not seen.has(host):
		return false
	host_slot = host
	_room_time = now
	for row: Dictionary in humans:
		_add_slot(row.slot,row.alias,false)
	_fill_bots()
	phase = "loading"
	deadline = now+LOAD_MS
	return true

func _add_slot(id: String, alias: String, bot: bool) -> void:
	var body := PLAYER.new()
	body.arena_movement = true
	body.floor_snap_length = .47
	body.collision_layer = 0
	body.collision_mask = 7
	body.world_bounds = YARD.WORLD_BOUNDS
	var shape := CapsuleShape3D.new()
	shape.radius = .31
	shape.height = 1.55
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .79
	body.add_child(collider)
	arena.add_child(body)
	body.set_physics_process(false)
	var idx := _spawns.size()
	_spawns.append(id)
	body.position = YARD.SPAWNS[idx]
	slots[id] = {"id":id,"alias":alias,"bot":bot,"body":body,"connected":true,"ready":bot,"hold":0,"retired":false,"last_input":-1,"last_at":-1,"axis":Vector2.ZERO,"pitch":0.0,"jump":false,"paint":false,"next_paint":0,"route":idx*3,"ticks_blocked":0}
	rules.points[id] = 0
	rules.totals[id] = 0

func _fill_bots() -> void:
	var used := {}
	for id: String in _spawns:
		if slots[id].bot: used[slots[id].alias]=true
	while _spawns.size()<4:
		for bot_alias: String in BOT_NAMES:
			if not used.has(bot_alias):
				_next_bot_id += 1
				_add_slot("npc_%d" % _next_bot_id,bot_alias,true)
				used[bot_alias]=true
				break

func ready_slot(id: String, now: int) -> bool:
	var s: Dictionary = slots.get(id,{})
	if phase!="loading" or now>=deadline or s.is_empty() or s.bot or not s.connected:
		return false
	s.ready=true
	for current: String in _spawns:
		if not slots[current].ready or not slots[current].connected:
			return true
	_begin_round(now)
	return true

func _begin_round(now: int) -> void:
	if not rules.start_round():
		return
	phase="playing"
	deadline=now+ROUND_MS
	for i in _spawns.size():
		var s: Dictionary=slots[_spawns[i]]
		var body: PLAYER=s.body
		body.position=YARD.SPAWNS[i]
		body.velocity=Vector3.ZERO
		body.touch_motion=Vector2.ZERO
		body.movement_locked=true
		body.movement_locked=false
		body.rotation.y=0
		body.collision_layer=4 if s.connected else 0
		s.axis=Vector2.ZERO
		s.paint=false
		s.jump=false
		s.route=i*3
		s.ticks_blocked=0
		s.next_paint=now+(1000+i*200 if s.bot else 0)
	_emit("round",{"round":rules.round_number})

func next_round(id: String, now: int) -> bool:
	if phase!="between" or id!=host_slot or not _can_play(id):
		return false
	for s: Dictionary in slots.values():
		if not s.bot and not s.connected and not s.retired and s.hold>now:
			return false
	for id_now: String in _spawns.duplicate():
		if not slots[id_now].connected:
			_retire(slots[id_now])
	_fill_bots()
	_begin_round(now)
	return true

func _can_play(id: String) -> bool:
	var s: Dictionary=slots.get(id,{})
	return not s.is_empty() and not s.bot and s.connected and not s.retired

func input(id: String, frame: Dictionary, now: int) -> bool:
	if phase!="playing" or now>=deadline or not _can_play(id):
		return false
	if frame.size()!=7 or frame.get("jump") is not bool or frame.get("paint") is not bool:
		return false
	for k in ["sequence","x","z","yaw","pitch"]:
		if not (frame.get(k) is float or frame.get(k) is int) or not is_finite(float(frame[k])):
			return false
	var s: Dictionary=slots[id]
	var seq := int(frame.sequence)
	var at := Vector2(float(frame.x),float(frame.z))
	if float(seq)!=float(frame.sequence) or seq<=int(s.last_input) or seq>2147483647 or absf(at.x)>1.0 or absf(at.y)>1.0 or absf(float(frame.yaw))>PI or absf(float(frame.pitch))>1.1:
		return false
	s.last_input=seq
	s.last_at=now
	s.axis=at.limit_length()
	s.pitch=frame.pitch
	s.body.rotation.y=float(frame.yaw)
	s.jump=s.jump or frame.jump
	s.paint=s.paint or frame.paint
	return true

func disconnect_player(id: String, now: int) -> void:
	if not _can_play(id): return
	var s: Dictionary=slots[id]
	s.connected=false
	s.hold=now+HOLD_MS
	s.body.collision_layer=0
	s.body.velocity=Vector3.ZERO
	s.axis=Vector2.ZERO
	s.paint=false
	s.jump=false
	_choose_host()

func reconnect(id: String, now: int) -> bool:
	var s: Dictionary=slots.get(id,{})
	if s.is_empty() or s.bot or s.connected or s.retired or now>=int(s.hold) or phase in ["abandoned","finished"]:
		return false
	s.connected=true
	s.hold=0
	s.body.collision_layer=4 if phase=="playing" else 0
	s.last_input=-1
	s.last_at=-1
	_choose_host()
	return true

func leave(id: String) -> Dictionary:
	var s: Dictionary=slots.get(id,{})
	if s.is_empty() or s.bot or s.retired:
		return {"ok":false}
	_retire(s)
	_choose_host()
	_check_abandon()
	return {"ok":true,"returnTown":true}

func _retire(s: Dictionary) -> void:
	s.connected=false
	s.hold=0
	s.retired=true
	s.body.collision_layer=0
	s.body.velocity=Vector3.ZERO
	_spawns.erase(s.id)

func _choose_host() -> void:
	if _can_play(host_slot): return
	host_slot=""
	for id: String in _spawns:
		if _can_play(id):
			host_slot=id
			return

func _check_abandon() -> void:
	if phase not in ["loading","playing","between"]: return
	var remaining := 0
	for id: String in _spawns:
		if not slots[id].bot and not slots[id].retired:
			remaining+=1
	if remaining>0 and (phase!="loading" or remaining>=2): return
	phase="abandoned"
	_emit("abandoned",{"message":"Not enough players are still in this match."})

func step(delta: float, now: int) -> void:
	if phase in ["idle","abandoned","finished"] or now<_room_time:
		return
	_room_time=now
	for id: String in _spawns.duplicate():
		var s: Dictionary=slots[id]
		if not s.bot and not s.connected and now>=int(s.hold):
			_retire(s)
	_check_abandon()
	if phase=="loading" and now>=deadline:
		phase="abandoned"
		_emit("abandoned",{"message":"The arena did not finish loading. Return to Town and try again."})
	if phase!="playing": return
	if now>=deadline:
		rules.tick(rules.remaining)
		phase="finished" if rules.phase==RULES.Phase.FINISHED else "between"
		for id: String in _spawns:
			slots[id].body.collision_layer=0
			slots[id].body.velocity=Vector3.ZERO
		_emit("results",{"round":rules.round_number,"rankings":_rank(phase=="finished")})
		return
	rules.remaining=float(deadline-now)/1000.
	if host_slot.is_empty(): return
	var dt := clampf(delta,0.0,.05)
	if dt<=0.0: return
	for id: String in _spawns:
		var s: Dictionary=slots[id]
		if not s.connected: continue
		var body: PLAYER=s.body
		if s.bot:
			_bot(s,dt,now)
		else:
			var fresh: bool=now-int(s.last_at)<=INPUT_STALE_MS
			body.touch_motion=s.axis if fresh else Vector2.ZERO
			if fresh and s.jump: body.request_jump()
			body._physics_process(dt)
			if fresh and s.paint and now>=int(s.next_paint):
				var aim := (Basis(Vector3.UP,body.rotation.y)*Basis(Vector3.RIGHT,float(s.pitch)))*Vector3.FORWARD
				_tag_ray(s,aim,now)
			s.jump=false
			s.paint=false

func _bot(s: Dictionary, dt: float, now: int) -> void:
	var body: PLAYER=s.body
	var goal: Vector3=YARD.PATROL[int(s.route)%YARD.PATROL.size()]
	var offset:=goal-body.position
	offset.y=0
	if offset.length_squared()<1.2 or int(s.ticks_blocked)>48:
		s.route=int(s.route)+3
		s.ticks_blocked=0
	if offset.length_squared()>.01:
		var desired:=atan2(-offset.x,-offset.z)
		body.rotation.y=rotate_toward(body.rotation.y,desired,7.0*dt)
	body.touch_motion=Vector2(0,-.57)
	body._physics_process(dt)
	s.ticks_blocked=int(s.ticks_blocked)+1 if body.get_real_velocity().length()<.45 else 0
	if now<int(s.next_paint): return
	s.next_paint=now+1050
	var nearest: PLAYER
	var best:=15.0
	for id: String in _spawns:
		var candidate: Dictionary=slots[id]
		if candidate.id==s.id or not candidate.connected: continue
		var target: PLAYER=candidate.body
		var distance:=body.position.distance_to(target.position)
		if distance>=best: continue
		var hit:=_ray(body,body.position+Vector3.UP*1.05,target.position+Vector3.UP*.94)
		if hit.get("collider")==target:
			best=distance
			nearest=target
	if is_instance_valid(nearest):
		var aim:=nearest.position-body.position-Vector3.UP*.08
		body.rotation.y=atan2(-aim.x,-aim.z)
		_tag_ray(s,aim.normalized(),now)

func _ray(body: PLAYER, from: Vector3, to: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,5,[body.get_rid()])
	return arena.get_world_3d().direct_space_state.intersect_ray(query)

func _tag_ray(shooter: Dictionary, direction: Vector3, now: int) -> void:
	if phase!="playing" or now>=deadline or not shooter.connected: return
	var body: PLAYER=shooter.body
	shooter.next_paint=now+(1050 if shooter.bot else PAINT_COOLDOWN_MS)
	var origin:=body.position+Vector3.UP*1.05
	var hit:=_ray(body,origin,origin+direction*42.)
	var endpoint: Vector3=hit.get("position",origin+direction*42.)
	var tagged: String=""
	for id: String in _spawns:
		if slots[id].connected and slots[id].body==hit.get("collider") and rules.tag(shooter.id,id):
			tagged=id
			break
	_emit("paint",{"slot":shooter.id,"tagged":tagged,"from":_vec(origin),"to":_vec(endpoint)})

func _emit(kind: String, fields: Dictionary) -> void:
	_event_id+=1
	var event: Dictionary={"eid":_event_id,"kind":kind}
	event.merge(fields)
	if next_events.size()>=48: next_events.pop_front()
	next_events.append(event)

func _rank(total: bool) -> Array[Dictionary]:
	var values: Dictionary=rules.totals if total else rules.points
	var ids:=values.keys()
	ids.sort_custom(func(a,b):
		if values[a]!=values[b]: return values[a]>values[b]
		return String(slots[a].alias).naturalnocasecmp_to(String(slots[b].alias))<0)
	var rows: Array[Dictionary]=[]
	var prior:=-1
	var rank:=0
	for i in ids.size():
		var id: String=ids[i]
		var points: int=values[id]
		if prior!=points: rank=i+1
		rows.append({"slot":id,"alias":slots[id].alias,"score":points,"rank":rank,"bot":slots[id].bot,"left":slots[id].retired})
		prior=points
	return rows

func _vec(v: Vector3) -> Array[float]:
	return [v.x,v.y,v.z]

func snapshot(id: String, now: int) -> Dictionary:
	if not _can_play(id): return {}
	var list: Array[Dictionary]=[]
	for sid: String in _spawns:
		var s: Dictionary=slots[sid]
		var body: PLAYER=s.body
		list.append({"slot":sid,"alias":s.alias,"bot":s.bot,"connected":s.connected,"ready":s.ready,"position":_vec(body.position),"yaw":body.rotation.y,"grounded":body.is_on_floor(),"moving":body.active,"points":int(rules.points.get(sid,0)),"total":int(rules.totals.get(sid,0))})
	return {"phase":phase,"hostSlot":host_slot,"selfSlot":id,"round":rules.round_number,"remainingMs":maxi(0,deadline-now) if phase in ["playing","loading"] else 0,"players":list,"ranking":_rank(phase=="finished") if phase in ["between","finished"] else [],"events":next_events.duplicate(true)}
