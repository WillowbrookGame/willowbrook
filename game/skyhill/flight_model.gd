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
const PITCH_MAX := 0.23
const DIVE_SINK := 7.0
const PULL_UP_CLIMB := 1.8
const HARD_TOUCHDOWN_SPEED := 4.5
const MAX_TOUCHDOWN_TILT := deg_to_rad(17.0)

enum Touchdown { CLEAN, HARD, TILTED }

var position := Vector3.ZERO
var heading := 0.0
var bank := 0.0
var pitch := 0.0
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
	pitch = 0.0
	climb = -SINK
	lift = 0.0
	steering = 0.0
	speed = SPEED
	runout_time = 0.0
	runout_elapsed = 0.0
	runout_speed = 0.0

func advance(delta: float, steer: float, updraft: float, height_over_meadow := INF,
		pitch_input := 0.0, climb_room := 1.0) -> Vector3:
	var approach := 1.0 - smoothstep(0.0, APPROACH_HEIGHT, height_over_meadow)
	steering = lerpf(steering, clampf(steer, -1.0, 1.0), 1.0 - exp(-STEER_RESPONSE * delta))
	lift = clampf(updraft, 0.0, 1.0)
	heading -= steering * TURN_RATE * lerpf(1.0, 0.42, approach) * delta
	# The flare helps ordinary steering, but holding a hard bank can still tilt a landing.
	var bank_weight := maxf(1.0 - approach, 0.8 * smoothstep(0.80, 1.0, absf(steering)))
	bank = lerpf(bank, -steering * BANK_MAX * bank_weight, 1.0 - exp(-8.0 * delta))
	var pitch_control := clampf(pitch_input, -1.0, 1.0)
	# A gentle correction still flares automatically. Holding a steep dive can overpower it.
	var pitch_weight := absf(pitch_control) * maxf(1.0 - approach, 0.68 * smoothstep(0.65, 1.0, -pitch_control))
	pitch = lerpf(pitch, signf(pitch_control) * pitch_weight * PITCH_MAX, 1.0 - exp(-5.0 * delta))
	var airspeed := SPEED + (3.0 if pitch_control < 0.0 else -2.0) * absf(pitch_control)
	speed = lerpf(speed, lerpf(airspeed, APPROACH_SPEED, approach), 1.0 - exp(-7.0 * delta))
	# Soften pitch near the meadow and limit manual climb without capping the waterfall.
	var pull_up := lerpf(-SINK, PULL_UP_CLIMB, clampf(climb_room, 0.0, 1.0))
	var vertical := lerpf(lerpf(-SINK, -0.85, approach), -DIVE_SINK if pitch_control < 0.0 else pull_up, pitch_weight)
	var target_climb := lerpf(vertical, LIFT_SPEED, lift)
	climb = lerpf(climb, target_climb, 1.0 - exp(-5.0 * delta))
	position += (Vector3.FORWARD.rotated(Vector3.UP, heading) * speed + Vector3.UP * climb) * delta
	return position

static func classify_touchdown(sink_speed: float, pitch_angle: float, bank_angle: float) -> Touchdown:
	if sink_speed > HARD_TOUCHDOWN_SPEED:
		return Touchdown.HARD
	# Compare the glider's combined tilt to level, not the heading across the meadow.
	if cos(pitch_angle) * cos(bank_angle) < cos(MAX_TOUCHDOWN_TILT):
		return Touchdown.TILTED
	return Touchdown.CLEAN

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
	pitch = lerpf(pitch, 0.0, 1.0 - exp(-10.0 * delta))
	if progress >= 1.0:
		bank = 0.0
		pitch = 0.0
	return progress >= 1.0
