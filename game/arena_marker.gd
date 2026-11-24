extends Node3D
signal actor_tag(victim: Node3D)
## Local-only paintball preview. No scoring, damage, or network messages.

const MARKER = preload("res://game/toy-paintball-marker.glb")
const SCALE := 0.24
const PAINT := Color("#4ce9fc")
const SHOT_INTERVAL := 0.16
const MAX_SPLATS := 40
var skeleton: Skeleton3D
var player: CharacterBody3D
var right_arm: int
var grip_pose: Quaternion
var marker: Node3D
var cooldown := 0.0
var pending_shot := false
var splats: Array[Node3D] = []
var shot_count := 0
var flights: Dictionary = {}
# Shared read-only resources; the active flight/splat nodes still own transforms.
static var paint_shapes: Dictionary = {}
static var paint_materials: Dictionary = {}

func setup(avatar: Node3D, animation: AnimationPlayer, owner_body: CharacterBody3D) -> void:
	player = owner_body
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
	skeleton.set_bone_pose_rotation(right_arm, grip_pose * Quaternion(Vector3.BACK, pitch * 0.75))
	var arm := skeleton.get_bone_global_pose(right_arm)
	var hand := skeleton.to_global(arm * Vector3(-0.143, -0.01, 0.0))
	var facing := Basis(Vector3.UP, player.rotation.y) * Basis(Vector3.RIGHT, pitch * 0.75) * Basis(Vector3.UP, PI)
	var scaled := facing.scaled(Vector3.ONE * SCALE)
	marker.global_transform = Transform3D(scaled, hand - scaled * Vector3(0, 0.30, -0.23))
	marker.visible = show_marker

func trigger() -> void:
	pending_shot = true

func tick(delta: float, camera: Camera3D) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if not pending_shot:
		return
	pending_shot = false
	if cooldown > 0.0:
		return
	cooldown = SHOT_INTERVAL
	shot_count += 1
	var muzzle := marker.to_global(Vector3(0, 0.65, 1.26))
	var chest := player.global_position + Vector3.UP * 1.03
	var forward := -camera.global_basis.z
	var hit := _ray(camera.global_position, camera.global_position + forward * 42.0)
	var destination: Vector3 = hit.get("position", camera.global_position + forward * 42.0)
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
		_animate_paint(muzzle, destination, {}, PAINT, _emit_actor_tag.bind(victim))
	else:
		_animate_paint(muzzle, destination, hit)

func _emit_actor_tag(victim: Node3D) -> void:
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
	if on_arrival.is_valid():
		on_arrival.call()


func clear_round_paint() -> void:
	pending_shot = false
	cooldown = 0.0
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
