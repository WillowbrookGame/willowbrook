extends Marker3D
## An editor-movable flight updraft. Overlapping fields never add their strength.
@export var caption := "Lift"
@export_range(0.0, 30.0) var top_taper := 0.0
@export var ribbons: Node3D
@onready var bounds := $LiftArea/LiftBounds.shape as CylinderShape3D

func weight_at(point: Vector3) -> float:
	var local := to_local(point)
	var half_height := bounds.height * 0.5
	if absf(local.y) > half_height:
		return 0.0
	var distance := Vector2(local.x, local.z).length() / bounds.radius
	var radial := 1.0 - smoothstep(0.65, 1.0, distance)
	var vertical := 1.0 - smoothstep(half_height - top_taper, half_height, local.y) if top_taper > 0.0 else 1.0
	return radial * vertical

func animate_ribbons(elapsed: float) -> void:
	if not is_instance_valid(ribbons):
		return
	ribbons.global_position = global_position
	for marker: Node3D in ribbons.get_children():
		var base_y: float = float(marker.get_meta("base_y", marker.position.y))
		marker.set_meta("base_y", base_y)
		marker.position.y = base_y + sin(elapsed * 2.2 + base_y * 0.3) * 0.65
