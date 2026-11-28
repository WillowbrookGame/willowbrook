extends SceneTree

const YARD_SCRIPT := preload("res://game/warehouse_yard.gd")
const SPAWN := "GameplayMarkers/MatchSpawns/Slot01"
const WAYPOINT := "GameplayMarkers/BotWaypoints/Waypoint13"
const YARD := preload("res://game/warehouse_yard.tscn")
const PROP := "WarehouseModel/Yard_Containers/Containers/Container_SW2"

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func run() -> void:
	var original := YARD.instantiate() as Node3D
	var original_model := original.get_node("WarehouseModel")
	if not expect(original.is_editable_instance(original_model),"WarehouseModel does not expose its children in Godot"): return
	var prop := original.get_node(PROP) as MeshInstance3D
	if not expect(prop.position.is_equal_approx(Vector3(-33,1,24.5)),"Default warehouse prop placement changed"): return
	root.add_child(original)
	await physics_frame
	await physics_frame
	var before := triangles(original)
	var probe := prop.global_position
	var hit := roof_hit(original,probe)
	if not expect(hit.get("collider") == original.get_node("YardCollision"),"Original cover collider is missing"): return
	var base_height: float = hit.position.y
	original.free()
	await physics_frame

	# Pack and reopen the editor's changed scene before either gameplay entry point uses it.
	var authored := YARD.instantiate() as YARD_SCRIPT
	var moved := authored.get_node(PROP) as MeshInstance3D
	moved.position.y += 4.0
	var spawn := authored.get_node(SPAWN) as Marker3D
	var waypoint := authored.get_node(WAYPOINT) as Marker3D
	spawn.position += Vector3(1,0,0)
	waypoint.position += Vector3(0,0,1)
	var edited_spawn := spawn.position
	var edited_waypoint := waypoint.position
	var packed := PackedScene.new()
	if not expect(packed.pack(authored) == OK,"Could not pack the edited scene"): return
	authored.free()
	var reopened := packed.instantiate() as YARD_SCRIPT
	root.add_child(reopened)
	await physics_frame
	await physics_frame
	if not expect(reopened.match_spawns[0].is_equal_approx(edited_spawn)
			and reopened.bot_waypoints[12].is_equal_approx(edited_waypoint),
			"Editor changes to the first spawn and last route marker were not preserved for runtime"): return
	moved = reopened.get_node(PROP) as MeshInstance3D
	var lift := Vector3.UP * 1.8
	if not expect(moved.global_position.is_equal_approx(probe+lift),"The editor's prop move was not preserved on reopen"): return
	var after := triangles(reopened)
	if not expect(before.size() == after.size(),"Editing a prop changed collision face count"): return
	var changed := 0
	for i in range(before.size()):
		if not after[i].is_equal_approx(before[i]):
			changed+=1
			if not expect(after[i].is_equal_approx(before[i]+lift),"Collision moved for something outside the authored prop"): return
	if not expect(changed == moved.mesh.get_faces().size(),"Exactly the moved prop's collision triangles should follow the edit"): return
	hit = roof_hit(reopened,probe)
	if not expect(hit.get("collider") == reopened.get_node("YardCollision") and absf(hit.position.y - (base_height+lift.y)) < .002,"Physics did not pick up the moved roof in the edited scene"): return
	print("PASS: Warehouse Yard prop and gameplay marker edits persisted; only edited prop collision moved.")
	quit(0)

func triangles(yard: Node3D) -> PackedVector3Array:
	var shape := yard.get_node("YardCollision/CollisionShape3D") as CollisionShape3D
	return (shape.shape as ConcavePolygonShape3D).get_faces()

func roof_hit(yard: Node3D, at: Vector3) -> Dictionary:
	return yard.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at+Vector3.UP*9.0,at+Vector3.UP*.4,1))
