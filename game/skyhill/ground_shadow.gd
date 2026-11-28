extends MeshInstance3D
## A soft landing cue that works with the Compatibility renderer without cast shadows.

const MATERIAL_SHADER := preload("res://game/skyhill/ground_shadow.gdshader")
const MAX_HEIGHT := 36.0
const MIN_GROUND_UP := 0.66
const SURFACE_OFFSET := 0.035

@export var subject: Node3D
@export_flags_3d_physics var ground_mask := 1
var _material := ShaderMaterial.new()
var _ray := PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	# Sample the new glider pose after the flight controller steps.
	process_physics_priority = 10
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	mesh = plane
	_material.shader = MATERIAL_SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hide()

func set_active(active: bool) -> void:
	set_physics_process(active)
	if not active:
		hide()

func _physics_process(_delta: float) -> void:
	project_at(get_world_3d().direct_space_state, subject.global_position)

func project_at(space: PhysicsDirectSpaceState3D, origin: Vector3) -> void:
	_ray.from = origin
	_ray.to = origin + Vector3.DOWN * MAX_HEIGHT
	_ray.collision_mask = ground_mask
	var hit := space.intersect_ray(_ray)
	if hit.is_empty() or hit.normal.y < MIN_GROUND_UP:
		hide()
		return
	var up: Vector3 = hit.normal.normalized()
	var forward := Vector3.FORWARD.slide(up).normalized()
	var right := forward.cross(up)
	var height: float = origin.y - hit.position.y
	var high := smoothstep(3.0, MAX_HEIGHT, height)
	var size := lerpf(1.7, 2.8, high)
	_material.set_shader_parameter("opacity", 0.46 * (1.0 - high))
	global_transform = Transform3D(Basis(right, up, -forward).scaled(Vector3.ONE * size),
		hit.position + up * SURFACE_OFFSET)
	show()
