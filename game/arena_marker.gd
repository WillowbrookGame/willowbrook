extends Node3D
signal actor_tag(victim: Node3D)
## Local-only paintball preview. No scoring, damage, or network messages.

const MARKER = preload("res://game/toy-paintball-marker.glb")
const SFX = preload("res://game/paintball_audio.gd")
const SCALE := 0.24
const PAINT := Color("#4ce9fc")
const SHOT_INTERVAL := 0.16
const MAX_SPLATS := 40
const AIM_ASSIST_RADIUS := 0.24
const AIM_RANGE := 42.0
var skeleton: Skeleton3D
var player: CharacterBody3D
var right_arm: int
var grip_pose: Quaternion
var marker: Node3D
var cooldown := 0.0
var recoil := 0.0
var pending_shot := false
var holding_fire := false
var splats: Array[Node3D] = []
var shot_count := 0
var flights: Dictionary = {}
var _sfx_rng := RandomNumberGenerator.new()
# Shared read-only resources; the active flight/splat nodes still own transforms.
static var paint_shapes: Dictionary = {}
static var paint_materials: Dictionary = {}

func setup(avatar: Node3D, animation: AnimationPlayer, owner_body: CharacterBody3D) -> void:
	player = owner_body
	_sfx_rng.randomize()
	skeleton = avatar.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	right_arm = skeleton.find_bone("arm-right")
	animation.play("holding-right")
	animation.advance(0)
	grip_pose = skeleton.get_bone_pose_rotation(right_arm)
	animation.play("idle")
	animation.advance(0)
	marker = MARKER.instantiate() as Node3D
	marker.name = "HeldPaintballMarker"
	var samples := marker.find_child("Paintballs", true, false) as Node3D
	if samples != null:
		samples.hide()
	add_child(marker)
	update_hand(0.0, true)

func update_hand(pitch: float, show_marker: bool) -> void:
	var kick := recoil
	skeleton.set_bone_pose_rotation(right_arm, grip_pose * Quaternion(Vector3.BACK, pitch * 0.75 + kick * 0.18))
	var arm := skeleton.get_bone_global_pose(right_arm)
	var hand := skeleton.to_global(arm * Vector3(-0.143, -0.01, 0.0))
	var facing := Basis(Vector3.UP, player.rotation.y) * Basis(Vector3.RIGHT, pitch * 0.75 + kick * 0.22) * Basis(Vector3.UP, PI)
	var scaled := facing.scaled(Vector3.ONE * SCALE)
	marker.global_transform = Transform3D(scaled, hand - scaled * Vector3(0, 0.30, -0.23 + kick * 0.28))
	marker.visible = show_marker

func trigger() -> void:
	pending_shot = true

func set_holding_fire(held: bool) -> void:
	holding_fire = held

func has_aim_target(camera: Camera3D) -> bool:
	if camera == null or not is_instance_valid(player) or not is_inside_tree():
		return false
	var forward := -camera.global_basis.z
	var hit := _aim_ray(camera.global_position, forward)
	var victim := hit.get("collider") as CollisionObject3D
	return victim != null and (victim.collision_layer & 4) != 0

func tick(delta: float, camera: Camera3D) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = maxf(0.0, recoil - delta * 7.5)
	if not pending_shot and not holding_fire:
		return
	if cooldown > 0.0:
		pending_shot = false
		return
	pending_shot = false
	cooldown = SHOT_INTERVAL
	recoil = 1.0
	shot_count += 1
	SFX.play(self, "pop", -7.0, _sfx_rng.randf_range(0.93, 1.09))
	var muzzle := marker.to_global(Vector3(0, 0.65, 1.26))
	var chest := player.global_position + Vector3.UP * 1.03
	var forward := -camera.global_basis.z
	var hit := _aim_ray(camera.global_position, forward)
	var destination: Vector3 = hit.get("position", camera.global_position + forward * AIM_RANGE)
	# The camera may see around a prop before the handheld marker has cleared it.
	var blocked_muzzle := _ray(chest, muzzle)
	if not blocked_muzzle.is_empty():
		hit = blocked_muzzle
		muzzle = blocked_muzzle.position + blocked_muzzle.normal * 0.035
		destination = blocked_muzzle.position
	elif muzzle.distance_squared_to(destination) > 0.0025:
		var marker_hit := _ray(muzzle, destination + (destination - muzzle).normalized() * 0.02)
		if not marker_hit.is_empty():
			hit = marker_hit
			destination = marker_hit.position
	var victim := hit.get("collider") as CollisionObject3D
	if victim != null and (victim.collision_layer & 4) != 0:
		_animate_paint(muzzle, destination, {}, PAINT, _emit_actor_tag.bind(victim, destination, PAINT))
	else:
		_animate_paint(muzzle, destination, hit)

func _aim_ray(origin: Vector3, forward: Vector3) -> Dictionary:
	var end := origin + forward * AIM_RANGE
	var hit := _ray(origin, end)
	var collider := hit.get("collider") as CollisionObject3D
	if collider != null and (collider.collision_layer & 4) != 0:
		return hit
	# Subtle aim forgiveness for tablets/kids: if the exact center ray barely misses
	# a player/bot, check a narrow cone around the crosshair with line-of-sight.
	var max_dist := origin.distance_to(hit.position) if not hit.is_empty() else AIM_RANGE
	var shape := SphereShape3D.new()
	shape.radius = AIM_ASSIST_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = forward * max_dist
	query.collision_mask = 4
	query.exclude = [player.get_rid()]
	var cast := get_world_3d().direct_space_state.cast_motion(query)
	if cast.size() == 2 and cast[1] < 1.0:
		var rest := PhysicsShapeQueryParameters3D.new()
		rest.shape = shape
		rest.transform = Transform3D(Basis.IDENTITY, origin + forward * (max_dist * cast[1]))
		rest.collision_mask = 4
		rest.exclude = [player.get_rid()]
		var info := get_world_3d().direct_space_state.get_rest_info(rest)
		if not info.is_empty():
			var candidate := instance_from_id(int(info.get("collider_id", 0))) as CollisionObject3D
			var point: Vector3 = info.get("point", origin + forward * (max_dist * cast[1]))
			if candidate != null and (candidate.collision_layer & 4) != 0:
				var los := _ray(origin, point + (point - origin).normalized() * 0.25)
				if los.get("collider") == candidate:
					return los
	return hit

func _emit_actor_tag(victim: Node3D, at: Vector3, tint: Color) -> void:
	burst_at(at, tint)
	if is_instance_valid(victim):
		actor_tag.emit(victim)

func _ray(start: Vector3, end: Vector3) -> Dictionary:
	var excluded: Array[RID] = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 5, excluded))

func _paint_mesh(radius: float, tint := PAINT) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	if not paint_shapes.has(radius):
		var mesh := SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 4
		paint_shapes[radius] = mesh
	if not paint_materials.has(tint):
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = tint
		paint_materials[tint] = paint
	part.mesh = paint_shapes[radius]
	part.material_override = paint_materials[tint]
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return part

func _animate_paint(start: Vector3, goal: Vector3, hit: Dictionary, tint := PAINT, on_arrival := Callable()) -> void:
	var ball := _paint_mesh(0.055,tint)
	add_child(ball)
	ball.global_position = start
	var tween := create_tween()
	tween.tween_property(ball, "global_position", goal, clampf(start.distance_to(goal) * 0.035, 0.035, 0.48))
	flights[ball] = tween
	tween.tween_callback(_finish_flight.bind(ball,hit,tint,on_arrival))


func _finish_flight(ball: MeshInstance3D, hit: Dictionary, tint: Color, on_arrival: Callable) -> void:
	flights.erase(ball)
	ball.queue_free()
	if not hit.is_empty():
		_splat(hit.position,hit.normal,tint)
		SFX.play(self, "splat", -11.0, _sfx_rng.randf_range(0.88, 1.16))
	if on_arrival.is_valid():
		on_arrival.call()


func burst_at(at: Vector3, tint := PAINT) -> void:
	if not is_inside_tree():
		return
	var directions := [
		Vector3(0.45, 0.35, 0.25), Vector3(-0.42, 0.30, 0.28),
		Vector3(0.28, 0.42, -0.40), Vector3(-0.32, 0.25, -0.38),
		Vector3(0.05, 0.55, 0.12), Vector3(-0.18, -0.10, 0.45),
	]
	for dir: Vector3 in directions:
		var drop := _paint_mesh(0.045, tint)
		add_child(drop)
		drop.global_position = at
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(drop, "global_position", at + dir * 0.95, 0.24).set_ease(Tween.EASE_OUT)
		tween.tween_property(drop, "scale", Vector3.ONE * 0.05, 0.24).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(drop.queue_free)


func clear_round_paint() -> void:
	pending_shot = false
	holding_fire = false
	cooldown = 0.0
	recoil = 0.0
	for ball: MeshInstance3D in flights:
		flights[ball].kill()
		ball.hide()
		ball.queue_free()
	flights.clear()
	for splat: Node3D in splats:
		splat.hide()
		splat.queue_free()
	splats.clear()

func _splat(at: Vector3, normal: Vector3, tint := PAINT) -> void:
	if splats.size() >= MAX_SPLATS:
		splats.pop_front().queue_free()
	var group := Node3D.new()
	group.name = "PaintSplat"
	add_child(group)
	group.global_position = at + normal * 0.018
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	group.global_basis = Basis(tangent, normal, tangent.cross(normal))
	for spec in [Vector4(0,0,0.19,0.8), Vector4(0.14,0.08,0.08,0.8), Vector4(-0.16,-0.06,0.07,0.8), Vector4(0.06,-0.18,0.045,1.0)]:
		var spot := _paint_mesh(spec.z,tint)
		group.add_child(spot)
		spot.position = Vector3(spec.x,0,spec.y)
		spot.scale = Vector3(1,0.035,spec.w)
	splats.append(group)
