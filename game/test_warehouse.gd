extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://game/arena.tscn") != OK:
		quit(1)
		return
	await scene_changed
	await physics_frame
	await physics_frame
	var map := current_scene
	var yard := map.get_node("WarehouseYard")
	var geometry := yard.find_children("*", "MeshInstance3D", true, false)
	var collision := yard.get_node("YardCollision/CollisionShape3D") as CollisionShape3D
	var world: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var exclusion: Array[RID] = [map.player.get_rid()]
	var floors := true
	for at in [Vector2(6.4,-18.0), Vector2(2.3,-5.7), Vector2(0.9,7.2), Vector2(6.4,18.0)]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(at.x,0.28,at.y), Vector3(at.x,-0.3,at.y), 1, exclusion)
		var hit := world.intersect_ray(ray)
		if hit.is_empty() or absf(hit.position.y) > 0.025:
			print("Unexpected floor at ", at, ": ", hit)
			floors = false
	var wall := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,0.65,18), Vector3(0,0.65,23), 1, exclusion))
	var house := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-3,0.85,8.3), Vector3(-3,0.85,5), 1, exclusion))
	var lane := world.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-1.65,0.65,7.05), Vector3(-1.65,0.65,9.45), 1, exclusion))
	var cutaway: bool = yard.update_cutaway(Vector3.ZERO) and not yard.roof_meshes.is_empty() and (yard.roof_meshes[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	var roof_restored: bool = not yard.update_cutaway(Vector3(0,0,10.0)) and (yard.roof_meshes[0] as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	print("Warehouse meshes=", geometry.size(), "; collision triangles=", (collision.shape as ConcavePolygonShape3D).get_faces().size()/3.0, "; four floor sections=", floors, "; perimeter=", not wall.is_empty(), "; warehouse shell=", not house.is_empty(), "; clear exit path=", lane.is_empty(), "; roof cutaway=", cutaway and roof_restored)
	if geometry.size() < 40 or not floors or wall.is_empty() or house.is_empty() or not lane.is_empty() or not cutaway or not roof_restored:
		quit(1)
		return
	map.player.held["down"] = true
	for n in range(20):
		await physics_frame
	map.player.held.clear()
	if not map._near_door() or absf(map.player.position.y) > 0.15 or map.player.position.z < 8.5:
		push_error("Walking from spawn did not safely reach exit: %s" % map.player.position)
		quit(1)
		return
	print("PASS: walkable warehouse arena and exit")
	quit()
