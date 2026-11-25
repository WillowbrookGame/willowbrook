extends Node3D
## Warehouse Yard Arena source geometry stays intact; collision is built from the
## pieces that physically occupy the yard, not signs, paint, or the roof.

const WORLD_BOUNDS := Vector2(24.2, 20.9)
const SOUTH_LOBBY := Vector3(-1.65, 0.04, 7.05)
const TOWN_EXIT := Vector3(-1.65, 0, 9.95)

# Placement shared by the local and authoritative matches. Keep slot order stable.
const SPAWNS := [Vector3(-1.65,0.04,7.05), Vector3(-17.6,0.08,4.4), Vector3(13.8,0.08,5.2), Vector3(2.3,0.08,-8.0)]
const PATROL := [Vector3(-11.1,0,-8.1),Vector3(-18.6,0,3.7),Vector3(-10.5,0,8.3),Vector3(5.6,0,8.0),Vector3(10.1,0,5.7),Vector3(19.2,0,5.0),Vector3(10.0,0,-6.0),Vector3(4.2,0,-8.0),Vector3(-8.9,0,-9.3)]

const COLLISION_PREFIXES := [
	"Container_", "Forklift_", "Catwalk_", "RollUpDoor_", "SideDoor_",
	"Spawn_Blue_", "Spawn_Red_",
]
const COLLISION_NAMES := [
	"Perimeter_Wall", "Warehouse_Shell", "Warehouse_Racks", "Yard_Barriers",
	"Crane_Gantry", "Drums", "Pallet_Stacks", "Cones",
]

@onready var warehouse_roof := find_child("Warehouse_Roof", true, false) as Node3D
var roof_meshes: Array[GeometryInstance3D] = []
var roof_cutaway := false

func _ready() -> void:
	if warehouse_roof is GeometryInstance3D:
		roof_meshes.append(warehouse_roof)
	if warehouse_roof != null:
		for roof_part in warehouse_roof.find_children("*","GeometryInstance3D",true,false):
			roof_meshes.append(roof_part)
	# Spread selected props, not the map boundary. Source units precede scale.
	var offsets := {
		"Container_SW2": Vector3(-3.0, 0, 0.5),
		"Container_SE_Open": Vector3(3.0, 0, 0.5),
		"Container_NE2": Vector3(1.6, 0, -1.3),
		"Container_NW_Open": Vector3(-1.6, 0, -1.3),
		"Forklift_B": Vector3(-2.6, 0, 0.5),
		"Forklift_C": Vector3(2.2, 0, 1.0),
	}
	for prop in offsets:
		var model := find_child(prop, true, false) as Node3D
		if model != null:
			model.position += offsets[prop]
	var triangles := PackedVector3Array()
	# Two smooth collision surfaces over the original visible stair treads.
	for side in [-1.0, 1.0]:
		var bottom := Vector3(1.35 * side, 0.005, -3.2175 * side)
		var top := Vector3(6.75 * side, 4.505, -3.2175 * side)
		var edge := Vector3(0, 0, 0.55)
		if side < 0.0:
			triangles.append_array(PackedVector3Array([bottom-edge, top-edge, top+edge, bottom-edge, top+edge, bottom+edge]))
		else:
			triangles.append_array(PackedVector3Array([bottom-edge, top+edge, top-edge, bottom-edge, bottom+edge, top+edge]))
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if not _is_solid(String(mesh_node.name)) or mesh_node.mesh == null:
			continue
		# Bake model scale and node rotations into the shape rather than scaling
		# a physics body or wrapping whole groups in invisible bounding boxes.
		var to_yard := global_transform.affine_inverse() * mesh_node.global_transform
		var faces := mesh_node.mesh.get_faces()
		var has_stairs := mesh_node.name == "Catwalk_North" or mesh_node.name == "Catwalk_South"
		for i in range(0, faces.size(), 3):
			if has_stairs and _stair_tread(faces[i]) and _stair_tread(faces[i+1]) and _stair_tread(faces[i+2]):
				continue
			for j in range(3):
				triangles.append(to_yard * faces[i+j])
	var hull := ConcavePolygonShape3D.new()
	hull.set_faces(triangles)
	hull.backface_collision = true
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	shape_node.shape = hull
	var body := StaticBody3D.new()
	body.name = "YardCollision"
	add_child(body)
	body.add_child(shape_node)
	_add_barrel_pocket_guards()

func _add_barrel_pocket_guards() -> void:
	# These floor-only patches bridge the narrow gaps behind the drum clusters,
	# not the walkable lanes. Layer 2 is for feet only, not paint or the camera.
	var west := [
		Vector2(-25.1, 12.35), Vector2(-23.95, 11.15), Vector2(-22.8, 12.65),
		Vector2(-22.25, 14.85), Vector2(-25.4, 14.85),
	]
	var east: Array[Vector2] = []
	for point: Vector2 in west:
		east.append(-point)
	var south := [
		Vector2(-15.35, 40.4), Vector2(-14.0, 38.65), Vector2(-12.4, 40.05),
		Vector2(-12.0, 43.55), Vector2(-15.65, 43.55),
	]
	var faces := PackedVector3Array()
	for polygon in [west, east, south]:
		var points := PackedVector2Array(polygon)
		var triangles := Geometry2D.triangulate_polygon(points)
		for index in triangles:
			var point := points[index]
			faces.append(Vector3(point.x * 0.45, 1.37, point.y * 0.45))
	var floor_guard := ConcavePolygonShape3D.new()
	floor_guard.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "BarrelPocketGuards"
	body.collision_layer = 2
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = floor_guard
	body.add_child(collider)
	add_child(body)


func _stair_tread(vertex: Vector3) -> bool:
	return absf(vertex.x) >= 3.99 and absf(vertex.x) <= 14.99 and absf(vertex.z) >= 5.89 and absf(vertex.z) <= 8.41 and vertex.y >= 1.57 and vertex.y <= 10.18

func _is_solid(label: String) -> bool:
	if label in COLLISION_NAMES or label.ends_with("_Ground"):
		return true
	for prefix in COLLISION_PREFIXES:
		if label.begins_with(prefix):
			return true
	return false

func update_cutaway(at: Vector3) -> bool:
	var under_roof := absf(at.x) < 8.55 and absf(at.z) < 6.85
	# Keep the roof's shadow in both camera states. Hiding the entire node
	# would make the interior illumination flash at the cutaway boundary.
	if roof_cutaway != under_roof:
		roof_cutaway = under_roof
		for roof_part in roof_meshes:
			roof_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if under_roof else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return under_roof
