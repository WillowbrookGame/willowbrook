extends Node3D

signal dialog_opened
signal dialog_closed

const LOT := Vector3(19,0,3)
const BAY := Vector3(-20,0,5)
const SCOOTER_SPOTS := [Vector3(-22,0.08,3.5),Vector3(-20,0.08,3.5),Vector3(-18,0.08,3.5)]
const CAR_PARK := Vector3(19,0.10,11.25)
const CAR_PATHS := [
	preload("res://game/town_assets/kenney-cars/sedan.glb"),
	preload("res://game/town_assets/kenney-cars/sedan.glb"),
	preload("res://game/town_assets/kenney-cars/sedan-sports.glb"),
]
const CAR_NAMES := ["Town Car","Blue Town Car","Sporty Car"]
const COSTS := [30,60,100]
const VEHICLE_LAYER := 2
const SCOOTER_RIDER = preload("res://game/vehicles/scooter_rider.gd")
const TOWN_LAYOUT = preload("res://game/town_layout.gd")
const STOP_SPEED := 0.12

var host: Node
var player: CharacterBody3D
var avatar: Node3D
var driven: CharacterBody3D
var owned_car: CharacterBody3D
var parked: Array[CharacterBody3D] = []
var speed := 0.0
var status: Label
var overlay: CenterContainer
var description: Label
var purchase: Button
var _old_layer := 0
var _old_mask := 0
var _old_avatar_yaw := 0.0
var _fade := 0.0


var _account_shop: Node
var _shared: Node
var _shared_bodies: Dictionary = {}
var _shared_rows: Dictionary = {}
var _shared_seat := ""
var _shared_action_until := 0
var _move_cadence := 0.0
var _recall_button: Button
var _town_action: Button
var _recall_home := false
var _saved_feedback: Label

func setup(town: Node, body: CharacterBody3D, character: Node3D, hud: CanvasLayer) -> void:
	host = town
	player = body
	# This module exists only in town. Pedestrians see parked vehicle hulls;
	# mount masks the rider, and dismount restores this same walking mask.
	player.collision_mask |= VEHICLE_LAYER
	avatar = character
	if OS.has_feature("web"):
		var account := get_node_or_null("/root/WillowbrookBrowserSession")
		if account!=null and account.has_method("vehicle_shop_available"):
			_account_shop = account
			account.vehicle_result.connect(_on_saved_purchase)
			if account.has_method("town_vehicle_state"):
				_shared=account
				account.shared_vehicle_event.connect(_on_vehicle_event)
	if _shared == null:
		for spot: Vector3 in SCOOTER_SPOTS:
			_make_vehicle(true,spot,PI)
	if _account_shop == null:
		_load_owned_car()
	_build_hud(hud)


func is_driving() -> bool:
	return is_instance_valid(driven)


func hides_avatar() -> bool:
	return _shared == null and is_driving() and not bool(driven.get_meta("scooter"))


func is_modal_open() -> bool:
	return overlay != null and overlay.visible


func interaction_prompt() -> String:
	if is_modal_open():
		return ""
	if is_driving():
		if absf(speed) > STOP_SPEED:
			return "Release throttle to stop"
		if bool(driven.get_meta("scooter")) and in_scooter_bay(driven.position):
			return "Return Scooter"
		return "Get Off Scooter" if bool(driven.get_meta("scooter")) else "Exit Car"
	if _planar_distance(player.position,LOT) <= 2.9:
		return "Shop at Willow Wheels"
	var nearby := _near_vehicle()
	if nearby != null:
		if _shared != null:
			var row: Dictionary = _shared_rows.get(nearby.get_meta("sharedId",""),{})
			if row.get("driver")==null and row.get("canDrive",false): return "Ride Scooter" if row.get("kind")=="scooter" else "Drive My Car"
			if row.get("kind")=="car" and row.get("passenger")==null and absf(float(row.get("speed",0)))<=STOP_SPEED: return "Ride Along"
			return ""
		return "Ride Scooter" if bool(nearby.get_meta("scooter")) else "Drive My Car"
	return ""


func interact() -> bool:
	if is_modal_open():
		return false
	if _shared != null:
		if is_driving():
			var op := "return" if bool(driven.get_meta("scooter")) and in_scooter_bay(driven.position) and _shared_seat=="driver" else "exit"
			return _shared_action(op)
		if _planar_distance(player.position,LOT)<=2.9:
			_open_purchase()
			return true
		var candidate := _near_vehicle()
		if candidate == null: return false
		var id: String = candidate.get_meta("sharedId","")
		var row: Dictionary = _shared_rows.get(id,{})
		if row.is_empty(): return false
		var seat := "driver" if row.get("canDrive")==true and row.get("driver")==null else "passenger"
		return _shared_action("enter",{"car":id,"seat":seat})
	if is_driving():
		if absf(speed) > STOP_SPEED:
			_note("Release throttle to stop first.")
		else:
			_exit_vehicle()
		return true
	if _planar_distance(player.position,LOT) <= 2.9:
		_open_purchase()
		return true
	var nearby := _near_vehicle()
	if nearby != null:
		_enter_vehicle(nearby)
		return true
	return false


# Run from the Town physics tick before sampling the camera/rider.
func tick_drive(delta: float) -> void:
	if _fade > 0.0:
		_fade -= delta
		if _fade <= 0.0 and status != null:
			status.text = ""
	if is_modal_open() and _account_shop != null:
		_update_offer()
	if _shared != null:
		_sync_shared(delta)
		if not is_driving() or _shared_seat!="driver": return
		_move_cadence += delta
		if _move_cadence < 0.05: return
		_move_cadence=0.0
		var tint: Vector2 = player.analog_motion()
		var steer := float(_press(KEY_D,"right"))-float(_press(KEY_A,"left"))+tint.x
		var throttle := float(_press(KEY_W,"up"))-float(_press(KEY_S,"down"))-tint.y
		if host.call("_world_input_blocked"): steer=0.0;throttle=0.0
		_shared.send_vehicle({"type":"vehicleInput","throttle":clampf(throttle,-1,1),"steer":clampf(steer,-1,1)})
		return
	if not is_driving():
		return
	var analog: Vector2 = player.analog_motion()
	var steer := float(_press(KEY_D,"right"))-float(_press(KEY_A,"left"))+analog.x
	var throttle := float(_press(KEY_W,"up"))-float(_press(KEY_S,"down"))-analog.y
	step_drive(throttle,steer,delta)


func scooter_mount() -> Node3D:
	return driven if is_driving() and bool(driven.get_meta("scooter",false)) else null

func rendered_scooter(id: String) -> Node3D:
	var body: Node3D = _shared_bodies.get(id)
	return body if is_instance_valid(body) and bool(body.get_meta("scooter",false)) else null

func shared_vehicle_sitting() -> bool:
	return _shared != null and not _shared_seat.is_empty() and scooter_mount() == null

func _shared_action(op: String, fields: Dictionary = {}) -> bool:
	if Time.get_ticks_msec() < _shared_action_until: return true
	if not _shared.send_vehicle({"type":"vehicleAction","operation":op}.merged(fields)):
		_note("Vehicle connection unavailable.")
		return true
	_shared_action_until=Time.get_ticks_msec()+400
	return true

func _on_vehicle_event(message: Dictionary) -> void:
	_shared_action_until=0
	if is_driving() and message.get("exit") is Dictionary:
		var at: Dictionary = message.exit
		_release_shared(Vector3(float(at.x),0.06,float(at.z)))
	_note(str(message.get("text","")))

func _release_shared(at: Vector3) -> void:
	driven=null
	_shared_seat=""
	speed=0
	player.global_position=at
	player.collision_layer=_old_layer
	player.collision_mask=_old_mask
	player.held.clear()
	player.velocity=Vector3.ZERO
	player.movement_locked=false
	player.set_physics_process(true)
	avatar.rotation.y=_old_avatar_yaw
	avatar.show()

func _make_open_car(body: CharacterBody3D, tier: int) -> void:
	var cabin := Node3D.new()
	cabin.name="OpenCabin"
	body.add_child(cabin)
	var paint := [Color("#d9784f"),Color("#4f96de"),Color("#e76360")][tier] as Color
	_box_art(cabin,Vector3(0,0.38,0),Vector3(1.75,0.55,3.7),paint)
	_box_art(cabin,Vector3(0,0.73,-1.22),Vector3(1.7,0.30,.96),paint)
	_box_art(cabin,Vector3(0,0.78,1.28),Vector3(1.7,0.36,.73),paint)
	for side: float in [-.87,.87]:
		_box_art(cabin,Vector3(side,.69,.3),Vector3(.18,.36,1.55),paint)
		for z: float in [-1.13,1.13]:
			_box_art(cabin,Vector3(side,.25,z),Vector3(.38,.49,.57),Color("#303339"))
	cabin.hide()

func _sync_shared(delta: float) -> void:
	var snap: Dictionary = _shared.town_vehicle_state()
	var seen := {}
	var blend := 1.0-exp(-18.0*delta)
	for raw: Dictionary in snap.get("rows",[]):
		var id: String = raw.id
		seen[id]=true
		var scooter: bool = raw.kind=="scooter"
		var at := Vector3(float(raw.x),0.08,float(raw.z))
		var tier := int(raw.tier)
		var body: CharacterBody3D = _shared_bodies.get(id)
		if is_instance_valid(body) and int(body.get_meta("tier"))!=tier:
			if body==driven: _release_shared(player.global_position)
			parked.erase(body)
			body.collision_layer=0
			body.queue_free()
			body=null
		if not is_instance_valid(body):
			body=_make_vehicle(scooter,at,float(raw.yaw),tier)
			body.set_meta("sharedId",id)
			_shared_bodies[id]=body
			if not scooter: _make_open_car(body,tier)
		else:
			body.position=at if body.position.distance_to(at)>5.0 else body.position.lerp(at,blend)
			body.rotation.y=lerp_angle(body.rotation.y,float(raw.yaw),blend)
		if not scooter:
			var occupied: bool = raw.get("driver")!=null or raw.get("passenger")!=null
			body.get_child(1).visible=not occupied
			body.get_node("OpenCabin").visible=occupied
		_shared_rows[id]=raw
	for id: String in _shared_bodies.keys():
		if seen.has(id): continue
		var body: CharacterBody3D = _shared_bodies[id]
		if is_instance_valid(body):
			if body==driven: _release_shared(player.global_position+Vector3(1.5,0,0))
			parked.erase(body)
			body.collision_layer=0
			body.queue_free()
		_shared_bodies.erase(id)
		_shared_rows.erase(id)
	var own: Variant = snap.get("self")
	if own is Dictionary and _shared_bodies.has(own.car):
		var body: CharacterBody3D = _shared_bodies[own.car]
		if not is_driving():
			host.call("_reset_input_context")
			_enter_vehicle(body)
			_shared_seat=own.seat
			if _shared_seat=="passenger": _note("Riding along. The driver controls this car.")
		var offset := Vector3(-.50 if _shared_seat=="driver" else .50,.40,0) if not bool(body.get_meta("scooter")) else Vector3(0,.18,0)
		player.global_position=body.to_global(offset)
		avatar.rotation.y=wrapf(body.rotation.y-player.rotation.y+_old_avatar_yaw,-PI,PI)
		speed=float(_shared_rows[own.car].speed)
	elif is_driving():
		_release_shared(player.global_position+Vector3(1.5,0,0))
	_recall_home=snap.get("recallHome",false)
	if _town_action!=null:
		var park: bool = snap.get("parkHome",false)
		_town_action.visible=(park or _recall_home) and not is_modal_open()
		_town_action.text="Park at Home" if park else "Call Car Home"

func step_drive(throttle: float, steer: float, delta: float) -> void:
	if not is_driving() or not is_finite(delta) or delta <= 0.0:
		return
	var scooter: bool = driven.get_meta("scooter")
	throttle = clampf(throttle,-1.0,1.0)
	steer = clampf(steer,-1.0,1.0)
	var dt := minf(delta,0.2)
	var steps := maxi(1,ceili(dt/0.025))
	var step := dt / steps
	for i in steps:
		speed = clampf(speed+throttle*7.0*step,-3.5 if scooter else -4.0,7.0 if scooter else 10.0)
		if is_zero_approx(throttle):
			speed = move_toward(speed,0.0,5.0*step)
		var reverse := -1.0 if speed < -0.01 else 1.0
		var yaw := wrapf(driven.rotation.y-steer*steer_rate(speed,scooter)*step*reverse,-PI,PI)
		var proposed := Transform3D(Basis(Vector3.UP,yaw),driven.global_position)
		if _clear_turn(driven,proposed):
			driven.rotation.y = yaw
		var motion := -driven.global_basis.z*speed*step
		if not is_vehicle_ground(driven.global_position + motion):
			speed = 0.0
		elif driven.move_and_collide(motion) != null:
			speed = 0.0
	player.global_position = driven.global_position + Vector3.UP*(0.22 if scooter else 0.53)
	if scooter:
		avatar.rotation.y = wrapf(driven.rotation.y-player.rotation.y+_old_avatar_yaw,-PI,PI)


static func steer_rate(current_speed: float,scooter: bool) -> float:
	# Preserve low-speed parking and reversing; reduce twitchiness at full throttle.
	var limit := 7.0 if scooter else 10.0
	var reduction := smoothstep(2.0,limit,absf(current_speed))
	return lerpf(1.8,1.05 if scooter else .85,reduction)


static func in_scooter_bay(at: Vector3) -> bool:
	return (at.x >= -25.0 and at.x <= -15.0 and at.z >= 0.5 and at.z <= 5.5) or (at.x >= -23.0 and at.x <= -17.0 and at.z >= 5.0 and at.z <= 9.0)


static func is_vehicle_ground(at: Vector3) -> bool:
	if not at.is_finite():
		return false
	if in_scooter_bay(at):
		return true
	for z: float in [-36.0,-12.0,12.0,36.0]:
		var dz := absf(at.z-z)
		if dz <= 3.6 and absf(at.x) <= 76.2:
			return true
	for x: float in [-72.0,-36.0,0.0,36.0,72.0]:
		var dx := absf(at.x-x)
		if dx <= 3.6 and absf(at.z) <= 40.2:
			return true
		var row := roundf((at.z+36.0)/24.0)*24.0-36.0
		if absf(row) <= 36.0 and dx <= 4.2 and absf(at.z-row) <= 4.2:
			return true
	return TOWN_LAYOUT.on_driveway(at)


func _press(code: Key, direction: String) -> bool:
	return Input.is_physical_key_pressed(code) or Input.is_action_pressed("ui_"+direction) or player.held.has(direction)


func _near_vehicle() -> CharacterBody3D:
	var best := 2.8
	var match_vehicle: CharacterBody3D
	for body: CharacterBody3D in parked:
		var d := _planar_distance(player.position,body.position)
		if d < best and absf(player.position.y-body.position.y) < 1.4:
			best = d
			match_vehicle = body
	return match_vehicle


func _enter_vehicle(vehicle: CharacterBody3D) -> void:
	driven = vehicle
	speed = 0.0
	player.held.clear()
	player.jump_buffer = 0.0
	player.velocity = Vector3.ZERO
	player.movement_locked = true
	player.set_physics_process(false)
	_old_layer = player.collision_layer
	_old_mask = player.collision_mask
	_old_avatar_yaw = avatar.rotation.y
	player.collision_layer = 0
	player.collision_mask = 0
	if hides_avatar():
		avatar.hide()
	player.global_position = driven.global_position + Vector3.UP*(0.53 if hides_avatar() else 0.22)
	_note("Drive with WASD or the touch thumbstick. Stop before getting off.")


func _exit_vehicle() -> void:
	var vehicle := driven
	var scooter: bool = vehicle.get_meta("scooter")
	var leaving := _exit_spot(vehicle)
	if not leaving.is_finite():
		_note("Move somewhere with room to get out.")
		return
	if not scooter and not _save_car_position(vehicle):
		_note("Your parking spot couldn't be saved. Try getting out again.")
		return
	if scooter and in_scooter_bay(vehicle.position):
		for slot: Vector3 in SCOOTER_SPOTS:
			if _spot_free(slot,vehicle,1.22):
				vehicle.position = slot
				vehicle.rotation.y = PI
				break
	driven = null
	speed = 0.0
	player.global_position = leaving
	player.collision_layer = _old_layer
	player.collision_mask = _old_mask
	player.held.clear()
	player.velocity = Vector3.ZERO
	player.movement_locked = false
	player.set_physics_process(true)
	avatar.rotation.y = _old_avatar_yaw
	avatar.show()


func _exit_spot(vehicle: CharacterBody3D) -> Vector3:
	var radius := 1.15 if bool(vehicle.get_meta("scooter")) else 2.1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.55
	var space := get_world_3d().direct_space_state
	for offset: Vector3 in [Vector3.RIGHT,-Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
		var at := vehicle.global_position+offset.rotated(Vector3.UP,vehicle.rotation.y)*radius
		at.y = 0.10
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*0.79)
		q.collision_mask = 1|VEHICLE_LAYER
		q.exclude = [player.get_rid(),vehicle.get_rid()]
		if space.intersect_shape(q,1).is_empty():
			return at
	return Vector3.INF


func _clear_turn(vehicle: CharacterBody3D, proposed: Transform3D) -> bool:
	if proposed.basis.is_equal_approx(vehicle.global_basis):
		return true
	var collider := vehicle.get_node("VehicleCollision") as CollisionShape3D
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = collider.shape
	q.transform = proposed * collider.transform
	q.collision_mask = vehicle.collision_mask
	q.exclude = [vehicle.get_rid(),player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))


func _spot_free(at: Vector3, exempt: CharacterBody3D, radius: float) -> bool:
	for vehicle: CharacterBody3D in parked:
		if vehicle != exempt and _planar_distance(at,vehicle.position) < radius:
			return false
	return true


func _make_vehicle(scooter: bool, at: Vector3, yaw: float, tier: int = -1) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = "TownScooter" if scooter else "OwnedCar"
	body.set_meta("scooter",scooter)
	body.set_meta("tier",tier)
	body.collision_layer = VEHICLE_LAYER
	body.collision_mask = 1|VEHICLE_LAYER
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_child(body)
	body.position = at
	body.rotation.y = yaw
	var collider := CollisionShape3D.new()
	collider.name = "VehicleCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(0.46,0.64,1.16) if scooter else Vector3(1.9,1.03,3.62)
	collider.shape = box
	collider.position.y = 0.10+box.size.y*0.5
	body.add_child(collider)
	if scooter:
		_make_scooter_art(body)
	else:
		_make_car_art(body,tier)
	parked.append(body)
	return body


func _make_car_art(body: CharacterBody3D,tier: int) -> void:
	var art := CAR_PATHS[tier].instantiate() as Node3D
	body.add_child(art)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in art.find_children("*","MeshInstance3D",true,false):
		var local_box := (body.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds = local_box if first else bounds.merge(local_box)
		first = false
	if not first:
		var factor := 3.72/maxf(bounds.size.x,bounds.size.z)
		art.scale *= factor
		var center := bounds.get_center()
		# The Kenney models face +Z; the driving basis points along -Z.
		art.rotation.y += PI
		art.position = Vector3(center.x,-bounds.position.y,center.z)*factor
	if tier == 1:
		# Built-in blue trim; leave imported material and textures shared.
		_box_art(body,Vector3(0,0.20,-1.65),Vector3(1.25,0.13,0.29),Color("#4f96de"))
		_box_art(body,Vector3(0,0.20,1.65),Vector3(1.25,0.13,0.29),Color("#4f96de"))


func _make_scooter_art(body: CharacterBody3D) -> void:
	var colors := [Color("#f0a353"),Color("#66bcad"),Color("#b293d9")]
	var bright: Color = colors[parked.size()%colors.size()]
	_box_art(body,SCOOTER_RIDER.DECK_CENTER,SCOOTER_RIDER.DECK_SIZE,bright)
	_box_art(body,Vector3(0,0.60,-0.48),Vector3(0.08,0.82,0.08),bright)
	_box_art(body,SCOOTER_RIDER.HANDLE,Vector3(0.53,0.08,0.09),Color("#3e4443"))
	for z: float in [-0.53,0.48]:
		var wheel := MeshInstance3D.new()
		var tire := CylinderMesh.new()
		tire.top_radius = 0.14
		tire.bottom_radius = 0.14
		tire.height = 0.085
		tire.radial_segments = 12
		wheel.mesh = tire
		wheel.material_override = _paint(Color("#303a3a"))
		body.add_child(wheel)
		wheel.position = Vector3(0,0.14,z)
		wheel.rotation.z = PI/2.0


func _box_art(body: Node3D,at: Vector3,size: Vector3,color: Color) -> void:
	var piece := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = size
	piece.mesh = block
	piece.material_override = _paint(color)
	body.add_child(piece)
	piece.position = at


func _paint(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _load_owned_car() -> void:
	var profile: Dictionary = host.profile_snapshot()
	var raw: Variant = profile.get("ownedCar")
	if not raw is Dictionary:
		return
	var record: Dictionary = raw
	var tier := int(record.get("tier",-1))
	if tier < 0 or tier >= COSTS.size():
		return
	var at := Vector3(float(record.get("x",CAR_PARK.x)),CAR_PARK.y,float(record.get("z",CAR_PARK.z)))
	var yaw := float(record.get("yaw",PI/2.0))
	var home: Variant = profile.get("home")
	if home is Dictionary:
		var plot := int(home.get("plot",-1))
		if plot >= 0 and plot < TOWN_LAYOUT.HOME_DOORS.size():
			var door: Vector3 = TOWN_LAYOUT.HOME_DOORS[plot]
			var side := -1 if door.x < 0.0 else 1
			var row := door.z-5.0
			if TOWN_LAYOUT.SIDE_DRIVEWAYS.is_retired_own_pad(at,side,row):
				var park := TOWN_LAYOUT.SIDE_DRIVEWAYS.park(side,row)
				at = Vector3(park.x,CAR_PARK.y,park.y)
				yaw = PI
	if not is_vehicle_ground(at) or not is_finite(yaw) or not _spot_free(at,null,2.4):
		at = CAR_PARK
		yaw = PI/2.0
	owned_car = _make_vehicle(false,at,yaw,tier)


func _save_car_position(vehicle: CharacterBody3D) -> bool:
	var next: Dictionary = host.profile_snapshot()
	next["ownedCar"] = {"tier":vehicle.get_meta("tier"),"x":vehicle.position.x,"z":vehicle.position.z,"yaw":vehicle.rotation.y}
	return _commit(next)


func _commit(next: Dictionary) -> bool:
	var result: Variant = host.profile_commit(next)
	return bool(result.get("ok",false)) if result is Dictionary else result == true


func _build_hud(hud: CanvasLayer) -> void:
	status = Label.new()
	status.position = Vector2(18,151)
	status.add_theme_constant_override("outline_size",4)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(status)
	overlay = CenterContainer.new()
	hud.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 260
	panel.add_child(column)
	var title := Label.new()
	title.text = "Willow Wheels"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	description = Label.new()
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(description)
	_saved_feedback = Label.new()
	_saved_feedback.custom_minimum_size.x = 260
	_saved_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_saved_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saved_feedback.hide()
	column.add_child(_saved_feedback)
	purchase = Button.new()
	purchase.custom_minimum_size.y = 44
	purchase.pressed.connect(_purchase)
	column.add_child(purchase)
	if _shared != null:
		_recall_button=Button.new()
		_recall_button.text="Call My Car"
		_recall_button.custom_minimum_size.y=42
		_recall_button.pressed.connect(func(): _shared_action("recall",{"destination":"lot"}))
		column.add_child(_recall_button)
		_town_action=Button.new()
		_town_action.custom_minimum_size=Vector2(138,44)
		_town_action.focus_mode=Control.FOCUS_NONE
		hud.add_child(_town_action)
		_town_action.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT,Control.PRESET_MODE_MINSIZE,16)
		_town_action.position.y-=111
		_town_action.hide()
		_town_action.pressed.connect(func(): _shared_action("park" if is_driving() else "recall",{"destination":"home"}))
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 44
	back.pressed.connect(close_modal)
	column.add_child(back)
	overlay.hide()


func _open_purchase() -> void:
	_saved_feedback.text = ""
	_saved_feedback.hide()
	_update_offer()
	overlay.show()
	dialog_opened.emit()


func close_modal() -> void:
	if not is_modal_open():
		return
	overlay.hide()
	dialog_closed.emit()


func _on_saved_purchase(message: String) -> void:
	_saved_feedback.text = message
	_saved_feedback.show()
	_update_offer()

func _update_saved_offer() -> void:
	if not _account_shop.vehicle_shop_available():
		description.text = "Saved car shop unavailable."
		purchase.hide()
		return
	var current: int = _account_shop.vehicle_tier()
	var stars: int = _account_shop.saved_stars()
	var saved: String = "Your saved car: "+CAR_NAMES[current] if current >= 0 else "No saved car yet"
	description.text = "%s\nSaved stars: %d" % [saved,stars]
	if current+1 < COSTS.size():
		description.text += "\n%s: %d stars" % [CAR_NAMES[current+1],COSTS[current+1]]
	description.text += "\nCars have a driver and a passenger."
	if _recall_button!=null: _recall_button.visible=current>=0
	if _account_shop.vehicle_purchase_pending():
		var retry: bool = _account_shop.can_retry_vehicle_purchase()
		purchase.text = "Retry last purchase" if retry else "Saving purchase..."
		purchase.disabled = not retry
		purchase.show()
	elif current+1 < COSTS.size():
		purchase.text = "Buy Car" if current < 0 else "Upgrade Car"
		purchase.disabled = stars < COSTS[current+1]
		purchase.show()
	else:
		purchase.hide()

func _update_offer() -> void:
	if _account_shop != null:
		_update_saved_offer()
		return
	var profile: Dictionary = host.profile_snapshot()
	var current := -1 if not is_instance_valid(owned_car) else int(owned_car.get_meta("tier"))
	var next := current+1
	var stars := int(profile.get("stars",0))
	if next >= COSTS.size():
		description.text = "You already own the top car.\nStars: %d" % stars
		purchase.hide()
		return
	description.text = "%s\n%d stars  •  You have %d" % [CAR_NAMES[next],COSTS[next],stars]
	purchase.text = "Buy Car" if current < 0 else "Upgrade Car"
	purchase.disabled = stars < COSTS[next]
	purchase.show()


func _purchase() -> void:
	if not is_modal_open() or _planar_distance(player.position,LOT) > 2.9:
		return
	if _account_shop != null:
		if _account_shop.vehicle_purchase():
			_saved_feedback.hide()
			_update_offer()
		else:
			_on_saved_purchase("Not sent. Check your connection and try again.")
		return
	var next: Dictionary = host.profile_snapshot()
	var tier := 0 if not is_instance_valid(owned_car) else int(owned_car.get_meta("tier"))+1
	if tier >= COSTS.size() or int(next.get("stars",0)) < COSTS[tier]:
		_update_offer()
		return
	var at := CAR_PARK if tier == 0 else owned_car.position
	var yaw := PI/2.0 if tier == 0 else owned_car.rotation.y
	if tier == 0 and not _spot_free(at,null,2.4):
		_note("There's no free space at the lot right now.")
		return
	next["stars"] = int(next.stars)-COSTS[tier]
	next["ownedCar"] = {"tier":tier,"x":at.x,"z":at.z,"yaw":yaw}
	if not _commit(next):
		_note("Couldn't save the car purchase. No stars were spent.")
		return
	if is_instance_valid(owned_car):
		parked.erase(owned_car)
		owned_car.queue_free()
		owned_car.collision_layer = 0
	owned_car = _make_vehicle(false,at,yaw,tier)
	close_modal()
	_note("%s is parked nearby." % CAR_NAMES[tier] if tier == 0 else "Upgraded to %s." % CAR_NAMES[tier])


func _note(message: String) -> void:
	status.text = message
	_fade = 4.0
