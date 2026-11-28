extends CharacterBody3D
## Local on-foot movement for the overlook; the flight model never drives this body.

const AVATARS := preload("res://game/avatars/catalog.gd")
const SPEED := 5.5
const MOUNT_RANGE := 2.2
const SEAT_APPROACH_RANGE := 0.54
# Match the Kenney seated rig contact correction used for the indoor chairs.
const SIT_VISUAL_OFFSET := Vector3(0, -0.02625, 0.02875) * 2.5
@onready var arrival: Marker3D = $"../Arrival"
@onready var mount: Marker3D = $"../GliderMount"
@onready var body: Node3D = $Body
var _animation: AnimationPlayer
var _seats: Array[Marker3D] = []
var _seat: Marker3D
var _stand_position := Vector3.ZERO

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("skyhill_overlook_seat"):
		if node is Marker3D and get_parent().is_ancestor_of(node):
			_seats.append(node)

func equip(avatar: String) -> void:
	var figure := AVATARS.instantiate(avatar)
	figure.scale = Vector3.ONE * 2.5
	body.add_child(figure)
	_animation = AVATARS.animator(figure)
	for clip in ["idle", "walk"]:
		if _animation.has_animation(clip):
			_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_animation.play("idle")

func set_walking(enabled: bool) -> void:
	_seat = null
	body.position = Vector3.ZERO
	visible = enabled
	velocity = Vector3.ZERO
	if enabled:
		global_position = arrival.global_position
		body.global_rotation.y = arrival.global_rotation.y

func step(delta: float, input: Vector2) -> void:
	if is_seated():
		_animation.advance(delta)
		return
	var motion := input.limit_length()
	velocity.x = motion.x * SPEED
	velocity.z = motion.y * SPEED
	velocity.y = -0.35 if is_on_floor() else maxf(-12.0, velocity.y - 19.0 * delta)
	move_and_slide()
	if global_position.y < get_parent().global_position.y - 1.5:
		set_walking(true)
		return
	var displacement := get_position_delta()
	var moving := Vector2(displacement.x, displacement.z).length_squared() > 0.00001
	if moving:
		body.rotation.y = atan2(displacement.x, displacement.z)
	var clip := "walk" if moving else "idle"
	if _animation.current_animation != clip:
		_animation.play(clip, 0.1)
	_animation.advance(delta)

func can_mount() -> bool:
	if is_seated():
		return false
	var offset := mount.global_position - global_position
	return absf(offset.y) < 0.8 and Vector2(offset.x, offset.z).length() <= MOUNT_RANGE

func is_seated() -> bool:
	return is_instance_valid(_seat)

func nearby_seat() -> Marker3D:
	if not is_on_floor():
		return null
	var nearest: Marker3D
	var best := SEAT_APPROACH_RANGE
	for seat in _seats:
		var approach: Marker3D = seat.get_node("Approach")
		var distance := global_position.distance_to(approach.global_position)
		if distance < best:
			best = distance
			nearest = seat
	return nearest

func toggle_sitting() -> bool:
	if is_seated():
		_seat = null
		global_position = _stand_position
		body.position = Vector3.ZERO
		_animation.play("idle")
		_animation.advance(0.0)
		return true
	var seat := nearby_seat()
	if seat == null:
		return false
	_seat = seat
	# Return to the actual walkable approach point, not the furniture collider.
	_stand_position = global_position
	velocity = Vector3.ZERO
	global_position = seat.global_position
	body.global_rotation.y = seat.global_rotation.y
	body.position = SIT_VISUAL_OFFSET.rotated(Vector3.UP, body.rotation.y)
	_animation.play("sit")
	_animation.advance(0.0)
	return true
