extends RefCounted
## Deterministic, forgiving arcade flight. The scene supplies the course.

const SPEED := 18.0
const SINK := 3.4
const TURN_RATE := 1.25
const BANK_MAX := 0.40
const LIFT_SPEED := 5.2

var position := Vector3.ZERO
var heading := 0.0
var bank := 0.0
var climb := -SINK
var lift := 0.0

func reset(origin: Vector3, yaw: float) -> void:
	position = origin
	heading = yaw
	bank = 0.0
	climb = -SINK
	lift = 0.0

func advance(delta: float, steer: float, updraft: float) -> Vector3:
	steer = clampf(steer, -1.0, 1.0)
	lift = clampf(updraft, 0.0, 1.0)
	heading -= steer * TURN_RATE * delta
	bank = lerpf(bank, -steer * BANK_MAX, 1.0 - exp(-7.5 * delta))
	climb = lerpf(climb, lerpf(-SINK, LIFT_SPEED, lift), 1.0 - exp(-4.0 * delta))
	position += (Vector3.FORWARD.rotated(Vector3.UP, heading) * SPEED + Vector3.UP * climb) * delta
	return position
