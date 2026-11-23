extends RefCounted
## Beach-only soft respawn. Does not touch wallet, fish bag, or equipped rod.
const WATER_FALL_Y := -0.77
const SAMPLE_INTERVAL := 0.12
const FALLBACKS := [Vector3(0,0.05,34),Vector3(0,0.05,29),Vector3(4,0.05,34)]
const SAMPLE_OFFSETS := [Vector3.ZERO,Vector3(.19,0,0),Vector3(-.19,0,0),Vector3(0,0,.19),Vector3(0,0,-.19)]
var last_safe := Vector3.INF
var _until_sample := 0.0


func tick(body: CharacterBody3D, delta: float, enabled: bool) -> bool:
	if not enabled or not body.is_physics_processing():
		return false
	var feet := body.global_position
	if not feet.is_finite() or feet.y < WATER_FALL_Y:
		var safe := _safe_point(body,last_safe)
		if not safe.is_finite():
			for fallback: Vector3 in FALLBACKS:
				safe = _safe_point(body,fallback)
				if safe.is_finite():
					break
		if not safe.is_finite():
			return false
		last_safe = safe
		body.global_position = safe
		body.velocity = Vector3.ZERO
		body.held.clear()
		body.jump_buffer = 0.0
		body.active = false
		body.reset_physics_interpolation()
		_until_sample = SAMPLE_INTERVAL
		return true
	_until_sample -= delta
	if body.is_on_floor() and _until_sample <= 0.0:
		_until_sample = SAMPLE_INTERVAL
		if not last_safe.is_finite() or feet.distance_squared_to(last_safe) > 0.025:
			var safe := _safe_point(body,feet)
			if safe.is_finite():
				last_safe = safe
	return false


func _safe_point(body: CharacterBody3D, hint: Vector3) -> Vector3:
	# Beach walking surfaces only; avoid roofs, the void, and the out-of-bounds side.
	if not hint.is_finite() or absf(hint.x) >= 55.5 or hint.z < -35.0 or hint.z > 42.0 or hint.y < -0.12 or hint.y > 1.35:
		return Vector3.INF
	var space := body.get_world_3d().direct_space_state
	var support_y := 0.0
	for offset: Vector3 in SAMPLE_OFFSETS:
		var foot := hint + offset
		# Layer 1 supports the character. The layer 2 rail must not become a checkpoint.
		var ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.30,foot-Vector3.UP*.42,1,[body.get_rid()])
		var support := space.intersect_ray(ray)
		if support.is_empty() or Vector3(support.normal).dot(Vector3.UP) < .76:
			return Vector3.INF
		if offset == Vector3.ZERO:
			support_y = support.position.y
		elif absf(float(support.position.y)-support_y) > .13:
			return Vector3.INF
	var safe := Vector3(hint.x,support_y+.085,hint.z)
	var collider: CollisionShape3D
	for child: Node in body.get_children():
		if child is CollisionShape3D and not child.disabled:
			collider = child
			break
	if collider == null or collider.shape == null:
		return Vector3.INF
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(body.global_basis,safe) * collider.transform
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	return safe if space.intersect_shape(query,1).is_empty() else Vector3.INF
