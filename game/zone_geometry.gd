extends RefCounted
## Geometry for shared map fixtures; scene and action state stays in the map controller.


static func build_arena_exit(parent: Node3D, door_position: Vector3) -> void:
	var exit_wall := door_position + Vector3(0, 1.5, 0.34)
	box(parent, "ExitFrame", exit_wall, Vector3(2.65, 3, 0.24), Color("#283d59"), true)
	box(parent, "ExitDoor", exit_wall + Vector3(0, -0.18, -0.13), Vector3(1.65, 2.53, 0.12), Color("#d58049"))
	var exit_sign := _sign(parent, "BACK TO TOWN", exit_wall + Vector3(0, 1.8, 0), 58, Color("#fff0a5"))
	exit_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	box(parent, "MarkedExitLane", door_position + Vector3(0, 0.012, -1.5), Vector3(1.85, 0.018, 2.6), Color("#e8c56b"))


static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, color: Color, solid := false) -> void:
	var model := MeshInstance3D.new()
	model.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	model.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	model.material_override = material
	parent.add_child(model, true)
	model.position = at
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		model.add_child(body)
		body.add_child(collision)

static func _sign(parent: Node3D, caption: String, at: Vector3, size: int, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = caption
	sign.font_size = size
	sign.pixel_size = 0.007
	sign.modulate = color
	sign.outline_size = 8
	sign.no_depth_test = false
	parent.add_child(sign)
	sign.position = at
	return sign
