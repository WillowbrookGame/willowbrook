extends RefCounted
## Deterministic, forgiving arcade flight. The scene supplies the course.

const SPEED := 18.0
const SINK := 3.4
const TURN_RATE := 0.95
const STEER_RESPONSE := 6.0
const APPROACH_SPEED := 10.0
const APPROACH_HEIGHT := 2.6
const RUNOUT_TIME := 1.25
const BANK_MAX := 0.40
const LIFT_SPEED := 5.2

var position := Vector3.ZERO
var heading := 0.0
var bank := 0.0
var climb := -SINK
var lift := 0.0
var steering := 0.0
var speed := SPEED
var runout_time := 0.0
var runout_elapsed := 0.0
var runout_speed := 0.0
var runout_start := Vector3.ZERO

func reset(origin: Vector3, yaw: float) -> void:
	position = origin
	heading = yaw
	bank = 0.0
	climb = -SINK
	lift = 0.0
	steering = 0.0
	speed = SPEED
	runout_time = 0.0
	runout_elapsed = 0.0
	runout_speed = 0.0

func advance(delta: float, steer: float, updraft: float, height_over_meadow := INF) -> Vector3:
	var approach := 1.0 - smoothstep(0.0, APPROACH_HEIGHT, height_over_meadow)
	steering = lerpf(steering, clampf(steer, -1.0, 1.0), 1.0 - exp(-STEER_RESPONSE * delta))
	lift = clampf(updraft, 0.0, 1.0)
	heading -= steering * TURN_RATE * lerpf(1.0, 0.42, approach) * delta
	bank = lerpf(bank, -steering * BANK_MAX * (1.0 - approach), 1.0 - exp(-8.0 * delta))
	speed = lerpf(speed, lerpf(SPEED, APPROACH_SPEED, approach), 1.0 - exp(-7.0 * delta))
	var target_climb := lerpf(lerpf(-SINK, -0.85, approach), LIFT_SPEED, lift)
	climb = lerpf(climb, target_climb, 1.0 - exp(-5.0 * delta))
	position += (Vector3.FORWARD.rotated(Vector3.UP, heading) * speed + Vector3.UP * climb) * delta
	return position

func begin_runout(touchdown: Vector3, clear_distance: float) -> void:
	position = touchdown
	runout_start = touchdown
	runout_speed = speed
	runout_elapsed = 0.0
	runout_time = minf(RUNOUT_TIME, 2.0 * clear_distance / maxf(speed, 0.01))
	climb = 0.0

func advance_runout(delta: float) -> bool:
	runout_elapsed = minf(runout_elapsed + delta, runout_time)
	var progress := runout_elapsed / runout_time if runout_time > 0.0 else 1.0
	var distance := runout_speed * runout_elapsed * (1.0 - 0.5 * progress)
	position = runout_start + Vector3.FORWARD.rotated(Vector3.UP, heading) * distance
	speed = runout_speed * (1.0 - progress)
	bank = lerpf(bank, 0.0, 1.0 - exp(-10.0 * delta))
	if progress >= 1.0:
		bank = 0.0
	return progress >= 1.0
