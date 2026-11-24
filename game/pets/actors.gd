extends Node3D
const CATALOG = preload("res://game/pets/catalog.gd")
const BODY_RADIUS := .325
const ROOM_STRIDE := 12.
const WORK_PER_TICK := 12
const SPAWN_PER_TICK := 4
var _rooms := 0
var _player: Node3D
var _inside: Dictionary = {}
var _insert_order: Array[String] = []
var _queued: Array[Dictionary] = []
var _state: Dictionary = {}
var _elapsed := 0.
var _index := 0
var _outside: Node3D
var _outside_kind := ""
var _prior_heading := Vector3.FORWARD
var _rng := RandomNumberGenerator.new()
var _probe := SphereShape3D.new()

func configure(player: Node3D, room_count: int) -> void:
	_player = player
	_rooms = room_count
	_probe.radius = BODY_RADIUS
	_rng.randomize()

func synchronize(next: Dictionary) -> void:
	if _state==next: return
	_state = next.duplicate(true)
	if _rooms<=0:
		var kind := CATALOG.active_species(next)
		if kind==_outside_kind: return
		if is_instance_valid(_outside): _outside.queue_free()
		_outside = CATALOG.make(kind)
		_outside_kind = kind
		if _outside!=null:
			_outside.name="OutdoorCompanion"
			add_child(_outside)
			_outside.hide()
		return
	var wanted: Dictionary = {}
	for row: Dictionary in next.get("owned",[]):
		if row.species in CATALOG.SPECIES:
			wanted[String(row.id)]=String(row.species)
	for id: String in _inside.keys():
		if wanted.has(id): continue
		var obsolete: Node3D = _inside[id].node
		obsolete.queue_free()
		_inside.erase(id)
		_insert_order.erase(id)
	_queued.clear()
	for id: String in wanted:
		if not _inside.has(id): _queued.append({"id":id,"kind":wanted[id]})

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player): return
	if _rooms<=0:
		_follow(delta)
		return
	_elapsed += delta
	for i in range(mini(SPAWN_PER_TICK,_queued.size())):
		var next: Dictionary = _queued.pop_back()
		_add_indoor(next.id,next.kind)
	for i in range(mini(WORK_PER_TICK,_insert_order.size())):
		_index %= _insert_order.size()
		var row: Dictionary = _inside[_insert_order[_index]]
		_index += 1
		_roam(row,clampf(_elapsed-float(row.last),delta,.18))
		row.last = _elapsed

func _add_indoor(id: String, species: String) -> void:
	var node := CATALOG.make(species)
	if node==null: return
	var home_room := int(hash(id)&0x7fffffff)%_rooms
	var at := Vector3.ZERO
	for i in range(24):
		at = _random_floor(home_room)
		if _safe_fraction(at,Vector3.ZERO)>=.99: break
	if _safe_fraction(at,Vector3.ZERO)<.99:
		_queued.push_front({"id":id,"kind":species})
		node.free()
		return
	node.name = "IndoorPet"
	add_child(node)
	node.global_position = at
	var row := {"node":node,"room":home_room,"goal":_random_floor(home_room),"last":_elapsed,"pause":_rng.randf_range(.2,1.8)}
	_inside[id]=row
	_insert_order.append(id)

func _random_floor(room_number: int) -> Vector3:
	return Vector3(float(room_number)*ROOM_STRIDE+_rng.randf_range(-5.4,5.4),.025,_rng.randf_range(-4.35,4.35))

func _roam(row: Dictionary,delta: float) -> void:
	var pet: Node3D = row.node
	row.pause = maxf(0.,float(row.pause)-delta)
	if row.pause>0.: return
	var move := Vector3(row.goal)-pet.global_position
	move.y = 0.
	if move.length_squared() < .045:
		row.goal = _random_floor(row.room)
		row.pause = _rng.randf_range(.35,2.1)
		return
	var direction := move.normalized()
	var step := direction*minf(move.length(),1.30*delta)
	var safe := _safe_fraction(pet.global_position,step)
	if safe<.9:
		row.goal = _random_floor(row.room)
		row.pause = _rng.randf_range(.13,.55)
		return
	pet.global_position += safe*step
	pet.rotation.y = lerp_angle(pet.rotation.y,atan2(direction.x,direction.z),minf(1.,8.*delta))

func _safe_fraction(at: Vector3, step: Vector3) -> float:
	var test := PhysicsShapeQueryParameters3D.new()
	test.shape = _probe
	test.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*.385)
	test.collision_mask = 1
	var space := get_world_3d().direct_space_state
	if step.is_zero_approx():
		return 1.0 if space.intersect_shape(test,1).is_empty() else 0.
	test.motion = step
	var hits := space.cast_motion(test)
	return 0. if hits.is_empty() else hits[0]

func _follow(delta: float) -> void:
	if not is_instance_valid(_outside): return
	var origin := _player.global_position
	var heading := _prior_heading
	var velocity: Vector3 = _player.get("velocity") if _player is CharacterBody3D else Vector3.ZERO
	velocity.y = 0.
	if velocity.length()>1.: heading=velocity.normalized()
	_prior_heading=heading
	var offset := heading*.62 + heading.cross(Vector3.UP)*1.22
	if not _outside.visible or _outside.global_position.distance_to(origin)>7.0:
		for side: float in [1.0,-1.0,0.0]:
			var at := origin-offset.rotated(Vector3.UP,side*.5)
			var floor: Variant = _floor(at)
			if floor==null: continue
			at.y=float(floor)
			if _safe_fraction(at,Vector3.ZERO)>.99:
				_outside.global_position=at
				_outside.show()
				break
		return
	var target := origin-offset
	var toward := target-_outside.global_position
	toward.y = 0.
	if toward.length_squared()<.15: return
	var step := toward.normalized()*minf(toward.length(),minf(9.,2.8+toward.length()*3.)*delta)
	var firm := _safe_fraction(_outside.global_position,step)
	if firm<.87: return
	var intended := _outside.global_position+step*firm
	var floor: Variant = _floor(intended)
	if floor==null or absf(float(floor)-_outside.global_position.y)>.59: return
	intended.y=float(floor)
	_outside.global_position=intended
	_outside.rotation.y=lerp_angle(_outside.rotation.y,atan2(toward.x,toward.z),minf(1.,11.*delta))

func _floor(at: Vector3) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.8,at-Vector3.UP*2.1,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return null if hit.is_empty() or Vector3(hit.normal).y<.62 else Vector3(hit.position).y+.025
