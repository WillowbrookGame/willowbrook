extends CharacterBody3D

const ARENA_WALK_SPEED := 5.5
const WORLD_WALK_SPEED := ARENA_WALK_SPEED * 1.5
const GRAVITY := 19.0
const JUMP_SPEED := 9.0
const STEP_HEIGHT := 0.41
const JUMP_GRACE := .11
var world_bounds := Vector2(18.0, 18.0)
var held: Dictionary = {}
var touch_motion := Vector2.ZERO
var gamepad_motion := Vector2.ZERO
var active := false
var _hide_seek_wait_neutral := false
var hide_seek_locked := false:
	set(value):
		if hide_seek_locked and not value:
			_hide_seek_wait_neutral = _hide_seek_digital_held()
		hide_seek_locked = value
var movement_locked := false:
	set(value):
		movement_locked = value
		if value:
			jump_buffer = 0.0
			_ground_grace = 0.0
var arena_movement := false
var jump_enabled := false
var jump_buffer := 0.0
var _ground_grace := 0.0

func request_jump() -> void:
	if (jump_enabled or arena_movement) and not movement_locked and not hide_seek_locked:
		jump_buffer = 0.13

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		held.clear()
		touch_motion = Vector2.ZERO
		gamepad_motion = Vector2.ZERO
		jump_buffer = 0.0
		_ground_grace = 0.0

func analog_motion() -> Vector2:
	return (touch_motion + gamepad_motion).limit_length()

func _hide_seek_digital_held() -> bool:
	return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")

func _physics_process(delta: float) -> void:
	if hide_seek_locked:
		velocity = Vector3.ZERO
		active = false
		return
	var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") + analog_motion()
	if Input.is_physical_key_pressed(KEY_A) or held.has("left"):
		motion.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or held.has("right"):
		motion.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or held.has("up"):
		motion.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or held.has("down"):
		motion.y += 1.0
	if _hide_seek_wait_neutral:
		_hide_seek_wait_neutral = _hide_seek_digital_held()
		if _hide_seek_wait_neutral:
			motion = analog_motion()
	if movement_locked:
		motion = Vector2.ZERO
	motion = motion.limit_length()
	var horizontal := Vector3(motion.x, 0, motion.y).rotated(Vector3.UP, rotation.y) * (ARENA_WALK_SPEED if arena_movement else WORLD_WALK_SPEED)
	active = motion.length_squared() > 0.0
	var vertical := -2.0
	if jump_enabled or arena_movement:
		var grounded := is_on_floor()
		vertical = -0.25 if grounded else velocity.y - GRAVITY * delta
		if movement_locked:
			_ground_grace = 0.0
		else:
			_ground_grace = JUMP_GRACE if grounded else maxf(0.0,_ground_grace-delta)
		if _ground_grace > 0.0 and jump_buffer > 0.0 and not movement_locked and not hide_seek_locked:
			vertical = JUMP_SPEED
			jump_buffer = 0.0
			_ground_grace = 0.0
		elif grounded and active and arena_movement:
			_try_step(horizontal * delta)
		jump_buffer = maxf(jump_buffer - delta, 0.0)
	velocity = Vector3(horizontal.x, vertical, horizontal.z)
	move_and_slide()
	position.x = clampf(position.x, -world_bounds.x, world_bounds.x)
	position.z = clampf(position.z, -world_bounds.y, world_bounds.y)

func _try_step(motion: Vector3) -> void:
	# Only try when a short lip blocks grounded horizontal motion. Find a
	# walkable landing at the raised position before lifting the capsule.
	var obstruction := KinematicCollision3D.new()
	if not test_move(global_transform, motion, obstruction) or obstruction.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	var raised := global_transform.translated(lift)
	if test_move(raised, motion):
		return
	var landing := KinematicCollision3D.new()
	if not test_move(raised.translated(motion), Vector3.DOWN * STEP_HEIGHT, landing):
		return
	var height := STEP_HEIGHT + landing.get_travel().y
	if height > 0.02 and landing.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		global_position.y += height + 0.008
