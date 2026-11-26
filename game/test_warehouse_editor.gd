extends SceneTree

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
	var authored := YARD.instantiate() as Node3D
	var moved := authored.get_node(PROP) as MeshInstance3D
	moved.position.y += 4.0
	var packed := PackedScene.new()
	if not expect(packed.pack(authored) == OK,"Could not pack the edited scene"): return
	authored.free()
	var reopened := packed.instantiate() as Node3D
	root.add_child(reopened)
	await physics_frame
	await physics_frame
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
	print("PASS: individual Warehouse Yard prop edit persisted and moved exactly its collision triangles.")
	quit(0)

func triangles(yard: Node3D) -> PackedVector3Array:
	var shape := yard.get_node("YardCollision/CollisionShape3D") as CollisionShape3D
	return (shape.shape as ConcavePolygonShape3D).get_faces()

func roof_hit(yard: Node3D, at: Vector3) -> Dictionary:
	return yard.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(at+Vector3.UP*9.0,at+Vector3.UP*.4,1))
