extends RefCounted
## Conversation range varies by layout, but rigid world geometry blocks speech.
static func visible_from(observer: Node3D, at: Vector3, actor: Vector3, radius: float, endpoint: Vector3, exclusions: Array[RID] = []) -> bool:
	if absf(at.y - actor.y) > 1.25 or Vector2(at.x - actor.x, at.z - actor.z).length_squared() > radius * radius:
		return false
	var from := at + Vector3.UP * 1.6
	var aim := endpoint + Vector3.UP * 1.6
	if from.is_equal_approx(aim):
		return true
	var query := PhysicsRayQueryParameters3D.create(from,aim,3,exclusions)
	return observer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
