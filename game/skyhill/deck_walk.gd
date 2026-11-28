extends CharacterBody3D
## Local on-foot movement for the overlook; the flight model never drives this body.

const AVATARS := preload("res://game/avatars/catalog.gd")
const SPEED := 5.5
const MOUNT_RANGE := 2.2
@onready var arrival: Marker3D = $"../Arrival"
@onready var mount: Marker3D = $"../GliderMount"
@onready var body: Node3D = $Body
var _animation: AnimationPlayer

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
	visible = enabled
	velocity = Vector3.ZERO
	if enabled:
		global_position = arrival.global_position
		body.global_rotation.y = arrival.global_rotation.y

func step(delta: float, input: Vector2) -> void:
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
	var offset := mount.global_position - global_position
	return absf(offset.y) < 0.8 and Vector2(offset.x, offset.z).length() <= MOUNT_RANGE
